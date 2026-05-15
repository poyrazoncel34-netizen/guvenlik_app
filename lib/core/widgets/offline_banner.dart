import 'dart:async';
import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// Global offline/online durum banner'ı.
///
/// Davranış:
/// - Online → Offline: Kırmızı banner üstte görünür, 3sn sonra küçülür → sabit ince şerit
/// - Offline → Online: Yeşil banner 2sn görünür, sonra kaybolur
/// - Acil durum akışı sırasında: Hiç gösterilmez (emergency flow bozulmasın)
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  StreamSubscription<bool>? _subscription;

  bool _isOffline = false;
  bool _showBanner = false;
  bool _showReconnected = false;

  Timer? _dismissTimer;
  Timer? _reconnectedTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // İlk durum
    _isOffline = !ConnectivityService.instance.isOnline;
    if (_isOffline) {
      _showBanner = true;
      _controller.value = 1.0;
    }

    _subscription = ConnectivityService.instance.onStatusChange.listen((
      online,
    ) {
      if (!mounted) return;
      if (!online) {
        _onWentOffline();
      } else {
        _onCameOnline();
      }
    });
  }

  void _onWentOffline() {
    _dismissTimer?.cancel();
    _reconnectedTimer?.cancel();
    setState(() {
      _isOffline = true;
      _showBanner = true;
      _showReconnected = false;
    });
    _controller.forward();

    // 3 saniye sonra tam banner'dan ince şeride geç
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isOffline) {
        setState(() => _showBanner = false);
        _controller.reverse();
      }
    });
  }

  void _onCameOnline() {
    _dismissTimer?.cancel();
    _reconnectedTimer?.cancel();
    setState(() {
      _isOffline = false;
      _showBanner = true;
      _showReconnected = true;
    });
    _controller.forward();

    // 2 saniye sonra banner'ı gizle
    _reconnectedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            setState(() {
              _showBanner = false;
              _showReconnected = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _subscription?.cancel();
    _dismissTimer?.cancel();
    _reconnectedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        widget.child,

        // Sürekli offline göstergesi — tam ekran olaylar yaşanmadığında sabit ince şerit
        if (_isOffline && !_showBanner)
          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            child: _OfflinePersistentBar(),
          ),

        // Animasyonlu banner — online/offline geçişlerinde
        if (_showBanner)
          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: _showReconnected
                  ? _OnlineBannerContent()
                  : _OfflineBannerContent(),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// Offline — tam banner (3 saniye)
// ============================================================
class _OfflineBannerContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(
        0xFFCC3333,
      ), // koyu kırmızı — AppTheme.emergency'den biraz koyu
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'İnternet bağlantısı yok',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const Text(
                  'Uygulama tam çalışmaya devam ediyor',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.3,
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

// ============================================================
// Bağlantı geri geldi — yeşil banner (2 saniye)
// ============================================================
class _OnlineBannerContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(
        0xFF1A9B7B,
      ), // koyu yeşil — AppTheme.success'ten biraz koyu
      child: Row(
        children: [
          const Icon(Icons.wifi_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          const Text(
            'Bağlantı yeniden kuruldu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Sürekli offline — sabit ince şerit (3sn banner kapandıktan sonra)
// ============================================================
class _OfflinePersistentBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFCC3333), Color(0xFFFF6666), Color(0xFFCC3333)],
        ),
      ),
    );
  }
}
