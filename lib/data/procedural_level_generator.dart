import 'dart:collection';
import 'dart:math';

import '../models/chocolate.dart';
import '../models/level_config.dart';
import '../models/point.dart';
import '../models/sweet_world.dart';
import 'difficulty.dart';
import 'pathfinding.dart';

// Pack / unpack (board ≤ 10)
int _pack(int x, int y) => (x << 4) | y;
int _unpackX(int packed) => packed >> 4;
int _unpackY(int packed) => packed & 0xF;

class _LevelCandidate {
  final LevelConfig config;
  final double score;
  _LevelCandidate(this.config, this.score);
}

/// Generates a procedurally built level with guaranteed solvability.
LevelConfig generateProceduralLevel(
  int levelNum, {
  int? seed,
  int candidateCount = 10, // more attempts = better chance
}) {
  final effectiveSeed = seed ?? (levelNum * 1000 + 42);
  final difficulty = difficultyForLevel(levelNum);
  final size = difficulty.gridSize;
  int chocolateCount = difficulty.chocolateCount;
  final maxPossible = (size * size) ~/ 2;
  if (chocolateCount > maxPossible) chocolateCount = maxPossible;
  if (chocolateCount < 3) chocolateCount = 3;

  final candidates = <_LevelCandidate>[];

  for (int attempt = 0; attempt < candidateCount * 2; attempt++) {
    final int currentSeed = effectiveSeed + attempt * 37;
    final config = _tryGenerateLevel(
      levelNum,
      size,
      chocolateCount,
      difficulty,
      currentSeed,
    );
    if (config != null) {
      final score = _scoreLevel(config);
      candidates.add(_LevelCandidate(config, score));
      if (candidates.length >= candidateCount) break;
    }
  }

  if (candidates.isEmpty) {
    // Fallback to a guaranteed solvable level
    return _fallbackLevel(levelNum);
  }

  candidates.sort((a, b) => b.score.compareTo(a.score));
  return candidates.first.config;
}

