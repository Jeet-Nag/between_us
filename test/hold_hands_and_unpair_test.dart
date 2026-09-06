import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:between_us/core/network/realtime_client.dart';
import 'package:between_us/features/auth/state/auth_state.dart';
import 'package:between_us/features/auth/data/auth_repository.dart';
import 'package:between_us/features/auth_pairing/domain/couple_model.dart';
import 'package:between_us/features/auth_pairing/state/couple_state.dart';
import 'package:between_us/features/couple_pairing/data/couple_repository.dart';
import 'package:between_us/features/call/state/call_state.dart';

class MockCoupleRepo implements CoupleRepository {
  bool unpairCalled = false;
  String? unpairCoupleId;
  String? unpairUserId;

  @override
  Stream<CoupleModel?> watchCouple(String coupleId, String myUserId) {
    return Stream.value(null);
  }

  @override
  Future<CoupleModel> createCoupleSpace({
    required String myUserId,
    required String myDisplayName,
    bool forceNew = false,
  }) async {
    return CoupleModel(
      id: 'couple_mock',
      pairingCode: 'ABC123',
      status: CoupleStatus.waitingForPartner,
      user: UserProfile(id: myUserId, displayName: myDisplayName, initials: 'U'),
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<CoupleModel?> joinCoupleSpace({
    required String myUserId,
    required String myDisplayName,
    required String pairingCode,
  }) async {
    return null;
  }

  @override
  Future<void> updateCountdown({required String coupleId, required DateTime targetDate, required String title}) async {}

  @override
  Future<void> unpairSpace(String coupleId, {String? myUserId}) async {
    unpairCalled = true;
    unpairCoupleId = coupleId;
    unpairUserId = myUserId;
  }
}

class FakeAuthRepo implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();
  @override
  User? get currentUser => null;
  @override
  Future<AuthUser> signIn({required String email, required String password}) async =>
      const AuthUser(uid: 'u1', email: 'test@example.com', displayName: 'User', coupleId: 'couple_mock');
  @override
  Future<AuthUser> signUp({required String email, required String password, required String displayName}) async =>
      AuthUser(uid: 'u1', email: email, displayName: displayName);
  @override
  Future<void> signOut() async {}
  @override
  Future<void> syncUserProfile(AuthUser user) async {}
  @override
  Future<AuthUser?> fetchUserProfile(String uid) async => null;
  @override
  Future<void> registerFcmToken(String uid) async {}
  @override
  Future<void> updateUserCoupleId({required String uid, required String coupleId}) async {}
}

void main() {
  group('Unpair & Disconnection Architecture Tests', () {
    test('CoupleState unpairSpace cleans state, disconnects realtime, and calls repo unpair', () async {
      final mockRepo = MockCoupleRepo();
      final mockClient = LocalBroadcastRealtimeClient();
      final coupleState = CoupleState(
        realtimeClient: mockClient,
        coupleRepository: mockRepo,
      );

      // Create space
      await coupleState.createSpace(myName: 'Jeet', myUserId: 'user_jeet');
      expect(coupleState.couple, isNotNull);
      expect(coupleState.couple?.id, equals('couple_mock'));

      // Perform Unpair
      await coupleState.unpairSpace(myUserId: 'user_jeet');

      expect(coupleState.couple, isNull);
      expect(coupleState.isConnected, isFalse);
      expect(mockRepo.unpairCalled, isTrue);
      expect(mockRepo.unpairCoupleId, equals('couple_mock'));
      expect(mockRepo.unpairUserId, equals('user_jeet'));
    });

    test('AuthState clearCoupleId immediately clears couple association', () async {
      final fakeAuth = FakeAuthRepo();
      final authState = AuthState(authRepository: fakeAuth);

      await authState.signIn(email: 'test@example.com', password: 'password');
      expect(authState.user?.coupleId, equals('couple_mock'));

      authState.clearCoupleId();
      expect(authState.user?.coupleId, equals(''));
    });
  });

  group('CallState Realtime State Machine Tests', () {
    test('CallState full lifecycle: idle -> outgoing -> connected -> end', () async {
      final client = LocalBroadcastRealtimeClient();
      await client.connect(coupleId: 'couple_1', userId: 'u1');

      final callState = CallState(
        realtimeClient: client,
        coupleId: 'couple_1',
        myUserId: 'u1',
        myName: 'Jeet',
        partnerName: 'Ananya',
      );

      expect(callState.status, equals(CallStatus.idle));
      expect(callState.isInCall, isFalse);

      // 1. Start Outgoing Call
      callState.startCall(mode: '❤️ Just See You', isVideo: true);
      expect(callState.status, equals(CallStatus.outgoingRinging));
      expect(callState.isInCall, isTrue);
      expect(callState.callContext, equals('❤️ Just See You'));

      // 2. Partner answers call
      await client.broadcastEvent(RealtimeEvent(
        id: 'evt_1',
        type: RealtimeEventType.callAnswer,
        senderId: 'u2',
        coupleId: 'couple_1',
        payload: {'status': 'accepted'},
        serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
      ));
      await pumpEventQueue();

      expect(callState.status, equals(CallStatus.connected));
      expect(callState.isConnected, isTrue);

      // 3. Toggle in-call media controls
      expect(callState.isMuted, isFalse);
      callState.toggleMute();
      expect(callState.isMuted, isTrue);

      expect(callState.isVideoOff, isFalse);
      callState.toggleVideo();
      expect(callState.isVideoOff, isTrue);

      expect(callState.isSpeakerOn, isTrue);
      callState.toggleSpeaker();
      expect(callState.isSpeakerOn, isFalse);

      expect(callState.isFrontCamera, isTrue);
      callState.flipCamera();
      expect(callState.isFrontCamera, isFalse);

      // 4. End Call
      callState.endCall();
      expect(callState.status, equals(CallStatus.ended));

      callState.dispose();
      client.dispose();
    });

    test('Incoming call can be accepted and transitioned to connected', () async {
      final client = LocalBroadcastRealtimeClient();
      await client.connect(coupleId: 'couple_1', userId: 'u2');

      final callState = CallState(
        realtimeClient: client,
        coupleId: 'couple_1',
        myUserId: 'u2',
        myName: 'Ananya',
        partnerName: 'Jeet',
      );

      // Incoming offer event from partner u1
      await client.broadcastEvent(RealtimeEvent(
        id: 'evt_offer',
        type: RealtimeEventType.callOffer,
        senderId: 'u1',
        coupleId: 'couple_1',
        payload: {
          'callId': 'call_123',
          'callerName': 'Jeet',
          'context': '🥺 Miss You',
          'isVideo': true,
        },
        serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
      ));
      await pumpEventQueue();

      expect(callState.status, equals(CallStatus.incomingRinging));
      expect(callState.callContext, equals('🥺 Miss You'));

      // Accept call
      callState.acceptCall();
      expect(callState.status, equals(CallStatus.connected));

      callState.dispose();
      client.dispose();
    });
  });
}
