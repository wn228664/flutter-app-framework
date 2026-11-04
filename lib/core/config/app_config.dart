// 公开构建配置：通过 --dart-define 提供应用名称及 API 基址；不承载秘密，空基址允许离线浏览框架。

/// 只读构建配置及启动校验入口；不可实例化，也不在运行期写回配置。
abstract final class AppConfig {
  /// APP_TITLE 构建值，未提供时使用 App Framework，供应用标题与首页展示。
  static const title = String.fromEnvironment(
    'APP_TITLE',
    defaultValue: 'App Framework',
  );

  /// API_BASE_URL 构建值；空串表示尚未配置网络服务，请求时会明确报错。
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// 启动时校验非空 API 基址为带 host 的 HTTP(S) 绝对地址；非法时抛 FormatException。
  static void validate() {
    if (apiBaseUrl.isEmpty) return;
    // uri：构建基址的解析结果，用于校验协议和主机是否齐全。
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        !{'https', 'http'}.contains(uri.scheme)) {
      throw const FormatException(
        'API_BASE_URL must be an absolute HTTP(S) URL',
      );
    }
  }
}
