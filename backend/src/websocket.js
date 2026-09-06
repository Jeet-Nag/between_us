const { v4: uuidv4 } = require('uuid');
const {
  verifyAuthToken,
  checkRateLimit,
  registerCoupleMembership,
  isAuthorizedMember,
  getPartnerId,
  unpairCoupleSpace,
  coupleSpaces
} = require('./auth');

// Map of userId -> WebSocket connection
const clientConnections = new Map();
// In-memory event buffer per couple (last 100 events) for temporary reconnect recovery
const coupleEventBuffers = new Map();
// Processed event IDs for idempotency (eventId -> timestamp)
const processedEventIds = new Map();

/**
 * Event buffer utility
 */
function recordEvent(coupleId, event) {
  let buffer = coupleEventBuffers.get(coupleId);
  if (!buffer) {
    buffer = [];
    coupleEventBuffers.set(coupleId, buffer);
  }
  buffer.push(event);
  if (buffer.length > 100) {
    buffer.shift(); // Keep latest 100
  }
}

/**
 * Main WebSocket Connection Initializer
 */
function setupWebSocketServer(wss) {
  wss.on('connection', (ws, req) => {
    ws.isAlive = true;
    ws.userId = null;
    ws.coupleId = null;

    ws.on('pong', () => {
      ws.isAlive = true;
    });

    ws.on('message', async (messageRaw) => {
      try {
        const messageStr = messageRaw.toString();
        const data = JSON.parse(messageStr);
        await handleClientEvent(ws, data);
      } catch (err) {
        sendError(ws, 'INVALID_JSON', 'Could not parse JSON payload');
      }
    });

    ws.on('close', () => {
      if (ws.userId) {
        clientConnections.delete(ws.userId);
        if (ws.coupleId) {
          // Notify partner of offline transition
          broadcastToPartner(ws.coupleId, ws.userId, {
            id: uuidv4(),
            type: 'PRESENCE_UPDATE',
            senderId: ws.userId,
            coupleId: ws.coupleId,
            serverTimestamp: Date.now(),
            payload: { isOnline: false, status: 'offline' }
          });
        }
      }
    });
  });

  // Periodic heartbeat cleanup (every 30 seconds)
  const heartbeatInterval = setInterval(() => {
    wss.clients.forEach((ws) => {
      if (!ws.isAlive) {
        return ws.terminate();
      }
      ws.isAlive = false;
      ws.ping();
    });
  }, 30000);
  if (heartbeatInterval.unref) {
    heartbeatInterval.unref();
  }

  wss.on('close', () => {
    clearInterval(heartbeatInterval);
  });
}

/**
 * Event Dispatcher
 */
