enum MusicCategory {
  romantic('❤️ Romantic'),
  intimate('🔥 Intimate'),
  missingYou('🥺 Sad / Missing'),
  happy('😊 Happy'),
  bhojpuri('🪕 Bhojpuri'),
  dance('💃 Dance'),
  lateNight('🌙 Late Night'),
  ourMemories('⭐ Our Memories'),
  favorites('💖 Favorites');

  final String label;
  const MusicCategory(this.label);
}

enum PlaybackState {
  stopped,
  playing,
  paused,
}

enum SyncHealth {
  synced,
  slewing,
  reconnecting,
}

class SongItem {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final int durationMs;
  final MusicCategory category;
  final String addedByName;

  const SongItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    required this.durationMs,
    required this.category,
    required this.addedByName,
  });
}

class MusicSession {
  final String sessionId;
  final SongItem currentSong;
  final PlaybackState playbackState;
  final int positionMs;
  final int serverTimestampMs;
  final String updatedBy;
  final int revision;

  const MusicSession({
    required this.sessionId,
    required this.currentSong,
    required this.playbackState,
    required this.positionMs,
    required this.serverTimestampMs,
    required this.updatedBy,
    this.revision = 1,
  });

  MusicSession copyWith({
    String? sessionId,
    SongItem? currentSong,
    PlaybackState? playbackState,
    int? positionMs,
    int? serverTimestampMs,
    String? updatedBy,
    int? revision,
  }) {
    return MusicSession(
      sessionId: sessionId ?? this.sessionId,
      currentSong: currentSong ?? this.currentSong,
      playbackState: playbackState ?? this.playbackState,
      positionMs: positionMs ?? this.positionMs,
      serverTimestampMs: serverTimestampMs ?? this.serverTimestampMs,
      updatedBy: updatedBy ?? this.updatedBy,
      revision: revision ?? this.revision,
    );
  }
}
