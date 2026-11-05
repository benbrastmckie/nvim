#!/usr/bin/env bash
# test-git-commit-scoped.sh - Regression suite for git-commit-scoped.sh's ephemeral-exclude
# injection, proving a held task lock (or any other present, gitignored ephemeral runtime file)
# cannot abort the scoped commit's `git add`.
#
# Root cause under test: naming an already-gitignored path in an explicit `:(exclude)` pathspec
# entry makes `git add` treat it as an explicitly-named ignored path and refuse the WHOLE add
# with "The following paths are ignored by one of your .gitignore files" whenever that path
# currently exists on disk -- even though an ignored path swept up IMPLICITLY by a bare directory
# pathspec is silently skipped. Every assertion below verifies the commit actually landed via
# `git log`/`git show --name-only`, never exit code alone (an exit-code-only assertion would pass
# unchanged against the pre-fix script on any case where the injected exclude never fires).
#
# Harness: each case builds an isolated scratch git repo under mktemp -d, copies
# git-commit-scoped.sh plus its two runtime dependencies (deploy-root-guard.sh, task-lock.sh)
# into <scratch>/.claude/scripts/, so PROJECT_ROOT resolves to <scratch> and
# deploy-root-guard.sh's `*/.claude` case matches -- the real script runs against a real git
# repo, not a mock. Fixtures are synthetic and built inline; this suite never touches the real
# repository tree.
#
# Follows context/standards/shell-script-testing.md: set -uo pipefail, PASSED/FAILED counters
# with pass()/fail()/info(), mktemp -d workdir with a trap EXIT cleanup, exit 0 only when FAILED
# is 0, loud-skip discipline (never a silent no-op).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED (or a required script is
# missing, which is reported loudly, not silently skipped).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."

PASSED=0
FAILED=0

# info() is part of the shared pass/fail/info() counter idiom (shell-script-testing.md);
# unused in this file's current case set, hence never invoked.
# shellcheck disable=SC2329

# --- Loud-skip discipline: verify all three required scripts exist before running anything. ---
REQUIRED_SCRIPTS=(git-commit-scoped.sh deploy-root-guard.sh task-lock.sh lib/common.sh lib/task-lookup-lib.sh lib/derived-artifact-probe-lib.sh lib/engine-written-state-paths-lib.sh)
missing=()
for f in "${REQUIRED_SCRIPTS[@]}"; do
  [ -f "$SRC_SCRIPTS_DIR/$f" ] || missing+=("$f")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "ERROR: test-git-commit-scoped.sh cannot run -- missing required script(s) under $SRC_SCRIPTS_DIR: ${missing[*]}" >&2
  exit 1
fi

TOP_WORKDIR="$(mktemp -d)"
# cleanup() is invoked indirectly via `trap cleanup EXIT` below.
# shellcheck disable=SC2329
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_repo <covered|uncovered> -- builds a scratch repo, echoes its path on stdout. ---
# "covered": .gitignore carries the full ephemeral block (.lock/, .orchestrator-loop-guard,
#            .orchestrator-churn-state.json, .drift-inspection.json) -- the normal/settled state
#            of this repo and of any consumer repo that applied the documented setup block.
# "uncovered": .gitignore carries no ephemeral block at all -- an under-configured consumer repo,
#              the case the literal VERIFICATION BAR wording (three exclude entries still
#              present) exercises.
build_repo() {
  local mode="$1"
  local repo
  repo="$(mktemp -d -p "$TOP_WORKDIR")"

  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test Suite"

  mkdir -p "$repo/.claude/scripts/lib"
  local f
  for f in "${REQUIRED_SCRIPTS[@]}"; do
    cp "$SRC_SCRIPTS_DIR/$f" "$repo/.claude/scripts/$f"
    # lib/common.sh, lib/task-lookup-lib.sh, lib/derived-artifact-probe-lib.sh, and
    # lib/engine-written-state-paths-lib.sh are sourced, never executed -- matches the other
    # scripts/lib/*.sh files.
    [ "$f" = "lib/common.sh" ] || [ "$f" = "lib/task-lookup-lib.sh" ] || [ "$f" = "lib/derived-artifact-probe-lib.sh" ] || [ "$f" = "lib/engine-written-state-paths-lib.sh" ] || chmod +x "$repo/.claude/scripts/$f"
  done

  if [ "$mode" = "covered" ]; then
    cat > "$repo/.gitignore" <<'GITIGNORE_EOF'
**/.lock/
**/.orchestrator-loop-guard
**/.orchestrator-churn-state.json
**/.drift-inspection.json
GITIGNORE_EOF
  else
    cat > "$repo/.gitignore" <<'GITIGNORE_EOF'
*.tmp
GITIGNORE_EOF
  fi

  mkdir -p "$repo/specs/999_probe"
  echo "line1" > "$repo/specs/999_probe/file.txt"
  git -C "$repo" add .gitignore specs/999_probe/file.txt
  git -C "$repo" commit -q -m "initial"

  echo "$repo"
}

# --- build_repo_tracked_ignored -- reproduces the live `specs/archive/state.json` shape: a file
# (and an ordinary sibling) is TRACKED FIRST, and only afterwards does a .gitignore rule land that
# ignore-matches it via a parent-directory pattern. This is the exact ordering the V7 defect
# requires -- git only emits the "ignored by one of your .gitignore files" advisory-but-stages
# false negative for a path that is already tracked when the rule is added; a never-tracked path
# under the same rule is genuinely, correctly dropped (see the untracked case below). Returns the
# repo path on stdout. ---
build_repo_tracked_ignored() {
  local repo
  repo="$(mktemp -d -p "$TOP_WORKDIR")"

  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test Suite"

  mkdir -p "$repo/.claude/scripts/lib"
  local f
  for f in "${REQUIRED_SCRIPTS[@]}"; do
    cp "$SRC_SCRIPTS_DIR/$f" "$repo/.claude/scripts/$f"
    [ "$f" = "lib/common.sh" ] || [ "$f" = "lib/task-lookup-lib.sh" ] || [ "$f" = "lib/derived-artifact-probe-lib.sh" ] || [ "$f" = "lib/engine-written-state-paths-lib.sh" ] || chmod +x "$repo/.claude/scripts/$f"
  done

  mkdir -p "$repo/specs/999_probe/archive"
  echo "line1" > "$repo/specs/999_probe/archive/state.json"
  echo "line1" > "$repo/specs/999_probe/ordinary.txt"
  git -C "$repo" add specs/999_probe/archive/state.json specs/999_probe/ordinary.txt
  git -C "$repo" commit -q -m "initial (tracked before any ignore rule exists)"

  # The ignore rule lands AFTER the tracking commit above -- reproducing the live defect's
  # ordering, not a from-scratch "never tracked" shape.
  echo "specs/999_probe/archive/" > "$repo/.gitignore"
  git -C "$repo" add .gitignore
  git -C "$repo" commit -q -m "add parent-directory ignore rule after tracking"

  echo "$repo"
}

# --- add_ephemeral <repo> <kind>... -- creates the named ephemeral runtime paths on disk. ---
add_ephemeral() {
  local repo="$1"
  shift
  local kind
  for kind in "$@"; do
    case "$kind" in
      lock)
        mkdir -p "$repo/specs/999_probe/.lock"
        echo '{"session_id":"sess_probe","pid":1}' > "$repo/specs/999_probe/.lock/holder.json"
        ;;
      loopguard)
        echo '{"cycle_count":1}' > "$repo/specs/999_probe/.orchestrator-loop-guard"
        ;;
      churn)
        echo '{"counters":{}}' > "$repo/specs/999_probe/.orchestrator-churn-state.json"
        ;;
      drift)
        echo '{}' > "$repo/specs/999_probe/.drift-inspection.json"
        ;;
      *)
        echo "ERROR: add_ephemeral: unknown kind '$kind'" >&2
        return 1
        ;;
    esac
  done
}

# --- run_commit <repo> <git-commit-scoped.sh args...> -- invokes the deployed copy in-repo. ---
run_commit() {
  local repo="$1"
  shift
  (cd "$repo" && bash "$repo/.claude/scripts/git-commit-scoped.sh" "$@")
}

# --- ephemeral_absent <show_output> -- true if none of the four ephemeral basenames appear. ---
ephemeral_absent() {
  ! echo "$1" | grep -Eq '\.lock/|\.orchestrator-loop-guard|\.orchestrator-churn-state\.json|\.drift-inspection\.json'
}

# --- build_repo_movable -- a repo whose tracked fixture lives in a directory that can be moved
# wholesale, with a nested subdirectory so the rename covers more than one file. Defined here
# (rather than down by its original W1-W4 callers) so the X-series false-positive cases above
# that section can call it too -- a bash function must be defined before the line that calls it
# executes. ---
build_repo_movable() {
  local repo
  repo="$(mktemp -d -p "$TOP_WORKDIR")"

  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test Suite"

  mkdir -p "$repo/.claude/scripts/lib"
  local f
  for f in "${REQUIRED_SCRIPTS[@]}"; do
    cp "$SRC_SCRIPTS_DIR/$f" "$repo/.claude/scripts/$f"
    [ "$f" = "lib/common.sh" ] || [ "$f" = "lib/task-lookup-lib.sh" ] || [ "$f" = "lib/derived-artifact-probe-lib.sh" ] || [ "$f" = "lib/engine-written-state-paths-lib.sh" ] || chmod +x "$repo/.claude/scripts/$f"
  done

  mkdir -p "$repo/specs/999_probe/reports"
  mkdir -p "$repo/specs/998_sibling"
  echo "plan" > "$repo/specs/999_probe/plan.md"
  echo "report" > "$repo/specs/999_probe/reports/01_probe.md"
  # An out-of-scope sibling, tracked but never named in any W-case pathspec: lets W1 prove the
  # acceptance did not widen the commit beyond the paths the caller asked for.
  echo "sibling" > "$repo/specs/998_sibling/file.txt"
  git -C "$repo" add -- specs/999_probe/plan.md specs/999_probe/reports/01_probe.md \
    specs/998_sibling/file.txt
  git -C "$repo" commit -q -m "initial"

  echo "$repo"
}

# --- build_repo_with_outside_tree -- a normal "covered" repo plus a SIBLING directory (not a
# descendant) under the same TOP_WORKDIR, holding a real on-disk file. Models the out-of-
# repository pathspec shape: a caller's pathspec list carries an absolute path into a different
# repository's tree. Reuse `run_commit` unchanged; the repo and the outside directory are both
# scratch, mktemp'd under TOP_WORKDIR so the single `trap cleanup EXIT` at the top of this file
# covers both. Prints the repo path on line 1 and the outside directory path on line 2 of stdout
# -- callers read both with `mapfile -t`. ---
build_repo_with_outside_tree() {
  local repo outside
  repo="$(build_repo covered)"
  outside="$(mktemp -d -p "$TOP_WORKDIR")"
  echo "evidence" > "$outside/evidence.txt"
  echo "$repo"
  echo "$outside"
}

# --- build_repo_with_scope <task_number> <project_name> [file_scope_json] -- a "covered" repo
# (build_repo's own specs/999_probe/file.txt fixture) PLUS a synthetic specs/state.json declaring
# one active_projects entry with the given task_number/project_name and, when the third argument
# is non-empty, a `file_scope` field spliced in verbatim as raw JSON -- so a caller can probe the
# V10 fail-open paths deliberately with a deck of malformed shapes (absent key when the argument
# is omitted/empty, "[]", a non-array string, an array with a non-string member), not just the
# well-formed case. Also provisions two additional tracked baseline files,
# specs/999_probe/a.txt and specs/999_probe/b.txt, so callers can independently dirty one, the
# other, or both without needing their own setup. Prints the repo path on stdout. Task number 999
# / project name "probe" (the convention every Z-case below uses) deliberately reuses build_repo's
# own hardcoded "specs/999_probe" fixture directory, so the implicit task-directory scope member
# (resolved via lib/task-lookup-lib.sh's task_lookup_dir) naturally admits that directory without
# any extra setup -- the directory already exists on disk because build_repo created it. ---
build_repo_with_scope() {
  local task_number="$1" project_name="$2" file_scope_json="${3:-}"
  local repo
  repo="$(build_repo covered)"

  local scope_line=""
  if [ -n "$file_scope_json" ]; then
    scope_line="\"file_scope\": ${file_scope_json},"
  fi
  cat > "$repo/specs/state.json" <<STATE_EOF
{
  "active_projects": [
    {
      "project_number": ${task_number},
      "project_name": "${project_name}",
      ${scope_line}
      "status": "implementing"
    }
  ]
}
STATE_EOF

  echo "baseline-a" > "$repo/specs/999_probe/a.txt"
  echo "baseline-b" > "$repo/specs/999_probe/b.txt"
  # out.txt lives under a SIBLING task directory, not "specs/999_probe" -- the implicit
  # task-directory scope member (see is_contained_v10's own header comment) unconditionally
  # admits the whole of "specs/999_probe", so a path inside it can never be the dropped member in
  # a partial-drop case. out.txt gives callers a genuinely out-of-scope candidate instead.
  mkdir -p "$repo/specs/998_sibling"
  echo "baseline-out" > "$repo/specs/998_sibling/out.txt"
  git -C "$repo" add specs/state.json specs/999_probe/a.txt specs/999_probe/b.txt specs/998_sibling/out.txt
  git -C "$repo" commit -q -m "add state.json (declared file_scope) and baseline a.txt/b.txt/out.txt"

  echo "$repo"
}

# =====================================================================
# T1 + T2: fully-covered repo, tracked+modified file, .lock/ present with a holder file.
# T1 -- the regression: commit actually lands (git log gained a commit, file.txt in HEAD).
# T2 -- same commit as T1: .lock is not staged.
# =====================================================================

repo_t1="$(build_repo covered)"
echo "line2" >> "$repo_t1/specs/999_probe/file.txt"
add_ephemeral "$repo_t1" lock
before_t1=$(git -C "$repo_t1" rev-list --count HEAD)
out_t1="$(run_commit "$repo_t1" --message "T1/T2 probe commit" --session "sess_t1" -- "specs/999_probe/" 2>&1)"
rc_t1=$?
after_t1=$(git -C "$repo_t1" rev-list --count HEAD 2>/dev/null || echo "$before_t1")
show_t1="$(git -C "$repo_t1" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_t1" -eq 0 ] && [ "$after_t1" -eq $((before_t1 + 1)) ] && echo "$show_t1" | grep -qF "specs/999_probe/file.txt"; then
  common_test_pass "T1: commit lands (git log gained a commit) with .lock/ present, fully-covered repo (verified via git log/git show, not exit code alone)"
else
  common_test_fail "T1: expected rc=0, HEAD count $before_t1 -> $((before_t1 + 1)), file.txt in HEAD; got rc=$rc_t1 before=$before_t1 after=$after_t1 output=$out_t1"
fi

if echo "$show_t1" | grep -q '\.lock/'; then
  common_test_fail "T2: .lock unexpectedly present in the T1 commit's file list: $show_t1"
else
  common_test_pass "T2: .lock is absent from the T1 commit's file list"
fi

# =====================================================================
# T3: fully-covered repo, all four ephemeral paths present -- commit lands, none appear.
# =====================================================================

repo_t3="$(build_repo covered)"
echo "line2" >> "$repo_t3/specs/999_probe/file.txt"
add_ephemeral "$repo_t3" lock loopguard churn drift
before_t3=$(git -C "$repo_t3" rev-list --count HEAD)
out_t3="$(run_commit "$repo_t3" --message "T3 probe commit" --session "sess_t3" -- "specs/999_probe/" 2>&1)"
rc_t3=$?
after_t3=$(git -C "$repo_t3" rev-list --count HEAD 2>/dev/null || echo "$before_t3")
show_t3="$(git -C "$repo_t3" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_t3" -eq 0 ] && [ "$after_t3" -eq $((before_t3 + 1)) ] \
  && echo "$show_t3" | grep -qF "specs/999_probe/file.txt" \
  && ephemeral_absent "$show_t3"; then
  common_test_pass "T3: commit lands with all four ephemeral paths present; none appear in the commit (fully-covered repo)"
