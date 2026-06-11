# KoruBeni — BAĞIMSIZ TAZE KOD DENETİMİ (FRESH AUDIT)

> **DURUM (11 Haziran 2026):**
> **F1 = DÜZELTİLDİ** (`231e7a7`; çözüm ve yeni `ALARM_FIRED` semantiği için bkz.
> [HANDOVER §4.3](HANDOVER.md)) · **F8 = DÜZELTİLDİ** (bu commit) ·
> **F2/F3 = plan aşamasında** · **F4–F7 = açık/triyajda.**
> Aşağıdaki bulgu metinleri 10 Haziran'daki denetim anının kaydıdır; bilerek değiştirilmedi.

> **Tarih:** 10 Haziran 2026 · **main HEAD:** `f4f9f00` · **Tür:** READ-ONLY adversarial denetim.
> Bu denetimde HİÇBİR kaynak dosya değiştirilmedi; yalnız bu rapor (`docs/FRESH_AUDIT_2026-06-10.md`)
> oluşturuldu. Düzeltme önerileri "uygulanmadı" — yalnız tarif edildi (CLAUDE.md kural 5: plan-onay).
>
> **Yöntem:** Dokümanlar (HANDOVER, SPEC, release_risks) yalnızca FAZ 0 filtresi (bağlayıcı
> kararlar + bilinen-konular deny-list'i) kurmak için okundu. Sonrasında her bulgu **bu oturumda
> kaynak/manifest/gradle açılarak** doğrulandı; satır numaraları bu oturumdaki okumalara dayanır.
> Hiçbir doküman iddiası kanıt sayılmadı.

---

## Özet

| ID | Önem | Konu | Tek-cümle |
|----|------|------|-----------|
| F1 | **Kritik** | Native yedek aramanın `failed` sonucu yok sayılıyor | Dart ölüyken native arama başarısız olursa olay sessiz kayboluyor; `alarm_fired` bayrağı Dart fail-safe'ini de bastırıyor. |
| F2 | Yüksek | Deadline'lar RTC duvar-saati (elapsedRealtime değil) | Saat ileri alınırsa/şebeke saat düzeltmesinde check-in/safe-walk/countdown anında ateşler → birincil kişiye yanlış-pozitif arama. |
| F3 | Orta | PIN üstel lockout duvar-saatine bağlı | Sistem saati ileri alınarak kaba-kuvvet kilidi (hem uygulama kilidi hem countdown iptali) baypas edilebilir. |
| F4 | Orta | Boot-restore credential-encrypted depo + BOOT_COMPLETED'a bağlı | Cihaz reboot olur ve hiç kilit açılmazsa aktif oturumlar geri yüklenmez, eskalasyon hiç olmaz. |
| F5 | Orta | Native arama normalize edilmemiş ham numarayı çeviriyor | Dart yolu numarayı normalize ediyor; native (Dart-ölü) yolu ham/biçimli numarayı `Uri.encode` ile çeviriyor — tutarsız. |
| F6 | Düşük | "Önce iptal et, sonra ara" süreç-ölümü penceresi | Dart, native yedeği iptal ettikten sonra aramadan önce ölürse, o senaryo için var olan yedek silinmiş olur. |
| F7 | Düşük | `pending_trigger` tek-slot | İki oturum (check-in + safe-walk) aynı anda Dart-ölüyken biterse bir oturumun pending olayı diğerini ezer. |
| F8 | Düşük | Native bildirim dili TR-kilitli UI ile eşleşmeyebilir | Cihaz sistem dili TR değilse kilit-ekranı acil bildirimi İngilizce çıkabilir. |

---

## F1 — Native yedek aramanın `failed` sonucu yok sayılıyor; başarısızlıkta sessiz toplam-kayıp

- **Önem:** Kritik (acil akışın sessiz başarısızlığı)
- **Senaryo (adım adım):**
  1. Kullanıcı panik/countdown başlatır VEYA check-in/safe-walk süresi dolar; Dart isolate Doze/app-kill
     altında donmuş ya da süreç öldürülmüştür (native yedeğin var olma sebebi tam olarak budur).
  2. AlarmManager `CountdownAlarmReceiver` / `CheckInAlarmReceiver` ateşler. Receiver **önce**
     `alarm_fired=true` + `active=false` yazar, **sonra** `EmergencyExecutor.executeEmergency(...)` çağırır.
  3. `EmergencyExecutor`, `ACTION_CALL` **ve** `ACTION_DIAL` ikisi de başarısız olursa (örn. arka plandan
     activity başlatma kısıtı, dialer yok, exception) `status=failed` döndürür — ama **çağıran receiver bu
     dönüş değerini hiç okumaz.**
  4. Sonuç: arama gitmedi, ama `alarm_fired=true` kalıcı yazıldı. Uygulama yeniden açıldığında Dart yolu
     `didCountdownAlarmFire` / `didCheckInAlarmFire` → `true` görüp **kendi aramasını ve fail-safe'ini atlar.**
  - Countdown'da bu **tamamen sessizdir**: arama yok, bildirim yok, yeniden açılışta hiçbir şey olmaz.
  - Check-in'de arama yok ama "acil durum / süre doldu" bildirimi yine de gönderilir (yani kullanıcıya
    arama yapılmış **izlenimi** verir — yanıltıcı). Dart resume'da fail-safe yine bastırılır.
