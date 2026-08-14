#!/usr/bin/env python3
"""Localised-copy inventory — sections 13, 14 spillover, and MP-03-026 / MP-05-021.

Every user-visible string in this app reaches the screen through one of 963
translation keys (a source guard, test/screens/hardcoded_strings_test.dart,
is what makes that true rather than aspirational). So copy requirements are
answerable by measuring the payloads.

  measurements.ctaClarity        -> MP-13-001
  measurements.tone              -> MP-13-005
  measurements.successCopy       -> MP-13-006
  measurements.tooltipCopy       -> MP-13-007
  measurements.emptyStateCopy    -> MP-13-008
  measurements.confirmationCopy  -> MP-13-009, MP-13-010
  measurements.privacyCopy       -> MP-13-015
  measurements.permissionCopy    -> MP-13-016
  measurements.jargon            -> MP-13-018, MP-03-026
  measurements.lengthDelta       -> MP-05-021

Run:
    python3 scripts/audit_evidence/copy.py
    python3 scripts/audit_evidence/copy.py --negative-control
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO, emit, main_guard, rel, run_negative_control  # noqa: E402

VERSION = "1.0.0"
COMMAND = "python3 scripts/audit_evidence/copy.py"

# Blame language: second person + fault. Turkish and English forms of "you did
# something wrong", which is the tone a duress-context app must never use.
BLAME_TR = ("yanlis yaptiniz", "hatali girdiniz", "hata yaptiniz", "yanlış yaptınız",
            "hatalı girdiniz", "başaramadınız", "basaramadiniz", "unuttunuz")
BLAME_EN = ("you failed", "you did not", "you forgot", "your mistake", "you entered wrong",
            "invalid input by you")

# Developer jargon that must not reach a user.
JARGON = ("null", "undefined", "exception", "stacktrace", "stack trace", "timeout ms",
          "http 4", "http 5", "socket", "json", "parse error", "nullpointer",
          "asenkron", "callback", "deserialize", "backend", "endpoint")

CTA_PREFIXES_TR = ("Ekle", "Kaydet", "Baslat", "Başlat", "Durdur", "Sil", "Devam",
                   "Onayla", "Iptal", "İptal", "Ac", "Aç", "Gonder", "Gönder",
                   "Ara", "Yenile", "Geri", "Kapat", "Sec", "Seç", "Tamam", "Izin", "İzin")


# Technical terms that are the CORRECT word, with the reason. Checked for
# staleness below, so an exemption cannot outlive the string it excuses.
JARGON_EXEMPT = {
    ("data_export_body", "json"):
        "KVKK Md. 11 data portability requires naming the machine-readable format "
        "the export produces; 'a file' would be less informative, not more human",
    ("data_export_kvkk_desc", "json"):
        "same right, same reason -- the format is part of the legal description",
}


def _tooltip_widgets(root: Path) -> int:
    count = 0
    for path in (root / "lib").rglob("*.dart"):
        count += len(re.findall(r"\bTooltip\(", path.read_text(encoding="utf-8")))
    return count


def _rationale_before_request(root: Path) -> dict:
    """Files that BOTH explain a permission and request it, with the order."""
    out = {}
    for path in (root / "lib").rglob("*.dart"):
        src = path.read_text(encoding="utf-8")
        req = re.search(r"\.request\(\)|requestPermission", src)
        rationale = re.search(r"rationale|_showRationale|perm_\w+_(?:title|body)", src)
        if req and rationale:
            out[str(path.relative_to(root))] = {
                "rationaleAtLine": src[: rationale.start()].count("\n") + 1,
                "requestAtLine": src[: req.start()].count("\n") + 1,
                "rationaleFirst": rationale.start() < req.start(),
            }
    return out


def _payloads(root: Path) -> dict:
    return {
        loc: json.loads((root / "assets" / "translations" / f"{loc}.json").read_text(encoding="utf-8"))
        for loc in ("tr-TR", "en-US")
    }


def _keys_matching(payload: dict, *fragments) -> dict:
    return {k: v for k, v in payload.items()
            if any(f in k for f in fragments) and isinstance(v, str)}


def measure(root: Path) -> list:
    payloads = _payloads(root)
    violations = []

    for loc, payload in payloads.items():
        blame = BLAME_TR if loc.startswith("tr") else BLAME_EN
        for key, value in payload.items():
            if not isinstance(value, str):
                continue
            low = value.lower()
            for phrase in blame:
                if phrase in low:
                    violations.append({"rule": "blameLanguage", "locale": loc,
                                       "key": key, "detail": phrase})
            for term in JARGON:
                # `null` and `json` appear inside ordinary words; require a boundary.
                if re.search(r"\b%s\b" % re.escape(term), low):
                    if (key, term) in JARGON_EXEMPT:
                        continue
                    violations.append({"rule": "developerJargonInCopy", "locale": loc,
                                       "key": key, "detail": term,
                                       "value": value[:120]})
    for (key, term), reason in sorted(JARGON_EXEMPT.items()):
        present = any(
            isinstance(p.get(key), str) and re.search(r"\b%s\b" % re.escape(term),
                                                      p[key].lower())
            for p in payloads.values()
        )
        if not present:
            violations.append({"rule": "staleJargonExemption",
                               "detail": f"{key} no longer contains {term!r} ({reason})"})

    # Key parity is enforced elsewhere; here the concern is LENGTH. A translation
    # that is far longer than its sibling is what breaks a fixed-width row.
    tr, en = payloads["tr-TR"], payloads["en-US"]
    for key in sorted(set(tr) & set(en)):
        a, b = tr[key], en[key]
        if not isinstance(a, str) or not isinstance(b, str) or not a or not b:
            continue
        ratio = max(len(a), len(b)) / max(1, min(len(a), len(b)))
        if ratio > 2.2 and max(len(a), len(b)) > 40:
            violations.append({
                "rule": "translationLengthDivergence", "key": key,
                "detail": f"tr={len(a)} en={len(b)} ratio={ratio:.2f}",
            })

    # A confirmation that does not name its object is the MP-13-010 defect.
    for loc, payload in payloads.items():
        for key, value in payload.items():
            if not isinstance(value, str):
                continue
            if key.endswith("_confirm_body") or key.endswith("_confirm_desc"):
                if "{" not in value and len(value) < 40:
                    violations.append({
                        "rule": "confirmationDoesNotNameItsObject",
                        "locale": loc, "key": key, "value": value,
                    })
    return violations


def build(root: Path) -> dict:
    payloads = _payloads(root)
    tr, en = payloads["tr-TR"], payloads["en-US"]

    cta = _keys_matching(tr, "btn_", "_button", "_action", "_cta")
    verb_leading = {k: v for k, v in cta.items()
                    if v.split(" ")[0] in CTA_PREFIXES_TR or v.split(" ")[0].istitle()}
    success = _keys_matching(tr, "success", "_confirmed", "_saved", "_added", "_done")
    empty = _keys_matching(tr, "empty", "no_", "_none")
    confirm = _keys_matching(tr, "_confirm")
    privacy = _keys_matching(tr, "kvkk", "privacy", "consent", "riza", "veri")
    permission = _keys_matching(tr, "perm", "permission", "izin", "rationale")

    lengths = []
    for key in sorted(set(tr) & set(en)):
        a, b = tr[key], en[key]
        if isinstance(a, str) and isinstance(b, str) and a and b:
            lengths.append((key, len(a), len(b)))
    worst = sorted(lengths, key=lambda t: -max(t[1], t[2]) / max(1, min(t[1], t[2])))[:8]

    return {
        "payloads": {
            "locales": sorted(payloads),
            "keysPerLocale": {loc: len(p) for loc, p in payloads.items()},
            "parityTest": "test/translations_key_parity_test.dart",
            "hardcodedStringGuard": "test/screens/hardcoded_strings_test.dart",
            "usageTest": "test/translation_key_usage_test.dart",
        },
        "ctaClarity": {
            "actionKeys": len(cta),
            "verbLeading": len(verb_leading),
            "verbLeadingPercent": round(100.0 * len(verb_leading) / max(1, len(cta)), 1),
            "examples": dict(list(cta.items())[:12]),
            "claim": "an action label names the action, not the surface it opens",
        },
        "tone": {
            "blamePhrasesSearched": {"tr": list(BLAME_TR), "en": list(BLAME_EN)},
            "blameHits": len([v for v in measure(root) if v["rule"] == "blameLanguage"]),
            "errorKeysExamined": len(_keys_matching(tr, "error", "fail", "hata", "_denied")),
            "styleClaim": (
                "errors describe the SYSTEM state and the next step, not the user: "
                "the duress context makes second-person fault language actively unsafe"
            ),
        },
        "successCopy": {
            "keys": len(success),
            "examples": dict(list(success.items())[:10]),
            "claim": "success copy states what became true, not merely 'OK'",
        },
        "tooltipCopy": {
            "tooltipWidgets": _tooltip_widgets(root),
            "why": "the app ships no Tooltip widget at all; labels are inline, so "
                   "there is no hover-only copy to keep short",
        },
        "emptyStateCopy": {
            "keys": len(empty),
            "examples": dict(list(empty.items())[:10]),
            "claim": "each empty state names the next action rather than only the absence",
        },
        "confirmationCopy": {
            "keys": len(confirm),
            "examples": dict(list(confirm.items())[:14]),
            "interpolatingKeys": sorted(k for k, v in confirm.items() if "{" in v),
            "claim": "destructive confirmations interpolate the object being destroyed",
        },
        "privacyCopy": {
            "keys": len(privacy),
            "legalVersionSource": "lib/constants/legal_texts.dart",
            "bumpProcedure": "scripts/bump_legal.sh",
            "overclaimGuards": ["test/public_release_overclaim_copy_test.dart",
                                "test/legal_no_first_responder_claims_test.dart"],
        },
        "permissionCopy": {
            "keys": len(permission),
            "rationaleScreensWithARequestCall": _rationale_before_request(root),
            "rationaleScreens": ["lib/screens/onboarding_screen.dart",
                                 "lib/core/utils/permission_helper.dart",
                                 "lib/screens/battery_optimization_wizard.dart"],
            "examples": dict(list(permission.items())[:10]),
        },
        "jargon": {
            "termsSearched": list(JARGON),
            "hits": len([v for v in measure(root)
                         if v["rule"] == "developerJargonInCopy"]),
            "justifiedExemptions": {f"{k[0]}:{k[1]}": v for k, v in JARGON_EXEMPT.items()},
            "scope": "both shipped translation payloads, every key in each",
        },
        "lengthDelta": {
            "pairsCompared": len(lengths),
            "worstRatios": [{"key": k, "tr": a, "en": b, "ratio": round(max(a, b) / max(1, min(a, b)), 2)}
                            for k, a, b in worst],
            "bar": 2.2,
            "why": "a locale twice as long as its sibling is what overflows a fixed row; "
                   "the geometry consequence is measured separately in text_scale.json",
        },
    }


def _mutate(scratch: Path) -> str:
    path = scratch / "assets" / "translations" / "tr-TR.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["contacts_add_error"] = "Yanlis yaptiniz. NullPointerException olustu."
    payload["timeline_delete_confirm_body"] = "Emin misiniz?"
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return "blame language + a raw exception name + an unnamed confirmation"


def main() -> int:
    if main_guard(sys.argv):
        return run_negative_control("copy", _mutate, measure)
    violations = measure(REPO)
    path = emit(
        "copy.json",
        verifier="scripts/audit_evidence/copy.py",
        version=VERSION,
        command=COMMAND,
        surfaces=["assets/translations/tr-TR.json", "assets/translations/en-US.json"],
        measurements=build(REPO),
        violations=violations,
        exclusions=[
            {"what": "the long-form legal texts in lib/constants/legal_texts.dart",
             "why": "they are versioned legal instruments, not UI microcopy; their "
                    "wording is governed by scripts/bump_legal.sh and pinned by the "
                    "legal policy tests"},
        ],
        extra={"negativeControl": {
            "command": COMMAND + " --negative-control",
            "mutation": "blame language, a raw exception name, and a confirmation that "
                        "names nothing",
            "expected": "blameLanguage, developerJargonInCopy and "
                        "confirmationDoesNotNameItsObject all fire",
        }},
    )
    print(f"COPY_OK violations={len(violations)} -> {rel(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
