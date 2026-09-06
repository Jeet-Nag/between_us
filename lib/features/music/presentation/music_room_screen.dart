import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../domain/music_models.dart';
import '../state/music_state.dart';
import 'widgets/synced_player_controls.dart';

class MusicRoomScreen extends StatefulWidget {
  const MusicRoomScreen({super.key});

  @override
  State<MusicRoomScreen> createState() => _MusicRoomScreenState();
}

class _MusicRoomScreenState extends State<MusicRoomScreen> {
  MusicCategory _selectedCategory = MusicCategory.romantic;

  void _showImportAudioSheet(BuildContext context, MusicState musicState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                Text('Add Music to Our Space', style: AppTypography.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Upload an MP3/M4A audio file from your device into your shared couple library.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRose,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.file_upload_rounded, color: Colors.white),
                  label: Text('Select Audio File from Device', style: AppTypography.titleMedium.copyWith(color: Colors.white)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    musicState.importAudioFile(category: _selectedCategory);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final musicState = context.watch<MusicState>();
    final session = musicState.currentSession;
    final filteredSongs = musicState.playlist.where((s) => s.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Together Music 🎵', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            tooltip: 'Import Audio File',
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryRose),
            onPressed: () => _showImportAudioSheet(context, musicState),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Uploading progress banner if file is transferring
            if (musicState.isUploadingAudio)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryRose.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Uploading Audio to Space...', style: AppTypography.titleMedium.copyWith(fontSize: 12)),
                        Text('${(musicState.uploadProgress * 100).toInt()}%', style: AppTypography.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: musicState.uploadProgress > 0 ? musicState.uploadProgress : null,
                      backgroundColor: AppColors.surface,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primaryRose),
                    ),
                  ],
                ),
              ),

            // Center Vinyl / Visualizer Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceElevated,
                      border: Border.all(color: AppColors.primaryRose, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRose.withOpacity(0.35),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.warmAmber,
                        ),
                        child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    session?.currentSong.title ?? 'No Track Selected',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session?.currentSong.artist ?? '',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 18),

                  SyncedPlayerControls(musicState: musicState),
                ],
              ),
            ),

            // Category Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: MusicCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(cat.label),
                      selected: isSelected,
                      selectedColor: AppColors.primaryRose.withOpacity(0.25),
                      backgroundColor: AppColors.surface,
                      labelStyle: AppTypography.titleMedium.copyWith(
                        fontSize: 12,
                        color: isSelected ? AppColors.primaryRose : AppColors.textSecondary,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryRose : AppColors.surfaceBorder,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Playlist Items
            Expanded(
              child: filteredSongs.isEmpty
                  ? Center(
                      child: Text('No songs in this category yet.', style: AppTypography.bodyMedium),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: filteredSongs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final song = filteredSongs[i];
                        final isCurrent = song.id == session?.currentSong.id;

                        return Dismissible(
                          key: Key(song.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ),
                          onDismissed: (_) => musicState.deleteSong(song.id),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isCurrent ? AppColors.surfaceElevated : AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCurrent ? AppColors.primaryRose.withOpacity(0.5) : AppColors.surfaceBorder,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                isCurrent ? Icons.volume_up_rounded : Icons.music_note_rounded,
                                color: isCurrent ? AppColors.primaryRose : AppColors.textMuted,
                              ),
                              title: Text(
                                song.title,
                                style: AppTypography.titleMedium.copyWith(
                                  fontSize: 14,
                                  color: isCurrent ? AppColors.primaryRose : AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                'Added by ${song.addedByName}',
                                style: AppTypography.bodySmall,
                              ),
                              onTap: () => musicState.selectTrack(song),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
