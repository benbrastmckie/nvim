#!/usr/bin/env bash
# test-run-all-selection.sh - Regression suite for suite-level selection within Gate 8: both
# halves of the mechanism -- scripts/lib/suite-selection-lib.sh's touched-file -> suite mapping
# (fail-safe escalation, mapping correctness, resolution-order classification) AND run-all.sh's
# --only SUITE[,SUITE,...] flag (validate-all-tokens-first refusal, no-flag behavior preservation,
# and parity of every existing mechanism -- --jobs, the nested guard, LOAD_SENSITIVE_BASENAMES,
# TOTAL_ACCOUNTED, known-failures.txt, --timings -- with and without selection).
#
# Structural model: test-run-all-parallel.sh (pass()/fail()/info() helpers, PASSED/FAILED
# counters, mktemp WORKDIR with trap EXIT cleanup, a SYNTHETIC source-store-shaped fixture with
# the real run-all.sh COPIED in so its own SCRIPT_DIR resolution walks the fixture tree, never
# the real repo's ~120-suite battery -- this suite must itself stay fast and deterministic). The
# library-level cases (fail-safe escalation, mapping correctness) run directly against the REAL
# corpus instead: sourcing a library and calling a pure function is cheap (milliseconds, no suite
# execution), so there is no affordability reason to synthesize a fixture for those cases, and a
# real zero-reference script is more honest evidence than a synthetic stand-in would be.
#
# SOURCE-STORE-ONLY SUBJECT RESOLUTION: this suite resolves its two subjects
# ($RUN_ALL_SRC, $SUITE_SELECTION_LIB) purely from its own location (SCRIPT_DIR's siblings),
# never from a deployed $REPO_ROOT/.claude path -- so this suite itself can never join the
# deployed-preferring population it is partly concerned with classifying in other suites.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_ALL_SRC="$CORE_DIR/tests/run-all.sh"
SUITE_SELECTION_LIB="$CORE_DIR/lib/suite-selection-lib.sh"

if [ ! -f "$RUN_ALL_SRC" ]; then
  echo "ERROR: expected $RUN_ALL_SRC" >&2
  exit 2
fi
if [ ! -f "$SUITE_SELECTION_LIB" ]; then
  echo "ERROR: expected $SUITE_SELECTION_LIB" >&2
  exit 2
fi

PASSED=0
FAILED=0

common_test_workdir_init

# See test-run-all-parallel.sh's identical header note: an outer run-all.sh unconditionally
# exports RUN_ALL_NESTED=1 into every suite it launches (including this one, when discovered
# as part of a real battery run), and that export is inherited by every child process this
# script spawns. Clearing it once here restores a clean unnested environment for every
# "unguarded" fixture invocation below; the deliberate exception (the nested-guard case) sets it
# explicitly only for that single command.
unset RUN_ALL_NESTED

# =====================================================================================
# PART 1 -- suite-selection-lib.sh, against the REAL corpus (cheap: pure function calls, no
# suite execution).
# =====================================================================================

# shellcheck source=/dev/null
source "$SUITE_SELECTION_LIB"

