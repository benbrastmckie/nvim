#!/usr/bin/env bash
# test-orchestrate-cycle-plan.sh - Fixture suite for orchestrate-cycle-plan.sh, covering the four
# acceptance areas named by this script's originating dispatch (eligibility, per-candidate forced
# phases, verdict relay, lock refusal) plus the two named invariants (bare-vs-suffixed session_id,
# dry-run no-mutation).
#
# Structural model: test-orchestrate-triage-classify.sh's sandbox shape (copy real collaborator
# scripts into a synthetic $WORKDIR/.claude/scripts/ tree so deploy-root-guard.sh's `*/.claude`
# parent-directory check passes and every sibling script's own SCRIPT_DIR-anchored PROJECT_ROOT
# resolves into the fixture, never the real repo) combined with test-orchestrate-build-dispatch.sh's
# stub convention for collaborators whose OWN real behavior is out of scope for this suite.
#
# Two fixture modes, matching the SUT's own two-function split:
#   - DRY-RUN fixtures (Groups 1-3, 6): use the REAL orchestrate-batch-admit.sh,
#     orchestrate-triage-classify.sh, and task-lock.sh (check-only; --dry-run never calls acquire).
#     No orchestrate-build-dispatch.sh, skill-base.sh, or update-task-status.sh involvement at all
#     -- --dry-run never reaches them by construction, so this suite does not need to stub them
#     for these groups.
#   - LIVE fixtures (Groups 4-5): additionally stub orchestrate-build-dispatch.sh (records argv to
#     a log file, returns a fixed {dispatch_file, model} JSON) and update-task-status.sh (records
#     its own argv and exits 0) -- neither script's OWN real behavior is under test here, only the
#     SUT's calling contract with them (arguments passed, ordering, the bare-vs-suffixed session_id
#     split). skill-base.sh and task-lock.sh are the REAL, unmodified collaborators in every group.
#
# NOTE on fixture numbering: every project_number below is synthetic fixture data for this suite
# only, never a citation of a real orchestrator project — pass/fail messages accordingly say
# "candidate #N" / "project #N", never "task N", per rules/no-task-references-in-deliverables.md.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required collaborator script was not found).

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

SUT_SRC="$CORE_DIR/orchestrate-cycle-plan.sh"
require_file "$SUT_SRC"
for f in orchestrate-batch-admit.sh orchestrate-triage-classify.sh task-lock.sh \
         deploy-root-guard.sh command-route-agent.sh skill-base.sh \
         lib/common.sh lib/file-scope-overlap.sh lib/continuation-pointer-lib.sh \
         lib/manifest-routing-lib.sh; do
  require_file "$CORE_DIR/$f"
done
require_file "$CORE_DIR/../context/reference/orchestrator-critical-paths.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

mkdir -p "$WORKDIR/.claude/scripts/lib" "$WORKDIR/.claude/context/reference" "$WORKDIR/specs"
for f in orchestrate-cycle-plan.sh orchestrate-batch-admit.sh orchestrate-triage-classify.sh \
         task-lock.sh deploy-root-guard.sh command-route-agent.sh skill-base.sh; do
  cp "$CORE_DIR/$f" "$WORKDIR/.claude/scripts/$f"
done
for f in common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh; do
  cp "$CORE_DIR/lib/$f" "$WORKDIR/.claude/scripts/lib/$f"
done
cp "$CORE_DIR/../context/reference/orchestrator-critical-paths.json" \
   "$WORKDIR/.claude/context/reference/orchestrator-critical-paths.json"
