#!/usr/bin/env bash
# test-check-task-references.sh - Fixture-driven regression suite for check-task-references.sh's
# repo-appropriate scan roots: a consumer-repo-shaped fixture (docs/, README.md, a source dir,
# .github/, specs/), proving the lint scans what a consumer repo actually ships rather than a
# hard-coded list of this repo's own directories, PLUS a lint/hook scope-agreement assertion
# proving check-task-references.sh (batch lint) and validate-no-task-references.sh (write-time
# gate) never diverge on which files are in scope.
#
# Structural model: test-deploy-verify-wiring.sh (mktemp -d WORKDIR, trap cleanup, git init -q
# throwaway fixture) crossed with test-validate-no-task-references.sh (jq-built synthetic
# PreToolUse payload piped to the hook, asserting on exit code). Follows
# context/standards/shell-script-testing.md's pass()/fail()/info() + PASSED/FAILED counters +
# exit 0-on-all-pass / exit 1-on-any-fail convention.
#
# Both the lint script and the hook are invoked with REPO_ROOT / their own sourcing resolved
# explicitly -- neither needs to sit under a literal .claude/scripts/ or .opencode/scripts/
# deploy-root shape, since check-task-references.sh's `REPO_ROOT=$(pwd)` override bypasses
# deploy-root-guard.sh entirely (the same override the script's own header documents for
# source-store invocation), and the hook resolves its shared library relative to its own
# directory regardless of where that directory sits.
#
# NOTE on this file's own task-ref-ok markers: the fixture blocks below deliberately embed
# literal task-number citations as TEST DATA written into throwaway fixture files under a
# mktemp WORKDIR (never committed to this repo). Per this repo's own
# rules/no-task-references-in-deliverables.md, the *source lines of this test file itself* that
# contain those literal citations must be marked exempt (Exemption Taxonomy category 6: test
# fixture for the reference-pattern detector itself) or the write-time hook blocks authoring this
# file. Each fixture-content block below is wrapped in a self-contained marker-pair exemption
# region (never nested, matching this convention's existing precedent in
# test-validate-no-task-references.sh).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (check-task-references.sh, the shared library, the hook, jq, or git not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
LINT_SRC="$SCRIPT_DIR/../check-task-references.sh"
LIB_SRC="$SCRIPT_DIR/../lib/task-reference-patterns.sh"
CORPUS_LIB_SRC="$SCRIPT_DIR/../lib/git-corpus-enum-lib.sh"
HOOK_SRC="$SCRIPT_DIR/../../hooks/validate-no-task-references.sh"

PASSED=0
FAILED=0

if [[ ! -f "$LINT_SRC" ]]; then
  echo "ERROR: expected check-task-references.sh at $LINT_SRC" >&2
  exit 2
fi
if [[ ! -f "$LIB_SRC" ]]; then
  echo "ERROR: expected shared library at $LIB_SRC" >&2
  exit 2
fi
if [[ ! -f "$CORPUS_LIB_SRC" ]]; then
  echo "ERROR: expected shared library git-corpus-enum-lib.sh at $CORPUS_LIB_SRC" >&2
  exit 2
fi
if [[ ! -f "$HOOK_SRC" ]]; then
  echo "ERROR: expected validate-no-task-references.sh at $HOOK_SRC" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build synthetic PreToolUse payloads and is not on PATH" >&2
  exit 2
fi
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not found on PATH" >&2
  exit 2
fi

common_test_workdir_init

# =====================================================================
# Fixture: a consumer-repo-shaped layout. Deliberately NO agent-system/extensions, lua,
# .memory, or .opencode -- the four directories the old hard-coded TREE_ROOTS scanned. This is
# the shape that was invisible to the lint before this task's fix (Verification's docs/,
# ModelChecker's code/).
# =====================================================================
FIXTURE="$WORKDIR/consumer"
mkdir -p "$FIXTURE/docs" "$FIXTURE/code" "$FIXTURE/.github" \
  "$FIXTURE/specs/007_example_task/reports" \
  "$FIXTURE/.memory/10-Memories" \
  "$FIXTURE/agent-system/extensions/core/scripts/lib"
