import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app_framework/app/providers.dart';
import 'package:flutter_app_framework/core/state/theme_controller.dart';
import 'package:flutter_app_framework/core/storage/secure_token_storage.dart';
import 'package:flutter_app_framework/core/storage/token_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DelayedPreferences implements SharedPreferences {
  final writes = <String>[];
  final completions = <Completer<bool>>[];
  @override
  String? getString(String key) => null;
  @override
  Future<bool> setString(String key, String value) {
    writes.add(value);
    final done = Completer<bool>();
    completions.add(done);
    return done.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTokenStorage implements TokenStorage {
  final values = <String, String>{};
  final writes = <Completer<void>>[];
  @override
  Future<String?> read() async => values['token'];
  @override
  Future<void> write(String value) async {
    final done = Completer<void>();
    writes.add(done);
    await done.future;
    values['token'] = value;
  }

  @override
  Future<void> clear() async {
    values.remove('token');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'theme writes retain invocation order and recover after a failed save',
    () async {
      final prefs = DelayedPreferences();
      final container = ProviderContainer(
        overrides: [preferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final controller = container.read(themeModeProvider.notifier);
      final first = controller.setMode(ThemeMode.dark);
      final second = controller.setMode(ThemeMode.light);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.writes, ['dark']);
      prefs.completions[0].complete(true);
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(prefs.writes, ['dark', 'light']);
      final rejected = expectLater(second, throwsStateError);
      prefs.completions[1].complete(false);
      await rejected;
      expect(container.read(themeModeProvider), ThemeMode.dark);
      final third = controller.setMode(ThemeMode.system);
      await Future<void>.delayed(Duration.zero);
      prefs.completions[2].complete(true);
      await third;
      expect(container.read(themeModeProvider), ThemeMode.system);
    },
  );
  test('disposing a theme owner ignores an in-flight save result', () async {
    final prefs = DelayedPreferences();
    final controller = ThemeController(prefs);
    final pending = controller.setMode(ThemeMode.dark);
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    prefs.completions.single.complete(true);
    await pending;
  });
  test(
    'token reads wait for writes and later writes recover from storage failure',
    () async {
      final prefs = FakeTokenStorage();
      final store = TokenStore(storage: prefs);
      final first = store.write('first');
      final failure = expectLater(first, throwsStateError);
      prefs.writes.first.completeError(StateError('disk failed'));
      await failure;
      await expectLater(store.read(), throwsStateError);
      final second = store.write('second');
      final read = store.read();
      await Future<void>.delayed(Duration.zero);
      prefs.writes.last.complete();
      await second;
      expect(await read, 'second');
      expect(store.revision, 2);
    },
  );
}
