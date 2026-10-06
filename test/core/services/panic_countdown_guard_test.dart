// PanicCountdownGuard: one real panic countdown across every entry point, and
// a guard that can NEVER stay latched. A latched guard would silently disable
// the panic button and every quick-access entry for the rest of the process,
// so each way a countdown route can end is exercised against a real Navigator.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/panic_countdown_guard.dart';

class _Owner extends StatefulWidget {
  const _Owner({required this.onReady});
  final void Function(State<_Owner> state) onReady;
  @override
  State<_Owner> createState() => _OwnerState();
}

class _OwnerState extends State<_Owner> {
  @override
  void initState() {
    super.initState();
    widget.onReady(this);
  }

  @override
  Widget build(BuildContext context) => const Text('OWNER');
}

final _navigatorKey = GlobalKey<NavigatorState>();

Route<void> _countdown([String label = 'COUNTDOWN']) => PageRouteBuilder<void>(
  pageBuilder: (_, _, _) => Scaffold(body: Text(label)),
  transitionDuration: Duration.zero,
  reverseTransitionDuration: Duration.zero,
);

Future<void> _pumpApp(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(MaterialApp(navigatorKey: _navigatorKey, home: home));
}

NavigatorState get _nav => _navigatorKey.currentState!;

void main() {
  setUp(PanicCountdownGuard.resetForTesting);

  test('a second owner is refused while the first holds the guard', () {
    final first = Object();
    final second = Object();
    expect(PanicCountdownGuard.tryAcquire(first), isTrue);
    expect(PanicCountdownGuard.tryAcquire(second), isFalse);
    PanicCountdownGuard.release(second); // not the owner: must be ignored
    expect(PanicCountdownGuard.isHeld, isTrue);
    PanicCountdownGuard.release(first);
    expect(PanicCountdownGuard.isHeld, isFalse);
  });

  testWidgets('open() refuses without pushing while another owner holds it', (
    tester,
  ) async {
    await _pumpApp(tester, const Text('HOME'));
    final quickAccess = Object();
    PanicCountdownGuard.tryAcquire(quickAccess);
    var pushed = false;
    final opened = PanicCountdownGuard.open(Object(), () {
      pushed = true;
      return _nav.push(_countdown());
    });
    expect(opened, isNull);
    expect(pushed, isFalse);
    PanicCountdownGuard.release(quickAccess);
  });

  final endings = <String, void Function()>{
    'pop': () => _nav.pop(),
    'pushReplacement (dispatch hand-off to the result screen)': () =>
        _nav.pushReplacement(_countdown('RESULT')),
    'popUntil first (result screen exit)': () =>
        _nav.popUntil((route) => route.isFirst),
    'pushAndRemoveUntil': () =>
        _nav.pushAndRemoveUntil(_countdown('SPLASH'), (_) => false),
  };
  for (final ending in endings.entries) {
    testWidgets('released when the countdown route ends by ${ending.key}', (
      tester,
    ) async {
      await _pumpApp(tester, const Text('HOME'));
      final owner = Object();
      final opened = PanicCountdownGuard.open(
        owner,
        () => _nav.push(_countdown()),
      );
      expect(opened, isNotNull);
      await tester.pump();
      expect(find.text('COUNTDOWN'), findsOneWidget);
      expect(PanicCountdownGuard.isHeld, isTrue);

      ending.value();
      await tester.pump();
      await tester.pump();
      expect(
        PanicCountdownGuard.isHeld,
        isFalse,
        reason: 'guard stayed latched after ${ending.key}',
      );
    });
  }

  testWidgets('released when the countdown route is removed', (tester) async {
    await _pumpApp(tester, const Text('HOME'));
    late Route<void> route;
    PanicCountdownGuard.open(Object(), () => _nav.push(route = _countdown()));
    await tester.pump();
    _nav.removeRoute(route);
    await tester.pump();
    expect(PanicCountdownGuard.isHeld, isFalse);
  });

  test('released when the push itself throws', () {
    final owner = Object();
    expect(
      () => PanicCountdownGuard.open<void>(
        owner,
        () => throw StateError('navigator gone'),
      ),
      throwsStateError,
    );
    expect(PanicCountdownGuard.isHeld, isFalse);
  });

  testWidgets(
    'the owner widget being disposed while its countdown is open neither '
    'frees the guard early nor latches it',
    (tester) async {
      final showOwner = ValueNotifier<bool>(true);
      late State<_Owner> ownerState;
      await _pumpApp(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: showOwner,
          builder: (_, show, _) => show
              ? _Owner(onReady: (s) => ownerState = s)
              : const Text('REBUILT_HOME'),
        ),
      );
      PanicCountdownGuard.open(ownerState, () => _nav.push(_countdown()));
      await tester.pump();

      // The panic button's subtree goes away while the countdown it opened is
      // still on screen.
      showOwner.value = false;
      await tester.pump();
      expect(ownerState.mounted, isFalse);
      expect(find.text('COUNTDOWN'), findsOneWidget);
      expect(
        PanicCountdownGuard.isHeld,
        isTrue,
        reason: 'the countdown is still open; a second one must stay blocked',
      );

      _nav.pop();
      await tester.pump();
      await tester.pump();
      expect(PanicCountdownGuard.isHeld, isFalse);
    },
  );
}
