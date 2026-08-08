import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Primary button (filled) – uses sentence case, with a tactile press-scale
/// so taps feel responsive rather than a flat static ElevatedButton.
class IOSPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final double fontSize;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;

  const IOSPrimaryButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.fontSize = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 5,
  }) : super(key: key);

  @override
  State<IOSPrimaryButton> createState() => _IOSPrimaryButtonState();
}

class _IOSPrimaryButtonState extends State<IOSPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: ElevatedButton(
          onPressed: null, // tap handled by GestureDetector above
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.backgroundColor ?? Colors.orange,
            foregroundColor: widget.foregroundColor ?? Colors.white,
            disabledBackgroundColor: widget.backgroundColor ?? Colors.orange,
            disabledForegroundColor: widget.foregroundColor ?? Colors.white,
            padding: widget.padding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: _pressed ? widget.elevation * 0.4 : widget.elevation,
            textStyle: TextStyle(fontSize: widget.fontSize), // prevents auto-uppercase
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

/// Secondary button (outlined), same tactile press-scale as the primary.
class IOSSecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final double fontSize;
  final EdgeInsets padding;

  const IOSSecondaryButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.fontSize = 16,
    this.padding = const EdgeInsets.symmetric(vertical: 14),
  }) : super(key: key);

  @override
  State<IOSSecondaryButton> createState() => _IOSSecondaryButtonState();
}

class _IOSSecondaryButtonState extends State<IOSSecondaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: OutlinedButton(
          onPressed: null, // tap handled by GestureDetector above
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.brown,
            disabledForegroundColor: Colors.brown,
            side: BorderSide(color: _pressed ? Colors.brown.shade300 : Colors.brown, width: 2),
            padding: widget.padding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            textStyle: TextStyle(fontSize: widget.fontSize),
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}