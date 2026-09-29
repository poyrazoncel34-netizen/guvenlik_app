# KoruBeni Finalization — Aşama 7

**Tarih:** 2026-09-29
**Dal:** `codex/evidence-remediation-20260911`
**HEAD:** `37ded42b524b9755d068fe63e1ff898a9c9cfd6d`
**Sonuç:** `BLOCKED` — emulator/widget/manual yapılabilen kapsam tamamlandı;
gerçek fiziksel cihazda TalkBack çalıştırılmadı.

Bu rapor Aşama 5 veya Aşama 6'yı kapatmaz. Önceki dış kanıt eksikleri aynen
korunur:

```text
STAGE_5=BLOCKED
STAGE_6=BLOCKED
```

## 1. Makine sayımı ve kapanış özeti

`docs/release/final_completion_matrix.md` tablo satırları makineyle parse edildi.
Eski `208` değeri kullanılmadı. Aşama başlangıcındaki `A6-gorsel` kaynak kümesi
116 benzersiz ID'dir; matris ve Interaction Inventory kümeleri 409/409 birebir
eşleşmektedir.

```text
VISUAL_REQUIRED=116
VISUAL_PROVEN=116
VISUAL_FAILED=0
VISUAL_UNTESTED=0

SEMANTICS=PASS_EMULATOR_AND_WIDGET
TEXT_SCALE=PASS
LAYOUT_OVERFLOW=PASS
ASSETS=PASS
PHYSICAL_TALKBACK=BLOCKED

TALKBACK_PHYSICAL_BLOCKED=11/11
409_IDS_ACCOUNTED=409/409

STAGE_5=BLOCKED
STAGE_6=BLOCKED
STAGE_7=BLOCKED
```

`VISUAL_PROVEN` fiziksel TalkBack PASS anlamına gelmez. Bu sayı, başlangıçtaki 116
`A6-gorsel` satırının gerçek production widget render/davranış kanıtı ile ve
yüksek riskli ekran/state ailelerinin aynı çalışma ağacından üretilen emulator
ekran görüntüsü/XML kanıtıyla yeniden doğrulandığını ifade eder. Kaynak metni,
grep veya replika widget tek başına kanıt sayılmadı. Eski
`layout_size_matrix_test.dart` replika ekranları bu sayıya dahil edilmedi.

Kapanışta 115 saf-görsel satır `A1-kapandi/KAPANDI` oldu. `RIZA-13`ün görsel
alt gereksinimi de PASS, fakat canlı web sürüm eşleşmesi A-004 açık olduğundan
satır kapanmadı. Son matris dağılımı `A1=240, A4=54, A5=99, A6=1, A7=15`;
`KAPANDI=240, ACIK=169`dır.

### 116 görsel ID

```text
BOOT-08,
RIZA-01,RIZA-02,RIZA-03,RIZA-04,RIZA-05,RIZA-06,RIZA-07,RIZA-08,RIZA-09,RIZA-10,RIZA-13,
ONB-01,ONB-03,ONB-04,ONB-06,ONB-07,ONB-08,ONB-10,ONB-11,ONB-13,ONB-14,
PIN-02,PIN-03,PIN-04,PIN-05,
KLT-01,KLT-03,KLT-04,KLT-08,KLT-09,
NAV-01,NAV-02,NAV-03,NAV-04,NAV-07,NAV-08,
HOME-01,HOME-02,HOME-03,HOME-09,HOME-10,HOME-11,HOME-12,HOME-14,HOME-15,HOME-19,HOME-20,HOME-23,HOME-27,
PNK-01,PNK-03,PNK-04,PNK-06,PNK-07,PNK-09,PNK-14,
GS-04,GS-07,GS-08,GS-10,GS-11,GS-12,GS-13,GS-19,GS-20,GS-21,GS-22,
SNC-01,SNC-06,SNC-08,HZ-09,CHK-01,CHK-10,SWK-01,SWK-07,
FKC-05,FKC-08,FKC-09,FKC-11,FKC-13,
KSI-01,KSI-02,KSI-05,KSI-06,KSI-07,KSI-09,KSI-10,KSI-11,KSI-14,KSI-15,KSI-16,
MAP-02,MAP-08,GCM-01,GCM-02,GCM-03,GCM-05,OEM-03,
AYR-01,AYR-04,AYR-07,AYR-10,AYR-11,AYR-13,AYR-16,
PRF-01,PRF-02,PRF-03,PRF-04,PRF-05,
YSL-02,YSL-03,YSL-06,YSL-09,DEL-02
```

