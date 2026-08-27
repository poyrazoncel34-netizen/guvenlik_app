// ============================================================================
// CONSENT MANAGER — Kabul edilen metnin SHA-256 ozeti
// ============================================================================
// Riza kaydi zaten consentTextVersion tasiyordu: "kullanici v4.0.0'i kabul
// etti". Eksik olan, v4.0.0'IN NE OLDUGUYDU.
//
// Ayrim uyusmazlikta onemli. Depodaki metni surum pini ve icerik testleri
// dogrular; ama bunlar DEPOYU kanitlar, kullanicinin ekraninda goruneni degil.
// Hash o boslugu kapatir: kabul aninda gosterilen baytlarin ozeti kaydin
// icinde durur.
//
// Ispat yuku bu urunde sorumludadir -- TKHK m.10 (teslimden itibaren alti ay)
// ve Yargitay HGK'nin illiyet bagi ictihadi (kesildigi iddiasi acikca
// ispatlanmadikca kabul edilmez). Ispatlanamayan bir savunma yoktur.
//
// Bu test hash'in DEGERINI pinlemez -- oyle yapsaydi her legal metin
// duzenlemesinde kirilirdi ve koruma degil gurultu olurdu. Pinlenen, DOGRU
// metnin ozetlendigi ve dogru dilin secildigidir.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/constants/legal_texts.dart';
import 'package:guvenlik_app/models/consent_record.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _sha(String text) => sha256.convert(utf8.encode(text)).toString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const consentLogKey = 'kvkk_consent_log_v2';
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (MethodCall call) async {
          // Eski keystore gunlugu yok: migrasyon sessizce atlanir.
          if (call.method == 'read') return null;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
  });

  Future<List<ConsentRecord>> logAfter(
    Future<void> Function(ConsentManager cm) act,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cm = ConsentManager();
    await act(cm);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(consentLogKey) ?? '[]';
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => ConsentRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  test('sozlesme rizasi, gosterilen TR metninin ozetini tasir', () async {
    final log = await logAfter(
      (cm) => cm.grantConsent(ConsentRecord.typeTerms, locale: 'tr'),
    );
    final rec = log.firstWhere((r) => r.consentType == ConsentRecord.typeTerms);
    expect(rec.consentTextHash, isNotEmpty);
    expect(
      rec.consentTextHash,
      _sha(LegalTexts.termsOfServiceTr),
      reason: 'TR kabulunde TR metni ozetlenmeli',
    );
    expect(rec.consentTextVersion, LegalTexts.termsVersion);
  });

  test('dil degisince ozetlenen metin de degisir', () async {
    final log = await logAfter(
      (cm) => cm.grantConsent(ConsentRecord.typeTerms, locale: 'en'),
    );
    final rec = log.firstWhere((r) => r.consentType == ConsentRecord.typeTerms);
    expect(
      rec.consentTextHash,
      _sha(LegalTexts.termsOfServiceEn),
      reason: 'EN kabulunde EN metni ozetlenmeli -- kullanici onu gordu',
    );
    expect(
      rec.consentTextHash,
      isNot(_sha(LegalTexts.termsOfServiceTr)),
      reason: 'Iki dilin ozeti ayni cikiyorsa dil secimi yapilmiyor demektir',
    );
  });

  test('KVKK rizasi aydinlatma metninin ozetini tasir', () async {
    final log = await logAfter(
      (cm) => cm.grantConsent(ConsentRecord.typeKvkk, locale: 'tr'),
    );
    final rec = log.firstWhere((r) => r.consentType == ConsentRecord.typeKvkk);
    expect(rec.consentTextHash, _sha(LegalTexts.kvkkDisclosureTr));
  });

  test('uzun metni olmayan riza turunde ozet bos kalir', () async {
    // Yas beyani, konum, sahte cagri gibi turlerin ozetlenecek bir sozlesme
    // metni yoktur. Bos birakmak, olmayan bir metnin ozetini uydurmaktan
    // durusttur.
    final log = await logAfter(
      (cm) => cm.grantConsent(ConsentRecord.typeLocation, locale: 'tr'),
    );
    final rec = log.firstWhere(
      (r) => r.consentType == ConsentRecord.typeLocation,
    );
    expect(rec.consentTextHash, isEmpty);
  });

  test('alan eklenmeden once yazilmis kayitlar hala okunur', () {
    // Sema hosgorusu: eski kayitlarda bu alan yoktur ve bos okunmalidir.
    // Aksi halde alan eklemek, mevcut kullanicilarin riza gunlugunu okunamaz
    // hale getirirdi.
    final legacy = ConsentRecord.fromJson(<String, dynamic>{
      'consentType': ConsentRecord.typeTerms,
      'granted': true,
      'timestamp': DateTime(2026, 3, 1).toIso8601String(),
      'appVersion': '1.0.0',
      'osVersion': 'Android 14',
      'deviceModel': 'test',
      'consentTextVersion': '3.1.0',
      'locale': 'tr',
    });
    expect(legacy.consentTextHash, isEmpty);
    expect(legacy.consentTextVersion, '3.1.0');
  });
}
