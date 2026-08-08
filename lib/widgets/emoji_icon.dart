import 'package:flutter/material.dart';

/// A polished icon glyph: renders a bundled image asset when one exists,
/// and falls back to a styled emoji when it doesn't — the same
/// image-with-graceful-fallback pattern [ChocoDinoLogo] already uses.
/// This means real art can be dropped into `assets/` later with zero
/// further code changes, while shipping a working, good-looking UI today.
///
/// Set [badge] to wrap the glyph in a soft gradient circle with a shadow
/// and hairline border — the "production" touch that turns a bare emoji
/// into something that reads as a designed icon.
class EmojiIcon extends StatelessWidget {
  final String emoji;
  final String? assetPath;
  final double size;
  final bool badge;
  final double badgePadding;
  final List<Color>? badgeGradient;
  final Color? badgeColor;

  const EmojiIcon(
    this.emoji, {
    Key? key,
    this.assetPath,
    this.size = 28,
    this.badge = false,
    this.badgePadding = 10,
    this.badgeGradient,
    this.badgeColor,
  }) : super(key: key);

  Widget _glyph() {
    if (assetPath == null) {
      return Text(emoji, style: TextStyle(fontSize: size, height: 1));
    }
    return Image.asset(
      assetPath!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Text(emoji, style: TextStyle(fontSize: size, height: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glyph = _glyph();
    if (!badge) return glyph;

    final gradient = badgeGradient;
    final shadowColor = (gradient?.first ?? badgeColor ?? Colors.black87);

    return Container(
      padding: EdgeInsets.all(badgePadding),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient != null
            ? LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: gradient == null ? (badgeColor ?? Colors.white.withOpacity(0.25)) : null,
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: glyph,
    );
  }
}