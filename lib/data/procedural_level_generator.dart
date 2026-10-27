// lib/generation/procedural_level_generator.dart
//
// Simple, self-contained level generator. Four rules, all enforced in code:
//
//   1. The route (start -> every chocolate in order -> finish) is built FIRST
//      and is never touched. No obstacle, mine, enemy or hazard is ever placed
//      on it, so the route can never be blocked.
//   2. Chocolates: exactly the number the difficulty table asks for, spaced
//      along the route (no staircases, no clusters).
//   3. Every obstacle has a purpose, and it is checked: an obstacle exists only
//      to close an ALTERNATIVE to the route (a corner-cut or side loop that
//      rejoins the route without skipping a chocolate). After placement each
//      obstacle is taken away on its own; if no alternative comes back, it was
//      decoration and is deleted. The board is never "filled": you get as many
//      obstacles as there are alternatives worth closing (at most 30% of the
//      cells, and never more than the difficulty table's budget).
//   4. Variety: for campaign levels the route is compared with the previous 4
//      levels of the same board size and rejected if it looks like any of them.
//      Deterministic: the same level number always gives the same board.
//
// There is no fixed fallback board. If something went wrong the safe fallback
// is still generated from the level number, and has a clear route.
//
// Public API is unchanged: generateProceduralLevel(levelNum, seed:, ...).
//
// This file depends only on the models and difficulty.dart. The earlier helper
// files (puzzle_solver, detour_placement, spine_variety, chocolate_placement)
// are no longer used and can be deleted.

import 'dart:math' show Random, max, min;
import 'dart:typed_data';

import '../models/chocolate.dart';
import '../models/level_config.dart';
import '../models/point.dart';
import '../models/sweet_world.dart';
import 'difficulty.dart';

// ============================================================================
// PUBLIC API
// ============================================================================

LevelConfig generateProceduralLevel(
  int levelNum, {
  int? seed,
  int candidateCount = 30,
  bool enableTrees = true,
}) {
  final campaign = seed == null; // campaign levels also compare with neighbours
  final effectiveSeed = seed ?? _campaignSeed(levelNum);
  final tries = min(24, max(8, candidateCount));

  final design = _finalDesign(levelNum, effectiveSeed, campaign, tries);
  if (design != null) {
    final level = _finish(levelNum, design, enableTrees);
    if (level != null) return level;
  }
  return _safeLevel(levelNum);
}

int _campaignSeed(int level) => level * 1000 + 42;

// ============================================================================
// CONSTANTS + SMALL HELPERS
// ============================================================================

/// Only alternatives that skip at most this many route cells matter.
const int _maxSkip = 12;

/// An alternative is "tempting" if it is at most 2 steps longer than the
/// stretch of route it replaces (shorter or equal is even more tempting).
const int _tempt = -2;

const List<int> _dx = [1, -1, 0, 0];
const List<int> _dy = [0, 0, 1, -1];
const List<Point> _dirs = [
  Point(1, 0),
  Point(-1, 0),
  Point(0, 1),
  Point(0, -1),
];

int _man(Point a, Point b) => (a.x - b.x).abs() + (a.y - b.y).abs();

class _Design {
  final int size;
  final List<Point> route; // (0,0) .. (size-1,size-1)
  final List<int> idx; // chocolate positions as indices into [route]
  final List<int> closers; // packed cells worth closing, most important first
  final int count;
  const _Design(this.size, this.route, this.idx, this.closers, this.count);
}

// ============================================================================
// DESIGN SELECTION (deterministic, with variety)
// ============================================================================

final Map<String, _Design?> _designMemo = <String, _Design?>{};

