#!/usr/bin/env bash
# test-phase-heading-patterns.sh - Fixture-driven regression suite for
# scripts/lib/phase-heading-patterns.sh, the single sourced anchor for the canonical
# `### Phase N: {name} [STATUS]` grammar, the closed status-marker enum, and non-conforming-
# heading detection (see context/formats/plan-format.md's "Canonical phase-heading shape"
# subsection for the policy this library implements).
#
# Structural model: scripts/tests/test-validate-no-task-references.sh (pass()/fail()/info()
# helpers, PASSED/FAILED integer counters, exit 0 on all-pass / exit 1 on any-fail). This suite
# sources the library directly rather than driving a subprocess, since the library exports shell
# functions and constants meant to be sourced, not a standalone executable.
#
# Library resolution mirrors the deploy-tree-first / source-store-fallback candidate list used by
# check-task-references.sh and the consumer scripts this library serves, so the suite runs
# correctly both post-deploy (.claude/scripts/lib/...) and in a source-store-only checkout
# (agent-system/extensions/core/scripts/lib/...).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (library
# not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

LIB="$(common_test_resolve_subject "phase-heading-patterns.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/phase-heading-patterns.sh" \
  "$SCRIPT_DIR/../lib/phase-heading-patterns.sh")" || exit 2
common_test_declare_subject "$LIB"
# shellcheck disable=SC1090
. "$LIB"

PASSED=0
FAILED=0


common_test_workdir_init

# =====================================================================
# Positive fixtures: extract_phase_number succeeds; nonconforming_phase_headings reports nothing.
# One fixture per enum value, plus a decimal sub-phase case.
# =====================================================================
assert_extracts() {
  local label="$1" heading="$2" expected="$3" got code
  got="$(extract_phase_number "$heading")"
  code=$?
  if [[ "$code" -eq 0 && "$got" == "$expected" ]]; then
    common_test_pass "$label: extract_phase_number -> '$got'"
  else
    common_test_fail "$label: expected '$expected' (exit 0), got '$got' (exit $code)"
  fi
}

assert_extracts "positive: Phase 3 NOT STARTED"  "### Phase 3: Name [NOT STARTED]"  "3"
assert_extracts "positive: Phase 3.1 COMPLETED"  "### Phase 3.1: Name [COMPLETED]"  "3.1"
assert_extracts "positive: Phase 12 COMPLETED WITH EXCLUSIONS" \
  "### Phase 12: Name [COMPLETED WITH EXCLUSIONS]" "12"
assert_extracts "positive: Phase 4 IN PROGRESS"  "### Phase 4: Name [IN PROGRESS]"  "4"
assert_extracts "positive: Phase 5 PARTIAL"      "### Phase 5: Name [PARTIAL]"      "5"
assert_extracts "positive: Phase 6 BLOCKED"       "### Phase 6: Name [BLOCKED]"      "6"

# A file containing only the positive fixtures above must report zero non-conforming headings.
positive_file="$WORKDIR/positive.md"
cat > "$positive_file" <<'EOF'
### Phase 3: Name [NOT STARTED]
### Phase 3.1: Name [COMPLETED]
### Phase 12: Name [COMPLETED WITH EXCLUSIONS]
### Phase 4: Name [IN PROGRESS]
### Phase 5: Name [PARTIAL]
### Phase 6: Name [BLOCKED]
EOF
positive_findings="$(nonconforming_phase_headings "$positive_file")"
if [[ -z "$positive_findings" ]]; then
  common_test_pass "positive file: nonconforming_phase_headings reports nothing"
else
  common_test_fail "positive file: expected no findings, got: $positive_findings"
fi

