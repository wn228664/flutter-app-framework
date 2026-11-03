import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.avatarUrl,
    required this.size,
    this.semanticLabel = '用户头像',
    super.key,
  });
  final String avatarUrl;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final data = _decodeDataUrl(avatarUrl.trim());
    final remoteUrl = _remoteAvatarUrl(avatarUrl.trim());
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: data != null
            ? Image.memory(
                data,
                fit: BoxFit.cover,
                semanticLabel: semanticLabel,
                errorBuilder: (_, _, _) => _fallback(context),
              )
            : remoteUrl != null
            ? _remoteImage(remoteUrl, context)
            : _fallback(context),
      ),
    );
  }

  Widget _remoteImage(String remoteUrl, BuildContext context) {
    return CachedNetworkImage(
      imageUrl: remoteUrl,
      fit: BoxFit.cover,
      imageBuilder: (_, provider) => Image(
        image: provider,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        semanticLabel: semanticLabel,
        errorBuilder: (_, _, _) => _fallback(context),
      ),
      placeholder: (_, _) => _fallback(context),
      errorWidget: (_, _, _) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
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

String? _remoteAvatarUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return null;
  if (!const {'http', 'https'}.contains(uri.scheme.toLowerCase())) return null;
  return value;
}

Uint8List? _decodeDataUrl(String value) {
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
