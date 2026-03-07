# Store Hazırlık – Yapılanlar ve Sizin Yapacaklarınız

Bu dosya, teknik eksikler listesinde istenen maddelerin projede nasıl karşılandığını özetler.

> Not: Bu özetin bazı eski bölümleri önceki Firebase tabanlı mimariden kalmış olabilir. Play Store başvurusu için öncelikli referans dosyalar: `store/PLAY_CONSOLE_CHECKLIST.md`, `store/DATA_SAFETY_FORM.md`, `store/SMS_PERMISSION_DECLARATION.md`.

---

## Yapılan Değişiklikler (Otomatik)

### 1. Firebase / Ortam Ayrımı
- **`lib/core/config/app_environment.dart`** eklendi. `ENV` dart-define ile dev/production ayrımı yapılıyor.
- **Kullanım:** `flutter run --dart-define=ENV=production` veya `flutter build apk --dart-define=ENV=production`
- **`lib/core/constants/api_constants.dart`** ortama göre `baseUrl` ve endpoint path'leri kullanıyor.
- **`main.dart`:** Firebase, `Firebase.initializeApp()` ile **önce** başlatılıyor (service locator’dan önce); production config ile uyumlu.
- **Sizin yapacaklarınız:** Production config (korubeni-prod) zaten eklendiyse ek işlem gerekmez.

### 2. App Icon
- **`assets/icon/app_icon.png`** eklendi (KoruBeni kalkan + konum iğnesi).
- **`pubspec.yaml`** içinde `flutter_launcher_icons` aktif; Android ve iOS launcher ikonları `dart run flutter_launcher_icons` ile üretildi.
- **Sizin yapacaklarınız:** İkon değişecekse `assets/icon/app_icon.png` dosyasını güncelleyip tekrar `dart run flutter_launcher_icons` çalıştırın.

### 3. Gizlilik Politikası
- **`store/privacy_policy_template.md`** güncellendi: başlık, maddeler, iletişim ve yayınlama notları eklendi.
- **Sizin yapacaklarınız:** Template dolduruldu (tarih: 2026-03-07, e-posta: korubeni.destek@gmail.com). HTML dosyaları güncel. GitHub Pages deploy sonrası store Privacy Policy URL alanına `https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy.html` yazın.

### 4. ProGuard / R8 (Android)
- **`android/app/proguard-rules.pro`** eklendi (Flutter, Firebase, Gson kuralları).
- **`android/app/build.gradle.kts`** release için `isMinifyEnabled = true`, `isShrinkResources = true` ve proguard dosyası tanımlandı.
- Release build: `flutter build apk --release` (ve gerekirse kendi signing config’inizi ekleyin).

### 5. Arka Plan Konum Gerekçesi
- **iOS `Info.plist`:** `NSLocationAlwaysAndWhenInUseUsageDescription` eklendi (arka planda konum, sadece acil durum için).
- **Android `AndroidManifest.xml`:** `ACCESS_BACKGROUND_LOCATION` ve `FOREGROUND_SERVICE` izinleri eklendi; yorum satırında gerekçe belirtildi.

### 6. API Endpoint’leri
- **`ApiConstants`** içinde `emergency`, `contacts`, `profile`, `location`, `activity` path’leri tanımlandı.
- Base URL `AppEnvironment.apiBaseUrl` üzerinden geliyor (production’da kendi backend adresinizi `app_environment.dart` içinde güncelleyin).

### 7. Crashlytics Test
- **`lib/core/utils/crashlytics_test_helper.dart`** eklendi: `recordTestError()`, `forceTestCrash()` (sadece debug), `logTestEvent()`.
- Debug menü veya geliştirme sırasında Crashlytics’in çalıştığını doğrulamak için kullanın.

### 8. Testler
- **`test/env_and_constants_test.dart`:** AppEnvironment, ApiConstants, LocationResult unit testleri.
- **`test/home_page_test.dart`:** PanicButton widget testi.
- Çalıştırma: `flutter test`

### 9. Erişilebilirlik (Semantics)
- **`lib/widgets/panic_button.dart`:** `Semantics` eklendi (label: "Acil Durum Butonu", hint, button: true).

### 10. Sürüm / Build Numarası
- **`scripts/bump_version.sh`:** Build numarasını (+1) artırır.
- **`store/release_checklist.md`:** Versioning bölümü ve production build komutu eklendi.

---

## Sizin Yapmanız Gerekenler (Manuel)

| Madde | Tahmini süre | Not |
|-------|----------------|-----|
| Firebase production config | ~30 dk | Yeni proje, `google-services.json` / `GoogleService-Info.plist` |
| App icon 1024x1024 | ~1 saat | Tasarım + `assets/icon/` + `flutter_launcher_icons` |
| Gizlilik politikası canlı URL | ~1 saat | Template’i doldurup GitHub Pages / siteye koyma |
| Screenshot’lar | ~2 saat | Emulator/cihazdan + gerekirse çerçeve (Fastlane snapshot/screengrab) |
| Release signing (Android) | ~30 dk | Keystore + `build.gradle.kts` signingConfig |
| iOS signing & provisioning | - | Apple Developer hesabı ve sertifikalar |
| Store metinleri | - | Kısa / uzun açıklama, destek e‑postası (zaten checklist’te) |

---

## Hızlı Komutlar

```bash
# Production build (API base URL production’a geçer)
flutter build apk --release --dart-define=ENV=production

# Build numarasını artır
chmod +x scripts/bump_version.sh && ./scripts/bump_version.sh

# Testler
flutter test

# İkon üretimi (app_icon.png eklendikten ve pubspec’teki config açıldıktan sonra)
dart run flutter_launcher_icons
```

---

*Bu özet, listelenen teknik eksiklerin proje içinde nasıl giderildiğini ve store öncesi sizin tamamlamanız gereken adımları özetler.*
