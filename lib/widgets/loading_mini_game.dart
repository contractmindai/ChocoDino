import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class LoadingMiniGame extends StatefulWidget {
  final Future<void> loadingFuture;
  const LoadingMiniGame({Key? key, required this.loadingFuture}) : super(key: key);

  @override
  _LoadingMiniGameState createState() => _LoadingMiniGameState();
}

class _LoadingMiniGameState extends State<LoadingMiniGame> with TickerProviderStateMixin {
  int taps = 0;
  int combo = 0;
  int maxCombo = 0;
  final List<FloatingChocolate> chocolates = [];
  final Random random = Random();
  Timer? _spawnTimer;
  Timer? _movementTimer;
  Timer? _progressTimer;
  bool loadingComplete = false;
  bool generationFailed = false;
  bool skipped = false;
  double progress = 0.0;
  String currentMessage = '🦖 Rex entered the jungle...';

  int missionGoal = 0;
  int missionProgress = 0;
  String missionText = '';
  bool missionComplete = false;
  int missionBonus = 0;

  late AnimationController _dinoBobController;
  late Animation<double> _dinoBob;

  bool _showSkip = false;
  Timer? _skipTimer;
  bool _nearReadyShown = false;
  Timer? _nearReadyTimer;

  @override
  void initState() {
    super.initState();
    _dinoBobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _dinoBob = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _dinoBobController, curve: Curves.easeInOut),
    );

    _startSpawning();
    _startMovement();
    _startProgressSimulation();
    _listenToLoading();

    _skipTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !loadingComplete) {
        setState(() => _showSkip = true);
      }
    });

    _generateNewMission();
  }

  @override
  void dispose() {
    _dinoBobController.dispose();
    _spawnTimer?.cancel();
    _movementTimer?.cancel();
    _progressTimer?.cancel();
    _skipTimer?.cancel();
    _nearReadyTimer?.cancel();
    super.dispose();
  }

  void _generateNewMission() {
    final missions = [
      {'text': '🍫 Collect 10 chocolates', 'goal': 10},
      {'text': '🌟 Reach 5× combo', 'goal': 5},
      {'text': '⚡ Quick taps: 15 in 5s', 'goal': 15},
    ];
    final picked = missions[random.nextInt(missions.length)];
    missionText = picked['text'] as String;
    missionGoal = picked['goal'] as int;
    missionProgress = 0;
    missionComplete = false;
    missionBonus = 0;
  }

  void _updateMission(int tapsNow) {
    if (missionComplete) return;
    if (missionText.contains('combo')) {
      if (maxCombo >= missionGoal) {
        missionComplete = true;
        missionBonus = 5;
        _showMessage('🎉 Mission complete! +$missionBonus bonus!');
      }
    } else {
      missionProgress = tapsNow;
      if (tapsNow >= missionGoal) {
        missionComplete = true;
        missionBonus = 3;
        _showMessage('✅ Mission complete! +$missionBonus bonus!');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !loadingComplete) {
            setState(() => _generateNewMission());
          }
        });
      }
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.amber.shade800,
      ),
    );
  }

  void _startSpawning() {
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted && !loadingComplete && !generationFailed) {
        setState(() {
          chocolates.add(FloatingChocolate(
            id: DateTime.now().millisecondsSinceEpoch + random.nextInt(10000),
            x: random.nextDouble() * 0.8 + 0.1,
            y: random.nextDouble(),
            speed: 0.002 + random.nextDouble() * 0.004,
            size: 30 + random.nextDouble() * 20,
          ));
          if (chocolates.length > 15) chocolates.removeAt(0);
        });
      }
    });
  }

  void _startMovement() {
    _movementTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted && !loadingComplete && !generationFailed) {
        setState(() {
          for (final c in chocolates) {
            c.y -= c.speed;
          }
          chocolates.removeWhere((c) {
            if (c.y < -0.1) {
              c.y = 1.0 + random.nextDouble() * 0.2;
              c.x = random.nextDouble() * 0.8 + 0.1;
              c.speed = 0.002 + random.nextDouble() * 0.004;
            }
            return false;
          });
          if (chocolates.length > 20) chocolates.removeAt(0);
        });
      }
    });
  }

  void _startProgressSimulation() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (mounted && !loadingComplete && !generationFailed) {
        setState(() {
          progress = (progress + 0.01).clamp(0.0, 0.9);
          _updateMessage();
          if (progress >= 0.9 && !_nearReadyShown) {
            _nearReadyShown = true;
            _triggerNearReady();
          }
        });
      }
    });
  }

  void _updateMessage() {
    if (progress < 0.2) currentMessage = '🦖 Rex entered the jungle...';
    else if (progress < 0.4) currentMessage = '🌴 Planting candy trees...';
    else if (progress < 0.6) currentMessage = '🍫 Hiding chocolate treasures...';
    else if (progress < 0.8) currentMessage = '🐍 Adding surprises...';
    else if (progress < 0.95) currentMessage = '🏆 Preparing your adventure!';
    else currentMessage = '✨ Almost ready!';
  }

  void _triggerNearReady() {
    _nearReadyTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      _nearReadyTimer?.cancel();
    });
  }

  void _listenToLoading() {
    widget.loadingFuture.then((_) {
      if (mounted) {
        setState(() {
          loadingComplete = true;
          progress = 1.0;
          currentMessage = '🎉 Adventure Ready!';
        });
        _spawnTimer?.cancel();
        _movementTimer?.cancel();
        _progressTimer?.cancel();
        _skipTimer?.cancel();
        final totalBonus = _calculateBonus();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop(totalBonus);
        });
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          generationFailed = true;
          loadingComplete = true;
          progress = 0.0;
          currentMessage = '🌪 This jungle is too wild!\nCreating another adventure...';
        });
        _spawnTimer?.cancel();
        _movementTimer?.cancel();
        _progressTimer?.cancel();
        _skipTimer?.cancel();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.of(context).pop(0);
        });
      }
    });
  }

  void _handleTap(FloatingChocolate tapped) {
    if (loadingComplete || generationFailed) return;
    setState(() {
      chocolates.removeWhere((c) => c.id == tapped.id);
      taps++;
      combo++;
      if (combo > maxCombo) maxCombo = combo;
      _updateMission(taps);
      progress = (progress + 0.01).clamp(0.0, 0.9);
    });
  }

  void _skipGame() {
    if (loadingComplete) return;
    setState(() {
      skipped = true;
      _showSkip = false;
      Navigator.of(context).pop(0);
    });
  }

  int _calculateBonus() {
    if (skipped) return 0;
    final base = taps ~/ 3;
    final comboBonus = (maxCombo / 2).floor();
    final missionBonusTotal = missionComplete ? missionBonus : 0;
    return (base + comboBonus + missionBonusTotal).clamp(0, 50);
  }

  @override
  Widget build(BuildContext context) {
    final isError = generationFailed;
    final isComplete = loadingComplete && !isError;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isError
                ? [Colors.red.shade300, Colors.orange.shade700]
                : [Colors.orange.shade300, Colors.brown.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _dinoBob,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _dinoBob.value),
                      child: const Text('🦖', style: TextStyle(fontSize: 48)),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isError ? 'Oh no!' : (isComplete ? '🎉 Adventure Ready!' : currentMessage),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            if (!isComplete && !isError)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.yellow),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            // Mission text
            if (!isComplete && !isError)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.assignment, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      missionComplete ? '✅ Mission complete!' : missionText,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Chocolate playground
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Background hint
                    Positioned.fill(
                      child: Center(
                        child: Text(
                          isError ? '😢' : (isComplete ? '✨' : '🍫'),
                          style: TextStyle(fontSize: 40, color: Colors.white.withOpacity(0.1)),
                        ),
                      ),
                    ),
                    // Chocolates
                    ...chocolates.map((c) {
                      return Positioned(
                        left: c.x * 320,
                        top: c.y * 130,
                        child: GestureDetector(
                          onTap: () => _handleTap(c),
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 150),
                            tween: Tween(begin: 1.0, end: 1.2),
                            builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                            child: Text('🍫', style: TextStyle(fontSize: c.size)),
                          ),
                        ),
                      );
                    }).toList(),
                    // Combo display
                    if (combo >= 3 && !isComplete && !isError)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.yellow.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '✨ ${combo}× Combo!',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('🍫 Taps', style: TextStyle(color: Colors.white70)),
                    Text('$taps', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                Column(
                  children: [
                    const Text('⭐ Best Combo', style: TextStyle(color: Colors.white70)),
                    Text('$maxCombo', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.yellowAccent)),
                  ],
                ),
                Column(
                  children: [
                    const Text('💰 Bonus', style: TextStyle(color: Colors.white70)),
                    Text(
                      isComplete ? '+${_calculateBonus()}' : (skipped ? '0' : '?'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Skip or reward
            if (_showSkip && !loadingComplete && !isError)
              TextButton(
                onPressed: _skipGame,
                child: const Text('Skip (no bonus)', style: TextStyle(color: Colors.white70, decoration: TextDecoration.underline)),
              ),
            if (isComplete)
              Text(
                'You collected $taps chocolates!\nBonus: +${_calculateBonus()} coins',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            if (isError)
              Text(
                '😴 Dino needs a break!\nTap OK to retry.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}

class FloatingChocolate {
  final int id;
  double x;
  double y;
  double speed;
  final double size;
  FloatingChocolate({
    required this.id,
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
  });
}