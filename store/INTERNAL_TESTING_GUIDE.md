# Play Store Internal Testing → İncelemeye Gönder Rehberi

Plan Madde 6-7: AAB build, Internal Testing yükleme, inceleme gönderimi.

---

## Ön Koşullar

- [ ] `android/key.properties` dolduruldu (storePassword, keyPassword, storeFile, keyAlias)
- [ ] `android/app/google-services.json` indirildi
- [ ] `assets/icon/app_icon.png` mevcut
- [ ] ENCRYPTION_KEY hazır (`openssl rand -base64 32`)

---

## 1. AAB Build Al

```bash
ENCRYPTION_KEY='base64_key_buraya' ./scripts/release_to_play_store.sh
```

veya:

```bash
ENCRYPTION_KEY='base64_key_buraya' ./scripts/build_production.sh
```

**Çıktı:** `build/app/outputs/bundle/release/app-release.aab`

---

## 2. Internal Testing'e Yükle

1. [Play Console](https://play.google.com/console) → Uygulamanızı seçin
2. **Release** → **Testing** → **Internal testing**
3. **Create new release**
4. **App bundles** → Upload → `app-release.aab` dosyasını seçin
5. **Release name** ve **Release notes** girin
6. **Save** → **Review release**

---

## 3. Store Bilgileri Kontrolü

İncelemeye göndermeden önce:

- [ ] **Store listing** tamam (başlık, açıklama, Privacy Policy URL, screenshots)
- [ ] **Data Safety** formu dolduruldu
- [ ] **Content Rating** sertifikası alındı
- [ ] **SMS Permission Declaration** formu dolduruldu (+ demo video)

---

## 4. İncelemeye Gönder

1. Internal testing release sayfasında **Start rollout to Internal testing**
2. Tüm uyarıları giderin
3. **Send for review** / **İncelemeye gönder**

---

## Sorun Giderme

| Hata | Çözüm |
|------|-------|
| key.properties bulunamadı | `cp android/key.properties.example android/key.properties` → değerleri düzenle |
| google-services.json bulunamadı | Firebase Console → Android app → Download |
| Keystore bulunamadı | `cd android && keytool -genkey -v -keystore korubeni-release-key.jks ...` |
