import 'package:flutter/material.dart';

/// A visual "world" theme for the collectible sweet — endless mode cycles
/// through these every [kStagesPerWorld] stages, so the target keeps
/// changing look (and color) as a run goes on instead of staying a static
/// chocolate circle forever.
///
/// Each world defines a complete visual palette: background gradient, tile
/// colour, path glow, accent colour for highlights, and a set of particle
/// colours for ambient sparkles.
class SweetWorld {
  final String name;
  final String emoji;
  final Color primaryColor;      // background gradient start
  final Color secondaryColor;    // background gradient end
  final Color tileColor;         // base tile colour
  final Color pathColor;         // path glow colour
  final Color accentColor;       // highlight / inner glow
  final List<Color> particleColors; // for floating ambient particles

  const SweetWorld({
    required this.name,
    required this.emoji,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tileColor,
    required this.pathColor,
    required this.accentColor,
    required this.particleColors,
  });
}

/// Predefined worlds with distinct visual identities.
const List<SweetWorld> kSweetWorlds = [
  SweetWorld(
    name: 'Forest',
    emoji: '🍫',
    primaryColor: Color(0xFF1B5E20),
    secondaryColor: Color(0xFF388E3C),
    tileColor: Color(0xFFC8E6C9),
    pathColor: Color(0xFF66BB6A),
    accentColor: Color(0xFFA5D6A7),
    particleColors: [
      Color(0xFF2E7D32),
      Color(0xFF4CAF50),
      Color(0xFF81C784),
    ],
  ),
  SweetWorld(
    name: 'Candy Land',
    emoji: '🍬',
    primaryColor: Color(0xFFFF80AB),
    secondaryColor: Color(0xFFFF4081),
    tileColor: Color(0xFFFFF9C4),
    pathColor: Color(0xFFFFD54F),
    accentColor: Color(0xFFFFF176),
    particleColors: [
      Color(0xFFFFAB91),
      Color(0xFFFF8A80),
      Color(0xFFFF80AB),
    ],
  ),
  SweetWorld(
    name: 'Ice World',
    emoji: '🍦',
    primaryColor: Color(0xFFB3E5FC),
    secondaryColor: Color(0xFF4FC3F7),
    tileColor: Color(0xFFE1F5FE),
    pathColor: Color(0xFF81D4FA),
    accentColor: Color(0xFFB3E5FC),
    particleColors: [
      Color(0xFF4FC3F7),
      Color(0xFF29B6F6),
      Color(0xFF81D4FA),
    ],
  ),
  SweetWorld(
    name: 'Volcano',
    emoji: '🌋',
    primaryColor: Color(0xFFBF360C),
    secondaryColor: Color(0xFFF4511E),
    tileColor: Color(0xFFFFCCBC),
    pathColor: Color(0xFFFF7043),
    accentColor: Color(0xFFFF8A65),
    particleColors: [
      Color(0xFFFF5722),
      Color(0xFFFF6E40),
      Color(0xFFFFAB91),
    ],
  ),
  SweetWorld(
    name: 'Space',
    emoji: '🚀',
    primaryColor: Color(0xFF1A237E),
    secondaryColor: Color(0xFF3F51B5),
    tileColor: Color(0xFFE8EAF6),
    pathColor: Color(0xFF5C6BC0),
    accentColor: Color(0xFF9FA8DA),
    particleColors: [
      Color(0xFF536DFE),
      Color(0xFF7C4DFF),
      Color(0xFFB388FF),
    ],
  ),
  SweetWorld(
    name: 'Jungle',
    emoji: '🌴',
    primaryColor: Color(0xFF33691E),
    secondaryColor: Color(0xFF558B2F),
    tileColor: Color(0xFFC5E1A5),
    pathColor: Color(0xFF7CB342),
    accentColor: Color(0xFFAED581),
    particleColors: [
      Color(0xFF689F38),
      Color(0xFF8BC34A),
      Color(0xFFAFB42B),
    ],
  ),
];

/// How many endless-mode stages before the sweet world cycles to the next
/// theme. Stage 1-5 = World 1, stage 6-10 = World 2, ... then loops back
/// to World 1 after World 5.
const int kStagesPerWorld = 5;

/// Returns the world for a given endless stage number.
SweetWorld sweetWorldForStage(int stage) {
  final idx = ((stage - 1) ~/ kStagesPerWorld) % kSweetWorlds.length;
  return kSweetWorlds[idx];
}

/// Returns the world for a given campaign level number.
/// Rotates every 5 levels (you can adjust the period as desired).
SweetWorld sweetWorldForLevel(int level) {
  final idx = ((level - 1) ~/ 5) % kSweetWorlds.length;
  return kSweetWorlds[idx];
}