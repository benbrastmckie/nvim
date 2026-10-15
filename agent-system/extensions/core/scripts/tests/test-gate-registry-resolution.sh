#!/usr/bin/env bash
# test-gate-registry-resolution.sh - Regression suite for scripts/lib/gate-registry-lib.sh, the
# thin interpreter over scripts/gate-registry.data. See that library's own header for the full
# contract (deliberately thin: look up a function name, call it -- no generic guard/output fold).
#
# Coverage:
#   - gate_registry_load parses the REAL gate-registry.data into the documented 7 fields per id.
#   - gate_registry_ids returns the loaded ids, space-separated, ascending.
#   - gate_registry_execute calls the registered function directly (in-process, not a subshell --
#     confirmed by having the called function mutate a caller-scope variable and observing the
#     mutation survive the call).
#   - gate_registry_field returns empty (not an error) for an unknown id or field.
#   - The "-" empty-dependency placeholder normalizes to a truly empty string, not the literal
#     "-" -- this is the regression pin for the TSV-empty-field-collapse defect found and fixed
#     during this task's own Phase 4 (IFS=$'\t' read silently shifts every later column when a
#     field between two tabs is genuinely empty, because bash classifies tab as IFS-whitespace
#     even as IFS's sole member).
#   - A synthetic registry with a genuinely malformed id (non-numeric) is skipped, not aborted.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# library was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$CORE_DIR/lib/gate-registry-lib.sh"
REAL_DATA="$CORE_DIR/gate-registry.data"

if [ ! -f "$LIB" ]; then
  echo "ERROR: expected $LIB" >&2
  exit 2
fi
if [ ! -f "$REAL_DATA" ]; then
  echo "ERROR: expected $REAL_DATA" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$LIB"

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); [ -n "${2:-}" ] && echo "$2"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ─── Case 1-7: load the REAL registry and confirm the documented shape ──────────────────────────
gate_registry_load "$REAL_DATA"

ids="$(gate_registry_ids)"
expected_ids="$(seq 1 23 | tr '\n' ' ' | sed 's/ $//')"
if [ "$ids" = "$expected_ids " ] || [ "$ids" = "$expected_ids" ]; then
  pass "case1: gate_registry_ids returns the real registry's 23 migrated ids, ascending (1-23, Phase 5 completed the migration)"
else
  fail "case1: unexpected ids from the real registry (got: '$ids')"
fi

if [ "$(gate_registry_field 3 invoke)" = "gate3_run" ]; then
  pass "case2: gate_registry_field resolves gate 3's invoke function correctly"
else
  fail "case2: gate 3 invoke mismatch (got: '$(gate_registry_field 3 invoke)')"
fi

if [ "$(gate_registry_field 8 serialized)" = "true" ] && [ "$(gate_registry_field 1 serialized)" = "false" ]; then
  pass "case3: gate_registry_field resolves the serialized flag correctly (gate8=true, gate1=false)"
else
  fail "case3: serialized flag mismatch (gate8='$(gate_registry_field 8 serialized)' gate1='$(gate_registry_field 1 serialized)')"
fi

if [ "$(gate_registry_field 3 requires_source_store)" = "true" ] && [ "$(gate_registry_field 1 requires_source_store)" = "false" ]; then
  pass "case4: gate_registry_field resolves requires_source_store correctly (gate3=true, gate1=false)"
else
  fail "case4: requires_source_store mismatch"
fi

timeout8="$(gate_registry_field 8 timeout_s)"
case "$timeout8" in
  ''|*[!0-9]*) fail "case5: gate 8's timeout_s is not a positive integer (got: '$timeout8')" ;;
  *)
    if [ "$timeout8" -gt 0 ]; then
      pass "case5: gate 8's timeout_s is a positive integer ($timeout8)"
    else
      fail "case5: gate 8's timeout_s is not > 0 (got: $timeout8)"
    fi
    ;;
esac

# Case 6 -- the TSV-empty-field-collapse regression pin: every gate's dependencies field must
# normalize to a truly empty string, never the literal on-disk "-" placeholder leaking through,
# and (indirectly) every LATER field must still resolve to its own correct value rather than a
# neighboring field's value shifted into it by a collapsed empty-field delimiter.
deps_leaked=false
fields_shifted=false
for id in $(gate_registry_ids); do
  d="$(gate_registry_field "$id" dependencies)"
  if [ "$d" = "-" ]; then
    deps_leaked=true
  fi
  class="$(gate_registry_field "$id" cost_class)"
  case "$class" in
    free|moderate|slow) : ;;
    *) fields_shifted=true ;;
  esac
done
if ! $deps_leaked && ! $fields_shifted; then
  pass "case6: the '-' empty-dependency placeholder normalizes to empty, and no field shifted into cost_class's slot (TSV-collapse regression pin)"
else
  fail "case6: TSV-collapse regression -- deps_leaked=$deps_leaked fields_shifted=$fields_shifted"
fi

# Case 7 -- gate_registry_field returns empty (not an error, no abort) for an unknown id/field.
unk_id="$(gate_registry_field 9999 invoke)"
unk_field="$(gate_registry_field 1 not_a_real_field)"
if [ -z "$unk_id" ] && [ -z "$unk_field" ]; then
  pass "case7: an unknown id or field resolves to empty, not an error"
else
  fail "case7: expected empty for unknown id/field (got id='$unk_id' field='$unk_field')"
fi

# ─── Case 8: gate_registry_execute calls the function directly (in-process, not a subshell) ────
TEST_MUTATION_PROBE=""
test_probe_fn() { TEST_MUTATION_PROBE="mutated"; }
SYNTH1="$WORKDIR/synth1.data"
printf '1\tprobe gate\ttest_probe_fn\t-\tfalse\t30\tfree\tfalse\n' > "$SYNTH1"
gate_registry_load "$SYNTH1"
gate_registry_execute 1
if [ "$TEST_MUTATION_PROBE" = "mutated" ]; then
  pass "case8: gate_registry_execute calls the registered function in-process (mutation observed by caller)"
else
  fail "case8: gate_registry_execute did not call the function in-process (TEST_MUTATION_PROBE='$TEST_MUTATION_PROBE')"
fi

# ─── Case 9: an id with no registered function (or a registry that was never loaded for that id)
# is a silent no-op, never an error / abort. ─────────────────────────────────────────────────────
gate_registry_execute 9999
if [ $? -eq 0 ]; then
  pass "case9: gate_registry_execute on an unregistered id is a silent no-op (no abort)"
else
  fail "case9: gate_registry_execute on an unregistered id did not return 0"
fi

# ─── Case 10: a malformed (non-numeric) id row is skipped during load, not aborted, and does not
# poison the ids array. ──────────────────────────────────────────────────────────────────────────
SYNTH2="$WORKDIR/synth2.data"
printf 'abc\tbad row\tsomefn\t-\tfalse\t30\tfree\tfalse\n2\tgood row\ttest_probe_fn\t-\tfalse\t30\tfree\tfalse\n' > "$SYNTH2"
gate_registry_load "$SYNTH2"
ids2="$(gate_registry_ids)"
if [ "$ids2" = "2" ] || [ "$ids2" = "2 " ]; then
  pass "case10: a malformed (non-numeric) id row is skipped during load, leaving only the valid row"
else
  fail "case10: expected only id 2 after skipping the malformed row (got: '$ids2')"
fi

# Restore the real registry for any downstream consumer of this same shell (defensive; this
# suite's own process exits right after, but mirrors good hygiene).
gate_registry_load "$REAL_DATA"

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
