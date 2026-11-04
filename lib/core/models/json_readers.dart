// 严格 JSON 读取器：仅缺失标量使用 fallback；错误类型、非有限数和错误嵌套键均抛 FormatException，不静默强转。

import 'json_types.dart';

/// 读取字符串字段；缺失或 null 返回 fallback，其他类型抛 FormatException。
/// json：待读取的 String 键 JSON 对象。
/// key：目标字符串字段名，也用于错误提示定位。
/// fallback：缺失或 null 时的字符串，默认空串。
String readString(JsonMap json, String key, {String fallback = ''}) {
  // value：目标字段原值，先区分缺失再检查字符串类型。
  final value = json[key];
  if (value == null) return fallback;
  if (value is String) return value;
  throw FormatException('$key must be a string');
}

/// 读取有限的整数数值；允许数学上为整数的 num，不解析字符串、不截断小数。
/// json：待读取整数的 JSON 对象。
/// key：目标整数字段名。
/// fallback：缺失或 null 时的整数，默认 0。
int readInt(JsonMap json, String key, {int fallback = 0}) {
  // value：待验证的原始数值，必须有限且没有小数部分。
  final value = json[key];
  if (value == null) return fallback;
  if (value is num && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  throw FormatException('$key must be an integer');
}

/// 读取有限数值并转 double；NaN、无穷值和非数值抛 FormatException。
/// json：待读取浮点数的 JSON 对象。
/// key：目标数值字段名。
/// fallback：字段缺失或 null 时返回的 double，默认 0。
double readDouble(JsonMap json, String key, {double fallback = 0}) {
  // value：目标字段原值，只有 num 才进入浮点转换。
  final value = json[key];
  if (value == null) return fallback;
  if (value is num) {
    // parsed：转成 double 后的数值，返回前仍检查是否有限。
    final parsed = value.toDouble();
    if (parsed.isFinite) return parsed;
    throw FormatException('$key must be a finite number');
  }
  throw FormatException('$key must be a number');
}

/// 读取真实 bool；不把 0、1 或字符串当作布尔值。
/// json：待读取布尔字段的 JSON 对象。
/// key：目标布尔字段名。
/// fallback：缺失或 null 时的布尔值，默认 false。
bool readBool(JsonMap json, String key, {bool fallback = false}) {
  // value：待检查的原始布尔字段，非 bool 不做隐式转换。
  final value = json[key];
  if (value == null) return fallback;
  if (value is bool) return value;
  throw FormatException('$key must be a boolean');
}

/// 读取必须存在的对象，验证所有键为 String 后复制成 JsonMap；缺失也视为格式错误。
/// json：包含嵌套对象字段的外层 JSON。
/// key：目标对象字段名，不提供空对象回退。
JsonMap readMap(JsonMap json, String key) {
  // value：目标嵌套对象原值，需同时满足 Map 及 String 键约束。
  final value = json[key];
  if (value is Map &&
      value.keys.every(
        /* 逐键验证嵌套对象可安全复制为 JsonMap。
   * key：嵌套对象中的实际键，必须为 String。 */
        (key) => key is String,
      )) {
    return Map<String, Object?>.from(value);
  }
  throw FormatException('$key must be an object');
}

/// 读取对象数组，逐项校验 Map 与 String 键；返回不可增长的新列表。
/// json：包含对象数组的外层 JSON。
/// key：目标数组字段名，缺失或非数组直接报错。
List<JsonMap> readMapList(JsonMap json, String key) {
  // value：待检查的原始数组，类型确认后才逐项解码。
  final value = json[key];
  if (value is! List) throw FormatException('$key must be an array');
  return value
      .map(
        /* 把一个经过键类型检查的数组元素复制成 JsonMap。
       * item：数组中的单个候选对象，非 Map 或含非 String 键即报错。 */
        (item) {
          if (item is! Map ||
              item.keys.any(
                /* 检测对象元素是否包含不支持的键类型。
         * key：当前元素对象中的实际键，非 String 表示格式错误。 */
                (key) => key is! String,
              )) {
            throw FormatException('$key item must be an object');
          }
          return Map<String, Object?>.from(item);
        },
      )
      .toList(growable: false);
}

/// 读取字符串数组；缺失或 null 返回 fallback，数组元素类型错误抛 FormatException。
/// json：包含字符串数组字段的外层 JSON。
/// key：目标字符串数组字段名。
/// fallback：缺失时直接返回的字符串列表，默认 const 空列表。
List<String> readStringList(
  JsonMap json,
  String key, {
  List<String> fallback = const [],
}) {
  // value：原始数组字段，非空时必须是 List。
  final value = json[key];
  if (value == null) return fallback;
  if (value is! List) throw FormatException('$key must be an array');
  return value
      .map(
        /* 验证并返回当前字符串元素，不对非字符串调用 toString。
       * item：数组中的单个原始值，必须是 String。 */
        (item) {
          if (item is! String) {
            throw FormatException('$key item must be a string');
          }
          return item;
        },
      )
      .toList(growable: false);
}
