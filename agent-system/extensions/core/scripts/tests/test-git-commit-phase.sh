#!/usr/bin/env bash
# test-git-commit-phase.sh - Regression suite for git-commit-phase.sh, pinning the N-vs-N-1
# acceptance criterion: a phase whose progress file declares N `files_touched` paths, but whose
# commit lands only N-1 of them, must fail loudly and name the missing path -- never exit 0
# the way the originating incident's hand-typed, nine-of-ten pathspec did.
#
# Follows context/standards/shell-script-testing.md and this directory's own house convention
# (see test-git-commit-scoped.sh): set -uo pipefail, PASSED/FAILED counters with
# pass()/fail()/info(), mktemp -d workdir with a trap EXIT cleanup, loud-skip discipline (a
# missing required script is reported loudly, never silently skipped), and assertions that read
# HEAD/working-tree/output content directly rather than trusting exit code alone.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED (or a required script is
# missing, reported loudly rather than silently skipped).

# task-ref-ok:begin category 6-adjacent: every "--task 999"/"999_probe" literal in this file is
# synthetic fixture data exercising git-commit-phase.sh's OWN --task input (an arbitrary integer
# identifying the committing task for the file_scope/progress-file lookup) -- never a citation of
# this repo's own ephemeral task tracker. The fixture task number (999) is arbitrary and carries
# no relationship to any real specs/{NNN}_{SLUG}/ task directory. Mirrors the identical
# task-ref-ok precedent in test-git-commit-scoped.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

# --- Loud-skip discipline: verify every required script exists before running anything. ---
REQUIRED_SCRIPTS=(git-commit-phase.sh git-commit-scoped.sh deploy-root-guard.sh task-lock.sh issue-record.sh lib/common.sh lib/task-lookup-lib.sh)
missing=()
for f in "${REQUIRED_SCRIPTS[@]}"; do
  [ -f "$SRC_SCRIPTS_DIR/$f" ] || missing+=("$f")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "ERROR: test-git-commit-phase.sh cannot run -- missing required script(s) under $SRC_SCRIPTS_DIR: ${missing[*]}" >&2
  exit 1
fi

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_repo -- scratch git repo with the wrapper plus every runtime dependency installed
# at .claude/scripts/ (satisfies deploy-root-guard.sh), a probe task directory, a declared
# file_scope in specs/state.json, and three tracked source files under the declared scope.
# Echoes the repo path on stdout. ---
build_repo() {
  local repo
  repo="$(mktemp -d -p "$TOP_WORKDIR")"

  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test Suite"

  mkdir -p "$repo/.claude/scripts/lib"
  local f
  for f in "${REQUIRED_SCRIPTS[@]}"; do
    mkdir -p "$repo/.claude/scripts/$(dirname "$f")"
    cp "$SRC_SCRIPTS_DIR/$f" "$repo/.claude/scripts/$f"
    [ "$f" = "lib/common.sh" ] || [ "$f" = "lib/task-lookup-lib.sh" ] || chmod +x "$repo/.claude/scripts/$f"
  done

  cat > "$repo/.gitignore" <<'GITIGNORE_EOF'
**/.lock/
**/.orchestrator-loop-guard
**/.orchestrator-churn-state.json
**/.drift-inspection.json
GITIGNORE_EOF

  mkdir -p "$repo/specs/999_probe/progress" "$repo/src"
  echo "orig a" > "$repo/src/a.txt"
  echo "orig b" > "$repo/src/b.txt"
  echo "orig c" > "$repo/src/c.txt"
  echo "a marker" > "$repo/specs/999_probe/marker.txt"
  cat > "$repo/specs/state.json" <<'STATE_EOF'
{"active_projects":[{"project_number":999,"project_name":"probe","file_scope":["src/a.txt","src/b.txt","src/c.txt"]}]}
STATE_EOF
  echo "# TODO" > "$repo/specs/TODO.md"

  git -C "$repo" add .gitignore specs src
  git -C "$repo" commit -q -m "initial"

  echo "$repo"
}

# --- write_progress <repo> <phase> <json-objectives-array> -- writes a progress file. ---
write_progress() {
  local repo="$1" phase="$2" objectives="$3"
  cat > "$repo/specs/999_probe/progress/phase-${phase}-progress.json" <<EOF
{"objectives": ${objectives}}
EOF
}

