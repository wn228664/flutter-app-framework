// 顶部消息：同一 ScaffoldMessenger 只保留最新一条；代次和关闭标记隔离旧计时器，长文本在自身区域内滚动。

import 'dart:async';

import 'package:flutter/material.dart';

/// 按 messenger 弱关联保存消息代次；不强持有已离开的页面，最新消息覆盖旧代次。
final Expando<int> _topMessageRevision = Expando<int>();

/// 替换当前 messenger 的所有旧 banner；仅当前消息可关闭或执行动作，非正 duration 常驻。
/// context：查找当前 ScaffoldMessenger 的已挂载上下文；无 messenger 时静默返回。
/// message：顶部提示正文，长内容限制高度并可内部滚动。
/// actionLabel：可选操作文案，缺省为“知道了”。
/// onAction：当前消息的按钮回调，先关闭消息再执行；旧消息按钮不触发它。
/// duration：可见后的定时关闭间隔，默认 4 秒，小于等于零时不启动计时器。

void showTopMessage(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  if (!context.mounted) return;
  // messenger：就近的已存在消息宿主，没有宿主时不展示提示。
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  // revision：当前 messenger 的新消息代次，后续新消息会让本次闭包失效。
  final revision = (_topMessageRevision[messenger] ?? 0) + 1;
  _topMessageRevision[messenger] = revision;

  // closed：本消息是否已经关闭，阻止重复关闭和重复执行动作。
  var closed = false;

  /// 同时验证消息未关闭、宿主仍挂载、代次仍为最新。
  bool ownsMessage() =>
      !closed &&
      messenger.mounted &&
      _topMessageRevision[messenger] == revision;

  /// 只关闭仍属于当前代次的消息，旧计时器不得隐藏新 banner。
  void close() {
    if (!ownsMessage()) return;
    closed = true;
    messenger.hideCurrentMaterialBanner();
  }

  messenger
    ..clearMaterialBanners()
    ..removeCurrentMaterialBanner();
  // controller：此消息的 MaterialBanner 控制器，用 closed Future 标记生命周期结束。
  final controller = messenger.showMaterialBanner(
    MaterialBanner(
      elevation: 4,
      backgroundColor: const Color(0xFF24272B),
      leading: const Icon(
        Icons.info_outline_rounded,
        color: Colors.white,
        size: 22,
      ),
      content: _TopMessageContent(
        message: message,
        duration: duration,
        onDismiss: close,
      ),
      actions: [
        TextButton(
          onPressed: /* 只处理当前消息按钮，先关闭再调用用户动作，避免重复进入。 */ () {
            if (!ownsMessage()) return;
            close();
            onAction?.call();
          },
          child: Text(
            actionLabel ?? '知道了',
            style: const TextStyle(color: Color(0xFFFFB15B)),
          ),
        ),
      ],
    ),
  );
  unawaited(
    controller.closed.then<void>(
      /* banner 真正结束后标记本消息关闭，使所有残留回调失效。
     * 忽略的 MaterialBannerClosedReason；任一关闭原因都结束本消息。 */
      (_) {
        closed = true;
      },
    ),
  );
}

/// 消息正文及可见期计时器的宿主，随 banner 内容插入和销毁管理定时资源。
class _TopMessageContent extends StatefulWidget {
  /// 保存正文、可见时长及带代次检查的关闭回调。
  /// message：当前 banner 的正文文本。
  /// duration：正数才启动关闭计时器。
  /// onDismiss：父函数创建的安全关闭入口，内部复验消息所有权。
  const _TopMessageContent({
    required this.message,
    required this.duration,
    required this.onDismiss,
  });

  /// 当前 banner 正文，不包含操作按钮文案。
  final String message;

  /// 正文挂载后开始计算的展示时长；非正值常驻。
  final Duration duration;

  /// 定时器到期使用的关闭回调，不能直接关闭其他代次消息。
  final VoidCallback onDismiss;

  /// 创建随正文可见期管理的计时器状态。
  @override
  State<_TopMessageContent> createState() => _TopMessageContentState();
}

/// 只持有当前正文的关闭计时器，退出树时取消以免产生无效回调。
class _TopMessageContentState extends State<_TopMessageContent> {
  /// 可选定时关闭计时器；常驻消息保持 null。
  Timer? _timer;

  /// 正文挂载且 duration 为正时启动一次计时关闭。
  @override
  void initState() {
    super.initState();
    if (widget.duration > Duration.zero) {
      _timer = Timer(widget.duration, widget.onDismiss);
    }
  }

  /// 取消定时器，消息移除后不再主动触发关闭。
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 限制正文最多占视口四分之一且夹取到 48 至 180 像素，长文本在内部滚动。
  /// context：读取消息宿主视口高度，计算正文滚动区域上限。
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    // 长提示不能挤走整个页面，正文在自身区域内滚动，操作按钮仍由 MaterialBanner 保留。
    constraints: BoxConstraints(
      maxHeight: (MediaQuery.sizeOf(context).height * .25)
          .clamp(48.0, 180.0)
          .toDouble(),
    ),
    child: SingleChildScrollView(
      child: Text(
        widget.message,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    ),
  );
}
