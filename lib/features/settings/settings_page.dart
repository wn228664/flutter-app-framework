import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/action_lock_controller.dart';
import '../../core/state/theme_controller.dart';
import '../../shared/widgets/top_message.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final saving = ref.watch(actionLockProvider).contains('appearance');
    return Scaffold(
      appBar: AppBar(title: const Text('外观设置')),
      body: SafeArea(
        child: ListView(
          children: [
            for (final entry in {
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
                    : (value) async {
                        if (value == null) return;
                        try {
                          await ref
                              .read(actionLockProvider.notifier)
                              .run(
                                'appearance',
                                () => ref
                                    .read(themeModeProvider.notifier)
                                    .setMode(value),
                              );
                        } catch (_) {
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
