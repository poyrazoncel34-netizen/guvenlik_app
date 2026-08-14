import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Where a scrolling list was, expressed so it survives the list CHANGING.
///
/// Flutter's built-in `ScrollView.restorationId` restores a raw pixel offset.
/// That is exactly right for a list whose content is fixed — the settings page
/// uses it. It is wrong for the safety timeline: `activity_events` grows, new
/// rows are PREPENDED (the query orders by timestamp DESC), and a process death
/// while a check-in is running can easily add rows before the user returns. A
/// restored pixel offset then lands on a different event than the one they were
/// reading, which is worse than not restoring at all — it looks like the app
/// scrolled somewhere on its own.
///
/// So the anchor carries the IDENTITY of the item that was at the top, and the
/// offset only as a fallback for when that item no longer exists.
@immutable
class ScrollAnchor {
  const ScrollAnchor({
    required this.offset,
    this.topItemId,
    this.topItemIndex,
  });

  /// Raw pixel offset at the moment of capture. Fallback only.
  final double offset;

  /// Identity of the first item whose leading edge was at or below the
  /// viewport top. Null when the list was empty or nothing could be resolved.
  final String? topItemId;

  /// The anchored item's index at capture time.
  ///
  /// Needed because a lazy list does NOT build off-screen items, so
  /// `GlobalObjectKey.currentContext` is null for the very item the anchor
  /// names -- discovered by driving a real `ListView.builder` rather than by
  /// reading the API. The index difference between capture and restore gives a
  /// first estimate good enough to BUILD the item; real geometry then corrects
  /// it exactly. Estimate-then-correct, never estimate-and-hope.
  final int? topItemIndex;

  bool get isAtTop => offset <= 0 && topItemId == null;

  String encode() => jsonEncode(<String, Object?>{
    'o': offset,
    if (topItemId != null) 'i': topItemId,
    if (topItemIndex != null) 'n': topItemIndex,
  });

  static ScrollAnchor? decode(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final offset = decoded['o'];
      if (offset is! num) return null;
      final id = decoded['i'];
      final index = decoded['n'];
      return ScrollAnchor(
        offset: offset.toDouble(),
        topItemId: id is String && id.isNotEmpty ? id : null,
        topItemIndex: index is int && index >= 0 ? index : null,
      );
    } on FormatException {
      // Restoration data is platform-supplied and can be anything. A malformed
      // anchor must mean "start at the top", never an exception on resume.
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ScrollAnchor &&
      other.offset == offset &&
      other.topItemId == topItemId &&
      other.topItemIndex == topItemIndex;

  @override
  int get hashCode => Object.hash(offset, topItemId, topItemIndex);

  @override
  String toString() => 'ScrollAnchor($offset, $topItemId, #$topItemIndex)';
}

/// A [ScrollAnchor] that survives process death through the restoration bucket.
class RestorableScrollAnchor extends RestorableValue<ScrollAnchor?> {
  /// Whether this property is attached to a restoration bucket.
  ///
  /// `RestorableValue.value=` asserts registration, and registration happens in
  /// `restoreState` -- which the mixin runs from `didChangeDependencies`, AFTER
  /// `initState` where a scroll listener is attached. Exposed here (rather than
  /// callers touching the protected member) so the owner can degrade instead of
  /// throwing on a scroll that arrives in that window, or in any tree with no
  /// restoration scope at all.
  bool get isAttached => isRegistered;

  @override
  ScrollAnchor? createDefaultValue() => null;

  @override
  void didUpdateValue(ScrollAnchor? oldValue) {
    if (oldValue != value) notifyListeners();
  }

  @override
  ScrollAnchor? fromPrimitives(Object? data) => ScrollAnchor.decode(data);

  @override
  Object? toPrimitives() => value?.encode();
}

/// Resolves an anchor back into something the list can act on.
abstract final class ScrollRestorationPolicy {
  /// How far from the recorded offset a fallback jump may land before it is
  /// abandoned. Beyond this the list has changed so much that jumping would be
  /// arbitrary, and the top is the honest answer.
  static const double fallbackTolerance = 4.0;

