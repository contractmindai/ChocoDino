// lib/pathfinding/pathfinding.dart
//
// Weighted A* pathfinding system – drop-in replacement for the old BFS
// PathValidator.  Supports hazard costs, conditional blockers, connected
// components for O(1) no-path detection, tie-breaking, and node limits.
//
// Optimized with integer keys and binary heap for performance.

import 'dart:math';
import '../models/point.dart';

// ============================================================================
// CONFIGURATION
// ============================================================================

class PathfindingConfig {
  final int maxNodes;
  final double heuristicScale;
  final bool useCrossProductTieBreak;
  final double turnPenalty;
  final bool allowDiagonal;
  final bool preventCornerCutting;

  const PathfindingConfig({
    this.maxNodes = 5000,
    this.heuristicScale = 0.001,
    this.useCrossProductTieBreak = true,
    this.turnPenalty = 0.0,
    this.allowDiagonal = false,
    this.preventCornerCutting = true,
  });

  const PathfindingConfig.strict()
      : maxNodes = 0,
        heuristicScale = 0.0,
        useCrossProductTieBreak = false,
        turnPenalty = 0.0,
        allowDiagonal = false,
        preventCornerCutting = true;

  const PathfindingConfig.fast()
      : maxNodes = 2000,
        heuristicScale = 0.001,
        useCrossProductTieBreak = true,
        turnPenalty = 0.2,
        allowDiagonal = false,
        preventCornerCutting = true;
}

// ============================================================================
// PATH RESULT
// ============================================================================

enum PathStatus {
  found,
  noPathExists,
  nodeLimitExceeded,
  invalidEndpoint,
}

class PathResult {
  final List<Point> path;
  final double totalCost;
  final PathStatus status;
  final int nodesExplored;

  const PathResult({
    required this.path,
    required this.totalCost,
    required this.status,
    required this.nodesExplored,
  });

  bool get isSuccess => status == PathStatus.found;
  bool get pathFound => path.isNotEmpty && isSuccess;

  static PathResult noPath(int nodes) => PathResult(
        path: const [],
        totalCost: double.infinity,
        status: PathStatus.noPathExists,
        nodesExplored: nodes,
      );

  static PathResult nodeLimit(int nodes) => PathResult(
        path: const [],
        totalCost: double.infinity,
        status: PathStatus.nodeLimitExceeded,
        nodesExplored: nodes,
      );

  static const invalid = PathResult(
    path: [],
    totalCost: double.infinity,
    status: PathStatus.invalidEndpoint,
    nodesExplored: 0,
  );
}

// ============================================================================
// PATH VALIDATION RESULT
// ============================================================================

class PathValidationResult {
  final bool isValid;
  final String? reason;
  final int invalidStepIndex;

  const PathValidationResult({
    required this.isValid,
    this.reason,
    this.invalidStepIndex = -1,
  });

  static const valid = PathValidationResult(isValid: true);

  static PathValidationResult invalid(String reason, int stepIndex) =>
      PathValidationResult(
        isValid: false,
        reason: reason,
        invalidStepIndex: stepIndex,
      );
}

// ============================================================================
// COORDINATE PACKING (for internal use)
// ============================================================================

int _pack(int x, int y) => (x << 4) | y;
int _unpackX(int v) => v >> 4;
int _unpackY(int v) => v & 0xF;

// ============================================================================
// GRID PATH CONTEXT
// ============================================================================

class GridPathContext {
  final int size;
  final Set<String> obstacles;
  final Set<String> mines;
  final Set<String> enemies;
  final Set<String> hazards;
  final Set<String> hiddenEnemies;
  final Set<String> revealedHiddenEnemies;
  final Set<String> bonusItems;
  final List<List<int>>? dangerMap;

  final bool hasMineShield;
  final bool canSeeHiddenEnemies;
  final bool canCrossHazards;
  final bool hasBonusProtection;
  final int version;

