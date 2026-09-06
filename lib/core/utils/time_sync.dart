/// Compensates for device clock skew against the shared server time.
/// Uses round-trip time (RTT) estimation to calculate server time offset.
class TimeSync {
  static int _serverOffsetMs = 0;
  static bool _isSynchronized = false;

  static bool get isSynchronized => _isSynchronized;
  static int get serverOffsetMs => _serverOffsetMs;

  /// Update the server offset based on a ping-pong handshake
  /// Formula: offset = ((serverTime - clientRequestTime) + (serverTime - clientResponseTime)) / 2
  static void updateOffset({
    required int clientRequestTimeMs,
    required int serverTimestampMs,
    required int clientResponseTimeMs,
  }) {
    final rtt = clientResponseTimeMs - clientRequestTimeMs;
    // Estimated server time at the moment of client response
    final estimatedServerTimeAtResponse = serverTimestampMs + (rtt ~/ 2);
    _serverOffsetMs = estimatedServerTimeAtResponse - clientResponseTimeMs;
    _isSynchronized = true;
  }

  /// Returns the current synchronized epoch millisecond timestamp
  static int get nowSyncedMs {
    return DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;
  }

  /// Converts a synced epoch millisecond timestamp to local DateTime
  static DateTime syncedEpochToDateTime(int epochMs) {
    return DateTime.fromMillisecondsSinceEpoch(epochMs);
  }

  /// Formats millisecond duration into "mm:ss"
  static String formatDurationMs(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = (totalSeconds / 60).floor();
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
