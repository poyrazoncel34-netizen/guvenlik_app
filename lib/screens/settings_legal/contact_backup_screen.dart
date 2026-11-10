// ============================================================================
// KİŞİ YEDEĞİ EKRANI
// Acil durum kişilerinin şifreli, kullanıcıda kalan yedeği (dışa/içe aktarma)
// ============================================================================

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_colors.dart';
import '../../core/design_tokens.dart';
import '../../core/services/contact_backup_service.dart';
import '../../core/services/local_logger_service.dart';
import '../../core/services/overlay_touch_guard.dart';
import '../../core/services/sensitive_temp_file_service.dart';
import '../../core/widgets/escape_dismissible.dart';
import '../../core/widgets/overlay_touch_shield.dart';
import '../../core/widgets/sensitive_action_pin_gate.dart';
import '../../presentation/providers/contacts_provider.dart';

class ContactBackupScreen extends StatefulWidget {
  const ContactBackupScreen({
    super.key,
    this.service = const ContactBackupService(),
  });

  final ContactBackupService service;

  @override
  State<ContactBackupScreen> createState() => _ContactBackupScreenState();
}

class _ContactBackupScreenState extends State<ContactBackupScreen>
    with OverlayTouchShield {
  // BLOCK, like DataExportScreen: export hands every contact to another app
  // and restore REPLACES the numbers a panic call dials. A tap-jacked restore
  // is the worse of the two.
  @override
  String get overlayGuardOwner => 'contact_backup';

  @override
  OverlayTouchPolicy get overlayGuardPolicy => OverlayTouchPolicy.block;

  bool _busy = false;

  /// Re-entrancy guard for the WHOLE flow, PIN gate and dialogs included.
  /// [_busy] only drives the spinner during the actual work; without this a
  /// double tap ran two PIN gates and two pickers, and the first flow's
  /// `finally` re-enabled the buttons while the second was still restoring.
  bool _inFlow = false;

  Future<void> _export() async {
    if (_inFlow) return;
    _inFlow = true;
    try {
      await _exportFlow();
    } finally {
      _inFlow = false;
    }
  }

  Future<void> _import() async {
    if (_inFlow) return;
    _inFlow = true;
    try {
      await _importFlow();
    } finally {
      _inFlow = false;
    }
  }

  Future<void> _exportFlow() async {
    if (!await SensitiveActionPinGate.ensure(context)) return;
    if (!mounted) return;
    final password = await _askPassword(confirm: true);
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    File? file;
    try {
      final bytes = await widget.service.exportCurrentContacts(password);
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
      file = File(
        '${dir.path}/${SensitiveTempFileService.contactBackupPrefix}$stamp.json',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'contact_backup_share_subject'.tr(),
          text: 'contact_backup_share_text'.tr(),
        ),
      );
    } on ContactBackupException catch (e) {
      _showError(_messageKey(e.failure));
    } on PlatformException {
      _showError('contact_backup_error_generic');
    } on FileSystemException {
      _showError('contact_backup_error_generic');
    } on Exception {
      // Picker, share sheet or isolate failures outside the expected set:
      // still a message, never a silent no-op.
      _showError('contact_backup_error_generic');
    } finally {
      await SensitiveTempFileService.delete(file);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFlow() async {
    if (!await SensitiveActionPinGate.ensure(context)) return;
    if (!mounted) return;
    try {
      final picked = await openFile();
      if (picked == null || !mounted) return;
      if (await picked.length() > ContactBackupService.maxFileBytes) {
        throw const ContactBackupException(ContactBackupFailure.tooLarge);
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final password = await _askPassword(confirm: false);
      if (password == null || !mounted) return;
      setState(() => _busy = true);
      final contacts = await widget.service.decode(bytes, password);
      if (!mounted) return;
      final confirmed = await _confirmReplace(contacts.length);
      if (!confirmed || !mounted) return;
      final count = await widget.service.restore(contacts);
      if (!mounted) return;
      await context.read<ContactsProvider>().reloadFromStorage();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'contact_backup_restore_success'.tr(namedArgs: {'count': '$count'}),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } on ContactBackupException catch (e) {
      if (e.failure == ContactBackupFailure.writeFailed) {
        await LocalLoggerService.instance.warningCode(
          LocalWarningCode.contactBackupRestoreWriteFailed,
        );
      }
      _showError(_messageKey(e.failure));
    } on PlatformException {
      _showError('contact_backup_error_generic');
    } on FileSystemException {
      _showError('contact_backup_error_generic');
    } on Exception {
      // Picker, share sheet or isolate failures outside the expected set:
      // still a message, never a silent no-op.
      _showError('contact_backup_error_generic');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _messageKey(ContactBackupFailure failure) {
    return switch (failure) {
      ContactBackupFailure.passwordTooShort =>
        'contact_backup_error_password_short',
      ContactBackupFailure.noContacts => 'contact_backup_error_no_contacts',
      ContactBackupFailure.tooLarge ||
      ContactBackupFailure.notABackup => 'contact_backup_error_not_backup',
      ContactBackupFailure.unsupportedVersion => 'contact_backup_error_version',
      ContactBackupFailure.wrongPasswordOrDamaged =>
        'contact_backup_error_wrong_password',
      ContactBackupFailure.invalidContent => 'contact_backup_error_invalid',
      ContactBackupFailure.writeFailed => 'contact_backup_error_write',
    };
  }

  void _showError(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(key.tr()),
        backgroundColor: AppColors.emergency,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<String?> _askPassword({required bool confirm}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BackupPasswordDialog(confirm: confirm),
    );
  }

  Future<bool> _confirmReplace(int count) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EscapeDismissible(
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'contact_backup_restore_confirm_title'.tr(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          content: Text(
            'contact_backup_restore_confirm_body'.tr(
              namedArgs: {'count': '$count'},
            ),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'cancel'.tr(),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('contact_backup_restore_confirm_button'.tr()),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'contact_backup_title'.tr(),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textSecondary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          // Telefon değişirse ne olur — açık bilgi
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.phonelink_erase_rounded,
                      color: AppColors.info,
                      size: IconSizes.action,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'contact_backup_info_title'.tr(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'contact_backup_info_body'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.info,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Güvenlik notu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'contact_backup_security_note'.tr(),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.warning,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 32),
          _actionButton(
            icon: Icons.share_rounded,
            labelKey: 'contact_backup_export_button',
            onPressed: _export,
          ),
          const SizedBox(height: 12),
          _actionButton(
            icon: Icons.restore_rounded,
            labelKey: 'contact_backup_import_button',
            onPressed: _import,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String labelKey,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _busy ? null : onPressed,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(
          _busy ? 'contact_backup_working'.tr() : labelKey.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

/// Asks for the backup password. With [confirm] it also asks for it twice,
/// because a typo at export time makes the file unopenable forever.
class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog({required this.confirm});

  final bool confirm;

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _password.text;
    if (value.length < ContactBackupService.minPasswordLength) {
      setState(
        () => _error = 'contact_backup_password_min'.tr(
          namedArgs: {'min': '${ContactBackupService.minPasswordLength}'},
        ),
      );
      return;
    }
    if (widget.confirm && value != _repeat.text) {
      setState(() => _error = 'contact_backup_password_mismatch'.tr());
      return;
    }
    Navigator.pop(context, value);
  }

  Widget _field(
    TextEditingController controller,
    String hintKey, {
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(labelText: hintKey.tr()),
      onSubmitted: (_) => _submit(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    // autofocus off: the password field takes focus itself, and stealing it
    // for the Escape handler would be a regression (see EscapeDismissible).
    return EscapeDismissible(
      autofocus: false,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          (widget.confirm
                  ? 'contact_backup_password_title_export'
                  : 'contact_backup_password_title_import')
              .tr(),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(_password, 'contact_backup_password_hint', autofocus: true),
            if (widget.confirm) ...[
              const SizedBox(height: 8),
              _field(_repeat, 'contact_backup_password_confirm_hint'),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error,
                style: const TextStyle(
                  color: AppColors.emergency,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('contact_backup_continue'.tr()),
          ),
        ],
      ),
    );
  }
}
