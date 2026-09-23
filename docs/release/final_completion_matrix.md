# KoruBeni — Final Completion Matrix

**Uretildi:** 2026-09-23 · **Baseline commit:** bu dosyayi ekleyen commit · **Satir sayisi:** 409/409

Kaynak envanter: [`docs/audit/interaction_inventory_2026-09-22.md`](../audit/interaction_inventory_2026-09-22.md) — 2026-09-22 tarihli, 409 davranisli "KoruBeni — Eksiksiz Etkilesim Envanteri".
Bu dosya YENI bir envanter degildir: o envanterin 409 ID'sini birebir devralir,
uzerine yalnizca takip alanlari ekler. Yeni ID eklemek = once envantere satir eklemek.

## Bu matrisin kurallari

1. **Bir satir yalnizca gercek kanitla KAPANIR.** Kod dogru gorunmesi, "test var"
   denmesi ya da kaynak-metni (string/grep) testi kapatmaz.
2. **Mevcut durum** sutunu envanterden BIREBIR devralindi; bu turda hicbir satirin
   durumu iyilestirilmedi.
3. **Final durum** yalnizca su kosulda `KAPANDI` yazar: envanter durumu `KANITLI`
   VE emulator/fiziksel cihaz/Play/gorsel kanit gereksinimlerinin hicbiri yok.
   Diger her satir `ACIK`.
4. **Ilgili asama** turetilmis bir ONERIDIR (asama plani henuz yazilmadi), sabit bir
   kuralla: Play/RC > fiziksel cihaz > emulator > repo-ici test > gorsel siralamasinda
   en pahali gereksinim asamayi belirler. Olu kod satirlari kanit degil karar bekler.
5. Bir fix davranisi degistirdiginde etkilenen TUM satirlar yeniden degerlendirilir.

## Asama dagilimi (baseline)

| Asama | Anlami | Baseline | Asama 2 sonrasi |
|---|---|---|---|
| `A1-kapandi` | kanit tam | 19 | **21** |
| `A2-repo` | repo-ici davranis testi | 141 | 141 |
| `A3-emu` | emulator | 72 | 72 |
| `A4-fiz` | fiziksel cihaz | 101 | **100** |
| `A5-play` | Play / RevenueCat | 36 | 36 |
| `A6-gorsel` | gorsel / manuel | 24 | 24 |
| `A7-olu` | olu kod karari | 16 | **15** |
| | **Toplam** | **409** | **409** |

> **Bu `A1..A7` etiketleri KANIT TURUDUR, calisma plani asama numarasi DEGILDIR.**
> `A5-play` "Play/RevenueCat kaniti gerekir" demektir; "Asama 5" demek degildir.
> Calisma plani asamalari (Asama 1, 2, 5, 6 ...) asagidaki devir bolumunde,
> ayri ve acik olarak yazilir. Ikisini karistirmak, R6'nin cihaz ucunu
> "gorsel kontrol" sanmaya yol acar.

## Final durum dagilimi (baseline)

| Final durum | Baseline | Asama 2 sonrasi |
|---|---|---|
| KAPANDI | 19 | **21** |
| ACIK | 390 | **388** |

> Baseline'da 409 satirin yalnizca 19 tanesi kapaliydi. Bu bir gerileme degil, ilk kez
> durust sayim: geri kalan satirlar ya cihaz/magaza kaniti ya da gercek davranis
> testi bekliyor.
>
> Asama 2 iki satir kapatti: **NTV-10** (bayat CLAIMED kaydi artik sormadan
> aranmiyor — emulatorde iki yonlu prob ile) ve **ABN-13** (karsiligi olmayan
> Pro faydasi kaldirildi — urun karari uygulandi). Asama 2'nin diger duzeltmeleri
> ilgili satirlarin KANIT alanini guclendirdi ama satirlari kapatmadi: onlarin
> bekledigi emulator/fiziksel/gorsel kanit hala eksik. Bu bilincli: bir fix'in
> varligi, o satirin istedigi kanit turu degildir.

## Asama 2 kapanisi ve devir (R1-R7 / K1-K3)

