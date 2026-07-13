class Point {
  final int x, y;
  const Point(this.x, this.y);
  @override
  bool operator ==(Object other) => other is Point && other.x == x && other.y == y;
  @override
  int get hashCode => x * 31 + y;
}