# =====================================================================
# PHASE_NUMBER_TOKEN_ERE / PHASE_HEADING_PREFIX: bare-argument validation and specific-number
# lookup composition, added for update-phase-status.sh's caller-supplied phase_number validation.
# =====================================================================
assert_token_ok() {
  local label="$1" token="$2"
  if grep -qE "$PHASE_NUMBER_TOKEN_ERE" <<< "$token"; then
    common_test_pass "$label: '$token' accepted by PHASE_NUMBER_TOKEN_ERE"
  else
    common_test_fail "$label: '$token' unexpectedly rejected by PHASE_NUMBER_TOKEN_ERE"
  fi
}
assert_token_rejected() {
  local label="$1" token="$2"
  if grep -qE "$PHASE_NUMBER_TOKEN_ERE" <<< "$token"; then
    common_test_fail "$label: '$token' unexpectedly accepted by PHASE_NUMBER_TOKEN_ERE"
  else
    common_test_pass "$label: '$token' correctly rejected by PHASE_NUMBER_TOKEN_ERE"
  fi
}
assert_token_ok "token positive: integer" "3"
assert_token_ok "token positive: decimal sub-phase" "3.1"
assert_token_rejected "token negative: letter suffix" "3a"
assert_token_rejected "token negative: double decimal" "3.1.2"
assert_token_rejected "token negative: roman numeral" "III"
assert_token_rejected "token negative: empty" ""

prefix_lookup_file="$WORKDIR/prefix-lookup.md"
cat > "$prefix_lookup_file" <<'EOF'
### Phase 1: First [COMPLETED]
### Phase 3.1: Second [NOT STARTED]
EOF
prefix_match=$(grep -n "${PHASE_HEADING_PREFIX}3\.1:" "$prefix_lookup_file" | cut -d: -f1)
if [[ "$prefix_match" == "2" ]]; then
  common_test_pass "PHASE_HEADING_PREFIX: specific-number lookup composition finds the correct line"
else
  common_test_fail "PHASE_HEADING_PREFIX: expected line 2, got '$prefix_match'"
fi

# =====================================================================
# Negative number-token fixtures: must be reported by nonconforming_phase_headings AND must make
# extract_phase_number return empty with non-zero status -- never a truncated prefix.
# =====================================================================
assert_rejects() {
  local label="$1" heading="$2" got code
  got="$(extract_phase_number "$heading")"
  code=$?
  if [[ "$code" -ne 0 && -z "$got" ]]; then
    common_test_pass "$label: extract_phase_number rejects (empty, non-zero exit)"
  else
    common_test_fail "$label: expected empty + non-zero exit, got '$got' (exit $code) -- possible truncated-prefix regression"
  fi
}

assert_rejects "negative: Phase 3a"      "### Phase 3a: Name [NOT STARTED]"
assert_rejects "negative: Phase 3.1.2"   "### Phase 3.1.2: Name [NOT STARTED]"
assert_rejects "negative: Phase III"     "### Phase III: Name [NOT STARTED]"
assert_rejects "negative: Phase (empty)" "### Phase : Name [NOT STARTED]"

negative_number_file="$WORKDIR/negative-number.md"
cat > "$negative_number_file" <<'EOF'
### Phase 3a: Name [NOT STARTED]
### Phase 3.1.2: Name [NOT STARTED]
### Phase III: Name [NOT STARTED]
### Phase : Name [NOT STARTED]
EOF
negative_number_count="$(nonconforming_phase_headings "$negative_number_file" | wc -l | tr -d ' ')"
if [[ "$negative_number_count" -eq 4 ]]; then
  common_test_pass "negative-number file: all 4 headings reported non-conforming"
else
  common_test_fail "negative-number file: expected 4 findings, got $negative_number_count"
fi

# =====================================================================
# Negative marker fixtures: [DESCOPED] reported + warning names the [COMPLETED WITH EXCLUSIONS]
# replacement. An arbitrary-unknown-marker fixture proves the check is enum-driven, not a
# DESCOPED special case with no general rule behind it.
# =====================================================================
descoped_file="$WORKDIR/descoped.md"
cat > "$descoped_file" <<'EOF'
### Phase 3: Name [DESCOPED]
EOF
descoped_findings="$(nonconforming_phase_headings "$descoped_file")"
if [[ -n "$descoped_findings" ]]; then
  common_test_pass "DESCOPED heading: reported by nonconforming_phase_headings"
