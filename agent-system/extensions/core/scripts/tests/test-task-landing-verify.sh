#!/usr/bin/env bash
# test-task-landing-verify.sh - Regression suite for scripts/task-landing-verify.sh: the landing
# predicate (V1 branch, V2 attribution, V3 path set, V4 blob equality, V5 nothing left behind),
# the landing proof, idempotence, and the inconclusive cases.
#
# Follows context/standards/shell-script-testing.md and this directory's house convention:
# common_test_pass/_fail from lib/common.sh, PASSED/FAILED counters, a mktemp -d workdir removed
# on EXIT. Every fixture is a scratch git repository under the workdir carrying its own copy of
# the script and the libraries it sources; none is built with a command that discards
# working-tree changes.
#
# MUTATION SEAMS. Each negative fixture is run twice: against the shipped script, which must
# refuse with the check's own exit code, and against a WEAKENED copy in which that one check is
# disabled, which must fail to refuse. The weakened copy is made here, by `sed` on the fixture's
# copy; the shipped script carries no seam. A seam whose `sed` no longer changes the script
# fails loudly, so a refactor cannot leave a negative fixture silently proving nothing.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED (or a required file or tool is
# missing, reported loudly rather than silently skipped).

# The `test && pass || fail` idiom is this directory's convention (the pass helper never fails),
# and the sed/jq programs below are single-quoted on purpose.
# shellcheck disable=SC2015,SC2016

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"
SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."
SUBJECT="$SRC_SCRIPTS_DIR/task-landing-verify.sh"

PASSED=0
FAILED=0

for required in "$SUBJECT" "$SRC_SCRIPTS_DIR/task-lock.sh" "$SRC_SCRIPTS_DIR/deploy-root-guard.sh" \
                "$SRC_SCRIPTS_DIR/lib/batch-admission-lib.sh"; do
  if [ ! -f "$required" ]; then
    echo "ERROR: test-task-landing-verify.sh cannot run -- missing required file: $required" >&2
    exit 1
  fi
done
for tool in git jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: test-task-landing-verify.sh cannot run -- missing required tool: $tool" >&2
    exit 1
  fi
done

common_test_workdir_init

BRANCH="trunk"
SESSION="sess_fixture_landing"
OUT="$WORKDIR/out.txt"
RC=0

# Fixed identity: every fixture commit is made "now", after the fixture tasks' created time.
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
CREATED="2020-01-01T00:00:00Z"

# task-ref-ok:begin category 6-adjacent: every numbered commit subject from here to the matching
# end marker is synthetic fixture data. The script under test attributes commits by the literal
# subject convention, so the fixtures must carry concrete digits; none names a real task.

# mkrepo [with_record: true|false] -- a scratch repository on $BRANCH with fixture tasks 1, 2
# and 3 in specs/state.json, a plan for the first, and (by default) one batch record listing the
# first two. Echoes the repository root.
mkrepo() {
  local with_record="${1:-true}" d
  d="$(mktemp -d -p "$WORKDIR")"
  git -C "$d" init -q -b "$BRANCH"
  mkdir -p "$d/.claude/scripts/lib" "$d/src" "$d/specs/001_alpha/plans"
  cp -r "$SRC_SCRIPTS_DIR/lib/." "$d/.claude/scripts/lib/"
  cp "$SRC_SCRIPTS_DIR/task-lock.sh" "$SRC_SCRIPTS_DIR/deploy-root-guard.sh" "$SUBJECT" \
    "$d/.claude/scripts/"
  printf '.claude/\n' > "$d/.gitignore"
  echo base > "$d/src/a.txt"
  echo base > "$d/src/b.txt"
  echo base > "$d/src/shared.txt"
  jq -n --arg c "$CREATED" '{next_project_number: 4, active_projects: [
      {project_number: 1, project_name: "alpha", status: "implementing", created: $c},
      {project_number: 2, project_name: "beta", status: "implementing", created: $c},
      {project_number: 3, project_name: "gamma", status: "implementing", created: $c}]}' \
    > "$d/specs/state.json"
  cat > "$d/specs/001_alpha/plans/01_alpha.md" <<'PLAN'
