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
source "$SCRIPT_DIR/../lib/common.sh"
SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."

PASSED=0
FAILED=0


# --- Loud-skip discipline: verify every required script exists before running anything. ---
REQUIRED_SCRIPTS=(git-commit-phase.sh git-commit-scoped.sh deploy-root-guard.sh task-lock.sh issue-record.sh lib/common.sh lib/task-lookup-lib.sh lib/engine-written-state-paths-lib.sh lib/source-store-path-lib.sh)
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
    [ "$f" = "lib/common.sh" ] || [ "$f" = "lib/task-lookup-lib.sh" ] || [ "$f" = "lib/engine-written-state-paths-lib.sh" ] || [ "$f" = "lib/source-store-path-lib.sh" ] || chmod +x "$repo/.claude/scripts/$f"
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
  # Minimal, schema-valid .return-meta.json (status + an empty artifacts array, legal for
  # in_progress per validate-return-meta.sh) -- the implement-postflight shape every real task
  # directory already carries by Stage 0 before any phase commit. Cases 18-24 below exercise the
  # propose_file_scope_addition() deposit against this seeded file.
  cat > "$repo/specs/999_probe/.return-meta.json" <<'RETURN_META_EOF'
{"status":"in_progress","artifacts":[]}
RETURN_META_EOF

  git -C "$repo" add .gitignore specs src
  git -C "$repo" commit -q -m "initial"

  echo "$repo"
}

