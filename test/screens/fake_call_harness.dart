// ── Shared FakeCallScreen test harness ───────────────────────────────────────
//
// Not a test file: it holds the fixtures that `fake_call_*_test.dart` share.
//
// It exists because of a hard constraint, not for tidiness. `audioplayers`
// cannot build a second `AudioPlayer` inside one widget-test isolate: the first
// player's `dispose()` never completes under the fake clock, and every later
// player's creation handshake then hangs, so `await player.stop()` waits
// forever. `FakeCallScreen` awaits exactly that in `_checkFirstUseWarning`,
// before it shows the KVKK first-use dialog -- so a second dialog test in the
// same file does not fail, it STALLS, and takes the whole suite with it. It was
// reproduced with a standalone player, with no KoruBeni code involved.
//
// Consequence: at most ONE test per file may take the first-use-dialog path
// (`warned: false`). The tests that path covers are therefore split across
// files, one dialog each, and share this harness rather than a copy of it.

import 'dart:async';

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/models/consent_record.dart';
import 'package:guvenlik_app/screens/fake_call_screen.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

class FakeAudioplayersPlatform extends AudioplayersPlatformInterface {
  final Map<String, StreamController<AudioEvent>> _events =
      <String, StreamController<AudioEvent>>{};

  StreamController<AudioEvent> _controllerFor(String playerId) =>
      _events.putIfAbsent(
        playerId,
        () => StreamController<AudioEvent>.broadcast(),
      );

  @override
  Future<void> create(String playerId) async => _controllerFor(playerId);

  @override
  Future<void> dispose(String playerId) async {
    await _events.remove(playerId)?.close();
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) =>
      _controllerFor(playerId).stream;

  @override
  Future<void> pause(String playerId) async {}

  @override
  Future<void> stop(String playerId) async {}

  @override
  Future<void> resume(String playerId) async {}

  @override
  Future<void> release(String playerId) async {}

  @override
  Future<void> seek(String playerId, Duration position) async {}

  @override
  Future<void> setBalance(String playerId, double balance) async {}

  @override
  Future<void> setVolume(String playerId, double volume) async {}

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {}

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {}

  @override
  Future<void> setSourceBytes(
    String playerId,
    Uint8List bytes, {
    String? mimeType,
  }) async {}

  @override
  Future<void> setAudioContext(
    String playerId,
    AudioContext audioContext,
  ) async {}

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}

  @override
  Future<int?> getDuration(String playerId) async => 1000;

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Future<void> emitError(String playerId, String code, String message) async {}
}

class FakeGlobalAudioplayersPlatform
    extends GlobalAudioplayersPlatformInterface {
  final StreamController<GlobalAudioEvent> _events =
      StreamController<GlobalAudioEvent>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => _events.stream;
}

class MemorySecureStorage extends SecureStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class MemoryDatabaseService extends LocalDatabaseService {
  MemoryDatabaseService(this.db);

  final Database db;

  @override
  Future<Database> get database async => db;
}

/// One cycle of "let real async work run, then build a frame".
///
/// `FakeCallScreen` reaches its first paint only after a chain of REAL async
/// work (SharedPreferences, the consent manager, the audio plugin). A widget
/// test's clock is fake, so that work only advances inside `runAsync`, while the
/// widgets it unblocks only appear on a `pump`. Neither alone is enough.
Future<void> settleCycle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

/// Pumps until [condition] holds, up to [attempts] cycles.
///
/// A fixed number of cycles was the original approach here and it was the bug:
/// the first-use dialog needs a different number of cycles depending on what ran
/// before it, so `FKC-05 accept` passed alone and failed after `FKC-05 cancel`.
/// Waiting on the CONDITION instead of on a cycle count removes the race without
/// weakening anything -- the bound still fails the test rather than hanging, and
/// every assertion after the wait is unchanged.
Future<void> pumpUntil(
  WidgetTester tester,
  String describe,
  bool Function() condition, {
  int attempts = 60,
}) async {
  for (var i = 0; i < attempts; i++) {
    if (condition()) {
      return;
    }
    await settleCycle(tester);
  }
  fail('Timed out after $attempts settle cycles waiting for: $describe');
}

/// Pumps until [finder]'s widget stops moving on screen.
///
/// Existing-and-visible is NOT enough to tap: a pushed `MaterialPageRoute` slides
/// in from the right, so mid-transition the screen is laid out at its full width
/// but drawn at an offset (measured here at x=92.4 of a 420-wide window). Taps
/// aimed at its right-hand controls -- "Kabul Et", "Ayarla" -- then land outside
/// the route and are silently dropped, which reads exactly like "the button does
/// nothing". A modal bottom sheet slides the same way.
///
/// `pumpAndSettle` is the usual answer and is unusable here: `FakeCallScreen`
/// runs a repeating pulse animation, so the tree is never "settled" and
/// `pumpAndSettle` would spin until it times out.
Future<void> pumpUntilStill(
  WidgetTester tester,
  String describe,
  Finder finder, {
  int attempts = 80,
}) async {
  Offset? previous;
  var stableCycles = 0;
  for (var i = 0; i < attempts; i++) {
    if (finder.evaluate().isNotEmpty) {
      final RenderBox box = tester.renderObject<RenderBox>(finder.first);
      final Offset position = box.localToGlobal(Offset.zero);
      if (previous != null && (position - previous).distance < 0.01) {
        stableCycles++;
        if (stableCycles >= 2) {
          return;
        }
      } else {
        stableCycles = 0;
      }
      previous = position;
    }
    await settleCycle(tester);
  }
  fail('Timed out after $attempts settle cycles waiting for $describe to stop moving');
}