# Case 1: fail-safe escalation. Dynamically derive a currently-true zero-reference candidate
# (never hardcode a specific basename here: a name hardcoded in THIS suite's own source text
# becomes, the moment this suite exists in the corpus, a textual "reference" to itself via
# suite-selection-lib.sh's own grep-based stratum (b) -- poisoning the very fixture this case is
# meant to prove). Scan the corpus's lib/+lint/+flat-non-test population and pick the first
# candidate whose basename is not grep-referenced by any discovered suite, including this one.
ZERO_REF_CANDIDATE=""
for _cand in "$CORE_DIR"/lib/*.sh "$CORE_DIR"/lint/*.sh "$CORE_DIR"/*.sh; do
  [ -e "$_cand" ] || continue
  _cand_base="$(basename "$_cand")"
  case "$_cand_base" in test-*.sh|run-all.sh) continue ;; esac
  # Captured to a variable rather than piped into `grep -q .`: under `set -o pipefail` (this
  # script's own top-of-file setting), `grep -l ... | grep -q .` is a SIGPIPE/pipefail footgun --
  # `grep -q` exits the instant it sees its first match, which can close the pipe out from under
  # an upstream `grep -l` that is still writing further matching filenames, so the upstream grep
  # is killed by SIGPIPE (exit 141) and pipefail then reports that non-zero as the WHOLE
  # pipeline's status even though a match plainly exists. A command substitution has no such
  # early-exit reader, so it always drains grep -l to completion and reports emptiness honestly.
  _cand_matches="$(grep -l -F -- "$_cand_base" "$CORE_DIR"/tests/test-*.sh "$CORE_DIR"/test-*.sh 2>/dev/null)"
  if [ -z "$_cand_matches" ]; then
    ZERO_REF_CANDIDATE="$_cand_base"
    break
  fi
done
unset _cand _cand_base _cand_matches

if [ -z "$ZERO_REF_CANDIDATE" ]; then
  common_test_fail "case1: setup error -- no zero-reference candidate could be derived from the current corpus"
  common_test_fail "case1b: skipped -- case1's candidate derivation failed"
else
  escalation_out="$(suite_selection_select "$CORE_DIR/$ZERO_REF_CANDIDATE")"
  if [ "$escalation_out" = "$SUITE_SELECTION_FULL_SWEEP_SENTINEL" ]; then
    common_test_pass "case1: a real zero-reference script ($ZERO_REF_CANDIDATE) escalates to the full-sweep sentinel"
  else
    common_test_fail "case1: expected the full-sweep sentinel for $ZERO_REF_CANDIDATE, got:" "$escalation_out"
  fi

  # Case 1b: the unmapped-reporter names the same path as unmappable.
  unmapped_out="$(suite_selection_unmapped "$CORE_DIR/$ZERO_REF_CANDIDATE")"
  if [ "$unmapped_out" = "$CORE_DIR/$ZERO_REF_CANDIDATE" ]; then
    common_test_pass "case1b: suite_selection_unmapped names the zero-reference path verbatim"
  else
    common_test_fail "case1b: suite_selection_unmapped did not name the unmappable path as expected" "$unmapped_out"
  fi
fi

# Case 2: mapping correctness -- a lint/ file maps to its paired suite (strict basename pairing).
LINT_FIXTURE="lint-agent-contracts.sh"
lint_out="$(suite_selection_select "$CORE_DIR/lint/$LINT_FIXTURE")"
if printf '%s\n' "$lint_out" | grep -qx "test-${LINT_FIXTURE}"; then
  common_test_pass "case2: lint/$LINT_FIXTURE maps to its paired suite test-$LINT_FIXTURE"
else
  common_test_fail "case2: lint/$LINT_FIXTURE did not map to test-$LINT_FIXTURE" "$lint_out"
fi

# Case 2b: a shared lib/ file maps to its full many-to-one suite set (reference count >= 10,
# well above any single-pairing result, proving stratum (b) fired).
LIB_FIXTURE="task-lookup-lib.sh"
lib_out="$(suite_selection_select "$CORE_DIR/lib/$LIB_FIXTURE")"
lib_count="$(printf '%s\n' "$lib_out" | grep -c .)"
if [ "$lib_count" -ge 10 ]; then
  common_test_pass "case2b: lib/$LIB_FIXTURE maps to its full many-to-one suite set ($lib_count suites)"
else
  common_test_fail "case2b: lib/$LIB_FIXTURE mapped to only $lib_count suite(s), expected >= 10" "$lib_out"
fi

# Case 2c: every returned suite carries a resolution-order classification (one of the three
# documented values) via suite_selection_select_annotated.
annotated_out="$(suite_selection_select_annotated "$CORE_DIR/lint/$LINT_FIXTURE")"
bad_class_count=0
while IFS='|' read -r _suite _class; do
  [ -n "$_suite" ] || continue
  case "$_class" in
    source-only|source-first|deployed-first) ;;
    *) bad_class_count=$((bad_class_count + 1)) ;;
  esac
done <<< "$annotated_out"
if [ "$bad_class_count" -eq 0 ] && [ -n "$annotated_out" ]; then
  common_test_pass "case2c: every selected suite carries a valid resolution-order classification"
else
  common_test_fail "case2c: $bad_class_count selected suite(s) carried an invalid/missing classification" "$annotated_out"
fi

# Case 3: multi-path union, except a single unmappable path escalates the whole call.
if [ -z "$ZERO_REF_CANDIDATE" ]; then
  common_test_fail "case3: skipped -- case1's candidate derivation failed"
else
  union_out="$(suite_selection_select "$CORE_DIR/lint/$LINT_FIXTURE" "$CORE_DIR/$ZERO_REF_CANDIDATE")"
  if [ "$union_out" = "$SUITE_SELECTION_FULL_SWEEP_SENTINEL" ]; then
    common_test_pass "case3: one unmappable path among several escalates the whole multi-path call"
  else
    common_test_fail "case3: multi-path call with one unmappable path did not escalate" "$union_out"
  fi
fi

# Cases 3b-3e pin the four non-core-extension-paths behaviours added to suite-selection-lib.sh:
# (a) a touched non-core source-store path resolves to its own extension's paired suite; (b) a
# genuinely uncovered non-core path still escalates to the honest sentinel; (c) deployed-mode
# selection stays byte-identical; (d) suite_selection_classify now reaches non-core suites on
# real evidence. EXT_PARENT is the agent-system/extensions/ directory this library's own
# _ssl_extensions_parent would derive -- empty when this suite itself is run from a deployed
# vantage point (no such directory exists there), which is the signal every derivation below
# guards on to report a clean skip rather than a failure (Phase 5 runs this suite from both
# vantage points).
EXT_PARENT="$(cd "$CORE_DIR/../.." 2>/dev/null && pwd)"
[ -f "$EXT_PARENT/core/manifest.json" ] || EXT_PARENT=""

# Case 3b setup: derive a non-core extension pair dynamically -- scan every non-core extension's
# own scripts/ for a basename pairing with its own scripts/tests/test-<name>.sh (or the lib/
# "-lib.sh" suffix variant), taking the first such pair in directory-listing order. Never
# hardcode a specific extension or basename: the extension set and each one's own script corpus
# can both change (same "never hardcode" discipline as case1's ZERO_REF_CANDIDATE above).
NONCORE_EXT=""
NONCORE_NAME=""
NONCORE_SUITE=""
if [ -n "$EXT_PARENT" ]; then
  for _ext_dir in "$EXT_PARENT"/*/; do
    [ -n "$NONCORE_EXT" ] && break
    _ext_name="$(basename "$_ext_dir")"
    [ "$_ext_name" = "core" ] && continue
    _ext_scripts="${_ext_dir}scripts"
    [ -d "$_ext_scripts" ] || continue
    for _cand in "$_ext_scripts"/*.sh; do
      [ -e "$_cand" ] || continue
      _cand_base="$(basename "$_cand")"
      case "$_cand_base" in test-*.sh) continue ;; esac
      _cand_noext="${_cand_base%.sh}"
      if [ -f "$_ext_scripts/tests/test-${_cand_base}" ]; then
        NONCORE_EXT="$_ext_name"
        NONCORE_NAME="$_cand_base"
        NONCORE_SUITE="test-${_cand_base}"
        break
      elif [ -f "$_ext_scripts/tests/test-${_cand_noext}-lib.sh" ]; then
        NONCORE_EXT="$_ext_name"
        NONCORE_NAME="$_cand_base"
        NONCORE_SUITE="test-${_cand_noext}-lib.sh"
        break
      fi
    done
  done
fi
unset _ext_dir _ext_name _ext_scripts _cand _cand_base _cand_noext

# Case 3b: a touched path under a real non-core extension's scripts/ resolves to that same
# extension's own paired suite (not __FULL_SWEEP__, the defect this task fixes).
if [ -z "$NONCORE_EXT" ]; then
  common_test_info "case3b: skip -- no non-core extension with a scripts/<name>.sh <-> scripts/tests/test-<name>.sh pair could be derived (expected from a deployed vantage point, which has no per-extension source-store tree)"
else
  noncore_out="$(suite_selection_select "$EXT_PARENT/$NONCORE_EXT/scripts/$NONCORE_NAME")"
  if [ "$noncore_out" != "$SUITE_SELECTION_FULL_SWEEP_SENTINEL" ] \
     && printf '%s\n' "$noncore_out" | grep -qx "$NONCORE_SUITE"; then
    common_test_pass "case3b: non-core path $NONCORE_EXT/scripts/$NONCORE_NAME resolves to its own extension's paired suite $NONCORE_SUITE"
  else
    common_test_fail "case3b: non-core path $NONCORE_EXT/scripts/$NONCORE_NAME did not resolve to $NONCORE_SUITE as expected" "$noncore_out"
  fi
fi

# Case 3c setup: derive a genuinely uncovered non-core path -- scan every non-core extension's
# own scripts/ (flat, plus lib/ and lint/ when present) for a basename with no paired test file
# and no textual reference from any suite in that SAME extension's own tests/ or flat scripts/
# (strata (a)+(b), scoped per-extension exactly as the corrected resolution now scopes them).
UNCOVERED_EXT=""
UNCOVERED_NAME=""
if [ -n "$EXT_PARENT" ]; then
  for _ext_dir in "$EXT_PARENT"/*/; do
    [ -n "$UNCOVERED_EXT" ] && break
    _ext_name="$(basename "$_ext_dir")"
    [ "$_ext_name" = "core" ] && continue
    _ext_scripts="${_ext_dir}scripts"
    [ -d "$_ext_scripts" ] || continue
    for _cand in "$_ext_scripts"/*.sh "$_ext_scripts"/lib/*.sh "$_ext_scripts"/lint/*.sh; do
      [ -e "$_cand" ] || continue
      _cand_base="$(basename "$_cand")"
      case "$_cand_base" in test-*.sh) continue ;; esac
      _cand_noext="${_cand_base%.sh}"
      [ -f "$_ext_scripts/tests/test-${_cand_base}" ] && continue
      [ -f "$_ext_scripts/tests/test-${_cand_noext}-lib.sh" ] && continue
      _cand_matches=""
      if [ -d "$_ext_scripts/tests" ]; then
        _cand_matches="$(grep -l -F -- "$_cand_base" "$_ext_scripts/tests"/test-*.sh 2>/dev/null)"
      fi
      if [ -z "$_cand_matches" ]; then
        _cand_matches="$(grep -l -F -- "$_cand_base" "$_ext_scripts"/test-*.sh 2>/dev/null)"
      fi
      if [ -z "$_cand_matches" ]; then
        UNCOVERED_EXT="$_ext_name"
        UNCOVERED_NAME="$_cand_base"
        break
      fi
    done
  done
fi
unset _ext_dir _ext_name _ext_scripts _cand _cand_base _cand_noext _cand_matches

# Case 3c: a genuinely uncovered non-core path still escalates to the honest sentinel --
# __FULL_SWEEP__ semantics are untouched by this task, never weakened.
if [ -z "$UNCOVERED_EXT" ]; then
  common_test_info "case3c: skip -- no genuinely uncovered non-core path could be derived from the current corpus (expected from a deployed vantage point, or a source-store corpus where every non-core script happens to be covered)"
else
  uncovered_out="$(suite_selection_select "$EXT_PARENT/$UNCOVERED_EXT/scripts/$UNCOVERED_NAME")"
  if [ "$uncovered_out" = "$SUITE_SELECTION_FULL_SWEEP_SENTINEL" ]; then
    common_test_pass "case3c: a genuinely uncovered non-core path ($UNCOVERED_EXT/scripts/$UNCOVERED_NAME) still escalates to the full-sweep sentinel"
  else
    common_test_fail "case3c: expected the full-sweep sentinel for $UNCOVERED_EXT/scripts/$UNCOVERED_NAME, got:" "$uncovered_out"
  fi
  unmapped_nc_out="$(suite_selection_unmapped "$EXT_PARENT/$UNCOVERED_EXT/scripts/$UNCOVERED_NAME")"
  if [ "$unmapped_nc_out" = "$EXT_PARENT/$UNCOVERED_EXT/scripts/$UNCOVERED_NAME" ]; then
    common_test_pass "case3c-unmapped: suite_selection_unmapped names the non-core zero-reference path verbatim"
  else
    common_test_fail "case3c-unmapped: suite_selection_unmapped did not name the non-core unmappable path as expected" "$unmapped_nc_out"
  fi
fi

# Case 3d: deployed-mode selection stays byte-identical -- build a synthetic DEPLOYED-shaped
# fixture (flat scripts/ + scripts/tests/, with NO core/manifest.json two directories above the
# scripts root -- the only state _ssl_extensions_parent's marker check consults), copy the real
# library in at scripts/lib/, source that copy in a subshell, and confirm a touched path carrying
# an agent-system/extensions/<ext>/scripts/ segment still resolves against the flat merged tree
# exactly as before this task's change -- proving the detection branch cannot fire without the
# marker.
DEPLOYED_FIXTURE="$WORKDIR/deployed-fixture"
DEPLOYED_SCRIPTS="$DEPLOYED_FIXTURE/scripts"
DEPLOYED_TESTS="$DEPLOYED_SCRIPTS/tests"
mkdir -p "$DEPLOYED_SCRIPTS/lib" "$DEPLOYED_TESTS"
cp "$SUITE_SELECTION_LIB" "$DEPLOYED_SCRIPTS/lib/suite-selection-lib.sh"
cat > "$DEPLOYED_SCRIPTS/fx-deployed-subject.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$DEPLOYED_TESTS/test-fx-deployed-subject.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
# Decoy: a real "lean/scripts/tests/" directory living exactly where _ssl_extensions_parent
# would land two directories up from the scripts root ($WORKDIR, the deployed fixture's own
# flat scripts/ being only one level below it -- the same shape a real .claude/scripts deploy
# has relative to the repo root), with no suite pairing a touched basename of
# "fx-deployed-subject.sh" at all. If the marker gate were ever bypassed (e.g. a future edit
# drops the core/manifest.json check), the extension-root override would find this decoy
# directory real and switch roots to it -- which has no matching suite -- flipping the expected
# result to the full-sweep sentinel instead of test-fx-deployed-subject.sh and failing this
# case. This is what makes the case load-bearing against the marker gate specifically, not
# merely against the extension directory existing.
mkdir -p "$WORKDIR/lean/scripts/tests"

deployed_out="$(bash -c '
  source "$1"
  suite_selection_select "agent-system/extensions/lean/scripts/fx-deployed-subject.sh"
' _ "$DEPLOYED_SCRIPTS/lib/suite-selection-lib.sh")"

if [ "$deployed_out" = "test-fx-deployed-subject.sh" ]; then
  common_test_pass "case3d: deployed-mode selection is byte-identical -- a touched path carrying an agent-system/extensions/<ext>/scripts/ segment still resolves against the flat merged tree (no core/manifest.json marker two directories up, so the detection branch cannot fire)"
else
  common_test_fail "case3d: deployed-mode selection changed under the new extension-detection branch" "$deployed_out"
fi

# Case 3e setup: derive a non-core (suite, touched-basename) pair whose suite_selection_classify
# call reaches real evidence rather than the vacuous not-found default -- scan every non-core
# suite carrying a .claude reference (the same textual signal the corpus-wide deployed-preferring
# ratio already uses) and probe candidate basenames the suite textually mentions until one yields
# a non-source-only classification. A non-"source-only" result is only reachable once the suite
# FILE has actually been found and read, so it is itself the evidence that classification now
# reaches non-core suites.
CLASSIFY_SUITE=""
CLASSIFY_TOUCHED=""
CLASSIFY_RESULT=""
if [ -n "$EXT_PARENT" ]; then
  for _ext_dir in "$EXT_PARENT"/*/; do
    [ -n "$CLASSIFY_SUITE" ] && break
    _ext_name="$(basename "$_ext_dir")"
    [ "$_ext_name" = "core" ] && continue
    _ext_tests="${_ext_dir}scripts/tests"
    [ -d "$_ext_tests" ] || continue
    for _suite_f in "$_ext_tests"/test-*.sh; do
      [ -e "$_suite_f" ] || continue
      [ -n "$CLASSIFY_SUITE" ] && break
      # shellcheck disable=SC2016
      grep -q -E '\$REPO_ROOT/\.claude|/\.claude/' "$_suite_f" 2>/dev/null || continue
      _suite_base="$(basename "$_suite_f")"
      while IFS= read -r _touched_cand; do
        [ -n "$_touched_cand" ] || continue
        _res="$(suite_selection_classify "$_suite_base" "$_touched_cand")"
        if [ "$_res" != "source-only" ]; then
          CLASSIFY_SUITE="$_suite_base"
          CLASSIFY_TOUCHED="$_touched_cand"
          CLASSIFY_RESULT="$_res"
          break
        fi
      done < <(grep -oE '[A-Za-z0-9_.-]+\.sh' "$_suite_f" 2>/dev/null | sort -u)
    done
  done
