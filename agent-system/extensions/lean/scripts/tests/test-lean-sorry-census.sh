#!/usr/bin/env bash
# test-lean-sorry-census.sh -- regression suite for lean-sorry-census.sh covering two distinct
# regression concerns:
#
# (1) The warn.sorry double-count defect (Fixtures A-E): `\bsorry\b` fires at the `.`/`s`
# boundary inside dotted-qualified names such as `warn.sorry` or `foo.sorry`, so an own-line
# `set_option warn.sorry false in` suppression annotation is counted as a phantom sorry on top of
# the real sorry it suppresses.
#
# (2) Guard routing of the `--cross-check` build (Fixtures F-I): the `--cross-check` branch's
# `lake build` command substitution is routed through the shared `lake-build-guard.sh` when both
# `lake` and the guard are available, and degrades gracefully to today's plain `lake build` when
# either (or both) is absent. Fixtures F-I cover the three-way branch: lake absent (F), lake
# present/guard absent (G), both present (H), and a guarded non-zero exit (I).
#
# This is the first regression fixture this script has ever had. Per the task's falsifiability
# gate, this suite MUST be run once against the UNFIXED script (before the regex at line 144 is
# touched, and before the guard routing exists) and is expected to show Fixtures A, D, and E FAIL
# while B and C PASS (warn.sorry concern), and Fixtures F and G PASS while H and I FAIL (guard
# routing concern, since the guarded path does not exist yet) -- proving the fixtures actually
# discriminate the buggy/pre-integration behavior from the intended one, rather than being a
# vacuous suite that would pass either way.
#
# Anti-vacuous-test guard: Fixtures A and D additionally assert that the naive `\bsorry\b`
# per-line count DIFFERS from the tool's reported count on the same fixture text, and Fixture H
# additionally asserts its captured output DIFFERS from Fixture G's (a distinctive
# compiler_sorry_count value proves the guard stub -- not the unused plain-lake stub also left on
# PATH -- actually supplied the combined capture), so a fixture both implementations would agree
# on can never masquerade as coverage (per context/standards/shell-script-testing.md's
# mutation-check discipline).
#
# Follows the core shell-test convention (see
# agent-system/extensions/core/scripts/tests/test-census-count.sh): pass()/fail()/info()
# helpers, PASSED/FAILED integer counters, mktemp -d workdir with a trap EXIT cleanup, exit 0 on
# all-pass and exit 1 on any-fail. All fixtures are synthetic heredocs; this suite never reads or
# asserts against the real repository tree.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_SRC="$SCRIPT_DIR/../lean-sorry-census.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$TOOL_SRC" ]; then
  echo "ERROR: expected lean-sorry-census.sh at $TOOL_SRC" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required by lean-sorry-census.sh and is not on PATH" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

get_count() {
  # get_count <output> -- extracts the integer from "sorry_count: N".
  echo "$1" | grep -oE '^sorry_count: [0-9]+' | grep -oE '[0-9]+'
}

naive_count() {
  # naive_count <file> -- per-line naive \bsorry\b count over the raw fixture text, using the
  # SAME per-line "does this line match" semantic as the tool (not occurrence counting), so the
  # comparison isolates the regex change and nothing else.
  python3 -c '
import re, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    lines = fh.read().split("\n")
naive_re = re.compile(r"\bsorry\b")
print(sum(1 for l in lines if naive_re.search(l)))
' "$1"
}

# ---------------------------------------------------------------------
# Helpers for Fixtures F-I (guard routing). These do not import the guard suite's own
# FAKE_LAKE_* convention (test-lake-build-guard.sh) -- that is a different script's convention;
# this suite keeps its own house style throughout.
# ---------------------------------------------------------------------

