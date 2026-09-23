# KoruBeni — Bağımsız Üretime Hazırlık Denetimi

**Denetim tarihi:** 18 Eylül 2026
**Denetlenen ağaç:** `codex/evidence-remediation-20260911` @ `d2e06db`, çalışma ağacı temiz
**Denetçi:** Bağımsız dış denetim (kodun yazarı değil)
**Araç zinciri:** Flutter 3.38.9 / Dart 3.10.8, macOS arm64 (Darwin 25.6.0), JDK 17, Gradle 8.14
**Bu turda kod değiştirilmedi.** Yalnız bu dosya oluşturuldu.

> ⚠️ **Bu dosyanın kendisi bir test kapısını kırıyor — ve bu beklenen bir durum.**
> `test/release_change_classification_test.dart`, depoda sınıflandırılmamış hiçbir
> yol kalmamasını şart koşuyor (fail-closed). Yeni bir kök dosyası olan
> `AUDIT_REPORT.md` hiçbir kurala uymadığı için test kırmızı oluyor:
> `RELEASE_CHANGE_CLASSIFICATION_FAIL - UNCLASSIFIED_PATH AUDIT_REPORT.md`
> Kanıtladım: dosyayı geçici olarak kaldırdığımda aynı test `All tests passed!`
> diyor, geri koyduğumda tekrar kırılıyor. Yani bu **benim eklediğim dosyanın
> sonucu, mevcut bir kusur değil** — ve aslında kapının doğru çalıştığının
> göstergesi. Düzeltmesi bu turun kapsamı dışında (kod/config değiştirmiyorum);
> tek satırlık çözüm bulgu A-033'te.


---

## 1. Yönetici özeti

KoruBeni teknik olarak alışılmadık derecede olgun bir uygulama. Acil çağrı çekirdeği
Kotlin tarafında yazılmış, durumlar tiplenmiş, testler gerçekten koşuyor ve yeşil
(1820 Dart testi, 94 Kotlin testi), yayın zinciri altı kapısını da yerelde geçiyor,
depoda tek bir gizli anahtar yok. Bu, "bir hafta sonunda yapılmış uygulama" değil.

Ama **yayına hazır değil**, ve bunun üç net sebebi var.

Birincisi: denetlediğim çalışma `main` dalına hiç birleştirilmemiş. 147 commit
yalnız bu dalda duruyor; yayın hattı ise sadece `main` üzerindeki imzalı bir etiketten
derleme yapıyor. Yani bugün bir yayın tetiklense, Ağustos başındaki eski kod çıkar.

İkincisi: uygulamanın manşet özelliği olan panik/SOS akışı ücretli aboneliğin
arkasında ve **o abonelik zinciri bugüne kadar bir kez bile gerçek bir satın alma
yapmamış.** Ödeme, geri yükleme, iptal ve deneme geçişlerinin hiçbiri hiçbir cihazda
görülmemiş. Para ödeyen bir kullanıcının SOS düğmesine basabildiğini kimse
göstermedi.

Üçüncüsü: ekibin kendi emülatör deneyi, geri sayım sırasında uygulama zorla
kapatılırsa (force-stop) aramanın gitmediğini, **kullanıcı uygulamayı ne zaman
açarsa açsın — bir dakika sonra da, günler sonra da — süresi geçmiş o oturumun
sormadan hemen aranacağını** ölçmüş. Bu düzeltilmemiş; kayıtlarda "karar bekliyor"
olarak duruyor.

En büyük üç risk sırayla: (1) istenmeyen, günler sonra gelen otomatik acil arama,
(2) hiç denenmemiş ödeme zinciri arkasındaki ana özellik, (3) yayın hattının
denetlenen kodu görmüyor olması.

Kalan iş kabaca şu: bir hafta içinde dalı birleştirip yaş sınırı kararını vermek,
ardından 1–2 hafta Play Console formları + gerçek cihaz QA + sandbox satın alma
turu. Kod tarafında yapılacak iş az; dışarıda yapılacak iş çok.

---

## 2. Sonuç kartı

| Metrik | Değer |
|---|---|
| **Özellik tamamlanma** | **%88** (34 kapsam-içi özellik: 26 `Tam`, 8 `Kısmi`, 0 `Stub/Yok`) |
| **Yayın hazırlığı** | **%60,0** (ağırlıklı puan 600/1000) |
| **Karar** | **Yayına hazır değil** |

Karar gerekçesi: Kapı 3 kapalı. Bu tek başına, yüzdeden bağımsız olarak kararı belirler.
Ayrıca üç Blocker açık ve yayın hazırlığı %75 eşiğinin çok altında.

### Kapı tablosu (go / no-go)

| # | Kapı | Sonuç | Kanıt |
|---|---|---|---|
| 1 | Release build her hedef platformda derleniyor | **Evet** | `./scripts/verify_release.sh` → `EXIT=0`, 6/6 kapı: analyze temiz, 1820 test yeşil, imzalı AAB üretildi, Android lint + Kotlin unit + instrumentation derlemesi yeşil, 16 KB hizalama 10/10 kütüphane. Hedef yalnız Android; `ios/` dizini yok. |
| 2 | Kaynak kodda ve derlenmiş pakette gizli anahtar yok | **Evet** | `scripts/scan_release_secrets.py --require-clean` → `RELEASE_SECRET_SCAN_PASS`, 951 dosya, 0 bulgu. Derlenen AAB'nin `base/` (cihaza giden kısım) ayrıca tarandı: temiz. Tek eşleşme `BUNDLE-METADATA/.../libflutter.so.dbg` içindeki `ghp_kEPKN24SkRasterPipelineContexts...` — bu bir C++ sembol adı, yanlış pozitif, ve Play bu metadatayı cihaza göndermez. |
| 3 | Tüm ana akışlar uçtan uca gerçek veriyle çalışıyor (mock yok) | **HAYIR** | Panik/SOS, Güvenli Yürüyüş ve Check-In `FeatureAccessLevel.pro` ile kapalı (`lib/core/constants/feature_access_matrix.dart:97-120`). Hiçbir satın alma, geri yükleme veya deneme geçişi hiç gözlenmemiş (`EXTERNAL_LAUNCH_BLOCKERS.md` E1: "No purchase, restore, trial, upgrade, downgrade, pause or cancel transition has ever been observed against this build"). |
| 4 | Backend yetkilendirme kuralları kapalı ve doğru | **Evet (konu dışı)** | Geliştirici backend'i yok; `lib/core/constants/api_constants.dart` bunu açıkça söylüyor. Herkese açık yazma yüzeyi mevcut değil. |
| 5 | Hesap varsa kimlik akışları çalışıyor, hassas veri güvenli | **Evet** | Hesap yok. PIN PBKDF2-HMAC-SHA256 100.000 iterasyon + rastgele salt ile saklanıyor (`lib/core/security/pin_hasher.dart:29,37-55`), sabit-zamanlı karşılaştırma. Kişiler `flutter_secure_storage`'da. |
| 6 | Ana akışlarda bilinen crash yok; soğuk açılış temiz | **Evet, ama uyarılı** | Bilinen crash yok; başlangıç sırası sözleşme testiyle sabitli (`test/main_startup_init_order_test.dart`). ANCAK crash olmayan ama en az onun kadar ciddi bir davranış açık: A-001 (istenmeyen otomatik arama). Soğuk açılış süresi bu denetimde ölçülmedi. |
| 7 | Gizlilik politikası mevcut; uygulama içi veri silme var | **Evet** | 4 yasal URL de canlı, HTTP 200 (18.09.2026 tarihinde `curl` ile doğrulandı). Uygulama içi silme: `lib/screens/settings_legal/data_deletion_screen.dart` (dialog + PIN + tipli native wipe). |
| 8 | İzinler ile kullanım eşleşiyor; usage description'lar tam | **Evet** | Manifest'te 11 izin var, hepsinin karşılığı kodda mevcut. `READ_CONTACTS` `tools:node="remove"` ile kaldırılmış, `RECORD_AUDIO` ve `ACCESS_BACKGROUND_LOCATION` yok, foreground service yok. iOS yok, usage description konu dışı. |

---

## 3. Alan puan tablosu

