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
# Additional collaborators driven by the acceptance-fixture section further down: the
# stash-provenance lib (for a direct sp_snapshot_pre pre-call simulation), its PostToolUse
# writer hook (for a real post-call sp_record_new_owned simulation), and git-snapshot.sh itself
# (driven as a real subprocess -- not a stub -- to prove the sanctioned rollback flow still works).
SP_LIB="$SCRIPT_DIR/../lib/stash-provenance-lib.sh"
RECORD_HOOK="$SCRIPT_DIR/../../hooks/record-stash-provenance.sh"
SNAPSHOT_SCRIPT="$SCRIPT_DIR/../git-snapshot.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$HOOK" ]; then
  echo "ERROR: expected guard-destructive-git.sh at $HOOK" >&2
  exit 1
fi

for f in "$SP_LIB" "$RECORD_HOOK" "$SNAPSHOT_SCRIPT"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: expected file at $f" >&2
    exit 1
  fi
done

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

# run_hook_in <repo_dir> <command> [session_id]
# Runs the hook as a subprocess with cwd set to <repo_dir>, piping a synthetic PreToolUse
# payload built via jq (safe against quotes/newlines in <command>). Echoes the exit code.
# <session_id> is OPTIONAL: when non-empty, it is threaded into the payload as a top-level
# "session_id" field (the hazard-class-3 stash-provenance predicate reads it); when omitted,
# the payload carries no session_id field at all, exactly as every pre-existing call site in
# this suite already builds it -- so all 60+ existing call sites keep working unchanged.
run_hook_in() {
  local repo="$1" cmd="$2" sid="${3:-}" code
  if [ -n "$sid" ]; then
    ( cd "$repo" && jq -n --arg c "$cmd" --arg sid "$sid" '{tool_input: {command: $c}, session_id: $sid}' | bash "$HOOK" ) \
      >/dev/null 2>/dev/null
  else
    ( cd "$repo" && jq -n --arg c "$cmd" '{tool_input: {command: $c}}' | bash "$HOOK" ) \
      >/dev/null 2>/dev/null
  fi
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
assert_blocked_dirty "stash_revert: git stash (bare, whole-tree)"  "git stash"
assert_blocked_dirty "baseline: git switch -f other"               "git switch -f other"

# --- stash_revert: bare/whole-tree git stash reverts the tree under concurrent writers ---
# (see rules/git-workflow.md's "Forbidden on a dirty tree" list and
# context/standards/git-workflow-narrative.md's "Bare git stash Incident and Full Detail")
assert_blocked_dirty "stash_revert: git stash push (whole-tree)"        "git stash push"
assert_blocked_dirty "stash_revert: git stash -u (implicit push)"       "git stash -u"
assert_blocked_dirty "stash_revert: git stash --include-untracked"      "git stash --include-untracked"
assert_blocked_dirty "stash_revert: git stash push -u (whole-tree)"     "git stash push -u"
assert_blocked_dirty "stash_revert: git stash push --include-untracked" "git stash push --include-untracked"
assert_blocked_dirty "stash_revert: git stash push -- (empty separator, no path token)" "git stash push --"

# --- stash_revert exemptions: pathspec-scoped (Item 7) and read-only/help/pop/apply (Item 8) ---
assert_allowed_dirty "stash_revert allow: git stash push -- foo.txt (pathspec-scoped)" \
  "git stash push -- foo.txt"
assert_allowed_dirty "stash_revert allow: git stash push -u -- foo.txt bar.txt (pathspec-scoped, multi-file)" \
  "git stash push -u -- foo.txt bar.txt"
assert_allowed_dirty "stash_revert allow: git stash list (read-only)"  "git stash list"
assert_allowed_dirty "stash_revert allow: git stash show (read-only)"  "git stash show"
assert_allowed_dirty "stash_revert allow: git stash --help (help output touches nothing)" \
  "git stash --help"

# --- Item 8 change: git stash pop/apply of a FOREIGN entry is now REFUSED, not
#     unconditionally permitted -- pop/apply stay permitted only for an entry the calling
#     session itself created. See guard-destructive-git.sh's hazard-class-3 predicate and
#     rules/git-workflow.md's "Not blocked" list for the conditional form this replaces. These
#     two cases seed a REAL foreign stash entry (no session-provenance machinery at all) so
#     stash@{0} actually resolves to a commit; without a resolvable target the predicate falls
#     through unblocked (nothing to lose by construction) -- which is exactly why the
#     previous unconditional "git stash pop"/"git stash apply" allow-cases here, run against an
#     always-EMPTY stash list, could never have caught this and are superseded by these two.
stash_apply_repo="$(make_dirty_repo)"
git -C "$stash_apply_repo" stash push -u -m "foreign entry" >/dev/null 2>&1
stash_apply_code="$(run_hook_in "$stash_apply_repo" "git stash apply")"
rm -rf "$stash_apply_repo"
if [ "$stash_apply_code" -eq 2 ]; then
  pass "stash_pop_foreign: git stash apply of a foreign entry (no session_id) is refused"
else
  fail "stash_pop_foreign: expected exit 2 for apply of a foreign entry, got exit=$stash_apply_code"
fi

stash_pop_repo="$(make_dirty_repo)"
git -C "$stash_pop_repo" stash push -u -m "foreign entry" >/dev/null 2>&1
stash_pop_code="$(run_hook_in "$stash_pop_repo" "git stash pop")"
rm -rf "$stash_pop_repo"
if [ "$stash_pop_code" -eq 2 ]; then
  pass "stash_pop_foreign: git stash pop of a foreign entry (no session_id) is refused"
else
  fail "stash_pop_foreign: expected exit 2 for pop of a foreign entry, got exit=$stash_pop_code"
fi

# --- Regression guard: with NO stash entries at all, pop/apply have nothing to resolve and
#     must still fall through unblocked (never over-block an empty stash list) ---
assert_allowed_dirty "stash_pop_foreign allow: git stash apply with an empty stash list" \
  "git stash apply"
assert_allowed_dirty "stash_pop_foreign allow: git stash pop with an empty stash list" \
  "git stash pop"

# --- Safe-form allow cases ---
assert_allowed_dirty "baseline: git restore --staged foo.txt"      "git restore --staged foo.txt"
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

# --- stash_revert mirrors the reset_hard pair: a matching grant allows the bare git stash once,
#     consumes it, and a second bare git stash (re-dirtied) blocks exactly as before ---
stash_grant_repo="$(make_dirty_repo)"
mint_destructive_grant_in "$stash_grant_repo" stash_revert
stash_first_code="$(run_hook_in "$stash_grant_repo" "git stash")"
stash_remaining="$(grant_count_in "$stash_grant_repo")"
if [ "$stash_first_code" -eq 0 ] && [ "$stash_remaining" -eq 0 ]; then
  pass "grant: stash_revert grant allows 'git stash' once and is consumed"
else
  fail "grant: expected exit=0 and grant consumed for stash_revert, got exit=$stash_first_code remaining=$stash_remaining"
fi
echo "more dirt" >> "$stash_grant_repo/tracked.txt"
stash_second_code="$(run_hook_in "$stash_grant_repo" "git stash")"
rm -rf "$stash_grant_repo"
[ "$stash_second_code" -eq 2 ] && pass "grant: second 'git stash' with no remaining stash_revert grant is blocked" \
  || fail "grant: expected exit=2 on second stash_revert attempt, got $stash_second_code"

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

# =====================================================================
# ACCEPTANCE FIXTURES: foreign-stash-pop ownership guard (hazard class 3). Encodes all three
# ACCEPTANCE sentences plus the fail-closed regression case and the grant escape hatch. Every
# BLOCK-expecting case below was confirmed RED against the pre-Phase-3 hook (a stashed copy of
# this file before the hazard-class-3 predicate landed) -- recorded in the implementing task's
# progress files, not re-verified by this suite itself at run time.
# =====================================================================

# run_hook_post_in <repo> <session_id> <command>
# Drives record-stash-provenance.sh (the PostToolUse writer) as a real subprocess, cwd set
# inside <repo>, naming a completed Bash call under <session_id>.
run_hook_post_in() {
  local repo="$1" sid="$2" cmd="$3"
  ( cd "$repo" && jq -n --arg sid "$sid" --arg c "$cmd" '{tool_name:"Bash", session_id:$sid, tool_input:{command:$c}}' \
    | bash "$RECORD_HOOK" ) >/dev/null 2>/dev/null
}

# drive_bash_call <repo> <session_id> <command>
# Simulates ONE full Bash-tool-call lifecycle for provenance purposes: fires the PreToolUse
# guard hook first (its pre-call stash-provenance snapshot is the side effect under test here;
# its own allow/block verdict is not inspected by this helper), then actually RUNS <command>
# for real inside <repo>, then fires the PostToolUse record-stash-provenance.sh hook. Mirrors
# exactly how the real harness drives one Bash call for a session with both provenance hooks
# wired in.
drive_bash_call() {
  local repo="$1" sid="$2" cmd="$3"
  run_hook_in "$repo" "$cmd" "$sid" >/dev/null
  ( cd "$repo" && eval "$cmd" ) >/dev/null 2>&1
  run_hook_post_in "$repo" "$sid" "$cmd"
}

# --- ACCEPTANCE 1: pop/apply of a session-created entry passes ---
owned_repo="$(make_dirty_repo)"
owned_sid="sess_test_owned_pop"
drive_bash_call "$owned_repo" "$owned_sid" "git stash push -- tracked.txt"
owned_pop_code="$(run_hook_in "$owned_repo" "git stash pop" "$owned_sid")"
rm -rf "$owned_repo"
if [ "$owned_pop_code" -eq 0 ]; then
  pass "ACCEPTANCE 1: pop of a session-created entry passes"
else
  fail "ACCEPTANCE 1: expected exit 0 for pop of an owned entry, got exit=$owned_pop_code"
fi

# --- ACCEPTANCE 2 + refusal-prevents-the-drop: foreign pop/apply refused in the exact
#     incident shape (a pre-existing entry created OUTSIDE the session machinery, followed by
#     a same-session push that saves nothing because the only tracked file was already
#     reverted by the pre-existing stash -- "No local changes to save"), bare/apply/ref-naming/
#     sha-naming forms, with a post-check that the foreign entry survives the refusal. ---
LAST_FOREIGN_SHA=""
make_foreign_incident_repo() {
  local sid="$1" d
  d="$(make_dirty_repo)"
  git -C "$d" stash push -m preexisting >/dev/null 2>&1
  LAST_FOREIGN_SHA="$(git -C "$d" rev-parse --verify --quiet 'stash@{0}^{commit}' 2>/dev/null)"
  drive_bash_call "$d" "$sid" "git stash push -- tracked.txt"
  echo "$d"
}

for variant_label in "bare pop" "apply" "pop stash@{0}" "pop by raw sha"; do
  incident_sid="sess_test_incident_$(printf '%s' "$variant_label" | tr -cd 'a-zA-Z0-9')"
  incident_repo="$(make_foreign_incident_repo "$incident_sid")"
  case "$variant_label" in
    "bare pop") incident_cmd="git stash pop" ;;
    "apply") incident_cmd="git stash apply" ;;
    "pop stash@{0}") incident_cmd="git stash pop stash@{0}" ;;
    "pop by raw sha") incident_cmd="git stash pop ${LAST_FOREIGN_SHA}" ;;
  esac
  incident_code="$(run_hook_in "$incident_repo" "$incident_cmd" "$incident_sid")"
  if [ "$incident_code" -eq 2 ]; then
    pass "ACCEPTANCE 2 ($variant_label): foreign entry (push-saved-nothing incident shape) refused"
  else
    fail "ACCEPTANCE 2 ($variant_label): expected exit 2, got exit=$incident_code"
  fi
  survive_count="$(git -C "$incident_repo" stash list | wc -l | tr -d ' ')"
  if [ "$survive_count" -eq 1 ]; then
    pass "refusal-prevents-drop ($variant_label): foreign entry still present in git stash list after the refusal"
  else
    fail "refusal-prevents-drop ($variant_label): expected the foreign entry to survive, stash list has $survive_count entries"
  fi
  rm -rf "$incident_repo"
