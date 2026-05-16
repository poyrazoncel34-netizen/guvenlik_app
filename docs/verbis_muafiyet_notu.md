# KoruBeni — VERBİS Kayıt Muafiyet Değerlendirmesi

**Veri Sorumlusu:** Poyraz Öncel — Bireysel Yazılım Geliştirici
**İletişim:** korubeni.destek@gmail.com
**Son Güncelleme:** 2026-03-19
**Versiyon:** 3.0.0

---

## 1. VERBİS Nedir?

Veri Sorumluları Sicili (VERBİS), KVKK m.16 uyarınca Kişisel Verileri Koruma Kurulu tarafından tutulan kamuya açık bir sicildir. Kişisel veri işleyen veri sorumluları, kural olarak bu sicile kayıt yükümlülüğündedir.

---

## 2. Muafiyet Gerekçesi

Kişisel Verileri Koruma Kurulu'nun **2018/32 sayılı kararı** ve ilgili düzenlemeler kapsamında aşağıdaki kategoriler VERBİS kayıt yükümlülüğünden muaf tutulmuştur:

### 2.1 Yıllık Çalışan Sayısı Kriteri
- **Koşul:** Yıllık çalışan sayısı 50'den az olan gerçek veya tüzel kişi veri sorumluları (yıllık mali bilanço toplamı 25 milyon TL'den az olması kaydıyla)
- **KoruBeni durumu:** Poyraz Öncel bireysel geliştiricidir, çalışan sayısı **sıfırdır** ✓

### 2.2 Dernek, Vakıf ve Sendika Muafiyeti
- Uygulanamaz — bireysel geliştirici

### 2.3 Noterlik Muafiyeti
- Uygulanamaz

### 2.4 Serbest Meslek Erbabı / Avukat / Mali Müşavir Muafiyeti
- **Koşul:** Serbest meslek faaliyeti kapsamında kişisel veri işleyenler
- **KoruBeni durumu:** Bireysel yazılım geliştirici olarak serbest meslek erbabı statüsündedir ✓

---

## 3. Ek Gerekçeler

### 3.1 Veri İşleme Hacmi
- Uygulama tamamen çevrimdışı çalışır
- Hiçbir sunucuda kişisel veri toplanmaz veya saklanmaz
- Tüm veri yalnızca kullanıcının kendi cihazında kalır
- Geliştirici olarak kişisel verilere **erişim imkânı bulunmamaktadır**

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

1. **Bireysel geliştirici** — Yıllık çalışan sayısı 0, mali bilanço 25M TL altında
2. **Serbest meslek erbabı** statüsü
3. **Tamamen çevrimdışı mimari** — Geliştirici kişisel verilere erişim imkânına sahip değildir
4. **Backend aktarımı yok** — Geliştirici sunucusuna kişisel veri gönderilmez; harita, Google Play Billing ve RevenueCat sağlayıcılarının teknik ağ davranışları ayrı değerlendirilir

---

## 5. Önemli Uyarılar

1. **Muafiyet, KVKK yükümlülüklerinden muafiyet anlamına gelmez.** VERBİS kaydından muaf olmak, veri sorumlusu olarak KVKK'nın diğer tüm yükümlülüklerini (aydınlatma, açık rıza, veri güvenliği, veri sahibi hakları vb.) yerine getirme zorunluluğunu ortadan kaldırmaz.

2. **Kurul kararları değişebilir.** VERBİS muafiyet kriterleri Kişisel Verileri Koruma Kurulu tarafından güncellenebilir. Bu değerlendirme düzenli olarak gözden geçirilmelidir.

3. **Şüphe halinde kayıt.** Muafiyet durumunda tereddüt oluşursa, ihtiyati olarak VERBİS kaydı yaptırılması önerilir. Kayıt ücretsizdir ve ek bir yükümlülük getirmez.

---

## 6. Referanslar

- KVKK m.16 — Veri Sorumluları Sicili
- Kişisel Verileri Koruma Kurulu 2018/32 sayılı karar — VERBİS kayıt yükümlülüğünden muafiyet
- Kişisel Verileri Koruma Kurulu 2018/68 sayılı karar — Muafiyet kriterleri detaylandırması
- VERBİS Rehberi — kvkk.gov.tr
