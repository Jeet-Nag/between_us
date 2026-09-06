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

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'fcmToken': fcmToken,
    'coupleId': coupleId,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<AuthUser> signUp({required String email, required String password, required String displayName});
  Future<AuthUser> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> registerFcmToken(String uid);
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
    );
    await cred.user?.updateDisplayName(displayName);

    final fcmToken = await _messaging.getToken();

    final user = AuthUser(
      uid: cred.user!.uid,
      email: email.trim(),
      displayName: displayName,
      fcmToken: fcmToken,
    );

    await _firestore.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));
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
    );

    final doc = await _firestore.collection('users').doc(cred.user!.uid).get();
    final fcmToken = await _messaging.getToken();

    if (fcmToken != null) {
      await _firestore.collection('users').doc(cred.user!.uid).update({'fcmToken': fcmToken});
    }

    final data = doc.data() ?? {};
    return AuthUser(
      uid: cred.user!.uid,
      email: cred.user!.email ?? email,
      displayName: data['displayName'] ?? cred.user!.displayName ?? 'User',
      fcmToken: fcmToken,
      coupleId: data['coupleId'],
    );
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<void> registerFcmToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
      }
    } catch (e) {
      // Ignored if offline
    }
  }

  @override
  Future<void> updateUserCoupleId({required String uid, required String coupleId}) async {
    await _firestore.collection('users').doc(uid).set({'coupleId': coupleId}, SetOptions(merge: true));
  }
}
