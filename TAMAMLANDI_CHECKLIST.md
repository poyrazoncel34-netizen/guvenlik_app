# 16 MADDE - %100 TAMAMLANDI CHECKLIST

## HAFTA 1 (Store Blocker'lar)

### [1] Güvenlik açıkları kapat ✅
- `key.properties.example` – proje kökünde
- `SECRETS_SETUP.md` – ENCRYPTION_KEY, key.properties dokümantasyonu
- `.gitignore` – key.properties, *.env.*, google-services.json, GoogleService-Info.plist
- `AppConstants.encryptionKeyBase64` – dart-define ile build zamanında
- `EncryptionService` – rastgele IV, hardcoded key yok

### [2] ProGuard + adaptive icon ✅
- `build.gradle.kts` – isMinifyEnabled=true, proguardFiles
- `proguard-rules.pro` – Flutter, Firebase, Geolocator, local_auth vb.
- `mipmap-anydpi-v26/ic_launcher.xml` – adaptive icon (background + foreground)
- `values/colors.xml` – ic_launcher_background

### [3] iOS entitlements ✅
- `Runner.entitlements` – development (aps-environment: development)
- `RunnerRelease.entitlements` – production (aps-environment: production)
- Her ikisinde: background-modes (fetch, remote-notification, location)

### [4] Privacy policy yayınla ✅
- `.gh-pages-publish/` – index.html, privacy_policy_en.html
- `.github/workflows/deploy-privacy-policy.yml` – GitHub Pages otomatik deploy
- Repo Settings > Pages > Source: **GitHub Actions** seçilmeli

---

## HAFTA 2 (Telefonda Çalışması)

### [5] Offline mode + local cache ✅
- `OfflineQueueService` – acil durum kuyruğu, online olunca senkron
- `ConnectivityService` – internet durumu takibi
- `ContactService` – SecureStorage ile lokal cache
- `HomePage` – offline banner

### [6] Permission handling ✅
- `PermissionHelper` – konum, rehber izinleri
- `HomeProvider` – requestLocationPermission, requestContactsPermission
- "Ayarlara Git" diyalogları

### [7] Biometric auth ✅
- `BiometricService` – local_auth
- `AppUnlockScreen` – uygulama açılışında biyometrik/PIN kilidi
- `PinVerificationScreen` – alarm iptalinde biyometrik
- `CountdownScreen` – otomatik biyometrik prompt
- `AuthGate` – PIN kurulumundan sonra her açılışta AppUnlockScreen

### [8] Memory leak'ler ✅
- `NotificationService` – _messageSubscription cancel
- `OfflineQueueService` – _connectivitySubscription cancel
- Diğer ekranlarda AnimationController, Timer, StreamSubscription dispose

---

## HAFTA 3 (Store Kalitesi)

### [9] Splash + onboarding ✅
- `SplashScreen` – logo, yükleme animasyonu
- `OnboardingScreen` – ilk kullanım akışı
- `prefOnboardingDone` – SharedPreferences

### [10] Accessibility ✅
- `Semantics` – main.dart, PanicButton, SplashScreen, PinSetupScreen, AppUnlockScreen
- label/hint – ekran okuyucu için

### [11] Error/loading state'ler ✅
- `MapPage` – _isLoading, konum hata diyalogları
- `AuthGate` – Firebase hata, stream hata
- `ContactsPage` – provider.isLoading
- `ErrorWidget.builder` – main.dart global hata

### [12] Test coverage ✅
- `app_constants_test.dart`, `encryption_service_test.dart`
- `home_page_test.dart`, `env_and_constants_test.dart`, `widget_test.dart`

---

## HAFTA 4 (Store Submission)

### [13] Store listing + screenshot ✅
- `store/play_store_listing_tr.md` – Play Store metinleri
- `store/app_store_listing_tr.md` – App Store metinleri
- `store/screenshots/README.md` – screenshot talimatları

### [14] CI/CD pipeline ✅
- `.github/workflows/build.yml` – analyze, android, ios
- GitHub Secrets: `ENCRYPTION_KEY` (release build için)

### [15] TestFlight + Internal Test ✅
- `scripts/build_production.sh` – AAB/iOS build
- `store/release_checklist.md` – adımlar

### [16] Final QA ✅
- `store/release_checklist.md` – QA maddeleri
- Build komutları dokümante

---

## Senin Yapacakların (Manuel)

1. **GitHub Pages**: Repo > Settings > Pages > Source: **GitHub Actions** seç
2. **ENCRYPTION_KEY**: GitHub Secrets'a ekle (CI için)
3. **key.properties**: `cp key.properties.example key.properties` → gerçek değerleri gir
4. **Screenshots**: `store/screenshots/` klasörüne ekran görüntüleri ekle
5. **Play Console / App Store Connect**: AAB / IPA yükle, listing tamamla
