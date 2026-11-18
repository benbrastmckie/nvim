#!/usr/bin/env bash
# test-suite-resolver-lib.sh - Narrow, fixture-driven suite for
# scripts/lib/suite-resolver-lib.sh's two public functions.
#
# The property this library exists to provide, and the one asserted most directly below, is
# ANTI-COLLAPSE: `suite_selection_select PATH [PATH...]` escalates an entire multi-path call to
# the `__FULL_SWEEP__` sentinel the moment ONE path is unmappable, so this library calls it one
# path at a time. A regression that restored the multi-path call would make a single new file
# drown out every real suite the other touched paths resolve to -- silently reverting the fast
# path to a full battery, which is exactly the collapse the originating record removed.
#
# Determinism: every case steers the explicit map through SUITE_RESOLVER_MAP_DATA and uses
# synthetic paths, so no assertion depends on the real checked-in map rows or on which suites
# happen to exist in the surrounding corpus (both of which are expected to change).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LIB_UNDER_TEST="$(common_test_resolve_candidate "suite-resolver-lib.sh" \
  "$REPO_ROOT/.claude/scripts/lib/suite-resolver-lib.sh" \
  "$SCRIPT_DIR/../lib/suite-resolver-lib.sh")" || exit 2

PASSED=0
FAILED=0
common_test_workdir_init

# shellcheck source=/dev/null
source "$LIB_UNDER_TEST"

