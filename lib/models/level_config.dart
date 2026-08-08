import 'chocolate.dart';
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
  });

  int get levelNumber => levelNum;
}