# check-task-references.sh's LIB_CANDIDATES resolves the shared library relative to REPO_ROOT
# (.claude/scripts/lib/... first, then agent-system/extensions/core/scripts/lib/... as the
# source-store fallback) -- mirror the source-store layout so REPO_ROOT=$FIXTURE resolves it.
cp "$LIB_SRC" "$FIXTURE/agent-system/extensions/core/scripts/lib/task-reference-patterns.sh"
cp "$CORPUS_LIB_SRC" "$FIXTURE/agent-system/extensions/core/scripts/lib/git-corpus-enum-lib.sh"
git init -q "$FIXTURE"
git -C "$FIXTURE" config user.email "test@example.com"
git -C "$FIXTURE" config user.name "Test"

# task-ref-ok:begin test fixture for check-task-references.sh detection, category 6
echo "# Consumer Repo" > "$FIXTURE/README.md"
echo "See task 42 for the original discussion." >> "$FIXTURE/README.md"
# task-ref-ok:end

# task-ref-ok:begin test fixture for check-task-references.sh detection, category 6
cat > "$FIXTURE/docs/notes.md" << 'EOF'
# Notes

Fixed in task 99 after investigation.
EOF
# task-ref-ok:end

# task-ref-ok:begin test fixture for check-task-references.sh detection, category 6
cat > "$FIXTURE/code/operators.py" << 'EOF'
# implements the operator from task 17
def foo():
    return 1
EOF
# task-ref-ok:end

# task-ref-ok:begin test fixture for check-task-references.sh detection, category 6
cat > "$FIXTURE/.github/workflow.yml" << 'EOF'
# CI config, unrelated to task 55
name: ci
EOF
# task-ref-ok:end

# task-ref-ok:begin test fixture for check-task-references.sh detection, category 6
# Memory-vault fixtures (taxonomy category 7, path-level): the provenance field a harvest
# writes into a memory's frontmatter, and the index that mirrors it. Deliberately unmarked --
# this zone is exempt by path, and an inline marker could not survive the index's wholesale
# regeneration anyway.
cat > "$FIXTURE/.memory/10-Memories/MEM-technique-example.md" << 'EOF'
---
topic: "task-101"
source: "Task 101: specs/101_example/summaries/01_example-summary.md"
---

Harvested while working on task 101.
EOF

cat > "$FIXTURE/.memory/memory-index.json" << 'EOF'
{
  "memories": [
    {
      "file": "10-Memories/MEM-technique-example.md",
      "source": "Task 101: specs/101_example/summaries/01_example-summary.md"
    }
  ]
}
EOF

cat > "$FIXTURE/specs/007_example_task/reports/01_report.md" << 'EOF'
# Report

Discusses task 7 phase 2 findings.
EOF
# task-ref-ok:end

# task-ref-ok:begin test fixture for check-task-references.sh detection, category 6
cat > "$FIXTURE/docs/marked.md" << 'EOF'
<!-- task-ref-ok:begin quoted historical anti-pattern -->
Fixed in task 123.
<!-- task-ref-ok:end -->
EOF
# task-ref-ok:end

# task-ref-ok:begin test fixture for check-task-references.sh detection, category 6
nested_cite_outer="Outer prose mentions task 201 outer."  # task-ref-ok inline test fixture, category 6
nested_cite_inner="Inner prose mentions task 202 inner."  # task-ref-ok inline test fixture, category 6
nested_cite_trailing="Between inner-end and outer-end, task 203 trailing."  # task-ref-ok inline test fixture, category 6
cat > "$FIXTURE/docs/nested-pair.md" << HEREDOC_EOF
<!-- task-ref-ok:begin outer region -->
$nested_cite_outer
<!-- task-ref-ok:begin inner region -->
$nested_cite_inner
<!-- task-ref-ok:end -->
$nested_cite_trailing
<!-- task-ref-ok:end -->
HEREDOC_EOF
# task-ref-ok:end

