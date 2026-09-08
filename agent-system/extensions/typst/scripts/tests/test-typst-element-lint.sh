#!/usr/bin/env bash
# test-typst-element-lint.sh - Narrow, fixture-driven suite for typst-element-lint.sh.
#
# Per context/standards/shell-script-testing.md: fixtures are constructed inline via heredocs
# into a mktemp -d workdir created at suite start; nothing here depends on the external
# Logos/Theory repository or on any real specs/ tree. Class B strict mode (this is a
# PASSED/FAILED-counter harness that must report every case, not abort on the first failure).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="${SCRIPT_DIR}/../typst-element-lint.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if [[ ! -x "$LINT" ]]; then
  fail "prerequisite: $LINT is not executable (or does not exist)"
  echo ""
  echo "$PASSED passed, $FAILED failed"
  exit 1
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

# assert_contains CASE_NAME OUTPUT NEEDLE
assert_contains() {
  local name="$1" output="$2" needle="$3"
  if [[ "$output" == *"$needle"* ]]; then
    pass "${name}: output contains '${needle}'"
  else
    fail "${name}: output does NOT contain '${needle}'"
    info "  --- actual output ---"
    while IFS= read -r line; do info "  $line"; done <<< "$output"
  fi
}

# assert_not_contains CASE_NAME OUTPUT NEEDLE
assert_not_contains() {
  local name="$1" output="$2" needle="$3"
  if [[ "$output" != *"$needle"* ]]; then
    pass "${name}: output does NOT contain '${needle}'"
  else
    fail "${name}: output unexpectedly contains '${needle}'"
    info "  --- actual output ---"
    while IFS= read -r line; do info "  $line"; done <<< "$output"
  fi
}

# ----------------------------------------------------------------------------------------------
# Case (a): heading followed by prose then a remark -- silent (check 1 does not fire).
# ----------------------------------------------------------------------------------------------
cat > "$WORKDIR/case-a.typ" <<'EOF'
= Chapter One

This chapter introduces the framework and its motivation.

#theorem("Basic Result")[
  Some claim.
]

#remark[
  A brief reflective aside on the result above.
]
EOF
out_a=$(bash "$LINT" "$WORKDIR/case-a.typ" 2>&1); ec_a=$?
assert_exit "case-a (prose before remark)" 0 "$ec_a"
assert_not_contains "case-a (prose before remark)" "$out_a" "[FAIL]"

# ----------------------------------------------------------------------------------------------
# Case (b): heading followed immediately by #remark( -- check 1 fires.
# ----------------------------------------------------------------------------------------------
cat > "$WORKDIR/case-b.typ" <<'EOF'
= Chapter Two

#remark("Status")[
  Some tracking content.
]
EOF
out_b=$(bash "$LINT" "$WORKDIR/case-b.typ" 2>&1); ec_b=$?
assert_exit "case-b (remark as chapter opener)" 1 "$ec_b"
assert_contains "case-b (remark as chapter opener)" "$out_b" "[FAIL]"
assert_contains "case-b (remark as chapter opener)" "$out_b" "#remark"

# ----------------------------------------------------------------------------------------------
# Case (c): heading followed immediately by #theorem[ -- check 1 fires (not remark-only).
# ----------------------------------------------------------------------------------------------
cat > "$WORKDIR/case-c.typ" <<'EOF'
= Chapter Three

#theorem("Immediate")[
  A claim with no motivating prose.
]
EOF
out_c=$(bash "$LINT" "$WORKDIR/case-c.typ" 2>&1); ec_c=$?
assert_exit "case-c (theorem as chapter opener)" 1 "$ec_c"
assert_contains "case-c (theorem as chapter opener)" "$out_c" "[FAIL]"
assert_contains "case-c (theorem as chapter opener)" "$out_c" "#theorem"

# ----------------------------------------------------------------------------------------------
# Case (d): pre-heading #import/#let/comment block with a compliant body -- silent.
# Mirrors the real 08-agency.typ shape: ~50 lines of chapter-local macros before the heading.
# ----------------------------------------------------------------------------------------------
cat > "$WORKDIR/case-d.typ" <<'EOF'
// Chapter-local notation block.
#import "../template.typ": *
#let Foo = $sans("Foo")$
#let Bar = $sans("Bar")$
// More setup comments.
#let Baz = $sans("Baz")$

= Chapter Four

