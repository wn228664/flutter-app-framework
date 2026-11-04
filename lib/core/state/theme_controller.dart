// 主题状态与持久化：从普通偏好恢复 ThemeMode，写入串行执行；单次失败向调用者报告，后续保存仍可继续。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/providers.dart';

/// 持久化成功后才更新主题状态；各次保存按调用顺序执行，销毁后不写 UI。
class ThemeController extends StateNotifier<ThemeMode> {
  /// 从 framework_theme 恢复匹配模式，缺失或未知值回退跟随系统。
  /// _preferences：非敏感偏好后端，只存主题名称，不存会话凭证。
  ThemeController(this._preferences)
    : super(
        ThemeMode.values.firstWhere(
          /* 匹配偏好里保存的 ThemeMode 名称。
           * mode：遍历到的系统、浅色或深色模式候选。 */
          (mode) => mode.name == _preferences.getString('framework_theme'),
          orElse: /* 保存值无匹配时采用跟随系统模式。 */ () => ThemeMode.system,
        ),
      );

  /// 外观偏好的存储实例，由启动入口或测试注入。
  final SharedPreferences _preferences;

  /// 已消化失败的队尾 Future，确保下一次保存不会被上一笔失败永久阻塞。
  Future<void> _pending = Future.value();

  /// 将模式保存加入队列；存储返回 false 时抛 StateError，成功且仍挂载才更新 state。
  /// mode：本次希望保存的 ThemeMode，按 name 写入偏好。
  Future<void> setMode(ThemeMode mode) {
    // operation：本次保存的原始 Future，保留失败给调用方显示提示。
    final operation = _pending.then(
      /* 上一笔结束后保存本次模式；控制器已销毁则跳过。
     * 忽略的上一笔队尾结果；队尾只提供串行时序。 */
      (_) async {
        if (!mounted) return;
        // saved：偏好写入是否成功，false 不得更新可见主题。
        final saved = await _preferences.setString(
          'framework_theme',
          mode.name,
        );
        if (!saved) throw StateError('无法保存外观偏好');
        if (mounted) state = mode;
      },
    );
    _pending = operation.then<void>(
      /* 将本次成功结果归一为空值，供下一笔等待。
       * 忽略的成功完成值；队列只关心结束时机。 */
      (_) {},
      onError: /* 仅在队尾吸收本次失败，原始 operation 仍向调用方抛错。
       * 忽略的存储异常；不让它阻断下一次外观选择。
       * 忽略的失败堆栈；错误传播由原始 operation 保留。 */
          (Object _, StackTrace __) {},
    );
    return operation;
  }
}

/// 把主题控制器及其当前 ThemeMode 暴露给根应用和设置页。
final themeModeProvider = StateNotifierProvider<ThemeController, ThemeMode>(
  /* 使用当前容器注入的偏好创建主题控制器。
   * ref：订阅 preferencesProvider，确保测试和启动覆盖生效。 */
  (ref) => ThemeController(ref.watch(preferencesProvider)),
);