# Gitignored file carrying a citation -- must never be scanned (git ls-files excludes it).
echo "ignored/" > "$FIXTURE/.gitignore"
mkdir -p "$FIXTURE/ignored"
# task-ref-ok:begin test fixture for check-task-references.sh detection, category 6
echo "See task 888 for context." > "$FIXTURE/ignored/scratch.md"
# task-ref-ok:end

git -C "$FIXTURE" add -A
git -C "$FIXTURE" commit -q -m "fixture: consumer repo layout"

run_lint() {
  # $1 = extra args (PATH_SCOPE etc, may be empty); output+exit captured via a temp file so both
  # stdout and $? are available to the caller.
  local extra="$1" out_file="$2"
  ( cd "$FIXTURE" && REPO_ROOT="$FIXTURE" bash "$LINT_SRC" $extra ) > "$out_file" 2>&1
  echo $?
}

# =====================================================================
# Case 1: docs/ citation is found (exit 1, finding line names the docs/ path) -- the case that
# failed before this fix.
# =====================================================================
out="$WORKDIR/case1.txt"
code="$(run_lint "" "$out")"
if [[ "$code" -eq 1 ]] && grep -qE '^  docs/notes\.md:[0-9]+:' "$out"; then
  common_test_pass "docs/ citation found (exit 1, finding names docs/notes.md)"
else
  common_test_fail "docs/ citation not found as expected (exit=$code); output:
$(cat "$out")"
fi

# =====================================================================
# Case 2: source-dir (code/) citation is found -- the ModelChecker reproduction.
# =====================================================================
if grep -qE '^  code/operators\.py:[0-9]+:' "$out"; then
  common_test_pass "source dir (code/) citation found"
else
  common_test_fail "source dir (code/) citation not found; output:
$(cat "$out")"
fi

# =====================================================================
# Case 2b: README.md citation is found too (repo-wide, not tree-scoped).
# =====================================================================
if grep -qE '^  README\.md:[0-9]+:' "$out"; then
  common_test_pass "README.md citation found"
else
  common_test_fail "README.md citation not found; output:
$(cat "$out")"
fi

# =====================================================================
# Case 3: specs/** citation is NOT found -- the one path exemption holds.
# =====================================================================
if grep -q 'specs/007_example_task' "$out"; then
  common_test_fail "specs/** citation was scanned (should be exempt)"
else
  common_test_pass "specs/** citation correctly exempt"
fi

# =====================================================================
# Case 3b: .memory/** citations are NOT found -- the vault path exemption holds, for both a
# memory's own frontmatter provenance field and the index that mirrors it, neither marked.
# =====================================================================
if grep -q 'MEM-technique-example' "$out"; then
  common_test_fail ".memory/ memory-file citation was scanned (should be exempt)"
else
  common_test_pass ".memory/ memory-file citation correctly exempt"
fi
if grep -q 'memory-index.json' "$out"; then
  common_test_fail ".memory/ index citation was scanned (should be exempt)"
else
  common_test_pass ".memory/ index citation correctly exempt"
fi

# =====================================================================
# Case 4: task-ref-ok-marked region is NOT found.
# =====================================================================
if grep -q 'docs/marked.md' "$out"; then
  common_test_fail "task-ref-ok-marked citation was scanned (should be stripped)"
else
  common_test_pass "task-ref-ok-marked citation correctly stripped"
fi

# =====================================================================
# Case 4b: nested-pair regression -- a well-formed nested marker pair (begin A / begin B /
# end / end) exempts everything inside it, confirming the lint's whole-file behavior is
# unaffected by the shared library's internal depth-counter rewrite.
# =====================================================================
if grep -q 'docs/nested-pair.md' "$out"; then
  common_test_fail "nested-pair.md citation was scanned (should be stripped by the depth-counter parser)"
