import 'package:flutter_test/flutter_test.dart';
import 'package:between_us/core/utils/distance_calculator.dart';

void main() {
  group('Distance Calculator Math Tests', () {
    test('Calculates distance accurately between two GPS points using Haversine', () {
      // New York (40.7128, -74.0060) to London (51.5074, -0.1278) -> ~5570 km
      final distanceKm = DistanceCalculator.calculateDistanceKm(
        lat1: 40.7128,
        lon1: -74.0060,
        lat2: 51.5074,
        lon2: -0.1278,
      );

      expect(distanceKm, greaterThan(5500));
      expect(distanceKm, lessThan(5650));
    });

    test('Distance between identical coordinates is 0', () {
      final distanceKm = DistanceCalculator.calculateDistanceKm(
        lat1: 12.9716,
        lon1: 77.5946,
        lat2: 12.9716,
        lon2: 77.5946,
      );

      expect(distanceKm, equals(0.0));
    });
  });
}
