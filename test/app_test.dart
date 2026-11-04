// 根应用组件测试：使用隔离偏好启动并操作外观，另在 320×640 与 1.6 倍文字下检查布局异常；不声称真机验收。

import 'package:flutter/material.dart';
import 'package:flutter_app_framework/app/framework_app.dart';
import 'package:flutter_app_framework/app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 注册应用启动、提示交互、主题持久化与窄屏大字体回归。
void main() {
  testWidgets(
    'app starts without a backend and persists appearance changes',
    /* 验证无后端可启动、顶部消息可关闭，并能保存深色外观。
   * tester：驱动当前隔离 Flutter 组件树、点击及动画推进。 */
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      // preferences：本用例清空后取得的 mock 偏好实例。
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [preferencesProvider.overrideWithValue(preferences)],
          child: const FrameworkApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('App Framework'), findsOneWidget);
      await tester.tap(find.text('显示提示'));
      await tester.pumpAndSettle();
      expect(find.text('提示组件正常'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('外观设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('深色'));
      await tester.pumpAndSettle();
      expect(preferences.getString('framework_theme'), 'dark');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow app layout remains usable with larger text',
    /* 在窄屏和大字体配置下启动应用，确认提示入口存在且无布局异常。
   * tester：设置测试视口、文字缩放并收集 Flutter 异常。 */
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({});
      // preferences：窄屏用例的隔离偏好，避免继承前次主题。
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [preferencesProvider.overrideWithValue(preferences)],
          child: const FrameworkApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('显示提示'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
