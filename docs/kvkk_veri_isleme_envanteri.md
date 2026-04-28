# KoruBeni — KVKK Veri İşleme Envanteri

**Veri Sorumlusu:** Poyraz Öncel — Bireysel Yazılım Geliştirici
**İletişim:** korubeni.destek@gmail.com
**Uygulama:** KoruBeni (Kişisel Güvenlik Uygulaması)
**Son Güncelleme:** 2026-03-19
**Versiyon:** 3.0.0

---

## 1. Genel Mimari

KoruBeni **offline-first** çalışır. Uygulama geliştirici tarafından işletilen bir backend veya bulut veritabanına kişisel veri göndermez. Harita karoları, Play Billing veya üretimde açıkça yapılandırılmış crash reporting gibi üçüncü taraf SDK/servisleri kendi teknik ağ davranışlarına sahip olabilir.

- **Yerel veritabanı:** SQLite (sqflite)
- **Hassas veri depolama:** FlutterSecureStorage (AES-256 şifreleme)
- **Crash raporlama:** Yerel log (`crash_log_service.dart`); üretimde DSN verilirse PII kapalı Sentry entegrasyonu
- **Ağ bağlantısı:** Acil arama için Android sistem arama akışı kullanılır; harita karoları ve Play Billing ağ kullanabilir

---

## 2. Veri Kategorileri ve İşleme Detayları

### 2.1 Konum Verisi

| Alan | Detay |
|------|-------|
| **Veri türü** | GPS koordinatları (enlem/boylam), adres bilgisi |
| **Hukuki dayanak** | KVKK m.5/1 — Açık rıza |
| **İşleme amacı** | Konumu haritada göstermek ve acil arama akışında durum bilgisini desteklemek |
| **Saklama süresi** | İşlem anında kullanılır, kalıcı olarak saklanmaz |
| **Güvenlik önlemi** | Yalnızca acil durum tetiklendiğinde ve rıza mevcut olduğunda erişilir |
| **Rıza tipi** | `consent_location` — Granüler, geri çekilebilir |
| **Aktarım** | Uygulama acil durumda konumu otomatik mesajla göndermez; çevrimiçi harita görünümü harita karo servisine ağ isteği yapabilir |

### 2.2 Acil Durum Kişileri

| Alan | Detay |
|------|-------|
| **Veri türü** | İsim, telefon numarası |
| **Hukuki dayanak** | KVKK m.5/1 — Açık rıza |
| **İşleme amacı** | Acil durumda arama akışında kullanılacak kişiyi saklama |
| **Saklama süresi** | Kullanıcı silene kadar |
| **Güvenlik önlemi** | Cihaz içi yerel veritabanı; Android yedekleme kapalı |
| **Rıza tipi** | `consent_emergency_contacts` — Granüler, geri çekilebilir |
| **3. kişi hakları** | Eklenen kişiler KVKK m.11 haklarını korubeni.destek@gmail.com üzerinden kullanabilir |

### 2.3 Ses / Mikrofon

| Alan | Detay |
|------|-------|
| **Veri türü** | Toplanmaz — bu Android Play sürümünde ses dosyası veya mikrofon verisi işlenmez |
| **Hukuki dayanak** | Uygulanmaz — mikrofon izni istenmez |
| **İşleme amacı** | Yok — ses kaydı özelliği bu Play sürümünde devre dışıdır |
| **Saklama süresi** | Yok |
| **Güvenlik önlemi** | `RECORD_AUDIO` ve `FOREGROUND_SERVICE_MICROPHONE` manifestten çıkarılmıştır |
| **Rıza tipi** | Yok — aktif ses/mikrofon işleme yoktur |
| **Aktarım** | Yok |
| **Ek uyarı** | Data Safety beyanında ses/mikrofon verisi toplanmadığı belirtilmelidir |

### 2.4 Profil Bilgileri

| Alan | Detay |
|------|-------|
| **Veri türü** | Kullanıcı adı, profil ayarları |
| **Hukuki dayanak** | KVKK m.5/1 — Açık rıza |
| **İşleme amacı** | Uygulama kişiselleştirme |
| **Saklama süresi** | Kullanıcı silene kadar |
| **Güvenlik önlemi** | SharedPreferences (hassas olmayan), FlutterSecureStorage (hassas) |
| **Rıza tipi** | `consent_profile` — Granüler, geri çekilebilir |

### 2.5 Biyometrik Veri (Özel Nitelikli)

| Alan | Detay |
|------|-------|
| **Veri türü** | Parmak izi / yüz tanıma verisi |
| **Hukuki dayanak** | KVKK m.6/2 — Açık rıza (özel nitelikli kişisel veri) |
| **İşleme amacı** | Uygulama kilidi — yalnızca cihaz düzeyinde doğrulama |
| **Saklama süresi** | İşletim sistemi tarafından yönetilir, uygulama saklamaz |
| **Güvenlik önlemi** | Biyometrik veri uygulamaya iletilmez; yalnızca OS düzeyinde doğrulama sonucu (başarılı/başarısız) alınır |
| **Rıza tipi** | `consent_biometric` — Granüler, geri çekilebilir, özel kategori işaretli |
| **Not** | Uygulama biyometrik veriyi hiçbir şekilde saklamaz veya işlemez; yalnızca OS API sonucunu kullanır |

### 2.6 Sahte Çağrı Verileri

