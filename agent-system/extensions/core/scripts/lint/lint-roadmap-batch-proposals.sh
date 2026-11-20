#!/usr/bin/env bash
# lint-roadmap-batch-proposals.sh - ADVISORY lint over the authored roadmap entries in a
# repository's specs/state.json: the batches nested under `roadmap_milestones`, and the bounded
# prose fields rendered into specs/ROADMAP.md beside them.
#
# INPUT IS STATE, NEVER THE RENDERED FILE
# ---------------------------------------
# specs/ROADMAP.md is wholly generated from specs/state.json, so the authored batch proposals
# live in state and that is what this script reads. Batches are read through
# scripts/lib/roadmap-entries-lib.sh: the batches of every non-closed milestone in
# milestone-then-batch order, or the flat `roadmap_batches` array of a store that carries no
# `roadmap_milestones` key. This script never opens, parses, or needs specs/ROADMAP.md.
#
# ADVISORY CONTRACT (read this before reading anything else in this file)
# -------------------------------------------------------------------------
# The exit code is NEVER affected by findings: exit 0 means the scan completed, not that
# nothing was found. WHY: an authored roadmap batch is never dispatched by being written down,
# so an under-inclusive batch causes no silent concurrent write -- the real admission gate
# (orchestrate-batch-admit.sh, the dependency-graph eligibility gate, and the write-time cycle
# refusal in update-task-status.sh's --depends-on-add) still fires at dispatch time regardless
# of anything this lint does or does not report. This lint exists to catch an under-inclusive
# batch at AUTHORING time instead of only at dispatch -- or never -- not to gate anything.
#
# DELIBERATE DIVERGENCE FROM SIBLING LINTS: every other scripts/lint/*.sh in this extension
# exits 1 on a violation. This script never does -- there is no exit 1 at all. Pin a test
# asserting exit 0 with findings present if this divergence is ever questioned.
#
# VALIDATOR, NEVER PROPOSER: this script validates a batch that was already authored. It must
# NEVER author, suggest, rank, or print a trimmed/corrected batch. Batch *selection* is the
# territory of scripts/orchestrate-suggest-next-batch.sh and roadmap-agent; a second copy of an
# admission predicate drifts from the real one. Every finding below states a fact about the
# batch as authored; none of them emits a replacement batch.
#
# ABSENT-file_scope POSTURE: an absent or empty `file_scope` on a candidate task is treated as
# "no evidence of overlap" -- finding (a) cannot fire using such a task as either side of a
# comparison. This mirrors docs/architecture/batch-admit-schema.md's `absent_scope_advisory`
# ruling, which this script does not itself implement but adopts the same posture as.
#
# FINDINGS IMPLEMENTED (all advisory):
#   (a) a non-terminal task whose declared file_scope overlaps an in-batch task but which is
#       absent from that batch (territory under-inclusion -- the primary finding).
#   (c) a batch's task_ids count exceeds MAX_TASKS=8 (commands/orchestrate.md's "MAX_TASKS
#       Guard"; contract: docs/architecture/orchestrate-state-machine.md's "Batch Size Cap").
#   (f) a repository path cited in backticks inside one of the bounded roadmap string fields
#       (primary_goals; a milestone's title, aim, gate and progress.note; a batch's
#       description; roadmap_context's overview, rules and conventions; a task's
#       roadmap_annotation) that does not resolve on disk.
#
# NOT A FINDING HERE: a terminal or unresolvable batch member. validate-state.sh Check 13 owns
# member integrity (abandoned / expanded members, terminal members of a closed milestone,
# members found in neither the active list nor the archive); a second report from this lint
# would only disagree with it over time.
#
# REJECTED BY DESIGN and intentionally absent: "a non-terminal dependent of an in-batch
# prerequisite that is absent from the batch". An intra-batch dependencies[] edge is never, by
# itself, grounds to flag a batch as defective -- /orchestrate performs dependency-aware wave
# dispatch, so such an edge merely sequences the two tasks into successive waves.
#
# KNOWN RESIDUAL NOISE in finding (f), stated plainly rather than hidden: a citation that drops
# MORE than the "agent-system/extensions/<ext>/" prefix this script's extra resolution roots
# account for -- e.g. "scripts/" additionally dropped ("lib/foo.sh" for "scripts/lib/foo.sh"),
# or the per-extension directory name itself dropped -- still reports as unresolved. Also
# residual: a placeholder word that is not one of the bracketed/glob tokens filtered below (e.g.
# "hooks/NAME.sh"), and a transient runtime path that only exists conditionally (e.g.
# "specs/.gate-lock", a lock file present only while held).
#
# LOCATION LABELS: a batch finding is prefixed `[milestone ID batch N]` (N is the batch's
# 1-based position inside its milestone), or `[batch N]` for the flat shape. A finding (f) is
# prefixed with the state path of the field carrying the citation.
#
# Usage: lint-roadmap-batch-proposals.sh [--verbose] [--state PATH]
#   --verbose     Print additional diagnostic detail (per-finding path detail, finding (f)'s
#                 skipped-cross-repo and skipped-shorthand counts).
#   --state PATH  Path to state.json (default: specs/state.json under the resolved repo root).
#
# Exit codes:
#   0 - the scan completed (findings or not -- see the Advisory Contract above).
#   2 - usage or environment error only (missing jq, unreadable state file). There is no
#       exit 1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/../lib/common.sh" ]]; then
  echo "ERROR: shared library not found at ${SCRIPT_DIR}/../lib/common.sh" >&2
  exit 2
