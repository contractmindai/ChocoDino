// lib/widgets/level_complete_body.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

// ============================================================================
// FUN FACTS — chocolate & dinosaur history, shown after each round
// ============================================================================
class _FunFact {
  final String emoji;
  final String text;
  const _FunFact(this.emoji, this.text);
}

const List<_FunFact> kChocoDinoFunFacts = [
  _FunFact('🍫', 'The word "chocolate" comes from "xocolatl," a word used by the Aztecs for their bitter, spiced cacao drink.'),
  _FunFact('🦖', 'Dinosaur means "terrible lizard" — a name coined by scientist Richard Owen back in 1842.'),
  _FunFact('🍫', 'The ancient Maya were drinking chocolate as a spicy, unsweetened beverage thousands of years before it became a sweet treat.'),
  _FunFact('🦕', 'Birds are actually living dinosaurs — they evolved from small feathered theropods millions of years ago.'),
  _FunFact('🍫', 'The Aztecs prized cacao beans so much that they used them as a form of money.'),
  _FunFact('🦖', 'Fossils show that many dinosaurs, especially smaller ones, were covered in feathers.'),
  _FunFact('🍫', 'Milk chocolate wasn\'t invented until 1875, when Swiss chocolatier Daniel Peter finally cracked the recipe with help from his neighbor Henri Nestlé.'),
  _FunFact('🦕', 'Some sauropod dinosaurs grew to nearly 100 feet long — longer than several school buses parked end to end.'),
  _FunFact('🍫', 'White chocolate isn\'t technically chocolate at all — it\'s made from cocoa butter but has none of the cocoa solids.'),
  _FunFact('🦖', 'The dinosaurs\' reign lasted over 165 million years before an asteroid impact ended it about 66 million years ago.'),
  _FunFact('🍫', 'It takes roughly 400 cacao beans to make just one pound of chocolate.'),
  _FunFact('🦕', 'Not every dinosaur was a giant — some, like Compsognathus, were only about the size of a chicken.'),
  _FunFact('🍫', 'Cacao trees only grow in a narrow band near the equator, often called the "cacao belt."'),
  _FunFact('🦖', 'Triceratops means "three-horned face" — named for the trio of horns on its skull.'),
  _FunFact('🍫', 'Chocolate was once so valuable in Mesoamerica that it was reserved mostly for royalty, warriors, and special ceremonies.'),
  _FunFact('🦕', 'T. rex actually lived closer in time to us than to some earlier dinosaurs, like Stegosaurus, which roamed Earth about 80 million years before it.'),
  _FunFact('🍫', 'Cacao was first used by people in the Amazon region of Ecuador about 5,300 years ago — over a thousand years before it reached Mesoamerica.'),
  _FunFact('🦖', 'Megalosaurus, described in 1824, was the very first dinosaur ever given a scientific name — years before the word "dinosaur" even existed.'),
  _FunFact('🍫', 'The scientific name for the cacao tree, Theobroma cacao, literally means "food of the gods" in Greek.'),
  _FunFact('🦕', 'Spinosaurus is thought to have been even longer than T. rex, and may have spent much of its life swimming and hunting in rivers.'),
  _FunFact('🍫', 'The first solid, eatable chocolate bar was created in 1847 by the British company J.S. Fry & Sons — before that, chocolate was mostly a drink.'),
  _FunFact('🦖', 'Velociraptor was actually about the size of a turkey, not the towering movie-monster it\'s often shown as.'),
  _FunFact('🍫', 'Early Mesoamerican chocolate drinks were often spiced with chili peppers instead of sweetened with sugar.'),
  _FunFact('🦕', 'Dinosaur eggs and nesting sites have been discovered on every continent, including Antarctica.'),
  _FunFact('🦖', 'Pterosaurs and plesiosaurs are often pictured alongside dinosaurs, but technically they belonged to entirely different reptile groups.'),
];

// ============================================================================
// COLOR HELPER — guarantees legible text regardless of how light/pale a
// world's primaryColor is (e.g. the pastel-pink "candy" world).
// ============================================================================
Color _readableTextColor(Color base) {
  final hsl = HSLColor.fromColor(base);
  return hsl
      .withLightness(0.24)
      .withSaturation(hsl.saturation.clamp(0.45, 0.85))
      .toColor();
}

