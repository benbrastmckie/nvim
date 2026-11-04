#!/usr/bin/env bash
# audit-task-proposals.sh - The single shared backlog-reconciliation matcher.
#
# Compares one or more proposed tasks against the full backlog CORPUS (the union of the open
# backlog and every closed record -- live `completed` entries plus the archive) and emits a
# structured verdict per proposal, per matched corpus record, drawn from the closed vocabulary
# canonically defined in context/patterns/backlog-reconciliation.md. This script implements that
# document's Rule, Inputs, and Two Passes; it does not restate the vocabulary's rationale here --
# see that document for the full account of WHY each design choice was made (the Non-Goals
# section in particular). Read it before modifying this script's classification logic.
#
# KNOWN NOISE TRADE-OFF, stated plainly: `scope-blind` is emitted for EVERY corpus record that
# declares no `file_scope`, UNCONDITIONALLY -- not gated by any semantic relevance check. This is
# deliberate (see context/patterns/backlog-reconciliation.md's Pass 1 section: an absent scope
# must never be silently read as non-overlap), but against a real backlog with many legacy
# no-scope records this can dominate a single proposal's verdict list. A calling surface wiring
# this into a confirmation table (Multi-Task Creation Standard Component 4b) is expected to
# render `scope-blind` entries compactly (e.g. a count, not N expanded rows) rather than treat the
# volume as a defect in this script; collapsing display noise is a presentation concern for the
# caller, never a reason for this script to start suppressing records.
#
# THE SCRIPT NEVER DECIDES DUPLICATION. Per that document's False-Negative Posture and D5: Pass
# 2 (semantic) is a recall-biased, over-inclusive SHORTLIST. A `duplicate-of-open`/
# `covered-by-closed` verdict emitted purely from Pass 2 (no mechanical corroboration) is this
# script's own best-effort disposition at its stated threshold -- it is not a certified fact, and
# a calling surface (or a human) renders the final ruling. NO SUPPRESSION: every corpus record
# this script emits a verdict for appears in the output; there is no flag or exit code that drops
# a proposal or a verdict.
#
# Two call shapes, served by the SAME matcher and the SAME vocabulary (D4):
#   (a) Creation-time, single-attempt: --title/--description/--file-scope flags describe ONE
#       proposal, optionally carrying --project-number (for an already-allocated task auditing
#       itself against the rest of the backlog -- that task's own corpus record is excluded from
#       its own comparison set).
#   (b) Proposal-time, over a SET, rendered before any task exists: --proposals-file FILE (or
#       `-` / omitted-with-stdin-piped) reads a JSON array of proposal objects that carry NO
#       project_number and NO task directory. This script never requires either field, and the
#       enforcement hook (hooks/validate-task-creation-audit.sh) and
#       scripts/state-write.sh's audit-evidence gate are NOWHERE in this call path -- this script
#       is fully standalone and callable by any proposal-rendering surface, not only a
#       task-creation attempt.
#
# Proposal object shape (set mode array elements, and the single-mode flags' equivalent):
#   {
#     "id": "<optional-caller-correlation-id, echoed back verbatim>",
#     "project_number": <optional integer -- omit for a not-yet-created proposal>,
#     "title": "<required>",
#     "description": "<required, may be empty string>",
#     "file_scope": ["path", ...]   <optional -- omit or [] when the proposal declares none>
#   }
#
# Output: NDJSON, one line per proposal, to stdout. Each line:
#   {
#     "proposal": {"id": ..., "project_number": ... | null, "title": ...},
#     "verdicts": [
#       {"verdict": "...", "project_number": N, "project_name": "...",
#        "shared_paths": [...]?,                    // open-side mechanical verdicts only
#        "discharging_artifact": {"type": "...", "path": "..."}?,   // covered-by-closed only
#        "semantic_score": 0.NN,
#        "mechanical_class": "exact|subset|superset|overlap|none|scope-blind"},
#       ...
#     ],
#     "passes": {"mechanical": true, "semantic": true},
#     "degradations": ["scope-blind: project 123 (some_project) declares no file_scope", ...]
#   }
# A proposal matching nothing in the corpus still emits a line, with
# `verdicts: [{"verdict": "genuinely-new"}]` -- never an empty array, so a consumer can always
# render SOME disposition without a special case for "no matches".
#
# Exit codes:
#   0 - the audit ran to completion for every proposal (a match is a VERDICT, never a failure --
#       this is the exit code even when every proposal duplicates something in the backlog).
#   1 - usage error (bad flags, malformed proposal JSON, a proposal missing title/description).
#   2 - a required state file could not be read, or the internal jq pipeline errored. FAILS
#       LOUDLY -- never an empty-corpus silent pass, per the dispatch's explicit requirement that
#       an unreadable corpus never be mistaken for "nothing to compare against".
#
# Semantic threshold (named constant, tuning rationale -- see SEMANTIC_THRESHOLD below for the
# value and the asymmetric-cost reasoning per the false-negative posture this implements).
#
# Canonical predicates reused, never forked: this script splices
# $FILE_SCOPE_OVERLAP_JQ_DEFS (scripts/lib/file-scope-overlap.sh) for the base directory-prefix
# overlap test (`norm`, `scopes_overlap_first`). The exact/subset/superset CLASSIFICATION built
# on top of that predicate is additive (this script's own `covered`/`mech_class` defs below) --
# see context/patterns/file-footprint-overlap.md's "Containment" section, which this
# classification applies rather than reinvents. Archive-loading mirrors
# scripts/lib/project-number-inuse.sh's convention (union completed_projects/archived_projects/
# abandoned_projects, tolerate a missing archive file).
#
# Usage:
#   audit-task-proposals.sh --title TITLE --description DESC [--file-scope JSON_ARRAY]
#                            [--project-number N]
#   audit-task-proposals.sh --proposals-file FILE   (FILE may be '-' for stdin)
#   cat proposals.json | audit-task-proposals.sh --proposals-file -
#   audit-task-proposals.sh < proposals.json          (stdin, no flags, when not a tty)
#
#   REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/audit-task-proposals.sh ...
#       (source-store invocation override -- same convention as audit-deletion-references.sh /
#       check-extension-docs.sh; required because .claude/scripts/audit-task-proposals.sh does
#       not exist until a deploy runs)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -n "${REPO_ROOT:-}" ]] || . "$SCRIPT_DIR/deploy-root-guard.sh" || exit 1
PROJECT_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: audit-task-proposals.sh: jq is required and is not on PATH" >&2
  exit 1
