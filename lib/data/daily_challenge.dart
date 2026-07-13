import '../models/level_config.dart';
import 'procedural_level_generator.dart';
import 'level_generation_isolate.dart';

/// The same board for every player on a given calendar day: the seed comes
/// purely from the date, so two players opening the app on the same day get
/// an identical, independently-solvable level (useful for comparing scores).
/// Difficulty cycles through the same 6-30 band the campaign uses, so daily
/// boards stay within a fair, familiar range indefinitely.
LevelConfig generateDailyLevel(DateTime date) {
  final dayKey = date.year * 10000 + date.month * 100 + date.day;
  final daysSinceEpoch = date.difference(DateTime(2026, 1, 1)).inDays;
  final virtualLevelNum = 6 + (daysSinceEpoch % 25); // cycles through 6..30 difficulty
  return generateProceduralLevel(virtualLevelNum, seed: dayKey);
}

/// Same as [generateDailyLevel], but off the main isolate — use this from
/// UI code (e.g. tapping "Daily Challenge") so the tap never causes a
/// visible stutter, however long generation takes on the device.
Future<LevelConfig> generateDailyLevelAsync(DateTime date) {
  final dayKey = date.year * 10000 + date.month * 100 + date.day;
  final daysSinceEpoch = date.difference(DateTime(2026, 1, 1)).inDays;
  final virtualLevelNum = 6 + (daysSinceEpoch % 25);
  return generateProceduralLevelAsync(virtualLevelNum, seed: dayKey);
}

/// Stable "yyyy-MM-dd" key for a date, used to track daily-streak state in
/// PlayerProgress without pulling in a date-formatting package.
String dailyKeyFor(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';