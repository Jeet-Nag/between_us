import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../moments/presentation/widgets/heart_particles.dart';
import '../state/call_state.dart';

class CallScreen extends StatefulWidget {
  final String partnerName;
  final String? initialMode;

  const CallScreen({
    super.key,
    required this.partnerName,
    this.initialMode,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _showHearts = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _triggerHeartsReaction() {
    setState(() => _showHearts = true);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showHearts = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final callState = context.watch<CallState>();

    // If call transitioned to idle/ended externally and user should return
    if (callState.status == CallStatus.idle && !callState.isInCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0B13),
      body: Stack(
        children: [
          // Floating Hearts Particles on Reaction
          if (_showHearts) const Positioned.fill(child: HeartParticles()),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  // Top Header / Call Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_rounded, color: AppColors.tealProximity, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'End-to-End Encrypted',
                              style: AppTypography.bodySmall.copyWith(fontSize: 10, color: AppColors.tealProximity),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRoseSoft.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryRose.withOpacity(0.4)),
                        ),
                        child: Text(
                          callState.callContext,
                          style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.primaryRose),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Center Avatar & Ringing / In-Call Display
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (ctx, child) {
                        final isRinging = callState.isOutgoing || callState.isIncoming;
                        final scale = isRinging ? _pulseAnimation.value : 1.0;

                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceElevated,
                              border: Border.all(
                                color: callState.isConnected ? AppColors.tealProximity : AppColors.primaryRose,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (callState.isConnected ? AppColors.tealProximity : AppColors.primaryRose)
                                      .withOpacity(0.35),
                                  blurRadius: 36,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                widget.partnerName.isNotEmpty
                                    ? widget.partnerName.substring(0, 1).toUpperCase()
                                    : 'P',
                                style: AppTypography.displayLarge.copyWith(
                                  fontSize: 48,
                                  color: callState.isConnected ? AppColors.tealProximity : AppColors.primaryRose,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Partner Name
                  Text(
                    widget.partnerName,
                    style: AppTypography.displayMedium.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),

                  // Call Status / Duration
                  if (callState.isConnected) ...[
                    Text(
                      _formatDuration(callState.callDurationSeconds),
                      style: AppTypography.titleLarge.copyWith(color: AppColors.tealProximity),
                    ),
                  ] else if (callState.isOutgoing) ...[
                    Text(
                      'Calling partner...',
                      style: AppTypography.titleMedium.copyWith(color: AppColors.warmAmber),
                    ),
                  ] else if (callState.isIncoming) ...[
                    Text(
                      'Incoming private call...',
                      style: AppTypography.titleMedium.copyWith(color: AppColors.primaryRose),
                    ),
                  ] else if (callState.status == CallStatus.ended) ...[
                    Text(
                      'Call Ended (${_formatDuration(callState.callDurationSeconds)})',
                      style: AppTypography.titleMedium.copyWith(color: AppColors.textMuted),
                    ),
                  ],

                  const Spacer(flex: 2),

                  // Quick Love Reaction floating hearts button while connected
                  if (callState.isConnected) ...[
                    IconButton(
                      icon: const Icon(Icons.favorite_rounded, color: AppColors.primaryRose, size: 36),
                      tooltip: 'Send Hearts',
                      onPressed: _triggerHeartsReaction,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Controls Bar
                  if (callState.isIncoming) ...[
                    // Incoming Call Accept / Decline Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCallActionCircle(
                          icon: Icons.call_end_rounded,
                          color: AppColors.error,
                          label: 'Decline',
                          onTap: () {
                            callState.declineCall();
                            Navigator.pop(context);
                          },
                        ),
                        _buildCallActionCircle(
                          icon: Icons.call_rounded,
                          color: AppColors.tealProximity,
                          label: 'Accept',
                          onTap: () => callState.acceptCall(),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Connected / Outgoing Call Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mute button
                        _buildControlIconButton(
                          icon: callState.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          isActive: callState.isMuted,
                          label: callState.isMuted ? 'Muted' : 'Mute',
                          onTap: () => callState.toggleMute(),
                        ),

                        // Video toggle
                        _buildControlIconButton(
                          icon: callState.isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                          isActive: callState.isVideoOff,
                          label: callState.isVideoOff ? 'Video Off' : 'Video',
                          onTap: () => callState.toggleVideo(),
                        ),

                        // Speaker toggle
                        _buildControlIconButton(
                          icon: callState.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                          isActive: callState.isSpeakerOn,
                          label: 'Speaker',
                          onTap: () => callState.toggleSpeaker(),
                        ),

                        // Flip camera
                        _buildControlIconButton(
                          icon: Icons.flip_camera_ios_rounded,
                          isActive: false,
                          label: 'Flip',
                          onTap: () => callState.flipCamera(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // End Call button
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          callState.endCall();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.error,
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlIconButton({
    required IconData icon,
    required bool isActive,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: isActive ? Colors.white : AppColors.surfaceElevated,
            foregroundColor: isActive ? Colors.black : Colors.white,
            padding: const EdgeInsets.all(14),
          ),
          icon: Icon(icon, size: 24),
          onPressed: onTap,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildCallActionCircle({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTypography.titleMedium.copyWith(fontSize: 13, color: Colors.white),
        ),
      ],
    );
  }
}