_Design? _finalDesign(int level, int seed, bool campaign, int tries) {
  final memoKey = '$level:$seed:$tries';
  if (campaign && _designMemo.containsKey(memoKey)) {
    return _designMemo[memoKey];
  }

  final d = difficultyForLevel(level);
  final size = d.gridSize;
  final area = size * size;
  final budget = min(
    d.treeCount + d.mineCount + d.enemyCount + d.hazardCount,
    (area * 0.30).floor(),
  );
  // Enough closable alternatives that the board is not bare.
  final wantClosers = min(budget, max(3, (0.08 * area).round()));

  final neighbours = <_Design>[];
  if (campaign) {
    for (var j = 1; j <= 4; j++) {
      final lv = level - j;
      if (lv < 1 || difficultyForLevel(lv).gridSize != size) continue;
      final n = _finalDesign(lv, _campaignSeed(lv), true, tries);
      if (n != null) neighbours.add(n);
    }
  }

  _Design? best;
  var bestScore = double.negativeInfinity;
  for (var r = 0; r < tries; r++) {
    final cand = _rawDesign(level, seed + r * 7919);
    if (cand == null) continue;
    var maxSim = 0.0;
    for (final n in neighbours) {
      maxSim = max(maxSim, _similarity(cand.route, n.route, size));
    }
    final rich = min(cand.closers.length, wantClosers);
    final unlike = maxSim < 0.5;
    final full = unlike && rich >= wantClosers;
    final score = (full ? 1000000.0 : 0.0) +
        (unlike ? 100000.0 : 0.0) +
        rich * 1000.0 -
        maxSim * 100.0;
    if (score > bestScore) {
      bestScore = score;
      best = cand;
    }
    if (full) break;
  }

  if (campaign) _designMemo[memoKey] = best;
  return best;
}

/// Route + chocolates + the alternatives worth closing. Best of 8 routes,
/// judged by how many purposeful obstacles the board can host.
_Design? _rawDesign(int level, int seed) {
  final d = difficultyForLevel(level);
  final size = d.gridSize;
  final area = size * size;
  final random = Random(seed);

  var count = d.chocolateCount;
  final cap = (area * 0.8).floor();
  final gap = (3 * count + 4 <= cap) ? 3 : 2;
  while (2 * count + 4 > cap && count > 3) {
    count--;
  }
  final budget = min(
    d.treeCount + d.mineCount + d.enemyCount + d.hazardCount,
    (area * 0.30).floor(),
  );

  _Design? best;
  for (var k = 0; k < 8; k++) {
    final route = _buildRoute(size, count, gap, random);
    if (route.isEmpty) continue;
    final idx = _placeChocolates(route, count, size, gap, random);
    if (idx == null) continue;
    final closers = _closeShortcuts(
      size,
      route,
      idx,
      budget,
      Random(random.nextInt(1 << 30)),
    );
    if (best == null || closers.length > best.closers.length) {
      best = _Design(size, route, idx, closers, count);
    }
  }
  return best;
}

// ============================================================================
// 1. ROUTE
// ============================================================================

List<Point> _buildRoute(int size, int count, int gap, Random random) {
  final area = size * size;
  final need = gap * count + 4;
  final base = (area * (0.5 + 0.3 * random.nextDouble())).floor();
  final minLen = min((area * 0.8).floor(), max(need, base));

  for (var attempt = 0; attempt < 2; attempt++) {
    final r = _route(size, minLen, random, 5);
    if (r.isNotEmpty) return r;
  }
  final lo = max(need, (area * 0.5).floor());
  final relaxed = _route(size, lo, random, 5);
  if (relaxed.isNotEmpty) return relaxed;
  return _route(size, lo, random, 7);
}

/// Self-avoiding path (0,0) -> (size-1,size-1) of at least [minLen] cells.
/// May make a single 1-cell jog but never two in a row (that is a staircase).
List<Point> _route(int size, int minLen, Random random, int maxRun) {
  final end = Point(size - 1, size - 1);
  final path = <Point>[];
  final visited = List<bool>.filled(size * size, false);
  final maxSteps = size * size * 300;
  var steps = 0;
  var found = false;

  bool hasFreeNeighbor(Point p, Point parent) {
    for (final d in _dirs) {
      final nx = p.x + d.x;
      final ny = p.y + d.y;
      if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
      if (nx == parent.x && ny == parent.y) continue;
      if (!visited[nx * size + ny]) return true;
    }
    return false;
  }

  // run = straight run being walked, prevRun = the run before the last turn.
  void dfs(Point cur, int run, Point? prevDir, int prevRun) {
    if (found || steps > maxSteps) return;
    steps++;
    path.add(cur);
    visited[cur.x * size + cur.y] = true;

    if (cur == end && path.length >= minLen) {
      found = true;
      return;
    }

    final dirs = List<Point>.from(_dirs)..shuffle(random);
    for (final d in dirs) {
      final nx = cur.x + d.x;
      final ny = cur.y + d.y;
      if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
      if (visited[nx * size + ny]) continue;
      final next = Point(nx, ny);
      if (next == end && path.length + 1 < minLen) continue;

      final turning = prevDir != null && d != prevDir;
      if (turning && run == 1 && prevRun == 1) continue;
      final nextRun = (prevDir != null && d == prevDir) ? run + 1 : 1;
      if (nextRun > maxRun) continue;
      if (next != end && !hasFreeNeighbor(next, cur)) continue;

      dfs(next, nextRun, d, turning ? run : prevRun);
      if (found) return;
    }

    path.removeLast();
    visited[cur.x * size + cur.y] = false;
  }

  dfs(const Point(0, 0), 0, null, 99);
  return found ? List<Point>.of(path) : <Point>[];
}

