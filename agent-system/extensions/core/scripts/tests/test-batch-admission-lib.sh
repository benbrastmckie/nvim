#!/usr/bin/env bash
# test-batch-admission-lib.sh - Regression suite for scripts/lib/batch-admission-lib.sh: the
# `integration_branch` and `worktree_isolation` readers, the admission predicate, and the batch
# record writer.
#
# Follows context/standards/shell-script-testing.md and this directory's house convention:
# common_test_pass/_fail/_info from lib/common.sh, PASSED/FAILED counters, a mktemp -d workdir
# with a trap EXIT cleanup, and assertions that read the verdict variables and the record file
# directly. Every fixture is a scratch git repository under the workdir; none is built with a
# command that discards working-tree changes.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED (or a required file is missing,
# reported loudly rather than silently skipped).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."

PASSED=0
FAILED=0

LIB_PATH="$SRC_SCRIPTS_DIR/lib/batch-admission-lib.sh"
PATTERNS_LIB="$SRC_SCRIPTS_DIR/lib/runtime-file-patterns.sh"
SCHEMA_DOC="$SRC_SCRIPTS_DIR/../context/standards/repo-level-declarations.md"
for required in "$LIB_PATH" "$PATTERNS_LIB"; do
  if [ ! -f "$required" ]; then
    echo "ERROR: test-batch-admission-lib.sh cannot run -- missing required file: $required" >&2
    exit 1
  fi
done
for tool in git jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: test-batch-admission-lib.sh cannot run -- missing required tool: $tool" >&2
    exit 1
  fi
done

# shellcheck disable=SC1090
source "$PATTERNS_LIB"
# shellcheck disable=SC1090
source "$LIB_PATH"

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

BRANCH="trunk"
SESSION="sess_fixture_1"
ERR="$TOP_WORKDIR/stderr.txt"
OUT="$TOP_WORKDIR/stdout.txt"

fgit() { git -c user.name=fixture -c user.email=fixture@example.invalid "$@"; }

# mkrepo [declarations_json] -- a scratch repository on $BRANCH with one commit carrying a file
# in each state-territory member and two files outside it. Echoes the repository root.
mkrepo() {
  local decl="${1:-}" root
  root="$(mktemp -d -p "$TOP_WORKDIR")"
  [ -n "$decl" ] || decl="{\"extensions\":{},\"version\":1,\"integration_branch\":\"$BRANCH\"}"
  fgit -C "$root" init -q -b "$BRANCH"
  mkdir -p "$root/specs" "$root/.memory" "$root/src"
  echo '{"active_projects":[]}' > "$root/specs/state.json"
  echo '{}' > "$root/.memory/memory-index.json"
  echo 'one' > "$root/src/a.txt"
  echo 'two' > "$root/src/b.txt"
  printf '%s\n' "$decl" > "$root/.claude-extensions.json"
  fgit -C "$root" add -- specs/state.json .memory/memory-index.json src/a.txt src/b.txt \
    .claude-extensions.json
  fgit -C "$root" commit -q -m "seed"
  echo "$root"
}

# evaluate <root> [dry_run] [session] -- runs the predicate in this shell; standard error lands
# in $ERR and standard output in $OUT.
evaluate() {
  local root="$1" dry="${2:-false}" session="${3:-$SESSION}"
  batch_admission_evaluate "$root" "$root/specs" "$session" "$dry" '[7,8]' "orch_fixture" \
    >"$OUT" 2>"$ERR"
}

record_of() { runtime_batch_record_path "$1/specs" "${2:-$SESSION}"; }

expect_verdict() {
  local label="$1" want_verdict="$2" want_reason="${3:-}"
  if [ "$BATCH_ADMISSION_VERDICT" = "$want_verdict" ] && [ "$BATCH_ADMISSION_REASON" = "$want_reason" ]; then
    common_test_pass "$label"
  else
    common_test_fail "$label" "  want ${want_verdict}/${want_reason:-<none>}, got ${BATCH_ADMISSION_VERDICT}/${BATCH_ADMISSION_REASON:-<none>}: ${BATCH_ADMISSION_MESSAGE}"
  fi
}

