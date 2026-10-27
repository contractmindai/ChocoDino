import 'chocolate.dart';
import 'point.dart';
import 'sweet_world.dart';

class LevelConfig {
  final int levelNum;
  final int gridSize;
  final List<Chocolate> chocolates;
  final Set<String> obstacles;
  final Set<String> mines;
  final Set<String> enemies;
  final Set<String> hazards;
  final List<List<int>> dangerMap;
  final Set<String> path;
  final SweetWorld world;
  final Set<String> hiddenEnemies;
  final Set<String> detours;
  final Set<String> bonusItems;

  /// The intended solution in walking order, (0,0) -> finish. Feeds
  /// PatrolEnemy(route: ...) and hint systems. (`path` is the same cells as
  /// an unordered set.)
  final List<Point> orderedPath;

  /// Damage points a valid run may take (see RiskModel in puzzle_solver).
  /// 0 = no damage allowed.
  final int riskBudget;

  LevelConfig(
    this.levelNum,
    this.gridSize,
    this.chocolates, {
    required this.obstacles,
    required this.mines,
    required this.enemies,
    required this.hazards,
    required this.dangerMap,
    required this.path,
    required this.world,
    this.hiddenEnemies = const {},
    this.detours = const {},
    this.bonusItems = const {},
    this.orderedPath = const [],
    this.riskBudget = 0,
  });

  int get levelNumber => levelNum;
}