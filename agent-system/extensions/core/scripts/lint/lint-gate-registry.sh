#!/usr/bin/env bash
# lint-gate-registry.sh - Structural validation for scripts/gate-registry.data, the declarative
# registry verify-deploy.sh's migrated gates (currently 1-8; Phase 5 adds 9-23) are driven from.
#
# Checks:
#   A. Every row's `invoke` field names a function that is actually DEFINED somewhere in
#      verify-deploy.sh (a registry row pointing at a function that does not exist would be a
#      silent no-op at runtime -- gate_registry_execute degrades quietly rather than erroring, so
#      this lint is the only place that catches it).
#   B. Every declared dependency id (comma-separated in the `dependencies` field, `-` meaning
#      none) refers to another id that actually EXISTS in the registry.
#   C. No dependency CYCLE exists (DFS-based cycle detection across the declared dependency
#      graph).
#   D. Every row has a non-empty, well-formed `timeout_s` (a positive integer) and `cost_class`
#      (one of free/moderate/slow).
#   E. Every id is UNIQUE and the full id set is CONTIGUOUS starting at 1 (1..N with no gaps) --
#      a gap or duplicate would silently strand a gate from the `gate_registry_ids` iteration
#      loop or double-execute one.
#   F. Every row has exactly 9 TAB-separated fields (8 tabs) -- a legacy 8-field row read by the
#      now-9-field loader would silently shift `serialized` into `input_corpus`'s column and
#      leave `input_corpus` itself unset, rather than failing loudly. Checked on the RAW line
#      (tab count), independent of what `read` happens to populate.
#   G. Every row's `input_corpus` field is either the bare placeholder `-` or a comma-separated
#      list of entries, each matching one of the grammar shapes gate-registry.data's own
#      `input_corpus` header documents (a named view `@extensions`/`@repo`, a path, a glob, or a
#      `!`-prefixed exclusion of one of those). A genuinely empty field (neither `-` nor a
#      parseable list) is rejected -- the placeholder means "not declared, never skippable", not
#      "no inputs", so blank is never a silent synonym for it.
#
# Usage: lint-gate-registry.sh [--verbose] [--help] [DATA_FILE]
#
# Exit codes:
#   0 - all checks pass
#   1 - one or more checks failed
#   2 - environment/usage error (data file or verify-deploy.sh not found, unknown argument)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

VERBOSE=false
DATA_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --verbose|-v) VERBOSE=true; shift ;;
    --help|-h)
      sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "Unknown argument: $1. Use --help for usage." >&2
      exit 2
      ;;
    *)
      DATA_FILE="$1"; shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
: "${DATA_FILE:=${CORE_DIR}/gate-registry.data}"
VERIFY_DEPLOY="${CORE_DIR}/verify-deploy.sh"

if [ ! -f "$DATA_FILE" ]; then
  echo "ERROR: gate registry data file not found: $DATA_FILE" >&2
  exit 2
fi
if [ ! -f "$VERIFY_DEPLOY" ]; then
  echo "ERROR: verify-deploy.sh not found: $VERIFY_DEPLOY" >&2
  exit 2
fi

PASSED=0
FAILED=0
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=$((FAILED + 1)); }
log_info() { $VERBOSE && echo -e "${BLUE}[INFO]${NC} $1" || true; }

declare -A LINT_NAME=() LINT_INVOKE=() LINT_DEPS=() LINT_RSS=() LINT_TIMEOUT=() LINT_CLASS=() LINT_SER=() LINT_CORPUS=()
LINT_IDS=()
field_count_failed=0

while IFS=$'\t' read -r id name invoke deps rss timeout_s class ser corpus; do
  case "$id" in
    ''|'#'*) continue ;;
  esac
  case "$id" in
    ''|*[!0-9]*)
      log_fail "malformed id (not a plain integer): '$id'"
      continue
      ;;
  esac
  if [ -n "${LINT_NAME[$id]+x}" ]; then
    log_fail "duplicate gate id: $id"
  fi
  [ "$deps" = "-" ] && deps=""
  LINT_NAME["$id"]="$name"
  LINT_INVOKE["$id"]="$invoke"
  LINT_DEPS["$id"]="$deps"
  LINT_RSS["$id"]="$rss"
  LINT_TIMEOUT["$id"]="$timeout_s"
  LINT_CLASS["$id"]="$class"
  LINT_SER["$id"]="$ser"
  LINT_CORPUS["$id"]="$corpus"
  LINT_IDS+=("$id")
