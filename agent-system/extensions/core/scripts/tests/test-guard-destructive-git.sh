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
# Concurrency-gated history-rewrite predicate (hazard class 2: rewriting already-committed
# history under a live concurrent writer). Every case below runs on a CLEAN tree
# (make_clean_repo) so the dirty-tree gate cannot be what produces a BLOCK -- if the new
# predicate were ever placed below the clean-tree exemption (dead code), every block case here
# would wrongly turn into an allow, which is exactly what this section pins against.
# =====================================================================

# dead_pid: forks and immediately reaps a child, returning a pid that is guaranteed not alive
# (used to build a genuinely stale/dead lock record without depending on any real stale pid on
# the test host).
dead_pid() {
  ( exit 0 ) &
  local p=$!
  wait "$p" 2>/dev/null || true
  echo "$p"
}

# add_live_lock <repo> <task_number>
# Writes a per-task lock holder.json with a live pid ($$ of the test process itself) and a
# fresh heartbeat, in the shape guard-destructive-git.sh's history_rewrite_live_writer() reads.
add_live_lock() {
  local repo="$1" task_number="$2" dir
  dir="$repo/specs/${task_number}_test_task/.lock"
  mkdir -p "$dir"
  cat > "$dir/holder.json" <<EOF
{
  "session_id": "sess_test_live",
  "task_number": ${task_number},
  "operation": "implement",
  "acquired_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "heartbeat_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "pid": $$
}
EOF
}

# add_stale_lock <repo> <task_number>
# Same shape, but a long-past heartbeat_at AND a pid that is not alive, so both the pid-liveness
# check and the heartbeat-freshness check independently fail the record.
add_stale_lock() {
  local repo="$1" task_number="$2" dir dpid
  dir="$repo/specs/${task_number}_test_task/.lock"
  mkdir -p "$dir"
  dpid="$(dead_pid)"
  cat > "$dir/holder.json" <<EOF
{
  "session_id": "sess_test_stale",
  "task_number": ${task_number},
  "operation": "implement",
  "acquired_at": "2020-01-01T00:00:00Z",
  "heartbeat_at": "2020-01-01T00:00:00Z",
  "pid": ${dpid}
}
EOF
}

# add_live_session <repo>
# Writes a session-registry entry with a live pid, a fresh heartbeat, and a multi-entry
# task_numbers array -- the motivating incident's own shape (one session driving several tasks).
add_live_session() {
  local repo="$1" dir
  dir="$repo/specs/.sessions"
  mkdir -p "$dir"
  cat > "$dir/sess_test_live.json" <<EOF
{
  "session_id": "sess_test_live",
  "pid": $$,
  "heartbeat_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task_numbers": [901, 902]
}
EOF
}

# make_concurrency_repo <fixture-fn> [fixture-args...]
# Builds a clean repo (make_clean_repo), commits a .gitignore for specs/ so the concurrency
# fixture files written under it (by <fixture-fn> below) do not themselves show up as untracked
# and thereby make `git status --porcelain` non-empty for the wrong reason, then applies
# <fixture-fn> to add (or not add, for the no-fixture no-op case) concurrency records. Echoes
# the repo path.
noop_fixture() { :; }

make_concurrency_repo() {
  local fixture_fn="$1"; shift
  local d
  d="$(make_clean_repo)"
  echo "specs/" > "$d/.gitignore"
  git -C "$d" add .gitignore
  git -C "$d" commit -q -m "ignore specs/ for concurrency fixtures"
  "$fixture_fn" "$d" "$@"
  echo "$d"
}

# assert_blocked_clean <label> <command> <fixture-fn> [fixture-args...]
# Builds a clean repo, applies the fixture, runs <command> through the hook, expects exit 2.
assert_blocked_clean() {
  local label="$1" cmd="$2" fixture_fn="$3"; shift 3
  local repo code
  repo="$(make_concurrency_repo "$fixture_fn" "$@")"
  code="$(run_hook_in "$repo" "$cmd")"
  rm -rf "$repo"
  if [ "$code" -eq 2 ]; then
    pass "$label: blocked (exit 2) in clean repo"
  else
    fail "$label: expected exit 2 in clean repo, got exit=$code"
  fi
}

# assert_allowed_clean_with <label> <command> <fixture-fn> [fixture-args...]
# Same shape, expects exit 0. Used both for the true-negative concurrency cases (stale/dead
# record, no record at all) and for command-shape allow cases under a LIVE record (unstaging,
# bare reset, the operator override, git-commit-scoped.sh, message text).
assert_allowed_clean_with() {
  local label="$1" cmd="$2" fixture_fn="$3"; shift 3
  local repo code
  repo="$(make_concurrency_repo "$fixture_fn" "$@")"
  code="$(run_hook_in "$repo" "$cmd")"
  rm -rf "$repo"
  if [ "$code" -eq 0 ]; then
    pass "$label: allowed (exit 0) in clean repo"
  else
    fail "$label: expected exit 0 in clean repo, got exit=$code"
  fi
}

