# Google Play Permissions Declaration Form — Hazırlık Notları

## Özet: Hangi İzinler Declaration Form Gerektirir?

| İzin | Manifest'te Var mı? | Declaration Gerekiyor mu? |
|------|---------------------|--------------------------|
| Mesaj gönderim izni | **HAYIR** | **HAYIR** — mesaj gönderimi bu Android Play sürümünde yok |
| CALL_PHONE | EVET | EVET — aşağıda açıklanmıştır |
| ACCESS_BACKGROUND_LOCATION | **HAYIR** | **HAYIR** — manifest'ten kaldırıldı |
| REQUEST_IGNORE_BATTERY_OPTIMIZATIONS | EVET | EVET — aşağıda açıklanmıştır |

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
Acil durumda kullanıcı telefonu kullanamıyor olabilir. Otomatik arama, yardım çağırmanın en güvenilir yoludur.

**Alternatif:**
`ACTION_DIAL` intent kullanılabilir (izin gerektirmez, kullanıcı onayı gerekir). Ancak kullanıcı bilincini yitirmişse bu alternatif işe yaramaz. Bu nedenle `CALL_PHONE` kullanılmaktadır.

---

## REQUEST_IGNORE_BATTERY_OPTIMIZATIONS Beyanı

**Core functionality açıklaması:**
"KoruBeni'nin güvenli yürüyüş/check-in özelliği, kullanıcı uygulama açıkken başlattığı oturumlarda zamanlayıcı ve bildirim desteği kullanır. Android pil optimizasyonu bu yardımcı akışı kısıtlayabilir; uygulama bunu garanti bir acil servis olarak sunmaz ve kullanıcıya degraded davranışı açıklar."

**Neden gerekli:**
Kullanıcı güvenli yürüyüş başlattığında, belirtilen süre içinde check-in yapmazsa otomatik acil durum tetiklenmesi gerekir. Bu Android'in normal doze/standby modlarında kesilebilir.

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
