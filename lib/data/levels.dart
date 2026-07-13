import '../models/level_config.dart';
import 'procedural_level_generator.dart';

/// Simple cache to avoid regenerating the same level multiple times.
final Map<int, LevelConfig> _levelCache = {};

/// Load a specific level on demand (with caching) – now supports up to 50.
Future<LevelConfig> loadLevel(int levelNum) async {
  // Clamp to 1-50
  final clampedLevel = levelNum.clamp(1, 50);
  if (_levelCache.containsKey(clampedLevel)) {
    return _levelCache[clampedLevel]!;
  }
  final level = generateProceduralLevel(clampedLevel);
  _levelCache[clampedLevel] = level;
  return level;
}

/// Pre‑load a level in the background (optional).
Future<void> preloadLevel(int levelNum) async {
  await loadLevel(levelNum);
}

/// For backward compatibility (you can remove if not used).
Future<List<LevelConfig>> loadAllLevels() async {
  final levels = <LevelConfig>[];
  for (int i = 1; i <= 50; i++) {
    levels.add(await loadLevel(i));
  }
  return levels;
}