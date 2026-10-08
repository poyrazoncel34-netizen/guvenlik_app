// OwnRoute: navigation that acts on the route owning a context, never on the
// navigator's topmost route (see lib/core/navigation/own_route.dart).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/navigation/own_route.dart';

final _key = GlobalKey<NavigatorState>();

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: _key,
      home: const Scaffold(body: Text('HOME')),
    ),
  );
}

/// Pushes a page that exposes its own context, plus its route.
Future<(BuildContext, Route<Object?>, Future<Object?>)> _pushOwner(
  WidgetTester tester,
) async {
  late BuildContext owner;
  final route = MaterialPageRoute<Object?>(
    builder: (context) {
      owner = context;
      return const Scaffold(body: Text('OWNER'));
    },
  );
  final future = _key.currentState!.push(route);
  await tester.pumpAndSettle();
  return (owner, route, future);
}

Route<void> _pushAbove(WidgetTester tester, String label) {
  final route = MaterialPageRoute<void>(
    builder: (_) => Scaffold(body: Text(label)),
  );
  unawaited(_key.currentState!.push(route));
  return route;
}

void main() {
  testWidgets('pop on the top route is a plain pop with its result', (
    tester,
  ) async {
    await _pump(tester);
    final (owner, _, future) = await _pushOwner(tester);
    OwnRoute.pop(owner, 'done');
    await tester.pumpAndSettle();
    expect(await future, 'done');
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('pop on a covered route removes IT and keeps the cover', (
    tester,
  ) async {
    await _pump(tester);
    final (owner, route, future) = await _pushOwner(tester);
    final above = _pushAbove(tester, 'ABOVE');
    await tester.pumpAndSettle();

    OwnRoute.pop(owner, 'gone');
    await tester.pumpAndSettle();

    expect(above.isCurrent, isTrue);
    expect(route.isActive, isFalse);
    expect(await future, 'gone');
  });

  testWidgets('a second pop during the exit animation leaves every other '
      'route alone', (tester) async {
    await _pump(tester);
    final below = _pushAbove(tester, 'BELOW');
    await tester.pumpAndSettle();
    final (owner, route, _) = await _pushOwner(tester);

    OwnRoute.pop(owner); // e.g. a cancel...
    await tester.pump(const Duration(milliseconds: 50));
    expect(owner.mounted, isTrue, reason: 'still animating out');
    OwnRoute.pop(owner); // ...and a late dispatch answer for the same route
    await tester.pumpAndSettle();

    expect(route.isActive, isFalse);
    expect(below.isCurrent, isTrue, reason: 'a neighbour was popped');
    expect(tester.takeException(), isNull);
  });

  testWidgets('replace on the top route is a plain pushReplacement', (
    tester,
  ) async {
    await _pump(tester);
    final (owner, route, _) = await _pushOwner(tester);
    OwnRoute.replace(
      owner,
      MaterialPageRoute<void>(builder: (_) => const Text('RESULT')),
    );
    await tester.pumpAndSettle();
    expect(find.text('RESULT'), findsOneWidget);
    expect(route.isActive, isFalse);
  });

  testWidgets('replace on a covered route takes its slot BELOW the cover', (
    tester,
  ) async {
    await _pump(tester);
    final (owner, route, future) = await _pushOwner(tester);
    final above = _pushAbove(tester, 'ABOVE');
    await tester.pumpAndSettle();

    final result = MaterialPageRoute<void>(
      builder: (_) => const Text('RESULT'),
    );
    OwnRoute.replace(owner, result);
    await tester.pumpAndSettle();

    expect(above.isCurrent, isTrue);
    expect(result.isActive, isTrue);
    expect(route.isActive, isFalse);
    expect(await future, isNull, reason: 'the replaced route completed');
    _key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(result.isCurrent, isTrue);
  });
}
