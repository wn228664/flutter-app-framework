// 连接状态覆盖层：内容始终保留；仅确定离线时遮罩，连接恢复自动刷新，平台检查失败不把未知状态误判为断网。

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'top_message.dart';

/// 监听连接类型并在离线时覆盖 child；只表示设备连接类型，不证明互联网或业务服务可达。
class NetworkStatusOverlay extends StatefulWidget {
  /// 接收保留的正文和刷新入口；流与初检可注入以隔离平台或进行测试。
  /// child：一直保留在树中的正文，断网遮罩不销毁其页面状态。
  /// onRefresh：手动重试或离线转在线时执行的刷新操作，可同步或异步。
  /// connectivityStream：可选连接事件流，不传则订阅 connectivity_plus。
  /// checkConnectivity：可选首次检查工厂，不传则使用插件检查。
  /// key：覆盖层元素身份，注入来源变化由生命周期比较处理。
  const NetworkStatusOverlay({
    required this.child,
    required this.onRefresh,
    this.connectivityStream,
    this.checkConnectivity,
    super.key,
  });

  /// 保持挂载的内容区域，离线时仅被覆盖。
  final Widget child;

  /// 调用方提供的数据刷新入口，覆盖层只管理其进行中和失败提示。
  final FutureOr<void> Function() onRefresh;

  /// 可选连接类型事件来源；换源会取消旧订阅并推进代次。
  final Stream<List<ConnectivityResult>>? connectivityStream;

  /// 可选首次检查来源；结果不能覆盖同周期已经收到的较新流事件。
  final Future<List<ConnectivityResult>> Function()? checkConnectivity;

  /// 为当前覆盖层创建独立订阅与刷新状态。
  @override
  State<NetworkStatusOverlay> createState() => _NetworkStatusOverlayState();
}

/// 管理连接监听、离线遮罩和刷新互斥；所有异步结果以连接源代次过滤。
class _NetworkStatusOverlayState extends State<NetworkStatusOverlay> {
  /// 当前连接源的事件订阅，换源及销毁时尝试取消。
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// 已知连接结果是否全为 none 或空列表；未知状态不视为离线。
  bool _offline = false;

  /// 是否收到至少一次有效连接结果，防止启动时闪现离线遮罩。
  bool _observedStatus = false;

  /// 本连接周期是否已有刷新在执行，防止恢复网络和手动按钮重复刷新。
  bool _refreshing = false;

  /// 最近刷新失败的安全提示，新刷新开始时清空。
  String? _refreshError;

  /// 监听来源的代次，换源或销毁时推进，拒绝旧检查、流事件和刷新结果。
  int _connectivityEpoch = 0;

  /// 组件挂载后建立连接监听并发起首次检查。
  @override
  void initState() {
    super.initState();
    unawaited(_listenToConnectivity());
  }

  /// 事件流或首次检查来源更换时重置可见连接标记并开始新周期。
  /// oldWidget：上一轮连接来源配置，仅比较注入流和检查函数的身份。
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

  /// 尽力取消旧监听；同步及异步取消失败均不阻断换源，代次检查继续过滤迟到事件。
  void _cancelSubscription() {
    try {
      // pending：取消订阅可能返回的 Future，异步失败被本地消化。
      final pending = _subscription?.cancel();
      if (pending != null) {
        unawaited(
          pending.catchError(
            /* 消化取消旧订阅时的异步错误，避免成为未处理异常。
         * 忽略的订阅取消异常；旧事件仍由代次过滤。 */
            (Object _) {},
          ),
        );
      }
    } catch (/* 忽略的同步取消异常，finally 仍清理本地订阅引用。 */ _) {
    } finally {
      _subscription = null;
    }
  }

  /// 先订阅再初检；流结果优先，未知平台错误保留正文；代次不符的任何结果直接忽略。
  Future<void> _listenToConnectivity() async {
    // epoch：此次连接来源周期的快照，用于隔离旧监听及初检。
    final epoch = ++_connectivityEpoch;
    _cancelSubscription();
    // connectivity：默认平台连接适配器，未注入来源时使用。
    final connectivity = Connectivity();
    // check：当前周期的初检工厂，优先使用调用方注入。
    final check = widget.checkConnectivity ?? connectivity.checkConnectivity;
    // stream：当前周期事件流，优先使用注入来源。
    final stream =
        widget.connectivityStream ?? connectivity.onConnectivityChanged;
    // observedEvent：本周期是否已经收到流事件，true 后迟到初检不得覆盖状态。
    var observedEvent = false;
    try {
      _subscription = stream.listen(
        /* 接收本周期有效流结果，标记流已观测后更新连接状态。
       * results：平台或测试发出的连接类型列表，可能为空。 */
        (results) {
          if (!mounted || epoch != _connectivityEpoch) return;
          observedEvent = true;
          _updateStatus(results);
        },
        onError: /* 连接事件流报错时保留现有内容与状态，不推断离线。
       * 忽略的流异常，未知平台状态不等于断网。
       * 忽略的流失败堆栈，不展示到界面。 */
            (Object _, StackTrace __) {},
      );
    } catch (/* 忽略的订阅建立异常，仍尝试一次首次检查。 */ _) {
      /* 平台尚不可用时保留内容，不把未知状态误判为断网。 */
    }
    try {
      // results：首次检查返回的类型列表，仅无较新流事件时采用。
      final results = await check();
      if (mounted && epoch == _connectivityEpoch && !observedEvent) {
        _updateStatus(results);
      }
    } catch (/* 忽略的首次检查异常，继续等待后续事件流。 */ _) {
      /* 首次检查失败时继续等待流事件。 */
    }
  }

