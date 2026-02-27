# 🚀 KORUBENI - STORE'A ÇIKIŞ REHBERİ

Bu rehber seni App Store ve Google Play Store'a çıkış için adım adım yönlendirecek.

---

## 📋 ADIM 1: GIT REPO KURULUMU (5 dakika)

Terminal'de şu komutları çalıştır:

```bash
cd /Users/poyrazoncel/Desktop/guvenlik_app
git init
git add .
git commit -m "Initial commit: KoruBeni security app - Store ready"
```

**Neden gerekli?** Versiyon kontrolü olmadan store süreci yönetilemez. Her değişikliği takip edebilirsin.

---

## 🔐 ADIM 2: ENCRYPTION KEY BELİRLEME (2 dakika)

Uygulama şifreleme için bir key kullanıyor. Bu key'i belirlemen gerekiyor.

**Seçenek 1: Otomatik key üret (Önerilen)**
```bash
# Terminal'de çalıştır:
openssl rand -base64 32
```

Bu komut sana 32 karakterlik bir base64 key verecek. Örnek: `K9TFyDd47LRrwnh/AxTaXD74vlqGRj3Rjqm9cekKJf8=`

**Seçenek 2: Kendi key'ini belirle**
- En az 32 karakter olmalı
- Base64 formatında olmalı

**Key'i not al!** Build alırken kullanacağız.

---

## 📱 ADIM 3: ANDROID KEYSTORE OLUŞTURMA (5 dakika)

Play Store'a yüklemek için bir keystore dosyası gerekiyor.

```bash
cd /Users/poyrazoncel/Desktop/guvenlik_app/android
keytool -genkey -v -keystore korubeni-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias korubeni
```

**Sorular:**
- **Password:** Güçlü bir şifre belirle (not al!)
- **Name:** Poyraz Öncel (veya kendi adın)
- **Organizational Unit:** (boş bırakabilirsin)
- **Organization:** (boş bırakabilirsin)
- **City:** (şehrin)
- **State:** (eyalet/il)
- **Country:** TR

**ÖNEMLİ:** `key.properties` dosyasını oluştur:

```bash
cd /Users/poyrazoncel/Desktop/guvenlik_app/android
cat > key.properties << EOF
storePassword=BURAYA_KEYSTORE_SIFRENI_YAZ
keyPassword=BURAYA_KEY_SIFRENI_YAZ
keyAlias=korubeni
storeFile=korubeni-release-key.jks
EOF
```

**DİKKAT:** `key.properties` dosyası `.gitignore`'da, repo'ya gitmeyecek. Ama sen yine de kontrol et:
```bash
git check-ignore android/key.properties
```
Eğer hiçbir şey yazmazsa, dosya ignore edilmiyor demektir - bu iyi!

---

## 🏗️ ADIM 4: İLK PRODUCTION BUILD (10 dakika)

**Android AAB (Play Store için):**

```bash
cd /Users/poyrazoncel/Desktop/guvenlik_app

# ENCRYPTION_KEY'i yukarıda ürettiğin key ile değiştir
flutter build appbundle --release \
  --dart-define=ENV=production \
  --dart-define=ENCRYPTION_KEY=BURAYA_KEY_YAZ
```

Build başarılı olursa şu dosya oluşur:
`build/app/outputs/bundle/release/app-release.aab`

**iOS (App Store için):**

```bash
flutter build ios --release \
  --dart-define=ENV=production \
  --dart-define=ENCRYPTION_KEY=BURAYA_KEY_YAZ
```

Sonra Xcode'da:
1. `ios/Runner.xcworkspace` dosyasını aç
2. Product > Archive
3. Distribute App > App Store Connect

---

## 📸 ADIM 5: SCREENSHOT'LAR (30 dakika)

Store'lara screenshot'lar lazım. Şu ekranları yakala:

### Android için:
- **Phone:** 1080x1920px (en az 2 adet)
- **Tablet:** 1200x1920px (opsiyonel)

### iOS için:
- **iPhone 6.7" (iPhone 14 Pro Max):** 1290x2796px
- **iPhone 6.5" (iPhone 11 Pro Max):** 1242x2688px
- **iPad Pro 12.9":** 2048x2732px (opsiyonel)

**Yakalanacak ekranlar:**
1. Ana sayfa (HomePage) - Panic button görünür olmalı
2. Kişiler sayfası (ContactsPage)
3. Harita sayfası (MapPage)
4. Ayarlar sayfası (SettingsPage)

**Nasıl yakalarım?**
- Android: Emulator'de çalıştır, screenshot al
- iOS: Simulator'de çalıştır, Cmd+S ile kaydet

**Screenshot'ları şuraya kaydet:**
```
store/screenshots/android/
store/screenshots/ios/
```

---

## 📄 ADIM 6: PRIVACY POLICY (✅ Tamamlandı)

`store/privacy_policy_template.md` dosyası dolduruldu:
- Tarih: 2026-02-26
- Destek e-postası: destek@korubeni.com

**Privacy Policy canlı URL'ler (GitHub Pages):**
- Türkçe: `https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy.html`
- İngilizce: `https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy_en.html`

**Deploy:** Repo Settings > Pages > Source: GitHub Actions, veya Actions > Deploy Privacy Policy > Run workflow