# Implementation Plan: alpha

### Phase 1: Build the thing [COMPLETED]

### Phase 2: Polish the thing [COMPLETED WITH EXCLUSIONS]

### Phase 3: Never reached [NOT STARTED]
PLAN
  git -C "$d" add -- .gitignore src/a.txt src/b.txt src/shared.txt specs/state.json \
    specs/001_alpha/plans/01_alpha.md
  git -C "$d" commit -q -m "init"
  if [ "$with_record" = "true" ]; then
    mkdir -p "$d/specs/.orchestration/batch"
    jq -n --arg s "$SESSION" --arg b "$BRANCH" \
      '{schema: 1, session_id: $s, task_numbers: [1, 2], admitted_at: "2026-01-01T00:00:00Z",
        integration_branch: $b, integration_branch_declared: false, landing_proofs: []}' \
      > "$d/specs/.orchestration/batch/${SESSION}.json"
  fi
  echo "$d"
}

# commit <root> <subject> <path...> -- stage the named paths and commit them.
commit() {
  local d="$1" subject="$2"
  shift 2
  git -C "$d" add -- "$@"
  git -C "$d" commit -q -m "$subject"
}

# seed <root> -- two tasks interleaved on one branch, each commit also carrying a state file,
# and one commit belonging to no task.
seed() {
  local d="$1"
  echo 1a > "$d/src/a.txt"; echo s1 >> "$d/specs/state.marker"
  commit "$d" "task 1 phase 1: a" src/a.txt specs/state.marker
  echo 2b > "$d/src/b.txt"; echo s2 >> "$d/specs/state.marker"
  commit "$d" "task 2 phase 1: b" src/b.txt specs/state.marker
  echo 1a2 > "$d/src/a.txt"; echo s3 >> "$d/specs/state.marker"
  commit "$d" "task 1 phase 2: a again" src/a.txt specs/state.marker
  echo r > "$d/specs/ROADMAP.md"
  commit "$d" "roadmap: maintenance pass" specs/ROADMAP.md
}

record_of() { echo "$1/specs/.orchestration/batch/${SESSION}.json"; }

# verify <root> <task> [args...] -- run the fixture's copy; output in $OUT, status in $RC.
verify() {
  local d="$1" task="$2"
  shift 2
  bash "$d/.claude/scripts/task-landing-verify.sh" "$task" --session "$SESSION" "$@" >"$OUT" 2>&1
  RC=$?
}

# weaken <root> <seam> -- replace the fixture's copy with one in which <seam>'s check is
# disabled. Fails the suite when the seam's edit no longer changes the script.
weaken() {
  local d="$1" seam="$2" f="$1/.claude/scripts/task-landing-verify.sh" expr
  case "$seam" in
    V1) expr='s|^current_branch="\$\(git symbolic-ref .*$|current_branch="${integration_branch:-$(git symbolic-ref -q --short HEAD)}"|' ;;
    V2) expr='s|^subject_re="\^task \$\{task_number\}\(:. phase \)"$|subject_re="^task [0-9]+(:\| phase )"|' ;;
    V2-bound) expr='s|^  \[ "\$ct" -ge "\$created_epoch" \] 2>/dev/null && own\+=\("\$sha"\)$|  own+=("$sha")|' ;;
    V4) expr='s|^    refuse 12 |    : |' ;;
    V5) expr='s|^    refuse 13 |    : |' ;;
    *) echo "ERROR: unknown seam $seam" >&2; exit 1 ;;
  esac
  sed -i -E "$expr" "$f"
  if cmp -s "$f" "$SUBJECT"; then
    common_test_fail "mutation seam $seam still edits the script" "  the seam's sed matched nothing"
    return 1
  fi
  common_test_pass "mutation seam $seam still edits the script"
}
restore() { cp "$SUBJECT" "$1/.claude/scripts/task-landing-verify.sh"; }

