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
        final partnerDoc = await _firestore.collection('users').doc(partnerId).get();
        final partnerData = partnerDoc.data() ?? {};
        partnerProfile = UserProfile(
          id: partnerId,
          displayName: partnerData['displayName'] ?? 'Partner',
          initials: (partnerData['displayName'] as String? ?? 'P').substring(0, 1).toUpperCase(),
        );
      }

      final myUserDoc = await _firestore.collection('users').doc(myUserId).get();
      final myUserData = myUserDoc.data() ?? {};

      return CoupleModel(
        id: coupleId,
        pairingCode: data['pairingCode'] ?? '',
        status: data['status'] == 'connected' ? CoupleStatus.connected : CoupleStatus.waitingForPartner,
        user: UserProfile(
          id: myUserId,
          displayName: myUserData['displayName'] ?? 'You',
          initials: (myUserData['displayName'] as String? ?? 'Y').substring(0, 1).toUpperCase(),
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

    await coupleRef.set(coupleData);
    await _firestore.collection('users').doc(myUserId).update({'coupleId': coupleRef.id});

    return CoupleModel(
      id: coupleRef.id,
      pairingCode: pairingCode,
      status: CoupleStatus.waitingForPartner,
      user: UserProfile(
        id: myUserId,
        displayName: myDisplayName,
        initials: myDisplayName.substring(0, 1).toUpperCase(),
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
        .get();

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

      transaction.update(_firestore.collection('users').doc(myUserId), {
        'coupleId': coupleId,
      });
    });

    return watchCouple(coupleId, myUserId).first;
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
    });
  }

  @override
  Future<void> unpairSpace(String coupleId) async {
    await _firestore.collection('couples').doc(coupleId).update({
      'status': 'disconnected',
    });
  }
}
