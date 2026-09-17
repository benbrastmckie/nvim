#!/usr/bin/env bash
# lint-json-channel-discipline.sh - Detect the channel-confusion defect class this task fixes:
# a single process stream carrying two meanings (JSON/NDJSON payload data AND human-readable
# diagnostic prose) at once. Two independent directions, both covered:
#
#   INGEST: a collaborator is captured with `2>&1` (folding its stderr diagnostics into the
#     captured value), and that captured value is later consumed as raw JSON/NDJSON data -- via
#     a `jq` pipe (`echo "$var" | jq ...`) or a here-string (`jq ... <<< "$var"`, or a
#     `while read` loop directly fed by `done <<< "$var"`). This is the MORE dangerous shape:
#     the collaborator can still exit 0, so a degraded-path warning never fires and the caller
#     silently ingests a garbage row while reporting success. The historical instance this
#     detector was built against needed three authoring iterations before it correctly caught
#     the `while read` here-string shape -- keep that shape covered; do not regress to jq-pipe
#     detection alone. A `while read` loop fed instead through an intermediate
#     `< <(cmd | grep ...)` process substitution is deliberately NOT flagged: only lines that
#     already survived a filter reach the loop, a fundamentally lower-risk shape (this is what
#     keeps verify-deploy.sh's nine structurally-similar `*_lint_output` while-read blocks from
#     needing their own allowlist entries -- only the one that feeds a here-string directly
#     does).
#
#   EMIT: a script whose own header declares a JSON-on-stdout output contract, but which
#     contains an unredirected `echo`/`printf`/heredoc write that is neither `>&2` (diagnostic),
#     `>&3` (the structural fd-3 data channel -- see orchestrate-cycle-plan.sh's own header for
#     that mechanism's full contract), nor inside a `$(...)` capture (whose own subshell rebinds
#     fd 1 privately, so it cannot leak into the caller's stdout regardless).
#
# Usage: lint-json-channel-discipline.sh [--verbose] [path...]
#   With no paths, scans every non-test *.sh under agent-system/extensions/ (test-*.sh files are
#   fixtures/harnesses, not the shipped scripts this class of defect targets).
#
# Known limitations (heuristic, not a real parser): the INGEST check only recognizes a
# SINGLE-LINE `var=$(... 2>&1 ...)` capture assignment -- a command substitution whose `2>&1`
# lives on a different line than its `var=$(` opener is not detected. The EMIT check's
# "inside a $(...) capture" exclusion is a simple same-line `$(` substring test, not real paren
# balancing. Both are the same techniques validated by hand during this lint's own authoring
# task and by the fixture suite alongside this script; they are deliberately simple enough to
# stay maintainable, at the cost of not catching every conceivable multi-line variant.
#
# Exit codes:
#   0 - No violations found (allowlisted matches do not count as violations)
#   1 - Violations found
#   2 - Script error (jq unavailable is NOT a requirement of this script; only argument/glob
#       failures reach this code)
#
# Gate wiring (deliberately NOT done here): this lint is NOT wired into verify-deploy.sh as an
# explicit numbered gate, by design -- verify-deploy.sh is owned by a separate, cross-referenced
# redeploy-checkpoint task and is out of scope for the task that authored this lint. It already
# runs inside the full gate set today, indirectly: `scripts/tests/run-all.sh` auto-discovers
# every `scripts/tests/test-*.sh` suite (including this lint's own
# test-lint-json-channel-discipline.sh), and `run-all.sh` itself is verify-deploy.sh's Gate 8.
# Adding this lint as its OWN separately-numbered gate (matching the eight sibling `lint-*.sh`
# scripts that verify-deploy.sh does invoke directly, e.g. `lint-agent-contracts.sh` at its
# Gate for agent contracts) is a real, recorded follow-up for whoever next owns
# verify-deploy.sh -- not performed here.

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERBOSE=false
TARGET_PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v) VERBOSE=true; shift ;;
    *) TARGET_PATHS+=("$1"); shift ;;
  esac
done

# ── Root resolution (mirrors lint-agent-contracts.sh's own convention, not the
# scripts/-depth-specific deploy-root-guard.sh one used by scripts/*.sh): `git rev-parse
# --show-toplevel` first (falling back to a REPO_ROOT env override honored first, then to a
# script-relative default) -- this script lives at scripts/lint/ and is designed to run
# identically from either the deployed .claude/scripts/lint/ copy or directly from the
# agent-system/extensions/core/scripts/lint/ source-store copy (read-only, so there is no
# destructive-write risk deploy-root-guard.sh's block would need to guard against).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-}"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

