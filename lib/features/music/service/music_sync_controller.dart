import '../../../core/utils/time_sync.dart';
import '../domain/music_models.dart';

/// Senior realtime music synchronization controller.
/// Compensates for network jitter, carrier latency, and clock drift
/// using dynamic rate slewing (0.95x / 1.05x) and Lamport revisions.
class MusicSyncController {
  SyncHealth _health = SyncHealth.synced;
  int _localEstimatedPositionMs = 0;
  double _playbackSpeed = 1.0;

  SyncHealth get health => _health;
  int get localEstimatedPositionMs => _localEstimatedPositionMs;
  double get playbackSpeed => _playbackSpeed;

  /// Calculates the expected position on the timeline right now based on server time
  int calculateTargetPosition(MusicSession session) {
    if (session.playbackState != PlaybackState.playing) {
      return session.positionMs;
    }

    final nowSynced = TimeSync.nowSyncedMs;
    final elapsedSinceUpdate = (nowSynced - session.serverTimestampMs).clamp(0, session.currentSong.durationMs);
    final target = session.positionMs + elapsedSinceUpdate;
    return target.clamp(0, session.currentSong.durationMs);
  }

  /// Evaluates clock drift and returns the recommended corrective action
  void reconcilePlaybackDrift({
    required MusicSession session,
    required int currentClientPositionMs,
    required Function(int seekTargetMs) onHardSeek,
    required Function(double targetSpeed) onAdjustSpeed,
  }) {
    if (session.playbackState != PlaybackState.playing) {
      _health = SyncHealth.synced;
      _playbackSpeed = 1.0;
      onAdjustSpeed(1.0);
      return;
    }

    final targetPos = calculateTargetPosition(session);
    final driftMs = (currentClientPositionMs - targetPos);

    // Drift < 300ms: Healthy sync, do not disturb audio
    if (driftMs.abs() < 300) {
      if (_playbackSpeed != 1.0) {
        _playbackSpeed = 1.0;
        onAdjustSpeed(1.0);
      }
      _health = SyncHealth.synced;
    } 
    // Drift between 300ms and 1500ms: Slew playback speed smoothly
    else if (driftMs.abs() <= 1500) {
      _health = SyncHealth.slewing;
      if (driftMs < 0) {
        // Client is behind -> speed up slightly
        _playbackSpeed = 1.05;
        onAdjustSpeed(1.05);
      } else {
        // Client is ahead -> slow down slightly
        _playbackSpeed = 0.95;
        onAdjustSpeed(0.95);
      }
    } 
    // Drift > 1500ms: Hard jump needed
    else {
      _health = SyncHealth.reconnecting;
      _playbackSpeed = 1.0;
      onHardSeek(targetPos);
      onAdjustSpeed(1.0);
      _health = SyncHealth.synced;
    }

    _localEstimatedPositionMs = currentClientPositionMs;
  }
}
