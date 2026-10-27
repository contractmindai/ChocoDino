// lib/models/player_progress.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PlayerProgress {
  String? dinoName;
  int levelsCompletedCount;
  int totalPoints;
  int unlockedLevel;
  Map<int, int> starsPerLevel;
  String selectedChocolateSkin;
  String selectedHat;
  Set<String> purchasedSkins;
  Set<String> purchasedHats;

  // NEW: names of worlds the player has unlocked ('Jungle' always included).
  Set<String> purchasedWorlds;

  int endlessBestStage;
  int endlessBestScore;

  String? lastDailyDate;
  int dailyStreak;
  int bestDailyStreak;

  String? lastLoginRewardDate;
  int loginStreak;
  int bestLoginStreak;

  bool tapAssistAlwaysOn;

  // World + notification fields (additive, backward-safe)
  String selectedWorld;
  bool remindersEnabled;
  int reminderHour;
  int reminderMinute;
  bool notificationPermissionAsked;
  String? lastPlayedAt;
  String? lastNotificationTime;

  PlayerProgress({
    this.dinoName,
    this.totalPoints = 0,
    this.unlockedLevel = 1,
    Map<int, int>? starsPerLevel,
    this.selectedChocolateSkin = 'dark',
    this.selectedHat = 'none',
    Set<String>? purchasedSkins,
    Set<String>? purchasedHats,
    Set<String>? purchasedWorlds,
    this.endlessBestStage = 0,
    this.endlessBestScore = 0,
    this.lastDailyDate,
    this.dailyStreak = 0,
    this.bestDailyStreak = 0,
    this.levelsCompletedCount = 0,
    this.lastLoginRewardDate,
    this.loginStreak = 0,
    this.bestLoginStreak = 0,
    this.tapAssistAlwaysOn = false,
    this.selectedWorld = 'Jungle',
    this.remindersEnabled = false,
    this.reminderHour = 18,
    this.reminderMinute = 0,
    this.notificationPermissionAsked = false,
    this.lastPlayedAt,
    this.lastNotificationTime,
  })  : starsPerLevel = starsPerLevel ?? {},
        purchasedSkins = purchasedSkins ?? {'dark'},
        purchasedHats = purchasedHats ?? {'none'},
        purchasedWorlds = purchasedWorlds ?? {'Jungle'};

  /// Sum of stars across every level — used by the star wallet in the header.
  int get totalStars => starsPerLevel.values.fold(0, (sum, s) => sum + s);

  Map<String, dynamic> toJson() => {
        'dinoName': dinoName,
        'totalPoints': totalPoints,
        'unlockedLevel': unlockedLevel,
        'starsPerLevel':
            starsPerLevel.map((key, value) => MapEntry(key.toString(), value)),
        'selectedChocolateSkin': selectedChocolateSkin,
        'selectedHat': selectedHat,
        'purchasedSkins': purchasedSkins.toList(),
        'purchasedHats': purchasedHats.toList(),
        'purchasedWorlds': purchasedWorlds.toList(),
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
        'selectedWorld': selectedWorld,
        'remindersEnabled': remindersEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'notificationPermissionAsked': notificationPermissionAsked,
        'lastPlayedAt': lastPlayedAt,
        'lastNotificationTime': lastNotificationTime,
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
    final worlds =
        Set<String>.from(json['purchasedWorlds'] as List? ?? ['Jungle']);
    // Ensure Jungle is always present even in corrupted saves.
    worlds.add('Jungle');

    return PlayerProgress(
      dinoName: json['dinoName'] as String?,
      totalPoints: json['totalPoints'] ?? 0,
      unlockedLevel: json['unlockedLevel'] ?? 1,
      starsPerLevel: starsMap,
      selectedChocolateSkin: json['selectedChocolateSkin'] ?? 'dark',
      selectedHat: json['selectedHat'] ?? 'none',
      purchasedSkins: skins,
      purchasedHats: hats,
      purchasedWorlds: worlds,
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
      selectedWorld: json['selectedWorld'] ?? 'Jungle',
      remindersEnabled: json['remindersEnabled'] ?? false,
      reminderHour: json['reminderHour'] ?? 18,
      reminderMinute: json['reminderMinute'] ?? 0,
      notificationPermissionAsked: json['notificationPermissionAsked'] ?? false,
      lastPlayedAt: json['lastPlayedAt'],
      lastNotificationTime: json['lastNotificationTime'],
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