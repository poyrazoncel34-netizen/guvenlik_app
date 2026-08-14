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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/app_lifecycle_handler.dart';

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
}
