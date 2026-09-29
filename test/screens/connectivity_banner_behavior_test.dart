import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/connectivity_service.dart';
import 'package:guvenlik_app/widgets/connectivity_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const eventChannel = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          if (call.method == 'check') return <String>['none'];
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventChannel, (_) async => null);
    await ConnectivityService.instance.initialize();
    await EasyLocalization.ensureInitialized();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventChannel, null);
  });

  testWidgets(
    'NAV-08/NAV-09: offline banner tap opens production dialog and Tamam closes it',
    (tester) async {
      await pumpLocalized(tester, const ConnectivityBanner());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Çevrimdışı Mod'), findsOneWidget);
      await tester.tap(find.text('Çevrimdışı Mod'));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectivityBanner), findsOneWidget);
      expect(find.text('Çevrimdışı Mod'), findsNWidgets(2));
      expect(find.text('Tamam'), findsOneWidget);

      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();

      expect(find.text('Tamam'), findsNothing);
      expect(find.text('Çevrimdışı Mod'), findsOneWidget);
    },
  );
}
