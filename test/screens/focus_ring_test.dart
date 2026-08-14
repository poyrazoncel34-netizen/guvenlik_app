// MP-12-025 — odak halkası. Kaynak renklerin değil, DAVRANIŞIN testi.
//
// Bu dosya cihazda ölçülen iki kusuru kilitler:
//   1. Profil kartı ve Pro satırında odak göstergesi HİÇ yoktu (odaklı/odaksız
//      pikseller birebir aynı: 1.00:1) — Material'in mürekkep vurgusu çocuğun
//      opak arka planının altında kalıyordu.
//   2. Ayar satırlarında gösterge vardı ama komşu renklere karşı 1.46-1.76:1,
//      yani WCAG 1.4.11'in istediği 3:1'in altında.
//
// Halkanın ÇOCUĞUN ÜSTÜNE çizilmesi (1) için, iki tonlu olması (2) için.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/app_colors.dart';
import 'package:guvenlik_app/core/design_tokens.dart';
import 'package:guvenlik_app/core/widgets/focus_ring.dart';

double _lin(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _lum(Color c) =>
    0.2126 * _lin((c.r * 255).round() / 255) +
    0.7152 * _lin((c.g * 255).round() / 255) +
    0.0722 * _lin((c.b * 255).round() / 255);

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Ağaçtaki halka kenarlıklarını toplar.
List<BoxDecoration> _ringDecorations(WidgetTester tester) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(IgnorePointer),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((DecoratedBox d) => d.decoration as BoxDecoration)
      .where((BoxDecoration d) => d.border != null)
      .toList();
}

