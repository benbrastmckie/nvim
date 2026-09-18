#!/usr/bin/env bash
# test-deploy-freshness.sh - Fixture-driven regression suite for check-deploy-freshness.sh, the
# bash read side of the source_git_head staleness stamp (see state.lua's
# `resolve_source_git_head` for the write side this checker's comparison logic mirrors).
#
# Structural model: test-phase-heading-patterns.sh (pass()/fail()/info() helpers, PASSED/FAILED
# integer counters, exit 0 on all-pass / exit 1 on any-fail) combined with
# test-deploy-propagation.sh's trap-based scratch WORKDIR pattern, since this suite -- like that
# one -- drives a real subprocess rather than sourcing a library.
#
# Fixture: a throwaway SOURCE git repo (standing in for the agent-system source store) holding a
# committed "ext" subdirectory, and one throwaway CONSUMER directory per case holding a
# fabricated .claude-extensions.json whose `source_dir` points at that subdirectory. The real
# check-deploy-freshness.sh AND its sibling scripts/lib/deploy-freshness-lib.sh are copied
# byte-for-byte into the fixture (checker at $WORKDIR/bin/, library at $WORKDIR/bin/lib/,
# preserving the sibling relationship the checker's own SCRIPT_DIR-relative resolution requires)
# and invoked only against these throwaway consumers -- never against this repo's own
# .claude-extensions.json or specs/ tree.
#
# Extended for the Phase 2 library extraction: this suite also sources
# deploy-freshness-lib.sh directly (a second, independent invocation path from the subprocess
# checker above) to pin its two exported functions' own contracts -- in particular the
# STALE/FRESH/CANNOTVERIFY three-way distinction `deploy_freshness_status` provides and
# check-deploy-freshness.sh's own WARN-or-silence output deliberately collapses.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (checker script, library, or git not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. Resolve via the
# git worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

CHECKER_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/check-deploy-freshness.sh"
  "$SCRIPT_DIR/../check-deploy-freshness.sh"
)
CHECKER=""
for candidate in "${CHECKER_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    CHECKER="$candidate"
    break
  fi
done
if [[ -z "$CHECKER" ]]; then
  echo "ERROR: check-deploy-freshness.sh not found at any of:" >&2
  for candidate in "${CHECKER_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/deploy-freshness-lib.sh"
  "$SCRIPT_DIR/../lib/deploy-freshness-lib.sh"
)
LIB=""
for candidate in "${LIB_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    LIB="$candidate"
    break
  fi
done
if [[ -z "$LIB" ]]; then
  echo "ERROR: deploy-freshness-lib.sh not found at any of:" >&2
  for candidate in "${LIB_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not found on PATH" >&2
  exit 2
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

info "Using checker: $CHECKER"
info "Using library: $LIB"

# --- Fixture: throwaway source-store stand-in with a committed "ext" subdirectory ---
SOURCE_REPO="$WORKDIR/source-repo"
mkdir -p "$SOURCE_REPO/ext"
git init -q "$SOURCE_REPO"
git -C "$SOURCE_REPO" config user.email "test@example.com"
git -C "$SOURCE_REPO" config user.name "Test"
echo "v1" > "$SOURCE_REPO/ext/file.txt"
git -C "$SOURCE_REPO" add ext/file.txt
git -C "$SOURCE_REPO" commit -q -m "initial ext"
EXT_DIR="$SOURCE_REPO/ext"
HEAD_V1="$(git -C "$SOURCE_REPO" log -1 --format=%H -- "$EXT_DIR")"

# Real checker + its sibling library, copied byte-for-byte so the suite exercises exactly the
# deployed artifacts and so the checker's own SCRIPT_DIR-relative `lib/deploy-freshness-lib.sh`
# sibling lookup resolves inside the fixture exactly as it does in either real deployment
# location.
mkdir -p "$WORKDIR/bin/lib"
cp "$CHECKER" "$WORKDIR/bin/check-deploy-freshness.sh"
chmod +x "$WORKDIR/bin/check-deploy-freshness.sh"
cp "$LIB" "$WORKDIR/bin/lib/deploy-freshness-lib.sh"

run_checker() {
  bash "$WORKDIR/bin/check-deploy-freshness.sh" "$1"
}