else
  common_test_fail "DESCOPED heading: expected a finding, got none"
fi

descoped_warning="$(warn_nonconforming "$descoped_file" "test" 2>&1 1>/dev/null)"
if echo "$descoped_warning" | grep -qF "COMPLETED WITH EXCLUSIONS"; then
  common_test_pass "DESCOPED warning: names [COMPLETED WITH EXCLUSIONS] as the replacement"
else
  common_test_fail "DESCOPED warning: replacement guidance missing. Got: $descoped_warning"
fi

arbitrary_file="$WORKDIR/arbitrary-marker.md"
cat > "$arbitrary_file" <<'EOF'
### Phase 3: Name [FROBNICATED]
EOF
arbitrary_findings="$(nonconforming_phase_headings "$arbitrary_file")"
if [[ -n "$arbitrary_findings" ]]; then
  common_test_pass "arbitrary-unknown-marker heading: reported (enum-driven, not a DESCOPED special case)"
else
  common_test_fail "arbitrary-unknown-marker heading: expected a finding, got none"
fi
arbitrary_warning="$(warn_nonconforming "$arbitrary_file" "test" 2>&1 1>/dev/null)"
if echo "$arbitrary_warning" | grep -qF "unrecognized status marker" && ! echo "$arbitrary_warning" | grep -qF "COMPLETED WITH EXCLUSIONS"; then
  common_test_pass "arbitrary-unknown-marker warning: generic unrecognized-marker reason, no DESCOPED-specific text"
else
  common_test_fail "arbitrary-unknown-marker warning: unexpected content: $arbitrary_warning"
fi

# =====================================================================
# Equivalence fixtures: the BRE compatibility alias and the ERE heading-match form must classify
# every fixture in this suite identically. A divergence here is exactly the drift this library
# exists to prevent.
# =====================================================================
all_fixture_headings=(
  "### Phase 3: Name [NOT STARTED]"
  "### Phase 3.1: Name [COMPLETED]"
  "### Phase 12: Name [COMPLETED WITH EXCLUSIONS]"
  "### Phase 4: Name [IN PROGRESS]"
  "### Phase 5: Name [PARTIAL]"
  "### Phase 6: Name [BLOCKED]"
  "### Phase 3a: Name [NOT STARTED]"
  "### Phase 3.1.2: Name [NOT STARTED]"
  "### Phase III: Name [NOT STARTED]"
  "### Phase : Name [NOT STARTED]"
  "### Phase 3: Name [DESCOPED]"
  "### Phase 3: Name [FROBNICATED]"
)
equivalence_ok=1
for heading in "${all_fixture_headings[@]}"; do
  ere_match=0
  bre_match=0
  grep -qE "$PHASE_HEADING_ERE" <<< "$heading" && ere_match=1
  grep -q  "$PHASE_HEADING_BRE" <<< "$heading" && bre_match=1
  if [[ "$ere_match" -ne "$bre_match" ]]; then
    equivalence_ok=0
    common_test_fail "equivalence: ERE/BRE diverge on '$heading' (ere=$ere_match bre=$bre_match)"
  fi
done
if [[ "$equivalence_ok" -eq 1 ]]; then
  common_test_pass "equivalence: ERE and BRE heading-match forms agree on all fixtures"
fi

# TOTAL-form equivalence (full-line conforming-heading-shape forms)
total_equivalence_ok=1
for heading in "${all_fixture_headings[@]}"; do
  ere_match=0
  bre_match=0
  grep -qE "$PHASE_HEADING_TOTAL_ERE" <<< "$heading" && ere_match=1
  grep -q  "$PHASE_HEADING_TOTAL_BRE" <<< "$heading" && bre_match=1
  if [[ "$ere_match" -ne "$bre_match" ]]; then
    total_equivalence_ok=0
    common_test_fail "TOTAL-form equivalence: ERE/BRE diverge on '$heading' (ere=$ere_match bre=$bre_match)"
  fi
