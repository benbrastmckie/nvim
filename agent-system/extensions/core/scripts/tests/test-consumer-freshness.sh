#!/usr/bin/env bash
# test-consumer-freshness.sh - Fixture-driven regression suite for check-consumer-freshness.sh,
# the source-side TIER 3 fleet freshness report (see that script's header for the full tiering
# model and context/patterns/regeneration-is-manual-only.md's "Detecting When You're Stale"
# section).
#
# Structural model: test-deploy-freshness.sh's pass()/fail()/info() helpers, PASSED/FAILED
# integer counters, exit 0 on all-pass / exit 1 on any-fail, and trap-based scratch WORKDIR
# pattern (matching test-deploy-propagation.sh). This suite drives the real subprocess script
# (never sources it) against fabricated fixture consumers -- never against this repo's own
# .claude-extensions.json, specs/ tree, or any real consumer repo.
#
# Fixtures: temp consumer repos with synthetic .claude-extensions.json files (fresh head, stale
# head, missing source_git_head, missing directory, missing extension state) plus a temp
# registry pointing at them, injected via the CONSUMER_FRESHNESS_REGISTRY_PATH env-var override
# check-consumer-freshness.sh reads (added alongside its default relative-path resolution).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (checker script, library, or git not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

CHECKER="$(common_test_resolve_subject "check-consumer-freshness.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/check-consumer-freshness.sh" \
  "$SCRIPT_DIR/../check-consumer-freshness.sh")" || exit 2
common_test_declare_subject "$CHECKER"

LIB="$(common_test_resolve_subject "deploy-freshness-lib.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/deploy-freshness-lib.sh" \
  "$SCRIPT_DIR/../lib/deploy-freshness-lib.sh")" || exit 2
common_test_declare_subject "$LIB"

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not found on PATH" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found on PATH" >&2
  exit 2
fi

PASSED=0
FAILED=0

WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

common_test_info "Using checker: $CHECKER"
common_test_info "Using library: $LIB"

# --- Fixture: throwaway source-store stand-in with TWO committed extension subdirectories ---
# Mirrors the real repo layout (agent-system/extensions/<name>) rather than a flat
# <source-repo>/<name> layout -- the --discover filter below matches on
# "<source_repo>/agent-system/extensions/" exactly as check-consumer-freshness.sh's own
# --discover implementation does against the real fleet, so the fixture must use the same shape.
SOURCE_REPO="$WORKDIR/source-repo"
mkdir -p "$SOURCE_REPO/agent-system/extensions/ext-a" "$SOURCE_REPO/agent-system/extensions/ext-b"
git init -q "$SOURCE_REPO"
git -C "$SOURCE_REPO" config user.email "test@example.com"
git -C "$SOURCE_REPO" config user.name "Test"
echo "v1" > "$SOURCE_REPO/agent-system/extensions/ext-a/file.txt"
echo "v1" > "$SOURCE_REPO/agent-system/extensions/ext-b/file.txt"
git -C "$SOURCE_REPO" add agent-system/extensions/ext-a/file.txt agent-system/extensions/ext-b/file.txt
git -C "$SOURCE_REPO" commit -q -m "initial"
EXT_A="$SOURCE_REPO/agent-system/extensions/ext-a"
EXT_B="$SOURCE_REPO/agent-system/extensions/ext-b"
HEAD_A_V1="$(git -C "$SOURCE_REPO" log -1 --format=%H -- "$EXT_A")"
HEAD_B_V1="$(git -C "$SOURCE_REPO" log -1 --format=%H -- "$EXT_B")"

# Real checker + its sibling library, copied byte-for-byte so the suite exercises exactly the
# deployed artifacts, preserving the checker's SCRIPT_DIR-relative sibling-lookup contract.
mkdir -p "$WORKDIR/bin/lib"
cp "$CHECKER" "$WORKDIR/bin/check-consumer-freshness.sh"
chmod +x "$WORKDIR/bin/check-consumer-freshness.sh"
cp "$LIB" "$WORKDIR/bin/lib/deploy-freshness-lib.sh"

# $1 consumer dir, $2 ext_name, $3 ext_dir, $4 head, $5 omit-head flag
write_ext_state() {
  local consumer="$1" name="$2" ext_dir="$3" head="$4" omit_head="${5:-false}"
  mkdir -p "$consumer"
  if [[ "$omit_head" == "true" ]]; then
    jq -n --arg n "$name" --arg d "$ext_dir" \
      '{version:"1.0.0", extensions:{($n):{version:"1.0.0", source_dir:$d}}}' \
      > "$consumer/.claude-extensions.json"
  else
    jq -n --arg n "$name" --arg d "$ext_dir" --arg h "$head" \
      '{version:"1.0.0", extensions:{($n):{version:"1.0.0", source_dir:$d, source_git_head:$h}}}' \
      > "$consumer/.claude-extensions.json"
  fi
}

