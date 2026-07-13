import 'package:flutter/foundation.dart';
import '../models/level_config.dart';
import 'procedural_level_generator.dart';

/// Plain-data request for [compute] — must contain only primitive fields
/// since it gets copied across the isolate boundary.
class LevelGenerationRequest {
  final int levelNum;
  final int? seed;
  final int candidateCount;
  const LevelGenerationRequest(this.levelNum, this.seed, this.candidateCount);
}

/// Top-level entry point (compute() requires a top-level or static
/// function, not a closure/instance method).
LevelConfig _generateLevelEntryPoint(LevelGenerationRequest request) {
  return generateProceduralLevel(
    request.levelNum,
    seed: request.seed,
    candidateCount: request.candidateCount,
  );
}

/// Runs procedural level generation on a background isolate so it never
/// blocks a UI frame.
Future<LevelConfig> generateProceduralLevelAsync(
  int levelNum, {
  int? seed,
  int candidateCount = 5,
}) {
  return compute(
    _generateLevelEntryPoint,
    LevelGenerationRequest(levelNum, seed, candidateCount),
  );
}