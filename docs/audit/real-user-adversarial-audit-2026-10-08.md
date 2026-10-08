# KoruBeni — Gerçek Kullanıcı / Saldırgan Denetimi, Bilinmeyen Hata Avı ve Düzeltme (2026-10-07/08)

Etiketler: `[KESİN]` doğrudan gözlendi/ölçüldü · `[GÜÇLÜ ÇIKARIM]` kanıttan çıkarıldı · `KANITLANMADI` bu ortamda doğrulanamadı.

**Başlangıç:** `8684cf7` (dal `codex/evidence-remediation-20260911`, temiz ağaç). **Son kod commit'i:** `e3415a1`.
**Ortam:** macOS, Flutter 3.38.9 / Dart 3.10.8; AVD `KoruBeni_A017_API35` (API 35, `userdebug`, GMS YOK, 420 dpi). Fiziksel cihaz YOK, gerçek SIM YOK, Play/RevenueCat sandbox YOK. API 29/36 imajı kurulu değil.
**Cihaz günlüğü:** [`evidence/adversarial-2026-10-08/device-log.md`](evidence/adversarial-2026-10-08/device-log.md).

## 0. Önceki kararın çürütülmesi

Önceki rapor "kod tarafında bilinen açık kusur yok" diyordu ve baseline'da paket bile tam yeşil değildi:
`flutter test` **2124 geçti / 1 kırmızı** (`audit_absence_claims_gate_test` 30 sn zaman aşımı) `[KESİN]`. Bu denetim, mevcut testlerin hiçbirinin dolaşmadığı **iki özelliğin kesişiminde** 4'ü yüksek önemde olmak üzere 13 yeni kod kusuru buldu; biri cihazda kullanıcıyı uygulamadan çıkamaz halde bıraktı, biri PIN kilidini atlattı.

## 1. Durum ve eylem modeli (özet)

Durumlar: yasal (gerekli/güncel) · PIN (yok/var/okunamaz/kilitli) · onboarding · birincil kişi · abonelik (yükleniyor/ücretsiz/Pro/erişilemez) · panik (yok/geri sayım/native ARMED/CLAIMED/sonuç) · Check-In ve Safe Walk (yok/ARMED/grace/sonuç) · uygulama (ön plan/arka plan/devam kilidi) · ağ · izinler · yaşam döngüsü (normal/yeniden yaratma/süreç ölümü).
Eylemler: açılış, geri, HOME, devam (<120 sn / >120 sn), süreç öldürme, sekme, derin bağlantı, ses tuşu/kutucuk/widget paniği, panik butonu, PIN iptali, doğru/yanlış PIN, kişi ekle/sil/birincil, Check-In/Safe Walk başlat/durdur/güvendeyim, satın alma/geri yükleme, siren, sahte arama, harita, izin ver/reddet, ayarlardan dönüş, sıfırlama.

**Kök neden sınıfı (yeni):** Navigator yığını tek bir paylaşılan kaynak; `Navigator.pop(context)`, `pushReplacement(context)` ve `popUntil(isFirst)` *bağlamın route'unu değil en üstteki route'u* hedefler. PIN kilidi, panik geri sayımı, dış bağlantılar ve paywall aynı yığına bağımsız itiliyordu; birbirlerinin üstüne geldiklerinde biri ötekini kapatıyordu.

## 2. Düzeltilen kusurlar

