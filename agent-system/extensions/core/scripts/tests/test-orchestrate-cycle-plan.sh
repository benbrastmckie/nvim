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
         orchestrate-loop-guard-init.sh orchestrate-build-aux-dispatch.sh \
         deploy-root-guard.sh command-route-agent.sh skill-base.sh \
         lib/common.sh lib/file-scope-overlap.sh lib/continuation-pointer-lib.sh \
         lib/manifest-routing-lib.sh lib/phase-heading-patterns.sh lib/deploy-baseline-lib.sh \
         lib/task-lookup-lib.sh lib/deploy-ledger-lib.sh; do
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
         task-lock.sh orchestrate-loop-guard-init.sh orchestrate-build-aux-dispatch.sh \
         deploy-root-guard.sh command-route-agent.sh skill-base.sh; do
  cp "$CORE_DIR/$f" "$WORKDIR/.claude/scripts/$f"
done
for f in common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh \
         phase-heading-patterns.sh deploy-baseline-lib.sh task-lookup-lib.sh deploy-ledger-lib.sh; do
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
# Stop-after-the-last-forced-phase (Phase 3 fix; this task no longer "falls through" once its
# queue empties) is exercised on the LIVE path (Group 4/5's stubbed build-dispatch/
# update-task-status fixture, below), since --dry-run never persists force_phases_remaining or
# forced_round_seeded across invocations by design (matches its "mutates nothing" contract);
# there is nothing to stop-after FROM in a single, non-persisting dry-run call. See the
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

info "Group 4/5 (continued): per-candidate forced-phase stop-after-last-named (LIVE)"
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 501, "project_name": "g5_fallthrough", "task_type": "general", "status": "implementing", "description": "single-item forced queue; must STOP (never fall through to status-derived implement) once exhausted", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
: > "$ARGV_LOG"
# --no-plan-cache on both calls below: this group's own domain is force_phases_remaining
# fall-through across two LIVE cycles of the SAME session with no simulated postflight/consumption
# in between (see the plan-cache-aware comment ahead of the cycle-2 call). Left plan-cache-enabled,
# cycle 2 would legitimately replay cycle 1's still-unconsumed cached plan (same forced-research
# row) rather than recompute -- correct behavior for the plan cache, but not what THIS group tests.
run_sut --session g5_fallthrough_sess --no-plan-cache --force-phases "research" -- 501
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
# is now empty AND this run itself seeded it (forced_round_seeded[501]=true) -- Phase 3's fix
# means this task is now excluded, terminal for the REST OF THIS RUN: zero dispatch rows, one
# blocked[] row carrying the "forced round complete" reason, status unchanged, cycle_counts
# unchanged. This inverts the OLD (defective) expectation that cycle 2 would fall through to
# ORDINARY status-derived classification (implement) -- it must NOT any more. No --force-phases
# is passed this time, proving the exclusion is driven by the persisted forced_round_seeded
# marker, not by the flag's absence alone.
g5_mt_state="$WORKDIR/specs/.orchestrator-multi-state-g5_fallthrough_sess.json"
g5_status_before=$(jq -r '.active_projects[] | select(.project_number == 501) | .status' "$STATE_FILE")
g5_cycle_before=$(jq -r --arg t "501" '.cycle_counts[$t] // 0' "$g5_mt_state" 2>/dev/null)
run_sut --session g5_fallthrough_sess --no-plan-cache -- 501
g5_status_after=$(jq -r '.active_projects[] | select(.project_number == 501) | .status' "$STATE_FILE")
g5_cycle_after=$(jq -r --arg t "501" '.cycle_counts[$t] // 0' "$g5_mt_state" 2>/dev/null)
if [ "$(jqf '.dispatch | map(select(.task == 501)) | length')" = "0" ]; then
  pass "stop-after-last-named: cycle 2 dispatches nothing once the forced queue this run seeded is exhausted (stop, not fall-through)"
else
  fail "stop-after-last-named: expected zero dispatch rows for candidate #501 on cycle 2, got: $LAST_STDOUT"
fi
if [ "$(jqf '.blocked | map(select(.task == 501 and (.reason | contains("forced round complete")))) | length')" = "1" ]; then
  pass "stop-after-last-named: cycle 2 emits exactly one blocked[] row carrying the forced-round-complete reason"
else
  fail "stop-after-last-named: expected one blocked[] row with the forced-round-complete reason, got: $LAST_STDOUT"
fi
if [ "$g5_status_before" = "$g5_status_after" ]; then
  pass "stop-after-last-named: status unchanged across the exclusion cycle ($g5_status_after)"
else
  fail "stop-after-last-named: status changed -- before='$g5_status_before' after='$g5_status_after'"
fi
if [ "$g5_cycle_before" = "$g5_cycle_after" ]; then
  pass "stop-after-last-named: cycle_counts unchanged across the exclusion cycle ($g5_cycle_after)"
else
  fail "stop-after-last-named: cycle_counts changed -- before='$g5_cycle_before' after='$g5_cycle_after'"
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
# Group 8: Decision (a) — per-RUN cycle budget (resets every /orchestrate run; NOT seeded from
# the durable guard file's cycle_count any more), mode-aware max_cycles WITHIN one run, six
# forced runs in a row never refused for budget, and dispatch_seq durability across runs.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 8: per-RUN cycle budget"

# ── A fresh session starts cycle_counts at 0 regardless of the durable guard file's cycle_count
# -- the inverted core assertion (was: "resumes the prior cycle_count", now: "never seeded from
# it at all"). Pre-seed the durable guard file at cycle_count=5 (would have exhausted the OLD
# cross-invocation budget outright) and confirm a fresh session still dispatches normally.
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 801, "project_name": "g8_budget", "task_type": "general", "status": "implementing", "description": "budget candidate", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -rf "$WORKDIR/specs/801_g8_budget"
mkdir -p "$WORKDIR/specs/801_g8_budget"
jq -n '{cycle_count: 5}' > "$WORKDIR/specs/801_g8_budget/.orchestrator-loop-guard"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g8_sess_a.json"

run_sut --session g8_sess_a -- 801
if [ "$(jqf '.dispatch | map(select(.task == 801)) | length')" = "1" ]; then
  pass "budget: a fresh session dispatches normally despite the durable guard's cycle_count=5 (never seeded from it)"
else
  fail "budget: a fresh session was blocked despite starting at cycle_counts=0 (stdout: $LAST_STDOUT)"
fi
g8a_mt_state="$WORKDIR/specs/.orchestrator-multi-state-g8_sess_a.json"
if [ "$(jq -r --arg t "801" '.cycle_counts[$t] // 0' "$g8a_mt_state" 2>/dev/null)" = "1" ]; then
  pass "budget: in-session cycle_counts[801] is 1 after one dispatch this run (not 6)"
else
  fail "budget: cycle_counts[801] is not 1 after one dispatch (got: $(jq -c '.cycle_counts' "$g8a_mt_state" 2>/dev/null))"
fi
if [ "$(jq -r '.cycle_count // "absent"' "$WORKDIR/specs/801_g8_budget/.orchestrator-loop-guard")" = "5" ]; then
  pass "budget: the durable guard's own cycle_count is left untouched (inert historical data, never flushed by this engine any more)"
else
  fail "budget: the durable guard's cycle_count was unexpectedly modified (got: $(cat "$WORKDIR/specs/801_g8_budget/.orchestrator-loop-guard"))"
fi

# ── Mode-aware max_cycles bound WITHIN one run: base mode's 5 vs. hard mode's 13. Pre-seed the
# SESSION's own (in-session) cycle_counts directly rather than looping real dispatches -- this
# asserts the per-run bound's arithmetic against max_cycles_per_task, not the mechanics of
# reaching it, which Group 4/5 and elsewhere already exercise via real dispatch charges.
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 802, "project_name": "g8_mode_aware", "task_type": "general", "status": "implementing", "description": "mode-aware max_cycles candidate", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g8_mode_base.json" "$WORKDIR/specs/.orchestrator-multi-state-g8_mode_hard.json"
jq -n --arg t "802" '{cycle_counts: {($t): 5}}' > "$WORKDIR/specs/.orchestrator-multi-state-g8_mode_base.json"
jq -n --arg t "802" '{cycle_counts: {($t): 5}}' > "$WORKDIR/specs/.orchestrator-multi-state-g8_mode_hard.json"

run_sut --session g8_mode_base -- 802
if [ "$(jqf '.blocked | map(select(.task == 802)) | length')" = "1" ] && \
   [[ "$(jqf '.blocked | map(select(.task == 802)) | .[0].reason')" == *MAX_CYCLES* ]]; then
  pass "budget: base mode (max_cycles=5) blocks a candidate already at cycle_counts=5 THIS run"
else
  fail "budget: base-mode candidate at cycle_counts=5 was not blocked for MAX_CYCLES (stdout: $LAST_STDOUT)"
fi

run_sut --session g8_mode_hard --hard -- 802
if [ "$(jqf '.dispatch | map(select(.task == 802)) | length')" = "1" ]; then
  pass "budget: hard mode (max_cycles=13) dispatches the SAME candidate at cycle_counts=5 THIS run"
else
  fail "budget: hard-mode candidate at cycle_counts=5 did not dispatch (stdout: $LAST_STDOUT)"
fi

# ── Batch-of-one budget-exhaustion stop, WITHIN one run (--dry-run never persists, so this
# reflects the bound purely from a pre-seeded in-session cycle_counts value).
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 803, "project_name": "g8_exhausted", "task_type": "general", "status": "implementing", "description": "exhausted budget candidate", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g8_exhausted_sess.json"
jq -n --arg t "803" '{cycle_counts: {($t): 5}}' > "$WORKDIR/specs/.orchestrator-multi-state-g8_exhausted_sess.json"

run_sut --session g8_exhausted_sess -- 803
if [ "$(jqf '.stop.reason')" = "max_cycles" ]; then
  pass "budget: a batch-of-one whose only task is budget-exhausted THIS run stops with reason=max_cycles"
else
  fail "budget: batch-of-one exhaustion did not stop with reason=max_cycles (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.dispatch | length')" = "0" ]; then
  pass "budget: exhausted batch-of-one dispatches nothing"
else
  fail "budget: exhausted batch-of-one unexpectedly dispatched (stdout: $LAST_STDOUT)"
fi
if [[ "$(jqf '.stop.message')" != *continue-budget* ]] && [[ "$(jqf '.stop.message')" == *re-invoke* ]]; then
  pass "budget: the stop message names re-invoking /orchestrate, not the withdrawn --continue-budget flag"
else
  fail "budget: the stop message still references --continue-budget, or does not name re-invocation (got: $(jqf '.stop.message'))"
fi

# ── --continue-budget is withdrawn end to end: it is now an ordinary unrecognized flag.
run_sut --session g8_withdrawn_sess --continue-budget -- 803
if [ "$LAST_EXIT" -eq 2 ] && echo "$LAST_STDERR" | grep -q 'unrecognized flag'; then
  pass "budget: --continue-budget is withdrawn -- rejected as an unrecognized flag (exit 2)"
else
  fail "budget: --continue-budget was not rejected as unrecognized (exit $LAST_EXIT, stderr: $LAST_STDERR)"
fi

# ── Mixed batch: one task's budget exhaustion (THIS run) excludes only that task, never the
# whole batch.
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 804, "project_name": "g8_mixed_exhausted", "task_type": "general", "status": "implementing", "description": "exhausted sibling", "dependencies": [], "file_scope": []},
    {"project_number": 805, "project_name": "g8_mixed_fresh", "task_type": "general", "status": "implementing", "description": "fresh sibling", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g8_mixed_sess.json"
jq -n --arg t "804" '{cycle_counts: {($t): 5}}' > "$WORKDIR/specs/.orchestrator-multi-state-g8_mixed_sess.json"

run_sut --session g8_mixed_sess -- 804 805
if [ "$(jqf '.blocked | map(select(.task == 804)) | length')" = "1" ] && \
   [[ "$(jqf '.blocked | map(select(.task == 804)) | .[0].reason')" == *MAX_CYCLES* ]]; then
  pass "budget: mixed batch blocks only the exhausted sibling (#804), never the whole batch"
else
  fail "budget: mixed batch did not block only the exhausted sibling (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.dispatch | map(select(.task == 805)) | length')" = "1" ] && [ "$(jqf '.stop')" = "null" ]; then
  pass "budget: mixed batch's fresh sibling (#805) still dispatches this cycle; no whole-batch stop"
else
  fail "budget: mixed batch's fresh sibling failed to dispatch or the batch stopped (stdout: $LAST_STDOUT)"
fi

# ── Six forced runs in a row (separate sessions) on ONE task are never refused for budget --
# each run's cycle_counts starts fresh at 0, so no cross-run accumulation can ever reach
# max_cycles_per_task regardless of how many runs have already happened.
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 806, "project_name": "g8_six_runs", "task_type": "general", "status": "not_started", "description": "six-forced-runs-in-a-row candidate", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
six_runs_ok=true
for i in 1 2 3 4 5 6; do
  if [ "$i" -gt 1 ]; then
    bash "$WORKDIR/.claude/scripts/task-lock.sh" release 806 "g8_six_run_$((i - 1))" >/dev/null 2>&1 || true
  fi
  rm -f "$WORKDIR/specs/.orchestrator-multi-state-g8_six_run_${i}.json"
  run_sut --session "g8_six_run_${i}" --force-phases research -- 806
  if [ "$(jqf '.dispatch | map(select(.task == 806)) | length')" != "1" ]; then
    six_runs_ok=false
    info "six-forced-runs: run $i did not dispatch (stdout: $LAST_STDOUT)"
  fi
  if [ "$(jqf '.blocked | map(select(.task == 806 and (.reason | test("MAX_CYCLES")))) | length')" != "0" ]; then
    six_runs_ok=false
    info "six-forced-runs: run $i was refused for MAX_CYCLES (stdout: $LAST_STDOUT)"
  fi
done
if [ "$six_runs_ok" = "true" ]; then
  pass "budget: six forced runs in a row (separate sessions) on one task are never refused for budget"
else
  fail "budget: at least one of six forced runs in a row was refused for budget (see INFO lines above)"
fi

# ── dispatch_seq never repeats across runs: two separate sessions dispatching the SAME task in
# succession must mint strictly increasing seq values, durably, even though cycle_counts itself
# resets every run.
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 807, "project_name": "g8_seq_no_repeat", "task_type": "general", "status": "implementing", "description": "dispatch_seq durability candidate", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -rf "$WORKDIR/specs/807_g8_seq_no_repeat"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g8_seq_run1.json" "$WORKDIR/specs/.orchestrator-multi-state-g8_seq_run2.json"

run_sut --session g8_seq_run1 -- 807
g8_durable_seq_after_run1=$(jq -r '.dispatch_seq_counter // 0' "$WORKDIR/specs/807_g8_seq_no_repeat/.orchestrator-loop-guard" 2>/dev/null)
bash "$WORKDIR/.claude/scripts/task-lock.sh" release 807 g8_seq_run1 >/dev/null 2>&1 || true

run_sut --session g8_seq_run2 -- 807
g8_durable_seq_after_run2=$(jq -r '.dispatch_seq_counter // 0' "$WORKDIR/specs/807_g8_seq_no_repeat/.orchestrator-loop-guard" 2>/dev/null)
if [ -n "$g8_durable_seq_after_run1" ] && [ -n "$g8_durable_seq_after_run2" ] && \
   [ "$g8_durable_seq_after_run2" -gt "$g8_durable_seq_after_run1" ]; then
  pass "budget: dispatch_seq_counter is durable and strictly increases across two separate runs on the same task ($g8_durable_seq_after_run1 -> $g8_durable_seq_after_run2)"
else
  fail "budget: dispatch_seq_counter did not durably increase across runs (run1=$g8_durable_seq_after_run1, run2=$g8_durable_seq_after_run2)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 9: H1 hard-mode per-phase dispatch (heading-scan, conformance gate, marker crosscheck,
# territory, fixed-agent-never fallthrough)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 9: H1 hard-mode per-phase dispatch"

# ── Case A: a non-conforming heading (3a-style) produces a blocked row, never a dispatch row ──
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 901, "project_name": "g9_nonconforming", "task_type": "general", "status": "implementing", "description": "H1 non-conforming heading", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
mkdir -p "$WORKDIR/specs/901_g9_nonconforming/plans"
cat > "$WORKDIR/specs/901_g9_nonconforming/plans/01_plan.md" <<'EOF'
# Plan

### Phase 1: One [COMPLETED]
### Phase 3a: Bad heading [NOT STARTED]
EOF
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g9a_sess.json"
: > "$ARGV_LOG"
run_sut --session g9a_sess --hard -- 901
if [ "$(jqf '.dispatch | map(select(.task == 901)) | length')" = "0" ] && \
   [ "$(jqf '.blocked | map(select(.task == 901)) | length')" = "1" ]; then
  pass "H1: a non-conforming heading blocks the candidate, never dispatches it"
else
  fail "H1: non-conforming-heading candidate not blocked as expected (stdout: $LAST_STDOUT)"
fi
if [[ "$(jqf '.blocked | map(select(.task == 901)) | .[0].reason')" == *"true next phase is UNKNOWN"* ]]; then
  pass "H1: blocked reason names the true-next-phase-UNKNOWN text"
else
  fail "H1: blocked reason missing the expected text (got: $(jqf '.blocked | map(select(.task == 901)) | .[0].reason'))"
fi

# ── Case B: marker/handoff mismatch -- blocked row AND the disputed heading downgrades to
# [PARTIAL] ──
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 902, "project_name": "g9_mismatch", "task_type": "general", "status": "implementing", "description": "H1 marker/handoff mismatch", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
mkdir -p "$WORKDIR/specs/902_g9_mismatch/plans"
cat > "$WORKDIR/specs/902_g9_mismatch/plans/01_plan.md" <<'EOF'
# Plan

### Phase 1: One [COMPLETED]
### Phase 2: Two [NOT STARTED]
EOF
cat > "$WORKDIR/specs/902_g9_mismatch/.orchestrator-handoff.json" <<'EOF'
{"status": "partial", "phases_completed": 0, "phases_total": 2}
EOF
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g9b_sess.json"
: > "$ARGV_LOG"
run_sut --session g9b_sess --hard -- 902
if [ "$(jqf '.dispatch | map(select(.task == 902)) | length')" = "0" ] && \
   [ "$(jqf '.blocked | map(select(.task == 902)) | length')" = "1" ]; then
  pass "H1: a marker/handoff mismatch blocks the candidate, never dispatches it"
else
  fail "H1: mismatch candidate not blocked as expected (stdout: $LAST_STDOUT)"
fi
if [[ "$(jqf '.blocked | map(select(.task == 902)) | .[0].reason')" == *"MARKER/HANDOFF MISMATCH"* ]]; then
  pass "H1: blocked reason names MARKER/HANDOFF MISMATCH"
else
  fail "H1: blocked reason missing MARKER/HANDOFF MISMATCH text"
fi
if grep -q '^### Phase 1: One \[PARTIAL\]$' "$WORKDIR/specs/902_g9_mismatch/plans/01_plan.md"; then
  pass "H1: the disputed phase heading is downgraded to [PARTIAL] in place"
else
  fail "H1: disputed heading was not downgraded (plan content: $(cat "$WORKDIR/specs/902_g9_mismatch/plans/01_plan.md"))"
fi

# ── Case C: a well-formed plan with an open heading dispatches WITH --phase-number/--territory ──
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 903, "project_name": "g9_dispatch", "task_type": "general", "status": "implementing", "description": "H1 successful phase selection", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
mkdir -p "$WORKDIR/specs/903_g9_dispatch/plans"
cat > "$WORKDIR/specs/903_g9_dispatch/plans/01_plan.md" <<'EOF'
# Plan

### Phase 1: One [COMPLETED]
### Phase 2: Two [NOT STARTED]
EOF
cat > "$WORKDIR/specs/903_g9_dispatch/.orchestrator-handoff.json" <<'EOF'
{"status": "partial", "phases_completed": 1, "phases_total": 2}
EOF
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g9c_sess.json"
: > "$ARGV_LOG"
run_sut --session g9c_sess --hard -- 903
if [ "$(jqf '.dispatch | map(select(.task == 903)) | length')" = "1" ] && \
   [ "$(jqf '.blocked | map(select(.task == 903)) | length')" = "0" ]; then
  pass "H1: a well-formed open heading dispatches (not blocked)"
else
  fail "H1: well-formed candidate did not dispatch as expected (stdout: $LAST_STDOUT)"
fi
dispatch_argv=$(grep '^903 implement' "$ARGV_LOG" || true)
if echo "$dispatch_argv" | grep -q -- "--phase-number 2"; then
  pass "H1: orchestrate-build-dispatch.sh receives --phase-number 2 (the selected open phase)"
else
  fail "H1: --phase-number 2 missing from orchestrate-build-dispatch.sh argv (argv: '$dispatch_argv')"
fi
if echo "$dispatch_argv" | grep -q -- "--territory"; then
  pass "H1: orchestrate-build-dispatch.sh receives --territory for the hard-mode implement row"
else
  fail "H1: --territory missing from orchestrate-build-dispatch.sh argv (argv: '$dispatch_argv')"
fi

# ── Case D: no open heading, not inconclusive -- falls through to ORDINARY dispatch, never a
# --phase-number (never resolved through a phase-scoped path when nothing is left open) ──
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 904, "project_name": "g9_fallthrough", "task_type": "general", "status": "implementing", "description": "H1 no-open-heading fallthrough", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
mkdir -p "$WORKDIR/specs/904_g9_fallthrough/plans"
cat > "$WORKDIR/specs/904_g9_fallthrough/plans/01_plan.md" <<'EOF'
# Plan

### Phase 1: One [COMPLETED]
EOF
cat > "$WORKDIR/specs/904_g9_fallthrough/.orchestrator-handoff.json" <<'EOF'
{"status": "partial", "phases_completed": 1, "phases_total": 1}
EOF
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g9d_sess.json"
: > "$ARGV_LOG"
run_sut --session g9d_sess --hard -- 904
if [ "$(jqf '.dispatch | map(select(.task == 904)) | length')" = "1" ] && \
   [ "$(jqf '.blocked | map(select(.task == 904)) | length')" = "0" ]; then
  pass "H1: no open heading (not inconclusive) falls through to ordinary dispatch"
else
  fail "H1: no-open-heading candidate did not fall through as expected (stdout: $LAST_STDOUT)"
fi
fallthrough_argv=$(grep '^904 implement' "$ARGV_LOG" || true)
if echo "$fallthrough_argv" | grep -q -- "--phase-number"; then
  fail "H1: fallthrough dispatch unexpectedly carries --phase-number (argv: '$fallthrough_argv')"
else
  pass "H1: fallthrough dispatch carries no --phase-number (ordinary status-derived dispatch)"
fi

# ── Case E: --dry-run parity -- the SAME blocked verdict, with NO plan-file mutation ──
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 905, "project_name": "g9_dryrun", "task_type": "general", "status": "implementing", "description": "H1 dry-run parity", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
mkdir -p "$WORKDIR/specs/905_g9_dryrun/plans"
cat > "$WORKDIR/specs/905_g9_dryrun/plans/01_plan.md" <<'EOF'
# Plan

### Phase 1: One [COMPLETED]
### Phase 2: Two [NOT STARTED]
EOF
cat > "$WORKDIR/specs/905_g9_dryrun/.orchestrator-handoff.json" <<'EOF'
{"status": "partial", "phases_completed": 0, "phases_total": 2}
EOF
plan_before=$(cat "$WORKDIR/specs/905_g9_dryrun/plans/01_plan.md")
run_sut --session g9e_sess --hard --dry-run -- 905
if [ "$(jqf '.blocked | map(select(.task == 905)) | length')" = "1" ] && \
   [[ "$(jqf '.blocked | map(select(.task == 905)) | .[0].reason')" == *"MARKER/HANDOFF MISMATCH"* ]]; then
  pass "H1: --dry-run reports the SAME blocked verdict as the live path"
else
  fail "H1: --dry-run did not report the expected blocked verdict (stdout: $LAST_STDOUT)"
fi
plan_after=$(cat "$WORKDIR/specs/905_g9_dryrun/plans/01_plan.md")
if [ "$plan_before" = "$plan_after" ]; then
  pass "H1: --dry-run performs NO disputed-heading downgrade (mutates nothing)"
