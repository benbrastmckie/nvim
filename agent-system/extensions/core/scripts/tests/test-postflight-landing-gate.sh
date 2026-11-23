#!/usr/bin/env bash
# test-postflight-landing-gate.sh - Regression suite for the landing gate inside
# scripts/update-task-status.sh: an implement postflight writes `completed` only when
# scripts/task-landing-verify.sh passes, and exits 7 having written nothing when it refuses.
#
# The predicate itself (V1 to V5, the proof, idempotence) is covered by
# test-task-landing-verify.sh. This suite covers the WIRING: that the status script calls the
# predicate before the state write, that a refusal leaves specs/state.json and the plan file
# byte-identical, that the reconcile promotion path is refused the same way, and that the
# inconclusive cases pass through.
#
# NEGATIVE FIXTURE. The case "work left uncommitted" is run twice on identical fixtures: once
# against a WEAKENED copy of the status script in which the gate's refusal is disabled (made
# here, by `sed` on the fixture's copy; the shipped script carries no seam), which must write
# `completed`, and once against the shipped script, which must exit 7. A seam whose `sed` no
# longer changes the script fails loudly.
#
# Every fixture is a scratch directory under the workdir carrying its own copy of the scripts;
# none is built with a command that discards working-tree changes.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- a required file or tool
# is missing (reported loudly, never silently skipped).

# The `test && pass || fail` idiom is this directory's convention (the pass helper never fails),
# and the sed/jq programs below are single-quoted on purpose.
# shellcheck disable=SC2015,SC2016

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"
SRC_SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
UTS_SRC="$SRC_SCRIPTS_DIR/update-task-status.sh"

PASSED=0
FAILED=0

for required in "$UTS_SRC" "$SRC_SCRIPTS_DIR/task-landing-verify.sh" \
                "$SRC_SCRIPTS_DIR/reconcile-task-status.sh" "$SRC_SCRIPTS_DIR/state-write.sh"; do
  if [ ! -f "$required" ]; then
    echo "ERROR: test-postflight-landing-gate.sh cannot run -- missing required file: $required" >&2
    exit 2
  fi
done
for tool in git jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: test-postflight-landing-gate.sh cannot run -- missing required tool: $tool" >&2
    exit 2
  fi
done

common_test_workdir_init

BRANCH="trunk"
SESSION="sess_fixture_gate"
OUT="$WORKDIR/out.txt"
RC=0

export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid

# task-ref-ok:begin category 6-adjacent: every numbered commit subject and fixture task number
# from here to the matching end marker is synthetic fixture data. The predicate attributes
# commits by the literal subject convention, so the fixtures must carry concrete digits.