  /// 将连接列表转成已观测离线标记；只有从离线恢复时自动刷新。
  /// results：当前有效周期的连接类型列表。
  void _updateStatus(List<ConnectivityResult> results) {
    if (!mounted) return;
    // nextOffline：列表为空或全部为 none 时为 true。
    final nextOffline =
        results.isEmpty ||
        results.every(
          /* 确认列表里每一种连接类型都表示无连接。
         * result：单个连接类型，只有 none 表示该项无连接。 */
          (result) => result == ConnectivityResult.none,
        );
    // wasOffline：更新前离线标记，用于识别恢复连接的边沿。
    final wasOffline = _offline;
    setState(
      /* 同时提交新离线结果和已观测标记，避免显示不完整状态。 */
      () {
        _offline = nextOffline;
        _observedStatus = true;
      },
    );
    if (wasOffline && !nextOffline) unawaited(_refreshPage());
  }

  /// 对本周期刷新加锁并清错误；失败显示可重试文案，在线时另发顶部消息，结束后仅解锁当前周期。
  Future<void> _refreshPage() async {
    if (_refreshing || !mounted) return;
    // epoch：刷新开始时的连接周期，换源后的旧结果不能修改新页面。
    final epoch = _connectivityEpoch;
    setState(
      /* 进入刷新中状态并清除上一次公开错误。 */
      () {
        _refreshing = true;
        _refreshError = null;
      },
    );
    try {
      await widget.onRefresh();
    } catch (/* 忽略的数据刷新原始异常，统一映射为可重试提示。 */ _) {
      if (mounted && epoch == _connectivityEpoch) {
        setState(
          /* 记录当前周期的刷新失败文案，供遮罩或顶部消息展示。 */
          () => _refreshError = '刷新失败，请重试',
        );
        if (!_offline) showTopMessage(context, _refreshError!);
      }
    } finally {
      if (mounted && epoch == _connectivityEpoch) {
        setState(/* 当前刷新结束且周期仍有效时解除刷新锁。 */ () => _refreshing = false);
      }
    }
  }

  /// 先使旧回调失效，再取消连接订阅并结束组件生命周期。
  @override
  void dispose() {
    _connectivityEpoch++;
    _cancelSubscription();
    super.dispose();
  }

  /// 正文保持挂载，仅在已知离线时叠加整页覆盖层。
  /// context：覆盖层构建上下文，正文与离线页共享继承环境。
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_observedStatus && _offline)
          _OfflineNetworkCover(
            onRefresh: /* 手动触发内部受锁保护的刷新，异常由内部转换为界面提示。 */ () =>
                unawaited(_refreshPage()),
            refreshing: _refreshing,
            error: _refreshError,
          ),
      ],
    );
  }
}

/// 可滚动离线遮罩，展示插画、恢复说明、刷新按钮与最近失败提示。
class _OfflineNetworkCover extends StatelessWidget {
  /// 接收刷新动作和进行中状态，不自行订阅网络或发起业务请求。
  /// onRefresh：用户点击手动刷新后的入口。
  /// refreshing：正在刷新时禁用按钮并更换文案。
  /// error：可选的最近刷新失败文案，空时显示连接检查提示。
  const _OfflineNetworkCover({
    required this.onRefresh,
    required this.refreshing,
    this.error,
  });

  /// 由父状态提供的刷新入口，父状态负责防重。
  final VoidCallback onRefresh;

  /// 刷新进行中标记，控制按钮禁用及文字。
  final bool refreshing;

  /// 可选刷新错误提示，不直接展示原始异常。
  final String? error;

  /// 在安全区和可滚动卡片内呈现离线状态，较大字体时允许刷新按钮增高。
  /// context：读取离线页语义色、文字样式和字体缩放。
  @override
  Widget build(BuildContext context) {
    // colors：离线遮罩使用的当前主题色集合。
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

/// 离线状态的纯装饰插画，由图标和色块组成，不提供交互。
class _OfflineNetworkArtwork extends StatelessWidget {
  /// 创建固定装饰插画，不保存连接状态。
  const _OfflineNetworkArtwork();

  /// 在固定插画画布中叠放信号点和网络图标，不参与正文布局定位。
  /// context：插画构建上下文；图形颜色使用明确的中性色。
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

/// 插画中的纯装饰圆点，不作为按钮或触控目标。
class _SignalDot extends StatelessWidget {
  /// 指定圆点填充色和逻辑直径。
  /// color：装饰圆点填充色。
  /// size：圆点的逻辑像素直径。
  const _SignalDot({required this.color, required this.size});

  /// 圆点填充色，可带透明度。
  final Color color;

  /// 圆点逻辑直径，同时决定宽高。
  final double size;

  /// 构建没有交互的圆形装饰。
  /// context：装饰构建上下文，不读取连接或刷新状态。
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: SizedBox.square(dimension: size),
  );
}

/// 插画中的圆形图标徽片，只负责视觉装饰。
class _NetworkChip extends StatelessWidget {
  /// 接收图标和强调色，使用统一徽片尺寸。
  /// icon：徽片中心展示的网络相关图标。
  /// color：图标及半透明描边的强调色。
  const _NetworkChip({required this.icon, required this.color});

  /// 中心图标数据，无点击行为。
  final IconData icon;

  /// 图标前景及边框着色来源。
  final Color color;

  /// 创建白底圆形装饰徽片，描边和图标共用强调色。
  /// context：徽片构建上下文；不依赖页面业务状态。
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