else
  common_test_pass "nested-pair.md citation correctly stripped (nested pairs resolve by depth)"
fi

# =====================================================================
# Case 5: gitignored file carrying a citation is NOT found (git ls-files exclusion).
# =====================================================================
if grep -q 'ignored/scratch.md' "$out"; then
  common_test_fail "gitignored citation was scanned (git ls-files should exclude it)"
else
  common_test_pass "gitignored citation correctly excluded"
fi

# =====================================================================
# Case 6: PATH_SCOPE=docs exits 0/1 with the docs/ finding, never 2.
# =====================================================================
out6="$WORKDIR/case6.txt"
code6="$(run_lint "docs" "$out6")"
if [[ "$code6" -eq 1 ]] && grep -qE '^  docs/notes\.md:[0-9]+:' "$out6"; then
  common_test_pass "PATH_SCOPE=docs finds the docs/ citation, exit 1 (never 2)"
else
  common_test_fail "PATH_SCOPE=docs expected exit 1 with docs/notes.md finding, got exit=$code6; output:
$(cat "$out6")"
fi

# =====================================================================
# Case 6b: PATH_SCOPE naming a non-existent path prints [SKIP] and exits 0.
# =====================================================================
out6b="$WORKDIR/case6b.txt"
code6b="$(run_lint "nonexistent-scope-xyz" "$out6b")"
if [[ "$code6b" -eq 0 ]] && grep -q '\[SKIP\]' "$out6b"; then
  common_test_pass "PATH_SCOPE naming a non-existent path prints [SKIP] and exits 0"
else
  common_test_fail "PATH_SCOPE nonexistent-scope-xyz expected exit 0 + [SKIP], got exit=$code6b; output:
$(cat "$out6b")"
fi

# =====================================================================
# Case 6c: PATH_SCOPE naming a single file (not a directory) is scanned, not skipped.
# =====================================================================
out6c="$WORKDIR/case6c.txt"
code6c="$(run_lint "README.md" "$out6c")"
if [[ "$code6c" -eq 1 ]] && grep -qE '^  README\.md:[0-9]+:' "$out6c" && ! grep -q '\[SKIP\]' "$out6c"; then
  common_test_pass "PATH_SCOPE naming a single file is scanned (not skipped)"
else
  common_test_fail "PATH_SCOPE=README.md expected exit 1, finding, no [SKIP], got exit=$code6c; output:
$(cat "$out6c")"
fi

# =====================================================================
# Case 7: per-finding line matches the verify-deploy.sh gate 4 contract:
# ^  [^:]+:[0-9]+:
# =====================================================================
if grep -E '^  [^:]+:[0-9]+:' "$out" >/dev/null; then
  common_test_pass "per-finding lines match the gate 4 regex ^  [^:]+:[0-9]+:"
else
  common_test_fail "no line in default-scan output matched the gate 4 regex"
fi

# =====================================================================
# Case 8: lint/hook scope agreement. For every fixture file with a planted citation, the lint's
# in-scope/out-of-scope verdict (does the default scan report a finding for this path?) must
# agree with the hook's verdict for a Write of that same path+content (does it block?). A
# repo-wide lint paired with a differently-scoped gate would be a new defect, not a fix.
# =====================================================================
hook_blocks() {
  local file_path="$1" content="$2" code
  jq -n --arg fp "$file_path" --arg c "$content" \
    '{tool_input: {file_path: $fp, content: $c}}' \
    | bash "$HOOK_SRC" >/dev/null 2>&1
  code=$?
  [[ "$code" -eq 2 ]]
}

lint_found() {
  local rel="$1"
  grep -qF "  $rel:" "$out"
}

