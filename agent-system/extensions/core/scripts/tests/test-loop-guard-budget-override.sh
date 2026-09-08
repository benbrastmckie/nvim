#!/usr/bin/env bash
# test-loop-guard-budget-override.sh - Regression suite for Defect B: the explicit,
# operator-typed `--continue-budget` override that lets an operator continue a task's work past
# an exhausted MAX_CYCLES work-cycle budget.
#
# TWO-TARGET STRUCTURE (task that ported single-task's loop guard into the batch engine): this
# suite now covers the SAME override mechanism in BOTH engines that implement it.
#   TARGET 1 (below): the merged single-task `skill-orchestrate/SKILL.md` engine, exercised in
#     BOTH `hard_mode` values via the SKILL.md-extracted sentinel region (unchanged by that task
#     -- the single-task engine stays live and stays the default path).
#   TARGET 2 (bottom of this file, after the Summary-adjacent marker): `orchestrate-cycle-plan.sh`
#     itself, called directly (not extracted) -- Decision 1 of that task moved this exact
#     mechanism (archive-aside, reset `cycle_count` to 0 in place, preserve
#     `dispatch_seq_counter`/`detected_defects`) into the batch engine's own top-of-cycle
#     eligibility loop. Target 2's two cases re-prove the same headline properties Target 1's
#     Cases 1/2 prove, against the batch engine; `test-orchestrate-cycle-plan.sh`'s own Group 8 is
#     the authoritative, much larger suite for that engine (cross-session cumulative resume,
#     mode-aware `max_cycles`, mixed-batch exclusion) -- Target 2 here is a second, narrower angle
#     from this suite's own name, not a replacement for Group 8.
#
# Structural model (Target 1): scripts/tests/test-handoff-dispatch-identity.sh (sentinel-region
# extraction via awk, mktemp -d workdir with an EXIT trap, pass()/fail()/info() helpers, exit 0
# all-pass / 1 any-fail / 2 environment error, every case run against BOTH `hard_mode` values).
#
# Region scope (HONEST SCOPE LIMIT, matching test-loop-guard-staleness.sh's own convention): the
# single extracted region spans from the `budget-continuation-override:begin` sentinel through
# the unique "Resuming — cycle" echo inside the pre-existing resume-read `if` branch, with a
# synthetic `fi` appended to close that intentionally-truncated block. This exercises the full
# override mechanism (peek, archive-or-refuse, reinit) AND the immediately-following resume read
# (cycle_count/dispatch_seq_counter/session_id-mismatch-INFO-log, plus the hard-mode-only burnout
# echo), but deliberately does NOT reach the fresh-init `else` branch, which depends on
# `task-lock.sh init-marker` and is out of scope here exactly as it is for the staleness suite's
# own sibling region. The region is run once per `hard_mode` value (false, true) rather than once
# per source file, since both values now live in the same merged engine.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

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

BEGIN_MARKER='budget-continuation-override:begin'
# Base resume-echo anchor only -- the merged file has a single unconditional "Resuming — cycle"
# echo (the former hard-only "burnout signals so far" wording now lives in a separate,
# self-closed `if [ "${hard_mode:-false}" = "true" ]` block immediately above this echo, not as
# an alternate ending to it). Do NOT substitute the similarly-worded "Resuming (lost init race) —
# cycle ..." line further down the file -- that is the fresh-init `else` branch, a different
# extraction target this suite deliberately does not cover (see HONEST SCOPE LIMIT above).
RESUME_ANCHOR='Resuming — cycle $cycle_count of $MAX_CYCLES (infra failures'

# Plain substring match (index()), not a regex match ($0 ~ pat) -- the anchor contains regex
# metacharacters ($, () that would otherwise need escaping and are fragile to get right.
extract_region() {
  local file="$1" resume_anchor="$2"
  awk -v b="$BEGIN_MARKER" -v r="$resume_anchor" '
    index($0, b) > 0 { flag=1 }
    flag { print }
    index($0, r) > 0 { if (flag) { print "fi"; exit } }
  ' "$file"
}

