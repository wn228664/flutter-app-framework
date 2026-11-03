import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_framework/shared/widgets/network_status_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});
  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('计数 $count'),
  );
}

void main() {
  testWidgets(
    'network recovery preserves child state and ignores stale initial checks',
    (tester) async {
      final stream = StreamController<List<ConnectivityResult>>();
      addTearDown(stream.close);
      final initial = Completer<List<ConnectivityResult>>();
      var refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkStatusOverlay(
              connectivityStream: stream.stream,
              checkConnectivity: () => initial.future,
              onRefresh: () => refreshes++,
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
    (tester) async {
      final stream = StreamController<List<ConnectivityResult>>();
      addTearDown(stream.close);
      var calls = 0;
      var pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkStatusOverlay(
              connectivityStream: stream.stream,
              checkConnectivity: () async => [ConnectivityResult.none],
              onRefresh: () {
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