  const GridPathContext({
    required this.size,
    required this.obstacles,
    this.mines = const {},
    this.enemies = const {},
    this.hazards = const {},
    this.hiddenEnemies = const {},
    this.revealedHiddenEnemies = const {},
    this.bonusItems = const {},
    this.dangerMap,
    this.hasMineShield = false,
    this.canSeeHiddenEnemies = false,
    this.canCrossHazards = true,
    this.hasBonusProtection = false,
    this.version = 0,
  });

  factory GridPathContext.fromRawSets({
    required int size,
    required Set<String> obstacles,
    Set<String> mines = const {},
    Set<String> enemies = const {},
    Set<String> hazards = const {},
    Set<String> hiddenEnemies = const {},
    Set<String> revealedHiddenEnemies = const {},
    Set<String> bonusItems = const {},
    List<List<int>>? dangerMap,
    bool hasMineShield = false,
    bool canSeeHiddenEnemies = false,
    bool canCrossHazards = true,
    bool hasBonusProtection = false,
    int version = 0,
  }) {
    return GridPathContext(
      size: size,
      obstacles: obstacles,
      mines: mines,
      enemies: enemies,
      hazards: hazards,
      hiddenEnemies: hiddenEnemies,
      revealedHiddenEnemies: revealedHiddenEnemies,
      bonusItems: bonusItems,
      dangerMap: dangerMap,
      hasMineShield: hasMineShield,
      canSeeHiddenEnemies: canSeeHiddenEnemies,
      canCrossHazards: canCrossHazards,
      hasBonusProtection: hasBonusProtection,
      version: version,
    );
  }

  static String _key(Point p) => '${p.x},${p.y}';
  static String _keyXY(int x, int y) => '$x,$y';

  bool inBounds(int x, int y) =>
      x >= 0 && x < size && y >= 0 && y < size;

  bool inBoundsP(Point p) => inBounds(p.x, p.y);

  bool isHardBlocked(Point p) {
    final k = _key(p);
    if (obstacles.contains(k)) return true;
    if (revealedHiddenEnemies.contains(k)) return true;
    if (canSeeHiddenEnemies && hiddenEnemies.contains(k)) return true;
    if (!canCrossHazards && hazards.contains(k)) return true;
    return false;
  }

  bool isPassable(Point p) => !isHardBlocked(p);

  double movementCost(Point p) {
    if (isHardBlocked(p)) return double.infinity;

    double cost = 1.0;
    final k = _key(p);

    if (mines.contains(k)) {
      cost += hasBonusProtection
          ? 2.0
          : (hasMineShield ? 8.0 : 100.0);
    }

    if (hazards.contains(k)) {
      cost += 20.0;
    }

    if (enemies.contains(k)) {
      cost += 35.0;
    }

    final danger = dangerMap;
    if (danger != null) {
      final d = danger[p.x][p.y];
      if (d > 0) cost += d * 0.75;
    }

    return cost;
  }
}

// ============================================================================
// CONNECTED COMPONENTS
// ============================================================================

class ConnectedComponents {
  final int _size;
  final List<List<int>> _componentId;
  int _count = 0;

  ConnectedComponents(GridPathContext ctx)
      : _size = ctx.size,
        _componentId = [] {
    for (int x = 0; x < _size; x++) {
      _componentId.add(List.filled(_size, -1));
    }

    const dirs = [Point(-1, 0), Point(1, 0), Point(0, -1), Point(0, 1)];

    for (int sx = 0; sx < _size; sx++) {
      for (int sy = 0; sy < _size; sy++) {
        final start = Point(sx, sy);
        if (_componentId[sx][sy] != -1) continue;
        if (ctx.isHardBlocked(start)) continue;

        _componentId[sx][sy] = _count;
        final queue = [start];
        int head = 0;
        while (head < queue.length) {
          final cur = queue[head++];
          for (final d in dirs) {
            final nx = cur.x + d.x;
            final ny = cur.y + d.y;
            if (nx < 0 || nx >= _size || ny < 0 || ny >= _size) continue;
            if (_componentId[nx][ny] != -1) continue;
            final np = Point(nx, ny);
            if (ctx.isHardBlocked(np)) continue;
            _componentId[nx][ny] = _count;
            queue.add(np);
          }
        }
        _count++;
      }
    }
  }

  int get count => _count;

