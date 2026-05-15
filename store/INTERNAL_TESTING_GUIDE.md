# Play Store Internal Testing → İncelemeye Gönder Rehberi

Plan Madde 6-7: AAB build, Internal Testing yükleme, inceleme gönderimi.

Status: NEEDS_OPERATOR_ACTION / PLAY_CONSOLE / SIGNING / REVENUECAT / NEEDS_REAL_DEVICE_TEST. This guide describes manual steps only; this repo audit did not create keystores/secrets, build a signed AAB, upload to Play Console, configure RevenueCat, or run device/billing flows.

Data Safety nuance: Play Console internal testing may be exempt from the Data Safety section depending on account/app state. Closed testing, open testing, and production require Data Safety where Play Console presents it. Legal/privacy docs must still match the build before internal testing.

---

## Ön Koşullar

- [ ] `android/key.properties` operator tarafından dolduruldu (storePassword, keyPassword, storeFile, keyAlias)
- [ ] Store icon 512x512 PNG operator tarafından Play Console'da doğrulandı
- [ ] ENCRYPTION_KEY operator secret store / local secure process ile hazırlandı
- [ ] REVENUECAT_ANDROID_API_KEY operator tarafından RevenueCat'ten alındı
- [ ] RevenueCat / Google Play Billing setup `store/BILLING_RELEASE_CHECKLIST.md` ile test için hazır
- [ ] Play Console Data Safety durumu kontrol edildi; closed/open/production için Data Safety formu hazırlanıp gönderilecek
- [ ] Real-device QA evidence path hazır: `store/REAL_DEVICE_QA_MATRIX.md`

---

## 1. AAB Build Al

```bash
ENCRYPTION_KEY=<redacted> REVENUECAT_ANDROID_API_KEY=<redacted> ./scripts/release_to_play_store.sh
```

veya:

```bash
ENCRYPTION_KEY=<redacted> REVENUECAT_ANDROID_API_KEY=<redacted> ./scripts/build_production.sh
```

**Çıktı:** `build/app/outputs/bundle/playRelease/app-play-release.aab`

---

## 2. Internal Testing'e Yükle

1. [Play Console](https://play.google.com/console) → Uygulamanızı seçin
2. **Release** → **Testing** → **Internal testing**
3. **Create new release**
4. **App bundles** → Upload → `app-play-release.aab` dosyasını seçin
5. **Release name** ve **Release notes** girin
6. **Save** → **Review release**

---

## 3. Store Bilgileri Kontrolü

İncelemeye göndermeden önce:

- [ ] **Store listing** tamam (başlık, açıklama, Privacy Policy URL, screenshots)
- [ ] **Data Safety** formu Play Console gerektiriyorsa dolduruldu; internal testing için muafsa not/evidence kaydedildi
- [ ] **Content Rating** sertifikası alındı
- [ ] Target Audience adult / 18+ olarak gönderildi
- [ ] FGS / exact alarm / battery optimization / CALL_PHONE declarations gerekiyorsa gönderildi
- [ ] Screenshots `store/screenshots/android/final/` yolundan yüklendi ve PII review tamamlandı

---

## 4. İncelemeye Gönder

1. Internal testing release sayfasında **Start rollout to Internal testing**
2. Tüm uyarıları giderin
3. **Send for review** / **İncelemeye gönder**

---

## 5. RevenueCat / Play Billing Sandbox

Status: REVENUECAT / PLAY_CONSOLE / NEEDS_REAL_DEVICE_TEST.

- [ ] Google Play app exists and package name matches `com.poyrazoncel.korubeni`
- [ ] Signed AAB is uploaded to internal/closed track before sandbox purchase testing
- [ ] License tester account is added in Play Console
- [ ] Test device is signed into the intended tester Google account
- [ ] RevenueCat Android app, service credentials, entitlement `KoruBeni Pro`, current offering, monthly package, and annual package are configured
- [ ] Purchase, restore, cancel/manage, expired/lapsed, renewal/lapse, account hold/paused if available, no-offering fallback, and network-failure fallback are tested on physical devices
- [ ] Screenshots/video/log excerpts are saved with account emails, order IDs, phone numbers, and location data redacted

## 6. Real-Device QA Evidence

Status: NEEDS_REAL_DEVICE_TEST.

- [ ] Android 13 physical device: CALL_PHONE granted/denied, notifications, exact alarm, Safe Walk, Check-In, map, legal URLs, billing smoke
- [ ] Android 14 physical device: CALL_PHONE granted/denied/permanently denied, exact alarm denied/default-denied, FGS, notification denied, boot/Doze where possible
- [ ] Android 15 physical device if available; if not available, document unavailability in the QA matrix
- [ ] No SIM / airplane mode emergency behavior documented without unintended emergency call
- [ ] Play declaration video evidence recorded for foreground service if Play requests it
- [ ] Pre-launch report reviewed after Play upload; findings triaged before production
- [ ] CI/release logs reviewed after a real release workflow run for secret leakage

---

## Sorun Giderme

| Hata | Çözüm |
|------|-------|
| key.properties bulunamadı | Operator secure release-signing prosedürünü kullanmalı; repo audit keystore/secret oluşturmaz |
| RevenueCat ürünleri görünmüyor | Play track, license tester, current offering, monthly/annual packages ve entitlement `KoruBeni Pro` kontrol edilir |
| Internal testing upload hazır değil | Signed AAB, Play forms, RevenueCat/Play setup ve app content hazırlığı tamamlanmadan hazır sayılmaz |