This chapter explains the setup above and what follows.

#definition("Term")[
  A term is a thing.
]
EOF
out_d=$(bash "$LINT" "$WORKDIR/case-d.typ" 2>&1); ec_d=$?
assert_exit "case-d (pre-heading macro block, compliant body)" 0 "$ec_d"
assert_not_contains "case-d (pre-heading macro block, compliant body)" "$out_d" "[FAIL]"

# ----------------------------------------------------------------------------------------------
# Case (e): heading, then #let declarations, then a semantic element -- check 1 STILL fires.
# Declarations are skipped (not counted as prose), so no prose was ever actually supplied.
# ----------------------------------------------------------------------------------------------
cat > "$WORKDIR/case-e.typ" <<'EOF'
= Chapter Five

#let Qux = $sans("Qux")$
#let Quux = $sans("Quux")$

#definition("Term")[
  A term is a thing.
]
EOF
out_e=$(bash "$LINT" "$WORKDIR/case-e.typ" 2>&1); ec_e=$?
assert_exit "case-e (heading, declarations, then element -- no real prose)" 1 "$ec_e"
assert_contains "case-e (heading, declarations, then element -- no real prose)" "$out_e" "[FAIL]"

# ----------------------------------------------------------------------------------------------
# Case (f): remark with a nested #items[...] and 5 markers -- check 2 warns, correct extent.
# The inner #items[...] closes one line before the outer remark's own close; the matcher must
# not stop at the inner close.
# ----------------------------------------------------------------------------------------------
cat > "$WORKDIR/case-f.typ" <<'EOF'
= Chapter Six

This chapter has substantial content before its remark.

#theorem("Result")[
  A claim.
]

#remark("Tracking")[
#items[
+ item one
+ item two
+ item three
+ item four
+ item five
]
] <rem-nested>

This is body prose after the remark, at the outer nesting level -- confirms the matcher
did not stop at the inner #items[...] close.
EOF
out_f=$(bash "$LINT" "$WORKDIR/case-f.typ" 2>&1); ec_f=$?
assert_exit "case-f (nested #items, 5 markers)" 0 "$ec_f"
assert_not_contains "case-f (nested #items, 5 markers)" "$out_f" "[FAIL]"
assert_contains "case-f (nested #items, 5 markers)" "$out_f" "[WARN]"
assert_contains "case-f (nested #items, 5 markers)" "$out_f" "5 enumerated items"

# ----------------------------------------------------------------------------------------------
# Case (g): remark with 2 markers (under the threshold of 3) -- check 2 silent.
# ----------------------------------------------------------------------------------------------
cat > "$WORKDIR/case-g.typ" <<'EOF'
= Chapter Seven

This chapter has substantial content before its remark.

#theorem("Result")[
  A claim.
]

#remark[
+ item one
+ item two
]
EOF
out_g=$(bash "$LINT" "$WORKDIR/case-g.typ" 2>&1); ec_g=$?
assert_exit "case-g (remark with 2 markers, under threshold)" 0 "$ec_g"
assert_not_contains "case-g (remark with 2 markers, under threshold)" "$out_g" "[WARN]"
assert_not_contains "case-g (remark with 2 markers, under threshold)" "$out_g" "[FAIL]"

# ----------------------------------------------------------------------------------------------
# Case (h.1): 5 remarks / 1 theorem -- check 3 WARNs, exit code stays 0 (advisory-only).
# ----------------------------------------------------------------------------------------------
cat > "$WORKDIR/case-h1.typ" <<'EOF'
= Chapter Eight

This chapter has one theorem and several short remarks.

#theorem("Result")[
  A claim.
]

#remark[ Aside one. ]

#remark[ Aside two. ]

#remark[ Aside three. ]

#remark[ Aside four. ]

#remark[ Aside five. ]
EOF
out_h1=$(bash "$LINT" "$WORKDIR/case-h1.typ" 2>&1); ec_h1=$?
assert_exit "case-h1 (5 remarks / 1 theorem, density warns)" 0 "$ec_h1"
assert_contains "case-h1 (5 remarks / 1 theorem, density warns)" "$out_h1" "[WARN]"
assert_contains "case-h1 (5 remarks / 1 theorem, density warns)" "$out_h1" "theorem-family"