make_isolated_bin_without_lake() {
  # make_isolated_bin_without_lake <dir> -- populate <dir> with symlinks to every tool the census
  # script and this suite need (bash, python3, grep, find, ...), deliberately EXCLUDING `lake`,
  # then print <dir> as a self-contained PATH value. A blanket "strip any PATH directory that
  # contains lake" approach is unsafe here: on a system where a directory such as
  # /run/current-system/sw/bin resolves BOTH `lake` and `bash` to the same symlink farm,
  # removing that directory would remove bash itself. Mirrors the isolated-PATH convention
  # test-lake-build-guard.sh's own suite already uses (there, to remove systemd-run only) --
  # a general PATH-isolation technique, not that suite's FAKE_LAKE_* naming convention.
  local dir="$1"
  mkdir -p "$dir"
  local tool
  for tool in bash env cat echo grep find sort mkdir rm chmod dirname cut tail head wc date sed awk stat sleep python3 printf true false; do
    local toolpath
    toolpath="$(command -v "$tool" 2>/dev/null || true)"
    if [ -n "$toolpath" ] && [ ! -e "$dir/$tool" ]; then
      ln -sf "$toolpath" "$dir/$tool"
    fi
  done
  echo "$dir"
}

make_synthetic_lean_project() {
  # make_synthetic_lean_project <dir> -- populate <dir> with a minimal lakefile.toml and one
  # .lean file with a known sorry, so the guard's own project-root resolution (a lakefile.lean or
  # lakefile.toml found above --dir, which defaults to $PWD) succeeds when the guarded fixtures
  # exercise it.
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/lakefile.toml" <<'EOF'
name = "SyntheticFixture"
defaultTargets = ["SyntheticFixture"]

[[lean_lib]]
name = "SyntheticFixture"
EOF
  cat > "$dir/Main.lean" <<'EOF'
theorem placeholder : True := sorry
EOF
}

make_stub_lake() {
  # make_stub_lake <bindir> <sorry_count> <exit_status> -- fabricate a stub `lake` executable in
  # <bindir> that, when invoked (with any args, e.g. "build"), echoes <sorry_count> synthetic
  # "declaration uses 'sorry'" lines (mirroring real `lake build` warning output, so
  # compiler_sorry_count parses as expected) and exits <exit_status>.
  local bindir="$1" sorry_count="$2" exit_status="$3"
  mkdir -p "$bindir"
  cat > "$bindir/lake" <<STUBEOF
#!/usr/bin/env bash
i=1
while [ "\$i" -le $sorry_count ]; do
  echo "warning: Foo.lean:\$i:0: declaration uses 'sorry'"
  i=\$((i + 1))
done
exit $exit_status
STUBEOF
  chmod +x "$bindir/lake"
}

make_stub_guard() {
  # make_stub_guard <path> <sorry_count> <exit_status> -- fabricate a stub guard script honoring
  # the real guard's `build [flags] -- <lake args>` calling convention (its first arg is the
  # subcommand "build"; it does not otherwise parse flags or forwarded lake args, since this
  # suite only needs to prove the guarded path was taken, not re-verify the guard's own argument
  # parsing -- that is test-lake-build-guard.sh's job). Echoes a marker line to stdout so the
  # test can prove the guarded path was actually taken, then <sorry_count> synthetic
  # "declaration uses 'sorry'" lines so compiler_sorry_count still parses correctly from the
  # combined capture, then exits <exit_status>.
  local path="$1" sorry_count="$2" exit_status="$3"
  cat > "$path" <<STUBEOF
#!/usr/bin/env bash
if [ "\$1" != "build" ]; then
  echo "stub-guard: unexpected first arg: \$1" >&2
  exit 77
fi
echo "STUB_GUARD_MARKER: guard invoked"
i=1
while [ "\$i" -le $sorry_count ]; do
  echo "warning: Foo.lean:\$i:0: declaration uses 'sorry'"
  i=\$((i + 1))
done
exit $exit_status
STUBEOF
  chmod +x "$path"
}

# =====================================================================
# Fixture A: own-line annotation
#   set_option warn.sorry false in
#   theorem foo : P := sorry
# Expect exactly 1 (the real sorry only). The buggy regex matches "sorry" inside "warn.sorry"
# on the annotation's own line too, yielding 2.
# =====================================================================

cat > "$WORKDIR/fixture_a.lean" <<'EOF'
set_option warn.sorry false in
theorem foo : P := sorry
EOF

