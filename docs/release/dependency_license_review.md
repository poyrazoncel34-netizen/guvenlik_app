# Dependency Licence Evidence Review

Status: **REQUIRED / INCOMPLETE**

This runbook closes the licence half of the release supply-chain gate. It does
not turn an automated package classifier into legal advice. The tagged release
must remain blocked until every component in the exact SBOM has independently
reviewed evidence and the policy verifier passes.

## Sources of truth

- Dependency inventory: `pubspec.lock` and
  `android/app/gradle.lockfile`.
- Exact component identity: the CycloneDX package URL (`purl`), including the
  resolved version.
- Reviewed evidence: `config/dependency_license_evidence.json`.
- Exact reviewed licence bytes: `config/license-texts/<sha256>.txt`.
- Candidate-bound shipped notice asset:
  `assets/legal/THIRD_PARTY_NOTICES.txt`.
- Policy and time-bounded exceptions:
  `config/dependency_license_policy.json`.
- Integrity of downloaded Gradle artifacts:
  `android/gradle/verification-metadata.xml`.

The current generated inventory contains 400 Pub/Maven components. The
evidence file is intentionally empty, so the tagged release currently fails
closed with `UNVERIFIED`. Do not change that status by adding guessed licences,
package-name-only records, or a blanket waiver.

## Required evidence per component

Each entry key must equal the exact SBOM `purl`. Each value must contain:

```json
{
  "spdxId": "MIT",
  "sourceUrl": "https://primary-upstream.example/LICENSE",
  "sha256": "64-lowercase-hex-characters",
  "reviewedBy": "accountable-human-reviewer",
  "reviewedAt": "YYYY-MM-DD"
}
```

The reviewer must:

1. Open the exact resolved version's primary upstream licence source. Prefer a
   versioned repository tag, release archive, package registry metadata, or the
   distributed artifact's own licence file. A search-result snippet or a
   third-party licence database is not primary evidence.
2. Save the exact reviewed bytes and record their SHA-256. The hash proves what
   was reviewed; it does not prove the interpretation was correct. Store those
   same UTF-8 bytes as `config/license-texts/<sha256>.txt`.
3. Confirm the SPDX identifier against the complete text, including additional
   notices, exceptions, dual-licensing choices, embedded code, fonts, and
   native binaries.
4. Record a named reviewer and UTC review date. The code author should not be
   the sole approver for a disputed, copyleft, custom, or unknown licence.
5. Re-run SBOM generation. Stale evidence for a dependency no longer present is
   rejected, and missing evidence keeps the whole SBOM `UNVERIFIED`.

## Policy and waivers

`allowedSpdxIds` is an explicit release policy, not a declaration that every
licence on the list is automatically compatible with every use. The blocked
GPL/AGPL identifiers fail even if evidence exists.

A non-allowlisted licence needs an exact-purl waiver containing the SPDX ID,
accountable approver, concrete rationale, and an expiry date. Waivers expire at
the start of the next UTC calendar day after `expiresOn`; stale waivers fail the
gate. Waivers must never be used to bypass an unknown licence or missing source
text. Counsel decides compatibility when obligations or distribution rights
are unclear.

## Deterministic verification

Generate and verify the exact inventory:

```sh
dart scripts/generate_cyclonedx_sbom.dart \
  --output build/release-evidence/sbom.cdx.json \
  --license-evidence config/dependency_license_evidence.json
dart scripts/verify_sbom_license_policy.dart \
  --sbom build/release-evidence/sbom.cdx.json \
  --policy config/dependency_license_policy.json
```

