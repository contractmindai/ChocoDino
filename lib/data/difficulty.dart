/// Defines the parameters for a given level number. Unbounded – no band resets.
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

/// Continuous difficulty – no resets, everything grows steadily.
DifficultyConfig difficultyForLevel(int level) {
  final lvl = level.clamp(1, 200);

  // ---- Grid size: 5 at level 1, +1 every 10 levels, capped at 10 ----
  final gridSize = (5 + (lvl - 1) ~/ 10).clamp(5, 10);

  // ---- Chocolate count: start at 4, +1 every 4 levels ----
  int chocolateCount = 4 + (lvl - 1) ~/ 4;

  // ---- Obstacle counts – continuous, no resets, start earlier and ramp faster ----
  final rawTreeCount = (lvl * 2) ~/ 5;
  final rawMineCount = lvl < 5 ? 0 : (lvl - 4) ~/ 2 + 1;
  final rawEnemyCount = lvl < 7 ? 0 : (lvl - 6) ~/ 2 + 1;
  final rawHazardCount = lvl < 10 ? 0 : (lvl - 9) ~/ 2 + 1;

  // ---- Cap obstacles to board capacity (max 45% obstacles, was 40%) ----
  final area = gridSize * gridSize;
  final maxObstacles = (area * 0.45).toInt();
  int treeCount = rawTreeCount;
  int mineCount = rawMineCount;
  int enemyCount = rawEnemyCount;
  int hazardCount = rawHazardCount;
  final total = rawTreeCount + rawMineCount + rawEnemyCount + rawHazardCount;
  if (total > maxObstacles && total > 0) {
    final ratio = maxObstacles / total;
    treeCount = (rawTreeCount * ratio).toInt();
    mineCount = (rawMineCount * ratio).toInt();
    enemyCount = (rawEnemyCount * ratio).toInt();
    hazardCount = (rawHazardCount * ratio).toInt();
  }

  // Ensure chocolates fit (max 25% of board, was 35% — a lower density
  // cap leaves more open space for hidden enemies and generally results
  // in cleaner, more reachable boards, especially at higher levels)
  chocolateCount = chocolateCount.clamp(3, (gridSize * gridSize) ~/ 2);
  final maxChoc = (area * 0.25).toInt();
  final finalChocolate = chocolateCount.clamp(3, maxChoc);

  return DifficultyConfig(
    gridSize: gridSize,
    chocolateCount: finalChocolate,
    treeCount: treeCount,
    mineCount: mineCount,
    enemyCount: enemyCount,
    hazardCount: hazardCount,
    maxMoves: 0,
  );
}