fi
unset _ext_dir _ext_name _ext_tests _suite_f _suite_base _touched_cand _res

# Case 3e: suite_selection_classify locates a non-core suite file and classifies it on real
# evidence (the classification ruling -- EXTENDED to non-core suites, not left core-only).
# A deployed vantage point (EXT_PARENT empty) has no per-extension source-store tree to derive
# from at all, so a clean skip is reported there -- but in source-store mode, deriving nothing is
# itself a failure signal (the research phase measured 5 qualifying suites in the real corpus),
# not a routine skip; it would otherwise hide a totally broken classify() behind a false skip,
# since the derivation above is probing with the very function this case exists to pin.
if [ -z "$CLASSIFY_SUITE" ] && [ -z "$EXT_PARENT" ]; then
  common_test_info "case3e: skip -- no extensions root at this vantage point (deployed mode has no per-extension source-store tree to derive a pair from)"
elif [ -z "$CLASSIFY_SUITE" ]; then
  common_test_fail "case3e: no non-core (suite, touched-basename) pair could be derived that reaches evidence-based classification, although this is a source-store vantage point with an extensions root"
else
  case "$CLASSIFY_RESULT" in
    source-first|deployed-first)
      common_test_pass "case3e: suite_selection_classify locates a non-core suite ($CLASSIFY_SUITE) and classifies $CLASSIFY_TOUCHED on real evidence ($CLASSIFY_RESULT), not the vacuous not-found default"
      ;;
    *)
      common_test_fail "case3e: derived non-core pair did not classify on evidence as expected" "$CLASSIFY_SUITE / $CLASSIFY_TOUCHED -> $CLASSIFY_RESULT"
      ;;
  esac
