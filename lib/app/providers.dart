// 依赖组装：偏好由启动入口覆盖，凭证默认接系统安全存储；HTTP 客户端随 provider 销毁关闭连接。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/token_store.dart';

/// 非敏感偏好依赖；未由启动入口或测试覆盖时立即报错，避免静默使用未初始化存储。
final preferencesProvider = Provider<SharedPreferences>(
  /* 拒绝在缺少启动覆盖时创建偏好依赖。
   * 忽略的 ProviderRef；此工厂只负责报告缺失覆盖。 */
  (_) => throw StateError('Preferences must be initialized at startup'),
);

/// 容器内共享的凭证存储及 revision 来源，默认使用平台安全后端。
final tokenStoreProvider = Provider<TokenStore>(
  /* 为当前容器创建独立 TokenStore，避免跨容器共用会话代次。
 * 忽略的 ProviderRef；TokenStore 不依赖其他 provider。 */
  (_) => TokenStore(),
);

/// 将公开 API 基址与当前 TokenStore 绑定；销毁时关闭其 Dio 客户端。
final apiClientProvider = Provider<ApiClient>(
  /* 组装会话隔离的 HTTP 客户端并注册连接清理。
 * ref：读取凭证依赖并注册 ApiClient.close 的生命周期清理。 */
  (ref) {
    // client：本次 provider 生命周期持有的 HTTP 客户端，返回给调用者复用。
    final client = ApiClient(
      baseUrl: AppConfig.apiBaseUrl,
      tokenStore: ref.watch(tokenStoreProvider),
    );
    ref.onDispose(client.close);
    return client;
  },
);
