import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/point.dart';
import '../models/sweet_world.dart';

extension ColorUtils on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}

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

  static final Map<String, TextPainter> _emojiPainters = {};

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
    required this.temporaryEffects,
    this.dangerMap,
    required this.world,
    required this.animationValue,
    this.sweetEmoji,
    this.eatenChocolates = const {},
    this.pathProgress = 0.0,
    this.chocolateImage,
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
        }).toSet();

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
    ..isAntiAlias = true;
  final Paint _pathCorePaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = Colors.white.withOpacity(0.9)
    ..strokeWidth = 3.5
    ..isAntiAlias = true;

  // Obstacle emoji sets per world
  final Map<String, List<String>> _obstacleEmojis = {
    'jungle': ['🌳', '🌴', '🪨', '🌿', '🪵'],
    'candy': ['🍭', '🍬', '🍪', '🧁', '🍫'],
    'ice': ['❄️', '🧊', '⛄', '🌨️', '💎'],
    'volcano': ['🌋', '🪨', '🔥', '💨', '🧨'],
    'space': ['🪐', '💫', '🌟', '☄️', '🚀'],
  };

  List<String> get _currentObstacleSet {
    final name = world.name.toLowerCase();
    return _obstacleEmojis[name] ?? _obstacleEmojis['jungle']!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ---- 1. Draw cells with checkerboard shade ----
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cellRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
          Radius.circular(8),
        );
        final baseColor = (r + c) % 2 == 0
            ? world.tileColor
            : world.tileColor.darken(0.06);
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
    }

    // ---- 2. Danger heatmap (optional) ----
    if (dangerMap != null) {
      for (int r = 0; r < gridSize; r++) {
        for (int c = 0; c < gridSize; c++) {
          final danger = dangerMap![r][c];
          if (danger > 0) {
            final dangerPaint = Paint()
              ..color = Colors.red.withOpacity(0.05 * danger);
            final rect = RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
              Radius.circular(8),
            );
            canvas.drawRRect(rect, dangerPaint);
          }
        }
      }
    }

    // ---- 3. Path ----
    _drawPath(canvas, size);

    // ---- 4. Themed obstacles ----
    _drawThemedObstacles(canvas);

    // ---- 5. Collectibles with image/emoji (now larger) ----
    _drawCollectibles(canvas);

    // ---- 6. Temporary effects ----
    _drawTemporaryEffects(canvas);
  }

  void _drawPath(Canvas canvas, Size size) {
    if (permanentPath.isEmpty && currentDragPath.isEmpty) return;

    final fullPath = Path();
    bool hasMoved = false;

    for (final cell in permanentPath) {
      final parts = cell.split(',').map(int.parse).toList();
      final x = parts[0], y = parts[1];
      final cx = y * cellSize + cellSize / 2;
      final cy = x * cellSize + cellSize / 2;
      if (!hasMoved) {
        fullPath.moveTo(cx, cy);
        hasMoved = true;
      } else {
        fullPath.lineTo(cx, cy);
      }
    }

    for (final p in currentDragPath) {
      final cx = p.y * cellSize + cellSize / 2;
      final cy = p.x * cellSize + cellSize / 2;
      if (!hasMoved) {
        fullPath.moveTo(cx, cy);
        hasMoved = true;
      } else {
        fullPath.lineTo(cx, cy);
      }
    }

    if (!hasMoved) return;

    final glowBase = 0.6 + 0.4 * sin(animationValue * 2 * pi);
    final glowFactor = 0.5 + 0.5 * pathProgress;
    _pathGlowPaint.color = world.pathColor.withOpacity((0.5 * glowBase + 0.2) * glowFactor);
    _pathGlowPaint.strokeWidth = (8 + 4 * sin(animationValue * 4 * pi)) * (0.5 + 0.5 * pathProgress);
    canvas.drawPath(fullPath, _pathGlowPaint);
    canvas.drawPath(fullPath, _pathCorePaint);

    // Sparkles
    if (pathProgress > 0.1) {
      final sparkleCount = (6 * pathProgress).toInt().clamp(2, 12);
      final metrics = fullPath.computeMetrics();
      double totalLen = 0;
      for (final m in metrics) totalLen += m.length;
      if (totalLen > 0) {
        double accumulated = 0;
        for (final metric in metrics) {
          final segmentLen = metric.length;
          while (accumulated < segmentLen) {
            final t = accumulated / segmentLen;
            final position = metric.getTangentForOffset(t * metric.length)?.position;
            if (position != null) {
              final sparklePaint = Paint()
                ..color = Colors.yellow.withOpacity(0.6 + 0.4 * sin(animationValue * 8 + sparkleCount))
                ..style = PaintingStyle.fill;
              canvas.drawCircle(position, 3 + 2 * sin(animationValue * 6 + sparkleCount), sparklePaint);
            }
            accumulated += segmentLen / sparkleCount;
          }
        }
      }
    }
  }

  void _drawThemedObstacles(Canvas canvas) {
    final emojis = _currentObstacleSet;
    final treeEmojis = emojis.sublist(0, 2);
    final mineEmojis = emojis.sublist(2, 4);
    final enemyEmoji = emojis.length > 4 ? emojis[4] : '🪵';
    final hazardEmoji = emojis.last;

    for (final p in obstaclePoints) {
      final center = Offset(p.y * cellSize + cellSize / 2, p.x * cellSize + cellSize / 2);
      final sway = sin(animationValue * 2 * pi + p.x + p.y) * 3;
      final pos = center + Offset(sway, 0);
      final emoji = treeEmojis[(p.x + p.y) % treeEmojis.length];
      _drawEmoji(canvas, pos, emoji, cellSize * 0.5);
    }
    for (final p in minePoints) {
      final center = Offset(p.y * cellSize + cellSize / 2, p.x * cellSize + cellSize / 2);
      final pulse = 0.5 + 0.5 * sin(animationValue * 4 * pi);
      final paint = Paint()
        ..color = Colors.red.withOpacity(0.2 * pulse)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, cellSize * 0.3 * pulse, paint);
      final emoji = mineEmojis[(p.x + p.y) % mineEmojis.length];
      _drawEmoji(canvas, center, emoji, cellSize * 0.5);
    }
    for (final p in enemyPoints) {
      final center = Offset(p.y * cellSize + cellSize / 2, p.x * cellSize + cellSize / 2);
      final bounce = sin(animationValue * 1.5 * pi + p.x * 2) * 4;
      final pos = center + Offset(0, bounce);
      _drawEmoji(canvas, pos, enemyEmoji, cellSize * 0.5);
    }
    for (final p in hazardPoints) {
      final center = Offset(p.y * cellSize + cellSize / 2, p.x * cellSize + cellSize / 2);
      final flicker = sin(animationValue * 10 * pi) * 2;
      final pos = center + Offset(0, flicker);
      _drawEmoji(canvas, pos, hazardEmoji, cellSize * 0.5);
    }
  }

  void _drawCollectibles(Canvas canvas) {
    final emoji = sweetEmoji ?? world.emoji;
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

          // Shadow underneath
          final shadowPaint = Paint()
            ..color = Colors.black.withOpacity(0.15)
            ..style = PaintingStyle.fill;
          canvas.drawOval(
            Rect.fromCenter(center: center + Offset(0, cellSize * 0.35), width: cellSize * 0.3, height: cellSize * 0.08),
            shadowPaint,
          );

          // ---- Draw collectible – now 70% of cell ----
          if (chocolateImage != null) {
            final imageSize = cellSize * 0.7 * scale; // increased from 0.55
            canvas.save();
            canvas.translate(pos.dx, pos.dy);
            canvas.scale(scale);
            canvas.drawImageRect(
              chocolateImage!,
              Rect.fromLTWH(0, 0, chocolateImage!.width.toDouble(), chocolateImage!.height.toDouble()),
              Rect.fromLTWH(-imageSize / 2, -imageSize / 2, imageSize, imageSize),
              Paint(),
            );
            canvas.restore();
          } else {
            // Emoji fallback – larger font size
            _drawEmoji(canvas, pos, emoji, cellSize * 0.7, scale: scale);
          }

          // ---- Glow ring for next chocolate ----
          if (isNext) {
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
          }

          // ---- Sparkles ----
          final sparkleCount = isNext ? 6 : 3;
          for (int i = 0; i < sparkleCount; i++) {
            final angle = animationValue * 4 * pi + i * 2 * pi / sparkleCount;
            final radius = cellSize * 0.3 * (0.5 + 0.5 * sin(animationValue * 2 * pi + i));
            final dx = radius * cos(angle);
            final dy = radius * sin(angle);
            final sparklePos = pos + Offset(dx, dy);
            final sparklePaint = Paint()
              ..color = Colors.white.withOpacity(0.6 + 0.4 * sin(animationValue * 6 + i))
              ..style = PaintingStyle.fill;
            canvas.drawCircle(sparklePos, isNext ? 3 : 2, sparklePaint);
          }
        }
      }
    }
  }

  void _drawTemporaryEffects(Canvas canvas) {
    for (var entry in temporaryEffects.entries) {
      final parts = entry.key.split(',').map(int.parse).toList();
      final r = parts[0], c = parts[1];
      final center = Offset(c * cellSize + cellSize / 2, r * cellSize + cellSize / 2);
      _drawEmoji(canvas, center, entry.value, cellSize * 0.8);
    }
  }

  void _drawEmoji(Canvas canvas, Offset pos, String emoji, double size, {double scale = 1.0}) {
    final key = '$emoji:$size';
    TextPainter? painter = _emojiPainters[key];
    if (painter == null) {
      final style = TextStyle(fontSize: size, fontWeight: FontWeight.bold);
      painter = TextPainter(
        text: TextSpan(text: emoji, style: style),
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
        oldDelegate.obstaclePoints != obstaclePoints ||
        oldDelegate.minePoints != minePoints ||
        oldDelegate.enemyPoints != enemyPoints ||
        oldDelegate.hazardPoints != hazardPoints ||
        oldDelegate.pathProgress != pathProgress ||
        oldDelegate.chocolateImage != chocolateImage;
  }
}