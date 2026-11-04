// 分页触发与页脚：只响应当前竖向容器的滚动，帧后触发受代次保护；调用方须同步 isLoading 并负责请求及取消。

import 'package:flutter/material.dart';

import 'app_loading_indicator.dart';

/// 监听当前竖向容器接近底部的滚动更新；帧内只排队一次，不替调用方实现请求互斥。
class PaginationScrollListener extends StatefulWidget {
  /// 接收分页可用状态与同步触发入口；默认距离底部 240 逻辑像素时允许加载。
  /// key：监听器元素身份，用于父级控制复用。
  /// child：被监听的滚动区域，只消费其 depth 0 通知。
  /// canLoadMore：业务上是否仍可请求下一页。
  /// isLoading：调用方的请求中标记，必须在 onLoadMore 中同步推进。
  /// onLoadMore：帧后触发下一页的同步入口，异步互斥由调用方负责。
  /// threshold：剩余滚动距离阈值，逻辑像素，默认 240。
  const PaginationScrollListener({
    super.key,
    required this.child,
    required this.canLoadMore,
    required this.isLoading,
    required this.onLoadMore,
    this.threshold = 240,
  });

  /// 目标滚动区域，子树内嵌滚动容器的通知不触发加载。
  final Widget child;

  /// 还有后续页时才允许排队和最终触发。
  final bool canLoadMore;

  /// 调用方的加载标记；帧后执行前再次核对，防止重复触发。
  final bool isLoading;

  /// 加载入口，调用方必须同步切换加载状态或使用动作锁。
  final VoidCallback onLoadMore;

  /// 触发加载的剩余滚动距离阈值。
  final double threshold;

  /// 创建帧内排队标记及配置代次。
  @override
  State<PaginationScrollListener> createState() =>
      _PaginationScrollListenerState();
}

/// 以 queued 合并同帧通知，以 revision 拒绝配置变化前排队的回调。
class _PaginationScrollListenerState extends State<PaginationScrollListener> {
  /// 当前帧是否已有待执行加载回调，不代表网络请求进行中。
  bool _queued = false;

  /// 分页配置代次，关键状态或正文身份变化时推进。
  int _revision = 0;

  /// 分页条件、回调或正文 key 变化时使旧帧后回调失效并释放排队标记。
  /// oldWidget：上一帧配置，用于比较分页条件、阈值、加载回调及 child.key。
  @override
  void didUpdateWidget(covariant PaginationScrollListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canLoadMore != widget.canLoadMore ||
        oldWidget.isLoading != widget.isLoading ||
        oldWidget.threshold != widget.threshold ||
        oldWidget.onLoadMore != widget.onLoadMore ||
        oldWidget.child.key != widget.child.key) {
      _revision++;
      _queued = false;
    }
  }

  /// 监听当前容器的竖向更新或越界滚动，接近底部且可加载时排一个帧后回调；不拦截通知冒泡。
  /// context：滚动监听器的构建上下文，分页状态由显式字段传入。
  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: /* 筛选当前竖向容器有效移动事件，并在帧后复验加载条件。
         * notification：滚动指标、深度和事件类型来源；返回 false 保留冒泡。 */ (notification) {
          // metrics：当前通知的滚动尺寸及轴向。
          final metrics = notification.metrics;
          // nearEnd：剩余内容距离不大于配置阈值。
          final nearEnd = metrics.extentAfter <= widget.threshold;
          // positionChanged：仅实际滚动更新或越界滚动符合触发条件。
          final positionChanged =
              notification is ScrollUpdateNotification ||
              notification is OverscrollNotification;
          if (notification.depth != 0 ||
              !widget.canLoadMore ||
              widget.isLoading ||
              _queued ||
              metrics.axis != Axis.vertical ||
              !positionChanged ||
              !nearEnd) {
            return false;
          }
          _queued = true;
          // revision：排队时配置代次，帧后不一致则忽略。
          final revision = _revision;
          WidgetsBinding.instance.addPostFrameCallback(
            /* 在布局帧结束后触发加载，避免滚动通知期间修改父级状态。
           * 忽略的帧时间戳，触发只依赖挂载、代次和加载条件。 */
            (_) {
              if (!mounted || revision != _revision) return;
              _queued = false;
              if (widget.canLoadMore && !widget.isLoading) widget.onLoadMore();
            },
          );
          return false;
        },
        child: widget.child,
      );
}

