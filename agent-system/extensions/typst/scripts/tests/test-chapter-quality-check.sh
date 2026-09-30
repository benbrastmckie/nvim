#!/usr/bin/env bash
# test-chapter-quality-check.sh - Narrow, fixture-driven suite for chapter-quality-check.sh.
#
# Per context/standards/shell-script-testing.md: fixtures are constructed inline via heredocs
# into a mktemp -d workdir created at suite start; nothing here depends on the external
# Logos/Theory repository or on any real specs/ tree. Class B strict mode (this is a
# PASSED/FAILED-counter harness that must report every case, not abort on the first failure).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER="${SCRIPT_DIR}/../chapter-quality-check.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if [[ ! -x "$CHECKER" ]]; then
  fail "prerequisite: $CHECKER is not executable (or does not exist)"
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
# Case (a): compliant fixture with a resolvable bibliography and a resolvable path -- exit 0,
# no [FAIL].
# ----------------------------------------------------------------------------------------------
mkdir -p "$WORKDIR/compliant"
cat > "$WORKDIR/compliant/refs.bib" <<'EOF'
@article{smith2020,
  author = {Smith, John},
  title = {An Important Paper},
  year = {2020},
}
EOF
cat > "$WORKDIR/compliant/case-a.typ" <<'EOF'
#bibliography("refs.bib")

= Chapter One

This chapter cites @smith2020 and points to `refs.bib` for the full reference list.
EOF
out_a=$(bash "$CHECKER" "$WORKDIR/compliant/case-a.typ" 2>&1); ec_a=$?
assert_exit "case-a (compliant fixture)" 0 "$ec_a"
assert_not_contains "case-a (compliant fixture)" "$out_a" "[FAIL]"

# ----------------------------------------------------------------------------------------------
# Case (b): Rule 3.2 violation -- a level-4 heading. [FAIL] naming the rule, exit 1.
# ----------------------------------------------------------------------------------------------
mkdir -p "$WORKDIR/rule32"
cat > "$WORKDIR/rule32/case-b.typ" <<'EOF'
= Chapter Two

==== Too Deep

Some prose here.
EOF
out_b=$(bash "$CHECKER" "$WORKDIR/rule32/case-b.typ" 2>&1); ec_b=$?
assert_exit "case-b (Rule 3.2 heading depth)" 1 "$ec_b"
assert_contains "case-b (Rule 3.2 heading depth)" "$out_b" "[FAIL]"
assert_contains "case-b (Rule 3.2 heading depth)" "$out_b" "3.2"

# ----------------------------------------------------------------------------------------------
# Case (c): Rule 1.5 violation -- an empty CONFIRM payload. [FAIL] naming the rule, exit 1.
# ----------------------------------------------------------------------------------------------
mkdir -p "$WORKDIR/rule15"
cat > "$WORKDIR/rule15/case-c.typ" <<'EOF'
= Chapter Three

This chapter has a gap.
// CONFIRM:
EOF
out_c=$(bash "$CHECKER" "$WORKDIR/rule15/case-c.typ" 2>&1); ec_c=$?
assert_exit "case-c (Rule 1.5 empty CONFIRM payload)" 1 "$ec_c"
assert_contains "case-c (Rule 1.5 empty CONFIRM payload)" "$out_c" "[FAIL]"
assert_contains "case-c (Rule 1.5 empty CONFIRM payload)" "$out_c" "1.5"

# A well-formed CONFIRM marker (non-empty payload) must NOT fire.
cat > "$WORKDIR/rule15/case-c-ok.typ" <<'EOF'
= Chapter Three

This chapter has a gap.
// CONFIRM: the exact version number used in benchmark X
EOF
out_c_ok=$(bash "$CHECKER" "$WORKDIR/rule15/case-c-ok.typ" 2>&1); ec_c_ok=$?
assert_exit "case-c-ok (Rule 1.5 well-formed CONFIRM)" 0 "$ec_c_ok"
assert_not_contains "case-c-ok (Rule 1.5 well-formed CONFIRM)" "$out_c_ok" "[FAIL]"

