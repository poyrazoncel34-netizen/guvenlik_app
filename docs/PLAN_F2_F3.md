# F2 / F3 — ONAYLI TASARIMLAR (DONDURULDU)

> **Durum:** Tasarımlar 11 Haziran 2026'da onaylandı ve DONDURULDU. **Uygulama ŞİMDİ değil** —
> cihaz QA / lansman sonrası, ayrı onayla başlar. Bu dosya, planların sohbet kaydında
> kaybolmaması için tek-kaynak kayıttır; gelecek oturum buradan okur.
> Bulgu tanımları: [FRESH_AUDIT_2026-06-10.md](FRESH_AUDIT_2026-06-10.md) (F2, F3).

---

## F2 — Check-in/safe-walk deadline'ları için elapsed-hibrit saat kaynağı

### Tehdit modeli
DST/saat dilimi değişimi epoch'u DEĞİŞTİRMEZ — kapsam dışı. Hedeflenen iki vektör:
1. **NITZ/operatör saat senkronu:** pil bitmiş cihaz yanlış saatle açılıp şebeke saati
   düzeltince ileri sıçrama → birincil kişiye yanlış-pozitif arama.
2. **Elle saat değişikliği:** duress senaryosunda saat geri alınarak eskalasyonun süresiz
   ertelenmesi.

