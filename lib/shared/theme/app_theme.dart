import 'package:flutter/material.dart';
import '../../core/models/theme_config.dart';

abstract final class AppColors {
  static const ink = Color(0xFF202226);
  static const secondaryText = Color(0xFF667085);
  static const divider = Color(0xFFE3E7EB);
  static const surface = Color(0xFFF4F6F7);
  static const paper = Color(0xFFFFF8ED);
  static const brand = Color(0xFF1677FF);
  static const accent = Color(0xFF17745F);
}

abstract final class AppTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'NotoSansSC',
      textTheme: _variableTextTheme(scheme.onSurface),
    );
  }

  static ThemeData light([ThemeConfig? config]) {
    final primary = _parseColor(config?.primaryColor) ?? AppColors.brand;
    final accent = _parseColor(config?.accentColor) ?? AppColors.accent;
    final surface = _parseColor(config?.surfaceColor) ?? AppColors.surface;
    final text = _parseColor(config?.textColor) ?? AppColors.ink;
    final radius = (config?.cornerRadius ?? 8).clamp(0, 16).toDouble();
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: Colors.white,
      brightness: Brightness.light,
    ).copyWith(onSurface: text);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      fontFamily: 'NotoSansSC',
      textTheme: _variableTextTheme(text),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        toolbarHeight: 44,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: text,
        iconTheme: const IconThemeData(size: 20),
        actionsIconTheme: const IconThemeData(size: 20),
        titleTextStyle: TextStyle(
          color: text,
          fontFamily: 'NotoSansSC',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          fontVariations: const [FontVariation('wght', 600)],
        ),
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) =>
            const Icon(Icons.arrow_back_ios_new, size: 20),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEDEDED),
        thickness: 0.5,
        space: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.divider),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          elevation: 0,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: primary.withValues(alpha: 0.12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.divider),
          borderRadius: BorderRadius.circular(radius),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.divider),
          borderRadius: BorderRadius.circular(radius),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.divider),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  static Color? _parseColor(String? value) {
    if (value == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      return null;
    }
    return Color(int.parse('FF${value.substring(1)}', radix: 16));
  }

  static TextTheme _variableTextTheme(Color text) {
    final base = ThemeData.light().textTheme.apply(
      bodyColor: text,
      displayColor: text,
      fontFamily: 'NotoSansSC',
    );
    TextStyle? withWeight(TextStyle? style) {
      if (style == null) return null;
      return style.copyWith(
        fontWeight: FontWeight.w400,
        fontVariations: const [FontVariation('wght', 400)],
      );
    }

    return base.copyWith(
      displayLarge: withWeight(base.displayLarge),
      displayMedium: withWeight(base.displayMedium),
      displaySmall: withWeight(base.displaySmall),
      headlineLarge: withWeight(base.headlineLarge),
      headlineMedium: withWeight(base.headlineMedium),
      headlineSmall: withWeight(base.headlineSmall),
      titleLarge: withWeight(base.titleLarge),
      titleMedium: withWeight(base.titleMedium),
      titleSmall: withWeight(base.titleSmall),
      bodyLarge: withWeight(base.bodyLarge),
      bodyMedium: withWeight(base.bodyMedium),
      bodySmall: withWeight(base.bodySmall),
      labelLarge: withWeight(base.labelLarge),
      labelMedium: withWeight(base.labelMedium),
      labelSmall: withWeight(base.labelSmall),
    );
  }
}
