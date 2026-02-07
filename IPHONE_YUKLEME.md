# 📱 KORUBENI - iPhone'a YÜKLEME REHBERİ

## ⚠️ ÖNEMLİ: iPhone'a Uygulama Yükleme

iPhone'a uygulama yüklemek Android'den daha karmaşık. İşte seçeneklerin:

---

## 🎯 SEÇENEK 1: TestFlight (Önerilen - Aileye Dağıtım İçin)

**Gereksinimler:**
- Apple Developer hesabı (99$/yıl)
- TestFlight uygulaması (App Store'dan ücretsiz)

**Avantajlar:**
- ✅ Bilgisayara bağlamadan yüklenebilir
- ✅ Aileye kolayca gönderebilirsin (100 kişiye kadar)
- ✅ Otomatik güncellemeler
- ✅ Profesyonel görünüm

**Adımlar:**
1. Apple Developer hesabı aç (developer.apple.com)
2. App Store Connect'te uygulamayı oluştur
3. Xcode'dan Archive yap → TestFlight'a yükle
4. TestFlight link'ini paylaş
5. Aile üyeleri TestFlight uygulamasından yükler

---

## 🎯 SEÇENEK 2: Xcode'dan Direkt Yükleme (Ücretsiz)

**Gereksinimler:**
- Mac bilgisayar
- iPhone USB kablosu
- Xcode (ücretsiz, App Store'dan)

**Avantajlar:**
- ✅ Ücretsiz
- ✅ Apple Developer hesabı gerekmez

**Dezavantajlar:**
- ❌ Her telefona USB ile bağlaman gerekiyor
- ❌ 7 günde bir yeniden imzalaman gerekiyor
- ❌ Aileye göndermek zor

**Adımlar:**
1. Xcode'u aç
2. `ios/Runner.xcworkspace` dosyasını aç
3. iPhone'u USB ile bağla
4. Product → Run (veya Cmd+R)
5. Uygulama telefona yüklenir

**Not:** 7 günde bir yeniden imzalaman gerekecek.

---

## 🎯 SEÇENEK 3: Ad-Hoc Distribution (Apple Developer Gerekli)

**Gereksinimler:**
- Apple Developer hesabı (99$/yıl)
- Her telefonun UDID'si gerekiyor

**Avantajlar:**
- ✅ USB bağlantısı gerekmez
- ✅ 100 cihaza kadar dağıtabilirsin

**Dezavantajlar:**
- ❌ Her telefonun UDID'sini Apple'a kaydetmen gerekiyor
- ❌ Kurulum biraz karmaşık

---

## 💡 ÖNERİM: TestFlight

Aileye dağıtmak için en kolay yol **TestFlight**. 

**Maliyet:** 99$/yıl (Apple Developer)

**Avantajlar:**
- Herkes kendi telefonuna kolayca yükler
- Güncellemeler otomatik gelir
- Profesyonel görünüm
- Store'a çıkmadan önce test edebilirsin

---

## 🚀 HEMEN BAŞLA: iOS Build Al

Terminal'de şunu çalıştır:

```bash
cd /Users/poyrazoncel/Desktop/guvenlik_app
flutter build ios --release --dart-define=ENV=production --dart-define=ENCRYPTION_KEY=$ENCRYPTION_KEY
```

Sonra Xcode'da:
1. `ios/Runner.xcworkspace` dosyasını aç
2. Product → Archive
3. Distribute App → TestFlight veya Ad-Hoc

---

## ❓ HANGİSİNİ SEÇMELİYİM?

- **Sadece kendin için:** Xcode'dan direkt yükle (ücretsiz, USB gerekli)
- **Aileye göndermek için:** TestFlight (99$/yıl, en kolay)
- **Store'a çıkmak için:** TestFlight → App Store (99$/yıl)

Hangi yolu seçmek istersin?
