#!/usr/bin/env bash
# test-orchestrate-cycle-postflight.sh - Fixture suite for orchestrate-cycle-postflight.sh,
# covering the five acceptance conditions and three invariants named by this task's own dispatch
# ACCEPTANCE line, modelled on the two live incidents (a still-live predecessor's late write, and
# a git-restored predecessor artifact) plus the spurious-defect case D1 exists to close.
#
# Structural model: test-orchestrate-cycle-plan.sh's sandbox shape (copy real collaborator
# scripts into a synthetic $WORKDIR/.claude/scripts/ tree so deploy-root-guard.sh's `*/.claude`
# parent-directory check passes and every sibling script's own SCRIPT_DIR-anchored resolution
# lands inside the fixture, never the real repo). Every real collaborator this script calls is
# copied in unmodified -- skill-base.sh, orchestrate-recover-outcome.sh, system-defect-record.sh,
# state-write.sh, update-task-status.sh, git-commit-scoped.sh, task-lock.sh, generate-todo.sh --
# so this suite exercises the real call graph, not a stubbed approximation of it.
#
# Fixture numbers are synthetic, referred to as "candidate #N" -- never "task N" -- per
# rules/no-task-references-in-deliverables.md.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

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

SUT_SRC="$CORE_DIR/orchestrate-cycle-postflight.sh"
require_file "$SUT_SRC"
for f in orchestrate-cycle-postflight.sh orchestrate-recover-outcome.sh task-lock.sh \
         orchestrate-churn.sh orchestrate-loop-guard-init.sh \
         deploy-root-guard.sh command-route-agent.sh skill-base.sh system-defect-record.sh \
         state-write.sh generate-todo.sh update-task-status.sh git-commit-scoped.sh \
         errors-append.sh events-append.sh; do
  require_file "$CORE_DIR/$f"
done
for f in common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh \
         phase-heading-patterns.sh status-vocabulary.sh task-lookup-lib.sh; do
  require_file "$CORE_DIR/lib/$f"
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