expect_message_has() {
  local label="$1" needle="$2"
  if printf '%s' "$BATCH_ADMISSION_MESSAGE" | grep -qF -- "$needle"; then
    common_test_pass "$label"
  else
    common_test_fail "$label" "  message lacks '${needle}': ${BATCH_ADMISSION_MESSAGE}"
  fi
}

expect_no_record() {
  local label="$1" root="$2"
  if [ ! -e "$root/specs/.orchestration" ]; then
    common_test_pass "$label"
  else
    common_test_fail "$label" "  unexpected: $(find "$root/specs/.orchestration" | tr '\n' ' ')"
  fi
}

# =====================================================================
common_test_info "=== Case 1: declared, on branch, clean -> admit, one record of the stated shape ==="
r="$(mkrepo)"
evaluate "$r"
expect_verdict "clean declared tree admits" "admit"
rec="$(record_of "$r")"
tip="$(git -C "$r" rev-parse HEAD)"
if [ -f "$rec" ] && jq -e --arg s "$SESSION" --arg b "$BRANCH" --arg tip "$tip" '
    .schema == 1 and .session_id == $s and .orchestration_id == "orch_fixture"
    and .task_numbers == [7,8] and (.admitted_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$"))
    and .integration_branch == $b and .integration_branch_declared == true
    and .integration_tip_at_cut == $tip and .worktree_isolation == "off"
    and .landing_proofs == []' "$rec" >/dev/null; then
  common_test_pass "record carries every stated field"
else
  common_test_fail "record carries every stated field" "  $(cat "$rec" 2>/dev/null || echo '<no record>')"
fi
if [ -f "$rec" ] && jq -e '(has("isolation") | not) and (keys | length == 10)' "$rec" >/dev/null; then
  common_test_pass "record has no isolation key and exactly ten fields"
else
  common_test_fail "record has no isolation key and exactly ten fields"
fi
if [ "$(find "$r/specs/.orchestration/batch" -type f | wc -l)" = "1" ]; then
  common_test_pass "exactly one file under batch/ (no tmp file left behind)"
else
  common_test_fail "exactly one file under batch/ (no tmp file left behind)"
fi
if [ ! -s "$OUT" ] && [ ! -s "$ERR" ]; then
  common_test_pass "a declared admit is silent on both streams"
else
  common_test_fail "a declared admit is silent on both streams" "  out=$(cat "$OUT") err=$(cat "$ERR")"
fi

# =====================================================================
common_test_info "=== Case 2: dirt only inside the state territory -> admit ==="
r="$(mkrepo)"
echo '{"active_projects":[1]}' > "$r/specs/state.json"
echo '{"n":1}' > "$r/.memory/memory-index.json"
echo "{\"extensions\":{\"x\":1},\"version\":1,\"integration_branch\":\"$BRANCH\"}" > "$r/.claude-extensions.json"
evaluate "$r"
expect_verdict "state-territory dirt admits" "admit"
if [ -z "$(batch_admission_dirty_paths "$r")" ]; then
  common_test_pass "dirty-path listing is empty for state-territory dirt"
else
  common_test_fail "dirty-path listing is empty for state-territory dirt" "  $(batch_admission_dirty_paths "$r")"
fi

# =====================================================================
common_test_info "=== Case 3: untracked file outside the state territory -> admit ==="
r="$(mkrepo)"
echo 'new' > "$r/src/untracked.txt"
evaluate "$r"
expect_verdict "untracked file never refuses" "admit"

# =====================================================================
common_test_info "=== Case 4: staged new file outside the state territory -> refuse ==="
r="$(mkrepo)"
echo 'new' > "$r/src/staged.txt"
fgit -C "$r" add -- src/staged.txt
evaluate "$r"
expect_verdict "staged new file refuses" "refuse" "dirty_primary_tree"
expect_message_has "refusal names the staged path" "src/staged.txt"
expect_no_record "a refusal writes no record" "$r"

# =====================================================================
common_test_info "=== Case 5: staged rename -> refuse, naming the new path ==="
r="$(mkrepo)"
fgit -C "$r" mv src/a.txt src/renamed.txt
evaluate "$r"
expect_verdict "staged rename refuses" "refuse" "dirty_primary_tree"
expect_message_has "refusal names the renamed path" "src/renamed.txt"

# =====================================================================
common_test_info "=== Case 6: working-tree deletion and modification -> refuse, listing every path ==="
r="$(mkrepo)"
rm "$r/src/a.txt"
echo 'changed' >> "$r/src/b.txt"
evaluate "$r"
expect_verdict "deletion plus modification refuses" "refuse" "dirty_primary_tree"
expect_message_has "refusal names the deleted path" "src/a.txt"
expect_message_has "refusal names the modified path" "src/b.txt"
expect_message_has "refusal counts both paths" "2 tracked path(s)"
for member in "${BATCH_ADMISSION_STATE_TERRITORY[@]}"; do
  expect_message_has "refusal names state-territory member ${member}" "$member"
done

# =====================================================================
common_test_info "=== Case 7: on another branch -> refuse, naming both ==="
r="$(mkrepo)"
fgit -C "$r" checkout -q -b side
evaluate "$r"
expect_verdict "other branch refuses" "refuse" "off_integration_branch"
expect_message_has "refusal names the checked-out branch" "'side'"
expect_message_has "refusal names the declared branch" "'$BRANCH'"
expect_no_record "an off-branch refusal writes no record" "$r"

# =====================================================================
common_test_info "=== Case 8: detached HEAD -> refuse ==="
r="$(mkrepo)"
fgit -C "$r" checkout -q --detach
evaluate "$r"
expect_verdict "detached HEAD refuses" "refuse" "off_integration_branch"
expect_message_has "refusal says HEAD is detached" "detached HEAD"

# =====================================================================
common_test_info "=== Case 9: worktree_isolation batch -> loud refusal naming the implementing work ==="
r="$(mkrepo "{\"integration_branch\":\"$BRANCH\",\"worktree_isolation\":\"batch\"}")"
evaluate "$r"
expect_verdict "batch refuses" "refuse" "isolation_unimplemented"
expect_message_has "refusal names the implementing work" "$BATCH_ADMISSION_ISOLATION_WORK"
expect_message_has "refusal names the declared value" '"batch"'
expect_message_has "refusal says not implemented" "not implemented"
if printf '%s' "$BATCH_ADMISSION_MESSAGE" | grep -qiE 'task #?[0-9]+'; then
  common_test_fail "refusal carries no task number" "  $BATCH_ADMISSION_MESSAGE"
else
  common_test_pass "refusal carries no task number"
fi
expect_no_record "a batch refusal writes no record" "$r"
[ "$(batch_admission_worktree_isolation "$r")" = "batch" ] \
  && common_test_pass "reader returns batch" || common_test_fail "reader returns batch"

nongit="$(mktemp -d -p "$TOP_WORKDIR")"
echo '{"worktree_isolation":"batch"}' > "$nongit/.claude-extensions.json"
evaluate "$nongit"
expect_verdict "batch refuses even outside a git work tree" "refuse" "isolation_unimplemented"

# =====================================================================
common_test_info "=== Case 10: unrecognised worktree_isolation values -> refuse like batch ==="
r="$(mkrepo "{\"integration_branch\":\"$BRANCH\",\"worktree_isolation\":\"on\"}")"
evaluate "$r"
expect_verdict "unknown string value refuses" "refuse" "isolation_unimplemented"
expect_message_has "refusal names the bad value" ' "on",'
expect_message_has "unknown-value refusal names the implementing work" "$BATCH_ADMISSION_ISOLATION_WORK"
r="$(mkrepo "{\"integration_branch\":\"$BRANCH\",\"worktree_isolation\":true}")"
evaluate "$r"
expect_verdict "non-string value refuses" "refuse" "isolation_unimplemented"
expect_message_has "refusal names the non-string value" " true,"
r="$(mkrepo "{\"integration_branch\":\"$BRANCH\",\"worktree_isolation\":\"\"}")"
evaluate "$r"
expect_verdict "empty-string value refuses" "refuse" "isolation_unimplemented"
expect_message_has "refusal shows the empty string as a quoted value" ' "",'

# =====================================================================
common_test_info "=== Case 11: explicit off, JSON null, and absence all read as off ==="
r="$(mkrepo "{\"integration_branch\":\"$BRANCH\",\"worktree_isolation\":\"off\"}")"
evaluate "$r"
expect_verdict "explicit off admits" "admit"
r2="$(mkrepo "{\"integration_branch\":\"$BRANCH\",\"worktree_isolation\":null}")"
empty="$(mktemp -d -p "$TOP_WORKDIR")"
broken="$(mktemp -d -p "$TOP_WORKDIR")"
echo 'not json {' > "$broken/.claude-extensions.json"
if [ "$(batch_admission_worktree_isolation "$r")" = "off" ] \
  && [ "$(batch_admission_worktree_isolation "$r2")" = "off" ] \
  && [ "$(batch_admission_worktree_isolation "$empty")" = "off" ] \
  && [ "$(batch_admission_worktree_isolation "$broken")" = "off" ]; then
  common_test_pass "off, null, missing file and unparseable file all read as off"
else
  common_test_fail "off, null, missing file and unparseable file all read as off"
fi

# =====================================================================
common_test_info "=== Case 12: integration_branch undeclared -> one advisory, no refusal ==="
r="$(mkrepo '{"extensions":{},"version":1}')"
echo 'changed' >> "$r/src/b.txt"
evaluate "$r"
expect_verdict "undeclared admits even with dirt outside the state territory" "admit"
if [ "$(grep -c '^ADVISORY:' "$ERR")" = "1" ] && grep -q 'integration_branch' "$ERR" \
  && grep -q '\.claude-extensions\.json' "$ERR" && grep -qF "'$BRANCH'" "$ERR"; then
  common_test_pass "one advisory names the key, the declarations file and the checked-out branch"
else
  common_test_fail "one advisory names the key, the declarations file and the checked-out branch" "  $(cat "$ERR")"
fi
[ ! -s "$OUT" ] && common_test_pass "the advisory never reaches standard output" \
  || common_test_fail "the advisory never reaches standard output"
rec="$(record_of "$r")"
if [ -f "$rec" ] && jq -e --arg b "$BRANCH" '.integration_branch == $b and .integration_branch_declared == false' "$rec" >/dev/null; then
  common_test_pass "undeclared record carries the checked-out branch, declared false"
else
  common_test_fail "undeclared record carries the checked-out branch, declared false"
fi
evaluate "$r"
expect_verdict "undeclared second cycle admits" "admit"
[ ! -s "$ERR" ] && common_test_pass "the advisory is printed on the first cycle only" \
  || common_test_fail "the advisory is printed on the first cycle only" "  $(cat "$ERR")"
for bad in '""' '42' '["trunk"]' 'null'; do
  r="$(mkrepo "{\"integration_branch\":$bad}")"
  if [ -z "$(batch_admission_integration_branch "$r")" ]; then
    common_test_pass "integration_branch $bad reads as undeclared"
  else
    common_test_fail "integration_branch $bad reads as undeclared"
  fi
done
r="$(mkrepo)"
[ "$(batch_admission_integration_branch "$r")" = "$BRANCH" ] \
  && common_test_pass "declared integration_branch is read back" \
  || common_test_fail "declared integration_branch is read back"

# =====================================================================
common_test_info "=== Case 13: unborn branch -> branch test passes, no dirty test, null tip ==="
r="$(mktemp -d -p "$TOP_WORKDIR")"
fgit -C "$r" init -q -b "$BRANCH"
mkdir -p "$r/specs" "$r/src"
echo "{\"integration_branch\":\"$BRANCH\"}" > "$r/.claude-extensions.json"
echo 'x' > "$r/src/a.txt"
fgit -C "$r" add -- src/a.txt
evaluate "$r"
expect_verdict "unborn branch admits" "admit"
rec="$(record_of "$r")"
if [ -f "$rec" ] && jq -e '.integration_tip_at_cut == null' "$rec" >/dev/null; then
  common_test_pass "unborn branch records a null tip"
else
  common_test_fail "unborn branch records a null tip"
fi

# =====================================================================
common_test_info "=== Case 14: project root is not a git work tree -> silent skip ==="
nongit="$(mktemp -d -p "$TOP_WORKDIR")"
mkdir -p "$nongit/specs"
echo "{\"integration_branch\":\"$BRANCH\"}" > "$nongit/.claude-extensions.json"
if [ "$(git -C "$nongit" rev-parse --is-inside-work-tree 2>/dev/null || true)" = "true" ]; then
  common_test_info "SKIP: the temporary directory is itself inside a git work tree; case 14 cannot be built here"
else
  evaluate "$nongit"
  expect_verdict "non-git root skips" "skip"
  expect_no_record "a skip writes no record" "$nongit"
  if [ ! -s "$OUT" ] && [ ! -s "$ERR" ]; then
    common_test_pass "a skip is silent on both streams"
  else
    common_test_fail "a skip is silent on both streams" "  $(cat "$ERR")"
  fi
fi

# =====================================================================
common_test_info "=== Case 15: later cycles skip the dirty test, keep the branch test, never rewrite ==="
r="$(mkrepo)"
evaluate "$r"
rec="$(record_of "$r")"
before="$(cat "$rec")"
echo 'changed by a dispatch' >> "$r/src/b.txt"
evaluate "$r"
expect_verdict "second cycle admits despite dirt outside the state territory" "admit"
if [ "$(cat "$rec")" = "$before" ]; then
  common_test_pass "second cycle leaves the record byte-identical"
else
  common_test_fail "second cycle leaves the record byte-identical"
fi
evaluate "$r" false "sess_fixture_other"
expect_verdict "a different session is a first cycle again and refuses the same dirt" "refuse" "dirty_primary_tree"
fgit -C "$r" checkout -q -b side
evaluate "$r"
expect_verdict "the branch test still runs on a later cycle" "refuse" "off_integration_branch"
if [ "$(cat "$rec")" = "$before" ] && [ "$(find "$r/specs/.orchestration/batch" -type f | wc -l)" = "1" ]; then
  common_test_pass "one record per session, untouched by later refusals"
else
  common_test_fail "one record per session, untouched by later refusals"
fi

# =====================================================================
common_test_info "=== Case 16: dry-run evaluates and reports, writes nothing ==="
r="$(mkrepo)"
evaluate "$r" true
expect_verdict "dry-run admit" "admit"
expect_no_record "dry-run admit writes no record" "$r"
echo 'changed' >> "$r/src/b.txt"
evaluate "$r" true
expect_verdict "dry-run still reports a refusal" "refuse" "dirty_primary_tree"
expect_no_record "dry-run refusal writes no record" "$r"

# =====================================================================
common_test_info "=== Case 17: safe under a caller's set -euo pipefail, and idempotent to source ==="
r="$(mkrepo)"
fgit -C "$r" checkout -q -b side
strict_out="$(bash -c '
  set -euo pipefail
  source "$1"; source "$2"; source "$2"
  batch_admission_evaluate "$3" "$3/specs" sess_strict false "[1]" ""
  echo "${BATCH_ADMISSION_VERDICT}/${BATCH_ADMISSION_REASON}"
  batch_admission_evaluate "$4" "$4/specs" sess_strict false
  echo "${BATCH_ADMISSION_VERDICT}/${BATCH_ADMISSION_REASON}"
' _ "$PATTERNS_LIB" "$LIB_PATH" "$r" "$TOP_WORKDIR/does-not-exist" 2>/dev/null)"
if [ "$strict_out" = "$(printf 'refuse/off_integration_branch\nskip/')" ]; then
  common_test_pass "a refusal and a missing root both return 0 under errexit"
else
  common_test_fail "a refusal and a missing root both return 0 under errexit" "  got: $strict_out"
fi

# =====================================================================
common_test_info "=== Case 18: record path resolver ==="
if [ "$(runtime_batch_record_path "some/specs" "sess_x")" = "some/specs/.orchestration/batch/sess_x.json" ] \
  && [ "$(batch_admission_record_path "some/specs" "sess_x")" = "some/specs/.orchestration/batch/sess_x.json" ]; then
  common_test_pass "both resolvers return the batch/ subdirectory path"
else
  common_test_fail "both resolvers return the batch/ subdirectory path"
fi
r="$(mkrepo)"
batch_admission_evaluate "$r" "$r/specs" "" false >/dev/null 2>&1
expect_verdict "an empty session identity still evaluates" "admit"
expect_no_record "an empty session identity writes no record" "$r"

# =====================================================================
common_test_info "=== Case 19: doc-sync -- state territory and the implementing work's name ==="
if [ ! -f "$SCHEMA_DOC" ]; then
  common_test_fail "schema document present" "  missing: $SCHEMA_DOC"
else
  [ "${#BATCH_ADMISSION_STATE_TERRITORY[@]}" = "3" ] \
    && common_test_pass "state territory has exactly three members" \
    || common_test_fail "state territory has exactly three members"
  for member in "${BATCH_ADMISSION_STATE_TERRITORY[@]}"; do
    if grep -qE "^- \`${member//./\\.}/?\`" "$SCHEMA_DOC"; then
      common_test_pass "schema document lists state-territory member ${member}"
    else
      common_test_fail "schema document lists state-territory member ${member}"
    fi
  done
  doc_members="$(sed -n '/^\*\*State territory\*\*/,/^A blanket clean-tree test/p' "$SCHEMA_DOC" | grep -c '^- `')"
  [ "$doc_members" = "3" ] \
    && common_test_pass "schema document lists exactly three state-territory members" \
    || common_test_fail "schema document lists exactly three state-territory members" "  found $doc_members"
  grep -qF "$BATCH_ADMISSION_ISOLATION_WORK" "$SCHEMA_DOC" \
    && common_test_pass "schema document names the implementing work" \
    || common_test_fail "schema document names the implementing work"
  for reason in isolation_unimplemented off_integration_branch dirty_primary_tree; do
    grep -qF "\`$reason\`" "$SCHEMA_DOC" \
      && common_test_pass "schema document names stop reason $reason" \
      || common_test_fail "schema document names stop reason $reason"
  done
fi

# =====================================================================
# Record lookup by member task, and the landing-proof appender
# =====================================================================
echo ""
echo "--- record lookup by member task, landing-proof append ---"
root="$(mkrepo)"
specs="$root/specs"
[ -z "$(batch_admission_record_for_task "$specs" 7)" ] \
  && common_test_pass "lookup prints nothing when no batch directory exists" \
  || common_test_fail "lookup prints nothing when no batch directory exists"
mkdir -p "$specs/.orchestration/batch"
write_rec() { # <session> <admitted_at> <task_numbers_json>
  jq -n --arg s "$1" --arg a "$2" --argjson t "$3" \
    '{schema:1,session_id:$s,task_numbers:$t,admitted_at:$a,landing_proofs:[]}' \
    > "$(record_of "$root" "$1")"
}
write_rec sess_old "2026-01-01T00:00:00Z" '[7,8]'
write_rec sess_new "2026-02-01T00:00:00Z" '[7]'
write_rec sess_other "2026-03-01T00:00:00Z" '[70,17]'
echo 'not json' > "$specs/.orchestration/batch/sess_broken.json"
[ "$(batch_admission_record_for_task "$specs" 7)" = "$(record_of "$root" sess_new)" ] \
  && common_test_pass "lookup returns the newest record listing the task" \
  || common_test_fail "lookup returns the newest record listing the task" "  got $(batch_admission_record_for_task "$specs" 7)"
[ "$(batch_admission_record_for_task "$specs" 8)" = "$(record_of "$root" sess_old)" ] \
  && common_test_pass "lookup matches by membership, not by position" \
  || common_test_fail "lookup matches by membership, not by position"
want_all="$(record_of "$root" sess_new)"$'\n'"$(record_of "$root" sess_old)"
[ "$(batch_admission_record_for_task "$specs" 7 all)" = "$want_all" ] \
  && common_test_pass "lookup 'all' lists every record for the task, newest first" \
  || common_test_fail "lookup 'all' lists every record for the task, newest first"
[ -z "$(batch_admission_record_for_task "$specs" 9)" ] \
  && common_test_pass "lookup prints nothing for a task no record lists (7 does not match 70 or 17)" \
  || common_test_fail "lookup prints nothing for a task no record lists"
[ -z "$(batch_admission_record_for_task "$specs" "7x")" ] \
  && common_test_pass "lookup prints nothing for a non-numeric task" \
  || common_test_fail "lookup prints nothing for a non-numeric task"

rec="$(record_of "$root" sess_new)"
out="$(batch_admission_append_landing_proof "$rec" '{"task_number":7,"end_commit":"abc"}' 2>"$ERR")"
if [ "$out" = "appended" ] && [ "$(jq -c '.landing_proofs' "$rec")" = '[{"task_number":7,"end_commit":"abc"}]' ] \
   && [ "$(jq -r '.session_id' "$rec")" = "sess_new" ]; then
  common_test_pass "append adds one proof and keeps the record's other fields"
else
  common_test_fail "append adds one proof and keeps the record's other fields" "  out='$out' $(cat "$rec")"
fi
batch_admission_append_landing_proof "$rec" '{"task_number":7,"end_commit":"def"}' >/dev/null 2>&1
[ "$(jq -r '[.landing_proofs[].end_commit] | join(",")' "$rec")" = "abc,def" ] \
  && common_test_pass "append is append-only and ordered" \
  || common_test_fail "append is append-only and ordered"
before="$(cksum < "$rec")"
out="$(batch_admission_append_landing_proof "$rec" '[1,2]' 2>"$ERR")"
if [ -z "$out" ] && [ "$(cksum < "$rec")" = "$before" ] && grep -q 'not a JSON object' "$ERR"; then
  common_test_pass "append refuses a non-object proof with a named warning, record byte-identical"
else
  common_test_fail "append refuses a non-object proof with a named warning, record byte-identical"
fi
out="$(batch_admission_append_landing_proof "$specs/.orchestration/batch/absent.json" '{}' 2>"$ERR")"
if [ -z "$out" ] && grep -q 'no batch record' "$ERR"; then
  common_test_pass "append to a missing record warns and writes nothing"
else
  common_test_fail "append to a missing record warns and writes nothing"
fi
[ -z "$(find "$specs/.orchestration/batch" -name '*.tmp.*')" ] \
  && common_test_pass "append leaves no temporary file behind" \
  || common_test_fail "append leaves no temporary file behind"

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