# --- run_phase_commit <repo> <args...> -- invokes the deployed copy in-repo, capturing stdout+stderr. ---
run_phase_commit() {
  local repo="$1"
  shift
  (cd "$repo" && bash "$repo/.claude/scripts/git-commit-phase.sh" "$@")
}

# =====================================================================
# Case 1 (acceptance fixture): a phase declaring 2 files_touched paths, whose commit reaches only
# 1 of them (the second reverted inside the temporary partial index by a planted pre-commit hook,
# mirroring test-git-commit-scoped.sh's own V8 fixture technique) -- must exit 6, name the missing
# path, and must NOT name the other, landed path.
# =====================================================================
info "=== Case 1: N-vs-N-1 acceptance fixture ==="

repo1="$(build_repo)"
write_progress "$repo1" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt","src/b.txt"]}]'
echo "modified a" > "$repo1/src/a.txt"
echo "modified b" > "$repo1/src/b.txt"

stale_sha_1=$(git -C "$repo1" rev-parse HEAD:src/b.txt)
mkdir -p "$repo1/.git/hooks"
cat > "$repo1/.git/hooks/pre-commit" <<HOOK_EOF
#!/usr/bin/env bash
git update-index --cacheinfo 100644 ${stale_sha_1} src/b.txt
exit 0
HOOK_EOF
chmod +x "$repo1/.git/hooks/pre-commit"

before1=$(git -C "$repo1" rev-list --count HEAD)
out1="$(run_phase_commit "$repo1" --task 999 --project probe --phase 1 --message "case1" --session sess_1 2>&1)"
rc1=$?
after1=$(git -C "$repo1" rev-list --count HEAD)

if [ "$rc1" -eq 6 ]; then
  pass "Case 1: exit code is 6"
else
  fail "Case 1: expected exit 6, got $rc1. Output:
$out1"
fi

if echo "$out1" | grep -qF "src/b.txt"; then
  pass "Case 1: the missing path (src/b.txt) is named in the output"
else
  fail "Case 1: src/b.txt not named in output:
$out1"
fi

if ! echo "$out1" | grep -A5 "files_touched path(s)" | grep -qF "src/a.txt"; then
  pass "Case 1: the other, correctly-landed path (src/a.txt) is NOT named among the dirty paths"
else
  fail "Case 1: src/a.txt was wrongly named among the dirty paths:
$out1"
fi

if [ "$after1" -eq $((before1 + 1)) ]; then
  pass "Case 1: the commit is still created despite the incompleteness"
else
  fail "Case 1: expected HEAD to advance by 1; before=$before1 after=$after1"
fi

rm -f "$repo1/.git/hooks/pre-commit"

# =====================================================================
# Case 2 (derivation fixture): the derived pathspec is the union of every objective's
# files_touched plus the fixed task-directory scope, deduplicated -- no hand-typed list required.
# =====================================================================
info "=== Case 2: derivation is the union of every objective, deduplicated ==="

repo2="$(build_repo)"
write_progress "$repo2" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt","src/b.txt"]},{"id":2,"status":"done","files_touched":["src/b.txt","src/c.txt"]}]'
echo "mod a" > "$repo2/src/a.txt"
echo "mod b" > "$repo2/src/b.txt"
echo "mod c" > "$repo2/src/c.txt"

before2=$(git -C "$repo2" rev-list --count HEAD)
out2="$(run_phase_commit "$repo2" --task 999 --project probe --phase 1 --message "case2" --session sess_2 2>&1)"
rc2=$?
after2=$(git -C "$repo2" rev-list --count HEAD)
show2="$(git -C "$repo2" show --name-only --format= HEAD)"

if [ "$rc2" -eq 0 ] && [ "$after2" -eq $((before2 + 1)) ] \
  && echo "$show2" | grep -qF "src/a.txt" \
  && echo "$show2" | grep -qF "src/b.txt" \
  && echo "$show2" | grep -qF "src/c.txt"; then
  pass "Case 2: the commit carries the deduplicated union of every objective's files_touched (a, b, and c each land exactly once)"
else
  fail "Case 2: expected rc=0, HEAD+1, a/b/c all present; got rc=$rc2 before=$before2 after=$after2 show='$show2' out=$out2"
fi

# =====================================================================
# Case 3 (--objective fixture): --objective narrows derivation to the named objective only,
# matching the existing per-objective green-substep behavior it replaces.
# =====================================================================
info "=== Case 3: --objective narrows derivation to one objective ==="

