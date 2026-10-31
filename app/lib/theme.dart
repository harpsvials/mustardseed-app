import 'package:flutter/material.dart';

/// 芥菜种 mustardseed 色板（对齐 src/site.css）
/// 支持明亮 / 暗色双主题：切换 `AppColors.isLight` 后全局取色自动跟随。
abstract class AppColors {
  AppColors._();

  /// 当前是否明亮主题（由 main.dart 切换时设置）
  static bool isLight = false;

  // —— 暗色（默认，对齐 --bg 等）——
  static const _bgD = Color(0xFF16281C); // --bg
  static const _bgRaisedD = Color(0xFF1D3526); // --bg-raised
  static const _bgCardD = Color(0xFF1A3122); // --bg-card
  static const _mustardD = Color(0xFFE0AE33); // --mustard
  static const _mustardSoftD = Color(0xFFF0C868); // --mustard-soft
  static const _terraD = Color(0xFFD98E5A); // --terra
  static const _terraSoftD = Color(0xFFE8B088);
  static const _sproutD = Color(0xFF8FBF5F); // --sprout
  static const _creamD = Color(0xFFF3EBD8); // --cream
  static const _creamDimD = Color(0xB8F3EBD8); // rgba(243,235,216,.72)
  static const _creamFaintD = Color(0x6BF3EBD8); // rgba(243,235,216,.42)
  static const _lineD = Color(0x29E0AE33); // rgba(224,174,51,.16)
  static const _lineStrongD = Color(0x4DE0AE33); // rgba(224,174,51,.30)

  // —— 明亮（html[data-theme=light] 对齐）——
  static const _bgL = Color(0xFFF6F0E2); // --bg
  static const _bgRaisedL = Color(0xFFEFE8D6); // --bg-raised
  static const _bgCardL = Color(0xFFFFFDF7); // --bg-card
  static const _mustardL = Color(0xFFB98A1C); // --mustard
  static const _mustardSoftL = Color(0xFFC79A2E); // --mustard-soft
  static const _terraL = Color(0xFFC87B45); // --terra
  static const _terraSoftL = Color(0xFFD6935E);
  static const _sproutL = Color(0xFF6E9A45); // --sprout
  static const _creamL = Color(0xFF24301B); // --cream
  static const _creamDimL = Color(0xB824301B); // rgba(36,48,27,.72)
  static const _creamFaintL = Color(0x6B24301B); // rgba(36,48,27,.42)
  static const _lineL = Color(0x38B08A2A); // rgba(176,138,42,.22)
  static const _lineStrongL = Color(0x6BB08A2A); // rgba(176,138,42,.42)

  static Color get bg => isLight ? _bgL : _bgD;
  static Color get bgRaised => isLight ? _bgRaisedL : _bgRaisedD;
  static Color get bgCard => isLight ? _bgCardL : _bgCardD;
  static Color get mustard => isLight ? _mustardL : _mustardD;
  static Color get mustardSoft => isLight ? _mustardSoftL : _mustardSoftD;
  static Color get terra => isLight ? _terraL : _terraD;
  static Color get terraSoft => isLight ? _terraSoftL : _terraSoftD;
  static Color get sprout => isLight ? _sproutL : _sproutD;
  static Color get cream => isLight ? _creamL : _creamD;
  static Color get creamDim => isLight ? _creamDimL : _creamDimD;
  static Color get creamFaint => isLight ? _creamFaintL : _creamFaintD;
  static Color get line => isLight ? _lineL : _lineD;
  static Color get lineStrong => isLight ? _lineStrongL : _lineStrongD;
}

ThemeData buildAppTheme() {
  final isLight = AppColors.isLight;
  final base = ThemeData(
    useMaterial3: true,
    brightness: isLight ? Brightness.light : Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.mustard,
      brightness: isLight ? Brightness.light : Brightness.dark,
      primary: AppColors.mustard,
      secondary: AppColors.terra,
      tertiary: AppColors.sprout,
      surface: AppColors.bg,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
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
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
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
        side: BorderSide(color: AppColors.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: AppColors.line),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.cream,
      displayColor: AppColors.cream,
    ),
  );
}
