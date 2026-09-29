#!/usr/bin/env bash
# test-dispatch-isolation-fixture.sh - Acceptance fixture for the working-tree/build isolation
# posture decision record (context/patterns/batch-orchestration-guardrails.md). Reproduces the
# observed batch shape from the two live incidents this task's own dispatch cites -- two
# concurrently dispatched tasks in ONE repo, both editing the SAME shared markdown file, one of
# them invoking an unguarded `lake` -- and demonstrates that the chosen posture (per-dispatch git
# worktree isolation for the lean4/cslib family, PLUS a contended-path refusal for the shared
# tree everything else keeps using) makes the observed cross-task commit bleed (mode 1b)
# structurally impossible on the isolated side, and refused rather than silent on the shared-tree
# side.
#
# Harness: throwaway scratch git repo under mktemp -d (no dependency on any reference consumer
# repo, no network, no real Lean toolchain). `.claude/scripts/` is populated with the REAL
# dispatch-worktree.sh, git-commit-scoped.sh, task-lock.sh, and lake-build-guard.sh -- this
# fixture drives the real call graph directly (provision/land/release, commit, claim-acquire/
# claim-release), the same sandbox model test-dispatch-worktree.sh and test-git-commit-scoped.sh
# already establish, rather than a stubbed approximation. `lake` is stubbed via
# LAKE_BUILD_GUARD_LAKE_BIN (a documented test seam), never placed on PATH -- no real Lean
# toolchain is invoked anywhere in this file.
#
# "Run the real dispatch-prep path" (the plan's own phrasing for this phase) is interpreted here
# as: drive dispatch-worktree.sh's provision/land/release and git-commit-scoped.sh's --task
# refusal for REAL, end to end -- the actual lifecycle machinery Phases 4-9 built -- rather than
# additionally re-driving orchestrate-cycle-plan.sh's OWN selection/manifest-producer code paths,
# which are already covered end to end by that script's own suite (Groups 30-31 in
# test-orchestrate-cycle-plan.sh). This fixture's job is the cross-script INTEGRATION outcome
# (no bleed, an honest conflict, separate .lake/, a refused shared-tree commit, clean teardown),
# which is exactly what the plan's own Verification bullets for this phase assert.
#
# "A test that cannot fail proves nothing" (Case 1's own no-bleed assertion): rather than
# reaching into orchestrate-cycle-plan.sh's private task_selected_for_worktree_isolation()
# predicate and temporarily forcing it false (that predicate lives in a DIFFERENT script this
# fixture does not otherwise drive), Case 5 below is the comparative negative control: the
# IDENTICAL two-writer same-file edit pattern, run on a SHARED (non-isolated) tree with the V5
# refusal check OMITTED (no --task), demonstrating the silent bleed the isolated Case 1 does NOT
# exhibit. This is the direct, reproducible negative of the observed incident, proving Case 1's
# assertion is not vacuous by showing the SAME pattern fails without the fix.
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

# --- Loud-skip discipline: verify every required script exists and is executable first. ---
REQUIRED_SCRIPTS=(dispatch-worktree.sh git-commit-scoped.sh task-lock.sh lake-build-guard.sh \
                   deploy-root-guard.sh lib/common.sh lib/task-lookup-lib.sh)
missing=()
for f in "${REQUIRED_SCRIPTS[@]}"; do
  [ -f "$SRC_SCRIPTS_DIR/$f" ] || missing+=("$f")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "ERROR: test-dispatch-isolation-fixture.sh cannot run -- missing required script(s) under $SRC_SCRIPTS_DIR: ${missing[*]}" >&2
  exit 1
fi
for f in dispatch-worktree.sh git-commit-scoped.sh task-lock.sh lake-build-guard.sh; do
  if [ ! -x "$SRC_SCRIPTS_DIR/$f" ]; then
    fail "SKIP-GUARD: $SRC_SCRIPTS_DIR/$f has lost its exec bit"
  fi
done
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 1
fi

TOP_WORKDIR="$(mktemp -d)"
# cleanup() is invoked indirectly via `trap cleanup EXIT`.
# shellcheck disable=SC2329
cleanup() {
  if [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ]; then
    find "$TOP_WORKDIR" -maxdepth 1 -type d -name 'repo-*' 2>/dev/null | while IFS= read -r r; do
      git -C "$r" worktree prune >/dev/null 2>&1 || true
    done
    rm -rf "$TOP_WORKDIR"
  fi
}
trap cleanup EXIT