// ============================================================================
// 2. CHOCOLATES
// ============================================================================

/// [count] route indices, spread evenly along the route (jittered), at least
/// [gap] route cells apart and never touching, best of 80 samples.
List<int>? _placeChocolates(
  List<Point> route,
  int count,
  int size,
  int gap,
  Random random,
) {
  final spine = Uint8List(size * size);
  for (final p in route) {
    spine[p.x * size + p.y] = 1;
  }

  List<int>? best;
  var bestScore = double.negativeInfinity;
  for (var t = 0; t < 80; t++) {
    final idx = _stratified(route.length, count, random, gap);
    if (idx == null) continue;
    final s = _scoreChocolates(route, idx, size, spine);
    if (s > bestScore) {
      bestScore = s;
      best = idx;
    }
  }
  return best;
}

List<int>? _stratified(int length, int count, Random random, int gap) {
  const lo = 2;
  final hi = length - 3;
  if (hi < lo) return null;
  final span = (hi - lo + 1) / count;
  if (span < gap) return null;

  final result = <int>[];
  for (var k = 0; k < count; k++) {
    final centre =
        lo + (k + 0.5) * span + (random.nextDouble() * 0.6 - 0.3) * span;
    var i = min(hi, max(lo, centre.round()));
    if (result.isNotEmpty && i - result.last < gap) i = result.last + gap;
    if (i > hi) return null;
    result.add(i);
  }
  return result;
}

int _regionId(int x, int y, int size) {
  final half = size / 2.0;
  return (x / half).floor() * 2 + (y / half).floor();
}

int _turnsInWindow(List<Point> path, int i) {
  final lo = max(1, i - 3);
  final hi = min(path.length - 2, i + 3);
  var turns = 0;
  for (var k = lo; k <= hi; k++) {
    final ax = path[k].x - path[k - 1].x;
    final ay = path[k].y - path[k - 1].y;
    final bx = path[k + 1].x - path[k].x;
    final by = path[k + 1].y - path[k].y;
    if (ax != bx || ay != by) turns++;
  }
  return turns;
}

double _scoreChocolates(
  List<Point> route,
  List<int> idx,
  int size,
  Uint8List spine,
) {
  final n = idx.length;
  final pts = [for (final i in idx) route[i]];

  var pairMin = 99;
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      pairMin = min(pairMin, _man(pts[i], pts[j]));
    }
  }
  if (pairMin < 2) return double.negativeInfinity; // never touching

  var consMin = 99;
  var consSum = 0;
  for (var i = 0; i < n - 1; i++) {
    final d = _man(pts[i], pts[i + 1]);
    consMin = min(consMin, d);
    consSum += d;
  }
  final consMean = consSum / (n - 1);

  // Three chocolates marching along one diagonal = a chocolate staircase.
  var diagRuns = 0;
  for (var i = 0; i < n - 2; i++) {
    final d1x = pts[i + 1].x - pts[i].x;
    final d1y = pts[i + 1].y - pts[i].y;
    final d2x = pts[i + 2].x - pts[i + 1].x;
    final d2y = pts[i + 2].y - pts[i + 1].y;
    final big = max(max(d1x.abs(), d1y.abs()), max(d2x.abs(), d2y.abs()));
    if (d1x * d2x > 0 && d1y * d2y > 0 && big <= 3) diagRuns++;
  }

  final quad = List<int>.filled(4, 0);
  for (final p in pts) {
    quad[_regionId(p.x, p.y, size) % 4]++;
  }
  final qSpread = quad.reduce(max) - quad.reduce(min);
  final rows = pts.map((p) => p.x).toSet().length / n;
  final cols = pts.map((p) => p.y).toSet().length / n;

  var zigzag = 0;
  for (final i in idx) {
    if (_turnsInWindow(route, i) >= 4) zigzag++;
  }

  // Prefer chocolates that have an off-route neighbour (room for a guard).
  var guardable = 0;
  for (final p in pts) {
    for (var k = 0; k < 4; k++) {
      final nx = p.x + _dx[k];
      final ny = p.y + _dy[k];
      if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
      if (spine[nx * size + ny] == 0) {
        guardable++;
        break;
      }
    }
  }

  return 4.0 * min(pairMin, 4) +
      3.0 * min(consMin, 5) +
      1.2 * consMean -
      4.0 * diagRuns -
      1.5 * qSpread +
      3.0 * (rows + cols) -
      3.0 * zigzag +
      3.0 * guardable / n;
}

