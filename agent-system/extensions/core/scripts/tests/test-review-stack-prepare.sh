#!/usr/bin/env bash
# test-review-stack-prepare.sh - Fixture-driven regression suite for review-stack-prepare.sh's
# Phase 1 surface: integration-branch resolution, every PD1 review_base refusal, every PD9
# platform refusal, every remote-resolution branch, and the two static assertions (no
# push/forge/branch-switching invocation; no literal remote or branch name). Each case uses a
# fixture whose remote is named neither `origin` nor `upstream` and whose branch is named
# neither `main` nor `master`, so a hardcoded assumption of any of those names would make the
# matching case fail rather than pass by accident.
#
# Follows the deployed-shape sandbox convention established by test-milestone-review-handoff.sh
# (deploy-root-guard.sh's default structural check requires the script's own directory to end
# in /.claude or /.opencode).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
RSP="$SCRIPT_DIR/../review-stack-prepare.sh"
GUARD="$SCRIPT_DIR/../deploy-root-guard.sh"

PASSED=0
FAILED=0

if [ ! -f "$RSP" ]; then
  echo "ERROR: expected review-stack-prepare.sh at $RSP" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 1
fi

common_test_workdir_init

REMOTE_NAME="fixremote"
REMOTE2_NAME="fixremote2"
BRANCH="integration-work"

