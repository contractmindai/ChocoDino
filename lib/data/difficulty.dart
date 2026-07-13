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

/// ⚡ EXTREME DIFFICULTY – more obstacles, faster ramp, but still capped at 40% of board.
/// Guaranteed solvable via BFS validation in the generator.
DifficultyConfig difficultyForLevel(int level) {
  final lvl = level.clamp(1, 200);

  // Grid size: 5 at level 1, +1 every 12 levels, capped at 10.
  final gridSize = (5 + (lvl - 1) ~/ 12).clamp(5, 10);

  // Chocolate count: start at 5, +1 every 3 levels.
  int chocolateCount = 5 + (lvl - 1) ~/ 3;

  // ---- Obstacle counts – much more aggressive ----
  // Trees: start from level 1, grow fast.
  final rawTreeCount = 1 + (lvl ~/ 2); // was lvl~/3

  // Mines: start from level 4.
  final rawMineCount = lvl < 4 ? 0 : 1 + ((lvl - 4) ~/ 2); // was lvl~/3

  // Enemies: start from level 6.
  final rawEnemyCount = lvl < 6 ? 0 : 1 + ((lvl - 6) ~/ 2); // was lvl~/3

  // Hazards: start from level 8.
  final rawHazardCount = lvl < 8 ? 0 : 1 + ((lvl - 8) ~/ 2); // was lvl~/3

  // ---- Cap obstacles to board capacity (max 40% obstacles) ----
  final area = gridSize * gridSize;
  final maxObstacles = (area * 0.4).toInt();
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

  // Ensure chocolates fit (max 35% of board)
  chocolateCount = chocolateCount.clamp(3, (gridSize * gridSize) ~/ 2);
  final maxChoc = (area * 0.35).toInt();
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