bcount=$(grep -c "$BEGIN_MARKER" "$SKILL_FILE")
if [[ "$bcount" -eq 1 ]]; then
  pass "Exactly one '${BEGIN_MARKER}' marker in skills/SKILL.md"
else
  fail "Expected exactly one '${BEGIN_MARKER}' marker in skills/SKILL.md, found ${bcount}"
fi

region="$(extract_region "$SKILL_FILE" "$RESUME_ANCHOR")"

if [[ -z "$region" ]]; then
  echo "ERROR: could not extract budget-override region from $SKILL_FILE" >&2
  exit 2
fi

# =====================================================================
# bash -n: the extracted region must be independently syntax-clean.
# =====================================================================
syntax_file="$WORKDIR/syntax.sh"
{
  echo '#!/usr/bin/env bash'
  echo 'TASK_DIR="/tmp/fixture"'
  echo 'loop_guard_file="/tmp/fixture/.orchestrator-loop-guard"'
  echo 'MAX_CYCLES=13'
  echo 'MAX_INFRA_FAILURES=3'
  echo 'continue_budget_flag=false'
  echo 'task_number=1'
  echo 'session_id="sess_fixture"'
  echo 'hard_mode="false"'
  printf '%s\n' "$region"
} > "$syntax_file"
if bash -n "$syntax_file" 2>"$WORKDIR/syntax.err"; then
  pass "Extracted region is bash -n clean"
else
  fail "Extracted region failed bash -n: $(cat "$WORKDIR/syntax.err")"
fi

# ── Region execution harness ────────────────────────────────────────────────────────────────────
# Runs the extracted region in a subshell against a fixture TASK_DIR, under a given `hard_mode`
# value. `exit 1` in the flag-absent branch only exits this SUBSHELL, not the test script itself,
# so it is safe to execute directly -- the caller observes it via $? from the subshell, not
# process termination. `hard_mode` gates only the self-closed burnout-echo block inside the
# region (see the region-scope comment above); the rest of the region -- including the
# guard_session_id mismatch INFO log Case 4 exercises -- is unconditional, shared code, so this
# is the ONLY per-`hard_mode` behavioral difference the region itself can produce.
run_region() {
  local region="$1" task_dir="$2" max_cycles="$3" flag="$4" session_id="$5" hard_mode_val="$6" out_file="$7" err_file="$8"
  (
    TASK_DIR="$task_dir"
    loop_guard_file="${task_dir}/.orchestrator-loop-guard"
    MAX_CYCLES="$max_cycles"
    MAX_INFRA_FAILURES=3
    continue_budget_flag="$flag"
    task_number=1
    session_id="$session_id"
    hard_mode="$hard_mode_val"
    eval "$region"
    echo "__EXIT_CODE__=0"
  ) > "$out_file" 2> "$err_file"
  echo $?
}

make_guard() {
  local path="$1" cycle_count="$2" session_id="${3:-sess_fixture_guard_writer}" \
        dispatch_seq_counter="${4:-3}" detected_defects="${5:-[]}"
  jq -n --argjson cc "$cycle_count" --arg sid "$session_id" --argjson dsc "$dispatch_seq_counter" \
    --argjson dd "$detected_defects" \
    '{"session_id":$sid,"cycle_count":$cc,"max_cycles":13,"infra_failures":0,
      "max_infra_failures":3,"current_state":"implementing","started":"2026-01-01T00:00:00Z",
      "last_updated":"2026-01-01T00:00:00Z","dispatch_seq_counter":$dsc,"detected_defects":$dd}' \
    > "$path"
}

count_glob() {
  local dir="$1" pattern="$2"
  # shellcheck disable=SC2012
  ls -1 "${dir}"/${pattern} 2>/dev/null | wc -l | tr -d ' '
}

LIVE_MAX_CYCLES=13