# --- build_repo <name> -- scratch repo with the real scripts deployed under .claude/scripts/,
# a seed commit carrying docs/shared.md, and a .gitignore covering every ephemeral runtime path
# this fixture's own scripts write (matching test-dispatch-worktree.sh's build_repo exactly, plus
# the two Phase 8/9 runtime paths). .claude/ is deliberately left UNTRACKED (see that file's own
# comment for the "cp -al would nest a copy inside a checked-out .claude/" hazard this avoids). ---
build_repo() {
  local name="$1" dir
  dir="$TOP_WORKDIR/repo-$name"
  mkdir -p "$dir/.claude/scripts/lib"
  for f in "${REQUIRED_SCRIPTS[@]}"; do
    cp "$SRC_SCRIPTS_DIR/$f" "$dir/.claude/scripts/$f"
    case "$f" in
      lib/*) : ;;
      *) chmod +x "$dir/.claude/scripts/$f" ;;
    esac
  done

  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"

  cat > "$dir/.gitignore" <<'EOF'
/.claude/
/.orchestrate-worktrees/
/specs/.worktree-registry/
/specs/.contention-manifest/
/specs/.contention-claims/
EOF

  mkdir -p "$dir/specs" "$dir/docs"
  echo "line1" > "$dir/docs/shared.md"
  echo '{"seed":true}' > "$dir/specs/state.json"
  git -C "$dir" add .gitignore docs/shared.md specs/state.json
  git -C "$dir" commit -q -m "seed"

  echo "$dir"
}

# --- run_dw <repo> <args...> / run_commit <repo> <args...> / run_tl <repo> <args...> -- invoke
# the repo's own deployed copies. ---
run_dw() { local repo="$1"; shift; (cd "$repo" && bash .claude/scripts/dispatch-worktree.sh "$@"); }
run_commit() { local repo="$1"; shift; (cd "$repo" && bash .claude/scripts/git-commit-scoped.sh "$@"); }
run_tl() { local repo="$1"; shift; (cd "$repo" && bash .claude/scripts/task-lock.sh "$@"); }

# task-ref-ok:begin category 6-adjacent: every "<task_number>-<seq>" and "task #NNN" literal
# below is fixture data exercising dispatch-worktree.sh's/git-commit-scoped.sh's OWN
# branch/registry/claim-identity conventions, mirroring the observed 2026-09-09 BimodalLogic
# incident's own fixture numbers (574/575) for direct traceability to that report -- never a
# citation of THIS repo's own ephemeral task tracker.

# =====================================================================================================
# Case 1-2: no bleed + honest conflict verdict -- the core acceptance test. Two worktree-isolated
# "dispatches" (candidates #574, #575) both edit docs/shared.md's ONE line distinctly, from the
# SAME base. #574 lands first (clean). #575's land then surfaces an EXPLICIT conflict verdict
# (never a silent/magical merge), with its branch and worktree preserved.
# =====================================================================================================
info "Case 1-2: worktree isolation -- no bleed on a clean land, honest conflict on the second"

repo1="$(build_repo iso)"

out_p1="$(run_dw "$repo1" provision 574 --session sess1 --seq 1)"
path_574="$(echo "$out_p1" | jq -r '.path')"
branch_574="$(echo "$out_p1" | jq -r '.branch')"
out_p2="$(run_dw "$repo1" provision 575 --session sess1 --seq 1)"
path_575="$(echo "$out_p2" | jq -r '.path')"
branch_575="$(echo "$out_p2" | jq -r '.branch')"

if [ -n "$path_574" ] && [ -d "$path_574" ] && [ -n "$path_575" ] && [ -d "$path_575" ] && [ "$path_574" != "$path_575" ]; then
  pass "Case 1: both candidates provisioned into distinct worktree directories"
else
  fail "Case 1: provisioning failed or produced overlapping paths (574='$path_574' 575='$path_575')"
fi

# Both worktrees branch from the SAME seed HEAD (line1) -- edit the SAME line distinctly, from
# that same base, exactly reproducing "both editing one shared markdown file" from independent,
# non-diverged starting points.
echo "line1-574" > "$path_574/docs/shared.md"
( cd "$path_574" && git add docs/shared.md && git -c user.email=t@t.com -c user.name=T commit -q -m "574 edit" )
echo "line1-575" > "$path_575/docs/shared.md"
( cd "$path_575" && git add docs/shared.md && git -c user.email=t@t.com -c user.name=T commit -q -m "575 edit" )

land_574="$(run_dw "$repo1" land 574 --session sess1)"
verdict_574="$(echo "$land_574" | jq -r '.verdict')"
if [ "$verdict_574" = "landed" ]; then
  pass "Case 1: candidate #574 lands cleanly (verdict=landed, no prior divergence)"
else
  fail "Case 1: expected verdict=landed for #574, got: $land_574"
fi

head_content_after_574="$(cat "$repo1/docs/shared.md" 2>/dev/null)"
if [ "$head_content_after_574" = "line1-574" ]; then
  pass "Case 1: the main tree carries ONLY #574's own edit after its land (no bleed of #575's content, which does not exist yet)"
else
  fail "Case 1: expected docs/shared.md='line1-574' after #574's land, got: '$head_content_after_574'"
fi

land_575="$(run_dw "$repo1" land 575 --session sess1)"
verdict_575="$(echo "$land_575" | jq -r '.verdict')"
conflict_paths_575="$(echo "$land_575" | jq -c '.paths // []')"

if [ "$verdict_575" = "conflict" ]; then
  pass "Case 2: candidate #575's land surfaces an EXPLICIT conflict verdict (not a silent/magical merge)"
else
  fail "Case 2: expected verdict=conflict for #575 (main tree now diverges: line1-574 vs branch's line1-575), got: $land_575"
fi
if echo "$conflict_paths_575" | grep -q "docs/shared.md"; then
  pass "Case 2: the conflict verdict names docs/shared.md as the conflicted path"
else
  fail "Case 2: expected docs/shared.md in the conflict verdict's paths, got: $conflict_paths_575"
fi

git_merge_state="$(cd "$repo1" && git status --porcelain=v1 2>/dev/null | grep -c '^UU' || true)"
if [ "${git_merge_state:-0}" -eq 0 ]; then
  pass "Case 2: the aborted conflict leaves no in-progress merge (git merge --abort ran)"
else
  fail "Case 2: expected no in-progress merge state after the abort, found $git_merge_state unmerged entr(y/ies)"
fi

head_after_conflict="$(cat "$repo1/docs/shared.md" 2>/dev/null)"
if [ "$head_after_conflict" = "line1-574" ] && ! echo "$head_after_conflict" | grep -q "575"; then
  pass "Case 2 (no-bleed, the direct negative of the observed incident): the main tree's docs/shared.md after the conflict still carries ONLY #574's content -- #575's content never bled in"
else
  fail "Case 2: expected docs/shared.md to still read exactly 'line1-574' (no bleed), got: '$head_after_conflict'"
fi

if git -C "$repo1" show "refs/heads/${branch_575}:docs/shared.md" 2>/dev/null | grep -q "^line1-575$"; then
  pass "Case 2: #575's own branch still carries its own content, untouched, preserved for human resolution"
else
  fail "Case 2: expected #575's branch to still carry 'line1-575'"
fi
if (cd "$repo1" && git worktree list) | grep -q "$path_575"; then
  pass "Case 2: #575's worktree is preserved (not released) pending conflict resolution"
else
  fail "Case 2: #575's worktree was unexpectedly removed after a conflict"
fi

# Clean up #574 (already landed) and simulate an operator resolving #575's conflict for teardown
# purposes -- dispatch-worktree.sh's own `release` deliberately never deletes a branch (durable
# git history, left for inspection; see that script's header), so this fixture's own teardown
# does so explicitly for BOTH candidates, the same way an operator would after resolving the
# conflict by hand.
run_dw "$repo1" release 574 >/dev/null
( cd "$repo1" && git branch -D "$branch_574" >/dev/null 2>&1 || true )
( cd "$repo1" && git worktree remove --force "$path_575" >/dev/null 2>&1 || true )
( cd "$repo1" && git branch -D "$branch_575" >/dev/null 2>&1 || true )
rm -f "$repo1/specs/.worktree-registry/575-1.json" 2>/dev/null || true

# =====================================================================================================
# Case 3: mode-2 -- isolated dispatches use SEPARATE .lake directories, so an unguarded `lake`
# call in one cannot collide with a guarded build in the sibling.
# =====================================================================================================
info "Case 3: mode 2 -- isolated worktrees hardlink-clone SEPARATE .lake directories"

repo3="$(build_repo lake)"
mkdir -p "$repo3/.lake"
echo "main-tree-baseline" > "$repo3/.lake/baseline.marker"
# lake-build-guard.sh resolves its project root by walking up for a lakefile -- a minimal, TRACKED
# stub (so it is checked out into every worktree by `git worktree add`, exactly like a real
# lakefile would be) is enough; no real Lean toolchain ever parses it (the `lake` binary itself is
# stubbed via LAKE_BUILD_GUARD_LAKE_BIN below).
echo 'name = "stub"' > "$repo3/lakefile.toml"
git -C "$repo3" add lakefile.toml
git -C "$repo3" commit -q -m "add stub lakefile"

out3a="$(run_dw "$repo3" provision 601 --session sess3 --seq 1)"
path_601="$(echo "$out3a" | jq -r '.path')"
branch_601="$(echo "$out3a" | jq -r '.branch')"
out3b="$(run_dw "$repo3" provision 602 --session sess3 --seq 1)"
path_602="$(echo "$out3b" | jq -r '.path')"
branch_602="$(echo "$out3b" | jq -r '.branch')"

if [ -f "$path_601/.lake/baseline.marker" ] && [ -f "$path_602/.lake/baseline.marker" ]; then
  pass "Case 3: both worktrees hardlink-cloned the main tree's .lake/ baseline"
else
  fail "Case 3: baseline.marker missing from one or both worktrees' .lake/ (601='$path_601' 602='$path_602')"
fi

# A stub `lake` (no real Lean toolchain): `build` writes a marker file naming its own CWD's
# .lake/, so a collision would show up as the WRONG worktree's marker.
cat > "$TOP_WORKDIR/stub-lake" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "build" ]; then
  mkdir -p .lake
  echo "built-by-$$" > .lake/build-guard.marker
  exit 0
fi
exit 0
EOF
chmod +x "$TOP_WORKDIR/stub-lake"

# Unguarded call in worktree #601 (simulating the observed incident's self-inflicted collision --
# an unguarded caller bypassing lake-build-guard.sh's opt-in mutex entirely).
( cd "$path_601" && LAKE_BUILD_GUARD_LAKE_BIN="$TOP_WORKDIR/stub-lake" "$TOP_WORKDIR/stub-lake" build )
# Guarded call in worktree #602, via the real lake-build-guard.sh.
# cd INTO the worktree itself (not --dir from outside): --dir only steers project-root
# resolution for the lock/result file paths -- the wrapped `lake` command itself always runs
# from the guard's own current working directory, exactly as a real caller invokes it from
# inside the project it is building.
guard_out_602="$(cd "$path_602" && LAKE_BUILD_GUARD_LAKE_BIN="$TOP_WORKDIR/stub-lake" bash "$repo3/.claude/scripts/lake-build-guard.sh" build -- build 2>&1)"
guard_rc_602=$?

if [ "$guard_rc_602" -eq 0 ]; then
  pass "Case 3: the guarded build in #602 succeeds independently of #601's unguarded call"
else
  fail "Case 3: expected the guarded build in #602 to succeed, got rc=$guard_rc_602 ($guard_out_602)"
fi
if [ -f "$path_601/.lake/build-guard.marker" ]; then
  pass "Case 3: #601's unguarded build wrote its own marker into its OWN .lake/"
else
  fail "Case 3: expected a build marker in #601's own .lake/"
fi
if [ -f "$path_602/.lake/build-guard.marker" ]; then
  pass "Case 3: #602's guarded build wrote its own marker into its OWN .lake/"
else
  fail "Case 3: expected a build marker in #602's own .lake/"
fi
marker_601="$(cat "$path_601/.lake/build-guard.marker" 2>/dev/null)"
marker_602="$(cat "$path_602/.lake/build-guard.marker" 2>/dev/null)"
if [ -n "$marker_601" ] && [ "$marker_601" != "$marker_602" ]; then
  pass "Case 3 (no collision): #601's and #602's build markers are DISTINCT -- the unguarded call in #601 never touched #602's .lake/, and vice versa"
else
  fail "Case 3: expected distinct build markers proving no cross-worktree write, got 601='$marker_601' 602='$marker_602'"
fi
if [ ! -f "$repo3/.lake/build-guard.marker" ]; then
  pass "Case 3: the main tree's own .lake/ was never touched by either worktree's build"
else
  fail "Case 3: the main tree's .lake/ unexpectedly picked up a build-guard.marker"
fi

run_dw "$repo3" release 601 >/dev/null
( cd "$repo3" && git branch -D "$branch_601" >/dev/null 2>&1 || true )
run_dw "$repo3" release 602 >/dev/null
( cd "$repo3" && git branch -D "$branch_602" >/dev/null 2>&1 || true )

# =====================================================================================================
# Case 4: shared-tree counterpart -- two non-isolated tasks contending for one declared path (the
# Phase 8 manifest, hand-built here exactly as orchestrate-cycle-plan.sh's build_contended_manifest
# would); the second committer is REFUSED before any git add, with nothing staged.
# =====================================================================================================
info "Case 4: shared-tree contended-path refusal -- the second committer is refused, nothing staged"

repo4="$(build_repo shared)"
mkdir -p "$repo4/specs/901_candidate" "$repo4/specs/.contention-manifest"
echo "line1" > "$repo4/docs/shared2.md"
git -C "$repo4" add docs/shared2.md
git -C "$repo4" commit -q -m "seed shared2"
cat > "$repo4/specs/.contention-manifest/sess4.json" <<EOF
{"session_id":"sess4","cycle":1,"generated_at":"2026-01-01T00:00:00Z","contended":[{"path":"docs/shared2.md","tasks":[901,902],"granularity":"file"}]}
EOF

echo "901 edit" >> "$repo4/docs/shared2.md"
out4a="$(run_commit "$repo4" --message "candidate 901: edit shared2" --session sess4 --task 901 -- docs/shared2.md 2>&1)"
rc4a=$?
if [ "$rc4a" -eq 0 ]; then
  pass "Case 4: candidate #901 (first committer) claims and commits successfully"
else
  fail "Case 4: expected candidate #901's commit to succeed, got rc=$rc4a ($out4a)"
fi

# Simulate candidate #902 racing #901 WHILE #901's own claim is still live (git-commit-scoped.sh
# releases its own claim at the end of each invocation -- to exercise the REFUSAL branch this
# fixture manually holds a claim on #902's behalf's rival, mirroring the exact shape
# test-git-commit-scoped.sh's own V4 case already proves against the same real scripts).
run_tl "$repo4" claim-acquire "docs/shared2.md" 901 sess4_still_committing >/dev/null
echo "902 edit" >> "$repo4/docs/shared2.md"
before4_head="$(git -C "$repo4" rev-list --count HEAD)"
before4_staged="$(git -C "$repo4" diff --cached --name-only)"
out4b="$(run_commit "$repo4" --message "candidate 902: edit shared2" --session sess4 --task 902 -- docs/shared2.md 2>&1)"
rc4b=$?
after4_head="$(git -C "$repo4" rev-list --count HEAD)"
staged4="$(git -C "$repo4" diff --cached --name-only)"

if [ "$rc4b" -eq 3 ]; then
  pass "Case 4: candidate #902 is refused (exit 3) while #901's claim is live"
else
  fail "Case 4: expected candidate #902 to be refused with exit 3, got rc=$rc4b ($out4b)"
fi
if [ "$after4_head" -eq "$before4_head" ]; then
  pass "Case 4: no new commit landed for the refused candidate #902"
else
  fail "Case 4: expected HEAD unchanged after the refusal, before=$before4_head after=$after4_head"
fi
if [ "$staged4" = "$before4_staged" ]; then
  pass "Case 4 (nothing staged): git diff --cached is unchanged by the refused attempt"
else
  fail "Case 4: expected nothing staged by the refused attempt, found: $staged4"
fi
if echo "$out4b" | grep -q "task #901"; then
  pass "Case 4: the refusal names the holding candidate (#901) verbatim"
else
  fail "Case 4: expected the refusal to name candidate #901, got: $out4b"
fi
run_tl "$repo4" claim-release "docs/shared2.md" 901 >/dev/null

# =====================================================================================================
# Case 5: negative control -- the SAME two-writer, same-file edit pattern as Case 1, but on a
# SHARED (non-isolated) tree with the V5 refusal OMITTED (no --task). Demonstrates the silent
# bleed Case 1's isolation does NOT exhibit -- proving Case 1's no-bleed assertion is not vacuous
# by reproducing the actual failure the fix closes.
# =====================================================================================================
info "Case 5 (negative control): the SAME edit pattern silently bleeds without --task's V5 refusal"

repo5="$(build_repo negctrl)"
echo "line1" > "$repo5/docs/shared3.md"
git -C "$repo5" add docs/shared3.md
git -C "$repo5" commit -q -m "seed shared3"
before_count_5="$(git -C "$repo5" rev-list --count HEAD)"

# candidate #903 stages+commits its own edit -- WITHOUT --task, so no claim is taken at all.
echo "line1-903" > "$repo5/docs/shared3.md"
run_commit "$repo5" --message "candidate 903: edit shared3" --session sess5 -- docs/shared3.md >/dev/null 2>&1

# candidate #904 races in and, ALSO without --task (no V5 protection), overwrites the SAME file
# and commits over it -- exactly the observed mode-1b shape: each stages only its own path,
# narrowly and correctly, and still bleeds because nothing is claiming the shared file.
echo "line1-904" > "$repo5/docs/shared3.md"
run_commit "$repo5" --message "candidate 904: edit shared3" --session sess5 -- docs/shared3.md >/dev/null 2>&1

final_shared3="$(cat "$repo5/docs/shared3.md" 2>/dev/null)"
commit_count_5="$(git -C "$repo5" rev-list --count HEAD)"
if [ "$final_shared3" = "line1-904" ] && [ "$commit_count_5" -eq $((before_count_5 + 2)) ]; then
  pass "Case 5 (negative control, confirms the fix is not vacuous): WITHOUT --task, candidate #904 silently commits over #903's edit -- the exact incident this posture closes"
else
  fail "Case 5: expected the negative control to reproduce the silent overwrite (final='line1-904', 2 new commits), got final='$final_shared3' before=$before_count_5 after=$commit_count_5"
fi

# =====================================================================================================
# Case 6: full teardown -- no leftover worktrees, no dangling registry/claim/manifest state.
# =====================================================================================================
info "Case 6: full teardown across every repo this fixture provisioned"

# Manifests are cycle-scoped snapshots owned by orchestrate-cycle-plan.sh's own
# build_contended_manifest (not by git-commit-scoped.sh, which only READS them) -- this fixture
# never drives that producer, so it removes the manifest it hand-built for Case 4 itself here,
# the same way a later cycle's build_contended_manifest would once contention drops back to a
# single task (see that function's own "actively removed, not merely left unwritten" contract).
rm -rf "$repo4/specs/.contention-manifest" 2>/dev/null || true

for r in "$repo1" "$repo3" "$repo4" "$repo5"; do
  wt_count="$(git -C "$r" worktree list --porcelain 2>/dev/null | grep -c '^worktree ' || true)"
  # Exactly one entry remains: the main tree itself (`git worktree list` always includes it).
  if [ "${wt_count:-0}" -le 1 ]; then
    pass "Case 6: $r has no leftover linked worktrees (git worktree list clean)"
  else
    fail "Case 6: $r still has leftover worktrees: $(git -C "$r" worktree list)"
  fi

  stray_branches="$(git -C "$r" branch --list 'orchestrate/task-*' 2>/dev/null)"
  if [ -z "$stray_branches" ]; then
    pass "Case 6: $r has no leftover orchestrate/task-* branches"
  else
    fail "Case 6: $r still has stray branches: $stray_branches"
  fi

  if [ ! -d "$r/specs/.worktree-registry" ] || [ -z "$(ls -A "$r/specs/.worktree-registry" 2>/dev/null)" ]; then
    pass "Case 6: $r's worktree registry is empty"
  else
    fail "Case 6: $r's worktree registry still has entries: $(ls "$r/specs/.worktree-registry" 2>/dev/null)"
  fi

  if [ ! -d "$r/specs/.contention-claims" ] || [ -z "$(ls -A "$r/specs/.contention-claims" 2>/dev/null)" ]; then
    pass "Case 6: $r has no leftover contended-path claims"
  else
    fail "Case 6: $r still has leftover claims: $(ls "$r/specs/.contention-claims" 2>/dev/null)"
  fi

  if [ ! -d "$r/specs/.contention-manifest" ] || [ -z "$(ls -A "$r/specs/.contention-manifest" 2>/dev/null)" ]; then
    pass "Case 6: $r has no leftover contention manifest"
  else
    fail "Case 6: $r still has a leftover manifest: $(ls "$r/specs/.contention-manifest" 2>/dev/null)"
  fi
done
# task-ref-ok:end

# =====================================================================================================
echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ]
