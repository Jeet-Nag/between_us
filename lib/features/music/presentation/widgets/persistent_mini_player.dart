import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/typography.dart';
import '../../domain/music_models.dart';
import '../../state/music_state.dart';

class PersistentMiniPlayer extends StatelessWidget {
  final MusicState musicState;
  final VoidCallback onTap;

  const PersistentMiniPlayer({
    super.key,
    required this.musicState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final session = musicState.currentSession;
    if (session == null) return const SizedBox();

    final isPlaying = session.playbackState == PlaybackState.playing;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primaryRose.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryRoseSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.music_note_rounded, color: AppColors.primaryRose, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    session.currentSong.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(fontSize: 13),
                  ),
                  Text(
                    'Listening together with partner',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.tealProximity, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.primaryRose,
                size: 26,
              ),
              onPressed: () => musicState.togglePlayPause(),
            ),
          ],
        ),
      ),
    );
  }
}
