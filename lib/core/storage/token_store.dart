import 'secure_token_storage.dart';

typedef _MutationFailure = ({Object error, StackTrace stackTrace});

/// 凭证写入串行化，读取等待已发起的修改；revision 递增让旧请求立即失效。
/// 默认使用系统安全存储；失败不回退到明文或旧凭证。
class TokenStore {
  TokenStore({TokenStorage? storage})
    : _storage = storage ?? SecureTokenStorage();
  final TokenStorage _storage;
  int _revision = 0;
  Future<_MutationFailure?>? _mutations;
  int get revision => _revision;
  Future<String?> read() async {
    final failure = await _mutations;
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
    return _storage.read();
  }

  Future<void> write(String token) {
    _revision += 1;
    return _enqueueMutation(() => _storage.write(token));
  }

  Future<void> clear() {
    _revision += 1;
    return _enqueueMutation(() => _storage.clear());
  }

  Future<void> _enqueueMutation(Future<void> Function() operation) {
    final previous = _mutations;
    final pending = previous == null
        ? Future<void>.sync(operation)
        : previous.then((_) => operation());
    _mutations = pending.then<_MutationFailure?>(
      (_) => null,
      onError: (Object error, StackTrace stackTrace) =>
          (error: error, stackTrace: stackTrace),
    );
    return pending;
  }
}
