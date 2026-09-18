#!/usr/bin/env bash
# test-init-specs.sh - Regression suite for scripts/init-specs.sh, the idempotent consumer-repo
# specs/ bootstrap (state trio + managed specs/.gitignore + untrack sweep).
#
# Pins every acceptance criterion from this suite's originating task: a fresh scratch repo
# bootstraps cleanly, a second run is a true no-op, managed-block content outside the sentinels
# survives a refresh, already-tracked runtime-class files are untracked (never deleted) and a
# following scoped commit plus lock release leaves the tree clean, durable provenance
# (.orchestrator-handoff.json / .return-meta.json) is never touched, and
# check-runtime-file-tracking.sh passes on the bootstrapped repo using ONLY specs/.gitignore
# coverage (no root .gitignore at all) while still catching an already-tracked ephemeral file
# regardless of ignore coverage (the item (h) regression pin).
#
# Structural model: context/standards/shell-script-testing.md (PASSED/FAILED counters,
# pass()/fail()/info() helpers, mktemp -d scratch repo(s), never resolves against the live tree
# -- every case below runs against a disposable scratch repo with its own copied `.claude/scripts`
# tree, never this repository's own specs/ tree).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# script under test, or a dependency it needs, not found in either tree root).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

# Deploy-tree-first / source-store-fallback resolution, matching test-runtime-file-tracking.sh's
# own TREE_ROOTS pattern -- both trees keep the same relative layout (scripts/, scripts/lib/,
# scripts/tests/), so whichever root has init-specs.sh present is used for everything.
TREE_ROOTS=(
  "$REPO_ROOT/.claude"
  "$REPO_ROOT/agent-system/extensions/core"
)
SCRIPTS_SRC=""
for root in "${TREE_ROOTS[@]}"; do
  if [[ -f "$root/scripts/init-specs.sh" && -f "$root/scripts/check-runtime-file-tracking.sh" ]]; then
    SCRIPTS_SRC="$root/scripts"
    break
  fi
done
if [[ -z "$SCRIPTS_SRC" ]]; then
  echo "ERROR: no tree root has scripts/init-specs.sh AND scripts/check-runtime-file-tracking.sh present together:" >&2
  for root in "${TREE_ROOTS[@]}"; do
    echo "  $root/scripts" >&2
  done
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

git_commit() {
  local repo="$1" msg="$2"
  git -C "$repo" -c user.email="test@test.local" -c user.name="test-init-specs" \
    commit -q -m "$msg"
}

# build_fixture_repo <name>
# Creates $WORKDIR/<name>, a fresh git repo with a full .claude/scripts copy (init-specs.sh's own
# dependency chain -- generate-todo.sh -> generate-task-order.sh -> lib/status-vocabulary.sh,
# deploy-root-guard.sh, lib/runtime-file-patterns.sh -- needs the real tree, not a hand-picked
# subset). Prints the repo's absolute path on stdout.
build_fixture_repo() {
  local name="$1"
  local repo="$WORKDIR/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q
  mkdir -p "$repo/.claude"
  cp -r "$SCRIPTS_SRC" "$repo/.claude/scripts"
  echo "$repo"
}

# =====================================================================
# Case 1: fresh bootstrap -- scratch repo with no specs/ at all.
# =====================================================================
REPO1="$(build_fixture_repo repo1)"
info "Case 1: fresh bootstrap in a scratch repo with no specs/"
case1_output="$(cd "$REPO1" && bash .claude/scripts/init-specs.sh 2>&1)"
case1_exit=$?
if [[ "$case1_exit" -eq 0 ]]; then
  pass "Case 1: init-specs.sh exits 0"
else
  fail "Case 1: expected exit 0, got $case1_exit:"
  echo "$case1_output" | sed 's/^/    /'
fi
if [[ -f "$REPO1/specs/state.json" ]] && jq -e '.next_project_number == 1 and (.active_projects | length) == 0' "$REPO1/specs/state.json" > /dev/null 2>&1; then
  pass "Case 1: specs/state.json created with next_project_number=1, empty active_projects"
else
  fail "Case 1: specs/state.json missing or wrong shape"
fi
if [[ -f "$REPO1/specs/archive/state.json" ]] && jq -e 'has("archived_projects") and has("completed_projects")' "$REPO1/specs/archive/state.json" > /dev/null 2>&1; then
  pass "Case 1: specs/archive/state.json created with archived_projects/completed_projects"
