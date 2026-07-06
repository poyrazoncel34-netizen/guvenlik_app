import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release artifact paths', () {
    const playAab = 'build/app/outputs/bundle/playRelease/app-play-release.aab';
    const staleFragments = [
      'build/app/outputs/bundle/release/app-release.aab',
      'bundle/release',
      'app-release.aab',
      'flutter build appbundle --release --dart-define=ENV=production',
    ];

    test('scripts and release checklists point to playRelease AAB', () {
      final files = [
        File('scripts/build_production.sh'),
        File('scripts/release_to_play_store.sh'),
        File('android/fastlane/Fastfile'),
        File('store/release_checklist.md'),
        File('store/INTERNAL_TESTING_GUIDE.md'),
        File('store/PLAY_CONSOLE_CHECKLIST.md'),
      ];

      final violations = <String>[];
      for (final file in files) {
        final source = file.readAsStringSync();
        if (!source.contains(playAab)) {
          violations.add('${file.path}:missing playRelease AAB path');
        }
        for (final fragment in staleFragments) {
          if (source.contains(fragment)) {
            violations.add('${file.path}:$fragment');
          }
        }
      }

      expect(violations, isEmpty);
    });

    test('build entry points use the Play flavor and production defines', () {
      final buildScript = File(
        'scripts/build_production.sh',
      ).readAsStringSync();
      final fastfile = File('android/fastlane/Fastfile').readAsStringSync();

      expect(buildScript, contains('--flavor play'));
      expect(buildScript, contains('--dart-define=ENV=production'));
      expect(
        buildScript,
        contains('--dart-define=REVENUECAT_ANDROID_API_KEY='),
      );
      expect(buildScript, contains(r'${REVENUECAT_ANDROID_API_KEY:-}'));

      expect(fastfile, contains('--flavor play'));
      expect(fastfile, contains("ENV.fetch('REVENUECAT_ANDROID_API_KEY')"));
      expect(fastfile, isNot(contains('ENCRYPTION_KEY')));
    });

    test('release docs mention required RevenueCat Android API key', () {
      final docs = [
        File('store/release_checklist.md'),
        File('store/INTERNAL_TESTING_GUIDE.md'),
        File('store/PLAY_CONSOLE_CHECKLIST.md'),
      ];

      for (final doc in docs) {
        final source = doc.readAsStringSync();
        expect(
          source,
          contains('REVENUECAT_ANDROID_API_KEY'),
          reason: '${doc.path} must document the required RevenueCat key.',
        );
      }
    });

    test(
      'release workflow and setup script do not echo or create secrets locally',
      () {
        final releaseWorkflow = File(
          '.github/workflows/release.yml',
        ).readAsStringSync();
        final setupScript = File(
          'scripts/setup_play_release.sh',
        ).readAsStringSync();

        expect(releaseWorkflow, isNot(contains('ENCRYPTION_KEY')));
        expect(
          releaseWorkflow,
          contains('REVENUECAT_ANDROID_API_KEY: \${{ secrets.'),
        );
        expect(
          releaseWorkflow,
          isNot(contains('--dart-define=ENCRYPTION_KEY=\${{ secrets.')),
        );
        expect(
          releaseWorkflow,
          isNot(
            contains('--dart-define=REVENUECAT_ANDROID_API_KEY=\${{ secrets.'),
          ),
        );
        expect(releaseWorkflow, contains('RELEASE_SECRETS_REDACTED'));

        expect(setupScript, contains('Bu script dosya oluşturmaz'));
        expect(setupScript, isNot(contains(r'cp "$KEY_EXAMPLE" "$KEY_PROPS"')));
        expect(setupScript, isNot(contains(r'cat > "$KEY_PROPS"')));
        expect(setupScript, contains('ayrı operator adımı'));
      },
    );
  });
}
