# Release Checklist (Store-Ready MVP)

## Pre-Release

### Versioning
- Her store gonderiminde build number artir: `./scripts/bump_version.sh`
- Gizlilik politikasını senkronize et: `./scripts/sync_privacy_policy.sh`
- Version format: `major.minor.patch+build` (orn. 1.0.0+1)
- Production build: `flutter build appbundle --release --flavor play --dart-define=ENV=production --dart-define=REVENUECAT_ANDROID_API_KEY=your_revenuecat_android_key --dart-define=ENCRYPTION_KEY=your_key`
- Production AAB output: `build/app/outputs/bundle/playRelease/app-play-release.aab`

### Security
- [x] Encryption key dart-define ile disaridan veriliyor
- [x] Default PIN kaldirild, ilk giris PIN setup zorunlu
- [x] key.properties .gitignore'da
- [x] Firebase bagimliligi kaldirildi; build icin cloud config gerekmiyor
- [x] Analytics/crash reporting SDK'i public Play build'inde kullanilmiyor; Data Safety buna gore doldurulacak

### App Identity
- [x] App name finalized: KoruBeni
- [x] Android applicationId: com.poyrazoncel.korubeni
- [x] Version and build number set

### Store Requirements
- [x] Privacy Policy URL canli: https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy.html
- [x] Support email: korubeni.destek@gmail.com
- [ ] Store listings finalize (store/ klasoru)
- [ ] Screenshots al (Android)
- [ ] App icon 1024x1024 onayla

### RevenueCat / Google Play Billing Public Release Gate
- [ ] Production build `REVENUECAT_ANDROID_API_KEY` ile alindi; dummy/dev key kullanilmadi
- [ ] RevenueCat entitlement id `KoruBeni Pro` dashboard'da aktif
- [ ] RevenueCat current offering Play production app ile eslesiyor
- [ ] Current offering icinde monthly package var
- [ ] Current offering icinde annual package var
- [ ] Google Play Console subscription product id'leri RevenueCat packages ile eslesiyor
- [ ] Play license tester ile monthly purchase basarili ve Pro entitlement aktif oldu
- [ ] Play license tester ile annual purchase basarili ve Pro entitlement aktif oldu
- [ ] Restore purchases ayni Google hesabi ile Pro erisimini geri getirdi
- [ ] Offering kapali/ag hatali senaryoda paywall `plans unavailable` fail-safe gosteriyor ve crash olmuyor
- [ ] Public production submit oncesi paywall fiyatlari bos gorunmuyor

### Android
- [x] Keystore olusturuldu
- [x] Release signing yapilandirildi (build.gradle.kts)
- [x] ProGuard kurallari aktif
- [ ] Data Safety form doldur (Play Console)
- [ ] Internal Testing track'e yukle
- **Detay:** [PLAY_CONSOLE_CHECKLIST.md](PLAY_CONSOLE_CHECKLIST.md) – Privacy Policy URL, Data Safety, Content rating, AAB adimlari

### QA
- [ ] Gercek Android cihazda test
- [ ] Geri sayım sonrası arama akışı ve dialer fallback test
- [ ] PIN kurulum akisi test
- [ ] Izin reddedilme senaryolari test
- [ ] Offline senaryolar test
- **Detay:** [QA_SENARYOLAR.md](QA_SENARYOLAR.md) – Kritik akışlar ve ekran kontrol listesi

## Build Commands

```bash
# Development
flutter run --dart-define=ENV=dev

# Production AAB (Play)
flutter build appbundle --release --flavor play \
  --dart-define=ENV=production \
  --dart-define=REVENUECAT_ANDROID_API_KEY=your_revenuecat_android_key \
  --dart-define=ENCRYPTION_KEY=your_base64_key

# Production AAB (Play Store)
flutter build appbundle --release --flavor play \
  --dart-define=ENV=production \
  --dart-define=REVENUECAT_ANDROID_API_KEY=your_revenuecat_android_key \
  --dart-define=ENCRYPTION_KEY=your_base64_key

# Build numarasi artir
chmod +x scripts/bump_version.sh && ./scripts/bump_version.sh

# Ikon uret
dart run flutter_launcher_icons
```
