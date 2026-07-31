# Panik butonu ↔ abonelik/ağ bağımlılığı

> Tarih: 2026-07-31 · Dal: `codex/release-hardening-100` @ `877b3fe`
> Kapsam: GÖREV 4 ölçümü. **Bu belge kaynak analizidir, cihaz kanıtı değildir.**
> Cihaz bölümü aşağıda boş bırakıldı; gerçek cihaz + gerçek Pro satın alma gerektiriyor.
> **Bu aşamada kod değişmedi** (CLAUDE.md kural 5).

## Soru

Ödemiş bir Pro kullanıcı, ağ yokken/zayıfken panik butonunu kurabiliyor mu?

## Yanıt: HAYIR — kuramıyor. Zincir koddan kesin izlenebiliyor.

| # | Adım | Dosya |
|---|---|---|
| 1 | `PremiumFeature.panic` = PRO (ücretsiz değil) | `lib/core/constants/feature_access_matrix.dart` |
| 2 | Basışta `await SubscriptionGate.ensureAccess(context, PremiumFeature.panic)` | `lib/widgets/panic_button.dart:107` |
| 3 | `ensureAccess` → `provider.resolveAccess()` | `lib/core/services/subscription_gate.dart:46` |
| 4 | Durum `uninitialized`/`loading` değilse **her yeni arm'da** `refresh()` | `lib/presentation/providers/subscription_provider.dart:204` |
| 5 | `refresh()` → `_rcService.getCustomerInfo()` | `subscription_provider.dart:187` |
| 6 | Ağ yok → `Purchases.getCustomerInfo()` `PlatformException` atar → yakalanır → **`null` döner** | `lib/core/services/revenue_cat_service.dart:208-219` |
| 7 | `null` → `_setAccess(_access.markUnavailable())` | `subscription_provider.dart:189-192` |
| 8 | `markUnavailable()` `lastVerifiedPro`'yu **korur**, `status`'ü `unavailable` yapar | `lib/core/services/subscription_access_state.dart:60-63` |
| 9 | `entitlementDecision`: `unavailable` → `_ =>` dalı → **`unknown`** | `subscription_access_state.dart:26-30` |
| 10 | `canUsePaidSafetyFeature` = `authorized && lastVerifiedPro == true` → **`false`** | `subscription_access_state.dart:33-35` |
| 11 | `shouldShowPaywall` = `verifiedFree && ...` → `false` | `subscription_access_state.dart:41-43` |
| 12 | Sonuç: `showEntitlementUnverified()` → snackbar, `return false` → **buton kurulmaz** | `subscription_gate.dart:56-62` |

8. adım kritik: `lastVerifiedPro == true` bilgisi **elde duruyor** ama 9-10. adımlar onu
kullanmıyor. Yani "bu kullanıcının Pro olduğunu biliyoruz" ile "yeni oturum açabilir"
arasındaki bağ, ağ hatası anında bilerek koparılıyor.

## Aynı kapının iki SESSİZ kullanımı (buton'dan daha kötü)

Panik butonu en azından snackbar gösteriyor. Şu iki yol hiçbir şey göstermiyor:

- `lib/core/widgets/emergency_trigger_host.dart:107` — **ses tuşu panik tetikleyicisi**.
  `canUsePaidSafetyFeature` false ise dinleyici hiç başlatılmıyor ve `return` ediliyor.
  Kullanıcı ayarında tetikleyici "açık" görünmeye devam ediyor. Yani kullanıcı ses
  tuşunun kurulu olduğunu sanıyor; kurulu değil.
- `lib/core/widgets/emergency_trigger_host.dart:200` — `_openCountdown` içinde aynı
  kontrol, yine sessiz `return`.

## Zaman sınırı: TANIMSIZ

`subscription_gate.dart`, `subscription_provider.dart`, `revenue_cat_service.dart`,
`panic_button.dart`, `emergency_trigger_host.dart` — **beşinde de tek bir `.timeout(` yok.**