fi

# Fail CLOSED if the shared overlap-predicate lib is unsourceable -- never fall back to an
# inline copy. Same posture as orchestrate-batch-admit.sh's identical guard.
if ! . "${SCRIPT_DIR}/lib/file-scope-overlap.sh" 2>/dev/null; then
  echo "ERROR: audit-task-proposals.sh: could not source ${SCRIPT_DIR}/lib/file-scope-overlap.sh" >&2
  echo "  Source-store copy: agent-system/extensions/core/scripts/lib/file-scope-overlap.sh" >&2
  exit 1
fi

STATE_FILE="$PROJECT_ROOT/specs/state.json"
ARCHIVE_FILE="$PROJECT_ROOT/specs/archive/state.json"

usage() {
  cat >&2 <<'USAGE'
Usage:
  audit-task-proposals.sh --title TITLE --description DESC [--file-scope JSON_ARRAY] [--project-number N]
  audit-task-proposals.sh --proposals-file FILE   (FILE may be '-' for stdin)
  <stdin JSON array>  | audit-task-proposals.sh --proposals-file -
  audit-task-proposals.sh < proposals.json
USAGE
}

TITLE=""
DESCRIPTION=""
FILE_SCOPE_JSON="null"
PROJECT_NUMBER_JSON="null"
PROPOSALS_FILE=""
HAVE_SINGLE=false
STATE_FILE_OVERRIDE=""
ARCHIVE_FILE_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      [[ $# -ge 2 ]] || { echo "ERROR: --title requires a value" >&2; exit 1; }
      TITLE="$2"; HAVE_SINGLE=true; shift 2 ;;
    --description)
      [[ $# -ge 2 ]] || { echo "ERROR: --description requires a value" >&2; exit 1; }
      DESCRIPTION="$2"; shift 2 ;;
    --file-scope)
      [[ $# -ge 2 ]] || { echo "ERROR: --file-scope requires a JSON array value" >&2; exit 1; }
      if ! FILE_SCOPE_JSON="$(printf '%s' "$2" | jq -c '.' 2>/dev/null)"; then
        echo "ERROR: --file-scope value is not valid JSON: $2" >&2
        exit 1
      fi
      shift 2 ;;
    --project-number)
      [[ $# -ge 2 ]] || { echo "ERROR: --project-number requires a value" >&2; exit 1; }
      case "$2" in
        ''|*[!0-9]*) echo "ERROR: --project-number must be a non-negative integer: $2" >&2; exit 1 ;;
      esac
      PROJECT_NUMBER_JSON="$2"
      shift 2 ;;
    --proposals-file)
      [[ $# -ge 2 ]] || { echo "ERROR: --proposals-file requires a value" >&2; exit 1; }
      PROPOSALS_FILE="$2"; shift 2 ;;
    --state-file)
      [[ $# -ge 2 ]] || { echo "ERROR: --state-file requires a value" >&2; exit 1; }
      STATE_FILE_OVERRIDE="$2"; shift 2 ;;
    --archive-file)
      [[ $# -ge 2 ]] || { echo "ERROR: --archive-file requires a value" >&2; exit 1; }
      ARCHIVE_FILE_OVERRIDE="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "ERROR: unrecognized argument: $1" >&2
      usage
      exit 1 ;;
  esac
done

[[ -n "$STATE_FILE_OVERRIDE" ]] && STATE_FILE="$STATE_FILE_OVERRIDE"
[[ -n "$ARCHIVE_FILE_OVERRIDE" ]] && ARCHIVE_FILE="$ARCHIVE_FILE_OVERRIDE"

if $HAVE_SINGLE && [[ -n "$PROPOSALS_FILE" ]]; then
  echo "ERROR: --title and --proposals-file are mutually exclusive" >&2
  exit 1
fi

# --- Build the $PROPOSALS_JSON array (one or more proposal objects) ---
if $HAVE_SINGLE; then
  if [[ -z "$TITLE" ]]; then
    echo "ERROR: --title must be non-empty" >&2
    exit 1
  fi
  PROPOSALS_JSON="$(jq -nc \
    --arg title "$TITLE" --arg desc "$DESCRIPTION" \
    --argjson fs "$FILE_SCOPE_JSON" --argjson pn "$PROJECT_NUMBER_JSON" \
    '[{id: null, project_number: $pn, title: $title, description: $desc, file_scope: $fs}]')"
elif [[ -n "$PROPOSALS_FILE" ]]; then
  if [[ "$PROPOSALS_FILE" == "-" ]]; then
    RAW="$(cat)"
  else
    if [[ ! -r "$PROPOSALS_FILE" ]]; then
      echo "ERROR: cannot read --proposals-file: $PROPOSALS_FILE" >&2
      exit 1
    fi
    RAW="$(cat "$PROPOSALS_FILE")"
  fi
  if ! PROPOSALS_JSON="$(printf '%s' "$RAW" | jq -c '.')"; then
    echo "ERROR: --proposals-file content is not valid JSON" >&2
    exit 1
  fi
elif [[ ! -t 0 ]]; then
  RAW="$(cat)"
  if ! PROPOSALS_JSON="$(printf '%s' "$RAW" | jq -c '.')"; then
    echo "ERROR: stdin content is not valid JSON" >&2
    exit 1
  fi
else
  echo "ERROR: no proposal given (--title, --proposals-file, or piped stdin required)" >&2
  usage
  exit 1
fi

# Normalize to an array (a bare single object on stdin/--proposals-file is accepted too).
PROPOSALS_JSON="$(printf '%s' "$PROPOSALS_JSON" | jq -c 'if type == "array" then . else [.] end')"

# Validate every proposal carries at least a title.
if ! printf '%s' "$PROPOSALS_JSON" | jq -e 'all(.[]; (.title // "") != "")' >/dev/null 2>&1; then
  echo "ERROR: every proposal must carry a non-empty 'title' field" >&2
  exit 1
fi

# --- Read the corpus sources. Fail LOUDLY (exit 2) on an unreadable required state file; an
# absent archive file is tolerated (not every repo has accrued archived history yet) and
# degrades to an empty archive document, never a silent full-corpus skip. ---
if [[ ! -r "$STATE_FILE" ]]; then
  echo "ERROR: audit-task-proposals.sh: cannot read required state file: $STATE_FILE" >&2
  exit 2
fi
if ! LIVE_DOC="$(jq -c '.' "$STATE_FILE" 2>&1)"; then
  echo "ERROR: audit-task-proposals.sh: $STATE_FILE is not valid JSON: $LIVE_DOC" >&2
  exit 2
fi
if [[ -r "$ARCHIVE_FILE" ]]; then
  if ! ARCHIVE_DOC="$(jq -c '.' "$ARCHIVE_FILE" 2>&1)"; then
    echo "ERROR: audit-task-proposals.sh: $ARCHIVE_FILE is not valid JSON: $ARCHIVE_DOC" >&2
    exit 2
  fi
else
  ARCHIVE_DOC='{}'
fi

# --- The jq program: corpus union, Pass 1 (mechanical), Pass 2 (semantic), verdict emission. ---
# SEMANTIC_THRESHOLD (D5): a single named constant, tuned toward OVER-inclusion per the
# False-Negative Posture in context/patterns/backlog-reconciliation.md. A false positive here
# costs a human one line's dismissal; a false negative silently reproduces the near-duplicate-
# with-almost-no-shared-paths failure this script exists to catch. 0.4 (token-overlap ratio over
# the SMALLER side's token count) is deliberately lenient: two titles/descriptions sharing two of
# five significant tokens already clears it. Tune this constant ONLY after re-measuring both
# error costs, never to "quiet down" a noisy run.
read -r -d '' JQ_PROGRAM_BODY <<'JQPROG' || true
def is_terminal_status: ascii_downcase as $s | ($s == "completed" or $s == "abandoned" or $s == "expanded");
def is_closed_status: ascii_downcase as $s | ($s == "completed");

def stopwords: ["a","an","the","and","or","for","to","of","in","on","at","is","are","was","were",
  "be","been","this","that","it","its","as","by","with","from","into","via","not","no","so","if",
  "than","then","also","when","which","who","whose","while","can","cannot","must","should",
  "would","could","will","shall","do","does","did","has","have","had","there","their","them",
  "they","these","those","such","per","each","every","any","all","only","just","still","even",
  "yet","out","up","down","over","under","between","about","after","before","both","own","same",
  "more","most","other","some","one","two","new","task"];

def tokenize:
  ascii_downcase
  | [scan("[a-z0-9]+")]
  | map(select((. | length) > 2))
  | map(select(. as $w | (stopwords | index($w)) == null))
  | unique;

def token_overlap_score($ta; $tb):
  ($ta | length) as $la | ($tb | length) as $lb |
  if ($la == 0 or $lb == 0) then 0
  else
    ([$ta[] | select(. as $w | ($tb | index($w)) != null)] | length) as $inter |
    ($inter / ([$la, $lb] | min))
  end;

# covered(p; scope): the one-directional Containment predicate (file-footprint-overlap.md) --
# is concrete path p inside SOME entry of scope (exact match, or scope-entry-as-ancestor)?
def covered($p; $scope):
  ($scope // []) as $s | ($p | norm) as $np |
  ([$s[] | (. | norm) as $ns | select($np == $ns or ($np | startswith($ns + "/")))] | length) > 0;

def all_covered($pscope; $rscope):
  ($pscope // []) as $ps |
  ([$ps[] | select(covered(.; $rscope) | not)] | length) == 0;

def any_overlap($pscope; $rscope):
  (([scopes_overlap_first($pscope; $rscope)] | first) // null) as $hit | ($hit != null and $hit != "");

# mech_class: exact/subset/superset/overlap/none/scope-blind, per backlog-reconciliation.md Pass 1.
def mech_class($pscope; $rscope):
  if (($rscope // []) | length) == 0 then "scope-blind"
  elif (($pscope // []) | length) == 0 then "none"
  else
    (all_covered($pscope; $rscope)) as $p_sub |
    (all_covered($rscope; $pscope)) as $r_sub |
    if ($p_sub and $r_sub) then "exact"
    elif $p_sub then "subset"
    elif $r_sub then "superset"
    elif any_overlap($pscope; $rscope) then "overlap"
    else "none"
    end
  end;

def shared_paths($pscope; $rscope):
  ($pscope // []) as $ps | ($rscope // []) as $rs |
  ([$ps[] | select(covered(.; $rs))] + [$rs[] | select(covered(.; $ps))]) | unique;

def discharging_artifact($arts):
  ($arts // []) as $a |
  ( [$a[] | select(.type == "summary")] | first ) //
  ( [$a[] | select(.type == "plan")] | first ) //
  ( [$a[] | select(.type == "report")] | first ) //
  ( $a | first ) // null;

def open_corpus($live):
  [ ($live.active_projects // [])[] | select(.status | is_terminal_status | not)
    | { side: "open", project_number, project_name,
        title: (.title // ""), description: (.description // ""),
        file_scope: (.file_scope // null), artifacts: (.artifacts // []) } ];

def closed_live_corpus($live):
  [ ($live.active_projects // [])[] | select(.status | is_closed_status)
    | { side: "closed", project_number, project_name,
        title: (.title // ""), description: (.description // ""),
        file_scope: (.file_scope // null), artifacts: (.artifacts // []) } ];

def archive_corpus($archive):
  [ (($archive.completed_projects // []) + ($archive.archived_projects // []) + ($archive.abandoned_projects // []))[]
    | { side: "closed", project_number, project_name,
        title: (.title // ""), description: (.description // ""),
        file_scope: (.file_scope // null), artifacts: (.artifacts // []) } ];

def full_corpus($live; $archive):
  open_corpus($live) + closed_live_corpus($live) + archive_corpus($archive);

def record_verdict($p; $r; $threshold):
  ($p.file_scope) as $pscope | ($r.file_scope) as $rscope |
  (mech_class($pscope; $rscope)) as $mc |
  ( ($p.title // "") + " " + ($p.description // "") | tokenize ) as $ptok |
  ( ($r.title // "") + " " + ($r.description // "") | tokenize ) as $rtok |
  (token_overlap_score($ptok; $rtok)) as $sem_score |
  ((($rscope // []) | length) == 0) as $is_scope_blind |
  if $r.side == "closed" then
    if ($mc == "exact" or $mc == "subset" or $mc == "superset" or $mc == "overlap" or $sem_score >= $threshold) then
      { verdict: "covered-by-closed", project_number: $r.project_number, project_name: $r.project_name,
        discharging_artifact: discharging_artifact($r.artifacts), mechanical_class: $mc,
        semantic_score: $sem_score }
    elif $is_scope_blind then
      { verdict: "scope-blind", project_number: $r.project_number, project_name: $r.project_name,
        mechanical_class: $mc, semantic_score: $sem_score }
    else empty
    end
  else
    if $mc == "exact" then
      { verdict: "duplicate-of-open", project_number: $r.project_number, project_name: $r.project_name,
        shared_paths: shared_paths($pscope; $rscope), mechanical_class: $mc, semantic_score: $sem_score }
    elif $mc == "subset" then
      { verdict: "subset-of-open", project_number: $r.project_number, project_name: $r.project_name,
        shared_paths: shared_paths($pscope; $rscope), mechanical_class: $mc, semantic_score: $sem_score }
    elif $mc == "superset" then
      { verdict: "superset-of-open", project_number: $r.project_number, project_name: $r.project_name,
        shared_paths: shared_paths($pscope; $rscope), mechanical_class: $mc, semantic_score: $sem_score }
    elif $sem_score >= $threshold then
      # A STRONG semantic signal outranks a merely WEAK mechanical one ($mc == "overlap" or
      # "none") -- per backlog-reconciliation.md's combination rule, only exact/subset/superset
      # (the SPECIFIC mechanical classes, handled above) outrank Pass 2. This is exactly the
      # near-duplicate-with-almost-no-shared-paths case Pass 2 exists to catch: a weak partial
      # file overlap must never suppress a strong semantic duplicate signal.
      { verdict: "duplicate-of-open", project_number: $r.project_number, project_name: $r.project_name,
        shared_paths: (if $mc == "overlap" then shared_paths($pscope; $rscope) else null end),
        mechanical_class: $mc, semantic_score: $sem_score }
    elif $mc == "overlap" then
      { verdict: "overlaps-open", project_number: $r.project_number, project_name: $r.project_name,
        shared_paths: shared_paths($pscope; $rscope), mechanical_class: $mc, semantic_score: $sem_score }
    elif $is_scope_blind then
      { verdict: "scope-blind", project_number: $r.project_number, project_name: $r.project_name,
        mechanical_class: $mc, semantic_score: $sem_score }
    else empty
    end
  end;

def proposal_result($p; $corpus; $threshold):
  ($p.project_number) as $self_num |
  ([$corpus[] | select($self_num == null or .project_number != $self_num)]) as $others |
  ([$others[] | record_verdict($p; .; $threshold)]) as $vs |
  ( [$vs[] | select(.verdict == "scope-blind") | "scope-blind: project \(.project_number) (\(.project_name)) declares no file_scope -- judged on the semantic shortlist alone"] ) as $degr |
  {
    proposal: {id: ($p.id // null), project_number: $self_num, title: $p.title},
    verdicts: (if ($vs | length) > 0 then $vs else [{verdict: "genuinely-new"}] end),
    passes: {mechanical: true, semantic: true},
    degradations: $degr
  };

($live_arr[0]) as $live_doc |
($archive_arr[0]) as $archive_doc |
full_corpus($live_doc; $archive_doc) as $corpus |
$proposals[] as $p |
proposal_result($p; $corpus; $threshold)
JQPROG

RESULT="$(jq -c -n \
  --argjson proposals "$PROPOSALS_JSON" \
  --slurpfile live_arr <(printf '%s' "$LIVE_DOC") \
  --slurpfile archive_arr <(printf '%s' "$ARCHIVE_DOC") \
  --argjson threshold 0.4 \
  "$FILE_SCOPE_OVERLAP_JQ_DEFS"'
'"$JQ_PROGRAM_BODY" 2>&1)"
JQ_RC=$?

if [[ $JQ_RC -ne 0 ]]; then
  echo "ERROR: audit-task-proposals.sh: internal jq error: $RESULT" >&2
  exit 2
fi

printf '%s\n' "$RESULT"
exit 0