LevelConfig? _tryGenerateLevel(
  int levelNum,
  int size,
  int chocolateCount,
  DifficultyConfig difficulty,
  int seed,
) {
  final random = Random(seed);

  // ----- 1. Generate a winding path (with DFS limit) -----
  List<Point> fullPath = _generateWindingPath(size, random);
  if (fullPath.isEmpty) return null;
  final Set<int> pathSet = fullPath.map((p) => _pack(p.x, p.y)).toSet();

  // ----- 2. Place chocolates along the path -----
  List<Point> allCells = fullPath
      .where((p) => !(p.x == 0 && p.y == 0) && !(p.x == size - 1 && p.y == size - 1))
      .toList();
  if (allCells.length < chocolateCount) chocolateCount = allCells.length;

  final weights = allCells
      .map((p) => (_minDistanceToBorder(p, size) + 1).toDouble())
      .toList();

  final chocolateCells = <Point>[];
  final usedChocolatePacked = <int>{};
  int selectAttempts = 0;
  while (chocolateCells.length < chocolateCount && selectAttempts < 1000) {
    selectAttempts++;
    double totalWeight = 0;
    for (int i = 0; i < allCells.length; i++) {
      if (!usedChocolatePacked.contains(_pack(allCells[i].x, allCells[i].y))) {
        totalWeight += weights[i];
      }
    }
    if (totalWeight == 0) break;

    double r = random.nextDouble() * totalWeight;
    double cum = 0;
    int selectedIdx = -1;
    for (int i = 0; i < allCells.length; i++) {
      if (usedChocolatePacked.contains(_pack(allCells[i].x, allCells[i].y))) continue;
      cum += weights[i];
      if (r <= cum) {
        selectedIdx = i;
        break;
      }
    }
    if (selectedIdx == -1) break;

    final candidate = allCells[selectedIdx];
    final tooClose = chocolateCells.any((c) =>
        (c.x - candidate.x).abs() <= 1 && (c.y - candidate.y).abs() <= 1);
    if (!tooClose) {
      chocolateCells.add(candidate);
      usedChocolatePacked.add(_pack(candidate.x, candidate.y));
    }
  }

  // Sort by path order
  final pathIndex = <int, int>{};
  for (int i = 0; i < fullPath.length; i++) {
    pathIndex[_pack(fullPath[i].x, fullPath[i].y)] = i;
  }
  chocolateCells.sort((a, b) {
    final idxA = pathIndex[_pack(a.x, a.y)] ?? 0;
    final idxB = pathIndex[_pack(b.x, b.y)] ?? 0;
    return idxA.compareTo(idxB);
  });

  final chocolates = <Chocolate>[];
  for (int i = 0; i < chocolateCells.length; i++) {
    chocolates.add(Chocolate(i + 1, chocolateCells[i].x, chocolateCells[i].y));
  }

  final chocolateKeys = chocolateCells.map((p) => _pack(p.x, p.y)).toSet();
  // Reserve the ENTIRE path, not just start/end/chocolates. Previously only
  // those three cell types were protected, which left ordinary path tiles
  // open to mines/enemies/hazards — those could land directly on the only
  // route between two chocolates and silently make the level unsolvable,
  // since the reachability check below never treated them as blockers.
  final reserved = Set<int>.from(pathSet);

  // ----- 3. BFS distance maps -----
  final (manhattanDist, chebyshevDist) = _buildDistanceMaps(size, fullPath);

  // ----- 4. Place trees with corridor protection -----
  final treeCandidates = <int>[];
  final treeWeights = <double>[];

  final corridorSet = <int>{};
  for (final p in fullPath) {
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        if (dx.abs() + dy.abs() != 1) continue;
        final nx = p.x + dx, ny = p.y + dy;
        if (nx >= 0 && nx < size && ny >= 0 && ny < size) {
          corridorSet.add(_pack(nx, ny));
        }
      }
    }
  }

  for (int x = 0; x < size; x++) {
    for (int y = 0; y < size; y++) {
      final packed = _pack(x, y);
      if (pathSet.contains(packed) || corridorSet.contains(packed)) continue;
      final manDist = manhattanDist[x][y];
      final chebDist = chebyshevDist[x][y];
      double weight = manDist.toDouble() * 2.0;
      if (chebDist == 1) weight *= 1.5;
      treeCandidates.add(packed);
      treeWeights.add(weight);
    }
  }

  final trees = <int>{};
  int actualTreeCount = difficulty.treeCount.clamp(0, treeCandidates.length);
  double totalTreeWeight = treeWeights.fold(0.0, (a, b) => a + b);

  while (trees.length < actualTreeCount && treeCandidates.isNotEmpty) {
    double roll = random.nextDouble() * totalTreeWeight;
    double cum = 0;
    int pickedIdx = -1;
    for (int i = 0; i < treeCandidates.length; i++) {
      cum += treeWeights[i];
      if (roll <= cum) {
        pickedIdx = i;
        break;
      }
    }
    if (pickedIdx == -1) break;

    final packed = treeCandidates.removeAt(pickedIdx);
    final weightRemoved = treeWeights.removeAt(pickedIdx);
    totalTreeWeight -= weightRemoved;
    trees.add(packed); // removed adjacency check for more flexibility
  }

  // Ensure each chocolate has at least 2 open neighbours
  for (final c in chocolateCells) {
    int cleanApproaches = 0;
    final neighbours = <Point>[];
    for (final d in const [Point(-1, 0), Point(1, 0), Point(0, -1), Point(0, 1)]) {
      final nx = c.x + d.x, ny = c.y + d.y;
      if (nx >= 0 && nx < size && ny >= 0 && ny < size) {
        neighbours.add(Point(nx, ny));
        if (!trees.contains(_pack(nx, ny))) cleanApproaches++;
      }
    }
    if (cleanApproaches < 2) {
      for (final n in neighbours) {
        if (trees.remove(_pack(n.x, n.y))) {
          cleanApproaches++;
          if (cleanApproaches >= 2) break;
        }
      }
    }
  }

  // ----- 5. Place mines, enemies, hazards with quadrant balancing -----
  final chocolateNeighbourKeys = <int>{};
  for (final c in chocolateCells) {
    for (final d in const [Point(-1, 0), Point(1, 0), Point(0, -1), Point(0, 1)]) {
      final nx = c.x + d.x, ny = c.y + d.y;
      if (nx >= 0 && nx < size && ny >= 0 && ny < size) {
        chocolateNeighbourKeys.add(_pack(nx, ny));
      }
    }
  }

  final dangerCandidates = <int>[];
  for (int x = 0; x < size; x++) {
    for (int y = 0; y < size; y++) {
      final packed = _pack(x, y);
      if (!reserved.contains(packed) &&
          !trees.contains(packed) &&
          !chocolateNeighbourKeys.contains(packed)) {
        dangerCandidates.add(packed);
      }
    }
  }

  final dangerPicks = _pickSpreadOutBalanced(
    dangerCandidates,
    difficulty.mineCount + difficulty.enemyCount + difficulty.hazardCount,
    size,
    random,
  );

  final mines = <int>{};
  final enemies = <int>{};
  final hazards = <int>{};
  int idx = 0;
  for (int i = 0; i < difficulty.mineCount && idx < dangerPicks.length; i++, idx++) {
    mines.add(dangerPicks[idx]);
  }
  for (int i = 0; i < difficulty.enemyCount && idx < dangerPicks.length; i++, idx++) {
    enemies.add(dangerPicks[idx]);
  }
  for (int i = 0; i < difficulty.hazardCount && idx < dangerPicks.length; i++, idx++) {
    hazards.add(dangerPicks[idx]);
  }

  final dangerMap = _buildDangerMap(size, {...mines, ...enemies, ...hazards});

  // ----- 6. Path validation (simple) -----
  bool isPathValid = true;
  final seenOnWalk = <int>{};
  int chocPtr = 0;
  for (final p in fullPath) {
    final packed = _pack(p.x, p.y);
    if (trees.contains(packed) || !seenOnWalk.add(packed)) {
      isPathValid = false;
      break;
    }
    if (chocPtr < chocolateCells.length && p == chocolateCells[chocPtr]) {
      chocPtr++;
    }
  }
  if (!isPathValid || chocPtr != chocolateCells.length || fullPath.last != Point(size - 1, size - 1)) {
    return null;
  }

  // ----- 7. BFS reachability check between consecutive chocolates -----
  final blockedForReach = <String>{};
  for (final t in trees) {
    blockedForReach.add('${_unpackX(t)},${_unpackY(t)}');
  }
  final validator = PathValidator(size, blockedForReach);
  final start = Point(0, 0);
  final end = Point(size - 1, size - 1);

  // Previously only consecutive chocolate pairs were checked, so a config
  // could pass validation despite the run from (0,0) to the first chocolate,
  // or from the last chocolate to the exit, being blocked. Check the full
  // chain: start -> choc[0] -> choc[1] -> ... -> choc[n-1] -> end.
  if (chocolates.isEmpty) {
    if (!validator.isReachable(start, end)) return null;
  } else {
    final firstChoc = Point(chocolates.first.row, chocolates.first.col);
    final lastChoc = Point(chocolates.last.row, chocolates.last.col);
    if (!validator.isReachable(start, firstChoc)) return null;
    if (!validator.isReachable(lastChoc, end)) return null;
    for (int i = 0; i < chocolates.length - 1; i++) {
      final from = Point(chocolates[i].row, chocolates[i].col);
      final to = Point(chocolates[i + 1].row, chocolates[i + 1].col);
      if (!validator.isReachable(from, to)) {
        // If unreachable, try to salvage by removing a tree near the path? 
        // For now, discard this candidate.
        return null;
      }
    }
  }

  // ----- 8. Convert to LevelConfig -----
  final world = sweetWorldForLevel(levelNum);
  final obstacleStrings = trees.map((p) => '${_unpackX(p)},${_unpackY(p)}').toSet();
  final mineStrings = mines.map((p) => '${_unpackX(p)},${_unpackY(p)}').toSet();
  final enemyStrings = enemies.map((p) => '${_unpackX(p)},${_unpackY(p)}').toSet();
  final hazardStrings = hazards.map((p) => '${_unpackX(p)},${_unpackY(p)}').toSet();
  final pathStrings = fullPath.map((p) => '${p.x},${p.y}').toSet();

  return LevelConfig(
    levelNum,
    size,
    chocolates,
    obstacles: obstacleStrings,
    mines: mineStrings,
    enemies: enemyStrings,
    hazards: hazardStrings,
    dangerMap: dangerMap,
    path: pathStrings,
    world: world,
  );
}

