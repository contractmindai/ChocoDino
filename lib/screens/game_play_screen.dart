// lib/screens/game_play_screen.dart
import 'dart:async';
import 'dart:collection';
import 'dart:math' hide Point;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart'; // <-- NEW

import '../models/level_config.dart';
import '../models/player_progress.dart';
import '../models/point.dart';
import '../models/sweet_world.dart';
import '../models/chocolate.dart';
import '../data/daily_challenge.dart';
import '../data/endless_generator.dart';
import '../data/levels.dart';
import '../utils/sound_manager.dart';
import '../utils/responsive.dart';
import '../widgets/grid_painter.dart';
import '../widgets/logo.dart';
import '../widgets/particle_system.dart';
import '../widgets/physics_motion.dart';
import '../widgets/loading_mini_game.dart';
import '../widgets/theme_widgets.dart';
import '../widgets/level_complete_body.dart';
import '../dialogs/tutorial_dialog.dart';
import '../dialogs/win_dialog.dart';
import '../dialogs/game_over_dialog.dart';
import '../dialogs/loading_dialog.dart';

// ============================================================================
// ENUMS & CONSTANTS
// ============================================================================

enum CellType { empty, chocolate }
const String kEmptyCell = 'empty';
const String kChocolateCell = 'chocolate';

enum ObstacleEffect { mine, enemy, hazard }
enum GameMode { normal, daily, endless }
enum WinDialogResult { retry, next, exit }

const int kStartingChances = 3;
const int kEndlessStartingChances = 3;

const double kLuckyChocolateChance = 0.12;
const int kLuckyChocolateBonus = 15;

const int kTapAssistUnlockThreshold = 3;

const List<String> kSweetEmojis = ['🍫', '🍬', '🍭', '🧁', '🍩', '🍪', '🎂', '🍰'];
const Map<String, String> kSweetImageMap = {
  '🍫': 'assets/images/jungle_choco.png',
  '🍬': 'assets/images/candy_choco.png',
  '🍭': 'assets/images/ice_choco.png',
  '🧁': 'assets/images/space_choco.png',
  '🍩': 'assets/images/volcano_choco.png',
  '🍪': 'assets/images/cookie.jpg',
  '🎂': 'assets/images/cake.jpg',
  '🍰': 'assets/images/slice.jpg',
};

const Map<String, List<String>> kWorldObstacleAssets = {
  'jungle': [
    'assets/obstacles/jungle_tree.jpg',
    'assets/obstacles/jungle_palm.jpg',
    'assets/obstacles/jungle_rock.jpg',
    'assets/obstacles/jungle_bush.jpg',
    'assets/obstacles/jungle_log.jpg',
  ],
  'candy': [
    'assets/images/lollipop.jpg',
    'assets/images/candy.jpg',
    'assets/images/cookie.jpg',
    'assets/images/cupcake.jpg',
    'assets/images/chocolate.jpg',
  ],
  'ice': [
    'assets/obstacles/ice_crystal.jpg',
    'assets/obstacles/ice_block.jpg',
    'assets/obstacles/ice_snowman.jpg',
    'assets/obstacles/ice_snowflake.jpg',
    'assets/obstacles/ice_gem.jpg',
  ],
  'volcano': [
    'assets/obstacles/volcano_rock.jpg',
    'assets/obstacles/volcano_lava.jpg',
    'assets/obstacles/volcano_fire.jpg',
    'assets/obstacles/volcano_smoke.jpg',
    'assets/obstacles/volcano_bomb.jpg',
  ],
  'space': [
    'assets/obstacles/space_planet.jpg',
    'assets/obstacles/space_star.jpg',
    'assets/obstacles/space_rocket.jpg',
    'assets/obstacles/space_comet.jpg',
    'assets/obstacles/space_ufo.jpg',
  ],
};

// ============================================================================
// FLOATING TEXT POPUP (unchanged)
// ============================================================================

class _FloatingText extends StatefulWidget {
  final Offset startPosition;
  final String text;
  final Color color;
  final VoidCallback onComplete;

  const _FloatingText({
    required this.startPosition,
    required this.text,
    required this.color,
    required this.onComplete,
  });

  @override
  State<_FloatingText> createState() => _FloatingTextState();
}