expect_rc() {
  local label="$1" want="$2"
  if [ "$RC" = "$want" ]; then
    common_test_pass "$label"
  else
    common_test_fail "$label" "  want exit $want, got $RC: $(tr '\n' ' ' < "$OUT")"
  fi
}
expect_out() {
  local label="$1" needle="$2"
  if grep -qF -- "$needle" "$OUT"; then
    common_test_pass "$label"
  else
    common_test_fail "$label" "  output lacks '${needle}': $(tr '\n' ' ' < "$OUT")"
  fi
}
snapshot() { # <root> -- every ref, HEAD, and the batch record's bytes
  git -C "$1" for-each-ref
  git -C "$1" symbolic-ref -q HEAD || git -C "$1" rev-parse HEAD
  [ -f "$(record_of "$1")" ] && cksum < "$(record_of "$1")"
  return 0
}
proofs() { jq -r '.landing_proofs | length' "$(record_of "$1")"; }

# =====================================================================
echo ""
echo "--- positive: two interleaved tasks, one branch ---"
d="$(mkrepo)"; seed "$d"
verify "$d" 1
expect_rc "the first task passes on an interleaved branch" 0
expect_out "pass line names the verification" "LANDING-VERIFIED task 1"
if ! grep -q 'WARNING' "$OUT" && [ ! -e "$d/specs/.commit-lock" ]; then
  common_test_pass "the commit mutex is taken without a warning and released"
else
  common_test_fail "the commit mutex is taken without a warning and released" "  $(tr '\n' ' ' < "$OUT") $(ls -a "$d/specs")"
fi
COMMIT_MUTEX_HELD=1 bash "$d/.claude/scripts/task-landing-verify.sh" 1 --session "$SESSION" --check >"$OUT" 2>&1; RC=$?
expect_rc "a caller already holding the commit mutex runs as a guest" 0
verify "$d" 2
expect_rc "the second task passes on the same branch" 0
[ "$(proofs "$d")" = "2" ] \
  && common_test_pass "one proof per task is recorded" \
  || common_test_fail "one proof per task is recorded" "  got $(proofs "$d")"
[ "$(git -C "$d" symbolic-ref --short HEAD)" = "$BRANCH" ] \
  && common_test_pass "HEAD names the same branch after both landings" \
  || common_test_fail "HEAD names the same branch after both landings"
p1="$(jq -c '.landing_proofs[] | select(.task_number == 1)' "$(record_of "$d")")"
[ "$(jq -r '.paths | join(",")' <<<"$p1")" = "src/a.txt" ] \
  && common_test_pass "the path set excludes the state territory" \
  || common_test_fail "the path set excludes the state territory" "  got $(jq -c '.paths' <<<"$p1")"
[ "$(jq -r '.commits | length' <<<"$p1")" = "2" ] \
  && [ "$(jq -r '.end_commit' <<<"$p1")" = "$(git -C "$d" log --format=%H --grep='^task 1 phase 2' -1)" ] \
  && common_test_pass "the proof lists the task's commits and its end commit" \
  || common_test_fail "the proof lists the task's commits and its end commit" "  $p1"
[ "$(jq -c '.phases' <<<"$p1")" = '[{"phase":"1","name":"Build the thing"},{"phase":"2","name":"Polish the thing"}]' ] \
  && common_test_pass "the proof carries the plan's completed phases only" \
  || common_test_fail "the proof carries the plan's completed phases only" "  got $(jq -c '.phases' <<<"$p1")"
