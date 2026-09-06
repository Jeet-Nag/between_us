import 'package:flutter_test/flutter_test.dart';
import 'package:between_us/core/utils/time_sync.dart';

void main() {
  group('TimeSync Unit Tests', () {
    test('Calculates NTP server offset accurately with RTT compensation', () {
      const clientReq = 1000;
      const serverTime = 5500;
      const clientResp = 1100;

      TimeSync.updateOffset(
        clientRequestTimeMs: clientReq,
        serverTimestampMs: serverTime,
        clientResponseTimeMs: clientResp,
      );

      expect(TimeSync.isSynchronized, isTrue);
      expect(TimeSync.serverOffsetMs, equals(4450));
    });

    test('Formats millisecond durations cleanly as mm:ss', () {
      expect(TimeSync.formatDurationMs(0), equals('00:00'));
      expect(TimeSync.formatDurationMs(65000), equals('01:05'));
      expect(TimeSync.formatDurationMs(360000), equals('06:00'));
    });
  });
}
