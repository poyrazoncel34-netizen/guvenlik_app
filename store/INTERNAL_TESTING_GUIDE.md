# Play Store Internal Testing → İncelemeye Gönder Rehberi

Plan Madde 6-7: AAB build, Internal Testing yükleme, inceleme gönderimi.

Status: NEEDS_OPERATOR_ACTION / PLAY_CONSOLE / SIGNING / REVENUECAT / NEEDS_REAL_DEVICE_TEST. This guide describes manual steps only; this repo audit did not create keystores/secrets, build a signed AAB, upload to Play Console, configure RevenueCat, or run device/billing flows.

Data Safety nuance: Play Console internal testing may be exempt from the Data Safety section depending on account/app state. Closed testing, open testing, and production require Data Safety where Play Console presents it. Legal/privacy docs must still match the build before internal testing.

**Related guides:**

- For tester-facing onboarding (the invitation message you send to the 12 closed-test testers, with install steps, 14-day commitment, test scenarios, "do not call real 112" warning, and feedback form structure), see [`CLOSED_TEST_TESTER_GUIDE.md`](CLOSED_TEST_TESTER_GUIDE.md). The current file (operator-facing) covers signed-AAB build and Play Console upload only.

---

## Ön Koşullar

- [ ] `android/key.properties` operator tarafından dolduruldu (storePassword, keyPassword, storeFile, keyAlias)
- [ ] Store icon 512x512 PNG operator tarafından Play Console'da doğrulandı
- [ ] GitHub release secret'ları ve `EXPECTED_UPLOAD_CERT_SHA256` operatör tarafından doğrulandı
- [ ] `REVENUECAT_ANDROID_API_KEY` RevenueCat'ten `goog_` Android **public SDK key** olarak alındı (`test_`/`sk_` kullanılmaz)
- [ ] RevenueCat / Google Play Billing setup `store/BILLING_RELEASE_CHECKLIST.md` ile test için hazır
- [ ] Play Console Data Safety durumu kontrol edildi; closed/open/production için Data Safety formu hazırlanıp gönderilecek
- [ ] Real-device QA evidence path hazır: `store/REAL_DEVICE_QA_MATRIX.md`

---

## 1. AAB Build Al

```bash
REVENUECAT_ANDROID_API_KEY=<redacted-public-sdk-key> ./scripts/release_to_play_store.sh
```

veya:

```bash
REVENUECAT_ANDROID_API_KEY=<redacted-public-sdk-key> ./scripts/build_production.sh
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
- [ ] First release base plans have no free-trial/introductory offer; adding one requires a separately approved paywall disclosure change
- [ ] Purchase, restore, cancel/manage, expired/lapsed, renewal/lapse, account hold/paused if available, no-offering fallback, and network-failure fallback are tested on physical devices
- [ ] Screenshots/video/log excerpts are saved with account emails, order IDs, phone numbers, and location data redacted

## 6. Real-Device QA Evidence

Status: NEEDS_REAL_DEVICE_TEST.

- [ ] API 29 arm64 boundary phone: CALL_PHONE/notification/exact alarm, Safe Walk, Check-In, map and process-death rows
- [ ] API 36 Pixel/AOSP with 16 KB kernel: install without compat mode, Direct Boot, Doze and permission rows
- [ ] Samsung One UI and Xiaomi/HyperOS API 34/35+: 100 deadline, 50 cancel-race and 20 process-kill/Doze/reboot repetitions
- [ ] Pool includes one dual-SIM and one low-memory phone
- [ ] No SIM / airplane mode emergency behavior documented without unintended emergency call
- [ ] Uploaded AAB manifest/permissions confirm no foreground-service entry; stale Console draft removed
- [ ] Pre-launch report reviewed after Play upload; findings triaged before production
- [ ] CI/release logs reviewed after a real release workflow run for secret leakage

---

## Sorun Giderme

| Hata | Çözüm |
|------|-------|
| key.properties bulunamadı | Operator secure release-signing prosedürünü kullanmalı; repo audit keystore/secret oluşturmaz |
| RevenueCat ürünleri görünmüyor | Play track, license tester, current offering, monthly/annual packages ve entitlement `KoruBeni Pro` kontrol edilir |
| Internal testing upload hazır değil | Signed AAB, Play forms, RevenueCat/Play setup ve app content hazırlığı tamamlanmadan hazır sayılmaz |