# mkfixture [git: true|false] -- a scratch project root with one implementing fixture task, its
# plan (one completed phase), a batch record listing it and, when git is true, one attributed
# commit carrying src/work.txt. Echoes the root.
mkfixture() {
  local with_git="${1:-true}" d f
  d="$(mktemp -d -p "$WORKDIR")"
  mkdir -p "$d/.claude/scripts/lib" "$d/src" "$d/specs/001_fixture_task/plans" \
    "$d/specs/.orchestration/batch"
  for f in "$SRC_SCRIPTS_DIR"/*.sh; do
    cp "$f" "$d/.claude/scripts/"
  done
  cp -r "$SRC_SCRIPTS_DIR/lib/." "$d/.claude/scripts/lib/"
  chmod +x "$d"/.claude/scripts/*.sh
  printf '.claude/\n' > "$d/.gitignore"
  cat > "$d/specs/state.json" <<'STATE'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "fixture_task",
      "status": "implementing",
      "task_type": "meta",
      "created": "2020-01-01T00:00:00Z",
      "next_artifact_number": 1
    }
  ]
}
STATE
  echo "## Tasks" > "$d/specs/TODO.md"
  cat > "$d/specs/001_fixture_task/plans/01_fixture-plan.md" <<'PLAN'
# Implementation Plan: fixture

- **Status**: [IMPLEMENTING]

### Phase 1: Only phase [COMPLETED]

- [x] did it
PLAN
  jq -n --arg s "$SESSION" --arg b "$BRANCH" \
    '{schema: 1, session_id: $s, task_numbers: [1], admitted_at: "2026-01-01T00:00:00Z",
      integration_branch: $b, integration_branch_declared: false, landing_proofs: []}' \
    > "$d/specs/.orchestration/batch/${SESSION}.json"
  echo '{"status": "implemented", "modified_files": ["src/work.txt"]}' \
    > "$d/specs/001_fixture_task/.return-meta.json"
  echo base > "$d/src/work.txt"
  if [ "$with_git" = "true" ]; then
    git -C "$d" init -q -b "$BRANCH"
    git -C "$d" add -- .gitignore specs/state.json specs/TODO.md \
      specs/001_fixture_task/plans/01_fixture-plan.md src/work.txt
    git -C "$d" commit -q -m "init"
    echo work > "$d/src/work.txt"
    git -C "$d" add -- src/work.txt
    git -C "$d" commit -q -m "task 1 phase 1: the work"
  fi
  echo "$d"
}

uts() { # <root> [args...] -- run the fixture's status script; output in $OUT, status in $RC
  local d="$1"
  shift
  ( cd "$d" && bash "$d/.claude/scripts/update-task-status.sh" "$@" ) >"$OUT" 2>&1
  RC=$?
}
status_of() { jq -r '.active_projects[0].status' "$1/specs/state.json"; }
proofs() { jq -r '.landing_proofs | length' "$1/specs/.orchestration/batch/${SESSION}.json"; }
plan_of() { echo "$1/specs/001_fixture_task/plans/01_fixture-plan.md"; }
bytes() { cksum < "$1/specs/state.json"; cksum < "$(plan_of "$1")"; }

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

# =====================================================================
echo ""
echo "--- landed work completes and records one proof ---"
d="$(mkfixture)"
uts "$d" postflight 1 implement "$SESSION"
expect_rc "a completion with landed work exits 0" 0
[ "$(status_of "$d")" = "completed" ] \
  && common_test_pass "the status is written completed" \
  || common_test_fail "the status is written completed" "  got $(status_of "$d")"
[ "$(proofs "$d")" = "1" ] \
  && common_test_pass "one landing proof is recorded" \
  || common_test_fail "one landing proof is recorded" "  got $(proofs "$d")"
expect_out "the predicate's pass line is shown" "LANDING-VERIFIED task 1"
[ "$(jq -r '.landing_proofs[0] | "\(.task_number) \(.paths | join(",")) \(.phases[0].name)"' \
     "$d/specs/.orchestration/batch/${SESSION}.json")" = "1 src/work.txt Only phase" ] \
  && common_test_pass "the proof names the task, its path set and its completed phase" \
  || common_test_fail "the proof names the task, its path set and its completed phase"

uts "$d" postflight 1 implement "$SESSION"
expect_rc "a second call after completion exits 0" 0
[ "$(proofs "$d")" = "1" ] && [ "$(status_of "$d")" = "completed" ] \
  && common_test_pass "the second call is a no-op: one proof, still completed" \
  || common_test_fail "the second call is a no-op: one proof, still completed"

# =====================================================================
echo ""
echo "--- negative: work left uncommitted ---"
d="$(mkfixture)"
echo more >> "$d/src/work.txt"
f="$d/.claude/scripts/update-task-status.sh"
sed -i -E 's|^( *)exit 7$|\1: # gate refusal disabled by the suite|' "$f"
if cmp -s "$f" "$UTS_SRC"; then
  common_test_fail "the mutation seam still edits the status script" "  the seam's sed matched nothing"
else
  common_test_pass "the mutation seam still edits the status script"
fi
uts "$d" postflight 1 implement "$SESSION"
if [ "$RC" = "0" ] && [ "$(status_of "$d")" = "completed" ]; then
  common_test_pass "OBSERVED-FAILING: with the gate's refusal disabled, uncommitted work is written completed"
else
  common_test_fail "OBSERVED-FAILING: with the gate's refusal disabled, uncommitted work is written completed" "  rc=$RC status=$(status_of "$d"): $(tr '\n' ' ' < "$OUT")"
fi

d="$(mkfixture)"
echo more >> "$d/src/work.txt"
before="$(bytes "$d")"
uts "$d" postflight 1 implement "$SESSION"
expect_rc "work left uncommitted exits 7" 7
[ "$(bytes "$d")" = "$before" ] \
  && common_test_pass "the refusal leaves specs/state.json and the plan file byte-identical" \
  || common_test_fail "the refusal leaves specs/state.json and the plan file byte-identical"
[ "$(status_of "$d")" = "implementing" ] && [ "$(proofs "$d")" = "0" ] \
  && common_test_pass "the task stays implementing and no proof is recorded" \
  || common_test_fail "the task stays implementing and no proof is recorded"
expect_out "the predicate's own refusal line names the path" "src/work.txt"
expect_out "the status script states that nothing was written" "No state.json write and no plan-file status stamp occurred."
git -C "$d" add -- src/work.txt
git -C "$d" commit -q -m "task 1 phase 1: the rest of the work"
uts "$d" postflight 1 implement "$SESSION"
expect_rc "committing the work under the task's subject clears the refusal" 0
[ "$(status_of "$d")" = "completed" ] \
  && common_test_pass "the retry writes completed" \
  || common_test_fail "the retry writes completed"

echo ""
echo "--- negative: no commit attributable to the task ---"
d="$(mkfixture false)"
git -C "$d" init -q -b "$BRANCH"
git -C "$d" add -- .gitignore specs/state.json specs/TODO.md \
  specs/001_fixture_task/plans/01_fixture-plan.md src/work.txt
git -C "$d" commit -q -m "init"
before="$(bytes "$d")"
uts "$d" postflight 1 implement "$SESSION"
expect_rc "a git work tree with no attributed commit exits 7" 7
[ "$(bytes "$d")" = "$before" ] \
  && common_test_pass "that refusal also writes nothing" \
  || common_test_fail "that refusal also writes nothing"

# =====================================================================
echo ""
echo "--- the reconcile promotion path is refused the same way ---"
d="$(mkfixture)"
mkdir -p "$d/specs/001_fixture_task/summaries"
echo "# summary" > "$d/specs/001_fixture_task/summaries/01_fixture-summary.md"
echo more >> "$d/src/work.txt"
( cd "$d" && bash "$d/.claude/scripts/reconcile-task-status.sh" 1 "$SESSION" ) >"$OUT" 2>&1; RC=$?
expect_rc "reconcile exits with the gate's code" 7
[ "$(status_of "$d")" = "implementing" ] \
  && common_test_pass "reconcile does not promote a task whose work did not land" \
  || common_test_fail "reconcile does not promote a task whose work did not land" "  got $(status_of "$d")"
if grep -q "promoted implementing -> completed" "$OUT"; then
  common_test_fail "reconcile prints no promotion line"
else
  common_test_pass "reconcile prints no promotion line"
fi
git -C "$d" add -- src/work.txt
git -C "$d" commit -q -m "task 1 phase 1: the rest of the work"
( cd "$d" && bash "$d/.claude/scripts/reconcile-task-status.sh" 1 "$SESSION" ) >"$OUT" 2>&1; RC=$?
expect_rc "reconcile promotes once the work has landed" 0
[ "$(status_of "$d")" = "completed" ] && [ "$(proofs "$d")" = "1" ] \
  && common_test_pass "the promotion writes completed and records the proof" \
  || common_test_fail "the promotion writes completed and records the proof" "  status=$(status_of "$d") proofs=$(proofs "$d")"

# =====================================================================
echo ""
echo "--- --dry-run writes nothing ---"
d="$(mkfixture)"
before="$(bytes "$d"; cksum < "$d/specs/.orchestration/batch/${SESSION}.json"; ls -a "$d/specs")"
uts "$d" postflight 1 implement "$SESSION" --dry-run
expect_rc "--dry-run with landed work exits 0" 0
[ "$(bytes "$d"; cksum < "$d/specs/.orchestration/batch/${SESSION}.json"; ls -a "$d/specs")" = "$before" ] \
  && common_test_pass "--dry-run writes no state, no plan stamp, no proof and takes no mutex" \
  || common_test_fail "--dry-run writes no state, no plan stamp, no proof and takes no mutex"
echo more >> "$d/src/work.txt"
uts "$d" postflight 1 implement "$SESSION" --dry-run
expect_rc "--dry-run over unlanded work reports and exits 0" 0
expect_out "--dry-run says the gate would block" "[dry-run] Landing-check would block this transition"

# =====================================================================
echo ""
echo "--- inconclusive cases pass through, named ---"
d="$(mkfixture false)"
uts "$d" postflight 1 implement "$SESSION"
expect_rc "a project root that is not a git work tree completes" 0
expect_out "the pass-through is named" "not a git work tree"
[ "$(status_of "$d")" = "completed" ] \
  && common_test_pass "the status is written completed there" \
  || common_test_fail "the status is written completed there"

d="$(mkfixture)"
echo more >> "$d/src/work.txt"
rm "$d/.claude/scripts/task-landing-verify.sh"
uts "$d" postflight 1 implement "$SESSION"
expect_rc "a tree without the predicate script completes" 0
expect_out "that pass-through is named too" "task-landing-verify.sh is not present beside this script"

d="$(mkfixture)"
echo more >> "$d/src/work.txt"
uts "$d" postflight 1 research "$SESSION"
[ "$RC" = "0" ] && ! grep -q "LANDING-" "$OUT" \
  && common_test_pass "a postflight other than implement never runs the gate" \
  || common_test_fail "a postflight other than implement never runs the gate" "  rc=$RC: $(tr '\n' ' ' < "$OUT")"
# task-ref-ok:end

# =====================================================================
echo ""
echo "--- the status script documents the exit code ---"
grep -qE '^#   7 - ' "$UTS_SRC" \
  && common_test_pass "the header's exit-code table lists exit 7" \
  || common_test_fail "the header's exit-code table lists exit 7"

echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