# --- build_source_store_repo <consumer_repo> -- creates a SECOND, genuinely disjoint `git init`
# repository under TOP_WORKDIR, with an `agent-system/extensions/core/doc.md` file at its own
# root, and writes a `.claude-extensions.json` into <consumer_repo> naming it as the `core`
# extension's source_dir -- the disjoint scenario the containment remedy requires, never a
# coincidental same-repository fixture. Echoes "<source_repo> <relative-path-inside-it>" on
# stdout for the caller to use when writing a files_touched entry. ---
build_source_store_repo() {
  local consumer_repo="$1"
  local source_repo
  source_repo="$(mktemp -d -p "$TOP_WORKDIR")"

  mkdir -p "$source_repo/agent-system/extensions/core"
  git -C "$source_repo" init -q
  git -C "$source_repo" config user.email "test@example.com"
  git -C "$source_repo" config user.name "Test Suite"
  echo "source store doc" > "$source_repo/agent-system/extensions/core/doc.md"
  git -C "$source_repo" add -A
  git -C "$source_repo" commit -q -m "seed source store"

  cat > "$consumer_repo/.claude-extensions.json" <<EOF
{"extensions":{"core":{"source_dir":"$source_repo/agent-system/extensions/core"}}}
EOF

  echo "$source_repo agent-system/extensions/core/doc.md"
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
common_test_info "=== Case 1: N-vs-N-1 acceptance fixture ==="

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
  common_test_pass "Case 1: exit code is 6"
else
  common_test_fail "Case 1: expected exit 6, got $rc1. Output:
$out1"
fi

if echo "$out1" | grep -qF "src/b.txt"; then
  common_test_pass "Case 1: the missing path (src/b.txt) is named in the output"
else
  common_test_fail "Case 1: src/b.txt not named in output:
$out1"
fi

if ! echo "$out1" | grep -A5 "files_touched path(s)" | grep -qF "src/a.txt"; then
  common_test_pass "Case 1: the other, correctly-landed path (src/a.txt) is NOT named among the dirty paths"
else
  common_test_fail "Case 1: src/a.txt was wrongly named among the dirty paths:
$out1"
fi

if [ "$after1" -eq $((before1 + 1)) ]; then
  common_test_pass "Case 1: the commit is still created despite the incompleteness"
else
  common_test_fail "Case 1: expected HEAD to advance by 1; before=$before1 after=$after1"
fi

rm -f "$repo1/.git/hooks/pre-commit"

# =====================================================================
# Case 2 (derivation fixture): the derived pathspec is the union of every objective's
# files_touched plus the fixed task-directory scope, deduplicated -- no hand-typed list required.
# =====================================================================
common_test_info "=== Case 2: derivation is the union of every objective, deduplicated ==="

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
  common_test_pass "Case 2: the commit carries the deduplicated union of every objective's files_touched (a, b, and c each land exactly once)"
else
  common_test_fail "Case 2: expected rc=0, HEAD+1, a/b/c all present; got rc=$rc2 before=$before2 after=$after2 show='$show2' out=$out2"
fi

# =====================================================================
# Case 3 (--objective fixture): --objective narrows derivation to the named objective only,
# matching the existing per-objective green-substep behavior it replaces.
# =====================================================================
common_test_info "=== Case 3: --objective narrows derivation to one objective ==="

repo3="$(build_repo)"
write_progress "$repo3" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt"]},{"id":2,"status":"in_progress","files_touched":["src/b.txt"]}]'
echo "mod a only" > "$repo3/src/a.txt"
echo "mod b too (not yet committed by objective 1)" > "$repo3/src/b.txt"

out3="$(run_phase_commit "$repo3" --task 999 --project probe --phase 1 --objective 1 --message "case3" --session sess_3 2>&1)"
rc3=$?
show3="$(git -C "$repo3" show --name-only --format= HEAD)"

if [ "$rc3" -eq 0 ] && echo "$show3" | grep -qF "src/a.txt" && ! echo "$show3" | grep -qF "src/b.txt"; then
  common_test_pass "Case 3: --objective 1 stages only objective 1's files_touched (a, not b)"
else
  common_test_fail "Case 3: expected rc=0, a present, b absent; got rc=$rc3 show='$show3' out=$out3"
fi

status3="$(git -C "$repo3" status --porcelain -- src/b.txt)"
if [ -n "$status3" ]; then
  common_test_pass "Case 3: src/b.txt (objective 2's own file) is correctly left uncommitted"
else
  common_test_fail "Case 3: src/b.txt should have been left modified/uncommitted"
fi

# =====================================================================
# Case 4 (fail-open: missing progress file) -- warns, skips the check, commits the fixed scope,
# returns the inner exit code.
# =====================================================================
common_test_info "=== Case 4: fail-open on a missing progress file ==="

repo4="$(build_repo)"
# No progress file written for phase 1 at all.
echo "updated marker" > "$repo4/specs/999_probe/marker.txt"

out4="$(run_phase_commit "$repo4" --task 999 --project probe --phase 1 --message "case4" --session sess_4 2>&1)"
rc4=$?

if [ "$rc4" -eq 0 ]; then
  common_test_pass "Case 4: exits 0 (the inner commit succeeded against the fixed scope alone)"
else
  common_test_fail "Case 4: expected exit 0; got $rc4. Output:
$out4"
fi

if echo "$out4" | grep -q "WARNING.*progress file not found"; then
  common_test_pass "Case 4: a loud warning names the missing progress file"
else
  common_test_fail "Case 4: no missing-progress-file warning in output:
$out4"
fi

if ! echo "$out4" | grep -q "completeness check failed"; then
  common_test_pass "Case 4: the completeness check is skipped (no ERROR line)"
else
  common_test_fail "Case 4: the completeness check should have been skipped:
$out4"
fi

# =====================================================================
# Case 5 (fail-open: malformed JSON) -- same contract as Case 4.
# =====================================================================
common_test_info "=== Case 5: fail-open on malformed progress-file JSON ==="

repo5="$(build_repo)"
echo "{not valid json" > "$repo5/specs/999_probe/progress/phase-1-progress.json"
echo "updated marker" > "$repo5/specs/999_probe/marker.txt"

out5="$(run_phase_commit "$repo5" --task 999 --project probe --phase 1 --message "case5" --session sess_5 2>&1)"
rc5=$?

if [ "$rc5" -eq 0 ] && echo "$out5" | grep -q "WARNING.*not valid JSON" && ! echo "$out5" | grep -q "completeness check failed"; then
  common_test_pass "Case 5: malformed JSON warns, falls back to the fixed scope, skips the check, exits 0"
else
  common_test_fail "Case 5: expected rc=0, a 'not valid JSON' warning, no completeness-check failure; got rc=$rc5 out=$out5"
fi

# =====================================================================
# Case 6 (fail-open: empty files_touched) -- a verification-only objective with nothing touched.
# =====================================================================
common_test_info "=== Case 6: fail-open on an empty files_touched set ==="

repo6="$(build_repo)"
write_progress "$repo6" 1 '[{"id":1,"status":"done","files_touched":[]}]'
echo "updated marker" > "$repo6/specs/999_probe/marker.txt"

out6="$(run_phase_commit "$repo6" --task 999 --project probe --phase 1 --message "case6" --session sess_6 2>&1)"
rc6=$?

if [ "$rc6" -eq 0 ] && echo "$out6" | grep -q "WARNING.*nothing to derive" && ! echo "$out6" | grep -q "completeness check failed"; then
  common_test_pass "Case 6: an empty files_touched set warns, skips the check, exits 0"
else
  common_test_fail "Case 6: expected rc=0, a 'nothing to derive' warning, no completeness-check failure; got rc=$rc6 out=$out6"
fi

# =====================================================================
# Case 7 (containment-port fixture): a files_touched path NOT contained in the task's declared
# file_scope is dropped with a warning, and the commit still lands (minus that one path).
# =====================================================================
common_test_info "=== Case 7: an uncontained path is dropped with a warning ==="

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
  common_test_pass "Case 7: other/outside.txt is dropped with a warning; src/a.txt still lands; exit 0"
else
  common_test_fail "Case 7: expected rc=0, a drop warning for other/outside.txt, src/a.txt committed, outside.txt not; got rc=$rc7 show='$show7' out=$out7"
fi

status7="$(git -C "$repo7" status --porcelain -- other/outside.txt)"
if [ -n "$status7" ]; then
  common_test_pass "Case 7: the dropped path is left uncommitted on disk for manual review"
else
  common_test_fail "Case 7: the dropped path should remain modified/uncommitted"
fi

# =====================================================================
# Case 8 (containment fail-open: missing file_scope) -- proceeds exactly as if the check were
# absent when the task's state.json entry carries no file_scope at all.
# =====================================================================
common_test_info "=== Case 8: containment check fails open on a missing file_scope ==="

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
  common_test_pass "Case 8: a missing file_scope fails open -- the path commits without being dropped"
else
  common_test_fail "Case 8: expected rc=0, other/anything.txt committed, no drop warning; got rc=$rc8 show='$show8' out=$out8"
fi

# =====================================================================
# Case 9 (exit-code pass-through fixture): an inner non-zero code with a clean files_touched set
# is returned verbatim, not rewritten to 6. Uses the V4 "nothing to commit" case: no change at
# all under a declared files_touched path.
# =====================================================================
common_test_info "=== Case 9: a benign inner non-zero exit code passes through unchanged ==="

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
  common_test_pass "Case 9: the benign 'nothing to commit' inner code (1) passes through unchanged, no completeness-check failure (src/a.txt was already clean before the commit attempt)"
else
  common_test_fail "Case 9: expected rc=1 (nothing to commit), no completeness-check failure; got rc=$rc9 out=$out9"
fi

# Case 10/11 below reuse the same synthetic fixture task identifier as every other case in this
# file, under the file-wide marker pair above.
# =====================================================================
# Case 10/11 (deep-glob "/**" containment coverage): proves the fix for the quoted-entry bug
# that made a "/**"-suffixed file_scope entry never contain any path at this ported-twin site.
# The base directory (other/widget-area/) lives entirely outside the default build_repo
# file_scope (src/a.txt, src/b.txt, src/c.txt), so containment under test is attributable only
# to the new deep-glob branch.
# =====================================================================
common_test_info "=== Case 10: a /** file_scope entry contains a direct child and a deep descendant ==="

repo10="$(build_repo)"
cat > "$repo10/specs/state.json" <<'STATE_EOF'
{"active_projects":[{"project_number":999,"project_name":"probe","file_scope":["other/widget-area/**"]}]}
STATE_EOF
git -C "$repo10" add specs/state.json
git -C "$repo10" commit -q -m "declare /** file_scope"
mkdir -p "$repo10/other/widget-area/deep/deeper"
echo "direct child" > "$repo10/other/widget-area/direct.txt"
echo "deep descendant" > "$repo10/other/widget-area/deep/deeper/nested.txt"
git -C "$repo10" add other/widget-area/direct.txt other/widget-area/deep/deeper/nested.txt
git -C "$repo10" commit -q -m "seed widget-area fixtures"
write_progress "$repo10" 1 '[{"id":1,"status":"done","files_touched":["other/widget-area/direct.txt","other/widget-area/deep/deeper/nested.txt"]}]'
echo "modified direct" > "$repo10/other/widget-area/direct.txt"
echo "modified nested" > "$repo10/other/widget-area/deep/deeper/nested.txt"

out10="$(run_phase_commit "$repo10" --task 999 --project probe --phase 1 --message "case10" --session sess_10 2>&1)"
rc10=$?
show10="$(git -C "$repo10" show --name-only --format= HEAD)"

if [ "$rc10" -eq 0 ] && ! echo "$out10" | grep -q "dropping out-of-scope" \
  && echo "$show10" | grep -qF "other/widget-area/direct.txt" \
  && echo "$show10" | grep -qF "other/widget-area/deep/deeper/nested.txt"; then
  common_test_pass "Case 10: a /** file_scope entry contains both a direct child and a deeply nested descendant -- both land, no drop warning, exit 0"
else
  common_test_fail "Case 10: expected rc=0, both direct.txt and nested.txt committed, no drop warning; got rc=$rc10 show='$show10' out=$out10"
fi

# =====================================================================
# Case 11: the same "/**" entry does NOT contain a same-prefix sibling (other/widget-area-sibling/
# vs other/widget-area/) -- the non-widening proof. The sibling is dropped with the existing
# warning and left uncommitted on disk; the in-scope descendant still lands.
# =====================================================================
common_test_info "=== Case 11: a /** file_scope entry does NOT contain a same-prefix sibling ==="

repo11="$(build_repo)"
cat > "$repo11/specs/state.json" <<'STATE_EOF'
{"active_projects":[{"project_number":999,"project_name":"probe","file_scope":["other/widget-area/**"]}]}
STATE_EOF
git -C "$repo11" add specs/state.json
git -C "$repo11" commit -q -m "declare /** file_scope"
mkdir -p "$repo11/other/widget-area" "$repo11/other/widget-area-sibling"
echo "in scope" > "$repo11/other/widget-area/direct.txt"
echo "same-prefix sibling, out of scope" > "$repo11/other/widget-area-sibling/x.txt"
git -C "$repo11" add other/widget-area/direct.txt other/widget-area-sibling/x.txt
git -C "$repo11" commit -q -m "seed widget-area and sibling fixtures"
write_progress "$repo11" 1 '[{"id":1,"status":"done","files_touched":["other/widget-area/direct.txt","other/widget-area-sibling/x.txt"]}]'
echo "modified direct" > "$repo11/other/widget-area/direct.txt"
echo "modified sibling" > "$repo11/other/widget-area-sibling/x.txt"

out11="$(run_phase_commit "$repo11" --task 999 --project probe --phase 1 --message "case11" --session sess_11 2>&1)"
rc11=$?
show11="$(git -C "$repo11" show --name-only --format= HEAD)"

if [ "$rc11" -eq 0 ] && echo "$out11" | grep -q "WARNING.*dropping out-of-scope path 'other/widget-area-sibling/x.txt'" \
  && echo "$show11" | grep -qF "other/widget-area/direct.txt" && ! echo "$show11" | grep -qF "other/widget-area-sibling/x.txt"; then
  common_test_pass "Case 11: other/widget-area-sibling/x.txt (same-prefix sibling outside the base's '/' boundary) is dropped with a warning; other/widget-area/direct.txt still lands; exit 0"
else
  common_test_fail "Case 11: expected rc=0, a drop warning for other/widget-area-sibling/x.txt, direct.txt committed, x.txt not; got rc=$rc11 show='$show11' out=$out11"
fi

status11="$(git -C "$repo11" status --porcelain -- other/widget-area-sibling/x.txt)"
if [ -n "$status11" ]; then
  common_test_pass "Case 11: the dropped same-prefix-sibling path is left uncommitted on disk for manual review"
else
  common_test_fail "Case 11: the dropped path should remain modified/uncommitted"
fi

# =====================================================================
# Case 12 (trailing-slash containment fixture): a file_scope entry declared with a trailing
# slash ("other/widget-area/") must contain its children exactly as the slash-free form
# ("other/widget-area") does -- pinning the doubled-slash glob defect where "$entry/*" on an
# already-slash-terminated entry composed "//*" and matched nothing, silently dropping every
# path under that scope entry.
# =====================================================================
common_test_info "=== Case 12: a trailing-slash file_scope entry contains its children ==="

repo12="$(build_repo)"
cat > "$repo12/specs/state.json" <<'STATE_EOF'
{"active_projects":[{"project_number":999,"project_name":"probe","file_scope":["other/widget-area/"]}]}
STATE_EOF
git -C "$repo12" add specs/state.json
git -C "$repo12" commit -q -m "declare trailing-slash file_scope"
mkdir -p "$repo12/other/widget-area"
echo "direct child" > "$repo12/other/widget-area/direct.txt"
git -C "$repo12" add other/widget-area/direct.txt
git -C "$repo12" commit -q -m "seed widget-area fixture"
write_progress "$repo12" 1 '[{"id":1,"status":"done","files_touched":["other/widget-area/direct.txt"]}]'
echo "modified direct" > "$repo12/other/widget-area/direct.txt"

out12="$(run_phase_commit "$repo12" --task 999 --project probe --phase 1 --message "case12" --session sess_12 2>&1)"
rc12=$?
show12="$(git -C "$repo12" show --name-only --format= HEAD)"

if [ "$rc12" -eq 0 ] && ! echo "$out12" | grep -q "dropping out-of-scope" \
  && echo "$show12" | grep -qF "other/widget-area/direct.txt"; then
  common_test_pass "Case 12: a trailing-slash file_scope entry ('other/widget-area/') contains its direct child -- no drop warning, exit 0"
else
  common_test_fail "Case 12: expected rc=0, direct.txt committed, no drop warning; got rc=$rc12 show='$show12' out=$out12"
fi

# =====================================================================
# Case 13 (positive admission + paired negative, the non-regression guard): specs/events.jsonl
# and specs/errors.json are admitted via the shared engine-written-state-paths-lib.sh widening
# -- neither is in the declared file_scope -- with NO "dropping out-of-scope path" warning for
# either, both present in the commit. In the SAME fixture, Case 7's genuinely out-of-scope
# other/outside.txt is STILL dropped, STILL warned with the same message text, and the commit
# STILL lands minus that path -- proving the admission is not a blanket pass.
# =====================================================================
common_test_info "=== Case 13: specs/events.jsonl and specs/errors.json are admitted; a genuine excursion is still dropped ==="

repo13="$(build_repo)"
mkdir -p "$repo13/other"
echo "out of scope" > "$repo13/other/outside.txt"
echo '{"event":"baseline"}' > "$repo13/specs/events.jsonl"
echo '{"errors":[]}' > "$repo13/specs/errors.json"
git -C "$repo13" add other/outside.txt specs/events.jsonl specs/errors.json
git -C "$repo13" commit -q -m "seed out-of-scope file and baseline engine-written-state files"
write_progress "$repo13" 1 '[{"id":1,"status":"done","files_touched":["specs/events.jsonl","specs/errors.json","other/outside.txt"]}]'
echo "mod outside" > "$repo13/other/outside.txt"
echo '{"event":"appended"}' >> "$repo13/specs/events.jsonl"
echo '{"errors":[{"id":1}]}' > "$repo13/specs/errors.json"

out13="$(run_phase_commit "$repo13" --task 999 --project probe --phase 1 --message "case13" --session sess_13 2>&1)"
rc13=$?
show13="$(git -C "$repo13" show --name-only --format= HEAD)"

if [ "$rc13" -eq 0 ] \
  && ! echo "$out13" | grep -q "dropping out-of-scope path 'specs/events.jsonl'" \
  && ! echo "$out13" | grep -q "dropping out-of-scope path 'specs/errors.json'" \
  && echo "$show13" | grep -qF "specs/events.jsonl" \
  && echo "$show13" | grep -qF "specs/errors.json"; then
  common_test_pass "Case 13: specs/events.jsonl and specs/errors.json are admitted via the shared library widening -- no drop warning for either, both committed"
else
  common_test_fail "Case 13: expected rc=0, events.jsonl and errors.json committed with no drop warning; got rc=$rc13 show='$show13' out=$out13"
fi

if echo "$out13" | grep -q "WARNING.*dropping out-of-scope path 'other/outside.txt'" \
  && ! echo "$show13" | grep -qF "other/outside.txt"; then
  common_test_pass "Case 13 (paired negative): other/outside.txt is STILL dropped with the same warning, in the SAME run that admits the engine-written-state files -- non-regression proof"
else
  common_test_fail "Case 13 (paired negative): expected other/outside.txt to still be dropped with a warning; got show='$show13' out=$out13"
fi

status13="$(git -C "$repo13" status --porcelain -- other/outside.txt)"
if [ -n "$status13" ]; then
  common_test_pass "Case 13 (paired negative): the dropped path is left uncommitted on disk for manual review, exactly as Case 7 pins"
else
  common_test_fail "Case 13 (paired negative): the dropped path should remain modified/uncommitted"
fi

# =====================================================================
# Case 14 (fail-open preserved, extending Case 8): a task entry with no file_scope still skips
# the Containment Self-Check entirely, even when files_touched names an engine-written-state
# path -- the shared-library splice lives INSIDE the non-empty file_scope_arr guard and must
# never fire when that guard itself is never entered.
# =====================================================================
common_test_info "=== Case 14: fail-open (no file_scope) is unaffected by the engine-written-state splice ==="

repo14="$(build_repo)"
cat > "$repo14/specs/state.json" <<'STATE_EOF'
{"active_projects":[{"project_number":999,"project_name":"probe"}]}
STATE_EOF
git -C "$repo14" add specs/state.json
git -C "$repo14" commit -q -m "remove file_scope"
echo '{"event":"baseline"}' > "$repo14/specs/events.jsonl"
git -C "$repo14" add specs/events.jsonl
git -C "$repo14" commit -q -m "seed baseline specs/events.jsonl"
write_progress "$repo14" 1 '[{"id":1,"status":"done","files_touched":["specs/events.jsonl"]}]'
echo '{"event":"dirtied"}' >> "$repo14/specs/events.jsonl"

out14="$(run_phase_commit "$repo14" --task 999 --project probe --phase 1 --message "case14" --session sess_14 2>&1)"
rc14=$?
show14="$(git -C "$repo14" show --name-only --format= HEAD)"

if [ "$rc14" -eq 0 ] && echo "$show14" | grep -qF "specs/events.jsonl" && ! echo "$out14" | grep -q "dropping out-of-scope"; then
  common_test_pass "Case 14: a missing file_scope fails open -- specs/events.jsonl commits without being dropped, and without the splice ever running"
else
  common_test_fail "Case 14: expected rc=0, specs/events.jsonl committed, no drop warning; got rc=$rc14 show='$show14' out=$out14"
fi

# =====================================================================
# Case 15 (acceptance: own-task-directory admission): a files_touched path under the committing
# task's own resolved artifact directory (specs/999_probe/reports/01_probe-report.md) is NOT
# named in the declared, non-empty file_scope (src/a.txt, src/b.txt, src/c.txt) yet lands in the
# phase commit with no drop warning and zero recorded scope-excursion issues -- proving the
# own-task-directory member spliced into the Containment Self-Check. Confirmed by direct probe
# against the unmodified (pre-fix) script: the file still lands via the unconditional task_dir/
# stage_paths seed even without this member, but a spurious drop warning fires and a spurious
# "scope excursion" row is written to specs/999_probe/issues.jsonl -- that noise, not an actual
# omission from the commit, is what this member eliminates.
# =====================================================================
common_test_info "=== Case 15: an own-task-directory path lands with no drop warning and no scope-excursion issue record ==="

repo15="$(build_repo)"
mkdir -p "$repo15/specs/999_probe/reports"
echo "baseline report" > "$repo15/specs/999_probe/reports/01_probe-report.md"
git -C "$repo15" add specs/999_probe/reports/01_probe-report.md
git -C "$repo15" commit -q -m "seed baseline own-task-directory report"
write_progress "$repo15" 1 '[{"id":1,"status":"done","files_touched":["specs/999_probe/reports/01_probe-report.md"]}]'
echo "updated report" > "$repo15/specs/999_probe/reports/01_probe-report.md"

out15="$(run_phase_commit "$repo15" --task 999 --project probe --phase 1 --message "case15" --session sess_15 2>&1)"
rc15=$?
show15="$(git -C "$repo15" show --name-only --format= HEAD)"

if [ "$rc15" -eq 0 ] \
  && ! echo "$out15" | grep -q "dropping out-of-scope path 'specs/999_probe/reports/01_probe-report.md'" \
  && echo "$show15" | grep -qF "specs/999_probe/reports/01_probe-report.md"; then
  common_test_pass "Case 15: the own-task-directory report lands with no drop warning"
else
  common_test_fail "Case 15: expected rc=0, own-task-directory report committed, no drop warning; got rc=$rc15 show='$show15' out=$out15"
fi

if [ ! -f "$repo15/specs/999_probe/issues.jsonl" ]; then
  common_test_pass "Case 15: no issues.jsonl was written for this task -- zero scope-excursion issue records"
elif ! grep -q "scope excursion" "$repo15/specs/999_probe/issues.jsonl" 2>/dev/null; then
  common_test_pass "Case 15: issues.jsonl exists but carries no scope-excursion record"
else
  common_test_fail "Case 15: expected no scope-excursion issue record; got $(cat "$repo15/specs/999_probe/issues.jsonl" 2>/dev/null)"
fi

# =====================================================================
# Case 16 (paired negative, Case 7/13's shape): in the SAME fixture run as an own-task-directory
# artifact path, a genuinely out-of-territory source path (other/outside.txt) is STILL dropped,
# STILL warned with the existing message text, STILL left modified/uncommitted on disk, and
# STILL recorded as a scope-excursion issue -- proving the own-task-directory admission is not a
# blanket pass.
# =====================================================================
common_test_info "=== Case 16: an own-task-directory path and a genuine excursion in the same run -- the excursion still drops ==="

repo16="$(build_repo)"
mkdir -p "$repo16/specs/999_probe/reports" "$repo16/other"
echo "baseline report" > "$repo16/specs/999_probe/reports/01_probe-report.md"
echo "out of scope" > "$repo16/other/outside.txt"
git -C "$repo16" add specs/999_probe/reports/01_probe-report.md other/outside.txt
git -C "$repo16" commit -q -m "seed own-task-directory report and out-of-scope file"
write_progress "$repo16" 1 '[{"id":1,"status":"done","files_touched":["specs/999_probe/reports/01_probe-report.md","other/outside.txt"]}]'
echo "updated report" > "$repo16/specs/999_probe/reports/01_probe-report.md"
echo "mod outside" > "$repo16/other/outside.txt"

out16="$(run_phase_commit "$repo16" --task 999 --project probe --phase 1 --message "case16" --session sess_16 2>&1)"
rc16=$?
show16="$(git -C "$repo16" show --name-only --format= HEAD)"

if [ "$rc16" -eq 0 ] \
  && ! echo "$out16" | grep -q "dropping out-of-scope path 'specs/999_probe/reports/01_probe-report.md'" \
  && echo "$show16" | grep -qF "specs/999_probe/reports/01_probe-report.md" \
  && echo "$out16" | grep -q "WARNING.*dropping out-of-scope path 'other/outside.txt'" \
  && ! echo "$show16" | grep -qF "other/outside.txt"; then
  common_test_pass "Case 16: the own-task-directory report lands with no drop warning; other/outside.txt is still dropped and warned"
else
  common_test_fail "Case 16: expected rc=0, own-dir report committed with no drop warning, outside.txt dropped and warned; got rc=$rc16 show='$show16' out=$out16"
fi

status16="$(git -C "$repo16" status --porcelain -- other/outside.txt)"
if [ -n "$status16" ]; then
  common_test_pass "Case 16: the dropped path is left uncommitted on disk for manual review"
else
  common_test_fail "Case 16: the dropped path should remain modified/uncommitted"
fi

if [ -f "$repo16/specs/999_probe/issues.jsonl" ] && grep -q "scope excursion" "$repo16/specs/999_probe/issues.jsonl" \
  && grep -q "other/outside.txt" "$repo16/specs/999_probe/issues.jsonl"; then
  common_test_pass "Case 16: other/outside.txt is still recorded as a scope-excursion issue"
else
  common_test_fail "Case 16: expected a scope-excursion issue record naming other/outside.txt; got $(cat "$repo16/specs/999_probe/issues.jsonl" 2>/dev/null)"
fi

# =====================================================================
# Case 17 (fail-open preserved across three "missing" shapes): an own-task-directory path commits
# with no drop warning in each case, because the new splice sits INSIDE the non-empty
# file_scope_arr guard and is never reached when that guard itself is never entered -- not
# because the own-task-directory path happens to be contained some other way.
# =====================================================================
common_test_info "=== Case 17: fail-open is preserved for missing, empty, and malformed file_scope ==="

# Case 17a: file_scope key entirely absent.
repo17a="$(build_repo)"
cat > "$repo17a/specs/state.json" <<'STATE_EOF'
{"active_projects":[{"project_number":999,"project_name":"probe"}]}
STATE_EOF
git -C "$repo17a" add specs/state.json
git -C "$repo17a" commit -q -m "remove file_scope"
mkdir -p "$repo17a/specs/999_probe/reports"
echo "baseline report" > "$repo17a/specs/999_probe/reports/01_probe-report.md"
git -C "$repo17a" add specs/999_probe/reports/01_probe-report.md
git -C "$repo17a" commit -q -m "seed own-task-directory report"
write_progress "$repo17a" 1 '[{"id":1,"status":"done","files_touched":["specs/999_probe/reports/01_probe-report.md"]}]'
echo "updated report" > "$repo17a/specs/999_probe/reports/01_probe-report.md"

out17a="$(run_phase_commit "$repo17a" --task 999 --project probe --phase 1 --message "case17a" --session sess_17a 2>&1)"
rc17a=$?
show17a="$(git -C "$repo17a" show --name-only --format= HEAD)"

if [ "$rc17a" -eq 0 ] && echo "$show17a" | grep -qF "specs/999_probe/reports/01_probe-report.md" && ! echo "$out17a" | grep -q "dropping out-of-scope"; then
  common_test_pass "Case 17 (missing file_scope key): the own-task-directory report commits without being dropped"
else
  common_test_fail "Case 17 (missing file_scope key): expected rc=0, report committed, no drop warning; got rc=$rc17a show='$show17a' out=$out17a"
fi

# Case 17b: file_scope present but empty ([]).
repo17b="$(build_repo)"
cat > "$repo17b/specs/state.json" <<'STATE_EOF'
{"active_projects":[{"project_number":999,"project_name":"probe","file_scope":[]}]}
STATE_EOF
git -C "$repo17b" add specs/state.json
git -C "$repo17b" commit -q -m "empty file_scope"
mkdir -p "$repo17b/specs/999_probe/reports"
echo "baseline report" > "$repo17b/specs/999_probe/reports/01_probe-report.md"
git -C "$repo17b" add specs/999_probe/reports/01_probe-report.md
git -C "$repo17b" commit -q -m "seed own-task-directory report"
write_progress "$repo17b" 1 '[{"id":1,"status":"done","files_touched":["specs/999_probe/reports/01_probe-report.md"]}]'
echo "updated report" > "$repo17b/specs/999_probe/reports/01_probe-report.md"

out17b="$(run_phase_commit "$repo17b" --task 999 --project probe --phase 1 --message "case17b" --session sess_17b 2>&1)"
rc17b=$?
show17b="$(git -C "$repo17b" show --name-only --format= HEAD)"

if [ "$rc17b" -eq 0 ] && echo "$show17b" | grep -qF "specs/999_probe/reports/01_probe-report.md" && ! echo "$out17b" | grep -q "dropping out-of-scope"; then
  common_test_pass "Case 17 (empty file_scope): the own-task-directory report commits without being dropped"
else
  common_test_fail "Case 17 (empty file_scope): expected rc=0, report committed, no drop warning; got rc=$rc17b show='$show17b' out=$out17b"
fi

# Case 17c: file_scope present but malformed (a bare string, not an array).
repo17c="$(build_repo)"
cat > "$repo17c/specs/state.json" <<'STATE_EOF'
{"active_projects":[{"project_number":999,"project_name":"probe","file_scope":"not-an-array"}]}
STATE_EOF
git -C "$repo17c" add specs/state.json
git -C "$repo17c" commit -q -m "malformed file_scope"
mkdir -p "$repo17c/specs/999_probe/reports"
echo "baseline report" > "$repo17c/specs/999_probe/reports/01_probe-report.md"
git -C "$repo17c" add specs/999_probe/reports/01_probe-report.md
git -C "$repo17c" commit -q -m "seed own-task-directory report"
write_progress "$repo17c" 1 '[{"id":1,"status":"done","files_touched":["specs/999_probe/reports/01_probe-report.md"]}]'
echo "updated report" > "$repo17c/specs/999_probe/reports/01_probe-report.md"

out17c="$(run_phase_commit "$repo17c" --task 999 --project probe --phase 1 --message "case17c" --session sess_17c 2>&1)"
rc17c=$?
show17c="$(git -C "$repo17c" show --name-only --format= HEAD)"

if [ "$rc17c" -eq 0 ] && echo "$show17c" | grep -qF "specs/999_probe/reports/01_probe-report.md" && ! echo "$out17c" | grep -q "dropping out-of-scope"; then
  common_test_pass "Case 17 (malformed file_scope): the own-task-directory report commits without being dropped"
else
  common_test_fail "Case 17 (malformed file_scope): expected rc=0, report committed, no drop warning; got rc=$rc17c show='$show17c' out=$out17c"
fi

# =====================================================================
# Case 18/19 (VERIFY 1 + VERIFY 2, same fixture run): a files_touched path outside the declared
# file_scope is STILL dropped from the commit with its existing WARNING and its existing
# issue-record.sh "scope excursion" row (the hard-constraint guard, unweakened) -- AND it is now
# additionally deposited into specs/999_probe/.return-meta.json's proposed_file_scope, so the
# genuine work is proposed forward rather than silently dropped-and-forgotten.
# =====================================================================
common_test_info "=== Case 18/19: a dropped path is proposed into proposed_file_scope, and the drop-and-warn guard survives intact ==="

repo18="$(build_repo)"
mkdir -p "$repo18/other"
echo "out of scope" > "$repo18/other/outside.txt"
git -C "$repo18" add other/outside.txt
git -C "$repo18" commit -q -m "seed out-of-scope file"
write_progress "$repo18" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt","other/outside.txt"]}]'
echo "mod a" > "$repo18/src/a.txt"
echo "mod outside" > "$repo18/other/outside.txt"

out18="$(run_phase_commit "$repo18" --task 999 --project probe --phase 1 --message "case18" --session sess_18 2>&1)"
rc18=$?
show18="$(git -C "$repo18" show --name-only --format= HEAD)"
proposed18="$(jq -c '.proposed_file_scope // []' "$repo18/specs/999_probe/.return-meta.json" 2>/dev/null)"

if [ "$rc18" -eq 0 ] && echo "$show18" | grep -qF "src/a.txt" && ! echo "$show18" | grep -qF "other/outside.txt"; then
  common_test_pass "Case 18: the commit still lands (src/a.txt) with other/outside.txt still dropped"
else
  common_test_fail "Case 18: expected rc=0, src/a.txt committed, other/outside.txt not; got rc=$rc18 show='$show18' out=$out18"
fi

if echo "$proposed18" | jq -e 'index("other/outside.txt") != null' >/dev/null 2>&1; then
  common_test_pass "Case 18 (VERIFY 1): other/outside.txt was deposited into proposed_file_scope"
else
  common_test_fail "Case 18 (VERIFY 1): expected other/outside.txt in proposed_file_scope; got $proposed18"
fi

if echo "$out18" | grep -q "WARNING.*dropping out-of-scope path 'other/outside.txt'"; then
  common_test_pass "Case 19 (VERIFY 2): the existing WARNING still fires for the dropped path"
else
  common_test_fail "Case 19 (VERIFY 2): expected the drop WARNING to still fire; got out=$out18"
fi

if [ -f "$repo18/specs/999_probe/issues.jsonl" ] && grep -q "scope excursion" "$repo18/specs/999_probe/issues.jsonl" \
  && grep -q "other/outside.txt" "$repo18/specs/999_probe/issues.jsonl"; then
  common_test_pass "Case 19 (VERIFY 2): the existing issue-record.sh scope-excursion row still fires"
else
  common_test_fail "Case 19 (VERIFY 2): expected a scope-excursion issue record naming other/outside.txt; got $(cat "$repo18/specs/999_probe/issues.jsonl" 2>/dev/null)"
fi

status18="$(git -C "$repo18" status --porcelain -- other/outside.txt)"
if [ -n "$status18" ]; then
  common_test_pass "Case 19 (VERIFY 2): the dropped path is still left uncommitted on disk for manual review"
else
  common_test_fail "Case 19 (VERIFY 2): the dropped path should remain modified/uncommitted"
fi

# =====================================================================
# Case 20 (idempotence): a second phase commit that drops the SAME path again leaves exactly one
# occurrence of that path in proposed_file_scope -- no duplicate append.
# =====================================================================
common_test_info "=== Case 20: a repeated drop of the same path appends to proposed_file_scope exactly once ==="

echo "mod outside again" > "$repo18/other/outside.txt"
out20="$(run_phase_commit "$repo18" --task 999 --project probe --phase 1 --message "case20" --session sess_20 2>&1)"
rc20=$?
proposed20="$(jq -c '.proposed_file_scope // []' "$repo18/specs/999_probe/.return-meta.json" 2>/dev/null)"
count20="$(echo "$proposed20" | jq '[.[] | select(. == "other/outside.txt")] | length' 2>/dev/null)"

if [ "$rc20" -eq 0 ] && [ "$count20" = "1" ]; then
  common_test_pass "Case 20: other/outside.txt appears exactly once in proposed_file_scope after a repeated drop"
else
  common_test_fail "Case 20: expected rc=0 and exactly one occurrence; got rc=$rc20 count=$count20 proposed=$proposed20 out=$out20"
fi

# =====================================================================
# Case 21 (VERIFY 3): the fixed-scope carve-out paths (the task directory, specs/TODO.md, and
# specs/state.json) are still staged unconditionally and are NEVER themselves proposed into
# proposed_file_scope, even when a files_touched entry names one of them directly.
# =====================================================================
common_test_info "=== Case 21: the fixed-scope carve-out paths are staged unconditionally and never proposed ==="

repo21="$(build_repo)"
write_progress "$repo21" 1 '[{"id":1,"status":"done","files_touched":["specs/TODO.md","specs/state.json","specs/999_probe/marker.txt"]}]'
echo "# TODO updated" > "$repo21/specs/TODO.md"
echo "a marker updated" > "$repo21/specs/999_probe/marker.txt"
# specs/state.json is rewritten in place with the same declared file_scope -- only its content
# bytes change, never its shape -- so the containment loop sees it as a genuinely modified path.
python3 - "$repo21/specs/state.json" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
data["active_projects"][0]["last_touched_marker"] = "case21"
with open(path, "w") as f:
    json.dump(data, f)
PYEOF

out21="$(run_phase_commit "$repo21" --task 999 --project probe --phase 1 --message "case21" --session sess_21 2>&1)"
rc21=$?
show21="$(git -C "$repo21" show --name-only --format= HEAD)"
proposed21="$(jq -c '.proposed_file_scope // []' "$repo21/specs/999_probe/.return-meta.json" 2>/dev/null)"

if [ "$rc21" -eq 0 ] && echo "$show21" | grep -qF "specs/TODO.md" && echo "$show21" | grep -qF "specs/state.json" \
  && echo "$show21" | grep -qF "specs/999_probe/marker.txt" \
  && ! echo "$out21" | grep -q "dropping out-of-scope"; then
  common_test_pass "Case 21 (VERIFY 3): the fixed-scope carve-out paths are staged unconditionally with no drop warning"
else
  common_test_fail "Case 21 (VERIFY 3): expected rc=0, all three carve-out paths committed, no drop warning; got rc=$rc21 show='$show21' out=$out21"
fi

if echo "$proposed21" | jq -e '(index("specs/TODO.md") // null) == null and (index("specs/state.json") // null) == null and (index("specs/999_probe/marker.txt") // null) == null' >/dev/null 2>&1; then
  common_test_pass "Case 21 (VERIFY 3): none of the carve-out paths were proposed into proposed_file_scope"
else
  common_test_fail "Case 21 (VERIFY 3): expected no carve-out path in proposed_file_scope; got $proposed21"
fi

# =====================================================================
# Case 22 (VERIFY 4): fail-open on a missing, empty, and malformed file_scope is unchanged by the
# new deposit -- the whole Containment Self-Check is skipped, so nothing is dropped AND nothing
# is proposed, for all three shapes, mirroring Case 17a/b/c's existing fixture shape.
# =====================================================================
common_test_info "=== Case 22 (VERIFY 4): fail-open on missing/empty/malformed file_scope -- nothing dropped, nothing proposed ==="

run_case22_shape() {
  local shape_label="$1" state_json="$2"
  local repo
  repo="$(build_repo)"
  printf '%s' "$state_json" > "$repo/specs/state.json"
  git -C "$repo" add specs/state.json
  git -C "$repo" commit -q -m "declare $shape_label file_scope"
  mkdir -p "$repo/other"
  echo "anything" > "$repo/other/anything.txt"
  git -C "$repo" add other/anything.txt
  git -C "$repo" commit -q -m "seed anything.txt"
  write_progress "$repo" 1 '[{"id":1,"status":"done","files_touched":["other/anything.txt"]}]'
  echo "modified anything" > "$repo/other/anything.txt"

  local out rc proposed
  out="$(run_phase_commit "$repo" --task 999 --project probe --phase 1 --message "case22-$shape_label" --session "sess_22_$shape_label" 2>&1)"
  rc=$?
  proposed="$(jq -c '.proposed_file_scope // []' "$repo/specs/999_probe/.return-meta.json" 2>/dev/null)"

  if [ "$rc" -eq 0 ] && ! echo "$out" | grep -q "dropping out-of-scope" \
    && echo "$proposed" | jq -e 'length == 0' >/dev/null 2>&1; then
    common_test_pass "Case 22 ($shape_label file_scope): fail-open preserved -- nothing dropped, nothing proposed"
  else
    common_test_fail "Case 22 ($shape_label file_scope): expected rc=0, no drop, empty proposed_file_scope; got rc=$rc proposed=$proposed out=$out"
  fi
}

run_case22_shape "missing" '{"active_projects":[{"project_number":999,"project_name":"probe"}]}'
run_case22_shape "empty" '{"active_projects":[{"project_number":999,"project_name":"probe","file_scope":[]}]}'
run_case22_shape "malformed" '{"active_projects":[{"project_number":999,"project_name":"probe","file_scope":"not-an-array"}]}'

# =====================================================================
# Case 23 (deposit-path fail-open): with .return-meta.json absent, and separately with it present
# but malformed JSON, a drop still warns, still records the issue, still commits, and the exit
# code matches the same fixture run with a valid .return-meta.json. The absent case must not
# create the file; the malformed case must not be overwritten.
# =====================================================================
common_test_info "=== Case 23: the proposed_file_scope deposit fails open when .return-meta.json is absent or malformed ==="

# Baseline: the same drop fixture with a valid (seeded) .return-meta.json, for the exit-code
# comparison below -- this is exactly Case 18/19's repo18 result (rc18, already captured above).

# Case 23a: .return-meta.json absent entirely.
repo23a="$(build_repo)"
rm -f "$repo23a/specs/999_probe/.return-meta.json"
mkdir -p "$repo23a/other"
echo "out of scope" > "$repo23a/other/outside.txt"
git -C "$repo23a" add other/outside.txt
git -C "$repo23a" commit -q -m "seed out-of-scope file (no .return-meta.json)"
write_progress "$repo23a" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt","other/outside.txt"]}]'
echo "mod a" > "$repo23a/src/a.txt"
echo "mod outside" > "$repo23a/other/outside.txt"

out23a="$(run_phase_commit "$repo23a" --task 999 --project probe --phase 1 --message "case23a" --session sess_23a 2>&1)"
rc23a=$?
show23a="$(git -C "$repo23a" show --name-only --format= HEAD)"

if [ "$rc23a" -eq "$rc18" ] \
  && echo "$out23a" | grep -q "WARNING.*dropping out-of-scope path 'other/outside.txt'" \
  && [ -f "$repo23a/specs/999_probe/issues.jsonl" ] && grep -q "scope excursion" "$repo23a/specs/999_probe/issues.jsonl" \
  && echo "$show23a" | grep -qF "src/a.txt" && ! echo "$show23a" | grep -qF "other/outside.txt"; then
  common_test_pass "Case 23a: an absent .return-meta.json still warns, still records the issue, still commits, same exit code as the valid-file baseline"
else
  common_test_fail "Case 23a: expected rc=$rc18, drop warning, issue record, src/a.txt committed, other/outside.txt not; got rc=$rc23a show='$show23a' out=$out23a"
fi

if [ ! -f "$repo23a/specs/999_probe/.return-meta.json" ]; then
  common_test_pass "Case 23a: .return-meta.json was NOT created (skip-if-absent, never create)"
else
  common_test_fail "Case 23a: .return-meta.json should not have been created; found: $(cat "$repo23a/specs/999_probe/.return-meta.json")"
fi

# Case 23b: .return-meta.json present but malformed JSON.
repo23b="$(build_repo)"
echo "{not valid json" > "$repo23b/specs/999_probe/.return-meta.json"
mkdir -p "$repo23b/other"
echo "out of scope" > "$repo23b/other/outside.txt"
git -C "$repo23b" add other/outside.txt
git -C "$repo23b" commit -q -m "seed out-of-scope file (malformed .return-meta.json)"
write_progress "$repo23b" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt","other/outside.txt"]}]'
echo "mod a" > "$repo23b/src/a.txt"
echo "mod outside" > "$repo23b/other/outside.txt"

out23b="$(run_phase_commit "$repo23b" --task 999 --project probe --phase 1 --message "case23b" --session sess_23b 2>&1)"
rc23b=$?
show23b="$(git -C "$repo23b" show --name-only --format= HEAD)"
content23b="$(cat "$repo23b/specs/999_probe/.return-meta.json")"

if [ "$rc23b" -eq "$rc18" ] \
  && echo "$out23b" | grep -q "WARNING.*dropping out-of-scope path 'other/outside.txt'" \
  && [ -f "$repo23b/specs/999_probe/issues.jsonl" ] && grep -q "scope excursion" "$repo23b/specs/999_probe/issues.jsonl" \
  && echo "$show23b" | grep -qF "src/a.txt" && ! echo "$show23b" | grep -qF "other/outside.txt"; then
  common_test_pass "Case 23b: a malformed .return-meta.json still warns, still records the issue, still commits, same exit code as the valid-file baseline"
else
  common_test_fail "Case 23b: expected rc=$rc18, drop warning, issue record, src/a.txt committed, other/outside.txt not; got rc=$rc23b show='$show23b' out=$out23b"
fi

if [ "$content23b" = "{not valid json" ]; then
  common_test_pass "Case 23b: the malformed .return-meta.json was left byte-for-byte untouched (no write on a malformed file)"
else
  common_test_fail "Case 23b: expected the malformed file untouched; got: $content23b"
fi

# =====================================================================
# Case 24 (VERIFY 5): the post-commit completeness check reports accurately under the new rule --
# a containment-dropped path is excluded from the surviving set the check verifies, so the check
# never reports the dropped path as un-landed. Reuses Case 18's repo and output (out18/show18).
# =====================================================================
common_test_info "=== Case 24 (VERIFY 5): the completeness check does not report the dropped path as un-landed ==="

if ! echo "$out18" | grep -q "completeness check failed"; then
  common_test_pass "Case 24 (VERIFY 5): no completeness-check failure is reported for a correctly-landed commit"
elif ! echo "$out18" | grep -A5 "files_touched path(s)" | grep -qF "other/outside.txt"; then
  common_test_pass "Case 24 (VERIFY 5): a completeness-check failure (if any) does not name the containment-dropped path"
else
  common_test_fail "Case 24 (VERIFY 5): the dropped path other/outside.txt was wrongly named among the un-landed completeness-check paths:
$out18"
fi

# =====================================================================
# Case 25 (deployed-tree loophole closure): a file_scope seeded with a bare `.claude/` entry no
# longer admits any `.claude/**` path -- the normalized is_contained() entry used to read the
# bare `.claude/` member as covering every deployed-tree path via its own "$entry/*" composition
# (the exact loophole the Hard Constraint forbids); the strip now removes the entry before
# is_contained() is even built. The `.claude/**` path is still dropped, still warned, and still
# issue-recorded -- exactly like a genuine out-of-territory excursion -- but it is NEVER deposited
# into proposed_file_scope (the deposit-site refusal). A sibling genuine (non-deployed)
# out-of-territory path in the SAME run is still dropped, warned, issue-recorded, AND deposited,
# confirming the refusal is scoped to deployed-tree paths only.
# =====================================================================
common_test_info "=== Case 25: a bare .claude/ file_scope entry no longer admits any .claude/** path (loophole closed); the drop is not deposited ==="

repo25="$(build_repo)"
cat > "$repo25/specs/state.json" <<'STATE25_EOF'
{"active_projects":[{"project_number":999,"project_name":"probe","file_scope":["src/a.txt",".claude/"]}]}
STATE25_EOF
git -C "$repo25" add specs/state.json
git -C "$repo25" commit -q -m "declare bare .claude/ file_scope"
mkdir -p "$repo25/other" "$repo25/.claude/scripts"
echo "out of scope" > "$repo25/other/outside.txt"
echo "deployed stray" > "$repo25/.claude/scripts/stray.sh"
git -C "$repo25" add other/outside.txt .claude/scripts/stray.sh
git -C "$repo25" commit -q -m "seed out-of-scope and deployed-tree files"
write_progress "$repo25" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt","other/outside.txt",".claude/scripts/stray.sh"]}]'
echo "mod a" > "$repo25/src/a.txt"
echo "mod outside" > "$repo25/other/outside.txt"
echo "mod stray" > "$repo25/.claude/scripts/stray.sh"

out25="$(run_phase_commit "$repo25" --task 999 --project probe --phase 1 --message "case25" --session sess_25 2>&1)"
rc25=$?
show25="$(git -C "$repo25" show --name-only --format= HEAD)"
proposed25="$(jq -c '.proposed_file_scope // []' "$repo25/specs/999_probe/.return-meta.json" 2>/dev/null)"

if [ "$rc25" -eq 0 ] && echo "$show25" | grep -qF "src/a.txt" \
  && ! echo "$show25" | grep -qF "other/outside.txt" \
  && ! echo "$show25" | grep -qF ".claude/scripts/stray.sh"; then
  common_test_pass "Case 25: src/a.txt commits; other/outside.txt and .claude/scripts/stray.sh are both dropped"
else
  common_test_fail "Case 25: expected rc=0, src/a.txt committed, both excursions dropped; got rc=$rc25 show='$show25' out=$out25"
fi

if echo "$out25" | grep -q "WARNING.*dropping out-of-scope path '.claude/scripts/stray.sh'"; then
  common_test_pass "Case 25: the deployed-tree path still draws the existing drop WARNING"
else
  common_test_fail "Case 25: expected the drop WARNING for .claude/scripts/stray.sh; got out=$out25"
fi

if [ -f "$repo25/specs/999_probe/issues.jsonl" ] && grep -q "scope excursion" "$repo25/specs/999_probe/issues.jsonl" \
  && grep -q "\.claude/scripts/stray\.sh" "$repo25/specs/999_probe/issues.jsonl"; then
  common_test_pass "Case 25: the deployed-tree path still draws the existing issue-record.sh scope-excursion row"
else
  common_test_fail "Case 25: expected a scope-excursion issue record naming .claude/scripts/stray.sh; got $(cat "$repo25/specs/999_probe/issues.jsonl" 2>/dev/null)"
fi

if echo "$out25" | grep -q "refusing to deposit '.claude/scripts/stray.sh'"; then
  common_test_pass "Case 25: the deposit-site refusal fires for the deployed-tree path"
else
  common_test_fail "Case 25: expected the deposit-site refusal warning for .claude/scripts/stray.sh; got out=$out25"
fi

if echo "$proposed25" | jq -e 'index(".claude/scripts/stray.sh") == null' >/dev/null 2>&1; then
  common_test_pass "Case 25: the deployed-tree path was NOT deposited into proposed_file_scope"
else
  common_test_fail "Case 25: .claude/scripts/stray.sh should never be deposited; got $proposed25"
fi

if echo "$proposed25" | jq -e 'index("other/outside.txt") != null' >/dev/null 2>&1; then
  common_test_pass "Case 25: the sibling genuine excursion (other/outside.txt) was still deposited"
else
  common_test_fail "Case 25: expected other/outside.txt still deposited (refusal must be scoped, not blanket); got $proposed25"
fi

# =====================================================================
# Case 26: a file_scope consisting SOLELY of `.claude/` strips to empty at THIS SCRIPT's own
# Containment Self-Check, which therefore fails open (skips itself) exactly like a missing/
# empty/malformed file_scope -- git-commit-phase.sh's OWN drop warning
# ("WARNING: git-commit-phase.sh: dropping out-of-scope path") never fires, and nothing is
# proposed into proposed_file_scope by THIS script.
#
# Deliberately NOT asserted here: the full end-to-end commit outcome (rc, whether the path
# actually lands in the commit). git-commit-scoped.sh carries its own SEPARATE V10 containment
# guard (context/standards/git-staging-scope.md's "Three Containment sites, not one" -- Site 3),
# which re-reads the UNSTRIPPED file_scope directly from specs/state.json and is not touched by
# this task's declared file_scope (git-commit-scoped.sh and test-git-commit-scoped.sh are not
# members of it). A `.claude/`-only declared file_scope therefore still interacts with Site 3's
# own (separately scoped, un-patched) containment predicate for a files_touched path that is not
# otherwise carve-out-admitted there -- a residual, OUT-OF-SCOPE-FOR-THIS-TASK gap recorded via
# issue-record.sh rather than silently masked by weakening this assertion to match whatever Site
# 3 happens to do. See this task's own implementation summary for the full citation.
# =====================================================================
common_test_info "=== Case 26: a file_scope of only .claude/ strips to empty at THIS script's own Containment Self-Check (fails open at Site 2 only) ==="

repo26="$(build_repo)"
cat > "$repo26/specs/state.json" <<'STATE26_EOF'
{"active_projects":[{"project_number":999,"project_name":"probe","file_scope":[".claude/"]}]}
STATE26_EOF
git -C "$repo26" add specs/state.json
git -C "$repo26" commit -q -m "declare claude-only file_scope"
write_progress "$repo26" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt"]}]'
echo "mod a" > "$repo26/src/a.txt"

out26="$(run_phase_commit "$repo26" --task 999 --project probe --phase 1 --message "case26" --session sess_26 2>&1)"
proposed26="$(jq -c '.proposed_file_scope // []' "$repo26/specs/999_probe/.return-meta.json" 2>/dev/null)"

if ! echo "$out26" | grep -q "WARNING: .*: dropping out-of-scope path"; then
  common_test_pass "Case 26: git-commit-phase.sh's OWN Containment Self-Check never fires its drop warning (fails open at Site 2)"
else
  common_test_fail "Case 26: git-commit-phase.sh's own Self-Check should have failed open (skipped itself) for a claude-only file_scope; got out=$out26"
fi

if echo "$proposed26" | jq -e 'length == 0' >/dev/null 2>&1; then
  common_test_pass "Case 26: nothing proposed into proposed_file_scope (Site 2's check never ran)"
else
  common_test_fail "Case 26: expected empty proposed_file_scope; got $proposed26"
fi

# =====================================================================
# Case 27 (PART B within-dispatch annotation): a path already recorded in proposed_file_scope
# earlier in THIS dispatch (a simulated earlier phase's own drop) draws an ANNOTATED warning on
# a subsequent phase's commit of the same path -- pointing at the already-known status and the
# scoped-follow-up-commit remedy -- while every pre-existing behavior (still dropped from
# staging, still issue-recorded, still deposited, idempotently) is UNCHANGED. A true admit-via-
# union design was built and rejected (see git-commit-phase.sh's own "WITHIN-DISPATCH
# proposed_file_scope LOOKUP (PART B)" header subsection for the full reasoning and the Site-3
# residual); this is the narrower, safe alternative actually shipped.
# =====================================================================
common_test_info "=== Case 27: a path already known in proposed_file_scope draws an annotated (not suppressed) repeat-drop warning ==="

repo27="$(build_repo)"
mkdir -p "$repo27/other"
echo "out of scope" > "$repo27/other/outside.txt"
git -C "$repo27" add other/outside.txt
git -C "$repo27" commit -q -m "seed out-of-scope file"
write_progress "$repo27" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt","other/outside.txt"]}]'
echo "mod a" > "$repo27/src/a.txt"
echo "mod outside" > "$repo27/other/outside.txt"

# First drop (phase 1): plain warning, no annotation yet (nothing known before this run).
out27a="$(run_phase_commit "$repo27" --task 999 --project probe --phase 1 --message "case27a" --session sess_27a 2>&1)"
if echo "$out27a" | grep -qF "already recorded in proposed_file_scope"; then
  common_test_fail "Case 27a: the FIRST drop should not yet carry the already-known annotation; got out=$out27a"
else
  common_test_pass "Case 27a: the first drop draws the plain (unannotated) warning"
fi

# Second drop (simulated subsequent phase 2, same repo, same path): annotated warning.
write_progress "$repo27" 2 '[{"id":1,"status":"done","files_touched":["other/outside.txt"]}]'
echo "mod outside again" > "$repo27/other/outside.txt"
out27b="$(run_phase_commit "$repo27" --task 999 --project probe --phase 2 --message "case27b" --session sess_27b 2>&1)"
rc27b=$?
proposed27b="$(jq -c '.proposed_file_scope // []' "$repo27/specs/999_probe/.return-meta.json" 2>/dev/null)"
count27b="$(echo "$proposed27b" | jq '[.[] | select(. == "other/outside.txt")] | length' 2>/dev/null)"

if echo "$out27b" | grep -qF "already recorded in proposed_file_scope earlier in this dispatch -- land it with a scoped follow-up commit"; then
  common_test_pass "Case 27b: the SECOND (subsequent-phase) drop of the same path draws the already-known annotation"
else
  common_test_fail "Case 27b: expected the already-known annotation on the second drop; got out=$out27b"
fi

if echo "$out27b" | grep -q "issue-record\|scope excursion" || { [ -f "$repo27/specs/999_probe/issues.jsonl" ] && [ "$(grep -c "other/outside.txt" "$repo27/specs/999_probe/issues.jsonl")" -ge 2 ]; }; then
  common_test_pass "Case 27b: the issue-record.sh call still fires on the repeat drop (unsuppressed)"
else
  common_test_fail "Case 27b: expected the issue-record.sh call to still fire on the repeat drop; got $(cat "$repo27/specs/999_probe/issues.jsonl" 2>/dev/null)"
fi

if [ "$count27b" = "1" ]; then
  common_test_pass "Case 27b: proposed_file_scope still holds exactly one occurrence (idempotent deposit unaffected)"
else
  common_test_fail "Case 27b: expected exactly one occurrence; got count=$count27b proposed=$proposed27b"
fi

if [ "$rc27b" -eq 0 ]; then
  common_test_pass "Case 27b: the repeat-drop commit still exits 0 (no regression -- the issue-record.sh append keeps the commit non-empty)"
else
  common_test_fail "Case 27b: expected rc=0; got rc=$rc27b out=$out27b"
fi

# =====================================================================
# Case 28: a deployed-tree path planted DIRECTLY into proposed_file_scope (bypassing
# propose_file_scope_addition()'s own deposit-site refusal, e.g. by a hand edit) is excluded
# from the already-known lookup -- it must never be annotated as "land it with a follow-up
# commit", since a deployed-tree path is never legitimate to land at all. The drop itself is
# still the plain, unannotated warning.
# =====================================================================
common_test_info "=== Case 28: a deployed-tree path planted directly in proposed_file_scope is excluded from the already-known annotation ==="

repo28="$(build_repo)"
printf '%s' '{"status":"in_progress","artifacts":[],"proposed_file_scope":[".claude/scripts/planted.sh"]}' > "$repo28/specs/999_probe/.return-meta.json"
mkdir -p "$repo28/.claude/scripts"
echo "planted" > "$repo28/.claude/scripts/planted.sh"
git -C "$repo28" add .claude/scripts/planted.sh
git -C "$repo28" commit -q -m "seed a planted deployed-tree file"
write_progress "$repo28" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt",".claude/scripts/planted.sh"]}]'
echo "mod a" > "$repo28/src/a.txt"
echo "mod planted" > "$repo28/.claude/scripts/planted.sh"

out28="$(run_phase_commit "$repo28" --task 999 --project probe --phase 1 --message "case28" --session sess_28 2>&1)"

if echo "$out28" | grep -qF "already recorded in proposed_file_scope"; then
  common_test_fail "Case 28: a planted deployed-tree proposed_file_scope entry must never draw the already-known annotation; got out=$out28"
else
  common_test_pass "Case 28: the planted deployed-tree entry draws no already-known annotation"
fi

if echo "$out28" | grep -q "WARNING.*dropping out-of-scope path '.claude/scripts/planted.sh'"; then
  common_test_pass "Case 28: the deployed-tree path is still dropped with the plain warning"
else
  common_test_fail "Case 28: expected the plain drop warning for .claude/scripts/planted.sh; got out=$out28"
fi

# =====================================================================
# Case 29 (disjoint source-store fixture): a files_touched path classified SOURCE_STORE against
# a genuinely disjoint second repository is dropped from THIS repository's commit with wording
# naming that repository's root -- never the undeclared-scope wording -- and recorded under the
# "source store excursion" class, never "scope excursion".
# =====================================================================
common_test_info "=== Case 29: disjoint source-store fixture classified and reported distinctly ==="

repo29="$(build_repo)"
read -r source_repo29 ssp29 < <(build_source_store_repo "$repo29")
write_progress "$repo29" 1 "[{\"id\":1,\"status\":\"done\",\"files_touched\":[\"src/a.txt\",\"${ssp29}\"]}]"
echo "mod a" > "$repo29/src/a.txt"

before29=$(git -C "$repo29" rev-list --count HEAD)
out29="$(run_phase_commit "$repo29" --task 999 --project probe --phase 1 --message "case29" --session sess_29 2>&1)"
rc29=$?
after29=$(git -C "$repo29" rev-list --count HEAD)
show29="$(git -C "$repo29" show --name-only --format= HEAD)"

if [ "$rc29" -eq 0 ] && [ "$after29" -eq $((before29 + 1)) ] && echo "$show29" | grep -qF "src/a.txt" && ! echo "$show29" | grep -qF "doc.md"; then
  common_test_pass "Case 29: src/a.txt lands; the source-store path does not; exit 0"
else
  common_test_fail "Case 29: expected rc=0, HEAD+1, src/a.txt landed, doc.md absent; got rc=$rc29 before=$before29 after=$after29 show='$show29' out=$out29"
fi

if echo "$out29" | grep -qF "$source_repo29" && echo "$out29" | grep -qF "extension 'core'"; then
  common_test_pass "Case 29: the warning names the resolved source repository root and the extension"
else
  common_test_fail "Case 29: expected the warning to name '$source_repo29' and extension 'core'; got out=$out29"
fi

if echo "$out29" | grep -qF "not contained in this task's declared file_scope"; then
  common_test_fail "Case 29: the SOURCE_STORE drop must NEVER use the undeclared-scope wording; got out=$out29"
else
  common_test_pass "Case 29: the SOURCE_STORE drop never reads as an undeclared-scope miss"
fi

if [ -f "$repo29/specs/999_probe/issues.jsonl" ] && grep -q "source store excursion" "$repo29/specs/999_probe/issues.jsonl"; then
  common_test_pass "Case 29: recorded under the distinct 'source store excursion' issue class"
else
  common_test_fail "Case 29: expected a 'source store excursion' issue record; got $(cat "$repo29/specs/999_probe/issues.jsonl" 2>/dev/null)"
fi

if [ -f "$repo29/specs/999_probe/issues.jsonl" ] && grep -q "scope excursion" "$repo29/specs/999_probe/issues.jsonl"; then
  common_test_fail "Case 29: must NOT also record under the ordinary 'scope excursion' class; got $(cat "$repo29/specs/999_probe/issues.jsonl" 2>/dev/null)"
else
  common_test_pass "Case 29: no ordinary 'scope excursion' record was created for this path"
fi

meta29="$(cat "$repo29/specs/999_probe/.return-meta.json" 2>/dev/null || echo '{}')"
if echo "$meta29" | jq -e --arg p "$ssp29" '(.proposed_file_scope // []) | index($p)' >/dev/null 2>&1; then
  common_test_fail "Case 29: the source-store path must NEVER be deposited into proposed_file_scope; got $meta29"
else
  common_test_pass "Case 29: the source-store path was not deposited into proposed_file_scope"
fi

# =====================================================================
# Case 30 (genuinely out-of-repository, unclaimed): a files_touched path resolving outside this
# repository that no extension's source_dir claims is dropped and reported naming the resolved
# directory, under the same "source store excursion" class.
# =====================================================================
common_test_info "=== Case 30: genuinely out-of-repository path, unclaimed by any extension ==="

repo30="$(build_repo)"
write_progress "$repo30" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt","../outside-this-repo-entirely.txt"]}]'
echo "mod a" > "$repo30/src/a.txt"
mkdir -p "$(dirname "$repo30")"
echo "outside" > "$(dirname "$repo30")/outside-this-repo-entirely.txt"

out30="$(run_phase_commit "$repo30" --task 999 --project probe --phase 1 --message "case30" --session sess_30 2>&1)"
rc30=$?
show30="$(git -C "$repo30" show --name-only --format= HEAD)"

if [ "$rc30" -eq 0 ] && echo "$show30" | grep -qF "src/a.txt"; then
  common_test_pass "Case 30: src/a.txt still lands; exit 0"
else
  common_test_fail "Case 30: expected rc=0 and src/a.txt landed; got rc=$rc30 show='$show30' out=$out30"
fi

if echo "$out30" | grep -qF "lies outside this repository" && ! echo "$out30" | grep -qF "not contained in this task's declared file_scope"; then
  common_test_pass "Case 30: the drop is reported as outside this repository, never as an undeclared-scope miss"
else
  common_test_fail "Case 30: expected the out-of-repository wording, never the undeclared-scope wording; got out=$out30"
fi

rm -f "$(dirname "$repo30")/outside-this-repo-entirely.txt"

# =====================================================================
# Case 31 (acceptance criterion 3 regression pin): an in-repository path genuinely outside the
# declared file_scope, run in the SAME dispatch as a disjoint source-store classification (Case
# 29's fixture extended with one more files_touched entry), still produces TODAY'S EXACT warning
# text, TODAY'S EXACT "scope excursion" class, and TODAY'S deposit -- unchanged by this phase.
# =====================================================================
common_test_info "=== Case 31: acceptance criterion 3 -- in-repository undeclared path is unchanged ==="

repo31="$(build_repo)"
read -r _ ssp31 < <(build_source_store_repo "$repo31")
write_progress "$repo31" 1 "[{\"id\":1,\"status\":\"done\",\"files_touched\":[\"src/a.txt\",\"other/outside.txt\",\"${ssp31}\"]}]"
echo "mod a" > "$repo31/src/a.txt"
mkdir -p "$repo31/other"
echo "outside" > "$repo31/other/outside.txt"

out31="$(run_phase_commit "$repo31" --task 999 --project probe --phase 1 --message "case31" --session sess_31 2>&1)"
show31="$(git -C "$repo31" show --name-only --format= HEAD)"

if echo "$out31" | grep -qF "dropping out-of-scope path 'other/outside.txt' from phase commit — not in task 999's declared file_scope"; then
  common_test_pass "Case 31: the in-repository undeclared path still produces today's exact warning text"
else
  common_test_fail "Case 31: expected today's exact scope-excursion warning for other/outside.txt; got out=$out31"
fi

if [ -f "$repo31/specs/999_probe/issues.jsonl" ] && grep -q "scope excursion" "$repo31/specs/999_probe/issues.jsonl" \
  && grep -q "other/outside.txt" "$repo31/specs/999_probe/issues.jsonl"; then
  common_test_pass "Case 31: today's exact 'scope excursion' class and what-happened string are recorded for other/outside.txt"
else
  common_test_fail "Case 31: expected the existing scope-excursion issue record for other/outside.txt; got $(cat "$repo31/specs/999_probe/issues.jsonl" 2>/dev/null)"
fi

meta31="$(cat "$repo31/specs/999_probe/.return-meta.json" 2>/dev/null || echo '{}')"
if echo "$meta31" | jq -e '(.proposed_file_scope // []) | index("other/outside.txt")' >/dev/null 2>&1; then
  common_test_pass "Case 31: other/outside.txt is still deposited into proposed_file_scope, exactly as before this phase"
else
  common_test_fail "Case 31: expected other/outside.txt deposited into proposed_file_scope; got $meta31"
fi

if echo "$show31" | grep -qF "src/a.txt" && ! echo "$show31" | grep -qF "doc.md" && ! echo "$show31" | grep -qF "other/outside.txt"; then
  common_test_pass "Case 31: src/a.txt lands; the source-store path and the undeclared path both do not"
else
  common_test_fail "Case 31: expected only src/a.txt landed; got show='$show31'"
fi

# =====================================================================
# Case 32 (inertness in THIS repository): source_store_classify is sourced (the library is
# present), but the classified repository equals the committing repository's own root -- every
# agent-system/** path must classify IN_REPO and proceed through the ordinary Containment
# Self-Check unaffected, never through the new SOURCE_STORE branch.
# =====================================================================
common_test_info "=== Case 32: inertness -- source_dir resolves inside the committing repo's own root ==="

repo32="$(build_repo)"
mkdir -p "$repo32/agent-system/extensions/core"
echo "owned source store" > "$repo32/agent-system/extensions/core/owned.md"
cat > "$repo32/.claude-extensions.json" <<EOF
{"extensions":{"core":{"source_dir":"$repo32/agent-system/extensions/core"}}}
EOF
cat > "$repo32/specs/state.json" <<'STATE_EOF'
{"active_projects":[{"project_number":999,"project_name":"probe","file_scope":["src/a.txt","src/b.txt","src/c.txt","agent-system/extensions/core/owned.md"]}]}
STATE_EOF
git -C "$repo32" add -A
git -C "$repo32" commit -q -m "seed owned source store"

write_progress "$repo32" 1 '[{"id":1,"status":"done","files_touched":["src/a.txt","agent-system/extensions/core/owned.md"]}]'
echo "mod a" > "$repo32/src/a.txt"
echo "mod owned" > "$repo32/agent-system/extensions/core/owned.md"

out32="$(run_phase_commit "$repo32" --task 999 --project probe --phase 1 --message "case32" --session sess_32 2>&1)"
rc32=$?
show32="$(git -C "$repo32" show --name-only --format= HEAD)"

if [ "$rc32" -eq 0 ] && echo "$show32" | grep -qF "src/a.txt" && echo "$show32" | grep -qF "agent-system/extensions/core/owned.md"; then
  common_test_pass "Case 32: inertness holds -- both paths land with no classification drop (the extension's own repository committing its own source store)"
else
  common_test_fail "Case 32: expected both src/a.txt and owned.md landed with rc=0; got rc=$rc32 show='$show32' out=$out32"
fi

if echo "$out32" | grep -qF "source store" || echo "$out32" | grep -qF "lies outside this repository"; then
  common_test_fail "Case 32: no source-store/out-of-repository classification warning must fire for an owned extension; got out=$out32"
else
  common_test_pass "Case 32: no classification warning fired (inertness)"
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