// ============================================================================
// 3. PURPOSEFUL OBSTACLES
// ============================================================================
//
// An "alternative" is a way from route cell i to route cell j (j-i >= 2) that
// leaves the route and uses only free off-route cells, where no chocolate lies
// between i and j (skipping a chocolate just loses, so that is not an
// alternative worth closing). Corner-cuts and side loops are alternatives.
// An obstacle is purposeful if taking it away brings an alternative back.

class _Grid {
  final int size;
  final Int32List _stamp;
  final Int32List _dist;
  final Int32List _prev;
  final Int32List _queue;
  int _now = 0;

  _Grid(this.size)
      : _stamp = Int32List(size * size),
        _dist = Int32List(size * size),
        _prev = Int32List(size * size),
        _queue = Int32List(size * size);

  /// Steps from route cell [a] to route cell [b] through off-route, unblocked
  /// cells only, or -1 if there is no such alternative.
  int bypassLen(int a, int b, Uint8List spine, Uint8List blocked) {
    _now++;
    var head = 0;
    var tail = 0;
    _stamp[a] = _now;
    _dist[a] = 0;
    _queue[tail++] = a;
    while (head < tail) {
      final c = _queue[head++];
      final x = c ~/ size;
      final y = c % size;
      for (var k = 0; k < 4; k++) {
        final nx = x + _dx[k];
        final ny = y + _dy[k];
        if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
        final n = nx * size + ny;
        if (_stamp[n] == _now || blocked[n] == 1) continue;
        if (n == b) return _dist[c] + 1;
        if (spine[n] == 1) continue;
        _stamp[n] = _now;
        _dist[n] = _dist[c] + 1;
        _queue[tail++] = n;
      }
    }
    return -1;
  }

  /// The cells of one shortest alternative from [a] to [b] (a..b), or empty.
  List<int> bypassPath(int a, int b, Uint8List spine, Uint8List blocked) {
    _now++;
    var head = 0;
    var tail = 0;
    _stamp[a] = _now;
    _prev[a] = -1;
    _queue[tail++] = a;
    while (head < tail) {
      final c = _queue[head++];
      final x = c ~/ size;
      final y = c % size;
      for (var k = 0; k < 4; k++) {
        final nx = x + _dx[k];
        final ny = y + _dy[k];
        if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
        final n = nx * size + ny;
        if (_stamp[n] == _now || blocked[n] == 1) continue;
        if (n == b) {
          final path = <int>[b];
          var cur = c;
          while (cur != -1) {
            path.add(cur);
            cur = _prev[cur];
          }
          return path.reversed.toList();
        }
        if (spine[n] == 1) continue;
        _stamp[n] = _now;
        _prev[n] = c;
        _queue[tail++] = n;
      }
    }
    return <int>[];
  }
}

