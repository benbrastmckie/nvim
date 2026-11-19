#!/usr/bin/env bash
# test-unmapped-fallback-lib.sh - Narrow, fixture-driven suite for
# scripts/lib/unmapped-fallback-lib.sh's three public functions.
#
# The library's two load-bearing invariants are asserted here directly, because a regression in
# either silently weakens verification coverage rather than failing loudly:
#
#   NEVER SILENT  -- every input path produces exactly one classification line. A path that
#                    vanished between input and output would be an unmapped path nobody pays for.
#   OWED IS NEVER FORGIVEN -- an owed row is appended, never deleted, and never duplicated while
#                    an OPEN row for the same path exists. The only sanctioned mutation is the
#                    discharge stamp, which belongs to the batch gate and is not exercised here.
#
# Fixtures use a per-case $WORKDIR task dir and a planted noclass data file steered through
# UNMAPPED_FALLBACK_NOCLASS_DATA, so the suite never reads the real checked-in data file (whose
# rows are expected to change) and never writes real task state.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LIB_UNDER_TEST="$(common_test_resolve_subject "unmapped-fallback-lib.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/unmapped-fallback-lib.sh" \
  "$SCRIPT_DIR/../lib/unmapped-fallback-lib.sh")" || exit 2
common_test_declare_subject "$LIB_UNDER_TEST"

PASSED=0
FAILED=0
common_test_workdir_init

# shellcheck source=/dev/null
source "$LIB_UNDER_TEST"

if ! command -v jq >/dev/null 2>&1; then
  common_test_info "jq unavailable; owed-record cases would exercise only the fail-open warning path"
fi

# A planted noclass fixture: TAB-separated <glob> <lints> <reason>.
NOCLASS="${WORKDIR}/noclass.data"
printf '%s\n' \
  '# comment row must be skipped' \
  '' \
  'docs/*.md	lint-markdown.sh	prose under docs cannot change a suite verdict' \
  '*.txt	lint-trailing-whitespace.sh,lint-eol.sh	records file read only by corpus-wide lints' \
  'specs/**	lint-records.sh	task records' \
  > "$NOCLASS"
export UNMAPPED_FALLBACK_NOCLASS_DATA="$NOCLASS"

owed_file() { printf '%s\n' "$1/records/full-sweep-owed.jsonl"; }

# --- unmapped_fallback_cost_class -------------------------------------------------------------

out="$(unmapped_fallback_cost_class)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "free" ]; then
  common_test_pass "cost_class: defaults to 'free'"
else
  common_test_fail "cost_class: defaults to 'free' (got rc=$rc out='$out')"
fi

out="$(UNMAPPED_FALLBACK_COST_CLASS=cheap bash -c \
  'source "$1"; unmapped_fallback_cost_class' _ "$LIB_UNDER_TEST")"
if [ "$out" = "cheap" ]; then
  common_test_pass "cost_class: honours an inherited UNMAPPED_FALLBACK_COST_CLASS override"
else
  common_test_fail "cost_class: override not honoured (got '$out')"
fi

# --- unmapped_fallback_classify: NO-SUITE-BY-CLASS --------------------------------------------

task_dir="${WORKDIR}/t-class"; mkdir -p "$task_dir"
out="$(unmapped_fallback_classify "$task_dir" sess_x 1 "docs/guide.md")"; rc=$?
expected="$(printf 'NO-SUITE-BY-CLASS\tdocs/guide.md\tlint-markdown.sh')"
if [ "$rc" -eq 0 ] && [ "$out" = "$expected" ]; then
  common_test_pass "classify: a class-matched path yields NO-SUITE-BY-CLASS with its lints"
else
  common_test_fail "classify: class-matched path (rc=$rc)"
  common_test_info "expected: $(printf '%q' "$expected")"
  common_test_info "actual:   $(printf '%q' "$out")"
fi

if [ ! -f "$(owed_file "$task_dir")" ]; then
  common_test_pass "classify: a NO-SUITE-BY-CLASS path writes NO owed record"
else
  common_test_fail "classify: a NO-SUITE-BY-CLASS path wrote an owed record it does not owe"
fi

out="$(unmapped_fallback_classify "$task_dir" sess_x 1 "notes.txt")"
expected="$(printf 'NO-SUITE-BY-CLASS\tnotes.txt\tlint-trailing-whitespace.sh,lint-eol.sh')"
if [ "$out" = "$expected" ]; then
  common_test_pass "classify: multi-lint class row returns the full comma-separated list"
else
  common_test_fail "classify: multi-lint class row"
  common_test_info "actual: $(printf '%q' "$out")"
fi

out="$(unmapped_fallback_classify "$task_dir" sess_x 1 "# comment row must be skipped")"
case "$out" in
  OWED*) common_test_pass "classify: a '#' row is a comment, never a matchable glob" ;;
  *) common_test_fail "classify: a '#' comment row was treated as a glob"; common_test_info "actual: $(printf '%q' "$out")" ;;
esac

# --- unmapped_fallback_classify: OWED ---------------------------------------------------------

task_dir="${WORKDIR}/t-owed"; mkdir -p "$task_dir"
out="$(unmapped_fallback_classify "$task_dir" sess_owed 7 "AGENTS.md")"; rc=$?
case "$out" in
  "OWED	AGENTS.md	"*) common_test_pass "classify: an unmatched path yields OWED with a stated reason" ;;
  *) common_test_fail "classify: unmatched path (rc=$rc)"; common_test_info "actual: $(printf '%q' "$out")" ;;
