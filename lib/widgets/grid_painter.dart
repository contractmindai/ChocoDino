// lib/widgets/grid_painter.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/point.dart';
import '../models/sweet_world.dart';

// ============================================================================
// EXTENSIONS
// ============================================================================

extension ColorUtils on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
  Color lighten(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/// Removes variation selectors from emoji strings for consistent caching.
String normalizeEmoji(String emoji) {
  return emoji.replaceAll(RegExp(r'[\uFE00-\uFE0F]'), '');
}

// ============================================================================
// GRID PAINTER
// ============================================================================

class GridPainter extends CustomPainter {
  final int gridSize;
  final double cellSize;
  final List<List<String>> grid;
  final List<String> permanentPath;
  final List<Point> currentDragPath;
  final Point? nextChocolate;
  final Point? lastConnected;
  final String chocolateSkin;
  final String hat;
  final Set<Point> obstaclePoints;
  final Set<Point> minePoints;
  final Set<Point> enemyPoints;
  final Set<Point> hazardPoints;
  final Map<String, String> temporaryEffects;
  final List<List<int>>? dangerMap;
  final SweetWorld world;
  final double animationValue;
  final String? sweetEmoji;
  final Set<String> eatenChocolates;
  final double pathProgress;
  final ui.Image? chocolateImage;
  final List<ui.Image?> obstacleImages;
  final Set<Point> detourPoints;
  final Set<Point> bonusPoints;
  final bool showNextChocolateHint;

  // Hidden enemy rendering
  final Set<Point> hiddenEnemyPoints;
  final Set<Point> revealedHiddenEnemyPoints;
  final ui.Image? hiddenEnemyImage;

  // Obstacle key (used for emoji fallback)
  final String obstacleKey;

  final double dinoVerticalOffset;

  // Hovered cells (from game_play_screen)
  final Map<String, bool> hoveredCells;

  static final Map<String, TextPainter> _emojiPainters = {};

  // ========== CONSTRUCTOR ==========
  GridPainter({
    required this.gridSize,
    required this.cellSize,
    required this.grid,
    required this.permanentPath,
    required this.currentDragPath,
    this.nextChocolate,
    this.lastConnected,
    required this.chocolateSkin,
    required this.hat,
    required Set<String> obstacles,
    required Set<String> mines,
    required Set<String> enemies,
    required Set<String> hazards,
    Set<String> detours = const {},
    Set<String> bonusItems = const {},
    required this.temporaryEffects,
    this.dangerMap,
    required this.world,
    required this.animationValue,
    this.sweetEmoji,
    this.eatenChocolates = const {},
    this.pathProgress = 0.0,
    this.chocolateImage,
    this.obstacleImages = const [],
    this.showNextChocolateHint = true,
    this.hiddenEnemyImage,
    Set<String> hiddenEnemies = const {},
    Set<String> revealedHiddenEnemies = const {},
    required this.obstacleKey,
    this.dinoVerticalOffset = 0.0,
    this.hoveredCells = const {},
  })  : obstaclePoints = obstacles.map((s) {
          final parts = s.split(',').map(int.parse).toList();
          return Point(parts[0], parts[1]);
        }).toSet(),
        minePoints = mines.map((s) {
          final parts = s.split(',').map(int.parse).toList();
          return Point(parts[0], parts[1]);
        }).toSet(),
        enemyPoints = enemies.map((s) {
          final parts = s.split(',').map(int.parse).toList();
          return Point(parts[0], parts[1]);
        }).toSet(),
        hazardPoints = hazards.map((s) {
          final parts = s.split(',').map(int.parse).toList();
          return Point(parts[0], parts[1]);
        }).toSet(),
        detourPoints = detours.map((s) {
          final parts = s.split(',').map(int.parse).toList();
          return Point(parts[0], parts[1]);
        }).toSet(),
        bonusPoints = bonusItems.map((s) {
          final parts = s.split(',').map(int.parse).toList();
          return Point(parts[0], parts[1]);
        }).toSet(),
        hiddenEnemyPoints = hiddenEnemies.map((s) {
          final parts = s.split(',').map(int.parse).toList();
          return Point(parts[0], parts[1]);
        }).toSet(),
        revealedHiddenEnemyPoints = revealedHiddenEnemies.map((s) {
          final parts = s.split(',').map(int.parse).toList();
          return Point(parts[0], parts[1]);
        }).toSet();

  // ========== PAINTS ==========
  final Paint _tilePaint = Paint()..isAntiAlias = true;
  final Paint _shadowPaint = Paint()
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4)
    ..color = Colors.black.withOpacity(0.12);
  final Paint _highlightPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = Colors.white.withOpacity(0.15);
  final Paint _cellBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..color = Colors.black.withOpacity(0.08);
  final Paint _pathGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round;
  final Paint _pathCorePaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = Colors.white.withOpacity(0.9)
    ..strokeWidth = 3.5
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round;

  // Paint for hover highlight
  final Paint _hoverPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.green.withOpacity(0.25);
  final Paint _hoverBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..color = Colors.greenAccent.withOpacity(0.6);

  // ========== MAIN PAINT METHOD ==========
  @override
  void paint(Canvas canvas, Size size) {
    // Pre‑compute occupied points for empty‑cell detection
    final occupiedPoints = <Point>{
      ...obstaclePoints,
      ...minePoints,
      ...enemyPoints,
      ...hazardPoints,
      ...bonusPoints,
      ...hiddenEnemyPoints,
    };

    // ------------------------------------------------------------------------
    // 1. TILES + OBSTACLES (single pass over the grid)
    // ------------------------------------------------------------------------
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cellRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
          Radius.circular(8),
        );
        final isChocolate = grid[r][c] == 'chocolate' &&
            !eatenChocolates.contains('$r,$c');
        final isEmpty = !isChocolate && !occupiedPoints.contains(Point(r, c));

        final baseColor = (r + c) % 2 == 0
            ? world.tileColor
            : world.tileColor.darken(0.06);

        // ---- Draw tile ----
        if (isEmpty) {
          _tilePaint.shader = null;
          _tilePaint.color = baseColor.darken(0.02);
          canvas.drawRRect(cellRect, _tilePaint);
          canvas.drawRRect(cellRect, _cellBorderPaint);
        } else {
          final tileGradient = LinearGradient(
            colors: [baseColor, baseColor.darken(0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(cellRect.outerRect);
          _tilePaint.shader = tileGradient;
          canvas.drawRRect(cellRect, _tilePaint);
          canvas.drawRRect(cellRect.shift(const Offset(2, 2)), _shadowPaint);
          final highlightRect = cellRect.deflate(2);
          canvas.drawRRect(highlightRect, _highlightPaint);
          canvas.drawRRect(cellRect, _cellBorderPaint);
        }

        // ---- Hovered cell highlight ----
        final key = '$r,$c';
        if (hoveredCells[key] == true) {
          final hoverRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(c * cellSize + 2, r * cellSize + 2,
                cellSize - 4, cellSize - 4),
            Radius.circular(6),
          );
          canvas.drawRRect(hoverRect, _hoverPaint);
          canvas.drawRRect(hoverRect, _hoverBorderPaint);
        }

        // ---- Obstacles on this tile ----
        final point = Point(r, c);
        final center = Offset(c * cellSize + cellSize / 2, r * cellSize + cellSize / 2);

        if (obstaclePoints.contains(point)) {
          _drawBlockedHatch(canvas, center);
          _drawTileObstacle(canvas, center, r, c, 'tree');
        } else if (minePoints.contains(point)) {
          _drawDangerPulse(canvas, center);
          _drawTileObstacle(canvas, center, r, c, 'mine');
        } else if (enemyPoints.contains(point)) {
          _drawDangerPulse(canvas, center);
          _drawTileObstacle(canvas, center, r, c, 'enemy');
        } else if (hazardPoints.contains(point)) {
          _drawDangerPulse(canvas, center);
          _drawTileObstacle(canvas, center, r, c, 'hazard');
        }
      }
    }

    // ------------------------------------------------------------------------
    // 2. PATH
    // ------------------------------------------------------------------------
    _drawPath(canvas);

    // ------------------------------------------------------------------------
    // 3. DETOURS (faint dots)
    // ------------------------------------------------------------------------
    _drawDetours(canvas);

    // ------------------------------------------------------------------------
    // 4. BONUS ITEMS (gifts) – ENHANCED WITH DEPTH & DETAIL
    // ------------------------------------------------------------------------
    _drawBonusItems(canvas);

    // ------------------------------------------------------------------------
    // 5. HIDDEN ENEMIES (placeholder image)
    // ------------------------------------------------------------------------
    _drawHiddenEnemies(canvas);

    // ------------------------------------------------------------------------
    // 6. COLLECTIBLES (chocolates)
    // ------------------------------------------------------------------------
    _drawCollectibles(canvas);

    // ------------------------------------------------------------------------
    // 7. TEMPORARY EFFECTS
    // ------------------------------------------------------------------------
    _drawTemporaryEffects(canvas);
  }

  // ========== PATH RENDERING ==========
  void _drawPath(Canvas canvas) {
    if (permanentPath.isEmpty && currentDragPath.isEmpty) return;

    final coords = <Point>[];
    for (final cell in permanentPath) {
      final parts = cell.split(',').map(int.parse).toList();
      coords.add(Point(parts[0], parts[1]));
    }
    coords.addAll(currentDragPath);
    if (coords.isEmpty) return;

    final fullPath = Path();
    for (int i = 0; i < coords.length; i++) {
      final p = coords[i];
      var pos = Offset(p.y * cellSize + cellSize / 2, p.x * cellSize + cellSize / 2);
      pos = _adjustForChocolateBob(p.x, p.y, pos);
      if (i == coords.length - 1) {
        pos = pos + Offset(0, dinoVerticalOffset);
      }
      if (i == 0) {
        fullPath.moveTo(pos.dx, pos.dy);
      } else {
        fullPath.lineTo(pos.dx, pos.dy);
      }
    }

    final glowBase = 0.6 + 0.4 * sin(animationValue * 2 * pi);
    final glowFactor = 0.5 + 0.5 * pathProgress;

    _pathGlowPaint.color = world.pathColor.withOpacity((0.7 * glowBase + 0.3) * glowFactor);
    _pathGlowPaint.strokeWidth = (12 + 6 * sin(animationValue * 4 * pi)) * (0.6 + 0.4 * pathProgress);
    canvas.drawPath(fullPath, _pathGlowPaint);
    canvas.drawPath(fullPath, _pathCorePaint);
  }

  Offset _adjustForChocolateBob(int x, int y, Offset basePos) {
    if (x < 0 || x >= grid.length || y < 0 || y >= grid[x].length) return basePos;
    if (grid[x][y] != 'chocolate') return basePos;
    final key = '$x,$y';
    if (eatenChocolates.contains(key)) return basePos;
    final isNext = nextChocolate != null && nextChocolate!.x == x && nextChocolate!.y == y;
    final bobAmplitude = isNext ? 10.0 : 4.0;
    final bob = bobAmplitude * sin(animationValue * 2 * pi + (x + y) * 0.8);
    return basePos + Offset(0, bob);
  }

  // ========== OBSTACLE HELPERS ==========
  void _drawBlockedHatch(Canvas canvas, Offset center) {
    final rect = Rect.fromCenter(center: center, width: cellSize * 0.86, height: cellSize * 0.86);
    final hatchPaint = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.save();
    canvas.clipRect(rect);
    const spacing = 10.0;
    for (double d = -rect.height; d < rect.width; d += spacing) {
      canvas.drawLine(
        Offset(rect.left + d, rect.top),
        Offset(rect.left + d + rect.height, rect.bottom),
        hatchPaint,
      );
    }
    canvas.restore();
  }

  void _drawDangerPulse(Canvas canvas, Offset center) {
    final pulse = 0.5 + 0.5 * sin(animationValue * 3 * pi);
    final ringPaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.28 + 0.22 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, cellSize * (0.40 + 0.05 * pulse), ringPaint);
  }

  void _drawTileObstacle(Canvas canvas, Offset center, int r, int c, String type) {
    final image = _getObstacleImage(type, r, c);
    final size = cellSize * 0.90;
    if (image != null) {
      _drawStaticObstacleImage(canvas, image, center, size);
    } else {
      final emoji = _getObstacleEmoji(type, r, c);
      _drawEmoji(canvas, center, emoji, cellSize * 0.6);
    }
  }

  ui.Image? _getObstacleImage(String type, int r, int c) {
    if (obstacleImages.isEmpty) return null;
    switch (type) {
      case 'tree':
        final idx = (r + c) % obstacleImages.sublist(0, 2).length;
        return obstacleImages[idx];
      case 'mine':
        final idx = (r + c) % obstacleImages.sublist(2, 4).length;
        return obstacleImages[2 + idx];
      case 'enemy':
        return obstacleImages.length > 4 ? obstacleImages[4] : null;
      case 'hazard':
        return obstacleImages.isNotEmpty ? obstacleImages.last : null;
      default:
        return null;
    }
  }

  String _getObstacleEmoji(String type, int r, int c) {
    final emojis = world.obstacleEmojis ?? _defaultObstacleEmojis[obstacleKey] ?? _defaultObstacleEmojis['jungle']!;
    switch (type) {
      case 'tree':
        return emojis[(r + c) % emojis.sublist(0, 2).length];
      case 'mine':
        return emojis[2 + ((r + c) % emojis.sublist(2, 4).length)];
      case 'enemy':
        return emojis.length > 4 ? emojis[4] : '🪵';
      case 'hazard':
        return emojis.last;
      default:
        return '🌲';
    }
  }

  void _drawStaticObstacleImage(Canvas canvas, ui.Image? image, Offset pos, double size) {
    if (image == null) {
      _drawEmoji(canvas, pos, '🌲', size);
      return;
    }
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(pos + Offset(2, 4), size * 0.3, shadowPaint);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(-size / 2, -size / 2, size, size),
      paint,
    );
    canvas.restore();
  }

  // ========== DETOURS ==========
  void _drawDetours(Canvas canvas) {
    if (detourPoints.isEmpty) return;
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    for (final p in detourPoints) {
      final center = Offset(p.y * cellSize + cellSize / 2, p.x * cellSize + cellSize / 2);
      canvas.drawCircle(center, cellSize * 0.08, dotPaint);
    }
  }

  // ========== ENHANCED BONUS ITEMS (with depth, ribbon, and border) ==========
  void _drawBonusItems(Canvas canvas) {
    if (bonusPoints.isEmpty) return;

    for (final p in bonusPoints) {
      final center = Offset(p.y * cellSize + cellSize / 2, p.x * cellSize + cellSize / 2);
      final radius = cellSize * 0.32;

      // ---- 1. Drop shadow ----
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center.translate(2, 3), radius, shadowPaint);

      // ---- 2. Golden circle with radial gradient ----
      final gradient = RadialGradient(
        colors: [Colors.yellow.shade300, Colors.yellow.shade700],
        center: Alignment(-0.2, -0.2),
        radius: 0.8,
      );
      final circlePaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, circlePaint);

      // ---- 3. Border (stroke) ----
      final borderPaint = Paint()
        ..color = Colors.orange.shade800
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, radius, borderPaint);

      // ---- 4. Detailed red ribbon / bow ----
      final ribbonPaint = Paint()..color = Colors.red.shade700;

      // Left loop
      final pathLeft = Path()
        ..moveTo(center.dx - 6, center.dy - 2)
        ..quadraticBezierTo(center.dx - 14, center.dy - 10, center.dx - 8, center.dy - 16)
        ..quadraticBezierTo(center.dx - 2, center.dy - 10, center.dx - 6, center.dy - 2);
      canvas.drawPath(pathLeft, ribbonPaint);

      // Right loop
      final pathRight = Path()
        ..moveTo(center.dx + 6, center.dy - 2)
        ..quadraticBezierTo(center.dx + 14, center.dy - 10, center.dx + 8, center.dy - 16)
        ..quadraticBezierTo(center.dx + 2, center.dy - 10, center.dx + 6, center.dy - 2);
      canvas.drawPath(pathRight, ribbonPaint);

      // Center knot (small circle)
      canvas.drawCircle(Offset(center.dx, center.dy - 2), 3, ribbonPaint);

      // ---- 5. Glow (animated) ----
      final glowPaint = Paint()
        ..color = const Color(0xFFFFD700).withOpacity(0.4 + 0.2 * sin(animationValue * 2.5 * pi + p.x + p.y))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, radius * 1.15, glowPaint);

      // ---- 6. Sparkles ----
      final sparklePaint = Paint()
        ..color = Colors.white.withOpacity(0.6 + 0.4 * sin(animationValue * 5 * pi + p.x * 0.3 + p.y * 0.7))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center + Offset(-radius * 0.5, -radius * 0.6), cellSize * 0.06, sparklePaint);
      final sparklePaint2 = Paint()
        ..color = Colors.white.withOpacity(0.4 + 0.4 * cos(animationValue * 4 * pi + p.x * 0.7 - p.y * 0.3))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center + Offset(radius * 0.6, -radius * 0.4), cellSize * 0.05, sparklePaint2);
    }
  }

  // ========== HIDDEN ENEMIES ==========
  void _drawHiddenEnemies(Canvas canvas) {
    if (hiddenEnemyImage == null || hiddenEnemyPoints.isEmpty) return;
    final double iconSize = cellSize * 0.6;
    for (final p in hiddenEnemyPoints) {
      if (revealedHiddenEnemyPoints.contains(p)) continue;
      final center = Offset(p.y * cellSize + cellSize / 2, p.x * cellSize + cellSize / 2);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      final paint = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;
      canvas.drawImageRect(
        hiddenEnemyImage!,
        Rect.fromLTWH(0, 0,
            hiddenEnemyImage!.width.toDouble(), hiddenEnemyImage!.height.toDouble()),
        Rect.fromLTWH(-iconSize / 2, -iconSize / 2, iconSize, iconSize),
        paint,
      );
      canvas.restore();
    }
  }

  // ========== COLLECTIBLES ==========
  void _drawCollectibles(Canvas canvas) {
    String emoji = sweetEmoji ?? world.emoji;
    const sweets = ['🍫', '🍬', '🍭', '🧁', '🍩', '🍪', '🎂', '🍰'];
    if (!sweets.contains(emoji)) emoji = '🍫';

    final eatenThisDrag = currentDragPath.map((p) => '${p.x},${p.y}').toSet();

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final key = '$r,$c';
        if (grid[r][c] == 'chocolate' &&
            !eatenChocolates.contains(key) &&
            !eatenThisDrag.contains(key)) {
          final center = Offset(c * cellSize + cellSize / 2, r * cellSize + cellSize / 2);
          final isNext = nextChocolate != null && nextChocolate!.x == r && nextChocolate!.y == c;

          final bobAmplitude = isNext ? 10.0 : 4.0;
          final bob = bobAmplitude * sin(animationValue * 2 * pi + (r + c) * 0.8);
          final scale = isNext
              ? 0.9 + 0.3 * sin(animationValue * 4 * pi + 0.5)
              : 1.0 + 0.05 * sin(animationValue * 3 * pi + r * 0.5);

          final pos = center + Offset(0, bob);

          // Shadow – slightly larger to match bigger chocolate
          final shadowPaint = Paint()
            ..color = Colors.black.withOpacity(0.15)
            ..style = PaintingStyle.fill;
          canvas.drawOval(
            Rect.fromCenter(
              center: center + Offset(0, cellSize * 0.38),
              width: cellSize * 0.45,
              height: cellSize * 0.1,
            ),
            shadowPaint,
          );

          // ---- CHOCOLATE IMAGE (increased size) ----
          if (chocolateImage != null) {
            final imageSize = cellSize * 0.90 * scale;
            canvas.save();
            canvas.translate(pos.dx, pos.dy);
            canvas.scale(scale);
            final paint = Paint()
              ..isAntiAlias = true
              ..filterQuality = FilterQuality.high;
            canvas.drawImageRect(
              chocolateImage!,
              Rect.fromLTWH(0, 0, chocolateImage!.width.toDouble(), chocolateImage!.height.toDouble()),
              Rect.fromLTWH(-imageSize / 2, -imageSize / 2, imageSize, imageSize),
              paint,
            );
            canvas.restore();
          } else {
            // Emoji fallback
            _drawEmoji(canvas, pos, emoji, cellSize * 0.8, scale: scale);
          }

          // ---- Glow / sparkles ----
          if (isNext && showNextChocolateHint) {
            final outerRadius = cellSize * 0.6 * (0.8 + 0.2 * sin(animationValue * 3 * pi));
            final outerPaint = Paint()
              ..color = Colors.yellow.withOpacity(0.2 + 0.2 * sin(animationValue * 4 * pi))
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6;
            canvas.drawCircle(pos, outerRadius, outerPaint);

            final ringRadius = cellSize * 0.5 * (0.8 + 0.2 * sin(animationValue * 3 * pi));
            final ringPaint = Paint()
              ..color = Colors.yellow.withOpacity(0.8 + 0.2 * sin(animationValue * 4 * pi))
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4;
            canvas.drawCircle(pos, ringRadius, ringPaint);

            for (int i = 0; i < 6; i++) {
              final angle = animationValue * 4 * pi + i * 2 * pi / 6;
              final radius = cellSize * 0.3 * (0.5 + 0.5 * sin(animationValue * 2 * pi + i));
              final sparklePos = pos + Offset.fromDirection(angle, radius);
              final sparklePaint = Paint()
                ..color = Colors.white.withOpacity(0.6 + 0.4 * sin(animationValue * 6 + i))
                ..style = PaintingStyle.fill;
              canvas.drawCircle(sparklePos, 3, sparklePaint);
            }
          } else {
            for (int i = 0; i < 3; i++) {
              final angle = animationValue * 4 * pi + i * 2 * pi / 3 + 0.5;
              final radius = cellSize * 0.25 * (0.5 + 0.5 * sin(animationValue * 2 * pi + i + 0.3));
              final sparklePos = pos + Offset.fromDirection(angle, radius);
              final sparklePaint = Paint()
                ..color = Colors.white.withOpacity(0.4 + 0.3 * sin(animationValue * 6 + i * 1.5))
                ..style = PaintingStyle.fill;
              canvas.drawCircle(sparklePos, 2, sparklePaint);
            }
          }
        }
      }
    }
  }

  // ========== TEMPORARY EFFECTS ==========
  void _drawTemporaryEffects(Canvas canvas) {
    for (var entry in temporaryEffects.entries) {
      final parts = entry.key.split(',').map(int.parse).toList();
      final r = parts[0], c = parts[1];
      final center = Offset(c * cellSize + cellSize / 2, r * cellSize + cellSize / 2);
      final emoji = normalizeEmoji(entry.value);
      _drawEmoji(canvas, center, emoji, cellSize * 0.8);
    }
  }

  // ========== EMOJI DRAWING ==========
  void _drawEmoji(Canvas canvas, Offset pos, String emoji, double size, {double scale = 1.0}) {
    final normalized = normalizeEmoji(emoji);
    final key = '$normalized:$size';
    TextPainter? painter = _emojiPainters[key];
    if (painter == null) {
      final style = TextStyle(
        fontSize: size,
        fontWeight: FontWeight.bold,
      );
      painter = TextPainter(
        text: TextSpan(text: normalized, style: style),
        textDirection: TextDirection.ltr,
      );
      painter.layout();
      _emojiPainters[key] = painter;
    }
    final offset = pos - Offset(painter.width / 2, painter.height / 2);
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(scale);
    canvas.translate(-pos.dx, -pos.dy);
    painter.paint(canvas, offset);
    canvas.restore();
  }

  // ========== SHOULD REPAINT ==========
  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.permanentPath != permanentPath ||
        oldDelegate.currentDragPath != currentDragPath ||
        oldDelegate.temporaryEffects != temporaryEffects ||
        oldDelegate.eatenChocolates != eatenChocolates ||
        oldDelegate.grid != grid ||
        oldDelegate.world != world ||
        oldDelegate.nextChocolate != nextChocolate ||
        oldDelegate.dangerMap != dangerMap ||
        oldDelegate.sweetEmoji != sweetEmoji ||
        oldDelegate.pathProgress != pathProgress ||
        oldDelegate.chocolateImage != chocolateImage ||
        oldDelegate.obstacleImages != obstacleImages ||
        oldDelegate.showNextChocolateHint != showNextChocolateHint ||
        oldDelegate.hiddenEnemyImage != hiddenEnemyImage ||
        oldDelegate.obstacleKey != obstacleKey ||
        oldDelegate.dinoVerticalOffset != dinoVerticalOffset ||
        oldDelegate.obstaclePoints != obstaclePoints ||
        oldDelegate.minePoints != minePoints ||
        oldDelegate.enemyPoints != enemyPoints ||
        oldDelegate.hazardPoints != hazardPoints ||
        oldDelegate.detourPoints != detourPoints ||
        oldDelegate.bonusPoints != bonusPoints ||
        oldDelegate.hiddenEnemyPoints != hiddenEnemyPoints ||
        oldDelegate.revealedHiddenEnemyPoints != revealedHiddenEnemyPoints ||
        oldDelegate.hoveredCells != hoveredCells;
  }

  // ========== CACHE CLEAR ==========
  static void clearEmojiCache() {
    _emojiPainters.clear();
  }
}

// ============================================================================
// FALLBACK OBSTACLE EMOJIS (if not defined in SweetWorld)
// ============================================================================
const Map<String, List<String>> _defaultObstacleEmojis = {
  'jungle': ['🌳', '🌴', '🪨', '🌿', '🪵'],
  'candy': ['🍭', '🍬', '🍪', '🧁', '🍫'],
  'ice': ['❄️', '🧊', '⛄', '🌨️', '💎'],
  'volcano': ['🌋', '🪨', '🔥', '💨', '🧨'],
  'space': ['🪐', '💫', '🌟', '☄️', '🚀'],
};