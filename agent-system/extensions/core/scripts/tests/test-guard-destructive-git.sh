#!/usr/bin/env bash
# test-guard-destructive-git.sh - Fixture-driven regression suite for
# guard-destructive-git.sh's argv-anchored destructive-pattern matching.
#
# Drives the hook as a real subprocess: pipes a synthetic PreToolUse JSON payload
# ({"tool_input":{"command": "..."}}) on stdin, with cwd set inside a freshly created git
# fixture, and asserts on the hook's EXIT CODE (2 = blocked, 0 = allowed) rather than stdout --
# the hook writes only stderr diagnostics. The hook itself is never instrumented or modified for
# testability; it never learns it is under test.
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md:
# pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d workdirs with trap EXIT
# cleanup, exit 0 on all-pass and exit 1 on any-fail.
#
# CRITICAL environmental requirement: guard-destructive-git.sh exits 0 (allowed) immediately
# whenever `git status --porcelain` is empty OR errors (stderr discarded) -- so a suite run
# outside a git repo, or against a clean tree, would pass every BLOCK-expecting case vacuously.
# Every case in this suite that is not explicitly testing the clean-tree/non-repo exemption
# itself runs inside a freshly created, genuinely DIRTY git repo (see make_dirty_repo below).
# The very first case run is a fixture self-check that fails loudly if this precondition is not
# met, rather than letting every later case silently pass for the wrong reason.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This single relative path resolves to agent-system/extensions/core/hooks/ in source-store mode
# and to .claude/hooks/ in deployed mode, with no branching -- see plan Phase 1.
HOOK="$SCRIPT_DIR/../../hooks/guard-destructive-git.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$HOOK" ]; then
  echo "ERROR: expected guard-destructive-git.sh at $HOOK" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build synthetic PreToolUse payloads and is not on PATH" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# make_dirty_repo
# Creates a fresh git repo under a new mktemp -d directory, commits one file, then modifies it
# so the working tree is genuinely dirty (non-empty `git status --porcelain`). Echoes the repo
# path. No .git-snapshot-marker is ever written, so the marker-freshness exemption never fires.
make_dirty_repo() {
  local d
  d="$(mktemp -d -p "$WORKDIR")"
  git -C "$d" init -q
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test Suite"
  echo "line one" > "$d/tracked.txt"
  git -C "$d" add tracked.txt
  git -C "$d" commit -q -m "initial commit"
  echo "line two" >> "$d/tracked.txt"
  echo "$d"
}

# make_clean_repo
# Same as make_dirty_repo but without the post-commit modification: `git status --porcelain`
# is empty.
make_clean_repo() {
  local d
  d="$(mktemp -d -p "$WORKDIR")"
  git -C "$d" init -q
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test Suite"
  echo "line one" > "$d/tracked.txt"
  git -C "$d" add tracked.txt
  git -C "$d" commit -q -m "initial commit"
  echo "$d"
}

# run_hook_in <repo_dir> <command>
# Runs the hook as a subprocess with cwd set to <repo_dir>, piping a synthetic PreToolUse
# payload built via jq (safe against quotes/newlines in <command>). Echoes the exit code.
run_hook_in() {
  local repo="$1" cmd="$2" code
  ( cd "$repo" && jq -n --arg c "$cmd" '{tool_input: {command: $c}}' | bash "$HOOK" ) \
    >/dev/null 2>/dev/null
  code=$?
  echo "$code"
}

# assert_blocked_dirty <label> <command>
# Creates a fresh dirty repo, runs <command> through the hook, expects exit 2.
assert_blocked_dirty() {
  local label="$1" cmd="$2" repo code
  repo="$(make_dirty_repo)"
  code="$(run_hook_in "$repo" "$cmd")"
  rm -rf "$repo"
  if [ "$code" -eq 2 ]; then
    pass "$label: blocked (exit 2) in dirty repo"
  else
    fail "$label: expected exit 2 in dirty repo, got exit=$code"
  fi
}

