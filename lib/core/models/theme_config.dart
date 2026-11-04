// 外观数据模型：严格读取颜色字符串与圆角整数；颜色语法回退和圆角夹取由 AppTheme 执行。

import 'json_readers.dart';
import 'json_types.dart';

/// 可选主题配置的只读字段集合；模型只校验 JSON 类型，实际样式安全范围交给 AppTheme。
class ThemeConfig {
  /// 保存调用方提供的主题字段，不在构造器中解析颜色或限制圆角。
  /// primaryColor：品牌主色文本，由主题层验证 #RRGGBB。
  /// accentColor：辅助强调色文本，供 ColorScheme.secondary 使用。
  /// surfaceColor：页面背景色文本，供 Scaffold 使用。
  /// textColor：正文前景色文本，供主题文字与 onSurface 使用。
  /// cornerRadius：圆角逻辑像素值，主题层限制在 0 到 16。
  const ThemeConfig({
    required this.primaryColor,
    required this.accentColor,
    required this.surfaceColor,
    required this.textColor,
    required this.cornerRadius,
  });

  /// 读取主题 JSON；缺失字段采用中性默认值，错误字段类型抛 FormatException。
  /// json：外部主题对象，不包含用户凭证或业务数据。
  factory ThemeConfig.fromJson(JsonMap json) => ThemeConfig(
    primaryColor: readString(json, 'primaryColor', fallback: '#1677FF'),
    accentColor: readString(json, 'accentColor', fallback: '#17745F'),
    surfaceColor: readString(json, 'surfaceColor', fallback: '#F6F7F8'),
    textColor: readString(json, 'textColor', fallback: '#202226'),
    cornerRadius: readInt(json, 'cornerRadius', fallback: 8),
  );

  /// 品牌主色；JSON 缺失默认 #1677FF，非法颜色格式在主题层回退。
  final String primaryColor;

  /// 辅助强调色；JSON 缺失默认 #17745F。
  final String accentColor;

  /// 页面背景色；JSON 缺失默认 #F6F7F8。
  final String surfaceColor;

  /// 正文颜色；JSON 缺失默认 #202226。
  final String textColor;

  /// 圆角逻辑像素整数；JSON 缺失默认 8，应用样式时再夹取范围。
  final int cornerRadius;
}