else
  fail "H1: --dry-run unexpectedly mutated the plan file"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 10: Decision 2 — aux_dispatch[] emission (fixed agents, per-task caps, chaining,
# mutual exclusion, --dry-run parity)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 10: aux_dispatch[] emission"

# The REAL orchestrate-build-aux-dispatch.sh runs in this group (never stubbed) -- it never calls
# memory/lit/command-route-agent.sh by its own design, so it is safe to exercise for real; this is
# what lets Case A below grep the WRITTEN dispatch file for the absence of a memory/lit block.
# A tiny fake agent directory gives the model-resolution assertion (Case F) something real to find
# (EXT_ROOT is the SUT's own two-levels-up from its script path, i.e. $WORKDIR here).
mkdir -p "$WORKDIR/fakeext/agents"
cat > "$WORKDIR/fakeext/agents/reviser-agent.md" <<'EOF'
---
model: opus
---
EOF

write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 1001, "project_name": "g10_aux", "task_type": "general", "status": "implementing", "description": "aux dispatch candidate", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -rf "$WORKDIR/specs/1001_g10_aux"
mkdir -p "$WORKDIR/specs/1001_g10_aux/plans"
cat > "$WORKDIR/specs/1001_g10_aux/plans/01_plan.md" <<'EOF'
# Plan

### Phase 1: One [NOT STARTED]
EOF
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g10_a.json"

# ── Case A: aux_pending = blocker-research produces exactly one aux_dispatch[] row with
# agent=fork, orchestrator_mode=false, and a dispatch file with no memory/lit block ──────────────
jq -n --arg t "1001" '{aux_pending: {($t): {kind: "blocker-research", blocker_desc: "widget X is missing"}}}' \
  > "$WORKDIR/specs/.orchestrator-multi-state-g10_a.json"
run_sut --session g10_a -- 1001
if [ "$(jqf '.aux_dispatch | length')" = "1" ] && \
   [ "$(jqf '.aux_dispatch[0].kind')" = "blocker-research" ] && \
   [ "$(jqf '.aux_dispatch[0].agent')" = "fork" ] && \
   [ "$(jqf '.aux_dispatch[0].orchestrator_mode')" = "false" ]; then
  pass "aux: blocker-research aux_pending produces exactly one row (agent=fork, orchestrator_mode=false)"
else
  fail "aux: blocker-research row missing or malformed (stdout: $LAST_STDOUT)"
fi
aux_file_a=$(jqf '.aux_dispatch[0].dispatch_file')
if [ -n "$aux_file_a" ] && [ -f "$aux_file_a" ] && ! grep -qi "memory\|literature" "$aux_file_a"; then
  pass "aux: blocker-research dispatch file exists and carries no memory/literature block"
else
  fail "aux: blocker-research dispatch file missing or unexpectedly carries a memory/lit block ($aux_file_a)"
fi
if [ "$(jq -r --arg t "1001" '.aux_pending[$t] // "CLEARED"' "$WORKDIR/specs/.orchestrator-multi-state-g10_a.json")" = "CLEARED" ] && \
   [ "$(jq -r --arg t "1001" '.blocker_escalation_count[$t] // 0' "$WORKDIR/specs/.orchestrator-multi-state-g10_a.json")" = "1" ]; then
  pass "aux: blocker-research clears aux_pending and increments blocker_escalation_count to 1"
else
  fail "aux: aux_pending not cleared or counter not incremented ($(cat "$WORKDIR/specs/.orchestrator-multi-state-g10_a.json"))"
fi

# ── Case B: MAX_BLOCKER_ESCALATIONS=2 cap -- a third blocker-research signal emits no row ───────
jq -n --arg t "1001" '{blocker_escalation_count: {($t): 2}, aux_pending: {($t): {kind: "blocker-research", blocker_desc: "third strike"}}}' \
  > "$WORKDIR/specs/.orchestrator-multi-state-g10_a.json"
run_sut --session g10_a -- 1001
if [ "$(jqf '.aux_dispatch | map(select(.task == 1001)) | length')" = "0" ]; then
  pass "aux: MAX_BLOCKER_ESCALATIONS cap suppresses a third blocker-research row"
else
  fail "aux: blocker-research cap did not suppress the row (stdout: $LAST_STDOUT)"
fi
if [ "$(jq -r --arg t "1001" '.aux_pending[$t] // "CLEARED"' "$WORKDIR/specs/.orchestrator-multi-state-g10_a.json")" = "CLEARED" ]; then
  pass "aux: a capped-out aux_pending entry is still cleared (never re-evaluated next cycle)"
else
  fail "aux: capped-out aux_pending entry was not cleared"
fi

# ── Case C: MAX_DRIFT_INSPECTIONS=1 cap -- base mode ─────────────────────────────────────────────
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g10_c.json"
jq -n --arg t "1001" '{aux_pending: {($t): {kind: "drift-inspection"}}}' \
  > "$WORKDIR/specs/.orchestrator-multi-state-g10_c.json"
run_sut --session g10_c -- 1001
if [ "$(jqf '.aux_dispatch | map(select(.task == 1001 and .kind == "drift-inspection")) | length')" = "1" ] && \
   [ "$(jqf '.aux_dispatch[0].agent')" = "fork" ]; then
  pass "aux: drift-inspection aux_pending (base mode) produces one row, agent=fork"
else
  fail "aux: drift-inspection row missing or malformed (stdout: $LAST_STDOUT)"
fi
jq -n --arg t "1001" '{drift_inspection_count: {($t): 1}, aux_pending: {($t): {kind: "drift-inspection"}}}' \
  > "$WORKDIR/specs/.orchestrator-multi-state-g10_c.json"
run_sut --session g10_c -- 1001
if [ "$(jqf '.aux_dispatch | map(select(.task == 1001)) | length')" = "0" ]; then
  pass "aux: MAX_DRIFT_INSPECTIONS cap suppresses a second drift-inspection row"
else
  fail "aux: drift-inspection cap did not suppress the row (stdout: $LAST_STDOUT)"
fi

# ── Case D: mutual exclusion -- drift-inspection aux_pending under --hard is suppressed, never
# co-occurring with divergence-audit's own hard-mode-only gate ──────────────────────────────────
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g10_d.json"
jq -n --arg t "1001" '{aux_pending: {($t): {kind: "drift-inspection"}}}' \
  > "$WORKDIR/specs/.orchestrator-multi-state-g10_d.json"
run_sut --session g10_d --hard -- 1001
if [ "$(jqf '.aux_dispatch | map(select(.task == 1001)) | length')" = "0" ]; then
  pass "aux: mutual exclusion -- a drift-inspection aux_pending under --hard emits no row"
else
  fail "aux: drift-inspection under --hard unexpectedly emitted a row (stdout: $LAST_STDOUT)"
fi

rm -f "$WORKDIR/specs/.orchestrator-multi-state-g10_e.json"
jq -n --arg t "1001" '{aux_pending: {($t): {kind: "divergence-audit", target: "the flaky step", verbatim_goal: "make it pass"}}}' \
  > "$WORKDIR/specs/.orchestrator-multi-state-g10_e.json"
run_sut --session g10_e -- 1001
if [ "$(jqf '.aux_dispatch | map(select(.task == 1001)) | length')" = "0" ]; then
  pass "aux: mutual exclusion -- a divergence-audit aux_pending in base mode emits no row"
else
  fail "aux: divergence-audit in base mode unexpectedly emitted a row (stdout: $LAST_STDOUT)"
fi

# ── Case E: divergence-audit under --hard dispatches with the task's own already-resolved
# research agent, never task-type re-resolved through command-route-agent.sh ────────────────────
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g10_f.json"
jq -n --arg t "1001" \
  '{research_agents: {($t): "stub-research-agent"}, aux_pending: {($t): {kind: "divergence-audit", target: "the flaky step", verbatim_goal: "make it pass"}}}' \
  > "$WORKDIR/specs/.orchestrator-multi-state-g10_f.json"
run_sut --session g10_f --hard -- 1001
if [ "$(jqf '.aux_dispatch | map(select(.task == 1001 and .kind == "divergence-audit")) | length')" = "1" ] && \
   [ "$(jqf '.aux_dispatch[0].agent')" = "stub-research-agent" ]; then
  pass "aux: divergence-audit under --hard dispatches with the task's stored research_agents[t], never re-resolved"
else
  fail "aux: divergence-audit row missing or used the wrong agent (stdout: $LAST_STDOUT)"
fi

# ── Case F: chaining -- a completed blocker-research fork's .blocker-research.json produces a
# plan-revision row (agent=reviser-agent, model read from that agent's own frontmatter), and the
# marker file is consumed (removed) once the row is built ───────────────────────────────────────
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g10_g.json"
jq -n '{summary: "root cause found", blocker_desc: "widget X is missing", root_cause: "typo", solution_path: "fix the typo"}' \
  > "$WORKDIR/specs/1001_g10_aux/.blocker-research.json"
run_sut --session g10_g -- 1001
if [ "$(jqf '.aux_dispatch | map(select(.task == 1001 and .kind == "plan-revision")) | length')" = "1" ] && \
   [ "$(jqf '.aux_dispatch[0].agent')" = "reviser-agent" ] && \
   [ "$(jqf '.aux_dispatch[0].model')" = "opus" ]; then
  pass "aux: a completed .blocker-research.json chains to a plan-revision row (agent=reviser-agent, model=opus from frontmatter)"
else
  fail "aux: blocker-research chain did not produce the expected plan-revision row (stdout: $LAST_STDOUT)"
fi
if [ ! -f "$WORKDIR/specs/1001_g10_aux/.blocker-research.json" ]; then
  pass "aux: .blocker-research.json is consumed (removed) once chained into a plan-revision row"
else
  fail "aux: .blocker-research.json was not removed after chaining"
fi

# ── Case G: chaining -- drift_pct <= 0.30 logs "Drift check passed" and emits NO row; the marker
# file is still consumed either way ──────────────────────────────────────────────────────────────
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g10_h.json"
jq -n '{drift_pct: 0.10, summary: "low drift"}' > "$WORKDIR/specs/1001_g10_aux/.drift-inspection.json"
run_sut --session g10_h -- 1001
if [ "$(jqf '.aux_dispatch | map(select(.task == 1001)) | length')" = "0" ] && [[ "$LAST_STDERR" == *"Drift check passed"* ]]; then
  pass "aux: drift_pct <= 0.30 emits no row and logs 'Drift check passed'"
else
  fail "aux: low-drift chain unexpectedly emitted a row or omitted the log line (stderr: $LAST_STDERR)"
fi
if [ ! -f "$WORKDIR/specs/1001_g10_aux/.drift-inspection.json" ]; then
  pass "aux: .drift-inspection.json is consumed (removed) even when drift_pct is below threshold"
else
  fail "aux: .drift-inspection.json was not removed after a below-threshold chain check"
fi

# ── Case H: --dry-run parity -- same kind/agent rendered, dispatch_file/model null, NO mutation.
# Uses the CHAIN file (.blocker-research.json), never a pre-seeded mt_state_file -- mt_state_file
# is never read back under --dry-run by this script's own two-function design (dry-run runs only
# the read-only decision pass; the ONLY per-invocation state --dry-run ever consults is on-disk
# task-directory files, exactly like H1's own --dry-run parity case above), so aux_pending seeded
# directly into a fixture mt_state_file would never be visible to a --dry-run invocation -- this
# is expected, not a gap this phase's own scope covers. ──────────────────────────────────────────
jq -n '{summary: "dry-run findings", blocker_desc: "dry-run case", root_cause: "x", solution_path: "y"}' \
  > "$WORKDIR/specs/1001_g10_aux/.blocker-research.json"
run_sut --session g10_i --dry-run -- 1001
if [ "$(jqf '.aux_dispatch | length')" = "1" ] && \
   [ "$(jqf '.aux_dispatch[0].kind')" = "plan-revision" ] && \
   [ "$(jqf '.aux_dispatch[0].agent')" = "reviser-agent" ] && \
   [ "$(jqf '.aux_dispatch[0].dispatch_file')" = "null" ] && \
   [ "$(jqf '.aux_dispatch[0].model')" = "null" ]; then
  pass "aux: --dry-run renders the SAME aux row (dispatch_file/model null)"
else
  fail "aux: --dry-run aux rendering incorrect (stdout: $LAST_STDOUT)"
fi
if [ -f "$WORKDIR/specs/1001_g10_aux/.blocker-research.json" ]; then
  pass "aux: --dry-run mutates nothing (chain marker file left in place)"
else
  fail "aux: --dry-run unexpectedly consumed the chain marker file"
fi
rm -f "$WORKDIR/specs/1001_g10_aux/.blocker-research.json"

# ── Case I: REGRESSION -- an aux row is still built even when the ONLY task in the batch is
# terminal/all-terminal THIS SAME cycle. A `blocked` verdict from orchestrate-cycle-postflight.sh
# both (a) records a blocker-research aux_pending signal and (b) charges the task to failed_tasks
# in the SAME cycle -- so the all-terminal short-circuit must never suppress the very aux row that
# task needs to get unstuck. This is a placement regression test: aux emission must happen BEFORE
# the all-terminal check's own emit_and_exit, not after. ─────────────────────────────────────────
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 1002, "project_name": "g10_terminal_aux", "task_type": "general", "status": "implementing", "description": "aux row survives all-terminal", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -rf "$WORKDIR/specs/1002_g10_terminal_aux"
mkdir -p "$WORKDIR/specs/1002_g10_terminal_aux"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g10_j.json"
jq -n --arg t "1002" '{failed_tasks: [1002], aux_pending: {($t): {kind: "blocker-research", blocker_desc: "widget X is missing"}}}' \
  > "$WORKDIR/specs/.orchestrator-multi-state-g10_j.json"
run_sut --session g10_j -- 1002
if [ "$(jqf '.stop.reason')" = "all_terminal" ]; then
  pass "aux: fixture confirms the all-terminal short-circuit actually fires this cycle (failed_tasks pre-seeded)"
else
  fail "aux: fixture did not reach the all-terminal short-circuit as expected (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.aux_dispatch | map(select(.task == 1002 and .kind == "blocker-research")) | length')" = "1" ] && \
   [ "$(jqf '.aux_dispatch[0].agent')" = "fork" ]; then
  pass "aux: REGRESSION -- an aux_dispatch[] row is still built even though this cycle stops for all_terminal"
else
  fail "aux: REGRESSION -- aux row was suppressed by the all-terminal short-circuit (stdout: $LAST_STDOUT)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 11: Inter-cycle redeploy checkpoint -- the three-branch (a)/(b)/(c) contract, driven with
# a stubbed deploy-headless.sh and a call-counting stubbed verify-deploy.sh (first invocation is
# the PRE snapshot, second is the POST snapshot -- matching the checkpoint's own call order:
# pre_findings, then deploy-headless.sh, then post_findings). SCRIPT_DIR interposition confirmed
# reachable: the checkpoint invokes `bash "$SCRIPT_DIR/deploy-headless.sh"` and
# `deploy_findings_snapshot "$SCRIPT_DIR/verify-deploy.sh"`, and $SCRIPT_DIR resolves to this
# fixture's own $WORKDIR/.claude/scripts (the SUT's own BASH_SOURCE-derived directory) -- so a
# same-named stub dropped there is picked up with no further interposition machinery needed.
#
# Cases (l)-(r) extend this group with the durable cross-invocation redeploy ledger (Phase 1-2 of
# this task): a hash skip for the ordinary unchanged-content case, an attributed-recency skip for
# the self-modifying-task class (a task whose own file_scope IS the orchestrator source store, so
# a content hash can never skip it by construction -- case (r) is the NAMED acceptance criterion
# for this class), the deploy_pending override, and negative-record (never-skip-eligible) ledger
# writes. These cases need a REAL (non-CANNOTVERIFY) source-store root distinct from the
# `.claude/scripts` deploy-mirror tree already set up above: `deploy_ledger_hash_state` hashes
# ONLY `agent-system/extensions/core` under PROJECT_ROOT (here, $WORKDIR), which cases (a)-(k)
# never populate -- confirming, by construction, that cases (a)-(k) exercise the CANNOTVERIFY ->
# run fallback path rather than accidentally exercising a skip.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 11: inter-cycle redeploy checkpoint (three-branch contract + durable ledger skip rules)"

# shellcheck source=/dev/null
source "$CORE_DIR/lib/deploy-ledger-lib.sh"

G11_CALL_MARKER="$WORKDIR/.claude/scripts/.g11_verify_call_count"

# write_g11_verify_stub <pre_findings_line_or_empty> <post_findings_line_or_empty> <exit_code>
#   [confirm_findings_line_or_empty]
# Call-counting, matching the checkpoint's own three-call order once the confirmation/attribution
# filters are reached (pre_findings, then deploy-headless.sh, then post_findings, then --
# ONLY when a candidate new finding is found -- a third confirmation snapshot):
#   1st invocation: prints only the PRE line (if any).
#   2nd invocation: prints PRE + POST lines (if any) -- this is the post-redeploy snapshot.
#   3rd+ invocation: prints PRE + CONFIRM lines (if any) -- this is the confirmation re-run.
# The optional 4th argument defaults to the POST value when omitted, preserving the exact
# pre-Phase-3 two-call behavior for every existing case that never reaches a 3rd call: passing
# an explicit "" for confirm (distinct from omitting it) simulates a finding that does NOT
# reproduce on the confirmation re-run -- i.e. flaky.
write_g11_verify_stub() {
  local pre="$1" post="$2" rc="$3" confirm="${4-__G11_CONFIRM_UNSET__}"
  if [ "$confirm" = "__G11_CONFIRM_UNSET__" ]; then confirm="$post"; fi
  cat > "$WORKDIR/.claude/scripts/verify-deploy.sh" <<EOF
#!/usr/bin/env bash
marker="$G11_CALL_MARKER"
count=0
[ -f "\$marker" ] && count=\$(cat "\$marker")
count=\$((count + 1))
echo "\$count" > "\$marker"
if [ -n "$pre" ]; then echo "$pre"; fi
if [ "\$count" -eq 2 ] && [ -n "$post" ]; then echo "$post"; fi
if [ "\$count" -ge 3 ] && [ -n "$confirm" ]; then echo "$confirm"; fi
exit $rc
EOF
  chmod +x "$WORKDIR/.claude/scripts/verify-deploy.sh"
}

# write_g11_deploy_headless_stub <exit_code> -- call-counting (G11_DEPLOY_CALL_MARKER), so
# cases (l)-(r) can assert the redeploy pipeline was (or, for a skip, was NOT) actually invoked --
# distinct from G11_CALL_MARKER above, which counts verify-deploy.sh calls. Backward-compatible
# with cases (a)-(k): none of them read this new marker, only the (unchanged) exit-code behavior.
G11_DEPLOY_CALL_MARKER="$WORKDIR/.claude/scripts/.g11_deploy_call_count"
write_g11_deploy_headless_stub() {
  local rc="$1"
  cat > "$WORKDIR/.claude/scripts/deploy-headless.sh" <<EOF
#!/usr/bin/env bash
marker="$G11_DEPLOY_CALL_MARKER"
count=0
[ -f "\$marker" ] && count=\$(cat "\$marker")
count=\$((count + 1))
echo "\$count" > "\$marker"
echo "[deploy-headless] (stub) simulated run, exit $rc" >&2
exit $rc
EOF
  chmod +x "$WORKDIR/.claude/scripts/deploy-headless.sh"
}

# write_g11_self_rewriting_deploy_stub <exit_code> [banner_kb] -- SELF-OVERWRITE HAZARD regression
# fixture. Identical call-counting/exit-code contract to write_g11_deploy_headless_stub above, but
# ALSO rewrites the staged SUT ($SUT) IN PLACE -- truncate + rewrite the SAME inode via a plain
# output redirection, matching the real deploy engine's io.open(path, "w") write, never a
# rename/mv -- while the SUT process invoking this stub is still mid-execution. This reproduces
# the observed incident (deploy-headless.sh regenerates the very script that invoked it)
# deterministically, independent of the orchestrator's real timing. The prepended comment banner
# is large enough that every byte offset in the file after the rewrite point moves, so a
# stale-offset resume (the actual bash behavior under test) is forced to read content that no
# longer lines up with a statement boundary, instead of getting lucky and re-aligning. Bump
# banner_kb (default $G11_SELF_REWRITE_BANNER_KB_DEFAULT KiB, set below) if a pre-fix run is ever
# observed to pass despite the unfixed script.
G11_SELF_REWRITE_BANNER_KB_DEFAULT=70
write_g11_self_rewriting_deploy_stub() {
  local rc="$1"
  local banner_kb="${2:-$G11_SELF_REWRITE_BANNER_KB_DEFAULT}"
  local banner_bytes=$((banner_kb * 1024))
  cat > "$WORKDIR/.claude/scripts/deploy-headless.sh" <<EOF
#!/usr/bin/env bash
marker="$G11_DEPLOY_CALL_MARKER"
count=0
[ -f "\$marker" ] && count=\$(cat "\$marker")
count=\$((count + 1))
echo "\$count" > "\$marker"
echo "[deploy-headless] (stub) simulated run, exit $rc" >&2
banner=\$(head -c $banner_bytes /dev/zero | tr '\\0' '#')
{
  printf '# %s\n' "\$banner"
  cat "$SUT_SRC"
} > "$SUT"
exit $rc
EOF
  chmod +x "$WORKDIR/.claude/scripts/deploy-headless.sh"
}

# g11_setup_dispatch_candidate <session_id> <candidate_status> -- like g11_seed_state_and_mt, but
# adds a SECOND, genuinely eligible candidate (project 9111) alongside the terminal fixture task
# 9101, so a case can assert the checkpoint still produces a real, non-empty .dispatch row for a
# live candidate after a mid-run self-rewrite -- not just checkpoint bookkeeping on a terminal-only
# batch, which is all cases (a)-(s) above exercise. Fresh invocation: clears the ledger, same as
# g11_seed_state_and_mt.
g11_setup_dispatch_candidate() {
  local session="$1" status="$2"
  write_state <<EOF
{
  "active_projects": [
    {"project_number": 9101, "project_name": "g11_terminal", "task_type": "general", "status": "abandoned", "description": "terminal fixture task, unrelated to the checkpoint under test", "dependencies": [], "file_scope": []},
    {"project_number": 9111, "project_name": "g11_rewrite_candidate", "task_type": "general", "status": "$status", "description": "eligible candidate proving the checkpoint still produces a real dispatch row after a mid-run self-rewrite", "dependencies": [], "file_scope": []}
  ]
}
EOF
  reset_lock_dirs
  rm -f "$G11_CALL_MARKER" "$G11_DEPLOY_CALL_MARKER"
  rm -f "$WORKDIR/specs/.orchestrator-deploy-ledger.json"
  local mt_file="$WORKDIR/specs/.orchestrator-multi-state-${session}.json"
  rm -f "$mt_file"
  jq -n --argjson tn "[9101,9111]" --argjson cmf '[".claude/scripts/orchestrate-cycle-plan.sh"]' '{
    task_numbers: $tn,
    cycle_modified_files: $cmf
  }' > "$mt_file"
  # Restore $SUT to a pristine copy of $SUT_SRC before every case, so a self-rewriting stub
  # (write_g11_self_rewriting_deploy_stub) always starts from a known, uncorrupted baseline
  # instead of compounding on whatever a PRIOR self-rewriting case already left on disk -- a
  # leftover banner prefix from an earlier case shifts every subsequent case's byte offsets in a
  # way that is not the hazard under test and would make results depend on suite ordering.
  cp "$SUT_SRC" "$SUT"
}

# g11_reset_mt <session_id> <cycle_modified_files_json> -- the state.json + mt_state half of
# g11_seed_state_and_mt below, factored out so cases (q) and (r) can simulate a FRESH
# `/orchestrate` invocation (new session, fresh mt_state) while the durable, specs-root-scoped
# deploy ledger survives across the call, exactly as it does across real invocations. Does NOT
# touch the ledger file.
g11_reset_mt() {
  local session="$1" cmf_json="$2"
  write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 9101, "project_name": "g11_terminal", "task_type": "general", "status": "abandoned", "description": "terminal fixture task, unrelated to the checkpoint under test", "dependencies": [], "file_scope": []}
  ]
}
EOF
  reset_lock_dirs
  rm -f "$G11_CALL_MARKER" "$G11_DEPLOY_CALL_MARKER"
  local mt_file="$WORKDIR/specs/.orchestrator-multi-state-${session}.json"
  rm -f "$mt_file"
  jq -n --argjson tn "[9101]" --argjson cmf "$cmf_json" '{
    task_numbers: $tn,
    cycle_modified_files: $cmf
  }' > "$mt_file"
}

