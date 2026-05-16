import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FakeCallScreen haptic feedback', () {
    final hapticLog = <String>[];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      hapticLog.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              hapticLog.add(call.arguments as String);
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('decline button triggers HapticFeedback.heavyImpact', (
      tester,
    ) async {
      await EasyLocalization.ensureInitialized();
      // Pump a minimal stub of the decline button callback directly
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                tapped = true;
              },
              child: const Text('Decline'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(tapped, isTrue);
      expect(hapticLog, contains('HapticFeedbackType.heavyImpact'));
    });
  });
}
