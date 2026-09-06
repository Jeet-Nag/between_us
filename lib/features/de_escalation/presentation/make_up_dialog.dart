import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';

class MakeUpDialog extends StatefulWidget {
  final Function(String) onSendMessage;

  const MakeUpDialog({
    super.key,
    required this.onSendMessage,
  });

  @override
  State<MakeUpDialog> createState() => _MakeUpDialogState();
}

class _MakeUpDialogState extends State<MakeUpDialog> {
  final TextEditingController _customMessageController = TextEditingController();

  final List<Map<String, String>> _templates = [
    {
      'title': '💌 Gentle Apology',
      'body': 'I hate feeling distant from you when we’re already so far apart. I’m sorry for my part, and I want to talk when you’re ready.',
    },
    {
      'title': '🫂 I’m Still Here',
      'body': 'Even when things feel tough, I love you and I’m in this with you. Let’s take a breath and figure this out together.',
    },
    {
      'title': '⏳ Need Some Space',
      'body': 'I love you very much, but I need a little bit of quiet time to clear my head before we talk. Not going anywhere.',
    },
    {
      'title': '📞 Can We Talk?',
      'body': 'Texting is making this harder than it needs to be. Can we hop on a quick call to hear each other’s voices?',
    },
  ];

  @override
  void dispose() {
    _customMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warmAmber.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.handshake_rounded, color: AppColors.warmAmber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Make Up Assistant', style: AppTypography.titleLarge),
                      Text('Saying what you mean with care', style: AppTypography.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Long distance makes misunderstandings hurt more. Pick a gentle message or personalize one:',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 220,
              child: ListView.separated(
                itemCount: _templates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final t = _templates[i];
                  return InkWell(
                    onTap: () {
                      widget.onSendMessage(t['body']!);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['title']!, style: AppTypography.titleMedium.copyWith(fontSize: 13, color: AppColors.warmAmber)),
                          const SizedBox(height: 4),
                          Text(t['body']!, style: AppTypography.bodySmall.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: AppTypography.bodyMedium),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