- **Kanıt (bu oturumda açılan dosyalar):**
  - `EmergencyExecutor` `failed` döndürür ve doc'u açıkça "caller can run its own fail-safe" der —
    [EmergencyExecutor.kt:18-23, 44, 59, 83-85](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyExecutor.kt).
  - Countdown receiver: bayrağı `commit()` ile yazar (43-46), sonucu yok sayar, **başarısızlıkta bildirim
    yok** — [CountdownAlarmReceiver.kt:43-60](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CountdownAlarmReceiver.kt).
  - Check-in receiver: `markAlarmFiredAndDeactivate` sonra `executeEmergency`, sonuç atılır —
    [CheckInAlarmReceiver.kt:51-71](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInAlarmReceiver.kt);
    bayrağı aramadan önce set eden yardımcı [CheckInScheduler.kt:95-103](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt);
    boot-restore aynı desen [CheckInScheduler.kt:209-215](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt).
  - Dart resume'da atlama: countdown [countdown_screen.dart:185-197](../lib/screens/countdown_screen.dart)
    (alarmFired → `Navigator.pop`, fail-safe yok); check-in [check_in_service.dart:368-373](../lib/core/services/check_in_service.dart)
    (nativeAlreadyFired → state temizle, arama/fail-safe yok).
  - Karşılaştırma — Dart **ön plan** countdown yolu `executeEmergencyNative`'in dönüşünü OKUR ve
    `callResult.isFailed` ise `_showBlockingFailure` gösterir ([countdown_screen.dart:287-315](../lib/screens/countdown_screen.dart)).
    Yani fail-safe yalnız Dart yolunda var; native yolda yok ve native bayrağı Dart yolunu bastırıyor.
- **Kullanıcı etkisi:** Native yedeğin devreye girmesi gereken tam senaryoda (Dart ölü) arama başarısız
  olursa, kullanıcı/birincil kişi **hiçbir uyarı almaz** ve "elle ara" fail-safe diyaloğu da hiç açılmaz.
  Ürünün en kritik vaadi (Dart ölse bile arama) bu başarısızlık dalında sessizce çöker. Mantık boşluğu
  cihazdan bağımsız kesindir; tetikleyicinin (aramanın fiilen başarısız olması) sıklığı cihaza bağlıdır
  (arka plan activity-launch kısıtları bunu olası kılar — bkz. "yalnız cihazda kanıtlanır").
- **Asgari düzeltme önerisi (uygulanmadı):** Native receiver'lar `executeEmergency` dönüşünü okusun;
  `status=failed` ise (a) `alarm_fired` bayrağını **set etmesin / geri alsın** ki Dart resume'da tekrar
  denesin, ve (b) yüksek-öncelikli "elle ara" bildirimi (tıklayınca dialer/fail-safe ekranı) göndersin.
  Bayrağı yalnız `directCallStarted`/`dialerOpened` durumunda yazmak en küçük değişikliktir.
- **Deny-list kontrolü: geçmiyor.** HANDOVER §4.3 dedup bayrağını bir *özellik* olarak anlatır; §11
  "yalnız cihazda" maddeleri aramanın **çıktığını** kanıtlamakla ilgilidir. Native dispatch **başarısız
  olduğunda** bayrağın Dart fail-safe'ini bastırması ve countdown'un tamamen sessiz kalması hiçbir
  dokümanda geçmiyor.

---

