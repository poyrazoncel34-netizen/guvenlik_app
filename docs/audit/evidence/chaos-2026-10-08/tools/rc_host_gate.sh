#!/bin/zsh
# Host-side release-candidate gate (closure audit 2026-10-10).
# usage: rc_host_gate.sh <clean worktree at the RC HEAD> <evidence dir> <mutant spec json>
# Runs, each with its own exit code recorded (never piped into tail before $?):
#   verify_release.sh, secrets scan, OSV, FUZZ_SCALE=13, run_safety_mutations.py,
#   all counterfactual mutants, critical tests x10, artifact hashes, merged-manifest inspection.
set -u
W=$1; EV=$2; SPEC=$3
TOOLS=${0:A:h}
mkdir -p $EV
cd $W || exit 2
HEAD=$(git rev-parse HEAD)
step() { print -- "== $1 ($(date '+%F %T'))" >> $EV/rc-host-gate-summary.txt; }
res() { print -- "   -> $1" >> $EV/rc-host-gate-summary.txt; }
print -- "RELEASE_CANDIDATE_HEAD=$HEAD worktree=$W" > $EV/rc-host-gate-summary.txt

step "verify_release.sh"
./scripts/verify_release.sh > $EV/verify_release.txt 2>&1; r=$?; res "exit=$r $(grep -a -E 'LOCAL_CANDIDATE_PASS|YAYIN DOGRULAMA KIRMIZI' $EV/verify_release.txt | sed 's/\x1b\[[0-9;]*m//g' | tail -1)"

step "artifact hashes"
{ print "RELEASE_CANDIDATE_HEAD=$HEAD"
  shasum -a 256 build/app/outputs/bundle/smokeRelease/app-smoke-release.aab
  shasum -a 256 build/app/intermediates/merged_manifest/smokeRelease/processSmokeReleaseMainManifest/AndroidManifest.xml
  shasum -a 256 build/app/outputs/apk/androidTest/play/debug/app-play-debug-androidTest.apk 2>/dev/null
  python3 - <<'PY'
import glob,re
t=f=0
for x in glob.glob('build/app/test-results/testPlayDebugUnitTest/*.xml'):
    h=open(x).read(2000); m=re.search(r'tests="(\d+)" skipped="(\d+)" failures="(\d+)" errors="(\d+)"',h)
    if m: t+=int(m.group(1)); f+=int(m.group(3))+int(m.group(4))
print(f"kotlin unit tests={t} failures+errors={f}")
PY
} > $EV/artifact-hashes.txt 2>&1; res "$(wc -l < $EV/artifact-hashes.txt) lines"

step "merged manifest inspection"
M=build/app/intermediates/merged_manifest/smokeRelease/processSmokeReleaseMainManifest/AndroidManifest.xml
{ print "sha256 $(shasum -a 256 $M | cut -c1-64)"; grep -o 'uses-permission[^>]*android:name="[^"]*"' $M | grep -o 'name="[^"]*"' | sort
  for p in USE_EXACT_ALARM FOREGROUND_SERVICE AD_ID ACCESS_BACKGROUND_LOCATION READ_CONTACTS USE_FULL_SCREEN_INTENT SEND_SMS READ_PHONE_STATE; do print "$p: $(grep -c "permission.$p\"" $M)"; done
} > $EV/merged-manifest-inspection.txt; res "$(grep -c ': 0' $EV/merged-manifest-inspection.txt)/8 forbidden permissions absent"

step "secrets scan"
python3 scripts/scan_release_secrets.py --repo $W --output $EV/secrets-scan.json --require-clean > $EV/secrets-scan.txt 2>&1; res "exit=$? $(head -1 $EV/secrets-scan.txt)"

step "OSV"
./scripts/audit_dependencies_osv.sh --output $EV/osv.json > $EV/osv-audit.txt 2>&1; res "exit=$? $(grep -E 'OSV_EVIDENCE_(PASS|FAIL)' $EV/osv-audit.txt)"

step "FUZZ_SCALE=13"
FUZZ_SCALE=13 flutter test --no-pub test/core/navigation/navigation_safety_fuzz_test.dart test/core/services/safety_clock_chaos_fuzz_test.dart > $EV/fuzz-scale13.raw 2>&1; r=$?
tr '\r' '\n' < $EV/fuzz-scale13.raw | grep -E 'All tests passed|Some tests failed' | tail -1 > $EV/fuzz-scale13.txt; rm -f $EV/fuzz-scale13.raw; res "exit=$r $(cat $EV/fuzz-scale13.txt)"

step "run_safety_mutations.py"
python3 scripts/run_safety_mutations.py --output $EV/safety-mutations.json > $EV/safety-mutations.txt 2>&1; res "exit=$? $(grep -E 'SAFETY_MUTATION_(PASS|FAIL)|killed=' $EV/safety-mutations.txt | tr '\n' ' ')"

step "counterfactual mutants (all specs)"
python3 $TOOLS/counterfactual.py $SPEC $EV/counterfactual-all-at-rc.txt > /dev/null 2>&1; r=$?; res "exit=$r $(grep -c KILLED $EV/counterfactual-all-at-rc.txt) killed, $(grep -E '^# survivors' $EV/counterfactual-all-at-rc.txt | tail -1); tree clean: $(git status --short --untracked-files=no | wc -l | tr -d ' ') changes"

step "critical tests x10"
FILES=(${(f)"$(ls test/screens/countdown_*_test.dart test/core/services/pin_lockout*_test.dart test/core/services/panic_*_test.dart test/screens/emergency_call_screen_behavior_test.dart test/core/services/check_in_service_behavior_matrix_test.dart test/core/services/emergency_snapshot_parser_test.dart test/core/services/native_history_warning_reason_test.dart test/core/services/emergency_call_flow_test.dart)"})
print "${#FILES} files" > $EV/critical-tests-x10.txt
for i in {1..10}; do flutter test --no-pub $FILES > /tmp/claude-501/crit.raw 2>&1; r=$?; print "run $i exit=$r $(tr '\r' '\n' < /tmp/claude-501/crit.raw | grep -E 'All tests passed|Some tests failed' | tail -1 | sed 's/ \{3,\}//g')" >> $EV/critical-tests-x10.txt; done
rm -f /tmp/claude-501/crit.raw; res "$(grep -c 'exit=0' $EV/critical-tests-x10.txt)/10 green"
print -- "== done $(date '+%F %T')" >> $EV/rc-host-gate-summary.txt
