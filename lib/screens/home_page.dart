// ============================================================================
// ANA SAYFA (İSTATİSTİKLER VE YENİ ÖZELLİKLER EKLENDİ)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/services/shake_detector_service.dart';
import '../core/services/audio_recorder_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/analytics_service.dart';
import '../presentation/providers/home_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../widgets/panic_button.dart';
import '../widgets/siren_dialog.dart';
import 'fake_call_screen.dart';
import 'contacts_page.dart';
import 'countdown_screen.dart';
import 'safe_walk_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _headerController;
  final ShakeDetectorService _shakeDetector = ShakeDetectorService();
  bool _isRecording = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _headerController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().initialize();
      _initShakeDetection();
      _initConnectivity();
    });
    AnalyticsService.logScreenView('home');
  }

  void _initShakeDetection() {
    _shakeDetector.startListening(onShakeDetected: () {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      AnalyticsService.logShakeDetected();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CountdownScreen()),
      );
    });
  }

  void _initConnectivity() {
    ConnectivityService.instance.initialize();
    ConnectivityService.instance.onStatusChange.listen((online) {
      if (mounted) {
        setState(() => _isOffline = !online);
        if (!online) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text("Internet baglantisi yok", style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  Future<void> _toggleRecording() async {
    final recorder = AudioRecorderService.instance;
    if (_isRecording) {
      final path = await recorder.stopRecording();
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(path != null ? "Kayit kaydedildi" : "Kayit basarisiz"),
            backgroundColor: path != null ? AppColors.success : AppColors.emergency,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      final started = await recorder.startRecording();
      if (mounted) {
        setState(() => _isRecording = started);
        if (started) {
          AnalyticsService.logAudioRecordingStarted();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Mikrofon izni gerekli"),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    _shakeDetector.dispose();
    super.dispose();
  }

  void _showMessageTemplates(BuildContext context, HomeProvider provider) {
    final templates = [
      "Yardıma ihtiyacım var! Konumumu kontrol edin.",
      "Kendimi güvende hissetmiyorum. Lütfen beni arayın.",
      "Acil durum! Hemen yardım gönderin.",
      "Rahatsız ediliyorum. Yardım edin.",
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.message_rounded, color: AppColors.primary),
            SizedBox(width: 12),
            Text("Hızlı Mesaj"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: templates.map((text) {
            return ListTile(
              title: Text(text, style: const TextStyle(fontSize: 14)),
              trailing: const Icon(Icons.send_rounded, color: AppColors.primary),
              onTap: () async {
                Navigator.pop(context);
                final message = await provider.sendQuickMessage(text);
                if (message != null && context.mounted) {
                  _showSnack(message);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Bildirimler",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            _buildNotificationItem(
                "Güvenlik Kontrolü", "Günlük kontrol tamamlandı", Icons.check_circle, const Color(0xFF34C759)),
            _buildNotificationItem(
                "Konum Güncellemesi", "Konumunuz paylaşıldı", Icons.location_on, const Color(0xFF007AFF)),
            _buildNotificationItem(
                "Sistem Bildirimi", "Yeni özellikler eklendi", Icons.new_releases, const Color(0xFFFF9500)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(String title, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final pendingMessage = provider.takeMessage();
    if (pendingMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnack(pendingMessage);
      });
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: FadeTransition(
                    opacity: _headerController,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.5),
                        end: Offset.zero,
                      ).animate(_headerController),
                      child: _buildHeader(),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isOffline) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 18),
                              SizedBox(width: 8),
                              Text("Cevrimdisi mod - bazi ozellikler kisitli",
                                  style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_isRecording) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.emergency.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.emergency.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.emergency, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              const Text("Ses kaydi aktif",
                                  style: TextStyle(fontSize: 12, color: AppColors.emergency, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              GestureDetector(
                                onTap: _toggleRecording,
                                child: const Text("Durdur",
                                    style: TextStyle(fontSize: 12, color: AppColors.emergency, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 6),
                    _buildEmergencyContactChip(provider),
                    const SizedBox(height: 14),
                    _buildReadinessCard(provider),
                    if (!provider.onboardingDismissed) ...[
                      const SizedBox(height: 16),
                      _buildOnboardingCard(provider),
                    ],
                    const SizedBox(height: 20),
                    const Center(child: PanicButton()),
                    const SizedBox(height: 12),
                    _buildTestModeButton(),
                    const SizedBox(height: 30),
                    _buildQuickActions(),
                      const SizedBox(height: 24),
                      _buildLocationCard(provider),
                      const SizedBox(height: 24),
                      _buildSafetyTips(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final settingsProvider = context.watch<SettingsProvider>();
    final displayName = settingsProvider.hasProfile ? settingsProvider.profileName : 'Kullanici';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Merhaba,",
                style: TextStyle(
                    fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.8,
                    height: 1.1),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _showNotifications(context);
              },
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined, size: 24, color: AppColors.textPrimary),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.emergency,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyContactChip(HomeProvider provider) {
    final name = provider.emergencyContact?.name;
    final phone = provider.emergencyContact?.phone;
    final hasContact = name != null && phone != null;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _openContacts,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasContact ? "Acil kişi hazır" : "Acil kişi seçilmedi",
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasContact ? "$name • $phone" : "Dokunarak kişi seçin",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildReadinessCard(HomeProvider provider) {
    final allReady = provider.locationPermissionGranted &&
        provider.contactsPermissionGranted &&
        provider.emergencyContact != null;
    final title = allReady ? "Hazır" : "Eksik ayar";
    final subtitle = allReady
        ? "Kritik izinler açık. Sistem çalışmaya hazır."
        : "Bazı izinler gerekli. Güvenliğiniz için tamamlayın.";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (allReady ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  allReady ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: allReady ? AppColors.success : AppColors.warning,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(
                label: "Konum",
                isOk: provider.locationPermissionGranted,
                onTap: _requestLocationPermission,
              ),
              _buildStatusChip(
                label: "Rehber",
                isOk: provider.contactsPermissionGranted,
                onTap: _requestContactsPermission,
              ),
              _buildStatusChip(
                label: "Acil kişi",
                isOk: provider.emergencyContact != null,
                onTap: _openContacts,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({required String label, required bool isOk, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (isOk ? AppColors.success : AppColors.warning).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: (isOk ? AppColors.success : AppColors.warning).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              size: 14,
              color: isOk ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isOk ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestLocationPermission() async {
    final provider = context.read<HomeProvider>();
    await provider.requestLocationPermission();
  }

  Future<void> _requestContactsPermission() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rehber izni web üzerinde desteklenmiyor.")),
      );
      return;
    }
    final provider = context.read<HomeProvider>();
    final message = await provider.requestContactsPermission();
    if (message != null && context.mounted) {
      _showSnack(message);
    }
  }

  Widget _buildOnboardingCard(HomeProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "3 adımda hazır olun",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                onPressed: provider.dismissOnboarding,
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildOnboardingStep(
            index: "1",
            title: "Acil kişi seçin",
            subtitle: "Rehberinizden güvenilir bir kişiyi belirleyin.",
            onTap: _openContacts,
          ),
          _buildOnboardingStep(
            index: "2",
            title: "Konum iznini verin",
            subtitle: "Acil durumlarda konum paylaşımı için izin gereklidir.",
            onTap: _requestLocationPermission,
          ),
          _buildOnboardingStep(
            index: "3",
            title: "Test modunu çalıştırın",
            subtitle: "Gerçek arama olmadan akışı deneyin.",
            onTap: _startTestMode,
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingStep({
    required String index,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    index,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestModeButton() {
    return OutlinedButton.icon(
      onPressed: _startTestMode,
      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
      label: const Text("Test Modu (gerçek arama yapılmaz)"),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _startTestMode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CountdownScreen(isTestMode: true)),
    );
  }

  Future<void> _openContacts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContactsPage()),
    );
    if (!mounted) return;
    await context.read<HomeProvider>().refreshAfterContactsChanged();
  }
  Widget _buildQuickActions() {
    final provider = context.read<HomeProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Hızlı İşlemler",
          style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                "Sahte Cagri",
                Icons.phone_in_talk_rounded,
                AppColors.primary,
                () {
                  AnalyticsService.logFakeCallUsed();
                  Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const FakeCallScreen()));
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildActionCard(
                "Siren",
                Icons.notifications_active_rounded,
                AppColors.warning,
                _activateSiren,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                "Guvenli Yuruyus",
                Icons.directions_walk_rounded,
                AppColors.accent,
                () {
                  Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const SafeWalkScreen()));
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildActionCard(
                _isRecording ? "Kaydi Durdur" : "Ses Kaydi",
                _isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                _isRecording ? AppColors.emergency : const Color(0xFF9B59B6),
                _toggleRecording,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                "Hizli Mesaj",
                Icons.message_rounded,
                AppColors.success,
                () => _showMessageTemplates(context, provider),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildActionCard(
                "Kisiler",
                Icons.people_rounded,
                AppColors.info,
                _openContacts,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _activateSiren() {
    HapticFeedback.heavyImpact();
    AnalyticsService.logSirenActivated();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SirenDialog(),
    );
  }

  Widget _buildLocationCard(HomeProvider provider) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.location_on_rounded, color: AppColors.info, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Konum Paylaşımı",
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.isLocationSharing
                      ? provider.locationShareEndAt != null
                          ? "Paylaşılıyor • ${_formatRemaining(provider.locationShareEndAt)}"
                          : "Konumunuz paylaşılıyor"
                      : "Güvenlik ağınızla konumunuzu paylaşın",
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: provider.isLocationSharing,
              onChanged: (value) {
                if (value) {
                  _showLocationShareOptions();
                } else {
                  provider.stopLocationSharing(manual: true);
                }
              },
              activeThumbColor: AppColors.info,
              activeTrackColor: AppColors.info.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Konum paylaşım süresi",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _buildShareOption("10 dakika", 10),
            _buildShareOption("30 dakika", 30),
            _buildShareOption("1 saat", 60),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(String label, int minutes) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      onTap: () {
        Navigator.pop(context);
        _startLocationSharing(minutes);
      },
    );
  }

  Future<void> _startLocationSharing(int minutes) async {
    final provider = context.read<HomeProvider>();
    HapticFeedback.lightImpact();
    final message = await provider.startLocationSharing(minutes);
    if (message != null && context.mounted) {
      provider.stopLocationSharing(manual: true);
      _showSnack(message);
    }
  }

  String _formatRemaining(DateTime? endAt) {
    if (endAt == null) return "";
    final remaining = endAt.difference(DateTime.now());
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    if (minutes <= 0) {
      return "${seconds}s";
    }
    return "${minutes}dk ${seconds}s";
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSafetyTips() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.tips_and_updates_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Güvenlik İpucu",
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                SizedBox(height: 5),
                Text(
                  "Telefonunuzu sallayarak veya panik butonunu basili tutarak acil durum baslatabilirsiniz.",
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
