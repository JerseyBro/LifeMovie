library;

import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 24.0;
}

abstract final class AppRadius {
  static const card = 20.0;
  static const button = 14.0;
}

abstract final class AppColor {
  static const ink = Color(0xff1f2933);
  static const canvas = Color(0xfff5f4f0);
  static const accent = Color(0xff496b55);
}

ThemeData buildNeutralTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColor.canvas,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColor.accent),
  cardTheme: const CardThemeData(margin: EdgeInsets.zero),
);