# $1 consumer dir, $2 source_dir, $3 recorded head (ignored if $4 == true), $4 omit-head flag
write_state() {
  local consumer="$1" ext_dir="$2" head="$3" omit_head="${4:-false}"
  mkdir -p "$consumer"
  if [[ "$omit_head" == "true" ]]; then
    cat > "$consumer/.claude-extensions.json" << EOF
{"version":"1.0.0","extensions":{"ext":{"version":"1.0.0","source_dir":"${ext_dir}"}}}
EOF
  else
    cat > "$consumer/.claude-extensions.json" << EOF
{"version":"1.0.0","extensions":{"ext":{"version":"1.0.0","source_dir":"${ext_dir}","source_git_head":"${head}"}}}
EOF
  fi
}

# =====================================================================
# Case STALE: recorded source_git_head is an older/bogus commit
# =====================================================================
CONSUMER_STALE="$WORKDIR/consumer-stale"
write_state "$CONSUMER_STALE" "$EXT_DIR" "0000000000000000000000000000000000dead"
OUT_STALE="$(run_checker "$CONSUMER_STALE" 2>&1)"
RC_STALE=$?
WARN_COUNT_STALE=$(printf '%s\n' "$OUT_STALE" | grep -c '^WARN:')
if [[ "$RC_STALE" -eq 0 && "$WARN_COUNT_STALE" -eq 1 && "$OUT_STALE" == *"'ext'"* ]]; then
  pass "STALE: exactly one WARN naming the extension, exit 0"
else
  fail "STALE: expected exactly one WARN naming 'ext' and exit 0, got rc=$RC_STALE warn_count=$WARN_COUNT_STALE output=<<<$OUT_STALE>>>"
fi
if [[ "$OUT_STALE" == *"deploy-headless.sh"* ]]; then
  pass "STALE: WARN names the regeneration remedy"
else
  fail "STALE: WARN did not name deploy-headless.sh remedy: <<<$OUT_STALE>>>"
fi

# =====================================================================
# Case FRESH: recorded source_git_head equals the current revision
# =====================================================================
CONSUMER_FRESH="$WORKDIR/consumer-fresh"
write_state "$CONSUMER_FRESH" "$EXT_DIR" "$HEAD_V1"
OUT_FRESH="$(run_checker "$CONSUMER_FRESH" 2>&1)"
RC_FRESH=$?
if [[ "$RC_FRESH" -eq 0 && -z "$OUT_FRESH" ]]; then
  pass "FRESH: no output, exit 0"
else
  fail "FRESH: expected silence and exit 0, got rc=$RC_FRESH output=<<<$OUT_FRESH>>>"
fi

# =====================================================================
# Case MISSING FIELD: entry has source_dir but no source_git_head
# =====================================================================
CONSUMER_MISSING="$WORKDIR/consumer-missing-field"
write_state "$CONSUMER_MISSING" "$EXT_DIR" "" true
OUT_MISSING="$(run_checker "$CONSUMER_MISSING" 2>&1)"
RC_MISSING=$?
if [[ "$RC_MISSING" -eq 0 && -z "$OUT_MISSING" ]]; then
  pass "MISSING FIELD: no output, exit 0"
else
  fail "MISSING FIELD: expected silence and exit 0, got rc=$RC_MISSING output=<<<$OUT_MISSING>>>"
fi

# =====================================================================
# Case UNVERIFIABLE (variant A): source_dir exists but is not inside any git repository
# =====================================================================
CONSUMER_NONGIT="$WORKDIR/consumer-nongit"
NONGIT_DIR="$WORKDIR/not-a-git-dir"
mkdir -p "$NONGIT_DIR"
write_state "$CONSUMER_NONGIT" "$NONGIT_DIR" "deadbeef"
OUT_NONGIT="$(run_checker "$CONSUMER_NONGIT" 2>&1)"
RC_NONGIT=$?
if [[ "$RC_NONGIT" -eq 0 && -z "$OUT_NONGIT" ]]; then
  pass "UNVERIFIABLE (non-git source_dir): no output, exit 0"
else
  fail "UNVERIFIABLE (non-git source_dir): expected silence and exit 0, got rc=$RC_NONGIT output=<<<$OUT_NONGIT>>>"
