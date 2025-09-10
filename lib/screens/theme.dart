import 'package:flutter/material.dart';

/// Global PixiePen theme colors
const kAppPrimary = Color(0xFF7B1FA2);

final appTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Poppins',
  colorScheme: ColorScheme.fromSeed(
    seedColor: kAppPrimary,
    primary: kAppPrimary,
    secondary: kAppPrimary,
  ),
);
