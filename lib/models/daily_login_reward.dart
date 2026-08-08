// lib/models/daily_login_reward.dart
class DailyLoginReward {
  final String emoji;
  final int coinAmount;
  const DailyLoginReward(this.emoji, this.coinAmount);
}

// The reward cycle (7 days, then repeats)
const List<DailyLoginReward> kDailyLoginRewards = [
  DailyLoginReward('🍫', 5),
  DailyLoginReward('🍬', 10),
  DailyLoginReward('🍭', 15),
  DailyLoginReward('🧁', 20),
  DailyLoginReward('🍩', 25),
  DailyLoginReward('🎂', 30),
  DailyLoginReward('🏆', 50),
];

/// Returns a date string in "YYYY-MM-DD" format
String dateKeyFor(DateTime date) {
  return '${date.year}-${date.month}-${date.day}';
}

/// Returns the reward for a given streak day (1‑based)
DailyLoginReward dailyLoginRewardForStreak(int streak) {
  final index = (streak - 1) % kDailyLoginRewards.length;
  return kDailyLoginRewards[index];
}