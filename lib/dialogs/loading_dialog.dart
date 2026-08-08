import 'package:flutter/material.dart';
import '../widgets/logo.dart';

/// A premium loading dialog with a progress bar and an animated dino emoji.
class PremiumLoadingDialog extends StatelessWidget {
  final String message;
  final double? progress; // 0.0 to 1.0, if null shows indeterminate

  const PremiumLoadingDialog({
    Key? key,
    this.message = 'Preparing level',
    this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ChocoDinoLogo(fontSize: 32, showIcon: true),
            const SizedBox(height: 16),
            // Animated dino running
            const Text(
              '🦕',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            // Linear progress
            SizedBox(
              width: double.infinity,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}