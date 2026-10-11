# KoruBeni — OD-1 + OD-2 + LR-1 kapanisi (2026-10-11)

Baslangic HEAD `1b76466` (onceki RC). **RELEASE_CANDIDATE_HEAD = `5aa3fe9`**,
dal `codex/evidence-remediation-20260911`, **push edilmedi**.

Bu bir yeni genel denetim DEGILDI. Kapsam uc acik maddeydi. Kapsam icinde
dogrulama yapilirken bulunan gercek kusurlar duzeltildi; disina cikilmadi.

Kural: kanitlanamayan hicbir seye PASS yazilmadi. Fiziksel cihaz →
**PHYSICAL DEVICE REQUIRED**, magaza/abonelik → **EXTERNAL SYSTEM REQUIRED**,
hukuki hukum → **LEGAL REVIEW REQUIRED**.

Ham kanit: [`evidence/closure-2026-10-11/`](evidence/closure-2026-10-11/)

## Commit'ler

| Commit | Ne |
|---|---|
| `e4c8668` | OD-1 — vade politikasi tek karar fonksiyonunda, monotonik saat yetkisi, **OD-1c** |
| `ed2885a` | OD-2 — gorunur "Arka Plan Koruması" adimi, tek readiness hukmu |
| `13972b0` | LR-1 — konum metinleri kaynakla eslesti, yasal surum bump'i |
| `5aa3fe9` | Inceleme bulgulari — **arm() saat sapmasi (HIGH)**, kanitsiz duvar ezmesi, adim durum metni |

## Bulunan kusurlar

| ID | Onem | Nereden | Durum |
|---|---|---|---|
| OD-1 | HIGH | owner maddesi | FIXED — ayni kayit, reconcile'da `manualActionRequired`, alarm alicisinda GERCEK Telecom cagrisi (API 36'da olculdu) |
| OD-1c | **CRITICAL** | OD-1'in cihaz dogrulamasi | FIXED — `reconcileAfterBoot` ayni-boot monotonik vadeyi kosulsuz eziyordu; force-stop + saat degisikligi canli 2 saatlik oturumu "simdi vadesi geldi"ye cevirip acil kisiyi **iki saat once** ariyordu. Android 15+ force-stop sonrasi BOOT_COMPLETED'i yeniden teslim ettigi icin gercekci |
| OD-1b (arm skew) | **HIGH** | security-reviewer — **bu calismanin OD-1 commit'inin GETIRDIGI kusur** | FIXED — `arm()` iki saatini ~80 satir arayla, binder isinin iki yaninda okuyordu; OD-1 gate'i monotonige cevirince tam zamaninda gelen Dart gonderimi reddediliyor, ekranda arayici VE otomatik arama olusuyordu |
| OD-2 | MEDIUM | owner maddesi | FIXED — gorunur, atlanabilir hazirlik adimi |
| LR-1 | MEDIUM | owner maddesi | TECHNICAL FACTS CLOSED / LEGAL REVIEW REQUIRED |

## Hukumler (RC `5aa3fe9`)

