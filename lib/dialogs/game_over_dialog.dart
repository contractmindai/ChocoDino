// lib/dialogs/game_over_dialog.dart
import 'package:flutter/material.dart';
import '../widgets/logo.dart';
import '../widgets/emoji_icon.dart';

class GameOverDialog extends StatefulWidget {
  final String dinoName;
  final String? subtitle;
  final String quote;
  final int chocolatesCollected;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  const GameOverDialog({
    Key? key,
    required this.dinoName,
    this.subtitle,
    required this.quote,
    required this.chocolatesCollected,
    required this.onRetry,
    required this.onExit,
  }) : super(key: key);

  @override
  State<GameOverDialog> createState() => _GameOverDialogState();
}

class _GameOverDialogState extends State<GameOverDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _entry,
        builder: (context, child) {
          final curved = Curves.easeOutBack.transform(_entry.value.clamp(0, 1));
          return Transform.scale(
            scale: 0.85 + 0.15 * curved,
            child: Opacity(
              opacity: _entry.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFB3E5FC), Color(0xFF81D4FA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10)),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ChocoDinoLogo(fontSize: 28, showIcon: true),
              const SizedBox(height: 12),
              const EmojiIcon(
                '💀',
                size: 34,
                badge: true,
                badgeGradient: [Color(0xFF37474F), Color(0xFF546E7A)],
              ),
              const SizedBox(height: 8),
              const Text(
                'Game Over',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                ),
              ),
              const SizedBox(height: 10),
              const EmojiIcon('😢', size: 44),
              const SizedBox(height: 12),
              Text(
                widget.quote,
                style: const TextStyle(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: Colors.brown,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You collected ${widget.chocolatesCollected} chocolates!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.subtitle!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.brown,
                        side: const BorderSide(color: Colors.brown),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: widget.onRetry,
                      child: const Text('Try Again', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: widget.onExit,
                      child: const Text('Exit', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}