## F2 — Deadline'lar RTC duvar-saatine dayanıyor (elapsedRealtime yok); saat sıçraması yanlış-pozitif arama yapar

- **Önem:** Yüksek (belirli koşulda akış kırılması + yanlış-pozitif acil arama)
- **Senaryo (adım adım):**
  1. Kullanıcı 30 dk'lık bir check-in/safe-walk (veya 10 sn countdown) başlatır. Deadline **epoch
     (duvar-saati)** olarak saklanır ve alarm `RTC_WAKEUP` ile kurulur.
  2. Sistem duvar-saati ileri sıçrar: manuel saat değişimi, ya da pil bitip yanlış saatle açılan cihazda
     şebeke/NITZ/NTP saat düzeltmesi, ya da uçak modundan/SIM değişiminden sonra otomatik saat senkronu.
  3. Yeni `now`, saklanan deadline'ı geçtiği an `RTC_WAKEUP` alarmı **hemen** ateşler ve Dart ticker da
     `_reconcileWithClock`'ta deadline'ı geçmiş görür → grace atlanabilir, doğrudan eskalasyon.
  4. Sonuç: birincil acil kişiye **istenmeyen otomatik arama** gider (kullanıcı henüz "tehlikede" değil).
     Ters yönde (saat geri alınırsa) eskalasyon gecikir/askıya alınır.
- **Kanıt (bu oturumda açılan dosyalar):**
  - Tüm alarmlar `RTC_WAKEUP`: [CheckInScheduler.kt:241,255,258,271,276,280](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt),
    [CountdownAlarmScheduler.kt:49,65,68,124,129,133](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CountdownAlarmScheduler.kt).
  - Native karşılaştırma `System.currentTimeMillis()` ile: [CheckInScheduler.kt:168](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt),
    [CheckInAlarmReceiver.kt:22](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInAlarmReceiver.kt).
  - Dart deadline'lar epoch ms olarak gönderilir: [emergency_platform_service.dart:67,217](../lib/core/services/emergency_platform_service.dart);
    Dart tarafı `DateTime.now()` ile uzlaştırır: [check_in_service.dart:228-273](../lib/core/services/check_in_service.dart),
    countdown deadline [countdown_screen.dart:151](../lib/screens/countdown_screen.dart).
  - `elapsedRealtime` / `ELAPSED_REALTIME_WAKEUP` repo genelinde **hiç yok** (bu oturumda grep ile doğrulandı).
- **Kullanıcı etkisi:** Bir güvenlik uygulamasında birincil kişiye sebepsiz otomatik arama, kişinin panik
  yaşamasına ve kullanıcının güvenini yitirmesine yol açar; ters yönde ise asıl korumanın gecikmesi.
- **Asgari düzeltme önerisi (uygulanmadı):** Geçen-süre ölçümünde `ELAPSED_REALTIME_WAKEUP` kullanmak saat
  sıçramasına bağışıktır. **Tasarım gerginliği var:** boot-restore mevcut hâlde mutlak duvar-saatini
  saklayarak "reboot sonrası ne zaman ateşlemeli" bilgisini koruyor; elapsedRealtime reboot'ta sıfırlanır.
  Pratik bir orta yol: hem duvar-saati hem elapsedRealtime sakla, ateşleme anında ikisinin de geçmiş
  olmasını şart koş; ya da makul olmayan büyük saat sıçramalarını (örn. > birkaç dk) tespit edip yeniden
  uzlaştır. Karar gereği UI'a dokunulmaz.
- **Deny-list kontrolü: geçmiyor.** Hiçbir dokümanda saat kaynağı (RTC vs elapsed) veya saat-değişimi
  davranışı geçmiyor.

---

## F3 — PIN üstel lockout'u duvar-saatine bağlı; saat ileri alınarak baypas edilebilir

- **Önem:** Orta (kaba-kuvvet korumasının baypası)
- **Senaryo (adım adım):**
  1. Kötü-niyetli kişi (zorlama senaryosu) ya uygulama kilidini açmaya ya da countdown'u iptal etmeye
     çalışarak PIN'i ardışık yanlış girer; 5. denemeden sonra üstel lockout devreye girer (`lockedUntil`
     epoch ms olarak secure storage'a yazılır).
  2. Kişi uygulamadan çıkar, Sistem Ayarları → Tarih/Saat → otomatiği kapatıp saati ileri alır.
  3. `getState()` `DateTime.now().isAfter(lockedUntil)` görüp kilidi **temizler** → kaba-kuvvet yeniden
     serbest. 4 haneli PIN (10⁴ olasılık) lockout olmadan çevrimdışı denenebilir.