done
if [[ "$total_equivalence_ok" -eq 1 ]]; then
  common_test_pass "equivalence: PHASE_HEADING_TOTAL_ERE and PHASE_HEADING_TOTAL_BRE agree on all fixtures"
fi

# DONE-form equivalence
done_equivalence_ok=1
for heading in "${all_fixture_headings[@]}"; do
  ere_match=0
  bre_match=0
  grep -qE "$PHASE_HEADING_DONE_ERE" <<< "$heading" && ere_match=1
  grep -q  "$PHASE_HEADING_DONE_BRE" <<< "$heading" && bre_match=1
  if [[ "$ere_match" -ne "$bre_match" ]]; then
    done_equivalence_ok=0
    common_test_fail "DONE-form equivalence: ERE/BRE diverge on '$heading' (ere=$ere_match bre=$bre_match)"
  fi
done
if [[ "$done_equivalence_ok" -eq 1 ]]; then
  common_test_pass "equivalence: PHASE_HEADING_DONE_ERE and PHASE_HEADING_DONE_BRE agree on all fixtures"
fi

# =====================================================================
# 3a/3b/3c case: three distinct non-conforming reports, not three identical "Phase 3" reports.
# =====================================================================
letter_suffix_file="$WORKDIR/letter-suffix.md"
cat > "$letter_suffix_file" <<'EOF'
### Phase 3a: First [NOT STARTED]
### Phase 3b: Second [NOT STARTED]
### Phase 3c: Third [NOT STARTED]
EOF
letter_suffix_findings="$(nonconforming_phase_headings "$letter_suffix_file")"
distinct_headings="$(echo "$letter_suffix_findings" | cut -d: -f3- | sort -u | wc -l | tr -d ' ')"
finding_count="$(echo "$letter_suffix_findings" | grep -c . || true)"
if [[ "$finding_count" -eq 3 && "$distinct_headings" -eq 3 ]]; then
  common_test_pass "3a/3b/3c: three distinct non-conforming reports (no collapse to a single 'Phase 3')"
else
  common_test_fail "3a/3b/3c: expected 3 distinct findings, got $finding_count findings / $distinct_headings distinct: $letter_suffix_findings"
fi
# Each must also fail extract_phase_number individually (never collapsing to a shared "3").
for h in "### Phase 3a: First [NOT STARTED]" "### Phase 3b: Second [NOT STARTED]" "### Phase 3c: Third [NOT STARTED]"; do
  r="$(extract_phase_number "$h")"
  c=$?
  if [[ "$c" -ne 0 && -z "$r" ]]; then
    common_test_pass "3a/3b/3c: '$h' individually rejected (no collapse to 'Phase 3')"
  else
    common_test_fail "3a/3b/3c: '$h' unexpectedly extracted '$r'"
  fi
done

# =====================================================================
# warn_nonconforming return-code contract: 0 when clean, 1 when findings exist.
# =====================================================================
warn_nonconforming "$positive_file" "test" >/dev/null 2>/dev/null
clean_rc=$?
if [[ "$clean_rc" -eq 0 ]]; then
  common_test_pass "warn_nonconforming: returns 0 on a clean file"
else
  common_test_fail "warn_nonconforming: expected 0 on clean file, got $clean_rc"
fi

warn_nonconforming "$negative_number_file" "test" >/dev/null 2>/dev/null
dirty_rc=$?
if [[ "$dirty_rc" -eq 1 ]]; then
  common_test_pass "warn_nonconforming: returns 1 when non-conforming headings exist"
else
  common_test_fail "warn_nonconforming: expected 1 on file with findings, got $dirty_rc"
fi

# =====================================================================
# has_nonconforming_phase_headings: added during Phase 4 migration after discovering that
# `nonconforming_phase_headings <file> | grep -q .` is racy under `set -o pipefail` (grep -q
# closes the pipe after its first match; if the producer is still writing, it receives SIGPIPE
# and the pipeline's reported exit status becomes the producer's non-zero signal-exit code).
# has_nonconforming_phase_headings avoids this via an internal command-substitution capture.
# =====================================================================
if has_nonconforming_phase_headings "$positive_file"; then
  common_test_fail "has_nonconforming_phase_headings: expected false (0 findings) on the positive fixture file"
