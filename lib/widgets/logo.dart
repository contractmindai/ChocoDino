import 'package:flutter/material.dart';

/// A logo widget that shows an image asset if available, otherwise a text fallback.
class ChocoDinoLogo extends StatelessWidget {
  final double fontSize;
  final bool showIcon;

  const ChocoDinoLogo({
    Key? key,
    this.fontSize = 22,
    this.showIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      height: fontSize * 1.3,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _textLogo(),
    );
  }

  Widget _textLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) const Text('🦕', style: TextStyle(fontSize: 22)),
        if (showIcon) const SizedBox(width: 4),
        Text(
          'ChocoDino',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: const [
              Shadow(offset: Offset(1, 1), color: Colors.black26),
            ],
          ),
        ),
      ],
    );
  }
}