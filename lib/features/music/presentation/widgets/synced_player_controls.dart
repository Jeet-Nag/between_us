import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/typography.dart';
import '../../../../core/utils/time_sync.dart';
import '../../domain/music_models.dart';
import '../../state/music_state.dart';

class SyncedPlayerControls extends StatelessWidget {
  final MusicState musicState;

  const SyncedPlayerControls({
    super.key,
    required this.musicState,
  });

  @override
  Widget build(BuildContext context) {
    final session = musicState.currentSession;
    if (session == null) return const SizedBox();

    final currentMs = session.positionMs;
    final totalMs = session.currentSong.durationMs;
    final progress = (currentMs / totalMs).clamp(0.0, 1.0);
    final isPlaying = session.playbackState == PlaybackState.playing;

    return Column(
      children: [
        // Sync Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: musicState.syncHealth == SyncHealth.synced
                  ? AppColors.tealProximity.withOpacity(0.4)
                  : AppColors.warning.withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_tethering_rounded,
                size: 14,
                color: musicState.syncHealth == SyncHealth.synced
                    ? AppColors.tealProximity
                    : AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                musicState.syncHealth == SyncHealth.synced ? 'SYNCED PLAYBACK' : 'ADJUSTING CLOCK…',
                style: AppTypography.proximityBadge.copyWith(
                  fontSize: 10,
                  color: musicState.syncHealth == SyncHealth.synced
                      ? AppColors.tealProximity
                      : AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Progress Slider
        SliderTheme(
          data: const SliderThemeData(
            trackHeight: 4,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: AppColors.primaryRose,
            inactiveTrackColor: AppColors.surfaceBorder,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: progress,
            onChanged: (val) {
              final target = (val * totalMs).toInt();
              musicState.seekTo(target);
            },
          ),
        ),

        // Time Labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(TimeSync.formatDurationMs(currentMs), style: AppTypography.bodySmall),
              Text(TimeSync.formatDurationMs(totalMs), style: AppTypography.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Playback Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded, size: 36, color: AppColors.textPrimary),
              onPressed: () => musicState.playPrevious(),
            ),
            const SizedBox(width: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryRose,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRose.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 34,
                  color: Colors.white,
                ),
                onPressed: () => musicState.togglePlayPause(),
              ),
            ),
            const SizedBox(width: 24),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, size: 36, color: AppColors.textPrimary),
              onPressed: () => musicState.playNext(),
            ),
          ],
        ),
      ],
    );
  }
}
