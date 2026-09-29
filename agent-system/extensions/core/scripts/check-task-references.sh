#!/usr/bin/env bash
# check-task-references.sh
#
# Repo-wide lint gate for rules/no-task-references-in-deliverables.md: scans every git-tracked
# file in the repository (via `git ls-files`, so gitignored/vendored/generated paths are excluded
# by construction) EXCEPT specs/** for unexempted task-number citations, using the SAME shared
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
# rather than scanning nothing. `specs/**` is the one path-level exemption (task-management
# artifacts) and is skipped via is_exempt_path, matching the taxonomy's category 1.
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
#       --quiet-only forms are UNCHANGED in shape: same exit codes, same per-finding line format.)
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

FAILURES=0
info() { [[ $QUIET -eq 0 ]] && echo "$@"; }

# SCAN_COUNT is set (not echoed) by scan_tree, and scan_tree is always invoked directly (never
# inside a command substitution) so its info() finding lines reach real stdout rather than being
# captured as part of a subshell's output.
SCAN_COUNT=0

# scan_tree <label> <enum_path>
# <label> names the scanned scope for reporting; <enum_path> is what is actually passed to
# `git ls-files` for enumeration, relative to REPO_ROOT. "." enumerates the whole repository (the
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

  local file rel
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue

    if is_exempt_path "$rel"; then
      continue
    fi

    file="$REPO_ROOT/$rel"
    [[ -f "$file" ]] || continue

    local finding
    while IFS= read -r finding; do
      [[ -z "$finding" ]] && continue
      count=$((count + 1))
      info "  $rel:$finding"
    done < <(strip_exempt_regions < "$file" | grep -nEi "$PHASE_PATTERN|$TASK_PATTERN" 2>/dev/null)
  done < <(git -C "$REPO_ROOT" ls-files "$enum_path" 2>/dev/null)

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
