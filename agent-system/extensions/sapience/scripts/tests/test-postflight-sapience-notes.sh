#!/usr/bin/env bash
# test-postflight-sapience-notes.sh - Regression suite for postflight-sapience-notes.sh, the
# single mechanically-anchored site where a completing task's agent-authored sapience_notes
# array reaches the Sapience vault.
#
# Stub mechanism: sapience-remember.sh itself is stubbed (never curl), because
# postflight-sapience-notes.sh calls its sibling by `${SCRIPT_DIR}/`-qualified path, so
# PATH-shadowing would not reach it. Each scratch's `.claude/scripts/sapience-remember.sh` is
# REPLACED with a small recorder script (not a copy of the real one, and so it needs no
# deploy-root-guard.sh of its own): it appends every argv element, one per line, followed by a
# `===CALL-END===` sentinel, to a recorder file named by `STUB_RECORDER`; optionally fails with
# exit 1 (after printing a diagnostic to stderr) when `--subject` matches `STUB_FAIL_SUBJECT`;
# and echoes a `dry-run-output for <subject>` line to stdout when `--dry-run` is among its args.
# `stub_call_count <recorder>` counts `===CALL-END===` sentinels to assert exact call counts.
#
# Follows the core shell-test convention: common_test_pass/_fail/_info, PASSED/FAILED integer
# counters, a `mktemp -d` workdir with a trap EXIT cleanup, and the two-candidate lib/common.sh
# bootstrap test-sapience-capture.sh already establishes for a suite living under the sapience
# extension (whose scripts/ has no lib/ of its own pre-deploy). Repo root via
# common_test_repo_root, never a fixed-depth `cd ../../..` walk.
#
# Cases (see each case's own header comment for detail):
#   1. N == 0                         -> zero stub calls, one knowledge-capture gap row, exit 0
#   2. N == 1                         -> exactly 1 stub call, minted subject/value, no gap row
#   3. N == 8                         -> exactly 8 stub calls, minted subject/value, no gap row
#   4. N == 12                        -> exactly 8 stub calls, one tooling bug or gap row
#   5. one mid-run failure within N=4 -> one infrastructure/transport unavailable row, all 4 attempted
#   6. sibling sapience-remember.sh absent -> exit 0, zero stub calls, zero issue rows
#   7. value with a double quote and a newline -> arrives at the stub as one intact argument
#   8. --dry-run                      -> propagates --dry-run into every stub invocation
#   9. missing/malformed .return-meta.json -> treated as N == 0 (one gap row, exit 0)
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (postflight-sapience-notes.sh, deploy-root-guard.sh, issue-record.sh, or a lib/ dependency not
# found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../lib/common.sh"
elif [ -f "$SCRIPT_DIR/../../../core/scripts/lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../../../core/scripts/lib/common.sh"
else
  echo "ERROR: test-postflight-sapience-notes.sh cannot locate lib/common.sh at any candidate path" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$COMMON_SH"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

SCRIPT_UNDER_TEST="$(common_test_resolve_subject "postflight-sapience-notes.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/postflight-sapience-notes.sh" \
  "$SCRIPT_DIR/../postflight-sapience-notes.sh")" || exit 2
common_test_declare_subject "$SCRIPT_UNDER_TEST"

GUARD_CANDIDATE_DEPLOYED="$REPO_ROOT/.claude/scripts/deploy-root-guard.sh"
GUARD_CANDIDATE_SOURCE="$SCRIPT_DIR/../../../core/scripts/deploy-root-guard.sh"
if [ -f "$GUARD_CANDIDATE_DEPLOYED" ]; then
  GUARD_SCRIPT="$GUARD_CANDIDATE_DEPLOYED"
elif [ -f "$GUARD_CANDIDATE_SOURCE" ]; then
  GUARD_SCRIPT="$GUARD_CANDIDATE_SOURCE"
else
  echo "ERROR: deploy-root-guard.sh not found at $GUARD_CANDIDATE_DEPLOYED or $GUARD_CANDIDATE_SOURCE" >&2
  exit 2
fi
common_test_declare_subject "$GUARD_SCRIPT"

ISSUE_RECORD_CANDIDATE_DEPLOYED="$REPO_ROOT/.claude/scripts/issue-record.sh"
ISSUE_RECORD_CANDIDATE_SOURCE="$SCRIPT_DIR/../../../core/scripts/issue-record.sh"
if [ -f "$ISSUE_RECORD_CANDIDATE_DEPLOYED" ]; then
  ISSUE_RECORD_SCRIPT="$ISSUE_RECORD_CANDIDATE_DEPLOYED"
elif [ -f "$ISSUE_RECORD_CANDIDATE_SOURCE" ]; then
  ISSUE_RECORD_SCRIPT="$ISSUE_RECORD_CANDIDATE_SOURCE"
else
  echo "ERROR: issue-record.sh not found at $ISSUE_RECORD_CANDIDATE_DEPLOYED or $ISSUE_RECORD_CANDIDATE_SOURCE" >&2
  exit 2
fi
common_test_declare_subject "$ISSUE_RECORD_SCRIPT"

ISSUE_RECORD_DIR="$(dirname "$ISSUE_RECORD_SCRIPT")"
TASK_LOOKUP_LIB_CANDIDATE="$ISSUE_RECORD_DIR/lib/task-lookup-lib.sh"
if [ ! -f "$TASK_LOOKUP_LIB_CANDIDATE" ]; then
  echo "ERROR: lib/task-lookup-lib.sh not found at $TASK_LOOKUP_LIB_CANDIDATE" >&2
  exit 2
fi
CENTRAL_LOG_LIB_CANDIDATE="$ISSUE_RECORD_DIR/lib/central-log-lib.sh"
common_test_declare_subject "$COMMON_SH"

PASSED=0
FAILED=0

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# DEMO_TASK_NUMBER -- the fixture's own --task CLI-flag value, kept in a variable rather than a
# literal so this suite's source text never carries an adjacent "task"+digit citation.
DEMO_TASK_NUMBER="7"
DEMO_TASK_DIR_NAME="demo-task-dir"

# --- stub_call_count <recorder_file> -- counts ===CALL-END=== sentinels. ---
stub_call_count() {
  local recorder="$1" n
  if [ -f "$recorder" ]; then
    n="$(grep -c '^===CALL-END===$' "$recorder" 2>/dev/null)" || true
    echo "${n:-0}"
  else
    echo 0
  fi
}

# --- build_scratch [--with-stub|--no-stub] -- builds an isolated <scratch>/.claude/scripts/{
#     postflight-sapience-notes.sh, deploy-root-guard.sh, issue-record.sh, lib/common.sh,
#     lib/task-lookup-lib.sh, lib/central-log-lib.sh(if present)} tree, a scratch git repo, and a
#     demo task directory at specs/<DEMO_TASK_DIR_NAME>/. With --with-stub (the default), also
#     installs the recorder-stub sapience-remember.sh, with STUB_RECORDER exported to point at a
#     fresh recorder file inside the scratch (echoed as the second output line). Echoes the
#     scratch root on the first line. ---
build_scratch() {
  local with_stub="${1:---with-stub}"
  local scratch recorder
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib" "$scratch/specs/$DEMO_TASK_DIR_NAME"
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/postflight-sapience-notes.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$ISSUE_RECORD_SCRIPT" "$scratch/.claude/scripts/issue-record.sh"
  cp "$COMMON_SH" "$scratch/.claude/scripts/lib/common.sh"
  cp "$TASK_LOOKUP_LIB_CANDIDATE" "$scratch/.claude/scripts/lib/task-lookup-lib.sh"
  [ -f "$CENTRAL_LOG_LIB_CANDIDATE" ] && cp "$CENTRAL_LOG_LIB_CANDIDATE" "$scratch/.claude/scripts/lib/central-log-lib.sh"
  chmod +x "$scratch/.claude/scripts/postflight-sapience-notes.sh" "$scratch/.claude/scripts/issue-record.sh"
  git -C "$scratch" init -q
  git -C "$scratch" config user.email "test@example.com"
  git -C "$scratch" config user.name "test"
  git -C "$scratch" commit -q --allow-empty -m "seed"

  if [ "$with_stub" = "--with-stub" ]; then
    recorder="$scratch/recorder.txt"
    : > "$recorder"
    cat > "$scratch/.claude/scripts/sapience-remember.sh" <<'STUB'
#!/usr/bin/env bash
recorder="${STUB_RECORDER:?STUB_RECORDER must be set}"
{
  for a in "$@"; do
    printf '%s\n' "$a"
  done
  printf '===CALL-END===\n'
} >> "$recorder"

subj=""
prev=""
is_dry_run="false"
for a in "$@"; do
  if [ "$prev" = "--subject" ]; then subj="$a"; fi
  [ "$a" = "--dry-run" ] && is_dry_run="true"
  prev="$a"
done

if [ -n "${STUB_FAIL_SUBJECT:-}" ] && [ "$subj" = "$STUB_FAIL_SUBJECT" ]; then
  echo "stub: simulated sapience-remember.sh failure for subject '$subj'" >&2
  exit 1
fi

if [ "$is_dry_run" = "true" ]; then
  printf 'dry-run-output for %s\n' "$subj"
fi
exit 0
STUB
    chmod +x "$scratch/.claude/scripts/sapience-remember.sh"
  fi

  echo "$scratch"
  [ -n "${recorder:-}" ] && echo "$recorder"
}

# --- mint_notes_json <count> -- echoes a JSON array of <count> objects, each with a freshly
#     minted, non-hardcoded subject/value pair (so an assertion against this output can never
#     pass vacuously on a hardcoded literal). ---
mint_notes_json() {
  local n="$1" i out
  out="[]"
  for ((i = 0; i < n; i++)); do
    out="$(printf '%s' "$out" | jq -c --arg s "mint-subject-$$-${i}-${RANDOM}" --arg v "mint-value-$$-${i}-${RANDOM}" \
      '. + [{"subject": $s, "value": $v}]')"
  done
  printf '%s' "$out"
}

# --- write_return_meta <scratch> <notes_json> -- writes {"sapience_notes": <notes_json>} to the
#     demo task's .return-meta.json. ---
write_return_meta() {
  local scratch="$1" notes_json="$2"
  jq -n --argjson notes "$notes_json" '{sapience_notes: $notes}' \
    > "$scratch/specs/$DEMO_TASK_DIR_NAME/.return-meta.json"
}

# --- run_psn <scratch> [args...] -- invokes postflight-sapience-notes.sh against the demo task
#     directory, forwarding any extra args (e.g. --dry-run) after the required --task-dir/--task
#     pair. ---
run_psn() {
  local scratch="$1"; shift
  bash "$scratch/.claude/scripts/postflight-sapience-notes.sh" \
    --task-dir "$scratch/specs/$DEMO_TASK_DIR_NAME" --task "$DEMO_TASK_NUMBER" "$@"
}

# --- issues_jsonl_classes <scratch> -- echoes one class value per line from the demo task's
#     issues.jsonl, or nothing if the file does not exist / is empty. ---
issues_jsonl_classes() {
  local scratch="$1"
  local f="$scratch/specs/$DEMO_TASK_DIR_NAME/issues.jsonl"
  [ -f "$f" ] || return 0
  jq -r '.class' "$f" 2>/dev/null
}

# =====================================================================================
# Case 1: N == 0 -> zero stub calls, exactly one knowledge-capture gap row, exit 0.
# =====================================================================================
{
  mapfile -t _bs < <(build_scratch --with-stub)
  scratch="${_bs[0]}"
  recorder="${_bs[1]}"
  write_return_meta "$scratch" "[]"
  out="$(STUB_RECORDER="$recorder" run_psn "$scratch" 2>/dev/null)"
  rc=$?
  count="$(stub_call_count "$recorder")"
  classes="$(issues_jsonl_classes "$scratch")"

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(1) N=0: exit 0"
  else
    common_test_fail "(1) N=0: exit 0" "got rc=$rc"
  fi
  if [ "$count" -eq 0 ]; then
    common_test_pass "(1) N=0: zero stub calls"
  else
    common_test_fail "(1) N=0: zero stub calls" "count=$count"
  fi
  if [ "$(printf '%s\n' "$classes" | grep -cx 'knowledge-capture gap')" -eq 1 ] && [ "$(printf '%s\n' "$classes" | grep -c .)" -eq 1 ]; then
    common_test_pass "(1) N=0: exactly one knowledge-capture gap row"
  else
    common_test_fail "(1) N=0: exactly one knowledge-capture gap row" "classes=$classes"
  fi
}

# =====================================================================================
# Case 2: N == 1 -> exactly 1 stub call with the fixture's own minted subject/value, no gap row.
# =====================================================================================
{
  mapfile -t _bs < <(build_scratch --with-stub)
  scratch="${_bs[0]}"
  recorder="${_bs[1]}"
  notes="$(mint_notes_json 1)"
  write_return_meta "$scratch" "$notes"
  subj="$(printf '%s' "$notes" | jq -r '.[0].subject')"
  val="$(printf '%s' "$notes" | jq -r '.[0].value')"
  out="$(STUB_RECORDER="$recorder" run_psn "$scratch" 2>/dev/null)"
  rc=$?
  count="$(stub_call_count "$recorder")"
  classes="$(issues_jsonl_classes "$scratch")"
  rec_content="$(cat "$recorder" 2>/dev/null)"

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(2) N=1: exit 0"
  else
    common_test_fail "(2) N=1: exit 0" "got rc=$rc"
  fi
  if [ "$count" -eq 1 ]; then
    common_test_pass "(2) N=1: exactly 1 stub call"
  else
    common_test_fail "(2) N=1: exactly 1 stub call" "count=$count"
  fi
  if printf '%s' "$rec_content" | grep -qF "$subj" && printf '%s' "$rec_content" | grep -qF "$val"; then
    common_test_pass "(2) N=1: stub call carries the minted subject/value"
  else
    common_test_fail "(2) N=1: stub call carries the minted subject/value" "subj=$subj val=$val rec=$rec_content"
  fi
  if [ -z "$classes" ]; then
    common_test_pass "(2) N=1: no gap row"
  else
    common_test_fail "(2) N=1: no gap row" "classes=$classes"
  fi
}

# =====================================================================================
# Case 3: N == 8 -> exactly 8 stub calls with the fixture's own minted subjects/values, no gap
# row.
# =====================================================================================
{
  mapfile -t _bs < <(build_scratch --with-stub)
  scratch="${_bs[0]}"
  recorder="${_bs[1]}"
  notes="$(mint_notes_json 8)"
  write_return_meta "$scratch" "$notes"
  out="$(STUB_RECORDER="$recorder" run_psn "$scratch" 2>/dev/null)"
  rc=$?
  count="$(stub_call_count "$recorder")"
  classes="$(issues_jsonl_classes "$scratch")"
  rec_content="$(cat "$recorder" 2>/dev/null)"
  all_present="true"
  for ((j = 0; j < 8; j++)); do
    subj="$(printf '%s' "$notes" | jq -r ".[$j].subject")"
    val="$(printf '%s' "$notes" | jq -r ".[$j].value")"
    if ! printf '%s' "$rec_content" | grep -qF "$subj" || ! printf '%s' "$rec_content" | grep -qF "$val"; then
      all_present="false"
    fi
  done

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(3) N=8: exit 0"
  else
    common_test_fail "(3) N=8: exit 0" "got rc=$rc"
  fi
  if [ "$count" -eq 8 ]; then
    common_test_pass "(3) N=8: exactly 8 stub calls"
  else
    common_test_fail "(3) N=8: exactly 8 stub calls" "count=$count"
  fi
  if [ "$all_present" = "true" ]; then
    common_test_pass "(3) N=8: all 8 minted subject/value pairs present"
  else
    common_test_fail "(3) N=8: all 8 minted subject/value pairs present" "notes=$notes"
  fi
  if [ -z "$classes" ]; then
    common_test_pass "(3) N=8: no gap row"
  else
    common_test_fail "(3) N=8: no gap row" "classes=$classes"
  fi
}

# =====================================================================================
# Case 4: N == 12 -> exactly 8 stub calls (ceiling), exactly one "tooling bug or gap" row.
# =====================================================================================
{
  mapfile -t _bs < <(build_scratch --with-stub)
  scratch="${_bs[0]}"
  recorder="${_bs[1]}"
  notes="$(mint_notes_json 12)"
  write_return_meta "$scratch" "$notes"
  out="$(STUB_RECORDER="$recorder" run_psn "$scratch" 2>/dev/null)"
  rc=$?
  count="$(stub_call_count "$recorder")"
  classes="$(issues_jsonl_classes "$scratch")"

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(4) N=12: exit 0"
  else
    common_test_fail "(4) N=12: exit 0" "got rc=$rc"
  fi
  if [ "$count" -eq 8 ]; then
    common_test_pass "(4) N=12: exactly 8 stub calls (ceiling honored)"
  else
    common_test_fail "(4) N=12: exactly 8 stub calls (ceiling honored)" "count=$count"
  fi
  if [ "$(printf '%s\n' "$classes" | grep -cx 'tooling bug or gap')" -eq 1 ] && [ "$(printf '%s\n' "$classes" | grep -c .)" -eq 1 ]; then
    common_test_pass "(4) N=12: exactly one tooling bug or gap row"
  else
    common_test_fail "(4) N=12: exactly one tooling bug or gap row" "classes=$classes"
  fi
}

# =====================================================================================
# Case 5: one stub call fails mid-run within N=4 -> exactly one infrastructure/transport
# unavailable row AND all 4 notes are still attempted (continue-on-failure, not
# abort-on-first-failure).
# =====================================================================================
{
  mapfile -t _bs < <(build_scratch --with-stub)
  scratch="${_bs[0]}"
  recorder="${_bs[1]}"
  notes="$(mint_notes_json 4)"
  write_return_meta "$scratch" "$notes"
  fail_subject="$(printf '%s' "$notes" | jq -r '.[1].subject')"
  out="$(STUB_RECORDER="$recorder" STUB_FAIL_SUBJECT="$fail_subject" run_psn "$scratch" 2>/dev/null)"
  rc=$?
  count="$(stub_call_count "$recorder")"
  classes="$(issues_jsonl_classes "$scratch")"

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(5) mid-run failure: exit 0 (degrade is non-fatal)"
  else
    common_test_fail "(5) mid-run failure: exit 0 (degrade is non-fatal)" "got rc=$rc"
  fi
  if [ "$count" -eq 4 ]; then
    common_test_pass "(5) mid-run failure: all 4 notes attempted (continue-on-failure)"
  else
    common_test_fail "(5) mid-run failure: all 4 notes attempted (continue-on-failure)" "count=$count"
  fi
  if [ "$(printf '%s\n' "$classes" | grep -cx 'infrastructure/transport unavailable')" -eq 1 ] && [ "$(printf '%s\n' "$classes" | grep -c .)" -eq 1 ]; then
    common_test_pass "(5) mid-run failure: exactly one infrastructure/transport unavailable row"
  else
    common_test_fail "(5) mid-run failure: exactly one infrastructure/transport unavailable row" "classes=$classes"
  fi
}

# =====================================================================================
# Case 6: sibling sapience-remember.sh absent -> exit 0, zero stub calls, zero issue rows. An
# unloaded extension is not a knowledge-capture gap.
# =====================================================================================
{
  read -r scratch < <(build_scratch --no-stub)
  notes="$(mint_notes_json 2)"
  write_return_meta "$scratch" "$notes"
  out="$(run_psn "$scratch" 2>/dev/null)"
  rc=$?
  classes="$(issues_jsonl_classes "$scratch")"

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(6) sibling absent: exit 0"
  else
    common_test_fail "(6) sibling absent: exit 0" "got rc=$rc"
  fi
  if [ -z "$classes" ]; then
    common_test_pass "(6) sibling absent: zero issue rows"
  else
    common_test_fail "(6) sibling absent: zero issue rows" "classes=$classes"
  fi
}

# =====================================================================================
# Case 7: a note whose value contains a double quote and a newline arrives at the stub as one
# intact argument.
# =====================================================================================
{
  mapfile -t _bs < <(build_scratch --with-stub)
  scratch="${_bs[0]}"
  recorder="${_bs[1]}"
  tricky_value='line one with a "quote"
line two after a real newline'
  notes="$(jq -n --arg s "mint-subject-$$-tricky-${RANDOM}" --arg v "$tricky_value" '[{"subject": $s, "value": $v}]')"
  write_return_meta "$scratch" "$notes"
  subj="$(printf '%s' "$notes" | jq -r '.[0].subject')"
  out="$(STUB_RECORDER="$recorder" run_psn "$scratch" 2>/dev/null)"
  rc=$?
  rec_content="$(cat "$recorder" 2>/dev/null)"

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(7) quote+newline value: exit 0"
  else
    common_test_fail "(7) quote+newline value: exit 0" "got rc=$rc"
  fi
  if printf '%s' "$rec_content" | grep -qF "$subj"; then
    common_test_pass "(7) quote+newline value: subject reached the stub"
  else
    common_test_fail "(7) quote+newline value: subject reached the stub" "rec=$rec_content"
  fi
  if printf '%s' "$rec_content" | grep -qF 'line one with a "quote"' \
    && printf '%s' "$rec_content" | grep -qF 'line two after a real newline'; then
    common_test_pass "(7) quote+newline value: both lines of the value reached the stub intact"
  else
    common_test_fail "(7) quote+newline value: both lines of the value reached the stub intact" "rec=$rec_content"
  fi
}

# =====================================================================================
# Case 8: --dry-run propagates --dry-run into every stub invocation.
# =====================================================================================
{
  mapfile -t _bs < <(build_scratch --with-stub)
  scratch="${_bs[0]}"
  recorder="${_bs[1]}"
  notes="$(mint_notes_json 3)"
  write_return_meta "$scratch" "$notes"
  out="$(STUB_RECORDER="$recorder" run_psn "$scratch" --dry-run 2>/dev/null)"
  rc=$?
  dry_run_flag_count="$(grep -cx -- '--dry-run' "$recorder" 2>/dev/null)" || true
  dry_run_flag_count="${dry_run_flag_count:-0}"
  dry_run_output_count="$(printf '%s\n' "$out" | grep -c '^dry-run-output for ')" || true
  dry_run_output_count="${dry_run_output_count:-0}"

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(8) --dry-run: exit 0"
  else
    common_test_fail "(8) --dry-run: exit 0" "got rc=$rc"
  fi
  if [ "$dry_run_flag_count" -eq 3 ]; then
    common_test_pass "(8) --dry-run: propagated into all 3 stub invocations"
  else
    common_test_fail "(8) --dry-run: propagated into all 3 stub invocations" "count=$dry_run_flag_count"
  fi
  if [ "$dry_run_output_count" -eq 3 ]; then
    common_test_pass "(8) --dry-run: stub's dry-run output surfaced for all 3 notes"
  else
    common_test_fail "(8) --dry-run: stub's dry-run output surfaced for all 3 notes" "out=$out"
  fi
}

# =====================================================================================
# Case 9: a missing or malformed .return-meta.json is treated as N == 0 (one gap row, exit 0),
# not a crash.
# =====================================================================================
{
  mapfile -t _bs < <(build_scratch --with-stub)
  scratch="${_bs[0]}"
  recorder="${_bs[1]}"
  rm -f "$scratch/specs/$DEMO_TASK_DIR_NAME/.return-meta.json"
  out="$(STUB_RECORDER="$recorder" run_psn "$scratch" 2>/dev/null)"
  rc=$?
  count="$(stub_call_count "$recorder")"
  classes="$(issues_jsonl_classes "$scratch")"

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(9a) missing .return-meta.json: exit 0"
  else
    common_test_fail "(9a) missing .return-meta.json: exit 0" "got rc=$rc"
  fi
  if [ "$count" -eq 0 ]; then
    common_test_pass "(9a) missing .return-meta.json: zero stub calls"
  else
    common_test_fail "(9a) missing .return-meta.json: zero stub calls" "count=$count"
  fi
  if [ "$(printf '%s\n' "$classes" | grep -cx 'knowledge-capture gap')" -eq 1 ]; then
    common_test_pass "(9a) missing .return-meta.json: exactly one knowledge-capture gap row"
  else
    common_test_fail "(9a) missing .return-meta.json: exactly one knowledge-capture gap row" "classes=$classes"
  fi
}
{
  mapfile -t _bs < <(build_scratch --with-stub)
  scratch="${_bs[0]}"
  recorder="${_bs[1]}"
  printf '{not valid json' > "$scratch/specs/$DEMO_TASK_DIR_NAME/.return-meta.json"
  out="$(STUB_RECORDER="$recorder" run_psn "$scratch" 2>/dev/null)"
  rc=$?
  count="$(stub_call_count "$recorder")"
  classes="$(issues_jsonl_classes "$scratch")"

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(9b) malformed .return-meta.json: exit 0"
  else
    common_test_fail "(9b) malformed .return-meta.json: exit 0" "got rc=$rc"
  fi
  if [ "$count" -eq 0 ]; then
    common_test_pass "(9b) malformed .return-meta.json: zero stub calls"
  else
    common_test_fail "(9b) malformed .return-meta.json: zero stub calls" "count=$count"
  fi
  if [ "$(printf '%s\n' "$classes" | grep -cx 'knowledge-capture gap')" -eq 1 ]; then
    common_test_pass "(9b) malformed .return-meta.json: exactly one knowledge-capture gap row"
  else
    common_test_fail "(9b) malformed .return-meta.json: exactly one knowledge-capture gap row" "classes=$classes"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
