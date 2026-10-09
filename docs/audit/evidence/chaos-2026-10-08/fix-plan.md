# Chaos audit 2026-10-08 — düzeltme planı (sahip onayı: TÜMÜ + API 29/36 imajları, 2026-10-08)

Her madde: ayrı commit · regresyon testi aynı commit'te · düzeltme geri alınınca test kırmızı (mutasyon) · commit başı
`flutter analyze --no-fatal-infos` + `flutter test` (+ Kotlin unit) yeşil · ilgili inceleme ajanı · emülatörde yeniden çalışma.
Boyut sınırı: `countdown_screen.dart` 1033'e, `check_in_service.dart` 799/800'e kilitli → mantık `lib/core/services/`e çıkarılır, dosyalar büyümez.

## A — HIGH (saat değişimi; güvenlik anlamı değişmez: native zaten süre tabanlı, Dart ona hizalanır)
1. **Y-04 panik geri sayımı monotonik.** Yeni `MonotonicDeadline` (enjekte edilebilir duvar/monotonik saat). Geri sayım
   gösterimi ve Dart son tarihi arm anında başlayan monotonik süreden; native'e giden duvar son tarihi aynı kalır; K-03'ün
   µs-tavan anlamı korunur. Test: saat ±1 sa sıçramasında erken 0 / çevirici / iptal yüzeyi kaybı yok; normal yolda ilk 0
   anı değişmez. Kalan risk (belgelenecek): geri alınan saat + TIME_SET yayını gerçek son tarihten de geç gelirse çevirici yolu.
2. **Y-01 Check-In / Safe Walk.** (a) `ClockChangeReceiver` uzlaştırmadan SONRA `safetyClockChanged` yayar (yalnız emit,
   asla persist — tek yuvalı bekleyen tetikleyiciyi ezmesin); Dart'taki mevcut ölü dinleyici canlanır. (b) Sayaç, son native
   senkrondan bu yana monotonik süreyle ilerler (`SafetySessionClock` olarak çıkarılır). Test: Robolectric (alıcı yayıyor,
   persist etmiyor) + Dart (ileri sıçrama: grace/gönderim yok; geri sıçrama: kalan süre şişmiyor; olay → yeniden senkron).

## B — MEDIUM
3. **Y-06** prova (Test Modu) tuş takımı kilit aktifken doğrulamaz, kilit mesajı gösterir. Gerçek panik değişmez.
4. **Y-05** PIN kilidi: duvar son tarihinin yanına aynı açılışın `elapsedRealtime` son tarihi + BOOT_COUNT yazılır (mevcut
   emergency kanalına salt-okur bir yöntem); aynı açılışta monotonik karar; farklı/bilinmeyen açılışta duvar, ama kalan süre
   `maxLockoutSeconds` ile sınırlı (geri alınan saat sahibi saatlerce kilitlemez). security-reviewer.
5. **A-11** panik yeniden bağlanma: açılış/devamda `discoverEmergencySession(panic)` ARMED + gelecekte son tarih + açık geri
   sayım yoksa, geri sayım "yeniden bağlanma" kipinde açılır: arm YOK, mevcut belirteç ve native son tarih, maskeli kimlik,
   PIN iptali aynı belirteçle, son tarihte aynı belirteçle dispatch (native zaten talep ettiyse terminal sonucu okunur).
6. **Y-03** `initializeFromPriorProHint` ağ başlatmasından önce yerel çapayı yükler (SOS "Kilitli" görünmez).
7. **Y-07** arm öncesi doğru PIN: arm başlamadıysa hiç arm edilmez ve ekran kapanır; arm sürüyorsa sonucu beklenir, sonra
   aynı belirteç iptal edilir. Kırmızı test hazır: `test/screens/countdown_pin_before_arm_test.dart`.
8. **Y-08** native oturumu olmayan (çeviriciye düşen) panik zaman çizelgesine doğrudan yazılır; native oturum varsa günlük
   uzlaştırması aynen kalır (çift kayıt yok). Test: ffi SQLite.

## C — LOW
9. **A-07** paywall, devam kilidi açıkken itilmez: kilit kalkınca erişim yeniden değerlendirilir, gerekiyorsa gösterilir.
10. **A-08** yeniden park edilen bağlantı, erteleme kalkmışsa aynı turda yeniden yönlendirilir (çift tüketim yok).
11. **A-02r** kimliksiz (eski) kayıt `reconcileCurrentBoot`'ta duvar son tarihinden yeniden tabanlanıp kimlik damgalanır.
    BOOT_COUNT okunamazsa ikinci kimlik olarak `/proc/sys/kernel/random/boot_id` — yalnız uygulama sürecinde okunabildiği
    enstrümantasyonla kanıtlanırsa; aksi halde kalan risk olarak belgelenir. JVM + özellik + mutasyon testleri.

