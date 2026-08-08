import 'dart:collection';
import 'dart:math';

import '../models/chocolate.dart';
import '../models/level_config.dart';
import '../models/point.dart';
import '../models/sweet_world.dart';
import 'difficulty.dart';
import 'pathfinding.dart';

int _pack(int x, int y) => (x << 4) | y;
int _unpackX(int v) => v >> 4;
int _unpackY(int v) => v & 0xF;

const List<Point> _kAllDirs = [
  Point(1, 0),
  Point(-1, 0),
  Point(0, 1),
  Point(0, -1),
];

LevelConfig generateProceduralLevel(
  int levelNum, {
  int? seed,
  int candidateCount = 10,
}) {
  final effectiveSeed = seed ?? (levelNum * 1000 + 42);
  final difficulty = difficultyForLevel(levelNum);
  final size = difficulty.gridSize;
  final chocolateCount = difficulty.chocolateCount.clamp(3, (size * size) ~/ 2 - 2);

  for (int i = 0; i < candidateCount * 2; i++) {
    final config = _tryGenerateLevel(
      levelNum,
      size,
      chocolateCount,
      difficulty,
      effectiveSeed + i * 37,
    );
    if (config != null) return config;
  }
  return _fallbackLevel(levelNum);
}

LevelConfig? _tryGenerateLevel(
  int levelNum,
  int size,
  int chocolateCount,
  DifficultyConfig difficulty,
  int seed,
) {
  final random = Random(seed);

  final manhattanMinCells = 2 * size - 1;
  final baseTarget = max(chocolateCount + 2, manhattanMinCells + size + 2);

  // Coverage-based target: how much of the board the winding path should
  // fill, growing with level. Bigger grids cap lower so the backtracking
  // search below stays fast; small grids can afford to be filled more.
  final area = size * size;
  final coverageCap = size <= 6 ? 0.78 : (size <= 8 ? 0.62 : 0.52);
  final coverageRatio = (0.42 + levelNum / 150).clamp(0.42, coverageCap);
  final coverageTarget = (area * coverageRatio).round();

  final targetPathLength = max(baseTarget, coverageTarget);
  final mainPath = _generateWindingPath(size, targetPathLength, random);
  if (mainPath.length < chocolateCount + 2) return null;

  final anchors = _pickAnchors(mainPath, chocolateCount, random);
  if (anchors.length < chocolateCount) return null;

  final chocolateCells = [for (final idx in anchors) mainPath[idx]];

  // Defense in depth: anchor indices are picked from disjoint buckets so
  // they should never collide, but if anything upstream ever changes that
  // invariant, this catches two chocolates landing on the same cell
  // immediately and rejects the candidate rather than shipping it.
  if (chocolateCells.toSet().length != chocolateCells.length) return null;

  final pathSet = mainPath.toSet();

  final chocolates = <Chocolate>[];
  for (int i = 0; i < chocolateCells.length; i++) {
    chocolates.add(Chocolate(i + 1, chocolateCells[i].x, chocolateCells[i].y));
  }

  final usedLeafCells = <Point>{};
  final treePoints = <Point>[];
  final treeTarget = difficulty.treeCount.clamp(0, (size * size) ~/ 4);

  for (final choc in chocolateCells) {
    if (treePoints.length >= treeTarget) break;
    final dirs = List<Point>.from(_kAllDirs)..shuffle(random);
    for (final dir in dirs) {
      final cand = Point(choc.x + dir.x, choc.y + dir.y);
      if (cand.x < 0 || cand.y < 0 || cand.x >= size || cand.y >= size) continue;
      if (pathSet.contains(cand) || usedLeafCells.contains(cand)) continue;
      treePoints.add(cand);
      usedLeafCells.add(cand);
      break;
    }
  }

  while (treePoints.length < treeTarget) {
    final p = Point(random.nextInt(size), random.nextInt(size));
    if (pathSet.contains(p) || usedLeafCells.contains(p)) continue;
    treePoints.add(p);
    usedLeafCells.add(p);
  }

  final trees = treePoints.map((p) => _pack(p.x, p.y)).toSet();

  final detourBlocked = {...trees, ...mainPath.map((p) => _pack(p.x, p.y))};
  final detourCount = (size / 3).ceil().clamp(1, 3);
  final detours = _generateDetours(size, mainPath, detourBlocked, random, detourCount);
  final detourCells = {for (final d in detours) ...d.cells};
  final bonusCells = {for (final d in detours) d.bonusCell};

  final guaranteedMineCells = <int>{};
  for (final d in detours) {
    final approachCells = d.cells.sublist(0, d.cells.length - 1);
    if (approachCells.isEmpty) continue;
    final pick = approachCells[random.nextInt(approachCells.length)];
    guaranteedMineCells.add(_pack(pick.x, pick.y));
  }

  final blockedForEnemies = {
    ...trees,
    ...mainPath.map((p) => _pack(p.x, p.y)),
    ...bonusCells.map((p) => _pack(p.x, p.y)),
    ...guaranteedMineCells,
  };
  final enemyPacked = _placeDangerObjects(size, blockedForEnemies, random, difficulty.enemyCount);
  final enemies = enemyPacked.map((p) => Point(_unpackX(p), _unpackY(p))).toSet();

  final enemyList = enemies.toList()..shuffle(random);
  final hiddenCount = (enemyList.length / 2).round();
  final hiddenEnemies = enemyList.take(hiddenCount).toSet();

  final blocked = {...blockedForEnemies, ...enemyPacked};
  final mines = _placeDangerObjects(size, blocked, random, difficulty.mineCount)
    ..addAll(guaranteedMineCells);
  blocked.addAll(mines);
  final hazards = _placeDangerObjects(size, blocked, random, difficulty.hazardCount);

  final dangerSet = {...enemies.map((p) => _pack(p.x, p.y)), ...mines, ...hazards};
  final dangerMap = _buildDangerMap(size, dangerSet);

  // These used to be `assert(...)`, which Dart strips out of release
  // builds entirely — meaning a broken candidate could ship silently in
  // production. Make them real checks: a failure here rejects the
  // candidate and the caller just retries with the next seed.
  if (!_isSolutionPathValid(mainPath, chocolateCells, trees)) return null;
  if (!_areDetoursValid(detours, pathSet, trees)) return null;

  // Belt-and-braces reachability check using the dedicated BFS validator
  // (previously unused elsewhere in the generator): confirm every
  // consecutive chocolate pair, and every detour's bonus cell, is
  // actually reachable given the final tree placement. Trees are the
  // only obstacle that blocks movement (see pathfinding.dart), so they're
  // the only thing that needs to be passed in here.
  final treeKeys = trees.map((p) => '${_unpackX(p)},${_unpackY(p)}').toSet();
  final validator = PathValidator(size, treeKeys);
  for (int i = 0; i < chocolateCells.length - 1; i++) {
    if (!validator.isReachable(chocolateCells[i], chocolateCells[i + 1])) {
      return null;
    }
  }
  for (final d in detours) {
    if (!validator.isReachable(d.cells.first, d.bonusCell)) {
      return null;
    }
  }

  return LevelConfig(
    levelNum,
    size,
    chocolates,
    obstacles: treePoints.map((p) => '${p.x},${p.y}').toSet(),
    mines: mines.map((p) => '${_unpackX(p)},${_unpackY(p)}').toSet(),
    enemies: enemies.map((p) => '${p.x},${p.y}').toSet(),
    hazards: hazards.map((p) => '${_unpackX(p)},${_unpackY(p)}').toSet(),
    dangerMap: dangerMap,
    path: mainPath.map((p) => '${p.x},${p.y}').toSet(),
    world: sweetWorldForLevel(levelNum),
    hiddenEnemies: hiddenEnemies.map((p) => '${p.x},${p.y}').toSet(),
    detours: detourCells.map((p) => '${p.x},${p.y}').toSet(),
    bonusItems: bonusCells.map((p) => '${p.x},${p.y}').toSet(),
  );
}

