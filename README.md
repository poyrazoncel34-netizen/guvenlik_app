# KoruBeni

KoruBeni, Android hedefli, offline-first kişisel güvenlik uygulamasıdır (Flutter; ilk
production runtime/listing yalnız Türkçe, Google Play hedefi). Bu README yalnız bir yönlendirme sayfasıdır — güncel ve
bağlayıcı bilgi aşağıdaki kaynaklardadır; buradaki hiçbir şey onları ezmez.

| Konu | Tek doğru kaynak |
|---|---|
| Bağlayıcı proje kuralları (112 yok, yalnız-PIN, offline-first, UI dokunulmaz) | [CLAUDE.md](CLAUDE.md) + [.claude/rules/](.claude/rules/) |
| Mimari, acil akışlar, güncel durum | [docs/release/safety_case.md](docs/release/safety_case.md) |
| Build & release süreci | [.github/workflows/release.yml](.github/workflows/release.yml) + [docs/play-console-checklist.md](docs/play-console-checklist.md) |
| Felaket kurtarma & anahtar saklama | [docs/release/dr_and_key_custody.md](docs/release/dr_and_key_custody.md) |
| Gözlemlenebilirlik & hedefler | [docs/release/observability_and_slo.md](docs/release/observability_and_slo.md) |
| Üretime hazırlık denetimi | [PRODUCTION_AUDIT.md](PRODUCTION_AUDIT.md) + [REMEDIATION_PLAN.md](REMEDIATION_PLAN.md) |
| Gerçek-cihaz QA | [store/REAL_DEVICE_QA_MATRIX.md](store/REAL_DEVICE_QA_MATRIX.md) |

> ⚠️ [docs/HANDOVER.md](docs/HANDOVER.md) **ARŞİVDİR.** Kaldırılmış bir mimariyi
> (`EmergencyExecutor`, `CheckInScheduler`, `CountdownAlarmScheduler`) anlatır ve release
> kanıtı olarak kullanılamaz. Güncel kaynak `docs/release/safety_case.md`.

## Yerelde çalıştırma

Uygulamanın iki flavor'ı var: `play` (mağaza) ve `smoke` (CI doğrulama, `.smoke`
applicationId son eki ile — Play uygulamasının yerine geçemez).

```bash
flutter pub get
flutter build apk --debug --flavor play --target-platform android-arm64
```

> `--target-platform` gerekiyor: Apple Silicon üzerindeki emülatörler **arm64**'tür.
> x86_64 derlerseniz APK kurulur ama açılışta
> `MissingLibraryException: Could not find 'libflutter.so'` ile çöker.

`ENV` varsayılan olarak `dev`'dir. Release derlemesi `--dart-define=ENV=production` ve
`goog_` ile başlayan gerçek bir RevenueCat anahtarı ister; `test_`, `sk_` ve placeholder
değerler hem gradle hem çalışma zamanında reddedilir.

## Test komutları

```bash
flutter analyze --no-fatal-infos
flutter test --no-pub
(cd android && ./gradlew :app:testPlayDebugUnitTest)
(cd android && ./gradlew :app:connectedPlayDebugAndroidTest)   # emülatör/cihaz gerekir
```

CI tam olarak ilk iki komutu koşar. Depoda **format kapısı yoktur** ve bu bilinçli bir
karardır — gerekçe: [.claude/rules/common/coding-style.md](.claude/rules/common/coding-style.md).

> Native safety testleri `:app:` scope ile koşulur. Dart tarafındaki eski doğrudan-arama
> eklentisi kaldırılmıştır; otomatik istek native typed coordinator üzerinden Telecom'a gider.
>
> Kök dizindeki `BUILD_NOW.md`, `BUILD_FIX.md`, `BUILD_FINAL.md`, `DEBUG_BUILD.md` ve
> `KEYSETUP.md` **Şubat 2026 dönemine ait eski notlardır ve güncel değildir.** Yerel kurulum
> için yukarıdaki bölüm, release için `release.yml` esastır.