fi

# =====================================================================
# Case UNVERIFIABLE (variant B): source_dir does not exist on disk
# =====================================================================
CONSUMER_NOPATH="$WORKDIR/consumer-nopath"
write_state "$CONSUMER_NOPATH" "$WORKDIR/does-not-exist-xyz" "deadbeef"
OUT_NOPATH="$(run_checker "$CONSUMER_NOPATH" 2>&1)"
RC_NOPATH=$?
if [[ "$RC_NOPATH" -eq 0 && -z "$OUT_NOPATH" ]]; then
  pass "UNVERIFIABLE (nonexistent source_dir): no output, exit 0"
else
  fail "UNVERIFIABLE (nonexistent source_dir): expected silence and exit 0, got rc=$RC_NOPATH output=<<<$OUT_NOPATH>>>"
fi

# =====================================================================
# Case SCOPING: commit a change elsewhere in the fixture source repo, outside ext/'s own
# subdirectory -- must produce no output (path-scoped comparison, not whole-repo HEAD)
# =====================================================================
echo "unrelated change" > "$SOURCE_REPO/outside.txt"
git -C "$SOURCE_REPO" add outside.txt
git -C "$SOURCE_REPO" commit -q -m "unrelated change outside ext/"
CONSUMER_SCOPING="$WORKDIR/consumer-scoping"
write_state "$CONSUMER_SCOPING" "$EXT_DIR" "$HEAD_V1"
OUT_SCOPING="$(run_checker "$CONSUMER_SCOPING" 2>&1)"
RC_SCOPING=$?
if [[ "$RC_SCOPING" -eq 0 && -z "$OUT_SCOPING" ]]; then
  pass "SCOPING: change outside ext/ subdirectory produces no output (path-scoped, not whole-repo HEAD)"
else
  fail "SCOPING: expected silence after unrelated commit, got rc=$RC_SCOPING output=<<<$OUT_SCOPING>>>"
fi

# =====================================================================
# Deliberate-break check (documented here, not run automatically): inverting the comparison
# (recomputed_head == recorded_head triggers WARN instead of !=) makes the FRESH case emit a
# WARN and the STALE case go silent -- proving these cases are load-bearing rather than vacuous.
# Verified manually during implementation; not re-run on every invocation since it requires
# mutating the checker script in place.
# =====================================================================

# =====================================================================
# PARTIAL STALENESS: reproduces the observed incident shape directly -- ONE extension with an
# untouched file plus a changed file (STALE), alongside a SECOND, wholly-untouched extension in
# the SAME consumer tree (FRESH) -- proving a spot-check of the fresh extension would have
# concluded "the deploy is current" while a different extension in the identical tree was
# already stale. This is the exact reasoning trap named in the task motivating this suite
# extension: partial staleness, not whole-tree staleness, is what a single-file or
# single-extension spot-check misses.
# =====================================================================
PARTIAL_SOURCE_REPO="$WORKDIR/partial-source-repo"
mkdir -p "$PARTIAL_SOURCE_REPO/extA" "$PARTIAL_SOURCE_REPO/extB"
git init -q "$PARTIAL_SOURCE_REPO"
git -C "$PARTIAL_SOURCE_REPO" config user.email "test@example.com"
git -C "$PARTIAL_SOURCE_REPO" config user.name "Test"
echo "extA file1 v1" > "$PARTIAL_SOURCE_REPO/extA/file1.txt"
echo "extA file2 v1" > "$PARTIAL_SOURCE_REPO/extA/file2.txt"
echo "extB fileB v1" > "$PARTIAL_SOURCE_REPO/extB/fileB.txt"
git -C "$PARTIAL_SOURCE_REPO" add extA/file1.txt extA/file2.txt extB/fileB.txt
git -C "$PARTIAL_SOURCE_REPO" commit -q -m "initial extA + extB"
EXTA_DIR="$PARTIAL_SOURCE_REPO/extA"
EXTB_DIR="$PARTIAL_SOURCE_REPO/extB"
EXTA_HEAD_V1="$(git -C "$PARTIAL_SOURCE_REPO" log -1 --format=%H -- "$EXTA_DIR")"
EXTB_HEAD_V1="$(git -C "$PARTIAL_SOURCE_REPO" log -1 --format=%H -- "$EXTB_DIR")"
EXTA_FILE2_HASH_BEFORE="$(git -C "$PARTIAL_SOURCE_REPO" hash-object "$EXTA_DIR/file2.txt")"

