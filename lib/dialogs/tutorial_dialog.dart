// lib/dialogs/tutorial_dialog.dart
import 'package:flutter/material.dart';
import '../models/sweet_world.dart';
import '../widgets/theme_widgets.dart';

class TutorialDialog extends StatefulWidget {
  final VoidCallback onDismiss;

  const TutorialDialog({
    Key? key,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  int _currentStep = 0;

  // Dummy world for buttons (tutorial is world‑agnostic)
  final SweetWorld _tutorialWorld = const SweetWorld(
    name: 'Tutorial',
    emoji: '📚',
    primaryColor: Color(0xFF8D6E63),
    secondaryColor: Color(0xFFA1887F),
    tileColor: Color(0xFFEFEBE9),
    pathColor: Color(0xFFBCAAA4),
    accentColor: Color(0xFFD7CCC8),
    particleColors: [Color(0xFF8D6E63), Color(0xFFA1887F)],
    backgroundImagePath: '',
    obstacleKey: '',
    chocolateImagePath: '',
    obstacleEmojis: [],
    unlockPrice: 0,   // was: unlockLevel: null
  );

  final List<Map<String, dynamic>> _steps = [
    {
      'icon': Icons.swipe,
      'title': 'Draw a Path',
      'body': 'Drag your finger across the grid to guide your dino to the next chocolate.\n\n'
          'You can move up, down, left, or right – but only one step at a time.',
    },
    {
      'icon': Icons.auto_awesome,
      'title': 'Collect & Avoid',
      'body': 'Reach all chocolates to win!\n\n'
          'Watch out for mines, enemies, and fire hazards – they cost you chances.\n'
          'Tap a chocolate after a few mistakes to auto‑draw the safest route.',
    },
  ];

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: BorderSide(color: const Color(0xFF8D6E63).withOpacity(0.5), width: 3),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Step dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (i) {
                return Container(
                  width: i == _currentStep ? 12 : 8,
                  height: i == _currentStep ? 12 : 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _currentStep
                        ? const Color(0xFF8D6E63)
                        : const Color(0xFF8D6E63).withOpacity(0.3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            // Icon
            Icon(
              step['icon'] as IconData,
              size: 64,
              color: const Color(0xFF8D6E63),
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              step['title'] as String,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8D6E63),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Body
            Text(
              step['body'] as String,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  CartoonButton(
                    world: _tutorialWorld,
                    label: 'Back',
                    primary: false,
                    icon: Icons.arrow_back,
                    onPressed: () {
                      if (_currentStep > 0) {
                        setState(() => _currentStep--);
                      }
                    },
                  )
                else
                  const SizedBox.shrink(),
                CartoonButton(
                  world: _tutorialWorld,
                  label: isLast ? 'Start Playing' : 'Next',
                  primary: true,
                  icon: isLast ? Icons.play_arrow : Icons.arrow_forward,
                  onPressed: _nextStep,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}