else
  fail "Case 1: specs/archive/state.json missing or wrong shape"
fi
if [[ -f "$REPO1/specs/TODO.md" ]]; then
  pass "Case 1: specs/TODO.md created"
else
  fail "Case 1: specs/TODO.md missing"
fi
if [[ -f "$REPO1/specs/.gitignore" ]] && grep -qF '# BEGIN managed block: runtime-file-patterns.sh' "$REPO1/specs/.gitignore"; then
  pass "Case 1: specs/.gitignore created with managed block sentinels"
else
  fail "Case 1: specs/.gitignore missing or lacks managed-block sentinels"
fi
if [[ -f "$REPO1/.claude/scripts/validate-state.sh" ]]; then
  validate_output="$(cd "$REPO1" && bash .claude/scripts/validate-state.sh specs/state.json 2>&1)"
  if echo "$validate_output" | grep -q 'STATE VALIDATION PASSED'; then
    pass "Case 1: specs/state.json passes validate-state.sh (schema-valid)"
  else
    fail "Case 1: validate-state.sh did not report STATE VALIDATION PASSED:"
    echo "$validate_output" | sed 's/^/    /'
  fi
fi

# =====================================================================
# Case 2: idempotence -- second run makes zero filesystem/staged changes.
# =====================================================================
info "Case 2: idempotence -- second run against the already-bootstrapped repo"
before_sum="$(cd "$REPO1" && find specs -type f -exec md5sum {} + | sort)"
case2_output="$(cd "$REPO1" && bash .claude/scripts/init-specs.sh 2>&1)"
case2_exit=$?
after_sum="$(cd "$REPO1" && find specs -type f -exec md5sum {} + | sort)"
if [[ "$case2_exit" -eq 0 ]]; then
  pass "Case 2: second run exits 0"
else
  fail "Case 2: second run expected exit 0, got $case2_exit"
fi
if [[ "$before_sum" == "$after_sum" ]]; then
  pass "Case 2: second run made zero filesystem content changes"
else
  fail "Case 2: second run changed file content (not idempotent)"
fi
if echo "$case2_output" | grep -q 'SKIP specs/state.json' && echo "$case2_output" | grep -q 'SKIP specs/.gitignore managed block already current'; then
  pass "Case 2: second run reports SKIP for state.json and the gitignore managed block"
else
  fail "Case 2: second run did not report the expected SKIP lines:"
  echo "$case2_output" | sed 's/^/    /'
fi

# =====================================================================
# Case 3: managed-block preservation -- a hand-added line outside the sentinels survives a
# refresh, and the sentinel-delimited region itself is regenerated byte-identically.
# =====================================================================
info "Case 3: managed-block preservation across a refresh"
echo "# my-local-custom-rule.txt" >> "$REPO1/specs/.gitignore"
echo "my-local-custom-rule.txt" >> "$REPO1/specs/.gitignore"
# Perturb the managed region so a real refresh is exercised (not another no-op).
sed -i '/^\/tmp\/$/d' "$REPO1/specs/.gitignore"
case3_output="$(cd "$REPO1" && bash .claude/scripts/init-specs.sh 2>&1)"
if echo "$case3_output" | grep -q 'REFRESHED specs/.gitignore managed block'; then
  pass "Case 3: a perturbed managed region is detected and refreshed"
else
  fail "Case 3: expected a REFRESHED line, got:"
  echo "$case3_output" | sed 's/^/    /'
fi
if grep -qF 'my-local-custom-rule.txt' "$REPO1/specs/.gitignore"; then
  pass "Case 3: hand-added line outside the sentinels survives the refresh"
else
  fail "Case 3: hand-added line outside the sentinels was lost"
fi
if grep -qF '/tmp/' "$REPO1/specs/.gitignore"; then
  pass "Case 3: the deliberately-removed /tmp/ line is restored by the refresh"
else
  fail "Case 3: /tmp/ line was not restored -- managed region not regenerated correctly"
fi

# =====================================================================
# Case 4 (ADDED ACCEPTANCE): untrack sweep on already-tracked runtime files, disk-preserved,
# clean tree after a following scoped commit.
# =====================================================================
REPO4="$(build_fixture_repo repo4)"
(cd "$REPO4" && bash .claude/scripts/init-specs.sh > /dev/null 2>&1)
(cd "$REPO4" && git add specs/ && git_commit "$REPO4" "bootstrap")