- **Kanıt (bu oturumda açılan dosyalar):**
  - Epoch tabanlı kilit ve süresi dolunca temizleme: [pin_lockout_service.dart:42-55, 62-69](../lib/core/services/pin_lockout_service.dart);
    `isLocked => DateTime.now().isBefore(lockedUntil)` [pin_lockout_service.dart:16-17](../lib/core/services/pin_lockout_service.dart).
  - Aynı servis hem uygulama kilidinde [app_unlock_screen.dart:67,121](../lib/screens/app_unlock_screen.dart)
    hem countdown iptalinde [countdown_screen.dart:575,628](../lib/screens/countdown_screen.dart) kullanılıyor —
    yani baypas her iki yüzeyi de etkiler.
- **Kullanıcı etkisi:** Sadece-PIN modeli (biyometrik yasak — bilinçli) PIN'in kaba-kuvvete dayanıklı
  olmasına güvenir. Saat değişimiyle lockout sıfırlanırsa bu güvence ortadan kalkar.
- **Asgari düzeltme önerisi (uygulanmadı):** Lockout penceresini `elapsedRealtime`/monoton sayaca dayandırmak
  veya başarısız-deneme sayacını (zaman değil) esas alıp süreyi yalnız bilgilendirme amaçlı kullanmak; saat
  geriye/ileriye gittiğinde kilidi koru. Sayaç zaten secure storage'da olduğu için süre dolmadan saat
  değişiminin kilidi açmasını engellemek yeterli.
- **Deny-list kontrolü: geçmiyor.** HANDOVER §5 lockout'un *varlığını* belgeler; saat manipülasyonuyla
  baypas edilebilirliği hiçbir yerde geçmiyor.

---

## F4 — Boot-restore credential-encrypted depo + `BOOT_COMPLETED`'a bağlı; reboot sonrası hiç kilit açılmazsa eskalasyon olmaz

- **Önem:** Orta (belirli koşulda akışın tamamen kurulmaması)
- **Senaryo (adım adım):**
  1. Aktif bir check-in/safe-walk (ya da countdown) sürerken cihaz yeniden başlar (pil, çökme, OEM reboot).
  2. `BootCompletedReceiver` yalnız `android.intent.action.BOOT_COMPLETED` dinler ve `EmergencyPrefs`
     varsayılan (credential-encrypted) SharedPreferences'tan okur.
  3. Credential-encrypted depo ve `BOOT_COMPLETED`, cihaz **ilk kez kilidi açılana kadar** erişilebilir/
     yayınlanmaz. Kullanıcı (örn. baygın/erişemiyor) cihazı hiç açmazsa restore hiç çalışmaz; deadline
     geçse bile alarm yeniden kurulmaz ve native eskalasyon **hiç olmaz.**
- **Kanıt (bu oturumda açılan dosyalar):**
  - Receiver yalnız `BOOT_COMPLETED`, `directBootAware` yok: [AndroidManifest.xml:113-120](../android/app/src/main/AndroidManifest.xml).
  - `directBootAware` / device-protected storage / `LOCKED_BOOT_COMPLETED` repo genelinde **hiç yok**
    (bu oturumda grep ile doğrulandı).
  - Prefs varsayılan `MODE_PRIVATE` (credential-encrypted): [EmergencyPrefs.kt:26-27](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyPrefs.kt).
  - Restore tetikleyici [BootCompletedReceiver.kt:8-12](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/BootCompletedReceiver.kt).
- **Kullanıcı etkisi:** Reboot + hiç-açılmama bileşiminde dead-man's-switch sessizce devre dışı kalır.
  Reboot nadirdir ve deadline'lar genelde kısadır, bu yüzden Kritik değil; ama bir güvenlik ürünü için
  belgelenmesi gereken gerçek bir boşluk.
- **Asgari düzeltme önerisi (uygulanmadı):** Restore zincirini `directBootAware` receiver +
  `createDeviceProtectedStorageContext()` ile device-encrypted depoya taşımak `LOCKED_BOOT_COMPLETED`
  öncesi de çalışmayı sağlar. Tam çözüm önemli iş gerektirir; asgari olarak bu sınır README/QA matrisinde
  açıkça not edilmeli ("reboot sonrası en az bir kez kilit açılana dek koruma askıda").
