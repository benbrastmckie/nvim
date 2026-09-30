#!/usr/bin/env bash
# test-session-runtime-files.sh - Isolated-temp-root suite proving the session-scoped
# orchestration runtime-file behavior: path isolation, foreign-session detection, resume
# tolerance, and the reap-session-runtime-files.sh threshold contract.
#
# Never touches the real specs/ tree. Builds a throwaway root with a fixture specs/ tree and
# controlled file mtimes (no sleeping), and copies the real reap-session-runtime-files.sh into
# the fixture's .claude/scripts/ byte-for-byte so production code never learns it is under test
# -- the same isolation technique test-task-lock-reap.sh uses.
#
# Two of the six cases below (foreign-session detection, resume tolerance) assert against
# instruction text in commands/orchestrate.md and skills/skill-orchestrate/SKILL.md rather than
# executable code, because the session_id checks those cases cover live in markdown instruction
# files, not a shell script. This is a known, explicitly recorded limitation (see the plan's
# Per-phase contingency), not an oversight: the foreign-session-detection case combines a
# faithful transcription of the check's logic (exercised here as real bash) with a companion grep
# assertion that the live orchestrate.md still contains the actual comparison; the
# resume-tolerance case is grep-only by nature, since "absence of a hard-fail construct" has no
# equivalent executable behavior to run.
#
# Runnable directly from the source store (this file's own location) or from a deployed
# .claude/scripts/ copy -- either way it locates its sibling reap-session-runtime-files.sh and
# the commands/orchestrate.md and skills/skill-orchestrate/SKILL.md instruction files by relative
# path (scripts/, commands/, skills/ are siblings under both agent-system/extensions/core/ and
# .claude/). The loop-guard staleness check and the hard-mode churn-state check now both live in
# this single merged engine file, since the standalone hard-mode orchestrate engine was deleted.
#
# Exit 0 when all cases PASS, exit 1 when any case FAILS.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASSED=$((PASSED + 1))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAILED=$((FAILED + 1))
}

info() {
  echo -e "${YELLOW}[INFO]${NC} $1"
}

# --- Locate the real reap script, lib/common.sh, and the instruction files this suite
# grep-asserts against ---
if [ ! -f "$SCRIPT_DIR/reap-session-runtime-files.sh" ] || [ ! -f "$SCRIPT_DIR/lib/common.sh" ]; then
  echo "ERROR: expected reap-session-runtime-files.sh and lib/common.sh alongside this script in $SCRIPT_DIR" >&2
  exit 1
fi
ORCHESTRATE_MD="$ROOT_DIR/commands/orchestrate.md"
LOOP_GUARD_SKILL="$ROOT_DIR/skills/skill-orchestrate/SKILL.md"
# Retargeted by the four-move loop rewrite (see docs/architecture/orchestrate-state-machine.md):
# both the mt_state_file initialization prose and the loop-guard/churn-state session_id
# mismatch-tolerance logic this suite grep-asserts against have moved out of
# skill-orchestrate/SKILL.md entirely -- mt_state_file's own per-session naming (Case 2) and the
# per-task guard seeding (Case 3) now live in orchestrate-cycle-plan.sh, and the churn-state
# mismatch log (Case 3) lives in orchestrate-churn.sh.
CYCLE_PLAN_SCRIPT="$SCRIPT_DIR/orchestrate-cycle-plan.sh"
CHURN_SKILL="$SCRIPT_DIR/orchestrate-churn.sh"
for f in "$ORCHESTRATE_MD" "$LOOP_GUARD_SKILL" "$CYCLE_PLAN_SCRIPT" "$CHURN_SKILL"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: expected instruction file not found: $f" >&2
    exit 1
  fi
done

# --- Build the isolated temp root ---
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/session-runtime-files-test.XXXXXX")"

