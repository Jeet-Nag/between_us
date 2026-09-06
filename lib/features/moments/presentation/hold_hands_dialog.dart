import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../service/moments_engine.dart';
import 'widgets/heart_particles.dart';

class HoldHandsDialog extends StatefulWidget {
  final String partnerName;

  const HoldHandsDialog({
    super.key,
    required this.partnerName,
  });

  @override
  State<HoldHandsDialog> createState() => _HoldHandsDialogState();
}

class _HoldHandsDialogState extends State<HoldHandsDialog> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String? _savedSummaryMessage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onPointerDown(MomentsEngine engine) {
    if (_savedSummaryMessage != null) return;
    engine.startHoldingHands();
  }

  void _onPointerUp(MomentsEngine engine) {
    final duration = engine.holdingDurationSeconds;
    final wasBoth = engine.bothHoldingHands;
    engine.stopHoldingHands();

    if (wasBoth && duration >= 3) {
      setState(() {
        _savedSummaryMessage = 'Held hands with ${widget.partnerName} for $duration seconds ❤️';
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final momentsEngine = context.watch<MomentsEngine>();
    final isHolding = momentsEngine.isHoldingHandsLocal;
    final isPartnerHolding = momentsEngine.isHoldingHandsPartner;
    final bothHolding = momentsEngine.bothHoldingHands;
    final duration = momentsEngine.holdingDurationSeconds;

    return Material(
      color: Colors.black.withOpacity(0.92),
      child: Stack(
        children: [
          // Floating Heart Particle Field
          if (bothHolding) const Positioned.fill(child: HeartParticles()),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
              child: Column(
                children: [
                  // Top bar with close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hold Hands 🫶',
                        style: AppTypography.titleLarge.copyWith(color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                        onPressed: () {
                          if (isHolding) momentsEngine.stopHoldingHands();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Touch and hold your thumb on the heart. When you both hold together, feel your connection across the distance.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),

                  const Spacer(),

                  // Center Interactive Heart Button
                  Center(
                    child: Listener(
                      onPointerDown: (_) => _onPointerDown(momentsEngine),
                      onPointerUp: (_) => _onPointerUp(momentsEngine),
                      onPointerCancel: (_) => _onPointerUp(momentsEngine),
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (ctx, child) {
                          final scale = bothHolding ? _pulseAnimation.value : (isHolding ? 1.05 : 1.0);
                          final glowColor = bothHolding
                              ? AppColors.primaryRose
                              : (isHolding ? AppColors.warmAmber : AppColors.surfaceBorder);

                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: bothHolding
                                    ? AppColors.primaryRoseSoft.withOpacity(0.4)
                                    : (isHolding
                                        ? AppColors.warmAmber.withOpacity(0.2)
                                        : AppColors.surfaceElevated),
                                border: Border.all(
                                  color: bothHolding
                                      ? AppColors.primaryRose
                                      : (isHolding ? AppColors.warmAmber : AppColors.surfaceBorder),
                                  width: bothHolding ? 4 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: glowColor.withOpacity(bothHolding ? 0.6 : (isHolding ? 0.3 : 0.05)),
                                    blurRadius: bothHolding ? 48 : (isHolding ? 24 : 10),
                                    spreadRadius: bothHolding ? 8 : 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    bothHolding
                                        ? Icons.favorite_rounded
                                        : (isHolding ? Icons.touch_app_rounded : Icons.fingerprint_rounded),
                                    color: bothHolding
                                        ? AppColors.primaryRose
                                        : (isHolding ? AppColors.warmAmber : AppColors.textSecondary),
                                    size: 64,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    bothHolding
                                        ? 'HOLDING'
                                        : (isHolding ? 'HOLDING...' : 'HOLD HERE'),
                                    style: AppTypography.titleMedium.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: bothHolding
                                          ? AppColors.primaryRose
                                          : (isHolding ? AppColors.warmAmber : AppColors.textMuted),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Dynamic State Feedback
                  if (_savedSummaryMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.tealProximity),
                      ),
                      child: Text(
                        _savedSummaryMessage!,
                        textAlign: TextAlign.center,
                        style: AppTypography.titleMedium.copyWith(color: AppColors.tealProximity, fontSize: 14),
                      ),
                    ),
                  ] else if (bothHolding) ...[
                    Column(
                      children: [
                        Text(
                          'Holding hands with ${widget.partnerName} ❤️',
                          style: AppTypography.titleLarge.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDuration(duration),
                          style: AppTypography.displayMedium.copyWith(
                            color: AppColors.primaryRose,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Heartbeats synchronized in real-time.',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ] else if (isHolding) ...[
                    Column(
                      children: [
                        Text(
                          'Waiting for ${widget.partnerName}...',
                          style: AppTypography.titleMedium.copyWith(color: AppColors.warmAmber),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Keep your thumb on the screen.',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ] else if (isPartnerHolding) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.warmAmber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.warmAmber.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite_rounded, color: AppColors.warmAmber, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.partnerName} is waiting to hold hands!',
                            style: AppTypography.titleMedium.copyWith(color: AppColors.warmAmber, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Press and hold to start',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
