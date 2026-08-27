# KoruBeni — VERBİS Kayıt Muafiyet Değerlendirmesi

**Veri Sorumlusu:** Poyraz Öncel — Bireysel Yazılım Geliştirici
**İletişim:** korubeni.destek@gmail.com
**Son Güncelleme:** 2026-08-27
**Versiyon:** 4.0.0

---

## 1. VERBİS Nedir?

Veri Sorumluları Sicili (VERBİS), KVKK m.16 uyarınca Kişisel Verileri Koruma Kurulu tarafından tutulan kamuya açık bir sicildir. Kişisel veri işleyen veri sorumluları, kural olarak bu sicile kayıt yükümlülüğündedir.

---

## 2. Muafiyet Gerekçesi

> **Bu bölüm 2026-08-27'de düzeltildi.** Önceki sürüm dayanak olarak "2018/32 sayılı
> karar" ve "25 milyon TL" eşiğini gösteriyordu. Karar numarası yanlıştı ve eşik üç yıl
> bayattı. Ayrıca muafiyet gerekçesi olarak "serbest meslek erbabı" statüsü ileri
> sürülüyordu; bu da yanlıştır (aşağıda 2.3).

Kurul kararlarının zinciri:

| Karar | Tarih / RG | Ne yaptı |
|---|---|---|
| **2018/87** | 19.07.2018 | İstisna çerçevesi: <50 çalışan **ve** <25 milyon TL bilanço |
| **2023/1154** | RG 25.07.2023, 32259 | Bilanço eşiğini **25 milyon → 100 milyon TL** yaptı |
| **2025/1572** | RG 01.10.2025, 33034 | Ana faaliyeti özel nitelikli veri işleme olan **mikro işletmelere** istisna: <10 çalışan **ve** <10 milyon TL |

### 2.1 Çalışan sayısı ve bilanço kriteri
- **Koşul:** Yıllık çalışan sayısı 50'den az **ve** yıllık mali bilanço toplamı
  **100 milyon TL'den az** (2023/1154 ile güncel tutar). Kriterler kümülatiftir.
- **KoruBeni durumu:** çalışan sayısı **sıfırdır** ✓

### 2.2 Bilanço tutmayanlar için belirleyici kural
- **Bilanço esasına göre defter tutmayanlar** için "yıllık mali bilanço toplamı" verisi
  bulunmadığından, istisnanın tespitinde **yalnızca yıllık çalışan sayısı** kriteri esas
  alınır.
- **KoruBeni durumu:** GVK mükerrer 20/B kapsamında gerçek kişi olarak bilanço esasına
  göre defter tutulmayacaktır; dolayısıyla tek ölçüt çalışan sayısıdır ve o **sıfırdır** ✓
- **Muafiyetin en sağlam dayanağı budur.**

### 2.3 "Serbest meslek erbabı" gerekçesi KULLANILMIYOR — ve nedeni
- Önceki sürüm bireysel yazılım geliştiriciyi "serbest meslek erbabı" sayıp muafiyet
  gerekçesi yapıyordu. Bu **yanlıştır.**
- VERBİS'teki ilgili istisna avukat, noter ve mali müşavir gibi **kendi özel kanunlarına
  tabi** meslekleri kapsar; yazılım geliştiriciliği bu listede değildir.
- Dahası, mobil uygulama geliştiriciliğinden elde edilen kazanç **ticari kazançtır**,
  serbest meslek kazancı değil. Bunu SGK muamelesi de teyit eder: GVK mük. 20/B
  kapsamında vergi mükellefiyeti açılınca doğan sigortalılık **5510 m.4/1-(b)**
  (esnaf/ticari) statüsüdür.
- Yanlış bir gerekçeye dayanan muafiyet, denetimde muafiyetin kendisini tartışmaya açar.
  Doğru gerekçe 2.1 ve 2.2'dir; onlar zaten yeterlidir.

### 2.4 Dernek, vakıf, sendika ve noterlik muafiyetleri
- Uygulanamaz — bireysel geliştirici

---

## 3. Ek Gerekçeler

### 3.1 Veri İşleme Hacmi
- **Acil arama akışı** geliştirici backend'i olmadan çalışır. Uygulama bir bütün olarak
  "tamamen çevrimdışı" DEĞİLDİR — proje kuralı bu iddiayı yasaklar (CLAUDE.md kural 1).
- Geliştiriciye ait hiçbir sunucuda kişisel veri toplanmaz veya saklanmaz
- Acil kişiler, güvenlik geçmişi ve PIN yalnızca kullanıcının kendi cihazında kalır
- Geliştirici olarak bu verilere **erişim imkânı bulunmamaktadır**
- İsteğe bağlı katmanların ağ davranışı 3.2'de ayrıca sayılır

