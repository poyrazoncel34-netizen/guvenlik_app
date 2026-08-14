// ============================================================================
// ODAK HALKASI — klavye/switch kullanıcısı için görünür odak göstergesi
// ============================================================================
// NEDEN AYRI BİR WIDGET, neden Material'in kendi odak kaplaması yetmedi:
//
// Uygulamanın dokunmatik hedefleri `InkWell`. Material'in odak vurgusu
// `Material` yüzeyinin ÜZERİNE, ama çocuğun ALTINA çizilir. Ayar satırlarında
// çocuk saydam olduğu için vurgu görünüyor — fakat zayıf: ölçülen dolgu
// rgb(47,69,89), komşu renklere karşı 1.46-1.76:1. Profil kartı ve Pro
// satırında çocuk kendi opak/gradyan arka planını çizdiği için vurgu tamamen
// örtülüyor ve odak göstergesi HİÇ görünmüyor (odaklı ve odaksız pikseller
// birebir aynı: 1.00:1).
//
// HALKA SIRASI ÖLÇÜMLE SEÇİLDİ. İlk denemede koyu ton DIŞTA, primary İÇTEydi.
// Render edilmiş piksellerde profil kartında iki sınır da zayıf çıktı: dış ton
// sayfa arka planına karşı 1.14:1, iç ton kartın camgöbeğine karşı 1.15:1 --
// halka yalnızca kendi iç kenarı (8.77:1) sayesinde görünüyordu. Sıra ters
// çevrilince primary DIŞTA sayfa arka planına karşı, koyu ton İÇTE kartın
// camgöbeğine karşı çalışıyor ve her yüzeyde YÜZEYE KOMŞU bir sınır 3:1'i
// geçiyor. Kaynak renklere bakarak bu görülmüyordu.
//
// Bu yüzden halka çocuğun ÜSTÜNE çiziliyor: opak bir çocuk onu gizleyemez.
// İki tonlu, çünkü tek renk bu paletin tüm yüzeylerini geçemiyor
// (bkz. AppColors.focusRing yorumu).
//
// Halka yalnızca `hasFocus` iken çizilir. Dokunmatik kullanıcı odak almadığı
// için ekranda hiçbir piksel değişmez — CLAUDE.md kural 4'ün koruduğu görsel
// tasarım aynen kalır; değişen tek şey, şu anda BOZUK olan bir durumun
// göstergesi.

import 'package:flutter/widgets.dart';

import '../app_colors.dart';
import '../design_tokens.dart';

/// Çocuğuna bir [FocusNode] verir ve o node odaklandığında üstüne iki tonlu
/// bir odak halkası çizer.
///
/// Kullanım:
/// ```dart
/// FocusRing(
///   borderRadius: BorderRadius.circular(Radii.xl),
///   builder: (node) => InkWell(focusNode: node, onTap: ..., child: ...),
/// )
/// ```
class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.builder,
    required this.borderRadius,
  });

  /// Halkanın bağlanacağı node'u alan çocuk üretici.
  final Widget Function(FocusNode node) builder;

  /// Halkanın köşe yarıçapı — sardığı bileşenle aynı olmalı.
  final BorderRadius borderRadius;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  final FocusNode _node = FocusNode(debugLabel: 'FocusRing');
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_syncFocus);
  }

  void _syncFocus() {
    if (!mounted) return;
    if (_node.hasFocus != _focused) {
      setState(() => _focused = _node.hasFocus);
    }
  }

  @override
  void dispose() {
    // Dinleyici node'dan ÖNCE kaldırılıyor: bu dosyanın kardeşlerinde
    // dispose eksikliği daha önce gerçek bir bulgu olarak kaydedildi.
    _node.removeListener(_syncFocus);
    _node.dispose();
    super.dispose();
  }

  BorderRadius get _innerRadius {
    BorderRadius shrink(BorderRadius r) => BorderRadius.only(
      topLeft: _shrinkCorner(r.topLeft),
      topRight: _shrinkCorner(r.topRight),
      bottomLeft: _shrinkCorner(r.bottomLeft),
      bottomRight: _shrinkCorner(r.bottomRight),
    );
    return shrink(widget.borderRadius);
  }

  static Radius _shrinkCorner(Radius r) => Radius.elliptical(
    (r.x - FocusIndicator.outlineWidth).clamp(0.0, double.infinity),
    (r.y - FocusIndicator.outlineWidth).clamp(0.0, double.infinity),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.builder(_node),
        if (_focused)
          Positioned.fill(
            child: IgnorePointer(
              // Halka salt görsel: dokunma hedefini ve semantik ağacı
              // değiştirmemeli.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: Border.all(
                    color: AppColors.focusRing,
                    width: FocusIndicator.ringWidth,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(FocusIndicator.outlineWidth),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: _innerRadius,
                      border: Border.all(
                        color: AppColors.focusRingOutline,
                        width: FocusIndicator.outlineWidth,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
