import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/design_tokens.dart';
import '../../core/services/notification_preferences_service.dart';

/// Per-category notification control (MP-23-010, MP-26-006) and per-category
/// delivery feedback (MP-11-014).
///
/// The app holds NO local copy of these switches. A local toggle that read ON
/// while Android's own permission was denied is how this app once promised
/// alerts it could not deliver, and that lesson is already recorded on the
/// settings row this screen sits behind. So each row shows what the PLATFORM
/// currently reports and links to the platform's own screen for that channel.
///
/// The one place it is opinionated: a safety-critical category the user has
/// muted is shown as a warning with its consequence named, not as a tidy grey
/// toggle. "Emergency alerts: off" and "Vibration: off" must not look alike in
/// an app whose whole purpose is the first one.
class NotificationCategoriesScreen extends StatefulWidget {
  const NotificationCategoriesScreen({super.key, this.service});

  final NotificationPreferencesService? service;

  @override
  State<NotificationCategoriesScreen> createState() =>
      _NotificationCategoriesScreenState();
}

class _NotificationCategoriesScreenState
    extends State<NotificationCategoriesScreen>
    with WidgetsBindingObserver {
  late final NotificationPreferencesService _service =
      widget.service ?? NotificationPreferencesService.instance;

  List<NotificationCategoryState>? _states;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Re-read on resume: the user leaves for Android settings and comes back,
    // and a screen still showing the pre-change answer would be the same
    // "second disagreeing copy" defect in slow motion.
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final states = await _service.readAll();
      if (!mounted) return;
      setState(() {
        _states = states;
        _error = null;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      // A read failure must not render as "everything is fine".
      setState(() {
        _states = null;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final states = _states;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('notification_categories_title'.tr()),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            Text(
              'notification_categories_intro'.tr(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: TypeScale.bodyLarge,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            if (_error != null)
              _banner(
                icon: Icons.error_outline_rounded,
                color: AppColors.emergency,
                title: 'notification_categories_read_failed'.tr(),
                body: 'notification_categories_read_failed_body'.tr(),
              )
            else if (states == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              for (final state in states) ...[
                _categoryRow(state),
                const SizedBox(height: Spacing.sm),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _banner({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(Spacing.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: IconSizes.action),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: TypeScale.bodyLarge,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Spacing.xxs),
              Text(
                body,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: TypeScale.body,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _categoryRow(NotificationCategoryState state) {
    final delivered = state.willBeDelivered;
    final warn = state.isSilencedSafetySurface;
    final statusKey = delivered
        ? 'notification_status_delivered'
        : (state.appLevelEnabled
              ? 'notification_status_channel_muted'
              : 'notification_status_app_blocked');
    final color = warn
        ? AppColors.emergency
        : (delivered ? AppColors.success : AppColors.warning);

    return Semantics(
      button: true,
      label:
          '${state.category.titleKey.tr()}: ${statusKey.tr()}. '
          '${'notification_categories_open_settings'.tr()}',
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(Radii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: () => _service.openSettingsFor(state.category),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  delivered
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: color,
                  size: IconSizes.dialog,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.category.titleKey.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: TypeScale.subtitle,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        state.category.descriptionKey.tr(),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: TypeScale.body,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        statusKey.tr(),
                        style: TextStyle(
                          color: color,
                          fontSize: TypeScale.body,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (warn) ...[
                        const SizedBox(height: Spacing.xxs),
                        Text(
                          'notification_status_safety_warning'.tr(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: TypeScale.body,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.white38,
                  size: IconSizes.dense,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