else
  common_test_fail "T3: expected rc=0, commit landed, none of the four ephemeral paths staged; got rc=$rc_t3 before=$before_t3 after=$after_t3 show='$show_t3' output=$out_t3"
fi

# =====================================================================
# T4: fully-covered repo, NO .lock/ present but the other three present -- outcome reading of
# "existing callers unaffected": commit lands and still excludes the other three.
# =====================================================================

repo_t4="$(build_repo covered)"
echo "line2" >> "$repo_t4/specs/999_probe/file.txt"
add_ephemeral "$repo_t4" loopguard churn drift
before_t4=$(git -C "$repo_t4" rev-list --count HEAD)
out_t4="$(run_commit "$repo_t4" --message "T4 probe commit" --session "sess_t4" -- "specs/999_probe/" 2>&1)"
rc_t4=$?
after_t4=$(git -C "$repo_t4" rev-list --count HEAD 2>/dev/null || echo "$before_t4")
show_t4="$(git -C "$repo_t4" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_t4" -eq 0 ] && [ "$after_t4" -eq $((before_t4 + 1)) ] \
  && echo "$show_t4" | grep -qF "specs/999_probe/file.txt" \
  && ephemeral_absent "$show_t4"; then
  common_test_pass "T4: no .lock/ present, other three present; commit lands and excludes the other three (outcome reading of 'existing callers unaffected')"
else
  common_test_fail "T4: expected rc=0, commit landed, other three excluded; got rc=$rc_t4 before=$before_t4 after=$after_t4 show='$show_t4' output=$out_t4"
fi

# =====================================================================
# T5: under-configured repo (.gitignore WITHOUT the ephemeral block), all four present -- the
# literal-pathspec-presence reading: the injected :(exclude) entries are what keep them out here.
# =====================================================================

repo_t5="$(build_repo uncovered)"
echo "line2" >> "$repo_t5/specs/999_probe/file.txt"
add_ephemeral "$repo_t5" lock loopguard churn drift
before_t5=$(git -C "$repo_t5" rev-list --count HEAD)
out_t5="$(run_commit "$repo_t5" --message "T5 probe commit" --session "sess_t5" -- "specs/999_probe/" 2>&1)"
rc_t5=$?
after_t5=$(git -C "$repo_t5" rev-list --count HEAD 2>/dev/null || echo "$before_t5")
show_t5="$(git -C "$repo_t5" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_t5" -eq 0 ] && [ "$after_t5" -eq $((before_t5 + 1)) ] \
  && echo "$show_t5" | grep -qF "specs/999_probe/file.txt" \
  && ephemeral_absent "$show_t5"; then
  common_test_pass "T5: under-configured repo (no ephemeral .gitignore block); commit lands and all four excluded via injected :(exclude) pathspecs"
else
  common_test_fail "T5: expected rc=0, commit landed, all four excluded via injected pathspecs; got rc=$rc_t5 before=$before_t5 after=$after_t5 show='$show_t5' output=$out_t5"
fi

# =====================================================================
# T6: V3 gate intact -- an exclude-only pathspec list is refused before any git add/commit.
# =====================================================================

repo_t6="$(build_repo covered)"
before_t6=$(git -C "$repo_t6" rev-list --count HEAD)
out_t6="$(run_commit "$repo_t6" --message "T6 probe commit" --session "sess_t6" -- ":(exclude)specs/999_probe/file.txt" 2>&1)"
rc_t6=$?
after_t6=$(git -C "$repo_t6" rev-list --count HEAD 2>/dev/null || echo "$before_t6")

if [ "$rc_t6" -eq 2 ] && [ "$after_t6" -eq "$before_t6" ]; then
  common_test_pass "T6: V3 exclude-only refusal intact -- exit 2, no commit created (git log unchanged)"
else
  common_test_fail "T6: expected rc=2 and no new commit; got rc=$rc_t6 before=$before_t6 after=$after_t6 output=$out_t6"
fi

# =====================================================================
# T7: V2 gate intact -- one valid positive pathspec plus one nonexistent positive pathspec still
# commits the valid path and emits a WARN naming the dropped pathspec.
# =====================================================================

repo_t7="$(build_repo covered)"
echo "line2" >> "$repo_t7/specs/999_probe/file.txt"
before_t7=$(git -C "$repo_t7" rev-list --count HEAD)
out_t7="$(run_commit "$repo_t7" --message "T7 probe commit" --session "sess_t7" -- "specs/999_probe/file.txt" "specs/999_probe/nonexistent.txt" 2>&1)"
rc_t7=$?
after_t7=$(git -C "$repo_t7" rev-list --count HEAD 2>/dev/null || echo "$before_t7")
show_t7="$(git -C "$repo_t7" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_t7" -eq 0 ] && [ "$after_t7" -eq $((before_t7 + 1)) ] \
  && echo "$show_t7" | grep -qF "specs/999_probe/file.txt" \
  && echo "$out_t7" | grep -q "^WARN:.*nonexistent\.txt"; then
  common_test_pass "T7: V2 unmatched-pathspec drop intact -- commit still lands with the valid path, WARN names the dropped pathspec"
else
  common_test_fail "T7: expected rc=0, commit landed with file.txt, WARN naming nonexistent.txt; got rc=$rc_t7 before=$before_t7 after=$after_t7 show='$show_t7' output=$out_t7"
fi

# =====================================================================
# T8: V2 gate — deletion-only scoped commit. A staged deletion (git rm) is absent from BOTH the
# working tree and the index, which is exactly the shape the V2 gate currently treats as
# "unmatched" and drops. Research predicts the current script hits the V3 post-filter refusal
# (exit 2) since filtering the sole positive pathspec down to zero leaves a degenerate list, so
# this asserts on the actual commit/status outcome, not on exit code alone, to stay meaningful
# whichever way the current script fails.
# =====================================================================

repo_t8="$(build_repo covered)"
git -C "$repo_t8" rm -q specs/999_probe/file.txt
before_t8=$(git -C "$repo_t8" rev-list --count HEAD)
out_t8="$(run_commit "$repo_t8" --message "T8 probe commit" --session "sess_t8" -- "specs/999_probe/file.txt" 2>&1)"
rc_t8=$?
after_t8=$(git -C "$repo_t8" rev-list --count HEAD 2>/dev/null || echo "$before_t8")
show_t8="$(git -C "$repo_t8" show --name-status --format="" HEAD 2>/dev/null)"

if [ "$after_t8" -eq $((before_t8 + 1)) ] && echo "$show_t8" | grep -qE '^D[[:space:]]+specs/999_probe/file\.txt$'; then
  common_test_pass "T8: deletion-only scoped commit lands with D specs/999_probe/file.txt in HEAD"
else
  common_test_fail "T8: expected a new commit carrying 'D specs/999_probe/file.txt'; got rc=$rc_t8 before=$before_t8 after=$after_t8 show='$show_t8' output=$out_t8"
fi

# =====================================================================
# T9: V2 gate — a staged deletion mixed with a modification in the SAME path set. This is the
# case that catches a wrongly-scoped `git add` array: if the deletion's path were left in the
# `git add` pathspec list, the single all-or-nothing `git add` invocation aborts (verified exit
# 128), which would ALSO drop the modification from the commit even though its own path is
# perfectly valid. Assert ONE commit carries both D and M, and that git status is clean for both
# paths afterwards — not an exit-code check alone.
# =====================================================================

repo_t9="$(build_repo covered)"
echo "keep1" > "$repo_t9/specs/999_probe/keep.txt"
git -C "$repo_t9" add specs/999_probe/keep.txt
git -C "$repo_t9" commit -q -m "add keep.txt"
git -C "$repo_t9" rm -q specs/999_probe/file.txt
echo "keep2" >> "$repo_t9/specs/999_probe/keep.txt"
before_t9=$(git -C "$repo_t9" rev-list --count HEAD)
out_t9="$(run_commit "$repo_t9" --message "T9 probe commit" --session "sess_t9" -- "specs/999_probe/file.txt" "specs/999_probe/keep.txt" 2>&1)"
rc_t9=$?
after_t9=$(git -C "$repo_t9" rev-list --count HEAD 2>/dev/null || echo "$before_t9")
show_t9="$(git -C "$repo_t9" show --name-status --format="" HEAD 2>/dev/null)"
status_t9="$(git -C "$repo_t9" status --short -- specs/999_probe/file.txt specs/999_probe/keep.txt 2>/dev/null)"

if [ "$after_t9" -eq $((before_t9 + 1)) ] \
  && echo "$show_t9" | grep -qE '^D[[:space:]]+specs/999_probe/file\.txt$' \
  && echo "$show_t9" | grep -qE '^M[[:space:]]+specs/999_probe/keep\.txt$' \
  && [ -z "$status_t9" ]; then
  common_test_pass "T9: one commit carries both D specs/999_probe/file.txt and M specs/999_probe/keep.txt; git status clean afterwards"
else
  common_test_fail "T9: expected one commit with D file.txt + M keep.txt and clean status; got rc=$rc_t9 before=$before_t9 after=$after_t9 show='$show_t9' status='$status_t9' output=$out_t9"
fi

# =====================================================================
# T10: V2 gate — in-scope rename. git records a rename as a delete plus an add; both halves are
# passed as positive pathspecs. Accept either the raw D+A shape or a detected R100 rename in
# `git show --name-status`, and assert git status is clean afterwards for both paths.
# =====================================================================

repo_t10="$(build_repo covered)"
git -C "$repo_t10" mv specs/999_probe/file.txt specs/999_probe/renamed.txt
before_t10=$(git -C "$repo_t10" rev-list --count HEAD)
out_t10="$(run_commit "$repo_t10" --message "T10 probe commit" --session "sess_t10" -- "specs/999_probe/file.txt" "specs/999_probe/renamed.txt" 2>&1)"
rc_t10=$?
after_t10=$(git -C "$repo_t10" rev-list --count HEAD 2>/dev/null || echo "$before_t10")
show_t10="$(git -C "$repo_t10" show --name-status --format="" HEAD 2>/dev/null)"
status_t10="$(git -C "$repo_t10" status --short -- specs/999_probe/file.txt specs/999_probe/renamed.txt 2>/dev/null)"

rename_ok=false
if echo "$show_t10" | grep -qE '^R100[[:space:]]+specs/999_probe/file\.txt[[:space:]]+specs/999_probe/renamed\.txt$'; then
  rename_ok=true
elif echo "$show_t10" | grep -qE '^D[[:space:]]+specs/999_probe/file\.txt$' \
  && echo "$show_t10" | grep -qE '^A[[:space:]]+specs/999_probe/renamed\.txt$'; then
  rename_ok=true
fi

if [ "$after_t10" -eq $((before_t10 + 1)) ] && [ "$rename_ok" = "true" ] && [ -z "$status_t10" ]; then
  common_test_pass "T10: in-scope rename commits both halves (D+A or R100); git status clean afterwards"
else
  common_test_fail "T10: expected one commit carrying both rename halves and clean status; got rc=$rc_t10 before=$before_t10 after=$after_t10 show='$show_t10' status='$status_t10' output=$out_t10"
fi

# =====================================================================
# T11 (research case A): EVERY positive pathspec unmatched -- the existing V3 post-filter
# refusal (git-commit-scoped.sh:318-326, added by commit 94256557d), exercised here for the
# first time. Pinned as a regression guard: this must survive the V6 ledger/gate addition
# (Phase 2) completely unchanged, since V3 already covers the all-dropped case and V6's
# predicate must not overlap or replace it.
# =====================================================================

repo_t11="$(build_repo covered)"
before_t11=$(git -C "$repo_t11" rev-list --count HEAD)
out_t11="$(run_commit "$repo_t11" --message "T11 probe commit" --session "sess_t11" -- "specs/998_absent_task/" "specs/998_absent_task/report.md" 2>&1)"
rc_t11=$?
after_t11=$(git -C "$repo_t11" rev-list --count HEAD 2>/dev/null || echo "$before_t11")

if [ "$rc_t11" -eq 2 ] && [ "$after_t11" -eq "$before_t11" ] \
  && echo "$out_t11" | grep -q "ERROR:.*zero positive pathspec entries remain"; then
  common_test_pass "T11: all-dropped pathspec list still hits the existing V3 refusal -- exit 2, no commit created (git log unchanged), unaffected by the V6 addition"
else
  common_test_fail "T11: expected rc=2, no new commit, V3 ERROR naming zero positive entries remaining; got rc=$rc_t11 before=$before_t11 after=$after_t11 output=$out_t11"
fi

# =====================================================================
# T12 (research case B): pins the V6 posture this task adds -- the gap T11 (all-dropped, V3) and
# T13 (partial drop with a surviving diff) do NOT cover. One positive pathspec is unmatched, but
# the SURVIVING pathspec is tracked, present, and unmodified, so `git commit` finds nothing to
# commit (exit 1, pre-V6 behavior). The V6 gate refuses to report that as the plain, ambiguous
# "nothing to commit" NOTE: it exits 4 with a loud ERROR naming the dropped path instead.
# =====================================================================

repo_t12="$(build_repo covered)"
before_t12=$(git -C "$repo_t12" rev-list --count HEAD)
out_t12="$(run_commit "$repo_t12" --message "T12 probe commit" --session "sess_t12" -- "specs/999_probe/file.txt" "specs/999_probe/plans/01_absent.md" 2>&1)"
rc_t12=$?
after_t12=$(git -C "$repo_t12" rev-list --count HEAD 2>/dev/null || echo "$before_t12")

if [ "$rc_t12" -eq 4 ] && [ "$after_t12" -eq "$before_t12" ] \
  && echo "$out_t12" | grep -q "ERROR:.*01_absent\.md" \
  && ! echo "$out_t12" | grep -q "^NOTE: Nothing to commit"; then
  common_test_pass "T12: V6 posture pinned -- partial drop with no surviving diff refuses as exit 4 (no commit, git log unchanged), ERROR names the dropped path, generic NOTE is not the only diagnostic"
else
  common_test_fail "T12: expected rc=4, no new commit, ERROR naming 01_absent.md, no bare NOTE-only output; got rc=$rc_t12 before=$before_t12 after=$after_t12 output=$out_t12"
fi

# =====================================================================
# T13 (research case C): a legitimate partial drop -- one pathspec names an artifact this
# caller's phase did not (yet) produce, but a survivor pathspec DOES carry a real diff. This is
# the HARD CONSTRAINT's partial-drop half and must keep succeeding exactly as before, both
# before and after the V6 gate lands in Phase 2 (T12, added in Phase 3, pins the gap case this
# differs from: a partial drop whose survivors carry NO diff).
# =====================================================================

repo_t13="$(build_repo covered)"
echo "line2" >> "$repo_t13/specs/999_probe/file.txt"
before_t13=$(git -C "$repo_t13" rev-list --count HEAD)
out_t13="$(run_commit "$repo_t13" --message "T13 probe commit" --session "sess_t13" -- "specs/999_probe/file.txt" "specs/999_probe/plans/01_absent.md" 2>&1)"
rc_t13=$?
after_t13=$(git -C "$repo_t13" rev-list --count HEAD 2>/dev/null || echo "$before_t13")
show_t13="$(git -C "$repo_t13" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_t13" -eq 0 ] && [ "$after_t13" -eq $((before_t13 + 1)) ] \
  && echo "$show_t13" | grep -qF "specs/999_probe/file.txt" \
  && echo "$out_t13" | grep -q "^WARN:.*01_absent\.md"; then
  common_test_pass "T13: legitimate partial drop with a surviving diff still commits -- exit 0, HEAD +1, WARN names the dropped path (HARD CONSTRAINT partial-drop half)"
else
  common_test_fail "T13: expected rc=0, HEAD count $before_t13 -> $((before_t13 + 1)), file.txt in HEAD, WARN naming 01_absent.md; got rc=$rc_t13 before=$before_t13 after=$after_t13 show='$show_t13' output=$out_t13"
fi

