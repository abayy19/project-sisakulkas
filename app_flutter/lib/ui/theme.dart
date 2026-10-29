import 'package:flutter/material.dart';

/// Warna sama dengan versi web: tema "pintu kulkas".
class AppColors {
  static const fridge = Color(0xFFE3EEEB);
  static const fridgeDeep = Color(0xFFCFE0DB);
  static const ink = Color(0xFF13292B);
  static const mute = Color(0xFF4E6668);
  static const chili = Color(0xFFD8382A);
  static const pandan = Color(0xFF1F6B4B);
  static const butter = Color(0xFFFFE680);

  static const boxPalette = <Color>[
    Color(0xFFD8382A),
    Color(0xFF1F6B4B),
    Color(0xFFE0A100),
    Color(0xFF2B6CB0),
    Color(0xFF8E44AD),
    Color(0xFFD2691E),
    Color(0xFF0F8B8D),
    Color(0xFFC2185B),
  ];
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.chili,
    primary: AppColors.chili,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.fridge,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.fridge,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          color: AppColors.ink, fontSize: 22, fontWeight: FontWeight.w800),
    ),
  );
}
