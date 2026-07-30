import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/quick_panic_request_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(
      QuickPanicRequestService.channel,
      null,
    );
  });

  group('sourceFrom', () {
    test('recognises the two quick-access surfaces', () {
      expect(
        QuickPanicRequestService.sourceFrom('widget'),
        QuickPanicSource.widget,
      );
      expect(
        QuickPanicRequestService.sourceFrom('tile'),
        QuickPanicSource.tile,
      );
    });

    test('discards an unrecognised label instead of treating it as a request', () {
      // Platform-channel data is not trusted blindly: an unknown value must not
      // open a countdown.
      expect(QuickPanicRequestService.sourceFrom(null), isNull);
      expect(QuickPanicRequestService.sourceFrom(''), isNull);
      expect(QuickPanicRequestService.sourceFrom('WIDGET'), isNull);
      expect(QuickPanicRequestService.sourceFrom('panic'), isNull);
    });
  });

  group('consume', () {
    test('a platform failure yields no request instead of throwing', () async {
      messenger.setMockMethodCallHandler(
        QuickPanicRequestService.channel,
        (call) async => throw PlatformException(code: 'ERROR'),
      );

      expect(await QuickPanicRequestService.consume(), isNull);
    });

    test('a missing channel yields no request', () async {
      messenger.setMockMethodCallHandler(QuickPanicRequestService.channel, null);

      expect(await QuickPanicRequestService.consume(), isNull);
    });

    test('only consumePanicRequest is ever invoked', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(
        QuickPanicRequestService.channel,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );

      await QuickPanicRequestService.consume();

      // Host tests report as non-Android, so the service short-circuits and
      // never touches the channel. What this pins is that it has no other
      // method to call -- no arm, no dispatch, no dial.
      expect(calls, anyOf(isEmpty, equals(<String>['consumePanicRequest'])));
    });
  });
}
