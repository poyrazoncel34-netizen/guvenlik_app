import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/screens/bootstrap_recovery_screen.dart';

void main() {
  Widget app(Widget child) => MaterialApp(home: child);

  testWidgets('retry can recover without exposing the application', (
    tester,
  ) async {
    var recovered = false;
    var resetCalls = 0;

    await tester.pumpWidget(
      app(
        BootstrapRecoveryScreen(
          reasonCode: 'pinFailed',
          retryBootstrap: () async => true,
          hasActiveSafetySession: () async => false,
          resetLocalData: () async {
            resetCalls++;
            return WipeResult.completed;
          },
          onRecovered: () => recovered = true,
        ),
      ),
    );

    expect(find.text('Güvenli başlatma tamamlanamadı'), findsOneWidget);
    expect(find.text('Yeniden Dene'), findsOneWidget);
    expect(find.text('Yerel Verileri Sıfırla'), findsOneWidget);

    await tester.tap(find.text('Yeniden Dene'));
    await tester.pump();

    expect(recovered, isTrue);
    expect(resetCalls, 0);
  });

  testWidgets('active-session uncertainty blocks unauthenticated reset', (
    tester,
  ) async {
    var resetCalls = 0;

    await tester.pumpWidget(
      app(
        BootstrapRecoveryScreen(
          reasonCode: 'pinFailed',
          retryBootstrap: () async => false,
          hasActiveSafetySession: () async => true,
          resetLocalData: () async {
            resetCalls++;
            return WipeResult.completed;
          },
          onRecovered: () {},
        ),
      ),
    );

    await tester.tap(find.text('Yerel Verileri Sıfırla'));
    await tester.pump();

    expect(resetCalls, 0);
    expect(
      find.text('Aktif bir güvenlik oturumu varken sıfırlama yapılamaz.'),
      findsOneWidget,
    );
  });

  testWidgets('reset requires typed confirmation and retries bootstrap', (
    tester,
  ) async {
    var resetCalls = 0;
    var retryCalls = 0;
    var recovered = false;

    await tester.pumpWidget(
      app(
        BootstrapRecoveryScreen(
          reasonCode: 'pinFailed',
          retryBootstrap: () async {
            retryCalls++;
            return true;
          },
          hasActiveSafetySession: () async => false,
          resetLocalData: () async {
            resetCalls++;
            return WipeResult.completed;
          },
          onRecovered: () => recovered = true,
        ),
      ),
    );

    await tester.tap(find.text('Yerel Verileri Sıfırla'));
    await tester.pumpAndSettle();
    expect(find.text('SIFIRLA yazarak onaylayın'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Sıfırla'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), 'SIFIRLA');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sıfırla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(resetCalls, 1);
    expect(retryCalls, 1);
    expect(recovered, isTrue);
  });

  testWidgets('failed reset remains fail-closed and visible', (tester) async {
    var recovered = false;

    await tester.pumpWidget(
      app(
        BootstrapRecoveryScreen(
          reasonCode: 'pinFailed',
          retryBootstrap: () async => true,
          hasActiveSafetySession: () async => false,
          resetLocalData: () async => WipeResult.unknown,
          onRecovered: () => recovered = true,
        ),
      ),
    );

    await tester.tap(find.text('Yerel Verileri Sıfırla'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'SIFIRLA');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sıfırla'));
    await tester.pumpAndSettle();

    expect(recovered, isFalse);
    expect(
      find.text('Veriler güvenli biçimde silinemedi. Yeniden deneyin.'),
      findsOneWidget,
    );
    expect(find.text('Güvenli başlatma tamamlanamadı'), findsOneWidget);
  });
}
