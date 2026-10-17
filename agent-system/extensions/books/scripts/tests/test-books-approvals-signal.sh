#!/usr/bin/env bash
# test-books-approvals-signal.sh - Narrow, fixture-driven suite for books-approvals-signal.sh.
#
# Per context/standards/shell-script-testing.md: fixtures are constructed inline via a mktemp -d
# workdir created at suite start; nothing here depends on the external Logos/Verification
# repository or on any real specs/ tree. Class B strict mode (this is a PASSED/FAILED-counter
# harness that must report every case, not abort on the first failure).
#
# Every recognized/excluded message string below is copied VERBATIM from
# context/project/books/domain/approvals-detection.md's pinned signature (read 2026-10-17 from
# the external repository's check-approvals.sh), not invented here.
#
# FORGERY PROBES. Per context/project/books/standards/forgery-probe-discipline.md, every
# predicate this suite relies on carries a probe that stubs the predicate out (a mutated COPY of
# the script under test, never the original) and asserts that the SAME case the suite trusts
# then FAILS. A test that would pass against a stubbed predicate proves nothing.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="${SCRIPT_DIR}/../books-approvals-signal.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [[ ! -x "$WRAPPER" ]]; then
  fail "prerequisite: $WRAPPER is not executable (or does not exist)"
  echo ""
  echo "$PASSED passed, $FAILED failed"
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "test-books-approvals-signal.sh: jq is required to read the recognizer's JSON output" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# The CLI's --task flag takes an arbitrary integer scope identifier -- it names no real task in
# this or any other repository's task-management system. "7" is used throughout below as a
# stand-in value. (task-ref-ok: test fixture -- an arbitrary CLI argument value, not a citation
# of any real task.)
FIXTURE_TASK_SCOPE=7

# ─── Helpers ────────────────────────────────────────────────────────────────────────────────────

# run_recognizer FIXTURE_FILE [EXTRA_ARGS...]
#   Runs the real recognizer against FIXTURE_FILE with --component framed_channel, captures
#   stdout and exit code into globals RC and OUT.
run_recognizer() {
  local fixture="$1"; shift
  OUT="$("$WRAPPER" --gate-output "$fixture" --component framed_channel "$@" 2>/dev/null)"
  RC=$?
}

# assert_exit CASE_NAME EXPECTED_EXIT ACTUAL_EXIT
assert_exit() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    pass "${name}: exit code ${actual} (expected ${expected})"
  else
    fail "${name}: exit code ${actual}, expected ${expected}"
  fi
}

# assert_empty CASE_NAME ACTUAL
assert_empty() {
  local name="$1" actual="$2"
  if [[ -z "$actual" ]]; then
    pass "${name}: stdout is empty, as expected"
  else
    fail "${name}: stdout is NOT empty: ${actual}"
  fi
}

# dir_digest DIR -- a stable content+structure digest of a fixture tree, used to assert the
# recognizer created/modified/deleted nothing under it.
dir_digest() {
  find "$1" -type f -exec sha256sum {} + 2>/dev/null | LC_ALL=C sort | sha256sum | awk '{print $1}'
}

# ─── Positive recognition: one case per recognized family (D2) ─────────────────────────────────
info "Positive recognition: the six recognized absent-or-stale families"

fam1="${WORKDIR}/fam1.txt"
printf '[FAIL] approvals: data/approvals.json does not exist. No selection or specification has been approved.\n' > "$fam1"
run_recognizer "$fam1"
assert_exit "fam1-exit" 0 "$RC"
echo "$OUT" | jq -e . >/dev/null 2>&1 && pass "fam1-jq-parseable" || fail "fam1-jq-parseable: not valid JSON: $OUT"

fam2="${WORKDIR}/fam2.txt"
printf '[FAIL] approvals: no selection record (the selection has not been approved)\n' > "$fam2"
run_recognizer "$fam2"
assert_exit "fam2-exit" 0 "$RC"

fam3="${WORKDIR}/fam3.txt"
printf '[FAIL] approvals: the selection is stale: the Rust changed since it was approved (source_sha256 recorded abc, now def)\n' > "$fam3"
run_recognizer "$fam3"
assert_exit "fam3-exit" 0 "$RC"

fam4="${WORKDIR}/fam4.txt"
printf '[FAIL] approvals: the selection is stale: the candidate set changed since it was approved (candidates_sha256 recorded abc, now def)\n' > "$fam4"
run_recognizer "$fam4"
assert_exit "fam4-exit" 0 "$RC"

