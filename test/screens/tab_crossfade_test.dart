// Source contract for the tab fade-through.
//
// Convention in this repo: screen-level guarantees are asserted at the source
// (see countdown_live_region_test.dart). MainNavigation cannot be pumped
// without a configured ServiceLocator, SharedPreferences and the map stack.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/main_navigation.dart').readAsStringSync();
  });

  group('page state survives the transition', () {
    test('IndexedStack is kept, not replaced by a PageView or a switcher', () {
      expect(
        source,
        contains('IndexedStack('),
        reason:
            'Every page must stay in the tree; rebuilding them on tab change '
            'would reload the map and drop scroll positions.',
      );
      expect(
        source.contains('PageView('),
        isFalse,
        reason: 'A slide implies a spatial relationship these tabs do not have.',
      );
    });

    test('the map keeps its index-driven active contract', () {
      expect(source, contains('MapPage(isActive: _selectedIndex == 1)'));
    });
  });

  group('the crossfade swaps at the trough', () {
    test('the index changes at the midpoint, not on tap', () {
      expect(source, contains('_pendingIndex'));
      expect(
        source,
        contains('_tabFadeController.value < 0.5'),
        reason:
            'Swapping on tap would show the old page dissolving into the new '
            'one instead of a clean fade-through.',
      );
    });

    test('the fade runs on the shared scale', () {
      expect(source, contains('duration: Motion.base'));
      expect(source, contains('curve: Motion.exit'));
      expect(source, contains('curve: Motion.enter'));
    });

    test('a second tap during the transition is ignored', () {
      expect(
        source,
        contains('_pendingIndex != null'),
        reason: 'Re-entrancy would leave the index and the fade out of sync.',
      );
    });
  });

  group('reduce-motion and haptics', () {
    test('reduce-motion gets the instant swap', () {
      expect(source, contains('ReducedMotionPolicy.isReduced(context)'));
    });

    test('the tap haptic fires regardless of motion preference', () {
      final selectTab = source.substring(source.indexOf('void _selectTab('));
      final haptic = selectTab.indexOf('HapticFeedback.lightImpact()');
      final reduceCheck = selectTab.indexOf('ReducedMotionPolicy.isReduced');

      expect(haptic, isNot(-1));
      expect(reduceCheck, isNot(-1));
      expect(
        haptic < reduceCheck,
        isTrue,
        reason: 'Suppressing motion must not suppress the felt channel.',
      );
    });
  });

  group('lifecycle', () {
    test('the controller and its listener are released', () {
      expect(source, contains('_tabFadeController.removeListener('));
      expect(source, contains('_tabFadeController.dispose()'));
    });
  });
}
