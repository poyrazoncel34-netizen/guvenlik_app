# KoruBeni — Veri İhlali Bildirimi Prosedürü

**Veri Sorumlusu:** Poyraz Öncel — Bireysel Yazılım Geliştirici
**İletişim:** korubeni.destek@gmail.com
**Son Güncelleme:** 2026-08-27
**Versiyon:** 4.0.0

---

## 1. Kapsam

Bu prosedür, KVKK m.12/5 kapsamında kişisel verilerin hukuka aykırı olarak işlenmesi, erişilmesi veya aktarılması durumunda uygulanacak adımları tanımlar.

---

## 2. Uygulama Mimarisi ve Veri İhlali Riski

KoruBeni'nin **acil arama akışı** geliştirici backend'i olmadan çalışır, ancak uygulama
bir bütün olarak "tamamen çevrimdışı" DEĞİLDİR. Bu ayrım bilinçlidir ve proje kuralı
gereğidir (CLAUDE.md kural 1: *"do not claim 100% offline product behavior"*).

**Geliştirici backend'i yoktur:**

- **Sunucu yok:** Geliştiriciye ait hiçbir uzak sunucuya kişisel veri gönderilmez
- **Bulut veritabanı yok:** Uzak depolama kullanılmaz
- **Analitik/reklam yok:** Analitik, reklam ağı veya üçüncü taraf crash toplama entegre değildir
- **Veri cihazda:** Acil kişiler cihaza özel güvenli depolamada (`emergency_contacts_v1`),
  güvenlik zaman çizelgesi yerel veritabanında tutulur

**Ancak isteğe bağlı katmanlar ağ kullanır ve bunlar gerçek ihlal vektörleridir:**

| Katman | İşlenen veri | İhlal ihtimali |
|---|---|---|
| RevenueCat | IP, cihaz/OS bilgisi, anonim abone kimliği, satın alma olayları | Sağlayıcı nezdinde ihlal |
| Google Play Billing | Ödeme olayları | Sağlayıcı nezdinde ihlal |
| Harita karo sağlayıcısı | IP, User-Agent, karo koordinatı | Sağlayıcı nezdinde ihlal |
| Play Console / GitHub | Yayın kontrolü | Hesap ele geçirilmesi |

**Bu mimari sunucu taraflı ihlal yüzeyini KÜÇÜLTÜR, sıfırlamaz.** Aydınlatma metni de
aynı aktarımları sayar; bu bölüm onunla tutarlı olmak zorundadır.

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

### 3.4 Üçüncü Taraf (Veri İşleyen) Nezdinde İhlal
- RevenueCat, Google Play veya harita karo sağlayıcısında yaşanan bir ihlal
- 2019/10 sayılı Kurul kararı: **veri işleyen, kendi nezdinde tespit ettiği ihlali
  gecikmeye yer vermeksizin veri sorumlusuna bildirmek zorundadır.** Sağlayıcıdan gelen
  böyle bir bildirim, 72 saatlik sürenin başlangıcıdır.
- Bu senaryo ilk sürümde eksikti; mimarinin ağ kullanan katmanları olduğu için gerçektir.

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
3. **Bildirimin GEREKİP GEREKMEDİĞİNİ değil, KAPSAMINI değerlendir.**

> **Bu adım ilk sürümde yanlıştı ve düzeltildi.** Eski metin "bildirim gerektirip
> gerektirmediğini değerlendir" diyordu; bu bir takdir yetkisi ima ediyor ve GDPR
> modelinden geliyor. KVKK m.12/5 farklıdır ve metninde **hiçbir risk eşiği yoktur**:
>
> *"İşlenen kişisel verilerin kanuni olmayan yollarla başkaları tarafından elde
> edilmesi hâlinde, veri sorumlusu bu durumu en kısa sürede ilgilisine ve Kurula
> bildirir."*
>
> Yani ihlal varsa bildirim vardır. "Riski düşük değerlendirdik, bildirmedik" savunması
> yoktur; geç veya eksik bildirim, veri güvenliği yükümlülüğünün ihlali olarak **ayrı**
> bir ceza sebebidir (2026: 256.357 – 17.092.242 TL).

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

2. **Bildirim kanalı — 3'te aranmayacak kadar net olmalı:**
   - Form: **"Kişisel Veri İhlal Bildirim Formu"** (Kurul kararı **2019/10**, 24.01.2019)
   - Elektronik gönderim: **https://ihlalbildirim.kvkk.gov.tr/**

