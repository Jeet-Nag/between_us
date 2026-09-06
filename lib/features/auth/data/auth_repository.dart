import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthUser {
  final String uid;
  final String email;
  final String displayName;
  final String? fcmToken;
  final String? coupleId;

  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.fcmToken,
    this.coupleId,
  });

  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? fcmToken,
    String? coupleId,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      fcmToken: fcmToken ?? this.fcmToken,
      coupleId: coupleId ?? this.coupleId,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'fcmToken': fcmToken,
    'coupleId': coupleId,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory AuthUser.fromMap(String uid, Map<String, dynamic> data, {String? fallbackEmail, String? fallbackName}) {
    return AuthUser(
      uid: uid,
      email: data['email'] as String? ?? fallbackEmail ?? '',
      displayName: data['displayName'] as String? ?? fallbackName ?? 'User',
      fcmToken: data['fcmToken'] as String?,
      coupleId: data['coupleId'] as String?,
    );
  }
}

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<AuthUser> signUp({required String email, required String password, required String displayName});
  Future<AuthUser> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> registerFcmToken(String uid);
  Future<AuthUser?> fetchUserProfile(String uid);
  Future<void> syncUserProfile(AuthUser user);
  Future<void> updateUserCoupleId({required String uid, required String coupleId});
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ).timeout(const Duration(seconds: 15));

    // Update display name in Firebase Auth without blocking the return
    cred.user?.updateDisplayName(displayName).timeout(
      const Duration(seconds: 5),
    ).catchError((e) {
      // Ignored non-fatal error
    });

    final user = AuthUser(
      uid: cred.user!.uid,
      email: email.trim(),
      displayName: displayName,
    );

    return user;
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ).timeout(const Duration(seconds: 15));

    final user = AuthUser(
      uid: cred.user!.uid,
      email: cred.user!.email ?? email.trim(),
      displayName: (cred.user!.displayName != null && cred.user!.displayName!.isNotEmpty)
          ? cred.user!.displayName!
          : 'User',
    );

    return user;
  }

  @override
  Future<AuthUser?> fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));

      final data = doc.data();
      if (data != null) {
        return AuthUser.fromMap(uid, data);
      }
    } catch (e) {
      // Network or permission fallback
    }
    return null;
  }

  @override
  Future<void> syncUserProfile(AuthUser user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(user.toMap(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      // Background sync non-fatal
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut().timeout(const Duration(seconds: 5));
  }

  @override
  Future<void> registerFcmToken(String uid) async {
    try {
      final token = await _messaging.getToken().timeout(const Duration(seconds: 4));
      if (token != null && token.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(uid)
            .set({'fcmToken': token}, SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      // Ignored if offline or FCM unavailable
    }
  }

  @override
  Future<void> updateUserCoupleId({required String uid, required String coupleId}) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set({'coupleId': coupleId}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      // Non-fatal
    }
  }
}