| Alan | Hukum | Gerekce |
|---|---|---|
| **OD-1** | **CLOSED** | Bes karar noktasinin tamami tek `OverdueDispatchPolicy`'den geciyor; ayni boot icinde yas monotonik saatle olculuyor. Cihaz: API 36 **10/10**, API 35 **10/10**; gercek 2 saatlik Check-In uzerinde duvar saati saldirisi **9/9** (elapsed vade alti saldiri boyunca hic oynamadi). Sinir matrisi 8 yas x 5 yol + ozellik testleri. Mutantlar 16/16. |
| **OD-2** | **CLOSED** | Temiz kurulumda kesin alarm Android varsayilaninda kapali; gorunur adim bunu soyluyor, CTA uygulamanin KENDI "Allow setting alarms" ekranini aciyor, atlanabiliyor ama hazirlik eksik kaliyor. Cihaz: API 36 **12/12**, API 35 **12/12**, API 29 (regresyon yok). `USE_EXACT_ALARM` eklenmedi. |
| **LR-1 TECHNICAL FACTS** | **CLOSED** | Kaynakta olmayan konum iddiasi kullaniciya gorunen veya kamuya acik hicbir yuzeyde kalmadi. Kaynak + calisma zamani: konum izni GERI ALINMISKEN Check-In ve Guvenli Yuruyus silahlaniyor, Panik ucan uca calisip Telecom istegini gonderiyor; Harita acilmadan OSM istegi 0; ham koordinat ne pcap'te ne depolamada. |
| **LR-1 LEGAL** | **LEGAL REVIEW REQUIRED** | Yeni metnin KVKK Md. 10 yeterliligi, konum icin "acik riza"nin dogru hukuki sebep olup olmadigi, surum bump'inin istege bagli onaylari sifirlamasinin kabul edilebilirligi, OSMF aktariminin Md. 9 degerlendirmesi. Claude hicbirini onaylamadi. |
| **CODE** | **PASS** | analyze 0 sorun; `flutter test` 2613; Kotlin unit 216; dort mutant setinde **0 survivor**; iki bagimsiz inceleme (security + flutter), butun MEDIUM/HIGH bulgular ya duzeltildi ya gerekceyle reddedildi. |
| **RUNTIME-HUMAN** | **PASS (emulator siniri icinde)** | Her duzeltmenin kullanici yolu gercek uygulamada yuruldu: API 36/35/29. Emulatorde kanitlanamayanlar asagida. |
| **DEVICE** | **UNKNOWN — PHYSICAL DEVICE REQUIRED** | Doze altinda gercek alarm gecikmesi, OEM pil yoneticileri, gercek SIM ile baglanti, gercek uyku, cift SIM. |
| **COMMERCE** | **UNKNOWN — EXTERNAL SYSTEM REQUIRED** | Satin alma, yenileme, iptal, iade, gercek cevrimdisi yetki. Pro yalniz TEST amacli cevrimdisi capa (root ile). |
| **PRIVACY/POLICY** | **LEGAL REVIEW REQUIRED** | Teknik olgular kapandi ve olculdu; hukuki hukum hukukcuda. Data Safety'ye yeni bilgi tasindi (asagida). |
| **RELEASE** | **PASS (yerel aday) / UNKNOWN (uretim)** | `verify_release.sh` **LOCAL_CANDIDATE_PASS** 6/6; 16 KB 8/8; lisans/notices yesil. AAB `.smoke` kimligiyle derlendi ve **Play'e yuklenemez**. `EXTERNAL_RELEASE_GATES_UNVERIFIED`. |
| **PRODUCT** | **GO (kod/emulator siniri icinde) — su sartla** | Uc madde kapandi. Yayin karari fiziksel cihaz, ticaret ve hukuk kapilarina bagli; bunlar bu oturumda KAPATILAMAZ. |

## Yayindan once bilinmesi gerekenler

1. **Yasal surum bump'i mevcut tum kullanicilari yeniden onaya gonderir** ve
   `UnifiedConsentScreen` onceki istege bagli onaylari geri yuklemedigi icin
   konum, acil kisi, profil ve sahte cagri onaylari isaretlenmezse **geri
   alinir**. Bu, LR-1 duzeltmesinin kacinilmaz yan etkisi; CHANGELOG'da duz
   dille yaziyor. Istenmiyorsa alternatif, metni surum bump'i OLMADAN
   duzeltmektir — ki bu `security.md` sozlesmesine aykiridir ve eski
   kullanicilari artik var olmayan bir metne verilmis onayla birakir. Karar
   sahibinin.
2. **Data Safety**: ham GPS gonderilmiyor, ama karo `z/x/y` goruntulenen alani
   belirliyor; olculen zoom 15/16'da 41°N'de bir karo **0.85** ve **0.21 km²** —
   ikisi de Play'in **HASSAS (<3 km²)** bandinda. "GPS gondermiyoruz" tek basina
   eksik beyan olurdu.
