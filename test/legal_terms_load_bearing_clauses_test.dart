// Kullanım Sözleşmesi v4.0.0'ın TAŞIYICI hükümlerini pinler.
//
// v4.0.0 sözleşmeyi "sorumsuzluk kaydı" modelinden "dar edim tanımı" modeline
// geçirdi. O modelin tamamı birkaç cümleye yaslanıyor ve bu cümleler iyi niyetle
// -- "sadeleştirelim", "çok uzun oldu", "daha güçlü yazalım" -- silinebilecek
// türden. Silinirlerse geriye ayakta kalmayan bir sözleşme kalır ve bunu hiçbir
// mevcut test yakalamaz: sözleşme metnini İÇERİK düzeyinde denetleyen tek gate
// bu dosyadır.
//
// İki yönlü çalışır:
//   1. TAŞIYICI hükümler VAR olmalı (silinemez).
//   2. GEÇERSİZ hükümler YOK olmalı (geri eklenemez).
//
// (2) özellikle önemli: eski madde 9 "hiçbir zarardan sorumlu tutulamaz (can
// kaybı dahil)" diyordu. Bu ifade Tüketici Sözleşmelerindeki Haksız Şartlar
// Hakkında Yönetmelik EK-1'in BİRİNCİ bendine denk gelir -- tüketicinin ölümü
// veya yaralanması halinde sorumluluğu kaldıran şart -- ve TKHK m.5 uyarınca
// KESİN OLARAK HÜKÜMSÜZDÜR; hâkim resen atar. Yani en çok koruma sağladığı
// sanılan cümle, mahkemede ilk düşecek cümleydi. Geri gelmemeli.
//
// Gerekçelerin tamamı: docs/legal/sorumluluk-devri-analizi-2026-08-25.md
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/constants/legal_texts.dart';

/// `N. BAŞLIK` biçimindeki madde başlıklarını sayar. Alt numaralar (`3.2.`)
/// eşleşmez: desen, noktadan sonra boşluk ve ardından büyük harf bekler.
int _articleHeadingCount(String text) =>
    RegExp(r'^\d+\. [A-ZÇĞİÖŞÜ]', multiLine: true).allMatches(text).length;

/// [startHeading] ile [endHeading] arasindaki madde govdesini keser.
///
/// Bent sayimi bunsuz yapilamaz: `^[a-p]\) ` deseni Madde 5'in a-p listesini de,
/// Madde 8'in a-j listesini de yakalar. Ilk yazimda sayim 16 yerine 26 donuyordu
/// ve "Madde 5'ten bent dustu" iddiasi hicbir zaman kirmizi olmuyordu -- negatif
/// kontrol bunu yakaladi.
String _articleBody(String text, String startHeading, String endHeading) {
  final start = text.indexOf(startHeading);
  final end = text.indexOf(endHeading, start);
  expect(start, isNonNegative, reason: 'baslik bulunamadi: \$startHeading');
  expect(end, greaterThan(start), reason: 'bitis basligi bulunamadi: \$endHeading');
  return text.substring(start, end);
}