List<Point> _generateWindingPath(int size, int minLength, Random random) {
  final start = Point(0, 0);
  final end = Point(size - 1, size - 1);
  final visited = <Point>{};
  final path = <Point>[];

  var stepsExplored = 0;
  final maxStepsExplored = size * size * 400;

  bool dfs(Point current, Point? prevDir, int straightRuns) {
    if (++stepsExplored > maxStepsExplored) return false;
    path.add(current);
    visited.add(current);
    if (current == end && path.length >= minLength) return true;

    final dirs = List<Point>.from(_kAllDirs)..shuffle(random);

    for (final d in dirs) {
      final next = Point(current.x + d.x, current.y + d.y);
      if (next.x < 0 || next.y < 0 || next.x >= size || next.y >= size) continue;
      if (visited.contains(next)) continue;
      if (next == end && path.length + 1 < minLength) continue;
      if (!_reachable(next, end, size, visited)) continue;

      final nextStraightRuns = (prevDir != null && d == prevDir) ? straightRuns + 1 : 1;
      if (nextStraightRuns > 2) continue;

      if (dfs(next, d, nextStraightRuns)) return true;
    }

    path.removeLast();
    visited.remove(current);
    return false;
  }

  if (dfs(start, null, 0)) return List.of(path);
  return [];
}

