# Uygulama Planı — Kullanım Sözleşmesi v4.0.0 (Faz 1)

**Tarih:** 2026-08-25 · **Dal:** `feat/tutundurma-ucretsiz-prova` üzerinden yeni dal
**Kaynak tasarım:** `docs/legal/TASLAK-kullanim-sozlesmesi-v4.md`
**Analiz:** `docs/legal/sorumluluk-devri-analizi-2026-08-25.md`

## Amaç

Sözleşmeyi "sorumsuzluk kaydı" modelinden "dar edim tanımı" modeline geçirmek.
Ölçülebilir hedef: 42 senaryodan 36'sında varsayılan sorumlunun kullanıcı olması,
ve haksız şart denetiminde resen düşecek hüküm kalmaması.

## Kapsam dışı (bu planda YOK)

- UI/tema/görsel değişiklik yok (CLAUDE.md kural 4). Yaş kapısı Faz 3'te ayrı planlanır.
- KVKK/aydınlatma metni değişmiyor → `kvkkVersion` **bump edilmiyor**.
- Yeni özellik yok, mimari değişiklik yok.

---

## Keşif bulguları — iki tuzak

### Tuzak 1: `bump_legal.sh` termsVersion'ı bilmiyor

Script yalnızca `--kvkk` alıyor; `termsVersion` için propagasyon yolu **yok.**
Aynı script'in kendi uyarısı: *"elle pin düzenleme."* Yani bu bump'ın bugün
otomasyonu yok ve elle yapılırsa tam da script'in engellemek için var olduğu
drift oluşur.

**Karar:** Önce script'e `--terms` desteği eklenir, sonra kullanılır.

### Tuzak 2: Sürüm satırı bir layout testinde sabit yazılı

`test/screens/unlock_screen_density_overflow_test.dart:120,126` içinde
`'Sürüm 3.1.0 — 21 Mayıs 2026'` **birebir** geçiyor. Bu test bir yoğunluk/taşma
regresyonunu koruyor: o satırın Row'unda Expanded yokken kırpılıyordu.

`4.0.0` ile `3.1.0` aynı uzunlukta, ama **tarih değişiyor.** Yeni tarih daha uzunsa
test ya kırılır ya da — daha kötüsü — kırılmaz ama koruduğu regresyon yüzeyini
kaybeder. Tarih uzunluğu bilinçli seçilmeli ve test yeni string ile güncellenmeli.

### Yayılım yüzeyi (tam liste)

| Dosya | Ne |
|---|---|
| `lib/constants/legal_texts.dart:9` | `termsVersion` sabiti |
| `lib/constants/legal_texts.dart:13-14` | "içerik değişmedi" yorumu — artık yanlış, güncellenecek |
| `lib/constants/legal_texts.dart:20-120` | TR sözleşme gövdesi |
| `lib/constants/legal_texts.dart:123-222` | EN sözleşme gövdesi |
| `store/kullanim_sartlari.html:104` | HTML aynası sürüm/tarih satırı + gövde |
| `.gh-pages-publish/` | store/'dan ÜRETİLİR, elle dokunulmaz |
| `test/release_readiness_policy_test.dart:472` | `expect(termsVersion, '3.1.0')` pini |
| `test/screens/unlock_screen_density_overflow_test.dart:120,126` | sabit sürüm string'i |

### Bump'ın tetiklediği davranış

| Dosya | Etki |
|---|---|
| `lib/services/consent_manager.dart:216` | Kayıtlı sürüm ≠ yeni sürüm → yeniden onay |
| `lib/services/legal_version_checker.dart:21` | Aynı kontrol |
| `lib/screens/splash_screen.dart:203` | Açılışta onay akışına yönlendirme |
| `lib/core/services/revenue_cat_service.dart:136` | RevenueCat yapılandırması güncel sözleşme onayına bağlı |

Yayında kullanıcı olmadığı için yeniden onayın maliyeti bugün **sıfır**. Bu değişikliğin
zamanı tam olarak şimdi.

---

## Adımlar

Her adım kendi commit'i, her commit'te `flutter analyze --no-fatal-infos && flutter test` yeşil.

### Adım 1 — `bump_legal.sh` termsVersion desteği

