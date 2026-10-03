#!/usr/bin/env bash
# test-books-gate.sh - Narrow, fixture-driven suite for books-gate.sh.
#
# Per context/standards/shell-script-testing.md: fixtures are constructed inline via a mktemp -d
# workdir (each made into its own git repo, since books-gate.sh resolves the repository root via
# `git rev-parse --show-toplevel` when --root is not given) created at suite start; nothing here
# depends on the external consuming repository or on any real specs/ tree. Class B strict mode
# (this is a PASSED/FAILED-counter harness that must report every case, not abort on the first
# failure).
#
# Every expected status string below is a MEASURED behaviour of the real tooling, not an
# invention: the vacuous-pass case reproduces a 0-of-9 rule match observed live, and the
# ambiguous-exit-1 case reproduces the rule-set library's `exit 1`-while-being-sourced.
#
# FORGERY PROBES. Each predicate carries a probe that stubs the predicate out and asserts the
# suite's own expectation then FAILS. A test that would pass against a stubbed predicate proves
# nothing, and this suite would be exactly such a test without these probes. See the books
# context corpus's forgery-probe discipline
# (`context/project/books/standards/forgery-probe-discipline.md`).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="${SCRIPT_DIR}/../books-gate.sh"

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
  echo "test-books-gate.sh: jq is required to read the wrapper's JSON output" >&2
  exit 2
fi

# assert_exit CASE_NAME EXPECTED_EXIT ACTUAL_EXIT
assert_exit() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    pass "${name}: exit code ${actual} (expected ${expected})"
  else
    fail "${name}: exit code ${actual}, expected ${expected}"
  fi
}

# assert_json CASE_NAME JSON JQ_FILTER EXPECTED
assert_json() {
  local name="$1" json="$2" filter="$3" expected="$4" actual
  actual="$(printf '%s' "$json" | jq -r "$filter" 2>/dev/null)"
  if [[ "$actual" == "$expected" ]]; then
    pass "${name}: ${filter} == ${expected}"
  else
    fail "${name}: ${filter} == '${actual}', expected '${expected}'"
    info "  --- actual JSON ---"
    while IFS= read -r line; do info "  $line"; done <<< "$json"
  fi
}

