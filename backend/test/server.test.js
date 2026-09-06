const request = require('supertest');
const WebSocket = require('ws');
const { app, server } = require('../src/server');
const { createTestToken, resetAuthState, coupleEventBuffers } = require('../src/auth');

describe('Between Us Backend - Security, Token Verification & Sync Integration Tests', () => {
  let port;
  let wsUrl;

  beforeAll((done) => {
    server.listen(0, () => {
      port = server.address().port;
      wsUrl = `ws://localhost:${port}`;
      done();
    });
  });

  afterAll((done) => {
    server.close(done);
  });

  beforeEach(() => {
    resetAuthState();
  });

  describe('REST Endpoints Security & Token Verification', () => {
    test('GET /health returns status ok', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
      expect(typeof res.body.timestamp).toBe('number');
    });

    test('GET /api/time returns high precision server timestamp', async () => {
      const res = await request(app).get('/api/time');
      expect(res.status).toBe(200);
      expect(typeof res.body.serverTimeMs).toBe('number');
      expect(res.body.serverTimeMs).toBeGreaterThan(0);
    });

    test('POST /api/couple/pair succeeds with cryptographically signed token', async () => {
      const token = createTestToken('user_test_1', 'Jeet');
      const res = await request(app)
        .post('/api/couple/pair')
        .set('Authorization', `Bearer ${token}`)
        .send({ coupleId: 'couple_unit_test', partnerId: 'user_test_2' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.coupleId).toBe('couple_unit_test');
      expect(res.body.userId).toBe('user_test_1');
    });

    test('POST /api/couple/pair rejects forged/invalid token with 401', async () => {
      const res = await request(app)
        .post('/api/couple/pair')
        .set('Authorization', 'Bearer forged_fake_token_12345')
        .send({ coupleId: 'couple_unit_test', partnerId: 'user_test_2' });

      expect(res.status).toBe(401);
      expect(res.body.error).toContain('Invalid or expired');
    });

    test('POST /api/couple/pair ignores client forged userId and binds token UID', async () => {
      const token = createTestToken('real_token_uid', 'Real User');
      const res = await request(app)
        .post('/api/couple/pair')
        .set('Authorization', `Bearer ${token}`)
        .send({
          coupleId: 'couple_bind_test',
          userId: 'forged_intruder_uid', // Attacker trying to spoof userId in body
          partnerId: 'partner_uid'
        });

      expect(res.status).toBe(200);
      expect(res.body.userId).toBe('real_token_uid'); // Token UID enforced
    });

    test('GET /api/couple/:coupleId/status returns forbidden for non-members', async () => {
      // Register couple for user1 & user2
      const token1 = createTestToken('member_1', 'Member 1');
      await request(app)
        .post('/api/couple/pair')
        .set('Authorization', `Bearer ${token1}`)
        .send({ coupleId: 'couple_private_1', partnerId: 'member_2' });

      // Attacker with valid token but non-member
      const tokenAttacker = createTestToken('intruder_99', 'Intruder');
      const res = await request(app)
        .get('/api/couple/couple_private_1/status')
        .set('Authorization', `Bearer ${tokenAttacker}`);

      expect(res.status).toBe(403);
      expect(res.body.error).toContain('Forbidden');
    });
  });

  describe('WebSocket Realtime Synchronization & Security Boundaries', () => {
    test('Connects, authenticates with token, and exchanges messages between two partners', (done) => {
      const coupleId = 'couple_ws_test';
      const user1Id = 'user_jeet';
      const user2Id = 'user_ananya';
      const token1 = createTestToken(user1Id, 'Jeet');
      const token2 = createTestToken(user2Id, 'Ananya');

      const ws1 = new WebSocket(wsUrl);
      const ws2 = new WebSocket(wsUrl);

      let ws1Authenticated = false;
      let ws2Authenticated = false;

      ws1.on('open', () => {
        ws1.send(JSON.stringify({
          type: 'AUTHENTICATE',
          token: token1,
          coupleId: coupleId,
          partnerId: user2Id,
          eventId: 'auth_1'
        }));
      });

      ws2.on('open', () => {
        ws2.send(JSON.stringify({
          type: 'AUTHENTICATE',
          token: token2,
          coupleId: coupleId,
          partnerId: user1Id,
          eventId: 'auth_2'
        }));
      });

      ws1.on('message', (data) => {
        const msg = JSON.parse(data.toString());
        if (msg.type === 'ACK' && msg.eventId === 'auth_1') {
          ws1Authenticated = true;
          if (ws1Authenticated && ws2Authenticated) {
            sendChatMessage();
          }
        }
      });

      ws2.on('message', (data) => {
        const msg = JSON.parse(data.toString());
        if (msg.type === 'ACK' && msg.eventId === 'auth_2') {
          ws2Authenticated = true;
          if (ws1Authenticated && ws2Authenticated) {
            sendChatMessage();
          }
        } else if (msg.type === 'CHAT_MESSAGE') {
          expect(msg.senderId).toBe(user1Id);
          expect(msg.payload.content).toBe('I miss you!');
          ws1.close();
          ws2.close();
          done();
        }
      });

      let sent = false;
      function sendChatMessage() {
        if (sent) return;
        sent = true;
        ws1.send(JSON.stringify({
          type: 'CHAT_MESSAGE',
          eventId: 'chat_msg_1',
          coupleId: coupleId,
          payload: {
            content: 'I miss you!',
            messageType: 'text'
          }
        }));
      }
    });

    test('Blocks cross-couple event injection attempt', (done) => {
      const tokenUser = createTestToken('user_couple_a', 'User A');
      const ws = new WebSocket(wsUrl);

      ws.on('open', () => {
        ws.send(JSON.stringify({
          type: 'AUTHENTICATE',
          token: tokenUser,
          coupleId: 'couple_A',
          eventId: 'auth_cross'
        }));
      });

      ws.on('message', (data) => {
        const msg = JSON.parse(data.toString());
        if (msg.type === 'ACK' && msg.eventId === 'auth_cross') {
          // Attempt to send event to foreign couple B
          ws.send(JSON.stringify({
            type: 'CHAT_MESSAGE',
            eventId: 'attack_cross_event',
            coupleId: 'couple_B_FOREIGN',
            payload: { content: 'injecting message into foreign couple space' }
          }));
        } else if (msg.eventId === 'attack_cross_event') {
          expect(msg.type).toBe('ERROR');
          expect(msg.code).toBe('CROSS_COUPLE_FORBIDDEN');
          ws.close();
          done();
        }
      });
    });

    test('Rejects duplicate event IDs (Idempotency enforcement)', (done) => {
      const tokenUser = createTestToken('user_idempotent', 'User Idempotent');
      const ws = new WebSocket(wsUrl);

      ws.on('open', () => {
        ws.send(JSON.stringify({
          type: 'AUTHENTICATE',
          token: tokenUser,
          coupleId: 'couple_idemp',
          eventId: 'auth_idemp'
        }));
      });

      let ackCount = 0;
      ws.on('message', (data) => {
        const msg = JSON.parse(data.toString());
        if (msg.type === 'ACK' && msg.eventId === 'auth_idemp') {
          // Send first event
          ws.send(JSON.stringify({
            type: 'MOOD_UPDATE',
            eventId: 'unique_mood_event_1',
            coupleId: 'couple_idemp',
            payload: { mood: 'missingYou', emoji: '🥺' }
          }));
        } else if (msg.eventId === 'unique_mood_event_1') {
          ackCount++;
          if (ackCount === 1) {
            expect(msg.status).toBe('delivered');
            // Send exact same eventId again
            ws.send(JSON.stringify({
              type: 'MOOD_UPDATE',
              eventId: 'unique_mood_event_1',
              coupleId: 'couple_idemp',
              payload: { mood: 'missingYou', emoji: '🥺' }
            }));
          } else if (ackCount === 2) {
            expect(msg.duplicate).toBe(true);
            expect(msg.status).toBe('already_processed');
            ws.close();
            done();
          }
        }
      });
    });

    test('Handles SYNC_REQUEST after server restart gracefully (empty buffer fallback)', (done) => {
      const token = createTestToken('user_restart_sync', 'Sync User');
      const ws = new WebSocket(wsUrl);

      ws.on('open', () => {
        ws.send(JSON.stringify({
          type: 'AUTHENTICATE',
          token: token,
          coupleId: 'couple_restart_test',
          eventId: 'auth_restart'
        }));
      });

      ws.on('message', (data) => {
        const msg = JSON.parse(data.toString());
        if (msg.type === 'ACK' && msg.eventId === 'auth_restart') {
          // Simulate server restart: buffer is completely empty
          ws.send(JSON.stringify({
            type: 'SYNC_REQUEST',
            eventId: 'sync_after_restart',
            coupleId: 'couple_restart_test',
            lastKnownRevision: 15
          }));
        } else if (msg.type === 'SYNC_RESPONSE') {
          expect(msg.type).toBe('SYNC_RESPONSE');
          expect(Array.isArray(msg.missedEvents)).toBe(true);
          expect(msg.missedEvents.length).toBe(0);
          ws.close();
          done();
        }
      });
    });

    test('Validates all 8 exact mood states across WebSocket MOOD_UPDATE', (done) => {
      const token = createTestToken('user_mood_tester', 'Mood Tester');
      const ws = new WebSocket(wsUrl);

      const exactMoods = [
        'happy',
        'loving',
        'missingYou',
        'sad',
        'angry',
        'tired',
        'needAHug',
        'intimate'
      ];

      ws.on('open', () => {
        ws.send(JSON.stringify({
          type: 'AUTHENTICATE',
          token: token,
          coupleId: 'couple_mood_test',
          eventId: 'auth_mood'
        }));
      });

      let currentMoodIndex = 0;

      ws.on('message', (data) => {
        const msg = JSON.parse(data.toString());
        if (msg.type === 'ACK' && msg.eventId === 'auth_mood') {
          sendNextMood();
        } else if (msg.type === 'ACK' && msg.eventId.startsWith('mood_evt_')) {
          currentMoodIndex++;
          if (currentMoodIndex < exactMoods.length) {
            sendNextMood();
          } else {
            ws.close();
            done();
          }
        }
      });

      function sendNextMood() {
        const mood = exactMoods[currentMoodIndex];
        ws.send(JSON.stringify({
          type: 'MOOD_UPDATE',
          eventId: `mood_evt_${currentMoodIndex}`,
          coupleId: 'couple_mood_test',
          payload: { mood, label: mood }
        }));
      }
    });

    test('Rejects unauthenticated events with ERROR', (done) => {
      const ws = new WebSocket(wsUrl);
      ws.on('open', () => {
        ws.send(JSON.stringify({
          type: 'CHAT_MESSAGE',
          eventId: 'unauth_msg',
          coupleId: 'any_couple',
          payload: { content: 'test' }
        }));
      });

      ws.on('message', (data) => {
        const msg = JSON.parse(data.toString());
        expect(msg.type).toBe('ERROR');
        expect(msg.code).toBe('UNAUTHENTICATED');
        ws.close();
        done();
      });
    });
  });
});