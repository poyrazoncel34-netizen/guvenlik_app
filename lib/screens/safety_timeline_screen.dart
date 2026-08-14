// ============================================================================
// GÜVENLİK ZAMAN ÇİZELGESİ (SAFETY TIMELINE)
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../core/services/activity_service.dart';
import '../domain/models/activity_event.dart';
import '../core/widgets/escape_dismissible.dart';

class SafetyTimelineScreen extends StatefulWidget {
  const SafetyTimelineScreen({super.key});

  @override
  State<SafetyTimelineScreen> createState() => _SafetyTimelineScreenState();
}

class _SafetyTimelineScreenState extends State<SafetyTimelineScreen> {
  static const String _storageKey = 'safety_timeline_notes';
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _planController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _planController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    final notes = raw
        .map((e) {
          try {
            return jsonDecode(e) as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((e) => e.isNotEmpty)
        .map((e) => {...e, '_kind': 'note'})
        .toList();

    // Merge with real safety activity events (panic, fake call, siren,
    // safe walk, check-in, etc.) so the paid Safety History reflects what
    // actually happened, not just user notes.
    final activity = await ActivityService.getEvents();
    final activityEntries = activity.map(
      (e) => {
        'id': e.id,
        '_kind': 'activity',
        '_activityType': e.type.name,
        'destination': e.title,
        'plan': '',
        'notes': e.description,
        'timestamp': e.timestamp.toIso8601String(),
      },
    );

    final entries = [...notes, ...activityEntries];
    entries.sort((a, b) {
      final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
      final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    if (mounted) {
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    }
  }

  Future<void> _addEntry() async {
    final destination = _destinationController.text.trim();
    final plan = _planController.text.trim();
    final notes = _notesController.text.trim();

    if (destination.isEmpty && plan.isEmpty && notes.isEmpty) return;

    final entry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'destination': destination,
      'plan': plan,
      'notes': notes,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    raw.insert(0, jsonEncode(entry));
    if (raw.length > 50) raw.removeRange(50, raw.length);
    await prefs.setStringList(_storageKey, raw);

    ActivityService.logEvent(
      type: ActivityType.timelineNote,
      title: "timeline_note_added".tr(),
      description: destination.isNotEmpty
          ? "timeline_note_destination_desc".tr(
              namedArgs: {'destination': destination},
            )
          : "timeline_note_general_desc".tr(),
    );

    _destinationController.clear();
    _planController.clear();
    _notesController.clear();

    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text("timeline_note_saved".tr())),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    await _loadEntries();
  }

  Future<void> _shareEntry(Map<String, dynamic> entry) async {
    final destination = entry['destination'] ?? '';
    final plan = entry['plan'] ?? '';
    final notes = entry['notes'] ?? '';

    final parts = <String>[];
    parts.add("timeline_share_header".tr());
    if (destination.isNotEmpty) {
      parts.add(
        "timeline_share_destination".tr(
          namedArgs: {'destination': destination},
        ),
      );
    }
    if (plan.isNotEmpty) {
      parts.add("timeline_share_plan".tr(namedArgs: {'plan': plan}));
    }
    if (notes.isNotEmpty) {
      parts.add("timeline_share_notes".tr(namedArgs: {'notes': notes}));
    }

    await SharePlus.instance.share(ShareParams(text: parts.join('\n')));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text("timeline_shared_ready".tr())),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// Deletes an entry from whichever store actually holds it.
  ///
  /// This list merges two stores: user notes in SharedPreferences and recorded
  /// safety events in sqflite. Deletion only ever touched the notes, so "Sil"
  /// on a recorded event silently did nothing -- the row reappeared on the very
  /// next reload. A delete action that leaves the data readable is not deletion
  /// under Silme Yonetmeligi Md. 8/1 ("hicbir sekilde erisilemez ve tekrar
  /// kullanilamaz hale getirilmesi"), and the app's own policy promises the
  /// KVKK Md. 11/f right. Both stores are cleared here.
  Future<void> _deleteEntry(String id, {String? kind}) async {
    if (id.isEmpty) return;
    if (kind == 'activity') {
      await ActivityService.deleteEvent(id);
      await _loadEntries();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    raw.removeWhere((e) {
      try {
        final map = jsonDecode(e) as Map<String, dynamic>;
        return map['id'] == id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_storageKey, raw);
    // A note also writes a mirrored activity row when it is created, so the
    // note's own id may exist in both stores. Clearing both keeps one delete
    // from leaving a duplicate behind.
    await ActivityService.deleteEvent(id);
    await _loadEntries();
  }

  void _showAddEntryDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => EscapeDismissible(
        child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "timeline_add_entry".tr(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "timeline_add_desc".tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _destinationController,
                  icon: Icons.location_on_rounded,
                  hint: "timeline_destination_hint".tr(),
                  label: "timeline_destination".tr(),
                  maxLength: 120,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _planController,
                  icon: Icons.event_note_rounded,
                  hint: "timeline_plan_hint".tr(),
                  label: "timeline_plan".tr(),
                  maxLines: 2,
                  maxLength: 500,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _notesController,
                  icon: Icons.notes_rounded,
                  hint: "timeline_notes_hint".tr(),
                  label: "timeline_notes".tr(),
                  maxLines: 3,
                  maxLength: 1000,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addEntry,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      "timeline_save".tr(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required String label,
    int maxLines = 1,
    required int maxLength,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        labelText: label,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.accent),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("timeline_title".tr()),
        backgroundColor: AppColors.surface,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showAddEntryDialog();
        },
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          "timeline_new_note".tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? _buildEmptyState()
          : _buildEntryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timeline_rounded,
                size: 48,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "timeline_empty".tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "timeline_empty_desc".tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryList() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _buildEntryCard(entry);
      },
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    final destination = entry['destination'] ?? '';
    final plan = entry['plan'] ?? '';
    final notes = entry['notes'] ?? '';
    final timestamp =
        DateTime.tryParse(entry['timestamp'] ?? '') ?? DateTime.now();
    final timeStr =
        "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";
    final dateStr =
        "${timestamp.day.toString().padLeft(2, '0')}.${timestamp.month.toString().padLeft(2, '0')}.${timestamp.year}";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            const BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.timeline_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.isNotEmpty
                            ? destination
                            : "timeline_general_note".tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$dateStr • $timeStr",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
                  ),
                  color: AppColors.cardBg,
                  onSelected: (value) {
                    if (value == 'share') _shareEntry(entry);
                    if (value == 'delete') {
                      _deleteEntry(
                        entry['id'] ?? '',
                        kind: entry['_kind'],
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.send_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "timeline_share".tr(),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.emergency,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "timeline_delete".tr(),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (plan.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.event_note_rounded,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.notes_rounded,
                      color: AppColors.info,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notes,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
