# KoruBeni — Alan Bazlı KVKK Veri İşleme Envanteri

**Durum:** `COUNSEL_UNVERIFIED`

**Teknik kapsam:** Android Play, Türkiye/Türkçe ilk sürüm

**Son teknik güncelleme:** 19 Temmuz 2026

**Veri sorumlusu taslağı:** Poyraz Öncel — bireysel geliştirici

**İletişim taslağı:** korubeni.destek@gmail.com

Bu belge teknik envanterdir; hukuki görüş veya KVKK uyum onayı değildir.
Veri sorumlusu kimliği/adresi, her satırın hukuki şartı, yurt dışı aktarım
mekanizması, saklama süresi ve ilgili kişi başvuru usulü Türk privacy counsel
tarafından doğrulanmadan G4/G8 kapanmaz.

KoruBeni offline-first'tür: acil akış geliştirici backend'ine bağlı değildir.
Bu, ürünün hiç ağ kullanmadığı anlamına gelmez. Google Play Billing,
RevenueCat, Android Telecom ve çevrimiçi harita sağlayıcısı ayrı veri akışlarıdır.

## Alan bazlı envanter

| Alan | Kaynak | İşleme zamanı | Amaç | Hukuki şart (taslak) | Alıcı | Ülke / aktarım | Retention | Silme / geri çekme | Teknik kanıt | Durum |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Yerel PIN ve lockout metası | Kullanıcının PIN kurulumu/girişi | Kurulum, unlock ve safety iptal doğrulaması | Yerel erişim kontrolü ve doğrulanmış iptal | Sözleşmenin kurulması/ifası veya meşru menfaat; counsel teyidi gerekir | Yok; cihaz içi | Türkiye dışına aktarım yok | PIN değiştirme veya local wipe'a kadar | PIN reset/wipe; biyometri kullanılmaz | `SecureStorageKeys.userPin`, `PinVerificationService`; dinamik storage testi gerekli | `TECHNICAL`, `COUNSEL_UNVERIFIED` |
| Acil kişi adı ve telefon numarası (üçüncü kişi verisi) | Kullanıcı manuel giriş veya Android contact picker ile tek kayıt seçer | Kişi ekleme/düzenleme | Kullanıcının seçtiği kişiyi safety hedefi yapmak | Açık rıza tek başına otomatik cevap kabul edilmez; üçüncü kişi verisi ve m.5 şartı counsel tarafından belirlenir | Normalde cihaz içi; expiry'de telefon Android Telecom'a verilir | Android/operatör telephony zinciri; sağlayıcı rolleri counsel incelemesinde | Kullanıcı silene/consent withdrawal'a kadar; aktif snapshot aşağıda ayrı | Aktif session yoksa silinir; aktif session varsa önce typed cancel acknowledgment gerekir | Contact repository, normalized target validation, manifest `CALL_PHONE` | `TECHNICAL`, `COUNSEL_UNVERIFIED` |
| Device-protected aktif-session envelope: protocol/schema, token, generation, kind, lifecycle, normalized target, wall/elapsed deadline, scheduling modu | Kullanıcının arm ettiği Panic/Check-In/Safe Walk | Arm, reboot/update recovery, cancel/dispatch | Flutter/credential storage açılmadan deadline ve stale-generation güvenliği | Safety hizmetinin ifası ve açık kullanıcı işlemi; counsel teyidi gerekir | Normalde yalnız cihaz; hedef expiry'de Android Telecom'a verilebilir | Cihaz; Telecom/operatör zinciri ayrı | Confirmed cancel/reset'e veya terminal sonrasında actionable fallback sona erene kadar | Confirmed cancel/reset hedefi hemen siler; posted fallback varsa hedef yalnız token ile yetkilendirilen app-private kayıtta tutulur; `Unknown/TooLate` durumunda silindi denmez | Native device-protected store, generation/tombstone/fault tests | `IMPLEMENTATION_IN_PROGRESS` |
| Actionable fallback hedefi | Aktif-session snapshot'ı | Otomatik request başarısız/belirsiz olduğunda | Kullanıcının bildirime dokunup dialer açabilmesi | Safety hizmetinin ifası; counsel teyidi gerekir | Android notification/PendingIntent; kullanıcı dokunursa dialer | Cihaz/Android telephony | Action, dismiss veya en fazla 24 saatlik mantıksal TTL; cihaz kapalıyken fiziksel silme mümkün değildir | TTL sonunda erişim reddedilir; açık cihazda alarm/reconcile ile, kapalı cihazda sonraki boot/read sırasında fiziksel kayıt temizlenir; lock-screen metninde ve PendingIntent'te numara yok | Native fallback record + expiry/boot testleri | `IMPLEMENTATION_IN_PROGRESS`, `COUNSEL_UNVERIFIED` |
| Konum koordinatı | Kullanıcının runtime location izni ve granüler consent'i | Kullanıcı harita/konum özelliğini aktif açtığında | Haritada konum gösterimi | Açık rıza; aydınlatmadan ayrı işlem | Cihaz; çevrimiçi haritada karo sağlayıcısına doğrudan koordinat alanı gönderilmez | Cihaz; aşağıdaki tile request çıkarımı ayrı | Ekran/session süresi; kalıcılaştırma varsa ayrıca envantere eklenir | Consent withdrawal gerçek GPS stream'ini durdurmalı; teknik test zorunlu | Geolocator/LocationService ve withdrawal testleri | `TECHNICAL_REVERIFY_REQUIRED` |
| Harita request metası ve yerel karo cache'i: IP, User-Agent, tile z/x/y; viewport çıkarımı; app-private PNG/expiry/validator metası | Cihaz ağı ve kullanıcının açtığı map viewport'u | Çevrimiçi harita açıldığında ve aynı karonun cache'den yeniden kullanımı sırasında | Harita karosu indirme ve gereksiz tekrar isteklerini önleme | Hizmet/consent ve m.9 şartı counsel tarafından belirlenir | Varsayılan public OSM endpoint; farklı build-time provider ayrıca incelenir | Yurt dışı aktarım ihtimali yüksek; ülke ve mekanizma `UNVERIFIED`; cache cihaz içi | Sağlayıcının `Cache-Control/Age/Expires` süresi; kullanılabilir talimat yoksa 7 gün; app cache toplam 128 MiB, tile başına 2 MiB; prefetch/offline archive yok | Expired/bozuk/uyumsuz kayıt startup'ta; bütün cache app-data reset/uninstall ile silinir; provider tarafı silme doğrudan garanti edilmez | `OsmTileCacheClient` davranış testleri, stable UA/contact, attribution; exact-AAB network capture bekliyor | `LOCAL_TECHNICAL_PASS`, `COUNSEL_UNVERIFIED`, `NETWORK_EVIDENCE_REQUIRED` |
| Google Play satın alma olayı, ürün/plan, ödeme/yenileme/iptal durumu | Kullanıcının Play purchase işlemi | Paywall, purchase, restore, Play lifecycle | Aylık/yıllık Pro aboneliği | Sözleşme/kanuni yükümlülük; counsel teyidi gerekir | Google Play Billing | Google/processor ülkeleri; m.9 mekanizması `UNVERIFIED` | Google hesabı/Play politikası | Local wipe aboneliği iptal etmez; Play hesabından ayrı yönetilir | Billing Library dependency, license tester evidence | `PLAY_CONSOLE_UNVERIFIED`, `COUNSEL_UNVERIFIED` |
| RevenueCat anonymous App User/subscription ID, entitlement ve purchase event metası, IP/device teknik metası | RevenueCat SDK; yalnız güncel legal akıştan sonra lazy configure | Pro/paywall/restore veya prior-Pro initialization hint'i | Verified entitlement kararı ve restore | Sözleşme/consent/m.9 şartı counsel tarafından belirlenir | RevenueCat ve subprocessors | Yurt dışı; DPA/standart sözleşme/diğer mekanizma `UNVERIFIED` | RevenueCat sözleşmesi/politikası | Local wipe ile silinmez; PIN sonrası kopyalanabilir request ID + support deletion runbook gerekir | Lazy configure testleri, Trusted Entitlements, network capture, dashboard evidence | `IMPLEMENTATION_IN_PROGRESS`, `COUNSEL_UNVERIFIED` |
| RevenueCat prior-Pro initialization hint'i | Daha önce doğrulanmış Pro sonucu | Legal kabul sonrası startup | SDK'yı gerektiğinde lazy başlatma | Teknik tercih; entitlement kanıtı değildir | Yok; app-private local flag | Cihaz | Uygulama verisi silinene kadar | Local wipe | Provider tests: hint asla access vermemeli | `IMPLEMENTATION_IN_PROGRESS` |
| Consent/aydınlatma kayıtları: tür, granted, zaman, metin/app sürümü, locale, OS metası | Kullanıcının ayrı seçimleri | Onboarding ve consent management | Tercihi uygulama ve ispat | Kanuni yükümlülük/meşru menfaat; counsel teyidi gerekir | Normalde cihaz; kullanıcı export ederse seçtiği hedef | Kullanıcı export'una bağlı | Uygulama verisi silinene kadar veya counsel-approved süre | Consent log clear/export | `ConsentManager`, corrupt-record ve persist-failure testleri | `TECHNICAL`, `COUNSEL_UNVERIFIED` |
| Yerel safety/activity/error olayları (redacted) | App/native runtime | Feature ve hata çalışması | Kullanıcıya geçmiş ve yerel teşhis | Meşru menfaat/hizmet; counsel teyidi gerekir | Cihaz; yalnız kullanıcı kontrollü redacted export | Kullanıcının seçtiği export hedefi hariç cihaz | Bounded ring buffer / kullanıcı silene kadar; kesin limit teknik kanıt ister | Timeline/delete/reset; export temp dosyası doğrulanmış cleanup | PII/logcat scan ve bounded native log testi | `IMPLEMENTATION_REQUIRED` |
| Fake-call adı/numarası/avatarı | Kullanıcı | Fake-call kurulum/çalıştırma | Cihaz içi simülasyon | Açık kullanıcı işlemi; üçüncü kişi içeriği counsel incelemesinde | Cihaz | Aktarım yok | Kullanıcı silene/local wipe'a kadar | Feature delete/local wipe | Shared prefs/file inspection | `TECHNICAL_REVERIFY_REQUIRED` |
| Support/KVKK/deletion request kimliği ve yazışması | Kullanıcının e-posta başvurusu + request identifier | Destek veya hak talebi | Talebi doğrulama, yanıtlama ve ispat | Kanuni yükümlülük/hak kullanımı | Support e-posta sağlayıcısı, gerekiyorsa RevenueCat | Mail/processor ülkeleri `UNVERIFIED` | Counsel-approved ticket süresi | Talep kapanışı ve yasal retention sonrası | Support runbook/evidence ledger | `OPERATIONAL_UNVERIFIED`, `COUNSEL_UNVERIFIED` |

