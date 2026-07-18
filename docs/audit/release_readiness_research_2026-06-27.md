# KoruBeni Release Readiness Research - 2026-06-27

> **SUPERSEDED HISTORICAL RECORD — DO NOT USE AS RELEASE INSTRUCTIONS.**
> This snapshot predates the strict smoke/play flavor split, removal of
> `USE_FULL_SCREEN_INTENT` and the generic foreground service, target API 36
> qualification, production-key validation, pinned upload certificate, and the
> Phase 1–5 hardening work. In particular, its placeholder `playRelease` build
> must never be reproduced or uploaded. Current gates are
> `store/release_checklist.md` and
> `docs/qa/phase5-operational-readiness-evidence-2026-07-18.md`.

Bu not, mevcut uygulamanın kodu ve resmi kaynaklar üzerinden yayına hazırlık kararını takip eder. Mevcut proje `.md` dosyaları karar girdisi olarak okunmadı; uygulama kodu, manifestler, Gradle yapılandırması, testler ve resmi kaynaklar esas alındı.

## Karar Özeti

- Seçilen repo: `/Users/poyrazoncel/Desktop/guvenlik_app`.
- Neden: Bu repo ve `../guvenlik_app kopyası` aynı GitHub remote ve aynı son commite sahip; mevcut repo `main...origin/main` üzerinde aktif RevenueCat/subscription hazırlığı ve store screenshot çıktıları taşıyor. Kopya temiz bir feature branch ve aynı taban committe.
- Yayın stratejisi: Android / Google Play odaklı Play flavor release. iOS kapsam dışı.

## Hipotez Ağacı

H0: Uygulama Google Play yayınına hazırlanabilir.

- H1: Mevcut repo doğru çalışma hedefidir.
  - Güven: %85.
  - Kanıt: `git remote -v` aynı remote; iki repo aynı son commit `7a24133`; mevcut repo aktif RevenueCat değişikliklerini içeriyor.
- H2: Android teknik yayın gereklilikleri kod tarafında büyük ölçüde karşılanıyor.
  - Güven: %82.
  - Kanıt: `targetSdk = 35`, `compileSdk = 36`, release build `ENV=production`, RevenueCat key ve `ENCRYPTION_KEY` zorunlu; debug signing fallback engellenmiş; `flutter analyze`, full `flutter test`, release placeholder AAB build, 16 KB alignment script ve Android `lintPlayRelease`/`testPlayDebugUnitTest` geçti.
  - Kalan risk: Gerçek release signing key ve production secrets bu repo içinde yok, operatör ortamında sağlanmalı.
- H3: Play policy/izin beyanları ana inceleme riski olmaya devam ediyor.
  - Güven: %68.
  - Kanıt: Uygulama `CALL_PHONE`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, foreground service special use ve konum izni kullanıyor. Bunlar açıklama ve Play Console declaration gerektirir.
  - Kalan risk: Console beyanlarının uygulama davranışıyla birebir girildiği dış sistemden doğrulanamaz.
- H4: RevenueCat/abonelik kodu yayın eşiğinde, ancak dış panel kurulumu bloklayabilir.
  - Güven: %75.
  - Kanıt: SDK dependency, `Purchases.configure`, offerings, purchase, restore, customer center/fallback ve Pro entitlement kontrolü var.
  - Kalan risk: RevenueCat Android app key, active offering, monthly/annual package ve `KoruBeni Pro` entitlement-product bağlantısı panelde doğrulanmalı.

## Güven Günlüğü

- Başlangıç: Repo seçimi %70, policy riski %60, release secret riski %55.
- Repo karşılaştırması sonrası: Repo seçimi %80.
- Resmi kaynak ve kod incelemesi sonrası: Repo seçimi %85, Android teknik uyum %75, policy/izin riski %65, RevenueCat dış panel riski %75.
- Harita izin akışı düzeltmesi ve hedefli testler sonrası: Android teknik uyum %78, policy/izin riski %68.
- Release build, 16 KB alignment ve Android Gradle lint/unit test sonrası: Android teknik uyum %82. Dış sistemler nedeniyle "tam yayın hazır" güveni bilinçli olarak sınırlı tutuldu.

## Kanıt Matrisi