class LevelCompleteBody extends StatefulWidget {
  final ui.Image dinoImage;
  final ui.Image starFilledImage;
  final ui.Image starEmptyImage;
  final int earnedStars;
  final int points;
  final String quote;
  final Color primaryColor;
  final Color secondaryColor;

  const LevelCompleteBody({
    Key? key,
    required this.dinoImage,
    required this.starFilledImage,
    required this.starEmptyImage,
    required this.earnedStars,
    required this.points,
    required this.quote,
    required this.primaryColor,
    required this.secondaryColor,
  }) : super(key: key);

  @override
  State<LevelCompleteBody> createState() => _LevelCompleteBodyState();
}

class _LevelCompleteBodyState extends State<LevelCompleteBody>
    with TickerProviderStateMixin {
  late AnimationController _dinoBobController;
  late AnimationController _pointsController;
  late AnimationController _starController;
  late AnimationController _entryController;
  late AnimationController _factController;

  int _displayPoints = 0;
  List<bool> _starRevealed = [false, false, false];
  late final _FunFact _funFact;

  @override
  void initState() {
    super.initState();
    _dinoBobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pointsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _factController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _funFact = kChocoDinoFunFacts[Random().nextInt(kChocoDinoFunFacts.length)];

    _pointsController.addListener(() {
      setState(() {
        _displayPoints = (_pointsController.value * widget.points).round();
      });
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _entryController.forward();
        _pointsController.forward();
        _revealStars();
      }
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _factController.forward();
      }
    });
  }

  void _revealStars() async {
    for (int i = 0; i < widget.earnedStars; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _starRevealed[i] = true;
        });
        _starController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _dinoBobController.dispose();
    _pointsController.dispose();
    _starController.dispose();
    _entryController.dispose();
    _factController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouncy dino image (no circle, bigger)
        AnimatedBuilder(
          animation: _dinoBobController,
          builder: (context, child) {
            final bob = sin(_dinoBobController.value * 2 * pi) * 8;
            return Transform.translate(
              offset: Offset(0, bob),
              child: child,
            );
          },
          child: AnimatedBuilder(
            animation: _entryController,
            builder: (context, child) {
              final scale = Curves.elasticOut.transform(_entryController.value.clamp(0.0, 1.0));
              return Transform.scale(
                scale: scale,
                child: RawImage(
                  image: widget.dinoImage,
                  width: 180,   // bigger size
                  height: 180,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Congratulatory text
        AnimatedBuilder(
          animation: _entryController,
          builder: (context, child) {
            final opacity = _entryController.value.clamp(0.0, 1.0);
            return Opacity(opacity: opacity, child: child);
          },
          child: Column(
            children: [
              Text(
                'Level Complete!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: _readableTextColor(widget.primaryColor),
                  shadows: const [
                    Shadow(color: Colors.white, blurRadius: 6),
                    Shadow(color: Colors.white, blurRadius: 14),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.quote,
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: _readableTextColor(widget.primaryColor),
                  shadows: const [
                    Shadow(color: Colors.white, blurRadius: 6),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Animated stars
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final revealed = _starRevealed[i];
            return AnimatedBuilder(
              animation: _starController,
              builder: (context, child) {
                final scale = revealed ? 1.0 + 0.3 * _starController.value : 0.5;
                return Transform.scale(
                  scale: scale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: RawImage(
                      image: i < widget.earnedStars
                          ? widget.starFilledImage
                          : widget.starEmptyImage,
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            );
          }),
        ),
        const SizedBox(height: 12),

        // Points count‑up
        AnimatedBuilder(
          animation: _pointsController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Text(
                '+$_displayPoints POINTS',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _readableTextColor(widget.primaryColor),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Fun fact about chocolate & dinosaur history
        AnimatedBuilder(
          animation: _factController,
          builder: (context, child) {
            final t = Curves.easeOut.transform(_factController.value.clamp(0.0, 1.0));
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 12),
                child: child,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.primaryColor.withOpacity(0.35), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_funFact.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      'Did you know?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _readableTextColor(widget.primaryColor),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _funFact.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: _readableTextColor(widget.primaryColor).withOpacity(0.95),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}