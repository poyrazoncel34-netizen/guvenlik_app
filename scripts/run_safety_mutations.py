#!/usr/bin/env python3
"""Run the six release-blocking KoruBeni safety mutants in isolation.

The active worktree is never edited. A minimal temporary project is copied,
baseline evals must pass there, then every mutant must make its targeted eval
fail. A compile failure also kills a mutant, but the mutation definitions are
kept deliberately type-correct so failures should remain behavioral.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Mutation:
    mutation_id: str
    description: str
    path: str
    old: str
    new: str
    command: tuple[str, ...]
    cwd: str = "."
    occurrence: int = 1


FLUTTER_BASELINE = (
    "flutter",
    "test",
    "--no-pub",
    "test/screens/countdown_dispose_lifecycle_test.dart",
    "test/core/services/pin_verification_service_test.dart",
    "test/core/services/emergency_dispatch_pipeline_test.dart",
)
NATIVE_BASELINE = (
    "./gradlew",
    "app:testPlayDebugUnitTest",
    "--tests",
    "com.poyrazoncel.korubeni.emergency.EmergencySessionCoordinatorTest",
    "--console=plain",
)
PREPARE_WORKSPACE = ("flutter", "pub", "get", "--offline")


MUTATIONS = (
    Mutation(
        "M01_CANCEL_RESULT_SWALLOWED",
        "Treat an unconfirmed native cancellation as if it were acknowledged.",
        "lib/screens/countdown_screen.dart",
        "if (!cancellationConfirmed) {",
        "if (false && !cancellationConfirmed) {",
        (
            "flutter",
            "test",
            "--no-pub",
            "test/screens/countdown_dispose_lifecycle_test.dart",
            "--plain-name",
            "unknown native cancel acknowledgement keeps countdown active",
        ),
    ),
    Mutation(
        "M02_STALE_GENERATION_ACCEPTED",
        "Let a stale token pass the coordinator token equality guard.",
        "android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencySessionCoordinator.kt",
        "if (current.token != token) {",
        "if (false && current.token != token) {",
        NATIVE_BASELINE,
        cwd="android",
        occurrence=2,
    ),
    Mutation(
        "M03_PIN_READ_FAILURE_AS_ABSENT",
        "Collapse secure-storage read failure into the non-error absent state.",
        "lib/core/services/pin_verification_service.dart",
        "return _state = PinState.readFailed;",
        "return _state = PinState.absent;",
        (
            "flutter",
            "test",
            "--no-pub",
            "test/core/services/pin_verification_service_test.dart",
        ),
    ),
    Mutation(
        "M04_LOG_BEFORE_DISPATCH",
        "Run non-critical side effects before obtaining the dispatch result.",
        "lib/core/services/emergency_dispatch_pipeline.dart",
        "    final result = await criticalOperation();\n",
        (
            "    for (final operation in bestEffortOperations) {\n"
            "      try {\n"
            "        await operation();\n"
            "      } catch (error, stackTrace) {\n"
            "        onBestEffortError?.call(error, stackTrace);\n"
            "      }\n"
            "    }\n"
            "    final result = await criticalOperation();\n"
        ),
        (
            "flutter",
            "test",
            "--no-pub",
            "test/core/services/emergency_dispatch_pipeline_test.dart",
        ),
    ),
    Mutation(
        "M05_NOTIFICATION_RESULT_IGNORED",
        "Report a posted fallback even when its durable authorization commit failed.",
        "android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencySessionCoordinator.kt",
        (
            "        val effectiveFallbackOutcome = if (\n"
            "            fallbackOutcome == FallbackOutcome.POSTED && !fallbackStateCommitted\n"
            "        ) {\n"
            "            // The immutable action cannot be authorized without its durable\n"
            "            // state. A visible but dead notification is not an actionable\n"
            "            // fallback and must not be reported as one.\n"
            "            FallbackOutcome.FAILED\n"
            "        } else {\n"
            "            fallbackOutcome\n"
            "        }\n"
        ),
        "        val effectiveFallbackOutcome = fallbackOutcome\n",
        NATIVE_BASELINE,
        cwd="android",
    ),
    Mutation(
        "M06_DISPOSE_NATIVE_CANCEL",
        "Reintroduce native safety cancellation from widget dispose.",
        "lib/screens/countdown_screen.dart",
        "  void dispose() {\n    _timer?.cancel();",
        (
            "  void dispose() {\n"
            "    final token = _sessionToken;\n"
            "    if (token != null) {\n"
            "      unawaited(_emergencyPlatformService.cancelEmergencySession(token));\n"
            "    }\n"
            "    _timer?.cancel();"
        ),
        (
            "flutter",
            "test",
            "--no-pub",
            "test/screens/countdown_dispose_lifecycle_test.dart",
            "--plain-name",
            "disposing an armed countdown never sends native cancel",
        ),
    ),
)


def copy_project(source: Path, destination: Path) -> None:
    ignored = shutil.ignore_patterns(
        ".git",
        ".gradle",
        "build",
        "coverage",
        "*.jks",
        "*.keystore",
        "key.properties",
        ".agents",
        ".codex",
    )
    for directory in ("lib", "test", "assets", "android"):
        shutil.copytree(source / directory, destination / directory, ignore=ignored)
    for filename in (
        "pubspec.yaml",
        "pubspec.lock",
        "analysis_options.yaml",
        ".flutter-plugins-dependencies",
    ):
        candidate = source / filename
        if candidate.is_file():
            shutil.copy2(candidate, destination / filename)
    (destination / ".dart_tool").mkdir()
    for filename in ("package_config.json", "package_graph.json", "version"):
        shutil.copy2(source / ".dart_tool" / filename, destination / ".dart_tool" / filename)


def replace_occurrence(source: str, old: str, new: str, occurrence: int) -> str:
    start = -1
    for _ in range(occurrence):
        start = source.find(old, start + 1)
        if start < 0:
            raise ValueError(f"mutation anchor occurrence {occurrence} was not found")
    return source[:start] + new + source[start + len(old) :]


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def run(command: tuple[str, ...], cwd: Path, timeout_seconds: int) -> dict[str, object]:
    started = time.monotonic()
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=timeout_seconds,
        )
        output = result.stdout
        exit_code = result.returncode
        timed_out = False
    except subprocess.TimeoutExpired as exc:
        output = (exc.stdout or b"") + (exc.stderr or b"")
        exit_code = 124
        timed_out = True
    record: dict[str, object] = {
        "command": list(command),
        "exitCode": exit_code,
        "timedOut": timed_out,
        "durationMs": round((time.monotonic() - started) * 1000),
        "outputSha256": hashlib.sha256(output).hexdigest(),
    }
    if exit_code != 0:
        record["diagnosticTail"] = output.decode(
            "utf-8",
            errors="replace",
        )[-2000:]
    return record


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--timeout-seconds", type=int, default=900)
    parser.add_argument("--keep-workspace", action="store_true")
    args = parser.parse_args()

    repo = args.repo.resolve()
    workspace = Path(tempfile.mkdtemp(prefix="korubeni-safety-mutations-"))
    status_bytes = subprocess.run(
        [
            "git",
            "-C",
            str(repo),
            "status",
            "--porcelain=v1",
            "-z",
            "--untracked-files=all",
        ],
        check=True,
        capture_output=True,
    ).stdout
    evidence_paths = {
        mutation.path for mutation in MUTATIONS
    } | {
        "test/screens/countdown_dispose_lifecycle_test.dart",
        "test/core/services/pin_verification_service_test.dart",
        "test/core/services/emergency_dispatch_pipeline_test.dart",
        "android/app/src/test/kotlin/com/poyrazoncel/korubeni/emergency/EmergencySessionCoordinatorTest.kt",
    }
    evidence: dict[str, object] = {
        "schemaVersion": 1,
        "sourceHead": subprocess.run(
            ["git", "-C", str(repo), "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip(),
        "sourceStatusSha256": hashlib.sha256(status_bytes).hexdigest(),
        "sourceWasDirty": bool(status_bytes),
        "runnerSha256": file_sha256(Path(__file__).resolve()),
        "sourceFiles": {
            path: file_sha256(repo / path) for path in sorted(evidence_paths)
        },
        "mutations": [],
    }
    errors: list[str] = []
    try:
        copy_project(repo, workspace)
        preparation = run(PREPARE_WORKSPACE, workspace, args.timeout_seconds)
        evidence["preparation"] = preparation
        if preparation["exitCode"] != 0:
            errors.append("WORKSPACE_PREPARATION_FAILED")
            return finish(args.output, evidence, errors)
        baselines = (
            ("flutter", FLUTTER_BASELINE, workspace),
            ("native", NATIVE_BASELINE, workspace / "android"),
        )
        baseline_results: list[dict[str, object]] = []
        for name, command, cwd in baselines:
            result = run(command, cwd, args.timeout_seconds)
            result["name"] = name
            baseline_results.append(result)
            if result["exitCode"] != 0:
                errors.append(f"BASELINE_FAILED {name}")
        evidence["baselines"] = baseline_results
        if errors:
            return finish(args.output, evidence, errors)

        for mutation in MUTATIONS:
            target = workspace / mutation.path
            pristine = target.read_text(encoding="utf-8")
            try:
                mutated = replace_occurrence(
                    pristine,
                    mutation.old,
                    mutation.new,
                    mutation.occurrence,
                )
                target.write_text(mutated, encoding="utf-8")
                result = run(
                    mutation.command,
                    workspace / mutation.cwd,
                    args.timeout_seconds,
                )
            except (OSError, ValueError) as exc:
                result = {
                    "command": list(mutation.command),
                    "exitCode": 125,
                    "timedOut": False,
                    "durationMs": 0,
                    "outputSha256": hashlib.sha256(str(exc).encode()).hexdigest(),
                    "harnessError": str(exc),
                }
            finally:
                target.write_text(pristine, encoding="utf-8")

            killed = result["exitCode"] not in {0, 124, 125}
            if killed:
                result.pop("diagnosticTail", None)
            record = {
                "id": mutation.mutation_id,
                "description": mutation.description,
                "target": mutation.path,
                "status": "KILLED" if killed else "SURVIVED_OR_INVALID",
                "result": result,
            }
            evidence["mutations"].append(record)
            if not killed:
                errors.append(f"MUTATION_NOT_KILLED {mutation.mutation_id}")
        return finish(args.output, evidence, errors)
    finally:
        if args.keep_workspace:
            print(f"mutation_workspace={workspace}")
        else:
            shutil.rmtree(workspace, ignore_errors=True)


def finish(output: Path, evidence: dict[str, object], errors: list[str]) -> int:
    evidence["status"] = "PASS" if not errors else "FAIL"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    if errors:
        print("SAFETY_MUTATION_FAIL", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("SAFETY_MUTATION_PASS")
    print(f"killed={len(MUTATIONS)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
