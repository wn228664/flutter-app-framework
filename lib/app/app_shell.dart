// 导航外壳：承载 GoRouter 的分支状态和底部入口；分支切换交给路由器，页面不另建导航栈。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 保留各分支页面状态的双入口外壳；重复选择当前入口时回到该分支初始位置。
class AppShell extends StatelessWidget {
  /// 将路由器创建的分支 shell 接入底部导航；本组件不拥有 shell 的销毁职责。
  /// shell：GoRouter 提供的有状态分支容器，负责当前索引与分支导航。
  /// key：外壳在父级组件树中的身份，用于 Flutter 元素复用。
  const AppShell({required this.shell, super.key});

  /// 当前路由分支容器；索引和页面状态均从此对象读取，不在外壳重复存储。
  final StatefulNavigationShell shell;

  /// 构建分支正文与底部导航，通过 shell.currentIndex 保持选中态和路由一致。
  /// context：导航外壳的构建上下文，供 Scaffold 和 NavigationBar 继承主题。
  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: /* 切换目标分支；再次点击当前分支时恢复该分支的初始路由。
       * index：底部入口的零基索引，直接传给 GoRouter 分支导航。 */ (index) =>
          shell.goBranch(index, initialLocation: index == shell.currentIndex),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
      ],
    ),
  );
}
