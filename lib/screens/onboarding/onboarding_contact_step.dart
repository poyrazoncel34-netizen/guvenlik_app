// ============================================================================
// ONBOARDING - ACIL KISI ADIMI
// ============================================================================
// Onboarding'in gecilemez son adimi. Kisi eklenmeden onboarding tamamlanamaz;
// karar mantigi [OnboardingContactGateService] icinde, bu widget yalnizca onu
// surer ve durumunu ust ekrana bildirir.
// ============================================================================

import '../../core/design_tokens.dart';
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/services/native_contact_picker_service.dart';
import '../../core/services/onboarding_contact_gate_service.dart';
import '../../core/utils/emergency_number_validator.dart';
import '../../widgets/emergency_contact_consent_dialog.dart';

const int _nameInputLimit = 60;
const int _phoneInputLimit = 32;

class OnboardingContactStep extends StatefulWidget {
  const OnboardingContactStep({super.key, required this.onGateChanged});

  /// Fires with true once a callable primary contact exists, false when it does
  /// not. The onboarding screen uses this to enable its completion button.
  final ValueChanged<bool> onGateChanged;

  @override
  State<OnboardingContactStep> createState() =>
      _OnboardingContactStepState();
}

class _OnboardingContactStepState extends State<OnboardingContactStep>
    with WidgetsBindingObserver, RestorationMixin {
  /// RESTORABLE ON PURPOSE.
  ///
  /// Android can kill this process while the user is mid-typing -- an incoming
  /// call, a camera launch, low memory, or the developer option "Don't keep
  /// activities" is enough. Before restoration the app came back with two empty
  /// fields, and this step is the ONLY gate that can complete onboarding: a
  /// user who loses their half-entered contact here can end up with no panic
  /// flow at all. That is the IR-01 failure reached by a different road, so it
  /// is treated as a defect rather than as a documented limitation.
  ///
  /// A contact name and phone number are ordinary user-entered form values, not
  /// authentication material -- the same two strings are about to be written to
  /// secure storage anyway. PIN entry is a different class and is deliberately
  /// NOT restorable; `test/state_restoration_policy_test.dart` fails if any PIN
  /// surface ever becomes restorable.
  final RestorableTextEditingController _nameController =
      RestorableTextEditingController();
  final RestorableTextEditingController _phoneController =
      RestorableTextEditingController();

  /// The phone verdict is derived from the phone text, so it travels with it.
  /// Restoring the text without it would redraw a form that looks valid and is
  /// not.
  final RestorableStringN _restoredPhoneErrorKey = RestorableStringN(null);

  @override
  String? get restorationId => 'onboarding_contact_step';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_nameController, 'contact_name_draft');
    registerForRestoration(_phoneController, 'contact_phone_draft');
    registerForRestoration(_restoredPhoneErrorKey, 'contact_phone_error');
    _phoneErrorKey = _restoredPhoneErrorKey.value;
  }

  /// Single writer for the field, so the restorable copy can never drift from
  /// the one the build method reads.
  void _setPhoneErrorKey(String? key) {
    _phoneErrorKey = key;
    _restoredPhoneErrorKey.value = key;
  }

  /// The soft keyboard resizes this step (Scaffold.resizeToAvoidBottomInset),
  /// which leaves "save contact" -- the only control that can complete
  /// onboarding -- below the fold. Flutter scrolls the FOCUSED field into view
  /// automatically, but not the action beneath it, so the step does that itself.
  ///
  /// The reveal is driven by the IME INSET, not by the focus event. An earlier
  /// attempt hung a single `addPostFrameCallback` off focus; that fires ~16ms
  /// later while the Android IME animates in over ~200-300ms, so it measured a
  /// viewport that had not shrunk yet and was a silent no-op. An independent
  /// reviewer reproduced the original defect against that build.
  ///
  /// Note the trap that makes this non-obvious: `Scaffold.resizeToAvoidBottomInset`
  /// defaults to true and CONSUMES the bottom inset, so `MediaQuery.viewInsetsOf`
  /// inside the body reads 0 no matter what the keyboard is doing. The only
  /// inset signal that survives into the body is the raw FlutterView's, observed
  /// through the FlutterView (see [_imeInset]).
  final FocusNode _phoneFocusNode = FocusNode();
  final GlobalKey _saveButtonKey = GlobalKey();

  /// Last observed raw view inset, in logical pixels.
  double _lastViewInsetBottom = 0;

  /// Fires the settled reveal once the IME stops moving. Longer than one frame
  /// and shorter than a user would notice.
  static const Duration _imeSettleDelay = Duration(milliseconds: 180);
  Timer? _settleTimer;

  bool _loading = true;
  bool _saving = false;
  bool _hasContact = false;
  bool _needsConsent = false;
  String? _phoneErrorKey;
  String? _failureKey;
  String _savedName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _phoneFocusNode.addListener(_revealSaveActionOnFocus);
    _refresh();
  }

  /// The step had no `dispose` at all: the lifecycle observer, the focus node
  /// and its listener all outlived the widget. Onboarding is entered once, so
  /// it never showed up as a visible leak -- but a StatefulWidget that
  /// registers an observer and never removes it is a real one, and the settle
  /// timer below would fire into a disposed State.
  @override
  void dispose() {
    _settleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _phoneFocusNode.removeListener(_revealSaveActionOnFocus);
    _phoneFocusNode.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _restoredPhoneErrorKey.dispose();
    super.dispose();
  }

  /// Live IME height in logical pixels.
  ///
  /// Read from the FlutterView, NOT from `MediaQuery.viewInsetsOf(context)`:
  /// `Scaffold.resizeToAvoidBottomInset` defaults to true and CONSUMES the
  /// bottom inset, so the MediaQuery visible inside the body always reports 0
  /// no matter what the keyboard is doing. That trap made two earlier attempts
  /// at this fix silently inert.
  double get _imeInset {
    final view = View.maybeOf(context);
    if (view == null) return 0;
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  /// Re-issued whenever inherited state changes, which includes the frames of
  /// the IME animation. Driving the reveal from layout state rather than from a
  /// one-shot post-frame callback is the whole point: a single callback fires
  /// ~16ms after focus, while the Android IME animates over ~200-300ms, so it
  /// measured a viewport that had not shrunk yet and did nothing.
  /// `didChangeMetrics` is the only callback that fires on IME inset changes.
  /// `didChangeDependencies` does NOT: `View.of` rebuilds dependents only when
  /// the view OBJECT changes, and the MediaQuery inside a Scaffold body has the
  /// bottom inset stripped by resizeToAvoidBottomInset.
  @override
  void didChangeMetrics() {
    // Rebuild so build() re-reads _imeInset for the reserved bottom padding.
    if (_onInsetChanged() && mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Deliberately no setState here: didChangeDependencies already runs as part
    // of a build pass, and calling setState from it throws
    // "setState() called during build".
    _onInsetChanged();
  }

  /// Returns true when the inset actually moved.
  bool _onInsetChanged() {
    if (!mounted) return false;
    final inset = _imeInset;
    if ((inset - _lastViewInsetBottom).abs() < 1.0) return false;
    final growing = inset > _lastViewInsetBottom;
    _lastViewInsetBottom = inset;
    if (growing && inset > 0 && _phoneFocusNode.hasFocus) {
      _scheduleRevealSaveAction();
    }
    return true;
  }

  void _revealSaveActionOnFocus() {
    if (!_phoneFocusNode.hasFocus) return;
    _scheduleRevealSaveAction();
  }

  void _scheduleRevealSaveAction() {
    _revealNow();
    // ...and again once the IME has STOPPED moving.
    //
    // Device evidence (arm64 API 36, logcat probe): the Android IME animates
    // over ~500ms and `didChangeMetrics` fires ~15 times during it. Reacting to
    // each frame issues a 200ms `ensureVisible` that the next frame immediately
    // supersedes, and every one of them is computed against a viewport that is
    // still shrinking. The measured result was a scroll that stopped at offset
    // 107 when 249 was needed -- the save action stayed below the keyboard and
    // the user still had to find the scroll gesture, which IS the IR-01 defect.
    // The standalone widget harness could not see this: it steps the inset in
    // four discrete jumps and then pumps, so its last reveal always lands on a
    // settled layout.
    //
    // The per-frame call is kept because it tracks the keyboard as it rises;
    // this timer is what guarantees the FINAL layout also gets a reveal.
    _settleTimer?.cancel();
    _settleTimer = Timer(_imeSettleDelay, _revealNow);
  }

  /// One reveal against whatever the layout is at the next frame.
  void _revealNow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _saveButtonKey.currentContext;
      if (target == null) return;
      // alignment 1.0 bottom-aligns the action in the shrunken viewport, the
      // minimum scroll that clears the keyboard.
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: 1.0,
      );
    });
  }

  Future<void> _refresh() async {
    final hasContact = await OnboardingContactGateService.hasCallableContact();
    final needsConsent = OnboardingContactGateService.needsContactDataConsent();
    var savedName = '';
    if (hasContact) {
      savedName = await OnboardingContactGateService.primaryContactName() ?? '';
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasContact = hasContact;
      _needsConsent = needsConsent;
      _savedName = savedName;
    });
    widget.onGateChanged(hasContact);
  }

  Future<void> _grantConsent() async {
    final locale = context.locale.languageCode;
    final granted = await OnboardingContactGateService.grantContactDataConsent(
      locale: locale,
    );
    if (!mounted) return;
    setState(() {
      _needsConsent = !granted;
      _failureKey = granted ? null : 'onboarding_contact_consent_failed';
    });
  }

  Future<void> _pickFromDevice() async {
    unawaited(HapticFeedback.selectionClick());
    final result = await NativeContactPickerService.pickPhoneContact();
    if (!mounted) return;
    if (result.isUnavailable) {
      setState(() => _failureKey = 'onboarding_contact_picker_failed');
      return;
    }
    final picked = result.contact;
    if (picked == null) return; // cancelled

    setState(() {
      _failureKey = null;
      _nameController.value.text = picked.name;
      _phoneController.value.text = picked.number;
      _setPhoneErrorKey(
        OnboardingContactGateService.phoneErrorKey(picked.number),
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final phone = _phoneController.value.text;
    final errorKey = OnboardingContactGateService.phoneErrorKey(phone);
    if (errorKey != null) {
      setState(() => _setPhoneErrorKey(errorKey));
      return;
    }

    final name = _nameController.value.text.trim();
    final consentGiven = await EmergencyContactConsentDialog.show(
      context: context,
      contactName: name.isEmpty ? 'contacts_unknown'.tr() : name,
    );
    if (!mounted || !consentGiven) return;

    setState(() {
      _saving = true;
      _failureKey = null;
    });
    final outcome = await OnboardingContactGateService.savePrimaryContact(
      name: name,
      phone: phone,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    switch (outcome) {
      case OnboardingContactSaveOutcome.saved:
        unawaited(HapticFeedback.mediumImpact());
        await _refresh();
      case OnboardingContactSaveOutcome.invalidPhone:
        setState(
          () => _setPhoneErrorKey('onboarding_contact_invalid_phone'),
        );
      case OnboardingContactSaveOutcome.storageFailed:
        setState(() => _failureKey = 'onboarding_contact_save_failed');
    }
  }

  void _startOver() {
    setState(() {
      _hasContact = false;
      _setPhoneErrorKey(null);
      _failureKey = null;
    });
    widget.onGateChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final failureKey = _failureKey;
    return Semantics(
      label: 'semantics_onboarding_contact_step'.tr(),
      child: SingleChildScrollView(
        // Reserve the IME's height at the bottom so the scroll extent always
        // covers the keyboard. Without this the content simply ends above the
        // IME and the save action cannot be scrolled clear of it at all.
        padding: EdgeInsets.only(left: 32, right: 32, bottom: _imeInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 24),
            if (_hasContact) _savedCard() else ..._form(),
            // Local copy so the null check promotes: a field cannot, and `!` on
            // a field is exactly the pattern this repo avoids.
            if (failureKey != null) ...[
              const SizedBox(height: 16),
              _noticeCard(
                icon: Icons.error_outline_rounded,
                color: AppColors.warning,
                text: failureKey.tr(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: (_hasContact ? AppColors.success : AppColors.primary)
                .withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _hasContact
                ? Icons.how_to_reg_rounded
                : Icons.contact_phone_rounded,
            size: IconSizes.illustration,
            color: _hasContact ? AppColors.success : AppColors.primary,
          ),
        ),
        const SizedBox(height: 20),
        // Step heading, so heading navigation has a target (MP-12-017).
        Semantics(
          header: true,
          child: Text(
            'onboarding_contact_title'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'onboarding_contact_body'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  List<Widget> _form() {
    return <Widget>[
      if (_needsConsent) ...[
        _consentCard(),
        const SizedBox(height: 16),
      ],
      TextField(
        controller: _nameController.value,
        enabled: !_needsConsent && !_saving,
        maxLength: _nameInputLimit,
        textInputAction: TextInputAction.next,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: _fieldDecoration(
          label: 'onboarding_contact_name_label'.tr(),
          icon: Icons.person_outline_rounded,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _phoneController.value,
        focusNode: _phoneFocusNode,
        enabled: !_needsConsent && !_saving,
        maxLength: _phoneInputLimit,
        keyboardType: TextInputType.phone,
        style: const TextStyle(color: AppColors.textPrimary),
        onChanged: (value) {
          final next = value.trim().isEmpty
              ? null
              : OnboardingContactGateService.phoneErrorKey(value);
          if (next != _phoneErrorKey) {
            setState(() => _setPhoneErrorKey(next));
          }
        },
        decoration: _fieldDecoration(
          label: 'onboarding_contact_phone_label'.tr(),
          icon: Icons.phone_outlined,
          errorText: _phoneErrorKey?.tr(),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'onboarding_contact_phone_hint'.tr(
          namedArgs: {
            'min': '${EmergencyNumberValidator.minUserContactDigits}',
            'max': '${EmergencyNumberValidator.maxUserContactDigits}',
          },
        ),
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _needsConsent || _saving ? null : _pickFromDevice,
        icon: const Icon(Icons.contacts_rounded, size: IconSizes.action),
        label: Text('onboarding_contact_pick_btn'.tr()),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      const SizedBox(height: 10),
      ElevatedButton.icon(
        key: _saveButtonKey,
        onPressed: _needsConsent || _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_rounded, size: IconSizes.action),
        label: Text('onboarding_contact_save_btn'.tr()),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ];
  }

  Widget _savedCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _noticeCard(
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
          text: _savedName.isEmpty
              ? 'onboarding_contact_saved_desc_generic'.tr()
              : 'onboarding_contact_saved_desc'.tr(
                  namedArgs: {'name': _savedName},
                ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _startOver,
          child: Text(
            'onboarding_contact_change_btn'.tr(),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _consentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'onboarding_contact_consent_title'.tr(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'onboarding_contact_consent_body'.tr(),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: _grantConsent,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.background,
              ),
              child: Text('onboarding_contact_consent_grant_btn'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noticeCard({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: IconSizes.emphasis),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      counterText: '',
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: IconSizes.action),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.cardBg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.emergency),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.emergency),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
    );
  }
}
