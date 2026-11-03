import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'top_message.dart';

/// 只反映设备网络连接类型，不证明互联网可达；刷新数据由调用方负责，保留 child 状态。
class NetworkStatusOverlay extends StatefulWidget {
  const NetworkStatusOverlay({
    required this.child,
    required this.onRefresh,
    this.connectivityStream,
    this.checkConnectivity,
    super.key,
  });
  final Widget child;
  final FutureOr<void> Function() onRefresh;
  final Stream<List<ConnectivityResult>>? connectivityStream;
  final Future<List<ConnectivityResult>> Function()? checkConnectivity;

  @override
  State<NetworkStatusOverlay> createState() => _NetworkStatusOverlayState();
}

class _NetworkStatusOverlayState extends State<NetworkStatusOverlay> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _offline = false;
  bool _observedStatus = false;
  bool _refreshing = false;
  String? _refreshError;
  int _connectivityEpoch = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_listenToConnectivity());
  }

  @override
  void didUpdateWidget(covariant NetworkStatusOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectivityStream != widget.connectivityStream ||
        oldWidget.checkConnectivity != widget.checkConnectivity) {
      _offline = false;
      _observedStatus = false;
      _refreshing = false;
      unawaited(_listenToConnectivity());
    }
  }

  void _cancelSubscription() {
    try {
      final pending = _subscription?.cancel();
      if (pending != null) {
        unawaited(pending.catchError((Object _) {}));
      }
    } catch (_) {
    } finally {
      _subscription = null;
    }
  }

  Future<void> _listenToConnectivity() async {
    final epoch = ++_connectivityEpoch;
    _cancelSubscription();
    final connectivity = Connectivity();
    final check = widget.checkConnectivity ?? connectivity.checkConnectivity;
    final stream =
        widget.connectivityStream ?? connectivity.onConnectivityChanged;
    var observedEvent = false;
    try {
      _subscription = stream.listen((results) {
        if (!mounted || epoch != _connectivityEpoch) return;
        observedEvent = true;
        _updateStatus(results);
      }, onError: (Object _, StackTrace __) {});
    } catch (_) {
      /* 平台尚不可用时保留内容，不把未知状态误判为断网。 */
    }
    try {
      final results = await check();
      if (mounted && epoch == _connectivityEpoch && !observedEvent) {
        _updateStatus(results);
      }
    } catch (_) {
      /* 首次检查失败时继续等待流事件。 */
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    if (!mounted) return;
    final nextOffline =
        results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);
    final wasOffline = _offline;
    setState(() {
      _offline = nextOffline;
      _observedStatus = true;
    });
    if (wasOffline && !nextOffline) unawaited(_refreshPage());
  }

  Future<void> _refreshPage() async {
    if (_refreshing || !mounted) return;
    final epoch = _connectivityEpoch;
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });
    try {
      await widget.onRefresh();
    } catch (_) {
      if (mounted && epoch == _connectivityEpoch) {
        setState(() => _refreshError = '刷新失败，请重试');
        if (!_offline) showTopMessage(context, _refreshError!);
      }
    } finally {
      if (mounted && epoch == _connectivityEpoch) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  void dispose() {
    _connectivityEpoch++;
    _cancelSubscription();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_observedStatus && _offline)
          _OfflineNetworkCover(
            onRefresh: () => unawaited(_refreshPage()),
            refreshing: _refreshing,
            error: _refreshError,
          ),
      ],
    );
  }
}

class _OfflineNetworkCover extends StatelessWidget {
  const _OfflineNetworkCover({
    required this.onRefresh,
    required this.refreshing,
    this.error,
  });
  final VoidCallback onRefresh;
  final bool refreshing;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: ColoredBox(
        color: colors.surface,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.outlineVariant),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x120F172A),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _OfflineNetworkArtwork(),
                      const SizedBox(height: 24),
                      Text(
                        '网络暂时走丢了',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '请检查 Wi-Fi 或移动网络，连接恢复后页面会自动刷新。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: 48,
                          maxHeight:
                              MediaQuery.textScalerOf(context).scale(14) > 14
                              ? double.infinity
                              : 48,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: refreshing ? null : onRefresh,
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            label: Text(refreshing ? '正在刷新' : '手动刷新'),
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: colors.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        error ?? '请检查设备的网络连接',
                        style: TextStyle(
                          color: colors.primary.withValues(alpha: 0.72),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineNetworkArtwork extends StatelessWidget {
  const _OfflineNetworkArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 126,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 8,
            left: 20,
            child: _SignalDot(
              color: AppColors.brand.withValues(alpha: 0.15),
              size: 44,
            ),
          ),
          Positioned(
            top: 0,
            right: 16,
            child: _SignalDot(color: const Color(0xFFFFE6C7), size: 28),
          ),
          const Positioned(
            top: 3,
            left: 18,
            child: Icon(Icons.wifi_rounded, size: 40, color: AppColors.accent),
          ),
          Container(
            width: 112,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3F4),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFFFD4D8)),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: AppColors.brand,
            ),
          ),
          Positioned(
            bottom: 4,
            left: 8,
            child: _NetworkChip(
              icon: Icons.cloud_off_rounded,
              color: const Color(0xFF17745F),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 4,
            child: _NetworkChip(
              icon: Icons.sync_rounded,
              color: const Color(0xFFFF9E42),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalDot extends StatelessWidget {
  const _SignalDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: SizedBox.square(dimension: size),
  );
}

class _NetworkChip extends StatelessWidget {
  const _NetworkChip({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 10)],
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Icon(icon, color: color, size: 21),
  );
}
