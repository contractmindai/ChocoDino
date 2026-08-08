import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ──────────────────────────────────────────────────────────────
//  ENUMS & THEMES
// ──────────────────────────────────────────────────────────────

enum SeasonalTheme { classic, halloween, christmas, valentine, summer }
enum ChocolateType { normal, golden, bomb, gift, rainbow }

// ──────────────────────────────────────────────────────────────
//  ENTITY CLASSES
// ──────────────────────────────────────────────────────────────

class ChocolateEntity {
  final int id;
  double x, y;
  final double size;
  final ChocolateType type;
  ChocolateEntity({
    required this.id,
    required this.x,
    required this.y,
    required this.size,
    required this.type,
  });
}

class Particle {
  double x, y, vx, vy, size, life;
  final Color color;
  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.life,
  });
}

// ──────────────────────────────────────────────────────────────
//  MAIN WIDGET
// ──────────────────────────────────────────────────────────────

class LoadingMiniGame extends StatefulWidget {
  final Future<void> loadingFuture;
  final SeasonalTheme theme;
  const LoadingMiniGame({
    Key? key,
    required this.loadingFuture,
    this.theme = SeasonalTheme.classic,
  }) : super(key: key);

  @override
  _LoadingMiniGameState createState() => _LoadingMiniGameState();
}

