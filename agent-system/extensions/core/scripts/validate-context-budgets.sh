#!/usr/bin/env bash
# validate-context-budgets.sh
# Validates agent context budgets against tier caps for index.json
#
# Usage: validate-context-budgets.sh [--verbose] [--index PATH]
#
# Exit codes:
#   0 - All agents within budget (or documented exceptions only)
#   1 - One or more agents exceed budget cap without documented exception

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
REPO_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
INDEX_FILE="${REPO_ROOT}/.claude/context/index.json"
VERBOSE=false
VIOLATIONS=0
# WARNINGS is the total count of non-fatal findings across every check.
# EXCEPTIONS_APPLIED counts only the subset that are documented per-agent budget exceptions
# (the OK* rows). The two are kept separate so a non-fatal finding (an OK* budget exception, an
# unclassifiable-command informational count, or a degraded route derivation) is never narrated
# as a "documented exception" in the summary. The Double-Loading Check itself no longer produces
# a routine warning -- it is keyed on the mechanical redundancy predicate below, and its
# redundant bucket contributes to VIOLATIONS, not WARNINGS. See the Double-Loading Check section
# for the current criterion.
WARNINGS=0
EXCEPTIONS_APPLIED=0
# Populated in the Agent Budget Check loop below, keyed by agent, only for agents whose
# documented exception actually applied this run. Consumed by the generalized summary
# narration loop so the two can never drift apart -- see that loop's comment for why.
declare -A EXCEPTIONS_APPLIED_TOTALS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE=true; shift ;;
    --index) INDEX_FILE="$2"; shift 2 ;;
    --help)
      echo "Usage: $0 [--verbose] [--index PATH]"
      echo ""
      echo "Validates agent context budgets against tier caps."
      echo "Reads index.json and computes per-agent token totals."
      echo ""
      echo "Options:"
      echo "  --verbose    List all entries per agent"
      echo "  --index PATH Path to index.json (default: .claude/context/index.json)"
      exit 0
      ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ ! -f "$INDEX_FILE" ]]; then
  echo "ERROR: index.json not found at $INDEX_FILE" >&2
  exit 1
fi

# Verify JSON validity
if ! jq empty "$INDEX_FILE" 2>/dev/null; then
  echo "ERROR: index.json is not valid JSON" >&2
  exit 1
fi