| İddia | Uygulama kanıtı | Kaynak 1 | Kaynak 2 / bağımsız doğrulama | Durum |
|---|---|---|---|---|
| Google Play yeni app/update için Android 15 / API 35 hedef ister. | `android/app/build.gradle.kts`: `targetSdk = 35`, `compileSdk = 36`. | Android Developers target API guide: https://developer.android.com/google/play/requirements/target-sdk | Play Console Help target API page: https://support.google.com/googleplay/android-developer/answer/11926878 | Karşılanıyor. |
| 16 KB page-size uyumu Play için release kontrolü olmalı. | 64-bit ABI filtreleri: `arm64-v8a`, `x86_64`; `scripts/verify_16kb_alignment.sh` var. | Android Developers 16 KB page-size guide: https://developer.android.com/guide/practices/page-sizes | Yerel verification script AAB içindeki `.so` PT_LOAD alignment kontrol ediyor. | Build sonrası script çalıştırılmalı. |
| Exact alarm izni Android 14+ davranışında varsayılan olarak reddedilebilir; uygulama fallback kullanmalı. | `CheckInScheduler.canScheduleExactAlarms()`, inexact fallback; `confirmExactAlarmPermissionOrDegraded()` açıklama akışı var. | Android exact alarm changes: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms | Yerel Kotlin scheduler ve Dart guard kodu; hedefli testler geçti. | Karşılanıyor, Play declaration riski sürer. |
| Geniş contacts erişimi yerine minimum scope gerekir; uygulama broad READ_CONTACTS istememeli. | Manifest `READ_CONTACTS` için `tools:node="remove"`; native `Intent.ACTION_PICK` phone contact picker var. | Google Play policy deadlines/minimum scope: https://support.google.com/googleplay/android-developer/answer/12253906 | Android Contact Picker yönlendirmesi aynı Play kaynak içinde; yerel `MainActivity` sadece seçilen satırı okuyor. | Karşılanıyor. |
| Konum erişimi öncesinde anlaşılır açıklama ve minimum veri ilkesi gerekir. | `PermissionHelper.requestLocationPermission()` prominent disclosure gösteriyor; harita sekmesi artık bu helper üzerinden geçiyor. | Google Play minimum-scope/location policy direction: https://support.google.com/googleplay/android-developer/answer/12253906 | KVKK aydınlatma yükümlülüğü: https://www.kvkk.gov.tr/Icerik/2033/Aydinlatma-Yukumlulugu- | Güçlendirildi. |
| Data Safety beyanı uygulamanın gerçek veri toplama/paylaşma davranışını yansıtmalı. | Offline-first kod; privacy/legal ekranları; RevenueCat, Google Play Billing ve OSM metinlerde yer alıyor. | Play Data safety Help: https://support.google.com/googleplay/android-developer/answer/10787469 | KVKK ilgili kişi hakları: https://www.kvkk.gov.tr/Icerik/2036/Ilgili-Kisinin-Haklari | Console dışı doğrulanamaz; app tarafı uyumlu. |
| Dijital abonelikler Google Play billing üzerinden yürümeli ve fiyat/şartlar açık olmalı. | `com.android.vending.BILLING`; custom paywall fiyatı RevenueCat store product’tan alıyor; restore ve legal links var. | Google Play Payments policy: https://support.google.com/googleplay/android-developer/answer/9858738 | Android subscriptions guide: https://developer.android.com/google/play/billing/subscriptions | Kod tarafı hazır; ürün/panel testi gerekli. |
| RevenueCat release build gerçek platform API key ve entitlement/offering ister. | Release build `REVENUECAT_ANDROID_API_KEY` olmadan fail; provider monthly/annual packages ve entitlement kontrol ediyor. | RevenueCat SDK configure docs: https://www.revenuecat.com/docs/getting-started/configuring-sdk | RevenueCat entitlements docs: https://www.revenuecat.com/docs/getting-started/entitlements | Kod tarafı hazır; panel dışı blok var. |
| OSM tile kullanımı visible attribution ve ayırt edilebilir User-Agent ister; bulk/offline tile indirme yapılmamalı. | `© OpenStreetMap contributors` görünür; `kOsmUserAgentPackageName` package + email içeriyor; offline tile prefetch yok. | OSMF Tile Usage Policy: https://operations.osmfoundation.org/policies/tiles/ | Yerel `map_utils.dart` ve `map_page.dart` testleri. | Karşılanıyor. |
| KVKK açık rıza bilgilendirmeye ve özgür iradeye dayanmalı; geri alınabilir olmalı. | Consent screens, consent log/export, legal settings ve data export mevcut. | KVKK açık rıza sayfası: https://www.kvkk.gov.tr/Icerik/2037/Acik-Riza-Alirken-Dikkat-Edilecek-Hususlar | KVKK aydınlatma yükümlülüğü sayfası: https://www.kvkk.gov.tr/Icerik/2033/Aydinlatma-Yukumlulugu- | App tarafı makul; hukuki nihai onay ayrı. |

