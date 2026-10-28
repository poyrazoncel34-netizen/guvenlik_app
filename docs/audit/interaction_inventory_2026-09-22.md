<!--
  PROVENANCE — bu dosya nasil olustu (okumadan once bilinmesi gereken)
  ------------------------------------------------------------------
  Icerik 2026-09-22 tarihli kesif turunda uretildi ve o turda DEPO DISINDA,
  oturum scratchpad'inde tutuldu (r0_head / r1_table_a..f / r2 / r3 / r4 / r5).
  Scratchpad gecici dizindeydi ve silindi; dosyalar 2026-09-23'te o oturumun
  transcript'indeki Write/Edit cagrilarindan, cagri sirasiyla yeniden kuruldu
  (Write = tam icerik, ardindan 4 Edit sirayla uygulandi, hepsi eslesti).

  Yeniden kurulumun dogrulugu iki bagimsiz sayimla olculdu:
    - 409 benzersiz ID, 0 tekrar, her satir tam 17 sutun;
    - durum dagilimi orijinal ozet bolumuyle birebir ayni
      (KANITLI 44, KISMEN KANITLI 146, DOGRULANMADI 183, OLU 16,
       DIS SISTEM 20; Fiz=E 119, Play=E 37, Gorsel=E 208).
  Ozet bolumu (Bolum 9) dosyanin kendi icinde yer aliyor ve tablodan bagimsiz
  yazilmisti; iki sayim ayni cikiyor.

  Icerige HICBIR EKLEME YAPILMADI. Tek degisiklik bu yorum blogudur.
  Envanter HEAD a099b4a + commit edilmemis WIP agacini olcer; o agac artik
  baseline commit'e alindi, yani bu dosya o commit'in davranis fotografidir.
-->

# KoruBeni — Eksiksiz Etkileşim Envanteri (Keşif Raporu)

> **Final completeness re-audit — 2026-09-29:** Güncel kirli çalışma ağacındaki
> 173 production Dart dosyası, 60 screen/widget dosyası, 33 main Kotlin dosyası,
> dört manifest; callback, dialog/sheet/snackbar, navigation, Android component,
> intent-filter, MethodChannel ve EventChannel yüzeyleri yeniden tarandı.
> HEAD sonrası iki yeni production dosyası mevcut `GCM` restoration ve `KSI`
> responsive-header davranışlarını uygular; yeni kullanıcı davranışı eklemez.
> Yeni veya sessizce kaldırılmış davranış bulunmadı. Envanter ve final matris
> 409 benzersiz ID ile birebir eşleşmeye devam eder. Ayrıntılı tarama kaydı:
> `docs/release/final/evidence_manifest.md`.

**Tarih:** 2026-09-22 · **Tür:** keşif / envanter — bu turda HİÇBİR kod, test, bağımlılık veya config değiştirilmedi.
Rapor depo dışında (`scratchpad`) üretildi; çalışma ağacı öncesi/sonrası `git status --short` karşılaştırıldı: **değişmedi**.

## 0. Repo durumu (istenen komutların çıktısı)

```
$ git branch --show-current      → codex/evidence-remediation-20260911
$ git rev-parse --short HEAD     → a099b4a
$ git log -1 --oneline           → a099b4a docs(audit): A-001 duzeltmesinin cihaz kaydi (emulator, negatif kontrollu)
$ git status --short             → 25 değiştirilmiş (M) + 10 izlenmeyen (??) yol; commit edilmemiş WIP var:
   M CHANGELOG.md, MainActivity.kt, config/release_change_classification.json, app_environment.dart,
     emergency_platform_channel.dart, emergency_platform_service.dart, emergency_readiness_service.dart,
     panic_arm_policy.dart, revenue_cat_service.dart, main.dart, settings_provider.dart, countdown_screen.dart,
     edit_profile_screen.dart, profile_page.dart, settings_page.dart, device_security_service.dart, + 9 test/script
  ?? AUDIT_REPORT.md, android/.../integrity/ (main+test+androidTest), docs/audit/device-verification-2026-09-22-a017-integrity-probe.md,
     profile_email_cleanup_service.dart, startup_best_effort_services.dart, + 4 test dosyası
```

**Önemli:** Bu envanter **HEAD + commit edilmemiş WIP** üzerindedir. Aşağıdaki her "KANITLI" satırı bu karma ağaca aittir;
hiçbir cihaz kaydı bu ağacı ölçmemiştir (en yeni cihaz kaydı `a099b4a`+WIP'in A-017 probu, diğerleri daha eski commit'ler).

## 1. Okunanlar ve çalıştırılanlar

- Okundu: `AUDIT_REPORT.md` (1248 satır), `CLAUDE.md`, `.claude/rules/common/*`, `docs/audit/device-verification-*` (14 kayıt), `telefon-testi-protokolu-2026-09-14.md`.
- Tarandı: `lib/` altında 169 Dart dosyası (40.063 satır), `android/app/src/main` altında 33 Kotlin dosyası (4.586 satır), ana + flavor manifest'leri, bugün derlenmiş `playDebug` birleşik manifest'i.
- Test yapısı: `test/` altında **319** `_test.dart` dosyası; Kotlin JVM testleri 16 dosya; instrumentation 6 dosya (12 `@Test`).
- **Çalıştırıldı (kod değiştirmez):**
  - `flutter test --no-pub` → **`01:05 +1885: All tests passed!` EXIT=0** (mevcut çalışma ağacı).
  - `./gradlew :app:testPlayDebugUnitTest` → **EXIT=0, 119 test, 0 hata** — dürüst not: Gradle görevi `UP-TO-DATE` idi, yani testler yeniden koşmadı; sonuçlar bugün 16:17'de aynı girdi (kaynak) kümesiyle üretilmiş XML'lerdir.
  - Instrumentation (emülatör) testleri **koşturulmadı**; yalnız `docs/audit` kayıtları okundu.
- Fiziksel cihaz kanıtı: **yok**. `build/qa/` dizini mevcut değil; `telefon-testi-protokolu-2026-09-14.md` yalnız hazırlık metni. Play Console / RevenueCat işlem kanıtı: **yok** (`EXTERNAL_LAUNCH_BLOCKERS.md` E1 ile tutarlı).

## 2. Durum tanımları (bu raporda nasıl uygulandı)

| Durum | Bu raporda kullanılma koşulu |
|---|---|
| **KANITLI** | Davranışın GERÇEK kod yolunu çalıştıran bir test var (gerçek ekranı pump eden widget testi veya gerçek servisi çalıştıran unit test; yalnız platform kanalı/OS sınırı sahte) VE bu test mevcut ağaçta geçiyor VE davranışın doğruluğu o sahte sınırın ötesinde bir OS/cihaz/mağaza davranışına dayanmıyor. |
| **KISMEN KANITLI** | Mantık gerçek testle kanıtlı ama (a) UI kablolaması veya (b) OS/Telecom/AlarmManager/izin diyaloğu tarafı kanıtsız; ya da yalnız emülatör kaydı var ve o kayıt daha eski bir commit'i ölçüyor; ya da dalların yalnız bir kısmı test ediliyor. |
| **DOĞRULANMADI** | Hiç test yok, ya da yalnız **kaynak-metni testi** var (dosyayı string olarak okuyup `contains` arayan test — davranış kanıtı sayılmadı), ya da test gerçek ekranı değil bir replika/stub'ı pump ediyor. |
| **ULAŞILAMAZ / ÖLÜ** | Kod mevcut ama hiçbir kullanıcı/sistem yolu oraya varmıyor (çağıran yok, parametre hep sabit, native olayı hiç üretmiyor vb.). |
| **DIŞ SİSTEM GEREKİYOR** | Davranışın doğruluğu Play Billing / RevenueCat / canlı web sayfası / üçüncü taraf uygulama (tarayıcı, e-posta, paylaşım) / OEM ayar ekranı gibi depo dışı bir sistemde yaşıyor ve o sistemde hiç gözlenmemiş. |

**Test tipi kısaltmaları:** `W` gerçek ekran/widget pump · `W*` replika/stub widget pump (gerçek ekran değil) · `U` Dart servis/unit (kanal mock olabilir) · `S` kaynak-metni (dosyayı string okur) · `K` Kotlin JVM (Robolectric/fake) · `I` Android instrumentation · `D` `docs/audit` cihaz kaydı · `—` yok.
**Gerçek?** = test gerçek davranışı çalıştırıyor mu: Evet / Kısmen / Hayır. **Emu/Fiz/Play/Görsel**: E = gerekir, H = gerekmez (doğrulama için).
**Eylem** sütunu `K:` (kullanıcı) veya `S:` (sistem) ile başlar — sayımlar buna göre yapıldı.

## 3. ANA TABLO — Kullanıcı ve sistem davranışları

