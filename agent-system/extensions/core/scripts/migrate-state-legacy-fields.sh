#!/usr/bin/env bash
# migrate-state-legacy-fields.sh - Consumer-runnable migration retiring three dead top-level
# state.json fields and normalizing the legacy entry-level `blockers` shape.
#
# Ships the migration half of the state-schema field ruling documented in
# context/reference/state-management-schema.md's "Retired Top-Level Fields" subsection.
# state-schema.json's additionalProperties: false rejected four top-level fields and four
# entry-level fields that carried live, non-null data in at least one consumer repo. Five of
# those eight were WIDENED into the schema (see context/schemas/state-schema.json and
# context/reference/state-management-schema.md); this script implements the other half --
# RETIRING the three top-level fields that have no agent-system writer or reader (`artifacts`,
# `metadata`, top-level `last_updated` -- pre-agent-system generator-era bookkeeping, a distinct
# concept from the well-modelled, load-bearing per-entry `last_updated`, which this script never
# touches), and NORMALIZING the one widened field whose live values have two incompatible shapes
# (`blockers`: a legacy scalar string on some entries, canonical array of strings on others).
#
# HARD CONSTRAINT: no value is ever deleted silently. Every dropped top-level value and every
# normalized blockers value is printed to stdout in full, under an explicit heading, BEFORE the
# write happens -- this output IS the written no-information-loss record this script's design
# requires, independent of any other artifact or this script's own closing summary.
#
# Usage:
#   migrate-state-legacy-fields.sh [--dry-run] [--state-file PATH] [--session-id SID]
#   migrate-state-legacy-fields.sh --help
#
# Options:
#   --dry-run      Preview what would change; writes nothing. Default off.
#   --state-file   Path to the target state.json. Default: specs/state.json, resolved against
#                  the current working directory. Refused (exit 2) if the resolved path is
#                  specs/archive/state.json (explicitly out of this schema's scope -- see
#                  state-schema.json's own header note) or if it resolves outside the git
#                  repository this script is invoked in.
#   --session-id   Session id attributed to the write via state-write.sh. Self-generated via
#                  lib/common.sh's common_session_id() when omitted.
#
# Writes exclusively through a DEPLOYED state-write.sh (a path matching */.claude/scripts/ or
# */.opencode/scripts/), following the exact discipline validate-state.sh's own --fix mode
# already uses -- never a hand-rolled `jq ... > tmp && mv`. Refuses loudly (exit 2) when no
# deployed copy resolves; never falls back to an in-script write.
#
# Idempotent: a second run against an already-migrated file finds the three retired keys absent
# and no string-shaped blockers value remaining, reports "nothing to migrate", and exits 0
# without writing.
#
# Exit codes:
#   0 - success (migration applied, dry-run preview, or nothing to migrate)
#   1 - usage error, or unparseable JSON in the target file
#   2 - environment error (jq unavailable, target refused, no deployed state-write.sh resolved)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false
STATE_FILE="specs/state.json"
SESSION_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --state-file)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --state-file requires an argument" >&2
        exit 1
      fi
      STATE_FILE="$2"
      shift 2
      ;;
    --session-id)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --session-id requires an argument" >&2
        exit 1
      fi
      SESSION_ID="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,46p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo -e "${RED}ERROR:${NC} jq not available" >&2
  exit 2
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo -e "${RED}ERROR:${NC} File not found: $STATE_FILE" >&2
  exit 2
fi

if ! jq empty "$STATE_FILE" 2>/dev/null; then
  echo -e "${RED}ERROR:${NC} Unparseable JSON in $STATE_FILE" >&2
  exit 1
fi

# ─── Refuse archive/state.json and anything outside the invoking repo ──────────────────────────
STATE_DIR="$(cd "$(dirname "$STATE_FILE")" && pwd)"
STATE_ABS="$STATE_DIR/$(basename "$STATE_FILE")"
STATE_BASENAME="$(basename "$STATE_ABS")"
PARENT_BASENAME="$(basename "$STATE_DIR")"

if [[ "$STATE_BASENAME" == "state.json" && "$PARENT_BASENAME" == "archive" ]]; then
  echo -e "${RED}ERROR:${NC} refusing to operate on $STATE_ABS -- specs/archive/state.json is explicitly out of this schema's scope (see state-schema.json's own header note). This migration targets the live state.json only." >&2
  exit 2
fi

CWD_TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$CWD_TOPLEVEL" ]]; then
  echo -e "${RED}ERROR:${NC} current directory is not inside a git repository; refusing to guess which repo $STATE_ABS belongs to. Run this script from within the consumer repo whose state.json you intend to migrate." >&2
  exit 2