fi

# =====================================================================================
# PART 2 -- run-all.sh's --only flag, against the REAL script directly (cheap: validation
# happens before any suite executes).
# =====================================================================================

# Case 4: invalid --only token exits 2, names the token, and runs nothing (no [RUN] line at all).
bad_token_out="$(bash "$RUN_ALL_SRC" --only "definitely-not-a-real-suite.sh" 2>&1)"
bad_token_rc=$?
if [ "$bad_token_rc" -eq 2 ] \
   && printf '%s\n' "$bad_token_out" | grep -q "definitely-not-a-real-suite.sh" \
   && ! printf '%s\n' "$bad_token_out" | grep -q '\[RUN\]'; then
  common_test_pass "case4: invalid --only token exits 2, names the token, runs no suite"
else
  common_test_fail "case4: invalid --only token did not refuse cleanly (rc=$bad_token_rc)" "$bad_token_out"
fi

# Case 4b: a mixed valid+invalid token list refuses the WHOLE run (no partial subset silently
# runs) -- picks one real, cheap, known-fast suite as the "valid" half.
mixed_out="$(bash "$RUN_ALL_SRC" --only "test-common-lib.sh,definitely-not-a-real-suite.sh" 2>&1)"
mixed_rc=$?
if [ "$mixed_rc" -eq 2 ] && ! printf '%s\n' "$mixed_out" | grep -q '\[RUN\]'; then
  common_test_pass "case4b: a mixed valid+invalid --only list refuses the whole run, not a partial subset"
else
  common_test_fail "case4b: mixed valid+invalid --only list did not refuse cleanly (rc=$mixed_rc)" "$mixed_out"
fi

# Case 4c: --only with an empty argument exits 2 with a named error.
empty_out="$(bash "$RUN_ALL_SRC" --only "" 2>&1)"
empty_rc=$?
if [ "$empty_rc" -eq 2 ] && printf '%s\n' "$empty_out" | grep -q "ERROR: --only"; then
  common_test_pass "case4c: --only with an empty argument exits 2 with a named error"
else
  common_test_fail "case4c: --only '' did not exit 2 with a named error (rc=$empty_rc)" "$empty_out"
fi

# =====================================================================================
# PART 3 -- run-all.sh's --only flag, against a SYNTHETIC fixture (mechanism parity: --jobs,
# the nested guard, LOAD_SENSITIVE_BASENAMES, TOTAL_ACCOUNTED, known-failures.txt, --timings).
# =====================================================================================

EXT_ROOT="$WORKDIR/exts"
TESTS_DIR="$EXT_ROOT/core/scripts/tests"
FLAT_DIR="$EXT_ROOT/core/scripts"
mkdir -p "$TESTS_DIR"
echo '{}' > "$EXT_ROOT/core/manifest.json"
cp "$RUN_ALL_SRC" "$TESTS_DIR/run-all.sh"
chmod +x "$TESTS_DIR/run-all.sh"
FIXTURE_RUNNER="$TESTS_DIR/run-all.sh"

