import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/typography.dart';
import '../../../../core/utils/time_sync.dart';

class MeetingCountdownCard extends StatefulWidget {
  final DateTime? targetDate;
  final String title;
  final VoidCallback onEdit;

  const MeetingCountdownCard({
    super.key,
    required this.targetDate,
    required this.title,
    required this.onEdit,
  });

  @override
  State<MeetingCountdownCard> createState() => _MeetingCountdownCardState();
}

class _MeetingCountdownCardState extends State<MeetingCountdownCard> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    if (widget.targetDate == null) return;
    
    // Use NTP server-compensated timestamp to prevent device clock skew desync
    final nowSynced = TimeSync.syncedEpochToDateTime(TimeSync.nowSyncedMs);
    final diff = widget.targetDate!.difference(nowSynced);
    
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.targetDate == null) {
      return InkWell(
        onTap: widget.onEdit,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primaryRoseSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_rounded, color: AppColors.primaryRose, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Next Time We Meet', style: AppTypography.titleMedium),
                    Text('Set a date to count down together', style: AppTypography.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline_rounded, color: AppColors.softLavender, size: 20),
            ],
          ),
        ),
      );
    }

    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final isToday = days == 0 && hours == 0 && minutes == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryRose.withOpacity(0.35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.deepWine.withOpacity(0.3),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.flight_takeoff_rounded, color: AppColors.warmAmber, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    widget.title.toUpperCase(),
                    style: AppTypography.proximityBadge.copyWith(color: AppColors.warmAmber),
                  ),
                ],
              ),
              IconButton(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.textMuted),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isToday) ...[
            Text('TODAY ❤️', style: AppTypography.displayMedium.copyWith(color: AppColors.primaryRose)),
            const SizedBox(height: 4),
            Text('The countdown is over. Enjoy every second together.', style: AppTypography.emotionalQuote),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTimeUnit(days.toString().padLeft(2, '0'), 'DAYS'),
                Text(':', style: AppTypography.displayMedium.copyWith(color: AppColors.textMuted)),
                _buildTimeUnit(hours.toString().padLeft(2, '0'), 'HOURS'),
                Text(':', style: AppTypography.displayMedium.copyWith(color: AppColors.textMuted)),
                _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'MINS'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Text(value, style: AppTypography.displayMedium.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.bodySmall.copyWith(letterSpacing: 1.0, fontSize: 10)),
      ],
    );
  }
}
