import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

/// Native Hardware Battery Service querying real device power and charging state
class NativeBatteryService {
  static final Battery _battery = Battery();

  /// Reads physical battery percentage (0-100), returns null if unavailable on device/platform
  static Future<int?> getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (level >= 0 && level <= 100) {
        return level;
      }
      return null;
    } catch (e) {
      debugPrint('[Battery] Notice: Unable to query native battery level: $e');
      return null;
    }
  }

  /// Checks if device is actively charging or connected to power
  static Future<bool> isCharging() async {
    try {
      final state = await _battery.batteryState;
      return state == BatteryState.charging || state == BatteryState.full;
    } catch (e) {
      return false;
    }
  }

  /// Stream of battery state changes (charging/discharging)
  static Stream<BatteryState> get onBatteryStateChanged => _battery.onBatteryStateChanged;
}
