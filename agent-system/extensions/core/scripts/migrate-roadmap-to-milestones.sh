#!/usr/bin/env bash
# migrate-roadmap-to-milestones.sh - One-time migration of a store from the flat roadmap shape
# (roadmap_batches / roadmap_notes plus a hand-authored specs/ROADMAP.md) to the milestone shape
# (primary_goals, roadmap_milestones, roadmap_context) that roadmap-integration.sh renders the
# whole file from, with a hard losslessness accounting gate that runs before any write.
#
# Usage:
#   migrate-roadmap-to-milestones.sh [--dry-run] [--force] [--roadmap PATH] [--state PATH]
#                                    [--retained PATH] --session-id SID
#   migrate-roadmap-to-milestones.sh --help
#
# Options:
#   --roadmap PATH     Path to ROADMAP.md (default: specs/ROADMAP.md under the repo root)
#   --state PATH       Path to state.json (default: specs/state.json under the repo root)
#   --retained PATH    Where prose with no state field is kept verbatim (default:
#                      archive/roadmap-retained-prose-YYYYMMDD.md beside the state file). An
#                      existing file at this path is never overwritten.
#   --session-id SID   Required for a real (non-dry-run) write; passed through to state-write.sh
#   --dry-run          Print the accounting and the proposed entries; write nothing
#   --force            Run even if roadmap_milestones is already non-empty
#   --help             Show this usage and exit 0
#
# Exit codes: 0 migrated (or dry run passed); 1 usage error or accounting-gate failure (nothing
# written); 2 refused (already migrated without --force, or the retained-prose target exists);
# 3 prerequisite missing (run migrate-roadmap-next-to-state.sh first).
#
# WHAT MOVES WHERE
#   State. Every flat batch, in order and unchanged, becomes a batch of ONE milestone (id M1,
#   title "Current work", status active, review state none, a fixed neutral aim). This script
#   draws no milestone boundary: dividing the work into real milestones is a judgment made later
#   through /roadmap. `## Goal` paragraphs go to primary_goals; `## Standing rules` list items go
#   to roadmap_context.rules; `## Checks before and after every call` and `## Settled decisions`
#   list items go to roadmap_context.conventions. The flat roadmap_batches and roadmap_notes keys
#   are deleted.
#   Retained-prose file. Everything with no state field is written verbatim under its original
#   header: the preamble, `## Gate state`, `## Unfiled observations`, any other section, every
#   roadmap_notes string, and any item longer than its field's bound. An over-bound item is never
#   truncated -- it is retained whole and one WARN names it. For a stage-layout or unrecognised
#   file every section is retained (bar a stage file's run-order section when it is rendered from
#   existing batches).
#   Generated regions. A classic file's `## Next` and `## Open work` bodies are rendered from
#   state and carry no authored text of their own; they are not accounted and not retained.
#
# LOSSLESSNESS GATE (hard, before any write)
#   1. Every non-blank line of the existing file outside generated regions is matched, trimmed,
#      against exactly one destination line: a line of the staged retained-prose file, or one of
#      the source lines recorded for an item placed in state. The comparison is a multiset
#      equality, so a dropped line and a duplicated line both fail.
#   2. Every item placed in state equals its recorded source lines joined by single spaces (list
#      marker removed), and sits at its expected index in the proposed state.
#   3. Every line of every roadmap_notes string is matched the same way against the retained
#      file's roadmap_notes sections.
#   4. Batches are accounted structurally: the flat array and the flattened nested one are equal
#      under `jq -S` (count, task_ids, description, rationale, flags).
#   Any failure is named line by line and the script exits 1 with nothing written.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
source "${SCRIPT_DIR}/lib/roadmap-preflight-lib.sh"

ROADMAP_PATH="${PROJECT_ROOT}/specs/ROADMAP.md"
STATE_PATH="${PROJECT_ROOT}/specs/state.json"
RETAINED_PATH=""
DRY_RUN=0
FORCE=0
SESSION_ID=""

# Field bounds, in characters; they mirror context/schemas/state-schema.json.
GOAL_BOUND=500
CONTEXT_BOUND=300