fam5="${WORKDIR}/fam5.txt"
printf '[FAIL] approvals: the specification Spec.Foo is stale: it changed since it was approved (spec_digest recorded abc, now def)\n' > "$fam5"
run_recognizer "$fam5"
assert_exit "fam5-exit" 0 "$RC"

fam6="${WORKDIR}/fam6.txt"
printf '[FAIL] approvals: no specification record for Spec.Foo (its current spec_digest is abc123): it has not been approved\n' > "$fam6"
run_recognizer "$fam6" --task "$FIXTURE_TASK_SCOPE"
assert_exit "fam6-exit" 0 "$RC"

# ─── Negative non-recognition: one case per excluded family, plus green/usage-error fixtures ──
info "Negative non-recognition: excluded families, a green gate, a usage error"

excl_cases=(
  "excl-malformed|[FAIL] approvals: the by record for Spec.Foo is malformed"
  "excl-both|[FAIL] approvals: Spec.Foo is both selected and declined"
  "excl-dup|[FAIL] approvals: Spec.Foo is listed more than once"
  "excl-neither|[FAIL] approvals: Spec.Foo is neither selected nor declined"
  "excl-not-in-subset|[FAIL] approvals: Spec.Foo is selected or declined but is not an in-subset candidate"
  "excl-no-statement|[FAIL] approvals: Spec.Foo selected, but no registered statement is about it"
  "excl-not-selected|[FAIL] approvals: Spec.Foo specified in the manifest but not selected"
  "excl-empty-reason|[FAIL] approvals: Spec.Foo declined with an empty reason"
  "excl-not-challenge|[FAIL] approvals: Spec.Foo names Helper.Bar, which is not a Challenge module"
  "excl-no-digest|[FAIL] approvals: SpecCheck reports no digest for it"
  "excl-bad-shape|[FAIL] approvals: the approvals file does not have the recorded shape"
  "excl-specchk-failed|[FAIL] approvals: spec-check.sh failed"
  "excl-require-person|[FAIL] approvals: Spec.Foo was approved by an agent (ci-bot), and --require-person is set"
)
for case_spec in "${excl_cases[@]}"; do
  case_name="${case_spec%%|*}"
  case_text="${case_spec#*|}"
  fx="${WORKDIR}/${case_name}.txt"
  printf '%s\n' "$case_text" > "$fx"
  run_recognizer "$fx"
  assert_exit "${case_name}-exit" 1 "$RC"
  assert_empty "${case_name}-stdout" "$OUT"
done

green="${WORKDIR}/green.txt"
printf '== approvals ==\n[ok] all approval records current\n' > "$green"
run_recognizer "$green"
assert_exit "green-gate-exit" 1 "$RC"
assert_empty "green-gate-stdout" "$OUT"

usage_err="${WORKDIR}/usage.txt"
printf 'check-approvals.sh: usage: check-approvals.sh --root DIR [--require-person]\n' > "$usage_err"
run_recognizer "$usage_err"
assert_exit "usage-error-exit" 1 "$RC"
assert_empty "usage-error-stdout" "$OUT"

# ─── Shape assertions ───────────────────────────────────────────────────────────────────────────
info "Shape assertions on a recognized object"

run_recognizer "$fam6" --task "$FIXTURE_TASK_SCOPE"
n_options=$(echo "$OUT" | jq '.options | length')
[[ "$n_options" -eq 3 ]] && pass "shape-exactly-3-options" || fail "shape-exactly-3-options: got ${n_options}"

blocking_val=$(echo "$OUT" | jq -r '.blocking')
[[ "$blocking_val" == "false" ]] && pass "shape-blocking-false" || fail "shape-blocking-false: got ${blocking_val}"

opt2=$(echo "$OUT" | jq -r '.options[1]')
recommended=$(echo "$OUT" | jq -r '.recommended')
[[ "$opt2" == "$recommended" ]] && pass "shape-recommended-is-defer" || fail "shape-recommended-is-defer: recommended='${recommended}' options[1]='${opt2}'"

echo "$OUT" | jq -r '.options[0]' | grep -q 'framed_channel' && pass "shape-component-in-option-text" || fail "shape-component-in-option-text"
echo "$OUT" | jq -r '.options[0]' | grep -q "$FIXTURE_TASK_SCOPE" && pass "shape-task-scope-in-option-text" || fail "shape-task-scope-in-option-text"