/// Generates a winding path using DFS with a step limit.
List<Point> _generateWindingPath(int size, Random random) {
  final visited = <Point>{};
  final path = <Point>[];
  final start = Point(0, 0);
  final end = Point(size - 1, size - 1);
  int dfsSteps = 0;
  const maxSteps = 5000;

  visited.add(start);
  path.add(start);

  bool dfs(Point current) {
    dfsSteps++;
    if (dfsSteps > maxSteps) return false;
    if (current == end) return true;
    final neighbours = <Point>[];
    for (final d in const [Point(1, 0), Point(0, 1), Point(-1, 0), Point(0, -1)]) {
      final nx = current.x + d.x;
      final ny = current.y + d.y;
      final np = Point(nx, ny);
      if (nx >= 0 && nx < size && ny >= 0 && ny < size && !visited.contains(np)) {
        neighbours.add(np);
      }
    }
    neighbours.shuffle(random);
    for (final next in neighbours) {
      visited.add(next);
      path.add(next);
      if (dfs(next)) return true;
      path.removeLast();
      visited.remove(next);
    }
    return false;
  }

  return dfs(start) ? path : [];
}

List<int> _pickSpreadOutBalanced(List<int> candidates, int count, int size, Random rnd) {
  if (count <= 0 || candidates.isEmpty) return [];
  final mid = size / 2;
  final quadrants = <String, List<int>>{};
  for (final packed in candidates) {
    final x = _unpackX(packed);
    final y = _unpackY(packed);
    final qx = x < mid ? 'L' : 'R';
    final qy = y < mid ? 'U' : 'D';
    final key = '$qx$qy';
    quadrants.putIfAbsent(key, () => []).add(packed);
  }
  for (final list in quadrants.values) {
    list.shuffle(rnd);
  }
  final chosen = <int>[];
  while (chosen.length < count && quadrants.isNotEmpty) {
    bool anyTaken = false;
    for (final key in quadrants.keys.toList()) {
      if (chosen.length >= count) break;
      final bucket = quadrants[key]!;
      if (bucket.isNotEmpty) {
        chosen.add(bucket.removeLast());
        anyTaken = true;
      } else {
        quadrants.remove(key);
      }
    }
    if (!anyTaken) break;
  }
  return chosen;
}

