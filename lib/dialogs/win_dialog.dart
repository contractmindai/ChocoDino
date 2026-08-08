import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/theme_widgets.dart';
import '../widgets/logo.dart';

/// A beautiful win dialog with:
/// - World‑themed accent color and gradient
/// - Stars revealed one by one with scale+rotation
/// - Points count‑up from 0 to earned amount
/// - Trophy pulse + glow
/// - Scale‑up entry animation
class WinDialog extends StatefulWidget {
  final int stars;
  final int points;
  final String? subtitle;
  final String quote;
  final VoidCallback onContinue;

  /// Optional world theme – used for accent colour and gradient.
  /// Supported: 'candy', 'jungle', 'ice', 'volcano', 'space'
  final String worldTheme;

  const WinDialog({
    Key? key,
    required this.stars,
    required this.points,
    this.subtitle,
    required this.quote,
    required this.onContinue,
    this.worldTheme = 'candy', // default
  }) : super(key: key);

  @override
  State<WinDialog> createState() => _WinDialogState();
}

class _WinDialogState extends State<WinDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _starController;
  late AnimationController _pointsController;
  late AnimationController _entryController;
  late AnimationController _pulseController;
  List<bool> _starRevealed = [];
  int _displayPoints = 0;

  // World theme data
  Map<String, dynamic> get _themeData {
    switch (widget.worldTheme) {
      case 'candy':
        return {
          'accent': Colors.pink.shade300,
          'gradient': [Colors.pink.shade100, Colors.pink.shade300],
          'titleColor': Colors.pink.shade800,
        };
      case 'jungle':
        return {
          'accent': Colors.green.shade600,
          'gradient': [Colors.green.shade100, Colors.green.shade400],
          'titleColor': Colors.green.shade900,
        };
      case 'ice':
        return {
          'accent': Colors.cyan.shade300,
          'gradient': [Colors.cyan.shade50, Colors.cyan.shade200],
          'titleColor': Colors.blue.shade900,
        };
      case 'volcano':
        return {
          'accent': Colors.orange.shade700,
          'gradient': [Colors.orange.shade100, Colors.orange.shade400],
          'titleColor': Colors.brown.shade900,
        };
      case 'space':
        return {
          'accent': Colors.purple.shade300,
          'gradient': [Colors.purple.shade100, Colors.purple.shade400],
          'titleColor': Colors.deepPurple.shade900,
        };
      default:
        return {
          'accent': Colors.amber,
          'gradient': [Color(0xFFFFE082), Color(0xFFFF8A65)],
          'titleColor': Colors.brown,
        };
    }
  }

  @override
  void initState() {
    super.initState();
    _starRevealed = List.filled(3, false);
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pointsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Reveal stars one by one
    _revealStars();

    // Animate points
    _pointsController.addListener(() {
      setState(() {
        _displayPoints = (_pointsController.value * widget.points).round();
      });
    });
    _pointsController.forward();

    // Entry animation – start after a tiny delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryController.forward();
    });
  }

  void _revealStars() async {
    for (int i = 0; i < widget.stars; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _starRevealed[i] = true;
        });
        _starController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _starController.dispose();
    _pointsController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themeData;
    final accent = theme['accent'] as Color;
    final gradientColors = theme['gradient'] as List<Color>;
    final titleColor = theme['titleColor'] as Color;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _entryController,
        builder: (context, child) {
          final curved = Curves.easeOutBack.transform(_entryController.value.clamp(0, 1));
          final scale = 0.6 + 0.4 * curved;
          final opacity = _entryController.value.clamp(0.0, 1.0);
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: child,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 6,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing/pulsing logo
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final pulse = 1.0 + 0.08 * _pulseController.value;
                  return Transform.scale(
                    scale: pulse,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.5 * _pulseController.value),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const ChocoDinoLogo(
                        fontSize: 32,
                        showIcon: true,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              // Title – large, bold, world‑themed
              Text(
                'Level Complete!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                  shadows: [
                    Shadow(
                      color: accent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle – softer, italic
              Text(
                widget.quote,
                style: TextStyle(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: titleColor.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Animated Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final revealed = _starRevealed[i];
                  return AnimatedBuilder(
                    animation: _starController,
                    builder: (context, child) {
                      final scale = revealed
                          ? 1.0 + 0.4 * _starController.value
                          : 0.5;
                      final rotation = revealed
                          ? _starController.value * 0.5
                          : 0.0;
                      return Transform.scale(
                        scale: scale,
                        child: Transform.rotate(
                          angle: rotation,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              i < widget.stars
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: i < widget.stars
                                  ? Colors.amber.shade800
                                  : Colors.grey.shade400,
                              size: 44,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Points with count‑up
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Text(
                  '+$_displayPoints POINTS',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.subtitle!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Continue button – styled as primary
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: accent,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                  shadowColor: accent.withOpacity(0.3),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onContinue();
                },
                child: const Text(
                  'Continue ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}