  /// The item to align to the viewport top, or null when the anchor's item is
  /// gone (or there never was one).
  static String? resolveTarget(ScrollAnchor? anchor, List<String> itemIds) {
    final id = anchor?.topItemId;
    if (id == null) return null;
    return itemIds.contains(id) ? id : null;
  }

  /// The offset to jump to when no item identity could be resolved.
  ///
  /// Clamped to the list's real extent: a restored offset from a longer list
  /// would otherwise throw or snap, and either reads as a bug on resume.
  static double fallbackOffset(ScrollAnchor? anchor, double maxScrollExtent) {
    final offset = anchor?.offset ?? 0;
    if (offset <= 0 || maxScrollExtent <= 0) return 0;
    return offset > maxScrollExtent ? maxScrollExtent : offset;
  }

  /// First-phase offset: where the anchored item probably is now.
  ///
  /// The list changed by `newIndex - topItemIndex` rows above the anchor, and
  /// the mean extent of the CURRENT list is the best available estimate for
  /// what those rows are worth. Deliberately an estimate and labelled one: it
  /// exists to get the target item BUILT so real geometry can take over.
  static double estimateOffset({
    required ScrollAnchor anchor,
    required int newIndex,
    required int itemCount,
    required double maxScrollExtent,
  }) {
    final oldIndex = anchor.topItemIndex;
    if (oldIndex == null || itemCount <= 0 || maxScrollExtent <= 0) {
      return fallbackOffset(anchor, maxScrollExtent);
    }
    final meanExtent = maxScrollExtent / itemCount;
    final estimate = anchor.offset + (newIndex - oldIndex) * meanExtent;
    if (estimate <= 0) return 0;
    return estimate > maxScrollExtent ? maxScrollExtent : estimate;
  }

  /// Builds the anchor to persist from a live scroll position.
  ///
  /// [visibleItemIdAt] maps a scroll offset to the identity of the item at the
  /// viewport top; it returns null when the caller cannot answer, and the
  /// anchor then degrades to the raw offset rather than lying about identity.
  static ScrollAnchor capture({
    required double offset,
    String? Function(double offset)? visibleItemIdAt,
  }) => ScrollAnchor(
    offset: offset,
    topItemId: visibleItemIdAt?.call(offset),
  );
}


/// Drives identity-anchored scroll restoration for one keyed list.
///
/// Owns the controller, the per-item keys and the anchor, so the screen using
/// it stays a screen. `SafetyTimelineScreen` is 700+ lines and sits under the
/// project's file-size ratchet; restoration mechanics living there would have
/// pushed it over, and this repo's own patterns file names screen-resident
/// logic as the anti-pattern being worked off.
class KeyedListScrollRestorer {
  KeyedListScrollRestorer();

  final RestorableScrollAnchor anchor = RestorableScrollAnchor();
  final ScrollController controller = ScrollController();
  final Map<String, GlobalObjectKey> _keys = <String, GlobalObjectKey>{};

  bool _applied = false;

  /// The anchor as this object knows it, independent of registration.
  ///
  /// `RestorableValue.value=` ASSERTS `isRegistered`, and registration happens
  /// in `restoreState`, which the mixin runs from `didChangeDependencies` --
  /// after `initState`, where the scroll listener is attached. A scroll before
  /// that point, or any use of this list outside a restoration scope at all,
  /// would throw on every notification. Found by driving a real scrolling list
  /// in the test rather than by reading the API.
  ///
  /// So the value lives here and is MIRRORED into the restorable only while it
  /// is registered: unregistered, restoration simply does not happen, which is
  /// the correct degradation.
  ScrollAnchor? _value;

  ScrollAnchor? get value => anchor.isAttached ? anchor.value : _value;

  set value(ScrollAnchor? next) {
    _value = next;
    if (anchor.isAttached) anchor.value = next;
  }

  void attach() => controller.addListener(_capture);

