#!/usr/bin/env bash
# test-dispatch-worktree.sh - Regression suite for dispatch-worktree.sh's provision/path/
# release/prune verbs (the worktree lifecycle's creation side; `land`, the merge-back verb, is a
# later addition to the same file and is not exercised here).
#
# Harness: each case builds an isolated scratch git repo under mktemp -d, copies
# dispatch-worktree.sh plus its two runtime dependencies (deploy-root-guard.sh, lib/common.sh)
# into <scratch>/.claude/scripts/, so PROJECT_ROOT resolves to <scratch> and
# deploy-root-guard.sh's `*/.claude` case matches -- the real script runs against a real git
# repo, not a mock. Fixtures are synthetic and built inline; this suite never touches the real
# repository tree.
#
# Follows context/standards/shell-script-testing.md: set -uo pipefail, PASSED/FAILED counters
# with pass()/fail()/info(), mktemp -d workdir with a trap EXIT cleanup, exit 0 only when FAILED
# is 0, loud-skip discipline (never a silent no-op).
#
# task-ref-ok:begin category 6-adjacent: every "<task_number>-<seq>" and
# "orchestrate/task-<task_number>-<seq>" literal below is fixture data exercising
# dispatch-worktree.sh's OWN branch/registry naming convention (see that script's header), which
# is a functional assertion on produced output -- never a citation of this repo's own ephemeral
# task tracker. The fixture task numbers (501, 601, 701-703, 801-802, 901, 1001, 1101, 1201,
# 1301, 1401, 1501...) are arbitrary and carry no relationship to any real specs/{NNN}_{SLUG}/
# task directory.
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

# --- Loud-skip discipline: verify all required scripts exist and are executable before running
# anything (a lost exec bit is reported loudly, per the plan's own acceptance note). ---
# lake-build-guard.sh is required for T15, which exercises the guard's own `result` reporting
# through a provisioned worktree's hardlink-cloned .claude/scripts/ copy.
REQUIRED_SCRIPTS=(dispatch-worktree.sh deploy-root-guard.sh lib/common.sh lake-build-guard.sh)
missing=()
for f in "${REQUIRED_SCRIPTS[@]}"; do
  [ -f "$SRC_SCRIPTS_DIR/$f" ] || missing+=("$f")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "ERROR: test-dispatch-worktree.sh cannot run -- missing required script(s) under $SRC_SCRIPTS_DIR: ${missing[*]}" >&2
  exit 1
fi
if [ ! -x "$SRC_SCRIPTS_DIR/dispatch-worktree.sh" ]; then
  fail "SKIP-GUARD: $SRC_SCRIPTS_DIR/dispatch-worktree.sh has lost its exec bit"
fi

TOP_WORKDIR="$(mktemp -d)"
# cleanup() is invoked indirectly via `trap cleanup EXIT`.
# shellcheck disable=SC2329
cleanup() {
  if [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ]; then
    # Best-effort: reap any worktrees left registered against git before rm -rf'ing the repos,
    # so a failed case never leaves `.git/worktrees/*` metadata pointing at a removed path.
    find "$TOP_WORKDIR" -maxdepth 1 -type d -name 'case-*' 2>/dev/null | while IFS= read -r r; do
      git -C "$r" worktree prune >/dev/null 2>&1 || true
    done
    rm -rf "$TOP_WORKDIR"
  fi
}
trap cleanup EXIT

# --- build_repo <name> -- builds a scratch git repo with a deployed dispatch-worktree.sh under
# .claude/scripts/, one seed commit, and echoes the repo's absolute path. ---
build_repo() {
  local name="$1" dir
  dir="$TOP_WORKDIR/case-$name"
  mkdir -p "$dir/.claude/scripts/lib"
  cp "$SRC_SCRIPTS_DIR/dispatch-worktree.sh" "$dir/.claude/scripts/dispatch-worktree.sh"
  cp "$SRC_SCRIPTS_DIR/deploy-root-guard.sh" "$dir/.claude/scripts/deploy-root-guard.sh"
  cp "$SRC_SCRIPTS_DIR/lib/common.sh" "$dir/.claude/scripts/lib/common.sh"
  # Copied unconditionally (unused by T1-T13) so T15 can exercise the guard through the SAME
  # hardlink-cloned .claude/scripts/ path a real dispatch worktree provides.
  cp "$SRC_SCRIPTS_DIR/lake-build-guard.sh" "$dir/.claude/scripts/lake-build-guard.sh"
  chmod +x "$dir/.claude/scripts/dispatch-worktree.sh" "$dir/.claude/scripts/lake-build-guard.sh"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  echo "seed" > "$dir/README.md"
  # .claude/ is deliberately left UNTRACKED here, matching the real system (see .gitignore's
  # /.claude/ rule): a fresh `git worktree add` must produce a tree with no .claude/ at all
  # (Phase 1's confirmed fact), which is exactly what a hardlink-clone step then populates.
  # Committing .claude/ here would make `git worktree add` check it out already, so the script's
  # own `cp -al` would nest a copy inside it instead of populating a clean destination.
  echo "/.claude/" > "$dir/.gitignore"
  echo "/.orchestrate-worktrees/" >> "$dir/.gitignore"
  echo "/specs/.worktree-registry/" >> "$dir/.gitignore"
  # A tracked specs/ file, so a land case can exercise the specs/** refusal against a real
  # tracked path (mirroring the real system, where specs/ is tracked -- see the script's own
  # header note).
  mkdir -p "$dir/specs"
  echo '{"seed":true}' > "$dir/specs/state.json"
  git -C "$dir" add README.md .gitignore specs/state.json
  git -C "$dir" commit -q -m "seed"
  echo "$dir"
}