Kaynak: envanterin 10. bolumu ("RELEASE BLOCKER OLABILECEK DOGRULANMAMIS
DAVRANISLAR"). Asagidaki "Asama" sutunu **calisma plani asamasidir**, yukaridaki
`A1..A7` kanit-turu etiketiyle ayni sey DEGILDIR.

| # | Konu | Durum | Devredildigi asama | Kanit |
|---|---|---|---|---|
| **R1** | Pro yetki zinciri gercek satin almayla hic calismadi | **EXTERNAL REMAINDER** | Asama 6 (Play + RevenueCat) | Yok. Lisans testcisi + dahili test kanali gerekir |
| **R2** | Acil sevk fiziksel telefonda hic denenmedi | **EXTERNAL REMAINDER** | Asama 5 (fiziksel cihaz) | Yok. `telefon-testi-protokolu-2026-09-14.md` Test A |
| **R3a** | Bayat `CLAIMED` kaydi yas siniri olmadan araniyordu | **KAPANDI** | — | `D 2026-09-23`; JVM + emulator probu, iki yonlu negatif kontrol. Satir: NTV-10 |
| **R3b** | Force-stop alarmlari siler, arama sessizce kacar | **EXTERNAL REMAINDER** | Asama 5 (fiziksel cihaz) | Protokol Test C. Satirlar: NTV-09, HATA-14 |
| **R4** | Veri silme sonrasi bayat provider durumu | **KAPANDI (repo)** | UI dogrulamasi Asama 3 (emulator) | `app_reset_provider_state_test`. Satirlar: HATA-12, SIF-02, KLT-11 |
| **R5** | Gecikmeli sahte cagri hic gorunmeyebilir | **KAPANDI** | Fiziksel cihaz teyidi Asama 5 | `D 2026-09-23`: manifest + kurulu paket + gercek teslim; mutasyon `NameNotFoundException`. Satirlar: BLD-01, FKC-03 |
| **R6a** | Ses tusu tetikleyici Dart/native kablosu | **KAPANDI (repo)** | — | `volume_trigger_service_behavior_test` (mutasyonla oldurulen) + `VolumeButtonDetectorTest` (4) |
| **R6b** | Ses tusu tetikleyici cihazda uctan uca | **EXTERNAL REMAINDER** | **Asama 6 (R1 bagimli)** | Yapilamadi: tetikleyici `SubscriptionGate` arkasinda; bu yapida `revenuecat_api_key_missing`, anahtar hic acilmiyor. Satirlar: SES-01..05, AYR-08 |
| **R7** | Paywall'da karsiligi olmayan Pro faydasi | **KAPANDI** | — | Urun karari: kaldirildi. `store_release_docs_test` paritesi. Satir: ABN-13 |
| **K1** | Hizli Ayarlar kutucugu / widget cihazda | **EXTERNAL REMAINDER** | Asama 5 (fiziksel cihaz) | Yok |
| **K2** | Keystore okunamazsa panik dahil her sey kilitli | **KAPANDI (repo)** | Emulator teyidi Asama 3 | `bootstrap_recovery_screen_test`. Satirlar: HATA-03, BOOT-02 |
| **K3** | Arka plan kilidi depolama hatasinda fail-open | **KAPANDI (repo)** | Emulator teyidi Asama 3 | `app_lifecycle_lock_test` (gercek ekran pump). Satir: YDK-03 |

### Asama 2'de bulunan ve kapatilan, listede olmayan madde

| # | Konu | Durum | Kanit |
|---|---|---|---|
| **C1** (CRITICAL) | Aktif panik oturumu PIN'siz sifirlamayla susturulabiliyordu: `SafetySessionActivityProbe` panigi kapsamiyordu, `wipe()` ise `ARMED` kaydi iptal ediyor | **KAPANDI** | `safety_session_activity_probe_test` 7 -> 14 test; mutasyonla oldurulen; negatif kontrollu. Satirlar: KLT-08, SIF-02 |

**R6b hakkinda durust not:** envanter bu maddeyi "emulatorde `adb shell input
keyevent 25` x3" ile dogrulanabilir saymisti. Dogrulanamadi ve dogrulanmis gibi
yazilmadi: tetikleyiciyi acmak Pro yetkisi ister, o da R1'dir. Bu nedenle R6'nin
cihaz ucu Asama 6'ya, R1'in arkasina tasindi.

## Matris

| ID | Yuzey | Mevcut durum | Gereken kanit turu | Ilgili asama | Son kanit | Final durum |
|---|---|---|---|---|---|---|
| BOOT-01 | Başlangıç | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | app_bootstrap_service_test; main_startup_init_order_test [U; S]; gercek-yol: Kısmen (servis gerçek, `main()` değil) | ACIK |
| BOOT-02 | Başlangıç hata ekranı | KISMEN KANITLI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | bootstrap_recovery_screen_test (gercek ekran pump; cikissiz hata ekrani yerine kurtarma yolu) [W]; gercek-yol: Evet (Flutter katmani) | ACIK |
| BOOT-03 | Başlangıç | KANITLI | Yok (kanit tam) | `A1-kapandi` | best_effort_startup_test; profile_email_removal_test; sensitive_temp_file_service_test [U]; gercek-yol: Evet | KAPANDI |
| BOOT-04 | Başlangıç | KISMEN KANITLI | repo-ici davranis testi | `A2-repo` | main_release_logging_contract_test; crash_log_service_test [S; U]; gercek-yol: Kısmen | ACIK |
| BOOT-05 | Başlangıç | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | main_text_scaling_test [U]; gercek-yol: Kısmen (yalnız clamp fonksiyonu) | ACIK |
| BOOT-06 | Tüm uygulama | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | secure_window_contract_test [S]; gercek-yol: Hayır | ACIK |
| BOOT-07 | Tüm uygulama | KISMEN KANITLI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | app_privacy_shield_test [W]; gercek-yol: Evet (Flutter katmanı) | ACIK |
| BOOT-08 | Splash | DOĞRULANMADI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | reduced_motion_coverage_test [S; W*]; gercek-yol: Hayır | ACIK |
| BOOT-09 | Splash | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | device_security_service_test; device_security_test; DeviceIntegrityProbeTest (18); DeviceIntegrityEmulatorProbeTest [U; S; K; I; D]; gercek-yol: Kısmen; cihaz kaydi 2026-09-22 | ACIK |
| BOOT-10 | Splash bütünlük diyaloğu | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| BOOT-11 | Splash yönlendirme | KANITLI | Yok (kanit tam) | `A1-kapandi` | startup_pin_boundary_test [W]; gercek-yol: Evet | KAPANDI |
| BOOT-12 | Splash yönlendirme | KANITLI | Yok (kanit tam) | `A1-kapandi` | startup_pin_boundary_test ("reconsent gates existing PIN"); splash_version_logic_test [W; S]; gercek-yol: Evet | KAPANDI |
| BOOT-13 | Splash yönlendirme | KANITLI | Yok (kanit tam) | `A1-kapandi` | startup_pin_boundary_test [W]; gercek-yol: Evet | KAPANDI |
| BOOT-14 | Splash yönlendirme | KANITLI | Yok (kanit tam) | `A1-kapandi` | startup_pin_boundary_test [W]; gercek-yol: Evet | KAPANDI |
| BOOT-15 | Splash yönlendirme | KANITLI | Yok (kanit tam) | `A1-kapandi` | startup_pin_boundary_test [W]; gercek-yol: Evet | KAPANDI |
| BOOT-16 | Splash | KISMEN KANITLI | repo-ici davranis testi + Play/RevenueCat islemi | `A5-play` | subscription_provider_access_test; offline_sos_entitlement_policy_test [U]; gercek-yol: Kısmen (RC sahte) | ACIK |
| BOOT-17 | AppRoot | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | state_restoration_test; state_restoration_navigator_precondition_test; state_restoration_policy_test; D 2026-08-14 [W; W*; S; D]; gercek-yol: Kısmen | ACIK |
| BOOT-18 | Kök ekranlar | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| RIZA-01 | UnifiedConsent | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | startup_pin_boundary_test (gerçek tap) [W]; gercek-yol: Evet | ACIK |
| RIZA-02 | UnifiedConsent | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| RIZA-03 | UnifiedConsent | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | startup_pin_boundary_test (onChanged doğrudan çağrılıyor); unified_consent_retry_test; touch_target_minimum_size_test [W]; gercek-yol: Kısmen (dokunma jesti değil callback) | ACIK |
| RIZA-04 | UnifiedConsent | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| RIZA-05 | UnifiedConsent | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | startup_pin_boundary_test; unified_consent_retry_test [W]; gercek-yol: Kısmen | ACIK |
| RIZA-06 | UnifiedConsent | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | unified_consent_retry_test [W]; gercek-yol: Kısmen | ACIK |
| RIZA-07 | UnifiedConsent | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | unified_consent_retry_test [W]; gercek-yol: Kısmen | ACIK |
| RIZA-08 | UnifiedConsent | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | unified_consent_retry_test [W]; gercek-yol: Kısmen | ACIK |
| RIZA-09 | UnifiedConsent | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | unified_consent_retry_test [W]; gercek-yol: Kısmen | ACIK |
| RIZA-10 | UnifiedConsent | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | startup_pin_boundary_test [W]; gercek-yol: Evet | ACIK |
| RIZA-11 | UnifiedConsent | KANITLI | Yok (kanit tam) | `A1-kapandi` | startup_pin_boundary_test; unified_consent_retry_test [W]; gercek-yol: Evet | KAPANDI |
| RIZA-12 | UnifiedConsent | KANITLI | Yok (kanit tam) | `A1-kapandi` | unified_consent_retry_test [W]; gercek-yol: Evet | KAPANDI |
| RIZA-13 | UnifiedConsent | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | legal_* policy tests; release_readiness_policy_test [S]; gercek-yol: Hayır | ACIK |
| RIZA-14 | UnifiedConsent | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | legal_age_gate_contract_test [S]; gercek-yol: Hayır | ACIK |
| ONB-01 | Onboarding | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | onboarding_contact_gate_source_test [S]; gercek-yol: Hayır | ACIK |
| ONB-02 | Onboarding | DOĞRULANMADI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | state_restoration_policy_test; D 2026-08-16 [S; D]; gercek-yol: Hayır | ACIK |
| ONB-03 | Onboarding | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | onboarding_safety_copy_render_test (sayfa render) [W]; gercek-yol: Kısmen (tap yok) | ACIK |
| ONB-04 | Onboarding | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | onboarding_contact_gate_source_test [S]; gercek-yol: Hayır | ACIK |
| ONB-05 | Onboarding | KISMEN KANITLI | repo-ici davranis testi | `A2-repo` | onboarding_contact_gate_service_test [U]; gercek-yol: Kısmen (UI tap yok) | ACIK |
| ONB-06 | Kişi adımı | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | onboarding_contact_gate_service_test; accessibility_guidelines_test [U; W]; gercek-yol: Kısmen | ACIK |
| ONB-07 | Kişi adımı | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | input_robustness_test; state_restoration_test [W]; gercek-yol: Evet | ACIK |
| ONB-08 | Kişi adımı | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | input_robustness_test; state_restoration_test; onboarding_contact_step_keyboard_test [W]; gercek-yol: Evet | ACIK |
| ONB-09 | Kişi adımı | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | contacts_picker_native_test [S; U]; gercek-yol: Kısmen (native yok) | ACIK |
| ONB-10 | Kişi adımı | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | onboarding_contact_gate_service_test; onboarding_contact_step_keyboard_test [U; W]; gercek-yol: Kısmen | ACIK |
| ONB-11 | Kişi rıza diyaloğu | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | button_loading_state_test [W]; gercek-yol: Evet | ACIK |
| ONB-12 | Kişi rıza diyaloğu | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| ONB-13 | Kişi rıza diyaloğu | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | button_loading_state_test [W]; gercek-yol: Kısmen | ACIK |
| ONB-14 | Kişi adımı | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| ONB-15 | Kişi adımı | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | onboarding_contact_step_keyboard_test; D 2026-08-13 [W; D]; gercek-yol: Kısmen | ACIK |
| PIN-01 | PinSetup (zorunlu) | DOĞRULANMADI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | main_navigation_construction_sites_test [S]; gercek-yol: Hayır | ACIK |
| PIN-02 | PinSetup | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | pin_setup_layout_stability_test [W]; gercek-yol: Evet | ACIK |
| PIN-03 | PinSetup | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | pin_setup_layout_stability_test [W]; gercek-yol: Evet | ACIK |
| PIN-04 | PinSetup | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | pin_setup_layout_stability_test; pin_change_validation_test [W; U]; gercek-yol: Evet | ACIK |
| PIN-05 | PinSetup | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| PIN-06 | PinSetup | KISMEN KANITLI | repo-ici davranis testi | `A2-repo` | pin_verification_service_test; pin_hasher_test [U]; gercek-yol: Kısmen (UI akışı yok) | ACIK |
| PIN-07 | PinSetup | KISMEN KANITLI | repo-ici davranis testi | `A2-repo` | pin_verification_service_test [U]; gercek-yol: Kısmen | ACIK |
| PIN-08 | PinSetup | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| PIN-09 | PinSetup | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| PIN-10 | İlk ana ekran | DOĞRULANMADI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| KLT-01 | AppUnlock | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | startup_pin_boundary_test [W]; gercek-yol: Evet | ACIK |
| KLT-02 | AppUnlock | KANITLI | Yok (kanit tam) | `A1-kapandi` | startup_pin_boundary_test [W]; gercek-yol: Evet | KAPANDI |
| KLT-03 | AppUnlock | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | pin_lockout_service_test; unlock_screen_duress_contract_test [U; S]; gercek-yol: Kısmen (UI yok) | ACIK |
| KLT-04 | AppUnlock | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | pin_lockout_backoff_test; pin_lockout_service_test [U]; gercek-yol: Kısmen | ACIK |
| KLT-05 | AppUnlock | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | pin_lockout_service_test [U]; gercek-yol: Kısmen | ACIK |
| KLT-06 | AppUnlock | KISMEN KANITLI | repo-ici davranis testi | `A2-repo` | single_pin_verification_path_test; pin_verification_service_test [S; U]; gercek-yol: Kısmen | ACIK |
| KLT-07 | AppUnlock | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| KLT-08 | AppUnlock | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | safety_session_activity_probe_test (14 test: panik ARMED/PREPARING/CLAIMED sifirlamayi engeller, bitmis oturum engellemez, okunamayan yuva fail-closed); forgot_pin_reset_route_test [U; S]; gercek-yol: Evet (probe) — CRITICAL: probe panik oturumunu kapsamiyordu, 2026-09-23 kapatildi | ACIK |
| KLT-09 | Unuttum diyaloğu | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | forgot_pin_reset_route_test [S]; gercek-yol: Hayır | ACIK |
| KLT-10 | Unuttum diyaloğu | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| KLT-11 | Unuttum diyaloğu | KISMEN KANITLI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | app_reset_native_prefs_test; contact_service_app_reset_cache_test; forgot_pin_reset_route_test; app_reset_provider_state_test [U; S]; gercek-yol: Kısmen | ACIK |
| KLT-12 | AppUnlock | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | unlock_screen_duress_contract_test [S]; gercek-yol: Hayır | ACIK |
| YDK-01 | Arka plan kilidi | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | app_lifecycle_lock_test [U]; gercek-yol: Kısmen (push yok) | ACIK |
| YDK-02 | Arka plan kilidi | KANITLI | Yok (kanit tam) | `A1-kapandi` | app_lifecycle_lock_test [U]; gercek-yol: Evet | KAPANDI |
| YDK-03 | Arka plan kilidi | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | app_lifecycle_lock_test (gercek AppUnlockScreen pump; firlatan secure storage artik fail-closed) [W]; gercek-yol: Evet | ACIK |
| YDK-04 | Arka plan kilidi | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| NAV-01 | MainNavigation | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | tab_crossfade_test [S]; gercek-yol: Hayır | ACIK |
| NAV-02 | MainNavigation | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | tab_crossfade_test; map_page_ui_test [S]; gercek-yol: Hayır | ACIK |
| NAV-03 | MainNavigation | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | tab_crossfade_test [S]; gercek-yol: Hayır | ACIK |
| NAV-04 | MainNavigation | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | tab_crossfade_test [S]; gercek-yol: Hayır | ACIK |
| NAV-05 | MainNavigation | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | state_restoration_policy_test; D 2026-08-14 [S; D]; gercek-yol: Hayır | ACIK |
| NAV-06 | MainNavigation | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| NAV-07 | Bağlantı bandı | KISMEN KANITLI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | connectivity_banner_reserves_space_test; connectivity_service_test; D 2026-08-16 [W*; U; D]; gercek-yol: Kısmen | ACIK |
| NAV-08 | Bağlantı bandı | DOĞRULANMADI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | D 2026-08-14 (dokunma hedefi) [D]; gercek-yol: Kısmen | ACIK |
| NAV-09 | Çevrimdışı diyaloğu | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| NAV-10 | MainNavigation | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| HOME-01 | Ana Sayfa | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | home_page_test [S]; gercek-yol: Hayır | ACIK |
| HOME-02 | Ana Sayfa | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| HOME-03 | Hazırlık kartı | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | readiness_card_test [W]; gercek-yol: Kısmen (kart gerçek, home kablosu değil) | ACIK |
| HOME-04 | Hazırlık kartı | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | readiness_card_test [W]; gercek-yol: Kısmen (izin akışı yok) | ACIK |
| HOME-05 | Hazırlık kartı | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | readiness_card_test [W]; gercek-yol: Kısmen | ACIK |
| HOME-06 | Hazırlık kartı | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | readiness_card_test; consent_gate_service_test [W; U]; gercek-yol: Kısmen | ACIK |
| HOME-07 | Hazırlık kartı | DOĞRULANMADI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | readiness_card_test [W]; gercek-yol: Kısmen | ACIK |
| HOME-08 | Hazırlık kartı | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | readiness_card_test; emergency_readiness_test; emergency_readiness_behavior_test; home_readiness_exact_alarm_test [W; U; S]; gercek-yol: Kısmen | ACIK |
| HOME-09 | Hazırlık kartı | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | readiness_card_stale_verification_test [W]; gercek-yol: Evet | ACIK |
| HOME-10 | Hazırlık kartı | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | readiness_card_test [W]; gercek-yol: Kısmen | ACIK |
| HOME-11 | Onboarding kartı | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| HOME-12 | Onboarding kartı | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| HOME-13 | Onboarding kartı | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| HOME-14 | Ana Sayfa / Onboarding kartı adım 3 | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | rehearsal_record_service_test; countdown_dispose_lifecycle_test [U; W]; gercek-yol: Kısmen (Home kablosu yok) | ACIK |
| HOME-15 | Hızlı eylemler | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | premium_gating_contract_test; consent_gate_enforcement_test [S]; gercek-yol: Hayır | ACIK |
| HOME-16 | Hızlı eylemler | DOĞRULANMADI | repo-ici davranis testi + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | premium_gating_contract_test [S]; gercek-yol: Hayır | ACIK |
| HOME-17 | Hızlı eylemler | KISMEN KANITLI | repo-ici davranis testi + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | premium_gating_contract_test; subscription_gate_test [S; U]; gercek-yol: Kısmen | ACIK |
| HOME-18 | Hızlı eylemler | KISMEN KANITLI | repo-ici davranis testi + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | subscription_gate_test; subscription_gate_unverified_test [U; W*]; gercek-yol: Kısmen | ACIK |
| HOME-19 | Hızlı eylemler | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | premium_gating_contract_test [S]; gercek-yol: Hayır | ACIK |
| HOME-20 | Hızlı eylemler | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | premium_gating_contract_test [S]; gercek-yol: Hayır | ACIK |
| HOME-21 | Hızlı eylemler | DOĞRULANMADI | repo-ici davranis testi + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | premium_gating_contract_test [S]; gercek-yol: Hayır | ACIK |
| HOME-22 | Hızlı eylemler | KISMEN KANITLI | repo-ici davranis testi + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | subscription_gate_test [U]; gercek-yol: Kısmen | ACIK |
| HOME-23 | Hızlı eylem kartı | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| HOME-24 | Gerekçe diyaloğu | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| HOME-25 | Gerekçe diyaloğu | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| HOME-26 | Pil sihirbazı otomatik | DOĞRULANMADI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | battery_wizard_onboarding_test [S]; gercek-yol: Hayır | ACIK |
| HOME-27 | Ana Sayfa | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | no_sms_references_test; legal_no_first_responder_claims_test [S]; gercek-yol: Hayır | ACIK |
| PNK-01 | Panik butonu | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | panic_button_behavior_test [W]; gercek-yol: Evet | ACIK |
| PNK-02 | Panik butonu | KISMEN KANITLI | repo-ici davranis testi + fiziksel cihaz + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | panic_button_behavior_test; panic_button_hold_contract_test; panic_button_release_contract_test [W; S]; gercek-yol: Kısmen (tam 3 sn → push testi adı yok) | ACIK |
| PNK-03 | Panik butonu | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | panic_button_behavior_test [W]; gercek-yol: Evet | ACIK |
| PNK-04 | Panik butonu | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| PNK-05 | Panik butonu | KISMEN KANITLI | repo-ici davranis testi + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | subscription_gate_test; subscription_gate_unverified_test [U; W*]; gercek-yol: Kısmen | ACIK |
| PNK-06 | Panik butonu | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | panic_button_behavior_test; subscription_gate_unverified_test [W]; gercek-yol: Evet | ACIK |
| PNK-07 | Panik butonu | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | contact_service_emergency_read_contract_test [S]; gercek-yol: Hayır | ACIK |
| PNK-08 | Panik SnackBar | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| PNK-09 | İlk kullanım uyarısı | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | no_sms_references_test [S]; gercek-yol: Hayır | ACIK |
| PNK-10 | Panik butonu (TalkBack) | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | accessibility_guidelines_test; panic_button_a11y_test; D 2026-08-21 [W; S; D]; gercek-yol: Kısmen | ACIK |
| PNK-11 | TalkBack onay diyaloğu | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| PNK-12 | TalkBack onay diyaloğu | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| PNK-13 | Panik butonu | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | panic_route_guard_test; panic_button_test [S]; gercek-yol: Hayır | ACIK |
| PNK-14 | Panik butonu | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | panic_button_pro_only_test [S]; gercek-yol: Hayır | ACIK |
| GS-01 | Geri sayım | KANITLI | Yok (kanit tam) | `A1-kapandi` | countdown_locked_screen_arm_test; emergency_trigger_host_contact_mask_test [W]; gercek-yol: Evet (native mock) | KAPANDI |
| GS-02 | Geri sayım | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | EmergencySessionCoordinatorTest (51); EmergencySessionAlarmInstrumentationTest; NativeDozeDispatchProbeTest; D 2026-09-13 native-doze [K; I; D]; gercek-yol: Kısmen | ACIK |
| GS-03 | Geri sayım | KANITLI | emulator | `A3-emu` | countdown_locked_screen_arm_test; bounded_frame_wait_test [W; U]; gercek-yol: Evet | ACIK |
| GS-04 | Geri sayım | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | countdown_dispose_lifecycle_test; panic_arm_policy_test [W; U]; gercek-yol: Evet | ACIK |
| GS-05 | Geri sayım | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | countdown_dispose_lifecycle_test ("rejected native arm ... PIN cancel exits locally"); panic_arm_policy_test [W; U]; gercek-yol: Kısmen | ACIK |
| GS-06 | Geri sayım | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | panic_arm_policy_test; emergency_platform_typed_contract_test [U]; gercek-yol: Kısmen | ACIK |
| GS-07 | Geri sayım | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | countdown_bridge_missing_test; emergency_platform_bridge_test [W; U]; gercek-yol: Evet | ACIK |
| GS-08 | Geri sayım | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | countdown_dispose_lifecycle_test; countdown_accessibility_test [W]; gercek-yol: Evet | ACIK |
| GS-09 | Geri sayım | KANITLI | Yok (kanit tam) | `A1-kapandi` | countdown_lockout_reset_failure_test [W]; gercek-yol: Evet | KAPANDI |
| GS-10 | Geri sayım | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | countdown_dispose_lifecycle_test [W]; gercek-yol: Evet | ACIK |
| GS-11 | Geri sayım | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | emergency_platform_typed_contract_test [U]; gercek-yol: Kısmen (UI dalı yok) | ACIK |
| GS-12 | Geri sayım | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | countdown_pin_dispatch_contract_test [S]; gercek-yol: Hayır | ACIK |
| GS-13 | Geri sayım | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | countdown_dispose_lifecycle_test ("PIN read failure") [W]; gercek-yol: Evet | ACIK |
| GS-14 | Geri sayım | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | countdown_back_guard_test [S]; gercek-yol: Hayır | ACIK |
| GS-15 | Geri sayım | KANITLI | Yok (kanit tam) | `A1-kapandi` | emergency_trigger_host_contact_mask_test; emergency_dispatch_pipeline_test; dispatch_path_latency_contract_test [W; U; S]; gercek-yol: Evet (native mock) | KAPANDI |
| GS-16 | Geri sayım | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | EmergencySessionCoordinatorTest; D 2026-09-13 native-doze [K; D]; gercek-yol: Kısmen | ACIK |
| GS-17 | Geri sayım | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | android_intent_service_test; call_service_test [U; S]; gercek-yol: Kısmen | ACIK |
| GS-18 | Geri sayım | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| GS-19 | Geri sayım | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | emergency_failure_surface_test; emergency_result_policy_test [W; U]; gercek-yol: Kısmen (diyalog gerçek, tetikleme değil) | ACIK |
| GS-20 | Geri sayım (Test Modu) | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | countdown_dispose_lifecycle_test ("test mode advances locally") [W]; gercek-yol: Evet | ACIK |
| GS-21 | Geri sayım (Test Modu) | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| GS-22 | Geri sayım | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | countdown_contact_mask_test; emergency_trigger_host_contact_mask_test [W]; gercek-yol: Evet | ACIK |
| GS-23 | Geri sayım | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | countdown_accessibility_test; countdown_live_region_test [W; S]; gercek-yol: Kısmen (TalkBack gerçek değil) | ACIK |
| GS-24 | Geri sayım | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| GS-25 | Geri sayım | KISMEN KANITLI | repo-ici davranis testi | `A2-repo` | countdown_dispose_lifecycle_test; wakelock_balance_test [W; S]; gercek-yol: Kısmen | ACIK |
| GS-26 | Hata diyaloğu | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | emergency_failure_surface_test (render) [W]; gercek-yol: Kısmen (tap yok) | ACIK |
| GS-27 | Hata diyaloğu | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | test yok; gercek-yol: Hayır | ACIK |
| GS-28 | Hata diyaloğu | KISMEN KANITLI | repo-ici davranis testi | `A2-repo` | emergency_failure_surface_test [W]; gercek-yol: Kısmen | ACIK |
| SNC-01 | Acil sonuç ekranı | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | emergency_per_target_outcome_test [W]; gercek-yol: Evet | ACIK |
| SNC-02 | Acil sonuç ekranı | DOĞRULANMADI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| SNC-03 | Fail-safe diyaloğu | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| SNC-04 | Fail-safe diyaloğu | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | test yok; gercek-yol: Hayır | ACIK |
| SNC-05 | Fail-safe diyaloğu | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| SNC-06 | Acil sonuç ekranı | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| SNC-07 | Acil sonuç ekranı | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | test yok; gercek-yol: Hayır | ACIK |
| SNC-08 | Acil sonuç ekranı | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | emergency_trigger_host_contact_mask_test (yalnız ad) [W]; gercek-yol: Kısmen | ACIK |
| SNC-09 | Acil sonuç ekranı | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| SNC-10 | Acil sonuç ekranı | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | wakelock_balance_test [S]; gercek-yol: Hayır | ACIK |
| HZ-01 | Hızlı Ayarlar kutucuğu | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | quick_access_panic_surface_test [S]; gercek-yol: Hayır | ACIK |
| HZ-02 | Hızlı Ayarlar kutucuğu | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | PanicLaunchTest; PanicRequestStoreTest; quick_access_panic_surface_test [K; S]; gercek-yol: Kısmen | ACIK |
| HZ-03 | Hızlı Ayarlar kutucuğu | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| HZ-04 | Ana ekran widget'ı | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| HZ-05 | Ana ekran widget'ı | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | PanicLaunchTest [K]; gercek-yol: Kısmen | ACIK |
| HZ-06 | Trampoline | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | PanicLaunchTest; PanicRequestStoreTest [K]; gercek-yol: Kısmen | ACIK |
| HZ-07 | EmergencyTriggerHost | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | quick_panic_request_service_test; emergency_trigger_duplicate_guard_test; emergency_trigger_host_contact_mask_test [U; W]; gercek-yol: Evet (Dart) | ACIK |
| HZ-08 | EmergencyTriggerHost | KANITLI | Yok (kanit tam) | `A1-kapandi` | emergency_trigger_duplicate_guard_test [W]; gercek-yol: Evet | KAPANDI |
| HZ-09 | EmergencyTriggerHost | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | emergency_trigger_duplicate_guard_test [W]; gercek-yol: Evet | ACIK |
| HZ-10 | Hızlı erişim — soğuk açılış | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | test yok; gercek-yol: Hayır | ACIK |
| HZ-11 | MainActivity | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | PanicLaunchTest; quick_access_panic_surface_test [K; S]; gercek-yol: Kısmen | ACIK |
| SES-01 | Ses tuşu tetikleyici | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi | `A5-play` | volume_trigger_service_behavior_test (mutasyonla oldurulen davranis testi); VolumeButtonDetectorTest (4 Robolectric) [U; K]; gercek-yol: Evet (Dart + JVM); cihaz uctan uca dogrulamasi **Asama 6 / R1 (Play+RevenueCat yetkisi)** bekliyor | ACIK |
| SES-02 | Ses tuşu tetikleyici | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | volume_trigger_service_behavior_test (mutasyonla oldurulen davranis testi); VolumeButtonDetectorTest (4 Robolectric) [U; K]; gercek-yol: Evet (Dart + JVM); cihaz uctan uca dogrulamasi **Asama 6 / R1 (Play+RevenueCat yetkisi)** bekliyor | ACIK |
| SES-03 | Ses tuşu tetikleyici | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | volume_trigger_service_behavior_test (mutasyonla oldurulen davranis testi); VolumeButtonDetectorTest (4 Robolectric) [U; K]; gercek-yol: Evet (Dart + JVM); cihaz uctan uca dogrulamasi **Asama 6 / R1 (Play+RevenueCat yetkisi)** bekliyor | ACIK |
| SES-04 | Ses tuşu tetikleyici | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | volume_trigger_service_behavior_test (mutasyonla oldurulen davranis testi); VolumeButtonDetectorTest (4 Robolectric) [U; K]; gercek-yol: Evet (Dart + JVM); cihaz uctan uca dogrulamasi **Asama 6 / R1 (Play+RevenueCat yetkisi)** bekliyor | ACIK |
| SES-05 | Ses tuşu tetikleyici | KISMEN KANITLI | repo-ici davranis testi + Play/RevenueCat islemi | `A5-play` | volume_trigger_service_behavior_test (mutasyonla oldurulen davranis testi); VolumeButtonDetectorTest (4 Robolectric) [U; K]; gercek-yol: Evet (Dart + JVM); cihaz uctan uca dogrulamasi **Asama 6 / R1 (Play+RevenueCat yetkisi)** bekliyor | ACIK |
| NTV-01 | CountdownAlarmReceiver | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | EmergencySessionCoordinatorTest; EmergencyReceiverExceptionBoundaryTest; EmergencySessionAlarmInstrumentationTest; D 2026-09-13 native-doze [K; I; D]; gercek-yol: Kısmen | ACIK |
| NTV-02 | Koordinatör | KANITLI | Yok (kanit tam) | `A1-kapandi` | EmergencySessionCoordinatorTest (1000 iç içe geçme ×3) [K]; gercek-yol: Evet (JVM, sahte depo) | KAPANDI |
| NTV-03 | CheckInAlarmReceiver | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | EmergencySessionCoordinatorTest; EmergencyReceiverExceptionBoundaryTest [K]; gercek-yol: Kısmen | ACIK |
| NTV-04 | CheckInAlarmReceiver | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | EmergencySessionCoordinatorTest (uyarı testleri) [K]; gercek-yol: Kısmen | ACIK |
| NTV-05 | CheckInAlarmReceiver | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | EmergencySessionCoordinatorTest [K]; gercek-yol: Kısmen | ACIK |
| NTV-06 | BootCompletedReceiver | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | AlarmClockRecoveryTest; EmergencySessionCoordinatorTest; Phase3RebootProbeTest; OverdueSessionProbeTest; D 2026-09-20 [K; I; D]; gercek-yol: Kısmen | ACIK |
| NTV-07 | BootCompletedReceiver | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi | `A5-play` | EmergencyReceiverExceptionBoundaryTest [K]; gercek-yol: Kısmen | ACIK |
| NTV-08 | BootCompletedReceiver | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | DirectBootSafetyKernelTest [K]; gercek-yol: Kısmen | ACIK |
| NTV-09 | Force-stop sonrası açılış | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | EmergencySessionCoordinatorTest (overdue 6 test); OverdueSessionProbeTest; D 2026-09-13 force-stop; D 2026-09-20; D 2026-09-23 (CLAIMED dali kapandi) [K; I; D]; gercek-yol: Kısmen — force-stop yarisi ACIK, **Asama 5 / fiziksel cihaz** | ACIK |
| NTV-10 | Force-stop sonrası açılış | KANITLI | Yok (kanit tam) | `A1-kapandi` | EmergencySessionCoordinatorTest (bayat/taze CLAIMED, negatif kontrollu); OverdueSessionProbeTest.staleClaimedSessionIsOfferedNotDialled + recentlyClaimedSessionIsStillDialled (gercek Direct Boot deposu + gercek koordinator) [K; I; D]; gercek-yol: Evet; cihaz kaydi 2026-09-23 | KAPANDI |
| NTV-11 | Gecikmiş oturum teklifi | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | EmergencySessionCoordinatorTest ("consumed exactly once", "fail closed after 24h"); DirectBootSafetyKernelTest [K]; gercek-yol: Kısmen | ACIK |
| NTV-12 | Manuel fallback bildirimi | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | EmergencySessionCoordinatorTest [K]; gercek-yol: Kısmen | ACIK |
| NTV-13 | Fallback bildirimi | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | EmergencyReceiverExceptionBoundaryTest [K]; gercek-yol: Kısmen | ACIK |
| NTV-14 | Fallback bildirimi | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | EmergencySessionCoordinatorTest [K]; gercek-yol: Kısmen | ACIK |
| NTV-15 | Direct Boot | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | DirectBootSafetyKernelTest; DeviceProtectedEmergencySessionStoreTest [K]; gercek-yol: Kısmen | ACIK |
| NTV-16 | ClockChangeReceiver | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | AlarmClockRecoveryTest; time_boundary_safety_test [K; U]; gercek-yol: Kısmen | ACIK |
| NTV-17 | ExactAlarmPermissionReceiver | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | EmergencyReceiverExceptionBoundaryTest [K]; gercek-yol: Kısmen | ACIK |
| NTV-18 | Exact alarm izni geri alındı | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| NTV-19 | Alıcı sınırı | KANITLI | Yok (kanit tam) | `A1-kapandi` | EmergencyReceiverExceptionBoundaryTest (6) [K]; gercek-yol: Evet | KAPANDI |
| NTV-20 | Olay kanalı | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | native_event_contract_test [S]; gercek-yol: Hayır | ACIK |
| NTV-21 | Bekleyen tetik | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | native_event_contract_test [S]; gercek-yol: Hayır | ACIK |
| NTV-22 | Olay kanalı | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | native_event_contract_test [S]; gercek-yol: Hayır | ACIK |
| NTV-23 | Native geçmiş | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | native_emergency_history_test [U]; gercek-yol: Kısmen | ACIK |
| NTV-24 | Native uyarı bildirimleri | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| NTV-25 | Native bildirim metni | KANITLI | Yok (kanit tam) | `A1-kapandi` | NativeNotificationTextTest [K]; gercek-yol: Evet | KAPANDI |
| NTV-26 | Native bildirim | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | EmergencySessionCoordinatorTest; FullScreenIntentNotificationTest [K]; gercek-yol: Kısmen | ACIK |
| NTV-27 | Arm yetenek reddi | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | EmergencySessionCoordinatorTest; EmergencyPlatformReadinessTest; SupportedOsBoundaryInstrumentationTest [K; I]; gercek-yol: Kısmen | ACIK |
| NTV-28 | Süreç ölümü (sevk ortası) | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | EmergencySessionCoordinatorTest (4 süreç ölümü testi) [K]; gercek-yol: Evet (JVM) | ACIK |
| NTV-29 | Kanal: kişi seçici | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | contacts_picker_native_test [S; U]; gercek-yol: Kısmen (Dart eşlemesi) | ACIK |
| NTV-30 | Kanal: android_intents | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | android_intent_service_test [U]; gercek-yol: Kısmen | ACIK |
| NTV-31 | Kanal: settings | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | notification_categories_test; oem_background_guide_service_test [W; U]; gercek-yol: Kısmen | ACIK |
| NTV-32 | Kanal: audio_control | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| NTV-33 | Kanal: device_integrity | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | DeviceIntegrityProbeTest; device_security_service_test; DeviceIntegrityEmulatorProbeTest [K; U; I]; gercek-yol: Kısmen | ACIK |
| NTV-34 | Kanal: emergency_platform | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | EmergencyPlatformReadinessTest [K]; gercek-yol: Hayır | ACIK |
| NTV-35 | Kanal: emergency_platform | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | LegacySafetyAuthorityTest [K]; gercek-yol: Evet | ACIK |
| NTV-36 | EmergencyNotificationHelper | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | test yok; gercek-yol: Hayır | ACIK |
| NTV-37 | MainActivity | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | countdown_bridge_missing_test; emergency_platform_bridge_test [W; U]; gercek-yol: Kısmen (Dart simülasyonu) | ACIK |
| NTV-38 | MainActivity | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| DL-01 | Derin bağlantı | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | deep_link_test (MainActivity kısmı kaynak) [S]; gercek-yol: Hayır | ACIK |
| DL-02 | Derin bağlantı | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | deep_link_test [S; U]; gercek-yol: Kısmen | ACIK |
| DL-03 | Derin bağlantı | KANITLI | Yok (kanit tam) | `A1-kapandi` | deep_link_test (30 test) [U]; gercek-yol: Evet | KAPANDI |
| DL-04 | Derin bağlantı | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | deep_link_test (kaynak düzeyi) [S]; gercek-yol: Hayır | ACIK |
| DL-05 | Derin bağlantı | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | deep_link_test [U; S]; gercek-yol: Kısmen | ACIK |
| DL-06 | Derin bağlantı | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | deep_link_test [U; S]; gercek-yol: Kısmen | ACIK |
| DL-07 | Derin bağlantı | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | deep_link_test [U; S]; gercek-yol: Kısmen | ACIK |
| DL-08 | Derin bağlantı | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | deep_link_test [U; S]; gercek-yol: Kısmen | ACIK |
| DL-09 | Derin bağlantı | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | deep_link_test [U; S]; gercek-yol: Kısmen | ACIK |
| DL-10 | Derin bağlantı | KISMEN KANITLI | repo-ici davranis testi + emulator + Play/RevenueCat islemi | `A5-play` | deep_link_test [U; S]; gercek-yol: Kısmen | ACIK |
| DL-11 | Derin bağlantı | KISMEN KANITLI | repo-ici davranis testi + emulator + Play/RevenueCat islemi | `A5-play` | deep_link_test [U; S]; gercek-yol: Kısmen | ACIK |
| BLD-01 | Dart bildirimi | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | ScheduledNotificationManifestInstrumentationTest (kurulu paket; manifest blogu kaldirilinca NameNotFoundException ile duser); emulator: 1 dk gecikmeli sahte cagri teslim edildi [I; D]; gercek-yol: Evet; cihaz kaydi 2026-09-23; fiziksel cihaz ACIK | ACIK |
| BLD-02 | Dart bildirimi | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| BLD-03 | Dart bildirimi | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| BLD-04 | Dart bildirimi | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | deep_link_test ("a notification submits through the SAME park") [U]; gercek-yol: Kısmen | ACIK |
| BLD-05 | Dart bildirimi | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | safety_alert_outcome_test; notification_channel_name_test [U]; gercek-yol: Kısmen | ACIK |
| BLD-06 | Durum bildirimi | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | foreground_service_ownership_test; (foreground_service yalnız S) [U; S]; gercek-yol: Kısmen | ACIK |
| CHK-01 | Check-In kurulum | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| CHK-02 | Check-In | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | check_in_service_behavior_matrix_test; check_in_typed_session_test; safety_session_callsite_contract_test [U; S]; gercek-yol: Kısmen (servis gerçek, ekran değil) | ACIK |
| CHK-03 | Check-In | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| CHK-04 | Exact alarm kapısı | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | emergency_timer_release_blockers_test [S]; gercek-yol: Hayır | ACIK |
| CHK-05 | Check-In | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| CHK-06 | Check-In | KISMEN KANITLI | repo-ici davranis testi + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | check_in_service_behavior_matrix_test [U]; gercek-yol: Kısmen | ACIK |
| CHK-07 | Check-In aktif | KISMEN KANITLI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | check_in_service_behavior_matrix_test; time_boundary_safety_test [U]; gercek-yol: Kısmen | ACIK |
| CHK-08 | Check-In aktif | KISMEN KANITLI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | check_in_service_behavior_matrix_test; safety_session_pin_gate_test [U; W]; gercek-yol: Kısmen | ACIK |
| CHK-09 | Check-In aktif | KISMEN KANITLI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | check_in_service_behavior_matrix_test; check_in_dedup_cancel_before_call_test [U]; gercek-yol: Kısmen | ACIK |
| CHK-10 | Güvenlik PIN diyaloğu | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | safety_session_pin_gate_test; safety_session_pin_lockout_test; sensitive_action_pin_gate_test [W; S]; gercek-yol: Evet | ACIK |
| CHK-11 | Check-In | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | safety_alert_outcome_test; check_in_service_behavior_matrix_test [U]; gercek-yol: Kısmen | ACIK |
| CHK-12 | Check-In | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | check_in_service_behavior_matrix_test; check_in_primary_only_contract_test [U]; gercek-yol: Kısmen | ACIK |
| CHK-13 | Check-In | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | check_in_service_behavior_matrix_test; check_in_shared_controller_test [U; S]; gercek-yol: Kısmen | ACIK |
| CHK-14 | Check-In | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| SWK-01 | Güvenli Yürüyüş | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | safe_walk_timer_test [S]; gercek-yol: Hayır | ACIK |
| SWK-02 | Güvenli Yürüyüş | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | check_in_service_behavior_matrix_test; safe_walk_persist_test [U; S]; gercek-yol: Kısmen | ACIK |
| SWK-03 | Güvenli Yürüyüş | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| SWK-04 | Güvenli Yürüyüş | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | safety_alert_outcome_test [U; S]; gercek-yol: Kısmen | ACIK |
| SWK-05 | Güvenli Yürüyüş | KISMEN KANITLI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | check_in_expiry_coordinator_test [U]; gercek-yol: Kısmen | ACIK |
| SWK-06 | Güvenli Yürüyüş | KISMEN KANITLI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | check_in_service_behavior_matrix_test [U]; gercek-yol: Kısmen | ACIK |
| SWK-07 | Güvenli Yürüyüş | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| SWK-08 | Çıkış diyaloğu | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| SWK-09 | Çıkış diyaloğu | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| SWK-10 | Güvenli Yürüyüş | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| SWK-11 | Güvenli Yürüyüş | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | check_in_service_behavior_matrix_test [U]; gercek-yol: Kısmen | ACIK |
| FKC-01 | Sahte çağrı sayfası | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | consent_gate_enforcement_test [S]; gercek-yol: Hayır | ACIK |
| FKC-02 | Sahte çağrı sayfası | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| FKC-03 | Sahte çağrı sayfası | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | BLD-01 kanitlari; emulator: "1 Dakika Sonra" secildi, bildirim geldi [I; D]; gercek-yol: Evet; cihaz kaydi 2026-09-23; fiziksel cihaz ACIK | ACIK |
| FKC-04 | Sahte çağrı sayfası | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| FKC-05 | FakeCallScreen | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | fake_call_consent_order_test [S]; gercek-yol: Hayır | ACIK |
| FKC-06 | FakeCallScreen | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | fake_call_consent_order_test [S]; gercek-yol: Hayır | ACIK |
| FKC-07 | FakeCallScreen | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| FKC-08 | FakeCallScreen | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | fake_call_haptic_source_test [S]; gercek-yol: Hayır | ACIK |
| FKC-09 | FakeCallScreen | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| FKC-10 | FakeCallScreen | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| FKC-11 | FakeCallScreen | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| FKC-12 | Özelleştir sayfası | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | avatar_store_service_test; image_sanitizer_service_test [U]; gercek-yol: Kısmen | ACIK |
| FKC-13 | Özelleştir sayfası | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | fake_call_presets_test [S]; gercek-yol: Hayır | ACIK |
| FKC-14 | Özelleştir sayfası | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| SRN-01 | Siren | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| SRN-02 | Siren | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| SRN-03 | Siren | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| SRN-04 | Siren | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| KSI-01 | Kişiler | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | contacts_provider_add_validation_test [U]; gercek-yol: Kısmen | ACIK |
| KSI-02 | Kişiler | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | consent_gate_enforcement_test; premium_gating_contract_test [S]; gercek-yol: Hayır | ACIK |
| KSI-03 | KVKK kişi bilgi diyaloğu | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| KSI-04 | Ekleme sayfası | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | contacts_picker_native_test [S; U]; gercek-yol: Kısmen | ACIK |
| KSI-05 | Ekleme sayfası | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | contacts_manual_phone_validation_test [U]; gercek-yol: Kısmen (saf fonksiyon) | ACIK |
| KSI-06 | Ekleme sayfası | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | contacts_provider_add_validation_test; contact_service tests [U]; gercek-yol: Kısmen | ACIK |
| KSI-07 | Ekleme sayfası | DOĞRULANMADI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | add_contact_keyboard_visibility_test [S]; gercek-yol: Hayır | ACIK |
| KSI-08 | Kişiler | DOĞRULANMADI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| KSI-09 | Kişiler | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| KSI-10 | Acil seçici | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | contact_service tests [U]; gercek-yol: Kısmen | ACIK |
| KSI-11 | Kişi kartı | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | contacts_card_overflow_test [S]; gercek-yol: Hayır | ACIK |
| KSI-12 | Seçenek sayfası | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | android_intent_service_test [U]; gercek-yol: Kısmen | ACIK |
| KSI-13 | Seçenek sayfası | KISMEN KANITLI | repo-ici davranis testi | `A2-repo` | contact_service tests [U]; gercek-yol: Kısmen | ACIK |
| KSI-14 | Seçenek sayfası | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | contacts_page_test; contact_service_* tests [S; U]; gercek-yol: Kısmen | ACIK |
| KSI-15 | Kişiler | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| KSI-16 | Kişiler | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | contacts_provider_add_validation_test [U]; gercek-yol: Kısmen | ACIK |
| KSI-17 | Kişiler | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | EmergencySessionCoordinatorTest ("immutable target") [K]; gercek-yol: Kısmen | ACIK |
| MAP-01 | Harita | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | map_freshness_widget_test [W]; gercek-yol: Evet (konum mock) | ACIK |
| MAP-02 | Harita | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | map_consent_gate_test [S]; gercek-yol: Hayır | ACIK |
| MAP-03 | Harita | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | permission_denied_test; gps_disabled_test; location_service_test [U]; gercek-yol: Kısmen | ACIK |
| MAP-04 | Harita hata diyaloğu | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| MAP-05 | Harita | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | map_page_ui_test [S]; gercek-yol: Hayır | ACIK |
| MAP-06 | Harita | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator | `A3-emu` | map_osm_cache_contract_test [S]; gercek-yol: Hayır | ACIK |
| MAP-07 | Harita | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | osm_tile_cache_client_test; tile_http_status_handling_test; tile_request_volume_test [U]; gercek-yol: Kısmen | ACIK |
| MAP-08 | Harita | KANITLI | gorsel/manuel kontrol | `A6-gorsel` | map_freshness_widget_test [W]; gercek-yol: Evet | ACIK |
| GCM-01 | Güvenlik geçmişi | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | safety_timeline_unified_test; high_volume_timeline_test [S; W*]; gercek-yol: Hayır | ACIK |
| GCM-02 | Güvenlik geçmişi | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| GCM-03 | Not alt sayfası | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| GCM-04 | Kayıt menüsü | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| GCM-05 | Kayıt menüsü | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | timeline_delete_confirmation_test; timeline_delete_semantics_test [S]; gercek-yol: Hayır | ACIK |
| GCM-06 | Güvenlik geçmişi | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | scroll_restoration_test [W*]; gercek-yol: Kısmen | ACIK |
| PIL-01 | Pil sihirbazı | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | battery_wizard_onboarding_test [S]; gercek-yol: Hayır | ACIK |
| PIL-02 | Pil sihirbazı | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | oem_background_guide_source_test [S]; gercek-yol: Hayır | ACIK |
| PIL-03 | Pil sihirbazı | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| PIL-04 | Pil sihirbazı | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | battery_wizard_onboarding_test [S]; gercek-yol: Hayır | ACIK |
| PIL-05 | Pil sihirbazı | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| PIL-06 | Pil sihirbazı | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| OEM-01 | OEM rehberi | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | oem_background_guide_service_test; turkish_casing_test [U]; gercek-yol: Kısmen | ACIK |
| OEM-02 | OEM rehberi | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | oem_background_guide_service_test [U]; gercek-yol: Kısmen | ACIK |
| OEM-03 | OEM rehberi | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | oem_background_guide_service_test [U]; gercek-yol: Kısmen | ACIK |
| OEM-04 | OEM rehberi | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| BLK-01 | Bildirim kategorileri | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | notification_categories_test (12) [W]; gercek-yol: Evet (kanal mock) | ACIK |
| BLK-02 | Bildirim kategorileri | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | notification_categories_test; notification_settings_row_test [W; S]; gercek-yol: Kısmen | ACIK |
| AYR-01 | Ayarlar | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | user_name_display_test [S]; gercek-yol: Hayır | ACIK |
| AYR-02 | Ayarlar | DOĞRULANMADI | repo-ici davranis testi + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | premium_gating_contract_test [S]; gercek-yol: Hayır | ACIK |
| AYR-03 | Ayarlar | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | notification_settings_row_test [S]; gercek-yol: Hayır | ACIK |
| AYR-04 | Ayarlar | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| AYR-05 | Ayarlar | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | oem_background_guide_source_test [S]; gercek-yol: Hayır | ACIK |
| AYR-06 | Ayarlar | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | oem_background_guide_source_test [S]; gercek-yol: Hayır | ACIK |
| AYR-07 | Ayarlar | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | touch_target_minimum_size_test [S]; gercek-yol: Hayır | ACIK |
| AYR-08 | Ayarlar | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | volume_trigger_service_behavior_test (mutasyonla oldurulen davranis testi); VolumeButtonDetectorTest (4 Robolectric) [U; K]; gercek-yol: Evet (Dart + JVM); cihaz uctan uca dogrulamasi **Asama 6 / R1 (Play+RevenueCat yetkisi)** bekliyor | ACIK |
| AYR-09 | Ayarlar | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| AYR-10 | Ayarlar | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| AYR-11 | Ayarlar | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| AYR-12 | Ayarlar | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| AYR-13 | Ayarlar | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| AYR-14 | Ayarlar | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| AYR-15 | Ayarlar | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator + Play/RevenueCat islemi | `A5-play` | test yok; gercek-yol: Hayır | ACIK |
| AYR-16 | Ayarlar | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| AYR-17 | Detay sayfası | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| AYR-18 | Detay sayfası (gizlilik) | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | sensitive_temp_file_service_test [S]; gercek-yol: Hayır | ACIK |
| PRF-01 | Profil | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | user_name_display_test [S]; gercek-yol: Hayır | ACIK |
| PRF-02 | Profil | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| PRF-03 | Profil | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| PRF-04 | Profil | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| PRF-05 | Profil düzenle | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | edit_profile_screen_test; profile_email_removal_test [S; U]; gercek-yol: Hayır | ACIK |
| PCH-01 | PIN değiştir | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| PCH-02 | PIN değiştir | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| PCH-03 | PIN değiştir | KISMEN KANITLI | repo-ici davranis testi | `A2-repo` | pin_change_validation_test [U]; gercek-yol: Kısmen (yalnız doğrulayıcı) | ACIK |
| PCH-04 | PIN değiştir | KISMEN KANITLI | repo-ici davranis testi | `A2-repo` | pin_verification_service_test [U]; gercek-yol: Kısmen | ACIK |
| SIF-01 | Sıfırlama diyaloğu | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| SIF-02 | Sıfırlama diyaloğu | KISMEN KANITLI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | app_reset_native_prefs_test; contact_service_app_reset_cache_test; sensitive_action_pin_gate_test; app_reset_provider_state_test; safety_session_activity_probe_test (panik oturumu artik engelliyor) [U; W]; gercek-yol: Kısmen | ACIK |
| YSL-01 | Yasal ayarlar | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| YSL-02 | Yasal ayarlar | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| YSL-03 | Yasal ayarlar | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | release_readiness_policy_test [S]; gercek-yol: Hayır | ACIK |
| YSL-04 | Yasal ayarlar | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator | `A3-emu` | phase5 live-legal-url evidence (07-18) [D]; gercek-yol: Kısmen | ACIK |
| YSL-05 | Yasal ayarlar | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| YSL-06 | Rıza yönetimi | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | touch_target_minimum_size_test; D 2026-08-14 [S; D]; gercek-yol: Hayır | ACIK |
| YSL-07 | Geri çekme onayı | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| YSL-08 | Rıza yönetimi | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| YSL-09 | ToS / KVKK salt okunur | DOĞRULANMADI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| YSL-10 | ToS / KVKK | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | test yok; gercek-yol: Hayır | ACIK |
| YSL-11 | Yasal ayarlar | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| YSL-12 | Yasal ayarlar | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| YSL-13 | Yasal ayarlar | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| EXP-01 | Veri dışa aktarma | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| EXP-02 | Veri dışa aktarma | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | sensitive_action_pin_gate_test; profile_email_removal_test; sensitive_temp_file_service_test; legal_data_export_claims_test [W; U; S]; gercek-yol: Kısmen | ACIK |
| DEL-01 | Veri silme | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| DEL-02 | Veri silme | KISMEN KANITLI | repo-ici davranis testi + gorsel/manuel kontrol | `A2-repo` | subscription_deletion_copy_test [W]; gercek-yol: Kısmen (not bileşeni gerçek) | ACIK |
| DEL-03 | Silme onayı | DOĞRULANMADI | repo-ici davranis testi | `A2-repo` | test yok; gercek-yol: Hayır | ACIK |
| DEL-04 | Abonelik notu | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator + Play/RevenueCat islemi | `A5-play` | subscription_deletion_copy_test [W]; gercek-yol: Kısmen (tap yok) | ACIK |
| ABN-01 | Paywall | KISMEN KANITLI | repo-ici davranis testi + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | paywall_render_test [W]; gercek-yol: Evet (sahte provider) | ACIK |
| ABN-02 | Paywall | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + Play/RevenueCat islemi | `A5-play` | test yok; gercek-yol: Hayır | ACIK |
| ABN-03 | Paywall | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | paywall_render_test; revenuecat_subscription_contract_test [W; S]; gercek-yol: Kısmen | ACIK |
| ABN-04 | Paywall | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | paywall_render_test [W]; gercek-yol: Kısmen | ACIK |
| ABN-05 | Paywall | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi | `A5-play` | paywall_render_test [W]; gercek-yol: Kısmen | ACIK |
| ABN-06 | Paywall | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator | `A3-emu` | paywall_render_test (görünürlük) [W]; gercek-yol: Kısmen | ACIK |
| ABN-07 | Abonelik yönetimi | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi | `A5-play` | test yok; gercek-yol: Hayır | ACIK |
| ABN-08 | Abonelik yönetimi | DOĞRULANMADI | repo-ici davranis testi + Play/RevenueCat islemi | `A5-play` | test yok; gercek-yol: Hayır | ACIK |
| ABN-09 | Abonelik yönetimi | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi | `A5-play` | test yok; gercek-yol: Hayır | ACIK |
| ABN-10 | Abonelik yönetimi | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | test yok; gercek-yol: Hayır | ACIK |
| ABN-11 | Yetki modeli | KISMEN KANITLI | repo-ici davranis testi + Play/RevenueCat islemi | `A5-play` | subscription_access_state tests (13 dosya); offline_grace_expiry_test; offline_sos_entitlement_policy_test [U]; gercek-yol: Evet (mantık) | ACIK |
| ABN-12 | Yetki | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi | `A5-play` | revenue_cat_service_test; revenue_cat_evidence_persistence_test [U]; gercek-yol: Hayır | ACIK |
| ABN-13 | Paywall fayda listesi / mağaza metni | URUN KARARI ALINDI (kaldirildi) | Yok (karar uygulandi) | `A1-kapandi` | advancedAutomation enum + matris girdisi + proBenefitKeys maddesi ve iki magaza metni kaldirildi; store_release_docs_test calisma-zamani matris paritesi [S] | KAPANDI |
| PRM-01 | İzin açıklama diyaloğu (prominent disclosure) | DOĞRULANMADI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| PRM-02 | İzin açıklama diyaloğu | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| PRM-03 | İzin reddedildi diyaloğu | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | test yok; gercek-yol: Hayır | ACIK |
| PRM-04 | İzin reddedildi diyaloğu | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | test yok; gercek-yol: Hayır | ACIK |
| HATA-01 | Çapraz | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | panic_arm_policy_test; countdown_dispose_lifecycle_test [U; W]; gercek-yol: Kısmen | ACIK |
| HATA-02 | Çapraz | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | notification_categories_test; EmergencySessionCoordinatorTest [W; K]; gercek-yol: Kısmen | ACIK |
| HATA-03 | Çapraz | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | app_bootstrap_service_test; bootstrap_recovery_screen_test (gercek kurtarma ekrani: yeniden dene, yazarak onaylanan sifirlama, aktif oturum engeli) [U; W]; gercek-yol: Evet (Flutter katmani) | ACIK |
| HATA-04 | Çapraz | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | pin_verification_service_test; sensitive_action_pin_gate_test [U; W]; gercek-yol: Kısmen | ACIK |
| HATA-05 | Çapraz | KISMEN KANITLI | repo-ici davranis testi | `A2-repo` | unified_consent_retry_test; atomic storage tests yok [W]; gercek-yol: Kısmen | ACIK |
| HATA-06 | Çapraz | KISMEN KANITLI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | DeviceProtectedEmergencySessionStoreTest; check_in_service_behavior_matrix_test [K; U]; gercek-yol: Kısmen | ACIK |
| HATA-07 | Çapraz | KANITLI | Yok (kanit tam) | `A1-kapandi` | emergency_platform_typed_contract_test; emergency_readiness_behavior_test [U]; gercek-yol: Evet | KAPANDI |
| HATA-08 | Çapraz | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi + gorsel/manuel kontrol | `A5-play` | connectivity_service_test; offline_sos_entitlement_policy_test; D 2026-08-14 perf (ağ) [U; D]; gercek-yol: Kısmen | ACIK |
| HATA-09 | Çapraz | DIŞ SİSTEM GEREKİYOR | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi | `A5-play` | subscription_provider_access_test [U]; gercek-yol: Kısmen | ACIK |
| HATA-10 | Çapraz | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | gps_disabled_test; permission_denied_test; location_service_test [U]; gercek-yol: Kısmen | ACIK |
| HATA-11 | Çapraz | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | EmergencyPlatformReadinessTest [K]; gercek-yol: Kısmen | ACIK |
| HATA-12 | Çapraz | KISMEN KANITLI | repo-ici davranis testi + emulator + gorsel/manuel kontrol | `A3-emu` | app_reset_provider_state_test (gercek ContactsProvider; silme sonrasi diriltme denemesi ve resetAll hata yolu dahil) [U]; gercek-yol: Evet (Dart katmani); UI dogrulamasi ACIK | ACIK |
| HATA-13 | Çapraz | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz | `A4-fiz` | EmergencySessionCoordinatorTest; D 2026-08-14 [K; D]; gercek-yol: Kısmen | ACIK |
| HATA-14 | Çapraz | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | NTV-09 kanıtları [K; I; D]; gercek-yol: Kısmen — force-stop yarisi ACIK, **Asama 5 / fiziksel cihaz** | ACIK |
| HATA-15 | Çapraz | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi | `A5-play` | local_database_migration_test; data_migration_v2_test; pin_storage_migration_test; medical_data_cleanup_service_test [U]; gercek-yol: Kısmen | ACIK |
| HATA-16 | Çapraz | KISMEN KANITLI | repo-ici davranis testi + emulator + fiziksel cihaz + gorsel/manuel kontrol | `A4-fiz` | NTV-06 kanıtları [K; I]; gercek-yol: Kısmen | ACIK |
| HATA-17 | Çapraz | DOĞRULANMADI | repo-ici davranis testi + emulator + fiziksel cihaz + Play/RevenueCat islemi | `A5-play` | test yok; gercek-yol: Hayır | ACIK |
| HATA-19 | Çapraz | DOĞRULANMADI | repo-ici davranis testi + emulator | `A3-emu` | state_restoration_navigator_precondition_test (replika) [W*]; gercek-yol: Hayır | ACIK |
| HATA-18 | Çapraz | KISMEN KANITLI | repo-ici davranis testi + emulator | `A3-emu` | countdown_bridge_missing_test [W]; gercek-yol: Kısmen | ACIK |
| OLU-01 | LegalDisclaimerScreen | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | test yok; gercek-yol: Hayır | ACIK |
| OLU-02 | ConsentScreen (eski rıza ekranı) | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | edge_to_edge_bottom_inset_test [S]; gercek-yol: Hayır | ACIK |
| OLU-03 | NetworkErrorRetry / showNetworkErrorSnackBar | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | test yok; gercek-yol: Hayır | ACIK |
| OLU-04 | EmptyState | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | test yok; gercek-yol: Hayır | ACIK |
| OLU-05 | LoadingOverlay | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | loading_overlay_semantics_test [W]; gercek-yol: Evet | ACIK |
| OLU-06 | Ana Sayfa | ULAŞILAMAZ / ÖLÜ | Urun karari: sil ya da bagla (kanit degil karar) | `A7-olu` | test yok; gercek-yol: Hayır | ACIK |
