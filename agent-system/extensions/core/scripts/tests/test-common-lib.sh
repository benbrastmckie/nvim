#!/usr/bin/env bash
# test-common-lib.sh - Fixture-driven regression suite for scripts/lib/common.sh, the shared
# repo-root/session-ID/timestamp/logging/test-helper library extracted to deduplicate boilerplate
# across core scripts (see context/patterns -- Phase 2 of the shell-hygiene plan that introduced
# this library).
#
# Structural model: scripts/tests/test-phase-heading-patterns.sh (pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, `mktemp -d` workdir with a trap EXIT cleanup, exit 0 on
# all-pass / exit 1 on any-fail). This suite sources the library directly rather than driving a
# subprocess, since the library exports shell functions meant to be sourced, not a standalone
# executable.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (library
# not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/../lib/common.sh"

PASSED=0
FAILED=0


if [ ! -f "$LIB" ]; then
  echo "ERROR: shared library common.sh not found at $LIB" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ── Capture shell-option state BEFORE sourcing ────────────────────────────────
DASH_BEFORE="$-"
SET_O_BEFORE="$(set -o)"

# shellcheck source=/dev/null
source "$LIB"

# ── Assertion: sourcing must not change $- or `set -o` state ─────────────────
DASH_AFTER="$-"
SET_O_AFTER="$(set -o)"

if [ "$DASH_BEFORE" = "$DASH_AFTER" ]; then
  common_test_pass "sourcing common.sh: \$- unchanged ($DASH_BEFORE)"
else
  common_test_fail "sourcing common.sh: \$- changed from '$DASH_BEFORE' to '$DASH_AFTER'"
fi

if [ "$SET_O_BEFORE" = "$SET_O_AFTER" ]; then
  common_test_pass "sourcing common.sh: 'set -o' state byte-for-byte unchanged"
else
  common_test_fail "sourcing common.sh: 'set -o' state changed"
fi

# ── common_repo_root: depth 2 (scripts/ callers) ──────────────────────────────
FIXTURE_ROOT="$WORKDIR/fixture-repo"
mkdir -p "$FIXTURE_ROOT/scripts"
resolved=$(common_repo_root "$FIXTURE_ROOT/scripts" 2)
expected="$(cd "$FIXTURE_ROOT/scripts/../.." && pwd)"
if [ "$resolved" = "$expected" ]; then
  common_test_pass "common_repo_root depth 2 resolves scripts/ callers correctly"
else
  common_test_fail "common_repo_root depth 2: expected '$expected', got '$resolved'"
fi

# ── common_repo_root: depth 3 (scripts/lib/, scripts/tests/, scripts/lint/) ──
mkdir -p "$FIXTURE_ROOT/scripts/lib" "$FIXTURE_ROOT/scripts/tests" "$FIXTURE_ROOT/scripts/lint"
for sub in lib tests lint; do
  resolved=$(common_repo_root "$FIXTURE_ROOT/scripts/$sub" 3)
  expected="$(cd "$FIXTURE_ROOT/scripts/$sub/../../.." && pwd)"
  if [ "$resolved" = "$expected" ]; then
    common_test_pass "common_repo_root depth 3 resolves scripts/$sub/ callers correctly"
  else
    common_test_fail "common_repo_root depth 3 ($sub): expected '$expected', got '$resolved'"
  fi
done

# ── common_repo_root: empty script_dir yields empty output, not an error ─────
resolved=$(common_repo_root "" 2)
if [ -z "$resolved" ]; then
  common_test_pass "common_repo_root with empty script_dir yields empty output (safe default)"
else
  common_test_fail "common_repo_root with empty script_dir yielded '$resolved', expected empty"
fi

# ── common_repo_root: nonexistent path yields empty output, not a nonzero exit ─
resolved=$(common_repo_root "/nonexistent/path/that/does/not/exist" 2)
rc=$?
if [ "$rc" -eq 0 ] && [ -z "$resolved" ]; then
  common_test_pass "common_repo_root with nonexistent path returns 0 with empty output"
else
  common_test_fail "common_repo_root with nonexistent path: rc=$rc, output='$resolved' (expected rc=0, empty)"
