#!/usr/bin/env bash
# test-handoff-dispatch-identity.sh - Regression suite for Defect A: the orchestrator-minted
# `dispatch_seq` identity gate, ported (Phase 7 of the task that built
# orchestrate-cycle-postflight.sh) from an sentinel-region extraction against
# skill-orchestrate/SKILL.md's inline Stage 5 prose to a direct invocation of the real gate's
# now-single implementation, orchestrate-cycle-postflight.sh's WORK (a). Both engines
# (single-task Stage 5 and multi-task Stage MT-4) call that one script, so this suite proves the
# gate once for both, instead of extracting and `eval`-ing a copy of inline SKILL.md text that
# stopped existing once the cutover replaced it with a script call.
#
# Reproduces the observed failure mode -- a woken predecessor's late handoff write whose mtime
# falls INSIDE the successor's dispatch window, defeating an mtime-only gate -- and asserts the
# dispatch_seq comparison rejects it where mtime alone would have accepted it. See
# context/patterns/dispatch-report-not-termination.md for the shared root-cause model this test
# proves closed, and context/standards/orchestrator-runtime-files.md's "Readers MUST check
# freshness" rationale for why mtime alone is insufficient.
#
# Structural model: test-orchestrate-cycle-postflight.sh's sandbox shape (copy real collaborator
# scripts into a synthetic $WORKDIR/.claude/scripts/ tree so deploy-root-guard.sh's `*/.claude`
# parent-directory check passes and every sibling script's own SCRIPT_DIR-anchored resolution
# lands inside the fixture, never the real repo). Every real collaborator this script calls is
# copied in unmodified, so this suite exercises the real call graph, not a stubbed
# approximation of it. Every case runs with `--dry-run` (no commit, no state.json/loop-guard
# mutation) since this suite asserts only the GATE's own accept/reject decision, not the full
# postflight pipeline downstream of it (that pipeline is test-orchestrate-cycle-postflight.sh's
# job).
#
# Detection strategy (black-box, since the script's compact JSON does not expose the internal
# `handoff_stale` variable by name): no `.return-meta.json` fixture exists in any of these four
# cases, so a REJECTED handoff has no recovery source at all and must fall through to
# verdict=failed with no trustworthy status; an ACCEPTED handoff is consumed directly and its
# fixture `status: "implemented"` is echoed straight through. Accept vs. reject is therefore
# unambiguous from the output JSON's `status` field alone, corroborated by the same stderr
# substrings the original sentinel-extraction suite asserted on (STALE HANDOFF / DISPATCH_SEQ
# MISMATCH / WARN: handoff has no dispatch_seq field / dispatch_seq match).
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
# Glob-copy the whole lib/ directory rather than a hardcoded per-file list (see
# test-force-phases.sh:106 for the precedent): a hardcoded list drifts silently whenever
# orchestrate-cycle-postflight.sh (or a script it transitively sources) grows a new lib/
# dependency, as happened with return-meta-status-vocabulary.sh.
if [ ! -d "$CORE_DIR/lib" ]; then
  echo "ERROR: expected directory $CORE_DIR/lib" >&2
  exit 2