### 3.2 Üçüncü Taraf / Sağlayıcı Davranışı
- Geliştirici tarafından işletilen bir backend'e kişisel veri aktarımı yapılmaz
- Çevrimiçi harita ekranı OpenStreetMap veya yapılandırılmış harita karo sağlayıcısına teknik ağ isteği yapabilir
- İsteğe bağlı Pro abonelik için Google Play Billing ve RevenueCat abonelik/yetki durumunu işleyebilir
- Ödeme kartı bilgileri geliştirici tarafından saklanmaz
- Analitik, üçüncü taraf crash raporlama veya reklam servisi kullanılmaz

### 3.3 Özel Nitelikli Veri İşleme
- Bu Android Play sürümünde biyometrik kilit devre dışıdır
- Uygulama biyometrik veriyi toplamaz, saklamaz veya işlemez

---

## 4. Sonuç ve Değerlendirme

Poyraz Öncel, KoruBeni uygulamasının veri sorumlusu olarak aşağıdaki gerekçelerle VERBİS kayıt yükümlülüğünden **muaf** olduğunu değerlendirmektedir:

1. **Çalışan sayısı sıfırdır** — 2018/87 çerçevesindeki <50 çalışan koşulu sağlanır
2. **Bilanço esasına göre defter tutulmaz** — bu halde istisnanın tespitinde yalnızca
   çalışan sayısı esas alınır; ikinci bir eşik tartışması doğmaz *(en sağlam dayanak)*
3. **Ana faaliyet özel nitelikli veri işleme değildir** — tıbbi profil özelliği
   kaldırılmıştır; kalan tek referans eski veriyi silen tek seferlik temizlik servisidir
   (`medical_data_cleanup_service.dart`) ve aydınlatma metni sağlık verisi saymaz
4. **Geliştirici backend'ine aktarım yok** — harita, Google Play Billing ve RevenueCat
   sağlayıcılarının teknik ağ davranışları 3.2'de ayrıca sayılır ve gizlenmez

**Kullanılmayan gerekçe:** "serbest meslek erbabı" statüsü — bkz. 2.3.

---

## 5. Önemli Uyarılar

1. **Muafiyet, KVKK yükümlülüklerinden muafiyet anlamına gelmez.** VERBİS kaydından muaf olmak, veri sorumlusu olarak KVKK'nın diğer tüm yükümlülüklerini (aydınlatma, açık rıza, veri güvenliği, veri sahibi hakları vb.) yerine getirme zorunluluğunu ortadan kaldırmaz.

2. **Kurul kararları değişebilir.** VERBİS muafiyet kriterleri Kişisel Verileri Koruma Kurulu tarafından güncellenebilir. Bu değerlendirme düzenli olarak gözden geçirilmelidir.

3. **Daha temel bir soru açık:** bu uygulamada veri sorumlusu geliştirici mi, kullanıcı
   mı? Veri cihazdan çıkmıyor ve geliştiricinin erişimi yok; sıfat, "işleme amaç ve
   vasıtalarını kim belirliyor" ölçütüne bağlıdır (Kurul kararı **2020/71**). Bu belge,
   sıfatın geliştiricide olduğu ihtiyatlı varsayımıyla yazılmıştır. Avukat teyidi
   alınmalıdır; cevap "kullanıcı" çıkarsa bu değerlendirme büyük ölçüde konusuz kalır.

4. **Şüphe halinde kayıt.** Muafiyet durumunda tereddüt oluşursa, ihtiyati olarak VERBİS kaydı yaptırılması önerilir. Kayıt ücretsizdir ve ek bir yükümlülük getirmez.

---

## 6. Referanslar

- KVKK m.16 — Veri Sorumluları Sicili
- Kurul kararı **2018/87** (19.07.2018) — istisna çerçevesi (<50 çalışan, <25 milyon TL)
- Kurul kararı **2023/1154** (RG 25.07.2023, 32259) — bilanço eşiği 100 milyon TL'ye çıktı
- Kurul kararı **2025/1572** (RG 01.10.2025, 33034) — mikro işletme istisnası
- Kurul kararı **2020/71** (30.01.2020) — veri sorumlusu / veri işleyen tespiti
- `docs/veri_ihlali_bildirimi_proseduru.md` — muafiyetin KALDIRMADIĞI bildirim yükümlülüğü
- VERBİS Rehberi — kvkk.gov.tr
