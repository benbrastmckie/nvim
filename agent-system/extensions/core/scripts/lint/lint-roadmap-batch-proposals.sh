#!/usr/bin/env bash
# lint-roadmap-batch-proposals.sh - ADVISORY lint over hand-authored /orchestrate batch
# proposals in a repository's specs/ROADMAP.md.
#
# ADVISORY CONTRACT (read this before reading anything else in this file)
# -------------------------------------------------------------------------
# The exit code is NEVER affected by findings: exit 0 means the scan completed, not that
# nothing was found. WHY: a prose markdown file (specs/ROADMAP.md) is never dispatched, so an
# under-inclusive or malformed hand-authored batch causes no silent concurrent write -- the real
# admission gate (orchestrate-batch-admit.sh, the dependency-graph eligibility gate, and the
# write-time cycle refusal in update-task-status.sh's --depends-on-add) still fires at dispatch
# time regardless of anything this lint does or does not report. This lint exists to catch an
# under-inclusive batch at AUTHORING time instead of only at dispatch -- or never -- not to gate
# anything.
#
# DELIBERATE DIVERGENCE FROM SIBLING LINTS: every other scripts/lint/*.sh in this extension
# exits 1 on a violation. This script never does -- there is no exit 1 at all. This is a
# considered choice (see this task's own plan Risk table), not an oversight: pin a test
# asserting exit 0 with findings present if this divergence is ever questioned.
#
# VALIDATOR, NEVER PROPOSER: this script validates a batch a human already typed. It must NEVER
# author, suggest, rank, or print a trimmed/corrected batch. Batch *selection* is the territory
# of scripts/orchestrate-suggest-next-batch.sh and the topic-orchestrator work; a second copy of
# an admission predicate drifts from the real one. Every finding below states a fact about the
# batch as authored; none of them emits a replacement batch.
#
# ABSENT-file_scope POSTURE (recorded so the ruling can be reconciled later): an absent or empty
# `file_scope` on a candidate task is treated as "no evidence of overlap" -- finding (a) (Phase
# 3 of this script's own history) cannot fire using such a task as either side of a comparison.
# This mirrors docs/architecture/batch-admit-schema.md's v6 `absent_scope_advisory` ruling, which
# this script does not itself implement but adopts the same posture as.
#
# FINDING (f)'S SCAN SCOPE IS THE WHOLE FILE, not just the batch block, despite this script's
# batch-oriented name: a stale citation can appear anywhere in specs/ROADMAP.md (the "Gate
# state", "Open work", or any authored-verbatim section), not only inside a Run line.
#
# FINDINGS IMPLEMENTED (all advisory; see this task's own plan for the full rationale on each):
#   (c) a Run line's task-id count exceeds MAX_TASKS=8 (commands/orchestrate.md's "MAX_TASKS
#       Guard"; contract: docs/architecture/orchestrate-state-machine.md's "Batch Size Cap").
#   (d) a cited task id that resolves to nothing at all, or resolves to a terminal status
#       (completed/abandoned/expanded).
#   (f) a cited repository path (specs/{NNN}_{slug}/..., or any other path-shaped backtick
#       citation) that does not resolve on disk.
#   (a) is added in a later revision of this script (this task's Phase 3): a non-terminal task
#       whose declared file_scope overlaps an in-batch task but which is absent from that batch.
#
# A finding REJECTED BY DESIGN and intentionally absent from this script, by this task's own
# record: "a non-terminal dependent of an in-batch prerequisite that is absent from the batch"
# (would-be finding (b)). An intra-batch dependencies[] edge is never, by itself, grounds to flag
# a batch as defective -- /orchestrate performs dependency-aware wave dispatch, so such an edge
# merely sequences the two tasks into successive waves. See
# context/formats/roadmap-format.md's "Next Grammar" section for the declarative statement of
# this rule (finding (e) in this task's own record).
#
# LAYOUT SNIFF: transcribed from context/formats/roadmap-format.md's own prose predicates
# ("Classic layout" / "Stage layout" sections), never from scripts/roadmap-integration.sh (a
# monolithic executable that cannot be sourced). `classic` iff all eight literal CLASSIC_HEADERS
# are present; `stage` iff a `^## Stage [0-9]+` header is present AND some `## ` section's body
# holds a fenced code block containing at least one `^/orchestrate ` line; otherwise `unknown`.
# On `unknown`, this script emits one loud named stderr line and exits 0 -- never a silent
# no-op, and never a guess at one of the two recognised layouts.
#
# KNOWN RESIDUAL NOISE in finding (f), stated plainly rather than hidden: a citation that drops
# MORE than the "agent-system/extensions/<ext>/" prefix this script's extra resolution roots
# account for -- e.g. "scripts/" additionally dropped ("lib/foo.sh" for "scripts/lib/foo.sh"),
# or the per-extension directory name itself dropped ("root-files/settings.json" for
# "agent-system/extensions/core/root-files/settings.json") -- still reports as unresolved. Also
# residual: a placeholder word that is not one of the bracketed/glob tokens filtered below (e.g.
# "hooks/NAME.sh"), and a transient runtime path that only exists conditionally (e.g.
# "specs/.gate-lock", a lock file present only while held). These are not the two false-positive
# classes this task's acceptance criteria name (bare basename; cross-repo-qualified path, both
# handled below) and are not chased further here -- doing so risks over-fitting the guard logic
# to one corpus document's current prose rather than the general two-guard contract.
#
# FOLLOW-UP RISK (named here, not solved here): the task record `roadmap-as-generated-artifact`
# will move batch membership out of this file's hand-authored `## Next` prose into state.json
# entries, maintained by a future `/roadmap` command. When that lands, this script's entire
# parse layer (the Next Grammar Run-line regex below) needs rescoping against the new source of
# truth. This was a recorded, accepted follow-up cost at this script's own authoring time, not
# an oversight.
#
# Usage: lint-roadmap-batch-proposals.sh [--verbose] [--roadmap PATH] [--state PATH]
#   --verbose     Print additional diagnostic detail (per-finding path detail, finding (f)'s
#                 skipped-cross-repo and skipped-shorthand counts).
#   --roadmap PATH  Path to ROADMAP.md (default: specs/ROADMAP.md under the resolved repo root).
#   --state PATH    Path to state.json (default: specs/state.json under the resolved repo root).
#
# Exit codes:
#   0 - the scan completed (findings or not -- see the Advisory Contract above).
#   2 - usage or environment error only (missing jq, unreadable roadmap/state file). There is no
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