done < "$DATA_FILE"

# Check F (field count), done as a second pass directly against the raw file -- `read`'s own
# behavior on a short/long row is not a reliable signal (a short row just leaves later bash
# variables empty; a long row folds the remainder into the LAST variable), so this counts each
# data row's own tab characters directly instead of inferring from what `read` populated.
while IFS= read -r raw_line; do
  case "$raw_line" in
    ''|'#'*) continue ;;
  esac
  raw_id="${raw_line%%$'\t'*}"
  case "$raw_id" in
    ''|*[!0-9]*) continue ;;  # already reported as a malformed id above
  esac
  tab_count=$(awk -F'\t' '{print NF-1}' <<< "$raw_line")
  if [ "$tab_count" -ne 8 ]; then
    log_fail "gate $raw_id: row has $tab_count tab(s), expected exactly 8 (9 fields) -- a legacy 8-field row would silently shift 'serialized' into 'input_corpus' under the current loader"
    field_count_failed=1
  fi
done < "$DATA_FILE"
[ "$field_count_failed" -eq 0 ] && log_pass "every row has exactly 9 TAB-separated fields"

if [ "${#LINT_IDS[@]}" -eq 0 ]; then
  log_fail "no gate rows parsed from $DATA_FILE -- empty or entirely comments?"
  echo ""
  echo "Results: $PASSED passed, $FAILED failed"
  exit 1
fi

# ── Check A: every invoke function is actually defined in verify-deploy.sh ────────────────────
for id in "${LINT_IDS[@]}"; do
  invoke="${LINT_INVOKE[$id]}"
  if [ -z "$invoke" ]; then
    log_fail "gate $id: empty invoke field"
    continue
  fi
  if grep -qE "^${invoke}\(\) \{" "$VERIFY_DEPLOY"; then
    log_info "gate $id: invoke function '$invoke' is defined"
  else
    log_fail "gate $id: invoke function '$invoke' is NOT defined in $(basename "$VERIFY_DEPLOY")"
  fi
done
if [ "$FAILED" -eq 0 ]; then
  log_pass "every gate's invoke function is defined in verify-deploy.sh"
fi

# ── Check B: every declared dependency id exists in the registry ──────────────────────────────
dep_check_failed=0
for id in "${LINT_IDS[@]}"; do
  deps="${LINT_DEPS[$id]}"
  [ -z "$deps" ] && continue
  IFS=',' read -r -a dep_ids <<< "$deps"
  for dep_id in "${dep_ids[@]}"; do
    if [ -z "${LINT_NAME[$dep_id]+x}" ]; then
      log_fail "gate $id: declared dependency '$dep_id' does not exist in the registry"
      dep_check_failed=1
    fi
  done
done
[ "$dep_check_failed" -eq 0 ] && log_pass "every declared dependency id exists in the registry"

# ── Check C: no dependency cycle ───────────────────────────────────────────────────────────────
declare -A VISIT_STATE=()  # unset=white, 1=gray (in progress), 2=black (done)
CYCLE_FOUND=""

dfs_visit() {
  local node="$1" path="$2" deps dep_ids dep_id
  case "${VISIT_STATE[$node]:-}" in
    1) CYCLE_FOUND="${path} -> ${node}"; return 0 ;;
    2) return 0 ;;
  esac
  VISIT_STATE["$node"]=1
  deps="${LINT_DEPS[$node]:-}"
  if [ -n "$deps" ]; then
    IFS=',' read -r -a dep_ids <<< "$deps"
    for dep_id in "${dep_ids[@]}"; do
      [ -n "${LINT_NAME[$dep_id]+x}" ] || continue  # Check B already reported this
      dfs_visit "$dep_id" "${path} -> ${node}"
      [ -n "$CYCLE_FOUND" ] && return 0
    done
  fi
  VISIT_STATE["$node"]=2
}

