import 'package:flutter/material.dart';

class Responsive {
  static Size size(BuildContext context) => MediaQuery.sizeOf(context);

  static double width(BuildContext context) => size(context).width;

  static double height(BuildContext context) => size(context).height;

  static bool isSmall(BuildContext context) => width(context) < 360;

  static bool isTablet(BuildContext context) => width(context) >= 768;

  static double wp(BuildContext context, double percent) {
    return width(context) * (percent / 100);
  }

  static double hp(BuildContext context, double percent) {
    return height(context) * (percent / 100);
  }
}