bool _reachable(Point start, Point target, int size, Set<Point> visited) {
  if (start == target) return true;
  final seen = <Point>{start};
  final queue = Queue<Point>()..add(start);

  while (queue.isNotEmpty) {
    final p = queue.removeFirst();
    for (final d in _kAllDirs) {
      final np = Point(p.x + d.x, p.y + d.y);
      if (np.x < 0 || np.y < 0 || np.x >= size || np.y >= size) continue;
      if (visited.contains(np) || seen.contains(np)) continue;
      if (np == target) return true;
      seen.add(np);
      queue.add(np);
    }
  }
  return false;
}

List<int> _pickAnchors(List<Point> mainPath, int count, Random random) {
  if (count <= 0) return [];

  final usableStart = 1;
  final usableEnd = mainPath.length - 2;
  final usableLen = usableEnd - usableStart + 1;

  if (usableLen <= count) {
    final anchors = <int>[];
    for (int i = usableStart; i <= usableEnd; i++) {
      anchors.add(i);
    }
    while (anchors.length < count) {
      anchors.add(usableEnd.clamp(usableStart, mainPath.length - 2));
    }
    return anchors;
  }

  final buckets = <List<int>>[];
  for (int i = 0; i < count; i++) {
    final bucketStart = usableStart + (usableLen * i) ~/ count;
    final bucketEndExclusive = usableStart + (usableLen * (i + 1)) ~/ count;
    final lo = bucketStart;
    final hi = (bucketEndExclusive - 1).clamp(lo, usableEnd);
    buckets.add([lo, hi]);
  }

  final anchors = <int>[];
  final chosenPoints = <Point>[];
  for (final bucket in buckets) {
    final lo = bucket[0], hi = bucket[1];
    final order = [for (int idx = lo; idx <= hi; idx++) idx]..shuffle(random);
    int bestIdx = order.first;
    int bestScore = -1 << 30;
    for (final idx in order) {
      final p = mainPath[idx];
      final score = _anchorScore(p, chosenPoints);
      if (score > bestScore) {
        bestScore = score;
        bestIdx = idx;
      }
    }
    anchors.add(bestIdx);
    chosenPoints.add(mainPath[bestIdx]);
  }

  return anchors;
}

int _anchorScore(Point p, List<Point> chosen) {
  if (chosen.isEmpty) return 1 << 30;
  var minDist = 1 << 30;
  var rowCount = 0;
  var colCount = 0;
  for (final c in chosen) {
    final d = (p.x - c.x).abs() + (p.y - c.y).abs();
    if (d < minDist) minDist = d;
    if (p.x == c.x) rowCount++;
    if (p.y == c.y) colCount++;
  }
  return minDist - 1000 * (rowCount + colCount);
}

class Detour {
  final List<Point> cells;
  Point get bonusCell => cells.last;
  Detour(this.cells);
}

List<Detour> _generateDetours(
  int size,
  List<Point> mainPath,
  Set<int> blocked,
  Random random,
  int count,
) {
  final detours = <Detour>[];
  if (count <= 0) return detours;

  final usableStart = 1;
  final usableEnd = mainPath.length - 2;
  if (usableEnd < usableStart) return detours;
  final usableLen = usableEnd - usableStart + 1;
  final bucketCount = min(count, usableLen);

  // Split the path into `bucketCount` stretches (same bucketing idea used
  // for chocolate anchors) so at most one detour attaches per stretch,
  // instead of a flat shuffle that can happily place every detour near
  // wherever the first successful spur growth happened.
  final chosenAttachPoints = <Point>[];

  for (int i = 0; i < bucketCount; i++) {
    final bucketStart = usableStart + (usableLen * i) ~/ bucketCount;
    final bucketEndExclusive = usableStart + (usableLen * (i + 1)) ~/ bucketCount;
    final lo = bucketStart;
    final hi = (bucketEndExclusive - 1).clamp(lo, usableEnd);

    // Within the bucket, try the cell farthest from already-placed
    // detours first, falling back to the next-farthest if growth fails,
    // so detours actively spread away from each other.
    final order = [for (int idx = lo; idx <= hi; idx++) idx]
      ..sort((a, b) => _anchorScore(mainPath[b], chosenAttachPoints)
          .compareTo(_anchorScore(mainPath[a], chosenAttachPoints)));

    for (final idx in order) {
      final attach = mainPath[idx];
      final spur = _growSpur(size, attach, blocked, random);
      if (spur == null) continue;
      detours.add(Detour(spur));
      chosenAttachPoints.add(attach);
      for (final p in spur) {
        blocked.add(_pack(p.x, p.y));
      }
      break;
    }
  }
  return detours;
}

