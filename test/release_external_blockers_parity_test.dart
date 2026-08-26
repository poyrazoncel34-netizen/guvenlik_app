// EXTERNAL_LAUNCH_BLOCKERS.md ile RESOLUTION_QUEUE.md arasindaki parite kapisi.
//
// NEDEN. Kuyruk her kosuda generate_resolution_queue.py ile URETILIYOR;
// blocker belgesi ise ELLE tutuluyor. Iki kaynak arasinda sessiz surukleme
// kacinilmazdi ve oldu: 2026-08-27'de denetlendiginde belge `ef40178`
// (2026-08-15) revizyonuna damgaliydi ve on iki gun geride kalmisti.
//
// Olculen sapma:
//   - Baslik "87 blocked ID" diyordu; belgede aslinda 76 benzersiz ID vardi.
//   - Kuyruktaki 109 maddenin 30'u HICBIR kategoride tarif edilmemisti --
//     prosedur, PASS olcutu ve sorumlu yazilmamisti. Dordu P1'di.
//   - Belgedeki 7 ID kuyrukta yoktu (TalkBack maddeleri kapanmisti).
//
// Bunun maliyeti dogrudan: operator Play Console'a bu belgeyle oturuyor.
// Eksik madde, yapilmayan is demek; bayat madde, bosuna yapilan is demek.
//
// Belgenin kendi vaadi de buydu ve tutmuyordu:
//   "The categories below carry every one of the ... IDs; no ID appears in
//    two categories."
// Bu test tam olarak o cumleyi calistirilabilir hale getirir.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Bir bolumun `- **Requirement IDs (N):**` listesindeki ID'ler.
///
/// Kapsam bilerek `- **Severity` satirinda biter: capraz atif gibi aciklayici
/// notlar ID listesinin DISINDA tutulur, yoksa bir nottaki atif gercek bir
/// girdi gibi sayilir ve "ayni ID iki kategoride" yanlis alarmi uretir.
Map<String, Set<String>> _sectionIds(String doc) {
  final result = <String, Set<String>>{};
  for (final m in RegExp(r'^## (E\d) —', multiLine: true).allMatches(doc)) {
    final rest = doc.substring(m.end);
    final ids = RegExp(
      r'- \*\*Requirement IDs[^\n]*\*\*(.*?)(?=\n- \*\*Severity)',
      dotAll: true,
    ).firstMatch(rest);
    if (ids == null) continue;
    result[m.group(1)!] = RegExp(r'MP-\d+-\d+')
        .allMatches(ids.group(1)!)
        .map((x) => x.group(0)!)
        .toSet();
  }
  return result;
}

void main() {
  final doc = File('EXTERNAL_LAUNCH_BLOCKERS.md').readAsStringSync();
  final queue = File('RESOLUTION_QUEUE.md').readAsStringSync();

  final queued = RegExp(r'^\| \d+ \| `(MP-\d+-\d+)` \|', multiLine: true)
      .allMatches(queue)
      .map((m) => m.group(1)!)
      .toSet();
  final sections = _sectionIds(doc);
  final described = <String>{for (final s in sections.values) ...s};

  test('kuyruktaki her madde bir kategoride tarif edilir', () {
    final missing = (queued.difference(described)).toList()..sort();
    expect(
      missing,
      isEmpty,
      reason: 'Bu maddelerin prosedürü, PASS ölçütü ve sorumlusu hiçbir yerde '
          'yazmıyor; operatör onları yapmadan yayına çıkar:\n${missing.join(", ")}',
    );
  });

  test('belgede kuyrukta olmayan madde kalmaz', () {
    final stale = (described.difference(queued)).toList()..sort();
    expect(
      stale,
      isEmpty,
      reason: 'Bu maddeler çözüldü ama belgede duruyor; operatörü boşa iş '
          'yapmaya gönderir:\n${stale.join(", ")}',
    );
  });

  test('aynı ID iki kategoride sayılmaz', () {
    final seen = <String, String>{};
    final dupes = <String>[];
    sections.forEach((code, ids) {
      for (final id in ids) {
        if (seen.containsKey(id)) {
          dupes.add('$id (${seen[id]} + $code)');
        } else {
          seen[id] = code;
        }
      }
    });
    expect(dupes, isEmpty, reason: dupes.join('\n'));
  });

  test('her bölümün başlığındaki sayı listesiyle tutar', () {
    // Arama BOLUM SINIRINA hapsedilir. Sinirlanmazsa firstMatch, kendi
    // bolumunde eslesme bulamadiginda belgenin geri kalanina tasar ve bir
    // SONRAKI bolumun sayisini o bolume atfeder. Ilk yazimda tam olarak bu
    // oldu: E5'in satiri "(0 directly; gates the evidence...)" bicimindedir,
    // duz (N) degildir, ve test E6'nin 14'unu E5'e yazdi.
    final heads =
        RegExp(r'^## (E\d) —', multiLine: true).allMatches(doc).toList();
    final mismatches = <String>[];
    for (var i = 0; i < heads.length; i++) {
      final code = heads[i].group(1)!;
      final end = i + 1 < heads.length ? heads[i + 1].start : doc.length;
      final body = doc.substring(heads[i].end, end);
      final claim =
          RegExp(r'- \*\*Requirement IDs \((\d+)\)').firstMatch(body);
      if (claim == null) continue; // E5: sayi degil, surec kapisi
      final declared = int.parse(claim.group(1)!);
      final actual = sections[code]?.length ?? 0;
      if (declared != actual) {
        mismatches.add('$code: başlık $declared, liste $actual');
      }
    }
    expect(mismatches, isEmpty, reason: mismatches.join('\n'));
  });

  test('belge başlığındaki toplam kuyrukla aynı', () {
    final total = RegExp(r'\| Blocked requirement IDs \| \*\*(\d+)\*\* \|')
        .firstMatch(doc);
    expect(total, isNotNull, reason: 'Başlık tablosundaki toplam satırı kayıp');
    expect(
      int.parse(total!.group(1)!),
      queued.length,
      reason: 'Belge başlığı gerçek blocker sayısını söylemiyor',
    );
  });
}
