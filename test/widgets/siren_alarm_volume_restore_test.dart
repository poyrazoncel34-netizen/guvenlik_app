// The siren raises the device ALARM stream to its maximum and must put back
// the user's own level when it stops.
//
// `_startSirenSound` is async and `dispose` is not: the original level is only
// known once `setMaxAlarmVolume` has RETURNED. Stopping the siren before that
// (a quick "Durdur", or the dialog going away) ran dispose with nothing to
// restore, the native call then raised the volume anyway, and the user's alarm
// stream stayed at maximum for good -- their next morning alarm included.

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/widgets/siren_dialog.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _audioControl = MethodChannel('com.poyrazoncel.korubeni/audio_control');

/// AudioCache copies the bundled siren asset into the temp directory.
class _TempPaths extends PathProviderPlatform {
  _TempPaths(this.root);
  final String root;
  @override
  Future<String> getTemporaryPath() async => root;
  @override
  Future<String> getApplicationDocumentsPath() async => root;
  @override
  Future<String> getApplicationSupportPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> audioCalls;
  late List<String> playerCalls;
  late Completer<int> maxVolumeReply;
  late PathProviderPlatform originalPaths;

  setUp(() async {
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TempPaths(
      Directory.systemTemp.createTempSync('siren_').path,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.prefWarningSiren: true,
      AppConstants.prefSound: true,
    });
    await EasyLocalization.ensureInitialized();
    audioCalls = <MethodCall>[];
    playerCalls = <String>[];
    maxVolumeReply = Completer<int>();
    messenger.setMockMethodCallHandler(_audioControl, (call) {
      audioCalls.add(call);
      if (call.method == 'setMaxAlarmVolume') return maxVolumeReply.future;
      return Future<Object?>.value(true);
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        playerCalls.add(call.method);
        if (call.method == 'create') {
          // The per-player event channel is named after a random id, so it
          // can only be answered once `create` has told us the id.
          final id = (call.arguments as Map)['playerId'];
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null,
          );
        }
        return null;
      },
    );
    for (final name in const [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
    // The player library initialises a process-wide scope once. Done inside a
    // widget test's fake zone, its completer would outlive that test and hang
    // every later player, so it is initialised here, in real time.
    await AudioPlayer.global.ensureInitialized();
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPaths;
    messenger.setMockMethodCallHandler(_audioControl, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      null,
    );
    for (final name in const [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  Future<void> openSiren(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => const SirenDialog(),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();
  }

  /// AudioCache copies the asset on the real clock: poll, bounded, for the
  /// step the test depends on instead of guessing how long that takes.
  Future<void> drain(WidgetTester tester, {bool Function()? until}) async {
    for (var i = 0; i < 150; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (until == null ? i >= 14 : until()) return;
    }
  }

  bool sawMethod(List<MethodCall> calls, String method) =>
      calls.any((call) => call.method == method);

  /// Pops the dialog and waits until its State has really been disposed.
  Future<void> closeSiren(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(SirenDialog))).pop();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(SirenDialog), findsNothing);
  }

  testWidgets('stop while the volume is still being raised restores it', (
    tester,
  ) async {
    await openSiren(tester);
    await drain(tester, until: () => sawMethod(audioCalls, 'setMaxAlarmVolume'));
    expect(
      audioCalls.map((c) => c.method),
      contains('setMaxAlarmVolume'),
      reason: 'precondition: the raise is in flight',
    );

    await closeSiren(tester);
    maxVolumeReply.complete(3);
    await drain(tester, until: () => sawMethod(audioCalls, 'restoreAlarmVolume'));

    final restores = audioCalls.where((c) => c.method == 'restoreAlarmVolume');
    expect(restores, hasLength(1));
    expect(restores.single.arguments, 3);
    expect(
      playerCalls,
      isNot(contains('setSourceUrl')),
      reason: 'a stopped siren must not go on to load and play its sound',
    );
  });

  testWidgets('normal start and stop restores the original level once', (
    tester,
  ) async {
    maxVolumeReply.complete(5);
    await openSiren(tester);
    await drain(tester, until: () => playerCalls.contains('setSourceUrl'));
    // The player waits for a native "prepared" event this harness never sends,
    // so loading the source is as far as a host test can follow it.
    expect(playerCalls, contains('setSourceUrl'));

    await closeSiren(tester);
    await drain(tester, until: () => sawMethod(audioCalls, 'restoreAlarmVolume'));
    final restores = audioCalls.where((c) => c.method == 'restoreAlarmVolume');
    expect(restores, hasLength(1));
    expect(restores.single.arguments, 5);
  });

  testWidgets('rapid open/stop cycles always restore', (tester) async {
    for (var cycle = 0; cycle < 3; cycle++) {
      audioCalls.clear();
      maxVolumeReply = Completer<int>();
      await openSiren(tester);
      await drain(
        tester,
        until: () => sawMethod(audioCalls, 'setMaxAlarmVolume'),
      );
      await closeSiren(tester);
      maxVolumeReply.complete(cycle % 7);
      await drain(
        tester,
        until: () => sawMethod(audioCalls, 'restoreAlarmVolume'),
      );
      final raised = audioCalls.where((c) => c.method == 'setMaxAlarmVolume');
      expect(raised, hasLength(1), reason: 'cycle $cycle never raised');
      final restored =
          audioCalls.where((c) => c.method == 'restoreAlarmVolume').toList();
      expect(restored.length, raised.length, reason: 'cycle $cycle');
      if (restored.isNotEmpty) expect(restored.single.arguments, cycle % 7);
    }
  });
}
