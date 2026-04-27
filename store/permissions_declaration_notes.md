# Google Play Permissions Declaration Form — Hazırlık Notları

## Özet: Hangi İzinler Declaration Form Gerektirir?

| İzin | Manifest'te Var mı? | Declaration Gerekiyor mu? |
|------|---------------------|--------------------------|
| Mesaj gönderim izni | **HAYIR** | **HAYIR** — mesaj gönderimi bu Android Play sürümünde yok |
| CALL_PHONE | EVET | EVET — aşağıda açıklanmıştır |
| READ_PHONE_STATE | **HAYIR** | **HAYIR** — fake call cihaz içi simülasyondur; telefon durumu izni istenmez |
| ACCESS_BACKGROUND_LOCATION | **HAYIR** | **HAYIR** — manifest'ten kaldırıldı |
| REQUEST_IGNORE_BATTERY_OPTIMIZATIONS | EVET | EVET — aşağıda açıklanmıştır |
| SCHEDULE_EXACT_ALARM | EVET | EVET — aşağıda açıklanmıştır |

---

## Mesaj Gönderim İzni — Declaration GEREKMEZ

**Neden manifest'te yok?**
Uygulama bu Android Play sürümünde mesaj göndermez ve mesaj uygulaması açmaz. Manifest'te mesaj gönderim izni veya mesaj intent'i bulunmamalıdır.

**Avantajlar:**
- Kısıtlı mesaj izni beyanı gerekmez
- Kullanıcıya otomatik iletim vaadi verilmez
- Play Store review yüzeyi küçülür

**Alternatif (uygulanmadı):**
Direkt mesaj gönderimi veya mesaj composer bu sürümün kapsamı dışındadır.

---

## CALL_PHONE Beyanı

**Beyan kategorisi:** Safety / Emergency

**Core functionality açıklaması:**
"Acil durum geri sayımı tamamlandığında kullanıcının belirlediği acil durum kişisini aramak için kullanılır. Kullanıcı panik butonunu tetikler, geri sayımı PIN ile iptal etmezse Android arama akışı başlatılır. İzin yoksa arama ekranı açılır ve kullanıcı aramayı manuel onaylar."

**Neden gerekli:**
CALL_PHONE, kullanıcı açıkça tetiklediği panik veya check-in akışında geri sayım tamamlandıktan sonra doğrudan arama denemesi yapmak için kullanılır. Arama bağlantısı garanti edilmez; izin yoksa arama ekranı açılır ve kullanıcı aramayı manuel onaylar.

**Alternatif:**
`ACTION_DIAL` intent kullanılabilir (izin gerektirmez, kullanıcı onayı gerekir). Ancak kullanıcı bilincini yitirmişse bu alternatif işe yaramaz. Bu nedenle `CALL_PHONE` kullanılmaktadır.

---

## REQUEST_IGNORE_BATTERY_OPTIMIZATIONS Beyanı

**Core functionality açıklaması:**
"KoruBeni'nin güvenli yürüyüş/check-in özelliği, kullanıcı uygulama açıkken başlattığı oturumlarda zamanlayıcı ve bildirim desteği kullanır. Android pil optimizasyonu bu yardımcı akışı kısıtlayabilir; uygulama bunu garanti bir acil servis olarak sunmaz ve kullanıcıya degraded davranışı açıklar."

**Neden gerekli:**
Kullanıcı güvenli yürüyüş başlattığında, belirtilen süre içinde check-in yapmazsa yardımcı acil durum akışının tetiklenmesi hedeflenir. Bu akış Android'in doze/standby ve üretici pil kısıtları nedeniyle gecikebilir veya kesilebilir.

---

## SCHEDULE_EXACT_ALARM Beyanı

**Beyan kategorisi:** Safety / Reminders / User-initiated safety timers

**Core functionality açıklaması:**
"KoruBeni, kullanıcı tarafından başlatılan panik geri sayımı, check-in ve güvenli yürüyüş gibi güvenlik zamanlayıcılarında alarmın beklenen zamanda çalışmasına yardımcı olmak için exact alarm kullanır. Bu zamanlayıcılar kullanıcı tarafından başlatılır, güvenlik/reminder amaçlıdır ve reklam, analitik, gizli takip veya keyfi arka plan işi için kullanılmaz."

**Neden gerekli:**
Android Doze, standby ve üretici pil kısıtları Dart timer, foreground service veya inexact alarm davranışını geciktirebilir. Güvenlik zamanlayıcılarında geri sayım/check-in süresi dolduğunda kullanıcının beklediği zamanda uyarı veya yardımcı acil akışın tetiklenmesi gerekir. `SCHEDULE_EXACT_ALARM`, bu kullanıcı başlatmalı safety-timer/reminder akışlarının zamanında çalışması için kullanılır.

**Kullanılmadığı amaçlar:**
- Reklam, pazarlama veya analitik
- Gizli konum takibi veya kullanıcı izleme
- Süresiz/keyfi arka plan işi
- Kullanıcı başlatmamışken arka planda yeni güvenlik oturumu oluşturma

**Fallback / degraded davranış:**
Exact alarm izni yoksa uygulama mümkün olan yerlerde inexact alarm, foreground service ve yerel timer yollarına düşer. İlgili akışlarda zamanlayıcı güvenilirliğinin azalabileceği kullanıcıya açıklanır veya uyarı gösterilir.

---

## Background Location — Declaration GEREKMEZ

Background location izni (`ACCESS_BACKGROUND_LOCATION`) manifest'ten kaldırılmıştır.
Güvenli yürüyüş özelliği, arka planda konum takibi yapmaz; yalnızca acil durum tetiklendiğinde anlık konum alır.

---

## Video Demo Gereksinimleri

Mesaj izni beyan edilmediği için mesaj izni demo videosu yoktur. Genel Play Store inceleme sürecinde hazır bulundurulması önerilen demo:

**1-3 dakikalık ekran kaydı içeriği:**
1. İlk açılış → KVKK/yasal onay akışı
2. Acil durum kişisi ekleme
3. Panik butonu tetikleme → geri sayım → arama akışı / dialer fallback
4. Güvenli yürüyüş başlatma ve check-in
5. Ayarlar → veri silme

---

## Güncelleme Geçmişi

- 2026-04-11: Android Play sürümü mesaj gönderimsiz, call-only panic kontratına hizalandı.
