import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class Particle {
  Offset position;
  Offset velocity;
  double size;
  Color color;
  double life;
  double gravity;
  bool alive = true;

  Particle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    required this.life,
    this.gravity = 0.0,
  });
}

class ParticleController extends ChangeNotifier {
  final List<Particle> particles = [];
  final Random _random = Random();
  double shakeOffset = 0.0;
  Timer? _shakeTimer;

  void attach(TickerProvider vsync) {
    // No animation controller needed; we update via timer.
    // For now, we rely on the game loop to call update().
    // We'll keep this method for compatibility.
  }

  void update(double dt) {
    for (final p in particles) {
      p.position += p.velocity * dt;
      p.velocity += Offset(0, p.gravity) * dt;
      p.life -= dt;
      if (p.life <= 0) p.alive = false;
    }
    particles.removeWhere((p) => !p.alive);
  }

  void burst(Offset position, {Color color = Colors.amber, int count = 20}) {
    for (int i = 0; i < count; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 50 + _random.nextDouble() * 150;
      particles.add(Particle(
        position: position,
        velocity: Offset(speed * cos(angle), speed * sin(angle)),
        size: 3 + _random.nextDouble() * 5,
        color: color.withOpacity(0.8),
        life: 0.5 + _random.nextDouble() * 0.8,
        gravity: 200,
      ));
    }
    notifyListeners();
  }

  void explosion(Offset position, {Color color = Colors.red, int count = 30}) {
    for (int i = 0; i < count; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 100 + _random.nextDouble() * 300;
      particles.add(Particle(
        position: position,
        velocity: Offset(speed * cos(angle), speed * sin(angle)),
        size: 2 + _random.nextDouble() * 6,
        color: color.withOpacity(0.9),
        life: 0.3 + _random.nextDouble() * 0.6,
        gravity: 300,
      ));
    }
    notifyListeners();
  }

  void shake(double intensity) {
    shakeOffset = intensity;
    notifyListeners();
    _shakeTimer?.cancel();
    _shakeTimer = Timer(const Duration(milliseconds: 200), () {
      shakeOffset = 0.0;
      notifyListeners();
    });
  }

  /// Emit a small dust puff at the given position.
  void puff(Offset position) {
    for (int i = 0; i < 6; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 20 + _random.nextDouble() * 40;
      particles.add(Particle(
        position: position + Offset(_random.nextDouble() * 6 - 3, _random.nextDouble() * 6 - 3),
        velocity: Offset(speed * cos(angle), speed * sin(angle)),
        size: 2 + _random.nextDouble() * 3,
        color: Colors.brown.withOpacity(0.3 + 0.3 * _random.nextDouble()),
        life: 0.3 + _random.nextDouble() * 0.3,
        gravity: 80,
      ));
    }
    notifyListeners();
  }

  void dispose() {
    _shakeTimer?.cancel();
  }
}

class PhysicsParticlePainter extends CustomPainter {
  final List<Particle> particles;

  PhysicsParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      if (!p.alive) continue;
      paint.color = p.color.withOpacity(p.life / (p.life + 0.5));
      canvas.drawCircle(p.position, p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PhysicsParticlePainter oldDelegate) {
    return true; // Always repaint to animate particles
  }
}