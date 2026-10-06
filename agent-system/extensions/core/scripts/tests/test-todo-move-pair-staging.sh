#!/usr/bin/env bash
# test-todo-move-pair-staging.sh - Regression suite for the /todo move-vacated-source-never-
# staged defect: both of /todo's recipe copies (commands/todo.md and skill-todo/SKILL.md) used
# to accumulate ONLY a directory move's destination into the commit pathspec, leaving the
# vacated source's removal unstaged -- the copy landed as a fresh `create mode` with no
# matching `delete mode`, the old tree stayed in the index pointing at files that no longer
# exist, and the commit still exited 0 reporting success. See
# context/standards/git-staging-scope.md's "Rename and Directory-Move Staging" section for the
# rule this suite pins.
#
# WHAT THIS SUITE CAN AND CANNOT COVER (stated plainly, not hidden): both recipes are
# agent-executed markdown, not scripts, so neither can be invoked directly by this suite. The
# BEHAVIORAL half below reproduces the staging *pattern* each recipe now uses (pair both
# endpoints vs. stage the destination only) inside a throwaway git fixture repo, proving the
# pattern itself behaves as expected in both directions. The STATIC half separately asserts
# that both recipes' actual text, and the standard's own text, use that pattern. Neither half
# alone is the regression net -- the behavioral half cannot see whether the recipes USE the
# pattern, and the static half cannot see whether the pattern itself WORKS. Together they pin
# the defect.
#
# Cases:
#   Behavioral, one pair (positive + negative control) per affected site shape:
#     - Step 5D shape: archive a completed/abandoned/expanded task (padded destination)
#     - Step 5E.1 shape: move an approved orphan out of specs/
#     - Step 5F shape: move a misplaced directory
#     - Stage 15 shape: skill-todo/SKILL.md's enumerated moved_paths[] list rather than an
#       inline accumulator -- mechanically identical git behavior, pinned separately because
#       it is a distinct site in a distinct file with its own historical regression risk
#   Each site shape's PAIRED case asserts: no unstaged ` D` entry under specs/, matching
#   `delete mode`/`create mode` counts in the commit, and phantom_paths == 0.
#   Each site shape's DEST-ONLY case is the negative control -- it asserts the OPPOSITE of all
#   three (an unstaged ` D` entry exists, create mode with zero delete mode, phantom_paths > 0).
#   A negative control that passes as positive (i.e. does not detect the broken shape) is
#   itself a suite failure: it would mean this suite could not have caught the live defect.
#
#   Static, over the real recipe text (not fixtures):
#     - commands/todo.md: every `mv "..." "..."` line is followed, within a generous lookahead
#       window, by a `stage_paths+=` call naming two tokens.
#     - skill-todo/SKILL.md: every bash-level `mv "..." "..."` line is followed by a
#       `moved_paths+=` call naming two tokens; each prose-level move step (Stage 10 steps 4, 5,
#       7) instructs appending to `moved_paths[]` in its own text; the single `git add` line
#       stages `"${moved_paths[@]}"` and contains neither `specs/archive/` nor a bare `specs/`
#       token.
#     - git-staging-scope.md: the named `## Rename and Directory-Move Staging` section exists.
#
# Structural model: scripts/tests/test-assess-repo-health.sh (pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, deploy-tree-first/source-store-fallback resolution, the
# git-fixture-with-unstaged-mv pattern for exercising phantom_paths via assess-repo-health.sh's
# `git ls-files` enumeration path).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required file or tool was not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

resolve_candidate() {
  local label="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  echo "ERROR: $label not found at any of:" >&2
  for candidate in "$@"; do
    echo "  $candidate" >&2
  done
  return 1
}

# Source-store copy preferred over the deployed copy: this suite's static half exists to
# verify the task's own source-store edits, which lag the deployed `.claude/` tree until the
# next redeploy. Once redeployed the two copies are byte-identical, so this order is harmless
# post-deploy and necessary pre-deploy.
TODO_MD="$(resolve_candidate "commands/todo.md" \
  "$SCRIPT_DIR/../../commands/todo.md" \
  "$REPO_ROOT/.claude/commands/todo.md")" || exit 2
