// lib/widgets/level_complete_body.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import '../models/sweet_world.dart';

// ============================================================================
// FUN FACTS — world‑specific (short & kid‑friendly)
// ============================================================================
class _FunFact {
  final String emoji;
  final String text;
  const _FunFact(this.emoji, this.text);
}

// General fallback facts (chocolate & dinosaurs) – also short
const List<_FunFact> kGeneralFunFacts = [
  _FunFact('🍫', 'Chocolate comes from the Aztec word "xocolatl".'),
  _FunFact('🦖', 'Dinosaur means "terrible lizard" – coined in 1842.'),
  _FunFact('🍫', 'The Maya drank chocolate thousands of years ago.'),
  _FunFact('🦕', 'Birds are modern‑day dinosaurs.'),
  _FunFact('🍫', 'Aztecs used cacao beans as money.'),
  _FunFact('🦖', 'Many small dinosaurs were covered in feathers.'),
  _FunFact('🍫', 'Milk chocolate was invented in 1875 in Switzerland.'),
  _FunFact('🦕', 'Some sauropods grew longer than a school bus.'),
  _FunFact('🍫', 'White chocolate isn’t real chocolate – it has no cocoa solids.'),
  _FunFact('🦖', 'Dinosaurs ruled Earth for 165 million years.'),
  _FunFact('🍫', 'It takes ~400 cacao beans to make 1 lb of chocolate.'),
  _FunFact('🦕', 'Some dinosaurs were as small as a chicken.'),
  _FunFact('🍫', 'Cacao trees grow only near the equator.'),
  _FunFact('🦖', 'Triceratops means "three‑horned face".'),
  _FunFact('🍫', 'Chocolate was once reserved for royalty and warriors.'),
  _FunFact('🦕', 'T. rex lived closer to us than to Stegosaurus.'),
  _FunFact('🍫', 'Cacao was first used in Ecuador ~5,300 years ago.'),
  _FunFact('🦖', 'Megalosaurus was the first dinosaur ever named.'),
  _FunFact('🍫', 'Theobroma cacao means "food of the gods".'),
  _FunFact('🦕', 'Spinosaurus may have been a swimming dinosaur.'),
  _FunFact('🍫', 'The first chocolate bar was made in 1847 in Britain.'),
  _FunFact('🦖', 'Velociraptor was the size of a turkey.'),
  _FunFact('🍫', 'Ancient chocolate drinks were spiced with chili.'),
  _FunFact('🦕', 'Dinosaur nests have been found on every continent.'),
  _FunFact('🦖', 'Pterosaurs were not dinosaurs – they were flying reptiles.'),
];