| ID | Yüzey/Ekran | Kontrol veya sistem tetikleyicisi | Kullanıcı/Sistem eylemi | Ön koşul | Beklenen davranış | Hata/alternatif davranış | Kaynak dosya:satır | Mevcut test | Test tipi | Gerçek? | Emu | Fiz | Play/RC | Görsel | Durum | Not |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| BOOT-01 | Başlangıç | Launcher ikonu (MAIN/LAUNCHER) | S: soğuk açılış | — | Kritik bootstrap: localization → locale reset → DI → migration → PIN deposu okunabilir → kişi ısınması; her adım 5 sn sınırlı; sonra runApp | Adım hata/timeout → BOOT-02 | main.dart:97-122; app_bootstrap_service.dart:41-67 | app_bootstrap_service_test; main_startup_init_order_test | U; S | Kısmen (servis gerçek, `main()` değil) | E | E | H | E | KISMEN KANITLI | Soğuk açılış süresi bu ağaçta ölçülmedi |
| BOOT-02 | Başlangıç hata ekranı | Kritik adım başarısız | S: bootstrap `failed` | BOOT-01 hatası | Statik "Uygulama başlatılamadı" ekranı | Yeniden dene yok; panik/hızlı erişim dahil HİÇBİR özellik yok (EmergencyTriggerHost hiç kurulmaz) | main.dart:38-95,111-121 | — | — | Hayır | E | H | H | E | DOĞRULANMADI | Bkz. HATA-03 (PIN deposu okunamazsa uygulama tamamen kilitlenir) |
| BOOT-03 | Başlangıç | En-iyi-çaba servisleri | S: kritik OK sonrası | — | 10 servis paralel, 5 sn sınır; hata yutulur | Servis düşer → ilgili özellik degrade | main.dart:125-132; startup_best_effort_services.dart:17-41 | best_effort_startup_test; profile_email_removal_test; sensitive_temp_file_service_test | U | Evet | H | H | H | H | KANITLI | |
| BOOT-04 | Başlangıç | FlutterError / PlatformDispatcher.onError | S: yakalanmamış hata | — | Yerel crash-log kodu; release'de ham metin yok | — | main.dart:135-165 | main_release_logging_contract_test; crash_log_service_test | S; U | Kısmen | H | H | H | H | KISMEN KANITLI | |
| BOOT-05 | Başlangıç | Yön/edge-to-edge/metin ölçeği | S: runApp öncesi | — | Portre kilidi; edge-to-edge; metin ölçeği 1.0–2.0'a sıkıştırılır | API36 sw≥600dp'de yön kilidi manifest opt-out ile korunur | main.dart:167-208; AndroidManifest.xml:68-70 | main_text_scaling_test | U | Kısmen (yalnız clamp fonksiyonu) | E | E | H | E | KISMEN KANITLI | Tablet/katlanabilir hiç ölçülmedi |
| BOOT-06 | Tüm uygulama | FLAG_SECURE | S: release build açılışı | Release | Ekran görüntüsü/kaydı/recents küçük resmi engelli | Debug'da kapalı | MainActivity.kt:67-72 | secure_window_contract_test | S | Hayır | E | E | H | E | DOĞRULANMADI | Release build cihazda hiç açılıp denenmedi |
| BOOT-07 | Tüm uygulama | AppPrivacyShield | S: inactive/paused/hidden | — | Hassas içerik recents yakalanmadan önce siyah örtüyle maskelenir; API 33+ recents screenshot ayrıca native kapatılır | Resume'da örtü kaldırılır | app_privacy_shield.dart; MainActivity.kt | app_privacy_shield_test; secure_window_contract_test | W; S; D | Evet; final emulator recents kartında içerik görünmedi | E | H | H | E | KANITLI | E4-PRIVACY-02, APK `7ddb5071…`; `stage4-final-recents-privacy.png` |
| BOOT-08 | Splash | Logo/metin animasyonu | S: ilk kare | — | ~1 sn animasyon; reduce-motion'da 500 ms, döngüler park | — | splash_screen.dart:137-165,305-322 | reduced_motion_coverage_test | S; W* | Hayır | E | H | H | E | DOĞRULANMADI | |
| BOOT-09 | Splash | Root/bütünlük probu | S: `_goNext` | — | Native probe (3 sn) → `compromised` ise uyarı diyaloğu | Probe hata/timeout/MissingPlugin → `unknown`, diyalog yok, yerel uyarı kodu | splash_screen.dart:170-188; device_security_service.dart:50-100; DeviceIntegrityProbe.kt | device_security_service_test; device_security_test; DeviceIntegrityProbeTest (18); DeviceIntegrityEmulatorProbeTest | U; S; K; I; D | Kısmen | E | E | H | E | KISMEN KANITLI | D 2026-09-22: stok imajda sonuç her açılışta `unknown` (A-017 KISMİ, sahibin kararı) |
| BOOT-10 | Splash bütünlük diyaloğu | "Devam" (TextButton) | K: dokun | `compromised` | Diyalog kapanır, akış sürer | — | splash_screen.dart:181 | — | — | Hayır | E | E | H | E | DOĞRULANMADI | Diyalog hiçbir testte pump edilmedi |
| BOOT-11 | Splash yönlendirme | Rıza yok | S: karar | Legal kabul yok | UnifiedConsentScreen | — | splash_screen.dart:191-229 | startup_pin_boundary_test | W | Evet | H | H | H | H | KANITLI | AppRoot+Splash gerçek pump |
| BOOT-12 | Splash yönlendirme | Legal sürüm değişti | S: karar | Kabul var, sürüm farklı | Yeniden rıza → sonra PIN kapısı | — | splash_screen.dart:198-229 | startup_pin_boundary_test ("reconsent gates existing PIN"); splash_version_logic_test | W; S | Evet | H | H | H | H | KANITLI | |
| BOOT-13 | Splash yönlendirme | PIN kurulu | S: karar | Rıza OK | AppUnlockScreen (AppRoot state) | — | splash_screen.dart:232-246 | startup_pin_boundary_test | W | Evet | H | H | H | H | KANITLI | |
| BOOT-14 | Splash yönlendirme | PIN yok, onboarding yok | S: karar | Rıza OK | OnboardingScreen | — | splash_screen.dart:247-248 | startup_pin_boundary_test | W | Evet | H | H | H | H | KANITLI | |
| BOOT-15 | Splash yönlendirme | PIN yok/var, onboarding tamam | S: karar | Rıza OK, PIN doğrulandı | MainNavigation | — | splash_screen.dart:249-251 | startup_pin_boundary_test | W | Evet | H | H | H | H | KANITLI | |
| BOOT-16 | Splash | Önceki Pro ipucu | S: rıza güncel | `revenuecat_prior_verified_pro_hint` | Arka planda RevenueCat yenileme (yetki vermez) | Ağ yok → sessiz | splash_screen.dart:209-217 | subscription_provider_access_test; offline_sos_entitlement_policy_test | U | Kısmen (RC sahte) | H | H | E | H | KISMEN KANITLI | Gerçek RC yanıtı hiç gözlenmedi |
| BOOT-17 | AppRoot | Android süreç ölümü + geri dönüş | S: `am kill` sonrası geri yükleme | — | Hedef geri yüklenmez → Splash + PIN kapısı yeniden; sekme indeksi, onboarding sayfası, kişi taslağı geri gelir | Route geçmişi boş kalırsa assert/crash (öncül koşul) | app_root.dart; main.dart | state_restoration_test; state_restoration_navigator_precondition_test; state_restoration_policy_test; E4-FINAL5-BOOT17 | W; W*; S; D | Evet; reset sonrası HOME → gerçek `am kill` → cold dönüşte onboarding 5/5 ve iki taslak alanı geri geldi, framework assertion yok | E | H | H | H | KANITLI | APK `e0618db2…`; `stage4-final5-reset-onboarding-draft-restored.png/.log` |
| BOOT-18 | Kök ekranlar | Sistem Geri tuşu | K: Geri | Rıza/Onboarding/Ana ekran kökte | Uygulamadan çıkar (PopScope yok) | Kilit ekranında Geri etkisiz (canPop:false) | app_unlock_screen.dart:196-197 | E4-FINAL4-BOOT18 | D | Evet; üç kök KoruBeni task'ından çıktı, AppLock BACK etkisiz | E | H | H | H | KANITLI | APK `b8f004d1…` |
| RIZA-01 | UnifiedConsent | 18+ seçeneği (GestureDetector) | K: dokun | — | 18+ seçili, haptik | — | unified_consent_screen.dart:261-264 | startup_pin_boundary_test (gerçek tap) | W | Evet | H | H | H | E | KANITLI | Yalnız tek seçenek var (radio, "18 yaş altı" seçeneği yok) |
| RIZA-02 | UnifiedConsent | Kullanım Şartları Genişlet/Daralt | K: dokun | — | Tam ToS metni açılır/kapanır | — | unified_consent_screen.dart:400 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | Uzun metin + 200% ölçek taşma kaydı 08-14 (emu) |
| RIZA-03 | UnifiedConsent | ToS onay kutusu (ConsentCheckboxWidget InkWell + Checkbox) | K: dokun | — | `_isEulaAccepted` | — | unified_consent_screen.dart:424; consent_checkbox_widget.dart:39,65 | startup_pin_boundary_test (onChanged doğrudan çağrılıyor); unified_consent_retry_test; touch_target_minimum_size_test | W | Kısmen (dokunma jesti değil callback) | H | H | H | E | KISMEN KANITLI | |
| RIZA-04 | UnifiedConsent | KVKK Genişlet/Daralt | K: dokun | — | Aydınlatma metni açılır | — | unified_consent_screen.dart:525 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| RIZA-05 | UnifiedConsent | KVKK onay kutusu | K: dokun | — | `_isKvkkAcknowledged` | — | unified_consent_screen.dart:549 | startup_pin_boundary_test; unified_consent_retry_test | W | Kısmen | H | H | H | E | KISMEN KANITLI | |
| RIZA-06 | UnifiedConsent | İsteğe bağlı: Konum | K: işaretle | — | Rıza kaydı + pref | Verilmezse harita/konum kapıda reddedilir (MAP-02) | unified_consent_screen.dart:601 | unified_consent_retry_test | W | Kısmen | H | H | H | E | KISMEN KANITLI | Varsayılan KAPALI |
| RIZA-07 | UnifiedConsent | İsteğe bağlı: Acil kişiler | K: işaretle | — | Rıza kaydı + pref | Verilmezse Kişiler sayfasında ekleme reddedilir (KSI-02) | unified_consent_screen.dart:607 | unified_consent_retry_test | W | Kısmen | H | H | H | E | KISMEN KANITLI | Varsayılan KAPALI; onboarding kendi rızasını ayrıca alır |
| RIZA-08 | UnifiedConsent | İsteğe bağlı: Profil | K: işaretle | — | Rıza kaydı + pref | Profil adı kaydı bu rızaya BAĞLI DEĞİL (PRF-03) | unified_consent_screen.dart:614 | unified_consent_retry_test | W | Kısmen | H | H | H | E | KISMEN KANITLI | |
| RIZA-09 | UnifiedConsent | İsteğe bağlı: Sahte çağrı | K: işaretle | — | Rıza kaydı (pref yazılmaz) | Verilmezse Ana ekrandan sahte çağrı reddedilir (FKC-01) | unified_consent_screen.dart:620 | unified_consent_retry_test | W | Kısmen | H | H | H | E | KISMEN KANITLI | Varsayılan KAPALI |
| RIZA-10 | UnifiedConsent | "Devam" CTA — pasif | K: dokun | 18+ ∧ ToS ∧ KVKK sağlanmadı | Buton pasif | — | unified_consent_screen.dart:53-54,655 | startup_pin_boundary_test | W | Evet | H | H | H | E | KANITLI | |
| RIZA-11 | UnifiedConsent | "Devam" CTA — aktif | K: dokun | Zorunlular sağlandı | Tüm rızalar + pref'ler commit doğrulamalı yazılır → legal sürümler işaretlenir → startup sürer | — | unified_consent_screen.dart:58-127 | startup_pin_boundary_test; unified_consent_retry_test | W | Evet | H | H | H | H | KANITLI | |
| RIZA-12 | UnifiedConsent | "Devam" — yazma reddi | S: SharedPreferences commit false/throw | — | SnackBar "Onaylar kaydedilemedi", seçimler korunur, tekrar denenebilir | — | unified_consent_screen.dart:128-141 | unified_consent_retry_test | W | Evet | H | H | H | H | KANITLI | |
| RIZA-13 | UnifiedConsent | Sürüm metni (ToS 4.0.0 / KVKK 3.4.0) | S: render | — | Uygulama içi sürüm | Canlı web ToS 3.1.0 (A-004) | unified_consent_screen.dart:374,474; legal_texts.dart | legal_* policy tests; release_readiness_policy_test | S | Hayır | H | H | H | E | DIŞ SİSTEM GEREKİYOR | GitHub Pages canlı sayfa ile eşleşme `main` birleşmesine bağlı |
| RIZA-14 | UnifiedConsent | Reddetme yolu | K: kabul etmeden çıkmak | — | Yalnız bilgilendirme notu; "Reddet" butonu yok; Geri → uygulamadan çık | — | unified_consent_screen.dart:626-643 | legal_age_gate_contract_test; E4-FINAL4-RIZA14 | S; D | Evet; gerçek root BACK uygulama task'ından çıktı, yeniden açılış consent'te kaldı | E | H | H | H | KANITLI | Final APK `b8f004d1…` |
| ONB-01 | Onboarding | "Atla" (TextButton) | K: dokun | Sayfa 1-4 | Kişi adımına (sayfa 5) atlar, tamamlamaz | Kişi adımındayken pasif/boş etiket | onboarding_screen.dart:132-139,219 | onboarding_contact_gate_source_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| ONB-02 | Onboarding | PageView kaydırma | K: kaydır | — | Sayfa değişir, haptik, indeks geri-yüklenebilir | — | onboarding_screen.dart:231-236 | state_restoration_policy_test; E4-FINAL4-ONB02 | S; D | Evet; gerçek swipe, vibrator TEXTURE_TICK ve am-kill restoration | E | H | H | E | KANITLI | APK `b8f004d1…`; `stage4-final4-onboarding-page2.png` |
| ONB-03 | Onboarding | "İleri" (sayfa 1-4) | K: dokun | — | nextPage | — | onboarding_screen.dart:396-404 | onboarding_safety_copy_render_test (sayfa render) | W | Kısmen (tap yok) | H | H | H | E | KISMEN KANITLI | |
| ONB-04 | Onboarding | "Başla" — pasif | K: dokun | Kişi adımı, kapı sağlanmadı | Pasif + "kişi gerekli" ipucu | — | onboarding_screen.dart:396,433-445 | onboarding_contact_gate_source_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| ONB-05 | Onboarding | "Başla" — aktif | K: dokun | Aranabilir birincil kişi var | `completeOnboarding` → `prefOnboardingDone` → MainNavigation | Servis false → kişi adımına geri, kapı sıfır | onboarding_screen.dart:141-169 | onboarding_contact_gate_service_test | U | Kısmen (UI tap yok) | H | H | H | H | KISMEN KANITLI | |
| ONB-06 | Kişi adımı | Rıza kartı "Onayla" | K: dokun | Kişi verisi rızası yok | Rıza verilir, form açılır | Yazılamazsa "onboarding_contact_consent_failed" | onboarding_contact_step.dart:252-262,565 | onboarding_contact_gate_service_test; accessibility_guidelines_test | U; W | Kısmen | H | H | H | E | KISMEN KANITLI | |
| ONB-07 | Kişi adımı | Ad alanı (max 60) | K: yaz | Rıza var | Taslak geri-yüklenebilir | Rıza yok/kaydediliyor → pasif | onboarding_contact_step.dart:423-433 | input_robustness_test; state_restoration_test | W | Evet | H | H | H | E | KANITLI | |
| ONB-08 | Kişi adımı | Telefon alanı onChanged (max 32) | K: yaz | Rıza var | Canlı doğrulama hatası anahtarı (geri-yüklenebilir) | Geçersiz → hata metni | onboarding_contact_step.dart:435-460 | input_robustness_test; state_restoration_test; onboarding_contact_step_keyboard_test | W | Evet | H | H | H | E | KANITLI | |
| ONB-09 | Kişi adımı | "Rehberden seç" | K: dokun | Rıza var | Native ACTION_PICK → ad/numara dolar | İptal → değişiklik yok; seçici yok/hata → "onboarding_contact_picker_failed" | onboarding_contact_step.dart:264-283,468; MainActivity.kt:421-480 | contacts_picker_native_test; E4-FINAL5-ONB09 | S; U; D | Kısmen; final APK'da gerçek başarı, iptal ve resolver'sız NO_PICKER geçti; PICK_FAILED exception dalı açık | E | E | H | H | KISMEN KANITLI | APK `e0618db2…`; `stage4-final5-onb09-picker-success/cancel`, `stage4-final5-onb09-no-picker-notice` |
| ONB-10 | Kişi adımı | "Kaydet" | K: dokun | Geçerli telefon | Rıza diyaloğu → birincil kişi kaydı → kayıtlı kart; kapı true | Geçersiz → hata; depolama → "onboarding_contact_save_failed" | onboarding_contact_step.dart:285-323,483 | onboarding_contact_gate_service_test; onboarding_contact_step_keyboard_test | U; W | Kısmen | H | H | H | E | KISMEN KANITLI | |
| ONB-11 | Kişi rıza diyaloğu | Onay kutusu (InkWell + Checkbox) | K: dokun | Diyalog açık | "Onayla" aktifleşir | — | emergency_contact_consent_dialog.dart:196,218 | button_loading_state_test | W | Evet | H | H | H | E | KANITLI | |
| ONB-12 | Kişi rıza diyaloğu | "İptal" | K: dokun | — | false → kayıt yok | — | emergency_contact_consent_dialog.dart:48-51,250 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| ONB-13 | Kişi rıza diyaloğu | "Onayla" | K: dokun | Kutu işaretli | Rıza kaydı → true | Rıza yazımı throw → spinner durur, diyalog açık kalır, MESAJ YOK | emergency_contact_consent_dialog.dart:64-78,265 | button_loading_state_test | W | Kısmen | H | H | H | E | KISMEN KANITLI | Hata yolu sessiz |
| ONB-14 | Kişi adımı | Kayıtlı kart "Değiştir/Baştan" | K: dokun | Kişi kayıtlı | Form yeniden, kapı false | — | onboarding_contact_step.dart:325-332,523 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| ONB-15 | Kişi adımı | Klavye açılışı | S: IME inset | Telefon alanı odakta | Kaydet butonu görünür alana kaydırılır | — | onboarding_contact_step.dart:149-233 | onboarding_contact_step_keyboard_test; E4-FINAL5-ONB15 | W; D | Evet; production telefon alanı gerçek IME'yi açtı, Kaydet bounds `[84,987][996,1124]` ile görünür kaldı | E | E | H | E | KANITLI | APK `e0618db2…`; `stage4-final5-onb15-ime-save-visible.png/.xml` |
| PIN-01 | PinSetup (zorunlu) | Otomatik açılma | S: MainNavigation ilk kare | PIN yok | Tam ekran PinSetupScreen(requiredSetup) | — | main_navigation.dart:212-226 | main_navigation_construction_sites_test | S | Hayır | E | H | H | E | DOĞRULANMADI | PIN onboarding'den SONRA kuruluyor |
| PIN-02 | PinSetup | Rakam tuşları (InkWell) | K: dokun | — | Nokta dolar | — | pin_setup_screen.dart:348-368 | pin_setup_layout_stability_test | W | Evet | H | H | H | E | KANITLI | |
| PIN-03 | PinSetup | Sil tuşu | K: dokun | — | Son hane silinir | — | pin_setup_screen.dart:342-346 | pin_setup_layout_stability_test | W | Evet | H | H | H | E | KANITLI | |
| PIN-04 | PinSetup | Zayıf PIN (örn. 1234) | K: 4. hane | — | Red bandı, tuş takımı yerinde kalır | — | pin_setup_screen.dart:61-69; validators.dart | pin_setup_layout_stability_test; pin_change_validation_test | W; U | Evet | H | H | H | E | KANITLI | |
| PIN-05 | PinSetup | Onay uyuşmazlığı | K: 2. giriş farklı | — | "PIN eşleşmedi", baştan | — | pin_setup_screen.dart:83-93 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| PIN-06 | PinSetup | Onay eşleşti | K: 2. giriş aynı | — | PBKDF2 hash yazılır → başarı SnackBar → pop | — | pin_setup_screen.dart:98-130 | pin_verification_service_test; pin_hasher_test | U | Kısmen (UI akışı yok) | H | H | H | H | KISMEN KANITLI | |
| PIN-07 | PinSetup | Yazma hatası | S: writePin false | — | "PIN kaydedilemedi", baştan | — | pin_setup_screen.dart:99-110 | pin_verification_service_test | U | Kısmen | H | H | H | H | KISMEN KANITLI | |
| PIN-08 | PinSetup | Geri (zorunlu kurulumda) | K: Geri | requiredSetup | Engelli (canPop false, AppBar geri yok) | — | pin_setup_screen.dart:156-163 | — | — | Hayır | E | H | H | H | DOĞRULANMADI | |
| PIN-09 | PinSetup | Bilgi ikonu | K: dokun | — | LegalSettingsScreen push (PIN henüz yok) | — | pin_setup_screen.dart:170-175 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | Buradan Veri Sil/Dışa Aktar'a PIN'siz erişim (PIN yokken zaten serbest) |
| PIN-10 | İlk ana ekran | Açılış yarışı | S: ilk kare | Yeni kullanıcı | PIN kurulumu tek başına açılır; tamamlandıktan sonra pil sihirbazı gelir | Modal çakışması olmamalı | main_navigation.dart:129-132,228-231; home_page.dart:103-107 | E4-FINAL5-PIN10 | D | Evet; onboarding sonrası ilk kare yalnız PIN, PIN 2689 tamamlanınca pil sihirbazı açıldı | E | H | H | E | KANITLI | APK `e0618db2…`; `stage4-final5-pin10-first-modal.png`, `stage4-final5-pin10-after-battery-skip.png` |
| KLT-01 | AppUnlock | Rakam/Sil tuşları | K: dokun | Kilit yok | Nokta dolar, 4. hanede doğrulama | Kilitliyken yok sayılır | app_unlock_screen.dart:106-122,539-560 | startup_pin_boundary_test | W | Evet | H | H | H | E | KANITLI | |
| KLT-02 | AppUnlock | Doğru PIN (başlangıçta) | K: 4 hane | Splash kaynaklı | Kilit sayacı sıfırlanır → startup sürer | — | app_unlock_screen.dart:147-150 | startup_pin_boundary_test | W | Evet | H | H | H | H | KANITLI | |
| KLT-03 | AppUnlock | Yanlış PIN | K: 4 hane | — | Titreşim, temizle, "Yanlış PIN", sayaç++ | registerFailure hatası → yalnız debugPrint | app_unlock_screen.dart:151-186 | pin_lockout_service_test; unlock_screen_duress_contract_test | U; S | Kısmen (UI yok) | H | H | H | E | KISMEN KANITLI | |
| KLT-04 | AppUnlock | 5 yanlış → kilit | S: sayaç eşiği | — | 30 sn → katlanarak 15 dk; geri sayım bandı; tuşlar pasif | — | app_unlock_screen.dart:68-98; pin_lockout_service.dart:47-58 | pin_lockout_backoff_test; pin_lockout_service_test | U | Kısmen | H | H | H | E | KISMEN KANITLI | |
| KLT-05 | AppUnlock | Kilit durumu süreç yeniden başlayınca | S: init | Kilit aktif | Kalıcı kilit okunur, geri sayım sürer | — | app_unlock_screen.dart:48-81 | pin_lockout_service_test; E4-FINAL5-KLT05 | U; D | Evet; gerçek keypad ile lockout 57s, force-stop/cold relaunch sonrası 52s olarak sürdü | E | H | H | H | KANITLI | APK `e0618db2…`; `stage4-final5-klt05-lockout-before/after-restart.xml/.png/.log` |
| KLT-06 | AppUnlock | PIN deposu okunamıyor | S: verify readFailed | — | "PIN okunamadı" SnackBar, açılmaz | — | app_unlock_screen.dart:133-145 | single_pin_verification_path_test; pin_verification_service_test | S; U | Kısmen | H | H | H | H | KISMEN KANITLI | Başlangıçta aynı durum BOOT-02'ye düşer |
| KLT-07 | AppUnlock | Yasal bilgi ikonu | K: dokun | Kilitli | LegalSettingsScreen açılır | — | app_unlock_screen.dart:205-217 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | GÜVENLİK NOTU: kilitli uygulamadan PIN'siz Rıza Yönetimi (YSL-05..08) değiştirilebilir |
| KLT-08 | AppUnlock | "PIN'imi unuttum" | K: dokun | — | Aktif Check-In/Güvenli Yürüyüş varsa engel SnackBar; yoksa sıfırlama diyaloğu | Probe hata → "aktif var" sayılır (fail-closed) | app_unlock_screen.dart:376-394 | safety_session_activity_probe_test; forgot_pin_reset_route_test | U; S | Kısmen | H | H | H | E | KISMEN KANITLI | Probe panik geri sayımını kapsamaz |
| KLT-09 | Unuttum diyaloğu | "SIFIRLA" metin alanı | K: yaz | — | Tam eşleşince buton aktif | — | app_unlock_screen.dart:441-464,478 | forgot_pin_reset_route_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| KLT-10 | Unuttum diyaloğu | "İptal" | K: dokun | — | Kapanır | — | app_unlock_screen.dart:471 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| KLT-11 | Unuttum diyaloğu | "Sıfırla" | K: dokun | "SIFIRLA" yazıldı | Native oturum silme → prefs/DB/dosyalar → secure storage EN SON → AppRoot startup state reset | Native TOO_LATE/unknown → "Etkin güvenlik işlemi durdurulamadı; veriler silinmedi" | app_unlock_screen.dart; app_root.dart; app_reset_service.dart | app_reset_native_prefs_test; contact_service_app_reset_cache_test; forgot_pin_reset_route_test; E4-FINAL5-KLT11 | U; S; D | Kısmen; gerçek başarı zinciri shell route'u koruyarak temiz consent'e döndü, native ret dalı runtime'da açık | E | H | H | E | KISMEN KANITLI | APK `e0618db2…`; başarı sonrası process-death BOOT-17/HATA-19 ile geçti |
| KLT-12 | AppUnlock | Sistem Geri | K: Geri | — | Etkisiz | — | app_unlock_screen.dart:196-197 | unlock_screen_duress_contract_test | S | Hayır | E | H | H | H | DOĞRULANMADI | |
| YDK-01 | Arka plan kilidi | Yaşam döngüsü | S: ≥120 sn paused/hidden/detached → resumed | PIN kurulu | Root navigator'a AppUnlockScreen push; doğru PIN → pop | `inactive` saati başlatmaz | app_lifecycle_handler.dart:26-94; emergency_trigger_host.dart:77-104 | app_lifecycle_lock_test | U | Kısmen (push yok) | E | H | H | H | KISMEN KANITLI | AUDIT: 141 sn cihaz ölçümü eski commit |
| YDK-02 | Arka plan kilidi | Yaşam döngüsü | S: <120 sn dönüş | — | Kilit yok | — | app_lifecycle_handler.dart:72 | app_lifecycle_lock_test | U | Evet | H | H | H | H | KANITLI | |
| YDK-03 | Arka plan kilidi | secure storage okuma hatası | S: onResumed içinde throw | — | — | Future hatası await edilmiyor → kilit HİÇ gösterilmez (fail-open) | app_lifecycle_handler.dart:74-76; emergency_trigger_host.dart:88 | — | — | Hayır | E | H | H | H | DOĞRULANMADI | Kod okumasından çıkarım; GÜVENLİK |
| YDK-04 | Arka plan kilidi | Kilit + hızlı panik aynı resume | S: resume | Tile/widget isteği bekliyor | Her ikisi de root navigator'a push; sıra zamanlamaya bağlı | — | emergency_trigger_host.dart:77-89 | — | — | Hayır | E | E | H | E | DOĞRULANMADI | |
| NAV-01 | MainNavigation | Sekme: Ana Sayfa | K: dokun | — | Crossfade (reduce-motion'da anlık), haptik | Geçiş sürerken ikinci tap yok sayılır | main_navigation.dart:197-208,396 | tab_crossfade_test | S | Hayır | H | H | H | E | DOĞRULANMADI | MainNavigation hiçbir testte pump edilmiyor |
| NAV-02 | MainNavigation | Sekme: Harita | K: dokun | — | MapPage `isActive` true → ilk konum isteği | — | main_navigation.dart:308,396 | tab_crossfade_test; map_page_ui_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| NAV-03 | MainNavigation | Sekme: Kişiler | K: dokun | — | ContactsPage | — | main_navigation.dart:309,396 | tab_crossfade_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| NAV-04 | MainNavigation | Sekme: Ayarlar | K: dokun | — | SettingsPage | — | main_navigation.dart:310,396 | tab_crossfade_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| NAV-05 | MainNavigation | Sekme indeksi geri yükleme | S: süreç ölümü | — | Son sekme geri gelir (PIN'den sonra) | — | main_navigation.dart:52-63 | state_restoration_policy_test; E4-FINAL5-NAV05 | S; D | Evet; Ayarlar seçili → cached süreç `am kill` ile PID yok → cold launch → PIN → Ayarlar selected=true | E | H | H | H | KANITLI | APK `e0618db2…`; `stage4-final5-nav05-settings-before-kill/restored.png/.xml/.log` |
| NAV-06 | MainNavigation | Bildirim izni istemi | S: ilk kare, PIN sonrası | Bildirim pref açık, izin yok, daha önce sorulmadı | Prominent disclosure → OS izni → "soruldu" işaretlenir | Reddedilirse bir daha otomatik sorulmaz | main_navigation.dart:246-277; permission_helper.dart:156-193 | — | — | Hayır | E | E | H | E | DOĞRULANMADI | |
| NAV-07 | Bağlantı bandı | Çevrimdışı | S: bağlantı kaybı | — | Üstte bant + içerik bant yüksekliği kadar itilir | — | connectivity_banner.dart; main_navigation.dart:291-325 | connectivity_banner_reserves_space_test; connectivity_service_test; E4-FINAL8-NAV07 | W*; U; D | Evet; final production APK'da Wi-Fi ve data kapatılınca banner `[0,0][1080,233]` oldu | E | H | H | E | KANITLI | APK `913e4e72…`; `stage4-final8-nav07-offline.png/.xml` |
| NAV-08 | Bağlantı bandı | Banda dokun | K: dokun | Çevrimdışı | Çevrimdışı bilgi diyaloğu | — | connectivity_banner.dart:132,185-255 | connectivity_banner_behavior_test; E4-FINAL8-NAV08 | W; D | Evet; final production APK'da gerçek offline banner dokunuşu bilgi yüzeyini açtı; ağ geri gelince banner sıfır bounds'a döndü | E | H | H | E | KANITLI | APK `913e4e72…`; `stage4-final8-nav08-dialog.png/.xml`, `stage4-final8-nav08-restored.xml` |
| NAV-09 | Çevrimdışı diyaloğu | "Tamam" | K: dokun | — | Kapanır | — | connectivity_banner.dart:248 | connectivity_banner_behavior_test; E4-FINAL6-NAV08 | W; D | Evet; production diyaloğu Tamam ile kapandı; ağ geri geldiğinde banner bounds `[0,0][0,0]` oldu | H | H | H | H | KANITLI | APK `627e3822…`; `stage4-final6-nav08-online-restored.xml` |
| NAV-10 | MainNavigation | Sistem Geri | K: Geri | Ana kabuk | Uygulamadan çıkar | — | main_navigation.dart (PopScope yok) | E4-FINAL5-NAV10 | D | Evet; Ayarlar sekmesindeki ana kabukta sistem BACK sonrası foreground Settings oldu, KoruBeni task görünmez kaldı | E | H | H | H | KANITLI | APK `e0618db2…`; `stage4-final5-nav10-main-back-exit.png`, dumpsys activity |
| HOME-01 | Ana Sayfa | Acil kişi çipi (InkWell) | K: dokun | — | ContactsPage push; dönüşte HomeProvider yenilenir | — | home_page.dart:305-372,808-815 | home_page_test | S | Hayır | H | H | H | E | DOĞRULANMADI | HomePage hiçbir testte pump edilmiyor |
| HOME-02 | Ana Sayfa | Acil kişi çipi — kişi yok durumu | S: render | Birincil yok | "Acil kişi seçilmedi / dokun" | — | home_page.dart:341-356 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| HOME-03 | Hazırlık kartı | Çip "Acil kişi" | K: dokun | — | ContactsPage | — | readiness_card.dart:94-98,228,424; home_page.dart:241 | readiness_card_test | W | Kısmen (kart gerçek, home kablosu değil) | H | H | H | E | KISMEN KANITLI | |
| HOME-04 | Hazırlık kartı | Çip "Arama izni" | K: dokun | — | Prominent disclosure → OS CALL_PHONE → hazırlık yeniden okunur | Kalıcı ret → Ayarlar'a git diyaloğu | readiness_card.dart:99-103; home_page.dart:423-427; permission_helper.dart:103-146 | readiness_card_test; E4-FINAL5-HOME04 | W; D | Evet; grant, ilk ret, USER_FIXED ikinci ret, uygulama diyaloğu ve APPLICATION_DETAILS_SETTINGS gerçek Android runtime'da geçti | E | E | H | E | KANITLI | APK `e0618db2…`; `stage4-final5-home04-*`; test sonunda CALL_PHONE tekrar granted |
| HOME-05 | Hazırlık kartı | Çip "Arka plan" | K: dokun | — | BatteryOptimizationWizard push | — | readiness_card.dart:104-108; home_page.dart:142-147 | readiness_card_test | W | Kısmen | E | E | H | E | KISMEN KANITLI | |
| HOME-06 | Hazırlık kartı | Çip "Konum" | K: dokun | — | Konum rızası kapısı → gerekçe diyaloğu → konum izni akışı | Rıza yok → SnackBar "ilgili onay gereklidir" | readiness_card.dart:109-113; home_page.dart:374-394 | readiness_card_test; consent_gate_service_test | W; U | Kısmen | E | E | H | E | KISMEN KANITLI | |
| HOME-07 | Hazırlık kartı | Çip "Rehber" | K: dokun | — | Gerçek `Acil Kişiler` ekranına gider | — | readiness_card.dart:114-118; home_page.dart | readiness_card_test; main_navigation_behavior_test | W; D | Evet; final emulator gerçek ekran | E | H | H | E | KANITLI | E4-FINAL4-HOME07, APK `b8f004d1…`; `stage4-final3-home07-contacts.png` |
| HOME-08 | Hazırlık kartı | Hazır / "N eksik" / "neredeyse" | S: render | Native readiness (getDeviceState) | Arama izni, exact alarm, bildirim, kanal HIGH, pil muafiyeti, konum, kişi → başlık/not | Native köprü yok → kırmızı + yerel kayıt | readiness_card.dart:130-257; emergency_readiness_service.dart:38-76 | readiness_card_test; emergency_readiness_test; emergency_readiness_behavior_test; home_readiness_exact_alarm_test; E4-FINAL8-HOME08 | W; U; S; D | Kısmen; gerçek emulator değerleri ve kullanıcıya yansıyan iki eksik görüldü | E | E | H | E | KISMEN KANITLI | APK `913e4e72…`; POST_NOTIFICATIONS ve konum granted, CALL_PHONE denied; `stage4-final8-home08-readiness.png/.xml`; fiziksel/görsel kalemler sürüyor |
| HOME-09 | Hazırlık kartı | Abonelik doğrulama notları | S: render | Doğrulama bekliyor / grace bitiyor / grace bitti | Bilgi kutusu (saat sayısı) | — | readiness_card.dart:262-338 | readiness_card_stale_verification_test | W | Evet | H | H | H | E | KANITLI | Gerçek RC gecikmesi DIŞ |
| HOME-10 | Hazırlık kartı | Prova satırı (InkWell) | K: dokun | — | Test Modu'nu başlatır (HOME-14) | — | readiness_card.dart:352-407 | readiness_card_test | W | Kısmen | H | H | H | E | KISMEN KANITLI | |
| HOME-11 | Onboarding kartı | "X" kapat | K: dokun | Kart kapatılmamış | Kalıcı gizlenir | — | home_page.dart:664-668; home_provider.dart:81-86 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| HOME-12 | Onboarding kartı | Adım 1 "Acil kişi seç" | K: dokun | — | ContactsPage | — | home_page.dart:675-680,708 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| HOME-13 | Onboarding kartı | Adım 2 "Konum izni" | K: dokun | — | HOME-06 ile aynı akış | — | home_page.dart:681-686,708 | E4-FINAL8-HOME13 | D | Kısmen; production açıklamaları → gerçek PermissionController → grant → hazırlık sayacı `3→2` | E | E | H | E | KISMEN KANITLI | APK `913e4e72…`; `stage4-final8-home13-before/disclosure1/step2/os/after.xml`, OS ekran görüntüsü ve sonrası; fiziksel/görsel kalemler sürüyor |
| HOME-14 | Ana Sayfa / Onboarding kartı adım 3 | "Test Modu" (OutlinedButton) | K: dokun | — | Geri sayım test modunda (GS-20); tamamlanınca prova tarihi kaydedilir | — | home_page.dart:691,771-806 | rehearsal_record_service_test; countdown_dispose_lifecycle_test | U; W | Kısmen (Home kablosu yok) | H | H | H | E | KISMEN KANITLI | |
| HOME-15 | Hızlı eylemler | "Sahte çağrı" kartı | K: dokun | Ücretsiz | Rıza kapısı → gecikme seçenekleri sayfası | Rıza yok (varsayılan!) → SnackBar | home_page.dart:822-829,476-550,957-968,1066-1072 | premium_gating_contract_test; consent_gate_enforcement_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| HOME-16 | Hızlı eylemler | "Siren" kartı | K: dokun | Ücretsiz | SirenDialog | — | home_page.dart:830-836,1074-1082 | premium_gating_contract_test | S | Hayır | H | E | H | E | DOĞRULANMADI | |
| HOME-17 | Hızlı eylemler | "Güvenli Yürüyüş" — Pro | K: dokun | Pro yetkili | SafeWalkScreen push | — | home_page.dart:837-848,1066-1072 | premium_gating_contract_test; subscription_gate_test | S; U | Kısmen | H | H | E | E | KISMEN KANITLI | Kilit rozeti `isAuthorized` ile |
| HOME-18 | Hızlı eylemler | "Güvenli Yürüyüş" — Pro değil | K: dokun | Doğrulanmış ücretsiz / bilinmiyor | Paywall push / "doğrulanamadı" SnackBar | — | subscription_gate.dart:77-157 | subscription_gate_test; subscription_gate_unverified_test | U; W* | Kısmen | H | H | E | E | KISMEN KANITLI | |
| HOME-19 | Hızlı eylemler | "Kişiler" kartı | K: dokun | Ücretsiz | ContactsPage PUSH (sekmeden ayrı ikinci örnek) | — | home_page.dart:849-855 | premium_gating_contract_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| HOME-20 | Hızlı eylemler | "Geçmiş" kartı | K: dokun | Ücretsiz | SafetyTimelineScreen push | — | home_page.dart:856-867 | premium_gating_contract_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| HOME-21 | Hızlı eylemler | "Check-In" — Pro | K: dokun | Pro yetkili | CheckInScreen push | — | home_page.dart:868-879 | premium_gating_contract_test | S | Hayır | H | H | E | E | DOĞRULANMADI | |
| HOME-22 | Hızlı eylemler | "Check-In" — Pro değil | K: dokun | Ücretsiz/bilinmiyor | Paywall / SnackBar | — | subscription_gate.dart:122-157 | subscription_gate_test | U | Kısmen | H | H | E | E | KISMEN KANITLI | |
| HOME-23 | Hızlı eylem kartı | _ScaleTapCard tapDown/Up/Cancel | K: bas-bırak | — | Ölçek animasyonu, bırakınca eylem | Kaydırarak iptal → eylem yok | home_page.dart:1160-1208 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| HOME-24 | Gerekçe diyaloğu | "Sonra" | K: dokun | Konum/rehber gerekçesi | false → çık | — | home_page.dart:452 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| HOME-25 | Gerekçe diyaloğu | "İzin ver" | K: dokun | — | true → izin akışı | — | home_page.dart:459 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| HOME-26 | Pil sihirbazı otomatik | İlk ana ekran | S: ilk kare | Görülmedi/ertelenmedi/"bir daha gösterme" değil | PIN kurulumundan sonra sihirbaz push | — | home_page.dart:111-121; battery_optimization_wizard.dart:37-45 | battery_wizard_onboarding_test; E4-FINAL5-HOME26 | S; D | Evet; yeni kullanıcı PIN'i tamamlayınca gerçek Pil Optimizasyonu ekranı otomatik açıldı | E | H | H | E | KANITLI | APK `e0618db2…`; `stage4-final5-pin10-after-confirm.xml`, `stage4-final5-pin10-after-battery-skip.png` |
| HOME-27 | Ana Sayfa | Yasal uyarı bandı | S: render | — | Statik "ilk müdahale değildir" bandı | — | legal_disclaimer_banner.dart; home_page.dart:263-265 | no_sms_references_test; legal_no_first_responder_claims_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| PNK-01 | Panik butonu | Basış başlangıcı (onTapDown) | K: parmak bas | Erişilebilir gezinme kapalı | Yetki kapısı (400 ms çapa + 1,8 sn mağaza) → ilk kullanım uyarısı → silahlı halka + 500 ms haptik | Yetki yok → PNK-05/06 | panic_button.dart:113-177,428 | panic_button_behavior_test | W | Evet | H | H | H | E | KANITLI | Gerçek RC yanıtıyla değil, sahte provider |
| PNK-02 | Panik butonu | 3 sn tutup bırak (onTapUp) | K: bırak | Silahlı, ≥3 sn | Yetki yeniden → `authorized` + aranabilir kişi → CountdownScreen (geçişsiz) | Kişi yok → PNK-07; yetki unknown → SnackBar | panic_button.dart:183-193,237-286,429 | panic_button_behavior_test; panic_button_hold_contract_test; panic_button_release_contract_test | W; S | Kısmen (tam 3 sn → push testi adı yok) | H | E | E | E | KISMEN KANITLI | |
| PNK-03 | Panik butonu | <3 sn bırak | K: bırak | — | Kurulmaz, halka yay ile geri döner | — | panic_button.dart:183-235 | panic_button_behavior_test | W | Evet | H | H | H | E | KANITLI | |
| PNK-04 | Panik butonu | onTapCancel (parmak kayar) | K: kaydır | — | Sıfırla | — | panic_button.dart:195-197,430 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| PNK-05 | Panik butonu | Pro değil (doğrulanmış ücretsiz) | K: bas | — | Paywall push | — | subscription_gate.dart:122-176 | subscription_gate_test; subscription_gate_unverified_test | U; W* | Kısmen | H | H | E | E | KISMEN KANITLI | Gerçek satın alma hiç yapılmadı (A-003) |
| PNK-06 | Panik butonu | Yetki çözülemedi | K: bas | Çevrimdışı, çapa yok | Görünür "Abonelik durumu doğrulanamadı" SnackBar (5 sn, TalkBack'e okunur) | — | subscription_gate.dart:143-157; panic_button.dart:250-260 | panic_button_behavior_test; subscription_gate_unverified_test | W | Evet | H | H | H | E | KANITLI | |
| PNK-07 | Panik butonu | Aranabilir kişi yok | K: bırak | Yetkili | SnackBar "önce acil kişi ekleyin" + "Kişi ekle" eylemi | — | panic_button.dart:266-315 | contact_service_emergency_read_contract_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| PNK-08 | Panik SnackBar | "Kişi ekle" eylemi | K: dokun | PNK-07 | ContactsPage push | — | panic_button.dart:307-311 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| PNK-09 | İlk kullanım uyarısı | "Anladım/Kabul" | K: dokun | İlk panik basışı | Pref + yasal log; ilk basış İPTAL olur, ikinci basış gerekir | — | feature_warning_dialog.dart:28-60,118; panic_button.dart:133-141 | no_sms_references_test | S | Hayır | H | H | H | E | DOĞRULANMADI | Kullanıcıya "neden kurulmadı" söylenmiyor |
| PNK-10 | Panik butonu (TalkBack) | Semantics onTap | K: çift dokun | accessibleNavigation | Kapı → uyarı → onay diyaloğu | — | panic_button.dart:324-387,426 | accessibility_guidelines_test; panic_button_a11y_test; D 2026-08-21 | W; S; D | Kısmen | E | E | H | E | KISMEN KANITLI | TalkBack kaydı emülatör, eski commit (b87b74a); panik başlatma adımı kaydedilmemiş |
| PNK-11 | TalkBack onay diyaloğu | "İptal" | K: dokun | — | Kurulmaz | — | panic_button.dart:362 | — | — | Hayır | E | H | H | H | DOĞRULANMADI | |
| PNK-12 | TalkBack onay diyaloğu | "Başlat" | K: dokun | — | Geri sayım açılır | — | panic_button.dart:369,385-386 | — | — | Hayır | E | H | H | H | DOĞRULANMADI | |
| PNK-13 | Panik butonu | Arka arkaya hızlı basış | K: 5× hızlı | — | En fazla bir geri sayım (`_pointerDown`, `_countdownOpening`) | — | panic_button.dart:113-121,238,273-285 | panic_route_guard_test; panic_button_test | S | Hayır | H | H | H | H | DOĞRULANMADI | Host tarafı eşdeğeri HZ-08 KANITLI |
| PNK-14 | Panik butonu | Kilitli görsel (Pro değil) | S: render | Acil yetki yok | Kilitli etiket/semantik; nefes halkası yok | — | panic_button.dart:394-420 | panic_button_pro_only_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| GS-01 | Geri sayım | Açılış + Dart arm isteği | S: initState | Yetkili, PIN kurulu, aranabilir kişi | PIN durumu + birincil kişi yüklenir, durum bildirimi kirası, native arm (10 sn, normalize hedef) | — | countdown_screen.dart:106-229 | countdown_locked_screen_arm_test; emergency_trigger_host_contact_mask_test | W | Evet (native mock) | H | H | H | H | KANITLI | |
| GS-02 | Geri sayım | Native AlarmManager kurulumu | S: arm | GS-01 | Exact+inexact ELAPSED_REALTIME_WAKEUP; Doze'da tetiklenir | Exact izni yok → reddedilir (GS-05) | EmergencySessionCoordinator.kt:24-172; AndroidEmergencySessionRuntime.kt:206-261 | EmergencySessionCoordinatorTest (51); EmergencySessionAlarmInstrumentationTest; NativeDozeDispatchProbeTest; D 2026-09-13 native-doze | K; I; D | Kısmen | E | E | H | H | KISMEN KANITLI | D: API37 emülatör, commit 6c1467c, 78 ms gecikme GEÇTİ; fiziksel cihaz yok |
| GS-03 | Geri sayım | Ekran açılırken telefon kilitlendi | S: paused | — | Kare beklemesi sınırlı (BoundedFrameWait), arm yine yapılır | — | countdown_screen.dart:147-156; bounded_frame_wait.dart | countdown_locked_screen_arm_test; bounded_frame_wait_test | W; U | Evet | E | H | H | H | KANITLI | |
| GS-04 | Geri sayım | Arm reddi: yetki/PIN/hedef | S: arm sonucu | — | Engelleyici hata diyaloğu (sebep metni), geri sayım yok, kapatınca ekran kapanır | — | countdown_screen.dart:173-202,248-265; panic_arm_policy.dart:26-37 | countdown_dispose_lifecycle_test; panic_arm_policy_test | W; U | Evet | H | H | H | E | KANITLI | |
| GS-05 | Geri sayım | Arm reddi: yetenek (arama izni / exact alarm / bildirim kapalı / kanal HIGH değil) | S: arm sonucu | — | "Ön plan arama" geri sayımı: yalnız Dart zamanlayıcısı, Doze koruması YOK | — | panic_arm_policy.dart:16-21,54-66 | countdown_dispose_lifecycle_test ("rejected native arm ... PIN cancel exits locally"); panic_arm_policy_test | W; U | Kısmen | E | E | H | E | KISMEN KANITLI | Kullanıcıya korumasız olduğu ekranda söylenmiyor |
| GS-06 | Geri sayım | Arm belirsiz (timeout/platformError) | S: ArmUnknown | — | Belirsiz token ile geri sayım sürer | — | panic_arm_policy.dart:58-60,70-75 | panic_arm_policy_test; emergency_platform_typed_contract_test | U | Kısmen | E | H | H | H | KISMEN KANITLI | |
| GS-07 | Geri sayım | Native köprü yok (MissingPlugin) | S: arm | — | Engellendi + "Şimdi ara" manuel arama teklif edilir | — | panic_arm_policy.dart:48-52; emergency_platform_channel.dart:38-53 | countdown_bridge_missing_test; emergency_platform_bridge_test | W; U | Evet | H | H | H | E | KANITLI | Bu WIP'te yeni |
| GS-08 | Geri sayım | PIN tuşları + Sil (+ _ScaleTapButton) | K: dokun | PIN kurulu | Nokta dolar; 4. hanede doğrulama | Doğrulama/gezinme sürerken yok sayılır | countdown_screen.dart:542-567,928-1033 | countdown_dispose_lifecycle_test; countdown_accessibility_test | W | Evet | H | H | H | E | KANITLI | |
| GS-09 | Geri sayım | Doğru PIN → native iptal onaylı | K: 4 hane | Armed | Etkinlik kaydı → pop; kilit sayacı sıfır | Sayaç sıfırlama hatası iptali engellemez | countdown_screen.dart:569-579,474-540 | countdown_lockout_reset_failure_test | W | Evet | H | H | H | H | KANITLI | |
| GS-10 | Geri sayım | Doğru PIN, iptal onaylanamadı | S: cancel unknown | Armed | "İptal doğrulanamadı; acil işlem devam ediyor olabilir" + geri sayım sürer | — | countdown_screen.dart:486-511 | countdown_dispose_lifecycle_test | W | Evet | H | H | H | E | KANITLI | |
| GS-11 | Geri sayım | Doğru PIN, "çok geç" | S: cancel TooLate | Native CLAIMED | "İptal için çok geç" + sevk sürer | — | countdown_screen.dart:494-508 | emergency_platform_typed_contract_test | U | Kısmen (UI dalı yok) | H | H | H | E | KISMEN KANITLI | |
| GS-12 | Geri sayım | Yanlış PIN | K: 4 hane | — | Sallanma + titreşim + "PIN eşleşmedi"; sayaç sn'de ≤1 kez; iptali asla kilitlemez | Sayaç yazma hatası yutulur | countdown_screen.dart:581-616 | countdown_pin_dispatch_contract_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| GS-13 | Geri sayım | PIN okunamıyor / yok | S: render | — | Tuş takımı yok; metin durumu | Arm zaten reddedilir (GS-04) | countdown_screen.dart:823-868 | countdown_dispose_lifecycle_test ("PIN read failure") | W | Evet | H | H | H | E | KANITLI | |
| GS-14 | Geri sayım | Geri / tahminli geri | K: Geri | — | Engelli (canPop:false) | — | countdown_screen.dart:623-628 | countdown_back_guard_test | S | Hayır | E | H | H | H | DOĞRULANMADI | |
| GS-15 | Geri sayım | Süre doldu → Dart sevk | S: 0 sn | Armed | Wakelock → dispatchEmergencySession → istek gönderildi → EmergencyCallScreen (pushReplacement) + defter + zaman çizelgesi/haptik/bildirim | — | countdown_screen.dart:269-446 | emergency_trigger_host_contact_mask_test; emergency_dispatch_pipeline_test; dispatch_path_latency_contract_test | W; U; S | Evet (native mock) | H | H | H | H | KANITLI | |
| GS-16 | Geri sayım | Gerçek Telecom araması | S: sevk | CALL_PHONE, SIM | `placeCall` → "istek gönderildi, bağlantı bilinmez" | İzin geri alınmış → FAILED + fallback bildirimi | AndroidEmergencySessionRuntime.kt:95-120 | EmergencySessionCoordinatorTest; D 2026-09-13 native-doze | K; D | Kısmen | E | E | H | H | KISMEN KANITLI | Fiziksel SIM ile hiç denenmedi |
| GS-17 | Geri sayım | İstek gönderilemedi → dialer | S: sevk | — | ACTION_DIAL → "dialerRequested" sonuç ekranı | Dialer da yok → GS-19 | countdown_screen.dart:372-377; android_intent_service.dart | android_intent_service_test; call_service_test | U; S | Kısmen | E | E | H | E | KISMEN KANITLI | |
| GS-18 | Geri sayım | Sevk "iptal edildi" döndü | S: yarış | — | Ekran kapanır | — | countdown_screen.dart:358-362 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| GS-19 | Geri sayım | Tam başarısızlık / throw / sonuç ekranı açılamadı | S: sevk | — | Engelleyici hata diyaloğu + defter + manuel arama | — | countdown_screen.dart:323-341,396-407,429-444 | emergency_failure_surface_test; emergency_result_policy_test | W; U | Kısmen (diyalog gerçek, tetikleme değil) | H | H | H | E | KISMEN KANITLI | |
| GS-20 | Geri sayım (Test Modu) | Test modu çalışması | S: 10 sn Dart | isTestMode | "TEST MODU" rozeti; native çağrı yok; bitince "Test tamamlandı" + pop(true) | — | countdown_screen.dart:135-150,238-245,309-321 | countdown_dispose_lifecycle_test ("test mode advances locally") | W | Evet | H | H | H | E | KANITLI | |
| GS-21 | Geri sayım (Test Modu) | İptal yolu | K: PIN/Geri | isTestMode | — | PIN yüklenmediği için tuş takımı YOK, metin "Güvenlik PIN'i doğrulanıyor…" kalır, Geri engelli → 10 sn beklemek zorunlu | countdown_screen.dart:135-137,823-868,623-628 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | Kod okumasıyla; prova PIN iptalini PROVA ETTİRMİYOR |
| GS-22 | Geri sayım | Kişi adı gösterimi | S: render | Normal / hızlı erişim | Normal: gerçek ad; hızlı erişim: maskeli (A***) | — | countdown_screen.dart:89-92,837-848; contact_name_mask.dart | countdown_contact_mask_test; emergency_trigger_host_contact_mask_test | W | Evet | H | H | H | E | KANITLI | Sonuç ekranında numara maskesiz (SNC-08) |
| GS-23 | Geri sayım | Erişilebilirlik | S: render | — | Canlı bölge duyurusu, 48 dp hedefler, etiketler | — | countdown_screen.dart:775-780; countdown_announcement.dart | countdown_accessibility_test; countdown_live_region_test | W; S | Kısmen (TalkBack gerçek değil) | E | E | H | E | KISMEN KANITLI | |
| GS-24 | Geri sayım | Arka plana alma | S: paused | Armed | Dart zamanlayıcı + native alarm | Süreç öldü → native alarm sevk eder (NTV-01) | countdown_screen.dart:269-295 | — | — | Hayır | E | E | H | H | DOĞRULANMADI | |
| GS-25 | Geri sayım | Dispose yaşam döngüsü | S: route kapanır | — | Silahlıyken dispose native iptal GÖNDERMEZ; wakelock/durum kirası dengesi | — | countdown_screen.dart:448-472 | countdown_dispose_lifecycle_test; wakelock_balance_test | W; S | Kısmen | H | H | H | H | KISMEN KANITLI | |
| GS-26 | Hata diyaloğu | "Şimdi ara" | K: dokun | Numara var | ACTION_DIAL | — | emergency_failure_dialog.dart:132-153 | emergency_failure_surface_test (render) | W | Kısmen (tap yok) | E | E | H | E | KISMEN KANITLI | |
| GS-27 | Hata diyaloğu | "Mesajı kopyala" | K: dokun | emergencyMessage ≠ null | Pano + SnackBar | — | emergency_failure_dialog.dart:154-178 | — | — | Hayır | H | H | H | H | ULAŞILAMAZ / ÖLÜ | Hiçbir çağıran emergencyMessage geçmiyor |
| GS-28 | Hata diyaloğu | "Kapat" | K: dokun | — | Diyalog + (popHost ise) geri sayım kapanır | — | emergency_failure_dialog.dart:180-186 | emergency_failure_surface_test | W | Kısmen | H | H | H | H | KISMEN KANITLI | |
| SNC-01 | Acil sonuç ekranı | Durum sunumu | S: render | Sevk sonucu | Durum kartı + başlık bandı + hedef bazında defter | — | emergency_call_screen.dart:324-677 | emergency_per_target_outcome_test | W | Evet | H | H | H | E | KANITLI | |
| SNC-02 | Acil sonuç ekranı | 5 sn fail-safe diyaloğu | S: zamanlayıcı | `isConfirmed` false (HER ZAMAN) | Her sevkte 5 sn sonra kırmızı "manuel ara" diyaloğu | — | emergency_call_screen.dart:99-108,123-284; call_service.dart:33 | — | — | Hayır | E | H | H | E | DOĞRULANMADI | |
| SNC-03 | Fail-safe diyaloğu | "Şimdi ara" | K: dokun | Numara var | ACTION_DIAL | — | emergency_call_screen.dart:217-241 | — | — | Hayır | E | E | H | H | DOĞRULANMADI | |
| SNC-04 | Fail-safe diyaloğu | "Mesajı kopyala" | K: dokun | emergencyMessage ≠ null | — | — | emergency_call_screen.dart:242-269 | — | — | Hayır | H | H | H | H | ULAŞILAMAZ / ÖLÜ | Mesaj hiç geçilmiyor |
| SNC-05 | Fail-safe diyaloğu | "Kapat" | K: dokun | — | Diyalog kapanır | Geri engelli (canPop:false) | emergency_call_screen.dart:270-282 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| SNC-06 | Acil sonuç ekranı | Ana sayfa (InkWell daire) | K: dokun | — | Durum kirası bırakılır → popUntil(ilk) | — | emergency_call_screen.dart:116-121,436-460 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| SNC-07 | Acil sonuç ekranı | 12 sn otomatik kapanış / "onaylandı" başlığı | S: zamanlayıcı | `isConfirmed` | — | — | emergency_call_screen.dart:110-114,619-626 | — | — | Hayır | H | H | H | H | ULAŞILAMAZ / ÖLÜ | `isConfirmed => false` sabit |
| SNC-08 | Acil sonuç ekranı | Numara gösterimi | S: render | Hızlı erişim (PIN'siz) | Ad maskeli | Telefon NUMARASI maskesiz gösteriliyor (ekran + fail-safe) | emergency_call_screen.dart:399-410,174-192 | emergency_trigger_host_contact_mask_test (yalnız ad) | W | Kısmen | H | H | H | E | KISMEN KANITLI | A-009 yalnız adı kapatıyor |
| SNC-09 | Acil sonuç ekranı | Sistem Geri | K: Geri | — | Pop (PopScope yok) → altındaki route | — | emergency_call_screen.dart | — | — | Hayır | E | H | H | H | DOĞRULANMADI | |
| SNC-10 | Acil sonuç ekranı | Arka plana alma | S: paused | — | Wakelock kapatılır, durum kirası bırakılır | — | emergency_call_screen.dart:83-97 | wakelock_balance_test | S | Hayır | E | H | H | H | DOĞRULANMADI | |
| HZ-01 | Hızlı Ayarlar kutucuğu | Kutucuk ekleme / onStartListening | K: gölgede düzenle-ekle | — | Kutucuk INACTIVE görünür | — | PanicTileService.kt:19-26; AndroidManifest.xml:219-228 | quick_access_panic_surface_test | S | Hayır | E | E | H | E | DOĞRULANMADI | |
| HZ-02 | Hızlı Ayarlar kutucuğu | onClick | K: dokun (cihaz açık) | — | PanicRequestStore.submit → startActivityAndCollapse (API34+ PendingIntent / 29-33 Intent) → Trampoline → MainActivity | — | PanicTileService.kt:32-53; PanicLaunch.kt; QuickPanicTrampolineActivity.kt | PanicLaunchTest; PanicRequestStoreTest; quick_access_panic_surface_test | K; S | Kısmen | E | E | H | H | KISMEN KANITLI | Tile → Activity zinciri hiçbir cihazda kayıtlı değil |
| HZ-03 | Hızlı Ayarlar kutucuğu | onClick | K: dokun (kilit ekranında) | Cihaz kilitli | Android açma ister (yorumda iddia) | `isSecure` bildirimi yok — davranış OEM'e bağlı | PanicTileService.kt:9-18 | — | — | Hayır | E | E | H | E | DOĞRULANMADI | |
| HZ-04 | Ana ekran widget'ı | APPWIDGET_UPDATE | S: widget eklendi/güncellendi | — | Tıklama PendingIntent (IMMUTABLE) bağlanır | — | PanicWidgetProvider.kt:20-44 | — | — | Hayır | E | E | H | E | DOĞRULANMADI | |
| HZ-05 | Ana ekran widget'ı | Tıklama | K: dokun | — | Trampoline → istek kaydı → MainActivity | — | PanicWidgetProvider.kt:37-44 | PanicLaunchTest | K | Kısmen | E | E | H | H | KISMEN KANITLI | |
| HZ-06 | Trampoline | onCreate | S: kendi PendingIntent'imiz | kaynak widget/tile | İstek kalıcı yazılır (commit) → MainActivity CLEAR_TOP → finish | Kayıt hatası → log, yine açılır | QuickPanicTrampolineActivity.kt:25-46 | PanicLaunchTest; PanicRequestStoreTest | K | Kısmen | E | H | H | H | KISMEN KANITLI | |
| HZ-07 | EmergencyTriggerHost | İstek tüketimi → _openCountdown | S: init + her resume | İstek var | Yetki (sınırlı) → maskeli CountdownScreen root navigator'a | Ret → paywall veya SnackBar; navigator yok → 1 kare bekle → log | emergency_trigger_host.dart:71-75,268-351 | quick_panic_request_service_test; emergency_trigger_duplicate_guard_test; emergency_trigger_host_contact_mask_test | U; W | Evet (Dart) | E | E | E | E | KISMEN KANITLI | Soğuk açılışta gerçek zincir kanıtsız |
| HZ-08 | EmergencyTriggerHost | Çoklu tetik | S: 20 hızlı tetik | — | Tam bir geri sayım route'u; kilit ilk await'ten önce alınır, her çıkışta bırakılır | — | emergency_trigger_host.dart:284-350 | emergency_trigger_duplicate_guard_test | W | Evet | H | H | H | H | KANITLI | |
| HZ-09 | EmergencyTriggerHost | Yetki çözülemedi | S: tetik | — | Root messenger'da görünür, okunur, tekilleştirilmiş SnackBar | — | emergency_trigger_host.dart:292-298,358-371 | emergency_trigger_duplicate_guard_test | W | Evet | H | H | H | E | KANITLI | |
| HZ-10 | Hızlı erişim — soğuk açılış | Rıza/onboarding/PIN ÖNCESİ tetik | S: yeni kurulum veya kilitli uygulama | Tile/widget | Geri sayım Splash/Rıza/Kilit ekranının ÜSTÜNE açılır (PIN'siz başlatma tasarım gereği) | Yeni kurulum: yetki yok → Paywall rıza ekranının üstüne | emergency_trigger_host.dart:59-75,300-316 | — | — | Hayır | E | E | E | E | DOĞRULANMADI | Kişi/PIN yoksa arm reddi diyaloğu |
| HZ-11 | MainActivity | Dış uygulama sahte PANIC_SOURCE | S: üçüncü taraf intent | — | Etkisiz (MainActivity extra okumaz; trampoline dışa kapalı) | — | MainActivity.kt:73-82; AndroidManifest.xml:186-197 | PanicLaunchTest; quick_access_panic_surface_test | K; S | Kısmen | E | H | H | H | KISMEN KANITLI | |
| SES-01 | Ses tuşu tetikleyici | 2 sn içinde 3 basış | K: ses tuşu | Ön planda, Pro, pref açık, dinleyici bağlı | "volume_panic" → _openCountdown (maskeli) ; 5 sn bekleme | — | VolumeButtonDetector.kt:63-109; volume_trigger_service.dart:78-106; emergency_trigger_host.dart:110-140 | emergency_trigger_duplicate_guard_test (kaynak düzeyi eşdeğerlik) | S | Hayır | E | E | E | H | DOĞRULANMADI | VolumeTriggerService ve VolumeButtonDetector için HİÇ test yok |
| SES-02 | Ses tuşu tetikleyici | Tuş tüketimi | K: ses tuşu | Etkin + sink bağlı | Ses seviyesi değişmez (DOWN ve UP yutulur) | — | VolumeButtonDetector.kt:63-77; MainActivity.kt:393-405 | volume_trigger_service_behavior_test; VolumeButtonDetectorTest | U; K | Kısmen (Dart/native wiring) | E | E | E | H | KISMEN KANITLI | PLAY_REQUIRED: production anahtarı SubscriptionGate arkasında; bu build `revenuecat_api_key_missing`, gerçek etkin kullanıcı zinciri Aşama 6/R1; **2026-10-28 (`6fb64d5`): beklenen davranış değişti** — artık yalnızca tetiklemeyi tamamlayan basış (DOWN+UP) yutulur, diğer basışlarda ses normal değişir; güncel takip: `docs/release/final_completion_matrix.md` SES-02 |
| SES-03 | Ses tuşu tetikleyici | Ayarlar'dan yeni açıldı | K: anahtar AÇ | Host init'te pref kapalıydı | Callback hemen bağlanır; desen aynı foreground oturumunda çalışır | Yetki yok/bilinmiyor → anahtar açılamaz, dinleyici kurulmaz | volume_trigger_service.dart:58-106; settings_provider.dart:59-65 | volume_trigger_service_behavior_test; VolumeButtonDetectorTest | U; K | Kısmen (Dart/native wiring) | E | E | E | H | KISMEN KANITLI | PLAY_REQUIRED: gerçek Pro entitlement olmadan production toggle açılamaz; Aşama 6/R1 |
| SES-04 | Ses tuşu tetikleyici | Arka plan / kilit ekranı | S: inactive/paused | — | Dinleyici iptal → tuşlar normal | — | emergency_trigger_host.dart:92-104,142-144 | volume_trigger_service_behavior_test; VolumeButtonDetectorTest | U; K | Kısmen (Dart/native wiring) | E | E | E | H | KISMEN KANITLI | PLAY_REQUIRED: etkin production zinciri gerçek Pro entitlement ister; Aşama 6/R1 |
| SES-05 | Ses tuşu tetikleyici | Yetki ücretsiz doğrulandı | S: resume | pref açık | Pref kapatılır | Yetki bilinmiyor → pref korunur, dinlenmez | emergency_trigger_host.dart:120-139 | — | — | Hayır | H | H | E | H | DOĞRULANMADI | |
| NTV-01 | CountdownAlarmReceiver | Exact/inexact alarm | S: son tarih (Doze dahil) | ARMED panik | claimAndDispatch: önce fallback bildirimi, sonra Telecom; kullanıcı kilidi açıksa olay yay/kalıcı yaz | Depo hatası → yerel olay halkası, çökme yok | CountdownAlarmReceiver.kt:15-43; EmergencySessionCoordinator.kt:248-407 | EmergencySessionCoordinatorTest; EmergencyReceiverExceptionBoundaryTest; EmergencySessionAlarmInstrumentationTest; D 2026-09-13 native-doze | K; I; D | Kısmen | E | E | H | H | KISMEN KANITLI | Fiziksel cihaz yok; D eski commit |
| NTV-02 | Koordinatör | Dart ↔ alıcı ↔ exact/inexact yarışı | S: eşzamanlı sevk | — | Nesil başına en fazla bir Telecom isteği; kaybeden kalıcı sonucu okur | Süreç ölümü sonrası belgelenmiş çift istek penceresi | EmergencySessionCoordinator.kt:248-407 | EmergencySessionCoordinatorTest (1000 iç içe geçme ×3) | K | Evet (JVM, sahte depo) | H | H | H | H | KANITLI | |
| NTV-03 | CheckInAlarmReceiver | ACTION_DISPATCH | S: son tarih | ARMED check-in/güvenli yürüyüş | claimAndDispatch (panikle aynı) | — | CheckInAlarmReceiver.kt:7-41 | EmergencySessionCoordinatorTest; EmergencyReceiverExceptionBoundaryTest | K | Kısmen | E | E | H | H | KISMEN KANITLI | |
| NTV-04 | CheckInAlarmReceiver | ACTION_GRACE | S: ana süre bitti | ARMED check-in/SW | Native "ek süre başladı" bildirimi (tür başına tek id) | Bildirim kapalı → "failed" | CheckInAlarmReceiver.kt:15-20; EmergencySessionCoordinator.kt:175-204 | EmergencySessionCoordinatorTest (uyarı testleri) | K | Kısmen | E | E | H | E | KISMEN KANITLI | |
| NTV-05 | CheckInAlarmReceiver | ACTION_PRE_WARNING | S: ön uyarı zamanı | ARMED Güvenli Yürüyüş | Native ön uyarı bildirimi | Diğer türlerde "stale" | CheckInAlarmReceiver.kt:15-20; AndroidEmergencySessionRuntime.kt:253-259 | EmergencySessionCoordinatorTest | K | Kısmen | E | E | H | E | KISMEN KANITLI | |
| NTV-06 | BootCompletedReceiver | LOCKED_BOOT_COMPLETED / BOOT_COMPLETED | S: yeniden başlatma | Kayıtlı oturum | reconcileAfterBoot: geleceğe ARMED → elapsed yeniden hesap + yeniden kur; ≤5 dk gecikmiş → ara; >5 dk → teklif bildirimi; PREPARING → CORRUPTED | Depo hatası → olay halkası | BootCompletedReceiver.kt:8-37; EmergencySessionCoordinator.kt:540-614 | AlarmClockRecoveryTest; EmergencySessionCoordinatorTest; Phase3RebootProbeTest; OverdueSessionProbeTest; D 2026-09-20 | K; I; D | Kısmen | E | E | H | E | KISMEN KANITLI | D: karar ölçüldü, gerçek reboot tetikleyicisi bu turda değil |
| NTV-07 | BootCompletedReceiver | MY_PACKAGE_REPLACED | S: uygulama güncellemesi | Kayıtlı oturum | reconcileCurrentBoot | — | BootCompletedReceiver.kt:18-26 | EmergencyReceiverExceptionBoundaryTest | K | Kısmen | E | E | E | H | KISMEN KANITLI | Play üzerinden gerçek güncelleme hiç denenmedi |
| NTV-08 | BootCompletedReceiver | USER_UNLOCKED | S: ilk kilit açma | Kayıtlı oturum | reconcileCurrentBoot | — | BootCompletedReceiver.kt:18-26 | DirectBootSafetyKernelTest | K | Kısmen | E | E | H | H | KISMEN KANITLI | |
| NTV-09 | Force-stop sonrası açılış | PACKAGE_UNSTOPPED + LOCKED_BOOT_COMPLETED | S: kullanıcı uygulamayı açar | Force-stop sırasında ARMED | >5 dk: arama YOK, "Geri sayımınız tamamlanamadı" bildirimi; ≤5 dk: sormadan arar | — | EmergencySessionCoordinator.kt:512-586,709 | EmergencySessionCoordinatorTest (overdue 6 test); OverdueSessionProbeTest; D 2026-09-13 force-stop; D 2026-09-20 | K; I; D | Kısmen | E | E | H | E | KISMEN KANITLI | D 09-20 gerçek force-stop→açılış döngüsünü değil kararı ölçtü |
| NTV-10 | Force-stop sonrası açılış | Bayat CLAIMED kaydı | S: açılış | Kayıt CLAIMED | Bayat kayıt otomatik aranmaz; kullanıcıya manuel eylem sunulur | Taze CLAIMED kayıt sevk edilir; iki yönlü negatif kontrol | EmergencySessionCoordinator.kt | EmergencySessionCoordinatorTest; OverdueSessionProbeTest | K; I; D | Evet; final APK'da dört opt-in prob | E | E | H | H | KANITLI | E4-STALE-02, APK `7ddb5071…` |
| NTV-11 | Gecikmiş oturum teklifi | Bildirime dokun | K: dokun | MANUAL_ACTION_REQUIRED + POSTED | EmergencyFallbackDialActivity → consumeFallbackTarget (token/TTL, tek kullanım) → ACTION_DIAL | TTL geçti/uyuşmaz → sessizce kapanır | EmergencyFallbackDialActivity.kt:16-35; EmergencySessionCoordinator.kt:460-510 | EmergencySessionCoordinatorTest ("consumed exactly once", "fail closed after 24h"); DirectBootSafetyKernelTest | K | Kısmen | E | E | H | H | KISMEN KANITLI | D 09-20: dokunma→arama zinciri ölçülmedi |
| NTV-12 | Manuel fallback bildirimi | Bildirime dokun | K: dokun | Sevkte POSTED | Aynı dial aktivitesi | — | AndroidEmergencySessionRuntime.kt:122-175 | EmergencySessionCoordinatorTest | K | Kısmen | E | E | H | H | KISMEN KANITLI | |
| NTV-13 | Fallback bildirimi | Kaydırıp silme (deleteIntent) | K: kaydır | — | CleanupReceiver → expireFallback + PendingIntent iptali | — | EmergencyFallbackCleanupReceiver.kt:13-45 | EmergencyReceiverExceptionBoundaryTest | K | Kısmen | E | E | H | H | KISMEN KANITLI | |
| NTV-14 | Fallback bildirimi | 24 saat TTL alarmı | S: RTC alarmı | — | Hedef silinir, bildirim kaldırılır | Exact izin yoksa inexact | EmergencyFallbackCleanupReceiver.kt:88-120 | EmergencySessionCoordinatorTest | K | Kısmen | E | E | H | H | KISMEN KANITLI | |
| NTV-15 | Direct Boot | İlk kilit açılmadan alıcılar | S: kilitli önyükleme | — | Cihaz-korumalı depo; olay yayını yalnız kilit açıkken | — | DirectBootAccess.kt; DeviceProtectedEmergencySessionStore.kt | DirectBootSafetyKernelTest; DeviceProtectedEmergencySessionStoreTest | K | Kısmen | E | E | H | H | KISMEN KANITLI | |
| NTV-16 | ClockChangeReceiver | TIME_SET / TIMEZONE_CHANGED | S: saat değişti | ARMED | Kalan elapsed süre korunur, duvar saati son tarihleri yeniden hesaplanır; 0 → sevk | — | ClockChangeReceiver.kt:8-22; EmergencySessionCoordinator.kt:617-637 | AlarmClockRecoveryTest; time_boundary_safety_test | K; U | Kısmen | E | E | H | H | KISMEN KANITLI | |
| NTV-17 | ExactAlarmPermissionReceiver | İzin verildi yayını | S: kullanıcı izni verdi | ARMED | reconcileCurrentBoot → exact'e yükselt | — | ExactAlarmPermissionReceiver.kt:16-30 | EmergencyReceiverExceptionBoundaryTest | K | Kısmen | E | E | H | H | KISMEN KANITLI | |
| NTV-18 | Exact alarm izni geri alındı | OS süreci öldürür | S: izin iptali | ARMED | Exact alarmlar silinir; inexact yedek ne olur? | — | ExactAlarmPermissionReceiver.kt:8-15 (yorum) | — | — | Hayır | E | E | H | H | DOĞRULANMADI | |
| NTV-19 | Alıcı sınırı | Depo/servis kurulum hatası | S: RuntimeException | — | Olay halkasına kod, çökme yok | — | EmergencyReceiverGuard.kt | EmergencyReceiverExceptionBoundaryTest (6) | K | Evet | H | H | H | H | KANITLI | |
| NTV-20 | Olay kanalı | `emergencySessionDispatched` | S: alıcı sevk etti, Flutter canlı | — | Dart: CheckIn/SW resume + geçmiş uzlaştırma | — | emergency_trigger_host.dart:146-181 | native_event_contract_test | S | Hayır | E | H | H | H | DOĞRULANMADI | |
| NTV-21 | Bekleyen tetik | KEY_PENDING_TRIGGER | S: Flutter ölüyken sevk | — | init/resume'da tüketilir → uzlaştırma | — | EmergencyEventBus.kt:33-70; emergency_trigger_host.dart:183-210 | native_event_contract_test | S | Hayır | E | H | H | H | DOĞRULANMADI | |
| NTV-22 | Olay kanalı | `checkInGraceStarted` / `checkInExpired` / `safetyClockChanged` | S: native olay | — | Dart işleyicileri var | Mevcut native kod bu türleri HİÇ yaymıyor | emergency_trigger_host.dart:153-174,192-199 | native_event_contract_test | S | Hayır | H | H | H | H | ULAŞILAMAZ / ÖLÜ | Yalnız eski sürümden kalma kalıcı payload ile teorik |
| NTV-23 | Native geçmiş | pendingEmergencyOutcomes/acknowledge | S: init/resume | Native terminal sonuç | Güvenlik geçmişine kayıt, onay | Hata → bir sonraki resume'da tekrar | native_emergency_history.dart; EmergencyTerminalJournal.kt | native_emergency_history_test | U | Kısmen | E | H | H | H | KISMEN KANITLI | |
| NTV-24 | Native uyarı bildirimleri | Dokun (varsayılan contentIntent) | K: dokun | Ek süre/ön uyarı bildirimi | MainActivity açılır; `pending_trigger_type` extra'sı OKUNMAZ | — | EmergencyNotificationHelper.kt:72-88,132 | — | — | Hayır | E | E | H | H | DOĞRULANMADI | |
| NTV-25 | Native bildirim metni | Dil çözümü | S: bildirim | — | Uygulamanın kalıcı dili (cihaz dili değil) | — | NativeNotificationText.kt:110-168 | NativeNotificationTextTest | K | Evet | H | H | H | H | KANITLI | |
| NTV-26 | Native bildirim | Bildirim/kanal kapalı | S: gönderim | — | showAlert false → fallback FAILED → REQUEST_FAILED veya yalnız arama | — | EmergencyNotificationHelper.kt:108-163 | EmergencySessionCoordinatorTest; FullScreenIntentNotificationTest | K | Kısmen | E | E | H | H | KISMEN KANITLI | |
| NTV-27 | Arm yetenek reddi | OS<29 / telefon yok / exact / bildirim / kanal / izin / PIN / hedef / yetki | S: arm | — | Tipli ret kodu | — | AndroidEmergencySessionRuntime.kt:40-93; EmergencySessionModels.kt | EmergencySessionCoordinatorTest; EmergencyPlatformReadinessTest; SupportedOsBoundaryInstrumentationTest | K; I | Kısmen | E | E | H | H | KISMEN KANITLI | |
| NTV-28 | Süreç ölümü (sevk ortası) | CLAIMED sonrası | S: süreç öldü | — | Kalıcı durumdan en-az-bir-kez yeniden deneme; belgelenmiş çift istek penceresi | — | EmergencySessionCoordinator.kt:1-13,365-397 | EmergencySessionCoordinatorTest (4 süreç ölümü testi) | K | Evet (JVM) | E | E | H | H | KISMEN KANITLI | Gerçek süreç ölümü değil, simülasyon |
| NTV-29 | Kanal: kişi seçici | pickPhoneContact | S: ACTION_PICK sonucu | — | Ad+numara / iptal→null / ALREADY_ACTIVE / NO_PICKER / PICK_FAILED | Süreç ölümü sonrası sonuç düşer | MainActivity.kt:337-348,420-480 | contacts_picker_native_test | S; U | Kısmen (Dart eşlemesi) | E | E | H | H | KISMEN KANITLI | Kotlin tarafı testsiz |
| NTV-30 | Kanal: android_intents | openDialer | S: Dart çağrısı | — | Doğrulanmış numara ile ACTION_DIAL | Geçersiz → false; uygulama yok → false | MainActivity.kt:223-242,482-503 | android_intent_service_test | U | Kısmen | E | E | H | H | KISMEN KANITLI | |
| NTV-31 | Kanal: settings | openNotificationSettings / openNotificationChannelSettings / openActivityByComponent / getDeviceManufacturer | S: Dart çağrısı | — | İlgili sistem ekranı / üretici adı | NOT_FOUND / INVALID_ARG | MainActivity.kt:247-332 | notification_categories_test; oem_background_guide_service_test | W; U | Kısmen | E | E | H | H | KISMEN KANITLI | |
| NTV-32 | Kanal: audio_control | setMaxAlarmVolume / restoreAlarmVolume | S: siren | — | Alarm akışı maks, sonra geri | Hata yutulur | MainActivity.kt:154-197; siren_dialog.dart:114-151 | — | — | Hayır | E | E | H | H | DOĞRULANMADI | |
| NTV-33 | Kanal: device_integrity | probe | S: splash | — | Kontrol başına found/absent/error, 3 sn | PROBE_FAILED → unknown | DeviceIntegrityChannel.kt | DeviceIntegrityProbeTest; device_security_service_test; DeviceIntegrityEmulatorProbeTest | K; U; I | Kısmen | E | E | H | H | KISMEN KANITLI | |
| NTV-34 | Kanal: emergency_platform | getEmergencyCapabilities, openManufacturerSettings | S: — | — | — | Dart'ta çağıran yok (`openManufacturerBatterySettings` çağrılmıyor) | EmergencyPlatformHandler.kt:87-89,141-143; battery_optimization_service.dart:171 | EmergencyPlatformReadinessTest | K | Hayır | H | H | H | H | ULAŞILAMAZ / ÖLÜ | |
| NTV-35 | Kanal: emergency_platform | 9 eski yöntem (scheduleCheckIn … clearEmergencyPrefs) | S: eski Dart | — | notImplemented (fail-closed) | — | EmergencyPlatformHandler.kt:109-120 | LegacySafetyAuthorityTest | K | Evet | H | H | H | H | ULAŞILAMAZ / ÖLÜ | Mevcut Dart çağırmıyor |
| NTV-36 | EmergencyNotificationHelper | buildOngoingServiceNotification | — | — | — | Çağıran yok | EmergencyNotificationHelper.kt:90-106 | — | — | Hayır | H | H | H | H | ULAŞILAMAZ / ÖLÜ | |
| NTV-37 | MainActivity | Kanal kaydı hatası (herhangi) | S: configureFlutterEngine istisnası | — | Yalnız logcat; acil kanal yoksa Dart MissingPlugin ile anlar | Diğer kanallarda Dart farkında olmaz | MainActivity.kt:108-391 | countdown_bridge_missing_test; emergency_platform_bridge_test | W; U | Kısmen (Dart simülasyonu) | E | H | H | H | KISMEN KANITLI | Native hata enjeksiyonu yok |
| NTV-38 | MainActivity | onDestroy | S: aktivite yok edildi | — | Ses dedektörü kapatılır | — | MainActivity.kt:410-418 | — | — | Hayır | E | H | H | H | DOĞRULANMADI | |
| DL-01 | Derin bağlantı | VIEW korubeni://open/… (soğuk) | S: dış uygulama/tarayıcı | — | onCreate'te 512 karakter + şema kontrolü → park | Aşım/yabancı şema → yok sayılır | MainActivity.kt:56-106; AndroidManifest.xml:107-112 | deep_link_test (MainActivity kısmı kaynak) | S | Hayır | E | H | H | H | DOĞRULANMADI | Cihazda `adb am start` kaydı yok |
| DL-02 | Derin bağlantı | VIEW (sıcak, singleTop) | S: onNewIntent | Uygulama açık | Park → resume'da toplanır | — | MainActivity.kt:85-91; main_navigation.dart:135-158 | deep_link_test | S; U | Kısmen | E | H | H | H | KISMEN KANITLI | |
| DL-03 | Derin bağlantı | Ayrıştırma + park | S: Dart consume | — | İzin listesi, tek segment, parametre kuralı, tek-kullanım, en son kazanır, ham URI kaydedilmez | Ret → park yok, kod kaydı | deep_link_parser.dart; pending_destination_service.dart | deep_link_test (30 test) | U | Evet | H | H | H | H | KANITLI | |
| DL-04 | Derin bağlantı | Kapılardan önce gelen link | S: kilitli/rızasız | — | MainNavigation kurulana dek park | — | main_navigation.dart:122-133 | deep_link_test (kaynak düzeyi) | S | Hayır | E | H | H | H | DOĞRULANMADI | |
| DL-05 | Derin bağlantı | /home | S: yönlendir | — | Sekme 0 | — | destination_router.dart:32-36 | deep_link_test | U; S | Kısmen | E | H | H | H | KISMEN KANITLI | DestinationRouter yalnız kaynak-metni testli |
| DL-06 | Derin bağlantı | /map | S: yönlendir | — | Sekme 1 | — | destination_router.dart:32-36 | deep_link_test | U; S | Kısmen | E | H | H | H | KISMEN KANITLI | |
| DL-07 | Derin bağlantı | /contacts | S: yönlendir | Kapı (ücretsiz) | Sekme 2 | — | app_destination.dart:76-81 | deep_link_test | U; S | Kısmen | E | H | H | H | KISMEN KANITLI | |
| DL-08 | Derin bağlantı | /settings | S: yönlendir | — | Sekme 3 | — | destination_router.dart:32-36 | deep_link_test | U; S | Kısmen | E | H | H | H | KISMEN KANITLI | |
| DL-09 | Derin bağlantı | /timeline | S: yönlendir | Kapı (ücretsiz) | SafetyTimelineScreen push | — | destination_router.dart:38-55 | deep_link_test | U; S | Kısmen | E | H | H | H | KISMEN KANITLI | |
| DL-10 | Derin bağlantı | /check-in | S: yönlendir | Pro kapısı | CheckInScreen push | Ret → paywall/SnackBar | destination_router.dart:25-30,38-55 | deep_link_test | U; S | Kısmen | E | H | E | H | KISMEN KANITLI | |
| DL-11 | Derin bağlantı | /subscription | S: yönlendir | — | PaywallScreen push | — | destination_router.dart:41 | deep_link_test | U; S | Kısmen | E | H | E | H | KISMEN KANITLI | |
| BLD-01 | Dart bildirimi | Gecikmeli sahte çağrı zamanlama | K: 1/3/10/15 dk seç | Bildirim izni + exact alarm | zonedSchedule(id 31001, exactAllowWhileIdle) → "zamanlandı" SnackBar | İzin yok → SnackBar; exact yok → false | notification_service.dart:181-221 | — | — | Hayır | E | E | H | E | DOĞRULANMADI | KRİTİK GÖZLEM: birleşik manifest'te `ScheduledNotificationReceiver` YOK → bildirim hiç görünmeyebilir |
| BLD-02 | Dart bildirimi | Sahte çağrı bildirimine dokun (uygulama canlı) | K: dokun | payload `fake_call` | Root navigator'a FakeCallScreen (PIN'siz, tasarım gereği) | — | notification_service.dart:242-272 | — | — | Hayır | E | E | H | H | DOĞRULANMADI | |
| BLD-03 | Dart bildirimi | Sahte çağrı bildirimine dokun (süreç ölü) | K: dokun | Teslim edilmiş sahte çağrı bildirimi | Cold-launch response bir kez park edilir; root Navigator ilk karesinde gerçek FakeCallScreen açılır | Navigator hazır değilse istek tüketilmeden bekler; duplicate route yok | notification_service.dart; main.dart | notification_cold_launch_test | U; D | Evet; süreç öldürüldükten sonra gerçek bildirime dokunuldu | E | E | H | H | KANITLI | E4-FAKECALL-02, APK `7ddb5071…`; `stage4-final-fake-call-cold-action.png` |
| BLD-04 | Dart bildirimi | Payload `timeline` / `check_in` / `subscription` | K: dokun | — | Park → yönlendirme | Uygulama bu payload'ları HİÇ üretmiyor | notification_service.dart:235-257 | deep_link_test ("a notification submits through the SAME park") | U | Kısmen | H | H | H | H | ULAŞILAMAZ / ÖLÜ | |
| BLD-05 | Dart bildirimi | Acil uyarı bildirimi (check-in sevki) | S: sevk sonrası | — | Yüksek önem bildirimi; sonuç tipli (izin yok / kullanıcı kapattı / teslim) | — | notification_service.dart:102-150 | safety_alert_outcome_test; notification_channel_name_test | U | Kısmen | E | E | H | E | KISMEN KANITLI | Payload yok → dokunma yalnız uygulamayı açar |
| BLD-06 | Durum bildirimi | "Aktif güvenlik oturumu" (kira sayımlı) | S: geri sayım/check-in/SW | — | Düşük önem, süreli; sahip bıraktığında kalkar | — | foreground_service.dart; foreground_service_ownership.dart | foreground_service_ownership_test; (foreground_service yalnız S) | U; S | Kısmen | E | E | H | E | KISMEN KANITLI | Gerçek FGS değil |
| CHK-01 | Check-In kurulum | Süre kartı 15 dk / 30 dk / 1 sa / 2 sa (4 seçenek) | K: dokun | Pro ile girildi | Başlatma akışı (CHK-02) | — | check_in_screen.dart:362-366,429-434 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | CheckInScreen hiçbir testte pump edilmiyor |
| CHK-02 | Check-In | Başlatma ön koşul zinciri | K: süre seç | — | Kişi → ilk kullanım uyarısı → bildirim izni → exact alarm → yetki (+PIN) → startSession (ana süre + 60 sn ek süre, native arm) | Kişi yok → SnackBar+"Kişi ekle"; bildirim reddi → SnackBar+"Bildirim ayarları"; exact yok → CHK-04 | check_in_screen.dart:176-234 | check_in_service_behavior_matrix_test; check_in_typed_session_test; safety_session_callsite_contract_test | U; S | Kısmen (servis gerçek, ekran değil) | E | E | E | E | KISMEN KANITLI | Ekrandaki `resolveAccess()` ZAMAN SINIRSIZ (panikteki 1,8 sn bütçe yok) |
| CHK-03 | Check-In | "Kişi ekle" SnackBar eylemi | K: dokun | Kişi yok | ContactsPage push | — | check_in_screen.dart:120-137 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| CHK-04 | Exact alarm kapısı | "Vazgeç" / "Ayarları aç" | K: dokun | Exact izni yok | Vazgeç → başlamaz; Ayarlar → sistem ekranı, fonksiyon yine false döner (kullanıcı tekrar başlatmalı) | — | exact_alarm_permission_guard.dart:14-63 | emergency_timer_release_blockers_test | S | Hayır | E | E | H | E | DOĞRULANMADI | |
| CHK-05 | Check-In | "Bildirim ayarları" SnackBar eylemi | K: dokun | Bildirim reddi | Sistem bildirim ayarları | Kanal yoksa uygulama ayarları | check_in_screen.dart:203-208; permission_helper.dart:237-249 | — | — | Hayır | E | E | H | H | DOĞRULANMADI | |
| CHK-06 | Check-In | Arm başarısız mesajları | S: arm sonucu | — | belirsiz / PIN yükleniyor / PIN gerekli / PIN okunamadı / yetki doğrulanamadı / hazır değil | — | check_in_screen.dart:139-161 | check_in_service_behavior_matrix_test | U | Kısmen | H | H | E | E | KISMEN KANITLI | |
| CHK-07 | Check-In aktif | Kalan süre sayacı + halka | S: ticker | ARMED | Saniyelik güncelleme, durum bildirimi | Native zamanlama degrade → uyarı bandı | check_in_screen.dart:474-600; check_in_service.dart:413-465 | check_in_service_behavior_matrix_test; time_boundary_safety_test | U | Kısmen | E | H | H | E | KISMEN KANITLI | |
| CHK-08 | Check-In aktif | "Güvendeyim" | K: dokun | ARMED | PIN kapısı → confirmSafeSession (yeni nesil süre) → onay SnackBar | Arm sonucu ≠ Armed → mesaj | check_in_screen.dart:236-263,610 | check_in_service_behavior_matrix_test; safety_session_pin_gate_test | U; W | Kısmen | E | H | H | E | KISMEN KANITLI | |
| CHK-09 | Check-In aktif | "İptal" | K: dokun | ARMED | PIN kapısı → stopSession → native iptal | Çok geç / onaylanamadı → SnackBar | check_in_screen.dart:265-273,633 | check_in_service_behavior_matrix_test; check_in_dedup_cancel_before_call_test | U | Kısmen | E | H | H | E | KISMEN KANITLI | |
| CHK-10 | Güvenlik PIN diyaloğu | Metin alanı onSubmitted / "Onayla" / "İptal" | K: PIN gir | Oturum eylemi | Doğru → true; yanlış → hata metni + sayaç kaydı (asla kısmaz); iptal → false | Depo okunamaz → diyalog hiç açılmaz, false | safety_session_pin_gate.dart:20-240 | safety_session_pin_gate_test; safety_session_pin_lockout_test; sensitive_action_pin_gate_test | W; S | Evet | H | H | H | E | KANITLI | |
| CHK-11 | Check-In | Ek süre başlangıcı (ön planda) | S: ana süre bitti | ARMED | Kırmızı ek süre görünümü + Dart ek süre bildirimi | Bildirim teslim edilemedi → SnackBar | check_in_service.dart:486-514; check_in_screen.dart:81-106 | safety_alert_outcome_test; check_in_service_behavior_matrix_test | U | Kısmen | E | E | H | E | KISMEN KANITLI | Arka plan tarafı NTV-04 |
| CHK-12 | Check-In | Süre sonu → sevk | S: ek süre bitti | ARMED | dispatch → istek gönderildi → alarm bildirimi + geçmiş + EmergencyCallScreen push | İstek yok → dialer; bilinmiyor → projeksiyon korunur + log | check_in_service.dart:545-660 | check_in_service_behavior_matrix_test; check_in_primary_only_contract_test | U | Kısmen | E | E | H | E | KISMEN KANITLI | Yalnız birincil kişi aranır |
| CHK-13 | Check-In | Resume / yeniden başlatma uzlaştırması | S: resume/init | Kayıtlı oturum | Native discover: ARMED → ticker; terminal → geçmiş + temizle; yok → temizle; bozuk → degrade | — | check_in_service.dart:339-411 | check_in_service_behavior_matrix_test; check_in_shared_controller_test | U; S | Kısmen | E | E | H | H | KISMEN KANITLI | |
| CHK-14 | Check-In | Ekrandan çıkma | K: Geri | ARMED | Oturum sürer (singleton), uyarı yok | — | check_in_screen.dart (PopScope yok) | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| SWK-01 | Güvenli Yürüyüş | Süre çipi 5/10/15/30/60 dk | K: dokun | Aktif değil | Seçim | — | safe_walk_screen.dart:50,420-428 | safe_walk_timer_test | S | Hayır | H | H | H | E | DOĞRULANMADI | SafeWalkScreen hiç pump edilmiyor |
| SWK-02 | Güvenli Yürüyüş | "Başlat" | K: dokun | — | CHK-02 ile aynı zincir (uyarı metni check-in'inkiyle aynı) | Aynı ret mesajları | safe_walk_screen.dart:95-155,472 | check_in_service_behavior_matrix_test; safe_walk_persist_test | U; S | Kısmen | E | E | E | E | KISMEN KANITLI | `resolveAccess()` zaman sınırsız |
| SWK-03 | Güvenli Yürüyüş | "Kişi ekle" / "Bildirim ayarları" SnackBar eylemleri | K: dokun | — | ContactsPage / sistem ayarları | — | safe_walk_screen.dart:123-127,176-180 | — | — | Hayır | E | H | H | H | DOĞRULANMADI | |
| SWK-04 | Güvenli Yürüyüş | Ön uyarı (Dart) | S: ≤120 sn (kısa sürede %10) | ARMED | Haptik + ön uyarı bildirimi | Teslim edilemedi → SnackBar | safe_walk_screen.dart:78-93,233-247 | safety_alert_outcome_test | U; S | Kısmen | E | E | H | E | KISMEN KANITLI | |
| SWK-05 | Güvenli Yürüyüş | "Güvendeyim" | K: dokun | ARMED, sevk talep edilmemiş | PIN → stopSession → etkinlik kaydı → SnackBar | Talep edildiyse yok sayılır | safe_walk_screen.dart:249-293,622 | check_in_expiry_coordinator_test | U | Kısmen | E | H | H | E | KISMEN KANITLI | |
| SWK-06 | Güvenli Yürüyüş | "İptal" | K: dokun | ARMED | PIN → stop | Başarısız → SnackBar | safe_walk_screen.dart:295-310,641 | check_in_service_behavior_matrix_test | U | Kısmen | E | H | H | E | KISMEN KANITLI | |
| SWK-07 | Güvenli Yürüyüş | AppBar geri | K: dokun | Aktif | Çıkış uyarı diyaloğu | Aktif değil → pop | safe_walk_screen.dart:337-345 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| SWK-08 | Çıkış diyaloğu | "Kal" | K: dokun | — | Kapanır | — | safe_walk_screen.dart:685 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| SWK-09 | Çıkış diyaloğu | "İptal et ve çık" | K: dokun | — | PIN → iptal → pop | İptal başarısız → ekranda kal | safe_walk_screen.dart:689-695 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| SWK-10 | Güvenli Yürüyüş | Sistem Geri | K: Geri | Aktif | Uyarısız pop; oturum sürer | — | safe_walk_screen.dart (PopScope yok) | — | — | Hayır | E | H | H | H | DOĞRULANMADI | AppBar geri ile tutarsız |
| SWK-11 | Güvenli Yürüyüş | Süre sonu → sevk | S: bitti | ARMED | CHK-12 ile aynı (safe_walk türü) | — | check_in_service.dart:545-660 | check_in_service_behavior_matrix_test | U | Kısmen | E | E | H | E | KISMEN KANITLI | |
| FKC-01 | Sahte çağrı sayfası | Rıza kapısı | K: kartı aç | typeFakeCall | Gecikme seçenek sayfası | Rıza yok → SnackBar | home_page.dart:476-482 | consent_gate_enforcement_test | S | Hayır | H | H | H | H | DOĞRULANMADI | |
| FKC-02 | Sahte çağrı sayfası | "Şimdi" | K: dokun | — | FakeCallScreen push | — | home_page.dart:524,552-577 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| FKC-03 | Sahte çağrı sayfası | 1 dk / 3 dk / 10 dk / 15 dk | K: dokun | — | BLD-01 zamanlama | — | home_page.dart:525-545,580-639 | — | — | Hayır | E | E | H | E | DOĞRULANMADI | Bkz. BLD-01 manifest bulgusu |
| FKC-04 | Sahte çağrı sayfası | "Bildirim ayarları" SnackBar eylemi | K: dokun | Bildirim kalıcı reddi | Sistem bildirim ayarları | — | home_page.dart:599-608 | E4-FINAL9-FKC04 | D | Kısmen; gerçek Android izni iki kez kullanıcı tarafından reddedildi, USER_FIXED oluştu, üçüncü denemede production SnackBar eylemi APP_NOTIFICATION_SETTINGS açtı | E | E | H | H | KISMEN KANITLI | APK `6fe2b8dc…`; `stage4-final9-fkc04-third.png/.xml`, `stage4-final9-fkc04-notification-settings.png`; test sonrası izin granted restore; fiziksel remainder sürüyor |
| FKC-05 | FakeCallScreen | İlk kullanım uyarısı "İptal" / "Kabul" | K: dokun | İlk açılış | İptal → pop; Kabul → pref + 'fake_call' rızası + zil sesi | Rıza yazımı hatası BOŞ catch ile yutulur | fake_call_screen.dart:87-169 | fake_call_consent_order_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| FKC-06 | FakeCallScreen | Rıza yeniden kontrolü | S: açılış | Rıza yok | maybePop | — | fake_call_screen.dart:75-81 | fake_call_consent_order_test | S | Hayır | H | H | H | H | DOĞRULANMADI | |
| FKC-07 | FakeCallScreen | Zil sesi | S: açılış | Ses ayarı açık | ringtone.wav döngüde | Ses ayarı kapalı/asset hatası → hata göstergesi | fake_call_screen.dart:251-280 | E4-FINAL9-FKC07 | D | Kısmen; production FakeCallScreen'de Android AudioTrack aktif, app logu `Ringtone started playing` ve UI arama durumundaydı | E | E | H | E | KISMEN KANITLI | APK `6fe2b8dc…`; `stage4-final9-fkc07-ringing2.png/.xml`, audio_flinger active track; fiziksel/görsel remainder sürüyor |
| FKC-08 | FakeCallScreen | "Reddet" | K: dokun | — | Zil durur, etkinlik kaydı, pop | — | fake_call_screen.dart:435-450,491 | fake_call_haptic_source_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| FKC-09 | FakeCallScreen | "Kabul et" | K: dokun | — | Zil durur, kayıt, pop (arama içi simülasyon YOK) | — | fake_call_screen.dart:452-467,491 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| FKC-10 | FakeCallScreen | Üst kapatma ikonu | K: dokun | — | Zil durur, pop | — | fake_call_screen.dart:311-314 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| FKC-11 | FakeCallScreen | "Özelleştir" | K: dokun | — | Ad/numara/foto alt sayfası | — | fake_call_screen.dart:321,515-700 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| FKC-12 | Özelleştir sayfası | "Foto seç" | K: dokun | — | Galeri → temizlenmiş avatar kopyası | İptal → yok; hata → SnackBar | fake_call_screen.dart:614,703-735; avatar_store_service.dart | avatar_store_service_test; image_sanitizer_service_test; E4-FINAL9-FKC12 | U; D | Kısmen; gerçek Android Photo Picker image/* açıldı, seçilen PNG işlendi ve 0600 `app_flutter/fake_call_avatar.jpg` olarak kaydedildi | E | E | H | E | KISMEN KANITLI | APK `6fe2b8dc…`; `stage4-final9-fkc12-picker/result/saved.png/.xml`; dosya 13742 byte; fiziksel/görsel remainder sürüyor |
| FKC-13 | Özelleştir sayfası | Şablon çipleri (×4) | K: dokun | — | Ad/numara alanları doldurulur | — | fake_call_screen.dart:560-587,748-765 | fake_call_presets_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| FKC-14 | Özelleştir sayfası | "Kaydet" | K: dokun | — | secure storage'a ad/numara/avatar, pop | Boş → varsayılan ad | fake_call_screen.dart:652-677 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| SRN-01 | Siren | Açılış | K: kartı aç | — | İlk kullanım uyarısı → alarm akışı maks → siren.wav döngü + saniyelik haptik | Ses ayarı KAPALI → siren çalmaz (hata görünümü); ses hatası → hata görünümü | siren_dialog.dart:53-133 | — | — | Hayır | E | E | H | E | DOĞRULANMADI | "Ses" ayarı sireni de susturur |
| SRN-02 | Siren | "Durdur" | K: dokun | — | Etkinlik kaydı (süre) → kapanır → ses seviyesi geri | — | siren_dialog.dart:255-266,142-151 | — | — | Hayır | E | E | H | H | DOĞRULANMADI | |
| SRN-03 | Siren | Geri / dış dokunma | K: Geri | — | Engelli (canPop:false) | — | siren_dialog.dart:156-157 | — | — | Hayır | E | H | H | H | DOĞRULANMADI | |
| SRN-04 | Siren | Uygulama arka plana | S: paused | Çalıyor | Kod: ses durdurulmuyor (dispose'a kadar) | — | siren_dialog.dart | — | — | Hayır | E | E | H | H | DOĞRULANMADI | |
| KSI-01 | Kişiler | Açılış (sekme veya push) | S: initState | — | Provider bir kez yüklenir (yükleniyor → liste/boş) | Yükleme hatası → yalnız debugPrint, boş liste | contacts_page.dart:62-68; contacts_provider.dart:43-58 | contacts_provider_add_validation_test | U | Kısmen | H | H | H | E | KISMEN KANITLI | ContactsPage hiç pump edilmiyor |
| KSI-02 | Kişiler | AppBar "+" | K: dokun | — | Kapı (ücretsiz) → acil kişi rızası → KVKK bilgi diyaloğu (ilk kez) → ekleme sayfası | Rıza yok (varsayılan) → SnackBar | contacts_page.dart:88-110,715-718 | consent_gate_enforcement_test; premium_gating_contract_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| KSI-03 | KVKK kişi bilgi diyaloğu | "Tamam" | K: dokun | İlk ekleme | Bir daha gösterilmez | — | contacts_page.dart:660-713 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| KSI-04 | Ekleme sayfası | "Rehberden seç" | K: dokun | — | Seçici → normalize → rıza diyaloğu → ekle | Seçici hatası / numara yok / limit / zaten var → SnackBar | contacts_page.dart:826-829,977-1046 | contacts_picker_native_test; E4-FINAL9-KSI04 | S; U; D | Kısmen; gerçek ACTION_PICK, StageFour sonucu, normalize edilmiş numara ve production rıza diyaloğu çalıştı | E | E | H | E | KISMEN KANITLI | APK `6fe2b8dc…`; `stage4-final9-ksi04-picker/consent/result2.png/.xml`; fiziksel/görsel remainder sürüyor |
| KSI-05 | Ekleme sayfası | Ad alanı / Telefon alanı (yalnız 0-9 ve +, doğrulayıcı) | K: yaz | — | Canlı doğrulama (onUserInteraction) | — | contacts_page.dart:848-890 | contacts_manual_phone_validation_test | U | Kısmen (saf fonksiyon) | H | H | H | E | KISMEN KANITLI | |
| KSI-06 | Ekleme sayfası | Klavye "bitti" (onFieldSubmitted) / "Kaydet" | K: dokun | — | Ad boş → SnackBar; telefon geçersiz → SnackBar; rıza diyaloğu → ekle → "eklendi" | Limit (5) / tekrar → SnackBar | contacts_page.dart:884-904,926-975 | contacts_provider_add_validation_test; contact_service tests | U | Kısmen | H | H | H | E | KISMEN KANITLI | Eklenen kişi otomatik BİRİNCİL olmaz |
| KSI-07 | Ekleme sayfası | Klavye açıkken görünürlük | S: odak | — | Telefon alanı kaydırılır | — | contacts_page.dart:726-743 | add_contact_keyboard_visibility_test; E4-FINAL9-KSI07 | S; D | Evet; gerçek Android IME açıkken telefon alanı `[63,1168][1017,1315]`, Manuel kaydet `[63,1357][1017,1483]` görünür kaldı | E | H | H | E | KANITLI | APK `6fe2b8dc…`; `stage4-final9-ksi07-ime.png/.xml`; yalnız görsel remainder |
| KSI-08 | Kişiler | Boş durum "Kişi ekle" | K: dokun | Liste boş | Doğrudan cihaz seçicisi (manuel form değil) | Rıza yok → SnackBar | contacts_page.dart:560-630 | — | — | Hayır | E | H | H | E | DOĞRULANMADI | |
| KSI-09 | Kişiler | "Acil kişiyi seç" (TextButton) | K: dokun | Kişi var | Seçici alt sayfası | Kişi yok → pasif | contacts_page.dart:135-145,1048-1146 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| KSI-10 | Acil seçici | Kişi ListTile | K: dokun | — | Birincil olarak kaydedilir → Home yenilenir → SnackBar | — | contacts_page.dart:1122-1137 | contact_service tests | U | Kısmen | H | H | H | E | KISMEN KANITLI | |
| KSI-11 | Kişi kartı | Karta dokun | K: dokun | — | Seçenek alt sayfası | — | contacts_page.dart:267-270,370-521 | contacts_card_overflow_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| KSI-12 | Seçenek sayfası | "Ara" | K: dokun | — | Dialer (ACTION_DIAL) | — | contacts_page.dart:427-430 | android_intent_service_test; E4-FINAL9-KSI12 | U; D | Kısmen; production StageFour Ara tap gerçek Dialer'ı `tel:5551234567` ile açtı | E | E | H | H | KISMEN KANITLI | APK `6fe2b8dc…`; `stage4-final9-ksi12-dialer.png/.xml`, ActivityTaskManager; fiziksel remainder sürüyor |
| KSI-13 | Seçenek sayfası | "Acil kişi yap" | K: dokun | — | Birincil kaydı → SnackBar | — | contacts_page.dart:452-467 | contact_service tests | U | Kısmen | H | H | H | H | KISMEN KANITLI | |
| KSI-14 | Seçenek sayfası | "Kaldır" → onay "İptal"/"Sil" | K: dokun | — | Onay → sil; birincilse birincil TEMİZLENİR (yerine başka kişi seçilmez) | Silme hatası → "kaldırılamadı" | contacts_page.dart:484-557; contacts_provider.dart:117-130 | contacts_page_test; contact_service_* tests | S; U | Kısmen | H | H | H | E | KISMEN KANITLI | Birincil silinince panik kişisiz kalır (PNK-07) |
| KSI-15 | Kişiler | Sürükle-sırala (onReorder) | K: sürükle | ≥2 kişi | Sıra kalıcı yazılır (birincili değiştirmez) | — | contacts_page.dart:172-192; contacts_provider.dart:169-175 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | Bkz. HATA-12 (bayat liste geri yazılabilir) |
| KSI-16 | Kişiler | Limit (5) | S: render | 5 kişi | "Maksimum" metni; ekleme reddedilir | — | contacts_page.dart:196-203; contacts_provider.dart:40-41 | contacts_provider_add_validation_test | U | Kısmen | H | H | H | E | KISMEN KANITLI | AppBar "+" yine açılır, sonda reddeder |
| KSI-17 | Kişiler | Aktif oturumdaki kişiyi silme | K: sil | Check-In/SW ARMED | Native hedef değişmez → silinen numara aranır | — | EmergencySessionCoordinator.kt:475 (değişmez hedef) | EmergencySessionCoordinatorTest ("immutable target") | K | Kısmen | E | E | H | H | KISMEN KANITLI | Kullanıcıya söylenmiyor |
| MAP-01 | Harita | Sekme ilk aktif | S: isActive | — | Rıza → izin → son bilinen konum → güncel konum → kamerayı taşı | — | map_page.dart:66-144 | map_freshness_widget_test | W | Evet (konum mock) | E | E | H | E | KISMEN KANITLI | Gerçek GPS yok |
| MAP-02 | Harita | Konum rızası yok | S: kapı | typeLocation yok (varsayılan) | SnackBar "ilgili onay gereklidir"; izin reddi durumu | — | location_consent_gate.dart:24-33; map_page.dart:212-222 | map_consent_gate_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| MAP-03 | Harita | Konum izni reddi / kalıcı ret / servis kapalı | S: izin | — | Hata diyaloğu (izin ver / Ayarlar / konum ayarları); yedek konum etiketi | — | map_page.dart:224-340; permission_helper.dart:25-73 | permission_denied_test; gps_disabled_test; location_service_test; E4-FINAL9-MAP03 | U; D | Kısmen; disclosure reddi izinleri false bıraktı ve güvenli `Konum alınamadı` gösterdi; gerçek sistem konum servisi kapalıyken production `Konum Servisi Kapalı` diyaloğu açıldı | E | E | H | E | KISMEN KANITLI | APK `6fe2b8dc…`; `stage4-final9-map-denied-result`, `stage4-final9-map-service-off.png/.xml`; fiziksel/görsel remainder sürüyor |
| MAP-04 | Harita hata diyaloğu | "Vazgeç" / eylem butonu | K: dokun | — | Kapat / izin tekrar / ayarlar / tekrar dene | — | map_page.dart:314,332 | E4-FINAL9-MAP04 | D | Kısmen; Reddet diyaloğu kapattı ve fallback'i korudu; Ayarlara Git gerçek LOCATION_SOURCE_SETTINGS ekranını açtı | E | E | H | H | KISMEN KANITLI | APK `6fe2b8dc…`; `stage4-final9-map-service-off-declined.xml`, `stage4-final9-map04-location-settings.png`, ActivityTaskManager |
| MAP-05 | Harita | "Konumum" FAB | K: dokun | — | Güncel konum → taşı → "güncellendi" SnackBar | Başarısız → yedek + hata diyaloğu | map_page.dart:154-210,785 | map_page_ui_test; location_service_test; E4-FINAL8-MAP05 | S; U; D | Evet; final APK gerçek koordinatı aldı; FAB tüm preflight dahil zaman sınırında tamamlandı, loading overlay kalmadı | E | E | H | E | KANITLI | APK `913e4e72…`; `stage4-final8-map-initial.png/.xml`, `stage4-final8-map-fab.png/.xml` |
| MAP-06 | Harita | OSM atfı | K: dokun | — | OSM telif sayfası (dış tarayıcı) | Açılamazsa ? | map_page.dart:381,873-882 | map_osm_cache_contract_test; E4-FINAL8-MAP06 | S; D | Evet; gerçek VIEW intent WebViewBrowserActivity'de `https://www.openstreetmap.org/copyright` açtı | E | H | H | H | KANITLI | APK `913e4e72…`; `stage4-final8-map06-osm-browser.png`; ActivityTaskManager intent/top activity |
| MAP-07 | Harita | Karo yükleme | S: ağ | — | OSM karoları önbellekli istemciyle | Ağ yok/HTTP hata → karo yok, çökme yok | osm_tile_cache_client.dart | osm_tile_cache_client_test; tile_http_status_handling_test; tile_request_volume_test; E4-FINAL9-MAP07 | U; D | Kısmen; production harita gerçek OSM karolarını indirip app-support cache'e PNG+metadata olarak yazdı | E | E | H | E | KISMEN KANITLI | APK `6fe2b8dc…`; `stage4-final9-map07-online.png/.xml`; cache dosyaları 22:56 timestamp; fiziksel/görsel remainder sürüyor |
| MAP-08 | Harita | Tazelik uyarısı | S: yedek/eski konum | — | "Son bilinen konum" uyarısı; güncel gelince kalkar | — | map_page.dart:800-850 | map_freshness_widget_test | W | Evet | H | H | H | E | KANITLI | |
| GCM-01 | Güvenlik geçmişi | Açılış | S: yükle | — | Yükleniyor → birleşik liste (etkinlik + notlar + native sonuçlar) veya boş durum | Bozuk satır atlanır | safety_timeline_screen.dart:70-116,488-535 | safety_timeline_unified_test; high_volume_timeline_test | S; W* | Hayır | H | H | H | E | DOĞRULANMADI | Gerçek ekran pump edilmiyor |
| GCM-02 | Güvenlik geçmişi | "Yeni not" FAB | K: dokun | — | Not alt sayfası (hedef/plan/not) | — | safety_timeline_screen.dart:323-420,474 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| GCM-03 | Not alt sayfası | "Kaydet" | K: dokun | ≥1 alan dolu | Kayıt + etkinlik + SnackBar + yenile | Hepsi boş → sessizce hiçbir şey | safety_timeline_screen.dart:118-179,401 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| GCM-04 | Kayıt menüsü | "Paylaş" | K: menü seç | Not kaydı | Sistem paylaşım sayfası (metin) + SnackBar | Paylaşım hatası yakalanmıyor | safety_timeline_screen.dart:181-222,634-640 | — | — | Hayır | E | H | H | H | DIŞ SİSTEM GEREKİYOR | |
| GCM-05 | Kayıt menüsü | "Sil" → onay "İptal"/"Sil" | K: seç | — | Adıyla onay → kalıcı sil → yenile | — | safety_timeline_screen.dart:231-321,264,271 | timeline_delete_confirmation_test; timeline_delete_semantics_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| GCM-06 | Güvenlik geçmişi | Kaydırma konumu geri yükleme | S: süreç ölümü | — | Konum geri gelir | — | scroll_restoration.dart | scroll_restoration_test | W* | Kısmen | E | H | H | H | KISMEN KANITLI | |
| PIL-01 | Pil sihirbazı | "Optimizasyonu kapat" | K: dokun | Muaf değil | Prominent disclosure → sistem REQUEST_IGNORE_BATTERY_OPTIMIZATIONS → resume'da durum yeniden | Ret/iptal → durum aynı | battery_optimization_wizard.dart:110-121,245-248; permission_helper.dart:79-97 | battery_wizard_onboarding_test | S | Hayır | E | E | H | E | DOĞRULANMADI | Play kısıtlı izin beyanı (A-007) |
| PIL-02 | Pil sihirbazı | "Üretici rehberi" | K: dokun | — | OemBackgroundGuideScreen push | — | battery_optimization_wizard.dart:275-282 | oem_background_guide_source_test | S | Hayır | H | H | H | H | DOĞRULANMADI | |
| PIL-03 | Pil sihirbazı | "Pil ayarları" | K: dokun | — | Genel pil optimizasyonu listesi | Hata → debugPrint | battery_optimization_wizard.dart:123-129,307-310 | E4-FINAL9-PIL03 | D | Kısmen; production düğme Android App battery usage listesini açtı ve KoruBeni listede görüldü | E | E | H | H | KISMEN KANITLI | APK `6fe2b8dc…`; `stage4-final9-pil03-battery-settings.png/.xml`; fiziksel remainder sürüyor |
| PIL-04 | Pil sihirbazı | "Atla" | K: dokun | — | Ret sayacı++: <3 → 7 gün ertele; 3 → bir daha otomatik gösterme; pop | — | battery_optimization_wizard.dart:52-66,330-334 | battery_wizard_onboarding_test | S | Hayır | H | H | H | H | DOĞRULANMADI | |
| PIL-05 | Pil sihirbazı | "Tamam" | K: dokun | — | "görüldü" → pop | — | battery_optimization_wizard.dart:47-50,348-352 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| PIL-06 | Pil sihirbazı | Resume'da durum | S: resume | — | Muafiyet durumu yeniden okunur; muafsa kapat butonu gizlenir | Hata yutulur | battery_optimization_wizard.dart:91-108 | E4-FINAL9-PIL06 | D | Kısmen; gerçek deviceidle whitelist değişiminden Settings dönüşünde production ekran `Harika!` / `Tamamlandı` durumuna geçti | E | E | H | E | KISMEN KANITLI | APK `6fe2b8dc…`; `stage4-final9-pil06-resume.png/.xml`; test sonrası whitelist kaldırıldı; fiziksel/görsel remainder sürüyor |
| OEM-01 | OEM rehberi | Açılış / üretici tespiti | S: getDeviceManufacturer | — | Xiaomi/Huawei-Honor/Samsung/Oppo-Realme-OnePlus/Vivo/genel adımlar | Kanal hatası → genel | oem_background_guide_service.dart:93-160; oem_background_guide_screen.dart:45-54 | oem_background_guide_service_test; turkish_casing_test | U | Kısmen | E | E | H | E | KISMEN KANITLI | |
| OEM-02 | OEM rehberi | "Aç" (adım) | K: dokun | Adımın hedefi var | Üretici bileşeni / sistem ekranı açılır | Yok → "bu cihazda yok" işareti | oem_background_guide_screen.dart:56-67,254 | oem_background_guide_service_test | U | Kısmen | E | E | H | H | DIŞ SİSTEM GEREKİYOR | Gerçek OEM ekranları yalnız o markalarda |
| OEM-03 | OEM rehberi | "Yaptım" (adım) | K: dokun | — | Kalıcı tamamlandı | — | oem_background_guide_screen.dart:69-76,264 | oem_background_guide_service_test | U | Kısmen | H | H | H | E | KISMEN KANITLI | |
| OEM-04 | OEM rehberi | "Bitir" | K: dokun | — | Kalıcı kayıt → pop | — | oem_background_guide_screen.dart:78-85,297 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| BLK-01 | Bildirim kategorileri | Açılış / aşağı çek yenile (onRefresh) | K: çek | — | İzin + kanal önemi → teslim/ susturulmuş/ güvenlik susturuldu uyarısı | — | notification_categories_screen.dart:89; notification_preferences_service.dart | notification_categories_test (12); E4-FINAL9-BLK01 | W; D | Kısmen; gerçek Android kanalları production ekranda `Gösterilecek` ve dumpsys'te importance 4/3/2 olarak görüldü | E | E | H | E | KISMEN KANITLI | APK `6fe2b8dc…`; `stage4-final9-notification-categories.png/.xml`, dumpsys notification; fiziksel/görsel remainder sürüyor |
| BLK-02 | Bildirim kategorileri | Kategori satırı | K: dokun | — | Kanal ayar ekranı (sistem) | O öncesi → uygulama bildirim ayarları | notification_categories_screen.dart:192; MainActivity.kt:295-320 | notification_categories_test; notification_settings_row_test; E4-FINAL9-BLK02 | W; S; D | Kısmen; Acil durum uyarıları satırı gerçek Android `Acil Bildirimler` kanal SubSettings ekranını açtı | E | E | H | H | KISMEN KANITLI | APK `6fe2b8dc…`; `stage4-final9-blk02-channel-settings.png/.xml`; fiziksel remainder sürüyor |
| AYR-01 | Ayarlar | Profil kartı | K: dokun | — | ProfilePage push → dönüşte ad yenilenir | — | settings_page.dart:526-546 | user_name_display_test | S | Hayır | H | H | H | E | DOĞRULANMADI | SettingsPage hiç pump edilmiyor |
| AYR-02 | Ayarlar | Abonelik kutucuğu | K: dokun | isPro (ticari) | Pro → SubscriptionManagement; değil → Paywall; dönüşte refresh | — | settings_page.dart:424-444 | premium_gating_contract_test | S | Hayır | H | H | E | E | DOĞRULANMADI | |
| AYR-03 | Ayarlar | Bildirimler | K: dokun | — | NotificationCategoriesScreen | — | settings_page.dart:148-153 | notification_settings_row_test | S | Hayır | H | H | H | H | DOĞRULANMADI | |
| AYR-04 | Ayarlar | PIN değiştir | K: dokun | — | PIN değiştirme alt sayfası (PCH-*) | — | settings_page.dart:161,728-730 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| AYR-05 | Ayarlar | Pil sihirbazı | K: dokun | — | Sihirbaz push | — | settings_page.dart:176-183 | oem_background_guide_source_test | S | Hayır | H | H | H | H | DOĞRULANMADI | |
| AYR-06 | Ayarlar | Üretici rehberi | K: dokun | — | Rehber push | — | settings_page.dart:190-197 | oem_background_guide_source_test | S | Hayır | H | H | H | H | DOĞRULANMADI | |
| AYR-07 | Ayarlar | "Ses" anahtarı (SettingsSwitchTile tap + Switch) | K: dokun | — | Pref kaydı | Kapalıyken sahte çağrı zili VE siren sesi çalmaz | settings_page.dart:207-214; settings_switch_tile.dart:77,85; settings_provider.dart:52-57 | touch_target_minimum_size_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| AYR-08 | Ayarlar | "Ses tuşu tetikleyici" anahtarı | K: dokun | Android | Pro kapısı (AÇ ve KAPA için) → pref + native etkinleştir + "yalnız ön planda" SnackBar | Pro değil → paywall/SnackBar | settings_page.dart:216-243 | volume_trigger_copy_test; settings_page_shake_paywall_test | S | Hayır | E | E | E | E | DOĞRULANMADI | SES-03 |
| AYR-09 | Ayarlar | Yasal | K: dokun | — | LegalSettingsScreen | — | settings_page.dart:257-263 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| AYR-10 | Ayarlar | Hakkında | K: dokun | — | Detay sayfası + sürüm/derleme | — | settings_page.dart:285; settings_detail_page.dart:153-170 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| AYR-11 | Ayarlar | Gizlilik politikası (uygulama içi) | K: dokun | — | Detay sayfası + "Verilerimi dışa aktar" butonu | — | settings_page.dart:298; settings_detail_page.dart:262-266 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| AYR-12 | Ayarlar | Gizlilik politikası (web) | K: dokun | — | Dış tarayıcı | Açılamazsa SnackBar | settings_page.dart:311-330 | E4-FINAL9-AYR12 | D | Evet; production tap gerçek ACTION_VIEW ile gizlilik URL'sini WebViewBrowserActivity'de açtı | E | H | H | H | KANITLI | APK `6fe2b8dc…`; `stage4-final9-ayr12-web.png`, ActivityTaskManager |
| AYR-13 | Ayarlar | Yardım | K: dokun | — | Detay sayfası | — | settings_page.dart:332 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| AYR-14 | Ayarlar | Uygulamayı paylaş | K: dokun | — | Sistem paylaşım sayfası | Hata → SnackBar | settings_page.dart:65-72,345 | E4-FINAL9-AYR14 | D | Evet; gerçek Android ChooserActivity açıldı ve KoruBeni tanıtım metni/Play URL'si Sharesheet'te görüldü | E | H | H | H | KANITLI | APK `6fe2b8dc…`; `stage4-final9-ayr14-share.png/.xml`, ActivityTaskManager |
| AYR-15 | Ayarlar | Uygulamayı puanla | K: dokun | — | Play mağaza sayfası (harici) | Açılamazsa SnackBar | settings_page.dart:74-88,353 | — | — | Hayır | E | H | E | H | DIŞ SİSTEM GEREKİYOR | Uygulama Play'de yayında değil |
| AYR-16 | Ayarlar | "Verilerimi sil / Çıkış" | K: dokun | — | Sıfırlama diyaloğu (SIF-01) | — | settings_page.dart:362-365,732-734 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| AYR-17 | Detay sayfası | Geri ikonu | K: dokun | — | pop | — | settings_detail_page.dart:179 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| AYR-18 | Detay sayfası (gizlilik) | "Verilerimi dışa aktar" | K: dokun | — | EXP-02 ile aynı mantık (ikinci kopya, farklı dosya adı) | — | settings_detail_page.dart:275-353 | sensitive_temp_file_service_test | S | Hayır | E | H | H | H | DOĞRULANMADI | |
| PRF-01 | Profil | "Kişisel bilgiler" | K: dokun | — | EditProfileScreen → kaydedilince ad yenilenir | — | profile_page.dart:185-208 | user_name_display_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| PRF-02 | Profil | "PIN güvenliği" | K: dokun | — | PIN değiştirme sayfası | — | profile_page.dart:209-210 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| PRF-03 | Profil | "Bildirimler" | K: dokun | — | Statik detay sayfası (Ayarlar'daki kanal ekranından FARKLI) | — | profile_page.dart:211-220 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | İki farklı "Bildirimler" yüzeyi |
| PRF-04 | Profil | "Çıkış/Verileri sil" | K: dokun | — | Sıfırlama diyaloğu (başlık farklı) | — | profile_page.dart:122-128 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| PRF-05 | Profil düzenle | Ad alanı + "Kaydet" | K: yaz/dokun | — | 2-60 karakter; kaydet → pop(true) + SnackBar | Boş/<2 → SnackBar; profil rızası kontrol EDİLMİYOR | edit_profile_screen.dart:38-86,133 | edit_profile_screen_test; profile_email_removal_test | S; U | Hayır | H | H | H | E | DOĞRULANMADI | |
| PCH-01 | PIN değiştir | "Kaydet" — eski PIN yanlış | K: dokun | — | "Mevcut PIN yanlış" SnackBar | Kilit sayacına İŞLENMİYOR | pin_settings_helper.dart:123-158 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | GÜVENLİK: kilitsiz PIN kahini |
| PCH-02 | PIN değiştir | "Kaydet" — PIN yok / okunamadı | K: dokun | — | Uyarı SnackBar'ları | — | pin_settings_helper.dart:131-149 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| PCH-03 | PIN değiştir | "Kaydet" — yeni PIN ≠4 / zayıf / eskiyle aynı | K: dokun | Eski doğru | İlgili SnackBar | — | pin_settings_helper.dart:159-188 | pin_change_validation_test | U | Kısmen (yalnız doğrulayıcı) | H | H | H | H | KISMEN KANITLI | |
| PCH-04 | PIN değiştir | "Kaydet" — başarılı | K: dokun | — | Hash yaz → etkinlik → kapat → "güncellendi" | Yazma hatası → "kaydedilemedi" (eski PIN geçerli) | pin_settings_helper.dart:189-218 | pin_verification_service_test | U | Kısmen | H | H | H | H | KISMEN KANITLI | |
| SIF-01 | Sıfırlama diyaloğu | "İptal" | K: dokun | — | Kapanır | — | app_reset_helper.dart:70 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| SIF-02 | Sıfırlama diyaloğu | "Sil" | K: dokun | — | PIN kapısı (kilit sayaçlı) → native oturum silme → yerel silme (PIN en son) → pushAndRemoveUntil(Splash) | Native CLAIMED → TOO_LATE → "veriler silinmedi"; PIN reddi → iptal | app_reset_helper.dart:88-104; app_reset_service.dart; sensitive_action_pin_gate.dart | app_reset_native_prefs_test; contact_service_app_reset_cache_test; sensitive_action_pin_gate_test | U; W | Kısmen | E | H | H | E | KISMEN KANITLI | Aktif Check-In varken ENGEL YOK (unuttum yolunun aksine); HATA-12 |
| YSL-01 | Yasal ayarlar | Geri | K: dokun | — | pop | — | legal_settings_screen.dart:41 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| YSL-02 | Yasal ayarlar | Kullanım Şartları | K: dokun | — | ToS (salt okunur) | — | legal_settings_screen.dart:67-73 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| YSL-03 | Yasal ayarlar | KVKK aydınlatma | K: dokun | — | KVKK (salt okunur) | — | legal_settings_screen.dart:81-87 | release_readiness_policy_test | S | Hayır | H | H | H | E | DOĞRULANMADI | |
| YSL-04 | Yasal ayarlar | Gizlilik politikası (web) | K: dokun | — | Dış tarayıcı | Açılamazsa SnackBar | legal_settings_screen.dart:95-120 | phase5 live-legal-url evidence (07-18); E4-FINAL9-YSL04 | D | Evet; production Yasal ekran tap'i gerçek ACTION_VIEW ile gizlilik URL'sini açtı | E | H | H | H | KANITLI | APK `6fe2b8dc…`; `stage4-final9-ysl04-web.png`, ActivityTaskManager |
| YSL-05 | Yasal ayarlar | Rıza yönetimi | K: dokun | — | ConsentManagementScreen (PIN'siz) | — | legal_settings_screen.dart:124-130 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | KLT-07: kilit ekranından da erişilebilir |
| YSL-06 | Rıza yönetimi | Anahtar / satır dokunuşu (×4 rıza) | K: dokun | — | Ver → kayıt; geri çek → onay diyaloğu → kayıt + pref | Kalıcı yazma hatası → SnackBar, durum yeniden okunur | consent_management_screen.dart:69-104,360,365 | touch_target_minimum_size_test; D 2026-08-14 | S; D | Hayır | H | H | H | E | DOĞRULANMADI | Geri çekmenin mevcut kişilere/panik akışına etkisi yok (yalnız yeni eylemler kapıda) |
| YSL-07 | Geri çekme onayı | "İptal" / "Geri çek" | K: dokun | — | false/true | — | consent_management_screen.dart:157,164 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| YSL-08 | Rıza yönetimi | Geri | K: dokun | — | pop | — | consent_management_screen.dart:200 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| YSL-09 | ToS / KVKK salt okunur | Geri | K: dokun | isReadOnly | pop | — | terms_of_service_screen.dart:98; kvkk_disclosure_screen.dart:77 | — | — | Hayır | H | H | H | E | DOĞRULANMADI | |
| YSL-10 | ToS / KVKK | Onay kutusu + "Kabul" (isReadOnly=false modu) | K: dokun | — | — | Tüm çağıranlar isReadOnly:true geçiyor | terms_of_service_screen.dart:152-250; kvkk_disclosure_screen.dart:160-236 | — | — | Hayır | H | H | H | H | ULAŞILAMAZ / ÖLÜ | 6 callback (190/215/245, 176/201/231) |
| YSL-11 | Yasal ayarlar | Veri dışa aktarma | K: dokun | — | DataExportScreen | — | legal_settings_screen.dart:138-141 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| YSL-12 | Yasal ayarlar | Veri silme | K: dokun | — | DataDeletionScreen | — | legal_settings_screen.dart:157-160 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| YSL-13 | Yasal ayarlar | KVKK başvurusu (mailto) | K: dokun | E-posta uygulaması | E-posta taslağı | Uygulama yok → SnackBar | legal_settings_screen.dart:177-200 | E4-FINAL9-YSL13 | D | Evet; resolver'sız emulator gerçek mailto VIEW denedi (`result code=-91`) ve production fallback SnackBar gösterdi | E | H | H | H | KANITLI | APK `6fe2b8dc…`; `stage4-final9-ysl13-mailto.png/.xml`, ActivityTaskManager |
| EXP-01 | Veri dışa aktarma | Geri | K: dokun | — | pop | — | data_export_screen.dart:99 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| EXP-02 | Veri dışa aktarma | "Dışa aktar" | K: dokun | — | PIN kapısı (kilit sayaçlı; PIN yoksa serbest) → JSON (kişiler, geçmiş, rızalar, native tanı) → geçici dosya → paylaşım → dosya silinir | PIN okunamaz → ret; hata → SnackBar | data_export_screen.dart:28-89,216; user_data_export_service.dart | sensitive_action_pin_gate_test; profile_email_removal_test; sensitive_temp_file_service_test; legal_data_export_claims_test | W; U; S | Kısmen | E | H | H | H | KISMEN KANITLI | Paylaşım hedefi DIŞ |
| DEL-01 | Veri silme | Geri | K: dokun | — | pop | — | data_deletion_screen.dart:135 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | |
| DEL-02 | Veri silme | "Verilerimi sil" | K: dokun | — | Onay diyaloğu (abonelik ayrı notu) | — | data_deletion_screen.dart:25-116,249 | subscription_deletion_copy_test | W | Kısmen (not bileşeni gerçek) | H | H | H | E | KISMEN KANITLI | |
| DEL-03 | Silme onayı | "İptal" / "Sil" | K: dokun | — | Sil → İKİNCİ onay diyaloğu (SIF) → PIN → silme | — | data_deletion_screen.dart:83,90,110-115 | — | — | Hayır | H | H | H | H | DOĞRULANMADI | Çift onay |
| DEL-04 | Abonelik notu | "Play aboneliklerini aç" | K: dokun | — | Play abonelikleri URL'i | — | subscription_deletion_notice.dart:101 | subscription_deletion_copy_test | W | Kısmen (tap yok) | E | H | E | H | DIŞ SİSTEM GEREKİYOR | |
| ABN-01 | Paywall | Açılış | S: push | — | Teklifler yüklenir; yükleniyor kartı | Paket yok → "planlar kullanılamıyor" + Tekrar dene | paywall_screen.dart:33-40,108-143 | paywall_render_test | W | Evet (sahte provider) | H | H | E | E | KISMEN KANITLI | Gerçek Offerings hiç yüklenmedi |
| ABN-02 | Paywall | "Tekrar dene" | K: dokun | Planlar yok | refreshOfferings | — | paywall_screen.dart:382 | — | — | Hayır | H | H | E | H | DIŞ SİSTEM GEREKİYOR | |
| ABN-03 | Paywall | Yıllık plan (kart + buton) | K: dokun | — | Satın alma → verifiedPro → "başarılı" + pop | İptal → SESSİZ; çevrimdışı/hata → SnackBar; ödendi ama yetki yok → "subscription_error_entitlement" | paywall_screen.dart:43-61,418,509; subscription_provider.dart:151-180 | paywall_render_test; revenuecat_subscription_contract_test | W; S | Kısmen | E | E | E | E | DIŞ SİSTEM GEREKİYOR | A-003: hiç gerçek işlem yok |
| ABN-04 | Paywall | Aylık plan (kart + buton) | K: dokun | — | ABN-03 ile aynı | Aynı | paywall_screen.dart:418,509 | paywall_render_test | W | Kısmen | E | E | E | E | DIŞ SİSTEM GEREKİYOR | |
| ABN-05 | Paywall | "Satın alımları geri yükle" | K: dokun | — | Pro ise "geri yüklendi" + pop; değilse "satın alım yok" | Hata → SnackBar | paywall_screen.dart:63-80,541 | paywall_render_test | W | Kısmen | E | E | E | H | DIŞ SİSTEM GEREKİYOR | |
| ABN-06 | Paywall | Gizlilik / Abonelik şartları / Aydınlatma linkleri | K: dokun | — | Dış tarayıcı | — | paywall_screen.dart:586,590,594 | paywall_render_test (görünürlük); E4-FINAL9-ABN06 | W; D | Evet; üç production link ayrı ayrı gerçek ACTION_VIEW ile doğru URL'leri açtı | E | H | H | H | KANITLI | APK `6fe2b8dc…`; privacy, `kullanim_sartlari.html`, `aydinlatma.html` ActivityTaskManager kayıtları; `stage4-final9-abn06-aydinlatma.png` |
| ABN-07 | Abonelik yönetimi | Customer Center | K: dokun | Pro | RevenueCatUI Customer Center → refresh | Hata → Play abonelikleri URL'i + SnackBar | subscription_management_screen.dart:58-89,134 | — | — | Hayır | E | E | E | H | DIŞ SİSTEM GEREKİYOR | |
| ABN-08 | Abonelik yönetimi | "Yükselt" | K: dokun | — | Paywall push → refresh | — | subscription_management_screen.dart:147-153 | — | — | Hayır | H | H | E | H | DOĞRULANMADI | |
| ABN-09 | Abonelik yönetimi | "Geri yükle" | K: dokun | — | ABN-05 benzeri SnackBar | — | subscription_management_screen.dart:29-56,186 | — | — | Hayır | E | E | E | H | DIŞ SİSTEM GEREKİYOR | |
| ABN-10 | Abonelik yönetimi | Bitiş tarihi / durum | S: render | Pro | RC entitlement `expirationDate` | — | subscription_management_screen.dart:91-130 | — | — | Hayır | H | H | E | E | DIŞ SİSTEM GEREKİYOR | |
| ABN-11 | Yetki modeli | authorized / denied / unknown + sınırsız çevrimdışı çapa (acil özellikler) / sınırlı grace (diğer) | S: her kapı | — | Tek kural `SubscriptionGate.isAuthorized` | Mağaza yavaş → son bilinen durum | subscription_gate.dart:67-75; subscription_access_state.dart | subscription_access_state tests (13 dosya); offline_grace_expiry_test; offline_sos_entitlement_policy_test | U | Evet (mantık) | H | H | E | H | KISMEN KANITLI | `KoruBeni Pro` kimliğinin dashboard ile eşleşmesi DIŞ |
| ABN-12 | Yetki | Deneme / yükseltme / düşürme / duraklatma / iptal / iade | S: mağaza | — | — | — | revenue_cat_service.dart | revenue_cat_service_test; revenue_cat_evidence_persistence_test | U | Hayır | E | E | E | H | DIŞ SİSTEM GEREKİYOR | E1: hiçbiri gözlenmedi |
| ABN-13 | Paywall fayda listesi / mağaza metni | "Gelişmiş güvenlik otomasyonları" (Pro) | K: satın alınan faydayı kullanmak | Pro | Satılan bir özellik | `PremiumFeature.advancedAutomation` kodda HİÇBİR yerde kullanılmıyor; karşılığı olan davranış yok | feature_access_matrix.dart:114-119,124-130; store/play_store_listing_tr.md:49-50 | paywall_compliance_test | S | Hayır | H | H | E | H | ULAŞILAMAZ / ÖLÜ | Ücretli abonelikte var olmayan fayda — mağaza politikası riski |
| PRM-01 | İzin açıklama diyaloğu (prominent disclosure) | "Reddet" | K: dokun | Konum / arama / bildirim / pil akışı | false → OS izni istenmez, akış durur | — | permission_helper.dart:253-335 | E4-FINAL4-PRM01 | D | Evet; gerçek Android izinleri false kaldı | E | H | H | E | KANITLI | Final APK `b8f004d1…` |
| PRM-02 | İzin açıklama diyaloğu | "Kabul" | K: dokun | — | true → OS çalışma zamanı izin diyaloğu | OS reddi → PRM-03 veya sessiz false | permission_helper.dart:319 | — | — | Hayır | E | E | H | E | DOĞRULANMADI | |
| PRM-03 | İzin reddedildi diyaloğu | "Reddet" | K: dokun | Kalıcı ret / servis kapalı | Kapanır, false | — | permission_helper.dart:357-430 | E4-FINAL4-PRM03 | D | Evet; USER_FIXED gerçek OS durumu | E | H | H | H | KANITLI | Final APK `b8f004d1…` |
| PRM-04 | İzin reddedildi diyaloğu | "Ayarlara Git" | K: dokun | — | Uygulama ayarları (sistem) | — | permission_helper.dart:420 | E4-FINAL4-PRM04 | D | Evet; APPLICATION_DETAILS_SETTINGS/SpaActivity | E | E | H | H | KANITLI | `stage4-final4-location-permission-settings.png` |
| HATA-01 | Çapraz | CALL_PHONE reddi | S: izin yok | Panik/Check-In | Arm `callPermissionDenied` → panikte ön plan geri sayımı + dialer; check-in'de sevkte dialer | Hazırlık kartı "arama izni" eksik | panic_arm_policy.dart:16-21; check_in_service.dart:577-593 | panic_arm_policy_test; countdown_dispose_lifecycle_test | U; W | Kısmen | E | E | H | E | KISMEN KANITLI | |
| HATA-02 | Çapraz | Bildirim izni reddi | S: izin yok | — | Check-In/SW başlatılamaz; panik ön plan geri sayımı; fallback bildirimi gönderilemez | — | check_in_screen.dart:194-212; EmergencyNotificationHelper.kt:144-163 | notification_categories_test; EmergencySessionCoordinatorTest | W; K | Kısmen | E | E | H | E | KISMEN KANITLI | |
| HATA-03 | Çapraz | Secure storage/Keystore okunamıyor (başlangıç) | S: bootstrap `pin` adımı | — | — | Statik hata ekranı; panik/tile/widget/ses tuşu DAHİL hiçbir şey çalışmaz | app_bootstrap_service.dart:69-74; main.dart:111-121 | app_bootstrap_service_test | U | Kısmen | E | E | H | E | KISMEN KANITLI | Kasıtlı fail-closed; kullanıcıya yol yok |
| HATA-04 | Çapraz | Secure storage okunamıyor (çalışırken) | S: verify/loadState | — | Kilit/geri sayım/kapılar "okunamadı" der, fail-closed | Arka plan kilidi fail-OPEN (YDK-03) | pin_verification_service.dart; sensitive_action_pin_gate.dart:38-49 | pin_verification_service_test; sensitive_action_pin_gate_test | U; W | Kısmen | E | H | H | H | KISMEN KANITLI | |
| HATA-05 | Çapraz | SharedPreferences yazma reddi | S: commit false | Rıza/kişi | Rıza ekranı tekrar dene; diğer yerlerde çoğunlukla sessiz | — | unified_consent_screen.dart:128-141 | unified_consent_retry_test; atomic storage tests yok | W | Kısmen | H | H | H | H | KISMEN KANITLI | |
| HATA-06 | Çapraz | Bozuk native oturum kaydı | S: read Corrupted | — | Arm Unknown; check-in degrade bandı; reconcile PREPARING→CORRUPTED | — | EmergencySessionCoordinator.kt:58-62,599-610; check_in_service.dart:357-365 | DeviceProtectedEmergencySessionStoreTest; check_in_service_behavior_matrix_test | K; U | Kısmen | E | H | H | E | KISMEN KANITLI | |
| HATA-07 | Çapraz | Platform kanalı timeout | S: invoke gecikir | — | Tipli `timeout` → Unknown; hazırlık "timeout" | — | emergency_platform_channel.dart:47-50 | emergency_platform_typed_contract_test; emergency_readiness_behavior_test | U | Evet | H | H | H | H | KANITLI | |
| HATA-08 | Çapraz | Ağ yok | S: uçak modu | — | Panik akışı ağsız; harita karosu yok; RC doğrulanamaz → çapa/grace | — | connectivity_service.dart; subscription_access_state.dart | connectivity_service_test; offline_sos_entitlement_policy_test; D 2026-08-14 perf (ağ) | U; D | Kısmen | E | E | E | E | KISMEN KANITLI | |
| HATA-09 | Çapraz | Satın alma iptal / hata / çevrimdışı | S: mağaza | — | İptal sessiz; hata/çevrimdışı SnackBar | — | subscription_provider.dart:165-179 | subscription_provider_access_test | U | Kısmen | E | E | E | H | DIŞ SİSTEM GEREKİYOR | |
| HATA-10 | Çapraz | Konum yok / GPS kapalı | S: konum | — | Harita yedek konum + diyalog | — | location_service.dart; map_page.dart | gps_disabled_test; permission_denied_test; location_service_test | U | Kısmen | E | E | H | E | KISMEN KANITLI | Panik akışı konum kullanmıyor |
| HATA-11 | Çapraz | SIM yok / uçak modu arama | S: sevk | — | Hazırlık `hasSim`/`isAirplaneModeOn` okur; Telecom sonucu bilinmez | — | EmergencyPlatformHandler.kt:220-262 | EmergencyPlatformReadinessTest | K | Kısmen | E | E | H | E | DOĞRULANMADI | Gerçek SIM/uçak davranışı yok |
| HATA-12 | Çapraz | Aynı süreçte veri silme sonrası provider durumu | S: SIF-02 / KLT-11 | Kişiler daha önce yüklenmişti | Yeni kurulum gibi temiz durum | Reset hatası → güvenli ret | providers.dart; app_reset_service.dart | app_reset_provider_state_test; E4-FINAL4-RESET-PROVIDER | U; D | Evet; gerçek reset, cold relaunch, temiz kişi adımı, yalnız yeniden picker+rıza ile ekleme | E | H | H | E | KANITLI | APK `b8f004d1…` |
| HATA-13 | Çapraz | Süreç öldürülmesi (OS) | S: düşük bellek | Aktif oturum | Native alarm sürer; açılışta uzlaştırma; taslaklar geri yüklenir | — | NTV-01/06; BOOT-17 | EmergencySessionCoordinatorTest; D 2026-08-14 | K; D | Kısmen | E | E | H | H | KISMEN KANITLI | |
| HATA-14 | Çapraz | Force-stop | S: kullanıcı/OEM | Aktif oturum | Alarmlar silinir, SESSİZ kaçırma; açılışta NTV-09 | OEM "temizle" davranışı ölçülmedi | NTV-09 | NTV-09 kanıtları | K; I; D | Kısmen | E | E | H | E | KISMEN KANITLI | Telefon protokolü Test C koşulmadı |
| HATA-15 | Çapraz | Uygulama güncellemesi | S: MY_PACKAGE_REPLACED + ilk açılış | Eski veri | Göç: DB v3 ekleme-only, PIN eski format, kişi göçü, tıbbi/e-posta temizliği, locale sıfırlama; native reconcile | — | data_migration_service.dart; local_database_service.dart; pin_verification_service.dart:61-105 | local_database_migration_test; data_migration_v2_test; pin_storage_migration_test; medical_data_cleanup_service_test | U | Kısmen | E | E | E | H | KISMEN KANITLI | Play sürümünden gerçek yükseltme yok |
| HATA-16 | Çapraz | Telefon yeniden başlatma | S: reboot | Aktif oturum | NTV-06 | — | NTV-06 | NTV-06 kanıtları | K; I | Kısmen | E | E | H | E | KISMEN KANITLI | |
| HATA-17 | Çapraz | Yedekleme/geri yükleme, yeni telefon | S: cihaz değişimi | — | allowBackup=false → tüm yerel veri kaybolur; PIN/kişi taşınmaz | Abonelik geri yükleme ile döner | AndroidManifest.xml:58-60 | — | — | Hayır | E | E | E | H | DOĞRULANMADI | |
| HATA-19 | Çapraz | Veri silme / PIN sıfırlama sonrası süreç ölümü | S: aynı oturumda silme → arka plan → OS süreci öldürür → geri dönüş | SIF-02 veya KLT-11 yapıldı | Temiz geri yükleme | Başarılı wipe AppRoot dışındaysa standalone navigation fallback'i | app_reset_helper.dart; app_unlock_screen.dart; app_root.dart | state_restoration_navigator_precondition_test; startup_pin_boundary_test; state_restoration_policy_test; E4-FINAL5-HATA19 | W; W*; D | Evet; gerçek SIFIRLA sonrası aynı süreçte consent/onboarding, HOME, `am kill`, cold dönüş; 5/5 + DraftOnb/5552223333 geri geldi, crash/assert yok | E | H | H | H | KANITLI | APK `e0618db2…`; `stage4-final5-reset-onboarding-draft-restored.png/.log` |
| HATA-18 | Çapraz | Kanal kurulumu native'de düştü | S: configureFlutterEngine | — | Acil kanal → GS-07; diğer kanallar → Dart çağrıları MissingPlugin → her özellik kendi fallback'i | — | MainActivity.kt:108-391 | countdown_bridge_missing_test | W | Kısmen | E | H | H | H | KISMEN KANITLI | |
| OLU-01 | LegalDisclaimerScreen | 11 callback (onay kutuları, butonlar, PopScope) | — | — | — | Hiçbir yerden oluşturulmuyor | legal_disclaimer_screen.dart:93-390 | — | — | Hayır | H | H | H | H | ULAŞILAMAZ / ÖLÜ | A-011 listesinde; hâlâ duruyor |
| OLU-02 | ConsentScreen (eski rıza ekranı) | 5 callback | — | — | — | Hiçbir yerden oluşturulmuyor | legal/consent_screen.dart:172-241 | edge_to_edge_bottom_inset_test | S | Hayır | H | H | H | H | ULAŞILAMAZ / ÖLÜ | |
| OLU-03 | NetworkErrorRetry / showNetworkErrorSnackBar | 2 callback | — | — | — | Kullanılmıyor | widgets/network_error_retry.dart:53,93 | — | — | Hayır | H | H | H | H | ULAŞILAMAZ / ÖLÜ | |
| OLU-04 | EmptyState | 1 callback | — | — | — | Kullanılmıyor | widgets/empty_state.dart:69 | — | — | Hayır | H | H | H | H | ULAŞILAMAZ / ÖLÜ | |
| OLU-05 | LoadingOverlay | — | — | — | — | Kullanılmıyor (ama testi var) | widgets/loading_overlay.dart | loading_overlay_semantics_test | W | Evet | H | H | H | H | ULAŞILAMAZ / ÖLÜ | Ölü kodu test eden test |
| OLU-06 | Ana Sayfa | HomeProvider bekleyen mesaj | — | — | — | `_pendingMessage` hiç atanmıyor | home_provider.dart:30,110-114; home_page.dart:162-167 | — | — | Hayır | H | H | H | H | ULAŞILAMAZ / ÖLÜ | |

## 4. Navigasyon ve state geçişleri

Uygulama tek kök route kullanıyor: `MaterialApp.home = AppRoot`. Başlangıç hedefleri (Rıza / Kilit / Onboarding / Ana kabuk) **route değil `AppRoot` state'i** olarak değişir (geri yüklenmez, her süreç ölümünde Splash baştan karar verir). Diğer tüm ekranlar bunun üstüne `push` edilir. Aşağıdaki "Geri" sütunu sistem Geri tuşunun davranışıdır.

| # | Nereden | Hangi eylemle | Koşul | Nereye | Geri dönüş davranışı | Envanter ID |
|---|---|---|---|---|---|---|
| N1 | AppRoot (başlangıç) | init | her soğuk açılış / süreç ölümü | Splash (state) | — | BOOT-11..17 |
| N2 | Splash | `_goTo` | rıza yok veya legal sürüm değişti | UnifiedConsent (state) | Geri → uygulamadan çıkış | BOOT-11/12 |
| N3 | Splash / Rıza `onAccepted` | `_continueStartup` | PIN kurulu (veya okunamıyor) | AppUnlock (state) | Geri engelli | BOOT-13 |
| N4 | Splash / Rıza / Kilit | `_continueStartup` | onboarding bitmemiş | Onboarding (state) | Geri → çıkış | BOOT-14 |
| N5 | Splash / Kilit / Onboarding `onCompleted` | `_goTo` | onboarding bitmiş | MainNavigation (state) | Geri → çıkış | BOOT-15, ONB-05 |
| N6 | MainNavigation | ilk kare | PIN yok | PinSetupScreen (tam ekran push) | Geri engelli; başarıda pop | PIN-01..08 |
| N7 | MainNavigation | ilk kare (PIN'den sonra) | bildirim izni sorulmamış | izin diyaloğu | — | NAV-06 |
| N8 | MainNavigation | alt çubuk (4 sekme) | — | IndexedStack sekme 0-3 (state, geri yüklenir) | Geri → çıkış | NAV-01..05 |
| N9 | MainNavigation | mount + her resume | park edilmiş derin link / bildirim hedefi | sekme veya push (Geçmiş/Check-In/Paywall) | push edilenler pop | DL-03..11 |
| N10 | HomePage | ilk kare | sihirbaz görülmedi | BatteryOptimizationWizard push | pop | HOME-26 |
| N11 | HomePage | kişi çipi / hazırlık çipi / onboarding adımı / hızlı eylem | — | ContactsPage push (sekmeden ayrı ikinci örnek) | pop → Home yenilenir | HOME-01,03,12,19 |
| N12 | HomePage | hızlı eylem | ücretsiz | FakeCall (sayfa→push) / SirenDialog / SafetyTimeline push | pop / diyalog | HOME-15,16,20 |
| N13 | HomePage | hızlı eylem | Pro yetkili | SafeWalkScreen / CheckInScreen push | pop (oturum sürer) | HOME-17,21 |
| N14 | Herhangi bir kapı | `SubscriptionGate.ensureAccess` ret | doğrulanmış ücretsiz | PaywallScreen push | pop → provider refresh | HOME-18,22, PNK-05 |
| N15 | HomePage | Test Modu | — | CountdownScreen(test) push | Geri engelli; 10 sn sonra otomatik pop(true) | HOME-14, GS-20/21 |
| N16 | PanicButton | 3 sn tut-bırak / TalkBack onay | yetkili + kişi var | CountdownScreen push (geçişsiz) | Geri engelli | PNK-02,12 |
| N17 | EmergencyTriggerHost | tile / widget / ses tuşu | yetkili | CountdownScreen **root navigator**'a (maskeli) — Splash/Rıza/Kilit'in ÜSTÜNE de olabilir | Geri engelli | HZ-07,10, SES-01 |
| N18 | CountdownScreen | süre doldu | istek gönderildi veya dialer | EmergencyCallScreen (`pushReplacement`) | Geri → pop (PopScope yok) | GS-15, SNC-09 |
| N19 | CountdownScreen | PIN iptal onaylı / arm reddi diyaloğu "Kapat" | — | pop | — | GS-09, GS-28 |
| N20 | CheckInService | süre sonu sevki | navigator var | EmergencyCallScreen (root push) | Geri → pop | CHK-12, SWK-11 |
| N21 | EmergencyCallScreen | Ana sayfa butonu | — | `popUntil(isFirst)` | — | SNC-06 |
| N22 | AppLifecycleHandler | resume | ≥120 sn arka plan, PIN var | AppUnlockScreen (root push) | Geri engelli; doğru PIN → pop | YDK-01 |
| N23 | NotificationService | sahte çağrı bildirimi dokunuşu | süreç canlı | FakeCallScreen (root push, PIN'siz) | pop → altındaki (kilit ekranı olabilir) | BLD-02 |
| N24 | CheckIn / SafeWalk / Panik SnackBar | "Kişi ekle" | kişi yok | ContactsPage push | pop | CHK-03, SWK-03, PNK-08 |
| N25 | SafeWalk AppBar geri | dokun | aktif | çıkış diyaloğu → (iptal) pop | sistem Geri uyarısız pop | SWK-07..10 |
| N26 | Settings | 8 gezinme kutucuğu | — | NotificationCategories / Wizard / OEM / Legal / Profile / Detail×3 / SubscriptionMgmt veya Paywall | pop | AYR-01..13 |
| N27 | BatteryWizard | "Üretici rehberi" | — | OemBackgroundGuide push | pop | PIL-02 |
| N28 | Profile | 3 satır | — | EditProfile / PIN sayfası / Detail(bildirimler) | pop(true) → yenile | PRF-01..03 |
| N29 | SubscriptionMgmt | "Yükselt" | — | Paywall push | pop → refresh | ABN-08 |
| N30 | LegalSettings | 5 satır | — | ToS / KVKK (salt okunur) / ConsentMgmt / DataExport / DataDeletion | pop | YSL-02..12 |
| N31 | PinSetup ve AppUnlock | bilgi ikonu | — | LegalSettings push (kilitliyken de) | pop | PIN-09, KLT-07 |
| N32 | AppUnlock "Unuttum" / Sıfırlama diyaloğu | onay + silme OK | — | `AppRoot.restartStartup` → mevcut `/` korunur, Splash kararı state olarak yeniden çalışır | Standalone yüzeyde eski navigation fallback'i | KLT-11, SIF-02, HATA-19 |
| N33 | Reset sonrası AppRoot Splash | `_goTo` → `advance` | N2-N5 ile aynı kararlar | Rıza / Kilit / Onboarding / MainNavigation (state) | Geri → çıkış; route restoration öncülü korunur | HATA-19 |

**Ulaşılamayan ekran/durumlar:** `LegalDisclaimerScreen` (OLU-01), `ConsentScreen` (OLU-02), ToS/KVKK kabul modu (YSL-10), `PinSetupScreen(requiredSetup:false)` — isteğe bağlı mod hiç oluşturulmuyor, `EmergencyCallScreen` "onaylandı"/12 sn otomatik kapanış (SNC-07), `emergencyMessage` kopyala butonları (GS-27, SNC-04), `UnifiedConsentScreen.onAccepted == null` ve `OnboardingScreen.onCompleted == null` geri dönüş dalları (Splash her zaman geri çağrı geçiriyor), bildirim payload hedefleri `timeline/check_in/subscription` (BLD-04), native olay türleri `checkInGraceStarted/checkInExpired/safetyClockChanged` (NTV-22), Pro faydası "Gelişmiş güvenlik otomasyonları" (ABN-13).

## 5. Görsel kullanılabilirlik envanteri (bu turda düzeltme/PASS yok)

Göstergeler: **G** = doğrulama gerekli ve bu ağaçta kanıt yok · **e(tarih)** = yalnız emülatör kaydı var, daha eski commit · **w** = gerçek ekranı pump eden widget testi var · **r** = yalnız replika/stub widget testi · **—** = bu ekranda o durum yok.

| Ekran | Küçük ekran | Büyük ekran/tablet | Maks font (200%) | Klavye açık | Uzun TR metin | Taşma/kırpma | Disabled | Error | Dialog | Loading | Empty | TalkBack/semantik |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Splash | G | G | G | — | G | G | — | G (bütünlük diyaloğu) | G | G | — | G |
| Başlangıç hata ekranı | G | G | G | — | G | G | — | G | — | — | — | G |
| UnifiedConsent | e(08-14) | G | e(08-14, 82 px taşma düzeltildi) | — | G | e(08-14) | w | w (SnackBar) | — | w | — | w + e(08-21) |
| Onboarding 1-4 | e(08-16) | G | w (safety copy) | — | G | G | — | — | — | — | — | e(08-21) |
| Onboarding kişi adımı | e(08-16) | G | w | w + e(08-13) | G | G | w | G | w (rıza diyaloğu) | G | — | w (a11y) |
| PinSetup | w (kısa ekran) | G | w | — | G | w | — | w | — | — | — | e(08-21) |
| AppUnlock | r (density) | G | G | G (unuttum diyaloğu) | G | r | G (kilitli) | G | G | G | — | e(08-21) |
| Ana Sayfa | e(08-16) | G | G | — | G | G | — | G | G | — | G (kişi yok) | e(08-21) |
| Hazırlık kartı | r (layout matrix) | G | r | — | G | r | — | w | — | — | — | w |
| Panik butonu (kilitli/açık) | G | G | G | — | G | G | G | G | G | — | — | w + e(08-21) |
| Geri sayım | w (compact dalı) | G | G | — | G | G | — | w | w (hata diyaloğu) | G | — | w |
| Acil sonuç ekranı | G | G | G | — | G | G | — | w | G (fail-safe) | — | — | w |
| Harita | e(08-16) | G | G | — | G | G | — | G | G | G | — | G |
| Kişiler (+ekleme/seçenek/seçici sayfaları) | e(08-16) | G | G | G | G | G | G | G | G | G | G | G |
| Ayarlar | e(08-16) | G | G | — | G | G | — | G | — | — | — | e(08-21) |
| Profil / Profil düzenle | G | G | G | G | G | G | — | G | — | — | — | G |
| PIN değiştir sayfası | G | G | G | G | G | G | — | G | — | — | — | G |
| Check-In (kurulum/aktif/ek süre) | G | G | G | — | G | G | — | G | G | — | — | G |
| Güvenli Yürüyüş | G | G | G | — | G | G | — | G | G | — | — | G |
| Sahte çağrı + özelleştir | G | G | G | G | G | G | — | G | G | — | — | G (kontrast 1.41:1 notu, 08-21) |
| Siren | G | G | G | — | G | G | — | G | — | — | — | G |
| Güvenlik geçmişi + not sayfası | G | G | G | G | G | G | — | G | G | G | G | G |
| Pil sihirbazı | e(08-16) | G | G | — | G | G | — | — | G | — | — | G |
| OEM rehberi | G | G | G | — | G | G | — | G (adım yok) | — | G | — | G |
| Bildirim kategorileri | G | G | G | — | G | G | — | w | — | G | — | w |
| Yasal ayarlar / Rıza yönetimi | e(08-14) | G | G | — | G | G | G | G | G | — | — | G |
| ToS / KVKK salt okunur | G | G | G | — | G (çok uzun metin) | G | — | — | — | — | — | G |
| Veri dışa aktarma / silme | G | G | G | — | G | G | G | G | G | G | — | G |
| Paywall | G | G | G | — | G | G | w | w | — | w | w (plan yok) | G |
| Abonelik yönetimi | G | G | G | — | G | G | G | G | — | G | — | G |
| Çevrimdışı bandı | e(08-16) | G | r | — | G | r | — | — | G | — | — | e(08-14) |

Notlar: (1) `layout_size_matrix_test` 6 görünüm × ölçek ızgarasını **gerçek ekranlarda değil** 5 test-yerel replikada (`_SettingsRow`, `_ChipStrip`, …) ölçüyor — davranış kanıtı sayılmadı. (2) Tüm cihaz kayıtları emülatör (`Medium_Phone_API_36.1`, `KoruBeni_API36_16k_ctrl`); FLAG_SECURE nedeniyle release build'de ekran görüntüsü alınamaz, görsel kontroller debug build'de yapılmış. (3) Tablet/katlanabilir hiçbir ekranda ölçülmedi. (4) Açık tema bilinçli olarak yok (tek karanlık tema).

## 6. Hata ve kesinti durumları — kullanıcıya etkisi (özet dizin)

Ayrıntı ana tablodaki `HATA-*` satırlarında ve ilgili ekran satırlarında. Kullanıcının ne gördüğüne göre gruplanmıştır:

| Durum | Kullanıcı ne yaşıyor | ID |
|---|---|---|
| Arama izni reddi | Panik yine geri sayar ama yalnız Dart zamanlayıcısıyla (Doze koruması yok, ekranda söylenmiyor); sonunda dialer açılır | HATA-01, GS-05 |
| Bildirim izni reddi | Check-In/Güvenli Yürüyüş başlamaz (SnackBar + ayarlar eylemi); panikte fallback bildirimi gönderilemez | HATA-02, CHK-02 |
| Exact alarm izni yok | Check-In/SW başlamaz (diyalog, ayarlar açılsa bile yeniden başlatmak gerekir); panik "ön plan" geri sayımı | CHK-04, GS-05, NTV-18 |
| Konum izni/servisi yok, rıza yok | Harita yedek konum + diyalog; rıza yoksa yalnız SnackBar | MAP-02/03, HATA-10 |
| MissingPlugin / kanal yok | Acil köprü: hazırlık kartı kırmızı, panik engellenir ve manuel arama önerilir; diğer kanallar: özellik sessizce degrade | GS-07, HATA-18, NTV-37 |
| Kanal timeout | Tipli "unknown": geri sayım belirsiz tokenla sürer; hazırlık "timeout" | HATA-07, GS-06 |
| Secure storage okunamıyor | Başlangıçta: tüm uygulama kilitli statik hata ekranı (panik dahil); çalışırken: kapılar fail-closed, ama arka plan kilidi fail-open | HATA-03/04, YDK-03 |
| SharedPreferences yazma reddi | Rıza ekranında tekrar dene; diğer yerlerde çoğunlukla sessiz | HATA-05, RIZA-12 |
| Bozuk/eksik native oturum | Arm "unknown", Check-In degrade bandı, PREPARING → CORRUPTED | HATA-06 |
| Faturalandırma hatası / iptal / çevrimdışı | İptal sessiz; hata/çevrimdışı SnackBar; ödendi-yetki yok ayrı mesaj | HATA-09, ABN-03 |
| Ağ yok | Panik ağsız; harita karosu yok; RC doğrulanamazsa çevrimdışı çapa (acil özelliklerde sınırsız) | HATA-08 |
| Süreç öldürüldü | Native alarm sürer; açılışta uzlaştırma; taslaklar geri yüklenir | HATA-13, BOOT-17 |
| Force-stop | Alarmlar silinir → sessiz kaçırma; açılışta ≤5 dk ise sormadan arama, >5 dk ise teklif bildirimi; bayat CLAIMED yaş sınırsız aranır | HATA-14, NTV-09/10 |
| Uygulama güncellemesi | Göçler + native reconcile | HATA-15, NTV-07 |
| Telefon yeniden başlatma | Oturum uzlaştırması, gecikme sınırı | HATA-16, NTV-06 |
| Veri silme sonrası aynı süreç | Bayat provider durumu; route öncülü bozuk | HATA-12, HATA-19 |

## 7. COMPLETENESS AUDIT (ikinci tur tarama)

İkinci tur tarama `lib/` ve `android/app/src/main` üzerinde yeniden yapıldı; ilk turda kaçırılıp bu turda eklenenler: `onReorder` (KSI-15), 4 genel izin diyaloğu butonu (PRM-01..04), ölü Pro faydası (ABN-13), silme sonrası route öncülü (HATA-19), Dart'ta çağrılmayan native yöntemler (NTV-34), üretilmeyen bildirim payload'ları (BLD-04), üretilmeyen native olay türleri (NTV-22), `ScheduledNotificationReceiver` eksikliği (BLD-01).

### 7.1 Statik sayımlar

| Kategori | Bulunan (statik) | Envanterde temsil | Nasıl sayıldı / not |
|---|---|---|---|
| Dart ekran/widget dosyası | 58 (`lib/screens` 34 + `lib/widgets` 10 + `lib/core/widgets` 14) | 58/58 (ölüler OLU-*) | `find … -name '*.dart'` |
| — hiç oluşturulmayan ekran/widget sınıfı | 6 (`LegalDisclaimerScreen`, `ConsentScreen`, `NetworkErrorRetry`, `LoadingOverlay`, `EmptyState` + `PinSetupScreen` isteğe bağlı modu) | 6/6 | sınıf adının kendi dosyası dışında aranması |
| `onPressed` | 121 | 121/121 | `grep -rnE '\bonPressed\s*:'` |
| `onTap` | 75 (1'i `focus_ring.dart:43` doküman yorumu → gerçek 74) | 74/74 | |
| `onLongPress` | **0** | — | Panik "basılı tut" `onTapDown/onTapUp` ile yapılıyor |
| `onChanged` | 26 | 26/26 | |
| `onSubmitted` / `onFieldSubmitted` | 1 / 1 | 2/2 | |
| `onTapDown` / `onTapUp` / `onTapCancel` | 3 / 3 / 3 | 9/9 | panik butonu, geri sayım tuşu, hızlı eylem kartı |
| `onSelected` / `onRefresh` / `onPageChanged` / `onReorder` | 1 / 1 / 1 / 1 | 4/4 | |
| **Toplam gerçek callback yeri** | **236** | **236/236 → 201 farklı envanter ID'si** | Ek A (satır satır eşleme) |
| Diyalog + alt sayfa yüzeyi | 30 (23 diyalog + 7 alt sayfa) | 30/30 | `showDialog` / `showModalBottomSheet` çağrı yerleri |
| Diyalog/alt sayfa eylem callback yeri | 60 | 60/60 | Ek A'nın alt kümesi |
| SnackBar eylemi | 6 | 6/6 | PNK-08, CHK-03, CHK-05, SWK-03 (×2), FKC-04 |
| Navigasyon/state geçişi | 5 AppRoot state değişimi + 37 `push` + 4 `pushReplacement` + 3 `pushAndRemoveUntil` + 1 `popUntil` = **50** (ayrıca 82 `pop`/`maybePop`) | 50/50 (Bölüm 4, N1–N33; 3 `pushReplacement`/`pushAndRemoveUntil` ölü geri dönüş dalı) | |
| Manifest bileşeni (uygulamanın kendi) | 11 (3 activity, 7 receiver, 1 service) | 11/11 | Ek B |
| Sistem intent aksiyonu (filtre) | 11 (LAUNCHER, VIEW, LOCKED_BOOT_COMPLETED, BOOT_COMPLETED, MY_PACKAGE_REPLACED, USER_UNLOCKED, SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED, TIME_SET, TIMEZONE_CHANGED, APPWIDGET_UPDATE, QS_TILE) | 11/11 | |
| Uygulama içi PendingIntent aksiyonu | 7 (DISPATCH, GRACE, PRE_WARNING × exact/inexact; FALLBACK_CLEANUP; fallback-dial activity; launch intent; tile/widget) | 7/7 | |
| MainActivity yaşam döngüsü/override | 7 (onCreate, onNewIntent, configureFlutterEngine, onKeyDown, onKeyUp, onActivityResult, onDestroy) | 7/7 | |
| MethodChannel yöntemi (native'de tanımlı) | **39** = 30 canlı + 9 kasıtlı `notImplemented` eski yöntem; 9 kanal | 39/39 | Ek B |
| — Dart'ın gerçekten çağırdığı | 28 | — | `getEmergencyCapabilities`, `openManufacturerSettings` Dart'tan erişilemez (NTV-34) |
| EventChannel | 2 (volume_button, emergency events) | 2/2 | |
| Birleşik manifest'teki kütüphane bileşenleri | 17 (RevenueCat 3, Billing 2, share_plus 2, image_picker 1, url_launcher 1, safe_device 1, gms 2, androidx 2, datatransport 3) | Ek B'de listelendi, davranış satırı yalnız kullanıcıya dokunanlar için | `build/…/playDebug/…/AndroidManifest.xml` (bugün 16:17 derlenmiş) |

### 7.2 Statik sayımın güvenilirlik sınırları

- **Bir callback yeri ≠ bir kontrol.** Parametre olarak aktarılan geri çağrılar tek bir kaynak satırında birden çok çalışma zamanı kontrolü üretir: `home_page.dart:964` 6 hızlı eylem kartı; `settings_page.dart:674` 13 ayar kutucuğu; `readiness_card.dart:424` 5 çip; `main_navigation.dart:396` 4 sekme; `check_in_screen.dart:434` 4 süre; `safe_walk_screen.dart:424` 5 süre; `home_page.dart:566` 5 gecikme seçeneği; `fake_call_screen.dart:762` 4 şablon; `contacts_page.dart:1122` kişi sayısı kadar satır. Envanter bu nedenle **callback sayısından değil kontrol/durum bazında** satır açtı; eşleme Ek A'da.
- `onFix*`, `onUnlocked`, `onCompleted`, `onAccepted`, `onGateChanged`, `onConfirmed/onCancelled` gibi **özel adlı** parametreler `onTap:` kalıbına uymaz; ayrıca tarandı ve ilgili satırlara bağlandı (HOME-03..07, BOOT-13..15, ONB-05, RIZA-11, ONB-11..13).
- `showDialog` yerleri sayıldı ama **dinamik içerikli** diyaloglar (ör. `PermissionHelper._showDialog` 5 farklı çağrıda farklı başlık) tek yüzey olarak sayıldı.
- MethodChannel yöntem adları string eşleşmesiyle sayıldı; yansıma/dinamik dispatch yok, ama `EmergencyPlatformChannel` sarmalayıcısı yöntem adını parametre olarak alıyor — isimler tek tek doğrulandı.

## 8. TEST COVERAGE MAP

### 8.1 Test dosyalarının niteliği (319 Dart test dosyası; mevcut ağaçta 1885 test yeşil)

| Sınıf | Dosya | Davranışı gerçekten çalıştırıyor mu | Cihaz kanıtının yerine geçer mi |
|---|---|---|---|
| Gerçek ekran/widget pump eden (`pumpWidget` + gerçek sınıf) | 32 | Evet — ama yalnız şu ekranlar: AppRoot+Splash, UnifiedConsent, Onboarding (+kişi adımı), PinSetup, CountdownScreen, EmergencyCallScreen, MapPage, PaywallScreen, NotificationCategories, PanicButton, ReadinessCard, EmergencyTriggerHost, EmergencyContactConsentDialog, SubscriptionDeletionNotice, küçük sarmalayıcılar | Hayır — platform kanalları mock |
| Stub/replika widget pump eden | 15 | Kısmen — gerçek ekran değil (ör. `layout_size_matrix_test`, `scroll_restoration_test`, `emergency_failure_surface_test` çağıran stub'ı) | Hayır |
| Saf Dart unit/servis (import eder, kaynak okumaz) | 86 | Evet (servis mantığı); 30 dosya platform kanalını `setMockMethodCallHandler` ile taklit eder → native yolu BYPASS eder | Hayır |
| Yalnız kaynak-metni (lib/android dosyasını string okur, import yok) | **133** | **Hayır** — string/regex sözleşmesi; davranış kanıtı sayılmadı | Hayır |
| Kaynak-metni + import karışık | 24 | Kısmen | Hayır |
| Politika/belge/config testleri (lib'e dokunmaz) | 29 | Davranış değil (yayın kapıları) | Hayır |
| Kotlin JVM (Robolectric/fake) | 16 dosya, 119 test | Evet — native koordinatör, alıcı sınırları, depo, metin, bütünlük probu, quick-access intent'leri; **MainActivity kanalları ve VolumeButtonDetector için 0 test** | Hayır (sahte AlarmManager/Telecom) |
| Android instrumentation | 6 dosya, 12 `@Test` | Emülatörde gerçek AlarmManager/Telecom/bildirim; bu turda **koşturulmadı** | Emülatör için evet (kayıtlar eski commit'lerde); fiziksel için hayır |
| `docs/audit` cihaz kayıtları | 14 | Emülatör ölçümleri (API 36/37/35) | Fiziksel cihaz kaydı **yok** |

### 8.2 Hiç pump edilmeyen gerçek ekranlar (tümü)

`MainNavigation`, `HomePage`, `ContactsPage`, `SettingsPage`, `AppUnlockScreen` (yalnız başlangıç akışı içinde tuşları), `FakeCallScreen`, `SirenDialog`, `SafeWalkScreen`, `CheckInScreen`, `SafetyTimelineScreen`, `BatteryOptimizationWizard`, `OemBackgroundGuideScreen`, `LegalSettingsScreen`, `ConsentManagementScreen`, `KvkkDisclosureScreen`, `TermsOfServiceScreen`, `DataExportScreen`, `DataDeletionScreen`, `SubscriptionManagementScreen`, `ProfilePage`, `EditProfileScreen`, `SettingsDetailPage`, `ConnectivityBanner` (gerçek bant; yer ayırma testi stub).

### 8.3 Hiç (import eden) testi olmayan servisler/yardımcılar

`VolumeTriggerService`, `BatteryOptimizationService`, `PermissionHelper`, `PinSettingsHelper`, `AppResetHelper`, `HomeProvider`, `SettingsProvider`, `DestinationRouter`, `KoruBeniForegroundService` (yalnız kaynak), `HapticService`, `LocationConsentGate`, `CheckInProjectionStore`, `EmergencyBookkeeping`, `AtomicStorageService`, `HealthCheckService`. Native: `MainActivity` kanalları, `VolumeButtonDetector`, `PanicTileService`, `PanicWidgetProvider` (yalnız intent kurulumu test ediliyor).

### 8.4 Mock'un gerçek yolu bypass ettiği yerler (bilinçli, ama kanıt sınırı)

- Tüm Dart acil akış testleri `EmergencyPlatformService.forTesting(methodChannel: …)` ile native koordinatörü **taklit ediyor** (GS-01..15, CHK-*, SWK-*). Dart ↔ Kotlin gerçek sözleşmesi yalnız emülatör probları (I) ile birleşiyor.
- Yetki testleri `SubscriptionProvider`/RevenueCat'i sahte yanıtla besliyor; gerçek `CustomerInfo` hiç görülmedi (ABN-*).
- Kotlin koordinatör testleri sahte depo/alarm/Telecom kullanıyor; "1000 iç içe geçme" testleri mantığı kanıtlar, Android zamanlamasını değil.
- `startup_pin_boundary_test` rıza onay kutularını dokunarak değil `widget.onChanged(true)` çağırarak işaretliyor.

## 9. ÖZET

| # | Metrik | Değer |
|---|---|---|
| 1 | Toplam benzersiz kullanıcı/sistem davranışı | **409** (239 kullanıcı eylemi `K:`, 163 sistem tetikleyicisi `S:`, 7 yalnız-kod ölü öğe) |
| 2 | KANITLI | **44** (17 kullanıcı, 27 sistem) |
| 3 | KISMEN KANITLI | **146** |
| 4 | DOĞRULANMADI | **183** |
| 5 | ULAŞILAMAZ / ÖLÜ | **16** |
| 6 | DIŞ SİSTEM GEREKİYOR | **20** |
| 7 | Fiziksel cihaz gerektiren | **119** |
| 8 | Play / RevenueCat gerektiren | **37** |
| 9 | Görsel manuel kontrol gerektiren | **208** |
| 10 | Hiç test edilmeyen kullanıcı etkileşimleri | **147** (davranışı çalıştıran test yok: yalnız kaynak-metni/replika ya da hiç test); bunların **101**'inde hiçbir test dosyası bile yok |

Okuma notu: KANITLI satırların tamamı "platform sınırı sahte" koşuluyla kanıtlı; hiçbiri fiziksel cihaz ya da gerçek mağaza işlemi içermiyor. En güçlü kanıtlı bölgeler: başlangıç yönlendirmesi (AppRoot/Splash/Rıza/Kilit), geri sayımın Dart tarafı (arm → PIN iptal → sevk → sonuç ekranı, kanal mock'lu), native koordinatörün yarış/süreç-ölümü mantığı (JVM), derin bağlantı ayrıştırıcısı. En zayıf bölgeler: Ana Sayfa, Kişiler, Ayarlar, Check-In/Güvenli Yürüyüş **ekranları**, sahte çağrı, siren, ses tuşu, hızlı erişim yüzeylerinin cihaz zinciri, faturalandırma.

## 10. RELEASE BLOCKER OLABİLECEK DOĞRULANMAMIŞ DAVRANIŞLAR

Ölçüt: (a) kullanıcının uygulamanın vaat edilen ana amacını — güvendiği kişiye acil durumda ulaşmayı — gerçekleştirmesini engelleyebilmesi, veya (b) güvenlik/gizlilik açısından yanlış davranış üretebilmesi. "Doğrulanmadı" ≠ "bozuk"; her madde için neyin yanlış gidebileceği ve nasıl hızlıca doğrulanacağı yazıldı.

**R1 — Pro yetki zinciri gerçek satın almayla hiç çalışmadı** (ABN-03/04/05/11/12, PNK-05, BOOT-16). Panik/SOS yalnız Pro'da (`feature_access_matrix.dart:97-120`). Entitlement kimliği (`KoruBeni Pro`) veya paket eşlemesi dashboard'la birebir tutmazsa ödeme yapan kullanıcının kararı `denied`/`unknown` olur → panik basışı paywall'a ya da "doğrulanamadı" mesajına düşer (PNK-05/06), **SOS hiç başlamaz**. (a) kapsamında. Doğrulama: `store/BILLING_RELEASE_CHECKLIST.md`, lisans testçisi + dahili test kanalı.

**R2 — Acil sevk fiziksel telefonda hiç denenmedi** (GS-02, GS-16, NTV-01, NTV-03, CHK-12, SWK-11). Kanıt yalnız API 37 emülatörü, commit `6c1467c` (bu ağaç değil): "istek Telecom'a gitti, 78 ms gecikme". Gerçek SIM, operatör, çift SIM, gerçek Doze ve OEM zamanlayıcı kısıtları altında arama isteği oluşmazsa ürünün ana vaadi (ekran kapalıyken kişiyi aramak) gerçekleşmez. (a). Doğrulama: `telefon-testi-protokolu-2026-09-14.md` Test A, en az bir Pixel + bir agresif OEM.

**R3 — OEM force-stop / arka plan öldürme ve bayat CLAIMED kaydı** (HATA-14, NTV-09, NTV-10). Force-stop alarmları siler → arama sessizce kaçar (a). Ayrıca `CLAIMED` durumda kalmış bir kayıt açılışta **yaş sınırı olmadan** aranır (`EmergencySessionCoordinator.kt:598`; 2026-09-20 kaydı bunu "açık kalıyor" diye listeliyor) → günler sonra istenmeyen acil arama (b). Doğrulama: protokol Test C + CLAIMED durumunu üreten bir instrumentation probu.

**R4 — Aynı süreçte veri silme sonrası bayat provider durumu** (HATA-12; SIF-02, KLT-11). `ContactsProvider`/`HomeProvider` `_initialized`, `SettingsProvider` `_loaded` bayrakları silmeden sonra sıfırlanmıyor; provider'lar `MaterialApp`'in üstünde süreç ömrü boyunca yaşıyor. Kod okumasına göre silinen kişiler Kişiler ekranında görünmeye devam edebilir ve bir sıralama/ekleme/silme işlemi **eski listeyi secure storage'a geri yazabilir** → uygulama içi veri silme vaadi (KVKK, Play Data Safety) bozulur ve kullanıcı yanlış kişi listesine bakar (b). Doğrulama: emülatörde kişi ekle → Ayarlar → Verilerimi sil → yeniden kurulum → Kişiler sekmesi; ya da gerçek ekranları pump eden bir widget testi.

**R5 — Gecikmeli sahte çağrı hiç görünmeyebilir** (BLD-01, FKC-03). `zonedSchedule` kullanılıyor ama bugün derlenen `playDebug` birleşik manifest'inde `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver` (ve boot receiver'ı) yok; eklenti v19 README'si bunu uygulama manifest'ine eklemeyi şart koşuyor. Sonuç: kullanıcıya "zamanlandı" denir, alarm teslim edilecek alıcı bulunamaz. Sahte çağrı bir kaçış/güvenlik aracı olarak mağazada vaat ediliyor; sessiz sahte-başarı (b). Doğrulama: emülatörde "1 dk" seç, bekle — 2 dakikalık iş.

**R6 — Ses tuşu tetikleyici: satılan Pro faydası, sıfır test, kodda olası no-op** (SES-01..05, AYR-08). `VolumeTriggerService` ve `VolumeButtonDetector` için hiçbir test yok. Kod okumasına göre Ayarlar'dan açıldığında dinleyicinin geri çağrısı bir sonraki resume'a kadar `null` kalıyor; bu arada native taraf ses tuşlarını yutuyor → kullanıcı "kurulu" sanır, desen hiçbir şey yapmaz (a, ücretli vaat). Doğrulama: emülatörde `adb shell input keyevent 25` ×3.

**R7 — Paywall'da karşılığı olmayan Pro faydası** (ABN-13). "Gelişmiş güvenlik otomasyonları" paywall ve mağaza metninde satılıyor, `PremiumFeature.advancedAutomation` kodda hiç kullanılmıyor. Güvenlik hatası değil; ücretli abonelikte var olmayan işlev vaadi → mağaza incelemesi/iade riski. (Bu maddeyi ölçütün "vaat edilen işlev" yarısına dayanarak listeledim; işlevsel blocker değil, politika blocker'ı olabilir.)

**Koşullu adaylar (yalnız belirli koşulda (a)/(b) üretir):**
- **K1 — Hızlı Ayarlar kutucuğu / widget cihazda hiç çalıştırılmadı** (HZ-02..06, HZ-10). Kilit ekranından erişilebilen tek panik yolu kutucuk; zincir (tile → trampoline → MainActivity → Dart tüketimi → yetki → geri sayım) hiçbir cihazda kaydedilmedi. Ayrıca soğuk açılışta geri sayım rıza/PIN ekranlarının üstüne açılıyor (tasarım gereği) — yeni kurulumda davranış doğrulanmadı.
- **K2 — Başlangıçta Keystore okunamazsa panik dahil her şey kilitlenir** (HATA-03, BOOT-02). Bilinçli fail-closed; ama o durumda kullanıcı acil akışa hiç erişemez ve ekranda çıkış yolu yok.
- **K3 — Arka plan kilidi depolama hatasında fail-open** (YDK-03). `onResumed` içindeki secure-storage okuması throw ederse Future beklenmediği için kilit ekranı hiç gösterilmez (b, yalnız depolama arızasında).

**Blocker değil ama doğrulanmalı (güvenlik/UX notları):** PIN değiştirme sayfası yanlış eski PIN'i kilit sayacına işlemiyor (PCH-01); kilitli uygulamadan PIN'siz Rıza Yönetimi erişimi (KLT-07); hızlı erişim sonucu ekranında numara maskesiz (SNC-08); Test Modu PIN iptalini prova ettirmiyor (GS-21); Check-In/Güvenli Yürüyüş başlatmada `resolveAccess()` zaman sınırsız (CHK-02, SWK-02); "Ses" ayarı sireni de susturuyor (AYR-07, SRN-01); silme sonrası route öncülü (HATA-19); başlangıçtaki itme yarışı (PIN-10); birincil kişi silinince otomatik yerine koyma yok (KSI-14).

## 11. BU ENVANTERİN EKSİKSİZLİK SINIRLARI

1. **Uygulama bu turda hiç çalıştırılmadı** (emülatör/cihaz yok). Tüm durumlar kod okuması + mevcut test koşusu + eski cihaz kayıtlarından.
2. **Çalışma ağacı karışık:** HEAD `a099b4a` + 35 yol commit edilmemiş WIP. Ayrıca `main` 147 commit geride (AUDIT A-002) — bugün yayına çıkacak build bu envanterin anlattığı davranışı DEĞİL, `main`'in davranışını taşır.
3. **Parametreyle aktarılan geri çağrılar** nedeniyle çalışma zamanı kontrol sayısı statik callback sayısından büyük (Bölüm 7.2). Satırlar kontrol/durum bazında açıldı; yine de liste bazlı yüzeylerde (kişi listesi, zaman çizelgesi kayıtları) her öğe ayrı satır değil.
4. **Sistem/üçüncü taraf arayüzleri kontrol düzeyinde envanterlenmedi:** Android izin diyalogları, sistem paylaşım sayfası, dialer, kişi seçici, galeri, Play Billing satın alma sayfası, RevenueCat Customer Center / Paywall aktiviteleri, tarayıcı, e-posta uygulaması, OEM ayar ekranları. Bunlar yalnız "giriş/çıkış" olarak satırlarda var.
5. **Eklenti iç davranışı izlenmedi:** `flutter_local_notifications` (alıcı eksikliği dışında), `audioplayers`, `geolocator`, `permission_handler`, `purchases_flutter`/`purchases_ui_flutter`, `url_launcher`, `share_plus`, `image_picker`. Birleşik manifest'te `com.google.android.datatransport` bileşenleri var; hangi bağımlılıktan geldiği ve ağ davranışı bu turda incelenmedi.
6. **OEM ve sürüm varyantları:** MIUI/One UI/ColorOS'ta kutucuk, widget, exact alarm ve force-stop davranışı statik analizle bilinemez. API 29–35 fiziksel cihazlarda hiçbir kayıt yok.
7. **Zaman bağımlı davranışlar** (24 saat fallback TTL, 7 gün sihirbaz ertelemesi, 15 dk PIN kilidi, 5 dk gecikme sınırı, 120 sn yeniden kilit) yalnız birim mantığıyla kanıtlı; duvar saati değişimi + Doze birleşimi cihazda ölçülmedi.
8. **Erişilebilirlik:** Semantik ağaç eksiksizliği ve TalkBack okuma sırası statik olarak belirlenemez; tek TalkBack kaydı emülatörde, eski commit'te, 7 ekranda.
9. **Kotlin test görevi `UP-TO-DATE`**: sonuçlar mevcut kaynak girdilerine ait ama bu turda yeniden koşmadı. Instrumentation testleri koşturulmadı.
10. **Play Console ve RevenueCat panoları** incelenmedi (erişim yok); ürün kimlikleri, teklifler, deneme süreleri, lisans testçileri bilinmiyor.
11. **Yalnız TR çalışma zamanı**: İngilizce katalog parite referansı; EN davranışı envanter dışı.
12. **Güvenlik gözlemleri** (YDK-03, PCH-01, KLT-07, HATA-12, BLD-01) kod okumasından çıkarımdır; hiçbiri çalıştırılarak doğrulanmadı ve bu nedenle hiçbiri "hata" diye değil "DOĞRULANMADI" diye işaretlendi.

## Ek A — Callback yeri → envanter ID eşlemesi (236 gerçek yer + 1 yorum yanlış pozitifi)

| Callback yeri | Tür | Metot | Envanter ID |
|---|---|---|---|
| `lib/core/utils/app_reset_helper.dart:70` | onPressed | [showResetDialog] | SIF-01 |
| `lib/core/utils/app_reset_helper.dart:88` | onPressed | [showResetDialog] | SIF-02 |
| `lib/core/utils/permission_helper.dart:309` | onPressed | [_showProminentDisclosure] | PRM-01 |
| `lib/core/utils/permission_helper.dart:319` | onPressed | [_showProminentDisclosure] | PRM-02 |
| `lib/core/utils/permission_helper.dart:410` | onPressed | [_showDialog] | PRM-03 |
| `lib/core/utils/permission_helper.dart:420` | onPressed | [_showDialog] | PRM-04 |
| `lib/core/utils/pin_settings_helper.dart:123` | onPressed | [showPinChangeSheet] | PCH-01..04 |
| `lib/core/widgets/emergency_failure_dialog.dart:136` | onPressed | [show] | GS-26 |
| `lib/core/widgets/emergency_failure_dialog.dart:158` | onPressed | [show] | GS-27 |
| `lib/core/widgets/emergency_failure_dialog.dart:183` | onPressed | [show] | GS-28 |
| `lib/core/widgets/exact_alarm_permission_guard.dart:46` | onPressed | [requireExactAlarmPermission] | CHK-04 |
| `lib/core/widgets/exact_alarm_permission_guard.dart:50` | onPressed | [requireExactAlarmPermission] | CHK-04 |
| `lib/core/widgets/feature_warning_dialog.dart:118` | onPressed | [build] | PNK-09 / CHK-02 / SWK-02 / SRN-01 |
| `lib/core/widgets/focus_ring.dart:43` | onTap | [?] | (yorum satırı — yanlış pozitif) |
| `lib/core/widgets/minimum_tap_target.dart:60` | onTap | [build] | HOME-03..07 (sarmalayıcı) |
| `lib/core/widgets/readiness_card.dart:97` | onTap | [_items] | HOME-03 |
| `lib/core/widgets/readiness_card.dart:102` | onTap | [_items] | HOME-04 |
| `lib/core/widgets/readiness_card.dart:107` | onTap | [_items] | HOME-05 |
| `lib/core/widgets/readiness_card.dart:112` | onTap | [_items] | HOME-06 |
| `lib/core/widgets/readiness_card.dart:117` | onTap | [_items] | HOME-07 |
| `lib/core/widgets/readiness_card.dart:228` | onTap | [build] | HOME-03..07 |
| `lib/core/widgets/readiness_card.dart:232` | onTap | [build] | HOME-03..07 |
| `lib/core/widgets/readiness_card.dart:377` | onTap | [build] | HOME-10 |
| `lib/core/widgets/readiness_card.dart:424` | onTap | [build] | HOME-03..07 |
| `lib/core/widgets/safety_session_pin_gate.dart:208` | onSubmitted | [build] | CHK-10 |
| `lib/core/widgets/safety_session_pin_gate.dart:220` | onPressed | [build] | CHK-10 |
| `lib/core/widgets/safety_session_pin_gate.dart:229` | onPressed | [build] | CHK-10 |
| `lib/core/widgets/subscription_deletion_notice.dart:101` | onTap | [build] | DEL-04 |
| `lib/screens/app_unlock_screen.dart:210` | onPressed | [build] | KLT-07 |
| `lib/screens/app_unlock_screen.dart:353` | onPressed | [build] | KLT-08 |
| `lib/screens/app_unlock_screen.dart:443` | onChanged | [_showForgotPinDialog] | KLT-09 |
| `lib/screens/app_unlock_screen.dart:471` | onPressed | [_showForgotPinDialog] | KLT-10 |
| `lib/screens/app_unlock_screen.dart:478` | onPressed | [_showForgotPinDialog] | KLT-11 |
| `lib/screens/app_unlock_screen.dart:543` | onTap | [_numKey] | KLT-01 |
| `lib/screens/battery_optimization_wizard.dart:245` | onPressed | [build] | PIL-01 |
| `lib/screens/battery_optimization_wizard.dart:275` | onPressed | [build] | PIL-02 |
| `lib/screens/battery_optimization_wizard.dart:307` | onPressed | [build] | PIL-03 |
| `lib/screens/battery_optimization_wizard.dart:330` | onPressed | [build] | PIL-04 |
| `lib/screens/battery_optimization_wizard.dart:348` | onPressed | [build] | PIL-05 |
| `lib/screens/check_in_screen.dart:129` | onPressed | [_showTimerContactRequired] | CHK-03 |
| `lib/screens/check_in_screen.dart:205` | onPressed | [_startCheckIn] | CHK-05 |
| `lib/screens/check_in_screen.dart:434` | onTap | [_buildDurationOption] | CHK-01 |
| `lib/screens/check_in_screen.dart:610` | onPressed | [_buildActiveView] | CHK-08 |
| `lib/screens/check_in_screen.dart:633` | onPressed | [_buildActiveView] | CHK-09 |
| `lib/screens/contacts_page.dart:101` | onPressed | [build] | KSI-02 |
| `lib/screens/contacts_page.dart:136` | onPressed | [build] | KSI-09 |
| `lib/screens/contacts_page.dart:267` | onTap | [_buildContactCard] | KSI-11 |
| `lib/screens/contacts_page.dart:427` | onPressed | [_showContactOptions] | KSI-12 |
| `lib/screens/contacts_page.dart:452` | onPressed | [_showContactOptions] | KSI-13 |
| `lib/screens/contacts_page.dart:487` | onPressed | [_showContactOptions] | KSI-14 |
| `lib/screens/contacts_page.dart:543` | onPressed | [_confirmRemoveContact] | KSI-14 |
| `lib/screens/contacts_page.dart:547` | onPressed | [_confirmRemoveContact] | KSI-14 |
| `lib/screens/contacts_page.dart:604` | onPressed | [_buildEmptyContactsState] | KSI-08 |
| `lib/screens/contacts_page.dart:706` | onPressed | [_showContactKvkkInfoIfNeeded] | KSI-03 |
| `lib/screens/contacts_page.dart:826` | onPressed | [_showAddContactSheetFlow] | KSI-04 |
| `lib/screens/contacts_page.dart:884` | onFieldSubmitted | [_showAddContactSheetFlow] | KSI-06 |
| `lib/screens/contacts_page.dart:896` | onPressed | [_showAddContactSheetFlow] | KSI-06 |
| `lib/screens/contacts_page.dart:1122` | onTap | [_showEmergencyPicker] | KSI-10 |
| `lib/screens/countdown_screen.dart:945` | onTap | [_buildNumberPad] | GS-08 |
| `lib/screens/countdown_screen.dart:958` | onTap | [_buildNumberPad] | GS-08 |
| `lib/screens/countdown_screen.dart:966` | onTap | [_buildPadButton] | GS-08 |
| `lib/screens/countdown_screen.dart:1024` | onTapDown | [build] | GS-08 |
| `lib/screens/countdown_screen.dart:1025` | onTapUp | [build] | GS-08 |
| `lib/screens/countdown_screen.dart:1029` | onTapCancel | [build] | GS-08 |
| `lib/screens/edit_profile_screen.dart:133` | onPressed | [build] | PRF-05 |
| `lib/screens/emergency_call_screen.dart:221` | onPressed | [_showFailSafeAlert] | SNC-03 |
| `lib/screens/emergency_call_screen.dart:246` | onPressed | [_showFailSafeAlert] | SNC-04 |
| `lib/screens/emergency_call_screen.dart:273` | onPressed | [_showFailSafeAlert] | SNC-05 |
| `lib/screens/emergency_call_screen.dart:442` | onTap | [build] | SNC-06 |
| `lib/screens/fake_call_screen.dart:137` | onPressed | [_checkFirstUseWarning] | FKC-05 |
| `lib/screens/fake_call_screen.dart:144` | onPressed | [_checkFirstUseWarning] | FKC-05 |
| `lib/screens/fake_call_screen.dart:311` | onPressed | [build] | FKC-10 |
| `lib/screens/fake_call_screen.dart:321` | onPressed | [build] | FKC-11 |
| `lib/screens/fake_call_screen.dart:491` | onTap | [_buildCallButton] | FKC-08 / FKC-09 |
| `lib/screens/fake_call_screen.dart:614` | onPressed | [_showCustomizeDialog] | FKC-12 |
| `lib/screens/fake_call_screen.dart:652` | onPressed | [_showCustomizeDialog] | FKC-14 |
| `lib/screens/fake_call_screen.dart:762` | onPressed | [_buildTemplateChip] | FKC-13 |
| `lib/screens/home_page.dart:312` | onTap | [_buildEmergencyContactChip] | HOME-01 |
| `lib/screens/home_page.dart:452` | onPressed | [_showPermissionRationale] | HOME-24 |
| `lib/screens/home_page.dart:459` | onPressed | [_showPermissionRationale] | HOME-25 |
| `lib/screens/home_page.dart:566` | onTap | [_buildFakeCallOption] | FKC-02 / FKC-03 |
| `lib/screens/home_page.dart:604` | onPressed | [_scheduleDelayedFakeCall] | FKC-04 |
| `lib/screens/home_page.dart:665` | onPressed | [_buildOnboardingCard] | HOME-11 |
| `lib/screens/home_page.dart:679` | onTap | [_buildOnboardingCard] | HOME-12 |
| `lib/screens/home_page.dart:685` | onTap | [_buildOnboardingCard] | HOME-13 |
| `lib/screens/home_page.dart:691` | onTap | [_buildOnboardingCard] | HOME-14 |
| `lib/screens/home_page.dart:708` | onTap | [_buildOnboardingStep] | HOME-12..14 |
| `lib/screens/home_page.dart:773` | onPressed | [_buildTestModeButton] | HOME-14 |
| `lib/screens/home_page.dart:964` | onTap | [_buildActionCard] | HOME-15..22 |
| `lib/screens/home_page.dart:1199` | onTapDown | [build] | HOME-23 |
| `lib/screens/home_page.dart:1200` | onTapUp | [build] | HOME-23 |
| `lib/screens/home_page.dart:1204` | onTapCancel | [build] | HOME-23 |
| `lib/screens/legal/consent_management_screen.dart:157` | onPressed | [_showRevokeConfirmation] | YSL-07 |
| `lib/screens/legal/consent_management_screen.dart:164` | onPressed | [_showRevokeConfirmation] | YSL-07 |
| `lib/screens/legal/consent_management_screen.dart:200` | onPressed | [build] | YSL-08 |
| `lib/screens/legal/consent_management_screen.dart:360` | onTap | [_buildConsentTile] | YSL-06 |
| `lib/screens/legal/consent_management_screen.dart:365` | onChanged | [_buildConsentTile] | YSL-06 |
| `lib/screens/legal/consent_screen.dart:172` | onChanged | [build] | OLU-02 |
| `lib/screens/legal/consent_screen.dart:180` | onChanged | [build] | OLU-02 |
| `lib/screens/legal/consent_screen.dart:189` | onChanged | [build] | OLU-02 |
| `lib/screens/legal/consent_screen.dart:198` | onChanged | [build] | OLU-02 |
| `lib/screens/legal/consent_screen.dart:241` | onPressed | [build] | OLU-02 |
| `lib/screens/legal/kvkk_disclosure_screen.dart:77` | onPressed | [build] | YSL-09 |
| `lib/screens/legal/kvkk_disclosure_screen.dart:176` | onTap | [build] | YSL-10 |
| `lib/screens/legal/kvkk_disclosure_screen.dart:201` | onChanged | [build] | YSL-10 |
| `lib/screens/legal/kvkk_disclosure_screen.dart:231` | onPressed | [build] | YSL-10 |
| `lib/screens/legal/terms_of_service_screen.dart:98` | onPressed | [build] | YSL-09 |
| `lib/screens/legal/terms_of_service_screen.dart:190` | onTap | [build] | YSL-10 |
| `lib/screens/legal/terms_of_service_screen.dart:215` | onChanged | [build] | YSL-10 |
| `lib/screens/legal/terms_of_service_screen.dart:245` | onPressed | [build] | YSL-10 |
| `lib/screens/legal/unified_consent_screen.dart:261` | onTap | [_buildAgeOption] | RIZA-01 |
| `lib/screens/legal/unified_consent_screen.dart:400` | onPressed | [_buildEulaSection] | RIZA-02 |
| `lib/screens/legal/unified_consent_screen.dart:424` | onChanged | [_buildEulaSection] | RIZA-03 |
| `lib/screens/legal/unified_consent_screen.dart:525` | onPressed | [_buildKvkkSection] | RIZA-04 |
| `lib/screens/legal/unified_consent_screen.dart:549` | onChanged | [_buildKvkkSection] | RIZA-05 |
| `lib/screens/legal/unified_consent_screen.dart:601` | onChanged | [_buildOptionalConsents] | RIZA-06 |
| `lib/screens/legal/unified_consent_screen.dart:607` | onChanged | [_buildOptionalConsents] | RIZA-07 |
| `lib/screens/legal/unified_consent_screen.dart:614` | onChanged | [_buildOptionalConsents] | RIZA-08 |
| `lib/screens/legal/unified_consent_screen.dart:620` | onChanged | [_buildOptionalConsents] | RIZA-09 |
| `lib/screens/legal/unified_consent_screen.dart:655` | onPressed | [_buildActionButton] | RIZA-10 / RIZA-11 |
| `lib/screens/legal_disclaimer_screen.dart:167` | onChanged | [build] | OLU-01 |
| `lib/screens/legal_disclaimer_screen.dart:184` | onTap | [build] | OLU-01 |
| `lib/screens/legal_disclaimer_screen.dart:207` | onChanged | [build] | OLU-01 |
| `lib/screens/legal_disclaimer_screen.dart:223` | onTap | [build] | OLU-01 |
| `lib/screens/legal_disclaimer_screen.dart:241` | onTap | [build] | OLU-01 |
| `lib/screens/legal_disclaimer_screen.dart:264` | onChanged | [build] | OLU-01 |
| `lib/screens/legal_disclaimer_screen.dart:283` | onChanged | [build] | OLU-01 |
| `lib/screens/legal_disclaimer_screen.dart:300` | onChanged | [build] | OLU-01 |
| `lib/screens/legal_disclaimer_screen.dart:324` | onPressed | [build] | OLU-01 |
| `lib/screens/legal_disclaimer_screen.dart:370` | onTap | [_buildCheckboxTile] | OLU-01 |
| `lib/screens/legal_disclaimer_screen.dart:388` | onChanged | [_buildCheckboxTile] | OLU-01 |
| `lib/screens/main_navigation.dart:396` | onTap | [_buildNavItem] | NAV-01..04 |
| `lib/screens/map_page.dart:314` | onPressed | [_showPermissionError] | MAP-04 |
| `lib/screens/map_page.dart:332` | onPressed | [_showPermissionError] | MAP-04 |
| `lib/screens/map_page.dart:381` | onTap | [build] | MAP-06 |
| `lib/screens/map_page.dart:785` | onPressed | [_buildMyLocationFab] | MAP-05 |
| `lib/screens/oem_background_guide_screen.dart:254` | onPressed | [_stepCard] | OEM-02 |
| `lib/screens/oem_background_guide_screen.dart:264` | onPressed | [_stepCard] | OEM-03 |
| `lib/screens/oem_background_guide_screen.dart:297` | onPressed | [_footer] | OEM-04 |
| `lib/screens/onboarding/onboarding_contact_step.dart:442` | onChanged | [_form] | ONB-08 |
| `lib/screens/onboarding/onboarding_contact_step.dart:468` | onPressed | [_form] | ONB-09 |
| `lib/screens/onboarding/onboarding_contact_step.dart:483` | onPressed | [_form] | ONB-10 |
| `lib/screens/onboarding/onboarding_contact_step.dart:523` | onPressed | [_savedCard] | ONB-14 |
| `lib/screens/onboarding/onboarding_contact_step.dart:565` | onPressed | [_consentCard] | ONB-06 |
| `lib/screens/onboarding_screen.dart:219` | onPressed | [build] | ONB-01 |
| `lib/screens/onboarding_screen.dart:233` | onPageChanged | [build] | ONB-02 |
| `lib/screens/onboarding_screen.dart:396` | onPressed | [build] | ONB-03 / ONB-04 / ONB-05 |
| `lib/screens/pin_setup_screen.dart:170` | onPressed | [build] | PIN-09 |
| `lib/screens/pin_setup_screen.dart:345` | onTap | [_buildNumberPad] | PIN-03 |
| `lib/screens/pin_setup_screen.dart:358` | onTap | [_buildNumberPad] | PIN-02 |
| `lib/screens/pin_setup_screen.dart:368` | onTap | [_buildPadButton] | PIN-02 / PIN-03 |
| `lib/screens/profile_page.dart:122` | onPressed | [build] | PRF-04 |
| `lib/screens/profile_page.dart:185` | onTap | [_buildSettingsItem] | PRF-01 / PRF-02 / PRF-03 |
| `lib/screens/safe_walk_screen.dart:125` | onPressed | [_startSafeWalk] | SWK-03 |
| `lib/screens/safe_walk_screen.dart:176` | onPressed | [_showTimerContactRequired] | SWK-03 |
| `lib/screens/safe_walk_screen.dart:339` | onPressed | [build] | SWK-07 |
| `lib/screens/safe_walk_screen.dart:424` | onTap | [_buildSetupView] | SWK-01 |
| `lib/screens/safe_walk_screen.dart:472` | onPressed | [_buildSetupView] | SWK-02 |
| `lib/screens/safe_walk_screen.dart:622` | onPressed | [_buildActiveView] | SWK-05 |
| `lib/screens/safe_walk_screen.dart:641` | onPressed | [_buildActiveView] | SWK-06 |
| `lib/screens/safe_walk_screen.dart:685` | onPressed | [_showExitWarning] | SWK-08 |
| `lib/screens/safe_walk_screen.dart:689` | onPressed | [_showExitWarning] | SWK-09 |
| `lib/screens/safety_timeline_screen.dart:264` | onPressed | [_confirmAndDeleteEntry] | GCM-05 |
| `lib/screens/safety_timeline_screen.dart:271` | onPressed | [_confirmAndDeleteEntry] | GCM-05 |
| `lib/screens/safety_timeline_screen.dart:401` | onPressed | [_showAddEntryDialog] | GCM-03 |
| `lib/screens/safety_timeline_screen.dart:474` | onPressed | [build] | GCM-02 |
| `lib/screens/safety_timeline_screen.dart:634` | onSelected | [_buildEntryCard] | GCM-04 / GCM-05 |
| `lib/screens/settings_detail_page.dart:179` | onPressed | [_buildBody] | AYR-17 |
| `lib/screens/settings_detail_page.dart:353` | onPressed | [build] | AYR-18 |
| `lib/screens/settings_legal/data_deletion_screen.dart:83` | onPressed | [_requestDeletion] | DEL-03 |
| `lib/screens/settings_legal/data_deletion_screen.dart:90` | onPressed | [_requestDeletion] | DEL-03 |
| `lib/screens/settings_legal/data_deletion_screen.dart:135` | onPressed | [build] | DEL-01 |
| `lib/screens/settings_legal/data_deletion_screen.dart:249` | onPressed | [build] | DEL-02 |
| `lib/screens/settings_legal/data_export_screen.dart:99` | onPressed | [build] | EXP-01 |
| `lib/screens/settings_legal/data_export_screen.dart:216` | onPressed | [build] | EXP-02 |
| `lib/screens/settings_legal/legal_settings_screen.dart:41` | onPressed | [build] | YSL-01 |
| `lib/screens/settings_legal/legal_settings_screen.dart:67` | onTap | [build] | YSL-02 |
| `lib/screens/settings_legal/legal_settings_screen.dart:81` | onTap | [build] | YSL-03 |
| `lib/screens/settings_legal/legal_settings_screen.dart:95` | onTap | [build] | YSL-04 |
| `lib/screens/settings_legal/legal_settings_screen.dart:124` | onTap | [build] | YSL-05 |
| `lib/screens/settings_legal/legal_settings_screen.dart:138` | onTap | [build] | YSL-11 |
| `lib/screens/settings_legal/legal_settings_screen.dart:157` | onTap | [build] | YSL-12 |
| `lib/screens/settings_legal/legal_settings_screen.dart:177` | onTap | [build] | YSL-13 |
| `lib/screens/settings_legal/legal_settings_screen.dart:274` | onTap | [_buildTile] | YSL-02..13 (sarmalayıcı) |
| `lib/screens/settings_notifications/notification_categories_screen.dart:89` | onRefresh | [build] | BLK-01 |
| `lib/screens/settings_notifications/notification_categories_screen.dart:192` | onTap | [_categoryRow] | BLK-02 |
| `lib/screens/settings_page.dart:148` | onTap | [build] | AYR-03 |
| `lib/screens/settings_page.dart:161` | onTap | [build] | AYR-04 |
| `lib/screens/settings_page.dart:176` | onTap | [build] | AYR-05 |
| `lib/screens/settings_page.dart:190` | onTap | [build] | AYR-06 |
| `lib/screens/settings_page.dart:213` | onChanged | [build] | AYR-07 |
| `lib/screens/settings_page.dart:223` | onChanged | [build] | AYR-08 |
| `lib/screens/settings_page.dart:257` | onTap | [build] | AYR-09 |
| `lib/screens/settings_page.dart:285` | onTap | [build] | AYR-10 |
| `lib/screens/settings_page.dart:298` | onTap | [build] | AYR-11 |
| `lib/screens/settings_page.dart:311` | onTap | [build] | AYR-12 |
| `lib/screens/settings_page.dart:332` | onTap | [build] | AYR-13 |
| `lib/screens/settings_page.dart:345` | onTap | [build] | AYR-14 |
| `lib/screens/settings_page.dart:353` | onTap | [build] | AYR-15 |
| `lib/screens/settings_page.dart:362` | onPressed | [build] | AYR-16 |
| `lib/screens/settings_page.dart:429` | onTap | [_buildProTile] | AYR-02 |
| `lib/screens/settings_page.dart:534` | onTap | [_buildProfileSection] | AYR-01 |
| `lib/screens/settings_page.dart:674` | onTap | [_buildNavigationTile] | AYR-03..15 (sarmalayıcı) |
| `lib/screens/splash_screen.dart:181` | onPressed | [_goNext] | BOOT-10 |
| `lib/screens/subscription/paywall_screen.dart:382` | onPressed | [_buildPlansUnavailableCard] | ABN-02 |
| `lib/screens/subscription/paywall_screen.dart:418` | onTap | [_buildPlanCard] | ABN-03 / ABN-04 |
| `lib/screens/subscription/paywall_screen.dart:509` | onPressed | [_buildPlanCard] | ABN-03 / ABN-04 |
| `lib/screens/subscription/paywall_screen.dart:541` | onPressed | [_buildRestoreButton] | ABN-05 |
| `lib/screens/subscription/paywall_screen.dart:586` | onPressed | [_buildLegalLinks] | ABN-06 |
| `lib/screens/subscription/paywall_screen.dart:590` | onPressed | [_buildLegalLinks] | ABN-06 |
| `lib/screens/subscription/paywall_screen.dart:594` | onPressed | [_buildLegalLinks] | ABN-06 |
| `lib/screens/subscription/subscription_management_screen.dart:134` | onTap | [build] | ABN-07 |
| `lib/screens/subscription/subscription_management_screen.dart:147` | onPressed | [build] | ABN-08 |
| `lib/screens/subscription/subscription_management_screen.dart:186` | onTap | [build] | ABN-09 |
| `lib/screens/subscription/subscription_management_screen.dart:340` | onTap | [_buildActionTile] | ABN-07 / ABN-09 (sarmalayıcı) |
| `lib/widgets/connectivity_banner.dart:132` | onTap | [build] | NAV-08 |
| `lib/widgets/connectivity_banner.dart:248` | onPressed | [_showOfflineInfoDialog] | NAV-09 |
| `lib/widgets/consent_checkbox_widget.dart:39` | onTap | [build] | RIZA-03 / RIZA-05..09 |
| `lib/widgets/consent_checkbox_widget.dart:65` | onChanged | [build] | RIZA-03 / RIZA-05..09 |
| `lib/widgets/emergency_contact_consent_dialog.dart:196` | onTap | [build] | ONB-11 |
| `lib/widgets/emergency_contact_consent_dialog.dart:218` | onChanged | [build] | ONB-11 |
| `lib/widgets/emergency_contact_consent_dialog.dart:250` | onPressed | [build] | ONB-12 |
| `lib/widgets/emergency_contact_consent_dialog.dart:265` | onPressed | [build] | ONB-13 |
| `lib/widgets/empty_state.dart:69` | onPressed | [build] | OLU-04 |
| `lib/widgets/network_error_retry.dart:53` | onPressed | [build] | OLU-03 |
| `lib/widgets/network_error_retry.dart:93` | onPressed | [showNetworkErrorSnackBar] | OLU-03 |
| `lib/widgets/panic_button.dart:307` | onPressed | [_showContactRequired] | PNK-08 |
| `lib/widgets/panic_button.dart:362` | onPressed | [_onAccessibleTap] | PNK-11 |
| `lib/widgets/panic_button.dart:369` | onPressed | [_onAccessibleTap] | PNK-12 |
| `lib/widgets/panic_button.dart:426` | onTap | [build] | PNK-10 |
| `lib/widgets/panic_button.dart:428` | onTapDown | [build] | PNK-01 |
| `lib/widgets/panic_button.dart:429` | onTapUp | [build] | PNK-02 / PNK-03 |
| `lib/widgets/panic_button.dart:430` | onTapCancel | [build] | PNK-04 |
| `lib/widgets/settings_switch_tile.dart:77` | onTap | [build] | AYR-07 / AYR-08 |
| `lib/widgets/settings_switch_tile.dart:85` | onChanged | [build] | AYR-07 / AYR-08 |
| `lib/widgets/siren_dialog.dart:257` | onPressed | [build] | SRN-02 |
| `lib/screens/contacts_page.dart:176` | onReorder | [build] | KSI-15 |

## Ek B — Native / Android giriş noktası → envanter eşlemesi

### B.1 Uygulamanın kendi manifest bileşenleri (11)

| Bileşen | exported | Tetik | Flutter karşılığı | Kotlin testi | ID |
|---|---|---|---|---|---|
| `MainActivity` | true | MAIN/LAUNCHER | AppRoot/Splash | — | BOOT-01 |
| `MainActivity` | true | VIEW `korubeni://open/*` (onCreate/onNewIntent) | `DeepLinkChannel.consume` → MainNavigation | — | DL-01, DL-02 |
| `EmergencyFallbackDialActivity` | false | Fallback/teklif bildirimi PendingIntent | — (native) | DirectBootSafetyKernelTest, koordinatör | NTV-11, NTV-12 |
| `QuickPanicTrampolineActivity` | false | Tile/widget PendingIntent | `QuickPanicRequestService.consume` | PanicLaunchTest | HZ-06 |
| `CountdownAlarmReceiver` | false | ACTION_DISPATCH (exact/inexact) | olay `emergencySessionDispatched` / bekleyen tetik | Boundary + koordinatör + I | NTV-01, NTV-02 |
| `CheckInAlarmReceiver` | false | DISPATCH / GRACE / PRE_WARNING | aynı | Boundary + koordinatör | NTV-03, NTV-04, NTV-05 |
| `BootCompletedReceiver` | false | LOCKED_BOOT_COMPLETED, BOOT_COMPLETED | — | AlarmClockRecoveryTest, Boundary, I | NTV-06, NTV-09 |
| `BootCompletedReceiver` | false | MY_PACKAGE_REPLACED | — | Boundary | NTV-07 |
| `BootCompletedReceiver` | false | USER_UNLOCKED | — | DirectBootSafetyKernelTest | NTV-08 |
| `ExactAlarmPermissionReceiver` | false | SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED | — | Boundary | NTV-17 |
| `ClockChangeReceiver` | false | TIME_SET, TIMEZONE_CHANGED | — | AlarmClockRecoveryTest | NTV-16 |
| `EmergencyFallbackCleanupReceiver` | false | deleteIntent + 24 sa RTC alarmı | — | Boundary | NTV-13, NTV-14 |
| `PanicWidgetProvider` | false | APPWIDGET_UPDATE + tıklama | trampoline → host | — (yalnız PanicLaunch) | HZ-04, HZ-05 |
| `PanicTileService` | true (`BIND_QUICK_SETTINGS_TILE`) | QS_TILE onStartListening / onClick | trampoline → host | — (yalnız PanicLaunch/Store) | HZ-01, HZ-02, HZ-03 |

### B.2 MethodChannel / EventChannel yöntemleri (39 yöntem + 2 olay kanalı)

| Kanal | Yöntem | Dart çağıranı | Kotlin testi | ID |
|---|---|---|---|---|
| `…/emergency_platform` | armEmergencySession | countdown_screen, check_in_service | koordinatör | GS-01/02, CHK-02 |
| | cancelEmergencySession | countdown_screen, check_in_service | koordinatör | GS-09..11, CHK-09 |
| | dispatchEmergencySession | countdown_screen, check_in_service | koordinatör | GS-15, CHK-12 |
| | warnEmergencySession | check_in_service | koordinatör | CHK-11, SWK-04 |
| | discoverEmergencySession | check_in_service | koordinatör | CHK-13 |
| | readEmergencySession | check_in_service | koordinatör | CHK-13 |
| | pendingEmergencyOutcomes / acknowledgeEmergencyOutcome | native_emergency_history | DeviceProtectedEmergencySessionStoreTest | NTV-23 |
| | wipeEmergencySessions | app_reset_service | koordinatör | SIF-02, KLT-11 |
| | consumePendingTrigger | emergency_trigger_host | — | NTV-21 |
| | canScheduleExactAlarms / requestExactAlarmPermission | exact_alarm guard, notification_service | — | CHK-04, BLD-01 |
| | getDeviceState | battery_optimization_service, readiness | EmergencyPlatformReadinessTest | HOME-08 |
| | readNativeSafetyDiagnostics | user_data_export_service | NativeSafetyEventRingTest | EXP-02 |
| | requestBatteryOptimizationExemption / openBatteryOptimizationSettings | battery service, wizard, OEM | — | PIL-01, PIL-03, OEM-02 |
| | getEmergencyCapabilities / openManufacturerSettings | **yok** | EmergencyPlatformReadinessTest | NTV-34 |
| | 9 eski yöntem (notImplemented) | yok | LegacySafetyAuthorityTest | NTV-35 |
| `…/emergency_platform/events` | olay: emergencySessionDispatched | emergency_trigger_host | — | NTV-20 |
| | (Dart bekliyor, native üretmiyor) checkInGraceStarted / checkInExpired / safetyClockChanged | emergency_trigger_host | — | NTV-22 |
| `…/volume_button` (Event) | "volume_panic" | volume_trigger_service | — | SES-01 |
| `…/volume_button/control` | setEnabled | volume_trigger_service | — | SES-01..05 |
| `…/device_integrity` | probe | device_security_service | DeviceIntegrityProbeTest | BOOT-09, NTV-33 |
| `…/audio_control` | setMaxAlarmVolume / restoreAlarmVolume | siren_dialog | — | SRN-01/02, NTV-32 |
| `…/android_intents` | openDialer | android_intent_service | — | GS-17, GS-26, SNC-03, KSI-12, NTV-30 |
| `…/settings` | openNotificationSettings | permission_helper, oem guide | — | CHK-05, NTV-31 |
| | openNotificationChannelSettings | notification_preferences_service | — | BLK-02 |
| | openActivityByComponent | oem_background_guide_service | — | OEM-02 |
| | getDeviceManufacturer | oem_background_guide_service | — | OEM-01 |
| `…/contacts_picker` | pickPhoneContact | native_contact_picker_service | — | ONB-09, KSI-04, NTV-29 |
| `…/deep_link` | consumeDeepLink | deep_link_channel | — | DL-01..04 |
| `…/quick_panic` | consumePanicRequest | quick_panic_request_service | PanicRequestStoreTest | HZ-07 |

### B.3 Birleşik manifest'teki kütüphane bileşenleri (davranış satırına bağlananlar)

RevenueCat `PaywallActivity`/`CustomerCenterActivity` (ABN-07), `SimulatedStoreErrorDialogActivity` (exported belirtilmemiş; RC test mağazası), Billing `ProxyBillingActivity`/`V2` (ABN-03/04), share_plus provider + receiver (AYR-14, GCM-04, EXP-02), image_picker provider (FKC-12), url_launcher `WebViewActivity` (dış linkler), safe_device `MockLocation.MainActivity` (exported=false; çalışma zamanında çağrılmıyor), gms `GoogleApiActivity`/`ModuleDependencies`, androidx `InitializationProvider`, `ProfileInstallReceiver` (exported, DUMP izniyle korunuyor), `com.google.android.datatransport` 3 bileşen (kaynağı/ağ davranışı incelenmedi — Bölüm 11/5).
