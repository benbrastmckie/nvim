#!/usr/bin/env bash
# test-slice-series.sh - Fixture-driven regression suite for slice-series.sh. Phase 1 covers
# the static no-push/no-forge assertion (written and passing before any other case, per this
# task's own Decision record) and every `check` refusal class plus its passing path. Phase 2
# adds `build` cases and the untouched-HEAD/index/worktree assertion. Phase 3 adds `status`
# cases, the union check, and two further static assertions (repo-agnosticism; no dependency on
# review-stack-prepare.sh).
#
# Follows the deployed-shape sandbox convention established by test-milestone-review-handoff.sh
# / test-review-stack-prepare.sh (deploy-root-guard.sh's default structural check requires the
# script's own directory to end in /.claude or /.opencode). Roots are resolved via
# common_test_repo_root / common_test_ext_root rather than a fixed-depth parent walk, so this
# suite runs correctly from both the source store and the deployed tree.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
EXT_ROOT="$(common_test_ext_root "$REPO_ROOT")" || EXT_ROOT="$REPO_ROOT/agent-system/extensions"
SS="$(common_test_resolve_candidate "slice-series.sh" \
  "$REPO_ROOT/.claude/scripts/slice-series.sh" \
  "$EXT_ROOT/core/scripts/slice-series.sh" \
  "$SCRIPT_DIR/../slice-series.sh")" || exit 2
GUARD="$(common_test_resolve_candidate "deploy-root-guard.sh" \
  "$REPO_ROOT/.claude/scripts/deploy-root-guard.sh" \
  "$EXT_ROOT/core/scripts/deploy-root-guard.sh" \
  "$SCRIPT_DIR/../deploy-root-guard.sh")" || exit 2
LIBDIR="$(dirname "$GUARD")/lib"
common_test_declare_subject "$SS"

PASSED=0
FAILED=0

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 1
fi

common_test_workdir_init

BRANCH_TARGET="basework"
BRANCH_WORK="featwork"

