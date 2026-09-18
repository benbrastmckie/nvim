#!/usr/bin/env bash
# test-orchestrate-context-growth.sh - Executable form of the orchestrator's per-cycle lead
# context growth probe. Converts the "~1 KB per task per cycle" Context Flatness target into a
# measured, re-runnable number by driving a disposable 3-task cycle through the REAL cycle
# scripts (orchestrate-cycle-plan.sh live-mode, which internally calls the real
# orchestrate-build-dispatch.sh, then orchestrate-cycle-postflight.sh per task against fixture
# handoffs) and summing exactly the bytes the LEAD itself accumulates in context.
#
# WHAT COUNTS AS "LEAD-VISIBLE" (and why the dispatch file itself is excluded): the dispatch file
# written by orchestrate-build-dispatch.sh (specs/{task}/.dispatch/{seq}.md) is read by the
# DISPATCHED agent in its own fresh context, never by the lead -- the lead's Move 2 prompt is a
# fixed one-line pointer ("Read {dispatch_file} first and execute it exactly...") plus a small
# JSON Context object, matching skill-orchestrate/SKILL.md's own "## Move 2: Dispatch" comment
# template verbatim (empirically confirmed against this task's own live dispatch message, which
# matched that template byte-for-byte in structure). So per task per cycle, the lead's own
# context grows by:
#   (1) an amortized share of the cycle's plan_json (one call, one JSON blob, shared across all
#       tasks in the batch -- amortized_bytes = plan_json_bytes / task_count)
#   (2) the Move 2 pointer prompt + Context object text for that task (NOT the dispatch file)
#   (3) the Move 3 postflight compact JSON for that task (orchestrate-cycle-postflight.sh's
#       stdout: {task, phase, status, phases_completed, phases_total, verdict, halt,
#       infra_exempt_cycle, aux_signal, note})
#
# Structural model: test-orchestrate-cycle-plan.sh's sandbox shape (copy real collaborator
# scripts into a synthetic $WORKDIR/.claude/scripts/ tree so deploy-root-guard.sh's `*/.claude`
# parent-directory check passes and every sibling script's own SCRIPT_DIR-anchored PROJECT_ROOT
# resolves inside the fixture, never the real repo), EXTENDED with orchestrate-build-dispatch.sh
# itself (real, unstubbed -- this suite exists specifically to measure ITS real output) plus its
# three SKILL_REPO_ROOT-qualified collaborators stubbed the same deterministic way
# test-orchestrate-build-dispatch.sh does (memory-retrieve.sh, literature-lit-flag-resolve.sh,
# literature-briefing-invoke.sh), and orchestrate-cycle-postflight.sh's own collaborator set
# (test-orchestrate-cycle-postflight.sh's sandbox), all merged into ONE fixture tree so the
# 3-task cycle runs start-to-finish without leaving the fixture.
#
# ISOLATION: every mutation happens under a mktemp -d WORKDIR; nothing under the real specs/ tree
# is read or written; no real task-lock is acquired; no real dispatch_seq counter advances.
#
# Exit codes: 0 -- probe ran and printed PER_TASK_PER_CYCLE_BYTES within the regression ceiling;
# 1 -- probe ran but exceeded the regression ceiling, or a fixture assertion failed; 2 --
# environment error (a required collaborator script was not found, or jq unavailable).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

require_file() {
  if [ ! -f "$1" ]; then
    echo "ERROR: expected $1" >&2
    exit 2
  fi
}

