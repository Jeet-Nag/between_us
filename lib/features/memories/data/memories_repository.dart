import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/memory_model.dart';
import '../../../core/storage/local_storage_service.dart';

abstract class MemoriesRepository {
  Stream<List<CoupleMemory>> watchMemories(String coupleId);
  Future<void> addMemory({required String coupleId, required CoupleMemory memory});
  Future<void> deleteMemory({required String coupleId, required String memoryId});
  Future<List<CoupleMemory>> getCachedMemories(String coupleId);
}

class FirebaseMemoriesRepository implements MemoriesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalStorageService _storage = LocalStorageService();

  @override
  Stream<List<CoupleMemory>> watchMemories(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('memories')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final memories = snapshot.docs.map((doc) {
        final data = doc.data();
        return CoupleMemory.fromMap(data, docId: doc.id);
      }).toList();

      // Cache locally for offline availability
      _storage.saveCachedMemories(
        coupleId,
        memories.map((m) => m.toMap()).toList(),
      );

      return memories;
    });
  }

  @override
  Future<void> addMemory({required String coupleId, required CoupleMemory memory}) async {
    try {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('memories')
          .doc(memory.id)
          .set(memory.toMap());
    } catch (e) {
      debugPrint('[MemoriesRepository] Error writing memory to Firestore: $e');
    }
  }

  @override
  Future<void> deleteMemory({required String coupleId, required String memoryId}) async {
    try {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('memories')
          .doc(memoryId)
          .delete();
    } catch (e) {
      debugPrint('[MemoriesRepository] Error deleting memory from Firestore: $e');
    }
  }

  @override
  Future<List<CoupleMemory>> getCachedMemories(String coupleId) async {
    final raw = await _storage.getCachedMemories(coupleId);
    return raw.map((map) => CoupleMemory.fromMap(map)).toList();
  }
}