done

# --- ACCEPTANCE 3: git-snapshot.sh rollback flow unaffected, default and --no-revert modes.
#     Drives the REAL script (not a stub) under a tracked session_id, parses the stash@{N} ref
#     it reports on its own output, then drives the hook for the exact "git stash pop <ref>"
#     the script printed. ---
SNAPSHOT_FIXTURE_NUM=901
make_snapshot_fixture() {
  local d
  d="$(mktemp -d -p "$WORKDIR")"
  git -C "$d" init -q
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test Suite"
  mkdir -p "$d/specs/${SNAPSHOT_FIXTURE_NUM}_fixture" "$d/in-scope"
  echo "keep" > "$d/specs/${SNAPSHOT_FIXTURE_NUM}_fixture/.gitkeep"
  echo "in scope, line one" > "$d/in-scope/tracked.txt"
  cat > "$d/specs/state.json" << STATEEOF
{
  "version": "1.0",
  "next_project_number": $((SNAPSHOT_FIXTURE_NUM + 1)),
  "active_projects": [
    {
      "project_number": ${SNAPSHOT_FIXTURE_NUM},
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
  echo "$d"
}

# run_snapshot_and_pop <extra_snapshot_args...> <label>
# Runs the real git-snapshot.sh under a fresh fixture and session_id, parses its reported
# stash@{N} ref, and drives the hook for the exact pop of that ref under the same session.
run_snapshot_and_pop() {
  local label="$1"; shift
  local repo sid cmd out ref pop_code
  repo="$(make_snapshot_fixture)"
  sid="sess_test_snapshot_$(printf '%s' "$label" | tr -cd 'a-zA-Z0-9')"
  cmd="bash ${SNAPSHOT_SCRIPT}"
  for a in "$@"; do cmd="$cmd $a"; done
  cmd="$cmd ${SNAPSHOT_FIXTURE_NUM}"
  run_hook_in "$repo" "$cmd" "$sid" >/dev/null
  out="$(cd "$repo" && bash "$SNAPSHOT_SCRIPT" "$@" "$SNAPSHOT_FIXTURE_NUM" 2>&1)"
  run_hook_post_in "$repo" "$sid" "$cmd"
  ref="$(printf '%s\n' "$out" | grep -oE 'stash@\{[0-9]+\}' | head -1)"
  if [ -z "$ref" ]; then
    fail "ACCEPTANCE 3 ($label): could not parse a stash@{N} ref from git-snapshot.sh's own output"
    rm -rf "$repo"
    return
  fi
  pop_code="$(run_hook_in "$repo" "git stash pop ${ref}" "$sid")"
  rm -rf "$repo"
  if [ "$pop_code" -eq 0 ]; then
    pass "ACCEPTANCE 3 ($label): git-snapshot.sh rollback pop passes under its own session"
  else
    fail "ACCEPTANCE 3 ($label): expected exit 0 for the rollback pop, got exit=$pop_code"
  fi
}

run_snapshot_and_pop "default mode"
run_snapshot_and_pop "no-revert mode" "--no-revert"

# --- Fail-closed regression: a foreign-pop payload with NO session_id field at all (the shape
#     every pre-existing case in this suite uses) must refuse, never read as "nothing to check
#     against, so allow." ---
failclosed_repo="$(make_foreign_incident_repo "sess_test_failclosed_setup")"
failclosed_code="$(run_hook_in "$failclosed_repo" "git stash pop")"
rm -rf "$failclosed_repo"
if [ "$failclosed_code" -eq 2 ]; then
  pass "fail-closed regression: a payload with no session_id field refuses rather than allowing"
else
  fail "fail-closed regression: expected exit 2 with no session_id field, got exit=$failclosed_code"
fi

# --- Grant escape hatch: a minted stash_pop_foreign grant allows one foreign pop and is
#     consumed; a second attempt with no remaining grant blocks exactly as before. Mirrors the
#     existing reset_hard/stash_revert grant pairs above. ---
grant_escape_repo="$(make_foreign_incident_repo "sess_test_grant_setup")"
mint_destructive_grant_in "$grant_escape_repo" stash_pop_foreign
grant_escape_code="$(run_hook_in "$grant_escape_repo" "git stash pop" "sess_test_grant_setup")"
grant_escape_remaining="$(grant_count_in "$grant_escape_repo")"
if [ "$grant_escape_code" -eq 0 ] && [ "$grant_escape_remaining" -eq 0 ]; then
  pass "grant: stash_pop_foreign grant allows one foreign pop and is consumed"
else
  fail "grant: expected exit=0 and grant consumed, got exit=$grant_escape_code remaining=$grant_escape_remaining"
fi
grant_escape_second_code="$(run_hook_in "$grant_escape_repo" "git stash pop" "sess_test_grant_setup")"
rm -rf "$grant_escape_repo"
if [ "$grant_escape_second_code" -eq 2 ]; then
  pass "grant: second foreign pop with no remaining stash_pop_foreign grant is blocked"
else
  fail "grant: expected exit=2 on second attempt, got $grant_escape_second_code"
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