# Union of orchestrate-cycle-plan.sh's, orchestrate-cycle-postflight.sh's, and
# orchestrate-build-dispatch.sh's own collaborator requirements (see test-orchestrate-cycle-plan.sh
# and test-orchestrate-cycle-postflight.sh, whose require lists this merges).
SCRIPTS=(
  orchestrate-cycle-plan.sh orchestrate-cycle-postflight.sh orchestrate-build-dispatch.sh
  orchestrate-batch-admit.sh orchestrate-triage-classify.sh task-lock.sh
  orchestrate-loop-guard-init.sh orchestrate-build-aux-dispatch.sh
  orchestrate-recover-outcome.sh orchestrate-churn.sh
  deploy-root-guard.sh command-route-agent.sh skill-base.sh system-defect-record.sh
  state-write.sh generate-todo.sh update-task-status.sh git-commit-scoped.sh
  errors-append.sh events-append.sh
)
LIBS=(
  common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh
  phase-heading-patterns.sh deploy-baseline-lib.sh status-vocabulary.sh task-lookup-lib.sh
  deploy-ledger-lib.sh
)

for f in "${SCRIPTS[@]}"; do require_file "$CORE_DIR/$f"; done
for f in "${LIBS[@]}"; do require_file "$CORE_DIR/lib/$f"; done
require_file "$CORE_DIR/../context/reference/orchestrator-critical-paths.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

mkdir -p "$WORKDIR/.claude/scripts/lib" "$WORKDIR/.claude/context/reference" "$WORKDIR/specs"
for f in "${SCRIPTS[@]}"; do cp "$CORE_DIR/$f" "$WORKDIR/.claude/scripts/$f"; done
for f in "${LIBS[@]}"; do cp "$CORE_DIR/lib/$f" "$WORKDIR/.claude/scripts/lib/$f"; done
cp "$CORE_DIR/../context/reference/orchestrator-critical-paths.json" \
   "$WORKDIR/.claude/context/reference/orchestrator-critical-paths.json"