/// Flattened (i, j) route index pairs a player could legally jump between.
List<int> _legalPairs(int length, List<int> idx) {
  // before[k] = number of chocolates with route index < k
  final isChoc = List<bool>.filled(length, false);
  for (final i in idx) {
    isChoc[i] = true;
  }
  final before = List<int>.filled(length + 1, 0);
  for (var k = 0; k < length; k++) {
    before[k + 1] = before[k] + (isChoc[k] ? 1 : 0);
  }
  final out = <int>[];
  for (var i = 0; i < length - 2; i++) {
    for (var j = i + 2; j < min(length, i + _maxSkip + 1); j++) {
      // chocolates strictly between i and j
      if (before[j] - before[i + 1] > 0) continue;
      out.add(i);
      out.add(j);
    }
  }
  return out;
}

int _countTempting(
  _Grid g,
  List<int> pairs,
  List<int> cellOf,
  Uint8List spine,
  Uint8List blocked,
) {
  var n = 0;
  for (var q = 0; q < pairs.length; q += 2) {
    final i = pairs[q];
    final j = pairs[q + 1];
    final bl = g.bypassLen(cellOf[i], cellOf[j], spine, blocked);
    if (bl > 0 && (j - i) - bl >= _tempt) n++;
  }
  return n;
}

/// Cells to block, most valuable first: repeatedly find the most tempting
/// alternative and block the cell on it that lengthens it the most.
List<int> _closeShortcuts(
  int size,
  List<Point> route,
  List<int> idx,
  int budget,
  Random random,
) {
  final out = <int>[];
  if (budget <= 0) return out;

  final g = _Grid(size);
  final spine = Uint8List(size * size);
  final cellOf = <int>[for (final p in route) p.x * size + p.y];
  for (final c in cellOf) {
    spine[c] = 1;
  }
  final blocked = Uint8List(size * size);
  final pairs = _legalPairs(route.length, idx);

  while (out.length < budget) {
    var bi = -1;
    var bj = -1;
    var bestT = -9999;
    var bestSpan = -1;
    var bestTie = -1.0;
    for (var q = 0; q < pairs.length; q += 2) {
      final i = pairs[q];
      final j = pairs[q + 1];
      final bl = g.bypassLen(cellOf[i], cellOf[j], spine, blocked);
      // bl == 1: the route touches itself here, there is no cell to block.
      if (bl <= 1) continue;
      final t = (j - i) - bl;
      if (t < _tempt) continue;
      final span = j - i;
      final tie = random.nextDouble();
      if (t > bestT ||
          (t == bestT &&
              (span > bestSpan || (span == bestSpan && tie > bestTie)))) {
        bestT = t;
        bestSpan = span;
        bestTie = tie;
        bi = i;
        bj = j;
      }
    }
    if (bi < 0) break;

    final path = g.bypassPath(cellOf[bi], cellOf[bj], spine, blocked);
    var bestCell = -1;
    var bestLen = -1;
    var bestCellTie = -1.0;
    for (var k = 1; k < path.length - 1; k++) {
      final c = path[k];
      if (spine[c] == 1) continue;
      blocked[c] = 1;
      final bl = g.bypassLen(cellOf[bi], cellOf[bj], spine, blocked);
      blocked[c] = 0;
      final len = bl < 0 ? 1000000 : bl;
      final tie = random.nextDouble();
      if (len > bestLen || (len == bestLen && tie > bestCellTie)) {
        bestLen = len;
        bestCellTie = tie;
        bestCell = c;
      }
    }
    if (bestCell < 0) break;
    blocked[bestCell] = 1;
    out.add(bestCell);
  }
  return out;
}

// ============================================================================
// 4. FINISH: give each obstacle its job, delete anything purposeless, verify
// ============================================================================

const int _tree = 0;
const int _mine = 1;
const int _enemy = 2;
const int _hazard = 3;

