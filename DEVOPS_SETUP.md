# 🚀 OTOMASYON KURULUM REHBERİ (DevOps)

Uygulamanın Store'lara otomatik çıkabilmesi için GitHub Secrets ve bazı dosyaların hazırlanması gerekiyor.

## 1. Android İçin Gerekenler

### 1.1. Google Play Console API Key
1. Google Play Console > Setup > API Access sayfasına git.
2. Yeni bir Service Account oluştur ve JSON key indir.
3. Bu dosyanın içeriğini Base64'e çevir:
   ```bash
   base64 -i indirdigin-api-key.json | pbcopy
   ```
4. GitHub Repo > Settings > Secrets and variables > Actions > New Request Secret:
   - Name: `ANDROID_JSON_KEY_BASE64`
   - Value: (Kopyaladığın değer)

### 1.2. Keystore Dosyası
1. `android/korubeni-release-key.jks` dosyasını Base64'e çevir:
   ```bash
   base64 -i android/korubeni-release-key.jks | pbcopy
   ```
2. GitHub Secret Ekle:
   - Name: `ANDROID_KEYSTORE_BASE64`
   - Value: (Kopyaladığın değer)

### 1.3. Key Properties
1. `android/key.properties` dosyasının içeriğini kopyala.
2. GitHub Secret Ekle:
   - Name: `ANDROID_KEY_PROPERTIES`
   - Value: (Dosya içeriği)

### 1.4. Encryption Key
1. Eğer belirlediysen encryption key'i ekle, yoksa `STORE_CIKIS_REHBERI.md`'deki adımla üret.
2. GitHub Secret Ekle:
   - Name: `ENCRYPTION_KEY`
   - Value: (Key değeri)

## 2. iOS İçin Gerekenler (Daha Karmaşık)
iOS için "Fastlane Match" kurulumu öneriyorum. Şimdilik CI/CD'de iOS adımını kapalı (`if: false`) bıraktım. Sertifikalar hazır olunca açabiliriz.

## 3. Nasıl Çalıştırılır?
GitHub'da "Actions" sekmesine git -> "Deploy to Store" sol menüden seç -> "Run workflow" butonuna bas.

✅ Başarılı olursa 15 dakika içinde Google Play Console'da "Internal Testing" kanalında yeni sürümü göreceksin!
