# KoruBeni — Kanıta Dayalı Kapsamlı Son Denetim ve Düzeltme (2026-10-06/07)

Etiketler: `[KESİN]` doğrudan gözlendi/ölçüldü · `[GÜÇLÜ ÇIKARIM]` kanıttan çıkarıldı, doğrudan gözlenmedi · `KANITLANMADI` bu ortamda doğrulanamadı.

**Başlangıç commit'i:** `eda8304` (dal `codex/evidence-remediation-20260911`, temiz ağaç).
**Ortam:** macOS, Flutter 3.38.9 / Dart 3.10.8; emülatör AVD `KoruBeni_A017_API35` (API 35, `userdebug`, GMS yok, 420 dpi, 1080x2400). Fiziksel cihaz YOK. Play/RevenueCat sandbox YOK.

## PHASE 0 — Önceki "CODE READY" kararına itiraz

Önceki karar (launch-readiness-2026-10-05 + 10-06 fonksiyonel denetim) şu kanıtlara dayanıyordu: yeşil test paketi, 16/18 enstrümantasyon, "yayını engellemez" diye ertelenen reset/süreç-ölümü hatası, tek denemeyle "gözlenmedi" denen derin bağlantı/kilit yarışı ve `[GÜÇLÜ ÇIKARIM]` siren yarışı. Bu denetim bu kararı **çürüttü**: ertelenen maddelerin ikisi gerçek ve yeniden üretilebilir hataydı (biri PIN atlatması), ayrıca önceki testlerin bir kısmının ilgili davranışı hiç sınamadığı gösterildi (aşağıda "Test geçerliliği").

## 1. Düzeltilen kusurlar (her biri: yeniden üretim → kök neden → regresyon testi → minimal yama → hedefli + tam doğrulama)

