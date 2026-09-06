import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/message_model.dart';
import '../service/media_storage_service.dart';
import '../../../core/storage/local_storage_service.dart';

abstract class ChatRepository {
  Stream<List<ChatMessage>> watchMessages(String coupleId);
  Future<List<ChatMessage>> getCachedMessages(String coupleId);
  Future<void> sendTextMessage({required String coupleId, required String senderId, required String senderName, required String content, bool isDisappearing});
  Future<void> sendVoiceNote({required String coupleId, required String senderId, required String senderName, required File audioFile, required int durationMs, bool isDisappearing});
  Future<void> sendPhotoMessage({required String coupleId, required String senderId, required String senderName, required File imageFile, bool isDisappearing});
  Future<void> sendVideoMessage({required String coupleId, required String senderId, required String senderName, required File videoFile, Function(double progress)? onProgress, bool isDisappearing});
  Future<void> addReaction({required String coupleId, required String messageId, required String userId, required String emoji});
}

class FirebaseChatRepository implements ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MediaStorageService _storageService = MediaStorageService();
  final LocalStorageService _localStorage = LocalStorageService();

  @override
  Stream<List<ChatMessage>> watchMessages(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map((doc) {
        final data = doc.data();
        return ChatMessage(
          id: doc.id,
          senderId: data['senderId'] as String? ?? '',
          senderName: data['senderName'] as String? ?? 'Partner',
          type: MessageType.values.firstWhere(
            (t) => t.name == data['type'],
            orElse: () => MessageType.text,
          ),
          content: data['content'] as String? ?? '',
          audioDurationMs: data['audioDurationMs'] as int?,
          createdAt: (data['createdAt'] is Timestamp)
              ? (data['createdAt'] as Timestamp).toDate()
              : (data['createdAt'] != null
                  ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
                  : DateTime.now()),
          isDisappearing: data['isDisappearing'] as bool? ?? false,
          reactions: data['reactions'] != null
              ? Map<String, String>.from(data['reactions'] as Map)
              : const {},
        );
      }).toList();

      // Persist to local cache for offline availability
      _localStorage.saveCachedMessages(
        coupleId,
        messages.map((m) => m.toMap()).toList(),
      );

      return messages;
    });
  }

  @override
  Future<List<ChatMessage>> getCachedMessages(String coupleId) async {
    final raw = await _localStorage.getCachedMessages(coupleId);
    return raw.map((m) => ChatMessage.fromMap(m)).toList();
  }

  @override
  Future<void> sendTextMessage({
    required String coupleId,
    required String senderId,
    required String senderName,
    required String content,
    bool isDisappearing = false,
  }) async {
    try {
      await _firestore.collection('couples').doc(coupleId).collection('messages').add({
        'senderId': senderId,
        'senderName': senderName,
        'type': MessageType.text.name,
        'content': content.trim(),
        'isDisappearing': isDisappearing,
        'reactions': {},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FirebaseChatRepository] sendTextMessage error: $e');
    }
  }

  @override
  Future<void> sendVoiceNote({
    required String coupleId,
    required String senderId,
    required String senderName,
    required File audioFile,
    required int durationMs,
    bool isDisappearing = false,
  }) async {
    try {
      final downloadUrl = await _storageService.uploadVoiceNote(coupleId: coupleId, file: audioFile);
      await _firestore.collection('couples').doc(coupleId).collection('messages').add({
        'senderId': senderId,
        'senderName': senderName,
        'type': MessageType.voiceNote.name,
        'content': downloadUrl,
        'audioDurationMs': durationMs,
        'isDisappearing': isDisappearing,
        'reactions': {},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FirebaseChatRepository] sendVoiceNote error: $e');
    }
  }

  @override
  Future<void> sendPhotoMessage({
    required String coupleId,
    required String senderId,
    required String senderName,
    required File imageFile,
    bool isDisappearing = false,
  }) async {
    try {
      final downloadUrl = await _storageService.uploadPhoto(coupleId: coupleId, file: imageFile);
      await _firestore.collection('couples').doc(coupleId).collection('messages').add({
        'senderId': senderId,
        'senderName': senderName,
        'type': MessageType.photo.name,
        'content': downloadUrl,
        'isDisappearing': isDisappearing,
        'reactions': {},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FirebaseChatRepository] sendPhotoMessage error: $e');
    }
  }

  @override
  Future<void> sendVideoMessage({
    required String coupleId,
    required String senderId,
    required String senderName,
    required File videoFile,
    Function(double progress)? onProgress,
    bool isDisappearing = false,
  }) async {
    try {
      final downloadUrl = await _storageService.uploadVideo(
        coupleId: coupleId,
        file: videoFile,
        onProgress: onProgress,
      );
      await _firestore.collection('couples').doc(coupleId).collection('messages').add({
        'senderId': senderId,
        'senderName': senderName,
        'type': MessageType.video.name,
        'content': downloadUrl,
        'isDisappearing': isDisappearing,
        'reactions': {},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FirebaseChatRepository] sendVideoMessage error: $e');
    }
  }

  @override
  Future<void> addReaction({
    required String coupleId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    try {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('messages')
          .doc(messageId)
          .update({
        'reactions.$userId': emoji,
      });
    } catch (e) {
      debugPrint('[FirebaseChatRepository] addReaction error: $e');
    }
  }
}
