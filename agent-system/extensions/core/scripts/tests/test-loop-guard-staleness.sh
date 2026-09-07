#!/usr/bin/env bash
# test-loop-guard-staleness.sh - Fixture-driven regression suite for the hard-mode loop-guard
# operational-staleness detector wired into skill-orchestrate/SKILL.md Stage 2, immediately
# before the pre-existing `if [ -f "$loop_guard_file" ] && jq empty ...` resume branch. The
# detector region is itself wrapped in `if [ "${hard_mode:-false}" = "true" ]; then ... fi`, so
# the fixture harness below sets `hard_mode=true` explicitly when running the extracted region --
# this was previously implicit because the whole target file was the hard-only engine. Exercises
# the three OR-combined signals (max_cycles drift, plan_version drift, mtime-age backstop),
# the archive-aside-never-delete behavior, and the explicit negative case that the rejected
# session_id-equality gate is genuinely absent -- see
# context/standards/orchestrator-runtime-files.md's "Operational staleness: a second, orthogonal
# freshness axis" for the full policy this suite verifies.
#
# Structural model: scripts/tests/test-resume-scan-nonconformance.sh (pass()/fail()/info()
# helpers, PASSED/FAILED integer counters, exit 0 all-pass / 1 any-fail / 2 environment error,
# mktemp -d workdir with an EXIT trap, sentinel-region extraction via awk, and a loud failure --
# not a silent skip -- if a sentinel marker is missing). Reuses the `loop-guard-staleness:begin`/
# `:end` sentinel region convention this suite's sibling established for the
# `resume-scan-conformance-gate` region in the same SKILL.md.
#
# HONEST SCOPE LIMIT: the extracted region ends the instant a stale guard/churn file is `mv`'d
# aside (or is a no-op when nothing is stale). What happens NEXT -- the pre-existing fresh-init
# `else` branch reinitializing the guard at cycle_count 0 -- depends on `task-lock.sh init-marker`
# and is NOT executed by this suite. That branch is verified structurally only: after a stale
# case, this suite asserts the original guard path no longer exists (so the unmodified
# `[ -f "$loop_guard_file" ]` test downstream must take the fresh-init branch) and greps the
# fresh-init payload to confirm it still seeds `"cycle_count": 0`. This mirrors how the sibling
# suite declares Site D's own scope limit rather than reproducing task-lock.sh's mutex machinery
# as a fixture.
#
# SINGLE-TARGET, RECORDED (not the two-target structure `test-loop-guard-budget-override.sh`
# gained): the task that ported single-task's loop guard/hard-mode counters/auxiliary dispatches
# into the batch engine (`orchestrate-cycle-plan.sh`/`orchestrate-cycle-postflight.sh`) did NOT
# port this detector -- grep-verified: neither script references `plan_version`, `mtime`, or
# `staleness` anywhere. This is a deliberate scope boundary, not an oversight: that task's own
# item (2) HARD names only churn/three-strikes detection and the burnout circuit breaker as
# porting targets (both now live in `orchestrate-churn.sh`); operational staleness is a THIRD,
# separate hard-mode mechanism this suite's own header already distinguishes from those two
# ("Operational staleness: a second, orthogonal freshness axis"), and porting it to the batch
# engine is out of scope for that task -- an explicitly separate, undecided question (see that
# task's own Non-Goals: "Extending the hard-only `loop-guard-staleness` detector to base mode").
# This suite therefore stays single-task-only for now; it should gain a second target the same
# way its sibling did only if and when a future task actually ports this detector.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required SKILL.md file or sentinel marker pair not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

# Resolved from the source store, matching how the sibling suite resolves its sites.
SKILL_FILE="$REPO_ROOT/agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"

if [[ ! -f "$SKILL_FILE" ]]; then
  echo "ERROR: required file not found: $SKILL_FILE" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# Full sentinel comment form, not the bare `loop-guard-staleness:begin`/`:end` substring: the
# merged SKILL.md's own design-decision table (a row documenting this same sentinel in prose)
# precedes the real sentinel comment, so a bare-substring match would start `extract_region`'s
# awk range at the prose row instead of the real region, and would inflate the "exactly one
# marker" count to two. The full comment form is verified unique (begin=1, end=1) in the merged
# file.
BEGIN_MARKER='# --- loop-guard-staleness:begin ---'
END_MARKER='# --- loop-guard-staleness:end ---'