esac

case "$out" in
  *"--cost-class free"*) common_test_pass "classify: the OWED reason names the cost-class fallback set it ran" ;;
  *) common_test_fail "classify: OWED reason does not name the fallback set" ;;
esac

if command -v jq >/dev/null 2>&1; then
  f="$(owed_file "$task_dir")"
  if [ -f "$f" ] && [ "$(wc -l < "$f")" -eq 1 ]; then
    common_test_pass "classify: an OWED path appends exactly one owed row"
  else
    common_test_fail "classify: expected exactly one owed row, found $( [ -f "$f" ] && wc -l < "$f" || echo 0)"
  fi

  row="$(head -1 "$f")"
  if echo "$row" | jq -e '.path == "AGENTS.md" and .session_id == "sess_owed" and .dispatch_seq == 7 and .discharged_ts == null and (.recorded_ts | type == "string")' >/dev/null 2>&1; then
    common_test_pass "classify: the owed row carries path/session/dispatch_seq, open discharge, and a timestamp"
  else
    common_test_fail "classify: owed row field shape"
    common_test_info "row: $row"
  fi

  # Idempotence: re-classifying the same path while an OPEN row exists must not duplicate it.
  unmapped_fallback_classify "$task_dir" sess_owed 8 "AGENTS.md" >/dev/null
  if [ "$(wc -l < "$f")" -eq 1 ]; then
    common_test_pass "classify: re-classifying a path with an OPEN row is a no-op (no duplicate)"
  else
    common_test_fail "classify: re-classification duplicated an OPEN owed row ($(wc -l < "$f") rows)"
  fi

  # A DISCHARGED row must not suppress a fresh owed row for the same path: the debt recurs.
  jq -c '.discharged_ts = "2026-01-01T00:00:00Z"' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
  unmapped_fallback_classify "$task_dir" sess_owed 9 "AGENTS.md" >/dev/null
  if [ "$(wc -l < "$f")" -eq 2 ]; then
    common_test_pass "classify: a path whose only row is DISCHARGED earns a new owed row"
  else
    common_test_fail "classify: discharged row did not permit a fresh owed row ($(wc -l < "$f") rows)"
  fi

  # Append-only: nothing above may have removed the discharged row.
  if [ "$(jq -s '[.[] | select(.discharged_ts != null)] | length' "$f")" -eq 1 ]; then
    common_test_pass "classify: owed records are append-only (the discharged row survives)"
  else
    common_test_fail "classify: the discharged row was mutated or removed"
  fi

  # record_owed creates records/ when absent.
  fresh="${WORKDIR}/t-fresh"; mkdir -p "$fresh"
  unmapped_fallback_record_owed "$fresh" "x/y.bin" "direct call" sess_d 3
  if [ -f "$(owed_file "$fresh")" ]; then
    common_test_pass "record_owed: creates records/ and the JSONL file when neither exists"
  else
    common_test_fail "record_owed: did not create records/full-sweep-owed.jsonl"
  fi
fi

# --- NEVER SILENT: one line in, one line out, order preserved ---------------------------------

task_dir="${WORKDIR}/t-mixed"; mkdir -p "$task_dir"
out="$(unmapped_fallback_classify "$task_dir" sess_m 1 \
  "docs/a.md" "AGENTS.md" "notes.txt" "src/thing.c" "specs/033/report.md")"
line_count="$(printf '%s\n' "$out" | grep -c .)"
if [ "$line_count" -eq 5 ]; then
  common_test_pass "classify: 5 input paths produce exactly 5 output lines (never silent)"
else
  common_test_fail "classify: expected 5 output lines, got $line_count"
  common_test_info "actual: $(printf '%q' "$out")"
fi

first_fields="$(printf '%s\n' "$out" | cut -f1 | tr '\n' ' ')"
if [ "$first_fields" = "NO-SUITE-BY-CLASS OWED NO-SUITE-BY-CLASS OWED NO-SUITE-BY-CLASS " ]; then
  common_test_pass "classify: verdicts are per-path and returned in input order"
else
  common_test_fail "classify: verdict order/content wrong: '$first_fields'"
fi

out="$(unmapped_fallback_classify "$task_dir" sess_m 1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
  common_test_pass "classify: zero paths is a silent no-op returning 0"
else
  common_test_fail "classify: zero-path call (rc=$rc out='$out')"
fi

# A path matching two globs takes the FIRST matching row, per _umf_noclass_lookup's contract.
out="$(unmapped_fallback_classify "$task_dir" sess_m 1 "specs/033/notes.txt")"
case "$out" in
  *"lint-trailing-whitespace.sh,lint-eol.sh"*) common_test_pass "classify: first matching class row wins over a later one" ;;
  *) common_test_fail "classify: first-match precedence"; common_test_info "actual: $(printf '%q' "$out")" ;;
esac

# --- sourcing posture -------------------------------------------------------------------------

opts_before="$(set +o)"
# shellcheck source=/dev/null
source "$LIB_UNDER_TEST"
opts_after="$(set +o)"
if [ "$opts_before" = "$opts_after" ]; then
  common_test_pass "sourcing the library changes no shell option in the caller"
else
  common_test_fail "sourcing the library changed the caller's shell options"
fi

echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