CONSUMER_STALE="$WORKDIR/consumer-stale"
write_ext_state "$CONSUMER_STALE" "ext-a" "$EXT_A" "0000000000000000000000000000000000dead"

CONSUMER_FRESH="$WORKDIR/consumer-fresh"
write_ext_state "$CONSUMER_FRESH" "ext-b" "$EXT_B" "$HEAD_B_V1"

CONSUMER_CANNOTVERIFY="$WORKDIR/consumer-cannotverify"
write_ext_state "$CONSUMER_CANNOTVERIFY" "ext-a" "$EXT_A" "" true

CONSUMER_MISSING="$WORKDIR/consumer-missing-does-not-exist"

CONSUMER_NOEXTSTATE="$WORKDIR/consumer-noextstate"
mkdir -p "$CONSUMER_NOEXTSTATE"

# --- Registry fixture ---
REGISTRY="$WORKDIR/known-consumer-repos.json"
jq -n \
  --arg src "$SOURCE_REPO" \
  --arg stale "$CONSUMER_STALE" \
  --arg fresh "$CONSUMER_FRESH" \
  --arg cv "$CONSUMER_CANNOTVERIFY" \
  --arg missing "$CONSUMER_MISSING" \
  --arg noext "$CONSUMER_NOEXTSTATE" \
  '{
    "$schema": "known-consumer-repos-v1",
    source_repo: $src,
    discover_roots: [],
    consumers: [
      {path: $stale, note: "stale fixture"},
      {path: $fresh, note: "fresh fixture"},
      {path: $cv, note: "cannotverify fixture"},
      {path: $missing, note: "missing fixture"},
      {path: $noext, note: "noextstate fixture"}
    ]
  }' > "$REGISTRY"

run_checker() {
  CONSUMER_FRESHNESS_REGISTRY_PATH="$REGISTRY" bash "$WORKDIR/bin/check-consumer-freshness.sh" "$@"
}

# =====================================================================
# Case: default report -- one row per registered consumer, correct classification
# =====================================================================
OUT_DEFAULT="$(run_checker 2>&1)"
RC_DEFAULT=$?

if [[ "$OUT_DEFAULT" == *"$CONSUMER_STALE"*"STALE"* ]]; then
  common_test_pass "default report: stale fixture classified STALE"
else
  common_test_fail "default report: expected STALE row for $CONSUMER_STALE, got <<<$OUT_DEFAULT>>>"
fi
if [[ "$OUT_DEFAULT" == *"$CONSUMER_FRESH"*"FRESH"* ]]; then
  common_test_pass "default report: fresh fixture classified FRESH"
else
  common_test_fail "default report: expected FRESH row for $CONSUMER_FRESH, got <<<$OUT_DEFAULT>>>"
fi
if [[ "$OUT_DEFAULT" == *"$CONSUMER_CANNOTVERIFY"*"CANNOTVERIFY"* ]]; then
  common_test_pass "default report: missing-source_git_head fixture classified CANNOTVERIFY"
else
  common_test_fail "default report: expected CANNOTVERIFY row for $CONSUMER_CANNOTVERIFY, got <<<$OUT_DEFAULT>>>"
fi
if [[ "$OUT_DEFAULT" == *"$CONSUMER_MISSING"*"MISSING"* ]]; then
  common_test_pass "default report: nonexistent path classified MISSING"
else
  common_test_fail "default report: expected MISSING row for $CONSUMER_MISSING, got <<<$OUT_DEFAULT>>>"
fi
if [[ "$OUT_DEFAULT" == *"$CONSUMER_NOEXTSTATE"*"NOEXTSTATE"* ]]; then
  common_test_pass "default report: no .claude-extensions.json classified NOEXTSTATE"
else
  common_test_fail "default report: expected NOEXTSTATE row for $CONSUMER_NOEXTSTATE, got <<<$OUT_DEFAULT>>>"
fi
if [[ "$OUT_DEFAULT" == *"$SOURCE_REPO"*"(source)"*"FRESH"* ]]; then
  common_test_pass "default report: source_repo row present and marked distinctly"
else
  common_test_fail "default report: expected source_repo row, got <<<$OUT_DEFAULT>>>"
fi
if [[ "$RC_DEFAULT" -eq 1 ]]; then
  common_test_pass "default report: exit 1 (at least one stale/cannotverify/missing/noextstate)"
else
  common_test_fail "default report: expected exit 1, got rc=$RC_DEFAULT"
fi

# =====================================================================
# Case: --stale-only suppresses FRESH rows
# =====================================================================
OUT_STALEONLY="$(run_checker --stale-only 2>&1)"
if [[ "$OUT_STALEONLY" != *"$CONSUMER_FRESH"* ]]; then
  common_test_pass "--stale-only: fresh fixture row suppressed"