# --- run_dw <repo> <args...> -- invokes the repo's own deployed dispatch-worktree.sh. ---
run_dw() {
  local repo="$1"
  shift
  (cd "$repo" && bash .claude/scripts/dispatch-worktree.sh "$@")
}

# =====================================================================
# T1: clean provision -- worktree created, branch set, .claude/ hardlink-cloned (not a symlink,
# physically present with its own scripts), .lake/ hardlink-cloned when the main tree has one.
# =====================================================================

repo_t1="$(build_repo t1)"
mkdir -p "$repo_t1/.lake/pkg"
echo "built" > "$repo_t1/.lake/pkg/out.olean"

out_t1="$(run_dw "$repo_t1" provision 501 --session sess_t1 --seq 1)"
rc_t1=$?
status_t1="$(echo "$out_t1" | jq -r '.status' 2>/dev/null)"
path_t1="$(echo "$out_t1" | jq -r '.path' 2>/dev/null)"

if [ "$rc_t1" -eq 0 ] && [ "$status_t1" = "provisioned" ] && [ -n "$path_t1" ] && [ -d "$path_t1" ]; then
  pass "T1: provision succeeds and reports status=provisioned with an existing path"
else
  fail "T1: expected rc=0 status=provisioned existing dir; got rc=$rc_t1 out=$out_t1"
fi

if git -C "$repo_t1" worktree list --porcelain | grep -qxF "worktree $path_t1"; then
  pass "T1: git recognizes the new worktree"
else
  fail "T1: git worktree list does not show $path_t1"
fi

if [ -d "$path_t1/.claude/scripts" ] && [ ! -L "$path_t1/.claude" ]; then
  pass "T1: .claude/ is physically present inside the worktree, not a symlink"
else
  fail "T1: .claude/ missing or is a symlink at $path_t1/.claude"
fi

if [ -f "$path_t1/.lake/pkg/out.olean" ]; then
  pass "T1: .lake/ was hardlink-cloned into the worktree"
else
  fail "T1: .lake/pkg/out.olean missing at $path_t1/.lake/pkg/out.olean"
fi

if git -C "$repo_t1" branch --list "orchestrate/task-501-1" | grep -q "orchestrate/task-501-1"; then
  pass "T1: branch orchestrate/task-501-1 exists"
else
  fail "T1: branch orchestrate/task-501-1 was not created"
fi

# =====================================================================
# T2: PROJECT_ROOT resolution -- a script sourcing lib/common.sh from the worktree's own
# .claude/scripts/ resolves common_repo_root to the WORKTREE root, not the main tree.
# =====================================================================

resolved_t2="$(cd "$path_t1/.claude/scripts" && bash -c 'source lib/common.sh; common_repo_root "$PWD" 2')"
canon_t2="$(cd "$path_t1" && pwd)"

if [ "$resolved_t2" = "$canon_t2" ]; then
  pass "T2: PROJECT_ROOT resolves inside the worktree ($canon_t2)"
else
  fail "T2: PROJECT_ROOT resolved to '$resolved_t2', expected worktree root '$canon_t2'"
fi

# =====================================================================
# T3: idempotent re-provision -- provisioning the same task/seq/session again reuses the
# existing worktree rather than erroring or double-creating.
# =====================================================================

out_t3="$(run_dw "$repo_t1" provision 501 --session sess_t1 --seq 1)"
rc_t3=$?
status_t3="$(echo "$out_t3" | jq -r '.status' 2>/dev/null)"
path_t3="$(echo "$out_t3" | jq -r '.path' 2>/dev/null)"
count_t3="$(git -C "$repo_t1" worktree list --porcelain | grep -cxF "worktree $path_t1")"

