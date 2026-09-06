import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/typography.dart';
import '../../state/presence_state.dart';

class AmbientMapView extends StatelessWidget {
  final PartnerLocation? myLocation;
  final PartnerLocation? partnerLocation;
  final String myName;
  final String partnerName;
  final String partnerFreshness;

  const AmbientMapView({
    super.key,
    this.myLocation,
    this.partnerLocation,
    required this.myName,
    required this.partnerName,
    this.partnerFreshness = 'Waiting for location…',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Ambient Starry / Grid Canvas representing distance space
            CustomPaint(
              size: Size.infinite,
              painter: _AmbientSpacePainter(),
            ),

            // Connecting Geodesic Arc
            CustomPaint(
              size: Size.infinite,
              painter: _ConnectionArcPainter(),
            ),

            // My Pin (Left side)
            Positioned(
              left: 36,
              top: 75,
              child: _buildLocationPin(
                label: myName,
                subtitle: myLocation != null ? 'Active now' : 'Locating…',
                color: AppColors.softLavender,
                isLeft: true,
              ),
            ),

            // Partner Pin (Right side)
            Positioned(
              right: 36,
              bottom: 60,
              child: _buildLocationPin(
                label: partnerName,
                subtitle: partnerLocation != null ? partnerFreshness : 'Waiting…',
                color: AppColors.primaryRose,
                isLeft: false,
              ),
            ),

            // Privacy & Map Provider Tag
            Positioned(
              bottom: 12,
              left: 16,
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Private Partner-to-Partner Location',
                    style: AppTypography.bodySmall.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPin({
    required String label,
    required String subtitle,
    required Color color,
    required bool isLeft,
  }) {
    return Column(
      crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text(
                label,
                style: AppTypography.titleMedium.copyWith(fontSize: 12, color: Colors.white),
              ),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(fontSize: 9, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.6),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmbientSpacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E1B33)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Draw subtle latitude / longitude grid lines
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double j = 0; j < size.height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), paint);
    }

    // Subtle atmospheric stars
    final starPaint = Paint()..color = Colors.white.withOpacity(0.2);
    final offsets = [
      Offset(size.width * 0.15, size.height * 0.2),
      Offset(size.width * 0.45, size.height * 0.35),
      Offset(size.width * 0.75, size.height * 0.15),
      Offset(size.width * 0.85, size.height * 0.75),
      Offset(size.width * 0.3, size.height * 0.8),
    ];
    for (var o in offsets) {
      canvas.drawCircle(o, 1.5, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ConnectionArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const start = Offset(45, 95);
    final end = Offset(size.width - 45, size.height - 70);

    final path = Path();
    path.moveTo(start.dx, start.dy);

    final controlPoint1 = Offset(size.width * 0.35, 20);
    final controlPoint2 = Offset(size.width * 0.65, size.height - 20);

    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      end.dx,
      end.dy,
    );

    final glowPaint = Paint()
      ..color = AppColors.primaryRose.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;

    final linePaint = Paint()
      ..color = AppColors.primaryRose
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