OUT_A="$(bash "$TOOL_SRC" "$WORKDIR/fixture_a.lean")"
COUNT_A="$(get_count "$OUT_A")"
if [ "$COUNT_A" = "1" ]; then
  pass "Fixture A (own-line annotation): count == 1"
else
  fail "Fixture A (own-line annotation): expected count 1, got '$COUNT_A'"
fi

NAIVE_A="$(naive_count "$WORKDIR/fixture_a.lean")"
if [ "$NAIVE_A" != "$COUNT_A" ]; then
  pass "Fixture A anti-vacuous: naive per-line count ($NAIVE_A) differs from tool count ($COUNT_A)"
else
  fail "Fixture A anti-vacuous: naive count ($NAIVE_A) equals tool count ($COUNT_A) -- fixture cannot discriminate"
fi

if echo "$OUT_A" | grep -q "theorem foo : P := sorry" && ! echo "$OUT_A" | grep -q "set_option warn.sorry false in$"; then
  pass "Fixture A inventory: contains 'theorem foo' line, excludes 'set_option' line"
else
  fail "Fixture A inventory: expected 'theorem foo' present and 'set_option' absent; got:
$OUT_A"
fi

# =====================================================================
# Fixture B: same-line annotation (non-regression guard)
#   set_option warn.sorry false in theorem bar : Q := sorry
# Expect exactly 1 -- not 0 (a line-skip anti-pattern that would silently drop a real
# same-line sorry) and not 2 (the per-line "search" semantic only counts a match once per
# line, regardless of how many sorry-shaped substrings appear on it).
# =====================================================================

cat > "$WORKDIR/fixture_b.lean" <<'EOF'
set_option warn.sorry false in theorem bar : Q := sorry
EOF

OUT_B="$(bash "$TOOL_SRC" "$WORKDIR/fixture_b.lean")"
COUNT_B="$(get_count "$OUT_B")"
if [ "$COUNT_B" = "1" ]; then
  pass "Fixture B (same-line annotation): count == 1"
else
  fail "Fixture B (same-line annotation): expected count 1, got '$COUNT_B'"
fi

# =====================================================================
# Fixture C: stripper guard -- one `--` line-commented sorry, one sorry inside a nested
# `/- ... /- ... -/ ... -/` block comment, and one sorry inside a `"..."` string literal.
# Each contributes 0; this exercises strip_lean_comments(), which is unrelated to the regex
# fix and must remain byte-identical throughout.
# =====================================================================

cat > "$WORKDIR/fixture_c.lean" <<'EOF'
-- line comment mentions sorry here
/- outer /- inner sorry -/ still outer -/
def baz : String := "a string containing sorry as text"
EOF

OUT_C="$(bash "$TOOL_SRC" "$WORKDIR/fixture_c.lean")"
COUNT_C="$(get_count "$OUT_C")"
if [ "$COUNT_C" = "0" ]; then
  pass "Fixture C (stripper guard): line comment, nested block comment, and string literal each contribute 0"
else
  fail "Fixture C (stripper guard): expected count 0, got '$COUNT_C'"
fi

# =====================================================================
# Fixture D: dotted-name generality -- a line containing `foo.sorry` with no bare sorry.
# Expect 0. The buggy regex fires at the `.`/`s` boundary just as it does for `warn.sorry`.
# =====================================================================

cat > "$WORKDIR/fixture_d.lean" <<'EOF'
def useProof : Bool := foo.sorry
EOF

OUT_D="$(bash "$TOOL_SRC" "$WORKDIR/fixture_d.lean")"
COUNT_D="$(get_count "$OUT_D")"
if [ "$COUNT_D" = "0" ]; then
  pass "Fixture D (dotted-name generality): count == 0"
else
  fail "Fixture D (dotted-name generality): expected count 0, got '$COUNT_D'"
fi

NAIVE_D="$(naive_count "$WORKDIR/fixture_d.lean")"
if [ "$NAIVE_D" != "$COUNT_D" ]; then
  pass "Fixture D anti-vacuous: naive per-line count ($NAIVE_D) differs from tool count ($COUNT_D)"