if [ "$rc_t3" -eq 0 ] && [ "$status_t3" = "reused" ] && [ "$path_t3" = "$path_t1" ] && [ "$count_t3" -eq 1 ]; then
  pass "T3: re-provisioning the same task-501-1 reuses the existing worktree (status=reused, one git entry)"
else
  fail "T3: expected rc=0 status=reused path=$path_t1 count=1; got rc=$rc_t3 status=$status_t3 path=$path_t3 count=$count_t3"
fi

# =====================================================================
# T4: path hit and miss.
# =====================================================================

out_t4_hit="$(run_dw "$repo_t1" path 501)"
rc_t4_hit=$?

if [ "$rc_t4_hit" -eq 0 ] && [ "$out_t4_hit" = "$path_t1" ]; then
  pass "T4: path 501 prints the provisioned worktree path"
else
  fail "T4: expected rc=0 path=$path_t1; got rc=$rc_t4_hit out=$out_t4_hit"
fi

out_t4_miss="$(run_dw "$repo_t1" path 999999)"
rc_t4_miss=$?

if [ "$rc_t4_miss" -eq 3 ] && [ -z "$out_t4_miss" ]; then
  pass "T4: path on an unprovisioned task exits 3 with empty stdout"
else
  fail "T4: expected rc=3 empty stdout; got rc=$rc_t4_miss out='$out_t4_miss'"
fi

# =====================================================================
# T5: release leaves no worktree and no registry record, but keeps the branch.
# =====================================================================

out_t5="$(run_dw "$repo_t1" release 501)"
rc_t5=$?
record_t5="$repo_t1/specs/.worktree-registry/501-1.json"

if [ "$rc_t5" -eq 0 ] && [ ! -d "$path_t1" ] && [ ! -f "$record_t5" ]; then
  pass "T5: release removes the worktree directory and its registry record"
else
  fail "T5: expected worktree and record gone; got rc=$rc_t5 out=$out_t5 dir_exists=$([ -d "$path_t1" ] && echo yes || echo no) record_exists=$([ -f "$record_t5" ] && echo yes || echo no)"
fi

if ! git -C "$repo_t1" worktree list --porcelain | grep -qxF "worktree $path_t1"; then
  pass "T5: git worktree list no longer shows the released path"
else
  fail "T5: git worktree list still shows $path_t1 after release"
fi

if git -C "$repo_t1" branch --list "orchestrate/task-501-1" | grep -q "orchestrate/task-501-1"; then
  pass "T5: release preserves the branch for later inspection"
else
  fail "T5: release deleted the branch orchestrate/task-501-1, which it must never do"
fi

# =====================================================================
# T6: free-space refusal -- DISPATCH_WORKTREE_FREE_BYTES_OVERRIDE forces the preflight below the
# floor; nothing is created.
# =====================================================================

repo_t6="$(build_repo t6)"
err_t6_file="$TOP_WORKDIR/t6.err"
out_t6="$(DISPATCH_WORKTREE_FREE_BYTES_OVERRIDE=1 bash -c "cd '$repo_t6' && bash .claude/scripts/dispatch-worktree.sh provision 601 --session sess_t6 --seq 1" 2>"$err_t6_file")"
rc_t6=$?

if [ "$rc_t6" -eq 80 ] && [ -z "$out_t6" ] && [ ! -d "$repo_t6/.orchestrate-worktrees/601-1" ] && [ ! -f "$repo_t6/specs/.worktree-registry/601-1.json" ]; then
  pass "T6: free-space refusal exits 80, emits no stdout JSON, and creates nothing"
else
  fail "T6: expected rc=80 empty stdout nothing created; got rc=$rc_t6 out='$out_t6' stderr='$(cat "$err_t6_file")'"
fi

if ! git -C "$repo_t6" worktree list --porcelain | grep -q "601-1"; then
  pass "T6: no worktree/branch registered for the refused provision"
else
  fail "T6: a worktree was registered despite the free-space refusal"
fi

# =====================================================================
# T7: prune reaps a stale foreign-session record and spares both a live-session record and a
# fresh foreign-session record.
# =====================================================================

repo_t7="$(build_repo t7)"
out_t7_a="$(run_dw "$repo_t7" provision 701 --session sess_old --seq 1)"
out_t7_b="$(run_dw "$repo_t7" provision 702 --session sess_current --seq 1)"
out_t7_c="$(run_dw "$repo_t7" provision 703 --session sess_other_fresh --seq 1)"

path_t7_a="$(echo "$out_t7_a" | jq -r '.path')"
path_t7_b="$(echo "$out_t7_b" | jq -r '.path')"
path_t7_c="$(echo "$out_t7_c" | jq -r '.path')"

rec_t7_a="$repo_t7/specs/.worktree-registry/701-1.json"
rec_t7_b="$repo_t7/specs/.worktree-registry/702-1.json"
rec_t7_c="$repo_t7/specs/.worktree-registry/703-1.json"

