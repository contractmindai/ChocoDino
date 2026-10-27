// lib/pathfinding/patrol_enemy.dart
//
// The rival dinosaur: walks the level's main solution path back and
// forth (bounces at each end, like a classic patrol guard), and "catches"
// any chocolate it steps onto before the player collects it.
//
// This is deliberately framework-agnostic — it doesn't know about
// Flutter widgets, Timers, or Tickers. Your game screen owns the clock
// (a Timer.periodic, an AnimationController, or a Ticker — whatever you
// already use for the rest of the game loop) and calls [tick] once per
// frame/interval. That keeps this class trivially testable and reusable
// regardless of how your board is rendered.

import '../models/point.dart';

/// Runtime state for the patrolling rival. Construct one per level, from
/// that level's [LevelConfig.orderedPath].
class PatrolEnemy {
  /// The route to walk, in order. Must have at least 2 points (a route
  /// of length 1 can't patrol anywhere).
  final List<Point> route;

  /// How long the dinosaur spends on each cell before advancing to the
  /// next one. Smaller = faster, more aggressive rival.
  final Duration stepInterval;

  int _index;
  bool _forward = true;
  Duration _elapsed = Duration.zero;

  PatrolEnemy({
    required this.route,
    this.stepInterval = const Duration(milliseconds: 350),
    int startIndex = 0,
  })  : assert(route.length >= 2, 'PatrolEnemy needs a route of at least 2 cells'),
        _index = startIndex.clamp(0, route.length - 1);

  /// The dinosaur's current cell.
  Point get position => route[_index];

  /// True while the dinosaur is walking start→end; false on the return
  /// leg. Useful if you want to flip the sprite horizontally.
  bool get isMovingForward => _forward;

  /// Advance the patrol by [delta] of real time. Call this every frame or
  /// timer tick from your game loop.
  ///
  /// [remainingChocolates] should be the set of chocolate cells the
  /// player hasn't collected yet (as [Point]s — convert from whatever
  /// your board state uses before calling). If the dinosaur's new
  /// position lands on one of them, it's returned so the caller can
  /// remove it from play (mark it "caught", update the score/UI, play a
  /// sound, etc). If the dinosaur passes over more than one chocolate in
  /// a single [tick] call (e.g. a big [delta] after a dropped frame),
  /// only the last one caught is returned — call [tick] with smaller
  /// deltas (i.e. every frame) if you need to catch that edge case, which
  /// in practice essentially never matters here since chocolates are one
  /// cell apart at minimum.
  Point? tick(Duration delta, Set<Point> remainingChocolates) {
    _elapsed += delta;
    Point? caught;

    while (_elapsed >= stepInterval) {
      _elapsed -= stepInterval;
      _advanceOneStep();
      if (remainingChocolates.contains(position)) {
        caught = position;
      }
    }

    return caught;
  }

  void _advanceOneStep() {
    if (route.length < 2) return;
    if (_forward) {
      _index++;
      if (_index >= route.length - 1) {
        _index = route.length - 1;
        _forward = false;
      }
    } else {
      _index--;
      if (_index <= 0) {
        _index = 0;
        _forward = true;
      }
    }
  }

  /// Reset to the start of the route, walking forward. Call this when
  /// restarting a level.
  void reset({int startIndex = 0}) {
    _index = startIndex.clamp(0, route.length - 1);
    _forward = true;
    _elapsed = Duration.zero;
  }

  /// Whether the dinosaur currently occupies the same cell as the player.
  /// This is a plain position check, not a life/score system — your game
  /// loop decides what happens on a hit (decrement a life, reset the
  /// player to the start, flash the screen, etc), since that logic lives
  /// wherever your existing life-tracking state does, not here.
  ///
  /// Call this every frame, after both the player's position and
  /// [tick] have been updated for that frame — a hit can happen either
  /// because the dinosaur just stepped onto the player's cell, or because
  /// the player just dragged onto the dinosaur's cell, so checking only
  /// right after [tick] would miss the second case.
  bool collidesWithPlayer(Point playerPosition) => playerPosition == position;
}