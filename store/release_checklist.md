# Release Checklist (Store-Ready MVP)

## Pre-Release

### Versioning
- Her store gonderiminde build number artir: `./scripts/bump_version.sh`
- Version format: `major.minor.patch+build` (orn. 1.0.0+1)
- Production build: `flutter build apk --release --dart-define=ENV=production --dart-define=ENCRYPTION_KEY=your_key`

### Security
- [x] Encryption key dart-define ile disaridan veriliyor
- [x] Default PIN kaldirild, ilk giris PIN setup zorunlu
- [x] key.properties .gitignore'da
- [x] google-services.json .gitignore'da
- [x] GoogleService-Info.plist .gitignore'da

### App Identity
- [x] App name finalized: KoruBeni
- [x] Android applicationId: com.poyrazoncel.korubeni
- [x] iOS bundleId: com.poyrazoncel.korubeni
- [x] Version and build number set

### Store Requirements
- [ ] Privacy Policy URL canli (store/privacy_policy_template.md'den)
- [ ] Support email belirle
- [ ] Store listings finalize (store/ klasoru)
- [ ] Screenshots al (iPhone, Android)
- [ ] App icon 1024x1024 onayla

### Android
- [x] Keystore olusturuldu
- [x] Release signing yapilandirildi (build.gradle.kts)
- [x] ProGuard kurallari aktif
- [ ] Data Safety form doldur (Play Console)
- [ ] Internal Testing track'e yukle
- **Detay:** [PLAY_CONSOLE_CHECKLIST.md](PLAY_CONSOLE_CHECKLIST.md) – Privacy Policy URL, Data Safety, Content rating, AAB adimlari

### iOS
- [x] Signing & provisioning yapilandi (Team ID set)
- [ ] App Store Privacy Details doldur
- [ ] TestFlight'a yukle

### QA
- [ ] Gercek Android cihazda test
- [ ] Gercek iPhone'da test
- [ ] SMS + arama akisi test
- [ ] PIN kurulum akisi test
- [ ] Izin reddedilme senaryolari test
- [ ] Offline senaryolar test

## Build Commands

```bash
# Development
flutter run --dart-define=ENV=dev

# Production APK
flutter build apk --release \
  --dart-define=ENV=production \
  --dart-define=ENCRYPTION_KEY=your_base64_key

# Production AAB (Play Store)
flutter build appbundle --release \
  --dart-define=ENV=production \
  --dart-define=ENCRYPTION_KEY=your_base64_key

# iOS
flutter build ios --release \
  --dart-define=ENV=production \
  --dart-define=ENCRYPTION_KEY=your_base64_key

# Build numarasi artir
chmod +x scripts/bump_version.sh && ./scripts/bump_version.sh

# Testler
flutter test

# Ikon uret
dart run flutter_launcher_icons
```