# Backdate the foreign-session record (701) far past any plausible stale threshold; leave the
# live-session (702) and fresh-foreign (703) records at their real just-provisioned timestamp.
old_ts="$(date -u -d "@$(($(date -u +%s) - 100000))" +%Y-%m-%dT%H:%M:%SZ)"
tmp_t7="$TOP_WORKDIR/t7-rec.json"
jq --arg ts "$old_ts" '.created_at = $ts' "$rec_t7_a" > "$tmp_t7" && mv "$tmp_t7" "$rec_t7_a"

out_t7_prune="$(DISPATCH_WORKTREE_STALE_SEC=10 bash -c "cd '$repo_t7' && bash .claude/scripts/dispatch-worktree.sh prune --session sess_current")"
rc_t7_prune=$?

if [ "$rc_t7_prune" -eq 0 ] && [ ! -d "$path_t7_a" ] && [ ! -f "$rec_t7_a" ]; then
  pass "T7: prune reaps the stale foreign-session record (701) and its worktree"
else
  fail "T7: expected 701 reaped; got rc=$rc_t7_prune dir_exists=$([ -d "$path_t7_a" ] && echo yes || echo no) rec_exists=$([ -f "$rec_t7_a" ] && echo yes || echo no)"
fi

if [ -d "$path_t7_b" ] && [ -f "$rec_t7_b" ]; then
  pass "T7: prune spares the live-session record (702) unconditionally"
else
  fail "T7: expected 702 spared (it names the calling session); dir_exists=$([ -d "$path_t7_b" ] && echo yes || echo no) rec_exists=$([ -f "$rec_t7_b" ] && echo yes || echo no)"
fi

if [ -d "$path_t7_c" ] && [ -f "$rec_t7_c" ]; then
  pass "T7: prune spares a fresh foreign-session record (703, age below the stale threshold)"
else
  fail "T7: expected 703 spared (not yet stale); dir_exists=$([ -d "$path_t7_c" ] && echo yes || echo no) rec_exists=$([ -f "$rec_t7_c" ] && echo yes || echo no)"
fi

pruned_list_t7="$(echo "$out_t7_prune" | jq -r '.pruned[]' 2>/dev/null)"
if echo "$pruned_list_t7" | grep -qxF "$path_t7_a"; then
  pass "T7: prune's JSON summary names the reaped path"
else
  fail "T7: prune's JSON summary did not name $path_t7_a; got $out_t7_prune"
fi

# Clean up the two deliberately-spared worktrees so this repo reaches a clean end state for the
# generic teardown sanity check below (their sparing was already asserted above).
run_dw "$repo_t7" release 702 >/dev/null 2>&1 || true
run_dw "$repo_t7" release 703 >/dev/null 2>&1 || true

# =====================================================================
# T8: worktree cap refusal (bonus coverage beyond the plan's minimum case list) -- a second
# provision beyond DISPATCH_WORKTREE_MAX_CONCURRENT is refused before touching git or disk.
# =====================================================================

repo_t8="$(build_repo t8)"
DISPATCH_WORKTREE_MAX_CONCURRENT=1 bash -c "cd '$repo_t8' && bash .claude/scripts/dispatch-worktree.sh provision 801 --session sess_t8a --seq 1" >/dev/null
err_t8_file="$TOP_WORKDIR/t8.err"
out_t8="$(DISPATCH_WORKTREE_MAX_CONCURRENT=1 bash -c "cd '$repo_t8' && bash .claude/scripts/dispatch-worktree.sh provision 802 --session sess_t8b --seq 1" 2>"$err_t8_file")"
rc_t8=$?

if [ "$rc_t8" -eq 81 ] && [ -z "$out_t8" ] && [ ! -d "$repo_t8/.orchestrate-worktrees/802-1" ]; then
  pass "T8: worktree-cap refusal exits 81 and creates nothing for the over-cap request"
  run_dw "$repo_t8" release 801 >/dev/null 2>&1 || true
else
  fail "T8: expected rc=81 empty stdout nothing created; got rc=$rc_t8 out='$out_t8' stderr='$(cat "$err_t8_file")'"
fi

# =====================================================================
# T9: land -- clean case. A branch-only commit merges cleanly into the main tree via
# `git merge --no-ff`; the worktree is left in place (release is a separate, later step).
# =====================================================================

repo_t9="$(build_repo t9)"
out_t9_prov="$(run_dw "$repo_t9" provision 901 --session sess_t9 --seq 1)"
wt_t9="$(echo "$out_t9_prov" | jq -r '.path')"

echo "new content" > "$wt_t9/feature.txt"
git -C "$wt_t9" add feature.txt
git -C "$wt_t9" commit -q -m "add feature.txt"

