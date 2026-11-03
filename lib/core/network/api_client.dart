import 'package:dio/dio.dart';

import '../storage/token_store.dart';
import 'api_exception.dart';

/// 保留 Dio 与凭证代次隔离；服务端响应信封由调用方解码。
class ApiClient {
  ApiClient({required String baseUrl, required TokenStore tokenStore, Dio? dio})
    : _tokenStore = tokenStore,
      _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
    );
  }

  final Dio _dio;
  final TokenStore _tokenStore;

  Future<T> request<T>(
    String path, {
    required T Function(Object? value) decode,
    String method = 'GET',
    Object? data,
    Map<String, Object?>? query,
    bool authenticated = true,
    CancelToken? cancelToken,
  }) async {
    if (_dio.options.baseUrl.isEmpty) {
      throw const ApiException(
        message: '请先配置 API_BASE_URL',
        code: 'API_NOT_CONFIGURED',
      );
    }
    // 只允许相对地址，避免携带会话凭证请求另一个站点。
    if (Uri.tryParse(path) == null ||
        Uri.parse(path).hasScheme ||
        path.startsWith('//') ||
        RegExp(r'[\x00-\x20\\]').hasMatch(path)) {
      throw const ApiException(message: '请求路径必须为相对地址', code: 'INVALID_PATH');
    }
    final revision = _tokenStore.revision;
    final token = authenticated ? await _tokenStore.read() : null;
    void ensureSession() {
      if (authenticated && revision != _tokenStore.revision) {
        throw const ApiException(
          message: '会话已变化，请重新操作',
          code: 'SESSION_CHANGED',
        );
      }
    }

    ensureSession();
    try {
      final response = await _dio.request<Object?>(
        path,
        data: data,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: {
            if (token?.isNotEmpty ?? false) 'Authorization': 'Bearer $token',
          },
        ),
      );
      ensureSession();
      return decode(response.data);
    } on DioException catch (error) {
      ensureSession();
      if (error.response?.statusCode == 401 && authenticated) {
        await _tokenStore.clear();
      }
      if (CancelToken.isCancel(error)) {
        throw const ApiException(message: '请求已取消', code: 'CANCELLED');
      }
      throw ApiException(
        message: error.response == null
            ? '网络连接失败，请重试'
            : 'HTTP ${error.response!.statusCode}',
        statusCode: error.response?.statusCode ?? 0,
        code: 'HTTP_ERROR',
      );
    }
  }

  void close() => _dio.close(force: true);
}