# --- Tier derivation -------------------------------------------------------------------------
# Tier is DERIVED from load_when shape, never read from an authored `tier` field. The entry
# schema (context/index.schema.json) deliberately omits `tier` and records in its $comment that
# the value "is meant to be derived algorithmically from load_when shape rather than
# hand-authored, since no entry in practice ever populated it accurately" -- and, with
# `additionalProperties: false` on the entry shape, an authored `tier` is not even schema-legal.
# This function is the single definition of that derivation; it is prepended to every jq program
# below that needs a tier, so there is exactly one rule table in this file.
#
#   Rule table (first match wins, total over all entries):
#     load_when.always == true                        -> Tier 1  (always loaded)
#     load_when.agents non-empty                      -> Tier 2  (agent-scoped)
#     load_when.commands or task_types non-empty      -> Tier 3  (command/task-type-scoped)
#     every hook empty                                -> Tier 4  (on-demand / grep-only)
#
# Because case 4 is a fallthrough on emptiness, "all hooks empty" now DERIVES to Tier 4 rather
# than being an authored claim. That is what makes the old Dead Entry Check ("not Tier 4 but
# never loaded") a tautology, and why that check is keyed on the explicit `on_demand` marker
# instead -- see the Dead Entry Check section below.
#
# See context/standards/context-tier-semantics.md for the full explanation and rationale behind
# this rule table and the on_demand decision rule; this comment states the rule, that file
# explains and motivates it.
DERIVED_TIER='
def derived_tier:
  if (.load_when.always == true) then 1
  elif ((.load_when.agents // []) | length) > 0 then 2
  elif (((.load_when.commands // []) | length) > 0
        or ((.load_when.task_types // []) | length) > 0) then 3
  else 4
  end;
'

echo "=== Context Budget Validation ==="
echo "Index: $INDEX_FILE"
echo ""

# Budget caps per agent class (tokens)
declare -A CAPS=(
  ["meta-builder-agent"]=15000
  ["planner-agent"]=15000
  ["general-implementation-agent"]=8000
  ["general-research-agent"]=8000
  ["neovim-implementation-agent"]=8000
  ["neovim-research-agent"]=8000
  ["nix-implementation-agent"]=8000
  ["nix-research-agent"]=8000
  ["code-reviewer-agent"]=8000
  ["spawn-agent"]=8000
)

# Documented exceptions (agents that cannot meet strict cap with minimum essential context)
#
# Format: agent=cap:justification, where cap = measured total (recomputed against the current
# deployed index; see the recomputation note below) plus a small fixed 500-token headroom so
# ordinary content drift (a line or two added to a hooked file) does not immediately re-break
# the gate. This differs from raising a CAPS value: CAPS above stays fixed at each agent's real
# budget ceiling, and an EXCEPTIONS entry is a separate, narrower, per-agent override that still
# fails loudly (falls through to a plain OVER) the moment the agent's real composition grows
# meaningfully past this recorded floor -- it is not a blank check.
#
# All three agents below share the same structural cause: the shared "always-loaded"
# implementation core bundle -- formats/return-metadata-file.md (4,768 tok) +
# formats/progress-file.md (2,160 tok) + formats/summary-format.md (608 tok) +
# contracts/phase-closure.md (856 tok) + contracts/pre-edit-gate.md (856 tok) = 9,248 tokens --
# already exceeds the 8,000-token cap before any agent-specific domain content is counted. This
# is a core-doc size problem, not a hook-authorship problem; see the recomputation note below.
#
# RECOMPUTATION NOTE: these caps and justifications are computed from file sizes measured at
# authoring time. Whenever any file named in a justification below changes size (edited content,
# not just a hook change), recompute with:
#   bash .claude/scripts/validate-context-budgets.sh --verbose
# and update the affected entry's cap/justification to match -- do not leave a stale cap in
# place the way the single prior entry (general-implementation-agent at a stale 8,048 against a
# real 68,568) went unnoticed and inert for an extended period.
declare -A EXCEPTIONS=(
  ["general-implementation-agent"]="17188:9,248-token shared core bundle (return-metadata-file 4768+progress-file 2160+summary-format 608+phase-closure 856+pre-edit-gate 856) plus this agent's unconditional domain content -- git-staging-scope(2624)+subagent-continuation-loop(1720)+context-exhaustion-detection(1688)+checkpoint-before-overflow(1408) -- measured total 16,688, +500 headroom"
  ["neovim-implementation-agent"]="15836:9,248-token shared core bundle (return-metadata-file 4768+progress-file 2160+summary-format 608+phase-closure 856+pre-edit-gate 856) plus this agent's unconditional domain content -- project/neovim/standards/lua-style-guide(2472)+project/neovim/patterns/plugin-spec(2136)+project/neovim/patterns/keymap-patterns(1480) -- measured total 15,336, +500 headroom"
  ["nix-implementation-agent"]="14604:9,248-token shared core bundle (return-metadata-file 4768+progress-file 2160+summary-format 608+phase-closure 856+pre-edit-gate 856) plus this agent's unconditional domain content -- project/nix/standards/nix-style-guide(2328)+project/nix/domain/nix-language(1720)+project/nix/README(808) -- measured total 14,104, +500 headroom"
)

echo "--- Agent Budget Check ---"
printf "%-35s %8s %8s %12s\n" "Agent" "Tokens" "Cap" "Status"
printf "%s\n" "$(printf '%.0s-' {1..67})"

for agent in "${!CAPS[@]}"; do
  cap="${CAPS[$agent]}"

  # Compute total tokens for this agent
  total=$(jq --arg agent "$agent" \
    '[.entries[] | select(any(.load_when.agents[]?; . == $agent)) | .line_count] | add // 0' \
    "$INDEX_FILE")
  total_tokens=$((total * 8))

  # Check for documented exception
  exception=""
  if [[ -v "EXCEPTIONS[$agent]" ]]; then
    exception_data="${EXCEPTIONS[$agent]}"
    exception_cap="${exception_data%%:*}"
    exception_reason="${exception_data#*:}"
    exception="(exception: $exception_reason)"
  fi

  if [[ $total_tokens -le $cap ]]; then
    printf "%-35s %8s %8s %12s\n" "$agent" "$total_tokens" "$cap" "OK"
  elif [[ -n "$exception" && $total_tokens -le "${exception_cap:-0}" ]]; then
    printf "%-35s %8s %8s %12s\n" "$agent" "$total_tokens" "$cap" "OK*"
    WARNINGS=$((WARNINGS + 1))
    EXCEPTIONS_APPLIED=$((EXCEPTIONS_APPLIED + 1))
    EXCEPTIONS_APPLIED_TOTALS["$agent"]="$total_tokens"
    if [[ "$VERBOSE" == "true" ]]; then
      echo "    * Documented exception: $exception_reason"
    fi
  else
    printf "%-35s %8s %8s %12s\n" "$agent" "$total_tokens" "$cap" "OVER:$((total_tokens - cap))"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi

  if [[ "$VERBOSE" == "true" ]]; then
    echo "  Entries for $agent:"
    jq -r --arg agent "$agent" "${DERIVED_TIER}"'
      .entries[] | select(any(.load_when.agents[]?; . == $agent)) | "    Tier \(derived_tier) \(.line_count * 8) tok  \(.path)"' \
      "$INDEX_FILE" | sort -t' ' -k3 -rn
    echo ""
  fi
done

echo ""

# Tier 1 check
echo "--- Tier 1 Check ---"
tier1_lines=$(jq '[.entries[] | select(.load_when.always == true) | .line_count] | add // 0' "$INDEX_FILE")
tier1_count=$(jq '[.entries[] | select(.load_when.always == true)] | length' "$INDEX_FILE")
tier1_target=500
echo "Always-loaded entries: $tier1_count (target: 2)"
echo "Always-loaded total lines: $tier1_lines (target: ≤$tier1_target)"
if [[ $tier1_lines -le $tier1_target ]]; then
  echo "Status: OK"
else
  echo "Status: OVER by $((tier1_lines - tier1_target)) lines"
  VIOLATIONS=$((VIOLATIONS + 1))
fi
if [[ "$VERBOSE" == "true" ]]; then
  echo "Tier 1 entries:"
  jq -r '.entries[] | select(.load_when.always == true) | "  \(.line_count)L  \(.path)"' "$INDEX_FILE"
fi
echo ""

# Every entry classifies under the derived tier rule table
# `derived_tier` is a total function over the four load_when cases, so an entry can never fail to
# classify. The check therefore reports the resulting distribution (which is real, diffable
# signal about index shape) rather than counting a never-populated authored field.
echo "--- Tier Classification Check ---"
total_entries=$(jq '.entries | length' "$INDEX_FILE")
unclassified=$(jq "${DERIVED_TIER}"'[.entries[] | select((derived_tier | IN(1,2,3,4)) | not)] | length' "$INDEX_FILE")
tier_dist=$(jq -r "${DERIVED_TIER}"'
  [.entries[] | derived_tier] | group_by(.) | map("Tier \(.[0]): \(length)") | join(", ")' "$INDEX_FILE")
echo "Total entries: $total_entries"
echo "Derived tier distribution: $tier_dist"
if [[ $unclassified -eq 0 ]]; then
  echo "Status: OK (all entries classify via derived_tier)"
else
  echo "Status: FAIL ($unclassified entries fail to classify)"
  VIOLATIONS=$((VIOLATIONS + 1))
  if [[ "$VERBOSE" == "true" ]]; then
    echo "Unclassified:"
    jq -r "${DERIVED_TIER}"'.entries[] | select((derived_tier | IN(1,2,3,4)) | not) | "  \(.path)"' "$INDEX_FILE"
  fi
fi
echo ""

# No dead entries (never auto-loaded and not explicitly marked on-demand)
# Dead = every load_when hook empty AND no explicit `on_demand: true` marker.
#
# This check was formerly keyed on the authored tier field being other than 4 ("not Tier 4 but
# never loaded"). Under algorithmic derivation an all-hooks-empty
# entry ALWAYS derives to Tier 4, so that predicate is unsatisfiable and the check would silently
# become a tautology that can never fire. Emptiness alone therefore no longer exempts an entry:
# the exemption must be stated explicitly by the entry author via `on_demand: true` (declared as
# a property in context/index.schema.json). That keeps "deliberately grep-only" distinguishable
# from "someone forgot to hook this up", which is the only signal this check ever carried.
DEAD_PRED='
  select(
    (((.on_demand // false) == true) | not) and
    ((.load_when.always == true) | not) and
    ((.load_when.agents // []) | length) == 0 and
    ((.load_when.commands // []) | length) == 0 and
    ((.load_when.task_types // []) | length) == 0 and
    ((.load_when.skills // []) | length) == 0 and
    ((.load_when.languages // []) | length) == 0
  )
'
echo "--- Dead Entry Check ---"
dead_count=$(jq "[.entries[] | ${DEAD_PRED}] | length" "$INDEX_FILE")
if [[ $dead_count -eq 0 ]]; then
  echo "Dead entries (all hooks empty, not marked on_demand): 0 -- OK"
else
  echo "Dead entries found: $dead_count"
  VIOLATIONS=$((VIOLATIONS + 1))
  jq -r "${DERIVED_TIER}"'.entries[] | '"${DEAD_PRED}"' | "  \(.path) (Tier \(derived_tier))"' "$INDEX_FILE"
fi
echo ""

# Entries reachable through both an agent hook and a command hook
#
# Redundancy criterion (mechanical, not shape-only): an entry with non-empty
# `load_when.agents` and non-empty `load_when.commands` is REDUNDANT iff every command in
# `commands[]` is agent-routed to an agent already present in that entry's own `agents[]`. The
# exemption for the legitimately dual-addressed shape is the predicate's own FALSE result --
# re-derived from deployed artifacts on every run -- never an allowlist file and never a frozen
# count in a comment.
#
# Six commands route to exactly one agent apiece and are derivable live from deployed artifacts
# (never a hardcoded literal agent name):
#   /research, /plan, /implement  <- manifest.json's routing_agents.{research,plan,implement}
#   /meta, /spawn, /revise        <- the sole `subagent_type:` line in skill-meta's,
#                                     skill-spawn's, and skill-reviser's SKILL.md
# `/orchestrate` can never make an entry redundant: its reach is the union of the research,
# plan, and implement agents, so it can only collapse onto a single already-listed agent if all
# three of those were the same agent, which they are not.
#
# A command outside those six routes and outside the literal direct-command roster below is
# UNCLASSIFIABLE: most are extension commands (e.g. /grant, /epi, /deck, /convert) whose
# command-name-to-agent route is not mechanically derivable from any manifest today (an
# extension's routing/routing_agents block is keyed by task type, not command name).
# Unclassifiable is informational, not a violation -- under-detection is the safe direction
# here -- but it is named and counted rather than silently folded into "legitimate", so the
# check's own coverage boundary stays visible in its output rather than buried in a comment.
#
# Route sources are overridable via env vars (unset in normal operation; used only by
# test-double-loading-check.sh to stub an unreadable route source for the degraded-derivation
# case, without touching the real deployed manifest/skill files).
echo "--- Double-Loading Check ---"

MANIFEST_FILE="${VALIDATE_BUDGETS_MANIFEST_OVERRIDE:-${REPO_ROOT}/.claude/extensions/core/manifest.json}"
META_SKILL_FILE="${VALIDATE_BUDGETS_META_SKILL_OVERRIDE:-${REPO_ROOT}/.claude/skills/skill-meta/SKILL.md}"
SPAWN_SKILL_FILE="${VALIDATE_BUDGETS_SPAWN_SKILL_OVERRIDE:-${REPO_ROOT}/.claude/skills/skill-spawn/SKILL.md}"
REVISE_SKILL_FILE="${VALIDATE_BUDGETS_REVISE_SKILL_OVERRIDE:-${REPO_ROOT}/.claude/skills/skill-reviser/SKILL.md}"

_dlc_route_agents() {
  # $1 = routing_agents.<op> key; unique agent names, newline-joined; empty on any failure.
  # `|| true` on the pipeline itself is required under `set -e -o pipefail`: a missing/unreadable
  # MANIFEST_FILE makes `jq` exit non-zero, and pipefail propagates that through `sort -u` into
  # this whole statement's exit status -- which, called inside a `var="$(...)"` command
  # substitution, would otherwise abort the entire script instead of degrading gracefully into
  # the [DEGRADED ROUTE DERIVATION] path below. `|| true` must sit on the pipeline itself, not
  # merely on a later `return 0`: under `set -e` the abort happens at the failing statement,
  # before a subsequent `return 0` would ever run.
  jq -r --arg op "$1" '.routing_agents[$op] // {} | to_entries[].value' "$MANIFEST_FILE" 2>/dev/null | sort -u || true
}
_dlc_subagent_type() {
  # $1 = SKILL.md path; the sole `subagent_type: "..."` value; empty on any failure. Same
  # pipefail/set -e hazard as _dlc_route_agents above -- an unreadable path must degrade, not abort.
  grep -oP 'subagent_type:\s*"\K[^"]+' "$1" 2>/dev/null | head -1 || true
}

dlc_research_route="$(_dlc_route_agents research)"
dlc_plan_route="$(_dlc_route_agents plan)"
dlc_implement_route="$(_dlc_route_agents implement)"
dlc_meta_route="$(_dlc_subagent_type "$META_SKILL_FILE")"
dlc_spawn_route="$(_dlc_subagent_type "$SPAWN_SKILL_FILE")"
dlc_revise_route="$(_dlc_subagent_type "$REVISE_SKILL_FILE")"

dlc_degraded=()
[[ -z "$dlc_research_route" ]] && dlc_degraded+=("/research")
[[ -z "$dlc_plan_route" ]] && dlc_degraded+=("/plan")
[[ -z "$dlc_implement_route" ]] && dlc_degraded+=("/implement")
[[ -z "$dlc_meta_route" ]] && dlc_degraded+=("/meta")
[[ -z "$dlc_spawn_route" ]] && dlc_degraded+=("/spawn")
[[ -z "$dlc_revise_route" ]] && dlc_degraded+=("/revise")

if [[ ${#dlc_degraded[@]} -gt 0 ]]; then
  echo "[DEGRADED ROUTE DERIVATION] failed to resolve: ${dlc_degraded[*]} -- affected command(s) treated as unclassifiable, never as direct"
  WARNINGS=$((WARNINGS + 1))
fi

# A degraded (empty-string) route is OMITTED from the table entirely, never represented as an
# empty array. `$route_table[$c]` for an omitted key is `null` via the `// null` default used
# throughout the partition logic below, which correctly routes a degraded command into
# "unclassifiable" rather than vacuously satisfying the redundancy subset test (`[] - $agents`
# is always `[]`, which would silently make an unroutable command look redundant instead of
# unclassifiable -- the exact silent-no-op this check must not produce).
dlc_route_table=$(jq -n \
  --arg research "$dlc_research_route" --arg plan "$dlc_plan_route" --arg implement "$dlc_implement_route" \
  --arg meta "$dlc_meta_route" --arg spawn "$dlc_spawn_route" --arg revise "$dlc_revise_route" \
  '
  {}
  + (if $research == "" then {} else {"/research": ($research | split("\n"))} end)
  + (if $plan == "" then {} else {"/plan": ($plan | split("\n"))} end)
  + (if $implement == "" then {} else {"/implement": ($implement | split("\n"))} end)
  + (if $meta == "" then {} else {"/meta": [$meta]} end)
  + (if $spawn == "" then {} else {"/spawn": [$spawn]} end)
  + (if $revise == "" then {} else {"/revise": [$revise]} end)
  ')

# Direct commands never route to an agent (their skill executes directly), so a command hook
# naming one of these can never make an entry redundant.
dlc_direct_commands='["/review","/errors","/task","/todo","/refresh","/fix-it","/learn","/distill","/literature","/project-overview","/tag","/merge","/cite"]'

# Note: jq's `index(.)` rebinds `.` to its own piped-in input, so `$arr | index(.)` does NOT
# test membership of the value from an outer context -- a documented jq footgun. Membership
# tests below always bind the value to a named variable first and use `any(. == $var)`.
dlc_partition=$(jq -n \
  --argjson route_table "$dlc_route_table" \
  --argjson direct "$dlc_direct_commands" \
  --slurpfile idx "$INDEX_FILE" \
  '
  ($idx[0].entries) as $entries |
  ($entries | map(select(
      (.load_when.agents // [] | length > 0) and
      (.load_when.commands // [] | length > 0)
    ))) as $dual |
  ($dual | map(
      . as $e |
      ($e.load_when.commands) as $cmds |
      ($e.load_when.agents) as $agents |
      {
        path: $e.path,
        is_redundant: ($cmds | all(. as $c |
            if $c == "/orchestrate" then false
            elif ($direct | any(. == $c)) then false
            elif ($route_table[$c] // null) == null then false
            else (($route_table[$c] - $agents) | length) == 0
            end
          )),
        unclassifiable_tokens: [$cmds[] | . as $c | select(
            $c != "/orchestrate" and
            (($direct | any(. == $c)) | not) and
            (($route_table[$c] // null) == null)
          )]
      }
    )) as $classified |
  {
    redundant: [$classified[] | select(.is_redundant) | .path],
    unclassifiable: [$classified[] | select((.is_redundant | not) and (.unclassifiable_tokens | length > 0)) | {path: .path, tokens: .unclassifiable_tokens}],
    legitimate: [$classified[] | select((.is_redundant | not) and (.unclassifiable_tokens | length == 0)) | .path],
    total: ($dual | length)
  }
  ')

dlc_total=$(echo "$dlc_partition" | jq '.total')
dlc_redundant_count=$(echo "$dlc_partition" | jq '.redundant | length')
dlc_legitimate_count=$(echo "$dlc_partition" | jq '.legitimate | length')
dlc_unclassifiable_count=$(echo "$dlc_partition" | jq '.unclassifiable | length')

echo "Entries with both agents and commands hooks: $dlc_total"
if [[ $dlc_total -eq 0 ]]; then
  echo "Status: OK"
else
  if [[ $dlc_redundant_count -eq 0 ]]; then
    echo "Redundant (commands[] fully subsumed by agents[]): 0 -- OK"
  else
    echo "Redundant (commands[] fully subsumed by agents[]): $dlc_redundant_count -- VIOLATION"
    VIOLATIONS=$((VIOLATIONS + 1))
    # Offending paths are listed unconditionally (not gated on --verbose) so the failure is
    # actionable from a bare run.
    echo "$dlc_partition" | jq -r '.redundant[] | "  \(.)"'
  fi
  echo "Legitimately dual-addressed (informational, not a violation): $dlc_legitimate_count"
  if [[ "$VERBOSE" == "true" && $dlc_legitimate_count -gt 0 ]]; then
    echo "$dlc_partition" | jq -r '.legitimate[] | "  \(.)"'
  fi
  echo "Unclassifiable-command (informational; route not mechanically derivable, e.g. extension commands): $dlc_unclassifiable_count"
  if [[ "$VERBOSE" == "true" && $dlc_unclassifiable_count -gt 0 ]]; then
    echo "$dlc_partition" | jq -r '.unclassifiable[] | "  \(.path) (unrecognized: \(.tokens | join(", ")))"'
  fi
fi
echo ""

# Summary
echo "=== Summary ==="
echo "Violations: $VIOLATIONS"
if [[ $WARNINGS -gt 0 ]]; then
  echo "Warnings: $WARNINGS"
fi
if [[ $EXCEPTIONS_APPLIED -gt 0 ]]; then
  echo "Documented exceptions: $EXCEPTIONS_APPLIED (OK* entries)"
  # Generalized loop over EXCEPTIONS (not a hardcoded literal per agent): this is the fix for
  # the exact drift this file's history already demonstrated once -- the prior version of this
  # block printed general-implementation-agent's stale 8,048/4,016/2,032/2,000 composition as
  # literal text regardless of what EXCEPTIONS actually declared, so the two silently diverged.
  # Looping over EXCEPTIONS_APPLIED_TOTALS (populated only for agents whose exception fired this
  # run, in the Agent Budget Check loop above) means the narration is always derived from the
  # live array contents and the live measured total, never copy-pasted prose.
  for agent in "${!EXCEPTIONS_APPLIED_TOTALS[@]}"; do
    exception_data="${EXCEPTIONS[$agent]}"
    exception_cap="${exception_data%%:*}"
    exception_reason="${exception_data#*:}"
    applied_total="${EXCEPTIONS_APPLIED_TOTALS[$agent]}"
    echo "  * ${agent}: ${applied_total} tokens vs ${CAPS[$agent]} cap (exception cap ${exception_cap})"
    echo "    ${exception_reason}"
  done
fi

if [[ $VIOLATIONS -eq 0 ]]; then
  echo ""
  echo "All checks passed!"
  exit 0
else
  echo ""
  echo "FAIL: $VIOLATIONS violation(s) found"
  exit 1
fi
