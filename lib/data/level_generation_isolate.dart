import '../models/level_config.dart';
import 'procedural_level_generator.dart';

// NOTE: this used to run generation on a background isolate via
// `compute()`. That's been removed — see the comment on
// generateProceduralLevelAsync below for why.
//
// The `LevelGenerationRequest` plain-data wrapper and top-level entry
// point are no longer needed (they only existed because `compute()`
// requires a top-level function taking a single argument), but the
// public `generateProceduralLevelAsync` signature is unchanged, so
// `daily_challenge.dart` and `endless_generator.dart` need no edits.

/// Runs procedural level generation without blocking the current frame.
///
/// This *used* to run on a background isolate via `compute()`, but that
/// spawns a brand-new OS thread on every call — on Windows this can hit
/// a known Dart VM bug ("Could not start thread DartWorker") when calls
/// overlap (e.g. prefetching more than one level at a time), and it's
/// unnecessary overhead regardless: generation for boards up to 10x10,
/// even with the retry loop, finishes in low single-digit milliseconds —
/// far below anything a player would perceive as a stutter.
///
/// `Future(() => ...)` schedules the (synchronous, CPU-bound) work as a
/// new event-loop turn rather than running it inline, so the current
/// frame gets a chance to paint first. If you ever need this to run
/// truly in parallel with other CPU-bound work again, reintroduce
/// `compute()` here, but make sure callers never have more than one
/// in-flight call at a time.
Future<LevelConfig> generateProceduralLevelAsync(
  int levelNum, {
  int? seed,
  int candidateCount = 5,
}) {
  return Future(() => generateProceduralLevel(
        levelNum,
        seed: seed,
        candidateCount: candidateCount,
      ));
}