# ─── Region extraction ─────────────────────────────────────────────────────────────────────────
# Fails loudly (not a silent skip) if a marker pair is missing.
extract_region() {
  local file="$1"
  if ! grep -qF "$BEGIN_MARKER" "$file"; then
    echo "ERROR: ${BEGIN_MARKER} not found in ${file}" >&2
    return 1
  fi
  if ! grep -qF "$END_MARKER" "$file"; then
    echo "ERROR: ${END_MARKER} not found in ${file}" >&2
    return 1
  fi
  awk -v b="$BEGIN_MARKER" -v e="$END_MARKER" '
    index($0, b) { flag=1 }
    flag { print }
    index($0, e) { flag=0 }
  ' "$file"
}

region="$(extract_region "$SKILL_FILE")" || exit 2

# Exactly one occurrence of each marker in the live file (Phase 3 verification bar). Counted as a
# fixed string (grep -cF), not a bare substring, so a prose mention of the sentinel name
# elsewhere in the merged file cannot inflate the count.
begin_count=$(grep -cF "$BEGIN_MARKER" "$SKILL_FILE")
end_count=$(grep -cF "$END_MARKER" "$SKILL_FILE")
if [[ "$begin_count" -eq 1 ]]; then
  pass "Exactly one '${BEGIN_MARKER}' marker in SKILL.md"
else
  fail "Expected exactly one '${BEGIN_MARKER}' marker, found ${begin_count}"
fi
if [[ "$end_count" -eq 1 ]]; then
  pass "Exactly one '${END_MARKER}' marker in SKILL.md"
else
  fail "Expected exactly one '${END_MARKER}' marker, found ${end_count}"
fi

# =====================================================================
# bash -n: the extracted region must be independently syntax-clean.
# =====================================================================
syntax_file="$WORKDIR/syntax.sh"
{
  echo '#!/usr/bin/env bash'
  echo 'TASK_DIR="/tmp/fixture"'
  echo 'loop_guard_file="/tmp/fixture/.orchestrator-loop-guard"'
  echo 'churn_file="/tmp/fixture/.orchestrator-churn-state.json"'
  echo 'MAX_CYCLES=13'
  echo 'current_plan_version="none"'
  printf '%s\n' "$region"
} > "$syntax_file"
if bash -n "$syntax_file" 2>"$WORKDIR/syntax.err"; then
  pass "Extracted loop-guard-staleness region is bash -n clean"
else
  fail "Extracted region failed bash -n: $(cat "$WORKDIR/syntax.err")"
fi

# =====================================================================
# bash -u: the region's only inputs are the five variables below (Phase 3 Scope Hypothesis).
# An unbound-variable error here means an undeclared input.
# =====================================================================
unbound_file="$WORKDIR/unbound.sh"
{
  echo 'set -u'
  printf '%s\n' "$region"
} > "$unbound_file"
if env -i PATH="$PATH" TASK_DIR="$WORKDIR/unbound-fixture" \
     loop_guard_file="$WORKDIR/unbound-fixture/.orchestrator-loop-guard" \
     churn_file="$WORKDIR/unbound-fixture/.orchestrator-churn-state.json" \
     MAX_CYCLES=13 current_plan_version="none" \
     bash "$unbound_file" >/dev/null 2>"$WORKDIR/unbound.err"; then
  pass "Region runs clean under bash -u with only the five declared inputs bound"
else
  fail "Region failed under bash -u with only the five declared inputs bound: $(cat "$WORKDIR/unbound.err")"
fi

# ─── Region execution harness ──────────────────────────────────────────────────────────────────
# Runs the extracted region in a subshell against a fixture TASK_DIR, reporting loop_guard_stale
# via stdout so the caller (which only sees the subshell's captured stdout/stderr, not its
# variable bindings) can assert on it. Stdout and stderr are captured to separate files.
#
# `hard_mode="true"` is set explicitly here: the whole extracted region is wrapped in
# `if [ "${hard_mode:-false}" = "true" ]; then ... fi` in the merged engine, so without this
# binding the entire detector body would silently no-op (loop_guard_stale would never even be
# set) instead of exercising the cases below. This was previously implicit -- the pre-merge
# target file was the hard-only engine, so `hard_mode` never needed to be set at all. The
# `__HARD_MODE__` echo lets the caller assert this binding is actually in effect (see the guard
# assertion right after Case 1 below), so a future edit that drops the export fails loudly rather
# than producing a silently-skipped detector region.
run_region() {
  local task_dir="$1" max_cycles="$2" plan_version="$3" out_file="$4" err_file="$5"
  (
    TASK_DIR="$task_dir"
    loop_guard_file="${task_dir}/.orchestrator-loop-guard"
    churn_file="${task_dir}/.orchestrator-churn-state.json"
    MAX_CYCLES="$max_cycles"
    current_plan_version="$plan_version"
    hard_mode="true"
    eval "$region"
    echo "__LOOP_GUARD_STALE__=${loop_guard_stale:-}"
    echo "__HARD_MODE__=${hard_mode:-}"
  ) > "$out_file" 2> "$err_file"
}

