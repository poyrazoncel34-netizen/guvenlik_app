# Candidate-Bound OWASP MASVS Assessment

Status: **REQUIRED / UNVERIFIED**

Bu çalışma OWASP MASVS kontrol ailelerini eksiksizlik listesi olarak kullanır;
bir OWASP onayı veya sertifika değildir. Production kapısı yalnız exact AAB'ye,
exact sürüme ve hash'i doğrulanan redakte kanıtlara bağlı insan incelemesiyle
kapanır.

## Sözleşme

- Kaynak: `https://mas.owasp.org/MASVS/`
- Şablon: `release-evidence/masvs-assessment.template.json`
- Şema: 24 güncel MASVS kontrolünün tamamı bulunmalıdır.
- Başlangıç durumu: bütün kontroller `UNVERIFIED`.
- Kabul edilen sonuç: `PASS` veya gerekçeli `NOT_APPLICABLE`.
- Her kontrol en az bir `candidateBound: true` evidence kaydı taşımalıdır.
- Evidence dosyası assessment ile aynı candidate klasörü altında kalmalı ve
  kaydedilen SHA-256 ile byte-for-byte eşleşmelidir.
- `reviewedBy` gerçek, hesap verebilir security reviewer kimliğidir; placeholder
  veya kod yazarının tek başına beyanı kabul edilmez.

Tek ekran görüntüsü otomatik olarak kanıt değildir. Kayıt; test hedefini,
beklenen sonucu, kullanılan exact AAB/version bilgisini, tekrar sayısını ve
sonucu anlatan redakte bir rapora bağlanmalıdır. PIN, telefon, koordinat,
RevenueCat/Play kimliği, e-posta veya secret evidence'a konmaz.

## Candidate klasörünü hazırla

Template'i ilgili versionCode klasörüne kopyala ve yalnız gerçek candidate
oluştuktan sonra candidate alanlarını doldur:

```sh
cp release-evidence/masvs-assessment.template.json \
  release-evidence/10003/masvs-assessment.json
```

Kontrol sonuçları storage, crypto, auth, network, platform, code, resilience ve
privacy yüzeylerini kapsamalıdır. Repo-içi testler yalnız ilgili kontrole kanıt
olabilir; Play/OEM/runtime iddiası gereken kontrollerde exact Play-delivered
candidate üzerinde fiziksel veya dashboard kanıtı gerekir.

## Fail-closed doğrulama

```sh
python3 scripts/verify_masvs_assessment.py \
  --assessment release-evidence/10003/masvs-assessment.json \
  --aab build/app/outputs/bundle/playRelease/app-play-release.aab \
  --expected-package com.poyrazoncel.korubeni \
  --expected-version-name 1.0.3 \
  --expected-version-code 10003
```

Tek başarılı terminal sonucu `MASVS_ASSESSMENT_PASS` ve `controls=24` satırlarını
taşır. Bir kontrolün eksik/UNVERIFIED olması, AAB drift'i, evidence path escape,
eksik dosya veya hash uyuşmazlığı sonucu FAIL yapar.

Master G4 manifestinde bu assessment şu türle tekil olarak bağlanır:

```json
{
  "path": "masvs-assessment.json",
  "sha256": "<assessment-bytes-sha256>",
  "candidateBound": true,
  "kind": "masvsAssessment"
}
```

Genel bir security notu veya `kind` taşımayan witness dosyası G4'ü kapatamaz.
Assessment PASS olsa bile 400/400 lisans, privacy counsel, deletion/transfer ve
diğer G4 kanıtları tamamlanmadan G4 PASS değildir.
