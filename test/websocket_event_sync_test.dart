import 'package:flutter_test/flutter_test.dart';
import 'package:between_us/core/network/realtime_client.dart';
import 'package:between_us/core/network/websocket_realtime_client.dart';

void main() {
  group('Realtime Event Synchronization & Protocol Tests', () {
    test('Serializes and deserializes RealtimeEvent faithfully', () {
      const event = RealtimeEvent(
        id: 'evt_12345',
        type: RealtimeEventType.moodChanged,
        senderId: 'user_a',
        coupleId: 'couple_xyz',
        payload: {'mood': 'loving', 'emoji': '🥰'},
        serverTimestampMs: 1725600000000,
        revision: 42,
      );

      final map = event.toMap();
      expect(map['id'], 'evt_12345');
      expect(map['type'], 'moodChanged');
      expect(map['senderId'], 'user_a');
      expect(map['coupleId'], 'couple_xyz');
      expect(map['payload']['mood'], 'loving');
      expect(map['serverTimestampMs'], 1725600000000);
      expect(map['revision'], 42);

      final reconstructed = RealtimeEvent.fromMap(map);
      expect(reconstructed.id, event.id);
      expect(reconstructed.type, event.type);
      expect(reconstructed.senderId, event.senderId);
      expect(reconstructed.coupleId, event.coupleId);
      expect(reconstructed.payload['mood'], 'loving');
      expect(reconstructed.serverTimestampMs, event.serverTimestampMs);
      expect(reconstructed.revision, event.revision);
    });

    test('LocalBroadcastRealtimeClient dispatches events to listeners', () async {
      final client = LocalBroadcastRealtimeClient();
      await client.connect(coupleId: 'couple_abc', userId: 'user_1');

      final receivedEvents = <RealtimeEvent>[];
      final sub = client.eventStream.listen((event) {
        receivedEvents.add(event);
      });

      const sentEvent = RealtimeEvent(
        id: 'evt_999',
        type: RealtimeEventType.missYouSent,
        senderId: 'user_2',
        coupleId: 'couple_abc',
        payload: {'intensity': 'warm'},
        serverTimestampMs: 1725600100000,
      );

      await client.broadcastEvent(sentEvent);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(receivedEvents.length, 1);
      expect(receivedEvents.first.id, 'evt_999');
      expect(receivedEvents.first.type, RealtimeEventType.missYouSent);

      await sub.cancel();
      await client.disconnect();
    });

    test('Handles music session sync events', () async {
      final client = LocalBroadcastRealtimeClient();
      await client.connect(coupleId: 'couple_music', userId: 'user_1');

      RealtimeEvent? captured;
      final sub = client.eventStream.listen((e) => captured = e);

      const musicEvent = RealtimeEvent(
        id: 'evt_music_1',
        type: RealtimeEventType.musicPlay,
        senderId: 'user_1',
        coupleId: 'couple_music',
        payload: {
          'trackId': 'track_ambient_lofi',
          'positionMs': 45200,
          'isPlaying': true,
        },
        serverTimestampMs: 1725600200000,
      );

      await client.broadcastEvent(musicEvent);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(captured, isNotNull);
      expect(captured!.type, RealtimeEventType.musicPlay);
      expect(captured!.payload['trackId'], 'track_ambient_lofi');
      expect(captured!.payload['positionMs'], 45200);

      await sub.cancel();
      await client.disconnect();
    });

    test('WebSocketRealtimeClient resolves verified Render backend URLs', () {
      final wsClient = WebSocketRealtimeClient();
      expect(wsClient.serverUrl, 'wss://between-us-backend-xnur.onrender.com');
      expect(WebSocketRealtimeClient.defaultWsBackendUrl, 'wss://between-us-backend-xnur.onrender.com');
      expect(WebSocketRealtimeClient.defaultHttpBackendUrl, 'https://between-us-backend-xnur.onrender.com');
      expect(WebSocketRealtimeClient.resolveHttpBackendUrl(), 'https://between-us-backend-xnur.onrender.com');
    });
  });
}