if [ "$(jq -r '[.session_id, .integration_branch, .tip_at_verification] | join(" ")' <<<"$p1")" \
     = "$SESSION $BRANCH $(git -C "$d" rev-parse HEAD)" ] \
   && [ "$(jq -r 'has("landed_at") and has("shared_paths") and has("source_store_commits")' <<<"$p1")" = "true" ]; then
  common_test_pass "the proof carries session, branch, tip and the remaining fields"
else
  common_test_fail "the proof carries session, branch, tip and the remaining fields" "  $p1"
fi

echo ""
echo "--- idempotence ---"
before="$(snapshot "$d")"
verify "$d" 1
expect_rc "a re-run after a recorded proof passes" 0
expect_out "the re-run says it is a no-op" "no-op"
[ "$(snapshot "$d")" = "$before" ] \
  && common_test_pass "the re-run appends nothing" \
  || common_test_fail "the re-run appends nothing"
echo finished >> "$d/specs/state.marker"
commit "$d" "task 1: complete implementation" specs/state.marker
verify "$d" 1
expect_rc "a re-run after a later state-only attributed commit passes" 0
[ "$(proofs "$d")" = "2" ] \
  && common_test_pass "the state-only commit does not become the end commit" \
  || common_test_fail "the state-only commit does not become the end commit" "  proofs=$(proofs "$d")"
echo 3a > "$d/src/a.txt"
commit "$d" "task 3 phase 1: a dependent task edits the same file" src/a.txt
verify "$d" 1
expect_rc "a dependent task editing the same file later does not fail the landed task" 0
verify "$d" 1 --print-body
expect_rc "--print-body exits 0" 0
expect_out "--print-body lists the phases" "- Phase 1: Build the thing"
expect_out "--print-body lists the attributed commits" "- $(git -C "$d" log --format=%H --grep='^task 1 phase 1' -1)"
expect_out "--print-body names the end commit" "End commit: $(git -C "$d" log --format=%H --grep='^task 1 phase 2' -1)"
verify "$d" 3 --print-body
[ "$RC" = "0" ] && [ ! -s "$OUT" ] \
  && common_test_pass "--print-body prints nothing for a task with no proof" \
  || common_test_fail "--print-body prints nothing for a task with no proof"

# =====================================================================
echo ""
echo "--- negative V5: work edited and never committed ---"
d="$(mkrepo)"; seed "$d"
echo 2b-more > "$d/src/b.txt"
weaken "$d" V5
verify "$d" 2 --check
expect_rc "OBSERVED-FAILING: with V5 disabled the uncommitted edit is not refused" 0
restore "$d"
before="$(snapshot "$d")"
verify "$d" 2
expect_rc "an edited, never-committed path refuses with the V5 exit code" 13
expect_out "the refusal names the path" "src/b.txt"
expect_out "the refusal names a remedy" "Remedy:"
[ "$(snapshot "$d")" = "$before" ] \
  && common_test_pass "the V5 refusal leaves every ref and the batch record byte-identical" \
  || common_test_fail "the V5 refusal leaves every ref and the batch record byte-identical"
verify "$d" 1
expect_rc "the sibling whose paths are clean still lands" 0

echo ""
echo "--- negative V5: a reported new file never committed ---"
d="$(mkrepo)"; seed "$d"
echo new > "$d/src/new.txt"
jq -n --arg abs "$d/src/a.txt" \
  '{modified_files: ["src/new.txt", $abs, "specs/state.json", "/outside/repo.txt", "../escape.txt"],
    source_store_commits: [{repository: "second-repo", commit: "abc123"}]}' > "$d/meta.json"
verify "$d" 2 --check
expect_rc "an untracked file the dispatch did not report is not this task's concern" 0
weaken "$d" V5
verify "$d" 2 --check --modified-files-from "$d/meta.json"
expect_rc "OBSERVED-FAILING: with V5 disabled the reported, uncommitted file is not refused" 0
restore "$d"
verify "$d" 2 --modified-files-from "$d/meta.json"
expect_rc "a reported file no commit carries refuses with the V5 exit code" 13
expect_out "the refusal names the reported file" "src/new.txt"
[ "$(proofs "$d")" = "0" ] \
  && common_test_pass "a refusal writes no proof" \
  || common_test_fail "a refusal writes no proof"