# Commit a change to exactly ONE of extA's two files. extB and extA/file2.txt are untouched.
echo "extA file1 v2" > "$PARTIAL_SOURCE_REPO/extA/file1.txt"
git -C "$PARTIAL_SOURCE_REPO" add extA/file1.txt
git -C "$PARTIAL_SOURCE_REPO" commit -q -m "change extA/file1.txt only"
EXTA_FILE2_HASH_AFTER="$(git -C "$PARTIAL_SOURCE_REPO" hash-object "$EXTA_DIR/file2.txt")"

CONSUMER_PARTIAL="$WORKDIR/consumer-partial"
mkdir -p "$CONSUMER_PARTIAL"
cat > "$CONSUMER_PARTIAL/.claude-extensions.json" << EOF
{"version":"1.0.0","extensions":{"extA":{"version":"1.0.0","source_dir":"${EXTA_DIR}","source_git_head":"${EXTA_HEAD_V1}"},"extB":{"version":"1.0.0","source_dir":"${EXTB_DIR}","source_git_head":"${EXTB_HEAD_V1}"}}}
EOF

(
  # shellcheck disable=SC1090
  . "$WORKDIR/bin/lib/deploy-freshness-lib.sh"

  if [[ "$EXTA_FILE2_HASH_BEFORE" == "$EXTA_FILE2_HASH_AFTER" ]]; then
    echo "LIBPASS partial: extA/file2.txt is byte-identical across both commits (independently confirmed, not just 'a hash moved')"
  else
    echo "LIBFAIL partial: extA/file2.txt hash changed unexpectedly (before=$EXTA_FILE2_HASH_BEFORE after=$EXTA_FILE2_HASH_AFTER) -- fixture is broken"
  fi

  status_partial_a="$(deploy_freshness_status "$CONSUMER_PARTIAL" extA)"
  if [[ "$status_partial_a" == "STALE" ]]; then
    echo "LIBPASS partial: extA (one changed file among two) -> STALE"
  else
    echo "LIBFAIL partial: extA expected STALE got '$status_partial_a'"
  fi

  status_partial_b="$(deploy_freshness_status "$CONSUMER_PARTIAL" extB)"
  if [[ "$status_partial_b" == "FRESH" ]]; then
    echo "LIBPASS partial: extB (wholly untouched, same consumer tree) -> FRESH"
  else
    echo "LIBFAIL partial: extB expected FRESH got '$status_partial_b'"
  fi

  names_partial="$(deploy_freshness_stale_names "$CONSUMER_PARTIAL" | sort)"
  if [[ "$names_partial" == "extA" ]]; then
    echo "LIBPASS partial: stale_names lists extA and omits extB (one fresh, one stale, same tree)"
  else
    echo "LIBFAIL partial: stale_names expected exactly 'extA' got '<<<$names_partial>>>'"
  fi
) > "$WORKDIR/partial-lib-direct.out"

while IFS= read -r line; do
  case "$line" in
    LIBPASS*) pass "${line#LIBPASS }" ;;
    LIBFAIL*) fail "${line#LIBFAIL }" ;;
    *) : ;;
  esac
done < "$WORKDIR/partial-lib-direct.out"

# Checker-level confirmation of the same partial-staleness shape (subprocess path, not just the
# library-direct path exercised above).
OUT_PARTIAL="$(run_checker "$CONSUMER_PARTIAL" 2>&1)"
RC_PARTIAL=$?
WARN_COUNT_PARTIAL=$(printf '%s\n' "$OUT_PARTIAL" | grep -c '^WARN:')
if [[ "$RC_PARTIAL" -eq 0 && "$WARN_COUNT_PARTIAL" -eq 1 && "$OUT_PARTIAL" == *"'extA'"* && "$OUT_PARTIAL" != *"'extB'"* ]]; then
  pass "partial (checker subprocess): exactly one WARN naming 'extA', no mention of 'extB', exit 0"