# ----------------------------------------------------------------------------------------------
# Case (d): Rule 1.2 violation -- a backticked path that does not resolve. [FAIL], exit 1.
# ----------------------------------------------------------------------------------------------
mkdir -p "$WORKDIR/rule12"
cat > "$WORKDIR/rule12/case-d.typ" <<'EOF'
= Chapter Four

See `nonexistent/path/file.sh` for details.
EOF
out_d=$(bash "$CHECKER" "$WORKDIR/rule12/case-d.typ" 2>&1); ec_d=$?
assert_exit "case-d (Rule 1.2 unresolved backtick path)" 1 "$ec_d"
assert_contains "case-d (Rule 1.2 unresolved backtick path)" "$out_d" "[FAIL]"
assert_contains "case-d (Rule 1.2 unresolved backtick path)" "$out_d" "1.2"

# ----------------------------------------------------------------------------------------------
# Case (e): Rule 1.3 violation -- a citation key that does not resolve in the declared .bib.
# [FAIL], exit 1.
# ----------------------------------------------------------------------------------------------
mkdir -p "$WORKDIR/rule13"
cat > "$WORKDIR/rule13/refs.bib" <<'EOF'
@article{smith2020,
  author = {Smith, John},
  title = {An Important Paper},
  year = {2020},
}
EOF
cat > "$WORKDIR/rule13/case-e.typ" <<'EOF'
#bibliography("refs.bib")

= Chapter Five

This cites @doesnotexist2099 as evidence.
EOF
out_e=$(bash "$CHECKER" "$WORKDIR/rule13/case-e.typ" 2>&1); ec_e=$?
assert_exit "case-e (Rule 1.3 unresolved citation key)" 1 "$ec_e"
assert_contains "case-e (Rule 1.3 unresolved citation key)" "$out_e" "[FAIL]"
assert_contains "case-e (Rule 1.3 unresolved citation key)" "$out_e" "1.3"

# ----------------------------------------------------------------------------------------------
# Case (f): unresolvable bibliography -- no #bibliography(...) declaration and no .bib file in
# the checked file's own directory. NOT EVALUATED [INFO] printed, exit 0 (never a blocking
# failure).
#
# DISPOSITION (re-examined against both the BUG 2a/2c ancestor-walk branch and the BUG 2b
# vendored-dir exclusion added to resolve_bibliography): this fixture stays VALID AND UNMODIFIED.
# $WORKDIR is a plain `mktemp -d`, not a git work tree, so resolve_repo_root falls back to
# `root == filedir` for case-f.typ's own directory; the ancestor walk therefore has zero range
# (filedir already equals root, so the loop checks one level and stops), and there is no `.bib`
# anywhere under root for branch (c) to find either. Both new branches are genuinely inert here --
# this is a real bib-less repo, and it correctly stays NOT EVALUATED.
# ----------------------------------------------------------------------------------------------
mkdir -p "$WORKDIR/nobib"
cat > "$WORKDIR/nobib/case-f.typ" <<'EOF'
= Chapter Six

Nothing special here, just prose with no citations.
EOF
out_f=$(bash "$CHECKER" "$WORKDIR/nobib/case-f.typ" 2>&1); ec_f=$?
assert_exit "case-f (unresolvable bibliography)" 0 "$ec_f"
assert_contains "case-f (unresolvable bibliography)" "$out_f" "NOT EVALUATED"
assert_contains "case-f (unresolvable bibliography)" "$out_f" "1.3"

# ----------------------------------------------------------------------------------------------
# Case (l): BUG 2a/2c fix -- nearest-ancestor #bibliography(...) declaration, multi-argument form.
# A root .typ (in a real git work tree, so resolve_repo_root's toplevel is the repo root rather
# than the chapter's own directory) declares `#bibliography("bibliography.bib", title: [...],
# style: "ieee")`; a chapters/ child with NO declaration of its own cites a key present in that
# .bib. Rule 1.3 must EVALUATE (not NOT EVALUATED), and the citation resolves so no [FAIL] fires.
# ----------------------------------------------------------------------------------------------
mkdir -p "$WORKDIR/ancestorbib/chapters"
(cd "$WORKDIR/ancestorbib" && git init -q)
cat > "$WORKDIR/ancestorbib/bibliography.bib" <<'EOF'
@article{jones2021,
  author = {Jones, Amy},
  title = {Another Paper},
  year = {2021},
}
EOF
cat > "$WORKDIR/ancestorbib/root.typ" <<'EOF'
#bibliography("bibliography.bib", title: [References], style: "ieee")