# =====================================================================
# X1: the silent-staging-drop fixture (V8). Deterministically reproduces the mechanism V8 is
# confirmed to catch -- NOT the real incident, which was a caller-side pathspec-list omission
# upstream of this script (see git-commit-scoped.sh's own V8 header entry for the correction).
# This fixture's shape is instead:
# (a named, on-disk, tracked, non-ignored positive pathspec absent from the resulting commit while
# the script exits 0 and prints nothing) via a planted `pre-commit` hook that mutates the
# TEMPORARY PARTIAL INDEX `git commit -- <pathspec>` builds for the commit, rather than the two-
# writer forced-fail-open harness researched for this mechanism (3/20, 1/10 trials -- rejected as
# the default fixture for being probabilistic, not because it failed to reproduce; see the plan's
# research-integration note and git-commit-scoped.sh's own V8 header entry). The hook receives
# GIT_INDEX_FILE pointing at that temporary index (confirmed by direct probe) and reverts the
# named path to its stale HEAD blob there -- the real index AND the working tree both correctly
# hold the new content throughout, exactly matching the research's "git commit -- <pathspec>
# re-reads the working tree at commit time" finding and proving the drop happens strictly between
# `git add` and the commit's own tree build, where no pre-existing gate (V2/V3/V5/V6/V7) looks.
#
# Before the V8 gate lands (Phase 2), this case is RED: rc=0, HEAD advances (a commit IS created
# despite the drop), and HEAD's content for the path differs from the
# working tree with no diagnostic at all. After the fix: rc=5, a marked ERROR naming the path,
# commit still created. Assertions read HEAD/working-tree content directly (never exit code
# alone), matching this suite's house convention throughout.
# =====================================================================

# --- plant_drop_hook <repo> <path> <stale_sha> -- installs the deterministic drop-injection hook. ---
plant_drop_hook() {
  local repo="$1" path="$2" stale_sha="$3"
  mkdir -p "$repo/.git/hooks"
  cat > "$repo/.git/hooks/pre-commit" <<HOOK_EOF
#!/usr/bin/env bash
# Reverts the named path to its stale HEAD blob inside the TEMPORARY partial index git builds
# for this commit (GIT_INDEX_FILE, exported by git for every hook it runs during commit) --
# deterministically reproducing the silent-staging-drop incident, confirmed by direct probe
# against the installed git version.
git update-index --cacheinfo 100644 ${stale_sha} ${path}
exit 0
HOOK_EOF
  chmod +x "$repo/.git/hooks/pre-commit"
}

repo_x1="$(build_repo covered)"
# Seed a distinct "stale" committed baseline (build_repo's own initial content is "line1"; this
# gives the hook a known, distinct stale blob to revert to -- matching the real incident's "much
# older historical" HEAD snapshot).
echo "stale-regeneration" > "$repo_x1/specs/999_probe/file.txt"
git -C "$repo_x1" add specs/999_probe/file.txt
git -C "$repo_x1" commit -q -m "seed stale content"
stale_sha_x1=$(git -C "$repo_x1" rev-parse HEAD:specs/999_probe/file.txt)
plant_drop_hook "$repo_x1" "specs/999_probe/file.txt" "$stale_sha_x1"
echo "correct-regenerated-content" > "$repo_x1/specs/999_probe/file.txt"
before_x1=$(git -C "$repo_x1" rev-list --count HEAD)
out_x1="$(run_commit "$repo_x1" --message "X1 probe commit" --session "sess_x1" -- "specs/999_probe/file.txt" 2>&1)"
rc_x1=$?
after_x1=$(git -C "$repo_x1" rev-list --count HEAD 2>/dev/null || echo "$before_x1")
head_content_x1="$(git -C "$repo_x1" show HEAD:specs/999_probe/file.txt 2>/dev/null)"
wt_content_x1="$(cat "$repo_x1/specs/999_probe/file.txt" 2>/dev/null)"

if [ "$rc_x1" -eq 5 ] \
  && echo "$out_x1" | grep -q "ERROR:.*V8" \
  && echo "$out_x1" | grep -qF "specs/999_probe/file.txt" \
  && [ "$head_content_x1" != "$wt_content_x1" ]; then
  common_test_pass "X1: the planted drop-injection hook's reproduction of the incident shape is caught -- exit 5, marked ERROR (Verified Finding V8) naming the dropped path, HEAD content independently confirmed to differ from the working tree"
else
  common_test_fail "X1: expected rc=5, marked ERROR (V8) naming specs/999_probe/file.txt, HEAD content != working-tree content (the reproduced drop); got rc=$rc_x1 before=$before_x1 after=$after_x1 head='$head_content_x1' wt='$wt_content_x1' output=$out_x1"
fi

if [ "$after_x1" -eq $((before_x1 + 1)) ]; then
  common_test_pass "X1: the commit is still created despite the drop (commit_exit remains 0) -- the integrity gate reports the partial outcome via a dedicated exit code rather than suppressing the commit"
else
  common_test_fail "X1: expected the commit to still be created (HEAD +1) since the underlying commit_exit remains 0; got before=$before_x1 after=$after_x1 output=$out_x1"
fi

# --- X1 negative-control probe (not a suite case): confirms X1's assertions are a real guard
# against the V8 predicate, not a tautology that would also pass against a gutted/no-op gate.
# Temporarily inverts the sense of the V8 mismatch test in a scratch COPY of the script (never
# the suite's own copies) and re-runs X1's exact scenario, expecting it to now wrongly PASS as if
# there were no mismatch -- proving the real predicate, not this inverted one, is what the
# genuine X1 case above depends on. Reverted immediately; never left in place. ---
x1_probe_dir="$(mktemp -d -p "$TOP_WORKDIR")"
cp "$SRC_SCRIPTS_DIR/git-commit-scoped.sh" "$x1_probe_dir/git-commit-scoped.sh.inverted"
# shellcheck disable=SC2016  # single quotes are deliberate: these must match the SOURCE FILE's
# literal, unexpanded `$v8_post_state`/`$v8_intended` text, never this shell's own expansion of it.
sed -i 's/elif \[ "\$v8_post_state" != "\$v8_intended" \]; then/elif [ "$v8_post_state" = "$v8_intended" ]; then/' \
  "$x1_probe_dir/git-commit-scoped.sh.inverted"
# shellcheck disable=SC2016
if grep -q 'elif \[ "\$v8_post_state" = "\$v8_intended" \]; then' "$x1_probe_dir/git-commit-scoped.sh.inverted" \
  && ! diff -q "$SRC_SCRIPTS_DIR/git-commit-scoped.sh" "$x1_probe_dir/git-commit-scoped.sh.inverted" >/dev/null 2>&1; then
  repo_x1_probe="$(build_repo covered)"
  echo "stale-regeneration" > "$repo_x1_probe/specs/999_probe/file.txt"
  git -C "$repo_x1_probe" add specs/999_probe/file.txt
  git -C "$repo_x1_probe" commit -q -m "seed stale content"
  stale_sha_x1_probe=$(git -C "$repo_x1_probe" rev-parse HEAD:specs/999_probe/file.txt)
  plant_drop_hook "$repo_x1_probe" "specs/999_probe/file.txt" "$stale_sha_x1_probe"
  cp "$x1_probe_dir/git-commit-scoped.sh.inverted" "$repo_x1_probe/.claude/scripts/git-commit-scoped.sh"
  chmod +x "$repo_x1_probe/.claude/scripts/git-commit-scoped.sh"
  echo "correct-regenerated-content" > "$repo_x1_probe/specs/999_probe/file.txt"
  out_x1_probe="$(run_commit "$repo_x1_probe" --message "X1 inversion probe" --session "sess_x1_probe" -- "specs/999_probe/file.txt" 2>&1)"
  rc_x1_probe=$?
  if [ "$rc_x1_probe" -ne 5 ]; then
    common_test_pass "X1 (inversion probe, non-default): with the V8 mismatch predicate inverted, the identical drop scenario no longer exits 5 -- confirms X1's real-predicate assertions are a genuine guard, not a tautology"
  else
    common_test_fail "X1 (inversion probe, non-default): expected the inverted predicate to mask the drop (rc != 5); still got rc=$rc_x1_probe output=$out_x1_probe"
  fi
else
  common_test_fail "X1 (inversion probe, non-default): could not construct the inverted scratch copy -- sed substitution did not apply as expected, inversion probe skipped"
fi

# =====================================================================
# X2-X8: false-positive dimension pins for the V8 gate -- every shape where
# absence from (or a change to) a tree is the CORRECT post-state must never trip V8, and the two
# V8 mismatch classes ("absent from HEAD" vs. "present with different content") must each be
# independently exercised and distinguished in the diagnostic.
# =====================================================================

# --- X2: V2 case-2 already-staged deletion (git rm already applied) -- V8 must not flag the
# correct absence as a drop. ---

repo_x2="$(build_repo covered)"
git -C "$repo_x2" rm -q specs/999_probe/file.txt
before_x2=$(git -C "$repo_x2" rev-list --count HEAD)
out_x2="$(run_commit "$repo_x2" --message "X2 probe" --session "sess_x2" -- "specs/999_probe/file.txt" 2>&1)"
rc_x2=$?
after_x2=$(git -C "$repo_x2" rev-list --count HEAD 2>/dev/null || echo "$before_x2")

if [ "$rc_x2" -eq 0 ] && [ "$after_x2" -eq $((before_x2 + 1)) ] && ! echo "$out_x2" | grep -q "ERROR:.*V8"; then
  common_test_pass "X2: a V2 case-2 already-staged deletion commits cleanly with no V8 diagnostic -- correct absence compares as a match"
else
  common_test_fail "X2: expected rc=0, HEAD+1, no V8 output; got rc=$rc_x2 before=$before_x2 after=$after_x2 output=$out_x2"
fi

# --- X3: V7 fully-staged-deletion acceptance -- a directory-move rename pair, both halves land,
# V8 must not flag the vacated source half. ---

repo_x3="$(build_repo_movable)"
mkdir -p "$repo_x3/specs/archive"
mv "$repo_x3/specs/999_probe" "$repo_x3/specs/archive/999_probe"
before_x3=$(git -C "$repo_x3" rev-list --count HEAD)
out_x3="$(run_commit "$repo_x3" --message "X3 probe" --session "sess_x3" \
  -- "specs/999_probe" "specs/archive/999_probe" 2>&1)"
rc_x3=$?
after_x3=$(git -C "$repo_x3" rev-list --count HEAD 2>/dev/null || echo "$before_x3")

if [ "$rc_x3" -eq 0 ] && [ "$after_x3" -eq $((before_x3 + 1)) ] && ! echo "$out_x3" | grep -q "ERROR:.*V8"; then
  common_test_pass "X3: a directory-move rename pair commits cleanly with no V8 diagnostic -- the vacated source half is not flagged"
else
  common_test_fail "X3: expected rc=0, HEAD+1, no V8 output; got rc=$rc_x3 before=$before_x3 after=$after_x3 output=$out_x3"
fi

# --- X4: directory pathspec in a covered repo with all four ephemeral paths present (U6 shape)
# -- V8 must not flag their absence from the commit. ---

repo_x4="$(build_repo covered)"
echo "line2" >> "$repo_x4/specs/999_probe/file.txt"
add_ephemeral "$repo_x4" lock loopguard churn drift
before_x4=$(git -C "$repo_x4" rev-list --count HEAD)
out_x4="$(run_commit "$repo_x4" --message "X4 probe" --session "sess_x4" -- "specs/999_probe/" 2>&1)"
rc_x4=$?
after_x4=$(git -C "$repo_x4" rev-list --count HEAD 2>/dev/null || echo "$before_x4")

if [ "$rc_x4" -eq 0 ] && [ "$after_x4" -eq $((before_x4 + 1)) ] && ! echo "$out_x4" | grep -q "ERROR:.*V8"; then
  common_test_pass "X4: a directory pathspec with all four ephemeral paths present commits cleanly with no V8 diagnostic"
else
  common_test_fail "X4: expected rc=0, HEAD+1, no V8 output; got rc=$rc_x4 before=$before_x4 after=$after_x4 output=$out_x4"
fi

# --- X5: a newly-created, ignore-matched file swept up IMPLICITLY inside a directory pathspec
# (never named explicitly, unlike U5) -- silently skipped by git add as documented, and V8 must
# not report it either, since the enumeration's --exclude-standard listing never includes it. ---

repo_x5="$(build_repo covered)"
echo "line2" >> "$repo_x5/specs/999_probe/file.txt"
echo "*.ignoredtmp" >> "$repo_x5/.gitignore"
git -C "$repo_x5" add .gitignore
git -C "$repo_x5" commit -q -m "add ignoredtmp rule"
echo "new" > "$repo_x5/specs/999_probe/new.ignoredtmp"
before_x5=$(git -C "$repo_x5" rev-list --count HEAD)
out_x5="$(run_commit "$repo_x5" --message "X5 probe" --session "sess_x5" -- "specs/999_probe/" 2>&1)"
rc_x5=$?
after_x5=$(git -C "$repo_x5" rev-list --count HEAD 2>/dev/null || echo "$before_x5")
show_x5="$(git -C "$repo_x5" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_x5" -eq 0 ] && [ "$after_x5" -eq $((before_x5 + 1)) ] \
  && ! echo "$show_x5" | grep -qF "new.ignoredtmp" \
  && ! echo "$out_x5" | grep -q "ERROR:.*V8"; then
  common_test_pass "X5: a newly-created ignore-matched file swept up implicitly inside a directory pathspec is silently skipped, with no V8 diagnostic"
else
  common_test_fail "X5: expected rc=0, HEAD+1, new.ignoredtmp absent from the commit, no V8 output; got rc=$rc_x5 before=$before_x5 after=$after_x5 show='$show_x5' output=$out_x5"
fi

# --- X6: the benign "nothing to commit" no-op -- every named positive pathspec is tracked and
# unmodified. V8 must not fire (nothing was ever intended to change). ---

repo_x6="$(build_repo covered)"
before_x6=$(git -C "$repo_x6" rev-list --count HEAD)
out_x6="$(run_commit "$repo_x6" --message "X6 probe" --session "sess_x6" -- "specs/999_probe/file.txt" 2>&1)"
rc_x6=$?
after_x6=$(git -C "$repo_x6" rev-list --count HEAD 2>/dev/null || echo "$before_x6")

if [ "$rc_x6" -eq 1 ] && [ "$after_x6" -eq "$before_x6" ] && ! echo "$out_x6" | grep -q "ERROR:.*V8"; then
  common_test_pass "X6: the benign nothing-to-commit no-op is unchanged -- exit 1, no V8 diagnostic"
else
  common_test_fail "X6: expected rc=1, HEAD unchanged, no V8 output; got rc=$rc_x6 before=$before_x6 after=$after_x6 output=$out_x6"
fi

# --- X7: V6's exit 4 path still reports 4, not 5, when a genuine drop coincides with no commit
# being produced. ---

repo_x7="$(build_repo covered)"
before_x7=$(git -C "$repo_x7" rev-list --count HEAD)
out_x7="$(run_commit "$repo_x7" --message "X7 probe" --session "sess_x7" -- "specs/999_probe/file.txt" "specs/999_probe/plans/01_absent.md" 2>&1)"
rc_x7=$?
after_x7=$(git -C "$repo_x7" rev-list --count HEAD 2>/dev/null || echo "$before_x7")

if [ "$rc_x7" -eq 4 ] && [ "$after_x7" -eq "$before_x7" ]; then
  common_test_pass "X7: V6's exit 4 is unaffected by the V8 addition -- still 4, never 5, when no commit was produced at all"
else
  common_test_fail "X7: expected rc=4 (never 5), HEAD unchanged; got rc=$rc_x7 before=$before_x7 after=$after_x7 output=$out_x7"
fi

# --- X8: the SECOND V8 mismatch class -- "absent from HEAD" (a path named, present on disk, and
# never before tracked, that the commit's own tree build drops entirely), distinguished in the
# diagnostic from X1's "present with different content" class. Batched with an ordinary tracked
# change so commit_exit is 0 (a commit IS produced) while the brand-new path alone is dropped. ---

