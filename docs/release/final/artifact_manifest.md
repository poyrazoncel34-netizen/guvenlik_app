# Artifact manifest

## Stage 4 emulator artifact

| Alan | Deger |
|---|---|
| Path | `docs/audit/evidence/stage4-final10/app-play-debug-final12.apk` |
| SHA-256 | `d1b99ea35961ed077c76c535e8f1d4ac1aaa0965cc6c3d59d844311553b96a22` |
| Variant | `playDebug` |
| applicationId | `com.poyrazoncel.korubeni` |
| Git base | `37ded42b524b9755d068fe63e1ff898a9c9cfd6d` + o turdaki dirty tree |
| Rol | Aşama 4 emulator kaniti; production release artifact degil |

## Aşama 8 smoke artifact

`verify_release.sh` smoke AAB uretebilir. Paket kimligi
`com.poyrazoncel.korubeni.smoke` ve sinifi `NON_RELEASE_SMOKE`tur. Hash ve boyut
fresh gate sonrasi kaydedilmistir:

| Alan | Deger |
|---|---|
| Path | `build/app/outputs/bundle/smokeRelease/app-smoke-release.aab` |
| Size | `105488101` bytes |
| SHA-256 | `dc72fe776f20b3312899c1078b3ce070142f89923afd965681499eee47518c8a` |
| package | `com.poyrazoncel.korubeni.smoke` |
| Sinif | `NON_RELEASE_SMOKE` |
| 16 KB | 10/10 native library PASS |

Bu artifact production hanesine yazilmaz ve Play production uygulamasina
yuklenemez.

## Production AAB

```text
SOURCE_FROZEN_SHA=c034731ced73cedc071fa76a800ca6a32a9c4789
COMMIT_12_SHA=INTENTIONALLY_REPORTED_AFTER_COMMIT
PRODUCTION_AAB=BLOCKED
```

Gercek release signing/env, tamamlanmis Stage 5/6/7, COMMIT_12 ile kayitli final
konsolidasyon, CI/Play provenance ve ayni artifact'in internal track kurulumu
yoktur. Bu nedenle production AAB uretilmis veya dogrulanmis gibi sunulmaz.
