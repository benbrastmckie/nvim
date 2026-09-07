#!/usr/bin/env bash
# test-orchestrate-build-aux-dispatch.sh - Fixture suite for orchestrate-build-aux-dispatch.sh,
# proving the fixed-agent-per-kind mapping, the frontmatter-only model resolution, the four
# kind-specific prompts, the "read your dispatch file first" pointer convention, and the negative
# assertion that this script NEVER shells out to memory-retrieve.sh, any literature script, or
# command-route-agent.sh (Decision 2's own MUST NOT).
#
# Structural model: test-orchestrate-build-dispatch.sh's SKILL_REPO_ROOT-env-override fixture
# (no synthetic `.claude/scripts/` tree is needed -- this SUT's only collaborator is skill-base.sh,
# its own real, unmodified neighbor).
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

SUT="$CORE_DIR/orchestrate-build-aux-dispatch.sh"
if [ ! -f "$SUT" ]; then
  echo "ERROR: orchestrate-build-aux-dispatch.sh not found at $SUT" >&2
  exit 2
fi
if [ ! -f "$CORE_DIR/skill-base.sh" ]; then
  echo "ERROR: skill-base.sh not found at $CORE_DIR/skill-base.sh" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

FIXTURE="$WORKDIR/fixture-repo"
TASK_NUM=999
PADDED="999"
PROJECT="fixture_task"
TASK_DIR_REL="specs/${PADDED}_${PROJECT}"

mkdir -p "$FIXTURE/${TASK_DIR_REL}/plans" "$FIXTURE/agents"
cat > "$FIXTURE/specs/state.json" <<EOF
{
  "active_projects": [
    {
      "project_number": ${TASK_NUM},
      "project_name": "${PROJECT}",
      "task_type": "general",
      "status": "implementing",
      "description": "Fixture task description for orchestrate-build-aux-dispatch.sh test suite."
    }
  ]
}
EOF
printf '# Fixture plan\n\n### Phase 1: Fixture phase [NOT STARTED]\n' > "$FIXTURE/${TASK_DIR_REL}/plans/01_fixture-plan.md"

# A fake agent-file tree the SUT's own EXT_ROOT ($SUT's-two-levels-up) glob can find: since the
# REAL script lives at .../core/scripts/orchestrate-build-aux-dispatch.sh, EXT_ROOT resolves to
# the real repo's agent-system/extensions/ regardless of $SKILL_REPO_ROOT (model resolution is
# NEVER fixture-relative -- it always searches the real, deployed-or-source-store agent tree).
# reviser-agent.md's real frontmatter already declares `model: opus`; assert against that
# pre-existing real fact rather than faking a second agents/ tree.