repo_x8="$(build_repo covered)"
echo "line2" >> "$repo_x8/specs/999_probe/file.txt"
echo "newcontent" > "$repo_x8/specs/999_probe/newfile.txt"
mkdir -p "$repo_x8/.git/hooks"
cat > "$repo_x8/.git/hooks/pre-commit" <<'HOOK_EOF'
#!/usr/bin/env bash
git update-index --force-remove specs/999_probe/newfile.txt
exit 0
HOOK_EOF
chmod +x "$repo_x8/.git/hooks/pre-commit"
before_x8=$(git -C "$repo_x8" rev-list --count HEAD)
out_x8="$(run_commit "$repo_x8" --message "X8 probe" --session "sess_x8" -- "specs/999_probe/file.txt" "specs/999_probe/newfile.txt" 2>&1)"
rc_x8=$?
after_x8=$(git -C "$repo_x8" rev-list --count HEAD 2>/dev/null || echo "$before_x8")
newfile_in_head_x8="true"
git -C "$repo_x8" rev-parse --verify -q "HEAD:specs/999_probe/newfile.txt" >/dev/null 2>&1 || newfile_in_head_x8="false"

if [ "$rc_x8" -eq 5 ] && [ "$after_x8" -eq $((before_x8 + 1)) ] \
  && [ "$newfile_in_head_x8" = "false" ] \
  && echo "$out_x8" | grep -q "ERROR:.*V8" \
  && echo "$out_x8" | grep -qF "specs/999_probe/newfile.txt" \
  && echo "$out_x8" | grep -q "newfile\.txt.*absent from HEAD"; then
  common_test_pass "X8: the 'absent from HEAD' V8 mismatch class (a brand-new named path dropped entirely, never before tracked) is caught and distinguished from X1's 'present with different content' class -- exit 5, commit still created, diagnostic names the correct classification"
else
  common_test_fail "X8: expected rc=5, HEAD+1, newfile.txt absent from HEAD, ERROR naming it as 'absent from HEAD'; got rc=$rc_x8 before=$before_x8 after=$after_x8 in_head=$newfile_in_head_x8 output=$out_x8"
fi

# --- X2-X5 negative-control probe (not a suite case): confirms the shared "intended absent
# compares as a match" special-case is what X2-X5 actually depend on, not a tautology. Disables
# that special-case in a scratch COPY of the script (the `[ "$v8_intended" = "absent" ]` branch
# guard, made permanently false) and re-runs X2's exact scenario (the simplest absence-dependent
# case), expecting it to now WRONGLY fire a V8 mismatch -- proving the real special-case, not
# this disabled one, is what the genuine X2-X5 cases above depend on. Reverted immediately. ---
x2_probe_dir="$(mktemp -d -p "$TOP_WORKDIR")"
cp "$SRC_SCRIPTS_DIR/git-commit-scoped.sh" "$x2_probe_dir/git-commit-scoped.sh.inverted"
# shellcheck disable=SC2016
sed -i 's/if \[ "\$v8_intended" = "absent" \]; then/if [ "$v8_intended" = "absent-DISABLED-BY-PROBE" ]; then/' \
  "$x2_probe_dir/git-commit-scoped.sh.inverted"
# shellcheck disable=SC2016
if grep -q 'if \[ "\$v8_intended" = "absent-DISABLED-BY-PROBE" \]; then' "$x2_probe_dir/git-commit-scoped.sh.inverted" \
  && ! diff -q "$SRC_SCRIPTS_DIR/git-commit-scoped.sh" "$x2_probe_dir/git-commit-scoped.sh.inverted" >/dev/null 2>&1; then
  repo_x2_probe="$(build_repo covered)"
  git -C "$repo_x2_probe" rm -q specs/999_probe/file.txt
  cp "$x2_probe_dir/git-commit-scoped.sh.inverted" "$repo_x2_probe/.claude/scripts/git-commit-scoped.sh"
  chmod +x "$repo_x2_probe/.claude/scripts/git-commit-scoped.sh"
  out_x2_probe="$(run_commit "$repo_x2_probe" --message "X2 inversion probe" --session "sess_x2_probe" -- "specs/999_probe/file.txt" 2>&1)"
  rc_x2_probe=$?
  if [ "$rc_x2_probe" -eq 5 ] && echo "$out_x2_probe" | grep -q "ERROR:.*V8"; then
    common_test_pass "X2-X5 (inversion probe, non-default): with the 'intended absent' special-case disabled, X2's identical deletion scenario now WRONGLY fires a V8 mismatch -- confirms X2-X5's absence-dependent assertions are a genuine guard, not a tautology"
  else
    common_test_fail "X2-X5 (inversion probe, non-default): expected the disabled special-case to false-positive (rc=5, V8 output); got rc=$rc_x2_probe output=$out_x2_probe"
  fi
else
  common_test_fail "X2-X5 (inversion probe, non-default): could not construct the disabled-special-case scratch copy -- sed substitution did not apply as expected, inversion probe skipped"
fi

# =====================================================================
# U1-U6: V7 gate -- git add's gitignore advisory false negative for a TRACKED, ignore-matched
# path (the `specs/archive/state.json` live defect shape). Every case verifies commit landing via
# git log/git show, never exit code alone, matching this suite's house style throughout.
# =====================================================================

# --- U1: a tracked, ignore-matched path passed ALONE as a positive pathspec still lands. ---

repo_u1="$(build_repo_tracked_ignored)"
echo "line2" >> "$repo_u1/specs/999_probe/archive/state.json"
before_u1=$(git -C "$repo_u1" rev-list --count HEAD)
out_u1="$(run_commit "$repo_u1" --message "U1 probe commit" --session "sess_u1" -- "specs/999_probe/archive/state.json" 2>&1)"
rc_u1=$?
after_u1=$(git -C "$repo_u1" rev-list --count HEAD 2>/dev/null || echo "$before_u1")
show_u1="$(git -C "$repo_u1" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_u1" -eq 0 ] && [ "$after_u1" -eq $((before_u1 + 1)) ] \
  && echo "$show_u1" | grep -qF "specs/999_probe/archive/state.json"; then
  common_test_pass "U1: tracked, ignore-matched positive pathspec lands despite git add's advisory exit 1 (verified via git log/git show, not exit code alone)"
else
  common_test_fail "U1: expected rc=0, HEAD count $before_u1 -> $((before_u1 + 1)), state.json in HEAD; got rc=$rc_u1 before=$before_u1 after=$after_u1 show='$show_u1' output=$out_u1"
fi

# --- U2: the same tracked, ignore-matched path BATCHED with an ordinary modified path -- both
# land in one commit. ---

repo_u2="$(build_repo_tracked_ignored)"
echo "line2" >> "$repo_u2/specs/999_probe/archive/state.json"
echo "line2" >> "$repo_u2/specs/999_probe/ordinary.txt"
before_u2=$(git -C "$repo_u2" rev-list --count HEAD)
out_u2="$(run_commit "$repo_u2" --message "U2 probe commit" --session "sess_u2" -- "specs/999_probe/archive/state.json" "specs/999_probe/ordinary.txt" 2>&1)"
rc_u2=$?
after_u2=$(git -C "$repo_u2" rev-list --count HEAD 2>/dev/null || echo "$before_u2")
show_u2="$(git -C "$repo_u2" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_u2" -eq 0 ] && [ "$after_u2" -eq $((before_u2 + 1)) ] \
  && echo "$show_u2" | grep -qF "specs/999_probe/archive/state.json" \
  && echo "$show_u2" | grep -qF "specs/999_probe/ordinary.txt"; then
  common_test_pass "U2: tracked ignore-matched path batched with an ordinary modified path -- both land in one commit"
else
  common_test_fail "U2: expected rc=0, HEAD count $before_u2 -> $((before_u2 + 1)), both paths in HEAD; got rc=$rc_u2 before=$before_u2 after=$after_u2 show='$show_u2' output=$out_u2"
fi

# --- U3: the tolerated-advisory invocation emits the stderr NOTE -- the tolerance must never be
# silent. Reuses U1's captured output. ---

if echo "$out_u1" | grep -qi "NOTE:.*tolerated git add"; then
  common_test_pass "U3: the tolerated gitignore-advisory exit is surfaced via a stderr NOTE, not silent"
else
  common_test_fail "U3: expected a stderr NOTE naming the tolerated git add exit; got output=$out_u1"
fi

# --- U4: a genuine add failure (nothing staged) still refuses with exit 2 and names the failing
# path -- proves the V7 fix does not paper over a hard failure (a single all-or-nothing git add
# call aborts staging for every path).
#
# Fixture choice, recorded because it changed: this previously used "/etc/passwd" as the genuine
# add failure. That is now the EXACT shape the V9 repository-containment guard (see this script's
# own header) is designed to classify and drop before `git add` ever sees it -- post-V9, this
# fixture would commit successfully (exit 6) instead of refusing, which is the intended fix, not
# a regression, but it means "/etc/passwd" no longer probes what this case is meant to probe (a
# hard git-add failure V7's tolerance must not paper over). Replaced with an in-repo
# permission-denied file (chmod 000), which `git add` genuinely cannot stage and which V9 does
# NOT classify as out-of-repository (verified in W4's own fixture change), so this case continues
# to probe a genuine, non-V9 add failure. ---

repo_u4="$(build_repo covered)"
echo "line2" >> "$repo_u4/specs/999_probe/file.txt"
echo "secret" > "$repo_u4/specs/999_probe/badperm.txt"
chmod 000 "$repo_u4/specs/999_probe/badperm.txt"
before_u4=$(git -C "$repo_u4" rev-list --count HEAD)
out_u4="$(run_commit "$repo_u4" --message "U4 probe commit" --session "sess_u4" -- "specs/999_probe/file.txt" "specs/999_probe/badperm.txt" 2>&1)"
rc_u4=$?
after_u4=$(git -C "$repo_u4" rev-list --count HEAD 2>/dev/null || echo "$before_u4")
chmod 644 "$repo_u4/specs/999_probe/badperm.txt" 2>/dev/null || true

if [ "$rc_u4" -eq 2 ] && [ "$after_u4" -eq "$before_u4" ] \
  && echo "$out_u4" | grep -q "ERROR:.*genuinely unstaged" \
  && echo "$out_u4" | grep -qF "badperm.txt"; then
  common_test_pass "U4: a genuine add failure (in-repo, permission-denied) still refuses -- exit 2, no commit, ERROR names the failing path (V7 does not paper over the hard-failure case; this fixture is deliberately in-repo so it survives the V9 addition unchanged)"
else
  common_test_fail "U4: expected rc=2, no new commit, ERROR naming badperm.txt; got rc=$rc_u4 before=$before_u4 after=$after_u4 output=$out_u4"
fi

# --- U5: a brand-new UNTRACKED, ignore-matched file named as an explicit positive pathspec is
# still NOT committed -- proves no `-f` behavior crept in; the genuine-drop case stays refused. ---

repo_u5="$(build_repo covered)"
mkdir -p "$repo_u5/specs/999_probe/ignoredsub"
echo "specs/999_probe/ignoredsub/" >> "$repo_u5/.gitignore"
git -C "$repo_u5" add .gitignore
git -C "$repo_u5" commit -q -m "add ignoredsub rule"
echo "new" > "$repo_u5/specs/999_probe/ignoredsub/new.txt"
before_u5=$(git -C "$repo_u5" rev-list --count HEAD)
out_u5="$(run_commit "$repo_u5" --message "U5 probe commit" --session "sess_u5" -- "specs/999_probe/ignoredsub/new.txt" 2>&1)"
rc_u5=$?
after_u5=$(git -C "$repo_u5" rev-list --count HEAD 2>/dev/null || echo "$before_u5")
tracked_u5="$(git -C "$repo_u5" ls-files -- specs/999_probe/ignoredsub/new.txt)"

if [ "$rc_u5" -eq 2 ] && [ "$after_u5" -eq "$before_u5" ] && [ -z "$tracked_u5" ] \
  && echo "$out_u5" | grep -q "ERROR:.*genuinely unstaged"; then
  common_test_pass "U5: a brand-new untracked, ignore-matched path named explicitly is still refused -- no -f behavior introduced"
else
  common_test_fail "U5: expected rc=2, no new commit, new.txt never tracked; got rc=$rc_u5 before=$before_u5 after=$after_u5 tracked='$tracked_u5' output=$out_u5"
fi

# --- U6: a directory pathspec in a fully-covered repo with ephemeral paths present still commits
# and still excludes them -- proves the exclude entries passed into the new git diff --quiet check
# do not false-flag the directory pathspec. ---

repo_u6="$(build_repo covered)"
echo "line2" >> "$repo_u6/specs/999_probe/file.txt"
add_ephemeral "$repo_u6" lock loopguard churn drift
before_u6=$(git -C "$repo_u6" rev-list --count HEAD)
out_u6="$(run_commit "$repo_u6" --message "U6 probe commit" --session "sess_u6" -- "specs/999_probe/" 2>&1)"
rc_u6=$?
after_u6=$(git -C "$repo_u6" rev-list --count HEAD 2>/dev/null || echo "$before_u6")
show_u6="$(git -C "$repo_u6" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_u6" -eq 0 ] && [ "$after_u6" -eq $((before_u6 + 1)) ] \
  && echo "$show_u6" | grep -qF "specs/999_probe/file.txt" \
  && ephemeral_absent "$show_u6"; then
  common_test_pass "U6: directory pathspec with ephemeral excludes present still commits and excludes them -- the V7 per-path diff check is not false-flagged by the directory pathspec"
else
  common_test_fail "U6: expected rc=0, commit landed, ephemerals excluded; got rc=$rc_u6 before=$before_u6 after=$after_u6 show='$show_u6' output=$out_u6"
fi

# task-ref-ok:begin category 6-adjacent: every "task 40x"/"#40x"/"--task 40x" literal in the V1-V8
# block below is synthetic fixture data exercising git-commit-scoped.sh's OWN --task input (an
# arbitrary integer identifying the committing task for the contended-path claim check) -- never
# a citation of this repo's own ephemeral task tracker. The fixture task numbers (401, 402) are
# arbitrary and carry no relationship to any real specs/{NNN}_{SLUG}/ task directory.
#
# V1-V8: V5 contended-path refusal (--task opt-in only; the working-tree/build isolation posture
# decision record's Option 3(ii)). write_manifest builds a synthetic
# specs/.contention-manifest/<name>.json exactly like orchestrate-cycle-plan.sh's
# build_contended_manifest would; every existing gate (V2/V3/mutex/ephemeral-exclude) is left
# completely untouched by these cases -- they only ever add --task to run_commit's argv.
# =====================================================================

write_manifest() {
  local repo="$1" name="$2" contended_json="$3"
  mkdir -p "$repo/specs/.contention-manifest"
  printf '{"session_id":"%s","cycle":1,"generated_at":"2026-01-01T00:00:00Z","contended":%s}' \
    "$name" "$contended_json" > "$repo/specs/.contention-manifest/${name}.json"
}

# --- V1: a path NOT listed in the manifest proceeds exactly as today, even with --task given. ---

repo_v1="$(build_repo covered)"
echo "line2" >> "$repo_v1/specs/999_probe/file.txt"
write_manifest "$repo_v1" "sess_v1" '[{"path":"specs/999_probe/OTHER.txt","tasks":[401,402],"granularity":"file"}]'
before_v1=$(git -C "$repo_v1" rev-list --count HEAD)
out_v1="$(run_commit "$repo_v1" --message "V1 probe" --session "sess_v1" --task 401 -- "specs/999_probe/file.txt" 2>&1)"
rc_v1=$?
after_v1=$(git -C "$repo_v1" rev-list --count HEAD 2>/dev/null || echo "$before_v1")

if [ "$rc_v1" -eq 0 ] && [ "$after_v1" -eq $((before_v1 + 1)) ]; then
  common_test_pass "V1: an unlisted path proceeds exactly as today, even with --task given"
else
  common_test_fail "V1: expected rc=0 and HEAD advanced by 1; got rc=$rc_v1 before=$before_v1 after=$after_v1 output=$out_v1"
fi

# --- V2: an unclaimed listed path claims, commits, and releases. ---