commit "$d" "task 2 phase 2: the new file" src/new.txt
verify "$d" 2 --modified-files-from "$d/meta.json"
expect_rc "committing the reported file under the task's subject clears the refusal" 0
[ "$(jq -c '.landing_proofs[0].source_store_commits' "$(record_of "$d")")" = '[{"repository":"second-repo","commit":"abc123"}]' ] \
  && common_test_pass "reported second-repository commits are copied into the proof" \
  || common_test_fail "reported second-repository commits are copied into the proof"
verify "$d" 2 --print-body
expect_out "--print-body lists second-repository commits" "- second-repo abc123"

# =====================================================================
echo ""
echo "--- negative V4: a foreign commit over a task's path after its end commit ---"
d="$(mkrepo)"; seed "$d"
echo clobber > "$d/src/a.txt"
commit "$d" "core: hand edit" src/a.txt
foreign="$(git -C "$d" rev-parse --short HEAD)"
weaken "$d" V4
verify "$d" 1 --check
expect_rc "OBSERVED-FAILING: with V4 disabled the overwritten path is not refused" 0
restore "$d"
before="$(snapshot "$d")"
verify "$d" 1
expect_rc "a path changed after the end commit refuses with the V4 exit code" 12
expect_out "the refusal names the path" "src/a.txt"
expect_out "the refusal names the offending commit" "$foreign core: hand edit"
[ "$(snapshot "$d")" = "$before" ] \
  && common_test_pass "the V4 refusal leaves every ref and the batch record byte-identical" \
  || common_test_fail "the V4 refusal leaves every ref and the batch record byte-identical"
verify "$d" 2
expect_rc "the sibling whose paths are untouched still lands" 0
[ "$(jq -r '[.landing_proofs[].task_number] | join(",")' "$(record_of "$d")")" = "2" ] \
  && common_test_pass "only the sibling has a proof" \
  || common_test_fail "only the sibling has a proof"

# =====================================================================
echo ""
echo "--- negative V1: commits stranded on a detached HEAD ---"
d="$(mkrepo)"
echo 1a > "$d/src/a.txt"; commit "$d" "task 1 phase 1: a" src/a.txt
git -C "$d" checkout -q --detach
echo 1a2 > "$d/src/a.txt"; commit "$d" "task 1 phase 2: stranded" src/a.txt
weaken "$d" V1
verify "$d" 1 --check
expect_rc "OBSERVED-FAILING: with V1 disabled the stranded commit is not refused" 0
restore "$d"
before="$(snapshot "$d")"
verify "$d" 1
expect_rc "a detached HEAD refuses with the V1 exit code" 10
expect_out "the refusal says HEAD is detached" "HEAD is detached"
[ "$(snapshot "$d")" = "$before" ] \
  && common_test_pass "the V1 refusal leaves every ref and the batch record byte-identical" \
  || common_test_fail "the V1 refusal leaves every ref and the batch record byte-identical"
git -C "$d" switch -q -c elsewhere
verify "$d" 1
expect_rc "a branch other than the integration branch refuses with the V1 exit code" 10
expect_out "the refusal names both branches" "HEAD is on 'elsewhere', not the integration branch '$BRANCH'"

# =====================================================================
echo ""
echo "--- negative V2: no commit attributable to the task ---"
d="$(mkrepo)"; seed "$d"
weaken "$d" V2
verify "$d" 3 --check
expect_rc "OBSERVED-FAILING: with attribution disabled another task's commits pass for the third" 0
restore "$d"
verify "$d" 3
expect_rc "a task with no attributed commit refuses with the V2 exit code" 11
expect_out "the refusal names the subject convention" "task 3:"
git -C "$d" commit -q --allow-empty -m "unrelated: mentions the convention

