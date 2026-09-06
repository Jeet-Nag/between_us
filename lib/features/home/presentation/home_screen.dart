import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../auth_pairing/state/couple_state.dart';
import '../../countdown/presentation/widgets/meeting_countdown_card.dart';
import '../../de_escalation/presentation/make_up_dialog.dart';
import '../../moments/presentation/love_moment_overlay.dart';
import '../../moments/service/moments_engine.dart';
import '../state/presence_state.dart';
import 'widgets/ambient_map_view.dart';
import 'widgets/distance_badge.dart';
import 'widgets/emotional_actions_bar.dart';
import 'widgets/partner_bubble.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenChat;
  final VoidCallback onOpenTogether;
  final VoidCallback onOpenMemories;

  const HomeScreen({
    super.key,
    required this.onOpenChat,
    required this.onOpenTogether,
    required this.onOpenMemories,
  });

  void _showSetCountdownDialog(BuildContext context, CoupleState coupleState) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 14));
    final titleController = TextEditingController(text: 'Reunion');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('Set Meeting Countdown', style: AppTypography.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Event Title (e.g. Reunion, Flight to Mumbai)',
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Target Date'),
              subtitle: Text(
                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                style: AppTypography.titleMedium.copyWith(color: AppColors.primaryRose),
              ),
              trailing: const Icon(Icons.calendar_month_rounded),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (picked != null) {
                  selectedDate = picked;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRose),
            onPressed: () {
              coupleState.updateMeetingCountdown(
                date: selectedDate,
                title: titleController.text.trim().isEmpty ? 'Reunion' : titleController.text.trim(),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save Countdown', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSendNoteDialog(BuildContext context, MomentsEngine momentsEngine) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Row(
          children: [
            const Icon(Icons.mark_email_read_rounded, color: AppColors.tealProximity, size: 22),
            const SizedBox(width: 8),
            Text('Send a Love Note 💌', style: AppTypography.titleLarge),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: AppTypography.bodyLarge,
          decoration: const InputDecoration(
            hintText: 'Write something sweet to appear across their screen...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.tealProximity),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                momentsEngine.sendMoment(MomentType.loveNote, customMessage: text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Send Note', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coupleState = context.watch<CoupleState>();
    final presenceState = context.watch<PresenceState>();
    final momentsEngine = context.watch<MomentsEngine>();

    final couple = coupleState.couple;
    final myName = couple?.user.displayName ?? 'You';
    final partnerName = couple?.partner?.displayName ?? 'Partner';
    final activeMoment = momentsEngine.activeReceivedMoment;

    // Calculate days together
    final daysTogether = DateTime.now().difference(couple?.createdAt ?? DateTime.now()).inDays + 1;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite_rounded, color: AppColors.primaryRose, size: 18),
                const SizedBox(width: 8),
                Text('Our Space', style: AppTypography.titleMedium),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Text('Day $daysTogether', style: AppTypography.bodySmall.copyWith(color: AppColors.warmAmber)),
                ),
              ],
            ),
            actions: [
              // Angry / Make Up Mode quick assistant if partner is upset
              if (presenceState.partnerMood == MoodType.angry)
                IconButton(
                  tooltip: 'Make Up Assistant',
                  icon: const Icon(Icons.support_agent_rounded, color: AppColors.warning),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => MakeUpDialog(
                        onSendMessage: (msg) {
                          momentsEngine.sendMoment(MomentType.loveNote, customMessage: msg);
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Partner Avatars & Presence Status
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      PartnerBubble(
                        name: myName,
                        initials: couple?.user.initials ?? 'Y',
                        isMe: true,
                        mood: presenceState.myMood,
                        batteryLevel: presenceState.myBatteryLevel,
                        isOnline: true,
                      ),
                      
                      // Heart Connection Center
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surfaceBorder),
                            ),
                            child: const Icon(Icons.all_inclusive_rounded, color: AppColors.primaryRose, size: 20),
                          ),
                          const SizedBox(height: 6),
                          Text('CONNECTED', style: AppTypography.proximityBadge.copyWith(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ),

                      PartnerBubble(
                        name: partnerName,
                        initials: couple?.partner?.initials ?? 'P',
                        isMe: false,
                        mood: presenceState.partnerMood,
                        batteryLevel: presenceState.partnerLocation?.batteryLevel,
                        isOnline: presenceState.isPartnerOnline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Ambient Map View
                AmbientMapView(
                  myLocation: presenceState.myLocation,
                  partnerLocation: presenceState.partnerLocation,
                  myName: myName,
                  partnerName: partnerName,
                  partnerFreshness: presenceState.partnerFreshnessLabel,
                ),
                const SizedBox(height: 16),

                // Distance and Proximity Status Badge
                DistanceBadge(proximity: presenceState.proximity),
                const SizedBox(height: 16),

                // Meeting Countdown
                MeetingCountdownCard(
                  targetDate: couple?.nextMeetingDate,
                  title: couple?.nextMeetingTitle ?? 'Reunion',
                  onEdit: () => _showSetCountdownDialog(context, coupleState),
                ),
                const SizedBox(height: 18),

                // Emotional Quick Actions
                EmotionalActionsBar(
                  presence: presenceState,
                  momentsEngine: momentsEngine,
                  onOpenNoteDialog: () => _showSendNoteDialog(context, momentsEngine),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Fullscreen Love Moment Overlay
        if (activeMoment != null)
          Positioned.fill(
            child: LoveMomentOverlay(
              moment: activeMoment,
              onDismiss: () => momentsEngine.dismissActiveMoment(),
              onSendBack: (type) => momentsEngine.sendMoment(type),
            ),
          ),
      ],
    );
  }
}