## Bilinçli olarak işlenmeyen alanlar

- Biyometrik doğrulama/veri: yok ve eklenmesi yasak.
- Mikrofon/ses kaydı: devre dış ve işlenmez; `RECORD_AUDIO` yok.
- SMS: yok; resmî 112/911/KADES entegrasyonu iddiası yok.
- Remote analytics/crash SDK: yok; teşhis cihaz içi ve redacted export'tur.
- Background location: yok.
- Developer backend/auth/cloud database: yok.

## Rıza ve silme transaction kuralları

1. Aydınlatma ve açık rıza ayrı metin/işlemdir; ikisini tek checkbox veya tek
   irade beyanı gibi sunma.
2. Acil kişi rızası geri çekilince önce yeni arm bloklanır. Aktif session varsa
   typed native cancel sonucu beklenir. Yalnız `Cancelled/AlreadyCancelled`
   sonrası kişi/snapshot için “silindi” denebilir.
3. `TooLate/Unknown` silme değildir; işlem `pending` kalır ve reconciliation
   gerekir.
4. Konum rızası geri çekilince canlı GPS stream'i kapatılır; yalnız UI toggle'ı
   değiştirmek yeterli kanıt değildir.
5. Local wipe, Play aboneliği iptali ve RevenueCat deletion üç ayrı işlemdir.
6. KVKK m.11/ğ bağımsız “veri portabilitesi hakkı” diye adlandırılmaz.

## Yurt dışı aktarım açık kapısı

RevenueCat, Google/Play, OSM ve support e-posta sağlayıcısı için alıcı rolü,
ülke, alt işleyenler, DPA, KVKK m.9 mekanizması ve gerekiyorsa standart sözleşme
bildirim süresi counsel tarafından belirlenmemiştir. Teknik doküman bu boşluğu
`risk kabul edildi` diyerek kapatamaz. G4/G8 bu satırlar `UNVERIFIED` iken PASS
olamaz.

## Teknik kanıt paketi

- Exact production AAB SDK/network capture ve Data Safety parity.
- Device-protected store dump: yalnız izin verilen minimal alanlar.
- Cancel/reset/TTL sonrası CE+DE store ve PendingIntent temizliği.
- RevenueCat'ın legal kabul öncesi sıfır ağ isteği ve Trusted Entitlements
  karar testi.
- OSM User-Agent, attribution, cache/backoff ve viewport request capture.
- Logcat/local log/export içinde PIN, telefon, hassas koordinat, RevenueCat ID
  ve secret taraması.
- Counsel imzalı field-level envanter, aktarım ve retention kararı.
