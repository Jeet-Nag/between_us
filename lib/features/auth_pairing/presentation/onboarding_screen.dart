import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import 'pairing_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _proceedToPairing({required bool isCreating}) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name to continue.'),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PairingScreen(
          userName: name,
          isCreating: isCreating,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.ambientGlow,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 1),
                
                // Emotional App Identity
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryRose.withOpacity(0.5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRose.withOpacity(0.2),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.primaryRose,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Between Us',
                  textAlign: TextAlign.center,
                  style: AppTypography.displayLarge,
                ),
                const SizedBox(height: 12),

                Text(
                  '“We don’t help couples talk.\nWe help them feel close when they can’t be together.”',
                  textAlign: TextAlign.center,
                  style: AppTypography.emotionalQuote,
                ),
                
                const Spacer(flex: 2),

                // Name input
                Text(
                  'What should your partner call you?',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _nameController,
                  style: AppTypography.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Your Name (e.g. Jeet)',
                    hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.surfaceBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.surfaceBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primaryRose, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Create Space Button
                ElevatedButton(
                  onPressed: () => _proceedToPairing(isCreating: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRose,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text('Create Our Private Space', style: AppTypography.titleMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Join Space Button
                OutlinedButton(
                  onPressed: () => _proceedToPairing(isCreating: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.surfaceBorder, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('I Have a Partner Code', style: AppTypography.titleMedium),
                ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '🔒 End-to-end private space for exactly 2 people.',
                    style: AppTypography.bodySmall,
                  ),
                ),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
