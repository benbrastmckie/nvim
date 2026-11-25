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
SS="$(common_test_resolve_subject "slice-series.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/slice-series.sh" \
  "$EXT_ROOT/core/scripts/slice-series.sh")" || exit 2
GUARD="$(common_test_resolve_subject "deploy-root-guard.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/deploy-root-guard.sh" \
  "$EXT_ROOT/core/scripts/deploy-root-guard.sh")" || exit 2
LIBDIR="$(dirname "$GUARD")/lib"
common_test_declare_subject "$SS"
common_test_declare_subject "$GUARD"

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

# =====================================================================
# Phase 2: build -- private index, overlay, write-tree, commit-tree, compare-and-swap.
# =====================================================================

# snapshot_repo <repo> -- captures HEAD, the shared index's tracked content, and the unstaged
# diff over tracked files, so a post-build assertion can prove none of the three is disturbed.
# `build` deliberately creates new, not-yet-existing files (the series document it updates in
# place, a slice's pull-request body) -- that is its entire job, and naming those as a "working
# tree" violation would contradict the record's own Phase 2 task list. What "untouched" means
# here is the pre-existing TRACKED state: HEAD does not move, nothing new is staged
# (`ls-files -s` over the shared index is byte-identical), and no already-tracked file's content
# changes (`git diff` over tracked paths, unstaged, stays empty both before and after).
snapshot_repo() {
  local repo="$1"
  SNAP_HEAD="$(git -C "$repo" rev-parse HEAD)"
  SNAP_IDX="$(git -C "$repo" ls-files -s | md5sum)"
  SNAP_DIFF="$(git -C "$repo" diff)"
}

assert_untouched() {
  local repo="$1" label="$2"
  local head_after idx_after diff_after
  head_after="$(git -C "$repo" rev-parse HEAD)"
  idx_after="$(git -C "$repo" ls-files -s | md5sum)"
  diff_after="$(git -C "$repo" diff)"
  if [ "$head_after" = "$SNAP_HEAD" ] && [ "$idx_after" = "$SNAP_IDX" ] && [ "$diff_after" = "$SNAP_DIFF" ]; then
    common_test_pass "$label"
  else
    common_test_fail "$label" "HEAD before=${SNAP_HEAD} after=${head_after}; index match=$([ "$idx_after" = "$SNAP_IDX" ] && echo yes || echo no); tracked-diff before=[${SNAP_DIFF}] after=[${diff_after}]"
  fi
}

doc_field() {
  local path="$1" id="$2" field="$3"
  jq -r --arg id "$id" --arg f "$field" '.slices[] | select(.id == $id) | .[$f] // ""' "$path"
}

