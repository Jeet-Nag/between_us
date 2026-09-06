import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/typography.dart';
import '../../domain/memory_model.dart';

class MemoryCard extends StatelessWidget {
  final CoupleMemory memory;

  const MemoryCard({
    super.key,
    required this.memory,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM d, yyyy').format(memory.memoryDate);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryRoseSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: AppColors.primaryRose, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    dateStr,
                    style: AppTypography.titleMedium.copyWith(fontSize: 13, color: AppColors.warmAmber),
                  ),
                ],
              ),
              if (memory.locationName != null)
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      memory.locationName!,
                      style: AppTypography.bodySmall.copyWith(fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          Text(memory.title, style: AppTypography.titleMedium),
          const SizedBox(height: 6),

          if (memory.caption != null)
            Text(
              '“${memory.caption}”',
              style: AppTypography.emotionalQuote.copyWith(fontSize: 14, color: AppColors.textPrimary),
            ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Added by ${memory.createdByName}',
                style: AppTypography.bodySmall.copyWith(fontSize: 10, color: AppColors.textMuted),
              ),
              const Icon(Icons.favorite_rounded, size: 16, color: AppColors.primaryRose),
            ],
          ),
        ],
      ),
    );
  }
}
