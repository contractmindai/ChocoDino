// lib/screens/game_home_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/player_progress.dart';
import '../models/level_config.dart';
import '../models/sweet_world.dart';
import '../data/levels.dart';
import '../data/daily_challenge.dart';
import 'game_play_screen.dart';
import 'selfie_with_dino_screen.dart';
import 'shop_screen.dart';
import 'settings_screen.dart';
import '../widgets/logo.dart';
import '../widgets/daily_login_dialog.dart';
import '../utils/sound_manager.dart';
import '../widgets/loading_mini_game.dart';
import '../widgets/loading_dialog.dart';
import '../widgets/theme_widgets.dart';
import '../dialogs/tutorial_dialog.dart';
import '../utils/notification_service.dart';

// ============================================================================
// MILESTONE CONSTANTS
// ============================================================================

const List<int> kMilestoneLevels = [10, 25, 40, 50];

class _MilestoneCopy {
  final String emoji;
  final String title;
  final String message;
  const _MilestoneCopy(this.emoji, this.title, this.message);
}

const Map<int, _MilestoneCopy> kMilestoneCopy = {
  10: _MilestoneCopy('🎉', 'Level 10 complete!', "You're getting the hang of this!"),
  25: _MilestoneCopy('🌟', 'Level 25 complete!', 'Halfway to fifty — keep it up!'),
  40: _MilestoneCopy('🔥', 'Level 40 complete!', 'Almost at the finish line!'),
  50: _MilestoneCopy('🏆', 'Level 50 complete!', "You've beaten every level!"),
};

// ============================================================================
// COLOR UTILS
// ============================================================================

extension _ColorUtils on Color {
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
// HOME SCREEN
// ============================================================================

class GameHomeScreen extends StatefulWidget {
  final String dinoName;
  const GameHomeScreen({required this.dinoName});

