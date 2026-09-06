import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/auth_repository.dart';

class AuthState extends ChangeNotifier {
  final AuthRepository _authRepository;
  
  AuthUser? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthState({required AuthRepository authRepository}) : _authRepository = authRepository {
    _checkInitialAuth();
  }

  AuthUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _checkInitialAuth() async {
    final current = _authRepository.currentUser;
    if (current != null) {
      _user = AuthUser(
        uid: current.uid,
        email: current.email ?? '',
        displayName: (current.displayName != null && current.displayName!.isNotEmpty) ? current.displayName! : 'User',
      );
      notifyListeners();

      _authRepository.registerFcmToken(current.uid);

      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(current.uid).get().timeout(const Duration(seconds: 5));
        final data = doc.data();
        if (data != null) {
          _user = AuthUser(
            uid: current.uid,
            email: current.email ?? '',
            displayName: data['displayName'] ?? current.displayName ?? 'User',
            coupleId: data['coupleId'],
            fcmToken: data['fcmToken'],
          );
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[AuthState] Initial Firestore profile sync notice: $e');
      }
    }
  }

  Future<bool> signUp({required String email, required String password, required String displayName}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authRepository.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authRepository.signIn(
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    _user = null;
    notifyListeners();
  }
}