# assert_allowed_dirty <label> <command>
# Creates a fresh dirty repo, runs <command> through the hook, expects exit 0. This is the
# shape used for both true-negative cases (safe forms) and false-positive defect cases (text
# that must NOT trip a detector even though the tree is dirty).
assert_allowed_dirty() {
  local label="$1" cmd="$2" repo code
  repo="$(make_dirty_repo)"
  code="$(run_hook_in "$repo" "$cmd")"
  rm -rf "$repo"
  if [ "$code" -eq 0 ]; then
    pass "$label: allowed (exit 0) in dirty repo"
  else
    fail "$label: expected exit 0 in dirty repo, got exit=$code"
  fi
}

# assert_allowed_clean <label> <command>
# Creates a fresh CLEAN repo, runs <command> through the hook, expects exit 0 (clean-tree
# exemption).
assert_allowed_clean() {
  local label="$1" cmd="$2" repo code
  repo="$(make_clean_repo)"
  code="$(run_hook_in "$repo" "$cmd")"
  rm -rf "$repo"
  if [ "$code" -eq 0 ]; then
    pass "$label: allowed (exit 0) in clean repo"
  else
    fail "$label: expected exit 0 in clean repo, got exit=$code"
  fi
}

# =====================================================================
# Fixture self-check (MUST run first): a broken fixture must fail loudly rather than let
# every later BLOCK-expecting case pass vacuously via the clean-tree/non-repo exemption.
# =====================================================================
fixture_repo="$(make_dirty_repo)"
fixture_status="$(git -C "$fixture_repo" status --porcelain)"
rm -rf "$fixture_repo"
if [ -n "$fixture_status" ]; then
  pass "fixture self-check: make_dirty_repo produces a genuinely dirty tree"
else
  fail "fixture self-check: make_dirty_repo produced an EMPTY git status --porcelain -- every later BLOCK case would pass vacuously"
fi

# =====================================================================
# Complementary exemption meta-cases
# =====================================================================
assert_allowed_clean "exemption: clean tree allows a destructive command" "git reset --hard"

empty_repo="$(make_dirty_repo)"
empty_code="$(run_hook_in "$empty_repo" "")"
rm -rf "$empty_repo"
if [ "$empty_code" -eq 0 ]; then
  pass "exemption: empty command allowed (exit 0)"
else
  fail "exemption: empty command expected exit 0, got exit=$empty_code"
fi

# =====================================================================
# Phase 1 baseline cases (must pass against the UNMODIFIED hook, before and after the fix)
# =====================================================================

# --- Over-staging true positives ---
assert_blocked_dirty "baseline: git add -A"                "git add -A"
assert_blocked_dirty "baseline: git add --all"              "git add --all"
assert_blocked_dirty "baseline: git add ."                  "git add ."
assert_blocked_dirty "baseline: git commit -am (message)"   'git commit -am "quick fix"'
assert_blocked_dirty "baseline: git commit -a"               "git commit -a"

# --- Already-working single-line over-staging false-positive exemption ---
assert_allowed_dirty "baseline: git commit -m mentions -a in quotes (single-line)" \
  'git commit -m "fix -a bug"'

# --- One true positive per destructive detector ---
assert_blocked_dirty "baseline: git reset --hard"                  "git reset --hard"
assert_blocked_dirty "baseline: git checkout -- foo.txt"           "git checkout -- foo.txt"
assert_blocked_dirty "baseline: git restore foo.txt"               "git restore foo.txt"
assert_blocked_dirty "baseline: git clean -fd"                     "git clean -fd"
assert_blocked_dirty "baseline: git stash drop"                    "git stash drop"
assert_blocked_dirty "baseline: git stash clear"                   "git stash clear"
assert_blocked_dirty "baseline: git switch -f other"               "git switch -f other"

# --- Safe-form allow cases ---
assert_allowed_dirty "baseline: git restore --staged foo.txt"      "git restore --staged foo.txt"
assert_allowed_dirty "baseline: git stash (bare)"                  "git stash"
assert_allowed_dirty "baseline: git stash pop"                     "git stash pop"
assert_allowed_dirty "baseline: git checkout other-branch (non-forced)" "git checkout other-branch"
assert_allowed_dirty "baseline: plain git commit -m"                'git commit -m "msg"'

