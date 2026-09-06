import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/typography.dart';
import '../../domain/message_model.dart';
import 'voice_note_player.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final Function(String emoji) onReact;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.onReact,
  });

  void _showReactionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '🥰', '🥺', '🫂', '🔥', '😂'].map((emoji) {
                return InkWell(
                  onTap: () {
                    onReact(emoji);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a').format(message.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showReactionMenu(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primaryRose : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: isMe ? null : Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.type == MessageType.text)
                      Text(
                        message.content,
                        style: AppTypography.bodyLarge.copyWith(
                          color: isMe ? Colors.white : AppColors.textPrimary,
                        ),
                      )
                    else if (message.type == MessageType.voiceNote)
                      VoiceNotePlayer(
                        durationMs: message.audioDurationMs ?? 10000,
                        isMe: isMe,
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 3),

              // Timestamp & Disappearing Indicator & Reactions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isDisappearing) ...[
                    const Icon(Icons.timer_outlined, size: 11, color: AppColors.warmAmber),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    timeStr,
                    style: AppTypography.bodySmall.copyWith(fontSize: 10),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.done_all_rounded, size: 13, color: AppColors.tealProximity),
                  ],
                  if (message.reactions.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Text(
                        message.reactions.values.join(' '),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
