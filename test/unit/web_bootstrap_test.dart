import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web bootstrap removes splash only after Flutter app starts', () {
    final source = File('web/index.html').readAsStringSync();
    final runApp = source.indexOf('await appRunner.runApp();');
    final removeSplash = source.indexOf('removeSplashFromWeb();', runApp);

    expect(runApp, greaterThan(0));
    expect(removeSplash, greaterThan(runApp));
  });
}