SKILL_MD="$(resolve_candidate "skill-todo/SKILL.md" \
  "$SCRIPT_DIR/../../skills/skill-todo/SKILL.md" \
  "$REPO_ROOT/.claude/skills/skill-todo/SKILL.md")" || exit 2
STAGING_STD="$(resolve_candidate "git-staging-scope.md" \
  "$SCRIPT_DIR/../../context/standards/git-staging-scope.md" \
  "$REPO_ROOT/.claude/context/standards/git-staging-scope.md")" || exit 2
ASSESS_TOOL="$(resolve_candidate "assess-repo-health.sh" \
  "$REPO_ROOT/.claude/scripts/assess-repo-health.sh" \
  "$SCRIPT_DIR/../assess-repo-health.sh")" || exit 2

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not available; this suite's behavioral half requires it" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not available; cannot parse assess-repo-health.sh output" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# =====================================================================
# Behavioral half
# =====================================================================

git_init_fixture() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" -c user.email="test@example.com" -c user.name="Test" commit -q --allow-empty -m "init"
}

git_commit_all() {
  local dir="$1" msg="$2"
  git -C "$dir" -c user.email="test@example.com" -c user.name="Test" commit -q -m "$msg"
}

# run_move_pair_case <site-shape-label> <src-rel-dir> <dst-rel-dir> <mode: paired|dest-only>
#
# Builds a throwaway git fixture repo, commits a small tracked directory at <src-rel-dir>,
# `mv`s it to <dst-rel-dir>, stages either both endpoints (paired) or the destination only
# (dest-only), commits, and asserts the three measured consequences from the live defect.
run_move_pair_case() {
  local label="$1" src_rel="$2" dst_rel="$3" mode="$4"
  local tag
  tag="$(printf '%s_%s' "$label" "$mode" | tr ' /' '__')"
  local fdir="$WORKDIR/$tag"

  # Fixture files are *.sh (not arbitrary text) so assess-repo-health.sh's phantom-path
  # detection -- scoped to its *.sh/*.json structural candidates -- actually sees them; an
  # arbitrary-extension fixture file silently reports phantom_paths == 0 regardless of staging,
  # which would make assertion (c) below vacuous.
  mkdir -p "$fdir/$src_rel"
  git_init_fixture "$fdir"
  printf '#!/usr/bin/env bash\necho alpha\n' > "$fdir/$src_rel/alpha.sh"
  printf '#!/usr/bin/env bash\necho beta\n' > "$fdir/$src_rel/beta.sh"
  git -C "$fdir" add -- "$src_rel"
  git_commit_all "$fdir" "add $src_rel"

  mkdir -p "$(dirname "$fdir/$dst_rel")"
  mv "$fdir/$src_rel" "$fdir/$dst_rel"

  if [ "$mode" = "paired" ]; then
    git -C "$fdir" add -- "$src_rel" "$dst_rel"
  else
    git -C "$fdir" add -- "$dst_rel"
  fi
  git_commit_all "$fdir" "move $src_rel to $dst_rel"

  local porcelain unstaged_deletions create_count delete_count
  porcelain="$(git -C "$fdir" status --porcelain)"
  unstaged_deletions="$(printf '%s\n' "$porcelain" | grep -c "^ D ${src_rel}" || true)"
  # --no-renames: git's default similarity detection reports an identical-content move as
  # `rename {old => new}` rather than paired create/delete mode lines, which would make the
  # dispatch's literal create-mode/delete-mode assertion inapplicable in the paired case.
  create_count="$(git -C "$fdir" show --no-renames --stat --summary HEAD | grep -c 'create mode' || true)"
  delete_count="$(git -C "$fdir" show --no-renames --stat --summary HEAD | grep -c 'delete mode' || true)"

  local health_out phantom_paths
  health_out="$(bash "$ASSESS_TOOL" --root "$fdir" 2>"$WORKDIR/${tag}_stderr" || true)"
  phantom_paths="$(printf '%s' "$health_out" | jq -r '.phantom_paths // "null"' 2>/dev/null)"

  if [ "$mode" = "paired" ]; then
    if [ "$unstaged_deletions" -eq 0 ]; then
      pass "$label (paired): no unstaged ' D' entry for $src_rel"
    else
      fail "$label (paired): found $unstaged_deletions unstaged ' D' entry/entries for $src_rel"
    fi
    if [ "$create_count" -gt 0 ] && [ "$delete_count" -eq "$create_count" ]; then
      pass "$label (paired): delete mode count ($delete_count) matches create mode count ($create_count)"
    else
      fail "$label (paired): delete mode ($delete_count) does not match create mode ($create_count)"
    fi
    if [ "$phantom_paths" = "0" ]; then
      pass "$label (paired): phantom_paths == 0"
    else
      fail "$label (paired): phantom_paths != 0 (got: $phantom_paths)"
    fi
  else
    # Negative control: the pre-fix dest-only shape must be DETECTED as broken by all three
    # assertions. A pass here means the broken shape was caught, not that it is desirable.
    if [ "$unstaged_deletions" -gt 0 ]; then
      pass "$label (dest-only, negative control): unstaged ' D' entry for $src_rel correctly detected"
    else
      fail "$label (dest-only, negative control): no unstaged ' D' entry detected -- this case would NOT have caught the live defect"
    fi
    if [ "$create_count" -gt 0 ] && [ "$delete_count" -eq 0 ]; then
      pass "$label (dest-only, negative control): create mode present with zero delete mode, as expected of the broken shape"
    else
      fail "$label (dest-only, negative control): expected create mode > 0 and delete mode == 0 (got create=$create_count delete=$delete_count)"
    fi
    if [ "$phantom_paths" != "0" ] && [ "$phantom_paths" != "null" ]; then
      pass "$label (dest-only, negative control): phantom_paths > 0 correctly detected (got: $phantom_paths)"
    else
      fail "$label (dest-only, negative control): phantom_paths not detected as nonzero (got: $phantom_paths) -- this case would NOT have caught the live defect"
    fi
  fi
}