  void dispose() {
    controller.removeListener(_capture);
    controller.dispose();
    anchor.dispose();
  }

  /// A stable key for [id], so `ensureVisible` can find the item later.
  GlobalObjectKey keyFor(String id) =>
      _keys.putIfAbsent(id, () => GlobalObjectKey(id));

  /// Offset of [id]'s leading edge inside the scrollable, or null.
  ///
  /// Uses the viewport's own `getOffsetToReveal` rather than index x extent:
  /// the cards differ in height, so an assumed uniform extent would be a guess
  /// dressed as geometry.
  double? offsetOf(String id) {
    final context = _keys[id]?.currentContext;
    final box = context?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return null;
    return viewport.getOffsetToReveal(box, 0).offset;
  }

  /// Identity of the first item whose leading edge is at or below the top.
  String? topVisibleId(List<String> orderedIds) {
    if (!controller.hasClients) return null;
    final top = controller.position.pixels;
    for (final id in orderedIds) {
      final offset = offsetOf(id);
      if (offset != null && offset >= top - 0.5) return id;
    }
    return null;
  }

  void _capture() {
    if (!controller.hasClients) return;
    final id = _lastOrderedIds.isEmpty ? null : topVisibleId(_lastOrderedIds);
    value = ScrollAnchor(
      offset: controller.position.pixels,
      topItemId: id,
      topItemIndex: id == null ? null : _lastOrderedIds.indexOf(id),
    );
  }

  List<String> _lastOrderedIds = const <String>[];

  /// Called by the screen whenever the list contents change.
  void setItems(List<String> orderedIds) => _lastOrderedIds = orderedIds;

  /// Applies the restored anchor once, after the items exist.
  ///
  /// Identity first: if the anchored item is still present, align IT to the
  /// top, which stays correct however many rows were prepended while the app
  /// was dead. Only when it is gone is the raw offset used, clamped to the
  /// list's real extent so a longer previous list cannot snap or throw.
  void applyOnce(List<String> orderedIds) {
    if (_applied) return;
    final anchorValue = value;
    if (anchorValue == null || anchorValue.isAtTop) {
      _applied = true;
      return;
    }
    _applied = true;
    setItems(orderedIds);
    _afterFrame(() => _restore(anchorValue, orderedIds));
  }

  /// Runs [action] after the next frame, and MAKES SURE there is one.
  ///
  /// `addPostFrameCallback` alone does not schedule a frame, so when nothing
  /// else is dirty the callback simply never fires and the restore silently
  /// does nothing. That is exactly what happened the first time this was
  /// written, and the test caught it: the anchor was correct, the policy was
  /// correct, and the list stayed where it was.
  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Estimate, then correct.
  ///
  /// Phase 1 jumps to an offset estimated from how far the anchored item MOVED
  /// in the list, which is what forces a lazy `ListView.builder` to build it.
  /// Phase 2 reads that item's real geometry and aligns it exactly. Phase 1
  /// alone would be an assumption about uniform extents; phase 2 alone cannot
  /// run, because the item it needs has not been built yet.
  void _restore(ScrollAnchor anchor, List<String> orderedIds) {
    if (!controller.hasClients) return;
    final target = ScrollRestorationPolicy.resolveTarget(anchor, orderedIds);
    if (target == null) {
      controller.jumpTo(
        ScrollRestorationPolicy.fallbackOffset(
          anchor,
          controller.position.maxScrollExtent,
        ),
      );
      return;
    }

    controller.jumpTo(
      ScrollRestorationPolicy.estimateOffset(
        anchor: anchor,
        newIndex: orderedIds.indexOf(target),
        itemCount: orderedIds.length,
        maxScrollExtent: controller.position.maxScrollExtent,
      ),
    );

    _afterFrame(() {
      if (!controller.hasClients) return;
      final exact = offsetOf(target);
      if (exact == null) return; // the estimate is what the user gets
      controller.jumpTo(
        exact.clamp(0.0, controller.position.maxScrollExtent),
      );
    });
  }
}
