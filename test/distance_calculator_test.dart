import 'package:flutter_test/flutter_test.dart';
import 'package:between_us/core/utils/distance_calculator.dart';

void main() {
  group('DistanceCalculator & Proximity Hysteresis Tests', () {
    test('Calculates accurate Haversine distance between Delhi and Mumbai', () {
      // Delhi coordinates
      const lat1 = 28.6139;
      const lon1 = 77.2090;
      // Mumbai coordinates
      const lat2 = 19.0760;
      const lon2 = 72.8777;

      final distanceMeters = DistanceCalculator.calculateDistanceMeters(
        lat1: lat1,
        lon1: lon1,
        lat2: lat2,
        lon2: lon2,
      );

      final distanceKm = distanceMeters / 1000;
      // Expected distance ~1,148 km (+- 20km tolerance)
      expect(distanceKm, greaterThan(1130));
      expect(distanceKm, lessThan(1170));
    });

    test('Classifies proximity states accurately', () {
      // Long distance (>50km)
      final long = DistanceCalculator.evaluateProximity(distanceMeters: 1200000);
      expect(long.state, ProximityState.longDistance);
      expect(long.formattedDistance, contains('1,200 km apart'));

      // Getting Closer (5km - 50km)
      final closer = DistanceCalculator.evaluateProximity(distanceMeters: 25000);
      expect(closer.state, ProximityState.gettingCloser);
      expect(closer.formattedDistance, contains('25 km apart'));

      // Nearby (500m - 5km)
      final nearby = DistanceCalculator.evaluateProximity(distanceMeters: 2500);
      expect(nearby.state, ProximityState.nearby);
      expect(nearby.formattedDistance, contains('2.5 km apart'));

      // Very Close (60m - 500m)
      final veryClose = DistanceCalculator.evaluateProximity(distanceMeters: 200);
      expect(veryClose.state, ProximityState.veryClose);
      expect(veryClose.formattedDistance, contains('200 m apart'));

      // Together (<=60m)
      final together = DistanceCalculator.evaluateProximity(distanceMeters: 25);
      expect(together.state, ProximityState.together);
      expect(together.formattedDistance, equals('Together ❤️'));
    });

    test('Applies hysteresis preventing jitter on proximity threshold boundaries', () {
      // Once Together, exiting requires distance > 120m
      final stillTogether = DistanceCalculator.evaluateProximity(
        distanceMeters: 90,
        previousState: ProximityState.together,
      );
      expect(stillTogether.state, ProximityState.together);

      // Transition out when > 120m
      final exited = DistanceCalculator.evaluateProximity(
        distanceMeters: 130,
        previousState: ProximityState.together,
      );
      expect(exited.state, ProximityState.veryClose);
    });
  });
}