if [[ ! -f "${SCRIPT_DIR}/../lib/task-lookup-lib.sh" ]]; then
  echo "ERROR: shared library not found at ${SCRIPT_DIR}/../lib/task-lookup-lib.sh" >&2
  exit 2
fi
# shellcheck source=../lib/task-lookup-lib.sh
source "${SCRIPT_DIR}/../lib/task-lookup-lib.sh"

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
ROADMAP_PATH="${PROJECT_ROOT}/specs/ROADMAP.md"
STATE_PATH="${PROJECT_ROOT}/specs/state.json"
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=true
      shift
      ;;
    --roadmap)
      ROADMAP_PATH="$2"
      shift 2
      ;;
    --state)
      STATE_PATH="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,70p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$ROADMAP_PATH" ]]; then
  echo "ERROR: roadmap file not found: $ROADMAP_PATH" >&2
  exit 2
fi
if [[ ! -f "$STATE_PATH" ]]; then
  echo "ERROR: state file not found: $STATE_PATH" >&2
  exit 2
fi

MAX_TASKS=8

# ---------------------------------------------------------------------------
# Layout sniff — transcribed from context/formats/roadmap-format.md's prose predicates.
# ---------------------------------------------------------------------------
CLASSIC_HEADERS=(
  "## Goal"
  "## Gate state"
  "## Next"
  "## Open work"
  "## Checks before and after every call"
  "## Settled decisions (do not re-litigate)"
  "## Standing rules"
  "## Unfiled observations (none worth a task yet)"
)

is_classic_layout() {
  local header
  for header in "${CLASSIC_HEADERS[@]}"; do
    grep -qxF "$header" "$ROADMAP_PATH" || return 1
  done
  return 0
}