else
  fail "partial (checker subprocess): expected exactly one WARN naming 'extA' only, got rc=$RC_PARTIAL warn_count=$WARN_COUNT_PARTIAL output=<<<$OUT_PARTIAL>>>"
fi

# =====================================================================
# Library-direct cases: source deploy-freshness-lib.sh in a scratch shell and exercise its two
# exported functions against the SAME fixture consumers created above, pinning the
# STALE/FRESH/CANNOTVERIFY three-way distinction the blocking backstop (Phase 3) depends on --
# a distinction check-deploy-freshness.sh's own WARN-or-silence output deliberately collapses.
# =====================================================================
(
  # shellcheck disable=SC1090
  . "$WORKDIR/bin/lib/deploy-freshness-lib.sh"

  status_stale="$(deploy_freshness_status "$CONSUMER_STALE" ext)"
  if [[ "$status_stale" == "STALE" ]]; then
    echo "LIBPASS status(STALE)"
  else
    echo "LIBFAIL status(STALE) expected STALE got '$status_stale'"
  fi

  status_fresh="$(deploy_freshness_status "$CONSUMER_FRESH" ext)"
  if [[ "$status_fresh" == "FRESH" ]]; then
    echo "LIBPASS status(FRESH)"
  else
    echo "LIBFAIL status(FRESH) expected FRESH got '$status_fresh'"
  fi

  status_missing="$(deploy_freshness_status "$CONSUMER_MISSING" ext)"
  if [[ "$status_missing" == "CANNOTVERIFY" ]]; then
    echo "LIBPASS status(MISSING FIELD -> CANNOTVERIFY)"
  else
    echo "LIBFAIL status(MISSING FIELD) expected CANNOTVERIFY got '$status_missing'"
  fi

  status_nongit="$(deploy_freshness_status "$CONSUMER_NONGIT" ext)"
  if [[ "$status_nongit" == "CANNOTVERIFY" ]]; then
    echo "LIBPASS status(NON-GIT -> CANNOTVERIFY)"
  else
    echo "LIBFAIL status(NON-GIT) expected CANNOTVERIFY got '$status_nongit'"
  fi

  status_nopath="$(deploy_freshness_status "$CONSUMER_NOPATH" ext)"
  if [[ "$status_nopath" == "CANNOTVERIFY" ]]; then
    echo "LIBPASS status(NOPATH -> CANNOTVERIFY)"
  else
    echo "LIBFAIL status(NOPATH) expected CANNOTVERIFY got '$status_nopath'"
  fi

  status_unknown_ext="$(deploy_freshness_status "$CONSUMER_STALE" "no-such-extension")"
  if [[ "$status_unknown_ext" == "CANNOTVERIFY" ]]; then
    echo "LIBPASS status(UNKNOWN EXTENSION NAME -> CANNOTVERIFY)"
  else
    echo "LIBFAIL status(UNKNOWN EXTENSION NAME) expected CANNOTVERIFY got '$status_unknown_ext'"
  fi

  names_stale="$(deploy_freshness_stale_names "$CONSUMER_STALE")"
  if [[ "$names_stale" == "ext" ]]; then
    echo "LIBPASS stale_names(STALE consumer -> exactly 'ext')"
  else
    echo "LIBFAIL stale_names(STALE consumer) expected 'ext' got '<<<$names_stale>>>'"
  fi

  names_fresh="$(deploy_freshness_stale_names "$CONSUMER_FRESH")"
  if [[ -z "$names_fresh" ]]; then
    echo "LIBPASS stale_names(FRESH consumer -> empty)"
  else
    echo "LIBFAIL stale_names(FRESH consumer) expected empty got '<<<$names_fresh>>>'"
  fi
) > "$WORKDIR/lib-direct.out"

while IFS= read -r line; do
  case "$line" in
    LIBPASS*) pass "${line#LIBPASS }" ;;
    LIBFAIL*) fail "${line#LIBFAIL }" ;;
    *) : ;;
  esac
done < "$WORKDIR/lib-direct.out"