  int componentOf(int x, int y) => _componentId[x][y];
  int componentOfP(Point p) => _componentId[p.x][p.y];

  bool canReach(Point from, Point to) {
    if (!(_size > from.x && from.x >= 0 && _size > from.y && from.y >= 0))
      return false;
    if (!(_size > to.x && to.x >= 0 && _size > to.y && to.y >= 0))
      return false;
    final fc = _componentId[from.x][from.y];
    final tc = _componentId[to.x][to.y];
    if (fc == -1 || tc == -1) return false;
    return fc == tc;
  }
}

// ============================================================================
// BINARY HEAP FOR A*
// ============================================================================

class _HeapNode {
  final Point point;
  final double f;
  final double g;
  final double h;
  final int order;

  _HeapNode(this.point, this.f, this.g, this.h, this.order);
}

class _MinHeap {
  final List<_HeapNode> _heap = [];

  int get length => _heap.length;
  bool get isEmpty => _heap.isEmpty;

  void add(_HeapNode node) {
    _heap.add(node);
    _siftUp(_heap.length - 1);
  }

  _HeapNode removeMin() {
    final min = _heap.first;
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = last;
      _siftDown(0);
    }
    return min;
  }

  void _siftUp(int index) {
    while (index > 0) {
      final parent = (index - 1) >> 1;
      if (_heap[index].f < _heap[parent].f) {
        _swap(index, parent);
        index = parent;
      } else {
        break;
      }
    }
  }

  void _siftDown(int index) {
    final size = _heap.length;
    while (true) {
      final left = (index << 1) + 1;
      final right = left + 1;
      int smallest = index;

      if (left < size && _heap[left].f < _heap[smallest].f) smallest = left;
      if (right < size && _heap[right].f < _heap[smallest].f) smallest = right;
      if (smallest == index) break;

      _swap(index, smallest);
      index = smallest;
    }
  }

  void _swap(int a, int b) {
    final tmp = _heap[a];
    _heap[a] = _heap[b];
    _heap[b] = tmp;
  }
}

// ============================================================================
// GRID PATHFINDER
// ============================================================================

class GridPathfinder {
  GridPathfinder._();

  static const _dir4 = [
    Point(-1, 0), Point(1, 0), Point(0, -1), Point(0, 1),
  ];
  static const _dir8 = [
    Point(-1, 0), Point(1, 0), Point(0, -1), Point(0, 1),
    Point(-1, -1), Point(-1, 1), Point(1, -1), Point(1, 1),
  ];

  static const _diagCost = 1.41421356;

