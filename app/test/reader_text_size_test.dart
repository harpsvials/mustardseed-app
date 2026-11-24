import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mustardseed_app/widgets/shared.dart';

void main() {
  testWidgets('ReaderTextSize remembers 85%-140% scale', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderTextSize(
            child: Text('正文', key: Key('reader-body')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double bodyScale() {
      final context = tester.element(find.byKey(const Key('reader-body')));
      return MediaQuery.textScalerOf(context).scale(10) / 10;
    }

    expect(find.text('100%'), findsOneWidget);
    expect(bodyScale(), closeTo(1.0, 0.001));

    await tester.tap(find.text('加大'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加大'));
    await tester.pumpAndSettle();
    expect(find.text('120%'), findsOneWidget);
    expect(bodyScale(), closeTo(1.2, 0.001));

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('减小'));
      await tester.pumpAndSettle();
    }
    expect(find.text('85%'), findsOneWidget);
    expect(bodyScale(), closeTo(0.85, 0.001));
    expect(
      tester.widget<OutlinedButton>(find.ancestor(
        of: find.text('减小'),
        matching: find.byType(OutlinedButton),
      )).onPressed,
      isNull,
    );
  });
}