## D — Test altyapısı
12. Gezinme fuzz'ına saat sıçraması ve "süreç ölümü → yeniden bağlanma" eylemleri; ≥100 kısa / ≥100 orta / ≥50 uzun dizi.
13. Mevcut testlerin geçerlilik notları: `countdown_test_mode_pin_cancel_test` "metered" testi yalnız sayacı ölçüyor (Y-06'yı
    kaçırdı); fuzz saat eylemi içermiyor (Y-01/Y-04'ü kaçırdı); `emergency_call_screen_behavior_test` yalnız `failed` sonucu.

## SAFETY / PRODUCT SEMANTIC DECISION REQUIRED (kod değiştirmeyeceğim)
- **Y-02** Telecom isteği kabul ettikten 5 sn sonra her seferinde "Yardım çağrısı henüz gitmedi / Arama bağlanmadı. … manuel
  arayın" + "yeşil arama tuşuna basmanız gerekir". Arama aktifken yanlış, uçak modunda doğru (iki yönlü kanıt). Uygulama
  bağlantıyı bilemez → metin kesin iddia yerine belirsizliği söylemeli; ama "kabul edilmiş istek sonrası elle yeniden arama
  istemek" mükerrer-vs-arama-yok dengesi → sahip.
- **A-03** (değişmedi), **kilit ↔ sonuç ekranı sırası** (değişmedi), gerçek panik tuş takımının kilidi yok sayması (öneri: koru).
- **Y-09** izin açıklaması ve gizlilik detayında var olmayan "konum oturumu" özelliği (Play belirgin açıklama doğruluğu) → sahip/hukuk.
- INFO: Safe Walk başlangıcında "Check-in Zamanlayıcı" başlığı; "degraded modda"; eski "Arama akışı başlatılıyor" bildirimleri.

## Ortam
- API 29 / 36 sistem imajı kurulu değil (her biri ~1–2 GB indirme) → açık onay gerekir.
- Fiziksel cihaz (Telecom/SIM/Doze/OEM/çift SIM/GMS'siz) → PHYSICAL DEVICE REQUIRED. Play Billing → COMMERCE REQUIRED.

## E — İnceleme ajanı bulguları (2026-10-08 18:30 sonrası; onaylı maddelerin "ilgili inceleme ajanı" adımı, güvenlik anlamı değişmez)
Üç ajan (flutter/kotlin/security): CRITICAL 0, HIGH 0. Doğrulanıp düzeltilecekler:
14. **Y-12 (HIGH, bu dalın gerilemesi — yayımlanmış kodda yok)** `SafetyClock.system.monotonic` düz `Stopwatch` =
    Android'de CLOCK_MONOTONIC, cihaz uykusunda DURUR; native alarmlar elapsedRealtime (= CLOCK_BOOTTIME) ile çalışır.
    Native oturumsuz (çevirici) panikte uyku sonrası çevirici, kalan geri sayım kadar GEÇ açılır; native oturumda
    arama gittikten sonra PIN tuşları canlı kalır. Düzeltme: Android'de `dart:ffi` ile libc `clock_gettime(CLOCK_BOOTTIME)`
    (native ile aynı saat); okunamazsa `Stopwatch` ile kesintisiz devam. Emülatörde uyku temsili değil (zorla s2idle:
    MONOTONIC ve BOOTTIME birlikte 88 sn kaybetti) → çalışma-zamanı uyku kanıtı PHYSICAL DEVICE REQUIRED; FFI okuması
    emülatörde (API 29/36) ayrıca doğrulanır.
15. **A-02r** her iki kayıtta kernel boot_id varsa BOOT_COUNT'tan ÖNCE o karar verir (BOOT_COUNT artış zamanına bağımlılık
    kalkar); `ClockChangeReceiver` olayı uzlaştırma istisna atsa da yayar; `ClockChangeEventTest` küresel veri yolu yalıtımı.
16. **Y-05** monotonik anlık görüntüye boot_id (BOOT_COUNT okunamayan cihazda da monotonik karar); aynı-açılış kararı
    native ile aynı sırada; kilit yazımında monotonik anahtarlar duvar anahtarından ÖNCE yazılır/silinir (yarım yazım
    eski, süresi geçmiş monotonik son tarihle kilidi açamaz).
17. **Y-10** desteklenen platformda duraklatma/devam monotonik okuması başarısızsa ya da açılış kimliği uyuşmazsa kilit
    uygulanır (fail-closed); okuma hatası saat geri alma atlatmasını yeniden açmaz.
18. **A-11** taze geri sayımın arm'ı `activeSessionExists` ile reddedilir ve native'de ekranı olmayan ARMED panik bulunursa,
    hata diyaloğu yerine o oturum benimsenir (yeniden gösterme ile hızlı tetikleyici yarışı); yeniden göstermenin gezgin
    bekleme sınırı monotonik.
19. **Test** arm öncesi iptal + `ArmUnknown`; `countdown_pin_before_arm_test` sabit gerçek-zaman gecikmeleri yerine koşul beklemesi.

SECURITY DECISION REQUIRED (kod değiştirmeyeceğim): yeniden başlatma + saat ileri → bir kilit atlanır (saldırgan maliyeti
~1–2 dk yeniden başlatma / kilit). Kapatmak, kilitliyken telefonu yeniden başlatan SAHİBİ de yeniden kilitler → sahip kararı.
LOW/INFO (belgelenir, kod yok): Check-In `safetyClockChanged` süren bir geri yükleme sırasında düşebilir (dar yarış; native
yetkili, sonraki devamda düzelir); kurtarılamayan bozuk monotonik anahtar duvara düşer (bozuk duvar anahtarı gibi
kapatmak sahibi kalıcı kilitleyebilir); A-02 ile A-02r arası derlemede yazılmış kayıt bir açılış boyunca boot_id'siz;
eski kaydın duvar tabanlı yeniden tabanlanması kuyruktaki TIME_SET ile yarışabilir; prova tuş takımı saniyede bir kayıp
sayar; `ArmUnknown` + Y-08 zaman çizelgesinde çift satır olabilir (eksik satırdan iyidir); yeniden bağlanan geri sayım
birincil kişi arada değiştiyse maskeli adı yanlış gösterebilir (10 sn içinde pratikte imkânsız); yanlış PIN kaydı kilit
yazarken ek bir native okuma yapar (ms mertebesi).