repo3="$(build_repo)"
write_progress "$repo3" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt"]},{"id":2,"status":"in_progress","files_touched":["src/b.txt"]}]'
echo "mod a only" > "$repo3/src/a.txt"
echo "mod b too (not yet committed by objective 1)" > "$repo3/src/b.txt"

out3="$(run_phase_commit "$repo3" --task 999 --project probe --phase 1 --objective 1 --message "case3" --session sess_3 2>&1)"
rc3=$?
show3="$(git -C "$repo3" show --name-only --format= HEAD)"

if [ "$rc3" -eq 0 ] && echo "$show3" | grep -qF "src/a.txt" && ! echo "$show3" | grep -qF "src/b.txt"; then
  pass "Case 3: --objective 1 stages only objective 1's files_touched (a, not b)"
else
  fail "Case 3: expected rc=0, a present, b absent; got rc=$rc3 show='$show3' out=$out3"
fi

status3="$(git -C "$repo3" status --porcelain -- src/b.txt)"
if [ -n "$status3" ]; then
  pass "Case 3: src/b.txt (objective 2's own file) is correctly left uncommitted"
else
  fail "Case 3: src/b.txt should have been left modified/uncommitted"
fi

# =====================================================================
# Case 4 (fail-open: missing progress file) -- warns, skips the check, commits the fixed scope,
# returns the inner exit code.
# =====================================================================
info "=== Case 4: fail-open on a missing progress file ==="

repo4="$(build_repo)"
# No progress file written for phase 1 at all.
echo "updated marker" > "$repo4/specs/999_probe/marker.txt"

out4="$(run_phase_commit "$repo4" --task 999 --project probe --phase 1 --message "case4" --session sess_4 2>&1)"
rc4=$?

if [ "$rc4" -eq 0 ]; then
  pass "Case 4: exits 0 (the inner commit succeeded against the fixed scope alone)"
else
  fail "Case 4: expected exit 0; got $rc4. Output:
$out4"
fi

if echo "$out4" | grep -q "WARNING.*progress file not found"; then
  pass "Case 4: a loud warning names the missing progress file"
else
  fail "Case 4: no missing-progress-file warning in output:
$out4"
fi

if ! echo "$out4" | grep -q "completeness check failed"; then
  pass "Case 4: the completeness check is skipped (no ERROR line)"
else
  fail "Case 4: the completeness check should have been skipped:
$out4"
fi

# =====================================================================
# Case 5 (fail-open: malformed JSON) -- same contract as Case 4.
# =====================================================================
info "=== Case 5: fail-open on malformed progress-file JSON ==="

repo5="$(build_repo)"
echo "{not valid json" > "$repo5/specs/999_probe/progress/phase-1-progress.json"
echo "updated marker" > "$repo5/specs/999_probe/marker.txt"

out5="$(run_phase_commit "$repo5" --task 999 --project probe --phase 1 --message "case5" --session sess_5 2>&1)"
rc5=$?

if [ "$rc5" -eq 0 ] && echo "$out5" | grep -q "WARNING.*not valid JSON" && ! echo "$out5" | grep -q "completeness check failed"; then
  pass "Case 5: malformed JSON warns, falls back to the fixed scope, skips the check, exits 0"
else
  fail "Case 5: expected rc=0, a 'not valid JSON' warning, no completeness-check failure; got rc=$rc5 out=$out5"
fi

# =====================================================================
# Case 6 (fail-open: empty files_touched) -- a verification-only objective with nothing touched.
# =====================================================================
info "=== Case 6: fail-open on an empty files_touched set ==="

repo6="$(build_repo)"
write_progress "$repo6" 1 '[{"id":1,"status":"done","files_touched":[]}]'
echo "updated marker" > "$repo6/specs/999_probe/marker.txt"

out6="$(run_phase_commit "$repo6" --task 999 --project probe --phase 1 --message "case6" --session sess_6 2>&1)"
rc6=$?

if [ "$rc6" -eq 0 ] && echo "$out6" | grep -q "WARNING.*nothing to derive" && ! echo "$out6" | grep -q "completeness check failed"; then
  pass "Case 6: an empty files_touched set warns, skips the check, exits 0"
else
  fail "Case 6: expected rc=0, a 'nothing to derive' warning, no completeness-check failure; got rc=$rc6 out=$out6"
fi

# =====================================================================
# Case 7 (containment-port fixture): a files_touched path NOT contained in the task's declared
# file_scope is dropped with a warning, and the commit still lands (minus that one path).
# =====================================================================
info "=== Case 7: an uncontained path is dropped with a warning ==="

