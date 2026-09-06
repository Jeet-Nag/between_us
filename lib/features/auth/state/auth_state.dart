import 'package:flutter/foundation.dart';
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

  void _checkInitialAuth() {
    final current = _authRepository.currentUser;
    if (current != null) {
      _user = AuthUser(
        uid: current.uid,
        email: current.email ?? '',
        displayName: current.displayName ?? 'User',
      );
      _authRepository.registerFcmToken(current.uid);
      notifyListeners();
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
