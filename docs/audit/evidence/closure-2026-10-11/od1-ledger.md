# OD-1 — 5 dakikalik vade politikasi, butun native yollarda ayni (2026-10-11)

Owner karari (ONAYLI): son tarih gectikten sonra 0–5 dk gecikmede otomatik gonderim
yapilabilir; 5 dakikayi ASAN oturum artik otomatik aramaz, `MANUAL_ACTION_REQUIRED`
olur ve kullanici birincil kisiyi elle arayabilir. Ayni boot icindeki zaman karari
duvar saatine degil uyku sayan monotonik (BOOTTIME/elapsedRealtime) saate dayanir.

## Ortam

| | |
|---|---|
| API 36 | AVD `KoruBeni_API36`, emulator-5558, userdebug, root, 420 dpi, 1080x2400, `-no-audio`, ses akislari 0 |
| API 35 | AVD `KoruBeni_A017_API35`, emulator-5554, userdebug, root, 420 dpi, `-no-audio` |
| Arama | yalnizca emulator-kontrollu numara `05551234567` (emulator modemi). Gercek ucuncu kisi ARANMADI. |
| Telecom sayimi | `dumpsys telecom` icindeki `TC@n` tekil sayisi. Mutlak sayi emulator modemi yuzunden kosular arasinda kayar; **delta** anlamlidir. |

## Yeniden uretim (duzeltmeden ONCE)

Kaynak: HEAD `1b764664a2b1fceb45624d903b5ef0c1973ce666` (RC). Yalnizca proba testi eklendi,
uygulama kodu degistirilmedi. APK `5de7b4f67f2e02b8`, test APK `560646032c41bfa1`.

JVM (`od1-repro-red-jvm.txt`): 5 testin 3'u KIRMIZI, iki negatif kontrol YESIL.

Cihaz, API 36 (`od1-device-prefix-api36.txt`) — gercek Direct Boot deposu, gercek
`CountdownAlarmReceiver`, gercek TelecomManager:

| Mod | ONCE | SONRA |
|---|---|---|
| `parity` (1 sa gecikmis, iki yol ayni kayit) | reconcile `manualActionRequired/notAttempted` **vs** alarm `requestSubmittedUnconfirmed/submittedUnconfirmed` — **AYRISIYOR** | ikisi de `manualActionRequired/notAttempted` |
| `alarm` (1 sa gecikmis alarm teslimi) | `submittedUnconfirmed`, Telecom **+1** | `notAttempted`, Telecom **+0**, geri donus bildirimi `posted` |
| `alarm-control` (30 sn gecikmis) | gonderildi, Telecom +1 | ayni (degismedi) |
| `overdue` (reconcile, 1 sa) | `manualActionRequired` | ayni |
| `control` (reconcile, 30 sn) | gonderildi | ayni |
| `claimed` (1 sa, CLAIMED kayit) | `manualActionRequired` | ayni |
| `claimed-control` (30 sn, CLAIMED) | gonderildi | ayni |
| `wall-forward` (ayni boot, 60 sn kalmis, duvar +2 sa) | **`manualActionRequired`** — canli oturum sonlandirildi | **`armed`**, 0 arama, geri donus yok |
| `wall-forward-boot` (boot-arasi, duvar +2 sa) | `manualActionRequired` | ayni (dogru: boot-arasi yas kanitlanamaz) |
| `wall-back` (monotonik olarak vadesi gelmis, duvar -1 sa) | **`armed`, 0 arama** — kacirilan arama | **`submittedUnconfirmed`**, Telecom +1 |

Butun negatif kontroller once ve sonra AYNI davraniyor; degisiklik dar ve hedefli.

## Kok neden

`MAX_OVERDUE_DISPATCH_MS` (5 dk) vardi ama 5 karar noktasindan 3'unde uygulaniyordu ve
saat yetkisi tutarsizdi:

