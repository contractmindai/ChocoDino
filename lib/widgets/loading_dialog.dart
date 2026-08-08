import 'package:flutter/material.dart';
import 'logo.dart';
import 'emoji_icon.dart';

/// A premium loading dialog with a progress bar and a gently bouncing
/// dino badge. Accepts an optional [progress] (0..1) for determinate
/// loads, or shows an indeterminate bar when generation time is unknown.
class PremiumLoadingDialog extends StatefulWidget {
  final String message;
  final double? progress;
  final Color? gradientStart;
  final Color? gradientEnd;

  const PremiumLoadingDialog({
    Key? key,
    this.message = 'Preparing level',
    this.progress,
    this.gradientStart,
    this.gradientEnd,
  }) : super(key: key);

  @override
  State<PremiumLoadingDialog> createState() => _PremiumLoadingDialogState();
}

class _PremiumLoadingDialogState extends State<PremiumLoadingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.gradientStart ?? const Color(0xFFFFB74D);
    final end = widget.gradientEnd ?? const Color(0xFFFF9800);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [start, end],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ChocoDinoLogo(fontSize: 30, showIcon: true),
            const SizedBox(height: 18),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final lift = 8 * _controller.value;
                return Transform.translate(
                  offset: Offset(0, -lift),
                  child: child,
                );
              },
              child: const EmojiIcon(
                '🦕',
                assetPath: 'assets/dino/idle.png',
                size: 44,
                badge: true,
                badgeGradient: [Color(0x59FFFFFF), Color(0x1AFFFFFF)],
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: double.infinity,
                child: LinearProgressIndicator(
                  value: widget.progress,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}