mkdir -p "$REPO4/specs/.commit-lock" "$REPO4/specs/001_x/.lock" "$REPO4/specs/001_x/.dispatch"
{ echo "pid=1"; echo "claimed_at=1"; echo "stale_sec=30"; } > "$REPO4/specs/.commit-lock/owner"
echo "lock" > "$REPO4/specs/.events.lock"
echo '{"session_id":"x"}' > "$REPO4/specs/001_x/.lock/holder.json"
echo "d1" > "$REPO4/specs/001_x/.dispatch/1.md"
echo "guard" > "$REPO4/specs/001_x/.orchestrator-loop-guard"
echo '{}' > "$REPO4/specs/.orchestrator-multi-state-sess_0_x.json"
mkdir -p "$REPO4/specs/001_x"
echo '{}' > "$REPO4/specs/001_x/.orchestrator-handoff.json"
echo '{}' > "$REPO4/specs/001_x/.return-meta.json"
(cd "$REPO4" && git add -f specs/.commit-lock specs/.events.lock specs/001_x/.lock \
  specs/001_x/.dispatch specs/001_x/.orchestrator-loop-guard \
  specs/.orchestrator-multi-state-sess_0_x.json specs/001_x/.orchestrator-handoff.json \
  specs/001_x/.return-meta.json)
git_commit "$REPO4" "simulate pre-policy committed runtime files"

info "Case 4: untrack sweep against already-tracked runtime-class files"
if ! (cd "$REPO4" && bash .claude/scripts/init-specs.sh) > "$WORKDIR/case4.out" 2>&1; then
  fail "Case 4: init-specs.sh exited nonzero:"
  sed 's/^/    /' "$WORKDIR/case4.out"
fi
staged="$(cd "$REPO4" && git diff --cached --name-status)"
expected_untracked=(
  "specs/.commit-lock/owner"
  "specs/.events.lock"
  "specs/001_x/.lock/holder.json"
  "specs/001_x/.dispatch/1.md"
  "specs/001_x/.orchestrator-loop-guard"
  "specs/.orchestrator-multi-state-sess_0_x.json"
)
all_staged=true
for p in "${expected_untracked[@]}"; do
  if ! echo "$staged" | grep -qE "^D\s+${p}$"; then
    all_staged=false
    fail "Case 4: expected a staged D for $p, not found in:"
    echo "$staged" | sed 's/^/    /'
  fi
done
[[ "$all_staged" == "true" ]] && pass "Case 4: all six expected runtime-class paths staged as D"

all_on_disk=true
for p in "${expected_untracked[@]}" "specs/001_x/.orchestrator-handoff.json" "specs/001_x/.return-meta.json"; do
  [[ -e "$REPO4/$p" ]] || { all_on_disk=false; fail "Case 4: $p missing from disk after untrack sweep"; }
done
[[ "$all_on_disk" == "true" ]] && pass "Case 4: every untracked path (and both durable-provenance files) still exists on disk"

if echo "$staged" | grep -qE '\.orchestrator-handoff\.json$|\.return-meta\.json$'; then
  fail "Case 4: the staged diff includes a durable-provenance path -- must never be untracked:"
  echo "$staged" | sed 's/^/    /'
else
  pass "Case 4: the staged diff does not include either durable-provenance path"
fi

git_commit "$REPO4" "untrack ephemeral runtime files"
tree_status="$(cd "$REPO4" && git status --porcelain -- specs/)"
if [[ -z "$tree_status" ]]; then
  pass "Case 4: git status --porcelain -- specs/ is empty after the untrack commit"
else
  fail "Case 4: git status --porcelain -- specs/ is NOT empty after the untrack commit:"
  echo "$tree_status" | sed 's/^/    /'
fi

info "Case 4: second run of the sweep is a true no-op"
case4b_output="$(cd "$REPO4" && bash .claude/scripts/init-specs.sh 2>&1)"
case4b_staged="$(cd "$REPO4" && git diff --cached --name-status)"
if [[ -z "$case4b_staged" ]] && echo "$case4b_output" | grep -q 'SKIP untrack sweep: no already-tracked runtime-class file found'; then
  pass "Case 4: second sweep stages nothing and reports the no-op SKIP line"
else
  fail "Case 4: second sweep was not a clean no-op:"
  echo "$case4b_output" | sed 's/^/    /'
fi

