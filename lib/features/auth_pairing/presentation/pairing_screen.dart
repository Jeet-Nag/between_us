import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../state/couple_state.dart';

class PairingScreen extends StatefulWidget {
  final String userName;
  final String? userId;
  final bool isCreating;

  const PairingScreen({
    super.key,
    required this.userName,
    this.userId,
    this.isCreating = true,
  });

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _codeController = TextEditingController();
  late bool _isCreatingMode;

  @override
  void initState() {
    super.initState();
    _isCreatingMode = widget.isCreating;
    if (_isCreatingMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CoupleState>().createSpace(
          myName: widget.userName,
          myUserId: widget.userId,
        );
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submitCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-character code.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final success = await context.read<CoupleState>().joinSpace(
      myName: widget.userName,
      code: code,
      myUserId: widget.userId,
    );

    if (success && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupleState = context.watch<CoupleState>();
    final couple = coupleState.couple;

    // If partner connected while on this screen
    if (coupleState.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreatingMode ? 'Our Invitation' : 'Join Our Space'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode switcher
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!_isCreatingMode) {
                            setState(() => _isCreatingMode = true);
                            if (coupleState.couple == null) {
                              coupleState.createSpace(
                                myName: widget.userName,
                                myUserId: widget.userId,
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isCreatingMode ? AppColors.primaryRose : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Invite Partner',
                            textAlign: TextAlign.center,
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 14,
                              color: _isCreatingMode ? Colors.white : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_isCreatingMode) {
                            setState(() => _isCreatingMode = false);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isCreatingMode ? AppColors.primaryRose : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Enter Code',
                            textAlign: TextAlign.center,
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 14,
                              color: !_isCreatingMode ? Colors.white : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (_isCreatingMode)
                _buildCreatorView(coupleState, couple?.pairingCode)
              else
                _buildJoinerView(coupleState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorView(CoupleState state, String? pairingCode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.primaryRoseSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread_rounded,
              color: AppColors.primaryRose,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Share This Code with Your Partner',
          textAlign: TextAlign.center,
          style: AppTypography.displayMedium,
        ),
        const SizedBox(height: 10),
        Text(
          'Once they enter this code on their phone, your private space will connect automatically.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: 28),

        // Pairing Code Display
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Text('INVITATION CODE', style: AppTypography.bodySmall.copyWith(letterSpacing: 1.5)),
              const SizedBox(height: 12),
              if (state.isLoading && (pairingCode == null || pairingCode.isEmpty))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRose),
                )
              else
                Text(
                  (pairingCode != null && pairingCode.isNotEmpty) ? pairingCode : '......',
                  style: AppTypography.displayLarge.copyWith(
                    letterSpacing: 8.0,
                    color: AppColors.warmAmber,
                  ),
                ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: (pairingCode == null || pairingCode.isEmpty)
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: pairingCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primaryRose),
                label: Text(
                  'Copy Code',
                  style: AppTypography.titleMedium.copyWith(color: AppColors.primaryRose),
                ),
              ),
            ],
          ),
        ),

        if (state.errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                Text(
                  state.errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    state.createSpace(
                      myName: widget.userName,
                      myUserId: widget.userId,
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primaryRose),
                  label: const Text('Retry Generating Code', style: TextStyle(color: AppColors.primaryRose)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryRose,
              ),
            ),
            const SizedBox(width: 12),
            Text('Waiting for partner to join...', style: AppTypography.bodyMedium),
          ],
        ),
      ],
    );
  }

  Widget _buildJoinerView(CoupleState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.softTealBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              color: AppColors.tealProximity,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Enter Partner’s Code',
          textAlign: TextAlign.center,
          style: AppTypography.displayMedium,
        ),
        const SizedBox(height: 10),
        Text(
          'Ask your partner for their 6-character invitation code to join your private space.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: 28),

        TextField(
          controller: _codeController,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          style: AppTypography.displayLarge.copyWith(
            letterSpacing: 6.0,
            color: AppColors.warmAmber,
          ),
          maxLength: 6,
          decoration: InputDecoration(
            hintText: 'CODE',
            counterText: '',
            hintStyle: AppTypography.displayLarge.copyWith(
              color: AppColors.textMuted.withOpacity(0.3),
              letterSpacing: 6.0,
            ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: AppColors.primaryRose, width: 2),
            ),
          ),
        ),

        if (state.errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withOpacity(0.4)),
            ),
            child: Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
        ],

        const SizedBox(height: 32),

        ElevatedButton(
          onPressed: state.isLoading ? null : _submitCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRose,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: state.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text('Connect Together ❤️', style: AppTypography.titleMedium),
        ),
      ],
    );
  }
}
