import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/navigation/app_navigator.dart';
import 'package:guvenlik_app/core/services/notification_service.dart';

void main() {
  final service = NotificationService.instance;

  tearDown(service.resetPendingFakeCallLaunchForTesting);

  testWidgets(
    'cold fake-call response parks before Navigator then routes exactly once',
    (tester) async {
      service.handleNotificationResponseForTesting(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: NotificationService.fakeCallPayload,
        ),
      );
      expect(service.hasPendingFakeCallLaunchForTesting, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const Scaffold(body: Text('underlay')),
        ),
      );

      expect(
        service.routePendingFakeCallLaunch(
          builder: (_) => const Scaffold(body: Text('fake-call-route')),
        ),
        isTrue,
      );
      expect(service.hasPendingFakeCallLaunchForTesting, isFalse);
      await tester.pumpAndSettle();
      expect(find.text('fake-call-route'), findsOneWidget);
      expect(service.routePendingFakeCallLaunch(), isFalse);
    },
  );

  testWidgets(
    'cold fake-call response retries when Navigator misses the first frame',
    (tester) async {
      service.handleNotificationResponseForTesting(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: NotificationService.fakeCallPayload,
        ),
      );

      service.routePendingFakeCallLaunchWhenReady(
        builder: (_) => const Scaffold(body: Text('retried-fake-call-route')),
      );

      // The first scheduled attempt runs without a Navigator and must leave
      // the request intact for the next frame.
      await tester.pump();
      expect(service.hasPendingFakeCallLaunchForTesting, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const Scaffold(body: Text('underlay')),
        ),
      );
      await tester.pumpAndSettle();

      expect(service.hasPendingFakeCallLaunchForTesting, isFalse);
      expect(find.text('retried-fake-call-route'), findsOneWidget);
      expect(service.routePendingFakeCallLaunch(), isFalse);
    },
  );

  test('unknown payload is neither routed nor parked', () {
    service.handleNotificationResponseForTesting(
      const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: 'not_allowlisted',
      ),
    );
    expect(service.hasPendingFakeCallLaunchForTesting, isFalse);
  });
}
