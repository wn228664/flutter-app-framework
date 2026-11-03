import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_framework/core/models/json_readers.dart';
import 'package:flutter_app_framework/core/models/page_data.dart';
import 'package:flutter_app_framework/core/network/api_exception.dart';
import 'package:flutter_app_framework/shared/widgets/async_value_view.dart';
import 'package:flutter_app_framework/shared/widgets/network_status_overlay.dart';
import 'package:flutter_app_framework/shared/widgets/pagination_footer.dart';
import 'package:flutter_app_framework/shared/widgets/top_message.dart';
import 'package:flutter_app_framework/shared/widgets/user_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'JSON integers reject fractional/non-finite input and maps reject non-string keys',
    () {
      expect(readInt({'value': 2.0}, 'value'), 2);
      expect(
        () => PageData.fromJson({'list': [], 'pageSize': 0}, (value) => value),
        throwsFormatException,
      );
      for (final value in [2.5, double.nan, double.infinity]) {
        expect(() => readInt({'value': value}, 'value'), throwsFormatException);
      }
      expect(
        () => readMap({
          'value': {1: 'invalid'},
        }, 'value'),
        throwsFormatException,
      );
      expect(
        () => readMapList({
          'value': [
            {1: 'invalid'},
          ],
        }, 'value'),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'pagination loading hides stale errors and avoids duplicate retry entry',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginationFooter(
              hasMore: true,
              isLoading: true,
              error: StateError('old failure'),
              onRetry: () => fail('retry while loading'),
            ),
          ),
        ),
      );
      expect(find.text('加载失败，点击重试'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    },
  );
  testWidgets('invalid avatar sources fall back without business assets', (
    tester,
  ) async {
    for (final url in ['javascript:alert(1)', 'data:image/png;base64,?']) {
      await tester.pumpWidget(
        MaterialApp(home: UserAvatar(avatarUrl: url, size: 48)),
      );
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('an older top message timer cannot close a newer message', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    showTopMessage(context, '旧提示', duration: const Duration(seconds: 1));
    await tester.pumpAndSettle();
    showTopMessage(context, '新提示', duration: const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('新提示'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.text('新提示'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'shared states stay usable on narrow and landscape screens with large text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      for (final size in [const Size(320, 600), const Size(844, 390)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorState(
                error: const ApiException(message: '网络错误，请重试'),
                onRetry: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.ensureVisible(find.text('重新加载'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NetworkStatusOverlay(
                checkConnectivity: () async => [ConnectivityResult.none],
                connectivityStream: const Stream.empty(),
                onRefresh: () {},
                child: const SizedBox(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.ensureVisible(find.text('手动刷新'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: PaginationFooter(
                  hasMore: false,
                  isLoading: false,
                  error: null,
                  onRetry: () {},
                  endLabel: '较长的分页结束提示，用于验证窄屏和大字体的布局边界',
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'pagination coalesces frame notifications and ignores work after disposal',
    (tester) async {
      late BuildContext origin;
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PaginationScrollListener(
            canLoadMore: true,
            isLoading: false,
            onLoadMore: () => calls++,
            child: Builder(
              builder: (context) {
                origin = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 100,
        pixels: 95,
        viewportDimension: 200,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );
      for (var i = 0; i < 10; i++) {
        ScrollUpdateNotification(
          metrics: metrics,
          context: origin,
          scrollDelta: 1,
        ).dispatch(origin);
      }
      await tester.pump();
      expect(calls, 1);
      ScrollUpdateNotification(
        metrics: metrics,
        context: origin,
        scrollDelta: 1,
      ).dispatch(origin);
      await tester.pumpWidget(const SizedBox());
      expect(calls, 1);
    },
  );
  testWidgets('a fading old retry button cannot be clicked during loading', (
    tester,
  ) async {
    var loading = false;
    var calls = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return PaginationFooter(
                hasMore: true,
                isLoading: loading,
                error: StateError('old'),
                onRetry: () => calls++,
              );
            },
          ),
        ),
      ),
    );
    update(() => loading = true);
    await tester.pump();
    await tester.tap(find.text('加载失败，点击重试'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 250));
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'shared error and avatar fallbacks inherit dark theme contrast colors',
    (tester) async {
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ErrorState(error: StateError('failed'), onRetry: () {}),
          ),
        ),
      );
      final Text title = tester.widget(find.text('内容加载失败'));
      expect(title.style!.color, theme.colorScheme.onSurface);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: UserAvatar(avatarUrl: '', size: 40)),
        ),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.person_outline)).color,
        theme.colorScheme.onSurfaceVariant,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
