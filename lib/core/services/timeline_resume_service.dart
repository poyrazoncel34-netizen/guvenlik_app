import 'package:shared_preferences/shared_preferences.dart';

import 'scroll_restoration.dart';

/// Resumes an interrupted timeline only after [MainNavigation] exists, so
/// Android process restoration cannot put user data above the local PIN gate.
abstract final class TimelineResumeService {
  static const String _pendingKey = 'timeline_resume_pending';
  static const String _anchorKey = 'timeline_resume_anchor';

  static Future<ScrollAnchor?> begin() async {
    final preferences = await SharedPreferences.getInstance();
    final anchor = ScrollAnchor.decode(preferences.getString(_anchorKey));
    await preferences.setBool(_pendingKey, true);
    return anchor;
  }

  static Future<void> save(ScrollAnchor? anchor) async {
    if (anchor == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_anchorKey, anchor.encode());
  }

  static Future<bool> consumePending() async {
    final preferences = await SharedPreferences.getInstance();
    final pending = preferences.getBool(_pendingKey) ?? false;
    if (pending) await preferences.setBool(_pendingKey, false);
    return pending;
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingKey);
    await preferences.remove(_anchorKey);
  }
}