cat > "$TESTS_DIR/test-fx-pass1.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$TESTS_DIR/test-fx-pass2.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$TESTS_DIR/test-fx-fail1.sh" << 'EOF'
#!/usr/bin/env bash
echo "deliberate fixture failure (registered in known-failures.txt)"
exit 1
EOF
cat > "$TESTS_DIR/test-fx-fail2.sh" << 'EOF'
#!/usr/bin/env bash
echo "deliberate fixture failure (NOT registered -- must classify NEW)"
exit 1
EOF
# Named EXACTLY one of run-all.sh's fixed LOAD_SENSITIVE_BASENAMES entries so is_load_sensitive()
# recognizes it inside this isolated fixture -- harmless here since the fixture never touches the
# real corpus's own test-run-all-parallel.sh.
cat > "$TESTS_DIR/test-run-all-parallel.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TESTS_DIR"/test-fx-pass1.sh "$TESTS_DIR"/test-fx-pass2.sh \
  "$TESTS_DIR"/test-fx-fail1.sh "$TESTS_DIR"/test-fx-fail2.sh "$TESTS_DIR"/test-run-all-parallel.sh

mkdir -p "$FLAT_DIR"
cat > "$FLAT_DIR/test-fx-flat1.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FLAT_DIR/test-fx-flat1.sh"

cat > "$TESTS_DIR/known-failures.txt" << 'EOF'
# synthetic fixture known-failures manifest
test-fx-fail1.sh|real-defect|synthetic known failure for test-run-all-selection.sh|test-fixture
EOF

# 2 quick pass + 2 quick fail + 1 load-sensitive pass + 1 flat pass = 6 fixture suites total.
FIXTURE_TOTAL=6

# Case 5: no-flag behavior is unaffected by the new --only machinery -- the fixture's full-sweep
# tally line matches the exact expected counts/classification (2 EXPECTED+NEW split, 6 total).
noflag_out="$(bash "$FIXTURE_RUNNER" --quiet 2>&1)"
noflag_rc=$?
if [ "$noflag_rc" -eq 1 ] \
   && printf '%s\n' "$noflag_out" | grep -qF "4 passed, 2 failed (1 expected, 1 NEW), 0 skipped, 6 total"; then
  common_test_pass "case5: no-flag run's tally line matches expected pre-selection semantics exactly"
else
  common_test_fail "case5: no-flag run's tally line did not match expected semantics (rc=$noflag_rc)" "$noflag_out"
fi

# Case 6: --only selects exactly the given subset, preserving EXPECTED/NEW classification
# identically to the full run (test-fx-fail1.sh EXPECTED, test-fx-fail2.sh NEW).
TIMINGS_FILE="$WORKDIR/timings-case6.csv"
only_out="$(bash "$FIXTURE_RUNNER" --quiet --timings "$TIMINGS_FILE" --only "test-fx-pass1.sh,test-fx-fail1.sh,test-fx-fail2.sh" 2>&1)"
only_rc=$?
if [ "$only_rc" -eq 1 ] \
   && printf '%s\n' "$only_out" | grep -qF "1 passed, 2 failed (1 expected, 1 NEW), 0 skipped, 3 total"; then
  common_test_pass "case6: --only selects exactly the given 3-suite subset with identical EXPECTED/NEW classification"
else
  common_test_fail "case6: --only subset tally did not match expected (rc=$only_rc)" "$only_out"
fi

# Case 6b: --timings emits exactly one row per SELECTED suite plus the aggregate TOTAL row --
# never the full 6-suite discovered population.
if [ -f "$TIMINGS_FILE" ]; then
  timings_lines="$(wc -l < "$TIMINGS_FILE")"
  timings_suite_rows="$(grep -vc '^TOTAL,' "$TIMINGS_FILE")"
  if [ "$timings_lines" -eq 4 ] && [ "$timings_suite_rows" -eq 3 ]; then
    common_test_pass "case6b: --timings under selection emits exactly 3 suite rows + 1 TOTAL row (not all $FIXTURE_TOTAL discovered)"
  else
    common_test_fail "case6b: --timings row count under selection was wrong (expected 3 suite + 1 TOTAL, got $timings_suite_rows suite + $((timings_lines - timings_suite_rows)) other)" "$(cat "$TIMINGS_FILE")"
  fi
else
  common_test_fail "case6b: expected timings file $TIMINGS_FILE was not created"
fi

# Case 7: --only + --jobs 2 exercises the parallel path and TOTAL_ACCOUNTED cleanly (no
# "internal scheduling error" message, which is run-all.sh's own self-check for this).
jobs2_out="$(bash "$FIXTURE_RUNNER" --quiet --jobs 2 --only "test-fx-pass1.sh,test-fx-pass2.sh,test-run-all-parallel.sh" 2>&1)"
jobs2_rc=$?
# known-failures.txt exists in this fixture, so MANIFEST_PRESENT=true for every run against it --
# even an all-pass tally line carries the "(E expected, N NEW)" clause.
if [ "$jobs2_rc" -eq 0 ] \
   && printf '%s\n' "$jobs2_out" | grep -qF "3 passed, 0 failed (0 expected, 0 NEW), 0 skipped, 3 total" \
   && ! printf '%s\n' "$jobs2_out" | grep -q "internal scheduling error"; then
  common_test_pass "case7: --only + --jobs 2 runs cleanly with no TOTAL_ACCOUNTED scheduling error"
else
  common_test_fail "case7: --only + --jobs 2 did not run cleanly (rc=$jobs2_rc)" "$jobs2_out"
fi

# Case 8: a LOAD_SENSITIVE_BASENAMES member included in --only still runs alone, serially,
# before the parallel pool starts -- confirmed via the exact [RUN] annotation run-all.sh prints
# for a load-sensitive suite, even under selection.
loadsens_out="$(bash "$FIXTURE_RUNNER" --jobs 2 --only "test-fx-pass1.sh,test-run-all-parallel.sh" 2>&1)"
if printf '%s\n' "$loadsens_out" | grep -qF "[RUN]  $TESTS_DIR/test-run-all-parallel.sh (load-sensitive: serialized, not in the parallel pool)"; then
  common_test_pass "case8: a LOAD_SENSITIVE_BASENAMES member selected via --only still serializes ahead of the parallel pool"
else
  common_test_fail "case8: load-sensitive serialization annotation missing under --only + --jobs 2" "$loadsens_out"
fi

# Case 9: RUN_ALL_NESTED=1 still forces sequential under --only + --jobs N (same RELATIVE-ratio
# timing technique as test-run-all-parallel.sh's cases 3/4, applied under selection, using two
# deliberately slow fixture suites selected via --only).
for n in a b; do
  cat > "$TESTS_DIR/test-fx-slow-$n.sh" << 'EOF'
#!/usr/bin/env bash
sleep 0.4
exit 0
EOF
  chmod +x "$TESTS_DIR/test-fx-slow-$n.sh"
done

t0=$(date +%s%3N)
bash "$FIXTURE_RUNNER" --quiet --jobs 2 --only "test-fx-slow-a.sh,test-fx-slow-b.sh" >/dev/null 2>&1
t1=$(date +%s%3N)
only_parallel_ms=$((t1 - t0))