// World‑specific facts – all short, fun, and educational for kids
const Map<String, List<_FunFact>> kWorldFunFacts = {
  'jungle': [
    _FunFact('🌳', 'The Amazon produces 20% of Earth\'s oxygen.'),
    _FunFact('🐒', 'The Amazon has 40,000 plant species – more than all of Europe.'),
    _FunFact('🌿', 'One hectare of rainforest can have 750 tree species.'),
    _FunFact('🐆', 'Jaguars have the strongest bite of any big cat.'),
    _FunFact('🍌', 'Bananas are berries – strawberries are not.'),
    _FunFact('🌴', 'The Amazon is the largest river by volume.'),
    _FunFact('🐸', 'Poison dart frogs are harmless in captivity.'),
    _FunFact('🦜', 'Macaws can live up to 80 years.'),
    _FunFact('🌺', 'The largest flower, Rafflesia, grows in SE Asia.'),
    _FunFact('🐍', 'Anacondas can stay underwater for 10 minutes.'),
    _FunFact('🦋', 'Some butterflies taste with their feet!'),
    _FunFact('🐜', 'Leafcutter ants carry leaves 50 times their weight.'),
    _FunFact('🌳', 'Kapok trees can grow up to 200 feet tall.'),
    _FunFact('🌧️', 'Rainforests get up to 400 inches of rain a year.'),
    _FunFact('🐬', 'Pink river dolphins live in the Amazon.'),
  ],
  'ice': [
    _FunFact('❄️', 'Antarctica is the coldest, windiest, driest continent.'),
    _FunFact('🧊', 'Antarctica holds 70% of the world\'s fresh water.'),
    _FunFact('🐧', 'Emperor penguins can dive 500 metres deep.'),
    _FunFact('🦭', 'Weddell seals can hold their breath for 80 minutes.'),
    _FunFact('🌨️', 'Antarctica\'s record high is only 18°C.'),
    _FunFact('🧊', 'Icebergs can be larger than small countries.'),
    _FunFact('🐋', 'Humpback whales travel to polar seas to feed.'),
    _FunFact('❄️', 'Snow is translucent, not white.'),
    _FunFact('🦊', 'Arctic foxes change fur colour with the seasons.'),
    _FunFact('🌌', 'The Northern Lights are best seen in polar regions.'),
    _FunFact('❄️', 'The coldest place on Earth is -89°C (-128°F).'),
    _FunFact('🐧', 'There are 17 different species of penguins.'),
    _FunFact('🦭', 'Polar bear fur is actually transparent, not white!'),
    _FunFact('🧊', 'Glacial ice can be over 100,000 years old.'),
    _FunFact('🌊', 'The Arctic Ocean is the smallest ocean on Earth.'),
  ],
  'candy': [
    _FunFact('🍭', 'The word "lollipop" comes from a candy tree.'),
    _FunFact('🍬', 'Gummy bears were invented in Germany in 1922.'),
    _FunFact('🍭', 'The world\'s largest lollipop weighed 3,000 pounds.'),
    _FunFact('🍬', 'Cotton candy is 99% sugar.'),
    _FunFact('🍭', 'The first chocolate bar was made in 1847.'),
    _FunFact('🍬', 'Licorice root has been used as medicine for 4,000 years.'),
    _FunFact('🍭', 'Twix is the world\'s most popular candy.'),
    _FunFact('🍬', 'Marshmallows were originally made from marshmallow root.'),
    _FunFact('🍭', 'The word "candy" comes from the Arabic word "qandi".'),
    _FunFact('🍬', 'Jelly beans have been around since the 1860s.'),
    _FunFact('🍭', 'The longest candy cane was over 50 feet long.'),
    _FunFact('🍬', 'Chocolate has over 600 flavour compounds – more than wine!'),
    _FunFact('🍩', 'The world\'s largest donut weighed over 1.7 tons.'),
    _FunFact('🍫', 'It takes 2–4 days to make a chocolate bar.'),
    _FunFact('🍬', 'The first candy was eaten over 4,000 years ago in Egypt.'),
  ],
  'volcano': [
    _FunFact('🌋', 'Volcanoes are named after Vulcan, the Roman god of fire.'),
    _FunFact('🔥', 'Lava can flow at up to 60 km/h – faster than a person.'),
    _FunFact('🌋', 'Over 80% of Earth\'s surface is volcanic in origin.'),
    _FunFact('💥', 'The 1815 Tambora eruption caused a "year without summer".'),
    _FunFact('🌋', 'Iceland has over 30 active volcanoes.'),
    _FunFact('🔥', 'Lava can reach 1,200°C – hot enough to melt steel.'),
    _FunFact('🌋', 'The Ring of Fire contains 75% of the world\'s volcanoes.'),
    _FunFact('💨', 'Volcanic ash can travel hundreds of kilometres.'),
    _FunFact('🌋', 'Mauna Loa is the largest volcano on Earth.'),
    _FunFact('🔥', 'Some volcanoes erupt mud or ice instead of lava.'),
    _FunFact('🌋', 'There are over 1,500 active volcanoes on Earth.'),
    _FunFact('💨', 'Volcanoes can create lightning during eruptions.'),
    _FunFact('🌋', 'Olympus Mons on Mars is 2.5x taller than Everest.'),
    _FunFact('🪨', 'Pumice, a volcanic rock, can float on water.'),
    _FunFact('🌋', 'Volcanic ash can reach the stratosphere.'),
  ],
  'space': [
    _FunFact('🪐', 'Saturn\'s rings are made of billions of ice particles.'),
    _FunFact('🌟', 'Light takes 8 minutes to travel from the Sun to Earth.'),
    _FunFact('🚀', 'The first human‑made object in space was the V‑2 rocket in 1944.'),
    _FunFact('🪐', 'Jupiter is 1,300 times bigger than Earth.'),
    _FunFact('🌌', 'The Milky Way has 100–400 billion stars.'),
    _FunFact('🌟', 'A sugar‑cube‑sized neutron star weighs as much as all of humanity.'),
    _FunFact('🚀', 'Apollo missions brought back 380 kg of Moon rocks.'),
    _FunFact('🪐', 'Jupiter\'s Great Red Spot is a storm raging for 350+ years.'),
    _FunFact('🌌', 'The universe is ~13.8 billion years old.'),
    _FunFact('🌟', 'There are more stars than grains of sand on all beaches.'),
    _FunFact('💫', 'A day on Venus is longer than a year on Venus.'),
    _FunFact('🌙', 'Jupiter has over 90 known moons (Earth has only 1!).'),
    _FunFact('☀️', 'The Sun is a star, just like the night‑time stars.'),
    _FunFact('🪐', 'Saturn could float in a giant bathtub – it\'s lighter than water!'),
    _FunFact('🌍', 'Earth is the only planet not named after a Greek or Roman god.'),
  ],
};

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
  final SweetWorld world;

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
    required this.world,
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

    // Pick a random fact based on the current world
    final worldFacts = kWorldFunFacts[widget.world.obstacleKey] ?? kGeneralFunFacts;
    _funFact = worldFacts[Random().nextInt(worldFacts.length)];

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
                  width: 180,
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

        // Fun fact – world‑specific (short)
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
                const SizedBox(height: 4),
                Text(
                  _funFact.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
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