repo_v2="$(build_repo covered)"
echo "line2" >> "$repo_v2/specs/999_probe/file.txt"
write_manifest "$repo_v2" "sess_v2" '[{"path":"specs/999_probe/file.txt","tasks":[401,402],"granularity":"file"}]'
before_v2=$(git -C "$repo_v2" rev-list --count HEAD)
out_v2="$(run_commit "$repo_v2" --message "V2 probe" --session "sess_v2" --task 401 -- "specs/999_probe/file.txt" 2>&1)"
rc_v2=$?
after_v2=$(git -C "$repo_v2" rev-list --count HEAD 2>/dev/null || echo "$before_v2")

if [ "$rc_v2" -eq 0 ] && [ "$after_v2" -eq $((before_v2 + 1)) ]; then
  common_test_pass "V2: an unclaimed listed path claims and commits successfully"
else
  common_test_fail "V2: expected rc=0 and HEAD advanced by 1; got rc=$rc_v2 before=$before_v2 after=$after_v2 output=$out_v2"
fi
if [ ! -d "$repo_v2/specs/.contention-claims" ] || [ -z "$(ls -A "$repo_v2/specs/.contention-claims" 2>/dev/null)" ]; then
  common_test_pass "V2: the claim was released after the commit (no lingering claim directory)"
else
  common_test_fail "V2: expected the claim released, found: $(ls "$repo_v2/specs/.contention-claims" 2>/dev/null)"
fi

# --- V3: a path already claimed by THIS SAME task is re-entrant -- proceeds without error, and
# the pre-existing claim (owned by an OUTER caller, not freshly acquired by this invocation) is
# left in place, never auto-released by this invocation. ---

repo_v3="$(build_repo covered)"
echo "line2" >> "$repo_v3/specs/999_probe/file.txt"
write_manifest "$repo_v3" "sess_v3" '[{"path":"specs/999_probe/file.txt","tasks":[401,402],"granularity":"file"}]'
(cd "$repo_v3" && bash .claude/scripts/task-lock.sh claim-acquire "specs/999_probe/file.txt" 401 sess_v3 >/dev/null)
before_v3=$(git -C "$repo_v3" rev-list --count HEAD)
out_v3="$(run_commit "$repo_v3" --message "V3 probe" --session "sess_v3" --task 401 -- "specs/999_probe/file.txt" 2>&1)"
rc_v3=$?
after_v3=$(git -C "$repo_v3" rev-list --count HEAD 2>/dev/null || echo "$before_v3")

if [ "$rc_v3" -eq 0 ] && [ "$after_v3" -eq $((before_v3 + 1)) ]; then
  common_test_pass "V3: a path already claimed by this same task is re-entrant -- commit proceeds"
else
  common_test_fail "V3: expected rc=0 and HEAD advanced by 1; got rc=$rc_v3 before=$before_v3 after=$after_v3 output=$out_v3"
fi
if [ -d "$repo_v3/specs/.contention-claims" ] && [ -n "$(ls -A "$repo_v3/specs/.contention-claims" 2>/dev/null)" ]; then
  common_test_pass "V3: the pre-existing (outer) claim is left in place -- never auto-released by a re-entrant caller"
else
  common_test_fail "V3: expected the outer claim still present after a re-entrant commit, found none"
fi
(cd "$repo_v3" && bash .claude/scripts/task-lock.sh claim-release "specs/999_probe/file.txt" 401 >/dev/null 2>&1)

# --- V4: a path claimed by ANOTHER live task refuses before any git add -- nothing staged, the
# foreign claim is left untouched, and the target commit count does not advance. ---

repo_v4="$(build_repo covered)"
echo "line2" >> "$repo_v4/specs/999_probe/file.txt"
write_manifest "$repo_v4" "sess_v4" '[{"path":"specs/999_probe/file.txt","tasks":[401,402],"granularity":"file"}]'
(cd "$repo_v4" && bash .claude/scripts/task-lock.sh claim-acquire "specs/999_probe/file.txt" 402 sess_v4_other >/dev/null)
before_v4=$(git -C "$repo_v4" rev-list --count HEAD)
out_v4="$(run_commit "$repo_v4" --message "V4 probe" --session "sess_v4" --task 401 -- "specs/999_probe/file.txt" 2>&1)"
rc_v4=$?
after_v4=$(git -C "$repo_v4" rev-list --count HEAD 2>/dev/null || echo "$before_v4")
staged_v4="$(git -C "$repo_v4" diff --cached --name-only 2>/dev/null)"

if [ "$rc_v4" -eq 3 ] && [ "$after_v4" -eq "$before_v4" ]; then
  common_test_pass "V4: a path held by another live task refuses (exit 3), HEAD unchanged"
else
  common_test_fail "V4: expected rc=3 and HEAD unchanged; got rc=$rc_v4 before=$before_v4 after=$after_v4 output=$out_v4"
fi
if [ -z "$staged_v4" ]; then
  common_test_pass "V4: nothing staged on the foreign-claim refusal (git diff --cached is empty)"
else
  common_test_fail "V4: expected nothing staged, found: $staged_v4"
fi
if echo "$out_v4" | grep -q "task #402"; then
  common_test_pass "V4: the refusal names the holding task (#402) verbatim"
else
  common_test_fail "V4: expected the refusal to name task #402, got: $out_v4"
fi
holder_after_v4=$(jq -r '.task // empty' "$repo_v4/specs/.contention-claims/specs_999_probe_file.txt/holder.json" 2>/dev/null)
if [ "$holder_after_v4" = "402" ]; then
  common_test_pass "V4: the foreign claim is untouched (still held by task #402)"
else
  common_test_fail "V4: expected the foreign claim to still be held by task #402, got holder='$holder_after_v4'"
fi
(cd "$repo_v4" && bash .claude/scripts/task-lock.sh claim-release "specs/999_probe/file.txt" 402 >/dev/null 2>&1)

# --- V5: a stale claim (age past its own holder-declared window) is reclaimed and the commit
# proceeds -- the age-based staleness override, reusing task-lock.sh's own lease pattern. ---

repo_v5="$(build_repo covered)"
echo "line2" >> "$repo_v5/specs/999_probe/file.txt"
write_manifest "$repo_v5" "sess_v5" '[{"path":"specs/999_probe/file.txt","tasks":[401,402],"granularity":"file"}]'
(cd "$repo_v5" && bash .claude/scripts/task-lock.sh claim-acquire "specs/999_probe/file.txt" 402 sess_v5_other 1 >/dev/null)
sleep 2
before_v5=$(git -C "$repo_v5" rev-list --count HEAD)
out_v5="$(run_commit "$repo_v5" --message "V5 probe" --session "sess_v5" --task 401 -- "specs/999_probe/file.txt" 2>&1)"
rc_v5=$?
after_v5=$(git -C "$repo_v5" rev-list --count HEAD 2>/dev/null || echo "$before_v5")

if [ "$rc_v5" -eq 0 ] && [ "$after_v5" -eq $((before_v5 + 1)) ]; then
  common_test_pass "V5: a stale foreign claim is reclaimed; the commit proceeds"
else
  common_test_fail "V5: expected rc=0 and HEAD advanced by 1; got rc=$rc_v5 before=$before_v5 after=$after_v5 output=$out_v5"
fi

# --- V6: a missing or malformed manifest fails open -- the commit still proceeds, with a
# non-blocking WARN naming the unreadable file. ---

repo_v6="$(build_repo covered)"
echo "line2" >> "$repo_v6/specs/999_probe/file.txt"
mkdir -p "$repo_v6/specs/.contention-manifest"
echo '{not valid json' > "$repo_v6/specs/.contention-manifest/sess_v6.json"
before_v6=$(git -C "$repo_v6" rev-list --count HEAD)
out_v6="$(run_commit "$repo_v6" --message "V6 probe" --session "sess_v6" --task 401 -- "specs/999_probe/file.txt" 2>&1)"
rc_v6=$?
after_v6=$(git -C "$repo_v6" rev-list --count HEAD 2>/dev/null || echo "$before_v6")

if [ "$rc_v6" -eq 0 ] && [ "$after_v6" -eq $((before_v6 + 1)) ]; then
  common_test_pass "V6: a malformed manifest fails open -- the commit still proceeds"
else
  common_test_fail "V6: expected rc=0 and HEAD advanced by 1 despite the malformed manifest; got rc=$rc_v6 before=$before_v6 after=$after_v6 output=$out_v6"
fi
if echo "$out_v6" | grep -qi "could not parse contention manifest"; then
  common_test_pass "V6: a non-blocking WARN names the unparseable manifest file"
else
  common_test_fail "V6: expected a WARN about the malformed manifest, got: $out_v6"
fi

# --- V7: omitting --task entirely fails open -- no claim check at all, even when the manifest
# lists the exact path being committed. ---

repo_v7="$(build_repo covered)"
echo "line2" >> "$repo_v7/specs/999_probe/file.txt"
write_manifest "$repo_v7" "sess_v7" '[{"path":"specs/999_probe/file.txt","tasks":[401,402],"granularity":"file"}]'
(cd "$repo_v7" && bash .claude/scripts/task-lock.sh claim-acquire "specs/999_probe/file.txt" 402 sess_v7_other >/dev/null)
before_v7=$(git -C "$repo_v7" rev-list --count HEAD)
out_v7="$(run_commit "$repo_v7" --message "V7 probe" --session "sess_v7" -- "specs/999_probe/file.txt" 2>&1)"
rc_v7=$?
after_v7=$(git -C "$repo_v7" rev-list --count HEAD 2>/dev/null || echo "$before_v7")

if [ "$rc_v7" -eq 0 ] && [ "$after_v7" -eq $((before_v7 + 1)) ]; then
  common_test_pass "V7: omitting --task fails open -- the commit proceeds even though the path is held by another task in the manifest"
else
  common_test_fail "V7: expected rc=0 and HEAD advanced by 1 with --task omitted; got rc=$rc_v7 before=$before_v7 after=$after_v7 output=$out_v7"
fi
(cd "$repo_v7" && bash .claude/scripts/task-lock.sh claim-release "specs/999_probe/file.txt" 402 >/dev/null 2>&1)

# --- V8: every pre-existing V2/V3 case (T1-T10 above) is unaffected -- already proven by T1-T10
# passing above without any of them ever passing --task; no new fixture needed here, this is a
# structural note that V8's own acceptance is "look at the T-series results already printed".
# task-ref-ok:end

# =====================================================================
# W1-W4: the fully-staged-deletion acceptance in the V7 verification loop.
#
# Defect these pin: V7 verified every positive pathspec by requiring it PRESENT in `git ls-files`
# after the add. That is wrong for a pathspec whose every tracked file `git add` just staged as
# DELETED -- absence from the index is the CORRECT post-add state there. The source half of a
# directory move (an archival pass that `mv`s a directory and names both old and new paths in one
# call) hit this on every run: `git add` staged the rename perfectly, `git status` showed
# `R old -> new`, and the script then refused the commit anyway with "not present in the index at
# all". A pure directory deletion (naming only the vacated path) was refused identically.
#
# Every assertion below checks the COMMIT actually landed (or actually did not) via git log/git
# show, never exit code alone -- an exit-code-only assertion on W1 would pass against a script
# that committed nothing at all.
# =====================================================================

# build_repo_movable is defined earlier in this file (alongside build_repo/ephemeral_absent),
# since the X-series false-positive cases above this section call it too, and a bash function
# must be defined before the line that calls it executes.

# --- W1: the headline regression -- a directory-move pathspec pair (vacated source + populated
# destination) commits, the commit records the move as renames, and an out-of-scope modified
# sibling is NOT swept in (the acceptance must not widen the commit's scope). ---

repo_w1="$(build_repo_movable)"
mkdir -p "$repo_w1/specs/archive"
mv "$repo_w1/specs/999_probe" "$repo_w1/specs/archive/999_probe"
echo "touched out of scope" >> "$repo_w1/specs/998_sibling/file.txt"
before_w1=$(git -C "$repo_w1" rev-list --count HEAD)
out_w1="$(run_commit "$repo_w1" --message "W1 archive move" --session "sess_w1" \
  -- "specs/999_probe" "specs/archive/999_probe" 2>&1)"
rc_w1=$?
after_w1=$(git -C "$repo_w1" rev-list --count HEAD 2>/dev/null || echo "$before_w1")
show_w1="$(git -C "$repo_w1" show --name-status --format="" HEAD 2>/dev/null)"
renames_w1=$(echo "$show_w1" | grep -c '^R' || true)
sibling_still_dirty_w1=$(git -C "$repo_w1" status --porcelain -- specs/998_sibling/file.txt | wc -l)

if [ "$rc_w1" -eq 0 ] && [ "$after_w1" -eq $((before_w1 + 1)) ] \
  && [ "$renames_w1" -eq 2 ] \
  && ! echo "$show_w1" | grep -qF "specs/998_sibling/file.txt" \
  && [ "$sibling_still_dirty_w1" -eq 1 ]; then
  common_test_pass "W1: a directory-move pathspec pair commits -- HEAD advanced, both files recorded as renames, out-of-scope modified sibling left uncommitted (verified via git log/git show, not exit code)"
else
  common_test_fail "W1: expected rc=0, HEAD+1, 2 renames in HEAD, sibling absent from the commit and still dirty; got rc=$rc_w1 before=$before_w1 after=$after_w1 renames=$renames_w1 sibling_dirty=$sibling_still_dirty_w1 show=$show_w1 output=$out_w1"
fi

# --- W2: the acceptance is never silent -- it names the accepted pathspec on stderr, matching the
# discipline the sibling tolerated-advisory NOTE already follows. Reuses W1's captured output. ---

if echo "$out_w1" | grep -q "NOTE:.*fully-staged deletion" \
  && echo "$out_w1" | grep -qF "specs/999_probe"; then
  common_test_pass "W2: the fully-staged-deletion acceptance emits a stderr NOTE naming the accepted pathspec, not silent"
else
  common_test_fail "W2: expected a stderr NOTE naming the accepted fully-staged-deletion pathspec; got output=$out_w1"
fi

# --- W3: the same acceptance covers a PURE deletion -- the vacated path named with no destination
# in the pathspec list at all (a directory removed outright, not moved). Refused identically
# before the fix, for the identical reason. ---

repo_w3="$(build_repo_movable)"
rm -rf "$repo_w3/specs/999_probe"
before_w3=$(git -C "$repo_w3" rev-list --count HEAD)
out_w3="$(run_commit "$repo_w3" --message "W3 pure deletion" --session "sess_w3" \
  -- "specs/999_probe" 2>&1)"
rc_w3=$?
after_w3=$(git -C "$repo_w3" rev-list --count HEAD 2>/dev/null || echo "$before_w3")
dels_w3=$(git -C "$repo_w3" show --name-status --format="" HEAD 2>/dev/null | grep -c '^D' || true)

if [ "$rc_w3" -eq 0 ] && [ "$after_w3" -eq $((before_w3 + 1)) ] && [ "$dels_w3" -eq 2 ]; then
  common_test_pass "W3: a pure directory deletion (vacated pathspec, no destination) commits -- HEAD advanced, both files recorded as deletions"
else
  common_test_fail "W3: expected rc=0, HEAD+1, 2 deletions in HEAD; got rc=$rc_w3 before=$before_w3 after=$after_w3 dels=$dels_w3 output=$out_w3"
fi

# --- W4: THE SAFETY CASE -- a genuine add failure sharing the pathspec list with a legitimate
# directory move still refuses. `git add` is one all-or-nothing call, so a genuine in-repo
# staging failure aborts staging for the move as well; the acceptance must NOT mask that, because
# the vacated source then still holds its index entries and is genuinely unstaged. Proves the new
# branch is unreachable whenever the deletion was not actually staged.
#
# Fixture choice, recorded because it changed: this previously used "/etc/passwd" as the genuine
# add failure. That stopped being a safe choice once the repository-containment gate (V9, see
# this script's own header) was added: V9 classifies "/etc/passwd" as out-of-repository and drops
# it BEFORE `git add` ever sees it, so `git add` would receive only the move's two paths, the move
# would succeed exactly as in W1, and the exit code would become 6 rather than 2 -- silently
# flipping this case's meaning from "a genuine failure aborts everything" to "an out-of-repo drop
# is harmless", defeating its purpose as a safety case pinned against V9. Replaced with an in-repo
# permission-denied file (chmod 000), which `git add` genuinely cannot stage (verified
# empirically: "fatal: adding files failed", rc=128, and the mixed valid paths are NOT staged
# either) and which V9's predicate correctly classifies as in-repo (its parent directory never
# resolves outside PROJECT_ROOT), so this fixture remains a true "genuine add failure" probe both
# before and after V9 lands. ---

