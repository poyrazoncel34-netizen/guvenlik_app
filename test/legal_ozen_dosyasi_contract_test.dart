// Özen Dosyası'nın taşıyıcı bölümlerini ve GERÇEKLE uyumunu pinler.
//
// NEDEN. docs/legal/ozen_dosyasi.md, TBK m.115'in bıraktığı boşluğu doldurmak
// için var: sözleşme kast ve ağır ihmali kapatamaz, dolayısıyla savunma bir
// kusurun "ağır" tarafa geçmemesine bağlıdır. Dosya bunun kaydıdır.
//
// Dosyanın değeri DÜRÜSTLÜĞÜNDEN gelir. En büyük risk, bir temizlik turunda
// "Doğrulanmamış olanlar" bölümünün kısaltılması veya güzelleştirilmesidir:
// eksiksiz görünen bir özen dosyası, özen dosyası değildir ve savunma
// delilinden ALEYHE delile döner.
//
// KASTEN PİNLENMEYEN ŞEY: tam test sayısı gibi ölçümler. Onları pinlemek her
// yeni testte kırılan bir kapı üretirdi -- koruma değil gürültü. Pinlenen,
// bölümlerin VARLIĞI ve başka bir belgeyle ÇELİŞMEMESİDİR.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dossier = File('docs/legal/ozen_dosyasi.md').readAsStringSync();
  final safetyCase = File('docs/release/safety_case.md').readAsStringSync();

  group('taşıyıcı bölümler duruyor', () {
    const required = <String, String>{
      'TBK m.115 ayrımı -- dosyanın varlık sebebi': 'Hafif ihmal mi, ağır ihmal mi?',
      'hafif kusur sınırlamasının neden geçerli olduğu': 'izne tabi bir meslek değildir',
      'ağır ihmalin somut emsali': 'Manavgat',
      'ölçülen aygıt envanteri': '## 4. Ölçülen özen aygıtı',
      'aygıtın kendi hatalarını yakaladığı kayıt': '## 6.',
      'dürüstlük bölümü': '## 7. Doğrulanmamış olanlar',
      'dosyayı yok edecek şeyler': '## 8.',
    };
    required.forEach((why, fragment) {
      test(why, () => expect(dossier, contains(fragment), reason: why));
    });
  });

  group('dürüstlük bölümü zayıflatılamaz', () {
    test('doğrulanmamış kalemler tek tek adlandırılıyor', () {
      // Genel bir "bazı şeyler doğrulanmadı" cümlesi yeterli DEĞİL; her kalem
      // adıyla durmali ki okuyan neyin bilinmedigini gorebilsin.
      for (final item in const [
        'NO_GO',
        'Doze',
        'Billing yaşam döngüsü',
        'Panik→arama süresi',
      ]) {
        expect(
          dossier,
          contains(item),
          reason: '§7 doğrulanmamış kalemi kaybetmiş: $item',
        );
      }
    });

    test('§7 gövdesi kısaltılmamış', () {
      final start = dossier.indexOf('## 7. Doğrulanmamış olanlar');
      final end = dossier.indexOf('## 8.', start);
      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final body = dossier.substring(start, end);
      // Alt sinir bilerek dusuk: amac uzunluk dayatmak degil, bolumun tek
      // cumleye indirgenmesini yakalamak.
      expect(
        body.split('\n').where((l) => l.trim().startsWith('-')).length,
        greaterThanOrEqualTo(4),
        reason: '§7 madde sayısı düşmüş; bölüm güzelleştirilmiş olabilir',
      );
    });
  });

  group('başka belgeyle çelişmiyor', () {
    test('safety_case NO_GO derken özen dosyası da öyle diyor', () {
      // safety_case GO'ya donerse bu dosya da guncellenmeli. Iki belgenin
      // farkli seyler soylemesi, ozen dosyasini aleyhe delile cevirir.
      final caseIsNoGo = safetyCase.contains('NO_GO');
      final dossierSaysNoGo = dossier.contains('NO_GO');
      expect(
        dossierSaysNoGo,
        caseIsNoGo,
        reason: caseIsNoGo
            ? 'safety_case.md NO_GO diyor ama özen dosyası bunu taşımıyor'
            : 'safety_case.md artık NO_GO değil; özen dosyası §7 güncellenmeli',
      );
    });

    test('ölçümlerin tarihi yazılı -- sayılar tarihsiz iddia değil', () {
      expect(
        dossier,
        contains('2026-08-27'),
        reason: 'Ölçüm tarihi kayıp; tarihsiz sayı iddiadır, ölçüm değildir',
      );
    });
  });
}
