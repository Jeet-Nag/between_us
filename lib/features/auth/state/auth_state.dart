import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/auth_repository.dart';

enum AuthStatus {
  checking,
  unauthenticated,
  authenticated,
}

class AuthState extends ChangeNotifier {
  final AuthRepository _authRepository;
  
  AuthStatus _status = AuthStatus.checking;
  AuthUser? _user;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _authSubscription;
  String? _lastSyncedUid;

  AuthState({required AuthRepository authRepository}) : _authRepository = authRepository {
    _initAuth();
  }

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _user != null;
  bool get isChecking => _status == AuthStatus.checking;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearCoupleId() {
    if (_user != null) {
      _user = _user!.copyWith(coupleId: '');
      notifyListeners();
    }
  }

  void _initAuth() {
    // 1. Synchronously restore any cached Firebase session on boot
    final current = _authRepository.currentUser;
    if (current != null) {
      _user = AuthUser(
        uid: current.uid,
        email: current.email ?? '',
        displayName: (current.displayName != null && current.displayName!.isNotEmpty)
            ? current.displayName!
            : 'User',
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      _triggerBackgroundSync(current.uid);
    } else {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }

    // 2. Authoritative subscription to Firebase auth changes
    _authSubscription?.cancel();
    _authSubscription = _authRepository.authStateChanges.listen((firebaseUser) {
      if (firebaseUser == null) {
        if (!_isLoading && _status != AuthStatus.unauthenticated) {
          _user = null;
          _status = AuthStatus.unauthenticated;
          _lastSyncedUid = null;
          notifyListeners();
        }
      } else {
        if (_user?.uid != firebaseUser.uid || _status != AuthStatus.authenticated) {
          _user = AuthUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            displayName: (firebaseUser.displayName != null && firebaseUser.displayName!.isNotEmpty)
                ? firebaseUser.displayName!
                : 'User',
          );
          _status = AuthStatus.authenticated;
          notifyListeners();
          _triggerBackgroundSync(firebaseUser.uid);
        }
      }
    }, onError: (e) {
      debugPrint('[AuthState] Auth state changes listener error: $e');
    });
  }

  void _triggerBackgroundSync(String uid, {String? displayName}) {
    if (_lastSyncedUid == uid && displayName == null) return;
    _lastSyncedUid = uid;

    Future.microtask(() async {
      try {
        // Register FCM Token asynchronously
        _authRepository.registerFcmToken(uid).catchError((_) {});

        // Fetch user document from Firestore (5s timeout)
        final profile = await _authRepository.fetchUserProfile(uid);
        if (profile != null) {
          if (_user != null && _user!.uid == uid) {
            _user = _user!.copyWith(
              displayName: profile.displayName.isNotEmpty ? profile.displayName : _user!.displayName,
              coupleId: profile.coupleId,
              fcmToken: profile.fcmToken,
            );
            notifyListeners();
          }
        } else {
          // If user profile document doesn't exist yet, create it
          final userToSync = _user ?? AuthUser(
            uid: uid,
            email: '',
            displayName: displayName ?? 'User',
          );
          await _authRepository.syncUserProfile(userToSync);
        }
      } catch (e) {
        debugPrint('[AuthState] Background user profile sync non-fatal notice: $e');
      }
    });
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('[AUTH] Starting Firebase signup for: $email');
      final user = await _authRepository.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );

      debugPrint('[AUTH] Firebase auth successful. User UID: ${user.uid}');
      _user = user;
      _status = AuthStatus.authenticated;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();

      // Trigger non-blocking Firestore/FCM background initialization
      _triggerBackgroundSync(user.uid, displayName: displayName);
      return true;
    } catch (e) {
      debugPrint('[AUTH] Signup failed: $e');
      _errorMessage = _parseAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('[AUTH] Starting Firebase sign-in for: $email');
      final user = await _authRepository.signIn(
        email: email,
        password: password,
      );

      debugPrint('[AUTH] Firebase auth successful. User UID: ${user.uid}');
      _user = user;
      _status = AuthStatus.authenticated;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();

      // Trigger non-blocking Firestore/FCM background initialization
      _triggerBackgroundSync(user.uid);
      return true;
    } catch (e) {
      debugPrint('[AUTH] Sign-in failed: $e');
      _errorMessage = _parseAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authRepository.signOut();
    } catch (e) {
      debugPrint('[AUTH] Sign out notice: $e');
    } finally {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _lastSyncedUid = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  String _parseAuthError(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('email-already-in-use')) {
      return 'This email is already registered. Please sign in instead.';
    } else if (str.contains('invalid-email')) {
      return 'The email address format is invalid.';
    } else if (str.contains('weak-password')) {
      return 'Password should be at least 6 characters.';
    } else if (str.contains('user-not-found')) {
      return 'No account found with this email. Please check or create an account.';
    } else if (str.contains('wrong-password') || str.contains('invalid-credential')) {
      return 'Incorrect email or password. Please try again.';
    } else if (str.contains('network-request-failed') || str.contains('timeout')) {
      return 'Network connection issue. Please check your internet connection and retry.';
    } else if (str.contains('too-many-requests')) {
      return 'Too many failed attempts. Please wait a moment and try again.';
    }
    return 'Authentication error: ${error.toString().replaceAll('Exception:', '').trim()}';
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
