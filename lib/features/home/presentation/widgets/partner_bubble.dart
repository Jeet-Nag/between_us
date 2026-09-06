import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/typography.dart';
import '../../state/presence_state.dart';

class PartnerBubble extends StatelessWidget {
  final String name;
  final String initials;
  final bool isMe;
  final MoodType mood;
  final int? batteryLevel;
  final bool isOnline;
  final VoidCallback? onTap;

  const PartnerBubble({
    super.key,
    required this.name,
    required this.initials,
    required this.isMe,
    required this.mood,
    this.batteryLevel,
    this.isOnline = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Outer Avatar Ring
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isMe ? AppColors.surfaceElevated : AppColors.deepWine,
                  border: Border.all(
                    color: isMe ? AppColors.softLavender : AppColors.primaryRose,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isMe ? AppColors.softLavender : AppColors.primaryRose).withOpacity(0.25),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: AppTypography.titleLarge.copyWith(
                      color: isMe ? AppColors.softLavender : AppColors.primaryRose,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Online / Offline Status Dot
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isOnline ? AppColors.online : AppColors.offline,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),

              // Mood Floating Pill
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    mood.emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Name and Label
          Text(
            isMe ? '$name (You)' : name,
            style: AppTypography.titleMedium.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 2),

          // Battery and Status Info
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (batteryLevel != null) ...[
                Icon(
                  batteryLevel! > 20 ? Icons.battery_charging_full_rounded : Icons.battery_alert_rounded,
                  size: 13,
                  color: batteryLevel! > 20 ? AppColors.textMuted : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  '$batteryLevel%',
                  style: AppTypography.bodySmall,
                ),
              ] else ...[
                const Icon(
                  Icons.battery_unknown_rounded,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Battery unavailable',
                  style: AppTypography.bodySmall.copyWith(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
