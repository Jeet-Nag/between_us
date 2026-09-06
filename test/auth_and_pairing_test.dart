import 'package:flutter_test/flutter_test.dart';
import 'package:between_us/core/network/realtime_client.dart';
import 'package:between_us/core/security/encryption_service.dart';
import 'package:between_us/features/auth_pairing/domain/couple_model.dart';
import 'package:between_us/features/auth_pairing/state/couple_state.dart';

void main() {
  group('Couple Space Creation & Pairing Handshake Tests', () {
    test('Generates valid 6-character alphanumeric pairing code', () {
      final code = EncryptionService.generatePairingCode();
      expect(code.length, 6);
      expect(RegExp(r'^[A-Z0-9]{6}$').hasMatch(code), isTrue);
      // Ensure confusing characters (0, O, 1, I) are omitted
      expect(code.contains('0'), isFalse);
      expect(code.contains('O'), isFalse);
      expect(code.contains('1'), isFalse);
      expect(code.contains('I'), isFalse);
    });

    test('Creates space with waitingForPartner status and generates user initials', () async {
      final client = LocalBroadcastRealtimeClient();
      final coupleState = CoupleState(realtimeClient: client);

      await coupleState.createSpace(myName: 'Jeet');

      expect(coupleState.couple, isNotNull);
      expect(coupleState.couple!.status, CoupleStatus.waitingForPartner);
      expect(coupleState.couple!.user.displayName, 'Jeet');
      expect(coupleState.couple!.user.initials, 'J');
      expect(coupleState.couple!.pairingCode.length, 6);
      expect(coupleState.isConnected, isFalse);
    });

    test('Transitions to connected status when partner joins', () async {
      final client = LocalBroadcastRealtimeClient();
      final coupleState = CoupleState(realtimeClient: client);

      await coupleState.createSpace(myName: 'Jeet', myUserId: 'user_jeet');
      expect(coupleState.isConnected, isFalse);

      // Realtime partner joined event dispatched over client stream
      await client.broadcastEvent(RealtimeEvent(
        id: 'evt_partner_join',
        type: RealtimeEventType.presenceChanged,
        senderId: 'partner_ananya',
        coupleId: coupleState.couple!.id,
        payload: {'action': 'partner_joined', 'displayName': 'Ananya'},
        serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
      ));

      expect(coupleState.isConnected, isTrue);
      expect(coupleState.couple!.status, CoupleStatus.connected);
      expect(coupleState.couple!.partner?.displayName, 'Ananya');
      expect(coupleState.couple!.partner?.initials, 'A');
    });

    test('Unpairs space and cleans up active couple session', () async {
      final client = LocalBroadcastRealtimeClient();
      final coupleState = CoupleState(realtimeClient: client);

      await coupleState.createSpace(myName: 'Jeet', myUserId: 'user_jeet');
      await client.broadcastEvent(RealtimeEvent(
        id: 'evt_partner_join',
        type: RealtimeEventType.presenceChanged,
        senderId: 'partner_ananya',
        coupleId: coupleState.couple!.id,
        payload: {'action': 'partner_joined', 'displayName': 'Ananya'},
        serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
      ));
      expect(coupleState.isConnected, isTrue);

      await coupleState.unpairSpace();
      expect(coupleState.couple, isNull);
      expect(coupleState.isConnected, isFalse);
    });
  });
}
