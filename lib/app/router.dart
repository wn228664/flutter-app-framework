// 路由定义：首页和设置使用保留状态的分支；未知地址提供返回首页操作，路由器随容器销毁。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_page.dart';
import '../features/settings/settings_page.dart';
import 'app_shell.dart';

/// 容器内唯一 GoRouter 实例，统一维护分支导航并释放监听资源。
final routerProvider = Provider<GoRouter>(
  /* 创建首页、设置及未知路由的路由表，并将 dispose 绑定到 provider。
 * ref：注册 GoRouter 的销毁回调，不在页面中重复创建路由器。 */
  (ref) {
    // router：此容器持有的路由实例，路由错误由 errorBuilder 呈现。
    final router = GoRouter(
      routes: [
        StatefulShellRoute.indexedStack(
          builder: /* 把有状态分支容器交给应用外壳，不复制分支状态。
         * context：ShellRoute 构建上下文，此处不直接读取。
         * state：当前 shell 路由匹配信息，此外壳不消费路径参数。
         * shell：GoRouter 创建的分支容器，由 AppShell 承载。 */ (context, state, shell) =>
              AppShell(shell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: /* 为根路径创建中性首页，不需要路由参数。
             * 忽略的路由 BuildContext；首页自行取得构建上下文。
             * 忽略的 GoRouterState；根页面无路径或查询参数。 */ (_, _) =>
                      const HomePage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: /* 为 /settings 创建本地外观设置页。
                 * 忽略的路由 BuildContext；设置页自行读取主题。
                 * 忽略的 GoRouterState；此页面不消费路径参数。 */ (_, _) =>
                      const SettingsPage(),
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: /* 将未知路由转换成可返回首页的错误页面，不直接暴露路由异常。
     * context：错误页面所处的路由上下文，返回按钮通过它访问 GoRouter。
     * state：失败的路由匹配结果，此页只展示固定提示。 */ (context, state) => Scaffold(
        appBar: AppBar(title: const Text('页面不存在')),
        body: Center(
          child: FilledButton(
            onPressed: /* 从未知地址跳转到已注册的根路径。 */ () => context.go('/'),
            child: const Text('返回首页'),
          ),
        ),
      ),
    );
    ref.onDispose(router.dispose);
    return router;
  },
);
