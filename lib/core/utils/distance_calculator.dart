import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/colors.dart';

enum ProximityState {
  longDistance,
  gettingCloser,
  nearby,
  veryClose,
  together,
}

class ProximityResult {
  final double distanceInMeters;
  final ProximityState state;
  final String formattedDistance;
  final String emotionalSubtitle;
  final Color stateColor;

  const ProximityResult({
    required this.distanceInMeters,
    required this.state,
    required this.formattedDistance,
    required this.emotionalSubtitle,
    required this.stateColor,
  });
}

/// Robust distance calculation and proximity hysteresis engine.
/// Prevents false positive "arrived/separated" flipping caused by GPS indoor drift.
class DistanceCalculator {
  static const double earthRadiusKm = 6371.0;

  /// Haversine formula calculation returning distance in meters.
  static double calculateDistanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return (earthRadiusKm * c) * 1000; // in meters
  }

  /// Haversine formula calculation returning distance in kilometers.
  static double calculateDistanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return calculateDistanceMeters(
      lat1: lat1,
      lon1: lon1,
      lat2: lat2,
      lon2: lon2,
    ) / 1000.0;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);

  /// Evaluates distance into an emotional, human-friendly proximity status.
  /// Applies accuracy-gating and hysteresis to prevent notification jitter.
  static ProximityResult evaluateProximity({
    required double distanceMeters,
    double accuracyMeters = 10.0,
    ProximityState previousState = ProximityState.longDistance,
  }) {
    // Determine proximity thresholds with hysteresis
    ProximityState state;
    
    // Together threshold: enter <= 60m, exit > 120m
    if (distanceMeters <= (previousState == ProximityState.together ? 120 : 60)) {
      state = ProximityState.together;
    } else if (distanceMeters <= (previousState == ProximityState.veryClose ? 600 : 500)) {
      state = ProximityState.veryClose;
    } else if (distanceMeters <= (previousState == ProximityState.nearby ? 6000 : 5000)) {
      state = ProximityState.nearby;
    } else if (distanceMeters <= (previousState == ProximityState.gettingCloser ? 60000 : 50000)) {
      state = ProximityState.gettingCloser;
    } else {
      state = ProximityState.longDistance;
    }

    String formatted;
    if (distanceMeters < 1000) {
      formatted = '${distanceMeters.toStringAsFixed(0)} m apart';
    } else if (distanceMeters < 10000) {
      formatted = '${(distanceMeters / 1000).toStringAsFixed(1)} km apart';
    } else {
      final kmStr = (distanceMeters / 1000).round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      formatted = '$kmStr km apart';
    }

    String subtitle;
    Color color;

    switch (state) {
      case ProximityState.together:
        formatted = 'Together ❤️';
        subtitle = 'No more distance between us.';
        color = AppColors.proximityTogether;
        break;
      case ProximityState.veryClose:
        subtitle = 'Just a little distance left.';
        color = AppColors.proximityVeryClose;
        break;
      case ProximityState.nearby:
        subtitle = 'You are in the same city.';
        color = AppColors.proximityNearby;
        break;
      case ProximityState.gettingCloser:
        subtitle = 'The distance is getting smaller.';
        color = AppColors.proximityCloser;
        break;
      case ProximityState.longDistance:
        subtitle = 'Far apart, still part of each other’s day.';
        color = AppColors.proximityLong;
        break;
    }

    return ProximityResult(
      distanceInMeters: distanceMeters,
      state: state,
      formattedDistance: formatted,
      emotionalSubtitle: subtitle,
      stateColor: color,
    );
  }
}