fi
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# Sourced via `if ! . file; then ...; fi` rather than a bare `source` -- file-scope-overlap.sh's
# own `read -r -d '' FILE_SCOPE_OVERLAP_JQ_DEFS <<'JQDEFS'` heredoc assignment always returns
# exit status 1 at EOF (no literal NUL in the heredoc), even though it reads the full content
# successfully. Under this script's own `set -e`, an unguarded `source` would abort right there
# -- running that command as an `if` condition suspends -e checking for its entire execution
# (matching task-lock.sh's and orchestrate-batch-admit.sh's identical guard around this same
# library), so the transient 1 from the read is never seen as a script-ending failure.
if [[ ! -f "${SCRIPT_DIR}/../lib/file-scope-overlap.sh" ]]; then
  echo "ERROR: shared library not found at ${SCRIPT_DIR}/../lib/file-scope-overlap.sh" >&2
  exit 2
fi
# shellcheck source=../lib/file-scope-overlap.sh
if ! . "${SCRIPT_DIR}/../lib/file-scope-overlap.sh" 2>/dev/null; then
  echo "ERROR: could not source ${SCRIPT_DIR}/../lib/file-scope-overlap.sh" >&2
  exit 2
fi

# roadmap-entries-lib.sh is the one accessor for the ordered authored-batch list (milestone
# shape, flat fallback). Never re-inline a copy of that question here.
if [[ ! -f "${SCRIPT_DIR}/../lib/roadmap-entries-lib.sh" ]]; then
  echo "ERROR: shared library not found at ${SCRIPT_DIR}/../lib/roadmap-entries-lib.sh" >&2
  exit 2
