import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../state/memories_state.dart';
import 'widgets/memory_card.dart';

class MemoriesScreen extends StatelessWidget {
  const MemoriesScreen({super.key});

  void _showAddMemoryDialog(BuildContext context, MemoriesState memoriesState) {
    final titleController = TextEditingController();
    final captionController = TextEditingController();
    final locationController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('Add a Memory 📖', style: AppTypography.titleLarge),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Memory Title (e.g. Stargazing on FaceTime)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: captionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'What made this moment special?'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location / City'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRose),
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                memoriesState.addMemory(
                  title: titleController.text.trim(),
                  caption: captionController.text.trim(),
                  locationName: locationController.text.trim().isEmpty ? 'Our Special Place' : locationController.text.trim(),
                  memoryDate: selectedDate,
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save Memory', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memoriesState = context.watch<MemoriesState>();
    final onThisDay = memoriesState.onThisDayMemories;

    return Scaffold(
      appBar: AppBar(
        title: Text('Our Memories 📖', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            tooltip: 'Add Memory',
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryRose),
            onPressed: () => _showAddMemoryDialog(context, memoriesState),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          children: [
            // "On This Day" Resurfacing Card
            if (onThisDay.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryRose.withOpacity(0.2),
                      AppColors.surfaceElevated,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.primaryRose.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: AppColors.warmAmber, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'ON THIS DAY IN OUR STORY',
                          style: AppTypography.proximityBadge.copyWith(color: AppColors.warmAmber),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      onThisDay.first.title,
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '“${onThisDay.first.caption ?? ''}”',
                      style: AppTypography.emotionalQuote.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            Text('Our Story Timeline', style: AppTypography.titleMedium),
            const SizedBox(height: 12),

            ...memoriesState.memories.map((m) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: MemoryCard(memory: m),
              );
            }),
          ],
        ),
      ),
    );
  }
}