g11_seed_state_and_mt() {
  # A single terminal (abandoned) task -- mirrors Group 1's fixture shape -- so the SUT reaches
  # the checkpoint (which runs before any candidate-eligibility work) and then cleanly stops with
  # no dispatch, needing no orchestrate-build-dispatch.sh/update-task-status.sh stubbing.
  # Also clears the durable deploy ledger, unlike g11_reset_mt above -- this is the "brand new
  # invocation, no prior deploy history at all" entry point every one of cases (a)-(p) uses; only
  # (q)'s second run and (r)'s b/c invocations deliberately reuse g11_reset_mt instead, to prove
  # the ledger's cross-invocation durability.
  g11_reset_mt "$1" '[".claude/scripts/orchestrate-cycle-plan.sh"]'
  rm -f "$WORKDIR/specs/.orchestrator-deploy-ledger.json"
}

# g11_set_cycle_modified_files <session_id> <json_array> -- overrides the cycle_modified_files
# g11_seed_state_and_mt/g11_reset_mt seeded, for a case that needs the SOURCE-STORE path itself
# (under agent-system/extensions/core, matching what a real self-modifying task's own
# modified_files would look like) rather than the `.claude` deploy-mirror path cases (a)-(k) use.
g11_set_cycle_modified_files() {
  local session="$1" cmf_json="$2"
  local mt_file="$WORKDIR/specs/.orchestrator-multi-state-${session}.json"
  jq --argjson cmf "$cmf_json" '.cycle_modified_files = $cmf' "$mt_file" > "${mt_file}.tmp" && mv "${mt_file}.tmp" "$mt_file"
}

# G11_SOURCE_ROOT / g11_seed_source_store / g11_mutate_source_file -- the ledger's OWN
# hash-scope root ($WORKDIR/agent-system/extensions/core, per deploy_ledger_hash_state's
# Decision 2 scope), distinct from the pre-existing `.claude/scripts` deploy-mirror tree set up
# earlier in this file. Cases (a)-(k) above deliberately never populate this root -- that is what
# proves they exercise the CANNOTVERIFY -> run fallback, not an accidental skip.
G11_SOURCE_ROOT="$WORKDIR/agent-system/extensions/core"
g11_seed_source_store() {
  # (Re)creates a full fixture source-store root containing a deterministic baseline file for
  # EVERY orchestrator-critical path (fixture content, never copied from the real repository
  # tree), so deploy_ledger_hash_state resolves a real, non-CANNOTVERIFY hash.
  rm -rf "$G11_SOURCE_ROOT"
  mkdir -p "$G11_SOURCE_ROOT"
  local rel
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    mkdir -p "$(dirname "$G11_SOURCE_ROOT/$rel")"
    printf 'fixture baseline content for %s\n' "$rel" > "$G11_SOURCE_ROOT/$rel"
  done < <(jq -r '.critical_paths[].path' "$WORKDIR/.claude/context/reference/orchestrator-critical-paths.json")
}
g11_mutate_source_file() {
  # Usage: g11_mutate_source_file <critical-path-relative-path> -- appends a uniquely-timestamped
  # line so the file's sha256 (and therefore the ledger's aggregate) deterministically changes.
  local rel="$1"
  printf 'mutated %s\n' "$(date +%s%N)" >> "$G11_SOURCE_ROOT/$rel"
}

# g11_seed_ledger <task_numbers_json> <verify_outcome> <age_seconds> -- seeds
# specs/.orchestrator-deploy-ledger.json from the LIBRARY's own deploy_ledger_hash_state +
# deploy_ledger_write (this test file sources the real lib above), so no test ever hand-rolls a
# hash; only verified_at is then back-dated by <age_seconds> to control the recency/max-age
# window checks deterministically.
g11_seed_ledger() {
  local tasks="$1" outcome="$2" age="$3"
  local ledger_file="$WORKDIR/specs/.orchestrator-deploy-ledger.json"
  local hs
  hs="$(deploy_ledger_hash_state "$WORKDIR" "$WORKDIR/.claude/context/reference/orchestrator-critical-paths.json")"
  deploy_ledger_write "$ledger_file" "$hs" "$outcome" "$tasks" "sess_ledger_seed" 1
  local now target
  now=$(date +%s)
  target=$((now - age))
  jq --argjson vat "$target" '.verified_at = $vat' "$ledger_file" > "${ledger_file}.tmp" && mv "${ledger_file}.tmp" "$ledger_file"
}

# ── Case (a): deploy-headless.sh exit 1 -- unconditional defer, NO baseline consultation. The
# stubbed verify-deploy.sh below would report a NEW finding on its 2nd call if reached; case (a)
# must never reach that 2nd call at all, which the call-count assertion below also pins. ─────────
g11_seed_state_and_mt "g11_a"
write_g11_verify_stub "FINDING gate1 pre-existing" "FINDING gate2 NEW" 1
write_g11_deploy_headless_stub 1
run_sut --session g11_a -- 9101
mt_a="$WORKDIR/specs/.orchestrator-multi-state-g11_a.json"
if [ "$(jq -r '.deferred_deploy_checkpoint | index(9101) != null' "$mt_a" 2>/dev/null)" = "true" ]; then
  pass "checkpoint (a): deploy-headless.sh exit 1 defers the batch (deferred_deploy_checkpoint contains the task)"
else
  fail "checkpoint (a): deferred_deploy_checkpoint does not contain 9101 (mt_state: $(cat "$mt_a" 2>/dev/null))"
fi
if [ "$(jq -r '.verify_deploy_baseline_notices | length' "$mt_a" 2>/dev/null)" = "0" ]; then
  pass "checkpoint (a): no baseline notice recorded (branch (a) never consults the baseline)"
else
  fail "checkpoint (a): unexpected verify_deploy_baseline_notices entry recorded"
fi
if [ -f "$G11_CALL_MARKER" ] && [ "$(cat "$G11_CALL_MARKER")" = "1" ]; then
  pass "checkpoint (a): verify-deploy.sh called exactly once (pre-snapshot only; post-snapshot never taken)"
else
  fail "checkpoint (a): expected exactly one verify-deploy.sh call, got $(cat "$G11_CALL_MARKER" 2>/dev/null || echo 'none')"
fi

# ── Case (b): deploy-headless.sh exit 3 (landed, gate red) WITH a genuinely new finding relative
# to the pre-redeploy baseline -- defer, same as (a)'s outcome, but reached via the baseline
# comparison this time (this is what the plan calls "the tolerance proven narrow"). ─────────────
g11_seed_state_and_mt "g11_b"
write_g11_verify_stub "FINDING gate1 pre-existing" "FINDING gate2 NEW" 1
write_g11_deploy_headless_stub 3
run_sut --session g11_b -- 9101
mt_b="$WORKDIR/specs/.orchestrator-multi-state-g11_b.json"
if [ "$(jq -r '.deferred_deploy_checkpoint | index(9101) != null' "$mt_b" 2>/dev/null)" = "true" ]; then
  pass "checkpoint (b): a NEW finding on exit 3 still defers the batch"
else
  fail "checkpoint (b): deferred_deploy_checkpoint does not contain 9101 (mt_state: $(cat "$mt_b" 2>/dev/null))"
fi
if [ "$(jq -r '.verify_deploy_baseline_notices | length' "$mt_b" 2>/dev/null)" = "0" ]; then
  pass "checkpoint (b): no baseline notice recorded (a genuinely new failure is not a tolerated pre-existing one)"
else
  fail "checkpoint (b): unexpected verify_deploy_baseline_notices entry recorded"
fi

# ── Case (c): deploy-headless.sh exit 3 (landed, gate red) with EVERY post-redeploy finding
# already present pre-redeploy -- proceed, record a verify_deploy_baseline_notices entry, do NOT
# defer. This is the exact branch that was UNREACHABLE before this task (the whole point of the
# fix): a pre-existing, unrelated red gate must not defer the batch. ────────────────────────────
g11_seed_state_and_mt "g11_c"
write_g11_verify_stub "FINDING gate1 pre-existing" "" 1
write_g11_deploy_headless_stub 3
run_sut --session g11_c -- 9101
mt_c="$WORKDIR/specs/.orchestrator-multi-state-g11_c.json"
if [ "$(jq -r '.deferred_deploy_checkpoint | index(9101) != null' "$mt_c" 2>/dev/null)" = "false" ] || \
   [ "$(jq -r '.deferred_deploy_checkpoint | length' "$mt_c" 2>/dev/null)" = "0" ]; then
  pass "checkpoint (c): a pre-existing-only finding set on exit 3 does NOT defer the batch"
else
  fail "checkpoint (c): batch was unexpectedly deferred (mt_state: $(cat "$mt_c" 2>/dev/null))"
fi
if [ "$(jq -r '.verify_deploy_baseline_notices | length' "$mt_c" 2>/dev/null)" -ge "1" ]; then
  pass "checkpoint (c): a verify_deploy_baseline_notices entry was recorded"
else
  fail "checkpoint (c): expected a verify_deploy_baseline_notices entry, found none (mt_state: $(cat "$mt_c" 2>/dev/null))"
fi
if [ "$(jq -r '.deployed_critical_paths | index(".claude/scripts/orchestrate-cycle-plan.sh") != null' "$mt_c" 2>/dev/null)" = "true" ]; then
  pass "checkpoint (c): deployed_critical_paths records the matched critical path"
else
  fail "checkpoint (c): deployed_critical_paths does not record the matched path (mt_state: $(cat "$mt_c" 2>/dev/null))"
fi

# ── Case (d): a candidate new finding does NOT reproduce on the confirmation re-run -- FLAKY.
# Must NOT defer the batch; a verify_deploy_baseline_notices entry records it as flaky, and
# deployed_critical_paths is still recorded (proceeding, not skipping the deploy bookkeeping). ──
g11_seed_state_and_mt "g11_d"
write_g11_verify_stub "FINDING gate1 pre-existing" "FINDING gate2 NEW" 1 ""
write_g11_deploy_headless_stub 3
run_sut --session g11_d -- 9101
mt_d="$WORKDIR/specs/.orchestrator-multi-state-g11_d.json"
if [ "$(jq -r '.deferred_deploy_checkpoint | index(9101) != null' "$mt_d" 2>/dev/null)" = "false" ] || \
   [ "$(jq -r '.deferred_deploy_checkpoint | length' "$mt_d" 2>/dev/null)" = "0" ]; then
  pass "checkpoint (d): a flaky (non-reproducing) new finding does NOT defer the batch"
else
  fail "checkpoint (d): batch was unexpectedly deferred (mt_state: $(cat "$mt_d" 2>/dev/null))"
fi
if [ "$(jq -r '.verify_deploy_baseline_notices[-1].filtered' "$mt_d" 2>/dev/null)" = "true" ] && \
   [ "$(jq -r '.verify_deploy_baseline_notices[-1].flaky_count' "$mt_d" 2>/dev/null)" -ge "1" ]; then
  pass "checkpoint (d): notice records the finding as flaky (filtered:true, flaky_count>=1)"
else
  fail "checkpoint (d): expected a filtered notice with flaky_count>=1 (mt_state: $(cat "$mt_d" 2>/dev/null))"
fi
if [ "$(jq -r '.deployed_critical_paths | index(".claude/scripts/orchestrate-cycle-plan.sh") != null' "$mt_d" 2>/dev/null)" = "true" ]; then
  pass "checkpoint (d): deployed_critical_paths still recorded when proceeding on a flaky finding"
else
  fail "checkpoint (d): deployed_critical_paths not recorded (mt_state: $(cat "$mt_d" 2>/dev/null))"
fi

# ── Case (e): a CONFIRMED new finding names an identifier absent from this batch's own
# cycle_modified_files -- UNRELATED. Must NOT defer; notice records it as unrelated. ────────────
g11_seed_state_and_mt "g11_e"
write_g11_verify_stub "FINDING gate1 pre-existing" "FINDING gate8 [FAIL] test-lake-build-guard.sh" 1
write_g11_deploy_headless_stub 3
run_sut --session g11_e -- 9101
mt_e="$WORKDIR/specs/.orchestrator-multi-state-g11_e.json"
if [ "$(jq -r '.deferred_deploy_checkpoint | index(9101) != null' "$mt_e" 2>/dev/null)" = "false" ] || \
   [ "$(jq -r '.deferred_deploy_checkpoint | length' "$mt_e" 2>/dev/null)" = "0" ]; then
  pass "checkpoint (e): a confirmed but unrelated new finding does NOT defer the batch"
else
  fail "checkpoint (e): batch was unexpectedly deferred (mt_state: $(cat "$mt_e" 2>/dev/null))"
fi
if [ "$(jq -r '.verify_deploy_baseline_notices[-1].filtered' "$mt_e" 2>/dev/null)" = "true" ] && \
   [ "$(jq -r '.verify_deploy_baseline_notices[-1].unrelated_count' "$mt_e" 2>/dev/null)" -ge "1" ]; then
  pass "checkpoint (e): notice records the finding as unrelated (filtered:true, unrelated_count>=1)"
else
  fail "checkpoint (e): expected a filtered notice with unrelated_count>=1 (mt_state: $(cat "$mt_e" 2>/dev/null))"
fi

# ── Case (f): a CONFIRMED new finding names an identifier PRESENT in this batch's own
# cycle_modified_files -- genuinely attributable. Must still defer (the gate is not disabled). ──
g11_seed_state_and_mt "g11_f"
write_g11_verify_stub "FINDING gate1 pre-existing" "FINDING gate3 [FAIL] .claude/scripts/orchestrate-cycle-plan.sh" 1
write_g11_deploy_headless_stub 3
run_sut --session g11_f -- 9101
mt_f="$WORKDIR/specs/.orchestrator-multi-state-g11_f.json"
if [ "$(jq -r '.deferred_deploy_checkpoint | index(9101) != null' "$mt_f" 2>/dev/null)" = "true" ]; then
  pass "checkpoint (f): a confirmed, attributable new finding still defers the batch"
else
  fail "checkpoint (f): deferred_deploy_checkpoint does not contain 9101 (mt_state: $(cat "$mt_f" 2>/dev/null))"
fi

# ── Case (g): the defer message (stderr) and defer_ledger[].detail both name the specific
# blocking finding -- Defect B, now against the FILTERED set. Reuses case (f)'s already-run
# fixture and captured $LAST_STDERR (no separate run needed). ──────────────────────────────────
if printf '%s' "$LAST_STDERR" | grep -q "orchestrate-cycle-plan.sh"; then
  pass "checkpoint (g): defer stderr names the specific blocking finding"
else
  fail "checkpoint (g): defer stderr does not name the finding (stderr: $LAST_STDERR)"
fi
if [ "$(jq -r '.defer_ledger[-1].detail' "$mt_f" 2>/dev/null | grep -c "orchestrate-cycle-plan.sh")" -ge "1" ]; then
  pass "checkpoint (g): defer_ledger[].detail names the specific blocking finding"
else
  fail "checkpoint (g): defer_ledger[].detail does not name the finding (mt_state: $(cat "$mt_f" 2>/dev/null))"
fi

# ── Case (h): a CONFIRMED new finding names NO identifier at all -- the attribution filter must
# NEVER treat an identifier-free finding as unrelated (fail-safe toward blocking). Still defers. ─
g11_seed_state_and_mt "g11_h"
write_g11_verify_stub "FINDING gate1 pre-existing" "FINDING gate2 NEW" 1
write_g11_deploy_headless_stub 3
run_sut --session g11_h -- 9101
mt_h="$WORKDIR/specs/.orchestrator-multi-state-g11_h.json"
if [ "$(jq -r '.deferred_deploy_checkpoint | index(9101) != null' "$mt_h" 2>/dev/null)" = "true" ]; then
  pass "checkpoint (h): an identifier-free confirmed finding still defers (fail-safe attribution)"
else
  fail "checkpoint (h): deferred_deploy_checkpoint does not contain 9101 (mt_state: $(cat "$mt_h" 2>/dev/null))"
fi

# ── Case (i): depth-symmetry regression guard -- a gate-8 finding present in BOTH pre and post
# snapshots is NOT treated as new (comm -13 sees it in both sets) and takes the ORIGINAL branch
# (c), never reaching the confirmation call at all (only 2 verify-deploy.sh calls). ─────────────
g11_seed_state_and_mt "g11_i"
write_g11_verify_stub "FINDING gate8 [FAIL] test-lake-build-guard.sh" "FINDING gate8 [FAIL] test-lake-build-guard.sh" 1
write_g11_deploy_headless_stub 3
run_sut --session g11_i -- 9101
mt_i="$WORKDIR/specs/.orchestrator-multi-state-g11_i.json"
if [ "$(jq -r '.deferred_deploy_checkpoint | index(9101) != null' "$mt_i" 2>/dev/null)" = "false" ] || \
   [ "$(jq -r '.deferred_deploy_checkpoint | length' "$mt_i" 2>/dev/null)" = "0" ]; then
  pass "checkpoint (i): a gate-8 finding present in BOTH pre and post is not treated as new"
else
  fail "checkpoint (i): batch was unexpectedly deferred (mt_state: $(cat "$mt_i" 2>/dev/null))"
fi
if [ "$(jq -r '.verify_deploy_baseline_notices[-1].filtered' "$mt_i" 2>/dev/null)" = "false" ]; then
  pass "checkpoint (i): takes the ORIGINAL branch (c) (filtered:false), not the new filtered sub-branch"
else
  fail "checkpoint (i): expected filtered:false (original branch (c)) (mt_state: $(cat "$mt_i" 2>/dev/null))"
fi
if [ -f "$G11_CALL_MARKER" ] && [ "$(cat "$G11_CALL_MARKER")" = "2" ]; then
  pass "checkpoint (i): verify-deploy.sh called exactly twice (no confirmation call when new_findings is empty)"
else
  fail "checkpoint (i): expected exactly two verify-deploy.sh calls, got $(cat "$G11_CALL_MARKER" 2>/dev/null || echo 'none')"
fi

# ── Case (j): call-count guard for the ORIGINAL branch (c) (identical to the pre-existing case
# (c) fixture) -- confirms it makes exactly two verify-deploy.sh calls, i.e. the confirmation
# snapshot is fired ONLY when there is a candidate new finding to confirm. ──────────────────────
g11_seed_state_and_mt "g11_j"
write_g11_verify_stub "FINDING gate1 pre-existing" "" 1
write_g11_deploy_headless_stub 3
run_sut --session g11_j -- 9101
if [ -f "$G11_CALL_MARKER" ] && [ "$(cat "$G11_CALL_MARKER")" = "2" ]; then
  pass "checkpoint (j): branch (c) (no new findings) makes exactly two verify-deploy.sh calls"
else
  fail "checkpoint (j): expected exactly two verify-deploy.sh calls, got $(cat "$G11_CALL_MARKER" 2>/dev/null || echo 'none')"
fi

# ── Case (k): Defect A depth-disagreement report -- deploy-headless.sh's OWN internal
# --skip-slow verify reports exit 0 (landed_verify_clean, a fast PASS) for this same tree, yet
# the checkpoint's independent full-depth comparison still finds a confirmed, attributable
# blocking finding. Reported as an explicit depth disagreement, not a silent contradiction. Goes
# beyond the plan's originally-enumerated (d)-(j) letter range per its own Scope Hypothesis note
# ("add ... cases as the wiring actually requires"), since the Testing & Validation section
# separately names this as its own acceptance criterion. ───────────────────────────────────────
g11_seed_state_and_mt "g11_k"
write_g11_verify_stub "FINDING gate1 pre-existing" "FINDING gate3 [FAIL] .claude/scripts/orchestrate-cycle-plan.sh" 1
write_g11_deploy_headless_stub 0
run_sut --session g11_k -- 9101
mt_k="$WORKDIR/specs/.orchestrator-multi-state-g11_k.json"
if [ "$(jq -r '.deferred_deploy_checkpoint | index(9101) != null' "$mt_k" 2>/dev/null)" = "true" ]; then
  pass "checkpoint (k): still defers despite deploy-headless.sh's own fast verify passing"
else
  fail "checkpoint (k): deferred_deploy_checkpoint does not contain 9101 (mt_state: $(cat "$mt_k" 2>/dev/null))"
fi
if printf '%s' "$LAST_STDERR" | grep -q "DEPTH NOTE"; then
  pass "checkpoint (k): stderr carries the explicit depth-disagreement note"
else
  fail "checkpoint (k): stderr missing the depth-disagreement note (stderr: $LAST_STDERR)"
fi
if [ "$(jq -r '.defer_ledger[-1].depth_disagreement' "$mt_k" 2>/dev/null)" = "true" ]; then
  pass "checkpoint (k): defer_ledger[].depth_disagreement records the depth disagreement"
else
  fail "checkpoint (k): defer_ledger[].depth_disagreement is not true (mt_state: $(cat "$mt_k" 2>/dev/null))"
fi

# ── Case (l): skip on unchanged hash -- the ordinary case. Ledger clean, same content, fresh
# (well within DEPLOY_LEDGER_MAX_AGE_SEC's default 86400s) -- must skip via skip_hash without
# ever invoking deploy-headless.sh or verify-deploy.sh at all. Deliberately configured with
# stubs that WOULD defer if reached, so a regression that fails to skip is caught loudly. ───────
g11_seed_state_and_mt "g11_l"
g11_seed_source_store
g11_seed_ledger '[9101]' "clean" 60
write_g11_verify_stub "FINDING gate1 pre-existing" "FINDING gate2 NEW" 1
write_g11_deploy_headless_stub 1
run_sut --session g11_l -- 9101
mt_l="$WORKDIR/specs/.orchestrator-multi-state-g11_l.json"
if [ "$(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 0)" = "0" ]; then
  pass "checkpoint (l): skip_hash never invokes deploy-headless.sh"
else
  fail "checkpoint (l): expected deploy-headless.sh to be skipped, got $(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null) call(s)"
fi
if [ "$(jq -r '.deferred_deploy_checkpoint | length' "$mt_l" 2>/dev/null)" = "0" ]; then
  pass "checkpoint (l): the batch is not deferred on a hash skip"
else
  fail "checkpoint (l): batch was unexpectedly deferred (mt_state: $(cat "$mt_l" 2>/dev/null))"
fi
if [ "$(jq -r '.redeploy_skip_notices[-1].decision' "$mt_l" 2>/dev/null)" = "skip_hash" ]; then
  pass "checkpoint (l): redeploy_skip_notices records decision=skip_hash"
else
  fail "checkpoint (l): expected redeploy_skip_notices[-1].decision=skip_hash (mt_state: $(cat "$mt_l" 2>/dev/null))"
fi
if [ "$(jq -r '.deployed_critical_paths | length' "$mt_l" 2>/dev/null)" = "0" ]; then
  pass "checkpoint (l): deployed_critical_paths is left unchanged (empty) on a skip"
else
  fail "checkpoint (l): expected deployed_critical_paths to stay empty on a skip (mt_state: $(cat "$mt_l" 2>/dev/null))"
fi

# ── Case (m): skip within the recency window -- the self-modifying-task case. Content changed
# on a path named in cycle_modified_files, ledger recent, same task number -- must skip via
# skip_attributed, again without ever invoking the (defer-triggering) stubs. ────────────────────
g11_seed_state_and_mt "g11_m"
g11_seed_source_store
g11_seed_ledger '[9101]' "clean" 300
g11_mutate_source_file "scripts/orchestrate-cycle-plan.sh"
g11_set_cycle_modified_files "g11_m" '["agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh"]'
write_g11_verify_stub "FINDING gate1 pre-existing" "FINDING gate2 NEW" 1
write_g11_deploy_headless_stub 1
run_sut --session g11_m -- 9101
mt_m="$WORKDIR/specs/.orchestrator-multi-state-g11_m.json"
if [ "$(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 0)" = "0" ]; then
  pass "checkpoint (m): skip_attributed never invokes deploy-headless.sh"
else
  fail "checkpoint (m): expected deploy-headless.sh to be skipped, got $(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null) call(s)"
fi
if [ "$(jq -r '.redeploy_skip_notices[-1].decision' "$mt_m" 2>/dev/null)" = "skip_attributed" ]; then
  pass "checkpoint (m): redeploy_skip_notices records decision=skip_attributed"
else
  fail "checkpoint (m): expected redeploy_skip_notices[-1].decision=skip_attributed (mt_state: $(cat "$mt_m" 2>/dev/null))"
fi
if [ "$(jq -r '.redeploy_skip_notices[-1].attributing_tasks | index(9101) != null' "$mt_m" 2>/dev/null)" = "true" ]; then
  pass "checkpoint (m): the skip notice attributes the skip to project #9101"