3. **F2 (owner karari olarak reddedildi)**: 5 dk kapagi artik en sik calisan
   yola (alarm teslimi) da uygulaniyor — OD-1'in kendisi bunu istiyor.
   Inceleyenin maliyet analizi kalan risk olarak kayitli: ayni boot icinde
   monotonik "gec", cihaz acikken OS/OEM'in alarmi ertelemesi demektir; ayrica
   bildirim gonderilemezse 6 dk gecikmis panik ne arama ne gorunur iz birakir.

## Kalan riskler (bilinen, duzeltilmedi)

| Risk | Onem | Durum |
|---|---|---|
| Boot-arasi yas yalniz duvar saatiyle olculebilir; telefon kapaliyken saat ileri alindiysa oturum MANUAL_ACTION_REQUIRED olur | LOW | owner kuralinin guvenli yonu; mevcut yeniden baslatma tasarimi korundu |
| F4: OFFER_MANUAL in-process "already submitted" korumasindan once calisiyor | LOW | terminal yazim hatasi gerektirir; dokunus kullanici eylemi, otomatik cift arama yok |
| Bildirim gonderilemezse asiri gecikmis oturum REQUEST_FAILED olur, gorunur iz kalmaz | LOW–MEDIUM | F2 ile ayni koke bagli; owner kararina tabi |
| 19 olu ceviri anahtari hala "konum oturumu" diyor | INFO | hicbiri referans edilmiyor; `y09` testi biri gorunur olursa kiriliyor |
| `openDialer` Android kanalinda `MissingPluginException` yakalamiyor | LOW | onceden var olan desen |
| Ileri butonu kontrasti (~1.8:1) yeni adimda da dusuk | LOW | her onboarding sayfasinda ayni; tek sayfada degistirmek gorsel tasarim degisikligi (CLAUDE.md kural 4) |

## Olculum araclarina dair durust not

Bu kapanista **uc olcum araci** kirik cikti ve ucu de gercek kusur gibi gorunen
kirmizilar uretti. Hepsi onarildi ve yeniden olculdu; hicbiri "proba
kararsizligi" diye gecistirilmedi:

1. `appops` bu sistem imajinda erisim ZAMAN DAMGASI vermiyor — "akislar konum
   okudu mu" sorusunu karsilastirdigim string'ler yapisi geregi aynidi. Yerine
   davranissal deney kondu: izni GERI ALIP akislari kosmak.
2. Bir kosum LR-1 degisikliklerinden ONCE derlenmis APK'ya karsi yapildi ve iki
   anlamsiz FAIL uretti (CERT2-05). `lr1_copy_runtime.py` artik degisikligi
   tasimayan derlemede kosmayi **reddediyor**.
3. OD-2 probasi Ayarlar donusunde sabit 4 sn bekliyordu; uygulama o imajda
   yeniden baslayip onboarding 1. sayfadan aciliyor. 25 dokunus bosa gitti ve
   6 FAIL kaskadi olustu. `wait_for_app_ui()` ile degistirildi; API 35 **12/12**.

Ayrica **ilk yazdigim F1 regresyon testi kusuru yakalamiyordu** ve bunu
karsi-olgusal mutasyon adimi ortaya cikardi (mutant SURVIVED). Model yanlisti:
gercek bosluk okumalar ARASINDAKI isten doguyor. Duzeltildi, mutant KILLED.
Bu adim olmasaydi hicbir sey kanitlamayan yesil bir test yayinlanacakti.

## Son soru

**Gercek bir insan … bugun bildigimiz KOD KAYNAKLI bir problem kaldi mi?**

Kapanan uc maddenin kapsaminda: **HAYIR** — kanitlanmis kod/emulator sinirinin
icinde. Bu sinirin disinda kalanlar yukarida PHYSICAL DEVICE REQUIRED,
EXTERNAL SYSTEM REQUIRED ve LEGAL REVIEW REQUIRED olarak isaretli; bunlar
"yok" degil, "bu oturumda kanitlanamaz".

Kalan riskler tablosundaki LOW maddeler bilinen, kayitli ve karara baglidir.
