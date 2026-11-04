// 受限 WebView：默认关闭 JavaScript，只允许初始 origin 或显式允许的 HTTP(S) host；不注册原生 Bridge，旧配置事件由 revision 隔离。

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'async_value_view.dart';

/// 可重建配置的受限网页容器；初始地址必须为无凭证的 HTTP(S)，后续导航也执行来源检查。
class AppWebView extends StatefulWidget {
  /// 接收初始地址与显式权限；默认不扩展 host，也不启用 JavaScript。
  /// url：初始 HTTP(S) 地址，必须有 host 且不含 userInfo。
  /// allowedHosts：允许跨 origin 导航的精确 host 集合；不自动包含子域，不限制为初始端口。
  /// javascriptEnabled：显式 true 才开启网页脚本，不提供原生消息 Bridge。
  /// key：WebView 容器元素身份，配置变化由 didUpdateWidget 处理。
  const AppWebView({
    required this.url,
    this.allowedHosts = const {},
    this.javascriptEnabled = false,
    super.key,
  });

  /// 当前初始地址及默认允许的 origin 来源。
  final Uri url;

  /// 额外允许的 host；每次初始化复制快照，避免旧闭包读取后续集合变动。
  final Set<String> allowedHosts;

  /// 网页脚本开关，默认 false；修改后创建新控制器。
  final bool javascriptEnabled;

  /// 创建独立控制器状态，页面之间不共享进度和错误。
  @override
  State<AppWebView> createState() => _AppWebViewState();
}

/// 持有当前配置周期的控制器、进度及公开错误；异步回调先检查 mounted 和 revision。
class _AppWebViewState extends State<AppWebView> {
  /// 当前周期创建的平台控制器，初始化前为空。
  WebViewController? _controller;

  /// 可展示的加载失败提示；旧周期的失败不得覆盖新页面。
  String? _error;

  /// 当前页面进度 0 到 100，未完成时展示线性进度条。
  int _progress = 0;

  /// 配置周期代次；重新初始化或销毁时推进以拒绝旧事件。
  int _revision = 0;

  /// 挂载时异步初始化控制器，初始化内部负责呈现失败。
  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  /// URL、脚本权限或 host 集合内容变化时开始新的控制器周期。
  /// oldWidget：上一次配置，用于逐项比较地址、脚本开关和 host 集合。
  @override
  void didUpdateWidget(covariant AppWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.javascriptEnabled != widget.javascriptEnabled ||
        !setEquals(oldWidget.allowedHosts, widget.allowedHosts)) {
      unawaited(_initialize());
    }
  }

  /// 捕获配置快照并顺序设置脚本、导航委托及初始请求；每个 await 后拒绝过期周期，失败转换成安全提示。
  Future<void> _initialize() async {
    // revision：此初始化周期的代次，所有页面事件闭包捕获它。
    final revision = ++_revision;
    // url：当前周期初始地址快照，也是默认导航 origin 的基准。
    final url = widget.url;
    // hosts：当前周期额外允许 host 的独立副本。
    final hosts = Set<String>.of(widget.allowedHosts);

    /// 只允许仍挂载且代次一致的周期修改状态。
    bool current() => mounted && revision == _revision;

    /// 校验候选导航为无凭证的 HTTP(S)，且同初始 origin 或精确命中允许 host。
    /// uri：导航地址解析结果，解析失败的 null 直接拒绝。
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
      // controller：当前配置周期专有的 WebView 控制器，不复用旧页面控制器。
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
          onNavigationRequest: /* 仅在周期有效且来源许可时放行导航，其余请求明确阻止。
           * request：平台报告的导航请求，读取 url 执行来源限制。 */ (request) =>
              current() && allowed(Uri.tryParse(request.url))
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageStarted: /* 当前页面开始加载时清空错误并把进度归零。
           * 忽略的平台页面地址；导航授权已由 onNavigationRequest 负责。 */ (_) {
            if (current()) {
              setState(
                /* 原子重置当前周期的错误与加载进度。 */
                () {
                  _error = null;
                  _progress = 0;
                },
              );
            }
          },
          onProgress: /* 仅接受当前周期进度，并夹取到 0 至 100。
           * progress：平台回传的加载百分比，写入前校正范围。 */ (progress) {
            /* 将已夹取的进度写入组件状态并触发重建。 */
            if (current()) setState(() => _progress = progress.clamp(0, 100));
          },
          onPageFinished: /* 当前页面完成后把进度标为 100。
           * 忽略的完成地址；周期检查负责过滤旧页面事件。 */ (_) {
            /* 完成当前周期进度，隐藏加载条。 */
            if (current()) setState(() => _progress = 100);
          },
          onWebResourceError: /* 仅主框架失败才替换整页，子资源错误不遮蔽已加载内容。
           * error：平台资源加载异常，通过 isForMainFrame 判断是否影响整页。 */ (error) {
            if (current() && error.isForMainFrame == true) {
              setState(/* 记录当前主框架的安全失败提示。 */ () => _error = '页面加载失败');
            }
          },
        ),
      );
      if (!current()) return;
      await controller.loadRequest(url);
    } catch (/* 忽略的初始化或加载原始异常，统一转为安全提示。 */ _) {
      /* 仅为仍有效的初始化周期展示打开失败提示。 */
      if (current()) setState(() => _error = '无法打开页面，请检查地址与网络');
    }
  }

  /// 推进代次使平台迟到事件失效，再结束组件生命周期。
  @override
  void dispose() {
    _revision++;
    super.dispose();
  }

  /// 错误时展示可重试视图，否则显示进度及当前控制器网页；控制器身份改变时重建平台视图。
  /// context：WebView 容器构建上下文，错误视图使用其继承主题。
  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ErrorState(
        error: StateError(_error!),
        onRetry: /* 用户重试时触发重建并开始新的初始化周期。 */ () {
          setState(/* 请求一次本组件重建；后续错误清理与新控制器建立由初始化完成。 */ () {});
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
