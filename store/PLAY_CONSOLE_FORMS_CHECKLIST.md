# Play Console Formları - Birleşik Kontrol Listesi

Play Console'da doldurulacak formlar ve ilgili rehberler.

---

## Öncelik Sırası

1. **Data Safety** — Zorunlu
2. **Content Rating** — Zorunlu  
3. **SMS Permission Declaration** — Zorunlu (SEND_SMS kullanıldığı için)

---

## 1. Data Safety

**Yol:** Policy → App content → Data safety

**Rehber:** [DATA_SAFETY_FORM.md](DATA_SAFETY_FORM.md)

| Adım | Durum |
|------|-------|
| Does your app collect or share data? | Yes |
| Konum (approximate, precise) | Collected, shared with emergency contacts |
| Personal info (name, email, phone, user ID) | Collected |
| Contacts | Collected, device-stored |
| Audio | Optional, not shared |
| App activity (crash, analytics) | Collected via Firebase |
| Encryption in transit | Yes |
| Users can request deletion | Yes |

---

## 2. Content Rating

**Yol:** Policy → App content → Content rating

**Rehber:** [CONTENT_RATING_ANSWERS.md](CONTENT_RATING_ANSWERS.md)

| Kategori | Yanıt |
|----------|-------|
| Violence | None |
| Sexual content | None |
| Language | None |
| Controlled substances | None |
| Fear/Horror | None |
| Shares location | Yes — only when user triggers |
| Social interaction | Yes — emergency contacts |

**Beklenen sonuç:** PEGI 3 / Everyone

---

## 3. SMS Permission Declaration

**Yol:** Policy → App content → Permissions declarations

**Rehber:** [SMS_PERMISSION_DECLARATION.md](SMS_PERMISSION_DECLARATION.md)

| Adım | Durum |
|------|-------|
| Restricted permission | SEND_SMS |
| Form yanıtları kopyala-yapıştır | Rehberden |
| Demo video (30-60 sn) | YouTube unlisted yükle |
| Video linkini forma yaz | |

**Önemli:** Panik butonu akışını gösteren ekran kaydı zorunludur.

---

## Tüm Formlar Tamamlandığında

- [ ] Data Safety gönderildi
- [ ] Content Rating sertifikası alındı
- [ ] SMS Permission Declaration formu dolduruldu ve video eklendi