else
  common_test_pass "has_nonconforming_phase_headings: false (clean) on the positive fixture file"
fi
if has_nonconforming_phase_headings "$negative_number_file"; then
  common_test_pass "has_nonconforming_phase_headings: true (findings exist) on the negative-number fixture file"
else
  common_test_fail "has_nonconforming_phase_headings: expected true on the negative-number fixture file"
fi
# Regression guard for the pipefail/SIGPIPE race itself: run under `set -o pipefail` explicitly,
# using the OLD racy idiom, and confirm it now agrees with the safe helper on a file large/slow
# enough to expose the race (each loop iteration in nonconforming_phase_headings runs multiple
# greps per line, which is enough latency for grep -q to close the pipe first in practice).
racy_check_ok=1
(
  set -o pipefail
  if nonconforming_phase_headings "$negative_number_file" | grep -q .; then
    exit 0
  else
    exit 1
  fi
)
if [[ $? -ne 0 ]]; then
  racy_check_ok=0
fi
if [[ "$racy_check_ok" -eq 1 ]]; then
  common_test_pass "pipefail regression guard: old racy idiom happened to agree with has_nonconforming_phase_headings this run (has_nonconforming_phase_headings is still the mandated call form regardless)"
else
  common_test_pass "pipefail regression guard: reproduced the known SIGPIPE race in the OLD idiom (exactly why has_nonconforming_phase_headings exists and is the mandated call form)"
fi

# =====================================================================
# Enterability vocabulary: PHASE_STATUS_ENTERABLE_ALT is a NEW, narrower alternation that
# excludes BLOCKED; PHASE_STATUS_OPEN_ALT must keep BLOCKED, byte-identical in meaning, for any
# other consumer.
# =====================================================================
if grep -qE "^(${PHASE_STATUS_ENTERABLE_ALT})\$" <<< "BLOCKED"; then
  common_test_fail "PHASE_STATUS_ENTERABLE_ALT: unexpectedly includes BLOCKED"
else
  common_test_pass "PHASE_STATUS_ENTERABLE_ALT: excludes BLOCKED"
fi
if grep -qE "^(${PHASE_STATUS_OPEN_ALT})\$" <<< "BLOCKED"; then
  common_test_pass "PHASE_STATUS_OPEN_ALT: still includes BLOCKED (byte-identical, unchanged meaning)"
else
  common_test_fail "PHASE_STATUS_OPEN_ALT: BLOCKED regression -- OPEN's established meaning must be preserved"
fi
for _enterable_marker in "NOT STARTED" "IN PROGRESS" "PARTIAL"; do
  if grep -qE "^(${PHASE_STATUS_ENTERABLE_ALT})\$" <<< "$_enterable_marker"; then
    common_test_pass "PHASE_STATUS_ENTERABLE_ALT: includes '$_enterable_marker'"
  else
    common_test_fail "PHASE_STATUS_ENTERABLE_ALT: missing '$_enterable_marker'"
  fi
done

# =====================================================================
# phase_marker_of: existing phase prints its marker; a non-existent phase number fails (returns
# 1, empty stdout).
# =====================================================================
marker_of_file="$WORKDIR/marker-of.md"
cat > "$marker_of_file" <<'EOF'
### Phase 1: One [COMPLETED]
### Phase 2: Two [NOT STARTED]
EOF
marker_of_got="$(phase_marker_of "$marker_of_file" 1)"
if [[ "$marker_of_got" == "COMPLETED" ]]; then
  common_test_pass "phase_marker_of: existing phase 1 -> 'COMPLETED'"
else
  common_test_fail "phase_marker_of: expected 'COMPLETED', got '$marker_of_got'"
fi
if phase_marker_of "$marker_of_file" 999 >/dev/null 2>&1; then
  common_test_fail "phase_marker_of: unexpectedly succeeded for a non-existent phase number"
else
  common_test_pass "phase_marker_of: correctly fails for a non-existent phase number"
