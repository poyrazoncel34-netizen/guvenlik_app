# iPhone’a Korubeni Yükleme – Kısa Rehber

iPhone’da uygulama **APK gibi dosya göndererek** yüklenemez. İki pratik yol var:

---

## 1. USB ile (Ücretsiz – Önerilen)

**Bir kez** iPhone’u Mac’e kablo ile bağlaman yeterli. Yüklemeden sonra kablo çıkarılabilir, uygulama normal çalışır.

1. **iOS build’i hazırla** (proje klasöründe):
   ```bash
   flutter build ios --release
   ```
2. **Xcode’u aç** → `ios/Runner.xcworkspace` dosyasını aç.
3. **Signing:** Runner → Signing & Capabilities → "Automatically manage signing" → Team olarak Apple ID’ni seç (ücretsiz).
4. **iPhone’u USB ile bağla** → Xcode üstünden cihaz olarak iPhone’u seç → **Product → Run** (veya Cmd+R).
5. İlk seferde iPhone’da: **Ayarlar → Genel → VPN ve Cihaz Yönetimi** → Geliştirici uygulamasına **Güven** de.

**Not:** Bu yöntemle yüklenen uygulama **7 günde bir** yeniden imzalanmalı (iPhone’u tekrar bağlayıp Xcode’dan Run).

---

## 2. Kablo Olmadan: TestFlight

Telefonu hiç bilgisayara bağlamak istemiyorsan **TestFlight** kullanılır.

- **Gereksinim:** Apple Developer hesabı (99$/yıl).
- **Akış:** Xcode’da Archive → App Store Connect’e yükle → TestFlight’ta testçi ekle → iPhone’da **TestFlight** uygulamasından linke tıklayıp yükle.
- **Avantaj:** Kablo gerekmez, güncellemeler TestFlight üzerinden gelir.

Detaylar: `IPHONE_YUKLEME.md` dosyasındaki TestFlight bölümü.

---

## Özet

| Yöntem      | Kablo      | Ücret   | Not                          |
|------------|------------|--------|------------------------------|
| Xcode + USB | İlk yükleme | Ücretsiz | 7 günde bir yeniden imzala   |
| TestFlight | Gerekmez   | 99$/yıl | Kablo hiç gerekmez           |

**Sadece kendi iPhone’un için:** USB ile Xcode’dan yükle (1. seçenek).  
**Kablo hiç kullanmak istemiyorsan:** TestFlight için Apple Developer hesabı gerekir (2. seçenek).