| ID | Sev. | Alan | Yeniden üretim | Kök neden | Commit | Regresyon testi | Bağımsız ikinci doğrulama |
|---|---|---|---|---|---|---|---|
| K-01 | **HIGH** (güvenlik) | Derin bağlantı / bildirim ↔ devam kilidi | `[KESİN]` API 35, `eda8304`: >120 sn arka plan → kilit → HOME → `korubeni://open/timeline` → zaman çizelgesi PIN'siz kilidin **üstünde** açıldı ("Yeni Not" kullanılabilir). | Devam kilidi `/` üstüne push edilen bir route; park edilmiş hedefi tüketen `MainNavigation` aynı Navigator'a push ediyordu. `deep_link_test` "LOCKED" kontratı yalnız açılış kilidini düşünüyordu. | `6edbc8a` | `deep_link_resume_lock_test` (5): kilit açıkken bağlantı, PIN okuması sürerken bağlantı (yarış), takılan PIN okuması, abonelik kapısı sırasında yükselen kilit, kilitliyken dönüşte zaman damgası. Her koruma mutantla düşürüldü. | Cihaz `[KESİN]`: düzeltilmiş build'de 2 senaryo (kilit açıkken bağlantı + dönüşle eşzamanlı bağlantı) — kilit üstte kaldı, PIN sonrası hedef açıldı; son commit'te yeniden (§8). |
| K-02 | **HIGH** | Veri silme / süreç ölümü | `[KESİN]` `eda8304` debug: Profil → Cihaz Verilerini Temizle → PIN → HOME → `kill -9` → görev: `'_history.isNotEmpty'` assertion + "Bir sorun oluştu", ardından sürekli `_elements.contains` hataları. Release'de `flutter_framework_unhandled` (önceki kayıt). | `AppRoot.restartStartup` kabuğu InheritedWidget ile arıyordu; push edilmiş route Overlay'de `/`'un kardeşi. Arama boş → `pushAndRemoveUntil` yedeği `/`'u sildi → restorasyon boş geçmiş. `startup_pin_boundary_test` yalnız AppRoot **içinden** çağırıyordu. | `3e39841` | `app_reset_restart_from_pushed_route_test` (2): gerçek AppRoot + push edilmiş route + `restartAndRestore`; gerçek `AppResetService` ile devam-kilidinden "PIN'i unuttum". 3 mutant düşürüldü. | Cihaz `[KESİN]`: Profil ve Verilerimi Sil yolları debug'da 0 framework hatası; smoke **release**'de yerel hata günlüğünde `flutter_framework_unhandled` yok, onay ekranı geldi. |
| K-03 | MEDIUM | Panik geri sayımı zamanlaması | `[KESİN]` deterministik/rastgele birim testleri: `secondsUntil` son tarihten <1 ms önce 0 döndürüyordu. | Kalan süre ms'ye kırpılıyordu; panik son tarihi µs hassasiyetinde, native ms tabanında. Native o anda `currentTimeMillis() < finalDeadlineMs` ile reddedince panik yolu `unknown` sayıp **dialer'ı açıyor**, native alarm da otomatik isteği gönderiyordu (mükerrer). Olasılık geri sayım başına ≈%0,05 `[GÜÇLÜ ÇIKARIM]`. | `f1a030d` | `countdown_clock_test` (+3): son 1 ms'de 1/10/100/499/500/999 µs; 20 000 rastgele örnekte "0 ⇒ native kabul eder"; 200 ms ve 1 sn tik ile 1/10/100/499/500/999/1000/1001/2000/9999 ms + rastgele ofsetler: erken ateşleme yok, gecikme < 1 periyot. | Check-In hizalama + davranış matrisi testleri yeşil. Not: Dart aynası en fazla bir tik (≤200 ms panik, ≤1 sn check-in) geç; native alarm son tarihte, çağrıyı geciktirmez. |
| K-04 | MEDIUM | Native saat değişimi | `[KESİN]` JVM testi: duvar saati son tarihten hemen önce geri alınır, ELAPSED alarm TIME_SET'ten önce gelir → alarm reddedilir, TIME_SET uzlaştırması da reddedilir, oturum ARMED kalır, hiçbir şey yeniden denemez. | `reconcileAfterClockChange` `remaining==0` dalı yeniden tabanlamadan `claimAndDispatch` çağırıyordu (duvar saati kapısı). | `6a8192f` | 2 JVM testi (takılı yol dispatch eder; 5 dk'dan eski takılı yol aranmaz, önerilir) + `57930de` iç içe geçme testindeki liveness değişmezi (düzeltme geri alınınca düşüyor). | Kotlin inceleme ajanı: erken/mükerrer arama yolu yok. Duvar saati son tarihi geçmişse davranış **değişmedi**. |
| K-05 | MEDIUM (gizlilik) | Harita | `[KESİN]` cihaz: ana ekranda `files/osm_tiles_v1` dolu; widget testinde gizli haritada `TileLayer` kurulu. | `IndexedStack` MapPage'i kurulu tutuyor; `TileLayer` her açılışta yedek merkez karolarını OSM'den çekiyordu (kodun kendi "yalnız aktif görünüm" kuralına ve OSMF politikasının ruhuna aykırı; kullanıcı haritayı hiç açmasa da üçüncü tarafa IP/UA trafiği). | `d041a00` | `NAV-02b` (main_navigation_behavior_test) | Cihaz `[KESİN]`: ana ekranda 0 karo, Harita sekmesi açılınca 60 karo. |
| K-06 | MEDIUM | Test Modu (prova) — **regresyon** `6e47a6b` | `[KESİN]` cihaz (2.0x yazı tipi): provada tuş takımı yok, 10 sn boyunca "Güvenlik PIN'i doğrulanıyor…". | Prova PIN durumunu hiç yüklemiyordu; iptal de `_armResult` null olduğundan "onaylanamadı"ya düşerdi. Mevcut Test Modu a11y testleri tuş takımı çizilmediği için **boş** geçiyordu. | `e619a2d` | `countdown_test_mode_pin_cancel_test` (4): tuş takımı görünür; doğru PIN native çağrısız kapatır; yanlış PIN gerçek kilide sayılır (bilinçli — ölçümsüz tuş takımı PIN kâhini olurdu); prova iptali güvenlik geçmişine yazılmaz. | Düzeltmesiz 2/2 kırmızı; son commit'te cihaz (§8). |
| K-07 | LOW | Siren | `[KESİN]` deterministik test (geciken `setMaxAlarmVolume`); cihazda 20 zamanlı denemede pencere yakalanamadı (`KANITLANMADI` cihazda). | Yanıt `dispose`'tan sonra gelirse orijinal ses hiç geri yüklenmiyor, alarm akışı en yüksekte kalıyordu. | `b64a45c` | `siren_alarm_volume_restore_test` (3) | Cihaz: normal durdurmada ses 7→2 geri yüklendi `[KESİN]`. |
| K-08 | — (enstrümantasyon) | §5: 16/18 | `[KESİN]` iki test RootBeer/safe_device'ı yansımayla çağırıyordu; F-06 (`6bb7361`) ile APK'dan çıktılar → yalnız `ClassNotFoundException`. **Bayat test.** | — | `f73f00d` | Üretim `DeviceIntegrityChannel` yolu (codec, işçi iş parçacığı, ana looper) cihazda. | API 35: **18/18** `[KESİN]`. |
| K-09 | LOW (test) | Kararsız test | `[KESİN]` yük altında 18 koşunun 2'sinde `unified_consent_behavior_test` RIZA-03..09. | Sabit 100 ms gerçek-zaman bekleme. | `e876516` | — | Yük altında 6/6 + paralel tam ekran paketi 3/3. |
| K-10 | — (kanıt) | §37 mutasyon kanıtı | Çalıştırıcı yalnız enjekte hash'i kaydediyordu. | — | `cc2fdd6` | sözleşme testi | Her mutant: pristine/injected/differs/restored. |