Küme 43 production yüzeye dağılır. En büyük gruplar UnifiedConsent (11), geri
sayım (9), ayarlar (7), panik butonu (6), kişiler (5) ve onboarding kişi adımıdır
(5). Matrisin her satırındaki `Son kanıt` gerçek ekran/davranış testine bağlandı;
tam test paketi bu çalışma ağacında yeniden çalıştırıldı.

## 2. Cihaz ve build bağı

- AVD: `KoruBeni_A017_API35_Play`
- Android: API 35
- Viewport: 1080×2400, 420 dpi; ayrıca küçük telefon viewport'u kullanıldı
- Font scale: 1.0 ve 2.0
- Ürün politikası: portrait-only; landscape senaryosu uydurulmadı
- APK komutu:
  `flutter build apk --debug --flavor play --target-platform android-arm64 --dart-define=ENV=production`
- APK SHA-256:
  `6f3cc7e31fceb1cbeb49423b4099851ba1cbd8efd2d4f7e22e5f3383a5cf8e25`

İlk birleşik build/hash denemesi Flutter cache izni yüzünden build'i
çalıştıramadı; shell ayıracı eski APK hash'i üretmişti. Bu çıktı kanıt olarak
reddedildi. Build tek başına izinli ortamda yeniden çalıştırıldı, `exit 0`
alındı ve yukarıdaki hash yalnız bu fresh sonuçtan üretildi.

## 3. Emulator/manual ekran-state matrisi

Aşağıdaki production ekran ve state'ler emulator üzerinde açıldı; scroll,
system back, dialog/sheet kapanışı, text scale, klavye ve semantics XML'i
incelendi:

- Unified Consent: normal, required/selected, 2× font, küçük viewport, scroll.
- Onboarding: sayfa 1–5, kişi rızası, kişi formu, Gboard açık, kayıt ve dönüş.
- PIN Setup/confirm: normal ve keypad semantics.
- Battery/OEM: izin diyaloğu, notification denied/degraded, skip.
- Home: degraded/offline görünüm, normal ve 2× font, hızlı eylemler.
- Contacts: normal, empty/add/select ve 2× font.
- Settings: üst/alt scroll.
- Data deletion: dialog, action erişimi, Android back ile kapanma ve scroll
  konumunun korunması.
- Paywall: offline/error; ilk viewport ve scroll sonrası restore/legal linkleri.
- Test Mode: gerçek production countdown, 10 saniyede tamamlanma ve Home'a dönüş;
  gerçek arama yapılmadı.
- AppUnlock: 2× font, tüm keypad, silme ve PIN unuttum erişimi.
- Free/locked: SOS ve SafeWalk quick action kilit durumu.

Gerçek Pro satın alma/entitlement üretilmedi. Bu Aşama 6 dış kanıtı olarak
sunulmadı. Check-In/SafeWalk production ekranlarının state kapsamı gerçek
production widget testleriyle çalıştırıldı; fiziksel cihaz veya Play kanıtı
olduğu iddia edilmedi.

Runtime kanıt klasörü:
`docs/audit/evidence/stage7-2026-09-28/` — 90 PNG/XML/log dosyası.

Önemli örnekler:

- `stage7-consent-small-scale2.png` / `.xml`
- `stage7-onboarding-ime-after-fix.png` / `.xml`
- `stage7-unlock-font2-semantics-fixed.png` / `.xml`
- `stage7-contacts-font2-overflow-fixed.png` / `.xml`
- `stage7-countdown-test-mode.png` / `.xml`
- `stage7-data-deletion-dialog.png` / `.xml`
- `stage7-paywall-scrolled.png` / `.xml`

## 4. Bulgu → düzeltme → regresyon

### S7-01 — yaş seçeneği selected semantics taşımıyordu

- Reproduce: Android semantics XML'de seçili yaş satırı `selected` değildi;
  widget testinde `Tristate.none` görüldü.
- Kök neden: Görsel seçim state'i Semantics'e aktarılmıyordu.
- Fix: seçenekler `button`, `selected` ve `inMutuallyExclusiveGroup` olarak
  işaretlendi.
- Regresyon: `unified_consent_behavior_test.dart`; final Android XML'de
  `selected=true`.