repo_w4="$(build_repo_movable)"
mkdir -p "$repo_w4/specs/archive"
mv "$repo_w4/specs/999_probe" "$repo_w4/specs/archive/999_probe"
echo "secret" > "$repo_w4/specs/999_badperm.txt"
chmod 000 "$repo_w4/specs/999_badperm.txt"
before_w4=$(git -C "$repo_w4" rev-list --count HEAD)
out_w4="$(run_commit "$repo_w4" --message "W4 mixed failure" --session "sess_w4" \
  -- "specs/999_probe" "specs/archive/999_probe" "specs/999_badperm.txt" 2>&1)"
rc_w4=$?
after_w4=$(git -C "$repo_w4" rev-list --count HEAD 2>/dev/null || echo "$before_w4")
chmod 644 "$repo_w4/specs/999_badperm.txt" 2>/dev/null || true

if [ "$rc_w4" -eq 2 ] && [ "$after_w4" -eq "$before_w4" ] \
  && echo "$out_w4" | grep -q "ERROR:.*genuinely unstaged"; then
  common_test_pass "W4: a genuine add failure (in-repo, permission-denied) batched with a legitimate directory move still refuses -- exit 2, no commit (the fully-staged-deletion acceptance does not mask an unstaged path; this fixture is deliberately in-repo so it survives the V9 addition unchanged)"
else
  common_test_fail "W4: expected rc=2 and no new commit; got rc=$rc_w4 before=$before_w4 after=$after_w4 output=$out_w4"
fi

# =====================================================================
# T14-T18: out-of-repository pathspec containment. An absolute pathspec whose resolved parent
# directory lies outside PROJECT_ROOT exists on disk, so the pre-existing V2 Case 1 test
# (`[ -e "$p" ]`) matches it and admits it to the single all-or-nothing `git add` call, which then
# fails FATALLY for every path in that call -- not just the offending one. Verified empirically:
# `git add valid1.txt valid2.txt /outside/evidence.txt` exits 128 with "fatal: ... is outside
# repository" and stages NEITHER valid1.txt NOR valid2.txt. The fix under test classifies a
# positive pathspec as out-of-repository BEFORE Case 1 can claim it (by resolving the pathspec's
# PARENT directory, never its final component -- see T16 for why), drops it with a dedicated WARN,
# and lets the remaining valid paths commit normally with a new dedicated exit code.
#
# Every assertion below checks committed CONTENT via `git show --name-only`/`git log`, never exit
# code alone -- an exit-code-only assertion on T14 would pass unchanged against the pre-fix
# script wherever its exit code happens to coincide (see T18's content-vs-code distinction).
# =====================================================================

# --- T14 (core case): one absolute out-of-repository path mixed with three valid repo-relative
# paths. Pre-fix: Case 1 admits the outside path, `git add` fails for the whole call, none of the
# three valid files are staged, and the script exits 2 with a V7 "genuinely unstaged" ERROR naming
# all four paths -- this case must FAIL against the unmodified script. ---

mapfile -t t14_paths < <(build_repo_with_outside_tree)
repo_t14="${t14_paths[0]}"
outside_t14="${t14_paths[1]}"
echo "a" > "$repo_t14/specs/999_probe/a.txt"
echo "b" > "$repo_t14/specs/999_probe/b.txt"
echo "c" > "$repo_t14/specs/999_probe/c.txt"
before_t14=$(git -C "$repo_t14" rev-list --count HEAD)
out_t14="$(run_commit "$repo_t14" --message "T14 probe commit" --session "sess_t14" \
  -- "specs/999_probe/a.txt" "specs/999_probe/b.txt" "specs/999_probe/c.txt" "$outside_t14/evidence.txt" 2>&1)"
rc_t14=$?
after_t14=$(git -C "$repo_t14" rev-list --count HEAD 2>/dev/null || echo "$before_t14")
show_t14="$(git -C "$repo_t14" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_t14" -eq 6 ] && [ "$after_t14" -eq $((before_t14 + 1)) ] \
  && echo "$show_t14" | grep -qF "specs/999_probe/a.txt" \
  && echo "$show_t14" | grep -qF "specs/999_probe/b.txt" \
  && echo "$show_t14" | grep -qF "specs/999_probe/c.txt" \
  && echo "$out_t14" | grep -q "out-of-repository" \
  && echo "$out_t14" | grep -qF "evidence.txt"; then
  common_test_pass "T14: one out-of-repository absolute path mixed with three valid paths -- the three valid paths commit (verified via git show, not exit code alone), the offending path is named loudly as out-of-repository, exit 6"
else
  common_test_fail "T14: expected rc=6, HEAD+1, a.txt/b.txt/c.txt in HEAD, stderr naming evidence.txt as out-of-repository; got rc=$rc_t14 before=$before_t14 after=$after_t14 show='$show_t14' output=$out_t14"
fi

# --- T15 (ACCEPTANCE item 4): an ABSOLUTE path that resolves INSIDE the repository continues to
# commit exactly as today -- the fix must distinguish "absolute" from "outside the repository".
# Expected to PASS both before and after the fix (unchanged behavior). ---

repo_t15="$(build_repo covered)"
echo "in-repo absolute" > "$repo_t15/specs/999_probe/abs.txt"
before_t15=$(git -C "$repo_t15" rev-list --count HEAD)
out_t15="$(run_commit "$repo_t15" --message "T15 probe commit" --session "sess_t15" \
  -- "$repo_t15/specs/999_probe/abs.txt" 2>&1)"
rc_t15=$?
after_t15=$(git -C "$repo_t15" rev-list --count HEAD 2>/dev/null || echo "$before_t15")
show_t15="$(git -C "$repo_t15" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_t15" -eq 0 ] && [ "$after_t15" -eq $((before_t15 + 1)) ] \
  && echo "$show_t15" | grep -qF "specs/999_probe/abs.txt" \
  && ! echo "$out_t15" | grep -q "out-of-repository"; then
  common_test_pass "T15: an absolute path resolving INSIDE the repository still commits -- exit 0, HEAD+1, no out-of-repository drop WARN"
else
  common_test_fail "T15: expected rc=0, HEAD+1, abs.txt in HEAD, no out-of-repository WARN; got rc=$rc_t15 before=$before_t15 after=$after_t15 show='$show_t15' output=$out_t15"
fi

# --- T16 (the leaf-symlink dimension): an in-repo symlink whose TARGET lies outside the
# repository, named as a positive pathspec. `git add` legally stages this (verified empirically:
# exit 0, staged as a symlink blob) -- it is the pathspec's PARENT that must be resolved, never
# its final component. A leaf-resolving predicate would misclassify this as out-of-repository and
# drop a legal path; this case is what distinguishes the two.
#
# rc is NOT pinned to a single value: verified empirically (and reproducible with ANY committed
# symlink, in-repo or out-of-repo target alike, so this is pre-existing and orthogonal to this
# change) that the V8 post-commit integrity gate's intent snapshot uses `git hash-object`, which
# FOLLOWS a symlink and hashes the pointed-to file's content, while the blob git actually commits
# for a symlink is the target path STRING -- the two never match, so V8 unconditionally reports a
# false "present with different content" mismatch (exit 5) for every symlink this script commits.
# That gap is in V8's hash-object snapshot, not in the out-of-repository classification under
# test here, and fixing it is out of scope. What this case pins is narrower and unaffected by it:
# the symlink is NOT dropped as out-of-repository (no such WARN appears) and it DOES land in the
# commit (HEAD+1, present in `git show --name-only`) either way. ---

mapfile -t t16_paths < <(build_repo_with_outside_tree)
repo_t16="${t16_paths[0]}"
outside_t16="${t16_paths[1]}"
ln -s "$outside_t16/evidence.txt" "$repo_t16/specs/999_probe/leaflink"
before_t16=$(git -C "$repo_t16" rev-list --count HEAD)
out_t16="$(run_commit "$repo_t16" --message "T16 probe commit" --session "sess_t16" \
  -- "specs/999_probe/leaflink" 2>&1)"
rc_t16=$?
after_t16=$(git -C "$repo_t16" rev-list --count HEAD 2>/dev/null || echo "$before_t16")
show_t16="$(git -C "$repo_t16" show --name-only --format="" HEAD 2>/dev/null)"

if { [ "$rc_t16" -eq 0 ] || [ "$rc_t16" -eq 5 ]; } && [ "$after_t16" -eq $((before_t16 + 1)) ] \
  && echo "$show_t16" | grep -qF "specs/999_probe/leaflink" \
  && ! echo "$out_t16" | grep -q "out-of-repository"; then
  common_test_pass "T16: an in-repo leaf symlink whose target lies outside the repository still commits, NOT dropped as out-of-repository -- HEAD+1, symlink present in the commit (pins parent-only resolution, never the final component; rc may be 5 due to V8's pre-existing, orthogonal symlink hash-object false positive, not an out-of-repository drop)"
else
  common_test_fail "T16: expected rc 0 or 5, HEAD+1, leaflink in HEAD, no out-of-repository WARN; got rc=$rc_t16 before=$before_t16 after=$after_t16 show='$show_t16' output=$out_t16"
fi

# --- T17: a path THROUGH an in-repo symlinked directory whose target lies outside the
# repository. Bare `git add` rejects this with "fatal: pathspec ... is beyond a symbolic link"
# (verified empirically, rc=128) -- today that fatal error aborts the whole `git add` call exactly
# like T14's plain out-of-repo path. Post-fix this is classified and dropped as out-of-repository
# (its resolved PARENT lies outside the root) rather than aborting the call; a valid sibling path
# in the same call still commits. Must FAIL against the unmodified script. ---

repo_t17="$(build_repo covered)"
outside_t17="$(mktemp -d -p "$TOP_WORKDIR")"
echo "through-symlink target" > "$outside_t17/target.txt"
ln -s "$outside_t17" "$repo_t17/specs/999_probe/dirsym"
echo "sibling" > "$repo_t17/specs/999_probe/sibling.txt"
before_t17=$(git -C "$repo_t17" rev-list --count HEAD)
out_t17="$(run_commit "$repo_t17" --message "T17 probe commit" --session "sess_t17" \
  -- "specs/999_probe/sibling.txt" "specs/999_probe/dirsym/target.txt" 2>&1)"
rc_t17=$?
after_t17=$(git -C "$repo_t17" rev-list --count HEAD 2>/dev/null || echo "$before_t17")
show_t17="$(git -C "$repo_t17" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_t17" -eq 6 ] && [ "$after_t17" -eq $((before_t17 + 1)) ] \
  && echo "$show_t17" | grep -qF "specs/999_probe/sibling.txt" \
  && echo "$out_t17" | grep -q "out-of-repository"; then
  common_test_pass "T17: a path THROUGH an in-repo symlinked directory pointing outside the repository is dropped as out-of-repository rather than aborting the call -- exit 6, HEAD+1, the valid sibling path committed"
else
  common_test_fail "T17: expected rc=6, HEAD+1, sibling.txt in HEAD, stderr naming out-of-repository; got rc=$rc_t17 before=$before_t17 after=$after_t17 show='$show_t17' output=$out_t17"
fi

# --- T18 (the degenerate case): EVERY positive pathspec is out-of-repository (two real,
# existing, absolute paths outside the repo, no valid path at all). Both pathspecs must actually
# EXIST on disk so Case 1 admits them pre-fix (a nonexistent out-of-repo path would already hit
# Case 3's unrelated "unmatched" drop today, making this case pass vacuously). Post-fix, V9 drops
# both before Case 1 ever sees them, filtered_pathspecs ends up empty, and the EXISTING V3
# post-filter refusal fires -- exit 2, no git add attempted, no commit, matching T11's precedent
# for the all-dropped shape. Asserted on the V3 message TEXT, not just the exit code: pre-fix this
# same rc=2 is reached via the DIFFERENT V7 "genuinely unstaged" path (git add is attempted and
# fails), so an exit-code-only assertion would pass vacuously; the V3 message only appears once V9
# removes both pathspecs before git add is ever invoked. ---

outside_t18="$(mktemp -d -p "$TOP_WORKDIR")"
echo "one" > "$outside_t18/one.txt"
echo "two" > "$outside_t18/two.txt"
repo_t18="$(build_repo covered)"
before_t18=$(git -C "$repo_t18" rev-list --count HEAD)
out_t18="$(run_commit "$repo_t18" --message "T18 probe commit" --session "sess_t18" \
  -- "$outside_t18/one.txt" "$outside_t18/two.txt" 2>&1)"
rc_t18=$?
after_t18=$(git -C "$repo_t18" rev-list --count HEAD 2>/dev/null || echo "$before_t18")

if [ "$rc_t18" -eq 2 ] && [ "$after_t18" -eq "$before_t18" ] \
  && echo "$out_t18" | grep -q "zero positive pathspec entries remain"; then
  common_test_pass "T18: every positive pathspec out-of-repository hits the existing V3 all-dropped refusal (not a second refusal path) -- exit 2, no commit, V3's own message, matching T11's all-dropped precedent"
else
  common_test_fail "T18: expected rc=2, no new commit, V3 message 'zero positive pathspec entries remain'; got rc=$rc_t18 before=$before_t18 after=$after_t18 output=$out_t18"
fi

# task-ref-ok:begin category 6-adjacent: every "--task 999" literal in the Z1-Z10 block below is
# synthetic fixture data exercising git-commit-scoped.sh's OWN --task input (an arbitrary integer
# identifying the committing project for the file_scope-Containment check), mirroring the
# already-exempted V1-V8 block's own 401/402 fixture numbers above -- never a citation of this
# repo's own ephemeral task tracker.
# =====================================================================
# Z1-Z10: the V10 file_scope-Containment chokepoint. Every case uses build_repo_with_scope, which
# reuses build_repo's own "specs/999_probe" fixture directory under project_number 999 /
# project_name "probe" -- the implicit task-directory scope member this relies on resolves
# correctly for exactly that reason (the directory already exists on disk). As with T14-T18
# above, every assertion checks committed CONTENT via `git show --name-only`/`git log` (or, for
# the refusal cases, the ABSENCE of a new commit), never exit code alone.
# =====================================================================

# --- Z1: --task given, but no specs/state.json at all -- fail-open, commit unchanged. ---

repo_z1="$(build_repo covered)"
echo "line2" >> "$repo_z1/specs/999_probe/file.txt"
before_z1=$(git -C "$repo_z1" rev-list --count HEAD)
out_z1="$(run_commit "$repo_z1" --message "Z1 probe commit" --session "sess_z1" --task 999 \
  -- "specs/999_probe/file.txt" 2>&1)"
rc_z1=$?
after_z1=$(git -C "$repo_z1" rev-list --count HEAD 2>/dev/null || echo "$before_z1")
show_z1="$(git -C "$repo_z1" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_z1" -eq 0 ] && [ "$after_z1" -eq $((before_z1 + 1)) ] \
  && echo "$show_z1" | grep -qF "specs/999_probe/file.txt" \
  && ! echo "$out_z1" | grep -q "out-of-scope"; then
  common_test_pass "Z1: --task given but no specs/state.json at all -- fails open, commit lands unchanged"
else
  common_test_fail "Z1: expected rc=0, HEAD+1, file.txt in HEAD, no out-of-scope WARN; got rc=$rc_z1 before=$before_z1 after=$after_z1 show='$show_z1' output=$out_z1"
fi

# --- Z2: a state.json entry IS found for the dispatching project, but its file_scope is absent,
# "[]", a non-array string, or an array with a non-string member -- all four shapes fail open
# identically (containment_scope_arr stays empty, so no path is ever dropped). ---

