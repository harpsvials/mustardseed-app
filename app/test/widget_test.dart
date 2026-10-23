import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mustardseed_app/main.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MustardSeedApp());
    // 让内置数据异步加载完成
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
