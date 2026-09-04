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
         deploy-root-guard.sh command-route-agent.sh skill-base.sh system-defect-record.sh \
         state-write.sh generate-todo.sh update-task-status.sh git-commit-scoped.sh \
         errors-append.sh events-append.sh; do
  require_file "$CORE_DIR/$f"
done
for f in common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh \
         phase-heading-patterns.sh status-vocabulary.sh; do
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
           deploy-root-guard.sh command-route-agent.sh skill-base.sh system-defect-record.sh \
           state-write.sh generate-todo.sh update-task-status.sh git-commit-scoped.sh \
           errors-append.sh events-append.sh; do
    cp "$CORE_DIR/$f" "$WORKDIR/.claude/scripts/$f"
  done
  for f in common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh \
           phase-heading-patterns.sh status-vocabulary.sh; do
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

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ]