# is_stage_layout: a `^## Stage [0-9]+` header present AND some fenced code block (anywhere in
# the file -- every fenced block necessarily falls within the nearest preceding `## ` section
# once at least one `## ` header exists, which the Stage-header test already requires) contains
# at least one `^/orchestrate ` line.
is_stage_layout() {
  grep -qE '^## Stage [0-9]+' "$ROADMAP_PATH" || return 1
  local in_fence=false
  local line
  while IFS= read -r line; do
    if [[ "$line" =~ ^\`\`\` ]]; then
      if $in_fence; then in_fence=false; else in_fence=true; fi
      continue
    fi
    if $in_fence && [[ "$line" =~ ^/orchestrate\  ]]; then
      return 0
    fi
  done < "$ROADMAP_PATH"
  return 1
}

LAYOUT="unknown"
if is_classic_layout; then
  LAYOUT="classic"
elif is_stage_layout; then
  LAYOUT="stage"
fi

if [[ "$LAYOUT" == "unknown" ]]; then
  echo "NOTE: layout=unknown; no batch block parsed" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Authored Run-line extraction. Stops at the generated coverage appendix header -- everything
# below it is machine output from scripts/roadmap-integration.sh and must never be linted.
# ---------------------------------------------------------------------------
# Run-line grammar, per context/formats/roadmap-format.md's "Next Grammar" section:
#   ^/orchestrate ([\d, ]+)(\s+(-\S.*?))?(\s{3}# (.+))?$
# Translated to a bash/ERE-compatible pattern (\d -> [0-9], \s -> [[:space:]]; the grammar is
# unchanged, only the regex-engine spelling). Capture groups: 1=task_list, 3=flags (optional),
# 5=rationale (optional).
RUN_LINE_RE='^/orchestrate ([0-9, ]+)([[:space:]]+(-[^[:space:]].*))?([[:space:]]{3}# (.+))?$'
COVERAGE_HEADER_RE='^\*\*Coverage appendix \(uncovered tasks\)\*\*:$'

# Section boundary (`^## ` header) used to find the target section's line range.
SECTION_HEADER_RE='^## '

section_start_line=0
section_end_line=0

if [[ "$LAYOUT" == "classic" ]]; then
  section_start_line="$(grep -nxF '## Next' "$ROADMAP_PATH" | head -1 | cut -d: -f1)"
else
  # stage: the run-order section is the FIRST `## ` section (in file order) whose own body
  # (before the next `## ` header) holds a fenced block containing an `^/orchestrate ` line.
  total_lines="$(wc -l < "$ROADMAP_PATH")"
  mapfile -t header_lines < <(grep -nE "$SECTION_HEADER_RE" "$ROADMAP_PATH" | cut -d: -f1)
  for idx in "${!header_lines[@]}"; do
    hl="${header_lines[$idx]}"
    if [[ $((idx + 1)) -lt ${#header_lines[@]} ]]; then
      next_hl=${header_lines[$((idx + 1))]}
      body_end=$((next_hl - 1))
    else
      body_end="$total_lines"
    fi
    if sed -n "$((hl + 1)),${body_end}p" "$ROADMAP_PATH" | grep -qE '^/orchestrate ' ; then
      # Confirm the /orchestrate line found is actually inside a fence within this section
      # (reuse the same fence-tracking scan, scoped to this section's body).
      in_fence=false
      found_fenced=false
      while IFS= read -r line; do
        if [[ "$line" =~ ^\`\`\` ]]; then
          if $in_fence; then in_fence=false; else in_fence=true; fi
          continue
        fi
        if $in_fence && [[ "$line" =~ ^/orchestrate\  ]]; then
          found_fenced=true
        fi
      done < <(sed -n "$((hl + 1)),${body_end}p" "$ROADMAP_PATH")
      if $found_fenced; then
        section_start_line="$hl"
        section_end_line="$body_end"
        break
      fi
    fi
  done
fi

if [[ "$section_start_line" -eq 0 ]]; then
  echo "NOTE: layout=$LAYOUT but no batch block section could be located; no batch block parsed" >&2
  exit 0
fi

if [[ "$section_end_line" -eq 0 ]]; then
  # classic: section runs from section_start_line+1 to the next `## ` header (exclusive) or EOF.
  total_lines="$(wc -l < "$ROADMAP_PATH")"
  next_header_line="$(tail -n "+$((section_start_line + 1))" "$ROADMAP_PATH" | grep -nE "$SECTION_HEADER_RE" | head -1 | cut -d: -f1 || true)"
  if [[ -n "$next_header_line" ]]; then
    section_end_line=$((section_start_line + next_header_line - 1))
  else
    section_end_line="$total_lines"
  fi
fi

AUTHORED_TASK_LISTS=()   # one entry per authored Run line: comma-joined task ids
AUTHORED_LINE_TEXT=()    # the raw Run line text, for message rendering
AUTHORED_LINE_NUMBERS=() # 1-based line number in ROADMAP_PATH

in_fence=false
stopped=false
line_no="$section_start_line"
while IFS= read -r line; do
  line_no=$((line_no + 1))
  if [[ "$line" =~ $COVERAGE_HEADER_RE ]]; then
    stopped=true
    continue
  fi
  if [[ "$line" =~ ^\`\`\` ]]; then
    if $in_fence; then in_fence=false; else in_fence=true; fi
    continue
  fi
  $stopped && continue
  $in_fence || continue
  if [[ "$line" =~ $RUN_LINE_RE ]]; then
    AUTHORED_TASK_LISTS+=("${BASH_REMATCH[1]}")
    AUTHORED_LINE_TEXT+=("$line")
    AUTHORED_LINE_NUMBERS+=("$line_no")
  fi
done < <(sed -n "$((section_start_line + 1)),${section_end_line}p" "$ROADMAP_PATH")

FINDINGS_TOTAL=0

# ---------------------------------------------------------------------------
# Finding (c): a Run line's task-id count exceeds MAX_TASKS.
# ---------------------------------------------------------------------------
for i in "${!AUTHORED_TASK_LISTS[@]}"; do
  task_list="${AUTHORED_TASK_LISTS[$i]}"
  # Normalize: split on comma, trim whitespace, drop empties.
  IFS=',' read -r -a raw_ids <<< "$task_list"
  ids=()
  for raw in "${raw_ids[@]}"; do
    id="$(echo "$raw" | tr -d '[:space:]')"
    [[ -n "$id" ]] && ids+=("$id")
  done
  count=${#ids[@]}
  if [[ "$count" -gt "$MAX_TASKS" ]]; then
    FINDINGS_TOTAL=$((FINDINGS_TOTAL + 1))
    echo "[Run line ${AUTHORED_LINE_NUMBERS[$i]}] FINDING (c): batch has $count tasks, exceeds MAX_TASKS=$MAX_TASKS. Any trim must list territory-mandatory groups first so the cut never splits one off the end (see context/patterns/batch-orchestration-guardrails.md's truncation-precedence rule). This lint does not propose a trimmed batch."
  fi
done

# ---------------------------------------------------------------------------
# Finding (d): a cited task id that is terminal or does not exist, via task_lookup_entry
# (Decision D2 — the archive-aware single source of truth for task lookup).
# ---------------------------------------------------------------------------
is_terminal_status() {
  local status_lc
  status_lc="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
  [[ "$status_lc" == "completed" || "$status_lc" == "abandoned" || "$status_lc" == "expanded" ]]
}

for i in "${!AUTHORED_TASK_LISTS[@]}"; do
  task_list="${AUTHORED_TASK_LISTS[$i]}"
  IFS=',' read -r -a raw_ids <<< "$task_list"
  for raw in "${raw_ids[@]}"; do
    id="$(echo "$raw" | tr -d '[:space:]')"
    [[ -n "$id" ]] || continue
    [[ "$id" =~ ^[0-9]+$ ]] || continue
    entry="$(task_lookup_entry "$id" "$STATE_PATH")"
    if [[ -z "$entry" ]]; then
      FINDINGS_TOTAL=$((FINDINGS_TOTAL + 1))
      echo "[Run line ${AUTHORED_LINE_NUMBERS[$i]}] FINDING (d): task $id does not exist in state.json (active or archived)."
    else
      status="$(echo "$entry" | jq -r '.status // ""')"
      if is_terminal_status "$status"; then
        FINDINGS_TOTAL=$((FINDINGS_TOTAL + 1))
        echo "[Run line ${AUTHORED_LINE_NUMBERS[$i]}] FINDING (d): task $id is terminal (status: $status) and should not be cited in a batch."
      fi
    fi
  done
done

# ---------------------------------------------------------------------------
# Finding (f): a cited repository path, outside fenced code blocks, that does not resolve on
# disk. Scope is the WHOLE file (see header note), not just the batch block.
#
# RESOLUTION ROOTS (beyond the two false-positive guards the task record names explicitly):
# measured live against this repo's own specs/ROADMAP.md, this document's own prose convention
# cites paths relative to several different roots without a prefix disambiguating which --
# `commands/orchestrate.md` (the deployed .claude/ tree) and `core/docs/fork-patterns.md` /
# `lean/agents/` (a source-store path with the "agent-system/extensions/" prefix dropped but the
# per-extension directory name, e.g. "core"/"lean", KEPT as the candidate's own first segment).
# A candidate is reported ONLY when it resolves under NONE of: PROJECT_ROOT itself (specs/...
# citations); PROJECT_ROOT/.claude (the deployed tree, when present); or
# PROJECT_ROOT/agent-system/extensions (the source-store extensions parent, when present --
# NEVER one specific extension subdirectory, since the candidate text already names its own
# extension as its leading segment). This is resolution-root breadth, not a new false-positive
# guard -- it does not change what counts as a candidate in the first place.
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

# Collect inline backtick-delimited spans from non-fenced lines only.
in_fence=false
while IFS= read -r line; do
  if [[ "$line" =~ ^\`\`\` ]]; then
    if $in_fence; then in_fence=false; else in_fence=true; fi
    continue
  fi
  $in_fence && continue
  # Extract each `...` span on this line.
  rest="$line"
  while [[ "$rest" == *'`'* ]]; do
    rest="${rest#*\`}"
    [[ "$rest" == *'`'* ]] || break
    candidate="${rest%%\`*}"
    rest="${rest#*\`}"
    [[ -z "$candidate" ]] && continue

    # Not a bare-path citation at all: contains whitespace (a shell command, e.g.
    # "tests/run-all.sh --jobs 4" or "rm .claude/settings.json", or a prose list/stat
    # expression) rather than a single path token. Skipped silently -- this is a structural
    # precondition for "is this candidate shaped like a path", not one of the two named
    # false-positive guards below.
    [[ "$candidate" == *[[:space:]]* ]] && continue

    # Elision marker: this document's own convention uses a literal "..." to abbreviate a path
    # prefix (e.g. ".../scripts/lint/foo.sh"), never a real citation.
    [[ "$candidate" == *'...'* ]] && continue

    # Guard 1: must carry path structure (at least one '/') to count as a citation at all --
    # a bare backticked basename (ci.yml, MintBound.lean) is prose shorthand, never reported.
    # EXTENDED (same insufficient-structure rationale, not a new guard class): a candidate that
    # is exactly ONE segment plus a trailing slash and nothing else (e.g. "lint/", quoting a
    # path SEGMENT name under discussion -- "missing the `lint/` segment" -- not citing a
    # specific file or directory to verify) carries no more real path structure than a bare
    # basename and is treated identically. A genuine multi-segment directory citation such as
    # "docs/architecture/" still has an embedded '/' before its own trailing one and is
    # unaffected.
    if [[ "$candidate" != */* ]] || [[ "$candidate" =~ ^[^/]+/$ ]]; then
      skipped_shorthand=$((skipped_shorthand + 1))
      continue
    fi

    # Skip placeholder/glob tokens -- never a concrete citation.
    case "$candidate" in
      *'{'*|*'}'*|*'*'*|*'<'*) continue ;;
    esac

    # Guard 2: a path qualified for another repository (leading ~/, leading /, or any other
    # explicit root prefix) is skipped explicitly and counted, never resolved against the local
    # root.
    # shellcheck disable=SC2088  # deliberate literal-tilde case pattern, not an expansion site:
    # the candidate text itself literally begins with "~/" (a citation someone typed), and this
    # case match is testing that literal prefix, never expanding it to $HOME.
    case "$candidate" in
      '~/'*|'/'*)
        skipped_cross_repo=$((skipped_cross_repo + 1))
        continue
        ;;
    esac

    # Surviving candidate: resolve against every known root (see RESOLUTION_ROOTS above).
    if ! candidate_resolves "$candidate"; then
      FINDINGS_TOTAL=$((FINDINGS_TOTAL + 1))
      echo "FINDING (f): cited path does not resolve: \`$candidate\`"
    fi
  done
done < "$ROADMAP_PATH"

if $VERBOSE; then
  echo "INFO: finding (f) skipped $skipped_shorthand bare-basename candidate(s) and $skipped_cross_repo cross-repository candidate(s)." >&2
fi

echo "---"
echo "Scan complete. layout=$LAYOUT authored_run_lines=${#AUTHORED_TASK_LISTS[@]} findings=$FINDINGS_TOTAL"
exit 0