### S7-02 — onboarding kişi alanlarının erişilebilir adı boştu

- Reproduce: gerçek contact step semantics testinde TextField adları boştu.
- Kök neden: yalnız görsel label vardı.
- Fix: ad/telefon alanlarına Semantics label; görsel label'lara
  `ExcludeSemantics`.
- Regresyon: `accessibility_guidelines_test.dart` PASS.

### S7-03 — Gboard “Kişiyi kaydet” butonunu kapatıyordu

- Reproduce: gerçek emulator/Gboard ile buton keyboard altında 425 px kaldı.
- Kök neden: 180 ms IME settle süresi Gboard animasyonundan kısaydı.
- Fix: settle süresi 700 ms ve testte bounded polling.
- Regresyon: keyboard testi PASS; final runtime clearance 241 px.

### S7-04 — PIN Setup keypad button rolü ve silme adı eksikti

- Reproduce: semantics testinde sayı tuşunda `isButton=false`.
- Fix: sayı/silme tuşlarına button semantics, silme etiketi `Sil`.
- Regresyon: `pin_setup_layout_stability_test.dart` 7/7 PASS; emulator XML PASS.

### S7-05 — Contacts üst ekle aksiyonunun adı boştu

- Reproduce: runtime XML'de clickable elementin adı boştu.
- Fix: `contacts_add_person` tooltip'i.
- Regresyon: `contacts_page_behavior_test.dart`; runtime 2× font XML'de
  `Kişi Ekle`, `android.widget.Button`.

### S7-06 — AppUnlock ve live Countdown keypad rol/ad eksikleri

- Reproduce: AppUnlock runtime XML'de tuşlar `android.view.View`, silme adsız;
  iki kırmızı widget testinde `isButton=false`.
- Fix: button/enabled/onTap semantics, `excludeSemantics`, silme adı `Sil`.
- Regresyon: `app_unlock_behavior_test.dart` ve
  `countdown_accessibility_test.dart`; final emulator XML'de 11 tuşun tamamı
  `android.widget.Button`, clickable/enabled.

### S7-07 — Contacts 2× font RenderFlex overflow

- Reproduce: emulator üzerinde `RIGHT OVERFLOWED BY 19 PIXELS`; gerçek
  ContactsPage widget regresyonunda 411×914 ve scale 2.0 ile 537 px overflow.
- Kök neden: başlık ve acil kişi butonu sabit yatay Row'daydı.
- Fix: `ResponsiveContactsHeader`; scale ≥1.6'da dikey, normal ölçekte mevcut
  yatay tasarım.
- Regresyon: gerçek ContactsPage 2× font testi PASS; final screenshot'ta overflow
  şeridi yok, başlık ve buton görünür.

Dosya-boyutu ratchet ilk iki tam testte düzeltmeyi engelledi:
`countdown_screen.dart 1033→1047`, `contacts_page.dart 1153→1193`.
Test zayıflatılmadı. Header odaklı widget'a çıkarıldı ve ek semantics kodu
sıkılaştırıldı; son değerler `1031` ve `1153`. Ratchet + ilgili production ekran
testleri 14/14 PASS oldu.

## 5. Accessibility ve fiziksel TalkBack sınırı

Emulator/widget kapsamında label, button, header, text field, selected, disabled,
toggle, live region, dismiss/back ve traversal sırası kontrol edildi. Gerçek
TalkBack oturumu yapılmadı. Aşağıdaki 11 ana akışın tamamı fiziksel cihaz kuyruğunda
kalır:

1. onboarding
2. PIN
3. home
4. panic
5. countdown
6. contacts
7. Check-In
8. SafeWalk
9. paywall
10. settings
11. data deletion

```text
PHYSICAL_TALKBACK_BLOCKED
```

Emulator semantics PASS, fiziksel TalkBack PASS olarak sunulmadı. Bu nedenle
Aşama 7'nin nihai durumu `BLOCKED`tır.

## 6. Asset envanteri

Production asset taraması pubspec, Dart runtime referansları ve Android
resource density ailelerini kapsadı:

- Pubspec'teki dört production girdi (TR translation, iki WAV ve third-party
  notices) mevcut ve yüklenebilir.
- 114 Material glyph / 298 kullanım noktası envanterlendi.
- 11 launcher/resource icon dosyası ve 5 density ailesinin tüm gerekli bucket'ları
  mevcut.