Kuyruğu doldurmadan önce, çözümlenmiş artefaktların **kendi lisans baytlarını**
çevrimdışı toplayın. Bu adım incelemenin mekanik yarısıdır (exact artefaktı bulmak,
baytları okumak, hash'lemek); hesap verebilir yarısını yapmaz:

```sh
python3 scripts/harvest_license_evidence.py \
  --sbom build/release-evidence/sbom.cdx.json \
  --evidence config/dependency_license_evidence.json \
  --output build/release-evidence/license-evidence-proposal.json \
  --text-output-dir build/release-evidence/license-texts
```

Araç hiçbir koşulda SPDX kimliği tahmin etmez, `reviewedBy`/`reviewedAt` üretmez,
ağdan indirme yapmaz ve `config/dependency_license_evidence.json` dosyasına yazmaz;
`--output` o dosyayı gösterirse fail-closed çıkar. Çıktının kök anahtarı `entries`
değil `candidates` olduğu için hiçbir kapı onu kanıt olarak kabul edemez. Bu
sözleşmeler `test/license_evidence_harvest_test.dart` ile pinlenmiştir.

Kayıtlar üç durumdan birini taşır:

| Durum | Anlamı | Reviewer'ın işi |
| --- | --- | --- |
| `ALREADY_REVIEWED` | Hesap verebilir kanıt dosyasında zaten var | Yok |
| `HUMAN_REVIEW_REQUIRED` | Exact baytlar toplandı ve hash'lendi | Metni oku, SPDX'e karar ver, adını/tarihini yaz |
| `UNRESOLVED` | Artefakt UTF-8 lisans metni taşımıyor | Primary upstream metni kendin getir |

Maven kayıtlarında `pomDeclaration`, yayımlanmış POM'un beyan ettiği ad/URL'dir —
upstream hakkında bir olgudur, lisans kararı değildir. SPDX'i yine tam metinden
doğrulayın.

`--text-output-dir` çıktısı `build/` altında kalır. Bir kaydı kanıt hâline
getirirken ilgili `<sha256>.txt` dosyasını `config/license-texts/` altına siz
taşırsınız; böylece depoya yalnız gerçekten incelenmiş baytlar girer.

İnsan inceleme kuyruğunu hiçbir lisansı tahmin etmeden üretmek için:

```sh
python3 scripts/prepare_license_review_queue.py \
  --sbom build/release-evidence/sbom.cdx.json \
  --evidence config/dependency_license_evidence.json \
  --output build/release-evidence/license-review-queue.json
```

Queue'daki `registryReference` yalnız exact koordinata giden başlangıç
noktasıdır; `primarySourceUrl`, SPDX kararı, reviewed bytes hash'i ve reviewer
alanları insan tarafından tamamlanmadıkça kayıt `HUMAN_REVIEW_REQUIRED` kalır.

Kuyruğu dört gerçek ve hesap verebilir reviewer arasında dengeli dağıtmak için
stable kurum/ekip kimliklerini verin:

```sh
python3 scripts/prepare_license_review_assignments.py \
  --queue build/release-evidence/license-review-queue.json \
  --reviewer reviewer-a@organization \
  --reviewer reviewer-b@organization \
  --reviewer reviewer-c@organization \
  --reviewer reviewer-d@organization \
  --output build/release-evidence/license-review-assignments.json
```

Assignment çıktısı yalnız iş dağılımıdır; lisans incelemesi veya hukuk onayı
değildir. Araç SPDX, primary-source URL, reviewed bytes hash'i ya da tamamlanmış
durum üretmez. Placeholder reviewer kimliğiyle oluşturulan dry-run çıktısı
release evidence'a alınmaz. Mevcut insan inceleme sayısı bu alanlar gerçek
kişilerce tamamlanana kadar `0/400` kalır.

All 400 records are complete only after generating the shipped notice:

```sh
python3 scripts/generate_third_party_notices.py \
  --sbom build/release-evidence/sbom.cdx.json \
  --evidence config/dependency_license_evidence.json \
  --license-text-dir config/license-texts \
  --output assets/legal/THIRD_PARTY_NOTICES.txt
```

The generator is offline and fail closed. It requires exact purl parity,
accountable review fields, a primary-source HTTPS URL, and a local text whose
bytes match the recorded hash. The release workflow regenerates the file into
`build/release-evidence`, compares it byte-for-byte with the asset packaged in
the AAB, and includes its hash in provenance schema v2. The current tracked
asset says `NOT A PRODUCTION CANDIDATE`; deleting that sentence manually does
not satisfy any gate.

The only passing terminal line is:

```text
LICENSE_POLICY_PASS: <count> components have reviewed evidence
```

The tagged release copies the reviewed SBOM and Gradle verification metadata
into the evidence bundle and hashes both. Any dependency or lockfile change
invalidates this review for the changed component set and requires regeneration
plus review of all new or changed exact purls.

## Acceptance record

The release owner closes this item only when:

- SBOM status is `VERIFIED` for the exact candidate lockfiles;
- the policy verifier exits zero without a waiver that expires before release;
- every custom, copyleft, dual, unknown, asset, font, and native licence has an
  explicit disposition;
- required attribution/notices are included in the shipped app or distribution
  materials;
- the evidence bundle contains SBOM, Gradle checksum metadata, policy/evidence
  files, verifier output, reviewer identity, and hashes.