info "Behavioral half: each site shape below runs a PAIRED case (the fix) and a DEST-ONLY case (the negative control reproducing the live defect)."

run_move_pair_case "Step 5D (archive completed task)" "specs/042_fixture_task" "specs/archive/042_fixture_task" "paired"
run_move_pair_case "Step 5D (archive completed task)" "specs/042_fixture_task" "specs/archive/042_fixture_task" "dest-only"

run_move_pair_case "Step 5E.1 (orphan move)" "specs/099_orphan_task" "specs/archive/099_orphan_task" "paired"
run_move_pair_case "Step 5E.1 (orphan move)" "specs/099_orphan_task" "specs/archive/099_orphan_task" "dest-only"

run_move_pair_case "Step 5F (misplaced move)" "specs/misplaced_task" "specs/archive/misplaced_task" "paired"
run_move_pair_case "Step 5F (misplaced move)" "specs/misplaced_task" "specs/archive/misplaced_task" "dest-only"

run_move_pair_case "Stage 15 (enumerated moved_paths[] list)" "specs/123_fixture_task" "specs/archive/123_fixture_task" "paired"
run_move_pair_case "Stage 15 (enumerated moved_paths[] list)" "specs/123_fixture_task" "specs/archive/123_fixture_task" "dest-only"

# =====================================================================
# Static half: assert the real recipe text (and the standard) actually use the pattern the
# behavioral half above just proved works.
# =====================================================================

# count_paren_tokens <content-between-the-parens-of-an-accumulator-call>
# Counts whitespace-separated tokens, treating a double-quoted run as one token.
count_paren_tokens() {
  printf '%s' "$1" | grep -oE '"[^"]*"|[^"() ]+' | wc -l | tr -d ' '
}