result_stale() { grep '^__LOOP_GUARD_STALE__=' "$1" | tail -1 | sed 's/^__LOOP_GUARD_STALE__=//'; }
result_hard_mode() { grep '^__HARD_MODE__=' "$1" | tail -1 | sed 's/^__HARD_MODE__=//'; }

# ─── Fixture builders ──────────────────────────────────────────────────────────────────────────
# make_guard PATH MAX_CYCLES PLAN_VERSION [MTIME_OFFSET_DAYS]
# Writes a syntactically-valid guard with all schema fields including plan_version. Backdates
# mtime by MTIME_OFFSET_DAYS (via GNU touch -d @epoch) when given.
make_guard() {
  local path="$1" max_cycles="$2" plan_version="$3" mtime_offset_days="${4:-}"
  jq -n --argjson max_cycles "$max_cycles" --arg plan_version "$plan_version" \
    --arg session_id "sess_fixture_guard_writer" \
    '{
      "session_id": $session_id,
      "cycle_count": 2,
      "max_cycles": $max_cycles,
      "current_state": "implementing",
      "hard_mode": true,
      "burnout_signals_this_session": 0,
      "infra_failures": 0,
      "max_infra_failures": 3,
      "started": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "plan_version": $plan_version
    }' > "$path"
  if [[ -n "$mtime_offset_days" ]]; then
    local epoch
    epoch=$(( $(date -u +%s) - mtime_offset_days * 86400 ))
    touch -d "@${epoch}" "$path" 2>/dev/null || touch -t "$(date -u -d "@${epoch}" +%Y%m%d%H%M.%S)" "$path"
  fi
}

# make_guard_no_plan_version PATH MAX_CYCLES -- old-format guard predating this schema field.
make_guard_no_plan_version() {
  local path="$1" max_cycles="$2"
  jq -n --argjson max_cycles "$max_cycles" --arg session_id "sess_fixture_guard_writer" \
    '{
      "session_id": $session_id,
      "cycle_count": 2,
      "max_cycles": $max_cycles,
      "current_state": "implementing",
      "hard_mode": true,
      "burnout_signals_this_session": 0,
      "infra_failures": 0,
      "max_infra_failures": 3,
      "started": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z"
    }' > "$path"
}

count_glob() {
  local dir="$1" pattern="$2"
  # shellcheck disable=SC2012
  ls -1 "${dir}"/${pattern} 2>/dev/null | wc -l | tr -d ' '
}

LIVE_MAX_CYCLES=13

# =====================================================================
# Case 1: Current guard. max_cycles matches, plan_version matches latest plan, mtime now.
# Expected: NOT stale; guard untouched; no archive file; no ERROR output.
# =====================================================================
fx1="$WORKDIR/case1"; mkdir -p "$fx1"
make_guard "$fx1/.orchestrator-loop-guard" "$LIVE_MAX_CYCLES" "01_current.md"
out="$WORKDIR/case1.out"; err="$WORKDIR/case1.err"
run_region "$fx1" "$LIVE_MAX_CYCLES" "01_current.md" "$out" "$err"

if [[ "$(result_stale "$out")" == "false" ]]; then
  pass "Case 1 (current guard): loop_guard_stale=false"
else
  fail "Case 1 (current guard): expected loop_guard_stale=false, got '$(result_stale "$out")'"
fi
if [[ -f "$fx1/.orchestrator-loop-guard" ]]; then
  pass "Case 1 (current guard): original guard path still present (untouched)"
else
  fail "Case 1 (current guard): original guard path missing -- should be untouched"
fi
if [[ "$(count_glob "$fx1" '.stale-loop-guard-*.json')" -eq 0 ]]; then
  pass "Case 1 (current guard): no stale-guard archive file created"