else
  fail "checkpoint (m): expected attributing_tasks to contain 9101 (mt_state: $(cat "$mt_m" 2>/dev/null))"
fi

# ── Case (n): NO skip when the source store genuinely changed OUTSIDE the recency window --
# full pipeline runs, and the ledger is rewritten with the new aggregate and outcome clean. ─────
g11_seed_state_and_mt "g11_n"
g11_seed_source_store
g11_seed_ledger '[9101]' "clean" 5000
g11_mutate_source_file "scripts/orchestrate-cycle-plan.sh"
g11_set_cycle_modified_files "g11_n" '["agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh"]'
write_g11_verify_stub "" "" 0
write_g11_deploy_headless_stub 0
run_sut --session g11_n -- 9101
mt_n="$WORKDIR/specs/.orchestrator-multi-state-g11_n.json"
if [ "$(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 0)" = "1" ]; then
  pass "checkpoint (n): outside the recency window, the full pipeline runs (deploy-headless.sh called)"
else
  fail "checkpoint (n): expected exactly one deploy-headless.sh call, got $(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 'none')"
fi
if [ "$(jq -r '.deferred_deploy_checkpoint | length' "$mt_n" 2>/dev/null)" = "0" ]; then
  pass "checkpoint (n): a clean redeploy does not defer the batch"
else
  fail "checkpoint (n): batch was unexpectedly deferred (mt_state: $(cat "$mt_n" 2>/dev/null))"
fi
ledger_n_outcome="$(jq -r '.verify_outcome' "$WORKDIR/specs/.orchestrator-deploy-ledger.json" 2>/dev/null)"
expected_hash_n="$(deploy_ledger_hash_state "$WORKDIR" "$WORKDIR/.claude/context/reference/orchestrator-critical-paths.json" | jq -r '.aggregate')"
ledger_n_agg="$(jq -r '.aggregate' "$WORKDIR/specs/.orchestrator-deploy-ledger.json" 2>/dev/null)"
if [ "$ledger_n_outcome" = "clean" ] && [ "$ledger_n_agg" = "$expected_hash_n" ]; then
  pass "checkpoint (n): the ledger is rewritten with the new aggregate and outcome clean"
else
  fail "checkpoint (n): expected ledger outcome=clean aggregate=$expected_hash_n, got outcome=$ledger_n_outcome aggregate=$ledger_n_agg"
fi

# ── Case (o): NO skip on a FOREIGN change -- an in-window, shared-task ledger, but the critical
# path that actually changed on disk is absent from cycle_modified_files (something else changed
# the source store) -- the attributed skip must not fire. ───────────────────────────────────────
g11_seed_state_and_mt "g11_o"
g11_seed_source_store
g11_seed_ledger '[9101]' "clean" 300
g11_mutate_source_file "scripts/orchestrate-cycle-plan.sh"
g11_set_cycle_modified_files "g11_o" '["agent-system/extensions/core/scripts/task-lock.sh"]'
write_g11_verify_stub "" "" 0
write_g11_deploy_headless_stub 0
run_sut --session g11_o -- 9101
if [ "$(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 0)" = "1" ]; then
  pass "checkpoint (o): a foreign changed critical path (not covered by cycle_modified_files) is not skipped"
else
  fail "checkpoint (o): expected the pipeline to run (not skip) on a foreign change, got $(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 'none') call(s)"
fi

# ── Case (p): deploy_pending override -- a batch task directory's own .return-meta.json carries
# deploy_pending:true, forcing `run` despite an otherwise-matching (skip-eligible) hash. ────────
g11_seed_state_and_mt "g11_p"
g11_seed_source_store
g11_seed_ledger '[9101]' "clean" 60
mkdir -p "$WORKDIR/specs/9101_g11_terminal"
jq -n '{deploy_pending: true}' > "$WORKDIR/specs/9101_g11_terminal/.return-meta.json"
write_g11_verify_stub "" "" 0
write_g11_deploy_headless_stub 0
run_sut --session g11_p -- 9101
if [ "$(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 0)" = "1" ]; then
  pass "checkpoint (p): a deploy_pending batch task forces run despite an otherwise-matching hash"
else
  fail "checkpoint (p): expected the pipeline to run under deploy_pending override, got $(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 'none') call(s)"
fi
rm -f "$WORKDIR/specs/9101_g11_terminal/.return-meta.json"
rmdir "$WORKDIR/specs/9101_g11_terminal" 2>/dev/null || true

# ── Case (q): negative record -- a branch (b) defer writes verify_outcome:"blocking" (never
# skip-eligible); a FOLLOWING run with genuinely unchanged content must still NOT skip, and the
# ledger converges back to "clean" once a clean deploy lands. Uses g11_reset_mt (not
# g11_seed_state_and_mt) for the second run so the durable ledger survives across the two
# invocations, exactly as it would across two real /orchestrate runs. ───────────────────────────
g11_seed_state_and_mt "g11_q"
g11_seed_source_store
write_g11_verify_stub "FINDING gate1 pre-existing" "FINDING gate3 [FAIL] .claude/scripts/orchestrate-cycle-plan.sh" 1
write_g11_deploy_headless_stub 3
run_sut --session g11_q -- 9101
LEDGER_FILE_Q="$WORKDIR/specs/.orchestrator-deploy-ledger.json"
if [ -f "$LEDGER_FILE_Q" ] && [ "$(jq -r '.verify_outcome' "$LEDGER_FILE_Q" 2>/dev/null)" = "blocking" ]; then
  pass "checkpoint (q): a branch (b) defer writes a negative 'blocking' ledger record"
else
  fail "checkpoint (q): expected ledger verify_outcome=blocking after a branch-(b) defer, got: $(cat "$LEDGER_FILE_Q" 2>/dev/null || echo MISSING)"
fi

g11_reset_mt "g11_q2" '["agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh"]'
write_g11_verify_stub "" "" 0
write_g11_deploy_headless_stub 0
run_sut --session g11_q2 -- 9101
if [ "$(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 0)" = "1" ]; then
  pass "checkpoint (q): a following run with unchanged content does NOT skip on a non-eligible (blocking) ledger record"
else
  fail "checkpoint (q): expected the pipeline to run (not skip) despite unchanged content, got $(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 'none') call(s)"
fi
if [ "$(jq -r '.verify_outcome' "$LEDGER_FILE_Q" 2>/dev/null)" = "clean" ]; then
  pass "checkpoint (q): the ledger converges back to 'clean' once a clean deploy lands"
else
  fail "checkpoint (q): expected ledger verify_outcome=clean after the follow-up run, got $(jq -c '.' "$LEDGER_FILE_Q" 2>/dev/null)"
fi

# ── Case (r): the NAMED self-modifying-task acceptance criterion. A task whose file_scope and
# cycle_modified_files overlap scripts/orchestrate-cycle-plan.sh. Invocation 1 (empty ledger)
# runs the full redeploy; the fixture source file is then edited (new hash, by construction)
# before invocations 2 and 3, which must both skip via skip_attributed -- so the TOTAL deploy
# count across all three invocations stays 1. The counterfactual re-run with
# DEPLOY_LEDGER_RECENT_SEC=-1 (a hash-only rule, in effect, since the recency window can never be
# satisfied) proves this is the ATTRIBUTED rule doing the work, not the hash rule: the hash
# changes on every one of the three invocations by construction, so a hash-only rule redeploys
# every time (count 3). This is what proves shipping only the hash skip would leave the observed
# failure mode fully intact. ──────────────────────────────────────────────────────────────────
g11_run_self_modifying_sequence() {
  # Usage: g11_run_self_modifying_sequence <label> [recent_sec_override]
  # Fresh baseline + empty ledger, then three invocations (mutating the source file and
  # resetting mt_state, but NOT the ledger, between each), summing the per-invocation
  # deploy-headless.sh call counts. Echoes the total on stdout.
  local label="$1" override="${2:-}"
  local total=0 c

  g11_reset_mt "g11_r_${label}_a" '["agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh"]'
  rm -f "$WORKDIR/specs/.orchestrator-deploy-ledger.json"
  g11_seed_source_store
  write_g11_verify_stub "" "" 0
  write_g11_deploy_headless_stub 0
  if [ -n "$override" ]; then
    DEPLOY_LEDGER_RECENT_SEC="$override" run_sut --session "g11_r_${label}_a" -- 9101
  else
    run_sut --session "g11_r_${label}_a" -- 9101
  fi
  c="$(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 0)"; total=$((total + c))

  g11_mutate_source_file "scripts/orchestrate-cycle-plan.sh"
  g11_reset_mt "g11_r_${label}_b" '["agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh"]'
  write_g11_deploy_headless_stub 0
  if [ -n "$override" ]; then
    DEPLOY_LEDGER_RECENT_SEC="$override" run_sut --session "g11_r_${label}_b" -- 9101
  else
    run_sut --session "g11_r_${label}_b" -- 9101
  fi
  c="$(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 0)"; total=$((total + c))

  g11_mutate_source_file "scripts/orchestrate-cycle-plan.sh"
  g11_reset_mt "g11_r_${label}_c" '["agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh"]'
  write_g11_deploy_headless_stub 0
  if [ -n "$override" ]; then
    DEPLOY_LEDGER_RECENT_SEC="$override" run_sut --session "g11_r_${label}_c" -- 9101
  else
    run_sut --session "g11_r_${label}_c" -- 9101
  fi
  c="$(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 0)"; total=$((total + c))

  echo "$total"
}

g11_r_normal_count="$(g11_run_self_modifying_sequence "normal")"
if [ "$g11_r_normal_count" = "1" ]; then
  pass "checkpoint (r): self-modifying-task acceptance -- total deploy count stays 1 across 3 invocations (the attributed skip closes the observed failure mode)"
else
  fail "checkpoint (r): expected total deploy count 1 across 3 self-modifying invocations, got $g11_r_normal_count"
fi

g11_r_counterfactual_count="$(g11_run_self_modifying_sequence "counterfactual" "-1")"
if [ "$g11_r_counterfactual_count" = "3" ]; then
  pass "checkpoint (r): counterfactual -- a hash-only rule (DEPLOY_LEDGER_RECENT_SEC=-1, recency window unsatisfiable) redeploys on every one of the 3 invocations, proving the attributed rule (not the hash rule) is what closes the failure mode"
else
  fail "checkpoint (r): expected counterfactual deploy count 3 (a hash-only rule never skips the self-modifying class), got $g11_r_counterfactual_count"
fi

rm -f "$WORKDIR/.claude/scripts/verify-deploy.sh" "$WORKDIR/.claude/scripts/deploy-headless.sh" "$G11_CALL_MARKER" "$G11_DEPLOY_CALL_MARKER"
rm -rf "$G11_SOURCE_ROOT"
rm -f "$WORKDIR/specs/.orchestrator-deploy-ledger.json"

# ── Case (s): WIDENED TRIGGER PREDICATE (this task's Part 1 core change) -- matched_count == 0
# (cycle_modified_files touches a file under agent-system/extensions/** that is NOT one of the
# curated orchestrator-critical-paths.json entries) but deploy_pending:true is set on candidate
# 9101's own .return-meta.json (postflight's completion-deploy gate already refused a prior
# cycle). Before this task's hoist, deploy_pending_any was computed ONLY INSIDE the
# `matched_count -gt 0` branch, so this exact combination never reached the deploy body at all --
# the D6 residual this phase retires. Distinct from case (p) above: case (p)'s default fixture
# cycle_modified_files (`.claude/scripts/orchestrate-cycle-plan.sh`) already matches a curated
# critical path, so matched_count is already >0 there and (p) only proves the LEDGER's own
# deploy_pending override, never the widened OR-predicate itself. This is the refusal-then-
# recovery path named in this task's own dispatch acceptance criterion #2. ──────────────────────
g11_seed_state_and_mt "g11_s"
g11_seed_source_store
g11_set_cycle_modified_files "g11_s" '["agent-system/extensions/core/scripts/foo.sh"]'
mkdir -p "$WORKDIR/specs/9101_g11_terminal"
jq -n '{deploy_pending: true}' > "$WORKDIR/specs/9101_g11_terminal/.return-meta.json"
write_g11_verify_stub "" "" 0
write_g11_deploy_headless_stub 0
run_sut --session g11_s -- 9101
if [ "$(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 0)" = "1" ]; then
  pass "checkpoint (s): the widened predicate reaches the deploy body when matched_count==0 but deploy_pending_any=true (a non-allowlisted agent-system/extensions/** path)"
else
  fail "checkpoint (s): expected the pipeline to run under the widened predicate, got $(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 'none') call(s)"
fi
if echo "$LAST_STDERR" | grep -q "REDEPLOY CHECKPOINT: triggered by the deploy_pending marker" && \
   echo "$LAST_STDERR" | grep -q '\[9101\]'; then
  pass "checkpoint (s): the announcement names its own reason (deploy_pending marker naming the candidate), not a misleading 'touched 0 orchestrator-critical path(s)' line"
else
  fail "checkpoint (s): expected the deploy_pending-triggered announcement naming the candidate, got: $LAST_STDERR"
fi
if echo "$LAST_STDERR" | grep -q "touched 0 orchestrator-critical path(s)"; then
  fail "checkpoint (s): the misleading 'touched 0 orchestrator-critical path(s)' line must not appear on the widened path"
else
  pass "checkpoint (s): no misleading 'touched 0 orchestrator-critical path(s)' line"
fi
mt_s="$WORKDIR/specs/.orchestrator-multi-state-g11_s.json"
if [ "$(jq -r '.cycle_modified_files' "$mt_s" 2>/dev/null)" = "[]" ]; then
  pass "checkpoint (s): cycle_modified_files is still reset to [] after the widened-path run (unconditional reset preserved)"
else
  fail "checkpoint (s): expected cycle_modified_files reset to [] after the run, got: $(cat "$mt_s" 2>/dev/null)"
fi
# Ledger-consult assertion (plan verification requirement): the widened path must still ROUTE
# THROUGH deploy_ledger_decide and write the durable ledger on a clean outcome, never bypass it --
# a written ledger record with verify_outcome=clean is only reachable via that consult+write path.
ledger_file_s="$WORKDIR/specs/.orchestrator-deploy-ledger.json"
if [ -f "$ledger_file_s" ] && [ "$(jq -r '.verify_outcome' "$ledger_file_s" 2>/dev/null)" = "clean" ]; then
  pass "checkpoint (s): the widened path still routes through deploy_ledger_decide (durable ledger written with verify_outcome=clean), not a bypass"
else
  fail "checkpoint (s): expected the durable ledger to be written with verify_outcome=clean on the widened path, got: $(cat "$ledger_file_s" 2>/dev/null || echo MISSING)"
fi
rm -f "$WORKDIR/specs/9101_g11_terminal/.return-meta.json"
rmdir "$WORKDIR/specs/9101_g11_terminal" 2>/dev/null || true
rm -f "$WORKDIR/.claude/scripts/verify-deploy.sh" "$WORKDIR/.claude/scripts/deploy-headless.sh" "$G11_CALL_MARKER" "$G11_DEPLOY_CALL_MARKER"
rm -rf "$G11_SOURCE_ROOT"
rm -f "$WORKDIR/specs/.orchestrator-deploy-ledger.json"

# ── Case (t): SELF-OVERWRITE HAZARD, deploy-landed branch (exit 3, clean gate) -- the redeploy
# checkpoint's own deploy-headless.sh call rewrites the staged SUT IN PLACE, mid-execution, exactly
# as the observed incident did (bash resumes reading the rewritten file at a stale byte offset and
# dies with a spurious "unbound variable"/syntax error). Pre-fix (this script not yet function-
# wrapped) this case is expected to FAIL -- that failure is the red-first proof the fixture actually
# detects the hazard, not evidence of a fixture defect. Post-fix (Phase 2's function-wrap) it must
# PASS: SUT exits 0, stdout is valid non-empty JSON carrying a REAL dispatch row for the live
# candidate (9111, not just checkpoint bookkeeping on the terminal-only fixture every other case in
# this group uses), and stderr carries none of the incident's crash signatures. ─────────────────
g11_setup_dispatch_candidate "g11_t" "researched"
write_g11_verify_stub "" "" 0
write_g11_self_rewriting_deploy_stub 3
run_sut --session g11_t -- 9101 9111
if [ "$LAST_EXIT" -eq 0 ]; then
  pass "checkpoint (t): SUT exits 0 despite the mid-run self-rewrite (deploy-landed branch)"
else
  fail "checkpoint (t): SUT exited $LAST_EXIT after the mid-run self-rewrite (stderr: $LAST_STDERR)"
fi
if echo "$LAST_STDOUT" | jq -e . >/dev/null 2>&1; then
  pass "checkpoint (t): stdout is valid, non-empty JSON after the mid-run self-rewrite"
else
  fail "checkpoint (t): stdout did not parse as JSON after the mid-run self-rewrite (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.dispatch | map(select(.task == 9111)) | length')" = "1" ] && \
   [ "$(jqf '.dispatch | map(select(.task == 9111)) | .[0].phase')" = "plan" ]; then
  pass "checkpoint (t): a real, non-empty dispatch row for the live candidate survives the mid-run self-rewrite"
else
  fail "checkpoint (t): expected a dispatch row for candidate #9111 (phase plan), got: $LAST_STDOUT"
fi
if echo "$LAST_STDERR" | grep -qiE 'unbound variable|syntax error|unexpected (token|EOF)'; then
  fail "checkpoint (t): stderr carries a crash signature from the mid-run self-rewrite: $LAST_STDERR"
else
  pass "checkpoint (t): stderr carries none of the incident's crash signatures"
fi
if [ "$(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 0)" = "1" ]; then
  pass "checkpoint (t): deploy-headless.sh was called exactly once"
else
  fail "checkpoint (t): expected exactly one deploy-headless.sh call, got $(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 'none')"
fi
rm -f "$WORKDIR/.claude/scripts/verify-deploy.sh" "$WORKDIR/.claude/scripts/deploy-headless.sh" "$G11_CALL_MARKER" "$G11_DEPLOY_CALL_MARKER"
rm -f "$WORKDIR/specs/.orchestrator-deploy-ledger.json"

# ── Case (u): SELF-OVERWRITE HAZARD, deploy-failure branch (exit 1) -- the same mid-run self-
# rewrite, but on the branch that must defer remaining tasks rather than proceed. Confirms the
# wrap does not weaken the deploy-failure defer contract even when the rewrite happens: both the
# terminal fixture task (9101) and the live candidate (9111) must land in
# deferred_deploy_checkpoint with an intact defer_ledger entry, and the SUT must still complete
# (exit 0, valid JSON) rather than dying mid-read. ────────────────────────────────────────────────
g11_setup_dispatch_candidate "g11_u" "researched"
write_g11_verify_stub "FINDING gate1 pre-existing" "FINDING gate2 NEW" 1
write_g11_self_rewriting_deploy_stub 1
run_sut --session g11_u -- 9101 9111
if [ "$LAST_EXIT" -eq 0 ]; then
  pass "checkpoint (u): SUT exits 0 despite the mid-run self-rewrite (deploy-failure branch)"
else
  fail "checkpoint (u): SUT exited $LAST_EXIT after the mid-run self-rewrite (stderr: $LAST_STDERR)"
fi
if echo "$LAST_STDOUT" | jq -e . >/dev/null 2>&1; then
  pass "checkpoint (u): stdout is valid, non-empty JSON after the mid-run self-rewrite"
else
  fail "checkpoint (u): stdout did not parse as JSON after the mid-run self-rewrite (stdout: $LAST_STDOUT)"
fi
if echo "$LAST_STDERR" | grep -qiE 'unbound variable|syntax error|unexpected (token|EOF)'; then
  fail "checkpoint (u): stderr carries a crash signature from the mid-run self-rewrite: $LAST_STDERR"
else
  pass "checkpoint (u): stderr carries none of the incident's crash signatures"
fi
mt_u="$WORKDIR/specs/.orchestrator-multi-state-g11_u.json"
if [ "$(jq -r '.deferred_deploy_checkpoint | index(9101) != null' "$mt_u" 2>/dev/null)" = "true" ] && \
   [ "$(jq -r '.deferred_deploy_checkpoint | index(9111) != null' "$mt_u" 2>/dev/null)" = "true" ]; then
  pass "checkpoint (u): both the terminal fixture task and the live candidate are deferred (deploy-failure defer not weakened by the rewrite)"
else
  fail "checkpoint (u): deferred_deploy_checkpoint missing an expected task (mt_state: $(cat "$mt_u" 2>/dev/null))"
fi
if [ "$(jq -r '.defer_ledger[-1].detail' "$mt_u" 2>/dev/null | grep -c "deploy-headless.sh exit 1")" -ge "1" ]; then
  pass "checkpoint (u): defer_ledger[].detail is intact (names the deploy-headless.sh exit code)"
else
  fail "checkpoint (u): defer_ledger[].detail missing/incorrect (mt_state: $(cat "$mt_u" 2>/dev/null))"
fi
if [ "$(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 0)" = "1" ]; then
  pass "checkpoint (u): deploy-headless.sh was called exactly once"
else
  fail "checkpoint (u): expected exactly one deploy-headless.sh call, got $(cat "$G11_DEPLOY_CALL_MARKER" 2>/dev/null || echo 'none')"
fi
rm -f "$WORKDIR/.claude/scripts/verify-deploy.sh" "$WORKDIR/.claude/scripts/deploy-headless.sh" "$G11_CALL_MARKER" "$G11_DEPLOY_CALL_MARKER"
rm -f "$WORKDIR/specs/.orchestrator-deploy-ledger.json"

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 12: --compare forwarding -- an implement-phase candidate's build-dispatch argv gains
# --compare; a plan-phase candidate's does not. The gate is scoped by THIS script (`$g = the
# candidate's dispatched phase`), not by orchestrate-build-dispatch.sh itself (which is
# phase-agnostic and is exercised separately in its own test suite).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 12: --compare forwarding (implement-phase only, never research/plan)"

G12_ARGV_LOG="$WORKDIR/g12-build-dispatch-argv.log"
: > "$G12_ARGV_LOG"
cat > "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$G12_ARGV_LOG"
proj_num="\$1"; phase="\$2"
jq -n -c --arg f "/fake/\${proj_num}-\${phase}.md" '{dispatch_file: \$f, model: ""}'
EOF
chmod +x "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh"

cat > "$WORKDIR/.claude/scripts/update-task-status.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$WORKDIR/.claude/scripts/update-task-status.sh"

