import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth_pairing/domain/couple_model.dart';
import '../../../core/security/encryption_service.dart';

class SelfPairingException implements Exception {
  final String message;
  const SelfPairingException([this.message = "You can't use your own invitation code. Ask your partner to join."]);
  @override
  String toString() => message;
}

class InvalidPairingCodeException implements Exception {
  final String message;
  const InvalidPairingCodeException(this.message);
  @override
  String toString() => message;
}

abstract class CoupleRepository {
  Stream<CoupleModel?> watchCouple(String coupleId, String myUserId);
  Future<CoupleModel> createCoupleSpace({
    required String myUserId,
    required String myDisplayName,
    bool forceNew = false,
  });
  Future<CoupleModel?> joinCoupleSpace({
    required String myUserId,
    required String myDisplayName,
    required String pairingCode,
  });
  Future<void> updateCountdown({required String coupleId, required DateTime targetDate, required String title});
  Future<void> unpairSpace(String coupleId, {String? myUserId});
}

class FirebaseCoupleRepository implements CoupleRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<CoupleModel?> watchCouple(String coupleId, String myUserId) {
    return _firestore.collection('couples').doc(coupleId).snapshots().asyncMap((doc) async {
      if (!doc.exists) return null;
      final data = doc.data()!;
      final members = List<String>.from(data['members'] ?? []);
      final partnerId = members.firstWhere((id) => id != myUserId, orElse: () => '');
      final memberNames = Map<String, dynamic>.from(data['memberNames'] ?? {});

      UserProfile? partnerProfile;
      if (partnerId.isNotEmpty) {
        String partnerName = memberNames[partnerId] as String? ?? '';
        if (partnerName.isEmpty) {
          try {
            final partnerDoc = await _firestore.collection('users').doc(partnerId).get().timeout(const Duration(seconds: 4));
            final partnerData = partnerDoc.data() ?? {};
            partnerName = partnerData['displayName'] as String? ?? '';
          } catch (_) {}
        }
        if (partnerName.isEmpty) {
          partnerName = 'Partner';
        }
        partnerProfile = UserProfile(
          id: partnerId,
          displayName: partnerName,
          initials: partnerName.isNotEmpty ? partnerName.substring(0, 1).toUpperCase() : 'P',
        );
      }

      String myDisplayName = memberNames[myUserId] as String? ?? '';
      if (myDisplayName.isEmpty) {
        try {
          final myUserDoc = await _firestore.collection('users').doc(myUserId).get().timeout(const Duration(seconds: 4));
          final myUserData = myUserDoc.data() ?? {};
          if (myUserData['displayName'] != null && (myUserData['displayName'] as String).isNotEmpty) {
            myDisplayName = myUserData['displayName'];
          }
        } catch (_) {}
      }
      if (myDisplayName.isEmpty) {
        myDisplayName = 'You';
      }

      return CoupleModel(
        id: coupleId,
        pairingCode: data['pairingCode'] ?? '',
        status: data['status'] == 'connected' ? CoupleStatus.connected : CoupleStatus.waitingForPartner,
        user: UserProfile(
          id: myUserId,
          displayName: myDisplayName,
          initials: myDisplayName.isNotEmpty ? myDisplayName.substring(0, 1).toUpperCase() : 'Y',
        ),
        partner: partnerProfile,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        nextMeetingDate: (data['nextMeetingDate'] as Timestamp?)?.toDate(),
        nextMeetingTitle: data['nextMeetingTitle'],
      );
    });
  }

  @override
  Future<CoupleModel> createCoupleSpace({
    required String myUserId,
    required String myDisplayName,
    bool forceNew = false,
  }) async {
    // 1. If not forcing a brand-new space, check if user already has an existing waiting couple space
    if (!forceNew) {
      try {
        final userDoc = await _firestore.collection('users').doc(myUserId).get().timeout(const Duration(seconds: 4));
        final userData = userDoc.data();
        final existingCoupleId = userData?['coupleId'] as String?;
        if (existingCoupleId != null && existingCoupleId.isNotEmpty) {
          final existingDoc = await _firestore.collection('couples').doc(existingCoupleId).get().timeout(const Duration(seconds: 4));
          if (existingDoc.exists) {
            final data = existingDoc.data()!;
            final code = data['pairingCode'] as String? ?? '';
            final status = data['status'] as String? ?? '';
            if (status == 'waitingForPartner' && code.isNotEmpty) {
              return CoupleModel(
                id: existingCoupleId,
                pairingCode: code,
                status: CoupleStatus.waitingForPartner,
                user: UserProfile(
                  id: myUserId,
                  displayName: myDisplayName,
                  initials: myDisplayName.isNotEmpty ? myDisplayName.substring(0, 1).toUpperCase() : 'U',
                ),
                createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              );
            }
          }
        }
      } catch (e) {
        // Continue to create new space if check fails
      }
    }

    // 2. Create and persist a brand-new authoritative couple document and keyed invitation document
    final coupleRef = _firestore.collection('couples').doc();
    final pairingCode = EncryptionService.generatePairingCode();
    final invRef = _firestore.collection('invitations').doc(pairingCode);

    final coupleData = {
      'id': coupleRef.id,
      'pairingCode': pairingCode,
      'status': 'waitingForPartner',
      'members': [myUserId],
      'memberNames': {myUserId: myDisplayName},
      'creatorId': myUserId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final invitationData = {
      'code': pairingCode,
      'coupleId': coupleRef.id,
      'creatorId': myUserId,
      'creatorDisplayName': myDisplayName,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Atomically persist both couple space and keyed invitation document
    final batch = _firestore.batch();
    batch.set(coupleRef, coupleData);
    batch.set(invRef, invitationData);
    batch.set(
      _firestore.collection('users').doc(myUserId),
      {'coupleId': coupleRef.id, 'displayName': myDisplayName},
      SetOptions(merge: true),
    );

    await batch.commit().timeout(const Duration(seconds: 10));

    return CoupleModel(
      id: coupleRef.id,
      pairingCode: pairingCode,
      status: CoupleStatus.waitingForPartner,
      user: UserProfile(
        id: myUserId,
        displayName: myDisplayName,
        initials: myDisplayName.isNotEmpty ? myDisplayName.substring(0, 1).toUpperCase() : 'U',
      ),
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<CoupleModel?> joinCoupleSpace({
    required String myUserId,
    required String myDisplayName,
    required String pairingCode,
  }) async {
    final code = pairingCode.toUpperCase().trim();

    // 1. Direct O(1) Keyed lookup of /invitations/$code (No collection scan / zero enumeration)
    final invDoc = await _firestore
        .collection('invitations')
        .doc(code)
        .get()
        .timeout(const Duration(seconds: 8));

    if (!invDoc.exists) return null;

    final invData = invDoc.data()!;
    final invStatus = invData['status'] as String? ?? '';
    final coupleId = invData['coupleId'] as String? ?? '';
    final creatorId = invData['creatorId'] as String? ?? '';

    // STRICT INVARIANT 1: Self-Pairing Guard
    if (creatorId == myUserId) {
      throw const SelfPairingException("You can't use your own invitation code. Ask your partner to join.");
    }

    if (invStatus != 'active' || coupleId.isEmpty) {
      throw InvalidPairingCodeException('Code "$code" is no longer active or already paired.');
    }

    final coupleRef = _firestore.collection('couples').doc(coupleId);
    final invRef = _firestore.collection('invitations').doc(code);

    // 2. Run atomic transaction to claim the invitation and activate couple
    await _firestore.runTransaction((transaction) async {
      final coupleSnap = await transaction.get(coupleRef);
      final freshInvSnap = await transaction.get(invRef);

      if (!coupleSnap.exists || !freshInvSnap.exists) {
        throw Exception('space_not_found');
      }

      final coupleData = coupleSnap.data()!;
      final currentCreatorId = coupleData['creatorId'] as String?;
      final members = List<String>.from(coupleData['members'] ?? []);
      final currentCoupleStatus = coupleData['status'] as String?;
      final currentInvStatus = freshInvSnap.data()?['status'] as String?;

      // STRICT INVARIANT 2: Self-pairing check inside atomic transaction
      if (currentCreatorId == myUserId || members.contains(myUserId)) {
        throw const SelfPairingException("You can't use your own invitation code. Ask your partner to join.");
      }

      if (currentCoupleStatus != 'waitingForPartner' || currentInvStatus != 'active') {
        throw InvalidPairingCodeException('Code "$code" is already paired or no longer waiting for partner.');
      }

      members.add(myUserId);
      final memberNames = Map<String, dynamic>.from(coupleData['memberNames'] ?? {});
      memberNames[myUserId] = myDisplayName;

      // Update couple space to connected
      transaction.update(coupleRef, {
        'members': members,
        'memberNames': memberNames,
        'status': 'connected',
        'partnerId': myUserId,
        'connectedAt': FieldValue.serverTimestamp(),
      });

      // Mark invitation as claimed
      transaction.update(invRef, {
        'status': 'claimed',
        'claimedBy': myUserId,
        'claimedAt': FieldValue.serverTimestamp(),
      });

      // Update joining user's profile with coupleId
      transaction.set(
        _firestore.collection('users').doc(myUserId),
        {'coupleId': coupleId, 'displayName': myDisplayName},
        SetOptions(merge: true),
      );
    }).timeout(const Duration(seconds: 10));

    final updatedDoc = await coupleRef.get().timeout(const Duration(seconds: 5));
    final data = updatedDoc.data() ?? {};
    final members = List<String>.from(data['members'] ?? []);
    final partnerId = members.firstWhere((id) => id != myUserId, orElse: () => '');
    final memberNames = Map<String, dynamic>.from(data['memberNames'] ?? {});
    final partnerName = memberNames[partnerId] as String? ?? 'Partner';

    return CoupleModel(
      id: coupleId,
      pairingCode: code,
      status: CoupleStatus.connected,
      user: UserProfile(
        id: myUserId,
        displayName: myDisplayName,
        initials: myDisplayName.isNotEmpty ? myDisplayName.substring(0, 1).toUpperCase() : 'U',
      ),
      partner: partnerId.isNotEmpty
          ? UserProfile(
              id: partnerId,
              displayName: partnerName,
              initials: partnerName.isNotEmpty ? partnerName.substring(0, 1).toUpperCase() : 'P',
            )
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Future<void> updateCountdown({
    required String coupleId,
    required DateTime targetDate,
    required String title,
  }) async {
    await _firestore.collection('couples').doc(coupleId).update({
      'nextMeetingDate': Timestamp.fromDate(targetDate),
      'nextMeetingTitle': title,
    }).timeout(const Duration(seconds: 5));
  }

  @override
  Future<void> unpairSpace(String coupleId, {String? myUserId}) async {
    try {
      final coupleRef = _firestore.collection('couples').doc(coupleId);
      final doc = await coupleRef.get().timeout(const Duration(seconds: 4));
      
      final batch = _firestore.batch();
      batch.update(coupleRef, {
        'status': 'disconnected',
        'disconnectedAt': FieldValue.serverTimestamp(),
      });

      if (doc.exists) {
        final data = doc.data() ?? {};
        final members = List<String>.from(data['members'] ?? []);
        for (final memberId in members) {
          if (memberId.isNotEmpty) {
            batch.set(
              _firestore.collection('users').doc(memberId),
              {'coupleId': ''},
              SetOptions(merge: true),
            );
          }
        }
      }

      if (myUserId != null && myUserId.isNotEmpty) {
        batch.set(
          _firestore.collection('users').doc(myUserId),
          {'coupleId': ''},
          SetOptions(merge: true),
        );
      }

      await batch.commit().timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('[FirebaseCoupleRepository] unpairSpace error: $e');
    }
  }
}