else
  fail "Case 1 (current guard): unexpected stale-guard archive file(s) created"
fi
if [[ ! -s "$err" ]]; then
  pass "Case 1 (current guard): stderr is empty"
else
  fail "Case 1 (current guard): expected empty stderr, got: $(cat "$err")"
fi
# Fixture guard assertion: the extracted region is entirely gated on `hard_mode = "true"` in the
# merged engine (see run_region's header comment). If a future edit drops the `hard_mode="true"`
# export, the whole detector body silently no-ops rather than exercising Case 1 at all -- this
# assertion converts that silent skip into a loud, named failure.
if [[ "$(result_hard_mode "$out")" == "true" ]]; then
  pass "Case 1 (current guard): fixture ran with hard_mode=true (detector region actually executed)"
else
  fail "Case 1 (current guard): expected fixture hard_mode=true, got '$(result_hard_mode "$out")' -- detector region may have been silently skipped"
fi

# =====================================================================
# Case 2 (THE NAMED REGRESSION): ordinary cross-conversational-turn resume. Identical to Case 1
# but mtime backdated 2 days, and the "caller's" session_id (used only by this harness to prove
# the point -- the region never reads session_id from the guard at all) differs from the guard's.
# Expected: NOT stale; guard untouched -- proves the rejected session_id-equality gate is
# genuinely absent.
# =====================================================================
fx2="$WORKDIR/case2"; mkdir -p "$fx2"
make_guard "$fx2/.orchestrator-loop-guard" "$LIVE_MAX_CYCLES" "01_current.md" 2
caller_session_id="sess_this_run_is_different_from_the_guard_writer"
guard_session_id=$(jq -r '.session_id' "$fx2/.orchestrator-loop-guard")
if [[ "$caller_session_id" != "$guard_session_id" ]]; then
  info "Case 2: caller session_id ('${caller_session_id}') differs from guard's session_id ('${guard_session_id}') by fixture design"
else
  fail "Case 2: fixture setup error -- caller and guard session_id must differ"
fi
out="$WORKDIR/case2.out"; err="$WORKDIR/case2.err"
run_region "$fx2" "$LIVE_MAX_CYCLES" "01_current.md" "$out" "$err"

if [[ "$(result_stale "$out")" == "false" ]]; then
  pass "Case 2 (ordinary cross-turn resume, different session_id): loop_guard_stale=false"
else
  fail "Case 2 (ordinary cross-turn resume): expected loop_guard_stale=false, got '$(result_stale "$out")'"
fi
if [[ -f "$fx2/.orchestrator-loop-guard" ]]; then
  pass "Case 2 (ordinary cross-turn resume): original guard path still present (untouched)"
else
  fail "Case 2 (ordinary cross-turn resume): original guard path missing -- should be untouched despite the session_id mismatch and 2-day-old mtime"
fi

# =====================================================================
# Case 3: version drift. guard max_cycles=5 against live MAX_CYCLES=13.
# Expected: stale; ERROR: STALE LOOP GUARD naming max_cycles; guard moved to
# .stale-loop-guard-*.json; original path gone.
# =====================================================================
fx3="$WORKDIR/case3"; mkdir -p "$fx3"
make_guard "$fx3/.orchestrator-loop-guard" 5 "01_current.md"
out="$WORKDIR/case3.out"; err="$WORKDIR/case3.err"
run_region "$fx3" "$LIVE_MAX_CYCLES" "01_current.md" "$out" "$err"

if [[ "$(result_stale "$out")" == "true" ]]; then
  pass "Case 3 (max_cycles drift): loop_guard_stale=true"
else
  fail "Case 3 (max_cycles drift): expected loop_guard_stale=true, got '$(result_stale "$out")'"
fi
if grep -q 'ERROR: STALE LOOP GUARD' "$err" && grep -q 'max_cycles' "$err"; then
  pass "Case 3 (max_cycles drift): stderr names 'ERROR: STALE LOOP GUARD' and 'max_cycles'"
else
  fail "Case 3 (max_cycles drift): stderr missing expected content: $(cat "$err")"
fi
if [[ ! -f "$fx3/.orchestrator-loop-guard" ]]; then
  pass "Case 3 (max_cycles drift): original guard path no longer exists"
else
  fail "Case 3 (max_cycles drift): original guard path still exists -- should have been archived"
fi
if [[ "$(count_glob "$fx3" '.stale-loop-guard-*.json')" -eq 1 ]]; then
  pass "Case 3 (max_cycles drift): exactly one stale-guard archive file created"