Uçak modunda platform kanalı hızlı hata verir; asıl tehlikeli durum **zayıf sinyal**
(tek çubuk, captive portal, dolu hücre): `Purchases.getCustomerInfo()` uygulama
tarafından sınırlanmamış bir süre bekler. Panik butonunun basıştan sonra kaç saniye
sessiz kalacağı şu an tanımlı değil. Sinyal kaybı tehlikeyle **ilintilidir** (kırsal,
bodrum, kapalı otopark) — yani bu, en kötü anda devreye giren bir gecikme.

## Neden CRITICAL

`.claude/rules/common/code-review.md`: "acil çağrıyı engelleyebilecek veya
geciktirebilecek her şey tanımı gereği CRITICAL". Bu ikisini de yapıyor.

## Cihaz doğrulaması — YAPILMADI

Aşağıdaki adımlar gerçek cihaz + gerçek Pro satın alma istiyor; bu oturumda koşulamadı.
Sonuç geldiğinde bu bölüm doldurulacak.

1. Gerçek cihazda Pro satın al, Pro'nun aktif olduğunu doğrula.
2. Uygulamayı tamamen kapat (arka plandan da kaldır).
3. Uçak modunu aç.
4. **10+ dakika bekle** (RevenueCat cache 5 dk; erken deneme cache'ten yeşil dönebilir).
5. Uygulamayı aç, panik butonuna uzun bas. Ekranı ve süreyi kaydet.
6. Ayrıca **zayıf sinyalle** (uçak modu değil) tekrarla ve basıştan tepkiye geçen
   süreyi ölç — asıl ölçülmek istenen bu.

| Alan | Sonuç |
|---|---|
| Cihaz / Android sürümü | _(doldurulacak)_ |
| Uygulama sürümü / build | _(doldurulacak)_ |
| Uçak modu: buton kuruldu mu? | _(doldurulacak)_ |
| Uçak modu: basıştan tepkiye süre | _(doldurulacak)_ |
| Zayıf sinyal: basıştan tepkiye süre | _(doldurulacak)_ |
| Ses tuşu tetikleyicisi çalıştı mı? | _(doldurulacak)_ |

---

## Denenen düzeltme GERİ ALINDI (2026-07-31)

`614bcda` ile 7 günlük çevrimdışı tolerans penceresi + 1800 ms timeout denendi ve
`d.` güvenlik incelemesi sonrası **geri alındı**. Sebep: düzeltme yanlış katmanda
duruyordu ve iki çağrı yerini kötüleştiriyordu.

### Neden çalışmadı

`SubscriptionGate.ensureAccess` yalnızca **bir bool** döndürüyor. Ama gerçek arm
yetkisi başka bir yerde, bağımsız olarak ikinci kez sorgulanıyor:

- `lib/widgets/panic_button.dart:206-219` — `ensureAccess` döndükten sonra
  `provider.entitlementDecision` **yeniden okunuyor** ve `authorized` olması
  şart koşuluyor. Tolerans yolunda `allowed == true` ama karar hâlâ `unknown`,
  dolayısıyla fonksiyon yine erken dönüyor. **Buton yine kurulmuyordu.**
- `lib/screens/countdown_screen.dart` — `entitlementDecision` parametresi ham
  hâliyle geçiyor ve native alarm planlaması `authorized` istiyor.
- `android/.../EmergencySessionModels.kt` — native katman da aynı kuralı
  bağımsız uyguluyor (`entitlementUnknown` reddi).

### Neden GERİLEME yarattı

`emergency_trigger_host.dart:107` ve `:200` önceden entitlement çözülemeyince
sessizce hiçbir şey yapmıyordu. Değişiklikten sonra `CountdownScreen` açılıyor,
orada arm reddediliyor ve kullanıcı **manuel arama düğmesi olmayan** bir
"tam başarısızlık" diyaloğuyla baş başa kalıyordu. Sessiz hiçbir şey yapmamak,
çıkışsız bir hata diyaloğundan iyidir.

### İkinci bulgu: anchor kimliği doğrulanmamış

`withRestoredProAnchor`, yalnızca SharedPreferences'taki bir tamsayının
varlığından `lastVerifiedPro = true` **üretiyordu**. Hiç satın alma yapmamış
bir kullanıcı, tek bir int yazarak tolerans yoluna girebilirdi. Saat kontrolü
bunu engellemez: hem yazma hem okuma aynı güvenilmeyen cihaz saatini kullanıyor.

### Gerçek düzeltme neyi gerektirir

Tolerans kararı `bool` seviyesinde değil, **`EntitlementDecision` seviyesinde**
verilmeli ve üç katmanın (Dart gate, `CountdownScreen`, native Kotlin) hepsi
aynı kararı görmeli. Yani:

1. Tolerans içindeyken `entitlementDecision`'ın `authorized` dönmesi (ya da
   native sözleşmeye yeni bir "graceAuthorized" durumu eklenmesi).
