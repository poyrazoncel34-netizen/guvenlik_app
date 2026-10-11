# OD-2 — Android 14+ temiz kurulumda kesin alarm hazirligi (2026-10-11)

Owner karari (ONAYLI): kesin alarm izni yokken kullaniciya Panik tamamen hazirmis gibi
gosterilmeyecek. Onboarding'de gorunur bir **Arka Plan Koruması** hazirlik adimi olacak,
ama uygulama onboarding acilirken kullaniciyi otomatik Settings'e firlatmayacak. Kullanici
CTA'ya dokununca kesin-alarm ozel erisim ekrani acilacak. Atlanabilir; atlanirsa hazirlik
**incomplete/limited** kalir. `USE_EXACT_ALARM` EKLENMEDI; `SCHEDULE_EXACT_ALARM`
yaklasimi korundu.

## Onceden zaten dogru olan (olculdu, varsayilmadi)

| | |
|---|---|
| Manifest | yalniz `SCHEDULE_EXACT_ALARM`; `USE_EXACT_ALARM` yok (test ile sabitlendi) |
| Sistem niyeti | `ExactAlarmSettingsIntent` once `canScheduleExactAlarms()` sorar, `package:` URI ile uygulamanin KENDI sayfasini acar, reddedilirse app-details'e duser |
| Readiness | `PlatformReadinessSnapshot.backgroundAlertReady` zaten `exactAlarmPermission` istiyordu |
| Resume | `EmergencyTriggerHost` MaterialApp'in ustunde, her `resumed`'da readiness'i yeniden olcuyor |
| Panik | kesin alarm yoksa korumali panik zaten reddediliyor (Y-11): "Arka plan korumasini ac" + "Simdi Ara" |

**Eksik olan tek sey:** onboarding'de bu bosluktan hic soz edilmiyordu. Kullanici bunu ilk
kez panik butonuna basarken ogreniyordu — bir kurulum boslugunu kesfetmek icin mumkun olan
en kotu an.

## Degisiklik

- `lib/screens/onboarding/onboarding_background_protection_step.dart` — gorunur adim:
  baslik, nedenini anlatan govde, canli durum satiri, CTA ve "atlarsan ne olur" notu.
  `didChangeAppLifecycleState(resumed)` ile izni YENIDEN OKUR; Activity sonucuna
  guvenmez (o ekran toggle hakkinda bir sey dondurmez ve kullanici izni bildirim
  panelinden de degistirmis olabilir).
- `lib/core/services/safety_readiness_level.dart` — `fullyReady / limited / unavailable`.
  Tek kaynak: artik hem kart basligi hem adim ayni hukmu okuyor. Oncesinde kart kendi
  basligini kirmizi cip sayisindan, gonderim yolu ise `criticalSafetyReady`'den
  turetiyordu; biri digerini haberdar etmeden genisleyebilirdi.
- `readiness_card.dart` — baslik bu hukumden turuyor ve `unavailable` icin ayri metin:
  prob cevap veremediginde "Kuruluma 2 adim kaldi" demek kullaniciyi olmayan adimlar icin
  Ayarlar'da dolastirir.
- `onboarding_screen.dart` — adim acil-kisi kapisinin HEMEN ONUNE eklendi (kapi son sayfa
  olarak kaldi, tamamlamanin tek cikisi odur). 'Atla' artik bu adima iniyor: eskiden
  dogrudan kapiya atliyordu, yani adim kazara hic gorulmeyebilirdi. Bilerek atlamak hala
  mumkun; ileri butonu bu adimda hic devre disi kalmiyor.
- Ikon `IconSizes.hero` (48): kardes onboarding sayfalarinin 52'si belgeli bir istisna ama
  `design_token_ratchet_test` istisna SAYISINI sabitliyor ve kurali "yeni kod olcege iner".

## Cihaz kaniti

Ortam: `-no-audio`, ses akislari 0, 420 dpi, 1080x2400, userdebug, root.
Arama yapilmadi; hicbir ucuncu kisi aranmadi.

