// lib/dialogs/tutorial_dialog.dart
import 'package:flutter/material.dart';
import '../models/sweet_world.dart';
import '../widgets/theme_widgets.dart';   // CartoonButton, showCartoonDialog

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

  // A dummy SweetWorld for the CartoonButton (tutorial is world‑agnostic)
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
    unlockLevel: null,
  );

  final List<Map<String, dynamic>> _steps = [
    {
      'icon': Icons.swipe,
      'title': 'Draw a Path',
      'body': 'Drag across the grid to guide your dino to the next chocolate.\n\n'
          'You can only move to adjacent cells (up, down, left, right).',
    },
    {
      'icon': Icons.warning_amber_rounded,
      'title': 'Watch Out for Obstacles',
      'body': 'Mines, enemies and fire hazards will hurt your dino.\n\n'
          'Avoid them by drawing a path that goes around them.',
    },
    {
      'icon': Icons.auto_fix_high,
      'title': 'Tap Assist',
      'body': 'After a few mistakes, you can tap a chocolate to automatically\n'
          'draw the shortest safe path to it.',
    },
    {
      'icon': Icons.star_rounded,
      'title': 'Earn Stars',
      'body': 'Complete levels with fewer steps and more chances remaining\n'
          'to earn up to 3 stars!',
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
            // Step counter (dots)
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
            // Button(s)
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
                  label: isLast ? 'Start' : 'Next',
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