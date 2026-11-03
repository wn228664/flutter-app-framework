import 'package:flutter_app_framework/core/storage/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'default credential persistence uses secure storage and never plain preferences',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final store = TokenStore();
      await store.write('fixture-session');
      expect(await store.read(), 'fixture-session');
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      await store.clear();
      expect(await store.read(), isNull);
    },
  );
}