write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 1201, "project_name": "g12_plan_candidate", "task_type": "general", "status": "researched", "description": "plan-phase candidate -- --compare must never reach this dispatch", "dependencies": [], "file_scope": []},
    {"project_number": 1202, "project_name": "g12_implement_candidate", "task_type": "general", "status": "implementing", "description": "implement-phase candidate -- --compare must reach this dispatch", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs

run_sut --session g12_sess --compare -- 1201 1202

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Group 12: SUT exits 0"
else
  fail "Group 12: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi

g12_plan_argv=$(grep '^1201 plan' "$G12_ARGV_LOG" || true)
g12_implement_argv=$(grep '^1202 implement' "$G12_ARGV_LOG" || true)

if echo "$g12_implement_argv" | grep -q -- "--compare"; then
  pass "Group 12: --compare forwarded into build_args for the implement-phase candidate"
else
  fail "Group 12: --compare missing from implement-phase build_args (argv: '$g12_implement_argv')"
fi

if echo "$g12_plan_argv" | grep -q -- "--compare"; then
  fail "Group 12: --compare unexpectedly forwarded into build_args for the plan-phase candidate (argv: '$g12_plan_argv')"
else
  pass "Group 12: --compare NOT forwarded into build_args for the plan-phase candidate"
fi

# ── --compare --hard together: both flags reach the implement dispatch (composition, never
# competing) ──────────────────────────────────────────────────────────────────────────────────
: > "$G12_ARGV_LOG"
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 1203, "project_name": "g12_hard_candidate", "task_type": "general", "status": "implementing", "description": "implement-phase candidate exercising --compare --hard composition", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs

run_sut --session g12b_sess --compare --hard -- 1203

g12_hard_argv=$(grep '^1203 implement' "$G12_ARGV_LOG" || true)
if echo "$g12_hard_argv" | grep -q -- "--compare" && echo "$g12_hard_argv" | grep -q -- "--hard"; then
  pass "Group 12: --compare --hard together both reach the implement dispatch (composition, not competition)"
else
  fail "Group 12: expected both --compare and --hard in implement build_args, got: '$g12_hard_argv'"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 13: degraded-classifier fallback table -- the path taken ONLY when
# orchestrate-triage-classify.sh itself exits non-zero. This is the drift risk the live
# classifier's own header discipline note does not, by itself, prevent: a fourth site
# (orchestrate-cycle-plan.sh's inline fallback `case` statement) that must move in lockstep with
# the live classifier but is normally dormant, so a missed edit here would silently ship a
# not_started->plan fallback while the live path correctly routes to research (or vice versa).
# The `not_started` row is now EFFORT-CONDITIONAL (research-first default, `--fast` preserves the
# prior plan-first behavior); both effort variants are asserted below against the fallback table,
# and Group 20 asserts the SAME two variants against the LIVE classifier so the two never
# silently diverge. --dry-run is sufficient: the decision pass (which the fallback table lives
# inside) runs unconditionally and --dry-run renders its output directly, per this script's own
# header.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 13: degraded-classifier fallback table (orchestrate-triage-classify.sh exit != 0)"

cat > "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh" <<'EOF'
#!/usr/bin/env bash
echo "orchestrate-triage-classify.sh: simulated degraded exit (fixture)" >&2
exit 3
EOF
chmod +x "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh"

write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 1301, "project_name": "g13_not_started", "task_type": "general", "status": "not_started", "description": "fresh task, degraded-fallback default-flip check", "dependencies": [], "file_scope": []},
    {"project_number": 1302, "project_name": "g13_researching", "task_type": "general", "status": "researching", "description": "in-flight research, degraded-fallback researching row check", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs

run_sut --session g13_sess --dry-run -- 1301 1302

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Group 13: SUT exits 0 despite the degraded classifier"
else
  fail "Group 13: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi

if echo "$LAST_STDERR" | grep -q "orchestrate-triage-classify.sh degraded"; then
  pass "Group 13: degraded-classifier WARNING logged"
else
  fail "Group 13: no degraded-classifier WARNING in stderr: $LAST_STDERR"
fi

if [ "$(jqf '.dispatch | map(select(.task == 1301)) | .[0].phase')" = "research" ]; then
  pass "Group 13: fallback table routes not_started -> research (research-first default, no --fast, matching the live classifier)"
else
  fail "Group 13: expected not_started candidate #1301 to route to research via the fallback table, got: $(jqf '.dispatch | map(select(.task == 1301))')"
fi

if [ "$(jqf '.dispatch | map(select(.task == 1302)) | .[0].phase')" = "research" ]; then
  pass "Group 13: fallback table keeps researching -> research (load-bearing for the needs_research return path)"
else
  fail "Group 13: expected researching candidate #1302 to route to research via the fallback table, got: $(jqf '.dispatch | map(select(.task == 1302))')"
fi

# --fast variant: not_started reverts to plan (the pre-research-first escape hatch); researching
# is NEVER skipped by --fast (only not_started reads effort).
reset_lock_dirs
run_sut --session g13_sess_fast --dry-run --fast -- 1301 1302

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Group 13 (--fast): SUT exits 0 despite the degraded classifier"
else
  fail "Group 13 (--fast): SUT exited $LAST_EXIT ($LAST_STDERR)"
fi

if [ "$(jqf '.dispatch | map(select(.task == 1301)) | .[0].phase')" = "plan" ]; then
  pass "Group 13 (--fast): fallback table routes not_started -> plan, matching the live classifier's --effort fast row"
else
  fail "Group 13 (--fast): expected not_started candidate #1301 to route to plan via the fallback table, got: $(jqf '.dispatch | map(select(.task == 1301))')"
fi

if [ "$(jqf '.dispatch | map(select(.task == 1302)) | .[0].phase')" = "research" ]; then
  pass "Group 13 (--fast): fallback table keeps researching -> research even under --fast (planner-requested research never skipped)"
else
  fail "Group 13 (--fast): expected researching candidate #1302 to route to research via the fallback table, got: $(jqf '.dispatch | map(select(.task == 1302))')"
fi

# Restore the real classifier for any test run after this point -- Group 20 below relies on the
# real (non-stubbed) classifier being back in place.
cp "$CORE_DIR/orchestrate-triage-classify.sh" "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh"
chmod +x "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh"

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 14: research_questions --focus wiring (research on demand, Stage A.8). Tests the WIRING
# only (orchestrate-cycle-plan.sh reads state.json's research_questions, joins them, and forwards
# as --focus to orchestrate-build-dispatch.sh) -- the --focus flag's own rendering into the
# dispatch file's "User focus:" line is orchestrate-build-dispatch.sh's OWN contract, already
# covered by test-orchestrate-build-dispatch.sh (its own "focus_prompt threaded into prompt text"
# assertion). No change was needed inside that script for this task, so this suite does not
# re-test its rendering.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 14: research_questions --focus wiring at the research-dispatch build call"

G14_ARGV_LOG="$WORKDIR/g14-build-dispatch-argv.log"
: > "$G14_ARGV_LOG"
cat > "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$G14_ARGV_LOG"
proj_num="\$1"; phase="\$2"
jq -n -c --arg f "/fake/\${proj_num}-\${phase}.md" '{dispatch_file: \$f, model: ""}'
EOF
chmod +x "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh"

write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 1401, "project_name": "g14_needs_research", "task_type": "meta", "status": "researching", "description": "planner requested research", "dependencies": [], "file_scope": [], "research_questions": ["Does library X expose a streaming API?", "Is the retry policy configurable?"]},
    {"project_number": 1402, "project_name": "g14_ordinary_research", "task_type": "meta", "status": "researching", "description": "ordinary in-flight research, no research_questions", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs

run_sut --session g14_sess -- 1401 1402

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Group 14: SUT exits 0"
else
  fail "Group 14: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi

g14_line_1401=$(grep '^1401 research' "$G14_ARGV_LOG" || true)
if echo "$g14_line_1401" | grep -qF -- "--focus Does library X expose a streaming API?; Is the retry policy configurable?"; then
  pass "Group 14: research_questions joined and forwarded as --focus for the needs_research-originated task"
else
  fail "Group 14: expected --focus with the joined research_questions in argv, got: '$g14_line_1401'"
fi

g14_line_1402=$(grep '^1402 research' "$G14_ARGV_LOG" || true)
if [ -n "$g14_line_1402" ] && ! echo "$g14_line_1402" | grep -q -- "--focus"; then
  pass "Group 14: no research_questions -> no --focus flag passed (byte-for-byte no-op)"
else
  fail "Group 14: unexpected --focus (or missing argv line) for the ordinary research candidate: '$g14_line_1402'"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 15: stdout/stderr stream discipline at every JSON-consuming collaborator call.
#
# This script's output contract reserves stdout for the single-line plan JSON and puts every
# human diagnostic on stderr. Each collaborator it shells out to (orchestrate-build-dispatch.sh,
# orchestrate-build-aux-dispatch.sh, orchestrate-triage-classify.sh, orchestrate-batch-admit.sh)
# holds the same contract for its OWN stdout payload. Capturing any of them with `2>&1` folds
# their diagnostics into the payload, and the jq that parses it then either fails outright (the
# single-object consumers) or -- worse, because the exit status is still 0 and the degraded-path
# warning never fires -- silently ingests a garbage NDJSON row.
#
# These collaborators are chatty on stderr in production: the --lit resolver's [lit:auto]
# rationale alone fires on essentially every literature-mode run. The stubs below therefore make
# each one write to stderr while returning a VALID payload on stdout, and assert (a) stdout is
# still parseable plan JSON and (b) the diagnostic reached stderr rather than vanishing.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 15: stdout stays pure JSON when collaborators write to stderr"

cat > "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh" <<'EOF'
#!/usr/bin/env bash
echo "[orchestrate-build-dispatch] [lit:auto] simulated resolver rationale (fixture)" >&2
proj_num="$1"; phase="$2"
jq -n -c --arg f "/fake/${proj_num}-${phase}.md" '{dispatch_file: $f, model: ""}'
EOF
chmod +x "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh"

cat > "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh" <<'EOF'
#!/usr/bin/env bash
echo "[triage] simulated classifier diagnostic (fixture)" >&2
for a in "$@"; do
  case "$a" in
    mt) continue ;;
    *) jq -n -c --argjson t "$a" '{task_number: $t, group: "plan", reason: "fixture"}' ;;
  esac
done
EOF
chmod +x "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh"

cat > "$WORKDIR/.claude/scripts/orchestrate-batch-admit.sh" <<'EOF'
#!/usr/bin/env bash
echo "[admit] simulated admission diagnostic (fixture)" >&2
for a in "$@"; do
  case "$a" in
    --*) prev="$a"; continue ;;
    *) if [ "${prev:-}" = "--invocation-count" ] || [ "${prev:-}" = "--session-id" ] || [ "${prev:-}" = "--phase-map" ]; then prev=""; continue; fi
       jq -n -c --argjson t "$a" '{task_number: $t, decision: "admit", reason: "fixture"}' ;;
  esac
done
EOF
chmod +x "$WORKDIR/.claude/scripts/orchestrate-batch-admit.sh"

write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 1501, "project_name": "g15_chatty_collaborators", "task_type": "general", "status": "not_started", "description": "collaborators write to stderr; stdout must stay pure JSON", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs

run_sut --session g15_sess -- 1501

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Group 15: SUT exits 0 with chatty collaborators"
else
  fail "Group 15: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi

if echo "$LAST_STDOUT" | jq -e . >/dev/null 2>&1; then
  pass "Group 15: stdout parses as JSON despite collaborator stderr on all four call sites"
else
  fail "Group 15: stdout is not parseable JSON -- stderr leaked into the payload: '$LAST_STDOUT'"
fi

g15_dispatch_file=$(jqf '.dispatch[0].dispatch_file')
if [ "$g15_dispatch_file" = "/fake/1501-plan.md" ]; then
  pass "Group 15: dispatch_file parsed correctly from the stub payload (not corrupted by stderr)"
else
  fail "Group 15: expected /fake/1501-plan.md, got '$g15_dispatch_file'"
fi

g15_missing=""
for marker in "[lit:auto] simulated resolver rationale" "[triage] simulated classifier diagnostic" "[admit] simulated admission diagnostic"; do
  echo "$LAST_STDERR" | grep -qF "$marker" || g15_missing="${g15_missing}${marker}; "
done
if [ -z "$g15_missing" ]; then
  pass "Group 15: all three collaborator diagnostics forwarded to stderr (nothing swallowed)"
else
  fail "Group 15: diagnostics missing from stderr: $g15_missing"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 16: entry-point fd-3 emit discipline (the structural remedy, distinct from Group 15's
# ingest-direction net). skill_preflight_update's underlying `update-task-status.sh preflight`
# call is invoked directly -- NOT through run_capture_stdout, since its own stdout was never a
# JSON/NDJSON payload this script parses -- and after this phase's `exec 3>&1 1>&2` entry-point
# redirect it carries no per-call-site `>&2` guard of its own any more (the prior stopgap was
# removed as redundant). Before that redirect existed, this exact call site was a real source of
# stdout contamination this phase fixes structurally. This stub reproduces that contamination --
# with NO `>&2` of its own, exactly like the pre-fix real script -- and asserts the entry-point
# redirect alone still keeps the emitted plan JSON pure.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 16: entry-point fd-3 redirect keeps plan JSON pure against an uncaptured, chatty collaborator"

cat > "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh" <<'EOF'
#!/usr/bin/env bash
proj_num="$1"; phase="$2"
jq -n -c --arg f "/fake/${proj_num}-${phase}.md" '{dispatch_file: $f, model: ""}'
EOF
chmod +x "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh"

cat > "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in
    mt) continue ;;
    *) jq -n -c --argjson t "$a" '{task_number: $t, group: "plan", reason: "fixture"}' ;;
  esac
done
EOF
chmod +x "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh"

cat > "$WORKDIR/.claude/scripts/orchestrate-batch-admit.sh" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in
    --*) prev="$a"; continue ;;
    *) if [ "${prev:-}" = "--invocation-count" ] || [ "${prev:-}" = "--session-id" ] || [ "${prev:-}" = "--phase-map" ]; then prev=""; continue; fi
       jq -n -c --argjson t "$a" '{task_number: $t, decision: "admit", reason: "fixture"}' ;;
  esac
done
EOF
chmod +x "$WORKDIR/.claude/scripts/orchestrate-batch-admit.sh"

cat > "$WORKDIR/.claude/scripts/update-task-status.sh" <<'EOF'
#!/usr/bin/env bash
# Reproduces the historical stdout contamination this phase fixes structurally: deliberately no
# `>&2` guard here, matching the real script's own confirmation echo before the fix landed (and
# before the per-call-site `>&2` stopgap that has since been removed as redundant).
echo "OK: candidate #$2 state.json already at '$3' (no-op); plan/phase updates re-applied"
exit 0
EOF
chmod +x "$WORKDIR/.claude/scripts/update-task-status.sh"

write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 1601, "project_name": "g16_chatty_preflight", "task_type": "general", "status": "not_started", "description": "uncaptured collaborator writes chatty prose to stdout; entry-point redirect must still keep plan JSON pure", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs

run_sut --session g16_sess -- 1601

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Group 16: SUT exits 0 despite the chatty, uncaptured collaborator"
else
  fail "Group 16: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi

if echo "$LAST_STDOUT" | jq -e . >/dev/null 2>&1; then
  pass "Group 16: stdout parses as a single JSON object"
else
  fail "Group 16: stdout is not parseable JSON -- '$LAST_STDOUT'"
fi

g16_lines=$(printf '%s\n' "$LAST_STDOUT" | grep -c . || true)
if [ "$g16_lines" -eq 1 ]; then
  pass "Group 16: stdout is exactly one line (no prose preamble)"
else
  fail "Group 16: expected exactly 1 stdout line, got $g16_lines: '$LAST_STDOUT'"
fi

g16_dispatch_file=$(jqf '.dispatch[0].dispatch_file')
if [ "$g16_dispatch_file" = "/fake/1601-plan.md" ]; then
  pass "Group 16: .dispatch[0] intact and correctly parsed"
else
  fail "Group 16: expected /fake/1601-plan.md, got '$g16_dispatch_file'"
fi

if echo "$LAST_STDERR" | grep -qF "OK: candidate #1601 state.json already at 'plan'"; then
  pass "Group 16: the chatty collaborator's prose landed on stderr, not the data channel"
else
  fail "Group 16: expected the collaborator's prose on stderr; got: '$LAST_STDERR'"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 17: --session optionality is dry-run-only. Reconciles commands/orchestrate.md's dry-run
# short-circuit (now a single unconditional invocation) with the script's own flag validation:
# --dry-run with no --session synthesizes an internal, never-persisted identity and still emits
# parseable plan JSON; live mode with no --session is unchanged (still exits 2).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 17: --session is optional under --dry-run, still required in live mode"

write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 1701, "project_name": "g17_no_session", "task_type": "general", "status": "not_started", "description": "--session optionality under --dry-run", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs

run_sut --dry-run -- 1701

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Group 17: --dry-run with no --session exits 0"
else
  fail "Group 17: --dry-run with no --session exited $LAST_EXIT ($LAST_STDERR)"
fi

if echo "$LAST_STDOUT" | jq -e . >/dev/null 2>&1; then
  pass "Group 17: --dry-run with no --session still prints parseable plan JSON on stdout"
else
  fail "Group 17: --dry-run with no --session did not print parseable JSON: '$LAST_STDOUT'"
fi

run_sut -- 1701

if [ "$LAST_EXIT" -eq 2 ]; then
  pass "Group 17: live mode with no --session still exits 2"
else
  fail "Group 17: live mode with no --session exited $LAST_EXIT (expected 2); stderr: '$LAST_STDERR'"
fi

if echo "$LAST_STDERR" | grep -qF -- "--session is required"; then
  pass "Group 17: live mode's no-session error message is preserved"
else
  fail "Group 17: expected a '--session is required' message on stderr; got: '$LAST_STDERR'"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 18: in-session plan cache -- a composition that dispatched, re-run with nothing consumed
# since, replays verbatim and charges nothing; once the cache is invalidated (simulating a real
# postflight), the next run recomputes and charges normally.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 18: in-session plan cache replay charges nothing; post-invalidation recompute charges normally"

cat > "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh" <<'EOF'
#!/usr/bin/env bash
proj_num="$1"; phase="$2"
jq -n -c --arg f "/fake/${proj_num}-${phase}.md" '{dispatch_file: $f, model: ""}'
EOF
chmod +x "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh"
cat > "$WORKDIR/.claude/scripts/update-task-status.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$WORKDIR/.claude/scripts/update-task-status.sh"

write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 1801, "project_name": "g18_plan_cache", "task_type": "general", "status": "not_started", "description": "in-session plan cache replay/invalidation", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
g18_mt_state="$WORKDIR/specs/.orchestrator-multi-state-g18_sess.json"
rm -f "$g18_mt_state"

run_sut --session g18_sess -- 1801
g18_run1_stdout="$LAST_STDOUT"
g18_run1_dispatch_file=$(jqf '.dispatch[0].dispatch_file')

if [ "$LAST_EXIT" -eq 0 ] && [ "$g18_run1_dispatch_file" = "/fake/1801-plan.md" ]; then
  pass "Group 18: run 1 genuinely composes and dispatches"
else
  fail "Group 18: run 1 did not compose/dispatch as expected: $LAST_STDOUT"
fi

g18_cycle_counts_after_1=$(jq -r --arg t "1801" '.cycle_counts[$t] // 0' "$g18_mt_state" 2>/dev/null)
g18_dsc_after_1=$(jq -r '.dispatch_seq_counter // 0' "$g18_mt_state" 2>/dev/null)
if jq -e '.plan_cache != null and .plan_cache.dispatch_seq_counter == .dispatch_seq_counter' "$g18_mt_state" >/dev/null 2>&1; then
  pass "Group 18: run 1's composition wrote plan_cache keyed at the resulting dispatch_seq_counter"
else
  fail "Group 18: expected plan_cache written and keyed at the current dispatch_seq_counter after run 1"
fi

run_sut --session g18_sess -- 1801

if [ "$LAST_EXIT" -eq 0 ] && [ "$LAST_STDOUT" = "$g18_run1_stdout" ]; then
  pass "Group 18: run 2 (nothing consumed since run 1) replays byte-identical stdout"
else
  fail "Group 18: run 2 stdout differs from run 1 (expected a verbatim replay). run1: '$g18_run1_stdout' run2: '$LAST_STDOUT'"
fi
if echo "$LAST_STDERR" | grep -qF "PLAN CACHE REPLAY"; then
  pass "Group 18: run 2 logs the PLAN CACHE REPLAY notice on stderr"
else
  fail "Group 18: expected a PLAN CACHE REPLAY notice on stderr; got: '$LAST_STDERR'"
fi
g18_cycle_counts_after_2=$(jq -r --arg t "1801" '.cycle_counts[$t] // 0' "$g18_mt_state" 2>/dev/null)
if [ "$g18_cycle_counts_after_2" = "$g18_cycle_counts_after_1" ]; then
  pass "Group 18: run 2 leaves cycle_counts[1801] unchanged (no cycle charged for the replay)"
else
  fail "Group 18: expected cycle_counts unchanged after replay; before=$g18_cycle_counts_after_1 after=$g18_cycle_counts_after_2"
fi
g18_guard_file="$WORKDIR/specs/1801_g18_plan_cache/.orchestrator-loop-guard"
g18_guard_dsc_after_2=$(jq -r '.dispatch_seq_counter // 0' "$g18_guard_file" 2>/dev/null)
if [ "$g18_guard_dsc_after_2" = "$g18_dsc_after_1" ]; then
  pass "Group 18: the durable loop-guard file's dispatch_seq_counter is unchanged by the replay (no extra --flush-seq)"
else
  fail "Group 18: durable loop-guard dispatch_seq_counter ($g18_guard_dsc_after_2) diverged from the pre-replay in-memory value ($g18_dsc_after_1)"
fi
if [ "$(jq -r '.cycle_count // "absent"' "$g18_guard_file" 2>/dev/null)" = "absent" ]; then
  pass "Group 18: the durable loop-guard file's cycle_count is never written by this engine any more (per-run budget contract)"
else
  fail "Group 18: durable loop-guard cycle_count is unexpectedly present/written: $(cat "$g18_guard_file" 2>/dev/null)"
fi

# Simulate a postflight: clear plan_cache directly (mirrors orchestrate-cycle-postflight.sh's own
# unconditional `del(.plan_cache)` on any outcome), proving the plan WAS consumed.
jq 'del(.plan_cache)' "$g18_mt_state" > "${g18_mt_state}.tmp" && mv "${g18_mt_state}.tmp" "$g18_mt_state"

run_sut --session g18_sess -- 1801

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Group 18: run 3 (post-invalidation) exits 0"
else
  fail "Group 18: run 3 exited $LAST_EXIT ($LAST_STDERR)"
fi
if echo "$LAST_STDERR" | grep -qF "PLAN CACHE REPLAY"; then
  fail "Group 18: run 3 unexpectedly replayed from cache after invalidation"
else
  pass "Group 18: run 3 does not replay (cache was invalidated)"
fi
g18_cycle_counts_after_3=$(jq -r --arg t "1801" '.cycle_counts[$t] // 0' "$g18_mt_state" 2>/dev/null)
if [ "$g18_cycle_counts_after_3" -eq "$((g18_cycle_counts_after_1 + 1))" ]; then
  pass "Group 18: run 3 charges exactly one additional cycle after cache invalidation"
else
  fail "Group 18: expected cycle_counts[1801] to advance by exactly 1 after invalidation; before=$g18_cycle_counts_after_1 after=$g18_cycle_counts_after_3"
fi

# A composition that dispatches nothing must never write plan_cache at all.
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 1802, "project_name": "g18_no_dispatch", "task_type": "general", "status": "completed", "description": "terminal candidate; a no-dispatch composition must never cache", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
g18b_mt_state="$WORKDIR/specs/.orchestrator-multi-state-g18b_sess.json"
rm -f "$g18b_mt_state"
run_sut --session g18b_sess -- 1802
if [ "$(jqf '.dispatch | length')" = "0" ]; then
  pass "Group 18: the no-dispatch fixture composition dispatches nothing (precondition for the next check)"
else
  fail "Group 18: expected 0 dispatched for the terminal-status fixture; got: $LAST_STDOUT"
fi
if [ ! -f "$g18b_mt_state" ] || jq -e '.plan_cache == null' "$g18b_mt_state" >/dev/null 2>&1; then
  pass "Group 18: a no-dispatch composition writes no plan_cache"
else
  fail "Group 18: a no-dispatch composition unexpectedly wrote plan_cache: $(cat "$g18b_mt_state" 2>/dev/null)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 19: durable cross-invocation pending_dispatch and dispatch_seq_counter ledgers (cycle_count
# itself is per-run now, never durable -- see Group 8). A FRESH session (a different session_id
# every time -- a genuinely new mt_state_file, so the in-session plan_cache from Group 18 never
# applies here, and in-session cycle_counts always starts at 0) against a durable guard file
# carrying a matching, file-present pending_dispatch does not charge an in-session cycle nor
# durably flush a new dispatch_seq_counter; a mismatch on phase, a missing dispatch file, or an
# absent pending_dispatch all charge normally (in-session cycle_counts advances by 1, and the
# durable dispatch_seq_counter -- seeded from the guard file and minted onward -- advances too).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 19: durable pending_dispatch ledger -- matched+file-present replays, else charges"

cat > "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh" <<'EOF'
#!/usr/bin/env bash
proj_num="$1"; phase="$2"
jq -n -c --arg f "/fake/${proj_num}-${phase}.md" '{dispatch_file: $f, model: ""}'
EOF
chmod +x "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh"
cat > "$WORKDIR/.claude/scripts/update-task-status.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$WORKDIR/.claude/scripts/update-task-status.sh"

write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 1901, "project_name": "g19_pending", "task_type": "general", "status": "not_started", "description": "durable pending_dispatch ledger", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
g19_guard_file="$WORKDIR/specs/1901_g19_pending/.orchestrator-loop-guard"
g19_real_dispatch_file="$WORKDIR/specs/1901_g19_pending/plans/01_fixture.md"
mkdir -p "$WORKDIR/specs/1901_g19_pending/plans"
echo "fixture" > "$g19_real_dispatch_file"
mkdir -p "$WORKDIR/specs/1901_g19_pending"

