// 凭证平台适配：默认使用系统安全存储，TokenStorage 允许测试注入；失败直接传播，不降级到明文偏好。

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// TokenStore 所需的最小凭证后端接口；不负责排队或身份代次。
abstract interface class TokenStorage {
  /// 读取单个会话凭证，未保存时返回 null，后端错误通过 Future 抛出。
  Future<String?> read();

  /// 替换会话凭证；完成表示后端写入结束，失败必须向调用者传播。
  /// value：待保存的完整凭证值，不记录到日志。
  Future<void> write(String value);

  /// 删除已保存凭证；失败不伪装成已清除。
  Future<void> clear();
}

/// Android 使用 Keystore 保护的加密偏好，iOS 使用本应用 Keychain；不复用 SharedPreferences。
class SecureTokenStorage implements TokenStorage {
  /// 允许注入安全存储实例；默认开启 Android encryptedSharedPreferences。
  /// storage：可选平台安全存储实例，测试可用插件 mock 隔离真实凭证。
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  /// 本应用安全存储中的会话键；各平台读写删除使用同一个键。
  static const _key = 'framework_session_token';

  /// 实际平台安全存储适配器，插件异常向调用方传播。
  final FlutterSecureStorage _storage;

  /// 从固定安全键读取凭证，不读取普通偏好或旧副本。
  @override
  Future<String?> read() => _storage.read(key: _key);

  /// 覆盖固定安全键的值，等待插件确认写入完成。
  /// value：本次写入的凭证，交给平台加密存储。
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  /// 删除固定安全键，清除失败仍向上抛出。
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
