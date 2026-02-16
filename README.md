# KoruBeni

Acil durum ve güvenlik uygulaması. Panik butonu, konum paylaşımı, acil kişiler, sahte çağrı, siren ve güvenli yürüyüş özellikleri.

**KoruBeni** – Your safety companion (Flutter, Android & iOS).

## Gereksinimler

- Flutter SDK (pubspec'te tanımlı sürüm)
- Firebase projesi (Auth, Firestore, Crashlytics, Messaging, Analytics)
- Android: `android/key.properties` ve keystore (release imzası)
- iOS: Xcode, Apple Developer hesabı, `GoogleService-Info.plist`

## Kurulum

1. **Bağımlılıklar**
   ```bash
   flutter pub get
   ```

2. **Firebase**
   - `android/app/google-services.json` → Firebase Console'dan Android uygulaması ekleyip indirin.
   - `ios/Runner/GoogleService-Info.plist` → Firebase Console'dan iOS uygulaması ekleyip indirin.
   - Bu dosyalar `.gitignore`'da; repo'ya eklemeyin.

3. **Android release imzası**
   - Release imzası için **sadece** `android/key.properties` kullanılır (proje kökünde `key.properties` kullanılmaz).
   ```bash
   cp android/key.properties.example android/key.properties
   # android/key.properties içine storePassword, keyPassword, keyAlias, storeFile değerlerini girin
   ```
   Keystore oluşturma: `SECRETS_SETUP.md` içinde anlatılmaktadır.

4. **Şifreleme anahtarı (production build)**
   - Production build için `ENCRYPTION_KEY` (base64, 32 byte) gereklidir.
   ```bash
   openssl rand -base64 32   # Anahtar üretir
   ```
   Detay: `SECRETS_SETUP.md`

## Çalıştırma

```bash
# Geliştirme
flutter run --dart-define=ENV=dev

# Production (yerel test)
flutter run --dart-define=ENV=production --dart-define=ENCRYPTION_KEY=<base64_key>
```

## Build (Store)

```bash
# Android AAB (Play Store)
flutter build appbundle --release \
  --dart-define=ENV=production \
  --dart-define=ENCRYPTION_KEY=<base64_key>

# iOS (Xcode ile Archive / veya Fastlane)
flutter build ios --release \
  --dart-define=ENV=production \
  --dart-define=ENCRYPTION_KEY=<base64_key>
```

Veya script ile (Android + opsiyonel iOS):

```bash
ENCRYPTION_KEY='<base64_key>' ./scripts/build_production.sh
```

**Fastlane (iOS):** `ENCRYPTION_KEY` ortam değişkenini set edip `ios/fastlane` içinden `beta` veya `release` lane'lerini çalıştırın.

## Dokümantasyon

- **Gizli anahtarlar:** [SECRETS_SETUP.md](SECRETS_SETUP.md)
- **Yayın checklist:** [store/release_checklist.md](store/release_checklist.md)
- **Play Console:** [store/PLAY_CONSOLE_CHECKLIST.md](store/PLAY_CONSOLE_CHECKLIST.md)

## Test

```bash
flutter test
flutter analyze
```

## Lisans

Özel proje.
