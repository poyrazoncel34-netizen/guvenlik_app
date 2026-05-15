// ============================================================================
// KULLANIM SÖZLEŞMESİ EKRANI (EULA)
// KVKK uyumlu — scroll + checkbox + tarih kaydı
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/app_colors.dart';
import '../../constants/legal_texts.dart';
import '../../services/consent_manager.dart';
import '../../models/consent_record.dart';
import '../../core/di/service_locator.dart';

class TermsOfServiceScreen extends StatefulWidget {
  final bool isReadOnly;
  final VoidCallback? onAccepted;

  const TermsOfServiceScreen({
    super.key,
    this.isReadOnly = false,
    this.onAccepted,
  });

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
  bool _accepted = false;
  bool _hasScrolledToBottom = false;
  bool _loading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasScrolledToBottom &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100) {
      setState(() => _hasScrolledToBottom = true);
    }
  }

  bool get _isTurkish => context.locale.languageCode == 'tr';

  String get _termsText =>
      _isTurkish ? LegalTexts.termsOfServiceTr : LegalTexts.termsOfServiceEn;

  Future<void> _accept() async {
    if (!_accepted || _loading) return;
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();
    try {
      final cm = serviceLocator<ConsentManager>();
      await cm.grantConsent(
        ConsentRecord.typeTerms,
        locale: context.locale.languageCode,
      );
      if (mounted) widget.onAccepted?.call();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          widget.isReadOnly ? 'legal_tos_title'.tr() : 'legal_tos_title'.tr(),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: widget.isReadOnly
            ? IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        automaticallyImplyLeading: widget.isReadOnly,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          // Versiyon bilgisi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: AppColors.primary.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${'legal_version_prefix'.tr()} ${LegalTexts.termsVersion} — ${LegalTexts.lastUpdated}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Metin içeriği
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                _termsText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ),

          // Onay alanı (sadece readOnly değilse)
          if (!widget.isReadOnly)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_hasScrolledToBottom)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'legal_scroll_to_bottom'.tr(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _accepted = !_accepted);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _accepted
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _accepted
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _accepted,
                              onChanged: (v) =>
                                  setState(() => _accepted = v ?? false),
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'legal_tos_accept_label'.tr(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _accepted
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _accepted && !_loading ? _accept : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.3,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'legal_continue'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
