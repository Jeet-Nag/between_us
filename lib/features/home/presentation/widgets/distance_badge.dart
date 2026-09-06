import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/typography.dart';
import '../../../../core/utils/distance_calculator.dart';

class DistanceBadge extends StatelessWidget {
  final ProximityResult proximity;

  const DistanceBadge({
    super.key,
    required this.proximity,
  });

  String _getBadgeLabel(ProximityState state) {
    switch (state) {
      case ProximityState.together:
        return 'TOGETHER';
      case ProximityState.veryClose:
        return 'VERY CLOSE';
      case ProximityState.nearby:
        return 'NEARBY';
      case ProximityState.gettingCloser:
        return 'GETTING CLOSER';
      case ProximityState.longDistance:
        return 'LONG DISTANCE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: proximity.stateColor.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: proximity.stateColor.withOpacity(0.12),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: proximity.stateColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: proximity.stateColor.withOpacity(0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getBadgeLabel(proximity.state),
                style: AppTypography.proximityBadge.copyWith(
                  color: proximity.stateColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            proximity.formattedDistance,
            style: AppTypography.distanceNumber,
          ),
          const SizedBox(height: 4),
          Text(
            proximity.emotionalSubtitle,
            textAlign: TextAlign.center,
            style: AppTypography.emotionalQuote.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