Future<void> drainAsyncFrames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await settleCycle(tester);
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Reads a table with REAL database I/O.
///
/// `sqflite_common_ffi` talks to a real SQLite instance off the fake clock, so
/// awaiting a query directly inside `testWidgets` never completes -- it hung the
/// whole suite here rather than failing. Every DB read in this file goes through
/// `runAsync` for that reason.
Future<List<Map<String, Object?>>> queryEvents(
  WidgetTester tester,
  Database db,
) async {
  final List<Map<String, Object?>>? rows = await tester.runAsync(
    () => db.query('activity_events'),
  );
  return rows ?? <Map<String, Object?>>[];
}

/// Gives the test a realistic PORTRAIT phone surface.
///
/// The default 800x600 test window is effectively landscape, and `FakeCallScreen`
/// overflows it horizontally: the "Kabul Et" button lands at x~827, past the
/// 800px edge, so `tap()` silently misses and the test sees "nothing happened".
/// That overflow is NOT a shippable defect -- `main.dart` pins the app to
/// portraitUp/portraitDown -- so the fix belongs in the harness, not the screen.
void usePortraitPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

/// What the screen is expected to settle into, so the wait has a single
/// unambiguous target.
///
/// A union-of-states wait was tried first and was wrong: the call UI (caller
/// row, Reddet/Kabul Et buttons) is built on the FIRST frame whether or not the
/// first-use dialog is still pending, so "buttons are visible" matched instantly
/// and the tests raced the very async chain they meant to wait for.
enum FakeCallSettled {
  /// The first-use warning dialog is up.
  warning,

  /// The call is running AND its async setup finished: the caller name arrives
  /// from secure storage, so a non-empty name is the readiness marker. Tapping
  /// before it lands is what made the customize sheet seed empty controllers.
  ringing,

  /// The screen mounted and then closed itself (consent withdrawn).
  dismissed,
}

Future<void> pumpFakeCall(
  WidgetTester tester,
  FakeCallSettled expected,
) async {
  usePortraitPhone(tester);
  await pumpLocalized(
    tester,
    Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const FakeCallScreen()),
        ),
        child: const Text('OPEN_FAKE_CALL'),
      ),
    ),
  );
  await tester.tap(find.text('OPEN_FAKE_CALL'));
  await tester.pump();

  switch (expected) {
    case FakeCallSettled.warning:
      await pumpUntil(
        tester,
        'the first-use warning dialog',
        () => find.text('Sahte Çağrı Uyarısı').evaluate().isNotEmpty,
      );
    case FakeCallSettled.ringing:
      await pumpUntil(
        tester,
        'the running call to finish loading its caller identity',
        () => find.text('Arkadaşım').evaluate().isNotEmpty,
      );
      await pumpUntilStill(
        tester,
        'the fake call route',
        find.byType(FakeCallScreen),
      );
    case FakeCallSettled.dismissed:
      // Waiting on "the route is gone" alone cannot tell "not pushed yet" from
      // "already dismissed", and trying to catch the mount first is a race the
      // other way -- the gate can mount and pop inside one cycle. The gate's own
      // SnackBar is the unambiguous signal: it only exists because the consent
      // check ran and refused, and it outlives the popped route.
      await pumpUntil(
        tester,
        'the consent gate to refuse and close the fake call',
        () =>
            find.byType(FakeCallScreen).evaluate().isEmpty &&
            find.byType(SnackBar).evaluate().isNotEmpty,
      );
  }
}


/// Per-file mutable fixtures: an in-memory secure store, an in-memory database
/// and a real `ConsentManager`.
class FakeCallHarness {
  late Database db;
  late MemorySecureStorage storage;
  late ConsentManager consentManager;

  /// Installs the audio fakes. Must run before any `AudioPlayer` is built --
  /// `audioplayers` caches its global init completer for the isolate's lifetime,
  /// so swapping the platform in later would leave that cache pointing at the
  /// real one.
  static void installAudioFakes() {
    AudioplayersPlatformInterface.instance = FakeAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance =
        FakeGlobalAudioplayersPlatform();
  }

  Future<void> configure({
    required bool warned,
    required bool consent,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pref_fake_call_warned': warned,
    });
    await serviceLocator.reset();
    storage = MemorySecureStorage();
    serviceLocator.registerSingleton<SecureStorage>(storage);
    consentManager = ConsentManager();
    await consentManager.initialize();
    if (consent) {
      await consentManager.grantConsent(ConsentRecord.typeFakeCall);
    }
    serviceLocator.registerSingleton<ConsentManager>(consentManager);
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await LocalDatabaseService.createSchema(db);
    serviceLocator.registerSingleton<LocalDatabaseService>(
      MemoryDatabaseService(db),
    );
  }

  Future<void> tearDownHarness() async {
    // The audio platform fake is deliberately left installed -- see the note at
    // the top of this file.
    await db.close();
    await serviceLocator.reset();
  }

  /// Unmounts the screen INSIDE the test's own async zone, so `State.dispose`
  /// and its unawaited audio teardown do not run while the zone is being torn
  /// down.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await settleCycle(tester);
    }
  }
}
