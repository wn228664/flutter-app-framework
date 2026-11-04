// 应用根组件：集中组装本地化、主题和路由；依赖 Riverpod 容器，底层偏好须由启动入口或测试覆盖。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/state/theme_controller.dart';
import '../shared/theme/app_theme.dart';
import 'router.dart';

/// 订阅主题与路由的应用根；不保存业务会话，也不假定已经配置后端。
class FrameworkApp extends ConsumerWidget {
  /// 创建根组件；运行依赖从外层 ProviderScope 取得。
  /// key：根组件的元素身份，供父级重建时判断复用。
  const FrameworkApp({super.key});

  /// 按当前 ThemeMode 和 GoRouter 配置构建 Material 应用，启用中文及英文组件文案。
  /// context：根组件构建上下文，应用级主题和路由从下方 MaterialApp 提供。
  /// ref：订阅主题和路由 provider；状态变化触发应用配置重建。
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: AppConfig.title,
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ref.watch(themeModeProvider),
    routerConfig: ref.watch(routerProvider),
  );
}