# -----------------------------------------------------------------------
# one-slice build (sliceB routed to not_landing so only sliceA is declared)
# -----------------------------------------------------------------------
repo="$(make_repo)"
doc="$(base_doc | jq 'del(.slices[1]) | .not_landing += ["sliceB/*"]')"
printf '%s' "$doc" >"$repo/candidate.json"
snapshot_repo "$repo"
run_ss "$repo" build candidate.json
if [ "$LAST_CODE" -eq 0 ] \
  && printf '%s' "$LAST_OUT" | grep -q '^SLICE sliceA built commit=' \
  && [ "$(doc_field "$repo/candidate.json" sliceA state)" = "built" ] \
  && [ -n "$(doc_field "$repo/candidate.json" sliceA commit)" ] \
  && [ -f "$repo/specs/.orchestration/slices/s1/sliceA.md" ]; then
  common_test_pass "a one-slice build: sliceA built, ref/body recorded, series document updated in place"
else
  common_test_fail "one-slice build" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
assert_untouched "$repo" "one-slice build leaves HEAD, the shared index, and the working tree unchanged"
rm -rf "$repo"

# -----------------------------------------------------------------------
# independent two-slice build (no depends_on edge between sliceA and sliceB)
# -----------------------------------------------------------------------
repo="$(make_repo)"
doc="$(base_doc | jq '.slices[1].depends_on = []')"
printf '%s' "$doc" >"$repo/candidate.json"
target_tip="$(git -C "$repo" rev-parse "$BRANCH_TARGET")"
snapshot_repo "$repo"
run_ss "$repo" build candidate.json
if [ "$LAST_CODE" -eq 0 ] \
  && [ "$(doc_field "$repo/candidate.json" sliceA state)" = "built" ] \
  && [ "$(doc_field "$repo/candidate.json" sliceB state)" = "built" ] \
  && [ "$(doc_field "$repo/candidate.json" sliceA base_commit)" = "$target_tip" ] \
  && [ "$(doc_field "$repo/candidate.json" sliceB base_commit)" = "$target_tip" ]; then
  common_test_pass "an independent two-slice build: both slices built on the target's tip"
else
  common_test_fail "independent two-slice build" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
assert_untouched "$repo" "independent two-slice build leaves HEAD, the shared index, and the working tree unchanged"
rm -rf "$repo"

# -----------------------------------------------------------------------
# build refuses every slice check refuses, via the same validation functions (no duplicated
# reimplementation) -- one representative refusal class is enough to pin the routing, since
# Phase 1's own cases already pin every refusal class's reason/exit code for `check` itself.
# -----------------------------------------------------------------------
repo="$(make_repo)"
doc="$(base_doc | jq '.slices[0].depends_on = ["sliceB"]')" # sliceA<->sliceB cycle
run_ss_stdin "$repo" "$doc" build
assert_refusal "build refuses a depends_on cycle exactly as check does, exit 27" 27 depends_on_cycle
rm -rf "$repo"

# -----------------------------------------------------------------------
# a dependent slice built on its one unmerged dependency's commit
# -----------------------------------------------------------------------
repo="$(make_repo)"
doc="$(base_doc)" # sliceB depends_on sliceA, both proposed
printf '%s' "$doc" >"$repo/candidate.json"
snapshot_repo "$repo"
run_ss "$repo" build candidate.json
sliceA_commit="$(doc_field "$repo/candidate.json" sliceA commit)"
sliceB_base="$(doc_field "$repo/candidate.json" sliceB base_commit)"
if [ "$LAST_CODE" -eq 0 ] \
  && [ -n "$sliceA_commit" ] \
  && [ "$sliceB_base" = "$sliceA_commit" ] \
  && [ "$(doc_field "$repo/candidate.json" sliceB state)" = "built" ] \
  && git -C "$repo" cat-file -e "${sliceA_commit}:sliceA/f1.txt" 2>/dev/null; then
  common_test_pass "a dependent slice is built on its one unmerged dependency's freshly built commit"
else
  common_test_fail "dependent slice build" "exit=${LAST_CODE} sliceA_commit=${sliceA_commit} sliceB_base=${sliceB_base} out=${LAST_OUT}"
fi
assert_untouched "$repo" "dependent two-slice build leaves HEAD, the shared index, and the working tree unchanged"
rm -rf "$repo"

# -----------------------------------------------------------------------
# a slice with two unmerged dependencies is reported waiting and not built
# -----------------------------------------------------------------------
make_repo3() {
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
  mkdir -p "$d/sliceA" "$d/sliceB" "$d/sliceC"
  echo one >"$d/sliceA/f1.txt"
  echo one >"$d/sliceB/f1.txt"
  echo one >"$d/sliceC/f1.txt"
  git -C "$d" add sliceA sliceB sliceC >/dev/null 2>&1
  git -C "$d" commit -q -m work >/dev/null 2>&1
  git -C "$d" checkout -q "$BRANCH_TARGET"
  printf '%s' "$d"
}

three_slice_doc() {
  cat <<EOF
{
  "series_id": "s1",
  "target": {"remote": "", "branch": "${BRANCH_TARGET}", "commit": ""},
  "work_ref": {"name": "${BRANCH_WORK}", "commit": ""},
  "bar": {"lines": 1500, "files": 30, "source": "default"},
  "not_landing": [],
  "slices": [
    {"id": "sliceA", "title": "A", "paths": ["sliceA/*"], "depends_on": [], "over_bar_reason": "", "state": "proposed"},
    {"id": "sliceB", "title": "B", "paths": ["sliceB/*"], "depends_on": [], "over_bar_reason": "", "state": "proposed"},
    {"id": "sliceC", "title": "C", "paths": ["sliceC/*"], "depends_on": ["sliceA", "sliceB"], "over_bar_reason": "", "state": "proposed"}
  ]
}
EOF
}

repo="$(make_repo3)"
doc="$(three_slice_doc)"
printf '%s' "$doc" >"$repo/candidate.json"
snapshot_repo "$repo"
run_ss "$repo" build candidate.json
if [ "$LAST_CODE" -eq 0 ] \
  && printf '%s' "$LAST_OUT" | grep -q '^SLICE sliceC waiting unmerged_depends_on=sliceA,sliceB$' \
  && [ "$(doc_field "$repo/candidate.json" sliceC state)" = "proposed" ] \
  && [ -z "$(doc_field "$repo/candidate.json" sliceC commit)" ] \
  && [ "$(doc_field "$repo/candidate.json" sliceA state)" = "built" ] \
  && [ "$(doc_field "$repo/candidate.json" sliceB state)" = "built" ]; then
  common_test_pass "a slice with two unmerged dependencies is reported waiting and not built"
else
  common_test_fail "two-unmerged-dependency waiting case" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
assert_untouched "$repo" "the waiting-slice build leaves HEAD, the shared index, and the working tree unchanged"
rm -rf "$repo"

# -----------------------------------------------------------------------
# a path the work ref deletes
# -----------------------------------------------------------------------
make_repo_delete() {
  local d
  d="$(mktemp -d -p "$WORKDIR")"
  git init -q -b "$BRANCH_TARGET" "$d"
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test Suite"
  install_scripts "$d"
  mkdir -p "$d/sliceA"
  echo one >"$d/sliceA/f1.txt"
  echo two >"$d/sliceA/f2.txt"
  echo base >"$d/README.md"
  git -C "$d" add README.md sliceA >/dev/null 2>&1
  git -C "$d" commit -q -m base >/dev/null 2>&1
  git -C "$d" branch "$BRANCH_WORK"
  git -C "$d" checkout -q "$BRANCH_WORK"
  git -C "$d" rm -q sliceA/f1.txt >/dev/null 2>&1
  echo changed >"$d/sliceA/f2.txt"
  git -C "$d" add sliceA/f2.txt >/dev/null 2>&1
  git -C "$d" commit -q -m work >/dev/null 2>&1
  git -C "$d" checkout -q "$BRANCH_TARGET"
  printf '%s' "$d"
}

one_slice_doc() {
  cat <<EOF
{
  "series_id": "s1",
  "target": {"remote": "", "branch": "${BRANCH_TARGET}", "commit": ""},
  "work_ref": {"name": "${BRANCH_WORK}", "commit": ""},
  "bar": {"lines": 1500, "files": 30, "source": "default"},
  "not_landing": [],
  "slices": [
    {"id": "sliceA", "title": "A", "paths": ["sliceA/*"], "depends_on": [], "over_bar_reason": "", "state": "proposed"}
  ]
}
EOF
}

repo="$(make_repo_delete)"
doc="$(one_slice_doc)"
printf '%s' "$doc" >"$repo/candidate.json"
snapshot_repo "$repo"
run_ss "$repo" build candidate.json
built_commit="$(doc_field "$repo/candidate.json" sliceA commit)"
if [ "$LAST_CODE" -eq 0 ] && [ -n "$built_commit" ] \
  && ! git -C "$repo" cat-file -e "${built_commit}:sliceA/f1.txt" 2>/dev/null \
  && git -C "$repo" cat-file -e "${built_commit}:sliceA/f2.txt" 2>/dev/null \
  && git -C "$repo" cat-file -e "${built_commit}:README.md" 2>/dev/null; then
  common_test_pass "a path the work ref deletes is force-removed from the slice's overlaid tree"
else
  common_test_fail "deleted-path overlay case" "exit=${LAST_CODE} commit=${built_commit} out=${LAST_OUT}"
fi
assert_untouched "$repo" "the deleted-path build leaves HEAD, the shared index, and the working tree unchanged"
rm -rf "$repo"

# -----------------------------------------------------------------------
# compare-and-swap refusal when the ref moved between read and write
# -----------------------------------------------------------------------
repo="$(make_repo)"
doc="$(base_doc | jq 'del(.slices[1]) | .not_landing += ["sliceB/*"]')"
printf '%s' "$doc" >"$repo/candidate.json"
run_ss "$repo" build candidate.json # first build: creates the ref
if [ "$LAST_CODE" -ne 0 ]; then
  common_test_fail "compare-and-swap fixture setup" "first build did not succeed: exit=${LAST_CODE} out=${LAST_OUT}"
  rm -rf "$repo"
else
  race_hook="$(mktemp -p "$WORKDIR")"
  cat >"$race_hook" <<'HOOK'
#!/usr/bin/env bash
# Test-only race simulator: moves the named ref to an unrelated commit right before the
# script's own compare-and-swap attempt, so the swap's captured "old" value is stale.
ref="$1"
git update-ref "$ref" "$(git rev-parse HEAD)"
HOOK
  chmod +x "$race_hook"
  snapshot_repo "$repo"
  LAST_OUT="$(cd "$repo" && SS_TEST_PRE_SWAP_HOOK="$race_hook" bash .claude/scripts/slice-series.sh build candidate.json 2>&1)"
  LAST_CODE=$?
  assert_refusal "a compare-and-swap refusal when the ref moved concurrently, exit 30" 30 ref_compare_and_swap_conflict
  assert_untouched "$repo" "a compare-and-swap refusal leaves HEAD, the shared index, and the working tree unchanged"
  rm -f "$race_hook"
  rm -rf "$repo"
fi

# =====================================================================
# Phase 3: status, the union check, and the repo-agnosticism assertion.
# =====================================================================

# REMOTE_NAME is neither a default remote name ("origin") nor a default branch name, per the
# same fixture-naming convention BRANCH_TARGET/BRANCH_WORK already follow.
REMOTE_NAME="forgehub"

status_field() {
  local out="$1" id="$2" field="$3"
  printf '%s\n' "$out" | grep "^STATUS ${id} " | grep -oE "${field}=[^ ]*" | cut -d= -f2-
}

doc_with_remote() {
  base_doc | jq --arg r "$REMOTE_NAME" '.target.remote = $r'
}

# -----------------------------------------------------------------------
# a built-but-unpushed slice
# -----------------------------------------------------------------------
repo="$(make_repo)"
doc="$(doc_with_remote | jq 'del(.slices[1]) | .not_landing += ["sliceB/*"]')"
printf '%s' "$doc" >"$repo/candidate.json"
run_ss "$repo" build candidate.json
run_ss "$repo" status candidate.json
if [ "$LAST_CODE" -eq 0 ] \
  && [ "$(status_field "$LAST_OUT" sliceA local_ref)" = "exists" ] \
  && [ "$(status_field "$LAST_OUT" sliceA local_matches_recorded)" = "yes" ] \
  && [ "$(status_field "$LAST_OUT" sliceA remote_ref)" = "absent" ] \
  && [ "$(status_field "$LAST_OUT" sliceA remote_matches_recorded)" = "n/a" ] \
  && [ "$(status_field "$LAST_OUT" sliceA merged)" = "no" ]; then
  common_test_pass "status on a built-but-unpushed slice reports local=exists, remote=absent"
else
  common_test_fail "built-but-unpushed status case" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# -----------------------------------------------------------------------
# a pushed slice whose remote ref matches
# -----------------------------------------------------------------------
repo="$(make_repo)"
doc="$(doc_with_remote | jq 'del(.slices[1]) | .not_landing += ["sliceB/*"]')"
printf '%s' "$doc" >"$repo/candidate.json"
run_ss "$repo" build candidate.json
built_commit="$(doc_field "$repo/candidate.json" sliceA commit)"
# Simulate a completed push's resulting remote-tracking ref directly (never via `git push`,
# which this suite never invokes -- the operator's push is out of scope for this script).
git -C "$repo" update-ref "refs/remotes/${REMOTE_NAME}/slice/s1/sliceA" "$built_commit"
run_ss "$repo" status candidate.json
if [ "$LAST_CODE" -eq 0 ] \
  && [ "$(status_field "$LAST_OUT" sliceA remote_ref)" = "exists" ] \
  && [ "$(status_field "$LAST_OUT" sliceA remote_matches_recorded)" = "yes" ]; then
  common_test_pass "status on a pushed slice whose remote ref matches the recorded commit"
else
  common_test_fail "pushed-and-matching status case" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# -----------------------------------------------------------------------
# a pushed slice whose remote ref diverges from the recorded commit
# -----------------------------------------------------------------------
repo="$(make_repo)"
doc="$(doc_with_remote | jq 'del(.slices[1]) | .not_landing += ["sliceB/*"]')"
printf '%s' "$doc" >"$repo/candidate.json"
run_ss "$repo" build candidate.json
target_tip="$(git -C "$repo" rev-parse "$BRANCH_TARGET")"
# An unrelated commit stands in for a remote ref that has diverged from what this document
# recorded (e.g. someone else pushed over it).
git -C "$repo" update-ref "refs/remotes/${REMOTE_NAME}/slice/s1/sliceA" "$target_tip"
run_ss "$repo" status candidate.json
if [ "$LAST_CODE" -eq 0 ] \
  && [ "$(status_field "$LAST_OUT" sliceA remote_ref)" = "exists" ] \
  && [ "$(status_field "$LAST_OUT" sliceA remote_matches_recorded)" = "no" ]; then
  common_test_pass "status on a pushed slice whose remote ref diverges from the recorded commit"
else
  common_test_fail "pushed-and-diverging status case" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# -----------------------------------------------------------------------
# a slice merged by squash (recognised by content, never by commit ancestry)
# -----------------------------------------------------------------------
repo="$(make_repo)"
doc="$(doc_with_remote | jq 'del(.slices[1]) | .not_landing += ["sliceB/*"]')"
printf '%s' "$doc" >"$repo/candidate.json"
run_ss "$repo" build candidate.json
# Land sliceA's own content directly on the target branch with a fresh, unrelated commit --
# a squash merge has no shared history with the slice's own commit, only identical content.
( cd "$repo" && git checkout -q "$BRANCH_TARGET" \
  && mkdir -p sliceA && echo one >sliceA/f1.txt && echo one >sliceA/f2.txt \
  && git add sliceA/f1.txt sliceA/f2.txt >/dev/null 2>&1 \
  && git commit -q -m "squash merge sliceA" >/dev/null 2>&1 )
run_ss "$repo" status candidate.json
if [ "$LAST_CODE" -eq 0 ] && [ "$(status_field "$LAST_OUT" sliceA merged)" = "yes" ]; then
  common_test_pass "status recognises a squash-merged slice by content, with no shared commit history"
else
  common_test_fail "squash-merge content recognition" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# -----------------------------------------------------------------------
# an unmerged slice whose base has moved: status names a rebuild as due
# -----------------------------------------------------------------------
repo="$(make_repo)"
doc="$(doc_with_remote | jq 'del(.slices[1]) | .not_landing += ["sliceB/*"]')"
printf '%s' "$doc" >"$repo/candidate.json"
run_ss "$repo" build candidate.json
run_ss "$repo" status candidate.json
rebuild_due_before="$(status_field "$LAST_OUT" sliceA rebuild_due)"
( cd "$repo" && git checkout -q "$BRANCH_TARGET" \
  && echo unrelated >unrelated.txt && git add unrelated.txt >/dev/null 2>&1 \
  && git commit -q -m "unrelated target progress" >/dev/null 2>&1 )
run_ss "$repo" status candidate.json
if [ "$rebuild_due_before" = "no" ] \
  && [ "$LAST_CODE" -eq 0 ] \
  && [ "$(status_field "$LAST_OUT" sliceA rebuild_due)" = "yes" ] \
  && [ "$(status_field "$LAST_OUT" sliceA merged)" = "no" ]; then
  common_test_pass "status names a rebuild due for an unmerged slice whose base has moved, writing and merging nothing"
else
  common_test_fail "rebuild-due-on-moved-base case" "before=${rebuild_due_before} exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# =====================================================================
# Static assertion: no literal default remote name and no literal default branch name.
# =====================================================================
default_name_hits="$(grep -nE '\borigin\b|\bmain\b|\bmaster\b' "$SS" || true)"
if [ -z "$default_name_hits" ]; then
  common_test_pass "static check: slice-series.sh names no default remote or branch name"
else
  common_test_fail "static check: found a literal default remote/branch name" "$default_name_hits"
fi

# =====================================================================
# Static assertion: no source of, or invocation of, review-stack-prepare.sh or any script
# outside lib/ and deploy-root-guard.sh.
# =====================================================================
dep_hits="$(grep -nE 'review-stack-prepare' "$SS" | grep -v '^[0-9]*:#' || true)"
if [ -z "$dep_hits" ]; then
  common_test_pass "static check: slice-series.sh neither sources nor invokes review-stack-prepare.sh"
else
  common_test_fail "static check: found a review-stack-prepare.sh reference" "$dep_hits"
fi

other_source_hits="$(grep -nE '^\s*(source|\.)\s+"?\$\{?SCRIPT_DIR\}?/' "$SS" | grep -v 'lib/common\.sh' | grep -v 'deploy-root-guard\.sh' || true)"
if [ -z "$other_source_hits" ]; then
  common_test_pass "static check: slice-series.sh sources nothing outside lib/ and deploy-root-guard.sh"
else
  common_test_fail "static check: found an unexpected source/invocation" "$other_source_hits"
fi

# =====================================================================
# The union check: the target's tree overlaid with every built slice equals the work ref's
# tree on every assigned path. Compared over resolved tree content, never a commit range.
# =====================================================================
assert_union_property() {
  local repo="$1" doc_path="$2" label="$3"
  local work_ref_commit
  work_ref_commit="$(git -C "$repo" rev-parse "$BRANCH_WORK")"
  local -a ids
  mapfile -d '' -t ids < <(jq -j '.slices[].id | . + "\u0000"' "$doc_path")
  local mismatch="" id
  for id in "${ids[@]}"; do
    [ -n "$id" ] || continue
    local commit
    commit="$(jq -r --arg id "$id" '.slices[] | select(.id == $id) | .commit // ""' "$doc_path")"
    [ -n "$commit" ] || continue
    local -a globs pathspecs
    mapfile -d '' -t globs < <(jq -j --arg id "$id" '
      .slices[] | select(.id == $id) | (.paths // [])[] | . + "\u0000"' "$doc_path")
    pathspecs=()
    local g
    for g in "${globs[@]}"; do
      [ -n "$g" ] || continue
      pathspecs+=(":(glob)${g}")
    done
    [ "${#pathspecs[@]}" -gt 0 ] || continue
    local diff_out
    diff_out="$(git -C "$repo" diff --name-only "$commit" "$work_ref_commit" -- "${pathspecs[@]}" 2>/dev/null)"
    if [ -n "$diff_out" ]; then
      mismatch="${mismatch}slice ${id}: ${diff_out}; "
    fi
  done
  if [ -z "$mismatch" ]; then
    common_test_pass "$label"
  else
    common_test_fail "$label" "$mismatch"
  fi
}

repo="$(make_repo)"
doc="$(base_doc | jq '.slices[1].depends_on = []')" # sliceA and sliceB, independent, both assigned
printf '%s' "$doc" >"$repo/candidate.json"
run_ss "$repo" build candidate.json
assert_union_property "$repo" "$repo/candidate.json" "the union check: target overlaid with every built slice equals the work ref on every assigned path"
rm -rf "$repo"

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