# =====================================================================
# Phase 2 defect cases: reproduced false positives / false-exemption bypasses.
# Recorded RED set against the unmodified hook (see phase notes / implementation summary):
#   - multiline essential-refactor commit subject
#   - all single-/multi-line hyphenated-prose cases (essential-refactor, auto-repair, multi-task)
#   - all five per-detector message-text false positives
#   - the #-comment false-exemption case (git restore ... # ... --staged ...)
# The quoted --staged false-exemption case and the no-bypass-opened cases were confirmed GREEN
# against the unmodified hook (safe by accident of ;/&/| segment boundaries), and remain GREEN
# after the fix -- they guard against a regression the fix must not introduce.
# =====================================================================

# --- Observed false positive: multi-line commit message, defect topic word on the subject line ---
multiline_essential_refactor='git commit -m "task: group the essential-refactor batch by topic

This is the body of the commit message, spanning multiple
paragraphs of free-text prose."'
assert_allowed_dirty "defect: multi-line commit, essential-refactor in subject" \
  "$multiline_essential_refactor"

# --- Single-line control for the same text (already passes pre-fix) ---
assert_allowed_dirty "defect control: single-line commit, essential-refactor in subject" \
  'git commit -m "task: group the essential-refactor batch by topic"'

# --- Hyphenated-prose cases, single- and multi-line ---
assert_allowed_dirty "defect: single-line, essential-refactor" \
  'git commit -m "essential-refactor of the module"'
assert_allowed_dirty "defect: single-line, auto-repair" \
  'git commit -m "auto-repair the broken index"'
assert_allowed_dirty "defect: single-line, multi-task" \
  'git commit -m "multi-task coordination update"'

multiline_auto_repair='git commit -m "auto-repair the broken index

Body paragraph explaining the change in detail."'
assert_allowed_dirty "defect: multi-line, auto-repair" "$multiline_auto_repair"

multiline_multi_task='git commit -m "multi-task coordination update

Body paragraph explaining the change in detail."'
assert_allowed_dirty "defect: multi-line, multi-task" "$multiline_multi_task"

# --- Already-passing controls: no 'a' after the hyphen ---
assert_allowed_dirty "control: single-line, un-edged" \
  'git commit -m "un-edged corners of the box"'
assert_allowed_dirty "control: single-line, repo-wide" \
  'git commit -m "repo-wide sweep of the config"'

# --- One message-text false-positive case per vulnerable destructive detector ---
# These five detectors read raw $COMMAND directly (no per-segment quote-strip at all, pre-fix)
# and anchor segment/match extraction on `(^|[;&|][[:space:]]*)` -- start-of-string or a literal
# ;/&/| character, NOT arbitrary preceding prose. A destructive phrase embedded mid-sentence with
# no preceding separator character does not reach these detectors even pre-fix (confirmed by
# reproduction: ordinary prose mentions were GREEN pre-fix and are not evidence of anything). The
# reproducible false positive needs the message text to contain a literal ';', '&', or '|'
# immediately before the git-destructive phrase, which the raw-text anchor cannot distinguish
# from a real shell segment separator -- e.g. a commit message with prose punctuated by a
# semicolon that happens to go on to mention a destructive command.
assert_allowed_dirty "defect: message mentions git reset --hard after a semicolon" \
  'git commit -m "See the notes below; git reset --hard discards local changes"'
assert_allowed_dirty "defect: message mentions git checkout -- after a semicolon" \
  'git commit -m "See notes below; git checkout -- somepath discards edits"'
assert_allowed_dirty "defect: message mentions git restore after a semicolon" \
  'git commit -m "See notes below; git restore somepath discards edits"'
assert_allowed_dirty "defect: message mentions git clean -f -d after a semicolon" \
  'git commit -m "See the notes below; git clean -f -d removes ignored files too"'
assert_allowed_dirty "defect: message mentions forced switch after a semicolon" \
  'git commit -m "See notes below; git switch -f other-branch discards edits"'

multiline_clean_mention='git commit -m "See the notes below; git clean -f -d removes ignored files too

Body paragraph with additional detail about the cleanup."'
assert_allowed_dirty "defect: multi-line message mentions git clean -f -d after a semicolon" \
  "$multiline_clean_mention"

multiline_forced_mention='git commit -m "See notes below; git switch -f other-branch discards edits

