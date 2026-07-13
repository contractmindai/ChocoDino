import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PlayerProgress {
  int totalPoints;
  int unlockedLevel; // 1-based
  Map<int, int> starsPerLevel;
  String selectedChocolateSkin;
  String selectedHat;
  Set<String> purchasedSkins;
  Set<String> purchasedHats;

  // Endless mode
  int endlessBestStage;
  int endlessBestScore;

  // Daily challenge
  String? lastDailyDate; // "yyyy-MM-dd" of the last completed daily
  int dailyStreak;
  int bestDailyStreak;

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
  }) : starsPerLevel = starsPerLevel ?? {},
       purchasedSkins = purchasedSkins ?? {'dark'},
       purchasedHats = purchasedHats ?? {'none'};

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
      };

  factory PlayerProgress.fromJson(Map<String, dynamic> json) {
    // stars conversion
    final starsMap = <int, int>{};
    if (json['starsPerLevel'] != null) {
      (json['starsPerLevel'] as Map<String, dynamic>).forEach((key, value) {
        starsMap[int.parse(key)] = value as int;
      });
    }
    // purchased sets
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