### Kapsam daraltması (KARAR)
**Countdown KAPSAM DIŞI.** 10sn+2sn penceresinde saat sıçramasının tam o anda deadline'ı
aşması pratikte anlamsız; kullanıcı zaten ekranda (PIN fail-safe'i orada). Yalnız
check-in/safe-walk hattı (`CheckInScheduler`) değişir.

### Mekanizma
- Kurulumda native **çift kayıt**: mevcut `deadline_epoch_ms` (korunur — boot-restore
  rekonstrüksiyonu + Dart UI) + YENİ `deadline_elapsed_ms`
  (`SystemClock.elapsedRealtime() + kalanMs`) + YENİ `boot_count`
  (`Settings.Global.BOOT_COUNT`; elapsed yalnız aynı boot içinde anlamlı).
- Canlı oturum alarmı `ELAPSED_REALTIME_WAKEUP` ile kurulur (`elapsedRealtime` derin uykuda
  da ilerler) — duvar-saati sıçramaları alarmı etkilemez.
- **Boot-restore:** elapsed sıfırlanır → epoch'tan rekonstrüksiyon (bugünkü mantık):
  epoch gelecekte → yeni elapsed hedefi `elapsedNow + (epoch − now)` ile yeniden kur;
  epoch geçmişte → mevcut eskalasyon yolu aynen.
- **KABUL EDİLEN ARTIK RİSK:** reboot ÜZERİNDEN saat manipülasyonu mümkün kalır
  (uygulamalara açık reboot-aşan monoton saat yok). HANDOVER'a bilinen sınır olarak yazılır.

### KAPANMIŞ KARAR — MY_PACKAGE_REPLACED (plan eki)
`BootCompletedReceiver` intent-filter'ına `android.intent.action.MY_PACKAGE_REPLACED`
eklenir ve aynı restore mantığına bağlanır:
- `boot_count` DEĞİŞMEMİŞSE → elapsed geçerli ama alarmlar silinmiş kabul →
  **elapsed'ten yeniden kur**;
- `boot_count` DEĞİŞMİŞSE → mevcut epoch-rekonstrüksiyonu.
**Gerekçe:** reconcile-içi yeniden-kurma yalnız uygulama açılırsa çalışır; Play otomatik
güncellemesi oturum ortasında alarmları siler ve uygulama açılmazsa eskalasyon kaybolur.
**Force-stop artığı bilinen sınır olarak kalır** (force-stop edilen uygulama broadcast almaz).

### Tek-doğru-kaynak (KARAR: bilgilendirme stringi YOK — sessiz benimseme)
- Ateşleme kararında **native elapsed kazanır** (yürütücü o).
- Dart ticker UI için DateTime ile saymaya devam eder; resume'da yeni
  `getCheckInRemaining(session)` sorgusuyla native kalan alınır; sapma > 30sn ise Dart
  `_endAt`'i native kalana göre yeniden kurar — **yeni ekran/string YOK, sessiz benimseme**
  (UI'da kalan süre düzeltilmiş görünür).
- Dart'ın reconcile-eskalasyonu, native ulaşılabilirken "vadesi gelmedi" diyorsa eskalasyon
  yerine **yeniden senkron** yapar; native'e ulaşılamıyorsa (timeout) bugünkü duvar-saati
  eskalasyonu korunur — kaçırılan arama, erken aramadan daha kötü (ürün duruşu).

### Dosya kapsamı
`EmergencyPrefs.kt` (+2 anahtar) · `CheckInScheduler.kt` (çift-yazım, ELAPSED alarm,
restore rekonstrüksiyonu, `remainingMsFor`) · `CheckInAlarmReceiver.kt` (faz mantığı aynı) ·
`BootCompletedReceiver.kt` + `AndroidManifest.xml` (MY_PACKAGE_REPLACED) ·
`EmergencyPlatformHandler.kt` + `emergency_platform_service.dart` (+`getCheckInRemaining`) ·
`check_in_service.dart` (reconcile senkronu + eskalasyon guard'ı). UI/string yok.

### Test stratejisi
Robolectric: `ShadowAlarmManager.nextScheduledAlarm.type == ELAPSED_REALTIME_WAKEUP`;
`ShadowSystemClock` duvar-saati ileri → alarm ERKEN ateşlemez; boot-count değişiminde
epoch-rekonstrüksiyon; MY_PACKAGE_REPLACED dalları (boot_count aynı → elapsed'ten kurulum).
Dart: reconcile'ın native'e danıştığı kaynak-kontrat + mock kanal birim testleri.
Gerçek NITZ sıçraması → HANDOVER §11 cihaz-QA maddesi.

### Geriye uyum / migrasyon
Anahtarlar ekleme: yeni build `deadline_elapsed_ms` yoksa epoch'tan üretir ve geri yazar;
eski build yeni anahtarları yok sayar. Aktif oturum ortasında güncelleme =
MY_PACKAGE_REPLACED restore'u kapsar.

### Riskler
Reboot-aşan artık pencere (belgelenir) · resume'da +1 kanal round-trip (timeout'lu, mevcut
davranışa düşer) · UI'da kalan sürenin "zıplaması" (kabul).

---

## F3 — PIN lockout: (elapsedRealtime, bootCount) çapası

### Şema
Kilitlenince secure storage'a: `lockout_window_ms` + `lockout_started_elapsed_ms` +
`lockout_boot_count` (epoch `lockedUntil` kaldırılır; `failed_attempts` aynen).
Aynı boot içinde kalan = `window − (elapsedNow − started)` → saat değişimi etkisiz.

### KAPANMIŞ KARAR — reboot dalı: (b)
`boot_count` uyuşmazlığında **aynı `n` ile mevcut pencere yeniden başlar** (eskalasyonsuz).
**Gerekçe (duress ↔ yanlış-alarm gerilimi):** duress saldırganının fiziksel erişimi var,
reboot onun için bedava; duvar-saati fallback'i (a) "saati ileri al + reboot" ile baypası
aynen geri getirirdi. Meşru kullanıcının "yanlış-alarm countdown'unu iptal edememe" maliyeti
reboot senaryosunda fiilen yok — countdown reboot'u atlatmaz (aşağıdaki teyit). Kalan tek
maliyet: uygulama-kilidi penceresinin reboot sonrası baştan sayması; pencereyi kullanıcının
kendi ≥5 hatalı denemesi belirlemiştir.

### KAPANMIŞ KARAR — üstel pencereye TAVAN: 1 saat
**Gerekçe:** tavan sonrası deneme-başı 1 saat, kaba kuvveti pratik dışı tutar; tavansız seri
stres altındaki meşru sahibi saatlerce dışarıda bırakabilir — duress ürününde sahibi
kilitlemek de başarısızlık modudur.

### Teyit notu (uygulamada yeniden doğrulanacak)
"Countdown'un boot-restore'u yok" iddiası bu oturumda koddan doğrulandı:
`BootCompletedReceiver.onReceive` yalnız `CheckInScheduler.restoreAfterBoot` çağırır
(BootCompletedReceiver.kt:8-12); countdown prefs'i (`countdown_*`) hiçbir boot yolunda
okunmaz. F3 uygulamasında bu teyit tekrarlanıp dokümana sonuca göre yazılır
(karar iki durumda da değişmez).

### Dosya kapsamı
`pin_lockout_service.dart` (şema + `now()`/`elapsed()` saat-sağlayıcı enjeksiyonu —
test edilebilirlik) · `EmergencyPlatformHandler.kt` `getDeviceState`'e `elapsedRealtimeMs`
+ `bootCount` · `emergency_platform_service.dart` (alan geçirme). Ekranlar
(`app_unlock_screen`, `countdown_screen`) değişmez — servis API'si aynı.

### Geriye uyum
İlk okumada legacy `pin_lockout_until_ms` varsa kalan süre yeni çapaya tek seferlik taşınır
(kalan = lockedUntil − now; >0 ise o uzunlukta yeni elapsed penceresi), legacy anahtar
silinir. Kanal ulaşılamazsa (web/test) mevcut duvar-saati davranışına düşülür — fail-open,
belgelenir.

### Test stratejisi
Sahte saat sağlayıcılarıyla birim testler: saat-ileri kilidi AÇMAZ; bootCount değişimi
pencereyi aynı `n` ile yeniden başlatır; 1 saat tavanı; legacy migrasyon; üstel seri
korunur; reset. Kaynak-kontrat: `DateTime.now().isAfter(lockedUntil)` kalıbı kilit
kararından çıkar.

### Riskler
Unlock ekranı kanal verisine dokunur (timeout'ta fail-open) · pencere-yeniden-başlatmanın
UX algısı (bilinçli güvenlik tercihi) · tavanla birlikte deneme sayacı sınırsız büyür
(taşma riski yok — int64).

---

## Backlog (bu planların kapsamı DIŞI — yalnız adlandırma)

- **F6:** Eskalasyonda "önce native yedeği iptal et, sonra ara" sıralamasının süreç-ölümü
  penceresi.
- **F7:** `pending_trigger` tek-slot — eşzamanlı check-in + safe-walk'ta Dart-tarafı olay
  ezilmesi.
