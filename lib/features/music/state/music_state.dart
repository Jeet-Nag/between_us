import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/time_sync.dart';
import '../data/music_repository.dart';
import '../domain/music_models.dart';
import '../service/audio_file_importer.dart';
import '../service/music_sync_controller.dart';
import '../service/native_audio_player_service.dart';

class MusicState extends ChangeNotifier {
  final MusicRepository _musicRepository;
  final String _coupleId;
  final String _myUserId;
  final String _myName;

  final NativeAudioPlayerService _playerService = NativeAudioPlayerService();
  final MusicSyncController _syncController = MusicSyncController();
  late final AudioFileImporter _audioImporter;

  List<SongItem> _playlist = [];
  MusicSession? _currentSession;
  StreamSubscription? _sessionSubscription;
  StreamSubscription? _playlistSubscription;
  StreamSubscription? _playerPositionSubscription;
  bool _isUploadingAudio = false;
  double _uploadProgress = 0.0;
  bool _isReconnecting = false;

  MusicState({
    required MusicRepository musicRepository,
    required String coupleId,
    required String myUserId,
    required String myName,
  })  : _musicRepository = musicRepository,
        _coupleId = coupleId,
        _myUserId = myUserId,
        _myName = myName {
    _audioImporter = AudioFileImporter(musicRepository: _musicRepository);
    _listenToPlaylist();
    _listenToSession();
    _startLocalAudioLoop();
  }

  List<SongItem> get playlist => List.unmodifiable(_playlist);
  MusicSession? get currentSession => _currentSession;
  SyncHealth get syncHealth => _isReconnecting ? SyncHealth.reconnecting : _syncController.health;
  int get currentPositionMs => _currentSession?.positionMs ?? 0;
  bool get isUploadingAudio => _isUploadingAudio;
  double get uploadProgress => _uploadProgress;

  void _listenToPlaylist() {
    _playlistSubscription = _musicRepository.watchPlaylist(_coupleId).listen((songs) {
      _playlist = songs;
      notifyListeners();
    }, onError: (e) {
      _isReconnecting = true;
      notifyListeners();
    });
  }

  void _listenToSession() {
    _sessionSubscription = _musicRepository.watchMusicSession(_coupleId).listen((session) async {
      _isReconnecting = false;
      if (session == null) return;

      // Conflict Resolution: Discard older revisions to prevent race condition flapping
      if (_currentSession != null && session.revision < _currentSession!.revision) {
        debugPrint('[MusicSync] Discarding stale revision ${session.revision} < ${_currentSession!.revision}');
        return;
      }

      final isTrackChanged = _currentSession?.currentSong.id != session.currentSong.id;
      _currentSession = session;
      notifyListeners();

      if (isTrackChanged) {
        await _playerService.loadAudio(session.currentSong.audioUrl);
      }

      if (session.playbackState == PlaybackState.playing) {
        if (!_playerService.isPlaying) {
          await _playerService.play();
        }
      } else {
        if (_playerService.isPlaying) {
          await _playerService.pause();
        }
      }
    }, onError: (e) {
      _isReconnecting = true;
      notifyListeners();
    });
  }

  void _startLocalAudioLoop() {
    _playerPositionSubscription = _playerService.positionStream.listen((pos) {
      if (_currentSession == null) return;

      final currentClientMs = pos.inMilliseconds;

      // Continuous rate slewing drift reconciliation
      _syncController.reconcilePlaybackDrift(
        session: _currentSession!,
        currentClientPositionMs: currentClientMs,
        onHardSeek: (targetMs) => _playerService.seek(Duration(milliseconds: targetMs)),
        onAdjustSpeed: (speed) => _playerService.setSpeed(speed),
      );

      _currentSession = _currentSession!.copyWith(positionMs: currentClientMs);
      notifyListeners();
    });
  }

  /// Synchronized Play / Pause
  Future<void> togglePlayPause() async {
    if (_currentSession == null) return;

    final newState = _currentSession!.playbackState == PlaybackState.playing
        ? PlaybackState.paused
        : PlaybackState.playing;

    final updated = _currentSession!.copyWith(
      playbackState: newState,
      serverTimestampMs: TimeSync.nowSyncedMs,
      updatedBy: _myUserId,
      revision: _currentSession!.revision + 1,
    );

    _currentSession = updated;
    notifyListeners();

    await _musicRepository.updateSession(coupleId: _coupleId, session: updated);
  }

  /// Synchronized Seek
  Future<void> seekTo(int positionMs) async {
    if (_currentSession == null) return;

    final updated = _currentSession!.copyWith(
      positionMs: positionMs,
      serverTimestampMs: TimeSync.nowSyncedMs,
      updatedBy: _myUserId,
      revision: _currentSession!.revision + 1,
    );

    _currentSession = updated;
    notifyListeners();

    await _playerService.seek(Duration(milliseconds: positionMs));
    await _musicRepository.updateSession(coupleId: _coupleId, session: updated);
  }

  /// Track Selection
  Future<void> selectTrack(SongItem song) async {
    final session = MusicSession(
      sessionId: const Uuid().v4(),
      currentSong: song,
      playbackState: PlaybackState.playing,
      positionMs: 0,
      serverTimestampMs: TimeSync.nowSyncedMs,
      updatedBy: _myUserId,
      revision: (_currentSession?.revision ?? 0) + 1,
    );

    _currentSession = session;
    notifyListeners();

    await _playerService.loadAudio(song.audioUrl);
    await _playerService.play();
    await _musicRepository.updateSession(coupleId: _coupleId, session: session);
  }

  /// Play Previous Track in Playlist
  Future<void> playPrevious() async {
    if (_playlist.isEmpty || _currentSession == null) return;
    final currentIndex = _playlist.indexWhere((s) => s.id == _currentSession!.currentSong.id);
    if (currentIndex > 0) {
      await selectTrack(_playlist[currentIndex - 1]);
    } else if (_playlist.isNotEmpty) {
      await selectTrack(_playlist.last);
    }
  }

  /// Play Next Track in Playlist
  Future<void> playNext() async {
    if (_playlist.isEmpty || _currentSession == null) return;
    final currentIndex = _playlist.indexWhere((s) => s.id == _currentSession!.currentSong.id);
    if (currentIndex >= 0 && currentIndex < _playlist.length - 1) {
      await selectTrack(_playlist[currentIndex + 1]);
    } else if (_playlist.isNotEmpty) {
      await selectTrack(_playlist.first);
    }
  }

  /// Import user audio file via native picker and upload to Firebase Storage
  Future<void> importAudioFile({required MusicCategory category}) async {
    _isUploadingAudio = true;
    _uploadProgress = 0.0;
    notifyListeners();

    try {
      final song = await _audioImporter.importUserAudioFile(
        coupleId: _coupleId,
        addedByName: _myName,
        category: category,
        onProgress: (p) {
          _uploadProgress = p;
          notifyListeners();
        },
      );

      if (song != null) {
        await selectTrack(song);
      }
    } catch (e) {
      debugPrint('[MusicState] Error importing audio file: $e');
    } finally {
      _isUploadingAudio = false;
      notifyListeners();
    }
  }

  /// Delete song from shared playlist
  Future<void> deleteSong(String songId) async {
    await _musicRepository.deleteSong(coupleId: _coupleId, songId: songId);
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _playlistSubscription?.cancel();
    _playerPositionSubscription?.cancel();
    _playerService.dispose();
    super.dispose();
  }
}
