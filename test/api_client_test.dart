// HTTP 契约回归：Dio 适配器完全隔离真实网络，验证响应不擅自解包、身份切换、401、路径限制与取消。

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_framework/core/network/api_client.dart';
import 'package:flutter_app_framework/core/network/api_exception.dart';
import 'package:flutter_app_framework/core/storage/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// 同步推进代次的内存会话替身，只用于 ApiClient 身份隔离测试。
class MemoryTokenStore implements TokenStore {
  /// 当前 mock 凭证，初始 test-token，不属于真实用户。
  String? token = 'test-token';

  /// mock 身份代次，每次写或清除都会递增。
  int generation = 0;

  /// 向客户端暴露 mock 身份代次。
  @override
  int get revision => generation;

  /// 返回当前 mock token，不访问平台安全存储。
  @override
  Future<String?> read() async => token;

  /// 推进代次并替换 mock 凭证，用于模拟请求期间切换身份。
  /// value：本用例希望切换到的新 mock 凭证。
  @override
  Future<void> write(String value) async {
    generation++;
    token = value;
  }

  /// 推进代次并清空 mock 凭证，用于观察当前 401 的清理行为。
  @override
  Future<void> clear() async {
    generation++;
    token = null;
  }
}

/// 由测试响应工厂驱动的 Dio 传输替身，不创建真实网络连接。
class TestAdapter implements HttpClientAdapter {
  /// 保存本用例响应工厂，在 Dio fetch 时调用。
  /// respond：接收真实 RequestOptions 并返回受控 ResponseBody 的工厂。
  TestAdapter(this.respond);

  /// 测试提供的响应工厂，负责断言请求或制造成功/失败。
  /// options：Dio 构造出的请求配置，可检查 Authorization 等字段。
  final Future<ResponseBody> Function(RequestOptions options) respond;

  /// 把请求配置交给工厂，忽略不需要的请求字节流与取消完成信号。
  /// options：Dio 最终提交给传输层的请求配置。
  /// requestStream：可选请求体字节流，本替身不消费。
  /// cancelFuture：Dio 取消完成信号，本替身无需等待它。
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);

  /// 空实现；替身没有连接资源，仍满足 Dio 关闭接口。
  /// force：Dio 传入的强制关闭标记，替身没有待取消连接。
  @override
  void close({bool force = false}) {}
}

