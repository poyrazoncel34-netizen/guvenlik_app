import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/pin_hasher.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/app_bootstrap_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/pin_storage_read_policy.dart';
import 'package:guvenlik_app/core/services/pin_verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a single secure-storage read of the PIN record does.
enum _Read { keystoreError, hang, stored }

/// Secure storage whose PIN reads follow a script. Once the script is used up
/// the LAST outcome repeats, so `[keystoreError]` means "fails forever".
class _ScriptedSecureStorage extends SecureStorage {
  _ScriptedSecureStorage(List<_Read> script, {required String storedRecord})
    : script = List<_Read>.of(script),
      values = <String, String>{SecureStorageKeys.userPin: storedRecord};

  final List<_Read> script;
  final Map<String, String> values;
  int pinReads = 0;
  int writes = 0;
  int deletes = 0;

  @override
  Future<String?> read({required String key}) async {
    if (key != SecureStorageKeys.userPin) return values[key];
    final outcome =
        script[pinReads < script.length ? pinReads : script.length - 1];
    pinReads++;
    switch (outcome) {
      case _Read.keystoreError:
        // The shape flutter_secure_storage 10 returns over the channel when
        // the Android Keystore cannot decrypt the record.
        throw PlatformException(
          code: 'Exception encountered',
          message: 'javax.crypto.AEADBadTagException',
        );
      case _Read.hang:
        return Completer<String?>().future;
      case _Read.stored:
        return values[key];
    }
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writes++;
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    deletes++;
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    deletes++;
    values.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final storedRecord = PinHasher.encode('2468');

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ({_ScriptedSecureStorage storage, PinVerificationService pins}) harness(
    List<_Read> script,
  ) {
    final storage = _ScriptedSecureStorage(script, storedRecord: storedRecord);
    return (
      storage: storage,
      pins: PinVerificationService.forTesting(secureStorage: storage),
    );
  }

  Future<CriticalBootstrapResult> bootstrap(PinVerificationService pins) =>
      AppBootstrapService(
        criticalSteps: <CriticalBootstrapStep>[
          AppBootstrapService.pinStorageStep(pins: pins),
        ],
      ).initializeCritical();

  group('transient secure-storage failures are retried with backoff', () {
    test('a single keystore error followed by a good read is ready', () async {
      final h = harness(const [_Read.keystoreError, _Read.stored]);

      final result = await bootstrap(h.pins);

      expect(result.isReady, isTrue, reason: 'reason=${result.reasonCode}');
      expect(h.storage.pinReads, 2);
      expect(h.pins.state, PinState.configured);
    });

    test(
      'a slow (timed-out) keystore read followed by a good read is ready',
      () async {
        final h = harness(const [_Read.hang, _Read.stored]);

        final result = await bootstrap(h.pins);

        expect(result.isReady, isTrue, reason: 'reason=${result.reasonCode}');
        expect(h.pins.state, PinState.configured);
      },
    );

    test('recovery on the last allowed attempt is still ready', () async {
      final h = harness(const [
        _Read.keystoreError,
        _Read.keystoreError,
        _Read.stored,
      ]);

      final result = await bootstrap(h.pins);

      expect(result.isReady, isTrue, reason: 'reason=${result.reasonCode}');
      expect(h.storage.pinReads, 3);
    });
  });

  group('persistent failures are bounded and classified', () {
    test(
      'a keystore error on every attempt is pinFailed after 3 reads',
      () async {
        final h = harness(const [_Read.keystoreError]);

        final result = await bootstrap(h.pins);

        expect(result.isReady, isFalse);
        expect(result.reasonCode, 'pinFailed');
        expect(h.storage.pinReads, 3, reason: 'bounded: exactly 3 attempts');
      },
    );

    test('a read that keeps timing out is classified as pinTimeout', () async {
      final h = harness(const [_Read.hang]);

      final result = await bootstrap(h.pins);

      expect(result.isReady, isFalse);
      expect(
        result.reasonCode,
        'pinTimeout',
        reason: 'a slow keystore is not evidence of corruption',
      );
      expect(h.storage.pinReads, 3);
    });

    test('persistent failure never becomes "no PIN" and never touches the '
        'stored record (no PIN bypass)', () async {
      final h = harness(const [_Read.keystoreError]);

      await bootstrap(h.pins);

      expect(h.pins.state, PinState.readFailed);
      expect(h.storage.writes, 0);
      expect(h.storage.deletes, 0);
      expect(h.storage.values[SecureStorageKeys.userPin], storedRecord);
      final attempt = await h.pins.verify('2468');
      expect(attempt.matches, isFalse);
      expect(attempt.state, PinState.readFailed);
    });
  });

  group('no storage failure dead-ends', () {
    test('every secure-storage failure reason offers the recovery surface', () {
      for (final reason in const [
        'pinFailed',
        'pinTimeout',
        'contactFailed',
        'contactTimeout',
      ]) {
        expect(
          AppBootstrapService.offersLocalRecovery(reason),
          isTrue,
          reason: '$reason must not fall through to the fatal ErrorWidget',
        );
      }
    });

    test(
      'persistent failure -> recovery surface -> confirmed wipe -> ready',
      () async {
        final h = harness(const [_Read.keystoreError]);

        final failed = await bootstrap(h.pins);
        expect(failed.isReady, isFalse);
        expect(
          AppBootstrapService.offersLocalRecovery(failed.reasonCode ?? ''),
          isTrue,
        );

        // The recovery surface's only data-destroying exit: the same full
        // local wipe as "PIN'imi unuttum". Afterwards the unreadable record is
        // gone, the store reads cleanly and the app restarts into PIN setup.
        await h.storage.deleteAll();
        h.storage.script
          ..clear()
          ..add(_Read.stored);

        final recovered = await bootstrap(h.pins);
        expect(recovered.isReady, isTrue);
        expect(h.pins.state, PinState.absent);
      },
    );
  });
  group('backoff policy', () {
    test('waits 300 ms then 900 ms between exactly 3 attempts', () async {
      final h = harness(const [_Read.keystoreError]);
      final waits = <Duration>[];

      final result = await PinStorageReadPolicy(
        pins: h.pins,
        delay: (d) async => waits.add(d),
      ).read();

      expect(waits, const [
        Duration(milliseconds: 300),
        Duration(milliseconds: 900),
      ]);
      expect(result.attempts, 3);
      expect(result.verdict, PinStorageVerdict.persistentFailure);
    });

    test('a clean read stops immediately without waiting', () async {
      final h = harness(const [_Read.stored]);
      final waits = <Duration>[];

      final result = await PinStorageReadPolicy(
        pins: h.pins,
        delay: (d) async => waits.add(d),
      ).read();

      expect(waits, isEmpty);
      expect(result.attempts, 1);
      expect(result.verdict, PinStorageVerdict.readable);
      expect(result.state, PinState.configured);
    });

    test('a mix of error and timeout is transient, not persistent', () async {
      final h = harness(const [_Read.keystoreError, _Read.hang]);

      final result = await PinStorageReadPolicy(
        pins: h.pins,
        delay: (_) async {},
      ).read();

      expect(result.verdict, PinStorageVerdict.transientFailure);
    });

    test('three slow keystore reads plus backoff fit the PIN step budget', () {
      final worstCase =
          PinStorageReadPolicy.defaultBackoff.fold<Duration>(
            Duration.zero,
            (sum, d) => sum + d,
          ) +
          PinVerificationService.defaultOperationTimeout *
              (PinStorageReadPolicy.defaultBackoff.length + 1);
      expect(worstCase < PinStorageReadPolicy.pinStepBudget, isTrue);
    });
  });
}