run_sut() {
  # Usage: run_sut <task_number> <kind> [extra SUT args...]
  local task="$1" kind="$2"; shift 2
  local stdout_file stderr_file
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  SKILL_REPO_ROOT="$FIXTURE" bash "$SUT" "$task" "$kind" --session sess_test_fixture --seq 7 "$@" \
    >"$stdout_file" 2>"$stderr_file"
  LAST_EXIT=$?
  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

jqf() { echo "$LAST_STDOUT" | jq -r "$1" 2>/dev/null; }

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Usage errors
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Usage errors"

run_sut "$TASK_NUM" "not-a-kind"
if [ "$LAST_EXIT" -eq 2 ]; then
  pass "unrecognized kind exits 2"
else
  fail "unrecognized kind did not exit 2 (got $LAST_EXIT)"
fi

run_sut "$TASK_NUM" "plan-revision"
if [ "$LAST_EXIT" -eq 2 ] && [[ "$LAST_STDERR" == *"revision-reason"* ]]; then
  pass "plan-revision without --revision-reason exits 2 naming the missing flag"
else
  fail "plan-revision without --revision-reason did not fail as expected (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Fixed agent per kind -- never task-type-routed
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Fixed agent per kind"

run_sut "$TASK_NUM" "drift-inspection" --plan-path "${FIXTURE}/${TASK_DIR_REL}/plans/01_fixture-plan.md"
if [ "$LAST_EXIT" -eq 0 ] && [ "$(jqf '.agent')" = "fork" ]; then
  pass "drift-inspection resolves agent=fork"
else
  fail "drift-inspection did not resolve agent=fork (exit=$LAST_EXIT stdout=$LAST_STDOUT stderr=$LAST_STDERR)"
fi
if [ "$(jqf '.model')" = "" ]; then
  pass "fork has no agent-frontmatter file in this repo -- model resolves to empty, never the string null"
else
  fail "fork's model did not resolve to empty (got: $(jqf '.model'))"
fi

run_sut "$TASK_NUM" "blocker-research" --blocker-desc "widget X is missing"
if [ "$LAST_EXIT" -eq 0 ] && [ "$(jqf '.agent')" = "fork" ]; then
  pass "blocker-research resolves agent=fork"
else
  fail "blocker-research did not resolve agent=fork (exit=$LAST_EXIT stdout=$LAST_STDOUT)"
fi

run_sut "$TASK_NUM" "plan-revision" --revision-reason blocker \
  --blocker-desc "widget X is missing" --findings-summary "typo in config" \
  --plan-path "${FIXTURE}/${TASK_DIR_REL}/plans/01_fixture-plan.md"
if [ "$LAST_EXIT" -eq 0 ] && [ "$(jqf '.agent')" = "reviser-agent" ]; then
  pass "plan-revision resolves agent=reviser-agent"
else
  fail "plan-revision did not resolve agent=reviser-agent (exit=$LAST_EXIT stdout=$LAST_STDOUT)"
fi
if [ "$(jqf '.model')" = "opus" ]; then
  pass "plan-revision's model is read from reviser-agent.md's OWN real frontmatter (opus)"
else
  fail "plan-revision's model did not resolve to opus (got: $(jqf '.model'))"
fi

run_sut "$TASK_NUM" "divergence-audit" --target "the flaky step" --verbatim-goal "make it pass" \
  --research-agent "nix-research-agent"
if [ "$LAST_EXIT" -eq 0 ] && [ "$(jqf '.agent')" = "nix-research-agent" ]; then
  pass "divergence-audit uses the passed-in --research-agent verbatim, never re-resolved by task type"
else
  fail "divergence-audit did not use the passed-in research agent (exit=$LAST_EXIT stdout=$LAST_STDOUT)"
fi

run_sut "$TASK_NUM" "divergence-audit" --target "x" --verbatim-goal "y"
if [ "$(jqf '.agent')" = "general-research-agent" ]; then
  pass "divergence-audit defaults to general-research-agent when --research-agent is omitted"
else
  fail "divergence-audit default agent incorrect (got: $(jqf '.agent'))"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Dispatch file content and naming
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Dispatch file content and naming"

run_sut "$TASK_NUM" "blocker-research" --blocker-desc "widget X is missing"
DF=$(jqf '.dispatch_file')
if [[ "$DF" == *".dispatch/7-aux-blocker-research.md" ]] && [ -f "$DF" ]; then
  pass "dispatch file is named {seq}-aux-{kind}.md under the task's .dispatch/ directory"
else
  fail "dispatch file naming incorrect (got: $DF)"
fi
if grep -q "read your dispatch file first" "$DF" 2>/dev/null || grep -qi "Read this file" "$DF" 2>/dev/null; then
  pass "dispatch file carries the 'read your dispatch file first' pointer convention"
else
  fail "dispatch file is missing the pointer convention"
fi
if grep -q "orchestrator_mode: false" "$DF" 2>/dev/null; then
  pass "dispatch file states orchestrator_mode: false"
else
  fail "dispatch file does not state orchestrator_mode: false"
fi
if grep -q "\.blocker-research\.json" "$DF" 2>/dev/null; then
  pass "blocker-research prompt instructs the fork to write .blocker-research.json (Decision 2's own departure from Stage 6's returned-text channel)"
else
  fail "blocker-research prompt does not name .blocker-research.json"
fi
if ! grep -qi "memory-context\|literature-briefing" "$DF" 2>/dev/null; then
  pass "dispatch file carries no memory-context or literature-briefing block"
else
  fail "dispatch file unexpectedly carries a memory/literature block"
fi

run_sut "$TASK_NUM" "drift-inspection" --plan-path "${FIXTURE}/${TASK_DIR_REL}/plans/01_fixture-plan.md"
DF2=$(jqf '.dispatch_file')
if grep -q "\.drift-inspection\.json" "$DF2" 2>/dev/null && grep -q "drift_pct" "$DF2" 2>/dev/null; then
  pass "drift-inspection prompt names .drift-inspection.json and drift_pct"
else
  fail "drift-inspection prompt missing expected content"
fi

run_sut "$TASK_NUM" "plan-revision" --revision-reason drift --drift-pct "0.42" \
  --drift-summary "too many deviations" --plan-path "${FIXTURE}/${TASK_DIR_REL}/plans/01_fixture-plan.md"
DF3=$(jqf '.dispatch_file')
if grep -q "drift_pct=0.42" "$DF3" 2>/dev/null; then
  pass "plan-revision (drift reason) interpolates the given drift_pct into the prompt"
else
  fail "plan-revision (drift reason) prompt missing drift_pct interpolation"
fi

run_sut "$TASK_NUM" "divergence-audit" --target "the flaky step" --verbatim-goal "make it pass"
DF4=$(jqf '.dispatch_file')
if grep -q "DIVERGENCE AUDIT" "$DF4" 2>/dev/null && grep -q "the flaky step" "$DF4" 2>/dev/null; then
  pass "divergence-audit prompt names DIVERGENCE AUDIT and the target verbatim"
else
  fail "divergence-audit prompt missing expected content"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Negative assertion: this script never shells out to memory/lit/route-agent collaborators
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Negative assertion: no memory/lit/route-agent collaborator calls"

if ! grep -vE '^\s*#' "$SUT" | grep -qE "memory-retrieve\.sh|literature-lit-flag-resolve\.sh|literature-briefing-invoke\.sh|command-route-agent\.sh|orchestrate-build-dispatch\.sh"; then
  pass "orchestrate-build-aux-dispatch.sh's own EXECUTABLE code never references memory/lit/route-agent/build-dispatch collaborators (header prose mentions them only to disclaim them)"
else
  fail "orchestrate-build-aux-dispatch.sh unexpectedly references a forbidden collaborator outside a comment"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
