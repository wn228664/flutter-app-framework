// WebView 生命周期回归：完整替换平台实现，记录脚本、导航委托和请求；验证配置重建及旧事件隔离，不连接真实网页。

import 'package:flutter/material.dart';
import 'package:flutter_app_framework/shared/widgets/app_webview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// 记录平台控制器创建的 WebViewPlatform 替身，不启动真实原生 WebView。
class TestPlatform extends WebViewPlatform {
  /// 已创建的控制器序列，用于区分新旧配置周期。
  final controllers = <TestController>[];

  /// 创建可观测控制器并保留引用供测试注入迟到事件。
  /// params：插件传入的平台控制器创建参数。
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    // controller：本次新建的受控平台控制器。
    final controller = TestController(params);
    controllers.add(controller);
    return controller;
  }

  /// 创建保存导航与资源事件回调的替身委托。
  /// params：插件传入的导航委托创建参数。
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => TestDelegate(params);

  /// 创建无原生资源的测试视图，保留插件接口契约。
  /// params：插件传入的视图创建参数。
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => TestView(params);
}

/// 以空白占位替代原生 WebView 的测试组件。
class TestView extends PlatformWebViewWidget {
  /// 按平台接口要求转发视图创建参数。
  /// params：转发给 PlatformWebViewWidget.implementation 的参数。
  TestView(super.params) : super.implementation();

  /// 占满分配区域，不创建原生视图或网络连接。
  /// context：测试平台视图的构建上下文。
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// 可记录脚本权限、导航委托和加载地址的控制器替身。
class TestController extends PlatformWebViewController {
  /// 转发平台创建参数，保持插件控制器接口。
  /// params：平台控制器创建参数，交给 implementation 构造器。
  TestController(super.params) : super.implementation();

  /// 最近设置的 JavaScriptMode，用于确认配置切换生效。
  JavaScriptMode? mode;

  /// 当前注册的测试导航委托，测试可通过它发送页面事件。
  TestDelegate? delegate;

  /// 该控制器实际收到的加载 URI 列表。
  final requests = <Uri>[];

  /// 记录脚本开关，异步接口立即成功完成。
  /// value：AppWebView 请求的平台脚本权限。
  @override
  Future<void> setJavaScriptMode(JavaScriptMode value) async {
    mode = value;
  }

  /// 保存测试委托，供后续模拟完成、进度和导航事件。
  /// value：由当前 TestPlatform 创建的 TestDelegate。
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate value,
  ) async {
    delegate = value as TestDelegate;
  }

  /// 记录 URI 并模拟页面已完成，避免测试依赖真实网页加载。
  /// params：包含目标 uri 的平台加载请求参数。
  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    requests.add(params.uri);
    delegate?.finished?.call(params.uri.toString());
  }
}

/// 保存平台回调的导航委托替身，测试可直接调用新旧周期事件。
class TestDelegate extends PlatformNavigationDelegate {
  /// 转发导航委托创建参数，不建立额外平台资源。
  /// params：PlatformNavigationDelegate 创建参数。
  TestDelegate(super.params) : super.implementation();

  /// 应用注册的导航许可回调，可用来断言来源限制。
  NavigationRequestCallback? navigate;

  /// started：页面开始事件，用于模拟加载周期。
  /// finished：页面结束事件，控制器加载替身会调用它。
  PageEventCallback? started, finished;

  /// 应用注册的进度回调，用于向旧控制器注入迟到进度。
  ProgressCallback? progress;

  /// 应用注册的资源错误回调，供需要时注入平台失败。
  WebResourceErrorCallback? error;

  /// 记录应用的导航授权判断回调。
  /// value：待注册的导航许可函数。
  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback value) async {
    navigate = value;
  }

  /// 记录页面开始事件回调。
  /// value：应用的 onPageStarted 处理器。
  @override
  Future<void> setOnPageStarted(PageEventCallback value) async {
    started = value;
  }

  /// 记录页面结束事件回调。
  /// value：应用的 onPageFinished 处理器。
  @override
  Future<void> setOnPageFinished(PageEventCallback value) async {
    finished = value;
  }

  /// 记录页面进度处理器，允许模拟迟到旧事件。
  /// value：接收 0 至 100 平台进度的应用回调。
  @override
  Future<void> setOnProgress(ProgressCallback value) async {
    progress = value;
  }

  /// 记录资源错误处理器。
  /// value：接收平台 WebResourceError 的应用回调。
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback value) async {
    error = value;
  }
}

/// 注册 WebView 配置切换、来源限制、旧事件隔离及非法初始地址回归。
void main() {
  testWidgets(
    'WebView applies new URL/JS settings and discards old controller events',
    /* 验证新 URL/脚本配置创建新控制器，旧进度不污染新页面，跨来源与降级协议导航被阻止。
     * tester：重建 WebView 配置并驱动平台回调后的组件更新。 */
    (tester) async {
      // platform：记录本用例全部控制器的隔离平台替身。
      final platform = TestPlatform();
      WebViewPlatform.instance = platform;

      /// 按 host 与脚本开关构造相同位置的 AppWebView，触发 didUpdateWidget 路径。
      /// host：初始 HTTPS URL 的主机名。
      /// js：本次配置是否显式启用 JavaScript。
      Widget view(String host, bool js) => MaterialApp(
        home: Scaffold(
          body: AppWebView(
            url: Uri.parse('https://$host/start'),
            javascriptEnabled: js,
          ),
        ),
      );
      await tester.pumpWidget(view('first.invalid', true));
      await tester.pumpAndSettle();
      // first：旧配置周期的控制器，后续用于发送过期进度。
      final first = platform.controllers.single;
      expect(first.mode, JavaScriptMode.unrestricted);
      await tester.pumpWidget(view('second.invalid', false));
      await tester.pumpAndSettle();
      // second：新配置周期控制器，必须加载新主机并关闭脚本。
      final second = platform.controllers.last;
      expect(second.requests.single.host, 'second.invalid');
      expect(second.mode, JavaScriptMode.disabled);
      first.delegate!.progress!(10);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        await second.delegate!.navigate!(
          const NavigationRequest(
            url: 'https://external.invalid',
            isMainFrame: true,
          ),
        ),
        NavigationDecision.prevent,
      );
      expect(
        await second.delegate!.navigate!(
          const NavigationRequest(
            url: 'http://second.invalid',
            isMainFrame: true,
          ),
        ),
        NavigationDecision.prevent,
      );
      expect(
        await second.delegate!.navigate!(
          const NavigationRequest(
            url: 'https://second.invalid/next',
            isMainFrame: true,
          ),
        ),
        NavigationDecision.navigate,
      );
      await tester.pumpWidget(const SizedBox());
      first.delegate!.progress!(20);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'invalid WebView URLs do not create a platform view and can be replaced',
    /* 验证 file 初始地址不创建平台控制器，更换为合法 HTTPS 后可以恢复。
     * tester：依次构建非法和合法地址并检查错误态。 */
    (tester) async {
      // platform：非法地址恢复场景的隔离平台替身。
      final platform = TestPlatform();
      WebViewPlatform.instance = platform;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppWebView(url: Uri.parse('file:///private/example')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(platform.controllers, isEmpty);
      expect(find.text('重新加载'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppWebView(url: Uri.parse('https://example.invalid')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(platform.controllers.length, 1);
      expect(find.text('重新加载'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
