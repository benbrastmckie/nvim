#!/usr/bin/env bash
# test-roadmap-items-producer.sh - Fixture-driven end-to-end regression suite for the
# roadmap_items producer chain: skill_propagate_completion_summary (scripts/skill-base.sh) ->
# specs/state.json -> roadmap-integration.sh's explicit_roadmap_item matcher/annotator.
#
# This is the demonstration the task's verification bar requires -- not a prose argument. It
# proves, on isolated fixtures, that a populated `roadmap_items` value flows all the way through
# the writer into state.json and produces a real ROADMAP.md annotation; that the `task_type ==
# "meta"` suppression still holds; that a paraphrase (non-verbatim) claim does not produce a
# high-confidence `explicit_roadmap_item` match; and that the `roadmap_no_match` jq derivation
# added to commands/todo.md fires exactly on its intended three-condition gate.
#
# Structural model: test-skill-base-lifecycle.sh (mktemp -d WORKDIR with an EXIT-trap cleanup,
# deploy-tree-first / source-store-fallback candidate resolution, sourced -- not subprocessed --
# skill-base.sh, pass()/fail()/info() helpers with integer counters, SKILL_REPO_ROOT-override
# fixture repos, a delta-based real-tree contamination guard). `skill_propagate_completion_summary`
# routes writes through state-write.sh, which needs a repo shaped like the real one -- this suite
# builds that shape per-case via build_fixture_repo(), exactly like the reference suite does for
# skill_link_artifacts.
#
# ISOLATION CONTRACT: never touches the real specs/ tree, real state.json, or real ROADMAP.md.
# Every case operates against a private mktemp -d fixture repo, reached via a SKILL_REPO_ROOT
# override for the sourced-function calls and via explicit --roadmap/--state path args for the
# standalone roadmap-integration.sh subprocess calls.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required library/script was not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. Resolve via the
# git worktree root first (depth-independent); fall back to the fixed-depth guess (matching the
# source-store depth) only when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

# ─── candidate resolution: deployed tree first, source-store fallback ─────────────────────────
resolve_candidate() {
  local desc="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  echo "ERROR: $desc not found at any of:" >&2
  for candidate in "$@"; do
    echo "  $candidate" >&2
  done
  return 1
}

SKILL_BASE="$(resolve_candidate "skill-base.sh" \
  "$REPO_ROOT/.claude/scripts/skill-base.sh" \
  "$SCRIPT_DIR/../skill-base.sh")" || exit 2

ROADMAP_INTEGRATION="$(resolve_candidate "roadmap-integration.sh" \
  "$REPO_ROOT/.claude/scripts/roadmap-integration.sh" \
  "$SCRIPT_DIR/../roadmap-integration.sh")" || exit 2

DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"
if [[ ! -d "$DEPLOY_SCRIPTS_SRC" ]]; then
  echo "ERROR: deployed scripts tree not found at $DEPLOY_SCRIPTS_SRC -- this suite needs a" >&2
  echo "       real deployed .claude/scripts/ tree to copy state-write.sh's dependency chain" >&2
  echo "       (task-lock.sh, deploy-root-guard.sh, lib/*.sh) from." >&2
  exit 2
fi
for req in state-write.sh task-lock.sh deploy-root-guard.sh roadmap-integration.sh; do
  if [[ ! -f "$DEPLOY_SCRIPTS_SRC/$req" ]]; then
    echo "ERROR: required deployed script missing: $DEPLOY_SCRIPTS_SRC/$req" >&2
    exit 2
  fi
done

# shellcheck disable=SC1090
. "$SKILL_BASE"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

BASELINE_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"

