#!/usr/bin/env bash
# check-record-versioning.sh
#
# Repo-wide lint gate for rules/no-record-versioning-in-deliverables.md: scans the UNION of
# every git-tracked file and every untracked-but-not-gitignored file in the repository (via the
# shared scripts/lib/git-corpus-enum-lib.sh enumeration, so gitignored/vendored/generated paths
# stay excluded by construction while a file that merely has not been `git add`ed yet is still
# scanned) EXCEPT specs/** for unexempted record-versioning language, using the SAME shared
# pattern/exemption/tiering library the write-time guard hook consumes
# (scripts/lib/record-version-patterns.sh). Neither this script nor the hook defines a detection
# pattern, an axis-discrimination rule, or a BLOCKING/ADVISORY tier locally -- see that library
# and context/standards/record-version-exemptions.md's "Exemption Taxonomy" and "Forbidden
# Categories and Tiers" sections (companion to rules/no-record-versioning-in-deliverables.md) for
# the single source of truth both consume.
#
# UNTRACKED-INCLUSION: a bare `git ls-files PATH_SCOPE` enumeration returns zero rows for a file
# that exists on disk but is not yet git-tracked, even though an `-e` existence guard on the path
# itself still passes -- the scan then silently iterates zero times and reports a clean verdict
# for a file it never examined. git-corpus-enum-lib.sh's `git_corpus_enum` closes this by
# enumerating the tracked-plus-untracked union (still excluding gitignored content via
# `--exclude-standard`), and this script additionally emits three stderr-only diagnostics so
# "clean" and "not examined" can never be confused: an untracked-inclusion count when any
# untracked file was folded into the scan, a per-file `[SKIP] ...: gitignored (not scanned)` line
# for every on-disk file a `PATH_SCOPE` scan still excludes, and a zero-enumeration notice when a
# `PATH_SCOPE` exists on disk but the union enumerates nothing. All three are stderr-only and
# never routed through `info()`, so `--quiet` cannot suppress them.
#
# The scan is repo-appropriate by construction: it does not hard-code this repo's own directory
# layout (agent-system/extensions, .opencode, lua, .memory), so a consumer repo with a different
# source-tree layout (docs/, README.md, a language-specific source dir, etc.) is scanned in full
# rather than scanning nothing. `specs/**` is the one path-level exemption (task-management
# artifacts) and is skipped via is_exempt_path, matching the taxonomy's category 1.
#
# TWO-TIER CONTRACT (the one genuinely new surface versus the check-task-references.sh sibling):
# a BLOCKING finding drives this script's exit code; an ADVISORY finding is reported and counted
# but NEVER affects exit status. Both counts are always printed in the Summary block, even when
# one or both are zero. The tier for each finding is consumed verbatim from the library's own
# `rv_grep_blocking`/`rv_grep_advisory` matching functions -- this script does not re-classify or
# re-derive a tier of its own.
#
# Exit codes:
#   0 - zero BLOCKING findings in the scanned scope (an ADVISORY-only result still exits 0, with
#       the advisory count stated in the pass message).
#   1 - one or more BLOCKING findings found.
#   2 - environment/usage error (shared library missing, git unavailable, unknown flag).
#       Distinct from 1 so a broken script invocation is never mistaken for a clean tree.
#
# Usage:
#   bash .claude/scripts/check-record-versioning.sh              (verbose: prints every finding)
#   bash .claude/scripts/check-record-versioning.sh --quiet       (summary only)
#   bash .claude/scripts/check-record-versioning.sh [--quiet] PATH_SCOPE
#       (scope the scan to a subtree or a single file anywhere in the repo, e.g.
#       agent-system/extensions/core/context or docs/README.md -- reports and exits on findings
#       under PATH_SCOPE only. Any in-repo path is scannable; a PATH_SCOPE naming a path that does
#       not exist prints a [SKIP] line and exits 0 rather than erroring. The no-argument and
#       --quiet-only forms are UNCHANGED in shape: same exit codes, same per-finding line format.
#       An on-disk-but-untracked file under PATH_SCOPE is scanned on its merits (not silently
#       skipped); a still-excluded gitignored file under PATH_SCOPE is named on stderr by a
#       `[SKIP] <path>: gitignored (not scanned)` line rather than passing in silence, and a
#       PATH_SCOPE that enumerates nothing at all gets its own stderr notice saying so.)
#   REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-record-versioning.sh
#       (source-store invocation override -- see check-task-references.sh for the same pattern;
#       required because .claude/scripts/check-record-versioning.sh does not exist until a
#       deploy runs)

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
# Same convention as check-task-references.sh: deploy-root-guard.sh enforces that the computed
# default (SCRIPT_DIR/../..) only resolves from a real deploy tree; a deliberate source-store
# invocation MUST pass REPO_ROOT=$(pwd) explicitly, which bypasses the guard below.
[[ -n "${REPO_ROOT:-}" ]] || . "$(dirname "${BASH_SOURCE[0]}")/deploy-root-guard.sh" || exit 2
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Degrade-safe guarded source (context/patterns/regeneration-is-manual-only.md's "Redeploy-Remedy
# Emission Sites" subsection, Decision 1(c)): a missing lib falls back to a no-op fragment rather
# than a source-time failure. Sibling-lib-relative only (this script's own directory), not
# REPO_ROOT-based, so it resolves identically regardless of a REPO_ROOT=$(pwd) override above.
_RR_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/redeploy-remedy-lib.sh"
# shellcheck source=lib/redeploy-remedy-lib.sh
[ -f "$_RR_LIB" ] && . "$_RR_LIB"
declare -F redeploy_remedy_fragment >/dev/null 2>&1 || redeploy_remedy_fragment() { printf '%s' ""; }

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required and is not on PATH" >&2
  exit 2
fi

# ── Shared library ───────────────────────────────────────────────────────────────────────────
# Sourced from the deployed location first (the ordinary runtime case), falling back to the
# source-store location for REPO_ROOT=$(pwd) source-store invocations where no deploy has
# happened yet. No patterns, exemption logic, or tiering are defined here -- if the library
# cannot be found, this is an environment error (exit 2), never a silent fall-through to an
# inline pattern.
LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/record-version-patterns.sh"
  "$REPO_ROOT/agent-system/extensions/core/scripts/lib/record-version-patterns.sh"
)
LIB=""
for candidate in "${LIB_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    LIB="$candidate"
    break
  fi
