import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PlayerProgress {
  // Keep only one counter – this one is already used throughout your app.
  int levelsCompletedCount;

  // Your other fields...
  int totalPoints;
  int unlockedLevel; // 1-based
  Map<int, int> starsPerLevel;
  String selectedChocolateSkin;
  String selectedHat;
  Set<String> purchasedSkins;
  Set<String> purchasedHats;

  int endlessBestStage;
  int endlessBestScore;

  String? lastDailyDate;
  int dailyStreak;
  int bestDailyStreak;

  String? lastLoginRewardDate;
  int loginStreak;
  int bestLoginStreak;

  bool tapAssistAlwaysOn;

  // Constructor – no need to change anything, the default value is already 0.
  PlayerProgress({
    this.totalPoints = 0,
    this.unlockedLevel = 1,
    Map<int, int>? starsPerLevel,
    this.selectedChocolateSkin = 'dark',
    this.selectedHat = 'none',
    Set<String>? purchasedSkins,
    Set<String>? purchasedHats,
    this.endlessBestStage = 0,
    this.endlessBestScore = 0,
    this.lastDailyDate,
    this.dailyStreak = 0,
    this.bestDailyStreak = 0,
    this.levelsCompletedCount = 0,   // already here – good!
    this.lastLoginRewardDate,
    this.loginStreak = 0,
    this.bestLoginStreak = 0,
    this.tapAssistAlwaysOn = false,
  }) : starsPerLevel = starsPerLevel ?? {},
       purchasedSkins = purchasedSkins ?? {'dark'},
       purchasedHats = purchasedHats ?? {'none'};

  // toJson / fromJson / load / save remain unchanged
  Map<String, dynamic> toJson() => {
        'totalPoints': totalPoints,
        'unlockedLevel': unlockedLevel,
        'starsPerLevel': starsPerLevel.map((key, value) => MapEntry(key.toString(), value)),
        'selectedChocolateSkin': selectedChocolateSkin,
        'selectedHat': selectedHat,
        'purchasedSkins': purchasedSkins.toList(),
        'purchasedHats': purchasedHats.toList(),
        'endlessBestStage': endlessBestStage,
        'endlessBestScore': endlessBestScore,
        'lastDailyDate': lastDailyDate,
        'dailyStreak': dailyStreak,
        'bestDailyStreak': bestDailyStreak,
        'levelsCompletedCount': levelsCompletedCount,
        'lastLoginRewardDate': lastLoginRewardDate,
        'loginStreak': loginStreak,
        'bestLoginStreak': bestLoginStreak,
        'tapAssistAlwaysOn': tapAssistAlwaysOn,
      };

  factory PlayerProgress.fromJson(Map<String, dynamic> json) {
    final starsMap = <int, int>{};
    if (json['starsPerLevel'] != null) {
      (json['starsPerLevel'] as Map<String, dynamic>).forEach((key, value) {
        starsMap[int.parse(key)] = value as int;
      });
    }
    final skins = Set<String>.from(json['purchasedSkins'] as List? ?? ['dark']);
    final hats = Set<String>.from(json['purchasedHats'] as List? ?? ['none']);

    return PlayerProgress(
      totalPoints: json['totalPoints'] ?? 0,
      unlockedLevel: json['unlockedLevel'] ?? 1,
      starsPerLevel: starsMap,
      selectedChocolateSkin: json['selectedChocolateSkin'] ?? 'dark',
      selectedHat: json['selectedHat'] ?? 'none',
      purchasedSkins: skins,
      purchasedHats: hats,
      endlessBestStage: json['endlessBestStage'] ?? 0,
      endlessBestScore: json['endlessBestScore'] ?? 0,
      lastDailyDate: json['lastDailyDate'],
      dailyStreak: json['dailyStreak'] ?? 0,
      bestDailyStreak: json['bestDailyStreak'] ?? 0,
      levelsCompletedCount: json['levelsCompletedCount'] ?? 0,
      lastLoginRewardDate: json['lastLoginRewardDate'],
      loginStreak: json['loginStreak'] ?? 0,
      bestLoginStreak: json['bestLoginStreak'] ?? 0,
      tapAssistAlwaysOn: json['tapAssistAlwaysOn'] ?? false,
    );
  }

  static Future<PlayerProgress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('progress');
    if (jsonString != null) {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return PlayerProgress.fromJson(map);
    }
    return PlayerProgress();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(toJson());
    await prefs.setString('progress', jsonString);
  }
}