cleanup() {
  [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"
}
trap cleanup EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
mkdir -p "$TMPROOT/specs/000_probe"
cp "$SCRIPT_DIR/reap-session-runtime-files.sh" "$TMPROOT/.claude/scripts/reap-session-runtime-files.sh"
cp "$SCRIPT_DIR/lib/common.sh" "$TMPROOT/.claude/scripts/lib/common.sh"
chmod +x "$TMPROOT/.claude/scripts/reap-session-runtime-files.sh"

REAP="$TMPROOT/.claude/scripts/reap-session-runtime-files.sh"

# --- Timestamp helpers (no sleeping -- controlled epoch arithmetic) ---
now_epoch() { date -u +%s; }
touch_minutes_ago() {
  # touch_minutes_ago <path> <minutes>
  local path="$1" mins="$2" epoch
  epoch=$(( $(now_epoch) - (mins * 60) ))
  touch -d "@$epoch" "$path" 2>/dev/null || touch -t "$(date -u -r "$epoch" +%Y%m%d%H%M.%S 2>/dev/null)" "$path" 2>/dev/null || touch "$path"
}

info "Fixture root built at $TMPROOT"

# =====================================================================
# Case 1: path isolation -- two distinct session_id multi-state files persist independently
# =====================================================================
SID_A="sess_1000000001_aaaaaa"
SID_B="sess_1000000002_bbbbbb"
FILE_A="$TMPROOT/specs/.orchestrator-multi-state-${SID_A}.json"
FILE_B="$TMPROOT/specs/.orchestrator-multi-state-${SID_B}.json"

jq -n --arg sid "$SID_A" '{"session_id": $sid, "cycle_count": 3, "completed_tasks": [101]}' > "$FILE_A"
jq -n --arg sid "$SID_B" '{"session_id": $sid, "cycle_count": 7, "completed_tasks": [202, 203]}' > "$FILE_B"

case1_ok=true
[ -f "$FILE_A" ] || { case1_ok=false; info "FILE_A missing after write"; }
[ -f "$FILE_B" ] || { case1_ok=false; info "FILE_B missing after write"; }
cc_a=$(jq -r '.cycle_count' "$FILE_A" 2>/dev/null)
cc_b=$(jq -r '.cycle_count' "$FILE_B" 2>/dev/null)
[ "$cc_a" = "3" ] || { case1_ok=false; info "FILE_A cycle_count corrupted: got '$cc_a', expected 3"; }
[ "$cc_b" = "7" ] || { case1_ok=false; info "FILE_B cycle_count corrupted: got '$cc_b', expected 7"; }

if [ "$case1_ok" = true ]; then
  pass "1: two distinct session_id multi-state files persist independently with distinct content"
else
  fail "1: path-isolation case failed (see INFO lines above)"
fi

# =====================================================================
# Case 2: foreign-session detection
# =====================================================================
# Historical context: commands/orchestrate.md used to re-read mt_state_file AFTER
# skill-orchestrate returned, and hard-failed on a session_id mismatch against its own
# batch_session_id. That external re-read is gone: batch-output ownership moved to the loop's
# own branch move (Move 4, retargeted from the deleted Stage MT-5 by the four-move loop
# rewrite -- see docs/architecture/orchestrate-state-machine.md), which runs INSIDE the same
# invocation that creates mt_state_file, using the session_id it just registered —
# commands/orchestrate.md no longer reads the file at all post-dispatch. The foreign-session
# scenario this check used to guard against is now structurally impossible rather than defended
# against at read time, PROVIDED mt_state_file's own filename is derived from `session_id`
# (`.orchestrator-multi-state-${session_id}.json`, in orchestrate-cycle-plan.sh) every
# invocation -- two different sessions never share a state file at all, let alone a mismatched
# one. This case verifies both halves: the abstract mismatch-detection algorithm still behaves
# correctly (kept as a regression-documenting transcription of the retired check's semantics),
# and the structural guarantee that makes the external check unnecessary is still true in
# orchestrate-cycle-plan.sh.
FOREIGN_FILE="$TMPROOT/specs/.orchestrator-multi-state-${SID_A}.json"
jq -n --arg sid "$SID_B" '{"session_id": $sid, "cycle_count": 99, "completed_tasks": [999]}' > "$FOREIGN_FILE"

batch_session_id="$SID_A"
mt_state_file="$FOREIGN_FILE"
mt_state_file_valid="false"
if [ -f "$mt_state_file" ]; then
  file_session_id=$(jq -r '.session_id // ""' "$mt_state_file")
  if [ "$file_session_id" = "$batch_session_id" ]; then
    mt_state_file_valid="true"
  fi
fi

case2_ok=true
[ "$mt_state_file_valid" = "false" ] || { case2_ok=false; info "transcribed check incorrectly accepted a foreign session_id (file has '$SID_B', invocation is '$SID_A')"; }

# Companion grep assertions: the structural guarantee lives in orchestrate-cycle-plan.sh now,
# not orchestrate.md and not skill-orchestrate/SKILL.md (which no longer initializes
# mt_state_file inline at all -- that logic is entirely inside the script).
grep -qE '\.orchestrator-multi-state-\$\{?session_id\}?\.json' "$CYCLE_PLAN_SCRIPT" || { case2_ok=false; info "orchestrate-cycle-plan.sh no longer names mt_state_file from session_id"; }
grep -q 'file_session_id' "$ORCHESTRATE_MD" && { case2_ok=false; info "orchestrate.md unexpectedly still reads file_session_id -- has post-dispatch re-read logic been reintroduced?"; }

if [ "$case2_ok" = true ]; then
  pass "2: foreign-session content is rejected by the transcribed check, and mt_state_file's filename is always derived from session_id in orchestrate-cycle-plan.sh (making the scenario structurally unreachable)"
else
  fail "2: foreign-session-detection case failed (see INFO lines above)"
fi

# =====================================================================
# Case 3: (a) per-run cycle budget -- cycle_counts is NOT seeded from the durable guard file's
# cycle_count for budgeting purposes any more (inverted from this case's OLD assertion, which
# protected the OPPOSITE, now-retired "cumulative across invocations, by design" contract -- see
# context/standards/orchestrator-runtime-files.md's "cycle_count semantics" section for the full
# per-run rationale). (b) resume tolerance -- loop-guard dispatch_seq_counter seeding and
# churn-state mismatch handling both remain a log line, never a gate. Guards the top risk: a
# future "make it consistent" edit that hard-fails these files would break legitimate
# conversational-turn resume.
# =====================================================================
extract_block() {
  # extract_block <file> <anchor_regex> <trailing_lines>
  local file="$1" anchor="$2" lines="$3" start
  start=$(grep -n "$anchor" "$file" | head -1 | cut -d: -f1)
  [ -n "$start" ] || return 1
  sed -n "${start},$((start + lines))p" "$file"
}

case3_ok=true

# (a) Per-run cycle budget: the retired seeding pattern (`.cycle_counts[$t] //= $_seeded`, which
# used to assign the durable guard's cycle_count into mt_json.cycle_counts[t] on first sight)
# must NOT be present anywhere in this script any more -- the ONLY seeding of cycle_counts[t] is
# the `//= {}` default on the whole map (giving every task a starting value of zero on first
# sight each invocation). A regression here would silently resurrect the retired
# cross-invocation budget-carryover contract.
if grep -qE 'cycle_counts\[\$t\]\s*//=\s*\$_seeded\b' "$CYCLE_PLAN_SCRIPT"; then
  case3_ok=false
  info "orchestrate-cycle-plan.sh still contains the retired 'cycle_counts[\$t] //= \$_seeded' pattern -- the per-run budget contract may have regressed"
fi
if ! grep -qF '.cycle_counts //= {}' "$CYCLE_PLAN_SCRIPT"; then
  case3_ok=false
  info "orchestrate-cycle-plan.sh no longer defaults .cycle_counts to {} -- the per-run zero-start guarantee may have regressed"
fi

# (b) Loop-guard half (retargeted): the single-task engine's guard_session_id vs. session_id
# compare-then-tolerate check is gone along with the engine that ran it. Its replacement in
# orchestrate-cycle-plan.sh's durable dispatch_seq_counter seeding is stronger, not weaker: the
# durable per-task .orchestrator-loop-guard's dispatch_seq_counter is seeded via
# orchestrate-loop-guard-init.sh --seed with NO session_id comparison at all (see that call
# site's own "READ-ONLY... idempotent... safe" comment) -- there is no session-keyed gate left to
# hard-fail on, so legitimate conversational-turn resume across sessions is unconditionally
# tolerated by construction rather than defended against at compare time.
loop_guard_block=$(extract_block "$CYCLE_PLAN_SCRIPT" 'Per-run cycle-budget contract' 30)
if [ -z "$loop_guard_block" ]; then
  case3_ok=false
  info "could not locate the (a2) per-run cycle-budget block in $CYCLE_PLAN_SCRIPT"
elif echo "$loop_guard_block" | grep -qiE 'hard-fail|abort|\bexit\b|\breturn 1\b'; then
  case3_ok=false
  info "(a2) block contains a hard-fail/abort/exit construct: $loop_guard_block"
elif echo "$loop_guard_block" | grep -qE 'session_id.{0,20}(!=|==)|(!=|==).{0,20}session_id'; then
  case3_ok=false
  info "(a2) block unexpectedly compares session_id -- has a mismatch gate been reintroduced without a resume-tolerance review?"
fi

churn_block=$(extract_block "$CHURN_SKILL" 'churn_session_id.*!=.*session_id' 3)
if [ -z "$churn_block" ]; then
  case3_ok=false
  info "could not locate churn_session_id mismatch comparison in $CHURN_SKILL"
elif echo "$churn_block" | grep -qiE 'hard-fail|abort|\bexit\b|\breturn 1\b'; then
  case3_ok=false
  info "churn-state mismatch block contains a hard-fail/abort/exit construct: $churn_block"
fi
echo "$churn_block" | grep -q 'INFO:' || { case3_ok=false; info "churn-state mismatch block does not log an INFO line"; }

if [ "$case3_ok" = true ]; then
  pass "3: cycle_counts is not seeded from the durable guard's cycle_count (per-run budget contract), loop-guard resume has no session-keyed gate at all (unconditional tolerance by construction), and churn-state session_id mismatch handling remains a log line, never a gate"
else
  fail "3: per-run-budget/resume-tolerance case failed (see INFO lines above)"
fi

# --- Reset fixture specs/ tree for the reap cases (cases 1/2 above wrote/overwrote FILE_A) ---
rm -f "$TMPROOT/specs/.orchestrator-multi-state-"*.json "$TMPROOT/specs/.return-meta-multi-"*.json

# =====================================================================
# Case 4: reap, stale -- dry-run reports without deleting; live run deletes
# =====================================================================
STALE_MULTI="$TMPROOT/specs/.orchestrator-multi-state-${SID_A}.json"
STALE_RETURN="$TMPROOT/specs/.return-meta-multi-${SID_B}.json"
jq -n --arg sid "$SID_A" '{"session_id": $sid, "cycle_count": 5}' > "$STALE_MULTI"
jq -n --arg sid "$SID_B" '{"status": "partial", "session_id": $sid}' > "$STALE_RETURN"
touch_minutes_ago "$STALE_MULTI" 500
touch_minutes_ago "$STALE_RETURN" 500

dry_run_out=$(ORCHESTRATOR_SESSION_REAP_MIN=240 "$REAP" --dry-run 2>&1)
dry_run_exit=$?

case4_ok=true
[ "$dry_run_exit" -eq 0 ] || { case4_ok=false; info "dry-run exit code was $dry_run_exit, expected 0"; }
[ -f "$STALE_MULTI" ] || { case4_ok=false; info "dry-run deleted $STALE_MULTI"; }
[ -f "$STALE_RETURN" ] || { case4_ok=false; info "dry-run deleted $STALE_RETURN"; }
echo "$dry_run_out" | grep -q "would reap" || { case4_ok=false; info "dry-run output missing 'would reap'"; }
echo "$dry_run_out" | grep -qF "$SID_A" || { case4_ok=false; info "dry-run output missing embedded session id $SID_A"; }

live_out=$(ORCHESTRATOR_SESSION_REAP_MIN=240 "$REAP" 2>&1)
live_exit=$?
[ "$live_exit" -eq 0 ] || { case4_ok=false; info "live reap exit code was $live_exit, expected 0"; }
[ -f "$STALE_MULTI" ] && { case4_ok=false; info "stale multi-state file $STALE_MULTI was NOT reaped"; }
[ -f "$STALE_RETURN" ] && { case4_ok=false; info "stale return-meta-multi file $STALE_RETURN was NOT reaped"; }
echo "$live_out" | grep -q "reaped:" || { case4_ok=false; info "live output missing 'reaped:'"; }

if [ "$case4_ok" = true ]; then
  pass "4: stale session-scoped files are reported by --dry-run without deletion, then deleted live"
else
  fail "4: reap-stale case failed (see INFO lines above)"
fi

# =====================================================================
# Case 5: reap, fresh (must never delete) -- direct mitigation for "reap deletes a live batch's
# own state" risk
# =====================================================================
FRESH_MULTI="$TMPROOT/specs/.orchestrator-multi-state-${SID_A}.json"
FRESH_RETURN="$TMPROOT/specs/.return-meta-multi-${SID_B}.json"
jq -n --arg sid "$SID_A" '{"session_id": $sid, "cycle_count": 1}' > "$FRESH_MULTI"
jq -n --arg sid "$SID_B" '{"status": "implemented", "session_id": $sid}' > "$FRESH_RETURN"
touch_minutes_ago "$FRESH_MULTI" 10
touch_minutes_ago "$FRESH_RETURN" 10

fresh_dry_out=$(ORCHESTRATOR_SESSION_REAP_MIN=240 "$REAP" --dry-run 2>&1)
case5_ok=true
[ -f "$FRESH_MULTI" ] || { case5_ok=false; info "fresh multi-state file was removed by --dry-run"; }
[ -f "$FRESH_RETURN" ] || { case5_ok=false; info "fresh return-meta-multi file was removed by --dry-run"; }
echo "$fresh_dry_out" | grep -qF "$SID_A" && { case5_ok=false; info "fresh file appeared in --dry-run 'would reap' output"; }

fresh_live_out=$(ORCHESTRATOR_SESSION_REAP_MIN=240 "$REAP" 2>&1)
[ -f "$FRESH_MULTI" ] || { case5_ok=false; info "fresh multi-state file was removed by a live run"; }
[ -f "$FRESH_RETURN" ] || { case5_ok=false; info "fresh return-meta-multi file was removed by a live run"; }
echo "$fresh_live_out" | grep -qF "$SID_A" && { case5_ok=false; info "fresh file appeared in live 'reaped:' output"; }

if [ "$case5_ok" = true ]; then
  pass "5: fresh (within-threshold) session-scoped files are never deleted by --dry-run or a live run"
else
  fail "5: reap-fresh case failed (see INFO lines above)"
fi

# =====================================================================
# Case 6: reap, per-task files untouched -- per-task runtime files are out of scope for this
# sweep (they are swept, if at all, by other mechanisms entirely)
# =====================================================================
PER_TASK_GUARD="$TMPROOT/specs/000_probe/.orchestrator-loop-guard"
echo '{"session_id": "sess_unrelated", "cycle_count": 1}' > "$PER_TASK_GUARD"
touch_minutes_ago "$PER_TASK_GUARD" 500

ORCHESTRATOR_SESSION_REAP_MIN=240 "$REAP" >/dev/null 2>&1

case6_ok=true
[ -f "$PER_TASK_GUARD" ] || { case6_ok=false; info "per-task .orchestrator-loop-guard was incorrectly reaped by the session-scoped sweep"; }

if [ "$case6_ok" = true ]; then
  pass "6: per-task .orchestrator-loop-guard is untouched by the session-scoped reap sweep"
else
  fail "6: per-task-untouched case failed (see INFO lines above)"
fi

# =====================================================================
# Case 7: reap, superseded shapes stale -- the three previously-unreapable naming generations
# (un-suffixed, dot-separator, .prev-) are now reaped when stale, for both families
# =====================================================================
rm -f "$TMPROOT/specs/.orchestrator-multi-state"*.json "$TMPROOT/specs/.return-meta-multi"*.json

SID_C="sess_1000000003_cccccc"
UNSUFFIXED_MULTI="$TMPROOT/specs/.orchestrator-multi-state.json"
UNSUFFIXED_RETURN="$TMPROOT/specs/.return-meta-multi.json"
DOTSEP_MULTI="$TMPROOT/specs/.orchestrator-multi-state.${SID_C}.json"
DOTSEP_RETURN="$TMPROOT/specs/.return-meta-multi.${SID_C}.json"
PREV_MULTI="$TMPROOT/specs/.orchestrator-multi-state.prev-${SID_C}.json"
PREV_RETURN="$TMPROOT/specs/.return-meta-multi.prev-${SID_C}.json"

jq -n --arg sid "$SID_C" '{"session_id": $sid, "cycle_count": 2}' > "$UNSUFFIXED_MULTI"
jq -n --arg sid "$SID_C" '{"status": "partial", "session_id": $sid}' > "$UNSUFFIXED_RETURN"
jq -n --arg sid "$SID_C" '{"session_id": $sid, "cycle_count": 2}' > "$DOTSEP_MULTI"
jq -n --arg sid "$SID_C" '{"status": "partial", "session_id": $sid}' > "$DOTSEP_RETURN"
jq -n --arg sid "$SID_C" '{"session_id": $sid, "cycle_count": 2}' > "$PREV_MULTI"
jq -n --arg sid "$SID_C" '{"status": "partial", "session_id": $sid}' > "$PREV_RETURN"

for superseded_f in "$UNSUFFIXED_MULTI" "$UNSUFFIXED_RETURN" "$DOTSEP_MULTI" "$DOTSEP_RETURN" "$PREV_MULTI" "$PREV_RETURN"; do
  touch_minutes_ago "$superseded_f" 500
done

case7_ok=true
superseded_dry_out=$(ORCHESTRATOR_SESSION_REAP_MIN=240 "$REAP" --dry-run 2>&1)
for superseded_f in "$UNSUFFIXED_MULTI" "$UNSUFFIXED_RETURN" "$DOTSEP_MULTI" "$DOTSEP_RETURN" "$PREV_MULTI" "$PREV_RETURN"; do
  [ -f "$superseded_f" ] || { case7_ok=false; info "dry-run deleted superseded-shape fixture $superseded_f"; }
done
echo "$superseded_dry_out" | grep -q "would reap" || { case7_ok=false; info "dry-run output missing 'would reap' for superseded shapes"; }

superseded_live_out=$(ORCHESTRATOR_SESSION_REAP_MIN=240 "$REAP" 2>&1)
for superseded_f in "$UNSUFFIXED_MULTI" "$UNSUFFIXED_RETURN" "$DOTSEP_MULTI" "$DOTSEP_RETURN" "$PREV_MULTI" "$PREV_RETURN"; do
  [ -f "$superseded_f" ] && { case7_ok=false; info "superseded-shape fixture $superseded_f was NOT reaped by a live run"; }
done
echo "$superseded_live_out" | grep -q "reaped:" || { case7_ok=false; info "live output missing 'reaped:' for superseded shapes"; }

if [ "$case7_ok" = true ]; then
  pass "7: all three previously-unreapable naming generations (un-suffixed, dot-separator, .prev-) are now reaped when stale, for both families"
else
  fail "7: superseded-shape-stale case failed (see INFO lines above)"
fi

# =====================================================================
# Case 8: reap, superseded shapes fresh -- a fresh file in each superseded shape is never
# deleted, matching the existing fresh-shape guarantee (Case 5)
# =====================================================================
rm -f "$TMPROOT/specs/.orchestrator-multi-state"*.json "$TMPROOT/specs/.return-meta-multi"*.json

SID_D="sess_1000000004_dddddd"
FRESH_UNSUFFIXED_MULTI="$TMPROOT/specs/.orchestrator-multi-state.json"
FRESH_DOTSEP_RETURN="$TMPROOT/specs/.return-meta-multi.${SID_D}.json"
FRESH_PREV_MULTI="$TMPROOT/specs/.orchestrator-multi-state.prev-${SID_D}.json"

jq -n --arg sid "$SID_D" '{"session_id": $sid, "cycle_count": 1}' > "$FRESH_UNSUFFIXED_MULTI"
jq -n --arg sid "$SID_D" '{"status": "implemented", "session_id": $sid}' > "$FRESH_DOTSEP_RETURN"
jq -n --arg sid "$SID_D" '{"session_id": $sid, "cycle_count": 1}' > "$FRESH_PREV_MULTI"
for fresh_f in "$FRESH_UNSUFFIXED_MULTI" "$FRESH_DOTSEP_RETURN" "$FRESH_PREV_MULTI"; do
  touch_minutes_ago "$fresh_f" 10
done

case8_ok=true
fresh_superseded_dry_out=$(ORCHESTRATOR_SESSION_REAP_MIN=240 "$REAP" --dry-run 2>&1)
for fresh_f in "$FRESH_UNSUFFIXED_MULTI" "$FRESH_DOTSEP_RETURN" "$FRESH_PREV_MULTI"; do
  [ -f "$fresh_f" ] || { case8_ok=false; info "dry-run removed fresh superseded-shape fixture $fresh_f"; }
done

fresh_superseded_live_out=$(ORCHESTRATOR_SESSION_REAP_MIN=240 "$REAP" 2>&1)
for fresh_f in "$FRESH_UNSUFFIXED_MULTI" "$FRESH_DOTSEP_RETURN" "$FRESH_PREV_MULTI"; do
  [ -f "$fresh_f" ] || { case8_ok=false; info "live run removed fresh superseded-shape fixture $fresh_f"; }
done
echo "$fresh_superseded_dry_out" | grep -qF "$SID_D" && { case8_ok=false; info "fresh superseded-shape file appeared in --dry-run 'would reap' output"; }
echo "$fresh_superseded_live_out" | grep -qF "$SID_D" && { case8_ok=false; info "fresh superseded-shape file appeared in live 'reaped:' output"; }

if [ "$case8_ok" = true ]; then
  pass "8: fresh (within-threshold) superseded-shape files are never deleted by --dry-run or a live run"
else
  fail "8: superseded-shape-fresh case failed (see INFO lines above)"
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