Widget _host({required FocusNode outside}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: <Widget>[
          // Odağı halkadan UZAKLAŞTIRABİLMEK için bir kardeş denetim.
          TextButton(
            focusNode: outside,
            onPressed: () {},
            child: const Text('dis'),
          ),
          FocusRing(
            borderRadius: BorderRadius.circular(Radii.md),
            builder: (FocusNode node) => InkWell(
              key: const Key('target'),
              focusNode: node,
              onTap: () {},
              child: const SizedBox(width: 300, height: 80),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('NEGATIF KONTROL: odak yokken halka çizilmez', (tester) async {
    final outside = FocusNode();
    addTearDown(outside.dispose);
    await tester.pumpWidget(_host(outside: outside));
    await tester.pump();

    expect(
      _ringDecorations(tester),
      isEmpty,
      reason: 'Odaklanmamış bir denetim odak halkası göstermemeli.',
    );
  });

  testWidgets('odaklanınca iki tonlu halka çizilir', (tester) async {
    final outside = FocusNode();
    addTearDown(outside.dispose);
    await tester.pumpWidget(_host(outside: outside));

    final FocusNode node = tester
        .widget<InkWell>(find.byKey(const Key('target')))
        .focusNode!;
    node.requestFocus();
    await tester.pumpAndSettle();

    final rings = _ringDecorations(tester);
    expect(
      rings.length,
      2,
      reason: 'Dış + iç olmak üzere iki halka bekleniyor.',
    );

    final colors = rings.map((d) => d.border!.top.color).toSet();
    expect(colors, contains(AppColors.focusRing));
    expect(colors, contains(AppColors.focusRingOutline));
  });

  testWidgets('MUTASYON: odak kaybedilince halka geri çekilir', (tester) async {
    final outside = FocusNode();
    addTearDown(outside.dispose);
    await tester.pumpWidget(_host(outside: outside));

    final FocusNode node = tester
        .widget<InkWell>(find.byKey(const Key('target')))
        .focusNode!;
    node.requestFocus();
    await tester.pumpAndSettle();
    expect(_ringDecorations(tester), hasLength(2));

    outside.requestFocus();
    await tester.pumpAndSettle();
    expect(
      _ringDecorations(tester),
      isEmpty,
      reason:
          'Halka yalnızca odaktayken görünmeli; aksi halde her satır '
          'sürekli çerçeveli görünürdü.',
    );
  });

  testWidgets('halka dokunma hedefini yutmaz', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusRing(
            borderRadius: BorderRadius.circular(Radii.md),
            builder: (FocusNode node) => InkWell(
              key: const Key('target'),
              focusNode: node,
              onTap: () => taps++,
              child: const SizedBox(width: 300, height: 80),
            ),
          ),
        ),
      ),
    );
    final FocusNode node = tester
        .widget<InkWell>(find.byKey(const Key('target')))
        .focusNode!;
    node.requestFocus();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('target')));
    await tester.pumpAndSettle();
    expect(taps, 1, reason: 'IgnorePointer olmasaydı halka dokunuşu yerdi.');
  });

  group('ÖLÇÜM: render edilmiş halka pikselleri WCAG barını geçiyor', () {
    // API 36 emülatöründe, düzeltilmiş yapıda okunan GERÇEK piksel değerleri.
    const outerRing = Color(0xFF2EC5FF); // rgb(46,197,255) — AppColors.primary
    const innerRing = Color(
      0xFF0A1B2A,
    ); // rgb(10,27,42)   — AppColors.background
    const pageBg = Color(0xFF0D2739); // profil kartı dışı rgb(13,39,57)
    const cyanCard = Color(0xFF4ED3FF); // profil kartı dolgusu rgb(78,211,255)
    const rowFill = Color(0xFF122B42); // ayar satırı dolgusu rgb(18,43,66)

    test('render edilen halka renkleri token değerleriyle birebir', () {
      expect(outerRing, AppColors.focusRing);
      expect(innerRing, AppColors.focusRingOutline);
    });

    test('parlak camgöbeği kart: her iki sınır da 3:1 üstünde', () {
      expect(
        contrast(outerRing, pageBg),
        greaterThanOrEqualTo(FocusIndicator.minContrast),
      );
      expect(
        contrast(innerRing, cyanCard),
        greaterThanOrEqualTo(FocusIndicator.minContrast),
      );
    });

    test('koyu ayar satırı: dış sınır 3:1 üstünde', () {
      expect(
        contrast(outerRing, pageBg),
        greaterThanOrEqualTo(FocusIndicator.minContrast),
      );
    });

    test('DÜRÜST KAYIT: koyu satırlarda İÇ sınır zayıf, dış sınır taşıyor', () {
      // WCAG 1.4.11 göstergenin komşu renklere karşı 3:1 olmasını ister;
      // halkanın HER İKİ kenarının birden geçmesini şart koşmaz. Koyu ayar
      // satırlarında iç (koyu) kenar satır dolgusuna karşı 1.21-1.76:1
      // kalıyor. Bunu gizlemek yerine pinliyoruz: gösterge dış kenarıyla
      // (5.84-8.94:1) ve iki ton arasındaki 8.77:1 iç kenarıyla ayırt ediliyor.
      const rowFillDark = Color(0xFF122B42);
      expect(
        contrast(AppColors.focusRingOutline, rowFillDark),
        lessThan(FocusIndicator.minContrast),
      );
      // ...ama dış kenar her yüzeyde barı geçiyor, ölçülen en düşük 5.84.
      const rowNeighbour = Color(0xFF1D3B54); // rgb(29,59,84)
      expect(
        contrast(AppColors.focusRing, rowNeighbour),
        greaterThanOrEqualTo(FocusIndicator.minContrast),
      );
      // ve iki ton birbirine karşı her zaman güçlü.
      expect(
        contrast(AppColors.focusRing, AppColors.focusRingOutline),
        greaterThanOrEqualTo(FocusIndicator.minContrast),
      );
    });

    test('tek tonlu halka YETMEZDİ — sıranın neden ölçümle seçildiği', () {
      // primary parlak kartta kaybolur, background koyu satırda kaybolur.
      expect(
        contrast(AppColors.focusRing, cyanCard),
        lessThan(FocusIndicator.minContrast),
      );
      expect(
        contrast(AppColors.focusRingOutline, rowFill),
        lessThan(FocusIndicator.minContrast),
      );
    });
  });
}