else
  fail "Fixture D anti-vacuous: naive count ($NAIVE_D) equals tool count ($COUNT_D) -- fixture cannot discriminate"
fi

# =====================================================================
# Fixture E: aggregate -- N=3 own-line annotations, M=2 real sorries. Expect the reported
# total to be M (2), not M + N (5).
# =====================================================================

cat > "$WORKDIR/fixture_e.lean" <<'EOF'
set_option warn.sorry false in
theorem t1 : P1 := trivial
set_option warn.sorry false in
theorem t2 : P2 := sorry
set_option warn.sorry false in
theorem t3 : P3 := trivial
theorem t4 : P4 := sorry
EOF

OUT_E="$(bash "$TOOL_SRC" "$WORKDIR/fixture_e.lean")"
COUNT_E="$(get_count "$OUT_E")"
if [ "$COUNT_E" = "2" ]; then
  pass "Fixture E (aggregate N=3 annotations, M=2 real sorries): count == M == 2"
else
  fail "Fixture E (aggregate N=3 annotations, M=2 real sorries): expected count 2, got '$COUNT_E'"
fi

# =====================================================================
# Fixture F: --cross-check with `lake` absent from PATH. Expect the existing lake-absent
# short-circuit to still win FIRST, regardless of guard presence -- proving the lake-absent check
# is still evaluated before the guard branch in the new three-way routing.
# =====================================================================

NOLAKE_PATH="$(make_isolated_bin_without_lake "$WORKDIR/isobin_f")"
GUARD_STUB_F="$WORKDIR/stub_guard_f.sh"
make_stub_guard "$GUARD_STUB_F" 0 0

OUT_F="$(PATH="$NOLAKE_PATH" LEAN_SORRY_CENSUS_GUARD_BIN="$GUARD_STUB_F" bash "$TOOL_SRC" "$WORKDIR/fixture_a.lean" --cross-check 2>&1)"
if echo "$OUT_F" | grep -qF "cross_check: unavailable (lake not found in PATH)"; then
  pass "Fixture F (lake absent): cross_check unavailable message present regardless of guard presence"
else
  fail "Fixture F (lake absent): expected 'cross_check: unavailable (lake not found in PATH)'; got:
$OUT_F"
fi

# =====================================================================
# Fixture G: --cross-check with `lake` present, guard ABSENT (LEAN_SORRY_CENSUS_GUARD_BIN points
# at a nonexistent path). Expect output shape byte-identical to pre-integration (unguarded)
# behavior: compiler_sorry_count / stripper_sorry_count / cross_check: MATCH lines present, no
# guard marker anywhere in the capture.
# =====================================================================

PROJ_G="$WORKDIR/proj_g"
make_synthetic_lean_project "$PROJ_G"
STUBBIN_G="$WORKDIR/stubbin_g"
make_stub_lake "$STUBBIN_G" 2 0

OUT_G="$(cd "$PROJ_G" && PATH="$STUBBIN_G:$PATH" LEAN_SORRY_CENSUS_GUARD_BIN="$WORKDIR/does-not-exist-guard.sh" bash "$TOOL_SRC" "$WORKDIR/fixture_e.lean" --cross-check 2>&1)"

if echo "$OUT_G" | grep -q '^compiler_sorry_count: 2$' \
  && echo "$OUT_G" | grep -q '^stripper_sorry_count: 2$' \
  && echo "$OUT_G" | grep -q '^cross_check: MATCH$'; then
  pass "Fixture G (lake present, guard absent): unguarded-shape output present (compiler/stripper counts + cross_check: MATCH)"
else
  fail "Fixture G (lake present, guard absent): expected compiler_sorry_count: 2 / stripper_sorry_count: 2 / cross_check: MATCH; got:
$OUT_G"
fi

if ! echo "$OUT_G" | grep -q "STUB_GUARD_MARKER"; then
  pass "Fixture G: no guard marker present -- guard-absent fallback took the plain lake build path"
else
  fail "Fixture G: unexpected guard marker present despite guard being absent"
fi