for hard_mode_val in "false" "true"; do
  engine_label="hard_mode=${hard_mode_val}"

  # =====================================================================
  # Case 1: cycle_count == MAX_CYCLES, flag ABSENT. Expected: subshell exits 1 (refuses
  # immediately -- never enters the main loop, never a zero-iteration no-op), ERROR names the
  # actual working command, and the guard is left fully in place (not archived, not reset).
  # =====================================================================
  fx="$WORKDIR/case1-${hard_mode_val}"; mkdir -p "$fx"
  make_guard "$fx/.orchestrator-loop-guard" "$LIVE_MAX_CYCLES"
  out="$fx.out"; err="$fx.err"
  exit_code=$(run_region "$region" "$fx" "$LIVE_MAX_CYCLES" "false" "sess_current" "$hard_mode_val" "$out" "$err")
  if [[ "$exit_code" -eq 1 ]]; then
    pass "case1-flag-absent (${engine_label}): subshell exits 1 (refuses immediately)"
  else
    fail "case1-flag-absent (${engine_label}): expected exit 1, got ${exit_code} -- stderr: $(cat "$err")"
  fi
  if grep -qE -- '--continue-budget' "$err"; then
    pass "case1-flag-absent (${engine_label}): stderr names the --continue-budget resume command"
  else
    fail "case1-flag-absent (${engine_label}): stderr does not name --continue-budget: $(cat "$err")"
  fi
  if [[ -f "$fx/.orchestrator-loop-guard" ]]; then
    orig_cc=$(jq -r '.cycle_count' "$fx/.orchestrator-loop-guard")
    if [[ "$orig_cc" -eq "$LIVE_MAX_CYCLES" ]]; then
      pass "case1-flag-absent (${engine_label}): guard left in place, cycle_count unchanged"
    else
      fail "case1-flag-absent (${engine_label}): guard cycle_count unexpectedly changed to ${orig_cc}"
    fi
  else
    fail "case1-flag-absent (${engine_label}): guard file unexpectedly removed"
  fi

  # =====================================================================
  # Case 2: cycle_count == MAX_CYCLES, flag PRESENT. Expected: guard archived (copied) to a
  # dated name, SAME guard path reinitialized at cycle_count=0 with dispatch_seq_counter and
  # detected_defects preserved, loud log emitted naming the exhausted count and the flag.
  # =====================================================================
  fx="$WORKDIR/case2-${hard_mode_val}"; mkdir -p "$fx"
  make_guard "$fx/.orchestrator-loop-guard" "$LIVE_MAX_CYCLES" "sess_fixture_guard_writer" 7 '["marker"]'
  out="$fx.out"; err="$fx.err"
  exit_code=$(run_region "$region" "$fx" "$LIVE_MAX_CYCLES" "true" "sess_current" "$hard_mode_val" "$out" "$err")
  if [[ "$exit_code" -eq 0 ]]; then
    pass "case2-flag-present (${engine_label}): subshell exits 0 (continues to resume read)"
  else
    fail "case2-flag-present (${engine_label}): expected exit 0, got ${exit_code} -- stderr: $(cat "$err")"
  fi
  if [[ "$(count_glob "$fx" '.exhausted-loop-guard-*.json')" -eq 1 ]]; then
    pass "case2-flag-present (${engine_label}): exactly one exhausted-guard archive created"
  else
    fail "case2-flag-present (${engine_label}): expected exactly one archive, found $(count_glob "$fx" '.exhausted-loop-guard-*.json')"
  fi
  if [[ -f "$fx/.orchestrator-loop-guard" ]]; then
    new_cc=$(jq -r '.cycle_count' "$fx/.orchestrator-loop-guard")
    new_dsc=$(jq -r '.dispatch_seq_counter' "$fx/.orchestrator-loop-guard")
    new_dd=$(jq -c '.detected_defects' "$fx/.orchestrator-loop-guard")
    if [[ "$new_cc" -eq 0 ]]; then
      pass "case2-flag-present (${engine_label}): reinitialized guard has cycle_count=0"
    else
      fail "case2-flag-present (${engine_label}): expected cycle_count=0, got ${new_cc}"
    fi
    if [[ "$new_dsc" -eq 7 ]]; then
      pass "case2-flag-present (${engine_label}): dispatch_seq_counter preserved (7), never reset"
    else
      fail "case2-flag-present (${engine_label}): dispatch_seq_counter expected 7, got ${new_dsc}"
    fi
    if [[ "$new_dd" == '["marker"]' ]]; then
      pass "case2-flag-present (${engine_label}): detected_defects preserved"
    else
      fail "case2-flag-present (${engine_label}): detected_defects expected [\"marker\"], got ${new_dd}"
    fi
  else
    fail "case2-flag-present (${engine_label}): reinitialized guard file missing"
  fi
  if grep -qE 'BUDGET EXHAUSTED' "$err" && grep -qE 'continue-budget' "$err"; then
    pass "case2-flag-present (${engine_label}): stderr names BUDGET EXHAUSTED and the authorizing flag"
  else
    fail "case2-flag-present (${engine_label}): stderr missing expected content: $(cat "$err")"
  fi
  # Burnout-echo assertion: the region's self-closed `if [ "${hard_mode:-false}" = "true" ]` block
  # (immediately above the unconditional "Resuming — cycle" echo) is exercised here since Case 2's
  # reinit falls through into the resume-read block that contains both echoes. hard_mode=false
  # must produce NO burnout line; hard_mode=true must produce exactly one.
  if [[ "$hard_mode_val" == "true" ]]; then
    if grep -qE 'Resuming \(hard mode\) — burnout signals so far' "$out"; then
      pass "case2-flag-present (${engine_label}): hard-mode burnout echo present"
    else
      fail "case2-flag-present (${engine_label}): expected hard-mode burnout echo missing: $(cat "$out")"
    fi
  else
    if grep -qE 'Resuming \(hard mode\) — burnout signals so far' "$out"; then
      fail "case2-flag-present (${engine_label}): unexpected hard-mode burnout echo present under hard_mode=false"
    else
      pass "case2-flag-present (${engine_label}): no hard-mode burnout echo under hard_mode=false"
    fi
  fi

  # =====================================================================
  # Case 3: cycle_count BELOW MAX_CYCLES, flag PRESENT. Expected: the flag is INERT when the
  # budget is not exhausted -- no archive, no reinit, ordinary resume proceeds untouched.
  # =====================================================================
  fx="$WORKDIR/case3-${hard_mode_val}"; mkdir -p "$fx"
  make_guard "$fx/.orchestrator-loop-guard" 2 "sess_fixture_guard_writer" 5
  out="$fx.out"; err="$fx.err"
  exit_code=$(run_region "$region" "$fx" "$LIVE_MAX_CYCLES" "true" "sess_current" "$hard_mode_val" "$out" "$err")
  if [[ "$exit_code" -eq 0 ]]; then
    pass "case3-below-budget-flag-present (${engine_label}): subshell exits 0"
  else
    fail "case3-below-budget-flag-present (${engine_label}): expected exit 0, got ${exit_code}"
  fi
  if [[ "$(count_glob "$fx" '.exhausted-loop-guard-*.json')" -eq 0 ]]; then
    pass "case3-below-budget-flag-present (${engine_label}): no archive created (flag inert below budget)"
  else
    fail "case3-below-budget-flag-present (${engine_label}): unexpected archive created despite non-exhausted budget"
  fi
  if [[ -f "$fx/.orchestrator-loop-guard" ]]; then
    unchanged_cc=$(jq -r '.cycle_count' "$fx/.orchestrator-loop-guard")
    if [[ "$unchanged_cc" -eq 2 ]]; then
      pass "case3-below-budget-flag-present (${engine_label}): cycle_count untouched (2)"
    else
      fail "case3-below-budget-flag-present (${engine_label}): cycle_count unexpectedly changed to ${unchanged_cc}"
    fi
  else
    fail "case3-below-budget-flag-present (${engine_label}): guard file unexpectedly removed"
  fi

  # =====================================================================
  # Case 4: differing guard_session_id, budget NOT exhausted. Expected: still just an INFO log
  # (from the pre-existing, untouched session_id-mismatch block), never a reset -- asserting the
  # test-session-runtime-files.sh Case 3 invariant from a second angle, inside this suite too.
  # =====================================================================
  fx="$WORKDIR/case4-${hard_mode_val}"; mkdir -p "$fx"
  make_guard "$fx/.orchestrator-loop-guard" 2 "sess_a_different_writer" 5
  out="$fx.out"; err="$fx.err"
  exit_code=$(run_region "$region" "$fx" "$LIVE_MAX_CYCLES" "false" "sess_current_caller" "$hard_mode_val" "$out" "$err")
  if [[ "$exit_code" -eq 0 ]]; then
    pass "case4-session-id-mismatch (${engine_label}): subshell exits 0"
  else
    fail "case4-session-id-mismatch (${engine_label}): expected exit 0, got ${exit_code}"
  fi
  # CORRECTNESS FIX (this task's plan Phase 5 centre of gravity): the session_id-mismatch INFO
  # log used to be gated on `engine_label == "base"`, because the pre-merge hard engine's own
  # resume-read block genuinely had no guard_session_id check at all. In the merged file that
  # check (lines ~358-361 of skill-orchestrate/SKILL.md) is UNCONDITIONAL, shared code -- it runs
  # identically regardless of `hard_mode`. The old base-only gate is now simply wrong: asserted
  # here for BOTH `hard_mode` values, not skipped for hard_mode=true. It is plain `echo` (no
  # `>&2`), so it lands on stdout, not stderr.
  if grep -qE 'INFO: loop guard was last written by a different session_id' "$out"; then
    pass "case4-session-id-mismatch (${engine_label}): INFO log present, never a gate"
  else
    fail "case4-session-id-mismatch (${engine_label}): expected INFO log missing: $(cat "$out")"
  fi
  if [[ -f "$fx/.orchestrator-loop-guard" ]]; then
    mismatch_cc=$(jq -r '.cycle_count' "$fx/.orchestrator-loop-guard")
    if [[ "$mismatch_cc" -eq 2 ]]; then
      pass "case4-session-id-mismatch (${engine_label}): guard untouched despite session_id mismatch"
    else
      fail "case4-session-id-mismatch (${engine_label}): guard unexpectedly reset to ${mismatch_cc}"
    fi
  else
    fail "case4-session-id-mismatch (${engine_label}): guard file unexpectedly removed"
  fi