z2_all_ok=true
z2_detail=""
for z2_shape_name in "absent" "empty-array" "non-array-string" "non-string-member"; do
  case "$z2_shape_name" in
    absent) z2_scope_arg="" ;;
    empty-array) z2_scope_arg="[]" ;;
    non-array-string) z2_scope_arg='"oops-not-an-array"' ;;
    non-string-member) z2_scope_arg="[123]" ;;
  esac

  repo_z2="$(build_repo_with_scope 999 probe "$z2_scope_arg")"
  echo "modified a" > "$repo_z2/specs/999_probe/a.txt"
  echo "modified b" > "$repo_z2/specs/999_probe/b.txt"
  before_z2=$(git -C "$repo_z2" rev-list --count HEAD)
  out_z2="$(run_commit "$repo_z2" --message "Z2 probe commit ($z2_shape_name)" --session "sess_z2" --task 999 \
    -- "specs/999_probe/a.txt" "specs/999_probe/b.txt" 2>&1)"
  rc_z2=$?
  after_z2=$(git -C "$repo_z2" rev-list --count HEAD 2>/dev/null || echo "$before_z2")
  show_z2="$(git -C "$repo_z2" show --name-only --format="" HEAD 2>/dev/null)"

  if ! { [ "$rc_z2" -eq 0 ] && [ "$after_z2" -eq $((before_z2 + 1)) ] \
    && echo "$show_z2" | grep -qF "specs/999_probe/a.txt" \
    && echo "$show_z2" | grep -qF "specs/999_probe/b.txt" \
    && ! echo "$out_z2" | grep -q "out-of-scope"; }; then
    z2_all_ok=false
    z2_detail="${z2_detail} [shape=$z2_shape_name rc=$rc_z2 before=$before_z2 after=$after_z2 show='$show_z2' output=$out_z2]"
  fi
done

if [ "$z2_all_ok" = "true" ]; then
  common_test_pass "Z2: a file_scope that is absent, [], a non-array string, or an array with a non-string member all fail open -- every shape commits both paths unchanged"
else
  common_test_fail "Z2: at least one malformed file_scope shape did not fail open --$z2_detail"
fi

# --- Z3: partial drop with a committable survivor -- exit 7, WARN names the dropped path,
# the in-scope path lands. The out-of-scope candidate is specs/998_sibling/out.txt (a SIBLING
# task directory, never specs/999_probe/b.txt): b.txt lives under the dispatching task's OWN
# directory, which is an unconditional implicit scope member by design (see
# build_repo_with_scope's own header comment), so it can never be the dropped path here. ---

repo_z3="$(build_repo_with_scope 999 probe '["specs/999_probe/a.txt"]')"
echo "modified a" > "$repo_z3/specs/999_probe/a.txt"
echo "modified out" > "$repo_z3/specs/998_sibling/out.txt"
before_z3=$(git -C "$repo_z3" rev-list --count HEAD)
out_z3="$(run_commit "$repo_z3" --message "Z3 probe commit" --session "sess_z3" --task 999 \
  -- "specs/999_probe/a.txt" "specs/998_sibling/out.txt" 2>&1)"
rc_z3=$?
after_z3=$(git -C "$repo_z3" rev-list --count HEAD 2>/dev/null || echo "$before_z3")
show_z3="$(git -C "$repo_z3" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_z3" -eq 7 ] && [ "$after_z3" -eq $((before_z3 + 1)) ] \
  && echo "$show_z3" | grep -qF "specs/999_probe/a.txt" \
  && ! echo "$show_z3" | grep -qF "specs/998_sibling/out.txt" \
  && echo "$out_z3" | grep -q "out-of-scope" \
  && echo "$out_z3" | grep -qF "specs/998_sibling/out.txt"; then
  common_test_pass "Z3: partial Containment drop with a committable survivor -- a.txt lands, out.txt dropped with a named out-of-scope WARN, exit 7"
else
  common_test_fail "Z3: expected rc=7, HEAD+1, a.txt in HEAD, out.txt absent, WARN naming out.txt; got rc=$rc_z3 before=$before_z3 after=$after_z3 show='$show_z3' output=$out_z3"
fi

# --- Z4: every positive pathspec out of scope -- exit 2 (V3's existing all-dropped refusal),
# nothing staged, matching T11/T18's precedent for the all-dropped shape. ---

repo_z4="$(build_repo_with_scope 999 probe '["specs/999_probe/a.txt"]')"
echo "modified out" > "$repo_z4/specs/998_sibling/out.txt"
before_z4=$(git -C "$repo_z4" rev-list --count HEAD)
out_z4="$(run_commit "$repo_z4" --message "Z4 probe commit" --session "sess_z4" --task 999 \
  -- "specs/998_sibling/out.txt" 2>&1)"
rc_z4=$?
after_z4=$(git -C "$repo_z4" rev-list --count HEAD 2>/dev/null || echo "$before_z4")

if [ "$rc_z4" -eq 2 ] && [ "$after_z4" -eq "$before_z4" ] \
  && echo "$out_z4" | grep -q "zero positive pathspec entries remain"; then
  common_test_pass "Z4: every positive pathspec out of scope hits the existing V3 all-dropped refusal -- exit 2, no commit"
else
  common_test_fail "Z4: expected rc=2, no new commit, V3 message; got rc=$rc_z4 before=$before_z4 after=$after_z4 output=$out_z4"
fi

# --- Z5: a Containment drop whose surviving pathspec carries no diff -- exit 4 (V6's existing
# ambiguous-no-commit refusal), not the generic "nothing to commit" NOTE. ---

repo_z5="$(build_repo_with_scope 999 probe '["specs/999_probe/a.txt"]')"
echo "modified out" > "$repo_z5/specs/998_sibling/out.txt"
# a.txt is left at its baseline (no diff) -- only out.txt is dirtied.
before_z5=$(git -C "$repo_z5" rev-list --count HEAD)
out_z5="$(run_commit "$repo_z5" --message "Z5 probe commit" --session "sess_z5" --task 999 \
  -- "specs/999_probe/a.txt" "specs/998_sibling/out.txt" 2>&1)"
rc_z5=$?
after_z5=$(git -C "$repo_z5" rev-list --count HEAD 2>/dev/null || echo "$before_z5")

if [ "$rc_z5" -eq 4 ] && [ "$after_z5" -eq "$before_z5" ] \
  && echo "$out_z5" | grep -q "Verified Finding V6" \
  && echo "$out_z5" | grep -qF "specs/998_sibling/out.txt"; then
  common_test_pass "Z5: a Containment drop whose surviving pathspec carries no diff -- exit 4 (V6), naming the dropped path, not the generic nothing-to-commit NOTE"
else
  common_test_fail "Z5: expected rc=4, no new commit, V6 message naming out.txt; got rc=$rc_z5 before=$before_z5 after=$after_z5 output=$out_z5"
fi

# --- Z6: the live per-cycle postflight pathspec shape -- absolute TASK_DIR/, absolute
# specs/TODO.md, absolute specs/state.json, plus a relative in-scope source path outside the task
# directory entirely. Everything lands, nothing is dropped, exit 0. ---

repo_z6="$(build_repo_with_scope 999 probe '["specs/999_probe/a.txt","lib/widget.txt"]')"
mkdir -p "$repo_z6/lib"
echo "widget" > "$repo_z6/lib/widget.txt"
echo "modified a" > "$repo_z6/specs/999_probe/a.txt"
echo "- probe task" > "$repo_z6/specs/TODO.md"
before_z6=$(git -C "$repo_z6" rev-list --count HEAD)
out_z6="$(run_commit "$repo_z6" --message "Z6 probe commit" --session "sess_z6" --task 999 \
  -- "$repo_z6/specs/999_probe/" "$repo_z6/specs/TODO.md" "$repo_z6/specs/state.json" "lib/widget.txt" 2>&1)"
rc_z6=$?
after_z6=$(git -C "$repo_z6" rev-list --count HEAD 2>/dev/null || echo "$before_z6")
show_z6="$(git -C "$repo_z6" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_z6" -eq 0 ] && [ "$after_z6" -eq $((before_z6 + 1)) ] \
  && echo "$show_z6" | grep -qF "specs/999_probe/a.txt" \
  && echo "$show_z6" | grep -qF "specs/TODO.md" \
  && echo "$show_z6" | grep -qF "lib/widget.txt" \
  && ! echo "$out_z6" | grep -q "out-of-scope"; then
  common_test_pass "Z6: the live postflight pathspec shape (absolute TASK_DIR/, absolute specs/TODO.md, absolute specs/state.json, plus a relative in-scope source path) commits with zero Containment drops -- exit 0"
else
  common_test_fail "Z6: expected rc=0, HEAD+1, a.txt/TODO.md/widget.txt all in HEAD, no out-of-scope WARN; got rc=$rc_z6 before=$before_z6 after=$after_z6 show='$show_z6' output=$out_z6"
fi

# --- Z7: trailing-slash asymmetry, both directions. (a) file_scope declares a directory WITHOUT
# a trailing slash; the pathspec passed is the same directory WITH one. (b) file_scope declares a
# directory WITH a trailing slash; the pathspec passed is the same directory WITHOUT one. Both
# must be contained -- is_contained_v10 strips at most one trailing slash from both sides. ---

repo_z7="$(build_repo_with_scope 999 probe '["specs/999_probe/subdir-a","specs/999_probe/subdir-b/"]')"
mkdir -p "$repo_z7/specs/999_probe/subdir-a" "$repo_z7/specs/999_probe/subdir-b"
echo "new" > "$repo_z7/specs/999_probe/subdir-a/new.txt"
echo "new" > "$repo_z7/specs/999_probe/subdir-b/new.txt"
before_z7=$(git -C "$repo_z7" rev-list --count HEAD)
out_z7="$(run_commit "$repo_z7" --message "Z7 probe commit" --session "sess_z7" --task 999 \
  -- "specs/999_probe/subdir-a/" "specs/999_probe/subdir-b" 2>&1)"
rc_z7=$?
after_z7=$(git -C "$repo_z7" rev-list --count HEAD 2>/dev/null || echo "$before_z7")
show_z7="$(git -C "$repo_z7" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_z7" -eq 0 ] && [ "$after_z7" -eq $((before_z7 + 1)) ] \
  && echo "$show_z7" | grep -qF "specs/999_probe/subdir-a/new.txt" \
  && echo "$show_z7" | grep -qF "specs/999_probe/subdir-b/new.txt" \
  && ! echo "$out_z7" | grep -q "out-of-scope"; then
  common_test_pass "Z7: a directory pathspec with a trailing slash matching a file_scope entry without one (and the converse) are both contained -- exit 0, both land"
else
  common_test_fail "Z7: expected rc=0, HEAD+1, both subdir-a/new.txt and subdir-b/new.txt in HEAD, no out-of-scope WARN; got rc=$rc_z7 before=$before_z7 after=$after_z7 show='$show_z7' output=$out_z7"
fi

# --- Z8: a path outside file_scope but under a derived_artifact_probes-declared
# derived_output_dirs prefix in .claude-extensions.json is NOT dropped -- the SAME widening
# orchestrate-cycle-postflight.sh's own WORK (h) filter already applies one layer above this
# script must not be silently reversed here. ---

repo_z8="$(build_repo_with_scope 999 probe '["specs/999_probe/a.txt"]')"
cat > "$repo_z8/.claude-extensions.json" <<'EXT_EOF'
{
  "derived_artifact_probes": [
    {
      "component": "generated-docs",
      "check_command": "true",
      "derived_output_dirs": ["build/generated"]
    }
  ]
}
EXT_EOF
mkdir -p "$repo_z8/build/generated"
echo "generated output" > "$repo_z8/build/generated/output.md"
echo "modified a" > "$repo_z8/specs/999_probe/a.txt"
before_z8=$(git -C "$repo_z8" rev-list --count HEAD)
out_z8="$(run_commit "$repo_z8" --message "Z8 probe commit" --session "sess_z8" --task 999 \
  -- "specs/999_probe/a.txt" "build/generated/output.md" 2>&1)"
rc_z8=$?
after_z8=$(git -C "$repo_z8" rev-list --count HEAD 2>/dev/null || echo "$before_z8")
show_z8="$(git -C "$repo_z8" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_z8" -eq 0 ] && [ "$after_z8" -eq $((before_z8 + 1)) ] \
  && echo "$show_z8" | grep -qF "specs/999_probe/a.txt" \
  && echo "$show_z8" | grep -qF "build/generated/output.md" \
  && ! echo "$out_z8" | grep -q "out-of-scope"; then
  common_test_pass "Z8: a path under a declared derived_output_dirs prefix, but outside file_scope, is NOT dropped -- exit 0, both land"
else
  common_test_fail "Z8: expected rc=0, HEAD+1, a.txt/output.md both in HEAD, no out-of-scope WARN; got rc=$rc_z8 before=$before_z8 after=$after_z8 show='$show_z8' output=$out_z8"
fi

# --- Z9: --task omitted entirely -- no Containment check at all, even with a declared
# file_scope present in specs/state.json. Both the in-scope and out-of-scope paths land. ---

repo_z9="$(build_repo_with_scope 999 probe '["specs/999_probe/a.txt"]')"
echo "modified a" > "$repo_z9/specs/999_probe/a.txt"
echo "modified b" > "$repo_z9/specs/999_probe/b.txt"
before_z9=$(git -C "$repo_z9" rev-list --count HEAD)
out_z9="$(run_commit "$repo_z9" --message "Z9 probe commit" --session "sess_z9" \
  -- "specs/999_probe/a.txt" "specs/999_probe/b.txt" 2>&1)"
rc_z9=$?
after_z9=$(git -C "$repo_z9" rev-list --count HEAD 2>/dev/null || echo "$before_z9")
show_z9="$(git -C "$repo_z9" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_z9" -eq 0 ] && [ "$after_z9" -eq $((before_z9 + 1)) ] \
  && echo "$show_z9" | grep -qF "specs/999_probe/a.txt" \
  && echo "$show_z9" | grep -qF "specs/999_probe/b.txt" \
  && ! echo "$out_z9" | grep -q "out-of-scope"; then
  common_test_pass "Z9: --task omitted entirely -- no Containment check runs at all, even with a declared file_scope present; both paths land"
else
  common_test_fail "Z9: expected rc=0, HEAD+1, both a.txt and b.txt in HEAD, no out-of-scope WARN; got rc=$rc_z9 before=$before_z9 after=$after_z9 show='$show_z9' output=$out_z9"
fi

# --- Z10: the drop WARN still appears, and the commit still lands, when issue-record.sh is
# entirely absent from the scratch repo (non-fatality proof) -- confirms the issue-record.sh call
# inside the V10 branch tolerates the script being absent, matching git-commit-phase.sh's own
# non-fatal recording idiom. issue-record.sh is never copied into any scratch repo in this suite
# (it is absent from REQUIRED_SCRIPTS by design), so this additionally asserts that precondition
# explicitly rather than relying on it silently. ---

repo_z10="$(build_repo_with_scope 999 probe '["specs/999_probe/a.txt"]')"
echo "modified a" > "$repo_z10/specs/999_probe/a.txt"
echo "modified out" > "$repo_z10/specs/998_sibling/out.txt"
if [ -e "$repo_z10/.claude/scripts/issue-record.sh" ]; then
  common_test_fail "Z10: precondition violated -- issue-record.sh unexpectedly present in the scratch repo"
else
  before_z10=$(git -C "$repo_z10" rev-list --count HEAD)
  out_z10="$(run_commit "$repo_z10" --message "Z10 probe commit" --session "sess_z10" --task 999 \
    -- "specs/999_probe/a.txt" "specs/998_sibling/out.txt" 2>&1)"
  rc_z10=$?
  after_z10=$(git -C "$repo_z10" rev-list --count HEAD 2>/dev/null || echo "$before_z10")
  show_z10="$(git -C "$repo_z10" show --name-only --format="" HEAD 2>/dev/null)"

  if [ "$rc_z10" -eq 7 ] && [ "$after_z10" -eq $((before_z10 + 1)) ] \
    && echo "$show_z10" | grep -qF "specs/999_probe/a.txt" \
    && echo "$out_z10" | grep -q "out-of-scope"; then
    common_test_pass "Z10: the drop WARN still appears and the commit still lands when issue-record.sh is entirely absent -- non-fatality proof"
  else
    common_test_fail "Z10: expected rc=7, HEAD+1, a.txt in HEAD, WARN naming the drop; got rc=$rc_z10 before=$before_z10 after=$after_z10 show='$show_z10' output=$out_z10"
  fi