if [[ ${#TARGET_PATHS[@]} -eq 0 ]]; then
  # Excludes test fixtures/harnesses in BOTH shapes run-all.sh itself discovers (see that
  # script's own header): narrow suites under a tests/ subdirectory (scripts/tests/test-*.sh)
  # and broad/flat suites living directly alongside the shipped scripts (scripts/test-*.sh) --
  # a basename-only match, so either shape is excluded regardless of its parent directory.
  mapfile -t TARGET_PATHS < <(find "$REPO_ROOT/agent-system/extensions" -name '*.sh' -type f 2>/dev/null \
    | grep -vE '/test-[^/]*\.sh$' \
    | sort)
fi

# ── Allowlist: known false positives, each with an inline, checked-in reason (never just a bare
# path -- the reason is the point, so a future reader does not have to re-derive it). Keyed
# "basename:varname" for the INGEST list.
declare -A ALLOWLIST_INGEST=(
  ["verify-deploy.sh:doc_lint_output"]="parses human-readable lint text (\"[header]\" / \"  FAIL:\" prefixes), not JSON -- merging stderr there is intentional, not a bug."
)

VIOLATIONS=0
FILES_CHECKED=0

# ── INGEST direction ─────────────────────────────────────────────────────────────────────────
check_ingest() {
  local file="$1" base found=0
  base="$(basename "$file")"

  local varnames
  varnames=$(grep -noE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=\$\([^()]*2>&1[^()]*\)' "$file" 2>/dev/null \
    | sed -E 's/^[0-9]+:[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=.*/\1/' \
    | sort -u)
  [ -z "$varnames" ] && return 0

  while IFS= read -r var; do
    [ -z "$var" ] && continue

    if [ -n "${ALLOWLIST_INGEST[${base}:${var}]:-}" ]; then
      $VERBOSE && echo "  [ALLOWLIST] $file: \$$var -- ${ALLOWLIST_INGEST[${base}:${var}]}"
      continue
    fi

    local jq_pipe_hit=false herestring_hit=false
    grep -qE "(echo|printf)[^|]*\\\$\{?${var}\}?[^|]*\\|[[:space:]]*jq" "$file" 2>/dev/null && jq_pipe_hit=true

    # A here-string consumption of $var is flagged whether it feeds jq directly
    # (`jq ... <<< "$var"`) or feeds a `while read` loop (`done <<< "$var"`) -- both treat the
    # raw, unfiltered capture as line-oriented/JSON data. A while-read fed through an
    # intermediate `< <(cmd | grep ...)` process substitution is a fundamentally different,
    # lower-risk shape instead: only lines that already survived a filter reach the loop at all
    # (verify-deploy.sh's nine `*_lint_output` blocks are exactly this --
    # `done < <(printf '%s\n' "$foo_lint_output" | grep -F '[FAIL]')`), so that shape is never
    # flagged here without its own per-script allowlist entry.
    grep -qE "<<<[[:space:]]*\"?\\\$\{?${var}\}?\"?" "$file" 2>/dev/null && herestring_hit=true

    if $jq_pipe_hit || $herestring_hit; then
      local shape="jq pipe"
      $herestring_hit && shape="here-string (jq or while-read NDJSON)"
      echo -e "${RED}[VIOLATION]${NC} $file: \$$var captured with 2>&1, then consumed as JSON/NDJSON ($shape) -- the collaborator's stderr can corrupt the payload"
      found=$((found + 1))
    fi
  done <<< "$varnames"

  return "$found"
}

# ── EMIT direction ───────────────────────────────────────────────────────────────────────────
# Two different mechanisms protect the emit direction across this codebase, and this lint checks
# each with the matching technique -- checking every script the SAME way would either miss a
# real regression or drown in false positives:
#
#   STRUCTURAL (orchestrate-cycle-plan.sh, orchestrate-cycle-postflight.sh): an entry-point
#     `exec 3>&1 1>&2` redirect makes plain, unredirected stdout (fd 1) route to stderr for the
#     REST OF THE PROCESS'S LIFE -- every other echo/printf/heredoc in the file is therefore
#     already safe by construction, redirected or not, and a per-line audit would just be
#     re-deriving that guarantee one line at a time (and, worse, false-positriing on the many
#     legitimate bare `echo`s these files contain in helper functions whose callers capture them
#     via `$(...)`). The only thing worth checking here is that the structural redirect itself
#     is still present -- if it is ever removed, EVERY line in the file reverts to needing its
#     own individual `>&2`, silently, with no per-line signal marking the regression.
#   PER-LINE (orchestrate-batch-admit.sh, orchestrate-triage-classify.sh): these do NOT carry
#     the structural redirect -- their correctness depends on every diagnostic individually
#     being `>&2`, with exactly ONE unredirected emit (their own final verdict print) at the very
#     end. A per-line audit is the right tool here, with a specific, load-bearing exemption: a
#     lone surviving unredirected match, when there is EXACTLY one in the whole file, IS that
#     legitimate final emit, not a violation -- two or more is itself the regression signal
#     (this contract promises exactly one emission point; a second one is either a duplicate or
#     the sign of a genuinely new leak).
#
# Sibling scripts like orchestrate-build-aux-dispatch.sh are out of scope for EITHER mechanism:
# they serve a fundamentally different purpose (writing a dispatch FILE's content via
# heredoc/redirect, not emitting a single JSON verdict on their own stdout).

EMIT_STRUCTURAL_FILES=("orchestrate-cycle-plan.sh" "orchestrate-cycle-postflight.sh")
EMIT_PERLINE_FILES=("orchestrate-batch-admit.sh" "orchestrate-triage-classify.sh")

check_emit_structural() {
  local file="$1"
  if grep -qE '^\s*exec\s+3>&1(\s+1>&2)?\s*$' "$file" 2>/dev/null; then
    return 0
  fi
  echo -e "${RED}[VIOLATION]${NC} $file: expected the entry-point \`exec 3>&1 1>&2\` structural redirect (declares a JSON-on-stdout contract but the redirect that makes it safe is missing or was altered) -- every echo/printf in this file now needs its own individual >&2 again"
  return 1
}

check_emit_perline() {
  local file="$1" found=0

  # Collect every candidate unredirected-write line first (deferred reporting, so the
  # "exactly one surviving match is the legitimate final emit" exemption can be applied before
  # anything is printed).
  local matches=()
  while IFS=: read -r lineno content; do
    [ -z "$lineno" ] && continue
    case "$content" in
      *'printf -v'*) continue ;;  # writes into a variable, not stdout, regardless of "printf "
    esac
    matches+=("${lineno}:${content}")
  # The final grep excludes a redirect to a variable-named target (e.g. `> "$var"` or a
  # mktemp-held path): that is a file write, not a stdout write, so it is not a JSON-channel
  # discipline violation regardless of this file's stdout contract.
  done < <(grep -nE 'echo |printf |cat <<' "$file" 2>/dev/null \
    | grep -v '>&2' | grep -v '>&3' | grep -v '\$(' | grep -v '^\s*[0-9]*:\s*#' \
    | grep -vE '>[[:space:]]*"?\$\{?[A-Za-z_]')

  if [ "${#matches[@]}" -eq 1 ]; then
    $VERBOSE && echo "  [OK] $file: exactly one unredirected write -- treated as the legitimate final emit: ${matches[0]}"
    return 0
  fi

  for m in "${matches[@]}"; do
    echo -e "${RED}[VIOLATION]${NC} $file:${m%%:*}: unredirected stdout write in a script whose header declares a JSON-on-stdout contract:${m#*:}"
    found=$((found + 1))
  done
  return "$found"
}

check_emit() {
  local file="$1" base
  base="$(basename "$file")"

  local f
  for f in "${EMIT_STRUCTURAL_FILES[@]}"; do
    [ "$base" = "$f" ] && { check_emit_structural "$file"; return $?; }
  done
  for f in "${EMIT_PERLINE_FILES[@]}"; do
    [ "$base" = "$f" ] && { check_emit_perline "$file"; return $?; }
  done
  return 0
}

echo "Checking JSON/NDJSON channel discipline (INGEST + EMIT)..."
echo ""

for f in "${TARGET_PATHS[@]}"; do
  [[ ! -f "$f" ]] && continue
  FILES_CHECKED=$((FILES_CHECKED + 1))
  $VERBOSE && echo "Checking: $f"

  set +e
  check_ingest "$f"
  ingest_hits=$?
  check_emit "$f"
  emit_hits=$?
  set -e

  VIOLATIONS=$((VIOLATIONS + ingest_hits + emit_hits))
  if [ "$ingest_hits" -eq 0 ] && [ "$emit_hits" -eq 0 ]; then
    $VERBOSE && echo -e "${GREEN}[PASS]${NC} $f"
  fi
done

echo ""
echo "================================"
echo "JSON Channel Discipline Summary"
echo "================================"
echo "Files checked: $FILES_CHECKED"
echo "Total violations: $VIOLATIONS"

if [ "$VIOLATIONS" -eq 0 ]; then
  echo -e "${GREEN}No channel-discipline violations found.${NC}"
  exit 0
else
  echo -e "${RED}Found $VIOLATIONS violation(s). See above for details.${NC}"
  exit 1
fi
