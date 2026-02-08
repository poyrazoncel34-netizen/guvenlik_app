import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';

class PhoneAuthScreen extends StatefulWidget {
  final VoidCallback? onDemoModeRequested;

  const PhoneAuthScreen({super.key, this.onDemoModeRequested});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _verificationId;
  bool _isSending = false;
  bool _codeSent = false;
  bool _isAnonymousLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Telefon numarasi zorunludur';
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!cleaned.startsWith('+')) {
      return 'Ulke kodu ile baslayiniz (orn. +90)';
    }
    if (cleaned.length < 10) {
      return 'Gecerli bir telefon numarasi girin';
    }
    final phoneRegex = RegExp(r'^\+[1-9]\d{7,14}$');
    if (!phoneRegex.hasMatch(cleaned)) {
      return 'Gecerli bir telefon numarasi girin';
    }
    return null;
  }

  String? _validateCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Dogrulama kodu zorunludur';
    }
    if (value.trim().length < 6) {
      return 'Kod 6 hane olmalidir';
    }
    return null;
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  String _mapVerificationError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Gecersiz telefon numarasi. +90 ile baslayip ulke kodunu kontrol edin.';
      case 'too-many-requests':
        return 'Cok fazla istek. Lutfen 1 saat sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin.';
      case 'captcha-check-failed':
      case 'missing-client-identifier':
        return 'Dogrulama basarisiz. Uygulamayi kapatip tekrar acmayi deneyin.';
      case 'internal-error':
      case 'invalid-verification-id':
        return 'Bir hata olustu. Tekrar deneyin.';
      case 'quota-exceeded':
        return 'Gunluk limit asildi. Yarın tekrar deneyin.';
      default:
        return e.message ?? 'Dogrulama basarisiz. Tekrar deneyin.';
    }
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    _safeSetState(() {
      _isSending = true;
      _errorMessage = null;
    });

    final phone = _phoneController.text.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 120),
        verificationCompleted: (credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
          } catch (e) {
            _safeSetState(() {
              _errorMessage = 'Otomatik dogrulama basarisiz. SMS kodunu girin.';
              _isSending = false;
            });
          }
        },
        verificationFailed: (e) {
          debugPrint('Firebase verificationFailed: ${e.code} ${e.message}');
          _safeSetState(() {
            _errorMessage = _mapVerificationError(e);
            _isSending = false;
          });
        },
        codeSent: (verificationId, _) {
          debugPrint('Firebase codeSent - SMS gonderildi');
          _safeSetState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _errorMessage = null;
            _isSending = false;
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
          _safeSetState(() => _isSending = false);
        },
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} ${e.message}');
      _safeSetState(() {
        _errorMessage = _mapVerificationError(e);
        _isSending = false;
      });
    } catch (e, stack) {
      debugPrint('Phone auth error: $e\n$stack');
      _safeSetState(() {
        _errorMessage =
            'Beklenmeyen hata. İnternet bağlantınızı kontrol edip tekrar deneyin. SMS gelmezse aşağıdaki "SMS gelmezse devam et" butonunu kullanabilirsiniz.';
        _isSending = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    if (_verificationId == null) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg;
        switch (e.code) {
          case 'invalid-verification-code':
            msg = 'Kod yanlis. Lutfen kontrol edip tekrar deneyin.';
            break;
          case 'session-expired':
            msg = 'Dogrulama suresi doldu. Yeni kod isteyin.';
            break;
          default:
            msg = 'Kod dogrulanamadi. Tekrar deneyin.';
        }
        setState(() {
          _errorMessage = msg;
          _isSending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Kod dogrulanamadi. Tekrar deneyin.';
          _isSending = false;
        });
      }
    }
  }

  /// Geliştirme/test için - telefon doğrulama olmadan giriş (iOS crash workaround)
  Future<void> _signInAnonymously() async {
    // Firebase Anonymous kapalı veya "administrators only" hatası veriyorsa
    // direkt demo moduna geç
    if (widget.onDemoModeRequested != null) {
      widget.onDemoModeRequested!();
      return;
    }
    _safeSetState(() {
      _isAnonymousLoading = true;
      _errorMessage = null;
    });
    try {
      await FirebaseAuth.instance.signInAnonymously();
      _safeSetState(() => _isAnonymousLoading = false);
    } on FirebaseAuthException catch (e) {
      _safeSetState(() {
        _errorMessage =
            e.message ??
            'Anonim giris basarisiz. Firebase Console\'da Anonymous auth etkin mi?';
        _isAnonymousLoading = false;
      });
      // administrators only veya başka hata - demo moduna geç
      if (widget.onDemoModeRequested != null) {
        widget.onDemoModeRequested!();
      }
    } catch (e) {
      _safeSetState(() {
        _errorMessage = 'Giriş başarısız. İnternet bağlantınızı kontrol edin.';
        _isAnonymousLoading = false;
      });
      // Hata varsa demo moduna geç
      if (widget.onDemoModeRequested != null) {
        widget.onDemoModeRequested!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, AppColors.surface],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 40),
                // Logo / Title area
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "KoruBeni",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Guvenliginiz icin telefon numaranizi dogrulayin.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 40),

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.emergency.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.emergency.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.emergency,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.emergency,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Phone input
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  enabled: !_codeSent,
                  validator: _codeSent ? null : _validatePhone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[\d\+\s\-\(\)]'),
                    ),
                  ],
                  decoration: const InputDecoration(
                    hintText: "+90 5XX XXX XX XX",
                    prefixIcon: Icon(Icons.phone_outlined),
                    labelText: "Telefon Numarasi",
                  ),
                ),
                const SizedBox(height: 16),

                if (_codeSent) ...[
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    validator: _validateCode,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      hintText: "6 haneli SMS kodu",
                      prefixIcon: Icon(Icons.lock_outline),
                      labelText: "Dogrulama Kodu",
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isSending
                          ? null
                          : () {
                              setState(() {
                                _codeSent = false;
                                _verificationId = null;
                                _codeController.clear();
                                _errorMessage = null;
                              });
                            },
                      child: const Text(
                        "Numarayi degistir",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSending
                        ? null
                        : (_codeSent ? _verifyCode : _sendCode),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _codeSent ? "Kodu Dogrula" : "Kod Gonder",
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                // SMS gelmezse test girişi - her zaman göster (kullanıcı uygulamayı kullanabilsin)
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: _isAnonymousLoading ? null : _signInAnonymously,
                  icon: _isAnonymousLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.phone_forwarded_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                  label: Text(
                    _isAnonymousLoading ? 'Giriliyor...' : 'SMS gelmezse buradan devam et',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'SMS doğrulama çalışmazsa bu butonla giriş yapıp uygulamayı test edebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
