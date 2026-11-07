#!/usr/bin/env bash
# check-task-references.sh
#
# Repo-wide lint gate for rules/no-task-references-in-deliverables.md: scans the UNION of every
# git-tracked file and every untracked-but-not-gitignored file in the repository (via the shared
# scripts/lib/git-corpus-enum-lib.sh enumeration, so gitignored/vendored/generated paths stay
# excluded by construction while a file that merely has not been `git add`ed yet is still
# scanned) EXCEPT specs/** for unexempted task-number citations, using the SAME shared
# pattern/exemption library the write-time guard hook consumes
# (scripts/lib/task-reference-patterns.sh). Neither this script nor the hook defines
# TASK_PATTERN, PHASE_PATTERN, or exemption logic locally -- see that library and
# context/standards/task-reference-exemptions.md's Exemption Taxonomy section (companion to
# rules/no-task-references-in-deliverables.md) for the single source
# of truth both consume.
#
# The scan is repo-appropriate by construction: it does not hard-code this repo's own directory
# layout (agent-system/extensions, .opencode, lua, .memory), so a consumer repo with a different
# source-tree layout (docs/, README.md, a language-specific source dir, etc.) is scanned in full
# rather than scanning nothing. Two path-level exemptions are subtracted from that scope via
# is_exempt_path -- `specs/**` (task-management artifacts, taxonomy category 1) and `.memory/**`
# (the memory vault, whose per-memory provenance fields are structured data, category 7).
#
# UNTRACKED-INCLUSION: this lint shares a single enumeration definition with
# check-record-versioning.sh (git-corpus-enum-lib.sh's `git_corpus_enum`) so the two cannot drift
# from each other's semantics. See that script's header for the full false-clean defect
# narrative -- the short version: a bare `git ls-files PATH_SCOPE` returns zero rows for an
# on-disk-but-untracked file even though the path's own `-e` existence guard still passes, so the
# old enumeration silently scanned nothing and reported clean. Three stderr-only diagnostics
# (never routed through `info()`, so `--quiet` cannot suppress them) make "clean" and "not
# examined" distinguishable: an untracked-inclusion count, a per-file
# `[SKIP] ...: gitignored (not scanned)` line in PATH_SCOPE mode, and a zero-enumeration notice
# when a PATH_SCOPE exists on disk but enumerates nothing.
#
# Exit codes:
#   0 - no unexempted citations found in the scanned scope.
#   1 - one or more unexempted citations found.
#   2 - environment/usage error (shared library missing, git unavailable, unknown flag).
#       Distinct from 1 so a broken script invocation is never mistaken for a clean tree.
#
# Usage:
#   bash .claude/scripts/check-task-references.sh              (verbose: prints every finding)
#   bash .claude/scripts/check-task-references.sh --quiet       (summary only)
#   bash .claude/scripts/check-task-references.sh [--quiet] PATH_SCOPE
#       (scope the scan to a subtree or a single file anywhere in the repo, e.g.
#       agent-system/extensions/core/context or docs/README.md -- reports and exits on findings
#       under PATH_SCOPE only. Any in-repo path is scannable; a PATH_SCOPE naming a path that does
#       not exist prints a [SKIP] line and exits 0 rather than erroring. The no-argument and
#       --quiet-only forms are UNCHANGED in shape: same exit codes, same per-finding line format.
#       An on-disk-but-untracked file under PATH_SCOPE is scanned on its merits (not silently
#       skipped); a still-excluded gitignored file under PATH_SCOPE is named on stderr by a
#       `[SKIP] <path>: gitignored (not scanned)` line rather than passing in silence, and a
#       PATH_SCOPE that enumerates nothing at all gets its own stderr notice saying so.)
#   REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh
#       (source-store invocation override -- see check-extension-docs.sh for the same pattern;
#       required because .claude/scripts/check-task-references.sh does not exist until a deploy
#       runs)

set -uo pipefail

