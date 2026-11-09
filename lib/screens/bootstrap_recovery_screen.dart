import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/design_tokens.dart';
import '../core/services/emergency_session_contract.dart';

typedef BootstrapRetry = Future<bool> Function();
typedef ActiveSafetySessionCheck = Future<bool> Function();
typedef LocalDataReset = Future<WipeResult> Function();

/// Fail-closed recovery surface used only when the PIN storage boundary could
/// not be read during critical bootstrap.
///
/// This widget deliberately has no route into the normal application. The only
/// successful exit is a fresh critical-bootstrap pass, either directly or
/// after an explicitly confirmed local reset.
///
/// The body is worded from [reasonCode]: `pinFailed` means every bounded
/// retry hit a storage error, so the user is told plainly that the way out may
/// cost every local record; `contact*` names the contact store.
class BootstrapRecoveryScreen extends StatefulWidget {
  const BootstrapRecoveryScreen({
    super.key,
    required this.reasonCode,
    required this.retryBootstrap,
    required this.hasActiveSafetySession,
    required this.resetLocalData,
    required this.onRecovered,
  });

  final String reasonCode;
  final BootstrapRetry retryBootstrap;
  final ActiveSafetySessionCheck hasActiveSafetySession;
  final LocalDataReset resetLocalData;
  final VoidCallback onRecovered;

  @override
  State<BootstrapRecoveryScreen> createState() =>
      _BootstrapRecoveryScreenState();
}

class _BootstrapRecoveryScreenState extends State<BootstrapRecoveryScreen> {
  bool _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    final recovered = await widget.retryBootstrap();
    if (!mounted) return;
    if (recovered) {
      widget.onRecovered();
      return;
    }
    setState(() => _busy = false);
    _showMessage('bootstrap_recovery_retry_failed'.tr());
  }

  Future<void> _requestReset() async {
    if (_busy) return;

    // This check is intentionally before the confirmation dialog and wipe.
    // An unreadable projection is reported as active by the probe, so an
    // unauthenticated attacker cannot cancel an uncertain ARMED session.
    if (await widget.hasActiveSafetySession()) {
      if (!mounted) return;
      _showMessage('bootstrap_recovery_reset_blocked_active_session'.tr());
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TypedResetDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await widget.resetLocalData();
    if (!mounted) return;
    if (result != WipeResult.completed) {
      setState(() => _busy = false);
      _showMessage('bootstrap_recovery_wipe_failed'.tr());
      return;
    }

    final recovered = await widget.retryBootstrap();
    if (!mounted) return;
    if (recovered) {
      widget.onRecovered();
      return;
    }
    setState(() => _busy = false);
    _showMessage('bootstrap_recovery_reset_done_bootstrap_failed'.tr());
  }

  String get _bodyKey => switch (widget.reasonCode) {
    'pinFailed' => 'bootstrap_recovery_body_persistent',
    'contactFailed' || 'contactTimeout' => 'bootstrap_recovery_body_contacts',
    _ => 'bootstrap_recovery_body',
  };

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: IconSizes.hero,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 20),
                    // No AppBar on this screen, so the heading a screen
                    // reader announces has to be marked explicitly.
                    Semantics(
                      header: true,
                      child: Text(
                        'bootstrap_recovery_title'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _bodyKey.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _retry,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text('bootstrap_recovery_retry'.tr()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _busy ? null : _requestReset,
                        child: Text('bootstrap_recovery_reset'.tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypedResetDialog extends StatefulWidget {
  const _TypedResetDialog();

  @override
  State<_TypedResetDialog> createState() => _TypedResetDialogState();
}

class _TypedResetDialogState extends State<_TypedResetDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('bootstrap_recovery_reset_dialog_title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('bootstrap_recovery_reset_dialog_body'.tr()),
            const SizedBox(height: 16),
            Text('bootstrap_recovery_reset_dialog_hint'.tr()),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('bootstrap_recovery_reset_dialog_cancel'.tr()),
        ),
        ElevatedButton(
          // Same typed token as "PIN'imi unuttum": one reset policy.
          onPressed: _controller.text == 'forgot_pin_reset_token'.tr()
              ? () => Navigator.pop(context, true)
              : null,
          child: Text('forgot_pin_reset_button'.tr()),
        ),
      ],
    );
  }
}
