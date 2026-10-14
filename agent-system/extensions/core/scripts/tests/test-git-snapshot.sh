#!/usr/bin/env bash
# test-git-snapshot.sh - Fixture-driven regression suite proving git-snapshot.sh's default
# (reverting) mode does not sweep away dirty tracked paths OUTSIDE the snapshotted job's
# declared file_scope.
#
# Root cause under test (see reports/01_git-snapshot-scope-guard.md, sibling task directory):
# default mode runs `git stash push -u`, which reverts the ENTIRE dirty working tree, including
# tracked modifications that have nothing to do with the work being snapshotted. This suite
# reproduces the exact incident tree shape -- a dirty tracked file inside the declared file_scope
# alongside a dirty tracked file outside it -- and asserts the out-of-scope file survives a
# default-mode snapshot untouched, with its path named on stderr. It is EXPECTED to FAIL against
# the unfixed script (that demonstrated RED is this phase's own deliverable) and to PASS once
# the guard lands.
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md and the
# structure of the sibling suite test-guard-destructive-git.sh: SCRIPT_DIR-relative resolution of
# the script under test, pass()/fail()/info() helpers, PASSED/FAILED counters, mktemp -d workdirs
# with trap EXIT cleanup, exit 0 all-pass / exit 1 any-fail. Every fixture repo is built fresh and
# genuinely dirty; a fixture self-check runs first so a broken fixture fails loudly rather than
# letting later cases pass vacuously.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This single relative path resolves to agent-system/extensions/core/scripts/ in source-store
# mode and to .claude/scripts/ in deployed mode, with no branching.
SNAPSHOT="$SCRIPT_DIR/../git-snapshot.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$SNAPSHOT" ]; then
  echo "ERROR: expected git-snapshot.sh at $SNAPSHOT" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required (git-snapshot.sh's file_scope resolution needs it) and is not on PATH" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# Fixture directory number. An arbitrary, sacrificial number used only inside a throwaway
# mktemp -d fixture repo -- never a citation of this repository's own specs/ directory.
FIXTURE_NUM=900
FIXTURE_DIR_NAME="${FIXTURE_NUM}_fixture"

# make_scoped_repo <dirty-outside:yes|no>
# Creates a fresh git repo under a new mktemp -d directory with:
#   specs/${FIXTURE_DIR_NAME}/  - the fixture's own task directory
#   specs/state.json            - declares the fixture number's file_scope as ["in-scope/"]
#   in-scope/tracked.txt        - inside the declared scope
#   outside/unrelated.txt       - outside the declared scope
# Both tracked files are committed, then in-scope/tracked.txt is always dirtied. When
# $1 = "yes", outside/unrelated.txt is ALSO dirtied (the incident tree shape); when "no", it is
# left clean (the negative-control, all-in-scope tree shape). Echoes the repo path.
make_scoped_repo() {
  local dirty_outside="$1"
  local d
  d="$(mktemp -d -p "$WORKDIR")"
  git -C "$d" init -q
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test Suite"

  mkdir -p "$d/specs/${FIXTURE_DIR_NAME}" "$d/in-scope" "$d/outside"
  echo "keep" > "$d/specs/${FIXTURE_DIR_NAME}/.gitkeep"
  echo "in scope, line one" > "$d/in-scope/tracked.txt"
  echo "outside, line one" > "$d/outside/unrelated.txt"
  cat > "$d/specs/state.json" << STATEEOF
{
  "version": "1.0",
  "next_project_number": $((FIXTURE_NUM + 1)),
  "active_projects": [
    {
      "project_number": ${FIXTURE_NUM},
      "project_name": "fixture",
      "status": "implementing",
      "task_type": "meta",
      "file_scope": ["in-scope/"]
    }
  ]
}
STATEEOF

  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" commit -q -m "initial fixture commit"

  echo "in scope, line two" >> "$d/in-scope/tracked.txt"
  if [ "$dirty_outside" = "yes" ]; then
    echo "outside, line two" >> "$d/outside/unrelated.txt"
  fi

  echo "$d"
}

# run_snapshot <repo> [args...]
# Runs git-snapshot.sh as a subprocess with cwd set to <repo>, capturing combined stdout+stderr
# into LAST_OUTPUT and the exit code into LAST_CODE (globals, not a subshell return -- the
# combined text is needed by callers, not just a pass/fail boolean).
LAST_OUTPUT=""
LAST_CODE=0
run_snapshot() {
  local repo="$1"
  shift
  LAST_OUTPUT="$(cd "$repo" && bash "$SNAPSHOT" "$@" 2>&1)"
  LAST_CODE=$?
}

# =====================================================================
# Fixture self-check (MUST run first): a broken fixture must fail loudly rather than let
# every later case pass or fail for the wrong reason.
# =====================================================================
fixture_repo="$(make_scoped_repo "yes")"
fixture_status="$(git -C "$fixture_repo" status --porcelain)"
in_scope_dirty="$(git -C "$fixture_repo" status --porcelain -- in-scope/tracked.txt)"
outside_dirty="$(git -C "$fixture_repo" status --porcelain -- outside/unrelated.txt)"
rm -rf "$fixture_repo"
if [ -n "$fixture_status" ] && [ -n "$in_scope_dirty" ] && [ -n "$outside_dirty" ]; then
  pass "fixture self-check: make_scoped_repo produces a genuinely dirty tree, both in- and out-of-scope"
else
  fail "fixture self-check: make_scoped_repo did not produce the expected dirty tree (status='$fixture_status') -- every later case would pass or fail for the wrong reason"
fi

# =====================================================================
# Core case: default mode must NOT sweep away the out-of-scope tracked file.
# EXPECTED TO FAIL against the unfixed script -- that is this phase's own deliverable.
# =====================================================================
core_repo="$(make_scoped_repo "yes")"
run_snapshot "$core_repo" "$FIXTURE_NUM"
core_code="$LAST_CODE"
core_output="$LAST_OUTPUT"
core_outside_status="$(git -C "$core_repo" status --porcelain -- outside/unrelated.txt)"
rm -rf "$core_repo"

if [ "$core_code" -ne 0 ] \
   && [ -n "$core_outside_status" ] \
   && printf '%s' "$core_output" | grep -q "outside/unrelated.txt"; then
  pass "core: default mode refuses and preserves the out-of-scope tracked path, naming it"
else
  fail "core: default mode must refuse (non-zero exit), leave outside/unrelated.txt dirty, and name it on output -- got exit=$core_code outside_status='$core_outside_status'"
fi

# =====================================================================
# Negative control: an all-in-scope dirty tree still snapshots successfully. This proves the
# guard did not simply break the script for the ordinary case.
# =====================================================================
control_repo="$(make_scoped_repo "no")"
run_snapshot "$control_repo" "$FIXTURE_NUM"
control_code="$LAST_CODE"
# Scoped to the two ORIGINAL fixture paths only: the snapshot itself legitimately leaves new,
# untracked patch/marker artifacts under specs/${FIXTURE_DIR_NAME}/, which a whole-tree status
# would (correctly) still show as dirty even though the revert succeeded.
control_original_status="$(git -C "$control_repo" status --porcelain -- in-scope/tracked.txt outside/unrelated.txt)"
control_marker_existed="no"
[ -f "$control_repo/specs/${FIXTURE_DIR_NAME}/.git-snapshot-marker" ] && control_marker_existed="yes"
rm -rf "$control_repo"

if [ "$control_code" -eq 0 ] && [ -z "$control_original_status" ] && [ "$control_marker_existed" = "yes" ]; then
  pass "negative control: all-in-scope dirty tree still snapshots successfully (reverted, marker written)"
else
  fail "negative control: all-in-scope dirty tree must still snapshot successfully -- got exit=$control_code original_status='$control_original_status' marker=$control_marker_existed"
fi

# =====================================================================
# --no-revert regression: never guarded (D2) -- exits 0 and leaves the out-of-scope tree exactly
# as found, on BOTH the unfixed and fixed script.
# =====================================================================
norevert_repo="$(make_scoped_repo "yes")"
# Scoped to the two ORIGINAL fixture paths only -- see the negative-control comment above for
# why: --no-revert also legitimately writes new untracked patch/marker/backup artifacts.
norevert_before="$(git -C "$norevert_repo" status --porcelain -- in-scope/tracked.txt outside/unrelated.txt)"
run_snapshot "$norevert_repo" "$FIXTURE_NUM" --no-revert
norevert_code="$LAST_CODE"
norevert_after="$(git -C "$norevert_repo" status --porcelain -- in-scope/tracked.txt outside/unrelated.txt)"
rm -rf "$norevert_repo"

if [ "$norevert_code" -eq 0 ] && [ "$norevert_before" = "$norevert_after" ]; then
  pass "--no-revert: never guarded, tree left exactly as found on an out-of-scope dirty tree"
else
  fail "--no-revert: expected exit 0 and an unchanged tree -- got exit=$norevert_code before='$norevert_before' after='$norevert_after'"
fi

# =====================================================================
# Silent-exit reproduction (see reports/01_silent-exit-no-revert.md, sibling task directory):
# a held .git/index.lock makes `git stash create` fail with an unguarded, 2>/dev/null-discarded
# command substitution under `set -euo pipefail`, aborting --no-revert mode silently -- mode
# line, then nothing, then exit 1 -- with the working tree left exactly as found but NO
# snapshot taken. The fix degrades this to a named WARNING and a patch-only snapshot (the
# `.patch` file is already computed and is a complete substitute for the stash's coverage),
# so this case is EXPECTED TO FAIL against the unfixed script.
# =====================================================================
lock_repo="$(make_scoped_repo "yes")"
: > "$lock_repo/.git/index.lock"
run_snapshot "$lock_repo" "$FIXTURE_NUM" --no-revert
lock_code="$LAST_CODE"
lock_output="$LAST_OUTPUT"
rm -f "$lock_repo/.git/index.lock"
lock_patch_count="$(find "$lock_repo/specs/${FIXTURE_DIR_NAME}" -maxdepth 1 -name 'working-progress-*.patch' 2>/dev/null | wc -l | tr -d ' ')"
lock_marker="$lock_repo/specs/${FIXTURE_DIR_NAME}/.git-snapshot-marker"
lock_marker_exists="no"
lock_marker_stash_ref=""
if [ -f "$lock_marker" ]; then
  lock_marker_exists="yes"
  lock_marker_stash_ref="$(grep '^STASH_REF=' "$lock_marker" | cut -d= -f2)"
fi
rm -rf "$lock_repo"

if [ "$lock_code" -eq 0 ] \
   && printf '%s' "$lock_output" | grep -qi "warning" \
   && printf '%s' "$lock_output" | grep -qi "stash" \
   && [ "$lock_patch_count" -ge 1 ] \
   && [ "$lock_marker_exists" = "yes" ] \
   && [ "$lock_marker_stash_ref" = "NONE" ]; then
  pass "held index.lock: --no-revert degrades with a named stash warning (not silence), exit 0, patch+marker written, STASH_REF=NONE"
else
  fail "held index.lock: expected exit 0, a named stash warning (not silence), a written patch, and STASH_REF=NONE in the marker -- got exit=$lock_code patch_count=$lock_patch_count marker_exists=$lock_marker_exists stash_ref='$lock_marker_stash_ref' output='$lock_output'"
fi

# =====================================================================
# Companion negative control: the identical fixture WITHOUT the held lock still succeeds,
# writes a real stash@{N} into the marker, and prints the unchanged stdout report -- proving
# the degrade-on-failure path above did not also break the ordinary success path.
# =====================================================================
unlocked_repo="$(make_scoped_repo "yes")"
run_snapshot "$unlocked_repo" "$FIXTURE_NUM" --no-revert
unlocked_code="$LAST_CODE"
unlocked_output="$LAST_OUTPUT"
unlocked_marker="$unlocked_repo/specs/${FIXTURE_DIR_NAME}/.git-snapshot-marker"
unlocked_stash_ref=""
[ -f "$unlocked_marker" ] && unlocked_stash_ref="$(grep '^STASH_REF=' "$unlocked_marker" | cut -d= -f2)"
rm -rf "$unlocked_repo"

if [ "$unlocked_code" -eq 0 ] \
   && printf '%s' "$unlocked_stash_ref" | grep -qE '^stash@\{[0-9]+\}$' \
   && printf '%s' "$unlocked_output" | grep -q "snapshot complete"; then
  pass "unlocked negative control: --no-revert still succeeds, records a real stash ref, unchanged stdout report"
else
  fail "unlocked negative control: expected exit 0, a real stash@{N} ref, and the unchanged success report -- got exit=$unlocked_code stash_ref='$unlocked_stash_ref' output='$unlocked_output'"
fi

# =====================================================================
# SIGPIPE reproduction (see reports/01_silent-exit-no-revert.md): `STASH_REF=$(git stash list |
# head -1 | cut -d: -f1)` is a second, independently triggerable unguarded substitution --
# under `pipefail`, once `git stash list`'s output exceeds the pipe buffer, `head -1` closes the
# pipe before `git stash list` finishes writing and the write fails, aborting the script. This
# is reproduced with ~2000 pre-existing stash entries. The entries are built via `git stash
# create` (distinct commit per differing message, no working-tree mutation needed per entry)
# plus a direct `git update-ref --create-reflog` append, which is fast (no per-entry `git stash
# push`/dirty-tree cycle) -- wall-clock for this case was measured at roughly 12 seconds, well
# under the suite's one-minute gating threshold, so no opt-in env var is used.
# =====================================================================
sigpipe_repo="$(make_scoped_repo "no")"
(
  cd "$sigpipe_repo" || exit 1
  old="0000000000000000000000000000000000000000"
  for i in $(seq 1 2000); do
    sha="$(git stash create "git-snapshot-sigpipe-filler-${i}")"
    git update-ref --create-reflog -m "git-snapshot-sigpipe-filler-${i}" refs/stash "$sha" "$old" >/dev/null 2>&1
    old="$sha"
  done
)
sigpipe_prior_count="$(git -C "$sigpipe_repo" stash list | wc -l | tr -d ' ')"
run_snapshot "$sigpipe_repo" "$FIXTURE_NUM" --no-revert
sigpipe_code="$LAST_CODE"
sigpipe_output="$LAST_OUTPUT"
sigpipe_marker="$sigpipe_repo/specs/${FIXTURE_DIR_NAME}/.git-snapshot-marker"
sigpipe_stash_ref=""
[ -f "$sigpipe_marker" ] && sigpipe_stash_ref="$(grep '^STASH_REF=' "$sigpipe_marker" | cut -d= -f2)"
rm -rf "$sigpipe_repo"

if [ "$sigpipe_prior_count" -lt 1500 ]; then
  fail "SIGPIPE fixture: expected >=1500 pre-existing stash entries to reliably exceed the pipe buffer, got $sigpipe_prior_count -- fixture setup did not reproduce the precondition"
elif [ "$sigpipe_code" -eq 0 ] \
   && printf '%s' "$sigpipe_stash_ref" | grep -qE '^stash@\{[0-9]+\}$' \
   && ! printf '%s' "$sigpipe_output" | grep -qi "unbound variable"; then
  pass "SIGPIPE: large stash list ($sigpipe_prior_count prior entries) parses correctly with no abort and no silence"
else
  fail "SIGPIPE: expected exit 0 and a correctly parsed stash@{N} against a $sigpipe_prior_count-entry stash list -- got exit=$sigpipe_code stash_ref='$sigpipe_stash_ref' output='$sigpipe_output'"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
