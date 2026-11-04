// 凭证时序边界：修改调用即推进 revision，实际写删串行；读操作等待当时队尾，失败带原堆栈上抛。

import 'secure_token_storage.dart';

/// 保存一次凭证修改的异常与原始堆栈；队列用记录值表示失败，允许下一笔修改继续。
typedef _MutationFailure = ({Object error, StackTrace stackTrace});

/// 会话凭证及代次的唯一入口；读取等待已发起的修改，修改失败不回退到旧凭证或明文。
class TokenStore {
  /// 默认接入系统安全存储；测试可注入隔离的 TokenStorage。
  /// storage：读写删除凭证的后端；不传则创建 SecureTokenStorage。
  TokenStore({TokenStorage? storage})
    : _storage = storage ?? SecureTokenStorage();

  /// 串行凭证操作最终访问的安全后端。
  final TokenStorage _storage;

  /// 身份变更代次，write 或 clear 调用时立即递增，使旧网络请求失效。
  int _revision = 0;

  /// 最近发起修改的队尾，完成值为空表示成功，失败记录供读取时重抛。
  Future<_MutationFailure?>? _mutations;

  /// 读取当前会话代次，无须等待持久化完成。
  int get revision => _revision;

  /// 等待调用时已存在的修改；最近一笔失败则带原堆栈抛出，否则读取安全后端。
  Future<String?> read() async {
    // failure：当前队尾的失败记录，为空时才允许读取后端值。
    final failure = await _mutations;
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
    return _storage.read();
  }

  /// 立即推进代次，再把覆盖凭证操作加入队列；返回当前写入的原始 Future。
  /// token：将替换旧值的完整凭证；本层不猜测其格式。
  Future<void> write(String token) {
    _revision += 1;
    return _enqueueMutation(
      /* 轮到本次修改时向安全后端写入捕获的 token。 */
      () => _storage.write(token),
    );
  }

  /// 立即推进代次并排队删除，避免旧身份请求在删除等待期间继续被接受。
  Future<void> clear() {
    _revision += 1;
    return _enqueueMutation(/* 轮到本次修改时删除安全后端凭证。 */ () => _storage.clear());
  }

  /// 将修改接到队尾；对调用者保留错误，对后续队列记录错误而不阻断下一笔。
  /// operation：当前一次后端写入或删除工厂，轮到本次时才执行。
  Future<void> _enqueueMutation(Future<void> Function() operation) {
    // previous：入队时捕获的队尾，确保并发调用仍按先后顺序执行。
    final previous = _mutations;
    // pending：本次实际后端操作的 Future，失败直接返回给调用方。
    final pending = previous == null
        ? Future<void>.sync(operation)
        : previous.then(
            /* 上一笔队尾结束后执行当前修改，允许在前次失败后恢复。
         * 忽略的前次失败记录；新修改可以尝试修复存储状态。 */
            (_) => operation(),
          );
    _mutations = pending.then<_MutationFailure?>(
      /* 本次修改成功后清空队尾失败记录。
       * 忽略的 void 完成值，只记录成功状态。 */
      (_) => null,
      onError: /* 把本次异常及堆栈保存到队尾，后续读取据此拒绝返回不可信旧值。
       * error：当前后端修改失败的原始异常。
       * stackTrace：原始失败位置，read 重抛时保留它。 */
          (Object error, StackTrace stackTrace) =>
              (error: error, stackTrace: stackTrace),
    );
    return pending;
  }
}