- PNG header/boyut ve WAV dosya kontrolleri başarılı.
- Eksik path, decode sorunu, demo/dead referans veya yanlış density yok.

Read-only final ölçüm:

```text
ASSETS_READONLY violations=0
```

Negatif kontrol önce 0 ihlal baseline'ını ölçtü; sentetik bozulmada 5 ihlal
üretti: `assetBucketMissing` (1), `assetDensityMismatch` (2),
`demoAssetShipped` (1), `referencedAssetMissing` (1). Negatif kontrol `exit 0`.
Normal emitter dirty çalışma ağacına revision damgası basmayı reddetti (`exit 1`);
bu fail-closed davranış ölçüm hatası veya asset FAIL olarak yorumlanmadı.

## 7. Komut günlüğü ve önemli ham sonuçlar

Tüm komutlar repo kökünde çalıştırıldı. Commit/push/tag yapılmadı.

| Komut | Exit | Önemli ham çıktı |
|---|---:|---|
| `git branch --show-current` | 0 | `codex/evidence-remediation-20260911` |
| `git rev-parse HEAD` | 0 | `37ded42b524b9755d068fe63e1ff898a9c9cfd6d` |
| `git status --short` | 0 | Önceden var olan geniş dirty tree korundu |
| `git diff --stat` | 0 | Mevcut değişiklikler kaybedilmedi |
| `git diff` | 0 | Başlangıç diff'i incelendi |
| `git log -10 --oneline --decorate` | 0 | HEAD `37ded42` |
| seçili Aşama 7 widget testleri | 0 | ilk baseline `+338: All tests passed!` |
| `flutter build apk --debug --flavor play --target-platform android-arm64 --dart-define=ENV=production` | 0 | fresh production-config debug APK |
| ilk `flutter test --concurrency=1` | 1 | `+2039 -1`; source file size ratchet |
| ayrıntılı tam tekrar | 1 | aynı deterministik ratchet; hayali flake sayılmadı |
| ratchet + Countdown + Contacts testleri | 0 | `+14: All tests passed!` |
| final `flutter test --concurrency=1` | 0 | `+2040: All tests passed!` |
| `flutter test test/release/final_completion_matrix_parity_test.dart --concurrency=1` | 0 | `+6: All tests passed!`; 409/409 |
| `flutter analyze` | 0 | `No issues found! (ran in 3.6s)` |
| `./scripts/verify_release.sh` | 0 | `LOCAL_CANDIDATE_PASS`; `EXTERNAL_RELEASE_GATES_UNVERIFIED`; 2040 test; coverage PASS; lint/Kotlin/instrumentation PASS; 10/10 16 KB PASS |
| asset read-only ölçümü | 0 | `ASSETS_READONLY violations=0` |
| `git diff --check` | 0 | çıktı yok |

`verify_release` ayrıca smoke paket kimlikli, gerçek Play uygulamasına
yüklenemeyen bir AAB üretir. Bu AAB yalnız kod/smoke doğrulamasıdır; Play,
RevenueCat veya production yayın kanıtı sayılmadı.

## 8. Aşama 7'de değişen dosyalar

Production:

- `lib/screens/legal/unified_consent_screen.dart`
- `lib/screens/onboarding/onboarding_contact_step.dart`
- `lib/screens/pin_setup_screen.dart`
- `lib/screens/contacts_page.dart`
- `lib/screens/app_unlock_screen.dart`
- `lib/screens/countdown_screen.dart`
- `lib/core/widgets/responsive_contacts_header.dart`

Regresyon testleri:

- `test/screens/unified_consent_behavior_test.dart`
- `test/screens/accessibility_guidelines_test.dart`
- `test/screens/onboarding_contact_step_keyboard_test.dart`
- `test/screens/pin_setup_layout_stability_test.dart`
- `test/screens/contacts_page_behavior_test.dart`
- `test/screens/app_unlock_behavior_test.dart`
- `test/screens/countdown_accessibility_test.dart`

Kanıt/rapor:

- `docs/audit/evidence/stage7-2026-09-28/*`
- `docs/audit/finalization-stage7-2026-09-29.md`
- `docs/release/final_completion_matrix.md`

Yeni kullanıcı davranışı eklenmedi; Interaction Inventory'ye yeni ID gerekmedi.
Mevcut A-016 renk kararı otomatik olarak değiştirilmedi.