List<Point>? _growSpur(int size, Point attach, Set<int> blocked, Random random) {
  final maxLen = 2 + random.nextInt(3); // 2-4 cells: longer, more varied pockets
  final spur = <Point>[];
  final localBlocked = {...blocked};
  var current = attach;

  for (int step = 0; step < maxLen; step++) {
    final dirs = List<Point>.from(_kAllDirs)..shuffle(random);
    // Prefer the direction that lands farthest from the attach point, so
    // the spur reads as a distinct pocket instead of hugging back along
    // the main path.
    dirs.sort((a, b) {
      final da = _manhattan(Point(current.x + a.x, current.y + a.y), attach);
      final db = _manhattan(Point(current.x + b.x, current.y + b.y), attach);
      return db.compareTo(da);
    });
    Point? next;
    for (final d in dirs) {
      final cand = Point(current.x + d.x, current.y + d.y);
      if (cand.x < 0 || cand.y < 0 || cand.x >= size || cand.y >= size) continue;
      if (localBlocked.contains(_pack(cand.x, cand.y))) continue;
      next = cand;
      break;
    }
    if (next == null) break;
    spur.add(next);
    localBlocked.add(_pack(next.x, next.y));
    current = next;
  }

  return spur.isEmpty ? null : spur;
}

int _manhattan(Point a, Point b) => (a.x - b.x).abs() + (a.y - b.y).abs();

bool _areDetoursValid(List<Detour> detours, Set<Point> pathSet, Set<int> trees) {
  final claimed = <Point>{};
  for (final d in detours) {
    if (d.cells.isEmpty) return false;
    for (final p in d.cells) {
      if (pathSet.contains(p)) return false;
      if (trees.contains(_pack(p.x, p.y))) return false;
      if (!claimed.add(p)) return false;
    }
  }
  return true;
}



Set<int> _placeDangerObjects(int size, Set<int> blocked, Random random, int count) {
  final candidates = <int>[];
  for (int x = 0; x < size; x++) {
    for (int y = 0; y < size; y++) {
      final p = _pack(x, y);
      if (!blocked.contains(p)) candidates.add(p);
    }
  }
  candidates.shuffle(random);
  return candidates.take(min(count, candidates.length)).toSet();
}

List<List<int>> _buildDangerMap(int size, Set<int> danger) {
  final map = List.generate(size, (_) => List.filled(size, 0));
  for (final packed in danger) {
    final cx = _unpackX(packed), cy = _unpackY(packed);
    for (int x = 0; x < size; x++) {
      for (int y = 0; y < size; y++) {
        final dist = (x - cx).abs() + (y - cy).abs();
        if (dist <= 3) map[x][y] = min(3, map[x][y] + (3 - dist));
      }
    }
  }
  return map;
}

bool _isSolutionPathValid(
  List<Point> solutionPath,
  List<Point> chocolateCells,
  Set<int> trees,
) {
  if (solutionPath.isEmpty) return false;

  final seen = <Point>{};
  for (int i = 0; i < solutionPath.length; i++) {
    final p = solutionPath[i];
    if (!seen.add(p)) return false;
    if (i > 0) {
      final prev = solutionPath[i - 1];
      final step = (p.x - prev.x).abs() + (p.y - prev.y).abs();
      if (step != 1) return false;
    }
  }

  for (final p in solutionPath) {
    if (trees.contains(_pack(p.x, p.y))) return false;
  }

  var lastIdx = -1;
  for (final choc in chocolateCells) {
    final idx = solutionPath.indexOf(choc);
    if (idx <= lastIdx) return false;
    lastIdx = idx;
  }

  return true;
}

LevelConfig _fallbackLevel(int levelNum) {
  return LevelConfig(
    levelNum,
    6,
    [
      Chocolate(1, 0, 2),
      Chocolate(2, 2, 3),
      Chocolate(3, 4, 5),
    ],
    obstacles: {},
    mines: {},
    enemies: {},
    hazards: {},
    dangerMap: List.generate(6, (_) => List.filled(6, 0)),
    path: {
      '0,0',
      '0,1',
      '0,2',
      '1,2',
      '2,2',
      '2,3',
      '3,3',
      '4,3',
      '4,4',
      '4,5',
    },
    world: sweetWorldForLevel(levelNum),
  );
}