| Adim | API 36 | API 35 | API 29 |
|---|---|---|---|
| 1-3. temiz kurulumda kesin alarm Android varsayilaninda | PASS `No operations` | PASS `No operations` | PASS (OS'te boyle bir erisim yok) |
| 4. 'Atla' gorunur "Arka Plan Koruması" adimina iniyor ve KAPALI diyor | PASS | PASS | PASS — API 29'da "acik" diyor, CTA yok (**regresyon yok**) |
| 5-6. CTA uygulamaya ozgu alarm ekranini aciyor | PASS → `com.android.settings/...SpaActivity`, ekranda `KoruBeni / 1.0.0 / Allow setting alar...` | PASS (ayni) | n/a |
| 7. izin vermeden donunce kapali kaliyor | PASS | PASS | n/a |
| 8a. adim onboarding'i TAMAMLAMAYI engellemiyor | PASS | PASS | PASS |
| 8b. izin kapaliyken ana sayfa hazir demiyor | PASS (uyari notu gorunur) | PASS | n/a |
| 9-11. izin verildi | PASS | PASS | n/a |
| 12-13. donuste FULLY READY | PASS `Kurulum tamam`, uyari notu kayboldu | PASS | n/a |
| 14-16. gercek Check-In silahlaniyor, kesin alarmlar VAR | PASS `armed`, 4 oturum alarmi, 2'si `window=0` | PASS (ayni) | PASS (ayni) |
| 17-19. izin geri alinca kesin alarmlar siliniyor | PASS 2 → 0 (inexact yedekler kaliyor 4 → 2); Android'in kendi kaydi `exact_alarm_permission_revoked` | PASS (ayni) | n/a |
| 20-21. yeniden acilista bayat READY yok | PASS `Kurulumun buyuk bolumu tamam` | PASS | n/a |
| 22. canli oturum degrade uyarisi gosteriyor | PASS "Arka plan koruması kapalı veya doğrulan…" | PASS | n/a |

Ham cikti: `od2-api36.md`, `od2-api35.md`, `od2-api29.md`. Arac: `tools/od2_probe.py`.

### RC `5aa3fe9`'da yeniden kosuldu

Inceleme duzeltmesi adimin durum METNINI degistirdi ("Arka plan koruması
açık/kapalı" → "Alarm ve hatırlatıcı erişimi açık/kapalı"), bu yuzden onceki
kosusmlarin hicbiri tasinmadi; hepsi RC derlemesiyle yeniden alindi. Her kosum
once APK'nin degisikligi tasidigini dogruladi (`e3046dbc…`).

**API 35'te ilk kosum 6/12 dondu ve sebebi PROBAYDI.** Ayarlar ekranindan
donunce uygulama YENIDEN BASLIYOR ve bu imajda (GMS yok, daha yavas) geri
gelmesi uzun suruyor — onboarding 1. sayfadan aciliyor. Proba sabit 4 sn
bekliyordu, sonra henuz cizilmemis bir butona 25 kez dokunmaya calisti ve
ardi ardina 6 FAIL uretti. Cihazi hemen sonra inceledigimde buton ORADAYDI ve
tiklanabilirdi. Sabit bekleme `wait_for_app_ui()` ile degistirildi (uygulama
gercekten onplanda ve tiklanabilir bir sey cizmis olana kadar bekler) ve
karusel 6 sayfanin tamamini yuruyebilecek sabra kavustu. Yeniden kosum:
**12/12**.

Izin verme adimi `appops set ... SCHEDULE_EXACT_ALARM allow` ile yazildi — sistem
toggle'inin yazdigi AYNI app-op biti. Toggle'in yerlesimi OEM/API'ye gore degistigi icin
bu ikame bilerek yapildi ve gizlenmedi.

## Kaniti olmayan iddia birakilmadi — bir yanlis teshis duzeltildi

`uiautomator dump` API 36'da adimin govde paragrafini ve "atlayabilirsin" notunu
GOSTERMIYOR, oysa ikisi de ekranda goruluyor (ekran goruntusu) ve Flutter'in semantik
agacinda VAR. Once bunu gercek bir TalkBack kusuru sandim ve `Semantics(container:)`
sarmalayicisi ekledim; sonra bare `Text` ile semantik agaci dokup karsilastirdim — ikisi
de ayni dugumleri uretiyor. Sarmalayici gereksizdi ve yorumunda var olmayan bir kusuru
anlatiyordu, bu yuzden geri alindi. Erisilebilirlik artik `find.bySemanticsLabel` ile
semantik agaca karsi sabitleniyor ("TalkBack reads the whole step, explanation included"),
cihaz probasi ise bu iki metni bilerek olcmuyor ve nedenini yaziyor.

## Dogrulama

| Kapi | Sonuc |
|---|---|
| `flutter analyze --no-fatal-infos` | 0 sorun |
| `flutter test --no-pub` | **2599/2599** (OD-2 ile 19 yeni test) |
| Karsi-olgusal mutantlar | **11/11 OLDURULDU**, agac hash ile geri yuklendi (`mutants/od2-mutants-final.txt`) |
| Cihaz probasi | API 36 **12/12**, API 35 **12/12**, API 29 **6/6** |
| Politika testleri | `design_token_ratchet`, `icon_size_migration`, `translations_key_parity` yesil |

Degisen sozlesme testleri (zayiflatilmadi, guncellendi): `onboarding_contact_gate_source_test`
(Skip hedefi degisti — kapinin hala tek cikis oldugu ayrica sabitlendi),
`home_readiness_exact_alarm_test` (hukum tek kaynaga tasindi — "fullyReady tam olarak
criticalSafetyReady demektir" ayrica sabitlendi), `onboarding_behavior_test` (akista bir
sayfa daha var; ara durak artik ASSERT ediliyor, sessizce gecilmiyor).

## Kalan risk

- Sistem toggle'ina gercek bir dokunusla izin verme (appops yerine) ve OEM Settings
  varyantlari → **PHYSICAL DEVICE REQUIRED**.
- Kullanici izni atlarsa koruma gercekten sinirlidir; bu bilincli bir urun karari ve
  hem adimda hem ana sayfada yaziyor.