agreement_ok=1
# task-ref-ok:begin test fixture for check-task-references.sh detection, category 6
declare -A AGREEMENT_FIXTURES=(
  ["README.md"]="See task 42 for the original discussion."
  ["docs/notes.md"]="Fixed in task 99 after investigation."
  ["code/operators.py"]="# implements the operator from task 17"
  ["specs/007_example_task/reports/01_report.md"]="Discusses task 7 phase 2 findings."
  [".memory/10-Memories/MEM-technique-example.md"]="Harvested while working on task 101."
  [".memory/memory-index.json"]="harvested from task 132"
)
# task-ref-ok:end
for rel in "${!AGREEMENT_FIXTURES[@]}"; do
  content="${AGREEMENT_FIXTURES[$rel]}"
  lint_verdict=0
  lint_found "$rel" && lint_verdict=1
  hook_verdict=0
  hook_blocks "$rel" "$content" && hook_verdict=1
  if [[ "$lint_verdict" -ne "$hook_verdict" ]]; then
    agreement_ok=0
    common_test_fail "lint/hook DISAGREE on $rel (lint_found=$lint_verdict hook_blocks=$hook_verdict)"
  fi
done
if [[ "$agreement_ok" -eq 1 ]]; then
  common_test_pass "lint and hook agree on every fixture file's in-scope verdict"
fi

# =====================================================================
# Case 9 (acceptance, mirrored from check-record-versioning.sh's own acceptance case): an
# untracked, on-disk file containing a task-reference occurrence does NOT yield a clean verdict
# under PATH_SCOPE mode. Deliberately never `git add`ed.
# =====================================================================
# task-ref-ok:begin test fixture for check-task-references.sh detection, category 6
echo "See task 777 for the untracked-file acceptance case." > "$FIXTURE/docs/untracked-citation.md"
# task-ref-ok:end
out9="$WORKDIR/case9.txt"
code9="$(run_lint "docs/untracked-citation.md" "$out9")"
if [[ "$code9" -eq 1 ]] && grep -qE '^  docs/untracked-citation\.md:[0-9]+:' "$out9"; then
  common_test_pass "untracked on-disk file with a task-reference occurrence yields a non-clean PATH_SCOPE verdict (acceptance)"
else
  common_test_fail "untracked citation file expected exit 1 naming it, got exit=$code9; output:
$(cat "$out9")"
fi

# =====================================================================
# Case 10: a gitignored file under a PATH_SCOPE still does not count as a finding (Case 5's
# exclusion preserved), AND now produces an explicit "[SKIP] ...: gitignored" stderr line.
# =====================================================================
out10="$WORKDIR/case10.txt"
code10="$(run_lint "ignored" "$out10")"
if [[ "$code10" -eq 0 ]] && ! grep -qE '^  ignored/scratch\.md:[0-9]+:' "$out10" \
   && grep -qF '[SKIP] ignored/scratch.md: gitignored (not scanned)' "$out10"; then
  common_test_pass "gitignored file under PATH_SCOPE=ignored: not a finding, named on stderr by [SKIP]"
else
  common_test_fail "PATH_SCOPE=ignored expected exit 0, no finding, [SKIP] line naming ignored/scratch.md; got exit=$code10; output:
$(cat "$out10")"
fi

# =====================================================================
# Case 11: the [SKIP]/gitignored stderr diagnostic survives --quiet.
# =====================================================================
out11="$WORKDIR/case11.txt"
code11="$(run_lint "--quiet ignored" "$out11")"
if [[ "$code11" -eq 0 ]] && grep -qF '[SKIP] ignored/scratch.md: gitignored (not scanned)' "$out11"; then
  common_test_pass "[SKIP]/gitignored diagnostic survives --quiet"
else
  common_test_fail "PATH_SCOPE=ignored --quiet expected the [SKIP] diagnostic to survive; got exit=$code11; output:
$(cat "$out11")"
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
