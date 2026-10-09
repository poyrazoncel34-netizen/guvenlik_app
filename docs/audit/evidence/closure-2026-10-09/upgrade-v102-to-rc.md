# Yükseltme: v1.0.2 → HEAD, API 35 `KoruBeni_A017_API35` emulator-5554, 420 dpi, `-no-audio`

**Yol: debug → debug (aynı paket, aynı debug imza anahtarı).** Yayın imzalı v1.0.2 → RC yükseltmesi derlenemedi: Play release kapısı (`android/app/build.gradle.kts` `isProductionRevenueCatAndroidSdkKey`) gerçek bir `goog_` RevenueCat anahtarı istiyor; sahte anahtarla kapıyı aşmak yerine debug yolu seçildi → yayın imzalı yükseltme = EXTERNAL SYSTEM REQUIRED. R8/imza tarafı ayrı release smoke koşusunda.

- v1.0.2 debug: tag v1.0.2 = 1f4062e, sha256 `7f68e08d4a5fa4effe9124653146ee644cbbabfffe51649678e1054e006765db`, lastUpdateTime=2026-10-09 20:26:02
- v1.0.2 Pro'yu yalnız RevenueCat ile açıyor (çevrimdışı Pro işareti yok): v1.0.2'de panik/Check-In çalıştırılamadı → yükseltme, Pro'suz bir v1.0.2 kullanıcısının verisini kapsıyor.

## Yükseltme öncesi (v1.0.2) kullanıcı verisi
- onboarding + rıza (terms 3.1.0, KVKK 3.1.1), PIN 2468, acil kişi "Annem 05551234567" birincil (ana ekran: "Acil kişi hazır — Annem • 05551234567"), izinler verildi.
```
FlutterSecureKeyStorage.xml
FlutterSecureStorage.xml
FlutterSecureStorageConfiguration.xml
FlutterSharedPreferences.xml
id.flutter.background_service.xml
notification_plugin_cache.xml
ls: databases: No such file or directory
FlutterSharedPreferences anahtarları:
name="flutter.battery_optimization_wizard_dismiss_count" name="flutter.battery_optimization_wizard_snooze_until_ms" name="flutter.data_schema_version" name="flutter.foreground_localized_active_body_v1" name="flutter.foreground_localized_active_title_v1" name="flutter.foreground_localized_channel_description_v1" name="flutter.foreground_localized_channel_name_v1" name="flutter.kvkk_consent_log_v2" name="flutter.pref_age_verified" name="flutter.pref_consent_emergency_contacts" name="flutter.pref_consent_location" name="flutter.pref_consent_profile" name="flutter.pref_contact_consent_shown" name="flutter.pref_kvkk_version" name="flutter.pref_legal_disclaimer_accepted" name="flutter.pref_medical_cleanup_done" name="flutter.pref_notification_permission_prompted" name="flutter.pref_onboarding_done" name="flutter.pref_pin_setup_done" name="flutter.pref_terms_version" 
```

## Koşum 1 — kısa kilitle yükseltme (20:30)
v1.0.2'de 5 yanlış PIN → "Kilitli: 26s" (20:30:04) → `install -r` HEAD `ebe5acd` debug sha1 `cf4dccc2a4ba` (lastUpdateTime 20:30:05, 1 sn) → ilk ekran yeniden rıza ("Kurulum ve Onay", Sözleşme 4.0.0 — 25 Ağustos 2026, KVKK 3.4.0 — 19 Temmuz 2026; yasal sürüm değiştiği için beklenen) → rıza → **kilit ekranı** ("Uygulama kilidi. PIN ile açın.") — yükseltme uygulama kilidini atlatmıyor. Kilit rıza ekranındayken (26 s) doldu → bu koşum kilidin taşındığını KANITLAMIYOR. PIN 2468 → ana ekran "Acil kişi hazır — Annem • 05551234567", "Acil kişin kayıtlı, arama izni açık."; `pref_terms_version` 4.0.0, `pref_kvkk_version` 3.4.0.

## Koşum 2 — 240 s kilitle yükseltme (20:39) — `shots/upgrade_lockout_survives_ebe5acd.png`
Temiz v1.0.2 debug kurulum + aynı veri; v1.0.2'de kilit 25 → 56 → 116 → **236 s** (20:39:27). `install -r` HEAD (20:39:41–42).
| Zaman | Gözlem | Sonuç |
|---|---|---|
| 20:40:26 | yeniden rıza sonrası kilit ekranı: "Kilitli: 178s" (236 − 59 s geçen = tutarlı) | PASS — kilit yükseltmeyi aştı |
| 20:40:54 | doğru PIN: tuş takımı devre dışı (NOPAD), uygulama açılmadı | PASS |
| 20:41:03 | force-stop → aç: "Kilitli: 133s" | PASS |
| 20:43:17 | "Kilitli: 12s", doğru PIN açmadı | PASS |
| 20:43:47 | kilit bitti → doğru PIN açtı; "Acil kişi hazır — Annem • 05551234567" | PASS — veri korundu |

Kalıntı (LOW): v1.0.2'nin kilidi yalnız duvar anahtarıyla yazılmış (monoton anahtar yok) → yeni sürüm onu duvarla (en çok 15 dk tavanla) ölçer; yükseltmeden hemen sonra yeniden başlatma + saat ileri o TEK eski kilidi bitirebilir. Yükseltmeden sonra kaydedilen her kilit monotondur.

## Koşum 3 — yükseltilmiş kurulumda silahlı Check-In: süreç ölümü / force-stop / yeniden başlatma (20:44–20:47)
Pro: yalnız TEST amaçlı çevrimdışı çapa (root ile; ticari kanıt DEĞİL). Check-In 15 dk → native `armed`; `dumpsys alarm`: GRACE + DISPATCH için tam (`window=0 flags=0x5 exactAllowReason=permission`) + yedek (`flags=0x20`), GRACE +14 dk 51 sn.
| Adım | native durum | bekleyen alarm | Sonuç |
|---|---|---|---|
| `kill -9` | armed | 4 | PASS |
| yeniden aç | armed | 4 | PASS |
| `am force-stop` → aç | armed | 4 (son tarih aynı: GRACE 20:59:40) | PASS |
| `adb reboot` (uygulama AÇILMADAN, 20:46:26) | armed; boot alıcısı süreci çalıştı | 4 yeniden kuruldu, GRACE +13 dk 20 sn (= 20:59:46; yeniden türetmede ~6 s kayma) | PASS |
| aç → PIN → Kontrol Noktası | ekranda "12:32 Kalan süre" (20:46:59 → 20:59:31) | — | PASS |
| İptal Et → PIN 2468 → Doğrula | `cancelled` | 0 | PASS |