out_t9_land="$(run_dw "$repo_t9" land 901 --session sess_t9)"
rc_t9_land=$?
verdict_t9="$(echo "$out_t9_land" | jq -r '.verdict' 2>/dev/null)"

if [ "$rc_t9_land" -eq 0 ] && [ "$verdict_t9" = "landed" ] && [ -f "$repo_t9/feature.txt" ] && [ "$(cat "$repo_t9/feature.txt")" = "new content" ]; then
  pass "T9: land merges a clean branch commit into the main tree (verdict=landed, file present)"
else
  fail "T9: expected rc=0 verdict=landed feature.txt present; got rc=$rc_t9_land out=$out_t9_land"
fi

run_dw "$repo_t9" release 901 >/dev/null 2>&1 || true

# =====================================================================
# T10: land -- specs/** refusal. A branch commit touching a tracked specs/ path is refused
# before any merge is attempted; the main tree's specs/state.json is untouched.
# =====================================================================

repo_t10="$(build_repo t10)"
out_t10_prov="$(run_dw "$repo_t10" provision 1001 --session sess_t10 --seq 1)"
wt_t10="$(echo "$out_t10_prov" | jq -r '.path')"

echo '{"touched":true}' > "$wt_t10/specs/state.json"
git -C "$wt_t10" add specs/state.json
git -C "$wt_t10" commit -q -m "touch specs/state.json"

before_state_t10="$(cat "$repo_t10/specs/state.json")"
err_t10_file="$TOP_WORKDIR/t10.err"
out_t10_land="$(run_dw "$repo_t10" land 1001 --session sess_t10 2>"$err_t10_file")"
rc_t10_land=$?
verdict_t10="$(echo "$out_t10_land" | jq -r '.verdict' 2>/dev/null)"
after_state_t10="$(cat "$repo_t10/specs/state.json")"

if [ "$rc_t10_land" -eq 90 ] && [ "$verdict_t10" = "refused_specs_paths" ] && [ "$before_state_t10" = "$after_state_t10" ]; then
  pass "T10: land refuses a specs/** touch before merging; specs/state.json byte-identical"
else
  fail "T10: expected rc=90 verdict=refused_specs_paths unchanged state.json; got rc=$rc_t10_land out=$out_t10_land stderr='$(cat "$err_t10_file")'"
fi

if echo "$out_t10_land" | jq -r '.paths[]' 2>/dev/null | grep -qxF "specs/state.json"; then
  pass "T10: refusal verdict names the offending specs/ path"
else
  fail "T10: refusal verdict did not name specs/state.json; got $out_t10_land"
fi

run_dw "$repo_t10" release 1001 --force >/dev/null 2>&1 || true

# =====================================================================
# T11: land -- genuine conflict (add/add on the same new path from both sides). The merge is
# aborted, nothing is left in-progress, and both the branch and worktree survive intact.
# =====================================================================

repo_t11="$(build_repo t11)"
out_t11_prov="$(run_dw "$repo_t11" provision 1101 --session sess_t11 --seq 1)"
wt_t11="$(echo "$out_t11_prov" | jq -r '.path')"

echo "branch version" > "$wt_t11/conflict.txt"
git -C "$wt_t11" add conflict.txt
git -C "$wt_t11" commit -q -m "branch adds conflict.txt"

# Main tree diverges independently, adding the SAME new path with different content.
echo "main version" > "$repo_t11/conflict.txt"
git -C "$repo_t11" add conflict.txt
git -C "$repo_t11" commit -q -m "main adds conflict.txt"

err_t11_file="$TOP_WORKDIR/t11.err"
out_t11_land="$(run_dw "$repo_t11" land 1101 --session sess_t11 2>"$err_t11_file")"
rc_t11_land=$?
verdict_t11="$(echo "$out_t11_land" | jq -r '.verdict' 2>/dev/null)"
merge_head_present_t11="no"
[ -f "$repo_t11/.git/MERGE_HEAD" ] && merge_head_present_t11="yes"

if [ "$rc_t11_land" -eq 92 ] && [ "$verdict_t11" = "conflict" ] && [ "$merge_head_present_t11" = "no" ]; then
  pass "T11: land aborts a genuine conflict (verdict=conflict, no in-progress merge left behind)"
else
  fail "T11: expected rc=92 verdict=conflict no MERGE_HEAD; got rc=$rc_t11_land out=$out_t11_land merge_head=$merge_head_present_t11 stderr='$(cat "$err_t11_file")'"
fi

if git -C "$repo_t11" branch --list "orchestrate/task-1101-1" | grep -q "orchestrate/task-1101-1" && [ -d "$wt_t11" ]; then
  pass "T11: conflict leaves the branch and worktree intact for resolution"
