// 统一加载指示器：固定三点动画外框，紧凑模式适配分页；对读屏提供单一加载提示，避免重复播报子图形。

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// 共享加载动画，提供常规及紧凑尺寸和可访问的状态文案。
class AppLoadingIndicator extends StatelessWidget {
  /// 创建三点加载指示器；默认常规尺寸、蓝色和“正在加载”语义。
  /// key：加载组件在父布局中的元素身份。
  /// compact：true 使用紧凑外框和较小动画，默认 false。
  /// color：三点动画颜色，默认 #1677FF。
  /// semanticLabel：读屏播报的加载文案，默认“正在加载”。
  const AppLoadingIndicator({
    super.key,
    this.compact = false,
    this.color = const Color(0xFF1677FF),
    this.semanticLabel = '正在加载',
  });

  /// 尺寸模式；仅控制外框及动画大小，不控制加载状态本身。
  final bool compact;

  /// 三点动画前景色，由调用方按主题提供。
  final Color color;

  /// 唯一可访问状态提示，动画子树不重复暴露语义。
  final String semanticLabel;

  /// 按尺寸模式构建三点动画，用 liveRegion 播报加载状态。
  /// context：此加载组件的构建上下文，布局不依赖页面业务状态。
  @override
  Widget build(BuildContext context) {
    // indicatorSize：紧凑模式为 15、常规模式为 22 的动画逻辑尺寸。
    final indicatorSize = compact ? 15.0 : 22.0;
    // frameSize：分别为 38×22 或 54×32 的稳定外框，减少加载时布局跳动。
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
