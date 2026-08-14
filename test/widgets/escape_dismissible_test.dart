// MP-12-007 — Escape, KAPANABİLİR modallarda çalışır; kilitli olanlarda çalışmaz.
//
// Bu ayrım testin bütün noktası. Escape'i her modala bağlamak kolay olurdu ve
// geri sayım iptali / acil arama uyarısı / siren gibi bilerek kilitlenmiş
// modalları da açardı. Aşağıdaki negatif kontrol tam olarak bunu yakalar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/widgets/escape_dismissible.dart';

Future<void> _openDialog(
  WidgetTester tester, {
  required bool wrap,
  bool locked = false,
  bool autofocus = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) {
                const Widget body = AlertDialog(content: Text('icerik'));
                Widget dialog = locked
                    ? const PopScope(canPop: false, child: body)
                    : body;
                if (wrap) {
                  dialog = EscapeDismissible(
                    autofocus: autofocus,
                    child: dialog,
                  );
                }
                return dialog;
              },
            ),
            child: const Text('ac'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ac'));
  await tester.pumpAndSettle();
  expect(
    find.text('icerik'),
    findsOneWidget,
    reason: 'ÖNKOŞUL: modal açılmalı',
  );
}

Future<void> _pressEscape(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('NEGATIF KONTROL: sarmalayıcı YOKKEN Escape hiçbir şey yapmaz '
      '(cihazda ölçülen kusurun ta kendisi)', (tester) async {
    await _openDialog(tester, wrap: false);
    await _pressEscape(tester);
    expect(
      find.text('icerik'),
      findsOneWidget,
      reason:
          'barrierDismissible:false, Flutter\'ın DismissAction\'ını devre '
          'dışı bırakır. Bu satır yeşil kaldıkça kusur gerçektir.',
    );
  });

  testWidgets('sarmalayıcı ile Escape kapanabilir modalı kapatır', (
    tester,
  ) async {
    await _openDialog(tester, wrap: true);
    await _pressEscape(tester);
    expect(find.text('icerik'), findsNothing);
  });

  testWidgets(
    'NEGATIF KONTROL: PopScope(canPop:false) modalı Escape ile AÇILMAZ',
    (tester) async {
      await _openDialog(tester, wrap: true, locked: true);
      await _pressEscape(tester);
      expect(
        find.text('icerik'),
        findsOneWidget,
        reason:
            'Kasıtlı kilit korunmalı: maybePop PopScope\'a saygı duyar. '
            'Bu kırmızıya dönerse geri sayım iptali Escape ile kapanır hale '
            'gelmiş demektir.',
      );
    },
  );

  testWidgets('sarmalayıcı başlangıç odağını modalın İÇİNE koyar', (
    tester,
  ) async {
    await _openDialog(tester, wrap: true);
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    expect(primary, isNotNull, reason: 'Odak BOŞ olmamalı.');
    expect(
      primary!.context?.findAncestorWidgetOfExactType<EscapeDismissible>(),
      isNotNull,
      reason:
          'Cihazda modal açıkken odaklanan TEK düğüm kök FlutterView idi; '
          'modalın içinde hiçbir şey odakta değildi. Odak modalın alt '
          'ağacında başlamalı, yoksa Escape eylemi de bulunamaz.',
    );
  });

  testWidgets('autofocus:false verilince odak metin alanında kalır', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => EscapeDismissible(
                  autofocus: false,
                  child: AlertDialog(
                    content: TextField(autofocus: true, controller: controller),
                  ),
                ),
              ),
              child: const Text('ac'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isTrue);
    expect(
      FocusManager.instance.primaryFocus?.context?.widget.runtimeType
          .toString(),
      isNot('EscapeDismissible'),
      reason: 'PIN alanından odağı çalmak gerçek bir gerileme olurdu.',
    );
  });

  // showModalBottomSheet, `isDismissible` varsayilani true olmasina RAGMEN Escape'e
  // yanit vermiyordu. Cihazda iki kez ureildi: sayfa acikken odaklanan HICBIR dugum
  // yoktu (uiautomator bos liste dondu), Escape ekranda 0.0000 degistirdi, BACK ise
  // kapatti. Bu, diyaloglardan AYRI bir modal sinifi ve ilk gecis onu atlamisti.
  testWidgets('modal bottom sheet: sarmalayici ile Escape kapatir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => const EscapeDismissible(
                  child: SizedBox(height: 200, child: Text('sayfa')),
                ),
              ),
              child: const Text('ac'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();
    expect(
      find.text('sayfa'),
      findsOneWidget,
      reason: 'ÖNKOŞUL: sayfa açılmalı',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('sayfa'), findsNothing);
  });

  testWidgets(
    'NEGATIF KONTROL: ONCEDEN ODAK YOKKEN sarmalayicisiz sayfa Escape ile kapanmaz',
    (tester) async {
      // CIHAZDA OLCULEN KOSUL, BIREBIR: dokunmatik kullanici hicbir seye odak
      // vermeden bir modal acinca `ModalRoute.didPush` yalnizca `setFirstFocus`
      // cagirir; cevreleyen kapsamda odak yoksa odak modalin ICINE TASINMAZ.
      // O zaman `Actions.maybeFind` aramasi modalin kapsamindan baslamaz ve
      // barrierDismissible true OLSA BILE Escape cozulmez.
      //
      // Bu yuzden cihazda diyalog (klavyeyle acilmisti) Escape'e yanit verdi ama
      // sayfa (dokunarak acilmisti) vermedi. Fark barrierDismissible degil, odakti.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) =>
                      const SizedBox(height: 200, child: Text('sayfa')),
                ),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();
      expect(find.text('sayfa'), findsOneWidget);

      // Dokunmatik kullanicinin gercek durumu: hicbir yerde odak yok.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.text('sayfa'),
        findsOneWidget,
        reason:
            'Odak modalin disindayken Escape cozulmuyor -- cihazda iki kez '
            'uretilen kusur. Sarmalayici autofocus ile tam olarak bunu kapatiyor.',
      );
    },
  );

  testWidgets(
    'KRITIK: ONCEDEN HIC ODAK YOKKEN de sarmalayici Escape\'i calistirir',
    (tester) async {
      // BU TEST ILK DUZELTMEYI YAKALARDI. Ilk surum `Focus(autofocus: true)`
      // kullaniyordu; `autofocus` yalnizca cevreleyen kapsam odak kazanirsa
      // uygulanan bir NIYET kaydi oldugu icin, dokunmatik kullanicinin
      // "hicbir seyin odagi yok" durumunda hic uygulanmiyordu. Widget testi
      // gecerken cihazda sayfa acildiginda Escape olu kaliyordu.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const EscapeDismissible(
                    child: SizedBox(height: 200, child: Text('sayfa')),
                  ),
                ),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
      );
      // ONKOSUL: uygulamada hicbir odak yok (dokunmatik kullanicinin durumu).
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();
      expect(find.text('sayfa'), findsOneWidget);

      // Odak gercekten sayfanin icinde olmali -- niyet degil, olgu.
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EscapeDismissible>(),
        isNotNull,
        reason:
            'requestFocus kosulsuzdur; autofocus bu kosulda uygulanmiyordu.',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('sayfa'), findsNothing);
    },
  );
}
