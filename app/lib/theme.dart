import 'package:flutter/material.dart';

/// 芥菜种 mustardseed 色板（对齐 src/site.css）
abstract class AppColors {
  static const bg = Color(0xFF16281C); // --bg
  static const bgRaised = Color(0xFF1D3526); // --bg-raised
  static const bgCard = Color(0xFF1A3122); // --bg-card
  static const mustard = Color(0xFFE0AE33); // --mustard
  static const mustardSoft = Color(0xFFF0C868); // --mustard-soft
  static const terra = Color(0xFFD98E5A); // --terra
  static const terraSoft = Color(0xFFE8B088);
  static const sprout = Color(0xFF8FBF5F); // --sprout
  static const cream = Color(0xFFF3EBD8); // --cream
  static const creamDim = Color(0xB8F3EBD8); // rgba(243,235,216,.72)
  static const creamFaint = Color(0x6BF3EBD8); // rgba(243,235,216,.42)
  static const line = Color(0x29E0AE33); // rgba(224,174,51,.16)
  static const lineStrong = Color(0x4DE0AE33); // rgba(224,174,51,.30)
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.mustard,
      brightness: Brightness.dark,
      primary: AppColors.mustard,
      secondary: AppColors.terra,
      tertiary: AppColors.sprout,
      surface: AppColors.bg,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgRaised,
      foregroundColor: AppColors.cream,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.cream,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: .5,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgRaised,
      selectedItemColor: AppColors.mustard,
      unselectedItemColor: AppColors.creamFaint,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    cardTheme: CardThemeData(
      color: AppColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.cream,
      displayColor: AppColors.cream,
    ),
  );
}
