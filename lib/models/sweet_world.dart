// lib/models/sweet_world.dart
import 'package:flutter/material.dart';

class SweetWorld {
  final String name;
  final String emoji;
  final Color primaryColor;
  final Color secondaryColor;
  final Color tileColor;
  final Color pathColor;
  final Color accentColor;
  final List<Color> particleColors;
  final String backgroundImagePath;
  final String obstacleKey;
  final String chocolateImagePath;
  final List<String> obstacleEmojis;
  final int unlockPrice; // NEW: 0 = free / default

  const SweetWorld({
    required this.name,
    required this.emoji,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tileColor,
    required this.pathColor,
    required this.accentColor,
    required this.particleColors,
    required this.backgroundImagePath,
    required this.obstacleKey,
    required this.chocolateImagePath,
    required this.obstacleEmojis,
    this.unlockPrice = 0,
  });
}

const List<SweetWorld> kSweetWorlds = [
  SweetWorld(
    name: 'Jungle',
    emoji: '🍫',
    primaryColor: Color(0xFF33691E),
    secondaryColor: Color(0xFF558B2F),
    tileColor: Color(0xFFC5E1A5),
    pathColor: Color(0xFF7CB342),
    accentColor: Color(0xFFAED581),
    particleColors: [Color(0xFF689F38), Color(0xFF8BC34A), Color(0xFFAFB42B)],
    backgroundImagePath: 'assets/backgrounds/jungle_bg.png',
    obstacleKey: 'jungle',
    chocolateImagePath: 'assets/images/jungle_choco.png',
    obstacleEmojis: ['🌳', '🌴', '🪨', '🌿', '🪵'],
    unlockPrice: 0,
  ),
  SweetWorld(
    name: 'Candy Land',
    emoji: '🍬',
    primaryColor: Color(0xFFFF80AB),
    secondaryColor: Color(0xFFFF4081),
    tileColor: Color(0xFFFFF9C4),
    pathColor: Color(0xFFFFD54F),
    accentColor: Color(0xFFFFF176),
    particleColors: [Color(0xFFFFAB91), Color(0xFFFF8A80), Color(0xFFFF80AB)],
    backgroundImagePath: 'assets/backgrounds/candy_bg.png',
    obstacleKey: 'candy',
    chocolateImagePath: 'assets/images/candy_choco.png',
    obstacleEmojis: ['🍭', '🍬', '🍪', '🧁', '🍫'],
    unlockPrice: 200,
  ),
  SweetWorld(
    name: 'Ice World',
    emoji: '🍭',
    primaryColor: Color(0xFFB3E5FC),
    secondaryColor: Color(0xFF4FC3F7),
    tileColor: Color(0xFFE1F5FE),
    pathColor: Color(0xFF81D4FA),
    accentColor: Color(0xFFB3E5FC),
    particleColors: [Color(0xFF4FC3F7), Color(0xFF29B6F6), Color(0xFF81D4FA)],
    backgroundImagePath: 'assets/backgrounds/ice_bg.png',
    obstacleKey: 'ice',
    chocolateImagePath: 'assets/images/ice_choco.png',
    obstacleEmojis: ['❄️', '🧊', '⛄', '🌨️', '💎'],
    unlockPrice: 500,
  ),
  SweetWorld(
    name: 'Volcano',
    emoji: '🍩',
    primaryColor: Color(0xFFBF360C),
    secondaryColor: Color(0xFFF4511E),
    tileColor: Color(0xFFFFCCBC),
    pathColor: Color(0xFFFF7043),
    accentColor: Color(0xFFFF8A65),
    particleColors: [Color(0xFFFF5722), Color(0xFFFF6E40), Color(0xFFFFAB91)],
    backgroundImagePath: 'assets/backgrounds/volcano_bg.png',
    obstacleKey: 'volcano',
    chocolateImagePath: 'assets/images/volcano_choco.png',
    obstacleEmojis: ['🌋', '🪨', '🔥', '💨', '🧨'],
    unlockPrice: 1000,
  ),
  SweetWorld(
    name: 'Space',
    emoji: '🧁',
    primaryColor: Color(0xFF1A237E),
    secondaryColor: Color(0xFF3F51B5),
    tileColor: Color(0xFFE8EAF6),
    pathColor: Color(0xFF5C6BC0),
    accentColor: Color(0xFF9FA8DA),
    particleColors: [Color(0xFF536DFE), Color(0xFF7C4DFF), Color(0xFFB388FF)],
    backgroundImagePath: 'assets/backgrounds/space_bg.png',
    obstacleKey: 'space',
    chocolateImagePath: 'assets/images/space_choco.png',
    obstacleEmojis: ['🪐', '💫', '🌟', '☄️', '🚀'],
    unlockPrice: 2000,
  ),
];

const int kStagesPerWorld = 5;

SweetWorld sweetWorldForStage(int stage) {
  final idx = ((stage - 1) ~/ kStagesPerWorld) % kSweetWorlds.length;
  return kSweetWorlds[idx];
}

SweetWorld sweetWorldForLevel(int level) {
  final idx = ((level - 1) ~/ 5) % kSweetWorlds.length;
  return kSweetWorlds[idx];
}