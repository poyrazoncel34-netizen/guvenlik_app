// Source contract for the home-screen widget and the Quick Settings tile.
//
// The load-bearing guarantee: neither surface is a second dispatch path. They
// record an intent-only request and launch MainActivity, which replays it into
// the one existing arm path. Behaviour is covered by Robolectric tests in
// android/app/src/test/kotlin/com/poyrazoncel/korubeni/quickaccess/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String manifest;
  late String tile;
  late String widget;
  late String launch;
  late String store;
  late String host;
  late String proguard;
  late String audit;

  String kotlin(String name) => File(
    'android/app/src/main/kotlin/com/poyrazoncel/korubeni/quickaccess/$name',
  ).readAsStringSync();

  /// Drops comment lines. These files explain at length what they deliberately
  /// do NOT do, so a naive substring search finds the forbidden name inside the
  /// comment that forbids it.
  String codeOnly(String source) => source
      .split('\n')
      .where((line) {
        final t = line.trimLeft();
        return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
      })
      .join('\n');

  setUpAll(() {
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    tile = kotlin('PanicTileService.kt');
    widget = kotlin('PanicWidgetProvider.kt');
    launch = kotlin('PanicLaunch.kt');
    store = kotlin('PanicRequestStore.kt');
    host = File(
      'lib/core/widgets/emergency_trigger_host.dart',
    ).readAsStringSync();
    proguard = File('android/app/proguard-rules.pro').readAsStringSync();
    audit = File('scripts/audit_android_release_surface.py').readAsStringSync();
  });

  group('no second dispatch path', () {
    test('neither surface dials, arms, or resolves a contact', () {
      for (final raw in <String>[tile, widget, launch, store]) {
        final source = codeOnly(raw);
        expect(source.contains('ACTION_CALL'), isFalse);
        expect(source.contains('ACTION_DIAL'), isFalse);
        expect(source.contains('armEmergencySession'), isFalse);
        expect(source.contains('EmergencySessionCoordinator'), isFalse);
        expect(source.contains('AlarmManager'), isFalse);
        expect(source.contains('ContactService'), isFalse);
      }
    });

    test('the request is replayed into the existing countdown entry', () {
      expect(host, contains('QuickPanicRequestService.consume()'));
      expect(
        host,
        contains('await _openCountdown()'),
        reason:
            '_openCountdown already resolves entitlement via SubscriptionGate; '
            'a parallel entry would duplicate the arm boundary.',
      );
    });

    test('the hand-off keeps its own key, away from the native trigger', () {
      expect(
        codeOnly(store).contains('KEY_PENDING_TRIGGER'),
        isFalse,
        reason:
            'Sharing that single-payload key would let a widget tap overwrite '
            'a pending checkInExpired, which means native already dispatched.',
      );
      expect(store, contains('quick_panic_pending_source'));
    });

    test('the pending request is read-and-clear', () {
      expect(store, contains('edit().remove('));
      expect(
        store,
        contains('.commit()'),
        reason: 'A process death before an async write lands drops the press.',
      );
    });
  });

  group('manifest surface', () {
    test('the widget provider is not exported', () {
      final start = manifest.indexOf('.quickaccess.PanicWidgetProvider');
      expect(start, isNot(-1));
      final block = manifest.substring(start, start + 700);
      expect(block, contains('android:exported="false"'));
      expect(block, contains('android.appwidget.action.APPWIDGET_UPDATE'));
      expect(block, contains('@xml/panic_widget_info'));
    });

    test('the tile service is exported but system-permission guarded', () {
      final start = manifest.indexOf('.quickaccess.PanicTileService');
      expect(start, isNot(-1));
      final block = manifest.substring(start, start + 600);
      expect(block, contains('android:exported="true"'));
      expect(
        block,
        contains('android:permission="android.permission.BIND_QUICK_SETTINGS_TILE"'),
        reason:
            'A QS tile must be exported for SystemUI to bind it; the '
            'signature-level permission is what keeps the binder to the system.',
      );
      expect(block, contains('android.service.quicksettings.action.QS_TILE'));
    });

    test('no new uses-permission was introduced', () {
      final permissions = RegExp(r'<uses-permission[^>]*android:name="([^"]+)"')
          .allMatches(manifest)
          .map((m) => m.group(1))
          .toSet();

      expect(permissions, hasLength(13));
      expect(
        permissions.any((p) => p!.contains('QUICK_SETTINGS')),
        isFalse,
        reason: 'BIND_QUICK_SETTINGS_TILE is a component guard, not a request.',
      );
    });
  });

  group('release gate', () {
    test('R8 keeps the OS-instantiated class names', () {
      expect(
        proguard,
        contains('com.poyrazoncel.korubeni.quickaccess.PanicWidgetProvider'),
      );
      expect(
        proguard,
        contains('com.poyrazoncel.korubeni.quickaccess.PanicTileService'),
      );
    });

    test('the exported allowlist admits the tile narrowly', () {
      expect(audit, contains('QS_TILE_SERVICE'));
      expect(audit, contains('BIND_QUICK_SETTINGS_TILE'));
      expect(audit, contains('qs_tile_filter_present(component)'));
      expect(
        audit,
        contains('and not qs_tile_ok'),
        reason: 'The allowance must be an added branch, not a relaxed rule.',
      );
      expect(
        audit.contains('unexpected exported component'),
        isTrue,
        reason: 'The exported-component check itself must stay in place.',
      );
    });

    test('the widget never wakes the device to refresh', () {
      final info = File(
        'android/app/src/main/res/xml/panic_widget_info.xml',
      ).readAsStringSync();
      expect(
        info,
        contains('android:updatePeriodMillis="0"'),
        reason: 'The widget shows no live data; polling would cost battery.',
      );
    });
  });

  group('tile behaviour across API levels', () {
    test('API 34+ uses the PendingIntent overload', () {
      expect(tile, contains('UPSIDE_DOWN_CAKE'));
      expect(tile, contains('startActivityAndCollapse('));
      expect(tile, contains('PendingIntent.getActivity('));
    });

    test('PendingIntents are immutable', () {
      expect(tile, contains('FLAG_IMMUTABLE'));
      expect(widget, contains('FLAG_IMMUTABLE'));
    });
  });
}
