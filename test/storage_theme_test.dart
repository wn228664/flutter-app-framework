// 存储顺序回归：以 Completer 精确控制偏好和凭证后端，检查串行、失败恢复及销毁期间迟到结果。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app_framework/app/providers.dart';
import 'package:flutter_app_framework/core/state/theme_controller.dart';
import 'package:flutter_app_framework/core/storage/secure_token_storage.dart';
import 'package:flutter_app_framework/core/storage/token_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 可控完成顺序的偏好替身，仅实现主题控制器使用的字符串读写。
class DelayedPreferences implements SharedPreferences {
  /// 已经实际进入后端的主题名称序列，用于证明保存顺序。
  final writes = <String>[];

  /// 每次主题写入对应的完成器，由测试选择成功或失败。
  final completions = <Completer<bool>>[];

  /// 固定返回无已存主题，让控制器从跟随系统开始。
  /// key：控制器读取的偏好键，此替身不提供任何初始值。
  @override
  String? getString(String key) => null;

  /// 记录本次主题名称，返回待测试主动完成的布尔 Future。
  /// key：偏好写入键，本组关注写值顺序。
  /// value：待保存的 ThemeMode 名称。
  @override
  Future<bool> setString(String key, String value) {
    writes.add(value);
    // done：本次写入成功与否的受控完成器。
    final done = Completer<bool>();
    completions.add(done);
    return done.future;
  }

  /// 将未实现偏好接口交给默认行为，不为测试伪造额外能力。
  /// invocation：本替身没有显式实现的成员调用。
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 带可控写入延迟的内存凭证后端，用于隔离串行和失败路径。
class FakeTokenStorage implements TokenStorage {
  /// 已提交的内存凭证，只在受控写入成功后改变。
  final values = <String, String>{};

  /// 实际启动写入的完成器队列，测试可让首笔失败、后笔恢复。
  final writes = <Completer<void>>[];

  /// 读取当前已经提交的内存 token。
  @override
  Future<String?> read() async => values['token'];

  /// 等待测试控制的写入完成后再修改内存值，错误不会提前提交。
  /// value：本次待提交的凭证文本。
  @override
  Future<void> write(String value) async {
    // done：本次凭证写入的完成器，可触发存储失败。
    final done = Completer<void>();
    writes.add(done);
    await done.future;
    values['token'] = value;
  }

  /// 立即移除内存凭证，模拟成功删除。
  @override
  Future<void> clear() async {
    values.remove('token');
  }

  /// 对未实现的接口成员保留默认异常行为。
  /// invocation：替身未显式支持的成员调用信息。
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 注册主题顺序、主题销毁隔离及凭证失败恢复回归。
void main() {
  test(
    'theme writes retain invocation order and recover after a failed save',
    /* 验证主题保存按顺序进入后端，失败不覆盖已成功主题，下一次仍能恢复。 */
    () async {
      // prefs：此用例控制主题写入完成顺序的偏好替身。
      final prefs = DelayedPreferences();
      // container：注入替身的隔离 ProviderContainer，结束时销毁。
      final container = ProviderContainer(
        overrides: [preferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      // controller：从隔离容器取得的真实主题控制器。
      final controller = container.read(themeModeProvider.notifier);
      // first：首先保存 dark 的 Future，应先于 light 完成。
      final first = controller.setMode(ThemeMode.dark);
      // second：排队的 light 保存，测试将使它返回 false。
      final second = controller.setMode(ThemeMode.light);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.writes, ['dark']);
      prefs.completions[0].complete(true);
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(prefs.writes, ['dark', 'light']);
      // rejected：先注册的失败断言 Future，避免受控失败变成未处理异常。
      final rejected = expectLater(second, throwsStateError);
      prefs.completions[1].complete(false);
      await rejected;
      expect(container.read(themeModeProvider), ThemeMode.dark);
      // third：前次失败后保存 system 的恢复操作。
      final third = controller.setMode(ThemeMode.system);
      await Future<void>.delayed(Duration.zero);
      prefs.completions[2].complete(true);
      await third;
      expect(container.read(themeModeProvider), ThemeMode.system);
    },
  );
  test(
    'disposing a theme owner ignores an in-flight save result',
    /* 验证销毁中的保存仍可结束，但不更新已释放的控制器状态。 */
    () async {
      // prefs：此销毁场景的受控偏好后端。
      final prefs = DelayedPreferences();
      // controller：直接创建并在保存完成前销毁的主题控制器。
      final controller = ThemeController(prefs);
      // pending：销毁时尚未结束的 dark 保存 Future。
      final pending = controller.setMode(ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      prefs.completions.single.complete(true);
      await pending;
    },
  );
  test(
    'token reads wait for writes and later writes recover from storage failure',
    /* 验证凭证写入失败后读取报错，下一次写入能恢复且读取等待最新写入。 */
    () async {
      // prefs：此处实际为凭证安全后端替身，不是 SharedPreferences。
      final prefs = FakeTokenStorage();
      // store：接入可控凭证后端的真实 TokenStore。
      final store = TokenStore(storage: prefs);
      // first：即将被测试设置失败的首笔凭证写入。
      final first = store.write('first');
      // failure：等待首笔写入抛 StateError 的断言 Future。
      final failure = expectLater(first, throwsStateError);
      prefs.writes.first.completeError(StateError('disk failed'));
      await failure;
      await expectLater(store.read(), throwsStateError);
      // second：失败后的恢复写入，完成后应覆盖失败状态。
      final second = store.write('second');
      // read：恢复写入进行中发起的读取，必须等到新值提交。
      final read = store.read();
      await Future<void>.delayed(Duration.zero);
      prefs.writes.last.complete();
      await second;
      expect(await read, 'second');
      expect(store.revision, 2);
    },
  );
}
