import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Smoothly interpolates the dino's on-screen (row, col) toward a logical
/// target using real spring physics instead of snapping straight there.
/// A synthetic parabola layered on top of the same clock gives each hop a
/// little vertical arc, so it reads as a hop rather than a slide.
class DinoMotionController extends ChangeNotifier {
  double row;
  double col;
  double _rowVelocity = 0;
  double _colVelocity = 0;
  double _targetRow;
  double _targetCol;
  double _hopClock = 0; // 0..1 progress of the current hop
  bool _hopping = false;

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 180,
    damping: 20,
  );

  DinoMotionController({required int startRow, required int startCol})
      : row = startRow.toDouble(),
        col = startCol.toDouble(),
        _targetRow = startRow.toDouble(),
        _targetCol = startCol.toDouble();

  /// 0..1 parabola — 0 on the ground, peaks mid-hop.
  double get hopHeight => _hopping ? (4 * _hopClock * (1 - _hopClock)) : 0;

  void attach(TickerProvider vsync) {
    _ticker?.dispose();
    _lastElapsed = Duration.zero;
    _ticker = vsync.createTicker(_onTick)..start();
  }

  void moveTo(int newRow, int newCol) {
    if (newRow == _targetRow && newCol == _targetCol) return;
    _targetRow = newRow.toDouble();
    _targetCol = newCol.toDouble();
    _hopClock = 0;
    _hopping = true;
  }

  /// Instantly relocate with no spring/arc — used on level retry/reset.
  void snapTo(int newRow, int newCol) {
    row = newRow.toDouble();
    col = newCol.toDouble();
    _targetRow = row;
    _targetCol = col;
    _rowVelocity = 0;
    _colVelocity = 0;
    _hopping = false;
    _hopClock = 0;
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0 || dt > 0.1) return;

    final rowSim = SpringSimulation(_spring, row, _targetRow, _rowVelocity);
    final colSim = SpringSimulation(_spring, col, _targetCol, _colVelocity);
    row = rowSim.x(dt);
    _rowVelocity = rowSim.dx(dt);
    col = colSim.x(dt);
    _colVelocity = colSim.dx(dt);

    if (_hopping) {
      _hopClock += dt * 3.2; // ~0.3s hop
      if (_hopClock >= 1) {
        _hopClock = 1;
        _hopping = false;
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}