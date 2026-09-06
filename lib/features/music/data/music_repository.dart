import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/music_models.dart';

abstract class MusicRepository {
  Stream<MusicSession?> watchMusicSession(String coupleId);
  Stream<List<SongItem>> watchPlaylist(String coupleId);
  Future<void> updateSession({required String coupleId, required MusicSession session});
  Future<void> addSong({required String coupleId, required SongItem song});
  Future<void> deleteSong({required String coupleId, required String songId});
}

class FirebaseMusicRepository implements MusicRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<MusicSession?> watchMusicSession(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('music_session')
        .doc('current')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      return MusicSession(
        sessionId: data['sessionId'] ?? '',
        currentSong: SongItem(
          id: data['songId'] ?? '',
          title: data['songTitle'] ?? '',
          artist: data['songArtist'] ?? '',
          audioUrl: data['songUrl'] ?? '',
          durationMs: data['songDurationMs'] ?? 200000,
          category: MusicCategory.values.firstWhere(
            (c) => c.name == data['category'],
            orElse: () => MusicCategory.romantic,
          ),
          addedByName: data['addedByName'] ?? 'Partner',
        ),
        playbackState: PlaybackState.values.firstWhere(
          (p) => p.name == data['playbackState'],
          orElse: () => PlaybackState.paused,
        ),
        positionMs: data['positionMs'] ?? 0,
        serverTimestampMs: (data['serverTimestampMs'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        updatedBy: data['updatedBy'] ?? '',
        revision: data['revision'] ?? 1,
      );
    });
  }

  @override
  Stream<List<SongItem>> watchPlaylist(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('playlist')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        return SongItem(
          id: doc.id,
          title: data['title'] ?? '',
          artist: data['artist'] ?? '',
          audioUrl: data['audioUrl'] ?? '',
          durationMs: data['durationMs'] ?? 200000,
          category: MusicCategory.values.firstWhere(
            (c) => c.name == data['category'],
            orElse: () => MusicCategory.romantic,
          ),
          addedByName: data['addedByName'] ?? 'Partner',
        );
      }).toList();
    });
  }

  @override
  Future<void> updateSession({required String coupleId, required MusicSession session}) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('music_session')
        .doc('current')
        .set({
      'sessionId': session.sessionId,
      'songId': session.currentSong.id,
      'songTitle': session.currentSong.title,
      'songArtist': session.currentSong.artist,
      'songUrl': session.currentSong.audioUrl,
      'songDurationMs': session.currentSong.durationMs,
      'category': session.currentSong.category.name,
      'playbackState': session.playbackState.name,
      'positionMs': session.positionMs,
      'serverTimestampMs': DateTime.now().millisecondsSinceEpoch,
      'updatedBy': session.updatedBy,
      'revision': session.revision,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> addSong({required String coupleId, required SongItem song}) async {
    await _firestore.collection('couples').doc(coupleId).collection('playlist').add({
      'title': song.title,
      'artist': song.artist,
      'audioUrl': song.audioUrl,
      'durationMs': song.durationMs,
      'category': song.category.name,
      'addedByName': song.addedByName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteSong({required String coupleId, required String songId}) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('playlist')
        .doc(songId)
        .delete();
  }
}
