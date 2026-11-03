class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode = 0,
    this.code = 'NETWORK_ERROR',
  });
  final String message;
  final int statusCode;
  final String code;
  bool get isUnauthorized => statusCode == 401;
  bool get isCancelled => code == 'CANCELLED';
  @override
  String toString() => message;
}