- `--terms X.Y.Z` argümanı; `--kvkk` ile birlikte veya ayrı kullanılabilir.
- Eski değer `legal_texts.dart`'tan otomatik keşfedilir (mevcut desenin aynısı).
- Propagasyon hedefleri: `legal_texts.dart`, `store/kullanim_sartlari.html`,
  `test/release_readiness_policy_test.dart`, `test/screens/unlock_screen_density_overflow_test.dart`.
- `--dry-run` mevcut davranışı korur.
- Script sonunda parity testi koşar.
- **Test:** script'in dry-run çıktısını doğrulayan kabuk seviyesi kontrol + mevcut
  parity testinin yeşil kalması.
- Bu adımda legal gövde **değişmez**; yalnızca araç eklenir. Tek başına güvenli.

### Adım 2 — Sözleşme gövdesi v4.0.0 (TR + EN), tek atomik commit

Pinler ile gövde aynı commit'te olmak zorunda: ayrılırsa aradaki commit'te testler kırmızı olur.

- TR gövdesi taslaktaki 19 maddeye göre yeniden yazılır.
- EN gövdesi TR ile birebir eşlenir (madde numaraları ve anlam aynı).
- `store/kullanim_sartlari.html` gövdesi TR ile eşitlenir.
- Sürüm/tarih propagasyonu **Adım 1'deki script ile** yapılır, elle değil.
- Yorum satırı 13-14 düzeltilir.
- **Test:** `release_readiness_policy_test` pini yeni sürümü gösterir;
  `unlock_screen_density_overflow_test` yeni string ile ölçer.

### Adım 3 — Yeni politika testleri

Sözleşmenin taşıyıcı hükümlerinin sessizce silinmesini engelleyen drift yakalayıcılar:

- `edim tanımı` maddesinin varlığı ve "sonuç borcu doğurmaz" ifadesinin korunması
- `belgelenmiş çalışma sınırları` listesinin en az 16 bent taşıması
- `kullanıcı doğrulama yükümlülüğü` maddesinin varlığı
- TBK m.115 istisna cümlesinin varlığı (bu cümle silinirse madde bütünüyle düşer)
- Yasaklı kalıp taraması: "hiçbir zarardan sorumlu", "can kaybı dahil",
  "tüm sorumluluk kullanıcıya aittir" — bunlar geri gelirse test kırmızı
- TR ↔ EN madde sayısı pariteси

### Adım 4 — Vaat tutarlılığı (Faz 2)

- `store/play_store_listing_tr.md` ve `_en.md`: "acil yardım" anahtar kelimesi,
  "Güvenli Yürüyüş" adlandırması gözden geçirilir.
- `public_release_overclaim_copy_test.dart` yeni yasaklı kalıplarla genişletilir.
- Mağaza metni ↔ sözleşme parity testi eklenir.

---

## Doğrulama

- Her commit'te: `flutter analyze --no-fatal-infos && flutter test --no-pub`
- Adım 2 ve 4 sonrası: `scripts/verify_release.sh` (legal metin ve store dokümanı
  değiştiği için release sınıflandırma kapısı tetiklenir)
- `config/release_change_classification.json`: Adım 1'de `docs/legal/` sınıflandırma
  kuralına eklendi (kategori `legal`, grup `05-legal-store`). Bu plan `docs/design/`
  altında tutulur; orası zaten sınıflandırılmıştır. Yeni bir yola dosya eklenirse
  gate kırmızı olur — çözüm config'e kural eklemektir, assertion'ı zayıflatmak değil.

## Geri alma

Play geri alma yapmaz. Bu değişiklik yayına çıkmadan önce yapıldığı için geri alma
git seviyesinde: adımlar ayrı commit olduğu için tek tek revert edilebilir.
Adım 2 atomik olduğundan yarım kalmış bir sürüm durumu oluşmaz.

## Onay bekleyen tek karar

Uygulama adı "KoruBeni" Reklam Kurulu genel izlenim ölçütü bakımından artık risk
taşıyor (bkz. analiz §8). Bu plan **ismi değiştirmiyor**; riski Faz 2 ile azaltıp
kalanını sahibinin bilinçli kabulüne bırakıyor. Aksi istenirse ayrı bir plan gerekir.