**Seçenek 2: Kendi websiten**
- HTML'e çevir ve yayınla

**Seçenek 3: Privacy Policy Generator**
- https://www.privacypolicygenerator.info/ kullan

**URL'i not al!** Store formlarında kullanacağız.

---

## 🎯 ADIM 7: GOOGLE PLAY STORE (1 saat)

### 7.1. Google Play Console'a Git
https://play.google.com/console

### 7.2. Yeni Uygulama Oluştur
- Uygulama adı: **KoruBeni**
- Varsayılan dil: **Türkçe**
- Uygulama türü: **Uygulama**
- Ücretsiz mi? **Evet**

### 7.3. Store Listing Doldur
- **Kısa açıklama:** (max 80 karakter)
  ```
  Acil durumlar için güvenlik uygulaması. Panik butonu, konum paylaşımı ve acil kişi bildirimi.
  ```

- **Uzun açıklama:** `store/play_store_listing_tr.md` dosyasındaki metni kopyala

- **Screenshot'ları yükle**

- **Uygulama ikonu:** `assets/icon/app_icon.png` (1024x1024)

- **Özellik grafiği:** (opsiyonel, 1024x500)

### 7.4. Privacy Policy URL
- Yukarıda hazırladığın Privacy Policy URL'ini gir

### 7.5. Data Safety Form
- **Konum verisi:** Evet, paylaşılıyor
- **Kişi bilgileri:** Evet, kullanıcı tarafından ekleniyor
- **Telefon numarası:** Evet, Firebase Auth için
- **Veri şifreleme:** Evet, transit ve at rest

### 7.5.5. ⚠️ SMS Permission Declaration (KRİTİK!)
Uygulama `SEND_SMS` izni kullandığı için Google formu **zorunlu olarak** doldurmanız gerekiyor.
- **Nereye gidilir:** Play Console > App content > Permissions declarations
- **Detaylı rehber:** `store/SMS_PERMISSION_DECLARATION.md` dosyasını takip edin
- **Demo video hazırlanmalı** (panik butonuna basılıp SMS gönderiminin gösterildiği 30-60 sn video)

### 7.6. AAB Dosyasını Yükle
- Production > Create new release
- `app-release.aab` dosyasını yükle
- Release notları: "İlk sürüm - Store'a çıkış"

### 7.7. İnceleme için Gönder
- "İnceleme için gönder" butonuna tıkla
- 1-3 gün içinde onaylanır

---

## 🍎 ADIM 8: APP STORE (1 saat)

### 8.1. App Store Connect'e Git
https://appstoreconnect.apple.com

### 8.2. Yeni Uygulama Oluştur
- Platform: **iOS**
- Ad: **KoruBeni**
- Birincil dil: **Türkçe**
- Bundle ID: **com.poyrazoncel.korubeni**
- SKU: **korubeni-001**

### 8.3. App Information
- Kategori: **Güvenlik**
- Alt kategori: **Kişisel Güvenlik**

### 8.4. Pricing and Availability
- Fiyat: **Ücretsiz**

### 8.5. App Privacy
- **Konum:** Evet, kullanıcı konumu
- **Kişi bilgileri:** Evet, kullanıcı tarafından ekleniyor
- **Telefon numarası:** Evet, kimlik doğrulama için

### 8.6. Screenshot'ları Yükle
- iPhone 6.7" screenshot'larını yükle

### 8.7. App Description
- `store/app_store_listing_tr.md` dosyasındaki metni kullan

### 8.8. Privacy Policy URL
- Yukarıda hazırladığın URL'i gir

### 8.9. Build Yükle
- Xcode'dan Archive yaptıktan sonra "Distribute App" > "App Store Connect"
- Build'i yükle ve beklenen süre: 10-30 dakika

### 8.10. İnceleme için Gönder
- "Submit for Review" butonuna tıkla
- 1-7 gün içinde onaylanır

---

## ✅ SON KONTROL LİSTESİ

- [ ] Git repo kuruldu
- [ ] Encryption key belirlendi ve not edildi
- [ ] Android keystore oluşturuldu
- [ ] `key.properties` dosyası oluşturuldu
- [ ] Production build başarılı (AAB + iOS)
- [ ] Screenshot'lar hazır
- [ ] Privacy Policy canlı URL'i var
- [ ] Play Store listing dolduruldu
- [ ] App Store listing dolduruldu
- [ ] Her iki store'a da gönderildi

---

## 🆘 SORUN GİDERME

### Build hatası alıyorum
```bash
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=ENV=production --dart-define=ENCRYPTION_KEY=xxx
```

### Keystore hatası
- `key.properties` dosyasının doğru yolda olduğundan emin ol
- Şifrelerin doğru olduğundan emin ol

### Firebase hatası
- `google-services.json` ve `GoogleService-Info.plist` dosyalarının doğru olduğundan emin ol

---

## 📞 YARDIM

Herhangi bir adımda takılırsan, bana sor! Beraber çözeriz.

**Önemli Notlar:**
- İlk gönderimde inceleme süresi uzun olabilir (1-7 gün)
- Store reddederse, reddetme nedenini oku ve düzelt
- Her yeni sürüm için build numarasını artır (`scripts/bump_version.sh`)

**Başarılar! 🚀**
