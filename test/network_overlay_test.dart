// 网络覆盖层回归：通过可控流和初检 Future 验证事件顺序、正文保留、恢复刷新和手动防重；不使用真实网络状态。

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_framework/shared/widgets/network_status_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

/// 带本地计数状态的正文 fixture，用于证明离线遮罩没有销毁 child。
class Counter extends StatefulWidget {
  /// 创建计数正文 fixture，不注入额外连接状态。
  /// key：测试正文的元素身份，维持同一计数状态。
  const Counter({super.key});

  /// 创建此 fixture 独有的计数状态。
  @override
  State<Counter> createState() => _CounterState();
}

/// 保存一次点击后的正文状态，恢复联网后应仍为 1。
class _CounterState extends State<Counter> {
  /// 正文点击次数，遮罩前后必须保持。
  int count = 0;

  /// 提供可点击计数文本，便于断言正文状态保留。
  /// context：计数 fixture 的构建上下文。
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: /* 点击正文按钮时通过 setState 请求更新计数。 */ () =>
        setState(/* 将正文点击次数加一，离线覆盖期间不重置它。 */ () => count++),
    child: Text('计数 $count'),
  );
}

/// 注册连接事件顺序、自动恢复和手动刷新防重回归。
void main() {
  testWidgets(
    'network recovery preserves child state and ignores stale initial checks',
    /* 验证较新 wifi 事件不会被迟到初检覆盖，断网后恢复保留正文并只刷新一次。
     * tester：驱动组件树和连接流异步更新，收集布局异常。 */
    (tester) async {
      // stream：测试可控连接事件流，结束时关闭。
      final stream = StreamController<List<ConnectivityResult>>();
      addTearDown(stream.close);
      // initial：故意迟到的首次连接检查结果。
      final initial = Completer<List<ConnectivityResult>>();
      // refreshes：恢复连接触发的数据刷新次数。
      var refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkStatusOverlay(
              connectivityStream: stream.stream,
              checkConnectivity: /* 返回受控初检 Future，让流事件先于初检到达。 */ () =>
                  initial.future,
              onRefresh: /* 记录一次恢复连接后的刷新调用。 */ () => refreshes++,
              child: const Counter(),
            ),
          ),
        ),
      );
      stream.add([ConnectivityResult.wifi]);
      await tester.pump();
      initial.complete([ConnectivityResult.none]);
      await tester.pump();
      expect(find.text('手动刷新'), findsNothing);
      await tester.tap(find.text('计数 0'));
      await tester.pump();
      stream.add([ConnectivityResult.none]);
      await tester.pump();
      expect(find.text('手动刷新'), findsOneWidget);
      expect(tester.takeException(), isNull);
      stream.add([ConnectivityResult.wifi]);
      await tester.pump();
      await tester.pump();
      expect(find.text('计数 1'), findsOneWidget);
      expect(refreshes, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'manual refresh rejects duplicates, shows failure and releases retry',
    /* 验证连续点击仅启动一次刷新，失败显示文案并允许下一次重试。
     * tester：点击遮罩按钮并推进刷新成功或失败后的组件更新。 */
    (tester) async {
      // stream：手动刷新用例的隔离连接流。
      final stream = StreamController<List<ConnectivityResult>>();
      addTearDown(stream.close);
      // calls：实际刷新工厂进入次数，用于验证 pending 防重。
      var calls = 0;
      // pending：当前刷新完成器，失败后替换以测试恢复。
      var pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkStatusOverlay(
              connectivityStream: stream.stream,
              checkConnectivity: /* 将初始连接固定为离线，使手动刷新入口可用。 */ () async => [
                ConnectivityResult.none,
              ],
              onRefresh: /* 记录刷新进入次数并等待测试控制成功或失败。 */ () {
                calls++;
                return pending.future;
              },
              child: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('手动刷新'));
      await tester.tap(find.text('手动刷新'));
      await tester.pump();
      expect(calls, 1);
      pending.completeError(StateError('offline'));
      await tester.pump();
      await tester.pump();
      expect(find.text('刷新失败，请重试'), findsOneWidget);
      pending = Completer<void>();
      await tester.tap(find.text('手动刷新'));
      await tester.pump();
      expect(calls, 2);
      pending.complete();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