done

# =====================================================================
# Stage 7 message assertion: the merged engine's MAX_CYCLES branch names --continue-budget. This
# message is shared, unconditional code (not per-`hard_mode`), so a single check against the one
# merged file replaces what used to be two per-engine checks.
# =====================================================================
if grep -A3 'MAX_CYCLES ($MAX_CYCLES) reached for task' "$SKILL_FILE" | grep -q -- '--continue-budget'; then
  pass "skill-orchestrate/SKILL.md Stage 7 MAX_CYCLES message names --continue-budget"
else
  fail "skill-orchestrate/SKILL.md Stage 7 MAX_CYCLES message does not name --continue-budget"
fi

# =====================================================================
# test-session-runtime-files.sh Case 3 byte-stability: git diff HEAD must be empty for the base
# engine file, or a recorded justification must exist. This suite runs the check itself rather
# than trusting a hand-authored claim.
# =====================================================================
SESSION_TEST_CANDIDATES=(
  "$SCRIPT_DIR/../test-session-runtime-files.sh"
  "$REPO_ROOT/.claude/scripts/test-session-runtime-files.sh"
)
SESSION_TEST=""
for candidate in "${SESSION_TEST_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    SESSION_TEST="$candidate"
    break
  fi
done
if [[ -n "$SESSION_TEST" ]]; then
  if bash "$SESSION_TEST" >"$WORKDIR/session-runtime.out" 2>&1; then
    pass "test-session-runtime-files.sh passes (Case 3 included)"
  else
    fail "test-session-runtime-files.sh FAILED -- see $WORKDIR/session-runtime.out"
    cat "$WORKDIR/session-runtime.out"
  fi