# --- Fixture self-check: the concurrency fixture must not itself dirty the tree ---
concurrency_fixture_check_repo="$(make_concurrency_repo add_live_lock 139)"
concurrency_fixture_check_status="$(git -C "$concurrency_fixture_check_repo" status --porcelain)"
rm -rf "$concurrency_fixture_check_repo"
if [ -z "$concurrency_fixture_check_status" ]; then
  pass "fixture self-check: concurrency fixture (live lock) keeps the tree clean"
else
  fail "fixture self-check: concurrency fixture (live lock) unexpectedly dirtied the tree"
fi

# --- BLOCK cases: clean tree + a live foreign task lock ---
assert_blocked_clean "concurrency: git commit --amend under live lock" \
  "git commit --amend" add_live_lock 139
assert_blocked_clean "concurrency: git commit --amend --no-edit under live lock" \
  "git commit --amend --no-edit" add_live_lock 139
assert_blocked_clean "concurrency: git reset --mixed <sha> under live lock" \
  "git reset --mixed abc1234" add_live_lock 139
assert_blocked_clean "concurrency: git reset <sha> (bare) under live lock" \
  "git reset abc1234" add_live_lock 139
assert_blocked_clean "concurrency: git reset --soft HEAD~1 under live lock" \
  "git reset --soft HEAD~1" add_live_lock 139
assert_blocked_clean "concurrency: git reset HEAD~2 (bare) under live lock" \
  "git reset HEAD~2" add_live_lock 139
assert_blocked_clean "concurrency: git reset --hard <sha> under live lock" \
  "git reset --hard abc1234" add_live_lock 139

# --- Same BLOCK cases, but the concurrency evidence is a live session-registry entry instead
#     of a task lock ---
assert_blocked_clean "concurrency: git commit --amend under live session" \
  "git commit --amend" add_live_session
assert_blocked_clean "concurrency: git reset --mixed <sha> under live session" \
  "git reset --mixed abc1234" add_live_session

# --- ALLOW cases: no concurrency evidence at all (the explicit non-goal: solo interactive
#     --amend with no live writer stays permitted) ---
assert_allowed_clean_with "concurrency allow: git commit --amend with no concurrency record at all" \
  "git commit --amend" noop_fixture
assert_allowed_clean_with "concurrency allow: git reset --hard <sha> with no concurrency record at all" \
  "git reset --hard abc1234" noop_fixture

# --- ALLOW cases: only a stale/dead record (dead pid AND long-past heartbeat) ---
assert_allowed_clean_with "concurrency allow: git commit --amend with only a stale/dead lock" \
  "git commit --amend" add_stale_lock 139
assert_allowed_clean_with "concurrency allow: git reset <sha> with only a stale/dead lock" \
  "git reset abc1234" add_stale_lock 139

# --- ALLOW: git-commit-scoped.sh's own invocation is never blocked (subprocess-invisible; the
#     hook only ever observes tool_input.command, never a wrapper script's internal git calls) ---
assert_allowed_clean_with "concurrency allow: git-commit-scoped.sh invocation under live lock" \
  "bash .claude/scripts/git-commit-scoped.sh --message x --session y -- foo.txt" add_live_lock 139

# --- ALLOW: a commit message that merely contains the literal text "--amend" (single- and
#     multi-line), under a live lock, must not trigger Gate A ---
assert_allowed_clean_with "concurrency allow: single-line message mentions --amend, under live lock" \
  'git commit -m "mention --amend in the message"' add_live_lock 139

concurrency_multiline_amend_mention='git commit -m "mention --amend in the message

Body paragraph that also says --amend, spanning multiple lines."'
assert_allowed_clean_with "concurrency allow: multi-line message mentions --amend, under live lock" \
  "$concurrency_multiline_amend_mention" add_live_lock 139

# --- ALLOW: pathspec-only reset forms, under a live lock, must not trigger Gate B ---
assert_allowed_clean_with "concurrency allow: git reset (bare) under live lock" \
  "git reset" add_live_lock 139
assert_allowed_clean_with "concurrency allow: git reset -- foo.txt under live lock" \
  "git reset -- foo.txt" add_live_lock 139
assert_allowed_clean_with "concurrency allow: git reset HEAD -- foo.txt under live lock" \
  "git reset HEAD -- foo.txt" add_live_lock 139
assert_allowed_clean_with "concurrency allow: git reset HEAD (bare) under live lock" \
  "git reset HEAD" add_live_lock 139

# --- ALLOW: the documented operator-only override, under a live lock ---
assert_allowed_clean_with "concurrency allow: GUARD_ALLOW_HISTORY_REWRITE=1 override under live lock" \
  "GUARD_ALLOW_HISTORY_REWRITE=1 git commit --amend" add_live_lock 139

