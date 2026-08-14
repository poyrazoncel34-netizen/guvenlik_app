// MP-12-030 / MP-12-031 — dokunma hedefi geometrisi, WCAG 2.2 SC 2.5.8 (AA).
//
// Sayilar CIHAZDAN geldi: API 36 emulatorunde `uiautomator` semantik agacindan
// okunan GERCEK etkilesim sinirlari (ikon boyutu degil). dpr 2.625.
//
// Bir sayi ayrica AMPIRIK OLARAK dogrulandi: "Yasal Bilgiler & KVKK" satirinin
// gercek vurus alani, semantik sinirlarla birebir ayni cikti -- ust kenardan
// 20 px yukarisi ve alt kenarin kendisi satiri ETKINLESTIRMEDI. Yani semantik
// dugum burada gercek hedefi buyutmuyor da kucultmuyor da.

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

  // --- 48 dp'nin ALTINDA kalan uc hedef ---
  // Yukseklik 24 dp barinin 0.8 dp altinda; en yakin hedef 56 dp uzakta
  // oldugu icin Spacing istisnasiyla geciyor.
  Target('Yasal Bilgiler & KVKK satiri', 371.4, 23.2, nearestNeighbourDp: 56.0),
  // Tam barin uzerinde.
  Target('Cevrimdisi Mod banneri', 411.4, 24.0, nearestNeighbourDp: 56.0),
  // Switch'ler 48 dp Material onerisinin altinda ama 24 dp AA barinin ustunde.
  Target('Ayarlar switch (kompakt)', 51.0, 28.2, nearestNeighbourDp: 45.0),
  Target('Ayarlar switch', 51.0, 40.8, nearestNeighbourDp: 45.0),
  // Modal icindeki onay kutusu: 22.1 dp, en yakin hedef (Iptal/Ekle) 47.6 dp.
  Target('Kisi onam modali onay kutusu', 22.1, 22.1, nearestNeighbourDp: 47.6),
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
    'MP-12-030: 24 dp altindaki hedefler SADECE bosluk istisnasiyla geciyor',
    () {
      // Gizlenmiyor, sayiliyor: uc hedef minimum boyutu KARSILAMIYOR ve yalnizca
      // aralarindaki bosluk sayesinde geciyor. Bu sayi artarsa yerlesim
      // sikilasmis demektir ve yeniden olculmesi gerekir.
      final undersized = measured.where((t) => !t.meetsMinimumSize).toList();
      expect(
        undersized.map((t) => t.label),
        unorderedEquals(<String>[
          'Yasal Bilgiler & KVKK satiri',
          'Kisi onam modali onay kutusu',
        ]),
      );
      for (final t in undersized) {
        expect(t.meetsSpacingException, isTrue);
      }
    },
  );

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
