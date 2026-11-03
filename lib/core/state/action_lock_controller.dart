import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 按动作键拒绝重复进入；返回 null 表示本次未执行。调用方负责后端幂等和取消。
class ActionLockController extends StateNotifier<Set<String>> {
  ActionLockController() : super(const {});
  bool isLocked(String key) => state.contains(key);
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

final actionLockProvider =
    StateNotifierProvider<ActionLockController, Set<String>>(
      (_) => ActionLockController(),
    );
