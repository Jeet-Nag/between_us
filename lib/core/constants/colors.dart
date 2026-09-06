import 'package:flutter/material.dart';

/// Intimate, cinematic, and warm color palette designed specifically
/// for two connected partners. Avoids generic pink or loud gradients.
class AppColors {
  // Dark Atmosphere Palette (Primary experience)
  static const Color background = Color(0xFF0F0E17);
  static const Color surface = Color(0xFF1A1829);
  static const Color surfaceElevated = Color(0xFF232138);
  static const Color surfaceBorder = Color(0xFF2E2B47);
  
  // Emotional Accent Colors
  static const Color primaryRose = Color(0xFFFF5470);
  static const Color primaryRoseSoft = Color(0x33FF5470);
  static const Color warmAmber = Color(0xFFFFD166);
  static const Color softLavender = Color(0xFFC4B5FD);
  static const Color deepWine = Color(0xFF4A1525);
  static const Color tealProximity = Color(0xFF2EC4B6);
  static const Color softTealBg = Color(0x1F2EC4B6);
  
  // Proximity State Colors
  static const Color proximityLong = Color(0xFF8E8CA3);
  static const Color proximityCloser = Color(0xFFFFD166);
  static const Color proximityNearby = Color(0xFF64DFDF);
  static const Color proximityVeryClose = Color(0xFF48CAE4);
  static const Color proximityTogether = Color(0xFFFF5470);

  // Neutral Typography & Icons
  static const Color textPrimary = Color(0xFFFFFFFE);
  static const Color textSecondary = Color(0xFFA7A9BE);
  static const Color textMuted = Color(0xFF6B6E8A);
  static const Color divider = Color(0xFF26243A);
  
  // Status Colors
  static const Color success = Color(0xFF2EC4B6);
  static const Color warning = Color(0xFFFFB703);
  static const Color error = Color(0xFFEF476F);
  static const Color online = Color(0xFF10B981);
  static const Color offline = Color(0xFF6B7280);

  // Gradient definitions for subtle atmospheric glows
  static const LinearGradient ambientGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x33FF5470),
      Color(0x110F0E17),
      Color(0x22C4B5FD),
    ],
  );

  static const LinearGradient cardGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF25223D),
      Color(0xFF1A1829),
    ],
  );
}