# =====================================================================
# Fixture H: --cross-check with `lake` present AND guard present (LEAN_SORRY_CENSUS_GUARD_BIN
# points at a stub guard). The guard stub's marker line (echoed to stdout ahead of its synthetic
# "declaration uses 'sorry'" lines) is captured into the script's internal BUILD_OUTPUT along
# with those lines -- but BUILD_OUTPUT is never echoed verbatim to the census script's own
# stdout (by design: the production script must not leak a raw build log, only the derived
# counts), so the marker cannot be grepped for directly in this fixture's captured output. What
# IS observable, and what this fixture asserts instead, is that compiler_sorry_count reflects the
# GUARD stub's distinctive sorry-line count rather than the unused plain-lake stub's -- positive
# proof the guarded path supplied the capture -- and that the marker line (which does not match
# the "declaration uses 'sorry'" pattern) does not corrupt that count, exercising the same
# substring-grep tolerance the real guard's memory-pressure warn line depends on.
# =====================================================================

PROJ_H="$WORKDIR/proj_h"
make_synthetic_lean_project "$PROJ_H"
GUARD_STUB_H="$WORKDIR/stub_guard_h.sh"
# Sorry-line count (3) deliberately differs from BOTH Fixture G's plain-lake stub (2, below) and
# the unused plain-lake stub left on PATH here (1, below) -- a test that accidentally invoked
# either wrong binary would be caught by the compiler_sorry_count assertion.
make_stub_guard "$GUARD_STUB_H" 3 0
STUBBIN_H="$WORKDIR/stubbin_h"
# A stub `lake` is on PATH too (so the lake-absent check still passes), but it must NOT be the
# one that supplies the build output when the guard is present -- the guard stub must be invoked
# instead.
make_stub_lake "$STUBBIN_H" 1 0

OUT_H="$(cd "$PROJ_H" && PATH="$STUBBIN_H:$PATH" LEAN_SORRY_CENSUS_GUARD_BIN="$GUARD_STUB_H" bash "$TOOL_SRC" "$WORKDIR/fixture_e.lean" --cross-check 2>&1)"

if echo "$OUT_H" | grep -q '^compiler_sorry_count: 3$' && echo "$OUT_H" | grep -q '^cross_check: MISMATCH (stripper=2, compiler=3)$'; then
  pass "Fixture H (lake present, guard present): compiler_sorry_count (3) reflects the guard stub, not the unused lake stub (1) -- guarded path was taken, and the guard's marker line did not corrupt the count"
else
  fail "Fixture H (lake present, guard present): expected compiler_sorry_count: 3 and cross_check: MISMATCH (stripper=2, compiler=3) from the guarded capture; got:
$OUT_H"
fi

if [ "$OUT_H" != "$OUT_G" ] && echo "$OUT_H" | grep -q '^compiler_sorry_count: 3$' && echo "$OUT_G" | grep -q '^compiler_sorry_count: 2$'; then
  pass "Fixture H anti-vacuous: captured output differs from Fixture G's (compiler_sorry_count 3 vs 2) -- guard-present and guard-absent paths are distinguishable"
else
  fail "Fixture H anti-vacuous: captured output does not discriminate guard-present (H) from guard-absent (G) -- fixture cannot discriminate"
fi

# =====================================================================
# Fixture I: --cross-check with the guard present but exiting non-zero (a guard-specific failure
# or a passed-through lake failure). Expect the existing "exited non-zero" warning to still fire
# on stderr and to report the guard's exit status.
# =====================================================================

PROJ_I="$WORKDIR/proj_i"
make_synthetic_lean_project "$PROJ_I"
GUARD_STUB_I="$WORKDIR/stub_guard_i.sh"
make_stub_guard "$GUARD_STUB_I" 0 75
STUBBIN_I="$WORKDIR/stubbin_i"
make_stub_lake "$STUBBIN_I" 0 0

ERR_I_FILE="$WORKDIR/fixture_i.err"
OUT_I="$(cd "$PROJ_I" && PATH="$STUBBIN_I:$PATH" LEAN_SORRY_CENSUS_GUARD_BIN="$GUARD_STUB_I" bash "$TOOL_SRC" "$WORKDIR/fixture_a.lean" --cross-check 2>"$ERR_I_FILE")"
ERR_I_TEXT="$(cat "$ERR_I_FILE")"