t0=$(date +%s%3N)
RUN_ALL_NESTED=1 bash "$FIXTURE_RUNNER" --quiet --jobs 2 --only "test-fx-slow-a.sh,test-fx-slow-b.sh" >/dev/null 2>&1
t1=$(date +%s%3N)
only_nested_ms=$((t1 - t0))

common_test_info "case9 timing: --only+parallel=${only_parallel_ms}ms --only+nested(forced-sequential)=${only_nested_ms}ms"

if [ "$only_nested_ms" -ge "$only_parallel_ms" ]; then
  common_test_pass "case9: RUN_ALL_NESTED=1 forces sequential (${only_nested_ms}ms) under --only, not faster than unguarded parallel (${only_parallel_ms}ms)"
else
  common_test_fail "case9: RUN_ALL_NESTED=1 (${only_nested_ms}ms) was FASTER than unguarded --only + --jobs 2 (${only_parallel_ms}ms) -- the nested guard may not compose with selection"
fi

# Case 10 (producer-side pinning, consumer/producer verdict-row contract): run-all.sh's own
# `[FAIL] <suite>` verdict row must be line-initial and uncolored -- the exact shape
# `scripts/lib/gate-verdict-extract-lib.sh`'s anchored extraction relies on for Gate 8 and that
# this suite's Case 5 run above already produced (noflag_out, test-fx-fail1.sh/test-fx-fail2.sh
# both fail). A regression here (e.g. a future edit that colorizes this line, or moves it off
# column 0) would silently blind Gate 8's extraction to every real failure -- see
# context/standards/shell-script-testing.md's "Verdict-line extraction contract" section.
if printf '%s\n' "$noflag_out" | grep -qE '^\[FAIL\] .*test-fx-fail1\.sh$' \
   && printf '%s\n' "$noflag_out" | grep -qE '^\[FAIL\] .*test-fx-fail2\.sh$' \
   && ! printf '%s\n' "$noflag_out" | grep -qP '^\x1b\[' 2>/dev/null; then
  common_test_pass "case10: run-all.sh's [FAIL] <suite> verdict rows are line-initial and uncolored"
else
  # grep -P may be unavailable on some hosts; fall back to a portable ANSI-escape probe for the
  # color-freedom half of the assertion so this case cannot spuriously fail on a missing -P flag.
  if printf '%s\n' "$noflag_out" | grep -qE '^\[FAIL\] .*test-fx-fail1\.sh$' \
     && printf '%s\n' "$noflag_out" | grep -qE '^\[FAIL\] .*test-fx-fail2\.sh$' \
     && ! printf '%s\n' "$noflag_out" | od -c | grep -q '033   \['; then
    common_test_pass "case10: run-all.sh's [FAIL] <suite> verdict rows are line-initial and uncolored (portable probe)"
  else
    common_test_fail "case10: run-all.sh's [FAIL] <suite> verdict row shape regressed" "$noflag_out"
  fi
fi

# =====================================================================================
# PART 4 -- RUN_ALL_SUITE_TIMEOUT_S (Phase 6, "Uniform Bounded Timeouts Per Gate and Per
# Suite"): the deliberately-stalled fixture, both sequential and parallel paths, and the
# SIGTERM-ignoring escalation case proving -k 5's SIGKILL path actually fires.
# =====================================================================================

cat > "$TESTS_DIR/test-fx-stall.sh" << 'EOF'
#!/usr/bin/env bash
sleep 30
exit 0
EOF
chmod +x "$TESTS_DIR/test-fx-stall.sh"

# Case 11: sequential (--jobs 1) per-suite timeout fires, names the suite and the exact bound,
# and finishes well within the bound plus a small margin -- never the full 30s sleep.
t0=$(date +%s%3N)
stall_out="$(RUN_ALL_SUITE_TIMEOUT_S=2 bash "$FIXTURE_RUNNER" --quiet --jobs 1 --only "test-fx-stall.sh" 2>&1)"
stall_rc=$?
t1=$(date +%s%3N)
stall_ms=$((t1 - t0))
if [ "$stall_rc" -eq 1 ] \
   && printf '%s\n' "$stall_out" | grep -qE '^\[FAIL\] .*test-fx-stall\.sh$' \
   && printf '%s\n' "$stall_out" | grep -qF "TIMEOUT: $TESTS_DIR/test-fx-stall.sh exceeded the 2s per-suite bound and was killed" \
   && [ "$stall_ms" -lt 8000 ]; then
  common_test_pass "case11: sequential per-suite timeout fires, names the suite and the 2s bound, within margin (${stall_ms}ms)"
else
  common_test_fail "case11: sequential per-suite timeout did not fire as expected (rc=$stall_rc, elapsed=${stall_ms}ms)" "$stall_out"
fi

# Case 12: parallel (--jobs 2) per-suite timeout kills only the stalled suite -- the sibling
# suite still completes normally, and the run reaches a stable summary line rather than
# aborting the whole battery over one stalled suite.
par_out="$(RUN_ALL_SUITE_TIMEOUT_S=2 bash "$FIXTURE_RUNNER" --quiet --jobs 2 --only "test-fx-stall.sh,test-fx-pass1.sh" 2>&1)"
par_rc=$?
if [ "$par_rc" -eq 1 ] \
   && printf '%s\n' "$par_out" | grep -qE '^\[FAIL\] .*test-fx-stall\.sh$' \
   && printf '%s\n' "$par_out" | grep -qF "TIMEOUT:" \
   && printf '%s\n' "$par_out" | grep -qF "1 passed, 1 failed (0 expected, 1 NEW), 0 skipped, 2 total"; then
  common_test_pass "case12: parallel per-suite timeout kills only the stalled suite; the sibling suite still completes and the run reaches a stable summary"
else
  common_test_fail "case12: parallel per-suite timeout did not isolate correctly (rc=$par_rc)" "$par_out"
fi

# Case 13: a suite that explicitly ignores SIGTERM is still terminated within a small margin of
# the bound, via `timeout -k 5`'s escalation to SIGKILL -- proving the escalation genuinely
# fires rather than merely being configured. `timeout --help`'s own documented exit-status
# contract gives 137 (128+SIGKILL) for this path, distinct from 124's "SIGTERM was enough".
cat > "$TESTS_DIR/test-fx-stall-ignoreterm.sh" << 'EOF'
#!/usr/bin/env bash
trap '' TERM
sleep 30
exit 0
EOF
chmod +x "$TESTS_DIR/test-fx-stall-ignoreterm.sh"