= Manual Root
EOF
cat > "$WORKDIR/ancestorbib/chapters/case-l.typ" <<'EOF'
= Chapter One

This chapter cites @jones2021 as evidence.
EOF
out_l=$(bash "$CHECKER" --verbose "$WORKDIR/ancestorbib/chapters/case-l.typ" 2>&1); ec_l=$?
assert_exit "case-l (BUG 2a/2c ancestor bib, multi-arg declaration)" 0 "$ec_l"
assert_not_contains "case-l (BUG 2a/2c ancestor bib, multi-arg declaration)" "$out_l" "[FAIL]"
assert_contains "case-l (BUG 2a/2c ancestor bib, multi-arg declaration)" "$out_l" "Rule 1.3 evaluated against"
assert_not_contains "case-l (BUG 2a/2c ancestor bib, multi-arg declaration)" "$out_l" "1.3 NOT EVALUATED"

# Negative twin (non-vacuity guard): the child cites a key ABSENT from the resolved ancestor
# .bib -- proves the new branch resolves to a real file (Rule 1.3 fires a genuine [FAIL]) rather
# than merely suppressing the NOT-EVALUATED skip.
mkdir -p "$WORKDIR/ancestorbib-neg/chapters"
(cd "$WORKDIR/ancestorbib-neg" && git init -q)
cp "$WORKDIR/ancestorbib/bibliography.bib" "$WORKDIR/ancestorbib-neg/bibliography.bib"
cp "$WORKDIR/ancestorbib/root.typ" "$WORKDIR/ancestorbib-neg/root.typ"
cat > "$WORKDIR/ancestorbib-neg/chapters/case-l-neg.typ" <<'EOF'
= Chapter One

This chapter cites @doesnotexist2099 as evidence.
EOF
out_l_neg=$(bash "$CHECKER" --verbose "$WORKDIR/ancestorbib-neg/chapters/case-l-neg.typ" 2>&1); ec_l_neg=$?
assert_exit "case-l-neg (BUG 2a/2c ancestor bib, unresolved key)" 1 "$ec_l_neg"
assert_contains "case-l-neg (BUG 2a/2c ancestor bib, unresolved key)" "$out_l_neg" "[FAIL]"
assert_contains "case-l-neg (BUG 2a/2c ancestor bib, unresolved key)" "$out_l_neg" "1.3"

# ----------------------------------------------------------------------------------------------
# Case (m): BUG 2b fix -- a vendored .bib under a pruned directory (.lake/) must not defeat the
# single-candidate test. A real refs.bib plus a vendored .lake/packages/mathlib/docs/references.bib
# both sit under root; Rule 1.3 must resolve against the real one and evaluate normally.
# ----------------------------------------------------------------------------------------------
mkdir -p "$WORKDIR/vendoredbib/.lake/packages/mathlib/docs"
cat > "$WORKDIR/vendoredbib/refs.bib" <<'EOF'
@article{smith2020,
  author = {Smith, John},
  title = {An Important Paper},
  year = {2020},
}
EOF
cat > "$WORKDIR/vendoredbib/.lake/packages/mathlib/docs/references.bib" <<'EOF'
@article{vendored2019,
  author = {Vendor, V.},
  title = {Unrelated Vendored Reference},
  year = {2019},
}
EOF
cat > "$WORKDIR/vendoredbib/case-m.typ" <<'EOF'
= Chapter One

This chapter cites @smith2020 as evidence.
EOF
out_m=$(bash "$CHECKER" --verbose "$WORKDIR/vendoredbib/case-m.typ" 2>&1); ec_m=$?
assert_exit "case-m (BUG 2b vendored .bib excluded)" 0 "$ec_m"
assert_not_contains "case-m (BUG 2b vendored .bib excluded)" "$out_m" "[FAIL]"
assert_contains "case-m (BUG 2b vendored .bib excluded)" "$out_m" "Rule 1.3 evaluated against"
assert_contains "case-m (BUG 2b vendored .bib excluded)" "$out_m" "refs.bib"
assert_not_contains "case-m (BUG 2b vendored .bib excluded)" "$out_m" "1.3 NOT EVALUATED"