else
  fail "T11: expected branch and worktree preserved after a conflict"
fi

if [ "$(cat "$repo_t11/conflict.txt")" = "main version" ]; then
  pass "T11: main tree's own conflicting file is untouched after the aborted merge"
else
  fail "T11: main tree's conflict.txt was altered by the aborted merge attempt"
fi

run_dw "$repo_t11" release 1101 --force >/dev/null 2>&1 || true

# =====================================================================
# T12: land -- dirty-overlap refusal. The main tree has an UNCOMMITTED edit to a path the branch
# also touches; land refuses before merging, and the uncommitted edit survives untouched.
# =====================================================================

repo_t12="$(build_repo t12)"
echo "seed" > "$repo_t12/shared.txt"
git -C "$repo_t12" add shared.txt
git -C "$repo_t12" commit -q -m "add shared.txt"

out_t12_prov="$(run_dw "$repo_t12" provision 1201 --session sess_t12 --seq 1)"
wt_t12="$(echo "$out_t12_prov" | jq -r '.path')"

echo "branch edit" >> "$wt_t12/shared.txt"
git -C "$wt_t12" add shared.txt
git -C "$wt_t12" commit -q -m "branch edits shared.txt"

echo "uncommitted local edit" >> "$repo_t12/shared.txt"
before_shared_t12="$(cat "$repo_t12/shared.txt")"

err_t12_file="$TOP_WORKDIR/t12.err"
out_t12_land="$(run_dw "$repo_t12" land 1201 --session sess_t12 2>"$err_t12_file")"
rc_t12_land=$?
verdict_t12="$(echo "$out_t12_land" | jq -r '.verdict' 2>/dev/null)"
after_shared_t12="$(cat "$repo_t12/shared.txt")"

if [ "$rc_t12_land" -eq 91 ] && [ "$verdict_t12" = "refused_dirty_overlap" ] && [ "$before_shared_t12" = "$after_shared_t12" ]; then
  pass "T12: land refuses on a main-tree dirty overlap; the uncommitted edit survives untouched"
else
  fail "T12: expected rc=91 verdict=refused_dirty_overlap unchanged shared.txt; got rc=$rc_t12_land out=$out_t12_land stderr='$(cat "$err_t12_file")'"
fi

git -C "$repo_t12" checkout -- shared.txt 2>/dev/null || true
run_dw "$repo_t12" release 1201 --force >/dev/null 2>&1 || true

# =====================================================================
# T13: land -- nothing-to-land no-op (no commits made on the branch beyond its fork point), and
# reuse of the same still-live worktree for the "invoked from inside a worktree" refusal.
# =====================================================================

repo_t13="$(build_repo t13)"
out_t13_prov="$(run_dw "$repo_t13" provision 1301 --session sess_t13 --seq 1)"
wt_t13="$(echo "$out_t13_prov" | jq -r '.path')"

out_t13_land="$(run_dw "$repo_t13" land 1301 --session sess_t13)"
rc_t13_land=$?
verdict_t13="$(echo "$out_t13_land" | jq -r '.verdict' 2>/dev/null)"

if [ "$rc_t13_land" -eq 0 ] && [ "$verdict_t13" = "nothing_to_land" ]; then
  pass "T13: land on a branch with no new commits reports verdict=nothing_to_land, exit 0"
else
  fail "T13: expected rc=0 verdict=nothing_to_land; got rc=$rc_t13_land out=$out_t13_land"
fi

err_t13b_file="$TOP_WORKDIR/t13-unavailable.err"
out_t13b="$(cd "$repo_t13" && bash .claude/scripts/dispatch-worktree.sh land 999999 --session sess_t13 2>"$err_t13b_file")"
rc_t13b=$?
verdict_t13b="$(echo "$out_t13b" | jq -r '.verdict' 2>/dev/null)"

if [ "$rc_t13b" -eq 93 ] && [ "$verdict_t13b" = "unavailable" ]; then
  pass "T13: land on an unprovisioned task reports verdict=unavailable, exit 93"
else
  fail "T13: expected rc=93 verdict=unavailable; got rc=$rc_t13b out=$out_t13b stderr='$(cat "$err_t13b_file")'"
fi

err_t13c_file="$TOP_WORKDIR/t13-fromworktree.err"
out_t13c="$(cd "$wt_t13" && bash .claude/scripts/dispatch-worktree.sh land 1301 --session sess_t13 2>"$err_t13c_file")"
rc_t13c=$?
verdict_t13c="$(echo "$out_t13c" | jq -r '.verdict' 2>/dev/null)"

if [ "$rc_t13c" -eq 93 ] && [ "$verdict_t13c" = "unavailable" ]; then
  pass "T13: land invoked from inside a worktree's own .claude/scripts/ refuses (verdict=unavailable)"
