import 'dart:async';

import 'package:flutter_app_framework/core/state/action_lock_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'disposing the owner while an action is pending preserves its result',
    () async {
      final controller = ActionLockController();
      final pending = Completer<String>();
      final result = controller.run('save', () => pending.future);
      controller.dispose();
      pending.complete('done');
      expect(await result, 'done');
    },
  );
  test(
    'action lock admits only one write for the same synchronous key',
    () async {
      final controller = ActionLockController();
      final completer = Completer<String>();
      var calls = 0;

      final first = controller.run('save', () {
        calls += 1;
        return completer.future;
      });
      final repeated = await controller.run('save', () async {
        calls += 1;
        return 'duplicate';
      });

      expect(repeated, isNull);
      expect(calls, 1);
      completer.complete('saved');
      expect(await first, 'saved');
      expect(controller.state, isEmpty);
    },
  );

  test('action lock releases a failed key so a retry can execute', () async {
    final controller = ActionLockController();

    await expectLater(
      controller.run<void>(
        'save',
        () => Future<void>.error(StateError('failed')),
      ),
      throwsStateError,
    );
    var retried = false;
    await controller.run('save', () async => retried = true);

    expect(retried, isTrue);
  });
}