# Fallback: when the deployed /approve surface is absent, option 1 names the component's own
# approve.sh lines instead.
emptyroot="${WORKDIR}/empty-root"
mkdir -p "$emptyroot"
(cd "$emptyroot" && git init -q)
run_recognizer "$fam6" --root "$emptyroot"
echo "$OUT" | jq -r '.options[0]' | grep -q 'approve.sh' && pass "shape-fallback-names-approve-sh" || fail "shape-fallback-names-approve-sh: ${OUT}"
echo "$OUT" | jq -r '.options[0]' | grep -qv '^/approve ' && pass "shape-fallback-does-not-name-slash-approve" || fail "shape-fallback-does-not-name-slash-approve"

# ─── Decline leaves the requirement intact; defer does not consume the need ────────────────────
info "Decline/defer: the same offer re-emits; .decisions.json is never read; nothing is written"

decline_dir="${WORKDIR}/decline-fixture"
mkdir -p "$decline_dir"
cp "$fam6" "${decline_dir}/gate-output.txt"
cat > "${decline_dir}/.decisions.json" <<'EOF'
[{"question": "framed_channel's approval records are absent or stale", "answer": "Decline — leave framed_channel's approval records as-is; the gate leg stays red"}]
EOF
before_digest="$(dir_digest "$decline_dir")"
run_recognizer "${decline_dir}/gate-output.txt" --task "$FIXTURE_TASK_SCOPE"
first_question="$(echo "$OUT" | jq -r '.question')"
assert_exit "decline-first-run-exit" 0 "$RC"

# Second run: same fixture, same recorded decline present. The recognizer must re-emit the SAME
# offer -- a decline does not consume or suppress the need.
run_recognizer "${decline_dir}/gate-output.txt" --task "$FIXTURE_TASK_SCOPE"
second_question="$(echo "$OUT" | jq -r '.question')"
[[ "$first_question" == "$second_question" ]] && pass "decline-reemits-same-offer" || fail "decline-reemits-same-offer: '${first_question}' vs '${second_question}'"

# Make .decisions.json unreadable (chmod 000) and assert behaviour is unchanged -- the recognizer
# never reads that file at all, so an unreadable one must not matter.
chmod 000 "${decline_dir}/.decisions.json" 2>/dev/null || true
run_recognizer "${decline_dir}/gate-output.txt" --task "$FIXTURE_TASK_SCOPE"
third_question="$(echo "$OUT" | jq -r '.question')"
chmod 644 "${decline_dir}/.decisions.json" 2>/dev/null || true
[[ "$first_question" == "$third_question" ]] && pass "decline-unreadable-decisions-file-no-effect" || fail "decline-unreadable-decisions-file-no-effect"

after_digest="$(dir_digest "$decline_dir")"
[[ "$before_digest" == "$after_digest" ]] && pass "decline-fixture-tree-unchanged" || fail "decline-fixture-tree-unchanged: digest changed (${before_digest} -> ${after_digest})"

# Same three assertions, for a recorded DEFER answer.
defer_dir="${WORKDIR}/defer-fixture"
mkdir -p "$defer_dir"
cp "$fam6" "${defer_dir}/gate-output.txt"
cat > "${defer_dir}/.decisions.json" <<'EOF'
[{"question": "framed_channel's approval records are absent or stale", "answer": "Defer — ask again on the next run that hits this red"}]
EOF
before_digest_d="$(dir_digest "$defer_dir")"
run_recognizer "${defer_dir}/gate-output.txt" --task "$FIXTURE_TASK_SCOPE"
d_first="$(echo "$OUT" | jq -r '.question')"
run_recognizer "${defer_dir}/gate-output.txt" --task "$FIXTURE_TASK_SCOPE"
d_second="$(echo "$OUT" | jq -r '.question')"
[[ "$d_first" == "$d_second" ]] && pass "defer-reemits-same-offer" || fail "defer-reemits-same-offer"
chmod 000 "${defer_dir}/.decisions.json" 2>/dev/null || true
run_recognizer "${defer_dir}/gate-output.txt" --task "$FIXTURE_TASK_SCOPE"
d_third="$(echo "$OUT" | jq -r '.question')"
chmod 644 "${defer_dir}/.decisions.json" 2>/dev/null || true
[[ "$d_first" == "$d_third" ]] && pass "defer-unreadable-decisions-file-no-effect" || fail "defer-unreadable-decisions-file-no-effect"
after_digest_d="$(dir_digest "$defer_dir")"
[[ "$before_digest_d" == "$after_digest_d" ]] && pass "defer-fixture-tree-unchanged" || fail "defer-fixture-tree-unchanged"

