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
# info() is part of the shared pass/fail/info() counter idiom (shell-script-testing.md);
# unused in this file's current case set, hence never invoked.
# shellcheck disable=SC2329
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
  pass "T8: deletion-only scoped commit lands with D specs/999_probe/file.txt in HEAD"
else
  fail "T8: expected a new commit carrying 'D specs/999_probe/file.txt'; got rc=$rc_t8 before=$before_t8 after=$after_t8 show='$show_t8' output=$out_t8"
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
  pass "T9: one commit carries both D specs/999_probe/file.txt and M specs/999_probe/keep.txt; git status clean afterwards"
else
  fail "T9: expected one commit with D file.txt + M keep.txt and clean status; got rc=$rc_t9 before=$before_t9 after=$after_t9 show='$show_t9' status='$status_t9' output=$out_t9"
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
  pass "T10: in-scope rename commits both halves (D+A or R100); git status clean afterwards"
else
  fail "T10: expected one commit carrying both rename halves and clean status; got rc=$rc_t10 before=$before_t10 after=$after_t10 show='$show_t10' status='$status_t10' output=$out_t10"
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
  pass "T11: all-dropped pathspec list still hits the existing V3 refusal -- exit 2, no commit created (git log unchanged), unaffected by the V6 addition"
else
  fail "T11: expected rc=2, no new commit, V3 ERROR naming zero positive entries remaining; got rc=$rc_t11 before=$before_t11 after=$after_t11 output=$out_t11"
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
  pass "T12: V6 posture pinned -- partial drop with no surviving diff refuses as exit 4 (no commit, git log unchanged), ERROR names the dropped path, generic NOTE is not the only diagnostic"
else
  fail "T12: expected rc=4, no new commit, ERROR naming 01_absent.md, no bare NOTE-only output; got rc=$rc_t12 before=$before_t12 after=$after_t12 output=$out_t12"
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
  pass "T13: legitimate partial drop with a surviving diff still commits -- exit 0, HEAD +1, WARN names the dropped path (HARD CONSTRAINT partial-drop half)"
else
  fail "T13: expected rc=0, HEAD count $before_t13 -> $((before_t13 + 1)), file.txt in HEAD, WARN naming 01_absent.md; got rc=$rc_t13 before=$before_t13 after=$after_t13 show='$show_t13' output=$out_t13"
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
  pass "V1: an unlisted path proceeds exactly as today, even with --task given"
else
  fail "V1: expected rc=0 and HEAD advanced by 1; got rc=$rc_v1 before=$before_v1 after=$after_v1 output=$out_v1"
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
  pass "V2: an unclaimed listed path claims and commits successfully"
else
  fail "V2: expected rc=0 and HEAD advanced by 1; got rc=$rc_v2 before=$before_v2 after=$after_v2 output=$out_v2"
fi
if [ ! -d "$repo_v2/specs/.contention-claims" ] || [ -z "$(ls -A "$repo_v2/specs/.contention-claims" 2>/dev/null)" ]; then
  pass "V2: the claim was released after the commit (no lingering claim directory)"
else
  fail "V2: expected the claim released, found: $(ls "$repo_v2/specs/.contention-claims" 2>/dev/null)"
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
  pass "V3: a path already claimed by this same task is re-entrant -- commit proceeds"
else
  fail "V3: expected rc=0 and HEAD advanced by 1; got rc=$rc_v3 before=$before_v3 after=$after_v3 output=$out_v3"
fi
if [ -d "$repo_v3/specs/.contention-claims" ] && [ -n "$(ls -A "$repo_v3/specs/.contention-claims" 2>/dev/null)" ]; then
  pass "V3: the pre-existing (outer) claim is left in place -- never auto-released by a re-entrant caller"
else
  fail "V3: expected the outer claim still present after a re-entrant commit, found none"
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
  pass "V4: a path held by another live task refuses (exit 3), HEAD unchanged"
else
  fail "V4: expected rc=3 and HEAD unchanged; got rc=$rc_v4 before=$before_v4 after=$after_v4 output=$out_v4"
fi
if [ -z "$staged_v4" ]; then
  pass "V4: nothing staged on the foreign-claim refusal (git diff --cached is empty)"
else
  fail "V4: expected nothing staged, found: $staged_v4"
fi
if echo "$out_v4" | grep -q "task #402"; then
  pass "V4: the refusal names the holding task (#402) verbatim"
else
  fail "V4: expected the refusal to name task #402, got: $out_v4"
fi
holder_after_v4=$(jq -r '.task // empty' "$repo_v4/specs/.contention-claims/specs_999_probe_file.txt/holder.json" 2>/dev/null)
if [ "$holder_after_v4" = "402" ]; then
  pass "V4: the foreign claim is untouched (still held by task #402)"
else
  fail "V4: expected the foreign claim to still be held by task #402, got holder='$holder_after_v4'"
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
  pass "V5: a stale foreign claim is reclaimed; the commit proceeds"
else
  fail "V5: expected rc=0 and HEAD advanced by 1; got rc=$rc_v5 before=$before_v5 after=$after_v5 output=$out_v5"
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
  pass "V6: a malformed manifest fails open -- the commit still proceeds"
else
  fail "V6: expected rc=0 and HEAD advanced by 1 despite the malformed manifest; got rc=$rc_v6 before=$before_v6 after=$after_v6 output=$out_v6"
fi
if echo "$out_v6" | grep -qi "could not parse contention manifest"; then
  pass "V6: a non-blocking WARN names the unparseable manifest file"
else
  fail "V6: expected a WARN about the malformed manifest, got: $out_v6"
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
  pass "V7: omitting --task fails open -- the commit proceeds even though the path is held by another task in the manifest"
else
  fail "V7: expected rc=0 and HEAD advanced by 1 with --task omitted; got rc=$rc_v7 before=$before_v7 after=$after_v7 output=$out_v7"
fi
(cd "$repo_v7" && bash .claude/scripts/task-lock.sh claim-release "specs/999_probe/file.txt" 402 >/dev/null 2>&1)

# --- V8: every pre-existing V2/V3 case (T1-T10 above) is unaffected -- already proven by T1-T10
# passing above without any of them ever passing --task; no new fixture needed here, this is a
# structural note that V8's own acceptance is "look at the T-series results already printed".
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
