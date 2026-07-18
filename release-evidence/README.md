# Release Evidence

`gates.template.json` bir başarı kaydı değildir; bütün dış kapıları bilinçli
olarak `UNVERIFIED` başlatır. Her release candidate için template ayrı bir
versionCode klasörüne kopyalanır. Secret, PIN, telefon, konum veya kullanıcı
kimliği evidence paketine konmaz.

Her evidence öğesi manifestin bulunduğu klasör altındaki bir dosyayı, SHA-256
hash'ini ve `candidateBound: true` değerini taşır. G1–G10'u `PASS` yapmak için
yorum, söz veya ekran görüntüsünün varlığı yetmez; evidence exact AAB hash'ini
ve cihaz/build/dashboard bağlamını içermelidir.

Schema v2 candidate alanı ayrıca Git commit/tree, signed tag object, version,
upload certificate, Play app-signing certificate, GitHub workflow URL ve
`provenance-v2.json` hash'ini taşır. Master verifier provenance içindeki zorunlu
artifact setini ve bütün bu kimliklerin birebir eşleşmesini doğrular.

Fail-closed kontrol:

```bash
python3 scripts/verify_external_release_gates.py \
  --manifest release-evidence/123/gates.json \
  --aab build/app/outputs/bundle/playRelease/app-play-release.aab
```

Yalnız bütün G0–G10 kapıları PASS, P0/P1 sıfır, aynı AAB ile en az 12 tester / 14
gün closed soak, safety incident sıfır, hotfix tatbikatı PASS ve yedi zorunlu
rolün onayı varsa `MASTER_GO_NO_GO_PASS` üretilir.
