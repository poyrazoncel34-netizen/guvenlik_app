import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/screens/legal/unified_consent_screen.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:guvenlik_app/widgets/consent_checkbox_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

const _tos = 'Kullanım sözleşmesini okudum, anladım ve kabul ediyorum.';
const _kvkk =
    'KVKK aydınlatma metnini okudum ve kişisel verilerimin yukarıda açıklanan kapsamda işleneceğini anladım.';
const _location =
    'Konum verilerimin acil durum ve konum oturumlarında işlenmesine rıza veriyorum';
const _contacts =
    'Acil durum kişilerime ait bilgilerin saklanmasına ve acil durumda kullanılmasına rıza veriyorum';
const _profile =
    'Profil bilgilerimin (ad, e-posta) cihazımda saklanmasına rıza veriyorum';
const _fakeCall =
    'Sahte çağrı özelliğinin yalnızca kişisel güvenlik amaçlı kullanımına onay veriyorum';

Future<void> _pumpConsent(
  WidgetTester tester, {
  VoidCallback? onAccepted,
  Size? viewport,
  double textScale = 1.0,
}) async {
  if (viewport != null) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = viewport;
    addTearDown(tester.view.reset);
  }
  await pumpLocalized(
    tester,
    MediaQuery(
      data: MediaQueryData(
        size: viewport ?? const Size(800, 600),
        textScaler: TextScaler.linear(textScale),
      ),
      child: UnifiedConsentScreen(onAccepted: onAccepted),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

Future<void> _tapVisibleText(WidgetTester tester, String text) =>
    _tapVisible(tester, find.text(text));

bool _consentValue(WidgetTester tester, String label) {
  final widget = find.ancestor(
    of: find.text(label),
    matching: find.byType(ConsentCheckboxWidget),
  );
  return tester.widget<ConsentCheckboxWidget>(widget).value;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    final manager = ConsentManager();
    await manager.initialize();
    serviceLocator.registerSingleton<ConsentManager>(manager);
  });

  tearDown(() => serviceLocator.reset());

  for (final viewport in <String, Size>{
    'small-320x568': const Size(320, 568),
    'normal-411x914': const Size(411, 914),
  }.entries) {
    testWidgets(
      'real consent remains usable at ${viewport.key} and 200% text',
      (tester) async {
        await _pumpConsent(tester, viewport: viewport.value, textScale: 2.0);

        expect(
          tester.takeException(),
          isNull,
          reason:
              'The production consent screen must not emit RenderFlex or '
              'clipping errors at the supported text-scale ceiling.',
        );

        final continueLabel = find.text('Devam Et ve Kurulumu Tamamla');
        expect(continueLabel, findsOneWidget);
        final continueRect = tester.getRect(continueLabel);
        expect(continueRect.top, greaterThanOrEqualTo(0));
        expect(
          continueRect.bottom,
          lessThanOrEqualTo(viewport.value.height),
          reason: 'The safety-critical completion action left the viewport.',
        );

        final termsHeading = find.text('Kullanım Sözleşmesi');
        await tester.ensureVisible(termsHeading);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final headingRect = tester.getRect(termsHeading);
        final requiredBadges = find.text('Zorunlu');
        final termsBadgeRect = tester.getRect(requiredBadges.at(1));
        expect(
          headingRect.right,
          lessThanOrEqualTo(termsBadgeRect.left),
          reason: 'The legal heading overlaps the required-state badge.',
        );

        final requiredConsent = find.text(_tos);
        await tester.ensureVisible(requiredConsent);
        await tester.pumpAndSettle();
        expect(requiredConsent, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('age option exposes its selected state to accessibility', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpConsent(tester);

    final ageOption = find.text('18 yaşından büyüğüm');
    await _tapVisible(tester, ageOption);

    expect(
      tester.getSemantics(ageOption).flagsCollection.isSelected,
      Tristate.isTrue,
      reason:
          'The radio-like age control changed visually and enabled the CTA, '
          'but assistive technology was not told that it is selected.',
    );
    semantics.dispose();
  });

  testWidgets(
    'RIZA-02/RIZA-04: real expand controls reveal and hide legal text',
    (tester) async {
      await _pumpConsent(tester);
      expect(find.byType(SelectableText), findsNothing);
      expect(find.textContaining('4.0.0'), findsOneWidget);
      expect(find.textContaining('3.4.0'), findsOneWidget);

      await _tapVisible(tester, find.text('Detayı Gör').first);
      expect(find.byType(SelectableText), findsOneWidget);
      await _tapVisibleText(tester, 'Gizle');
      expect(find.byType(SelectableText), findsNothing);

      await _tapVisible(tester, find.text('Detayı Gör').last);
      expect(find.byType(SelectableText), findsOneWidget);
      await _tapVisibleText(tester, 'Gizle');
      expect(find.byType(SelectableText), findsNothing);
    },
  );

  testWidgets(
    'RIZA-03/RIZA-05/RIZA-06/RIZA-07/RIZA-08/RIZA-09: taps change real controls and persist choices',
    (tester) async {
      var accepted = 0;
      await _pumpConsent(tester, onAccepted: () => accepted++);

      await _tapVisibleText(tester, '18 yaşından büyüğüm');
      for (final label in <String>[
        _tos,
        _kvkk,
        _location,
        _contacts,
        _profile,
        _fakeCall,
      ]) {
        expect(_consentValue(tester, label), isFalse);
        await _tapVisibleText(tester, label);
        expect(_consentValue(tester, label), isTrue);
      }

      final cta = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(cta.onPressed, isNotNull);
      final continueButton = find.text('Devam Et ve Kurulumu Tamamla');
      await tester.ensureVisible(continueButton);
      await tester.runAsync(() async {
        await tester.tap(continueButton);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      // The save is several async writes. A fixed 100 ms was enough on an idle
      // machine and failed under a parallel test load (2 of 18 runs); poll,
      // bounded, instead of guessing.
      for (var round = 0; round < 50 && accepted == 0; round++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }

      expect(accepted, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConstants.prefConsentLocation), isTrue);
      expect(prefs.getBool(AppConstants.prefConsentEmergencyContacts), isTrue);
      expect(prefs.getBool(AppConstants.prefConsentProfile), isTrue);
      expect(serviceLocator<ConsentManager>().isGranted('fake_call'), isTrue);
    },
  );
}
