#!/usr/bin/env bash
# test-orchestrate-recover-message-findings.sh - Fixture suite for
# orchestrate-recover-message-findings.sh: the D4 helper that saves a research subagent's
# message-borne findings as a clearly-tagged recovered artifact when
# orchestrate-cycle-postflight.sh reports report_missing=true.
#
# Structural model: same sandbox shape as test-orchestrate-cycle-postflight.sh (copy real
# collaborator scripts into a synthetic $WORKDIR/.claude/scripts/ tree). The end-to-end fixture
# additionally copies orchestrate-cycle-postflight.sh's own full collaborator set so it can run a
# real postflight cycle and feed its report_missing=true output into this helper, exactly as
# skill-orchestrate/SKILL.md Move 3 does.
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

SUT_SRC="$CORE_DIR/orchestrate-recover-message-findings.sh"
require_file "$SUT_SRC"
require_file "$CORE_DIR/lib/common.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

setup_sandbox() {
  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR/.claude/scripts/lib" "$WORKDIR/specs"
  cp "$CORE_DIR/orchestrate-recover-message-findings.sh" "$WORKDIR/.claude/scripts/"
  cp "$CORE_DIR/lib/common.sh" "$WORKDIR/.claude/scripts/lib/"
  chmod +x "$WORKDIR/.claude/scripts/orchestrate-recover-message-findings.sh"
}

SUT="$WORKDIR/.claude/scripts/orchestrate-recover-message-findings.sh"

