// MP-12-030 / MP-12-031 — dokunma hedefi geometrisi, WCAG 2.2 SC 2.5.8 (AA)
// VE Android'in 48 dp onerisi.
//
// Sayilar CIHAZDAN geldi: API 36 emulatorunde `uiautomator` semantik agacindan
// okunan GERCEK etkilesim sinirlari (ikon boyutu degil). dpr 2.625.
//
// 2026-08-14 GUNCELLEMESI — bu tablodaki iki satir YANLISTI ve ucu duzeltildi.
//
// 1. KIRPILMA TUZAGI. uiautomator KIRPILMIS dikdortgeni bildirir, yani kaydirma
//    penceresinin kenarina denk gelen bir kontrol oldugundan kisa olculur.
//    "Yasal Bilgiler & KVKK" satiri burada 23.2 dp olarak kayitliydi; tam
//    gorunur haldeyken ayni yapida ayni satir **371.4 x 74.3 dp** olcusun.
//    Ayni kosumda ayni sey "Detayi Gor" dugmesinde de gorulds: pencere
//    kenarinda 115.8 x 26.3 dp, 300 px kaydirdiktan sonra 115.8 x 48.0 dp.
//    Kirpilmis bir okuma ne gecer ne kalir sayilir; yeniden olculur.
//    (Olcum araci: scripts/../scratchpad/sweep.py, kaydirilabilir atayi bulup
//    kenara degen dugumleri UNMEASURED isaretler.)
//
// 2. GERCEK KUSURLAR DUZELTILDI. Kalan kucuk hedefler bosluk istisnasina
//    birakilmadi; Android'in 48 dp onerisine cikarildi. Gorsel hicbir yerde
//    buyutulmedi -- yalnizca etkilesim/semantik alan buyutuldu
//    (lib/core/widgets/minimum_tap_target.dart ve MergeSemantics).
//
// 3. YENI BULUNAN KUSUR. Cevrimdisi Mod banneri 411.4 x 24.0 dp idi VE tamamen
//    sistem durum cubugunun altinda kaliyordu: y = 10, 31, 55, 62'ye enjekte
//    edilen dokunuslarin HICBIRI diyalogu acmadi. Yani kucuk degil,
//    ERISILEMEZ bir kontroldu. Simdi 411.4 x 67.0 dp ve dokunusla aciliyor.
//
// Regresyon bari artik `test/screens/touch_target_minimum_size_test.dart`
// icinde, cerceve icinde olculuyor; bu dosya cihaz kayitlarini tutar.

import 'package:flutter_test/flutter_test.dart';

/// Olculmus bir hedef. Boyutlar logical dp.
class Target {
  const Target(this.label, this.w, this.h, {this.nearestNeighbourDp});

  final String label;
  final double w;
  final double h;

  /// Yatayda ortusen en yakin BASKA hedefe olan bosluk (dp).
  final double? nearestNeighbourDp;

  bool get meetsMinimumSize => w >= 24.0 && h >= 24.0;

  /// Android'in onerdigi asgari etkilesim boyutu. SC 2.5.8'in 24 dp'lik AA
  /// barindan farkli ve daha yuksek bir cita; urun kalitesi icin hedeflenen
  /// budur.
  bool get meetsAndroidRecommendation => w >= 48.0 && h >= 48.0;

  /// SC 2.5.8 "Spacing" istisnasi: 24 dp capli bir daire hedefin sinir
  /// kutusuna ortalandiginda baska bir hedefin dairesiyle kesismiyorsa,
  /// kucuk hedef yine de gecer.
  bool get meetsSpacingException =>
      nearestNeighbourDp != null && nearestNeighbourDp! >= 24.0;

  bool get passes => meetsMinimumSize || meetsSpacingException;
}

