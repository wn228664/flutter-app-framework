import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_framework/core/network/api_client.dart';
import 'package:flutter_app_framework/core/network/api_exception.dart';
import 'package:flutter_app_framework/core/storage/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryTokenStore implements TokenStore {
  String? token = 'test-token';
  int generation = 0;
  @override
  int get revision => generation;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    generation++;
    token = value;
  }

  @override
  Future<void> clear() async {
    generation++;
    token = null;
  }
}

class TestAdapter implements HttpClientAdapter {
  TestAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions options) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'backend configuration is required only when sending a request',
    () async {
      final client = ApiClient(baseUrl: '', tokenStore: MemoryTokenStore());
      addTearDown(client.close);
      await expectLater(
        client.request('/example', decode: (data) => data),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'API_NOT_CONFIGURED',
          ),
        ),
      );
    },
  );
  test(
    'authenticated request returns the untouched response payload',
    () async {
      final dio = Dio()
        ..httpClientAdapter = TestAdapter((options) async {
          expect(options.headers['Authorization'], 'Bearer test-token');
          return ResponseBody.fromString(
            '{"success":false}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
      final client = ApiClient(
        baseUrl: 'https://example.invalid',
        tokenStore: MemoryTokenStore(),
        dio: dio,
      );
      addTearDown(client.close);
      expect(await client.request('/example', decode: (data) => data), {
        'success': false,
      });
    },
  );
  test('late 401 cannot clear a new session', () async {
    final store = MemoryTokenStore();
    final dio = Dio()
      ..httpClientAdapter = TestAdapter((options) async {
        await store.write('new-session');
        return ResponseBody.fromString('', 401);
      });
    final client = ApiClient(
      baseUrl: 'https://example.invalid',
      tokenStore: store,
      dio: dio,
    );
    addTearDown(client.close);
    await expectLater(
      client.request('/example', decode: (data) => data),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'SESSION_CHANGED',
        ),
      ),
    );
    expect(store.token, 'new-session');
  });
  test('a current 401 clears the session', () async {
    final store = MemoryTokenStore();
    final dio = Dio()
      ..httpClientAdapter = TestAdapter(
        (_) async => ResponseBody.fromString('', 401),
      );
    final client = ApiClient(
      baseUrl: 'https://example.invalid',
      tokenStore: store,
      dio: dio,
    );
    addTearDown(client.close);
    await expectLater(
      client.request('/example', decode: (data) => data),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 401),
      ),
    );
    expect(store.token, isNull);
  });
  test('absolute URLs cannot receive the app token', () async {
    final client = ApiClient(
      baseUrl: 'https://example.invalid',
      tokenStore: MemoryTokenStore(),
    );
    addTearDown(client.close);
    await expectLater(
      client.request('https://external.invalid', decode: (data) => data),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_PATH',
        ),
      ),
    );
  });
  test(
    'an old successful response is rejected before its decoder runs',
    () async {
      final store = MemoryTokenStore();
      var decoded = false;
      final dio = Dio()
        ..httpClientAdapter = TestAdapter((_) async {
          await store.write('new');
          return ResponseBody.fromString(
            '{}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
      final client = ApiClient(
        baseUrl: 'https://example.invalid',
        tokenStore: store,
        dio: dio,
      );
      addTearDown(client.close);
      await expectLater(
        client.request(
          '/example',
          decode: (value) {
            decoded = true;
            return value;
          },
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
        ),
      );
      expect(decoded, false);
    },
  );
  test(
    'unsafe relative paths and canceled requests never reach the transport',
    () async {
      final dio = Dio()
        ..httpClientAdapter = TestAdapter((_) async {
          fail('unexpected transport request');
        });
      final client = ApiClient(
        baseUrl: 'https://example.invalid',
        tokenStore: MemoryTokenStore(),
        dio: dio,
      );
      addTearDown(client.close);
      for (final path in [
        '//external.invalid',
        '/\\external.invalid',
        '/bad\npath',
      ]) {
        await expectLater(
          client.request(path, decode: (value) => value),
          throwsA(
            isA<ApiException>().having((e) => e.code, 'code', 'INVALID_PATH'),
          ),
        );
      }
      final cancel = CancelToken()..cancel();
      await expectLater(
        client.request(
          '/example',
          cancelToken: cancel,
          decode: (value) => value,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.isCancelled, 'canceled', true),
        ),
      );
    },
  );
}