  @override
  _GameHomeScreenState createState() => _GameHomeScreenState();
}

class _GameHomeScreenState extends State<GameHomeScreen>
    with TickerProviderStateMixin {
  PlayerProgress? _progress;
  late AnimationController _bounceController;
  late AnimationController _bgController;
  late AnimationController _jumpController;
  late Animation<double> _jumpHeight;
  late Animation<double> _jumpScale;
  final Set<int> _preloadedLevels = {};

  SweetWorld _currentWorld = kSweetWorlds[0];

  @override
  void initState() {
    super.initState();
    _loadProgress();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();

    _jumpHeight = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -32.0), weight: 0.4),
      TweenSequenceItem(tween: Tween(begin: -32.0, end: 0.0), weight: 0.6),
    ]).animate(_jumpController);

    _jumpScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 0.5),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 0.5),
    ]).animate(CurvedAnimation(
      parent: _jumpController,
      curve: Curves.easeInOut,
    ));

    SoundManager.addListener(_onSoundChanged);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _bgController.dispose();
    _jumpController.dispose();
    SoundManager.removeListener(_onSoundChanged);
    super.dispose();
  }

  void _onSoundChanged() {
    setState(() {});
  }

  Future<void> _loadProgress() async {
    final progress = await PlayerProgress.load();
    if (mounted) {
      setState(() {
        _progress = progress;
        final saved = kSweetWorlds.firstWhere(
          (w) => w.name == progress.selectedWorld,
          orElse: () => kSweetWorlds.first,
        );
        // If for some reason the saved world isn't in the purchased set,
        // fall back to Jungle (free, always owned).
        _currentWorld = progress.purchasedWorlds.contains(saved.name)
            ? saved
            : kSweetWorlds.first;
      });
      _preloadLevels(1, 10);
      _maybeShowDailyLoginReward();
    }
  }

  Future<void> _maybeShowDailyLoginReward() async {
    if (_progress == null) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final reward = await maybeShowDailyLoginDialog(context, _progress!);
    if (reward != null && mounted) {
      setState(() {});
    }
  }

  void _preloadLevels(int start, int end) {
    for (int i = start; i <= end && i <= 50; i++) {
      if (!_preloadedLevels.contains(i)) {
        _preloadedLevels.add(i);
        unawaited(preloadLevel(i));
      }
    }
  }

  bool get _dailyCompletedToday =>
      _progress != null &&
      _progress!.lastDailyDate == dailyKeyFor(DateTime.now());

  bool get _isFirstRun =>
      _progress != null &&
      _progress!.unlockedLevel == 1 &&
      _progress!.starsPerLevel.isEmpty;

  void _openTutorial() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => TutorialDialog(
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }

  // ---- Notification soft-ask (after first win only) ----
  Future<void> _showNotificationSoftAsk() async {
    final wants = await showCartoonDialog<bool>(
      context: context,
      world: _currentWorld,
      title: '📬 Keep me posted?',
      subtitle: 'A gentle weekly summary of your progress. At most once a week.',
      iconEmoji: '🦕',
      actions: [
        CartoonButton(
          world: _currentWorld,
          label: 'Not now',
          primary: false,
          onPressed: () => Navigator.pop(context, false),
        ),
        CartoonButton(
          world: _currentWorld,
          label: 'Yes please',
          primary: true,
          icon: Icons.notifications,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    _progress!.notificationPermissionAsked = true;

    if (wants == true) {
      await NotificationService.requestPermission();
      _progress!.remindersEnabled = true;
      await _progress!.save();
      await NotificationService.scheduleWeeklyRecap(_progress!);
      await NotificationService.scheduleWelcomeBack(_progress!);
    } else {
      await _progress!.save();
    }
  }

  // ---- Settings ----
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          progress: _progress!,
          world: _currentWorld,
          onUpdate: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  // ============================================================================
  // DIALOGS
  // ============================================================================

  Future<void> _showWorldSelection() async {
    final selected = await showCartoonDialog<SweetWorld>(
      context: context,
      world: _currentWorld,
      title: 'Choose Your World',
      subtitle: '${_progress!.totalPoints} pts available',
      iconEmoji: '🌍',
      body: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: kSweetWorlds.map((world) {
          final owned = _progress!.purchasedWorlds.contains(world.name);
          final label = owned
              ? world.name
              : '🔒 ${world.name} · ${world.unlockPrice} pts';
          return CartoonButton(
            world: world,
            label: label,
            primary: world == _currentWorld,
            onPressed: () async {
              if (owned) {
                if (mounted) Navigator.pop(context, world);
                return;
              }
              final bought = await _confirmWorldPurchase(world);
              if (bought == true && mounted) {
                Navigator.pop(context, world);
              }
            },
          );
        }).toList(),
      ),
      // UPDATED: Added a Close button here
      actions: [
        CartoonButton(
          world: _currentWorld,
          label: 'Cancel',
          primary: false,
          icon: Icons.close,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );

    if (selected != null && mounted) {
      setState(() => _currentWorld = selected);
      _progress!.selectedWorld = selected.name;
      await _progress!.save();
    }
  }

  /// Asks the player whether to spend points to unlock [world]. Deducts points
  /// and records the purchase only on confirm + sufficient balance.
  Future<bool?> _confirmWorldPurchase(SweetWorld world) async {
    if (_progress!.totalPoints < world.unlockPrice) {
      final remaining = world.unlockPrice - _progress!.totalPoints;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Earn $remaining more points to unlock ${world.name}.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    final confirm = await showCartoonDialog<bool>(
      context: context,
      world: world,
      title: 'Unlock ${world.name}?',
      subtitle: '${world.unlockPrice} pts · one-time unlock',
      iconEmoji: '🔓',
      actions: [
        CartoonButton(
          world: world,
          label: 'Cancel',
          primary: false,
          icon: Icons.close,
          onPressed: () => Navigator.pop(context, false),
        ),
        CartoonButton(
          world: world,
          label: 'Unlock · ${world.unlockPrice} pts',
          primary: true,
          icon: Icons.lock_open,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (confirm != true) return false;
    if (!mounted) return false;

    _progress!.totalPoints -= world.unlockPrice;
    _progress!.purchasedWorlds.add(world.name);
    await _progress!.save();
    setState(() {});
    return true;
  }

  void _showMilestoneDialog(int levelNum) {
    final copy = kMilestoneCopy[levelNum];
    if (copy == null) return;
    showCartoonDialog(
      context: context,
      world: _currentWorld,
      title: '${copy.emoji} ${copy.title}',
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          copy.message,
          style: const TextStyle(fontSize: 18, color: Colors.brown),
          textAlign: TextAlign.center,
        ),
      ),
      iconEmoji: copy.emoji,
      actions: [
        CartoonButton(
          world: _currentWorld,
          label: 'Nice!',
          primary: true,
          icon: Icons.check,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  void _showFinaleDialog() {
    final copy = kMilestoneCopy[50]!;
    showCartoonDialog(
      context: context,
      world: _currentWorld,
      title: '${copy.emoji} ${copy.title}',
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          copy.message,
          style: const TextStyle(fontSize: 18, color: Colors.brown),
          textAlign: TextAlign.center,
        ),
      ),
      iconEmoji: copy.emoji,
      actions: [
        CartoonButton(
          world: _currentWorld,
          label: 'OK',
          primary: true,
          icon: Icons.check,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  void _showSelfieInvite() {
    showCartoonDialog(
      context: context,
      world: _currentWorld,
      title: '📸 High five!',
      subtitle: "You've cleared ${_progress!.levelsCompletedCount} levels with "
          "${widget.dinoName}! Want to take a selfie together?",
      iconEmoji: '📸',
      actions: [
        CartoonButton(
          world: _currentWorld,
          label: 'Maybe later',
          primary: false,
          icon: Icons.close,
          onPressed: () => Navigator.pop(context),
        ),
        CartoonButton(
          world: _currentWorld,
          label: "Let's go!",
          primary: true,
          icon: Icons.photo_camera,
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SelfieWithDinoScreen()),
            );
          },
        ),
      ],
    );
  }

  // ---- NAVIGATION ----
  Future<void> _openLevel(int levelNum) async {
    if (_progress == null || levelNum > 50) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PremiumLoadingDialog(
        message: 'Preparing level',
      ),
    );

    LevelConfig? level;
    try {
      level = await loadLevel(levelNum);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The level took too long to load. Please try again.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamePlayScreen(
          dinoName: widget.dinoName,
          level: level,
          progress: _progress!,
        ),
      ),
    );

    if (mounted) {
      final updated = await PlayerProgress.load();
      setState(() {
        _progress = updated;
      });
    }

    if (!mounted) return;

    if (result != null) {
      try {
        final starsEarned = result['stars'] as int;
        final pointsEarned = result['points'] as int;
        final isNewUnlock =
            (levelNum == _progress!.unlockedLevel - 1) && levelNum < 50;

        final nextStart = levelNum + 1;
        final nextEnd = levelNum + 5;
        _preloadLevels(nextStart, nextEnd);

        // Soft-ask after the very first win (non-blocking, staggered)
        if (!_progress!.notificationPermissionAsked) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted && !_progress!.notificationPermissionAsked) {
              _showNotificationSoftAsk();
            }
          });
        }

        if (levelNum == 50) {
          Future.microtask(() {
            if (mounted) _showFinaleDialog();
          });
        } else if (isNewUnlock && kMilestoneLevels.contains(levelNum)) {
          Future.microtask(() {
            if (mounted) _showMilestoneDialog(levelNum);
          });
        } else if (_progress!.levelsCompletedCount % 5 == 0 &&
            _progress!.levelsCompletedCount > 0) {
          Future.microtask(() {
            if (mounted) _showSelfieInvite();
          });
        }
      } catch (e) {}
    }
  }

  Future<void> _openDailyChallenge() async {
    final levelFuture = generateDailyLevelAsync(DateTime.now());

    final bonus = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LoadingMiniGame(loadingFuture: levelFuture),
    );

    LevelConfig? level;
    try {
      level = await levelFuture;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('The daily challenge is busy. Please try again shortly.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (bonus != null && bonus > 0) {
      _progress!.totalPoints += bonus;
      await _progress!.save();
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamePlayScreen(
          dinoName: widget.dinoName,
          level: level,
          progress: _progress!,
          mode: GameMode.daily,
        ),
      ),
    );

    if (mounted) {
      final updated = await PlayerProgress.load();
      setState(() => _progress = updated);
    }
  }

  Future<void> _openEndlessMode() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamePlayScreen(
          dinoName: widget.dinoName,
          progress: _progress!,
          mode: GameMode.endless,
        ),
      ),
    );
    if (mounted) {
      final updated = await PlayerProgress.load();
      setState(() => _progress = updated);
    }
  }

  void _openShop() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ShopScreen(
        progress: _progress!,
        onUpdate: () {
          if (mounted) {
            setState(() {});
            _progress!.save();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_progress == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bgImage = Image.asset(
      _currentWorld.backgroundImagePath,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
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
      ),
    );

    return Scaffold(
      appBar: _buildThemedAppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) {
                final offset = _bgController.value * 40;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: Transform.scale(
                    scale: 1.05,
                    child: child,
                  ),
                );
              },
              child: bgImage,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 400) {
                          return Column(
                            children: [
                              _ModeCard(
                                icon: _ModeIcon(painter: _DailyIconPainter()),
                                color: const Color(0xFFE64A19),
                                title: _dailyCompletedToday
                                    ? 'Done for today!'
                                    : 'Daily Challenge',
                                subtitle: _progress!.dailyStreak > 0
                                    ? '🔥 ${_progress!.dailyStreak}-day streak'
                                    : 'Start a streak!',
                                enabled: !_dailyCompletedToday,
                                onTap: _openDailyChallenge,
                                animation: _bounceController,
                              ),
                              const SizedBox(height: 8),
                              _ModeCard(
                                icon: _ModeIcon(painter: _EndlessIconPainter()),
                                color: const Color(0xFF00695C),
                                title: 'Endless Mode',
                                subtitle: _progress!.endlessBestStage > 0
                                    ? 'Best: Stage ${_progress!.endlessBestStage}'
                                    : 'No runs yet',
                                enabled: true,
                                onTap: _openEndlessMode,
                                animation: _bounceController,
                              ),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              Expanded(
                                child: _ModeCard(
                                  icon:
                                      _ModeIcon(painter: _DailyIconPainter()),
                                  color: const Color(0xFFE64A19),
                                  title: _dailyCompletedToday
                                      ? 'Done for today!'
                                      : 'Daily Challenge',
                                  subtitle: _progress!.dailyStreak > 0
                                      ? '🔥 ${_progress!.dailyStreak}-day streak'
                                      : 'Start a streak!',
                                  enabled: !_dailyCompletedToday,
                                  onTap: _openDailyChallenge,
                                  animation: _bounceController,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ModeCard(
                                  icon: _ModeIcon(
                                      painter: _EndlessIconPainter()),
                                  color: const Color(0xFF00695C),
                                  title: 'Endless Mode',
                                  subtitle: _progress!.endlessBestStage > 0
                                      ? 'Best: Stage ${_progress!.endlessBestStage}'
                                      : 'No runs yet',
                                  enabled: true,
                                  onTap: _openEndlessMode,
                                  animation: _bounceController,
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                  if (_isFirstRun) _buildFirstRunNudge(),
                  Expanded(
                    child: GridView.builder(
                      key: ValueKey(_progress),
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: 50,
                      itemBuilder: (context, index) {
                        final levelNum = index + 1;
                        final unlocked = levelNum <= _progress!.unlockedLevel;
                        final stars = _progress!.starsPerLevel[levelNum] ?? 0;
                        return _LevelCard(
                          levelNum: levelNum,
                          unlocked: unlocked,
                          stars: stars,
                          onTap: unlocked ? () => _openLevel(levelNum) : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'Tap a level!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: Listenable.merge(
                      [_jumpController, _jumpHeight, _jumpScale]),
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _jumpHeight.value),
                      child: Transform.scale(
                        scale: _jumpScale.value,
                        child: Opacity(
                          opacity: 0.4,
                          child: Image.asset(
                            'assets/dino/idle.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Text('🦕',
                                style: TextStyle(fontSize: 80)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildThemedAppBar() {
    return AppBar(
      title: Row(
        children: [
          const ChocoDinoLogo(fontSize: 32, showIcon: true),
          const SizedBox(width: 6),
          AnimatedBuilder(
            animation: _bounceController,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -3 * _bounceController.value),
              child: child,
            ),
            child: Text(' Hello ${widget.dinoName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                )),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.public, color: Colors.white),
            onPressed: _showWorldSelection,
            tooltip: 'Change world',
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 70,
      iconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: _openSettings,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Settings',
              ),
              const Icon(Icons.star, color: Colors.yellow, size: 20),
              Text(' ${_progress!.totalPoints}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: _openShop,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
      flexibleSpace: Container(
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
      ),
    );
  }

  Widget _buildFirstRunNudge() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: AnimatedBuilder(
        animation: _bounceController,
        builder: (context, child) => Transform.translate(
          offset: Offset(-4 * _bounceController.value, 0),
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('👉', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                'Tap Level 1 to start your adventure!',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF33691E)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LEVEL CARD (unchanged)
// ============================================================================

class _LevelCard extends StatelessWidget {
  final int levelNum;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  const _LevelCard({
    required this.levelNum,
    required this.unlocked,
    required this.stars,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final world = sweetWorldForLevel(levelNum);
    final worldColor = world.primaryColor;
    final isCompleted = stars > 0;

    List<Color> gradientColors;
    Color borderColor;

    if (!unlocked) {
      gradientColors = [Colors.grey.shade400, Colors.grey.shade600];
      borderColor = Colors.grey.shade700;
    } else if (isCompleted) {
      gradientColors = [worldColor, world.secondaryColor];
      borderColor = Colors.amber.shade700;
    } else {
      gradientColors = [worldColor, world.secondaryColor];
      borderColor = Colors.white.withOpacity(0.6);
    }

    return Semantics(
      label:
          'Level $levelNum${!unlocked ? ', locked' : ''}${stars > 0 ? ', $stars stars' : ''}',
      button: true,
      enabled: unlocked,
      onTap: unlocked ? onTap : null,
      child: GestureDetector(
        onTap: onTap,
        child: Transform.scale(
          scale: unlocked ? 1.0 : 0.95,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color:
                      (unlocked ? worldColor : Colors.black26).withOpacity(0.4),
                  blurRadius: isCompleted ? 16 : 10,
                  offset: const Offset(0, 6),
                )
              ],
              border: Border.all(
                color: isCompleted ? Colors.amber.shade700 : borderColor,
                width: isCompleted ? 3.0 : 2.5,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$levelNum',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                  offset: Offset(2, 2),
                                  color: Colors.black26)
                            ],
                          )),
                      if (!unlocked)
                        const Icon(Icons.lock,
                            size: 28, color: Colors.white70)
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) {
                            final filled = i < stars;
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 1),
                              child: Text(
                                filled ? '⭐' : '☆',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: filled ? null : Colors.white38,
                                  shadows: filled
                                      ? const [
                                          Shadow(
                                              color: Colors.black45,
                                              blurRadius: 3,
                                              offset: Offset(0, 1))
                                        ]
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.transparent
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MODE CARDS (unchanged)
// ============================================================================

class _ModeCard extends StatelessWidget {
  final Widget icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  final AnimationController animation;

  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final scale = 1.0 + 0.02 * animation.value;
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: enabled ? 1.0 : 0.6,
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeIcon extends StatelessWidget {
  final CustomPainter painter;
  const _ModeIcon({required this.painter});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 28, height: 28, child: CustomPaint(painter: painter));
  }
}

class _DailyIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final flame = Paint()..color = Colors.white;

    final path = Path()
      ..moveTo(w * 0.5, h * 0.02)
      ..cubicTo(w * 0.85, h * 0.35, w * 0.78, h * 0.55, w * 0.62, h * 0.5)
      ..cubicTo(w * 0.7, h * 0.65, w * 0.6, h * 0.98, w * 0.4, h * 0.98)
      ..cubicTo(w * 0.1, h * 0.98, w * 0.05, h * 0.6, w * 0.28, h * 0.42)
      ..cubicTo(w * 0.22, h * 0.6, w * 0.35, h * 0.65, w * 0.38, h * 0.5)
      ..cubicTo(w * 0.18, h * 0.3, w * 0.3, h * 0.1, w * 0.5, h * 0.02)
      ..close();
    canvas.drawPath(path, flame);

    final choc = Paint()..color = const Color(0xFF6D4C41);
    final chocRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.78),
          width: w * 0.24,
          height: h * 0.2),
      const Radius.circular(2),
    );
    canvas.drawRRect(chocRect, choc);
  }

  @override
  bool shouldRepaint(covariant _DailyIconPainter oldDelegate) => false;
}

class _EndlessIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.16
      ..strokeCap = StrokeCap.round;

    final leftLoop = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.32, h * 0.5),
          width: w * 0.42,
          height: h * 0.42));
    final rightLoop = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.68, h * 0.5),
          width: w * 0.42,
          height: h * 0.42));

    canvas.drawPath(leftLoop, stroke);
    canvas.drawPath(rightLoop, stroke);

    final sparkle = Paint()..color = Colors.white;
    final cx = w * 0.86;
    final cy = h * 0.16;
    final r = w * 0.07;
    final sparklePath = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r * 0.3, cy - r * 0.3)
      ..lineTo(cx + r, cy)
      ..lineTo(cx + r * 0.3, cy + r * 0.3)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r * 0.3, cy + r * 0.3)
      ..lineTo(cx - r, cy)
      ..lineTo(cx - r * 0.3, cy - r * 0.3)
      ..close();
    canvas.drawPath(sparklePath, sparkle);
  }

  @override
  bool shouldRepaint(covariant _EndlessIconPainter oldDelegate) => false;
}