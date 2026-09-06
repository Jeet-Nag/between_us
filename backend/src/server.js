const http = require('http');
const express = require('express');
const { WebSocketServer } = require('ws');
const cors = require('cors');
const helmet = require('helmet');
const dotenv = require('dotenv');

dotenv.config();

const { setupWebSocketServer } = require('./websocket');
const {
  verifyAuthToken,
  registerCoupleMembership,
  isAuthorizedMember,
  coupleSpaces
} = require('./auth');

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

// Security and standard middlewares
app.use(helmet());
app.use(cors());
app.use(express.json());

// 1. Health check for Render / load balancers
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'Between Us Backend',
    uptime: process.uptime(),
    timestamp: Date.now()
  });
});

// 2. High-precision server time endpoint for NTP clock skew calculation
app.get('/api/time', (req, res) => {
  res.json({
    serverTimeMs: Date.now()
  });
});

// 3. Couple pairing endpoint (Cryptographically authenticated)
app.post('/api/couple/pair', async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: 'Missing Authorization header' });
  }

  const auth = await verifyAuthToken(authHeader);
  if (!auth) {
    return res.status(401).json({ error: 'Invalid or expired Firebase authentication token' });
  }

  const { coupleId, partnerId } = req.body;
  if (!coupleId || typeof coupleId !== 'string') {
    return res.status(400).json({ error: 'Missing or invalid coupleId' });
  }

  // Use the cryptographically verified auth.uid (ignore any forged userId in body)
  const success = registerCoupleMembership(coupleId, auth.uid, partnerId, auth.displayName);
  if (!success) {
    return res.status(403).json({ error: 'Couple space is already full (maximum 2 members)' });
  }

  res.json({
    success: true,
    coupleId,
    userId: auth.uid,
    serverTime: Date.now()
  });
});

// 4. Couple status check (Authorized members only)
app.get('/api/couple/:coupleId/status', async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: 'Missing Authorization header' });
  }

  const auth = await verifyAuthToken(authHeader);
  if (!auth) {
    return res.status(401).json({ error: 'Invalid or expired Firebase authentication token' });
  }

  const { coupleId } = req.params;
  if (!isAuthorizedMember(coupleId, auth.uid)) {
    return res.status(403).json({ error: 'Forbidden: You are not an authorized member of this couple' });
  }

  const space = coupleSpaces.get(coupleId);
  res.json({
    coupleId,
    status: space.status,
    members: space.members,
    createdAt: space.createdAt
  });
});

// Bind WebSocket Server
setupWebSocketServer(wss);

const PORT = process.env.PORT || 3000;

if (process.env.NODE_ENV !== 'test') {
  server.listen(PORT, () => {
    console.log(`[Between Us Backend] Server listening on port ${PORT}`);
  });
}

module.exports = { app, server, wss };