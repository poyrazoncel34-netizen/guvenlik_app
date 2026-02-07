# ✅ iPhone'da USB'siz Çalışma - Garanti

## 🎯 EVET, USB'SİZ ÇALIŞIR - AMA ŞARTLAR VAR

### ✅ USB ile Yükledikten Sonra:
- ✅ USB'yi çıkarabilirsin
- ✅ Uygulama **bağımsız çalışır**
- ✅ Normal bir uygulama gibi kullanabilirsin
- ✅ Internet'e bağlı olmana gerek yok
- ✅ Mac'e bağlı olmana gerek yok

### ⚠️ AMA DİKKAT: 7 Gün Kuralı

**Personal Team** ile yüklenen uygulamalar:
- ✅ İlk yüklemeden sonra **7 gün** boyunca çalışır
- ⚠️ **7 gün sonra** uygulama açılmaz
- 🔄 **7 günde bir** yeniden imzalaman gerekiyor (USB ile Xcode'dan Run)

---

## 🔍 DÜN NEDEN ÇALIŞMADI?

Muhtemel nedenler:

### 1. Güven Ayarı Eksikti
**Çözüm:**
- iPhone'da: **Ayarlar → Genel → VPN ve Cihaz Yönetimi**
- Geliştirici uygulamasına **"Güven"** de
- Uygulamayı tekrar aç

### 2. Signing Hatası Vardı
**Çözüm:**
- Xcode'da **Signing & Capabilities** sekmesinde
- **"Automatically manage signing"** işaretli olmalı
- **Team:** Apple ID'n görünmeli
- Hata varsa: **"Automatically manage signing"** kapat → aç

### 3. Build Hatası Vardı
**Çözüm:**
- Terminal'de: `flutter clean`
- Xcode'da: Product → Clean Build Folder (Shift+Cmd+K)
- Sonra tekrar: Product → Run

### 4. 7 Gün Geçmişti
**Çözüm:**
- USB ile bağla
- Xcode'da Product → Run
- Yeniden imzalanır, 7 gün daha çalışır

---

## ✅ ŞİMDİ KESIN ÇALIŞMASI İÇİN:

### ADIM 1: Xcode'da Kontrol Et

**Signing & Capabilities sekmesinde:**
- ✅ "Automatically manage signing" **işaretli** olmalı
- ✅ Team: **"Poyraz Öncel (Personal Team)"** görünmeli
- ✅ Bundle Identifier: `com.poyrazoncel.korubeni`
- ✅ Provisioning Profile: "Xcode Managed Profile"
- ✅ Signing Certificate: "Apple Development: poyrazsagaoyun@gmail.com..."

**Eğer hata görürsen:**
- "Automatically manage signing" kapat → aç
- Team dropdown'dan Apple ID'ni tekrar seç

---

### ADIM 2: iPhone'u Bağla ve Yükle

1. iPhone'u USB ile bağla
2. Xcode'un üst kısmında **"Poyraz iPhone"** seçili olmalı
3. **Product → Run** (Cmd+R)
4. İlk kez yapıyorsan iPhone'da:
   - **Ayarlar → Genel → VPN ve Cihaz Yönetimi**
   - Geliştirici uygulamasına **"Güven"** de
5. Uygulama yüklenir ve açılır

---

### ADIM 3: USB'yi Çıkar ve Test Et

1. USB'yi çıkar
2. Uygulamayı aç
3. **Çalışmalı!** ✅

---

## 🔄 7 GÜN SONRA NE OLUR?

7 gün sonra uygulama açılmaz. Şunu yap:

1. USB ile bağla
2. Xcode'da Product → Run
3. Yeniden imzalanır, 7 gün daha çalışır

---

## 💡 DAHA KOLAY ÇÖZÜM: TestFlight

Eğer 7 günde bir USB bağlamak istemiyorsan:

**TestFlight kullan:**
- ✅ USB gerekmez
- ✅ 90 gün çalışır (7 gün değil)
- ✅ Aileye kolayca gönderebilirsin
- ✅ Otomatik güncellemeler
- ⚠️ Apple Developer hesabı gerekir (99$/yıl)

---

## 🎯 ŞİMDİ YAP:

1. Xcode'da **Signing & Capabilities** sekmesini kontrol et
2. Her şey doğruysa → iPhone'u bağla → Product → Run
3. USB'yi çıkar → Uygulamayı aç → Çalışmalı!

Hangi adımda takıldın? Hata mesajı var mı?
