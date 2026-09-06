import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:between_us/core/constants/colors.dart';
import 'package:between_us/core/constants/typography.dart';
import 'package:between_us/features/moments/service/moments_engine.dart';
import 'package:between_us/features/home/state/presence_state.dart';

class EmotionalActionsBar extends StatelessWidget {
  final PresenceState presence;
  final MomentsEngine momentsEngine;
  final VoidCallback onOpenNoteDialog;

  const EmotionalActionsBar({
    super.key,
    required this.presence,
    required this.momentsEngine,
    required this.onOpenNoteDialog,
  });

  void _triggerMoment(BuildContext context, MomentType type) {
    HapticFeedback.mediumImpact();
    momentsEngine.sendMoment(type);

    String label;
    switch (type) {
      case MomentType.missYou:
        label = 'Miss You sent ❤️';
        break;
      case MomentType.hug:
        label = 'Warm Hug sent 🫂';
        break;
      case MomentType.kiss:
        label = 'Sweet Kiss sent 😘';
        break;
      case MomentType.loveNote:
        label = 'Love Note sent 💌';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label, style: AppTypography.titleMedium.copyWith(fontSize: 14)),
        backgroundColor: AppColors.surfaceElevated,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showMoodPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('How are you feeling right now?', style: AppTypography.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Your partner will see this quietly on their home screen.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: MoodType.values.map((mood) {
                    final isSelected = presence.myMood == mood;
                    return ChoiceChip(
                      label: Text('${mood.emoji} ${mood.label}'),
                      selected: isSelected,
                      selectedColor: AppColors.primaryRose.withOpacity(0.25),
                      backgroundColor: AppColors.surface,
                      labelStyle: AppTypography.titleMedium.copyWith(
                        fontSize: 13,
                        color: isSelected ? AppColors.primaryRose : AppColors.textSecondary,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryRose : AppColors.surfaceBorder,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onSelected: (val) {
                        if (val) {
                          presence.setMyMood(mood);
                          Navigator.pop(context);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quick Moments', style: AppTypography.titleMedium),
            TextButton.icon(
              onPressed: () => _showMoodPicker(context),
              icon: Text(presence.myMood.emoji, style: const TextStyle(fontSize: 16)),
              label: Text(
                'My Mood: ${presence.myMood.label}',
                style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.favorite_rounded,
                label: 'Miss You',
                color: AppColors.primaryRose,
                onTap: () => _triggerMoment(context, MomentType.missYou),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.people_alt_rounded,
                label: 'Hug',
                color: AppColors.warmAmber,
                onTap: () => _triggerMoment(context, MomentType.hug),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.sentiment_very_satisfied_rounded,
                label: 'Kiss',
                color: AppColors.softLavender,
                onTap: () => _triggerMoment(context, MomentType.kiss),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.mark_email_read_rounded,
                label: 'Note',
                color: AppColors.tealProximity,
                onTap: onOpenNoteDialog,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
