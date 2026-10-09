#!/usr/bin/env bash
# sweep-invalidated-claims.sh - Cross-task claim-invalidation matcher.
#
# OUTPUT CONTRACT: JSON array on stdout, always -- `[]` on no match, no name, no state file, a
# malformed state file, or a jq-unavailable host. Every diagnostic goes to stderr. Exit status
# is unconditionally 0 on every path (see Exit codes below): this script is advisory-only and
# must never fail a dispatch that calls it.
#
# ADVISORY, NEVER-MUTATING POSTURE: this script opens its state file read-only and never writes
# to it, never sources state-write.sh or any mutation helper, and never touches a task's
# description, file_scope, or status. It only ever produces a list for a human to triage.
#
# FALSE-NEGATIVE POSTURE, STATED EXPLICITLY: matching is literal and word-boundary, keyed on
# declaration names and explicit supersession markers -- never natural-language or semantic
# claim equivalence. A refutation referenced only by paraphrase in a sibling task's own text will
# be missed. This is a deliberate precision-over-recall trade (see the task's plan, Decision 1),
# not an oversight.
#
# DORMANCY NOTE (deliberate, not an oversight): as of this writing, NO call site invokes this
# script. The single integration point is `scripts/orchestrate-cycle-postflight.sh`, at the
# research-postflight site, deliberately deferred to its own follow-up task rather than wired
# here (wiring it here would add a serializing edge against a file already in eight other open
# tasks' declared file_scope for one call line). That follow-up task owes BOTH of the following
# calls, bundled as one task so as not to double the serializing edges:
#   1. This script, keyed on the producing dispatch's `.return-meta.json` `claim_invalidations`
#      array (the NEGATIVE direction: a refutation falsifying a sibling task's filed premise).
#   2. `memory-harvest.sh <task_number>`, keyed on a non-empty `memory_candidates` array (the
#      POSITIVE direction: a finding already recorded in one task's artifacts reaching the next
#      task that would otherwise rediscover it). `memory-harvest.sh` already exists and is
#      itself presently uncalled for the same reason -- see its own header.
#
# Usage:
#   sweep-invalidated-claims.sh --name NAME [--name NAME ...] [--self TASK_NUMBER] [--state-file PATH]
#   sweep-invalidated-claims.sh --from-return-meta PATH [--self TASK_NUMBER] [--state-file PATH]
#   sweep-invalidated-claims.sh --help
#
# Input modes (combinable -- names from both are unioned and deduplicated):
#   --name NAME              A declaration name to sweep for. Repeatable.
#   --from-return-meta PATH  Read every entry's `declaration_names` out of a `.return-meta.json`
#                            file's top-level `claim_invalidations` array (see
#                            context/formats/return-metadata-file.md). A missing file, an
#                            unreadable file, or an absent/empty `claim_invalidations` array
#                            contributes zero names -- never an error.
#   --self TASK_NUMBER       The producing task's own project_number, excluded from the result
#                            (a task never flags itself).
#   --state-file PATH        Defaults to `specs/state.json` under the repository root. Present
#                            so a test fixture can drive this script against a synthetic state
#                            file without ever touching real state.
#
# Match rule (plan Decisions 1-2): for every non-terminal (`completed`/`abandoned`/`expanded`
# excluded via a membership test, never a chain of `!=` -- see CLAUDE.md's "jq Command Safety"
# section) sibling task other than `--self`, each collected declaration name is regex-escaped
# and matched against that task's own `title` and `description` with an explicit word-boundary
# lookaround, `(?<![A-Za-z0-9_])<name>(?![A-Za-z0-9_])`, inside one `jq` invocation (Oniguruma
# lookaround, verified against the installed jq at plan-authoring time).
#
# Output: a JSON array of `{task_number, title, matched_name}` objects (plan Decision 4 -- `title`
# is carried so a human triaging the output does not need a `state.json` lookup per row), sorted
# by `task_number` then `matched_name` and deduplicated by that same pair, so output is
# deterministic across repeated runs.
#
# Exit codes:
#   0 - Always, on every path described above (including every error condition). This script
#       exits non-zero ONLY for a CLI usage error (an unrecognized flag, or a flag missing its
#       required value) -- a programming error distinct from the runtime/data conditions the
#       advisory posture above covers.
#   2 - CLI usage error (unrecognized flag, or a flag missing its required value).

set -uo pipefail

print_usage() {
  cat <<'USAGE'
Usage:
  sweep-invalidated-claims.sh --name NAME [--name NAME ...] [--self TASK_NUMBER] [--state-file PATH]
  sweep-invalidated-claims.sh --from-return-meta PATH [--self TASK_NUMBER] [--state-file PATH]
  sweep-invalidated-claims.sh --help

Input modes (combinable):
  --name NAME              A declaration name to sweep for. Repeatable.
  --from-return-meta PATH  Read declaration_names out of a .return-meta.json's top-level
                           claim_invalidations array. Missing/empty contributes nothing.
  --self TASK_NUMBER       The producing task's own project_number, excluded from the result.
  --state-file PATH        Defaults to specs/state.json under the repository root.

Output: a JSON array of {task_number, title, matched_name} objects on stdout, always -- "[]" on
no match, no name, or any error. Exit status is always 0 except for a CLI usage error (exit 2).
Advisory-only: never mutates state.json, never writes anything.
USAGE
}

