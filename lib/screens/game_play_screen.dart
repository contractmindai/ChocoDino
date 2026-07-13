import 'dart:async';
import 'dart:math' hide Point;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/level_config.dart';
import '../models/player_progress.dart';
import '../models/point.dart';
import '../models/sweet_world.dart';
import '../models/chocolate.dart';
import '../data/daily_challenge.dart';
import '../data/endless_generator.dart';
import '../data/levels.dart';
import '../utils/sound_manager.dart';
import '../widgets/grid_painter.dart';
import '../widgets/logo.dart';
import '../widgets/particle_system.dart';
import '../widgets/physics_motion.dart';
import '../widgets/loading_mini_game.dart';

// --- Constants & Enums ---
enum CellType { empty, chocolate }
const String kEmptyCell = 'empty';
const String kChocolateCell = 'chocolate';

enum ObstacleEffect { mine, enemy, hazard }
enum GameMode { normal, daily, endless }

const int kEndlessStartingChances = 5;

// List of sweet emojis – fallback default
const List<String> kSweetEmojis = ['🍫', '🍬', '🍭', '🧁', '🍩', '🍪', '🎂', '🍰'];

// ==================== GAME CONTROLLER ====================
class GameController extends ChangeNotifier {
  final LevelConfig level;
  final PlayerProgress progress;
  final int startingChances;
  final Map<int, Point> _chocolateOrderMap = {};

  List<List<String>> grid = [];
  List<String> permanentPathCells = [];
  Set<int> connectedOrders = {};
  int nextOrder = 1;
  int chances = 5;
  bool gameActive = true;
  bool win = false;
  Point dinoPos = const Point(0, 0);
  List<Point> currentDragPath = [];
  Map<String, String> temporaryEffects = {};

  // ---- FIXED: default starting chances = 5 ----
  GameController({required this.level, required this.progress, this.startingChances = 5}) {
    _initLevel();
  }

  void _initLevel() {
    final size = level.gridSize;
    grid = List.generate(size, (_) => List.filled(size, kEmptyCell));
    for (final choc in level.chocolates) {
      grid[choc.row][choc.col] = kChocolateCell;
      _chocolateOrderMap[choc.order] = Point(choc.row, choc.col);
    }
    final first = level.chocolates.first;
    connectedOrders = {1};
    permanentPathCells = ['${first.row},${first.col}'];
    nextOrder = 2;
    chances = startingChances;
    gameActive = true;
    win = false;
    dinoPos = Point(first.row, first.col);
    currentDragPath = [];
    temporaryEffects.clear();
    notifyListeners();
  }

  void retry() {
    _initLevel();
    notifyListeners();
  }

  Point? getChocolateCoord(int order) => _chocolateOrderMap[order];
  Point? getLastConnectedCoord() {
    if (connectedOrders.isEmpty) return null;
    final maxOrder = connectedOrders.reduce((a, b) => a > b ? a : b);
    return getChocolateCoord(maxOrder);
  }

  bool isNextChocolate(int row, int col) {
    final coord = getChocolateCoord(nextOrder);
    return coord != null && coord.x == row && coord.y == col;
  }

  ObstacleEffect? checkObstacle(int row, int col) {
    final key = '$row,$col';
    if (level.mines.contains(key)) return ObstacleEffect.mine;
    if (level.enemies.contains(key)) return ObstacleEffect.enemy;
    if (level.hazards.contains(key)) return ObstacleEffect.hazard;
    return null;
  }

  bool isObstacleCell(int row, int col) => checkObstacle(row, col) != null;
  bool isAdjacent(Point a, Point b) => (a.x - b.x).abs() + (a.y - b.y).abs() == 1;

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

  void correctConnect(Point target) {
    for (final p in currentDragPath) {
      permanentPathCells.add('${p.x},${p.y}');
    }
    connectedOrders.add(nextOrder);
    dinoPos = target;
    currentDragPath = [];

    if (nextOrder == level.chocolates.length) {
      win = true;
      gameActive = false;
    } else {
      nextOrder++;
    }
    notifyListeners();
  }

