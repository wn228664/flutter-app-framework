abstract final class AppConfig {
  static const title = String.fromEnvironment(
    'APP_TITLE',
    defaultValue: 'App Framework',
  );
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static void validate() {
    if (apiBaseUrl.isEmpty) return;
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