# install_scripts <repo> -- the deployed-shape copies the script under test needs.
install_scripts() {
  local d="$1"
  mkdir -p "$d/.claude/scripts/lib"
  cp -r "$LIBDIR/." "$d/.claude/scripts/lib/"
  cp "$GUARD" "$d/.claude/scripts/deploy-root-guard.sh"
  cp "$SS" "$d/.claude/scripts/slice-series.sh"
  chmod +x "$d"/.claude/scripts/*.sh
}

# make_repo -- a sandbox on $BRANCH_TARGET with a sibling $BRANCH_WORK carrying one commit that
# adds sliceA/*, sliceB/*, and notland/* paths. Branch names are neither "main" nor "master", so
# a hardcoded assumption of either would fail this fixture rather than pass by accident.
make_repo() {
  local d
  d="$(mktemp -d -p "$WORKDIR")"
  git init -q -b "$BRANCH_TARGET" "$d"
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test Suite"
  install_scripts "$d"
  echo base >"$d/README.md"
  git -C "$d" add README.md >/dev/null 2>&1
  git -C "$d" commit -q -m base >/dev/null 2>&1
  git -C "$d" branch "$BRANCH_WORK"
  git -C "$d" checkout -q "$BRANCH_WORK"
  mkdir -p "$d/sliceA" "$d/sliceB" "$d/notland"
  echo one >"$d/sliceA/f1.txt"
  echo one >"$d/sliceA/f2.txt"
  echo one >"$d/sliceB/f1.txt"
  echo one >"$d/notland/ignored.txt"
  git -C "$d" add sliceA sliceB notland >/dev/null 2>&1
  git -C "$d" commit -q -m work >/dev/null 2>&1
  git -C "$d" checkout -q "$BRANCH_TARGET"
  printf '%s' "$d"
}

# base_doc -- the happy-path series document: sliceA and sliceB each under the default bar,
# sliceB depends_on sliceA (a valid, acyclic edge), notland/* excluded via not_landing.
base_doc() {
  cat <<EOF
{
  "series_id": "s1",
  "target": {"remote": "", "branch": "${BRANCH_TARGET}", "commit": ""},
  "work_ref": {"name": "${BRANCH_WORK}", "commit": ""},
  "bar": {"lines": 1500, "files": 30, "source": "default"},
  "not_landing": ["notland/*"],
  "slices": [
    {"id": "sliceA", "title": "A", "paths": ["sliceA/*"], "depends_on": [], "over_bar_reason": "", "state": "proposed"},
    {"id": "sliceB", "title": "B", "paths": ["sliceB/*"], "depends_on": ["sliceA"], "over_bar_reason": "", "state": "proposed"}
  ]
}
EOF
}

run_ss() {
  local repo="$1"
  shift
  LAST_OUT="$(cd "$repo" && bash .claude/scripts/slice-series.sh "$@" 2>&1)"
  LAST_CODE=$?
}

run_ss_stdin() {
  local repo="$1" doc="$2"
  shift 2
  LAST_OUT="$(cd "$repo" && printf '%s' "$doc" | bash .claude/scripts/slice-series.sh "$@" - 2>&1)"
  LAST_CODE=$?
}

assert_refusal() {
  local label="$1" expected_code="$2" expected_reason="$3"
  if [ "$LAST_CODE" -eq "$expected_code" ] && printf '%s' "$LAST_OUT" | grep -q "REFUSED: slice-series.sh: ${expected_reason}:"; then
    common_test_pass "$label"
  else
    common_test_fail "$label" "expected exit ${expected_code} with reason ${expected_reason}, got exit ${LAST_CODE}: ${LAST_OUT}"
  fi
}

# =====================================================================
# Static assertion FIRST: no push/checkout/switch/merge/rebase/replay/gh/glab invocation.
# This case must be written and passing before any later case is added (Decision record).
# =====================================================================
forbidden_hits="$(grep -nE '\bgit[[:space:]]+(push|checkout|switch|rebase)\b|\bgit[[:space:]]+merge([[:space:]]|$)|git-replay|\bgh[[:space:]]+(pr|api)\b|\bglab[[:space:]]+mr\b' "$SS" | grep -v '^[0-9]*:#' | grep -v "NEVER CALLS" || true)"
if [ -z "$forbidden_hits" ]; then
  common_test_pass "static check: slice-series.sh contains no push/checkout/switch/merge/rebase/replay/gh/glab invocation"
else
  common_test_fail "static check: found forbidden invocation(s)" "$forbidden_hits"
fi

# =====================================================================
# Usage errors (exit 2)
# =====================================================================
repo="$(make_repo)"
run_ss "$repo"
assert_refusal "no subcommand refuses with usage_error, exit 2" 2 usage_error
rm -rf "$repo"

repo="$(make_repo)"
run_ss "$repo" bogus
assert_refusal "an unknown subcommand refuses with usage_error, exit 2" 2 usage_error
rm -rf "$repo"

repo="$(make_repo)"
run_ss "$repo" check
if [ "$LAST_CODE" -eq 2 ]; then
  common_test_pass "check with no document argument exits 2 (usage) rather than defaulting"
else
  common_test_fail "check with no document argument" "expected exit 2, got ${LAST_CODE}: ${LAST_OUT}"
fi
rm -rf "$repo"

# =====================================================================
# document_unreadable / document_invalid
# =====================================================================
repo="$(make_repo)"
run_ss "$repo" check /no/such/document.json
assert_refusal "check on a missing document path refuses with document_unreadable, exit 11" 11 document_unreadable
rm -rf "$repo"

repo="$(make_repo)"
run_ss_stdin "$repo" 'not json at all' check
assert_refusal "check on malformed JSON refuses with document_invalid, exit 10" 10 document_invalid
rm -rf "$repo"

repo="$(make_repo)"
run_ss_stdin "$repo" '{"series_id":"s1"}' check
assert_refusal "check on a document missing required keys refuses with document_invalid, exit 10" 10 document_invalid
rm -rf "$repo"

# =====================================================================
# target_unresolvable / work_ref_unresolvable
# =====================================================================
repo="$(make_repo)"
doc="$(base_doc | jq '.target.branch = "no-such-branch-anywhere"')"
run_ss_stdin "$repo" "$doc" check
assert_refusal "an unresolvable target refuses with target_unresolvable, exit 20" 20 target_unresolvable
rm -rf "$repo"

repo="$(make_repo)"
doc="$(base_doc | jq '.work_ref.name = "no-such-ref-anywhere"')"
run_ss_stdin "$repo" "$doc" check
assert_refusal "an unresolvable work_ref refuses with work_ref_unresolvable, exit 21" 21 work_ref_unresolvable
rm -rf "$repo"

# =====================================================================
# target_not_ancestor
# =====================================================================
repo="$(make_repo)"
git -C "$repo" checkout -q -b "diverged" "$BRANCH_TARGET"
echo diverged >"$repo/diverge.txt"
git -C "$repo" add diverge.txt >/dev/null 2>&1
git -C "$repo" commit -q -m diverge >/dev/null 2>&1
git -C "$repo" checkout -q "$BRANCH_TARGET"
doc="$(base_doc | jq '.target.branch = "diverged"')"
run_ss_stdin "$repo" "$doc" check
assert_refusal "a target that is not an ancestor of work_ref refuses with target_not_ancestor, exit 22" 22 target_not_ancestor
rm -rf "$repo"

# =====================================================================
# path_unassigned
# =====================================================================
repo="$(make_repo)"
doc="$(base_doc | jq 'del(.slices[1])')" # drop sliceB; its paths become unassigned
run_ss_stdin "$repo" "$doc" check
assert_refusal "a difference path assigned to no slice and not matched by not_landing refuses with path_unassigned, exit 23" 23 path_unassigned
rm -rf "$repo"

# =====================================================================
# path_in_two_slices
# =====================================================================
repo="$(make_repo)"
doc="$(base_doc | jq '.slices[1].paths = ["sliceA/*"]')" # sliceB now also claims sliceA's paths
run_ss_stdin "$repo" "$doc" check
assert_refusal "a difference path matching two slices' paths refuses with path_in_two_slices, exit 24" 24 path_in_two_slices
rm -rf "$repo"

# =====================================================================
# glob_empty
# =====================================================================
repo="$(make_repo)"
doc="$(base_doc | jq '.slices[0].paths = ["sliceA/*", "nowhere/*"]')"
run_ss_stdin "$repo" "$doc" check
assert_refusal "a declared glob matching zero difference paths refuses with glob_empty, exit 25" 25 glob_empty
rm -rf "$repo"

repo="$(make_repo)"
doc="$(base_doc | jq '.not_landing = ["notland/*", "nowhere/*"]')"
run_ss_stdin "$repo" "$doc" check
assert_refusal "a not_landing glob matching zero difference paths refuses with glob_empty, exit 25" 25 glob_empty
rm -rf "$repo"

# =====================================================================
# depends_on_unknown / depends_on_cycle
# =====================================================================
repo="$(make_repo)"
doc="$(base_doc | jq '.slices[1].depends_on = ["no-such-slice"]')"
run_ss_stdin "$repo" "$doc" check
assert_refusal "depends_on naming an undeclared slice refuses with depends_on_unknown, exit 26" 26 depends_on_unknown
rm -rf "$repo"

repo="$(make_repo)"
doc="$(base_doc | jq '.slices[0].depends_on = ["sliceB"]')" # sliceA<->sliceB cycle
run_ss_stdin "$repo" "$doc" check
assert_refusal "a depends_on cycle refuses with depends_on_cycle, exit 27" 27 depends_on_cycle
rm -rf "$repo"

# =====================================================================
# over_bar_no_reason / accepted reasons
# =====================================================================
repo="$(make_repo)"
# push sliceA over a tiny bar with no reason.
doc="$(base_doc | jq '.bar.lines = 0 | .bar.files = 0')"
run_ss_stdin "$repo" "$doc" check
assert_refusal "a slice over the bar with no over_bar_reason refuses with over_bar_no_reason, exit 28" 28 over_bar_no_reason
rm -rf "$repo"

repo="$(make_repo)"
doc="$(base_doc | jq '.bar.lines = 0 | .bar.files = 0 | .slices[0].over_bar_reason = "single_file" | .slices[1].over_bar_reason = "single_file"')"
run_ss_stdin "$repo" "$doc" check
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -q '^OK$'; then
  common_test_pass "a slice over the bar with an accepted over_bar_reason (single_file) is not refused"
else
  common_test_fail "accepted over_bar_reason case" "expected exit 0 with OK, got exit ${LAST_CODE}: ${LAST_OUT}"
fi
rm -rf "$repo"

repo="$(make_repo)"
doc="$(base_doc | jq '.bar.lines = 0 | .bar.files = 0 | .slices[0].over_bar_reason = "generated_tree" | .slices[1].over_bar_reason = "generated_tree"')"
run_ss_stdin "$repo" "$doc" check
if [ "$LAST_CODE" -eq 0 ]; then
  common_test_pass "a slice over the bar with the other accepted over_bar_reason (generated_tree) is not refused"
else
  common_test_fail "accepted over_bar_reason (generated_tree) case" "expected exit 0, got exit ${LAST_CODE}: ${LAST_OUT}"
fi
rm -rf "$repo"

repo="$(make_repo)"
doc="$(base_doc | jq '.bar.lines = 0 | .bar.files = 0 | .slices[0].over_bar_reason = "because i said so" | .slices[1].over_bar_reason = "single_file"')"
run_ss_stdin "$repo" "$doc" check
assert_refusal "an over_bar_reason outside the two accepted values still refuses with over_bar_no_reason, exit 28" 28 over_bar_no_reason
rm -rf "$repo"

# =====================================================================
# Passing path: counts, via a file argument (not stdin) and via '-' stdin
# =====================================================================
repo="$(make_repo)"
doc="$(base_doc)"
printf '%s' "$doc" >"$repo/candidate.json"
run_ss "$repo" check candidate.json
if [ "$LAST_CODE" -eq 0 ] \
  && printf '%s' "$LAST_OUT" | grep -q '^OK$' \
  && printf '%s' "$LAST_OUT" | grep -q '^diff_total=4$' \
  && printf '%s' "$LAST_OUT" | grep -q '^assigned=3 unassigned=0 in_two_slices=0 not_landing=1$' \
  && printf '%s' "$LAST_OUT" | grep -q '^SLICE sliceA files=2 lines=2 ' \
  && printf '%s' "$LAST_OUT" | grep -q '^SLICE sliceB files=1 lines=1 '; then
  common_test_pass "check on a valid candidate-document PATH prints the counts prompt 2 needs"
else
  common_test_fail "valid candidate-document path case" "$LAST_OUT"
fi
rm -rf "$repo"

repo="$(make_repo)"
doc="$(base_doc)"
run_ss_stdin "$repo" "$doc" check
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -q '^OK$'; then
  common_test_pass "check on a valid candidate document read from stdin ('-') succeeds and writes nothing durable"
else
  common_test_fail "valid candidate-document stdin case" "$LAST_OUT"
fi
if [ ! -e "$repo/specs/.orchestration/slices" ]; then
  common_test_pass "a validation-only check run writes no durable series state"
else
  common_test_fail "validation-only check run wrote durable state" "specs/.orchestration/slices exists"
fi
rm -rf "$repo"

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
