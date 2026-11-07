#!/usr/bin/env bash
# lint-subject-resolution-declaration.sh - Detect a lint-fixture-test suite that resolves a
# deployed/source-store subject-under-test through an undeclared or silently-ordered shape,
# instead of the explicit, mode-selectable, mandatory-declaration pair
# (common_test_resolve_subject / common_test_declare_subject, lib/common.sh).
#
# WHY THIS EXISTS
# ----------------
# The deploy-tree-first / source-store-fallback subject-resolution convention used across the
# lint-fixture-test family is real and load-bearing (the Inter-Cycle Redeploy Checkpoint's
# pre/post divergence signal depends on it staying deploy-tree-first by default -- see
# context/patterns/batch-orchestration-guardrails.md). But until common_test_resolve_subject
# existed, every caller's resolution mode was IMPLICIT in its candidate argument order, and no
# suite ever declared which copy it actually tested. A green run was therefore indistinguishable
# from a vacuous one: running a suite after editing the source-store copy but before a redeploy
# silently exercised the STALE deployed copy. This lint is the guardrail against a NEW suite
# reintroducing any of the three undeclared/silently-ordered shapes that caused that defect, now
# that the explicit, self-declaring alternative exists.
#
# DETECTION MODEL (file-level, four checks; see KNOWN LIMITATION below)
# -----------------------------------------------------------------------
# Four independent, file-level structural checks, each its own VIOLATION class:
#
#   1. HAND-DUPLICATE shape: the file defines its own local `resolve_candidate() {` function
#      instead of calling the shared library's helper -- a hand-duplicated copy of the
#      deploy-tree-first/source-store-fallback lookup.
#   2. INLINE-LOOP shape: the file contains an inline `*CANDIDATES*`-named array assignment
#      (`FOO_CANDIDATES=(`) or a `for candidate in` loop -- the shape invisible to a
#      `grep resolve_candidate` measurement, because it never names a function at all.
#   3. MISSING-DECLARATION shape: the file calls `common_test_resolve_subject` more times than
#      it calls `common_test_declare_subject` -- a resolved subject with no paired declaration,
#      the exact defect this whole mechanism exists to make impossible to hide.
#   4. UNMIGRATED-IMPLICIT-ORDER shape: the file calls `common_test_resolve_candidate` AND
#      contains a literal `.claude/scripts` path -- the deploy-tree-first/source-store-fallback
#      pair in its original, mode-implicit form.
#
# A file matching ANY of the four is a VIOLATION unless it carries a Layer-2 allowlist entry
# (below), each stating its own one-line reason: either "migration-pending" (a measured member
# of the family, scheduled for conversion in a reviewable batch) or "permanent" (a suite that
# legitimately does not fit the explicit-helper contract, with the specific reason why).
#
# KNOWN LIMITATION (stated plainly rather than papered over)
# ------------------------------------------------------------
# This is a regex-only, FILE-level (not call-site-level) content lint, matching the precedent set
# by lint-verdict-extraction-anchoring.sh and lint-state-writer-boundary.sh. It cannot distinguish
# two unrelated statements in the same file that each independently trip a different check's
# token (e.g. a file whose check-4 tokens come from two different, unrelated statements), and it
# cannot catch a variable-indirected call (a function name assembled into a variable before being
# invoked). It is a guardrail against the recurrence of the three known bad shapes, and against a
# new resolve_subject caller skipping its declaration, not a proof that every resolution site in
# the corpus is helper-routed.
#
# SCAN CORPUS
# -----------
# Deliberately narrow: `scripts/tests/*.sh` (non-recursive; this directory has no subdirectories).
# This is the lint-fixture-test family's own home -- widening the corpus would reach suites that
# never resolve a deployed/source-store subject at all.
#
# Usage: lint-subject-resolution-declaration.sh [--verbose] [--quiet] [path...]
#
#   path...    Optional. Files or directories to scan. A directory is scanned (non-recursively for
#              the default root; recursively for an explicit directory argument, matching the
#              corpus-scan library's own default behavior) for .sh files. Defaults to
#              scripts/tests/ under the source store.
#   --verbose  Report every exempted file too, tagged with its allowlist reason.
#   --quiet    Suppress the progress header and the all-clear summary. Violations are still
#              printed, and the failing summary is still printed, so a failing run is never
#              silent.
#
# Exit codes:
#   0 - No unexcluded violations found
#   1 - One or more unexcluded violations found (each printed as a [VIOLATION] row naming the file)
#   2 - Script error (unresolvable project root, missing shared library, unreadable scan path)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERBOSE=false
QUIET=false
SCAN_PATHS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/../lib/common.sh" ]]; then
    echo "ERROR: shared library not found at ${SCRIPT_DIR}/../lib/common.sh" >&2
    exit 2
