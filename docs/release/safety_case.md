# KoruBeni Android Safety Case — Release Candidate Template

**Karar durumu:** `NO_GO / INDEPENDENT_REVIEW_UNVERIFIED`  
**Destek zarfı:** Türkiye, Türkçe, telephony-capable phone, Android API 29–36,
arm64-v8a, Google Play kurulumu  
**Garanti dışı:** Android Settings → Force Stop, root/modifiye OS, SIM/şebeke,
operatör ve alıcı tarafı arızası

Bu belge G0'ın izlenebilirlik kaydıdır; uygulamanın bir kişiyi kesin kurtaracağı
iddiası değildir. Call connection gözlemlenemez. Ürün yalnız
`REQUEST_SUBMITTED_UNCONFIRMED`, `MANUAL_ACTION_REQUIRED` veya `REQUEST_FAILED`
gibi sonuçlar gösterebilir.

## Safety claim'leri

1. `Cancelled/AlreadyCancelled` acknowledgment alan generation daha sonra
   request/fallback üretemez.
2. Yalnız eşleşen `ARMED` token+generation native lock altında `CLAIMED`
   olabilir; stale alarm etkisizdir.
3. Armed session Flutter, RevenueCat ve geliştirici backend'i olmadan normal
   process kill, Doze ve reboot boyunca native olarak ilerler.
4. Check-In/Safe Walk; verified Pro lease, PIN, callable immutable contact,
   telephony/Telecom, CALL_PHONE, exact alarm ve yüksek önem notification
   capability olmadan `ARMED` olmaz.
5. Uygulama 112/911/KADES veya başka resmî hedef üretmez.
6. External telephony side effect ile durable store atomik değildir; normal
   akış generation başına at-most-one request üretir, request sonrası crash
   penceresinde duplicate residual riski missed emergency'ye tercih edilir.

## Hazard → kontrol → eval matrisi

| ID | Hazard / sonuç | Şiddet | Kontrol | Zorunlu eval | Candidate evidence | Durum |
| --- | --- | --- | --- | --- | --- | --- |
| H01 | UI iptal başarı gösterir fakat alarm canlıdır | S4 | Typed `CancelResult`; timeout=`Unknown`; durable tombstone; reconciliation | cancel timeout, store commit=false, cancel-vs-receiver 1.000 interleaving | G1/G2 unit+device log | `LOCAL_PASS`, device unverified |
| H02 | PIN loading/read failure PINsiz iptale dönüşür | S4 | `PinState loading/configured/absent/readFailed`; configured olmadan arm yok | secure-storage hang/error, widget lifecycle, wrong/correct race | G2 widget/integration | `LOCAL_PASS`, device unverified |
| H03 | Widget `dispose` session'ı iptal eder | S4 | Lifecycle callback'leri safety state değiştiremez | route pop/rebuild/pause/dispose mutant | G2 mutation ledger | `LOCAL_PASS`, device unverified |
| H04 | Eski reschedule alarmı yeni deadline'dan önce dispatch eder | S4 | Token+monotonic generation+deadline check | old-vs-new generation controlled interleavings | G1 native tests | `LOCAL_PASS` |
| H05 | Log/DB/haptic hatası çağrı yolunu sıfırlar | S4 | Native claim; fallback post ve Telecom request tüm noncritical side effect'lerden önce | her boundary exception/storage-full/navigator-null | G1/G3 fault matrix | `LOCAL_PASS`, device/storage-full unverified |
| H06 | Direct Boot restore yanlış hedefi arar | S4 | Minimal DE schema; corrupt/unknown→`CORRUPTED`, otomatik dispatch yok | locked boot, corrupt schema, update/reboot | G1/G3 physical log | `LOCAL_PASS`, real reboot unverified |
| H07 | Confirmed cancel sonrası fallback/request | S4 | Tombstone önce commit, PendingIntent cancel best-effort | 50 race/OEM, 1.000 modeled interleaving | G7 witnessed evidence | `UNVERIFIED` |
| H08 | CALL_PHONE/notification/exact permission arm sonrası geri alınır | S3 | Arm-time capability; dispatch typed failure + actionable fallback; resume reconciliation | revoke/regrant, locked/background/no handler | G3/G7 | `UNVERIFIED` |
| H09 | Background activity launch sessizce başarısızdır | S3 | Raw background ACTION_CALL/DIAL yok; `TelecomManager.placeCall`; dial yalnız visible Activity veya user-tapped PendingIntent | BAL test/API29–36 | G3/G7 | `CODE_PASS`, device unverified |
| H10 | RevenueCat outage free/Pro diye yanlış sınıflanır | S3 | Trusted Entitlements; `unknown` yeni arm'ı bloklar; armed lease immutable | failed/notRequested/offline/outage/refund | G2/G8 | `LOCAL_PARTIAL`, dashboard unverified |
| H11 | Kişi değişimi aktif session hedefini sessizce değiştirir | S4 | Arm-time normalized immutable target snapshot; değişiklik için confirmed stop+re-arm | contact mutation trace | G1/G2/G5 | `LOCAL_PASS` |
| H12 | Duplicate concurrent native/Dart/exact/inexact dispatch | S3 | Tek `claimAndDispatch`, per-generation lock; crash residual documented | exact-vs-inexact/Dart/receiver + process-death points | G1 model/fault evidence | `LOCAL_PASS`, crash-device evidence open |
| H13 | Yanlış resmî kısa kod aranır | S4 | Callable target validator; app kısa kod sentezlemez | malicious URI/3-digit/Unicode phone fuzz | G1/G4 security | `LOCAL_PASS`, fuzz depth partial |
| H14 | App “call connected” diyerek yanlış güven üretir | S3 | Connection state daima `unknown`; call/fallback outcome ayrımı; listing parity | UI/store copy scan + device observation | G2/G8 | `LOCAL_PASS`, Play/device unverified |
| H15 | Force Stop normal process kill gibi vaat edilir | S3 | Destek sözleşmesinden açıkça hariç; QA matrisi ayrı sonuç | `am kill` PASS, Settings Force Stop unsupported | G5/G7/G8 | `DOCUMENTED`, `UNVERIFIED` |

## Release-blocking acceptance

- Açık S4 veya kontrolsüz S3: G0 `FAIL`.
- Tek missed deadline, wrong target, confirmed-cancel dispatch veya PIN bypass:
  candidate `FAIL`, readiness tavanı 49.
- Source-text test safety kanıtı değildir. G1/G2; executable unit,
  concurrency, fault, mutation ve device testlerine bağlanır.
- Kod yazarı G0/G1 signoff veremez; bağımsız reviewer gerekir.
- AAB hash değişince G7–G9 ve candidate-bound evidence geçersizdir.

## Kalan residual riskler

- Telecom request'in çalma/bağlanma sonucu app tarafından bilinemez.
- External call side effect ile durable terminal commit atomik değildir.
- OEM alarm/power politikaları ilan edilen zarf içinde dahi ölçüm gerektirir.
- Force Stop, root/modifiye OS, SIM/şebeke ve alıcı tarafı kontrol edilemez.
- İlk production sürüm kurulu cihazlardan uzaktan geri alınamaz.

Bu dosyanın `NO_GO` başlığı yalnız G0 bağımsız signoff ve exact candidate evidence
ile değiştirilebilir; repository testlerinin yeşil olması tek başına yeterli
değildir.