else
  fail "Case 3 (max_cycles drift): expected exactly one stale-guard archive file, found $(count_glob "$fx3" '.stale-loop-guard-*.json')"
fi

# =====================================================================
# Case 4: plan-lineage drift. guard plan_version="01_old.md", live latest is "03_new.md".
# Expected: stale; notice names the plan-lineage signal and both values.
# =====================================================================
fx4="$WORKDIR/case4"; mkdir -p "$fx4"
make_guard "$fx4/.orchestrator-loop-guard" "$LIVE_MAX_CYCLES" "01_old.md"
out="$WORKDIR/case4.out"; err="$WORKDIR/case4.err"
run_region "$fx4" "$LIVE_MAX_CYCLES" "03_new.md" "$out" "$err"

if [[ "$(result_stale "$out")" == "true" ]]; then
  pass "Case 4 (plan-lineage drift): loop_guard_stale=true"
else
  fail "Case 4 (plan-lineage drift): expected loop_guard_stale=true, got '$(result_stale "$out")'"
fi
if grep -q 'plan_version drift' "$err" && grep -q '01_old.md' "$err" && grep -q '03_new.md' "$err"; then
  pass "Case 4 (plan-lineage drift): stderr names the plan-lineage signal and both values"
else
  fail "Case 4 (plan-lineage drift): stderr missing expected content: $(cat "$err")"
fi

# =====================================================================
# Case 5: mtime backstop. mtime backdated 30 days, all other fields current.
# Expected: stale; notice names the age signal and the threshold.
# =====================================================================
fx5="$WORKDIR/case5"; mkdir -p "$fx5"
make_guard "$fx5/.orchestrator-loop-guard" "$LIVE_MAX_CYCLES" "01_current.md" 30
out="$WORKDIR/case5.out"; err="$WORKDIR/case5.err"
run_region "$fx5" "$LIVE_MAX_CYCLES" "01_current.md" "$out" "$err"

if [[ "$(result_stale "$out")" == "true" ]]; then
  pass "Case 5 (mtime backstop): loop_guard_stale=true"
else
  fail "Case 5 (mtime backstop): expected loop_guard_stale=true, got '$(result_stale "$out")'"
fi
if grep -q 'mtime age' "$err" && grep -q 'threshold' "$err"; then
  pass "Case 5 (mtime backstop): stderr names the age signal and the threshold"
else
  fail "Case 5 (mtime backstop): stderr missing expected content: $(cat "$err")"
fi

# =====================================================================
# Case 6: old-format guard (no plan_version field), everything else current.
# Expected: NOT stale -- a missing field is not evidence.
# =====================================================================
fx6="$WORKDIR/case6"; mkdir -p "$fx6"
make_guard_no_plan_version "$fx6/.orchestrator-loop-guard" "$LIVE_MAX_CYCLES"
out="$WORKDIR/case6.out"; err="$WORKDIR/case6.err"
run_region "$fx6" "$LIVE_MAX_CYCLES" "01_current.md" "$out" "$err"

if [[ "$(result_stale "$out")" == "false" ]]; then
  pass "Case 6 (old-format guard, no plan_version): loop_guard_stale=false"
else
  fail "Case 6 (old-format guard, no plan_version): expected loop_guard_stale=false, got '$(result_stale "$out")'"
fi
if [[ -f "$fx6/.orchestrator-loop-guard" ]]; then
  pass "Case 6 (old-format guard, no plan_version): original guard path still present"
else
  fail "Case 6 (old-format guard, no plan_version): original guard path missing -- should be untouched"
fi

# =====================================================================
# Case 7: no plans/ directory yet. guard current, plans/ absent (current_plan_version="none").
# Expected: NOT stale; region exits 0 with no stderr noise.
# =====================================================================
fx7="$WORKDIR/case7"; mkdir -p "$fx7"
make_guard "$fx7/.orchestrator-loop-guard" "$LIVE_MAX_CYCLES" "none"
out="$WORKDIR/case7.out"; err="$WORKDIR/case7.err"
run_region "$fx7" "$LIVE_MAX_CYCLES" "none" "$out" "$err"

if [[ "$(result_stale "$out")" == "false" ]]; then
  pass "Case 7 (no plans/ directory yet): loop_guard_stale=false"
else
  fail "Case 7 (no plans/ directory yet): expected loop_guard_stale=false, got '$(result_stale "$out")'"
