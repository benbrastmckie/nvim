#!/usr/bin/env bash
# test-lean-src-roots.sh -- regression suite for lean-src-roots.sh.
#
# Covers the resolution precedence (lakefile.toml over LEAN_SRC_ROOTS), the Lake-default
# application (srcDir "." , roots [name]), the --default-targets filter, and every documented
# loud-failure path: no lakefile and no env, malformed TOML, zero lean_lib entries, zero existing
# roots, and zero .lean files across existing roots.
#
# Follows the core shell-test convention (see
# agent-system/extensions/core/scripts/tests/test-census-count.sh and this extension's own
# test-lean-sorry-census.sh): pass()/fail()/info() helpers, PASSED/FAILED integer counters,
# mktemp -d workdir with a trap EXIT cleanup, exit 0 on all-pass and exit 1 on any-fail.
#
# Mutation check (Fixture M): asserts that removing the empty-.lean-files check would let a
# fixture that exercises exactly that path pass silently -- proving the fixture actually
# discriminates the loud-failure behavior rather than being vacuous coverage. Concretely: fixture
# G's directory has zero .lean files by construction; if the empty-files guard in the script were
# deleted, resolution would (incorrectly) succeed and print the root. Fixture G's own assertion
# (non-zero exit, root named on stderr) is therefore the mutation-killing assertion for that
# guard, and this comment records the reasoning per
# context/standards/shell-script-testing.md's mutation-check discipline.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_SRC="$SCRIPT_DIR/../lean-src-roots.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$TOOL_SRC" ]; then
  echo "ERROR: expected lean-src-roots.sh at $TOOL_SRC" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required by lean-src-roots.sh and is not on PATH" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

run_tool() {
  # run_tool <repo-dir> [extra args...] -- runs the tool with cwd set to <repo-dir> (so
  # `git rev-parse --show-toplevel`/pwd fallback resolves there), NOT inside a git work tree
  # (this suite's fixtures are plain directories -- the tool's non-git CWD fallback is exercised
  # deliberately, since a synthetic `git init` per fixture would be needless setup for behavior
  # this suite does not otherwise care about).
  local dir="$1"
  shift
  (cd "$dir" && bash "$TOOL_SRC" "$@")
}

# =====================================================================
# Fixture A: BimodalLogic-shaped lakefile.toml (srcDir = "Tests" on one lib, several libs)
# Expect: both the srcDir-default lib's directory+file candidates and the srcDir="Tests" lib's
# candidates resolve, and only the ones that exist on disk are printed.
# =====================================================================

PROJ_A="$WORKDIR/proj_a"
mkdir -p "$PROJ_A/FormalSystem" "$PROJ_A/Tests/BimodalTest"
touch "$PROJ_A/FormalSystem/Basic.lean" "$PROJ_A/Tests/BimodalTest/Basic.lean"
cat > "$PROJ_A/lakefile.toml" <<'EOF'
name = "BimodalLogic"
defaultTargets = ["FormalSystem"]

[[lean_lib]]
name = "FormalSystem"

[[lean_lib]]
name = "BimodalTest"
srcDir = "Tests"
EOF

OUT_A="$(run_tool "$PROJ_A")"
RC_A=$?
if [ $RC_A -eq 0 ] && echo "$OUT_A" | grep -qx "FormalSystem" && echo "$OUT_A" | grep -qx "Tests/BimodalTest"; then
  pass "Fixture A (BimodalLogic-shaped, mixed srcDir): resolves both libs' existing roots, exit 0"
else
  fail "Fixture A (BimodalLogic-shaped, mixed srcDir): expected exit 0 with FormalSystem and Tests/BimodalTest; got exit $RC_A, output:
$OUT_A"
fi

if ! echo "$OUT_A" | grep -qx "FormalSystem.lean" && ! echo "$OUT_A" | grep -qx "Tests/BimodalTest.lean"; then
  pass "Fixture A: candidate .lean files that do not exist on disk are correctly omitted"
else
  fail "Fixture A: expected FormalSystem.lean / Tests/BimodalTest.lean to be omitted (not on disk); got:
$OUT_A"
fi