| Nokta | Kapi | Saat |
|---|---|---|
| `reconcileArmedFromWall` | vardi | DUVAR |
| `reconcile()` CLAIMED dali | vardi | DUVAR |
| `reconcileAfterClockChange` (geri alinmis duvar dali) | vardi | MONOTONIK |
| `reconcileAfterClockChange` (`remaining==0` + duvar vadesi gecmis) | **YOK** | — |
| `claimAndDispatch` (iki alarm alicisi + Dart kanali) | **YOK** | yalnizca "duvar < son tarih" reddi |

Alarmlar `ELAPSED_REALTIME_WAKEUP` ile kuruluyor, yani teslim monotonik saatle olusuyor;
yas karari ise duvar saatinden okunuyordu.

## Duzeltme

- Yeni `OverdueDispatchPolicy` (tek karar fonksiyonu + sinir anlambilimi tek yerde):
  `overdueMs < 0` → NOT_DUE; `0..300000` **dahil** → DISPATCH; `> 300000` → OFFER_MANUAL.
  Tam 5:00.000 hala arar, 5:00.001 aramaz — degistirilen `>` karsilastirmalariyla birebir
  ayni, yani kural tek yere tasinirken sinir bir milisaniye kaymadi.
- `EmergencySessionCoordinator.deadlineDecision()` yetkili saati secer: kaydin elapsed
  damgasi bu boot'a aitse MONOTONIK, degilse DUVAR (boot-arasi tek referans odur).
- Bes yolun hepsi ayni karardan geciyor. `claimAndDispatch` tek huni oldugu icin iki alarm
  alicisi ve Dart kanali otomatik kapsaniyor.
- `rebasedWallFromElapsed()`: monotonik yetkili oldugunda ve duvar vadesi 2 sn'den fazla
  sapmissa, saklanan duvar vadesi monotonik kalan sureden yeniden kuruluyor — Dart geri
  sayimi o duvar vadesini gosteriyor ve uygulama calısmazken olan saat degisikligi icin
  TIME_SET hic gelmemis olabilir.

## OD-1c — bu dogrulamada bulunan YENI kusur (CRITICAL)

`reconcileAfterBoot()` elapsed vadesini **kosulsuz** duvar saatinden yeniden kuruyordu
(`rebaseElapsedFromWall` "her zaman" demekti). Boot kimligi AYNI oldugunda bile.

API 36'da gercek 2 saatlik Check-In ile alan alan izlendi (`tools/od1_step_trace.sh`):

| Adim | state | elapsedStamp | elapsedDeadline | duvar |
|---|---|---|---|---|
| silahlandi | armed | 3744486 | 11004481 | +2 sa |
| force-stop | armed | 3744486 | 11004481 | +2 sa |
| duvar +1 gun | armed | 3744486 | 11004481 | gecmis |
| yeniden acildi | **requestSubmittedUnconfirmed** | 3765708 | **3765708** | gecmis |

`boot_id` (`5a89827a-...`) ve `settings get global boot_count` (47) hic degismedi, `/proc/uptime`
kesintisiz artti — yani AYNI boot ve monotonik vade gecerliydi (2 saat koruma kalmisti).
Yeniden kurulan vade `elapsedNow + max(0, duvarVade - duvarSimdi)` = "simdi vadesi geldi"
oldu, alarm aninda tetiklendi ve kisi **iki saat once** arandi.

Emulator tuhafligi degil: Android 15+ force-stop sonrasi BOOT_COMPLETED'i yeniden teslim
ediyor — bu depo bunu FS-01'i kapatirken kendisi olcmustu (API 36'da 4 → 0 → 4 alarm).
Force-stop + saat degisikligi, agresif gorev sonlandiricisi ve otomatik ag saati olan bir
telefonda olagan bir hafta.

Duzeltme: `isProvenSameBoot()` — bir boot yayini, kimligin BU boot'a ait oldugunu kanitladigi
bir elapsed vadesini ezmek icin gerekce degil; kanitlanmamis bir damgaya guvenmemek icin
gerekce. Gercek yeniden baslatmada kimlik farkli olur (ve elapsed sifirdan baslar), bu yuzden
yeniden kurma eskisi gibi calisir — `a real reboot still rebuilds the elapsed deadline from
the wall deadline` testi bunu tutuyor.