done
if [[ -z "$LIB" ]]; then
  echo "ERROR: shared library record-version-patterns.sh not found at any of:" >&2
  for candidate in "${LIB_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi
# shellcheck disable=SC1090
. "$LIB"

# A library found at a candidate path but missing an expected function is a DIFFERENT
# environment error than "not found" above, with the same severity: a stale/pre-two-tier-split
# library (lacking rv_grep_blocking/rv_grep_advisory/rv_is_markdown_path, added after this
# script was wired to consume them) would otherwise fail SILENTLY -- `rv_grep_blocking` as an
# undefined command exits 127 under a pipeline whose stderr this script redirects to
# /dev/null, so the scan loop below simply never iterates and the whole run falsely reports a
# clean 0 BLOCKING / 0 ADVISORY PASS instead of the loud failure an incompatible library
# deserves. Checked explicitly here, once, rather than left to surface as a confusing false
# green.
for required_fn in is_exempt_path strip_durable_axis_lines strip_exempt_regions \
                   rv_grep_blocking rv_grep_advisory; do
  if ! declare -F "$required_fn" >/dev/null 2>&1; then
    echo "ERROR: library at $LIB is missing required function '$required_fn' -- stale or" >&2
    echo "       incompatible version (expected the two-tier rv_grep_blocking/rv_grep_advisory" >&2
    echo "       matching API). Redeploy core, or point REPO_ROOT at a tree whose deployed" >&2
    echo "       library is current." >&2
    echo "       $(redeploy_remedy_fragment)" >&2
    exit 2
  fi
