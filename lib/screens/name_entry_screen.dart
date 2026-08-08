// lib/screens/name_entry_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/logo.dart';
import '../models/sweet_world.dart';
import 'game_home_screen.dart';

// ============================================================================
// THEMED BUTTON
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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.color;
    final secondary = widget.color.darken(0.15);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final padding = isTablet ? 22.0 : 16.0;
    final fontSize = isTablet ? 19.0 : 17.0;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 - 0.05 * _controller.value;
          final opacity = 1.0 - 0.1 * _controller.value;
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.75),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.primary
                        ? [primary, secondary]
                        : [primary.withOpacity(0.6), secondary.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: fontSize + 2),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: fontSize,
                        letterSpacing: 0.3,
                        shadows: const [
                          Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
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
    );
  }
}

extension _ColorUtils on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
  Color lighten(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}

// ============================================================================
// SPARKLE PARTICLES
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
// NAME ENTRY SCREEN
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
  late final Animation<double> _bobAnimation;

  late final List<_Sparkle> _sparkles;

  bool _isFocused = false;

  static const primaryColor = Color(0xFFFF6F00);
  static const secondaryColor = Color(0xFFFFAB00);
  static const cardColor = Color(0xFFFFF8E1);

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
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _bobAnimation = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    final rand = Random();
    const emojis = ['🍫', '✨', '🌟', '🍬', '💫'];
    _sparkles = List.generate(9, (i) {
      return _Sparkle(
        x: rand.nextDouble(),
        baseY: rand.nextDouble(),
        size: 14 + rand.nextDouble() * 14,
        speed: 0.5 + rand.nextDouble() * 0.7,
        phase: rand.nextDouble() * 2 * pi,
        emoji: emojis[rand.nextInt(emojis.length)],
      );
    });

    _nameFocusNode.addListener(() {
      setState(() => _isFocused = _nameFocusNode.hasFocus);
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

  void _submit() {
    String name = _nameController.text.trim();
    if (name.isEmpty) name = 'Rex';
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => GameHomeScreen(dinoName: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

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
      appBar: AppBar(
        title: const ChocoDinoLogo(fontSize: 28),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // ---- Background ----
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

          // ---- Overlay ----
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // ---- Decorative dino silhouette ----
          Positioned(
            top: 30,
            right: -50,
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) => Transform.rotate(
                angle: -_bgController.value * 0.12,
                child: child,
              ),
              child: Opacity(
                opacity: 0.03,
                child: Transform.flip(
                  flipX: true,
                  child: Image.asset(
                    'assets/dino/idle.png',
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text('🦕', style: TextStyle(fontSize: 100)),
                  ),
                ),
              ),
            ),
          ),

          // ---- Sparkles ----
          Positioned.fill(
            child: _SparkleField(controller: _bgController, sparkles: _sparkles),
          ),

          // ---- Main content ----
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
                child: Container(
                  width: isTablet ? 460 : null,
                  margin: const EdgeInsets.all(24),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ---- Premium card ----
                      Container(
                        padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cardColor.withOpacity(0.98), cardColor.withOpacity(0.9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(48),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 36,
                              offset: const Offset(0, 18),
                            ),
                            BoxShadow(
                              color: primaryColor.withOpacity(0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withOpacity(0.7),
                            width: 4,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ---- Assistant dino on the left side of heading ----
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Dino mascot on the left
                                  AnimatedBuilder(
                                    animation: _idleController,
                                    builder: (context, child) => Transform.translate(
                                      offset: Offset(0, _bobAnimation.value),
                                      child: Image.asset(
                                        'assets/dino/idle.png',
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const Text('🦕', style: TextStyle(fontSize: 32)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Title
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ShaderMask(
                                          shaderCallback: (bounds) => const LinearGradient(
                                            colors: [primaryColor, secondaryColor],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds),
                                          child: const Text(
                                            'Chocolate Eater',
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(1, 2)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Dinosaur',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.brown.shade700,
                                            shadows: [
                                              Shadow(
                                                color: Colors.brown.shade200,
                                                blurRadius: 6,
                                                offset: const Offset(2, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Give your dino a name to start the adventure',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.brown.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 26),
                            // ---- Input field ----
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: _isFocused
                                    ? [
                                        BoxShadow(
                                          color: primaryColor.withOpacity(0.35),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: TextField(
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                textCapitalization: TextCapitalization.words,
                                maxLength: 16,
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: "What's your dino's name?",
                                  counterText: '',
                                  labelStyle: TextStyle(
                                    color: Colors.brown.shade600,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.85),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(40),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(40),
                                    borderSide: BorderSide(color: primaryColor.withOpacity(0.15), width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(40),
                                    borderSide: const BorderSide(color: primaryColor, width: 2),
                                  ),
                                  prefixIcon: Icon(Icons.edit, color: Colors.brown.shade500),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                                ),
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.brown.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            // ---- Themed button ----
                            _ThemedButton(
                              color: primaryColor,
                              label: 'Start Adventure',
                              primary: true,
                              icon: Icons.play_arrow,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 14),
                            // ---- Footer ----
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/dino/idle.png',
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Text('🦕', style: TextStyle(fontSize: 18)),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Let's go!",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.brown.shade500,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // ---- Floating badge (above card) ----
                      Positioned(
                        top: -34,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: TweenAnimationBuilder(
                            tween: Tween<double>(begin: -60, end: 0),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.elasticOut,
                            builder: (context, entrance, child) => Transform.translate(
                              offset: Offset(0, entrance),
                              child: child,
                            ),
                            child: AnimatedBuilder(
                              animation: _idleController,
                              builder: (context, child) => Transform.translate(
                                offset: Offset(0, _bobAnimation.value),
                                child: child,
                              ),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [secondaryColor, primaryColor],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.5),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Image.asset(
                                  'assets/dino/idle.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Text('🦕', style: TextStyle(fontSize: 36)),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}