else
  fail "T13: expected rc=93 verdict=unavailable when invoked from inside a worktree; got rc=$rc_t13c out=$out_t13c stderr='$(cat "$err_t13c_file")'"
fi

run_dw "$repo_t13" release 1301 --force >/dev/null 2>&1 || true

# =====================================================================
# T14: root cause, inode distinctness -- after the .lake/ hardlink clone, every `build-guard.*`
# state file must be an INDEPENDENT inode in the worktree, never the same inode as the main
# tree's copy (each is ephemeral per-tree runtime bookkeeping, not build output), while ordinary
# .lake/ build output (e.g. an .olean) remains hardlink-shared -- the actual reason .lake/ is
# cloned at all. Confirmed root cause: `cp -al` makes every pre-existing file in the source
# directory a shared inode, and lake-build-guard.sh's own `finalize_record()` truncates its
# state files in place, so a shared inode is silently overwritten across trees.
# =====================================================================

repo_t14="$(build_repo t14)"
mkdir -p "$repo_t14/.lake/pkg"
echo "built" > "$repo_t14/.lake/pkg/out.olean"
echo "lock" > "$repo_t14/.lake/build-guard.lock"
echo "state=complete" > "$repo_t14/.lake/build-guard.result"
echo "log" > "$repo_t14/.lake/build-guard.log"
echo "stdout" > "$repo_t14/.lake/build-guard.stdout"
echo "stderr" > "$repo_t14/.lake/build-guard.stderr"

out_t14="$(run_dw "$repo_t14" provision 1401 --session sess_t14 --seq 1)"
path_t14="$(echo "$out_t14" | jq -r '.path' 2>/dev/null)"

# Two implementations both satisfy the goal (never hardlink these five in the first place, OR
# delete them immediately and unconditionally post-clone -- see the plan's Phase 2 task list,
# "T14 asserts the end state either way"): the worktree's copy may be ABSENT entirely, or
# PRESENT with an inode distinct from the main tree's. Either is a pass; only "present with the
# SAME inode as the main tree's" (the pre-fix hardlink-sharing defect) is a fail.
GUARD_STATE_FILES_T14=(build-guard.lock build-guard.result build-guard.log build-guard.stdout build-guard.stderr)
for f in "${GUARD_STATE_FILES_T14[@]}"; do
  main_inode_t14="$(stat -c '%i' "$repo_t14/.lake/$f" 2>/dev/null)"
  if [ ! -f "$path_t14/.lake/$f" ]; then
    pass "T14: .lake/$f is absent from the worktree (never hardlinked in, not shared with the main tree)"
    continue
  fi
  wt_inode_t14="$(stat -c '%i' "$path_t14/.lake/$f" 2>/dev/null)"
  if [ -n "$main_inode_t14" ] && [ -n "$wt_inode_t14" ] && [ "$main_inode_t14" != "$wt_inode_t14" ]; then
    pass "T14: .lake/$f is an independent inode in the worktree (not hardlinked to the main tree)"
  else
    fail "T14: .lake/$f expected absent or a distinct worktree inode; main_inode=$main_inode_t14 wt_inode=$wt_inode_t14"
  fi
done

main_olean_inode_t14="$(stat -c '%i' "$repo_t14/.lake/pkg/out.olean" 2>/dev/null)"
wt_olean_inode_t14="$(stat -c '%i' "$path_t14/.lake/pkg/out.olean" 2>/dev/null)"
if [ -f "$path_t14/.lake/pkg/out.olean" ] && [ -n "$main_olean_inode_t14" ] && [ "$main_olean_inode_t14" = "$wt_olean_inode_t14" ]; then
  pass "T14: .lake/pkg/out.olean remains hardlink-shared (same inode) -- the sharing benefit survives the guard-state exclusion"
else
  fail "T14: .lake/pkg/out.olean expected to remain hardlink-shared; main_inode=$main_olean_inode_t14 wt_inode=$wt_olean_inode_t14"
fi

run_dw "$repo_t14" release 1401 --force >/dev/null 2>&1 || true

# =====================================================================
# T15: behavioural, cross-tree `result` clobbering -- `result --dir <main>` (no --expect-pid)
# must keep reporting the MAIN tree's own build after an unrelated build at a DIFFERENT scope
# completes inside a provisioned worktree. Pre-fix, the shared inode lets the worktree build's
# finalize_record() truncate-in-place overwrite the main tree's own record and log, so `result`
# reports the worktree's verdict as the main tree's own -- the reported false green.
# =====================================================================