# install_scripts <repo> -- the deployed-shape copies the script under test needs.
install_scripts() {
  local d="$1"
  mkdir -p "$d/specs" "$d/.claude/scripts/lib"
  cp -r "$SCRIPT_DIR/../lib/." "$d/.claude/scripts/lib/"
  cp "$GUARD" "$d/.claude/scripts/deploy-root-guard.sh"
  cp "$RSP" "$d/.claude/scripts/review-stack-prepare.sh"
  chmod +x "$d"/.claude/scripts/*.sh
}

# make_fixture_repo [review_base_json] -- a sandbox on $BRANCH with a bare remote reachable over
# a file:// URL that LOOKS like a GitHub remote (it embeds "github.com" in its path so the
# platform detector's substring match recognises it without needing a real network remote). Two
# commits exist; the first is tagged "basepoint" so a review base distinct from $BRANCH is
# always resolvable. [review_base_json] is written into .claude-extensions.json verbatim when
# given (a JSON object literal, e.g. '{"review_base":"basepoint"}'); omitted means no
# .claude-extensions.json is written at all (review_base undeclared).
make_fixture_repo() {
  local ext_json="${1:-}"
  local d bare
  d="$(mktemp -d -p "$WORKDIR")"
  bare="$(mktemp -d -p "$WORKDIR")/github.com/fixture/repo.git"
  mkdir -p "$(dirname "$bare")"
  git init -q --bare "$bare"
  git init -q -b "$BRANCH" "$d"
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test Suite"
  install_scripts "$d"
  echo seed > "$d/f.txt"
  git -C "$d" add f.txt >/dev/null 2>&1
  git -C "$d" commit -q -m seed >/dev/null 2>&1
  git -C "$d" tag basepoint
  echo more > "$d/f.txt"
  git -C "$d" add f.txt >/dev/null 2>&1
  git -C "$d" commit -q -m advance >/dev/null 2>&1
  git -C "$d" remote add "$REMOTE_NAME" "file://${bare}"
  if [ -n "$ext_json" ]; then
    printf '%s' "$ext_json" > "$d/.claude-extensions.json"
  fi
  printf '%s' "$d"
}

run_rsp() {
  local repo="$1"
  shift
  LAST_OUT="$(cd "$repo" && bash .claude/scripts/review-stack-prepare.sh "$@" 2>&1)"
  LAST_CODE=$?
}

assert_refusal() {
  local label="$1" expected_code="$2" expected_reason="$3"
  if [ "$LAST_CODE" -eq "$expected_code" ] && printf '%s' "$LAST_OUT" | grep -q "REFUSED: review-stack-prepare.sh: ${expected_reason}:"; then
    common_test_pass "$label"
  else
    common_test_fail "$label" "expected exit ${expected_code} with reason ${expected_reason}, got exit ${LAST_CODE}: ${LAST_OUT}"
  fi
}

# =====================================================================
# PD1 refusals
# =====================================================================

repo="$(make_fixture_repo)"
run_rsp "$repo" cut --dry-run
assert_refusal "PD1: review_base undeclared refuses with review_base_undeclared, exit 10" 10 review_base_undeclared
rm -rf "$repo"

repo="$(make_fixture_repo '{"review_base": ""}')"
run_rsp "$repo" cut --dry-run
assert_refusal "PD1: declared review_base is an empty string refuses with review_base_invalid, exit 11" 11 review_base_invalid
rm -rf "$repo"

repo="$(make_fixture_repo '{"review_base": 42}')"
run_rsp "$repo" cut --dry-run
assert_refusal "PD1: declared review_base is a non-string refuses with review_base_invalid, exit 11" 11 review_base_invalid
rm -rf "$repo"

repo="$(make_fixture_repo '{"review_base": "no-such-ref-anywhere"}')"
run_rsp "$repo" cut --dry-run
assert_refusal "PD1: declared review_base does not resolve to a commit refuses with review_base_unresolvable, exit 12" 12 review_base_unresolvable
rm -rf "$repo"

repo="$(make_fixture_repo "{\"review_base\": \"${BRANCH}\"}")"
run_rsp "$repo" cut --dry-run
assert_refusal "PD1: declared review_base names the integration branch refuses with review_base_is_integration_branch, exit 13" 13 review_base_is_integration_branch
rm -rf "$repo"

# --review-base override hits the same five refusals (checked once, the undeclared case, since
# the override bypasses "undeclared" by construction -- empty override still refuses invalid).
repo="$(make_fixture_repo)"
run_rsp "$repo" cut --dry-run --review-base ""
assert_refusal "PD1: an empty --review-base override refuses with review_base_invalid, exit 11 (not undeclared)" 11 review_base_invalid
rm -rf "$repo"

repo="$(make_fixture_repo)"
# show, not cut: Phase 2 made cut's own body need a selection (--milestone/--batch/--tasks), so
# this assertion -- about the review_base resolver shared by every subcommand, not about cut's
# selection/ordering body -- now exercises show, whose body is still the Phase 1 placeholder.
run_rsp "$repo" show --dry-run --review-base basepoint
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -q "review_base='basepoint'"; then
  common_test_pass "PD1: a valid --review-base override resolves and is not refused"
else
  common_test_fail "PD1: valid --review-base override" "expected exit 0 with review_base=basepoint, got exit ${LAST_CODE}: ${LAST_OUT}"
fi
rm -rf "$repo"

# =====================================================================
# PD9 platform refusals (review_base valid throughout, via basepoint)
# =====================================================================

repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
git -C "$repo" remote set-url "$REMOTE_NAME" "https://gitlab.com/fixture/repo.git"
run_rsp "$repo" cut --dry-run
assert_refusal "PD9: a GitLab remote refuses with platform_gitlab_unsupported, exit 30" 30 platform_gitlab_unsupported
rm -rf "$repo"

repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
git -C "$repo" remote set-url "$REMOTE_NAME" "https://example.com/fixture/repo.git"
run_rsp "$repo" cut --dry-run
assert_refusal "PD9: an unrecognised host refuses with platform_unrecognized_host, exit 31" 31 platform_unrecognized_host
rm -rf "$repo"

repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
git -C "$repo" remote set-url "$REMOTE_NAME" "https://github.com/fixture/repo.git"
git -C "$repo" remote set-url --push "$REMOTE_NAME" "https://github.com/fixture/other.git"
run_rsp "$repo" cut --dry-run
assert_refusal "PD9: a push URL differing from the fetch URL refuses with platform_push_url_mismatch, exit 32" 32 platform_push_url_mismatch
rm -rf "$repo"

repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
# show, not cut: see the note above the PD1 override case for why.
run_rsp "$repo" show --dry-run
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -q "platform='github'"; then
  common_test_pass "PD9: a github.com remote with matching fetch/push URLs resolves to platform=github"
else
  common_test_fail "PD9: github platform resolution" "expected exit 0 with platform=github, got exit ${LAST_CODE}: ${LAST_OUT}"
fi
rm -rf "$repo"

# =====================================================================
# Remote-resolution branches
# =====================================================================

# Branch: --remote always wins, even with no remote of that name configured's URL unresolved by
# other means (ambiguous remotes still resolved explicitly).
repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
git -C "$repo" remote rename "$REMOTE_NAME" "$REMOTE2_NAME"
bare2_dir="$(mktemp -d -p "$WORKDIR")/github.com/fixture/other.git"
mkdir -p "$(dirname "$bare2_dir")"
git init -q --bare "$bare2_dir"
git -C "$repo" remote add "$REMOTE_NAME" "file://${bare2_dir}"
# show, not cut: see the note above the PD1 override case for why.
run_rsp "$repo" show --dry-run --remote "$REMOTE_NAME"
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -q "remote='${REMOTE_NAME}'"; then
  common_test_pass "remote resolution: --remote NAME is used even with another remote present"
else
  common_test_fail "remote resolution: --remote override" "expected exit 0 with remote=${REMOTE_NAME}, got exit ${LAST_CODE}: ${LAST_OUT}"
fi
rm -rf "$repo"

# Branch: the integration branch's configured remote (git config branch.<name>.remote) wins
# when --remote is not given and more than one remote exists.
repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
git -C "$repo" remote rename "$REMOTE_NAME" "$REMOTE2_NAME"
bare3_dir="$(mktemp -d -p "$WORKDIR")/github.com/fixture/third.git"
mkdir -p "$(dirname "$bare3_dir")"
git init -q --bare "$bare3_dir"
git -C "$repo" remote add "$REMOTE_NAME" "file://${bare3_dir}"
git -C "$repo" config "branch.${BRANCH}.remote" "$REMOTE_NAME"
# show, not cut: see the note above the PD1 override case for why.
run_rsp "$repo" show --dry-run
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -q "remote='${REMOTE_NAME}'"; then
  common_test_pass "remote resolution: the integration branch's configured remote wins over an unconfigured second remote"
else
  common_test_fail "remote resolution: configured-remote branch" "expected exit 0 with remote=${REMOTE_NAME}, got exit ${LAST_CODE}: ${LAST_OUT}"
fi
rm -rf "$repo"

# Branch: with no --remote and no branch config, the repository's single remote is used.
repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
# show, not cut: see the note above the PD1 override case for why.
run_rsp "$repo" show --dry-run
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -q "remote='${REMOTE_NAME}'"; then
  common_test_pass "remote resolution: the repository's only remote is used with no --remote and no branch config"
else
  common_test_fail "remote resolution: only-remote branch" "expected exit 0 with remote=${REMOTE_NAME}, got exit ${LAST_CODE}: ${LAST_OUT}"
fi
rm -rf "$repo"

# Branch: two remotes, no --remote, no branch config -> ambiguous, refuses asking for --remote.
repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
bare4_dir="$(mktemp -d -p "$WORKDIR")/github.com/fixture/fourth.git"
mkdir -p "$(dirname "$bare4_dir")"
git init -q --bare "$bare4_dir"
git -C "$repo" remote add "$REMOTE2_NAME" "file://${bare4_dir}"
run_rsp "$repo" cut --dry-run
assert_refusal "remote resolution: two remotes with no override or branch config refuses with remote_unresolvable, exit 20" 20 remote_unresolvable
rm -rf "$repo"

# Branch: zero remotes, no --remote -> refuses with remote_unresolvable.
repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
git -C "$repo" remote remove "$REMOTE_NAME"
run_rsp "$repo" cut --dry-run
assert_refusal "remote resolution: zero remotes with no override refuses with remote_unresolvable, exit 20" 20 remote_unresolvable
rm -rf "$repo"

# =====================================================================
# Phase 2: selection, units and order fixtures
# =====================================================================
# Every fixture below declares review_base at "basepoint" (via make_fixture_repo) and adds its
# own specs/state.json entries, specs/.orchestration/batch/<session>.json landing proofs, and
# commits on $BRANCH, then selects with --tasks/--stack-id and reads the printed "UNIT NN:
# tasks=... branch=... base=... end=..." lines cut's Phase 2 body prints.

# task-ref-ok:begin category 6-adjacent: the 9xx fixture task numbers and the "task N: ..."
# commit subjects from here to the matching end marker are synthetic fixture data. The script
# under test reads landing proofs by task number and, absent one, the literal "task N:" commit-
# subject convention, so the fixtures must carry concrete digits.

STACK_SESSION="sess_test_stack"

_csv_to_json_array_numbers() {
  local csv="$1"
  [ -n "$csv" ] || { echo '[]'; return 0; }
  printf '%s' "$csv" | tr ',' '\n' | jq -R 'tonumber' | jq -s -c '.'
}

_csv_to_json_array_strings() {
  local csv="$1"
  [ -n "$csv" ] || { echo '[]'; return 0; }
  printf '%s' "$csv" | tr ',' '\n' | jq -R . | jq -s -c '.'
}

# stack_fixture_repo -- a fresh fixture repo with review_base declared ("basepoint"), plus an
# empty specs/state.json and an empty specs/.orchestration/batch/ directory.
stack_fixture_repo() {
  local d
  d="$(make_fixture_repo '{"review_base": "basepoint"}')"
  mkdir -p "$d/specs/.orchestration/batch"
  echo '{"active_projects": []}' > "$d/specs/state.json"
  printf '%s' "$d"
}

# stack_add_task_entry <repo> <task> <slug> <deps_csv> <created_iso> -- appends an
# active_projects entry to specs/state.json.
stack_add_task_entry() {
  local repo="$1" task="$2" slug="$3" deps_csv="$4" created="$5" deps_json tmp
  deps_json="$(_csv_to_json_array_numbers "$deps_csv")"
  tmp="$(mktemp)"
  jq --argjson n "$task" --arg slug "$slug" --argjson deps "$deps_json" --arg created "$created" \
    '.active_projects += [{"project_number": $n, "project_name": $slug, "dependencies": $deps, "created": $created, "status": "completed"}]' \
    "$repo/specs/state.json" > "$tmp" && mv "$tmp" "$repo/specs/state.json"
}

# stack_commit <repo> <task> <file> <subject_suffix> -- writes and commits <file> on $BRANCH
# with subject "task <task>: <subject_suffix>"; sets LAST_SHA to the new commit.
stack_commit() {
  local repo="$1" task="$2" file="$3" suffix="$4"
  echo "content-${RANDOM}-${file}" > "$repo/$file"
  git -C "$repo" add "$file" >/dev/null 2>&1
  git -C "$repo" commit -q -m "task ${task}: ${suffix}" >/dev/null 2>&1
  LAST_SHA="$(git -C "$repo" rev-parse HEAD)"
}

# stack_write_batch <repo> <task_numbers_csv> -- creates/overwrites the one batch record this
# fixture's proofs are appended to, naming <task_numbers_csv> in its `task_numbers`.
stack_write_batch() {
  local repo="$1" tasks_csv="$2" tasks_json
  tasks_json="$(_csv_to_json_array_numbers "$tasks_csv")"
  jq -n --argjson tasks "$tasks_json" \
    '{schema: 1, session_id: "sess_test_stack", task_numbers: $tasks, admitted_at: "2026-01-01T00:00:00Z", integration_branch: null, landing_proofs: []}' \
    > "$repo/specs/.orchestration/batch/${STACK_SESSION}.json"
}

# stack_add_proof <repo> <task> <end_commit> <paths_csv> [shared_csv] -- appends one landing
# proof to the batch record stack_write_batch created.
stack_add_proof() {
  local repo="$1" task="$2" end="$3" paths_csv="$4" shared_csv="${5:-}" paths_json shared_json tmp
  paths_json="$(_csv_to_json_array_strings "$paths_csv")"
  shared_json="$(_csv_to_json_array_strings "$shared_csv")"
  tmp="$(mktemp)"
  jq --argjson n "$task" --arg end "$end" --argjson paths "$paths_json" --argjson shared "$shared_json" \
    '.landing_proofs += [{"task_number": $n, "end_commit": $end, "commits": [$end], "paths": $paths, "shared_paths": $shared}]' \
    "$repo/specs/.orchestration/batch/${STACK_SESSION}.json" > "$tmp" \
    && mv "$tmp" "$repo/specs/.orchestration/batch/${STACK_SESSION}.json"
}

# unit_field <nn> <field> -- stdout: the value of <field> ("tasks"|"branch"|"base"|"end") on the
# "UNIT <nn>: ..." line of $LAST_OUT, or nothing.
unit_field() {
  local nn="$1" field="$2"
  printf '%s\n' "$LAST_OUT" | grep -E "^UNIT ${nn}: " | grep -oE "${field}=[^ ]*" | head -n 1 | cut -d= -f2-
}

# unit_count -- stdout: the number of "UNIT NN: ..." lines in $LAST_OUT.
unit_count() {
  printf '%s\n' "$LAST_OUT" | grep -cE "^UNIT [0-9]+: " || true
}

# --- three dependent tasks order bottom-up (bottom <- mid <- top), disjoint paths -----------
repo="$(stack_fixture_repo)"
stack_write_batch "$repo" "901,902,903"
stack_add_task_entry "$repo" 901 "task-901-base" "" "2020-01-01T00:00:00Z"
stack_commit "$repo" 901 "f901.txt" "base work"
stack_add_proof "$repo" 901 "$LAST_SHA" "f901.txt"
stack_add_task_entry "$repo" 902 "task-902-mid" "901" "2020-01-02T00:00:00Z"
stack_commit "$repo" 902 "f902.txt" "mid work"
stack_add_proof "$repo" 902 "$LAST_SHA" "f902.txt"
stack_add_task_entry "$repo" 903 "task-903-top" "902" "2020-01-03T00:00:00Z"
stack_commit "$repo" 903 "f903.txt" "top work"
stack_add_proof "$repo" 903 "$LAST_SHA" "f903.txt"
before_head="$(git -C "$repo" rev-parse HEAD)"
before_status="$(git -C "$repo" status --porcelain)"
run_rsp "$repo" cut --dry-run --tasks 901,902,903 --stack-id stackA
after_head="$(git -C "$repo" rev-parse HEAD)"
after_status="$(git -C "$repo" status --porcelain)"
if [ "$LAST_CODE" -eq 0 ] && [ "$(unit_count)" -eq 3 ] \
   && [ "$(unit_field 01 tasks)" = "901" ] && [ "$(unit_field 01 base)" = "basepoint" ] \
   && [ "$(unit_field 02 tasks)" = "902" ] && [ "$(unit_field 02 base)" = "$(unit_field 01 branch)" ] \
   && [ "$(unit_field 03 tasks)" = "903" ] && [ "$(unit_field 03 base)" = "$(unit_field 02 branch)" ] \
   && [ "$before_head" = "$after_head" ] && [ "$before_status" = "$after_status" ]; then
  common_test_pass "cut: three dependent tasks order bottom-up with chained bases, creating no ref and no file"
else
  common_test_fail "cut: three dependent tasks order bottom-up" "exit=${LAST_CODE} out=${LAST_OUT} before_head=${before_head} after_head=${after_head}"
fi
rm -rf "$repo"

# --- two path-disjoint dependent tasks follow the edge even against landing order ----------
repo="$(stack_fixture_repo)"
stack_write_batch "$repo" "910,911"
stack_add_task_entry "$repo" 910 "task-910-base" "" "2020-01-01T00:00:00Z"
stack_add_task_entry "$repo" 911 "task-911-top" "910" "2020-01-02T00:00:00Z"
# Commit 911's work before 910's, so the landed commit order contradicts the dependency order;
# the two files are disjoint so this must not refuse.
stack_commit "$repo" 911 "f911.txt" "top work landed first"
stack_add_proof "$repo" 911 "$LAST_SHA" "f911.txt"
stack_commit "$repo" 910 "f910.txt" "base work landed second"
stack_add_proof "$repo" 910 "$LAST_SHA" "f910.txt"
run_rsp "$repo" cut --dry-run --tasks 910,911 --stack-id stackB
if [ "$LAST_CODE" -eq 0 ] && [ "$(unit_count)" -eq 2 ] \
   && [ "$(unit_field 01 tasks)" = "910" ] && [ "$(unit_field 01 base)" = "basepoint" ] \
   && [ "$(unit_field 02 tasks)" = "911" ] && [ "$(unit_field 02 base)" = "$(unit_field 01 branch)" ]; then
  common_test_pass "cut: two path-disjoint tasks follow the dependency edge even against landing order"
else
  common_test_fail "cut: path-disjoint tasks vs landing order" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- two path-overlapping tasks ordered against landing order are refused ------------------
repo="$(stack_fixture_repo)"
stack_write_batch "$repo" "920,921"
stack_add_task_entry "$repo" 920 "task-920-base" "" "2020-01-01T00:00:00Z"
stack_add_task_entry "$repo" 921 "task-921-top" "920" "2020-01-02T00:00:00Z"
# Same path-overlap setup as above, but the two tasks share a path, so the dependency edge now
# disagrees with the landed order on an overlapping file: a refusal, not a silent reorder.
stack_commit "$repo" 921 "f_shared.txt" "top work landed first"
stack_add_proof "$repo" 921 "$LAST_SHA" "f_shared.txt"
stack_commit "$repo" 920 "f_shared.txt" "base work landed second"
stack_add_proof "$repo" 920 "$LAST_SHA" "f_shared.txt"
run_rsp "$repo" cut --dry-run --tasks 920,921 --stack-id stackC
assert_refusal "cut: two path-overlapping tasks ordered against landing order refuse with order_contradiction, exit 45" 45 order_contradiction
rm -rf "$repo"

# --- a shared_paths pair becomes one unit ---------------------------------------------------
repo="$(stack_fixture_repo)"
stack_write_batch "$repo" "930,931"
stack_add_task_entry "$repo" 930 "task-930" "" "2020-01-01T00:00:00Z"
stack_add_task_entry "$repo" 931 "task-931" "" "2020-01-02T00:00:00Z"
stack_commit "$repo" 930 "f_coland.txt" "first half"
stack_add_proof "$repo" 930 "$LAST_SHA" "f_coland.txt" "f_coland.txt"
stack_commit "$repo" 931 "f_coland.txt" "second half"
stack_add_proof "$repo" 931 "$LAST_SHA" "f_coland.txt"
run_rsp "$repo" cut --dry-run --tasks 930,931 --stack-id stackD
if [ "$LAST_CODE" -eq 0 ] && [ "$(unit_count)" -eq 1 ] \
   && { [ "$(unit_field 01 tasks)" = "930,931" ] || [ "$(unit_field 01 tasks)" = "931,930" ]; }; then
  common_test_pass "cut: a shared_paths pair becomes one unit"
else
  common_test_fail "cut: shared_paths pair becomes one unit" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- a no-proof task is attributed by commit subject and marked ----------------------------
repo="$(stack_fixture_repo)"
stack_add_task_entry "$repo" 940 "task-940" "" "2020-01-01T00:00:00Z"
stack_commit "$repo" 940 "f940.txt" "no-proof work"
run_rsp "$repo" cut --dry-run --tasks 940 --stack-id stackE
if [ "$LAST_CODE" -eq 0 ] && [ "$(unit_count)" -eq 1 ] \
   && [ "$(unit_field 01 tasks)" = "940" ] \
   && printf '%s' "$LAST_OUT" | grep -q "no_proof=true"; then
  common_test_pass "cut: a no-proof task is attributed by commit subject and marked no_proof=true"
else
  common_test_fail "cut: no-proof task attribution" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- two components yield two stacks, each bottomed on the review base ---------------------
repo="$(stack_fixture_repo)"
stack_write_batch "$repo" "950,960"
stack_add_task_entry "$repo" 950 "task-950" "" "2020-01-01T00:00:00Z"
stack_commit "$repo" 950 "f950.txt" "standalone one"
stack_add_proof "$repo" 950 "$LAST_SHA" "f950.txt"
stack_add_task_entry "$repo" 960 "task-960" "" "2020-01-02T00:00:00Z"
stack_commit "$repo" 960 "f960.txt" "standalone two"
stack_add_proof "$repo" 960 "$LAST_SHA" "f960.txt"
run_rsp "$repo" cut --dry-run --tasks 950,960 --stack-id stackF
if [ "$LAST_CODE" -eq 0 ] && [ "$(unit_count)" -eq 2 ] \
   && [ "$(unit_field 01 base)" = "basepoint" ] && [ "$(unit_field 02 base)" = "basepoint" ]; then
  common_test_pass "cut: two components yield two stacks, each bottomed on the review base"
else
  common_test_fail "cut: two components, two stacks" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- an earlier unmerged task sharing a path with the selection is pulled in ---------------
repo="$(stack_fixture_repo)"
stack_write_batch "$repo" "970,971"
stack_add_task_entry "$repo" 970 "task-970" "" "2020-01-02T00:00:00Z"
stack_add_task_entry "$repo" 971 "task-971" "" "2020-01-01T00:00:00Z"
# 971 lands first and is NOT in the --tasks selection below; it shares f_pullin.txt with 970
# and its end commit is not yet an ancestor of the review base, so it must be pulled in.
stack_commit "$repo" 971 "f_pullin.txt" "earlier unmerged work"
stack_add_proof "$repo" 971 "$LAST_SHA" "f_pullin.txt"
stack_commit "$repo" 970 "f_pullin.txt" "later selected work"
stack_add_proof "$repo" 970 "$LAST_SHA" "f_pullin.txt"
run_rsp "$repo" cut --dry-run --tasks 970 --stack-id stackG
if [ "$LAST_CODE" -eq 0 ] && [ "$(unit_count)" -eq 2 ] \
   && printf '%s' "$LAST_OUT" | grep -q "pulled in task 971" \
   && { [ "$(unit_field 01 tasks)" = "971" ] || [ "$(unit_field 02 tasks)" = "971" ]; } \
   && { [ "$(unit_field 01 tasks)" = "970" ] || [ "$(unit_field 02 tasks)" = "970" ]; }; then
  common_test_pass "cut: an earlier unmerged task sharing a path with the selection is pulled in"
else
  common_test_fail "cut: earlier-unmerged-task pull-in" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- selection refusals: no selection flag, and a batch/tasks selection with no --stack-id -
repo="$(stack_fixture_repo)"
run_rsp "$repo" cut --dry-run
assert_refusal "cut: no selection flag refuses with selection_missing, exit 40" 40 selection_missing
rm -rf "$repo"

repo="$(stack_fixture_repo)"
run_rsp "$repo" cut --dry-run --tasks 901
assert_refusal "cut: --tasks with no --stack-id refuses with stack_id_required, exit 41" 41 stack_id_required
rm -rf "$repo"

# =====================================================================
# Phase 3: cut builds the review commits and the manifest; show prints them.
# =====================================================================

# manifest_entry_field <repo> <stack_id> <ordinal> <field> -- stdout.
manifest_entry_field() {
  local repo="$1" sid="$2" ord="$3" field="$4"
  jq -r --argjson n "$ord" --arg f "$field" \
    "(.entries[] | select(.ordinal == \$n) | .[\$f])" \
    "$repo/specs/.orchestration/reviews/${sid}/manifest.json" 2>/dev/null
}

# --- cut builds three branches, each parented on the one below, each diff disjoint ---------
repo="$(stack_fixture_repo)"
stack_write_batch "$repo" "981,982,983"
stack_add_task_entry "$repo" 981 "task-981-base" "" "2020-01-01T00:00:00Z"
stack_commit "$repo" 981 "f981.txt" "base work"
stack_add_proof "$repo" 981 "$LAST_SHA" "f981.txt"
stack_add_task_entry "$repo" 982 "task-982-mid" "981" "2020-01-02T00:00:00Z"
stack_commit "$repo" 982 "f982.txt" "mid work"
stack_add_proof "$repo" 982 "$LAST_SHA" "f982.txt"
stack_add_task_entry "$repo" 983 "task-983-top" "982" "2020-01-03T00:00:00Z"
stack_commit "$repo" 983 "f983.txt" "top work"
stack_add_proof "$repo" 983 "$LAST_SHA" "f983.txt"
before_head="$(git -C "$repo" rev-parse HEAD)"
before_status="$(git -C "$repo" status --porcelain)"
run_rsp "$repo" cut --tasks 981,982,983 --stack-id stackP3A
after_head="$(git -C "$repo" rev-parse HEAD)"
after_status="$(git -C "$repo" status --porcelain)"
b1="$(unit_field 01 branch)"
b2="$(unit_field 02 branch)"
b3="$(unit_field 03 branch)"
if [ "$LAST_CODE" -eq 0 ] \
   && [ "$(git -C "$repo" rev-parse --verify -q "refs/heads/${b1}")" = "$(git -C "$repo" rev-parse "$b1")" ] \
   && [ "$(git -C "$repo" rev-parse "${b1}^1")" = "$(git -C "$repo" rev-parse basepoint)" ] \
   && [ "$(git -C "$repo" rev-parse "${b2}^1")" = "$(git -C "$repo" rev-parse "$b1")" ] \
   && [ "$(git -C "$repo" rev-parse "${b3}^1")" = "$(git -C "$repo" rev-parse "$b2")" ] \
   && [ "$(git -C "$repo" diff --name-only basepoint.."$b1")" = "f981.txt" ] \
   && [ "$(git -C "$repo" diff --name-only "$b1".."$b2")" = "f982.txt" ] \
   && [ "$(git -C "$repo" diff --name-only "$b2".."$b3")" = "f983.txt" ] \
   && [ "$before_head" = "$after_head" ] && [ "$before_status" = "$after_status" ]; then
  common_test_pass "cut: three branches, each parented on the one below, each diff holding only its own unit's paths"
else
  common_test_fail "cut: three branches real build" "exit=${LAST_CODE} out=${LAST_OUT} before_head=${before_head} after_head=${after_head}"
fi

# --- the top commit differs from the integration tip only outside every unit's path set -----
top_diff="$(git -C "$repo" diff --name-only "$b3" "$BRANCH")"
leak="false"
while IFS= read -r p; do
  [ -n "$p" ] || continue
  case "$p" in f981.txt | f982.txt | f983.txt) leak="true" ;; esac
done <<< "$top_diff"
if [ "$leak" = "false" ] && [ -n "$top_diff" ]; then
  common_test_pass "cut: the top-of-stack commit differs from the integration tip only in paths outside every unit's set"
else
  common_test_fail "cut: top-of-stack vs integration tip diff" "top_diff=[${top_diff}] leak=${leak}"
fi

# --- the manifest and the PR bodies were written with the expected shape -------------------
manifest_file="$repo/specs/.orchestration/reviews/stackP3A/manifest.json"
if [ -f "$manifest_file" ] \
   && [ "$(manifest_entry_field "$repo" stackP3A 1 branch)" = "$b1" ] \
   && [ "$(manifest_entry_field "$repo" stackP3A 1 base)" = "basepoint" ] \
   && [ "$(manifest_entry_field "$repo" stackP3A 1 title)" = "base work" ] \
   && [ "$(manifest_entry_field "$repo" stackP3A 2 base)" = "$b1" ] \
   && [ "$(manifest_entry_field "$repo" stackP3A 3 base)" = "$b2" ] \
   && [ -f "$(manifest_entry_field "$repo" stackP3A 1 body_path)" ] \
   && grep -q '## Relationship to other PRs' "$(manifest_entry_field "$repo" stackP3A 1 body_path)" \
   && grep -qF "$b2" "$(manifest_entry_field "$repo" stackP3A 1 body_path)"; then
  common_test_pass "cut: writes a manifest with chained bases/titles and a PR body per entry naming its child"
else
  common_test_fail "cut: manifest and body shape" "manifest=$(cat "$manifest_file" 2>/dev/null)"
fi

# --- idempotent re-cut: unchanged inputs move no ref and change no commit sha --------------
before_refs="$(git -C "$repo" for-each-ref refs/heads | LC_ALL=C sort)"
run_rsp "$repo" cut --tasks 981,982,983 --stack-id stackP3A
after_refs="$(git -C "$repo" for-each-ref refs/heads | LC_ALL=C sort)"
if [ "$LAST_CODE" -eq 0 ] && [ "$before_refs" = "$after_refs" ]; then
  common_test_pass "cut: a re-cut with unchanged inputs is a no-op (no ref moves, no new commit)"
else
  common_test_fail "cut: idempotent re-cut" "before=[${before_refs}] after=[${after_refs}]"
fi

# --- show prints the manifest's branch/base/title/body_path and the literal commands -------
run_rsp "$repo" show --stack-id stackP3A
if [ "$LAST_CODE" -eq 0 ] \
   && printf '%s' "$LAST_OUT" | grep -qF "branch=${b1} base=basepoint title=base work" \
   && printf '%s' "$LAST_OUT" | grep -qF "/please push ${REMOTE_NAME} ${b1}" \
   && printf '%s' "$LAST_OUT" | grep -qF "/merge --stack stackP3A" \
   && printf '%s' "$LAST_OUT" | grep -qF "3 entrie(s)"; then
  common_test_pass "show: prints each entry's branch/base/title/body_path and the literal push/merge commands"
else
  common_test_fail "show: printed stack" "out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- show --json emits the manifest verbatim; show with no stack id is unaffected ----------
repo="$(stack_fixture_repo)"
stack_write_batch "$repo" "984"
stack_add_task_entry "$repo" 984 "task-984" "" "2020-01-01T00:00:00Z"
stack_commit "$repo" 984 "f984.txt" "solo work"
stack_add_proof "$repo" 984 "$LAST_SHA" "f984.txt"
run_rsp "$repo" cut --tasks 984 --stack-id stackP3B
run_rsp "$repo" show --stack-id stackP3B --json
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | jq -e '.stack_id == "stackP3B" and (.entries | length) == 1' >/dev/null 2>&1; then
  common_test_pass "show --json: emits the manifest verbatim"
else
  common_test_fail "show --json" "out=${LAST_OUT}"
fi
run_rsp "$repo" show --dry-run --stack-id missing-stack
assert_refusal "show: an unknown stack id refuses with manifest_missing, exit 50" 50 manifest_missing
rm -rf "$repo"

# --- record-request fills the request field, surviving an unchanged re-cut -----------------
repo="$(stack_fixture_repo)"
stack_write_batch "$repo" "985"
stack_add_task_entry "$repo" 985 "task-985" "" "2020-01-01T00:00:00Z"
stack_commit "$repo" 985 "f985.txt" "solo work"
stack_add_proof "$repo" 985 "$LAST_SHA" "f985.txt"
run_rsp "$repo" cut --tasks 985 --stack-id stackP3C
run_rsp "$repo" record-request 1 https://example.invalid/pr/1 --stack-id stackP3C
run_rsp "$repo" cut --tasks 985 --stack-id stackP3C
if [ "$(manifest_entry_field "$repo" stackP3C 1 request)" = "https://example.invalid/pr/1" ]; then
  common_test_pass "record-request: fills the request field, and a re-cut with an unchanged commit preserves it"
else
  common_test_fail "record-request" "request=$(manifest_entry_field "$repo" stackP3C 1 request)"
fi
rm -rf "$repo"

# --- a review base past the merge base: the first cut moves the overlay and keeps a foreign
#     line that is outside every unit's path set -------------------------------------------
repo="$(stack_fixture_repo)"
git -C "$repo" branch review-base-branch basepoint
git -C "$repo" checkout -q review-base-branch
echo foreign > "$repo/foreign.txt"
git -C "$repo" add foreign.txt >/dev/null 2>&1
git -C "$repo" commit -q -m "foreign work, not part of any unit"
git -C "$repo" checkout -q "$BRANCH"
printf '%s' '{"review_base": "review-base-branch"}' > "$repo/.claude-extensions.json"
stack_write_batch "$repo" "986"
stack_add_task_entry "$repo" 986 "task-986" "" "2020-01-01T00:00:00Z"
stack_commit "$repo" 986 "f986.txt" "solo work"
stack_add_proof "$repo" 986 "$LAST_SHA" "f986.txt"
before_head="$(git -C "$repo" rev-parse HEAD)"
before_status="$(git -C "$repo" status --porcelain)"
run_rsp "$repo" cut --tasks 986 --stack-id stackMoved
after_head="$(git -C "$repo" rev-parse HEAD)"
after_status="$(git -C "$repo" status --porcelain)"
moved_branch="$(unit_field 01 branch)"
if [ "$LAST_CODE" -eq 0 ] \
   && [ "$(git -C "$repo" rev-parse "${moved_branch}^1")" = "$(git -C "$repo" rev-parse review-base-branch)" ] \
   && git -C "$repo" ls-tree -r "$moved_branch" --name-only | grep -qx "foreign.txt" \
   && [ "$before_head" = "$after_head" ] && [ "$before_status" = "$after_status" ]; then
  common_test_pass "cut: a review base past the merge base moves the overlay and keeps a foreign line"
else
  common_test_fail "cut: moved-base foreign line" "exit=${LAST_CODE} head_eq=$([ "$before_head" = "$after_head" ] && echo y || echo n)"
fi

# --- a branch's remote-tracking ref holding a commit the manifest does not record refuses --
foreign_sha="$(git -C "$repo" commit-tree "$(git -C "$repo" rev-parse "${moved_branch}^{tree}")" -p "$(git -C "$repo" rev-parse "$moved_branch")" <<< "an independent push, not recorded by the manifest")"
mkdir -p "$repo/.git/refs/remotes/${REMOTE_NAME}/$(dirname "$moved_branch")" 2>/dev/null
git -C "$repo" update-ref "refs/remotes/${REMOTE_NAME}/${moved_branch}" "$foreign_sha"
echo c987 > "$repo/f987.txt"
git -C "$repo" add f987.txt >/dev/null 2>&1
git -C "$repo" commit -q -m "task 987: more work"
SHA987="$(git -C "$repo" rev-parse HEAD)"
stack_write_batch "$repo" "986,987"
stack_add_proof "$repo" 986 "$LAST_SHA" "f986.txt"
stack_add_task_entry "$repo" 987 "task-987" "" "2020-01-02T00:00:00Z"
stack_add_proof "$repo" 987 "$SHA987" "f987.txt"
before_head="$(git -C "$repo" rev-parse HEAD)"
before_status="$(git -C "$repo" status --porcelain)"
run_rsp "$repo" cut --tasks 986,987 --stack-id stackMoved
after_head="$(git -C "$repo" rev-parse HEAD)"
after_status="$(git -C "$repo" status --porcelain)"
if [ "$before_head" = "$after_head" ] && [ "$before_status" = "$after_status" ]; then
  assert_refusal "cut: a remote-tracking ref holding a commit the manifest does not record refuses with unknown_remote_commit, exit 49" 49 unknown_remote_commit
else
  common_test_fail "cut: unknown-remote-commit refusal left HEAD/status changed" "head_eq=$([ "$before_head" = "$after_head" ] && echo y || echo n) status_eq=$([ "$before_status" = "$after_status" ] && echo y || echo n)"
fi
rm -rf "$repo"
# task-ref-ok:end

# =====================================================================
# Phase 4 (restack): detect a merged bottom-of-stack entry (PD7) and move descendants onto the
# review base's new remote-tracking tip by compare-and-swap; refuse by name on anything
# unresolvable.
# =====================================================================

# restack_fixture_repo -- stack_fixture_repo, but review_base is declared as a dedicated branch
# "review-main" (pointed at basepoint) rather than the "basepoint" tag, since restack needs a
# branch-shaped review base to probe refs/remotes/<remote>/<review_base>. No remote-tracking ref
# for review-main exists until a case calls restack_set_remote_tracking.
restack_fixture_repo() {
  local d
  d="$(stack_fixture_repo)"
  git -C "$d" branch review-main basepoint
  printf '%s' '{"review_base": "review-main"}' > "$d/.claude-extensions.json"
  printf '%s' "$d"
}

# restack_set_remote_tracking <repo> [sha] -- points refs/remotes/<remote>/review-main at <sha>
# (default: review-main's current tip) via `git update-ref`, simulating a prior fetch -- never a
# real fetch, push, or git merge.
restack_set_remote_tracking() {
  local repo="$1" sha="${2:-}"
  [ -n "$sha" ] || sha="$(git -C "$repo" rev-parse review-main)"
  git -C "$repo" update-ref "refs/remotes/${REMOTE_NAME}/review-main" "$sha"
}

# restack_entry_field <nn> <field> -- stdout: the value of <field> on the "ENTRY <nn>: ..." line
# of $LAST_OUT, or nothing.
restack_entry_field() {
  local nn="$1" field="$2"
  printf '%s\n' "$LAST_OUT" | grep -E "^ENTRY ${nn}: " | grep -oE "${field}=[^ ]*" | head -n 1 | cut -d= -f2-
}

# --- restack with no --stack-id refuses with stack_id_required, exit 41 (D6) ---------------
repo="$(restack_fixture_repo)"
restack_set_remote_tracking "$repo"
run_rsp "$repo" restack
assert_refusal "restack: no --stack-id refuses with stack_id_required, exit 41" 41 stack_id_required
rm -rf "$repo"

# --- restack against a stack with no manifest refuses with manifest_missing, exit 50 -------
repo="$(restack_fixture_repo)"
restack_set_remote_tracking "$repo"
run_rsp "$repo" restack --stack-id no-such-stack
assert_refusal "restack: no manifest on disk refuses with manifest_missing, exit 50" 50 manifest_missing
rm -rf "$repo"

# task-ref-ok:begin category 6-adjacent: synthetic 990 fixture task number and "task N: ..."
# commit subject, the same convention the cut suite above already uses.
repo="$(restack_fixture_repo)"
stack_write_batch "$repo" "990"
stack_add_task_entry "$repo" 990 "task-990" "" "2020-01-01T00:00:00Z"
stack_commit "$repo" 990 "f990.txt" "solo work"
stack_add_proof "$repo" 990 "$LAST_SHA" "f990.txt"
run_rsp "$repo" cut --tasks 990 --stack-id stackRestackA
before_head="$(git -C "$repo" rev-parse HEAD)"
before_status="$(git -C "$repo" status --porcelain)"
before_refs="$(git -C "$repo" for-each-ref | LC_ALL=C sort)"
before_manifest="$(cat "$repo/specs/.orchestration/reviews/stackRestackA/manifest.json")"

# --- an absent review-base remote-tracking ref refuses with review_base_remote_ref_absent,
#     exit 53, naming the fetch command the operator runs; the same refusal fires with
#     --merged NN supplied (D3: never bypasses the ref requirement) ------------------------
run_rsp "$repo" restack --stack-id stackRestackA
assert_refusal "restack: an absent review-base remote-tracking ref refuses with review_base_remote_ref_absent, exit 53" 53 review_base_remote_ref_absent
if printf '%s' "$LAST_OUT" | grep -q "git fetch ${REMOTE_NAME} review-main"; then
  common_test_pass "restack: the exit-53 refusal names the fetch command the operator runs"
else
  common_test_fail "restack: exit-53 fetch command" "out=${LAST_OUT}"
fi
run_rsp "$repo" restack --stack-id stackRestackA --merged 1
assert_refusal "restack: --merged NN does not bypass the absent-remote-ref refusal, still exit 53" 53 review_base_remote_ref_absent
after_head="$(git -C "$repo" rev-parse HEAD)"
after_status="$(git -C "$repo" status --porcelain)"
after_refs="$(git -C "$repo" for-each-ref | LC_ALL=C sort)"
after_manifest="$(cat "$repo/specs/.orchestration/reviews/stackRestackA/manifest.json")"
if [ "$before_head" = "$after_head" ] && [ "$before_status" = "$after_status" ] \
   && [ "$before_refs" = "$after_refs" ] && [ "$before_manifest" = "$after_manifest" ]; then
  common_test_pass "restack: both exit-53 refusals leave HEAD, status, every ref, and the manifest byte-identical"
else
  common_test_fail "restack: exit-53 writes-nothing" "refs_eq=$([ "$before_refs" = "$after_refs" ] && echo y || echo n) manifest_eq=$([ "$before_manifest" = "$after_manifest" ] && echo y || echo n)"
fi

# --- a review base whose local ref and remote-tracking ref disagree unexplainedly refuses
#     with review_base_ref_divergence, exit 54, naming the review base's own ref -------------
divergent_sha="$(git -C "$repo" commit-tree "$(git -C "$repo" rev-parse "review-main^{tree}")" -p "$(git -C "$repo" rev-parse review-main)" <<< "a local-only commit on the review base, never pushed or fetched")"
git -C "$repo" update-ref refs/heads/review-main "$divergent_sha" "$(git -C "$repo" rev-parse review-main)"
restack_set_remote_tracking "$repo" "$(git -C "$repo" rev-parse basepoint)"
before_head="$(git -C "$repo" rev-parse HEAD)"
before_status="$(git -C "$repo" status --porcelain)"
run_rsp "$repo" restack --stack-id stackRestackA
after_head="$(git -C "$repo" rev-parse HEAD)"
after_status="$(git -C "$repo" status --porcelain)"
if [ "$LAST_CODE" -eq 54 ] && printf '%s' "$LAST_OUT" | grep -q "REFUSED: review-stack-prepare.sh: review_base_ref_divergence:" \
   && printf '%s' "$LAST_OUT" | grep -q "the review base's own ref disagreeing, not a stack branch's"; then
  common_test_pass "restack: an unexplained review-base local/remote-tracking divergence refuses with review_base_ref_divergence, exit 54, naming the review base's own ref"
else
  common_test_fail "restack: exit-54 divergence" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
if [ "$before_head" = "$after_head" ] && [ "$before_status" = "$after_status" ]; then
  common_test_pass "restack: the exit-54 refusal leaves HEAD and status unchanged"
else
  common_test_fail "restack: exit-54 writes-nothing" "head_eq=$([ "$before_head" = "$after_head" ] && echo y || echo n) status_eq=$([ "$before_status" = "$after_status" ] && echo y || echo n)"
fi
rm -rf "$repo"
# task-ref-ok:end

# =====================================================================
# Phase 4 (restack), continued: bottom-up detection (D1), the --merged override (D3), the
# off-tree descendant recompute (D4), the nothing-merged/stale-stack reports, and the printed
# operator commands.
# =====================================================================

# task-ref-ok:begin ad hoc fixture task numbers 994-996, same convention as 990 above
# restack_build_chain <repo> <stack_id> <t1> <t2> <t3> -- a three-task dependency chain
# (t1 <- t2 <- t3, disjoint paths), cut bottomed on review-main. Sets RB1/RB2/RB3 to the three
# resulting branch names.
restack_build_chain() {
  local repo="$1" sid="$2" t1="$3" t2="$4" t3="$5"
  stack_write_batch "$repo" "${t1},${t2},${t3}"
  stack_add_task_entry "$repo" "$t1" "task-${t1}" "" "2020-01-01T00:00:00Z"
  stack_commit "$repo" "$t1" "f${t1}.txt" "base work"
  stack_add_proof "$repo" "$t1" "$LAST_SHA" "f${t1}.txt"
  stack_add_task_entry "$repo" "$t2" "task-${t2}" "$t1" "2020-01-02T00:00:00Z"
  stack_commit "$repo" "$t2" "f${t2}.txt" "mid work"
  stack_add_proof "$repo" "$t2" "$LAST_SHA" "f${t2}.txt"
  stack_add_task_entry "$repo" "$t3" "task-${t3}" "$t2" "2020-01-03T00:00:00Z"
  stack_commit "$repo" "$t3" "f${t3}.txt" "top work"
  stack_add_proof "$repo" "$t3" "$LAST_SHA" "f${t3}.txt"
  run_rsp "$repo" cut --tasks "${t1},${t2},${t3}" --stack-id "$sid"
  RB1="$(unit_field 01 branch)"
  RB2="$(unit_field 02 branch)"
  RB3="$(unit_field 03 branch)"
}

# --- a bottom entry squash-merged into the review base's remote-tracking tip is detected,
#     promotes the next entry's base to the review base, and the printed output carries one
#     /please push ... --force-with-lease per restacked branch plus exactly one
#     /merge --stack ... --retarget (built entirely by commit-tree/update-ref -- no push, fetch,
#     or git merge) --------------------------------------------------------------------------
repo="$(restack_fixture_repo)"
restack_build_chain "$repo" stackRB1 994 995 996
restack_set_remote_tracking "$repo"
squashed_sha="$(git -C "$repo" commit-tree "$(git -C "$repo" rev-parse "${RB1}^{tree}")" -p "$(git -C "$repo" rev-parse review-main)" <<< "a squash-merged PR, built by plumbing only, never a push, fetch, or git merge")"
git -C "$repo" update-ref "refs/remotes/${REMOTE_NAME}/review-main" "$squashed_sha"
before_refs="$(git -C "$repo" for-each-ref refs/heads | LC_ALL=C sort)"
run_rsp "$repo" restack --stack-id stackRB1 --dry-run
after_refs="$(git -C "$repo" for-each-ref refs/heads | LC_ALL=C sort)"
if [ "$LAST_CODE" -eq 0 ] \
   && [ "$(restack_entry_field 1 new_state)" = "merged" ] \
   && [ "$(restack_entry_field 2 new_base)" = "review-main" ] \
   && [ "$before_refs" = "$after_refs" ]; then
  common_test_pass "restack: a squash-merged bottom entry is detected, promotes the next entry's base, and a dry-run writes no ref"
else
  common_test_fail "restack: squash-merge detection" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
push_count="$(printf '%s\n' "$LAST_OUT" | grep -cE '^/please push ')"
merge_count="$(printf '%s\n' "$LAST_OUT" | grep -cE '^/merge --stack ')"
if [ "$push_count" -eq 2 ] && [ "$merge_count" -eq 1 ] \
   && printf '%s\n' "$LAST_OUT" | grep -qF "/please push ${REMOTE_NAME} ${RB2} --force-with-lease" \
   && printf '%s\n' "$LAST_OUT" | grep -qF "/please push ${REMOTE_NAME} ${RB3} --force-with-lease" \
   && ! printf '%s\n' "$LAST_OUT" | grep -qF "${RB1} --force-with-lease" \
   && printf '%s\n' "$LAST_OUT" | grep -qF "/merge --stack stackRB1 --retarget"; then
  common_test_pass "restack: printed output has one /please push ... --force-with-lease per restacked branch (never the merged one) and exactly one /merge --stack ... --retarget"
else
  common_test_fail "restack: printed push/merge lines" "push_count=${push_count} merge_count=${merge_count} out=${LAST_OUT}"
fi
if printf '%s' "$LAST_OUT" | grep -q "git remote set-head ${REMOTE_NAME} -a"; then
  common_test_pass "restack: the git remote set-head line appears when refs/remotes/<remote>/HEAD is absent"
else
  common_test_fail "restack: missing set-head line" "out=${LAST_OUT}"
fi
git -C "$repo" symbolic-ref "refs/remotes/${REMOTE_NAME}/HEAD" "refs/remotes/${REMOTE_NAME}/review-main"
run_rsp "$repo" restack --stack-id stackRB1 --dry-run
if ! printf '%s' "$LAST_OUT" | grep -q "git remote set-head"; then
  common_test_pass "restack: the git remote set-head line does not appear once refs/remotes/<remote>/HEAD is present"
else
  common_test_fail "restack: unexpected set-head line" "out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- a merge-commit parent whose history contains the bottom entry is detected by ancestry --
repo="$(restack_fixture_repo)"
restack_build_chain "$repo" stackRB2 994 995 996
restack_set_remote_tracking "$repo"
old_tip="$(git -C "$repo" rev-parse review-main)"
merge_commit="$(git -C "$repo" commit-tree "$(git -C "$repo" rev-parse "${old_tip}^{tree}")" -p "$old_tip" -p "$(git -C "$repo" rev-parse "$RB1")" <<< "a merge commit whose history contains the bottom entry, built by plumbing only")"
git -C "$repo" update-ref "refs/remotes/${REMOTE_NAME}/review-main" "$merge_commit"
run_rsp "$repo" restack --stack-id stackRB2 --dry-run
if [ "$LAST_CODE" -eq 0 ] && [ "$(restack_entry_field 1 new_state)" = "merged" ]; then
  common_test_pass "restack: a merge-commit parent whose history contains the bottom entry is detected by ancestry"
else
  common_test_fail "restack: ancestry detection" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- a conflicting descendant refuses with ref_conflict, exit 48, names the path, and moves
#     nothing (D4: the off-tree recompute pass runs, and refuses, before any ref is touched) --
repo="$(restack_fixture_repo)"
restack_build_chain "$repo" stackRB3 994 995 996
restack_set_remote_tracking "$repo"
old_tip="$(git -C "$repo" rev-parse review-main)"
bottom_tree="$(git -C "$repo" rev-parse "${RB1}^{tree}")"
tmp_index="$(mktemp)"
rm -f "$tmp_index"
GIT_INDEX_FILE="$tmp_index" git -C "$repo" read-tree "$bottom_tree"
conflict_blob="$(echo "a conflicting edit to the same path unit 2 touches" | git -C "$repo" hash-object -w --stdin)"
GIT_INDEX_FILE="$tmp_index" git -C "$repo" update-index --add --cacheinfo "100644,${conflict_blob},f995.txt"
conflict_tree="$(GIT_INDEX_FILE="$tmp_index" git -C "$repo" write-tree)"
rm -f "$tmp_index"
conflict_remote="$(git -C "$repo" commit-tree "$conflict_tree" -p "$old_tip" <<< "squash merge of unit 1 plus a conflicting edit to f995.txt, built by plumbing only")"
git -C "$repo" update-ref "refs/remotes/${REMOTE_NAME}/review-main" "$conflict_remote"
before_refs="$(git -C "$repo" for-each-ref | LC_ALL=C sort)"
before_manifest="$(cat "$repo/specs/.orchestration/reviews/stackRB3/manifest.json")"
run_rsp "$repo" restack --stack-id stackRB3 --dry-run
after_refs="$(git -C "$repo" for-each-ref | LC_ALL=C sort)"
after_manifest="$(cat "$repo/specs/.orchestration/reviews/stackRB3/manifest.json")"
if [ "$LAST_CODE" -eq 48 ] && printf '%s' "$LAST_OUT" | grep -q "REFUSED: review-stack-prepare.sh: ref_conflict:" \
   && printf '%s' "$LAST_OUT" | grep -q "f995.txt" \
   && [ "$before_refs" = "$after_refs" ] && [ "$before_manifest" = "$after_manifest" ]; then
  common_test_pass "restack: a conflicting descendant refuses with ref_conflict, exit 48, names the path, and moves nothing"
else
  common_test_fail "restack: conflicting descendant" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- no merged parent is a no-op that reports as such and changes nothing, even for a real
#     (non-dry-run) invocation ---------------------------------------------------------------
repo="$(restack_fixture_repo)"
restack_build_chain "$repo" stackRB4 994 995 996
restack_set_remote_tracking "$repo"
before_refs="$(git -C "$repo" for-each-ref | LC_ALL=C sort)"
before_manifest="$(cat "$repo/specs/.orchestration/reviews/stackRB4/manifest.json")"
run_rsp "$repo" restack --stack-id stackRB4
after_refs="$(git -C "$repo" for-each-ref | LC_ALL=C sort)"
after_manifest="$(cat "$repo/specs/.orchestration/reviews/stackRB4/manifest.json")"
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -qF "nothing merged for stack 'stackRB4'; no change." \
   && [ "$before_refs" = "$after_refs" ] && [ "$before_manifest" = "$after_manifest" ]; then
  common_test_pass "restack: no merged parent is a no-op that reports as such and changes nothing, even for a real (non-dry-run) invocation"
else
  common_test_fail "restack: no-op real run" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- a review base whose remote-tracking ref has moved past the manifest's recorded base,
#     without any entry having merged, is reported as a stale stack ------------------------
repo="$(restack_fixture_repo)"
restack_build_chain "$repo" stackRB5 994 995 996
old_tip="$(git -C "$repo" rev-parse review-main)"
tmp_index="$(mktemp)"
rm -f "$tmp_index"
GIT_INDEX_FILE="$tmp_index" git -C "$repo" read-tree "$old_tip"
unrelated_blob="$(echo "an unrelated merge into the review base" | git -C "$repo" hash-object -w --stdin)"
GIT_INDEX_FILE="$tmp_index" git -C "$repo" update-index --add --cacheinfo "100644,${unrelated_blob},unrelated.txt"
advanced_tree="$(GIT_INDEX_FILE="$tmp_index" git -C "$repo" write-tree)"
rm -f "$tmp_index"
advanced_commit="$(git -C "$repo" commit-tree "$advanced_tree" -p "$old_tip" <<< "an unrelated merge into the review base, nothing to do with this stack")"
git -C "$repo" update-ref "refs/remotes/${REMOTE_NAME}/review-main" "$advanced_commit"
run_rsp "$repo" restack --stack-id stackRB5 --dry-run
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -q "is stale -- the review base's remote-tracking ref has moved past"; then
  common_test_pass "restack: a moved base with no merged entry is reported as a stale stack"
else
  common_test_fail "restack: stale stack" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- --merged NN naming a non-existent ordinal refuses with record_request_entry_not_found,
#     exit 52 ---------------------------------------------------------------------------------
repo="$(restack_fixture_repo)"
restack_build_chain "$repo" stackRB6 994 995 996
restack_set_remote_tracking "$repo"
run_rsp "$repo" restack --stack-id stackRB6 --merged 99 --dry-run
assert_refusal "restack: --merged NN naming a non-existent ordinal refuses with record_request_entry_not_found, exit 52" 52 record_request_entry_not_found
rm -rf "$repo"
# task-ref-ok:end

# =====================================================================
# Phase 4 (restack), concluded: rsp_restack_execute moves refs by compare-and-swap, rewrites the
# manifest, and show reports the merged state -- the real (non-dry-run) counterpart to the
# detection/recompute cases above.
# =====================================================================

# task-ref-ok:begin ad hoc fixture task numbers 997-999, same convention as 990/994-996 above
# --- a clean bottom-up restack moves every descendant's ref, the manifest records the merged
#     entry as "merged" and the new bottom's base as the review base, each descendant's diff
#     against its new base lists only its own paths, and show prints "merged" for that entry --
repo="$(restack_fixture_repo)"
restack_build_chain "$repo" stackP4A 997 998 999
restack_set_remote_tracking "$repo"
squashed_sha="$(git -C "$repo" commit-tree "$(git -C "$repo" rev-parse "${RB1}^{tree}")" -p "$(git -C "$repo" rev-parse review-main)" <<< "a squash-merged PR, built by plumbing only, never a push, fetch, or git merge")"
git -C "$repo" update-ref "refs/remotes/${REMOTE_NAME}/review-main" "$squashed_sha"
before_head="$(git -C "$repo" rev-parse HEAD)"
before_status="$(git -C "$repo" status --porcelain)"
run_rsp "$repo" restack --stack-id stackP4A
after_head="$(git -C "$repo" rev-parse HEAD)"
after_status="$(git -C "$repo" status --porcelain)"
if [ "$LAST_CODE" -eq 0 ] \
   && [ "$(manifest_entry_field "$repo" stackP4A 1 state)" = "merged" ] \
   && [ "$(manifest_entry_field "$repo" stackP4A 2 base)" = "review-main" ] \
   && [ "$(git -C "$repo" rev-parse "${RB2}^1")" = "$squashed_sha" ] \
   && [ "$(git -C "$repo" diff --name-only "$squashed_sha".."$RB2")" = "f998.txt" ] \
   && [ "$(git -C "$repo" diff --name-only "$RB2".."$RB3")" = "f999.txt" ] \
   && [ "$before_head" = "$after_head" ] && [ "$before_status" = "$after_status" ]; then
  common_test_pass "restack: a clean bottom-up restack moves every descendant's ref, records the merged entry's state and the new bottom's base, and each descendant's diff lists only its own paths"
else
  common_test_fail "restack: clean real restack" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
run_rsp "$repo" show --stack-id stackP4A
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -qF "state=merged" \
   && printf '%s' "$LAST_OUT" | grep -qF "state=prepared"; then
  common_test_pass "restack: show's human-readable output prints merged for the merged entry and prepared for the rest"
else
  common_test_fail "restack: show state column" "out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- a foreign commit already on the review base (unrelated to any unit) survives the
#     restack -----------------------------------------------------------------------------
repo="$(restack_fixture_repo)"
restack_build_chain "$repo" stackP4B 997 998 999
restack_set_remote_tracking "$repo"
tmp_index="$(mktemp)"
rm -f "$tmp_index"
GIT_INDEX_FILE="$tmp_index" git -C "$repo" read-tree "$(git -C "$repo" rev-parse "${RB1}^{tree}")"
foreign_blob="$(echo "foreign content, unrelated to any unit" | git -C "$repo" hash-object -w --stdin)"
GIT_INDEX_FILE="$tmp_index" git -C "$repo" update-index --add --cacheinfo "100644,${foreign_blob},foreign.txt"
foreign_tree="$(GIT_INDEX_FILE="$tmp_index" git -C "$repo" write-tree)"
rm -f "$tmp_index"
squashed_with_foreign="$(git -C "$repo" commit-tree "$foreign_tree" -p "$(git -C "$repo" rev-parse review-main)" <<< "squash merge of unit 1 plus a foreign commit, unrelated to any unit, built by plumbing only")"
git -C "$repo" update-ref "refs/remotes/${REMOTE_NAME}/review-main" "$squashed_with_foreign"
run_rsp "$repo" restack --stack-id stackP4B
if [ "$LAST_CODE" -eq 0 ] && git -C "$repo" ls-tree -r "$RB3" --name-only | grep -qx "foreign.txt"; then
  common_test_pass "restack: a foreign commit already on the review base survives the restack"
else
  common_test_fail "restack: foreign line" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- a descendant whose remote-tracking ref holds a commit the manifest does not record
#     refuses with unknown_remote_commit, exit 49, naming that branch, and moves nothing -----
repo="$(restack_fixture_repo)"
restack_build_chain "$repo" stackP4C 997 998 999
restack_set_remote_tracking "$repo"
squashed_sha="$(git -C "$repo" commit-tree "$(git -C "$repo" rev-parse "${RB1}^{tree}")" -p "$(git -C "$repo" rev-parse review-main)" <<< "squash merge of unit 1, built by plumbing only")"
git -C "$repo" update-ref "refs/remotes/${REMOTE_NAME}/review-main" "$squashed_sha"
foreign_branch_sha="$(git -C "$repo" commit-tree "$(git -C "$repo" rev-parse "${RB2}^{tree}")" -p "$(git -C "$repo" rev-parse "$RB2")" <<< "an independent push to unit 2's branch, not recorded by the manifest, built by plumbing only")"
git -C "$repo" update-ref "refs/remotes/${REMOTE_NAME}/${RB2}" "$foreign_branch_sha"
before_head="$(git -C "$repo" rev-parse HEAD)"
before_status="$(git -C "$repo" status --porcelain)"
before_refs="$(git -C "$repo" for-each-ref refs/heads | LC_ALL=C sort)"
run_rsp "$repo" restack --stack-id stackP4C
after_head="$(git -C "$repo" rev-parse HEAD)"
after_status="$(git -C "$repo" status --porcelain)"
after_refs="$(git -C "$repo" for-each-ref refs/heads | LC_ALL=C sort)"
if [ "$LAST_CODE" -eq 49 ] && printf '%s' "$LAST_OUT" | grep -qF "REFUSED: review-stack-prepare.sh: unknown_remote_commit:" \
   && printf '%s' "$LAST_OUT" | grep -qF "$RB2" \
   && [ "$before_head" = "$after_head" ] && [ "$before_status" = "$after_status" ] && [ "$before_refs" = "$after_refs" ]; then
  common_test_pass "restack: a descendant whose remote-tracking ref holds an unrecorded commit refuses with unknown_remote_commit, exit 49, naming that branch, and moves nothing"
else
  common_test_fail "restack: unknown remote commit" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- a compare-and-swap that loses a race refuses with ref_conflict, exit 48, naming the ref,
#     and moves nothing -----------------------------------------------------------------------
repo="$(restack_fixture_repo)"
restack_build_chain "$repo" stackP4D 997 998 999
restack_set_remote_tracking "$repo"
squashed_sha="$(git -C "$repo" commit-tree "$(git -C "$repo" rev-parse "${RB1}^{tree}")" -p "$(git -C "$repo" rev-parse review-main)" <<< "squash merge of unit 1, built by plumbing only")"
git -C "$repo" update-ref "refs/remotes/${REMOTE_NAME}/review-main" "$squashed_sha"
# Simulate a lost race: move unit 2's local ref directly (plumbing only, no push/fetch/merge) to
# a different commit than the manifest recorded, between this stack's plan pass and its execute
# pass -- exactly what the compare-and-swap exists to catch.
raced_sha="$(git -C "$repo" commit-tree "$(git -C "$repo" rev-parse "${RB2}^{tree}")" -p "$(git -C "$repo" rev-parse "${RB2}^1")" <<< "a concurrent re-cut that moved this ref first, built by plumbing only")"
git -C "$repo" update-ref "refs/heads/${RB2}" "$raced_sha" "$(git -C "$repo" rev-parse "$RB2")"
before_head="$(git -C "$repo" rev-parse HEAD)"
before_status="$(git -C "$repo" status --porcelain)"
before_refs="$(git -C "$repo" for-each-ref refs/heads | LC_ALL=C sort)"
run_rsp "$repo" restack --stack-id stackP4D
after_head="$(git -C "$repo" rev-parse HEAD)"
after_status="$(git -C "$repo" status --porcelain)"
after_refs="$(git -C "$repo" for-each-ref refs/heads | LC_ALL=C sort)"
if [ "$LAST_CODE" -eq 48 ] && printf '%s' "$LAST_OUT" | grep -qF "REFUSED: review-stack-prepare.sh: ref_conflict:" \
   && printf '%s' "$LAST_OUT" | grep -qF "$RB2" \
   && [ "$before_head" = "$after_head" ] && [ "$before_status" = "$after_status" ] && [ "$before_refs" = "$after_refs" ]; then
  common_test_pass "restack: a compare-and-swap that loses a race refuses with ref_conflict, exit 48, naming the ref, and moves nothing"
else
  common_test_fail "restack: lost race" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"

# --- Phase 2's conflict case re-asserted with the execute path present (no --dry-run);
#     every ref and the manifest are still byte-identical --------------------------------------
repo="$(restack_fixture_repo)"
restack_build_chain "$repo" stackP4E 997 998 999
restack_set_remote_tracking "$repo"
old_tip="$(git -C "$repo" rev-parse review-main)"
tmp_index="$(mktemp)"
rm -f "$tmp_index"
GIT_INDEX_FILE="$tmp_index" git -C "$repo" read-tree "$(git -C "$repo" rev-parse "${RB1}^{tree}")"
conflict_blob="$(echo "a conflicting edit to the same path unit 2 touches" | git -C "$repo" hash-object -w --stdin)"
GIT_INDEX_FILE="$tmp_index" git -C "$repo" update-index --add --cacheinfo "100644,${conflict_blob},f998.txt"
conflict_tree="$(GIT_INDEX_FILE="$tmp_index" git -C "$repo" write-tree)"
rm -f "$tmp_index"
conflict_remote="$(git -C "$repo" commit-tree "$conflict_tree" -p "$old_tip" <<< "squash merge of unit 1 plus a conflicting edit to f998.txt, built by plumbing only")"
git -C "$repo" update-ref "refs/remotes/${REMOTE_NAME}/review-main" "$conflict_remote"
before_head="$(git -C "$repo" rev-parse HEAD)"
before_status="$(git -C "$repo" status --porcelain)"
before_refs="$(git -C "$repo" for-each-ref | LC_ALL=C sort)"
before_manifest="$(cat "$repo/specs/.orchestration/reviews/stackP4E/manifest.json")"
run_rsp "$repo" restack --stack-id stackP4E
after_head="$(git -C "$repo" rev-parse HEAD)"
after_status="$(git -C "$repo" status --porcelain)"
after_refs="$(git -C "$repo" for-each-ref | LC_ALL=C sort)"
after_manifest="$(cat "$repo/specs/.orchestration/reviews/stackP4E/manifest.json")"
if [ "$LAST_CODE" -eq 48 ] && printf '%s' "$LAST_OUT" | grep -q "REFUSED: review-stack-prepare.sh: ref_conflict:" \
   && printf '%s' "$LAST_OUT" | grep -q "f998.txt" \
   && [ "$before_head" = "$after_head" ] && [ "$before_status" = "$after_status" ] \
   && [ "$before_refs" = "$after_refs" ] && [ "$before_manifest" = "$after_manifest" ]; then
  common_test_pass "restack: Phase 2's conflict case re-asserted with the execute path present (no --dry-run); every ref and the manifest are still byte-identical"
else
  common_test_fail "restack: re-asserted conflict with execute present" "exit=${LAST_CODE} out=${LAST_OUT}"
fi
rm -rf "$repo"
# task-ref-ok:end

# =====================================================================
# Writes-nothing check: a refusing invocation leaves the fixture's git state byte-identical.
# =====================================================================
repo="$(make_fixture_repo)"
before_head="$(git -C "$repo" rev-parse HEAD)"
before_status="$(git -C "$repo" status --porcelain)"
run_rsp "$repo" cut --dry-run
after_head="$(git -C "$repo" rev-parse HEAD)"
after_status="$(git -C "$repo" status --porcelain)"
if [ "$LAST_CODE" -ne 0 ] && [ "$before_head" = "$after_head" ] && [ "$before_status" = "$after_status" ]; then
  common_test_pass "a refused cut --dry-run writes no ref, no file, and leaves HEAD and status unchanged"
else
  common_test_fail "writes-nothing check" "exit=${LAST_CODE} before_head=${before_head} after_head=${after_head} before_status=[${before_status}] after_status=[${after_status}]"
fi
rm -rf "$repo"

# =====================================================================
# Static checks over the script's non-comment lines.
# =====================================================================
forbidden_hits="$(grep -nE '\bgit[[:space:]]+(push|checkout|switch|rebase)\b|\bgit[[:space:]]+merge([[:space:]]|$)|git-replay|\bgh[[:space:]]+(pr|api)\b|\bglab[[:space:]]+mr\b' "$RSP" | grep -v '^[0-9]*:#' | grep -v "NEVER CALLS" || true)"
if [ -z "$forbidden_hits" ]; then
  common_test_pass "static check: review-stack-prepare.sh contains no push/checkout/switch/merge/rebase/replay/gh/glab invocation"
else
  common_test_fail "static check: found forbidden invocation(s): $forbidden_hits"
fi

literal_hits="$(grep -nE '\b(origin|main|master|upstream)\b' "$RSP" | grep -v '^[0-9]*:#' || true)"
if [ -z "$literal_hits" ]; then
  common_test_pass "static check: review-stack-prepare.sh contains no literal origin/main/master/upstream word outside comments"
else
  common_test_fail "static check: found literal name(s): $literal_hits"
fi

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