fi

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
  cp "$CORE_DIR"/lib/*.sh "$WORKDIR/.claude/scripts/lib/"
  cp "$CORE_DIR/../context/reference/orchestrator-critical-paths.json" \
     "$WORKDIR/.claude/context/reference/orchestrator-critical-paths.json" 2>/dev/null || true
  chmod +x "$WORKDIR"/.claude/scripts/*.sh
  ( cd "$WORKDIR" && git init -q && git config user.email t@t.com && git config user.name T )
}

SUT="$WORKDIR/.claude/scripts/orchestrate-cycle-postflight.sh"
STATE_FILE="$WORKDIR/specs/state.json"

write_state() { cat > "$STATE_FILE"; }

commit_fixture() {
  ( cd "$WORKDIR" && git add specs/ .claude/ >/dev/null 2>&1 && git commit -q -m "fixture" >/dev/null 2>&1 )
}

now_ts() { date -u +%s; }

run_sut() {
  # Usage: run_sut <task_dir_relpath> [extra args...]
  local task_dir="$1"; shift
  local stdout_file stderr_file
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  ( cd "$WORKDIR" && bash "$SUT" "$@" --state-file specs/state.json --task-dir "$task_dir" --dry-run \
      >"$stdout_file" 2>"$stderr_file" )
  LAST_EXIT=$?
  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

jqf() { echo "$LAST_STDOUT" | jq -r "$1" 2>/dev/null; }

# make_case_dir CANDIDATE_NUM HANDOFF_DISPATCH_SEQ MTIME_OFFSET_SECONDS
# HANDOFF_DISPATCH_SEQ: numeric value, or "" to omit the field entirely (Case 4).
# MTIME_OFFSET_SECONDS: 0 = written "just now" (inside window); a large positive value backdates
# the handoff file to BEFORE the dispatch window opened (the git-restoration hazard shape).
make_case_dir() {
  local num="$1" handoff_seq="$2" mtime_offset="$3"
  local dir="$WORKDIR/specs/${num}_candidate"
  mkdir -p "$dir"
  write_state <<EOF
{"next_project_number": 2, "active_projects": [{"project_number": ${num}, "project_name": "candidate", "task_type": "general", "status": "implementing", "description": "candidate #${num}", "dependencies": [], "file_scope": []}]}
EOF
  echo "## Tasks" > "$WORKDIR/specs/TODO.md"
  commit_fixture
  cat > "${dir}/.orchestrator-loop-guard" <<EOF
{"dispatch_seq_counter": ${num}, "detected_defects": [], "infra_failures": 0}
EOF
  if [ -n "$handoff_seq" ]; then
    jq -n --argjson seq "$handoff_seq" \
      '{"status":"implemented","summary":"fixture","artifacts":[{"type":"summary","path":"specs/000_x/summaries/01_x-summary.md"}],"phases_completed":1,"phases_total":1,"blockers":[],"continuation_path":null,"dispatch_seq":$seq}' \
      > "${dir}/.orchestrator-handoff.json"
  else
    jq -n \
      '{"status":"implemented","summary":"fixture","artifacts":[{"type":"summary","path":"specs/000_x/summaries/01_x-summary.md"}],"phases_completed":1,"phases_total":1,"blockers":[],"continuation_path":null}' \
      > "${dir}/.orchestrator-handoff.json"
  fi
  if [ "$mtime_offset" -gt 0 ]; then
    local epoch=$(( $(now_ts) - mtime_offset ))
    touch -d "@${epoch}" "${dir}/.orchestrator-handoff.json" 2>/dev/null \
      || touch -t "$(date -u -d "@${epoch}" +%Y%m%d%H%M.%S)" "${dir}/.orchestrator-handoff.json"
  fi
}

# run_case NAME CANDIDATE_NUM HANDOFF_SEQ MINTED_SEQ MTIME_OFFSET EXPECT_ACCEPTED EXPECT_STDERR_GREP
run_case() {
  local name="$1" num="$2" handoff_seq="$3" minted_seq="$4" mtime_offset="$5" \
        expect_accepted="$6" expect_grep="${7:-}"
  setup_sandbox
  make_case_dir "$num" "$handoff_seq" "$mtime_offset"
  local window_start
  window_start=$(now_ts)
  run_sut "specs/${num}_candidate" --session "sess_${num}" --phase implement \
    --task-type general --agent general-implementation-agent \
    --loop-guard-file "specs/${num}_candidate/.orchestrator-loop-guard" \
    --dispatch-seq "$minted_seq" --dispatch-start-ts "$window_start" "$num"

  local got_status
  got_status="$(jqf '.status')"
  if [ "$expect_accepted" = "true" ]; then
    if [ "$got_status" = "implemented" ]; then
      pass "${name}: handoff accepted (status=implemented, echoed from the fixture)"
    else
      fail "${name}: expected the handoff to be ACCEPTED (status=implemented), got: $LAST_STDOUT ($LAST_STDERR)"
    fi
  else
    if [ "$got_status" != "implemented" ] && [ "$(jqf '.verdict')" = "failed" ]; then
      pass "${name}: handoff rejected (no recovery source -> verdict=failed, status not echoed from the untrusted fixture)"
    else
      fail "${name}: expected the handoff to be REJECTED (verdict=failed, status!=implemented), got: $LAST_STDOUT ($LAST_STDERR)"
    fi
  fi
  if [ -n "$expect_grep" ]; then
    if echo "$LAST_STDERR" | grep -qE "$expect_grep"; then
      pass "${name}: stderr matches expected pattern"
    else
      fail "${name}: stderr does not match expected pattern '${expect_grep}': $LAST_STDERR"
    fi
  fi
}

# =====================================================================
# Case 1: dispatch_seq matches the current cycle's minted value, mtime inside the window.
# Expected: ACCEPTED.
# =====================================================================
run_case "case1-match" 801 5 5 0 "true" 'dispatch_seq match'

# =====================================================================
# Case 2 (THE LOAD-BEARING CASE): dispatch_seq is a PREDECESSOR's value (a still-live
# predecessor's late write), mtime inside the successor's dispatch window -- reproducing the
# observed 6-second-overlap failure shape. mtime alone would ACCEPT this (mtime_offset=0, i.e.
# written "just now", well inside the window); only the dispatch_seq comparison rejects it.
# Expected: REJECTED, stderr names DISPATCH_SEQ MISMATCH.
# =====================================================================
run_case "case2-mismatch-inside-window" 802 4 5 0 "false" 'DISPATCH_SEQ MISMATCH'

# =====================================================================
# Case 3: old mtime (git-restoration hazard) -- handoff predates the dispatch window by a wide
# margin, regardless of dispatch_seq. Expected: REJECTED by the RETAINED mtime check, before the
# dispatch_seq comparison is even reached.
# =====================================================================
run_case "case3-old-mtime" 803 5 5 3600 "false" 'STALE HANDOFF'

# =====================================================================
# Case 4: handoff has no dispatch_seq field at all (writer predates the contract). mtime is
# inside the window. Expected: WARN, NOT rejected -- accepted via mtime-only discrimination.
# =====================================================================
run_case "case4-absent" 804 "" 5 0 "true" 'WARN: handoff has no dispatch_seq field'

# =====================================================================
# Negative-control note (not automated): temporarily reverting the dispatch_seq gate in
# orchestrate-cycle-postflight.sh (commenting out the `elif [ -n "$expected_dispatch_seq" ] &&
# [ "$handoff_dispatch_seq" != ... ]` branch) makes Case 2 fail, since only that branch's
# mismatch check distinguishes it from Case 1. Verified manually during authoring; not
# re-verified on every run (would require mutating the source file mid-suite).
# =====================================================================

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
