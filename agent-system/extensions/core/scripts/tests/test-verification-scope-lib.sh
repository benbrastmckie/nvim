#!/usr/bin/env bash
# test-verification-scope-lib.sh - Narrow, fixture-driven suite for
# scripts/lib/verification-scope-lib.sh's five public readers.
#
# The library's load-bearing property is its ABSOLUTE fail-open posture: a missing
# .claude-extensions.json, an unparseable one, an absent `verification_scope` key, or a malformed
# entry must each yield the documented default, never a block and never a nonzero return. Each
# case below asserts both the value and `rc 0`, because a library that returned the right string
# while signalling failure would still break every caller that runs under `set -e`.
#
# Fixtures are per-case .claude-extensions.json files written under $WORKDIR; no real repository
# state is read or written.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LIB_UNDER_TEST="$(common_test_resolve_candidate "verification-scope-lib.sh" \
  "$REPO_ROOT/.claude/scripts/lib/verification-scope-lib.sh" \
  "$SCRIPT_DIR/../lib/verification-scope-lib.sh")" || exit 2

PASSED=0
FAILED=0
common_test_workdir_init

# shellcheck source=/dev/null
source "$LIB_UNDER_TEST"

# plant_scope <case_name> <file_content> -- writes a fixture repo root carrying the given
# .claude-extensions.json content (pass the empty string to plant NO file at all) and echoes it.
plant_scope() {
  local case_name="$1" content="$2" root
  root="${WORKDIR}/${case_name}"
  mkdir -p "$root"
  [ -n "$content" ] && printf '%s' "$content" > "${root}/.claude-extensions.json"
  printf '%s\n' "$root"
}

# assert_lines <description> <expected_newline_separated> <actual> <rc>
assert_lines() {
  local desc="$1" expected="$2" actual="$3" rc="$4"
  if [ "$rc" -ne 0 ]; then
    common_test_fail "$desc (returned rc=$rc; every reader must always return 0)"
    return 0
  fi
  if [ "$actual" = "$expected" ]; then
    common_test_pass "$desc"
  else
    common_test_fail "$desc"
    common_test_info "expected: $(printf '%q' "$expected")"
    common_test_info "actual:   $(printf '%q' "$actual")"
  fi
  return 0
}

# --- tree_roots -------------------------------------------------------------------------------

root="$(plant_scope no-file "")"
out="$(verification_scope_tree_roots "$root")"; rc=$?
assert_lines "tree_roots: absent .claude-extensions.json defaults to '.'" "." "$out" "$rc"

root="$(plant_scope no-key '{"extensions": {}, "version": 1}')"
out="$(verification_scope_tree_roots "$root")"; rc=$?
assert_lines "tree_roots: absent verification_scope key defaults to '.'" "." "$out" "$rc"

root="$(plant_scope unparseable '{"extensions": {},,, BROKEN')"
out="$(verification_scope_tree_roots "$root")"; rc=$?
assert_lines "tree_roots: unparseable JSON defaults to '.'" "." "$out" "$rc"

root="$(plant_scope empty-array '{"verification_scope": {"tree_roots": []}}')"
out="$(verification_scope_tree_roots "$root")"; rc=$?
assert_lines "tree_roots: declared-but-empty array defaults to '.'" "." "$out" "$rc"

root="$(plant_scope wrong-type '{"verification_scope": {"tree_roots": "notanarray"}}')"
out="$(verification_scope_tree_roots "$root")"; rc=$?
assert_lines "tree_roots: non-array value defaults to '.'" "." "$out" "$rc"

root="$(plant_scope mixed-type '{"verification_scope": {"tree_roots": [".claude", 7]}}')"
out="$(verification_scope_tree_roots "$root")"; rc=$?
assert_lines "tree_roots: array with a non-string member defaults to '.'" "." "$out" "$rc"

root="$(plant_scope empty-string-member '{"verification_scope": {"tree_roots": [".claude", ""]}}')"
out="$(verification_scope_tree_roots "$root")"; rc=$?
assert_lines "tree_roots: array with an empty-string member defaults to '.'" "." "$out" "$rc"

root="$(plant_scope one-root '{"verification_scope": {"tree_roots": [".claude"]}}')"
out="$(verification_scope_tree_roots "$root")"; rc=$?
assert_lines "tree_roots: single declared root is returned verbatim" ".claude" "$out" "$rc"

root="$(plant_scope three-roots '{"verification_scope": {"tree_roots": [".claude", ".opencode", "isolated"]}}')"
out="$(verification_scope_tree_roots "$root")"; rc=$?
assert_lines "tree_roots: three declared roots print one per line, in order" \
  ".claude
.opencode
isolated" "$out" "$rc"

# A `verification_scope` sibling key must not disturb the loader's own two keys, and the
# RESERVED project_gates/closing_gate fields must be ignored rather than tripping validation.
root="$(plant_scope with-reserved '{"extensions": {"core": {"source_dir": "/x"}}, "version": 1, "verification_scope": {"tree_roots": ["."], "project_gates": "reserved", "closing_gate": "reserved"}}')"
out="$(verification_scope_tree_roots "$root")"; rc=$?
assert_lines "tree_roots: RESERVED project_gates/closing_gate fields are ignored, not rejected" \
  "." "$out" "$rc"

# --- project_suite_roots ----------------------------------------------------------------------

root="$(plant_scope psr-no-file "")"
out="$(verification_scope_project_suite_roots "$root")"; rc=$?
assert_lines "project_suite_roots: absent file defaults to empty output" "" "$out" "$rc"

root="$(plant_scope psr-no-key '{"verification_scope": {"tree_roots": ["."]}}')"
out="$(verification_scope_project_suite_roots "$root")"; rc=$?
assert_lines "project_suite_roots: undeclared defaults to empty output" "" "$out" "$rc"

