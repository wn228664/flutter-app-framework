import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// TokenStore 的平台边界；测试可注入隔离后端，不复用普通偏好存储保存凭证。
abstract interface class TokenStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

/// Android 使用 Keystore 保护的加密偏好，iOS 使用本应用的 Keychain。
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );
  static const _key = 'framework_session_token';
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