LevelConfig? _finish(int level, _Design d, bool enableTrees) {
  final diff = difficultyForLevel(level);
  final size = d.size;
  final route = d.route;
  final cells = size * size;
  final cellOf = <int>[for (final p in route) p.x * size + p.y];
  final chocCells = <int>{for (final i in d.idx) cellOf[i]};

  // ---- job per closer: guard a chocolate, else follow the budgets ----------
  var mineLeft = diff.mineCount;
  var enemyLeft = diff.enemyCount;
  var hazardLeft = diff.hazardCount;
  var treeLeft = enableTrees ? diff.treeCount : 0;

  final role = <int, int>{};
  for (final c in d.closers) {
    final x = c ~/ size;
    final y = c % size;
    var nextToChocolate = false;
    for (var k = 0; k < 4; k++) {
      final nx = x + _dx[k];
      final ny = y + _dy[k];
      if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
      if (chocCells.contains(nx * size + ny)) nextToChocolate = true;
    }
    if (nextToChocolate && enemyLeft > 0) {
      role[c] = _enemy;
      enemyLeft--;
    } else if (mineLeft > 0) {
      role[c] = _mine;
      mineLeft--;
    } else if (hazardLeft > 0) {
      role[c] = _hazard;
      hazardLeft--;
    } else if (treeLeft > 0) {
      role[c] = _tree;
      treeLeft--;
    } else if (enemyLeft > 0) {
      role[c] = _enemy;
      enemyLeft--;
    }
    // no budget left for this one: it simply stays open
  }

  // ---- purpose check: drop every obstacle whose removal changes nothing ----
  final g = _Grid(size);
  final spine = Uint8List(cells);
  for (final c in cellOf) {
    spine[c] = 1;
  }
  final blocked = Uint8List(cells);
  for (final c in role.keys) {
    blocked[c] = 1;
  }
  final pairs = _legalPairs(route.length, d.idx);

  var changed = true;
  while (changed && role.isNotEmpty) {
    changed = false;
    final base = _countTempting(g, pairs, cellOf, spine, blocked);
    final cellsNow = role.keys.toList()..sort();
    for (final o in cellsNow) {
      blocked[o] = 0;
      final without = _countTempting(g, pairs, cellOf, spine, blocked);
      blocked[o] = 1;
      if (without <= base) {
        blocked[o] = 0;
        role.remove(o);
        changed = true;
        break;
      }
    }
  }

  // ---- independent safety net: never ship a board that breaks the rules ----
  if (!_isValid(size, route, d.idx, role.keys.toSet())) return null;

  // ---- hidden enemies: every second enemy from level 10 --------------------
  final enemies = <int>[
    for (final e in role.entries)
      if (e.value == _enemy) e.key,
  ]..sort();
  final hidden = <int>{};
  if (level >= 10) {
    for (var i = 1; i < enemies.length; i += 2) {
      hidden.add(enemies[i]);
    }
  }

  String key(int v) => '${v ~/ size},${v % size}';
  Set<String> of(int type) => {
        for (final e in role.entries)
          if (e.value == type) key(e.key),
      };

  final danger = <int>{
    for (final e in role.entries)
      if (e.value != _tree) e.key,
  };

  return LevelConfig(
    level,
    size,
    [
      for (var i = 0; i < d.idx.length; i++)
        Chocolate(i + 1, route[d.idx[i]].x, route[d.idx[i]].y),
    ],
    obstacles: of(_tree),
    mines: of(_mine),
    enemies: of(_enemy),
    hazards: of(_hazard),
    dangerMap: _buildDangerMap(size, danger),
    path: {for (final c in cellOf) key(c)},
    world: sweetWorldForLevel(level),
    hiddenEnemies: hidden.map(key).toSet(),
    detours: <String>{},
    bonusItems: <String>{},
    orderedPath: List<Point>.unmodifiable(route),
    riskBudget: 0, // nothing on the route, so the route costs nothing
  );
}

