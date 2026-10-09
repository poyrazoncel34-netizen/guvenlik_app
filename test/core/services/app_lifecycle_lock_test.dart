// Arka plandan donuste yeniden kimlik dogrulama kilidi.
//
// CIHAZDA OLCULEN KUSUR: uygulama 141 saniye arka planda kaldi ve donuste kilit
// ekrani HIC GELMEDI -- esik 120 saniye olmasina ragmen.
//
// Sebep: `AppLifecycleState.inactive` yalnizca disari cikarken degil, GERI
// GIRERKEN de -- `resumed`'dan hemen once -- tetikleniyor. `onPaused()` bu duruma
// da bagli oldugu icin, donus gecisi duraklama zaman damgasini o anki zamanla
// EZIYOR, gecen sure ~0 hesaplaniyor ve kilit HICBIR surede acilmiyor.
//
// Zorlama modeli yalnizca yerel PIN'e dayandigi icin (CLAUDE.md kural 2), hic
// tetiklenmeyen bir otomatik kilit gercek bir guvenlik bulgusudur.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/navigation/app_navigator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/app_lifecycle_handler.dart';
import 'package:guvenlik_app/screens/app_unlock_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnreadableSecureStorage extends SecureStorage {
  @override
  Future<String?> read({required String key}) =>
      Future<String?>.error(StateError('injected unreadable keystore'));

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<void> deleteAll() async {}
}

class _PinPresentStorage extends SecureStorage {
  @override
  Future<String?> read({required String key}) async => 'pbkdf2\$1000\$abc\$def';

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<void> deleteAll() async {}
}