# =====================================================================
# Case 5: provenance preserved -- .orchestrator-handoff.json and .return-meta.json remain
# tracked (never in the untrack sweep's staged output) after the sweep.
# =====================================================================
info "Case 5: durable provenance stays tracked after the sweep"
tracked_after="$(cd "$REPO4" && git ls-files -- specs/)"
if echo "$tracked_after" | grep -qF 'specs/001_x/.orchestrator-handoff.json' \
  && echo "$tracked_after" | grep -qF 'specs/001_x/.return-meta.json'; then
  pass "Case 5: .orchestrator-handoff.json and .return-meta.json are still tracked"
else
  fail "Case 5: durable provenance is missing from git ls-files after the sweep:"
  echo "$tracked_after" | sed 's/^/    /'
fi
if (cd "$REPO4" && git check-ignore -q specs/001_x/.orchestrator-handoff.json); then
  fail "Case 5: .orchestrator-handoff.json is ignored -- must never be"
else
  pass "Case 5: .orchestrator-handoff.json is not ignored"
fi
if (cd "$REPO4" && git check-ignore -q specs/001_x/.return-meta.json); then
  fail "Case 5: .return-meta.json is ignored -- must never be"
else
  pass "Case 5: .return-meta.json is not ignored"
fi

# =====================================================================
# Case 6: check-runtime-file-tracking.sh exits 0 on the bootstrapped repo using ONLY
# specs/.gitignore coverage (no root .gitignore at all) -- proves item (f) without a logic
# change (Check A's `git check-ignore -q` already honors specs/.gitignore at any depth).
# =====================================================================
REPO6="$(build_fixture_repo repo6)"
(cd "$REPO6" && bash .claude/scripts/init-specs.sh > /dev/null 2>&1)
if [[ -f "$REPO6/.gitignore" ]]; then
  fail "Case 6: fixture repo unexpectedly has a root .gitignore -- test setup invalid"
else
  info "Case 6: confirmed no root .gitignore exists in the fixture repo"
fi
(cd "$REPO6" && git add specs/ && git_commit "$REPO6" "bootstrap")
case6_output="$(cd "$REPO6" && bash .claude/scripts/check-runtime-file-tracking.sh 2>&1)"
case6_exit=$?
if [[ "$case6_exit" -eq 0 ]] && echo "$case6_output" | grep -q 'PASS'; then
  pass "Case 6: check-runtime-file-tracking.sh exits 0 / PASS using only specs/.gitignore"
else
  fail "Case 6: expected exit 0 / PASS, got exit $case6_exit:"
  echo "$case6_output" | sed 's/^/    /'
fi

# =====================================================================
# Case 7 (item (h) regression pin): specs/.gitignore covers the class AND a tracked ephemeral
# file is present -- check-runtime-file-tracking.sh still exits nonzero via Check B. This
# verifies pre-existing behavior (shipped before this task), not new logic.
# =====================================================================
REPO7="$(build_fixture_repo repo7)"
(cd "$REPO7" && bash .claude/scripts/init-specs.sh > /dev/null 2>&1)
(cd "$REPO7" && git add specs/ && git_commit "$REPO7" "bootstrap")
echo "lock" > "$REPO7/specs/.errors.lock"
(cd "$REPO7" && git add -f specs/.errors.lock && git_commit "$REPO7" "force-track an ephemeral file despite full ignore coverage")
case7_output="$(cd "$REPO7" && bash .claude/scripts/check-runtime-file-tracking.sh 2>&1)"
case7_exit=$?
if [[ "$case7_exit" -eq 1 ]] && echo "$case7_output" | grep -q 'Check B FAILED'; then
  pass "Case 7: Check B still FAILs on a tracked ephemeral file despite full specs/.gitignore coverage (item (h) regression pin)"
else
  fail "Case 7: expected exit 1 with 'Check B FAILED', got exit $case7_exit:"
  echo "$case7_output" | sed 's/^/    /'
fi

# =====================================================================
# Case 8: specs/tmp/claude-tts-notify.log is ignored in the bootstrapped repo.
# =====================================================================
info "Case 8: specs/tmp/ ignore coverage in the bootstrapped repo"
if (cd "$REPO1" && git check-ignore -q specs/tmp/claude-tts-notify.log); then
  pass "Case 8: specs/tmp/claude-tts-notify.log is ignored"
else
  fail "Case 8: specs/tmp/claude-tts-notify.log is NOT ignored"
fi

# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [[ "$FAILED" -eq 0 ]]; then
  exit 0
else
  exit 1
fi
