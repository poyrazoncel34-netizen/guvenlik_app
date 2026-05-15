# Play Store Internal Testing → İncelemeye Gönder Rehberi

Plan Madde 6-7: AAB build, Internal Testing yükleme, inceleme gönderimi.

Status: OPERATOR_ACTION. This guide describes manual steps only; this repo audit did not create keystores/secrets, build a signed AAB, upload to Play Console, or run device/billing flows.

**Related guides:**

- For tester-facing onboarding (the invitation message you send to the 12 closed-test testers, with install steps, 14-day commitment, test scenarios, "do not call real 112" warning, and feedback form structure), see [`CLOSED_TEST_TESTER_GUIDE.md`](CLOSED_TEST_TESTER_GUIDE.md). The current file (operator-facing) covers signed-AAB build and Play Console upload only.

---

## Ön Koşullar

- [ ] `android/key.properties` operator tarafından dolduruldu (storePassword, keyPassword, storeFile, keyAlias)
- [ ] Store icon 512x512 PNG operator tarafından Play Console'da doğrulandı
- [ ] ENCRYPTION_KEY operator secret store / local secure process ile hazırlandı
- [ ] REVENUECAT_ANDROID_API_KEY operator tarafından RevenueCat'ten alındı
- [ ] RevenueCat / Google Play Billing setup `store/BILLING_RELEASE_CHECKLIST.md` ile test için hazır

---

## 1. AAB Build Al

```bash
ENCRYPTION_KEY='base64_key_buraya' REVENUECAT_ANDROID_API_KEY='goog_...' ./scripts/release_to_play_store.sh
```

veya:

```bash
ENCRYPTION_KEY='base64_key_buraya' REVENUECAT_ANDROID_API_KEY='goog_...' ./scripts/build_production.sh
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
- [ ] **Data Safety** formu dolduruldu
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

## Sorun Giderme

| Hata | Çözüm |
|------|-------|
| key.properties bulunamadı | Operator secure release-signing prosedürünü kullanmalı; repo audit keystore/secret oluşturmaz |
| RevenueCat ürünleri görünmüyor | Play track, license tester, current offering, monthly/annual packages ve entitlement `KoruBeni Pro` kontrol edilir |
| Internal testing upload hazır değil | Signed AAB, Play forms, RevenueCat/Play setup ve app content hazırlığı tamamlanmadan hazır sayılmaz |