void main() {
  group('lifecycleStartsBackgroundClock', () {
    test('gercek arka plan durumlari saati BASLATIR', () {
      expect(lifecycleStartsBackgroundClock(AppLifecycleState.paused), isTrue);
      expect(lifecycleStartsBackgroundClock(AppLifecycleState.hidden), isTrue);
      expect(
        lifecycleStartsBackgroundClock(AppLifecycleState.detached),
        isTrue,
      );
    });

    test('KUSURUN KENDISI: inactive saati BASLATMAZ', () {
      // Bu satir kirmiziya donerse kilit yeniden sessizce devre disi kalir:
      // inactive donuste de tetiklendigi icin saat resume aninda sifirlanir.
      expect(
        lifecycleStartsBackgroundClock(AppLifecycleState.inactive),
        isFalse,
        reason:
            'inactive gorunur haldeyken ve DONUSTE de tetiklenir; '
            'arka plan saatini baslatmamali.',
      );
    });

    test('resumed elbette saati baslatmaz', () {
      expect(
        lifecycleStartsBackgroundClock(AppLifecycleState.resumed),
        isFalse,
      );
    });
  });

  group('onPaused zaman damgasi', () {
    setUp(AppLifecycleHandler.instance.resetForTest);
    tearDown(AppLifecycleHandler.instance.resetForTest);

    test('ilk arka plan anini kaydeder', () {
      expect(AppLifecycleHandler.instance.pausedAt, isNull);
      AppLifecycleHandler.instance.onPaused();
      expect(AppLifecycleHandler.instance.pausedAt, isNotNull);
    });

    test('EN ERKEN an kazanir -- tekrarli cagri saati ILERLETMEZ', () async {
      AppLifecycleHandler.instance.onPaused();
      final first = AppLifecycleHandler.instance.pausedAt;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      // Android arka arkaya birkac arka plan durumu yollar (hidden, sonra
      // paused). Her birinde ezmek olculen sureyi kisaltirdi.
      AppLifecycleHandler.instance.onPaused();
      expect(
        AppLifecycleHandler.instance.pausedAt,
        first,
        reason: 'Ikinci cagri saati ileri almamali.',
      );
    });

    test(
      'MUTASYON: eski davranis (her cagride ez) bu testi dusururdu',
      () async {
        AppLifecycleHandler.instance.onPaused();
        final first = AppLifecycleHandler.instance.pausedAt!;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        AppLifecycleHandler.instance.onPaused();
        final second = AppLifecycleHandler.instance.pausedAt!;
        expect(second.isAfter(first), isFalse);
      },
    );
  });

  test('esik degeri 2 dakika olarak sabit', () {
    expect(AppLifecycleHandler.lockAfterSeconds, 120);
  });

  testWidgets(
    'secure storage read failure on resume fails closed without trapping loading UI',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await serviceLocator.reset();
      final storage = _UnreadableSecureStorage();
      serviceLocator.registerSingleton<SecureStorage>(storage);
      var now = DateTime.utc(2026, 9, 23, 12);
      final handler = AppLifecycleHandler.forTesting(
        now: () => now,
        secureStorage: storage,
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const Scaffold(body: Text('protected content')),
        ),
      );
      handler.onPaused();
      now = now.add(const Duration(seconds: 121));

      Object? resumeError;
      unawaited(
        handler.onResumed().catchError((Object error) {
          resumeError = error;
        }),
      );
      await tester.pumpAndSettle();

      expect(resumeError, isNull);
      expect(find.byType(AppUnlockScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('protected content'), findsNothing);

      await serviceLocator.reset();
    },
  );

  // Y-10 (chaos audit 2026-10-08): background time was measured on the WALL
  // clock alone. Whoever holds the unlocked phone could leave KoruBeni in the
  // background for any length of time, set the clock back, and reopen it with
  // no PIN: elapsed came out negative. elapsedRealtime cannot be set; a lock
  // is now owed when EITHER clock says the threshold passed.
  group('Y-10: a clock set back cannot skip the re-auth lock', () {
    Future<void> resumeAfter(
      WidgetTester tester, {
      required Duration wallJump,
      required Duration realElapsed,
      required bool monotonicAvailable,
      bool monotonicRequired = false,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await serviceLocator.reset();
      final storage = _PinPresentStorage();
      serviceLocator.registerSingleton<SecureStorage>(storage);
      var now = DateTime.utc(2026, 10, 8, 18, 10);
      var elapsedMs = 5000000;
      final handler = AppLifecycleHandler.forTesting(
        now: () => now,
        secureStorage: storage,
        monotonic: () async => monotonicAvailable
            ? (elapsedMs: elapsedMs, bootCount: 17, bootId: null)
            : null,
        monotonicRequired: monotonicRequired,
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const Scaffold(body: Text('protected content')),
        ),
      );
      handler.onPaused();
      await tester.pump();
      now = now.add(realElapsed).add(wallJump);
      elapsedMs += realElapsed.inMilliseconds;
      unawaited(handler.onResumed());
      await tester.pumpAndSettle();
    }

    testWidgets('long background, clock set back an hour: locked', (
      tester,
    ) async {
      await resumeAfter(
        tester,
        wallJump: const Duration(hours: -1),
        realElapsed: const Duration(seconds: 130),
        monotonicAvailable: true,
      );
      expect(find.byType(AppUnlockScreen), findsOneWidget);
      await serviceLocator.reset();
    });

    testWidgets('short background, no clock change: not locked', (
      tester,
    ) async {
      await resumeAfter(
        tester,
        wallJump: Duration.zero,
        realElapsed: const Duration(seconds: 10),
        monotonicAvailable: true,
      );
      expect(find.byType(AppUnlockScreen), findsNothing);
      expect(find.text('protected content'), findsOneWidget);
      await serviceLocator.reset();
    });

    testWidgets('short background, clock moved forward: locked (fail closed)', (
      tester,
    ) async {
      await resumeAfter(
        tester,
        wallJump: const Duration(hours: 1),
        realElapsed: const Duration(seconds: 10),
        monotonicAvailable: true,
      );
      expect(find.byType(AppUnlockScreen), findsOneWidget);
      await serviceLocator.reset();
    });

    // Review of Y-10: a reading that failed (a 500 ms timeout under load as
    // another app launches) silently fell back to the wall clock, and with it
    // the clock-set-back bypass. Where the native clock exists, an unanswered
    // read now locks.
    testWidgets('a native clock that does not answer still locks a clock set '
        'back', (tester) async {
      await resumeAfter(
        tester,
        wallJump: const Duration(hours: -1),
        realElapsed: const Duration(seconds: 10),
        monotonicAvailable: false,
        monotonicRequired: true,
      );
      expect(find.byType(AppUnlockScreen), findsOneWidget);
      await serviceLocator.reset();
    });

    testWidgets('where there is no native clock a short background is not '
        'locked', (tester) async {
      await resumeAfter(
        tester,
        wallJump: Duration.zero,
        realElapsed: const Duration(seconds: 10),
        monotonicAvailable: false,
      );
      expect(find.byType(AppUnlockScreen), findsNothing);
      await serviceLocator.reset();
    });

    testWidgets('without a monotonic reading the wall clock still decides', (
      tester,
    ) async {
      await resumeAfter(
        tester,
        wallJump: Duration.zero,
        realElapsed: const Duration(seconds: 130),
        monotonicAvailable: false,
      );
      expect(find.byType(AppUnlockScreen), findsOneWidget);
      await serviceLocator.reset();
    });
  });
}