# ----------------------------------------------------------------------------------------------
# Case (n): NOT-EVALUATED surfacing -- a NOT EVALUATED BLOCKING rule (1.3, on a bib-less fixture
# reusing case-f's shape without modifying case-f itself) must print at [WARN] tier and qualify
# the final PASSED banner, while the exit code stays 0.
# ----------------------------------------------------------------------------------------------
mkdir -p "$WORKDIR/nobib-qualified"
cat > "$WORKDIR/nobib-qualified/case-n.typ" <<'EOF'
= Chapter Six

Nothing special here, just prose with no citations.
EOF
out_n=$(bash "$CHECKER" "$WORKDIR/nobib-qualified/case-n.typ" 2>&1); ec_n=$?
assert_exit "case-n (qualified PASSED banner, BLOCKING rule skipped)" 0 "$ec_n"
assert_contains "case-n (qualified PASSED banner, BLOCKING rule skipped)" "$out_n" "[WARN]"
assert_contains "case-n (qualified PASSED banner, BLOCKING rule skipped)" "$out_n" "Rule 1.3 NOT EVALUATED"
assert_contains "case-n (qualified PASSED banner, BLOCKING rule skipped)" "$out_n" \
  "CHAPTER QUALITY CHECK PASSED"
# The qualifier suffix follows a color-reset escape, so it is checked on its own rather than as
# one contiguous substring spanning the reset code.
assert_contains "case-n (qualified PASSED banner, BLOCKING rule skipped)" "$out_n" \
  "(1 BLOCKING rule(s) not evaluated) (mechanical coverage only"

# ----------------------------------------------------------------------------------------------
# Case (o): NOT-EVALUATED surfacing, negative control -- an ADVISORY-only run (Rule 3.3, with a
# resolvable bibliography so no BLOCKING rule is skipped) must NOT qualify the PASSED banner.
# Guards against the TOTAL_BLOCKING_SKIPPED counter firing on the wrong severity.
# ----------------------------------------------------------------------------------------------
mkdir -p "$WORKDIR/advisory-qualified"
cat > "$WORKDIR/advisory-qualified/refs.bib" <<'EOF'
@article{smith2020,
  author = {Smith, John},
  title = {An Important Paper},
  year = {2020},
}
EOF
python3 -c "
words = ' '.join(['word'] * 200)
print('#bibliography(\"refs.bib\")')
print()
print('= Chapter Seven')
print()
print('This chapter cites @smith2020 as evidence.')
print()
print(words)
" > "$WORKDIR/advisory-qualified/case-o.typ"
out_o=$(bash "$CHECKER" "$WORKDIR/advisory-qualified/case-o.typ" 2>&1); ec_o=$?
assert_exit "case-o (ADVISORY-only, banner NOT qualified)" 0 "$ec_o"
assert_not_contains "case-o (ADVISORY-only, banner NOT qualified)" "$out_o" "[FAIL]"
assert_contains "case-o (ADVISORY-only, banner NOT qualified)" "$out_o" "[WARN]"
assert_contains "case-o (ADVISORY-only, banner NOT qualified)" "$out_o" "3.3"
assert_contains "case-o (ADVISORY-only, banner NOT qualified)" "$out_o" "CHAPTER QUALITY CHECK PASSED"
# The Summary block's own "Skipped: 0 BLOCKING rule(s) not evaluated" line always contains that
# phrase regardless of count, so the banner-qualifier check below targets the qualified banner's
# distinctive adjacency ("not evaluated) (mechanical") rather than the phrase alone.
assert_not_contains "case-o (ADVISORY-only, banner NOT qualified)" "$out_o" \
  "not evaluated) (mechanical coverage only"

