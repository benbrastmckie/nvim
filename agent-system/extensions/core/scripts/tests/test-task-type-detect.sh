#!/usr/bin/env bash
# test-task-type-detect.sh - Table-driven regression suite for scripts/lib/task-type-detect.sh's
# detect_task_type function: the strong-anchor + weak-signal-threshold resolution ladder that
# replaced commands/task.md step 4's old first-keyword-match-wins table (see Decision D6 in
# specs/210_fix_task_create_topic_assignment_order/plans/01_topic-order-and-keyword-routing.md).
#
# Structured table-driven after test-routing-resolution.sh: cases are (description, expected
# task_type) pairs run through detect_task_type via a mktemp -d SCRATCH extensions_dir fixture
# (so this suite does not depend on the live manifest set), plus one case run against the real
# manifests (deployed tree if present, source store otherwise) to pin the actual
# literature-keyword regression this task fixed.
#
# Follows the core shell-test convention: pass()/fail()/info() helpers, PASSED/FAILED integer
# counters, mktemp -d workdir with a trap EXIT cleanup, exit 0 on all-pass and exit 1 on any-fail.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi

# ─── candidate resolution: deployed tree first, source-store fallback (mirrors
# test-skill-base-lifecycle.sh's resolve_candidate) -- this makes the SAME suite file correct
# whether it runs pre-deploy (source store) or post-deploy (deployed copy under
# .claude/scripts/tests/), since each copy's own resolve_candidate call prefers its own sibling
# deployed lib first. ────────────────────────────────────────────────────────────────────────
resolve_candidate() {
  local desc="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" || -d "$candidate" ]]; then
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

LIB_SRC="$(resolve_candidate "task-type-detect.sh" \
  "$REPO_ROOT/.claude/scripts/lib/task-type-detect.sh" \
  "$REPO_ROOT/agent-system/extensions/core/scripts/lib/task-type-detect.sh")" || exit 2

# REAL_EXT_ROOT resolves relative to THIS suite's own SCRIPT_DIR, not deployed-first, so the
# source-store copy always checks the source store's own extensions/ (never a possibly-stale
# deployed .claude/extensions/ that has not been redeployed yet) and the deployed copy always
# checks its sibling .claude/extensions/. The two trees have different relative depths below
# scripts/tests/ (source: extensions/core/scripts/tests -> three levels up is "extensions";
# deployed: .claude/scripts/tests -> two levels up is ".claude", then down into "extensions"),
# so shape is detected by checking which candidate exists and is actually named "extensions".
_SRC_STORE_EXT_CANDIDATE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
if [[ -d "$_SRC_STORE_EXT_CANDIDATE" && "$(basename "$_SRC_STORE_EXT_CANDIDATE")" == "extensions" ]]; then
  REAL_EXT_ROOT="$_SRC_STORE_EXT_CANDIDATE"
else
  REAL_EXT_ROOT="$(resolve_candidate "real extensions directory" \
    "$(cd "$SCRIPT_DIR/../.." && pwd)/extensions")" || exit 2
fi
unset _SRC_STORE_EXT_CANDIDATE

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 2
fi

# shellcheck disable=SC1090
. "$LIB_SRC"
if ! declare -F detect_task_type >/dev/null 2>&1; then
  echo "ERROR: detect_task_type is not a defined function after sourcing $LIB_SRC" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ─── scratch extensions_dir fixture: no keyword_overrides at all, so every case below exercises
# only the strong-anchor / weak-signal / project-default ladder, never step 2's extension scan
# (which the "real manifests" case at the end covers separately). Also a scratch, empty
# state.json (no default_task_type), so step 3 is always a no-op here too. ────────────────────
SCRATCH_EXT_DIR="$WORKDIR/extensions"
mkdir -p "$SCRATCH_EXT_DIR"
SCRATCH_STATE="$WORKDIR/state.json"
echo '{"active_projects": []}' > "$SCRATCH_STATE"

run_case() {
  # run_case <label> <description> <expected>
  local label="$1" desc="$2" expected="$3" got
  got=$(detect_task_type "$desc" "$SCRATCH_STATE" "$SCRATCH_EXT_DIR")
  if [[ "$got" == "$expected" ]]; then
    pass "$label -> '$got'"
  else
    fail "$label -> expected '$expected', got '$got' (description: \"$desc\")"
  fi
}

# =====================================================================
# The six D6 acceptance cases (plan's D6 detail table, worked against the six descriptions named
# in the dispatch's ACCEPTANCE section).
# =====================================================================
info "=== D6 acceptance cases ==="

run_case "Acceptance 1 (agent, in passing)" \
  "research and revise the AI agent objectives ... training models ... agent harnesses" \
  "general"

run_case "Acceptance 2 (lean, in passing)" \
  "Why Lean over Rocq when there are more resources for software verification in Rocq?" \
  "general"

run_case "Acceptance 3 (proof, in passing, business strategy)" \
  "Write the quarterly business strategy memo; footnote references the Logos proof theory in passing" \
  "general"

run_case "Acceptance 4 (lean4 formalization mentioning literature)" \
  "Formalize the CoherentConstruction lemma in lean4, citing prior literature on the topic" \
  "lean4"

run_case "Acceptance 5 (skill-<word> strong anchor)" \
  "Update skill-orchestrate's dispatch to pass --lit" \
  "meta"

run_case "Acceptance 6 (.lean path strong anchor)" \
  "Prove soundness lemma in Metalogic/Soundness.lean" \
  "lean4"

# =====================================================================
# Negative controls (pin the threshold's intent, per Phase 7's Scope Hypothesis).
# =====================================================================
info "=== Negative controls ==="

run_case "Control 1 (genuine short agent-system description, strong anchor)" \
  "Add a new hook to .claude/hooks/" \
  "meta"

run_case "Control 2 (one incidental routing word only)" \
  "Fix a scheduling bug affecting agent response latency" \
  "general"

# =====================================================================
# Literature-keyword regression guard: literature alongside lean4 content resolves lean4, not
# meta -- the exact defect this task's Phase 4 (manifest fix) and Phase 5/6 (detection rewrite)
# jointly close.
# =====================================================================
info "=== Literature-keyword regression guard ==="

run_case "Literature + lean4 content resolves lean4, not meta" \
  "Survey the literature and formalize the resulting theorem as a lean4 proof" \
  "lean4"

# =====================================================================
# Real-manifest case: run one description against the REAL manifest set (deployed if present,
# else the source store) to pin the actual fix -- a bare mention of "literature" no longer
# force-routes to meta now that the literature manifest's keyword_overrides block is removed.
# =====================================================================
info "=== Real manifests (${REAL_EXT_ROOT}) ==="

real_got=$(detect_task_type "Search the literature for prior citations on this topic" \
  "$SCRATCH_STATE" "$REAL_EXT_ROOT")
if [[ "$real_got" != "meta" ]]; then
  pass "Real manifests: bare 'literature' mention no longer force-routes to meta (got '$real_got')"
else
  fail "Real manifests: bare 'literature' mention still resolves to meta -- the literature manifest's keyword_overrides regression has returned"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [[ "$FAILED" -eq 0 ]]; then
  exit 0
else
  exit 1
fi
