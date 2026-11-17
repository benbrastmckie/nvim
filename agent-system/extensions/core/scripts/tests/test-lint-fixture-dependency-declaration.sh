#!/usr/bin/env bash
# test-lint-fixture-dependency-declaration.sh - Both-polarity fixture test for
# scripts/lint/lint-fixture-dependency-declaration.sh.
#
# The lint's job is to flag a scripts/tests/*.sh suite whose declared/copied sandbox set omits a
# MANDATORY scripts/lib/*.sh dependency of a script it copies, covering both declaration shapes
# (a named array; an open-coded require_file/cp pair), while staying silent on the three
# OPTIONAL guard shapes already live in this corpus (the degrade-safe single-line guard, the
# log-and-continue search-loop pass-through, and the lazy fail-closed-on-first-use function
# wrapper that this lint deliberately never flags -- see the lint's own header). This suite
# seeds its three positive cases from the EXACT pre-repair text of the three historical commits
# that motivated this lint, rather than a synthetic fixture, so the regression bar is the
# actual drift this lint owes, not a stand-in for it.
#
# Structural model: test-lint-subject-resolution-declaration.sh (mktemp -d WORKDIR,
# common_test_resolve_subject / common_test_declare_subject, common_test_pass/_fail/_info).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LINT_SCRIPT="$(common_test_resolve_subject "lint-fixture-dependency-declaration.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lint/lint-fixture-dependency-declaration.sh" \
  "$SCRIPT_DIR/../lint/lint-fixture-dependency-declaration.sh")" || exit 2
common_test_declare_subject "$LINT_SCRIPT"

CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASSED=0
FAILED=0
common_test_workdir_init

# =====================================================================
# Cases 1-3 (FAILING, positive): the exact pre-repair text of the three historical commits that
# motivated this lint, each omitting lib/project-number-inuse.sh -- a dependency of
# state-write.sh, which all three suites copy. Case 3 is the Shape-2 (open-coded) suite; Cases 1
# and 2 are Shape-1 (named array), so this one fixture set exercises both declaration shapes.
# =====================================================================
common_test_info "=== FAILING: three measured pre-repair declarations (both shapes) ==="

declare -A PREREPAIR_SHA=(
  [test-postflight-deploy-gate.sh]="d3e45535e"
  [test-redeploy-checkpoint-promotion.sh]="1c10b01f7"
  [test-orchestrate-predispatch-review.sh]="4c96ccb4f"
)
declare -A PREREPAIR_SHAPE=(
  [test-postflight-deploy-gate.sh]="Shape 1 (named array)"
  [test-redeploy-checkpoint-promotion.sh]="Shape 1 (named array)"
  [test-orchestrate-predispatch-review.sh]="Shape 2 (open-coded)"
)
PREREPAIR_PATH="agent-system/extensions/core/scripts/tests"

for suite in test-postflight-deploy-gate.sh test-redeploy-checkpoint-promotion.sh test-orchestrate-predispatch-review.sh; do
  sha="${PREREPAIR_SHA[$suite]}"
  shape="${PREREPAIR_SHAPE[$suite]}"
  case_dir="$WORKDIR/prerepair-$suite"
  mkdir -p "$case_dir"

  if ! git -C "$REPO_ROOT" show "${sha}^:${PREREPAIR_PATH}/${suite}" > "$case_dir/$suite" 2>/dev/null; then
    common_test_fail "could not extract ${sha}^:${PREREPAIR_PATH}/${suite} -- path or commit spelling may have changed"
    continue
  fi
  if [[ ! -s "$case_dir/$suite" ]]; then
    common_test_fail "${sha}^:${PREREPAIR_PATH}/${suite} resolved to an empty file"
    continue
  fi
  if grep -q 'project-number-inuse' "$case_dir/$suite"; then
    common_test_fail "precondition violated: ${sha}^:${suite} already mentions project-number-inuse.sh -- this is not the pre-repair text the lint owes a regression for"
    continue
  else
    common_test_pass "$suite pre-repair text ($shape) genuinely omits project-number-inuse.sh (precondition confirmed)"
  fi

  out="$(bash "$LINT_SCRIPT" --verbose "$case_dir" 2>&1)"
  rc=$?

  if [[ $rc -eq 1 ]]; then
    common_test_pass "$suite pre-repair ($shape): lint exits 1 (violation found)"
  else
    common_test_fail "$suite pre-repair ($shape): lint exited $rc (expected 1):
$out"
  fi

  if grep -qE '\[VIOLATION\].*'"$suite"'.*lib/project-number-inuse\.sh' <<<"$out"; then
    common_test_pass "$suite pre-repair ($shape): violation names lib/project-number-inuse.sh"
  else
    common_test_fail "$suite pre-repair ($shape): violation did not name lib/project-number-inuse.sh as expected:
$out"
  fi

  if grep -q 'SELECTED' <<<"$out" && grep -qF "$case_dir/$suite" <<<"$out"; then
    common_test_pass "$suite pre-repair ($shape): suite-selection predicate selected it"
  else
    common_test_fail "$suite pre-repair ($shape): suite-selection predicate did not select it:
$out"
  fi
done

# =====================================================================
# Cases 4-6 (PASSING, negative): the same three suites' CURRENT (already-repaired) text,
# checked directly against their real on-disk paths -- zero violations.
# =====================================================================
common_test_info "=== PASSING: the same three suites' current (repaired) text ==="