| Alan | Detay |
|------|-------|
| **Veri türü** | Sahte arayan bilgisi (kullanıcı tanımlı isim/numara) |
| **Hukuki dayanak** | KVKK m.5/1 — Açık rıza |
| **İşleme amacı** | Tehlikeli durumda sahte arama simülasyonu |
| **Saklama süresi** | Kullanıcı silene kadar |
| **Güvenlik önlemi** | SharedPreferences |
| **Rıza tipi** | `consent_fake_call` — Granüler, geri çekilebilir |

### 2.7 Yaş Beyanı

| Alan | Detay |
|------|-------|
| **Veri türü** | Yaş beyanı (18+ / 18 altı kullanım desteklenmez) |
| **Hukuki dayanak** | KVKK m.6 — Reşit olmayanların korunması |
| **İşleme amacı** | Yasal yükümlülük kontrolü |
| **Saklama süresi** | Uygulama yüklü olduğu süre |
| **Güvenlik önlemi** | SharedPreferences |
| **Rıza tipi** | `consent_age_verification` — Onboarding'de bir kez |

### 2.8 Hukuki Onay Kayıtları (Audit Log)

| Alan | Detay |
|------|-------|
| **Veri türü** | Onay zaman damgası, onay türü, uygulama versiyonu, locale |
| **Hukuki dayanak** | KVKK m.5/1 — Meşru menfaat (ispat yükümlülüğü) |
| **İşleme amacı** | Rıza ispatı, yasal savunma |
| **Saklama süresi** | Uygulama yüklü olduğu süre |
| **Güvenlik önlemi** | SQLite veritabanı, cihaz düzeyinde koruma |
| **Not** | TBK Md. 50 kapsamında ispat aracı |

---

## 3. Veri Aktarımı

| Aktarım Türü | Durum |
|---------------|-------|
| Yurt içi üçüncü taraf | **YOK** — Hiçbir üçüncü tarafa veri aktarılmaz |
| Yurt dışı aktarım | **YOK** — KVKK m.9 kapsamında yurt dışına veri aktarımı yapılmaz |
| Crash raporlama servisi | **YOK** — Tüm hata logları yalnızca yerel cihazda saklanır |
| Analitik servisi | **YOK** |
| Reklam ağı | **YOK** |

---

## 4. Teknik ve İdari Güvenlik Önlemleri

### Teknik Önlemler
- AES-256 şifreleme (FlutterSecureStorage) — hassas veriler için
- Yerel PIN kilidi — uygulama erişim kontrolü
- Biyometrik kilit desteği (opsiyonel, kullanıcı rızasına bağlı)
- Offline-first mimari — geliştirici sunucusu yoktur; üçüncü taraf SDK ağ davranışları ayrı değerlendirilmelidir
- Granüler rıza yönetimi — her veri kategorisi için ayrı onay/red
- Merkezi rıza kapısı (ConsentGateService) — rıza olmadan veri işleme engellenir
- Ses/mikrofon işleme bu Play sürümünde kapalıdır; `RECORD_AUDIO` izni yoktur

### İdari Önlemler
- 4 adımlı onboarding yasal akışı (18+ beyanı → kullanım sözleşmesi → KVKK aydınlatma → granüler rıza)
- Versiyon bazlı yeniden onay mekanizması — yasal metinler güncellendiğinde otomatik yeniden onay
- Veri silme ve dışa aktarma hakları (KVKK m.11) — Ayarlar ekranından erişilebilir
- Audit log kaydı — tüm rıza işlemleri zaman damgalı olarak loglanır
- 3. kişi (acil durum kişisi) KVKK hakları bilgilendirmesi

---

## 5. Veri Sahibi Hakları (KVKK m.11)

Kullanıcılar aşağıdaki haklarını uygulama içinden veya korubeni.destek@gmail.com adresine başvurarak kullanabilir:

1. Kişisel verisinin işlenip işlenmediğini öğrenme
2. İşlenmişse buna ilişkin bilgi talep etme
3. İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme
4. Yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme (aktarım yok)
5. Eksik veya yanlış işlenmişse düzeltilmesini isteme
6. KVKK m.7 kapsamında silinmesini veya yok edilmesini isteme
7. Düzeltme/silme işlemlerinin aktarıldığı üçüncü kişilere bildirilmesini isteme
8. Münhasıran otomatik sistemlerle analiz edilmesi sonucu aleyhine bir sonucun ortaya çıkmasına itiraz etme
9. Kanuna aykırı işlenmesi sebebiyle zarara uğraması halinde zararın giderilmesini talep etme

**Yanıt süresi:** Başvuru tarihinden itibaren en geç 30 gün.

---

## 6. Hukuki Dayanak Özeti

| Kanun | İlgili Madde | Uygulama |
|-------|-------------|----------|
| KVKK 6698 | m.5/1 | Açık rıza — tüm veri işleme faaliyetleri |
| KVKK 6698 | m.6/2 | Özel nitelikli veri (biyometrik) — açık rıza |
| KVKK 6698 | m.9 | Yurt dışı aktarım yasağı — aktarım yok |
| KVKK 6698 | m.10 | Aydınlatma yükümlülüğü — 4 adımlı onboarding |
| KVKK 6698 | m.11 | Veri sahibi hakları — uygulama içi + e-posta |
| TCK | m.133 | Ses kaydı özelliği bu Play sürümünde devre dışı; aktif kayıt/onay akışı yok |
| TBK | m.50 | İspat — audit log kayıtları |
| TBK | m.115 | Sorumluluk sınırı — ağır kusur istisnası |
| 6502 | Tüketici Kanunu | Ücretsiz uygulama bilgilendirmesi |