# assert_mv_followed_by_pair <file> <mv-line-regex> <accumulator-name> <lookahead-lines> <label>
assert_mv_followed_by_pair() {
  local file="$1" mv_regex="$2" accumulator="$3" lookahead="$4" label="$5"
  local mv_lines
  mv_lines="$(grep -nE "$mv_regex" "$file" | cut -d: -f1)"
  if [ -z "$mv_lines" ]; then
    fail "$label: no \`mv\` line matched $mv_regex in $file -- scope hypothesis invalidated, report rather than silently absorb"
    return
  fi
  local total_lines
  total_lines="$(wc -l < "$file")"
  local line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local window_end=$((line + lookahead))
    [ "$window_end" -gt "$total_lines" ] && window_end="$total_lines"
    local window
    window="$(sed -n "${line},${window_end}p" "$file")"
    local accumulator_line
    accumulator_line="$(printf '%s\n' "$window" | grep -m1 "${accumulator}+=(" || true)"
    if [ -z "$accumulator_line" ]; then
      fail "$label: mv at line $line in $file has no \`${accumulator}+=\` within the next $lookahead lines"
      continue
    fi
    local paren_content
    paren_content="$(printf '%s' "$accumulator_line" | sed -n "s/.*${accumulator}+=(\\(.*\\)).*/\\1/p")"
    local token_count
    token_count="$(count_paren_tokens "$paren_content")"
    if [ "$token_count" -ge 2 ]; then
      pass "$label: mv at line $line in $file is paired by \`${accumulator}+=\` naming $token_count tokens"
    else
      fail "$label: mv at line $line in $file has \`${accumulator}+=\` naming only $token_count token (dest-only shape) -- content: $paren_content"
    fi
  done <<< "$mv_lines"
}

assert_mv_followed_by_pair "$TODO_MD" 'mv "' "stage_paths" 10 "commands/todo.md"
assert_mv_followed_by_pair "$SKILL_MD" 'mv "' "moved_paths" 20 "skill-todo/SKILL.md"

# Prose-level Stage 10 steps 4, 5, 7 (no bash mv line to anchor on) each instruct appending to
# moved_paths[] in their own step text. Anchored to a bounded window (not a whole-file greedy
# match) so this cannot pass merely because `moved_paths+=` appears somewhere later in the file.
PROSE_LOOKAHEAD=6
for anchor_pattern in \
  'Move project directories to specs/archive' \
  'Track orphaned directories' \
  'Move misplaced directories'
do
  anchor_line="$(grep -n "$anchor_pattern" "$SKILL_MD" | head -1 | cut -d: -f1)"
  if [ -z "$anchor_line" ]; then
    fail "skill-todo/SKILL.md: anchor step '$anchor_pattern' not found at all"
    continue
  fi
  window_end=$((anchor_line + PROSE_LOOKAHEAD))
  window="$(sed -n "${anchor_line},${window_end}p" "$SKILL_MD")"
  if printf '%s\n' "$window" | grep -q 'moved_paths+='; then
    pass "skill-todo/SKILL.md: step '$anchor_pattern' (line $anchor_line) instructs appending to moved_paths[] within $PROSE_LOOKAHEAD lines"
  else
    fail "skill-todo/SKILL.md: step '$anchor_pattern' (line $anchor_line) has no moved_paths+= instruction within $PROSE_LOOKAHEAD lines"
  fi
done

# Exactly one git add line, consuming moved_paths[], staging neither specs/archive/ nor a bare
# specs/ token.
git_add_count="$(grep -cE 'git add specs/' "$SKILL_MD" || true)"
if [ "$git_add_count" -eq 1 ]; then
  pass "skill-todo/SKILL.md: exactly one 'git add specs/...' line found"
else
  fail "skill-todo/SKILL.md: expected exactly one 'git add specs/...' line, found $git_add_count"
fi
stage15_line="$(grep -n 'git add specs/TODO.md specs/state.json' "$SKILL_MD" || true)"
if [ -n "$stage15_line" ]; then
  pass "skill-todo/SKILL.md: Stage 15's git add line found and contains the expected literal form"
  if printf '%s' "$stage15_line" | grep -q '"\${moved_paths\[@\]}"'; then
    pass "skill-todo/SKILL.md: Stage 15's git add consumes \"\${moved_paths[@]}\""
  else
    fail "skill-todo/SKILL.md: Stage 15's git add does not consume \"\${moved_paths[@]}\""
  fi
  if printf '%s' "$stage15_line" | grep -q 'specs/archive/'; then
    fail "skill-todo/SKILL.md: Stage 15's git add still stages a bare specs/archive/ token"
  else
    pass "skill-todo/SKILL.md: Stage 15's git add does not stage specs/archive/"
  fi
else
  fail "skill-todo/SKILL.md: Stage 15's expected git add literal form not found"
fi

if grep -q '^## Rename and Directory-Move Staging$' "$STAGING_STD"; then
  pass "git-staging-scope.md: '## Rename and Directory-Move Staging' section exists"
else
  fail "git-staging-scope.md: '## Rename and Directory-Move Staging' section NOT found"
fi

echo ""
echo "$PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
