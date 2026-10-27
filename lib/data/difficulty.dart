import 'dart:math' show max, min;

class DifficultyConfig {
  final int gridSize;
  final int chocolateCount;
  final int treeCount;
  final int mineCount;
  final int enemyCount;
  final int hazardCount;
  final int maxMoves;

  const DifficultyConfig({
    required this.gridSize,
    required this.chocolateCount,
    required this.treeCount,
    required this.mineCount,
    required this.enemyCount,
    required this.hazardCount,
    this.maxMoves = 0,
  });
}

DifficultyConfig difficultyForLevel(int level) {
  final lvl = level.clamp(1, 200);

  // Grid size: 5 at level 1, +1 every 10 levels, capped at 10
  final gridSize = (5 + (lvl - 1) ~/ 10).clamp(5, 10);

  // Chocolate count
  int chocolateCount = 4 + (lvl - 1) ~/ 4;

  // Obstacle counts – early levels get extra trees for visual interest
  int treeCount = lvl < 2 ? 3 : (lvl < 4 ? 4 : (lvl * 2) ~/ 5 + 2);
  int mineCount   = lvl < 4 ? 0 : (lvl - 3) ~/ 2;
  int enemyCount  = lvl < 5 ? 0 : (lvl - 4) ~/ 2;
  int hazardCount = lvl < 7 ? 0 : (lvl - 6) ~/ 2;

  // Cap total obstacles to 45% of board
  final area = gridSize * gridSize;
  final maxObstacles = (area * 0.45).toInt();
  int total = treeCount + mineCount + enemyCount + hazardCount;
  if (total > maxObstacles) {
    final ratio = maxObstacles / total;
    treeCount   = (treeCount   * ratio).toInt();
    mineCount   = (mineCount   * ratio).toInt();
    enemyCount  = (enemyCount  * ratio).toInt();
    hazardCount = (hazardCount * ratio).toInt();
    total = treeCount + mineCount + enemyCount + hazardCount;
  }

  // Clamp chocolate count
  final maxChoc = (area * 0.25).toInt();
  chocolateCount = chocolateCount.clamp(3, maxChoc);

  return DifficultyConfig(
    gridSize: gridSize,
    chocolateCount: chocolateCount,
    treeCount: treeCount,
    mineCount: mineCount,
    enemyCount: enemyCount,
    hazardCount: hazardCount,
    maxMoves: 0,
  );
}

// ============================================================================
// PUZZLE TARGETS (used by the solver-verified generator)
// ============================================================================

class PuzzleTargets {
  /// Board is "tight enough" when the solver finds at most this many
  /// different valid runs. Loose early, tight late.
  final int maxAlternativeSolutions;

  /// Extra damage points a player may take beyond the intended route.
  /// Shrinks with level so improvising costs more.
  final int riskSlack;

  /// Decoy bypasses: attractive shortcuts that skip at least one chocolate.
  final int shortcutCount;

  /// Fraction of guards (enemy/mine/hazard) placed ON the intended route
  /// instead of beside it.
  final double spineGateFraction;

  const PuzzleTargets({
    required this.maxAlternativeSolutions,
    required this.riskSlack,
    required this.shortcutCount,
    required this.spineGateFraction,
  });
}

PuzzleTargets puzzleTargetsForLevel(int level) {
  final lvl = max(1, min(200, level));
  return PuzzleTargets(
    maxAlternativeSolutions: max(2, (20 - 0.45 * lvl).round()),
    riskSlack: max(0, 4 - lvl ~/ 10),
    shortcutCount: min(1 + lvl ~/ 8, 4),
    spineGateFraction: min(0.8, 0.3 + lvl / 80),
  );
}

/// Chocolate density cap: ~1 chocolate per 6 board cells. Anything denser
/// cannot be spaced out along the path, which is what produced the
/// "couple of squares apart" clusters. Difficulty comes from guards, not
/// from cramming more chocolates in.
int maxChocolatesForBoard(int size) => max(3, (size * size * 0.17).floor());