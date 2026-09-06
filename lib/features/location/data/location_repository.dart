import 'package:cloud_firestore/cloud_firestore.dart';
import '../../home/state/presence_state.dart';
import '../service/native_location_service.dart';

abstract class LocationRepository {
  Stream<PartnerLocation?> watchPartnerLocation({required String coupleId, required String partnerId});
  Future<void> updateMyLocation({required String coupleId, required String myUserId, required LocationReading reading, int batteryLevel});
}

class FirebaseLocationRepository implements LocationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<PartnerLocation?> watchPartnerLocation({required String coupleId, required String partnerId}) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('locations')
        .doc(partnerId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      return PartnerLocation(
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        accuracy: (data['accuracy'] as num?)?.toDouble() ?? 10.0,
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        batteryLevel: (data['batteryLevel'] as num?)?.toInt() ?? 80,
        isCharging: data['isCharging'] as bool? ?? false,
      );
    });
  }

  @override
  Future<void> updateMyLocation({
    required String coupleId,
    required String myUserId,
    required LocationReading reading,
    int batteryLevel = 85,
  }) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('locations')
        .doc(myUserId)
        .set({
      'latitude': reading.latitude,
      'longitude': reading.longitude,
      'accuracy': reading.accuracy,
      'speed': reading.speed,
      'batteryLevel': batteryLevel,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
