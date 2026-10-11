# LR-1 — kaynakla celisen konum/gizlilik metinleri (2026-10-11)

Owner karari (ONAYLI): depodaki kaynakla uyusmayan faktuel hukuki/gizlilik metni
duzeltilecek; var olmayan **"konum oturumu"** ifadeleri kaldirilacak. Claude hukuki
uygunluk ILAN ETMEYECEK — teknik faktuel uyumsuzluk kapatilabilir, nihai hukuki/KVKK
degerlendirmesi **LEGAL REVIEW REQUIRED** olarak kalir.

## Once olculdu, sonra yazildi

Tam envanter: [`lr1-dataflow-inventory.md`](lr1-dataflow-inventory.md).
Calisma zamani: [`lr1-dataflow-api36.md`](lr1-dataflow-api36.md).

Ozet: konumu okuyan **tek** cagri `map_page.dart`'ta; konum alabilen tek kapi
`LocationConsentGate` ve o da yalniz `map_page.dart:215`'ten cagriliyor (basliginda
"NEVER call this on the panic / SOS / check-in path" yaziyor). Konum izni **geri
alinmisken** Check-In ve Guvenli Yuruyus silahlaniyor, Panik ucan uca calisip
Telecom istegini gonderiyor (0 → 1) — yani bu akislar konumu kullanmiyor.
Harita acilmadan OSM istegi **0**. Ham koordinat ne pcap'te ne de cihaz
depolamasinda bulunuyor.

## Kapsam: olculdu, tahmin edilmedi

Depo genelinde "konum oturumu" / "location session" taramasi 60+ dosyada esleme verdi.
Ayrildi:

| Sinif | Ne yapildi |
|---|---|
| Kullaniciya GORUNEN uygulama metni | 46 gorunur konum string'inden **yalniz 2'si** yanlisti: `legal_consent_location` ve `legal_consent_location_sub`. Duzeltildi (TR+EN). |
| Hukuki kaynak | `lib/constants/legal_texts.dart`: Kullanim Sartlari §12 basligi ve ilk maddesi, KVKK veri tablosu satiri, isleme amaclari, saklama suresi (TR+EN). |
| Yayimlanan hukuki aynalar | `store/kullanim_sartlari.html`, `store/aydinlatma_metni.html`, `store/privacy_policy.html`, `store/privacy_policy_en.html` + `.gh-pages-publish/` (script ile yeniden uretildi). |
| Magaza/Play metinleri | `google_play_listing.md`, `play_store_listing_{tr,en}.md`, `PLAY_CONSOLE_COPY_PASTE_PACK.md`, `CONTENT_RATING_ANSWERS.md`, `PLAY_REVIEWER_ACCESS_NOTES.md`, `DATA_SAFETY_FORM.md`, `PLAY_CONSOLE_RUNBOOK.html`, `privacy_policy_template.md`, `docs/play_console_declarations.md`, `docs/feature_matrix_verification.md`, `docs/kvkk_veri_isleme_envanteri.md`, `pubspec.yaml`. |
| Magaza ekran goruntusu uretici | `generate_premium_app_screenshots.py` "KONUM OTURUMU" basligi tasiyordu — magaza ekran goruntusu metnidir, yani kamuya acik. "HARITA" oldu. |
| **Dokunulmadi**: `docs/audit/**`, `AUDIT_REPORT.md`, `PRODUCTION_AUDIT.md`, `CHANGELOG` gecmisi, `docs/research/*` | Tarihsel olcum kayitlari. CERT2-05: gecmis kanit yeniden yazilmaz. |
| **Dokunulmadi**: 19 olu ceviri anahtari (`map_share_started`, `foreground_location_share_*` …) | Hicbir Dart dosyasindan referans edilmiyor. Silmek yerine BIRAKILDI: `y09_location_session_copy_test` zaten bir anahtar GORUNUR hale gelirse kiriliyor — bu, silmekten daha guclu bir koruma. |
| **Dokunulmadi**: `3.4.0` eslesmeleri (guava `33.4.0`, pub `synchronized@3.4.0`) | Hukuki surumle ilgisiz. |

## Hukuki surumleme — ve sonuclari

`scripts/bump_legal.sh` ile (elle pin duzenlenmedi):

| | ESKI | YENI |
|---|---|---|
| `termsVersion` | 4.0.0 | **4.1.0** |
| `kvkkVersion` | 3.4.0 | **3.5.0** |
| Terms tarihi | 25 Agustos 2026 | **11 Ekim 2026** |
| KVKK tarihi | 19 Temmuz 2026 | **11 Ekim 2026** |

