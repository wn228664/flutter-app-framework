// 通用组件回归：覆盖 JSON 边界、头像兜底、消息代次、分页防重和大小字体布局；使用 Flutter 测试树，不代表真机验收。

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

/// 注册共享模型与组件的八项契约和布局回归。
void main() {
  test(
    'JSON integers reject fractional/non-finite input and maps reject non-string keys',
    /* 验证整数拒绝小数和非有限值，分页拒绝零容量，对象拒绝非 String 键。 */
    () {
      expect(readInt({'value': 2.0}, 'value'), 2);
      expect(
        /* 构造非法分页容量，预期 fromJson 直接抛格式错误。 */
        () => PageData.fromJson(
          {'list': [], 'pageSize': 0},
          /* 保持条目解码原样，当前场景不依赖业务模型。
         * value：单条 JSON 对象，当前空 list 场景不会实际调用。 */
          (value) => value,
        ),
        throwsFormatException,
      );
      for ( /* value：当前非法整数样例，小数、NaN 或无穷值。 */ final value in [
        2.5,
        double.nan,
        double.infinity,
      ]) {
        expect(
          /* 延迟执行非法整数读取，让 expect 捕获同步 FormatException。 */
          () => readInt({'value': value}, 'value'),
          throwsFormatException,
        );
      }
      expect(
        /* 尝试读取非 String 键对象，预期拒绝。 */
        () => readMap({
          'value': {1: 'invalid'},
        }, 'value'),
        throwsFormatException,
      );
      expect(
        /* 尝试读取含非 String 键元素的对象数组，预期拒绝。 */
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
    /* 验证加载态优先于旧错误，不暴露可重复进入的重试按钮。
     * tester：构建正在加载的分页页脚并查询可交互子树。 */
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginationFooter(
              hasMore: true,
              isLoading: true,
              error: StateError('old failure'),
              onRetry: /* 若加载中还能调用重试就直接使测试失败。 */ () =>
                  fail('retry while loading'),
            ),
          ),
        ),
      );
      expect(find.text('加载失败，点击重试'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    },
  );
  testWidgets(
    'invalid avatar sources fall back without business assets',
    /* 验证危险协议和非法 data URL 都回退中性默认头像。
   * tester：依次构建非法来源头像并检查渲染异常。 */
    (tester) async {
      for ( /* url：当前无效头像来源样例。 */ final url in [
        'javascript:alert(1)',
        'data:image/png;base64,?',
      ]) {
        await tester.pumpWidget(
          MaterialApp(home: UserAvatar(avatarUrl: url, size: 48)),
        );
        expect(find.byIcon(Icons.person_outline), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'an older top message timer cannot close a newer message',
    /* 验证旧消息计时器过期不会关闭新消息，且新消息可由按钮关闭。
   * tester：控制 banner 动画、虚拟时间和按钮点击。 */
    (tester) async {
      // context：从 Scaffold 内 Builder 取得的消息宿主上下文。
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: /* 捕获有效 Scaffold 上下文用于调用 showTopMessage。
             * value：Builder 提供的已挂载上下文。 */ (value) {
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
    },
  );
  testWidgets(
    'shared states stay usable on narrow and landscape screens with large text',
    /* 在窄屏、横屏和 1.6 倍文字下检查错误页、离线页及长终点文案可用。
     * tester：设置测试视口、放大文字并滚动至关键操作。 */
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      for ( /* size：本轮布局样例，分别为 320×600 和 844×390。 */ final size in [
        const Size(320, 600),
        const Size(844, 390),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorState(
                error: const ApiException(message: '网络错误，请重试'),
                onRetry: /* 布局用例的空重试动作，本组只验证按钮触达与溢出。 */ () {},
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
                checkConnectivity: /* 返回固定离线初检，保证覆盖层布局可观测。 */ () async => [
                  ConnectivityResult.none,
                ],
                connectivityStream: const Stream.empty(),
                onRefresh: /* 离线布局用例的空刷新动作，不引入真实请求。 */ () {},
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
                  onRetry: /* 终点页脚的空重试动作，当前终点态不会展示重试入口。 */ () {},
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
    /* 验证同帧十次滚动通知只触发一次，销毁后排队工作不能执行。
     * tester：派发滚动通知并控制帧后回调执行时机。 */
    (tester) async {
      // origin：监听器子树的通知发起上下文。
      late BuildContext origin;
      // calls：下一页回调实际触发次数。
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PaginationScrollListener(
            canLoadMore: true,
            isLoading: false,
            onLoadMore: /* 记录被分页监听器放行的加载次数。 */ () => calls++,
            child: Builder(
              builder: /* 保存通知发起点，确保 dispatch 能沿树到达真实监听器。
               * context：位于 PaginationScrollListener 下方的 Builder 上下文。 */
                  (context) {
                    origin = context;
                    return const SizedBox();
                  },
            ),
          ),
        ),
      );
      // metrics：距底部 5 像素的竖向固定滚动指标 fixture。
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 100,
        pixels: 95,
        viewportDimension: 200,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );
      for (
        var // i：同一帧派发滚动通知的计数，覆盖重复排队场景。
        i = 0;
        i < 10;
        i++
      ) {
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
  testWidgets(
    'a fading old retry button cannot be clicked during loading',
    /* 验证淡出的旧错误按钮在加载态期间也无法继续触发重试。
   * tester：保持退出动画进行中并尝试点击残留文字。 */
    (tester) async {
      // loading：StatefulBuilder 使用的分页加载标记。
      var loading = false;
      // calls：旧重试按钮回调次数，切入加载后应始终为零。
      var calls = 0;
      // update：由 StatefulBuilder 提供的状态更新入口。
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: /* 保存状态更新入口并构建受 loading 控制的页脚。
             * context：测试页脚的局部构建上下文，此处无须读取。
             * setState：测试用局部状态更新函数，赋给 update 后主动切换状态。 */ (context, setState) {
                update = setState;
                return PaginationFooter(
                  hasMore: true,
                  isLoading: loading,
                  error: StateError('old'),
                  onRetry: /* 记录实际重试回调，以捕获淡出旧按钮的错误响应。 */ () => calls++,
                );
              },
            ),
          ),
        ),
      );
      update(/* 将页脚从错误态切换到加载态。 */ () => loading = true);
      await tester.pump();
      await tester.tap(find.text('加载失败，点击重试'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 250));
      expect(calls, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'shared error and avatar fallbacks inherit dark theme contrast colors',
    /* 验证错误标题和默认头像沿用深色主题语义色，保持对比度。
     * tester：读取实际构建文字和图标颜色。 */
    (tester) async {
      // theme：测试显式生成的深色主题，作为颜色断言基准。
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
            body: ErrorState(
              error: StateError('failed'),
              onRetry: /* 颜色验证用空重试回调，不触发数据请求。 */ () {},
            ),
          ),
        ),
      );
      // title：真实错误标题 Text 组件，用于核对 onSurface 前景色。
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