- **Deny-list kontrolü: geçmiyor.** Dokümanlar boot-restore'un *çalıştığını* anlatır; "cihaz reboot olur
  ve hiç açılmazsa restore olmaz" sınırı (Direct Boot / credential-encrypted) hiçbir yerde geçmiyor.

---

## F5 — Native arama yolu normalize edilmemiş ham numarayı çeviriyor (Dart yolu normalize ediyor)

- **Önem:** Orta (yanlış/eksik davranış; cihaza bağlı kırılma riski)
- **Senaryo (adım adım):**
  1. Kullanıcı kişiyi `ACTION_PICK` ile seçer; numara biçimli gelir (boşluk, parantez, tire, NBSP,
     örn. `(555) 123 45 67` veya `+90 555 123 45 67`).
  2. Kişi DB'ye **ham** (`phone.trim()`) saklanır; `normalizedPhone` yalnız bir getter olduğu için
     karşılaştırmada normalize edilir ama saklanan/iletilen alan hamdır.
  3. Native countdown/check-in yedeği bu ham numarayı prefs'e yazar ve `EmergencyExecutor`
     `Uri.parse("tel:${Uri.encode(number)}")` ile çevirir → boşluk `%20`, NBSP `%C2%A0` olarak kodlanır.
     Dart **ön plan** yolu (`CallService.startEmergencyCall`) ise önce `normalizePhoneNumber` ile ayraçları
     siler. Yani aynı numara, yola göre farklı biçimde çevriliyor.
- **Kanıt (bu oturumda açılan dosyalar):**
  - Kişi ham saklanıyor (`.trim()`, normalize değil): [contact_service.dart:44, 62-63, 84](../lib/core/services/contact_service.dart);
    `normalizedPhone` sadece getter [contact_service.dart:377](../lib/core/services/contact_service.dart).
  - Native'e ham geçiş: check-in [check_in_service.dart:463-471, 573-580](../lib/core/services/check_in_service.dart)
    (`primaryContact?.phone` ham), countdown [countdown_screen.dart:135-156, 286-288](../lib/screens/countdown_screen.dart).
  - Native çeviri `Uri.encode` ile: [EmergencyExecutor.kt:88-94](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyExecutor.kt).
  - Karşıt: Dart yolu önce normalize eder: [call_service.dart:73-77](../lib/core/services/call_service.dart),
    [android_intent_service.dart:13-19](../lib/core/services/android_intent_service.dart).
- **Kullanıcı etkisi:** Çoğu OEM dialer'ı `%20`/parantez/tire içeren `tel:` URI'sini tolere eder, ama bu
  garanti değildir; özellikle NBSP (`%C2%A0`) gibi egzotik ayraçlar bazı telefon yığınlarında çevirmeyi
  bozabilir. Bozulursa F1 ile birleşip sessiz başarısızlığa döner. Tutarsızlık kesin (kod düzeyinde), kırılma
  cihaza bağlı.
- **Asgari düzeltme önerisi (uygulanmadı):** Native'e iletmeden ve prefs'e yazmadan ÖNCE numarayı tek bir
  ortak normalleştiriciden geçirmek (Dart yolundaki `normalizePhoneNumber` ile aynı), ya da
  `EmergencyExecutor`'da çevirmeden önce ayraçları sıyırmak. Tercihen kişi DB'ye normalize edilmiş saklanır.
- **Deny-list kontrolü: geçmiyor.** Numara normalizasyonu tutarlılığı hiçbir dokümanda ele alınmamış.

---

## F6 — "Önce native yedeği iptal et, sonra ara" deseni süreç-ölümü penceresi açıyor