double _scoreLevel(LevelConfig config) {
  final size = config.gridSize;
  final obstacleSet = config.obstacles.map((s) {
    final parts = s.split(',');
    return _pack(int.parse(parts[0]), int.parse(parts[1]));
  }).toSet();

  // Quadrant balance
  final mid = size / 2;
  final quadrantCounts = [0, 0, 0, 0];
  for (final packed in obstacleSet) {
    final x = _unpackX(packed);
    final y = _unpackY(packed);
    final qx = x < mid ? 0 : 1;
    final qy = y < mid ? 0 : 1;
    final idx = qx * 2 + qy;
    quadrantCounts[idx]++;
  }
  final mean = quadrantCounts.reduce((a, b) => a + b) / quadrantCounts.length;
  double variance = 0;
  for (final count in quadrantCounts) {
    variance += (count - mean) * (count - mean);
  }
  final balanceScore = 1.0 / (1.0 + variance);

  // Dead‑ends
  final pathSet = config.path.map((s) {
    final parts = s.split(',');
    return _pack(int.parse(parts[0]), int.parse(parts[1]));
  }).toSet();
  final chocolateSet = config.chocolates.map((c) => _pack(c.row, c.col)).toSet();
  int deadEnds = 0;
  for (int x = 0; x < size; x++) {
    for (int y = 0; y < size; y++) {
      final packed = _pack(x, y);
      if (pathSet.contains(packed) || chocolateSet.contains(packed) || obstacleSet.contains(packed)) continue;
      int openNeighbours = 0;
      for (final d in const [Point(1, 0), Point(0, 1), Point(-1, 0), Point(0, -1)]) {
        final nx = x + d.x, ny = y + d.y;
        if (nx >= 0 && nx < size && ny >= 0 && ny < size) {
          if (!obstacleSet.contains(_pack(nx, ny))) openNeighbours++;
        }
      }
      if (openNeighbours == 1) deadEnds++;
    }
  }
  final deadEndScore = 1.0 / (1.0 + deadEnds);

  // Branching
  int totalBranch = 0;
  int countBranch = 0;
  for (int x = 0; x < size; x++) {
    for (int y = 0; y < size; y++) {
      final packed = _pack(x, y);
      if (pathSet.contains(packed) || chocolateSet.contains(packed) || obstacleSet.contains(packed)) continue;
      int open = 0;
      for (final d in const [Point(1, 0), Point(0, 1), Point(-1, 0), Point(0, -1)]) {
        final nx = x + d.x, ny = y + d.y;
        if (nx >= 0 && nx < size && ny >= 0 && ny < size) {
          if (!obstacleSet.contains(_pack(nx, ny))) open++;
        }
      }
      totalBranch += open;
      countBranch++;
    }
  }
  final avgBranch = countBranch > 0 ? totalBranch / countBranch : 1.0;
  final branchScore = avgBranch / 4.0;

  return 0.4 * balanceScore + 0.3 * deadEndScore + 0.3 * branchScore;
}

