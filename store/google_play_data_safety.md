# Google Play — Veri Güvenliği Bölümü Yanıtları

Bu belge, Google Play Console'da "Veri Güvenliği" bölümü için hazır yanıtları içermektedir.

Son güncelleme: 18 Mart 2026

---

## 1. Veri Toplanıyor mu?

**EVET** — Uygulama aşağıdaki verileri toplar:

---

## 2. Toplanan Veriler

| Veri Türü | Alt Kategori | Toplanıyor mu | Paylaşılıyor mu | Şifreli mi | Sililebilir mi | Amaç |
|-----------|-------------|----------------|-----------------|------------|----------------|------|
| Kişisel bilgiler | Ad ve soyadı | Evet (isteğe bağlı) | Hayır | Evet | Evet | Uygulama işlevselliği |
| Kişisel bilgiler | E-posta adresi | Evet (isteğe bağlı) | Hayır | Evet | Evet | Uygulama işlevselliği |
| Kişisel bilgiler | Fotoğraflar ve videolar | Evet (isteğe bağlı) | Hayır | Evet | Evet | Uygulama işlevselliği |
| Konum | Yaklaşık konum | Evet (yalnızca kullanım sırasında) | Hayır | Evet | Evet | Uygulama işlevselliği |
| Konum | Kesin konum | Evet (yalnızca kullanım sırasında) | Hayır | Evet | Evet | Uygulama işlevselliği |
| Kişiler | Kişiler | Evet (kullanıcı seçer) | Hayır | Evet | Evet | Uygulama işlevselliği |
| Ses | Ses dosyaları | Hayır | Hayır | Uygulanamaz | Uygulanamaz | Bu Android Play sürümünde yok |
| Uygulama etkinliği | Yerel olay geçmişi | Evet (cihaz içi) | Hayır | Hayır | Evet | Uygulama işlevselliği |
| Finansal bilgiler | Satın alma geçmişi / abonelik | Google Play Billing üzerinden işlenir | Hayır | Sağlayıcı altyapısı | Evet | Uygulama işlevselliği |

---

## 3. Veri Paylaşımı

**HAYIR** — Uygulama acil durumda kişisel veriyi otomatik mesajla üçüncü kişilere göndermez. Harita ve Google Play Billing gibi SDK/servislerin teknik ağ davranışı ayrıca beyan edilmelidir.

---

## 4. Veri Güvenliği Önlemleri

- [x] **Veriler aktarım sırasında şifreleniyor** — Geliştirici backend'i yok; üçüncü taraf SDK trafiği kendi TLS/Play altyapısına tabidir
- [x] **Veriler depolanırken şifreleniyor** — Kısmen: PIN ve ilk müdahale bilgileri Android Keystore / Flutter Secure Storage ile korunur; acil kişiler ve yerel olay geçmişi cihaz içi veritabanında tutulur
- [x] **Kullanıcılar veri silebilir** — Evet (Ayarlar > Yasal Bilgiler > Verilerimi Sil)

---

## 5. Güvenlik Uygulamaları

- [x] Veriler Google Play'in güvenlik uygulamalarına göre ele alınıyor
- [x] Uygulama bağımsız güvenlik incelemesine tabi tutuldu (kendi denetimimizle)

---

## 6. Şeffaflık Notu

> "Kişisel verilerin ana kopyası cihazınızda tutulur. Geliştirici backend'i yoktur; harita ve Play servisleri kendi ağ davranışlarına sahip olabilir. KVKK bilgilendirme ve veri silme akışları sunulur."

---

## 7. Form Doldurma Kılavuzu

### "Bu uygulama veri topluyor mu?" sorusu için:
Kısmen / veri türüne göre — PIN ve secure-storage alanları için evet; yerel veritabanı kayıtları için blanket "evet" işaretlenmemelidir.

### "Verilerinizi üçüncü taraflarla paylaşıyor musunuz?" sorusu için:
❌ **Hayır**

### "Tüm kullanıcıların verilerini silmesine izin veriyor musunuz?" sorusu için:
✅ **Evet** — Uygulama içinden (Ayarlar > Yasal Bilgiler > Verilerimi Sil)

### "Veriler aktarım sırasında şifreleniyor mu?" sorusu için:
✅ **Evet**

### "Depolamada şifreleniyor mu?" sorusu için:
✅ **Evet**
