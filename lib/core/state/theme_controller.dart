import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/providers.dart';

/// 写入按调用顺序串行执行，存储失败不会阻断后续选择；销毁后不再更新 UI。
class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController(this._preferences)
    : super(
        ThemeMode.values.firstWhere(
          (mode) => mode.name == _preferences.getString('framework_theme'),
          orElse: () => ThemeMode.system,
        ),
      );
  final SharedPreferences _preferences;
  Future<void> _pending = Future.value();
  Future<void> setMode(ThemeMode mode) {
    final operation = _pending.then((_) async {
      if (!mounted) return;
      final saved = await _preferences.setString('framework_theme', mode.name);
      if (!saved) throw StateError('无法保存外观偏好');
      if (mounted) state = mode;
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }
}

final themeModeProvider = StateNotifierProvider<ThemeController, ThemeMode>(
  (ref) => ThemeController(ref.watch(preferencesProvider)),
);
