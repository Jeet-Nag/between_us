import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class HeartParticles extends StatefulWidget {
  const HeartParticles({super.key});

  @override
  State<HeartParticles> createState() => _HeartParticlesState();
}

class _HeartParticlesState extends State<HeartParticles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    for (int i = 0; i < 28; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: 0.8 + _random.nextDouble() * 0.4,
        size: 14 + _random.nextDouble() * 22,
        speed: 0.15 + _random.nextDouble() * 0.35,
        opacity: 0.4 + _random.nextDouble() * 0.6,
        color: i % 3 == 0
            ? AppColors.primaryRose
            : (i % 3 == 1 ? AppColors.warmAmber : AppColors.softLavender),
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(_particles, _controller.value),
        );
      },
    );
  }
}

class _Particle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;
  Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final currentY = (p.y - progress * p.speed) % 1.2;
      final actualY = currentY * size.height;
      final actualX = (p.x * size.width) + math.sin(progress * 4 + p.x * 10) * 15;

      final paint = Paint()
        ..color = p.color.withOpacity((p.opacity * (1.0 - (actualY / size.height))).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      // Draw subtle heart shape
      _drawHeart(canvas, Offset(actualX, actualY), p.size, paint);
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final width = size;
    final height = size;

    path.moveTo(center.dx, center.dy + height * 0.3);
    path.cubicTo(
      center.dx - width * 0.6,
      center.dy - height * 0.3,
      center.dx - width * 0.6,
      center.dy - height * 0.8,
      center.dx,
      center.dy - height * 0.4,
    );
    path.cubicTo(
      center.dx + width * 0.6,
      center.dy - height * 0.8,
      center.dx + width * 0.6,
      center.dy - height * 0.3,
      center.dx,
      center.dy + height * 0.3,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
