import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/network/websocket_realtime_client.dart';
import '../../auth/state/auth_state.dart';
import '../../auth_pairing/state/couple_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _locationSharing = true;
  bool _quietHoursEnabled = true;
  String _callContext = '❤️ Just See You';

  void _showUnpairConfirmation(BuildContext context, CoupleState coupleState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Text('Disconnect Space?', style: AppTypography.titleLarge),
          ],
        ),
        content: Text(
          'This will revoke connection on both devices. Your private photos, messages, and location sharing will be securely closed.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              coupleState.unpairSpace();
              Navigator.pop(ctx);
            },
            child: const Text('Confirm Disconnect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startPrivateCall(BuildContext context, String mode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Row(
          children: [
            const Icon(Icons.videocam_rounded, color: AppColors.primaryRose),
            const SizedBox(width: 8),
            Text('Private Call ($mode)', style: AppTypography.titleLarge),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryRoseSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_rounded, color: AppColors.primaryRose, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Calling Partner...', style: AppTypography.titleMedium),
            const SizedBox(height: 6),
            Text('End-to-End Encrypted Session', style: AppTypography.bodySmall),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('End Call', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coupleState = context.watch<CoupleState>();
    final couple = coupleState.couple;
    final realtimeClient = WebSocketRealtimeClient();

    return Scaffold(
      appBar: AppBar(
        title: Text('Us & Settings 🔒', style: AppTypography.titleLarge),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          children: [
            // Couple Space Identity Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryRoseSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_rounded, color: AppColors.primaryRose, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${couple?.user.displayName ?? "You"} & ${couple?.partner?.displayName ?? "Partner"}',
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Space ID: ${couple?.id ?? "..."}',
                          style: AppTypography.bodySmall.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Call Modes Section
            Text('Contextual Calls', style: AppTypography.titleMedium),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.videocam_rounded, color: AppColors.primaryRose),
                    title: const Text('Call Partner'),
                    subtitle: Text('Mode: $_callContext'),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRose,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _startPrivateCall(context, _callContext),
                      child: const Text('Start Call', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Call Context:'),
                        DropdownButton<String>(
                          value: _callContext,
                          dropdownColor: AppColors.surfaceElevated,
                          underline: const SizedBox(),
                          items: [
                            '❤️ Just See You',
                            '🥺 Miss You',
                            '😊 Talk',
                            '🔥 Private',
                          ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _callContext = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Privacy & Location Settings
            Text('Privacy & Battery Controls', style: AppTypography.titleMedium),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Share Live Location'),
                    subtitle: const Text('Battery-aware updates when significant motion occurs'),
                    value: _locationSharing,
                    activeColor: AppColors.tealProximity,
                    onChanged: (val) {
                      setState(() => _locationSharing = val);
                    },
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  SwitchListTile(
                    title: const Text('Quiet Hours (11:00 PM – 7:00 AM)'),
                    subtitle: const Text('Mute non-urgent notifications during sleep'),
                    value: _quietHoursEnabled,
                    activeColor: AppColors.softLavender,
                    onChanged: (val) {
                      setState(() => _quietHoursEnabled = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Live Diagnostics & Environment Status
            Text('Sync & Infrastructure Diagnostics', style: AppTypography.titleMedium),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      realtimeClient.isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: realtimeClient.isConnected ? AppColors.tealProximity : AppColors.warning,
                    ),
                    title: const Text('Realtime Sync Server'),
                    subtitle: Text(realtimeClient.serverUrl, style: const TextStyle(fontSize: 11)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: realtimeClient.isConnected
                            ? AppColors.tealProximity.withOpacity(0.2)
                            : AppColors.warning.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        realtimeClient.isConnected ? 'ONLINE' : 'CONNECTING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: realtimeClient.isConnected ? AppColors.tealProximity : AppColors.warning,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  const ListTile(
                    leading: Icon(Icons.local_fire_department_rounded, color: AppColors.warmAmber),
                    title: Text('Firebase Project ID'),
                    subtitle: Text('between-us-eda3b (Spark Plan)', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Danger Zone & Account
            Text('Space & Account', style: AppTypography.titleMedium.copyWith(color: AppColors.error)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.link_off_rounded, color: AppColors.error),
                    title: const Text('Unpair / Disconnect Space'),
                    subtitle: const Text('Revokes session for both devices'),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: () => _showUnpairConfirmation(context, coupleState),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppColors.textMuted),
                    title: const Text('Sign Out Account'),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: () async {
                      await context.read<AuthState>().signOut();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
