// 通用头像：支持严格 PNG/JPEG data URL 和 HTTP(S) 远程地址；解码、加载或图片渲染失败统一显示默认头像。

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 固定圆形头像，远程图片通过缓存组件加载；无有效图片时使用主题化默认图标。
class UserAvatar extends StatelessWidget {
  /// 接收图片来源和逻辑直径；默认读屏名称为“用户头像”。
  /// avatarUrl：远程 HTTP(S) 地址或 PNG/JPEG base64 data URL，使用前去掉首尾空白。
  /// size：头像逻辑像素直径，由调用方提供有效布局尺寸。
  /// semanticLabel：有效图片的读屏说明，默认“用户头像”。
  /// key：头像组件的元素身份。
  const UserAvatar({
    required this.avatarUrl,
    required this.size,
    this.semanticLabel = '用户头像',
    super.key,
  });

  /// 待解析图片来源，非法或空来源直接回退默认头像。
  final String avatarUrl;

  /// 圆形头像逻辑直径，宽高一致。
  final double size;

  /// 有效图片的语义标签；默认头像另使用“默认头像”。
  final String semanticLabel;

  /// 按内嵌图片、远程图片、默认头像的优先级构建圆形内容，并处理真实图片解码失败。
  /// context：头像主题来源，失败占位使用同一继承主题。
  @override
  Widget build(BuildContext context) {
    // data：严格 data URL 解码后的字节，非支持格式或 base64 非法时为 null。
    final data = _decodeDataUrl(avatarUrl.trim());
    // remoteUrl：通过 HTTP(S) 与 host 检查的远程地址，非法时为 null。
    final remoteUrl = _remoteAvatarUrl(avatarUrl.trim());
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: data != null
            ? Image.memory(
                data,
                fit: BoxFit.cover,
                semanticLabel: semanticLabel,
                errorBuilder: /* 内嵌字节无法渲染成图片时展示默认头像。
                 * 忽略的图片构建上下文；回退沿用外层头像 context。
                 * 忽略的内嵌图片解码错误，不向界面展示异常原文。
                 * 忽略的图片解码堆栈，回退不依赖其内容。 */ (_, _, _) =>
                    _fallback(context),
              )
            : remoteUrl != null
            ? _remoteImage(remoteUrl, context)
            : _fallback(context),
      ),
    );
  }

  /// 加载带缓存的远程图片；等待中、下载失败或实际图片解码失败都回退默认头像。
  /// remoteUrl：已通过地址协议和 host 检查的图片来源。
  /// context：为远程图片失败或等待状态构建主题化占位。
  Widget _remoteImage(String remoteUrl, BuildContext context) {
    return CachedNetworkImage(
      imageUrl: remoteUrl,
      fit: BoxFit.cover,
      imageBuilder: /* 使用缓存得到的 ImageProvider 构建覆盖裁剪图片，并保留渲染失败兜底。
       * 忽略的缓存图片局部构建上下文；回退使用外层主题上下文。
       * provider：缓存组件提供的图片来源，交给 Image 渲染。 */ (_, provider) => Image(
        image: provider,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        semanticLabel: semanticLabel,
        errorBuilder: /* 缓存命中但字节渲染失败时回退默认头像。
         * 忽略的 Image 局部上下文，沿用外层头像 context。
         * 忽略的缓存图片解码错误，避免泄露内部细节。
         * 忽略的图片解码堆栈，默认头像无需诊断信息。 */ (_, _, _) =>
            _fallback(context),
      ),
      placeholder: /* 远程加载期间使用相同大小的默认头像占位。
       * 忽略的 placeholder 构建上下文，使用外层主题。
       * 忽略的加载中地址，避免把 URL 展示成界面文案。 */ (_, _) =>
          _fallback(context),
      errorWidget: /* 下载或缓存获取失败时统一回退默认头像。
       * 忽略的错误占位上下文，沿用外层头像 context。
       * 忽略的失败图片地址，不在界面暴露来源。
       * 忽略的远程图片错误对象，默认头像不依赖异常类型。 */ (_, _, _) =>
          _fallback(context),
    );
  }

  /// 用当前主题的容器底色和人物图标创建安全默认头像。
  /// context：获取默认头像前景和背景语义色。
  Widget _fallback(BuildContext context) {
    // colors：当前亮暗主题色，保证占位在两种外观下可辨识。
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Icon(
        Icons.person_outline,
        color: colors.onSurfaceVariant,
        semanticLabel: '默认头像',
      ),
    );
  }
}

/// 仅接受具有 host 的 HTTP(S) 地址，合法时保留原字符串，否则返回 null。
/// value：已经由调用方去掉首尾空白的候选远程地址。
String? _remoteAvatarUrl(String value) {
  // uri：候选地址解析结果，用于验证 host 与协议。
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return null;
  if (!const {'http', 'https'}.contains(uri.scheme.toLowerCase())) return null;
  return value;
}

/// 仅解码完整匹配的 PNG/JPEG base64 data URL；编码错误返回 null，真实图像格式错误交给 Image 兜底。
/// value：已经去掉首尾空白的候选内嵌图片文本。
Uint8List? _decodeDataUrl(String value) {
  // match：严格 data URL 正则结果，第一组包含待 base64 解码的载荷。
  final match = RegExp(
    r'^data:image\/(?:jpeg|png);base64,([A-Za-z0-9+/=]+)$',
  ).firstMatch(value);
  if (match == null) return null;
  try {
    return base64Decode(match.group(1)!);
  } on FormatException {
    return null;
  }
}