done

# ── Shared corpus-enumeration library ────────────────────────────────────────────────────────
# Same not-found/stale-library severity as the record-version-patterns.sh block above: a
# missing or stale git-corpus-enum-lib.sh must fail loudly (exit 2), never silently fall back to
# the bare `git ls-files` enumeration this library exists to replace -- that silent fallback IS
# the defect this script was fixed to stop reproducing.
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

for required_fn in git_corpus_enum git_corpus_unenumerated_report git_corpus_untracked_count; do
  if ! declare -F "$required_fn" >/dev/null 2>&1; then
    echo "ERROR: library at $CORPUS_LIB is missing required function '$required_fn' -- stale" >&2
    echo "       or incompatible version. Redeploy core, or point REPO_ROOT at a tree whose" >&2
    echo "       deployed library is current." >&2
    echo "       $(redeploy_remedy_fragment)" >&2
    exit 2
  fi
done

info() { [[ $QUIET -eq 0 ]] && echo "$@"; }

# SCAN_BLOCKING / SCAN_ADVISORY are set (not echoed) by scan_tree, and scan_tree is always
# invoked directly (never inside a command substitution) so its info() finding lines reach real
# stdout rather than being captured as part of a subshell's output.
SCAN_BLOCKING=0
SCAN_ADVISORY=0

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
  local blocking_count=0
  local advisory_count=0

  if [[ ! -e "$enum_dir" ]]; then
    info "  [SKIP] $label does not exist under $REPO_ROOT"
    SCAN_BLOCKING=0
    SCAN_ADVISORY=0
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

  local file rel stripped
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue

    if is_exempt_path "$rel"; then
      continue
    fi

    file="$REPO_ROOT/$rel"
    [[ -f "$file" ]] || continue

    # Stripped once per file, per the library's documented Usage order, and reused for both the
    # BLOCKING and the ADVISORY pass below -- neither pass re-derives its own stripped content.
    stripped="$(strip_durable_axis_lines < "$file" | strip_exempt_regions)"

    local finding lineno content
    while IFS= read -r finding; do
      [[ -z "$finding" ]] && continue
      blocking_count=$((blocking_count + 1))
      lineno="${finding%%:*}"
      content="${finding#*:}"
      info "  $rel:$lineno: BLOCKING: $content"
    done < <(printf '%s\n' "$stripped" | rv_grep_blocking "$rel" 2>/dev/null)

    while IFS= read -r finding; do
      [[ -z "$finding" ]] && continue
      advisory_count=$((advisory_count + 1))
      lineno="${finding%%:*}"
      content="${finding#*:}"
      info "  $rel:$lineno: ADVISORY: $content"
    done < <(printf '%s\n' "$stripped" | rv_grep_advisory "$rel" 2>/dev/null)
  done <<< "$enum_output"

  SCAN_BLOCKING="$blocking_count"
  SCAN_ADVISORY="$advisory_count"
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

TOTAL_BLOCKING="$SCAN_BLOCKING"
TOTAL_ADVISORY="$SCAN_ADVISORY"
echo "  $LABEL: $TOTAL_BLOCKING BLOCKING, $TOTAL_ADVISORY ADVISORY"

if [[ "$TOTAL_BLOCKING" -gt 0 ]]; then
  echo "FAIL: $TOTAL_BLOCKING BLOCKING record-versioning occurrence(s) found ($TOTAL_ADVISORY advisory)"
  exit 1
elif [[ "$TOTAL_ADVISORY" -gt 0 ]]; then
  echo "PASSED WITH WARNINGS ($TOTAL_ADVISORY advisory finding(s))"
  exit 0
else
  echo "PASS: 0 unexempted record-versioning occurrences"
  exit 0
fi