fi
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"
if [[ ! -f "${SCRIPT_DIR}/../lib/lint-corpus-scan-lib.sh" ]]; then
    echo "ERROR: shared library not found at ${SCRIPT_DIR}/../lib/lint-corpus-scan-lib.sh" >&2
    exit 2
fi
# shellcheck source=../lib/lint-corpus-scan-lib.sh
source "${SCRIPT_DIR}/../lib/lint-corpus-scan-lib.sh"

lint_corpus_scan_parse_flags SCAN_PATHS VERBOSE QUIET -- "$@" || exit 2

# Root resolution -- same walk-up-until-source-store-found strategy as
# lint-verdict-extraction-anchoring.sh, since this script also runs directly from the source
# store, where a fixed-depth common_repo_root walk would land in the wrong place.
resolve_project_root() {
    local candidate
    candidate="$(common_repo_root "$SCRIPT_DIR" 3)"
    if [[ -n "$candidate" && -d "$candidate/agent-system/extensions" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    local dir="$SCRIPT_DIR"
    local i=0
    while [[ $i -lt 8 ]]; do
        dir="$(cd "$dir/.." 2>/dev/null && pwd)" || break
        [[ -z "$dir" || "$dir" == "/" ]] && break
        if [[ -d "$dir/agent-system/extensions" ]]; then
            printf '%s\n' "$dir"
            return 0
        fi
        i=$((i + 1))
    done

    printf '%s\n' "$candidate"
    return 0
}

PROJECT_ROOT="$(resolve_project_root)"
CORE_TESTS="$PROJECT_ROOT/agent-system/extensions/core/scripts/tests"

if [[ ${#SCAN_PATHS[@]} -eq 0 ]]; then
    if [[ ! -d "$CORE_TESTS" ]]; then
        echo "ERROR: default scan root not found: $CORE_TESTS" >&2
        echo "       Pass explicit path arguments, or run from a checkout containing the source store." >&2
        exit 2
    fi
    SCAN_PATHS=("$CORE_TESTS")
fi

# ---------------------------------------------------------------------------
# Layer 2: file-level allowlist. Every entry is "<repo-relative-path>|<one-line reason>".
# "migration-pending: ..." entries name a measured member of the 70-suite family, scheduled for
# conversion in a reviewable batch; "permanent: ..." entries name a suite that legitimately does
# not fit the explicit-helper contract. A passing lint run is never readable as "fully migrated"
# while a migration-pending entry remains -- each migration batch removes exactly the entries it
# converted in the same commit.
# ---------------------------------------------------------------------------
EXCLUDED_FILES=(
# --- This lint's own fixture test necessarily contains heredoc-embedded literal strings
# reproducing all three bad shapes plus the missing-declaration case, to prove the lint detects
# them (same reasoning as lint-verdict-extraction-anchoring.sh's own self-exemption). ---
    "agent-system/extensions/core/scripts/tests/test-lint-subject-resolution-declaration.sh|permanent: this suite's own seeded-violation fixtures are heredoc-embedded literal strings reproducing the bad shapes, necessarily present in its own source to prove the lint detects them"

# --- Group A: common_test_resolve_candidate callers -- migrated to common_test_resolve_subject.
# Only test-common-lib.sh remains, permanently: it is the function's own regression suite,
# exercising common_test_resolve_candidate/common_test_resolve_subject directly against
# synthetic fixture paths as the function under test, never as a genuine subject-resolution
# call -- the paired-declaration discipline does not apply to a function's own unit test. ---
    "agent-system/extensions/core/scripts/tests/test-common-lib.sh|permanent: this is common_test_resolve_candidate/common_test_resolve_subject's own regression suite, exercising both directly against synthetic fixture paths as the function under test, not as a genuine subject-resolution call"

# --- test-task-type-detect.sh is already migrated (its task-type-detect.sh subject resolves via
# common_test_resolve_subject with a declaration above). It also calls
# common_test_resolve_candidate once more, for REAL_EXT_ROOT -- a single-candidate lookup of the
# extensions/ directory, not a deployed/source-store subject-pair resolution at all, so it is
# intentionally left on the old helper per this task's "leave non-subject uses on the old helper"
# rule. The file-level check-4 regex (this lint's documented KNOWN LIMITATION) cannot distinguish
# that unrelated statement from the migrated one, hence this permanent allowlist entry. ---
    "agent-system/extensions/core/scripts/tests/test-task-type-detect.sh|permanent: its task-type-detect.sh subject is migrated to common_test_resolve_subject with a declaration; its separate REAL_EXT_ROOT lookup is a single-candidate extensions/-directory resolution, not a deployed/source-store subject pair, and stays on common_test_resolve_candidate by design"

# --- Group B: local hand-duplicated resolve_candidate() function -- all 12 migrated to the
# shared explicit helper (common_test_resolve_subject + common_test_declare_subject); no entries
# remain. ---

# --- Group C: inline CANDIDATES-array loop, no named function, migration-pending ---
    "agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-consumer-freshness.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-context-reachability.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-deploy-root-guard.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-derived-artifact-probe-lib.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-dispatch-metrics.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-engine-written-state-paths-lib.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-errors-append.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-generate-task-order.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-issue-record.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-reconcile-demote-stranded.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-record-version-patterns.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-redeploy-remedy-lib.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-return-meta-status-vocabulary.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-script-inventory.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-status-vocabulary.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-sweep-invalidated-claims.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-update-plan-status.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-validate-artifact.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-validate-handoff.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"
    "agent-system/extensions/core/scripts/tests/test-validate-state.sh|migration-pending: Group C shape (inline CANDIDATES-array for-loop, invisible to a resolve_candidate grep); scheduled for conversion to common_test_resolve_subject"

# --- Permanent exemptions: deployed-only-by-design (one valid copy; no store/deployed duality) ---
    "agent-system/extensions/core/scripts/tests/test-backfill-file-scope.sh|permanent: deployed-only by design, one valid copy, no deployed/source-store duality to declare"
    "agent-system/extensions/core/scripts/tests/test-double-loading-check.sh|permanent: deployed-only by design, one valid copy, no deployed/source-store duality to declare"
    "agent-system/extensions/core/scripts/tests/test-update-task-status.sh|permanent: deployed-only by design, one valid copy, no deployed/source-store duality to declare"

# --- Permanent exemptions: non-subject-resolution CANDIDATES mentions (describe a production script's own internal resolution, not this harness's own subject) ---
    "agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh|permanent: prose/comments describe a production script's own internal LIB_CANDIDATES resolution, not this harness's own subject-under-test"
    "agent-system/extensions/core/scripts/tests/test-check-task-references.sh|permanent: prose/comments describe a production script's own internal LIB_CANDIDATES resolution, not this harness's own subject-under-test"
)

is_excluded_file() {
    local file="$1"
    local rel="${file#"$PROJECT_ROOT"/}"
    local entry entry_path
    for entry in "${EXCLUDED_FILES[@]}"; do
        entry_path="${entry%%|*}"
        [[ "$rel" == "$entry_path" ]] && return 0
        [[ "$file" == */"$entry_path" ]] && return 0
    done
    return 1
}

excluded_reason() {
    local file="$1"
    local rel="${file#"$PROJECT_ROOT"/}"
    local entry entry_path entry_reason
    for entry in "${EXCLUDED_FILES[@]}"; do
        entry_path="${entry%%|*}"
        entry_reason="${entry#*|}"
        if [[ "$rel" == "$entry_path" ]] || [[ "$file" == */"$entry_path" ]]; then
            printf '%s\n' "$entry_reason"
            return 0
        fi
    done
    printf '%s\n' "(no reason on file)"
    return 0
}

# ---------------------------------------------------------------------------
# Layer 1: structural detection, per file
# ---------------------------------------------------------------------------
HAND_DUP_RE='^[[:space:]]*resolve_candidate\(\)[[:space:]]*\{'
INLINE_ARRAY_RE='^[[:space:]]*[A-Za-z0-9_]*CANDIDATES[A-Za-z0-9_]*=\('
INLINE_LOOP_RE='for[[:space:]]+candidate[[:space:]]+in[[:space:]]'

# Echoes zero or more of: HAND_DUP INLINE_LOOP MISSING_DECLARATION UNMIGRATED_IMPLICIT_ORDER
classify_file() {
    local f="$1"
    local hits=""

    grep -qE "$HAND_DUP_RE" "$f" 2>/dev/null && hits="$hits HAND_DUP"
    { grep -qE "$INLINE_ARRAY_RE" "$f" 2>/dev/null || grep -qE "$INLINE_LOOP_RE" "$f" 2>/dev/null; } && hits="$hits INLINE_LOOP"

    local resolve_subject_count declare_subject_count
    resolve_subject_count="$(grep -c 'common_test_resolve_subject' "$f" 2>/dev/null || true)"
    declare_subject_count="$(grep -c 'common_test_declare_subject' "$f" 2>/dev/null || true)"
    resolve_subject_count="${resolve_subject_count:-0}"
    declare_subject_count="${declare_subject_count:-0}"
    if [[ "$resolve_subject_count" -gt "$declare_subject_count" ]]; then
        hits="$hits MISSING_DECLARATION"
    fi

    if grep -q 'common_test_resolve_candidate' "$f" 2>/dev/null && grep -Fq '.claude/scripts' "$f" 2>/dev/null; then
        hits="$hits UNMIGRATED_IMPLICIT_ORDER"
    fi

    printf '%s\n' "$hits"
}

violation_message() {
    case "$1" in
        HAND_DUP)
            printf '%s\n' "declares a local resolve_candidate() function (hand-duplicate shape) -- route through common_test_resolve_subject (lib/common.sh) instead of hand-duplicating the lookup"
            ;;
        INLINE_LOOP)
            printf '%s\n' "contains an inline CANDIDATES-array for-loop (inline shape, invisible to a resolve_candidate grep) -- route through common_test_resolve_subject (lib/common.sh) instead"
            ;;
        MISSING_DECLARATION)
            printf '%s\n' "calls common_test_resolve_subject without a paired common_test_declare_subject for every resolved subject -- a resolved subject MUST be declared (lib/common.sh)"
            ;;
        UNMIGRATED_IMPLICIT_ORDER)
            printf '%s\n' "calls common_test_resolve_candidate against a .claude/scripts deployed candidate without an explicit mode (unmigrated implicit-order shape) -- migrate to common_test_resolve_subject with an explicit mode"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Collect files to scan
# ---------------------------------------------------------------------------
# Deliberately NOT lint_corpus_scan_collect_files's shared-corpus-reuse path: that optimization
# matches a PATTERN with [[ == ]] globbing against the WHOLE repo-wide corpus, where '*' spans
# directory separators freely -- a bare '*.sh' pattern would silently widen this lint's scan to
# every .sh file in the tree (confirmed live: running under verify-deploy.sh, where
# GATE_SHARED_CORPUS_FILE/ROOT are exported, this scanned far beyond scripts/tests/ and produced
# false violations from unrelated files elsewhere in the source store). This corpus is small and
# flat, so a direct `find` is used unconditionally instead of chasing the shared-corpus path's
# multi-segment-pattern caveat.
FILES=()
for _subj_scan_path in "${SCAN_PATHS[@]}"; do
    if [[ -d "$_subj_scan_path" ]]; then
        while IFS= read -r _subj_found; do
            [[ -n "$_subj_found" ]] && FILES+=("$_subj_found")
        done < <(find "$_subj_scan_path" -type f -name '*.sh' 2>/dev/null | sort)
    elif [[ -f "$_subj_scan_path" ]]; then
        FILES+=("$_subj_scan_path")
    else
        echo "ERROR: scan path not found: $_subj_scan_path" >&2
        exit 2
    fi
done
unset _subj_scan_path _subj_found

# ---------------------------------------------------------------------------
# Main scan
# ---------------------------------------------------------------------------
VIOLATIONS=0
FILES_CHECKED=0
FILES_WITH_VIOLATIONS=0
EXEMPTED=0

$QUIET || {
    echo "Checking subject-resolution declaration compliance..."
    echo "Scan roots: ${SCAN_PATHS[*]}"
    echo ""
}

for file in "${FILES[@]}"; do
    ((FILES_CHECKED++)) || true

    hits="$(classify_file "$file")"
    if [[ -z "$hits" ]]; then
        continue
    fi

    if is_excluded_file "$file"; then
        ((EXEMPTED++)) || true
        $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file: $(excluded_reason "$file")"
        continue
    fi

    file_violations=0
    for shape in $hits; do
        echo -e "${RED}[VIOLATION]${NC} $file: $(violation_message "$shape")"
        ((file_violations++)) || true
        ((VIOLATIONS++)) || true
    done
    [[ $file_violations -gt 0 ]] && ((FILES_WITH_VIOLATIONS++)) || true
done

if [[ $VIOLATIONS -eq 0 ]]; then
    $QUIET || {
        echo ""
        echo "================================"
        echo "Subject-Resolution Declaration Check Summary"
        echo "================================"
        echo "Files checked: $FILES_CHECKED"
        echo "Files exempted: $EXEMPTED"
        echo "Total violations: 0"
        echo -e "${GREEN}No undeclared or silently-ordered subject-resolution sites found.${NC}"
    }
    exit 0
fi

echo ""
echo "================================"
echo "Subject-Resolution Declaration Check Summary"
echo "================================"
echo "Files checked: $FILES_CHECKED"
echo "Files with violations: $FILES_WITH_VIOLATIONS"
echo "Files exempted: $EXEMPTED"
echo "Total violations: $VIOLATIONS"
echo -e "${RED}Found $VIOLATIONS undeclared or silently-ordered subject-resolution site(s). See above for details.${NC}"
echo ""
echo "Fix: route the resolution through common_test_resolve_subject plus common_test_declare_subject"
echo "(see scripts/lib/common.sh's header for the contract and"
echo "context/standards/shell-script-testing.md's three-shape taxonomy)."
echo "Edit the source store under agent-system/extensions/ -- .claude/ is a generated artifact."
exit 1