repo7="$(build_repo)"
mkdir -p "$repo7/other"
echo "out of scope" > "$repo7/other/outside.txt"
git -C "$repo7" add other/outside.txt
git -C "$repo7" commit -q -m "seed out-of-scope file"
write_progress "$repo7" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt","other/outside.txt"]}]'
echo "mod a" > "$repo7/src/a.txt"
echo "mod outside" > "$repo7/other/outside.txt"

out7="$(run_phase_commit "$repo7" --task 999 --project probe --phase 1 --message "case7" --session sess_7 2>&1)"
rc7=$?
show7="$(git -C "$repo7" show --name-only --format= HEAD)"

if [ "$rc7" -eq 0 ] && echo "$out7" | grep -q "WARNING.*dropping out-of-scope path 'other/outside.txt'" \
  && echo "$show7" | grep -qF "src/a.txt" && ! echo "$show7" | grep -qF "other/outside.txt"; then
  pass "Case 7: other/outside.txt is dropped with a warning; src/a.txt still lands; exit 0"
else
  fail "Case 7: expected rc=0, a drop warning for other/outside.txt, src/a.txt committed, outside.txt not; got rc=$rc7 show='$show7' out=$out7"
fi

status7="$(git -C "$repo7" status --porcelain -- other/outside.txt)"
if [ -n "$status7" ]; then
  pass "Case 7: the dropped path is left uncommitted on disk for manual review"
else
  fail "Case 7: the dropped path should remain modified/uncommitted"
fi

# =====================================================================
# Case 8 (containment fail-open: missing file_scope) -- proceeds exactly as if the check were
# absent when the task's state.json entry carries no file_scope at all.
# =====================================================================
info "=== Case 8: containment check fails open on a missing file_scope ==="

repo8="$(build_repo)"
cat > "$repo8/specs/state.json" <<'STATE_EOF'
{"active_projects":[{"project_number":999,"project_name":"probe"}]}
STATE_EOF
git -C "$repo8" add specs/state.json
git -C "$repo8" commit -q -m "remove file_scope"
mkdir -p "$repo8/other"
echo "anything" > "$repo8/other/anything.txt"
git -C "$repo8" add other/anything.txt
git -C "$repo8" commit -q -m "seed anything.txt"
write_progress "$repo8" 1 '[{"id":1,"status":"done","files_touched":["other/anything.txt"]}]'
echo "modified anything" > "$repo8/other/anything.txt"

out8="$(run_phase_commit "$repo8" --task 999 --project probe --phase 1 --message "case8" --session sess_8 2>&1)"
rc8=$?
show8="$(git -C "$repo8" show --name-only --format= HEAD)"

if [ "$rc8" -eq 0 ] && echo "$show8" | grep -qF "other/anything.txt" && ! echo "$out8" | grep -q "dropping out-of-scope"; then
  pass "Case 8: a missing file_scope fails open -- the path commits without being dropped"
else
  fail "Case 8: expected rc=0, other/anything.txt committed, no drop warning; got rc=$rc8 show='$show8' out=$out8"
fi

# =====================================================================
# Case 9 (exit-code pass-through fixture): an inner non-zero code with a clean files_touched set
# is returned verbatim, not rewritten to 6. Uses the V4 "nothing to commit" case: no change at
# all under a declared files_touched path.
# =====================================================================
info "=== Case 9: a benign inner non-zero exit code passes through unchanged ==="

repo9="$(build_repo)"
write_progress "$repo9" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt"]}]'
# Commit the progress file itself as a baseline first, so the run_phase_commit call below has
# genuinely nothing left to stage: src/a.txt is unmodified since the initial commit, the probe
# directory's own marker.txt is unmodified, and the progress file is already tracked.
git -C "$repo9" add specs/999_probe/progress/phase-1-progress.json
git -C "$repo9" commit -q -m "seed progress file baseline"

out9="$(run_phase_commit "$repo9" --task 999 --project probe --phase 1 --message "case9" --session sess_9 2>&1)"
rc9=$?

if [ "$rc9" -eq 1 ] && ! echo "$out9" | grep -q "completeness check failed"; then
  pass "Case 9: the benign 'nothing to commit' inner code (1) passes through unchanged, no completeness-check failure (src/a.txt was already clean before the commit attempt)"
else
  fail "Case 9: expected rc=1 (nothing to commit), no completeness-check failure; got rc=$rc9 out=$out9"
fi

# task-ref-ok:end

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