- **Önem:** Düşük (dar pencere; yine de native yedeğin amacını zayıflatır)
- **Senaryo (adım adım):**
  1. Countdown/check-in eskalasyon anında Dart, **önce** native yedek alarmı iptal eder (dedup penceresini
     daraltmak için), **sonra** kendi aramasını yapar.
  2. İptal ile kendi araması arasındaki (birkaç MethodChannel round-trip'lik) pencerede süreç ölürse
     (OOM kill, kullanıcı "durmaya zorla"), iptal edilmiş yedek artık ateşlemez → bu senaryo için var olan
     güvenlik ağı kaybolur ve arama hiç gitmez.
- **Kanıt (bu oturumda açılan dosyalar):**
  - Countdown: iptal [countdown_screen.dart:198-208](../lib/screens/countdown_screen.dart) → sonra dispatch
    [countdown_screen.dart:230](../lib/screens/countdown_screen.dart).
  - Check-in: "Cancel … BEFORE any log/notification/call" [check_in_service.dart:375-390](../lib/core/services/check_in_service.dart)
    → sonra dispatch [check_in_service.dart:404-416](../lib/core/services/check_in_service.dart).
- **Kullanıcı etkisi:** Çok dar bir zamanlama penceresinde acil arama kaybı. Olasılık düşük.
- **Asgari düzeltme önerisi (uygulanmadı):** Sıralamayı tersine çevirip (önce ara/dispatch et, sonra
  yedeği iptal et) ya da iptali yalnız dispatch başarıyla teslim edildikten sonra yapmak pencereyi kapatır;
  dedup için F1'deki "yalnız başarıda bayrak yaz" yaklaşımı bununla uyumludur.
- **Deny-list kontrolü: kısmen bitişik — dürüst not.** HANDOVER §4.3(6) "cancel-before-escalation"
  desenini bir *dedup faydası* olarak belgeliyor; ancak bu sıralamanın açtığı **süreç-ölümü penceresini**
  risk olarak ele almıyor. Bu bulgu o riski adlandırır; rehash değil ama bitişik olduğu için Düşük tutuldu.

---

## F7 — `pending_trigger` tek-slot: eşzamanlı iki oturumda olay ezilebilir

- **Önem:** Düşük (büyük ölçüde per-oturum uzlaştırmayla telafi ediliyor)
- **Senaryo (adım adım):**
  1. Hem check-in hem safe-walk aynı anda aktifken Dart ölüdür ve ikisinin de deadline'ı geçer.
  2. Her receiver `emitOrPersist` ile aynı tek anahtara (`pending_trigger`) yazar → ikincisi birincinin
     olayını **ezer**. Açılışta yalnız son yazılan olay tüketilir.
- **Kanıt (bu oturumda açılan dosyalar):**
  - Tek anahtar persist/consume: [EmergencyEventBus.kt:48-57](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyEventBus.kt).
  - Telafi: her oturum açılışta kendi SharedPreferences blob'undan bağımsız uzlaşır
    ([check_in_service.dart:173-273](../lib/core/services/check_in_service.dart)), ve native zaten her oturum
    için ayrı arama yapmıştır. Bu yüzden gerçek bir **arama kaybı** gözlenmez — kayıp yalnız Dart-tarafı
    pending-olay teslimindedir, state reconcile ile kapanır.
- **Kullanıcı etkisi:** Pratikte düşük; ön-plan UI geçişinde bir oturumun olayı işlenmeyebilir ama arama ve
  state temizliği bağımsız yürür.
- **Asgari düzeltme önerisi (uygulanmadı):** `pending_trigger`'ı per-session anahtara çevirmek (mevcut
  `keyFor` deseni gibi) ya da bir liste/kuyruk olarak biriktirip açılışta hepsini tüketmek.
- **Deny-list kontrolü: geçmiyor.** Tek-slot pending-trigger eşzamanlı-oturum davranışı dokümanlarda yok.

---

## F8 — Native bildirim dili TR-kilitli UI ile eşleşmeyebilir

- **Önem:** Düşük (yerelleştirme/kozmetik tutarsızlık)
- **Senaryo (adım adım):**
  1. Uygulama artık TR-kilitli (`startLocale: tr_TR`, non-tr_TR persisted locale açılışta siliniyor);
     UI her zaman Türkçe.
  2. Kilit-ekranı native acil bildirimi dili `NativeNotificationText.resolveLanguage` ile çözülür:
     persisted locale → **sistem locale** → EN. Cihaz sistem dili TR değilse ve persisted bir locale yoksa
     bildirim İngilizce çıkar — TR olan uygulama UI'ı ile çelişir.
- **Kanıt (bu oturumda açılan dosyalar):**
  - Dil çözümü zinciri: [NativeNotificationText.kt:81-133](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/NativeNotificationText.kt).
  - TR-kilit + non-TR locale silme: [main.dart:51-55, 207-210](../lib/main.dart).
- **Kullanıcı etkisi:** Kritik anda kilit-ekranı bildirimi yanlış dilde görünebilir (yalnız metin dili;
  davranış değişmez).
