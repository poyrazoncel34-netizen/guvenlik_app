# Phase 5 — Dependency Security Evidence (2026-07-18)

Scope: exact dependency versions currently resolved by `pubspec.lock` and the
Android `playReleaseRuntimeClasspath`. Queries used the official OSV
`POST /v1/querybatch` API.

## Result

| Layer | Exact versions queried | Result |
| --- | ---: | --- |
| Pub / Flutter | 199 | PASS — no known OSV finding |
| Maven / Android Play release runtime | 203 | PASS — no known OSV finding |

`flutter pub outdated` also reported 53 lockfile-upgradable packages and 31
dependencies constrained below a newer resolvable version. That is maintenance
debt, not proof of a vulnerability. Major upgrades must be isolated and repeat
the full physical safety/billing matrix instead of being bundled into the first
release without evidence.

## RevenueCat version decision

The two RevenueCat Flutter packages were advanced together from 10.3.0 to
10.4.2. This is a controlled pre-candidate update, not a policy of blindly
tracking newest releases:

- 10.3.0 wrapped RevenueCat Android 10.9.1.
- Flutter 10.4.2 wraps Android 10.13.0 and 10.14.0. Android 10.13.0 catches a
  `FileNotFoundException` in event-file reading to prevent a time-of-check /
  time-of-use crash; 10.14.0 reduces ETag/HTTP response memory pressure and
  includes remote-config/paywall fixes.
- KoruBeni uses RevenueCat core plus Customer Center, so the event crash fix is
  reachable enough to justify qualification. It does not use RevenueCat's
  hosted `PaywallView`; most Paywalls V2 changes are therefore not the reason
  for the update.
- The update was made before the signed Play candidate and license-tester
  matrix. It passed clean static analysis, all 524 Flutter tests, Android lint,
  Kotlin unit tests, instrumentation APK compilation, smoke AAB signing and the
  10/10 native-library 16 KB gate. It is still **not billing-qualified** until
  monthly, annual, restore, lapse and failure paths pass on the Play test track.

Primary release notes:

- <https://github.com/RevenueCat/purchases-flutter/releases/tag/10.3.0>
- <https://github.com/RevenueCat/purchases-flutter/releases/tag/10.4.2>
- <https://github.com/RevenueCat/purchases-android/releases/tag/10.13.0>
- <https://github.com/RevenueCat/purchases-android/releases/tag/10.14.0>

## Repeatable gate

```text
./scripts/audit_dependencies_osv.sh
```

The script fails on OSV/network/response errors or a known finding and is wired
into both PR/main CI and the tagged release workflow.

## Limitation

This result means only “no vulnerability known to OSV for these exact package
coordinates at scan time.” It does not prove absence of undisclosed issues,
incorrect coordinates, unreachable vulnerable code, Play SDK policy problems,
or vulnerabilities outside OSV's covered sources. Official API/data references:

- <https://google.github.io/osv.dev/post-v1-querybatch/>
- <https://google.github.io/osv.dev/data/>