3. **72 saat kaçırılırsa ne olur:** 2019/10 sayılı karar bunu öngörür — bildirim yine
   yapılır, ancak **gecikmenin nedenleri de bildirimle birlikte Kurula açıklanır.**
   Gecikme bildirimi bırakmak için gerekçe değildir.

4. **Sürenin başlangıcı:** "öğrenildiği an". Hafta sonu ve resmî tatil sürenin işlemesini
   durdurmaz.

### Aşama 4: İlgili Kişilere Bildirim (Makul sürede)

KVKK m.12/5 gereğince, ihlalden etkilenen kişilere **makul olan en kısa sürede** bildirim:

1. **Bildirim kanalları:**
   - Google Play Store güncelleme notları
   - Uygulama açılışında bilgilendirme ekranı (sonraki güncelleme ile)
   - korubeni.destek@gmail.com üzerinden bireysel bildirim (iletişim bilgisi mevcutsa)

2. **Bildirim içeriği — Kurul kararı 2019/271 (18.09.2019) asgari unsurları.**
   Bildirim **açık ve sade bir dille** yazılır ve şunları içerir:

   1. İhlalin **ne zaman gerçekleştiği**
   2. Kişisel veri **kategorileri bazında** hangi verilerin etkilendiği
      *(özel nitelikli veriler varsa ayrıca belirtilir)*
   3. İhlalin **olası sonuçları**
   4. Olumsuz etkilerin azaltılması için **alınan veya alınması önerilen tedbirler**
      *(örn. PIN değişikliği, uygulama verisini silme)*
   5. Bilgi almayı sağlayacak **irtibat kişisi ve iletişim detayları** ya da veri
      sorumlusunun web sayfası/çağrı merkezi gibi iletişim yolları

   İlk sürümde 1. unsur (zaman) ve özel nitelikli ayrımı eksikti.

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

## 8. Karara bağlanmamış soru — kullanıcının cihazının çalınması

§3.2 cihaz kaybını ihlal senaryosu olarak sayıyor ama **Kurul'a bildirim doğurup
doğurmadığını söylemiyor.** Bu boşluk bilerek açık bırakılıyor, çünkü cevabı daha temel
bir soruya bağlı: **bu uygulamada veri sorumlusu kim?**

- Şirket dizüstü bilgisayarının çalınması yerleşik bir ihlal örneğidir — ama orada cihaz
  veri sorumlusunun kontrolündedir.
- KoruBeni'de veri **kullanıcının kendi cihazındadır**, geliştiricinin erişimi yoktur ve
  o cihazı geliştirici işletmez.
- Kurul'un 30.01.2020 tarih **2020/71** sayılı kararı veri sorumlusu/veri işleyen
  tespitinin ölçütlerini düzenler ve bu sorunun cevaplanacağı yer orasıdır.

**Avukat teyidi alınana kadar ihtiyatlı varsayım:** her cihaz kaybını bildirmek pratik
değildir, ancak *uygulamanın bir kusuru nedeniyle* cihazdaki veriye yetkisiz erişim
mümkün olduysa bu bir ihlaldir ve bildirilir. Ayrım "cihaz kayboldu" ile "uygulama
veriyi korumadı" arasındadır.

---

## 9. VERBİS muafiyeti bu yükümlülüğü KALDIRMAZ

`docs/verbis_muafiyet_notu.md` VERBİS kayıt yükümlülüğünden muafiyeti değerlendirir.
**Muafiyet yalnızca sicile kayıt ve bildirim yükümlülüğüne ilişkindir.** Aydınlatma,
veri güvenliği, saklama-imha ve bu belgedeki **ihlal bildirimi** yükümlülükleri muaf
olanlar için de aynen sürer.

---

## 10. Önemli Not

KoruBeni geliştirici tarafından işletilen bir backend kullanmaz; ancak harita karo sağlayıcısı, Google Play Billing ve RevenueCat gibi üçüncü taraf akışların kendi teknik ağ davranışları olabilir. Bu prosedür; cihaz içi veri, uygulama düzeyi güvenlik açıkları, üçüncü taraf sağlayıcı bildirimleri ve KVKK m.12 yükümlülükleri için hazırlanmıştır. Hiçbir güvenlik veya erişilebilirlik garantisi verilmez.
