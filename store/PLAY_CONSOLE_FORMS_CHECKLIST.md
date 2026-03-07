# Play Console Formları - Birleşik Kontrol Listesi

Play Console'da doldurulacak formlar ve ilgili rehberler.

---

## Öncelik Sırası

1. **Data Safety** — Zorunlu
2. **Content Rating** — Zorunlu  

---

## 1. Data Safety

**Yol:** Policy → App content → Data safety

**Rehber:** [DATA_SAFETY_FORM.md](DATA_SAFETY_FORM.md)

| Adım | Durum |
|------|-------|
| Does your app collect or share data? | Yes |
| Konum (approximate, precise) | Collected, shared with emergency contacts |
| Personal info (optional profile name/photo) | Device-only |
| Contacts | Collected, device-stored |
| Audio | Optional, not shared |
| App activity (crash, analytics) | Not collected |
| Encryption in transit | Do not answer "Yes" for SMS-based emergency delivery |
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

---

## Tüm Formlar Tamamlandığında

- [ ] Data Safety gönderildi
- [ ] Content Rating sertifikası alındı
