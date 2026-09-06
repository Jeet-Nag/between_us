import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth_pairing/domain/couple_model.dart';
import '../../../core/security/encryption_service.dart';

abstract class CoupleRepository {
  Stream<CoupleModel?> watchCouple(String coupleId, String myUserId);
  Future<CoupleModel> createCoupleSpace({required String myUserId, required String myDisplayName});
  Future<CoupleModel?> joinCoupleSpace({required String myUserId, required String myDisplayName, required String pairingCode});
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
  }) async {
    // 1. Check if user already has an existing waiting couple space
    try {
      final existingQuery = await _firestore
          .collection('couples')
          .where('members', arrayContains: myUserId)
          .where('status', isEqualTo: 'waitingForPartner')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (existingQuery.docs.isNotEmpty) {
        final doc = existingQuery.docs.first;
        final data = doc.data();
        final existingCode = data['pairingCode'] as String? ?? '';
        if (existingCode.isNotEmpty) {
          return CoupleModel(
            id: doc.id,
            pairingCode: existingCode,
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
    } catch (e) {
      // Continue to create new space if query times out or fails
    }

    final coupleRef = _firestore.collection('couples').doc();
    final pairingCode = EncryptionService.generatePairingCode();

    final coupleData = {
      'id': coupleRef.id,
      'pairingCode': pairingCode,
      'status': 'waitingForPartner',
      'members': [myUserId],
      'creatorId': myUserId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await coupleRef.set(coupleData).timeout(const Duration(seconds: 8));

    try {
      await _firestore
          .collection('users')
          .doc(myUserId)
          .set({'coupleId': coupleRef.id, 'displayName': myDisplayName}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      // Non-fatal if user doc update times out
    }

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
    final query = await _firestore
        .collection('couples')
        .where('pairingCode', isEqualTo: pairingCode.toUpperCase().trim())
        .where('status', isEqualTo: 'waitingForPartner')
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 8));

    if (query.docs.isEmpty) return null;

    final coupleDoc = query.docs.first;
    final coupleId = coupleDoc.id;

    // Run atomic transaction to add user as the second member and activate couple
    await _firestore.runTransaction((transaction) async {
      final fresh = await transaction.get(coupleDoc.reference);
      final members = List<String>.from(fresh.data()?['members'] ?? []);
      if (!members.contains(myUserId)) {
        members.add(myUserId);
      }

      transaction.update(coupleDoc.reference, {
        'members': members,
        'status': 'connected',
        'connectedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        _firestore.collection('users').doc(myUserId),
        {'coupleId': coupleId, 'displayName': myDisplayName},
        SetOptions(merge: true),
      );
    }).timeout(const Duration(seconds: 10));

    final updatedDoc = await _firestore.collection('couples').doc(coupleId).get().timeout(const Duration(seconds: 5));
    final data = updatedDoc.data() ?? {};
    final members = List<String>.from(data['members'] ?? []);
    final partnerId = members.firstWhere((id) => id != myUserId, orElse: () => '');

    return CoupleModel(
      id: coupleId,
      pairingCode: pairingCode,
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