class _LoadingMiniGameState extends State<LoadingMiniGame>
    with TickerProviderStateMixin {
  // ─── Game state ───
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _taps = 0;
  bool _loadingComplete = false;
  bool _generationFailed = false;
  bool _skipped = false;
  double _progress = 0.0;
  String _currentMessage = 'Looking for chocolates...';

  // ─── Dino ───
  late AnimationController _dinoController;
  late Animation<double> _dinoBob;
  late Animation<double> _dinoTailWag;
  bool _dinoBlink = false;
  Timer? _blinkTimer;
  Offset _dinoPosition = const Offset(0.5, 0.5);

  // ─── Chocolates ───
  final List<ChocolateEntity> _chocolates = [];
  final Random _random = Random();
  Timer? _spawnTimer;

  // ─── Particles ───
  final List<Particle> _particles = [];
  Timer? _particleTimer;

  // ─── Combo effects ───
  String _comboText = '';
  Color _comboColor = Colors.white;
  double _comboScale = 1.0;
  Timer? _comboTimer;

  // ─── Mission ───
  int _missionGoal = 0;
  int _missionProgress = 0;
  String _missionText = '';
  bool _missionComplete = false;
  int _missionBonus = 0;

  // ─── Events ───
  Timer? _eventTimer;

  // ─── UI ───
  bool _showSkip = false;
  Timer? _skipTimer;
  bool _nearReadyShown = false;

  // ─── Reward chest ───
  bool _chestRevealed = false;
  int _finalBonus = 0;

  // ─── Asset helpers ───
  Widget _dinoImage({double size = 40, String state = 'idle'}) {
    return Image.asset(
      'assets/dino/${state}.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(
        state == 'idle' ? '🦖' : '🦕',
        style: TextStyle(fontSize: size),
      ),
    );
  }

  Widget _chocolateImage(ChocolateType type, {double size = 30}) {
    String asset;
    switch (type) {
      case ChocolateType.golden:
        asset = 'assets/images/golden_chocolate.jpg';
        break;
      case ChocolateType.bomb:
        asset = 'assets/images/bomb.png';
        break;
      case ChocolateType.gift:
        asset = 'assets/images/gift.jpg';
        break;
      case ChocolateType.rainbow:
        asset = 'assets/images/rainbow_chocolate.jpg';
        break;
      default:
        asset = 'assets/images/chocolate.jpg';
    }
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(
        type == ChocolateType.golden
            ? '⭐'
            : type == ChocolateType.bomb
                ? '💣'
                : type == ChocolateType.gift
                    ? '🎁'
                    : type == ChocolateType.rainbow
                        ? '🌈'
                        : '🍫',
        style: TextStyle(fontSize: size),
      ),
    );
  }

  Widget _decorationImage(String asset, {double size = 30}) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _dinoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _dinoBob = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _dinoController, curve: Curves.easeInOut),
    );
    // Fixed: use Curves.easeInOutSine instead of non-existent sineInOut
    _dinoTailWag = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _dinoController, curve: Curves.easeInOutSine),
    );

    _blinkTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() => _dinoBlink = true);
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _dinoBlink = false);
        });
      }
    });

    _startSpawning();
    _startProgressSimulation();
    _listenToLoading();
    _generateNewMission();
    _scheduleSkipButton();
    _scheduleRandomEvents();
    _dinoPosition = const Offset(0.5, 0.5);
  }

  @override
  void dispose() {
    _dinoController.dispose();
    _blinkTimer?.cancel();
    _spawnTimer?.cancel();
    _progressTimer?.cancel();
    _skipTimer?.cancel();
    _eventTimer?.cancel();
    _comboTimer?.cancel();
    _particleTimer?.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  //  GAME LOGIC
  // ──────────────────────────────────────────────────────────────

  void _startSpawning() {
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted && !_loadingComplete && !_generationFailed) {
        setState(() {
          if (_chocolates.length < 8) {
            _chocolates.add(_createChocolate());
          }
        });
      }
    });
    if (_chocolates.isEmpty) _chocolates.add(_createChocolate());
  }

  ChocolateEntity _createChocolate() {
    final type = _random.nextDouble() < 0.1
        ? ChocolateType.values[_random.nextInt(ChocolateType.values.length)]
        : ChocolateType.normal;
    return ChocolateEntity(
      id: DateTime.now().millisecondsSinceEpoch + _random.nextInt(10000),
      x: 0.1 + _random.nextDouble() * 0.8,
      y: 0.1 + _random.nextDouble() * 0.8,
      size: 28 + _random.nextDouble() * 16,
      type: type,
    );
  }

  void _handleTap(ChocolateEntity tapped) {
    if (_loadingComplete || _generationFailed || _skipped) return;

    setState(() {
      _chocolates.removeWhere((c) => c.id == tapped.id);
      _taps++;
      _score++;
      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;
      _updateMission();
      _progress = (_progress + 0.012).clamp(0.0, 0.9);
      _dinoPosition = Offset(tapped.x, tapped.y);
      _dinoController.reset();
      _dinoController.forward();
      _spawnParticles(tapped.x, tapped.y, tapped.type);
      _updateComboEffect();
      HapticFeedback.lightImpact();
      _handleSpecialChocolate(tapped.type);
    });
  }

  void _handleSpecialChocolate(ChocolateType type) {
    switch (type) {
      case ChocolateType.golden:
        _score += 5;
        _showFloatingText('+5 GOLDEN!', Colors.amber);
        break;
      case ChocolateType.bomb:
        _combo = 0;
        _showFloatingText('COMBO LOST!', Colors.red);
        break;
      case ChocolateType.gift:
        _score += 10;
        _showFloatingText('+10 BONUS!', Colors.purple);
        break;
      case ChocolateType.rainbow:
        _score += 2;
        _combo += 3;
        _showFloatingText('2x COMBO!', Colors.cyan);
        break;
      default:
        break;
    }
  }

  void _showFloatingText(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _spawnParticles(double x, double y, ChocolateType type) {
    final color = type == ChocolateType.golden
        ? Colors.amber
        : type == ChocolateType.rainbow
            ? Colors.purple
            : Colors.brown;
    for (int i = 0; i < 12; i++) {
      _particles.add(Particle(
        x: x,
        y: y,
        vx: (_random.nextDouble() - 0.5) * 0.04,
        vy: (_random.nextDouble() - 0.5) * 0.04 - 0.02,
        size: 4 + _random.nextDouble() * 8,
        color: color.withOpacity(0.8 + _random.nextDouble() * 0.2),
        life: 1.0,
      ));
    }
    _startParticleAnimation();
  }

  void _startParticleAnimation() {
    _particleTimer?.cancel();
    _particleTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!mounted) {
        _particleTimer?.cancel();
        return;
      }
      setState(() {
        for (final p in _particles) {
          p.x += p.vx;
          p.y += p.vy;
          p.vy += 0.001;
          p.life -= 0.025;
        }
        _particles.removeWhere((p) => p.life <= 0);
        if (_particles.isEmpty) _particleTimer?.cancel();
      });
    });
  }

  void _updateComboEffect() {
    String text;
    Color color;
    if (_combo >= 20) {
      text = 'LEGENDARY!!!';
      color = Colors.deepPurple;
    } else if (_combo >= 15) {
      text = 'INCREDIBLE!!!!';
      color = Colors.pink;
    } else if (_combo >= 10) {
      text = 'AWESOME!!!';
      color = Colors.orange;
    } else if (_combo >= 6) {
      text = 'GREAT!!';
      color = Colors.green;
    } else if (_combo >= 3) {
      text = 'GOOD!';
      color = Colors.blue;
    } else {
      _comboText = '';
      return;
    }
    setState(() {
      _comboText = text;
      _comboColor = color;
      _comboScale = 1.8;
    });
    _comboTimer?.cancel();
    _comboTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      setState(() {
        _comboScale = _comboScale > 1.0 ? _comboScale - 0.02 : 1.0;
        if (_comboScale <= 1.0) _comboTimer?.cancel();
      });
    });
  }

  // ─── Mission ───

  void _generateNewMission() {
    final missions = [
      {'text': 'Eat 10 Chocolates', 'goal': 10},
      {'text': 'Reach 5× Combo', 'goal': 5},
      {'text': 'Tap 15 Chocolates', 'goal': 15},
    ];
    final picked = missions[_random.nextInt(missions.length)];
    _missionText = picked['text'] as String;
    _missionGoal = picked['goal'] as int;
    _missionProgress = 0;
    _missionComplete = false;
    _missionBonus = 0;
  }

  void _updateMission() {
    if (_missionComplete) return;
    if (_missionText.contains('Combo')) {
      if (_maxCombo >= _missionGoal) {
        _missionComplete = true;
        _missionBonus = 5;
        _showFloatingText('Mission complete! +$_missionBonus bonus!', Colors.green);
      }
    } else {
      _missionProgress = _taps;
      if (_taps >= _missionGoal) {
        _missionComplete = true;
        _missionBonus = 3;
        _showFloatingText('Mission complete! +$_missionBonus bonus!', Colors.green);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_loadingComplete) setState(() => _generateNewMission());
        });
      }
    }
  }

  // ─── Random events ───

  void _scheduleRandomEvents() {
    _eventTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_loadingComplete && !_generationFailed) {
        setState(() {
          if (_chocolates.length < 10) _chocolates.add(_createChocolate());
          final messages = [
            'Dino is hungry!',
            'More chocolates!',
            'Watch out for bombs!',
            'Gift box appears!',
          ];
          _currentMessage = messages[_random.nextInt(messages.length)];
        });
      }
    });
  }

  // ─── Progress simulation ───

  Timer? _progressTimer;

  void _startProgressSimulation() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (mounted && !_loadingComplete && !_generationFailed) {
        setState(() {
          _progress = (_progress + 0.01).clamp(0.0, 0.9);
          _updateMessage();
          if (_progress >= 0.9 && !_nearReadyShown) {
            _nearReadyShown = true;
            _currentMessage = 'Almost ready!';
          }
        });
      }
    });
  }

  void _updateMessage() {
    final msgs = [
      'Looking for chocolates...',
      'Hiding chocolates...',
      'Planting tasty trees...',
      'Avoiding dangerous mines...',
      'Waking sleepy dinosaurs...',
      'Almost ready...',
    ];
    if (_progress < 0.2) _currentMessage = msgs[0];
    else if (_progress < 0.4) _currentMessage = msgs[1];
    else if (_progress < 0.6) _currentMessage = msgs[2];
    else if (_progress < 0.8) _currentMessage = msgs[3];
    else _currentMessage = msgs[5];
  }

  // ─── Loading listener ───

  void _listenToLoading() {
    widget.loadingFuture.then((_) {
      if (mounted) {
        setState(() {
          _loadingComplete = true;
          _progress = 1.0;
          _currentMessage = 'Ready!';
        });
        _spawnTimer?.cancel();
        _progressTimer?.cancel();
        _skipTimer?.cancel();
        _eventTimer?.cancel();
        _finalBonus = _calculateBonus();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _chestRevealed = true);
            HapticFeedback.mediumImpact();
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) Navigator.of(context).pop(_finalBonus);
            });
          }
        });
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _generationFailed = true;
          _loadingComplete = true;
          _progress = 0.0;
          _currentMessage = 'Something went wrong. Please try again.';
        });
        _spawnTimer?.cancel();
        _progressTimer?.cancel();
        _skipTimer?.cancel();
        _eventTimer?.cancel();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.of(context).pop(0);
        });
      }
    });
  }

  // ─── Skip ───

  void _scheduleSkipButton() {
    _skipTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_loadingComplete) setState(() => _showSkip = true);
    });
  }

  void _skipGame() {
    if (_loadingComplete) return;
    setState(() {
      _skipped = true;
      _showSkip = false;
      Navigator.of(context).pop(0);
    });
  }

  // ─── Bonus ───

  int _calculateBonus() {
    if (_skipped) return 0;
    final base = _taps ~/ 3;
    final comboBonus = (_maxCombo / 2).floor();
    final missionBonusTotal = _missionComplete ? _missionBonus : 0;
    return (base + comboBonus + missionBonusTotal).clamp(0, 50);
  }

  // ──────────────────────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isError = _generationFailed;
    final isComplete = _loadingComplete && !isError;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.92,
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isError
                ? [Colors.red.shade300, Colors.orange.shade700]
                : [Colors.orange.shade300, Colors.brown.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── HEADER ───
            Row(
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_dinoBob, _dinoTailWag]),
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _dinoBob.value),
                      child: Row(
                        children: [
                          Transform.rotate(
                            angle: _dinoTailWag.value * 0.02,
                            child: _dinoImage(size: 24, state: 'idle'),
                          ),
                          const SizedBox(width: 4),
                          AnimatedOpacity(
                            opacity: _dinoBlink ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 100),
                            child: _dinoImage(size: 40, state: 'idle'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isError
                        ? 'Oh no!'
                        : (isComplete ? 'Ready!' : _currentMessage),
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
            const SizedBox(height: 8),

            // ─── PROGRESS (dino walking) ───
            if (!isComplete && !isError)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    _dinoImage(size: 18, state: 'idle'),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: _progress,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.yellow,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          Positioned(
                            left: _progress * 100 - 12,
                            top: -10,
                            child: _dinoImage(size: 24, state: 'walk'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    _chocolateImage(ChocolateType.normal, size: 18),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // ─── MISSION CARD ───
            if (!isComplete && !isError)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.assignment, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DAILY MISSION',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                _missionComplete ? 'Complete!' : _missionText,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              const Spacer(),
                              if (!_missionComplete)
                                Text(
                                  '${_missionProgress}/${_missionGoal}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                            ],
                          ),
                          if (!_missionComplete)
                            LinearProgressIndicator(
                              value: _missionGoal > 0
                                  ? (_missionProgress / _missionGoal).clamp(0.0, 1.0)
                                  : 0.0,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                              minHeight: 4,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // ─── PLAYGROUND ───
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Background decorations
                    ..._buildBackgroundDecorations(),

                    // Particles
                    ..._particles.map((p) => Positioned(
                          left: p.x * 340,
                          top: p.y * 160,
                          child: Container(
                            width: p.size,
                            height: p.size,
                            decoration: BoxDecoration(
                              color: p.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )),

                    // Chocolates
                    ..._chocolates.map((c) {
                      return Positioned(
                        left: c.x * 340 - 16,
                        top: c.y * 160 - 16,
                        child: GestureDetector(
                          onTap: () => _handleTap(c),
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 200),
                            tween: Tween(begin: 1.0, end: 1.2),
                            builder: (_, scale, child) => Transform.scale(
                              scale: scale,
                              child: child,
                            ),
                            child: _chocolateImage(c.type, size: c.size),
                          ),
                        ),
                      );
                    }).toList(),

                    // Dino at current position (over chocolates)
                    Positioned(
                      left: _dinoPosition.dx * 340 - 20,
                      top: _dinoPosition.dy * 160 - 20,
                      child: _dinoImage(size: 40, state: 'idle'),
                    ),

                    // Combo text overlay
                    if (_comboText.isNotEmpty && !isComplete)
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: AnimatedScale(
                            scale: _comboScale,
                            duration: const Duration(milliseconds: 100),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _comboColor.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _comboText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ─── STATS CARDS ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCard('🍫', '$_taps', 'Collected'),
                _statCard('🔥', '${_maxCombo}x', 'Combo'),
                _statCard(
                  '🪙',
                  isComplete ? '+$_finalBonus' : (_skipped ? '0' : '?'),
                  'Coins',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ─── SKIP / CHEST ───
            if (_showSkip && !_loadingComplete && !isError)
              TextButton(
                onPressed: _skipGame,
                child: const Text(
                  'Still Loading? Skip → (No Bonus)',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            if (_chestRevealed)
              Column(
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 4),
                  Text(
                    '+$_finalBonus Coins!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            if (isError)
              const Text(
                'Something went wrong. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBackgroundDecorations() {
    return [
      Positioned(left: 10, top: 10, child: _decorationImage('assets/obstacles/jungle_tree.jpg', size: 30)),
      Positioned(right: 10, bottom: 10, child: _decorationImage('assets/obstacles/jungle_bush.jpg', size: 24)),
      Positioned(left: 20, bottom: 30, child: _decorationImage('assets/obstacles/jungle_rock.jpg', size: 20)),
      Positioned(right: 30, top: 40, child: _decorationImage('assets/obstacles/jungle_palm.jpg', size: 28)),
    ];
  }
}