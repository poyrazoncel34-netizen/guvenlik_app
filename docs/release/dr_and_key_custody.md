# Disaster recovery and key custody — KoruBeni

> Scope: this document covers the only disaster domains this project actually has.
> It deliberately does **not** contain a status page, incident-commander rota or
> database restore plan, because there is no service, no team and no operator-held
> database. Inventing that apparatus would make this document decorative.

Last reviewed: 2026-08-12 · Owner: repository owner (single maintainer)

---

## 1. What can actually be lost

| Asset | Where it lives | Loss impact | Recoverable? |
|---|---|---|---|
| User data (contacts, PIN, timeline) | Only on each user's device | Owner loses their own setup | **No — by design** |
| Source code | git + GitHub | Development stops | Yes, from any clone |
| Upload keystore (`korubeni_keystore_release.jks`) | Local + `KEYSTORE_BASE64` secret | Cannot sign a new upload | **Yes — see §3** |
| Play app-signing key | Held by Google | Cannot ship to existing installs | Yes — Google holds it |
| Play Console account | Google account | Cannot publish at all | Depends on account recovery |
| GitHub account | GitHub | CI and release pipeline stop | Depends on account recovery |
| RevenueCat account | RevenueCat | Entitlements stop resolving → app fails closed | Yes, account recovery |

**User data is intentionally unrecoverable.** `AndroidManifest.xml` sets `allowBackup=false`
and `data_extraction_rules.xml` excludes every domain from cloud-backup and device-transfer.
Under the duress threat model a cloud copy of a victim's emergency contacts is a liability,
not an asset. The onboarding copy already sets this expectation ("PIN'i sıfırlayacak bir
sunucu yok"). **Do not "fix" this by enabling backup.**

---

## 2. Key custody model

The release pipeline is built on **Play App Signing**. This is visible in
[`.github/workflows/release.yml`](../../.github/workflows/release.yml), which pins two
distinct fingerprints:

- `EXPECTED_UPLOAD_CERT_SHA256` — the local keystore, verified with `keytool -exportcert`
  before any build. A mismatch fails the release closed.
- `EXPECTED_PLAY_APP_SIGNING_CERT_SHA256` — "copied from Play Console", i.e. the key Google
  holds and signs the delivered artifact with.

That two-key split only exists when Play App Signing is enrolled.

**Consequence: losing the upload keystore is not catastrophic.** Google can reset the upload
key on request; the app-signing key that existing installs trust never leaves Google.

> **Open item (externally verifiable only).** The repository proves the pipeline *expects*
> Play App Signing. It cannot prove the Play Console account is enrolled — that requires
> Console access. Confirm once, and record the date in the table at the top of this file.
> Until confirmed this stays an assumption, not a fact.

---

## 3. Runbook: upload keystore lost or compromised

1. Do **not** delete the old key material until the replacement is live.
2. Generate a new upload keystore.
3. In Play Console → Setup → App integrity → request an **upload key reset**, attaching the
   new certificate (`.pem`).
4. Wait for Google to activate the new upload key (typically ~48h).
5. Update repository secrets: `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`,
   `KEY_ALIAS`, `EXPECTED_UPLOAD_CERT_SHA256`.
6. Cut a tag and confirm the "Verify upload certificate identity" step passes.

`EXPECTED_PLAY_APP_SIGNING_CERT_SHA256` does **not** change — that is the point of the split.

---

## 4. Runbook: Play Console or GitHub account compromised

1. Recover or lock the Google/GitHub account first; everything else is downstream.
2. Rotate every repository secret listed in §3 plus `REVENUECAT_ANDROID_API_KEY`.
3. Review the Play Console release history for artifacts you did not publish.
4. Review GitHub Actions run history and the tag list; `release.yml` requires a **signed
   annotated tag whose commit is an ancestor of `origin/main`**, so a forged release would
   need both account access and a signing key.
5. If any unauthorised build reached users, treat it as a security incident and follow
   [`docs/veri_ihlali_bildirimi_proseduru.md`](../veri_ihlali_bildirimi_proseduru.md) to
   assess whether a KVKK notification obligation is triggered.

**Preventive control (confirm, do not assume):** MFA — preferably a hardware key — on both
the Google account that owns the Play Console and the GitHub account. Neither is verifiable
from this repository.

---

## 5. Runbook: bad release already rolled out

**Google Play does not allow rollback to a lower `versionCode`.** The only remedy is halt
plus roll-forward. Anyone who expects "click rollback" will lose time discovering this
during the incident.

1. **Halt the staged rollout** in Play Console immediately. This stops new users receiving
   the build; it does not remove it from devices that already updated.
2. Assess severity:
   - **S1** — panic/dispatch path broken (the app fails at its only real job)
   - **S2** — Pro entitlement or check-in/safe-walk broken
   - **S3** — cosmetic or non-safety
3. For S1, consider whether the previous version can be re-published under a *higher*
   `versionCode` while the fix is prepared. `versionCode` derives from the tag
   (see the release workflow), so this is mechanically possible.
4. Fix, tag, and roll forward through the internal-test track first.
5. Write a postmortem using section 79 of
   [`docs/MASTER_PRODUCTION_CHECKLIST.md`](../MASTER_PRODUCTION_CHECKLIST.md) as the template.

> **Not yet rehearsed.** The roll-forward path above has never been executed. Rehearse it
> once on the internal-test track so the real timing is known before it is needed.

---

## 6. Credential rotation

| Credential | Source | Rotation |
|---|---|---|
| `REVENUECAT_ANDROID_API_KEY` | RevenueCat dashboard | Issue a new public `goog_` key, update the repo secret, cut a release. Old key stops working once revoked. |
| `KEYSTORE_BASE64` + passwords | Local keystore | Only as part of §3. |
| GitHub Actions secrets | GitHub | Settings → Secrets → update. Scoped to the `production` environment. |

`lib/core/config/app_environment.dart` rejects any RevenueCat key that is not a `goog_`
public client key — `sk_` secret keys, placeholders and the CI smoke key all fail the
release build. That guard is pinned by `test/release_readiness_policy_test.dart`.

---

## 7. What has no recovery path, and why that is correct

- **User data.** See §1. Deliberate.
- **In-flight safety sessions on a wiped device.** Sessions live in device-protected
  storage; a factory reset ends them. There is no server to resume from, and adding one
  would violate the offline-first envelope (CLAUDE.md rule 1).
- **Telemetry about what went wrong in production.** The app ships no analytics by design.
  Post-incident evidence depends on the user exporting their own local log
  (`lib/core/services/user_data_export_service.dart`). See
  [`observability_and_slo.md`](observability_and_slo.md).
