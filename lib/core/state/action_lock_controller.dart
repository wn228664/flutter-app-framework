// 前端动作互斥：以字符串键同步占锁，所有退出路径释放；不提供网络取消或服务端幂等保障。

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 同一控制器内按动作键拒绝重复进入；未执行返回 null，已执行动作的结果或异常向调用方传播。
class ActionLockController extends StateNotifier<Set<String>> {
  /// 以空锁集合创建控制器，不预占任何动作。
  ActionLockController() : super(const {});

  /// 读取指定键是否已被运行中的动作占用。
  /// key：调用方约定的动作身份，查询与 run 必须使用相同键。
  bool isLocked(String key) => state.contains(key);

  /// 同步占锁后执行 action，finally 释放；销毁或重复进入返回 null，销毁后的进行中动作仍完成但不再更新状态。
  /// key：当前异步动作的互斥键，不同键可以并行执行。
  /// action：获得锁后才调用的异步操作，T 结果和异常保留给调用方。
  Future<T?> run<T>(String key, Future<T> Function() action) async {
    if (!mounted || state.contains(key)) return null;
    state = {...state, key};
    try {
      return await action();
    } finally {
      if (mounted) state = {...state}..remove(key);
    }
  }
}

/// 容器内共享的动作锁及锁集合，让按钮可以订阅 pending 状态。
final actionLockProvider =
    StateNotifierProvider<ActionLockController, Set<String>>(
      /* 创建当前 ProviderScope 独立持有的动作锁控制器。
       * 忽略的 ProviderRef；动作锁不依赖其他 provider。 */
      (_) => ActionLockController(),
    );