chmod +x "$WORKDIR"/.claude/scripts/*.sh

# Deterministic stubs for orchestrate-build-dispatch.sh's three SKILL_REPO_ROOT-qualified
# collaborators (same contract as test-orchestrate-build-dispatch.sh's stubs) -- this suite is
# under no obligation to depend on the real memory vault or a real Literature corpus.
cat > "$WORKDIR/.claude/scripts/memory-retrieve.sh" <<'EOF'
#!/usr/bin/env bash
echo "<memory-context>"
echo "STUB_MEMORY_CONTENT"
echo "</memory-context>"
EOF
cat > "$WORKDIR/.claude/scripts/literature-lit-flag-resolve.sh" <<'EOF'
#!/usr/bin/env bash
while [ "$#" -gt 0 ]; do
  case "$1" in
    --lit-flag|--orchestrator-mode|--query) shift 2 ;;
    *) shift ;;
  esac
done
echo "Rationale: stub rationale" >&2
echo "GLOBAL_MISSING"
EOF
cat > "$WORKDIR/.claude/scripts/literature-briefing-invoke.sh" <<'EOF'
#!/usr/bin/env bash
echo "<literature-briefing>"
echo "STUB_LIT_CONTENT"
echo "</literature-briefing>"
EOF
chmod +x "$WORKDIR"/.claude/scripts/memory-retrieve.sh \
         "$WORKDIR"/.claude/scripts/literature-lit-flag-resolve.sh \
         "$WORKDIR"/.claude/scripts/literature-briefing-invoke.sh

( cd "$WORKDIR" && git init -q && git config user.email t@t.com && git config user.name T )

CYCLE_PLAN="$WORKDIR/.claude/scripts/orchestrate-cycle-plan.sh"
CYCLE_POSTFLIGHT="$WORKDIR/.claude/scripts/orchestrate-cycle-postflight.sh"
STATE_FILE="$WORKDIR/specs/state.json"
SESSION_ID="sess_growth_probe_0001"

# ─── 3-task fixture: uniform "not_started" status -> all 3 dispatch to research this cycle,
# keeping the postflight fixture shape identical across all three (simpler, still representative
# -- Phase 4's job is to measure per-task marginal bytes, which this deliberate uniformity does
# not distort: the Move 2/Move 3 template shape is the same across research/plan/implement,
# differing only in field VALUES of comparable length). ───────────────────────────────────────
for n in 801 802 803; do
  mkdir -p "$WORKDIR/specs/${n}_growth_probe_${n}"
done
cat > "$STATE_FILE" <<'EOF'
{
  "next_project_number": 900,
  "active_projects": [
    {"project_number": 801, "project_name": "growth_probe_801", "task_type": "general", "status": "not_started", "description": "Growth probe fixture candidate one -- synthetic, not a real task.", "dependencies": [], "file_scope": []},
    {"project_number": 802, "project_name": "growth_probe_802", "task_type": "general", "status": "not_started", "description": "Growth probe fixture candidate two -- synthetic, not a real task.", "dependencies": [], "file_scope": []},
    {"project_number": 803, "project_name": "growth_probe_803", "task_type": "general", "status": "not_started", "description": "Growth probe fixture candidate three -- synthetic, not a real task.", "dependencies": [], "file_scope": []}
  ]
}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
( cd "$WORKDIR" && git add specs/ .claude/ >/dev/null 2>&1 && git commit -q -m fixture >/dev/null 2>&1 )

# ─── (1) Live cycle-plan: mints dispatch_seq, calls the REAL orchestrate-build-dispatch.sh per
# candidate, returns plan_json with real dispatch_file paths. ──────────────────────────────────
#
# NOTE (real finding, not a test workaround): orchestrate-cycle-plan.sh's live preflight write
# path calls skill_preflight_update -> update-task-status.sh, whose `echo "OK: task $n status ->
# $STATE_STATUS"` (update-task-status.sh line ~799) is UNREDIRECTED plain stdout -- it is never
# captured or suppressed by skill_preflight_update, so it lands on cycle-plan.sh's own stdout
# ahead of the final JSON line. skill-orchestrate/SKILL.md's own `plan_json=$(bash
# .claude/scripts/orchestrate-cycle-plan.sh ...)` capture (Move 1) does not filter this either --
# the LEAD (an LLM reading Bash tool output, not a literal `jq` parse) tolerates the noise by
# reading past it, which is why this does not surface as a functional bug in production, but it
# IS real bytes the lead's context absorbs on a status transition. plan_json below is therefore
# the RAW captured stdout (matching what the lead actually sees, contamination included); a
# separate plan_json_clean (last JSON-shaped line only) is used for this suite's own jq parsing.
# Not in scope for 142 to fix (MUST-NOT-DAMAGE names the redeploy checkpoint/admission gates, not
# this call site) -- recorded as a Stage C follow-up observation in the implementation summary.
plan_stdout_file="$(mktemp)"; plan_stderr_file="$(mktemp)"
( cd "$WORKDIR" && bash "$CYCLE_PLAN" --session "$SESSION_ID" --state-file specs/state.json \
    801 802 803 >"$plan_stdout_file" 2>"$plan_stderr_file" )
plan_rc=$?
plan_json="$(cat "$plan_stdout_file")"
plan_json_clean="$(grep '^{' "$plan_stdout_file" | tail -n1)"
plan_stderr="$(cat "$plan_stderr_file")"
rm -f "$plan_stdout_file" "$plan_stderr_file"

if [ "$plan_rc" -eq 0 ] && echo "$plan_json_clean" | jq -e '.dispatch | length == 3' >/dev/null 2>&1; then
  pass "live cycle-plan: exit 0, all 3 fixture candidates dispatched"
else
  fail "live cycle-plan: exit=$plan_rc, dispatch count != 3 (stdout: $plan_json) (stderr: $plan_stderr)"
  echo ""
  echo "$FAILED failed -- cannot proceed to per-task measurement without a live plan_json"
  exit 1
fi

plan_json_bytes=$(printf '%s' "$plan_json" | wc -c | tr -d ' ')
info "plan_json bytes (one call, 3-task cycle): $plan_json_bytes"

mt_state_file="$WORKDIR/specs/.orchestrator-multi-state-${SESSION_ID}.json"
if [ ! -f "$mt_state_file" ]; then
  fail "mt_state_file not written by live cycle-plan: $mt_state_file"
  exit 1
fi

# ─── (2) Per-task Move 2 pointer prompt + Context object, reproducing skill-orchestrate/SKILL.md's
# "## Move 2: Dispatch" comment template verbatim (task_number, phase, dispatch_file path,
# orchestrator_mode, session_id, task_dir, handoff_path, dispatch_seq) -- confirmed against this
# task's own live dispatch message, which matched this template's structure exactly. Excludes the
# dispatch FILE's own bytes: only its PATH (as it appears in the prompt text) counts, since the
# file itself is read by the dispatched agent in a separate fresh context, never by the lead. ──
total_pointer_context_bytes=0
total_postflight_bytes=0
task_count=0

for t in 801 802 803; do
  row=$(echo "$plan_json_clean" | jq -c --argjson t "$t" '.dispatch[] | select(.task == $t)')
  if [ -z "$row" ]; then
    fail "no dispatch row for candidate #$t in plan_json"
    continue
  fi
  phase=$(jq -r .phase <<<"$row")
  dispatch_file=$(jq -r .dispatch_file <<<"$row")
  agent=$(jq -r .agent <<<"$row")
  if [ ! -f "$dispatch_file" ]; then
    fail "candidate #$t: dispatch_file not found on disk: $dispatch_file"
    continue
  fi
  task_dir_rel=$(jq -r --arg t "$t" '.task_dirs[$t]' "$mt_state_file")
  task_dir_abs="$WORKDIR/$task_dir_rel"
  dispatch_seq=$(jq -r --arg t "$t" '.dispatch_seq[$t]' "$mt_state_file")
  handoff_path="${task_dir_abs}/.orchestrator-handoff.json"
  ctx_sid="$SESSION_ID"
  [ "$phase" != "implement" ] && ctx_sid="${SESSION_ID}_${t}"

  # Pointer prompt text, verbatim template from SKILL.md's Move 2 comment.
  pointer_prompt="You are dispatched by /orchestrate for task $t, phase $phase. Read $dispatch_file first and execute it exactly; it names every input, output path and contract."
  # Context object, verbatim field set from the same comment.
  context_obj=$(jq -n -c --argjson t "$t" --arg sid "$ctx_sid" --arg td "$task_dir_abs" \
    --arg hp "$handoff_path" --argjson ds "$dispatch_seq" \
    '{task_number: $t, orchestrator_mode: true, session_id: $sid, task_dir: $td, handoff_path: $hp, dispatch_seq: $ds}')

  pointer_bytes=$(printf '%s' "$pointer_prompt" | wc -c | tr -d ' ')
  context_bytes=$(printf '%s' "$context_obj" | wc -c | tr -d ' ')
  combined=$(( pointer_bytes + context_bytes ))
  total_pointer_context_bytes=$(( total_pointer_context_bytes + combined ))
  info "candidate #$t ($phase, agent=$agent): pointer=$pointer_bytes B, context=$context_bytes B, combined=$combined B"

  # ─── (3) Fixture a completed dispatch (fresh handoff + return-meta) and run the REAL
  # orchestrate-cycle-postflight.sh (multi-task mode: no --loop-guard-file), capturing its
  # compact JSON stdout bytes. ──────────────────────────────────────────────────────────────
  mkdir -p "${task_dir_abs}/summaries"
  echo "# fixture summary" > "${task_dir_abs}/summaries/01_fixture-summary.md"
  now_ts=$(date -u +%s)
  future_window=$(( now_ts + 500 ))
  cat > "$handoff_path" <<EOF
{"status": "researched", "dispatch_seq": $dispatch_seq, "phases_completed": 0, "phases_total": 0}
EOF
  cat > "${task_dir_abs}/.return-meta.json" <<EOF
{"status":"researched","dispatch_seq":$dispatch_seq,"artifacts":[{"type":"report","path":"${task_dir_rel}/summaries/01_fixture-summary.md","summary":"fixture"}],"metadata":{"phases_completed":0,"phases_total":0}}
EOF
  touch -d "@${future_window}" "${task_dir_abs}/.return-meta.json" 2>/dev/null || true

  pf_stdout_file="$(mktemp)"; pf_stderr_file="$(mktemp)"
  ( cd "$WORKDIR" && bash "$CYCLE_POSTFLIGHT" "$t" --session "$SESSION_ID" --state-file specs/state.json \
      --phase "$phase" --task-dir "$task_dir_rel" --task-type general --agent "$agent" \
      --dispatch-seq "$dispatch_seq" --dispatch-start-ts "$future_window" \
      >"$pf_stdout_file" 2>"$pf_stderr_file" )
  pf_rc=$?
  pf_json="$(cat "$pf_stdout_file")"
  pf_stderr="$(cat "$pf_stderr_file")"
  rm -f "$pf_stdout_file" "$pf_stderr_file"

  if [ "$pf_rc" -eq 0 ] && [ -n "$pf_json" ]; then
    pf_bytes=$(printf '%s' "$pf_json" | wc -c | tr -d ' ')
    total_postflight_bytes=$(( total_postflight_bytes + pf_bytes ))
    info "candidate #$t postflight JSON: $pf_bytes B (verdict=$(jq -r '.verdict // "?"' <<<"$pf_json"))"
    pass "candidate #$t: live postflight produced compact JSON"
  else
    fail "candidate #$t: postflight exit=$pf_rc, empty or malformed JSON (stdout: $pf_json) (stderr: $pf_stderr)"
  fi

  task_count=$(( task_count + 1 ))
done

if [ "$task_count" -eq 0 ]; then
  echo ""
  echo "$FAILED failed -- no candidate produced a measurement"
  exit 1
fi

amortized_plan_json=$(( plan_json_bytes / task_count ))
avg_pointer_context=$(( total_pointer_context_bytes / task_count ))
avg_postflight=$(( total_postflight_bytes / task_count ))
per_task_per_cycle=$(( amortized_plan_json + avg_pointer_context + avg_postflight ))

echo ""
echo "=== Per-cycle lead context growth breakdown (3-task fixture cycle) ==="
echo "  plan_json total:              $plan_json_bytes B (one call per cycle)"
echo "  plan_json amortized/task:     $amortized_plan_json B"
echo "  pointer+context avg/task:     $avg_pointer_context B"
echo "  postflight JSON avg/task:     $avg_postflight B"
echo "PER_TASK_PER_CYCLE_BYTES: $per_task_per_cycle"

# Regression ceiling: a generous detector, not a tight target (research Finding 5 derived
# ~850-1,010 B/task analytically; this is a re-runnable MEASUREMENT, and the ceiling exists only
# to catch a future regression that balloons lead growth, never to be retrofit to match whatever
# number comes out).
REGRESSION_CEILING_BYTES=2048
if [ "$per_task_per_cycle" -le "$REGRESSION_CEILING_BYTES" ]; then
  pass "PER_TASK_PER_CYCLE_BYTES ($per_task_per_cycle B) is under the regression ceiling ($REGRESSION_CEILING_BYTES B)"
else
  fail "PER_TASK_PER_CYCLE_BYTES ($per_task_per_cycle B) EXCEEDS the regression ceiling ($REGRESSION_CEILING_BYTES B) -- investigate before adjusting the ceiling"
fi

# ─── No real orchestrator state touched ────────────────────────────────────────────────────────
if git -C "$CORE_DIR/../../../.." status --porcelain -- specs/ 2>/dev/null | grep -qE '\.orchestrator-multi-state-sess_growth_probe|801_growth_probe|802_growth_probe|803_growth_probe'; then
  fail "fixture leaked into the real specs/ tree"
else
  pass "no real specs/ state was created or mutated by this probe"
fi
if compgen -G "$CORE_DIR/../../../../specs/.orchestrator-multi-state-*.json" > /dev/null 2>&1; then
  info "note: pre-existing real multi-state files present (unrelated to this probe; not asserted against)"
fi

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] || exit 1
exit 0