# Case 1: matching pending_dispatch (phase=plan, forced=false), dispatch_file present on disk.
cat > "$g19_guard_file" <<EOF
{"dispatch_seq_counter": 3, "cycle_count": 2, "pending_dispatch": {"seq": 3, "phase": "plan", "forced": false, "dispatch_file": "${g19_real_dispatch_file}", "recorded_at": "2026-01-01T00:00:00Z"}}
EOF
run_sut --session g19_sess_case1 -- 1901

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Group 19 case 1: SUT exits 0"
else
  fail "Group 19 case 1: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if echo "$LAST_STDERR" | grep -qF "UNCONSUMED DISPATCH REPLAY"; then
  pass "Group 19 case 1: logs the UNCONSUMED DISPATCH REPLAY notice"
else
  fail "Group 19 case 1: expected the UNCONSUMED DISPATCH REPLAY notice; got: '$LAST_STDERR'"
fi
if [ "$(jq -r '.cycle_count' "$g19_guard_file" 2>/dev/null)" = "2" ]; then
  pass "Group 19 case 1: the durable guard file's cycle_count is unchanged (never written by this engine any more)"
else
  fail "Group 19 case 1: expected cycle_count unchanged at 2; got: $(jq -r '.cycle_count' "$g19_guard_file" 2>/dev/null)"
fi
if [ "$(jq -r '.dispatch_seq_counter' "$g19_guard_file" 2>/dev/null)" = "3" ]; then
  pass "Group 19 case 1: the durable guard file's dispatch_seq_counter is unchanged by a replay (no extra --flush-seq)"
else
  fail "Group 19 case 1: expected durable dispatch_seq_counter unchanged at 3 after a replay; got: $(jq -r '.dispatch_seq_counter' "$g19_guard_file" 2>/dev/null)"
fi
g19_mt_state_1="$WORKDIR/specs/.orchestrator-multi-state-g19_sess_case1.json"
if [ "$(jq -r --arg t "1901" '.cycle_counts[$t] // 0' "$g19_mt_state_1" 2>/dev/null)" = "0" ]; then
  pass "Group 19 case 1: in-memory cycle_counts[1901] starts at 0 THIS run (per-run budget contract; NOT seeded from the durable cycle_count=2)"
else
  fail "Group 19 case 1: in-memory cycle_counts[1901] diverged from the per-run-zero-start contract: $(cat "$g19_mt_state_1" 2>/dev/null)"
fi
if [ "$(jq -r --arg t "1901" '.dispatch_seq[$t]' "$g19_mt_state_1" 2>/dev/null)" = "3" ]; then
  pass "Group 19 case 1: the recorded seq (3) is reused for dispatch_seq[1901], not a freshly minted one"
else
  fail "Group 19 case 1: expected dispatch_seq[1901]=3 (reused); got: $(jq -r --arg t "1901" '.dispatch_seq[$t]' "$g19_mt_state_1" 2>/dev/null)"
fi

# Case 2: phase mismatch (pending_dispatch recorded for "research", candidate actually dispatches
# "plan") -- must NOT replay; charges normally.
cat > "$g19_guard_file" <<EOF
{"dispatch_seq_counter": 3, "cycle_count": 2, "pending_dispatch": {"seq": 3, "phase": "research", "forced": false, "dispatch_file": "${g19_real_dispatch_file}", "recorded_at": "2026-01-01T00:00:00Z"}}
EOF
reset_lock_dirs
run_sut --session g19_sess_case2 -- 1901
if echo "$LAST_STDERR" | grep -qF "UNCONSUMED DISPATCH REPLAY"; then
  fail "Group 19 case 2: unexpectedly replayed despite a phase mismatch"
else
  pass "Group 19 case 2: a phase mismatch does not replay"
fi
g19_mt_state_2="$WORKDIR/specs/.orchestrator-multi-state-g19_sess_case2.json"
if [ "$(jq -r --arg t "1901" '.cycle_counts[$t] // 0' "$g19_mt_state_2" 2>/dev/null)" = "1" ]; then
  pass "Group 19 case 2: in-session cycle_counts[1901] charges normally (0 -> 1) on a phase mismatch"
else
  fail "Group 19 case 2: expected in-session cycle_counts[1901]=1 after a genuine charge; got: $(cat "$g19_mt_state_2" 2>/dev/null)"
fi
if [ "$(jq -r '.dispatch_seq_counter' "$g19_guard_file" 2>/dev/null)" = "4" ]; then
  pass "Group 19 case 2: the durable guard's dispatch_seq_counter durably advances (3 -> 4) on a genuine charge"
else
  fail "Group 19 case 2: expected durable dispatch_seq_counter=4 after a genuine charge; got: $(jq -r '.dispatch_seq_counter' "$g19_guard_file" 2>/dev/null)"
fi
if [ "$(jq -r '.cycle_count // "absent"' "$g19_guard_file" 2>/dev/null)" = "2" ]; then
  pass "Group 19 case 2: the durable guard's cycle_count stays untouched (never written by this engine any more)"
else
  fail "Group 19 case 2: durable cycle_count unexpectedly changed: $(jq -r '.cycle_count // "absent"' "$g19_guard_file" 2>/dev/null)"
fi

# Case 3: matching phase/forced, but the recorded dispatch_file no longer exists on disk -- must
# NOT replay (no proof of non-consumption); charges normally.
cat > "$g19_guard_file" <<EOF
{"dispatch_seq_counter": 3, "cycle_count": 2, "pending_dispatch": {"seq": 3, "phase": "plan", "forced": false, "dispatch_file": "${WORKDIR}/specs/1901_g19_pending/plans/99_never-existed.md", "recorded_at": "2026-01-01T00:00:00Z"}}
EOF
reset_lock_dirs
run_sut --session g19_sess_case3 -- 1901
if echo "$LAST_STDERR" | grep -qF "UNCONSUMED DISPATCH REPLAY"; then
  fail "Group 19 case 3: unexpectedly replayed despite a missing dispatch_file"
else
  pass "Group 19 case 3: a missing dispatch_file does not replay"
fi
g19_mt_state_3="$WORKDIR/specs/.orchestrator-multi-state-g19_sess_case3.json"
if [ "$(jq -r --arg t "1901" '.cycle_counts[$t] // 0' "$g19_mt_state_3" 2>/dev/null)" = "1" ]; then
  pass "Group 19 case 3: in-session cycle_counts[1901] charges normally (0 -> 1) when the dispatch_file is missing"
else
  fail "Group 19 case 3: expected in-session cycle_counts[1901]=1 after a genuine charge; got: $(cat "$g19_mt_state_3" 2>/dev/null)"
fi
if [ "$(jq -r '.dispatch_seq_counter' "$g19_guard_file" 2>/dev/null)" = "4" ]; then
  pass "Group 19 case 3: the durable guard's dispatch_seq_counter durably advances (3 -> 4) on a genuine charge"
else
  fail "Group 19 case 3: expected durable dispatch_seq_counter=4 after a genuine charge; got: $(jq -r '.dispatch_seq_counter' "$g19_guard_file" 2>/dev/null)"
fi

# Case 4: no pending_dispatch recorded at all (the ordinary case) -- charges normally, and
# records a fresh pending_dispatch for the NEXT invocation to potentially replay.
cat > "$g19_guard_file" <<EOF
{"dispatch_seq_counter": 3, "cycle_count": 2}
EOF
reset_lock_dirs
run_sut --session g19_sess_case4 -- 1901
g19_mt_state_4="$WORKDIR/specs/.orchestrator-multi-state-g19_sess_case4.json"
if [ "$(jq -r --arg t "1901" '.cycle_counts[$t] // 0' "$g19_mt_state_4" 2>/dev/null)" = "1" ]; then
  pass "Group 19 case 4: no pending_dispatch charges normally in-session (0 -> 1)"
else
  fail "Group 19 case 4: expected in-session cycle_counts[1901]=1; got: $(cat "$g19_mt_state_4" 2>/dev/null)"
fi
if [ "$(jq -r '.cycle_count // "absent"' "$g19_guard_file" 2>/dev/null)" = "2" ]; then
  pass "Group 19 case 4: the durable guard's cycle_count stays untouched (never written by this engine any more)"
else
  fail "Group 19 case 4: durable cycle_count unexpectedly changed: $(jq -r '.cycle_count // "absent"' "$g19_guard_file" 2>/dev/null)"
fi

# Note: dispatch_seq_counter DOES durably cross invocations now (unlike cycle_count): this fresh
# session's own (a2) seeding peeks the durable guard's dispatch_seq_counter=3, takes max(0,3)=3,
# and section (i) mints 3+1=4 -- so the freshly recorded pending_dispatch's seq is 4, matching
# the durable dispatch_seq_counter this same charge flushes via --flush-seq (also 4).
if jq -e '.pending_dispatch.phase == "plan" and .pending_dispatch.seq == 4' "$g19_guard_file" >/dev/null 2>&1; then
  pass "Group 19 case 4: a fresh pending_dispatch is recorded (seq=4, phase=plan) for a future invocation"
else
  fail "Group 19 case 4: expected a fresh pending_dispatch to be recorded with seq=4; got: $(cat "$g19_guard_file" 2>/dev/null)"
fi
if [ "$(jq -r '.dispatch_seq_counter' "$g19_guard_file" 2>/dev/null)" = "4" ]; then
  pass "Group 19 case 4: the durable guard's dispatch_seq_counter durably advances (3 -> 4)"
else
  fail "Group 19 case 4: expected durable dispatch_seq_counter=4; got: $(jq -r '.dispatch_seq_counter' "$g19_guard_file" 2>/dev/null)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 20: LIVE (non-degraded) classifier forwarding -- proves this script actually forwards
# --fast through to orchestrate-triage-classify.sh as --effort fast, as distinct from Group 13's
# degraded-fallback table merely having the branch hardcoded. Exercised through --dry-run against
# the REAL classifier. Groups 15/16 (upstream) overwrite BOTH orchestrate-triage-classify.sh and
# orchestrate-batch-admit.sh with always-"plan"/always-"admit" stubs and never restore them, so
# both are restored here first -- Group 13's own restore only covers the gap up to Group 14.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 20: live classifier forwarding (not_started research-first default, --fast escape hatch)"

cp "$CORE_DIR/orchestrate-triage-classify.sh" "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh"
cp "$CORE_DIR/orchestrate-batch-admit.sh" "$WORKDIR/.claude/scripts/orchestrate-batch-admit.sh"
chmod +x "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh" "$WORKDIR/.claude/scripts/orchestrate-batch-admit.sh"