root="$(plant_scope psr-malformed '{"verification_scope": {"project_suite_roots": {"a": 1}}}')"
out="$(verification_scope_project_suite_roots "$root")"; rc=$?
assert_lines "project_suite_roots: malformed value defaults to empty output" "" "$out" "$rc"

root="$(plant_scope psr-declared '{"verification_scope": {"project_suite_roots": ["tests", "sf1-v2/tests"]}}')"
out="$(verification_scope_project_suite_roots "$root")"; rc=$?
assert_lines "project_suite_roots: declared roots print one per line, in order" \
  "tests
sf1-v2/tests" "$out" "$rc"

# --- resolver.command -------------------------------------------------------------------------

root="$(plant_scope cmd-no-file "")"
out="$(verification_scope_resolver_command "$root")"; rc=$?
assert_lines "resolver_command: absent file prints nothing (= use default backend)" "" "$out" "$rc"

root="$(plant_scope cmd-no-resolver '{"verification_scope": {"tree_roots": ["."]}}')"
out="$(verification_scope_resolver_command "$root")"; rc=$?
assert_lines "resolver_command: no resolver object prints nothing" "" "$out" "$rc"

root="$(plant_scope cmd-empty '{"verification_scope": {"resolver": {"command": ""}}}')"
out="$(verification_scope_resolver_command "$root")"; rc=$?
assert_lines "resolver_command: empty-string command prints nothing" "" "$out" "$rc"

root="$(plant_scope cmd-declared '{"verification_scope": {"resolver": {"command": "bash tools/resolve.sh --paths"}}}')"
out="$(verification_scope_resolver_command "$root")"; rc=$?
assert_lines "resolver_command: declared command is returned verbatim, spaces intact" \
  "bash tools/resolve.sh --paths" "$out" "$rc"

# --- resolver.compose -------------------------------------------------------------------------

root="$(plant_scope compose-no-file "")"
out="$(verification_scope_resolver_compose "$root")"; rc=$?
assert_lines "resolver_compose: absent file defaults to 'union'" "union" "$out" "$rc"

root="$(plant_scope compose-undeclared '{"verification_scope": {"resolver": {"command": "x"}}}')"
out="$(verification_scope_resolver_compose "$root")"; rc=$?
assert_lines "resolver_compose: command without compose defaults to 'union'" "union" "$out" "$rc"

root="$(plant_scope compose-replace '{"verification_scope": {"resolver": {"compose": "replace"}}}')"
out="$(verification_scope_resolver_compose "$root")"; rc=$?
assert_lines "resolver_compose: declared 'replace' is honoured" "replace" "$out" "$rc"

root="$(plant_scope compose-union '{"verification_scope": {"resolver": {"compose": "union"}}}')"
out="$(verification_scope_resolver_compose "$root")"; rc=$?
assert_lines "resolver_compose: declared 'union' is honoured" "union" "$out" "$rc"

root="$(plant_scope compose-garbage '{"verification_scope": {"resolver": {"compose": "sideways"}}}')"
out="$(verification_scope_resolver_compose "$root")"; rc=$?
assert_lines "resolver_compose: out-of-enum value falls back to 'union'" "union" "$out" "$rc"

# --- closing_gate ------------------------------------------------------------------------------

root="$(plant_scope cg-no-file "")"
out="$(verification_scope_closing_gate "$root")"; rc=$?
assert_lines "closing_gate: absent file prints nothing (= no declared closing gate)" "" "$out" "$rc"

root="$(plant_scope cg-undeclared '{"verification_scope": {"tree_roots": ["."]}}')"
out="$(verification_scope_closing_gate "$root")"; rc=$?
assert_lines "closing_gate: key absent on an otherwise-populated object prints nothing" "" "$out" "$rc"

root="$(plant_scope cg-declared '{"verification_scope": {"closing_gate": "bash tools/close.sh --all"}}')"
out="$(verification_scope_closing_gate "$root")"; rc=$?
assert_lines "closing_gate: declared command is returned verbatim, spaces intact" \
  "bash tools/close.sh --all" "$out" "$rc"

root="$(plant_scope cg-empty '{"verification_scope": {"closing_gate": ""}}')"
out="$(verification_scope_closing_gate "$root")"; rc=$?
assert_lines "closing_gate: empty-string command prints nothing" "" "$out" "$rc"

root="$(plant_scope cg-non-string '{"verification_scope": {"closing_gate": 42}}')"
out="$(verification_scope_closing_gate "$root")"; rc=$?
assert_lines "closing_gate: a non-string (number) value is malformed and prints nothing" "" "$out" "$rc"

root="$(plant_scope cg-non-string-obj '{"verification_scope": {"closing_gate": {"nested": true}}}')"
out="$(verification_scope_closing_gate "$root")"; rc=$?
assert_lines "closing_gate: a non-string (object) value is malformed and prints nothing" "" "$out" "$rc"

# --- sourcing posture -------------------------------------------------------------------------
# The header commits to setting NO shell options in the caller. A regression here silently
# changes error handling for every consumer that sources the library.
opts_before="$(set +o)"
# shellcheck source=/dev/null
source "$LIB_UNDER_TEST"
opts_after="$(set +o)"
if [ "$opts_before" = "$opts_after" ]; then
  common_test_pass "sourcing the library changes no shell option in the caller"
else
  common_test_fail "sourcing the library changed the caller's shell options"
  common_test_info "diff: $(diff <(printf '%s\n' "$opts_before") <(printf '%s\n' "$opts_after") | tr '\n' ' ')"
fi

echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
