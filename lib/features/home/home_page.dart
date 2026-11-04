// 中性首页：展示框架启动状态与通用提示入口；不调用业务 API，内容在安全区内滚动适配窄屏。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../shared/widgets/top_message.dart';

/// 无业务依赖的起始页，演示顶部提示及外观设置导航。
class HomePage extends StatelessWidget {
  /// 创建首页，页面内容由公开应用标题和中性说明组成。
  /// key：首页在路由分支中的元素身份。
  const HomePage({super.key});

  /// 构建可滚动首页；操作复用统一消息组件和 GoRouter。
  /// context：首页主题、ScaffoldMessenger 及 GoRouter 的查找起点。
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('首页')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            AppConfig.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text('应用已就绪。可以从路由、状态管理和通用组件开始开发。'),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: /* 通过当前页 messenger 展示演示消息，沿用统一替换和关闭时序。 */ () =>
                    showTopMessage(context, '提示组件正常'),
                child: const Text('显示提示'),
              ),
              OutlinedButton(
                onPressed: /* 跳转到已注册的外观设置路径。 */ () => context.go('/settings'),
                child: const Text('外观设置'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
