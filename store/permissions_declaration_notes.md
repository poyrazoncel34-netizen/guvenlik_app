# Google Play Permissions Declaration Form — Hazırlık Notları

## Özet: Hangi İzinler Declaration Form Gerektirir?

| İzin | Manifest'te Var mı? | Declaration Gerekiyor mu? |
|------|---------------------|--------------------------|
| SEND_SMS | **HAYIR** | **HAYIR** — SMS composer intent kullanılıyor |
| CALL_PHONE | EVET | EVET — aşağıda açıklanmıştır |
| ACCESS_BACKGROUND_LOCATION | **HAYIR** | **HAYIR** — manifest'ten kaldırıldı |
| REQUEST_IGNORE_BATTERY_OPTIMIZATIONS | EVET | EVET — aşağıda açıklanmıştır |

---

## SEND_SMS — Declaration GEREKMEZ

**Neden manifest'te yok?**
Uygulama, direkt SMS göndermek yerine kullanıcının varsayılan SMS uygulamasını önceden doldurulmuş mesajla açar.
Bu yaklaşım `android.intent.action.SENDTO` intent'i kullanır ve `SEND_SMS` izni **gerektirmez**.

**Avantajlar:**
- Play Store'da kısıtlı izin beyanı gerekmez
- Kullanıcı SMS göndermeden önce içeriği görebilir ve onaylayabilir
- Daha az Play Store review engeli

**Alternatif (uygulanmadı):**
Direkt SMS (`SmsManager.sendTextMessage`) için `SEND_SMS` gerekir ve SMS Permission Declaration Form doldurulması şarttır.

---

## CALL_PHONE Beyanı

**Beyan kategorisi:** Safety / Emergency

**Core functionality açıklaması:**
"Acil durum tetiklendiğinde kullanıcının belirlediği acil durum kişisini aramak için kullanılır. Kullanıcı panik butonunu tetikler, uygulama önce SMS composer'ı açar, ardından telefon araması yapar. Kullanıcı bilinçsiz veya hareket edemez durumda olabileceğinden otomatik arama kritiktir."

**Neden gerekli:**
Acil durumda kullanıcı telefonu kullanamıyor olabilir. Otomatik arama, yardım çağırmanın en güvenilir yoludur.

**Alternatif:**
`ACTION_DIAL` intent kullanılabilir (izin gerektirmez, kullanıcı onayı gerekir). Ancak kullanıcı bilincini yitirmişse bu alternatif işe yaramaz. Bu nedenle `CALL_PHONE` kullanılmaktadır.

---

## REQUEST_IGNORE_BATTERY_OPTIMIZATIONS Beyanı

**Core functionality açıklaması:**
"KoruBeni'nin güvenli yürüyüş özelliği, kullanıcı check-in yapmazsa arka planda acil durum tetiklemesi yapabilmek için 7/24 çalışması gereken bir zamanlayıcı servisi içerir. Pil optimizasyonu bu servisi durdurursa kullanıcı tehlikede olduğunda bildirimi gönderemeyiz."

**Neden gerekli:**
Kullanıcı güvenli yürüyüş başlattığında, belirtilen süre içinde check-in yapmazsa otomatik acil durum tetiklenmesi gerekir. Bu Android'in normal doze/standby modlarında kesilebilir.

---

## Background Location — Declaration GEREKMEZ

Background location izni (`ACCESS_BACKGROUND_LOCATION`) manifest'ten kaldırılmıştır.
Güvenli yürüyüş özelliği, arka planda konum takibi yapmaz; yalnızca acil durum tetiklendiğinde anlık konum alır.

---

## Video Demo Gereksinimleri (SMS Declaration Form için)

Declaration Form'da SMS izni beyan edilmediği için video demo gerekmez.
Ancak genel Play Store inceleme sürecinde hazır bulundurulması önerilen demo:

**1-3 dakikalık ekran kaydı içeriği:**
1. İlk açılış → KVKK/yasal onay akışı
2. Acil durum kişisi ekleme
3. Panik butonu tetikleme → SMS composer açılması
4. Güvenli yürüyüş başlatma ve check-in
5. Ayarlar → veri silme

---

## Güncelleme Geçmişi

- 2026-03-18: İlk oluşturma. SEND_SMS manifest'ten kaldırıldı, SMS composer intent yaklaşımı benimsendi.
