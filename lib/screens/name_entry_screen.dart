// lib/screens/name_entry_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../widgets/logo.dart';
import '../models/sweet_world.dart';
import 'game_home_screen.dart';
import '../models/player_progress.dart';

// ============================================================================
// THEMED BUTTON (with idle animation – fixed TickerProvider)
// ============================================================================

class _ThemedButton extends StatefulWidget {
  final Color color;
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final IconData? icon;

  const _ThemedButton({
    required this.color,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.icon,
  });

  @override
  State<_ThemedButton> createState() => _ThemedButtonState();
}

class _ThemedButtonState extends State<_ThemedButton>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _idleController;
  late Animation<double> _idleScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _idleScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.color;
    final secondary = widget.color.darken(0.15);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final padding = isTablet ? 22.0 : 16.0;
    final fontSize = isTablet ? 22.0 : 18.0;

    return AnimatedBuilder(
      animation: _idleController,
      builder: (context, child) {
        return Transform.scale(
          scale: _idleScale.value,
          child: GestureDetector(
            onTapDown: (_) => _pressController.forward(),
            onTapUp: (_) {
              _pressController.reverse();
              widget.onPressed();
            },
            onTapCancel: () => _pressController.reverse(),
            child: AnimatedBuilder(
              animation: _pressController,
              builder: (context, child) {
                final scale = 1.0 - 0.06 * _pressController.value;
                final opacity = 1.0 - 0.1 * _pressController.value;
                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: padding * 1.2, vertical: padding * 0.8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.primary
                              ? [primary, secondary]
                              : [primary.withOpacity(0.6), secondary.withOpacity(0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(60),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(-2, -2),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: Colors.white, size: fontSize + 4),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize,
                              letterSpacing: 1.2,
                              shadows: const [
                                Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

extension _ColorUtils on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}



// ============================================================================
// SPARKLE PARTICLES (unchanged)
// ============================================================================

class _Sparkle {
  final double x;
  final double baseY;
  final double size;
  final double speed;
  final double phase;
  final String emoji;

  _Sparkle({
    required this.x,
    required this.baseY,
    required this.size,
    required this.speed,
    required this.phase,
    required this.emoji,
  });
}

class _SparkleField extends StatelessWidget {
  final AnimationController controller;
  final List<_Sparkle> sparkles;

  const _SparkleField({required this.controller, required this.sparkles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = controller.value * 2 * pi;
            return Stack(
              children: sparkles.map((s) {
                final drift = sin(t * s.speed + s.phase) * 14;
                final bob = cos(t * s.speed * 0.6 + s.phase) * 10;
                return Positioned(
                  left: constraints.maxWidth * s.x + drift,
                  top: constraints.maxHeight * s.baseY + bob,
                  child: Opacity(
                    opacity: 0.35 + 0.25 * sin(t * s.speed + s.phase).abs(),
                    child: Text(s.emoji, style: TextStyle(fontSize: s.size)),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// NAME ENTRY SCREEN – transparent glass card, larger, no footprint trail
// ============================================================================

class NameEntryScreen extends StatefulWidget {
  @override
  _NameEntryScreenState createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  late final AnimationController _bgController;
  late final AnimationController _parallaxController;
  late final AnimationController _idleController;

  late final List<_Sparkle> _sparkles;

  String _enteredName = '';
  bool _isNameComplete = false;
  bool _isFocused = false;

  static const primaryColor = Color(0xFFFF6F00);
  static const secondaryColor = Color(0xFFFFAB00);

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _parallaxController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    final rand = Random();
    const emojis = ['🍫', '✨', '🌟', '🍬', '💫'];
    _sparkles = List.generate(12, (i) {
      return _Sparkle(
        x: rand.nextDouble(),
        baseY: rand.nextDouble(),
        size: 14 + rand.nextDouble() * 18,
        speed: 0.5 + rand.nextDouble() * 0.7,
        phase: rand.nextDouble() * 2 * pi,
        emoji: emojis[rand.nextInt(emojis.length)],
      );
    });

    _nameFocusNode.addListener(() {
      setState(() => _isFocused = _nameFocusNode.hasFocus);
    });

    _nameController.addListener(() {
      final name = _nameController.text.trim();
      setState(() {
        _enteredName = name;
        _isNameComplete = name.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _parallaxController.dispose();
    _idleController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    String name = _nameController.text.trim();
    if (name.isEmpty) name = 'Rex';

    final progress = await PlayerProgress.load();
    progress.dinoName = name;
    await progress.save();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => GameHomeScreen(dinoName: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    // Make the card much larger – use 95% of screen width, capped at 560px for tablets.
    final cardWidth = isTablet ? 560.0 : screenWidth * 0.92;
    final dinoSize = isTablet ? 180.0 : 160.0;

    final bgImage = Image.asset(
      kSweetWorlds[0].backgroundImagePath,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, secondaryColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          // Background with parallax
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _parallaxController,
              builder: (context, child) {
                final offset = _parallaxController.value * 40;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: Transform.scale(scale: 1.05, child: child),
                );
              },
              child: bgImage,
            ),
          ),
          // Overlay (lighter to make glass pop)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Sparkles
          Positioned.fill(
            child: _SparkleField(controller: _bgController, sparkles: _sparkles),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [


                    const SizedBox(height: 16),

                    // ---- Glass‑morphism card (larger, with logo) ----
                    ClipRRect(
                      borderRadius: BorderRadius.circular(48),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: cardWidth,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.18),
                                Colors.white.withOpacity(0.10),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(48),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 30,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ---- Logo (bigger) ----
                              Image.asset(
                                'assets/images/logo.png',
                                height: 80, // increased from 50
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Text('🦕', style: TextStyle(fontSize: 60)),
                              ),
                              const SizedBox(height: 12),

                              // ---- Title ----
                              const Text(
                                'NAME YOUR DINO!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
                                  letterSpacing: 1.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(1, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Meet your hungry little chocolate hunter!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.brown.shade800,
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    Shadow(
                                      color: Colors.white.withOpacity(0.6),
                                      blurRadius: 4,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Name input
                              TextField(
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                textCapitalization: TextCapitalization.words,
                                maxLength: 16,
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: "What should we call you?",
                                  labelStyle: TextStyle(
                                    color: Colors.brown.shade800,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.75),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(40),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(40),
                                    borderSide: BorderSide(
                                        color: primaryColor.withOpacity(0.2), width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(40),
                                    borderSide: const BorderSide(color: primaryColor, width: 2),
                                  ),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Image.asset(
                                      'assets/dino/idle.png',
                                      width: 28,
                                      height: 28,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  hintText: "✏️ Enter your dino's name...",
                                  hintStyle: TextStyle(
                                    color: Colors.brown.shade400,
                                    fontSize: 16,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                ),
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.brown.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 28),

                              // Start button
                              _ThemedButton(
                                color: primaryColor,
                                label: 'PLAY',
                                primary: true,
                                icon: null,
                                onPressed: _submit,
                              ),

                              const SizedBox(height: 8),

                              // Supporting text (no footprints, just text)
                              Text(
                                'Your adventure is waiting!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.brown.shade800,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    Shadow(
                                      color: Colors.white.withOpacity(0.6),
                                      blurRadius: 4,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}