QUIET=0
PATH_SCOPE=""
if [[ $# -gt 0 && "$1" == "--quiet" ]]; then
  QUIET=1
  shift
fi
if [[ $# -gt 0 ]]; then
  case "$1" in
    --*)
      echo "ERROR: unknown flag: $1" >&2
      exit 2
      ;;
    *)
      PATH_SCOPE="${1%/}"
      shift
      ;;
  esac
fi
if [[ $# -gt 0 ]]; then
  echo "ERROR: unexpected extra argument(s): $*" >&2
  exit 2
fi

# ── REPO_ROOT resolution ─────────────────────────────────────────────────────────────────────
# Same convention as check-extension-docs.sh: deploy-root-guard.sh enforces that the computed
# default (SCRIPT_DIR/../..) only resolves from a real deploy tree; a deliberate source-store
# invocation MUST pass REPO_ROOT=$(pwd) explicitly, which bypasses the guard below.
[[ -n "${REPO_ROOT:-}" ]] || . "$(dirname "${BASH_SOURCE[0]}")/deploy-root-guard.sh" || exit 2
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required and is not on PATH" >&2
  exit 2
fi

# ── Shared library ───────────────────────────────────────────────────────────────────────────
# Sourced from the deployed location first (the ordinary runtime case), falling back to the
# source-store location for REPO_ROOT=$(pwd) source-store invocations where no deploy has
# happened yet (see the "Redeploy checkpoints" note in this task's plan). No patterns or
# exemption logic are defined here -- if the library cannot be found, this is an environment
# error (exit 2), never a silent fall-through to an inline pattern.
LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/task-reference-patterns.sh"
  "$REPO_ROOT/agent-system/extensions/core/scripts/lib/task-reference-patterns.sh"
)
LIB=""
for candidate in "${LIB_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    LIB="$candidate"
    break
  fi
done
if [[ -z "$LIB" ]]; then
  echo "ERROR: shared library task-reference-patterns.sh not found at any of:" >&2
  for candidate in "${LIB_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi
# shellcheck disable=SC1090
. "$LIB"

# ── Shared corpus-enumeration library ────────────────────────────────────────────────────────
# Same not-found severity as the task-reference-patterns.sh block above: a missing or stale
# git-corpus-enum-lib.sh must fail loudly (exit 2), never silently fall back to the bare
# `git ls-files` enumeration this library exists to replace -- that silent fallback IS the
# defect this script was fixed to stop reproducing. This is the SAME library
# check-record-versioning.sh consumes, so the two lints cannot drift from each other's
# enumeration semantics.
CORPUS_LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/git-corpus-enum-lib.sh"
  "$REPO_ROOT/agent-system/extensions/core/scripts/lib/git-corpus-enum-lib.sh"
)
CORPUS_LIB=""
for candidate in "${CORPUS_LIB_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    CORPUS_LIB="$candidate"
    break
  fi
done
if [[ -z "$CORPUS_LIB" ]]; then
  echo "ERROR: shared library git-corpus-enum-lib.sh not found at any of:" >&2
  for candidate in "${CORPUS_LIB_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi
# shellcheck disable=SC1090
. "$CORPUS_LIB"

# A library found at a candidate path but missing an expected function is a DIFFERENT
# environment error than "not found" above, with the same severity -- a stale deployed copy
# would otherwise fail SILENTLY (an undefined `git_corpus_enum` under a pipeline whose errors
# this script does not surface would simply enumerate nothing, reinstating the exact false-clean
# defect this wiring exists to close) rather than the loud failure an incompatible library
# deserves.
for required_fn in git_corpus_enum git_corpus_unenumerated_report git_corpus_untracked_count; do
  if ! declare -F "$required_fn" >/dev/null 2>&1; then
    echo "ERROR: library at $CORPUS_LIB is missing required function '$required_fn' -- stale" >&2
    echo "       or incompatible version. Redeploy core, or point REPO_ROOT at a tree whose" >&2
    echo "       deployed library is current." >&2
    exit 2
  fi
done

info() { [[ $QUIET -eq 0 ]] && echo "$@"; }

# SCAN_COUNT is set (not echoed) by scan_tree, and scan_tree is always invoked directly (never
# inside a command substitution) so its info() finding lines reach real stdout rather than being
# captured as part of a subshell's output.
SCAN_COUNT=0

# scan_tree <label> <enum_path>
# <label> names the scanned scope for reporting; <enum_path> is what is actually passed to
# `git_corpus_enum` for enumeration (the shared tracked-plus-untracked union, see
# lib/git-corpus-enum-lib.sh), relative to REPO_ROOT. "." enumerates the whole repository (the
# default, unscoped case); any other value scopes to that subtree or file (PATH_SCOPE mode).
# Existence is checked with `-e`, not `-d`, so a PATH_SCOPE naming a single file is scanned
# rather than incorrectly treated as missing.
scan_tree() {
  local label="$1"
  local enum_path="$2"
  local enum_dir="$REPO_ROOT/$enum_path"
  local count=0

  if [[ ! -e "$enum_dir" ]]; then
    info "  [SKIP] $label does not exist under $REPO_ROOT"
    SCAN_COUNT=0
    return 0
  fi

  # Enumerated once into a variable (rather than re-invoked per diagnostic) so the loop below and
  # the zero-enumeration check see the exact same result.
  local enum_output
  enum_output="$(git_corpus_enum "$REPO_ROOT" "$enum_path")"

  if [[ -z "$enum_output" ]]; then
    echo "  [DIAG] $label: PATH_SCOPE exists on disk but enumerates 0 files -- nothing was" >&2
    echo "         scanned under this scope (an empty directory, or every file under it is" >&2
    echo "         gitignored)" >&2
  fi

  local untracked_count
  untracked_count="$(git_corpus_untracked_count "$REPO_ROOT" "$enum_path")"
  if [[ "$untracked_count" -gt 0 ]]; then
    echo "  [DIAG] $label: $untracked_count untracked (not git-added) file(s) included in this scan" >&2
  fi

  # Per-file loud-skip report: PATH_SCOPE mode only (enum_path != "."), per this script's
  # Non-Goals -- a repo-wide run would otherwise name the whole gitignored .claude/ deploy tree.
  if [[ "$enum_path" != "." ]]; then
    local unenum_report
    unenum_report="$(git_corpus_unenumerated_report "$REPO_ROOT" "$enum_path")"
    [[ -n "$unenum_report" ]] && printf '%s\n' "$unenum_report" >&2
  fi

  local file rel
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue

    if is_exempt_path "$rel"; then
      continue
    fi

    file="$REPO_ROOT/$rel"
    [[ -f "$file" ]] || continue

    # Named unbalanced-marker diagnostic (additive): when a file's own task-ref-ok marker parse
    # is invalid (an unterminated begin, or a stray end), name it explicitly here rather than
    # letting the operator discover it only as a sudden pile of unrelated citation findings from
    # the now-unexempt trailing span -- marker_balance_report is silent on a well-formed parse,
    # so this never fires on the ordinary case.
    local balance_report
    balance_report="$(marker_balance_report < "$file" 2>/dev/null)" || true
    if [[ -n "$balance_report" ]]; then
      count=$((count + 1))
      info "  UNBALANCED MARKER in $rel: $balance_report"
    fi

    local finding
    while IFS= read -r finding; do
      [[ -z "$finding" ]] && continue
      count=$((count + 1))
      info "  $rel:$finding"
    done < <(strip_exempt_regions < "$file" | grep -nEi "$PHASE_PATTERN|$TASK_PATTERN" 2>/dev/null)
  done <<< "$enum_output"

  SCAN_COUNT="$count"
}

if [[ -n "$PATH_SCOPE" ]]; then
  LABEL="$PATH_SCOPE"
  info "Scanning $PATH_SCOPE ..."
  scan_tree "$LABEL" "$PATH_SCOPE"
  info ""
else
  LABEL="repo (excluding specs/)"
  info "Scanning $LABEL ..."
  scan_tree "$LABEL" "."
  info ""
fi

TOTAL="$SCAN_COUNT"
echo "  $LABEL: $TOTAL occurrence(s)"

if [[ "$TOTAL" -gt 0 ]]; then
  echo "FAIL: $TOTAL unexempted task-reference occurrence(s) found"
  exit 1
else
  echo "PASS: 0 unexempted task-reference occurrences"
  exit 0
fi
