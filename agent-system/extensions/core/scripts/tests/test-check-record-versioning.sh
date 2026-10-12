#!/usr/bin/env bash
# test-check-record-versioning.sh - Fixture-driven regression suite for
# check-record-versioning.sh's repo-appropriate scan roots: a consumer-repo-shaped fixture
# (docs/, README.md, a source dir, .github/, specs/), proving the lint scans what a consumer repo
# actually ships rather than a hard-coded list of this repo's own directories, PLUS the
# BLOCKING/ADVISORY two-tier contract -- the one genuinely new surface versus the sibling
# check-task-references.sh lint.
#
# Structural model: scripts/tests/test-check-task-references.sh (mktemp -d WORKDIR, trap cleanup,
# git init -q throwaway fixture, pass()/fail()/info() + PASSED/FAILED counters, exit
# 0-on-all-pass / exit 1-on-any-fail / exit 2-on-environment-error convention from
# context/standards/shell-script-testing.md). This suite deliberately OMITS that sibling's Case
# 8 (lint/hook scope-agreement): hooks/validate-no-record-versioning.sh does not exist yet and is
# out of scope for this task -- there is no hook to agree with.
#
# The lint script is invoked with REPO_ROOT resolved explicitly -- it does not need to sit under
# a literal .claude/scripts/ or .opencode/scripts/ deploy-root shape, since
# check-record-versioning.sh's `REPO_ROOT=$(pwd)` override bypasses deploy-root-guard.sh
# entirely (the same override the script's own header documents for source-store invocation).
#
# NOTE on this file's own version-ok markers: the fixture blocks below deliberately embed
# literal record-versioning-language strings as TEST DATA written into throwaway fixture files
# under a mktemp WORKDIR (never committed to this repo). Per this repo's own
# rules/no-record-versioning-in-deliverables.md, the *source lines of this test file itself*
# that contain those literal strings must be marked exempt (Exemption Taxonomy category: test
# fixture for the reference-pattern detector itself) or the repo-wide lint and the write-time
# guard hook would both flag this file. Each fixture-content block below is wrapped in a
# self-contained version-ok:begin/end pair (never nested, mirroring this convention's existing
# precedent in scripts/tests/test-record-version-patterns.sh and
# scripts/tests/test-check-task-references.sh's own task-ref-ok markers for the sibling lint).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (check-record-versioning.sh, the shared library, or git not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT_SRC="$SCRIPT_DIR/../check-record-versioning.sh"
LIB_SRC="$SCRIPT_DIR/../lib/record-version-patterns.sh"

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
# shellcheck disable=SC2329
info() { echo "[INFO] $1"; }

if [[ ! -f "$LINT_SRC" ]]; then
  echo "ERROR: expected check-record-versioning.sh at $LINT_SRC" >&2
  exit 2
fi
if [[ ! -f "$LIB_SRC" ]]; then
  echo "ERROR: expected shared library at $LIB_SRC" >&2
  exit 2
fi
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not found on PATH" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# =====================================================================
# Fixture: a consumer-repo-shaped layout. Deliberately NO agent-system/extensions (beyond the
# single lib-mirror shim below), lua, .memory, or .opencode -- the lint must scan a layout that
# looks nothing like this repo's own, by construction (no hard-coded directory list).
# =====================================================================
FIXTURE="$WORKDIR/consumer"
mkdir -p "$FIXTURE/docs" "$FIXTURE/code" "$FIXTURE/.github" \
  "$FIXTURE/specs/007_example_task/reports" \
  "$FIXTURE/agent-system/extensions/core/scripts/lib"
# check-record-versioning.sh's LIB_CANDIDATES resolves the shared library relative to REPO_ROOT
# (.claude/scripts/lib/... first, then agent-system/extensions/core/scripts/lib/... as the
# source-store fallback) -- mirror the source-store layout so REPO_ROOT=$FIXTURE resolves it.
cp "$LIB_SRC" "$FIXTURE/agent-system/extensions/core/scripts/lib/record-version-patterns.sh"
git init -q "$FIXTURE"
git -C "$FIXTURE" config user.email "test@example.com"
git -C "$FIXTURE" config user.name "Test"

# version-ok:begin test fixture for check-record-versioning.sh detection, category: test fixture
# for the reference-pattern detector itself
echo "# Consumer Repo" > "$FIXTURE/README.md"
echo '**Status**: v2, accepted 2026-01-01; supersedes v1' >> "$FIXTURE/README.md"
# version-ok:end

# version-ok:begin test fixture for check-record-versioning.sh detection
cat > "$FIXTURE/docs/notes.md" << 'EOF'
# Notes

## The widget convention (v2)

Describes the widget.
EOF
# version-ok:end

# version-ok:begin test fixture for check-record-versioning.sh detection
cat > "$FIXTURE/code/operators.py" << 'EOF'
# This record supersedes v1 of the convention entirely.
def foo():
    return 1
EOF
# version-ok:end

