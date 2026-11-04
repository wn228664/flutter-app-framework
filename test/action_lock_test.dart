// 动作锁回归：手动控制异步完成顺序，验证同键防重、失败释放及销毁后结果传播；不依赖网络或真实存储。

import 'dart:async';

import 'package:flutter_app_framework/core/state/action_lock_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// 注册动作锁的三个生命周期与互斥回归。
void main() {
  test(
    'disposing the owner while an action is pending preserves its result',
    /* 验证控制器销毁不会丢失已经执行动作的返回结果，也不在销毁后更新状态。 */
    () async {
      // controller：此销毁场景独占的动作锁。
      final controller = ActionLockController();
      // pending：由测试控制完成时机的动作结果。
      final pending = Completer<String>();
      // result：销毁前启动动作的 Future，销毁后仍须返回 done。
      final result = controller.run(
        'save',
        /* 以受控 Future 保持动作进行中，直到控制器销毁后才完成。 */
        () => pending.future,
      );
      controller.dispose();
      pending.complete('done');
      expect(await result, 'done');
    },
  );
  test(
    'action lock admits only one write for the same synchronous key',
    /* 验证同一同步键只执行第一次动作，重复调用返回 null。 */
    () async {
      // controller：防重场景中的锁实例。
      final controller = ActionLockController();
      // completer：阻止首个动作过早结束，保留可重复进入的验证窗口。
      final completer = Completer<String>();
      // calls：实际动作工厂执行次数，第二次请求不得增加。
      var calls = 0;

      // first：首个获锁调用的结果，解除等待后应返回 saved。
      final first = controller.run(
        'save',
        /* 记录首次动作已进入，并等待测试主动完成。 */
        () {
          calls += 1;
          return completer.future;
        },
      );
      // repeated：同键重复进入的返回值，预期 null。
      final repeated = await controller.run(
        'save',
        /* 重复调用的动作替身；若被执行会增加 calls 并暴露缺陷。 */
        () async {
          calls += 1;
          return 'duplicate';
        },
      );

      expect(repeated, isNull);
      expect(calls, 1);
      completer.complete('saved');
      expect(await first, 'saved');
      expect(controller.state, isEmpty);
    },
  );

  test(
    'action lock releases a failed key so a retry can execute',
    /* 验证失败路径释放锁，之后同键重试仍可执行。 */
    () async {
      // controller：失败恢复场景的独立锁实例。
      final controller = ActionLockController();

      await expectLater(
        controller.run<void>(
          'save',
          /* 构造明确失败的 Future，测试 finally 解锁路径。 */
          () => Future<void>.error(StateError('failed')),
        ),
        throwsStateError,
      );
      // retried：失败后的重试动作是否真正执行。
      var retried = false;
      await controller.run(
        'save',
        /* 重试成功时设置标记，证明失败未永久占锁。 */
        () async => retried = true,
      );

      expect(retried, isTrue);
    },
  );
}
