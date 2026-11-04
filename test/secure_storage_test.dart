// 默认凭证后端回归：使用插件 mock 隔离平台，断言凭证不进入普通偏好；不能代替真机 Keystore/Keychain 验收。

import 'package:flutter_app_framework/core/storage/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 注册默认凭证后端写、读、删与明文偏好隔离回归。
void main() {
  test(
    'default credential persistence uses secure storage and never plain preferences',
    /* 用安全存储 mock 验证默认 TokenStore 完整读写清除，普通偏好始终为空。 */
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      // store：未注入后端的默认 TokenStore，必须走 SecureTokenStorage。
      final store = TokenStore();
      await store.write('fixture-session');
      expect(await store.read(), 'fixture-session');
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      await store.clear();
      expect(await store.read(), isNull);
    },
  );
}