  static PathResult findPath(
    Point start,
    Point goal,
    GridPathContext ctx, {
    PathfindingConfig config = const PathfindingConfig(),
    ConnectedComponents? components,
  }) {
    if (!ctx.inBoundsP(start) || !ctx.inBoundsP(goal)) {
      return PathResult.invalid;
    }
    if (ctx.isHardBlocked(start) || ctx.isHardBlocked(goal)) {
      return PathResult.invalid;
    }
    if (start == goal) {
      return PathResult(
          path: [start], totalCost: 0, status: PathStatus.found, nodesExplored: 1);
    }

    if (components != null && !components.canReach(start, goal)) {
      return PathResult.noPath(0);
    }

    final dirs = config.allowDiagonal ? _dir8 : _dir4;
    final openHeap = _MinHeap();
    final gScore = <int, double>{};
    final cameFrom = <int, Point>{};
    final closed = <int>{};

    final startKey = _pack(start.x, start.y);
    final startH = _heuristic(start, goal, start, config);
    gScore[startKey] = 0.0;
    openHeap.add(_HeapNode(start, startH, 0.0, startH, 0));

    int nodesExplored = 0;
    int insertionOrder = 1;

    while (!openHeap.isEmpty) {
      final current = openHeap.removeMin();
      final curKey = _pack(current.point.x, current.point.y);

      if (closed.contains(curKey)) continue;
      closed.add(curKey);
      nodesExplored++;

      if (current.point == goal) {
        final path = _reconstructPath(cameFrom, current.point, start);
        return PathResult(
          path: path,
          totalCost: gScore[curKey]!,
          status: PathStatus.found,
          nodesExplored: nodesExplored,
        );
      }

      if (config.maxNodes > 0 && nodesExplored >= config.maxNodes) {
        return PathResult.nodeLimit(nodesExplored);
      }

      final curG = current.g;
      final parent = cameFrom[curKey];

      for (final d in dirs) {
        final nx = current.point.x + d.x;
        final ny = current.point.y + d.y;
        if (!ctx.inBounds(nx, ny)) continue;

        final neighbor = Point(nx, ny);
        final nKey = _pack(nx, ny);
        if (closed.contains(nKey)) continue;

        if (config.preventCornerCutting && d.x != 0 && d.y != 0) {
          final h1 = ctx.isHardBlocked(Point(current.point.x + d.x, current.point.y));
          final h2 = ctx.isHardBlocked(Point(current.point.x, current.point.y + d.y));
          if (h1 || h2) continue;
        }

        final stepCost = ctx.movementCost(neighbor);
        if (stepCost == double.infinity) continue;

        final moveCost = (d.x != 0 && d.y != 0) ? stepCost * _diagCost : stepCost;

        double turnPen = 0.0;
        if (config.turnPenalty > 0 && parent != null) {
          final prevDx = current.point.x - parent.x;
          final prevDy = current.point.y - parent.y;
          if (prevDx != d.x || prevDy != d.y) turnPen = config.turnPenalty;
        }

        final tentativeG = curG + moveCost + turnPen;
        final existingG = gScore[nKey];

        if (existingG == null || tentativeG < existingG) {
          gScore[nKey] = tentativeG;
          cameFrom[nKey] = current.point;

          final h = _heuristic(neighbor, goal, start, config);
          openHeap.add(_HeapNode(neighbor, tentativeG + h, tentativeG, h, insertionOrder++));
        }
      }
    }

    return PathResult.noPath(nodesExplored);
  }

  static (Map<String, double> costs, Map<String, Point> cameFrom)
      dijkstraAll(
    Point start,
    GridPathContext ctx, {
    int maxNodes = 10000,
  }) {
    if (!ctx.inBoundsP(start) || ctx.isHardBlocked(start)) {
      return ({}, {});
    }

    final dirs = _dir4;
    final openSet = <_DijkstraNode>[];
    final costs = <String, double>{};
    final cameFrom = <String, Point>{};
    final closed = <String>{};

    final startKey = '${start.x},${start.y}';
    costs[startKey] = 0.0;
    openSet.add(_DijkstraNode(start, 0.0, 0));
    int explored = 0;

    while (openSet.isNotEmpty) {
      int minIdx = 0;
      for (int i = 1; i < openSet.length; i++) {
        if (openSet[i].cost < openSet[minIdx].cost) minIdx = i;
      }
      final current = openSet.removeAt(minIdx);
      final curKey = '${current.point.x},${current.point.y}';

      if (closed.contains(curKey)) continue;
      closed.add(curKey);
      explored++;

      if (maxNodes > 0 && explored >= maxNodes) break;

      final curCost = current.cost;

      for (final d in dirs) {
        final nx = current.point.x + d.x;
        final ny = current.point.y + d.y;
        if (!ctx.inBounds(nx, ny)) continue;

        final neighbor = Point(nx, ny);
        final nKey = '$nx,$ny';
        if (closed.contains(nKey)) continue;

        final stepCost = ctx.movementCost(neighbor);
        if (stepCost == double.infinity) continue;

        final newCost = curCost + stepCost;
        final existing = costs[nKey];

        if (existing == null || newCost < existing) {
          costs[nKey] = newCost;
          cameFrom[nKey] = current.point;
          openSet.add(_DijkstraNode(neighbor, newCost, explored));
        }
      }
    }

    return (costs, cameFrom);
  }

