// HTTP 边界：Dio 负责传输，TokenStore 代次隔离身份；只接收相对路径，响应信封解码交给调用方。

import 'package:dio/dio.dart';

import '../storage/token_store.dart';
import 'api_exception.dart';

/// 带凭证代次检查的 HTTP 客户端；发送前、成功后和失败后都验证身份，拒绝旧请求污染新会话。
class ApiClient {
  /// 设置连接 8 秒、发送和接收各 12 秒的超时；注入 Dio 时也以这里的 BaseOptions 替换其配置。
  /// baseUrl：经应用启动校验的公开 API 基址，空串会在真正请求时被拒绝。
  /// tokenStore：本客户端共享的凭证来源及会话 revision。
  /// dio：可注入的传输客户端，默认新建；其连接由 close 强制关闭。
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

  /// 当前实例持有的 Dio，执行传输及最终连接清理。
  final Dio _dio;

  /// 当前身份的凭证队列与代次来源，用于识别迟到响应。
  final TokenStore _tokenStore;

  /// 校验相对路径并发送请求，返回 decode 的 T；取消与 HTTP 失败转为 ApiException，解码及存储异常原样抛出。
  /// 当前身份的 401 才清凭证；旧身份的响应在调用解码器或清凭证前被拒绝。
  /// path：基址内的相对路径；禁止协议、双斜杠起始、空白控制字符和反斜杠。
  /// decode：调用方的响应转换器，负责真实业务信封及结果判断。
  /// value：Dio 已解码的原始响应 data，可能为空，不被框架擅自解包。
  /// method：HTTP 方法，默认 GET，直接传给 Dio Options。
  /// data：可空请求体，保持调用方提供的编码对象。
  /// query：可空查询参数对象，由 Dio 负责序列化。
  /// authenticated：默认读取 Bearer 凭证并检查代次；false 时不读取凭证也不执行身份隔离。
  /// cancelToken：调用方持有的可选取消令牌，取消映射为 CANCELLED。
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
    // revision：读取凭证前捕获的身份代次，用于拒绝读取期间或请求期间的身份变化。
    final revision = _tokenStore.revision;
    // token：等待已有凭证修改后读取的值，非空才附加 Authorization。
    final token = authenticated ? await _tokenStore.read() : null;

    /// 对需要鉴权的请求复验代次；不同则抛 SESSION_CHANGED，阻止旧请求继续消费。
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
      // response：传输成功的 Dio 响应，身份复验通过后才交给 decode。
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
    } on DioException catch (
      /* error：Dio 传输或 HTTP 错误，先复验身份，再判断 401、取消和公开提示。 */ error
    ) {
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

  /// 强制关闭此客户端及进行中的连接；由 apiClientProvider 的销毁回调调用。
  void close() => _dio.close(force: true);
}