fi
# shellcheck source=../lib/roadmap-entries-lib.sh
source "${SCRIPT_DIR}/../lib/roadmap-entries-lib.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not found on PATH" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Root resolution: dual-mode probe (deployed .claude/scripts/lint/, or source-store
# agent-system/extensions/core/scripts/lint/), keyed on the presence of a `specs/` directory --
# the actual target this script reads from, unlike lint-task-lookup-adoption.sh's
# `agent-system/extensions` marker (which keys on the extension tree it scans instead). Mirrors
# that script's walk-up shape.
# ---------------------------------------------------------------------------
resolve_project_root() {
  local candidate
  candidate="$(common_repo_root "$SCRIPT_DIR" 3)"
  if [[ -n "$candidate" && -d "$candidate/specs" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  local dir="$SCRIPT_DIR"
  local i=0
  while [[ $i -lt 8 ]]; do
    dir="$(cd "$dir/.." 2>/dev/null && pwd)" || break
    [[ -z "$dir" || "$dir" == "/" ]] && break
    if [[ -d "$dir/specs" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    i=$((i + 1))
  done

  printf '%s\n' "$candidate"
  return 0
}

PROJECT_ROOT="$(resolve_project_root)"
STATE_PATH="${PROJECT_ROOT}/specs/state.json"
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=true
      shift
      ;;
    --state)
      STATE_PATH="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,73p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$STATE_PATH" ]]; then
  echo "ERROR: state file not found: $STATE_PATH" >&2
  exit 2
fi
if ! jq empty "$STATE_PATH" >/dev/null 2>&1; then
  echo "ERROR: state file is not valid JSON: $STATE_PATH" >&2
  exit 2
fi

MAX_TASKS=8
SHAPE="$(roadmap_entries_shape "$STATE_PATH")"

# ---------------------------------------------------------------------------
# Authored batches, through the accessor. One entry per batch, index-aligned:
#   BATCH_LABELS[i]  the finding prefix (`milestone ID batch N`, or `batch N` for the flat shape)
#   BATCH_IDS[i]     the batch's task ids as a compact JSON array
# ---------------------------------------------------------------------------
BATCH_LABELS=()
BATCH_IDS=()
while IFS=$'\t' read -r b_label b_ids; do
  [[ -z "$b_label" ]] && continue
  BATCH_LABELS+=("$b_label")
  BATCH_IDS+=("$b_ids")
done < <(roadmap_entries_batches "$STATE_PATH" | jq -r '
  [ (if .milestone == null then "batch \(.ordinal)" else "milestone \(.milestone) batch \(.ordinal)" end),
    ((.task_ids // []) | map(select(type == "number")) | tojson) ] | @tsv')

FINDINGS_TOTAL=0

# ---------------------------------------------------------------------------
# Finding (c): a batch's task-id count exceeds MAX_TASKS.
# ---------------------------------------------------------------------------
for i in "${!BATCH_IDS[@]}"; do
  count="$(jq -n --argjson ids "${BATCH_IDS[$i]}" '$ids | length')"
  if [[ "$count" -gt "$MAX_TASKS" ]]; then
    FINDINGS_TOTAL=$((FINDINGS_TOTAL + 1))
    echo "[${BATCH_LABELS[$i]}] FINDING (c): batch has $count tasks, exceeds MAX_TASKS=$MAX_TASKS. Any trim must list territory-mandatory groups first so the cut never splits one off the end (see context/patterns/batch-orchestration-guardrails.md's truncation-precedence rule). This lint does not propose a trimmed batch."
  fi
done

# ---------------------------------------------------------------------------
# Finding (f): a repository path cited in backticks inside a bounded roadmap string field that
# does not resolve on disk. The scan covers exactly the string fields named in the header --
# the prose roadmap-integration.sh renders -- one "state-path<TAB>text" record per field.
#
# RESOLUTION ROOTS: roadmap prose cites paths relative to several different roots without a
# prefix disambiguating which -- `commands/orchestrate.md` (the deployed .claude/ tree) and
# `core/docs/fork-patterns.md` (a source-store path with the "agent-system/extensions/" prefix
# dropped but the per-extension directory name kept as the candidate's own first segment). A
# candidate is reported ONLY when it resolves under NONE of: PROJECT_ROOT itself;
# PROJECT_ROOT/.claude (the deployed tree, when present); or
# PROJECT_ROOT/agent-system/extensions (the source-store extensions parent, when present).
# ---------------------------------------------------------------------------
skipped_cross_repo=0
skipped_shorthand=0

RESOLUTION_ROOTS=("$PROJECT_ROOT")
[[ -d "${PROJECT_ROOT}/.claude" ]] && RESOLUTION_ROOTS+=("${PROJECT_ROOT}/.claude")
[[ -d "${PROJECT_ROOT}/agent-system/extensions" ]] && RESOLUTION_ROOTS+=("${PROJECT_ROOT}/agent-system/extensions")

candidate_resolves() {
  local cand="$1" root
  for root in "${RESOLUTION_ROOTS[@]}"; do
    [[ -e "${root}/${cand}" ]] && return 0
  done
  return 1
}

# shellcheck disable=SC2016  # $-prefixed names below are jq variables, not shell expansions
ROADMAP_FIELDS_JQ='
def rec($p; $v): select(($v | type) == "string" and ($v | length) > 0) | [$p, ($v | gsub("[\t\n\r]"; " "))] | @tsv;
( (.primary_goals // []) | to_entries[] | rec("primary_goals[\(.key)]"; .value) ),
( (.roadmap_milestones // []) | to_entries[] | .key as $i | .value as $m |
  ( rec("roadmap_milestones[\($i)].title"; $m.title),
    rec("roadmap_milestones[\($i)].aim"; $m.aim),
    rec("roadmap_milestones[\($i)].gate"; $m.gate),
    rec("roadmap_milestones[\($i)].progress.note"; $m.progress.note),
    ( ($m.batches // []) | to_entries[] | rec("roadmap_milestones[\($i)].batches[\(.key)].description"; .value.description) ) ) ),
( if has("roadmap_milestones") then empty else
    ( (.roadmap_batches // []) | to_entries[] | rec("roadmap_batches[\(.key)].description"; .value.description) ) end ),
( (.roadmap_context // {}) as $c | ("overview", "rules", "conventions") as $k |
  ( ($c[$k] // []) | to_entries[] | rec("roadmap_context.\($k)[\(.key)]"; .value) ) ),
( (.active_projects // [])[] | rec("active_projects[project_number=\(.project_number)].roadmap_annotation"; .roadmap_annotation) )
'

while IFS=$'\t' read -r field_path line; do
  [[ -z "$field_path" ]] && continue
  # Extract each `...` span in this field.
  rest="$line"
  while [[ "$rest" == *'`'* ]]; do
    rest="${rest#*\`}"
    [[ "$rest" == *'`'* ]] || break
    candidate="${rest%%\`*}"
    rest="${rest#*\`}"
    [[ -z "$candidate" ]] && continue

    # Not a bare-path citation at all: contains whitespace (a shell command or a prose
    # expression) rather than a single path token. Skipped silently -- a structural
    # precondition for "is this candidate shaped like a path".
    [[ "$candidate" == *[[:space:]]* ]] && continue

    # Elision marker: a literal "..." abbreviates a path prefix, never a real citation.
    [[ "$candidate" == *'...'* ]] && continue

    # Guard 1: must carry path structure (at least one '/') to count as a citation at all --
    # a bare backticked basename (ci.yml, MintBound.lean) is prose shorthand, never reported.
    # A candidate that is exactly ONE segment plus a trailing slash (e.g. "lint/", quoting a
    # path SEGMENT name under discussion) carries no more real path structure than a bare
    # basename and is treated identically.
    if [[ "$candidate" != */* ]] || [[ "$candidate" =~ ^[^/]+/$ ]]; then
      skipped_shorthand=$((skipped_shorthand + 1))
      continue
    fi

    # Skip placeholder/glob tokens -- never a concrete citation.
    case "$candidate" in
      *'{'*|*'}'*|*'*'*|*'<'*) continue ;;
    esac

    # Guard 2: a path qualified for another repository (leading ~/ or leading /) is skipped
    # explicitly and counted, never resolved against the local root.
    # shellcheck disable=SC2088  # deliberate literal-tilde case pattern, not an expansion site
    case "$candidate" in
      '~/'*|'/'*)
        skipped_cross_repo=$((skipped_cross_repo + 1))
        continue
        ;;
    esac

    if ! candidate_resolves "$candidate"; then
      FINDINGS_TOTAL=$((FINDINGS_TOTAL + 1))
      echo "[$field_path] FINDING (f): cited path does not resolve: \`$candidate\`"
    fi
  done
done < <(jq -r "$ROADMAP_FIELDS_JQ" "$STATE_PATH" 2>/dev/null)

if $VERBOSE; then
  echo "INFO: finding (f) skipped $skipped_shorthand bare-basename candidate(s) and $skipped_cross_repo cross-repository candidate(s)." >&2
fi

# ---------------------------------------------------------------------------
# Finding (a): territory under-inclusion — the primary finding. A non-terminal task whose
# declared file_scope overlaps an in-batch task but which is absent from that batch.
#
# REAL OBSERVED FAILURE this finding exists for (recorded here so a reader of just this script
# understands the stakes): a task was REMOVED from an authored batch because it depended on another task already in that batch. That
# reasoning was wrong: /orchestrate performs dependency-aware wave dispatch, so an intra-batch
# dependencies[] edge merely sequences the two tasks into successive waves. The two tasks ALSO
# shared file
# territory (three files under one component's certificate/ directory), which under Rule 1
# (shared file territory is unconditional) makes batching them MANDATORY, not optional. Nothing
# caught either error at authoring time.
#
# This finding splices $FILE_SCOPE_OVERLAP_JQ_DEFS (norm, scopes_overlap_first) into ONE jq -n
# program over the whole cross-product — the same shape orchestrate-batch-admit.sh
# uses — rather than a per-pair scopes_overlap() shell-out. Nothing about the overlap algorithm
# is restated, re-derived, or "improved" locally.
#
# SUPPRESSIONS (by construction, each for its own reason): a terminal candidate (nothing to
# batch); a candidate with an absent/empty file_scope (no evidence of overlap — this script's
# adopted absent-scope posture, see header); the task's own in-batch members (excluded from the
# candidate pool entirely). Deliberately NEVER suppressed: the presence of a dependencies[] edge
# between the candidate and an in-batch task — Rule 1's territory requirement is unconditional,
# and an edge-based suppression would re-admit exactly the reasoning the observed failure used.
#
# The reserved __WHOLE_TREE__ sentinel is inert against real paths under scopes_overlap_first
# (it has no '/' and so satisfies neither the exact-match nor the prefix-containment clause
# against anything other than another literal __WHOLE_TREE__ declarant) — a hit against it is
# the intended same-whole-tree-claim detection signal, not a false positive.
# ---------------------------------------------------------------------------
BATCHES_JSON='[]'
if [[ ${#BATCH_IDS[@]} -gt 0 ]]; then
  BATCHES_JSON="$(printf '%s\n' "${BATCH_IDS[@]}" | jq -c -s '.')"
fi

if [[ "$BATCHES_JSON" != "[]" ]]; then
  FINDING_A_JQ_PROGRAM='
def is_terminal: ascii_downcase as $s | ($s == "completed" or $s == "abandoned" or $s == "expanded");

($state_arr[0].active_projects // []) as $all |
($all | map({key: (.project_number|tostring), value: (.file_scope // [])}) | from_entries) as $scope_by_num |
$batches as $bs |
range(0; ($bs|length)) as $bi |
($bs[$bi]) as $batch_ids |
($all[] | select((.project_number as $pn | ($batch_ids | index($pn))) == null)) as $cand |
select(($cand.status // "") | is_terminal | not) |
select((($cand.file_scope // []) | length) > 0) |
( [ $batch_ids[] as $bnum |
    ($scope_by_num[$bnum|tostring] // []) as $bscope |
    select(($bscope | length) > 0) |
    scopes_overlap_first($cand.file_scope; $bscope) as $ov |
    select($ov != null and $ov != "") |
    {bnum: $bnum, path: $ov}
  ] | sort_by(.bnum)
) as $hits |
select(($hits | length) > 0) |
{run_line_index: $bi, absent: $cand.project_number, hits: $hits}
'
  finding_a_results="$(jq -n -c --argjson batches "$BATCHES_JSON" --slurpfile state_arr "$STATE_PATH" \
    "${FILE_SCOPE_OVERLAP_JQ_DEFS}${FINDING_A_JQ_PROGRAM}" 2>/dev/null)" || finding_a_results=""

  if [[ -n "$finding_a_results" ]]; then
    while IFS= read -r result_line; do
      [[ -z "$result_line" ]] && continue
      run_line_index="$(echo "$result_line" | jq -r '.run_line_index')"
      absent_task="$(echo "$result_line" | jq -r '.absent')"
      first_bnum="$(echo "$result_line" | jq -r '.hits[0].bnum')"
      first_path="$(echo "$result_line" | jq -r '.hits[0].path')"
      batch_label="${BATCH_LABELS[$run_line_index]}"
      FINDINGS_TOTAL=$((FINDINGS_TOTAL + 1))
      echo "[$batch_label] FINDING (a): task $absent_task is absent from this batch but its declared file_scope overlaps in-batch task $first_bnum at \`$first_path\`. Rule 1 (shared file territory) is unconditional and does not depend on topic cohesion; an intra-batch dependencies[] edge is never grounds to exclude a task."
      if $VERBOSE; then
        hit_count="$(echo "$result_line" | jq '.hits | length')"
        if [[ "$hit_count" -gt 1 ]]; then
          echo "$result_line" | jq -c '.hits[1:][]' | while IFS= read -r extra_hit; do
            extra_bnum="$(echo "$extra_hit" | jq -r '.bnum')"
            extra_path="$(echo "$extra_hit" | jq -r '.path')"
            echo "  [verbose] also overlaps in-batch task $extra_bnum at \`$extra_path\`"
          done
        fi
      fi
    done <<< "$finding_a_results"
  fi
fi

echo "---"
echo "Scan complete. shape=$SHAPE batches=${#BATCH_IDS[@]} findings=$FINDINGS_TOTAL"
exit 0
