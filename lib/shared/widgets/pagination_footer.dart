import 'package:flutter/material.dart';

import 'app_loading_indicator.dart';

/// 只响应当前滚动容器；onLoadMore 须同步更新 isLoading，异步请求可复用动作锁。
class PaginationScrollListener extends StatefulWidget {
  const PaginationScrollListener({
    super.key,
    required this.child,
    required this.canLoadMore,
    required this.isLoading,
    required this.onLoadMore,
    this.threshold = 240,
  });
  final Widget child;
  final bool canLoadMore;
  final bool isLoading;
  final VoidCallback onLoadMore;
  final double threshold;

  @override
  State<PaginationScrollListener> createState() =>
      _PaginationScrollListenerState();
}

class _PaginationScrollListenerState extends State<PaginationScrollListener> {
  bool _queued = false;
  int _revision = 0;

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

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          final metrics = notification.metrics;
          final nearEnd = metrics.extentAfter <= widget.threshold;
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
          final revision = _revision;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || revision != _revision) return;
            _queued = false;
            if (widget.canLoadMore && !widget.isLoading) widget.onLoadMore();
          });
          return false;
        },
        child: widget.child,
      );
}

class PaginationFooter extends StatelessWidget {
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
  final bool hasMore;
  final bool isLoading;
  final Object? error;
  final VoidCallback onRetry;
  final String endLabel;
  final String loadingLabel;
  final String retryLabel;
  final Color? textColor;
  final Color? dividerColor;
  final Color? loadingColor;

  @override
  Widget build(BuildContext context) {
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
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [
          ...previous.map((child) => IgnorePointer(child: child)),
          if (current != null) current,
        ],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
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

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
        builder: (context, constraints) => Row(
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