async function handleClientEvent(ws, event) {
  const { type, token, coupleId, eventId, payload, revision } = event;

  // 1. Authenticate event
  if (type === 'AUTHENTICATE') {
    if (!token) {
      return sendError(ws, 'UNAUTHENTICATED', 'Missing authentication token', eventId);
    }

    const auth = await verifyAuthToken(token);
    if (!auth) {
      return sendError(ws, 'UNAUTHENTICATED', 'Cryptographic token verification failed', eventId);
    }

    // Bind authenticated UID strictly from verified token claims
    ws.userId = auth.uid;
    ws.displayName = auth.displayName;
    clientConnections.set(ws.userId, ws);

    if (coupleId) {
      // Validate or register couple space membership
      const registered = registerCoupleMembership(coupleId, ws.userId, event.partnerId, auth.displayName);
      if (!registered) {
        return sendError(ws, 'FORBIDDEN', 'Couple space is full or access is denied', eventId);
      }
      ws.coupleId = coupleId;

      // Broadcast online presence to verified partner
      broadcastToPartner(coupleId, ws.userId, {
        id: uuidv4(),
        type: 'PRESENCE_UPDATE',
        senderId: ws.userId,
        coupleId,
        serverTimestamp: Date.now(),
        payload: { isOnline: true, status: 'online', displayName: ws.displayName }
      });
    }

    return sendAck(ws, eventId, {
      status: 'authenticated',
      userId: ws.userId,
      serverTimestamp: Date.now()
    });
  }

  // Enforce authentication for all other events
  if (!ws.userId) {
    return sendError(ws, 'UNAUTHENTICATED', 'Must call AUTHENTICATE before sending events', eventId);
  }

  // Enforce rate limiting per verified user
  if (!checkRateLimit(ws.userId)) {
    return sendError(ws, 'RATE_LIMITED', 'Too many requests, please slow down', eventId);
  }

  // 2. Heartbeat / Ping
  if (type === 'HEARTBEAT') {
    ws.isAlive = true;
    return sendAck(ws, eventId, {
      type: 'HEARTBEAT_ACK',
      serverTimestamp: Date.now()
    });
  }

  // 3. Pair Event
  if (type === 'PAIR') {
    const targetCoupleId = coupleId || payload?.coupleId;
    if (!targetCoupleId) {
      return sendError(ws, 'INVALID_PAIRING', 'Missing coupleId', eventId);
    }
    const success = registerCoupleMembership(targetCoupleId, ws.userId, payload?.partnerId, ws.displayName);
    if (!success) {
      return sendError(ws, 'SPACE_FULL', 'This couple space already has 2 members', eventId);
    }
    ws.coupleId = targetCoupleId;
    return sendAck(ws, eventId, { status: 'paired', coupleId: targetCoupleId });
  }

  // 4. Unpair Event
  if (type === 'UNPAIR') {
    const targetCoupleId = ws.coupleId || coupleId;
    const success = unpairCoupleSpace(targetCoupleId, ws.userId);
    if (success) {
      broadcastToPartner(targetCoupleId, ws.userId, {
        id: uuidv4(),
        type: 'UNPAIR',
        senderId: ws.userId,
        coupleId: targetCoupleId,
        serverTimestamp: Date.now(),
        payload: { status: 'disconnected' }
      });
      ws.coupleId = null;
      return sendAck(ws, eventId, { status: 'unpaired' });
    } else {
      return sendError(ws, 'UNPAIR_FAILED', 'Could not unpair space', eventId);
    }
  }

  // 5. Sync Request on Reconnect
  if (type === 'SYNC_REQUEST') {
    const targetCoupleId = ws.coupleId || coupleId;
    if (!isAuthorizedMember(targetCoupleId, ws.userId)) {
      return sendError(ws, 'UNAUTHORIZED', 'Not an authorized member of this couple', eventId);
    }

    const lastKnownRevision = event.lastKnownRevision || payload?.lastKnownRevision || 0;
    const sinceTimestamp = payload?.sinceTimestamp || 0;
    const buffer = coupleEventBuffers.get(targetCoupleId) || [];
    const missedEvents = buffer.filter(e => {
      if (lastKnownRevision > 0 && e.revision) {
        return e.revision > lastKnownRevision;
      }
      return e.serverTimestamp > sinceTimestamp;
    });

    return ws.send(JSON.stringify({
      type: 'SYNC_RESPONSE',
      eventId: eventId || uuidv4(),
      coupleId: targetCoupleId,
      latestRevision: buffer.length > 0 ? (buffer[buffer.length - 1].revision || lastKnownRevision) : lastKnownRevision,
      missedEvents,
      serverTimestamp: Date.now()
    }));
  }

  // Ensure user is authorized for couple operations
  const activeCoupleId = ws.coupleId || coupleId;
  if (!activeCoupleId || !isAuthorizedMember(activeCoupleId, ws.userId)) {
    return sendError(ws, 'FORBIDDEN', 'User is not an authorized member of this couple', eventId);
  }

  // Check if client is attempting cross-couple event injection
  if (coupleId && coupleId !== ws.coupleId) {
    return sendError(ws, 'CROSS_COUPLE_FORBIDDEN', 'Cannot dispatch events to a foreign couple space', eventId);
  }

  // Check idempotency (prevent duplicate execution of the same eventId)
  if (eventId && processedEventIds.has(eventId)) {
    return sendAck(ws, eventId, { duplicate: true, status: 'already_processed' });
  }
  if (eventId) {
    processedEventIds.set(eventId, Date.now());
    // Prune processedEventIds older than 10 minutes
    if (processedEventIds.size > 5000) {
      const cutoff = Date.now() - 600000;
      for (const [id, ts] of processedEventIds.entries()) {
        if (ts < cutoff) processedEventIds.delete(id);
      }
    }
  }

  // 6. Broadcastable Supported Events
  const supportedTypes = [
    'PRESENCE_UPDATE',
    'LOCATION_UPDATE',
    'CHAT_MESSAGE',
    'MESSAGE_REACTION',
    'MESSAGE_DELETE',
    'MOMENT',
    'MOOD_UPDATE',
    'MISS_YOU',
    'MEETING_UPDATE',
    'MUSIC_SESSION_UPDATE',
    'MEMORY_CREATED',
    'MEMORY_UPDATED',
    'MEMORY_DELETED',
    'HOLD_HANDS_START',
    'HOLD_HANDS_STOP',
    'holdHandsStart',
    'holdHandsStop',
    'CALL_OFFER',
    'CALL_ANSWER',
    'CALL_ICE_CANDIDATE',
    'CALL_END',
    'callOffer',
    'callAnswer',
    'callIceCandidate',
    'callEnd'
  ];

  if (supportedTypes.includes(type)) {
    const outboundEvent = {
      id: eventId || uuidv4(),
      type,
      senderId: ws.userId, // Authenticated UID enforced (prevents impersonation)
      coupleId: activeCoupleId,
      serverTimestamp: Date.now(),
      revision: revision || 1,
      payload: payload || {}
    };

    recordEvent(activeCoupleId, outboundEvent);
    broadcastToPartner(activeCoupleId, ws.userId, outboundEvent);
    return sendAck(ws, eventId, { status: 'delivered', serverTimestamp: outboundEvent.serverTimestamp });
  }

  sendError(ws, 'UNKNOWN_EVENT_TYPE', `Unsupported event type: ${type}`, eventId);
}

/**
 * Broadcasts an event strictly to the partner within the same couple
 */
function broadcastToPartner(coupleId, senderId, eventObj) {
  const partnerId = getPartnerId(coupleId, senderId);
  if (!partnerId) return;

  const partnerWs = clientConnections.get(partnerId);
  if (partnerWs && partnerWs.readyState === 1) { // WebSocket.OPEN
    partnerWs.send(JSON.stringify(eventObj));
  }
}

function sendAck(ws, eventId, data = {}) {
  if (ws.readyState === 1) {
    ws.send(JSON.stringify({
      type: 'ACK',
      eventId: eventId || uuidv4(),
      serverTimestamp: Date.now(),
      ...data
    }));
  }
}

function sendError(ws, code, message, eventId = null) {
  if (ws.readyState === 1) {
    ws.send(JSON.stringify({
      type: 'ERROR',
      eventId: eventId || uuidv4(),
      code,
      message,
      serverTimestamp: Date.now()
    }));
  }
}

module.exports = {
  setupWebSocketServer,
  clientConnections,
  coupleEventBuffers,
  processedEventIds,
  recordEvent
};