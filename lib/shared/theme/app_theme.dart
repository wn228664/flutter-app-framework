// 主题基础：集中管理中性颜色和可变字体；浅色外部配置严格解析并回退，深色由 Material 色种生成。

import 'package:flutter/material.dart';
import '../../core/models/theme_config.dart';

/// 框架中性基础色常量，供主题及通用插画共用，不承载业务品牌状态。
abstract final class AppColors {
  /// 默认正文深色，浅色主题未配置 textColor 时使用。
  static const ink = Color(0xFF202226);

  /// 次级文字的中性灰色，供调用方需要固定浅色语义时使用。
  static const secondaryText = Color(0xFF667085);

  /// 浅色卡片、输入框和细分隔边界的默认描边色。
  static const divider = Color(0xFFE3E7EB);

  /// 浅色页面默认背景色，与白色卡片区分层级。
  static const surface = Color(0xFFF4F6F7);

  /// 可选暖色表面，用于中性展示区，不随业务状态变化。
  static const paper = Color(0xFFFFF8ED);

  /// 默认主色，也是深色色种和网络插画的强调色。
  static const brand = Color(0xFF1677FF);

  /// 默认辅助强调色，浅色主题映射到 secondary。
  static const accent = Color(0xFF17745F);
}

/// 统一生成 Material 3 主题、组件外观及 NotoSansSC 可变字体字重。
abstract final class AppTheme {
  /// 从默认主色生成深色 ColorScheme，沿用统一字体；不读取浅色外部配置。
  static ThemeData dark() {
    // scheme：Material 根据品牌种子和深色亮度生成的语义色集合。
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

  /// 生成浅色主题；颜色只接受 #RRGGBB，圆角限制为 0 到 16，关闭默认水波与悬停底色。
  /// config：可选外观配置；缺失或颜色格式非法时采用 AppColors 默认值。
  static ThemeData light([ThemeConfig? config]) {
    // primary：合法配置主色或默认品牌色，供按钮和主色语义使用。
    final primary = _parseColor(config?.primaryColor) ?? AppColors.brand;
    // accent：合法配置辅助色或默认辅助色。
    final accent = _parseColor(config?.accentColor) ?? AppColors.accent;
    // surface：Scaffold 背景色；卡片表面仍使用白色。
    final surface = _parseColor(config?.surfaceColor) ?? AppColors.surface;
    // text：正文及 onSurface 使用的颜色，非法配置回退默认深色。
    final text = _parseColor(config?.textColor) ?? AppColors.ink;
    // radius：将配置圆角夹取到 0 至 16 后的逻辑像素值。
    final radius = (config?.cornerRadius ?? 8).clamp(0, 16).toDouble();
    // scheme：以主辅色生成的浅色语义色，显式固定白色表面和正文色。
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
        backButtonIconBuilder: /* 统一 Material 返回按钮为 iOS 风格箭头，不修改导航行为。
         * 忽略的图标构建上下文；箭头大小与图形固定。 */ (_) =>
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

  /// 仅解析六位十六进制颜色并补不透明 alpha；空值或格式错误返回 null 以触发默认色。
  /// value：可空的 #RRGGBB 颜色字符串，不接受缩写或 alpha 扩展。
  static Color? _parseColor(String? value) {
    if (value == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      return null;
    }
    return Color(int.parse('FF${value.substring(1)}', radix: 16));
  }

  /// 为 Material 文本角色统一设置 NotoSansSC 和 wght 400，组件可再显式覆盖强调字重。
  /// text：基础正文和展示文字颜色。
  static TextTheme _variableTextTheme(Color text) {
    // base：Flutter 浅色基础字级应用统一字体与文字颜色后的 TextTheme。
    final base = ThemeData.light().textTheme.apply(
      bodyColor: text,
      displayColor: text,
      fontFamily: 'NotoSansSC',
    );

    /// 为非空文字样式同时设置 FontWeight 和可变字体 wght 轴，保持实际字重一致。
    /// style：单个 Material 文字角色样式，空角色保持为空。
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
