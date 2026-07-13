import '../models/point.dart';

/// Simple BFS reachability check over an [size] x [size] grid, treating
/// every cell whose "row,col" key is in [blocked] as impassable.
///
/// Used by the procedural level generator to make sure a candidate tree
/// placement never seals off the only route between two consecutive
/// chocolates. Mines/enemies/hazards are *not* passed in here because they
/// cost the player chances/points but never block movement, so they can
/// never make a level unsolvable.
class PathValidator {
  final int size;
  final Set<String> blocked;

  PathValidator(this.size, this.blocked);

  bool isReachable(Point from, Point to) {
    if (from == to) return true;
    final startKey = '${from.x},${from.y}';
    if (blocked.contains(startKey)) return false;

    final visited = <String>{startKey};
    final queue = <Point>[from];
    int head = 0;
    while (head < queue.length) {
      final current = queue[head++];
      if (current == to) return true;
      for (final neighbor in _neighbors(current)) {
        final key = '${neighbor.x},${neighbor.y}';
        if (visited.contains(key) || blocked.contains(key)) continue;
        visited.add(key);
        queue.add(neighbor);
      }
    }
    return false;
  }

  List<Point> _neighbors(Point p) {
    const deltas = [Point(-1, 0), Point(1, 0), Point(0, -1), Point(0, 1)];
    final result = <Point>[];
    for (final d in deltas) {
      final nx = p.x + d.x;
      final ny = p.y + d.y;
      if (nx >= 0 && nx < size && ny >= 0 && ny < size) {
        result.add(Point(nx, ny));
      }
    }
    return result;
  }
}