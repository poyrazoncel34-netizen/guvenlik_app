# Fresh local gate results

Tarih: 2026-09-29. Komutlar current working tree uzerinde sirayla calistirildi.

## 1. Static analysis

```text
COMMAND=flutter analyze --no-fatal-infos
EXIT=0
OUTPUT=No issues found! (ran in 3.6s)
```

## 2. Tam Flutter paketi

```text
COMMAND=flutter test --no-pub
EXIT=0
TESTS=2040
OUTPUT=01:47 +2040: All tests passed!
```

## 3. Fresh Kotlin unit + instrumentation APK build

```text
COMMAND=cd android && ./gradlew :app:testPlayDebugUnitTest :app:assemblePlayDebugAndroidTest --rerun-tasks --console=plain
EXIT=0
KOTLIN_TESTS=125
KOTLIN_FAILURES=0
KOTLIN_ERRORS=0
KOTLIN_SKIPPED=0
OUTPUT=BUILD SUCCESSFUL in 25s; 462 actionable tasks: 462 executed
```

`assemblePlayDebugAndroidTest` PASS yalniz instrumentation APK build kanitidir;
cihazda instrumentation runtime calistirildi diye sunulmaz.

## 4. Release verification chain

Ilk sandbox kosusu urun/test hatasi olmadan Flutter SDK cache yazma izninde
durdu:

```text
COMMAND=./scripts/verify_release.sh
EXIT=1
OUTPUT=engine.stamp: Operation not permitted; flutter clean basarisiz
```

Ayni komut gerekli filesystem izniyle fresh tekrarlandi:

```text
COMMAND=./scripts/verify_release.sh
EXIT=0
FLUTTER_TESTS=2040
CRITICAL_COVERAGE=PASS
KOTLIN_UNIT=PASS
INSTRUMENTATION_BUILD=PASS
ANDROID_RELEASE_SURFACE=PASS
NATIVE_16KB=10/10 PASS
LICENSE_NOTICES=PASS
OUTPUT=LOCAL_CANDIDATE_PASS; TAGGED_RELEASE_GATES_LOCAL_PASS; EXTERNAL_RELEASE_GATES_UNVERIFIED
```

Uretilen AAB `.smoke` package kimliklidir; production artifact degildir.

## 5. Diff whitespace gate

```text
COMMAND=git diff --check
EXIT=0
OUTPUT=(bos)
```

## 6. Inventory/matrix parity

```text
COMMAND=flutter test --no-pub test/release/final_completion_matrix_parity_test.dart
EXIT=0
TESTS=6
OUTPUT=+6: All tests passed!; inventory 409; missing 0; extra 0; duplicate 0
```

## 7. Secret scan

```text
COMMAND=python3 scripts/scan_release_secrets.py --repo . --output /tmp/korubeni-post-commit-secret-scan.json
EXIT=0
OUTPUT=RELEASE_SECRET_SCAN_PASS; tracked-candidate files=1001; findings=0
UNTRACKED_HIGH_CONFIDENCE_FINDINGS=0
```

## Sonuc

```text
FLUTTER_SUITE=PASS
KOTLIN_SUITE=PASS
INSTRUMENTATION_BUILD=PASS
VERIFY_RELEASE=PASS
PARITY=PASS
```

Bu local sonuc Stage 5/6/7 dis kanit blocker'larini kapatmaz.
