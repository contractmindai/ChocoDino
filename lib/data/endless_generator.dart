import '../models/level_config.dart';
import 'procedural_level_generator.dart';
import 'level_generation_isolate.dart';

LevelConfig generateEndlessLevel(int stage, int runSeed) {
  final virtualLevelNum = 5 + stage;
  final seed = runSeed * 100003 + stage;
  return generateProceduralLevel(virtualLevelNum, seed: seed, candidateCount: 6);
}

Future<LevelConfig> generateEndlessLevelAsync(int stage, int runSeed) {
  final virtualLevelNum = 5 + stage;
  final seed = runSeed * 100003 + stage;
  return generateProceduralLevelAsync(
    virtualLevelNum,
    seed: seed,
    candidateCount: 6,
  );
}