import 'json_readers.dart';
import 'json_types.dart';

class ThemeConfig {
  const ThemeConfig({
    required this.primaryColor,
    required this.accentColor,
    required this.surfaceColor,
    required this.textColor,
    required this.cornerRadius,
  });
  factory ThemeConfig.fromJson(JsonMap json) => ThemeConfig(
    primaryColor: readString(json, 'primaryColor', fallback: '#1677FF'),
    accentColor: readString(json, 'accentColor', fallback: '#17745F'),
    surfaceColor: readString(json, 'surfaceColor', fallback: '#F6F7F8'),
    textColor: readString(json, 'textColor', fallback: '#202226'),
    cornerRadius: readInt(json, 'cornerRadius', fallback: 8),
  );
  final String primaryColor;
  final String accentColor;
  final String surfaceColor;
  final String textColor;
  final int cornerRadius;
}