/// Structural checks on the finished board (does not trust the generator).
bool _isValid(int size, List<Point> route, List<int> idx, Set<int> obstacles) {
  if (route.length < 5) return false;
  if (route.first != const Point(0, 0)) return false;
  if (route.last != Point(size - 1, size - 1)) return false;

  final seen = <int>{};
  for (var i = 0; i < route.length; i++) {
    final p = route[i];
    if (p.x < 0 || p.y < 0 || p.x >= size || p.y >= size) return false;
    final c = p.x * size + p.y;
    if (!seen.add(c)) return false; // revisit
    if (obstacles.contains(c)) return false; // obstacle on the route
    if (i > 0 && _man(route[i - 1], p) != 1) return false; // gap in route
  }
  for (var i = 0; i < idx.length; i++) {
    if (idx[i] < 1 || idx[i] > route.length - 2) return false;
    if (i > 0 && idx[i] <= idx[i - 1]) return false;
  }
  for (final o in obstacles) {
    if (o < 0 || o >= size * size) return false;
  }

  // Everything reachable with every obstacle treated as a wall.
  const start = 0;
  final finish = size * size - 1;
  final visited = Uint8List(size * size);
  final queue = <int>[start];
  visited[start] = 1;
  var head = 0;
  while (head < queue.length) {
    final c = queue[head++];
    final x = c ~/ size;
    final y = c % size;
    for (var k = 0; k < 4; k++) {
      final nx = x + _dx[k];
      final ny = y + _dy[k];
      if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
      final n = nx * size + ny;
      if (visited[n] == 1 || obstacles.contains(n)) continue;
      visited[n] = 1;
      queue.add(n);
    }
  }
  if (visited[finish] == 0) return false;
  for (final i in idx) {
    if (visited[route[i].x * size + route[i].y] == 0) return false;
  }
  return true;
}

List<List<int>> _buildDangerMap(int size, Set<int> danger) {
  final map = List.generate(size, (_) => List.filled(size, 0));
  for (final packed in danger) {
    final cx = packed ~/ size;
    final cy = packed % size;
    for (var x = 0; x < size; x++) {
      for (var y = 0; y < size; y++) {
        final dist = (x - cx).abs() + (y - cy).abs();
        if (dist <= 3) map[x][y] = min(3, map[x][y] + (3 - dist));
      }
    }
  }
  return map;
}

// ============================================================================
// VARIETY: how alike are two routes?
// ============================================================================

/// 0..1, 1 = same route. Compares route edges and also tries the board
/// symmetries that keep start/finish in place, so a mirrored copy counts as
/// the same layout.
double _similarity(List<Point> a, List<Point> b, int size) {
  final eb = _edgeSet(b, size, 0);
  var best = 0.0;
  for (var mode = 0; mode < 4; mode++) {
    final ea = _edgeSet(a, size, mode);
    var inter = 0;
    for (final e in ea) {
      if (eb.contains(e)) inter++;
    }
    final union = ea.length + eb.length - inter;
    if (union > 0) best = max(best, inter / union);
  }
  return best;
}

Set<int> _edgeSet(List<Point> route, int size, int mode) {
  final n = size - 1;
  final cells = size * size;
  int cell(Point p) {
    switch (mode) {
      case 1:
        return p.y * size + p.x;
      case 2:
        return (n - p.x) * size + (n - p.y);
      case 3:
        return (n - p.y) * size + (n - p.x);
      default:
        return p.x * size + p.y;
    }
  }

  final out = <int>{};
  for (var i = 0; i < route.length - 1; i++) {
    final a = cell(route[i]);
    final b = cell(route[i + 1]);
    out.add(a < b ? a * cells + b : b * cells + a);
  }
  return out;
}

// ============================================================================
// SAFE FALLBACK (only if the normal path ever fails; still clear, sized to the
// level - NOT a fixed 3-chocolate board)
// ============================================================================

LevelConfig _safeLevel(int levelNum) {
  final diff = difficultyForLevel(levelNum);
  final size = diff.gridSize;

  // Along the bottom edge, then up the right edge: always a valid route.
  final route = <Point>[
    for (var x = 0; x < size; x++) Point(x, 0),
    for (var y = 1; y < size; y++) Point(size - 1, y),
  ];
  final maxFit = ((route.length - 3 - 2) ~/ 2) + 1;
  final count = max(1, min(diff.chocolateCount, maxFit));
  final idx = <int>[for (var k = 0; k < count; k++) 2 + 2 * k];

  return LevelConfig(
    levelNum,
    size,
    [
      for (var i = 0; i < idx.length; i++)
        Chocolate(i + 1, route[idx[i]].x, route[idx[i]].y),
    ],
    obstacles: <String>{},
    mines: <String>{},
    enemies: <String>{},
    hazards: <String>{},
    dangerMap: List.generate(size, (_) => List.filled(size, 0)),
    path: {for (final p in route) '${p.x},${p.y}'},
    world: sweetWorldForLevel(levelNum),
    orderedPath: List<Point>.unmodifiable(route),
    riskBudget: 0,
  );
}