# ─── No self-answering: the recognizer's own source invokes nothing ────────────────────────────
info "No self-answering: source-level structural assertion"

forbidden_tokens=(approve.sh '/approve' check-approvals.sh full-gate.sh check.sh AskUserQuestion)
self_answer_violation=0
# The recognizer legitimately NAMES these tool/command names as literal text it builds for the
# user to read (the relayed option strings, and the stage-attribution line it searches for) --
# that is the whole point of the feature. What must never appear is an actual INVOCATION: the
# token used as a real subprocess command rather than as string-literal content. Since every
# legitimate mention in the real script lives inside a single- or double-quoted string literal,
# stripping quoted string CONTENTS first and then searching the remainder isolates genuine
# invocation syntax from mere mention.
strip_quoted_contents() {
  sed -E 's/"[^"]*"//g; s/'"'"'[^'"'"']*'"'"'//g'
}
for tok in "${forbidden_tokens[@]}"; do
  if grep -vE '^\s*#' "$WRAPPER" | strip_quoted_contents | grep -qF -- "$tok"; then
    self_answer_violation=1
    fail "no-self-answer: executable code references forbidden token '${tok}' OUTSIDE any string literal (looks like a real invocation)"
  fi
done
[[ "$self_answer_violation" -eq 0 ]] && pass "no-self-answer: every mention of a forbidden token lives inside a string literal; none is a real invocation"

# Write-redirection check: `2>/dev/null` (discard) and `>&N` (fd duplication, e.g. stderr) are
# both safe and are NOT a write to a real path; strip those known-safe forms and check whether
# any `>` redirection remains.
redirect_remainder="$(grep -vE '^\s*#' "$WRAPPER" | sed -E 's#>[[:space:]]*/dev/null##g; s#>&[0-9]##g')"
if printf '%s' "$redirect_remainder" | grep -qE '>'; then
  fail "no-self-answer: executable code contains a write redirection outside stdout/stderr/devnull"
else
  pass "no-self-answer: no write redirection found outside stdout/stderr/devnull"
fi

# ─── Forgery probes ─────────────────────────────────────────────────────────────────────────────
# Each probe mutates a COPY of the script (never the original) to stub out one predicate, then
# re-runs the SAME case the suite above trusts and asserts that case's expectation now FAILS.
info "Forgery probes: each predicate, stubbed in a copy, must break its own case"

make_stub() {
  # make_stub OUT_PATH UNIQUE_SUBSTRING -- copies $WRAPPER to OUT_PATH with the line containing
  # UNIQUE_SUBSTRING replaced by a no-op `false` guard, breaking that one predicate only.
  local out="$1" needle="$2"
  awk -v needle="$needle" '
    index($0, needle) > 0 { print "  if false; then # stubbed by forgery probe"; next }
    { print }
  ' "$WRAPPER" > "$out"
  chmod +x "$out"
}

# Probe 1: family-6 recognition predicate stubbed. The real fam6 case expects exit 0; stubbed,
# it must not.
probe_fam6="${WORKDIR}/probe-fam6.sh"
make_stub "$probe_fam6" 'no specification record for'
probe_fam6_rc=0
"$probe_fam6" --gate-output "$fam6" --component framed_channel >/dev/null 2>&1 || probe_fam6_rc=$?
if [[ "$probe_fam6_rc" -eq 0 ]]; then
  fail "probe-fam6-recognition: stubbing the family-6 predicate still produced exit 0 -- the case does not bind the predicate"
else
  pass "probe-fam6-recognition: stubbing the family-6 predicate breaks the case (got exit ${probe_fam6_rc}, real case expects 0)"
fi

# Probe 2: family-2 recognition predicate stubbed (distinct family, same discipline).
probe_fam2="${WORKDIR}/probe-fam2.sh"
make_stub "$probe_fam2" 'no selection record (the selection has not been approved)'
probe_fam2_rc=0
"$probe_fam2" --gate-output "$fam2" --component framed_channel >/dev/null 2>&1 || probe_fam2_rc=$?
if [[ "$probe_fam2_rc" -eq 0 ]]; then
  fail "probe-fam2-recognition: stubbing the family-2 predicate still produced exit 0"