class _FloatingTextState extends State<_FloatingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -100),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.startPosition.dx - 40,
      top: widget.startPosition.dy - 20,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: _offsetAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        shadows: [
                          Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// GAME CONTROLLER (unchanged)
// ============================================================================

class GameController extends ChangeNotifier {
  final LevelConfig level;
  final PlayerProgress progress;
  final int startingChances;

  List<List<String>> grid = [];
  List<String> permanentPathCells = [];
  Set<String> collectedChocolateKeys = {};
  int chances = 5;
  bool gameActive = true;
  bool win = false;
  Point dinoPos = const Point(0, 0);
  List<Point> currentDragPath = [];
  Map<String, String> temporaryEffects = {};
  Set<String> collectedBonuses = {};

  int totalStepsTaken = 0;
  int dragFailureCount = 0;

  void recordDragFailure() {
    dragFailureCount++;
    notifyListeners();
  }

  bool get tapAssistUnlocked => dragFailureCount >= kTapAssistUnlockThreshold;

  GameController({
    required this.level,
    required this.progress,
    this.startingChances = kStartingChances,
  }) {
    _initLevel();
  }

  void _initLevel() {
    final size = level.gridSize;
    grid = List.generate(size, (_) => List.filled(size, kEmptyCell));
    for (final choc in level.chocolates) {
      grid[choc.row][choc.col] = kChocolateCell;
    }
    final first = level.chocolates.first;
    collectedChocolateKeys.clear();
    collectedChocolateKeys.add('${first.row},${first.col}');
    dinoPos = Point(first.row, first.col);
    permanentPathCells = ['${first.row},${first.col}'];
    chances = startingChances;
    gameActive = true;
    win = false;
    currentDragPath = [];
    temporaryEffects.clear();
    collectedBonuses.clear();
    totalStepsTaken = 0;
    notifyListeners();
  }

  void retry() {
    _initLevel();
    notifyListeners();
  }

  bool collectBonus(int row, int col) {
    final key = '$row,$col';
    if (!level.bonusItems.contains(key)) return false;
    if (collectedBonuses.contains(key)) return false;
    collectedBonuses.add(key);
    progress.totalPoints += 5;
    unawaited(progress.save());
    notifyListeners();
    return true;
  }

  bool isUncollectedChocolate(int row, int col) {
    final key = '$row,$col';
    return grid[row][col] == kChocolateCell && !collectedChocolateKeys.contains(key);
  }

  bool isObstacleCell(int row, int col) => checkObstacle(row, col) != null;
  bool isAdjacent(Point a, Point b) => (a.x - b.x).abs() + (a.y - b.y).abs() == 1;

  ObstacleEffect? checkObstacle(int row, int col) {
    final key = '$row,$col';
    if (level.mines.contains(key)) return ObstacleEffect.mine;
    if (level.enemies.contains(key)) return ObstacleEffect.enemy;
    if (level.hazards.contains(key)) return ObstacleEffect.hazard;
    return null;
  }

  void wrongMove() {
    if (!gameActive) return;
    chances--;
    if (chances <= 0) {
      gameActive = false;
    } else {
      currentDragPath = [];
    }
    notifyListeners();
  }

  void applyObstacleEffect(ObstacleEffect effect, int row, int col) {
    switch (effect) {
      case ObstacleEffect.mine:
        chances--;
        break;
      case ObstacleEffect.enemy:
        chances -= 2;
        break;
      case ObstacleEffect.hazard:
        chances -= 2;
        final newPoints = progress.totalPoints - 10;
        progress.totalPoints = newPoints < 0 ? 0 : newPoints;
        unawaited(progress.save());
        break;
    }
    if (chances <= 0) {
      gameActive = false;
    } else {
      currentDragPath = [];
    }
    notifyListeners();
  }

  int lastLuckyBonus = 0;
  final Random _random = Random();

  void collectChocolate(Point target) {
    final key = '${target.x},${target.y}';
    for (final p in currentDragPath) {
      permanentPathCells.add('${p.x},${p.y}');
    }
    collectedChocolateKeys.add(key);
    dinoPos = target;
    currentDragPath.clear();

    if (_random.nextDouble() < kLuckyChocolateChance) {
      lastLuckyBonus = kLuckyChocolateBonus;
      progress.totalPoints += kLuckyChocolateBonus;
      unawaited(progress.save());
    } else {
      lastLuckyBonus = 0;
    }

    if (collectedChocolateKeys.length == level.chocolates.length) {
      win = true;
      gameActive = false;
    }
    notifyListeners();
  }

  void addToDragPath(Point cell) {
    if (currentDragPath.isNotEmpty && currentDragPath.last == cell) return;
    currentDragPath.add(cell);
    dinoPos = cell;
    totalStepsTaken++;
    notifyListeners();
  }

  void reseedDragAt(Point cell) {
    currentDragPath = [cell];
    notifyListeners();
  }

  void removeLastFromDragPath() {
    if (currentDragPath.length >= 2) {
      currentDragPath.removeLast();
      dinoPos = currentDragPath.last;
      totalStepsTaken = (totalStepsTaken - 1).clamp(0, 1 << 30);
      notifyListeners();
    }
  }

  void resetDrag() {
    currentDragPath = [];
    notifyListeners();
  }

  bool get hasWon => win;
  bool get isActive => gameActive && !win;

  int get bonusPointsThisLevel => collectedBonuses.length * 5;
  int get parSteps => level.path.length;

  double get pathEfficiency {
    if (totalStepsTaken <= 0) return 1.0;
    return (parSteps / totalStepsTaken).clamp(0.0, 1.0);
  }

  int get starsEarned {
    final efficiency = pathEfficiency;
    if (chances >= 3 && efficiency >= 0.75) return 3;
    if (chances >= 2 && efficiency >= 0.55) return 2;
    if (chances >= 1) return 1;
    return 0;
  }

  int get pointsEarned => starsEarned == 3 ? 30 : starsEarned == 2 ? 25 : 20;
}

// ============================================================================
// FOOTSTEP DATA & PAINTER (unchanged)
// ============================================================================

enum FootType { left, right }

class Footstep {
  final Point cell;
  final FootType type;
  final double rotation; // radians
  Footstep(this.cell, this.type, this.rotation);
}

class FootstepPainter extends CustomPainter {
  final List<Footstep> footsteps;
  final double cellSize;
  final ui.Image leftImage;
  final ui.Image rightImage;

  FootstepPainter(this.footsteps, this.cellSize, this.leftImage, this.rightImage);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xAAFFFFFF);
    for (final fs in footsteps) {
      final image = fs.type == FootType.left ? leftImage : rightImage;
      final center = Offset(
        fs.cell.y * cellSize + cellSize / 2,
        fs.cell.x * cellSize + cellSize / 2,
      );
      final fpSize = cellSize * 0.55;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(fs.rotation);

      final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      final dst = Rect.fromCenter(center: Offset.zero, width: fpSize, height: fpSize);
      canvas.drawImageRect(image, src, dst, paint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant FootstepPainter old) => old.footsteps != footsteps;
}

// ============================================================================
// GAME PLAY SCREEN
// ============================================================================

class GamePlayScreen extends StatefulWidget {
  final String dinoName;
  final LevelConfig? level;
  final PlayerProgress progress;
  final GameMode mode;

  const GamePlayScreen({
    super.key,
    required this.dinoName,
    this.level,
    required this.progress,
    this.mode = GameMode.normal,
  }) : assert(mode == GameMode.endless || level != null, 'level is required unless mode is GameMode.endless');

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> with TickerProviderStateMixin {
  GameController? _game;
  bool _isDialogShowing = false;
  bool _isAnimatingTapPath = false;
  bool _isGameFinished = false;
  bool _isLoadingNextLevel = false;

  late GameMode _mode;

  LevelConfig? _activeLevel;
  late SweetWorld _currentWorld;
  SweetWorld? _lastWorldForAssets;
  late String _collectibleEmoji;
  ui.Image? _currentSweetImage;

  int _endlessStage = 1;
  int _endlessRunSeed = 0;
  int _endlessScore = 0;

  bool _isLoadingFirstLevel = false;
  Future<LevelConfig>? _prefetchedNextLevel;

  late AnimationController _idleController;
  late Animation<double> _bobAnimation;
  late AnimationController _biteController;
  late AnimationController _stepController;
  late AnimationController _colorPulseController;
  late ConfettiController _confettiController;

  DinoMotionController? _dinoMotion;
  ParticleController? _particles;
  double _cellSize = 1;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  double _redFlashOpacity = 0.0;

  final GlobalKey _gridKey = GlobalKey();

  late AnimationController _bgController;

  ui.Image? _dinoIdleImage;
  ui.Image? _dinoWalkImage;
  ui.Image? _dinoEatImage;
  bool _imagesLoaded = false;
  ui.Image? _starFilledImage;
  ui.Image? _starEmptyImage;
  ui.Image? _dinoTrophyImage;

  ui.Image? _backgroundImage;
  String? _currentBackgroundImagePath;

  final Map<String, ui.Image> _sweetImageCache = {};
  final Map<String, List<ui.Image?>> _obstacleImageCache = {};
  List<ui.Image?> _obstacleImages = [];
  String? _currentObstacleKey;

  Set<String>? _cachedEatenKeys;
  int _lastCollectedCount = -1;

  final Set<String> _revealedHiddenEnemies = {};

  List<Point> _currentPath = [];
  Map<String, bool> _hoveredCells = {};

  int _displayStars = 0;
  bool _isDragging = false;

  final Random _rand = Random();

  // Footstep fields
  ui.Image? _footLeftImage;
  ui.Image? _footRightImage;
  final List<Footstep> _footsteps = [];
  int _stepCounter = 0;

  // ---- NEW: Visual tilt from accelerometer ----
  double _dinoLean = 0.0;
  StreamSubscription<AccelerometerEvent>? _sensorSub;

  void _resetFootsteps() {
    _footsteps.clear();
    _stepCounter = 0;
  }

  void _addFootstep(Point from, Point to) {
    final dx = to.y - from.y;
    final dy = to.x - from.x;
    final angle = atan2(dy, dx);
    final footType = _stepCounter % 2 == 0 ? FootType.left : FootType.right;
    _footsteps.add(Footstep(to, footType, angle));
    _stepCounter++;
  }

  Set<String> _getEatenChocolateKeys() {
    if (_game == null) return {};
    final count = _game!.collectedChocolateKeys.length;
    if (_lastCollectedCount != count) {
      _cachedEatenKeys = Set.from(_game!.collectedChocolateKeys);
      _lastCollectedCount = count;
    }
    return _cachedEatenKeys!;
  }

  String _getDinoQuote(bool isWin) {
    final winQuotes = [
      'Yummy! That was delicious!',
      'More chocolate, please!',
      'Rex is happy!',
      'Best snack ever!',
    ];
    final loseQuotes = [
      'Oops! Let\'s try another path.',
      'Rex needs more practice!',
      'Almost had it! Try again.',
      'Dino is sad... 😢',
    ];
    final list = isWin ? winQuotes : loseQuotes;
    return list[_rand.nextInt(list.length)];
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _initAnimations();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    SoundManager.addListener(_onSoundChanged);
    _collectibleEmoji = kSweetEmojis.isNotEmpty ? kSweetEmojis[0] : '🍫';
    _loadImages();

    if (_mode == GameMode.endless) {
      _endlessRunSeed = _rand.nextInt(1 << 31);
      _isLoadingFirstLevel = true;
      _loadFirstEndlessLevel();
    } else {
      _activeLevel = widget.level!;
      _game = GameController(level: _activeLevel!, progress: widget.progress, startingChances: kStartingChances);
      _updateWorld();
      _game!.addListener(_onGameStateChanged);
      _dinoMotion = DinoMotionController(
        startRow: _game!.dinoPos.x,
        startCol: _game!.dinoPos.y,
      )..attach(this);
      _particles = ParticleController()..attach(this);
      _checkTutorial();
      SoundManager.playBg();
    }

    // ---- NEW: Start accelerometer listener for visual tilt ----
    _sensorSub = accelerometerEvents.listen((event) {
      // Map x-axis acceleration to a lean angle (clamped)
      // 9.81 m/s² is 1 G. Sensitivity 0.3 (max angle ~0.3 rad ≈17°)
      final lean = (event.x / 9.81).clamp(-1.0, 1.0) * 0.3;
      // Dead-zone to avoid jitter
      if (lean.abs() < 0.01) {
        if (_dinoLean.abs() > 0.01) {
          setState(() => _dinoLean = 0.0);
        }
        return;
      }
      if ((lean - _dinoLean).abs() > 0.005) {
        setState(() => _dinoLean = lean);
      }
    });
  }

  // ---- Load images ----
  Future<void> _loadSweetImage(String emoji) async {
    final assetPath = kSweetImageMap[emoji];
    if (assetPath == null) {
      _currentSweetImage = null;
      return;
    }
    if (_sweetImageCache.containsKey(emoji)) {
      _currentSweetImage = _sweetImageCache[emoji];
      return;
    }
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;
      _sweetImageCache[emoji] = image;
      _currentSweetImage = image;
    } catch (_) {
      _currentSweetImage = null;
    }
  }

  Future<void> _loadObstacleImagesForWorld(String obstacleKey) async {
    if (_currentObstacleKey == obstacleKey && _obstacleImageCache.containsKey(obstacleKey)) {
      return;
    }

    final cached = _obstacleImageCache[obstacleKey];
    if (cached != null) {
      _currentObstacleKey = obstacleKey;
      if (mounted) setState(() => _obstacleImages = cached);
      return;
    }

    final assets = kWorldObstacleAssets[obstacleKey] ?? kWorldObstacleAssets['jungle']!;
    final images = <ui.Image?>[];
    for (final asset in assets) {
      try {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        images.add(frame.image);
      } catch (_) {
        images.add(null);
      }
    }

    _obstacleImageCache[obstacleKey] = images;
    _currentObstacleKey = obstacleKey;
    if (mounted) {
      setState(() {
        _obstacleImages = images;
      });
    }
  }

  Future<void> _loadImages() async {
    try {
      final idleData = await rootBundle.load('assets/dino/idle.png');
      final idleCodec = await ui.instantiateImageCodec(idleData.buffer.asUint8List());
      final idleFrame = await idleCodec.getNextFrame();
      _dinoIdleImage = idleFrame.image;

      try {
        final walkData = await rootBundle.load('assets/dino/walk.png');
        final walkCodec = await ui.instantiateImageCodec(walkData.buffer.asUint8List());
        final walkFrame = await walkCodec.getNextFrame();
        _dinoWalkImage = walkFrame.image;
      } catch (_) {
        _dinoWalkImage = _dinoIdleImage;
      }

      try {
        final eatData = await rootBundle.load('assets/dino/eat.png');
        final eatCodec = await ui.instantiateImageCodec(eatData.buffer.asUint8List());
        final eatFrame = await eatCodec.getNextFrame();
        _dinoEatImage = eatFrame.image;
      } catch (_) {
        _dinoEatImage = _dinoIdleImage;
      }

      // Footprints
      final fpLData = await rootBundle.load('assets/dino/dino_footprint_left.png');
      final fpLCodec = await ui.instantiateImageCodec(fpLData.buffer.asUint8List());
      final fpLFrame = await fpLCodec.getNextFrame();
      _footLeftImage = fpLFrame.image;

      final fpRData = await rootBundle.load('assets/dino/dino_footprint_right.png');
      final fpRCodec = await ui.instantiateImageCodec(fpRData.buffer.asUint8List());
      final fpRFrame = await fpRCodec.getNextFrame();
      _footRightImage = fpRFrame.image;

      // Star images
      final starFilledData = await rootBundle.load('assets/dino/star_filled.png');
      final starFilledCodec = await ui.instantiateImageCodec(starFilledData.buffer.asUint8List());
      final starFilledFrame = await starFilledCodec.getNextFrame();
      _starFilledImage = starFilledFrame.image;

      final starEmptyData = await rootBundle.load('assets/dino/star_empty.png');
      final starEmptyCodec = await ui.instantiateImageCodec(starEmptyData.buffer.asUint8List());
      final starEmptyFrame = await starEmptyCodec.getNextFrame();
      _starEmptyImage = starEmptyFrame.image;

      // Dino trophy image
      final trophyData = await rootBundle.load('assets/dino/dino_trophy.png');
      final trophyCodec = await ui.instantiateImageCodec(trophyData.buffer.asUint8List());
      final trophyFrame = await trophyCodec.getNextFrame();
      _dinoTrophyImage = trophyFrame.image;

      if (mounted) setState(() => _imagesLoaded = true);
    } catch (e) {
      if (mounted) setState(() => _imagesLoaded = true);
    }
  }

  Future<void> _loadBackgroundImage(String path) async {
    if (_currentBackgroundImagePath == path && _backgroundImage != null) return;

    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _backgroundImage = frame.image;
          _currentBackgroundImagePath = path;
        });
      }
    } catch (e) {
      debugPrint('Failed to load background image: $e');
      if (mounted) {
        setState(() {
          _backgroundImage = null;
          _currentBackgroundImagePath = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _sensorSub?.cancel(); // <-- NEW
    SoundManager.removeListener(_onSoundChanged);
    _game?.removeListener(_onGameStateChanged);
    _game?.dispose();
    _dinoMotion?.dispose();
    _particles?.dispose();
    _idleController.dispose();
    _biteController.dispose();
    _stepController.dispose();
    _colorPulseController.dispose();
    _confettiController.dispose();
    _bgController.dispose();
    _shakeController.dispose();
    SoundManager.stopBg();
    super.dispose();
  }

  void _onSoundChanged() {
    if (mounted) setState(() {});
  }

  void _updateWorld() {
    final newWorld = _mode == GameMode.endless
        ? sweetWorldForStage(_endlessStage)
        : sweetWorldForLevel(_activeLevel!.levelNumber);

    final worldChanged = _lastWorldForAssets != newWorld;
    _currentWorld = newWorld;
    _collectibleEmoji = _currentWorld.emoji;

    if (!worldChanged) return;
    _lastWorldForAssets = newWorld;

    _loadSweetImage(_collectibleEmoji);
    _loadObstacleImagesForWorld(_currentWorld.obstacleKey);
    _loadBackgroundImage(_currentWorld.backgroundImagePath);
  }

  void _initAnimations() {
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _bobAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );
    _biteController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _stepController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _colorPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 4.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
  }

  void _onGameStateChanged() {
    if (!mounted || _game == null) return;
    _dinoMotion?.moveTo(_game!.dinoPos.x, _game!.dinoPos.y);

    if (!_isDragging) {
      _displayStars = _game!.starsEarned;
    }

    if (_isGameFinished) return;

    if (_game!.hasWon && !_isDialogShowing && !_isLoadingNextLevel) {
      _handleWin();
    } else if (!_game!.isActive && !_game!.hasWon && !_isDialogShowing) {
      _isGameFinished = true;
      _showGameOverDialog();
    }
    setState(() {});
  }

  void _handleWin() {
    if (_isGameFinished) return;
    _isGameFinished = true;
    if (_mode == GameMode.endless) {
      _handleEndlessStageCleared();
    } else {
      _confettiController.play();
      SoundManager.playWin();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _showWinDialog();
        }
      });
    }
  }

  // ---- Endless logic ----
  Future<void> _handleEndlessStageCleared() async {
    if (_isLoadingNextLevel || _game == null) return;
    _isLoadingNextLevel = true;

    _confettiController.play();
    SoundManager.playStageClear();

    final points = _game!.pointsEarned;
    final stars = _game!.starsEarned;
    final quote = _getDinoQuote(true);
    final world = _currentWorld;

    _endlessScore += points;
    final carryChances = _game!.chances;

    if (_endlessStage > widget.progress.endlessBestStage) {
      widget.progress.endlessBestStage = _endlessStage;
    }
    if (_endlessScore > widget.progress.endlessBestScore) {
      widget.progress.endlessBestScore = _endlessScore;
    }
    await widget.progress.save();

    if (mounted) {
      final winBody = LevelCompleteBody(
        dinoImage: _dinoTrophyImage!,
        starFilledImage: _starFilledImage!,
        starEmptyImage: _starEmptyImage!,
        earnedStars: stars,
        points: points,
        quote: quote,
        primaryColor: world.primaryColor,
        secondaryColor: world.secondaryColor,
      );

      await showCartoonDialog(
        context: context,
        world: world,
        title: '',
        backgroundImagePath: world.backgroundImagePath,
        body: winBody,
        actions: [
          CartoonButton(
            world: world,
            label: 'Continue',
            primary: true,
            icon: Icons.arrow_forward,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
    }

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) {
      _isLoadingNextLevel = false;
      return;
    }

    final nextStage = _endlessStage + 1;

    LevelConfig? nextLevel;
    if (_prefetchedNextLevel != null) {
      try {
        nextLevel = await _prefetchedNextLevel!;
      } catch (e) {
        nextLevel = null;
      }
    }
    if (nextLevel == null) {
      final levelFuture = generateEndlessLevelAsync(nextStage, _endlessRunSeed)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              _showMessage('⏳ Dino is taking his time... retrying!');
              return generateEndlessLevelAsync(nextStage, _rand.nextInt(1 << 31));
            },
          )
          .catchError((e) {
            _showMessage('Dino got distracted! Trying again...');
            return generateEndlessLevelAsync(nextStage, _rand.nextInt(1 << 31));
          });

      final bonus = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => LoadingMiniGame(loadingFuture: levelFuture),
      );

      try {
        nextLevel = await levelFuture;
      } catch (e) {
        nextLevel = _fallbackEndlessLevel(nextStage);
      }

      if (bonus != null && bonus > 0) {
        widget.progress.totalPoints += bonus;
        await widget.progress.save();
      }
    }

    if (!mounted) {
      _isLoadingNextLevel = false;
      return;
    }

    if (nextLevel == null) {
      _isGameFinished = false;
      _isLoadingNextLevel = false;
      _showMessage('😴 Dino is exhausted! Game Over for now.');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showGameOverDialog();
      });
      return;
    }

    _endlessStage = nextStage;
    _replaceGameController(
      GameController(
        level: nextLevel!,
        progress: widget.progress,
        startingChances: carryChances,
      ),
    );
    setState(() {
      _activeLevel = nextLevel;
      _updateWorld();
      _isGameFinished = false;
      _isLoadingNextLevel = false;
      _currentPath.clear();
      _hoveredCells.clear();
      _resetFootsteps();
    });
    _dinoMotion?.snapTo(_game!.dinoPos.x, _game!.dinoPos.y);
    _resetAnimations();
    _prefetchNextStage();
  }

  LevelConfig _fallbackEndlessLevel(int stage) {
    final world = sweetWorldForStage(stage);
    return LevelConfig(
      stage,
      5,
      [Chocolate(1, 0, 1), Chocolate(2, 2, 2), Chocolate(3, 4, 3)],
      obstacles: {},
      mines: {},
      enemies: {},
      hazards: {},
      dangerMap: List.generate(5, (_) => List.filled(5, 0)),
      path: {'0,1', '1,1', '2,1', '2,2', '3,2', '4,2', '4,3'},
      world: world,
    );
  }

  void _prefetchNextStage() {
    if (_mode != GameMode.endless) return;
    _prefetchedNextLevel = generateEndlessLevelAsync(_endlessStage + 1, _endlessRunSeed);
  }

  Future<void> _restartEndlessRun({bool resetRun = true}) async {
    if (resetRun) {
      setState(() => _isLoadingFirstLevel = true);
      _endlessStage = 1;
      _endlessScore = 0;
      _endlessRunSeed = _rand.nextInt(1 << 31);
      _prefetchedNextLevel = null;
    } else {
      setState(() => _isLoadingFirstLevel = true);
      _prefetchedNextLevel = null;
    }

    LevelConfig? level;
    try {
      level = await generateEndlessLevelAsync(_endlessStage, _endlessRunSeed);
    } catch (e, st) {
      try {
        level = await generateEndlessLevelAsync(_endlessStage, _rand.nextInt(1 << 31));
      } catch (e2, st2) {}
    }
    if (!mounted) return;
    if (level == null) {
      Navigator.pop(context);
      return;
    }

    _replaceGameController(
      GameController(
        level: level,
        progress: widget.progress,
        startingChances: kEndlessStartingChances,
      ),
    );
    setState(() {
      _activeLevel = level;
      _updateWorld();
      _isGameFinished = false;
      _isLoadingFirstLevel = false;
      _currentPath.clear();
      _hoveredCells.clear();
      _resetFootsteps();
    });
    _dinoMotion?.snapTo(_game!.dinoPos.x, _game!.dinoPos.y);
    _resetAnimations();
    _prefetchNextStage();
  }

  Future<void> _loadFirstEndlessLevel() async {
    LevelConfig? level;
    try {
      level = await generateEndlessLevelAsync(_endlessStage, _endlessRunSeed);
    } catch (e, st) {
      try {
        level = await generateEndlessLevelAsync(_endlessStage, _rand.nextInt(1 << 31));
      } catch (e2, st2) {}
    }
    if (!mounted) return;
    if (level == null) {
      Navigator.pop(context);
      return;
    }
    _activeLevel = level;
    _game = GameController(level: _activeLevel!, progress: widget.progress, startingChances: kEndlessStartingChances);
    _updateWorld();
    _game!.addListener(_onGameStateChanged);
    _dinoMotion = DinoMotionController(
      startRow: _game!.dinoPos.x,
      startCol: _game!.dinoPos.y,
    )..attach(this);
    _particles = ParticleController()..attach(this);
    setState(() => _isLoadingFirstLevel = false);
    _checkTutorial();
    _prefetchNextStage();
    SoundManager.playBg();
    _resetFootsteps();
  }

  void _replaceGameController(GameController newController) {
    _game?.removeListener(_onGameStateChanged);
    _game?.dispose();
    _game = newController;
    _game!.addListener(_onGameStateChanged);
  }

  // ---- Tutorial ----
  void _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('tutorial_seen') ?? false;
    if (!alreadyShown && _activeLevel?.levelNumber == 1) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => TutorialDialog(
          onDismiss: () {
            Navigator.pop(context);
            _dismissTutorial();
          },
        ),
      );
    }
  }

  void _dismissTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_seen', true);
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showFloatingText(Offset globalPosition, String text, {Color color = Colors.green}) {
    final overlay = Overlay.of(context);
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => _FloatingText(
        startPosition: globalPosition,
        text: text,
        color: color,
        onComplete: () {
          entry?.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  void _showTemporaryEffect(int row, int col, String effectEmoji) {
    if (_game == null) return;
    final key = '$row,$col';
    setState(() {
      _game!.temporaryEffects[key] = effectEmoji;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _game?.temporaryEffects.remove(key);
        });
      }
    });
  }

  void _recordDailyCompletion() {
    final today = dailyKeyFor(DateTime.now());
    if (widget.progress.lastDailyDate == today) return;
    final yesterday = dailyKeyFor(DateTime.now().subtract(const Duration(days: 1)));
    if (widget.progress.lastDailyDate == yesterday) {
      widget.progress.dailyStreak += 1;
    } else {
      widget.progress.dailyStreak = 1;
    }
    widget.progress.lastDailyDate = today;
    if (widget.progress.dailyStreak > widget.progress.bestDailyStreak) {
      widget.progress.bestDailyStreak = widget.progress.dailyStreak;
    }
    widget.progress.totalPoints += 20;
    unawaited(widget.progress.save());
  }

  // ============================================================================
  // DIALOGS
  // ============================================================================
  Future<void> _showWinDialog() async {
    if (_isDialogShowing || _game == null) return;
    _isDialogShowing = true;

    final stars = _game!.starsEarned;
    final points = _game!.pointsEarned;
    final quote = _getDinoQuote(true);
    final world = _currentWorld;

    _confettiController.play();
    SoundManager.playWin();
    _particles?.shake(8);

    final dinoPos = _game!.dinoPos;
    _showTemporaryEffect(dinoPos.x, dinoPos.y - 1, 'Yummy!');

    if (_mode == GameMode.daily) {
      _recordDailyCompletion();
    }

    _idleController.stop();

    WinDialogResult? result;

    final winBody = LevelCompleteBody(
      dinoImage: _dinoTrophyImage!,
      starFilledImage: _starFilledImage!,
      starEmptyImage: _starEmptyImage!,
      earnedStars: stars,
      points: points,
      quote: quote,
      primaryColor: world.primaryColor,
      secondaryColor: world.secondaryColor,
    );

    if (_mode == GameMode.endless) {
      result = await showCartoonDialog<WinDialogResult>(
        context: context,
        world: world,
        title: '',
        backgroundImagePath: world.backgroundImagePath,
        body: winBody,
        actions: [
          CartoonButton(
            world: world,
            label: 'Continue',
            primary: true,
            icon: Icons.arrow_forward,
            onPressed: () => Navigator.pop(context, WinDialogResult.next),
          ),
        ],
      );
    } else if (_mode == GameMode.daily) {
      result = await showCartoonDialog<WinDialogResult>(
        context: context,
        world: world,
        title: '',
        backgroundImagePath: world.backgroundImagePath,
        body: winBody,
        actions: [
          CartoonButton(
            world: world,
            label: 'Done',
            primary: true,
            icon: Icons.check,
            onPressed: () => Navigator.pop(context, WinDialogResult.exit),
          ),
        ],
      );
    } else {
      // Normal mode
      final nextLevel = _activeLevel!.levelNumber + 1;
      result = await showCartoonDialog<WinDialogResult>(
        context: context,
        world: world,
        title: '',
        backgroundImagePath: world.backgroundImagePath,
        body: winBody,
        actions: [
          CartoonButton(
            world: world,
            label: nextLevel <= kMaxLevelCount ? 'Next Level' : 'Continue',
            primary: true,
            icon: Icons.play_arrow,
            onPressed: () => Navigator.pop(context, WinDialogResult.next),
          ),
          CartoonButton(
            world: world,
            label: 'Retry',
            primary: false,
            icon: Icons.refresh,
            onPressed: () => Navigator.pop(context, WinDialogResult.retry),
          ),
          CartoonButton(
            world: world,
            label: 'Exit',
            primary: false,
            icon: Icons.close,
            onPressed: () => Navigator.pop(context, WinDialogResult.exit),
          ),
        ],
      );
    }

    _confettiController.stop();
    _isDialogShowing = false;
    _isGameFinished = false;

    if (!mounted) return;

    switch (result) {
      case WinDialogResult.retry:
        _game!.retry();
        _dinoMotion?.snapTo(_game!.dinoPos.x, _game!.dinoPos.y);
        _resetAnimations();
        _currentPath.clear();
        _hoveredCells.clear();
        _resetFootsteps();
        setState(() {});
        break;

      case WinDialogResult.exit:
        Navigator.pop(context);
        break;

      case WinDialogResult.next:
        // For normal mode, pop with result so home screen can handle milestones/selfie
        if (_mode == GameMode.normal) {
          final levelNum = _activeLevel!.levelNumber;
          final currentStars = widget.progress.starsPerLevel[levelNum] ?? 0;
          if (stars > currentStars) {
            widget.progress.starsPerLevel[levelNum] = stars;
          }
          if (levelNum == widget.progress.unlockedLevel && levelNum < 50) {
            widget.progress.unlockedLevel = levelNum + 1;
          }
          widget.progress.levelsCompletedCount++;
          widget.progress.totalPoints += points;
          await widget.progress.save();
          Navigator.pop(context, {'stars': stars, 'points': points});
        } else {
          // Endless or daily – just pop
          Navigator.pop(context);
        }
        break;

      case null:
        // If the dialog was dismissed without a selection, treat as exit.
        Navigator.pop(context);
        break;
    }
  }

  Future<void> _loadNextLevel() async {
    final nextLevelNum = _activeLevel!.levelNumber + 1;
    if (nextLevelNum > kMaxLevelCount) {
      if (mounted) await _offerEndlessContinuation();
      return;
    }

    try {
      final nextLevel = await loadLevel(nextLevelNum);
      _replaceGameController(
        GameController(
          level: nextLevel,
          progress: widget.progress,
          startingChances: kStartingChances,
        ),
      );
      setState(() {
        _activeLevel = nextLevel;
        _updateWorld();
        _isGameFinished = false;
        _currentPath.clear();
        _hoveredCells.clear();
        _resetFootsteps();
      });
      _dinoMotion?.snapTo(_game!.dinoPos.x, _game!.dinoPos.y);
      _resetAnimations();
      _idleController.repeat(reverse: true);
    } catch (e) {
      _showMessage('Failed to load level $nextLevelNum. Please try again.');
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _offerEndlessContinuation() async {
    final wantsEndless = await showCartoonDialog<bool>(
      context: context,
      world: _currentWorld,
      title: '🏆 All 50 levels complete!',
      subtitle: "You've beaten every level! Want to keep going in Endless Mode?",
      iconEmoji: '🌟',
      actions: [
        CartoonButton(
          world: _currentWorld,
          label: 'Back to menu',
          primary: false,
          icon: Icons.home,
          onPressed: () => Navigator.pop(context, false),
        ),
        CartoonButton(
          world: _currentWorld,
          label: "Let's go endless!",
          primary: true,
          icon: Icons.rocket,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (!mounted) return;
    if (wantsEndless == true) {
      await _transitionToEndlessMode();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _transitionToEndlessMode() async {
    setState(() {
      _mode = GameMode.endless;
      _endlessStage = 1;
      _endlessScore = 0;
      _endlessRunSeed = _rand.nextInt(1 << 31);
      _isLoadingFirstLevel = true;
    });

    LevelConfig? level;
    try {
      level = await generateEndlessLevelAsync(_endlessStage, _endlessRunSeed);
    } catch (e, st) {
      try {
        level = await generateEndlessLevelAsync(_endlessStage, _rand.nextInt(1 << 31));
      } catch (e2, st2) {}
    }
    if (!mounted) return;
    if (level == null) {
      _showMessage('Dino needs a break! Returning to menu.');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context);
      return;
    }

    _replaceGameController(
      GameController(
        level: level,
        progress: widget.progress,
        startingChances: kEndlessStartingChances,
      ),
    );
    setState(() {
      _activeLevel = level;
      _updateWorld();
      _isGameFinished = false;
      _isLoadingFirstLevel = false;
      _currentPath.clear();
      _hoveredCells.clear();
      _resetFootsteps();
    });
    _dinoMotion?.snapTo(_game!.dinoPos.x, _game!.dinoPos.y);
    _resetAnimations();
    _idleController.repeat(reverse: true);
    _prefetchNextStage();
  }

  Future<void> _showGameOverDialog() async {
    if (_isDialogShowing || _game == null) return;
    _isDialogShowing = true;

    final world = _currentWorld;
    String? subtitle;
    if (_mode == GameMode.endless) {
      final isNewBest = _endlessStage > widget.progress.endlessBestStage ||
          (_endlessStage == widget.progress.endlessBestStage &&
              _endlessScore > widget.progress.endlessBestScore);
      if (_endlessStage > widget.progress.endlessBestStage) {
        widget.progress.endlessBestStage = _endlessStage;
      }
      if (_endlessScore > widget.progress.endlessBestScore) {
        widget.progress.endlessBestScore = _endlessScore;
      }
      unawaited(widget.progress.save());
      subtitle = isNewBest
          ? 'Reached stage $_endlessStage · $_endlessScore pts — NEW BEST!'
          : 'Reached stage $_endlessStage · $_endlessScore pts (best: stage ${widget.progress.endlessBestStage})';
    }
    final quote = _getDinoQuote(false);

    _idleController.stop();

    final result = await showCartoonDialog<WinDialogResult>(
      context: context,
      world: world,
      title: '💀 Game Over',
      subtitle: subtitle ?? quote,
      iconEmoji: '😢',
      actions: [
        CartoonButton(
          world: world,
          label: 'Retry',
          primary: true,
          icon: Icons.refresh,
          onPressed: () => Navigator.pop(context, WinDialogResult.retry),
        ),
        CartoonButton(
          world: world,
          label: 'Exit',
          primary: false,
          icon: Icons.close,
          onPressed: () => Navigator.pop(context, WinDialogResult.exit),
        ),
      ],
    );
    _isDialogShowing = false;

    if (!mounted) return;

    switch (result) {
      case WinDialogResult.retry:
        if (_mode == GameMode.endless) {
          _restartEndlessRun(resetRun: false);
        } else {
          _game!.retry();
          _isGameFinished = false;
          _dinoMotion?.snapTo(_game!.dinoPos.x, _game!.dinoPos.y);
          _resetAnimations();
          _currentPath.clear();
          _hoveredCells.clear();
          _resetFootsteps();
          setState(() {});
        }
        break;

      case WinDialogResult.exit:
      case WinDialogResult.next:
      case null:
        Navigator.pop(context);
        break;
    }
  }

  void _resetAnimations() {
    _idleController.reset();
    _idleController.repeat(reverse: true);
    _biteController.reset();
    _stepController.reset();
    _colorPulseController.reset();
    _shakeController.reset();
  }

  // ---- Drag Handling ----
  Point? _getCellFromGlobalPosition(Offset globalPosition) {
    if (_activeLevel == null) return null;
    final RenderBox? box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPosition);
    final cellSize = box.size.width / _activeLevel!.gridSize;
    final row = (local.dy / cellSize).floor();
    final col = (local.dx / cellSize).floor();
    if (row < 0 || row >= _activeLevel!.gridSize || col < 0 || col >= _activeLevel!.gridSize) {
      return null;
    }
    return Point(row, col);
  }

  List<Point> _orthogonalPath(Point a, Point b) {
    final path = <Point>[a];
    int x = a.x, y = a.y;
    while (x != b.x || y != b.y) {
      if (x < b.x) x++;
      else if (x > b.x) x--;
      else if (y < b.y) y++;
      else if (y > b.y) y--;
      path.add(Point(x, y));
    }
    return path;
  }

  static const List<Point> _kAllDirs = [Point(0,1), Point(1,0), Point(0,-1), Point(-1,0)];

  List<Point>? _findShortestPath(Point start, Point target) {
    final size = _activeLevel!.gridSize;
    final visited = <Point>{};
    final queue = Queue<List<Point>>();
    queue.add([start]);
    visited.add(start);
    while (queue.isNotEmpty) {
      final path = queue.removeFirst();
      final last = path.last;
      if (last == target) return path;
      for (final dir in _kAllDirs) {
        final next = Point(last.x + dir.x, last.y + dir.y);
        if (next.x < 0 || next.y < 0 || next.x >= size || next.y >= size) continue;
        final key = '${next.x},${next.y}';
        if (_activeLevel!.obstacles.contains(key)) continue;
        if (_game!.permanentPathCells.contains(key)) continue;
        if (next != target && _game!.checkObstacle(next.x, next.y) != null) continue;
        if (visited.contains(next)) continue;
        visited.add(next);
        final newPath = List.of(path)..add(next);
        queue.add(newPath);
      }
    }
    return null;
  }

  // ---- DRAG EVENTS ----
  void _onPanStart(DragStartDetails details) {
    if (_game == null || !_game!.isActive || _isGameFinished || _isAnimatingTapPath) return;
    final cell = _getCellFromGlobalPosition(details.globalPosition);
    if (cell == null) return;
    if (_game!.dinoPos.x != cell.x || _game!.dinoPos.y != cell.y) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.lightImpact();
    _game!.resetDrag();
    _game!.addToDragPath(cell);
    _currentPath = [cell];
    _hoveredCells.clear();
    _isDragging = true;
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_game == null || _game!.currentDragPath.isEmpty || !_game!.isActive || _isGameFinished) return;
    final newCell = _getCellFromGlobalPosition(details.globalPosition);
    if (newCell == null) return;
    final last = _game!.currentDragPath.last;
    if (last == newCell) return;

    if (last.x != newCell.x && last.y != newCell.y) return;

    final cells = _orthogonalPath(last, newCell);
    final cell = cells[1];

    if (_game!.currentDragPath.contains(cell)) {
      if (_game!.currentDragPath.length >= 2 &&
          _game!.currentDragPath[_game!.currentDragPath.length - 2] == cell) {
        _game!.removeLastFromDragPath();
        _currentPath.removeLast();
        HapticFeedback.lightImpact();
        setState(() {});
        return;
      } else {
        HapticFeedback.selectionClick();
        return;
      }
    }

    final key = '${cell.x},${cell.y}';

    if (_activeLevel!.obstacles.contains(key)) {
      HapticFeedback.selectionClick();
      SoundManager.playTreeBlock();
      _particles?.shake(3);
      _game!.resetDrag();
      _currentPath.clear();
      _recordDragFailureAndMaybeAnnounce();
      _triggerGridShake();
      _isDragging = false;
      setState(() {});
      return;
    }

    if (_game!.permanentPathCells.contains(key)) {
      HapticFeedback.selectionClick();
      _particles?.shake(2);
      _game!.resetDrag();
      _currentPath.clear();
      _recordDragFailureAndMaybeAnnounce();
      _triggerGridShake();
      _isDragging = false;
      setState(() {});
      return;
    }

    if (_game!.isUncollectedChocolate(cell.x, cell.y)) {
      _addFootstep(last, cell);
      _game!.addToDragPath(cell);
      _currentPath.add(cell);
      _stepController.forward(from: 0);
      _biteController.forward(from: 0);
      _colorPulseController.forward(from: 0);
      HapticFeedback.mediumImpact();
      SoundManager.playEat();
      _particles?.burst(
        Offset(cell.y * _cellSize + _cellSize / 2, cell.x * _cellSize + _cellSize / 2),
        color: Colors.amber,
        count: 40,
      );
      _revealHiddenEnemiesNear(cell);
      _game!.collectChocolate(cell);
      _maybeShowLuckyChocolatePopup(cell);

      if (_game!.hasWon) {
        _handleWin();
        _isDragging = false;
        return;
      }
      _showMessage('Yum! ${_game!.collectedChocolateKeys.length}/${_activeLevel!.chocolates.length} collected.');
      _game!.reseedDragAt(cell);
      _currentPath = [cell];
      setState(() {});
      return;
    }

    final obstacle = _game!.checkObstacle(cell.x, cell.y);
    if (obstacle != null) {
      _handleObstacle(obstacle, cell);
      setState(() {});
      return;
    }

    _addFootstep(last, cell);
    _game!.addToDragPath(cell);
    _currentPath.add(cell);
    _stepController.forward(from: 0);
    HapticFeedback.lightImpact();
    _revealHiddenEnemiesNear(cell);
    _maybeCollectBonus(cell);
    _hoveredCells['$key'] = true;
    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    if (_game == null || _game!.currentDragPath.isEmpty || !_game!.isActive || _isGameFinished) {
      _game?.resetDrag();
      _currentPath.clear();
      _hoveredCells.clear();
      setState(() {});
      return;
    }
    final last = _game!.currentDragPath.last;
    if (_game!.isUncollectedChocolate(last.x, last.y)) {
      _game!.collectChocolate(last);
      _biteController.forward(from: 0);
      _colorPulseController.forward(from: 0);
      HapticFeedback.mediumImpact();
      SoundManager.playEat();
      _particles?.burst(
        Offset(last.y * _cellSize + _cellSize / 2, last.x * _cellSize + _cellSize / 2),
        color: Colors.amber,
        count: 40,
      );
      _maybeShowLuckyChocolatePopup(last);

      if (_game!.hasWon) {
        _handleWin();
      } else {
        _showMessage('Yum! ${_game!.collectedChocolateKeys.length}/${_activeLevel!.chocolates.length} collected.');
      }
      _currentPath.clear();
      _hoveredCells.clear();
      setState(() {});
    } else {
      _game!.resetDrag();
      _currentPath.clear();
      _hoveredCells.clear();
      setState(() {});
    }
    _displayStars = _game!.starsEarned;
  }

  Future<void> _onTapGrid(TapDownDetails details) async {
    if (_game == null || !_game!.isActive || _isGameFinished || _isAnimatingTapPath) return;
    if (_game!.currentDragPath.isNotEmpty) return;
    final cell = _getCellFromGlobalPosition(details.globalPosition);
    if (cell == null) return;
    if (!_game!.isUncollectedChocolate(cell.x, cell.y)) return;

    if (!_game!.tapAssistUnlocked && !widget.progress.tapAssistAlwaysOn) {
      final remaining = kTapAssistUnlockThreshold - _game!.dragFailureCount;
      _showMessage('Draw the path yourself! Tap-assist unlocks after $remaining more slip-up${remaining == 1 ? '' : 's'}.');
      HapticFeedback.selectionClick();
      return;
    }

    final path = _findShortestPath(_game!.dinoPos, cell);
    if (path == null || path.length <= 1) {
      _showMessage('No valid path found!');
      return;
    }

    _game!.resetDrag();
    _isAnimatingTapPath = true;
    _isDragging = true;
    try {
      for (int i = 1; i < path.length; i++) {
        if (!mounted || _game == null || !_game!.isActive) return;
        _addFootstep(path[i - 1], path[i]);
        _game!.addToDragPath(path[i]);
        _currentPath.add(path[i]);
        _stepController.forward(from: 0);
        HapticFeedback.selectionClick();
        _maybeCollectBonus(path[i]);
        _revealHiddenEnemiesNear(path[i]);
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 130));
      }

      if (!mounted || _game == null) return;
      final target = path.last;
      if (_game!.isUncollectedChocolate(target.x, target.y)) {
        _game!.collectChocolate(target);
        _biteController.forward(from: 0);
        _colorPulseController.forward(from: 0);
        HapticFeedback.mediumImpact();
        SoundManager.playEat();
        _particles?.burst(
          Offset(target.y * _cellSize + _cellSize / 2, target.x * _cellSize + _cellSize / 2),
          color: Colors.amber,
          count: 40,
        );
        _maybeShowLuckyChocolatePopup(target);

        if (_game!.hasWon) {
          _handleWin();
        } else {
          _showMessage('Yum! ${_game!.collectedChocolateKeys.length}/${_activeLevel!.chocolates.length} collected.');
        }
      }
    } finally {
      _isAnimatingTapPath = false;
      _isDragging = false;
      _currentPath.clear();
      _hoveredCells.clear();
      setState(() {});
      _displayStars = _game!.starsEarned;
    }
  }

  // ----- Helper methods -----
  void _recordDragFailureAndMaybeAnnounce() {
    if (_game == null) return;
    final wasUnlocked = _game!.tapAssistUnlocked;
    _game!.recordDragFailure();
    if (!wasUnlocked && _game!.tapAssistUnlocked) {
      _showMessage('💡 Tap-assist unlocked! Tap a chocolate to auto-path there.');
    }
  }

  void _maybeShowLuckyChocolatePopup(Point cell) {
    if (_game == null || _game!.lastLuckyBonus <= 0) return;
    HapticFeedback.heavyImpact();
    _showTemporaryEffect(cell.x, cell.y, '🍀 +${_game!.lastLuckyBonus}');
    _particles?.burst(
      Offset(cell.y * _cellSize + _cellSize / 2, cell.x * _cellSize + _cellSize / 2),
      color: Colors.greenAccent,
    );
  }

  void _maybeCollectBonus(Point cell) {
    if (_game == null) return;
    if (!_game!.collectBonus(cell.x, cell.y)) return;

    final RenderBox? box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final cellSize = box.size.width / _activeLevel!.gridSize;
      final localOffset = Offset(
        cell.y * cellSize + cellSize / 2,
        cell.x * cellSize + cellSize / 2,
      );
      final globalOffset = box.localToGlobal(localOffset);
      _showFloatingText(globalOffset, '+5 🎁', color: const Color(0xFFFFD700));
    }

    setState(() {});
    _showTemporaryEffect(cell.x, cell.y, '🎁');
    HapticFeedback.mediumImpact();
    SoundManager.playEat();
  }

  void _revealHiddenEnemiesNear(Point center) {
    if (_activeLevel!.hiddenEnemies.isEmpty) return;
    final neighbors = [
      center,
      Point(center.x - 1, center.y),
      Point(center.x + 1, center.y),
      Point(center.x, center.y - 1),
      Point(center.x, center.y + 1),
    ];
    for (final p in neighbors) {
      final key = '${p.x},${p.y}';
      if (_activeLevel!.hiddenEnemies.contains(key) &&
          !_revealedHiddenEnemies.contains(key)) {
        _revealedHiddenEnemies.add(key);
        _showTemporaryEffect(p.x, p.y, '👀');
        HapticFeedback.mediumImpact();
      }
    }
  }

  void _handleObstacle(ObstacleEffect effect, Point cell) {
    String effectEmoji, message;
    Color fxColor;
    switch (effect) {
      case ObstacleEffect.mine:
        effectEmoji = '💥';
        message = 'Mine triggered. Lose 1 chance.';
        fxColor = Colors.orange;
        break;
      case ObstacleEffect.enemy:
        effectEmoji = '🗡️💥';
        message = 'Guard blocked you. Lose 2 chances.';
        fxColor = Colors.redAccent;
        break;
      case ObstacleEffect.hazard:
        effectEmoji = '🔥💥';
        message = 'Fire hazard. Lose 2 chances and 10 points.';
        fxColor = Colors.deepOrange;
        break;
    }
    _showTemporaryEffect(cell.x, cell.y, effectEmoji);
    _showMessage(message);
    HapticFeedback.heavyImpact();
    SoundManager.playHit();
    _particles?.explosion(
      Offset(cell.y * _cellSize + _cellSize / 2, cell.x * _cellSize + _cellSize / 2),
      color: fxColor,
    );
    _game!.applyObstacleEffect(effect, cell.x, cell.y);
    _triggerGridShake();
    _showRedFlash();
    if (_game!.chances <= 0) {
      _isDragging = false;
      _currentPath.clear();
      _hoveredCells.clear();
      setState(() {});
      return;
    }
    _game!.resetDrag();
    _currentPath.clear();
    _hoveredCells.clear();
    _recordDragFailureAndMaybeAnnounce();
    _isDragging = false;
    setState(() {});
  }

  void _triggerGridShake() {
    _shakeController
      ..reset()
      ..forward();
  }

  void _showRedFlash() {
    setState(() {
      _redFlashOpacity = 0.4;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _redFlashOpacity = 0.0;
        });
      }
    });
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    if (_isLoadingFirstLevel || _activeLevel == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF2E7D32),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'Generating your next challenge...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                label: const Text('Cancel', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final eatenChocolateKeys = _getEatenChocolateKeys();
    final pathProgress = _game!.collectedChocolateKeys.length / _activeLevel!.chocolates.length;
    final uncollectedBonuses = _activeLevel!.bonusItems.difference(_game!.collectedBonuses);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildWorldBackground(),
          // ---- Grid (full screen) ----
          Center(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: _currentWorld.primaryColor.withOpacity(0.4),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _currentWorld.primaryColor.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _currentWorld.primaryColor,
                        _currentWorld.secondaryColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      onTapDown: _onTapGrid,
                      child: AnimatedBuilder(
                        animation: _particles ?? AlwaysStoppedAnimation(0),
                        builder: (context, child) => AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(_shakeAnimation.value, 0),
                            child: child,
                          ),
                          child: child,
                        ),
                        child: Container(
                          key: _gridKey,
                          padding: const EdgeInsets.all(8),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final boardSize = constraints.maxWidth;
                              final cellSize = boardSize / _activeLevel!.gridSize;
                              _cellSize = cellSize;
                              return RepaintBoundary(
                                child: Stack(
                                  children: [
                                    CustomPaint(
                                      size: Size(boardSize, boardSize),
                                      painter: GridPainter(
                                        gridSize: _activeLevel!.gridSize,
                                        cellSize: cellSize,
                                        grid: _game!.grid,
                                        permanentPath: _game!.permanentPathCells,
                                        currentDragPath: _game!.currentDragPath,
                                        nextChocolate: null,
                                        lastConnected: null,
                                        chocolateSkin: widget.progress.selectedChocolateSkin,
                                        hat: widget.progress.selectedHat,
                                        obstacles: _activeLevel!.obstacles,
                                        mines: _activeLevel!.mines,
                                        enemies: _activeLevel!.enemies.where((key) =>
                                            !_activeLevel!.hiddenEnemies.contains(key) ||
                                            _revealedHiddenEnemies.contains(key)).toSet(),
                                        hazards: _activeLevel!.hazards,
                                        detours: _activeLevel!.detours,
                                        bonusItems: uncollectedBonuses,
                                        temporaryEffects: _game!.temporaryEffects,
                                        dangerMap: _activeLevel!.dangerMap,
                                        world: _currentWorld,
                                        animationValue: _idleController.value,
                                        sweetEmoji: _collectibleEmoji,
                                        eatenChocolates: eatenChocolateKeys,
                                        pathProgress: pathProgress,
                                        chocolateImage: _currentSweetImage,
                                        obstacleImages: _obstacleImages,
                                        showNextChocolateHint: false,
                                        obstacleKey: _currentWorld.obstacleKey,
                                        hoveredCells: _hoveredCells,
                                      ),
                                    ),
                                    // Footsteps
                                    if (_footLeftImage != null && _footRightImage != null)
                                      CustomPaint(
                                        painter: FootstepPainter(
                                          _footsteps,
                                          cellSize,
                                          _footLeftImage!,
                                          _footRightImage!,
                                        ),
                                        size: Size(boardSize, boardSize),
                                      ),
                                    _buildDino(cellSize),
                                    if (_particles != null)
                                      AnimatedBuilder(
                                        animation: _particles!,
                                        builder: (context, _) => CustomPaint(
                                          size: Size(boardSize, boardSize),
                                          painter: PhysicsParticlePainter(_particles!.particles),
                                        ),
                                      ),
                                    if (_redFlashOpacity > 0)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Container(
                                            color: Colors.red.withOpacity(_redFlashOpacity),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ---- FLOATING BACK BUTTON (top-left) ----
          Positioned(
            top: 20,
            left: 16,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Exit level',
                ),
              ),
            ),
          ),
          // ---- FLOATING SOUND TOGGLE (top-right) ----
          Positioned(
            top: 20,
            right: 16,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    SoundManager.muted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () async {
                    await SoundManager.toggleMute();
                    setState(() {}); // Update icon
                  },
                  tooltip: SoundManager.muted ? 'Unmute' : 'Mute',
                ),
              ),
            ),
          ),
          // ---- FLOATING STATS CHIP (bottom-right) ----
          Positioned(
            bottom: 32,
            right: 16,
            child: _StatsChip(
              chances: _game!.chances,
              chocolatesCollected: _game!.collectedChocolateKeys.length,
              totalChocolates: _activeLevel!.chocolates.length,
              bonusPoints: _game!.bonusPointsThisLevel,
              stars: _game!.starsEarned,
              points: _game!.pointsEarned,
              world: _currentWorld,
              tapAssistAlwaysOn: widget.progress.tapAssistAlwaysOn,
              onTapAssistToggle: () async {
                setState(() {
                  widget.progress.tapAssistAlwaysOn = !widget.progress.tapAssistAlwaysOn;
                });
                await widget.progress.save();
                _showMessage(widget.progress.tapAssistAlwaysOn
                    ? '📌 Tap‑assist is now always available.'
                    : '✏️ Tap‑assist will unlock after a few slip‑ups.');
              },
              soundMuted: SoundManager.muted,
              onSoundToggle: SoundManager.toggleMute,
            ),
          ),
          // ---- Bottom hint text ----
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Drag to draw a path · Tap a chocolate for the shortest route',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // ---- Confetti ----
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorldBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final offset = _bgController.value * 300;
        if (_backgroundImage != null) {
          final panX = offset * 0.04;
          return Positioned.fill(
            child: ClipRect(
              child: Transform.translate(
                offset: Offset(panX, 0),
                child: Transform.scale(
                  scale: 1.1,
                  child: RawImage(
                    image: _backgroundImage!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          );
        } else {
          final primary = _currentWorld.primaryColor.withOpacity(0.12);
          final secondary = _currentWorld.secondaryColor.withOpacity(0.08);
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, secondary],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MountainPainter(
                      color: _currentWorld.primaryColor.withOpacity(0.1),
                      offset: offset * 0.2,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TreePainter(
                      color: _currentWorld.secondaryColor.withOpacity(0.08),
                      offset: offset * 0.5,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CloudPainter(
                      color: Colors.white.withOpacity(0.08),
                      offset: offset * 1.2,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildDino(double cellSize) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _idleController,
        _biteController,
        _stepController,
        _colorPulseController,
        if (_dinoMotion != null) _dinoMotion!,
      ]),
      builder: (context, child) {
        double scale = 1.0;
        if (_biteController.isAnimating) {
          scale = 1.0 + _biteController.value * 0.5;
        } else if (_stepController.isAnimating) {
          scale = 1.0 + _stepController.value * 0.3;
        }
        final hopLift = (_dinoMotion?.hopHeight ?? 0) * cellSize * 0.35;

        final totalChocolates = _activeLevel!.chocolates.length;
        final eaten = _game!.collectedChocolateKeys.length;
        final progress = totalChocolates > 0 ? eaten / totalChocolates : 0.0;
        final sizeFactor = 0.6 + 0.35 * progress;

        final progressTint = progress * 0.55;
        final biteFlash = (1 - _colorPulseController.value).clamp(0.0, 1.0) * 0.4;
        final tintOpacity = (progressTint + biteFlash).clamp(0.0, 0.85);

        ui.Image? image;
        if (_game!.currentDragPath.isNotEmpty || _stepController.isAnimating) {
          image = _dinoWalkImage;
        } else if (_biteController.isAnimating) {
          image = _dinoEatImage;
        } else {
          image = _dinoIdleImage;
        }

        Widget dino;
        if (_imagesLoaded && image != null) {
          dino = RawImage(
            image: image,
            width: cellSize * sizeFactor,
            height: cellSize * sizeFactor,
            fit: BoxFit.contain,
          );
        } else {
          dino = Text(
            _game!.currentDragPath.isNotEmpty ? '🦖' : '🦕',
            style: TextStyle(fontSize: cellSize * 0.7),
          );
        }

        if (tintOpacity > 0.01 && image != null) {
          dino = ColorFiltered(
            colorFilter: ColorFilter.mode(
              const Color(0xFF5D3A1A).withOpacity(tintOpacity),
              BlendMode.srcATop,
            ),
            child: dino,
          );
        }

        final dinoWithGlow = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(child: dino),
        );

        return Positioned(
          left: (_dinoMotion?.col ?? 0) * cellSize,
          top: (_dinoMotion?.row ?? 0) * cellSize - hopLift,
          width: cellSize,
          height: cellSize,
          child: Transform.rotate(
            angle: _dinoLean, // <-- NEW: visual tilt
            child: Transform.scale(
              scale: scale,
              child: Transform.translate(
                offset: Offset(0, _bobAnimation.value),
                child: dinoWithGlow,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// POLISHED STATS CHIP & SHEET (unchanged)
// ============================================================================

class _StatsChip extends StatefulWidget {
  final int chances;
  final int chocolatesCollected;
  final int totalChocolates;
  final int bonusPoints;
  final int stars;
  final int points;
  final SweetWorld world;
  final bool tapAssistAlwaysOn;
  final VoidCallback onTapAssistToggle;
  final bool soundMuted;
  final VoidCallback onSoundToggle;

  const _StatsChip({
    required this.chances,
    required this.chocolatesCollected,
    required this.totalChocolates,
    required this.bonusPoints,
    required this.stars,
    required this.points,
    required this.world,
    required this.tapAssistAlwaysOn,
    required this.onTapAssistToggle,
    required this.soundMuted,
    required this.onSoundToggle,
  });

  @override
  State<_StatsChip> createState() => _StatsChipState();
}

class _StatsChipState extends State<_StatsChip> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showStatsSheet(context),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.red, size: 20),
                  const SizedBox(width: 4),
                  Text('${widget.chances}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
                      )),
                  const SizedBox(width: 12),
                  const Text('🍫', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 4),
                  Text('${widget.chocolatesCollected}/${widget.totalChocolates}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
                      )),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_drop_up, color: Colors.white70, size: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showStatsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, -8)),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) => Icon(
                  i < widget.stars ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 40,
                )),
              ),
              const SizedBox(height: 8),
              Text('${widget.points} points',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
              const Divider(height: 32, color: Colors.white24),
              // Stats grid
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _StatItem(
                    icon: Icons.favorite,
                    color: Colors.red,
                    label: 'Chances',
                    value: '${widget.chances}',
                  ),
                  _StatItem(
                    icon: Icons.emoji_events,
                    color: Colors.amber,
                    label: 'Collected',
                    value: '${widget.chocolatesCollected}/${widget.totalChocolates}',
                  ),
                  if (widget.bonusPoints > 0)
                    _StatItem(
                      icon: Icons.card_giftcard,
                      color: Colors.green,
                      label: 'Bonus',
                      value: '+${widget.bonusPoints}',
                    ),
                  _StatItem(
                    icon: widget.soundMuted ? Icons.volume_off : Icons.volume_up,
                    color: widget.soundMuted ? Colors.grey : Colors.blue,
                    label: 'Sound',
                    value: widget.soundMuted ? 'Off' : 'On',
                    onTap: widget.onSoundToggle,
                  ),
                  _StatItem(
                    icon: widget.tapAssistAlwaysOn ? Icons.touch_app : Icons.touch_app_outlined,
                    color: widget.tapAssistAlwaysOn ? Colors.amber : Colors.grey,
                    label: 'Tap Assist',
                    value: widget.tapAssistAlwaysOn ? 'On' : 'Off',
                    onTap: widget.onTapAssistToggle,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Background painters (unchanged) ----
class _MountainPainter extends CustomPainter {
  final Color color;
  final double offset;
  _MountainPainter({required this.color, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    final h = size.height;
    final w = size.width;
    path.moveTo(0, h);
    final peaks = [
      Offset(0.1 * w + offset * 0.1, h * 0.55),
      Offset(0.25 * w + offset * 0.15, h * 0.3),
      Offset(0.45 * w + offset * 0.05, h * 0.45),
      Offset(0.65 * w + offset * 0.12, h * 0.2),
      Offset(0.85 * w + offset * 0.08, h * 0.4),
      Offset(1.0 * w + offset * 0.1, h * 0.5),
    ];
    path.moveTo(peaks[0].dx, peaks[0].dy);
    for (int i = 1; i < peaks.length; i++) {
      path.quadraticBezierTo(
        (peaks[i - 1].dx + peaks[i].dx) / 2,
        (peaks[i - 1].dy + peaks[i].dy) / 2 - 20,
        peaks[i].dx,
        peaks[i].dy,
      );
    }
    path.lineTo(w, h);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MountainPainter oldDelegate) => oldDelegate.offset != offset;
}

class _TreePainter extends CustomPainter {
  final Color color;
  final double offset;
  _TreePainter({required this.color, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final treePositions = [
      Offset(0.05 * size.width + offset * 0.3, size.height * 0.75),
      Offset(0.15 * size.width + offset * 0.4, size.height * 0.8),
      Offset(0.8 * size.width + offset * 0.2, size.height * 0.7),
      Offset(0.9 * size.width + offset * 0.5, size.height * 0.85),
    ];
    for (var pos in treePositions) {
      final path = Path()
        ..moveTo(pos.dx, pos.dy - 30)
        ..lineTo(pos.dx - 15, pos.dy)
        ..lineTo(pos.dx + 15, pos.dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TreePainter oldDelegate) => oldDelegate.offset != offset;
}

class _CloudPainter extends CustomPainter {
  final Color color;
  final double offset;
  _CloudPainter({required this.color, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final cloudCenters = [
      Offset(0.1 * size.width + offset * 0.8, size.height * 0.15),
      Offset(0.4 * size.width + offset * 0.5, size.height * 0.08),
      Offset(0.7 * size.width + offset * 0.9, size.height * 0.12),
    ];
    for (var center in cloudCenters) {
      final r = 20.0;
      for (int i = 0; i < 6; i++) {
        final angle = i * 2 * pi / 6;
        final dx = r * cos(angle);
        final dy = r * sin(angle) * 0.6;
        canvas.drawCircle(center + Offset(dx, dy), r * 0.7, paint);
      }
      canvas.drawCircle(center, r * 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) => oldDelegate.offset != offset;
}