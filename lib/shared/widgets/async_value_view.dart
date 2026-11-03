import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_exception.dart';
import 'app_loading_indicator.dart';

typedef AsyncErrorBuilder =
    Widget Function(BuildContext context, Object error, VoidCallback retry);

class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.isEmpty,
    this.errorBuilder,
  });
  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback onRetry;
  final bool Function(T value)? isEmpty;
  final AsyncErrorBuilder? errorBuilder;
  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (error, _) =>
          errorBuilder?.call(context, error, onRetry) ??
          ErrorState(error: error, onRetry: onRetry),
      data: (result) {
        if (isEmpty?.call(result) ?? false) return const EmptyState();
        return data(result);
      },
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.title = '暂无内容',
    this.body = '稍后再来看看',
    this.action,
  });
  final String title;
  final String body;
  final Widget? action;

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