| ID | Önem | Kullanıcıya görünür | Yeniden üretim | Kök neden | Commit | Regresyon | Bağımsız doğrulama |
|---|---|---|---|---|---|---|---|
| N-03 | **HIGH** | Evet | `[KESİN]` cihaz (09b9004): Test Modu + `korubeni://open/timeline` → T+10'da prova zaman çizelgesini kapattı, prova "0 saniye"de kaldı; GERİ ve doğru PIN etkisiz; çıkış yalnız süreç öldürme. Gerçek panikte (widget testi): sonuç ekranı üstteki route'u DEĞİŞTİRDİ — o route devam kilidiyse kilit PIN'siz kalktı; geri sayım ölü kaldı, `PanicCountdownGuard` süreç boyunca tutuldu (tüm panik girişleri reddedilir). | Geri sayım/hata diyaloğu `Navigator.pop/pushReplacement(context)` en üstteki route'u hedefliyordu. | `216ff3c` | `countdown_route_scoped_navigation_test` (prova, gerçek gönderim, hata diyaloğu), `own_route_test` | Cihaz `[KESİN]` düzeltilmiş build: zaman çizelgesi üstte kaldı, GERİ → Ana Sayfa. Mutasyon: pop/replace eski hale → kırmızı (birim + fuzz I4). |
| N-05 | **HIGH (güvenlik)** | Evet | `[KESİN]` widget testi (gerçek kilit + gerçek `EmergencyCallScreen`): kilit üstteyken arama sonucu ekranında "bitir" → `popUntil(isFirst)` kilidi de kaldırdı. Ulaşılabilir yollar: >2 dk arka plan + widget/kutucuk paniği (kilit önce itilirse) ve devamda Dart tarafı Check-In gönderimi. | `_returnHome` yığının tamamını boşaltıyordu. | `31de015` | `resume_lock_route_integrity_test` | Mutasyon → kırmızı (birim + fuzz I6). security-reviewer: kalan atlatma vektörü yok. |
| N-01 | **HIGH** | Evet | `[KESİN]` widget testi: aynı devamda hızlı erişim geri sayımı kilitten önce itilirse kilit geri sayımın ÜSTÜNE çıkıyor, PIN iptal tuş takımını 10 sn'lik sürede iki PIN girişinin arkasına saklıyordu. | Kilit, canlı geri sayımı hiç hesaba katmıyordu (sıra yarışı). | `31de015` | aynı dosya | Mutasyon → kırmızı (birim + fuzz I7). |
| N-02 | MEDIUM | Evet | `[KESİN]` widget testi: PIN doğrulanırken kilidin üstüne itilen route, `onUnlocked` = `navigator.pop()` ile kapanıyordu (geri sayım kapanırsa native oturum silahlı, iptal UI'sı yok). | En üstteki route'u kapatan kilit açma. | `31de015` | aynı dosya | Mutasyon → kırmızı (birim + fuzz I8). |
| L-01 | MEDIUM (güvenlik, savunma) | — | Kilit, doğrulanmış açma dışında herhangi bir yolla kaldırılırsa geri gelmiyordu. Ayrıca kendini onarma ilk sürümde PIN okumasını bekleyip 2 sn'ye kadar açık pencere bırakıyordu (security-reviewer). | — | `31de015` | "comes back at once, without waiting on storage", "leaked countdown guard" | Mutasyon 5/5 kırmızı. |
| A-05 | MEDIUM | Evet | `[KESİN]` widget testi: panik butonu geri sayımı açıkken hızlı erişim tetiği, abonelik "ücretsiz" dönünce **paywall'ı geri sayımın üstüne** itti. | Host, guard'ı yalnız push anında kontrol ediyordu. | `c2def35` | cross-surface guard testi | Mutasyon → kırmızı. |
| A-06 | MEDIUM | Evet | `[KESİN]` cihaz (N-03 ile aynı yeniden üretim) + widget testi. | Bağlantı yönlendirmesi geri sayımı bilmiyordu. | `c2def35` | 2 test (`deep_link_resume_lock_test`) | Mutasyon → kırmızı. |
| N-04 | LOW | Evet | `[KESİN]` widget testi: son anda girilen doğru PIN'in doğrulaması gönderim başladıktan sonra bitince kilit sayacına **hata** yazıldı ve "PIN eşleşmedi" gösterildi. | `matches && !_isNavigating` dalı. | `ad46474` | 1 test | Mutasyon → kırmızı. |
| A-02 | **HIGH** (önceki raporda MEDIUM bilinmeyen) | Hayır (geç/gecikmiş arama) | `[KESİN]` JVM: yeni açılışta TIME_SET boot reconcile'dan önce gelince son tarih **72 saat** ileri itildi; açılış boyunca kaçırılan son tarih hiç aranmadı; iki sıra arasındaki fark 259 230 000 ms. | `elapsedRealtime` son tarihi yalnız yazıldığı açılışta anlamlı; sıra garanti değil (TIME_SET ön plan kuyruğunda, direct-boot alıcısı). | `c33d722` | 9 JVM testi | Mutasyon 7/7 kırmızı. kotlin-reviewer bulguları (başarısız yazımda eski alarm, korumasız sağlayıcı, BOOT_COUNT yokken kalan risk) uygulandı. `BOOT_COUNT` cihazda 16→17 `[KESİN]`. |
| A-12 | MEDIUM | Evet | `[KESİN]` cihaz: alarm sesi 3 → siren 7 → süreç ölümü 7 → yeniden açılış 7. | Akış sesi sistem durumu; süreç ölümünde kimse geri yüklemiyor. | `2725a59` | 4 Robolectric testi | Cihaz `[KESİN]`: yeniden açılışta 3; kullanıcı arada 5 yaptıysa 5 kaldı. |
| A-09 | LOW | Evet | `[KESİN]` gerçek ffi SQLite: `UNIQUE constraint failed: activity_events.id` — ardışık iki `await`'li kayıt bile çakıştı. | `id = millisecondsSinceEpoch` + `INSERT OR ABORT`. | `c1e24a2` | 3 davranış testi (kaynak-metni testinin yanında) | — |
| F-01 | LOW | Evet | `[KESİN]` hata enjeksiyonu: etkinlik tablosu okunamazsa zaman çizelgesi sonsuz yükleme göstergesinde kaldı, notlar da görünmedi. | `getEvents()` hatası yakalanmıyordu. | `9190095` | 1 widget testi | — |
| A-04 | LOW | Evet | `[KESİN]` cihaz: kişi kayıtlıyken "Önce acil kişini ekleyelim". | Alt başlık kişiye bakmıyordu. | `9438fa2` | 2 widget testi | Cihaz `[KESİN]`: "Eksik adımlara aşağıdan dokunarak tamamlayabilirsin." |
| R-01 | LOW | Evet | `[KESİN]` widget testi: süre çipine / "Başla"ya çift dokunuşta oturum başladı ama ikinci akış hata SnackBar'ı gösterdi. | Ekran düzeyinde tek-uçuş yok. | `e3415a1` | 2 widget testi | — |
| U-01 | LOW | Evet | `[KESİN]` Google Play'li `user` AVD: konum rızası yokken Harita konum düğmesi yalnız "Bu özellik için ilgili onay gereklidir." dedi (hangi onay, nerede yok); kart kalıcı "Konum alınamadı". | Genel rıza kapısı metni yol göstermiyordu. | `5081f10` | metnin gerçek menü etiketlerini (Ayarlar → Yasal Bilgiler & KVKK → Rıza Yönetimi) içermesini sabitleyen test | Yol cihazda gezilerek doğrulandı. |
| T-02 | **HIGH (yayın hattı)** | Hayır (CI) | `[KESİN]` temiz worktree'de: `release_doc_citation_gate_test` kırmızı; `PRODUCTION_AUDIT.md` 12 satırda git'in ignore ettiği `.claude/rules/...` dosyalarını kanıt gösteriyor, kapı "diskte var mı" diye çözüyordu → geliştirici makinesinde yeşil, temiz checkout'ta (CI) kırmızı. Bu dal 2026-08-03'ten beri CI'da hiç koşmadı (232 commit), bu yüzden görünmedi. | Ortama bağımlı dosya kümesi. | `3453b5e` | mevcut kapı + negatif kontrol | Temiz worktree'de commit-başı koşuda yeşil. Satırlar artık bu kuralları "yerel, depoda olmayan araç kuralı" olarak adlandırıyor (PASS hükümleri depoda görülebilir kanıta dayanmıyor — sahip değerlendirmeli). |
| T-01 | — (test altyapısı) | Hayır | `[KESİN]` baseline kırmızısı; betik yerelde ignore edilmiş 6×~200 MB APK'yı her iddia için okuyordu (12,3 sn tek başına). | — | `39bb440` | mevcut kapı testi | 1,2 sn; karar aynı. |

## 3. Durumlu rastgele kullanıcı testi (fuzz)

`test/core/navigation/navigation_safety_fuzz_test.dart` (`0f14ed5`): gerçek `MainNavigation`, devam kilidi, `PanicCountdownGuard`, `OwnRoute`, `EmergencyCallScreen` üzerinde **26 tohum / 1000 rastgele eylem** (12×10, 10×40, 4×120; taban tohum `20261007`, `FUZZ_SEED` ile yeniden üretim, `FUZZ_SCALE` ile ölçek). Her adımdan sonra 8 değişmez: I1 tek geri sayım ve guard eşliği · I2 kilit borcu varken uygulama içeriği görünmez · I3 bağlantı hedefi kilidin/geri sayımın üstünde olmaz · I4 bitmiş geri sayım yığında kalmaz · I5 istisna yok · I6 kilit yalnız doğrulanmış açma/silmeyle kalkar · I7 kilit çalışan geri sayımın üstünde olmaz · I8 bitmemiş geri sayım yığından çıkmaz.

Düzeltilmiş kodda 0 ihlal `[KESİN]`. **Testin kendisinin geçerliliği:** düzeltmeler tek tek geri alındığında fuzz N-03 (replace), N-01, N-02, N-05'i **davranışla** yakaladı. İlk sürüm 7 mutanttan yalnız 2'sini (ikisi de derleme hatasıyla) "yakalıyordu"; model/değişmezler güçlendirildi. Yakalanmayanlar ve nedenleri: N-03 pop yolu (örtülü geri sayımın kendini kapatması nadir dizilim — `own_route_test` öldürüyor), A-06 yönlendirici katmanı (MainNavigation'daki ikinci katman maskeliyor — `deep_link_resume_lock_test` öldürüyor), kendini onarma (diğer düzeltmelerle eşdeğer mutant).

## 4. Test geçerliliği bulguları (§31)

- `activity_service_test`, `safety_timeline_unified_test`, `countdown_typed_cancel_contract_test`: kaynak-metni testleri; A-09/F-01'i göremezdi. Davranış testleri eklendi; sözleşme testindeki `Navigator.pop` işaretçisi tam da hatalı çağrıyı sabitliyordu.
- `emergency_trigger_cross_surface_guard_test` "the trigger was evaluated" (`resolveCalls == 1`) A-05'in kusurlu davranışını (geri sayım açıkken erişim çözümü) önkoşul olarak sabitliyordu.
- Önceki raporun "16/18 → 18/18" ve "2125/2125" iddiaları baseline'da tekrarlanamadı: yerelde 1 kırmızı (T-01).

## 5. Düzeltilmeyenler ve sahip kararları

### SAFETY / PRODUCT SEMANTIC DECISION REQUIRED
- **A-03:** K-04'ün açtığı dar yolda Check-In/Safe Walk grace uyarısı "stale" sayılıp gösterilmeden aranabilir. Uyarısız arama mı, öneri mi — sahip.
- **A-11:** Geri sayım sırasında Flutter süreci ölürse yeniden açılışta iptal arayüzü gelmez; native son tarihte arar. Süreç ölümünden sonra iptal yüzeyi bir ürün özelliğidir — sahip.
- **Kilit ↔ sonuç ekranı sırası:** Geri sayım kilitten önce açıldıysa kilit, geri sayım bitince arama sonucu ekranının üstüne gelir (5 sn güvenlik diyaloğu yine üstte); kilit önce açıldıysa sonuç ekranı kilidin üstündedir (PIN'siz acil durum yüzeyi, tasarım gereği). Atlatma değil; tutarlılık için ürün kararı.

### Kalan düşük/bilgi bulguları
| ID | Sev. | Not |
|---|---|---|
| A-02r | LOW | Hem BOOT_COUNT okunamayan hem de yeni açılışın çalışma süresi eski damgayı geçmiş bir cihazda A-02 sürer; bu sürümden önce silahlanmış kayıtlar (alan yok) eski varsayımı kullanır. |
| A-07 | LOW | Abonelik kapısı beklerken kilit yükselirse paywall kilidin üstüne gelebilir (veri açığa çıkmaz; ≥120 sn arka planı kapsayan bir `await` ister). |
| A-08 | LOW | Yeniden park mikro-yarışı: bağlantı bir sonraki dönüşe kadar parkta kalabilir. |
| A-10 | INFO | `_deleting` bayrağı etkisiz ama diyalog bariyeri çift eylemi engelliyor; görünür etki yok. |
| A-13…A-17 | INFO | Önceki rapordaki gibi. |

## 6. Cihaz ve ortam (§19–§30)

Ayrıntı: [`device-log.md`](evidence/adversarial-2026-10-08/device-log.md). Özet:

| Alan | Durum |
|---|---|
| N-03, A-12, A-04, K-01 regresyonu | GMS'siz API 35 emülatörde düzeltme öncesi ve sonrası `[KESİN]` |
| A-01 | GMS'li `user` API 35 emülatörde 10 sekme döngüsü (5'i aktif konum isteğiyle) 0 ANR `[KESİN]`; GMS'siz gerçek cihaz **DEVICE VALIDATION REQUIRED** |
| A-02 | JVM `[KESİN]`; `BOOT_COUNT` gerçek soğuk açılışta 16→17 `[KESİN]`; TIME_SET/LOCKED_BOOT_COMPLETED gerçek cihaz sırası ve direct-boot'ta `BOOT_COUNT` okunabilirliği **DEVICE VALIDATION REQUIRED** |
| API 29 / API 36 | **ENVIRONMENT BLOCKER**: sistem imajları kurulu değil; indirmek dış eylem ve açık izin gerektiriyor — bu turda indirilmedi |
| Gerçek SIM / Telecom / OEM pil yöneticisi / fiziksel Doze / çift SIM | **DEVICE BLOCKER** — fiziksel cihaz yok |
| Play Billing / RevenueCat | **COMMERCE BLOCKER** — sandbox hesabı ve kimlik bilgisi yok; emülatörde Pro yetkisi yok, gerçek panik arm'ı cihazda denenemedi (yalnız Test Modu) |
| "Etkinlikleri tutma", süreç ölümü (onboarding, harita, kişi düzenleme, sıfırlama) | Bu turda yeniden koşulmadı; önceki denetim kanıtı (`device-verification-2026-10-07-final-audit.md`) geçerli. Siren süreç ölümü bu turda ölçüldü (A-12). |

## 7. Doğrulama zinciri

| Kapı | Sonuç | Kanıt |
|---|---|---|
| Baseline `8684cf7` | analiz temiz; `flutter test` **2124 / 1 kırmızı** (yerel), temiz worktree'de `release_doc_citation_gate` kırmızı (T-02) | `[KESİN]` |
| Commit başı (temiz `git worktree`, `build/test_cache` silinerek) | **14/14 commit**: analiz 0 sorun; tam Flutter paketi yeşil (2125 → 2181); A-02 ve siren commit'lerinde Kotlin birim testleri yeşil | [`per-commit.txt`](evidence/adversarial-2026-10-08/per-commit.txt) |
| Kotlin birim (JVM/Robolectric) | **155/155** (önce 141) | `build/app/test-results/testPlayDebugUnitTest` |
| Kararlılık (§33), yük altında | yeni kritik 9 dosya 10× (600 test) 0 hata; fuzz 3× (78 dizi) ve `FUZZ_SCALE=4` (104 tohum, ~4000 eylem) 0 ihlal | [`flakiness.txt`](evidence/adversarial-2026-10-08/flakiness.txt) |
| Karşı-olgusal mutasyon (§32) | Navigasyon/geri sayım/host/diyalog 9 + kilit davranışları 5 + A-02 7 + A-06 yönlendirme 1 = **22 anlamlı mutant öldürüldü**, her biri için özgün/enjekte/geri yüklenen hash; 1 eşdeğer mutant (N-04 iç `return`) kaldırıldı; fuzz için 6 mutanttan 4'ü davranışla, kalan 2'si birim testleriyle öldürüldü | bu raporun §2–§3'ü |
| Bağımsız inceleme | security-reviewer: CRITICAL/HIGH yok, kalan PIN atlatma vektörü yok; kotlin-reviewer: 1 HIGH + 3 MEDIUM → uygulandı; flutter-reviewer: CRITICAL/HIGH yok, test boşlukları → `own_route_test`, guard testleri eklendi | — |
| `scripts/verify_release.sh` (HEAD `5081f10`; `flutter clean` dahil) | **EXIT=0** — 5/5 kod+smoke kapısı + etiketli yayın kapıları yerel PASS; **2182/2182** test; `CRITICAL_COVERAGE_PASS`; imzalı smoke AAB + birleşik release manifest yüzeyi; `lintSmokeRelease` + Kotlin unit + `assemblePlayDebugAndroidTest`; 8 native kütüphane 16 KB uyumlu | [`verify_release_summary.txt`](evidence/adversarial-2026-10-08/verify_release_summary.txt). Not: ilk koşu, durdurulan önceki koşunun yetim `flutter test` süreci aynı depoda çalışırken yapılmıştı; süreç öldürülüp zincir temiz koşuldu. |
| Enstrümantasyon | **18/18** — `am instrument`, Play AVD (API 35, `user`), `5081f10` kodu, `lastUpdateTime 2026-10-08 09:11:37` | `[KESİN]` |
| Release (smoke, debuggable değil) cihaz duman testi | Temiz kurulum yolculuğu (onay → karusel → kişi + kişi rızası → PIN → **bildirim izni reddedildi** → pil adımı atlandı) çökmesiz; ana sayfada A-04 düzeltmesi; Test Modu + `korubeni://open/timeline` → kapan yok; >120 sn arka plan + bağlantı → kilit üstte; kilit ekranının ekran görüntüsü siyah (ort. parlaklık 0,53 — FLAG_SECURE); PIN → zaman çizelgesi; logcat'te FATAL/ANR/`E/flutter` 0 `[KESİN]` | [`device-log.md`](evidence/adversarial-2026-10-08/device-log.md) |

## 8. Güven ayrımı

| Boyut | Karar | Gerekçe |
|---|---|---|
| **CODE** | **FAIL** | Doğrulanmış ve düzeltilmemiş kod kusuru yok; ancak §38 ölçütleri karşılanmıyor: sahip kararı bekleyen davranışlar (A-03, A-11, kilit↔sonuç ekranı sırası) ve kabul edilmemiş LOW maddeler (A-02r, A-07, A-08) açık. Bunlar sahip kararıyla kabul edilirse CODE, bu turun kanıtıyla PASS'a yükselebilir. |
| **DEVICE** | **UNKNOWN** | Tüm cihaz kanıtı emülatörde. Gerçek SIM/Telecom ile otomatik arama, kilitli ekranda arama, fiziksel Doze ve OEM pil yöneticileri, açılışta TIME_SET sırası (A-02), GMS'siz gerçek cihazda harita (A-01), çift SIM: yapılmadı. API 29/36: ENVIRONMENT BLOCKER. |
| **COMMERCE** | **UNKNOWN** | Play/RevenueCat sandbox satın alma, geri yükleme, iptal, süre dolumu ve çevrimdışı açılış hiç denenmedi; emülatörde Pro yetkisi olmadığı için gerçek panik arm'ı cihazda sınanamadı. |
| **RELEASE** | **FAIL** | Bu commit'ler push edilmedi; dal 2026-08-03'ten beri CI'da koşmadı (T-02 bu yüzden gizli kaldı); `release.yml` önkoşulları (2 secret + 1 değişken + imzalı tag) eksik; Play Console adımları yapılmadı. |
| **PRODUCT** | **NO-GO** | Gerçek SIM/Telecom/Doze/Play Billing kanıtı olmadan yayın kararı verilemez. |


## 9. Nihai cevap

**Gerçek bir kullanıcı bu uygulamayı öngörülmeyen şekillerde kullandığında bugün bildiğimiz kod kaynaklı problem kaldı mı? — EVET.**

Bu turda bulunan 16 kod/altyapı kusurunun hepsi düzeltildi ve iki bağımsız yöntemle (regresyon testi + mutasyon ve/veya cihaz) doğrulandı. Kalan, bilinen kod kaynaklı maddeler: A-02r (BOOT_COUNT okunamayan cihaz + eski kayıt), A-07, A-08 (LOW, kabul edilmemiş) ve sahip kararı bekleyen davranışlar (A-03, A-11, kilit↔sonuç ekranı sırası). Kodun gerçek cihaz davranışları (Telecom, Doze, OEM, açılış yayın sırası, GMS'siz konum) kanıtlanmadı.

**Bugün gerçek kullanıcılara yayınlıyor muyuz? — NO-GO.** Gerekçe testlerin yeşil olması değil: gerçek SIM/Telecom, fiziksel Doze/OEM ve Play Billing kanıtı yok; yayın hattı (CI koşusu, imzalı Play AAB, secret'lar, Console) hiç çalıştırılmadı.
