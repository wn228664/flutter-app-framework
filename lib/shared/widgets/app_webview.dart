import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'async_value_view.dart';

/// 默认只浏览初始来源，显式 allowedHosts 可扩展 HTTP(S) 站点；JavaScript 默认关闭。
class AppWebView extends StatefulWidget {
  const AppWebView({
    required this.url,
    this.allowedHosts = const {},
    this.javascriptEnabled = false,
    super.key,
  });
  final Uri url;
  final Set<String> allowedHosts;
  final bool javascriptEnabled;
  @override
  State<AppWebView> createState() => _AppWebViewState();
}

class _AppWebViewState extends State<AppWebView> {
  WebViewController? _controller;
  String? _error;
  int _progress = 0;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant AppWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.javascriptEnabled != widget.javascriptEnabled ||
        !setEquals(oldWidget.allowedHosts, widget.allowedHosts)) {
      unawaited(_initialize());
    }
  }

  Future<void> _initialize() async {
    final revision = ++_revision;
    final url = widget.url;
    final hosts = Set<String>.of(widget.allowedHosts);
    bool current() => mounted && revision == _revision;
    bool allowed(Uri? uri) =>
        uri != null &&
        {'http', 'https'}.contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        (uri.origin == url.origin || hosts.contains(uri.host));
    _error = null;
    _progress = 0;
    try {
      if (!{'http', 'https'}.contains(url.scheme) ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty) {
        throw const FormatException('仅支持 HTTP(S) 地址');
      }
      // 每个配置周期独立持有 controller，旧页面的进度/错误不能污染新页面。
      final controller = WebViewController();
      _controller = controller;
      await controller.setJavaScriptMode(
        widget.javascriptEnabled
            ? JavaScriptMode.unrestricted
            : JavaScriptMode.disabled,
      );
      if (!current()) return;
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              current() && allowed(Uri.tryParse(request.url))
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageStarted: (_) {
            if (current()) {
              setState(() {
                _error = null;
                _progress = 0;
              });
            }
          },
          onProgress: (progress) {
            if (current()) setState(() => _progress = progress.clamp(0, 100));
          },
          onPageFinished: (_) {
            if (current()) setState(() => _progress = 100);
          },
          onWebResourceError: (error) {
            if (current() && error.isForMainFrame == true) {
              setState(() => _error = '页面加载失败');
            }
          },
        ),
      );
      if (!current()) return;
      await controller.loadRequest(url);
    } catch (_) {
      if (current()) setState(() => _error = '无法打开页面，请检查地址与网络');
    }
  }

  @override
  void dispose() {
    _revision++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ErrorState(
        error: StateError(_error!),
        onRetry: () {
          setState(() {});
          unawaited(_initialize());
        },
      );
    }
    return Column(
      children: [
        if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
        if (_controller != null)
          Expanded(
            child: WebViewWidget(
              key: ObjectKey(_controller),
              controller: _controller!,
            ),
          ),
      ],
    );
  }
}