else
  info "test-session-runtime-files.sh not found at any candidate path -- skipping (not this suite's environment error)"
fi

# =====================================================================
# TARGET 2: orchestrate-cycle-plan.sh's OWN budget guard / --continue-budget path, direct (not
# SKILL.md-extracted). Decision 1 of the task that ported single-task's loop-guard budget into
# the batch engine moved this exact mechanism (archive-aside, reset cycle_count to 0 in place,
# preserve dispatch_seq_counter/detected_defects) into that script's own top-of-cycle eligibility
# loop. This section re-proves the SAME two headline properties Cases 1/2 above prove for the
# SKILL.md-extracted region -- refusal without the flag, archive+reset+preserve+dispatch with it
# -- against the batch engine directly, one case each, rather than duplicating
# test-orchestrate-cycle-plan.sh's own much larger Group 8 (which already covers this in full,
# including cross-session cumulative resume and mode-aware max_cycles; this section is a second,
# narrower angle on the same underlying mechanism, not a replacement for that suite).
# =====================================================================
info "TARGET 2: orchestrate-cycle-plan.sh direct (not SKILL.md-extracted)"

CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CP_SUT_SRC="$CORE_DIR/orchestrate-cycle-plan.sh"

if [[ ! -f "$CP_SUT_SRC" ]]; then
  fail "TARGET 2: orchestrate-cycle-plan.sh not found at $CP_SUT_SRC -- skipping this target's cases"