/// 统一展示分页加载、错误重试或终点；仍有下一页但空闲时不显示正文。
class PaginationFooter extends StatelessWidget {
  /// 接收分页状态和可选文案/颜色；加载态优先于错误，错误优先于终点。
  /// key：页脚组件元素身份。
  /// hasMore：是否还有下一页，false 且无加载或错误时显示终点。
  /// isLoading：是否正在请求，true 时优先展示加载态。
  /// error：上一笔分页失败对象，非空时展示安全重试文案。
  /// onRetry：用户触发重试的入口，互斥由调用方负责。
  /// endLabel：终点提示，默认“我也是有底线的”。
  /// loadingLabel：加载显示及读屏文案，默认“正在加载更多”。
  /// retryLabel：错误按钮安全文案，不展示 error.toString。
  /// textColor：可选前景色，不传则使用主题 onSurfaceVariant。
  /// dividerColor：可选终点分隔线颜色，默认主题 outlineVariant。
  /// loadingColor：可选加载动画颜色，默认主题 primary。
  const PaginationFooter({
    super.key,
    required this.hasMore,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    this.endLabel = '我也是有底线的',
    this.loadingLabel = '正在加载更多',
    this.retryLabel = '加载失败，点击重试',
    this.textColor,
    this.dividerColor,
    this.loadingColor,
  });

  /// 后续页可用标记，空闲且为 true 时页脚收起。
  final bool hasMore;

  /// 加载状态，优先级高于错误与终点。
  final bool isLoading;

  /// 是否失败的依据，正文不暴露此对象的内部信息。
  final Object? error;

  /// 错误态重试回调，页脚动画不负责请求生命周期。
  final VoidCallback onRetry;

  /// 终点文案，同时作为独立读屏提示。
  final String endLabel;

  /// 加载文案与动画语义标签。
  final String loadingLabel;

  /// 错误态按钮文案。
  final String retryLabel;

  /// 页脚文字及重试图标的可选着色。
  final Color? textColor;

  /// 终点两侧分隔线的可选着色。
  final Color? dividerColor;

  /// 三点加载动画的可选着色。
  final Color? loadingColor;

  /// 按状态键切换动画；淡出子树禁止点击，避免旧重试按钮继续响应。
  /// context：页脚构建上下文，传给状态正文读取主题。
  @override
  Widget build(BuildContext context) {
    // stateKey：loading、error、idle 或 end，保证 AnimatedSwitcher 识别状态变化。
    final stateKey = isLoading
        ? 'loading'
        : error != null
        ? 'error'
        : hasMore
        ? 'idle'
        : 'end';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      // 淡出的旧重试按钮仍在树中，必须退出点击和辅助操作路径。
      layoutBuilder: /* 叠放新旧状态，并隔离仍在淡出的旧子树交互。
       * current：当前状态的正文组件，可能为空。
       * previous：仍在退出动画中的旧正文列表。 */ (current, previous) => Stack(
        alignment: Alignment.center,
        children: [
          ...previous.map(
            /* 为每个淡出旧子树增加 IgnorePointer，阻断残留点击。
           * child：一个尚未完成退出动画的旧状态组件。 */
            (child) => IgnorePointer(child: child),
          ),
          if (current != null) current,
        ],
      ),
      transitionBuilder: /* 对状态变化同时应用透明度和尺寸过渡。
       * child：本次参与过渡的状态正文。
       * animation：AnimatedSwitcher 提供的进入或退出动画进度。 */ (child, animation) =>
          FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, child: child),
          ),
      child: ConstrainedBox(
        key: ValueKey('pagination-footer-$stateKey'),
        constraints: const BoxConstraints(minHeight: 52),
        child: Center(heightFactor: 1, child: _buildContent(context)),
      ),
    );
  }

  /// 按加载、错误、空闲和终点优先级构建正文；终点文字为窄屏约束最大宽度。
  /// context：读取当前页脚语义色及布局环境。
  Widget _buildContent(BuildContext context) {
    // colors：当前主题的加载和分隔语义色来源。
    final colors = Theme.of(context).colorScheme;
    // foreground：调用方覆盖色或主题次级前景色。
    final foreground = textColor ?? colors.onSurfaceVariant;
    if (isLoading) {
      return Semantics(
        liveRegion: true,
        label: loadingLabel,
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLoadingIndicator(
                compact: true,
                color: loadingColor ?? colors.primary,
                semanticLabel: loadingLabel,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  loadingLabel,
                  style: TextStyle(color: foreground, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (error != null) {
      return TextButton.icon(
        key: const ValueKey('pagination-footer-retry'),
        onPressed: onRetry,
        icon: Icon(Icons.refresh, size: 17, color: foreground),
        label: Text(
          retryLabel,
          style: TextStyle(color: foreground, fontSize: 12),
        ),
      );
    }
    if (hasMore) return const SizedBox.shrink();
    return Semantics(
      label: endLabel,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: /* 依据实际可用宽度分配终点文字空间，保留两侧分隔线。
         * context：终点局部布局上下文，此处无需额外读取。
         * constraints：终点容器的宽度约束，用于扣除分隔线缩进。 */ (context, constraints) => Row(
          children: [
            Expanded(
              child: Divider(
                color: dividerColor ?? colors.outlineVariant,
                indent: 30,
                endIndent: 12,
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (constraints.maxWidth - 2 * (30 + 12))
                    .clamp(0.0, double.infinity)
                    .toDouble(),
              ),
              child: Text(
                endLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: foreground, fontSize: 11),
              ),
            ),
            Expanded(
              child: Divider(
                color: dividerColor ?? colors.outlineVariant,
                indent: 12,
                endIndent: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