# =====================================================================
# Fixture B: cslib-shaped lakefile.toml (defaults only: no srcDir, no roots, no globs)
# =====================================================================

PROJ_B="$WORKDIR/proj_b"
mkdir -p "$PROJ_B/Cslib" "$PROJ_B/CslibTests"
touch "$PROJ_B/Cslib/Basic.lean" "$PROJ_B/CslibTests/Basic.lean"
cat > "$PROJ_B/lakefile.toml" <<'EOF'
name = "cslib"
defaultTargets = ["Cslib"]

[[lean_lib]]
name = "Cslib"

[[lean_lib]]
name = "CslibTests"
EOF

OUT_B="$(run_tool "$PROJ_B")"
RC_B=$?
if [ $RC_B -eq 0 ] && echo "$OUT_B" | grep -qx "Cslib" && echo "$OUT_B" | grep -qx "CslibTests"; then
  pass "Fixture B (cslib-shaped, defaults only): resolves both libs by Lake default rules, exit 0"
else
  fail "Fixture B (cslib-shaped, defaults only): expected exit 0 with Cslib and CslibTests; got exit $RC_B, output:
$OUT_B"
fi

# =====================================================================
# Fixture C: --default-targets flag limits output to declared defaultTargets
# =====================================================================

OUT_C="$(run_tool "$PROJ_B" --default-targets)"
RC_C=$?
if [ $RC_C -eq 0 ] && echo "$OUT_C" | grep -qx "Cslib" && ! echo "$OUT_C" | grep -qx "CslibTests"; then
  pass "Fixture C (--default-targets): restricts output to Cslib only"
else
  fail "Fixture C (--default-targets): expected only Cslib; got exit $RC_C, output:
$OUT_C"
fi

# =====================================================================
# Fixture D: missing root directory (lakefile declares a lib whose srcDir/roots do not exist)
# Expect: non-zero exit naming the tried root(s).
# =====================================================================

PROJ_D="$WORKDIR/proj_d"
mkdir -p "$PROJ_D"
cat > "$PROJ_D/lakefile.toml" <<'EOF'
name = "ghost"

[[lean_lib]]
name = "GhostLib"
EOF

ERR_D_FILE="$WORKDIR/fixture_d.err"
OUT_D="$(run_tool "$PROJ_D" 2>"$ERR_D_FILE")"
RC_D=$?
ERR_D="$(cat "$ERR_D_FILE")"
if [ $RC_D -ne 0 ] && echo "$ERR_D" | grep -q "GhostLib"; then
  pass "Fixture D (missing root dir): non-zero exit ($RC_D), stderr names the tried root"
else
  fail "Fixture D (missing root dir): expected non-zero exit naming GhostLib; got exit $RC_D, stderr:
$ERR_D"
fi

# =====================================================================
# Fixture E: roots exist but hold zero .lean files -- non-zero exit
# =====================================================================

PROJ_E="$WORKDIR/proj_e"
mkdir -p "$PROJ_E/EmptyLib"
touch "$PROJ_E/EmptyLib/README.md"
cat > "$PROJ_E/lakefile.toml" <<'EOF'
name = "empty"

[[lean_lib]]
name = "EmptyLib"
EOF

ERR_E_FILE="$WORKDIR/fixture_e.err"
OUT_E="$(run_tool "$PROJ_E" 2>"$ERR_E_FILE")"
RC_E=$?
ERR_E="$(cat "$ERR_E_FILE")"
if [ $RC_E -ne 0 ] && echo "$ERR_E" | grep -q "zero .lean files" && echo "$ERR_E" | grep -q "EmptyLib"; then
  pass "Fixture E (zero .lean files in existing root): non-zero exit ($RC_E), stderr names the root"
else
  fail "Fixture E (zero .lean files in existing root): expected non-zero exit naming EmptyLib; got exit $RC_E, stderr:
$ERR_E"
fi

# =====================================================================
# Fixture F: no lakefile.toml, LEAN_SRC_ROOTS set to an existing, non-empty path -- used
# =====================================================================

PROJ_F="$WORKDIR/proj_f"
mkdir -p "$PROJ_F/CustomRoot"
touch "$PROJ_F/CustomRoot/Basic.lean"