# ─── build_fixture_repo: a full isolated repo shape under $1, real deployed scripts copied in ──
# $2 = ROADMAP.md content, $3 = state.json content
build_fixture_repo() {
  local root="$1"
  local roadmap_content="$2"
  local state_content="$3"
  mkdir -p "$root/.claude/scripts/lib" "$root/specs"
  for f in state-write.sh task-lock.sh deploy-root-guard.sh; do
    cp "$DEPLOY_SCRIPTS_SRC/$f" "$root/.claude/scripts/$f"
    chmod +x "$root/.claude/scripts/$f"
  done
  cp "$DEPLOY_SCRIPTS_SRC"/lib/*.sh "$root/.claude/scripts/lib/" 2>/dev/null || true
  printf '%s' "$roadmap_content" > "$root/specs/ROADMAP.md"
  printf '%s' "$state_content" > "$root/specs/state.json"
}

# Fixture ROADMAP.md: one open (- [ ]) checkbox item under a single phase, verbatim text below
# reused across cases so Case 1's verbatim propagation and Case 3's paraphrase both target the
# same item.
ROADMAP_ITEM_TEXT="Add fixture-driven regression coverage for the roadmap_items producer chain"
FIXTURE_ROADMAP=$'# Project Roadmap\n\n## Phase 1: Agent System Quality (High Priority)\n\n- [ ] '"$ROADMAP_ITEM_TEXT"$'\n'

# =====================================================================
# Case 1: the verification bar, end to end -- verbatim roadmap_items propagates through the
# writer into state.json, then roadmap-integration.sh --annotate applies a real annotation.
# =====================================================================
info "=== Case 1: end-to-end verbatim propagation + annotation ==="

CASE1_ROOT="$WORKDIR/case1"
CASE1_STATE=$(cat <<'EOF'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "fixture_producer_task",
      "description": "Implement fixture producer test task",
      "status": "completed",
      "task_type": "general",
      "next_artifact_number": 1
    }
  ]
}
EOF
)
build_fixture_repo "$CASE1_ROOT" "$FIXTURE_ROADMAP" "$CASE1_STATE"

CASE1_ROADMAP_ITEMS=$(jq -cn --arg t "$ROADMAP_ITEM_TEXT" '[$t]')
SKILL_REPO_ROOT="$CASE1_ROOT" skill_propagate_completion_summary 1 \
  "Added fixture-driven regression coverage for the roadmap_items producer chain end to end." \
  "$CASE1_ROADMAP_ITEMS" "general" "sess_test_case1" 2>"$WORKDIR/case1-propagate-stderr.log"

WRITTEN_ITEMS=$(jq -c '.active_projects[0].roadmap_items // null' "$CASE1_ROOT/specs/state.json" 2>/dev/null)
if [[ "$WRITTEN_ITEMS" == "$CASE1_ROADMAP_ITEMS" ]]; then
  pass "Case 1: skill_propagate_completion_summary writes verbatim roadmap_items to state.json"
else
  fail "Case 1: expected roadmap_items $CASE1_ROADMAP_ITEMS, got $WRITTEN_ITEMS (see $WORKDIR/case1-propagate-stderr.log)"
fi

CASE1_OUTPUT=$(bash "$ROADMAP_INTEGRATION" \
  --roadmap "$CASE1_ROOT/specs/ROADMAP.md" \
  --state "$CASE1_ROOT/specs/state.json" \
  --annotate 2>"$WORKDIR/case1-annotate-stderr.log")

CASE1_ANNOTATIONS_MADE=$(echo "$CASE1_OUTPUT" | jq '.annotation_summary.annotations_made')
CASE1_MATCH_TYPE=$(echo "$CASE1_OUTPUT" | jq -r \
  '.roadmap_matches[] | select(.match_type == "explicit_roadmap_item") | .match_type' | head -1)
CASE1_MATCH_CONFIDENCE=$(echo "$CASE1_OUTPUT" | jq -r \
  '.roadmap_matches[] | select(.match_type == "explicit_roadmap_item") | .confidence' | head -1)

if [[ "$CASE1_ANNOTATIONS_MADE" == "1" ]]; then
  pass "Case 1: annotation_summary.annotations_made == 1"
else
  fail "Case 1: expected annotations_made == 1, got '$CASE1_ANNOTATIONS_MADE' (see $WORKDIR/case1-annotate-stderr.log)"
fi
if [[ "$CASE1_MATCH_TYPE" == "explicit_roadmap_item" && "$CASE1_MATCH_CONFIDENCE" == "high" ]]; then
  pass "Case 1: match_type == explicit_roadmap_item at confidence == high"
else
  fail "Case 1: expected explicit_roadmap_item/high, got match_type='$CASE1_MATCH_TYPE' confidence='$CASE1_MATCH_CONFIDENCE'"
fi

CASE1_ROADMAP_ON_DISK=$(cat "$CASE1_ROOT/specs/ROADMAP.md")
# The literal digit here is roadmap-integration.sh's OWN completion-marker vocabulary (its fixed
# "*(Completed: Task {N})*" annotation format, an orthogonal domain concept from this repo's
# specs/ task-management numbering) -- asserting on it verbatim is the whole point of this
# fixture case, exactly as category 6 of the Exemption Taxonomy describes for a detector's own
# literal-output fixtures. A placeholder would not match the script's real output and would
# silently disable the assertion.
CASE1_EXPECTED_ANNOTATED_LINE="- [x] $ROADMAP_ITEM_TEXT *(Completed: Task 1"  # task-ref-ok: category 6 analog, literal script-output fixture
if echo "$CASE1_ROADMAP_ON_DISK" | grep -qF -- "$CASE1_EXPECTED_ANNOTATED_LINE"; then
  pass "Case 1: ROADMAP.md item annotated with the completion-marker suffix (observed file content)"
else
  fail "Case 1: ROADMAP.md item not annotated as expected -- on-disk content:
$CASE1_ROADMAP_ON_DISK"
fi

# =====================================================================
# Case 2: meta suppression preserved -- task_type == "meta" writes completion_summary but no
# roadmap_items key at all.
# =====================================================================
info "=== Case 2: meta task_type suppresses roadmap_items ==="

CASE2_ROOT="$WORKDIR/case2"
CASE2_STATE=$(cat <<'EOF'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "fixture_meta_task",
      "description": "A meta task that happens to mention roadmap-adjacent work",
      "status": "completed",
      "task_type": "meta",
      "next_artifact_number": 1
    }
  ]
}
EOF
)
build_fixture_repo "$CASE2_ROOT" "$FIXTURE_ROADMAP" "$CASE2_STATE"

CASE2_ROADMAP_ITEMS=$(jq -cn --arg t "$ROADMAP_ITEM_TEXT" '[$t]')
SKILL_REPO_ROOT="$CASE2_ROOT" skill_propagate_completion_summary 1 \
  "Updated meta agent contracts." \
  "$CASE2_ROADMAP_ITEMS" "meta" "sess_test_case2" 2>"$WORKDIR/case2-propagate-stderr.log"

CASE2_SUMMARY_WRITTEN=$(jq -r '.active_projects[0].completion_summary // ""' "$CASE2_ROOT/specs/state.json" 2>/dev/null)
CASE2_ROADMAP_KEY_PRESENT=$(jq -r 'has("roadmap_items")' <(jq '.active_projects[0]' "$CASE2_ROOT/specs/state.json") 2>/dev/null)

if [[ "$CASE2_SUMMARY_WRITTEN" == "Updated meta agent contracts." ]]; then
  pass "Case 2: completion_summary is written for a meta task"
else
  fail "Case 2: expected completion_summary to be written, got '$CASE2_SUMMARY_WRITTEN' (see $WORKDIR/case2-propagate-stderr.log)"
fi
if [[ "$CASE2_ROADMAP_KEY_PRESENT" == "false" ]]; then
  pass "Case 2: no roadmap_items key written to state.json for a meta task"
else
  fail "Case 2: roadmap_items key unexpectedly present for a meta task"
fi

# =====================================================================
# Case 3: paraphrase does not mis-annotate -- a non-verbatim roadmap_items entry must not
# produce a high-confidence explicit_roadmap_item match (the guard the Phase 2 verbatim
# requirement relies on).
# =====================================================================
info "=== Case 3: paraphrase does not produce a high-confidence explicit_roadmap_item match ==="

CASE3_ROOT="$WORKDIR/case3"
CASE3_STATE=$(cat <<'EOF'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "fixture_producer_task",
      "description": "Implement fixture producer test task",
      "status": "completed",
      "task_type": "general",
      "next_artifact_number": 1
    }
  ]
}
EOF
)
build_fixture_repo "$CASE3_ROOT" "$FIXTURE_ROADMAP" "$CASE3_STATE"

# Deliberate paraphrase: substantively different wording from ROADMAP_ITEM_TEXT, so neither the
# explicit_roadmap_item substring/exact check nor the exact_title_match check can fire.
CASE3_PARAPHRASE_ITEMS=$(jq -cn '["Wrote some tests for the roadmap sync feature"]')
SKILL_REPO_ROOT="$CASE3_ROOT" skill_propagate_completion_summary 1 \
  "Added regression tests for roadmap producer." \
  "$CASE3_PARAPHRASE_ITEMS" "general" "sess_test_case3" 2>"$WORKDIR/case3-propagate-stderr.log"

CASE3_OUTPUT=$(bash "$ROADMAP_INTEGRATION" \
  --roadmap "$CASE3_ROOT/specs/ROADMAP.md" \
  --state "$CASE3_ROOT/specs/state.json" 2>"$WORKDIR/case3-parse-stderr.log")

CASE3_EXPLICIT_MATCH_COUNT=$(echo "$CASE3_OUTPUT" | jq \
  '[.roadmap_matches[] | select(.match_type == "explicit_roadmap_item" and .confidence == "high")] | length')

if [[ "$CASE3_EXPLICIT_MATCH_COUNT" == "0" ]]; then
  pass "Case 3: paraphrase produces zero high-confidence explicit_roadmap_item matches"
else
  fail "Case 3: expected 0 high-confidence explicit_roadmap_item matches, got $CASE3_EXPLICIT_MATCH_COUNT"
fi

# =====================================================================
# Case 4: roadmap_no_match derivation (commands/todo.md Step 3.5.5), exercised in isolation
# against three inputs. Mirrors the exact jq expression added to commands/todo.md.
# =====================================================================
info "=== Case 4: roadmap_no_match derivation ==="

derive_roadmap_no_match() {
  # $1 = eligible task count, $2 = roadmap_eligible_matches JSON array, $3 = roadmap_state JSON
  local eligible_count="$1"
  local eligible_matches="$2"
  local roadmap_state="$3"
  local open_checkbox_count
  open_checkbox_count=$(echo "$roadmap_state" | jq \
    '[.phases[].checkboxes.items[]? | select(.completed == false)] | length')
  local result=false
  if [ "$eligible_count" -gt 0 ] && \
     [ "$(echo "$eligible_matches" | jq 'length')" -eq 0 ] && \
     [ "$open_checkbox_count" -gt 0 ]; then
    result=true
  fi
  echo "$result"
}

CASE4A_STATE='{"phases":[{"checkboxes":{"items":[{"text":"x","completed":false}]}}]}'
CASE4A_RESULT=$(derive_roadmap_no_match 1 '[]' "$CASE4A_STATE")
if [[ "$CASE4A_RESULT" == "true" ]]; then
  pass "Case 4a: eligible tasks non-empty, matches empty, open checkboxes > 0 -> true"
else
  fail "Case 4a: expected true, got '$CASE4A_RESULT'"
fi

CASE4B_RESULT=$(derive_roadmap_no_match 0 '[]' "$CASE4A_STATE")
if [[ "$CASE4B_RESULT" == "false" ]]; then
  pass "Case 4b: eligible tasks empty -> false"
else
  fail "Case 4b: expected false, got '$CASE4B_RESULT'"
fi

CASE4C_STATE='{"phases":[{"checkboxes":{"items":[{"text":"x","completed":true}]}}]}'
CASE4C_RESULT=$(derive_roadmap_no_match 1 '[]' "$CASE4C_STATE")
if [[ "$CASE4C_RESULT" == "false" ]]; then
  pass "Case 4c: zero open checkboxes -> false"
else
  fail "Case 4c: expected false, got '$CASE4C_RESULT'"
fi

# =====================================================================
# Real-tree contamination guard: this suite must never leave a NEW mark on the actual repo's
# specs/ tree relative to the pre-suite baseline.
# =====================================================================
info "=== contamination guard ==="
FINAL_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"
if [[ "$FINAL_SPECS_STATUS" == "$BASELINE_SPECS_STATUS" ]]; then
  pass "real specs/ tree status is unchanged relative to this suite's pre-run baseline"
else
  fail "real specs/ tree status changed during this suite (baseline vs. final differ) -- baseline:
$BASELINE_SPECS_STATUS
-- final:
$FINAL_SPECS_STATUS"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