for id in "${LINT_IDS[@]}"; do
  [ -n "$CYCLE_FOUND" ] && break
  [ "${VISIT_STATE[$id]:-}" = "2" ] && continue
  dfs_visit "$id" "start"
done

if [ -n "$CYCLE_FOUND" ]; then
  log_fail "dependency cycle detected: $CYCLE_FOUND"
else
  log_pass "no dependency cycle in the registry's declared dependency graph"
fi

# ── Check D: every row has a well-formed timeout_s and cost_class ─────────────────────────────
d_failed=0
for id in "${LINT_IDS[@]}"; do
  timeout_s="${LINT_TIMEOUT[$id]}"
  class="${LINT_CLASS[$id]}"
  case "$timeout_s" in
    ''|*[!0-9]*)
      log_fail "gate $id: timeout_s is not a positive integer: '$timeout_s'"
      d_failed=1
      ;;
    0)
      log_fail "gate $id: timeout_s must be > 0, got 0"
      d_failed=1
      ;;
  esac
  case "$class" in
    free|moderate|slow) : ;;
    *)
      log_fail "gate $id: cost_class must be one of free/moderate/slow, got '$class'"
      d_failed=1
      ;;
  esac
  rss="${LINT_RSS[$id]}"
  case "$rss" in
    true|false) : ;;
    *)
      log_fail "gate $id: requires_source_store must be exactly 'true' or 'false', got '$rss'"
      d_failed=1
      ;;
  esac
  ser="${LINT_SER[$id]}"
  case "$ser" in
    true|false) : ;;
    *)
      log_fail "gate $id: serialized must be exactly 'true' or 'false', got '$ser'"
      d_failed=1
      ;;
  esac
done
[ "$d_failed" -eq 0 ] && log_pass "every gate has a well-formed timeout_s, cost_class, requires_source_store, and serialized field"

# ── Check E: ids unique (duplicates already caught above) and contiguous starting at 1 ────────
mapfile -t sorted_ids < <(printf '%s\n' "${LINT_IDS[@]}" | sort -n -u)
contiguous_ok=true
expected=1
for id in "${sorted_ids[@]}"; do
  if [ "$id" != "$expected" ]; then
    contiguous_ok=false
    log_fail "gate id sequence is not contiguous starting at 1: expected $expected, found $id"
    break
  fi
  expected=$((expected + 1))
done
$contiguous_ok && log_pass "gate id sequence is contiguous: 1..${#sorted_ids[@]}"

# ── Check G: every row's input_corpus is '-' or a comma-separated list of grammar-conformant
# entries (see gate-registry.data's own input_corpus header comment for the authoritative
# grammar). A genuinely empty field is rejected: '-' is the only accepted "not declared" spelling.
# Entry shapes accepted: '@extensions', '@repo' (named views); a bare path/directory/glob
# (letters, digits, '_', '.', '/', '*', '?', '[', ']', '-'); any of those prefixed with '!' for
# exclusion.
g_failed=0
corpus_entry_re='^!?(@extensions|@repo|[[:alnum:]_.*][][:alnum:]_./*?-]*)$'
for id in "${LINT_IDS[@]}"; do
  corpus="${LINT_CORPUS[$id]:-}"
  if [ -z "$corpus" ]; then
    log_fail "gate $id: input_corpus is empty -- use the '-' placeholder for 'not declared, never skippable', never a blank field"
    g_failed=1
    continue
  fi
  [ "$corpus" = "-" ] && continue
  IFS=',' read -r -a corpus_entries <<< "$corpus"
  for entry in "${corpus_entries[@]}"; do
    if [ -z "$entry" ]; then
      log_fail "gate $id: input_corpus '$corpus' has an empty entry (double comma or trailing comma)"
      g_failed=1
      continue
    fi
    if ! [[ "$entry" =~ $corpus_entry_re ]]; then
      log_fail "gate $id: input_corpus entry '$entry' does not match any grammar shape (named view, path, glob, or !-exclusion -- see gate-registry.data's header)"
      g_failed=1
    fi
  done
done
[ "$g_failed" -eq 0 ] && log_pass "every gate's input_corpus is '-' or a grammar-conformant entry list"

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