# ----------------------------------------------------------------------------------------------
# Case (h.2): 2 remarks / 0 theorems -- silent (absolute floor of 3 remarks not met).
# ----------------------------------------------------------------------------------------------
cat > "$WORKDIR/case-h2.typ" <<'EOF'
= Chapter Nine

This chapter has no theorem-family elements yet, and two short remarks.

#remark[ Aside one. ]

#remark[ Aside two. ]
EOF
out_h2=$(bash "$LINT" "$WORKDIR/case-h2.typ" 2>&1); ec_h2=$?
assert_exit "case-h2 (2 remarks / 0 theorems, floor holds)" 0 "$ec_h2"
assert_not_contains "case-h2 (2 remarks / 0 theorems, floor holds)" "$out_h2" "[WARN]"
assert_not_contains "case-h2 (2 remarks / 0 theorems, floor holds)" "$out_h2" "[FAIL]"

# ----------------------------------------------------------------------------------------------
# Case (i): bare-bracket #remark[ call form (no title argument) -- recognized by all checks.
# ----------------------------------------------------------------------------------------------
cat > "$WORKDIR/case-i.typ" <<'EOF'
= Chapter Ten

#remark[
  A bare-bracket remark with no title argument, standing as the chapter opener.
]
EOF
out_i=$(bash "$LINT" "$WORKDIR/case-i.typ" 2>&1); ec_i=$?
assert_exit "case-i (bare-bracket #remark[ call form)" 1 "$ec_i"
assert_contains "case-i (bare-bracket #remark[ call form)" "$out_i" "[FAIL]"
assert_contains "case-i (bare-bracket #remark[ call form)" "$out_i" "#remark"

# ----------------------------------------------------------------------------------------------
# Warnings-only run exits 0 -- the Constraint 2 guarantee (checks 2/3 never affect exit code),
# tested explicitly rather than assumed. Combine a long remark AND a density trigger with zero
# placement violations.
# ----------------------------------------------------------------------------------------------
cat > "$WORKDIR/case-warnings-only.typ" <<'EOF'
= Chapter Eleven

This chapter opens with real prose, as required.

#theorem("Result")[
  A claim.
]

#remark("Tracking")[
+ item one
+ item two
+ item three
+ item four
]

#remark[ Aside two. ]

#remark[ Aside three. ]

#remark[ Aside four. ]
EOF
out_wo=$(bash "$LINT" "$WORKDIR/case-warnings-only.typ" 2>&1); ec_wo=$?
assert_exit "case-warnings-only (item-count and density warnings, no placement violation)" 0 "$ec_wo"
assert_not_contains "case-warnings-only (item-count and density warnings, no placement violation)" "$out_wo" "[FAIL]"
assert_contains "case-warnings-only (item-count and density warnings, no placement violation)" "$out_wo" "[WARN]"

# ----------------------------------------------------------------------------------------------
# CLI contract: no PATH -> exit 2; nonexistent PATH -> exit 2; --help -> exit 0.
# ----------------------------------------------------------------------------------------------
bash "$LINT" >/dev/null 2>&1; ec_nopath=$?
assert_exit "CLI: no PATH given" 2 "$ec_nopath"

bash "$LINT" "$WORKDIR/does-not-exist.typ" >/dev/null 2>&1; ec_badpath=$?
assert_exit "CLI: nonexistent PATH" 2 "$ec_badpath"

bash "$LINT" --help >/dev/null 2>&1; ec_help=$?
assert_exit "CLI: --help" 0 "$ec_help"

# ----------------------------------------------------------------------------------------------
# Directory scanning: a directory PATH is scanned recursively for *.typ files.
# ----------------------------------------------------------------------------------------------
mkdir -p "$WORKDIR/dirscan/nested"
cp "$WORKDIR/case-a.typ" "$WORKDIR/dirscan/clean.typ"
cp "$WORKDIR/case-b.typ" "$WORKDIR/dirscan/nested/violation.typ"
out_dir=$(bash "$LINT" "$WORKDIR/dirscan" 2>&1); ec_dir=$?
assert_exit "directory scan (one clean, one violating, nested)" 1 "$ec_dir"
assert_contains "directory scan (one clean, one violating, nested)" "$out_dir" "[FAIL]"
assert_contains "directory scan (one clean, one violating, nested)" "$out_dir" "Files checked: 2"

echo ""
echo "$PASSED passed, $FAILED failed"
if [[ "$FAILED" -eq 0 ]]; then
  exit 0
else
  exit 1
fi
