import 'package:flutter/material.dart';
import 'package:flutter_app_framework/app/framework_app.dart';
import 'package:flutter_app_framework/app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app starts without a backend and persists appearance changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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
  });

  testWidgets('narrow app layout remains usable with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
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
  });
}