# ─── Default-backend stubs (defined AFTER sourcing, so they shadow the real library) ───────────
# This suite tests THIS library's composition, de-duplication and anti-collapse logic -- not
# suite-selection-lib.sh's own basename/class rules, which have their own suite and whose real
# rules match broad globs (a "synthetic" path is NOT reliably unmapped against the live corpus,
# so asserting against it would make this suite a fragile proxy for that one). Stubbing the two
# functions the default backend calls makes every case below deterministic and independent of
# which suites happen to exist in the surrounding tree.
#
#   basename-ok/<anything>  -> mapped by basename resolution to test-basename.sh
#   everything else         -> unmapped, so the explicit map pre-pass and the UNRESOLVED
#                              disposition are the paths actually under test
suite_selection_unmapped() {
  case "$1" in
    basename-ok/*) : ;;        # mapped: emit nothing
    *) printf '%s\n' "$1" ;;   # unmapped: echo the path back
  esac
  return 0
}
suite_selection_select() {
  case "$1" in
    basename-ok/*) printf '%s\n' "test-basename.sh" ;;
  esac
  return 0
}

# Deterministic explicit map: TAB-separated <path_glob> <suites> <reason>.
MAP="${WORKDIR}/map.data"
printf '%s\n' \
  '# comment row must be skipped' \
  '' \
  'fixture/alpha/*	test-alpha.sh	alpha fixture' \
  'fixture/multi/*	test-m1.sh,test-m2.sh	two suites, one row' \
  'fixture/**	test-catchall.sh	later row; must lose to the rows above' \
  > "$MAP"
export SUITE_RESOLVER_MAP_DATA="$MAP"

# A path no map row and no basename resolution can cover.
UNMAPPABLE="zzz-nonexistent-dir/zzz-nonexistent-file.qqq"

sel_lines() { printf '%s\n' "$1" | grep '^SELECT ' | sed 's/^SELECT //' | sort | tr '\n' ' '; }
unres_lines() { printf '%s\n' "$1" | grep '^UNRESOLVED ' | sed 's/^UNRESOLVED //' | sort | tr '\n' ' '; }

# --- usage errors -----------------------------------------------------------------------------

out="$(suite_resolver_resolve "$WORKDIR" 2>/dev/null)"; rc=$?
if [ "$rc" -eq 2 ]; then
  common_test_pass "resolve: zero paths is a usage error (rc 2)"
else
  common_test_fail "resolve: expected rc 2 for zero paths, got $rc"
fi

# --- explicit map pre-pass --------------------------------------------------------------------

out="$(suite_resolver_resolve "$WORKDIR" "fixture/alpha/thing.txt")"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(sel_lines "$out")" = "test-alpha.sh " ] && [ -z "$(unres_lines "$out")" ]; then
  common_test_pass "resolve: a map-matched path yields its SELECT token and no UNRESOLVED line"
else
  common_test_fail "resolve: map-matched path (rc=$rc)"
  common_test_info "actual: $(printf '%q' "$out")"
fi

out="$(suite_resolver_resolve "$WORKDIR" "fixture/multi/thing.txt")"
if [ "$(sel_lines "$out")" = "test-m1.sh test-m2.sh " ]; then
  common_test_pass "resolve: a map row naming two suites emits both SELECT tokens"
else
  common_test_fail "resolve: multi-suite map row: '$(sel_lines "$out")'"
fi

out="$(suite_resolver_resolve "$WORKDIR" "fixture/alpha/x")"
if [ "$(sel_lines "$out")" = "test-alpha.sh " ]; then
  common_test_pass "resolve: the FIRST matching map row wins over a later catch-all"
else
  common_test_fail "resolve: first-match precedence: '$(sel_lines "$out")'"
fi

out="$(suite_resolver_resolve "$WORKDIR" "$UNMAPPABLE")"; rc=$?
if [ "$rc" -eq 0 ] && [ -z "$(sel_lines "$out")" ] && [ "$(unres_lines "$out")" = "$UNMAPPABLE " ]; then
  common_test_pass "resolve: an unmappable path yields UNRESOLVED and rc 0 (empty SELECT is legal)"
else
  common_test_fail "resolve: unmappable path (rc=$rc)"
  common_test_info "actual: $(printf '%q' "$out")"
fi

# --- ANTI-COLLAPSE: the reason this library wraps suite_selection_select ------------------------

out="$(suite_resolver_resolve "$WORKDIR" "basename-ok/a.txt" "fixture/alpha/a.txt" "$UNMAPPABLE" "fixture/multi/b.txt")"
sel="$(sel_lines "$out")"
unres="$(unres_lines "$out")"
if [ "$sel" = "test-alpha.sh test-basename.sh test-m1.sh test-m2.sh " ] && [ "$unres" = "$UNMAPPABLE " ]; then
  common_test_pass "resolve: one unmappable path does NOT collapse the set (resolved peers survive)"
else
  common_test_fail "resolve: ANTI-COLLAPSE violated"
  common_test_info "SELECT:     '$sel'"
  common_test_info "UNRESOLVED: '$unres'"
fi

case "$out" in
  *__FULL_SWEEP__*)
    common_test_fail "resolve: the __FULL_SWEEP__ sentinel leaked into the published output shape" ;;
  *)
    common_test_pass "resolve: the __FULL_SWEEP__ sentinel never appears in published output" ;;
esac

out="$(suite_resolver_resolve "$WORKDIR" "fixture/alpha/a" "fixture/alpha/b" "fixture/alpha/c")"
if [ "$(printf '%s\n' "$out" | grep -c '^SELECT test-alpha.sh$')" -eq 1 ]; then
  common_test_pass "resolve: repeated resolution of one suite is de-duplicated to a single token"
else
  common_test_fail "resolve: SELECT tokens not de-duplicated"
  common_test_info "actual: $(printf '%q' "$out")"
fi

# Every input path gets a disposition: resolved (contributing a token) or UNRESOLVED.
out="$(suite_resolver_resolve "$WORKDIR" "fixture/alpha/a" "$UNMAPPABLE" "zzz-other/none.qqq")"
if [ "$(printf '%s\n' "$out" | grep -c '^UNRESOLVED ')" -eq 2 ]; then
  common_test_pass "resolve: every unresolved path is reported individually, never aggregated"
else
  common_test_fail "resolve: expected 2 UNRESOLVED lines"
  common_test_info "actual: $(printf '%q' "$out")"
fi

# --- declared backend: conformance check ------------------------------------------------------

good_backend="${WORKDIR}/good-backend.sh"
cat > "$good_backend" <<'EOF'
#!/usr/bin/env bash
# Conforming: only SELECT/UNRESOLVED on stdout, diagnostics to stderr, exit 0.
echo "a diagnostic that must not break conformance" >&2
while IFS= read -r p; do
  case "$p" in
    declared/*) echo "SELECT test-declared.sh" ;;
    *) echo "UNRESOLVED $p" ;;
  esac
done
exit 0
EOF
chmod +x "$good_backend"

if suite_resolver_conformance_check "bash $good_backend" "$WORKDIR" 2>/dev/null; then
  common_test_pass "conformance: a conforming backend is accepted (stderr diagnostics allowed)"
else
  common_test_fail "conformance: a conforming backend was refused"
fi

bad_exit="${WORKDIR}/bad-exit.sh"
printf '%s\n' '#!/usr/bin/env bash' 'cat >/dev/null' 'exit 7' > "$bad_exit"
chmod +x "$bad_exit"
if suite_resolver_conformance_check "bash $bad_exit" "$WORKDIR" 2>/dev/null; then
  common_test_fail "conformance: a backend exiting 7 was accepted (must be one of 0/2/3)"
else
  common_test_pass "conformance: a backend exiting outside 0/2/3 is refused"
fi

bad_shape="${WORKDIR}/bad-shape.sh"
printf '%s\n' '#!/usr/bin/env bash' 'cat >/dev/null' 'echo "Resolving suites, please wait..."' 'exit 0' > "$bad_shape"
chmod +x "$bad_shape"
if suite_resolver_conformance_check "bash $bad_shape" "$WORKDIR" 2>/dev/null; then
  common_test_fail "conformance: a backend printing a banner on stdout was accepted"
else
  common_test_pass "conformance: a backend emitting a non-SELECT/UNRESOLVED stdout line is refused"
fi

for code in 0 2 3; do
  probe="${WORKDIR}/exit-${code}.sh"
  printf '%s\n' '#!/usr/bin/env bash' 'cat >/dev/null' "exit ${code}" > "$probe"
  chmod +x "$probe"
  if suite_resolver_conformance_check "bash $probe" "$WORKDIR" 2>/dev/null; then
    common_test_pass "conformance: documented exit code ${code} is accepted"
  else
    common_test_fail "conformance: documented exit code ${code} was refused"
  fi
done

# --- declared backend: composition ------------------------------------------------------------

# compose=union -- the declared backend's tokens join the default+map resolution.
union_root="${WORKDIR}/union-root"; mkdir -p "$union_root"
cat > "${union_root}/.claude-extensions.json" <<EOF
{"verification_scope": {"resolver": {"command": "bash ${good_backend}", "compose": "union"}}}
EOF
out="$(suite_resolver_resolve "$union_root" "fixture/alpha/a.txt" "declared/b.txt")"
sel="$(sel_lines "$out")"
if [ "$sel" = "test-alpha.sh test-declared.sh " ]; then
  common_test_pass "resolve/union: declared-backend tokens are unioned with the default+map set"
else
  common_test_fail "resolve/union: expected both tokens, got '$sel'"
fi

if [ -z "$(unres_lines "$out")" ]; then
  common_test_pass "resolve/union: a path either backend resolves is not reported UNRESOLVED"
else
  common_test_fail "resolve/union: unexpected UNRESOLVED '$(unres_lines "$out")'"
fi

out="$(suite_resolver_resolve "$union_root" "$UNMAPPABLE")"
if [ "$(unres_lines "$out")" = "$UNMAPPABLE " ]; then
  common_test_pass "resolve/union: a path BOTH backends leave unresolved is UNRESOLVED"
else
  common_test_fail "resolve/union: expected UNRESOLVED for a doubly-unresolved path"
fi

# compose=replace -- the default backend and explicit map are not consulted at all.
replace_root="${WORKDIR}/replace-root"; mkdir -p "$replace_root"
cat > "${replace_root}/.claude-extensions.json" <<EOF
{"verification_scope": {"resolver": {"command": "bash ${good_backend}", "compose": "replace"}}}
EOF
out="$(suite_resolver_resolve "$replace_root" "fixture/alpha/a.txt" "declared/b.txt")"
sel="$(sel_lines "$out")"
if [ "$sel" = "test-declared.sh " ]; then
  common_test_pass "resolve/replace: only the declared backend's tokens are used"
else
  common_test_fail "resolve/replace: expected only test-declared.sh, got '$sel'"
fi

if [ "$(unres_lines "$out")" = "fixture/alpha/a.txt " ]; then
  common_test_pass "resolve/replace: a map-only path is UNRESOLVED (the map is not consulted)"
else
  common_test_fail "resolve/replace: expected the map-only path UNRESOLVED, got '$(unres_lines "$out")'"
fi

# An undeclared repo root must behave exactly as the default backend alone.
plain_root="${WORKDIR}/plain-root"; mkdir -p "$plain_root"
out_plain="$(suite_resolver_resolve "$plain_root" "fixture/alpha/a.txt" "$UNMAPPABLE")"
out_none="$(suite_resolver_resolve "$WORKDIR" "fixture/alpha/a.txt" "$UNMAPPABLE")"
if [ "$out_plain" = "$out_none" ]; then
  common_test_pass "resolve: a repo declaring nothing is byte-for-byte the default-backend result"
else
  common_test_fail "resolve: undeclared repo diverged from the default-backend result"
  common_test_info "declared-nothing: $(printf '%q' "$out_plain")"
  common_test_info "no-file:          $(printf '%q' "$out_none")"
fi

# A declared backend that exits nonzero must not poison the default resolution.
broken_root="${WORKDIR}/broken-root"; mkdir -p "$broken_root"
cat > "${broken_root}/.claude-extensions.json" <<EOF
{"verification_scope": {"resolver": {"command": "bash ${bad_exit}", "compose": "union"}}}
EOF
out="$(suite_resolver_resolve "$broken_root" "fixture/alpha/a.txt")"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(sel_lines "$out")" = "test-alpha.sh " ]; then
  common_test_pass "resolve/union: a failing declared backend degrades to the default resolution"
else
  common_test_fail "resolve/union: failing backend poisoned the result (rc=$rc)"
  common_test_info "actual: $(printf '%q' "$out")"
fi

# --- published output shape -------------------------------------------------------------------

out="$(suite_resolver_resolve "$WORKDIR" "fixture/alpha/a.txt" "$UNMAPPABLE")"
stray="$(printf '%s\n' "$out" | grep -vcE '^(SELECT|UNRESOLVED) .+$' || true)"
if [ "$stray" -eq 0 ]; then
  common_test_pass "resolve: stdout carries only 'SELECT <token>' / 'UNRESOLVED <path>' lines"
else
  common_test_fail "resolve: $stray stdout line(s) violate the published shape"
  common_test_info "actual: $(printf '%q' "$out")"
fi

echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