fi

# The Z11-Z14 block below reuses the same synthetic fixture task identifier as the Z1-Z10 block
# above, under the file-wide marker pair already in force for this file.
# =====================================================================
# Z11-Z14: deep-glob "/**" containment coverage, added to prove the fix for the quoted-entry
# bug that made a "/**"-suffixed file_scope entry never contain any path. Each case uses a base
# directory (lib/widget-area/) entirely OUTSIDE the implicit task-directory scope member
# (specs/999_probe/), so the containment under test is the "/**" entry's own deep-glob prefix
# match and nothing else.
# =====================================================================

# --- Z11: a "/**"-suffixed file_scope entry contains a DIRECT CHILD of its base directory. ---

repo_z11="$(build_repo_with_scope 999 probe '["lib/widget-area/**"]')"
mkdir -p "$repo_z11/lib/widget-area"
echo "direct child" > "$repo_z11/lib/widget-area/direct.txt"
before_z11=$(git -C "$repo_z11" rev-list --count HEAD)
out_z11="$(run_commit "$repo_z11" --message "Z11 probe commit" --session "sess_z11" --task 999 \
  -- "lib/widget-area/direct.txt" 2>&1)"
rc_z11=$?
after_z11=$(git -C "$repo_z11" rev-list --count HEAD 2>/dev/null || echo "$before_z11")
show_z11="$(git -C "$repo_z11" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_z11" -eq 0 ] && [ "$after_z11" -eq $((before_z11 + 1)) ] \
  && echo "$show_z11" | grep -qF "lib/widget-area/direct.txt" \
  && ! echo "$out_z11" | grep -q "out-of-scope"; then
  common_test_pass "Z11: a \"/**\"-suffixed file_scope entry contains a direct child -- exit 0, lands, no out-of-scope WARN"
else
  common_test_fail "Z11: expected rc=0, HEAD+1, direct.txt in HEAD, no out-of-scope WARN; got rc=$rc_z11 before=$before_z11 after=$after_z11 show='$show_z11' output=$out_z11"
fi

# --- Z12: the same "/**" entry contains a DEEPLY NESTED descendant, at least two directory
# levels below the base -- proves the containment is depth-independent, not limited to direct
# children. ---

repo_z12="$(build_repo_with_scope 999 probe '["lib/widget-area/**"]')"
mkdir -p "$repo_z12/lib/widget-area/deep/deeper"
echo "deep descendant" > "$repo_z12/lib/widget-area/deep/deeper/nested.txt"
before_z12=$(git -C "$repo_z12" rev-list --count HEAD)
out_z12="$(run_commit "$repo_z12" --message "Z12 probe commit" --session "sess_z12" --task 999 \
  -- "lib/widget-area/deep/deeper/nested.txt" 2>&1)"
rc_z12=$?
after_z12=$(git -C "$repo_z12" rev-list --count HEAD 2>/dev/null || echo "$before_z12")
show_z12="$(git -C "$repo_z12" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_z12" -eq 0 ] && [ "$after_z12" -eq $((before_z12 + 1)) ] \
  && echo "$show_z12" | grep -qF "lib/widget-area/deep/deeper/nested.txt" \
  && ! echo "$out_z12" | grep -q "out-of-scope"; then
  common_test_pass "Z12: a \"/**\"-suffixed file_scope entry contains a deeply nested descendant (two levels down) -- exit 0, lands, no out-of-scope WARN"
else
  common_test_fail "Z12: expected rc=0, HEAD+1, nested.txt in HEAD, no out-of-scope WARN; got rc=$rc_z12 before=$before_z12 after=$after_z12 show='$show_z12' output=$out_z12"
fi

# --- Z13: the same "/**" entry does NOT contain a SAME-PREFIX SIBLING -- a path that shares the
# base's text but not its "/" boundary (lib/widget-area-sibling/ vs lib/widget-area/). This is
# the non-widening proof the task scope explicitly demands: partial drop with a committable
# survivor -- exit 7, WARN names the sibling, the in-scope descendant still lands. ---

repo_z13="$(build_repo_with_scope 999 probe '["lib/widget-area/**"]')"
mkdir -p "$repo_z13/lib/widget-area" "$repo_z13/lib/widget-area-sibling"
echo "in scope" > "$repo_z13/lib/widget-area/direct.txt"
echo "same-prefix sibling, out of scope" > "$repo_z13/lib/widget-area-sibling/x.txt"
before_z13=$(git -C "$repo_z13" rev-list --count HEAD)
out_z13="$(run_commit "$repo_z13" --message "Z13 probe commit" --session "sess_z13" --task 999 \
  -- "lib/widget-area/direct.txt" "lib/widget-area-sibling/x.txt" 2>&1)"
rc_z13=$?
after_z13=$(git -C "$repo_z13" rev-list --count HEAD 2>/dev/null || echo "$before_z13")
show_z13="$(git -C "$repo_z13" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_z13" -eq 7 ] && [ "$after_z13" -eq $((before_z13 + 1)) ] \
  && echo "$show_z13" | grep -qF "lib/widget-area/direct.txt" \
  && ! echo "$show_z13" | grep -qF "lib/widget-area-sibling/x.txt" \
  && echo "$out_z13" | grep -q "out-of-scope" \
  && echo "$out_z13" | grep -qF "lib/widget-area-sibling/x.txt"; then
  common_test_pass "Z13: a \"/**\"-suffixed file_scope entry does NOT contain a same-prefix sibling outside its \"/\" boundary -- sibling dropped with a named out-of-scope WARN (exit 7), in-scope descendant still lands (the non-widening proof)"
else
  common_test_fail "Z13: expected rc=7, HEAD+1, direct.txt in HEAD, x.txt absent, WARN naming x.txt; got rc=$rc_z13 before=$before_z13 after=$after_z13 show='$show_z13' output=$out_z13"
fi

# --- Z14: a "/**" entry alongside a plain non-glob entry in the SAME file_scope -- the
# non-glob entry's exact-match behaviour is unchanged by the new branch. ---

repo_z14="$(build_repo_with_scope 999 probe '["lib/widget-area/**","specs/999_probe/a.txt"]')"
mkdir -p "$repo_z14/lib/widget-area"
echo "direct child" > "$repo_z14/lib/widget-area/direct.txt"
echo "modified a" > "$repo_z14/specs/999_probe/a.txt"
before_z14=$(git -C "$repo_z14" rev-list --count HEAD)
out_z14="$(run_commit "$repo_z14" --message "Z14 probe commit" --session "sess_z14" --task 999 \
  -- "lib/widget-area/direct.txt" "specs/999_probe/a.txt" 2>&1)"
rc_z14=$?
after_z14=$(git -C "$repo_z14" rev-list --count HEAD 2>/dev/null || echo "$before_z14")
show_z14="$(git -C "$repo_z14" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_z14" -eq 0 ] && [ "$after_z14" -eq $((before_z14 + 1)) ] \
  && echo "$show_z14" | grep -qF "lib/widget-area/direct.txt" \
  && echo "$show_z14" | grep -qF "specs/999_probe/a.txt" \
  && ! echo "$out_z14" | grep -q "out-of-scope"; then
  common_test_pass "Z14: a \"/**\" entry alongside a plain non-glob entry -- both the deep-glob descendant and the exact-match entry land unchanged, exit 0"
else
  common_test_fail "Z14: expected rc=0, HEAD+1, direct.txt and a.txt both in HEAD, no out-of-scope WARN; got rc=$rc_z14 before=$before_z14 after=$after_z14 show='$show_z14' output=$out_z14"
fi

# =====================================================================
# Z15-Z18: the shared engine-written-state-paths-lib.sh widening of containment_scope_arr.
# None of these fixtures declares specs/events.jsonl or specs/errors.json in its own
# file_scope -- admission comes entirely from the shared library's four-member set, not from
# the declared scope.
# =====================================================================

# --- Z15 (positive): a tracked, dirtied specs/events.jsonl named directly in the pathspec
# alongside an in-scope source path -- commits with rc 0, zero Containment drops,
# specs/events.jsonl present in HEAD. ---

repo_z15="$(build_repo_with_scope 999 probe '["specs/999_probe/a.txt"]')"
echo "baseline event" > "$repo_z15/specs/events.jsonl"
git -C "$repo_z15" add specs/events.jsonl
git -C "$repo_z15" commit -q -m "add baseline specs/events.jsonl"
echo "modified a" > "$repo_z15/specs/999_probe/a.txt"
echo "appended event" >> "$repo_z15/specs/events.jsonl"
before_z15=$(git -C "$repo_z15" rev-list --count HEAD)
out_z15="$(run_commit "$repo_z15" --message "Z15 probe commit" --session "sess_z15" --task 999 \
  -- "specs/999_probe/a.txt" "specs/events.jsonl" 2>&1)"
rc_z15=$?
after_z15=$(git -C "$repo_z15" rev-list --count HEAD 2>/dev/null || echo "$before_z15")
show_z15="$(git -C "$repo_z15" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_z15" -eq 0 ] && [ "$after_z15" -eq $((before_z15 + 1)) ] \
  && echo "$show_z15" | grep -qF "specs/999_probe/a.txt" \
  && echo "$show_z15" | grep -qF "specs/events.jsonl" \
  && ! echo "$out_z15" | grep -q "out-of-scope"; then
  common_test_pass "Z15: specs/events.jsonl is admitted via the shared engine-written-state-paths-lib.sh widening, undeclared in file_scope -- exit 0, no Containment drop, present in HEAD"
else
  common_test_fail "Z15: expected rc=0, HEAD+1, a.txt and events.jsonl both in HEAD, no out-of-scope WARN; got rc=$rc_z15 before=$before_z15 after=$after_z15 show='$show_z15' output=$out_z15"
fi

# --- Z16 (positive): the same shape for specs/errors.json. ---

repo_z16="$(build_repo_with_scope 999 probe '["specs/999_probe/a.txt"]')"
echo '{"errors":[]}' > "$repo_z16/specs/errors.json"
git -C "$repo_z16" add specs/errors.json
git -C "$repo_z16" commit -q -m "add baseline specs/errors.json"
echo "modified a" > "$repo_z16/specs/999_probe/a.txt"
echo '{"errors":[{"id":1}]}' > "$repo_z16/specs/errors.json"
before_z16=$(git -C "$repo_z16" rev-list --count HEAD)
out_z16="$(run_commit "$repo_z16" --message "Z16 probe commit" --session "sess_z16" --task 999 \
  -- "specs/999_probe/a.txt" "specs/errors.json" 2>&1)"
rc_z16=$?
after_z16=$(git -C "$repo_z16" rev-list --count HEAD 2>/dev/null || echo "$before_z16")
show_z16="$(git -C "$repo_z16" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_z16" -eq 0 ] && [ "$after_z16" -eq $((before_z16 + 1)) ] \
  && echo "$show_z16" | grep -qF "specs/999_probe/a.txt" \
  && echo "$show_z16" | grep -qF "specs/errors.json" \
  && ! echo "$out_z16" | grep -q "out-of-scope"; then
  common_test_pass "Z16: specs/errors.json is admitted via the shared engine-written-state-paths-lib.sh widening, undeclared in file_scope -- exit 0, no Containment drop, present in HEAD"
else
  common_test_fail "Z16: expected rc=0, HEAD+1, a.txt and errors.json both in HEAD, no out-of-scope WARN; got rc=$rc_z16 before=$before_z16 after=$after_z16 show='$show_z16' output=$out_z16"
fi

# --- Z17 (paired negative, the non-regression guard): in the SAME fixture shape, a genuinely
# out-of-scope path (specs/998_sibling/out.txt) alongside the admitted specs/events.jsonl --
# the commit lands, events.jsonl is in HEAD, out.txt is NOT, the drop WARN names it, and the
# exit code is the same partial-drop code Z3 already asserts (7). This is the proof the
# admission is not a blanket pass. ---

repo_z17="$(build_repo_with_scope 999 probe '["specs/999_probe/a.txt"]')"
echo "baseline event" > "$repo_z17/specs/events.jsonl"
git -C "$repo_z17" add specs/events.jsonl
git -C "$repo_z17" commit -q -m "add baseline specs/events.jsonl"
echo "appended event" >> "$repo_z17/specs/events.jsonl"
echo "modified out" > "$repo_z17/specs/998_sibling/out.txt"
before_z17=$(git -C "$repo_z17" rev-list --count HEAD)
out_z17="$(run_commit "$repo_z17" --message "Z17 probe commit" --session "sess_z17" --task 999 \
  -- "specs/events.jsonl" "specs/998_sibling/out.txt" 2>&1)"
rc_z17=$?
after_z17=$(git -C "$repo_z17" rev-list --count HEAD 2>/dev/null || echo "$before_z17")
show_z17="$(git -C "$repo_z17" show --name-only --format="" HEAD 2>/dev/null)"

if [ "$rc_z17" -eq 7 ] && [ "$after_z17" -eq $((before_z17 + 1)) ] \
  && echo "$show_z17" | grep -qF "specs/events.jsonl" \
  && ! echo "$show_z17" | grep -qF "specs/998_sibling/out.txt" \
  && echo "$out_z17" | grep -q "out-of-scope" \
  && echo "$out_z17" | grep -qF "specs/998_sibling/out.txt"; then
  common_test_pass "Z17: specs/events.jsonl is admitted while a genuinely out-of-scope sibling path is STILL dropped and warned exactly as today -- non-regression proof, exit 7"
else
  common_test_fail "Z17: expected rc=7, HEAD+1, events.jsonl in HEAD, out.txt absent, WARN naming out.txt; got rc=$rc_z17 before=$before_z17 after=$after_z17 show='$show_z17' output=$out_z17"
fi

# --- Z18 (fallback): with lib/engine-written-state-paths-lib.sh made unsourceable in the
# fixture repo (removed after build, the same "absent" technique Z10 uses for
# issue-record.sh), specs/TODO.md is still admitted and still committed -- pinning Decision 2's
# fallback: a source failure reproduces today's behavior exactly, never a narrower scope. ---

repo_z18="$(build_repo_with_scope 999 probe '["specs/999_probe/a.txt"]')"
rm -f "$repo_z18/.claude/scripts/lib/engine-written-state-paths-lib.sh"
echo "modified a" > "$repo_z18/specs/999_probe/a.txt"
echo "- probe task" > "$repo_z18/specs/TODO.md"
if [ -e "$repo_z18/.claude/scripts/lib/engine-written-state-paths-lib.sh" ]; then
  common_test_fail "Z18: precondition violated -- engine-written-state-paths-lib.sh unexpectedly still present in the scratch repo"
else
  before_z18=$(git -C "$repo_z18" rev-list --count HEAD)
  out_z18="$(run_commit "$repo_z18" --message "Z18 probe commit" --session "sess_z18" --task 999 \
    -- "specs/999_probe/a.txt" "specs/TODO.md" 2>&1)"
  rc_z18=$?
  after_z18=$(git -C "$repo_z18" rev-list --count HEAD 2>/dev/null || echo "$before_z18")
  show_z18="$(git -C "$repo_z18" show --name-only --format="" HEAD 2>/dev/null)"

  if [ "$rc_z18" -eq 0 ] && [ "$after_z18" -eq $((before_z18 + 1)) ] \
    && echo "$show_z18" | grep -qF "specs/999_probe/a.txt" \
    && echo "$show_z18" | grep -qF "specs/TODO.md" \
    && ! echo "$out_z18" | grep -q "out-of-scope"; then
    common_test_pass "Z18: with the shared library unsourceable, specs/TODO.md still falls back to the hardcoded two-literal pair and is still admitted -- Decision 2's fallback, exit 0"
  else
    common_test_fail "Z18: expected rc=0, HEAD+1, a.txt and TODO.md both in HEAD, no out-of-scope WARN; got rc=$rc_z18 before=$before_z18 after=$after_z18 show='$show_z18' output=$out_z18"
  fi
fi

# task-ref-ok:end

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
