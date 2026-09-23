import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main awaits fail-closed critical bootstrap without eager billing', () {
    final source = File('lib/main.dart').readAsStringSync();

    final bootstrapIdx = source.indexOf('AppBootstrapService.production(');

    expect(
      bootstrapIdx,
      isNot(-1),
      reason: 'Critical bootstrap must complete before runApp.',
    );
    expect(source, contains('if (!criticalBootstrap.isReady)'));
    expect(
      source,
      contains(
        "CriticalBootstrapStep('localization', EasyLocalization.ensureInitialized)",
      ),
    );
    expect(source, contains("CriticalBootstrapStep('localePreferences'"));
    expect(source, contains('await initializeBestEffortServices(services)'));
    // The list itself lives in startup_best_effort_services.dart so tests run
    // the real one (profile_email_removal_test.dart); main must use it.
    expect(
      source,
      contains('final services = buildStartupBestEffortServices(isWeb: kIsWeb);'),
    );
    expect(
      source.indexOf('buildStartupBestEffortServices('),
      greaterThan(source.indexOf('if (!criticalBootstrap.isReady)')),
      reason: 'optional work still runs only after the critical bootstrap',
    );
    expect(source, contains('ErrorWidget.builder('));
    expect(
      source,
      isNot(contains('serviceLocator<RevenueCatService>().initialize()')),
      reason:
          'RevenueCat may not configure or contact its service before the '
          'current Terms and KVKK acceptance is known.',
    );
  });
}