t0=$(date +%s%3N)
ign_out="$(RUN_ALL_SUITE_TIMEOUT_S=1 bash "$FIXTURE_RUNNER" --quiet --jobs 1 --only "test-fx-stall-ignoreterm.sh" 2>&1)"
ign_rc=$?
t1=$(date +%s%3N)
ign_ms=$((t1 - t0))
if [ "$ign_rc" -eq 1 ] \
   && printf '%s\n' "$ign_out" | grep -qF "TIMEOUT:" \
   && [ "$ign_ms" -lt 15000 ]; then
  common_test_pass "case13: a SIGTERM-ignoring suite is still killed via -k 5's SIGKILL escalation (${ign_ms}ms, not the full 30s sleep)"
else
  common_test_fail "case13: SIGTERM-ignoring suite was not reliably killed (rc=$ign_rc, elapsed=${ign_ms}ms)" "$ign_out"
fi

# =====================================================================================
# PART 5 -- --class / --tag / --cost-class selection (Phase 14). Library-level correctness runs
# against the REAL corpus (suite-selection-lib.sh's new axis functions, already sourced for
# Part 1 above); run-all.sh flag-level validation/composition runs against a FIXTURE carrying its
# own minimal suite-classification.data and suite-cost-hints.txt, never the real corpus's.
# =====================================================================================

# Case 14: suite_selection_known_classes against the real corpus returns exactly {unit, integration}.
known_classes_out="$(suite_selection_known_classes)"
if printf '%s\n' "$known_classes_out" | grep -qx "unit" \
   && printf '%s\n' "$known_classes_out" | grep -qx "integration" \
   && [ "$(printf '%s\n' "$known_classes_out" | grep -c .)" -eq 2 ]; then
  common_test_pass "case14: suite_selection_known_classes returns exactly {unit, integration}"
else
  common_test_fail "case14: suite_selection_known_classes did not return exactly {unit, integration}" "$known_classes_out"
fi

# Case 15: suite_selection_by_class unit vs. integration are non-empty and disjoint (coverage of
# every discovered suite is lint-unit-integration-boundary.sh's own separate concern).
unit_out="$(suite_selection_by_class unit)"
integ_out="$(suite_selection_by_class integration)"
unit_count="$(printf '%s\n' "$unit_out" | grep -c .)"
integ_count="$(printf '%s\n' "$integ_out" | grep -c .)"
overlap_count="$(comm -12 <(printf '%s\n' "$unit_out" | sort) <(printf '%s\n' "$integ_out" | sort) | grep -c .)"
if [ "$unit_count" -gt 0 ] && [ "$integ_count" -gt 0 ] && [ "$overlap_count" -eq 0 ]; then
  common_test_pass "case15: suite_selection_by_class unit ($unit_count) and integration ($integ_count) are non-empty and disjoint"
else
  common_test_fail "case15: unit/integration selection sanity failed (unit=$unit_count, integration=$integ_count, overlap=$overlap_count)"
fi

# Case 16: suite_selection_known_tags includes "lint" (mechanically derived from the real,
# non-empty test-lint-*.sh population) plus at least one invoked-tool-derived tag.
known_tags_out="$(suite_selection_known_tags)"
if printf '%s\n' "$known_tags_out" | grep -qx "lint" \
   && [ "$(printf '%s\n' "$known_tags_out" | grep -c .)" -ge 2 ]; then
  common_test_pass "case16: suite_selection_known_tags includes 'lint' plus at least one invoked-tool tag"
else
  common_test_fail "case16: suite_selection_known_tags did not include the expected tag set" "$known_tags_out"
fi

# Case 17: suite_selection_by_tag lint selects only suites actually named test-lint-*.sh.
tag_lint_out="$(suite_selection_by_tag lint)"
bad_lint_count=0
while IFS= read -r _tl; do
  [ -n "$_tl" ] || continue
  case "$_tl" in test-lint-*.sh) ;; *) bad_lint_count=$((bad_lint_count + 1)) ;; esac
done <<< "$tag_lint_out"
if [ "$bad_lint_count" -eq 0 ] && [ -n "$tag_lint_out" ]; then
  common_test_pass "case17: suite_selection_by_tag lint selects only test-lint-*.sh suites"
else
  common_test_fail "case17: suite_selection_by_tag lint selected $bad_lint_count non-lint suite(s)" "$tag_lint_out"
fi

# Case 18: suite_selection_known_cost_classes is the fixed closed vocabulary.
known_cost_out="$(suite_selection_known_cost_classes)"
expected_cost_out="$(printf '%s\n' free moderate slow unknown)"
if [ "$known_cost_out" = "$expected_cost_out" ]; then
  common_test_pass "case18: suite_selection_known_cost_classes is exactly {free, moderate, slow, unknown}"
else
  common_test_fail "case18: suite_selection_known_cost_classes did not match the fixed vocabulary" "$known_cost_out"
fi

# Fixture additions for the run-all.sh flag-level cases below: the real suite-selection-lib.sh
# COPIED into the fixture's own lib/ sibling (mirroring how run-all.sh itself is copied above) --
# the fixture's FIXTURE_RUNNER resolves it at "$SCRIPT_DIR/../lib/suite-selection-lib.sh" exactly
# as the real run-all.sh does, so --class/--tag/--cost-class need it present at that path -- plus
# a minimal suite-classification.data and suite-cost-hints.txt scoped to THIS fixture's own
# suites only, never the real corpus's files.
mkdir -p "$EXT_ROOT/core/scripts/lib"
cp "$CORE_DIR/lib/suite-selection-lib.sh" "$EXT_ROOT/core/scripts/lib/suite-selection-lib.sh"

# A basename-tagged "lint" fixture suite, unit-classified -- gives case25 below a value ("lint")
# that IS a recognized tag in THIS fixture's own vocabulary, so its empty-intersection case tests
# AND-composition genuinely (two recognized-but-non-overlapping values), not an unknown-token
# refusal that would short-circuit before composition is ever exercised.
cat > "$TESTS_DIR/test-lint-fx.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TESTS_DIR/test-lint-fx.sh"

printf 'test-fx-pass1.sh\tunit\t-\n' > "$TESTS_DIR/suite-classification.data"
printf 'test-fx-pass2.sh\tunit\t-\n' >> "$TESTS_DIR/suite-classification.data"
printf 'test-fx-fail1.sh\tintegration\tinvokes:deploy-headless.sh\n' >> "$TESTS_DIR/suite-classification.data"
printf 'test-fx-fail2.sh\tintegration\tinvokes:verify-deploy.sh\n' >> "$TESTS_DIR/suite-classification.data"
printf 'test-lint-fx.sh\tunit\t-\n' >> "$TESTS_DIR/suite-classification.data"

