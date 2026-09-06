import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:between_us/core/network/realtime_client.dart';
import 'package:between_us/core/security/encryption_service.dart';
import 'package:between_us/features/auth/data/auth_repository.dart';
import 'package:between_us/features/auth/state/auth_state.dart';
import 'package:between_us/features/auth_pairing/domain/couple_model.dart';
import 'package:between_us/features/auth_pairing/state/couple_state.dart';
import 'package:between_us/features/couple_pairing/data/couple_repository.dart';

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

class FakeCoupleRepository implements CoupleRepository {
  final Map<String, CoupleModel> _spaces = {};
  final _controller = StreamController<CoupleModel?>.broadcast();

  @override
  Stream<CoupleModel?> watchCouple(String coupleId, String myUserId) {
    return _controller.stream;
  }

  @override
  Future<CoupleModel> createCoupleSpace({
    required String myUserId,
    required String myDisplayName,
    bool forceNew = false,
  }) async {
    if (myDisplayName == 'force_failure') {
      throw Exception('network_timeout');
    }

    if (!forceNew) {
      for (final space in _spaces.values) {
        if (space.user.id == myUserId && space.status == CoupleStatus.waitingForPartner) {
          return space;
        }
      }
    }

    final code = EncryptionService.generatePairingCode();
    final couple = CoupleModel(
      id: 'couple_${_spaces.length + 1}',
      pairingCode: code,
      status: CoupleStatus.waitingForPartner,
      user: UserProfile(id: myUserId, displayName: myDisplayName, initials: myDisplayName.substring(0, 1).toUpperCase()),
      createdAt: DateTime.now(),
    );

    _spaces[couple.id] = couple;
    return couple;
  }

  @override
  Future<CoupleModel?> joinCoupleSpace({
    required String myUserId,
    required String myDisplayName,
    required String pairingCode,
  }) async {
    for (final space in _spaces.values) {
      if (space.pairingCode == pairingCode.toUpperCase().trim()) {
        if (space.user.id == myUserId) {
          throw const SelfPairingException("You can't use your own invitation code. Ask your partner to join.");
        }
        if (space.status != CoupleStatus.waitingForPartner) {
          throw InvalidPairingCodeException('Code "$pairingCode" is already paired or no longer waiting for partner.');
        }
        final connected = space.copyWith(
          status: CoupleStatus.connected,
          partner: UserProfile(id: myUserId, displayName: myDisplayName, initials: myDisplayName.substring(0, 1).toUpperCase()),
        );
        _spaces[space.id] = connected;
        _controller.add(connected);
        return connected;
      }
    }
    return null; // Not found
  }

  @override
  Future<void> updateCountdown({required String coupleId, required DateTime targetDate, required String title}) async {}

  @override
  Future<void> unpairSpace(String coupleId) async {
    _spaces.remove(coupleId);
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

  group('Authoritative Couple Space Creation & Pairing Handshake Tests', () {
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

    test('Authoritative space creation persists code and populates model only on success', () async {
      final client = LocalBroadcastRealtimeClient();
      final coupleRepo = FakeCoupleRepository();
      final coupleState = CoupleState(realtimeClient: client, coupleRepository: coupleRepo);

      expect(coupleState.couple, isNull);
      await coupleState.createSpace(myName: 'Jeet', myUserId: 'user_phone1');

      expect(coupleState.couple, isNotNull);
      expect(coupleState.couple!.status, CoupleStatus.waitingForPartner);
      expect(coupleState.couple!.user.displayName, 'Jeet');
      expect(coupleState.couple!.user.initials, 'J');
      expect(coupleState.couple!.pairingCode.length, 6);
      expect(coupleState.isConnected, isFalse);
      expect(coupleState.isLoading, isFalse);
      expect(coupleState.errorMessage, isNull);
    });

    test('Self-pairing is strictly rejected: creator cannot use own code', () async {
      final client = LocalBroadcastRealtimeClient();
      final coupleRepo = FakeCoupleRepository();
      final coupleState = CoupleState(realtimeClient: client, coupleRepository: coupleRepo);

      await coupleState.createSpace(myName: 'Jeet', myUserId: 'user_phone1');
      final code = coupleState.couple!.pairingCode;

      // Phone 1 attempts to enter its own code
      final selfJoinSuccess = await coupleState.joinSpace(
        myName: 'Jeet',
        code: code,
        myUserId: 'user_phone1',
      );

      expect(selfJoinSuccess, isFalse);
      expect(coupleState.isConnected, isFalse);
      expect(coupleState.errorMessage, "You can't use your own invitation code. Ask your partner to join.");
    });

    test('Space creation failure keeps code null and surfaces retryable error', () async {
      final client = LocalBroadcastRealtimeClient();
      final coupleRepo = FakeCoupleRepository();
      final coupleState = CoupleState(realtimeClient: client, coupleRepository: coupleRepo);

      await coupleState.createSpace(myName: 'force_failure', myUserId: 'user_phone1');

      expect(coupleState.couple, isNull);
      expect(coupleState.isLoading, isFalse);
      expect(coupleState.errorMessage, isNotNull);
      expect(coupleState.errorMessage, contains('Could not create your invitation'));
    });

    test('Retry Generating Code generates and displays a new authoritative code', () async {
      final client = LocalBroadcastRealtimeClient();
      final coupleRepo = FakeCoupleRepository();
      final coupleState = CoupleState(realtimeClient: client, coupleRepository: coupleRepo);

      // 1. First attempt fails
      await coupleState.createSpace(myName: 'force_failure', myUserId: 'user_phone1');
      expect(coupleState.couple, isNull);

      // 2. Retry with valid input and forceNew
      await coupleState.createSpace(myName: 'Jeet', myUserId: 'user_phone1', forceNew: true);
      expect(coupleState.couple, isNotNull);
      expect(coupleState.couple!.pairingCode.length, 6);
      expect(coupleState.errorMessage, isNull);
    });

    test('Two-Phone End-to-End Handshake: Phone 2 joins Phone 1 with real partner names', () async {
      final client1 = LocalBroadcastRealtimeClient();
      final client2 = LocalBroadcastRealtimeClient();
      final coupleRepo = FakeCoupleRepository();

      final phone1State = CoupleState(realtimeClient: client1, coupleRepository: coupleRepo);
      final phone2State = CoupleState(realtimeClient: client2, coupleRepository: coupleRepo);

      // Phone 1 creates authoritative space
      await phone1State.createSpace(myName: 'Jeet', myUserId: 'user_phone1');
      final phone1Code = phone1State.couple!.pairingCode;

      // Phone 2 enters invalid code
      final failedJoin = await phone2State.joinSpace(myName: 'Ananya', code: 'WRONG1', myUserId: 'user_phone2');
      expect(failedJoin, isFalse);
      expect(phone2State.isConnected, isFalse);

      // Phone 2 enters Phone 1 exact code
      final successfulJoin = await phone2State.joinSpace(myName: 'Ananya', code: phone1Code, myUserId: 'user_phone2');
      expect(successfulJoin, isTrue);
      expect(phone2State.isConnected, isTrue);
      expect(phone2State.couple!.status, CoupleStatus.connected);
      expect(phone2State.couple!.partner?.displayName, 'Ananya');

      // Phone 3 attempting to join already connected space fails
      final phone3State = CoupleState(realtimeClient: client2, coupleRepository: coupleRepo);
      final secondJoin = await phone3State.joinSpace(myName: 'Intruder', code: phone1Code, myUserId: 'user_phone3');
      expect(secondJoin, isFalse);
      expect(phone3State.isConnected, isFalse);
    });
  });
}