write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2001, "project_name": "g20_not_started", "task_type": "general", "status": "not_started", "description": "fresh task, live-classifier research-first default check", "dependencies": [], "file_scope": []},
    {"project_number": 2002, "project_name": "g20_researched", "task_type": "general", "status": "researched", "description": "already researched, must never re-research", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
run_sut --session g20_sess --dry-run -- 2001 2002

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Group 20: SUT exits 0 (no --fast)"
else
  fail "Group 20: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi

if [ "$(jqf '.dispatch | map(select(.task == 2001)) | .[0].phase')" = "research" ]; then
  pass "Group 20: live classifier routes not_started -> research with no --fast (research-first default)"
else
  fail "Group 20: expected not_started candidate #2001 to route to research, got: $(jqf '.dispatch | map(select(.task == 2001))')"
fi

if [ "$(jqf '.dispatch | map(select(.task == 2002)) | .[0].phase')" = "plan" ]; then
  pass "Group 20: live classifier keeps researched -> plan with no --fast (never re-researches)"
else
  fail "Group 20: expected researched candidate #2002 to route to plan, got: $(jqf '.dispatch | map(select(.task == 2002))')"
fi

reset_lock_dirs
run_sut --session g20_sess_fast --dry-run --fast -- 2001 2002

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Group 20 (--fast): SUT exits 0"
else
  fail "Group 20 (--fast): SUT exited $LAST_EXIT ($LAST_STDERR)"
fi

if [ "$(jqf '.dispatch | map(select(.task == 2001)) | .[0].phase')" = "plan" ]; then
  pass "Group 20 (--fast): live classifier routes not_started -> plan (the pre-research-first escape hatch), proving --fast actually reaches --effort"
else
  fail "Group 20 (--fast): expected not_started candidate #2001 to route to plan, got: $(jqf '.dispatch | map(select(.task == 2001))')"
fi

if [ "$(jqf '.dispatch | map(select(.task == 2002)) | .[0].phase')" = "plan" ]; then
  pass "Group 20 (--fast): live classifier keeps researched -> plan under --fast too (never re-researches)"
else
  fail "Group 20 (--fast): expected researched candidate #2002 to route to plan, got: $(jqf '.dispatch | map(select(.task == 2002))')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 21: forced phase on terminal and archived tasks (task acceptance, Cases A-E)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 21: forced phase on terminal and archived tasks (Cases A-E)"

# Restore the REAL classify/admit collaborators -- a prior group (13/15/16) may have left a stub
# in place, same precaution Group 20 takes. Also install the REAL orchestrate-build-dispatch.sh,
# update-task-status.sh, state-write.sh, and generate-todo.sh (never stubbed anywhere in this
# file until now) plus lib/status-vocabulary.sh (update-task-status.sh's own VOCAB_LIB
# dependency, not previously needed by any earlier group) -- Case B needs the REAL
# orchestrate-build-dispatch.sh to actually resolve TASK_DIR via task_lookup_dir, and Case D
# needs the REAL update-task-status.sh (not Groups 4/5's stub) so the preflight clamp exercises
# real map_status()/state.json read-modify-write, per this phase's own verification requirement.
cp "$CORE_DIR/orchestrate-triage-classify.sh" "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh"
cp "$CORE_DIR/orchestrate-batch-admit.sh" "$WORKDIR/.claude/scripts/orchestrate-batch-admit.sh"
cp "$CORE_DIR/orchestrate-build-dispatch.sh" "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh"
cp "$CORE_DIR/update-task-status.sh" "$WORKDIR/.claude/scripts/update-task-status.sh"
cp "$CORE_DIR/state-write.sh" "$WORKDIR/.claude/scripts/state-write.sh"
cp "$CORE_DIR/generate-todo.sh" "$WORKDIR/.claude/scripts/generate-todo.sh"
cp "$CORE_DIR/lib/status-vocabulary.sh" "$WORKDIR/.claude/scripts/lib/status-vocabulary.sh"
chmod +x "$WORKDIR"/.claude/scripts/*.sh

# ── Case A: active terminal, forced -- must dispatch, must NOT stop at all_terminal ─────────────
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2101, "project_name": "g21a_active_completed", "task_type": "general", "status": "completed", "description": "active terminal task, forced research", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g21a.json"
run_sut --session g21a --dry-run --force-phases research -- 2101
if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Case A: SUT exits 0"
else
  fail "Case A: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if [ "$(jqf '.dispatch | map(select(.task == 2101 and .phase == "research" and .force == true)) | length')" = "1" ]; then
  pass "Case A: active-terminal candidate #2101 dispatches with phase=research, force=true"
else
  fail "Case A: candidate #2101 did not dispatch as forced research (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.stop')" = "null" ]; then
  pass "Case A: does NOT stop with all_terminal (the forced-phase exemption keeps all_done false)"
else
  fail "Case A: unexpectedly stopped: $(jqf '.stop')"
fi

# ── Case B: archived terminal, forced -- dispatches into specs/archive/{NNN}_{slug}/ ────────────
mkdir -p "$WORKDIR/specs/archive"
cat > "$WORKDIR/specs/archive/state.json" <<'EOF'
{
  "completed_projects": [
    {"project_number": 2102, "project_name": "g21b_archived_completed", "status": "completed", "next_artifact_number": 2}
  ]
}
EOF
write_state <<'EOF'
{
  "active_projects": []
}
EOF
rm -rf "$WORKDIR/specs/archive/2102_g21b_archived_completed"
mkdir -p "$WORKDIR/specs/archive/2102_g21b_archived_completed/reports"
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g21b.json"
run_sut --session g21b --force-phases research -- 2102
if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Case B: SUT exits 0 (LIVE)"
else
  fail "Case B: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
b_dispatch_file=$(jqf '.dispatch | map(select(.task == 2102)) | .[0].dispatch_file // ""')
if [[ "$b_dispatch_file" == *"/specs/archive/2102_g21b_archived_completed/"* ]]; then
  pass "Case B: archived-terminal candidate #2102's dispatch_file lands under specs/archive/ (got: $b_dispatch_file)"
else
  fail "Case B: expected dispatch_file under specs/archive/2102_g21b_archived_completed/, got: '$b_dispatch_file' (stdout: $LAST_STDOUT, stderr: $LAST_STDERR)"
fi
if [ -n "$b_dispatch_file" ] && [ -f "$b_dispatch_file" ]; then
  pass "Case B: the dispatch file was actually written to disk"
else
  fail "Case B: dispatch file '$b_dispatch_file' does not exist on disk"
fi
b_status_after=$(jq -r '.completed_projects[] | select(.project_number == 2102) | .status' "$WORKDIR/specs/archive/state.json")
if [ "$b_status_after" = "completed" ]; then
  pass "Case B: archive/state.json status is untouched (still completed; the archive read is read-only)"
else
  fail "Case B: archive/state.json status unexpectedly changed to '$b_status_after'"
fi

# ── Case C: unforced terminal -- must still stop at all_terminal, zero dispatch rows ────────────
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2103, "project_name": "g21c_unforced_terminal", "task_type": "general", "status": "completed", "description": "unforced terminal must still stop", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g21c.json"
run_sut --session g21c --dry-run -- 2103
if [ "$(jqf '.stop.reason')" = "all_terminal" ]; then
  pass "Case C: unforced terminal candidate #2103 stops with all_terminal (Non-Goal regression guard)"
else
  fail "Case C: expected stop_reason all_terminal, got: $(jqf '.stop') (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.dispatch | length')" = "0" ]; then
  pass "Case C: zero dispatch rows for the unforced terminal candidate"
else
  fail "Case C: expected zero dispatch rows, got: $LAST_STDOUT"
fi

# ── Case D: LIVE no-regression -- REAL update-task-status.sh, status stays completed ────────────
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2105, "project_name": "g21d_live_no_regression", "task_type": "general", "status": "completed", "description": "live forced research round must not regress status", "dependencies": [], "file_scope": [], "next_artifact_number": 2}
  ]
}
EOF
rm -rf "$WORKDIR/specs/2105_g21d_live_no_regression"
mkdir -p "$WORKDIR/specs/2105_g21d_live_no_regression/reports"
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g21d.json"
d_status_before=$(jq -r '.active_projects[] | select(.project_number == 2105) | .status' "$WORKDIR/specs/state.json")
run_sut --session g21d --force-phases research -- 2105
d_status_after=$(jq -r '.active_projects[] | select(.project_number == 2105) | .status' "$WORKDIR/specs/state.json")
if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Case D: LIVE forced round exits 0"
else
  fail "Case D: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if [ "$d_status_before" = "completed" ] && [ "$d_status_after" = "completed" ]; then
  pass "Case D: state.json status is 'completed' both before and after the LIVE forced round (no regression)"
else
  fail "Case D: status regressed -- before='$d_status_before' after='$d_status_after' (stderr: $LAST_STDERR)"
fi
if echo "$LAST_STDERR" | grep -q '\[monotonic-max\]'; then
  pass "Case D: the preflight clamp actually fired (named [monotonic-max] notice present on stderr)"
else
  fail "Case D: expected a [monotonic-max] clamp notice on stderr; got: $LAST_STDERR"
fi
if [ "$(jqf '.dispatch | map(select(.task == 2105)) | length')" = "1" ]; then
  pass "Case D: candidate #2105 still dispatches despite the clamp skipping the status write"
else
  fail "Case D: candidate #2105 did not dispatch (stdout: $LAST_STDOUT)"
fi

# ── Case E: --force-phases implement on a completed task dispatches (Decision (c)) -- WITH a
# plan artifact present (Phase 5's artifact-based admission rule requires one for implement;
# a terminal status alone is not enough, matching the same rule Group 23 tests in full below).
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2104, "project_name": "g21e_forced_implement", "task_type": "general", "status": "completed", "description": "forced implement on completed task", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -rf "$WORKDIR/specs/2104_g21e_forced_implement"
mkdir -p "$WORKDIR/specs/2104_g21e_forced_implement/plans"
printf '# Fixture plan\n\n### Phase 1: Fixture phase [NOT STARTED]\n' > "$WORKDIR/specs/2104_g21e_forced_implement/plans/01_fixture-plan.md"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g21e.json"
run_sut --session g21e --dry-run --force-phases implement -- 2104
if [ "$(jqf '.dispatch | map(select(.task == 2104 and .phase == "implement" and .force == true)) | length')" = "1" ]; then
  pass "Case E: --force-phases implement on a completed task WITH a plan dispatches with phase=implement, force=true"
else
  fail "Case E: candidate #2104 did not dispatch as forced implement (stdout: $LAST_STDOUT)"
fi

# ── Regression guard: Group 10 Case I's failed_tasks-driven all_terminal fixture must remain
# untouched by this group's changes (it is re-run implicitly by being earlier in this same file;
# nothing here re-executes it -- this comment simply records that the assertion was NOT modified
# to accommodate the forced-phase exemption predicate, matching the Verification note above). ────

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 22: --focus threading (Phase 1 of the focus/forced-phase/cycle-budget task) -- the user's
# own free-form --focus text reaches the LIVE dispatch file's "User focus:" block, composed with
# any task-level research_questions without either silently replacing the other, and surfaced
# under --dry-run before any live run. Reuses Group 21's already-installed REAL
# orchestrate-build-dispatch.sh/update-task-status.sh/state-write.sh/generate-todo.sh (no stub
# involvement here -- the whole point is the file actually written to disk). Fixture style
# borrowed from Group 14 (research_questions wiring) and Group 21 Case D (real-collaborator LIVE
# forced round).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 22: --focus threading into the live dispatch file's User focus: block"

# ── Case A: --focus alone (no research_questions) -- forced research dispatch ───────────────────
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2201, "project_name": "g22a_focus_only", "task_type": "meta", "status": "not_started", "description": "focus text alone, no research_questions", "dependencies": [], "file_scope": []}
  ]
}
EOF
rm -rf "$WORKDIR/specs/2201_g22a_focus_only"
mkdir -p "$WORKDIR/specs/2201_g22a_focus_only/reports"
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g22a.json"
run_sut --session g22a --force-phases research --focus "Q1? Q2?" -- 2201
if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Group 22 Case A: SUT exits 0"
else
  fail "Group 22 Case A: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
g22a_dispatch_file=$(jqf '.dispatch | map(select(.task == 2201)) | .[0].dispatch_file // ""')
if [ -n "$g22a_dispatch_file" ] && [ -f "$g22a_dispatch_file" ] && \
   grep -qF "User focus: From the user: Q1? Q2?" "$g22a_dispatch_file"; then
  pass "Group 22 Case A: dispatch file carries a User focus: block with the --focus text"
else
  fail "Group 22 Case A: expected 'User focus: From the user: Q1? Q2?' in '$g22a_dispatch_file' (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.dispatch | map(select(.task == 2201)) | .[0].focus // ""')" = "From the user: Q1? Q2?" ]; then
  pass "Group 22 Case A: the composed .dispatch[].focus row field matches"
else
  fail "Group 22 Case A: unexpected .dispatch[].focus: $(jqf '.dispatch')"
fi

# ── Case B: --focus AND research_questions both present -- both labelled segments appear ───────
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2202, "project_name": "g22b_focus_and_rq", "task_type": "meta", "status": "researching", "description": "focus text plus research_questions", "dependencies": [], "file_scope": [], "research_questions": ["Does X exist?", "Is Y true?"]}
  ]
}
EOF
rm -rf "$WORKDIR/specs/2202_g22b_focus_and_rq"
mkdir -p "$WORKDIR/specs/2202_g22b_focus_and_rq/reports"
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g22b.json"
run_sut --session g22b --force-phases research --focus "Extra context here" -- 2202
g22b_dispatch_file=$(jqf '.dispatch | map(select(.task == 2202)) | .[0].dispatch_file // ""')
if [ -n "$g22b_dispatch_file" ] && [ -f "$g22b_dispatch_file" ] && \
   grep -qF "From the user: Extra context here" "$g22b_dispatch_file" && \
   grep -qF "Research questions: Does X exist?; Is Y true?" "$g22b_dispatch_file"; then
  pass "Group 22 Case B: dispatch file carries BOTH labelled segments; neither replaced the other"
else
  fail "Group 22 Case B: expected both labelled segments in '$g22b_dispatch_file' (stdout: $LAST_STDOUT)"
fi

# ── Case C: no --focus, research_questions present -- byte-for-byte identical to Group 14's
#    pre-existing (bare, unlabelled) output; this is the Non-Goal regression guard ──────────────
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2203, "project_name": "g22c_rq_only_no_focus", "task_type": "meta", "status": "researching", "description": "research_questions only, no user focus text", "dependencies": [], "file_scope": [], "research_questions": ["Only RQ present"]}
  ]
}
EOF
rm -rf "$WORKDIR/specs/2203_g22c_rq_only_no_focus"
mkdir -p "$WORKDIR/specs/2203_g22c_rq_only_no_focus/reports"
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g22c.json"
run_sut --session g22c --force-phases research -- 2203
g22c_dispatch_file=$(jqf '.dispatch | map(select(.task == 2203)) | .[0].dispatch_file // ""')
if [ -n "$g22c_dispatch_file" ] && [ -f "$g22c_dispatch_file" ] && \
   grep -qxF "User focus: Only RQ present" "$g22c_dispatch_file"; then
  pass "Group 22 Case C: no --focus -> bare research_questions line, no label (byte-for-byte unchanged)"
else
  fail "Group 22 Case C: expected exact line 'User focus: Only RQ present' with no label in '$g22c_dispatch_file' (stdout: $LAST_STDOUT)"
fi
if ! grep -qF "From the user:" "$g22c_dispatch_file" 2>/dev/null && ! grep -qF "Research questions:" "$g22c_dispatch_file" 2>/dev/null; then
  pass "Group 22 Case C: neither label string appears anywhere in the dispatch file"
else
  fail "Group 22 Case C: an unexpected label string leaked into the dispatch file"
fi

# ── Case D: a --focus value containing spaces AND an embedded double quote survives intact ──────
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2204, "project_name": "g22d_focus_quotes_spaces", "task_type": "meta", "status": "not_started", "description": "focus text with spaces and an embedded double quote", "dependencies": [], "file_scope": []}
  ]
}
EOF
rm -rf "$WORKDIR/specs/2204_g22d_focus_quotes_spaces"
mkdir -p "$WORKDIR/specs/2204_g22d_focus_quotes_spaces/reports"
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g22d.json"
run_sut --session g22d --force-phases research --focus 'has "quoted" words and spaces' -- 2204
g22d_dispatch_file=$(jqf '.dispatch | map(select(.task == 2204)) | .[0].dispatch_file // ""')
if [ -n "$g22d_dispatch_file" ] && [ -f "$g22d_dispatch_file" ] && \
   grep -qF 'User focus: From the user: has "quoted" words and spaces' "$g22d_dispatch_file"; then
  pass "Group 22 Case D: a focus value with spaces and an embedded double quote survives intact"
else
  fail "Group 22 Case D: expected the quoted/spaced focus text intact in '$g22d_dispatch_file' (stdout: $LAST_STDOUT)"
fi

# ── Case E: --dry-run with --focus surfaces a non-empty .dispatch[].focus before any live run ───
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2205, "project_name": "g22e_dry_run_focus", "task_type": "meta", "status": "not_started", "description": "dry-run focus surfacing", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g22e.json"
run_sut --session g22e --dry-run --force-phases research --focus "dry run focus text" -- 2205
if [ "$(jqf '.dispatch | map(select(.task == 2205)) | .[0].focus // ""')" = "From the user: dry run focus text" ]; then
  pass "Group 22 Case E: --dry-run emits a non-empty .dispatch[].focus carrying the --focus text"
else
  fail "Group 22 Case E: expected a non-empty .dispatch[].focus under --dry-run, got: $(jqf '.dispatch')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 23: Phase 5 -- artifact-based admission for forced plan and implement. One admission
# rule, keyed on artifacts alone: implement admitted only when plans/*.md exists (else blocked,
# "no plan artifact; run --plan first"); plan always admitted (reviser-agent when a plan exists,
# planner-agent otherwise). All cases forced (--force-phases), at ordinary AND terminal status,
# proving the rule is artifact-keyed, never status-keyed. Reuses Group 21's already-installed
# REAL orchestrate-build-dispatch.sh/update-task-status.sh/state-write.sh (LIVE dispatch actually
# writes files and reads reviser-agent.md's own field names).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 23: artifact-based admission for forced plan and implement"

# ── Case A: --implement on a RESEARCHED task WITH a plan dispatches implement ───────────────────
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2301, "project_name": "g23a_implement_with_plan", "task_type": "general", "status": "researched", "description": "forced implement, plan present", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -rf "$WORKDIR/specs/2301_g23a_implement_with_plan"
mkdir -p "$WORKDIR/specs/2301_g23a_implement_with_plan/plans"
printf '# Fixture plan\n\n### Phase 1: Fixture phase [NOT STARTED]\n' > "$WORKDIR/specs/2301_g23a_implement_with_plan/plans/01_fixture-plan.md"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g23a.json"
run_sut --session g23a --force-phases implement -- 2301
if [ "$(jqf '.dispatch | map(select(.task == 2301 and .phase == "implement" and .force == true)) | length')" = "1" ]; then
  pass "Group 23 Case A: --implement on a RESEARCHED task WITH a plan dispatches implement"
else
  fail "Group 23 Case A: expected a forced implement dispatch for candidate #2301, got: $LAST_STDOUT"
fi

# ── Case B: --implement on a task with NO plan yields exactly one blocked[] row; no dispatch
# file, lock, or status write ────────────────────────────────────────────────────────────────────
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2302, "project_name": "g23b_implement_no_plan", "task_type": "general", "status": "researched", "description": "forced implement, no plan present", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -rf "$WORKDIR/specs/2302_g23b_implement_no_plan"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g23b.json"
g23b_status_before=$(jq -r '.active_projects[] | select(.project_number == 2302) | .status' "$STATE_FILE")
run_sut --session g23b --force-phases implement -- 2302
g23b_status_after=$(jq -r '.active_projects[] | select(.project_number == 2302) | .status' "$STATE_FILE")
if [ "$(jqf '.blocked | map(select(.task == 2302 and (.reason == "no plan artifact; run --plan first"))) | length')" = "1" ]; then
  pass "Group 23 Case B: --implement with no plan yields exactly one blocked[] row with the named reason"
else
  fail "Group 23 Case B: expected the no-plan blocked[] row, got: $LAST_STDOUT"
fi
if [ "$(jqf '.dispatch | map(select(.task == 2302)) | length')" = "0" ]; then
  pass "Group 23 Case B: no dispatch row for candidate #2302"
else
  fail "Group 23 Case B: unexpectedly dispatched candidate #2302 (stdout: $LAST_STDOUT)"
fi
if [ ! -d "$WORKDIR/specs/2302_g23b_implement_no_plan/.dispatch" ]; then
  pass "Group 23 Case B: no .dispatch/ directory or file was created"
else
  fail "Group 23 Case B: a .dispatch/ directory was unexpectedly created"
fi
if [ ! -d "$WORKDIR/specs/2302_g23b_implement_no_plan/.lock" ]; then
  pass "Group 23 Case B: no task lock was taken"
else
  fail "Group 23 Case B: a .lock/ directory was unexpectedly created"
fi
if [ "$g23b_status_before" = "$g23b_status_after" ]; then
  pass "Group 23 Case B: status unchanged (no status write) -- before='$g23b_status_before' after='$g23b_status_after'"
else
  fail "Group 23 Case B: status changed -- before='$g23b_status_before' after='$g23b_status_after'"
fi

# ── Case C: --plan with an existing plan resolves reviser-agent; dispatch file carries
# existing_plan_path (the field name agents/reviser-agent.md reads) ────────────────────────────
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2303, "project_name": "g23c_plan_revise", "task_type": "general", "status": "researched", "description": "forced plan round, plan present -- revise", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -rf "$WORKDIR/specs/2303_g23c_plan_revise"
mkdir -p "$WORKDIR/specs/2303_g23c_plan_revise/plans" "$WORKDIR/specs/2303_g23c_plan_revise/reports"
printf '# Fixture plan\n\n### Phase 1: Fixture phase [NOT STARTED]\n' > "$WORKDIR/specs/2303_g23c_plan_revise/plans/01_fixture-plan.md"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g23c.json"
run_sut --session g23c --force-phases plan -- 2303
if [ "$(jqf '.dispatch | map(select(.task == 2303)) | .[0].agent // ""')" = "reviser-agent" ]; then
  pass "Group 23 Case C: --plan with an existing plan resolves reviser-agent"
else
  fail "Group 23 Case C: expected agent=reviser-agent for candidate #2303, got: $LAST_STDOUT"
fi
g23c_dispatch_file=$(jqf '.dispatch | map(select(.task == 2303)) | .[0].dispatch_file // ""')
if [ -n "$g23c_dispatch_file" ] && [ -f "$g23c_dispatch_file" ] && \
   grep -qF "existing_plan_path: specs/2303_g23c_plan_revise/plans/01_fixture-plan.md" "$g23c_dispatch_file" && \
   grep -qF "revision_reason: forced --plan round" "$g23c_dispatch_file"; then
  pass "Group 23 Case C: dispatch file carries existing_plan_path and revision_reason"
else
  fail "Group 23 Case C: expected existing_plan_path/revision_reason in '$g23c_dispatch_file'"
fi

# ── Case D: --plan with no plan resolves planner-agent (ordinary path, unchanged) ───────────────
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2304, "project_name": "g23d_plan_author", "task_type": "general", "status": "not_started", "description": "forced plan round, no plan present -- author", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -rf "$WORKDIR/specs/2304_g23d_plan_author"
mkdir -p "$WORKDIR/specs/2304_g23d_plan_author/reports"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g23d.json"
run_sut --session g23d --force-phases plan -- 2304
if [ "$(jqf '.dispatch | map(select(.task == 2304)) | .[0].agent // ""')" = "planner-agent" ]; then
  pass "Group 23 Case D: --plan with no plan resolves planner-agent"
else
  fail "Group 23 Case D: expected agent=planner-agent for candidate #2304, got: $LAST_STDOUT"
fi

# ── Case E: both plan admission modes are admitted at TERMINAL status too, proving the rule is
# artifact-keyed, never status-keyed (mirrors Group 21's forced-admits-terminal contract) ──────
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2305, "project_name": "g23e_terminal_plan_revise", "task_type": "general", "status": "completed", "description": "terminal task, forced plan round, plan present", "dependencies": [], "file_scope": []},
    {"project_number": 2306, "project_name": "g23f_terminal_plan_author", "task_type": "general", "status": "abandoned", "description": "terminal task, forced plan round, no plan present", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -rf "$WORKDIR/specs/2305_g23e_terminal_plan_revise" "$WORKDIR/specs/2306_g23f_terminal_plan_author"
mkdir -p "$WORKDIR/specs/2305_g23e_terminal_plan_revise/plans"
printf '# Fixture plan\n\n### Phase 1: Fixture phase [NOT STARTED]\n' > "$WORKDIR/specs/2305_g23e_terminal_plan_revise/plans/01_fixture-plan.md"
mkdir -p "$WORKDIR/specs/2306_g23f_terminal_plan_author"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g23ef.json"
run_sut --session g23ef --dry-run --force-phases plan -- 2305 2306
if [ "$(jqf '.dispatch | map(select(.task == 2305)) | .[0].agent // ""')" = "reviser-agent" ]; then
  pass "Group 23 Case E: terminal (completed) task with a plan still resolves reviser-agent when forced"
else
  fail "Group 23 Case E: expected agent=reviser-agent for terminal candidate #2305, got: $LAST_STDOUT"
fi
if [ "$(jqf '.dispatch | map(select(.task == 2306)) | .[0].agent // ""')" = "planner-agent" ]; then
  pass "Group 23 Case E: terminal (abandoned) task with no plan still resolves planner-agent when forced"
else
  fail "Group 23 Case E: expected agent=planner-agent for terminal candidate #2306, got: $LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 24: orchestrate-unwind-dispatch.sh pre-image capture -- `pending_dispatch` gains the four
# `prior_*` fields (prior_status, prior_last_updated, prior_session_id, prior_dispatch_seq_counter)
# on a genuine (non-replay) live charge, captured from the task's state.json entry and durable
# guard file BEFORE this cycle's own preflight write / --flush-seq overwrite them. A replay of an
# already-charged, never-consumed dispatch must leave the existing record -- pre-image included --
# completely untouched (Risk table's #1 concern: a replay must never record the CURRENT, already
# in-flight status as if it were the pre-dispatch one). REAL orchestrate-build-dispatch.sh,
# update-task-status.sh, state-write.sh, and generate-todo.sh are already installed by Group 21
# above and never re-stubbed since -- this group relies on that real end-to-end write path.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 24: pending_dispatch pre-image capture (prior_* fields) and replay non-overwrite"

write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2401, "project_name": "g24_prior_image", "task_type": "general", "status": "researched", "description": "pre-image capture fixture", "dependencies": [], "file_scope": [], "last_updated": "2020-01-01T00:00:00Z", "session_id": "sess_before_case1"}
  ]
}
EOF
rm -rf "$WORKDIR/specs/2401_g24_prior_image"
mkdir -p "$WORKDIR/specs/2401_g24_prior_image"
jq -n '{dispatch_seq_counter: 7}' > "$WORKDIR/specs/2401_g24_prior_image/.orchestrator-loop-guard"
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g24_case1.json"

run_sut --session g24_case1 --force-phases plan -- 2401
g24_guard_file="$WORKDIR/specs/2401_g24_prior_image/.orchestrator-loop-guard"

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Group 24 case 1: LIVE forced plan round exits 0"
else
  fail "Group 24 case 1: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if [ "$(jq -r '.pending_dispatch.prior_status // ""' "$g24_guard_file" 2>/dev/null)" = "researched" ]; then
  pass "Group 24 case 1: pending_dispatch.prior_status captures the pre-dispatch status ('researched')"
else
  fail "Group 24 case 1: expected prior_status='researched'; got: $(cat "$g24_guard_file" 2>/dev/null)"
fi
if [ "$(jq -r '.pending_dispatch.prior_last_updated // ""' "$g24_guard_file" 2>/dev/null)" = "2020-01-01T00:00:00Z" ]; then
  pass "Group 24 case 1: pending_dispatch.prior_last_updated captures the pre-dispatch last_updated"
else
  fail "Group 24 case 1: expected prior_last_updated='2020-01-01T00:00:00Z'; got: $(cat "$g24_guard_file" 2>/dev/null)"
fi
if [ "$(jq -r '.pending_dispatch.prior_session_id // ""' "$g24_guard_file" 2>/dev/null)" = "sess_before_case1" ]; then
  pass "Group 24 case 1: pending_dispatch.prior_session_id captures the pre-dispatch session_id"
else
  fail "Group 24 case 1: expected prior_session_id='sess_before_case1'; got: $(cat "$g24_guard_file" 2>/dev/null)"
fi
if [ "$(jq -r '.pending_dispatch.prior_dispatch_seq_counter // -1' "$g24_guard_file" 2>/dev/null)" = "7" ]; then
  pass "Group 24 case 1: pending_dispatch.prior_dispatch_seq_counter captures the pre-charge durable counter (7)"
else
  fail "Group 24 case 1: expected prior_dispatch_seq_counter=7; got: $(cat "$g24_guard_file" 2>/dev/null)"
fi
if [ "$(jq -r '.dispatch_seq_counter' "$g24_guard_file" 2>/dev/null)" = "8" ]; then
  pass "Group 24 case 1: the durable dispatch_seq_counter itself advances normally (7 -> 8) alongside the pre-image"
else
  fail "Group 24 case 1: expected dispatch_seq_counter=8 after the charge; got: $(cat "$g24_guard_file" 2>/dev/null)"
fi
g24_status_after_case1=$(jq -r '.active_projects[] | select(.project_number == 2401) | .status' "$WORKDIR/specs/state.json")
if [ "$g24_status_after_case1" != "researched" ]; then
  pass "Group 24 case 1: state.json status actually changed away from the captured pre-image ('$g24_status_after_case1')"
else
  fail "Group 24 case 1: expected state.json status to change from 'researched'; still researched"
fi

# Snapshot the full pending_dispatch record before the replay run, to prove it is byte-for-byte
# untouched afterward (not merely that the four prior_* fields individually still read the same).
g24_pending_before_case2="$(jq -c '.pending_dispatch' "$g24_guard_file" 2>/dev/null)"

reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g24_case2.json"
run_sut --session g24_case2 --force-phases plan -- 2401

if echo "$LAST_STDERR" | grep -qF "UNCONSUMED DISPATCH REPLAY"; then
  pass "Group 24 case 2: a same-phase, file-present re-dispatch replays instead of re-charging"
else
  fail "Group 24 case 2: expected an UNCONSUMED DISPATCH REPLAY notice; got stderr: $LAST_STDERR"
fi
g24_pending_after_case2="$(jq -c '.pending_dispatch' "$g24_guard_file" 2>/dev/null)"
if [ "$g24_pending_after_case2" = "$g24_pending_before_case2" ]; then
  pass "Group 24 case 2: the replay leaves the ENTIRE pending_dispatch record (pre-image included) byte-for-byte untouched"
else
  fail "Group 24 case 2: replay unexpectedly mutated pending_dispatch -- before: $g24_pending_before_case2 -- after: $g24_pending_after_case2"
fi
if [ "$(jq -r '.dispatch_seq_counter' "$g24_guard_file" 2>/dev/null)" = "8" ]; then
  pass "Group 24 case 2: the durable dispatch_seq_counter is unchanged by a replay (no extra --flush-seq)"
else
  fail "Group 24 case 2: expected dispatch_seq_counter unchanged at 8 after a replay; got: $(cat "$g24_guard_file" 2>/dev/null)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 25: Base-mode sibling territory fixture (the task that carries concurrent-sibling
# territory into base-mode dispatch briefs) -- reproduces the observed batch shape: concurrent
# implement dispatches with mixed declared-scope granularity, one with a narrow file scope, one
# with no declared scope at all, and one with a coarse (directory) scope. orchestrate-build-dispatch.sh
# is stubbed to just echo its argv (this suite's own convention -- Group 9 Case C tests --territory
# the same way), so assertions inspect the exact --territory JSON string the SUT builds and passes,
# rather than a rendered dispatch file (that half -- ## Territory + the territory.md pointer --
# is Group 13 of test-orchestrate-build-dispatch.sh's job, not this suite's).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 25: base-mode sibling territory (mixed granularity, single-task regression, hard-mode merge)"

G25_ARGV_LOG="$WORKDIR/g25-build-dispatch-argv.log"
: > "$G25_ARGV_LOG"
cat > "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$G25_ARGV_LOG"
proj_num="\$1"; phase="\$2"
jq -n -c --arg f "/fake/\${proj_num}-\${phase}.md" '{dispatch_file: \$f, model: ""}'
EOF
chmod +x "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh"
cat > "$WORKDIR/.claude/scripts/update-task-status.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$WORKDIR/.claude/scripts/update-task-status.sh"

# Cases A-C: three concurrently-scheduled `planned` tasks (all resolve to the implement group).
# 2501 declares a narrow, single-file scope (the observed two-file proof-tactic sweep). 2502
# OMITS the file_scope key entirely (the observed tree-wide rename that declared no scope at all).
# 2503 declares a directory-granularity scope (the RECURRED four-task batch's coarse-declaration
# shape) plus an explicitly empty array (2504), proving `[]` renders identically to absent.
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2501, "project_name": "g25_narrow", "task_type": "general", "status": "planned", "description": "narrow single-file scope", "dependencies": [], "file_scope": ["FormalSystem/Metalogic/Soundness.lean"]},
    {"project_number": 2502, "project_name": "g25_undeclared", "task_type": "general", "status": "planned", "description": "no file_scope key at all (tree-wide rename case)"},
    {"project_number": 2503, "project_name": "g25_coarse", "task_type": "general", "status": "planned", "description": "directory-granularity scope", "dependencies": [], "file_scope": ["docs/"]},
    {"project_number": 2504, "project_name": "g25_empty_array", "task_type": "general", "status": "planned", "description": "explicitly empty file_scope array", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
: > "$G25_ARGV_LOG"
run_sut --session g25_sess -- 2501 2502 2503 2504

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "Group 25 (Cases A-C): SUT exits 0"
else
  fail "Group 25 (Cases A-C): SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if [ "$(jqf '.dispatch | length')" = "4" ]; then
  pass "Group 25 (Cases A-C): all four siblings dispatch this cycle"
else
  fail "Group 25 (Cases A-C): expected 4 dispatch rows; got: $LAST_STDOUT"
fi

# Case A: #2501's own --territory names #2502 (undeclared) and shows the undeclared sentinel.
g25_2501_argv=$(grep '^2501 implement' "$G25_ARGV_LOG" || true)
if echo "$g25_2501_argv" | grep -q -- "--territory"; then
  pass "Case A: #2501 receives --territory"
else
  fail "Case A: --territory missing from #2501's argv ('$g25_2501_argv')"
fi
if echo "$g25_2501_argv" | grep -q '"task_number":2502' && \
   echo "$g25_2501_argv" | grep -q '"scope_declared":false' && \
   echo "$g25_2501_argv" | grep -q '"scope_granularity":"undeclared"'; then
  pass "Case A: #2501's territory names sibling #2502 as undeclared (scope_declared=false)"
else
  fail "Case A: #2501's territory missing the undeclared #2502 entry (argv: '$g25_2501_argv')"
fi
if echo "$g25_2501_argv" | grep -q "context/contracts/territory.md"; then
  pass "Case A: #2501's concurrency_note cites context/contracts/territory.md"
else
  fail "Case A: territory.md citation missing from #2501's concurrency_note"
fi

# Case B: #2502's own --territory names #2501 with its exact file and granularity=file.
g25_2502_argv=$(grep '^2502 implement' "$G25_ARGV_LOG" || true)
if echo "$g25_2502_argv" | grep -q '"task_number":2501' && \
   echo "$g25_2502_argv" | grep -q "FormalSystem/Metalogic/Soundness.lean" && \
   echo "$g25_2502_argv" | grep -q '"granularity":"file"'; then
  pass "Case B: #2502's territory names sibling #2501 with its exact file and granularity=file"
else
  fail "Case B: #2502's territory missing the file-granularity #2501 entry (argv: '$g25_2502_argv')"
fi

# Case C: #2501's territory also names #2503 as coarse/directory, and #2504 (empty array) as
# undeclared -- identical rendering to #2502's absent-key case.
if echo "$g25_2501_argv" | grep -q '"task_number":2503' && \
   echo "$g25_2501_argv" | grep -q '"granularity":"directory"' && \
   echo "$g25_2501_argv" | grep -q '"scope_granularity":"coarse"'; then
  pass "Case C: #2501's territory names sibling #2503 as coarse/directory"
else
  fail "Case C: #2501's territory missing the coarse #2503 entry (argv: '$g25_2501_argv')"
fi
if echo "$g25_2501_argv" | grep -q '"task_number":2504' && \
   echo "$g25_2501_argv" | grep -q '"scope_granularity":"undeclared"'; then
  pass "Case C: #2501's territory renders #2504's empty-array file_scope identically to absent (undeclared)"
else
  fail "Case C: #2501's territory did not render #2504 as undeclared (argv: '$g25_2501_argv')"
fi

# Case D (regression guard): a single-task cycle (same state.json, but only #2501 named on the
# command line) never receives --territory at all -- no siblings are scheduled this cycle.
reset_lock_dirs
: > "$G25_ARGV_LOG"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g25_solo.json"
run_sut --session g25_solo -- 2501
g25_solo_argv=$(grep '^2501 implement' "$G25_ARGV_LOG" || true)
if [ -n "$g25_solo_argv" ] && ! echo "$g25_solo_argv" | grep -q -- "--territory"; then
  pass "Case D: a single-task cycle never receives --territory (no siblings scheduled)"
else
  fail "Case D: expected no --territory in a single-task cycle (argv: '$g25_solo_argv')"
fi

# Case E: hard mode -- an H1 implement candidate (#2601, its own plan has an open phase) keeps its
# H1 owned_files literal AND gains concurrent_siblings for #2602 (scheduled the same cycle).
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2601, "project_name": "g25_hard_h1", "task_type": "general", "status": "implementing", "description": "H1 candidate with a sibling", "dependencies": [], "file_scope": ["a.lean"]},
    {"project_number": 2602, "project_name": "g25_hard_sibling", "task_type": "general", "status": "planned", "description": "sibling scheduled the same cycle", "dependencies": [], "file_scope": ["b.lean"]}
  ]
}
EOF
reset_lock_dirs
mkdir -p "$WORKDIR/specs/2601_g25_hard_h1/plans"
cat > "$WORKDIR/specs/2601_g25_hard_h1/plans/01_plan.md" <<'EOF'
# Plan

### Phase 1: One [COMPLETED]
### Phase 2: Two [NOT STARTED]
EOF
cat > "$WORKDIR/specs/2601_g25_hard_h1/.orchestrator-handoff.json" <<'EOF'
{"status": "partial", "phases_completed": 1, "phases_total": 2}
EOF
: > "$G25_ARGV_LOG"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g25_hard.json"
run_sut --session g25_hard --hard -- 2601 2602
g25_hard_argv=$(grep '^2601 implement' "$G25_ARGV_LOG" || true)
if echo "$g25_hard_argv" | grep -q -- "--phase-number 2"; then
  pass "Case E: #2601 still receives --phase-number 2 (H1 unaffected by the sibling merge)"
else
  fail "Case E: --phase-number 2 missing from #2601's argv ('$g25_hard_argv')"
fi
if echo "$g25_hard_argv" | grep -q "owned_files" && echo "$g25_hard_argv" | grep -q '"concurrent_siblings"'; then
  pass "Case E: #2601's --territory carries BOTH the H1 owned_files literal AND concurrent_siblings"
else
  fail "Case E: #2601's --territory missing owned_files or concurrent_siblings (argv: '$g25_hard_argv')"
fi
if echo "$g25_hard_argv" | grep -q '"task_number":2602'; then
  pass "Case E: #2601's concurrent_siblings names sibling #2602"
else
  fail "Case E: #2601's concurrent_siblings missing sibling #2602 (argv: '$g25_hard_argv')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 26: end-to-end no-redispatch demonstration for a blocker-bearing `partial` outcome --
# orchestrate-cycle-postflight.sh's `partial)` arm (Phase 1) writes status="partial" to
# state.json when the handoff carries a non-empty blockers[]; this group demonstrates that
# orchestrate-cycle-plan.sh, reading a state.json already at that status, never routes the task
# back into `implement` for the rest of the run -- it lands in blocked[] (needs_human, visible),
# never dispatch[] or eligible_tasks. Companion negative case: an empty-blockers[] partial is
# still routed to `implement` unchanged.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 26: a partial+blockers task (status already written by postflight) is excluded from redispatch; an empty-blockers partial still dispatches"
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2701, "project_name": "g26_partial_blockers", "task_type": "general", "status": "partial", "description": "postflight already wrote status=partial for a blocker-bearing outcome", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
mkdir -p "$WORKDIR/specs/2701_g26_partial_blockers"
cat > "$WORKDIR/specs/2701_g26_partial_blockers/.orchestrator-handoff.json" <<'EOF'
{"status": "partial", "dispatch_seq": 1, "phases_completed": 3, "phases_total": 4, "blockers": [{"target": "aeneas-macos-aarch64 asset", "verbatim_goal": "download the release asset", "why_it_failed": "upstream release lacks this asset"}]}
EOF
run_sut --session g26_sess --dry-run -- 2701
if [ "$(jqf '.blocked | map(select(.task == 2701)) | length')" = "1" ]; then
  pass "Group 26: candidate #2701 (partial+blockers) lands in blocked[] -- visible, never a silent skip"
else
  fail "Group 26: candidate #2701 not found in blocked[] (stdout: $LAST_STDOUT)"
fi
g26_reason=$(jqf '.blocked | map(select(.task == 2701)) | .[0].reason // ""')
if [[ "$g26_reason" == *"needs human"* ]] || [[ "$g26_reason" == *"unresolved blocker"* ]]; then
  pass "Group 26: candidate #2701's blocked[] reason names the unresolved-blocker/needs-human cause"
else
  fail "Group 26: candidate #2701's blocked[] reason missing the expected text (got: '$g26_reason')"
fi
if [ "$(jqf '.dispatch | map(select(.task == 2701)) | length')" = "0" ] && \
   [ "$(jqf '.deferred | map(select(.task == 2701)) | length')" = "0" ]; then
  pass "Group 26: candidate #2701 is absent from dispatch[] and deferred[] -- not routed back to implement"
else
  fail "Group 26: candidate #2701 leaked into dispatch or deferred (stdout: $LAST_STDOUT)"
fi

# Companion negative case: the identical fixture shape, but with an empty blockers[] -- still
# routed to `implement`, per the classifier's "partial, neither -> implement" row (Non-Goals: no
# behavior change intended here; this pins that orchestrate-cycle-plan.sh needed no edit).
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2702, "project_name": "g26_partial_no_blockers", "task_type": "general", "status": "partial", "description": "an ordinary in-progress partial, no blockers", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
mkdir -p "$WORKDIR/specs/2702_g26_partial_no_blockers"
cat > "$WORKDIR/specs/2702_g26_partial_no_blockers/.orchestrator-handoff.json" <<'EOF'
{"status": "partial", "dispatch_seq": 1, "phases_completed": 3, "phases_total": 4}
EOF
run_sut --session g26b_sess --dry-run -- 2702
if [ "$(jqf '.dispatch | map(select(.task == 2702)) | length')" = "1" ] && \
   [ "$(jqf '.dispatch | map(select(.task == 2702)) | .[0].phase')" = "implement" ]; then
  pass "Group 26 (negative): candidate #2702 (partial, no blockers) still dispatches to implement"
else
  fail "Group 26 (negative): candidate #2702 did not dispatch to implement (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.blocked | map(select(.task == 2702)) | length')" = "0" ]; then
  pass "Group 26 (negative): candidate #2702 is absent from blocked[]"
else
  fail "Group 26 (negative): candidate #2702 unexpectedly landed in blocked[] (stdout: $LAST_STDOUT)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 27: Fix 2 (Phase 1) -- identical-dispatch content hashing and per-task streak accounting.
# Log-only: no dispatch is blocked and no behavior changes (Phase 2 adds the halt).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 27: identical-dispatch content hashing and streak accounting (log-only)"

# Restore the REAL orchestrate-build-dispatch.sh AND update-task-status.sh -- Group 25
# (immediately prior) installs its own stubs (a fixed "/fake/<n>-<phase>.md" dispatch_file that
# never exists on disk, and a bare `exit 0` in place of the real preflight/postflight status
# writer) for its own sibling-territory assertions and never restores either afterward. Cases C-E
# below (and Group 28's) need the REAL scripts: a dispatch file that actually exists on disk for
# cycle_plan_dispatch_hash to hash, and a real preflight status write for the back-out assertions
# to have something genuine to restore. Same precaution Group 21 already takes for itself against
# Groups 13/15/16.
cp "$CORE_DIR/orchestrate-build-dispatch.sh" "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh"
cp "$CORE_DIR/update-task-status.sh" "$WORKDIR/.claude/scripts/update-task-status.sh"
chmod +x "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh" "$WORKDIR/.claude/scripts/update-task-status.sh"

# ── Case A: the normalizer -- byte-extracts the REAL cycle_plan_dispatch_hash() function from the
# SUT source (isolated unit test of the normalizer's own behavior, independent of the full live
# dispatch pipeline exercised in Cases C-E below). Same digest when only the two per-cycle-varying
# lines (dispatch_seq, dispatch_start_ts) differ; a different digest when any other line differs.
g27_hash_fn=$(sed -n '/^cycle_plan_dispatch_hash() {/,/^}/p' "$SUT_SRC")
if [ -n "$g27_hash_fn" ]; then
  pass "Group 27 Case A: cycle_plan_dispatch_hash() found in SUT source"
else
  fail "Group 27 Case A: could not extract cycle_plan_dispatch_hash() from $SUT_SRC"
fi

g27_f1="$WORKDIR/g27_dispatch_a.md"
cat > "$g27_f1" <<'EOF'
# Dispatch Context: candidate 9001, phase=implement

## Identity

- candidate_number: 9001
- phase: implement
- candidate_type: general
- session_id: sess_abc
- dispatch_seq: 4
- dispatch_start_ts: 1000000

## Description

Some description.
EOF
g27_f2="$WORKDIR/g27_dispatch_b.md"
sed -e 's/dispatch_seq: 4/dispatch_seq: 5/' -e 's/dispatch_start_ts: 1000000/dispatch_start_ts: 1000099/' "$g27_f1" > "$g27_f2"
g27_f3="$WORKDIR/g27_dispatch_c.md"
sed 's/Some description\./A different description./' "$g27_f1" > "$g27_f3"

g27_h1=$(bash -c "$g27_hash_fn"$'\n''cycle_plan_dispatch_hash "$1"' _ "$g27_f1")
g27_h2=$(bash -c "$g27_hash_fn"$'\n''cycle_plan_dispatch_hash "$1"' _ "$g27_f2")
g27_h3=$(bash -c "$g27_hash_fn"$'\n''cycle_plan_dispatch_hash "$1"' _ "$g27_f3")
if [ -n "$g27_h1" ] && [ "$g27_h1" = "$g27_h2" ]; then
  pass "Group 27 Case A: identical digest for two files differing only in dispatch_seq/dispatch_start_ts"
else
  fail "Group 27 Case A: expected matching digests, got '$g27_h1' vs '$g27_h2'"
fi
if [ -n "$g27_h3" ] && [ "$g27_h3" != "$g27_h1" ]; then
  pass "Group 27 Case A: different digest when a non-varying line (Description) differs"
else
  fail "Group 27 Case A: expected a different digest for a genuinely different dispatch, got '$g27_h3' (same as '$g27_h1')"
fi

# ── Case B: sha256sum-absent degrade path -- returns exit 2 (never a crash, never a fatal), no
# digest emitted. An absolute path to bash bypasses the emptied PATH for the interpreter itself;
# PATH="" inside that bash instance is what makes `command -v sha256sum` fail.
g27_bash_abs="$(command -v bash)"
g27_degrade_out=$(PATH="" "$g27_bash_abs" -c "$g27_hash_fn"$'\n''cycle_plan_dispatch_hash "$1"' _ "$g27_f1" 2>/dev/null)
g27_degrade_rc=$?
if [ "$g27_degrade_rc" -eq 2 ] && [ -z "$g27_degrade_out" ]; then
  pass "Group 27 Case B: cycle_plan_dispatch_hash returns 2 (degrade, not crash) when sha256sum is unavailable"
else
  fail "Group 27 Case B: expected exit 2 and empty output with sha256sum unavailable, got rc=$g27_degrade_rc out='$g27_degrade_out'"
fi

# ── Cases C-D: full LIVE pipeline -- `--no-plan-cache` forces a genuinely fresh composition on
# each call (mirroring orchestrate-cycle-postflight.sh clearing plan_cache unconditionally after
# any real postflight, so a same-content redispatch is never short-circuited by the in-session
# cache the way two bare back-to-back calls in this same process otherwise would be). Neither case
# repeats identical content twice in a row -- reaching streak=2 and halting is Group 28's own
# scope (Fix 2, Phase 2), landing in a later commit; these two cases pin Phase 1's accounting in
# isolation, one live call at a time.
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2703, "project_name": "g27_live", "task_type": "general", "status": "implementing", "description": "live streak test", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -rf "$WORKDIR/specs/2703_g27_live"
mkdir -p "$WORKDIR/specs/2703_g27_live/plans"
printf '# Fixture plan\n\n### Phase 1: Fixture phase [NOT STARTED]\n' > "$WORKDIR/specs/2703_g27_live/plans/01_fixture-plan.md"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g27live.json"

run_sut --session g27live --no-plan-cache -- 2703
if [ "$LAST_EXIT" -eq 0 ] && [ "$(jqf '.dispatch | map(select(.task == 2703)) | length')" = "1" ]; then
  pass "Group 27 Case C: cycle 1 dispatches candidate #2703 normally"
else
  fail "Group 27 Case C: cycle 1 did not dispatch candidate #2703 (exit=$LAST_EXIT stdout: $LAST_STDOUT)"
fi
g27_streak_after_1=$(jq -r '.identical_dispatch_streak["2703"] // 0' "$WORKDIR/specs/.orchestrator-multi-state-g27live.json")
if [ "$g27_streak_after_1" = "1" ]; then
  pass "Group 27 Case C: streak recorded as 1 after the first dispatch"
else
  fail "Group 27 Case C: expected streak 1 after cycle 1, got '$g27_streak_after_1'"
fi
if [[ "$LAST_STDERR" != *"IDENTICAL DISPATCH:"* ]]; then
  pass "Group 27 Case C: no IDENTICAL DISPATCH notice on a first-ever dispatch (streak=1)"
else
  fail "Group 27 Case C: unexpected IDENTICAL DISPATCH notice on the first dispatch: $LAST_STDERR"
fi

# ── Case D: a genuinely different dispatch (description changed) still records streak=1 -- never
# a repeat of cycle 1's own content, so this never reaches the halt threshold. ────────────────────
g27_desc_filter='(.active_projects[] | select(.project_number == 2703)).description = "a genuinely different description"'
jq "$g27_desc_filter" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
run_sut --session g27live --no-plan-cache -- 2703
if [ "$LAST_EXIT" -eq 0 ] && [ "$(jqf '.dispatch | map(select(.task == 2703)) | length')" = "1" ]; then
  pass "Group 27 Case D: a genuinely different dispatch still dispatches normally"
else
  fail "Group 27 Case D: expected a normal dispatch for genuinely different content, got exit=$LAST_EXIT stdout: $LAST_STDOUT"
fi
g27_streak_after_2=$(jq -r '.identical_dispatch_streak["2703"] // 0' "$WORKDIR/specs/.orchestrator-multi-state-g27live.json")
if [ "$g27_streak_after_2" = "1" ]; then
  pass "Group 27 Case D: streak stays at 1 when the dispatch content genuinely differs from the previous cycle"
else
  fail "Group 27 Case D: expected streak 1, got '$g27_streak_after_2'"
fi
if [[ "$LAST_STDERR" != *"IDENTICAL DISPATCH:"* ]]; then
  pass "Group 27 Case D: no IDENTICAL DISPATCH notice on a streak of 1"
else
  fail "Group 27 Case D: unexpected IDENTICAL DISPATCH notice on a genuinely different dispatch: $LAST_STDERR"
fi

# ── Case E: --dry-run composition is untouched -- the guard lives entirely in the live-only half.
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2704, "project_name": "g27_dryrun", "task_type": "general", "status": "not_started", "description": "dry-run must be byte-unaffected by the accounting guard", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g27dry.json"
run_sut --session g27dry --dry-run -- 2704
if [ "$LAST_EXIT" -eq 0 ] && [ "$(jqf '.dispatch | map(select(.task == 2704 and .phase == "research")) | length')" = "1" ]; then
  pass "Group 27 Case E: --dry-run still dispatches normally"
else
  fail "Group 27 Case E: --dry-run behavior changed (exit=$LAST_EXIT stdout: $LAST_STDOUT)"
fi
if [ ! -f "$WORKDIR/specs/.orchestrator-multi-state-g27dry.json" ]; then
  pass "Group 27 Case E: --dry-run never persists a multi-state file (no accounting side effect)"
else
  fail "Group 27 Case E: --dry-run unexpectedly wrote a multi-state file"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 28: Fix 2 (Phase 2) -- halt on a second consecutive identical dispatch (N=2). Verification
# arm (5): the same dispatch fired twice with identical content stops the run for that task.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 28: identical-dispatch halt, inline back-out, and the halted-set exclusion"

write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2801, "project_name": "g28_halt", "task_type": "general", "status": "not_started", "description": "halt-on-repeat test", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -rf "$WORKDIR/specs/2801_g28_halt"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g28halt.json"

# Cycle 1: an ordinary, first-ever dispatch -- dispatches ok, streak=1, no halt.
run_sut --session g28halt --no-plan-cache -- 2801
if [ "$LAST_EXIT" -eq 0 ] && [ "$(jqf '.dispatch | map(select(.task == 2801 and .phase == "research")) | length')" = "1" ]; then
  pass "Group 28: cycle 1 dispatches candidate #2801 normally"
else
  fail "Group 28: cycle 1 did not dispatch candidate #2801 (exit=$LAST_EXIT stdout: $LAST_STDOUT)"
fi
g28_status_after_1=$(jq -r '.active_projects[] | select(.project_number == 2801) | .status' "$STATE_FILE")
if [ "$g28_status_after_1" = "researching" ]; then
  pass "Group 28: cycle 1's preflight write actually changed status to 'researching'"
else
  fail "Group 28: expected status 'researching' after cycle 1's preflight write, got '$g28_status_after_1'"
fi
# Snapshot the exact pre-image cycle 2's own halt must restore -- cycle 2's own preflight write
# would have overwritten last_updated/session_id with ITS OWN fresh values even though status is
# already 'researching' (a same-value status write still refreshes last_updated/session_id), so
# the correct restore target is cycle 1's post-write state, not the original not_started fixture.
g28_entry_after_1=$(jq -c '.active_projects[] | select(.project_number == 2801)' "$STATE_FILE")
g28_lu_after_1=$(echo "$g28_entry_after_1" | jq -r '.last_updated // ""')
g28_sid_after_1=$(echo "$g28_entry_after_1" | jq -r '.session_id // ""')
g28_seq_counter_after_1=$(jq -r '.dispatch_seq_counter // 0' "$WORKDIR/specs/2801_g28_halt/.orchestrator-loop-guard")
g28_cycle_count_after_1=$(jq -r '.cycle_counts["2801"] // 0' "$WORKDIR/specs/.orchestrator-multi-state-g28halt.json")
[ -d "$WORKDIR/specs/2801_g28_halt/.dispatch" ] && [ -f "$WORKDIR/specs/2801_g28_halt/.dispatch/1.md" ]
g28_dispatch_1_present=$?
[ -d "$WORKDIR/specs/2801_g28_halt/.lock" ]
g28_lock_present_after_1=$?

# Cycle 2: IDENTICAL content -- must halt: no dispatch row, a blocked[] row instead, every side
# effect from this cycle backed out.
run_sut --session g28halt --no-plan-cache -- 2801
if [ "$LAST_EXIT" -eq 0 ] && [ "$(jqf '.dispatch | length')" = "0" ]; then
  pass "Group 28: cycle 2 (identical content) issues ZERO dispatch rows -- halted, not re-dispatched"
else
  fail "Group 28: cycle 2 unexpectedly dispatched (exit=$LAST_EXIT stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.blocked | map(select(.task == 2801)) | length')" = "1" ]; then
  pass "Group 28: cycle 2 reports candidate #2801 in blocked[] -- visible, never a silent skip"
else
  fail "Group 28: expected candidate #2801 in blocked[] after the halt, got: $LAST_STDOUT"
fi
g28_blocked_reason=$(jqf '.blocked | map(select(.task == 2801)) | .[0].reason // ""')
if [[ "$g28_blocked_reason" == *"identical-dispatch convergence guard"* ]] && [[ "$g28_blocked_reason" == *"2 times in a row"* ]]; then
  pass "Group 28: the blocked[] reason names the guard and the streak"
else
  fail "Group 28: blocked[] reason missing the expected text, got: '$g28_blocked_reason'"
fi
if [[ "$LAST_STDERR" == *"IDENTICAL DISPATCH HALT:"* ]]; then
  pass "Group 28: the named IDENTICAL DISPATCH HALT notice fires on stderr"
else
  fail "Group 28: expected the IDENTICAL DISPATCH HALT notice on stderr, got: $LAST_STDERR"
fi

# Back-out assertion 1: state.json status/last_updated/session_id restored to the EXACT pre-image
# cycle 2's own preflight write would otherwise have overwritten -- i.e. byte-identical to cycle
# 1's own post-write state, not the original not_started fixture (cycle 1 already advanced status
# to 'researching' before cycle 2 ever ran; cycle 2's back-out only undoes ITS OWN write).
g28_status_after_2=$(jq -r '.active_projects[] | select(.project_number == 2801) | .status' "$STATE_FILE")
g28_lu_after_2=$(jq -r '.active_projects[] | select(.project_number == 2801) | .last_updated // ""' "$STATE_FILE")
g28_sid_after_2=$(jq -r '.active_projects[] | select(.project_number == 2801) | .session_id // ""' "$STATE_FILE")
if [ "$g28_status_after_2" = "$g28_status_after_1" ] && [ "$g28_lu_after_2" = "$g28_lu_after_1" ] && [ "$g28_sid_after_2" = "$g28_sid_after_1" ]; then
  pass "Group 28: state.json status/last_updated/session_id restored to cycle 1's exact post-write pre-image"
else
  fail "Group 28: expected status='$g28_status_after_1' last_updated='$g28_lu_after_1' session_id='$g28_sid_after_1', got status='$g28_status_after_2' last_updated='$g28_lu_after_2' session_id='$g28_sid_after_2'"
fi

# Back-out assertion 2: the just-written .dispatch/2.md file is gone.
if [ ! -f "$WORKDIR/specs/2801_g28_halt/.dispatch/2.md" ]; then
  pass "Group 28: the halted cycle's .dispatch/2.md file was removed"
else
  fail "Group 28: .dispatch/2.md unexpectedly still exists after the halt"
fi
# Cycle 1's own dispatch file is untouched -- the back-out only removes THIS cycle's own file.
if [ "$g28_dispatch_1_present" -eq 0 ] && [ -f "$WORKDIR/specs/2801_g28_halt/.dispatch/1.md" ]; then
  pass "Group 28: cycle 1's own .dispatch/1.md file is untouched by cycle 2's back-out"
else
  fail "Group 28: cycle 1's .dispatch/1.md file was unexpectedly affected"
fi

# Back-out assertion 3: the task lock is released.
if [ ! -d "$WORKDIR/specs/2801_g28_halt/.lock" ]; then
  pass "Group 28: the task lock was released by the halt back-out"
else
  fail "Group 28: the task lock is still held after the halt back-out"
fi

# Back-out assertion 4: the durable dispatch_seq_counter did NOT advance past cycle 1's value --
# the halted cycle never flushed a second charge.
g28_seq_counter_after_2=$(jq -r '.dispatch_seq_counter // 0' "$WORKDIR/specs/2801_g28_halt/.orchestrator-loop-guard")
if [ "$g28_seq_counter_after_2" = "$g28_seq_counter_after_1" ]; then
  pass "Group 28: the durable dispatch_seq_counter did not advance past the halted cycle ($g28_seq_counter_after_1 -> $g28_seq_counter_after_2)"
else
  fail "Group 28: expected the durable dispatch_seq_counter to stay at $g28_seq_counter_after_1, got $g28_seq_counter_after_2"
fi

# Back-out assertion 5: the per-task cycle budget was not charged a second time.
g28_cycle_count_after_2=$(jq -r '.cycle_counts["2801"] // 0' "$WORKDIR/specs/.orchestrator-multi-state-g28halt.json")
if [ "$g28_cycle_count_after_2" = "$g28_cycle_count_after_1" ]; then
  pass "Group 28: the per-task cycle budget was not charged for the halted cycle ($g28_cycle_count_after_1 -> $g28_cycle_count_after_2)"
else
  fail "Group 28: expected cycle_counts unchanged at $g28_cycle_count_after_1, got $g28_cycle_count_after_2"
fi

# Cycle 3: a subsequent cycle emits the same blocked[] reason and dispatches nothing for this
# task -- the halted-set exclusion persists for the rest of the run, visible every cycle.
run_sut --session g28halt --no-plan-cache -- 2801
if [ "$(jqf '.dispatch | map(select(.task == 2801)) | length')" = "0" ] && \
   [ "$(jqf '.blocked | map(select(.task == 2801)) | length')" = "1" ]; then
  pass "Group 28: cycle 3 (a later cycle) still excludes candidate #2801 via blocked[], dispatching nothing"
else
  fail "Group 28: cycle 3 did not keep candidate #2801 excluded (stdout: $LAST_STDOUT)"
fi

# ── Regression guard: a non-repeating multi-task composition is unaffected -- two brand-new
# candidates, neither repeating, both dispatch normally with no halted rows at all. ───────────────
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 2802, "project_name": "g28_norepeat_a", "task_type": "general", "status": "not_started", "description": "first-ever dispatch, never repeated", "dependencies": [], "file_scope": []},
    {"project_number": 2803, "project_name": "g28_norepeat_b", "task_type": "general", "status": "not_started", "description": "first-ever dispatch, never repeated", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -rf "$WORKDIR/specs/2802_g28_norepeat_a" "$WORKDIR/specs/2803_g28_norepeat_b"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g28norepeat.json"
run_sut --session g28norepeat --no-plan-cache -- 2802 2803
if [ "$(jqf '.dispatch | length')" = "2" ] && [ "$(jqf '.blocked | length')" = "0" ]; then
  pass "Group 28: a non-repeating two-candidate composition dispatches both, with zero blocked[] rows"
else
  fail "Group 28: non-repeating composition regression -- expected 2 dispatch rows and 0 blocked rows, got: $LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
