import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all static GoRouter navigation targets are registered', () {
    final routerSource = File(
      'lib/core/router/app_router.dart',
    ).readAsStringSync();
    final registeredRoutes = RegExp(
      r"path:\s*'([^']+)'",
    ).allMatches(routerSource).map((match) => match.group(1)!).toSet();

    final undefinedTargets = <String>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      final matches = RegExp(
        r"context\.(?:go|push|replace)\(\s*'([^']+)'",
        multiLine: true,
      ).allMatches(source);

      for (final match in matches) {
        final target = match.group(1)!;
        if (target.contains(r'$')) continue;
        final targetPath = Uri.parse(target).path;
        if (!registeredRoutes.contains(targetPath)) {
          undefinedTargets.add(target);
        }
      }
    }

    expect(
      undefinedTargets,
      isEmpty,
      reason: 'Navigation targets must have matching GoRoute declarations.',
    );
  });
}