# ----------------------------------------------------------------------------------------------
# Case (g): advisory-only fixture (Rule 3.3, paragraph length) -- exit 0 AND the advisory
# finding IS printed. The non-vacuity guard: a checker that passes silently on a fixture with a
# real defect is the failure mode being guarded against.
# ----------------------------------------------------------------------------------------------
mkdir -p "$WORKDIR/advisory"
python3 -c "
words = ' '.join(['word'] * 200)
print('= Chapter Seven')
print()
print(words)
" > "$WORKDIR/advisory/case-g.typ"
out_g=$(bash "$CHECKER" "$WORKDIR/advisory/case-g.typ" 2>&1); ec_g=$?
assert_exit "case-g (advisory-only, Rule 3.3 paragraph length)" 0 "$ec_g"
assert_not_contains "case-g (advisory-only, Rule 3.3 paragraph length)" "$out_g" "[FAIL]"
assert_contains "case-g (advisory-only, Rule 3.3 paragraph length)" "$out_g" "[WARN]"
assert_contains "case-g (advisory-only, Rule 3.3 paragraph length)" "$out_g" "3.3"

# ----------------------------------------------------------------------------------------------
# Case (h): ANTI-FLUFF-only fixture (Rules 2.1 and 2.3 firing, nothing else) -- exit 0
# explicitly, proving no ANTI-FLUFF finding can ever change the exit code. Three short
# paragraphs (each under the Rule 3.3 threshold) summing above the Rule 2.1 threshold, with zero
# citations and several hedging phrases; no backtick paths, no CONFIRM markers, heading depth
# bounded, no semantic elements (avoids placement).
# ----------------------------------------------------------------------------------------------
mkdir -p "$WORKDIR/antifluff"
python3 -c "
para = lambda n, extra: ' '.join(['filler'] * n) + ' ' + extra
print('= Chapter Eight')
print()
print(para(55, 'Clearly this point is obviously trivial and easy to see.'))
print()
print(para(55, 'It seems arguably true, and it is worth noting that the pattern holds.'))
print()
print(para(55, 'Needless to say, the conclusion follows without further comment.'))
" > "$WORKDIR/antifluff/case-h.typ"
out_h=$(bash "$CHECKER" "$WORKDIR/antifluff/case-h.typ" 2>&1); ec_h=$?
assert_exit "case-h (ANTI-FLUFF-only: 2.1 + 2.3, no blocking)" 0 "$ec_h"
assert_not_contains "case-h (ANTI-FLUFF-only: 2.1 + 2.3, no blocking)" "$out_h" "[FAIL]"
assert_contains "case-h (ANTI-FLUFF-only: 2.1 + 2.3, no blocking)" "$out_h" "2.1"
assert_contains "case-h (ANTI-FLUFF-only: 2.1 + 2.3, no blocking)" "$out_h" "2.3"
assert_not_contains "case-h (ANTI-FLUFF-only: 2.1 + 2.3, no blocking)" "$out_h" "3.3"

# ----------------------------------------------------------------------------------------------
# Case (i): judged-prompt emission -- all eight prompts present on a compliant fixture, asserted
# by rule id.
# ----------------------------------------------------------------------------------------------
out_i="$out_a"
for rule in 1.1 1.4 2.2 3.1 3.4 4.1 4.2 4.3; do
  assert_contains "case-i (judged prompt ${rule} present)" "$out_i" "[JUDGED]"
  assert_contains "case-i (judged rule id ${rule} present)" "$out_i" "[${rule} /"
done
assert_contains "case-i (judged prompt count)" "$out_i" "JUDGED 8 prompts pending"

# ----------------------------------------------------------------------------------------------
# Case (j): placement delegation -- a semantic element standing as the first body content after
# a heading. BLOCKING (delegated from typst-element-lint.sh), exit 1.
# ----------------------------------------------------------------------------------------------
mkdir -p "$WORKDIR/placement"
cat > "$WORKDIR/placement/case-j.typ" <<'EOF'
= Chapter Nine

#theorem("Immediate")[
  A claim with no motivating prose.
]
EOF
out_j=$(bash "$CHECKER" "$WORKDIR/placement/case-j.typ" 2>&1); ec_j=$?
assert_exit "case-j (placement delegation, element as chapter opener)" 1 "$ec_j"
assert_contains "case-j (placement delegation, element as chapter opener)" "$out_j" "[FAIL]"
assert_contains "case-j (placement delegation, element as chapter opener)" "$out_j" "delegated from typst-element-lint.sh"

