import 'package:flutter_test/flutter_test.dart';
import 'package:mustardseed_app/data/app_data.dart';

void main() {
  test('loadBuiltIn parses asset', () async {
    final d = await AppData.loadBuiltIn();
    // ignore: avoid_print
    print('OK sermons=${d.sermons.length} topics=${d.topics.length} '
        'about=${d.about.length} nav=${d.nav.length}');
  });
}