repo_t15="$(build_repo t15)"
mkdir -p "$repo_t15/bin" "$repo_t15/src"
cat > "$repo_t15/lakefile.toml" <<'EOF'
name = "fixture"
EOF
echo "leanprover/lean4:stable" > "$repo_t15/lean-toolchain"
echo "def foo := 1" > "$repo_t15/src/Foo.lean"
cat > "$repo_t15/bin/lake" <<'FAKE_LAKE_EOF'
#!/usr/bin/env bash
echo "${FAKE_LAKE_OUT:-STDOUT_MARKER}"
echo "${FAKE_LAKE_ERR:-STDERR_MARKER}" >&2
exit "${FAKE_LAKE_EXIT:-0}"
FAKE_LAKE_EOF
chmod +x "$repo_t15/bin/lake"
git -C "$repo_t15" add lakefile.toml lean-toolchain src/Foo.lean bin/lake
git -C "$repo_t15" commit -q -m "add lean fixture and fake lake"

GUARD_T15="$repo_t15/.claude/scripts/lake-build-guard.sh"

# Main-tree build: scope "build", marker MAIN_MARKER.
main_rc_t15=0
FAKE_LAKE_OUT="MAIN_MARKER" PATH="$repo_t15/bin:$PATH" bash "$GUARD_T15" build --dir "$repo_t15" -- build >/dev/null 2>&1 || main_rc_t15=$?

main_result_t15="$(PATH="$repo_t15/bin:$PATH" bash "$GUARD_T15" result --dir "$repo_t15" 2>/dev/null)"
main_holder_pid_t15="$(echo "$main_result_t15" | grep '^holder_pid=' | cut -d= -f2-)"

if [ "$main_rc_t15" -eq 0 ] && [ -n "$main_holder_pid_t15" ] && grep -q "MAIN_MARKER" "$repo_t15/.lake/build-guard.log" 2>/dev/null; then
  pass "T15: main-tree build completes and records MAIN_MARKER in its own log"
else
  fail "T15: main-tree build setup failed; rc=$main_rc_t15 holder_pid=$main_holder_pid_t15"
fi

out_t15_prov="$(run_dw "$repo_t15" provision 1501 --session sess_t15 --seq 1)"
path_t15="$(echo "$out_t15_prov" | jq -r '.path' 2>/dev/null)"

# Worktree build: a DIFFERENT scope ("build Bar" vs main's "build"), marker WT_MARKER.
FAKE_LAKE_OUT="WT_MARKER" PATH="$path_t15/bin:$PATH" bash "$path_t15/.claude/scripts/lake-build-guard.sh" build --dir "$path_t15" -- build Bar >/dev/null 2>&1 || true

# Re-check the MAIN tree's own result, with NO --expect-pid -- the unguarded read this case
# targets as the false-green path.
after_result_t15="$(PATH="$repo_t15/bin:$PATH" bash "$GUARD_T15" result --dir "$repo_t15" 2>/dev/null)"
after_holder_pid_t15="$(echo "$after_result_t15" | grep '^holder_pid=' | cut -d= -f2-)"

if [ "$after_holder_pid_t15" = "$main_holder_pid_t15" ]; then
  pass "T15: result --dir <main> (no --expect-pid) still reports the main tree's own holder_pid after an unrelated worktree build"
else
  fail "T15: result --dir <main> reported holder_pid=$after_holder_pid_t15, expected the main tree's own $main_holder_pid_t15 (cross-tree record clobbering)"
fi

if grep -q "MAIN_MARKER" "$repo_t15/.lake/build-guard.log" 2>/dev/null && ! grep -q "WT_MARKER" "$repo_t15/.lake/build-guard.log" 2>/dev/null; then
  pass "T15: main tree's build-guard.log still contains MAIN_MARKER and not WT_MARKER after the worktree build"
else
  fail "T15: main tree's build-guard.log was clobbered by the worktree build: $(cat "$repo_t15/.lake/build-guard.log" 2>/dev/null)"
fi

run_dw "$repo_t15" release 1501 --force >/dev/null 2>&1 || true

# =====================================================================
# Teardown sanity: no leftover worktrees or stray branches from THIS suite's own fixtures.
# =====================================================================

for r in "$repo_t1" "$repo_t6" "$repo_t7" "$repo_t8" "$repo_t9" "$repo_t10" "$repo_t11" "$repo_t12" "$repo_t13" "$repo_t14" "$repo_t15"; do
  leftover="$(git -C "$r" worktree list --porcelain 2>/dev/null | grep -c '^worktree ' || true)"
  # Exactly one entry (the repo's own main worktree) is expected once every case-owned worktree
  # has been released/pruned/refused-before-creation.
  if [ "$leftover" -le 1 ]; then
    pass "teardown: $r has no leftover case worktrees ($leftover total)"
  else
    fail "teardown: $r still has $leftover worktree entries (expected 1, main only)"
  fi
done
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