  void addToDragPath(Point cell) {
    if (currentDragPath.isNotEmpty && currentDragPath.last == cell) return;
    currentDragPath.add(cell);
    dinoPos = cell;
    notifyListeners();
  }

  void removeLastFromDragPath() {
    if (currentDragPath.length >= 2) {
      currentDragPath.removeLast();
      dinoPos = currentDragPath.last;
      notifyListeners();
    }
  }

  void resetDrag() {
    currentDragPath = [];
    notifyListeners();
  }

  bool get hasWon => win;
  bool get isActive => gameActive && !win;

  // ---- FIXED: generous star calculation ----
  int get starsEarned {
    if (chances >= 3) return 3;
    if (chances >= 2) return 2;
    if (chances >= 1) return 1;
    return 0;
  }

  int get pointsEarned => starsEarned == 3 ? 30 : starsEarned == 2 ? 25 : 20;
}

// ==================== CUTE GLASSMORPHISM DIALOGS ====================

class _TutorialDialog extends StatelessWidget {
  final VoidCallback onDismiss;
  const _TutorialDialog({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade100, Colors.pink.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🦕', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 12),
            const Text(
              'Touch Rex and drag to draw a path to the next chocolate!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Watch out for 🌳 trees, 💣 mines, 🗡️ guards and 🔥 fire!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.brown),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onDismiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                elevation: 5,
              ),
              child: const Text('GOT IT!', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

class _WinDialog extends StatelessWidget {
  final int stars;
  final int points;
  final String? subtitle;
  final String quote;
  final VoidCallback onContinue;

  const _WinDialog({
    required this.stars,
    required this.points,
    this.subtitle,
    required this.quote,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE082), Color(0xFFFF8A65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10)),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 60)),
            const Text('LEVEL COMPLETE!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                  letterSpacing: 1.5,
                )),
            const SizedBox(height: 6),
            Text(quote,
                style: const TextStyle(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: Colors.brown,
                ),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber.shade800,
                  size: 44,
                ),
              )),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Text('+$points POINTS',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                  )),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(subtitle!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                  )),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                elevation: 5,
              ),
              child: const Text('CONTINUE', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameOverDialog extends StatelessWidget {
  final String dinoName;
  final String? subtitle;
  final String quote;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  const _GameOverDialog({
    required this.dinoName,
    this.subtitle,
    required this.quote,
    required this.onRetry,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFB3E5FC), Color(0xFF81D4FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10)),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😢', style: TextStyle(fontSize: 60)),
            const Text('GAME OVER',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                  letterSpacing: 1.5,
                )),
            const SizedBox(height: 6),
            Text(quote,
                style: const TextStyle(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: Colors.brown,
                ),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('$dinoName ran out of chances!',
                style: const TextStyle(fontSize: 16, color: Colors.brown)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  )),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.brown,
                      side: const BorderSide(color: Colors.brown, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('RETRY', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onExit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 4,
                    ),
                    child: const Text('EXIT', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MAIN GAME SCREEN ====================
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
  late GameController _game;
  bool _showTutorial = false;
  bool _isDialogShowing = false;
  bool _isGameFinished = false;
  bool _isLoadingNextLevel = false;

  late LevelConfig _activeLevel;
  late SweetWorld _currentWorld;
  late String _collectibleEmoji;

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

  late DinoMotionController _dinoMotion;
  late ParticleController _particles;
  double _cellSize = 1;

  final GlobalKey _gridKey = GlobalKey();

  late AnimationController _bgController;

  // ---- Image assets ----
  ui.Image? _chocolateImage;
  ui.Image? _dinoIdleImage;
  ui.Image? _dinoWalkImage;
  ui.Image? _dinoEatImage;
  bool _imagesLoaded = false;

  // ---- Cache for eaten chocolate keys ----
  Set<String>? _cachedEatenKeys;
  int _lastConnectedCount = -1;

  Set<String> _getEatenChocolateKeys() {
    final count = _game.connectedOrders.length;
    if (_lastConnectedCount != count) {
      _cachedEatenKeys = _game.connectedOrders
          .map((order) {
            final coord = _game.getChocolateCoord(order);
            return coord != null ? '${coord.x},${coord.y}' : '';
          })
          .where((s) => s.isNotEmpty)
          .toSet();
      _lastConnectedCount = count;
    }
    return _cachedEatenKeys!;
  }

  // ---- Personality quotes ----
  String _getDinoQuote(bool isWin) {
    final winQuotes = [
      'Yummy! That was delicious! 🦕',
      'More chocolate, please!',
      'Rex is happy! 🎉',
      'Best snack ever!',
    ];
    final loseQuotes = [
      'Oops! Let\'s try another path.',
      'Rex needs more practice!',
      'Almost had it! Try again.',
      'Dino is sad... 😢',
    ];
    final list = isWin ? winQuotes : loseQuotes;
    return list[Random().nextInt(list.length)];
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    SoundManager.addListener(_onSoundChanged);

    _collectibleEmoji = kSweetEmojis.isNotEmpty ? kSweetEmojis[0] : '🍫';

    // Load images
    _loadImages();

    if (widget.mode == GameMode.endless) {
      _endlessRunSeed = Random().nextInt(1 << 31);
      _isLoadingFirstLevel = true;
      _loadFirstEndlessLevel();
    } else {
      _activeLevel = widget.level!;
      // ---- FIXED: pass 5 starting chances ----
      _game = GameController(level: _activeLevel, progress: widget.progress, startingChances: 5);
      _updateWorld();
      _game.addListener(_onGameStateChanged);
      _dinoMotion = DinoMotionController(
        startRow: _game.dinoPos.x,
        startCol: _game.dinoPos.y,
      )..attach(this);
      _particles = ParticleController()..attach(this);
      _checkTutorial();
      SoundManager.playBg();
    }
  }

  Future<void> _loadImages() async {
    try {
      // Load chocolate image (optional)
      final chocolateData = await rootBundle.load('assets/images/chocolate.png');
      final chocolateCodec = await ui.instantiateImageCodec(chocolateData.buffer.asUint8List());
      final chocolateFrame = await chocolateCodec.getNextFrame();
      _chocolateImage = chocolateFrame.image;

      // Load dino idle
      final idleData = await rootBundle.load('assets/dino/idle.png');
      final idleCodec = await ui.instantiateImageCodec(idleData.buffer.asUint8List());
      final idleFrame = await idleCodec.getNextFrame();
      _dinoIdleImage = idleFrame.image;

      // Load dino walk (if available, else reuse idle)
      try {
        final walkData = await rootBundle.load('assets/dino/walk.png');
        final walkCodec = await ui.instantiateImageCodec(walkData.buffer.asUint8List());
        final walkFrame = await walkCodec.getNextFrame();
        _dinoWalkImage = walkFrame.image;
      } catch (_) {
        _dinoWalkImage = _dinoIdleImage; // fallback to idle
      }

      // Load dino eat (if available, else reuse idle)
      try {
        final eatData = await rootBundle.load('assets/dino/eat.png');
        final eatCodec = await ui.instantiateImageCodec(eatData.buffer.asUint8List());
        final eatFrame = await eatCodec.getNextFrame();
        _dinoEatImage = eatFrame.image;
      } catch (_) {
        _dinoEatImage = _dinoIdleImage; // fallback to idle
      }

      if (mounted) setState(() => _imagesLoaded = true);
    } catch (e) {
      debugPrint('Image loading failed: $e');
      if (mounted) setState(() => _imagesLoaded = true); // fallback to emoji
    }
  }

  @override
  void dispose() {
    SoundManager.removeListener(_onSoundChanged);
    if (!_isLoadingFirstLevel) {
      _game.removeListener(_onGameStateChanged);
      _game.dispose();
      _dinoMotion.dispose();
      _particles.dispose();
    }
    _idleController.dispose();
    _biteController.dispose();
    _stepController.dispose();
    _colorPulseController.dispose();
    _confettiController.dispose();
    _bgController.dispose();
    SoundManager.stopBg();
    super.dispose();
  }

  void _onSoundChanged() {
    if (mounted) setState(() {});
  }

  String _pickRandomSweet() {
    if (kSweetEmojis.isEmpty) return '🍫';
    return kSweetEmojis[Random().nextInt(kSweetEmojis.length)];
  }

  Future<void> _loadFirstEndlessLevel() async {
    LevelConfig? level;
    try {
      level = await generateEndlessLevelAsync(_endlessStage, _endlessRunSeed);
    } catch (e, st) {
      debugPrint('Endless first-level generation failed: $e\n$st');
      try {
        level = await generateEndlessLevelAsync(_endlessStage, Random().nextInt(1 << 31));
      } catch (e2, st2) {
        debugPrint('Retry also failed: $e2\n$st2');
      }
    }
    if (!mounted) return;
    if (level == null) {
      Navigator.pop(context);
      return;
    }
    _activeLevel = level;
    _game = GameController(
      level: _activeLevel,
      progress: widget.progress,
      startingChances: kEndlessStartingChances,
    );
    _updateWorld();
    _game.addListener(_onGameStateChanged);
    _dinoMotion = DinoMotionController(
      startRow: _game.dinoPos.x,
      startCol: _game.dinoPos.y,
    )..attach(this);
    _particles = ParticleController()..attach(this);
    setState(() => _isLoadingFirstLevel = false);
    _checkTutorial();
    _prefetchNextStage();
    SoundManager.playBg();
  }

  void _prefetchNextStage() {
    if (widget.mode != GameMode.endless) return;
    _prefetchedNextLevel = generateEndlessLevelAsync(_endlessStage + 1, _endlessRunSeed);
  }

  Future<void> _restartEndlessRun({bool resetRun = true}) async {
    if (resetRun) {
      setState(() => _isLoadingFirstLevel = true);
      _endlessStage = 1;
      _endlessScore = 0;
      _endlessRunSeed = Random().nextInt(1 << 31);
      _prefetchedNextLevel = null;
    } else {
      setState(() => _isLoadingFirstLevel = true);
      _prefetchedNextLevel = null;
    }

    LevelConfig? level;
    try {
      level = await generateEndlessLevelAsync(_endlessStage, _endlessRunSeed);
    } catch (e, st) {
      debugPrint('Endless restart generation failed: $e\n$st');
      try {
        level = await generateEndlessLevelAsync(_endlessStage, Random().nextInt(1 << 31));
      } catch (e2, st2) {
        debugPrint('Retry also failed: $e2\n$st2');
      }
    }
    if (!mounted) return;
    if (level == null) {
      Navigator.pop(context);
      return;
    }

    _game.removeListener(_onGameStateChanged);
    _game.dispose();
    setState(() {
      _activeLevel = level!;
      _updateWorld();
      _isGameFinished = false;
      _isLoadingFirstLevel = false;
      _game = GameController(
        level: _activeLevel,
        progress: widget.progress,
        startingChances: kEndlessStartingChances,
      )..addListener(_onGameStateChanged);
    });
    _dinoMotion.snapTo(_game.dinoPos.x, _game.dinoPos.y);
    _resetAnimations();
    _prefetchNextStage();
  }

  void _initAnimations() {
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _bobAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );
    _biteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _stepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _colorPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    _dinoMotion.moveTo(_game.dinoPos.x, _game.dinoPos.y);

    if (_isGameFinished) return;

    if (_game.hasWon && !_isDialogShowing && !_isLoadingNextLevel) {
      _isGameFinished = true;
      if (widget.mode == GameMode.endless) {
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
    } else if (!_game.isActive && !_game.hasWon && !_isDialogShowing) {
      _isGameFinished = true;
      _showGameOverDialog();
    }
    setState(() {});
  }

  void _updateWorld() {
    if (widget.mode == GameMode.endless) {
      _currentWorld = sweetWorldForStage(_endlessStage);
    } else {
      _currentWorld = sweetWorldForLevel(_activeLevel.levelNumber);
    }
    _collectibleEmoji = _pickRandomSweet();
    if (_collectibleEmoji.isEmpty) _collectibleEmoji = '🍫';
  }

  // ========== ENDLESS STAGE CLEAR (with mini-game and timeout) ==========
  Future<void> _handleEndlessStageCleared() async {
    if (_isLoadingNextLevel) return;
    _isLoadingNextLevel = true;

    _confettiController.play();
    SoundManager.playStageClear();
    final points = _game.pointsEarned;
    _endlessScore += points;
    final carryChances = _game.chances;
    _showMessage('Stage $_endlessStage cleared! +$points pts');

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) {
      _isLoadingNextLevel = false;
      return;
    }

    final nextStage = _endlessStage + 1;

    final levelFuture = generateEndlessLevelAsync(nextStage, _endlessRunSeed)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            _showMessage('⏳ Dino is taking his time... retrying!');
            return generateEndlessLevelAsync(nextStage, Random().nextInt(1 << 31));
          },
        )
        .catchError((e) {
          _showMessage('🦕 Dino got distracted! Trying again...');
          return generateEndlessLevelAsync(nextStage, Random().nextInt(1 << 31));
        });

    final bonus = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LoadingMiniGame(loadingFuture: levelFuture),
    );

    LevelConfig? nextLevel;
    try {
      nextLevel = await levelFuture;
    } catch (e) {
      debugPrint('❌ Generation failed after retries: $e');
      nextLevel = _fallbackEndlessLevel(nextStage);
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

    if (bonus != null && bonus > 0) {
      widget.progress.totalPoints += bonus;
      await widget.progress.save();
    }

    _endlessStage = nextStage;
    _game.removeListener(_onGameStateChanged);
    _game.dispose();

    setState(() {
      _activeLevel = nextLevel!;
      _updateWorld();
      _isGameFinished = false;
      _isLoadingNextLevel = false;
      _game = GameController(
        level: _activeLevel,
        progress: widget.progress,
        startingChances: carryChances,
      )..addListener(_onGameStateChanged);
    });
    _dinoMotion.snapTo(_game.dinoPos.x, _game.dinoPos.y);
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

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('tutorial_seen') ?? false;
    if (!alreadyShown && _activeLevel.levelNumber == 1) {
      setState(() => _showTutorial = true);
    }
  }

  void _dismissTutorial() async {
    setState(() => _showTutorial = false);
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

  void _showTemporaryEffect(int row, int col, String effectEmoji) {
    final key = '$row,$col';
    setState(() {
      _game.temporaryEffects[key] = effectEmoji;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _game.temporaryEffects.remove(key);
        });
      }
    });
  }

  Future<void> _showWinDialog() async {
    if (_isDialogShowing) return;
    _isDialogShowing = true;
    final stars = _game.starsEarned;
    final points = _game.pointsEarned;
    final quote = _getDinoQuote(true);

    _confettiController.play();
    SoundManager.playWin();
    _particles.shake(8);

    final dinoPos = _game.dinoPos;
    _showTemporaryEffect(dinoPos.x, dinoPos.y - 1, '💬 Yummy!');

    if (widget.mode == GameMode.daily) {
      _recordDailyCompletion();
    }

    _idleController.stop();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _WinDialog(
        stars: stars,
        points: points,
        subtitle: widget.mode == GameMode.daily
            ? '🔥 ${widget.progress.dailyStreak}-day streak!'
            : null,
        quote: quote,
        onContinue: () {
          Navigator.pop(dialogContext);
          Navigator.pop(context, {'stars': stars, 'points': points});
        },
      ),
    );
    _isDialogShowing = false;
    _isGameFinished = false;
    if (widget.mode == GameMode.endless && mounted) {
      _idleController.repeat(reverse: true);
    }
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

  Future<void> _showGameOverDialog() async {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    String? subtitle;
    if (widget.mode == GameMode.endless) {
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
          : 'Reached stage $_endlessStage · $_endlessScore pts '
              '(best: stage ${widget.progress.endlessBestStage})';
    }
    final quote = _getDinoQuote(false);

    _idleController.stop();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _GameOverDialog(
        dinoName: widget.dinoName,
        subtitle: subtitle,
        quote: quote,
        onRetry: () {
          Navigator.pop(dialogContext);
          if (widget.mode == GameMode.endless) {
            _restartEndlessRun(resetRun: false);
          } else {
            _game.retry();
            _isGameFinished = false;
            _dinoMotion.snapTo(_game.dinoPos.x, _game.dinoPos.y);
            _resetAnimations();
            setState(() {});
          }
        },
        onExit: () {
          Navigator.pop(dialogContext);
          Navigator.pop(context);
        },
      ),
    );
    _isDialogShowing = false;
  }

  void _resetAnimations() {
    _idleController.reset();
    _idleController.repeat(reverse: true);
    _biteController.reset();
    _stepController.reset();
    _colorPulseController.reset();
  }

  // --- Drag Handling ---
  Point? _getCellFromGlobalPosition(Offset globalPosition) {
    final RenderBox? box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPosition);
    final cellSize = box.size.width / _activeLevel.gridSize;
    final row = (local.dy / cellSize).floor();
    final col = (local.dx / cellSize).floor();
    if (row < 0 || row >= _activeLevel.gridSize || col < 0 || col >= _activeLevel.gridSize) {
      return null;
    }
    return Point(row, col);
  }

  void _onPanStart(DragStartDetails details) {
    if (!_game.isActive || _isGameFinished) return;
    final cell = _getCellFromGlobalPosition(details.globalPosition);
    if (cell == null) return;
    if (_game.dinoPos.x != cell.x || _game.dinoPos.y != cell.y) {
      _showMessage('Touch the dinosaur to start dragging!');
      return;
    }
    HapticFeedback.lightImpact();
    _game.resetDrag();
    _game.addToDragPath(cell);
    _particles.puff(Offset(
      cell.y * _cellSize + _cellSize / 2,
      cell.x * _cellSize + _cellSize / 2,
    ));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_game.currentDragPath.isEmpty || !_game.isActive || _isGameFinished) return;
    final newCell = _getCellFromGlobalPosition(details.globalPosition);
    if (newCell == null) return;

    final last = _game.currentDragPath.last;
    if (last == newCell) return;

    if (_game.currentDragPath.contains(newCell)) {
      if (_game.currentDragPath.length >= 2 &&
          _game.currentDragPath[_game.currentDragPath.length - 2] == newCell) {
        _game.removeLastFromDragPath();
        _stepController.forward(from: 0);
        HapticFeedback.lightImpact();
        _particles.puff(Offset(
          newCell.y * _cellSize + _cellSize / 2,
          newCell.x * _cellSize + _cellSize / 2,
        ));
      }
      return;
    }

    if (!_game.isAdjacent(last, newCell)) return;

    final key = '${newCell.x},${newCell.y}';
    if (_activeLevel.obstacles.contains(key)) {
      HapticFeedback.selectionClick();
      SoundManager.playTreeBlock();
      _particles.shake(3);
      _showMessage('🌳 A tree blocks the way!');
      return;
    }

    if (_game.permanentPathCells.contains(key)) return;

    if (_game.isNextChocolate(newCell.x, newCell.y)) {
      _game.addToDragPath(newCell);
      _stepController.forward(from: 0);
      HapticFeedback.lightImpact();
      _particles.puff(Offset(
        newCell.y * _cellSize + _cellSize / 2,
        newCell.x * _cellSize + _cellSize / 2,
      ));
      return;
    }

    final obstacle = _game.checkObstacle(newCell.x, newCell.y);
    if (obstacle != null) {
      _handleObstacle(obstacle, newCell);
      return;
    }

    if (_game.grid[newCell.x][newCell.y] == kChocolateCell) {
      _handleWrongMove();
      return;
    }

    _game.addToDragPath(newCell);
    _stepController.forward(from: 0);
    HapticFeedback.lightImpact();
    _particles.puff(Offset(
      newCell.y * _cellSize + _cellSize / 2,
      newCell.x * _cellSize + _cellSize / 2,
    ));
  }

  void _handleObstacle(ObstacleEffect effect, Point cell) {
    String effectEmoji;
    String message;
    Color fxColor;
    switch (effect) {
      case ObstacleEffect.mine:
        effectEmoji = '💥';
        message = '💣 Mine explosion! Lose 1 chance.';
        fxColor = Colors.orange;
        break;
      case ObstacleEffect.enemy:
        effectEmoji = '🗡️💥';
        message = '🗡️ Guard attacked! Lose 2 chances!';
        fxColor = Colors.redAccent;
        break;
      case ObstacleEffect.hazard:
        effectEmoji = '🔥💥';
        message = '🔥 Fire! Lose 2 chances and 10 points!';
        fxColor = Colors.deepOrange;
        break;
    }
    _showTemporaryEffect(cell.x, cell.y, effectEmoji);
    _showMessage(message);
    HapticFeedback.heavyImpact();
    SoundManager.playHit();
    _particles.explosion(
      Offset(cell.y * _cellSize + _cellSize / 2, cell.x * _cellSize + _cellSize / 2),
      color: fxColor,
    );
    _game.applyObstacleEffect(effect, cell.x, cell.y);
    if (_game.chances <= 0) {
      return;
    }
    _game.resetDrag();
  }

  void _handleWrongMove() {
    HapticFeedback.heavyImpact();
    _game.wrongMove();
    if (_game.chances <= 0) {
      return;
    }
    _showMessage('Oops! ${widget.dinoName} missed. ${_game.chances} chances left.');
    _game.resetDrag();
  }

  void _onPanEnd(DragEndDetails details) {
    if (_game.currentDragPath.isEmpty || !_game.isActive || _isGameFinished) {
      _game.resetDrag();
      return;
    }
    final last = _game.currentDragPath.last;
    if (_game.isNextChocolate(last.x, last.y)) {
      _game.correctConnect(last);
      _biteController.forward(from: 0);
      _colorPulseController.forward(from: 0);
      HapticFeedback.mediumImpact();
      SoundManager.playEat();
      _particles.burst(
        Offset(last.y * _cellSize + _cellSize / 2, last.x * _cellSize + _cellSize / 2),
        color: Colors.amber,
      );
      if (!_game.hasWon) {
        _showMessage('Yum! ${widget.dinoName} loves ${_collectibleEmoji}! Next one glows.');
      }
    } else {
      _handleWrongMove();
    }
    _game.resetDrag();
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    if (_isLoadingFirstLevel) {
      return Scaffold(
        backgroundColor: const Color(0xFF2E7D32),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Generating your next challenge...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final eatenChocolateKeys = _getEatenChocolateKeys();
    final pathProgress = _game.connectedOrders.length / _activeLevel.chocolates.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _buildPremiumAppBar(),
      body: Stack(
        children: [
          _buildParallaxBackground(),
          Center(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 20,
                    offset: Offset(0, 12),
                  )
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
                      child: AnimatedBuilder(
                        animation: _particles,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(_particles.shakeOffset, 0),
                          child: child,
                        ),
                        child: Container(
                          key: _gridKey,
                          padding: const EdgeInsets.all(8),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final boardSize = constraints.maxWidth;
                              final cellSize = boardSize / _activeLevel.gridSize;
                              _cellSize = cellSize;
                              return RepaintBoundary(
                                child: Stack(
                                  children: [
                                    CustomPaint(
                                      size: Size(boardSize, boardSize),
                                      painter: GridPainter(
                                        gridSize: _activeLevel.gridSize,
                                        cellSize: cellSize,
                                        grid: _game.grid,
                                        permanentPath: _game.permanentPathCells,
                                        currentDragPath: _game.currentDragPath,
                                        nextChocolate: _game.getChocolateCoord(_game.nextOrder),
                                        lastConnected: _game.getLastConnectedCoord(),
                                        chocolateSkin: widget.progress.selectedChocolateSkin,
                                        hat: widget.progress.selectedHat,
                                        obstacles: _activeLevel.obstacles,
                                        mines: _activeLevel.mines,
                                        enemies: _activeLevel.enemies,
                                        hazards: _activeLevel.hazards,
                                        temporaryEffects: _game.temporaryEffects,
                                        dangerMap: _activeLevel.dangerMap,
                                        world: _currentWorld,
                                        animationValue: _idleController.value,
                                        sweetEmoji: _collectibleEmoji,
                                        eatenChocolates: eatenChocolateKeys,
                                        pathProgress: pathProgress,
                                        chocolateImage: _chocolateImage,
                                      ),
                                    ),
                                    _buildDino(cellSize),
                                    AnimatedBuilder(
                                      animation: _particles,
                                      builder: (context, _) => CustomPaint(
                                        size: Size(boardSize, boardSize),
                                        painter: PhysicsParticlePainter(_particles.particles),
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
              child: Text(
                'Drag from the glowing start to the pulsing $_collectibleEmoji',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white),
              ),
            ),
          ),
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
          if (_showTutorial) _TutorialDialog(onDismiss: _dismissTutorial),
        ],
      ),
    );
  }

  Widget _buildParallaxBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final offset = _bgController.value * 300;
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
      },
    );
  }

  PreferredSizeWidget _buildPremiumAppBar() {
    final isEndless = widget.mode == GameMode.endless;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ChocoDinoLogo(fontSize: 18, showIcon: true),
              const SizedBox(width: 8),
              Text(
                isEndless
                    ? 'Endless'
                    : (widget.mode == GameMode.daily
                        ? 'Daily'
                        : 'Level ${_activeLevel.levelNumber}'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          if (isEndless)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, color: Colors.yellow, size: 16),
                  const SizedBox(width: 4),
                  Text('$_endlessStage',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 8),
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text('$_endlessScore',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 8),
                  const Icon(Icons.favorite, color: Colors.red, size: 16),
                  const SizedBox(width: 4),
                  Text('${_game.chances}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text('${widget.progress.totalPoints}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(width: 12),
                const Icon(Icons.favorite, color: Colors.red, size: 16),
                const SizedBox(width: 4),
                Text('${_game.chances}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            SoundManager.muted ? Icons.volume_off : Icons.volume_up,
            color: Colors.white,
          ),
          onPressed: () async {
            await SoundManager.toggleMute();
          },
        ),
      ],
    );
  }

  // ==================== DINO WITH IMAGES & GROWTH ====================
  Widget _buildDino(double cellSize) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _idleController,
        _biteController,
        _stepController,
        _colorPulseController,
        _dinoMotion,
      ]),
      builder: (context, child) {
        double scale = 1.0;
        if (_biteController.isAnimating) {
          scale = 1.0 + _biteController.value * 0.5;
        } else if (_stepController.isAnimating) {
          scale = 1.0 + _stepController.value * 0.3;
        }
        final hopLift = _dinoMotion.hopHeight * cellSize * 0.35;

        final totalChocolates = _activeLevel.chocolates.length;
        final eaten = _game.connectedOrders.length;
        final progress = totalChocolates > 0 ? eaten / totalChocolates : 0.0;
        final sizeFactor = 0.6 + 0.35 * progress;

        final progressTint = progress * 0.55;
        final biteFlash = (1 - _colorPulseController.value).clamp(0.0, 1.0) * 0.4;
        final tintOpacity = (progressTint + biteFlash).clamp(0.0, 0.85);

        ui.Image? image;
        if (_game.currentDragPath.isNotEmpty || _stepController.isAnimating) {
          image = _dinoWalkImage;
        } else if (_biteController.isAnimating) {
          image = _dinoEatImage;
        } else {
          image = _dinoIdleImage;
        }

        Widget dino;
        if (image != null && _imagesLoaded) {
          dino = RawImage(
            image: image,
            width: cellSize * sizeFactor,
            height: cellSize * sizeFactor,
            fit: BoxFit.contain,
          );
        } else {
          dino = Text(
            _game.currentDragPath.isNotEmpty ? '🦖' : '🦕',
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

        return Positioned(
          left: _dinoMotion.col * cellSize,
          top: _dinoMotion.row * cellSize - hopLift,
          width: cellSize,
          height: cellSize,
          child: Transform.scale(
            scale: scale,
            child: Transform.translate(
              offset: Offset(0, _bobAnimation.value),
              child: Center(child: dino),
            ),
          ),
        );
      },
    );
  }
}

// ==================== BACKGROUND PAINTERS ====================
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