else
  CP_WORKDIR="$WORKDIR/cycle-plan-target"
  mkdir -p "$CP_WORKDIR/.claude/scripts/lib" "$CP_WORKDIR/specs"
  cp_ok=true
  for f in orchestrate-cycle-plan.sh orchestrate-batch-admit.sh orchestrate-triage-classify.sh \
           task-lock.sh orchestrate-loop-guard-init.sh \
           deploy-root-guard.sh command-route-agent.sh skill-base.sh; do
    if [[ -f "$CORE_DIR/$f" ]]; then
      cp "$CORE_DIR/$f" "$CP_WORKDIR/.claude/scripts/$f"
    else
      fail "TARGET 2: missing collaborator $f -- environment error for this target"
      cp_ok=false
    fi
  done
  for f in common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh \
           phase-heading-patterns.sh deploy-baseline-lib.sh; do
    if [[ -f "$CORE_DIR/lib/$f" ]]; then
      cp "$CORE_DIR/lib/$f" "$CP_WORKDIR/.claude/scripts/lib/$f"
    else
      fail "TARGET 2: missing collaborator lib/$f -- environment error for this target"
      cp_ok=false
    fi
  done
  mkdir -p "$CP_WORKDIR/.claude/context/reference"
  if [[ -f "$CORE_DIR/../context/reference/orchestrator-critical-paths.json" ]]; then
    cp "$CORE_DIR/../context/reference/orchestrator-critical-paths.json" \
       "$CP_WORKDIR/.claude/context/reference/orchestrator-critical-paths.json"
  else
    cp_ok=false
  fi
  chmod +x "$CP_WORKDIR"/.claude/scripts/*.sh 2>/dev/null || true

  if [[ "$cp_ok" == "true" ]]; then
    CP_SUT="$CP_WORKDIR/.claude/scripts/orchestrate-cycle-plan.sh"
    CP_STATE_FILE="$CP_WORKDIR/specs/state.json"
    cat > "$CP_STATE_FILE" <<'EOF'
{
  "active_projects": [
    {"project_number": 950, "project_name": "loop_guard_target2", "task_type": "general", "status": "implementing", "description": "budget-override direct-target candidate", "dependencies": [], "file_scope": []}
  ]
}
EOF
    mkdir -p "$CP_WORKDIR/specs/950_loop_guard_target2"
    jq -n --argjson dsc 7 --argjson dd '["marker"]' \
      '{cycle_count: 13, dispatch_seq_counter: $dsc, detected_defects: $dd}' \
      > "$CP_WORKDIR/specs/950_loop_guard_target2/.orchestrator-loop-guard"

    # Stubs for the LIVE-only dispatch path Case T2-2 reaches (Case T2-1 refuses before either is
    # called) -- neither script's own real behavior is under test here, only that a re-authorized
    # candidate reaches an actual dispatch this cycle. Mirrors test-orchestrate-cycle-plan.sh's own
    # Group 4/5 stub convention.
    cat > "$CP_WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh" <<'EOF'
#!/usr/bin/env bash
proj_num="$1"; phase="$2"
jq -n -c --arg f "/fake/${proj_num}-${phase}.md" '{dispatch_file: $f, model: ""}'
EOF
    chmod +x "$CP_WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh"
    cat > "$CP_WORKDIR/.claude/scripts/update-task-status.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$CP_WORKDIR/.claude/scripts/update-task-status.sh"

    # Case T2-1: exhausted (cycle_count=13=hard-mode MAX_CYCLES), flag ABSENT -- blocked with the
    # MAX_CYCLES reason, guard file left fully in place.
    cp_out=$(bash "$CP_SUT" --session t2_sess_a --state-file "$CP_STATE_FILE" --hard 950 2>"$WORKDIR/t2-case1.err")
    if echo "$cp_out" | jq -e '.blocked | map(select(.task == 950)) | length == 1' >/dev/null 2>&1 && \
       [[ "$(echo "$cp_out" | jq -r '.blocked[0].reason')" == *MAX_CYCLES* ]]; then
      pass "TARGET 2 case T2-1: exhausted budget blocks (flag absent), reason names MAX_CYCLES"
    else
      fail "TARGET 2 case T2-1: expected a blocked row naming MAX_CYCLES (stdout: $cp_out)"
    fi
    if [[ "$(jq -r '.cycle_count' "$CP_WORKDIR/specs/950_loop_guard_target2/.orchestrator-loop-guard")" == "13" ]]; then
      pass "TARGET 2 case T2-1: durable guard file left unchanged (cycle_count still 13)"
    else
      fail "TARGET 2 case T2-1: durable guard file was unexpectedly modified"
    fi

    # Case T2-2: same exhausted guard, flag PRESENT -- archived aside, reset to cycle_count=0 in
    # place (then charged to 1 by this same cycle's own live dispatch), dispatch_seq_counter and
    # detected_defects preserved, and a dispatch actually occurs this cycle.
    cp_out2=$(bash "$CP_SUT" --session t2_sess_b --state-file "$CP_STATE_FILE" --hard --continue-budget 950 2>"$WORKDIR/t2-case2.err")
    if echo "$cp_out2" | jq -e '.dispatch | map(select(.task == 950)) | length == 1' >/dev/null 2>&1; then
      pass "TARGET 2 case T2-2: --continue-budget authorizes a dispatch this cycle"
    else
      fail "TARGET 2 case T2-2: expected a dispatch row for the re-authorized candidate (stdout: $cp_out2)"
    fi
    post_guard="$CP_WORKDIR/specs/950_loop_guard_target2/.orchestrator-loop-guard"
    if [[ -f "$post_guard" ]] && [[ "$(jq -r '.dispatch_seq_counter' "$post_guard")" == "7" ]] && \
       [[ "$(jq -r '.detected_defects | length' "$post_guard")" == "1" ]]; then
      pass "TARGET 2 case T2-2: --continue-budget's reset preserves dispatch_seq_counter and detected_defects"
    else
      fail "TARGET 2 case T2-2: dispatch_seq_counter/detected_defects not preserved (got: $(cat "$post_guard" 2>/dev/null))"
    fi
    archived_count=$(find "$CP_WORKDIR/specs/950_loop_guard_target2" -maxdepth 1 -name '.exhausted-loop-guard-*.json' 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$archived_count" -ge 1 ]]; then
      pass "TARGET 2 case T2-2: the exhausted guard is archived aside for auditability"
    else
      fail "TARGET 2 case T2-2: no archived exhausted-guard file found"
    fi
  fi
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
