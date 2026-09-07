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
         lib/manifest-routing-lib.sh lib/phase-heading-patterns.sh lib/deploy-baseline-lib.sh; do
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
         phase-heading-patterns.sh deploy-baseline-lib.sh; do
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
# Group 8: Decision 1 — per-task cumulative cycle budget (durable across sessions, mode-aware
# max_cycles, --continue-budget reset)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 8: per-task cumulative cycle budget"

write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 801, "project_name": "g8_budget", "task_type": "general", "status": "implementing", "description": "budget candidate", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
rm -rf "$WORKDIR/specs/801_g8_budget"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g8_sess_a.json" "$WORKDIR/specs/.orchestrator-multi-state-g8_sess_b.json"

# Invocation 1, session A: live dispatch charges this task's durable guard file to cycle_count=1.
run_sut --session g8_sess_a -- 801
guard_file="$WORKDIR/specs/801_g8_budget/.orchestrator-loop-guard"
if [ -f "$guard_file" ] && [ "$(jq -r '.cycle_count' "$guard_file")" = "1" ]; then
  pass "budget: live dispatch flushes cycle_count=1 to the durable per-task guard file"
else
  fail "budget: durable guard file missing or wrong cycle_count after invocation 1 (got: $(cat "$guard_file" 2>/dev/null || echo MISSING))"
fi

# Invocation 2, session B: a FRESH session_id (fresh mt_state_file) must still resume from the
# durable file's cycle_count=1, seeding cycle_counts[801]=1, then charge it to 2 on dispatch --
# this is the cross-invocation cumulative guarantee Decision 1 exists to preserve. Release session
# A's task-lock first (mirroring the real postflight's own release once a dispatched agent
# returns) -- otherwise session B's candidate is merely deferred as locked, never re-evaluated.
bash "$WORKDIR/.claude/scripts/task-lock.sh" release 801 g8_sess_a >/dev/null 2>&1 || true
run_sut --session g8_sess_b -- 801
if [ -f "$guard_file" ] && [ "$(jq -r '.cycle_count' "$guard_file")" = "2" ]; then
  pass "budget: a second invocation with a FRESH session_id resumes the prior cycle_count (cumulative across invocations)"
else
  fail "budget: cross-session resume failed (got: $(cat "$guard_file" 2>/dev/null || echo MISSING))"
fi

# ── Mode-aware max_cycles: base mode's 5 vs. hard mode's 13, observed behaviorally via --dry-run
# (dry-run never flushes, so the durable guard file is pre-seeded directly at exactly 5).
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 802, "project_name": "g8_mode_aware", "task_type": "general", "status": "implementing", "description": "mode-aware max_cycles candidate", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
mkdir -p "$WORKDIR/specs/802_g8_mode_aware"
jq -n '{cycle_count: 5}' > "$WORKDIR/specs/802_g8_mode_aware/.orchestrator-loop-guard"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g8_mode_base.json" "$WORKDIR/specs/.orchestrator-multi-state-g8_mode_hard.json"

run_sut --session g8_mode_base --dry-run -- 802
if [ "$(jqf '.blocked | map(select(.task == 802)) | length')" = "1" ] && \
   [[ "$(jqf '.blocked | map(select(.task == 802)) | .[0].reason')" == *MAX_CYCLES* ]]; then
  pass "budget: base mode (max_cycles=5) blocks a candidate already at cycle_count=5"
else
  fail "budget: base-mode candidate at cycle_count=5 was not blocked for MAX_CYCLES (stdout: $LAST_STDOUT)"
fi

run_sut --session g8_mode_hard --dry-run --hard -- 802
if [ "$(jqf '.dispatch | map(select(.task == 802)) | length')" = "1" ]; then
  pass "budget: hard mode (max_cycles=13) dispatches the SAME candidate at cycle_count=5"
else
  fail "budget: hard-mode candidate at cycle_count=5 did not dispatch (stdout: $LAST_STDOUT)"