if echo "$ERR_I_TEXT" | grep -q "exited non-zero (75)"; then
  pass "Fixture I (guarded non-zero exit): warning fires on stderr and reports the guard's status (75)"
else
  fail "Fixture I (guarded non-zero exit): expected 'exited non-zero (75)' on stderr; got:
$ERR_I_TEXT
(stdout was:
$OUT_I)"
fi

# =====================================================================
# Fixture J: nonexistent target -- MUST be a fatal, non-zero exit naming the target on stderr,
# never the old warn-and-skip behavior. This is the direct regression test for the defect this
# task fixes: a target that silently vanished must never be indistinguishable from a target that
# exists and is merely clean.
# =====================================================================

ERR_J_FILE="$WORKDIR/fixture_j.err"
OUT_J="$(bash "$TOOL_SRC" "$WORKDIR/DoesNotExist" 2>"$ERR_J_FILE")"
RC_J=$?
ERR_J="$(cat "$ERR_J_FILE")"
if [ $RC_J -ne 0 ] && [ -z "$OUT_J" ] && echo "$ERR_J" | grep -q "DoesNotExist"; then
  pass "Fixture J (nonexistent target): non-zero exit ($RC_J), no stdout, stderr names the target"
else
  fail "Fixture J (nonexistent target): expected non-zero exit naming the target with no stdout; got exit $RC_J, stdout:
$OUT_J
stderr:
$ERR_J"
fi

# =====================================================================
# Fixture K: an existing target directory that holds zero .lean files -- also MUST be fatal, not
# the old "sorry_count: 0 / exit 0" no-op-that-looks-clean behavior. This is the mutation-check
# fixture: if the empty-file guard were removed, this fixture would (incorrectly) print
# "sorry_count: 0" and exit 0, so its assertion below is exactly what that removal would flip.
# =====================================================================

EMPTY_DIR="$WORKDIR/empty_target_dir"
mkdir -p "$EMPTY_DIR"
touch "$EMPTY_DIR/not_a_lean_file.txt"

ERR_K_FILE="$WORKDIR/fixture_k.err"
OUT_K="$(bash "$TOOL_SRC" "$EMPTY_DIR" 2>"$ERR_K_FILE")"
RC_K=$?
ERR_K="$(cat "$ERR_K_FILE")"
if [ $RC_K -ne 0 ] && [ -z "$OUT_K" ] && echo "$ERR_K" | grep -q "zero .lean files"; then
  pass "Fixture K (existing target, zero .lean files -- mutation check): non-zero exit ($RC_K), stderr explains why"
else
  fail "Fixture K (existing target, zero .lean files -- mutation check): expected non-zero exit; got exit $RC_K, stdout:
$OUT_K
stderr:
$ERR_K"
fi

# =====================================================================
# Fixture L: an existing target directory with real .lean files and no sorry -- MUST stay exit 0
# with sorry_count: 0, so "scanned and clean" remains distinct from "scanned nothing" (Fixture K).
# =====================================================================

CLEAN_DIR="$WORKDIR/clean_target_dir"
mkdir -p "$CLEAN_DIR"
cat > "$CLEAN_DIR/Clean.lean" <<'EOF'
theorem clean_proof : True := trivial
EOF

OUT_L="$(bash "$TOOL_SRC" "$CLEAN_DIR")"
RC_L=$?
COUNT_L="$(get_count "$OUT_L")"
if [ $RC_L -eq 0 ] && [ "$COUNT_L" = "0" ]; then
  pass "Fixture L (existing target, real .lean files, no sorry): exit 0, sorry_count: 0 -- distinct from Fixture K's fatal empty-scan"
else
  fail "Fixture L (existing target, real .lean files, no sorry): expected exit 0 with sorry_count 0; got exit $RC_L, output:
$OUT_L"
fi

# =====================================================================
# Summary
# =====================================================================

info "Passed: $PASSED, Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