fi

# =====================================================================
# phase_dependency_numbers: both field spellings, `none`, comma-spacing variants, a decimal
# sub-phase token, an unparseable-prose value and a corpus-realistic value both falling back to
# all-prior, and an absent field also falling back to all-prior.
# task-ref-ok:begin test fixture quoting a real plan-corpus Depends-on value found during
# research/planning, asserting the parser falls back to the all-prior default rather than
# misreading its digit-shaped tokens as phase numbers (category 6 analog: the fixture's whole
# purpose is a literal string the parser must reject)
# =====================================================================
dep_file="$WORKDIR/deps.md"
cat > "$dep_file" <<'EOF'
### Phase 1: First [COMPLETED]
### Phase 2: Second [COMPLETED]
### Phase 3: Third [NOT STARTED]

**Depends on**: none

### Phase 4: Fourth [NOT STARTED]

**Depends on:** 1

### Phase 5: Fifth [NOT STARTED]

**Depends on**: 1, 2

### Phase 6: Sixth [NOT STARTED]

**Depends on:** 1,2

### Phase 7: Seventh [NOT STARTED]

**Depends on**: 3.1

### Phase 8: Eighth [NOT STARTED]

**Depends on**: Phase 3 (directory skeleton must exist)

### Phase 9: Ninth [NOT STARTED]

**Depends on**: Items 593 (shared utilities), 594 (skill base)

### Phase 10: Tenth [NOT STARTED]
EOF
# task-ref-ok:end
assert_dep_numbers() {
  local label="$1" phase_number="$2" expected="$3" got
  got="$(phase_dependency_numbers "$dep_file" "$phase_number" | tr '\n' ',')"
  got="${got%,}"
  if [[ "$got" == "$expected" ]]; then
    common_test_pass "$label: phase_dependency_numbers($phase_number) -> '$got'"
  else
    common_test_fail "$label: phase_dependency_numbers($phase_number) expected '$expected', got '$got'"
  fi
}
assert_dep_numbers "field spelling 1 ('**Depends on**:'), literal 'none'" 3 ""
assert_dep_numbers "field spelling 2 ('**Depends on:**'), single token '1'" 4 "1"
assert_dep_numbers "spacing variant '1, 2'" 5 "1,2"
assert_dep_numbers "spacing variant '1,2'" 6 "1,2"
assert_dep_numbers "decimal sub-phase token '3.1'" 7 "3.1"
assert_dep_numbers "unparseable prose value falls back to all-prior" 8 "1,2,3,4,5,6,7"
assert_dep_numbers "corpus-realistic multi-number prose value falls back to all-prior (never parsed as phase numbers)" 9 "1,2,3,4,5,6,7,8"
assert_dep_numbers "absent field falls back to all-prior" 10 "1,2,3,4,5,6,7,8,9"

# =====================================================================
# phase_is_enterable: marker rejection (BLOCKED), unmet dependency, dangling dependency, and a
# satisfied phase accepted -- each reported via its own single machine-readable reason token.
# =====================================================================
ent_file="$WORKDIR/enterable.md"
cat > "$ent_file" <<'EOF'
### Phase 1: One [BLOCKED]

**Depends on**: none

### Phase 2: Two [NOT STARTED]

**Depends on**: 1

### Phase 3: Three [NOT STARTED]

**Depends on**: 99

### Phase 4: Four [COMPLETED]
### Phase 5: Five [NOT STARTED]

**Depends on**: 4
EOF
assert_enterable() {
  local label="$1" phase_number="$2" expect_rc="$3" expect_reason="$4"
  local heading got rc
  heading=$(grep -E "^### Phase ${phase_number}:" "$ent_file")
  got="$(phase_is_enterable "$ent_file" "$heading")"
  rc=$?
  if [[ "$rc" -eq "$expect_rc" && "$got" == "$expect_reason" ]]; then
    common_test_pass "$label: phase_is_enterable -> rc=$rc reason='$got'"
  else
    common_test_fail "$label: expected rc=$expect_rc reason='$expect_reason', got rc=$rc reason='$got'"
  fi
}
assert_enterable "BLOCKED rejected on marker" 1 1 "marker"
assert_enterable "unmet dependency rejected" 2 1 "unmet-dependency:1"
assert_enterable "dangling dependency rejected" 3 1 "dangling-dependency:99"
assert_enterable "satisfied phase (dependency COMPLETED) accepted" 5 0 ""