**DEGISEN METIN**: Kullanim Sartlari §12 (baslik + ilk madde) ve KVKK aydinlatmasinin
konum satiri / isleme amaci / saklama suresi. Baska hukum degismedi; madde sayisi
degismedi (`legal_terms_load_bearing_clauses_test` yesil).

**KIMLER YENIDEN GORUR**: mevcut TUM kullanicilar. `splash_screen.dart` kayitli
`pref_terms_version` / `pref_kvkk_version` degerlerini sabitlerle karsilastirir; fark
varsa uygulama acilista `UnifiedConsentScreen`'e yonlenir.

**NE GECERSIZ OLUR — dikkat**: `UnifiedConsentScreen` onceki ISTEGE BAGLI onaylari
geri YUKLEMIYOR (`_consentLocation` vb. `false` baslar) ve `_complete()` isaretlenmeyen
her birini `revokeConsent` ile **geri aliyor**. Yani surum yukseltmesi, kullanici
yeniden isaretlemezse konum, acil kisi, profil ve sahte cagri onaylarini sifirlar.
Bu, bu duzeltmenin gercek ve kullaniciya gorunur bir yan etkisidir; sessizce
birakilmasin diye burada yaziyor.

**YALNIZ BILGILENDIRME (acik riza degil)**: KVKK aydinlatma metni — ekranda
"okudum/anladim" olarak alinir.
**ACIK RIZA GEREKTIREN**: yas beyani, Kullanim Sozlesmesi kabulu (zorunlu); konum,
acil kisi, profil, sahte cagri (istege bagli).

**HUKUKCUYA KALAN**: yeni metnin KVKK Md. 10 aydinlatma yeterliligi; konum isleme
icin "acik riza"nin dogru hukuki sebep olup olmadigi; surum yukseltmesinin istege
bagli onaylari sifirlamasinin kabul edilebilirligi; OSMF'ye yapilan aktarimin
Md. 9 degerlendirmesi. Claude bunlarin hicbirini onaylamadi.

## Data Safety — tasinan yeni bilgi

Uygulama ham koordinat GONDERMIYOR (pcap ile dogrulandi). Ancak gonderilen karo
`z/x/y`, kullanicinin **baktigi alani** belirler; harita kullanicinin uzerine
ortalandiginda bu alan onun konumudur. Olculen zoom'larda (15 ve 16), 41°N'de bir karo
**0.85 km²** ve **0.21 km²** — ikisi de Google Play'in **HASSAS (<3 km²)** bandinda.
`store/DATA_SAFETY_FORM.md` bunu artik acikca yaziyor; "GPS gonderilmiyor" tek basina
eksik bir beyan olurdu. OSMF bir "service provider" varsayilmadi.

## Dogrulama

| Kapi | Sonuc |
|---|---|
| `flutter analyze --no-fatal-infos` | 0 sorun |
| `flutter test --no-pub` | **2607/2607** |
| Politika testleri (`release_readiness_policy`, `store_release_docs`, `public_release_overclaim_copy`, `legal_no_first_responder_claims`) | yesil — zayiflatilmadi |
| `y09_location_session_copy_test` | muafiyet listesi **BOSALTILDI**; 4 yeni iddia eklendi (kaynak, yayimlanan aynalar, pozitif "konum kullanmaz" cumlesi) |
| Karsi-olgusal mutantlar | **10/10 OLDURULDU** (`mutants/lr1-mutants-final.txt`) |
| `bump_legal.sh` artik-deger taramasi | temiz |
| Yayimlanan ayna ↔ kaynak byte esitligi | yesil |

Bir politika testi kirmizi dondu ve hakliydi: EN tanitim cumlem
"Free map, fake call and siren; optional Pro safety tools" — overclaim muhafizi bunu
"siren Pro'ya ozel" diye okudu (siren UCRETSIZ). Cumle duzeltildi.

## Hukum

- **LR-1 TECHNICAL FACTS: CLOSED.** Kaynakta olmayan hicbir konum iddiasi kullaniciya
  gorunen veya kamuya acik hicbir yuzeyde kalmadi.
- **LR-1 LEGAL: LEGAL REVIEW REQUIRED.** Yukaridaki "HUKUKCUYA KALAN" maddeleri.
