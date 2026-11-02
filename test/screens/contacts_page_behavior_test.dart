import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/native_contact_picker_service.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:guvenlik_app/models/consent_record.dart';
import 'package:guvenlik_app/presentation/providers/contacts_provider.dart';
import 'package:guvenlik_app/presentation/providers/home_provider.dart';
import 'package:guvenlik_app/screens/contacts_page.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

class _MemoryContactsRepository implements ContactsRepository {
  _MemoryContactsRepository([List<EmergencyContact>? initial])
    : records = List<EmergencyContact>.from(initial ?? const []);

  final List<EmergencyContact> records;
  EmergencyContact? primary;
  int loadCount = 0;

  @override
  Future<void> clearPrimaryEmergencyContact() async => primary = null;

  @override
  Future<List<String>> getAllEmergencyNumbers() async =>
      records.map((contact) => contact.phone).toList();

  @override
  Future<List<EmergencyContact>> getContactRecords() async {
    loadCount++;
    return List<EmergencyContact>.from(records);
  }

  @override
  Future<List<String>> getContacts() async =>
      records.map((contact) => contact.phone).toList();

  @override
  Future<EmergencyContact?> getPrimaryEmergencyContact() async => primary;

  @override
  Future<void> saveContactRecords(List<EmergencyContact> contacts) async {
    records
      ..clear()
      ..addAll(contacts);
  }

  @override
  Future<void> saveContacts(List<String> numbers) async {
    records
      ..clear()
      ..addAll(
        numbers.map((phone) => EmergencyContact(name: '', phone: phone)),
      );
  }

  @override
  Future<void> saveEmergencyNumbers(List<String> numbers) =>
      saveContacts(numbers);

  @override
  Future<void> savePrimaryEmergencyContact({
    required String name,
    required String phone,
  }) async {
    primary = EmergencyContact(name: name, phone: phone);
  }
}

class _HomeSpy extends HomeProvider {
  int refreshCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refreshAfterContactsChanged() async {
    refreshCount++;
  }
}

