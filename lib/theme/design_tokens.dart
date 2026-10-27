// lib/theme/design_tokens.dart
//
// Shared design tokens for ChocoDino. Every screen and widget should pull
// spacing, radius, and font sizes from here instead of hardcoding numbers —
// that's what turns "looks consistent by accident" into "is consistent by
// construction." Numbers were chosen to match the values already dominant
// across the app (e.g. 16/20/28 radii, 14/16/22/28 fonts), so adopting this
// is a naming/consolidation pass, not a visual overhaul.

import 'package:flutter/material.dart';

/// Spacing scale — use for padding, SizedBox gaps, and margins.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Corner radius scale. Collapses the 9 ad-hoc values previously in use
/// (10/12/14/16/20/24/28/30/40) down to 5 named steps with clear intent:
///  - [sm]   small chips, badges, input fields
///  - [md]   buttons, cards, list tiles
///  - [lg]   prominent cards (shop items, mode cards)
///  - [xl]   dialogs, sheets, hero cards
///  - [pill] fully-rounded pill buttons / capsule badges
class AppRadius {
  AppRadius._();
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

/// Font-size scale. Use with the semantic [AppTextStyles] below where
/// possible instead of raw `fontSize:` numbers.
class AppFontSize {
  AppFontSize._();
  static const double caption = 12;
  static const double body = 14;
  static const double bodyLarge = 16;
  static const double title = 20;
  static const double headline = 24;
  static const double display = 28;
  static const double hero = 32;
}

/// Ready-to-use text styles built from the scale above. Screens can still
/// override `color`/`fontWeight` per use via `.copyWith(...)`.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle caption = TextStyle(
    fontSize: AppFontSize.caption,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle body = TextStyle(
    fontSize: AppFontSize.body,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyBold = TextStyle(
    fontSize: AppFontSize.bodyLarge,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle title = TextStyle(
    fontSize: AppFontSize.title,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headline = TextStyle(
    fontSize: AppFontSize.headline,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle hero = TextStyle(
    fontSize: AppFontSize.hero,
    fontWeight: FontWeight.w900,
  );
}

/// Elevation / shadow presets, so "how strong should this shadow be"
/// stops being a per-widget guess.
class AppElevation {
  AppElevation._();

  static List<BoxShadow> soft(Color color) => [
        BoxShadow(color: color.withOpacity(0.20), blurRadius: 10, offset: const Offset(0, 4)),
      ];

  static List<BoxShadow> medium(Color color) => [
        BoxShadow(color: color.withOpacity(0.30), blurRadius: 16, offset: const Offset(0, 6)),
      ];

  static List<BoxShadow> strong(Color color) => [
        BoxShadow(color: color.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 12)),
      ];
}

/// Minimum interactive target size per Material/iOS accessibility
/// guidelines. Wrap small tappables with [AppTouchTarget.ensure] so they
/// never end up smaller than this, regardless of their visible size.
class AppTouchTarget {
  AppTouchTarget._();
  static const double minSize = 44;

  /// Guarantees [child] occupies at least [minSize] x [minSize], centering
  /// the (possibly smaller) visible content within that tappable area.
  static Widget ensure({required Widget child, double size = minSize}) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      child: Center(child: child),
    );
  }
}