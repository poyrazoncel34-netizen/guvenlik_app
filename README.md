# KoruBeni

KoruBeni, Android hedefli, offline-first kişisel güvenlik uygulamasıdır (Flutter; ilk
production runtime/listing yalnız Türkçe, Google Play hedefi). Bu README yalnız bir yönlendirme sayfasıdır — güncel ve
bağlayıcı bilgi aşağıdaki kaynaklardadır; buradaki hiçbir şey onları ezmez.

| Konu | Tek doğru kaynak |
|---|---|
| Bağlayıcı proje kuralları (112 yok, yalnız-PIN, offline-first, UI dokunulmaz) | [CLAUDE.md](CLAUDE.md) + [docs/HANDOVER.md §2](docs/HANDOVER.md) |
| Mimari, acil akışlar, proje durumu | [docs/HANDOVER.md](docs/HANDOVER.md) |
| Build & release süreci | [.github/workflows/release.yml](.github/workflows/release.yml) + [docs/play-console-checklist.md](docs/play-console-checklist.md) |
| Gerçek-cihaz QA | [store/REAL_DEVICE_QA_MATRIX.md](store/REAL_DEVICE_QA_MATRIX.md) |

## Test komutları

```bash
flutter analyze
flutter test
(cd android && ./gradlew :app:testPlayDebugUnitTest)
```

> Native safety testleri `:app:` scope ile koşulur. Dart tarafındaki eski doğrudan-arama
> eklentisi kaldırılmıştır; otomatik istek native typed coordinator üzerinden Telecom'a gider.
> Kök `BUILD_*.md` dosyaları erken dönem notlarıdır; release için
> `release.yml` esastır.
