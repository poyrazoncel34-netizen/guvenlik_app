# SPEC — M2: Check-In / Safe-Walk Süre Dolumu (Grace-Period'lı Dead-Man's-Switch)

> Durum: NİHAİ KARARLAR + UYGULAMA SPEC'İ. Bu turda kaynak kod **değiştirilmedi**.
> Uygulama ayrı, temiz oturumda yapılacak. UI/tema/görsel tasarım DEĞİŞMEZ.
>
> ⚠️ **BU TUR YALNIZ SPEC GÜNCELLEMESİDİR.** `lib/` ve `android/` altında hiçbir
> kaynak dosyaya dokunulmadı. Strings (tr-TR.json / en-US.json) **değişmedi**.

---

## 0. Nihai Kararlar (BAĞLAYICI)

Bu bölüm önceki turun "onaylanmış kararlarını" ezer. Çelişki olursa burası geçerlidir.

| # | Konu | NİHAİ KARAR |
|---|------|-------------|
| 1 | **Arama hedefi** | Süre + grace dolunca **YALNIZ BİRİNCİL (ana) acil kişi** aranır. Diğer acil kişiler **ARANMAZ**. **112 ARANMAZ.** |
| 2 | **Çoklu-numara failover** | **YOK.** Birincil kişi tek hedeftir. Fallback numara listesi yoktur. |
| 3 | **"Açmazsa" mantığı** | **YOK ve OLAMAZ.** Android, normal uygulamalara karşı-taraf çağrı durumu (açıldı/açılmadı/meşgul) **vermez**. "Kişi açmazsa X yap" dalı **teknik olarak kurulamaz**. Uygulama yalnız aramayı başlatır; gerisi sistem telefon uygulamasındadır. |
| 4 | **Native-yedek arama** | **EKLE (M2'nin asıl işi).** Grace de dolunca, Dart isolate ölü olsa bile (Doze/app-kill) birincil kişiyi **native** olarak ara. Yol: izin varsa `ACTION_CALL`, yoksa `ACTION_DIAL` (mevcut desen). |
| 5 | **Grace** | Zaten var (60sn). **Korunuyor, değişmiyor.** İptal = tek-dokunuş "Güvendeyim" (**PIN YOK** — countdown'dan kasıtlı farklı). |
| 6 | **Safe-walk ↔ check-in** | **Aynı `sessionId` state machine + AYNI grace UI bileşeni** (tek bileşen, tekrar yok). |
| 7 | **Full-screen-intent** | (a) Play Console'da çekirdek-işlev beyanı verilecek — **geliştirici/Console işi, SPEC yalnız NOT eder, kod değil.** (b) **KOD**, full-screen izni reddini **zarif** ele alır: izin yoksa normal yüksek-öncelikli bildirime düşer, **ÇÖKMEZ**. |
| 8 | **Metin güncelleme** | Kod güçlenince "uygulama açıksa" metni gerçeğin gerisinde kalır. AMA metin değişikliği **gerçek-cihaz turu kod kanıtlanana kadar BEKLER**. **Bu turda string DEĞİŞMEZ.** Metin = ayrı, sonraki adım. |

### 0.1 Countdown/panik akışından KASITLI FARK (kritik)

Bu, M2'nin can alıcı noktasıdır. **Check-in/safe-walk expiry yolu, countdown/panik
yolundan bilinçli olarak farklıdır:**

| | **Countdown / Panik** (DEĞİŞMEZ) | **Check-in / Safe-walk expiry** (M2) |
|---|---|---|
| Aranan numaralar | **TÜM** acil kişiler denenir | **YALNIZ birincil** kişi |
| 112 fallback | **VAR** (son çare) | **YOK** |
| İptal | PIN gerekir | Tek-dokunuş "Güvendeyim" (PIN yok) |

**Bu farkın NEDENİ — ve neden teknik kısıt DEĞİL, bilinçli ürün kararı olduğu:**
Geliştirici, kaçırılan check-in / safe-walk senaryosunda yalnızca güvenilen birincil
kişinin haberdar edilmesini istiyor. Bu senaryo bir panik anı değil, bir "yaşam belirtisi
alınamadı" sinyalidir; otomatik 112 araması ve tüm rehberin taranması, yanlış-pozitif
(uyuyakalma, telefonu duymama) durumunda orantısız ve istenmeyen sonuç doğurur. Panik/
countdown ise kullanıcının **bilerek** tetiklediği gerçek acil durumdur; orada tam
eskalasyon (tüm numaralar + 112) doğru davranıştır. **Yani fark, Android'in bir kısıtı
yüzünden değil; iki senaryonun farklı risk profili yüzünden, geliştiricinin bilinçli
tercihiyle vardır.** SPEC, kodu yazacak oturumun bu farkı "eksiklik" sanıp 112/failover
"tamamlamasın" diye bunu açıkça belgeler.

---

## 1. Mevcut Davranış Özeti (kanıtlı)

### 1.1 Grace-period zaten var
Check-in tarafında **60 saniyelik grace-period dead-man's-switch zaten uygulanmış**:

- `CheckInService._gracePeriodSeconds = 60` — [check_in_service.dart:33](lib/core/services/check_in_service.dart#L33)
- Ana süre dolunca grace'e geçiş — [check_in_service.dart:295-314](lib/core/services/check_in_service.dart#L295) (`_onMainTimerExpired`)
- Grace dolunca arama — [check_in_service.dart:328](lib/core/services/check_in_service.dart#L328) (`_triggerEmergency`)

### 1.2 Expiry akışı (adım adım — mevcut)

**Check-in** (`CheckInService` + native `CheckInScheduler`):
1. `start(minutes)` → native `scheduleCheckIn(phase:'main', graceDuration:60sn)` ([check_in_service.dart:500](lib/core/services/check_in_service.dart#L500)) + Dart ticker + FGS başlatılır.
2. **Ana süre dolar** → native [CheckInAlarmReceiver.kt:16-37](android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInAlarmReceiver.kt#L16): `checkInGraceStarted` event + **bildirim** yayar, grace alarmı kurar.
   Dart canlıysa → [emergency_trigger_host.dart:105](lib/core/widgets/emergency_trigger_host.dart#L105) → `handleNativeGraceStarted()` → grace ticker.
3. **Grace (60sn) dolar** → native [CheckInAlarmReceiver.kt:39-52](android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInAlarmReceiver.kt#L39): `checkInExpired` event + **yalnız bildirim**. **Native arama YAPMAZ.**
4. Dart canlıysa → `_handleCheckInExpired` → `handleNativeExpired()` → `_triggerEmergency()` → Dart `CallService.startEmergencyCall` ile arar.
5. **Dart isolate ölüyse (Doze / app kill) → yalnız bildirim; ARAMA GİTMEZ.** ← M2'nin kapattığı boşluk.

**Safe-walk** ([safe_walk_screen.dart](lib/screens/safe_walk_screen.dart)):
- Native'i `phase:'grace', graceDuration:0` ile kurar ([safe_walk_screen.dart:187-192](lib/screens/safe_walk_screen.dart#L187)) → **grace YOK, anında dolum**.
- `CheckInService`'i kullanmaz; kendi timer'ı + 2 dk önce ön-uyarı bildirimi var.
- Expiry'de native `checkInExpired` → Dart canlıysa [emergency_trigger_host.dart:162](lib/core/widgets/emergency_trigger_host.dart#L162) **CountdownScreen** açar.
- Dart ölüyse → yalnız bildirim; arama gitmez.

### 1.3 Arama yolu (ACTION_CALL vs ACTION_DIAL)
- **Native (countdown yolu):** [EmergencyExecutor.kt:48-79](android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyExecutor.kt#L48) — `CALL_PHONE` izni VARSA `ACTION_CALL`, YOKSA `ACTION_DIAL`. Wake-lock (120sn) alır.
  > Not: Countdown/panik yolu ayrıca tüm numaraları dener + 112 son-çaresine sahiptir; **bu davranış M2'de DOKUNULMAZ.** M2 native-yedek, EmergencyExecutor'un **tek-numara** arama yeteneğini birincil kişi için kullanır.
- **Güncel yol:** Flutter yalnız typed token taşır. Native coordinator fallback'i önce
  kaydeder/post eder ve `TelecomManager.placeCall()` ile doğrulanmamış istek gönderir.
  `ACTION_DIAL` yalnız görünür Activity veya TTL doğrulayan kullanıcı bildirimi eylemidir.

### 1.4 Reliability altyapısı (mevcut)
- Native AlarmManager `setExactAndAllowWhileIdle` (Doze-geçirgen) — [CheckInScheduler.kt:178](android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt#L178); exact izni yoksa inexact fallback.
- Boot sonrası geri yükleme — [CheckInScheduler.kt:70-170](android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt#L70) (`restoreAfterBoot`); expired-after-boot **yalnız bildirim** atıyor.
- Dedup: `CheckInExpiryCoordinator.tryClaim` (isolate-içi tek-arama kilidi) — [check_in_expiry_coordinator.dart](lib/core/services/check_in_expiry_coordinator.dart).
- Countdown dedup deseni: `dispatchId` + `KEY_COUNTDOWN_ALARM_FIRED` + `didCountdownAlarmFire` (Dart↔native çift-arama önleme).

---

## 2. Metin-vs-Kod Uyumsuzluğu Bulgusu

**Şu an uyumsuzluk YOK.** Metinler bilinçli olarak şartlı yazılmış ([tr-TR.json](assets/translations/tr-TR.json)): "uygulama açıksa acil arama akışı hazırlanır", "arka planda davranış cihaz izinlerine bağlıdır" gibi.

> **M2 sonucu:** Native-yedek arama eklenince (Karar 4), "uygulama açıksa" kaydı **kodun gerisinde kalır** (kod artık arka planda da arayacak). Metin GÜÇLENDİRİLMELİ.
> **ANCAK — Karar 8 gereği:** metin değişikliği **bu turda YAPILMAZ.** Önce kod yazılır, **gerçek cihazda** (Doze/app-kill turu) native-yedek aramanın çalıştığı kanıtlanır; metin değişikliği **ondan sonra, ayrı bir adımda** ele alınır. Yanlış/abartılı vaat (kod henüz kanıtlanmadan "arka planda da arar" demek) bu sırayla engellenir.

---

## 3. Hedef Davranış — State Machine

### 3.1 Genelleştirilmiş oturum modeli
Tek bir paylaşılan kontrolör, `sessionId ∈ {check_in, safe_walk}` parametresiyle çalışır.
**İkisi de aynı faz makinesini ve AYNI grace UI bileşenini kullanır** (Karar 6 — tek bileşen, tekrar yok):

```
IDLE
 └─ start(minutes, sessionId)
      → native scheduleCheckIn(phase=main, graceDuration=60s, primaryNumber)
        (NOT: fallbackNumbers YOK — yalnız birincil kişi saklanır)
      → Dart ana ticker, FGS
      → ACTIVE(main)

ACTIVE(main)
 ├─ confirmSafe()   → süreyi sıfırla (tek dokunuş, PIN yok)  → ACTIVE(main)
 ├─ stop()/cancel() → IDLE  (tüm native alarmlar + bayraklar temizlenir)
 └─ main deadline doldu
      → native: checkInGraceStarted event + HIGH-PRIORITY bildirim (ses+titreşim)
        + (izin varsa) full-screen-intent; izin yoksa düz heads-up'a düş (çökme yok)
      → native: grace alarmı kur (phase=grace, deadline=now+60s)
      → Dart canlıysa: grace ticker + AYNI ekran-içi grace uyarı bileşeni
      → GRACE

GRACE  (60 saniye)
 ├─ confirmSafe()   → ACTIVE(main)'e dön (tek dokunuş)   ← TEK iptal yolu
 ├─ stop()/cancel() → IDLE
 └─ grace deadline doldu
      → ESCALATE

ESCALATE  (atomik, dedup'lı — TEK arama, TEK hedef)
 1. tek-arama claim'i al (native-fired bayrağı + isolate-içi tryClaim)
 2. arama yolu — YALNIZ BİRİNCİL KİŞİ:
      CALL_PHONE izni VAR  → ACTION_CALL (doğrudan)   ┐ EmergencyExecutor
      izin YOK             → ACTION_DIAL (dialer)      ┘ (tek numara)
    ✗ çoklu-numara failover YOK
    ✗ 112 fallback YOK
    ✗ "açmazsa" dalı YOK (Android karşı-taraf durumu vermez)
 3. activity log + emergency bildirimi
 4. Dart canlıysa: EmergencyCallScreen'e geçiş (mevcut UI)
      → DONE
```

### 3.2 İki yürütücü, tek karar noktası, tek hedef
ESCALATE iki yoldan tetiklenebilir; **ikisi de aynı dedup kilidini paylaşır ve yalnız birincil kişiyi arar**:

- **Native yol (PRIMER yedek — M2'nin asıl işi):** `CheckInAlarmReceiver` grace-expiry'de doğrudan `EmergencyExecutor.executeEmergency(primaryNumber)` çağırır. **Dart ölü olsa bile çalışır** (Doze/app-kill). Arama sonrası `KEY_CHECK_IN_ALARM_FIRED_<session> = true` yazar.
- **Dart yol (uygulama açıkken):** `handleNativeExpired()` → arama. **Önce** native-fired bayrağını sorar (`didCheckInAlarmFire`), set ise çift-aramayı atlar (countdown'daki `didCountdownAlarmFire` deseninin birebir kopyası).

### 3.3 Yanlış-pozitif dengesi (KRİTİK — Karar 4 + Karar 5 birleşimi)
Native otomatik arama + tek-dokunuş iptal birleşince, kaçırılan check-in arka planda bile arama yapacak. **Tek-dokunuş iptal + native otomatik arama birleşimi yanlış-pozitif / çift-tetikleme riskini artırır** — bu yüzden dedup KORUNUR ve şu mekanizmalarla dengelenir:
- **Grace bildirimi yüksek öncelikli + ses + titreşim + (izin varsa) full-screen-intent** (`CHANNEL_ALERTS`, `IMPORTANCE_HIGH`) — kullanıcının 60sn içinde fark edip iptal etme şansı maksimum. Full-screen izni yoksa düz heads-up'a düşülür (Karar 7b, çökme yok).
- **60sn grace** korunur (kısaltılmaz) — uyuyakalma/sessiz mod için tampon.
- **Tam dedup** — Dart + native asla iki kez aramaz (`KEY_CHECK_IN_ALARM_FIRED` + `tryClaim`).
- **stop()/confirmSafe ANINDA native alarmı iptal eder** — iptal sonrası alarm ateşlenirse `KEY_CHECK_IN_ACTIVE` kontrolüyle reddedilir (countdown'daki `KEY_COUNTDOWN_ACTIVE` deseni gibi).

### 3.4 Arama hedefi gerekçesi (Play uyumu DAHİL)
- Seçim: **yalnız birincil kişi; izin varsa ACTION_CALL, yoksa ACTION_DIAL. 112 yok, failover yok.**
- Gerekçe: kaçırılan check-in/safe-walk bir "yaşam belirtisi alınamadı" sinyalidir; güvenilen birincil kişiye ulaşmak orantılı çıktıdır. Otomatik 112 + tüm rehber, yanlış-pozitifte orantısızdır (bkz. §0.1).
- **Play uyumu:** `CALL_PHONE` yüksek-riskli izin. Arka plan otomatik aramada kullanımı, Play Console'da çekirdek-işlev / izin beyanı gerektirir. **Bu desen uygulamada zaten mevcuttur** (countdown/panik yolu `EmergencyExecutor` ile arka plandan ACTION_CALL yapıyor). M2, var olan ve onaylanmış davranışı **daha dar bir hedefe** (tek kişi, 112 yok) genişletir; **yeni izin / yeni risk sınıfı eklemez** — aksine countdown'dan daha sınırlı bir eskalasyondur.

### 3.5 Reliability / boot
- Native alarm `setExactAndAllowWhileIdle` korunur (Doze-geçirgen). Exact izni yoksa inexact fallback + `nativeScheduleDegraded` bayrağı kullanıcıya gösterilir (mevcut davranış).
- **Boot-restore expired yolu** ([CheckInScheduler.kt:153-169](android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt#L153)) artık yalnız bildirim değil, `EmergencyExecutor.executeEmergency(primaryNumber)` de çağırmalı (Karar 4 ile tutarlı) — aynı dedup bayrağıyla, yine yalnız birincil kişi.

### 3.6 Full-screen-intent — iki ayrı madde (Karar 7)
- **(a) Console beyanı — KOD DEĞİL:** `USE_FULL_SCREEN_INTENT`, Play'de çekirdek-işlev gerekçesi ister. Bu beyan **geliştirici/Play Console işidir**; SPEC yalnız NOT eder, bu turda kod tarafı bir şey yapmaz.
- **(b) Zarif izin-reddi — KOD:** Cihaz/sürüm full-screen izni vermezse (Android 14+ runtime kısıtı dâhil), kod **çökmemeli**; full-screen intent başarısız/izinsizse **normal yüksek-öncelikli (heads-up) bildirime düşmeli**. Bu, kodun bu turdan sonraki uygulama oturumunda ele alacağı somut bir gereksinimdir.

### 3.7 Metin (içerik) — BU TURDA DEĞİŞMEZ (Karar 8)
- "uygulama açıksa/açıkken" kayıtları (`check_in_warning`, `check_in_grace_info`, `check_in_notification_body`, `safe_walk_desc`) kod güçlenince gerçeğin gerisinde kalacak.
- **Ama metin değişikliği ayrı, sonraki adımdır ve kod gerçek-cihazda kanıtlanana kadar bekler.** Bu turda **hiçbir string değişmez**. `feature_warning_checkin_content` "fiziksel koruma sağlamaz" disclaimer'ı her hâlükârda KORUNUR (yasal/Play).

---

## 4. Dokunulacak Dosyalar (üst düzey — kod değil, sonraki tur)

| Dosya | Değişiklik |
|-------|-----------|
| `android/.../emergency/EmergencyPrefs.kt` | Yeni anahtarlar: per-session `KEY_CHECK_IN_PRIMARY_NUMBER`, `KEY_CHECK_IN_ALARM_FIRED`, dispatch/claim id. **(`KEY_CHECK_IN_FALLBACK_NUMBERS` YOK — failover yok.)** |
| `android/.../emergency/CheckInScheduler.kt` | `schedule()` artık `primaryNumber`'ı da saklar (tek numara). `restoreAfterBoot` expired yolu `EmergencyExecutor.executeEmergency(primaryNumber)` çağırır. |
| `android/.../emergency/CheckInAlarmReceiver.kt` | Grace-expiry (`checkInExpired`) dalında: `KEY_CHECK_IN_ACTIVE` kontrolü → aktifse `EmergencyExecutor.executeEmergency(primaryNumber)` çağır, `KEY_CHECK_IN_ALARM_FIRED=true` yaz; sonra event+bildirim. Grace-start bildirimi HIGH importance + ses/titreşim + full-screen-intent (izin yoksa heads-up'a düş, çökme yok). |
| `android/.../emergency/EmergencyExecutor.kt` | **Muhtemelen DEĞİŞMEZ.** Tek-numara `executeEmergency` zaten var; check-in yedeği bunu birincil kişi için çağırır. **112/çoklu-numara mantığına dokunulmaz** (o countdown'a ait). |
| `android/.../emergency/EmergencyPlatformHandler.kt` | `scheduleCheckIn` argümanlarına `primaryNumber` ekle. Yeni method: `didCheckInAlarmFire(sessionId)`. |
| `lib/core/services/emergency_platform_service.dart` | `scheduleCheckIn`'e `primaryNumber` parametresi. Yeni `didCheckInAlarmFire({sessionId})`. |
| `lib/core/services/check_in_service.dart` | (a) `sessionId` ile genelleştir (check_in/safe_walk). (b) Schedule'da `primaryNumber` geç. (c) `_triggerEmergency` öncesi `didCheckInAlarmFire` dedup kontrolü. (d) Numara çözümü native ile birebir aynı (yalnız birincil kişi). |
| `lib/screens/safe_walk_screen.dart` | Kendi timer + grace=0 yolunu bırak; paylaşılan kontrolörü `sessionId=safe_walk` ile kullan (60sn grace). 2 dk ön-uyarı korunur. **Görsel değişmez** — mevcut "acele edin/urgent warning" UI'ı AYNI grace bileşeniyle beslenir. |
| `lib/core/widgets/emergency_trigger_host.dart` | `_handleCheckInExpired` her iki session için paylaşılan kontrolöre + AYNI grace UI bileşenine yönlensin (safe-walk artık ayrı CountdownScreen açmaz; ortak grace bileşeni kullanılır — bkz. §6). |
| `assets/translations/*.json` | **BU TURDA DOKUNULMAZ** (Karar 8). Sonraki adım, kod kanıtlandıktan sonra. |

> **Dokunulmayacaklar:** `call_service.dart` mantığı, `CountdownAlarmReceiver`/`CountdownAlarmScheduler` ve countdown'un tüm-numara+112 davranışı (panik yolu bozulmaz), tema/renk/widget yerleşimi, PIN/auth, offline-first çağrı yolu, **tüm string'ler.**

---

## 5. Yeniden Kullanılan Countdown Parçaları

- **Dedup deseni:** `dispatchId` + `KEY_..._ALARM_FIRED` + `did...AlarmFire` → check-in/safe-walk için birebir uyarlanır (`KEY_CHECK_IN_ALARM_FIRED_<session>`, `didCheckInAlarmFire`). **KORUNUR — kritik:** tek-dokunuş iptal + native otomatik arama birleşimi çift-tetikleme riskini artırdığından dedup zorunludur.
- **Native yürütücü:** `EmergencyExecutor.executeEmergency` (wake-lock + ACTION_CALL/DIAL) — **tek numara modunda** kullanılır. 112/çoklu-numara dalları check-in yedeğinde **devreye girmez**.
- **"İptal sonrası alarm reddi":** Countdown `KEY_COUNTDOWN_ACTIVE` → check-in `KEY_CHECK_IN_ACTIVE` kontrolü (native arama dalında uygulanır).
- **Tek dokunuş "Güvendeyim"** countdown'un PIN'inden AYRILIR (Karar 5) — bilinçli; paylaşılmaz.

---

## 6. Safe-walk Grace UI — tek paylaşılan bileşen (Karar 6)

Safe-walk artık expiry'de ayrı bir `CountdownScreen` **açmaz**. Onun yerine check-in ile
**aynı grace UI bileşenini** kullanır (app foreground iken). CLAUDE.md "UI değişmez" gereği:
- **Yeni ekran / yeni tasarım eklenmez.**
- Mevcut bileşenler `sessionId` ile yeniden bağlanır; safe-walk'ın mevcut "acele edin/urgent"
  görseli aynı grace fazıyla beslenir.
- Tek bir grace bileşeni → tekrar yok, iki yolda tutarlı davranış.

---

## 7. Test Planı

Mevcut testler: `CheckInSchedulerTest.kt`, `EmergencyExecutorTest.kt`, `NativeNotificationTextTest.kt`. Yeni/genişletilecek testler:

| Test | Senaryo | Pass kriteri |
|------|---------|--------------|
| `expiry→grace` (Dart) | `fake_async` ile ana süre dolar | `isGracePeriod==true`, `remainingSeconds==60`, grace bildirimi tetiklendi |
| `grace→confirmSafe` | Grace'te tek dokunuş "Güvendeyim" | ACTIVE(main)'e döner, native alarm yeniden kurulur, **arama yapılmaz** |
| `grace→escalate (Dart)` | Grace dolar, Dart canlı | Tam 1 arama, **yalnız birincil kişiye**; `EmergencyCallScreen` açılır; `tryClaim` ikinci çağrıyı reddeder |
| `grace→escalate (native)` | `CheckInAlarmReceiver` grace-expiry, `KEY_CHECK_IN_ACTIVE=true` | `EmergencyExecutor.executeEmergency(primaryNumber)` çağrılır, `KEY_CHECK_IN_ALARM_FIRED=true` |
| **`112/failover ÇAĞRILMAZ`** | Check-in/safe-walk escalate | Yalnız birincil numara aranır; **112 ve diğer kişiler ASLA aranmaz** (regresyon koruması) |
| `native-fired dedup` | Native ateşledi, sonra Dart resume | `didCheckInAlarmFire==true` → Dart **arama yapmaz** |
| `iptal sonrası alarm reddi` | confirmSafe/stop sonrası eski alarm ateşlenir | `KEY_CHECK_IN_ACTIVE` false → receiver **arama yapmaz** |
| `izin-yok→dialer` | `CALL_PHONE` granted değil | `EmergencyExecutor` ACTION_DIAL döner (`dialerOpened`), **112'ye düşmez** |
| `izin-var→ACTION_CALL` | `CALL_PHONE` granted | `directCallStarted` döner (birincil numara) |
| **`full-screen izni yok→heads-up`** | `USE_FULL_SCREEN_INTENT` reddedilmiş | Bildirim düz yüksek-öncelikli olarak gönderilir, **çökme yok** (Karar 7b) |
| `Doze/exact-yok` | `canScheduleExactAlarms==false` | inexact alarm kurulur, `nativeScheduleDegraded==true`, kullanıcıya gösterilir |
| `boot-restore expired` | Cihaz reboot, deadline geçmiş | `restoreAfterBoot` → `EmergencyExecutor(primaryNumber)` + bildirim (yalnız bildirim DEĞİL) |
| `safe-walk grace eşitliği` | safe_walk session ana süre dolar | check-in ile aynı: 60sn grace → escalate; **aynı grace UI bileşeni**, ayrı CountdownScreen DEĞİL |

Hedef: yeni iş mantığı ≥%80 (CLAUDE.md testing). TDD: önce kırmızı test, sonra implementasyon.

---

## 8. Riskler + KISITLAR Uyum Teyidi

**Riskler**
- **Play Store CALL_PHONE arka plan otomatik arama:** Beyan gerekir. Hafifletici: desen zaten mevcut (countdown); M2 **daha dar** (tek kişi, 112 yok), risk sınıfı artmaz. Full-screen-intent beyanı ayrıca Console işidir (§3.6a).
- **Yanlış-pozitif arama:** Uygulama ölüyken bile arama → §3.3 (yüksek-öncelikli grace bildirimi + 60sn + dedup + iptal-reddi) ile dengelenir. Tek-dokunuş iptal + native arama birleşimi bu dengeyi özellikle gerektirir.
- **Çift-arama:** Dart + native iki yürütücü → tam dedup (native-fired bayrağı + `tryClaim`) zorunlu; testle kanıtlanır.
- **Safe-walk refactor regresyonu:** kendi timer'ından paylaşılan kontrolöre + ortak grace bileşenine geçiş → mevcut safe-walk testleri + yeni eşitlik testi ile korunur.

**KISITLAR uyum teyidi**
- ✅ **Offline-first:** arama yolu backend gerektirmez; yalnız platform/telefon servisleri.
- ✅ **Sadece-PIN:** biyometrik eklenmez; grace iptali tek-dokunuş "Güvendeyim" (auth değil, "yaşam belirtisi").
- ✅ **UI/tema/görsel DEĞİŞMEZ:** yeni ekran yok; safe-walk mevcut bileşenlerle ortak grace UI'ına bağlanır. **String'ler bu turda değişmez** (Karar 8).
- ✅ **Acil akış korunur:** Countdown/panik yolunun tüm-numara + 112 davranışı **hiç dokunulmaz**. Check-in/safe-walk expiry yalnız birincil-kişi native-yedek ile **güçlendirilir** (countdown'dan kasıtlı dar — §0.1).
- ✅ Eski `flutter_direct_caller_plugin` kaldırıldı; production safety dispatch'i native
  typed coordinator, AlarmManager ve Android Telecom üzerinden yürür.

---

## 9. Açık Sorular

**Yok.** Önceki SPEC'teki tüm açık sorular nihai kararlarla kapatıldı:

| Eski açık soru | Çözüm |
|----------------|-------|
| Safe-walk grace UI'ı | **Karar 6:** check-in ile aynı paylaşılan grace bileşeni; ayrı CountdownScreen yok; yeni görsel yok (§6). |
| String güncellemesi onayı | **Karar 8:** bu turda string değişmez; metin güncellemesi kod gerçek-cihazda kanıtlandıktan sonra ayrı adımda. |
| Çoklu-numara failover native tarafta mı? | **Karar 2:** failover YOK; tek hedef birincil kişi. Soru konusuz. |
| Grace bildirimi full-screen-intent mi? | **Karar 7:** evet, ama (a) Console beyanı geliştirici işi, (b) kod izin reddini zarifçe heads-up'a düşürür (§3.6). |
| App-kill kalıcılığı | Native AlarmManager ayakta kalır (kanıtlandı); manüfaktör-kill senaryoları gerçek-cihaz turunda doğrulanır (uygulama testinin parçası). |
# Tarihsel not — production sözleşmesi değildir

Bu dosya eski M2 tasarım çalışmasını korur ve aşağıdaki bazı akış/satır referansları artık
bilerek geçersizdir. Güncel production sözleşmesi
[`docs/release/safety_case.md`](docs/release/safety_case.md), typed
`EmergencySessionCoordinator` ve `release-evidence` kapılarıdır. Bu dosyadan release iddiası
veya uygulama davranışı türetilmez.
