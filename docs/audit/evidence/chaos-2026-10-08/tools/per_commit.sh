#!/bin/bash
# Per-commit validation in a clean detached worktree (chaos audit 2026-10-08).
# usage: per_commit.sh <base-exclusive> <head> <out-file>
set -u
REPO=/Users/poyrazoncel/Projects/guvenlik_app
BASE=$1; HEAD=$2; OUT=$3
WT=$(mktemp -d /private/tmp/claude-501/-Users-poyrazoncel-Projects-guvenlik-app/53dc7a26-0f79-4878-85a0-74d07698c976/scratchpad/wt.XXXX)
git -C $REPO worktree add --detach $WT $HEAD >/dev/null 2>&1 || { echo "worktree failed" >> $OUT; exit 1; }
echo "per-commit validation $(date '+%F %T') base=$BASE head=$HEAD worktree=clean" >> $OUT
cd $WT && flutter pub get >/dev/null 2>&1
for sha in $(git -C $REPO rev-list --reverse $BASE..$HEAD); do
  git -C $WT checkout -q --detach $sha
  rm -rf $WT/build/test_cache
  flutter analyze --no-fatal-infos > /dev/null 2>&1; A=$?
  T=$(flutter test --no-pub -r compact 2>&1 | tr '\r' '\n' | grep -oE "\+[0-9]+( -[0-9]+)?: (All tests passed|Some tests failed)" | tail -1)
  K=-
  if git -C $REPO diff --name-only $sha~1 $sha | grep -q '^android/'; then
    (cd $WT/android && ./gradlew :app:testPlayDebugUnitTest -q > /dev/null 2>&1); K=$?
  fi
  echo "$sha analyze=$A test=[$T] kotlin=$K | $(git -C $REPO log -1 --format=%s $sha)" >> $OUT
done
echo "DONE $(date '+%F %T')" >> $OUT
git -C $REPO worktree remove --force $WT >/dev/null 2>&1
