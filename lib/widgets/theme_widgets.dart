// lib/widgets/theme_widgets.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/sweet_world.dart';

// ============================================================================
// COLOR UTILS
// ============================================================================
extension _ColorUtils on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}

// ============================================================================
// THEMED DIALOG (original – kept for backward compatibility)
// ============================================================================
class ThemedDialog extends StatefulWidget {
  final SweetWorld world;
  final String title;
  final String? subtitle;
  final Widget? body;
  final List<Widget> actions;
  final String? iconEmoji;

  const ThemedDialog({
    Key? key,
    required this.world,
    required this.title,
    this.subtitle,
    this.body,
    required this.actions,
    this.iconEmoji,
  }) : super(key: key);

  @override
  State<ThemedDialog> createState() => _ThemedDialogState();
}

class _ThemedDialogState extends State<ThemedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late List<_Particle> _particles;
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _particles = List.generate(20, (i) {
      return _Particle(
        position: Offset(_rand.nextDouble() * 300, _rand.nextDouble() * 200),
        size: 4 + _rand.nextDouble() * 8,
        speed: 0.2 + _rand.nextDouble() * 0.4,
        opacity: 0.2 + _rand.nextDouble() * 0.4,
        emoji: _getRandomParticleEmoji(),
      );
    });
    _controller.forward();
  }

  String _getRandomParticleEmoji() {
    final world = widget.world.name.toLowerCase();
    if (world.contains('space')) {
      return ['✨', '⭐', '🌟', '💫'][_rand.nextInt(4)];
    } else if (world.contains('volcano')) {
      return ['🔥', '💨', '🌋', '🧨'][_rand.nextInt(4)];
    } else if (world.contains('ice')) {
      return ['❄️', '🧊', '⛄', '🌨️'][_rand.nextInt(4)];
    } else if (world.contains('candy')) {
      return ['🍬', '🍭', '🍫', '🧁'][_rand.nextInt(4)];
    } else {
      return ['🌿', '🌴', '🍃', '🌺'][_rand.nextInt(4)];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.world.primaryColor;
    final brightness = widget.world.primaryColor.computeLuminance();
    final shadowIntensity = brightness < 0.3 ? 0.4 : 0.2;

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final dialogWidth = isTablet ? screenWidth * 0.5 : screenWidth * 0.9;
    final fontSize = isTablet ? 28.0 : 20.0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Center(
          child: Container(
            width: dialogWidth,
            constraints: const BoxConstraints(maxWidth: 500),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DialogParticlePainter(_particles, _controller),
                  ),
                ),
                Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                    side: BorderSide(color: primary.withOpacity(0.5), width: 3),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.95),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.98),
                          Colors.white.withOpacity(0.92),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: primary.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(shadowIntensity),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.iconEmoji != null) ...[
                          Text(widget.iconEmoji!, style: TextStyle(fontSize: fontSize + 12)),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: primary,
                            shadows: [
                              Shadow(
                                color: primary.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                              fontSize: fontSize * 0.7,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (widget.body != null) ...[
                          const SizedBox(height: 12),
                          widget.body!,
                        ],
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.actions,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final Offset position;
  final double size;
  final double speed;
  final double opacity;
  final String emoji;
  _Particle({
    required this.position,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.emoji,
  });
}

class _DialogParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final AnimationController animation;
  final TextPainter _textPainter = TextPainter(textDirection: TextDirection.ltr);

  _DialogParticlePainter(this.particles, this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    for (final p in particles) {
      final dx = p.position.dx + 20 * sin(now * p.speed + p.position.dx);
      final dy = p.position.dy + 20 * cos(now * p.speed * 0.7 + p.position.dy);
      final x = (dx % size.width);
      final y = (dy % size.height);
      final opacity = p.opacity * (0.5 + 0.5 * sin(now * p.speed + p.position.dx));
      _textPainter.text = TextSpan(
        text: p.emoji,
        style: TextStyle(fontSize: p.size, color: Colors.white.withOpacity(opacity)),
      );
      _textPainter.layout();
      _textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================================
// THEMED BUTTON (original)
// ============================================================================
class ThemedButton extends StatefulWidget {
  final SweetWorld world;
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final IconData? icon;
  final double? minWidth;

  const ThemedButton({
    Key? key,
    required this.world,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.icon,
    this.minWidth,
  }) : super(key: key);

  @override
  State<ThemedButton> createState() => _ThemedButtonState();
}

class _ThemedButtonState extends State<ThemedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.world.primaryColor;
    final secondary = widget.world.secondaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final padding = isTablet ? 20.0 : 12.0;
    final fontSize = isTablet ? 18.0 : 14.0;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 - 0.05 * _controller.value;
          final opacity = 1.0 - 0.1 * _controller.value;
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: widget.minWidth ?? 90),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.7),
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
                      BoxShadow(color: primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: fontSize + 2),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: fontSize,
                            shadows: const [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 2D CARTOON BUTTON (new style)
// ============================================================================
class CartoonButton extends StatefulWidget {
  final SweetWorld world;
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final IconData? icon;

  const CartoonButton({
    Key? key,
    required this.world,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.icon,
  }) : super(key: key);

  @override
  State<CartoonButton> createState() => _CartoonButtonState();
}

class _CartoonButtonState extends State<CartoonButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    setState(() => _pressed = true);
    _controller.forward();
  }

  void _onTapUp(_) {
    setState(() => _pressed = false);
    _controller.reverse();
    widget.onPressed();
  }

  void _onTapCancel() {
    setState(() => _pressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.world.primaryColor;
    final secondary = widget.world.secondaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final fontSize = isTablet ? 16.0 : 14.0;

    final baseColor = widget.primary ? primary : secondary;
    final borderColor = baseColor.darken(0.3);
    final shadowOffset = _pressed ? 0.0 : 3.0;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: borderColor.withOpacity(0.4),
                    offset: Offset(0, shadowOffset),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: Colors.white, size: fontSize + 4),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: fontSize,
                      letterSpacing: 1.2,
                      shadows: const [
                        Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// SHOW THEMED DIALOG (original, kept for any unused references)
// ============================================================================
Future<T?> showThemedDialog<T>({
  required BuildContext context,
  required SweetWorld world,
  required String title,
  String? subtitle,
  Widget? body,
  required List<Widget> actions,
  String? iconEmoji,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: '',
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) {
      return ThemedDialog(
        world: world,
        title: title,
        subtitle: subtitle,
        body: body,
        actions: actions,
        iconEmoji: iconEmoji,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation.drive(Tween<double>(begin: 0, end: 1)),
        child: child,
      );
    },
  );
}

// ============================================================================
// SHOW CARTOON DIALOG (2D cartoon style with optional world background)
// ============================================================================
Future<T?> showCartoonDialog<T>({
  required BuildContext context,
  required SweetWorld world,
  required String title,
  String? subtitle,
  Widget? body,
  required List<Widget> actions,
  String? iconEmoji,
  String? backgroundImagePath,
}) {
  final primary = world.primaryColor;
  final borderColor = primary.darken(0.3);

  // The visible dialog content – now with TRANSPARENT background
  Widget dialogContent = Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.transparent,   // ← changed from Colors.white to transparent
      borderRadius: BorderRadius.circular(32),
      border: Border.all(color: borderColor, width: 4),
      boxShadow: [
        BoxShadow(
          color: borderColor.withOpacity(0.5),
          offset: const Offset(0, 6),
          blurRadius: 0,
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconEmoji != null) ...[
          Text(iconEmoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
        ],
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: primary),
            textAlign: TextAlign.center,
          ),
        ],
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
        ],
        if (body != null) ...[
          const SizedBox(height: 12),
          body,
        ],
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: actions,
        ),
      ],
    ),
  );

  // If a background image is provided, wrap with image + white overlay
  if (backgroundImagePath != null && backgroundImagePath.isNotEmpty) {
    dialogContent = Stack(
      children: [
        // 1. The world image
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.asset(
              backgroundImagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.red), // temporary red to catch errors
            ),
          ),
        ),
        // 2. Semi‑transparent white overlay to keep text readable
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(32),
            ),
          ),
        ),
        // 3. The transparent dialog content (border, shadow, text, buttons)
        dialogContent,
      ],
    );
  } else {
    // Fallback: if no image, use a solid white card (same as before)
    dialogContent = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor, width: 4),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.5),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconEmoji != null) ...[
            Text(iconEmoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
          ],
          if (title.isNotEmpty) ...[
            Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: primary), textAlign: TextAlign.center),
          ],
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
          ],
          if (body != null) ...[
            const SizedBox(height: 12),
            body,
          ],
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
        ],
      ),
    );
  }

  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: '',
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: dialogContent,
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation.drive(Tween<double>(begin: 0, end: 1)),
        child: child,
      );
    },
  );
}