fi
case "$STATE_ABS" in
  "$CWD_TOPLEVEL"/*|"$CWD_TOPLEVEL")
    : # inside the invoking repo, proceed
    ;;
  *)
    echo -e "${RED}ERROR:${NC} refusing to operate on $STATE_ABS -- it resolves outside the current repository ($CWD_TOPLEVEL). This migration never writes to a repository other than the one it is invoked in." >&2
    exit 2
    ;;
esac

# ─── Resolve a DEPLOYED state-write.sh (same discipline as validate-state.sh's --fix mode) ─────
_toplevel_for_write="$(git -C "$STATE_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
STATE_WRITE_CANDIDATES=(
  "$SCRIPT_DIR/state-write.sh"
  "$SCRIPT_DIR/../../.claude/scripts/state-write.sh"
)
if [[ -n "$_toplevel_for_write" ]]; then
  STATE_WRITE_CANDIDATES+=("$_toplevel_for_write/.claude/scripts/state-write.sh")
fi
STATE_WRITE=""
for _candidate in "${STATE_WRITE_CANDIDATES[@]}"; do
  if [[ -f "$_candidate" ]] && [[ "$_candidate" == *"/.claude/scripts/"* || "$_candidate" == *"/.opencode/scripts/"* ]]; then
    STATE_WRITE="$_candidate"
    break
  fi
done
if [[ -z "$STATE_WRITE" ]]; then
  echo -e "${RED}ERROR:${NC} requires a DEPLOYED state-write.sh (path matching */.claude/scripts/ or */.opencode/scripts/); none found at any of:" >&2
  for _candidate in "${STATE_WRITE_CANDIDATES[@]}"; do
    echo "  $_candidate" >&2
  done
  echo "Deploy first (bash .claude/scripts/deploy-headless.sh), then re-run." >&2
  exit 2
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo -e "${YELLOW}DRY RUN MODE - no changes will be made${NC}"
  echo ""
fi

echo -e "${BLUE}Target:${NC} $STATE_ABS"
echo ""

# ─── Step 1: detect retired top-level fields and print their values before dropping them ───────
RETIRED_FIELDS=(artifacts metadata last_updated)
retired_found=0
echo -e "${BLUE}=== Step 1: retired top-level fields ===${NC}"
for field in "${RETIRED_FIELDS[@]}"; do
  if jq -e --arg f "$field" 'has($f)' "$STATE_FILE" >/dev/null 2>&1; then
    retired_found=$((retired_found + 1))
    value=$(jq -c --arg f "$field" '.[$f]' "$STATE_FILE")
    echo -e "${YELLOW}RECORDING DROPPED VALUE BEFORE REMOVAL${NC} -- top-level \`$field\`:"
    echo "  $value"
  fi
done
if [[ "$retired_found" -eq 0 ]]; then
  echo "  (none of artifacts, metadata, top-level last_updated present -- nothing to retire)"
fi
echo ""

# ─── Step 2: detect scalar-string blockers values and print before/after ───────────────────────
echo -e "${BLUE}=== Step 2: normalize entry-level blockers (string -> array of strings) ===${NC}"
blockers_report=$(jq -c '
  [ .active_projects[] | select((.blockers // null) | type == "string")
    | {project_number, before: .blockers, after: [.blockers]} ]
' "$STATE_FILE")
blockers_count=$(jq 'length' <<< "$blockers_report")
if [[ "$blockers_count" -eq 0 ]]; then
  echo "  (no scalar-string blockers values found -- nothing to normalize)"
else
  while IFS=$'\t' read -r pn before after; do
    [[ -z "$pn" ]] && continue
    echo "  project_number $pn: $before  ->  $after"
  done < <(jq -r '.[] | [(.project_number|tostring), (.before|tostring), (.after|tostring)] | @tsv' <<< "$blockers_report")
fi
echo ""

if [[ "$retired_found" -eq 0 && "$blockers_count" -eq 0 ]]; then
  echo -e "${GREEN}Nothing to migrate.${NC} $STATE_ABS already has no retired top-level fields and no scalar-string blockers values."
  exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo -e "${YELLOW}Run without --dry-run to apply the changes above.${NC}"
  exit 0
fi

JQ_FILTER='
  del(.artifacts) | del(.metadata) | del(.last_updated)
  | .active_projects = [.active_projects[] |
      if (.blockers // null | type) == "string" then .blockers |= [.] else . end
    ]
'

_session="${SESSION_ID:-$(common_session_id)}"

bash "$STATE_WRITE" \
  "$JQ_FILTER" \
  --state-file "$STATE_ABS" \
  --session-id "$_session"
_write_rc=$?

if [[ "$_write_rc" -ne 0 ]]; then
  echo -e "${RED}ERROR:${NC} state-write.sh failed (exit $_write_rc); $STATE_ABS left untouched." >&2
  exit 2
fi

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo "Retired top-level fields removed: $retired_found (values recorded above)"
echo "Entry blockers values normalized: $blockers_count (before/after recorded above)"
echo ""
echo -e "${GREEN}Migration complete.${NC} The dropped values and normalizations are recorded in this run's own stdout above -- capture it (e.g. redirect to a file) if you need a durable copy beyond your terminal scrollback."
exit 0