2. `EmergencySessionModels.kt` içindeki `rejectionReason()` sözleşmesinin
   buna göre güncellenmesi — bu bir native sözleşme değişikliğidir.
3. Anchor'ın tek başına `lastVerifiedPro` üretmemesi.
4. `test/screens/safety_session_callsite_contract_test.dart` bu ikinci kapıyı
   zaten pinliyor; değişiklik o sözleşmeyi bilinçli olarak güncellemeli.

Bu, tek bir dosyalık bir yama değil; üç katmanlı bir sözleşme değişikliği.
Yayın öncesi kapsamda yapılıp yapılmayacağı ayrı bir karar.

---

## Düzeltme (ikinci deneme) — kaynakta çözüldü

Onaylanan yaklaşım: toleransı `bool` seviyesinde değil, **`EntitlementDecision`'ın
kaynağında** çöz. `SubscriptionAccessState.entitlementDecision` artık mağaza yanıtı
`unknown` iken tolerans penceresini de hesaba katıyor ve `authorized` dönüyor.

Bunun sonucu, ilk denemede eksik kalan üç katmanın **tek noktadan** düzelmesi:

| Katman | Aldığı değer |
|---|---|
| `panic_button.dart:206-219` ikinci kapı | `authorized` → geçiyor |
| `CountdownScreen(entitlementDecision:)` | `authorized` |
| native `EmergencySessionModels.kt` `rejectionReason()` | wire'da `"authorized"` |

**Native kod, wire protokolü ve enum değişmedi.** `EntitlementDecision`'a yeni bir değer
eklemek (`graceAuthorized`) gerekmedi; o yol `fromWire`, kalıcı oturum geri okuması ve
Kotlin tarafını da değiştirmeyi gerektirirdi.

Mağazanın gerçekten ne dediği kayboldu mu? Hayır: ham değer
`verifiedEntitlementDecision` olarak ayrı duruyor ve `unknown` demeye devam ediyor.

### Güvenlik incelemesinin diğer bulguları da kapatıldı

- **B (CRITICAL)** — `withRestoredProAnchor` artık tek başına `lastVerifiedPro`
  ÜRETMİYOR. Anchor yalnızca, sadece doğrulanmış Pro'da yazılan
  `priorProInitializationHintKey` ile birlikte geçerli. Bu kurcalamayı imkânsız kılmaz
  — sunucusuz bir mimaride kılınamaz — ama tek bir tamsayı yazmayı yetersiz kılar ve
  pencere yine kendiliğinden doluyor.
- **C (MEDIUM)** — `_applyCustomerInfo` awaitable yapıldı; `verifiedFree` yanıtında
  anchor silme artık **await ediliyor** (SDK callback'i hariç, orada await edilecek bir
  yer yok). Süreç ölümü bayat anchor'ı diriltemiyor.
- **D (MEDIUM)** — `ensureOfflineGraceLoaded()` kendi 400 ms bütçesine alındı; ağ
  bütçesinden ayrı, çünkü ağ zaten başarısızken atlanmamalı.
- **E (LOW)** — anchor okuma/yazma hataları artık ayrı `LocalErrorCode` değerlerinde.

### Bilinçli kapsam kararı

Tolerans **tüm Pro özelliklerini** kapsıyor, sadece paniği değil: `entitlementDecision`
tek kaynak olduğu için Safe Walk ve check-in de aynı pencereden yararlanıyor. Bunlar da
güvenlik özellikleri ve sinyalsizken tutarsız bir uygulama sunmak istemedik.

### Hâlâ cihazda doğrulanmadı

Yukarıdaki cihaz tablosu boş kalmaya devam ediyor. Düzeltme birim testleriyle kanıtlı
ama gerçek cihazda gerçek Pro satın almayla ölçülmedi.
