import 'package:flutter/material.dart';
import 'package:flutter_app_framework/shared/widgets/app_webview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class TestPlatform extends WebViewPlatform {
  final controllers = <TestController>[];
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = TestController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => TestDelegate(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => TestView(params);
}

class TestView extends PlatformWebViewWidget {
  TestView(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class TestController extends PlatformWebViewController {
  TestController(super.params) : super.implementation();
  JavaScriptMode? mode;
  TestDelegate? delegate;
  final requests = <Uri>[];
  @override
  Future<void> setJavaScriptMode(JavaScriptMode value) async {
    mode = value;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate value,
  ) async {
    delegate = value as TestDelegate;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    requests.add(params.uri);
    delegate?.finished?.call(params.uri.toString());
  }
}

class TestDelegate extends PlatformNavigationDelegate {
  TestDelegate(super.params) : super.implementation();
  NavigationRequestCallback? navigate;
  PageEventCallback? started, finished;
  ProgressCallback? progress;
  WebResourceErrorCallback? error;
  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback value) async {
    navigate = value;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback value) async {
    started = value;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback value) async {
    finished = value;
  }

  @override
  Future<void> setOnProgress(ProgressCallback value) async {
    progress = value;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback value) async {
    error = value;
  }
}

void main() {
  testWidgets(
    'WebView applies new URL/JS settings and discards old controller events',
    (tester) async {
      final platform = TestPlatform();
      WebViewPlatform.instance = platform;
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
      final first = platform.controllers.single;
      expect(first.mode, JavaScriptMode.unrestricted);
      await tester.pumpWidget(view('second.invalid', false));
      await tester.pumpAndSettle();
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
    (tester) async {
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
