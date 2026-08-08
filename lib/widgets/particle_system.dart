import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

/// A single physics particle. Velocity decays via friction and is pulled
/// down by gravity every frame, integrated with real elapsed time (dt) so
/// motion is frame-rate independent rather than a canned tween.
class Particle {
  Offset position;
  Offset velocity;
  final double gravity;
  final double friction;
  double life;
  final double maxLife;
  final Color color;
  final double size;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    this.gravity = 700,
    this.friction = 0.97,
    this.maxLife = 0.8,
    this.size = 6,
  }) : life = maxLife;

  bool get isDead => life <= 0;

  void step(double dt) {
    velocity = Offset(velocity.dx * friction, velocity.dy * friction + gravity * dt);
    position += velocity * dt;
    life -= dt;
  }
}

/// Drives every active particle plus a critically-damped spring used for
/// screen shake. Both are real physics simulations (gravity/friction on
/// particles, a SpringSimulation for the shake), not pre-baked animations.
class ParticleController extends ChangeNotifier {
  final List<Particle> _particles = [];
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  double _shakeOffset = 0;
  double _shakeVelocity = 0;
  static const SpringDescription _shakeSpring = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 18,
  );

  double get shakeOffset => _shakeOffset;
  List<Particle> get particles => List.unmodifiable(_particles);

  void attach(TickerProvider vsync) {
    _ticker?.dispose();
    _lastElapsed = Duration.zero;
    _ticker = vsync.createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0 || dt > 0.1) return; // guard first frame / hot-reload spikes

    for (final p in _particles) {
      p.step(dt);
    }
    _particles.removeWhere((p) => p.isDead);

    if (_shakeOffset.abs() > 0.01 || _shakeVelocity.abs() > 0.01) {
      final spring = SpringSimulation(_shakeSpring, _shakeOffset, 0, _shakeVelocity);
      _shakeOffset = spring.x(dt);
      _shakeVelocity = spring.dx(dt);
    } else {
      _shakeOffset = 0;
      _shakeVelocity = 0;
    }

    notifyListeners();
  }

  /// A soft, upward-biased burst — used for chocolate pickups.
  void burst(Offset origin, {int count = 14, required Color color, double speed = 220}) {
    final rand = Random();
    for (int i = 0; i < count; i++) {
      final angle = rand.nextDouble() * 2 * pi;
      final v = speed * (0.5 + rand.nextDouble() * 0.5);
      _particles.add(Particle(
        position: origin,
        velocity: Offset(cos(angle) * v, sin(angle) * v - 100),
        color: color,
        gravity: 650,
        maxLife: 0.6 + rand.nextDouble() * 0.3,
        size: 3 + rand.nextDouble() * 4,
      ));
    }
  }

  /// A harder, faster burst plus screen shake — used for mine/enemy/hazard hits.
  void explosion(Offset origin, {Color color = Colors.orange}) {
    burst(origin, count: 26, color: color, speed: 360);
    shake(12);
  }

  void shake(double magnitude) {
    _shakeVelocity += magnitude * 40;
  }

  /// Immediately wipes every in-flight particle and resets shake state.
  /// Needed specifically because this controller is a single long-lived
  /// object that survives across endless-mode stage transitions (by
  /// design, for continuous animation) — without this, particles from a
  /// win-celebration burst or a last-chocolate eat-burst that haven't
  /// fully decayed yet keep rendering right on top of the next stage's
  /// freshly-loaded board.
  void clear() {
    _particles.clear();
    _shakeOffset = 0;
    _shakeVelocity = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}

class PhysicsParticlePainter extends CustomPainter {
  final List<Particle> particles;
  PhysicsParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final opacity = (p.life / p.maxLife).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withOpacity(opacity);
      canvas.drawCircle(p.position, p.size * opacity + 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PhysicsParticlePainter oldDelegate) => true;
}