- **Asgari düzeltme önerisi (uygulanmadı):** Uygulama TR-kilitli olduğu için native tarafın persisted
  locale yoksa **sistem yerine TR**'ye düşmesi (varsayılanı EN değil TR yapmak) UI ile tutarlı olur; ya da
  açılışta `flutter.locale`'ı açıkça `tr_TR` yazmak.
- **Deny-list kontrolü: geçmiyor.** Native bildirim dili / sistem-locale fallback uyumsuzluğu dokümanlarda yok.

---

## EK-1: Bilinen olduğu için elendi (deny-list nedeniyle rapor edilmedi)

Aşağıdakiler kodda gözlendi ama **bağlayıcı ürün kararı** veya **bilinen-konu** olduğu için bulgu sayılmadı:

1. **112/911/999 hiçbir akışta aranmıyor** ve boş hedefte arama yok — bağlayıcı karar (HANDOVER §2.1,
   SPEC §0). `EmergencyExecutor`/receiver'lar bilinçli olarak 112'ye düşmüyor; doğru.
2. **Check-in/safe-walk yalnız birincil kişiyi arar (failover yok)**, countdown tüm numaralarda failover
   yapar — bilinçli ayrım (SPEC §0.1). Kodla uyumlu; "tamamlama" yapılmadı.
3. **Biyometrik yok, yalnız PIN** — bağlayıcı (CLAUDE.md 2). Kodda biyometrik akış yok; önerilmedi.
4. **`USE_FULL_SCREEN_INTENT` manifest'te yok**, grace uyarısı fiilen heads-up; `showAlert` izinsizde zarif
   düşüyor — bilinçli ertelenmiş (HANDOVER §2.5). Manifeste eklenmesi önerilmedi.
5. **POST_NOTIFICATIONS reddinde "yine de başlat?" diyaloğu** ile kullanıcı bilgilendiriliyor
   ([check_in_screen.dart:117-142](../lib/screens/check_in_screen.dart), [safe_walk_screen.dart:101-127](../lib/screens/safe_walk_screen.dart));
   bildirim reddinde native uyarı bastırılması ([EmergencyNotificationHelper.kt:102, 145-153](../android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyNotificationHelper.kt))
   zaten ele alınmış bir konu — yeni bulgu sayılmadı.
6. **800+ satırlık dosyalar**, **paket major güncellemeleri**, **kök `gradle` test komutu sorunu**,
   **16KB nihai kanıtı**, **operatör/Play Console işleri**, **`dart format` drift** — hepsi HANDOVER §7/§8/§12
   ve release_risks'te yazılı bilinen borç/risk.
7. **`exported` bileşen yüzeyi** (yalnız MainActivity launcher + izin-filtreli/protected-broadcast
   BOOT receiver) — incelendi, beklenmedik giriş yok; mevcut güvenlik durumuyla uyumlu, yeni bulgu yok.

---

## EK-2: Kodda belirsiz, yalnız cihazda kanıtlanır

Aşağıdakiler kod okumayla **kesinleştirilemeyen**, gerçek-cihaz turu gerektiren noktalardır (bulgu sayılmadı):

1. **F1'in tetiklenme sıklığı:** Arka plandan `ACTION_CALL`/`ACTION_DIAL` activity başlatmanın
   Android 12–15 Background-Activity-Launch kısıtlarına (FGS varken/yokken) ne sıklıkta takıldığı yalnız
   cihazda ölçülür. Mantık boşluğu (F1) kesindir; *ne kadar sık `failed` döneceği* cihaza bağlıdır.
2. **F5'in fiili kırılması:** `%20`/parantez/NBSP içeren `tel:` URI'sini hangi OEM dialer'larının/telefon
   yığınlarının tolere edip etmediği yalnız cihazda görülür.
3. **F2'nin gerçek tetikleyicileri:** NITZ/NTP otomatik saat düzeltmesinin sahada ne sıklıkta büyük sıçrama
   ürettiği cihaz/operatör bağımlıdır (kod-düzeyi gerçek — RTC kullanımı — kesin).
4. **Doze/OEM-kill altında native yedeğin fiilen çıkması, dedup yarışının gözlenmesi, exact-alarm reddi
   degraded davranışı** — HANDOVER §11'de zaten cihaz-turu bekleyen maddeler; burada tekrar edilmedi.

> Not: Cihaz QA'sı **imzalı release AAB** üstünde yapılmalı (R8/obfuscation yalnız release'te aktif).
