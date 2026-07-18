# KoruBeni — Kod Tabanı Denetimi (Araştırma Notları & Hipotez Ağacı)

> Canlı çalışma dosyası. Kanıt topladıkça güncellenir. Amaç: şeffaflık + kalibrasyon.
> Tarih: 2026-06-25 · Dal: `feat/contacts-secure-at-rest`
> Kapsam: mevcut kodun denetimi (#2 anlama/refactor, #3 debug, #5 performans, #6 temiz mimari).
> **Kural:** Bu aşamada KOD DEĞİŞMEZ. Önce bulgu + plan + onay (CLAUDE.md kural 5). UI/tema dokunulmaz (kural 4).

## Kaynak güvenilirlik sıralaması (birincil → ikincil)
1. **Kodun kendisi** (`lib/**`) — en yüksek güven, çalışan gerçek.
2. **Git geçmişi** (`git log`, churn) — niyet ve değişim baskısı sinyali.
3. **Resmi dokümanlar** (Flutter/paket, Context7) — davranış doğrulaması.
4. Proje kuralları (`.claude/rules/**`, `CLAUDE.md`) — projenin kendi standardı (uyum ölçütü).
5. Hafıza notları (`memory/**`) — geçmiş kararlar; "yazıldığı anda doğruydu", kodda teyit şart.

Her önemli iddia ≥2 bağımsız kaynakla doğrulanır. Çelişki olursa kod > doküman > hafıza.

## Ölçülen metrikler (birincil kaynak: kod, 2026-06-25)
| Metrik | Değer | Not |
|---|---|---|
| Dart dosya / satır | 125 / ~28.7k | sadece Android hedefi |
| Test dosyası | 147 | oran iyi görünüyor (derinlik ayrı incelenecek) |
| >800 satır dosya | 5 (home 1280, countdown 1189, contacts 1184, map 857, settings 762) | proje sınırı 800 — ihlal |
| 600–800 satır | ~9 ek dosya | fake_call 720, contact_service 726, unified_consent 697, panic_button 661, emergency_call 642, paywall 636, safety_timeline 635, check_in 627, safe_walk 621 |
| bare `catch (e)` | 117 | proje Dart kuralı: yasak |
| bare `catch (_)` | 61 | " |
| typed `on X catch` | 31 | toplam catch'in ~%15'i tipli |
| relative import | 359 | proje kuralı: sadece `package:` — ihlal |
| `package:` import | 313 | |
| StatefulWidget | 38 | |
| `setState(` | 112 | |
| `mounted` guard | 216 | async-gap koruması yaygın (olumlu) |
| `late` | 49 | kural: mümkünse kaçın |
| `!` bang | ~36 | kural: mümkünse kaçın |
| TODO/FIXME | 0 | işaretleyici yok |

## Churn ↔ boyut sıcak noktaları (risk = boyut × değişim)
| Dosya | Satır | Son ~300 commit'te değişim |
|---|---|---|
| `screens/countdown_screen.dart` | 1189 | 44 ⬅ en riskli |
| `screens/contacts_page.dart` | 1184 | 33 |
| `screens/settings_page.dart` | 762 | 31 |
| `screens/home_page.dart` | 1280 | 31 |
| `main.dart` | 270 | 30 |
| `core/constants/app_constants.dart` | 102 | 29 |
| `screens/safe_walk_screen.dart` | 621 | 22 |
| `screens/map_page.dart` | 857 | 22 |
| `widgets/panic_button.dart` | 661 | 18 |

---

## Hipotez Ağacı (güven seviyeleri kalibre edilir)

### H1 — Yarım kalmış mimari göçü (DUAL ARCHITECTURE) · güven: 0.90
İki mimari yan yana yaşıyor: **eski** (`lib/screens`, `lib/services`, `lib/widgets`, `lib/models`, `lib/constants`) + **yeni temiz** (`lib/core`, `lib/data`, `lib/domain`, `lib/presentation`).
- Kanıt-1 (kod): dizin envanteri + her iki kümede de canlı dosyalar.
- Kanıt-2 (kod): `service_locator.dart` yeni katmanı kayıt ederken `services/consent_manager.dart` (eski) da singleton kaydediyor — ikisi karışık.
- **Rakip hipotez H1-alt:** Bu kasıtlı, ilerleyen bir "strangler fig" göçü. → Karşı kanıt: son commit'ler göçü ilerletmiyor, mevcut iki yolu yamalıyor; her iki yol da aktif. Güven (kasıtlı-ilerliyor): 0.2.

### H2 — "Temiz" katman monolitin önünde ince FACADE · güven: 0.80 → (doğrulanacak)
`ContactsLocalDataSource` (data katmanı) 726-satırlık `ContactService`'i import ediyor → repository soyutlaması gerçek ayrışma sağlamıyor, sadece dolaylama ekliyor. Aynı veri deposuna iki erişim yolu:
  - UI → Provider → `ContactsRepository` → `ContactsLocalDataSource` → **ContactService** (countdown_screen, home_provider, check_in_service)
  - UI → **ContactService** doğrudan (panic_button ⚠️, check_in_screen, safe_walk_screen, app_reset, user_data_export, main.warmUp)
- Kanıt-1 (grep): importer listeleri (yukarıda).
- Kanıt-2: `contacts_local_datasource.dart` okunacak (DELEGASYON teyidi). ⏳

### H3 — Üç state-yönetim paradigması yan yana · güven: 0.85
`provider`/ChangeNotifier (5 provider) + statik singleton servisler (`.instance`, `ContactService` static) + 112 `setState`/38 StatefulWidget. Tek bir akış yok.
- Kanıt-1: `providers.dart` (5 ChangeNotifierProvider).
- Kanıt-2: metrikler (112 setState, statik servisler).

### H4 — Hata yönetimi gözlemlenebilirliği düşük · güven: 0.88
178 bare catch vs 31 tipli catch. Projenin kendi Dart kuralını ("never bare catch") ve common kuralını ("never silently swallow") ihlal ediyor. Bazıları loglamadan yutuyor (örn. `main.dart` cold-start `catch (e) {}`).
- Kanıt-1 (kod): metrik + `main.dart:140`.
- Kanıt-2 (kural): `.claude/rules/dart/coding-style.md`.
- **Rakip hipotez H4-alt:** Bare catch'ler "asla çökme" (kural 3, offline-first) için bilinçli. → Kısmen geçerli; ama tipli-catch + log da aynı çökmezliği verir, gözlemlenebilirliği kaybetmeden. Güven (tamamı kasıtlı/iyi): 0.25.

### H5 — Import disiplini bozuk · güven: 0.95
359 relative import; proje kuralı "sadece `package:`" diyor. `main.dart`, `service_locator.dart`, `contacts_provider.dart` hepsi `../..` kullanıyor.
- Kanıt-1 (kod): metrik + okunan dosyalar. Kanıt-2 (kural): dart/coding-style.md.

### H6 — God-file + churn = en yüksek bakım riski · güven: 0.85
countdown_screen (1189/44), contacts_page (1184/33), home_page (1280/31) hem en büyük hem en çok değişen. Tek dosyada UI+iş mantığı+platform çağrısı karışımı varsayımı (doğrulanacak).
- Kanıt-1: boyut+churn tablosu. Kanıt-2: dosya içerikleri okunacak. ⏳

### H7 — Ölü/artık kod · güven: 0.55 → (doğrulanacak)
- `services/secure_storage_service.dart` (15 satır): hiçbir dosya import etmiyor → ölü? ⏳ okunacak.
- "kept-but-empty" DB tablosu (hafıza: emergency_contacts secure storage'a taşındı) — kasıtlı ama temizlenebilir.
- Kaldırılan özellik artıkları: location-session (`5e9d046`), medical profile (`170eb0b`) — kalıntı referans taraması yapılacak.

### H8 — Performans: geniş yeniden çizim · güven: 0.45 → (doğrulanacak)
Büyük StatefulWidget'lar setState ile tüm ağacı çiziyor olabilir; `map_page` marker/polyline yeniden üretimi; provider `notifyListeners` aşırı yayın. Henüz okunmadı.

### H9 — Emergency kritik yolda gizli bug riski · güven: 0.40 → (doğrulanacak)
Panik anında iki ayrı contact yolu + bare catch → yanlış/eksik kişiyle arama riski; `context`-after-`await`. `emergency_core_service` / `emergency_platform_service` / `panic_button` okunacak.

---

## Öz-eleştiri (yöntem)
- ⚠️ Metrikler kaba grep; bare-catch sayımı yorum içindeki "catch (e)" ifadelerini de sayabilir → spot-check yapılacak.
- ⚠️ "Ölü kod" iddiası reflection/string-tabanlı kullanım veya testlerden çağrıyı kaçırabilir → test dizini de taranacak.
- ⚠️ Henüz emergency kritik yol (ürünün kalbi) okunmadı; en yüksek öncelik orada olmalı, sadece kolay bulunan smell'lerde değil.
- ✅ İddialar kod + (kural|git|2. dosya) ile çiftleniyor.

## Evidence log
- 2026-06-25: Envanter, churn, main.dart, analysis_options, service_locator, providers.dart, contacts_provider.dart, importer haritaları, smell metrikleri toplandı.
- 2026-06-25 (tur 2): contacts_local_datasource, contacts_repository_impl, domain/contacts_repository, secure_storage_service, emergency_core_service, emergency_platform_service, consent_gate_service okundu; countdown/panic dispatch izi, contact_service API, test envanteri, ölü-kod & kaldırılan-özellik taraması, map_page perf sinyali alındı.

---

# DOĞRULAMA TURU 2 — Güncellenen güvenler & bulgular

## Hipotez sonuçları (kalibre edilmiş)
| Hipotez | İlk | Son | Sonuç |
|---|---|---|---|
| H1 dual architecture / yarım göç | 0.90 | **0.95** | DOĞRULANDI — baskın yapısal sorun |
| H2 temiz katman = monolit facade + domain→infra inversiyonu | 0.80 | **0.95** | DOĞRULANDI — bayrak gemisi refactor hedefi |
| H3 üç state paradigması | 0.85 | **0.85** | DOĞRULANDI |
| H4 hata-yönetimi gözlemlenebilirliği | 0.88 | **0.88** | DOĞRULANDI (nüanslı: platform katmanı örnek; bare catch'ler UI/servis/fallback'te) |
| H5 import disiplini | 0.95 | **0.95** | DOĞRULANDI |
| H6 god-file + churn = en yüksek risk | 0.85 | **0.90** | DOĞRULANDI — kritik dispatch mantığı 1189-satır widget'ta |
| H7 ölü kod | 0.55 | **0.30** | BÜYÜK ÖLÇÜDE ÇÜRÜTÜLDÜ — sadece `SecureStorageService` prod'da kullanılmıyor (ama testi var) |
| H8 performans büyük sorun | 0.45 | **0.25** | ÇÜRÜTÜLDÜ — tek marker, paralel cold-start, sınırlı rebuild |
| H9 emergency canlı bug | 0.40 | **0.20** | ÇÜRÜTÜLDÜ — idempotency guard + fallback + Doze alarm + timeout; risk yapısal, canlı değil |

## Düzeltmeler (öz-eleştiri / kalibrasyon)
- ❌→✅ `DeviceSecurityService` (splash kullanıyor) ve `LegalVersionChecker` (legal_texts kullanıyor) **ölü değil**. İlk "ölü kod" şüphem yanlıştı.
- ❌→✅ `medical*` (5 dosya) ve `locationShared` referansları **kasıtlı**: KVKK silme/temizleme yolu + Safe Walk'ın yeniden kullandığı enum (hafıza notuyla uyumlu). Artık değil.
- ❌→✅ `ConsentGateService` `ConsentManager`'a delege ediyor → **mantık tekrarı değil**, manager üzerinde ince UI kapısı. Sadece eski/yeni dizine bölünmüş (H1 semptomu).
- ✅ Çekirdek (emergency dispatch + platform + storage) sağlam ve iyi test edilmiş. Sorunlar YAPISAL/bakım kaynaklı, üründe canlı arıza değil.

## Doğrulanmış kritik yol (ürünün kalbi)
`panic_button._openCountdownScreen()` → `Navigator.push(CountdownScreen)` → `CountdownScreen._executeEmergency()`:
1. `_contactsRepository.getAllEmergencyNumbers()` ile numaralar alınır (primary önce).
2. `EmergencyPlatformService.scheduleCountdownAlarm()` → Doze yedeği (native AlarmManager).
3. `executeEmergencyNative(primaryNumber:)` → başarısızsa diğer numaralara fallback döngüsü.
4. `_emergencyDispatched` + `_dispatchId` + `didCountdownAlarmFire()` → çift-tetikleme koruması.
- `EmergencyPlatformService`: tüm kanal çağrılarında `timeout` + tipli `on TimeoutException/PlatformException/Exception catch`. Tek normalizasyon noktası (`AndroidIntentService.normalizePhoneNumber`). **Kod tabanının en disiplinli katmanı.**
- ⚠️ Ama bu kritik mantık 1189-satırlık `CountdownScreen` StatefulWidget'ı İÇİNDE yaşıyor (emergency_core_service.dart:9 bunu açıkça söylüyor). Test'ler source-contract ile bunu kapatıyor (25 countdown / 58 emergency test dosyası), yani test edilebilirlik kısmen telafi edilmiş.

## Test profili
468 `test()`, 114 `group()`, 1173 `expect()`, **yalnızca 3 `testWidgets()`**. Suite ezici çoğunlukla unit/source-contract (hafıza: "source-contract tests + channel mocks" ile uyumlu). **Güçlü yön**; boşluk = widget/integration testleri.

---

# BULGULAR (önem derecesine göre)

> Hiçbiri ürünün acil-arama akışında canlı arıza DEĞİL. Hepsi bakım/yapı/uyum.

### CRITICAL (yok)
Acil akışta veri kaybı/güvenlik açığı tespit edilmedi. (Çekirdek sağlam.)

### HIGH (birleşmeden önce düzeltilmeli)
- **H-1 Yarım kalmış mimari göçü.** Eski (`screens/services/widgets/models/constants`) + yeni (`core/data/domain/presentation`) yan yana. Yeni gelen geliştirici hangi yola dokunacağını bilemez → her değişiklik iki yeri etkileyebilir.
- **H-2 Contacts "temiz" katmanı sahte soyutlama.** `domain → data → datasource → ContactService` zinciri saf pass-through; `ContactsRepositoryImpl` ayrıca `ContactService`'i gereksiz import ediyor; **domain interface infra'ya bağımlı** (`EmergencyContact` core/services'te). İki erişim yolu (repo vs doğrudan ContactService) aynı store'a — bugün tutarlı, yarın diverjans riski.
- **H-3 Tutarsız hata yönetimi.** 178 bare catch / 31 tipli. Projenin kendi Dart kuralını ihlal. Bazıları sessizce yutuyor (`main.dart` cold-start). Gözlemlenebilirlik düşük.

### MEDIUM (planlı düzeltme)
- **M-1 God-file'lar.** 5 dosya >800 (proje sınırı), ~9 dosya 600-800. En riskliler churn ile örtüşüyor (countdown 1189/44, contacts_page 1184/33, home_page 1280/31).
- **M-2 Üç state paradigması.** provider/ChangeNotifier + statik singleton + 112 setState. Tek akış yok.
- **M-3 Import disiplini.** 359 relative import; kural "sadece package:". Mekanik ama kuralı ihlal ediyor ve refactor sırasında kırılganlık yaratıyor.
- **M-4 Kritik mantık UI'da.** Emergency dispatch `CountdownScreen` içinde; saf bir `EmergencyDispatchService`'e çıkarılmalı (davranış değişmeden).

### LOW (fırsat buldukça)
- **L-1** `SecureStorageService` prod'da kullanılmıyor (testi de var) → kaldır veya tek secure-storage sarmalayıcıda birleştir.
- **L-2** Kaldırılan özellik temizlik yolları (`medical*`) bir süre sonra emekliye ayrılabilir (şimdilik kasıtlı).
- **L-3** `analysis_options.yaml` projenin kendi katı kurallarını zorlamıyor (bare-catch, relative-import lint'leri kapalı) → CI sapması.

---

# REFACTOR STRATEJİSİ (davranış sabit, kalite artar — kural 5: önce onay)

Sıra: düşük-risk/yüksek-kazanç → yüksek-risk. Her adım kendi commit'i + yeşil testler.

1. **Güvenlik ağı (kod değişmez).** Mevcut testleri çalıştır, yeşil tabanı doğrula; `dart analyze` mevcut uyarıları kaydet. Acil akış için karakterizasyon testi boşluğu varsa önce onu ekle.
2. **L-1 + ölü import temizliği (mekanik, risksiz).** `SecureStorageService` ve `ContactsRepositoryImpl`'deki kullanılmayan `contact_service` import'u kaldır.
3. **H-2 Contacts katmanını dürüstleştir.** İki seçenek (onayına sunulacak):
   (a) `ContactService`'i resmi datasource yap, `EmergencyContact`'ı `domain/models`'a taşı, tüm UI tek `ContactsRepository` üzerinden geçsin (panic_button dahil); **veya**
   (b) gereksiz domain/data/datasource ceremony'sini kaldır, `ContactService`'i tek tutarlı arayüz arkasında standartlaştır.
4. **M-4 + M-1 Kritik mantığı çıkar.** `CountdownScreen`'den dispatch'i saf `EmergencyDispatchService`'e taşı (davranış birebir, sadece taşıma + test). En riskli adım — izole + yoğun test.
5. **H-3 Hata yönetimi.** Önce yutan/loglamayan bare catch'leri tipli + log'a çevir (özellikle `main.dart` cold-start). "Asla çökme" korunur.
6. **M-3 Import + M-2 dizin birleştirme.** Tek mimariye yönelt (eski `services/`,`widgets/`,`screens/` → `core`/`presentation`), relative→package importlar. Büyük ama mekanik; en sona.
7. **L-3 Lint sıkılaştır** (kademeli), CI'ya bağla.

## Açık riskler / sınırlar
- UI/tema dokunulmaz (kural 4) → M-1 god-file bölme yalnızca mantık çıkarma, görsel değişiklik yok.
- 16KB sayfa boyutu / R8 keep-rules / release imzası device-bağımlı (hafıza); refactor sonrası release doğrulaması gerekir.
- Adım 6 en geniş diff; ayrı PR'larda, dosya-grubu bazında yapılmalı.

## Son öz-eleştiri
- ✅ Her HIGH bulgu kod + (kural|2. dosya) ile çiftlendi.
- ✅ 3 hipotez çürütüldü/düzeltildi → onaylama yanlılığına düşülmedi.
- ⚠️ Bare-catch sayımı yorum satırlarını da kapsıyor olabilir (±%5); önem derecesini değiştirmez.
- ⚠️ Performans yalnızca statik sinyalle değerlendirildi; gerçek profil (DevTools) yapılmadı — bu yüzden H8 "düşük" ama "kesin yok" değil.