MILESTONE_ID="M1"
MILESTONE_TITLE="Current work"
MILESTONE_AIM="Work already scheduled when this store adopted milestones. Divide it into real milestones on a later /roadmap run."

usage() {
  sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --roadmap) ROADMAP_PATH="$2"; shift 2 ;;
    --state) STATE_PATH="$2"; shift 2 ;;
    --retained) RETAINED_PATH="$2"; shift 2 ;;
    --session-id) SESSION_ID="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ! -f "$STATE_PATH" ]]; then
  echo "ERROR: --state path does not exist: $STATE_PATH" >&2
  exit 1
fi
if ! jq -e 'type == "object"' "$STATE_PATH" >/dev/null 2>&1; then
  echo "ERROR: --state path is not a JSON object: $STATE_PATH" >&2
  exit 1
fi
if [[ "$DRY_RUN" -eq 0 && -z "$SESSION_ID" ]]; then
  echo "ERROR: --session-id is required for a real (non-dry-run) write" >&2
  exit 1
fi
if [[ -z "$RETAINED_PATH" ]]; then
  RETAINED_PATH="$(dirname "$STATE_PATH")/archive/roadmap-retained-prose-$(date +%Y%m%d).md"
fi

ms_count="$(jq -r '(.roadmap_milestones // []) | length' "$STATE_PATH")"
flat_count="$(jq -r '(.roadmap_batches // []) | length' "$STATE_PATH")"
if [[ "$ms_count" -gt 0 && "$FORCE" -ne 1 ]]; then
  echo "ERROR: roadmap_milestones already has $ms_count entries; this store is already migrated. Refusing without --force." >&2
  exit 2
fi

# The single neutral milestone is written when there are flat batches to carry, or when the
# store has no milestone at all. A --force run over an already-migrated store with no flat
# batches left keeps its milestones and only processes the file.
WRAP=false
if [[ "$flat_count" -gt 0 || "$ms_count" -eq 0 ]]; then
  WRAP=true
fi

layout="$(roadmap_preflight_classify "$ROADMAP_PATH")"

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# The file's lines, as a JSON array. A generated or absent file contributes no authored line.
case "$layout" in
  classic|stage|unknown)
    jq -R -s 'split("\n") | if (.[-1] // "") == "" then .[:-1] else . end' "$ROADMAP_PATH" \
      > "$WORKDIR/lines.json"
    ;;
  *)
    echo '[]' > "$WORKDIR/lines.json"
    ;;
esac

# ─── Prerequisite: a hand-authored ## Next that was never moved into state ────────────────────
if [[ "$layout" == "classic" && "$flat_count" -eq 0 && "$ms_count" -eq 0 ]]; then
  if awk '
      $0 == "## Next" { printing = 1; next }
      printing && /^## / { exit }
      printing && /^\*\*Coverage appendix \(uncovered tasks\)\*\*:$/ { exit }
      printing && /^\/orchestrate / { found = 1 }
      END { exit (found ? 0 : 1) }
    ' "$ROADMAP_PATH"; then
    echo "ERROR: ${ROADMAP_PATH} carries a hand-authored ## Next (it holds /orchestrate lines) while" >&2
    echo "       roadmap_batches is empty. Run migrate-roadmap-next-to-state.sh first so those batches" >&2
    echo "       are in state, then run this script again." >&2
    exit 3
  fi
fi

# ─── Shared jq definitions ────────────────────────────────────────────────────────────────────
# shellcheck disable=SC2016  # $-prefixed names below are jq variables, not shell expansions
MIGRATE_JQ_DEFS='
def blank: test("^\\s*$");
def trim: sub("^\\s+"; "") | sub("\\s+$"; "");
def marker: test("^([-*]|[0-9]+\\.) ");
def unmark: sub("^([-*]|[0-9]+\\.)\\s+"; "");
def trimblank:
  map(blank | not) as $nb
  | ($nb | index(true)) as $first
  | if $first == null then [] else .[$first:(($nb | rindex(true)) + 1)] end;