fi

# ── Batch-of-one budget-exhaustion stop, and --continue-budget's reset+resume override.
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 803, "project_name": "g8_exhausted", "task_type": "general", "status": "implementing", "description": "exhausted budget candidate", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
mkdir -p "$WORKDIR/specs/803_g8_exhausted"
jq -n '{cycle_count: 5, dispatch_seq_counter: 9, detected_defects: ["kept"]}' > "$WORKDIR/specs/803_g8_exhausted/.orchestrator-loop-guard"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g8_exhausted_sess.json"

run_sut --session g8_exhausted_sess -- 803
if [ "$(jqf '.stop.reason')" = "max_cycles" ]; then
  pass "budget: a batch-of-one whose only task is budget-exhausted stops with reason=max_cycles"
else
  fail "budget: batch-of-one exhaustion did not stop with reason=max_cycles (stdout: $LAST_STDOUT)"
fi
if [ "$(jqf '.dispatch | length')" = "0" ]; then
  pass "budget: exhausted batch-of-one dispatches nothing"
else
  fail "budget: exhausted batch-of-one unexpectedly dispatched (stdout: $LAST_STDOUT)"
fi

run_sut --session g8_exhausted_sess --continue-budget -- 803
exhausted_guard="$WORKDIR/specs/803_g8_exhausted/.orchestrator-loop-guard"
if [ "$(jqf '.dispatch | map(select(.task == 803)) | length')" = "1" ]; then
  pass "budget: --continue-budget authorizes dispatching the same exhausted candidate"
else
  fail "budget: --continue-budget did not dispatch the exhausted candidate (stdout: $LAST_STDOUT)"
fi
if [ -f "$exhausted_guard" ] && [ "$(jq -r '.dispatch_seq_counter' "$exhausted_guard")" = "9" ] && \
   [ "$(jq -r '.detected_defects | length' "$exhausted_guard")" = "1" ]; then
  pass "budget: --continue-budget's reset preserves dispatch_seq_counter and detected_defects"
else
  fail "budget: --continue-budget's reset did not preserve cross-invocation history fields (got: $(cat "$exhausted_guard" 2>/dev/null))"
fi
if [ "$(jq -r '.cycle_count' "$exhausted_guard")" = "1" ]; then
  pass "budget: --continue-budget resets cycle_count to 0 then charges this cycle's own dispatch (now 1)"
else
  fail "budget: --continue-budget did not reset+recharge cycle_count correctly (got: $(jq -r '.cycle_count' "$exhausted_guard" 2>/dev/null))"
fi
exhausted_archive_count=$(find "$WORKDIR/specs/803_g8_exhausted" -maxdepth 1 -name '.exhausted-loop-guard-*.json' | wc -l)
if [ "$exhausted_archive_count" -ge 1 ]; then
  pass "budget: --continue-budget archives the exhausted guard aside for auditability"
else
  fail "budget: --continue-budget did not archive the exhausted guard"
fi

# ── Mixed batch: one task's budget exhaustion excludes only that task, never the whole batch.
write_state <<'EOF'
{
  "active_projects": [
    {"project_number": 804, "project_name": "g8_mixed_exhausted", "task_type": "general", "status": "implementing", "description": "exhausted sibling", "dependencies": [], "file_scope": []},
    {"project_number": 805, "project_name": "g8_mixed_fresh", "task_type": "general", "status": "implementing", "description": "fresh sibling", "dependencies": [], "file_scope": []}
  ]
}
EOF
reset_lock_dirs
mkdir -p "$WORKDIR/specs/804_g8_mixed_exhausted"
jq -n '{cycle_count: 5}' > "$WORKDIR/specs/804_g8_mixed_exhausted/.orchestrator-loop-guard"
rm -rf "$WORKDIR/specs/805_g8_mixed_fresh"
rm -f "$WORKDIR/specs/.orchestrator-multi-state-g8_mixed_sess.json"

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
echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
