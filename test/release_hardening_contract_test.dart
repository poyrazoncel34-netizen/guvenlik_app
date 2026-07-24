import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'supported Android envelope is explicit and cannot drift below API 29',
    () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(gradle, contains('minSdk = 29'));
      expect(gradle, contains('compileSdk = 36'));
      expect(gradle, contains('targetSdk = 36'));
      expect(gradle, isNot(contains('minSdk = flutter.minSdkVersion')));
    },
  );

  test('first production runtime is Turkish-only', () {
    final main = File('lib/main.dart').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(main, contains("supportedLocales: const [Locale('tr', 'TR')]"));
    expect(
      main,
      isNot(
        contains(
          "supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')]",
        ),
      ),
    );
    expect(gradle, contains('localeFilters += listOf("tr")'));
  });

  test('GitHub Actions are immutable and least-privilege by default', () {
    final workflows = Directory(
      '.github/workflows',
    ).listSync().whereType<File>().where((file) => file.path.endsWith('.yml'));
    final mutableUses = <String>[];

    for (final workflow in workflows) {
      final source = workflow.readAsStringSync();
      expect(
        source,
        contains('permissions:'),
        reason: '${workflow.path} must declare explicit permissions.',
      );
      for (final match in RegExp(
        r'uses:\s*[^\s]+@([^\s#]+)',
      ).allMatches(source)) {
        final ref = match.group(1)!;
        if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(ref)) {
          mutableUses.add('${workflow.path}:$ref');
        }
      }
    }

    expect(mutableUses, isEmpty);
  });

  test('local verifier never claims external production readiness', () {
    final verifier = File('scripts/verify_release.sh').readAsStringSync();

    expect(verifier, contains('LOCAL_CANDIDATE_PASS'));
    expect(verifier, contains('EXTERNAL_RELEASE_GATES_UNVERIFIED'));
    expect(verifier, isNot(contains('yanlış-yeşil imkânsız')));
    expect(verifier, isNot(contains('deterministik cevabıdır')));
  });

  test('strict verifier resolves dependencies cold before claiming green', () {
    // 2026-07-24 regresyonu: verification-metadata.xml'de
    // ui-unit-android-1.7.0.module girdisi eksikti. Yerel dogrulama zinciri
    // 6/6 yesil verdi ama CI'in 4 job'u ayni commit'te kirmiziydi. Sebep
    // yapisal: Gradle surum cakismasini descriptor cache'inden cozer ve
    // KAYBEDEN adayin .module dosyasini indirmedigi icin dogrulama yerelde hic
    // tetiklenmez. --refresh-dependencies bu farki kapatir; bayrak dusurulurse
    // kapi sessizce yalanci-yesile doner, o yuzden pinlenir.
    final verifier = File('scripts/verify_release.sh').readAsStringSync();

    expect(verifier, contains('checkPlayDebugAarMetadata'));
    expect(verifier, contains('--refresh-dependencies'));

    // Dogrulanamayan kapi yesil sayilamaz (fail-closed).
    expect(verifier, contains('dogrulanamayan kapi yesil sayilmaz'));

    // Adim sayaci sabit olmamali: kapi eklendiginde sessizce yanlis sayar.
    expect(verifier, isNot(contains(r'[%d/6]')));
  });

  test('platform-classified artifacts are verified for CI and dev hosts', () {
    // 2026-07-24, ikinci regresyon: aapt2'nin YALNIZ -osx.jar girdisi vardi,
    // cunku verification-metadata.xml bir macOS makinesinde uretilmisti. CI
    // ubuntu'dur ve -linux.jar ister; o girdi olmadan
    // :audioplayers_android:compileDebugLibraryResources kirilir.
    //
    // Bu, soguk cozum kapisinin (verify_release.sh --strict-release-gates)
    // YAPISAL OLARAK yakalayamayacagi bir siniftir: --refresh-dependencies bile
    // macOS'ta linux siniflandirmali artefakti cozmez, cunku siniflandirmayi
    // host OS belirler. Statik kontrol tek dogru arac.
    final metadata = File(
      'android/gradle/verification-metadata.xml',
    ).readAsStringSync();

    final classified = RegExp(r'name="([^"]+)-(linux|osx|windows)\.jar"');
    final families = <String, Set<String>>{};
    for (final match in classified.allMatches(metadata)) {
      families.putIfAbsent(match.group(1)!, () => <String>{})
        ..add(match.group(2)!);
    }

    // En az bir platform-siniflandirmali aile bulunmali; regex sessizce
    // eslesmeyi birakirsa test yalanci-yesile donmemeli.
    expect(
      families,
      isNotEmpty,
      reason:
          'platform-siniflandirmali artefakt bulunamadi; regex bozulmus olabilir',
    );

    final missing = <String>[];
    families.forEach((base, platforms) {
      for (final required in const ['linux', 'osx']) {
        if (!platforms.contains(required)) {
          missing.add('$base -> $required eksik');
        }
      }
    });

    expect(
      missing,
      isEmpty,
      reason:
          'CI ubuntu, gelistirici makinesi macOS. Her iki siniflandirma da '
          'kayitli olmali. Eksik girdiyi ELLE yazma; Gradle yazicisini o '
          'siniflandirmayi cozmeye zorlayip urettir.',
    );
  });

  test('fallback notifications and PendingIntents do not carry phone PII', () {
    final copy = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/NativeNotificationText.kt',
    ).readAsStringSync();
    final dial = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyFallbackDialActivity.kt',
    ).readAsStringSync();
    final cleanup = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyFallbackCleanupReceiver.kt',
    ).readAsStringSync();

    expect(copy, isNot(contains('{number}')));
    expect(dial, isNot(contains('EXTRA_TARGET')));
    expect(cleanup, isNot(contains('EXTRA_TARGET')));
    expect(dial, contains('consumeFallbackTarget'));
  });

  test('release workflow requires protected signed-main provenance', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();
    final wrapper = File(
      'android/gradle/wrapper/gradle-wrapper.properties',
    ).readAsStringSync();

    expect(workflow, contains('environment: production'));
    expect(workflow, contains('git verify-tag'));
    expect(workflow, contains('git merge-base --is-ancestor'));
    expect(workflow, contains('umask 077'));
    expect(workflow, contains('chmod 600 "\$KEYSTORE_OUT"'));
    expect(workflow, contains('AAB signer mismatch'));
    expect(wrapper, contains('distributionSha256Sum='));
    expect(File('android/gradlew').existsSync(), isTrue);
    expect(File('android/gradlew.bat').existsSync(), isTrue);
    expect(
      File('android/gradle/wrapper/gradle-wrapper.jar').existsSync(),
      isTrue,
    );
  });

  test('tagged candidate provenance fails closed on any source drift', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();
    final verifier = File(
      'scripts/verify_release_source_provenance.sh',
    ).readAsStringSync();

    expect(workflow, contains('./scripts/verify_release_source_provenance.sh'));
    expect(
      workflow.indexOf('./scripts/verify_release_source_provenance.sh'),
      lessThan(workflow.indexOf('flutter pub get')),
      reason: 'Source identity must be frozen before dependency/build output.',
    );
    expect(
      verifier,
      contains('git status --porcelain=v1 --untracked-files=all'),
    );
    expect(verifier, contains('git rev-parse "HEAD^{tree}"'));
    expect(verifier, contains(r'git rev-parse "refs/tags/$TAG^{commit}"'));
    expect(verifier, contains('source_status=clean'));
    expect(workflow, contains('scripts/generate_release_provenance.py'));
    expect(workflow, contains(r'--commit "$GIT_COMMIT"'));
    expect(workflow, contains(r'--tree "$GIT_TREE"'));
    expect(workflow, contains(r'--artifact "aab=$AAB"'));
    expect(workflow, contains('provenance-v2.json'));
    expect(workflow, contains('EXPECTED_PLAY_APP_SIGNING_CERT_SHA256'));
  });
}
