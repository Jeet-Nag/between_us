/**
 * Cryptographic Firebase Auth Token Verification and Zero-Trust Authorization Engine
 */

const https = require('https');
const crypto = require('crypto');

const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'between-us-eda3b';
const GOOGLE_CERTS_URL = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

// In-memory public key cache for Google x509 certs
let googleCertsCache = null;
let googleCertsExpiresAt = 0;

// In-memory active couple membership mapping (userId -> { coupleId, role, partnerId, displayName })
const userCoupleMap = new Map();
// Couple spaces mapping (coupleId -> { members: [userId1, userId2], status, createdAt, pairingCode })
const coupleSpaces = new Map();
// Rate limit tracker (userId -> timestamp[])
const rateLimitMap = new Map();

/**
 * Fetches and caches Google's public certificates for Firebase ID Token verification
 */
async function fetchGooglePublicCerts() {
  const now = Date.now();
  if (googleCertsCache && now < googleCertsExpiresAt) {
    return googleCertsCache;
  }

  return new Promise((resolve, reject) => {
    https.get(GOOGLE_CERTS_URL, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          if (res.statusCode !== 200) {
            return reject(new Error(`Failed to fetch Google certs: HTTP ${res.statusCode}`));
          }
          const certs = JSON.parse(data);
          // Parse Cache-Control max-age header if available
          const cacheControl = res.headers['cache-control'] || '';
          const maxAgeMatch = cacheControl.match(/max-age=(\d+)/);
          const maxAgeSec = maxAgeMatch ? parseInt(maxAgeMatch[1], 10) : 3600;
          
          googleCertsCache = certs;
          googleCertsExpiresAt = Date.now() + (maxAgeSec * 1000);
          resolve(certs);
        } catch (err) {
          reject(err);
        }
      });
    }).on('error', (err) => {
      reject(err);
    });
  });
}

/**
 * Cryptographically verifies a Firebase Authentication ID Token (RS256 JWT)
 * or test-mode signed JWT tokens in unit testing.
 * 
 * Never trusts client-supplied userId, coupleId, or authorization fields.
 */
async function verifyAuthToken(token) {
  if (!token || typeof token !== 'string') {
    return null;
  }

  const cleanToken = token.startsWith('Bearer ') ? token.slice(7).trim() : token.trim();
  if (cleanToken.length < 10) {
    return null;
  }

  const parts = cleanToken.split('.');
  if (parts.length !== 3) {
    // Malformed token format
    return null;
  }

  const [rawHeader, rawPayload, signature] = parts;

  try {
    const headerJson = Buffer.from(rawHeader, 'base64url').toString('utf8');
    const payloadJson = Buffer.from(rawPayload, 'base64url').toString('utf8');
    const header = JSON.parse(headerJson);
    const payload = JSON.parse(payloadJson);

    const nowSec = Math.floor(Date.now() / 1000);

    // Check expiration
    if (payload.exp && payload.exp < nowSec) {
      return null;
    }

    // Check audience and issuer for Firebase
    const expectedAudience = FIREBASE_PROJECT_ID;
    const expectedIssuer = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;

    // 1. Test Mode Verification (HMAC-SHA256 test tokens for Jest tests)
    if (process.env.NODE_ENV === 'test' && header.alg === 'HS256') {
      const testSecret = process.env.TEST_AUTH_SECRET || 'between_us_test_secret_key_32bytes!!';
      const expectedSig = crypto
        .createHmac('sha256', testSecret)
        .update(`${rawHeader}.${rawPayload}`)
        .digest('base64url');

      if (signature === expectedSig && payload.sub) {
        return {
          uid: payload.sub,
          email: payload.email || null,
          displayName: payload.name || payload.displayName || 'User',
          authTime: payload.auth_time || nowSec
        };
      }
      return null;
    }

    // 2. Production Cryptographic RS256 Verification against Google Public Certs
    if (header.alg !== 'RS256' || !header.kid) {
      return null;
    }

    if (payload.aud !== expectedAudience || payload.iss !== expectedIssuer) {
      return null;
    }

    if (!payload.sub || typeof payload.sub !== 'string') {
      return null;
    }

    const certs = await fetchGooglePublicCerts();
    const publicCert = certs[header.kid];
    if (!publicCert) {
      return null;
    }

    // Verify RSA-SHA256 signature
    const verifier = crypto.createVerify('RSA-SHA256');
    verifier.update(`${rawHeader}.${rawPayload}`);
    const isValid = verifier.verify(publicCert, signature, 'base64url');

    if (!isValid) {
      return null;
    }

    return {
      uid: payload.sub,
      email: payload.email || null,
      displayName: payload.name || payload.displayName || 'User',
      authTime: payload.auth_time || nowSec
    };
  } catch (err) {
    return null;
  }
}

