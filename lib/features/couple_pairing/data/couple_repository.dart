import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth_pairing/domain/couple_model.dart';
import '../../../core/security/encryption_service.dart';

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
  Future<void> unpairSpace(String coupleId);
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

      UserProfile? partnerProfile;
      if (partnerId.isNotEmpty) {
        try {
          final partnerDoc = await _firestore.collection('users').doc(partnerId).get().timeout(const Duration(seconds: 5));
          final partnerData = partnerDoc.data() ?? {};
          final name = partnerData['displayName'] as String? ?? 'Partner';
          partnerProfile = UserProfile(
            id: partnerId,
            displayName: name,
            initials: name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'P',
          );
        } catch (e) {
          partnerProfile = UserProfile(
            id: partnerId,
            displayName: 'Partner',
            initials: 'P',
          );
        }
      }

      String myDisplayName = 'You';
      try {
        final myUserDoc = await _firestore.collection('users').doc(myUserId).get().timeout(const Duration(seconds: 5));
        final myUserData = myUserDoc.data() ?? {};
        if (myUserData['displayName'] != null && (myUserData['displayName'] as String).isNotEmpty) {
          myDisplayName = myUserData['displayName'];
        }
      } catch (e) {
        // Safe fallback
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
      'creatorId': myUserId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final invitationData = {
      'code': pairingCode,
      'coupleId': coupleRef.id,
      'creatorId': myUserId,
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

    // Return the authoritative model only after atomic write succeeds
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

    if (invStatus != 'active' || coupleId.isEmpty) {
      return null;
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

      final currentCoupleStatus = coupleSnap.data()?['status'] as String?;
      final currentInvStatus = freshInvSnap.data()?['status'] as String?;

      if (currentCoupleStatus != 'waitingForPartner' || currentInvStatus != 'active') {
        throw Exception('already_paired');
      }

      final members = List<String>.from(coupleSnap.data()?['members'] ?? []);
      if (!members.contains(myUserId)) {
        members.add(myUserId);
      }

      // Update couple space to connected
      transaction.update(coupleRef, {
        'members': members,
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

      // Update user's coupleId
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
              displayName: 'Partner',
              initials: 'P',
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
  Future<void> unpairSpace(String coupleId) async {
    await _firestore.collection('couples').doc(coupleId).update({
      'status': 'disconnected',
    }).timeout(const Duration(seconds: 5));
  }
}