# A placement-advisory delegated finding (density warning) is exit 0 with the advisory printed.
mkdir -p "$WORKDIR/placement-advisory"
cat > "$WORKDIR/placement-advisory/case-j2.typ" <<'EOF'
= Chapter Ten

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
out_j2=$(bash "$CHECKER" "$WORKDIR/placement-advisory/case-j2.typ" 2>&1); ec_j2=$?
assert_exit "case-j2 (placement delegation, density advisory only)" 0 "$ec_j2"
assert_not_contains "case-j2 (placement delegation, density advisory only)" "$out_j2" "[FAIL]"
assert_contains "case-j2 (placement delegation, density advisory only)" "$out_j2" "[WARN]"
assert_contains "case-j2 (placement delegation, density advisory only)" "$out_j2" "delegated from typst-element-lint.sh"

# Confirm no second placement implementation exists in this checker (only header prose and the
# delegation call should match).
placement_regex_hits=$(grep -cE 'definition|theorem|lemma|corollary|remark|rule-block|rule-list' "${SCRIPT_DIR}/../chapter-quality-check.sh")
if [[ "$placement_regex_hits" -le 1 ]]; then
  pass "case-k (no second placement implementation: ${placement_regex_hits} regex hit(s), header prose only)"
else
  fail "case-k (unexpected element-name regex hits in chapter-quality-check.sh: ${placement_regex_hits})"
fi

# ----------------------------------------------------------------------------------------------
# CLI contract: no PATH -> exit 2; nonexistent PATH -> exit 2; --help -> exit 0; directory scan.
# ----------------------------------------------------------------------------------------------
bash "$CHECKER" >/dev/null 2>&1; ec_nopath=$?
assert_exit "CLI: no PATH given" 2 "$ec_nopath"

bash "$CHECKER" "$WORKDIR/does-not-exist.typ" >/dev/null 2>&1; ec_badpath=$?
assert_exit "CLI: nonexistent PATH" 2 "$ec_badpath"

bash "$CHECKER" --help >/dev/null 2>&1; ec_help=$?
assert_exit "CLI: --help" 0 "$ec_help"

mkdir -p "$WORKDIR/dirscan/nested"
cp "$WORKDIR/compliant/case-a.typ" "$WORKDIR/dirscan/clean.typ"
cp "$WORKDIR/compliant/refs.bib" "$WORKDIR/dirscan/refs.bib"
cp "$WORKDIR/rule32/case-b.typ" "$WORKDIR/dirscan/nested/violation.typ"
out_dir=$(bash "$CHECKER" "$WORKDIR/dirscan" 2>&1); ec_dir=$?
assert_exit "CLI: directory scan (one clean, one violating, nested)" 1 "$ec_dir"
assert_contains "CLI: directory scan (one clean, one violating, nested)" "$out_dir" "[FAIL]"
assert_contains "CLI: directory scan (one clean, one violating, nested)" "$out_dir" "Files checked: 2"

# Non-regression guard, explicit rather than assumed (per the plan's research integration note):
# `$WORKDIR` is a plain `mktemp -d`, not a git work tree, so resolve_repo_root falls back to
# `root == filedir` for nested/violation.typ (its OWN directory, not dirscan/'s parent), giving
# the BUG 2a/2c ancestor walk zero range -- it never reaches dirscan/'s refs.bib one level up.
# violation.typ has no #bibliography(...) declaration and no *.bib file in its own dirscan/nested/
# directory, so Rule 1.3 must stay NOT EVALUATED for it post-fix, exactly as pre-fix.
assert_contains "CLI: directory scan (nested/violation.typ Rule 1.3 stays NOT EVALUATED)" \
  "$out_dir" "nested/violation.typ: Rule 1.3 NOT EVALUATED"

echo ""
echo "$PASSED passed, $FAILED failed"
if [[ "$FAILED" -eq 0 ]]; then
  exit 0
else
  exit 1
fi
