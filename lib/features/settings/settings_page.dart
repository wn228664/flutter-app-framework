// 本地外观设置：订阅主题与 appearance 动作锁，持久化失败保留现有选择并显示可重试提示。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/action_lock_controller.dart';
import '../../core/state/theme_controller.dart';
import '../../shared/widgets/top_message.dart';

/// 仅管理系统、浅色、深色三种外观；保存使用共享动作锁，防止同步连点重复写入。
class SettingsPage extends ConsumerWidget {
  /// 创建设置页面，主题和保存状态由当前 ProviderScope 提供。
  /// key：设置页在路由分支中的元素身份。
  const SettingsPage({super.key});

  /// 构建主题单选列表，保存期间禁用所有选项，存储成功后由主题 provider 更新选中态。
  /// context：读取主题并在保存失败且页面仍挂载时展示顶部提示。
  /// ref：订阅当前模式及动作锁，并调用对应 notifier。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // mode：已成功恢复或保存的主题模式，不提前展示未持久化的选择。
    final mode = ref.watch(themeModeProvider);
    // saving：appearance 键是否占锁，决定所有主题选项是否可操作。
    final saving = ref.watch(actionLockProvider).contains('appearance');
    return Scaffold(
      appBar: AppBar(title: const Text('外观设置')),
      body: SafeArea(
        child: ListView(
          children: [
            for ( /* entry：一个 ThemeMode 与中文展示文案的对应项。 */ final entry in {
              ThemeMode.system: '跟随系统',
              ThemeMode.light: '浅色',
              ThemeMode.dark: '深色',
            }.entries)
              RadioListTile<ThemeMode>(
                title: Text(entry.value),
                value: entry.key,
                groupValue: mode,
                onChanged: saving
                    ? null
                    : /* 忽略空选择，取得 appearance 锁后串行保存；失败仅在页面仍挂载时提示。
                     * value：本次选中的 ThemeMode，可空值不触发保存。 */ (value) async {
                        if (value == null) return;
                        try {
                          await ref
                              .read(actionLockProvider.notifier)
                              .run(
                                'appearance',
                                /* 只有获得动作锁后才调用主题控制器持久化所选模式。 */
                                () => ref
                                    .read(themeModeProvider.notifier)
                                    .setMode(value),
                              );
                        } catch (/* 忽略的保存异常；界面统一展示安全文案，不泄露存储实现细节。 */ _) {
                          if (context.mounted) {
                            showTopMessage(context, '保存失败，请重试');
                          }
                        }
                      },
              ),
          ],
        ),
      ),
    );
  }
}