İnceleme ajanlarının (security-, flutter-, kotlin-reviewer) bulguları üzerine aynı commit'lere eklenenler: kilit kararında PIN okumasına 2 sn sınır (takılan okuma `lockActive`'i kalıcı `true` bırakıp yeniden kilitlemeyi devre dışı bırakabiliyordu — benim ilk yamamın yan etkisiydi); yeniden park etme daha yeni bir bağlantının üzerine yazmıyor; prova iptali geçmişe yazmıyor; yeni testlerdeki sabit beklemeler sınırlı yoklamaya çevrildi; iç içe geçme testine liveness değişmezi ve kapsam sayacı.

## 2. Düzeltilmeyen bulgular (küçük olanlar dahil)

| ID | Sev. | Alan | Kanıt | Etki | Neden düzeltilmedi / sahip |
|---|---|---|---|---|---|
| A-01 | MEDIUM (ortam) | Harita ↔ GMS'siz cihaz | `[KESİN]` API 35 (GMS yok) emülatörde Harita sekmesinde ANR. İz: ana iş parçacığı geolocator `NmeaClient.stop` → `LocationManager.unregisterGnssStatusCallback` binder çağrısında; system_server GNSS HAL'ında kilitlenme (`native_stop_sv_status_collection` kilidi tutarken HAL geri çağrısı aynı kilidi bekliyor). | Emülatör HAL kusuru `[GÜÇLÜ ÇIKARIM]`; ancak GMS'siz cihazlarda (Fused değil LocationManager yolu) system_server takılması uygulamayı ANR'a sokar. Ana iş parçacığı takılıyken native alarm alıcıları da çalışamaz. | Fiziksel GMS'siz cihazda (ör. Çin ROM'lu Xiaomi) doğrulanmalı (§9 H-9). Eklenti davranışı; kod düzeltmesi bu turda yok. |
| A-02 | MEDIUM | Native açılış ↔ TIME_SET sırası (önceden var) | Kaynak (kotlin-reviewer): TIME_SET, açılışta `reconcileAfterBoot`'tan önce işlenirse `remaining` önceki açılışın çalışma süresinden hesaplanır ve son tarih o kadar ileri itilir. Bu emülatörün soğuk açılış geçmişinde TIME_SET yok `[KESİN]`; gerçek cihaz sırası `KANITLANMADI`. | Olursa süresi dolan oturum çok geç aranır. | Açılış kimliği (BOOT_COUNT) saklamak şema değişikliği ister; fiziksel cihaz testi (H-10) ve sahip kararı. |
| A-03 | LOW | K-04'ün yeni açılan yolu | kotlin-reviewer: aynı pencerede grace uyarısı "stale" sayılıp gösterilmemiş olabilir; Check-In/Safe Walk uyarısız aranabilir (önceden hiç aranmıyordu). Yeniden tabanlama yazımı başarısız olursa eski takılı davranış sürer. | Çok dar zamanlama. | Uyarısız arama mı, öneri mi: **SAFETY SEMANTIC** — sahip kararı. |
| A-04 | LOW | Hazırlık kartı metni | `[KESİN]` cihaz: kişi kayıtlıyken, 2+ başka eksik varsa alt başlık "Önce acil kişini ekleyelim; gerisi bekleyebilir." | Yanlış yönlendirici metin. | Mevcut anahtarlarda doğru metin yok; yeni kopya CLAUDE.md kural 4 → sahip. |
| A-05 | LOW | Host tetikleyici | Kaynak: panik butonu geri sayımı açıkken ses tuşu/kutucuk tetiklenir ve abonelik o anda `verifiedFree` olursa paywall geri sayımın üstüne açılabilir (geri tuşuyla dönülür). | Çok dar. | `_openCountdown` başında `PanicCountdownGuard.isHeld` kontrolü önerilir; acil yol dosyası — ayrı inceleme. |
| A-06 | LOW | Bağlantı ↔ geri sayım | Kaynak: bildirim dokunuşuyla gelen hedef aktif bir `CountdownScreen`'in üstüne açılabilir (geri sayım altta sürer). | PIN tuş takımı geçici gizlenir. | Ürün kararı. |
| A-07 | LOW | Paywall ↔ kilit | security-reviewer: kilit, abonelik kapısı beklerken yükselirse kapının kendi paywall/uyarı yüzeyi kilidin üstünde görünebilir. Veri açığa çıkmaz. | Kozmetik. | — |
| A-08 | LOW | Yeniden park yarışı | İki ajan: `deferredByLock` ile kilidin inişi arasındaki mikro görev aralığında bağlantı bir sonraki dönüşe kadar parkta kalır. | Gecikmiş bağlantı, atlatma değil. | — |
| A-09 | LOW | Zaman çizelgesi | Kaynak: kimliksiz `logEvent` `id = millisecondsSinceEpoch` + `abort`; aynı ms'de iki kayıt ikincisini istisnayla düşürür. Siren/sahte arama/not çağrıları `catchError`'sız fire-and-forget. | Teorik (UI'dan aynı ms üretilemedi). | — |
| A-10 | LOW | Veri silme ekranı | `_deleting` bayrağı senkron `showResetDialog` yüzünden etkisiz. Cihazda çift dokunuşta mükerrer diyalog gözlenmedi `[KESİN]`. | — | — |
| A-11 | INFO | Panik + süreç ölümü | Kaynak: geri sayım sırasında Flutter süreci ölürse ARMED oturum için iptal arayüzü yeniden açılmaz; native son tarihte arar. | 10 sn pencere. | Tasarım; belgelenmeli. |
| A-12 | INFO | Siren + süreç ölümü | Siren çalarken süreç ölürse alarm sesi en yüksekte kalır (kalıcı geri yükleme yok). | — | — |
| A-13 | INFO | Bildirim kanalları | `[KESİN]` logcat: kanallar katalogdan önce ASCII yedek metinle oluşturuluyor; sonra doğru Türkçe ile güncelleniyor (sistem ayarlarında doğrulandı). | — | — |
| A-14 | INFO | Dışa aktarma | `[KESİN]` gerçek JSON: PIN/anahtar yok, Türkçe karakterler ham UTF-8, geçici dosya paylaşımdan sonra siliniyor. Kişi kayıtlarında `isPrimary` yok; zaman damgalarında saat dilimi yok; onay kaydında `consentTextHash` boş. | Taşınabilirlik/kanıt zayıflığı. | Hukuk/ürün. |
| A-15 | INFO | Ölü kod | `ConsentScreen` hiçbir yerde kurulmuyor (await sonrası `mounted`'sız `setState` içeriyor, erişilemez). `consent_management_screen.dart:87` modal diyalog sonrası — pratikte güvenli. | — | Silme öncesi `audit_absence_claims_gate` (hafıza notu). |
| A-16 | INFO | Göç v2 mesajı | "secure storage reset" yazıyor ama yalnız `pref_pin_setup_done=false`; PIN varsa `MainNavigation` düzeltiyor. Veri kaybı yok. | Yanıltıcı log. | — |
| A-17 | INFO | API matrisi | Yalnız API 35 imajları kurulu. API 29/36 `KANITLANMADI` (imaj indirmek açık izin ister). | — | Sahip onayıyla indirilebilir. |

## 3. Test geçerliliği (§36) — yanlış güven veren testler

- `EmergencySessionReferenceModelTest`: üretim koordinatörünü **hiç çağırmıyor**; oyuncak modeli kendine karşı test ediyor. → Yerine üretim koordinatörü üzerinde iç içe geçme testi eklendi (240 000 adım, 5 mutant düşürüyor).
- `startup_pin_boundary_test`: `restartStartup`'ı yalnız AppRoot içinden çağırıyordu (K-02'yi kaçırdı).
- `state_restoration_policy_test` / `forgot_pin_reset_route_test`: kaynak-metni testleri; davranışı değil dizgeyi sınıyor.
- `deep_link_test` "LOCKED": yalnız açılış kilidini düşünüyordu (K-01'i kaçırdı).
- `countdown_accessibility_test` Test Modu kontrolleri: tuş takımı hiç çizilmediği için boş geçiyordu (K-06).
- Yeni testlerde: her düzeltme geri alınınca ilgili testin düştüğü tek tek doğrulandı (mutasyon); sabit gerçek-zaman beklemeleri sınırlı yoklamaya çevrildi.

## 4. Native durum makinesi (§12–15) — kaynaktan

| Geçiş | Çağıran | Ön koşul | Kalıcı yazım | Hata davranışı | İdempotans / kurtarma |
|---|---|---|---|---|---|
| — → PREPARING | `arm` (Dart) | protokol, randomId, nesil=1, geçerli son tarihler, aranabilir hedef, yetenekler (entitlement AUTHORIZED, PIN, CALL_PHONE, exact alarm, bildirim, HIGH kanal); slot PREPARING/ARMED/CLAIMED değil | PREPARING | yazım hatası → `Unknown(preparingCommitFailed)`, alarm yok | aynı randomId+son tarih+hedef+nesil → mevcut `Armed` |
| PREPARING → ARMED | `arm` | exact alarm kabul | ARMED | exact red → CANCELLED (hedef boş) + `Rejected`; ARMED yazımı hatası → alarm iptal, `Unknown`; PREPARING dispatch edilemez | reboot'ta PREPARING → CORRUPTED |
| ARMED → ARMED (nesil+1) | `arm` (revizyon) | aynı tür ve hedef (değişmez), nesil+1 | yeni ARMED, sonra eski alarm iptal | zamanlama hatası → `Rejected`, eski oturum kalır | eski nesil alarmı/dispatch'i etkisiz |
| PREPARING/ARMED → CANCELLED | `cancel` (PIN) | token eşleşir | hedef boş mezar taşı | yazım hatası → `Unknown`; CLAIMED+ → `TooLate` | `AlreadyCancelled` |
| ARMED → CLAIMED | `claimAndDispatch` (Dart son tarih, alarm alıcıları, reconcile) | token eşleşir, duvar saati ≥ final | CLAIMED | yazım hatası → `notAttempted(ARMED)` | ikinci çağıran terminal sonucu okur |
| CLAIMED → SUBMITTED_UNCONFIRMED / MANUAL_ACTION_REQUIRED / REQUEST_FAILED | `claimAndDispatch` | yedek bildirim, sonra Telecom | terminal (+ redakte günlük atomik) | terminal yazımı hatası → CLAIMED kalır; süreç içi `submittedInProcess` mükerreri engeller; yan etki yoksa tek 5 sn yeniden deneme | süreç ölümünden sonra yeniden dispatch: **belgelenmiş en-az-bir-kez penceresi** |
| ARMED/CLAIMED → MANUAL/FAILED (öneri) | `reconcile*` | duvar saatiyle > 5 dk gecikmiş (K-04 sonrası: TIME_SET'teki takılı yolda monotonik) | terminal, çağrı yok | bildirim gönderilemezse REQUEST_FAILED | — |
| herhangi → temiz | `wipe` | CLAIMED yoksa | PREPARING/ARMED → CANCELLED, sonra `clearAll` | CLAIMED → `TOO_LATE`; `clearAll` hatası → `UNKNOWN` | — |

İç içe geçme testiyle `[KESİN]` (JVM, sahte saatler): süreç ömrü başına ≤1 istek; terminal/iptal sonrası arama yok; iki saate göre de erken arama yok; CANCELLED zarfında hedef yok; nesil geri gitmez; hatasız TIME_SET'ten sonra monotonik olarak süresi dolmuş ARMED kalmaz. Gerçek AlarmManager/Telecom/Doze/OEM davranışı **cihaza özgü**, bu ortamda `KANITLANMADI` (önceki emülatör kayıtları: `device-verification-2026-09-13-native-doze.md`, `-force-stop.md`, `-2026-09-20-overdue-dispatch.md`).

## 5. Bölüm bazında kısa durum

- §6 reset: K-02 düzeltildi; depolama incelemesi `[KESİN]` (güvenli depolama boş, native oturum deposu boş, DB/dosyalar silindi, park edilmiş hedef temizlendi).
- §7 siren: K-07 (deterministik); cihazda normal geri yükleme `[KESİN]`, yarış penceresi cihazda yakalanamadı.
- §8 bağlantı+kilit: K-01; deterministik 5 test + cihaz.
- §9 geri sayım kilidi: kaynak yeniden denetlendi (çıkış yollarının hepsinde serbest; await boyunca tutulmuyor); A-05/A-06 kaldı. Kilidin süreç içi gözlemi 10x kararlılık koşusunda.
- §10 son tarih: K-03; rastgele sınır testleri; gecikme ölçüldü (<1 tik).
- §11 native geçmiş: kaynak + testler: kimlik oturum anahtarından (`ignore`), onay ancak başarılı yazımdan sonra, katalog yoksa tüketilmez, 5 sn sonra beklemede kalır. `[KESİN]` (birim) — gerçek DB içeriği cihazda bu turda sorgulanmadı.
- §16 izinler (cihaz, kısmi): CALL_PHONE geri alındığında süreç Android tarafından öldürüldü, yeniden açılışta çökme yok, kart "İzin verilmedi — acil durumda dialer açılacak"; konum reddi: harita "Konum alınamadı", çökme yok. Exact alarm/bildirim reddi panik arm'ını reddeder (kaynak + mevcut testler); Pro olmadan cihazda arm denenemedi `KANITLANMADI`.
- §17/§18: `setState`-after-`await` taraması 4 aday → 2 yanlış pozitif, 2 düşük (A-15). 198 geniş catch; acil yol dosyalarındakiler tek tek incelendi: hiçbiri hata durumunu başarı/varsayılan olarak döndürmüyor (fail-closed veya kalıcı yeniden deneme).
- §20 temiz kurulum `[KESİN]`: onay (Devam boşken etkisiz) → karusel → geçersiz numara reddedildi → kişi → kişi rızası → PIN (geri tuşu tüketiliyor) → izin → pil → ana ekran; onboarding ortasında yeniden başlatma onboarding'e döndü.
- §23 abonelik: kaynak; geç çapa okuması doğrulanmış yanıtı ezemiyor, `denied` çapayı bekleyerek siliyor; yeni kusur yok. Play sandbox `KANITLANMADI`.
- §27 dışa aktarma: A-14. §28 silme: §6.
- §29 release: smoke release'de K-02 doğrulandı; FLAG_SECURE (ekran görüntüsü siyah) önceki kayıtla tutarlı.
- §31 metin: TR/EN parite ve anahtar kullanım testleri yeşil; A-04, A-13.
- §32 büyük yazı (2.0x): K-06 bu sırada bulundu; diğer kritik ekranlar mevcut `layout_size_matrix` / metin ölçeği testleriyle.
- §34 "Etkinlikleri tutma": arka plan → dönüş, sekme korundu, 0 hata `[KESİN]`.
- §35 API matrisi: A-17.
- §37 mutasyon: 7/7 öldürüldü; her mutant için orijinal hash, enjekte hash (farklı), geri yükleme hash'i eşit, Flutter + native taban çizgileri yeşil `[KESİN]` (kanıt alanları `cc2fdd6` ile eklendi).
- §38 kararsızlık: kritik set 10x + ayrıntılı 8x + yük altında 6x×2: tek kararsız test K-09 (düzeltildi).
- §39 logcat: ANR (A-01), `device_integrity_unknown` (emülatörde beklenen), eksik anahtar uyarıları (A-13); başka istisna yok.
- §41 güvenlik: `allowBackup=false`, `fullBackupContent=false`, `usesCleartextTraffic=false`, dışa açık yalnız `MainActivity` ve izinle korunan `PanicTileService` (kaynak manifest; birleşik manifest §7'de).

## 6. Ek düzeltme — güvenli depo `resetOnError` (K-11, HIGH)

Doğrulama zinciri sırasında bulundu: `flutter_secure_storage` 10.0.0'da `AndroidOptions()` varsayılanı `resetOnError = true` (eklentinin kendi doküman yorumu "Defaults to false" diyor). Her şifre çözme/Keystore hatasında eklenti kaydı silip `null` döndürüyordu; uygulamanın okunamayan PIN, kişi listesi ve kilit sayacı için kurduğu fail-closed yolları hiç çalışmıyordu.

- Yeniden üretim `[KESİN]` (`cc2fdd6`): `user_pin` şifreli metninde 1 bayt → `AEADBadTagException` → "Attempting to delete corrupted data" → PIN silindi → uygulama kilit yerine **"Güvenlik PIN'i Belirleyin"** açtı (PIN'i bilmeyen biri yeni PIN belirleyip uygulamaya ve geri sayım iptaline erişebilir).
- Düzeltme `09b9004`: iki örnekte `AndroidOptions(resetOnError: false)`.
- Doğrulama `[KESİN]`: aynı bozulmada "Güvenli başlatma tamamlanamadı — PIN güvenli depodan okunamadığı için uygulama kilitli tutuluyor" (Yeniden Dene / Yerel Verileri Sıfırla); depodan kayıt silinmedi; geçerli veriyle normal kilit açma çalıştı. Test: `secure_storage_reset_on_error_test` (kanal sınırında seçenek).
- Kalan risk: kalıcı bir Keystore hatasında kullanıcı artık bilinçli sıfırlamaya yönlendirilir (veri kaybı açık onayla). Eklenti algoritma göçü başarısız olursa da veri silinmez, hata yüzeye çıkar.

## 7. Tam doğrulama (§48) — son kod commit'i `09b9004`

| Kapı | Sonuç | Kanıt |
|---|---|---|
| `scripts/verify_release.sh` (flutter clean + pub get dahil) | **EXIT=0**, 5/5 kod+smoke kapısı + etiketli yayın kapısı yerel PASS | analiz "No issues found"; **2125/2125 test**; `CRITICAL_COVERAGE_PASS` (koordinatör %100 sözleşme, platform servisi %97,1, check-in %94,4, kişi %93,1…); imzalı smoke AAB + `ANDROID_RELEASE_SURFACE_PASS` (birleşik manifest); `lintSmokeRelease` + Kotlin unit + `assemblePlayDebugAndroidTest`; 16 KB hizalama; SBOM lisans + THIRD_PARTY_NOTICES paritesi |
| CI aynası `flutter analyze --no-fatal-infos && flutter test` | yeşil | ayrıca koşuldu (2119 test, K-11 öncesi) |
| Kotlin birim (flutter clean sonrası taze) | **141/141**, 0 atlanan | `build/app/test-results/testPlayDebugUnitTest` |
| Enstrümantasyon (API 35) | **18/18** | `am instrument`, kurulu build `09b9004` kodu (lastUpdateTime 2026-10-07 18:43:59) |
| Commit başına | **12/12 commit** analiz + o commit'in testleri (+ Kotlin) yeşil | geçici worktree |
| Mutasyon (§37) | **7/7 KILLED**; `differs=true`, `restored=true`; taban çizgileri 0/0 | `scripts/run_safety_mutations.py` |
| Kararlılık (§38) | kritik set 10x + 8x + yük altında 6x×2 | tek kararsız test (K-09) giderildi |
| Gizli anahtar taraması | **PASS**, temiz ağaç `95f3362`: 1175 metin + 226 ikili, 0 bulgu | `scan_release_secrets.py --require-clean` |
| OSV | **PASS**, temiz ağaç `95f3362`: 195 pub + 203 Maven sorgusu, bilinen bulgu yok (OSV kapsam sınırları geçerli) | `audit_dependencies_osv.sh` |
| Format (§48 "format") | Uygulanmadı — **bilinçli**: depo politikası (`coding-style.md`, MP-27-003) toplu format'ı yasaklıyor; yalnız yeni dosyalar kendi biçiminde | — |

## 8. Güven ayrımı (§51)

| Boyut | Durum | Gerekçe |
|---|---|---|
| **CODE CONFIDENCE** | **PASS (koşullu)** | Bulunan 11 kusur düzeltildi ve iki bağımsız yöntemle doğrulandı; tam zincir yeşil. Açık: A-04 (onaylı küçük metin kusuru, sahip kopyası gerekli), A-02/A-01 (cihaza bağlı bilinmeyenler), A-03 (güvenlik semantiği kararı). |
| **DEVICE CONFIDENCE** | **UNKNOWN** | Tüm kanıt GMS'siz API 35 emülatöründe; gerçek SIM/Telecom, OEM pil yöneticileri, fiziksel Doze, açılış yayın sırası, GMS'siz cihazda harita yapılmadı. |
| **COMMERCE CONFIDENCE** | **UNKNOWN** | Play/RevenueCat sandbox satın alma/geri yükleme/iptal hiç denenmedi. |
| **RELEASE CONFIDENCE** | **FAIL** | Bu kod push edilmedi; `release.yml` imzalı Play AAB'si, CI koşusu ve Console adımları yok (önceki raporda P0-1, eksik secret'lar). |

## 9. Fiziksel cihaz devri (§52)

Cihazlar: **D1** Pixel (GMS, Android 15/16) · **D2** Samsung One UI · **D3** Xiaomi HyperOS (mümkünse GMS'siz Çin ROM'u) · gerçek SIM + aramayı karşılayacak ikinci telefon. Her satır için kaydedilecek: cihaz/OS · build ve versionCode · commit (`git rev-parse HEAD`) · yükleyici (`adb shell pm list packages -i com.poyrazoncel.korubeni`) · `dumpsys package … | grep lastUpdateTime` · izin durumu (`dumpsys package … | grep granted`) · pil durumu (`dumpsys deviceidle`, OEM pil modu) · beklenen · gözlenen · log (`adb logcat -d` + `dumpsys activity exit-info`) · P/F.

| # | Senaryo | Beklenen |
|---|---|---|
| H-1 | Panik ön planda | 10 sn sonra arama isteği; "bağlandı" iddiası yok; dialer açılmaz (K-03) |
| H-2 | Panik, ekran kilitli | native alarmla istek |
| H-3 | Panik + `dumpsys deviceidle force-idle` | `setExactAndAllowWhileIdle` teslimi |
| H-4 | Panik, Flutter süreci öldürülmüş (son uygulamalardan kaydırma / OEM öldürme) | alıcı → `claimAndDispatch` |
| H-5 | Panik PIN iptali (10 sn içinde) / CLAIMED sonrası iptal | arama yok / "çok geç" yüzeyi, mükerrer yok |
| H-6 | Check-In süresi → grace uyarısı → arama; PIN ile revizyon | eski nesil alarm etkisiz |
| H-7 | Safe Walk ön uyarı (120 sn) → grace → arama; PIN iptali | |
| H-8 | Check-In sırasında yeniden başlatma (≤5 dk / >5 dk) + `dumpsys activity broadcasts history \| grep -E "TIME_SET\|LOCKED_BOOT"` | ≤5 dk ara, >5 dk öner; **A-02 için TIME_SET'in LOCKED_BOOT_COMPLETED'dan sonra geldiğini kaydet** |
| H-9 | **D3 GMS'siz**: Harita sekmesi + konum izni ver/ret | ANR yok (A-01) |
| H-10 | Check-In son tarihine ~1 sn kala saati elle geri al | istek gider (K-04) |
| H-11 | Exact alarm izni kaldırılmış / bildirimler kapalı / CALL_PHONE reddi | arm reddi + yönlendirme; çökme yok |
| H-12 | Çift SIM "her seferinde sor" | SIM seçici davranışını kaydet (P1-7) |
| H-13 | Hızlı Ayarlar / widget / ses tuşu paniği | maskeli kişi, tek geri sayım |
| H-14 | >2 dk arka plan → kilit → bağlantı/bildirim dokunuşu | kilit üstte; PIN sonrası hedef (K-01) |
| H-15 | Profil ve Verilerimi Sil ile sıfırlama → son uygulamalardan kaydır → aç | onay ekranı, hata ekranı yok (K-02) |
| H-16 | Ekran kilidi değiştir / OS güncellemesi sonrası aç | PIN okunamazsa fail-closed kurtarma, sessiz silme yok (K-11) |
| H-17 | Siren başlat-durdur (hızlı dahil) | alarm sesi eski seviyeye döner (K-07) |
| H-18 | Yazı tipi %200 + Test Modu ve gerçek geri sayım | PIN tuş takımı erişilebilir (K-06) |
| H-19 | Force-stop sırasında oturum; >5 dk sonra aç | arama yok, öneri bildirimi |
| H-20 | Düşük RAM cihazda iptal PIN'i (PBKDF2 100k), 30 deneme | medyan/p95 kaydet |
| H-21 | Play sandbox: satın alma, geri yükleme, iptal, süre dolumu, çevrimdışı açılış | Pro kapısı UI ve native ile tutarlı |



## 10. Nihai karar (§50)

## CODE NOT READY

Kural gereği: doğrulanmış ve çözülmemiş bir kod kusuru kaldı — **A-04** (kişi kayıtlıyken hazırlık kartının "Önce acil kişini ekleyelim" demesi). Kusur LOW ve güvenlik akışını etkilemiyor, ancak doğru metin yeni kopya istiyor ve CLAUDE.md kural 4 gereği sahip onayı olmadan değiştirilmedi. Bunun dışında kod tarafında bilinen açık kusur yok; kalanlar cihaza bağlı bilinmeyenler (A-01, A-02) ve sahip kararları (A-03).

Önceki "CODE READY" kararı **çürütüldü**: o karar sırasında koddaydı ve bu turda düzeltildi — bir PIN atlatması (K-01), bir Keystore hatasında PIN kapısının açılması ve verinin sessizce silinmesi (K-11), süreç ölümünde çöken veri silme (K-02), nadir mükerrer arama yolu (K-03), takılı kalabilen native oturum (K-04), haritanın izinsiz üçüncü taraf trafiği (K-05), bozuk prova (K-06), siren ses yarışı (K-07), 16/18 enstrümantasyon (K-08) ve kararsız bir test (K-09).

## 11. En son soru (§53)

> "Bu kodu bugün gerçek kullanıcıların telefonuna göndermemizi engelleyen KOD KAYNAKLI herhangi bir sorun veya bilinmeyen kaldı mı?"

**EVET.**

1. **A-02 — bilinmeyen (native, önceden var):** açılışta TIME_SET'in `reconcileAfterBoot`'tan önce işlendiği bir cihazda süresi dolan oturum çok geç aranabilir. Kod bunu sırayla varsayıyor; gerçek cihazlardaki sıra ölçülmedi (H-8).
2. **A-01 — bilinmeyen (cihaza bağlı):** Google Play hizmetleri olmayan cihazlarda konum yolu ana iş parçacığında system_server'a binder çağrısı yapıyor; emülatörde system_server takılınca uygulama ANR oldu. Gerçek GMS'siz cihazda doğrulanmadı (H-9).
3. **A-03 — güvenlik semantiği kararı:** K-04'ün açtığı dar yolda Check-In/Safe Walk grace uyarısı olmadan aranabilir; öneri mi arama mı, sahip karar vermeli (**SAFETY SEMANTIC BLOCKER**, §46).
4. **A-04 — doğrulanmış küçük metin kusuru:** sahip kopyası gerekli (kural 4).
5. **Cihaz davranışları kanıtlanmadı:** gerçek SIM/Telecom, kilitli ekranda çağrı, OEM pil yöneticileri, fiziksel Doze, çift SIM. Bunlar bu ortamda doğrulanamaz; §9 listesi deterministik devir içindir.

Testlerin yeşil olması bu cevabın gerekçesi değildir: bu turdaki kusurların çoğu yeşil bir paketin içinde, ilgili davranışı hiç sınamayan testlerin yanında duruyordu (§3).