/// Guaranteed solvable fallback level (6x6, no obstacles, clear path).
LevelConfig _fallbackLevel(int levelNum) {
  final world = sweetWorldForLevel(levelNum);
  return LevelConfig(
    levelNum,
    6,
    [
      Chocolate(1, 0, 1),
      Chocolate(2, 1, 3),
      Chocolate(3, 3, 2),
      Chocolate(4, 5, 4),
    ],
    obstacles: {},
    mines: {},
    enemies: {},
    hazards: {},
    dangerMap: List.generate(6, (_) => List.filled(6, 0)),
    path: {
      '0,1','0,2','1,2','1,3','2,3','3,3','3,2','4,2','4,3','5,3','5,4'
    },
    world: world,
  );
}

(List<List<int>>, List<List<int>>) _buildDistanceMaps(int size, List<Point> path) {
  final manhattan = List.generate(size, (_) => List.filled(size, -1));
  final chebyshev = List.generate(size, (_) => List.filled(size, -1));

  final dirs4 = const [Point(1, 0), Point(0, 1), Point(-1, 0), Point(0, -1)];
  final dirs8 = const [
    Point(1, 0), Point(0, 1), Point(-1, 0), Point(0, -1),
    Point(1, 1), Point(1, -1), Point(-1, 1), Point(-1, -1),
  ];

  // Manhattan BFS
  final q1 = Queue<Point>.from(path);
  for (final p in path) manhattan[p.x][p.y] = 0;
  while (q1.isNotEmpty) {
    final c = q1.removeFirst();
    final d = manhattan[c.x][c.y];
    for (final dir in dirs4) {
      final nx = c.x + dir.x, ny = c.y + dir.y;
      if (nx >= 0 && nx < size && ny >= 0 && ny < size && manhattan[nx][ny] == -1) {
        manhattan[nx][ny] = d + 1;
        q1.add(Point(nx, ny));
      }
    }
  }

  // Chebyshev BFS
  final q8 = Queue<Point>.from(path);
  for (final p in path) chebyshev[p.x][p.y] = 0;
  while (q8.isNotEmpty) {
    final c = q8.removeFirst();
    final d = chebyshev[c.x][c.y];
    for (final dir in dirs8) {
      final nx = c.x + dir.x, ny = c.y + dir.y;
      if (nx >= 0 && nx < size && ny >= 0 && ny < size && chebyshev[nx][ny] == -1) {
        chebyshev[nx][ny] = d + 1;
        q8.add(Point(nx, ny));
      }
    }
  }

  return (manhattan, chebyshev);
}

int _minDistanceToBorder(Point p, int size) {
  int d = min(p.x, size - 1 - p.x);
  d = min(d, p.y);
  d = min(d, size - 1 - p.y);
  return d;
}

List<List<int>> _buildDangerMap(int size, Set<int> dangerPacked) {
  final map = List.generate(size, (_) => List.filled(size, 0));

  for (final packed in dangerPacked) {
    final cx = _unpackX(packed);
    final cy = _unpackY(packed);

    for (int x = 0; x < size; x++) {
      for (int y = 0; y < size; y++) {
        final dist = (x - cx).abs() + (y - cy).abs();
        if (dist <= 2) {
          final contribution = (3 - dist).clamp(0, 3);
          map[x][y] = (map[x][y] + contribution).clamp(0, 3);
        }
      }
    }
  }
  return map;
}