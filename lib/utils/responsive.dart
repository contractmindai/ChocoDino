import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;

  static double getGridCrossAxisExtent(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 400) return 80;
    if (w < 600) return 100;
    return 120;
  }

  static double getMaxDialogWidth(BuildContext context) =>
      isTablet(context) ? 500 : 360;
}