# =====================================================================
# ADDITIVE: grant-check cases (push-grant-lib.sh's destructive ACTION_CLASS support).
# Every case above this point is byte-identical to before this addition -- these cases only
# ADD coverage for the new grant check; none alters or removes an existing case.
# =====================================================================
PG_LIB="$SCRIPT_DIR/../lib/push-grant-lib.sh"
GRANT_TEST_WORKDIR="$(mktemp -d)"
export PUSH_GRANT_KEY_PATH="${GRANT_TEST_WORKDIR}/push-grant.key"
export PUSH_GRANT_DIR="specs/.push-grant"

# mint_destructive_grant_in <repo> <action_class>
# Mints a grant bound to <repo>'s current HEAD/branch for a destructive action class, using the
# fixed REMOTE=local sentinel guard-destructive-git.sh's own grant check consumes.
mint_destructive_grant_in() {
  local repo="$1" action="$2" ref sha
  (
    cd "$repo" || exit 1
    # shellcheck source=../lib/push-grant-lib.sh
    source "$PG_LIB"
    pg_grant_revoke
    ref="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || ref="HEAD"
    [ -n "$ref" ] && [ "$ref" != "HEAD" ] || ref="HEAD"
    sha="$(git rev-parse HEAD)"
    pg_grant_mint "$action" "local" "$ref" "0" "$sha" "test grant" "please" >/dev/null 2>&1
  )
}

grant_count_in() {
  find "${1}/specs/.push-grant" -maxdepth 1 -name "grant-*.kv" -type f 2>/dev/null | wc -l | tr -d ' '
}

# --- A matching grant allows the one already-matched destructive action, and is consumed ---
grant_repo="$(make_dirty_repo)"
mint_destructive_grant_in "$grant_repo" reset_hard
first_code="$(run_hook_in "$grant_repo" "git reset --hard")"
remaining="$(grant_count_in "$grant_repo")"
rm -rf "$grant_repo"
if [ "$first_code" -eq 0 ] && [ "$remaining" -eq 0 ]; then
  pass "grant: reset_hard grant allows 'git reset --hard' once and is consumed"
else
  fail "grant: expected exit=0 and grant consumed, got exit=$first_code remaining=$remaining"
fi

# --- A second attempt, with the grant already consumed, is blocked exactly as before ---
grant_repo2="$(make_dirty_repo)"
mint_destructive_grant_in "$grant_repo2" reset_hard
run_hook_in "$grant_repo2" "git reset --hard" >/dev/null
echo "more dirt" >> "$grant_repo2/tracked.txt"
second_code="$(run_hook_in "$grant_repo2" "git reset --hard")"
rm -rf "$grant_repo2"
[ "$second_code" -eq 2 ] && pass "grant: second 'git reset --hard' with no remaining grant is blocked" \
  || fail "grant: expected exit=2 on second attempt, got $second_code"

# --- No-grant behaviour is byte-identical to before: a representative blocked case still
#     blocks the same way with PUSH_GRANT_* exported but no grant file present ---
noregress_repo="$(make_dirty_repo)"
noregress_code="$(run_hook_in "$noregress_repo" "git reset --hard")"
rm -rf "$noregress_repo"
[ "$noregress_code" -eq 2 ] && pass "grant: no-grant behaviour unchanged (git reset --hard still blocks)" \
  || fail "grant: no-grant case expected exit=2, got $noregress_code"

# --- A destructive grant does NOT exempt over-staging (the asymmetry this phase must preserve) ---
overstage_repo="$(make_dirty_repo)"
mint_destructive_grant_in "$overstage_repo" reset_hard
overstage_code="$(run_hook_in "$overstage_repo" "git add -A")"
overstage_remaining="$(grant_count_in "$overstage_repo")"
rm -rf "$overstage_repo"
if [ "$overstage_code" -eq 2 ] && [ "$overstage_remaining" -eq 1 ]; then
  pass "grant: 'git add -A' still blocked with a live reset_hard grant present (over-staging immunity)"
else
  fail "grant: expected over-staging still blocked (exit 2) and grant untouched, got exit=$overstage_code remaining=$overstage_remaining"
fi

# --- The history-rewrite predicate still fires with an unrelated grant live, for a DIFFERENT
#     action class than the one the command matches ---
hrw_repo="$(make_clean_repo)"
echo "specs/" > "$hrw_repo/.gitignore"
git -C "$hrw_repo" add .gitignore
git -C "$hrw_repo" commit -q -m "ignore specs/ for concurrency fixtures"
add_live_lock "$hrw_repo" 139
mint_destructive_grant_in "$hrw_repo" reset_hard
hrw_code="$(run_hook_in "$hrw_repo" "git commit --amend -m x")"
hrw_remaining="$(grant_count_in "$hrw_repo")"
rm -rf "$hrw_repo"
if [ "$hrw_code" -eq 2 ] && [ "$hrw_remaining" -eq 1 ]; then
  pass "grant: history-rewrite predicate still fires under a live writer with an unrelated reset_hard grant present"
else
  fail "grant: expected history-rewrite block (exit 2) with grant untouched, got exit=$hrw_code remaining=$hrw_remaining"
fi

rm -rf "$GRANT_TEST_WORKDIR"

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