setup_sandbox() {
  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR/.claude/scripts/lib" "$WORKDIR/.claude/context/reference" "$WORKDIR/specs"
  for f in orchestrate-cycle-postflight.sh orchestrate-recover-outcome.sh task-lock.sh \
           orchestrate-churn.sh orchestrate-loop-guard-init.sh \
           deploy-root-guard.sh command-route-agent.sh skill-base.sh system-defect-record.sh \
           state-write.sh generate-todo.sh update-task-status.sh git-commit-scoped.sh \
           errors-append.sh events-append.sh; do
    cp "$CORE_DIR/$f" "$WORKDIR/.claude/scripts/$f"
  done
  for f in common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh \
           phase-heading-patterns.sh status-vocabulary.sh task-lookup-lib.sh; do
    cp "$CORE_DIR/lib/$f" "$WORKDIR/.claude/scripts/lib/$f"
  done
  cp "$CORE_DIR/../context/reference/orchestrator-critical-paths.json" \
     "$WORKDIR/.claude/context/reference/orchestrator-critical-paths.json" 2>/dev/null || true
  chmod +x "$WORKDIR"/.claude/scripts/*.sh
  ( cd "$WORKDIR" && git init -q && git config user.email t@t.com && git config user.name T )
}

SUT="$WORKDIR/.claude/scripts/orchestrate-cycle-postflight.sh"
STATE_FILE="$WORKDIR/specs/state.json"

write_state() {
  # Usage: write_state <<'EOF' ... EOF
  cat > "$STATE_FILE"
}

commit_fixture() {
  ( cd "$WORKDIR" && git add specs/ .claude/ >/dev/null 2>&1 && git commit -q -m "fixture" >/dev/null 2>&1 )
}

now_ts() { date -u +%s; }

run_sut() {
  # Usage: run_sut <task_dir_relpath> [extra args...]
  local task_dir="$1"; shift
  local stdout_file stderr_file
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  ( cd "$WORKDIR" && bash "$SUT" "$@" --state-file specs/state.json --task-dir "$task_dir" \
      >"$stdout_file" 2>"$stderr_file" )
  LAST_EXIT=$?
  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

jqf() { echo "$LAST_STDOUT" | jq -r "$1" 2>/dev/null; }

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Acceptance (1): a handoff whose mtime predates the dispatch window routes to recovery
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Acceptance (1): stale mtime routes to recovery, not the trusted handoff"
setup_sandbox
mkdir -p "$WORKDIR/specs/701_candidate/summaries"
echo x > "$WORKDIR/specs/701_candidate/summaries/01_x-summary.md"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 701, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #701", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/701_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 5, "detected_defects": [], "infra_failures": 0}
EOF
# A stale handoff reporting the WRONG (previous-cycle) outcome: zero phases, "planned".
cat > "$WORKDIR/specs/701_candidate/.orchestrator-handoff.json" <<'EOF'
{"status": "planned", "dispatch_seq": 4, "phases_completed": 0, "phases_total": 0}
EOF
future_window=$(( $(now_ts) + 500 ))
cat > "$WORKDIR/specs/701_candidate/.return-meta.json" <<EOF
{"status":"implemented","dispatch_seq":5,"artifacts":[{"type":"summary","path":"specs/701_candidate/summaries/01_x-summary.md","summary":"y"}],"metadata":{"phases_completed":6,"phases_total":6}}
EOF
touch -d "@${future_window}" "$WORKDIR/specs/701_candidate/.return-meta.json" 2>/dev/null || true
run_sut specs/701_candidate --session sess_701 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/701_candidate/.orchestrator-loop-guard \
  --dispatch-seq 5 --dispatch-start-ts "$future_window" 1

if [ "$(jqf '.status')" = "implemented" ] && [ "$(jqf '.phases_completed')" = "6" ]; then
  pass "acceptance (1): stale-mtime handoff (status=planned, 0/0) is ignored; recovery reports the TRUE outcome (implemented, 6/6)"
else
  fail "acceptance (1): expected status=implemented phases_completed=6 from recovery, got: $LAST_STDOUT ($LAST_STDERR)"
fi
if echo "$LAST_STDERR" | grep -q "STALE HANDOFF"; then
  pass "acceptance (1): stale-handoff detection is logged"
else
  fail "acceptance (1): no STALE HANDOFF notice in stderr"
fi
if jq -e '.detected_defects | map(select(.defect_class == "HANDOFF_STALE_OR_ABSENT")) | length >= 1' \
     "$WORKDIR/specs/701_candidate/.orchestrator-loop-guard" >/dev/null 2>&1; then
  pass "acceptance (1): HANDOFF_STALE_OR_ABSENT recorded in the loop guard"
else
  fail "acceptance (1): no HANDOFF_STALE_OR_ABSENT recorded"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Acceptance (2): dispatch_seq mismatch routes to recovery, INCLUDING when mtime is newer
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Acceptance (2): dispatch_seq mismatch routes to recovery even with a newer (in-window) mtime"
setup_sandbox
mkdir -p "$WORKDIR/specs/702_candidate/summaries"
echo x > "$WORKDIR/specs/702_candidate/summaries/01_x-summary.md"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 702, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #702", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/702_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 7, "detected_defects": [], "infra_failures": 0}
EOF
# A still-live predecessor's late write: mtime is NEWER than the window (it wrote just now), but
# dispatch_seq=4 belongs to an earlier cycle -- the incident shape mtime alone cannot reject.
window_start=$(( $(now_ts) - 5 ))
cat > "$WORKDIR/specs/702_candidate/.orchestrator-handoff.json" <<'EOF'
{"status": "planned", "dispatch_seq": 4}
EOF
cat > "$WORKDIR/specs/702_candidate/.return-meta.json" <<'EOF'
{"status":"implemented","dispatch_seq":7,"artifacts":[{"type":"summary","path":"specs/702_candidate/summaries/01_x-summary.md","summary":"y"}],"metadata":{"phases_completed":2,"phases_total":2}}
EOF
run_sut specs/702_candidate --session sess_702 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/702_candidate/.orchestrator-loop-guard \
  --dispatch-seq 7 --dispatch-start-ts "$window_start" 702

if [ "$(jqf '.status')" = "implemented" ]; then
  pass "acceptance (2): dispatch_seq-mismatched handoff (mtime newer than window) is rejected; recovery reports the true outcome"
else
  fail "acceptance (2): expected status=implemented from recovery, got: $LAST_STDOUT ($LAST_STDERR)"
fi
if echo "$LAST_STDERR" | grep -q "DISPATCH_SEQ MISMATCH"; then
  pass "acceptance (2): dispatch_seq mismatch is logged"
else
  fail "acceptance (2): no DISPATCH_SEQ MISMATCH notice in stderr"
fi
if jq -e '.detected_defects | map(select(.defect_class == "HANDOFF_STALE_OR_ABSENT")) | length >= 1' \
     "$WORKDIR/specs/702_candidate/.orchestrator-loop-guard" >/dev/null 2>&1; then
  pass "acceptance (2): HANDOFF_STALE_OR_ABSENT recorded despite the newer mtime"
else
  fail "acceptance (2): no HANDOFF_STALE_OR_ABSENT recorded"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Acceptance (3): a git-restored predecessor .return-meta.json is rejected by recovery too
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Acceptance (3): git-restored predecessor return-meta (fresh in-window mtime, stale dispatch_seq) rejected"
setup_sandbox
mkdir -p "$WORKDIR/specs/703_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 703, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #703", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/703_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 9, "detected_defects": [], "infra_failures": 0}
EOF
# No handoff at all (absent). The return-meta was "git restored" -- fresh mtime, well inside the
# window, but carries a PREDECESSOR dispatch_seq (4) against this cycle's minted 9.
window_start=$(( $(now_ts) - 100 ))
cat > "$WORKDIR/specs/703_candidate/.return-meta.json" <<'EOF'
{"status":"implemented","dispatch_seq":4,"artifacts":[{"type":"summary","path":"specs/703_candidate/summaries/01_x-summary.md","summary":"y"}],"metadata":{"phases_completed":0,"phases_total":0}}
EOF
run_sut specs/703_candidate --session sess_703 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/703_candidate/.orchestrator-loop-guard \
  --dispatch-seq 9 --dispatch-start-ts "$window_start" 703

if [ "$(jqf '.verdict')" = "failed" ]; then
  pass "acceptance (3): git-restored predecessor return-meta is rejected -- verdict=failed, not a false success"
else
  fail "acceptance (3): expected verdict=failed for a rejected git-restored predecessor, got: $LAST_STDOUT ($LAST_STDERR)"
fi
# Confirm the SPECIFIC gate that fired is D2's dispatch_seq check (not some other rejection
# reason) by calling orchestrate-recover-outcome.sh directly with the same arguments the SUT
# used internally -- this script's own call site discards orchestrate-recover-outcome.sh's
# stderr by design (2>/dev/null, matching the precedent orchestrate-stage5-gates.sh already
# established), so the reason is only observable by asking the sub-script directly.
recover_probe=$(bash "$WORKDIR/.claude/scripts/orchestrate-recover-outcome.sh" \
  "$WORKDIR/specs/703_candidate" "$window_start" 9 2>/dev/null)
if [ "$(echo "$recover_probe" | jq -r '.reason')" = "META_DISPATCH_SEQ_MISMATCH" ]; then
  pass "acceptance (3): the recovery-path dispatch_seq check (D2, orchestrate-recover-outcome.sh) is specifically what rejected it"
else
  fail "acceptance (3): expected reason=META_DISPATCH_SEQ_MISMATCH from orchestrate-recover-outcome.sh, got: $recover_probe"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Acceptance (4), direction A: contractual non-writer with no handoff records NO defect
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Acceptance (4a): a contractual non-writer's absent handoff records no defect (recovered outcome)"
setup_sandbox
mkdir -p "$WORKDIR/specs/704_candidate/summaries"
echo x > "$WORKDIR/specs/704_candidate/summaries/01_x-summary.md"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 704, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #704", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/704_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/704_candidate/.return-meta.json" <<'EOF'
{"status":"implemented","dispatch_seq":1,"artifacts":[{"type":"summary","path":"specs/704_candidate/summaries/01_x-summary.md","summary":"y"}],"metadata":{"phases_completed":1,"phases_total":1}}
EOF
window_start=$(( $(now_ts) - 5 ))
run_sut specs/704_candidate --session sess_704 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/704_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" 704

if [ "$(jqf '.verdict')" = "ok" ]; then
  pass "acceptance (4a): general-implementation-agent's absent handoff still recovers successfully"
else
  fail "acceptance (4a): expected verdict=ok, got: $LAST_STDOUT ($LAST_STDERR)"
fi
defect_count=$(jq '.detected_defects | length' "$WORKDIR/specs/704_candidate/.orchestrator-loop-guard" 2>/dev/null)
if [ "$defect_count" = "0" ]; then
  pass "acceptance (4a): zero defects recorded for a non-writer's absent handoff"
else
  fail "acceptance (4a): expected 0 detected_defects, got $defect_count"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Acceptance (4), direction B: a genuine seq-mismatched late write still records
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Acceptance (4b): a genuine seq-mismatched late write (present handoff) still records, regardless of agent"
setup_sandbox
mkdir -p "$WORKDIR/specs/705_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 705, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #705", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/705_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 3, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/705_candidate/.orchestrator-handoff.json" <<'EOF'
{"status": "planned", "dispatch_seq": 1}
EOF
window_start=$(( $(now_ts) - 5 ))
run_sut specs/705_candidate --session sess_705 --phase plan --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/705_candidate/.orchestrator-loop-guard \
  --dispatch-seq 3 --dispatch-start-ts "$window_start" 705

defect_count=$(jq '.detected_defects | length' "$WORKDIR/specs/705_candidate/.orchestrator-loop-guard" 2>/dev/null)
if [ "$defect_count" -ge 1 ] 2>/dev/null; then
  pass "acceptance (4b): a present-but-seq-mismatched handoff still records a defect, even from a non-contractual-writer agent"
else
  fail "acceptance (4b): expected >=1 detected_defects for a present seq-mismatched handoff, got $defect_count"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Acceptance (5): a user_decision payload is relayed intact with status unchanged
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Acceptance (5): user_decision payload relayed verbatim, status left as the agent reported it"
setup_sandbox
mkdir -p "$WORKDIR/specs/706_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 706, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #706", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/706_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 2, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/706_candidate/.return-meta.json" <<'EOF'
{"status":"partial","dispatch_seq":2,"partial_progress":{"stage":"needs_input","details":"blocked on a choice"},"user_decision":{"question":"Which approach — A or B?","options":["A","B"]}}
EOF
window_start=$(( $(now_ts) - 5 ))
run_sut specs/706_candidate --session sess_706 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/706_candidate/.orchestrator-loop-guard \
  --dispatch-seq 2 --dispatch-start-ts "$window_start" 706

if [ "$(jqf '.verdict')" = "ask_user" ]; then
  pass "acceptance (5): verdict=ask_user when a user_decision payload is present"
else
  fail "acceptance (5): expected verdict=ask_user, got: $LAST_STDOUT"
fi
expected_ud='{"question":"Which approach — A or B?","options":["A","B"]}'
actual_ud=$(jqf '.user_decision')
if [ "$(jq -c -n --argjson a "$expected_ud" '$a')" = "$(jq -c -n --argjson b "$actual_ud" '$b' 2>/dev/null)" ]; then
  pass "acceptance (5): user_decision payload relayed verbatim (question and options intact)"
else
  fail "acceptance (5): user_decision payload not relayed intact: got $actual_ud, expected $expected_ud"
fi
if [ "$(jqf '.status')" = "partial" ]; then
  pass "acceptance (5): status left exactly as the agent reported it (partial)"
else
  fail "acceptance (5): expected status=partial (unchanged), got: $(jqf '.status')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Acceptance (6): research on demand (Stage A.8) -- the needs_research hazard fixture. The
# consequential hazard this task's own plan names: a needs_research status with no dedicated
# postflight arm falls into the off-schema catch-all, which sets halt=true and records an
# OFF_SCHEMA_STATUS system defect. This fixture pins the fix -- modeled directly on the
# "researched" fixture template (Acceptance (4a) above): planner-agent never writes a handoff
# (base-mode, mirroring general-implementation-agent), so recovery reads .return-meta.json.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Acceptance (6): needs_research verdict -- halt=false, no OFF_SCHEMA_STATUS, researching state write, no artifact-round advance"
setup_sandbox
mkdir -p "$WORKDIR/specs/900_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 900, "project_name": "candidate", "task_type": "meta", "status": "planning", "description": "candidate #900", "dependencies": [], "file_scope": [], "next_artifact_number": 1}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/900_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/900_candidate/.return-meta.json" <<'EOF'
{"status":"needs_research","dispatch_seq":1,"artifacts":[],"research_questions":["Does library X expose a streaming API?","Is the retry policy configurable?"],"metadata":{"phases_completed":0,"phases_total":0}}
EOF
window_start=$(( $(now_ts) - 5 ))
run_sut specs/900_candidate --session sess_900 --phase plan --task-type meta \
  --agent planner-agent --loop-guard-file specs/900_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" 900

if [ "$(jqf '.verdict')" = "needs_research" ]; then
  pass "acceptance (6): verdict=needs_research"
else
  fail "acceptance (6): expected verdict=needs_research, got: $LAST_STDOUT ($LAST_STDERR)"
fi
if [ "$(jqf '.halt')" = "false" ]; then
  pass "acceptance (6): halt=false"
else
  fail "acceptance (6): expected halt=false, got: $(jqf '.halt')"
fi
defect_count=$(jq '.detected_defects | length' "$WORKDIR/specs/900_candidate/.orchestrator-loop-guard" 2>/dev/null)
if [ "$defect_count" = "0" ]; then
  pass "acceptance (6): zero defects recorded (no OFF_SCHEMA_STATUS)"
else
  fail "acceptance (6): expected 0 detected_defects, got $defect_count: $(jq -c '.detected_defects' "$WORKDIR/specs/900_candidate/.orchestrator-loop-guard")"
fi
if ! echo "$LAST_STDERR" | grep -qi "OFF-SCHEMA\|OFF_SCHEMA"; then
  pass "acceptance (6): no off-schema mention in stderr"
else
  fail "acceptance (6): unexpected off-schema mention in stderr: $LAST_STDERR"
fi
new_status=$(jq -r --argjson n 900 '.active_projects[] | select(.project_number == $n) | .status' "$WORKDIR/specs/state.json")
if [ "$new_status" = "researching" ]; then
  pass "acceptance (6): state.json status -> researching"
else
  fail "acceptance (6): expected state.json status=researching, got: $new_status"
fi
new_rq=$(jq -c --argjson n 900 '.active_projects[] | select(.project_number == $n) | .research_questions' "$WORKDIR/specs/state.json")
if [ "$new_rq" = '["Does library X expose a streaming API?","Is the retry policy configurable?"]' ]; then
  pass "acceptance (6): research_questions persisted to state.json"
else
  fail "acceptance (6): expected research_questions persisted, got: $new_rq"
fi
new_next_artifact=$(jq -r --argjson n 900 '.active_projects[] | select(.project_number == $n) | .next_artifact_number' "$WORKDIR/specs/state.json")
if [ "$new_next_artifact" = "1" ]; then
  pass "acceptance (6): next_artifact_number NOT advanced (no plan artifact was produced)"
else
  fail "acceptance (6): expected next_artifact_number unchanged at 1, got: $new_next_artifact"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Acceptance (7): needs_research under a forced dispatch (clamp_mode=monotonic-max) -- the
# monotonic-max clamp interaction Phase 3/skill-base.sh recorded as intended: needs_research is
# deliberately absent from STATUS_VOCABULARY_LIFECYCLE_RANK, so the clamp can never skip this
# write, even when the task's current status (planning, rank 3) outranks the resting state the
# write resolves to (researching, rank 1) -- which a naive monotonic-max check would otherwise
# treat as a regression and skip.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Acceptance (7): needs_research under --force-invoked (monotonic-max clamp does not block it)"
setup_sandbox
mkdir -p "$WORKDIR/specs/901_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 901, "project_name": "candidate", "task_type": "meta", "status": "planning", "description": "candidate #901", "dependencies": [], "file_scope": [], "next_artifact_number": 1}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/901_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/901_candidate/.return-meta.json" <<'EOF'
{"status":"needs_research","dispatch_seq":1,"artifacts":[],"research_questions":["Is the vendor SDK still maintained?"],"metadata":{"phases_completed":0,"phases_total":0}}
EOF
window_start=$(( $(now_ts) - 5 ))
run_sut specs/901_candidate --session sess_901 --phase plan --task-type meta \
  --agent planner-agent --loop-guard-file specs/901_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" --force-invoked true 901

if [ "$(jqf '.verdict')" = "needs_research" ] && [ "$(jqf '.halt')" = "false" ]; then
  pass "acceptance (7): force-invoked needs_research still yields verdict=needs_research, halt=false"
else
  fail "acceptance (7): expected verdict=needs_research/halt=false under force-invoked, got: $LAST_STDOUT ($LAST_STDERR)"
fi
new_status_901=$(jq -r --argjson n 901 '.active_projects[] | select(.project_number == $n) | .status' "$WORKDIR/specs/state.json")
if [ "$new_status_901" = "researching" ]; then
  pass "acceptance (7): state.json status -> researching even though current status (planning, rank 3) outranks the resting state (researching, rank 1) -- clamp does not apply, by construction"
else
  fail "acceptance (7): expected state.json status=researching (clamp must not block needs_research), got: $new_status_901"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Acceptance (8): end-to-end assertion for this task's own ACCEPTANCE line -- "a
# specification-shaped task goes [NOT STARTED] -> [PLANNED] -> [COMPLETED] in two dispatches with
# a plan that passes validate-artifact.sh". This suite cannot dispatch a real planner-agent (an
# LLM), so it composes the two halves this suite CAN mechanically verify into one fixture: (a) a
# genuinely conforming plan artifact -- the SAME minimal-valid-plan shape
# test-gate-out-repair-reporting.sh's write_valid_plan() uses -- passes validate-artifact.sh
# directly, and (b) orchestrate-cycle-postflight.sh resolves a "planned" dispatch_status to
# [PLANNED] and links that exact artifact, for a task whose PRECEDING dispatch was the task's
# very first (no prior research round) -- i.e. the "one dispatch" half of not_started->planned
# that Phase 4's triage-classify fixtures (not_started routes to plan, not research) already
# proved is reachable in a single hop under the research-on-demand default.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Acceptance (8): not_started -> planned in one dispatch, with a plan that passes validate-artifact.sh"
setup_sandbox
mkdir -p "$WORKDIR/specs/902_candidate/plans"
cat > "$WORKDIR/specs/902_candidate/plans/01_fixture-spec.md" << 'EOF'
# Fixture Plan

- **Task**: 902 - fixture
- **Status**: [NOT STARTED]
- **Effort**: 1h
- **Dependencies**: None
- **Research Inputs**: none
- **Artifacts**: plans/01_fixture-spec.md
- **Standards**: none
- **Type**: meta

## Overview
x

## Goals & Non-Goals
x

## Risks & Mitigations
x

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases |
|------|--------|
| 1 | 1 |

### Phase 1: Fixture [NOT STARTED]
- **Verification Tier**: local

## Testing & Validation
x

## Artifacts & Outputs
x

## Rollback/Contingency
x
EOF

if bash "$CORE_DIR/validate-artifact.sh" "$WORKDIR/specs/902_candidate/plans/01_fixture-spec.md" plan >/tmp/va-out-$$.log 2>&1; then
  pass "acceptance (8a): the plan artifact passes validate-artifact.sh"
else
  fail "acceptance (8a): plan artifact failed validate-artifact.sh: $(cat /tmp/va-out-$$.log)"
fi
rm -f /tmp/va-out-$$.log

write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 902, "project_name": "candidate", "task_type": "meta", "status": "planning", "description": "candidate #902 -- no research_path, no prior report: this is the task's FIRST dispatch, reached directly from not_started via the research-on-demand default", "dependencies": [], "file_scope": [], "next_artifact_number": 2}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/902_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/902_candidate/.return-meta.json" <<'EOF'
{"status":"planned","dispatch_seq":1,"artifacts":[{"type":"plan","path":"specs/902_candidate/plans/01_fixture-spec.md","summary":"fixture plan"}],"metadata":{"phase_count":1,"estimated_hours":1}}
EOF
window_start=$(( $(now_ts) - 5 ))
run_sut specs/902_candidate --session sess_902 --phase plan --task-type meta \
  --agent planner-agent --loop-guard-file specs/902_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" 902

if [ "$(jqf '.verdict')" = "ok" ]; then
  pass "acceptance (8b): verdict=ok for a planned outcome reached directly from not_started (no research round)"
else
  fail "acceptance (8b): expected verdict=ok, got: $LAST_STDOUT ($LAST_STDERR)"
fi
new_status_902=$(jq -r --argjson n 902 '.active_projects[] | select(.project_number == $n) | .status' "$WORKDIR/specs/state.json")
if [ "$new_status_902" = "planned" ]; then
  pass "acceptance (8b): state.json status -> planned (the [NOT STARTED] -> [PLANNED] half of the acceptance line, in one dispatch)"
else
  fail "acceptance (8b): expected state.json status=planned, got: $new_status_902"
fi
linked_artifact=$(jq -r --argjson n 902 '.active_projects[] | select(.project_number == $n) | .artifacts // [] | map(select(.type == "plan")) | .[0].path // ""' "$WORKDIR/specs/state.json")
if [ "$linked_artifact" = "specs/902_candidate/plans/01_fixture-spec.md" ]; then
  pass "acceptance (8b): the validate-artifact.sh-passing plan was linked into state.json's artifacts"
else
  fail "acceptance (8b): expected the fixture plan linked as a plan artifact, got: $linked_artifact"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Fixture (A): the observed live incident -- general-implementation-agent (base-mode, never on
# the old agent-name allowlist) writes NEITHER .orchestrator-handoff.json NOR .return-meta.json
# (a context-exhaustion death mid-implement). Under D1's dispatch-derived predicate
# (--handoff-expected defaults to true), this now records HANDOFF_STALE_OR_ABSENT -- the exact
# gap the old allowlist left silently unrecorded.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Fixture (A): general-implementation-agent double-miss (no handoff, no return-meta) now records a defect"
setup_sandbox
mkdir -p "$WORKDIR/specs/910_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 910, "project_name": "candidate", "task_type": "meta", "status": "implementing", "description": "candidate #910 -- double-miss fixture", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/910_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
window_start=$(( $(now_ts) - 5 ))
run_sut specs/910_candidate --session sess_910 --phase implement --task-type meta \
  --agent general-implementation-agent --loop-guard-file specs/910_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" 910

if [ "$(jqf '.verdict')" = "failed" ]; then
  pass "fixture (A): verdict=failed for the double-miss"
else
  fail "fixture (A): expected verdict=failed, got: $LAST_STDOUT ($LAST_STDERR)"
fi
a_defect_count=$(jq '.detected_defects | map(select(.defect_class == "HANDOFF_STALE_OR_ABSENT")) | length' \
  "$WORKDIR/specs/910_candidate/.orchestrator-loop-guard" 2>/dev/null)
if [ "$a_defect_count" = "1" ]; then
  pass "fixture (A): exactly one HANDOFF_STALE_OR_ABSENT defect row recorded"
else
  fail "fixture (A): expected exactly 1 HANDOFF_STALE_OR_ABSENT defect, got $a_defect_count"
fi
if echo "$LAST_STDERR" | grep -q "not on the contractual handoff-writer allowlist"; then
  fail "fixture (A): stale allowlist WARN text still present on stderr"
else
  pass "fixture (A): no allowlist WARN text on stderr (the removed mechanism's wording is gone)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Fixture (B): the explicit opt-out. Same double-miss, but the caller passes
# --handoff-expected false -- the aux-dispatch-equivalent case. No defect is recorded.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Fixture (B): --handoff-expected false double-miss records zero defects"
setup_sandbox
mkdir -p "$WORKDIR/specs/911_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 911, "project_name": "candidate", "task_type": "meta", "status": "implementing", "description": "candidate #911 -- opt-out fixture", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/911_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
window_start=$(( $(now_ts) - 5 ))
run_sut specs/911_candidate --session sess_911 --phase implement --task-type meta \
  --agent general-implementation-agent --loop-guard-file specs/911_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" --handoff-expected false 911

b_defect_count=$(jq '.detected_defects | length' "$WORKDIR/specs/911_candidate/.orchestrator-loop-guard" 2>/dev/null)
if [ "$b_defect_count" = "0" ]; then
  pass "fixture (B): --handoff-expected false records zero defects for the same double-miss"
else
  fail "fixture (B): expected 0 detected_defects, got $b_defect_count"
fi
if echo "$LAST_STDERR" | grep -q "handoff not expected for this dispatch"; then
  pass "fixture (B): neutral INFO line present for the explicit opt-out"
else
  fail "fixture (B): expected the neutral opt-out INFO line on stderr, got: $LAST_STDERR"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Fixture (C): the same double-miss shape, but on the research phase with
# general-research-agent -- the task's own OBSERVED incident (5 of 7 research subagents wrote
# neither file). Asserts verdict=failed, one defect, and task status unchanged (never
# "researched").
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Fixture (C): general-research-agent double-miss (research phase) records a defect and never advances to researched"
setup_sandbox
mkdir -p "$WORKDIR/specs/912_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 912, "project_name": "candidate", "task_type": "general", "status": "researching", "description": "candidate #912 -- research double-miss fixture", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/912_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
window_start=$(( $(now_ts) - 5 ))
run_sut specs/912_candidate --session sess_912 --phase research --task-type general \
  --agent general-research-agent --loop-guard-file specs/912_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" 912

if [ "$(jqf '.verdict')" = "failed" ]; then
  pass "fixture (C): verdict=failed for the research-phase double-miss"
else
  fail "fixture (C): expected verdict=failed, got: $LAST_STDOUT ($LAST_STDERR)"
fi
c_defect_count=$(jq '.detected_defects | map(select(.defect_class == "HANDOFF_STALE_OR_ABSENT")) | length' \
  "$WORKDIR/specs/912_candidate/.orchestrator-loop-guard" 2>/dev/null)
if [ "$c_defect_count" = "1" ]; then
  pass "fixture (C): exactly one HANDOFF_STALE_OR_ABSENT defect row recorded"
else
  fail "fixture (C): expected exactly 1 HANDOFF_STALE_OR_ABSENT defect, got $c_defect_count"
fi
new_status_912=$(jq -r --argjson n 912 '.active_projects[] | select(.project_number == $n) | .status' "$WORKDIR/specs/state.json")
if [ "$new_status_912" = "researching" ]; then
  pass "fixture (C): task status unchanged (still researching, never advanced to researched)"
else
  fail "fixture (C): expected status to remain researching, got: $new_status_912"
fi
if [ "$(jqf '.report_missing')" = "true" ]; then
  pass "fixture (G): fixture C's double-miss also surfaces report_missing=true for the message-recovery consumer"
else
  fail "fixture (G): expected report_missing=true for fixture C's double-miss, got: $(jqf '.report_missing') ($LAST_STDOUT)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Fixture (D): a "researched" outcome whose claimed report artifact does not exist on disk.
# verdict=failed, task status never advances to researched, one ARTIFACTS_MISSING_ON_SUCCESS
# defect, report_missing=true.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Fixture (D): researched outcome with a nonexistent report file is refused"
setup_sandbox
mkdir -p "$WORKDIR/specs/920_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 920, "project_name": "candidate", "task_type": "general", "status": "researching", "description": "candidate #920 -- nonexistent report fixture", "dependencies": [], "file_scope": [], "next_artifact_number": 1}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/920_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/920_candidate/.return-meta.json" <<'EOF'
{"status":"researched","dispatch_seq":1,"artifacts":[{"type":"report","path":"specs/920_candidate/reports/01_x-report.md","summary":"y"}],"metadata":{}}
EOF
window_start=$(( $(now_ts) - 5 ))
run_sut specs/920_candidate --session sess_920 --phase research --task-type general \
  --agent general-research-agent --loop-guard-file specs/920_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" 920

if [ "$(jqf '.verdict')" = "failed" ]; then
  pass "fixture (D): verdict=failed for a nonexistent report file"
else
  fail "fixture (D): expected verdict=failed, got: $LAST_STDOUT ($LAST_STDERR)"
fi
new_status_920=$(jq -r --argjson n 920 '.active_projects[] | select(.project_number == $n) | .status' "$WORKDIR/specs/state.json")
if [ "$new_status_920" = "researching" ]; then
  pass "fixture (D): task status never advanced to researched"
else
  fail "fixture (D): expected status to remain researching, got: $new_status_920"
fi
d_defect_count=$(jq '.detected_defects | map(select(.defect_class == "ARTIFACTS_MISSING_ON_SUCCESS")) | length' \
  "$WORKDIR/specs/920_candidate/.orchestrator-loop-guard" 2>/dev/null)
if [ "$d_defect_count" = "1" ]; then
  pass "fixture (D): exactly one ARTIFACTS_MISSING_ON_SUCCESS defect recorded"
else
  fail "fixture (D): expected exactly 1 ARTIFACTS_MISSING_ON_SUCCESS defect, got $d_defect_count"
fi
if [ "$(jqf '.report_missing')" = "true" ]; then
  pass "fixture (D): report_missing=true"
else
  fail "fixture (D): expected report_missing=true, got: $(jqf '.report_missing')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Fixture (E): a "researched" outcome whose claimed report artifact exists but is EMPTY (0
# bytes). Same assertions as (D) -- an empty file is not a usable report.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Fixture (E): researched outcome with an empty report file is refused"
setup_sandbox
mkdir -p "$WORKDIR/specs/921_candidate/reports"
: > "$WORKDIR/specs/921_candidate/reports/01_x-report.md"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 921, "project_name": "candidate", "task_type": "general", "status": "researching", "description": "candidate #921 -- empty report fixture", "dependencies": [], "file_scope": [], "next_artifact_number": 1}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/921_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/921_candidate/.return-meta.json" <<'EOF'
{"status":"researched","dispatch_seq":1,"artifacts":[{"type":"report","path":"specs/921_candidate/reports/01_x-report.md","summary":"y"}],"metadata":{}}
EOF
window_start=$(( $(now_ts) - 5 ))
run_sut specs/921_candidate --session sess_921 --phase research --task-type general \
  --agent general-research-agent --loop-guard-file specs/921_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" 921

if [ "$(jqf '.verdict')" = "failed" ]; then
  pass "fixture (E): verdict=failed for an empty report file"
else
  fail "fixture (E): expected verdict=failed, got: $LAST_STDOUT ($LAST_STDERR)"
fi
new_status_921=$(jq -r --argjson n 921 '.active_projects[] | select(.project_number == $n) | .status' "$WORKDIR/specs/state.json")
if [ "$new_status_921" = "researching" ]; then
  pass "fixture (E): task status never advanced to researched"
else
  fail "fixture (E): expected status to remain researching, got: $new_status_921"
fi
e_defect_count=$(jq '.detected_defects | map(select(.defect_class == "ARTIFACTS_MISSING_ON_SUCCESS")) | length' \
  "$WORKDIR/specs/921_candidate/.orchestrator-loop-guard" 2>/dev/null)
if [ "$e_defect_count" = "1" ]; then
  pass "fixture (E): exactly one ARTIFACTS_MISSING_ON_SUCCESS defect recorded"
else
  fail "fixture (E): expected exactly 1 ARTIFACTS_MISSING_ON_SUCCESS defect, got $e_defect_count"
fi
if [ "$(jqf '.report_missing')" = "true" ]; then
  pass "fixture (E): report_missing=true"
else
  fail "fixture (E): expected report_missing=true, got: $(jqf '.report_missing')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Fixture (F): regression guard -- a genuine, non-empty report file plus a valid
# .return-meta.json still yields verdict=ok, status->researched, report_missing=false, and the
# artifact gets linked.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Fixture (F): a real non-empty report still transitions to researched (regression guard)"
setup_sandbox
mkdir -p "$WORKDIR/specs/922_candidate/reports"
echo "real findings" > "$WORKDIR/specs/922_candidate/reports/01_x-report.md"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 922, "project_name": "candidate", "task_type": "general", "status": "researching", "description": "candidate #922 -- regression guard fixture", "dependencies": [], "file_scope": [], "next_artifact_number": 1}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/922_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/922_candidate/.return-meta.json" <<'EOF'
{"status":"researched","dispatch_seq":1,"artifacts":[{"type":"report","path":"specs/922_candidate/reports/01_x-report.md","summary":"real findings"}],"metadata":{}}
EOF
window_start=$(( $(now_ts) - 5 ))
run_sut specs/922_candidate --session sess_922 --phase research --task-type general \
  --agent general-research-agent --loop-guard-file specs/922_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" 922

if [ "$(jqf '.verdict')" = "ok" ]; then
  pass "fixture (F): verdict=ok for a genuine non-empty report"
else
  fail "fixture (F): expected verdict=ok, got: $LAST_STDOUT ($LAST_STDERR)"
fi
new_status_922=$(jq -r --argjson n 922 '.active_projects[] | select(.project_number == $n) | .status' "$WORKDIR/specs/state.json")
if [ "$new_status_922" = "researched" ]; then
  pass "fixture (F): task status advanced to researched"
else
  fail "fixture (F): expected status=researched, got: $new_status_922"
fi
f_defect_count=$(jq '.detected_defects | length' "$WORKDIR/specs/922_candidate/.orchestrator-loop-guard" 2>/dev/null)
if [ "$f_defect_count" = "0" ]; then
  pass "fixture (F): zero defects recorded for a genuine success"
else
  fail "fixture (F): expected 0 detected_defects, got $f_defect_count"
fi
if [ "$(jqf '.report_missing')" = "false" ]; then
  pass "fixture (F): report_missing=false"
else
  fail "fixture (F): expected report_missing=false, got: $(jqf '.report_missing')"
fi
linked_report_922=$(jq -r --argjson n 922 '.active_projects[] | select(.project_number == $n) | .artifacts // [] | map(select(.type == "report")) | .[0].path // ""' "$WORKDIR/specs/state.json")
if [ "$linked_report_922" = "specs/922_candidate/reports/01_x-report.md" ]; then
  pass "fixture (F): the report was linked into state.json's artifacts"
else
  fail "fixture (F): expected the report linked, got: $linked_report_922"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Invariant: the 9999999999 sentinel is literal and shared across the two gate scripts
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Invariant: 9999999999 fail-closed sentinel is the same literal in both scripts"
sentinel_count_1=$(grep -c 9999999999 "$CORE_DIR/orchestrate-cycle-postflight.sh")
sentinel_count_2=$(grep -c 9999999999 "$CORE_DIR/orchestrate-recover-outcome.sh")
if [ "$sentinel_count_1" -ge 1 ] && [ "$sentinel_count_2" -ge 1 ]; then
  pass "invariant: 9999999999 sentinel present in both orchestrate-cycle-postflight.sh and orchestrate-recover-outcome.sh"
else
  fail "invariant: 9999999999 sentinel missing from one or both scripts (postflight=$sentinel_count_1, recover=$sentinel_count_2)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Invariant: the excursion advisory never changes exit code or verdict
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Invariant: modified_files-vs-file_scope excursion never changes exit code or verdict"
setup_sandbox
mkdir -p "$WORKDIR/specs/707_candidate/summaries"
echo x > "$WORKDIR/specs/707_candidate/summaries/01_x-summary.md"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 707, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #707", "dependencies": [], "file_scope": ["specs/707_candidate/"]}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/707_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/707_candidate/.return-meta.json" <<'EOF'
{"status":"implemented","dispatch_seq":1,"artifacts":[{"type":"summary","path":"specs/707_candidate/summaries/01_x-summary.md","summary":"y"}],"metadata":{"phases_completed":1,"phases_total":1},"modified_files":["specs/707_candidate/summaries/01_x-summary.md","completely/unrelated/excursion.sh"]}
EOF
window_start=$(( $(now_ts) - 5 ))
run_sut specs/707_candidate --session sess_707 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/707_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" 707

if [ "$LAST_EXIT" -eq 0 ] && [ "$(jqf '.verdict')" = "ok" ]; then
  pass "invariant: an excursion outside file_scope still exits 0 with verdict=ok (detection only)"
else
  fail "invariant: excursion changed exit code or verdict — exit=$LAST_EXIT, verdict=$(jqf '.verdict')"
fi
if echo "$LAST_STDERR" | grep -q "ADVISORY.*excursion.sh"; then
  pass "invariant: the excursion is actually logged (the check is not silently inert)"
else
  fail "invariant: no ADVISORY excursion notice found in stderr: $LAST_STDERR"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Invariant: --dry-run mutates nothing (git, state.json, loop guard all byte-identical)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Invariant: --dry-run leaves git status, state.json, and the loop guard unchanged"
setup_sandbox
mkdir -p "$WORKDIR/specs/708_candidate/summaries"
echo x > "$WORKDIR/specs/708_candidate/summaries/01_x-summary.md"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 708, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #708", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/708_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/708_candidate/.return-meta.json" <<'EOF'
{"status":"implemented","dispatch_seq":1,"artifacts":[{"type":"summary","path":"specs/708_candidate/summaries/01_x-summary.md","summary":"y"}],"metadata":{"phases_completed":1,"phases_total":1},"modified_files":["specs/708_candidate/summaries/01_x-summary.md"]}
EOF
window_start=$(( $(now_ts) - 5 ))
before_state=$(md5sum "$STATE_FILE" | cut -d' ' -f1)
before_guard=$(md5sum "$WORKDIR/specs/708_candidate/.orchestrator-loop-guard" | cut -d' ' -f1)
before_head=$(cd "$WORKDIR" && git rev-parse HEAD)
before_porcelain=$(cd "$WORKDIR" && git status --porcelain)

run_sut specs/708_candidate --session sess_708 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/708_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" --dry-run 708

after_state=$(md5sum "$STATE_FILE" | cut -d' ' -f1)
after_guard=$(md5sum "$WORKDIR/specs/708_candidate/.orchestrator-loop-guard" | cut -d' ' -f1)
after_head=$(cd "$WORKDIR" && git rev-parse HEAD)
after_porcelain=$(cd "$WORKDIR" && git status --porcelain)

if [ "$before_state" = "$after_state" ]; then
  pass "invariant: --dry-run leaves state.json byte-identical"
else
  fail "invariant: --dry-run mutated state.json"
fi
if [ "$before_guard" = "$after_guard" ]; then
  pass "invariant: --dry-run leaves the loop guard (defect store) byte-identical"
else
  fail "invariant: --dry-run mutated the loop guard"
fi
if [ "$before_head" = "$after_head" ] && [ "$before_porcelain" = "$after_porcelain" ]; then
  pass "invariant: --dry-run performs no commit and leaves git status unchanged"
else
  fail "invariant: --dry-run changed git HEAD or working-tree status"
fi
if [ "$(jqf '.verdict')" = "ok" ]; then
  pass "invariant: --dry-run still emits the identical decision output (verdict=ok)"
else
  fail "invariant: --dry-run's decision output diverged, got verdict=$(jqf '.verdict')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Invariant: halt=true only for an off-schema dispatch_status; a genuine verdict=failed does not
# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Motivates why `halt` and `infra_exempt_cycle` were added to the output contract during Phase 7
# of this task's own plan: verdict="failed" alone cannot tell a caller whether to EXIT the whole
# /orchestrate invocation (off-schema — the outcome cannot be trusted at all) or simply let the
# task stay in-flight for the next cycle (a genuine in-vocabulary dispatch_status="failed").
info "Invariant: halt=true only for an off-schema dispatch_status"
setup_sandbox
mkdir -p "$WORKDIR/specs/705_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 705, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #705", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/705_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
window_start=$(( $(now_ts) - 5 ))
cat > "$WORKDIR/specs/705_candidate/.orchestrator-handoff.json" <<'EOF'
{"status": "garbage-not-in-vocabulary", "dispatch_seq": 1}
EOF
run_sut specs/705_candidate --session sess_705 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/705_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" 705

if [ "$(jqf '.verdict')" = "failed" ] && [ "$(jqf '.halt')" = "true" ]; then
  pass "invariant: an off-schema dispatch_status yields verdict=failed AND halt=true"
else
  fail "invariant: expected verdict=failed halt=true for an off-schema status, got: $LAST_STDOUT ($LAST_STDERR)"
fi
if [ "$(jqf '.infra_exempt_cycle')" = "false" ]; then
  pass "invariant: an off-schema dispatch_status is not infra-exempt"
else
  fail "invariant: expected infra_exempt_cycle=false for an off-schema status, got: $LAST_STDOUT"
fi
# Cross-check, same sandbox: a genuine IN-VOCABULARY dispatch_status="failed" (a present, fresh,
# correctly-seq'd handoff -- the ordinary "the dispatched agent reported it failed" case) must
# NOT set halt=true, or every caller's loop-control would incorrectly stop the whole invocation
# on an ordinary in-budget failure instead of leaving the task in-flight for the next cycle.
mkdir -p "$WORKDIR/specs/707_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 707, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #707", "dependencies": [], "file_scope": []}]}
EOF
commit_fixture
cat > "$WORKDIR/specs/707_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/707_candidate/.orchestrator-handoff.json" <<'EOF'
{"status": "failed", "dispatch_seq": 1}
EOF
run_sut specs/707_candidate --session sess_707 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/707_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$(( $(now_ts) - 5 ))" 707

if [ "$(jqf '.verdict')" = "failed" ] && [ "$(jqf '.halt')" = "false" ]; then
  pass "invariant: a genuine in-vocabulary dispatch_status=failed leaves halt=false (does not stop the loop)"
else
  fail "invariant: expected verdict=failed halt=false for an in-vocabulary failed status, got: $LAST_STDOUT ($LAST_STDERR)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Invariant: infra_exempt_cycle=true only for a corroborated infra failure, never for an ordinary
# defer (partial dispatch, or implemented with the completion-claim gate refused)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Invariant: infra_exempt_cycle=true when the infra-failure discrimination is corroborated"
setup_sandbox
mkdir -p "$WORKDIR/specs/706_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 706, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #706", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/706_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
# No handoff, no .return-meta.json at all -- meta_touched is structurally false (stat on a
# missing file yields mtime 0, always older than any window). Corroborated by --transport-error
# true, matching the two-signal contract WORK (a)'s header documents.
window_start=$(now_ts)
run_sut specs/706_candidate --session sess_706 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/706_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" --transport-error true 706

if [ "$(jqf '.infra_exempt_cycle')" = "true" ] && [ "$(jqf '.verdict')" = "defer" ]; then
  pass "invariant: a corroborated infra failure yields infra_exempt_cycle=true (verdict=defer)"
else
  fail "invariant: expected infra_exempt_cycle=true verdict=defer for a corroborated infra failure, got: $LAST_STDOUT ($LAST_STDERR)"
fi
if [ "$(jqf '.halt')" = "false" ]; then
  pass "invariant: a corroborated infra failure does not halt"
else
  fail "invariant: expected halt=false for a corroborated infra failure, got: $LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# WORK (k): --hard invokes orchestrate-churn.sh (three consecutive zero-progress partials on one
# blocker target reach the three-strikes threshold and request a divergence audit); a base-mode
# run never invokes it at all.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "WORK (k): --hard invokes orchestrate-churn.sh; base mode does not"
setup_sandbox
mkdir -p "$WORKDIR/specs/820_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 820, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #820", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/820_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 4, "detected_defects": [], "infra_failures": 0}
EOF

run_churn_cycle() {
  # Usage: run_churn_cycle <dispatch_seq>
  local seq="$1"
  cat > "$WORKDIR/specs/820_candidate/.orchestrator-handoff.json" <<EOF
{"status": "partial", "dispatch_seq": ${seq}, "phases_completed": 2, "phases_total": 5, "blockers": [{"target": "foo", "verbatim_goal": "do foo"}]}
EOF
  run_sut specs/820_candidate --session sess_820 --phase implement --task-type general \
    --agent general-implementation-agent --loop-guard-file specs/820_candidate/.orchestrator-loop-guard \
    --dispatch-seq "$seq" --dispatch-start-ts "$(( $(now_ts) - 5 ))" --hard 820
}

run_churn_cycle 1
if [ -f "$WORKDIR/specs/820_candidate/.orchestrator-churn-state.json" ]; then
  pass "churn: --hard invokes orchestrate-churn.sh (churn-state file created)"
else
  fail "churn: --hard did not invoke orchestrate-churn.sh (no churn-state file)"
fi
if [ "$(jqf '.aux_signal')" = "null" ]; then
  pass "churn: cycle 1 (no prior phases_completed_last) records no aux_signal yet"
else
  fail "churn: cycle 1 unexpectedly recorded an aux_signal: $(jqf '.aux_signal')"
fi

run_churn_cycle 2
if [ "$(jqf '.aux_signal')" = "null" ]; then
  pass "churn: cycle 2 (churn count 1) does not yet request an audit"
else
  fail "churn: cycle 2 unexpectedly recorded an aux_signal: $(jqf '.aux_signal')"
fi

run_churn_cycle 3
if [ "$(jqf '.aux_signal')" = "null" ]; then
  pass "churn: cycle 3 (churn count 2) does not yet request an audit"
else
  fail "churn: cycle 3 unexpectedly recorded an aux_signal: $(jqf '.aux_signal')"
fi

run_churn_cycle 4
if [ "$(jqf '.aux_signal.kind')" = "divergence-audit" ] && [ "$(jqf '.aux_signal.target')" = "foo" ] \
   && [ "$(jqf '.aux_signal.verbatim_goal')" = "do foo" ]; then
  pass "churn: cycle 4 (churn count 3) requests a divergence-audit aux_signal"
else
  fail "churn: cycle 4 did not request a divergence-audit (stdout: $LAST_STDOUT)"
fi
if jq -e '.aux_pending."820".kind == "divergence-audit" and .aux_pending."820".target == "foo"' \
     "$WORKDIR/specs/820_candidate/.orchestrator-loop-guard" >/dev/null 2>&1; then
  pass "churn: aux_pending[820] persisted to the resolved state store (loop-guard file)"
else
  fail "churn: aux_pending[820] not found in the loop-guard file"
fi
if [ "$(jqf '.verdict')" != "null" ] && [ "$(jqf '.halt')" = "false" ]; then
  pass "churn: recording an aux_signal never changes verdict/halt (still an ordinary defer outcome)"
else
  fail "churn: recording an aux_signal unexpectedly changed verdict/halt: $LAST_STDOUT"
fi

# Base-mode companion: the SAME churn signature, without --hard, must never invoke the script.
mkdir -p "$WORKDIR/specs/821_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 821, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #821", "dependencies": [], "file_scope": []}]}
EOF
commit_fixture
cat > "$WORKDIR/specs/821_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/821_candidate/.orchestrator-handoff.json" <<'EOF'
{"status": "partial", "dispatch_seq": 1, "phases_completed": 2, "phases_total": 5, "blockers": [{"target": "foo", "verbatim_goal": "do foo"}]}
EOF
run_sut specs/821_candidate --session sess_821 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/821_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$(( $(now_ts) - 5 ))" 821

if [ ! -f "$WORKDIR/specs/821_candidate/.orchestrator-churn-state.json" ]; then
  pass "churn: a base-mode run (no --hard) never invokes orchestrate-churn.sh"
else
  fail "churn: a base-mode run unexpectedly created a churn-state file"
fi
# NOTE: this handoff (2/5 phases, 40%) also happens to be below the drift threshold, so a
# drift-inspection aux_signal IS correctly expected here (base mode's own trigger) -- the
# invariant under test is narrower: never a divergence-audit signal outside --hard.
if [ "$(jqf '.aux_signal.kind')" != "divergence-audit" ]; then
  pass "churn: a base-mode run with a churn-shaped handoff never records a divergence-audit aux_signal"
else
  fail "churn: a base-mode run unexpectedly recorded a divergence-audit aux_signal: $(jqf '.aux_signal')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# WORK (k): base-mode drift-inspection aux signal (phases_completed/phases_total < 70%)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "WORK (k): base-mode drift-inspection aux signal fires below the 70% threshold, not above it"
mkdir -p "$WORKDIR/specs/822_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 822, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #822", "dependencies": [], "file_scope": []}]}
EOF
commit_fixture
cat > "$WORKDIR/specs/822_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/822_candidate/.orchestrator-handoff.json" <<'EOF'
{"status": "partial", "dispatch_seq": 1, "phases_completed": 1, "phases_total": 5}
EOF
run_sut specs/822_candidate --session sess_822 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/822_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$(( $(now_ts) - 5 ))" 822

if [ "$(jqf '.aux_signal.kind')" = "drift-inspection" ]; then
  pass "drift: 1/5 phases (20%, below 70%) records a drift-inspection aux_signal"
else
  fail "drift: expected a drift-inspection aux_signal at 1/5 phases, got: $LAST_STDOUT"
fi
if jq -e '.aux_pending."822".kind == "drift-inspection"' \
     "$WORKDIR/specs/822_candidate/.orchestrator-loop-guard" >/dev/null 2>&1; then
  pass "drift: aux_pending[822] persisted to the loop-guard file"
else
  fail "drift: aux_pending[822] not found in the loop-guard file"
fi

# Negative case: 4/5 phases (80%, at/above 70%) must NOT record a drift signal.
mkdir -p "$WORKDIR/specs/823_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 823, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #823", "dependencies": [], "file_scope": []}]}
EOF
commit_fixture
cat > "$WORKDIR/specs/823_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/823_candidate/.orchestrator-handoff.json" <<'EOF'
{"status": "partial", "dispatch_seq": 1, "phases_completed": 4, "phases_total": 5}
EOF
run_sut specs/823_candidate --session sess_823 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/823_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$(( $(now_ts) - 5 ))" 823

if [ "$(jqf '.aux_signal')" = "null" ]; then
  pass "drift: 4/5 phases (80%, at/above 70%) records no drift-inspection aux_signal"
else
  fail "drift: unexpected aux_signal at 4/5 phases: $(jqf '.aux_signal')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# WORK (k): blocker-research aux signal fires unconditionally on verdict=blocked (either mode)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "WORK (k): blocker-research aux signal fires on verdict=blocked"
mkdir -p "$WORKDIR/specs/824_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 824, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #824", "dependencies": [], "file_scope": [], "blockers": "Missing API key"}]}
EOF
commit_fixture
cat > "$WORKDIR/specs/824_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/824_candidate/.orchestrator-handoff.json" <<'EOF'
{"status": "blocked", "dispatch_seq": 1}
EOF
run_sut specs/824_candidate --session sess_824 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/824_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$(( $(now_ts) - 5 ))" 824

if [ "$(jqf '.verdict')" = "blocked" ] && [ "$(jqf '.aux_signal.kind')" = "blocker-research" ] \
   && [ "$(jqf '.aux_signal.blocker_desc')" = "Missing API key" ]; then
  pass "blocker-research: verdict=blocked records a blocker-research aux_signal with the state.json blocker description"
else
  fail "blocker-research: expected a blocker-research aux_signal, got: $LAST_STDOUT"
fi
if jq -e '.aux_pending."824".kind == "blocker-research"' \
     "$WORKDIR/specs/824_candidate/.orchestrator-loop-guard" >/dev/null 2>&1; then
  pass "blocker-research: aux_pending[824] persisted to the loop-guard file"
else
  fail "blocker-research: aux_pending[824] not found in the loop-guard file"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Regression (base mode, non-hard-mode task): a `partial` outcome carrying a non-empty handoff
# `blockers[]`, no continuation pointer, now writes status="partial" to state.json (making
# orchestrate-triage-classify.sh's "partial + blockers, no continuation -> needs_human" row
# reachable) AND raises the widened blocker-research aux signal, with its description derived
# from the handoff (not the never-written state.json .active_projects[].blockers string).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Regression: partial + non-empty blockers[] writes status=partial and records a handoff-derived blocker-research aux signal"
setup_sandbox
mkdir -p "$WORKDIR/specs/830_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 830, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #830", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/830_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/830_candidate/.orchestrator-handoff.json" <<'EOF'
{"status": "partial", "dispatch_seq": 1, "phases_completed": 3, "phases_total": 4, "blockers": [{"target": "aeneas-macos-aarch64 asset", "verbatim_goal": "download the release asset", "why_it_failed": "upstream release lacks this asset"}]}
EOF
run_sut specs/830_candidate --session sess_830 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/830_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$(( $(now_ts) - 5 ))" 830

new_status_830=$(jq -r --argjson n 830 '.active_projects[] | select(.project_number == $n) | .status' "$WORKDIR/specs/state.json")
if [ "$new_status_830" = "partial" ]; then
  pass "regression (830): state.json status -> partial (blocker-bearing partial)"
else
  fail "regression (830): expected state.json status=partial, got: $new_status_830"
fi
if [ "$(jqf '.verdict')" = "defer" ]; then
  pass "regression (830): verdict=defer (unchanged)"
else
  fail "regression (830): expected verdict=defer, got: $(jqf '.verdict')"
fi
if [ "$(jqf '.halt')" = "false" ]; then
  pass "regression (830): halt=false"
else
  fail "regression (830): expected halt=false, got: $(jqf '.halt')"
fi
if [ "$(jqf '.aux_signal.kind')" = "blocker-research" ]; then
  pass "regression (830): aux_signal.kind=blocker-research"
else
  fail "regression (830): expected aux_signal.kind=blocker-research, got: $LAST_STDOUT"
fi
blocker_desc_830=$(jqf '.aux_signal.blocker_desc')
if [ "$blocker_desc_830" != "Unspecified blocker" ] \
   && echo "$blocker_desc_830" | grep -q "aeneas-macos-aarch64 asset" \
   && echo "$blocker_desc_830" | grep -q "upstream release lacks this asset"; then
  pass "regression (830): blocker_desc derived from the handoff (target + why_it_failed), not the fallback"
else
  fail "regression (830): expected a handoff-derived blocker_desc, got: $blocker_desc_830"
fi
if jq -e '.aux_pending."830".kind == "blocker-research"' \
     "$WORKDIR/specs/830_candidate/.orchestrator-loop-guard" >/dev/null 2>&1; then
  pass "regression (830): aux_pending[830] persisted to the loop-guard file"
else
  fail "regression (830): aux_pending[830] not found in the loop-guard file"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Regression negative case: a `partial` outcome with EMPTY blockers[] must leave state.json
# status UNCHANGED (still "implementing") -- the explicit "current defer behaviour must be
# preserved" requirement -- and must record no blocker-research aux signal.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Regression: partial + empty blockers[] leaves state.json status unchanged and records no blocker-research aux signal"
setup_sandbox
mkdir -p "$WORKDIR/specs/831_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 831, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #831", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/831_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/831_candidate/.orchestrator-handoff.json" <<'EOF'
{"status": "partial", "dispatch_seq": 1, "phases_completed": 3, "phases_total": 4}
EOF
run_sut specs/831_candidate --session sess_831 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/831_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$(( $(now_ts) - 5 ))" 831

new_status_831=$(jq -r --argjson n 831 '.active_projects[] | select(.project_number == $n) | .status' "$WORKDIR/specs/state.json")
if [ "$new_status_831" = "implementing" ]; then
  pass "regression (831): state.json status unchanged (still implementing) for an empty-blockers partial"
else
  fail "regression (831): expected state.json status to remain implementing, got: $new_status_831"
fi
if [ "$(jqf '.verdict')" = "defer" ]; then
  pass "regression (831): verdict=defer"
else
  fail "regression (831): expected verdict=defer, got: $(jqf '.verdict')"
fi
if [ "$(jqf '.aux_signal.kind')" != "blocker-research" ]; then
  pass "regression (831): no blocker-research aux signal recorded (75% progress is also above the drift threshold)"
else
  fail "regression (831): unexpected blocker-research aux signal for an empty-blockers partial: $(jqf '.aux_signal')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Regression: partial + non-empty blockers[] + a user_decision payload -- the status write and
# the ask_user verdict resolution are independent and both apply (Risk table interaction case).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Regression: partial + blockers[] + user_decision -- status write still happens, ask_user verdict still resolves"
setup_sandbox
mkdir -p "$WORKDIR/specs/832_candidate"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 832, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #832", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/832_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/832_candidate/.orchestrator-handoff.json" <<'EOF'
{"status": "partial", "dispatch_seq": 1, "phases_completed": 3, "phases_total": 4, "blockers": [{"target": "aeneas-macos-aarch64 asset", "verbatim_goal": "download the release asset", "why_it_failed": "upstream release lacks this asset"}], "user_decision": {"question": "Skip the macOS build or wait for upstream?", "options": ["skip", "wait"]}}
EOF
run_sut specs/832_candidate --session sess_832 --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file specs/832_candidate/.orchestrator-loop-guard \
  --dispatch-seq 1 --dispatch-start-ts "$(( $(now_ts) - 5 ))" 832

new_status_832=$(jq -r --argjson n 832 '.active_projects[] | select(.project_number == $n) | .status' "$WORKDIR/specs/state.json")
if [ "$new_status_832" = "partial" ]; then
  pass "regression (832): state.json status -> partial even alongside a user_decision payload"
else
  fail "regression (832): expected state.json status=partial, got: $new_status_832"
fi
if [ "$(jqf '.verdict')" = "ask_user" ]; then
  pass "regression (832): verdict=ask_user (user_decision relay still resolves its own verdict)"
else
  fail "regression (832): expected verdict=ask_user, got: $(jqf '.verdict')"
fi
expected_ud_832='{"question":"Skip the macOS build or wait for upstream?","options":["skip","wait"]}'
actual_ud_832=$(jqf '.user_decision')
if [ "$(jq -c -n --argjson a "$expected_ud_832" '$a')" = "$(jq -c -n --argjson b "$actual_ud_832" '$b' 2>/dev/null)" ]; then
  pass "regression (832): user_decision payload relayed verbatim alongside the status write"
else
  fail "regression (832): user_decision payload not relayed intact: got $actual_ud_832, expected $expected_ud_832"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Invariant: the stray-handoff sweep (Phase 7 addition, absorbed from the single-task-only
# orchestrate-stage5-gates.sh) fires for BOTH engines -- exercised here via the multi-task path
# (no --loop-guard-file), since the single-task path already had this coverage historically.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Invariant: stray-handoff sweep fires and records HANDOFF_MISLOCATED (multi-task path)"
setup_sandbox
mkdir -p "$WORKDIR/specs/708_candidate/summaries"
echo x > "$WORKDIR/specs/708_candidate/summaries/01_x-summary.md"
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 708, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #708", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/.orchestrator-multi-state-sess_708.json" <<'EOF'
{"detected_defects": [], "infra_failures": {}, "dispatch_seq": {"708": 1}, "dispatch_start_ts": {}}
EOF
cat > "$WORKDIR/specs/708_candidate/.return-meta.json" <<'EOF'
{"status":"implemented","dispatch_seq":1,"artifacts":[{"type":"summary","path":"specs/708_candidate/summaries/01_x-summary.md","summary":"y"}],"metadata":{"phases_completed":1,"phases_total":1}}
EOF
# The stray file itself, at repo root -- a writer that mis-resolved its own task_dir.
echo '{"status":"implemented"}' > "$WORKDIR/.orchestrator-handoff.json"
run_sut specs/708_candidate --session sess_708 --phase implement --task-type general \
  --agent general-implementation-agent --dispatch-seq 1 --dispatch-start-ts "$(( $(now_ts) - 5 ))" 708

if echo "$LAST_STDERR" | grep -q "STRAY HANDOFF"; then
  pass "invariant: stray handoff at repo root is detected"
else
  fail "invariant: no STRAY HANDOFF notice in stderr: $LAST_STDERR"
fi
if [ ! -e "$WORKDIR/.orchestrator-handoff.json" ]; then
  pass "invariant: stray handoff was moved aside (not left at repo root)"
else
  fail "invariant: stray handoff was NOT moved aside"
fi
if jq -e '.detected_defects | map(select(.defect_class == "HANDOFF_MISLOCATED")) | length >= 1' \
     "$WORKDIR/specs/.orchestrator-multi-state-sess_708.json" >/dev/null 2>&1; then
  pass "invariant: HANDOFF_MISLOCATED recorded in the multi-state file (not just the loop guard)"
else
  fail "invariant: no HANDOFF_MISLOCATED recorded in the multi-state file"
fi
# The task's own outcome (recovered via .return-meta.json, since no handoff sits at the correct
# path) must still resolve normally -- the sweep is a side observation, never a gate.
if [ "$(jqf '.verdict')" = "ok" ]; then
  pass "invariant: the stray-handoff sweep never blocks this dispatch's own outcome resolution"
else
  fail "invariant: expected verdict=ok despite the stray handoff, got: $LAST_STDOUT ($LAST_STDERR)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Invariant: entry-point fd-3 emit discipline (mirrors orchestrate-cycle-plan.sh's own Group 16).
#
# update-task-status.sh's own final confirmation lines (`OK: ... status -> ...` /
# `OK: ... state.json already at ... (no-op)`) are written unconditionally to STDOUT for every
# live, non-dry-run call -- including postflight calls, since it is one shared script used by
# both preflight and postflight. skill_postflight_update invokes it directly, NOT through any
# capture-and-parse wrapper, and after this phase's `exec 3>&1 1>&2` entry-point redirect it
# carries no per-call-site `>&2` guard of its own any more (the prior stopgap was removed as
# redundant). This uses the REAL, unmodified update-task-status.sh (already copied into the
# sandbox by setup_sandbox) rather than a stub, since the real script's own final lines already
# reproduce the exact shape this phase fixes structurally.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Invariant: entry-point fd-3 redirect keeps the postflight verdict JSON pure against update-task-status.sh's own stdout confirmation"
setup_sandbox
candidate_num=1601
mkdir -p "$WORKDIR/specs/${candidate_num}_candidate"
write_state <<EOF
{"next_project_number": 2, "active_projects": [{"project_number": ${candidate_num}, "project_name": "candidate", "task_type": "meta", "status": "planning", "description": "candidate #${candidate_num} -- fd-3 emit discipline invariant", "dependencies": [], "file_scope": [], "next_artifact_number": 1}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/${candidate_num}_candidate/.orchestrator-loop-guard" <<EOF
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
cat > "$WORKDIR/specs/${candidate_num}_candidate/.return-meta.json" <<EOF
{"status":"planned","dispatch_seq":1,"artifacts":[],"metadata":{"phase_count":0,"estimated_hours":1}}
EOF
window_start=$(( $(now_ts) - 5 ))
run_sut "specs/${candidate_num}_candidate" --session sess_fd3 --phase plan --task-type meta \
  --agent planner-agent --loop-guard-file "specs/${candidate_num}_candidate/.orchestrator-loop-guard" \
  --dispatch-seq 1 --dispatch-start-ts "$window_start" "$candidate_num"

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "invariant (fd-3): SUT exits 0 with the real update-task-status.sh confirmation on its own stdout"
else
  fail "invariant (fd-3): SUT exited $LAST_EXIT ($LAST_STDERR)"
fi

if echo "$LAST_STDOUT" | jq -e . >/dev/null 2>&1; then
  pass "invariant (fd-3): stdout parses as a single JSON object"
else
  fail "invariant (fd-3): stdout is not parseable JSON -- '$LAST_STDOUT'"
fi

g_fd3_lines=$(printf '%s\n' "$LAST_STDOUT" | grep -c . || true)
if [ "$g_fd3_lines" -eq 1 ]; then
  pass "invariant (fd-3): stdout is exactly one line (no confirmation preamble)"
else
  fail "invariant (fd-3): expected exactly 1 stdout line, got $g_fd3_lines: '$LAST_STDOUT'"
fi

if [ "$(jqf '.verdict')" = "ok" ]; then
  pass "invariant (fd-3): verdict=ok, the underlying postflight write still succeeded"
else
  fail "invariant (fd-3): expected verdict=ok, got: $LAST_STDOUT"
fi

g_fd3_marker="OK: task ${candidate_num}"
if echo "$LAST_STDERR" | grep -qF "$g_fd3_marker"; then
  pass "invariant (fd-3): update-task-status.sh's own stdout confirmation landed on stderr, not the data channel"
else
  fail "invariant (fd-3): expected update-task-status.sh's confirmation on stderr; got: '$LAST_STDERR'"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Invariant: pending_dispatch ledger clearing (Item (b)'s durable cross-invocation half). Any
# postflight outcome is proof the composition that recorded pending_dispatch was consumed, so
# this script clears it unconditionally as one of its first writes -- engine-agnostic (targets
# the durable per-task .orchestrator-loop-guard file directly, not the ephemeral mt_state_file).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Invariant: pending_dispatch is cleared from the durable loop-guard file on any postflight outcome"
setup_sandbox
pd_candidate_num=1602
mkdir -p "$WORKDIR/specs/${pd_candidate_num}_candidate/summaries"
echo x > "$WORKDIR/specs/${pd_candidate_num}_candidate/summaries/01_x-summary.md"
write_state <<EOF
{"next_project_number": 2, "active_projects": [{"project_number": ${pd_candidate_num}, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #${pd_candidate_num} -- pending_dispatch clearing invariant", "dependencies": [], "file_scope": []}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
commit_fixture
cat > "$WORKDIR/specs/${pd_candidate_num}_candidate/.orchestrator-loop-guard" <<EOF
{"dispatch_seq_counter": 5, "detected_defects": [], "infra_failures": 0, "cycle_count": 3, "pending_dispatch": {"seq": 5, "phase": "implement", "forced": false, "dispatch_file": "/fake/path.md", "recorded_at": "2026-01-01T00:00:00Z"}}
EOF
future_window=$(( $(now_ts) + 500 ))
cat > "$WORKDIR/specs/${pd_candidate_num}_candidate/.return-meta.json" <<EOF
{"status":"implemented","dispatch_seq":5,"artifacts":[{"type":"summary","path":"specs/${pd_candidate_num}_candidate/summaries/01_x-summary.md","summary":"y"}],"metadata":{"phases_completed":1,"phases_total":1}}
EOF
touch -d "@${future_window}" "$WORKDIR/specs/${pd_candidate_num}_candidate/.return-meta.json" 2>/dev/null || true
run_sut "specs/${pd_candidate_num}_candidate" --session sess_pd --phase implement --task-type general \
  --agent general-implementation-agent --loop-guard-file "specs/${pd_candidate_num}_candidate/.orchestrator-loop-guard" \
  --dispatch-seq 5 --dispatch-start-ts "$future_window" "$pd_candidate_num"

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "invariant (pending-dispatch): SUT exits 0"
else
  fail "invariant (pending-dispatch): SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
pd_guard_file="$WORKDIR/specs/${pd_candidate_num}_candidate/.orchestrator-loop-guard"
if jq -e '.pending_dispatch == null or has("pending_dispatch") == false' "$pd_guard_file" >/dev/null 2>&1; then
  pass "invariant (pending-dispatch): pending_dispatch was cleared from the durable loop-guard file"
else
  fail "invariant (pending-dispatch): pending_dispatch still present: $(cat "$pd_guard_file")"
fi
if [ "$(jq -r '.cycle_count' "$pd_guard_file" 2>/dev/null)" = "3" ]; then
  pass "invariant (pending-dispatch): every other loop-guard field (cycle_count) is preserved"
else
  fail "invariant (pending-dispatch): cycle_count was not preserved: $(cat "$pd_guard_file")"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ]
