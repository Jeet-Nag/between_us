import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/typography.dart';
import '../../../../core/utils/time_sync.dart';

class VoiceNotePlayer extends StatefulWidget {
  final int durationMs;
  final bool isMe;

  const VoiceNotePlayer({
    super.key,
    required this.durationMs,
    required this.isMe,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  bool _isPlaying = false;
  double _progress = 0.0;
  Timer? _playbackTimer;

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _startPlayback();
    } else {
      _playbackTimer?.cancel();
    }
  }

  void _startPlayback() {
    _playbackTimer?.cancel();
    const stepMs = 100;
    _playbackTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress += stepMs / widget.durationMs;
        if (_progress >= 1.0) {
          _progress = 0.0;
          _isPlaying = false;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isMe ? Colors.white : AppColors.primaryRose;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _togglePlay,
          icon: Icon(
            _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
            color: activeColor,
            size: 32,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 10),
        
        // Audio Waveform representation
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(24, (index) {
                  final height = 6.0 + (index % 5) * 3.5;
                  final isPlayed = (index / 24.0) <= _progress;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.0),
                      height: height,
                      decoration: BoxDecoration(
                        color: isPlayed ? activeColor : activeColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                TimeSync.formatDurationMs(widget.durationMs),
                style: AppTypography.bodySmall.copyWith(
                  color: widget.isMe ? Colors.white70 : AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
