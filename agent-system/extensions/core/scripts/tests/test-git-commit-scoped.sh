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
SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

# --- Loud-skip discipline: verify all three required scripts exist before running anything. ---
REQUIRED_SCRIPTS=(git-commit-scoped.sh deploy-root-guard.sh task-lock.sh lib/common.sh lib/task-lookup-lib.sh)
missing=()
for f in "${REQUIRED_SCRIPTS[@]}"; do
  [ -f "$SRC_SCRIPTS_DIR/$f" ] || missing+=("$f")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "ERROR: test-git-commit-scoped.sh cannot run -- missing required script(s) under $SRC_SCRIPTS_DIR: ${missing[*]}" >&2
  exit 1
fi

TOP_WORKDIR="$(mktemp -d)"
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
    # lib/common.sh and lib/task-lookup-lib.sh are sourced, never executed -- matches the other
    # scripts/lib/*.sh files.
    [ "$f" = "lib/common.sh" ] || [ "$f" = "lib/task-lookup-lib.sh" ] || chmod +x "$repo/.claude/scripts/$f"
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
  pass "T1: commit lands (git log gained a commit) with .lock/ present, fully-covered repo (verified via git log/git show, not exit code alone)"
else
  fail "T1: expected rc=0, HEAD count $before_t1 -> $((before_t1 + 1)), file.txt in HEAD; got rc=$rc_t1 before=$before_t1 after=$after_t1 output=$out_t1"
fi

if echo "$show_t1" | grep -q '\.lock/'; then
  fail "T2: .lock unexpectedly present in the T1 commit's file list: $show_t1"
else
  pass "T2: .lock is absent from the T1 commit's file list"
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
  pass "T3: commit lands with all four ephemeral paths present; none appear in the commit (fully-covered repo)"
else
  fail "T3: expected rc=0, commit landed, none of the four ephemeral paths staged; got rc=$rc_t3 before=$before_t3 after=$after_t3 show='$show_t3' output=$out_t3"
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
  pass "T4: no .lock/ present, other three present; commit lands and excludes the other three (outcome reading of 'existing callers unaffected')"
else
  fail "T4: expected rc=0, commit landed, other three excluded; got rc=$rc_t4 before=$before_t4 after=$after_t4 show='$show_t4' output=$out_t4"
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
  pass "T5: under-configured repo (no ephemeral .gitignore block); commit lands and all four excluded via injected :(exclude) pathspecs"
else
  fail "T5: expected rc=0, commit landed, all four excluded via injected pathspecs; got rc=$rc_t5 before=$before_t5 after=$after_t5 show='$show_t5' output=$out_t5"
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
  pass "T6: V3 exclude-only refusal intact -- exit 2, no commit created (git log unchanged)"
else
  fail "T6: expected rc=2 and no new commit; got rc=$rc_t6 before=$before_t6 after=$after_t6 output=$out_t6"
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
  pass "T7: V2 unmatched-pathspec drop intact -- commit still lands with the valid path, WARN names the dropped pathspec"
else
  fail "T7: expected rc=0, commit landed with file.txt, WARN naming nonexistent.txt; got rc=$rc_t7 before=$before_t7 after=$after_t7 show='$show_t7' output=$out_t7"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