  static double _heuristic(
    Point node,
    Point goal,
    Point start,
    PathfindingConfig config,
  ) {
    final dx = (node.x - goal.x).abs();
    final dy = (node.y - goal.y).abs();

    double h;
    if (config.allowDiagonal) {
      const d = 1.0;
      const d2 = _diagCost;
      h = d * (dx + dy) + (d2 - 2 * d) * min(dx, dy);
    } else {
      h = (dx + dy).toDouble();
    }

    if (config.heuristicScale > 0) {
      h *= (1.0 + config.heuristicScale);
    }

    if (config.useCrossProductTieBreak) {
      final dx1 = node.x - goal.x;
      final dy1 = node.y - goal.y;
      final dx2 = start.x - goal.x;
      final dy2 = start.y - goal.y;
      final cross = (dx1 * dy2 - dx2 * dy1).abs();
      h += cross * 0.001;
    }

    return h;
  }

  static List<Point> _reconstructPath(
    Map<int, Point> cameFrom,
    Point current,
    Point start,
  ) {
    final path = [current];
    while (current != start) {
      final key = _pack(current.x, current.y);
      final prev = cameFrom[key];
      if (prev == null) break;
      path.add(prev);
      current = prev;
    }
    return path.reversed.toList();
  }

  static PathValidationResult validatePlayerPath(
    List<Point> path,
    GridPathContext ctx, {
    bool noRevisits = false,
    bool hiddenEnemiesBlock = true,
  }) {
    if (path.isEmpty) {
      return PathValidationResult.invalid('Path is empty', 0);
    }

    if (ctx.isHardBlocked(path.first)) {
      return PathValidationResult.invalid('Start cell is blocked', 0);
    }

    final visited = <String>{};

    for (int i = 0; i < path.length; i++) {
      final p = path[i];
      final key = '${p.x},${p.y}';

      if (!ctx.inBoundsP(p)) {
        return PathValidationResult.invalid('Out of bounds', i);
      }

      if (ctx.isHardBlocked(p)) {
        return PathValidationResult.invalid('Path crosses obstacle', i);
      }

      if (hiddenEnemiesBlock) {
        final k = '${p.x},${p.y}';
        if (ctx.hiddenEnemies.contains(k) &&
            !ctx.revealedHiddenEnemies.contains(k)) {
          return PathValidationResult.invalid(
              'Path crosses hidden enemy', i);
        }
      }

      if (noRevisits && visited.contains(key)) {
        return PathValidationResult.invalid('Revisits cell', i);
      }
      visited.add(key);

      if (i > 0) {
        final prev = path[i - 1];
        final dx = (p.x - prev.x).abs();
        final dy = (p.y - prev.y).abs();

        if (dx + dy != 1) {
          return PathValidationResult.invalid('Non-adjacent step', i);
        }
      }
    }

    return PathValidationResult.valid;
  }

  static bool isReachable(
    Point from,
    Point to,
    GridPathContext ctx, {
    ConnectedComponents? components,
  }) {
    if (from == to) return true;
    if (!ctx.inBoundsP(from) || !ctx.inBoundsP(to)) return false;
    if (ctx.isHardBlocked(from) || ctx.isHardBlocked(to)) return false;

    if (components != null) {
      return components.canReach(from, to);
    }

    final result = findPath(from, to, ctx, config: const PathfindingConfig(maxNodes: 0));
    return result.isSuccess;
  }
}

// ============================================================================
// INTERNAL NODE CLASSES
// ============================================================================

class _DijkstraNode {
  final Point point;
  final double cost;
  final int insertionOrder;

  _DijkstraNode(this.point, this.cost, this.insertionOrder);
}

// ============================================================================
// LEGACY COMPATIBILITY
// ============================================================================

class PathValidator {
  final int size;
  final Set<String> blocked;

  final GridPathContext _ctx;
  late final ConnectedComponents _components = ConnectedComponents(_ctx);

  PathValidator(this.size, this.blocked)
      : _ctx = GridPathContext(size: size, obstacles: blocked);

  bool isReachable(Point from, Point to) {
    if (from == to) return true;
    if (!ctx.inBoundsP(from) || !ctx.inBoundsP(to)) return false;
    if (ctx.isHardBlocked(from) || ctx.isHardBlocked(to)) return false;
    return _components.canReach(from, to);
  }

  GridPathContext get ctx => _ctx;
  ConnectedComponents get components => _components;
}