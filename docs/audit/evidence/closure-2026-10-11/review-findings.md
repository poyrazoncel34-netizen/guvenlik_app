# Inceleme bulgulari ve ne yapildi (2026-10-11)

Depo kurali geregi (`.claude/rules/common/development-workflow.md` adim 3)
OD-1 icin **security-reviewer**, OD-2/LR-1 Dart'i icin **flutter-reviewer**
kosuldu. Her bulgu kaynakta DOGRULANDI; kabul edilenler karsi-olgusal mutantla
baglandi, reddedilenin gerekcesi yazildi.

## security-reviewer (OD-1, commit e4c8668)

CRITICAL 0 · HIGH 1 · MEDIUM 1 · LOW 5.

### F1 — HIGH — KABUL EDILDI, duzeltildi. Bu commit'in GETIRDIGI kusur.

`arm()` duvar saatini ~46. satirda, monotonik saati ~126. satirda okuyordu;
arada `capabilityProvider.snapshot()` (birkac binder cagrisi) ve `store.read()`
var. Yani saklanan elapsed vade, duvar vadesinden bu **bosluk kadar SONRAYA**
dusuyordu.

Gate duvar saatindeyken zararsizdi. OD-1 gate'i monotonige cevirdi ve Dart
gonderimini DUVAR vadesine cipaliyor (`safety_clock.dart`, K-03: "native bir
mikrosaniye erken reddetmemeli"). Sonuc: tam zamaninda gelen Dart gonderimi o
bosluk boyunca NOT_DUE okuyor → Dart istegi basarisiz sayip arayiciyi aciyor →
bosluk kadar sonra kesin alarm otomatik aramayi yapiyor. Ekranda arayici VE
otomatik arama: Y-04'un ta kendisi.

Duzeltme: iki saat yan yana, **once monotonik** okunuyor. Kalan sapma da artik
guvenli yone dusuyor (native vade duvardan bir tik ERKEN).

**Testin kendisi de yanlisti ve mutantla yakalandi.** Ilk yazdigim regresyon
"her okumada saat ilerler" modeliydi; arm() duzeltmeden once de sonra da TEK
elapsed okumasi yaptigi icin sahte saat iki durumda da ayni zarfi uretiyordu —
mutant SURVIVED. Gercek bosluk okumalar ARASINDAKI ISTEN doguyor, bu yuzden
sahte `capabilityProvider` artik monotonik saati ilerletiyor. Mutant KILLED.

### F2 — MEDIUM — REDDEDILDI (owner karari), riski yazildi.

"5 dk kapagi artik alarm yoluna da uygulaniyor" — bu OD-1'in kendisi: owner
karari butun yollarin AYNI olmasini ve `claimAndDispatch`'in de kapsanmasini
acikca istiyor. Degistirmedim. Inceleyenin maliyet analizi kalan risk olarak
kayitli: ayni boot icinde monotonik "gec", cihaz acikken OS/OEM'in kesin alarmi
ertelemesi demektir; kapak orada az koruma saglar. Ayrica bildirim
gonderilemezse oturum REQUEST_FAILED olur ve 6 dk gecikmis bir panik ne arama ne
gorunur iz birakir. Gercek Doze alarm gecikmesi zaten **PHYSICAL DEVICE
REQUIRED**.

### F3 — MEDIUM — KABUL EDILDI, duzeltildi.

`rebasedWallFromElapsed` `finalDeadlineMs`'i — yeniden baslatmadan sag cikan tek
referansi — eziyordu, ama zayif kontrolun (`!isFromAnotherBoot`) arkasindaydi.
Yikici yazim artik `isProvenSameBoot` istiyor. Ikisi yalniz hicbir boot kimligi
okunamadiginda ayrilir; orada "bilinmiyor"u "ayni boot" saymak vadeyi onceki
boot'un uptime'i kadar oteleyebilirdi. Yeniden kurma devam ediyor, yalniz ezme
geri cekildi. Yeni test + mutant (OD1-M14) bagladi.

### F5 — LOW — KABUL EDILDI (yorum yanlisti).

CLAIMED muafiyetinin gerekcesi olarak yazdigim "bounded retry vadeleri yeniden
yazar" iddiasi YANLIS: `retryEnvelope` yalnizca `scheduleBestEffort`'a veriliyor,
hic kalici yazilmiyor. Yorum gercek gerekceyle degistirildi.

### F6 — LOW — KABUL EDILDI (yorum yanlisti).

`ClockAuthority` "for logging" diyordu, hicbir yer loglamiyordu. Iddia kaldirildi.

### F4 — LOW — kabul, kayitli, degistirilmedi.

OFFER_MANUAL in-process "already submitted" korumasindan once calisiyor; terminal
yazim basarisizligi sonrasi 5 dk+ gecikmeli bir kayit icin "dokun ve ara"
gosterilebilir ve `callRequestOutcome = NOT_ATTEMPTED` yazilir. Yazim
basarisizligi gerektirdigi icin nadir, ve dokunus kullanici eylemi oldugundan
otomatik cift arama yok. Kalan risk olarak kaydedildi.

### Temiz cikanlar (inceleyenin dogruladiklari)

Tasma/isaret, `isProvenSameBoot` mantigi, `rebasedWallFromElapsed` yaziminin
atomikligi, PROCESS_LOCK reentrancy ve CANCELLED/terminal dirilmesi — hepsi temiz.

## flutter-reviewer (OD-2 + LR-1 Dart'i)

CRITICAL 0 · HIGH 0 · MEDIUM 3 · LOW 4. Ucu de kaynakta dogrulandi ve duzeltildi.

### MEDIUM 1 — adimin durum satiri fazla iddia ediyordu.

`granted` = `exactAlarmPermission`, ana karttaki cip ise `backgroundAlertReady`
(ayrica bildirim izni + yuksek onemli kanal) — ve bu akista bildirim izni bu
adimdan SONRA isteniyor. Yani adim "arka plan koruması açık" diyebilirken cip
kirmizi kalabiliyordu.

Sinyali genisletmek **yanlis** duzeltme olurdu: adimin CTA'si kesin-alarm
ekranini aciyor ve bildirimi veremez, yani duzeltemeyecegi bir sey icin kirmizi
gosterirdi. Dogru duzeltme metni daraltmak: durum satiri artik sahip oldugu tek
erisimi adlandiriyor ("Alarm ve hatırlatıcı erişimi açık/kapalı"). Genel hukum
kartta kaliyor. Yeni test (bildirim reddiyken) + mutant OD2-M12 bagladi.

### MEDIUM 2 — adim readiness servisini dinlemiyordu.

Yalnizca kendi probunu bekliyordu. `EmergencyReadinessService` ustune binen
probu gecersiz kilar ve gecersiz kilinan icin **notify etmez**, dolayisiyla adim
bayat durum cizip yeni sonucu hic duymayabilirdi. Bugun calismasi yalnizca
dinleyici kayit sirasina bagliydi. Artik `addListener`/`removeListener` var
(HomePage da oyle yapiyor). Mutant OD2-M13 bagladi.

### MEDIUM 3 — yeni "okunamadı" basligi iki hata yapiyordu.

(a) `null` (henuz olculmedi) de `unavailable`'a dustugu icin kart acilista
kisaca "Hazırlık durumu okunamadı" gosterebiliyordu; (b) bu dal, acil kisi
eksikken gosterilmesi gereken "once acil kisini ekle" yonlendirmesini
geciyordu (denetim bulgusu A-04). Artik yalnizca prob GERCEKTEN kosup
basarisiz olduysa ve acil kisi VARSA gosteriliyor. Mutant OD2-M14/M15 bagladi.

### LOW'lar

`-1` korumasi tek yerde hesaplanip tersine donemeyecek bicime getirildi
(`_pages` getter'i her okumada 12 `.tr()` cagiriyordu, build basina 4 kez
okunuyordu); `unawaited` eklendi. **Kontrast LOW'u reddedildi**: Ileri butonu
her onboarding sayfasinda sayfa rengini aliyor; tek sayfada degistirmek gorsel
tasarim degisikligi olur (CLAUDE.md kural 4) ve desen zaten tutarli.
