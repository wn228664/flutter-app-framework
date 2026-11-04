// 异步展示边界：将 Riverpod 的加载、失败、空态和数据态映射成通用组件；重试操作与业务成功判断由调用方负责。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_exception.dart';
import 'app_loading_indicator.dart';

/// 自定义异步错误区构建器；接收原始异常和调用方提供的重试入口。
/// context：错误区域的构建上下文，可读取当前主题。
/// error：AsyncValue 携带的原始异常，不直接作为通用页面文案。
/// retry：调用方负责实现的重新加载操作。
typedef AsyncErrorBuilder =
    Widget Function(BuildContext context, Object error, VoidCallback retry);

/// 将 `AsyncValue<T>` 展示为加载、错误、空态或数据内容；T 的空值语义由 isEmpty 明确提供。
class AsyncValueView<T> extends StatelessWidget {
  /// 接收异步状态及各态构建策略，不在组件内发起请求。
  /// key：异步展示组件的元素身份。
  /// value：待展示的 Riverpod `AsyncValue<T>`。
  /// data：非空数据态的内容构建器。
  /// onRetry：错误区域触发的重新加载入口。
  /// isEmpty：可选空态判定，不提供则所有 data 值进入内容构建器。
  /// errorBuilder：可选错误展示覆盖，不提供则使用 ErrorState。
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.isEmpty,
    this.errorBuilder,
  });

  /// 当前异步状态；when 的刷新与重载语义沿用 Riverpod 默认行为。
  final AsyncValue<T> value;

  /// 非空数据内容构建器，不负责网络或持久化。
  /// value：已成功取得且未判空的 T 数据。
  final Widget Function(T value) data;

  /// 调用方提供的重试操作，组件不自行推断请求参数。
  final VoidCallback onRetry;

  /// 可选业务空态判定；返回 true 时展示默认 EmptyState。
  /// value：需要进行空态判断的已成功数据。
  final bool Function(T value)? isEmpty;

  /// 可选自定义错误区，接收异常和同一个重试入口。
  final AsyncErrorBuilder? errorBuilder;

  /// 选择异步展示状态，错误可定制，成功数据先判空再构建内容。
  /// context：用于错误构建器和子状态组件的构建上下文。
  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: /* 用统一加载指示器展示无数据的加载状态。 */ () =>
          const Center(child: AppLoadingIndicator()),
      error: /* 优先使用自定义错误区，否则交给安全文案的 ErrorState。
       * error：本次 AsyncValue 的失败对象。
       * 忽略的异步失败堆栈，不展示到用户界面。 */ (error, _) =>
          errorBuilder?.call(context, error, onRetry) ??
          ErrorState(error: error, onRetry: onRetry),
      data: /* 按调用方规则判空，非空时调用数据内容构建器。
       * result：当前成功状态中的 T 数据。 */ (result) {
        if (isEmpty?.call(result) ?? false) return const EmptyState();
        return data(result);
      },
    );
  }
}

/// 可滚动的通用失败视图；仅展示 ApiException 的公开提示，其余异常统一为安全文案。
class ErrorState extends StatelessWidget {
  /// 创建带重试按钮的错误区，调用方持有失败对象和重试动作。
  /// key：错误区域的元素身份。
  /// error：失败对象，只有 ApiException.message 会直接展示。
  /// onRetry：点击重新加载时调用的回调。
  const ErrorState({super.key, required this.error, required this.onRetry});

  /// 待展示错误，未知异常的内部信息不进入页面。
  final Object error;

  /// 重试入口；是否防重和发起请求由调用方负责。
  final VoidCallback onRetry;

  /// 构建安全错误文案及重试按钮，正文可滚动，较大字体下放开标题行数与按钮固定宽高。
  /// context：读取错误语义色、字号缩放和按钮主题。
  @override
  Widget build(BuildContext context) {
    // colors：当前亮暗主题的语义色，保持错误区与页面一致。
    final colors = Theme.of(context).colorScheme;
    // message：经过公开异常类型筛选的用户提示，未知错误不直接 toString。
    final message = error is ApiException
        ? (error as ApiException).message
        : '数据加载失败，请稍后重试';
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 30,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '内容加载失败',
                  maxLines: MediaQuery.textScalerOf(context).scale(16) > 16
                      ? null
                      : 1,
                  textAlign: MediaQuery.textScalerOf(context).scale(16) > 16
                      ? TextAlign.center
                      : null,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.5,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 148,
                    minHeight: 44,
                    maxWidth: MediaQuery.textScalerOf(context).scale(14) > 14
                        ? double.infinity
                        : 148,
                    maxHeight: MediaQuery.textScalerOf(context).scale(14) > 14
                        ? double.infinity
                        : 44,
                  ),
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('重新加载'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      overlayColor: Colors.transparent,
                      splashFactory: NoSplash.splashFactory,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 无数据时的通用提示区，允许调用方追加操作组件。
class EmptyState extends StatelessWidget {
  /// 创建可滚动空态，默认展示“暂无内容”和“稍后再来看看”。
  /// key：空态区域的元素身份。
  /// title：空态标题，默认“暂无内容”。
  /// body：补充说明，默认“稍后再来看看”。
  /// action：可选操作组件，不传时不保留按钮占位。
  const EmptyState({
    super.key,
    this.title = '暂无内容',
    this.body = '稍后再来看看',
    this.action,
  });

  /// 空态标题，使用当前主题的中等标题样式。
  final String title;

  /// 空态补充说明，居中显示并允许自然换行。
  final String body;

  /// 调用方提供的可选操作，不由空态组件决定业务行为。
  final Widget? action;

  /// 在可滚动区域中展示图标、标题、说明和可选操作，适应短视口。
  /// context：读取空态标题样式和继承主题。
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 46),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
