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
