#!/usr/bin/env python3
"""Fail-closed audit of KoruBeni's merged Android release surface.

The merged manifest is the authority because dependency manifests can add
permissions and components after the source manifest has been reviewed. This
tool emits evidence; it does not claim that a smoke manifest is a production
candidate or that an allowlisted component is vulnerability-free.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path


ANDROID_NS = "http://schemas.android.com/apk/res/android"
ANDROID = f"{{{ANDROID_NS}}}"
PACKAGE_RE = re.compile(r"^[a-z][a-z0-9_]*(?:\.[a-zA-Z][a-zA-Z0-9_]*)+$")

REQUIRED_PERMISSIONS = {
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
}
SAFETY_COMPONENTS = {
    "com.poyrazoncel.korubeni.emergency.EmergencyFallbackDialActivity",
    "com.poyrazoncel.korubeni.emergency.CheckInAlarmReceiver",
    "com.poyrazoncel.korubeni.emergency.CountdownAlarmReceiver",
    "com.poyrazoncel.korubeni.emergency.BootCompletedReceiver",
    "com.poyrazoncel.korubeni.emergency.ExactAlarmPermissionReceiver",
    "com.poyrazoncel.korubeni.emergency.ClockChangeReceiver",
    "com.poyrazoncel.korubeni.emergency.EmergencyFallbackCleanupReceiver",
}
COMPONENT_TAGS = ("activity", "activity-alias", "service", "receiver", "provider")
REQUIRED_BACKUP_DOMAINS = {
    "root",
    "file",
    "database",
    "sharedpref",
    "external",
    "device_root",
    "device_file",
    "device_database",
    "device_sharedpref",
}
LAUNCHER_ACTIVITY = "com.poyrazoncel.korubeni.MainActivity"
PROFILE_RECEIVER = "androidx.profileinstaller.ProfileInstallReceiver"


def attr(element: ET.Element, name: str) -> str | None:
    return element.get(f"{ANDROID}{name}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def parse_xml(path: Path, label: str, errors: list[str]) -> ET.Element | None:
    if not path.is_file():
        errors.append(f"{label} is missing: {path}")
        return None
    try:
        # lstrip accepts deterministic test fixtures without weakening XML
        # semantics; comments/declarations inside the document still parse.
        return ET.fromstring(path.read_bytes().lstrip())
    except (OSError, ET.ParseError) as exc:
        errors.append(f"{label} cannot be parsed: {exc}")
        return None


def is_true(value: str | None) -> bool:
    return value == "true"


def launcher_filter_present(component: ET.Element) -> bool:
    for intent_filter in component.findall("intent-filter"):
        actions = {attr(item, "name") for item in intent_filter.findall("action")}
        categories = {
            attr(item, "name") for item in intent_filter.findall("category")
        }
        if (
            "android.intent.action.MAIN" in actions
            and "android.intent.category.LAUNCHER" in categories
        ):
            return True
    return False


def audit_manifest(
    root: ET.Element,
    expected_package: str,
    errors: list[str],
) -> dict[str, object]:
    if root.tag != "manifest":
        errors.append("merged manifest root must be <manifest>")
    if root.get("package") != expected_package:
        errors.append("merged manifest package does not match expected package")

    uses_sdk = root.find("uses-sdk")
    if uses_sdk is None:
        errors.append("uses-sdk is missing")
        min_sdk = target_sdk = None
    else:
        min_sdk = attr(uses_sdk, "minSdkVersion")
        target_sdk = attr(uses_sdk, "targetSdkVersion")
        if min_sdk != "29":
            errors.append("minSdkVersion must be 29")
        if target_sdk != "36":
            errors.append("targetSdkVersion must be 36")

    permission_nodes = root.findall("uses-permission")
    permissions = [attr(node, "name") or "" for node in permission_nodes]
    if "" in permissions or len(permissions) != len(set(permissions)):
        errors.append("permissions must be named and unique")
    dynamic_permission = (
        f"{expected_package}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"
    )
    expected_permissions = REQUIRED_PERMISSIONS | {dynamic_permission}
    if set(permissions) != expected_permissions:
        missing = sorted(expected_permissions - set(permissions))
        unexpected = sorted(set(permissions) - expected_permissions)
        errors.append(
            "permission allowlist mismatch: "
            f"missing={missing} unexpected={unexpected}"
        )

    permission_definition = next(
        (
            node
            for node in root.findall("permission")
            if attr(node, "name") == dynamic_permission
        ),
        None,
    )
    if permission_definition is None or attr(permission_definition, "protectionLevel") != "signature":
        errors.append("dynamic receiver permission must be defined as signature")

    telephony = next(
        (
            node
            for node in root.findall("uses-feature")
            if attr(node, "name") == "android.hardware.telephony"
        ),
        None,
    )
    if telephony is None or attr(telephony, "required") != "true":
        errors.append("android.hardware.telephony must be required=true")

    application = root.find("application")
    if application is None:
        errors.append("application element is missing")
        return {
            "minSdk": min_sdk,
            "targetSdk": target_sdk,
            "permissions": sorted(permissions),
            "components": [],
            "unprotectedExportedComponents": [],
        }

    required_application_attributes = {
        "allowBackup": "false",
        "fullBackupContent": "false",
        "dataExtractionRules": "@xml/data_extraction_rules",
        "usesCleartextTraffic": "false",
        "networkSecurityConfig": "@xml/network_security_config",
        "extractNativeLibs": "false",
    }
    for name, expected in required_application_attributes.items():
        if attr(application, name) != expected:
            if name == "usesCleartextTraffic":
                errors.append("usesCleartextTraffic must be false")
            else:
                errors.append(f"application {name} must be {expected}")
    for forbidden_true in ("debuggable", "testOnly", "profileableByShell"):
        if is_true(attr(application, forbidden_true)):
            errors.append(f"application {forbidden_true}=true is forbidden")

    components: list[dict[str, object]] = []
    unprotected_exported: list[str] = []
    component_by_name: dict[str, ET.Element] = {}
    for tag in COMPONENT_TAGS:
        for component in application.findall(tag):
            name = attr(component, "name") or ""
            if not name:
                errors.append(f"unnamed <{tag}> component")
                continue
            if name in component_by_name:
                errors.append(f"duplicate component name: {name}")
            component_by_name[name] = component
            exported_value = attr(component, "exported")
            has_intent_filter = component.find("intent-filter") is not None
            if has_intent_filter and exported_value not in {"true", "false"}:
                errors.append(f"component with intent-filter lacks explicit exported: {name}")
            exported = exported_value == "true"
            permission = attr(component, "permission")
            if attr(component, "foregroundServiceType") is not None:
                errors.append(f"foregroundServiceType is forbidden: {name}")
            if "com.amazon" in name or "ProxyAmazonBillingActivity" in name:
                errors.append(f"Amazon billing component is forbidden: {name}")

            if exported:
                launcher_ok = (
                    tag == "activity"
                    and name == LAUNCHER_ACTIVITY
                    and launcher_filter_present(component)
                    and attr(component, "taskAffinity") == ""
                )
                profile_ok = (
                    tag == "receiver"
                    and name == PROFILE_RECEIVER
                    and permission == "android.permission.DUMP"
                )
                if not launcher_ok and not profile_ok:
                    errors.append(f"unexpected exported component: {tag}:{name}")
                    if not permission:
                        unprotected_exported.append(name)

            components.append(
                {
                    "type": tag,
                    "name": name,
                    "exported": exported,
                    "permission": permission,
                    "directBootAware": attr(component, "directBootAware") == "true",
                }
            )

    launcher = component_by_name.get(LAUNCHER_ACTIVITY)
    if (
        launcher is None
        or attr(launcher, "exported") != "true"
        or not launcher_filter_present(launcher)
        or attr(launcher, "taskAffinity") != ""
    ):
        errors.append("launcher activity contract is invalid")

    for name in sorted(SAFETY_COMPONENTS):
        component = component_by_name.get(name)
        if component is None:
            errors.append(f"required safety component is missing: {name}")
            continue
        if attr(component, "exported") != "false":
            errors.append(f"safety component must be exported=false: {name}")
        if attr(component, "directBootAware") != "true":
            errors.append(f"safety component must be directBootAware=true: {name}")

    return {
        "minSdk": int(min_sdk) if min_sdk and min_sdk.isdigit() else min_sdk,
        "targetSdk": int(target_sdk) if target_sdk and target_sdk.isdigit() else target_sdk,
        "permissions": sorted(permissions),
        "components": sorted(components, key=lambda item: (str(item["type"]), str(item["name"]))),
        "unprotectedExportedComponents": sorted(unprotected_exported),
    }


def audit_network_config(root: ET.Element, errors: list[str]) -> None:
    if root.tag != "network-security-config":
        errors.append("network security root must be <network-security-config>")
        return
    base_configs = root.findall("base-config")
    if (
        len(base_configs) != 1
        or base_configs[0].get("cleartextTrafficPermitted") != "false"
    ):
        errors.append("network base-config must deny cleartext")
    for element in root.iter():
        if element.get("cleartextTrafficPermitted") == "true":
            errors.append("network config contains a cleartext opt-in")
    if root.find("debug-overrides") is not None:
        errors.append("network debug-overrides are forbidden in release")


def audit_extraction_rules(root: ET.Element, errors: list[str]) -> None:
    if root.tag != "data-extraction-rules":
        errors.append("data extraction root must be <data-extraction-rules>")
        return
    if root.find(".//include") is not None:
        errors.append("data extraction rules must not include any storage domain")
    for section_name in ("cloud-backup", "device-transfer"):
        section = root.find(section_name)
        if section is None:
            errors.append(f"data extraction section is missing: {section_name}")
            continue
        exclusions = {
            item.get("domain")
            for item in section.findall("exclude")
            if item.get("path") == "."
        }
        if exclusions != REQUIRED_BACKUP_DOMAINS:
            errors.append(
                f"{section_name} exclusion set mismatch: "
                f"missing={sorted(REQUIRED_BACKUP_DOMAINS - exclusions)}"
            )


def fail(errors: list[str]) -> int:
    print("ANDROID_RELEASE_SURFACE_FAIL", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    return 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--network-security-config", required=True, type=Path)
    parser.add_argument("--data-extraction-rules", required=True, type=Path)
    parser.add_argument("--expected-package", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    try:
        args.output.unlink(missing_ok=True)
    except OSError as exc:
        return fail([f"stale output cannot be removed: {exc}"])

    if not PACKAGE_RE.fullmatch(args.expected_package):
        return fail(["expected package has an invalid format"])

    errors: list[str] = []
    manifest = parse_xml(args.manifest, "merged manifest", errors)
    network = parse_xml(args.network_security_config, "network security config", errors)
    extraction = parse_xml(args.data_extraction_rules, "data extraction rules", errors)
    manifest_report: dict[str, object] = {}
    if manifest is not None:
        manifest_report = audit_manifest(manifest, args.expected_package, errors)
    if network is not None:
        audit_network_config(network, errors)
    if extraction is not None:
        audit_extraction_rules(extraction, errors)
    if errors:
        return fail(errors)

    report = {
        "schemaVersion": 1,
        "status": "PASS",
        "candidateBound": False,
        "expectedPackage": args.expected_package,
        "manifestSha256": sha256(args.manifest),
        "networkSecurityConfigSha256": sha256(args.network_security_config),
        "dataExtractionRulesSha256": sha256(args.data_extraction_rules),
        "minSdk": manifest_report["minSdk"],
        "targetSdk": manifest_report["targetSdk"],
        "permissionCount": len(manifest_report["permissions"]),
        "permissions": manifest_report["permissions"],
        "componentCount": len(manifest_report["components"]),
        "components": manifest_report["components"],
        "unprotectedExportedComponents": manifest_report[
            "unprotectedExportedComponents"
        ],
        "limitations": [
            "MERGED_MANIFEST_AND_SOURCE_RESOURCE_AUDIT_ONLY",
            "NOT_RUNTIME_INTENT_FUZZING",
            "NOT_PRODUCTION_AAB_UNLESS_RUN_BY_TAGGED_WORKFLOW",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    serialized = json.dumps(report, indent=2, sort_keys=True) + "\n"
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{args.output.name}.", dir=args.output.parent
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(serialized)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_name, 0o644)
        os.replace(temporary_name, args.output)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)

    print("ANDROID_RELEASE_SURFACE_PASS")
    print(
        f"package={args.expected_package} permissions={report['permissionCount']} "
        f"components={report['componentCount']}"
    )
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