## Yapılan Düzeltme

- `lib/screens/map_page.dart`: harita sekmesi ilk konum okuması ve “konumuma git” akışı artık `PermissionHelper.requestLocationPermission(context)` üzerinden geçiyor. Böylece native izin prompt’u öncesi merkezi prominent disclosure akışı kullanılıyor.
- `test/screens/map_page_ui_test.dart`: harita konum isteklerinin disclosure helper’dan geçtiğini doğrulayan regresyon testi eklendi.
- `android/app/src/main/res/values/styles.xml` ve `android/app/src/main/res/values-night/styles.xml`: minSdk 24 kaynaklarından API 27/29 gerektiren `windowLayoutInDisplayCutoutMode` ve `forceDarkAllowed` öğeleri kaldırıldı. Bu davranış mevcut `values-v27`/`values-v29` ve night varyantlarında korunuyor; `lintPlayRelease` hatası baseline eklemeden çözüldü.
- `android/key.properties`: sır değerlerine dokunmadan `storeFile` yolu, mevcut `storePassword`/`keyAlias` ile doğrulanan keystore adayı olan `app/korubeni_keystore_ESKI_YEDEK.jks` dosyasına çevrildi. Önceki yol `app/korubeni_keystore.jks` imzalama aşamasında “keystore password was incorrect” hatası veriyordu.

## Doğrulama

- `flutter analyze`: geçti.
- `flutter test test/screens/map_page_ui_test.dart test/core/services/revenuecat_subscription_contract_test.dart test/release_readiness_policy_test.dart`: geçti.
- `flutter test`: geçti.
- Placeholder build check: `flutter build appbundle --release --flavor play --dart-define=ENV=production --dart-define=REVENUECAT_ANDROID_API_KEY=placeholder_build_check --dart-define=ENCRYPTION_KEY=placeholder_build_check` geçti ve `build/app/outputs/bundle/playRelease/app-play-release.aab` üretti.
- `scripts/verify_16kb_alignment.sh build/app/outputs/bundle/playRelease/app-play-release.aab`: geçti; 12 native library 16 KB page-size compatible.
- `cd android && ./gradlew app:lintPlayRelease app:testPlayDebugUnitTest`: ilk çalıştırmada temel style kaynaklarındaki yeni API öğeleri nedeniyle 4 `NewApi` lint hatası verdi; resource düzeltmesinden sonra geçti.

Not: Üretilen AAB gerçek RevenueCat Android API key ve gerçek `ENCRYPTION_KEY` ile değil, placeholder değerlerle derlendi. Bu artefact Play’e yüklenmemelidir; sadece release pipeline, signing ve 16 KB uyum kontrolünü doğrulamak için üretildi.

## Öz Eleştiri / Kalan Bloklar

- Kod ve resmi kaynak uyumu, Play Console panelinin gerçekten doğru doldurulduğunu kanıtlamaz. Data Safety, exact alarm/special use FGS, battery optimization ve CALL_PHONE beyanları operatör tarafından Play Console’da birebir girilmeli.
- RevenueCat gerçek Android API key, offering, monthly/annual package mapping ve entitlement bağlantıları repo dışıdır; kapalı/lisans tester testleri yapılmadan “tam yayın hazır” denemez.
- Release AAB gerçek production secrets olmadan upload-ready sayılmaz. Placeholder build compile/sign/16 KB doğrulaması için yeterlidir; mağaza yüklemesi için gerçek `REVENUECAT_ANDROID_API_KEY` ve gerçek `ENCRYPTION_KEY` ile yeniden build alınmalıdır.
- Mevzuat.gov.tr sayfası shell ile anlamlı içerik döndürmedi; KVKK için Kurumun resmi rehber/hak sayfaları kullanıldı. Bu yüzden kanun maddesi numarası iddialarını burada genişletmedim.