/**
 * Helper to generate valid test tokens for unit test suites
 */
function createTestToken(uid, displayName = 'Test User', expiresInSec = 3600) {
  const nowSec = Math.floor(Date.now() / 1000);
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload = {
    sub: uid,
    name: displayName,
    aud: FIREBASE_PROJECT_ID,
    iss: `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`,
    iat: nowSec,
    exp: nowSec + expiresInSec,
    auth_time: nowSec
  };

  const rawHeader = Buffer.from(JSON.stringify(header)).toString('base64url');
  const rawPayload = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const testSecret = process.env.TEST_AUTH_SECRET || 'between_us_test_secret_key_32bytes!!';

  const signature = crypto
    .createHmac('sha256', testSecret)
    .update(`${rawHeader}.${rawPayload}`)
    .digest('base64url');

  return `${rawHeader}.${rawPayload}.${signature}`;
}

/**
 * Enforces rate limiting (max 120 events per minute per user)
 */
function checkRateLimit(userId, limit = 120, windowMs = 60000) {
  const now = Date.now();
  const timestamps = rateLimitMap.get(userId) || [];
  const recent = timestamps.filter(t => now - t < windowMs);

  if (recent.length >= limit) {
    return false;
  }

  recent.push(now);
  rateLimitMap.set(userId, recent);
  return true;
}

/**
 * Registers / verifies couple space membership
 */
function registerCoupleMembership(coupleId, userId, partnerId = null, displayName = 'User') {
  if (!coupleId || !userId) return false;

  let space = coupleSpaces.get(coupleId);
  if (!space) {
    space = {
      coupleId,
      members: [userId],
      status: partnerId ? 'connected' : 'waitingForPartner',
      createdAt: Date.now(),
      lastActive: Date.now()
    };
    if (partnerId && partnerId !== userId) {
      space.members.push(partnerId);
    }
    coupleSpaces.set(coupleId, space);
  } else {
    if (!space.members.includes(userId)) {
      if (space.members.length < 2) {
        space.members.push(userId);
        space.status = 'connected';
      } else {
        return false; // Space already full (strictly 2 members cap)
      }
    }
    space.lastActive = Date.now();
  }

  userCoupleMap.set(userId, {
    coupleId,
    displayName,
    partnerId: partnerId || space.members.find(id => id !== userId) || null
  });

  return true;
}

/**
 * Zero-trust authorization: checks if a user is legitimately a member of the couple
 */
function isAuthorizedMember(coupleId, userId) {
  if (!coupleId || !userId) return false;
  const space = coupleSpaces.get(coupleId);
  if (!space) return false;
  return space.members.includes(userId);
}

/**
 * Retrieves the partner's userId for an authenticated user
 */
function getPartnerId(coupleId, userId) {
  const space = coupleSpaces.get(coupleId);
  if (!space) return null;
  return space.members.find(id => id !== userId) || null;
}

/**
 * Unpairs / disconnects a couple space
 */
function unpairCoupleSpace(coupleId, userId) {
  if (!isAuthorizedMember(coupleId, userId)) return false;
  const space = coupleSpaces.get(coupleId);
  if (space) {
    space.status = 'disconnected';
    for (const memberId of space.members) {
      userCoupleMap.delete(memberId);
    }
    coupleSpaces.delete(coupleId);
    return true;
  }
  return false;
}

function resetAuthState() {
  userCoupleMap.clear();
  coupleSpaces.clear();
  rateLimitMap.clear();
}

module.exports = {
  verifyAuthToken,
  createTestToken,
  checkRateLimit,
  registerCoupleMembership,
  isAuthorizedMember,
  getPartnerId,
  unpairCoupleSpace,
  resetAuthState,
  coupleSpaces,
  userCoupleMap
};
