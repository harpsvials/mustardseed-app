import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mustardseed_app/widgets/shared.dart';

void main() {
  double bodyScale(WidgetTester tester, Key key) {
    final context = tester.element(find.byKey(key));
    return MediaQuery.textScalerOf(context).scale(10) / 10;
  }

  testWidgets('ReaderTextSize 共享设置并限制在 85%-140%', (tester) async {
    SharedPreferences.setMockInitialValues({});

    Widget page(String label, Key key) {
      return MaterialApp(
        home: Scaffold(
          body: ReaderTextSize(child: Text(label, key: key)),
        ),
      );
    }

    const first = Key('reader-body');
    const second = Key('reader-body-second');
    await tester.pumpWidget(page('正文', first));
    await tester.pumpAndSettle();

    expect(find.text('100%'), findsOneWidget);
    expect(bodyScale(tester, first), closeTo(1.0, 0.001));

    await tester.tap(find.text('加大'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加大'));
    await tester.pumpAndSettle();
    expect(find.text('120%'), findsOneWidget);
    expect(bodyScale(tester, first), closeTo(1.2, 0.001));

    // 同一会话内新页面应沿用刚设置的 120%，而不是回到 100%。
    await tester.pumpWidget(page('第二页', second));
    await tester.pumpAndSettle();
    expect(find.text('120%'), findsOneWidget);
    expect(bodyScale(tester, second), closeTo(1.2, 0.001));

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('减小'));
      await tester.pumpAndSettle();
    }
    expect(find.text('85%'), findsOneWidget);
    expect(bodyScale(tester, second), closeTo(0.85, 0.001));
    expect(
      tester
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.text('减小'),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('加大'));
      await tester.pumpAndSettle();
    }
    expect(find.text('140%'), findsOneWidget);
    expect(bodyScale(tester, second), closeTo(1.4, 0.001));
  });
}