Future<void> _settleIo(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpContacts(
  WidgetTester tester,
  ContactsProvider provider,
  HomeProvider home,
) async {
  await pumpLocalized(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ContactsProvider>.value(value: provider),
        ChangeNotifierProvider<HomeProvider>.value(value: home),
      ],
      child: const ContactsPage(),
    ),
  );
  await _settleIo(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryContactsRepository repository;
  late ContactsProvider provider;
  late _HomeSpy home;
  late ConsentManager consentManager;

  Future<void> configure([List<EmergencyContact>? contacts]) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    repository = _MemoryContactsRepository(contacts);
    serviceLocator.registerSingleton<ContactsRepository>(repository);
    consentManager = ConsentManager();
    await consentManager.initialize();
    serviceLocator.registerSingleton<ConsentManager>(consentManager);
    provider = ContactsProvider();
    home = _HomeSpy();
  }

  tearDown(() async {
    provider.dispose();
    home.dispose();
    await serviceLocator.reset();
  });

  testWidgets('KSI-01/KSI-16 real page initializes once and renders limit', (
    tester,
  ) async {
    await tester.runAsync(
      () => configure(
        List.generate(
          AppConstants.maxEmergencyContacts,
          (index) => EmergencyContact(
            name: 'Kişi $index',
            phone: '+9055500000${10 + index}',
          ),
        ),
      ),
    );

    await _pumpContacts(tester, provider, home);

    expect(find.byType(ContactsPage), findsOneWidget);
    expect(find.text('Kişi 0'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pump();
    expect(find.text('Maksimum kişi sayısına ulaştınız'), findsOneWidget);
    expect(repository.loadCount, 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.loadCount, 1);
  });

  testWidgets('top add-contact action has a Turkish accessible name and role', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.runAsync(configure);
    await _pumpContacts(tester, provider, home);

    final appBarAdd = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(IconButton),
    );
    expect(appBarAdd, findsOneWidget);
    final accessibleAdd = find.bySemanticsLabel('Kişi Ekle');
    expect(accessibleAdd, findsOneWidget);
    final node = tester.getSemantics(accessibleAdd);
    expect(node.label, 'Kişi Ekle');
    expect(node.flagsCollection.isButton, isTrue);
    semantics.dispose();
  });

  testWidgets('real contacts page does not overflow at 2x text scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 914);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(
      () => configure(const [
        EmergencyContact(name: 'Acil Kişi', phone: '5551234567'),
      ]),
    );

    await _pumpContacts(tester, provider, home);

    expect(tester.takeException(), isNull);
    expect(find.text('Güvenlik Ağım'), findsOneWidget);
    expect(find.text('Acil kişi seç'), findsOneWidget);
  });

  testWidgets('KSI-02/KSI-03/KSI-05/KSI-06 manual add validates and persists', (
    tester,
  ) async {
    await tester.runAsync(configure);
    await _pumpContacts(tester, provider, home);
    final appBarAdd = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(IconButton),
    );
    expect(appBarAdd, findsOneWidget);

    await tester.tap(appBarAdd);
    await tester.pumpAndSettle();
    expect(find.text('Yeni Kişi Ekle'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.runAsync(
      () => consentManager.grantConsent(ConsentRecord.typeEmergencyContacts),
    );
    expect(
      consentManager.isGranted(ConsentRecord.typeEmergencyContacts),
      isTrue,
    );
    await tester.tap(appBarAdd);
    await tester.pumpAndSettle();
    expect(find.text('KVKK Bilgilendirme'), findsOneWidget);
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni Kişi Ekle'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        AppConstants.prefContactConsentShown,
      ),
      isTrue,
    );

    final name = find.widgetWithText(TextField, 'Ad');
    final phone = find.widgetWithText(TextFormField, 'Telefon numarası');
    await tester.enterText(name, 'Ayşe');
    await tester.enterText(phone, '123');
    await tester.pump();
    expect(
      find.text('Geçerli bir telefon numarası veya resmi acil numara girin'),
      findsOneWidget,
    );
    await tester.enterText(phone, '+905551112233');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Kişi Ekleme Onayı'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Ekle'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.textContaining('Bu kişiyi uygulamaya'));
    await tester.pump();
    await tester.tap(find.text('Ekle'));
    await _settleIo(tester);

    expect(repository.records, hasLength(1));
    expect(repository.records.single.name, 'Ayşe');
    expect(repository.records.single.phone, '+905551112233');
    expect(home.refreshCount, 1);
    expect(find.text('Ayşe'), findsOneWidget);
  });

  testWidgets('KSI-09/KSI-10 picker selects and persists primary contact', (
    tester,
  ) async {
    await tester.runAsync(
      () => configure(const [
        EmergencyContact(name: 'Ayşe', phone: '+905551112233'),
        EmergencyContact(name: 'Bora', phone: '+905552223344'),
      ]),
    );
    await _pumpContacts(tester, provider, home);

    await tester.tap(find.text('Acil kişi seç'));
    await tester.pumpAndSettle();
    expect(find.text('Acil Kişi Seç'), findsOneWidget);
    await tester.tap(find.text('Bora').last);
    await _settleIo(tester);

    expect(repository.primary?.name, 'Bora');
    expect(repository.primary?.phone, '+905552223344');
    expect(home.refreshCount, 1);
    expect(find.text('Acil kişi seçildi: Bora'), findsOneWidget);
  });

  testWidgets('KSI-11/KSI-13/KSI-14 options select and remove cancel/confirm', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.runAsync(
      () => configure(const [
        EmergencyContact(name: 'Ayşe', phone: '+905551112233'),
      ]),
    );
    await _pumpContacts(tester, provider, home);

    Future<void> openOptions() async {
      await tester.tap(find.text('Ayşe'));
      await tester.pumpAndSettle();
      expect(find.text('Kişiyi Kaldır'), findsOneWidget);
    }

    await openOptions();
    await tester.tap(find.text('Acil Kişi Seç'));
    await _settleIo(tester);
    expect(repository.primary?.name, 'Ayşe');

    await openOptions();
    await tester.tap(find.text('Kişiyi Kaldır'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(repository.records, hasLength(1));

    await openOptions();
    await tester.tap(find.text('Kişiyi Kaldır'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await _settleIo(tester);
    expect(repository.records, isEmpty);
    expect(repository.primary, isNull);
    expect(find.text('Ayşe'), findsNothing);
  });

  testWidgets('KSI-15 reorder drag persists order without changing primary', (
    tester,
  ) async {
    await tester.runAsync(
      () => configure(const [
        EmergencyContact(name: 'Ayşe', phone: '+905551112233'),
        EmergencyContact(name: 'Bora', phone: '+905552223344'),
      ]),
    );
    repository.primary = repository.records.first;
    await _pumpContacts(tester, provider, home);

    final dragHandles = find.byType(ReorderableDelayedDragStartListener);
    expect(dragHandles, findsNWidgets(2));
    final gesture = await tester.startGesture(
      tester.getCenter(dragHandles.first),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 260));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await _settleIo(tester);

    expect(repository.records.map((contact) => contact.name), ['Bora', 'Ayşe']);
    expect(repository.primary?.name, 'Ayşe');
  });

  // Device pick and manual entry share the onboarding boundary: contact-book
  // noise is sanitized, a missing number and an uncallable number get two
  // different messages, and dial strings are refused instead of being folded
  // into the digits by an input filter.
  group('pick and manual entry boundary', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const invalidPhoneText =
        'Geçerli bir telefon numarası veya resmi acil numara girin';
    const noPhoneText = 'Seçilen kişide telefon numarası yok';

    tearDown(() {
      messenger.setMockMethodCallHandler(
        NativeContactPickerService.channel,
        null,
      );
    });

    Future<void> pickFromEmptyState(
      WidgetTester tester,
      Map<String, String> nativeReply,
    ) async {
      messenger.setMockMethodCallHandler(
        NativeContactPickerService.channel,
        (_) async => nativeReply,
      );
      await tester.runAsync(configure);
      await tester.runAsync(
        () => consentManager.grantConsent(ConsentRecord.typeEmergencyContacts),
      );
      await _pumpContacts(tester, provider, home);
      final addPerson = find.descendant(
        of: find.byWidgetPredicate((widget) => widget is ElevatedButton),
        matching: find.text('Kişi Ekle'),
      );
      expect(addPerson, findsOneWidget, reason: 'empty-state pick action');
      await tester.tap(addPerson);
      await tester.pumpAndSettle();
    }

    Future<Finder> openManualPhoneField(WidgetTester tester) async {
      await tester.runAsync(configure);
      await tester.runAsync(
        () => consentManager.grantConsent(ConsentRecord.typeEmergencyContacts),
      );
      await _pumpContacts(tester, provider, home);
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni Kişi Ekle'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Ad'), 'Anne');
      return find.widgetWithText(TextFormField, 'Telefon numarası');
    }

    Future<void> confirmConsentAndAdd(WidgetTester tester) async {
      expect(find.text('Kişi Ekleme Onayı'), findsOneWidget);
      await tester.tap(find.textContaining('Bu kişiyi uygulamaya'));
      await tester.pump();
      await tester.tap(find.text('Ekle'));
      await _settleIo(tester);
    }

    testWidgets('a NBSP-grouped contact is saved as the canonical number', (
      tester,
    ) async {
      await pickFromEmptyState(tester, {
        'number': '0532\u00A0123\u00A045\u00A067',
        'name': 'Anne',
      });

      expect(find.text(noPhoneText), findsNothing);
      await confirmConsentAndAdd(tester);
      expect(repository.records, hasLength(1));
      expect(repository.records.single.phone, '05321234567');
    });

    testWidgets('a contact without a number is told so', (tester) async {
      await pickFromEmptyState(tester, {'number': '', 'name': 'Anne'});

      expect(find.text(noPhoneText), findsOneWidget);
      expect(find.text('Kişi Ekleme Onayı'), findsNothing);
      expect(repository.records, isEmpty);
    });

    testWidgets('a present but uncallable number gets its own message', (
      tester,
    ) async {
      await pickFromEmptyState(tester, {
        'number': '*31#05321234567',
        'name': 'Anne',
      });

      expect(
        find.text(
          'Seçilen kişinin numarası aranabilir bir numara değil. '
          'Numarayı kontrol edip düzeltin veya elle girin.',
        ),
        findsOneWidget,
      );
      expect(find.text(noPhoneText), findsNothing);
      expect(find.text('Kişi Ekleme Onayı'), findsNothing);
      expect(repository.records, isEmpty);
    });

    testWidgets('a pasted pause/extension is refused, not folded into the '
        'digits', (tester) async {
      final phone = await openManualPhoneField(tester);
      await tester.enterText(phone, '0532 123 45 67,123');
      // Also lets the sheet's 300 ms focus-reveal delay run out.
      await tester.pump(const Duration(milliseconds: 400));

      // The old [0-9+] input filter rewrote this into the 14-digit
      // "05321234567123" and accepted it: the pause became part of the
      // number. It must stay visible, as typed, and be refused.
      expect(
        tester.widget<TextFormField>(phone).controller?.text,
        '0532 123 45 67,123',
      );
      expect(find.text(invalidPhoneText), findsOneWidget);
    });

    testWidgets('fullwidth digits are accepted and stored canonical', (
      tester,
    ) async {
      final phone = await openManualPhoneField(tester);
      await tester.enterText(
        phone,
        '\uFF10\uFF15\uFF13\uFF12\uFF11\uFF12\uFF13\uFF14\uFF15\uFF16\uFF17',
      );
      await tester.pump();

      expect(find.text(invalidPhoneText), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await confirmConsentAndAdd(tester);
      expect(repository.records.single.phone, '05321234567');
    });

    testWidgets('a NBSP-grouped paste still saves without the old digit '
        'filter', (tester) async {
      final phone = await openManualPhoneField(tester);
      await tester.enterText(phone, '0532\u00A0123\u00A045\u00A067');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await confirmConsentAndAdd(tester);
      expect(repository.records.single.phone, '05321234567');
    });

    // The sheet owns its text controllers and the phone focus node. The
    // route's future resolves at pop while the exit animation still runs, and
    // focus leaving the closing route rebuilds the fields; disposing them as
    // soon as that future resolved crashed those last frames in debug builds.
    testWidgets('the sheet releases its controllers only after it has fully '
        'closed', (tester) async {
      final phone = await openManualPhoneField(tester);
      await tester.enterText(phone, '0532');
      // Also lets the sheet's 300 ms focus-reveal delay run out.
      await tester.pump(const Duration(milliseconds: 400));
      final phoneFocus = tester
          .widget<EditableText>(
            find.descendant(of: phone, matching: find.byType(EditableText)),
          )
          .focusNode;
      final owned = <String, ChangeNotifier>{
        'name controller': tester
            .widget<TextField>(find.widgetWithText(TextField, 'Ad'))
            .controller!,
        'phone controller': tester.widget<TextFormField>(phone).controller!,
        'phone focus node': phoneFocus,
      };
      expect(phoneFocus.hasFocus, isTrue);

      // Android: the first Back only hides the keyboard and the field keeps
      // focus; the second Back closes the sheet.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Yeni Kişi Ekle'), findsOneWidget, reason: 'mid exit');
      for (final entry in owned.entries) {
        expect(
          () => ChangeNotifier.debugAssertNotDisposed(entry.value),
          returnsNormally,
          reason: 'the closing route still builds the ${entry.key}',
        );
      }

      await tester.pumpAndSettle();
      expect(find.text('Yeni Kişi Ekle'), findsNothing);
      for (final entry in owned.entries) {
        expect(
          () => ChangeNotifier.debugAssertNotDisposed(entry.value),
          throwsFlutterError,
          reason: 'the ${entry.key} is released with the route',
        );
      }
    });

    // Submitting validates before the sheet closes. It used to close first and
    // validate on the page afterwards: an invalid entry lost what was typed
    // and left only a snackbar.
    testWidgets('an uncallable number keeps the sheet and the typed entry on '
        'submit', (tester) async {
      final phone = await openManualPhoneField(tester);
      await tester.enterText(phone, '0532 123 45 67,123');
      // Also lets the sheet's 300 ms focus-reveal delay run out.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Yeni Kişi Ekle'), findsOneWidget);
      expect(
        find.descendant(of: phone, matching: find.text(invalidPhoneText)),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.widget<TextFormField>(phone).controller?.text,
        '0532 123 45 67,123',
      );

      // The kept entry is what gets saved once the number is fixed.
      await tester.enterText(phone, '0532 123 45 67');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await confirmConsentAndAdd(tester);
      expect(repository.records.single.name, 'Anne');
      expect(repository.records.single.phone, '05321234567');
    });

    testWidgets('the save button validates before closing too', (
      tester,
    ) async {
      final phone = await openManualPhoneField(tester);
      final save = find.text('Manuel kaydet');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      // The phone field was never touched, so its error can only come from
      // the tap validating it.
      expect(find.text('Yeni Kişi Ekle'), findsOneWidget);
      expect(
        find.descendant(of: phone, matching: find.text(invalidPhoneText)),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);

      await tester.enterText(phone, '+905551112233');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await confirmConsentAndAdd(tester);
      expect(repository.records.single.name, 'Anne');
      expect(repository.records.single.phone, '+905551112233');
    });

    testWidgets('a blank name keeps the sheet open with the error under the '
        'name', (tester) async {
      final phone = await openManualPhoneField(tester);
      final name = find.widgetWithText(TextField, 'Ad');
      await tester.enterText(name, '   ');
      await tester.enterText(phone, '0532 123 45 67');
      // Also lets the sheet's 300 ms focus-reveal delay run out.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Yeni Kişi Ekle'), findsOneWidget);
      expect(
        find.descendant(of: name, matching: find.text('Kişi adı girin')),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Kişi Ekleme Onayı'), findsNothing);
      expect(
        tester.widget<TextFormField>(phone).controller?.text,
        '0532 123 45 67',
      );
    });
  });
}
