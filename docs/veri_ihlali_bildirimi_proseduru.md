# KoruBeni — Veri İhlali Bildirimi Prosedürü

**Veri Sorumlusu:** Poyraz Öncel — Bireysel Yazılım Geliştirici
**İletişim:** korubeni.destek@gmail.com
**Son Güncelleme:** 2026-03-19
**Versiyon:** 3.0.0

---

## 1. Kapsam

Bu prosedür, KVKK m.12/5 kapsamında kişisel verilerin hukuka aykırı olarak işlenmesi, erişilmesi veya aktarılması durumunda uygulanacak adımları tanımlar.

---

## 2. Uygulama Mimarisi ve Veri İhlali Riski

KoruBeni **tamamen çevrimdışı** çalışan bir mobil uygulamadır:

- **Sunucu yok:** Uygulama hiçbir uzak sunucuya bağlanmaz, API çağrısı yapmaz
- **Veritabanı yok:** Bulut veritabanı veya uzak depolama kullanılmaz
- **Üçüncü taraf servisi yok:** Crash raporlama, analitik veya reklam servisi entegre edilmemiştir
- **Tüm veri cihazda:** Kişisel veriler yalnızca kullanıcının Android cihazında, yerel SQLite veritabanında ve FlutterSecureStorage'da (AES-256) saklanır

**Bu mimari nedeniyle sunucu taraflı veri ihlali teknik olarak mümkün değildir.** Olası ihlal senaryoları yalnızca uygulama kodundaki güvenlik açıklarından kaynaklanabilir.

---

## 3. Olası İhlal Senaryoları

### 3.1 Uygulama Güvenlik Açığı
- Kötü niyetli bir üçüncü taraf uygulamanın KoruBeni verilerine erişmesi
- Android işletim sistemi düzeyinde bir güvenlik açığının sömürülmesi
- Uygulama kodunda keşfedilen bir zafiyet

### 3.2 Cihaz Kaybı/Çalınması
- Kullanıcının cihazının kaybolması veya çalınması durumunda cihaz üzerindeki verilere erişim riski
- **Azaltıcı önlem:** Uygulama PIN kilidi ile korunmaktadır

### 3.3 Zararlı Güncelleme
- Geliştirici hesabının ele geçirilmesi ve zararlı güncelleme yayınlanması

---

## 4. İhlal Tespit Kanalları

| Kanal | Açıklama |
|-------|----------|
| Google Play Console | Güvenlik uyarıları ve politika bildirimleri |
| E-posta (korubeni.destek@gmail.com) | Kullanıcı bildirimleri |
| Güvenlik araştırmacıları | Sorumlu açıklama (responsible disclosure) |
| Topluluk geri bildirimi | Google Play yorumları |

---

## 5. İhlal Müdahale Prosedürü

### Aşama 1: Tespit ve Değerlendirme (0-24 saat)

1. İhlal bildirimini al ve kaydet
2. İhlalin kapsamını değerlendir:
   - Etkilenen veri kategorileri
   - Etkilenen kullanıcı sayısı (tahmini)
   - İhlalin devam edip etmediği
   - Veri sızıntısının boyutu
3. İhlalin KVKK kapsamında bildirim gerektirip gerektirmediğini değerlendir

### Aşama 2: Acil Müdahale (0-48 saat)

1. **Güvenlik açığı tespit edildiyse:**
   - Düzeltme (hotfix) geliştir
   - Google Play Store'a acil güncelleme yayınla
   - Etkilenen kullanıcılara uygulama içi bildirim veya Google Play güncelleme notları ile bilgilendir

2. **Zararlı güncelleme senaryosu:**
   - Google Play Console üzerinden etkilenen sürümü geri çek
   - Google Play Destek ile iletişime geç
   - Geliştirici hesabı güvenliğini yeniden sağla (şifre değişikliği, 2FA)

### Aşama 3: KVKK Kurulu Bildirimi (72 saat içinde)

KVKK m.12/5 gereğince, veri ihlalinin öğrenilmesinden itibaren **en geç 72 saat** içinde:

1. **Kişisel Verileri Koruma Kurulu'na bildirim:**
   - İhlalin niteliği ve kapsamı
   - Etkilenen kişisel veri kategorileri
   - İhlalin olası sonuçları
   - Alınan veya alınması önerilen önlemler
   - İletişim bilgileri

2. **Bildirim yöntemi:** Kurul'un belirlediği form ve kanal üzerinden

### Aşama 4: İlgili Kişilere Bildirim (Makul sürede)

KVKK m.12/5 gereğince, ihlalden etkilenen kişilere **makul olan en kısa sürede** bildirim:

1. **Bildirim kanalları:**
   - Google Play Store güncelleme notları
   - Uygulama açılışında bilgilendirme ekranı (sonraki güncelleme ile)
   - korubeni.destek@gmail.com üzerinden bireysel bildirim (iletişim bilgisi mevcutsa)

2. **Bildirim içeriği:**
   - İhlalin açıklaması
   - Etkilenen veri türleri
   - Kullanıcının alabileceği önlemler (örn: PIN değişikliği, veri silme)
   - İletişim bilgileri

### Aşama 5: Düzeltme ve İyileştirme

1. Kök neden analizi yap
2. Güvenlik önlemlerini güçlendir
3. Benzer ihlalleri önlemek için gerekli kod değişikliklerini uygula
4. Prosedürü güncelle

---

## 6. İhlal Kaydı Tutma

Her ihlal olayı için aşağıdaki bilgiler kaydedilir ve en az **3 yıl** saklanır:

- İhlalin tespit tarihi ve saati
- İhlalin niteliği ve kapsamı
- Etkilenen veri kategorileri
- Alınan önlemler
- KVKK Kurulu bildirim tarihi ve referans numarası
- İlgili kişilere bildirim tarihi ve yöntemi

---

## 7. İletişim

Güvenlik açığı bildirimi veya veri ihlali şüphesi için:

**E-posta:** korubeni.destek@gmail.com
**Konu satırı:** [GÜVENLİK] — Kısa açıklama

---

## 8. Önemli Not

KoruBeni tamamen çevrimdışı çalıştığı ve hiçbir sunucuya veri aktarmadığı için, geleneksel anlamda bir "veri ihlali" (sunucu sızıntısı, veritabanı hack'i vb.) **teknik olarak mümkün değildir**. Bu prosedür, olası uygulama düzeyindeki güvenlik açıkları için hazırlanmıştır ve KVKK m.12 yükümlülüklerini karşılamak amacıyla oluşturulmuştur.
