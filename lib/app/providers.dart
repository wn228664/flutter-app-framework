import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/token_store.dart';

final preferencesProvider = Provider<SharedPreferences>(
  (_) => throw StateError('Preferences must be initialized at startup'),
);
final tokenStoreProvider = Provider<TokenStore>((_) => TokenStore());
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    tokenStore: ref.watch(tokenStoreProvider),
  );
  ref.onDispose(client.close);
  return client;
});