Body paragraph with additional detail about the branch switch."'
assert_allowed_dirty "defect: multi-line message mentions forced switch after a semicolon" \
  "$multiline_forced_mention"

# --- --staged false-exemption cases (quoted form was already safe; comment form is the
#     additional in-scope defect) ---
assert_blocked_dirty "no-bypass: quoted --staged does not exempt a real restore" \
  'git restore foo.txt; echo "note: use --staged next time"'
assert_blocked_dirty "defect: #-comment --staged does not exempt a real restore" \
  'git restore foo.txt # use --staged next time'

# --- Comment-strip over-reach guard: an unquoted # in a path/ref must not defeat detection ---
assert_blocked_dirty "no-bypass: unquoted # inside a real destructive command's path stays blocked" \
  'git restore path/with#hash.txt'

# --- No-bypass-opened direction: real destructive commands stay blocked, incl. multi-line ---
multiline_commit_am='git commit -am "quick fix

Second paragraph of an otherwise ordinary commit message."'
assert_blocked_dirty "no-bypass: git commit -am with multi-line message stays blocked" \
  "$multiline_commit_am"
assert_blocked_dirty "no-bypass: git clean -fd stays blocked with multi-line message" \
  'git clean -fd -m "not a real flag on clean, just checking neighbors"'
assert_blocked_dirty "no-bypass: real destructive command beside quoted text stays blocked" \
  'git reset --hard HEAD~1 && echo "done"'

# =====================================================================
# Directory/glob over-staging pathspec cases (the directory-pathspec-overstage hole).
# Recorded RED set against the unmodified hook (confirmed by a run of this suite before the
# ADD_SEGMENTS per-token directory/glob detector was added -- all four failed with exit=0):
#   - git add -- dir/ (trailing slash)
#   - git add dir/ (no -- separator)
#   - git add some_dir (no trailing slash, real on-disk directory)
#   - git add src/*.lean (glob pathspec)
# The loop at that point tests only whole-segment `-A`/`--all`/bare-`.` regexes and never
# inspects individual pathspec tokens, so a directory or glob pathspec passed straight through
# as exit 0. The three ALLOW cases below (explicit multi-file list, plain single file, and a
# directory-looking string inside a commit message) were already GREEN pre-fix and remain GREEN
# after -- they guard against a regression the fix must not introduce.
# =====================================================================

# --- BLOCK: directory pathspec, with and without the "--" separator ---
assert_blocked_dirty "overstage: git add -- dir/ (trailing slash)" \
  "git add -- dir/"
assert_blocked_dirty "overstage: git add dir/ (no -- separator)" \
  "git add dir/"

# --- BLOCK: no-trailing-slash on-disk directory pathspec (filesystem [ -d ] check) ---
overstage_realdir_repo="$(make_dirty_repo)"
mkdir -p "$overstage_realdir_repo/some_dir"
echo "nested" > "$overstage_realdir_repo/some_dir/nested.txt"
overstage_realdir_code="$(run_hook_in "$overstage_realdir_repo" "git add some_dir")"
rm -rf "$overstage_realdir_repo"
if [ "$overstage_realdir_code" -eq 2 ]; then
  pass "overstage: git add some_dir (no trailing slash, real on-disk dir): blocked (exit 2) in dirty repo"
else
  fail "overstage: git add some_dir (no trailing slash, real on-disk dir): expected exit 2 in dirty repo, got exit=$overstage_realdir_code"
fi

# --- BLOCK: glob pathspec ---
assert_blocked_dirty "overstage: git add src/*.lean (glob pathspec)" \
  "git add src/*.lean"

# --- ALLOW: the sanctioned explicit multi-file list stays permitted, no exemption needed ---
assert_allowed_dirty "overstage allow: git add -- a.lean b.lean (explicit multi-file list)" \
  "git add -- a.lean b.lean"

# --- ALLOW: plain single-file control ---
assert_allowed_dirty "overstage allow: git add foo.txt (plain single file)" \
  "git add foo.txt"

# --- ALLOW: a directory-looking string inside a commit message must not trip the detector ---
assert_allowed_dirty "overstage allow: commit message mentions some/dir/ (not a real git add)" \
  'git commit -m "clean up some/dir/ later"'

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
