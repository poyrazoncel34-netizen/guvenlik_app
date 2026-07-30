// ============================================================================
// OEM ARKA PLAN IZIN SIHIRBAZI
// ============================================================================
// Uretici-ozel pil politikalarinin uygulamayi oldurmesi bu kategorideki sessiz
// basarisizligin bir numarali sebebi. Bu ekran kullaniciyi cihazina ozel ayar
// ekranlarina adim adim goturur.
//
// Karar mantigi [OemBackgroundGuideService] icinde: vendor eslemesi, adim
// verisi, intent calistirma ve kalici ilerleme. Bu dosya yalnizca sunum.
// ============================================================================

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/services/oem_background_guide_service.dart';

class OemBackgroundGuideScreen extends StatefulWidget {
  const OemBackgroundGuideScreen({super.key});

  @override
  State<OemBackgroundGuideScreen> createState() =>
      _OemBackgroundGuideScreenState();
}

class _OemBackgroundGuideScreenState extends State<OemBackgroundGuideScreen> {
  OemVendor? _vendor;
  List<OemGuideStep> _steps = const <OemGuideStep>[];
  Set<String> _completed = <String>{};

  /// Steps whose target screen turned out not to exist on this device. The body
  /// text stays as the instruction; the step is never a dead end.
  final Set<String> _unavailable = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final vendor = await OemBackgroundGuideService.detectVendor();
    final completed = await OemBackgroundGuideService.completedSteps(vendor);
    if (!mounted) return;
    setState(() {
      _vendor = vendor;
      _steps = OemBackgroundGuideService.stepsFor(vendor);
      _completed = completed;
    });
  }

  Future<void> _openStep(OemGuideStep step) async {
    unawaited(HapticFeedback.selectionClick());
    final outcome = await OemBackgroundGuideService.openStep(step);
    if (!mounted) return;
    setState(() {
      if (outcome == OemStepLaunch.noIntent) {
        _unavailable.add(step.id);
      } else {
        _unavailable.remove(step.id);
      }
    });
  }

  Future<void> _markDone(OemGuideStep step) async {
    final vendor = _vendor;
    if (vendor == null) return;
    unawaited(HapticFeedback.mediumImpact());
    await OemBackgroundGuideService.markStepCompleted(vendor, stepId: step.id);
    if (!mounted) return;
    setState(() => _completed = <String>{..._completed, step.id});
  }

  Future<void> _finish() async {
    final vendor = _vendor;
    if (vendor != null) {
      await OemBackgroundGuideService.markGuideCompleted(vendor);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vendor = _vendor;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('oem_guide_title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: vendor == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _intro(vendor),
                        const SizedBox(height: 20),
                        for (var i = 0; i < _steps.length; i++) ...[
                          _stepCard(i, _steps[i]),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                  _footer(),
                ],
              ),
            ),
    );
  }

  Widget _intro(OemVendor vendor) {
    final done = _completed.length;
    final total = _steps.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'oem_guide_vendor_${vendor.name}'.tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'oem_guide_intro'.tr(),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'oem_guide_progress'.tr(
              namedArgs: {'done': '$done', 'total': '$total'},
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCard(int index, OemGuideStep step) {
    final isDone = _completed.contains(step.id);
    final isUnavailable = _unavailable.contains(step.id);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color:
                      (isDone ? AppColors.success : AppColors.primary)
                          .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: AppColors.success,
                        )
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.titleKey.tr(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            step.bodyKey.tr(),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (isUnavailable) ...[
            const SizedBox(height: 10),
            Text(
              'oem_guide_step_unavailable'.tr(),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.warning,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (step.hasTarget)
                OutlinedButton.icon(
                  onPressed: () => _openStep(step),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text('oem_guide_open_btn'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              if (!isDone)
                ElevatedButton.icon(
                  onPressed: () => _markDone(step),
                  icon: const Icon(Icons.done_rounded, size: 18),
                  label: Text('oem_guide_done_btn'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          Text(
            'oem_guide_no_guarantee'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _finish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'oem_guide_finish_btn'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
