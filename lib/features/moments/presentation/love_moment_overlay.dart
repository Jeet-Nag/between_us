import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../service/moments_engine.dart';
import 'widgets/heart_particles.dart';

class LoveMomentOverlay extends StatelessWidget {
  final ReceivedMoment moment;
  final VoidCallback onDismiss;
  final Function(MomentType) onSendBack;

  const LoveMomentOverlay({
    super.key,
    required this.moment,
    required this.onDismiss,
    required this.onSendBack,
  });

  String _getMomentTitle() {
    switch (moment.type) {
      case MomentType.missYou:
        return '${moment.senderName} misses you ❤️';
      case MomentType.hug:
        return '${moment.senderName} sent you a warm hug 🫂';
      case MomentType.kiss:
        return '${moment.senderName} sent you a sweet kiss 😘';
      case MomentType.loveNote:
        return 'Love Note from ${moment.senderName} 💌';
    }
  }

  IconData _getMomentIcon() {
    switch (moment.type) {
      case MomentType.missYou:
        return Icons.favorite_rounded;
      case MomentType.hug:
        return Icons.people_alt_rounded;
      case MomentType.kiss:
        return Icons.sentiment_very_satisfied_rounded;
      case MomentType.loveNote:
        return Icons.mark_email_unread_rounded;
    }
  }

  Color _getMomentColor() {
    switch (moment.type) {
      case MomentType.missYou:
        return AppColors.primaryRose;
      case MomentType.hug:
        return AppColors.warmAmber;
      case MomentType.kiss:
        return AppColors.softLavender;
      case MomentType.loveNote:
        return AppColors.tealProximity;
    }
  }

  @override
  Widget build(BuildContext context) {
    HapticFeedback.heavyImpact();
    final color = _getMomentColor();

    return Material(
      color: Colors.black.withOpacity(0.88),
      child: Stack(
        children: [
          // Floating Heart Particle Field
          const Positioned.fill(child: HeartParticles()),

          // Center Emotional Content Card
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 1),

                  // Glowing Center Icon
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 36,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(_getMomentIcon(), color: color, size: 48),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    _getMomentTitle(),
                    textAlign: TextAlign.center,
                    style: AppTypography.displayMedium.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),

                  if (moment.message != null && moment.message!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Text(
                        '“${moment.message}”',
                        textAlign: TextAlign.center,
                        style: AppTypography.emotionalQuote.copyWith(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Text(
                      'Thinking of you across the distance right now.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),
                  ],

                  const Spacer(flex: 1),

                  // Send Hug / Love Back quick action
                  ElevatedButton.icon(
                    onPressed: () {
                      onSendBack(MomentType.hug);
                      onDismiss();
                    },
                    icon: const Icon(Icons.people_alt_rounded, size: 20),
                    label: Text(
                      'Send a Warm Hug Back 🫂',
                      style: AppTypography.titleMedium.copyWith(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRose,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Close button
                  TextButton(
                    onPressed: onDismiss,
                    child: Text(
                      'Close',
                      style: AppTypography.titleMedium.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