fi
if [[ ! -s "$err" ]]; then
  pass "Case 7 (no plans/ directory yet): stderr is empty"
else
  fail "Case 7 (no plans/ directory yet): expected empty stderr, got: $(cat "$err")"
fi

# =====================================================================
# Case 8: churn co-archive. A stale case (version drift) with a churn-state file present.
# Expected: both archived, sharing the same timestamp suffix.
# =====================================================================
fx8="$WORKDIR/case8"; mkdir -p "$fx8"
make_guard "$fx8/.orchestrator-loop-guard" 5 "01_current.md"
echo '{"session_id":"sess_fixture_guard_writer","total_churn":3,"target_churn":{},"adversarial_triggers":0,"audit_dispatches":0}' > "$fx8/.orchestrator-churn-state.json"
out="$WORKDIR/case8.out"; err="$WORKDIR/case8.err"
run_region "$fx8" "$LIVE_MAX_CYCLES" "01_current.md" "$out" "$err"

if [[ ! -f "$fx8/.orchestrator-loop-guard" && ! -f "$fx8/.orchestrator-churn-state.json" ]]; then
  pass "Case 8 (churn co-archive): both original paths gone"
else
  fail "Case 8 (churn co-archive): expected both original paths gone (guard present=$([ -f "$fx8/.orchestrator-loop-guard" ] && echo yes || echo no), churn present=$([ -f "$fx8/.orchestrator-churn-state.json" ] && echo yes || echo no))"
fi
guard_archive="$(ls -1 "$fx8"/.stale-loop-guard-*.json 2>/dev/null | head -1)"
churn_archive="$(ls -1 "$fx8"/.stale-churn-state-*.json 2>/dev/null | head -1)"
if [[ -n "$guard_archive" && -n "$churn_archive" ]]; then
  guard_ts="${guard_archive##*loop-guard-}"; guard_ts="${guard_ts%.json}"
  churn_ts="${churn_archive##*churn-state-}"; churn_ts="${churn_ts%.json}"
  if [[ "$guard_ts" == "$churn_ts" ]]; then
    pass "Case 8 (churn co-archive): guard and churn archives share the same timestamp suffix (${guard_ts})"
  else
    fail "Case 8 (churn co-archive): timestamp suffixes differ (guard=${guard_ts}, churn=${churn_ts})"
  fi
else
  fail "Case 8 (churn co-archive): expected both archive files to exist (guard=${guard_archive:-MISSING}, churn=${churn_archive:-MISSING})"
fi

# =====================================================================
# Case 9: churn absent. A stale case (version drift) with no churn-state file at all.
# Expected: guard archived; no error, no empty churn archive created.
# =====================================================================
fx9="$WORKDIR/case9"; mkdir -p "$fx9"
make_guard "$fx9/.orchestrator-loop-guard" 5 "01_current.md"
out="$WORKDIR/case9.out"; err="$WORKDIR/case9.err"
run_region "$fx9" "$LIVE_MAX_CYCLES" "01_current.md" "$out" "$err"

if [[ ! -f "$fx9/.orchestrator-loop-guard" ]]; then
  pass "Case 9 (churn absent): guard archived (original path gone)"
else
  fail "Case 9 (churn absent): guard was not archived"
fi
if [[ "$(count_glob "$fx9" '.stale-churn-state-*.json')" -eq 0 ]]; then
  pass "Case 9 (churn absent): no empty churn archive created"
else
  fail "Case 9 (churn absent): unexpected churn archive file created despite no churn file existing"
fi

# =====================================================================
# Structural (grep-based) assertion: the fresh-init branch downstream of the untouched
# `if [ -f "$loop_guard_file" ] ... else` is unchanged and still seeds cycle_count: 0. Verified
# structurally, not by execution -- see the header's HONEST SCOPE LIMIT note (task-lock.sh
# dependency).
# =====================================================================
if grep -q '"cycle_count": 0,' "$SKILL_FILE"; then
  pass "Structural: fresh-init payload still seeds \"cycle_count\": 0"
else
  fail "Structural: fresh-init payload does not appear to seed \"cycle_count\": 0"
fi
if grep -q '"plan_version": \$plan_version' "$SKILL_FILE"; then
  pass "Structural: fresh-init payload seeds plan_version from \$plan_version"
else
  fail "Structural: fresh-init payload does not appear to seed plan_version"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