# ADVISORY-only fixture: bare past-tense vocabulary with NO adjacent version token, so it must
# be reported (nonzero ADVISORY count) WITHOUT changing the exit code. The single most important
# fixture in this file -- it is the one that proves the tier split.
# version-ok:begin test fixture for check-record-versioning.sh detection
cat > "$FIXTURE/.github/workflow.yml" << 'EOF'
# This workflow is no longer manually triggered.
name: ci
EOF
# version-ok:end

# version-ok:begin test fixture for check-record-versioning.sh detection
cat > "$FIXTURE/specs/007_example_task/reports/01_report.md" << 'EOF'
# Report

## The widget convention (v2)

Discusses findings. specs/** is exempt regardless of content.
EOF
# version-ok:end

# version-ok:begin test fixture for check-record-versioning.sh detection
cat > "$FIXTURE/docs/marked.md" << 'EOF'
<!-- version-ok:begin quoted historical anti-pattern -->
## The widget convention (v2)
<!-- version-ok:end -->
EOF
# version-ok:end

# Durable-axis fixture: a dotted-semver toolchain pin, an @vN action pin, and a CI cache-key
# epoch segment -- none of this is record-versioning language, so it must produce no finding at
# all (not even ADVISORY).
cat > "$FIXTURE/docs/durable-axis.md" << 'EOF'
# Toolchain Notes

Stay on v4.31.0 for now. Uses actions/checkout@v4. Cache key: elan-v2-linux.
EOF

# Gitignored file carrying a BLOCKING finding -- must never be scanned (git ls-files excludes it).
echo "ignored/" > "$FIXTURE/.gitignore"
mkdir -p "$FIXTURE/ignored"
# version-ok:begin test fixture for check-record-versioning.sh detection
echo "## The widget convention (v2)" > "$FIXTURE/ignored/scratch.md"
# version-ok:end

git -C "$FIXTURE" add -A
git -C "$FIXTURE" commit -q -m "fixture: consumer repo layout"

run_lint() {
  # $1 = extra args (--quiet, PATH_SCOPE, etc, may be empty); output+exit captured via a temp
  # file so both stdout and $? are available to the caller.
  local extra="$1" out_file="$2"
  ( cd "$FIXTURE" && REPO_ROOT="$FIXTURE" bash "$LINT_SRC" $extra ) > "$out_file" 2>&1
  echo $?
}

# =====================================================================
# Case 1: clean tree -- a fixture subtree with no version language: exit 0, both counters 0.
# =====================================================================
echo "# Nothing version-related here." > "$FIXTURE/docs/clean.md"
git -C "$FIXTURE" add -A
git -C "$FIXTURE" commit -q -m "fixture: add clean file"
out1="$WORKDIR/case1.txt"
code1="$(run_lint "docs/clean.md" "$out1")"
if [[ "$code1" -eq 0 ]] && grep -qE '0 BLOCKING, 0 ADVISORY' "$out1"; then
  pass "clean tree: exit 0, both counters 0"
else
  fail "clean tree: expected exit 0 with 0 BLOCKING, 0 ADVISORY, got exit=$code1; output:
$(cat "$out1")"
fi

# =====================================================================
# Case 2: blocking finding -- exit 1, the finding line names the path and is labeled BLOCKING.
# =====================================================================
out="$WORKDIR/case_full.txt"
code="$(run_lint "" "$out")"
if [[ "$code" -eq 1 ]] && grep -qE '^  docs/notes\.md:[0-9]+: BLOCKING:' "$out"; then
  pass "blocking finding: exit 1, finding line names docs/notes.md and is labeled BLOCKING"
else
  fail "blocking finding not found as expected (exit=$code); output:
$(cat "$out")"
fi
if grep -qE '^  code/operators\.py:[0-9]+: BLOCKING:' "$out"; then
  pass "blocking finding in a source file (code/operators.py) is also labeled BLOCKING"
else
  fail "source-dir BLOCKING finding not found; output:
$(cat "$out")"
fi
if grep -qE '^  README\.md:[0-9]+: BLOCKING:' "$out"; then
  pass "Status-line BLOCKING finding in README.md found (path-class-agnostic branch)"
else
  fail "README.md BLOCKING finding not found; output:
$(cat "$out")"
fi

# =====================================================================
# Case 3: advisory finding that does NOT change the exit code -- the single most important
# assertion in this file: it is the one that proves the tier split.
# =====================================================================
if grep -qE '^  \.github/workflow\.yml:[0-9]+: ADVISORY:' "$out"; then
  pass "advisory finding in .github/workflow.yml is labeled ADVISORY (not BLOCKING)"
else
  fail "expected ADVISORY finding for .github/workflow.yml; output:
$(cat "$out")"
fi
out_adv="$WORKDIR/case_advisory_only.txt"
code_adv="$(run_lint ".github/workflow.yml" "$out_adv")"
if [[ "$code_adv" -eq 0 ]] && grep -qE '0 BLOCKING, [1-9][0-9]* ADVISORY' "$out_adv"; then
  pass "advisory-only scope exits 0 with a nonzero ADVISORY count (tier split proven)"
else
  fail "advisory-only scope expected exit 0 with nonzero ADVISORY count, got exit=$code_adv; output:
$(cat "$out_adv")"
fi

# =====================================================================
# Case 4: marker-exempted content (version-ok:begin/end) is NOT found.
# =====================================================================
if grep -q 'docs/marked.md' "$out"; then
  fail "version-ok-marked finding was scanned (should be stripped)"
else
  pass "version-ok-marked content correctly stripped"
fi

# =====================================================================
# Case 5: specs/** path exemption holds regardless of content.
# =====================================================================
if grep -q 'specs/007_example_task' "$out"; then
  fail "specs/** content was scanned (should be exempt)"
else
  pass "specs/** content correctly exempt"
fi

# =====================================================================
# Case 6: durable-axis content produces no finding at all (not even ADVISORY).
# =====================================================================
if grep -q 'docs/durable-axis.md' "$out"; then
  fail "durable-axis content was scanned as a finding (should be stripped before matching)"
else
  pass "durable-axis content (semver pin, @vN pin, CI cache-key segment) correctly stripped"
fi

# =====================================================================
# Case 7: gitignored file carrying a finding is NOT found (git ls-files exclusion).
# =====================================================================
if grep -q 'ignored/scratch.md' "$out"; then
  fail "gitignored finding was scanned (git ls-files should exclude it)"
else
  pass "gitignored finding correctly excluded"
fi

# =====================================================================
# Case 8: PATH_SCOPE=docs exits 1 with the docs/ finding, never 2.
# =====================================================================
out8="$WORKDIR/case8.txt"
code8="$(run_lint "docs" "$out8")"
if [[ "$code8" -eq 1 ]] && grep -qE '^  docs/notes\.md:[0-9]+: BLOCKING:' "$out8"; then
  pass "PATH_SCOPE=docs finds the docs/ BLOCKING finding, exit 1 (never 2)"
else
  fail "PATH_SCOPE=docs expected exit 1 with docs/notes.md finding, got exit=$code8; output:
$(cat "$out8")"
fi

# =====================================================================
# Case 9: PATH_SCOPE naming a non-existent path prints [SKIP] and exits 0.
# =====================================================================
out9="$WORKDIR/case9.txt"
code9="$(run_lint "nonexistent-scope-xyz" "$out9")"
if [[ "$code9" -eq 0 ]] && grep -q '\[SKIP\]' "$out9"; then
  pass "PATH_SCOPE naming a non-existent path prints [SKIP] and exits 0"
else
  fail "PATH_SCOPE nonexistent-scope-xyz expected exit 0 + [SKIP], got exit=$code9; output:
$(cat "$out9")"
fi

# =====================================================================
# Case 10: PATH_SCOPE naming a single file (not a directory) is scanned, not skipped.
# =====================================================================
out10="$WORKDIR/case10.txt"
code10="$(run_lint "README.md" "$out10")"
if [[ "$code10" -eq 1 ]] && grep -qE '^  README\.md:[0-9]+: BLOCKING:' "$out10" && ! grep -q '\[SKIP\]' "$out10"; then
  pass "PATH_SCOPE naming a single file is scanned (not skipped)"
else
  fail "PATH_SCOPE=README.md expected exit 1, finding, no [SKIP], got exit=$code10; output:
$(cat "$out10")"
fi

# =====================================================================
# Case 11: unknown flag exits 2.
# =====================================================================
out11="$WORKDIR/case11.txt"
code11="$(run_lint "--bogus-flag" "$out11")"
if [[ "$code11" -eq 2 ]]; then
  pass "unknown flag exits 2"
else
  fail "unknown flag expected exit 2, got exit=$code11; output:
$(cat "$out11")"
fi

# =====================================================================
# Case 12: per-finding line matches ^  [^:]+:[0-9]+: (the sibling's gate-4-style contract),
# regardless of tier label.
# =====================================================================
if grep -E '^  [^:]+:[0-9]+: (BLOCKING|ADVISORY):' "$out" >/dev/null; then
  pass "per-finding lines match ^  [^:]+:[0-9]+: (BLOCKING|ADVISORY): "
else
  fail "no line in default-scan output matched the tier-labeled finding regex"
fi

# =====================================================================
# Case 13: --quiet suppresses per-finding lines but still reports the Summary/FAIL line.
# =====================================================================
out13="$WORKDIR/case13.txt"
code13="$(run_lint "--quiet" "$out13")"
if [[ "$code13" -eq 1 ]] && ! grep -q '^  docs/notes.md' "$out13" && grep -q '^FAIL:' "$out13"; then
  pass "--quiet suppresses per-finding lines but still prints the FAIL summary line"
else
  fail "--quiet expected exit 1, no per-finding lines, a FAIL summary line; got exit=$code13; output:
$(cat "$out13")"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
