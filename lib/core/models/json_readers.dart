import 'json_types.dart';

String readString(JsonMap json, String key, {String fallback = ''}) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is String) return value;
  throw FormatException('$key must be a string');
}

int readInt(JsonMap json, String key, {int fallback = 0}) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is num && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  throw FormatException('$key must be an integer');
}

double readDouble(JsonMap json, String key, {double fallback = 0}) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is num) {
    final parsed = value.toDouble();
    if (parsed.isFinite) return parsed;
    throw FormatException('$key must be a finite number');
  }
  throw FormatException('$key must be a number');
}

bool readBool(JsonMap json, String key, {bool fallback = false}) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is bool) return value;
  throw FormatException('$key must be a boolean');
}

JsonMap readMap(JsonMap json, String key) {
  final value = json[key];
  if (value is Map && value.keys.every((key) => key is String)) {
    return Map<String, Object?>.from(value);
  }
  throw FormatException('$key must be an object');
}

List<JsonMap> readMapList(JsonMap json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('$key must be an array');
  return value
      .map((item) {
        if (item is! Map || item.keys.any((key) => key is! String)) {
          throw FormatException('$key item must be an object');
        }
        return Map<String, Object?>.from(item);
      })
      .toList(growable: false);
}

List<String> readStringList(
  JsonMap json,
  String key, {
  List<String> fallback = const [],
}) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is! List) throw FormatException('$key must be an array');
  return value
      .map((item) {
        if (item is! String) {
          throw FormatException('$key item must be a string');
        }
        return item;
      })
      .toList(growable: false);
}
