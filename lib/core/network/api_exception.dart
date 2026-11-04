// 网络层公开异常：保存稳定错误码、HTTP 状态和安全提示；业务信封仍由调用方自行判断。

/// 供页面和通用错误组件消费的网络异常；不包含请求体、令牌或原始响应详情。
class ApiException implements Exception {
  /// 构造公开异常；未取得 HTTP 状态时用 0，默认错误码为 NETWORK_ERROR。
  /// message：可展示给用户的安全提示，不放入服务器敏感原文。
  /// statusCode：HTTP 状态码；本地校验、取消和无响应时默认为 0。
  /// code：程序判断用稳定错误码，与用户文案分离。
  const ApiException({
    required this.message,
    this.statusCode = 0,
    this.code = 'NETWORK_ERROR',
  });

  /// 面向用户的错误提示，ErrorState 允许直接展示。
  final String message;

  /// HTTP 响应状态，缺省 0 表示无可用状态。
  final int statusCode;

  /// 稳定错误标识，如 SESSION_CHANGED、INVALID_PATH 或 CANCELLED。
  final String code;

  /// 只按 HTTP 401 判断未授权，不推断后端业务码。
  bool get isUnauthorized => statusCode == 401;

  /// 按 CANCELLED 错误码识别主动取消。
  bool get isCancelled => code == 'CANCELLED';

  /// 返回安全提示，避免默认字符串包含多余内部细节。
  @override
  String toString() => message;
}