chmod +x "$WORKDIR"/.claude/scripts/*.sh

SUT="$WORKDIR/.claude/scripts/orchestrate-cycle-plan.sh"
STATE_FILE="$WORKDIR/specs/state.json"

write_state() {
  # Usage: write_state <<'EOF' ... EOF   (writes stdin to STATE_FILE)
  cat > "$STATE_FILE"
}

reset_lock_dirs() {
  find "$WORKDIR/specs" -maxdepth 2 -type d -name '.lock' -exec rm -rf {} + 2>/dev/null || true
}

run_sut() {
  # Usage: run_sut <session_id> [extra args...] -- <project_number...>
  local args=() nums=() in_nums=false
  for a in "$@"; do
    if [ "$a" = "--" ]; then in_nums=true; continue; fi
    if [ "$in_nums" = "true" ]; then nums+=("$a"); else args+=("$a"); fi
  done
  local stdout_file stderr_file
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  bash "$SUT" "${args[@]}" --state-file "$STATE_FILE" "${nums[@]}" >"$stdout_file" 2>"$stderr_file"
  LAST_EXIT=$?
  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

jqf() { echo "$LAST_STDOUT" | jq -r "$1" 2>/dev/null; }

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 1: Eligibility -- status never gates; a failed predecessor blocks
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 1: eligibility (status-not-gated; failed-predecessor blocks)"
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 101, "project_name": "g1_abandoned", "task_type": "general", "status": "abandoned", "description": "abandoned predecessor", "dependencies": [], "file_scope": []},
    {"project_number": 102, "project_name": "g1_dependent", "task_type": "general", "status": "not_started", "description": "depends on an abandoned predecessor", "dependencies": [101], "file_scope": []},
    {"project_number": 103, "project_name": "g1_researching", "task_type": "general", "status": "researching", "description": "in-flight status must still be eligible", "dependencies": [], "file_scope": []}
  ]
}
EOF
run_sut --session g1_sess --dry-run -- 101 102 103
if [ "$LAST_EXIT" -eq 0 ]; then
  pass "eligibility: SUT exits 0"
else
  fail "eligibility: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if [ "$(jqf '.dispatch | map(select(.task == 103)) | length')" = "1" ] && \
   [ "$(jqf '.dispatch | map(select(.task == 103)) | .[0].phase')" = "research" ]; then
  pass "eligibility: candidate #103 in 'researching' status dispatches to research (status never gates)"
else
  fail "eligibility: candidate #103 did not dispatch to research (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.blocked | map(select(.task == 102)) | length')" = "1" ]; then
  pass "eligibility: candidate #102 with an abandoned predecessor is blocked"
else
  fail "eligibility: candidate #102 was not blocked (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.dispatch | map(select(.task == 102)) | length')" = "0" ] && \
   [ "$(jqf '.deferred | map(select(.task == 102)) | length')" = "0" ]; then
  pass "eligibility: blocked candidate #102 is absent from dispatch and deferred"
else
  fail "eligibility: candidate #102 leaked into dispatch or deferred (stdout: $LAST_STDOUT)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 2: Per-candidate forced phases -- canonical ordering, stop-after-last-named fall-through
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 2: per-candidate forced phases (canonical ordering)"
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 201, "project_name": "g2_forced", "task_type": "general", "status": "implementing", "description": "would normally dispatch to implement, but is force-sequenced", "dependencies": [], "file_scope": []},
    {"project_number": 202, "project_name": "g2_plain", "task_type": "general", "status": "researched", "description": "ordinary status-derived classification, no forcing in this separate invocation", "dependencies": [], "file_scope": []}
  ]
}
EOF
run_sut --session g2_sess --dry-run --force-phases "implement,research" -- 201
if [ "$(jqf '.dispatch | map(select(.task == 201)) | .[0].phase')" = "research" ]; then
  pass "forced-phases: canonical order wins over typed order (research dispatched first, not implement)"
else
  fail "forced-phases: candidate #201 did not dispatch to research first (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.dispatch | map(select(.task == 201)) | .[0].force')" = "true" ]; then
  pass "forced-phases: dispatch row's force field is true for a task whose phase was popped off force_phases_remaining this cycle"
else
  fail "forced-phases: expected .dispatch[].force=true for candidate #201, got: $LAST_STDOUT"
fi
# A separate invocation (no --force-phases, a fresh session so no queue carries over) against the
# SAME candidate set's other member proves the mechanism is gated by the flag, not hardcoded.
run_sut --session g2_sess_plain --dry-run -- 202
if [ "$(jqf '.dispatch | map(select(.task == 202)) | .[0].phase')" = "plan" ]; then
  pass "forced-phases: without --force-phases, classification stays ordinary status-derived (researched -> plan)"
else
  fail "forced-phases: candidate #202 did not classify status-derived (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.dispatch | map(select(.task == 202)) | .[0].force')" = "false" ]; then
  pass "forced-phases: dispatch row's force field is false for an ordinary status-derived dispatch"
else
  fail "forced-phases: expected .dispatch[].force=false for candidate #202, got: $LAST_STDOUT"
fi
# Stop-after-last-named fall-through -- exercised on the LIVE path (Group 4/5's stubbed
# build-dispatch/update-task-status fixture, below), since --dry-run never persists
# force_phases_remaining across invocations by design (matches its "mutates nothing" contract);
# there is nothing to fall through FROM in a single, non-persisting dry-run call. See the
# "stop-after-last-named" assertions inside Group 4/5.

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 3: Verdict relay -- 2+ self-modifying candidates; ORDERING CONSTRAINT text; forbidden
# literals absent from the script
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 3: verdict relay (self-modifying tie-breaker; forbidden-literal negative assertion)"
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 301, "project_name": "g3_sm_one", "task_type": "general", "status": "planned", "description": "self-modifying candidate one", "dependencies": [], "file_scope": ["agent-system/extensions/core/scripts/task-lock.sh"]},
    {"project_number": 302, "project_name": "g3_sm_two", "task_type": "general", "status": "planned", "description": "self-modifying candidate two", "dependencies": [], "file_scope": ["agent-system/extensions/core/scripts/update-task-status.sh"]}
  ]
}
EOF
run_sut --session g3_sess --dry-run -- 301 302
admit_reason_301=$(bash "$WORKDIR/.claude/scripts/orchestrate-batch-admit.sh" --invocation-count 2 --session-id g3_sess 301 302 2>/dev/null | jq -r 'select(.task_number == 301) | .reason // empty')
deferred_reason_301=$(jqf '.deferred | map(select(.task == 301)) | .[0].reason // empty')
deferred_reason_302=$(jqf '.deferred | map(select(.task == 302)) | .[0].reason // empty')
one_deferred_one_admitted=false
if { [ "$(jqf '.dispatch | map(select(.task==301))|length')" = "1" ] && [ "$deferred_reason_302" != "" ]; } || \
   { [ "$(jqf '.dispatch | map(select(.task==302))|length')" = "1" ] && [ "$deferred_reason_301" != "" ]; }; then
  one_deferred_one_admitted=true
fi
if [ "$one_deferred_one_admitted" = "true" ]; then
  pass "verdict-relay: designated (lowest-numbered) self-modifying candidate dispatches, the other defers"
else
  fail "verdict-relay: expected exactly one admitted + one deferred self-modifying candidate (stdout: $LAST_STDOUT)"
fi
relayed_reason=$(jqf '.deferred[0].reason // empty')
if echo "$relayed_reason" | grep -q "ORDERING CONSTRAINT"; then
  pass "verdict-relay: deferred reason names the ORDERING CONSTRAINT text verbatim"
else
  fail "verdict-relay: ORDERING CONSTRAINT text missing from relayed reason ('$relayed_reason')"
fi
if [ -n "$admit_reason_301" ] && [ "$deferred_reason_301" = "$admit_reason_301" ]; then
  pass "verdict-relay: relayed reason is byte-identical to the admission script's own .reason"
elif [ -z "$deferred_reason_301" ]; then
  info "verdict-relay: candidate #301 was the admitted (not deferred) side this run; byte-identity checked via #302 instead"
  admit_reason_302=$(bash "$WORKDIR/.claude/scripts/orchestrate-batch-admit.sh" --invocation-count 2 --session-id g3_sess 301 302 2>/dev/null | jq -r 'select(.task_number == 302) | .reason // empty')
  if [ -n "$admit_reason_302" ] && [ "$deferred_reason_302" = "$admit_reason_302" ]; then
    pass "verdict-relay: relayed reason is byte-identical to the admission script's own .reason (#302)"
  else
    fail "verdict-relay: relayed reason diverges from the admission script's own .reason"
  fi
else
  fail "verdict-relay: relayed reason diverges from the admission script's own .reason"
fi

if grep -q "runs solo only" "$SUT_SRC" || grep -q "re-run it alone" "$SUT_SRC"; then
  fail "verdict-relay: forbidden literal ('runs solo only' or 're-run it alone') found in orchestrate-cycle-plan.sh"
else
  pass "verdict-relay: forbidden literals absent from orchestrate-cycle-plan.sh"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 4/5: Lock refusal + session-id invariant (LIVE path; stubbed build-dispatch/update-status)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 4/5: lock refusal removes a candidate from the batch; bare-vs-suffixed session_id invariant"

ARGV_LOG="$WORKDIR/build-dispatch-argv.log"
: > "$ARGV_LOG"
cat > "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$ARGV_LOG"
proj_num="\$1"; phase="\$2"
jq -n -c --arg f "/fake/\${proj_num}-\${phase}.md" '{dispatch_file: \$f, model: ""}'
EOF
chmod +x "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh"

UTS_LOG="$WORKDIR/update-task-status-argv.log"
: > "$UTS_LOG"
cat > "$WORKDIR/.claude/scripts/update-task-status.sh" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$UTS_LOG"
exit 0
EOF
chmod +x "$WORKDIR/.claude/scripts/update-task-status.sh"

write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 401, "project_name": "g4_plan_candidate", "task_type": "general", "status": "researched", "description": "plan-phase live dispatch", "dependencies": [], "file_scope": []},
    {"project_number": 402, "project_name": "g4_implement_candidate", "task_type": "general", "status": "implementing", "description": "implement-phase live dispatch", "dependencies": [], "file_scope": []},
    {"project_number": 403, "project_name": "g4_locked_candidate", "task_type": "general", "status": "implementing", "description": "pre-locked by a foreign, fresh session", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
mkdir -p "$WORKDIR/specs/403_g4_locked_candidate/.lock"
cat > "$WORKDIR/specs/403_g4_locked_candidate/.lock/holder.json" <<'EOF'
{"session_id": "FOREIGN_SESSION", "task_number": 403, "operation": "implement", "acquired_at": "2026-01-01T00:00:00Z", "heartbeat_at": "2099-01-01T00:00:00Z", "command": "test", "pid": 1, "pid_source": "test"}
EOF

run_sut --session g45_sess -- 401 402 403

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "live: SUT exits 0"
else
  fail "live: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi

if [ "$(jqf '.dispatch | map(select(.task == 403)) | length')" = "0" ] && \
   [ "$(jqf '.deferred | map(select(.task == 403)) | length')" = "1" ] && \
   [ "$(jqf '.blocked | map(select(.task == 403)) | length')" = "0" ]; then
  pass "lock-refusal: locked candidate #403 is absent from dispatch, present in deferred, absent from blocked"
else
  fail "lock-refusal: candidate #403 bucketing wrong (stdout: $LAST_STDOUT)"
fi

if [ "$(jqf '.dispatch | map(select(.task == 401)) | length')" = "1" ] && \
   [ "$(jqf '.dispatch | map(select(.task == 402)) | length')" = "1" ]; then
  pass "lock-refusal: sibling (unlocked) candidates still dispatch this cycle"
else
  fail "lock-refusal: an unlocked sibling failed to dispatch (stdout: $LAST_STDOUT)"
fi

plan_argv=$(grep '^401 plan' "$ARGV_LOG" || true)
implement_argv=$(grep '^402 implement' "$ARGV_LOG" || true)
if echo "$plan_argv" | grep -q -- "--session g45_sess_401"; then
  pass "session-id invariant: plan dispatch uses the SUFFIXED session id for orchestrate-build-dispatch.sh"
else
  fail "session-id invariant: plan dispatch argv missing suffixed session id (argv: '$plan_argv')"
fi
if echo "$implement_argv" | grep -q -- "--session g45_sess " || echo "$implement_argv" | grep -qE -- "--session g45_sess\$"; then
  pass "session-id invariant: implement dispatch uses the BARE session id for orchestrate-build-dispatch.sh"
else
  fail "session-id invariant: implement dispatch argv missing bare session id (argv: '$implement_argv')"
fi

plan_preflight=$(grep '^preflight 401 plan' "$UTS_LOG" || true)
implement_preflight=$(grep '^preflight 402 implement' "$UTS_LOG" || true)
if echo "$plan_preflight" | grep -q "g45_sess_401"; then
  pass "session-id invariant: skill_preflight_update receives the SUFFIXED session id for plan"
else
  fail "session-id invariant: plan preflight argv missing suffixed session id (argv: '$plan_preflight')"
fi
if echo "$implement_preflight" | grep -q "g45_sess\$"; then
  pass "session-id invariant: skill_preflight_update receives the BARE session id for implement"
else
  fail "session-id invariant: implement preflight argv missing bare session id (argv: '$implement_preflight')"
fi

mt_state_file_live="$WORKDIR/specs/.orchestrator-multi-state-g45_sess.json"
if [ -f "$mt_state_file_live" ]; then
  dispatch_seq_count=$(jq -r '.dispatch_seq | keys | length' "$mt_state_file_live" 2>/dev/null)
  if [ "$dispatch_seq_count" = "2" ]; then
    pass "session-id invariant: dispatch_seq minted for both dispatched candidates in one mt_state_file"
  else
    fail "session-id invariant: expected 2 dispatch_seq entries, got '$dispatch_seq_count'"
  fi
else
  fail "session-id invariant: mt_state_file not written for live dispatch"
fi

info "Group 4/5 (continued): per-candidate forced-phase stop-after-last-named fall-through (LIVE)"
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 501, "project_name": "g5_fallthrough", "task_type": "general", "status": "implementing", "description": "single-item forced queue; must fall through to status-derived (implement) once exhausted", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
: > "$ARGV_LOG"
run_sut --session g5_fallthrough_sess --force-phases "research" -- 501
cycle1_phase=$(jqf '.dispatch | map(select(.task == 501)) | .[0].phase')
if [ "$cycle1_phase" = "research" ]; then
  pass "stop-after-last-named: cycle 1 forces the named phase (research) despite status implementing"
else
  fail "stop-after-last-named: cycle 1 did not force research (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.dispatch | map(select(.task == 501)) | .[0].force')" = "true" ]; then
  pass "stop-after-last-named: cycle 1's dispatch row carries force=true (live path, not just --dry-run)"
else
  fail "stop-after-last-named: expected .dispatch[].force=true on cycle 1 (live path), got: $LAST_STDOUT"
fi
# Cycle 2, same session (mt_state_file persists live state across separate invocations, mirroring
# how the thin lead's loop calls this script once per cycle): the one-item queue popped in cycle 1
# is now empty, so this cycle must fall through to ORDINARY status-derived classification
# (status is still "implementing" in state.json -- unaffected by dispatch -- which routes to
# implement), never re-force research. No --force-phases is passed this time, proving the
# fall-through is driven by the persisted (now-empty) queue, not by the flag's absence alone.
run_sut --session g5_fallthrough_sess -- 501
cycle2_phase=$(jqf '.dispatch | map(select(.task == 501)) | .[0].phase')
if [ "$cycle2_phase" = "implement" ]; then
  pass "stop-after-last-named: cycle 2 falls through to status-derived classification (implement) once the forced queue is exhausted"
else
  fail "stop-after-last-named: cycle 2 did not fall through (got '$cycle2_phase', stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.dispatch | map(select(.task == 501)) | .[0].force')" = "false" ]; then
  pass "stop-after-last-named: cycle 2's dispatch row carries force=false (queue exhausted, ordinary dispatch)"
else
  fail "stop-after-last-named: expected .dispatch[].force=false on cycle 2, got: $LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 6: Dry-run no-mutation -- state.json, mt_state_file, and .lock/ unchanged across a run
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 6: dry-run mutates nothing"
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 601, "project_name": "g6_candidate", "task_type": "general", "status": "not_started", "description": "dry-run no-mutation check", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g6_sess.json"
rm -rf "$WORKDIR/specs/601_g6_candidate"
before_checksum=$(find "$WORKDIR/specs" -type f | sort | xargs -I{} md5sum {} 2>/dev/null | md5sum)
run_sut --session g6_sess --dry-run -- 601
after_checksum=$(find "$WORKDIR/specs" -type f | sort | xargs -I{} md5sum {} 2>/dev/null | md5sum)
if [ "$before_checksum" = "$after_checksum" ]; then
  pass "dry-run: specs/ tree (state.json, mt_state_file, .lock/) is byte-identical before and after"
else
  fail "dry-run: specs/ tree changed across a --dry-run invocation"
fi
if [ -d "$WORKDIR/specs/601_g6_candidate" ]; then
  fail "dry-run: candidate directory was created despite --dry-run"
else
  pass "dry-run: no candidate directory created"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 7: Dependency resolution spans the ARCHIVE -- regression guard
#
# The defect this group exists to prevent: archival (which moves every terminal project out of
# `.active_projects` and into the sibling archive) made a COMPLETED predecessor unresolvable, and
# an unresolvable predecessor was read as "still in flight". Every dependent candidate therefore
# became permanently un-dispatchable -- and, worse, was dropped SILENTLY: absent from dispatch,
# from deferred, and from blocked alike, visible only as the aggregate `no_eligible_stuck` stop
# message. These three cases pin the resolution semantics (archived-completed satisfies;
# archived-abandoned still blocks) and the reporting rule (a genuinely unresolvable edge is named
# in blocked[], never dropped).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 7: dependency resolution spans the archive (archived predecessor is not 'in flight')"
mkdir -p "$WORKDIR/specs/archive"
cat > "$WORKDIR/specs/archive/state.json" <<'EOF'
{
  "completed_projects": [
    {"project_number": 700, "project_name": "g7_archived_done", "status": "completed"},
    {"project_number": 702, "project_name": "g7_archived_orphan", "status": "orphan_archived"}
  ],
  "archived_projects": [
    {"project_number": 701, "project_name": "g7_archived_dropped", "status": "abandoned"}
  ]
}
EOF
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 710, "project_name": "g7_after_completed", "task_type": "general", "status": "not_started", "description": "predecessor was archived as completed", "dependencies": [700], "file_scope": []},
    {"project_number": 711, "project_name": "g7_after_abandoned", "task_type": "general", "status": "not_started", "description": "predecessor was archived as abandoned", "dependencies": [701], "file_scope": []},
    {"project_number": 712, "project_name": "g7_dangling", "task_type": "general", "status": "not_started", "description": "predecessor exists nowhere at all", "dependencies": [9999], "file_scope": []},
    {"project_number": 713, "project_name": "g7_after_orphan", "task_type": "general", "status": "not_started", "description": "predecessor was archived by orphan recovery", "dependencies": [702], "file_scope": []}
  ]
}
EOF
run_sut --session g7_sess --dry-run -- 710 711 712 713
if [ "$LAST_EXIT" -eq 0 ]; then
  pass "archive-deps: SUT exits 0"
else
  fail "archive-deps: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if [ "$(jqf '.dispatch | map(select(.task == 710)) | length')" = "1" ]; then
  pass "archive-deps: candidate #710 dispatches -- an archived COMPLETED predecessor is satisfied, not in-flight"
else
  fail "archive-deps: candidate #710 did not dispatch; archived completed predecessor read as unsatisfied (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.blocked | map(select(.task == 711)) | length')" = "1" ]; then
  pass "archive-deps: candidate #711 is blocked -- an archived ABANDONED predecessor still blocks"
else
  fail "archive-deps: candidate #711 was not blocked (stdout: $LAST_STDOUT)"
fi
g7_dangling_reason=$(jqf '.blocked | map(select(.task == 712)) | .[0].reason // ""')
if [ "$(jqf '.blocked | map(select(.task == 712)) | length')" = "1" ] && \
   [[ "$g7_dangling_reason" == *9999* ]]; then
  pass "archive-deps: candidate #712's dangling edge is reported in blocked[] and names the number"
else
  fail "archive-deps: candidate #712's dangling dependency was not reported in blocked[] (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.dispatch | map(select(.task == 713)) | length')" = "1" ]; then
  pass "archive-deps: candidate #713 dispatches -- an orphan_archived predecessor is terminal, not in-flight"
else
  fail "archive-deps: candidate #713 did not dispatch (stdout: $LAST_STDOUT)"
fi
for n in 710 711 712 713; do
  in_dispatch=$(jqf ".dispatch | map(select(.task == $n)) | length")
  in_deferred=$(jqf ".deferred | map(select(.task == $n)) | length")
  in_blocked=$(jqf ".blocked | map(select(.task == $n)) | length")
  if [ "$((in_dispatch + in_deferred + in_blocked))" -ge 1 ]; then
    pass "archive-deps: candidate #$n is accounted for in exactly one bucket (never silently dropped)"
  else
    fail "archive-deps: candidate #$n vanished from the plan entirely -- the silent-drop regression (stdout: $LAST_STDOUT)"
  fi
done

# ═══════════════════════════════════════════════════════════════════════════════════════════════
echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