run_sut() {
  local stdout_file stderr_file
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  ( cd "$WORKDIR" && bash "$SUT" "$@" >"$stdout_file" 2>"$stderr_file" )
  LAST_EXIT=$?
  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

jqf() { echo "$LAST_STDOUT" | jq -r "$1" 2>/dev/null; }

write_dispatch_file() {
  # Usage: write_dispatch_file <task_relpath> <seq> <artifact_padded> <output_dir>
  local task_relpath="$1" seq="$2" padded="$3" out_dir="$4"
  mkdir -p "$WORKDIR/${task_relpath}/.dispatch"
  cat > "$WORKDIR/${task_relpath}/.dispatch/${seq}.md" <<EOF
# Dispatch Context

## Artifact Round

- artifact_number: ${padded#0}
- artifact_padded: ${padded}
- output_dir: ${out_dir}
EOF
}

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Success path: banner + verbatim body present at the naming convention's target path
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Success path: recovered file carries the banner and the verbatim message body"
setup_sandbox
mkdir -p "$WORKDIR/specs/930_candidate"
write_dispatch_file specs/930_candidate 1 01 specs/930_candidate/reports
echo "these are the agent's real findings, verbatim" > "$WORKDIR/msg.txt"
run_sut --task-dir specs/930_candidate --dispatch-seq 1 --message-file msg.txt \
  --agent general-research-agent --session sess_930

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "success: SUT exits 0"
else
  fail "success: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if [ "$(jqf '.recovered')" = "true" ]; then
  pass "success: recovered=true"
else
  fail "success: expected recovered=true, got: $LAST_STDOUT"
fi
written_path="$WORKDIR/$(jqf '.path')"
if [ -f "$written_path" ]; then
  pass "success: the reported path actually exists"
else
  fail "success: reported path does not exist: $written_path"
fi
if grep -q "NOT a completed research report" "$written_path" 2>/dev/null; then
  pass "success: the recovered-content banner is present"
else
  fail "success: banner missing from $written_path"
fi
if grep -q "these are the agent's real findings, verbatim" "$written_path" 2>/dev/null; then
  pass "success: the verbatim message body is present"
else
  fail "success: verbatim body missing from $written_path"
fi
if grep -q "general-research-agent" "$written_path" 2>/dev/null && grep -q "sess_930" "$written_path" 2>/dev/null; then
  pass "success: provenance lines (agent, session) are present"
else
  fail "success: provenance lines missing from $written_path"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Never-clobber: a second run against the same round creates a -2 suffixed file
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Never-clobber: a second recovery for the same round does not overwrite the first"
run_sut --task-dir specs/930_candidate --dispatch-seq 1 --message-file msg.txt \
  --agent general-research-agent --session sess_930_second

if [ "$(jqf '.path')" = "specs/930_candidate/reports/01_recovered-agent-message-2.md" ]; then
  pass "never-clobber: second run created the -2 suffixed file"
else
  fail "never-clobber: expected the -2 suffixed path, got: $(jqf '.path')"
fi
if [ -f "$WORKDIR/specs/930_candidate/reports/01_recovered-agent-message.md" ] && \
   grep -q "sess_930\b" "$WORKDIR/specs/930_candidate/reports/01_recovered-agent-message.md" && \
   ! grep -q "sess_930_second" "$WORKDIR/specs/930_candidate/reports/01_recovered-agent-message.md"; then
  pass "never-clobber: the original file is untouched"
else
  fail "never-clobber: the original file was modified"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Empty message: no file is created, recovered=false, reason=EMPTY_MESSAGE
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Empty message: whitespace-only message writes nothing"
setup_sandbox
mkdir -p "$WORKDIR/specs/931_candidate"
write_dispatch_file specs/931_candidate 1 01 specs/931_candidate/reports
printf '   \n\n  \t\n' > "$WORKDIR/whitespace.txt"
run_sut --task-dir specs/931_candidate --dispatch-seq 1 --message-file whitespace.txt \
  --agent general-research-agent --session sess_931

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "empty message: SUT still exits 0 (non-fatal to the caller's loop)"
else
  fail "empty message: SUT exited $LAST_EXIT"
fi
if [ "$(jqf '.recovered')" = "false" ] && [ "$(jqf '.reason')" = "EMPTY_MESSAGE" ]; then
  pass "empty message: recovered=false, reason=EMPTY_MESSAGE"
else
  fail "empty message: expected recovered=false/EMPTY_MESSAGE, got: $LAST_STDOUT"
fi
if [ -d "$WORKDIR/specs/931_candidate/reports" ] && \
   [ -z "$(ls -A "$WORKDIR/specs/931_candidate/reports" 2>/dev/null)" ]; then
  pass "empty message: no file was created"
elif [ ! -d "$WORKDIR/specs/931_candidate/reports" ]; then
  pass "empty message: reports/ was never even created"
else
  fail "empty message: a file was unexpectedly created: $(ls -A "$WORKDIR/specs/931_candidate/reports")"
fi

# Also cover a missing message-file argument entirely (not just whitespace-only content).
run_sut --task-dir specs/931_candidate --dispatch-seq 1 --message-file /no/such/file.txt \
  --agent general-research-agent --session sess_931b
if [ "$(jqf '.reason')" = "EMPTY_MESSAGE" ]; then
  pass "empty message: a nonexistent message-file path is treated identically to an empty one"
else
  fail "empty message: expected reason=EMPTY_MESSAGE for a missing file, got: $LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Missing dispatch file: fallback to reports/ and 01, with a named WARN on stderr
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Missing dispatch file: falls back to reports/ and 01 with a named WARN"
setup_sandbox
mkdir -p "$WORKDIR/specs/932_candidate"
echo "findings with no dispatch file to consult" > "$WORKDIR/msg.txt"
run_sut --task-dir specs/932_candidate --dispatch-seq 7 --message-file msg.txt \
  --agent general-research-agent --session sess_932

if [ "$(jqf '.recovered')" = "true" ]; then
  pass "missing dispatch file: recovery still succeeds via the fallback"
else
  fail "missing dispatch file: expected recovered=true, got: $LAST_STDOUT"
fi
if [ "$(jqf '.path')" = "specs/932_candidate/reports/01_recovered-agent-message.md" ]; then
  pass "missing dispatch file: fallback path is reports/01_recovered-agent-message.md"
else
  fail "missing dispatch file: expected the fallback path, got: $(jqf '.path')"
fi
if echo "$LAST_STDERR" | grep -q "WARN: could not resolve artifact_padded/output_dir"; then
  pass "missing dispatch file: named WARN present on stderr"
else
  fail "missing dispatch file: expected a named WARN on stderr, got: $LAST_STDERR"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# --dry-run: no write performed, recovered=false, reason=DRY_RUN, would_write names the target
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "--dry-run: no file is written"
setup_sandbox
mkdir -p "$WORKDIR/specs/933_candidate"
write_dispatch_file specs/933_candidate 1 01 specs/933_candidate/reports
echo "dry run findings" > "$WORKDIR/msg.txt"
run_sut --task-dir specs/933_candidate --dispatch-seq 1 --message-file msg.txt \
  --agent general-research-agent --session sess_933 --dry-run

if [ "$(jqf '.recovered')" = "false" ] && [ "$(jqf '.reason')" = "DRY_RUN" ]; then
  pass "dry-run: recovered=false, reason=DRY_RUN"
else
  fail "dry-run: expected recovered=false/DRY_RUN, got: $LAST_STDOUT"
fi
if [ -n "$(jqf '.would_write')" ]; then
  pass "dry-run: would_write names the target path"
else
  fail "dry-run: would_write missing or empty"
fi
if [ ! -d "$WORKDIR/specs/933_candidate/reports" ] || \
   [ -z "$(ls -A "$WORKDIR/specs/933_candidate/reports" 2>/dev/null)" ]; then
  pass "dry-run: no file was actually written"
else
  fail "dry-run: a file was written despite --dry-run: $(ls -A "$WORKDIR/specs/933_candidate/reports")"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Acceptance, end-to-end: a research dispatch with no report, no return-meta, no handoff runs
# through orchestrate-cycle-postflight.sh (report_missing=true, verdict=failed), and this
# helper then recovers the findings. Reuses the postflight sandbox pattern directly (copies its
# full collaborator set) rather than re-implementing postflight's own logic.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Acceptance (end-to-end): postflight's report_missing=true feeds this helper, which recovers the findings"
setup_sandbox
POSTFLIGHT_SRC="$CORE_DIR/orchestrate-cycle-postflight.sh"
require_file "$POSTFLIGHT_SRC"
for f in orchestrate-cycle-postflight.sh orchestrate-recover-outcome.sh task-lock.sh \
         orchestrate-churn.sh orchestrate-loop-guard-init.sh \
         deploy-root-guard.sh command-route-agent.sh skill-base.sh system-defect-record.sh \
         state-write.sh generate-todo.sh update-task-status.sh git-commit-scoped.sh \
         errors-append.sh events-append.sh; do
  require_file "$CORE_DIR/$f"
  cp "$CORE_DIR/$f" "$WORKDIR/.claude/scripts/$f"
done
for f in common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh \
         phase-heading-patterns.sh status-vocabulary.sh task-lookup-lib.sh; do
  require_file "$CORE_DIR/lib/$f"
  cp "$CORE_DIR/lib/$f" "$WORKDIR/.claude/scripts/lib/$f"
done
mkdir -p "$WORKDIR/.claude/context/reference"
cp "$CORE_DIR/../context/reference/orchestrator-critical-paths.json" \
   "$WORKDIR/.claude/context/reference/orchestrator-critical-paths.json" 2>/dev/null || true
chmod +x "$WORKDIR"/.claude/scripts/*.sh
( cd "$WORKDIR" && git init -q && git config user.email t@t.com && git config user.name T )

mkdir -p "$WORKDIR/specs/934_candidate"
cat > "$WORKDIR/specs/state.json" <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 934, "project_name": "candidate", "task_type": "general", "status": "researching", "description": "candidate #934 -- end-to-end recovery fixture", "dependencies": [], "file_scope": [], "next_artifact_number": 1}]}
EOF
echo "## Tasks" > "$WORKDIR/specs/TODO.md"
( cd "$WORKDIR" && git add specs/ .claude/ >/dev/null 2>&1 && git commit -q -m "fixture" >/dev/null 2>&1 )
cat > "$WORKDIR/specs/934_candidate/.orchestrator-loop-guard" <<'EOF'
{"dispatch_seq_counter": 1, "detected_defects": [], "infra_failures": 0}
EOF
window_start=$(( $(date -u +%s) - 5 ))
POSTFLIGHT_STDOUT="$(mktemp)"
( cd "$WORKDIR" && bash .claude/scripts/orchestrate-cycle-postflight.sh 934 \
    --session sess_934 --state-file specs/state.json --task-dir specs/934_candidate \
    --phase research --task-type general --agent general-research-agent \
    --loop-guard-file specs/934_candidate/.orchestrator-loop-guard \
    --dispatch-seq 1 --dispatch-start-ts "$window_start" >"$POSTFLIGHT_STDOUT" 2>/dev/null )
postflight_json="$(cat "$POSTFLIGHT_STDOUT")"
rm -f "$POSTFLIGHT_STDOUT"

if [ "$(echo "$postflight_json" | jq -r '.report_missing')" = "true" ] && \
   [ "$(echo "$postflight_json" | jq -r '.verdict')" = "failed" ]; then
  pass "acceptance (e2e): postflight reports report_missing=true, verdict=failed for the double-miss"
else
  fail "acceptance (e2e): expected report_missing=true/verdict=failed, got: $postflight_json"
fi

# The lead's own Move 3 step: capture the agent's returned message verbatim, then call this
# helper. write_dispatch_file supplies the same Artifact Round shape orchestrate-build-dispatch.sh
# would have written for this dispatch.
write_dispatch_file specs/934_candidate 1 01 specs/934_candidate/reports
echo "the agent's actual findings, delivered by message instead of a report file" > "$WORKDIR/agent-message.txt"
( cd "$WORKDIR" && bash .claude/scripts/orchestrate-recover-message-findings.sh \
    --task-dir specs/934_candidate --dispatch-seq 1 --message-file agent-message.txt \
    --agent general-research-agent --session sess_934 )
recover_exit=$?

if [ "$recover_exit" -eq 0 ]; then
  pass "acceptance (e2e): the recovery helper exits 0"
else
  fail "acceptance (e2e): the recovery helper exited $recover_exit"
fi
if [ -f "$WORKDIR/specs/934_candidate/reports/01_recovered-agent-message.md" ] && \
   grep -q "the agent's actual findings" "$WORKDIR/specs/934_candidate/reports/01_recovered-agent-message.md"; then
  pass "acceptance (e2e): the findings text landed in reports/"
else
  fail "acceptance (e2e): recovered findings file missing or does not contain the expected text"
fi
e2e_status=$(jq -r --argjson n 934 '.active_projects[] | select(.project_number == $n) | .status' "$WORKDIR/specs/state.json")
if [ "$e2e_status" = "researching" ]; then
  pass "acceptance (e2e): state.json status is still not researched"
else
  fail "acceptance (e2e): expected status=researching, got: $e2e_status"
fi
e2e_defect_count=$(jq '.detected_defects | length' "$WORKDIR/specs/934_candidate/.orchestrator-loop-guard" 2>/dev/null)
if [ "$e2e_defect_count" -ge 1 ] 2>/dev/null; then
  pass "acceptance (e2e): a defect row exists (the double-miss was recorded)"
else
  fail "acceptance (e2e): expected >=1 detected_defects, got $e2e_defect_count"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ]
