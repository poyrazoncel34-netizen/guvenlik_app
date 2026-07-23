#!/usr/bin/env python3
"""Fail-closed verifier for KoruBeni's external release evidence manifest.

This script never creates evidence. It only proves that one immutable AAB is
bound to every required gate, soak, drill, finding disposition and approval.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import zipfile
from pathlib import Path

from verify_gate_evidence import (
    REQUIRED_APPROVAL_ROLES,
    REQUIRED_EVIDENCE_KINDS,
    REQUIRED_GATE_OWNERS,
    accountable_identity,
    exact_string_set,
    parse_utc,
    validate_gate_evidence,
)
from verify_masvs_assessment import validate_assessment


EXPECTED_GATES = {f"G{i}" for i in range(11)}
REQUIRED_PROVENANCE_ARTIFACTS = {
    "aab",
    "androidReleaseSurface",
    "sbom",
    "mergedManifest",
    "r8Mapping",
    "dartSymbolsIndex",
    "nativeSymbolsIndex",
    "criticalCoverage",
    "mutationReport",
    "lintReport",
    "dependencyLockPub",
    "dependencyLockGradle",
    "gradleVerification",
    "sourceProvenance",
    "secretScan",
    "osvAudit",
    "thirdPartyNotices",
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
EMPTY_SHA256 = hashlib.sha256(b"").hexdigest()
TAG_RE = re.compile(r"^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
WORKFLOW_URL_RE = re.compile(
    r"^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/actions/runs/[0-9]+$"
)
EXPECTED_MUTATION_IDS = {
    "M01_CANCEL_RESULT_SWALLOWED",
    "M02_STALE_GENERATION_ACCEPTED",
    "M03_PIN_READ_FAILURE_AS_ABSENT",
    "M04_LOG_BEFORE_DISPATCH",
    "M05_NOTIFICATION_RESULT_IGNORED",
    "M06_DISPOSE_NATIVE_CANCEL",
}
EXPECTED_CRITICAL_COVERAGE_PATHS = {
    "lib/core/services/emergency_session_contract.dart",
    "lib/core/services/emergency_platform_service.dart",
    "lib/core/services/pin_verification_service.dart",
    "lib/core/services/check_in_service.dart",
}
EXPECTED_ANDROID_PERMISSIONS = {
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.CALL_PHONE",
    "android.permission.INTERNET",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
    "android.permission.SCHEDULE_EXACT_ALARM",
    "android.permission.VIBRATE",
    "android.permission.WAKE_LOCK",
    "com.android.vending.BILLING",
    "com.poyrazoncel.korubeni.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION",
}
EXPECTED_SAFETY_COMPONENTS = {
    "com.poyrazoncel.korubeni.emergency.EmergencyFallbackDialActivity",
    "com.poyrazoncel.korubeni.emergency.CheckInAlarmReceiver",
    "com.poyrazoncel.korubeni.emergency.CountdownAlarmReceiver",
    "com.poyrazoncel.korubeni.emergency.BootCompletedReceiver",
    "com.poyrazoncel.korubeni.emergency.ExactAlarmPermissionReceiver",
    "com.poyrazoncel.korubeni.emergency.ClockChangeReceiver",
    "com.poyrazoncel.korubeni.emergency.EmergencyFallbackCleanupReceiver",
}
EXPECTED_SURFACE_LIMITATIONS = {
    "MERGED_MANIFEST_AND_SOURCE_RESOURCE_AUDIT_ONLY",
    "NOT_RUNTIME_INTENT_FUZZING",
    "NOT_PRODUCTION_AAB_UNLESS_RUN_BY_TAGGED_WORKFLOW",
}
REQUIRED_AAB_ENTRIES = {
    "BundleConfig.pb",
    "base/manifest/AndroidManifest.xml",
    "base/resources.pb",
}
MAX_AAB_FILE_BYTES = 512 * 1024 * 1024
MAX_AAB_UNCOMPRESSED_BYTES = 1024 * 1024 * 1024
CERTIFICATE_SHA256_RE = re.compile(
    r"(?m)^\s*SHA256:\s*((?:[0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2})\s*$"
)
NATIVE_LIBRARY_RE = re.compile(r"^[^/]+/lib/([^/]+)/.+\.so$")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def safe_aab_member_name(name: str, is_directory: bool) -> bool:
    if not name or "\x00" in name or "\\" in name or name.startswith("/"):
        return False
    candidate = name[:-1] if is_directory and name.endswith("/") else name
    if not candidate or re.match(r"^[A-Za-z]:", candidate):
        return False
    return all(part not in {"", ".", ".."} for part in candidate.split("/"))


def validate_candidate_aab(path: Path, errors: list[str]) -> str | None:
    """Validate the upload artifact itself and return its signer fingerprint.

    Upload keys use self-signed certificates, so jarsigner's strict exit bit 4
    (certificate chain not trusted) is expected. Every other strict warning bit,
    including bit 16 for unsigned entries, remains fatal.
    """

    try:
        file_size = path.stat().st_size
    except OSError as exc:
        errors.append(f"candidate AAB cannot be inspected: {exc}")
        return None
    if file_size <= 0 or file_size > MAX_AAB_FILE_BYTES:
        errors.append("candidate AAB file size is outside the allowed range")
        return None
    if not zipfile.is_zipfile(path):
        errors.append("candidate AAB is not a ZIP archive")
        return None

    try:
        with zipfile.ZipFile(path) as archive:
            members = archive.infolist()
            names: set[str] = set()
            native_abis: set[str] = set()
            native_library_count = 0
            total_uncompressed = 0
            for member in members:
                if member.filename in names:
                    errors.append(f"candidate AAB contains duplicate ZIP entry: {member.filename}")
                names.add(member.filename)
                if not safe_aab_member_name(member.filename, member.is_dir()):
                    errors.append(f"candidate AAB contains unsafe ZIP entry: {member.filename}")
                unix_mode = (member.external_attr >> 16) & 0xFFFF
                if stat.S_IFMT(unix_mode) == stat.S_IFLNK:
                    errors.append(f"candidate AAB contains symbolic-link entry: {member.filename}")
                if member.flag_bits & 0x1:
                    errors.append(f"candidate AAB contains encrypted ZIP entry: {member.filename}")
                total_uncompressed += member.file_size
                native_match = NATIVE_LIBRARY_RE.fullmatch(member.filename)
                if native_match:
                    native_library_count += 1
                    native_abis.add(native_match.group(1))
            if total_uncompressed > MAX_AAB_UNCOMPRESSED_BYTES:
                errors.append("candidate AAB uncompressed size exceeds the allowed limit")
            missing_entries = REQUIRED_AAB_ENTRIES - names
            if missing_entries:
                errors.append(
                    "candidate AAB is missing required entries: "
                    + ", ".join(sorted(missing_entries))
                )
            for required_name in REQUIRED_AAB_ENTRIES.intersection(names):
                if archive.getinfo(required_name).file_size <= 0:
                    errors.append(f"candidate AAB required entry is empty: {required_name}")
            if native_library_count == 0:
                errors.append("candidate AAB contains no native libraries")
            if native_abis != {"arm64-v8a"}:
                errors.append(
                    "candidate AAB native ABI set must be arm64-v8a only"
                )
    except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile) as exc:
        errors.append(f"candidate AAB ZIP cannot be inspected: {exc}")
        return None

    if errors:
        return None

    alignment_verifier = Path(__file__).resolve().with_name("verify_16kb_alignment.sh")
    if not alignment_verifier.is_file() or not os.access(alignment_verifier, os.X_OK):
        errors.append("16 KB alignment verifier is missing or not executable")
        return None
    try:
        alignment = subprocess.run(
            [str(alignment_verifier), str(path.resolve())],
            capture_output=True,
            check=False,
            text=True,
            timeout=120,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        errors.append(f"candidate AAB 16 KB verification could not run: {exc}")
        return None
    if alignment.returncode != 0:
        errors.append(
            "candidate AAB 16 KB verification failed "
            f"(verifier exit {alignment.returncode})"
        )
        return None

    jarsigner = shutil.which("jarsigner")
    if jarsigner is None:
        errors.append("jarsigner is required for strict candidate AAB verification")
        return None
    command_environment = os.environ.copy()
    command_environment.update({"LANG": "C", "LC_ALL": "C"})
    try:
        verified = subprocess.run(
            [jarsigner, "-verify", "-strict", str(path.resolve())],
            capture_output=True,
            check=False,
            text=True,
            timeout=120,
            env=command_environment,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        errors.append(f"candidate AAB strict signature verification could not run: {exc}")
        return None
    if verified.returncode not in {0, 4}:
        errors.append(
            "candidate AAB strict signature verification failed "
            f"(jarsigner exit {verified.returncode})"
        )
        return None

    keytool = shutil.which("keytool")
    if keytool is None:
        errors.append("keytool is required to identify the candidate AAB signer")
        return None
    try:
        certificate = subprocess.run(
            [keytool, "-printcert", "-jarfile", str(path.resolve())],
            capture_output=True,
            check=False,
            text=True,
            timeout=120,
            env=command_environment,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        errors.append(f"candidate AAB signer certificate could not be read: {exc}")
        return None
    if certificate.returncode != 0:
        errors.append("candidate AAB signer certificate could not be read")
        return None
    fingerprints = {
        match.replace(":", "").lower()
        for match in CERTIFICATE_SHA256_RE.findall(certificate.stdout)
    }
    if len(fingerprints) != 1:
        errors.append("candidate AAB must have exactly one identifiable signer certificate")
        return None
    return fingerprints.pop()


def read_json_artifact(
    name: str,
    artifacts: dict[str, Path],
    errors: list[str],
) -> dict[str, object] | None:
    path = artifacts.get(name)
    if path is None or not path.is_file():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        errors.append(f"provenance artifact {name} cannot be parsed: {exc}")
        return None
    if not isinstance(payload, dict):
        errors.append(f"provenance artifact {name} must be a JSON object")
        return None
    return payload


def validate_clean_source_binding(
    name: str,
    payload: dict[str, object],
    candidate: dict[str, object],
    errors: list[str],
) -> None:
    source = payload.get("source")
    require(isinstance(source, dict), f"{name} source is missing", errors)
    if not isinstance(source, dict):
        return
    require(
        source.get("gitCommit") == candidate.get("gitCommit"),
        f"{name} gitCommit mismatch",
        errors,
    )
    require(
        source.get("gitTree") == candidate.get("gitTree"),
        f"{name} gitTree mismatch",
        errors,
    )
    require(source.get("sourceWasDirty") is False, f"{name} source is dirty", errors)
    require(
        source.get("sourceStatusSha256") == EMPTY_SHA256,
        f"{name} clean source status hash mismatch",
        errors,
    )


def successful_command_record(value: object) -> bool:
    return (
        isinstance(value, dict)
        and value.get("exitCode") == 0
        and value.get("timedOut") is False
        and bool(SHA256_RE.fullmatch(str(value.get("outputSha256", ""))))
    )


def validate_mutation_artifact(
    payload: dict[str, object],
    candidate: dict[str, object],
    errors: list[str],
) -> None:
    require(payload.get("schemaVersion") == 1, "mutationReport schemaVersion must be 1", errors)
    require(payload.get("status") == "PASS", "mutationReport is not PASS", errors)
    require(
        payload.get("sourceHead") == candidate.get("gitCommit"),
        "mutationReport sourceHead mismatch",
        errors,
    )
    require(payload.get("sourceWasDirty") is False, "mutationReport source is dirty", errors)
    require(
        payload.get("sourceStatusSha256") == EMPTY_SHA256,
        "mutationReport clean source status hash mismatch",
        errors,
    )
    require(
        bool(SHA256_RE.fullmatch(str(payload.get("runnerSha256", "")))),
        "mutationReport runner hash is invalid",
        errors,
    )
    source_files = payload.get("sourceFiles")
    require(
        isinstance(source_files, dict) and bool(source_files),
        "mutationReport sourceFiles are missing",
        errors,
    )
    if isinstance(source_files, dict):
        for path, digest in source_files.items():
            require(
                isinstance(path, str)
                and bool(path)
                and not Path(path).is_absolute()
                and ".." not in Path(path).parts,
                "mutationReport source file path is invalid",
                errors,
            )
            require(
                bool(SHA256_RE.fullmatch(str(digest))),
                f"mutationReport source file hash is invalid: {path}",
                errors,
            )
    require(
        successful_command_record(payload.get("preparation")),
        "mutationReport preparation did not pass",
        errors,
    )
    baselines = payload.get("baselines")
    require(isinstance(baselines, list), "mutationReport baselines are missing", errors)
    if isinstance(baselines, list):
        baseline_by_name = {
            item.get("name"): item
            for item in baselines
            if isinstance(item, dict) and isinstance(item.get("name"), str)
        }
        require(
            set(baseline_by_name) == {"flutter", "native"}
            and len(baselines) == 2,
            "mutationReport baseline set mismatch",
            errors,
        )
        for name, record in baseline_by_name.items():
            require(
                successful_command_record(record),
                f"mutationReport {name} baseline did not pass",
                errors,
            )
    mutations = payload.get("mutations")
    require(isinstance(mutations, list), "mutationReport mutations are missing", errors)
    if isinstance(mutations, list):
        by_id = {
            item.get("id"): item
            for item in mutations
            if isinstance(item, dict) and isinstance(item.get("id"), str)
        }
        require(
            set(by_id) == EXPECTED_MUTATION_IDS and len(mutations) == len(EXPECTED_MUTATION_IDS),
            "mutationReport mutation set mismatch",
            errors,
        )
        for mutation_id, record in by_id.items():
            require(record.get("status") == "KILLED", f"mutationReport survivor: {mutation_id}", errors)
            result = record.get("result")
            killed_by_test = (
                isinstance(result, dict)
                and isinstance(result.get("exitCode"), int)
                and not isinstance(result.get("exitCode"), bool)
                and result.get("exitCode") not in {0, 124, 125}
                and result.get("timedOut") is False
                and bool(SHA256_RE.fullmatch(str(result.get("outputSha256", ""))))
            )
            require(killed_by_test, f"mutationReport invalid kill result: {mutation_id}", errors)


def validate_critical_coverage_artifact(
    payload: dict[str, object],
    errors: list[str],
) -> None:
    require(payload.get("schemaVersion") == 1, "criticalCoverage schemaVersion must be 1", errors)
    require(payload.get("result") == "PASS", "criticalCoverage is not PASS", errors)
    require(
        payload.get("minimumLineCoveragePercent") == 90,
        "criticalCoverage minimum must be 90%",
        errors,
    )
    files = payload.get("files")
    require(isinstance(files, list), "criticalCoverage files are missing", errors)
    if not isinstance(files, list):
        return
    by_path = {
        item.get("path"): item
        for item in files
        if isinstance(item, dict) and isinstance(item.get("path"), str)
    }
    require(
        set(by_path) == EXPECTED_CRITICAL_COVERAGE_PATHS
        and len(files) == len(EXPECTED_CRITICAL_COVERAGE_PATHS),
        "criticalCoverage file set mismatch",
        errors,
    )
    for path, record in by_path.items():
        found = record.get("linesFound")
        hit = record.get("linesHit")
        valid_counts = (
            isinstance(found, int)
            and not isinstance(found, bool)
            and found > 0
            and isinstance(hit, int)
            and not isinstance(hit, bool)
            and 0 <= hit <= found
        )
        require(valid_counts, f"criticalCoverage invalid line counts: {path}", errors)
        if not valid_counts:
            continue
        require(hit * 100 >= found * 90, f"criticalCoverage file is below 90%: {path}", errors)
        reported = record.get("lineCoveragePercent")
        expected = round(hit * 100 / found, 2)
        require(
            isinstance(reported, (int, float))
            and not isinstance(reported, bool)
            and abs(float(reported) - expected) < 0.005,
            f"criticalCoverage reported percentage mismatch: {path}",
            errors,
        )


def validate_android_surface_artifact(
    payload: dict[str, object],
    errors: list[str],
) -> None:
    require(payload.get("schemaVersion") == 1, "androidReleaseSurface schemaVersion must be 1", errors)
    require(payload.get("status") == "PASS", "androidReleaseSurface is not PASS", errors)
    require(payload.get("candidateBound") is False, "androidReleaseSurface candidateBound contract changed", errors)
    require(
        payload.get("expectedPackage") == "com.poyrazoncel.korubeni",
        "androidReleaseSurface package mismatch",
        errors,
    )
    require(payload.get("minSdk") == 29, "androidReleaseSurface minSdk mismatch", errors)
    require(payload.get("targetSdk") == 36, "androidReleaseSurface targetSdk mismatch", errors)
    for field in ("manifestSha256", "networkSecurityConfigSha256", "dataExtractionRulesSha256"):
        require(
            bool(SHA256_RE.fullmatch(str(payload.get(field, "")))),
            f"androidReleaseSurface {field} is invalid",
            errors,
        )
    permissions = payload.get("permissions")
    permission_set = set(permissions) if isinstance(permissions, list) and all(isinstance(item, str) for item in permissions) else set()
    require(permission_set == EXPECTED_ANDROID_PERMISSIONS, "androidReleaseSurface permission set mismatch", errors)
    require(
        payload.get("permissionCount") == len(permission_set)
        and isinstance(permissions, list)
        and len(permissions) == len(permission_set),
        "androidReleaseSurface permission count mismatch",
        errors,
    )
    require(
        payload.get("unprotectedExportedComponents") == [],
        "androidReleaseSurface contains unprotected exported components",
        errors,
    )
    components = payload.get("components")
    require(isinstance(components, list) and bool(components), "androidReleaseSurface components are missing", errors)
    if isinstance(components, list):
        by_name = {
            item.get("name"): item
            for item in components
            if isinstance(item, dict) and isinstance(item.get("name"), str)
        }
        require(
            len(by_name) == len(components)
            and payload.get("componentCount") == len(components),
            "androidReleaseSurface component count mismatch",
            errors,
        )
        safety_names = EXPECTED_SAFETY_COMPONENTS.intersection(by_name)
        require(
            safety_names == EXPECTED_SAFETY_COMPONENTS,
            "androidReleaseSurface safety component set mismatch",
            errors,
        )
        for name in safety_names:
            record = by_name[name]
            require(
                record.get("exported") is False and record.get("directBootAware") is True,
                f"androidReleaseSurface unsafe safety component: {name}",
                errors,
            )
        allowed_exported = {
            "com.poyrazoncel.korubeni.MainActivity",
            "androidx.profileinstaller.ProfileInstallReceiver",
        }
        exported_names = {
            name for name, record in by_name.items() if record.get("exported") is True
        }
        require(
            exported_names.issubset(allowed_exported)
            and "com.poyrazoncel.korubeni.MainActivity" in exported_names,
            "androidReleaseSurface exported component allowlist mismatch",
            errors,
        )
    limitations = payload.get("limitations")
    limitation_set = set(limitations) if isinstance(limitations, list) and all(isinstance(item, str) for item in limitations) else set()
    require(
        limitation_set == EXPECTED_SURFACE_LIMITATIONS,
        "androidReleaseSurface limitation set mismatch",
        errors,
    )


def property_map(value: object) -> dict[str, str]:
    if not isinstance(value, list):
        return {}
    result: dict[str, str] = {}
    for item in value:
        if not isinstance(item, dict):
            continue
        name = item.get("name")
        property_value = item.get("value")
        if isinstance(name, str) and isinstance(property_value, str) and name not in result:
            result[name] = property_value
    return result


def validate_sbom_artifact(
    payload: dict[str, object],
    osv_audit: dict[str, object] | None,
    errors: list[str],
) -> None:
    require(payload.get("bomFormat") == "CycloneDX", "sbom format must be CycloneDX", errors)
    require(payload.get("specVersion") == "1.6", "sbom specVersion must be 1.6", errors)
    require(payload.get("version") == 1, "sbom version must be 1", errors)
    metadata = payload.get("metadata")
    require(isinstance(metadata, dict), "sbom metadata is missing", errors)
    metadata_properties = property_map(metadata.get("properties")) if isinstance(metadata, dict) else {}
    require(
        metadata_properties.get("korubeni:licenseEvidenceStatus") == "VERIFIED",
        "sbom license evidence status is not VERIFIED",
        errors,
    )
    require(
        metadata_properties.get("korubeni:sourceOfTruth") == "pubspec.lock+android/app/gradle.lockfile",
        "sbom source of truth mismatch",
        errors,
    )
    components = payload.get("components")
    require(isinstance(components, list) and bool(components), "sbom components are missing", errors)
    if not isinstance(components, list):
        return
    seen: set[str] = set()
    ecosystem_counts = {"Pub": 0, "Maven": 0}
    for component in components:
        require(isinstance(component, dict), "sbom component is malformed", errors)
        if not isinstance(component, dict):
            continue
        purl = component.get("purl")
        valid_purl = isinstance(purl, str) and purl.startswith("pkg:") and purl not in seen
        require(valid_purl, f"sbom missing or duplicate purl: {purl}", errors)
        if not valid_purl:
            continue
        seen.add(purl)
        if purl.startswith("pkg:pub/"):
            ecosystem_counts["Pub"] += 1
        elif purl.startswith("pkg:maven/"):
            ecosystem_counts["Maven"] += 1
        else:
            errors.append(f"sbom unsupported runtime purl: {purl}")
        licenses = component.get("licenses")
        license_id = None
        if isinstance(licenses, list) and len(licenses) == 1 and isinstance(licenses[0], dict):
            license_record = licenses[0].get("license")
            if isinstance(license_record, dict):
                license_id = license_record.get("id")
        require(isinstance(license_id, str) and bool(license_id), f"sbom reviewed SPDX decision missing: {purl}", errors)
        properties = property_map(component.get("properties"))
        require(
            properties.get("korubeni:licenseEvidenceUrl", "").startswith("https://")
            and bool(SHA256_RE.fullmatch(properties.get("korubeni:licenseEvidenceSha256", "")))
            and bool(properties.get("korubeni:licenseReviewedBy"))
            and bool(re.fullmatch(r"\d{4}-\d{2}-\d{2}", properties.get("korubeni:licenseReviewedAt", ""))),
            f"sbom reviewed license evidence is incomplete: {purl}",
            errors,
        )
    if isinstance(osv_audit, dict):
        ecosystems = osv_audit.get("ecosystems")
        if isinstance(ecosystems, dict):
            for name, count in ecosystem_counts.items():
                record = ecosystems.get(name)
                if isinstance(record, dict):
                    require(
                        record.get("queryCount") == count,
                        f"sbom {name} component count does not match OSV query count",
                        errors,
                    )
def validate_candidate_security_artifacts(
    artifacts: dict[str, Path],
    candidate: dict[str, object],
    errors: list[str],
) -> None:
    secret_scan = read_json_artifact("secretScan", artifacts, errors)
    if secret_scan is not None:
        require(secret_scan.get("schemaVersion") == 2, "secretScan schemaVersion must be 2", errors)
        require(secret_scan.get("status") == "PASS", "secretScan is not PASS", errors)
        require(
            secret_scan.get("mode") == "tracked-candidate",
            "secretScan mode is not tracked-candidate",
            errors,
        )
        require(parse_utc(secret_scan.get("scannedAt")) is not None, "secretScan scannedAt is invalid", errors)
        require(secret_scan.get("findingCount") == 0, "secretScan contains findings", errors)
        validate_clean_source_binding("secretScan", secret_scan, candidate, errors)
        scanner = secret_scan.get("scanner")
        require(isinstance(scanner, dict), "secretScan scanner identity is missing", errors)
        if isinstance(scanner, dict):
            require(
                scanner.get("name") == "scan_release_secrets.py",
                "secretScan scanner name mismatch",
                errors,
            )
            require(
                bool(SHA256_RE.fullmatch(str(scanner.get("sha256", "")))),
                "secretScan scanner hash is invalid",
                errors,
            )
        for field in ("pathSetSha256", "contentSetSha256"):
            require(
                bool(SHA256_RE.fullmatch(str(secret_scan.get(field, "")))),
                f"secretScan {field} is invalid",
                errors,
            )
        input_count = secret_scan.get("inputPathCount")
        text_count = secret_scan.get("scannedTextFileCount")
        binary_count = secret_scan.get("skippedBinaryFileCount")
        counts_are_ints = all(
            isinstance(value, int) and not isinstance(value, bool) and value >= 0
            for value in (input_count, text_count, binary_count)
        )
        require(counts_are_ints, "secretScan file counts are invalid", errors)
        if counts_are_ints:
            require(input_count > 0, "secretScan scanned no files", errors)
            require(
                text_count + binary_count == input_count,
                "secretScan file counts do not reconcile",
                errors,
            )

    osv_audit = read_json_artifact("osvAudit", artifacts, errors)
    if osv_audit is not None:
        require(osv_audit.get("schemaVersion") == 1, "osvAudit schemaVersion must be 1", errors)
        require(osv_audit.get("status") == "PASS", "osvAudit is not PASS", errors)
        require(osv_audit.get("findingCount") == 0, "osvAudit contains findings", errors)
        require(osv_audit.get("findings") == [], "osvAudit findings must be empty", errors)
        require(
            osv_audit.get("endpoint") == "https://api.osv.dev/v1/querybatch",
            "osvAudit endpoint mismatch",
            errors,
        )
        require(
            osv_audit.get("interpretation") == "noKnownFindingsAtScanTime",
            "osvAudit interpretation mismatch",
            errors,
        )
        require(parse_utc(osv_audit.get("scannedAt")) is not None, "osvAudit scannedAt is invalid", errors)
        validate_clean_source_binding("osvAudit", osv_audit, candidate, errors)
        inputs = osv_audit.get("inputs")
        require(isinstance(inputs, dict), "osvAudit inputs are missing", errors)
        if isinstance(inputs, dict):
            pub_lock = artifacts.get("dependencyLockPub")
            gradle_lock = artifacts.get("dependencyLockGradle")
            if pub_lock is not None and pub_lock.is_file():
                require(
                    inputs.get("pubspecLockSha256") == sha256(pub_lock),
                    "osvAudit pubspec lock hash mismatch",
                    errors,
                )
            if gradle_lock is not None and gradle_lock.is_file():
                require(
                    inputs.get("gradleLockSha256") == sha256(gradle_lock),
                    "osvAudit Gradle lock hash mismatch",
                    errors,
                )
            for field in ("runnerSha256", "generatorSha256"):
                require(
                    bool(SHA256_RE.fullmatch(str(inputs.get(field, "")))),
                    f"osvAudit {field} is invalid",
                    errors,
                )
        ecosystems = osv_audit.get("ecosystems")
        require(
            isinstance(ecosystems, dict) and set(ecosystems) == {"Pub", "Maven"},
            "osvAudit ecosystem set mismatch",
            errors,
        )
        if isinstance(ecosystems, dict):
            for ecosystem in ("Pub", "Maven"):
                record = ecosystems.get(ecosystem)
                require(isinstance(record, dict), f"osvAudit {ecosystem} record is missing", errors)
                if not isinstance(record, dict):
                    continue
                query_count = record.get("queryCount")
                require(
                    isinstance(query_count, int)
                    and not isinstance(query_count, bool)
                    and query_count > 0,
                    f"osvAudit {ecosystem} queryCount is invalid",
                    errors,
                )
                require(
                    record.get("findingCount") == 0,
                    f"osvAudit {ecosystem} contains findings",
                    errors,
                )
                for field in ("querySha256", "responseSha256"):
                    require(
                        bool(SHA256_RE.fullmatch(str(record.get(field, "")))),
                        f"osvAudit {ecosystem} {field} is invalid",
                        errors,
                    )

    mutation_report = read_json_artifact("mutationReport", artifacts, errors)
    if mutation_report is not None:
        validate_mutation_artifact(mutation_report, candidate, errors)

    critical_coverage = read_json_artifact("criticalCoverage", artifacts, errors)
    if critical_coverage is not None:
        validate_critical_coverage_artifact(critical_coverage, errors)

    android_surface = read_json_artifact("androidReleaseSurface", artifacts, errors)
    if android_surface is not None:
        validate_android_surface_artifact(android_surface, errors)

    sbom = read_json_artifact("sbom", artifacts, errors)
    if sbom is not None:
        validate_sbom_artifact(sbom, osv_audit, errors)


def validate_provenance(
    provenance: object,
    candidate: dict[str, object],
    actual_aab_hash: str,
    evidence_root: Path,
    provenance_path: Path,
    candidate_aab_path: Path,
    errors: list[str],
) -> None:
    require(isinstance(provenance, dict), "provenance payload must be an object", errors)
    if not isinstance(provenance, dict):
        return
    require(provenance.get("schemaVersion") == 2, "provenance schemaVersion must be 2", errors)

    source = provenance.get("source")
    require(isinstance(source, dict), "provenance source is missing", errors)
    if isinstance(source, dict):
        require(source.get("gitCommit") == candidate.get("gitCommit"), "provenance gitCommit mismatch", errors)
        require(source.get("gitTree") == candidate.get("gitTree"), "provenance gitTree mismatch", errors)
        signed_tag = source.get("signedTag")
        require(isinstance(signed_tag, dict), "provenance signedTag is missing", errors)
        if isinstance(signed_tag, dict):
            require(signed_tag.get("name") == candidate.get("tag"), "provenance tag mismatch", errors)
            require(
                signed_tag.get("objectSha") == candidate.get("tagObjectSha"),
                "provenance tag object mismatch",
                errors,
            )

    provenance_candidate = provenance.get("candidate")
    require(isinstance(provenance_candidate, dict), "provenance candidate is missing", errors)
    if isinstance(provenance_candidate, dict):
        require(
            provenance_candidate.get("versionName") == candidate.get("versionName"),
            "provenance versionName mismatch",
            errors,
        )
        require(
            provenance_candidate.get("versionCode") == candidate.get("versionCode"),
            "provenance versionCode mismatch",
            errors,
        )
        require(
            provenance_candidate.get("aabSha256") == actual_aab_hash,
            "provenance AAB SHA-256 mismatch",
            errors,
        )

    signing = provenance.get("signing")
    require(isinstance(signing, dict), "provenance signing is missing", errors)
    if isinstance(signing, dict):
        require(
            signing.get("uploadCertificateSha256") == candidate.get("uploadCertificateSha256"),
            "provenance upload certificate mismatch",
            errors,
        )
        require(
            signing.get("playAppSigningCertificateSha256")
            == candidate.get("playAppSigningCertificateSha256"),
            "provenance Play app-signing certificate mismatch",
            errors,
        )

    workflow = provenance.get("workflow")
    require(isinstance(workflow, dict), "provenance workflow is missing", errors)
    if isinstance(workflow, dict):
        require(
            workflow.get("runUrl") == candidate.get("workflowRunUrl"),
            "provenance workflow URL mismatch",
            errors,
        )

    artifacts = provenance.get("artifacts")
    require(isinstance(artifacts, dict), "provenance artifacts are missing", errors)
    if isinstance(artifacts, dict):
        require(
            set(artifacts) == REQUIRED_PROVENANCE_ARTIFACTS,
            "provenance artifact set mismatch",
            errors,
        )
        resolved_artifacts: dict[str, Path] = {}
        seen_artifact_paths: set[Path] = set()
        for name, record in artifacts.items():
            require(isinstance(record, dict), f"provenance artifact {name} is malformed", errors)
            if isinstance(record, dict):
                artifact_hash = str(record.get("sha256", "")).lower()
                require(
                    bool(SHA256_RE.fullmatch(artifact_hash)),
                    f"provenance artifact {name} hash is invalid",
                    errors,
                )
                raw_path = record.get("path")
                require(
                    isinstance(raw_path, str) and bool(raw_path.strip()),
                    f"provenance artifact {name} path is missing",
                    errors,
                )
                if isinstance(raw_path, str) and raw_path.strip():
                    declared_path = Path(raw_path)
                    if declared_path.is_absolute():
                        path_candidates = {declared_path.resolve()}
                    else:
                        path_candidates = {
                            (Path.cwd() / declared_path).resolve(),
                            (evidence_root / declared_path).resolve(),
                            (provenance_path.parent / declared_path).resolve(),
                        }
                    existing_candidates = {
                        path for path in path_candidates if path.is_file()
                    }
                    require(
                        len(existing_candidates) <= 1,
                        f"provenance artifact {name} path is ambiguous",
                        errors,
                    )
                    artifact_path = (
                        next(iter(existing_candidates))
                        if existing_candidates
                        else next(iter(path_candidates))
                    )
                    try:
                        artifact_path.relative_to(evidence_root)
                    except ValueError:
                        errors.append(f"provenance artifact {name} escapes the evidence directory")
                    else:
                        require(
                            artifact_path not in seen_artifact_paths,
                            f"provenance artifact path reused: {raw_path}",
                            errors,
                        )
                        seen_artifact_paths.add(artifact_path)
                        resolved_artifacts[name] = artifact_path
                        require(
                            artifact_path.is_file(),
                            f"provenance artifact {name} is missing",
                            errors,
                        )
                        declared_size = record.get("sizeBytes")
                        require(
                            isinstance(declared_size, int)
                            and not isinstance(declared_size, bool)
                            and declared_size > 0,
                            f"provenance artifact {name} sizeBytes is invalid",
                            errors,
                        )
                        if artifact_path.is_file():
                            require(
                                artifact_path.stat().st_size == declared_size,
                                f"provenance artifact {name} size mismatch",
                                errors,
                            )
                            if SHA256_RE.fullmatch(artifact_hash):
                                require(
                                    sha256(artifact_path) == artifact_hash,
                                    f"provenance artifact {name} hash mismatch",
                                    errors,
                                )
        aab_record = artifacts.get("aab")
        if isinstance(aab_record, dict):
            require(
                str(aab_record.get("sha256", "")).lower() == actual_aab_hash,
                "provenance aab artifact hash mismatch",
                errors,
            )
            require(
                resolved_artifacts.get("aab") == candidate_aab_path.resolve(),
                "provenance aab artifact path does not match candidate AAB",
                errors,
            )
        validate_candidate_security_artifacts(resolved_artifacts, candidate, errors)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--aab", required=True, type=Path)
    args = parser.parse_args()
    errors: list[str] = []

    require(args.manifest.is_file(), "manifest file is missing", errors)
    require(args.aab.is_file(), "candidate AAB is missing", errors)
    if errors:
        return fail(errors)

    # Validate the artifact before trusting any manifest field. This prevents a
    # synthetic evidence package from blessing an arbitrary text file that only
    # happens to have a matching SHA-256 value.
    actual_upload_signer = validate_candidate_aab(args.aab, errors)

    try:
        payload = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return fail([f"manifest cannot be parsed: {exc}"])

    require(payload.get("schemaVersion") == 2, "schemaVersion must be 2", errors)
    candidate = payload.get("candidate")
    require(isinstance(candidate, dict), "candidate object is required", errors)
    if not isinstance(candidate, dict):
        return fail(errors)

    commit = str(candidate.get("gitCommit", ""))
    tree = str(candidate.get("gitTree", ""))
    tag = str(candidate.get("tag", ""))
    tag_object = str(candidate.get("tagObjectSha", ""))
    version_name = str(candidate.get("versionName", ""))
    raw_version_code = candidate.get("versionCode")
    version_code = (
        raw_version_code
        if isinstance(raw_version_code, int) and not isinstance(raw_version_code, bool)
        else 0
    )
    expected_aab_hash = str(candidate.get("aabSha256", "")).lower()
    upload_cert = str(candidate.get("uploadCertificateSha256", "")).lower()
    play_cert = str(candidate.get("playAppSigningCertificateSha256", "")).lower()
    workflow_run_url = str(candidate.get("workflowRunUrl", ""))
    require(bool(COMMIT_RE.fullmatch(commit)), "gitCommit must be 40 lowercase hex", errors)
    require(bool(COMMIT_RE.fullmatch(tree)), "gitTree must be 40 lowercase hex", errors)
    require(bool(TAG_RE.fullmatch(tag)), "tag must be strict vMAJOR.MINOR.PATCH", errors)
    require(bool(COMMIT_RE.fullmatch(tag_object)), "tagObjectSha must be 40 lowercase hex", errors)
    require(version_name == tag.removeprefix("v"), "versionName must match tag", errors)
    require(
        version_code > 0,
        "versionCode must be a positive integer",
        errors,
    )
    require(bool(SHA256_RE.fullmatch(expected_aab_hash)), "aabSha256 is invalid", errors)
    require(bool(SHA256_RE.fullmatch(upload_cert)), "upload certificate SHA-256 is invalid", errors)
    require(bool(SHA256_RE.fullmatch(play_cert)), "Play app-signing certificate SHA-256 is invalid", errors)
    if actual_upload_signer is not None:
        require(
            actual_upload_signer == upload_cert,
            "candidate AAB signer does not match upload certificate SHA-256",
            errors,
        )
    require(bool(WORKFLOW_URL_RE.fullmatch(workflow_run_url)), "workflowRunUrl is invalid", errors)
    actual_aab_hash = sha256(args.aab)
    require(actual_aab_hash == expected_aab_hash, "AAB SHA-256 does not match manifest", errors)

    manifest_dir = args.manifest.resolve().parent
    provenance_ref = candidate.get("provenance")
    require(isinstance(provenance_ref, dict), "candidate provenance reference is required", errors)
    if isinstance(provenance_ref, dict):
        provenance_rel = str(provenance_ref.get("path", ""))
        provenance_hash = str(provenance_ref.get("sha256", "")).lower()
        require(bool(SHA256_RE.fullmatch(provenance_hash)), "provenance reference hash is invalid", errors)
        provenance_path = (manifest_dir / provenance_rel).resolve()
        try:
            provenance_path.relative_to(manifest_dir)
        except ValueError:
            errors.append("provenance path escapes the evidence directory")
        else:
            require(provenance_path.is_file(), "provenance file is missing", errors)
            if provenance_path.is_file() and SHA256_RE.fullmatch(provenance_hash):
                require(sha256(provenance_path) == provenance_hash, "provenance file hash mismatch", errors)
                try:
                    provenance_payload = json.loads(provenance_path.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError) as exc:
                    errors.append(f"provenance cannot be parsed: {exc}")
                else:
                    evidence_root = Path(
                        os.path.commonpath([manifest_dir, args.aab.resolve()])
                    ).resolve()
                    require(
                        evidence_root != Path(evidence_root.anchor),
                        "candidate evidence package has no bounded common root",
                        errors,
                    )
                    validate_provenance(
                        provenance_payload,
                        candidate,
                        actual_aab_hash,
                        evidence_root,
                        provenance_path,
                        args.aab,
                        errors,
                    )

    gates = payload.get("gates")
    require(isinstance(gates, list), "gates must be an array", errors)
    seen: set[str] = set()
    g4_masvs_paths: list[Path] = []
    used_evidence_paths: set[Path] = set()
    typed_evidence_payloads: dict[str, dict[str, object]] = {}
    if isinstance(gates, list):
        for gate in gates:
            if not isinstance(gate, dict):
                errors.append("every gate must be an object")
                continue
            gate_id = str(gate.get("id", ""))
            require(gate_id in EXPECTED_GATES, f"unknown gate id: {gate_id}", errors)
            require(gate_id not in seen, f"duplicate gate: {gate_id}", errors)
            seen.add(gate_id)
            require(gate.get("status") == "PASS", f"{gate_id} is not PASS", errors)
            owners = gate.get("owners")
            require(
                isinstance(owners, list)
                and exact_string_set(owners) == REQUIRED_GATE_OWNERS.get(gate_id, set()),
                f"{gate_id} owner set mismatch",
                errors,
            )
            declared_kinds = gate.get("requiredEvidenceKinds")
            expected_kinds = REQUIRED_EVIDENCE_KINDS.get(gate_id, set())
            require(
                isinstance(declared_kinds, list)
                and exact_string_set(declared_kinds) == expected_kinds,
                f"{gate_id} requiredEvidenceKinds mismatch",
                errors,
            )
            evidence = gate.get("evidence")
            require(
                isinstance(evidence, list) and bool(evidence),
                f"{gate_id} has no evidence",
                errors,
            )
            if not isinstance(evidence, list):
                continue
            actual_kinds: list[str] = []
            for item in evidence:
                if not isinstance(item, dict):
                    errors.append(f"{gate_id} evidence must be an object")
                    continue
                rel_path = str(item.get("path", ""))
                kind = str(item.get("kind", ""))
                actual_kinds.append(kind)
                item_hash = str(item.get("sha256", "")).lower()
                require(kind in expected_kinds, f"{gate_id}:{rel_path} has unexpected kind {kind}", errors)
                require(item.get("candidateBound") is True, f"{gate_id}:{rel_path} is not candidate-bound", errors)
                require(bool(SHA256_RE.fullmatch(item_hash)), f"{gate_id}:{rel_path} has invalid hash", errors)
                evidence_path = (manifest_dir / rel_path).resolve()
                try:
                    evidence_path.relative_to(manifest_dir)
                except ValueError:
                    errors.append(f"{gate_id}:{rel_path} escapes the evidence directory")
                    continue
                require(evidence_path not in used_evidence_paths, f"evidence path reused: {rel_path}", errors)
                used_evidence_paths.add(evidence_path)
                require(evidence_path.is_file(), f"{gate_id}:{rel_path} is missing", errors)
                if evidence_path.is_file() and SHA256_RE.fullmatch(item_hash):
                    require(sha256(evidence_path) == item_hash, f"{gate_id}:{rel_path} hash mismatch", errors)
                if gate_id == "G4" and kind == "masvsAssessment":
                    g4_masvs_paths.append(evidence_path)
                elif kind in expected_kinds and evidence_path.is_file():
                    gate_errors = validate_gate_evidence(
                        evidence_path,
                        gate_id,
                        kind,
                        actual_aab_hash,
                        "com.poyrazoncel.korubeni",
                        version_name,
                        version_code,
                    )
                    errors.extend(f"{gate_id} {kind}: {error}" for error in gate_errors)
                    try:
                        typed_payload = json.loads(evidence_path.read_text(encoding="utf-8"))
                    except (OSError, json.JSONDecodeError):
                        typed_payload = None
                    if isinstance(typed_payload, dict):
                        require(kind not in typed_evidence_payloads, f"duplicate typed evidence kind: {kind}", errors)
                        typed_evidence_payloads[kind] = typed_payload
            require(
                set(actual_kinds) == expected_kinds and len(actual_kinds) == len(expected_kinds),
                f"{gate_id} evidence kind set mismatch",
                errors,
            )

    require(seen == EXPECTED_GATES, f"gate set mismatch: found {sorted(seen)}", errors)
    require(
        len(g4_masvs_paths) == 1,
        "G4 requires one candidate-bound MASVS assessment",
        errors,
    )
    if len(g4_masvs_paths) == 1 and g4_masvs_paths[0].is_file():
        masvs_errors = validate_assessment(
            g4_masvs_paths[0],
            args.aab,
            "com.poyrazoncel.korubeni",
            version_name,
            version_code,
        )
        errors.extend(f"G4 MASVS: {error}" for error in masvs_errors)

    findings = payload.get("openFindings")
    require(isinstance(findings, list), "openFindings must be an array", errors)
    if isinstance(findings, list):
        for finding in findings:
            if isinstance(finding, dict) and finding.get("severity") in {"P0", "P1"}:
                errors.append("open P0/P1 finding blocks release")

    soak = payload.get("closedSoak")
    require(isinstance(soak, dict), "closedSoak object is required", errors)
    if isinstance(soak, dict):
        require(soak.get("status") == "PASS", "closed soak is not PASS", errors)
        require(isinstance(soak.get("days"), int) and soak["days"] >= 14, "closed soak is shorter than 14 days", errors)
        require(isinstance(soak.get("testers"), int) and soak["testers"] >= 12, "closed soak has fewer than 12 testers", errors)
        require(soak.get("safetyIncidents") == 0, "closed soak has a safety incident", errors)
        require(str(soak.get("aabSha256", "")).lower() == expected_aab_hash, "closed soak used a different AAB", errors)
        soak_report = typed_evidence_payloads.get("closedSoakReport")
        soak_metrics = soak_report.get("metrics") if isinstance(soak_report, dict) else None
        if isinstance(soak_metrics, dict):
            require(
                soak.get("testers") == soak_metrics.get("testers"),
                "closed soak testers do not match typed report",
                errors,
            )
            require(
                soak.get("safetyIncidents") == soak_metrics.get("safetyIncidents"),
                "closed soak incidents do not match typed report",
                errors,
            )
            started_at = parse_utc(soak_metrics.get("startedAt"))
            finished_at = parse_utc(soak_metrics.get("finishedAt"))
            if started_at is not None and finished_at is not None:
                complete_days = int((finished_at - started_at).total_seconds() // 86_400)
                require(
                    soak.get("days") == complete_days,
                    "closed soak days do not match typed report",
                    errors,
                )

    drill = payload.get("hotfixDrill")
    require(isinstance(drill, dict) and drill.get("status") == "PASS", "hotfix drill is not PASS", errors)
    if isinstance(drill, dict):
        duration = drill.get("durationMinutes")
        require(
            isinstance(duration, int)
            and not isinstance(duration, bool)
            and 1 <= duration <= 120,
            "hotfix drill duration must be 1..120 minutes",
            errors,
        )
        reserved_code = drill.get("reservedVersionCode")
        require(
            isinstance(reserved_code, int)
            and not isinstance(reserved_code, bool)
            and reserved_code > version_code,
            "hotfix drill reservedVersionCode must exceed candidate",
            errors,
        )
        require(
            str(drill.get("aabSha256", "")).lower() == expected_aab_hash,
            "hotfix drill used a different AAB",
            errors,
        )
        drill_report = typed_evidence_payloads.get("hotfixDrillReport")
        drill_metrics = drill_report.get("metrics") if isinstance(drill_report, dict) else None
        if isinstance(drill_metrics, dict):
            require(
                drill.get("durationMinutes") == drill_metrics.get("durationMinutes"),
                "hotfix drill duration does not match typed report",
                errors,
            )
            require(
                drill.get("reservedVersionCode") == drill_metrics.get("reservedVersionCode"),
                "hotfix drill reservedVersionCode does not match typed report",
                errors,
            )

    approvals = payload.get("approvals")
    approved_roles: set[str] = set()
    seen_approval_roles: set[str] = set()
    if isinstance(approvals, list):
        for approval in approvals:
            if not isinstance(approval, dict):
                errors.append("approval record must be an object")
                continue
            role = str(approval.get("role", ""))
            require(role in REQUIRED_APPROVAL_ROLES, f"unknown approval role: {role}", errors)
            require(role not in seen_approval_roles, f"duplicate approval role: {role}", errors)
            seen_approval_roles.add(role)
            require(approval.get("decision") == "APPROVE", f"{role} did not approve", errors)
            require(accountable_identity(approval.get("signer")), f"{role} signer is not accountable", errors)
            approval_signed_at = parse_utc(approval.get("signedAt"))
            require(approval_signed_at is not None, f"{role} signedAt must be UTC", errors)
            soak_report = typed_evidence_payloads.get("closedSoakReport")
            soak_metrics = soak_report.get("metrics") if isinstance(soak_report, dict) else None
            soak_finished_at = parse_utc(soak_metrics.get("finishedAt")) if isinstance(soak_metrics, dict) else None
            if approval_signed_at is not None and soak_finished_at is not None:
                require(
                    approval_signed_at >= soak_finished_at,
                    f"{role} approval predates closed soak completion",
                    errors,
                )
            require(
                str(approval.get("candidateAabSha256", "")).lower() == expected_aab_hash,
                f"{role} approval used a different AAB",
                errors,
            )
            require(
                approval.get("versionCode") == version_code,
                f"{role} approval versionCode mismatch",
                errors,
            )
            approval_rel = approval.get("evidencePath")
            approval_hash = str(approval.get("evidenceSha256", "")).lower()
            require(
                isinstance(approval_rel, str) and bool(approval_rel.strip()),
                f"{role} approval evidencePath is required",
                errors,
            )
            require(
                bool(SHA256_RE.fullmatch(approval_hash)),
                f"{role} approval evidenceSha256 is invalid",
                errors,
            )
            require(
                approval.get("evidenceCandidateBound") is True,
                f"{role} approval evidence is not candidate-bound",
                errors,
            )
            if isinstance(approval_rel, str) and approval_rel.strip():
                approval_path = (manifest_dir / approval_rel).resolve()
                try:
                    approval_path.relative_to(manifest_dir)
                except ValueError:
                    errors.append(f"{role} approval evidence escapes the evidence directory")
                else:
                    require(
                        approval_path not in used_evidence_paths,
                        f"evidence path reused: {approval_rel}",
                        errors,
                    )
                    used_evidence_paths.add(approval_path)
                    require(approval_path.is_file(), f"{role} approval evidence is missing", errors)
                    if approval_path.is_file() and SHA256_RE.fullmatch(approval_hash):
                        require(
                            sha256(approval_path) == approval_hash,
                            f"{role} approval evidence hash mismatch",
                            errors,
                        )
                        try:
                            approval_payload = json.loads(approval_path.read_text(encoding="utf-8"))
                        except (OSError, json.JSONDecodeError) as exc:
                            errors.append(f"{role} approval evidence cannot be parsed: {exc}")
                        else:
                            require(isinstance(approval_payload, dict), f"{role} approval evidence must be an object", errors)
                            if isinstance(approval_payload, dict):
                                for field in (
                                    "role",
                                    "decision",
                                    "signer",
                                    "signedAt",
                                    "candidateAabSha256",
                                    "versionCode",
                                ):
                                    require(
                                        approval_payload.get(field) == approval.get(field),
                                        f"{role} approval evidence {field} mismatch",
                                        errors,
                                    )
            if approval.get("decision") == "APPROVE" and role in REQUIRED_APPROVAL_ROLES:
                approved_roles.add(role)
    require(
        approved_roles == REQUIRED_APPROVAL_ROLES,
        f"missing approvals: {sorted(REQUIRED_APPROVAL_ROLES - approved_roles)}",
        errors,
    )

    if errors:
        return fail(errors)
    print("MASTER_GO_NO_GO_PASS")
    print(f"candidate_aab_sha256={actual_aab_hash}")
    return 0


def fail(errors: list[str]) -> int:
    print("MASTER_GO_NO_GO_FAIL", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
