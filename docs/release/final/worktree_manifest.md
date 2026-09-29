# Worktree manifest

## Logical commit uygulamasi oncesi onaylanan baseline

```text
BRANCH=codex/evidence-remediation-20260911
HEAD=37ded42b524b9755d068fe63e1ff898a9c9cfd6d
MAIN=a099b4ab5064ce91fb2ca51bc2fd50a588d434f8
WORKTREE_MODIFIED=63
WORKTREE_UNTRACKED=154
WORKTREE_FINGERPRINT_SHA256=55b47dbda32994aa8f5b0709c47b6202daa5030cdc1230226c45ce7a84a34511
```

Fingerprint girdisi `HEAD + tracked binary diff hash + sorted untracked
path/content manifest hash`tir. Bu deger commit plani onayinda dondurulan
baseline'dir.

## 216 status entry siniflandirmasi

Asagidaki kurallar `git status --porcelain=v1` girdilerinin tamamini tek bir
ana sinifa atar. Toplam `46 + 15 + 14 + 14 + 118 + 1 + 8 = 216`dir.

| Sinif | Entry | Kapsam |
|---|---:|---|
| Stage 2 | 0 dirty | Aşama 2, `main..HEAD` arasindaki 11 committe kayitlidir |
| Stage 3 | 46 | repo davranis duzeltmeleri, production/widget testleri ve dev-only test dependency |
| Stage 4 | 15 | runtime bug fixleri, timeline restoration, notification/location/siren ve testleri |
| Stage 6 | 14 | store/legal copy, translations, handover/checklist ve store regression testi |
| Stage 7 | 14 | semantics/text-scale production duzeltmeleri ve hedefli widget testleri |
| generated evidence / Stage 4 | 118 | instrumentation probe, APK/PNG/XML/log evidence ve `tool/stage4_*` |
| generated evidence / Stage 7 | 1 | `docs/audit/evidence/stage7-2026-09-28/` status entry |
| shared/finalization docs | 8 | inventory, matrix, stage raporlari ve change classification |
| suspicious/unowned | 0 | siniflandirilmamis status entry yok |

Stage 6 sahipligi, Aşama 6 raporundaki explicit dosya listesinden; Stage 7
sahipligi Aşama 7 bolum 8'den; Stage 4 sahipligi ilk/continuation raporlarindaki
explicit listelerden gelir. Kalan production ve davranis testleri Aşama 3 repo
behavior calismasidir. Bir dosya birden cok asamada degistiyse en son dominant
sahiplik kullanilir; bu commit tarihi kaniti degil logical grouping planidir.

`tool/stage4_android_runtime_probe.dart` Stage 4 test-only runtime probe'udur;
production entrypoint degildir ve `release_change_classification.json` icinde
siniflandirilmistir. Suspicious/unowned degildir.

## Logical commit uygulama sonucu

Onaylanan COMMIT_1-11 sirasiyla uygulanmistir. Kaynak, regression testleri,
Stage 4 probe'u, store/legal hazirligi ve 409-ID audit/matrix belgeleri ayri
logical commitlerde kayitlidir. COMMIT_12 uygulanmamistir; merge, push ve tag
yapilmamistir.

```text
COMMITS_CREATED=11/11
HEAD_AFTER_COMMIT_11=c034731ced73cedc071fa76a800ca6a32a9c4789
SOURCE_FROZEN_SHA=c034731ced73cedc071fa76a800ca6a32a9c4789
MAIN=a099b4ab5064ce91fb2ca51bc2fd50a588d434f8
```

## COMMIT_12 duzenlemesi oncesi tam worktree snapshot'i

Final belge alanlari guncellenmeden hemen once alinan butun-agac snapshot'i:

```text
WORKTREE_MODIFIED=0
UNTRACKED_STATUS_ENTRIES=119
UNTRACKED_ACTUAL_FILES=369
GENERATED_EVIDENCE_UNTRACKED=362
TRACKED_DIFF_SHA256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
UNTRACKED_MANIFEST_SHA256=e3fd6ef956c6971512eb46f15172160db9a32e46a4ab4103771109e4c30beef3
WORKTREE_FINGERPRINT_SHA256=025c308dba45c316d33eff187f39414a582e3cc20d86b53d1d5a3e6f6b2f1514
```

369 untracked dosyanin 362'si generated Stage 4/7 evidence, yedisi
`docs/release/final/*.md` COMMIT_12 belgesidir. Generated evidence silinmemis ve
stage edilmemistir. Suspicious/unowned dosya yoktur.

Kendi fingerprint satirini hashleme dongusunu onleyen stabil source snapshot'i
`docs/release/final/**` haric tutar:

```text
SOURCE_TRACKED_DIFF_SHA256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
SOURCE_UNTRACKED_MANIFEST_SHA256=422adb58a52171e959807fb2aec5bb6325fd70d6b78c368ce26ea102029d592c
SOURCE_WORKTREE_FINGERPRINT_SHA256=188f421f8ff981b41927e2f67175b85fe29ade17f255e6a0362dc3454624c326
```
