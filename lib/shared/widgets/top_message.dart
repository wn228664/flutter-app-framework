import 'dart:async';

import 'package:flutter/material.dart';

final Expando<int> _topMessageRevision = Expando<int>();

/// 同一 messenger 只保留最新消息；duration<=0 常驻，旧计时器不会关闭新消息。
void showTopMessage(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final revision = (_topMessageRevision[messenger] ?? 0) + 1;
  _topMessageRevision[messenger] = revision;

  var closed = false;
  bool ownsMessage() =>
      !closed &&
      messenger.mounted &&
      _topMessageRevision[messenger] == revision;
  void close() {
    if (!ownsMessage()) return;
    closed = true;
    messenger.hideCurrentMaterialBanner();
  }

  messenger
    ..clearMaterialBanners()
    ..removeCurrentMaterialBanner();
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
          onPressed: () {
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
    controller.closed.then<void>((_) {
      closed = true;
    }),
  );
}

class _TopMessageContent extends StatefulWidget {
  const _TopMessageContent({
    required this.message,
    required this.duration,
    required this.onDismiss,
  });
  final String message;
  final Duration duration;
  final VoidCallback onDismiss;
  @override
  State<_TopMessageContent> createState() => _TopMessageContentState();
}

class _TopMessageContentState extends State<_TopMessageContent> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    if (widget.duration > Duration.zero) {
      _timer = Timer(widget.duration, widget.onDismiss);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
