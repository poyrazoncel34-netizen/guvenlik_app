import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/local_logger_service.dart';
import 'package:guvenlik_app/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'BOOT-04: installed debug handlers record codes and preserve visibility',
    () {
      final previousFlutterHandler = FlutterError.onError;
      final previousPlatformHandler = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = previousFlutterHandler;
        PlatformDispatcher.instance.onError = previousPlatformHandler;
      });
      final crashCodes = <LocalErrorCode>[];
      final loggerCodes = <LocalErrorCode>[];
      final presented = <FlutterErrorDetails>[];

      app.installUnhandledErrorHandlers(
        crashRecorder: crashCodes.add,
        localLogger: loggerCodes.add,
        debugPresenter: presented.add,
        releaseMode: false,
      );

      final frameworkDetails = FlutterErrorDetails(
        exception: StateError('private phone=555123 PIN=4821'),
      );
      FlutterError.onError!(frameworkDetails);
      final platformHandled = PlatformDispatcher.instance.onError!(
        StateError('private token'),
        StackTrace.current,
      );

      expect(crashCodes, <LocalErrorCode>[
        LocalErrorCode.flutterFrameworkUnhandled,
        LocalErrorCode.platformDispatcherUnhandled,
      ]);
      expect(loggerCodes, crashCodes);
      expect(presented, <FlutterErrorDetails>[frameworkDetails]);
      expect(platformHandled, isFalse);
    },
  );

  test('BOOT-04: installed release handlers suppress raw presentation', () {
    final previousFlutterHandler = FlutterError.onError;
    final previousPlatformHandler = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = previousFlutterHandler;
      PlatformDispatcher.instance.onError = previousPlatformHandler;
    });
    final codes = <LocalErrorCode>[];
    var rawPresentationCount = 0;

    app.installUnhandledErrorHandlers(
      crashRecorder: codes.add,
      localLogger: (_) {},
      debugPresenter: (_) => rawPresentationCount++,
      releaseMode: true,
    );

    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('private phone=555123')),
    );
    final platformHandled = PlatformDispatcher.instance.onError!(
      StateError('private PIN=4821'),
      StackTrace.current,
    );

    expect(codes, <LocalErrorCode>[
      LocalErrorCode.flutterFrameworkUnhandled,
      LocalErrorCode.platformDispatcherUnhandled,
    ]);
    expect(rawPresentationCount, 0);
    expect(platformHandled, isTrue);
  });
}