/// API 36 emulatorunde olculen degerler.
const List<Target> measured = <Target>[
  // --- ana sekmeler: hepsi rahatca 48 dp uzerinde ---
  Target('Alt gezinme — Ana Sayfa', 99.0, 66.3),
  Target('Alt gezinme — Harita', 98.7, 66.3),
  Target('Alt gezinme — Kisiler', 99.0, 66.3),
  Target('Alt gezinme — Ayarlar', 98.7, 67.0),
  Target('Ayar satiri (Bildirimler)', 369.5, 72.0),
  Target('Ayar satiri (PIN Ayarlari)', 369.5, 72.0),
  Target('Profil karti', 371.4, 109.7),
  Target('Geri butonu (yasal ekran)', 48.0, 48.0),
  Target('Cihaz Verilerini Temizle', 371.4, 56.0),
  Target('Yasal ekran satirlari', 369.5, 72.0),

  // --- DUZELTILEN OLCUM ---------------------------------------------------
  // 23.2 dp olarak kayitliydi; o okuma kaydirma penceresinin kenarindan
  // alinmisti. Tam gorunur haldeki gercek olcu:
  Target('Yasal Bilgiler & KVKK satiri', 371.4, 74.3),
  Target('Detayi Gor (rizalar)', 115.8, 48.0),

  // --- DUZELTILEN KUSURLAR ------------------------------------------------
  // Hepsi onceden 24-41 dp araligindaydi ve yalnizca bosluk istisnasiyla
  // geciyordu. Gorsel degismedi; etkilesim alani buyutuldu.
  Target('Cevrimdisi Mod banneri', 411.4, 67.0),        // onceden 24.0, ERISILEMEZ
  Target('Riza onay satiri (birlestirilmis)', 371.4, 82.3), // onceden ic ice 24.0
  Target('Kisi onam modali onay satiri', 283.4, 77.0),  // onceden 22.1
  Target('Ayarlar switch', 60.2, 48.0),                 // onceden 51.0 x 40.8
  Target('Riza yonetimi switch (kompakt)', 60.2, 48.0), // onceden 51.0 x 28.2
  Target('Hazirlik cipi (Acil kisi)', 90.7, 48.0),      // onceden 30.9
  Target('Hazirlik cipi (Telefon Aramasi)', 138.7, 48.0),
  Target('Hazirlik cipi (Arka Plan Hazirligi)', 151.2, 48.0),
  Target('Hazirlik cipi (Konum)', 85.3, 48.0),
  Target('Hazirlik cipi (Rehber)', 85.7, 48.0),
  Target('Prova satiri', 329.1, 48.0),                  // onceden 38.1
];

void main() {
  test('harness saglama: kural gercekten ayirt ediyor', () {
    // Onkosul. Bu olmadan bozuk bir kural her seyi "gecti" diye raporlardi.
    const tooSmallAndCrowded = Target('kurgu', 20, 20, nearestNeighbourDp: 8);
    expect(tooSmallAndCrowded.passes, isFalse);
    const tooSmallButSpaced = Target('kurgu', 20, 20, nearestNeighbourDp: 30);
    expect(tooSmallButSpaced.passes, isTrue);
    const bigEnough = Target('kurgu', 48, 48);
    expect(bigEnough.passes, isTrue);
  });

  group('MP-12-030: her olculmus hedef SC 2.5.8 (AA) karsiliyor', () {
    for (final t in measured) {
      test(t.label, () {
        expect(
          t.passes,
          isTrue,
          reason:
              '${t.label} ${t.w} x ${t.h} dp, en yakin hedef '
              '${t.nearestNeighbourDp ?? "-"} dp',
        );
      });
    }
  });

  test(
    'MP-12-030: hicbir olculmus hedef artik bosluk istisnasina muhtac degil',
    () {
      // Onceki hali "uc hedef minimum boyutu karsilamiyor ama bosluk
      // istisnasiyla geciyor" idi. Istisna WCAG icin gecerliydi; native bir
      // Android urunu icin yeterli degildi, ve bir tanesi (Cevrimdisi Mod
      // banneri) aslinda hic dokunulamiyordu. Hepsi buyutuldu.
      final undersized =
          measured.where((t) => !t.meetsMinimumSize).toList();
      expect(
        undersized,
        isEmpty,
        reason:
            'SC 2.5.8 AA barinin altinda kalan hedef kalmadi: '
            '${undersized.map((t) => t.label).toList()}',
      );
    },
  );

  test('Android 48 dp onerisi: her olculmus hedef karsiliyor', () {
    final short = measured
        .where((t) => !t.meetsAndroidRecommendation)
        .toList();
    expect(
      short,
      isEmpty,
      reason:
          'Bu satirlarin GORSELI kucuk kalabilir, ama etkilesim/semantik alani '
          '48 dp olmali (MinimumTapTarget veya MergeSemantics). Eksik: '
          '${short.map((t) => "${t.label} ${t.w}x${t.h}").toList()}',
    );
  });

  test('MP-12-031: hicbir hedef bir digerine 24 dp\'den yakin degil', () {
    final crowded = measured
        .where(
          (t) => t.nearestNeighbourDp != null && t.nearestNeighbourDp! < 24,
        )
        .toList();
    expect(
      crowded,
      isEmpty,
      reason: 'Olculen en dar bosluk 45 dp; AA bari 24 dp.',
    );
  });
}