task 3: this body line is not a subject"
verify "$d" 3 --check
expect_rc "a matching body line is not an attributed subject" 11
git -C "$d" commit -q --allow-empty -m "task 30 phase 1: a longer task number"
verify "$d" 3 --check
expect_rc "a longer number sharing the prefix is not attributed" 11

echo ""
echo "--- V2 time bound: a reused task number ---"
d="$(mkrepo)"
echo old > "$d/src/b.txt"
git -C "$d" add -- src/b.txt
GIT_AUTHOR_DATE="2019-06-01T00:00:00Z" GIT_COMMITTER_DATE="2019-06-01T00:00:00Z" \
  git -C "$d" commit -q -m "task 1 phase 1: an earlier holder of this number"
weaken "$d" V2-bound
verify "$d" 1 --check
expect_rc "OBSERVED-FAILING: with the time bound disabled the earlier holder's commit is attributed" 0
restore "$d"
verify "$d" 1 --check
expect_rc "a commit older than the task's created time is not attributed" 11
echo 1a > "$d/src/a.txt"; commit "$d" "task 1 phase 1: a" src/a.txt
verify "$d" 1
expect_rc "the task's own commit is attributed" 0
[ "$(jq -r '.landing_proofs[0] | "\(.commits | length) \(.paths | join(","))"' "$(record_of "$d")")" = "1 src/a.txt" ] \
  && common_test_pass "the earlier holder's commit and path stay out of the proof" \
  || common_test_fail "the earlier holder's commit and path stay out of the proof" "  $(jq -c '.landing_proofs[0]' "$(record_of "$d")")"

# =====================================================================
echo ""
echo "--- shared paths, state-only tasks, no batch record, --check ---"
d="$(mkrepo)"
echo 1s > "$d/src/shared.txt"; commit "$d" "task 1 phase 1: shared" src/shared.txt
echo 2s >> "$d/src/shared.txt"; commit "$d" "task 2 phase 1: shared too" src/shared.txt
echo 1a > "$d/src/a.txt"; commit "$d" "task 1 phase 2: a" src/a.txt
verify "$d" 1
expect_rc "a task sharing a file with an interleaved sibling passes" 0
[ "$(jq -c '.landing_proofs[0].shared_paths' "$(record_of "$d")")" = '["src/shared.txt"]' ] \
  && common_test_pass "the co-written file is recorded in shared_paths" \
  || common_test_fail "the co-written file is recorded in shared_paths" "  $(jq -c '.landing_proofs[0].shared_paths' "$(record_of "$d")")"

d="$(mkrepo)"
echo note > "$d/specs/notes.md"; commit "$d" "task 1 phase 1: a record under the state territory" specs/notes.md
verify "$d" 1
expect_rc "a task whose commits touch only the state territory passes" 0
[ "$(jq -c '.landing_proofs[0].paths' "$(record_of "$d")")" = '[]' ] \
  && common_test_pass "its path set is empty" \
  || common_test_fail "its path set is empty"
echo more >> "$d/specs/notes.md"; commit "$d" "task 1: complete implementation" specs/notes.md
verify "$d" 1
[ "$RC" = "0" ] && [ "$(proofs "$d")" = "1" ] \
  && common_test_pass "its re-run after a later state-only commit is a no-op" \
  || common_test_fail "its re-run after a later state-only commit is a no-op" "  rc=$RC proofs=$(proofs "$d")"

d="$(mkrepo false)"; seed "$d"
verify "$d" 1
expect_rc "with no batch record the predicate still passes landed work" 0
expect_out "the pass says no proof was recorded" "no batch record lists this task"
[ ! -e "$d/specs/.orchestration" ] \
  && common_test_pass "no record is created" \
  || common_test_fail "no record is created"
