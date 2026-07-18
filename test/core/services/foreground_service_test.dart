import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/core/services/foreground_service.dart',
  ).readAsStringSync();

  test('active-session status is owner-scoped and persistent', () {
    expect(source, contains('ForegroundServiceOwnership'));
    expect(source, contains('required String owner'));
    expect(source, contains('ongoing: true'));
    expect(source, contains('visibility: NotificationVisibility.private'));
  });

  test('notification failures degrade without breaking native alarms', () {
    final refresh = source.substring(
      source.indexOf('static Future<void> _refreshNotification'),
    );
    expect(refresh, contains('try {'));
    expect(refresh, contains('catch (e)'));
  });

  test('notification denied copy warns about reduced reliability', () {
    final en = File('assets/translations/en-US.json').readAsStringSync();
    final tr = File('assets/translations/tr-TR.json').readAsStringSync();

    expect(en, contains('timer reliability and visibility may be reduced'));
    expect(tr, contains('zamanlayıcı güvenilirliği ve görünürlüğü azalabilir'));
  });
}
