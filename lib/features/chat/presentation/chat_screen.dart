import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../auth_pairing/state/couple_state.dart';
import '../../de_escalation/presentation/make_up_dialog.dart';
import '../service/voice_recorder_service.dart';
import '../state/chat_state.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final VoiceRecorderService _voiceRecorder = VoiceRecorderService();
  bool _isRecordingVoice = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _voiceRecorder.dispose();
    super.dispose();
  }

  void _sendMessage(ChatState chatState) {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    chatState.sendTextMessage(text);
    _textController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleVoiceNoteAction(ChatState chatState) async {
    if (!_isRecordingVoice) {
      final started = await _voiceRecorder.startRecording();
      if (started) {
        setState(() => _isRecordingVoice = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recording voice note... Tap mic again to send.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission required for voice notes.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      final result = await _voiceRecorder.stopRecording();
      setState(() => _isRecordingVoice = false);
      if (result != null) {
        final durationMs = result['durationMs'] as int? ?? 5000;
        chatState.sendVoiceNote(durationMs: durationMs);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupleState = context.watch<CoupleState>();
    final chatState = context.watch<ChatState>();

    final partner = coupleState.couple?.partner;
    final partnerName = partner?.displayName ?? 'Partner';
    final myId = coupleState.couple?.user.id ?? 'me';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(partnerName, style: AppTypography.titleMedium),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.online,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Connected & Private',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.online, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Make Up Assistant',
            icon: const Icon(Icons.handshake_rounded, color: AppColors.warmAmber),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => MakeUpDialog(
                  onSendMessage: (msg) => chatState.sendTextMessage(msg),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Disappearing Messages',
            icon: Icon(
              Icons.timer_outlined,
              color: chatState.disappearingEnabled ? AppColors.warmAmber : AppColors.textMuted,
            ),
            onPressed: () {
              chatState.toggleDisappearing();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    chatState.disappearingEnabled
                        ? 'Disappearing messages enabled (24h)'
                        : 'Disappearing messages disabled',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: chatState.messages.length,
                itemBuilder: (ctx, i) {
                  final msg = chatState.messages[i];
                  final isMe = msg.senderId == myId;
                  return MessageBubble(
                    message: msg,
                    isMe: isMe,
                    onReact: (emoji) => chatState.addReaction(msg.id, emoji),
                  );
                },
              ),
            ),

            // Message Composer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
              ),
              child: Row(
                children: [
                  // Voice note button
                  IconButton(
                    icon: Icon(
                      _isRecordingVoice ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isRecordingVoice ? AppColors.error : AppColors.textSecondary,
                    ),
                    onPressed: () => _handleVoiceNoteAction(chatState),
                  ),

                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: AppTypography.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Message $partnerName...',
                        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(chatState),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primaryRose,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: () => _sendMessage(chatState),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
