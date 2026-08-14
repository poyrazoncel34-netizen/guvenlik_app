import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _androidNs = 'http://schemas.android.com/apk/res/android';
const _packageName = 'com.poyrazoncel.korubeni.smoke';

String _validManifest({
  String extraPermission = '',
  String extraComponent = '',
  String cleartext = 'false',
}) =>
    '''
<manifest xmlns:android="$_androidNs" package="$_packageName">
  <uses-sdk android:minSdkVersion="29" android:targetSdkVersion="36" />
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="com.android.vending.BILLING" />
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
  <uses-permission android:name="android.permission.VIBRATE" />
  <uses-permission android:name="android.permission.CALL_PHONE" />
  <uses-permission android:name="android.permission.WAKE_LOCK" />
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
  <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
  <permission
      android:name="$_packageName.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"
      android:protectionLevel="signature" />
  <uses-permission android:name="$_packageName.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" />
  $extraPermission
  <uses-feature android:name="android.hardware.telephony" android:required="true" />
  <application
      android:allowBackup="false"
      android:extractNativeLibs="false"
      android:fullBackupContent="false"
      android:dataExtractionRules="@xml/data_extraction_rules"
      android:usesCleartextTraffic="$cleartext"
      android:networkSecurityConfig="@xml/network_security_config">
    <activity
        android:name="com.poyrazoncel.korubeni.MainActivity"
        android:exported="true"
        android:launchMode="singleTop"
        android:taskAffinity="">
      <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
      </intent-filter>
      <!-- The shipped deep-link filter (MP-26-008). Present in the fixture so
           "a valid merged release surface" means the surface that actually
           ships, not a reduced one that would let the scheme rule go
           unexercised. -->
      <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="korubeni" android:host="open" />
      </intent-filter>
    </activity>
    <activity android:name="com.poyrazoncel.korubeni.emergency.EmergencyFallbackDialActivity" android:directBootAware="true" android:exported="false" />
    <receiver android:name="com.poyrazoncel.korubeni.emergency.CheckInAlarmReceiver" android:directBootAware="true" android:exported="false" />
    <receiver android:name="com.poyrazoncel.korubeni.emergency.CountdownAlarmReceiver" android:directBootAware="true" android:exported="false" />
    <receiver android:name="com.poyrazoncel.korubeni.emergency.BootCompletedReceiver" android:directBootAware="true" android:exported="false" />
    <receiver android:name="com.poyrazoncel.korubeni.emergency.ExactAlarmPermissionReceiver" android:directBootAware="true" android:exported="false" />
    <receiver android:name="com.poyrazoncel.korubeni.emergency.ClockChangeReceiver" android:directBootAware="true" android:exported="false" />
    <receiver android:name="com.poyrazoncel.korubeni.emergency.EmergencyFallbackCleanupReceiver" android:directBootAware="true" android:exported="false" />
    <receiver
        android:name="androidx.profileinstaller.ProfileInstallReceiver"
        android:exported="true"
        android:permission="android.permission.DUMP">
      <intent-filter>
        <action android:name="androidx.profileinstaller.action.INSTALL_PROFILE" />
      </intent-filter>
    </receiver>
    $extraComponent
  </application>
</manifest>
''';

const _networkConfig = '''
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
  <base-config cleartextTrafficPermitted="false" />
</network-security-config>
''';

const _extractionRules = '''
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
  <cloud-backup>
    <exclude domain="root" path="." />
    <exclude domain="file" path="." />
    <exclude domain="database" path="." />
    <exclude domain="sharedpref" path="." />
    <exclude domain="external" path="." />
    <exclude domain="device_root" path="." />
    <exclude domain="device_file" path="." />
    <exclude domain="device_database" path="." />
    <exclude domain="device_sharedpref" path="." />
  </cloud-backup>
  <device-transfer>
    <exclude domain="root" path="." />
    <exclude domain="file" path="." />
    <exclude domain="database" path="." />
    <exclude domain="sharedpref" path="." />
    <exclude domain="external" path="." />
    <exclude domain="device_root" path="." />
    <exclude domain="device_file" path="." />
    <exclude domain="device_database" path="." />
    <exclude domain="device_sharedpref" path="." />
  </device-transfer>
</data-extraction-rules>
''';