OUT_F="$(cd "$PROJ_F" && LEAN_SRC_ROOTS="CustomRoot" bash "$TOOL_SRC")"
RC_F=$?
if [ $RC_F -eq 0 ] && echo "$OUT_F" | grep -qx "CustomRoot"; then
  pass "Fixture F (no lakefile, LEAN_SRC_ROOTS set to existing path): used, exit 0"
else
  fail "Fixture F (no lakefile, LEAN_SRC_ROOTS set to existing path): expected exit 0 with CustomRoot; got exit $RC_F, output:
$OUT_F"
fi

# =====================================================================
# Fixture G: no lakefile.toml and no LEAN_SRC_ROOTS -- non-zero exit
# This is also the mutation-check fixture (see header comment): it is the plainest instance of
# the "nothing to resolve" path, and its non-zero-exit assertion is what a deleted loud-failure
# guard would silently flip to a false pass.
# =====================================================================

PROJ_G="$WORKDIR/proj_g"
mkdir -p "$PROJ_G"

ERR_G_FILE="$WORKDIR/fixture_g.err"
OUT_G="$(cd "$PROJ_G" && env -u LEAN_SRC_ROOTS bash "$TOOL_SRC" 2>"$ERR_G_FILE")"
RC_G=$?
ERR_G="$(cat "$ERR_G_FILE")"
if [ $RC_G -ne 0 ] && [ -z "$OUT_G" ] && echo "$ERR_G" | grep -q "lakefile.toml"; then
  pass "Fixture G (no lakefile, no env): non-zero exit ($RC_G), no stdout, stderr explains why"
else
  fail "Fixture G (no lakefile, no env): expected non-zero exit, empty stdout; got exit $RC_G, stdout:
$OUT_G
stderr:
$ERR_G"
fi

# =====================================================================
# Fixture H: lakefile.toml present AND LEAN_SRC_ROOTS set -- env is ignored, with a notice,
# and resolution proceeds from the lakefile
# =====================================================================

PROJ_H="$WORKDIR/proj_h"
mkdir -p "$PROJ_H/RealLib"
touch "$PROJ_H/RealLib/Basic.lean"
cat > "$PROJ_H/lakefile.toml" <<'EOF'
name = "hlib"

[[lean_lib]]
name = "RealLib"
EOF

ERR_H_FILE="$WORKDIR/fixture_h.err"
OUT_H="$(cd "$PROJ_H" && LEAN_SRC_ROOTS="SomeOtherPath" bash "$TOOL_SRC" 2>"$ERR_H_FILE")"
RC_H=$?
ERR_H="$(cat "$ERR_H_FILE")"
if [ $RC_H -eq 0 ] && echo "$OUT_H" | grep -qx "RealLib" && ! echo "$OUT_H" | grep -q "SomeOtherPath" && echo "$ERR_H" | grep -q "ignoring LEAN_SRC_ROOTS"; then
  pass "Fixture H (lakefile + env both present): lakefile wins, stderr notes the env value was ignored"
else
  fail "Fixture H (lakefile + env both present): expected RealLib on stdout and an ignore notice on stderr; got exit $RC_H, stdout:
$OUT_H
stderr:
$ERR_H"
fi

# =====================================================================
# Fixture I: malformed TOML -- non-zero exit
# =====================================================================

PROJ_I="$WORKDIR/proj_i"
mkdir -p "$PROJ_I"
printf 'not valid toml [[[\n' > "$PROJ_I/lakefile.toml"

ERR_I_FILE="$WORKDIR/fixture_i.err"
OUT_I="$(run_tool "$PROJ_I" 2>"$ERR_I_FILE")"
RC_I=$?
ERR_I="$(cat "$ERR_I_FILE")"
if [ $RC_I -ne 0 ] && [ -z "$OUT_I" ] && echo "$ERR_I" | grep -qi "cannot parse"; then
  pass "Fixture I (malformed TOML): non-zero exit ($RC_I), stderr reports the parse failure"
else
  fail "Fixture I (malformed TOML): expected non-zero exit reporting a parse failure; got exit $RC_I, stdout:
$OUT_I
stderr:
$ERR_I"
fi

# =====================================================================
# Summary
# =====================================================================

info "Passed: $PASSED, Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