else
  common_test_fail "--stale-only: fresh fixture row should be suppressed, got <<<$OUT_STALEONLY>>>"
fi
if [[ "$OUT_STALEONLY" == *"$CONSUMER_STALE"* ]]; then
  common_test_pass "--stale-only: stale fixture row still present"
else
  common_test_fail "--stale-only: expected stale fixture row, got <<<$OUT_STALEONLY>>>"
fi

# =====================================================================
# Case: exit 0 when no registered consumer is stale (single-fresh registry)
# =====================================================================
REGISTRY_ALLFRESH="$WORKDIR/known-consumer-repos-allfresh.json"
jq -n --arg src "$SOURCE_REPO" --arg fresh "$CONSUMER_FRESH" \
  '{"$schema":"known-consumer-repos-v1", source_repo:$src, discover_roots:[], consumers:[{path:$fresh, note:"fresh only"}]}' \
  > "$REGISTRY_ALLFRESH"
OUT_ALLFRESH="$(CONSUMER_FRESHNESS_REGISTRY_PATH="$REGISTRY_ALLFRESH" bash "$WORKDIR/bin/check-consumer-freshness.sh" 2>&1)"
RC_ALLFRESH=$?
if [[ "$RC_ALLFRESH" -eq 0 ]]; then
  common_test_pass "all-fresh registry: exit 0"
else
  common_test_fail "all-fresh registry: expected exit 0, got rc=$RC_ALLFRESH output=<<<$OUT_ALLFRESH>>>"
fi

# =====================================================================
# Case: exit 2 on missing/unparseable registry
# =====================================================================
OUT_NOREG="$(CONSUMER_FRESHNESS_REGISTRY_PATH="$WORKDIR/does-not-exist.json" bash "$WORKDIR/bin/check-consumer-freshness.sh" 2>&1)"
RC_NOREG=$?
if [[ "$RC_NOREG" -eq 2 ]]; then
  common_test_pass "missing registry: exit 2"
else
  common_test_fail "missing registry: expected exit 2, got rc=$RC_NOREG output=<<<$OUT_NOREG>>>"
fi

BAD_REGISTRY="$WORKDIR/bad-registry.json"
echo "not json" > "$BAD_REGISTRY"
OUT_BADREG="$(CONSUMER_FRESHNESS_REGISTRY_PATH="$BAD_REGISTRY" bash "$WORKDIR/bin/check-consumer-freshness.sh" 2>&1)"
RC_BADREG=$?
if [[ "$RC_BADREG" -eq 2 ]]; then
  common_test_pass "unparseable registry: exit 2"
else
  common_test_fail "unparseable registry: expected exit 2, got rc=$RC_BADREG output=<<<$OUT_BADREG>>>"
fi

# =====================================================================
# Case: --discover reports an unregistered repo
# =====================================================================
DISCOVER_ROOT="$WORKDIR/discover-root"
UNREG_CONSUMER="$DISCOVER_ROOT/unregistered-consumer"
write_ext_state "$UNREG_CONSUMER" "ext-a" "$EXT_A" "$HEAD_A_V1"

REGISTRY_DISCOVER="$WORKDIR/known-consumer-repos-discover.json"
jq -n --arg src "$SOURCE_REPO" --arg root "$DISCOVER_ROOT" \
  '{"$schema":"known-consumer-repos-v1", source_repo:$src, discover_roots:[$root], consumers:[]}' \
  > "$REGISTRY_DISCOVER"
OUT_DISCOVER="$(CONSUMER_FRESHNESS_REGISTRY_PATH="$REGISTRY_DISCOVER" bash "$WORKDIR/bin/check-consumer-freshness.sh" --discover 2>&1)"
if [[ "$OUT_DISCOVER" == *"UNREGISTERED: $UNREG_CONSUMER"* ]]; then
  common_test_pass "--discover: unregistered on-disk consumer reported"
else
  common_test_fail "--discover: expected UNREGISTERED line for $UNREG_CONSUMER, got <<<$OUT_DISCOVER>>>"
fi

# =====================================================================
# Case: no-write invariant -- consumer fixtures and registry byte-identical before/after
# =====================================================================
HASH_BEFORE="$(md5sum "$CONSUMER_STALE/.claude-extensions.json" "$REGISTRY" 2>/dev/null)"
run_checker --discover >/dev/null 2>&1
HASH_AFTER="$(md5sum "$CONSUMER_STALE/.claude-extensions.json" "$REGISTRY" 2>/dev/null)"
if [[ "$HASH_BEFORE" == "$HASH_AFTER" ]]; then
  common_test_pass "no-write invariant: consumer fixture and registry unchanged across a run"
else
  common_test_fail "no-write invariant: fixture or registry was modified by the checker"
fi

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