Future<ProcessResult> _runAudit(Directory directory, String manifest) async {
  final manifestFile = File('${directory.path}/AndroidManifest.xml')
    ..writeAsStringSync(manifest);
  final networkFile = File('${directory.path}/network_security_config.xml')
    ..writeAsStringSync(_networkConfig);
  final extractionFile = File('${directory.path}/data_extraction_rules.xml')
    ..writeAsStringSync(_extractionRules);

  return Process.run('python3', [
    'scripts/audit_android_release_surface.py',
    '--manifest',
    manifestFile.path,
    '--network-security-config',
    networkFile.path,
    '--data-extraction-rules',
    extractionFile.path,
    '--expected-package',
    _packageName,
    '--output',
    '${directory.path}/audit.json',
  ]);
}

void main() {
  test('valid merged release surface emits a hash-bound PASS report', () async {
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-release-surface-pass.',
    );
    addTearDown(() => directory.deleteSync(recursive: true));

    final result = await _runAudit(directory, _validManifest());
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('ANDROID_RELEASE_SURFACE_PASS'));

    final report =
        jsonDecode(File('${directory.path}/audit.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(report['status'], 'PASS');
    expect(report['expectedPackage'], _packageName);
    expect(report['manifestSha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(report['permissionCount'], 13);
    expect(report['unprotectedExportedComponents'], isEmpty);
  });

  test('unexpected exported component fails closed without a report', () async {
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-release-surface-exported.',
    );
    addTearDown(() => directory.deleteSync(recursive: true));

    final result = await _runAudit(
      directory,
      _validManifest(
        extraComponent:
            '<receiver android:name="example.AttackerReachable" android:exported="true" />',
      ),
    );
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('unexpected exported component'));
    expect(File('${directory.path}/audit.json').existsSync(), isFalse);
  });

  test('forbidden permission and cleartext opt-in fail closed', () async {
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-release-surface-forbidden.',
    );
    addTearDown(() => directory.deleteSync(recursive: true));

    final result = await _runAudit(
      directory,
      _validManifest(
        extraPermission:
            '<uses-permission android:name="android.permission.RECORD_AUDIO" />',
        cleartext: 'true',
      ),
    );
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('permission allowlist mismatch'));
    expect(result.stderr, contains('usesCleartextTraffic must be false'));
  });

  test('an https App Link on the launcher fails closed', () async {
    // MP-26-008's negative control. An https intent filter asserts ownership of
    // a domain, and this project publishes to a GitHub Pages PROJECT site whose
    // root -- where assetlinks.json must live -- it does not control. Admitting
    // one would let an unverifiable claim ship, so the audit refuses the scheme
    // rather than trusting a reviewer to notice.
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-release-surface-applink.',
    );
    addTearDown(() => directory.deleteSync(recursive: true));

    final manifest = _validManifest().replaceFirst(
      '<data android:scheme="korubeni" android:host="open" />',
      '<data android:scheme="korubeni" android:host="open" />\n'
      '        <data android:scheme="https" '
      'android:host="poyrazoncel34-netizen.github.io" />',
    );
    final result = await _runAudit(directory, manifest);
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('unexpected scheme: https'));
    expect(File('${directory.path}/audit.json').existsSync(), isFalse);
  });

  test('dropping singleTop from the launcher fails closed', () async {
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-release-surface-launchmode.',
    );
    addTearDown(() => directory.deleteSync(recursive: true));

    final manifest = _validManifest()
        .replaceFirst('android:launchMode="singleTop"\n        ', '');
    final result = await _runAudit(directory, manifest);
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('launcher must be singleTop'));
  });

  test('a failed rerun removes a stale PASS report', () async {
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-release-surface-stale.',
    );
    addTearDown(() => directory.deleteSync(recursive: true));

    final passed = await _runAudit(directory, _validManifest());
    expect(passed.exitCode, 0, reason: '${passed.stdout}\n${passed.stderr}');
    final report = File('${directory.path}/audit.json');
    expect(report.existsSync(), isTrue);

    final failed = await _runAudit(
      directory,
      _validManifest(cleartext: 'true'),
    );
    expect(failed.exitCode, isNot(0));
    expect(report.existsSync(), isFalse);
  });

  test('smoke and tagged production pipelines invoke the XML audit', () {
    final smoke = File('scripts/verify_release.sh').readAsStringSync();
    final production = File('scripts/build_production.sh').readAsStringSync();
    final workflow = File('.github/workflows/release.yml').readAsStringSync();

    for (final source in [smoke, production, workflow]) {
      expect(source, contains('audit_android_release_surface.py'));
      expect(source, contains('android-release-surface.json'));
    }
  });
}