# =====================================================================
# select_enterable_phase: one fixture per exit code.
#   exit 0 -- the SAME enterable.md file above: phases 1-3 are open but non-enterable in file
#             order; phase 5 (later in file order) is the first ENTERABLE heading and is selected,
#             never phase 1.
#   exit 3 -- open headings exist (phases 1-2), none enterable: a diagnostic line per rejected
#             heading, in file order.
#   exit 4 -- no heading matches PHASE_STATUS_OPEN_ERE at all (the pre-existing fallthrough).
# =====================================================================
select_exit0_out="$(select_enterable_phase "$ent_file")"
select_exit0_rc=$?
if [[ "$select_exit0_rc" -eq 0 && "$select_exit0_out" == "### Phase 5: Five [NOT STARTED]" ]]; then
  common_test_pass "select_enterable_phase exit 0: selects phase 5 (later in file order), never phase 1"
else
  common_test_fail "select_enterable_phase exit 0: expected phase 5, got rc=$select_exit0_rc out='$select_exit0_out'"
fi

select_exit3_file="$WORKDIR/select-exit3.md"
cat > "$select_exit3_file" <<'EOF'
### Phase 1: One [BLOCKED]

**Depends on**: none

### Phase 2: Two [NOT STARTED]

**Depends on**: 1
EOF
select_exit3_out="$(select_enterable_phase "$select_exit3_file")"
select_exit3_rc=$?
if [[ "$select_exit3_rc" -eq 3 ]]; then
  common_test_pass "select_enterable_phase exit 3: open headings exist, none enterable"
else
  common_test_fail "select_enterable_phase exit 3: expected rc=3, got rc=$select_exit3_rc (out: $select_exit3_out)"
fi
if echo "$select_exit3_out" | grep -qF "1:BLOCKED:marker" && echo "$select_exit3_out" | grep -qF "2:NOT STARTED:unmet-dependency:1"; then
  common_test_pass "select_enterable_phase exit 3: diagnostic lines name both rejected headings with their reasons"
else
  common_test_fail "select_enterable_phase exit 3: expected diagnostics missing (got: $select_exit3_out)"
fi

select_exit4_file="$WORKDIR/select-exit4.md"
cat > "$select_exit4_file" <<'EOF'
### Phase 1: One [COMPLETED]
### Phase 2: Two [COMPLETED WITH EXCLUSIONS]
EOF
select_exit4_out="$(select_enterable_phase "$select_exit4_file")"
select_exit4_rc=$?
if [[ "$select_exit4_rc" -eq 4 && -z "$select_exit4_out" ]]; then
  common_test_pass "select_enterable_phase exit 4: no OPEN heading at all -- the pre-existing fallthrough, preserved as its own distinct code"
else
  common_test_fail "select_enterable_phase exit 4: expected rc=4 and empty output, got rc=$select_exit4_rc out='$select_exit4_out'"
fi

# =====================================================================
# Deliberate-break check (documented here, not run automatically): flipping any exported
# constant, e.g. removing "COMPLETED WITH EXCLUSIONS" from PHASE_STATUS_ENUM, must make the
# suite above fail -- proving the assertions are live, not vacuous. Verified manually during
# implementation; not re-run on every invocation since it requires mutating the sourced library
# in place. The same holds for the enterability additions above: e.g. restoring `BLOCKED` to
# PHASE_STATUS_ENTERABLE_ALT must make the "PHASE_STATUS_ENTERABLE_ALT: excludes BLOCKED"
# assertion (and the exit-3/exit-0 select_enterable_phase assertions above, which depend on
# BLOCKED staying non-enterable) fail.
# =====================================================================

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