printf 'test-fx-pass1.sh,500\n' > "$TESTS_DIR/suite-cost-hints.txt"
printf 'test-fx-pass2.sh,500\n' >> "$TESTS_DIR/suite-cost-hints.txt"
printf 'test-fx-fail1.sh,500\n' >> "$TESTS_DIR/suite-cost-hints.txt"
printf 'test-fx-fail2.sh,50000\n' >> "$TESTS_DIR/suite-cost-hints.txt"
# test-fx-flat1.sh is deliberately left unhinted -- exercises the "unknown" cost-class bucket.

# Case 19: --class unit intersects with --only to select exactly the fixture's 2 unit-class
# suites, excluding the integration-class pair.
class_out="$(bash "$FIXTURE_RUNNER" --quiet --class unit --only "test-fx-pass1.sh,test-fx-pass2.sh,test-fx-fail1.sh,test-fx-fail2.sh" 2>&1)"
class_rc=$?
if [ "$class_rc" -eq 0 ] \
   && printf '%s\n' "$class_out" | grep -qF "2 passed, 0 failed (0 expected, 0 NEW), 0 skipped, 2 total"; then
  common_test_pass "case19: --class unit intersects with --only to select exactly the 2 unit-class fixture suites"
else
  common_test_fail "case19: --class unit did not select the expected 2-suite subset (rc=$class_rc)" "$class_out"
fi

# Case 20: --class with an unknown value refuses the whole run (exit 2), names the token, runs
# nothing -- mirrors --only's own refuse-loudly discipline.
bad_class_out="$(bash "$FIXTURE_RUNNER" --quiet --class bogus-class --only "test-fx-pass1.sh" 2>&1)"
bad_class_rc=$?
if [ "$bad_class_rc" -eq 2 ] \
   && printf '%s\n' "$bad_class_out" | grep -qF "bogus-class" \
   && ! printf '%s\n' "$bad_class_out" | grep -q '\[RUN\]'; then
  common_test_pass "case20: --class with an unknown value refuses the whole run, names the token, runs nothing"
else
  common_test_fail "case20: --class bogus-class did not refuse cleanly (rc=$bad_class_rc)" "$bad_class_out"
fi

# Case 21: --tag with an unknown value refuses the whole run (exit 2), names the token.
bad_tag_out="$(bash "$FIXTURE_RUNNER" --quiet --tag bogus-tag --only "test-fx-pass1.sh" 2>&1)"
bad_tag_rc=$?
if [ "$bad_tag_rc" -eq 2 ] \
   && printf '%s\n' "$bad_tag_out" | grep -qF "bogus-tag" \
   && ! printf '%s\n' "$bad_tag_out" | grep -q '\[RUN\]'; then
  common_test_pass "case21: --tag with an unknown value refuses the whole run, names the token, runs nothing"
else
  common_test_fail "case21: --tag bogus-tag did not refuse cleanly (rc=$bad_tag_rc)" "$bad_tag_out"
fi

# Case 22: --cost-class with an unknown value refuses the whole run (exit 2), names the token.
bad_cost_out="$(bash "$FIXTURE_RUNNER" --quiet --cost-class bogus-cost --only "test-fx-pass1.sh" 2>&1)"
bad_cost_rc=$?
if [ "$bad_cost_rc" -eq 2 ] \
   && printf '%s\n' "$bad_cost_out" | grep -qF "bogus-cost" \
   && ! printf '%s\n' "$bad_cost_out" | grep -q '\[RUN\]'; then
  common_test_pass "case22: --cost-class with an unknown value refuses the whole run, names the token, runs nothing"
else
  common_test_fail "case22: --cost-class bogus-cost did not refuse cleanly (rc=$bad_cost_rc)" "$bad_cost_out"
fi

# Case 23: --cost-class slow selects the one fixture suite hinted above the slow threshold
# (test-fx-fail2.sh, 50000ms), excluding its cheaper sibling. test-fx-fail2.sh is not registered
# in this fixture's known-failures.txt, so it classifies NEW.
costslow_out="$(bash "$FIXTURE_RUNNER" --quiet --cost-class slow --only "test-fx-pass1.sh,test-fx-fail2.sh" 2>&1)"
costslow_rc=$?
if [ "$costslow_rc" -eq 1 ] \
   && printf '%s\n' "$costslow_out" | grep -qF "0 passed, 1 failed (0 expected, 1 NEW), 0 skipped, 1 total"; then
  common_test_pass "case23: --cost-class slow selects exactly the one hinted-slow fixture suite"
else
  common_test_fail "case23: --cost-class slow did not select the expected 1-suite subset (rc=$costslow_rc)" "$costslow_out"
fi

# Case 24: --cost-class unknown selects a fixture suite the hints file never covers
# (test-fx-flat1.sh), excluding a hinted sibling.
costunknown_out="$(bash "$FIXTURE_RUNNER" --quiet --cost-class unknown --only "test-fx-pass1.sh,test-fx-flat1.sh" 2>&1)"
costunknown_rc=$?
if [ "$costunknown_rc" -eq 0 ] \
   && printf '%s\n' "$costunknown_out" | grep -qF "1 passed, 0 failed (0 expected, 0 NEW), 0 skipped, 1 total"; then
  common_test_pass "case24: --cost-class unknown selects exactly the one un-hinted fixture suite"
else
  common_test_fail "case24: --cost-class unknown did not select the expected 1-suite subset (rc=$costunknown_rc)" "$costunknown_out"
fi

# Case 25: --class + --tag compose by intersection (AND), not union (OR). Among the 3 selected
# fixture suites, test-fx-fail1.sh/test-fx-fail2.sh satisfy --class integration but not --tag lint
# (not named test-lint-*.sh), and test-lint-fx.sh satisfies --tag lint but not --class integration
# (classified unit above) -- no single suite satisfies BOTH at once, so the intersection must be
# empty, which run-all.sh reports as a harness failure (exit 2, zero discovered), never a silent
# partial run that happened to pick one axis over the other.
intersect_out="$(bash "$FIXTURE_RUNNER" --quiet --class integration --tag lint --only "test-fx-fail1.sh,test-fx-fail2.sh,test-lint-fx.sh" 2>&1)"
intersect_rc=$?
if [ "$intersect_rc" -eq 2 ] && printf '%s\n' "$intersect_out" | grep -q "zero test suites discovered"; then
  common_test_pass "case25: --class + --tag compose by intersection (an empty intersection is a harness failure, not a silent partial run)"
else
  common_test_fail "case25: --class integration --tag lint under --only did not behave as an empty-intersection harness failure (rc=$intersect_rc)" "$intersect_out"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