# assert_json_wellformed CASE_NAME JSON
assert_json_wellformed() {
  local name="$1" json="$2"
  if printf '%s' "$json" | jq -e . >/dev/null 2>&1; then
    pass "${name}: stdout is one well-formed JSON object"
  else
    fail "${name}: stdout is NOT well-formed JSON"
    info "  --- actual stdout ---"
    while IFS= read -r line; do info "  $line"; done <<< "$json"
  fi
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ─── Fixture builders ──────────────────────────────────────────────────────────────────────────
# install_rule_set DIR [MODE]
#   Installs a fixture interface/scripts/{layer-lint.sh,layer-rules.sh} pair whose rule set has
#   exactly two rules, both of whose file halves name `interface/lean/`. MODE=exit-on-source makes
#   the rule library `exit 1` while being sourced, with the real library's own stderr wording --
#   the ambiguity the wrapper must disambiguate from a real violation.
install_rule_set() {
  local dir="$1" mode="${2:-normal}"
  mkdir -p "${dir}/interface/scripts"
  if [[ "$mode" == "exit-on-source" ]]; then
    cat > "${dir}/interface/scripts/layer-rules.sh" <<'EOF'
#!/usr/bin/env bash
# Fixture rule library that fails while being SOURCED, as the real one does when its queue-model
# derivation yields nothing. A `.`-sourcing includer is terminated by this exit.
echo "layer-rules.sh: no queue model found under components/framed_channel/lean/FramedChannel/Model (fixture)" >&2
exit 1
EOF
  else
    cat > "${dir}/interface/scripts/layer-rules.sh" <<'EOF'
#!/usr/bin/env bash
# Fixture rule library: two rules, both file halves scoped to interface/lean/.
LAYER_RULES=(
  '^interface/lean/Interface/Spec/;^Forbidden\.One($|\.);a specification may not depend on Forbidden.One'
)
LAYER_ALLOW_RULES=(
  '^interface/lean/Interface/Defs/;^Allowed\.Only($|\.);a definitions module may import only Allowed.Only'
)
EOF
  fi
  cat > "${dir}/interface/scripts/layer-lint.sh" <<'EOF'
#!/usr/bin/env bash
# Fixture layer lint: the real driver's argument, exit-code and output contract, applied by a
# deliberately trivial matcher. Exit 0 no violations, 1 violations (or a rule-library source
# failure, which terminates this script with the same code), 2 usage error.
set -u
if [ $# -eq 0 ]; then
  echo "layer-lint.sh: usage: bash layer-lint.sh PACKAGE_ROOT..." >&2
  exit 2
fi
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/layer-rules.sh"
for pkg in "$@"; do
  if [ ! -d "$ROOT/$pkg" ]; then
    echo "layer-lint.sh: no such package root: $pkg" >&2
    exit 2
  fi
done
failures=0
files=0
imports=0
for pkg in "$@"; do
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    files=$((files + 1))
    imports=$((imports + $(grep -cE '^[[:space:]]*(public[[:space:]]+)?(meta[[:space:]]+)?import[[:space:]]' "$ROOT/$rel" || true)))
    for r in "${LAYER_RULES[@]}"; do
      fh="${r%%;*}"
      rest="${r#*;}"
      ih="${rest%%;*}"
      printf '%s\n' "$rel" | grep -qE "$fh" || continue
      while IFS= read -r imp; do
        [ -n "$imp" ] || continue
        if printf '%s\n' "$imp" | grep -qE "$ih"; then
          echo "[FAIL] $rel imports $imp"
          failures=$((failures + 1))
        fi
      done <<< "$(sed -n 's/^[[:space:]]*\(public[[:space:]]\{1,\}\)\{0,1\}\(meta[[:space:]]\{1,\}\)\{0,1\}import[[:space:]]\{1,\}\([A-Za-z0-9_.]\{1,\}\).*/\3/p' "$ROOT/$rel")"
    done
  done <<< "$(cd "$ROOT" && find "$pkg" -name '*.lean' -not -path '*/.lake/*' | LC_ALL=C sort)"
done
if [ $failures -ne 0 ]; then
  echo "layer-lint.sh: $failures layer import violation(s)"
  exit 1
fi
echo "[ok] layer import rule ($files modules, $imports imports, ${#LAYER_RULES[@]} exclusion rules, ${#LAYER_ALLOW_RULES[@]} allow-only rules; queue models derived: fixture; package roots: $*)"
EOF
}

# install_provider DIR -- the Books.Meta provider package, with the zero-require invariant held.
install_provider() {
  local dir="$1"
  mkdir -p "${dir}/books/lean/Books"
  cat > "${dir}/books/lean/lakefile.toml" <<'EOF'
name = "books"
# There is deliberately NO require here: the module builds against core Lean alone.
EOF
  printf 'public meta import Lean\n' > "${dir}/books/lean/Books/Meta.lean"
}

# ─── Case 1: lint script absent -> lint_unavailable, wrapper exit 0 ────────────────────────────
info "Case 1: lint script absent in the fixture root"
repo1="${WORKDIR}/no-lint"
mkdir -p "${repo1}/interface/lean"
(cd "$repo1" && git init -q)
out1="$("$WRAPPER" --json --root "$repo1" 2>/dev/null)"
exit1=$?
assert_exit "case1-lint-absent" 0 "$exit1"
assert_json_wellformed "case1-lint-absent" "$out1"
assert_json "case1-lint-absent" "$out1" '.layer_lint.status' "lint_unavailable"

# ─── Case 2: a root no rule's file-half reaches -> pass_vacuous, rules_matched 0, never pass ───
info "Case 2: a fixture root no rule's file-half can reach"
repo2="${WORKDIR}/vacuous"
install_rule_set "$repo2"
install_provider "$repo2"
mkdir -p "${repo2}/components/unreached/lean/Unreached"
printf 'import Something.Else\n' > "${repo2}/components/unreached/lean/Unreached/A.lean"
(cd "$repo2" && git init -q)
out2="$("$WRAPPER" --json --root "$repo2" --package-root components/unreached 2>/dev/null)"
exit2=$?
assert_exit "case2-vacuous" 0 "$exit2"
assert_json "case2-vacuous" "$out2" '.layer_lint.status' "pass_vacuous"
assert_json "case2-vacuous" "$out2" '.layer_lint.rules_matched' "0"
assert_json "case2-vacuous" "$out2" '.layer_lint.rules_total' "2"
if [[ "$(printf '%s' "$out2" | jq -r '.layer_lint.status')" == "pass" ]]; then
  fail "case2-vacuous-not-collapsed: a vacuous pass was reported as a plain pass"
else
  pass "case2-vacuous-not-collapsed: a vacuous pass is never reported as a plain pass"
fi

# ─── Case 3: a root every rule reaches, no violation planted -> pass, matched == total ─────────
info "Case 3: a fixture root every rule reaches, nothing planted"
repo3="${WORKDIR}/clean"
install_rule_set "$repo3"
install_provider "$repo3"
mkdir -p "${repo3}/interface/lean/Interface/Spec" "${repo3}/interface/lean/Interface/Defs"
printf 'import Books.Meta\nimport Interface.Other\n' > "${repo3}/interface/lean/Interface/Spec/A.lean"
printf 'import Allowed.Only\n' > "${repo3}/interface/lean/Interface/Defs/B.lean"
(cd "$repo3" && git init -q)
out3="$("$WRAPPER" --json --root "$repo3" --package-root interface 2>/dev/null)"
exit3=$?
assert_exit "case3-clean" 0 "$exit3"
assert_json "case3-clean" "$out3" '.layer_lint.status' "pass"
assert_json "case3-clean" "$out3" '.layer_lint.rules_matched' "2"
assert_json "case3-clean" "$out3" '.layer_lint.rules_total' "2"
assert_json "case3-clean" "$out3" '.layer_lint.violation_count' "0"

# ─── Case 4: rule library exits 1 while being sourced -> rule_set_error, not violations ───────
info "Case 4: a fixture rule library that exit 1s on source"
repo4="${WORKDIR}/rule-set-error"
install_rule_set "$repo4" exit-on-source
install_provider "$repo4"
mkdir -p "${repo4}/interface/lean/Interface/Spec"
printf 'import Books.Meta\n' > "${repo4}/interface/lean/Interface/Spec/A.lean"
(cd "$repo4" && git init -q)
out4="$("$WRAPPER" --json --root "$repo4" --package-root interface 2>/dev/null)"
exit4=$?
assert_exit "case4-rule-set-error" 0 "$exit4"
assert_json "case4-rule-set-error" "$out4" '.layer_lint.status' "rule_set_error"
if [[ "$(printf '%s' "$out4" | jq -r '.layer_lint.status')" == "violations" ]]; then
  fail "case4-exit1-disambiguated: a rule-library source failure was read as violations"
else
  pass "case4-exit1-disambiguated: exit 1 from a rule-library source failure is NOT read as violations"
fi
# The wrapper's own shell survived the library's exit, which only a subshell makes possible.
assert_json_wellformed "case4-subshell-proof" "$out4"

# ─── Case 5: lint invoked with an absent named root -> usage_error, wrapper exit 0 ─────────────
info "Case 5: lint invoked with an absent named package root"
repo5="${WORKDIR}/usage-error"
install_rule_set "$repo5"
install_provider "$repo5"
mkdir -p "${repo5}/interface/lean"
(cd "$repo5" && git init -q)
out5="$("$WRAPPER" --json --root "$repo5" --package-root nosuchdir 2>/dev/null)"
exit5=$?
assert_exit "case5-usage-error" 0 "$exit5"
assert_json "case5-usage-error" "$out5" '.layer_lint.status' "usage_error"

# ─── Case 5b: the wrapper's OWN argument error is a real exit 2, distinct from the above ──────
info "Case 5b: the wrapper's own unknown-argument error"
set +e
"$WRAPPER" --json --definitely-not-a-flag >/dev/null 2>&1
exit5b=$?
set -e
assert_exit "case5b-wrapper-usage-error" 2 "$exit5b"

# ─── Case 6: a planted public import of the provider -> exactly one closure violation ─────────
info "Case 6: a planted public import of the provider"
repo6="${WORKDIR}/public-import"
install_rule_set "$repo6"
install_provider "$repo6"
mkdir -p "${repo6}/interface/lean/Interface/Book"
printf 'public import Books.Meta\n' > "${repo6}/interface/lean/Interface/Book/Bad.lean"
(cd "$repo6" && git init -q)
out6="$("$WRAPPER" --json --root "$repo6" --package-root interface 2>/dev/null)"
exit6=$?
assert_exit "case6-public-import" 0 "$exit6"
assert_json "case6-public-import" "$out6" '.books_meta_closure.status' "violations"
assert_json "case6-public-import" "$out6" '.books_meta_closure.public_import_violation_count' "1"
assert_json "case6-public-import" "$out6" '.books_meta_closure.public_import_violations[0]' \
  "interface/lean/Interface/Book/Bad.lean"

# ─── Case 6b: the `public meta import` form is caught too ─────────────────────────────────────
info "Case 6b: the public meta import form"
repo6b="${WORKDIR}/public-meta-import"
install_rule_set "$repo6b"
install_provider "$repo6b"
mkdir -p "${repo6b}/interface/lean/Interface/Book"
printf 'public meta import Books.Meta\n' > "${repo6b}/interface/lean/Interface/Book/Bad.lean"
(cd "$repo6b" && git init -q)
out6b="$("$WRAPPER" --json --root "$repo6b" --package-root interface 2>/dev/null)"
assert_json "case6b-public-meta-import" "$out6b" '.books_meta_closure.public_import_violation_count' "1"

# ─── Case 7 (negative): the same planted import under specs/ is NOT a violation ───────────────
info "Case 7 (negative): the same planted public import under a specs/-prefixed path"
repo7="${WORKDIR}/specs-pruned"
install_rule_set "$repo7"
install_provider "$repo7"
mkdir -p "${repo7}/interface/lean/Interface/Book" "${repo7}/specs/archive/prototype/Books"
printf 'import Books.Meta\n' > "${repo7}/interface/lean/Interface/Book/Good.lean"
printf 'public import Books.Meta\n' > "${repo7}/specs/archive/prototype/Books/Compose.lean"
(cd "$repo7" && git init -q)
out7="$("$WRAPPER" --json --root "$repo7" --package-root interface 2>/dev/null)"
assert_json "case7-specs-pruned" "$out7" '.books_meta_closure.status' "pass"
assert_json "case7-specs-pruned" "$out7" '.books_meta_closure.public_import_violation_count' "0"

# ─── Case 8 (negative): the same planted import under .lake/ is NOT a violation ───────────────
info "Case 8 (negative): the same planted public import under a .lake/-prefixed path"
repo8="${WORKDIR}/lake-pruned"
install_rule_set "$repo8"
install_provider "$repo8"
mkdir -p "${repo8}/interface/lean/Interface/Book" "${repo8}/interface/.lake/build/Dep"
printf 'import Books.Meta\n' > "${repo8}/interface/lean/Interface/Book/Good.lean"
printf 'public import Books.Meta\n' > "${repo8}/interface/.lake/build/Dep/Vendored.lean"
(cd "$repo8" && git init -q)
out8="$("$WRAPPER" --json --root "$repo8" --package-root interface 2>/dev/null)"
assert_json "case8-lake-pruned" "$out8" '.books_meta_closure.status' "pass"
assert_json "case8-lake-pruned" "$out8" '.books_meta_closure.public_import_violation_count' "0"

# ─── Case 9: the provider package absent -> provider_absent ───────────────────────────────────
info "Case 9: provider package absent from the fixture"
repo9="${WORKDIR}/no-provider"
install_rule_set "$repo9"
mkdir -p "${repo9}/interface/lean/Interface/Spec"
printf 'import Interface.Other\n' > "${repo9}/interface/lean/Interface/Spec/A.lean"
(cd "$repo9" && git init -q)
out9="$("$WRAPPER" --json --root "$repo9" --package-root interface 2>/dev/null)"
assert_json "case9-provider-absent" "$out9" '.books_meta_closure.status' "provider_absent"

# ─── Case 10: a require line planted in the provider lakefile is reported ─────────────────────
info "Case 10: a require line planted in the provider lakefile"
repo10="${WORKDIR}/provider-require"
install_rule_set "$repo10"
install_provider "$repo10"
mkdir -p "${repo10}/interface/lean/Interface/Spec"
printf 'import Books.Meta\n' > "${repo10}/interface/lean/Interface/Spec/A.lean"
printf '\n[[require]]\nname = "mathlib"\n' >> "${repo10}/books/lean/lakefile.toml"
(cd "$repo10" && git init -q)
out10="$("$WRAPPER" --json --root "$repo10" --package-root interface 2>/dev/null)"
assert_json "case10-provider-require" "$out10" '.books_meta_closure.provider_require_lines' "1"
assert_json "case10-provider-require" "$out10" '.books_meta_closure.status' "violations"

# ─── Case 11: the private import form is counted as context, never as a violation ─────────────
info "Case 11: the sanctioned private import form"
assert_json "case11-private-import-counted" "$out10" '.books_meta_closure.private_import_sites' "1"
assert_json "case11-private-import-not-violation" "$out10" '.books_meta_closure.public_import_violation_count' "0"

# ─── Case 12: package-root derivation never hardcodes a component name ────────────────────────
info "Case 12: derived package roots"
repo12="${WORKDIR}/derived-roots"
install_rule_set "$repo12"
install_provider "$repo12"
mkdir -p "${repo12}/interface/lean" \
         "${repo12}/components/alpha/lean" \
         "${repo12}/components/beta/lean" \
         "${repo12}/components/gamma/docs"
(cd "$repo12" && git init -q)
out12="$("$WRAPPER" --json --root "$repo12" 2>/dev/null)"
assert_json "case12-derived-roots" "$out12" '.layer_lint.package_roots | join(",")' \
  "interface,components/alpha,components/beta"
if printf '%s' "$out12" | jq -e '.layer_lint.package_roots | index("components/gamma")' >/dev/null 2>&1; then
  fail "case12-no-lean-dir-excluded: components/gamma has no lean/ subdirectory and must not be derived"
else
  pass "case12-no-lean-dir-excluded: a components/* directory without a lean/ subdirectory is not derived"
fi

# ─── Forgery probes ───────────────────────────────────────────────────────────────────────────
# Each probe stubs ONE predicate and asserts the case above would then FAIL. Without these, a
# predicate silently stubbed to a constant would leave every case above still green.
info "Forgery probes: each predicate, stubbed, must break its own case"

# probe_expect_broken NAME ACTUAL EXPECTED_FROM_REAL_CASE
#   PASSES when the stubbed run does NOT reproduce the real case's expectation.
probe_expect_broken() {
  local name="$1" actual="$2" real="$3"
  if [[ "$actual" == "$real" ]]; then
    fail "${name}: the stubbed predicate still produced '${real}' -- the case does not actually bind the predicate"
  else
    pass "${name}: stubbing the predicate breaks the case (got '${actual}', real case expects '${real}')"
  fi
}

# Probe A -- vacuity predicate. Stub the rule set to one rule whose file half matches everything.
# The real Case 2 expects pass_vacuous; with the predicate's input forged, it must not.
probeA="${WORKDIR}/probe-vacuity"
install_rule_set "$probeA"
install_provider "$probeA"
cat > "${probeA}/interface/scripts/layer-rules.sh" <<'EOF'
#!/usr/bin/env bash
LAYER_RULES=( '.;^Never\.Matches\.Any\.Import$;a rule whose file half matches every path' )
LAYER_ALLOW_RULES=()
EOF
mkdir -p "${probeA}/components/unreached/lean/Unreached"
printf 'import Something.Else\n' > "${probeA}/components/unreached/lean/Unreached/A.lean"
(cd "$probeA" && git init -q)
probeA_out="$("$WRAPPER" --json --root "$probeA" --package-root components/unreached 2>/dev/null)"
probe_expect_broken "probeA-vacuity-predicate" \
  "$(printf '%s' "$probeA_out" | jq -r '.layer_lint.status')" "pass_vacuous"

# Probe B -- exit-1 disambiguation. Stub the rule library to fail on source WITHOUT the stderr
# marker the wrapper classifies on. Case 4 expects rule_set_error; without the marker it must not
# be reported as rule_set_error, proving the classification reads stderr rather than guessing.
probeB="${WORKDIR}/probe-exit1"
install_rule_set "$probeB"
install_provider "$probeB"
cat > "${probeB}/interface/scripts/layer-rules.sh" <<'EOF'
#!/usr/bin/env bash
echo "layer-rules.sh: some other bootstrap problem entirely" >&2
exit 1
EOF
mkdir -p "${probeB}/interface/lean/Interface/Spec"
printf 'import Books.Meta\n' > "${probeB}/interface/lean/Interface/Spec/A.lean"
(cd "$probeB" && git init -q)
probeB_out="$("$WRAPPER" --json --root "$probeB" --package-root interface 2>/dev/null)"
probeB_status="$(printf '%s' "$probeB_out" | jq -r '.layer_lint.status')"
if [[ "$probeB_status" == "rule_set_error" ]]; then
  fail "probeB-exit1-marker: a source failure without the classified stderr marker was still called rule_set_error -- Case 4 does not bind the stderr classification"
else
  pass "probeB-exit1-marker: the exit-1 classification genuinely reads the stderr marker (got '${probeB_status}')"
fi

# Probe C -- specs/ pruning. The real Case 7 expects pass with the planted import under specs/.
# Plant the identical import OUTSIDE specs/ and the case must break, proving Case 7's pass comes
# from the pruning rather than from the predicate never firing at all.
probeC="${WORKDIR}/probe-specs-prune"
install_rule_set "$probeC"
install_provider "$probeC"
mkdir -p "${probeC}/interface/lean/Interface/Book"
printf 'public import Books.Meta\n' > "${probeC}/interface/lean/Interface/Book/Compose.lean"
(cd "$probeC" && git init -q)
probeC_out="$("$WRAPPER" --json --root "$probeC" --package-root interface 2>/dev/null)"
probe_expect_broken "probeC-specs-pruning" \
  "$(printf '%s' "$probeC_out" | jq -r '.books_meta_closure.status')" "pass"

# Probe D -- .lake/ pruning. Same construction as Probe C, for the .lake/ exclusion. Case 8's
# pass must come from the pruning, not from the public-import predicate being inert.
probeD="${WORKDIR}/probe-lake-prune"
install_rule_set "$probeD"
install_provider "$probeD"
mkdir -p "${probeD}/interface/lean/build/Dep"
printf 'public import Books.Meta\n' > "${probeD}/interface/lean/build/Dep/Vendored.lean"
(cd "$probeD" && git init -q)
probeD_out="$("$WRAPPER" --json --root "$probeD" --package-root interface 2>/dev/null)"
probe_expect_broken "probeD-lake-pruning" \
  "$(printf '%s' "$probeD_out" | jq -r '.books_meta_closure.status')" "pass"

# Probe E -- provider-require predicate. Case 10 expects provider_require_lines 1 from a planted
# [[require]]; with no require planted the same fixture must report 0, proving the count is read
# from the lakefile rather than asserted.
probeE="${WORKDIR}/probe-provider-require"
install_rule_set "$probeE"
install_provider "$probeE"
mkdir -p "${probeE}/interface/lean/Interface/Spec"
printf 'import Books.Meta\n' > "${probeE}/interface/lean/Interface/Spec/A.lean"
(cd "$probeE" && git init -q)
probeE_out="$("$WRAPPER" --json --root "$probeE" --package-root interface 2>/dev/null)"
probe_expect_broken "probeE-provider-require-predicate" \
  "$(printf '%s' "$probeE_out" | jq -r '.books_meta_closure.provider_require_lines')" "1"

# Probe F -- lint_unavailable predicate. Case 1 expects lint_unavailable from an absent lint
# script; install one and the status must change, proving Case 1 binds the script's absence rather
# than any always-unavailable default.
probeF="${WORKDIR}/probe-lint-available"
install_rule_set "$probeF"
install_provider "$probeF"
mkdir -p "${probeF}/interface/lean/Interface/Spec"
printf 'import Books.Meta\n' > "${probeF}/interface/lean/Interface/Spec/A.lean"
(cd "$probeF" && git init -q)
probeF_out="$("$WRAPPER" --json --root "$probeF" --package-root interface 2>/dev/null)"
probe_expect_broken "probeF-lint-unavailable-predicate" \
  "$(printf '%s' "$probeF_out" | jq -r '.layer_lint.status')" "lint_unavailable"

# Probe G -- provider_absent predicate. Case 9 expects provider_absent with no provider; install
# one and the status must change.
probeG="${WORKDIR}/probe-provider-present"
install_rule_set "$probeG"
install_provider "$probeG"
mkdir -p "${probeG}/interface/lean/Interface/Spec"
printf 'import Interface.Other\n' > "${probeG}/interface/lean/Interface/Spec/A.lean"
(cd "$probeG" && git init -q)
probeG_out="$("$WRAPPER" --json --root "$probeG" --package-root interface 2>/dev/null)"
probe_expect_broken "probeG-provider-absent-predicate" \
  "$(printf '%s' "$probeG_out" | jq -r '.books_meta_closure.status')" "provider_absent"

# ─── Advisory-only invariant: every case above exited 0 ───────────────────────────────────────
info "Advisory-only invariant: the wrapper never exits non-zero on a finding"
adv_failures=0
for adv_root in "$repo1" "$repo2" "$repo4" "$repo5" "$repo6" "$repo9" "$repo10"; do
  "$WRAPPER" --json --root "$adv_root" >/dev/null 2>&1 || adv_failures=$((adv_failures + 1))
done
if [[ "$adv_failures" -eq 0 ]]; then
  pass "advisory-exit-0: every fixture root (including violations, rule_set_error and usage_error) exits 0"
else
  fail "advisory-exit-0: ${adv_failures} fixture root(s) produced a non-zero exit -- the advisory-only contract is broken"
fi

echo ""
echo "$PASSED passed, $FAILED failed"
[[ "$FAILED" -eq 0 ]] || exit 1