`deadlineDecision` bilerek `isFromAnotherBoot` kullanmaya devam ediyor: hangi saatten
OKUNACAGI yikici degil, ve hic boot kimligi okunamayan bir cihazda kanit sart kosmak her
karari duvar saatine geri verir, yani OD-1'i tumden bosa cikarirdi.

## Dogrulama

| Kapi | Sonuc | Kanit |
|---|---|---|
| JVM yeniden uretim (duzeltmeden once) | 3 KIRMIZI / 2 kontrol YESIL | `od1-repro-red-jvm.txt` |
| Kotlin birim (tum paket) | **216/216**, 0 hata | `gradlew :app:testPlayDebugUnitTest` |
| Sinir matrisi (8 yas x 5 yol) + boot kurtarma + izin yeniden verme + surec basi | PASS | `OverdueDispatchParityTest` |
| Ozellik testleri (rastgele olay sirasi, rastgele duvar ziplamasi, sinir monotonlugu) | PASS 43k vaka | `OverdueDispatchPolicyTest`, `OverdueDispatchParityTest` |
| Karsi-olgusal mutantlar | **14/14 OLDURULDU**, agac hash ile geri yuklendi | `mutants/od1-mutants-final.txt` |
| Ayni mutantlar, `SessionClockAuthority` cikariminden SONRA | **14/14 OLDURULDU** | `mutants/od1-mutants-postextract.txt` |
| Android lint (`lintPlayDebug`) | PASS | — |
| Cihaz probasi API 36, cikarimdan SONRA (10 mod) | **10/10 OK**, 0 FAILURES | `od1-device-postfix-api36.txt` |
| `flutter analyze --no-fatal-infos` | 0 sorun | — |
| `flutter test --no-pub` | **2580/2580** | — |
| Cihaz probasi API 36 (10 mod) | **10/10 OK**, 0 FAILURES | `od1-device-postfix-api36.txt` |
| Cihaz probasi API 35 (10 mod) | **10/10 OK** | `od1-device-postfix-api35.txt` |
| Duvar saati saldirisi, gercek 2 sa Check-In, API 36 | **9/9 PASS** — elapsed vade 6 saldiri boyunca hic oynamadi (12628895), native `armed`, Telecom 0, Dart geri sayimi native yetkiyle uyumlu | `od1-clock-attack-api36.md` |

## Dosya boyutu

`EmergencySessionCoordinator.kt` 837 → 979 satira cikti; bu deponun kurali "sinirin
uzerindeki dosya dokunuldugunda mantik verir, almaz" oldugu icin saat yetkisi mantigi
`SessionClockAuthority.kt`'ye (165 satir, saf, depo/alarm/Telecom yok) cikarildi ve
koordinator 879 satira indi. Orijinaline gore net +42 satir; bunun neredeyse tamami
CRITICAL bir guvenlik kararinin gerekcesini yazan yorum. Cikarimdan SONRA butun kapilar
(216 Kotlin testi, 14/14 mutant, API 36 cihaz probasi) yeniden kosuldu.

## Kalan risk

- Boot-arasi yas yalnizca duvar saatiyle olculebilir. Telefon kapaliyken saat ileri
  alinmissa oturum `MANUAL_ACTION_REQUIRED` olur (owner kuralinin guvenli yonu); geri
  alinmissa oturum uzar. Bu, mevcut yeniden baslatma kurtarma tasariminin siniri ve bu
  gorevde yeniden yazilmadi.
- Doze altinda gercek alarm gecikmesi, gercek SIM ile baglanti → **PHYSICAL DEVICE REQUIRED**.
- Ortam notu: uc emulator ayni anda calisirken ana makine yuku 11–20'ye cikti ve uygulama
  `CRITICAL_BOOTSTRAP_diTimeout` kurtarma ekranini gosterdi (tasarlanmis fail-closed
  davranis; yeniden acilista duzeldi). UI probalari bu yuzden tek emulatorle kosuldu.