NAMES=()
FROM_RETURN_META=""
SELF=""
STATE_FILE_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      [[ $# -ge 2 ]] || { echo "ERROR: --name requires a value" >&2; print_usage >&2; exit 2; }
      NAMES+=("$2")
      shift 2
      ;;
    --from-return-meta)
      [[ $# -ge 2 ]] || { echo "ERROR: --from-return-meta requires a value" >&2; print_usage >&2; exit 2; }
      FROM_RETURN_META="$2"
      shift 2
      ;;
    --self)
      [[ $# -ge 2 ]] || { echo "ERROR: --self requires a value" >&2; print_usage >&2; exit 2; }
      SELF="$2"
      shift 2
      ;;
    --state-file)
      [[ $# -ge 2 ]] || { echo "ERROR: --state-file requires a value" >&2; print_usage >&2; exit 2; }
      STATE_FILE_ARG="$2"
      shift 2
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    *)
      echo "ERROR: unrecognized argument: $1" >&2
      print_usage >&2
      exit 2
      ;;
  esac
done

# ── jq availability: advisory means a jq-less host still gets [] on stdout, exit 0 ─────────────
if ! command -v jq >/dev/null 2>&1; then
  echo "WARNING: jq not found on PATH -- sweep-invalidated-claims.sh is a no-op here" >&2
  echo '[]'
  exit 0
fi

# ── Root resolution (mirrors lint-json-channel-discipline.sh's own convention, not the
# scripts/-depth-specific deploy-root-guard.sh one used by most scripts/*.sh): `git rev-parse
# --show-toplevel` first (a REPO_ROOT env override honored first), falling back to a
# script-relative default -- this script is read-only and is designed to run identically from
# either the deployed .claude/scripts/ copy or directly from the agent-system source-store copy,
# so deploy-root-guard.sh's deployed-tree-only assumption does not apply here.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-}"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

STATE_FILE="${STATE_FILE_ARG:-$REPO_ROOT/specs/state.json}"

# ── Collect declaration names from both input modes, unioned and deduplicated ──────────────────
direct_names_json='[]'
if [[ ${#NAMES[@]} -gt 0 ]]; then
  direct_names_json="$(printf '%s\n' "${NAMES[@]}" | jq -R -s -c '[splits("\n")] | map(select(length > 0))' 2>/dev/null || echo '[]')"
  [[ -n "$direct_names_json" ]] || direct_names_json='[]'
fi

return_meta_names_json='[]'
if [[ -n "$FROM_RETURN_META" ]] && [[ -f "$FROM_RETURN_META" ]]; then
  return_meta_names_json="$(jq -c '[.claim_invalidations // [] | .[] | .declaration_names // [] | .[]?]' "$FROM_RETURN_META" 2>/dev/null || echo '[]')"
  [[ -n "$return_meta_names_json" ]] || return_meta_names_json='[]'
fi

all_names_json="$(jq -nc --argjson a "$direct_names_json" --argjson b "$return_meta_names_json" \
  '($a + $b) | map(select(type == "string" and length > 0)) | unique' 2>/dev/null || echo '[]')"
[[ -n "$all_names_json" ]] || all_names_json='[]'

# ── The match itself: one jq invocation, per plan Decision 1/2 ─────────────────────────────────
result="$(jq -c \
  --argjson names "$all_names_json" \
  --arg self "$SELF" \
  --argjson terminal '["completed", "abandoned", "expanded"]' \
  '
    ($names | map(select(type == "string" and length > 0))) as $names2
    | if ($names2 | length) == 0 then []
      else
        ($names2 | map({name: ., esc: (gsub("(?<c>[.*+?^${}()|\\[\\]\\\\])"; "\\" + .c))})) as $pairs
        | (if ($self | length) == 0 then [] else [$self] end) as $self_set
        | [
            .active_projects[]? as $task
            | select(([$task.status] | inside($terminal)) | not)
            | select(([$task.project_number | tostring] | inside($self_set)) | not)
            | ($task.title // "") as $title
            | ($task.description // "") as $desc
            | ($title + "\n" + $desc) as $hay
            | $pairs[] as $p
            | select($hay | test("(?<![A-Za-z0-9_])" + $p.esc + "(?![A-Za-z0-9_])"))
            | {task_number: $task.project_number, title: $title, matched_name: $p.name}
          ]
        | unique_by([.task_number, .matched_name])
        | sort_by([.task_number, .matched_name])
      end
  ' "$STATE_FILE" 2>/dev/null)"
rc=$?

if [[ $rc -ne 0 ]] || [[ -z "$result" ]]; then
  echo '[]'
  exit 0
fi

echo "$result"
exit 0