echo 1a-more > "$d/src/a.txt"
verify "$d" 1
expect_rc "with no batch record the predicate still refuses unlanded work" 13

d="$(mkrepo)"; seed "$d"
before="$(snapshot "$d"; find "$d/specs" | LC_ALL=C sort)"
verify "$d" 1 --check
expect_rc "--check passes landed work" 0
[ "$(snapshot "$d"; find "$d/specs" | LC_ALL=C sort)" = "$before" ] \
  && common_test_pass "--check writes no proof and takes no mutex" \
  || common_test_fail "--check writes no proof and takes no mutex"

# =====================================================================
echo ""
echo "--- inconclusive cases and usage ---"
d="$(mkrepo)"; seed "$d"
verify "$d" 99
expect_rc "a task in neither state file passes through" 0
expect_out "the pass-through is named" "LANDING-INCONCLUSIVE task 99"
jq '.active_projects += [{project_number: 4, project_name: "delta", status: "implementing"}]' \
  "$d/specs/state.json" > "$d/specs/state.json.new" && mv "$d/specs/state.json.new" "$d/specs/state.json"
verify "$d" 4
expect_rc "a task with no created timestamp passes through" 0
expect_out "that pass-through names the missing bound" "no readable created timestamp"
jq -n --arg b "$BRANCH" '{schema: 1, session_id: "sess_other", task_numbers: [4],
    admitted_at: "2026-01-01T00:00:00Z", integration_branch: $b, landing_proofs: []}' \
  > "$d/specs/.orchestration/batch/sess_other.json"
echo old > "$d/src/shared.txt"
git -C "$d" add -- src/shared.txt
GIT_AUTHOR_DATE="2019-06-01T00:00:00Z" GIT_COMMITTER_DATE="2019-06-01T00:00:00Z" \
  git -C "$d" commit -q -m "task 4 phase 1: an earlier holder of this number"
verify "$d" 4 --check
expect_rc "with no created timestamp, the oldest admission bounds attribution" 11
echo 4b > "$d/src/b.txt"; commit "$d" "task 4 phase 1: b" src/b.txt
verify "$d" 4
expect_rc "a commit made after the admission is attributed" 0
[ "$(jq -r '.landing_proofs[0].paths | join(",")' "$d/specs/.orchestration/batch/sess_other.json")" = "src/b.txt" ] \
  && common_test_pass "the proof is appended to the record that lists the task, without the earlier holder's path" \
  || common_test_fail "the proof is appended to the record that lists the task, without the earlier holder's path"
mkdir -p "$d/specs/archive"
jq -n --arg c "$CREATED" '{completed_projects: [{project_number: 1, project_name: "alpha", status: "completed", created: $c}], archived_projects: []}' \
  > "$d/specs/archive/state.json"
jq '.active_projects |= map(select(.project_number == 1 | not))' "$d/specs/state.json" \
  > "$d/specs/state.json.new" && mv "$d/specs/state.json.new" "$d/specs/state.json"
verify "$d" 1 --check
expect_rc "an archived task is found through the archive state file" 0
expect_out "the archived task is verified, not passed through" "LANDING-VERIFIED task 1"

plain="$(mktemp -d -p "$WORKDIR")"
mkdir -p "$plain/.claude/scripts"
cp -r "$d/.claude/scripts/." "$plain/.claude/scripts/"
bash "$plain/.claude/scripts/task-landing-verify.sh" 1 --session "$SESSION" >"$OUT" 2>&1; RC=$?
expect_rc "a project root that is not a git work tree passes through" 0
expect_out "that pass-through names the reason" "not a git work tree"

verify "$d" notanumber
expect_rc "a non-numeric task number is a usage error" 2
bash "$d/.claude/scripts/task-landing-verify.sh" 1 >"$OUT" 2>&1; RC=$?
expect_rc "a missing --session is a usage error" 2
# task-ref-ok:end

# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
