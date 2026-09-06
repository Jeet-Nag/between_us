import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../domain/music_models.dart';
import '../data/music_repository.dart';

class AudioFileImporter {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final MusicRepository _musicRepository;

  AudioFileImporter({required MusicRepository musicRepository})
      : _musicRepository = musicRepository;

  /// Opens native file picker to select owned audio file and uploads to Firebase Storage
  Future<SongItem?> importUserAudioFile({
    required String coupleId,
    required String addedByName,
    required MusicCategory category,
    Function(double progress)? onProgress,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac'],
      );

      if (result == null || result.files.isEmpty) return null;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final fileSize = await file.length();

      // Validate maximum file size (25 MB limit for mobile optimization)
      if (fileSize > 25 * 1024 * 1024) {
        throw Exception('Audio file exceeds maximum size limit of 25MB.');
      }

      final songId = const Uuid().v4();
      final storageRef = _storage.ref().child('couples/$coupleId/music/$songId.mp3');

      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(contentType: 'audio/mpeg'),
      );

      uploadTask.snapshotEvents.listen((event) {
        if (event.totalBytes > 0 && onProgress != null) {
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress(progress);
        }
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final title = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final newSong = SongItem(
        id: songId,
        title: title,
        artist: addedByName,
        audioUrl: downloadUrl,
        durationMs: 240000, // Estimated duration until loaded by player
        category: category,
        addedByName: addedByName,
      );

      await _musicRepository.addSong(coupleId: coupleId, song: newSong);
      return newSong;
    } catch (e) {
      rethrow;
    }
  }
}