/// 注册 ApiClient 的配置、响应、会话、路径及取消回归。
void main() {
  test(
    'backend configuration is required only when sending a request',
    /* 验证空 API 基址允许创建客户端，但真正请求必须明确报 API_NOT_CONFIGURED。 */
    () async {
      // client：空基址客户端，结束时统一 close。
      final client = ApiClient(baseUrl: '', tokenStore: MemoryTokenStore());
      addTearDown(client.close);
      await expectLater(
        client.request(
          '/example',
          decode: /* 原样返回载荷的解码器；配置失败时不应调用。
         * data：候选响应载荷，此用例不会到达成功解码。 */ (data) =>
              data,
        ),
        throwsA(
          isA<ApiException>().having(
            /* 提取公开错误码用于配置失败断言。
             * error：已限定为 ApiException 的实际异常。 */
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
    /* 验证正确附加 Bearer，业务 success:false 仍原样交给调用方判断。 */
    () async {
      // dio：装有隔离响应工厂的客户端，用于检查实际请求头。
      final dio = Dio()
        ..httpClientAdapter = TestAdapter(
          /* 核对 Authorization 并返回 HTTP 200 的业务失败信封。
         * options：真实构造的请求配置，检查其中 Bearer token。 */
          (options) async {
            expect(options.headers['Authorization'], 'Bearer test-token');
            return ResponseBody.fromString(
              '{"success":false}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          },
        );
      // client：使用隔离 Dio 与 mock 会话的受测客户端。
      final client = ApiClient(
        baseUrl: 'https://example.invalid',
        tokenStore: MemoryTokenStore(),
        dio: dio,
      );
      addTearDown(client.close);
      expect(
        await client.request(
          '/example',
          decode: /* 原样返回业务信封，证明框架不擅自把 success:false 当异常。
       * data：Dio 解码后的业务对象。 */ (data) =>
              data,
        ),
        {'success': false},
      );
    },
  );
  test(
    'late 401 cannot clear a new session',
    /* 模拟旧身份请求返回 401，断言新凭证保留且报 SESSION_CHANGED。 */
    () async {
      // store：在响应返回前切换身份的 mock 会话。
      final store = MemoryTokenStore();
      // dio：返回迟到 401 的隔离传输。
      final dio = Dio()
        ..httpClientAdapter = TestAdapter(
          /* 先切换到 new-session，再返回旧请求的 401。
       * options：本次旧身份请求配置，此用例不另检查其字段。 */
          (options) async {
            await store.write('new-session');
            return ResponseBody.fromString('', 401);
          },
        );
      // client：接入可切换 mock 会话的客户端。
      final client = ApiClient(
        baseUrl: 'https://example.invalid',
        tokenStore: store,
        dio: dio,
      );
      addTearDown(client.close);
      await expectLater(
        client.request(
          '/example',
          decode: /* 成功载荷直通解码器，迟到 401 场景不应调用。
       * data：候选响应载荷，此失败路径不会成功返回。 */ (data) =>
              data,
        ),
        throwsA(
          isA<ApiException>().having(
            /* 提取身份隔离错误码，断言为 SESSION_CHANGED。
           * error：迟到 401 经身份复验后得到的 ApiException。 */
            (error) => error.code,
            'code',
            'SESSION_CHANGED',
          ),
        ),
      );
      expect(store.token, 'new-session');
    },
  );
  test(
    'a current 401 clears the session',
    /* 验证当前身份 401 会清除凭证并保留 HTTP 状态。 */
    () async {
      // store：代次保持不变直到当前 401 被处理的 mock 会话。
      final store = MemoryTokenStore();
      // dio：固定返回 401 的隔离传输。
      final dio = Dio()
        ..httpClientAdapter = TestAdapter(
          /* 返回当前身份的 HTTP 401，不触发身份切换。
         * 忽略的 RequestOptions，此场景只验证状态处理。 */
          (_) async => ResponseBody.fromString('', 401),
        );
      // client：处理当前 401 的受测客户端。
      final client = ApiClient(
        baseUrl: 'https://example.invalid',
        tokenStore: store,
        dio: dio,
      );
      addTearDown(client.close);
      await expectLater(
        client.request(
          '/example',
          decode: /* 直通响应的候选解码器，401 不会调用。
       * data：候选成功载荷，当前场景保持未消费。 */ (data) =>
              data,
        ),
        throwsA(
          isA<ApiException>().having(
            /* 提取 HTTP 状态以确认 401 被公开保留。
         * error：当前 401 对应的 ApiException。 */
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(store.token, isNull);
    },
  );
  test(
    'absolute URLs cannot receive the app token',
    /* 验证绝对外站 URL 在传输前被拒绝，避免泄露应用凭证。 */
    () async {
      // client：配置合法基址的客户端，用于验证非法 path。
      final client = ApiClient(
        baseUrl: 'https://example.invalid',
        tokenStore: MemoryTokenStore(),
      );
      addTearDown(client.close);
      await expectLater(
        client.request(
          'https://external.invalid',
          decode: /* 候选直通解码器；非法绝对地址不会进入解码。
       * data：未被消费的候选响应载荷。 */ (data) =>
              data,
        ),
        throwsA(
          isA<ApiException>().having(
            /* 提取非法路径的公开错误码。
           * error：绝对地址校验得到的 ApiException。 */
            (error) => error.code,
            'code',
            'INVALID_PATH',
          ),
        ),
      );
    },
  );
  test(
    'an old successful response is rejected before its decoder runs',
    /* 验证成功响应也先检查代次，旧身份载荷不能调用解码器。 */
    () async {
      // store：在传输工厂中切换到新凭证的 mock 会话。
      final store = MemoryTokenStore();
      // decoded：解码器是否执行，身份切换后必须仍为 false。
      var decoded = false;
      // dio：先改身份再返回 HTTP 200 的隔离客户端。
      final dio = Dio()
        ..httpClientAdapter = TestAdapter(
          /* 写入新身份后返回成功载荷，制造迟到成功响应。
         * 忽略的请求配置，场景重点为返回前身份变化。 */
          (_) async {
            await store.write('new');
            return ResponseBody.fromString(
              '{}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          },
        );
      // client：接入受控成功响应和 mock 会话的客户端。
      final client = ApiClient(
        baseUrl: 'https://example.invalid',
        tokenStore: store,
        dio: dio,
      );
      addTearDown(client.close);
      await expectLater(
        client.request(
          '/example',
          decode: /* 标记解码器已执行，用于捕获旧身份载荷被误消费。
           * value：候选旧身份响应 data，正确实现不应交到这里。 */ (value) {
            decoded = true;
            return value;
          },
        ),
        throwsA(
          isA<ApiException>().having(
            /* 提取旧成功响应触发的 SESSION_CHANGED 错误码。
           * e：身份复验拒绝旧响应时的 ApiException。 */
            (e) => e.code,
            'code',
            'SESSION_CHANGED',
          ),
        ),
      );
      expect(decoded, false);
    },
  );
  test(
    'unsafe relative paths and canceled requests never reach the transport',
    /* 验证危险相对路径及预先取消请求都不会到达传输工厂。 */
    () async {
      // dio：一旦真正进入传输就立即 fail 的隔离客户端。
      final dio = Dio()
        ..httpClientAdapter = TestAdapter(
          /* 若传输被调用立即失败，证明前置校验或取消边界失效。
         * 忽略的请求配置，任何进入本工厂的请求都不应发生。 */
          (_) async {
            fail('unexpected transport request');
          },
        );
      // client：执行路径及取消前置校验的受测客户端。
      final client = ApiClient(
        baseUrl: 'https://example.invalid',
        tokenStore: MemoryTokenStore(),
        dio: dio,
      );
      addTearDown(client.close);
      for ( /* path：当前危险路径样例，包括外站双斜杠、反斜杠和换行。 */ final path in [
        '//external.invalid',
        '/\\external.invalid',
        '/bad\npath',
      ]) {
        await expectLater(
          client.request(
            path,
            decode: /* 候选直通解码器，危险路径不会取得响应。
           * value：此失败路径不应出现的响应载荷。 */ (value) =>
                value,
          ),
          throwsA(
            isA<ApiException>().having(
              /* 提取危险路径对应的 INVALID_PATH 错误码。
             * e：路径校验得到的 ApiException。 */
              (e) => e.code,
              'code',
              'INVALID_PATH',
            ),
          ),
        );
      }
      // cancel：创建后立即取消的令牌，发送请求前已处于取消态。
      final cancel = CancelToken()..cancel();
      await expectLater(
        client.request(
          '/example',
          cancelToken: cancel,
          decode: /* 候选直通解码器，预取消请求不应调用。
           * value：预取消路径不应取得的响应载荷。 */ (value) =>
              value,
        ),
        throwsA(
          isA<ApiException>().having(
            /* 读取 isCancelled 标记，确认取消被转换为统一公开异常。
           * e：预取消请求对应的 ApiException。 */
            (e) => e.isCancelled,
            'canceled',
            true,
          ),
        ),
      );
    },
  );
}
