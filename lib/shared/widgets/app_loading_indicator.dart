import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.compact = false,
    this.color = const Color(0xFF1677FF),
    this.semanticLabel = '正在加载',
  });
  final bool compact;
  final Color color;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final indicatorSize = compact ? 15.0 : 22.0;
    final frameSize = compact ? const Size(38, 22) : const Size(54, 32);
    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.fromSize(
          size: frameSize,
          child: Center(
            child: SpinKitThreeBounce(color: color, size: indicatorSize),
          ),
        ),
      ),
    );
  }
}
