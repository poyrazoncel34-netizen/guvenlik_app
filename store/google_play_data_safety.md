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
| Ses | Ses dosyaları | Evet (kullanıcı başlatır, isteğe bağlı) | Hayır | Evet | Evet | Uygulama işlevselliği |
| Uygulama etkinliği | Uygulama etkileşimleri | Evet (yerel log) | Hayır | Evet | Evet | Analitik (yerel) |

---

## 3. Veri Paylaşımı

**HAYIR** — Uygulama acil durumda kişisel veriyi otomatik mesajla üçüncü kişilere göndermez. Harita, billing ve üretimde açıkça yapılandırılmış crash reporting gibi SDK/servislerin teknik ağ davranışı ayrıca beyan edilmelidir.

---

## 4. Veri Güvenliği Önlemleri

- [x] **Veriler aktarım sırasında şifreleniyor** — Geliştirici backend'i yok; üçüncü taraf SDK trafiği kendi TLS/Play altyapısına tabidir
- [x] **Veriler depolanırken şifreleniyor** — Evet (Android Keystore / Flutter Secure Storage; yerel DB için backup kapalı ve veri yüzeyi azaltılmıştır)
- [x] **Kullanıcılar veri silebilir** — Evet (Ayarlar > Yasal Bilgiler > Verilerimi Sil)

---

## 5. Güvenlik Uygulamaları

- [x] Veriler Google Play'in güvenlik uygulamalarına göre ele alınıyor
- [x] Uygulama bağımsız güvenlik incelemesine tabi tutuldu (kendi denetimimizle)

---

## 6. Şeffaflık Notu

> "Tüm verileriniz cihazınızda kalır. Hiçbir sunucuya gönderilmez. KVKK uyumlu. Verilerinizi istediğiniz zaman silebilirsiniz."

---

## 7. Form Doldurma Kılavuzu

### "Bu uygulama veri topluyor mu?" sorusu için:
✅ **Evet**

### "Verilerinizi üçüncü taraflarla paylaşıyor musunuz?" sorusu için:
❌ **Hayır**

### "Tüm kullanıcıların verilerini silmesine izin veriyor musunuz?" sorusu için:
✅ **Evet** — Uygulama içinden (Ayarlar > Yasal Bilgiler > Verilerimi Sil)

### "Veriler aktarım sırasında şifreleniyor mu?" sorusu için:
✅ **Evet**

### "Depolamada şifreleniyor mu?" sorusu için:
✅ **Evet**
