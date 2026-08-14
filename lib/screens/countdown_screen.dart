// ============================================================================
// GERİ SAYIM EKRANI – DRAMATIC UX (Gradient arc, pulsating glow, scale bounce)
// ============================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/di/service_locator.dart';
import '../core/app_colors.dart';
import '../core/motion.dart';
import '../core/services/contact_service.dart';
import '../domain/repositories/contacts_repository.dart';
import '../core/services/activity_service.dart';
import '../core/services/countdown_clock.dart';
import '../core/services/call_service.dart';
import '../core/services/android_intent_service.dart';
import '../core/services/pin_lockout_service.dart';
import '../domain/models/activity_event.dart';
import 'emergency_call_screen.dart';
import '../core/services/foreground_service.dart';
import '../core/services/countdown_announcement.dart';
import '../core/services/haptic_service.dart';
import '../core/services/reduced_motion_policy.dart';
import '../core/services/dispatch_ledger_recorder.dart';
import '../core/services/emergency_bookkeeping.dart';
import '../core/services/emergency_dispatch_pipeline.dart';
import '../core/services/emergency_platform_service.dart';
import '../core/services/emergency_session_contract.dart';
import '../core/services/panic_arm_policy.dart';
import '../core/services/pin_verification_service.dart';
import '../core/utils/emergency_number_validator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class CountdownScreen extends StatefulWidget {
  final bool isTestMode;
  final EntitlementDecision entitlementDecision;
  final PinVerificationService? pinVerificationService;
  final EmergencyPlatformService? emergencyPlatformService;

  const CountdownScreen({
    super.key,
    this.isTestMode = false,
    this.entitlementDecision = EntitlementDecision.unknown,
    this.pinVerificationService,
    this.emergencyPlatformService,
  });

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen>
    with TickerProviderStateMixin {
  int _countdown = 10;

  DateTime? _armedDeadline; // absolute; see [CountdownClock]
  Timer? _timer;
  String _pin = "";
  PinState _pinState = PinState.loading;
  bool _verificationInProgress = false;
  DateTime? _lastWrongPinEvaluation;
  late AnimationController _shakeController;
  late AnimationController _tickBounceController;
  late AnimationController _glowController;
  EmergencyContact? _emergencyContact;
  late final ContactsRepository _contactsRepository =
      serviceLocator<ContactsRepository>();
  late final PinVerificationService _pinVerificationService =
      widget.pinVerificationService ?? PinVerificationService.instance;
  late final EmergencyPlatformService _emergencyPlatformService =
      widget.emergencyPlatformService ?? EmergencyPlatformService.instance;
  late final EmergencyDispatchPipeline _dispatchPipeline =
      EmergencyDispatchPipeline(
        onBestEffortError: (error, _) {
          debugPrint('CountdownScreen best-effort operation failed: $error');
        },
      );
  bool _reduceMotion = false;
  bool _handoffToEmergencyScreen = false;
  bool _isNavigating = false;
  bool _emergencyDispatched = false;
  late final String _dispatchId =
      'countdown-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  String get _foregroundOwner => 'countdown:$_dispatchId';
  SessionToken? _sessionToken;
  ArmResult? _armResult;
  String? _armedTargetNumber;
  String? _armedTargetName;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _tickBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // ~2.8s breath; 800ms read as a flash. Pulse started once MediaQuery is.
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _bootstrapAndStartCountdown();
    unawaited(KoruBeniForegroundService.start(owner: _foregroundOwner));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = ReducedMotionPolicy.isReduced(context);
    ReducedMotionPolicy.pulse(_glowController, reduced: _reduceMotion);
  }

  Future<void> _bootstrapAndStartCountdown() async {
    if (!widget.isTestMode) {
      await Future.wait<void>([_loadPin(), _loadEmergencyContact()]);
    }
    if (!mounted) return;
    await _startCountdownAfterPermission();
  }

  /// Release-of-panic-button kicks off the countdown immediately.
  /// CALL_PHONE permission is requested from the readiness card (see
  /// [HomePage._requestCallPhonePermission]) so the emergency flow is not
  /// interrupted; the pre-countdown honesty dialog was dropped to keep
  /// the panic-button release responsive.
  Future<void> _startCountdownAfterPermission() async {
    if (widget.isTestMode) {
      await _startCountdown();
      return;
    }
    // Wait for the frame that is actually pending, not a fixed 300ms: the
    // deadline is set at arm time, so that delay pushed every dial 300ms later.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _startCountdown();
  }

  Future<void> _loadPin() async {
    final state = await _pinVerificationService.loadState();
    if (mounted) setState(() => _pinState = state);
  }

  Future<void> _loadEmergencyContact() async {
    final contact = await _contactsRepository.getPrimaryEmergencyContact();
    if (mounted) {
      setState(() => _emergencyContact = contact);
    }
  }

  /// Arm the native authority before starting the Dart projection. Exact-alarm
  /// access is required at arm time; a distinct inexact alarm is retained only
  /// as a best-effort backup if that access is revoked after arming.
  Future<ArmResult> _scheduleNativeBackupAlarm() async {
    if (widget.entitlementDecision != EntitlementDecision.authorized) {
      return _recordRejectedArm(
        widget.entitlementDecision == EntitlementDecision.denied
            ? 'entitlementDenied'
            : 'entitlementUnknown',
      );
    }
    if (_pinState != PinState.configured) {
      return _recordRejectedArm(
        _pinState == PinState.readFailed ? 'pinReadFailed' : 'pinNotConfigured',
      );
    }

    ArmResult result;
    try {
      final primaryCandidate = _emergencyContact?.phone;
      final primaryNumber =
          primaryCandidate != null &&
              EmergencyNumberValidator.isCallableEmergencyTarget(
                primaryCandidate,
              )
          ? primaryCandidate
          : null;

      // A safety session is bound only to the explicitly selected primary.
      // Silently falling back to list order can dispatch to the wrong person.
      if (primaryNumber == null) {
        return _recordRejectedArm('callableTargetMissing');
      }

      _armedTargetNumber = AndroidIntentService.normalizePhoneNumber(
        primaryNumber,
      );
      _armedTargetName = _emergencyContact?.name;

      // Dart and native race against the same 10-second deadline. Whichever
      // claims first performs the request; the loser reads the durable result.
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      _armedDeadline = deadline;
      result = await _emergencyPlatformService.armEmergencySession(
        kind: EmergencySessionKind.panic,
        mainDeadline: deadline,
        finalDeadline: deadline,
        target: _armedTargetNumber!,
        entitlementDecision: widget.entitlementDecision,
        pinConfigured: _pinState == PinState.configured,
        randomId: _dispatchId,
      );
    } catch (_) {
      debugPrint('CountdownScreen: Native session arm failed');
      result = const ArmUnknown('flutterArmException');
    }
    _armResult = result;
    _sessionToken = PanicArmPolicy.activeOrUncertainToken(result);
    return result;
  }

  ArmRejected _recordRejectedArm(String reasonCode) {
    final result = ArmRejected(reasonCode);
    _armResult = result;
    _sessionToken = null;
    return result;
  }

  Future<void> _startCountdown() async {
    if (_timer != null) return;
    if (widget.isTestMode) {
      // Test mode is a local UI rehearsal. It neither arms native safety state
      // nor needs a real contact, entitlement lease, or PIN.
      _startDartCountdownTimer();
      return;
    }
    // Arm native AlarmManager backup BEFORE the Dart timer starts, so a Doze
    // transition during this window cannot leave us without a safety net.
    final armResult = await _scheduleNativeBackupAlarm();
    if (!mounted || _timer != null) return;
    if (!PanicArmPolicy.shouldStartCountdown(armResult)) {
      // Ownership is released synchronously. The platform notification update
      // is best-effort and must not delay the fail-closed rejection UI.
      unawaited(KoruBeniForegroundService.stop(owner: _foregroundOwner));
      if (!mounted) return;
      await _showBlockingFailure(
        title: 'emergency_total_failure_title'.tr(),
        body: PanicArmPolicy.blockedMessageKey(armResult).tr(),
        phoneNumber: '',
      );
      return;
    }
    _startDartCountdownTimer();
  }

  void _startDartCountdownTimer() {
    // Test mode has no armed session, so it keeps the plain tick behaviour.
    final deadline = _armedDeadline;
    // Real session polls the deadline; test mode keeps whole-second ticks.
    final period = deadline == null
        ? const Duration(seconds: 1)
        : const Duration(milliseconds: 200);
    _timer = Timer.periodic(period, (timer) {
      final left = deadline == null
          ? _countdown - 1
          : CountdownClock.secondsUntil(deadline);
      if (left > 0) {
        if (left == _countdown) return;
        setState(() => _countdown = left);
        HapticService.countdownTick(secondsRemaining: _countdown);
        // ── Tick bounce ── decoration; number + haptic carry the second.
        ReducedMotionPolicy.playOnce(
          _tickBounceController,
          reduced: _reduceMotion,
        );
        return;
      }
      if (mounted) setState(() => _countdown = 0);
      timer.cancel();
      unawaited(_makeEmergencyCall());
    });
  }

  Future<void> _makeEmergencyCall() async {
    if (_emergencyDispatched || _isNavigating) return;
    _emergencyDispatched = true;

    // Native dispatch and fallback must never wait on a plugin channel. The
    // wakelock is a best-effort execution aid, not safety authority.
    unawaited(
      WakelockPlus.enable().catchError((Object _) {
        debugPrint('CountdownScreen: WakelockPlus.enable failed');
      }),
    );

    if (widget.isTestMode) {
      unawaited(KoruBeniForegroundService.stop(owner: _foregroundOwner));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("countdown_test_complete".tr()),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
      return;
    }

    try {
      await _executeEmergency();
    } catch (_) {
      // FAIL-SAFE: If ANY unhandled exception occurs, show blocking error with manual call option.
      debugPrint('CountdownScreen: Emergency execution failed');
      unawaited(KoruBeniForegroundService.stop(owner: _foregroundOwner));
      if (mounted) {
        final primaryNumber = _emergencyContact?.phone ?? '';
        await _showBlockingFailure(
          title: 'emergency_total_failure_title'.tr(),
          body: 'emergency_total_failure_body'.tr(),
          phoneNumber: primaryNumber,
        );
      }
    }
  }

  Future<void> _executeEmergency() async {
    // The arming-time target is immutable. Contact edits during a countdown
    // cannot redirect an already-authorized safety action.
    final primaryNumber = _armedTargetNumber;

    final execution = await _dispatchPipeline.execute<EmergencyCallResult?>(
      dispatchId: _dispatchId,
      criticalOperation: () async {
        final token = _sessionToken;
        if (token != null) {
          final dispatch = await _emergencyPlatformService
              .dispatchEmergencySession(
                token: token,
                source: 'dartPanicCountdown',
              );
          if (dispatch.wasCancelled) {
            unawaited(KoruBeniForegroundService.stop(owner: _foregroundOwner));
            if (mounted) Navigator.pop(context);
            return null;
          }
          if (dispatch.requestWasSubmitted) {
            return EmergencyCallResult.requested(primaryNumber ?? '');
          }
        }

        // A timeout/failed request may still have raced across the native
        // boundary. A visible Activity can request ACTION_DIAL without making
        // a false automatic-call claim. A missing token means native arm was
        // definitively rejected and uses the same foreground-only path.
        final dialerOpened = primaryNumber != null && primaryNumber.isNotEmpty
            ? await AndroidIntentService.openDialer(primaryNumber)
            : false;
        return dialerOpened
            ? EmergencyCallResult.dialer(primaryNumber)
            : EmergencyCallResult.failed(primaryNumber ?? '');
      },
      recordCriticalOutcome: DispatchLedgerRecorder.recordCallTargets,
      shouldRunBestEffort: (result) => result != null,
      bestEffortOperations: EmergencyBookkeeping.panicStepsWithDefaultCopy(),
    );
    final callResult = execution.result;
    final ledger = execution.ledger;
    if (callResult == null) return;

    final calledNumber = primaryNumber ?? '';

    if (callResult.isFailed) {
      unawaited(KoruBeniForegroundService.stop(owner: _foregroundOwner));
      if (mounted) {
        await _showBlockingFailure(
          title: 'emergency_total_failure_title'.tr(),
          body: 'emergency_total_failure_body'.tr(),
          phoneNumber: calledNumber,
        );
      }
      return;
    }

    if (mounted && !_isNavigating) {
      _isNavigating = true;
      _handoffToEmergencyScreen = true;
      try {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmergencyCallScreen(
              name:
                  _armedTargetName ??
                  _emergencyContact?.name ??
                  "countdown_emergency_label".tr(),
              // Display the immutable arming-time identity when available.
              phone: calledNumber,
              callResult: callResult,
              dispatchLedger: ledger,
              foregroundOwner: _foregroundOwner,
            ),
          ),
        );
      } catch (_) {
        debugPrint('CountdownScreen: Navigation failed');
        _isNavigating = false;
        _handoffToEmergencyScreen = false;
        if (mounted) {
          await _showBlockingFailure(
            title: 'emergency_total_failure_title'.tr(),
            body: 'emergency_total_failure_body'.tr(),
            phoneNumber: calledNumber,
          );
        }
      }
    }
  }

  /// Shows a FULLSCREEN BLOCKING failure dialog. User MUST interact.
  /// No silent dismissal. No snackbar. This is the fail-safe.
  Future<void> _showBlockingFailure({
    required String title,
    required String body,
    required String phoneNumber,
    String? emergencyMessage,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.emergency.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_rounded,
                  color: AppColors.emergency,
                  size: 42,
                ),
              ),
              const SizedBox(height: 16),
              // Heading of the blocking failure surface (MP-12-017).
              Semantics(
                header: true,
                child: Text(title, textAlign: TextAlign.center, style: const
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (phoneNumber.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    phoneNumber,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (emergencyMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    emergencyMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (phoneNumber.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await AndroidIntentService.openDialer(phoneNumber);
                  },
                  icon: const Icon(Icons.call, size: 20),
                  label: Text(
                    'emergency_manual_call_now'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emergency,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (emergencyMessage != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: emergencyMessage));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('emergency_message_copied'.tr()),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text('emergency_copy_message'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text(
                  'emergency_dismiss'.tr(),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    _tickBounceController.dispose();
    _glowController.dispose();
    if (!_handoffToEmergencyScreen && !_emergencyDispatched) {
      // Widget lifecycle is not cancellation authority. The native session
      // survives route disposal/process recreation until verified PIN cancel,
      // dispatch or expiry reaches a durable terminal state.
      unawaited(KoruBeniForegroundService.stop(owner: _foregroundOwner));
    }
    // Release the wakelock unless EmergencyCallScreen is taking over. If
    // wakelock was never enabled (cancelled before dispatch), disable() is
    // a no-op. When handing off, EmergencyCallScreen owns the lock and
    // releases it in its own dispose.
    if (!_handoffToEmergencyScreen) {
      unawaited(
        WakelockPlus.disable().catchError((Object e) {
          debugPrint('CountdownScreen: WakelockPlus.disable failed: $e');
        }),
      );
    }
    super.dispose();
  }

  Future<void> _cancelCountdownAndExit({
    required String description,
    bool resetPinLockout = false,
  }) async {
    if (_isNavigating || _emergencyDispatched) return;
    _isNavigating = true;
    _timer?.cancel();
    _timer = null;
    final token = _sessionToken;
    final cancelResult = token == null
        ? null
        : await _emergencyPlatformService.cancelEmergencySession(token);
    final definitivelyNoNativeSession =
        token == null && _armResult is ArmRejected;
    final cancellationConfirmed =
        definitivelyNoNativeSession ||
        (cancelResult?.isConfirmedCancelled ?? false);
    if (!cancellationConfirmed) {
      _isNavigating = false;
      if (mounted) {
        final message = cancelResult is SessionCancelTooLate
            ? 'emergency_cancel_too_late'.tr()
            : 'emergency_cancel_unconfirmed'.tr();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.emergency,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (cancelResult is SessionCancelTooLate) {
        _emergencyDispatched = false;
        unawaited(_makeEmergencyCall());
      } else {
        _startDartCountdownTimer();
      }
      return;
    }
    if (resetPinLockout) {
      await PinLockoutService.instance.reset();
    }
    try {
      await ActivityService.logEvent(
        type: ActivityType.emergencyCancelled,
        title: "countdown_cancelled_title".tr(),
        description: description,
      );
    } catch (_) {
      // Native cancellation is already durably acknowledged. A local history
      // failure must not trap the user on an active-looking countdown or
      // weaken the cancellation result.
      debugPrint('CountdownScreen: cancellation log failed');
    }
    // Native cancellation is already durable and ownership is released before
    // the notification plugin is awaited internally. A stalled plugin channel
    // must not trap the user on an active-looking countdown.
    unawaited(KoruBeniForegroundService.stop(owner: _foregroundOwner));
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _handlePinInput(String key) {
    if (_pinState != PinState.configured ||
        _verificationInProgress ||
        _isNavigating ||
        _emergencyDispatched) {
      return;
    }
    HapticFeedback.lightImpact();

    if (key == "DEL") {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
      return;
    }

    if (_pin.length < 4) {
      setState(() => _pin += key);

      if (_pin.length == 4) {
        final candidate = _pin;
        _verificationInProgress = true;
        unawaited(_verifyPinAndMaybeCancel(candidate));
      }
    }
  }

  Future<void> _verifyPinAndMaybeCancel(String candidate) async {
    final verification = await _pinVerificationService.verify(candidate);
    if (!mounted) return;
    _pinState = verification.state;
    if (verification.matches && !_isNavigating) {
      _verificationInProgress = false;
      await _cancelCountdownAndExit(
        description: "countdown_cancelled_pin".tr(),
        resetPinLockout: true,
      );
      return;
    }

    final now = DateTime.now();
    final shouldEvaluateWrongPin =
        verification.state == PinState.configured &&
        (_lastWrongPinEvaluation == null ||
            now.difference(_lastWrongPinEvaluation!) >=
                const Duration(seconds: 1));
    _lastWrongPinEvaluation = shouldEvaluateWrongPin
        ? now
        : _lastWrongPinEvaluation;
    if (shouldEvaluateWrongPin) {
      await PinLockoutService.instance.registerFailure().catchError((
        Object error,
      ) {
        debugPrint('PinLockoutService.registerFailure failed: $error');
        return const PinLockoutState(failedAttempts: 0, lockedUntil: null);
      });
    }
    if (!mounted) return;
    ReducedMotionPolicy.playOnce(_shakeController, reduced: _reduceMotion);
    HapticFeedback.vibrate();
    setState(() {
      _pin = '';
      _verificationInProgress = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          verification.state == PinState.readFailed
              ? 'pin_state_read_failed'.tr()
              : "pin_mismatch".tr(),
        ),
        backgroundColor: AppColors.emergency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _countdown <= 5;
    final urgentColor = isUrgent ? AppColors.emergency : AppColors.warning;

    return PopScope(
      // The explicit PIN/no-PIN controls below are the only cancellation
      // authority. Allowing Navigator to pop this route would run dispose(),
      // cancel the native alarm, and silently bypass that contract.
      // `canPop: false` also covers Android predictive Back.
      canPop: false,
      child: Semantics(
        label: "semantics_countdown".tr(),
        hint: "semantics_countdown_hint".tr(),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              // ── Pulsating background glow in last 5 seconds ──
              final glowPulse = ReducedMotionPolicy.pulseValue(
                _glowController,
                reduced: _reduceMotion,
              );
              final glowAlpha = isUrgent ? (0.03 + glowPulse * 0.08) : 0.0;
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      AppColors.emergency.withValues(alpha: glowAlpha),
                      AppColors.background,
                    ],
                  ),
                ),
                child: child,
              );
            },
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 720;
                  final pagePadding = compact ? 16.0 : 24.0;
                  final topGap = compact ? 8.0 : 12.0;
                  final sectionGap = 24.0;
                  final pinGap = compact ? 28.0 : 24.0;
                  final bottomGap = 16.0;
                  final circleSize = compact ? 152.0 : 144.0;
                  final countdownFontSize = compact ? 58.0 : 56.0;
                  final bannerPadding = compact ? 16.0 : 20.0;
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(pagePadding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - (pagePadding * 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: topGap),
                          // Warning banner
                          Container(
                            padding: EdgeInsets.all(bannerPadding),
                            decoration: BoxDecoration(
                              color: AppColors.emergency.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.emergency.withValues(
                                  alpha: 0.3,
                                ),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_rounded,
                                  color: AppColors.emergency,
                                  size: 26,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    "countdown_warning_title".tr(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.isTestMode) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.success.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                "countdown_test_mode".tr(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: sectionGap),
                          // ── Countdown circle with gradient arc + tick bounce ──
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Gradient arc
                              SizedBox(
                                width: circleSize,
                                height: circleSize,
                                child: CustomPaint(
                                  painter: _GradientArcPainter(
                                    progress: _countdown / 10,
                                    startColor: urgentColor,
                                    endColor: isUrgent
                                        ? const Color(0xFFFF8A65)
                                        : AppColors.primary,
                                    bgColor: AppColors.border.withValues(
                                      alpha: 0.5,
                                    ),
                                    strokeWidth: 14,
                                  ),
                                ),
                              ),
                              // Bouncing countdown number
                              Semantics(
                                liveRegion: true,
                                container: true,
                                label: CountdownAnnouncement.labelFor(_countdown),
                                child: ExcludeSemantics(
                                  child: AnimatedBuilder(
                                    animation: _tickBounceController,
                                    builder: (context, child) {
                                      final bounceScale =
                                          1.0 +
                                          (sin(
                                                _tickBounceController.value *
                                                    pi,
                                              ) *
                                              0.12);
                                      return Transform.scale(
                                        scale: bounceScale,
                                        child: child,
                                      );
                                    },
                                    child: Column(
                                      children: [
                                        Text(
                                          "$_countdown",
                                          style: TextStyle(
                                            fontSize: countdownFontSize,
                                            fontWeight: FontWeight.w900,
                                            color: urgentColor,
                                            height: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "countdown_seconds".tr(),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: sectionGap),
                          Text(
                            switch (_pinState) {
                              PinState.loading => 'pin_state_loading'.tr(),
                              PinState.configured => "countdown_enter_pin".tr(),
                              PinState.absent => "settings_pin_not_found".tr(),
                              PinState.readFailed =>
                                'pin_state_read_failed'.tr(),
                            },
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (_emergencyContact != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              "countdown_emergency_contact".tr(
                                namedArgs: {
                                  "name":
                                      _armedTargetName ??
                                      _emergencyContact!.name,
                                },
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            _pinState == PinState.configured
                                ? "countdown_disclaimer".tr()
                                : switch (_pinState) {
                                    PinState.loading =>
                                      'pin_state_loading'.tr(),
                                    PinState.readFailed =>
                                      'pin_state_read_failed'.tr(),
                                    _ => "settings_pin_not_found".tr(),
                                  },
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: sectionGap),
                          if (_pinState == PinState.configured) ...[
                            // ── PIN dots with shake ──
                            AnimatedBuilder(
                              animation: _shakeController,
                              builder: (context, child) {
                                final offset =
                                    sin(_shakeController.value * pi * 4) * 12;
                                return Transform.translate(
                                  offset: Offset(offset, 0),
                                  child: child,
                                );
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(4, (index) {
                                  final isFilled = index < _pin.length;
                                  return AnimatedContainer(
                                    duration: Motion.fast,
                                    curve: Motion.enter,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    width: isFilled ? 20 : 18,
                                    height: isFilled ? 20 : 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isFilled
                                          ? AppColors.primary
                                          : AppColors.border,
                                      boxShadow: isFilled
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 8,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  );
                                }),
                              ),
                            ),
                            SizedBox(height: pinGap),
                            _buildNumberPad(),
                          ],
                          SizedBox(height: bottomGap),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Returns the screen-reader announcement string for the current
  /// countdown second. Returns an empty string for ticks that should
  /// not announce — sparse schedule (10, 8, 5, 4, 3, 2, 1) keeps
  /// TalkBack from spamming every second while still giving the user
  /// enough warning to enter PIN before dispatch.
  Widget _buildNumberPad() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 30),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 18,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        if (index == 9) return const SizedBox();
        if (index == 11) {
          return _buildPadButton(
            child: const Icon(Icons.backspace_outlined, size: 26),
            onTap: () => _handlePinInput("DEL"),
          );
        }
        final value = index == 10 ? "0" : "${index + 1}";
        return _buildPadButton(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          onTap: () => _handlePinInput(value),
        );
      },
    );
  }

  Widget _buildPadButton({required Widget child, required VoidCallback onTap}) {
    return _ScaleTapButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Scale-bounce micro-animation for numpad buttons
class _ScaleTapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _ScaleTapButton({required this.child, required this.onTap});

  @override
  State<_ScaleTapButton> createState() => _ScaleTapButtonState();
}

class _ScaleTapButtonState extends State<_ScaleTapButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Gradient arc painter for the countdown circle
class _GradientArcPainter extends CustomPainter {
  final double progress;
  final Color startColor;
  final Color endColor;
  final Color bgColor;
  final double strokeWidth;

  _GradientArcPainter({
    required this.progress,
    required this.startColor,
    required this.endColor,
    required this.bgColor,
    this.strokeWidth = 14,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background ring
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Gradient arc
    if (progress > 0) {
      final sweepAngle = 2 * pi * progress;
      final gradient = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + sweepAngle,
        colors: [startColor, endColor],
      );
      final arcPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradientArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.startColor != startColor;
  }
}