| # | Alan | Puan /10 | Ağırlık | Katkı | Tek cümlelik gerekçe |
|---|---|---|---|---|---|
| 1 | Derleme ve proje sağlığı | 8 | 8 | 64 | Zincir 6/6 yeşil ve kilit dosyaları tam, ama 128 paket geride ve birkaç majör sürüm atlanmış. |
| 2 | Fonksiyonel bütünlük | 5 | 15 | 75 | Özellikler kaynak düzeyinde büyük ölçüde tam, ama manşet özelliğin erişim yolu kanıtlanamıyor (A-003'ün fonksiyonel sonucu = Critical → tavan 5). |
| 3 | Hata yönetimi, uç durumlar, çevrimdışı | 3 | 8 | 24 | Tipli sonuç modellemesi örnek niteliğinde, fakat force-stop sonrası yaş sınırsız otomatik arama bir Blocker (tavan 3). |
| 4 | Güvenlik | 8 | 12 | 96 | Zorlama (duress) modeli tutarlı uygulanmış, PIN hash'li, yüzey dar; kalan boşluklar bilinçli kabul edilmiş kalıntı riskler. |
| 5 | Gizlilik, izinler, uyumluluk | 6 | 7 | 42 | İzin-kullanım eşleşmesi temiz ve KVKK akışı gerçek, ama canlı sözleşme sürümü uygulamadakiyle uyuşmuyor ve yurt dışı aktarım hukukçu onayı almamış. |
| 6 | Arayüz ve kullanıcı deneyimi | 7 | 10 | 70 | Tema merkezi ve erişim durumları düşünülmüş, ama 345 satır içi `fontSize` borcu duruyor ve görsel davranış bu turda çalıştırılmadı. |
| 7 | Erişilebilirlik ve yerelleştirme | 7 | 5 | 35 | Semantik etiketler ve dokunma hedefleri testle zorlanıyor, üç renk çifti AA altında kabul edilmiş, gerçek cihaz TalkBack turu açık. |
| 8 | Performans ve kaynak kullanımı | 6 | 7 | 42 | Sevkiyat yolu ağsız ve sınırlı, ancak hiçbir çalışma zamanı ölçümü bu turda yapılmadı ve pakette gereksiz web/iOS varlıkları var. |
| 9 | Test ve kalite güvence | 8 | 8 | 64 | 1820 + 94 test gerçekten koşuyor, mutasyon ve coverage kapıları var; 314 test dosyasının 205'i kaynak metni okuyor, bu davranış kanıtı değil. |
| 10 | Mağaza ve yayın hazırlığı | **3** | 8 | 24 | İmzalama, provenance ve 16 KB tarafı örnek, ama kod yayın dalında bile değil (A-002 = Blocker → tavan 3). |
| 11 | Kod kalitesi, mimari, bakım | 7 | 7 | 49 | Katmanlar tutarlı ve `TODO` sıfır, ama 17 dosya ölü ve kök dizindeki 20+ rapor yeni geliştiriciyi boğuyor. |
| 12 | Backend, veri ve kimlik | **3** | 5 | 15 | Şema göçleri yalnız-ekleme ve testli, kimlik yok; faturalandırma yaşam döngüsü hiç işlem görmemiş (A-003 = Blocker → tavan 3). |
| | **TOPLAM** | | **100** | **600** | **Yayın hazırlığı = 600 / 10 = %60,0** |

**Blocker'ların alanlara dağılımı (tavan kuralının nasıl uygulandığı):**
A-001 → alan 3 (uç durumlar), A-002 → alan 10 (yayın hazırlığı), A-003 → alan 12
(faturalandırma yaşam döngüsü). Üçü de kendi alanını 3'e sabitliyor. A-003'ün
fonksiyonel sonucu alan 2'ye Critical olarak yansıyor ve orayı 5'e sabitliyor;
aynı bulguyu iki alanda birden Blocker saymadım.

---

## 4. Uygulama envanteri

**Teknoloji:** Flutter 3.38.9 (Dart 3.10.8) + Kotlin 2.1.0 / AGP 8.9.1, Android tek platform
(`minSdk 29`, `targetSdk 36`, `compileSdk 36`, yalnız `arm64-v8a` üretimde).
**Mimari:** ~90 odaklı servis `lib/core/services/` altında; sunum katmanı `provider`
(ChangeNotifier) + `get_it`. BLoC/Riverpod/GoRouter/freezed yok.
**Kod hacmi:** 177 Dart dosyası / 40.320 satır; 25 Kotlin dosyası / 4.019 satır.
**Navigasyon:** Tek kök route (`AppRoot`), hedefler route değil **state** olarak değişiyor
(`lib/screens/app_root.dart:36-63`); 4 sekmeli `IndexedStack` + push edilen ekranlar.
**Ortamlar:** `ENV=dev` (varsayılan) / `production` / `ci_smoke`; `play` ve `smoke` gradle flavor'ı.

### 4.1 Ekran ve özellik durumu

Durum ölçütü: `Tam` = arayüzden kalıcı kata ve geri arayüze kadar yol kodda ve testte
bütün; `Kısmi` = yol var ama bir ucu doğrulanmamış veya bilinen açık defekti var.

| # | Ekran / Özellik | Durum | Kanıt | Not |
|---|---|---|---|---|
| 1 | Splash + başlangıç kararı | Tam | `lib/screens/splash_screen.dart:167-290` | Rıza → PIN → onboarding → ana sıralaması; PIN okunamazsa "kilitli" sayılıyor |
| 2 | Birleşik rıza (aydınlatma + açık rıza + 18+) | Tam | `lib/screens/legal/unified_consent_screen.dart:75,421,546` | Her yazma commit doğrulaması istiyor |
| 3 | Onboarding (4 sayfa + zorunlu kişi adımı) | Tam | `lib/screens/onboarding_screen.dart:72-111`, `onboarding/onboarding_contact_step.dart` | Aranabilir kişi olmadan `prefOnboardingDone` yazılmıyor |
| 4 | PIN kurulumu (zayıf PIN reddi) | Tam | `lib/screens/pin_setup_screen.dart:62`, `lib/core/utils/validators.dart:5-39` | 16 yasaklı kalıp + artan/azalan diziler |
| 5 | Uygulama kilidi + kilitlenme sayacı | Tam | `lib/screens/app_unlock_screen.dart:71-188`, `lib/core/services/pin_lockout_service.dart:47-58` | 5 hatada 30 sn, katlanarak 15 dk tavanı |
| 6 | Arka plan sonrası yeniden kilit (120 sn) | Tam | `lib/core/services/app_lifecycle_handler.dart:26,38` | `inactive` dönüş yolunda sayacı sıfırlama hatası düzeltilmiş |
| 7 | "PIN'imi unuttum" → tam yerel silme | Tam | `lib/screens/app_unlock_screen.dart:376-393` | Aktif güvenlik oturumu varsa fail-closed engelleniyor |
| 8 | Ana ekran hazırlık kartı | Tam | `lib/core/widgets/readiness_card.dart:82-117` | Kişi, arama izni, arka plan, konum, rehber çipleri |
| 9 | **Panik butonu (3 sn basılı tut / erişilebilir dokunuş)** | **Kısmi** | `lib/widgets/panic_button.dart:113-286,324-387` | Pro kapısı hiç işlem görmemiş (A-003); erişilebilirlik yolu tek dokunuş + onay |
| 10 | Geri sayım + PIN ile iptal | Tam | `lib/screens/countdown_screen.dart:227-284,559-606` | `canPop: false`, iptal yetkisi yalnız PIN |
| 11 | **Native acil oturum çekirdeği (arm/cancel/dispatch/reconcile)** | **Kısmi** | `EmergencySessionCoordinator.kt:24-172,248-407` | Doze'da emülatörde geçti (78 ms gecikme) ama A-001 açık |
| 12 | Acil arama sonuç ekranı + defter | Tam | `lib/screens/emergency_call_screen.dart`, `lib/core/services/emergency_result_policy.dart` | Üç ayrı dürüst iddia: mutlak / belirsiz / kısmi |
| 13 | Sahte çağrı (anında + gecikmeli) | Tam | `lib/screens/fake_call_screen.dart:57-275` | Zil sesi hatası ayrıca durumlanıyor |
| 14 | Siren | Tam | `lib/widgets/siren_dialog.dart:113-151` | Alarm ses seviyesi yükseltilip `dispose`'da geri veriliyor |
| 15 | Acil kişiler (manuel + sistem seçici, birincil seçimi, 5 sınırı) | Tam | `lib/screens/contacts_page.dart:926-1032`, `MainActivity.kt:399-458` | `READ_CONTACTS` izni yok, `ACTION_PICK` kullanılıyor |
| 16 | Harita / konum oturumu | Tam | `lib/screens/map_page.dart:106-262,504-523` | İzin reddi üç ayrı duruma ayrılmış, OSM atıfı görünür |
| 17 | **Güvenli Yürüyüş** | **Kısmi** | `lib/screens/safe_walk_screen.dart:95-195`, `check_in_service.dart` | Pro; gerçek cihazda hiç koşulmamış |
| 18 | **Check-In** | **Kısmi** | `lib/screens/check_in_screen.dart:176-232,362-365` | Pro; 15/30/60/120 dk + 60 sn grace |
| 19 | **Ses tuşu tetikleyici** | **Kısmi** | `VolumeButtonDetector.kt:63-109`, `lib/core/services/volume_trigger_service.dart` | Pro; yalnız uygulama ön plandayken çalışır |
| 20 | Hızlı Ayarlar kutucuğu | Tam | `quickaccess/PanicTileService.kt:19-53` | `BIND_QUICK_SETTINGS_TILE` ile korunuyor |
| 21 | Ana ekran widget'ı | Tam | `quickaccess/PanicWidgetProvider.kt:20-44` | `exported="false"`, IMMUTABLE PendingIntent |
| 22 | Derin bağlantılar (`korubeni://open/...`) | Tam | `lib/core/navigation/app_destination.dart`, `MainActivity.kt:98-105` | İzin listesi + 512 karakter sınırı, kapılardan sonra tüketiliyor |
| 23 | Güvenlik geçmişi + plan notu | Tam | `lib/screens/safety_timeline_screen.dart:73-151` | Silme artık onay istiyor (CHANGELOG) |
| 24 | Prova / Test Modu (ücretsiz) | Tam | `lib/core/constants/feature_access_matrix.dart:82-87` | Gerçek arama yapmıyor, bilinçli ücretsiz |
| 25 | Pil optimizasyonu sihirbazı | Tam | `lib/screens/battery_optimization_wizard.dart:38-65` | Erteleme + "bir daha gösterme" sayacı |
| 26 | Üretici arka plan rehberi | Tam | `lib/core/services/oem_background_guide_service.dart`, `EmergencyPlatformHandler.kt:270-299` | Xiaomi/Samsung/Huawei/OnePlus hedefleri |
| 27 | Bildirim kategorileri ayarları | Tam | `lib/screens/settings_notifications/notification_categories_screen.dart` | Android kanal ayarına yönlendiriyor |
| 28 | Ayarlar (ses, ses tuşu, PIN değiştir) | Tam | `lib/screens/settings_page.dart:122-353` | |
| 29 | Yasal ayarlar + rıza yönetimi | Tam | `lib/screens/settings_legal/legal_settings_screen.dart`, `lib/services/consent_manager.dart:125-155` | Rıza geri çekme akışı var |
| 30 | Veri dışa aktarma | Tam | `lib/core/services/user_data_export_service.dart:21-114` | PIN kapısı arkasında, geçici dosya temizliği var |
| 31 | Veri silme (yerel wipe) | Tam | `lib/core/services/app_reset_service.dart:51-110` | Kimlik deposu EN SON siliniyor — kısmi hata PIN'i koruyor |
| 32 | **Profil düzenleme** | **Kısmi** | `lib/screens/edit_profile_screen.dart:115-124` | Yalnız ad alanı var; `profile_email` saklanıyor ve dışa aktarılıyor ama girilemiyor |
| 33 | **Paywall (aylık/yıllık, geri yükleme)** | **Kısmi** | `lib/screens/subscription/paywall_screen.dart:43-143,332-392` | Hiç işlem görmemiş |
| 34 | **Abonelik yönetimi** | **Kısmi** | `lib/screens/subscription/subscription_management_screen.dart:29-102` | Hiç işlem görmemiş |

**Kapsam dışı (bilinçli kararlar, yüzdeye dahil edilmedi):** açık tema silinmiş (D-1),
iOS hedefi yok (`ios/` dizini mevcut değil), İngilizce çalışma zamanı kapalı
(`main.dart:214` yalnız `tr_TR`; `en-US.json` parite referansı olarak duruyor).

### 4.2 Bağımlılıklar

29 doğrudan bağımlılığın 28'i kodda gerçekten kullanılıyor. Tek istisna
`cupertino_icons` (0 dosyada import), ki buna rağmen 252 KB font olarak pakete giriyor.

`flutter pub outdated`: **128 paket geride.** Majör atlamalar:
`flutter_local_notifications` 19.5→22.3, `permission_handler` 11.4→13.0,
`geolocator` 13.0→14.0, `flutter_map` 7.0→8.3, `get_it` 7.7→9.2,
`package_info_plus` 8.3→10.2, `connectivity_plus` 6.1→7.3, `battery_plus` 6.2→7.1,
`flutter_secure_storage` 10.0→11.2, `mocktail` 0.3→1.0.5.

Zafiyet taraması temiz: `scripts/audit_dependencies_osv.sh` → `OSV_EVIDENCE_PASS`,
197 pub + 203 maven sorgusu, **0 bulgu**. Lisans tarafı: SBOM 400 bileşen üretiyor,
politika kapısı yeşil, ama insan lisans incelemesi **0/400**.

### 4.3 Test, CI ve doküman

| Alan | Durum |
|---|---|
| Dart testleri | 314 dosya, **1820 test, hepsi yeşil** (`flutter test --no-pub` → `EXIT=0`) |
| Kotlin unit testleri | 94 `@Test` (15 dosya), Robolectric + mockito-kotlin |
| Instrumentation | 8 `@Test` (4 dosya), CI'da API 29/34/36 emülatör matrisi + gecelik 29–36 |
| Assert içermeyen test | **0** (314 dosyanın tamamı `expect`/`verify` içeriyor) |
| `skip:` kullanımı | **0** |
| Kaynak-metni testleri | 314 dosyanın **205'i** `lib` kaynağını metin olarak okuyor — davranış kanıtı değil |
| Kritik coverage kapısı | 7 dosyada ≥%90 zorunlu (`scripts/verify_critical_coverage.dart:4-12`) |
| Mutasyon kapısı | 6 zorunlu güvenlik mutantı öldürülmeli |
| CI | `ci.yml` (analyze, test+coverage, OSV, sır taraması, Kotlin unit, mutasyon, instrumentation derleme, smoke AAB), `codeql.yml` (java-kotlin + actions; **Dart kapsam dışı, açıkça notlanmış**), `nightly-android.yml`, `release.yml`, `pages.yml` |
| E2E / integration_test | **Yok** (paket bağımlılığı yok) |
| Golden test | **Yok** (depo kuralıyla yasaklı) |

---

## 5. Bulgular

### 5.1 BLOCKER

```
[A-001] [Blocker] [Güvenilirlik / Ürün] Vadesi geçmiş panik oturumu, uygulama
açıldığında yaş sınırı olmadan ve sormadan otomatik aranıyor

Konum: android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/
       EmergencySessionCoordinator.kt:522-524

Kanıt:
  LifecycleState.ARMED -> {
      if (wallClockMs() >= envelope.finalDeadlineMs) {
          claimAndDispatch(envelope.token)
      } else { ... }

  reconcile() bu dalda hiçbir yaş sınırı uygulamıyor. reconcileAfterBoot() ve
  reconcileCurrentBoot() aynı fonksiyonu çağırıyor; BootCompletedReceiver
  LOCKED_BOOT_COMPLETED / BOOT_COMPLETED / MY_PACKAGE_REPLACED / USER_UNLOCKED
  olaylarının hepsinde bunu tetikliyor (BootCompletedReceiver.kt:18-26).

  Projenin kendi cihaz kaydı (docs/audit/device-verification-2026-09-13-force-stop.md,
  Android 17 / API 37 emülatörü, commit 6c1467c):
    "A — kullanıcı uygulamayı açar | Sistem PACKAGE_UNSTOPPED yayınladı ve pakete
     LOCKED_BOOT_COMPLETED gönderdi. BootCompletedReceiver Flutter yüklenmeden
     çalıştı (23:33:42.792), Telecom arama kaydı 82 ms sonra oluştu.
     Açılışta sormadan, yaş sınırı olmadan otomatik arama."
  ve docs/audit/remediation-20260911.md N-08 satırı:
    "HIGH (unrequested emergency call on app open; silent miss while stopped)
     -- decision required, not fixed. Open."

Etki: Kullanıcı bir panik geri sayımı başlatır, telefon zorla kapatılır veya yeniden
başlatılır, hiçbir arama gitmez ve kullanıcıya hiçbir şey söylenmez. Sonra kullanıcı
uygulamayı açtığında — aynı gün ya da bir hafta sonra — uygulama o eski oturumu
GERÇEK bir acil durummuş gibi acil kişiyi arar. Acil kişi, ortada bir olay yokken
"acil durum" araması alır. Bir güvenlik ürününde bu, kullanıcının o kişiye olan
güvenini bir kerede bitiren türden bir hatadır ve tekrarında acil kişinin uygulamayı
ciddiye almamasına yol açar. Ayrıca istenmeyen giden arama geri alınamaz bir yan
etkidir.

Nasıl görülür:
  1. Pro erişimi olan bir cihazda acil kişiyi ikinci bir test telefonu yap.
  2. Panik butonunu basılı tutup bırak; geri sayım başlasın.
  3. Geri sayım biterken/bitmeden `adb shell am force-stop com.poyrazoncel.korubeni`
     (veya cihazı kapat).
  4. Süreyi geçir (1 dakika yeter, ama günler de olur).
  5. Uygulamayı ana ekrandan aç. İkinci telefon çalıyor.

Önerilen çözüm: `reconcile()` içinde ARMED→dispatch dalına bir yaş sınırı koy
(ör. `wallClockMs() - envelope.finalDeadlineMs > MAX_OVERDUE_MS` ise dispatch etme).
Sınırı aşan oturum aranmak yerine **kullanıcıya gösterilsin**: yüksek öncelikli bir
bildirim ("geri sayımınız tamamlanamadı, aramak ister misiniz?") + geçmişe dürüst bir
kayıt. Sınır değeri bir ürün kararıdır; öneri 2–5 dakika. Karar verilmeden kod
değiştirilmemeli, çünkü tersi hata (kaçırılan arama) da gerçek bir maliyet — bu
tam olarak sahibinin vereceği bir denge kararı.

Not — derecelendirme farkı: Proje bunu kendi kaydında HIGH olarak işaretlemiş.
Ben Blocker'a yükselttim, çünkü (a) sonucu geri alınamaz bir dış yan etki
(gerçek bir kişiye giden arama), (b) kullanıcının onayı hiç alınmıyor, (c) ölçülmüş
ve tekrarlanabilir, (d) bir güvenlik ürününde acil kişinin uygulamaya güvenini
bitirir. Bu, projenin kendi CLAUDE.md kuralıyla da tutarlı: "acil çağrıyı engelleyen
veya geciktiren her şey tanımı gereği CRITICAL" — burada ters yönde, istenmeyen bir
çağrı üretiliyor ki sonucu aynı derecede ciddi.

Efor: M (yarım–1 gün, karar verildikten sonra; testi ve cihaz doğrulaması dâhil)
Durum: Doğrulandı (kod okundu + projenin kendi emülatör kanıtı)
```

```
[A-002] [Blocker] [Yayın] Denetlenen kod yayın hattında değil: dal `main`'e
birleştirilmemiş, yayın yalnız `main` üzerindeki imzalı etiketten derleniyor

Konum: git durumu + .github/workflows/release.yml

Kanıt:
  $ git log --oneline main..HEAD | wc -l
  147
  $ git log -1 main --format='%h %ad %s' --date=short
  d0693eb 2026-08-03 fix(safety): cozulmus entitlement durumunu bayat anchor'dan koru
  $ git log -1 HEAD --format='%h %ad' --date=short
  d2e06db 2026-09-13

  release.yml (Verify signed annotated tag and main ancestry):
    git merge-base --is-ancestor "$TAG_COMMIT" origin/main || {
      echo "::error title=Release commit is not on main::Refusing to build a
            production artifact from an unmerged commit."
      exit 1; }

Etki: Bugün bir `v*.*.*` etiketi atılsa, ya CI reddeder (etiket `main`'in atası
değil) ya da 3 Ağustos tarihli eski kod yayınlanır. Bu denetimin incelediği her
düzeltme — N-01…N-08 serisi, F01–F17 remediation'ı, BoundedFrameWait, v4.0.0
sözleşme metni — yayına çıkmaz. Ayrıca A-004 (canlı sözleşme sürümü uyuşmazlığı)
doğrudan bunun sonucudur: `pages.yml` de `main`'den yayınlıyor.

Nasıl görülür: `git log --oneline main..HEAD | wc -l` → 147.

Önerilen çözüm: Dalı `main`'e birleştir. Depo kuralı her commit'te yeşil test
istiyor; 147 commit için `git rebase --exec` ile commit başı doğrulama pahalı olur,
pratik yol tek bir gözden geçirilmiş merge + merge sonrası tam `verify_release.sh`.
Birleştirmeden önce A-001 kararının verilmiş olması gerekir, yoksa Blocker'ı yayın
hattına taşımış olursunuz.

Efor: L (1+ gün — birleştirme + tam doğrulama + A-001 kararı)
Durum: Doğrulandı
```

```
[A-003] [Blocker] [Fonksiyonel / Gelir] Manşet özellik (panik/SOS) hiç işlem
görmemiş bir faturalandırma zincirinin arkasında

Konum: lib/core/constants/feature_access_matrix.dart:97-120
       EXTERNAL_LAUNCH_BLOCKERS.md E1

Kanıt:
  PremiumFeature.panic: FeatureAccessEntry(
      access: FeatureAccessLevel.pro, ...)
  PremiumFeature.safeWalk: ... FeatureAccessLevel.pro
  PremiumFeature.checkIn:  ... FeatureAccessLevel.pro
  PremiumFeature.volumeTrigger: ... FeatureAccessLevel.pro

  EXTERNAL_LAUNCH_BLOCKERS.md E1:
    "No purchase, restore, trial, upgrade, downgrade, pause or cancel transition
     has ever been observed against this build — the in-repo tests prove the
     *gating logic*, never the *store transaction*."
    "Launch impact: **Blocking.** Shipping an unexercised billing path on a paid
     safety feature risks charging users who then cannot arm SOS."

Etki: Para ödeyen bir kullanıcının SOS düğmesine basabildiği gösterilmedi.
RevenueCat entitlement kimliğinin (`KoruBeni Pro`, revenue_cat_service.dart:29)
dashboard'daki tanımla harfi harfine eşleştiği, aylık/yıllık paketlerin Play
ürünleriyle eşlendiği, satın alma sonrası `evaluateEntitlement`'ın `authorized`
döndüğü — hiçbiri doğrulanmadı. Yanlış eşleşen tek bir kimlik, ödeme yapan
kullanıcıyı panik butonundan tamamen mahrum bırakır ve bunu ancak kullanıcı
acil bir anda fark eder.

Nasıl görülür: Kapı 3 ile aynı. Play Console'da ürün yok, RevenueCat'te
doğrulanmış eşleme kaydı yok, `docs/qa/` altında satın alma kanıtı yok.

Önerilen çözüm: `store/BILLING_RELEASE_CHECKLIST.md` uçtan uca koşulmalı:
dahili test track'i + lisans testçisi hesabı + sandbox anahtarıyla derlenmiş AAB
üzerinde aylık satın alma, yıllık satın alma, iptal, ikinci cihazda geri yükleme,
deneme başlatma, deneme bitişi, yükseltme, düşürme, duraklatma ve reddedilen
kartla ödeme hatası. Her geçişte RevenueCat customer-info yükü + ekran görüntüsü
`docs/qa/` altına.

Efor: L (1+ gün; Play Console ve RevenueCat kurulumu dâhil)
Durum: Doğrulandı (kapının varlığı kodda; işlem görmemişliği projenin kendi kaydında)
```

### 5.2 HIGH

```
[A-004] [High] [Uyum / Hukuk] Canlı Kullanım Şartları sayfası 3.1.0 yayınlıyor;
bu daldaki uygulama 4.0.0'ı gösterip kullanıcıya kabul ettiriyor

Konum: lib/constants/legal_texts.dart:9
       https://poyrazoncel34-netizen.github.io/guvenlik_app/kullanim_sartlari.html

Kanıt (18.09.2026, curl):
  privacy_policy.html      200  21004 bayt  Sürüm 3.4.0  19 Temmuz 2026
  kullanim_sartlari.html   200  12678 bayt  Sürüm 3.1.0  21 Mayıs 2026   <-- ESKİ
  data_deletion.html       200   1469 bayt
  aydinlatma.html          200  17777 bayt  Sürüm 3.4.0  19 Temmuz 2026

  Depodaki ayna (bu dal):  store/kullanim_sartlari.html → "Sürüm 4.0.0"
  Kod:                     legal_texts.dart:9 → termsVersion = '4.0.0'
  main dalı:               termsVersion = '3.1.0'  (canlı sayfayla tutarlı)

Etki: Bu dal yayınlanırsa kullanıcı uygulama içinde "Sürüm 4.0.0" metnini kabul
eder, ama uygulamanın ve Play listelemesinin gösterdiği URL 3.1.0'ı sunar. Hangi
metnin bağladığı tartışmalı hâle gelir; tüketici mevzuatı açısından kabul kaydının
ispat değeri zayıflar. KVKK aydınlatma tarafında sürümler tutuyor (3.4.0), sorun
yalnız Kullanım Şartları'nda.

Nasıl görülür: Tarayıcıda canlı URL'yi aç, "Sürüm" satırına bak (3.1.0), sonra
uygulamada Ayarlar → Yasal → Kullanım Şartları'na bak (4.0.0).

Önerilen çözüm: A-002 birleştirmesi bunu kendiliğinden kapatır — `pages.yml`
`.gh-pages-publish/**` değişince `main`'den yayınlıyor ve bu daldaki ayna zaten
4.0.0. Birleştirme sonrası canlı URL'yi tekrar doğrulayın. Elle HTML düzenlemeyin;
sürüm değişiklikleri yalnız `scripts/bump_legal.sh` üzerinden gider.

Efor: S (<2 saat, A-002'den sonra)
Durum: Doğrulandı
```

```
[A-005] [High] [Güvenilirlik] Native acil kanalının kurulum hatası sessizce
yutuluyor; uygulama güvenlik çekirdeği köprüsü olmadan normal görünerek çalışıyor

Konum: android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt:191-199
       ve 365-368

Kanıt:
  try {
      MethodChannel(messenger, EmergencyChannels.METHOD)
          .setMethodCallHandler(emergencyPlatformHandler)
      EventChannel(messenger, EmergencyChannels.EVENTS)
          .setStreamHandler(EmergencyEventStreamHandler())
  } catch (_: Exception) {
      android.util.Log.e("MainActivity", "EMERGENCY_PLATFORM_CONFIG_FAILED")
  }
  ...
  } catch (_: Exception) {
      android.util.Log.e("MainActivity", "FLUTTER_ENGINE_CONFIG_FAILED")
      // Don't crash - let Flutter handle it
  }

  Dart tarafı bunu fark edemez: EmergencyPlatformService.isSupported yalnız
  platformu kontrol ediyor (emergency_platform_service.dart:53-55), kanalın kayıtlı
  olup olmadığını değil. Kanal yoksa armEmergencySession → MissingPluginException
  → `on Exception` → ArmUnknown('unexpectedError') → PanicArmPolicy →
  uncertainNativeCountdown → geri sayım BAŞLIYOR.

Etki: Bu durumda kullanıcı normal bir geri sayım görür ve korunduğunu sanır, ama
native AlarmManager oturumu hiç kurulmamıştır. Ekran kapalıysa ve cihaz Doze'a
girerse Dart zamanlayıcısı tetiklenmeyebilir ve **hiçbir şey olmaz**. Sevkiyat
anında akış görünür bir hataya düşüyor (bu iyi), ama kullanıcı arm anında Doze
güvenlik ağının olmadığını hiçbir yerde göremiyor. Hata yalnız logcat'e yazılıyor,
ki release'de kullanıcı onu okuyamaz.

Nasıl görülür: Kod okumasıyla doğrulandı; çalışma zamanında tetiklemek için kanal
kurulumunun başarısız olması gerekir (nadir). `EMERGENCY_PLATFORM_CONFIG_FAILED`
logcat satırı tek göstergedir.

Önerilen çözüm: Kanal kurulumu başarısızsa bunu Dart'ın okuyabileceği kalıcı bir
duruma yaz (ör. `EmergencyPrefs` içinde bir bayrak) ve `EmergencyReadinessService`
bunu "kritik hazır değil" olarak raporlasın; hazırlık kartı kullanıcıya göstersin.
Alternatif olarak `getEmergencyCapabilities` çağrısının hiç cevap vermemesini
`ArmUnknown` yerine açık bir "platform köprüsü yok" durumuna ayırın.

Efor: M (yarım–1 gün)
Durum: Doğrulandı (kod okumasıyla; çalışma zamanı tetiklenmesi Doğrulanamadı)
```

```
[A-006] [High] [Mağaza] Play inceleme reddi riski üç faktörün üst üste binmesinden
yüksek, ve azaltıcı adımların hiçbiri tamamlanmamış

Konum: store/PLAY_REVIEWER_ACCESS_NOTES.md
       android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt:66-71
       android/app/build.gradle.kts:163-165

Kanıt:
  1) Release'de FLAG_SECURE açık:
       if (!BuildConfig.DEBUG) { window.setFlags(FLAG_SECURE, FLAG_SECURE) }
     → İncelemecinin ekran görüntüsü ve Pre-launch report görselleri siyah çıkar.
  2) Uygulama yalnız Türkçe: androidResources { localeFilters += listOf("tr") }
     ve main.dart:214 supportedLocales = [Locale('tr','TR')].
  3) Manşet özellik ücretli (A-003).

  Hazırlanmış azaltıcı metin var ama uygulanmamış:
    store/PLAY_REVIEWER_ACCESS_NOTES.md içinde hâlâ `<PROMO_CODE>` yer tutucusu
    duruyor ve dosyanın kendi yapılacaklar listesindeki dört kutunun hiçbiri
    işaretli değil (App access metni, promo kod, License testing, varsayılan dil).

Etki: İncelemeci uygulamayı açar, arayüzü okuyamaz, manşet özelliği ödeme yapmadan
göremez ve ekran görüntüsü alamaz. "Temel işlevsellik doğrulanamadı" gerekçeli red
gerçekçi bir sonuçtur ve her red turu takvimi 1–2 hafta uzatır.

Nasıl görülür: `grep PROMO_CODE store/PLAY_REVIEWER_ACCESS_NOTES.md` → yer tutucu.

Önerilen çözüm: O dosyadaki dört operatör adımını yayından önce bitir: App access
metnini Console'a yapıştır, gerçek bir promo kod üret veya inceleme hesabını
License testing'e ekle, listeleme varsayılan dilini Türkçe yap.

Efor: S (<2 saat Console'da)
Durum: Doğrulandı (repo tarafı); Console durumu Doğrulanamadı
```

```
[A-007] [High] [Uyum] Play Console'da hiçbir form gönderilmemiş: Data Safety,
içerik derecelendirmesi, hedef kitle, hassas izin beyanları

Konum: store/release_checklist.md "Final Operator Handoff Matrix"
       store/DATA_SAFETY_FORM.md, store/CONTENT_RATING_ANSWERS.md,
       store/permissions_declaration_notes.md

Kanıt: Üç dosya da durumunu açıkça yazıyor:
  "Dashboard completion is PLAY_CONSOLE / NEEDS_OPERATOR_ACTION."
  "Do not mark this as submitted until the Play Console certificate exists."
  release_checklist.md: "No Play Console dashboard task, RevenueCat dashboard task,
  billing purchase test, signed AAB upload, or real-device QA is marked done in
  this repo."

Etki: Data Safety ve içerik derecelendirmesi kapalı/açık test ve production
sunumları için zorunlu. Gönderilmeden production'a çıkılamaz. Metinler hazır
olduğu için bu bir yazım işi değil, bir Console oturumu işi — ama sırası önemli
(gizlilik URL'i → app access → ads → içerik derecelendirmesi → hedef kitle →
Data Safety), ve bu sıra `docs/play-console-checklist.md` içinde zaten yazılı.

Nasıl görülür: Play Console → Policy → App content: bölümler boş/eksik.

Önerilen çözüm: `docs/play-console-checklist.md` §3'teki sırayla doldur.
Foreground service beyanı **gönderilmemeli** — pakette FGS yok; eski bir
`specialUse` taslağı varsa silinmeli.

Efor: M (yarım gün Console'da)
Durum: Doğrulanamadı (Console erişimim yok); repo tarafı Doğrulandı
```

```
[A-008] [High] [Uyum / Hukuk] KVKK yurt dışı aktarım mekanizması (RevenueCat)
hukukçu tarafından doğrulanmamış ve proje bunu kendisi blocker sayıyor

Konum: docs/kvkk_veri_isleme_envanteri.md — "Yurt dışı aktarım açık kapısı"

Kanıt:
  "RevenueCat, Google/Play, OSM ve support e-posta sağlayıcısı için alıcı rolü,
   ülke, alt işleyenler, DPA, KVKK m.9 mekanizması ve gerekiyorsa standart sözleşme
   bildirim süresi counsel tarafından belirlenmemiştir. Teknik doküman bu boşluğu
   `risk kabul edildi` diyerek kapatamaz. G4/G8 bu satırlar UNVERIFIED iken PASS
   olamaz."
  Belgenin başlığı: Durum: COUNSEL_UNVERIFIED

Etki: Abonelik açıldığı anda anonim kullanıcı kimliği, entitlement ve teknik
metadata yurt dışındaki bir işleyiciye gidiyor. KVKK m.9 mekanizması belirlenmeden
bu aktarım hukuki dayanaksız kalır. Aydınlatma metninde açıklama yapmak tek başına
yetki değildir — belgenin kendisi de bunu söylüyor.

Nasıl görülür: Belgeyi aç; her RevenueCat satırı `COUNSEL_UNVERIFIED`.

Önerilen çözüm: Türk veri koruma hukukçusundan RevenueCat akışı için m.9
mekanizması hakkında yazılı görüş al ve kararı belgeye iliştir. Alternatif:
RevenueCat'i kaldırıp doğrudan Play Billing'e geçmek — bu faturalandırma ve
gizlilik tasarımını baştan doğrulamayı gerektirir.

Efor: L (dış hukukçu; takvim olarak 1+ hafta)
Durum: Doğrulanamadı (hukuki değerlendirme denetim kapsamım dışında); belgenin
       durumu Doğrulandı
```

### 5.3 MEDIUM

```
[A-009] [Medium] [Güvenlik / Gizlilik] Hızlı erişim yüzeyleri, uygulama PIN'i
sorulmadan acil kişinin adını ekranda gösteriyor

Konum: lib/core/widgets/emergency_trigger_host.dart:71-75, 268-336
       lib/screens/countdown_screen.dart:827-843

Kanıt: EmergencyTriggerHost, MaterialApp'in ÜSTÜNDE mount ediliyor (main.dart:240)
ve initState'te `_consumeQuickPanicRequest()` → `_openCountdown()` çağırıyor.
`_openCountdown` yalnız abonelik kapısını çalıştırıp `rootNavigatorKey` üzerine
CountdownScreen push ediyor — arada PIN kapısı yok. Geri sayım ekranı ise:
  if (_emergencyContact != null) ... Text("countdown_emergency_contact".tr(
      namedArgs: {"name": _armedTargetName ?? _emergencyContact!.name}))

Etki: Cihazı açık hâlde ele geçiren biri (zorlama modelinin tam senaryosu) Hızlı
Ayarlar kutucuğuna dokunarak kurbanın acil kişisinin adını uygulama PIN'ini
bilmeden öğrenebilir. Uygulamanın geri kalanı PIN arkasında; bu yüzey değil.
Not: geri sayımı BAŞLATABİLMESİ bilinçli bir tasarım (acil anda PIN istemek
özelliği öldürür); sorun adın görünmesi.

Nasıl görülür: PIN kurulu ve Pro aktif bir cihazda uygulamayı tamamen kapat,
bildirim gölgesinden KoruBeni kutucuğuna dokun. Geri sayım açılır ve "Acil kişi:
<AD>" satırı PIN sorulmadan görünür.

Önerilen çözüm: Hızlı erişimden gelen geri sayımda kişi adını maskele (ör. yalnız
baş harf) veya adı yalnız PIN doğrulanmış oturumda göster. Arama hedefi zaten
arm anında sabitleniyor, adı göstermemek akışı bozmaz.

Efor: S (<2 saat)
Durum: Doğrulandı (kod okumasıyla); cihazda tetikleme Doğrulanamadı
```

```
[A-010] [Medium] [Performans] Pakete 2,7 MB gereksiz varlık giriyor: iOS ikon
fontu, RevenueCat web köprüsü ve 1,7 MB'lık lisans metni

Konum: Derlenmiş AAB içeriği (base/assets/flutter_assets/)

Kanıt (yerel smoke AAB'den ölçüldü):
  1,7 MB  assets/legal/THIRD_PARTY_NOTICES.txt
  744 KB  packages/purchases_flutter/assets/web/purchases_js_hybrid_mappings.js
  448 KB  assets/sounds/ringtone.wav      (sıkıştırılmamış WAV)
  252 KB  packages/cupertino_icons/assets/CupertinoIcons.ttf
  176 KB  assets/sounds/siren.wav         (sıkıştırılmamış WAV)
  Tek-ABI (arm64) base toplamı: 59,5 MB sıkıştırılmamış
  `cupertino_icons` lib içinde 0 dosyada import ediliyor.

Etki: Android paketinde bir web JavaScript köprüsü ve bir iOS ikon fontu taşınıyor;
ikisi de bu üründe çalışamaz. WAV'lar sıkıştırılmamış. Toplamda indirme boyutu ve
cihaz depolaması gereksiz yere büyüyor — düşük depolamalı, eski telefonlu hedef
kullanıcı için anlamlı.

Nasıl görülür: AAB'yi aç, `base/assets/flutter_assets/packages/` altına bak.

Önerilen çözüm: `cupertino_icons` bağımlılığını kaldır (kullanılmıyor).
`THIRD_PARTY_NOTICES.txt` uygulama içinde gösteriliyorsa sıkıştırılmış tutulabilir
veya yalnız web'e bırakılabilir — ama lisans yükümlülüğü olduğu için kaldırmadan
önce lisans metinlerinin hangi dağıtım biçimini gerektirdiği kontrol edilmeli.
WAV'lar OGG/AAC'ye çevrilebilir. `purchases_ui_flutter` gerçekten kullanılıyorsa
web varlığı paket tarafının sorunu, kaldırılamaz.

Efor: S (<2 saat, lisans kontrolü hariç)
Durum: Doğrulandı (derlenmiş paket ölçüldü)
```

```
[A-011] [Medium] [Bakım] 17 Dart dosyası `lib` içinden hiç referans edilmiyor

Konum: lib/ (ölü dosya listesi aşağıda)

Kanıt (her dosya adı, kendisi hariç tüm lib içinde arandı; 0 eşleşme):
  lib/screens/legal_disclaimer_screen.dart        lib/services/secure_storage_service.dart
  lib/services/legal_version_checker.dart         lib/widgets/status_badge.dart
  lib/widgets/network_error_retry.dart            lib/widgets/gradient_card.dart
  lib/widgets/loading_overlay.dart                lib/widgets/empty_state.dart
  lib/core/constants/api_constants.dart           lib/core/constants/route_constants.dart
  lib/core/utils/crashlytics_test_helper.dart     lib/core/utils/extensions.dart
  lib/core/services/safety_alert_dispatch.dart    lib/core/services/resource_monitor_service.dart
  lib/core/services/startup_diagnostics_service.dart
  lib/screens/legal/onboarding_legal_flow.dart    lib/domain/models/user_profile.dart

Etki: `crashlytics_test_helper.dart` üç `debugPrint` ile "Crash reporting removed"
yazıyor — kaldırılmış bir SDK'nın kalıntısı. `route_constants.dart` ve
`api_constants.dart` artık kullanılmayan bir mimariyi anlatıyor. Yeni geliştirici
bunları canlı sanar; ayrıca R8 bunları paketten atsa da kaynak okuma maliyeti kalır.

Nasıl görülür: Yukarıdaki listeyi `grep -r <dosya_adı> lib` ile doğrula.

Önerilen çözüm: Sil. Testlerden referans alanlar olabilir — silmeden önce
`grep -r <dosya_adı> test` ile kontrol et. `.claude/rules/common/coding-style.md`
gereği tek başına bir commit olmalı.

Efor: S (<2 saat)
Durum: Doğrulandı
```

```
[A-012] [Medium] [Mağaza] Mağaza ekran görüntüleri emülatör çıktısı ve projenin
kendi kuralı bunu kabul etmiyor; boyutlar da kendi belgesindeki değerlerle uyuşmuyor

Konum: store/screenshots/android/final/, store/screenshots/README.md

Kanıt:
  $ file store/screenshots/android/final/*.png
  01_home_locked_panic.png: PNG 992 x 1846
  02_contacts.png:          PNG 992 x 1846
  03_settings_legal.png:    PNG 992 x 1846
  04_map.png:               PNG 848 x 1696
  scripts/capture_screenshots.sh: adb shell screencap → emülatör/cihaz
  store/screenshots/README.md:
    "Recommended phone sizes: 1080x1920 or 1080x2340."
    "Status: NEEDS_OPERATOR_ACTION until reviewed and evidenced.
     Emulator output is not accepted as release evidence."

Etki: 992x1846 Play'in teknik sınırlarını ihlal etmiyor ama projenin kendi
belgelediği hedefi tutturmuyor ve dört görsel de release build'den (FLAG_SECURE
nedeniyle alınamaz) değil debug'dan gelmiş olmalı. Ayrıca PII incelemesi
"NEEDS_OPERATOR_ACTION" durumunda — yani kimse ekranlarda gerçek isim/numara
olup olmadığını kayıtlı biçimde kontrol etmemiş.

Nasıl görülür: Yukarıdaki `file` komutu.

Önerilen çözüm: Debug build ile (FLAG_SECURE debug'da kapalı) 1080x2340 bir cihaz
veya AVD üzerinden yeniden yakala, dördünü de PII açısından gözden geçir ve
incelemeyi tarihli bir notla kaydet.

Efor: S (<2 saat)
Durum: Doğrulandı
```

```
[A-013] [Medium] [Bakım / Güvenlik] 128 paket geride; güvenlikle ilgili üç
bağımlılık birer majör sürüm atlamış

Konum: pubspec.yaml + `flutter pub outdated`

Kanıt: flutter_secure_storage 10.0.0 → 11.2.0 · permission_handler 11.4.0 → 13.0.2
       geolocator 13.0.4 → 14.0.3 · flutter_local_notifications 19.5.0 → 22.3.1
       get_it 7.7.0 → 9.2.1 · flutter_map 7.0.2 → 8.3.2 · mocktail 0.3.0 → 1.0.5
       OSV taraması yine de temiz: 0 bulgu / 400 sorgu.

Etki: Bilinen bir zafiyet yok (bu iyi haber ve ölçüldü), ama `flutter_secure_storage`
gibi PIN'i tutan bir paketin bir majör geride kalması, ileride bir yama
çıktığında sıçramayı pahalı ve riskli yapar. `flutter_local_notifications` üç
majör geride ve zaten pubspec yorumunda "her minör yükseltmede elle test et"
notu var.

Nasıl görülür: `flutter pub outdated`.

Önerilen çözüm: Dependabot zaten aylık gruplu PR açıyor. Yayından SONRA, bir
sürümde bir majör olacak şekilde ilerleyin; `flutter_secure_storage` ve
`permission_handler` önce gelsin çünkü izin ve depolama davranışı değişir.
Yayından önce yükseltme yapmayın — bu boyutta bir sıçrama yeni cihaz QA'sı ister.

Efor: L (yayın sonrası, sürüm başına M)
Durum: Doğrulandı
```

```
[A-014] [Medium] [Fonksiyonel] Profil e-postası saklanıyor ve dışa aktarılıyor
ama girilebileceği bir alan yok

Konum: lib/screens/edit_profile_screen.dart:115-124
       lib/presentation/providers/settings_provider.dart:41-51
       lib/core/services/user_data_export_service.dart:114

Kanıt: Profil ekranında tek bir `TextFormField` var (ad, maxLength 60).
`SettingsProvider.updateProfile` ise `required String email` alıyor ve
`prefProfileEmail` anahtarına yazıyor; dışa aktarma `'email': prefs.getString(
AppConstants.prefProfileEmail) ?? ''` satırıyla bunu JSON'a koyuyor.

Etki: Kullanıcı e-posta giremediği için alan hep boş; dışa aktarma çıktısında
anlamsız boş bir alan duruyor ve KVKK envanterinde olmayan bir veri alanı kodda
yaşıyor. İşlevsel zarar yok, ama "arayüzün vaat ettiği ↔ kodun yaptığı"
tutarsızlığının küçük bir örneği.

Nasıl görülür: Profil düzenleme ekranını aç; e-posta alanı yok. Ayarlar →
Verilerimi dışa aktar; JSON'da `"email": ""`.

Önerilen çözüm: Ya alanı tamamen kaldır (sabit `prefProfileEmail`, provider alanı,
dışa aktarma satırı) ya da UI'ya ekle. Kaldırma tercih edilir: e-posta toplamak
yeni bir KVKK envanter satırı açar.

Efor: S (<2 saat)
Durum: Doğrulandı
```

```
[A-015] [Medium] [Güvenlik / Süreç] Şifresi bilinmeyen bir keystore, çalışan
keystore'un yanında duruyor

Konum: android/app/korubeni_keystore_SIFRESI_BILINMIYOR_KULLANMA.jks
       android/app/korubeni_keystore_release.jks
       android/korubeni-release-key.jks

Kanıt:
  $ ls -la android/app/*.jks android/*.jks
  -rw------- 2748 android/app/korubeni_keystore_SIFRESI_BILINMIYOR_KULLANMA.jks
  -rw------- 2632 android/app/korubeni_keystore_release.jks
  -rw------- 2748 android/korubeni-release-key.jks
  $ grep storeFile android/key.properties
  storeFile=app/korubeni_keystore_release.jks
  Git geçmişi temiz: `git log --all --diff-filter=A -- '*.jks'` → boş.

Etki: Hiçbiri git'e girmemiş (doğrulandı, bu iyi). Ama üç keystore dosyası ve
açık metin parolalı bir `key.properties` disk üzerinde duruyor ve biri açıkça
"şifresi bilinmiyor". Yanlış dosyanın seçilmesi yayın kimliğini geri dönüşsüz
bozar; Play App Signing'e yüklenen ilk sertifika değiştirilemez. CI tarafı bunu
SHA-256 ile sabitlemiş (`EXPECTED_UPLOAD_CERT_SHA256`), o yüzden asıl risk yerel
derlemede.

Nasıl görülür: Yukarıdaki `ls`.

Önerilen çözüm: Kullanılmayan iki dosyayı şifreli bir yedeğe taşıyıp diskten
kaldır. `docs/release/dr_and_key_custody.md` zaten saklama prosedürünü yazıyor;
uygulanması operatör işi.

Efor: S (<2 saat)
Durum: Doğrulandı
```

```
[A-016] [Medium] [Erişilebilirlik] Üç renk çifti WCAG AA altında kalıyor

Konum: PRODUCT_DECISIONS_REQUIRED.md D-10 kararı

Kanıt (projenin kendi ölçümü):
  emergency/cardBg 4,43:1 · kendi %25 tint'i 3,97:1 · cardBg üzerine %12 tint 3,99:1
  Bar 4,5:1. Üçü de büyük-metin barı 3,0'ı geçiyor.
  Karar: "kabul edilen kalıntı risk" (MP-06-014 → N/A).

Etki: Acil durum rengiyle yazılmış küçük metin, düşük görme keskinliği olan veya
parlak güneşte bakan kullanıcı için okunması zor. Bir güvenlik uygulamasında
acil metni tam da en kötü koşullarda okunur olmalı.

Nasıl görülür: Kararın kendisinde ölçülmüş; cihazda güneş altında bakarak da
hissedilir.

Önerilen çözüm: Karar zaten kayıtlı ve gerekçesi sağlam (uyumlu renk, rozeti
tamamen siliyor). Yayından sonra bütçelenmiş bir tasarım geçişinde kontrast VE
renk körlüğü ayrımı BİRLİKTE yeniden ölçülmeli. Not: `#FF6B6B` önerisi ölçümle
çürütülmüş, bir daha önerilmemeli.

Efor: L (tasarım turu)
Durum: Doğrulandı (projenin ölçümü okundu; bağımsız ölçüm yapmadım)
```

```
[A-017] [Medium] [Güvenlik] Root/jailbreak tespiti tek çağrıya dayanıyor,
hata durumunda "güvenli" diyor ve uyarı kapatılabiliyor

Konum: lib/services/device_security_service.dart:4-10
       lib/screens/splash_screen.dart:170-188

Kanıt:
  Future<bool> isCompromised() async {
    try { return await SafeDevice.isJailBroken; }
    catch (e) { return false; }
  }
  Splash'te sonuç true ise tek "Devam" butonlu, kapatılabilir bir dialog gösteriliyor.

Etki: Hata yutulunca sonuç "cihaz temiz" olur — fail-open. Zorlama modelinde
root'lu cihaz, entitlement çapasının (iki SharedPreferences anahtarı) ve yerel
verinin okunabildiği tek senaryo, yani tespitin sessizce başarısız olması bilinçli
kabul edilen riski genişletir.

Nasıl görülür: Kod okuması.

Önerilen çözüm: `catch` bloğunu "bilinmiyor" durumuna ayır ve en azından yerel
loglara yaz. Uyarıyı engelleyici yapmak gerekmez (kullanıcıyı kendi cihazından
kilitlemek doğru değil), ama sessiz başarısızlık ile "temiz" aynı şey olmamalı.

Efor: S (<2 saat)
Durum: Doğrulandı
```

### 5.4 LOW

```
[A-018] [Low] [Bakım] `.claude/` gitignore'da ama `.claude/tdd-guard/data/
instructions.md` git'te izleniyor — tutarsız durum.
Kanıt: `.gitignore` satır "Claude Code tooling → .claude/"; `git ls-files` bu
dosyayı listeliyor. Efor: S. Durum: Doğrulandı.
```

```
[A-019] [Low] [Bakım] Kök dizinde güncel olmadığı README'de yazılı beş dosya
duruyor: BUILD_NOW.md, BUILD_FIX.md, BUILD_FINAL.md, DEBUG_BUILD.md, KEYSETUP.md
(Şubat 2026). Hepsi gitignore'lu ama diskte ve karışıklık yaratıyor.
Efor: S. Durum: Doğrulandı.
```

```
[A-020] [Low] [Kod kalitesi] `Validators.isValidPhone` ve `Validators.isValidEmail`
hiçbir yerden çağrılmıyor; telefon doğrulaması `EmergencyNumberValidator` üzerinden
gidiyor. İki doğrulama kuralı da birbirinden farklı (biri 10 hane, diğeri 7–15) —
ileride yanlışlıkla ölü olanın kullanılması riski var.
Konum: lib/core/utils/validators.dart:41-48. Efor: S. Durum: Doğrulandı.
```

```
[A-021] [Low] [Kod kalitesi] `AppConstants.prefDemoMode` hiçbir yerde okunmuyor
veya yazılmıyor. Konum: lib/core/constants/app_constants.dart:26. Efor: S.
Durum: Doğrulandı.
```

```
[A-022] [Low] [Ortam] `AppEnvironment.isDev => !isProduction`, yani `ci_smoke`
ortamı "dev" sayılıyor. Bugün zarar vermiyor (release doğrulaması ayrı kontrol
ediyor) ama üç ortamlı bir modelde iki değerli bir bayrak ileride yanlış dallanır.
Konum: lib/core/config/app_environment.dart:30. Efor: S. Durum: Doğrulandı.
```

```
[A-023] [Low] [Kod kalitesi] `lib` içinde 92 `dynamic` kullanımı var; çoğu
platform kanalı sınırında (kaçınılmaz) ama hepsi sınırda değil. Efor: M.
Durum: Doğrulandı.
```

### 5.5 INFO — bilinçli kararlar (kusur değil, kayıt için)

| ID | Konu | Durum |
|---|---|---|
| A-024 | Çevrimdışı entitlement çapası **sınırsız**: bir kez doğrulanmış Pro, mağazaya ulaşılamadığı sürece süresiz SOS yetkisi veriyor; çapa iki düz SharedPreferences anahtarı (`revenuecat_prior_verified_pro_hint_v1` + `revenuecat_last_verified_pro_at_v1`). Root'lu cihazda taklit edilebilir. Karar D-8: kabul — kayıp gelir, kayıp güvenlik değil. Kod: `lib/core/services/subscription_access_state.dart:151-178`. | Doğrulandı, kabul edilmiş |
| A-025 | Geri sayım sırasındaki PIN denemeleri kilitlenme sayacına takılmıyor (yalnız saniyede bir değerlendiriliyor). Panikleyen kullanıcıyı kendi iptalinden kilitlememek için bilinçli; pencere zaten 10 saniye. Kod: `lib/screens/countdown_screen.dart:572-588`. | Doğrulandı, gerekçesi sağlam |
| A-026 | Telemetri, analitik ve uzaktan crash SDK'sı yok; regresyonu kullanıcı bildirir. Karar D-6: kabul, Play vitals tek sinyal. | Doğrulandı, kabul edilmiş |
| A-027 | Çalışma zamanı feature flag'i ve uzaktan kapatma anahtarı yok; geri alma = daha yüksek versionCode ile ileri sarma. Karar D-7. | Doğrulandı, kabul edilmiş |
| A-028 | Biyometrik kilit açma yok ve eklenmeyecek (zorlama modeli). `local_auth` bağımlılığı mevcut değil — doğrulandı. | Doğrulandı, doğru |
| A-029 | KVKK rıza kaydı bilinçli olarak keystore'suz `SharedPreferences`'ta (`kvkk_consent_log_v2`) — rıza ispatı keystore sıfırlamasından sağ çıkmalı. | Doğrulandı, gerekçesi yazılı |
| A-030 | 345 satır içi `fontSize`, 1 `textTheme` okuması. Karar D-2: ratchet var, migrasyon yok. | Doğrulandı, kabul edilmiş borç |
| A-031 | Depo bilinçli olarak tek biçimde formatlanmamış; CI'da format kapısı yok. Gerekçe `.claude/rules/common/coding-style.md` içinde ölçümle yazılı. | Doğrulandı, gerekçesi sağlam |
| A-032 | 314 test dosyasının 205'i `lib` kaynağını metin olarak okuyor. Mutasyon kapısı bunu kısmen dengeliyor ama "string grep testi davranış kanıtı değil" — bu deponun kendi kuralı. | Doğrulandı, risk olarak notlanmalı |
| A-033 | **Bu raporun kendisi** `release_change_classification_test`'i kırıyor: `AUDIT_REPORT.md` `config/release_change_classification.json` içindeki hiçbir kurala uymuyor, kapı da fail-closed. Bu turda düzeltilmedi çünkü config değiştirmek denetim kapsamı dışında. Çözüm: config'e `"pattern": "^AUDIT_REPORT\\.md$"`, `"category": "release"` kuralı ekle — ya da raporu depoya hiç koymayıp dışarıda sakla. | Doğrulandı (kaldır/geri koy testiyle izole edildi) |

---

## 6. İyi yapılanlar

Kısa tutuyorum çünkü sorunlar uzun, ama bu bölümü atlamak haksızlık olur.

Bu depo, gördüğüm mobil projelerin çok üstünde bir dürüstlük disiplini taşıyor.
Acil çağrı çekirdeği Kotlin'de tiplenmiş durum makinesi olarak yazılmış
(`ArmResult`/`CancelResult`/`DispatchResult`), ve en zor kısmı doğru yapmış:
**belirsizliği başarı ya da başarısızlık saymıyor.** `EmergencyResultPolicy`
kullanıcıya gösterilecek iddiayı sevkiyat defterinden türetiyor ve "hiçbir işlem
tamamlanmadı" cümlesini yalnız defter gerçekten boşsa kurabiliyor — bunu bir
constructor gizleyerek yapıya gömmüşler, yoruma bırakmamışlar. Entitlement üç
değerli (`authorized`/`denied`/`unknown`) ve "mağazaya ulaşılamadı" hiçbir yerde
"abone değil"e dönüşmüyor. PIN, PBKDF2-HMAC-SHA256 100.000 iterasyonla saklanıyor
ve iterasyon sayısı ölçümle seçilmiş, folklorla değil. Veri silme işleminde kimlik
deposu en son siliniyor, çünkü ara bir hata durumunda geriye kalan verinin önünde
hâlâ PIN olsun isteniyor — bu, çoğu ekibin düşünmediği bir ayrıntı. Yayın zinciri
imzalı etiket, sertifika parmak izi sabitleme, provenance, SBOM, 16 KB hizalama ve
mutasyon kapısı içeriyor. Ve en çarpıcısı: belgeler kapatılmamış işi kapatılmış
göstermiyor — CodeQL'in Dart'ı görmediği, TalkBack'in gerçek cihazda denenmediği,
faturalandırmanın hiç işlem görmediği hep açıkça yazılı.

---

## 7. Aksiyon planı

### Hemen yapılacak ilk 10 madde

| # | İş | Bulgu | Efor |
|---|---|---|---|
| 1 | **A-001 için ürün kararını ver:** vadesi geçmiş oturum kaç dakika sonra aranmak yerine gösterilsin? | A-001 | Karar (S) |
| 2 | Kararı `reconcile()` içine uygula, testini ve emülatör doğrulamasını aynı commit'te ekle | A-001 | M |
| 3 | Dalı `main`'e birleştir, ardından tam `verify_release.sh` koş | A-002 | L |
| 4 | Birleştirme sonrası canlı `kullanim_sartlari.html` sürümünün 4.0.0 olduğunu tarayıcıda doğrula | A-004 | S |
| 5 | Play Console'da abonelik ürünlerini (aylık + yıllık) oluştur ve RevenueCat eşlemesini yap | A-003 | M |
| 6 | Lisans testçisi hesabı ekle, dahili test track'ine imzalı AAB yükle | A-003, A-006 | M |
| 7 | `store/BILLING_RELEASE_CHECKLIST.md` zincirini uçtan uca koş, her geçişi kaydet | A-003 | L |
| 8 | Play Console App content formlarını `docs/play-console-checklist.md` §3 sırasıyla doldur | A-007 | M |
| 9 | `PLAY_REVIEWER_ACCESS_NOTES.md` içindeki dört operatör adımını bitir (promo kod dâhil) | A-006 | S |
| 10 | Bölüm 8'deki manuel test senaryolarını iki gerçek telefonda koş ve sonuçları kaydet | — | M |
| 11 | `AUDIT_REPORT.md` için sınıflandırma kuralı ekle (veya raporu depo dışında tut) — aksi hâlde CI kırmızı kalır | A-033 | S |

### P0 — Herhangi bir test kullanıcısından önce

| Sıra | İş | Bulgu ID | Efor |
|---|---|---|---|
| 1 | A-001 kararı + uygulaması + cihaz doğrulaması | A-001 | M |
| 2 | Dalı `main`'e birleştir | A-002 | L |
| 3 | Canlı sözleşme sürümünü doğrula | A-004 | S |
| 4 | Faturalandırma zincirini gerçek bir sandbox işlemiyle çalıştır | A-003 | L |
| 5 | Hızlı erişim geri sayımında kişi adını maskele | A-009 | S |

### P1 — Mağazaya göndermeden önce

| Sıra | İş | Bulgu ID | Efor |
|---|---|---|---|
| 1 | Play Console formlarının tamamı (Data Safety, içerik derecelendirmesi, hedef kitle, hassas izinler) | A-007 | M |
| 2 | İncelemeci erişim paketi: promo kod / license testing / varsayılan dil | A-006 | S |
| 3 | KVKK yurt dışı aktarım için hukukçu görüşü | A-008 | L |
| 4 | Gerçek cihaz QA: `store/REAL_DEVICE_QA_MATRIX.md` — en az bir Pixel + bir agresif OEM (Xiaomi/Samsung), ikisi de SIM'li | — | L |
| 5 | Ekran görüntülerini 1080x2340 ile yeniden al ve PII incelemesini kaydet | A-012 | S |
| 6 | Native kanal kurulum hatasını kullanıcıya görünür yap | A-005 | M |
| 7 | Root tespitinde fail-open'ı kaldır | A-017 | S |
| 8 | `cupertino_icons` bağımlılığını kaldır, WAV'ları sıkıştır | A-010 | S |

### P2 — Yayın sonrası

| Sıra | İş | Bulgu ID | Efor |
|---|---|---|---|
| 1 | 17 ölü dosyayı tek commit'te sil | A-011 | S |
| 2 | Profil e-posta alanını kaldır (veya UI'ya ekle) | A-014 | S |
| 3 | Kullanılmayan keystore'ları şifreli yedeğe taşı | A-015 | S |
| 4 | Bağımlılıkları sürüm başına bir majör olacak şekilde güncelle | A-013 | L |
| 5 | Kontrast geçişini bütçele (kontrast + renk körlüğü birlikte ölçülerek) | A-016 | L |
| 6 | Ölü sabitleri ve doğrulayıcıları temizle | A-020, A-021, A-022 | S |
| 7 | Gerçek cihazda TalkBack turu (E8) | — | M |
| 8 | Beş kişilik yönlendirmesiz kullanılabilirlik testi (E7) | — | M |

---

## 8. Manuel test senaryoları

Bunlar teknik bilgi gerektirmez. **İki telefona ihtiyacınız var:** biri KoruBeni'nin
kurulu olduğu, diğeri acil kişi olarak kaydedeceğiniz. Acil kişi olarak asla gerçek
bir yakınınızı veya 112'yi yazmayın — ikinci test telefonunuzu yazın.

> ⚠️ Panik/SOS, Güvenli Yürüyüş ve Check-In ücretli. Bunları test edebilmek için
> önce Play Console'da lisans testçisi olarak kendinizi eklemeniz gerekir (madde 6).
> Test Modu ücretsizdir ve gerçek arama yapmaz — ondan başlayın.

### T-01 — İlk kurulum (yaklaşık 3 dakika)
1. Uygulamayı yeni kurun ve açın.
2. Onay ekranında zorunlu kutuları işaretleyin ve 18+ beyanını seçin.
   → **Görmelisiniz:** Tüm kutular işaretlenmeden "Devam" çalışmamalı.
3. 4 tanıtım sayfasını geçin, acil kişi adımına gelin.
4. Önce rıza kartını onaylayın, sonra ikinci telefonunuzun adını ve numarasını girin.
   → **Görmelisiniz:** Kişi eklemeden bu adım geçilememeli.
5. 4 haneli bir PIN belirleyin. **`1234` deneyin.**
   → **Görmelisiniz:** "Zayıf PIN" uyarısı ve reddedilmesi. → Görmezseniz: bulgu yok,
     ama not edin (kod bunu reddediyor olmalı).
6. `2468` gibi bir PIN girin, tekrar girin.
7. Bildirim izni sorulunca "İzin ver" deyin.
   → **Görmelisiniz:** Ana ekran, üstte hazırlık kartı.

### T-02 — Hazırlık kartı dürüst mü? (2 dakika)
1. Ana ekranda hazırlık kartındaki her çipi okuyun.
2. Telefon ayarlarından KoruBeni'nin **arama izni**ni kapatın, uygulamaya dönün.
   → **Görmelisiniz:** Arama çipi kırmızı/eksik olmalı ve dokununca izin istemeli.
   → **Görmezseniz:** Bulgu A-005 civarı; not edin.
3. İzni geri verin.

### T-03 — Test Modu provası (ücretsiz, 2 dakika)
1. Ana ekranda "Test Modu" butonuna basın.
   → **Görmelisiniz:** Geri sayım ekranı, üstte yeşil "Test Modu" rozeti.
2. Geri sayımın dolmasını bekleyin.
   → **Görmelisiniz:** "Test tamamlandı" bildirimi ve **hiçbir arama yapılmaması.**
   → **İkinci telefonunuz çalarsa:** Kritik bulgu, hemen bildirin.

### T-04 — Gerçek panik akışı (Pro gerekir, 3 dakika)
1. Panik butonunu **3 saniye basılı tutun**, sonra bırakın.
   → **Görmelisiniz:** Buton kırmızıya döner, titreşim gelir, halka dolar.
   → 3 saniyeden önce bırakırsanız hiçbir şey olmamalı.
2. Geri sayım ekranı açılır.
   → **Görmelisiniz:** 10'dan geriye sayan sayı, acil kişinizin adı, PIN tuş takımı.
3. PIN'inizi girin.
   → **Görmelisiniz:** Geri sayım durur ve ekran kapanır. → **Kapanmazsa:** bulgu.
4. Tekrar başlatın, bu kez PIN girmeyin, süreyi doldurun.
   → **Görmelisiniz:** İkinci telefonunuz çalar veya telefon uygulaması numarayla
     açılır. Ekranda "arama isteği gönderildi" benzeri bir ifade olmalı —
     "arama bağlandı" YAZMAMALI.

### T-05 — A-001'i kendiniz görün: force-stop sonrası açılışta arama (5 dakika)
**Bu, raporun en önemli testidir.**
1. Panik geri sayımını başlatın (T-04 adım 1).
2. Geri sayım devam ederken telefonun **Ayarlar → Uygulamalar → KoruBeni →
   Zorla durdur** düğmesine basın.
   → **Görmelisiniz:** Hiçbir arama gitmemeli ve size hiçbir şey söylenmemeli.
3. **10 dakika bekleyin.** Hâlâ arama yok, ikinci telefon sessiz.
4. Şimdi KoruBeni'yi ana ekrandan normal şekilde açın.
   → **Beklenen (kusurlu) davranış:** İkinci telefonunuz, siz hiçbir şey
     sormadan, birkaç saniye içinde çalar.
   → **Olması gereken:** Uygulama size "geri sayımınız tamamlanamadı, aramak
     ister misiniz?" diye sormalı.
   → İkinci telefon çalıyorsa **bulgu A-001 doğrulanmış demektir.**
5. Aynısını 1 gün bekleyerek tekrarlayın; davranışın değişmediğini göreceksiniz.

### T-06 — İzinleri reddeden kullanıcı (4 dakika)
1. Telefon ayarlarından KoruBeni'nin **arama iznini** kapatın.
2. Panik akışını çalıştırın, süreyi doldurun.
   → **Görmelisiniz:** Telefon uygulaması numarayla açılmalı ve size "arama
     tuşuna kendiniz basın" denmeli. Sessizce hiçbir şey olmaması bir bulgudur.
3. **Bildirim iznini** kapatın, Check-In başlatmayı deneyin.
   → **Görmelisiniz:** Açık bir "başlatılamıyor / güvenilirlik düşük" mesajı.
4. **Konum iznini** "Bir daha sorma" ile reddedin, Harita sekmesini açın.
   → **Görmelisiniz:** Ayarlara yönlendiren net bir mesaj; sahte/yanlış konum
     gösterilmemeli.
5. Tüm izinleri geri verin.

### T-07 — İnternetsiz kullanım (3 dakika)
1. Uçak modunu açın.
2. Ana ekranı ve panik akışını (Test Modu ile) kullanın.
   → **Görmelisiniz:** Üstte çevrimdışı bandı, ama akışın çalışması. Panik akışı
     internete ihtiyaç duymamalı.
3. Harita sekmesini açın.
   → **Görmelisiniz:** Harita karoları yüklenmez ama uygulama çökmez, durum açıkça
     söylenir.
4. Uçak modunu kapatın.

### T-08 — Beceriksiz kullanıcı (4 dakika)
1. Kişi ekleme formunu boş gönderin. → Net hata mesajı görmelisiniz.
2. Telefon alanına `abc` yazmayı deneyin. → Harf girilememeli.
3. Telefon alanına `1` yazıp kaydedin. → "Geçersiz numara" uyarısı.
4. İsim alanına 200 karakter ve emoji yazın. → Kırpılmalı veya reddedilmeli, taşma
   olmamalı.
5. Panik butonuna arka arkaya 5 kez hızlıca basıp bırakın.
   → **Görmelisiniz:** En fazla BİR geri sayım ekranı. İki geri sayım üst üste
     açılırsa bulgu.
6. Kişi silme düğmesine basın. → Onay sorulmalı; sormadan silerse bulgu.

### T-09 — Kesinti ve dönüş (4 dakika)
1. Panik geri sayımını başlatın, hemen **güç tuşuna basıp ekranı kilitleyin.**
2. 15 saniye bekleyin, ekranı açın.
   → **Görmelisiniz:** İkinci telefonunuz çalmış olmalı (ekran kapalıyken de
     çalışmalı). Çalmadıysa **kritik bulgu** — bu ürünün temel vaadi.
3. Kişi ekleme formunu yarım doldurup uygulamayı arka plana alın, dönün.
   → **Görmelisiniz:** Yazdıklarınız durmalı.
4. Uygulamayı 3 dakika arka planda bırakıp dönün.
   → **Görmelisiniz:** PIN ekranı gelmeli (2 dakikalık kilit).

### T-10 — Büyük yazı tipi ve küçük ekran (3 dakika)
1. Telefon ayarlarından yazı boyutunu **en büyüğe** alın.
2. Sırayla: Ana ekran, Kişiler, Harita, Ayarlar, Geri sayım (Test Modu ile).
   → **Görmelisiniz:** Hiçbir yazı kesilmemeli, hiçbir buton ekran dışına
     taşmamalı, çevrimdışı bandı kendi yazısını kırpmamalı.
3. Yazı boyutunu normale alın.

### T-11 — Hızlı erişim yüzeyleri (3 dakika)
1. Bildirim gölgesini açın, düzenle'den KoruBeni kutucuğunu ekleyin.
2. Uygulamayı tamamen kapatın (son uygulamalardan kaydırın).
3. Kutucuğa dokunun.
   → **Görmelisiniz:** Geri sayım açılır.
   → **A-009 kontrolü:** Uygulama PIN'i sorulmadan acil kişinizin **adı** ekranda
     görünüyor mu? Görünüyorsa bulgu A-009 doğrulanmış demektir.
4. PIN girip iptal edin.

### T-12 — Veri silme (3 dakika)
1. Ayarlar → Yasal → Verilerimi sil.
2. Uyarıyı okuyun, onaylayın, PIN girin.
   → **Görmelisiniz:** Aboneliğin ayrı olduğunu söyleyen bir not mutlaka olmalı.
3. Silme sonrası uygulamayı kapatıp açın.
   → **Görmelisiniz:** Sıfırdan kurulum akışı (onay → onboarding → PIN).
4. Kişilerin ve geçmişin gittiğini doğrulayın.

### T-13 — Yasal bağlantılar (2 dakika)
1. Ayarlar → Yasal → her bağlantıyı açın (Gizlilik, Kullanım Şartları, Aydınlatma).
   → **Görmelisiniz:** Sayfa açılmalı ve **üstteki sürüm numarası uygulamadakiyle
     aynı olmalı.** Farklıysa bulgu A-004 doğrulanmış demektir (bugün farklı:
     uygulama 4.0.0, canlı sayfa 3.1.0).
2. Paywall ekranındaki üç yasal bağlantıyı da açın.

---

## 9. Doğrulanamayanlar ve geliştiriciye sorular

### 9.1 Bu denetimde doğrulanamayanlar

| Konu | Neden | Etkilenen alan |
|---|---|---|
| Uygulamanın gerçek cihazda/emülatörde çalıştırılması | Bu turda uygulama hiç çalıştırılmadı; tüm çalışma zamanı değerlendirmesi kod okuması, test sonuçları ve projenin kendi cihaz kayıtlarına dayanıyor | 2, 3, 6, 8 |
| Gerçek telefonda Doze, üretici pil yöneticisi, force-stop davranışı | Fiziksel cihaz yok; emülatör MIUI/One UI davranışını üretmiyor | 3, 8 |
| Gerçek telefonyla arama: SIM, operatör, çift SIM, gelen arama çakışması | Telefon donanımı ve ikinci hat gerekiyor | 2, 3 |
| Satın alma, geri yükleme, deneme, iptal, hesap beklemede | Play Console + RevenueCat + lisans testçisi hesabı gerekiyor | 2, 12 |
| Play Console'daki fiili form durumları | Console erişimim yok | 5, 10 |
| Soğuk açılış süresi, bellek, pil tüketimi ölçümleri | Cihaz üzerinde profil alınmadı | 8 |
| Gerçek TalkBack duyurularının sırası ve akıcılığı | Ekran okuyuculu cihaz gerekiyor | 7 |
| Görsel kalite: taşma, kırpılma, karanlık mod tutarlılığı | Uygulama görsel olarak açılmadı; yalnız test kapıları okundu | 6 |
| CodeQL'in Kotlin kaynaklarını gerçekten çıkarıp çıkarmadığı | Hosted çalıştırma logu gerekiyor; workflow metni kanıt değil (projenin kendi notu) | 4 |
| KVKK m.9 aktarım mekanizmasının hukuki yeterliliği | Hukuki değerlendirme denetim kapsamım dışında | 5 |
| 400 SBOM bileşeninin lisans incelemesi | İnsan incelemesi 0/400; bu bir hukukçu/lisans uzmanı işi | 11 |

### 9.2 Geliştiriciye sorular

1. **A-001 için hangi yaş sınırını istiyorsunuz?** Vadesi 2 dakika geçmiş bir
   oturum aransın mı, 5 dakika mı, yoksa hiç aranmayıp yalnız gösterilsin mi?
   Bu bir denge kararı: kaçırılan arama da gerçek bir maliyet.
2. Vadesi geçmiş oturum aranmayacaksa kullanıcıya nasıl gösterilsin — bildirim mi,
   uygulama açılışında bir kart mı, ikisi de mi?
3. `main` dalına birleştirme planı ne? 147 commit tek merge ile mi gidecek, yoksa
   parçalı mı? Depo kuralı her commit'te yeşil test istiyor; hangisini tercih
   ediyorsunuz?
4. RevenueCat entitlement kimliği dashboard'da harfi harfine `KoruBeni Pro` mu?
   (Boşluk ve büyük harfler dâhil — kod bunu tam eşleşmeyle arıyor.)
5. Aylık ve yıllık ürün kimlikleri Play Console'da oluşturuldu mu? Fiyatlar ve
   deneme süresi belirlendi mi?
6. İnceleme için promo kod mu üreteceksiniz, yoksa lisans testçisi listesi mi
   kullanacaksınız?
7. Profil e-postası alanı kalsın mı, kaldırılsın mı? Kaldırmak KVKK envanterini
   sadeleştirir.
8. `THIRD_PARTY_NOTICES.txt`'in uygulama içinde gösterilmesi bir lisans zorunluluğu
   mu, yoksa web'e taşınabilir mi? (1,7 MB paket içinde.)
9. Gerçek cihaz QA için hangi telefonlara erişiminiz var? En az bir Pixel/AOSP ve
   bir Xiaomi/Samsung gerekiyor.
10. Yayın takvimi ne? P0 maddeleri kabaca 1 hafta, P1 maddeleri 1–2 hafta daha
    sürer; bu sizin planınızla uyuşuyor mu?

---

## 10. Varsayımlarım

Proje bilgileri formu boş geldiği için aşağıdakileri koddan çıkardım.

| Alan | Çıkardığım değer | Dayanak |
|---|---|---|
| Uygulama adı | KoruBeni (Play adı: "KoruBeni: Panik Butonu, Siren") | `pubspec.yaml`, `store/google_play_listing.md` |
| Ne işe yarar, kimin için | Kişisel güvenlik uygulaması: panik butonu, sahte çağrı, siren, güvenli yürüyüş. Türkiye'de, yetişkin (18+), Türkçe konuşan bireysel kullanıcı | `store/play_store_listing_tr.md`, `CONTENT_RATING_ANSWERS.md` |
| Platformlar | **Yalnız Android.** `ios/` dizini mevcut değil | Dosya sistemi |
| Teknoloji | Flutter 3.38.9 + Kotlin native çekirdek | `pubspec.yaml`, `android/` |
| Backend | **Yok.** Ağ yalnız opsiyonel katmanlarda: OSM harita karoları, Google Play Billing, RevenueCat | `lib/core/constants/api_constants.dart`, `CLAUDE.md` kural 1 |
| Ana akışlar | (1) rıza → onboarding → PIN → ana ekran, (2) panik: basılı tut → geri sayım → PIN iptal / arama, (3) check-in ve güvenli yürüyüş, (4) sahte çağrı ve siren, (5) acil kişi yönetimi, (6) konum oturumu, (7) abonelik | `lib/screens/`, `FeatureAccessMatrix` |
| Hedef | **Google Play'e ilk gönderim** (dahili/kapalı test üzerinden) | `CLAUDE.md` kural 4, `store/release_checklist.md` |
| Gelir modeli | Ücretsiz + isteğe bağlı abonelik ("KoruBeni Pro", aylık/yıllık, RevenueCat üzerinden Play Billing) | `lib/core/services/revenue_cat_service.dart:29`, paywall |
| Bilinen sorunlar | Ekibin kendi kaydından alındı: N-08 (açık), E1–E9 dış engelleyiciler, D-1…D-11 ürün kararları | `docs/audit/remediation-20260911.md`, `EXTERNAL_LAUNCH_BLOCKERS.md` |
| Rapor dili | Türkçe, teknik terimler İngilizce | Prompt |

**Metodoloji varsayımları:**
- "Ana akış" tanımını yukarıdaki yedi akış olarak aldım; kapı 3'ü bunlara göre
  değerlendirdim.
- Özellik tamamlanma yüzdesini hesaplarken bilinçli olarak kapsam dışı bırakılmış
  üç şeyi (açık tema, iOS, İngilizce çalışma zamanı) paydaya katmadım; bunlar
  eksik değil, verilmiş kararlar.
- Projenin kendi cihaz doğrulama belgelerini kanıt olarak kabul ettim, çünkü
  build parmak izi, AVD adı, yoğunluk ve commit içeriyorlar (deponun kendi
  CERT2-05 kuralı). Bunları bağımsız olarak tekrarlamadım.
- `flutter analyze`, `flutter test`, `verify_release.sh`, OSV taraması ve sır
  taraması bu makinede benim tarafımdan çalıştırıldı; çıktıları yukarıda.

---

*Bu rapor 18 Eylül 2026'da `d2e06db` commit'i üzerinde üretildi. Kod değiştirilmedi.
Düzeltmeler ayrı bir turda istenmelidir.*


---

## 11. Kapatma kapsamı ve doğrulama listesi

Bu bölüm 20 Eylül 2026'da, "hangi bulgular depo içinde kapatılabilir ve
kapatıldığını nasıl kanıtlarız" sorusuna cevap olarak eklendi.

### 11.1 33 bulgunun dağılımı

| Kategori | Adet | Bulgular |
|---|---|---|
| **A — Depo içinde kapatılabilir** | **14** | A-002, A-005, A-009, A-010, A-011, A-014, A-017, A-018, A-019, A-020, A-021, A-022, A-023, A-033 |
| **B — Önce sahibin kararı, sonra kod** | **1** | A-001 |
| **C — Başka bulguya bağlı, kendiliğinden kapanır** | **1** | A-004 (A-002 birleştirilip push edilince) |
| **D — Bilinçli olarak yayın sonrasına ertelendi** | **2** | A-013, A-016 |
| **E — DEPO DIŞI: hiçbir kod oturumu kapatamaz** | **6** | A-003, A-006, A-007, A-008, A-012, A-015 |
| **F — Zaten verilmiş kararlar, yapılacak iş yok** | **9** | A-024 … A-032 |
| | **33** | |

**Sorunun cevabı: 6 bulgu tamamen depo dışındadır.** Bunlar Play Console,
RevenueCat, gerçek telefon, hukukçu veya anahtar saklama gerektirir:

| ID | Neden depo dışı | Kim kapatır |
|---|---|---|
| A-003 | Gerçek bir sandbox satın alma işlemi gerekiyor | Sahibi + Play Console + RevenueCat |
| A-006 | Promo kod üretimi, license testing listesi, listeleme dili | Sahibi, Play Console'da |
| A-007 | Data Safety / içerik derecelendirmesi / hedef kitle formları | Sahibi, Play Console'da |
| A-008 | KVKK m.9 aktarım mekanizması hakkında yazılı görüş | Türk veri koruma hukukçusu |
| A-012 | Gerçek cihaz yakalaması + insan PII incelemesi + Console yüklemesi | Sahibi |
| A-015 | Keystore'ların şifreli yedeğe taşınması ve diskten kaldırılması | Sahibi |

**Bir kod oturumunun görev listesi bu yüzden 14 maddedir** (kategori A), artı
A-001'in karar verildikten sonraki kod yarısı. Başka hiçbir bulgu "kapatıldı"
işaretlenmemelidir.

### 11.2 Doğrulama listesi

Aşağıdaki komutlar "kapatıldı" iddiasını bağımsız olarak sınar. Beklenen çıktıyı
vermeyen madde kapatılmamıştır. Oturumun kendi beyanı kanıt değildir.

| ID | Doğrulama komutu | Beklenen |
|---|---|---|
| A-002 | `git log --oneline main..HEAD \| wc -l` | `0` |
| A-005 | Yeni bir test dosyası olmalı; düzeltmeyi geri alınca o test KIRILMALI (mutasyon kontrolü) | Test var ve mutasyonla kırılıyor |
| A-009 | `grep -n "countdown_emergency_contact" lib/screens/countdown_screen.dart` + yeni test | Hızlı erişim yolunda ad maskeli |
| A-010 | `grep -c cupertino_icons pubspec.yaml` | `0` |
| A-011 | `for f in <17 dosya>; do test -e "$f" && echo "HALA VAR: $f"; done` | Hiç çıktı yok |
| A-014 | `grep -rn "prefProfileEmail" lib \| wc -l` | `0` (kaldırıldıysa) veya UI'da alan var |
| A-017 | `sed -n '1,15p' lib/services/device_security_service.dart` | `catch` artık `false` dönmüyor |
| A-018 | `git ls-files .claude/ \| wc -l` | `0` |
| A-019 | `ls BUILD_NOW.md BUILD_FIX.md BUILD_FINAL.md DEBUG_BUILD.md KEYSETUP.md 2>&1` | "No such file" |
| A-020 | `grep -n "isValidPhone\|isValidEmail" lib/core/utils/validators.dart` | Çıktı yok |
| A-021 | `grep -rn "prefDemoMode" lib \| wc -l` | `0` |
| A-022 | `sed -n '28,32p' lib/core/config/app_environment.dart` | `isDev` üç ortamı ayırıyor |
| A-023 | `grep -rn "\bdynamic\b" lib \| wc -l` | 92'den belirgin düşük |
| A-033 | `flutter test --no-pub test/release_change_classification_test.dart` | `All tests passed!` |
| A-001 | Yeni test + `docs/audit/` altında cihaz kaydı (AVD adı, yoğunluk, commit, `lastUpdateTime`) | Yaş sınırı testle sabit, cihazda ölçülmüş |

**Kapanış kapısı — hepsi bittikten sonra, sırayla:**

```bash
flutter analyze --no-fatal-infos     # "No issues found!"
flutter test --no-pub                # "All tests passed!"
./scripts/verify_release.sh          # EXIT=0, 6/6 kapı
```

Üçü de yeşil değilse hiçbir madde kapatılmış sayılmaz.

### 11.3 Oturumun ASLA yapmaması gerekenler

- A-003, A-006, A-007, A-008, A-012, A-015'i "kapatıldı" işaretlemek.
- A-013'ü uygulamak: 128 paketi yükseltmek yayın öncesi yapılmaz, yeni cihaz QA'sı ister.
- A-016 için renk değiştirmek: karar D-10'da verilmiş, `#FF6B6B` ölçümle çürütülmüş.
- A-024 … A-032'ye dokunmak: bunlar verilmiş kararlar, kusur değil.
- A-001'i kararsız uygulamak: yaş sınırı sahibinin vereceği bir sayıdır.
- Testin iddiasını zayıflatarak yeşile getirmek.
