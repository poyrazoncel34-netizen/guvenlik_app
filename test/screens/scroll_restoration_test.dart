// MP-10-023 -- scroll restoration across PROCESS DEATH, not merely across a
// widget rebuild.
//
// The requirement's own remediation note said "add restorationId to the two
// long scroll views". That is right for one of them and wrong for the other,
// and the difference is the point of this file: `ListView.restorationId`
// restores a RAW PIXEL OFFSET. The settings list has fixed content, so an
// offset is exactly the right thing. The safety timeline grows and PREPENDS
// (it sorts by timestamp DESC), so an offset restored after a process death
// during which a check-in fired lands on a different event than the one the
// user was reading -- the app appears to scroll somewhere by itself.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/scroll_restoration.dart';

void main() {
  group('the anchor survives serialisation', () {
    test('round-trips offset and identity', () {
      const anchor = ScrollAnchor(offset: 1234.5, topItemId: 'evt-9');
      final restored = ScrollAnchor.decode(anchor.encode());
      expect(restored, anchor);
      expect(restored?.offset, 1234.5);
      expect(restored?.topItemId, 'evt-9');
    });

    test('an offset-only anchor round-trips', () {
      const anchor = ScrollAnchor(offset: 42);
      expect(ScrollAnchor.decode(anchor.encode()), anchor);
    });

    test('malformed restoration data means "top", never an exception', () {
      // Restoration data comes back from the platform and can be anything.
      // Throwing here would crash the app on RESUME, which is the worst
      // possible moment for a safety app.
      for (final hostile in <Object?>[
        null, '', 'not json', '[]', '{}', '{"o":"NaN"}', '{"i":"x"}', 42,
        '{"o":1,"i":""}',
      ]) {
        final decoded = ScrollAnchor.decode(hostile);
        expect(decoded == null || decoded.topItemId != '', isTrue,
            reason: 'input: $hostile');
      }
    });

    test('a RestorableScrollAnchor exposes the same primitives', () {
      final restorable = RestorableScrollAnchor();
      addTearDown(restorable.dispose);
      expect(restorable.createDefaultValue(), isNull);
      expect(
        restorable.fromPrimitives(
          const ScrollAnchor(offset: 10, topItemId: 'a').encode(),
        ),
        const ScrollAnchor(offset: 10, topItemId: 'a'),
      );
    });
  });

  group('the policy prefers identity over pixels', () {
    const anchor = ScrollAnchor(offset: 900, topItemId: 'evt-5');

    test('the anchored item is chosen when it still exists', () {
      expect(
        ScrollRestorationPolicy.resolveTarget(
          anchor,
          <String>['evt-9', 'evt-8', 'evt-5', 'evt-1'],
        ),
        'evt-5',
        reason: 'four rows were prepended while the app was dead; the offset '
            'would now point somewhere else entirely',
      );
    });

    test('a vanished item falls back to the offset', () {
      expect(
        ScrollRestorationPolicy.resolveTarget(anchor, <String>['evt-9']),
        isNull,
      );
      expect(ScrollRestorationPolicy.fallbackOffset(anchor, 2000), 900);
    });

    test('the fallback is clamped to the list that EXISTS now', () {
      // The previous session's list was longer. Jumping to 900 in a list whose
      // extent is 300 throws or snaps, and either reads as a bug on resume.
      expect(ScrollRestorationPolicy.fallbackOffset(anchor, 300), 300);
      expect(ScrollRestorationPolicy.fallbackOffset(anchor, 0), 0);
      expect(
        ScrollRestorationPolicy.fallbackOffset(
          const ScrollAnchor(offset: -5),
          1000,
        ),
        0,
      );
    });

    test('an at-top anchor is not restored at all', () {
      expect(const ScrollAnchor(offset: 0).isAtTop, isTrue);
      expect(const ScrollAnchor(offset: 0, topItemId: 'a').isAtTop, isFalse);
      expect(const ScrollAnchor(offset: 10).isAtTop, isFalse);
    });
  });

  group('the restorer against a real, scrolling list', () {
    Future<KeyedListScrollRestorer> pumpList(
      WidgetTester tester,
      List<String> ids, {
      KeyedListScrollRestorer? reuse,
    }) async {
      final restorer = reuse ?? (KeyedListScrollRestorer()..attach());
      restorer.setItems(ids);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: restorer.controller,
              itemCount: ids.length,
              itemBuilder: (context, index) => KeyedSubtree(
                key: restorer.keyFor(ids[index]),
                // Deliberately uneven heights: a uniform extent would make
                // index-times-extent work, and that is not this list.
                child: SizedBox(
                  height: 60 + (index % 3) * 20,
                  child: Text(ids[index]),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return restorer;
    }

    testWidgets('scrolling captures the identity at the viewport top',
        (tester) async {
      final ids = List<String>.generate(40, (i) => 'evt-$i');
      final restorer = await pumpList(tester, ids);
      addTearDown(restorer.dispose);

      restorer.controller.jumpTo(500);
      await tester.pumpAndSettle();

      final anchor = restorer.value;
      expect(anchor, isNotNull);
      expect(anchor!.offset, 500);
      expect(anchor.topItemId, isNotNull,
          reason: 'without an identity the anchor degrades to a bare offset, '
              'which is what this row exists to improve on');
      // The captured id must be an item that is genuinely at/below the top.
      final capturedOffset = restorer.offsetOf(anchor.topItemId!);
      expect(capturedOffset, isNotNull);
      expect(capturedOffset as double, greaterThanOrEqualTo(500 - 0.5));
    });

    testWidgets('PROCESS DEATH + PREPENDED rows: the same EVENT is restored, '
        'not the same pixel', (tester) async {
      final before = List<String>.generate(40, (i) => 'evt-$i');
      final first = await pumpList(tester, before);
      first.controller.jumpTo(500);
      await tester.pumpAndSettle();
      final anchor = first.value!;
      final anchoredId = anchor.topItemId!;
      final offsetBefore = first.offsetOf(anchoredId)!;
      first.dispose();

      // The process died. Five events happened while it was gone and are
      // PREPENDED, then the app came back with a restored anchor.
      final after = <String>[
        for (var i = 0; i < 5; i++) 'evt-new-$i',
        ...before,
      ];
      final second = KeyedListScrollRestorer()..attach();
      addTearDown(second.dispose);
      second.value = ScrollAnchor.decode(anchor.encode());
      await pumpList(tester, after, reuse: second);
      second.applyOnce(after);
      await tester.pumpAndSettle();

      final offsetAfter = second.offsetOf(anchoredId);
      expect(offsetAfter, isNotNull,
          reason: 'the anchored event must still be findable');
      // The list got longer above the anchor, so the raw offset moved...
      expect(offsetAfter, greaterThan(offsetBefore));
      // ...and the restored scroll position followed the EVENT, not the pixel.
      expect(second.controller.position.pixels,
          closeTo(offsetAfter as double, 1.0),
          reason: 'restoring ${anchor.offset} verbatim would have left the '
              'user looking at a different event');
      expect(second.controller.position.pixels,
          isNot(closeTo(anchor.offset, 1.0)));
    });

    testWidgets('a DELETED anchor item falls back to the clamped offset',
        (tester) async {
      final ids = List<String>.generate(40, (i) => 'evt-$i');
      final restorer = KeyedListScrollRestorer()..attach();
      addTearDown(restorer.dispose);
      restorer.value =
          const ScrollAnchor(offset: 400, topItemId: 'evt-gone');
      await pumpList(tester, ids, reuse: restorer);
      restorer.applyOnce(ids);
      await tester.pumpAndSettle();
      expect(restorer.controller.position.pixels, closeTo(400, 1.0));
    });

    testWidgets('a SHORTER list clamps instead of throwing', (tester) async {
      final restorer = KeyedListScrollRestorer()..attach();
      addTearDown(restorer.dispose);
      restorer.value =
          const ScrollAnchor(offset: 5000, topItemId: 'evt-gone');
      final ids = List<String>.generate(3, (i) => 'evt-$i');
      await pumpList(tester, ids, reuse: restorer);
      restorer.applyOnce(ids);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(restorer.controller.position.pixels,
          restorer.controller.position.maxScrollExtent);
    });

    testWidgets('applyOnce is once: a rebuild does not re-scroll',
        (tester) async {
      final ids = List<String>.generate(40, (i) => 'evt-$i');
      final restorer = KeyedListScrollRestorer()..attach();
      addTearDown(restorer.dispose);
      restorer.value =
          const ScrollAnchor(offset: 400, topItemId: 'evt-gone');
      await pumpList(tester, ids, reuse: restorer);
      restorer.applyOnce(ids);
      await tester.pumpAndSettle();

      restorer.controller.jumpTo(0);
      await tester.pumpAndSettle();
      restorer.applyOnce(ids);
      await tester.pumpAndSettle();
      expect(restorer.controller.position.pixels, 0,
          reason: 'a second application would yank the user back whenever the '
              'list rebuilt');
    });
  });

  group('the two lists use the mechanism suited to their content', () {
    test('settings uses the built-in pixel restoration -- content is fixed',
        () {
      final src = File('lib/screens/settings_page.dart').readAsStringSync();
      expect(src, contains("restorationId: 'settings_page_scroll'"));
    });

    test('the timeline uses the identity anchor -- content grows', () {
      final src =
          File('lib/screens/safety_timeline_screen.dart').readAsStringSync();
      expect(src, contains('RestorationMixin'));
      expect(src, contains("restorationId => 'safety_timeline'"));
      expect(src, contains('registerForRestoration(_restorer.anchor'));
      expect(src, contains('KeyedListScrollRestorer'));
      // The wrong mechanism for this list, asserted absent.
      expect(src, isNot(contains("restorationId: 'safety_timeline_scroll'")),
          reason: 'ListView.restorationId here would restore a pixel offset '
              'into a list that prepends rows');
    });

    test('the PIN gate architecture is untouched', () {
      // A restored ROUTE above the unlock screen is the crash and the security
      // hole this app already paid for once; only widget STATE is restorable.
      final root = File('lib/screens/app_root.dart').readAsStringSync();
      expect(root, contains('_destination'));
      expect(root, isNot(contains('restorationId: ')),
          reason: 'AppRoot._destination must stay non-restorable so a process '
              'death re-runs the whole decision including the PIN gate');
    });
  });

  group('negative control -- the naive mechanism FAILS this suite', () {
    testWidgets('a raw pixel restore lands on the wrong event', (tester) async {
      // Reproduce exactly what `ListView.restorationId` would have done: put
      // the old offset back verbatim. If that satisfied the assertions above,
      // none of this machinery would be earning its place.
      final before = List<String>.generate(40, (i) => 'evt-$i');
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final keys = <String, GlobalObjectKey>{
        for (final id in <String>[...before.map((e) => e), for (var i = 0; i < 5; i++) 'evt-new-$i'])
          id: GlobalObjectKey(id),
      };

      Future<void> pump(List<String> ids) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                controller: controller,
                itemCount: ids.length,
                itemBuilder: (context, index) => KeyedSubtree(
                  key: keys[ids[index]],
                  child: SizedBox(
                    height: 60 + (index % 3) * 20,
                    child: Text(ids[index]),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(before);
      controller.jumpTo(500);
      await tester.pumpAndSettle();
      final eventAtTop = keys.entries
          .where((e) => e.value.currentContext != null)
          .map((e) => e.key)
          .first;

      final after = <String>[
        for (var i = 0; i < 5; i++) 'evt-new-$i',
        ...before,
      ];
      await pump(after);
      controller.jumpTo(500); // the naive restore
      await tester.pumpAndSettle();

      final nowAtTop = keys.entries
          .where((e) => e.value.currentContext != null)
          .map((e) => e.key)
          .first;
      expect(nowAtTop, isNot(eventAtTop),
          reason: 'if a raw offset DID land on the same event after five rows '
              'were prepended, the identity anchor would be pure overhead and '
              'should be deleted');
    });
  });
}
