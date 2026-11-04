// 启动入口：先校验公开构建配置并取得偏好存储，再注入根容器；启动失败向调用栈抛出，不带未初始化依赖进入页面。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/framework_app.dart';
import 'app/providers.dart';
import 'core/config/app_config.dart';

/// 初始化 Flutter 绑定和非敏感偏好，覆盖 preferencesProvider 后挂载应用；不在启动时发送业务请求。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  // preferences：启动时取得的非敏感偏好实例，供主题控制器持久化外观选择。
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [preferencesProvider.overrideWithValue(preferences)],
      child: const FrameworkApp(),
    ),
  );
}