else
  pass "probe-fam2-recognition: stubbing the family-2 predicate breaks the case (got exit ${probe_fam2_rc})"
fi

# Probe 3: excluded-family rejection predicate stubbed out entirely (the whole exclusion loop's
# own grep test disabled). Without it, excluded_hit can never become true, so the mixed-red
# fixture (a recognized family PLUS an excluded family in the same capture) must lose its
# "other approvals failures are also present" clause.
probe_excl="${WORKDIR}/probe-excl.sh"
# shellcheck disable=SC2016  # intentional: matching the literal source text in $WRAPPER, not expanding
make_stub "$probe_excl" 'grep -qE "$pat"'
mixed="${WORKDIR}/mixed.txt"
printf '%s\n%s\n' \
  '[FAIL] approvals: no specification record for Spec.Foo (its current spec_digest is abc123): it has not been approved' \
  '[FAIL] approvals: spec-check.sh failed' > "$mixed"
real_mixed_out="$("$WRAPPER" --gate-output "$mixed" --component framed_channel 2>/dev/null)"
real_mixed_has_clause="$(echo "$real_mixed_out" | jq -r '.question' | grep -c 'Other approvals failures are also present' || true)"
stub_mixed_out="$("$probe_excl" --gate-output "$mixed" --component framed_channel 2>/dev/null)"
stub_mixed_has_clause="$(echo "$stub_mixed_out" | jq -r '.question' | grep -c 'Other approvals failures are also present' || true)"
if [[ "$real_mixed_has_clause" -ge 1 ]] && [[ "$stub_mixed_has_clause" -eq 0 ]]; then
  pass "probe-excluded-rejection: stubbing the exclusion-match predicate removes the mixed-red clause (real has it, stub does not)"
else
  fail "probe-excluded-rejection: expected real=has-clause, stub=no-clause; got real_count=${real_mixed_has_clause} stub_count=${stub_mixed_has_clause}"
fi

# Probe 4: shape assertion (blocking:false). Mutate a copy to always emit blocking:true, and
# assert the suite's OWN shape check (re-applied to the mutated output) correctly reports it as
# wrong, i.e. the predicate the shape-assertion depends on is not vacuously satisfied.
probe_blocking="${WORKDIR}/probe-blocking.sh"
awk '{ gsub(/"blocking": false/, "\"blocking\": true"); print }' "$WRAPPER" > "$probe_blocking"
chmod +x "$probe_blocking"
probe_blocking_out="$("$probe_blocking" --gate-output "$fam6" --component framed_channel --task "$FIXTURE_TASK_SCOPE" 2>/dev/null)"
probe_blocking_val="$(echo "$probe_blocking_out" | jq -r '.blocking')"
if [[ "$probe_blocking_val" == "false" ]]; then
  fail "probe-shape-blocking: mutated script still reported blocking=false -- the shape case does not bind this field"
else
  pass "probe-shape-blocking: the shape assertion correctly distinguishes the mutated output (got '${probe_blocking_val}')"
fi

# Probe 5: read-only structural assertion. Inject a forbidden invocation into a copy and assert
# the suite's own detector (re-applied to the mutated copy) correctly flags it -- proving the
# grep-based detector is not vacuously matching nothing.
probe_readonly="${WORKDIR}/probe-readonly.sh"
cp "$WRAPPER" "$probe_readonly"
printf '\nbash approve.sh --record\n' >> "$probe_readonly"
chmod +x "$probe_readonly"
if grep -vE '^\s*#' "$probe_readonly" | strip_quoted_contents | grep -qF 'approve.sh'; then
  pass "probe-readonly-detector: injecting a bare (unquoted) forbidden invocation into a copy is correctly detected by the same strip-quotes mechanism the real check above uses"
else
  fail "probe-readonly-detector: the injected forbidden invocation was NOT detected -- the structural check is vacuous"
fi

info "Suite complete"

echo ""
echo "$PASSED passed, $FAILED failed"
if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
if [[ "$PASSED" -eq 0 ]]; then
  echo "test-books-approvals-signal.sh: zero cases ran -- this is a harness failure, not a pass." >&2
  exit 2
fi
exit 0
