import 'package:flutter/material.dart';
import '../models/player_progress.dart';
import '../models/level_config.dart';
import '../data/levels.dart';
import '../data/daily_challenge.dart';
import 'game_play_screen.dart';
import 'shop_screen.dart';
import '../widgets/logo.dart';
import '../utils/sound_manager.dart';
import '../widgets/loading_mini_game.dart';

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

class GameHomeScreen extends StatefulWidget {
  final String dinoName;
  const GameHomeScreen({required this.dinoName});

  @override
  _GameHomeScreenState createState() => _GameHomeScreenState();
}

class _GameHomeScreenState extends State<GameHomeScreen>
    with SingleTickerProviderStateMixin {
  PlayerProgress? _progress;
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    SoundManager.addListener(_onSoundChanged);
  }

  @override
  void dispose() {
    _bounceController.dispose();
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
      });
    }
  }

  bool get _dailyCompletedToday =>
      _progress != null && _progress!.lastDailyDate == dailyKeyFor(DateTime.now());

  Future<void> _openLevel(int levelNum) async {
    if (_progress == null || levelNum > 50) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Loading level...'),
              ],
            ),
          ),
        ),
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
            content: Text('😴 Oh! Dino is tired. Let\'s try again in a moment!'),
            duration: Duration(seconds: 2),
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

    if (!mounted) return;

    if (result != null) {
      try {
        final starsEarned = result['stars'] as int;
        final pointsEarned = result['points'] as int;


        setState(() {
          if (starsEarned > (_progress!.starsPerLevel[levelNum] ?? 0)) {
            _progress!.starsPerLevel[levelNum] = starsEarned;
          }
          if (levelNum == _progress!.unlockedLevel && levelNum < 50) {
            _progress!.unlockedLevel = levelNum + 1;
          }
          _progress!.totalPoints += pointsEarned;
        });

        await _progress!.save();

        // ---- RELOAD ENTIRE PROGRESS from disk ----
        await _loadProgress();


        if (levelNum == 50) {
          Future.microtask(() {
            if (mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('🎉 Congratulations!'),
                  content: const Text('You have completed all 50 levels!'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('🦕 Dino spilled the chocolate! Error: $e')),
          );
        }
      }
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
            content: Text('🌋 Too hot! Dino needs a break. Try again soon.'),
            duration: Duration(seconds: 2),
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
    if (mounted) setState(() {});
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
    if (mounted) setState(() {});
  }

  void _openShop() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const ChocoDinoLogo(fontSize: 32, showIcon: true),
            const SizedBox(width: 8),
            Text('| ${widget.dinoName}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 70,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                IconButton(
                  icon: Icon(
                    SoundManager.muted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                  ),
                  onPressed: () async {
                    await SoundManager.toggleMute();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Icon(Icons.star, color: Colors.yellow, size: 20),
                Text(' ${_progress!.totalPoints}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeCard(
                      icon: Icons.local_fire_department,
                      color: const Color(0xFFE64A19),
                      title: _dailyCompletedToday ? 'Done for today!' : 'Daily Challenge',
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
                      icon: Icons.all_inclusive,
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
              ),
            ),
            Expanded(
              child: GridView.builder(
                // ---- FIX: Force rebuild when _progress changes ----
                key: ValueKey(_progress),
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                  // ---- Debug print ----
            
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
    );
  }
}

// ---- Enhanced Level Card ----
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

  Color _getWorldColor() {
    if (levelNum <= 10) return const Color(0xCD7F32); // Bronze
    if (levelNum <= 20) return Colors.grey.shade400; // Silver
    if (levelNum <= 30) return Colors.amber.shade700; // Gold
    if (levelNum <= 40) return Colors.purple.shade400; // Purple
    return Colors.pink.shade300; // Pink (Space)
  }

  @override
  Widget build(BuildContext context) {
    final worldColor = _getWorldColor();
    final isCompleted = stars > 0;
    final isPerfect = stars == 3;

    List<Color> gradientColors;
    Color borderColor;

    if (!unlocked) {
      gradientColors = [Colors.grey.shade400, Colors.grey.shade600];
      borderColor = Colors.grey.shade700;
    } else if (isPerfect) {
      gradientColors = [Colors.amber.shade300, Colors.amber.shade700];
      borderColor = Colors.amber.shade900;
    } else if (isCompleted) {
      gradientColors = [worldColor, worldColor.darken(0.15)];
      borderColor = Colors.amber.shade700;
    } else {
      gradientColors = [worldColor, worldColor.darken(0.2)];
      borderColor = Colors.white.withOpacity(0.6);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        transform: Matrix4.identity()..scale(unlocked ? 1.0 : 0.95),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: (unlocked ? worldColor : Colors.black26).withOpacity(0.4),
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
                        shadows: [Shadow(offset: Offset(2, 2), color: Colors.black26)],
                      )),
                  if (!unlocked)
                    const Icon(Icons.lock, size: 28, color: Colors.white70)
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        final filled = i < stars;
                        return Icon(
                          filled ? Icons.star_rounded : Icons.star_border_rounded,
                          // Filled stars are white with a dark shadow so they
                          // read clearly against every tile color, including
                          // the amber/gold "perfect" tile — the previous
                          // yellow.shade700-on-amber.shade700 combination had
                          // almost no contrast, which is why 3 earned stars
                          // could look like 0.
                          color: filled ? Colors.white : Colors.white38,
                          size: 22,
                          shadows: filled
                              ? const [Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1))]
                              : null,
                        );
                      }),
                    ),
                  if (isPerfect)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'PERFECT',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.2), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Mode Card ----
class _ModeCard extends StatelessWidget {
  final IconData icon;
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                    Icon(icon, color: Colors.white, size: 28),
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
                                  fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(subtitle,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 11),
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
        },
      ),
    );
  }
}