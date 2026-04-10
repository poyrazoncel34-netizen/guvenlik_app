# Google Play Data Safety Section — Form Yanıtları

## Veri Toplama
- Uygulama kullanıcıdan veri topluyor mu? **EVET** (cihazda kalır, sunucuya gönderilmez)

---

## Toplanan Veri Türleri

### Konum
- Yaklaşık konum: **EVET**
- Kesin konum: **EVET**
- Toplama amacı: Uygulama işlevselliği (acil durum konum paylaşımı)
- Zorunlu mu: **EVET**
- Paylaşılıyor mu: **HAYIR** (yalnızca kullanıcının seçtiği kişilere telefon araması ile — üçüncü taraf sunucuya değil)
- İşleme: Cihazda geçici (acil durum sırasında)

### Kişisel Bilgiler
- Ad: **EVET**
  - Toplama amacı: Uygulama işlevselliği (profil / acil durum mesajı)
  - Zorunlu mu: **HAYIR**
  - Paylaşılıyor mu: **HAYIR**
  - İşleme: Cihazda (SQLite)

- Telefon numarası: **EVET** (acil durum kişileri)
  - Toplama amacı: Uygulama işlevselliği (acil durum araması)
  - Zorunlu mu: **EVET**
  - Paylaşılıyor mu: **HAYIR**
  - İşleme: Cihazda (SQLite)

### Fotoğraf ve Video
- Fotoğraf: **EVET** (profil fotoğrafı — opsiyonel)
  - Toplama amacı: Uygulama işlevselliği (profil)
  - Zorunlu mu: **HAYIR**
  - Paylaşılıyor mu: **HAYIR**
  - İşleme: Cihazda

---

## Güvenlik Uygulamaları

| Konu | Durum |
|------|-------|
| Veri aktarım sırasında şifreleniyor mu? | Uygulamanın kendi veri akışı yok. Acil arama operatör kanalı üzerinden yapılır. |
| Veri silinebilir mi? | **EVET** — uygulama içinden tam silme mevcut |
| Veri sunucuya gönderilmiyor | **DOĞRU** — tamamen offline, sıfır bulut bağlantısı |
| Veri üçüncü tarafla paylaşılmıyor | **DOĞRU** — analytics, crashlytics, reklam servisi yok |

---

## Üçüncü Taraf Kütüphaneler

| Kütüphane | Amaç | Veri Topluyor mu? |
|-----------|-------|-------------------|
| OpenStreetMap (flutter_map) | Harita görüntüleme (tile download) | Hayır (kullanıcı verisi iletilmez) |

Firebase / Google Analytics / Crashlytics: **KULLANILMIYOR**

---

## Play Console Veri Güvenliği Formu — Özet Cevaplar

- **Kullanıcı verileri paylaşılıyor mu?** HAYIR
- **Kullanıcı verileri toplanıyor mu?** EVET (cihazda)
- **Veriler şifreli aktarılıyor mu?** UYGULANAMAZ (sunucu bağlantısı yok)
- **Kullanıcı veri silme talebinde bulunabilir mi?** EVET
- **Uygulama güvenlik ihlallerini nasıl ele alıyor?** Sunucu yok, yerel veri SQLite'ta şifreli depolanıyor (flutter_secure_storage)
