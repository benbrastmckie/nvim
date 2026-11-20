#!/usr/bin/env bash
# test-roadmap-entries-lib.sh - Unit suite for scripts/lib/roadmap-entries-lib.sh, the one
# accessor for the ordered authored-batch list and the roadmap output path.
#
# Covers: milestone-then-batch order with milestone id / ordinal / stream index tags; a closed
# milestone's batches are skipped; the flat roadmap_batches fallback when no roadmap_milestones
# key exists; the milestone shape winning when both shapes are present (an empty
# roadmap_milestones array included); an empty store; the shape verdict for each case; the
# output-path default and its roadmap_context.output_path override; and the library's own
# sourcing contract (no shell options changed, no exit on an unreadable file).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 2
fi

LIB_UNDER_TEST="$(common_test_resolve_subject "roadmap-entries-lib.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/roadmap-entries-lib.sh" "$SCRIPT_DIR/../lib/roadmap-entries-lib.sh")" || exit 2
common_test_declare_subject "$LIB_UNDER_TEST"

PASSED=0
FAILED=0

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# --- sourcing contract: shell options unchanged, functions defined ---
opts_before="$(set +o)"
# shellcheck disable=SC1090
source "$LIB_UNDER_TEST"
opts_after="$(set +o)"
if [ "$opts_before" = "$opts_after" ]; then
  common_test_pass "sourcing the library changes no shell option"
else
  common_test_fail "sourcing the library changed a shell option"
fi
if declare -F roadmap_entries_batches >/dev/null && declare -F roadmap_entries_shape >/dev/null \
    && declare -F roadmap_entries_output_path >/dev/null; then
  common_test_pass "the three accessor functions are defined"
else
  common_test_fail "an accessor function is missing after sourcing"
fi

# expect LABEL ACTUAL EXPECTED
expect() {
  if [ "$2" = "$3" ]; then
    common_test_pass "$1"
  else
    common_test_fail "$1 -- expected [$3], got [$2]"
  fi
}
# tags FILE -- "milestone/ordinal/index:ids" per emitted batch, space-joined
tags() {
  roadmap_entries_batches "$1" \
    | jq -r '"\(.milestone // "-")/\(.ordinal)/\(.index):\(.task_ids | map(tostring) | join("+"))"' \
    | paste -sd' ' -
}

# --- nested order ---
cat > "$WORKDIR/nested.json" <<'JSON'
{"roadmap_milestones": [
  {"id": "M1", "title": "t", "aim": "a", "progress": {"status": "active"},
   "batches": [{"task_ids": [1, 2], "description": "one"}, {"task_ids": [3], "description": "two", "flags": "--hard"}]},
  {"id": "M2", "title": "t", "aim": "a", "progress": {"status": "planned"},
   "batches": [{"task_ids": [4], "description": "three", "rationale": "because"}]}
]}
JSON
expect "nested shape: milestone-then-batch order, tagged with milestone id, ordinal and index" \
  "$(tags "$WORKDIR/nested.json")" "M1/1/1:1+2 M1/2/2:3 M2/1/3:4"
expect "nested shape: batch fields pass through unchanged (description, flags, rationale)" \
  "$(roadmap_entries_batches "$WORKDIR/nested.json" | jq -rs 'map(.description + "|" + (.flags // "") + "|" + (.rationale // "")) | join(",")')" \
  "one||,two|--hard|,three||because"
expect "nested shape: verdict is milestones" "$(roadmap_entries_shape "$WORKDIR/nested.json")" "milestones"

# --- closed milestone skipped; ordinals stay per-milestone ---
cat > "$WORKDIR/closed.json" <<'JSON'
{"roadmap_milestones": [
  {"id": "M0", "title": "t", "aim": "a", "progress": {"status": "closed", "closed": "2026-01-01"},
   "batches": [{"task_ids": [9], "description": "done"}]},
  {"id": "M1", "title": "t", "aim": "a", "progress": {"status": "active"},
   "batches": [{"task_ids": [1], "description": "open"}]}
]}
JSON
expect "closed milestone: its batches are skipped and the stream index restarts at the first open batch" \
  "$(tags "$WORKDIR/closed.json")" "M1/1/1:1"

# --- flat fallback ---
cat > "$WORKDIR/flat.json" <<'JSON'
{"roadmap_batches": [{"task_ids": [5], "description": "f1"}, {"task_ids": [6, 7], "description": "f2"}]}
JSON
expect "flat fallback: roadmap_batches in array order, milestone null, ordinal == index" \
  "$(tags "$WORKDIR/flat.json")" "-/1/1:5 -/2/2:6+7"
expect "flat fallback: verdict is flat" "$(roadmap_entries_shape "$WORKDIR/flat.json")" "flat"

# --- both shapes present: nested wins, even when the milestone array is empty ---
cat > "$WORKDIR/both.json" <<'JSON'
{"roadmap_batches": [{"task_ids": [5], "description": "flat"}],
 "roadmap_milestones": [{"id": "M1", "title": "t", "aim": "a", "progress": {"status": "active"},
   "batches": [{"task_ids": [1], "description": "nested"}]}]}
JSON
expect "both shapes present: the milestone shape wins" "$(tags "$WORKDIR/both.json")" "M1/1/1:1"
cat > "$WORKDIR/both-empty.json" <<'JSON'
{"roadmap_batches": [{"task_ids": [5], "description": "flat"}], "roadmap_milestones": []}
JSON
expect "both shapes present, empty milestone array: still the milestone shape (no batches)" \
  "$(tags "$WORKDIR/both-empty.json")" ""
expect "both shapes present, empty milestone array: verdict is milestones" \
  "$(roadmap_entries_shape "$WORKDIR/both-empty.json")" "milestones"

# --- empty store ---
echo '{"active_projects": []}' > "$WORKDIR/empty.json"
expect "empty store: no batches" "$(tags "$WORKDIR/empty.json")" ""
expect "empty store: verdict is none" "$(roadmap_entries_shape "$WORKDIR/empty.json")" "none"
echo '{"roadmap_batches": []}' > "$WORKDIR/empty-flat.json"
expect "empty flat array: verdict is none" "$(roadmap_entries_shape "$WORKDIR/empty-flat.json")" "none"

# --- output path ---
expect "output path: default is specs/ROADMAP.md" \
  "$(roadmap_entries_output_path "$WORKDIR/empty.json")" "specs/ROADMAP.md"
echo '{"roadmap_context": {"output_path": "docs/ROADMAP.md"}}' > "$WORKDIR/path.json"
expect "output path: roadmap_context.output_path overrides the default" \
  "$(roadmap_entries_output_path "$WORKDIR/path.json")" "docs/ROADMAP.md"
echo '{"roadmap_context": {"output_path": ""}}' > "$WORKDIR/path-empty.json"
expect "output path: an empty stored path falls back to the default" \
  "$(roadmap_entries_output_path "$WORKDIR/path-empty.json")" "specs/ROADMAP.md"

# --- unreadable file: never exits the caller ---
roadmap_entries_batches "$WORKDIR/does-not-exist.json" >/dev/null 2>&1
expect "unreadable file: batches returns to the caller (no exit), with no output" \
  "$(roadmap_entries_batches "$WORKDIR/does-not-exist.json" 2>&1)" ""
expect "unreadable file: output path still answers the default" \
  "$(roadmap_entries_output_path "$WORKDIR/does-not-exist.json")" "specs/ROADMAP.md"

echo
echo "Results: $PASSED passed, $FAILED failed"
if [[ "$FAILED" -eq 0 ]]; then
  exit 0
else
  exit 1
fi