for suite in test-postflight-deploy-gate.sh test-redeploy-checkpoint-promotion.sh test-orchestrate-predispatch-review.sh; do
  live_path="$CORE_DIR/tests/$suite"
  if [[ ! -f "$live_path" ]]; then
    common_test_fail "$suite not found at $live_path"
    continue
  fi
  out="$(bash "$LINT_SCRIPT" "$live_path" 2>&1)"
  rc=$?
  if [[ $rc -eq 0 ]]; then
    common_test_pass "$suite current text: lint exits 0 (clean)"
  else
    common_test_fail "$suite current text: lint exited $rc (expected 0, already repaired):
$out"
  fi
done

# =====================================================================
# Case 7 (PASSING, dedicated OPTIONAL shape (ii) negative): a synthetic suite that copies
# orchestrate-predispatch-review.sh and declares its MANDATORY deps only (common.sh,
# task-lookup-lib.sh, file-scope-overlap.sh -- the last one is MANDATORY here because this
# script's own `if ! . "lib/file-scope-overlap.sh" ...; then ... exit 2; fi` guard sits at
# column 0, unconditionally reached) while deliberately omitting redeploy-remedy-lib.sh, whose
# single-line `[ -f "$_RR_LIB" ] && . "$_RR_LIB"` guard (shape ii) must never be reported missing.
# =====================================================================
common_test_info "=== PASSING: dedicated OPTIONAL shape (ii) negative (redeploy-remedy-lib.sh) ==="

case7_dir="$WORKDIR/case7"
mkdir -p "$case7_dir"
cat > "$case7_dir/test-seeded-shape-ii.sh" << 'EOF'
#!/usr/bin/env bash
set -uo pipefail
CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
require_file() {
  if [ ! -f "$1" ]; then
    echo "ERROR: expected $1" >&2
    exit 2
  fi
}
require_file "$CORE_DIR/orchestrate-predispatch-review.sh"
require_file "$CORE_DIR/lib/common.sh"
require_file "$CORE_DIR/lib/task-lookup-lib.sh"
require_file "$CORE_DIR/lib/file-scope-overlap.sh"
WORKDIR="$(mktemp -d)"
mkdir -p "$WORKDIR/.claude/scripts/lib"
cp "$CORE_DIR/orchestrate-predispatch-review.sh" "$WORKDIR/.claude/scripts/orchestrate-predispatch-review.sh"
cp "$CORE_DIR/lib/common.sh" "$WORKDIR/.claude/scripts/lib/common.sh"
cp "$CORE_DIR/lib/task-lookup-lib.sh" "$WORKDIR/.claude/scripts/lib/task-lookup-lib.sh"
cp "$CORE_DIR/lib/file-scope-overlap.sh" "$WORKDIR/.claude/scripts/lib/file-scope-overlap.sh"
EOF

out="$(bash "$LINT_SCRIPT" "$case7_dir" 2>&1)"
rc=$?
if [[ $rc -eq 0 ]]; then
  common_test_pass "shape (ii) negative: declaring only the mandatory deps (omitting redeploy-remedy-lib.sh) is clean"
else
  common_test_fail "shape (ii) negative: redeploy-remedy-lib.sh was misreported as missing (expected exit 0, got $rc):
$out"
fi

# =====================================================================
# Case 8 (PASSING, dedicated OPTIONAL shape (iii) negative): a synthetic suite that copies
# update-task-status.sh and declares its MANDATORY deps plus redeploy-remedy-lib.sh (isolating
# this case from shape (ii)) while deliberately omitting file-scope-overlap.sh and
# deploy-freshness-lib.sh, whose log-and-continue `*_CANDIDATES` search-loop pass-through
# (shape iii, optional) must never be reported missing.
# =====================================================================
common_test_info "=== PASSING: dedicated OPTIONAL shape (iii) negative (file-scope-overlap.sh / deploy-freshness-lib.sh) ==="

case8_dir="$WORKDIR/case8"
mkdir -p "$case8_dir"
cat > "$case8_dir/test-seeded-shape-iii.sh" << 'EOF'
#!/usr/bin/env bash
set -uo pipefail
CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQUIRED_SCRIPTS=(update-task-status.sh lib/common.sh lib/phase-heading-patterns.sh lib/status-vocabulary.sh lib/redeploy-remedy-lib.sh)
missing=()
for f in "${REQUIRED_SCRIPTS[@]}"; do
  [ -f "$CORE_DIR/$f" ] || missing+=("$f")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "ERROR: missing: ${missing[*]}" >&2
  exit 2
fi
WORKDIR="$(mktemp -d)"
mkdir -p "$WORKDIR/.claude/scripts/lib"
for f in "${REQUIRED_SCRIPTS[@]}"; do
  cp "$CORE_DIR/$f" "$WORKDIR/.claude/scripts/$f"
done
EOF

out="$(bash "$LINT_SCRIPT" "$case8_dir" 2>&1)"
rc=$?
if [[ $rc -eq 0 ]]; then
  common_test_pass "shape (iii) negative: declaring only the mandatory deps (omitting file-scope-overlap.sh / deploy-freshness-lib.sh) is clean"
else
  common_test_fail "shape (iii) negative: an OPTIONAL log-and-continue dependency was misreported as missing (expected exit 0, got $rc):
$out"
fi

# =====================================================================
# Case 9 (live-corpus case): run the lint with no positional argument against the real source
# store -- the standing assertion that the gate is not red on the live tree.
# =====================================================================
common_test_info "=== Live-corpus case: default corpus against the real source store ==="

case9_out="$(bash "$LINT_SCRIPT" 2>&1)"
case9_rc=$?
if [[ $case9_rc -eq 0 ]]; then
  common_test_pass "default corpus against the live source store exits 0"
else
  common_test_fail "default corpus against the live source store did not exit 0 (rc=$case9_rc):
$case9_out"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
