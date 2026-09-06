import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:between_us/core/network/realtime_client.dart';
import 'package:between_us/core/security/encryption_service.dart';
import 'package:between_us/features/auth/data/auth_repository.dart';
import 'package:between_us/features/auth/state/auth_state.dart';
import 'package:between_us/features/auth_pairing/domain/couple_model.dart';
import 'package:between_us/features/auth_pairing/state/couple_state.dart';

class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<User?>.broadcast();
  User? _currentUser;
  AuthUser? profileToReturn;

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  User? get currentUser => _currentUser;

  void emitAuthState(User? user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  Future<AuthUser> signUp({required String email, required String password, required String displayName}) async {
    if (email.contains('fail')) {
      throw Exception('email-already-in-use');
    }
    return AuthUser(uid: 'user_123', email: email, displayName: displayName);
  }

  @override
  Future<AuthUser> signIn({required String email, required String password}) async {
    if (password == 'wrong') {
      throw Exception('wrong-password');
    }
    return AuthUser(uid: 'user_123', email: email, displayName: 'Test User', coupleId: 'couple_existing');
  }

  @override
  Future<AuthUser?> fetchUserProfile(String uid) async {
    return profileToReturn;
  }

  @override
  Future<void> syncUserProfile(AuthUser user) async {}

  @override
  Future<void> registerFcmToken(String uid) async {}

  @override
  Future<void> updateUserCoupleId({required String uid, required String coupleId}) async {}

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }
}

void main() {
  group('AuthState Startup & Authentication State Machine Tests', () {
    test('Initializes with unauthenticated status when no cached session exists', () {
      final repo = FakeAuthRepository();
      final authState = AuthState(authRepository: repo);

      expect(authState.status, AuthStatus.unauthenticated);
      expect(authState.isAuthenticated, isFalse);
      expect(authState.isChecking, isFalse);
      expect(authState.user, isNull);
    });

    test('Successful signup transitions immediately to authenticated and clears loading', () async {
      final repo = FakeAuthRepository();
      final authState = AuthState(authRepository: repo);

      final success = await authState.signUp(
        email: 'jeet@example.com',
        password: 'password123',
        displayName: 'Jeet',
      );

      expect(success, isTrue);
      expect(authState.isAuthenticated, isTrue);
      expect(authState.status, AuthStatus.authenticated);
      expect(authState.isLoading, isFalse);
      expect(authState.user?.displayName, 'Jeet');
      expect(authState.errorMessage, isNull);
    });

    test('Failed signup records user-friendly error and resets loading state', () async {
      final repo = FakeAuthRepository();
      final authState = AuthState(authRepository: repo);

      final success = await authState.signUp(
        email: 'fail@example.com',
        password: 'password123',
        displayName: 'Jeet',
      );

      expect(success, isFalse);
      expect(authState.isAuthenticated, isFalse);
      expect(authState.isLoading, isFalse);
      expect(authState.errorMessage, contains('already registered'));
    });

    test('Successful sign-in immediately sets authenticated state and restores coupleId', () async {
      final repo = FakeAuthRepository();
      final authState = AuthState(authRepository: repo);

      final success = await authState.signIn(
        email: 'jeet@example.com',
        password: 'correct_password',
      );

      expect(success, isTrue);
      expect(authState.isAuthenticated, isTrue);
      expect(authState.user?.coupleId, 'couple_existing');
      expect(authState.isLoading, isFalse);
    });
  });

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
