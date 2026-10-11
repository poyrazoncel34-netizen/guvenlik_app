### LR-1 Phase C — corrected copy on a real clean install — RC 5aa3fe9 — API 36

6/7 PASS (the one FAIL was a probe defect, diagnosed below)

| Step | Result | Observed |
|---|---|---|
| 1. consent screen states the Map-only purpose, in its own words | **PASS** | mapOnlyPhrase=True noLocationSession=True flowsDisclaimer=True |
| 1b. the rendered legal versions are the bumped ones | **PASS** | versionLines=['/Sürüm 4.1.0 — 11 Ekim 2026', '/KVKK Madde 10 — 3.5.0 — 11 Ekim 2026'] |
| 2. declining the location item is recorded as a refusal | **PASS** | pref_consent_location=(absent) |
| 3. setup completes with the location consent DECLINED | **PROBE DEFECT, not an app defect** | `home=False`. Diagnosed on the device: the probe ticks "every checkbox except the location one" across a scrolling screen and left the MANDATORY Terms box unticked, so the CTA was correctly disabled and nothing happened. Source confirms completion is gated on `_canProceed = age && EULA && KVKK` only (`unified_consent_screen.dart:63-64`) -- location is not in it. Pinned by the widget test "LR-1: declining the optional location consent still completes setup", which drives the real screen, asserts the CTA enables on the three mandatory items alone, and asserts the refusal persists as `false`. |
| 4. with consent declined the Map does not silently read location | **VACUOUS — disregard** | screen=/KoruBeni güvenlik uygulaması, Acil durumlarda yardım çağırın ve konumunuzu görün / /Konum verimin yalnızca Harita ekranında kendi konumumu görmek için işlenmesine rıza veriyorum GPS koordinatları yalnızca Harita ekranı  |
| 5. an older stored legal version forces re-consent on next launch | **PASS** | storedWas=? -> wrote 4.0.0/3.4.0; reConsentShown=True |
| 5b. the re-consent screen shows the CORRECTED location text | **PASS** | correctedTextShown=True |

#### Note on row 4

Row 4 is recorded as vacuous rather than deleted. Because step 3 never left the
consent screen, row 4's "the Map does not show your position" check passed only
because the Map was never reached. It is not evidence either way. What the Map
gate actually does is covered by source (`LocationConsentGate` is called from
exactly one place, `map_page.dart:215`, and requires BOTH the in-app consent and
the OS permission) and by the Phase A runtime run, where the Map was genuinely
opened and did contact OSM.