# sections: array of file lines -> [{header: null | "## ...", lines: [...]}]; entry 0 is the
# preamble (header null). A leading "# " title line is structural and is dropped.
def sections:
  (if ((.[0] // "") | test("^# ")) then .[1:] else . end)
  | reduce .[] as $l ([{header: null, lines: []}];
      if ($l | test("^## ")) then . + [{header: $l, lines: []}]
      else .[-1].lines += [$l] end);
# blocks: lines -> [{kind: "item" | "prose", lines: [...]}]. A blank line ends a block; a line
# starting at column 0 with a list marker starts an item; any other line continues the current
# block or starts a prose block.
def blocks:
  reduce .[] as $l ({done: [], cur: null};
    if ($l | blank) then (if .cur then (.done += [.cur] | .cur = null) else . end)
    elif ($l | marker) then ((if .cur then .done += [.cur] else . end) | .cur = {kind: "item", lines: [$l]})
    elif .cur then .cur.lines += [$l]
    else .cur = {kind: "prose", lines: [$l]} end)
  | if .cur then .done + [.cur] else .done end;
def blocktext:
  .kind as $k | (.lines | map(trim)) | (if $k == "item" then (.[0] |= unmark) else . end) | join(" ");
def has_orchestrate_fence:
  (reduce .[] as $l ({in: false, found: false};
     if ($l | test("^```")) then .in = (.in | not)
     elif (.in and ($l | test("^/orchestrate "))) then .found = true
     else . end)) | .found;
# role: what happens to one section, given the layout.
#   goals | rules | conventions  -> blocks go to that state array (over-bound ones are retained)
#   retain                       -> the whole section is retained verbatim
#   generated                    -> rendered from state; not accounted, not retained
def role($layout; $runorder; $i):
  if $layout == "classic" then
    ( if .header == "## Goal" then "goals"
      elif .header == "## Standing rules" then "rules"
      elif (.header == "## Checks before and after every call"
            or .header == "## Settled decisions (do not re-litigate)") then "conventions"
      elif (.header == "## Next" or .header == "## Open work") then "generated"
      else "retain" end )
  elif ($layout == "stage" and $runorder == $i) then "generated"
  else "retain" end;
# runorder: index of the stage layout run-order section when it is rendered from existing
# batches, else -1.
def runorder($layout; $has_batches):
  if ($layout == "stage" and $has_batches) then
    ([to_entries[] | select(.value.lines | has_orchestrate_fence) | .key] | (.[0] // -1))
  else -1 end;
def retained_header: if .header == null then "(preamble)" else (.header | sub("^## "; "")) end;
# msub($b): multiset difference, the elements of the input array not matched one for one in $b.
def msub($b):
  reduce .[] as $x ({cnt: ($b | group_by(.) | map({key: .[0], value: length}) | from_entries), out: []};
    if ((.cnt[$x] // 0) > 0) then .cnt[$x] -= 1 else .out += [$x] end) | .out;
'

# ─── Step 1: the plan -- where every block goes ───────────────────────────────────────────────
# shellcheck disable=SC2016
jq -n --slurpfile lines "$WORKDIR/lines.json" --arg layout "$layout" \
  --argjson has_batches "$([[ "$flat_count" -gt 0 ]] && echo true || echo false)" \
  --argjson goal_bound "$GOAL_BOUND" --argjson context_bound "$CONTEXT_BOUND" \
  "${MIGRATE_JQ_DEFS}"'
  ($lines[0] | sections) as $secs
  | ($secs | runorder($layout; $has_batches)) as $ro
  | reduce ($secs | to_entries[]) as $e
      ({goals: [], rules: [], conventions: [], retained: [], warns: []};
       ($e.value | role($layout; $ro; $e.key)) as $role
       | ($e.value | retained_header) as $h
       | if $role == "generated" then .
         elif $role == "retain" then
           ($e.value.lines | trimblank) as $body
           | if ($body | length) == 0 then . else .retained += [{header: $h, blocks: [$body]}] end
         else
           (if $role == "goals" then $goal_bound else $context_bound end) as $bound
           | reduce ($e.value.lines | blocks[]) as $b (.;
               ($b | blocktext) as $text
               | if ($role != "goals" and $b.kind == "prose") then
                   .retained += [{header: $h, blocks: [$b.lines]}]
                 elif ($text | length) > $bound then
                   .retained += [{header: $h, blocks: [$b.lines]}]
                   | .warns += ["over-bound item retained whole (" + ($text | length | tostring)
                                + " > " + ($bound | tostring) + " characters, from " + $h + "): "
                                + ($text[0:70]) + "..."]
                 else
                   .[$role] += [{text: $text, kind: $b.kind, orig: ($b.lines | map(trim))}]
                 end)
         end)
  # one retained entry per header, blocks in file order
  | .retained |= (reduce .[] as $r ([];
      if (length > 0 and .[-1].header == $r.header) then .[-1].blocks += $r.blocks
      else . + [$r] end))
' > "$WORKDIR/plan.json"

# ─── Step 2: the proposed state (the same filter the real write applies) ──────────────────────
# shellcheck disable=SC2016
STATE_FILTER='
  (if ($goals | length) > 0 then .primary_goals = ((.primary_goals // []) + $goals) else . end)
  | (if ($rules | length) > 0
     then .roadmap_context = ((.roadmap_context // {}) | .rules = ((.rules // []) + $rules))
     else . end)
  | (if ($conventions | length) > 0
     then .roadmap_context = ((.roadmap_context // {}) | .conventions = ((.conventions // []) + $conventions))
     else . end)
  | (if $wrap then
       .roadmap_milestones = [ { id: $mid, title: $mtitle, aim: $maim,
                                 progress: {status: "active"}, review: {state: "none"},
                                 batches: (.roadmap_batches // []) } ]
     else . end)
  | del(.roadmap_batches, .roadmap_notes)
'
goals_json="$(jq -c '[.goals[].text]' "$WORKDIR/plan.json")"
rules_json="$(jq -c '[.rules[].text]' "$WORKDIR/plan.json")"
conventions_json="$(jq -c '[.conventions[].text]' "$WORKDIR/plan.json")"
STATE_FILTER_ARGS=(
  --argjson goals "$goals_json" --argjson rules "$rules_json"
  --argjson conventions "$conventions_json" --argjson wrap "$WRAP"
  --arg mid "$MILESTONE_ID" --arg mtitle "$MILESTONE_TITLE" --arg maim "$MILESTONE_AIM"
)
jq "${STATE_FILTER_ARGS[@]}" "$STATE_FILTER" "$STATE_PATH" > "$WORKDIR/new-state.json"

# ─── Step 3: stage the retained-prose file ────────────────────────────────────────────────────
# shellcheck disable=SC2016
jq -r --slurpfile plan "$WORKDIR/plan.json" --arg date "$(date +%Y-%m-%d)" \
  --arg roadmap "$ROADMAP_PATH" '
  ($plan[0].retained) as $ret
  | ( (.roadmap_notes // {}) | if type == "object" then . else {} end
      | to_entries
      | map(select((.value | type) == "array")
            | {header: ("roadmap_notes." + .key),
               blocks: [.value[] | select(type == "string") | split("\n")]}
            | select((.blocks | length) > 0)) ) as $notes
  | if (($ret | length) + ($notes | length)) == 0 then empty
    else
      "# Roadmap retained prose",
      "",
      ("Retained verbatim by migrate-roadmap-to-milestones.sh on " + $date + " from `" + $roadmap
       + "` and its state file. Nothing in this file is rendered into the roadmap."),
      "",
      ( ($ret + $notes)[]
        | "## " + .header, "",
          ( .blocks[] | (.[]), "" ) )
    end
' "$STATE_PATH" > "$WORKDIR/retained.md"

HAS_RETAINED=0
[[ -s "$WORKDIR/retained.md" ]] && HAS_RETAINED=1
jq -R -s 'split("\n") | if (.[-1] // "") == "" then .[:-1] else . end' "$WORKDIR/retained.md" \
  > "$WORKDIR/retained-lines.json"

# ─── Step 4: the losslessness gate ────────────────────────────────────────────────────────────
jq -S -c '.roadmap_batches // []' "$STATE_PATH" > "$WORKDIR/batches-before.json"
jq -S -c '[(.roadmap_milestones // [])[] | (.batches // [])[]]' "$WORKDIR/new-state.json" \
  > "$WORKDIR/batches-after.json"
BATCHES_EQUAL=true
if [[ "$WRAP" == "true" ]] && ! cmp -s "$WORKDIR/batches-before.json" "$WORKDIR/batches-after.json"; then
  BATCHES_EQUAL=false
fi

# shellcheck disable=SC2016
jq -n --slurpfile lines "$WORKDIR/lines.json" --slurpfile ret "$WORKDIR/retained-lines.json" \
  --slurpfile plan "$WORKDIR/plan.json" --slurpfile old "$STATE_PATH" \
  --slurpfile new "$WORKDIR/new-state.json" --arg layout "$layout" \
  --argjson has_batches "$([[ "$flat_count" -gt 0 ]] && echo true || echo false)" \
  --argjson batches_equal "$BATCHES_EQUAL" \
  "${MIGRATE_JQ_DEFS}"'
  ($lines[0] | sections) as $secs
  | ($secs | runorder($layout; $has_batches)) as $ro
  # A: every non-blank line outside generated regions, trimmed
  | [ $secs | to_entries[]
      | .key as $k
      | select((.value | role($layout; $ro; $k)) != "generated")
      | .value.lines[] | select(blank | not) | trim ] as $src
  # the staged retained file, read back: sections after the front matter
  | ( $ret[0]
      | reduce .[] as $l ([];
          if ($l | test("^## ")) then . + [{header: $l, lines: []}]
          elif length == 0 then .
          else .[-1].lines += [$l] end) ) as $rsecs
  | [ $rsecs[] | select(.header | startswith("## roadmap_notes.") | not)
      | .lines[] | select(blank | not) | trim ] as $ret_lines
  | [ $rsecs[] | select(.header | startswith("## roadmap_notes."))
      | .lines[] | select(blank | not) | trim ] as $ret_notes
  | [ $plan[0] | (.goals, .rules, .conventions)[] | .orig[] ] as $state_lines
  | ($ret_lines + $state_lines) as $dst
  | [ ($old[0].roadmap_notes // {}) | if type == "object" then . else {} end
      | .[] | select(type == "array") | .[] | select(type == "string")
      | split("\n")[] | select(blank | not) | trim ] as $notes
  | ($old[0]) as $o | ($new[0]) as $n
  | [ ($src | msub($dst))[] | "source line with no destination: " + . ]
    + [ ($dst | msub($src))[] | "destination line with no source: " + . ]
    + [ ($notes | msub($ret_notes))[] | "roadmap_notes line not retained: " + . ]
    + [ ($ret_notes | msub($notes))[] | "retained roadmap_notes line with no source: " + . ]
    + [ ( {key: "goals", base: (($o.primary_goals // []) | length), arr: ($n.primary_goals // [])},
          {key: "rules", base: (($o.roadmap_context.rules // []) | length), arr: ($n.roadmap_context.rules // [])},
          {key: "conventions", base: (($o.roadmap_context.conventions // []) | length), arr: ($n.roadmap_context.conventions // [])} )
        | . as $t
        | ($plan[0][$t.key] | to_entries[])
        | . as $it
        | ($it.value | (.orig | (if $it.value.kind == "item" then (.[0] |= unmark) else . end) | join(" "))) as $expect
        | select(($t.arr[$t.base + $it.key] // null) != $expect or $it.value.text != $expect)
        | "state item mismatch in " + $t.key + "[" + (($t.base + $it.key) | tostring) + "]: " + $expect[0:70] ]
    + (if $batches_equal then [] else ["batch accounting: the flat roadmap_batches array and the flattened nested batches differ"] end)
    + (if (($n | has("roadmap_batches")) or ($n | has("roadmap_notes")))
       then ["the proposed state still carries a flat roadmap key"] else [] end)
  | { ok: (length == 0), problems: .,
      src: ($src | length), retained: ($ret_lines | length), state: ($state_lines | length),
      notes: ($notes | length) }
' > "$WORKDIR/gate.json"

# ─── Step 5: report ───────────────────────────────────────────────────────────────────────────
nested_count="$(jq -r 'length' "$WORKDIR/batches-after.json")"
echo "Layout of ${ROADMAP_PATH}: ${layout}"
if [[ "$WRAP" == "true" ]]; then
  echo "Batches: ${flat_count} flat -> ${nested_count} under milestone ${MILESTONE_ID} (\"${MILESTONE_TITLE}\")"
else
  echo "Batches: no flat batches; existing roadmap_milestones kept (${nested_count} nested batches)"
fi
echo "Placed in state: primary_goals +$(jq -r '.goals | length' "$WORKDIR/plan.json"), roadmap_context.rules +$(jq -r '.rules | length' "$WORKDIR/plan.json"), roadmap_context.conventions +$(jq -r '.conventions | length' "$WORKDIR/plan.json")"
echo "Retained prose: $(jq -r '.retained' "$WORKDIR/gate.json") file lines and $(jq -r '.notes' "$WORKDIR/gate.json") roadmap_notes lines -> ${RETAINED_PATH}"
jq -r '.warns[] | "WARN: " + .' "$WORKDIR/plan.json" >&2

if [[ "$(jq -r '.ok' "$WORKDIR/gate.json")" != "true" ]]; then
  echo "ERROR: losslessness accounting FAILED -- nothing was written:" >&2
  jq -r '.problems[] | "  " + .' "$WORKDIR/gate.json" >&2
  exit 1
fi
echo "Losslessness accounting PASSED: $(jq -r '.src' "$WORKDIR/gate.json") source lines = $(jq -r '.retained' "$WORKDIR/gate.json") retained + $(jq -r '.state' "$WORKDIR/gate.json") in state; $(jq -r '.notes' "$WORKDIR/gate.json") roadmap_notes lines retained; batches structurally equal."

if [[ "$HAS_RETAINED" -eq 1 && -e "$RETAINED_PATH" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "WARN: the retained-prose target already exists and a real run would refuse: ${RETAINED_PATH}" >&2
  else
    echo "ERROR: the retained-prose target already exists; it is never overwritten: ${RETAINED_PATH}" >&2
    echo "       Name another file with --retained. Nothing was written." >&2
    exit 2
  fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo
  echo "=== Proposed primary_goals additions ==="
  jq -r '.goals[] | "- " + .text' "$WORKDIR/plan.json"
  echo "=== Proposed roadmap_context.rules additions ==="
  jq -r '.rules[] | "- " + .text' "$WORKDIR/plan.json"
  echo "=== Proposed roadmap_context.conventions additions ==="
  jq -r '.conventions[] | "- " + .text' "$WORKDIR/plan.json"
  echo
  echo "--dry-run: writing nothing."
  exit 0
fi

# ─── Step 6: write -- retained prose first, then state, then the generated file ───────────────
# The retained file goes first so no prose exists only in memory once state has changed.
if [[ "$HAS_RETAINED" -eq 1 ]]; then
  mkdir -p "$(dirname "$RETAINED_PATH")"
  cp "$WORKDIR/retained.md" "$RETAINED_PATH"
  echo "Wrote retained prose to ${RETAINED_PATH}."
fi

bash "${SCRIPT_DIR}/state-write.sh" "$STATE_FILTER" \
  --session-id "$SESSION_ID" "${STATE_FILTER_ARGS[@]}" --state-file "$STATE_PATH"
echo "Wrote the milestone shape to ${STATE_PATH} and deleted the flat roadmap keys."

"${SCRIPT_DIR}/roadmap-integration.sh" --print --state "$STATE_PATH" --roadmap "$ROADMAP_PATH" \
  > "$WORKDIR/generated.md" 2>"$WORKDIR/render-stderr.txt" || {
    echo "ERROR: state was migrated but rendering failed; ${ROADMAP_PATH} was left as it was:" >&2
    cat "$WORKDIR/render-stderr.txt" >&2
    exit 1
  }
mkdir -p "$(dirname "$ROADMAP_PATH")"
cp "$WORKDIR/generated.md" "${ROADMAP_PATH}.migrating"
mv "${ROADMAP_PATH}.migrating" "$ROADMAP_PATH"
echo "Wrote the generated roadmap to ${ROADMAP_PATH}."
