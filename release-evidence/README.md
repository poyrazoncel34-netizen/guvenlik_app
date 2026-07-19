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

G4 için genel bir security witness yeterli değildir. Tam olarak bir evidence
öğesi `kind: masvsAssessment` taşımalı ve
`masvs-assessment.template.json` şemasından üretilen candidate-bound assessment'i
işaret etmelidir. Ön kontrol:

```bash
python3 scripts/verify_masvs_assessment.py \
  --assessment release-evidence/10003/masvs-assessment.json \
  --aab build/app/outputs/bundle/playRelease/app-play-release.aab \
  --expected-package com.poyrazoncel.korubeni \
  --expected-version-name 1.0.3 \
  --expected-version-code 10003
```

Bu rapor bir OWASP sertifikası değildir. Eksik kontrol, placeholder reviewer,
candidate/AAB drift'i veya hash'i doğrulanamayan evidence G4'ü fail-closed
bırakır. Ayrıntılı süreç `docs/release/masvs_assessment.md` içindedir.

Fail-closed kontrol:

```bash
python3 scripts/verify_external_release_gates.py \
  --manifest release-evidence/123/gates.json \
  --aab build/app/outputs/bundle/playRelease/app-play-release.aab
```

Yalnız bütün G0–G10 kapıları PASS, P0/P1 sıfır, aynı AAB ile en az 12 tester / 14
gün closed soak, safety incident sıfır, hotfix tatbikatı PASS ve yedi zorunlu
rolün onayı varsa `MASTER_GO_NO_GO_PASS` üretilir.