# =====================================================================
# Streak-counter cases: consecutive-ignore escalation (see check-deploy-freshness.sh's own
# header block for the full contract). Uses a dedicated consumer fixture and its own specs/
# directory so these cases never interact with the STALE/FRESH fixtures above.
# =====================================================================
CONSUMER_STREAK="$WORKDIR/consumer-streak"
mkdir -p "$CONSUMER_STREAK/specs"
STREAK_FILE="$CONSUMER_STREAK/specs/.freshness-warn-streak.json"
write_state "$CONSUMER_STREAK" "$EXT_DIR" "0000000000000000000000000000000000dead"

for i in 1 2 3 4; do
  run_checker "$CONSUMER_STREAK" > "$WORKDIR/streak-run-${i}.out" 2>&1
done
if [[ -f "$STREAK_FILE" ]] && [[ "$(jq -r '.streak' "$STREAK_FILE" 2>/dev/null)" == "4" ]]; then
  pass "streak counter: 4 consecutive stale runs -> streak=4, no escalated banner yet"
else
  fail "streak counter: expected streak=4 after 4 runs, got <<<$(cat "$STREAK_FILE" 2>/dev/null || echo MISSING)>>>"
fi
if ! grep -q "consecutive" "$WORKDIR/streak-run-4.out"; then
  pass "streak counter: no escalated banner below threshold (streak=4 < 5)"
else
  fail "streak counter: escalated banner appeared before threshold: <<<$(cat "$WORKDIR/streak-run-4.out")>>>"
fi

run_checker "$CONSUMER_STREAK" > "$WORKDIR/streak-run-5.out" 2>&1
if [[ "$(jq -r '.streak' "$STREAK_FILE" 2>/dev/null)" == "5" ]] && grep -q "5 consecutive" "$WORKDIR/streak-run-5.out"; then
  pass "streak counter: 5th consecutive stale run -> escalated banner naming the count"
else
  fail "streak counter: expected streak=5 and escalated banner on run 5, got <<<$(cat "$WORKDIR/streak-run-5.out")>>>"
fi

# Reset-on-fresh: switch the fixture to the recorded-matches-current (fresh) state.
write_state "$CONSUMER_STREAK" "$EXT_DIR" "$HEAD_V1"
run_checker "$CONSUMER_STREAK" > "$WORKDIR/streak-run-fresh.out" 2>&1
if [[ ! -f "$STREAK_FILE" ]]; then
  pass "streak counter: reset (file removed) on a fresh run"
else
  fail "streak counter: expected streak file removed after fresh run, still present: $(cat "$STREAK_FILE")"
fi

# Cap at 999: pre-seed the counter above the cap and confirm one more stale run clamps it.
write_state "$CONSUMER_STREAK" "$EXT_DIR" "0000000000000000000000000000000000dead"
mkdir -p "$CONSUMER_STREAK/specs"
echo '{"streak": 999, "extensions": ["ext"], "updated": "2020-01-01T00:00:00Z"}' > "$STREAK_FILE"
run_checker "$CONSUMER_STREAK" > /dev/null 2>&1
if [[ "$(jq -r '.streak' "$STREAK_FILE" 2>/dev/null)" == "999" ]]; then
  pass "streak counter: capped at 999, does not grow unbounded"
else
  fail "streak counter: expected cap held at 999, got <<<$(cat "$STREAK_FILE")>>>"
fi
rm -f "$STREAK_FILE"

# Silent skip when specs/ does not exist.
CONSUMER_STREAK_NOSPECS="$WORKDIR/consumer-streak-nospecs"
write_state "$CONSUMER_STREAK_NOSPECS" "$EXT_DIR" "0000000000000000000000000000000000dead"
run_checker "$CONSUMER_STREAK_NOSPECS" > /dev/null 2>&1
RC_NOSPECS=$?
if [[ "$RC_NOSPECS" -eq 0 ]] && [[ ! -d "$CONSUMER_STREAK_NOSPECS/specs" ]]; then
  pass "streak counter: silent skip when specs/ does not exist (no dir created, exit 0)"
else
  fail "streak counter: expected exit 0 and no specs/ dir created, got rc=$RC_NOSPECS dir_exists=$([[ -d "$CONSUMER_STREAK_NOSPECS/specs" ]] && echo yes || echo no)"
fi

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