void main() {
  final termsTr = LegalTexts.termsOfServiceTr;
  final termsEn = LegalTexts.termsOfServiceEn;
  final mirror = File('store/kullanim_sartlari.html').readAsStringSync();

  group('v4 sözleşmesinin taşıyıcı hükümleri yerinde', () {
    // Her biri modelin bir kolonu. Silinirse model çöker.
    //
    // Parçalar her yüzeyin KENDİ yazımıyla pinlenir: düz metin olan Dart
    // sabitleri vurguyu BÜYÜK HARFLE yapar, HTML aynası `<strong>` ile yapar.
    // Aynı hüküm, farklı vurgu geleneği. Büyük/küçük harf duyarsız karşılaştırma
    // denenmedi çünkü Türkçe'de güvenilir değil: `İ`.toLowerCase() Unicode'da
    // `i` + birleşen nokta üretir ve düz `i` ile eşleşmez.
    const loadBearingTr = <String, String>{
      'EDİMİN KAPSAMI VE NİTELİĞİ': 'edim tanımı başlığı -- modelin girişi',
      'SONUÇ BORCU': 'edimin özen borcu olduğunu söyleyen çekirdek kavram',
      'Taahhüt edilmemiş bir sonucun gerçekleşmemesi':
          'vaat edilmeyenin ihlal edilemeyeceği cümlesi',
      'BELGELENMİŞ ÇALIŞMA SINIRLARI':
          'ayıp iddiasını tetikleyicisinden kapatan madde',
      'ayıp, kusur veya eksik ifa SAYILMAZ':
          'çalışma sınırlarının ayıp olmadığını söyleyen cümle',
      'KULLANICININ DOĞRULAMA YÜKÜMLÜLÜĞÜ':
          'TBK m.52 zemini -- zarar görenin kusuru',
      'ağır ihmali':
          'TBK m.115 istisnası -- yoksa sorumluluk maddesi bütünüyle düşer',
      'KENDİ YERLEŞİM YERİNDEKİ': 'TKHK m.73/5 -- emredici tüketici yetkisi',
    };

    loadBearingTr.forEach((fragment, why) {
      test('TR: "$fragment" korunuyor', () {
        expect(termsTr, contains(fragment), reason: why);
      });
    });

    const loadBearingEn = <String>[
      'SCOPE AND NATURE OF THE OBLIGATION',
      'NO OBLIGATION OF RESULT',
      'DOCUMENTED OPERATING LIMITS',
      'do NOT constitute a defect',
      "THE USER'S VERIFICATION DUTY",
      'gross negligence',
      'AT THEIR OWN PLACE OF RESIDENCE',
    ];

    for (final fragment in loadBearingEn) {
      test('EN: "$fragment" korunuyor', () {
        expect(termsEn, contains(fragment));
      });
    }

    test('HTML aynası da taşıyıcı hükümleri içeriyor', () {
      for (final fragment in const [
        'SONUÇ BORCU',
        'Belgelenmiş Çalışma Sınırları',
        'ayıp, kusur veya eksik ifa sayılmaz',
        'Doğrulama Yükümlülüğü',
        'ağır ihmali',
        'kendi yerleşim yerindeki',
      ]) {
        expect(
          mirror,
          contains(fragment),
          reason: 'HTML aynasında eksik: $fragment',
        );
      }
    });
  });

  group('geçersiz hükümler geri eklenemez', () {
    // Bunlar Haksız Şartlar Yönetmeliği EK-1 (a) kapsamına girer ve TKHK m.5
    // uyarınca kesin hükümsüzdür. Sözleşmede bulunmaları koruma sağlamaz;
    // aksine, düştüklerinde yerlerine geçecek daha dar bir hüküm bırakmazlar.
    const forbidden = <String, String>{
      'hiçbir zarardan': 'blanket zarar reddi -- EK-1 (a), kesin hükümsüz',
      'can kaybı': 'ölüm sorumluluğunu kaldırma -- EK-1 (a), kesin hükümsüz',
      'loss of life': 'aynısının İngilizcesi',
      'İzmir Mahkemeleri': 'TKHK m.73/5 emredici; tüketiciye karşı işlemez',
    };

    forbidden.forEach((fragment, why) {
      test('"$fragment" hiçbir yüzeyde yok', () {
        final violations = <String>[];
        if (termsTr.contains(fragment)) violations.add('termsOfServiceTr');
        if (termsEn.contains(fragment)) violations.add('termsOfServiceEn');
        if (mirror.contains(fragment)) {
          violations.add('store/kullanim_sartlari.html');
        }
        expect(violations, isEmpty, reason: why);
      });
    });
  });

  group('yapısal parite', () {
    test('TR ve EN aynı sayıda madde taşıyor', () {
      final tr = _articleHeadingCount(termsTr);
      final en = _articleHeadingCount(termsEn);
      expect(tr, 19, reason: 'TR madde sayısı v4.0.0 için 19 olmalı');
      expect(en, tr, reason: 'EN aynası TR ile aynı madde sayısını taşımalı');
    });

    test('HTML aynası da 19 madde taşıyor', () {
      final count = RegExp(r'<h2>Madde \d+ —').allMatches(mirror).length;
      expect(count, 19, reason: 'HTML aynası Dart metniyle aynı yapıda olmalı');
    });

    test('Madde 5 çalışma sınırları listesi 16 bent taşıyor', () {
      // Liste ne kadar eksiksizse "makul beklenti" o kadar dar tanımlanır ve
      // ayıp iddiasının yüzeyi o kadar küçülür. Bent silmek korumayı azaltır.
      //
      // Sayım MADDE 5'e sınırlı: belge genelinde `a)` ile başlayan iki liste var
      // (Madde 5 a-p, Madde 8 a-j) ve toplam sayım bent düşüşünü gizliyordu.
      final body = _articleBody(
        termsTr,
        '5. BELGELENMİŞ ÇALIŞMA SINIRLARI',
        '6. KULLANICININ DOĞRULAMA YÜKÜMLÜLÜĞÜ',
      );
      final bullets =
          RegExp(r'^[a-p]\) ', multiLine: true).allMatches(body).length;
      expect(
        bullets,
        16,
        reason: 'Madde 5 listesinden bent düşmüş veya eklenmiş',
      );
    });

    test('sözleşme sürümü v4 hattında', () {
      expect(
        LegalTexts.termsVersion,
        startsWith('4.'),
        reason: 'Edim tanımı modeli v4 ile geldi; majör düşüş modeli geri alır',
      );
    });
  });
}