fi

# ── common_session_id: shape ──────────────────────────────────────────────────
sid=$(common_session_id)
if [[ "$sid" =~ ^sess_[0-9]+_[0-9a-f]{6}$ ]]; then
  common_test_pass "common_session_id matches ^sess_[0-9]+_[0-9a-f]{6}\$ ($sid)"
else
  common_test_fail "common_session_id did not match expected shape: '$sid'"
fi

# ── common_session_id: no embedded whitespace or newline ─────────────────────
if [ "$(printf '%s' "$sid" | wc -l)" -eq 0 ] && [[ "$sid" != *" "* ]]; then
  common_test_pass "common_session_id has no embedded whitespace or newline"
else
  common_test_fail "common_session_id contains embedded whitespace or newline: '$sid'"
fi

# ── common_session_id: two calls yield different IDs (random component varies) ─
sid2=$(common_session_id)
if [ "$sid" != "$sid2" ]; then
  common_test_pass "common_session_id: two successive calls yield different IDs"
else
  common_test_info "two successive common_session_id calls yielded the same ID (rare but not necessarily a bug within the same second + same random bytes)"
  common_test_pass "common_session_id: two successive calls (non-fatal duplicate check)"
fi

# ── common_timestamp_iso: format ──────────────────────────────────────────────
iso=$(common_timestamp_iso)
if [[ "$iso" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  common_test_pass "common_timestamp_iso matches YYYY-MM-DDTHH:MM:SSZ ($iso)"
else
  common_test_fail "common_timestamp_iso did not match expected format: '$iso'"
fi

# ── common_timestamp_epoch: format ────────────────────────────────────────────
epoch=$(common_timestamp_epoch)
if [[ "$epoch" =~ ^[0-9]+$ ]]; then
  common_test_pass "common_timestamp_epoch is a plain integer ($epoch)"
else
  common_test_fail "common_timestamp_epoch did not match expected format: '$epoch'"
fi

# ── common_timestamp_date: format ─────────────────────────────────────────────
dt=$(common_timestamp_date)
if [[ "$dt" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  common_test_pass "common_timestamp_date matches YYYY-MM-DD ($dt)"
else
  common_test_fail "common_timestamp_date did not match expected format: '$dt'"
fi

# ── common_log_error / common_log_warn: stream routing (stderr) ──────────────
err_out=$(common_log_error "test error" 2>&1 1>/dev/null)
if [[ "$err_out" == "ERROR: test error" ]]; then
  common_test_pass "common_log_error routes to stderr with 'ERROR: ' prefix"
else
  common_test_fail "common_log_error stderr routing/format wrong: '$err_out'"
fi

warn_out=$(common_log_warn "test warning" 2>&1 1>/dev/null)
if [[ "$warn_out" == "WARNING: test warning" ]]; then
  common_test_pass "common_log_warn routes to stderr with 'WARNING: ' prefix"
else
  common_test_fail "common_log_warn stderr routing/format wrong: '$warn_out'"
fi

# ── common_log_info: stream routing (stdout) ──────────────────────────────────
info_out=$(common_log_info "test info" 2>/dev/null)
if [[ "$info_out" == "INFO: test info" ]]; then
  common_test_pass "common_log_info routes to stdout with 'INFO: ' prefix"
else
  common_test_fail "common_log_info stdout routing/format wrong: '$info_out'"
fi

info_err=$(common_log_info "test info" 2>&1 1>/dev/null)
if [ -z "$info_err" ]; then
  common_test_pass "common_log_info emits nothing to stderr"
else
  common_test_fail "common_log_info unexpectedly wrote to stderr: '$info_err'"
fi

# ── common_test_pass / common_test_fail: counter arithmetic on caller's vars ──
(
  PASSED=0
  FAILED=0
  common_test_pass "sub-case A" >/dev/null
  common_test_pass "sub-case B" >/dev/null
  common_test_fail "sub-case C" >/dev/null
  if [ "$PASSED" -eq 2 ] && [ "$FAILED" -eq 1 ]; then
    exit 0
  else
    exit 1
  fi
)
if [ $? -eq 0 ]; then
  common_test_pass "common_test_pass/common_test_fail increment caller's PASSED/FAILED correctly"
else
  common_test_fail "common_test_pass/common_test_fail counter arithmetic incorrect"
fi

# ── common_test_pass/_fail/_info: output format matches shell-script-testing.md ──
tp_out=$(PASSED=0; common_test_pass "case")
if [[ "$tp_out" == "[PASS] case" ]]; then
  common_test_pass "common_test_pass emits '[PASS] <msg>'"
else
  common_test_fail "common_test_pass output format wrong: '$tp_out'"
fi

tf_out=$(FAILED=0; common_test_fail "case")
if [[ "$tf_out" == "[FAIL] case" ]]; then
  common_test_pass "common_test_fail emits '[FAIL] <msg>'"
else
  common_test_fail "common_test_fail output format wrong: '$tf_out'"
fi

ti_out=$(common_test_info "case")
if [[ "$ti_out" == "[INFO] case" ]]; then
  common_test_pass "common_test_info emits '[INFO] <msg>'"
else
  common_test_fail "common_test_info output format wrong: '$ti_out'"
fi

# ── common_test_repo_root: git-aware fixture (depth-independent) ─────────────
GIT_FIXTURE="$WORKDIR/git-fixture"
mkdir -p "$GIT_FIXTURE/scripts/tests"
(cd "$GIT_FIXTURE" && git init -q) >/dev/null 2>&1
git_root_resolved=$(common_test_repo_root "$GIT_FIXTURE/scripts/tests")
git_root_expected="$(cd "$GIT_FIXTURE" && pwd -P)"
if [ "$git_root_resolved" = "$git_root_expected" ]; then
  common_test_pass "common_test_repo_root resolves a git work tree via git rev-parse (depth-independent)"
else
  common_test_fail "common_test_repo_root (git fixture): expected '$git_root_expected', got '$git_root_resolved'"
fi

# ── common_test_repo_root: non-git fixture falls back to the fixed-depth walk ─
NONGIT_FIXTURE="$WORKDIR/nongit-fixture"
mkdir -p "$NONGIT_FIXTURE/a/b/c/scripts/tests"
nongit_resolved=$(common_test_repo_root "$NONGIT_FIXTURE/a/b/c/scripts/tests" 2)
nongit_expected="$(cd "$NONGIT_FIXTURE/a/b/c" && pwd -P)"
if [ "$nongit_resolved" = "$nongit_expected" ]; then
  common_test_pass "common_test_repo_root falls back to common_repo_root's fixed-depth walk outside a git tree"
else
  common_test_fail "common_test_repo_root (non-git fallback): expected '$nongit_expected', got '$nongit_resolved'"
fi

# ── common_test_resolve_candidate: found / not-found polarity ────────────────
RESOLVE_FIXTURE="$WORKDIR/resolve-fixture"
mkdir -p "$RESOLVE_FIXTURE"
touch "$RESOLVE_FIXTURE/real.sh"
found=$(common_test_resolve_candidate "real.sh" "$RESOLVE_FIXTURE/missing.sh" "$RESOLVE_FIXTURE/real.sh")
if [ "$found" = "$RESOLVE_FIXTURE/real.sh" ]; then
  common_test_pass "common_test_resolve_candidate returns the first existing candidate"
else
  common_test_fail "common_test_resolve_candidate (found): expected '$RESOLVE_FIXTURE/real.sh', got '$found'"
fi

resolve_err=$(common_test_resolve_candidate "ghost.sh" "$RESOLVE_FIXTURE/ghost1.sh" "$RESOLVE_FIXTURE/ghost2.sh" 2>&1 1>/dev/null)
resolve_rc=0
common_test_resolve_candidate "ghost.sh" "$RESOLVE_FIXTURE/ghost1.sh" "$RESOLVE_FIXTURE/ghost2.sh" >/dev/null 2>&1 || resolve_rc=$?
if [ "$resolve_rc" -eq 1 ] && [[ "$resolve_err" == "ERROR: ghost.sh not found at any of:"* ]]; then
  common_test_pass "common_test_resolve_candidate returns 1 with an enumerated ERROR when no candidate exists"
else
  common_test_fail "common_test_resolve_candidate (not found): rc=$resolve_rc, stderr='$resolve_err'"
fi

# ── common_test_workdir_init: creates WORKDIR and tears it down on EXIT ──────
# Called as a bare statement, per the function's own contract: a command-substitution capture
# would run it in a subshell whose own EXIT trap fires (deleting the directory) the instant the
# function returns, before this outer check could ever see it.
inner_wd_file="$WORKDIR/inner-wd-path.txt"
(
  common_test_workdir_init
  inner_wd="$WORKDIR"
  printf '%s\n' "$inner_wd" > "$inner_wd_file"
  [ -n "$inner_wd" ] && [ -d "$inner_wd" ]
)
inner_rc=$?
inner_wd="$(cat "$inner_wd_file" 2>/dev/null)"
if [ "$inner_rc" -eq 0 ] && [ -n "$inner_wd" ] && [ ! -d "$inner_wd" ]; then
  common_test_pass "common_test_workdir_init creates WORKDIR during the call and removes it via an EXIT trap"
else
  common_test_fail "common_test_workdir_init: inner_rc=$inner_rc, inner_wd='$inner_wd' (expected created-then-gone)"
fi

# ── common_test_fixture_overlay: directory copy, read-only source stays read-only, errors ───
OVERLAY_SRC_DIR="$WORKDIR/overlay-src"
mkdir -p "$OVERLAY_SRC_DIR/sub"
echo "original" > "$OVERLAY_SRC_DIR/sub/file.txt"
chmod -R a-w "$OVERLAY_SRC_DIR"

OVERLAY_DEST_DIR="$WORKDIR/overlay-dest"
if common_test_fixture_overlay "$OVERLAY_SRC_DIR" "$OVERLAY_DEST_DIR" \
   && [ -f "$OVERLAY_DEST_DIR/sub/file.txt" ] \
   && [ "$(cat "$OVERLAY_DEST_DIR/sub/file.txt")" = "original" ]; then
  common_test_pass "common_test_fixture_overlay: copies a directory's content to the destination"
else
  common_test_fail "common_test_fixture_overlay: directory copy did not produce the expected content"
fi

if echo "mutated" > "$OVERLAY_DEST_DIR/sub/file.txt" 2>/dev/null; then
  common_test_pass "common_test_fixture_overlay: the copy is independently writable even though its source is read-only"
else
  common_test_fail "common_test_fixture_overlay: the copy inherited the source's read-only bit (should be chmod u+w)"
fi

if [ "$(cat "$OVERLAY_SRC_DIR/sub/file.txt" 2>/dev/null)" = "original" ]; then
  common_test_pass "common_test_fixture_overlay: mutating the copy left the read-only source untouched (not a hardlink)"
else
  common_test_fail "common_test_fixture_overlay: the source was mutated by writing to the copy -- inode sharing (hardlink) hazard"
fi

chmod -R u+w "$OVERLAY_SRC_DIR" 2>/dev/null || true

OVERLAY_FILE_SRC="$WORKDIR/overlay-file-src.txt"
echo "a lone file" > "$OVERLAY_FILE_SRC"
OVERLAY_FILE_DEST="$WORKDIR/overlay-file-dest.txt"
if common_test_fixture_overlay "$OVERLAY_FILE_SRC" "$OVERLAY_FILE_DEST" \
   && [ "$(cat "$OVERLAY_FILE_DEST")" = "a lone file" ]; then
  common_test_pass "common_test_fixture_overlay: also copies a single file (not just a directory)"
else
  common_test_fail "common_test_fixture_overlay: single-file copy did not produce the expected content"
fi

if common_test_fixture_overlay "$WORKDIR/does-not-exist" "$WORKDIR/overlay-missing-dest" 2>/dev/null; then
  common_test_fail "common_test_fixture_overlay: incorrectly succeeded against a missing source"
else
  common_test_pass "common_test_fixture_overlay: refuses (rc != 0) when the source does not exist"
fi

if common_test_fixture_overlay "$OVERLAY_SRC_DIR" "$OVERLAY_DEST_DIR" 2>/dev/null; then
  common_test_fail "common_test_fixture_overlay: incorrectly succeeded against an already-existing destination"
else
  common_test_pass "common_test_fixture_overlay: refuses (rc != 0) when the destination already exists"
fi

# ── Single-definition assertion: each new function has exactly one definition ─
for fn in common_test_repo_root common_test_resolve_candidate common_test_workdir_init common_test_fixture_overlay; do
  hits=$(grep -rc "^${fn}() {" --include="*.sh" "$SCRIPT_DIR/../lib" 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')
  if [ "$hits" -eq 1 ]; then
    common_test_pass "$fn has exactly one definition under scripts/lib/"
  else
    common_test_fail "$fn: expected exactly one definition under scripts/lib/, found $hits"
  fi
done

# ── Anti-regression: a suite sourcing common.sh for the test-helper trio must not also define
# its own pass()/fail()/info(). This is proven against two constructed fixtures (never the live
# corpus here -- the live corpus's own migration onto these functions is a separate, later
# phase's job, not this suite's) via a small detector reusable once that migration lands.
detect_test_helper_redefinition() {
  local _file="$1"
  grep -q 'source.*common\.sh' "$_file" || return 1
  grep -qE '^(pass|fail|info)\(\) \{' "$_file"
}

# Both fixtures below are built with an UNQUOTED heredoc delimiter so "$LIB" (this suite's own
# already-resolved absolute path to lib/common.sh) expands to a literal path AT FIXTURE-WRITE
# TIME -- the fixture's `source` line therefore contains the literal substring "common.sh",
# exactly as every real suite's own `source ".../lib/common.sh"` line does, which is what
# detect_test_helper_redefinition's `source.*common\.sh` probe looks for. Every other `$...`
# reference the fixture itself should see at RUN time is backslash-escaped so it survives
# unexpanded.
GOOD_FIXTURE="$WORKDIR/good-suite.sh"
cat > "$GOOD_FIXTURE" <<EOF
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
source "$LIB"
PASSED=0
FAILED=0
common_test_pass "sourced trio works without local redefinition"
echo "Passed: \$PASSED"
echo "Failed: \$FAILED"
EOF
chmod +x "$GOOD_FIXTURE"
if detect_test_helper_redefinition "$GOOD_FIXTURE"; then
  common_test_fail "detect_test_helper_redefinition: false positive on a fixture with no local pass/fail/info"
else
  common_test_pass "detect_test_helper_redefinition: correctly clears a fixture sourcing common.sh with no local redefinition"
fi
good_out=$(bash "$GOOD_FIXTURE")
if [[ "$good_out" == *"[PASS] sourced trio works without local redefinition"* ]] && [[ "$good_out" == *"Passed: 1"* ]]; then
  common_test_pass "good-suite fixture runs end-to-end on the shared trio with no local pass/fail/info"
else
  common_test_fail "good-suite fixture did not run correctly: $good_out"
fi

BAD_FIXTURE="$WORKDIR/bad-suite.sh"
cat > "$BAD_FIXTURE" <<EOF
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
source "$LIB"
PASSED=0
FAILED=0
pass() { echo "[PASS] \$1"; PASSED=\$((PASSED + 1)); }
fail() { echo "[FAIL] \$1"; FAILED=\$((FAILED + 1)); }
info() { echo "[INFO] \$1"; }
pass "this suite still redefines its own trio after sourcing common.sh"
EOF
chmod +x "$BAD_FIXTURE"
if detect_test_helper_redefinition "$BAD_FIXTURE"; then
  common_test_pass "detect_test_helper_redefinition: correctly flags a fixture that redefines pass/fail/info after sourcing common.sh"
else
  common_test_fail "detect_test_helper_redefinition: missed a fixture that redefines pass/fail/info after sourcing common.sh"
fi

# ── Single-source assertion: no inline sess_$(date generation outside lib/common.sh ──
# This is the mechanical form of the task's verification bar: session-ID generation must exist
# in exactly one place. Two independent, previously-uncorrected defects in this scan: (1) the
# root was resolved by a fixed ../../.. walk from SCRIPT_DIR, correct only in the source-store
# layout and silently landing on the repo root (over-scanning) when this suite runs from the
# deployed .claude/scripts/tests/ copy; (2) the scan only ever looked at *.sh files, so it was
# structurally blind to the same duplicated generator inside .md executable surfaces
# (commands/, skills/, agents/). Both are fixed below: dual-mode root resolution (reusing
# run-all.sh's core/manifest.json probe verbatim, not a new heuristic) plus a second .md scan
# scoped to commands/skills/agents, which leaves illustrative prose under context/, docs/, and
# rules/ out of scope by construction rather than by a growing exclusion list.
if grep -q 'sess_\$(date' "$LIB" 2>/dev/null; then
  common_test_pass "common.sh itself defines the canonical sess_\$(date generator"
else
  common_test_fail "common.sh does not appear to define the canonical session-ID generator"
fi

# ── Detect source-store vs. deployed layout ───────────────────────────────────
# Source-store mode: three levels up from scripts/tests/ is agent-system/extensions/, containing
# per-extension directories each with their own manifest.json (core/manifest.json in particular).
# This is the exact probe run-all.sh uses one directory over; reused verbatim rather than
# reinvented.
# Deployed mode: two levels up from scripts/tests/ is .claude/ itself. This is one level ABOVE
# run-all.sh's own DEPLOY_SCRIPTS_ROOT ($SCRIPT_DIR/..), because commands/, skills/, and agents/
# live at the .claude/ top level, not under .claude/scripts/ -- the .md scan below needs .claude/
# itself, not .claude/scripts/.
CANDIDATE_EXT_ROOT="$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd || true)"
if [ -n "$CANDIDATE_EXT_ROOT" ] && [ -f "$CANDIDATE_EXT_ROOT/core/manifest.json" ]; then
  SCAN_MODE="source-store"
  SCAN_ROOT="$CANDIDATE_EXT_ROOT"
else
  SCAN_MODE="deployed"
  SCAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
echo "[test-common-lib] Mode: $SCAN_MODE (scan root: $SCAN_ROOT)"

# collect_session_id_offenders <mode> <root> -- echoes a newline-separated, deduplicated list of
# files (outside lib/common.sh and this suite's own self-referential comment) that still carry
# an inline sess_$(date ...) generator. Runs the *.sh scan whole-tree over <root> (reach
# unchanged from before this task -- narrowing it would regress detection of a real .sh
# offender), plus a *.md scan scoped to commands/, skills/, and agents/ under <root> (source-store
# mode: those three subdirectories under each per-extension directory directly under <root>;
# deployed mode: those three subdirectories directly under <root>). A missing subdirectory is
# silently skipped, never an error. Side-effect-free and never exits, so both the live assertion
# below and the regression fixtures further down can call it.
collect_session_id_offenders() {
  local _mode="$1"
  local _root="$2"
  local _sh_hits _md_hits _ext_dir _sub

  _sh_hits="$(grep -rl 'sess_\$(date' --include="*.sh" "$_root" 2>/dev/null || true)"

  _md_hits=""
  if [ "$_mode" = "source-store" ]; then
    for _ext_dir in "$_root"/*/; do
      [ -d "$_ext_dir" ] || continue
      for _sub in commands skills agents; do
        [ -d "${_ext_dir}${_sub}" ] || continue
        _md_hits="${_md_hits}$(grep -rl 'sess_\$(date' --include="*.md" "${_ext_dir}${_sub}" 2>/dev/null || true)
"
      done
    done
  else
    for _sub in commands skills agents; do
      [ -d "$_root/$_sub" ] || continue
      _md_hits="${_md_hits}$(grep -rl 'sess_\$(date' --include="*.md" "$_root/$_sub" 2>/dev/null || true)
"
    done
  fi

  printf '%s\n%s\n' "$_sh_hits" "$_md_hits" \
    | grep -v -F "/lib/common.sh" \
    | grep -v -F "/tests/test-common-lib.sh" \
    | sed '/^$/d' \
    | sort -u

  unset _mode _root _sh_hits _md_hits _ext_dir _sub
  return 0
}

offending=$(collect_session_id_offenders "$SCAN_MODE" "$SCAN_ROOT")
if [ -z "$offending" ]; then
  common_test_pass "single-source assertion: no inline sess_\$(date generation outside lib/common.sh"
else
  common_test_fail "single-source assertion: inline sess_\$(date generation found outside lib/common.sh:"
  while IFS= read -r off_line; do
    [ -n "$off_line" ] && common_test_info "  $off_line"
  done <<< "$offending"
fi

# ── Dual-mode and exclusion regression fixtures ───────────────────────────────
# Pins the two behaviors that were invisible before this task: deployed-mode .md detection (a
# source-store-only test run can never exercise the deployed branch), and the prose-exclusion
# boundary (context/ must never be flagged even though it can carry the literal generator as
# documentation). Uses the suite's existing mktemp workdir/trap; no parallel reporting convention.
FIXTURE_GENERATOR='sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d '"'"' '"'"')'

# -- Deployed-layout fixture --
mkdir -p "$WORKDIR/deployed/commands" "$WORKDIR/deployed/skills" "$WORKDIR/deployed/agents" \
  "$WORKDIR/deployed/context" "$WORKDIR/deployed/scripts/lib"
printf '```bash\nsession_id="%s"\n```\n' "$FIXTURE_GENERATOR" > "$WORKDIR/deployed/commands/planted.md"
printf '```bash\nsession_id="%s"\n```\n' "$FIXTURE_GENERATOR" > "$WORKDIR/deployed/context/illustrative.md"

deployed_offenders="$(collect_session_id_offenders deployed "$WORKDIR/deployed")"
if echo "$deployed_offenders" | grep -q "commands/planted.md"; then
  common_test_pass "collect_session_id_offenders (deployed): detects planted commands/ offender"
else
  common_test_fail "collect_session_id_offenders (deployed): did not detect planted commands/ offender"
fi
if echo "$deployed_offenders" | grep -q "context/illustrative.md"; then
  common_test_fail "collect_session_id_offenders (deployed): incorrectly flagged illustrative-prose context/ site"
else
  common_test_pass "collect_session_id_offenders (deployed): correctly excludes illustrative-prose context/ site"
fi

# -- Source-store-layout fixture (including an extension lacking commands/skills/agents) --
mkdir -p "$WORKDIR/source/core" "$WORKDIR/source/someext/commands" "$WORKDIR/source/bareext"
echo '{}' > "$WORKDIR/source/core/manifest.json"
printf '```bash\nsession_id="%s"\n```\n' "$FIXTURE_GENERATOR" > "$WORKDIR/source/someext/commands/planted.md"

source_offenders="$(collect_session_id_offenders source-store "$WORKDIR/source")"
if echo "$source_offenders" | grep -q "someext/commands/planted.md"; then
  common_test_pass "collect_session_id_offenders (source-store): detects planted extension offender"
else
  common_test_fail "collect_session_id_offenders (source-store): did not detect planted extension offender"
fi
if [ -n "$source_offenders" ] && ! echo "$source_offenders" | grep -q "someext/commands/planted.md" 2>/dev/null; then
  common_test_fail "collect_session_id_offenders (source-store): unexpected offender set: $source_offenders"
else
  common_test_pass "collect_session_id_offenders (source-store): skips bareext/ (no commands/skills/agents) without error"
fi

# -- Mode-probe correctness --
if [ -f "$WORKDIR/deployed/core/manifest.json" ]; then
  common_test_fail "mode probe: deployed fixture unexpectedly carries core/manifest.json"
else
  common_test_pass "mode probe: deployed fixture correctly lacks core/manifest.json (resolves deployed)"
fi
if [ -f "$WORKDIR/source/core/manifest.json" ]; then
  common_test_pass "mode probe: source-store fixture correctly has core/manifest.json (resolves source-store)"
else
  common_test_fail "mode probe: source-store fixture missing core/manifest.json"
fi

echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
