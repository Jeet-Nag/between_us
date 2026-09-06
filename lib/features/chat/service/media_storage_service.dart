import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class MediaStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a voice note to the couple's private storage bucket
  Future<String> uploadVoiceNote({
    required String coupleId,
    required File file,
  }) async {
    final fileId = const Uuid().v4();
    final ref = _storage.ref().child('couples/$coupleId/voice_notes/$fileId.m4a');
    final uploadTask = ref.putFile(file, SettableMetadata(contentType: 'audio/m4a'));
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Uploads a photo to the couple's private storage bucket
  Future<String> uploadPhoto({
    required String coupleId,
    required File file,
  }) async {
    final fileId = const Uuid().v4();
    final ref = _storage.ref().child('couples/$coupleId/photos/$fileId.jpg');
    final uploadTask = ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Uploads a video file with size validation (<=50MB) and progress streaming
  Future<String> uploadVideo({
    required String coupleId,
    required File file,
    Function(double progress)? onProgress,
  }) async {
    final fileSize = await file.length();
    // 50 MB limit safeguard to prevent mobile timeouts
    if (fileSize > 50 * 1024 * 1024) {
      throw Exception('Video file exceeds maximum allowable size of 50MB.');
    }

    final fileId = const Uuid().v4();
    final ref = _storage.ref().child('couples/$coupleId/videos/$fileId.mp4');
    final uploadTask = ref.putFile(file, SettableMetadata(contentType: 'video/mp4'));

    uploadTask.snapshotEvents.listen((event) {
      if (event.totalBytes > 0 && onProgress != null) {
        onProgress(event.bytesTransferred / event.totalBytes);
      }
    });

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}
