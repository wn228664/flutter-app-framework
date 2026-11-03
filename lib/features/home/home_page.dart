import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../shared/widgets/top_message.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
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
                onPressed: () => showTopMessage(context, '提示组件正常'),
                child: const Text('显示提示'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/settings'),
                child: const Text('外观设置'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
