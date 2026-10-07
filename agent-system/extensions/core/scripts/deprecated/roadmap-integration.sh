#!/usr/bin/env bash
# roadmap-integration.sh - Parse ROADMAP.md, cross-reference with state, annotate completed items
#
# Implements Steps 2.5-2.5.3 from /review command:
#   2.5   Parse ROADMAP.md
#   2.5.2 Cross-reference roadmap with project state
#   2.5.3 Annotate completed roadmap items
#
# Usage:
#   bash roadmap-integration.sh --roadmap specs/ROADMAP.md --state specs/state.json
#   bash roadmap-integration.sh --roadmap specs/ROADMAP.md --state specs/state.json --annotate
#
# Options:
#   --roadmap PATH    Path to ROADMAP.md (required)
#   --state PATH      Path to state.json (required)
#   --annotate        Apply high-confidence annotations to ROADMAP.md (default: parse only)
#   --dry-run         Show what annotations would be made without applying them
#
# Output:
#   JSON object with roadmap_state, roadmap_matches, annotation_summary, roadmap_structure, and
#   warnings to stdout. If --annotate: also applies edits to ROADMAP.md and prints annotation
#   summary to stderr.
#
#   Every invocation, in every mode (including parse-only), also prints an always-present
#   machine-readable marker to stderr:
#     <!-- roadmap-structure phases=N checkboxes=M table_rows=T parseable=true|false -->
#   and, when warranted, one or both loud banners:
#     [UNPARSEABLE ROADMAP - 0 phases, 0 checkboxes, 0 table rows] ...
#     [ROADMAP ANNOTATION NO-OP - {K} high-confidence match(es), 0 applied] Skip reasons: ...
#   These never affect the exit code -- they are diagnostics, not failures.
#
# status_tables[] / table-sourced roadmap_matches[] entries additionally carry line_index
# (0-based), raw_line (unmodified source text), and status_index (the column the completion
# allowlist matched), which the table-row annotation path uses to locate and safely rewrite a row
# in place. Checkbox-sourced match objects never carry these keys.
#
# Caller contract:
#   (a) Parse-only mode (omitting --annotate) is a supported, first-class call shape. Its purpose
#       is to obtain roadmap_structure/warnings/roadmap_matches without mutating ROADMAP.md at
#       all -- a caller that only needs the structure signal or the match list, not an applied
#       edit, should call the script this way rather than treating --annotate as the only mode.
#   (b) The archive input is resolved as the sibling ${STATE_PATH%state.json}archive/state.json.
#       A caller that passes a synthesized or filtered --state snapshot living outside specs/
#       therefore gets an empty archive set (the sibling path will not exist) -- this is the
#       supported way to scope a run to a caller-chosen task subset, not an accident to work
#       around. A caller relying on this must place its snapshot outside specs/ deliberately.
#   (c) The script applies no task_type filter and has no abandoned-status branch: its
#       COMPLETED_TASKS/ARCHIVED_TASKS queries only ever select status == "completed", and its
#       only annotation-suffix construction is the "*(Completed: Task N ...)*" format. A caller
#       needing to exclude a task type (e.g. meta tasks) or to annotate an abandoned-task branch
#       must filter its own --state input, or implement that annotation path itself -- neither is
#       something a future change to this script should add, since doing so would widen an
#       already-fixed, already-verified call site for the benefit of a caller that can filter its
#       own input instead.
#
# Output schema (all fields below annotation_summary.annotations_made/items_skipped/
# skipped_reasons and roadmap_state/roadmap_matches are unchanged from the original schema;
# roadmap_structure, warnings, and the two annotation_summary fields marked NEW are additive):
#   {
#     "roadmap_state": {
#       "phases": [...],
#       "status_tables": [{ "component", "status", "location", "columns", "line_index",
#                            "raw_line", "status_index" }, ...]
#     },
#     "roadmap_matches": [...],
#     "annotation_summary": {
#       "annotations_made": 0,
#       "items_skipped": 0,
#       "skipped_reasons": [],
#       "high_confidence_matches": 0,      # NEW: count of confidence=="high" matches; 0 when
#                                           #      --annotate was not passed
#       "silent_noop": false               # NEW: true iff high_confidence_matches > 0 and
#                                           #      annotations_made == 0
#     },
#     "roadmap_structure": {               # NEW: always present, every mode
#       "phases": 0,
#       "checkboxes": 0,
#       "table_rows": 0,
#       "parseable": true
#     },
#     "warnings": []                       # NEW: stable string codes, [] when none apply.
#                                           #      "unparseable_roadmap": phases == 0 &&
#                                           #        checkboxes == 0 && table_rows == 0
#                                           #      "annotation_noop": annotate mode ran,
#                                           #        high_confidence_matches > 0, and
#                                           #        annotations_made == 0
#                                           #      "roadmap_absent": --roadmap path did not
#                                           #        exist; "no roadmap tracked" -- a supported
#                                           #        state, not auto-created and not an error.
#                                           #        Exits 0 with the empty-state payload above
#                                           #        before any parsing is attempted.
#   }

set -euo pipefail

# ─── Parse arguments ──────────────────────────────────────────────────────────

ROADMAP_PATH=""
STATE_PATH=""
DO_ANNOTATE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --roadmap)
      ROADMAP_PATH="$2"
      shift 2
      ;;
    --state)
      STATE_PATH="$2"
      shift 2
      ;;
    --annotate)
      DO_ANNOTATE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      DO_ANNOTATE=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$ROADMAP_PATH" ]]; then
  echo "Error: --roadmap is required" >&2
  exit 1
fi

if [[ -z "$STATE_PATH" ]]; then
  echo "Error: --state is required" >&2
  exit 1
fi

# ─── Absent ROADMAP.md is a supported state, not a failure ──────────────────
#
# An absent roadmap means "no roadmap tracked" -- it is not a signal to auto-create a fresh
# stub. A repo that has deliberately deleted its roadmap must stay deleted; auto-recreating a
# stub here would make that deletion never stick, since the next /review or /todo run would
# regenerate it. Emit the same empty-state
# payload shape the callers' own fallback branches already construct on a missing/failed script
# (review.md, todo.md), plus the new roadmap_absent warning code, and exit 0 -- absence is
# parsed successfully as "nothing to report", never as an error condition.
if [[ ! -f "$ROADMAP_PATH" ]]; then
  echo "Note: ROADMAP.md not found at $ROADMAP_PATH -- treating as 'no roadmap tracked' (absence is a supported state; nothing is auto-created)" >&2
  jq -n '{
    "roadmap_state": {"phases": [], "status_tables": []},
    "roadmap_matches": [],
    "annotation_summary": {
      "annotations_made": 0,
      "items_skipped": 0,
      "skipped_reasons": [],
      "high_confidence_matches": 0,
      "silent_noop": false
    },
    "roadmap_structure": {
      "phases": 0,
      "checkboxes": 0,
      "table_rows": 0,
      "parseable": false
    },
    "warnings": ["roadmap_absent"]
  }'
  exit 0
fi

if [[ ! -f "$STATE_PATH" ]]; then
  echo "Error: state.json not found at $STATE_PATH" >&2
  exit 1
fi

# ─── Step 2.5: Parse ROADMAP.md ──────────────────────────────────────────────
#
# Extract:
#   Phase headers: ## Phase {N}: {Title} ({Priority})
#   Checkboxes: - [ ] (incomplete) and - [x] (complete)
#   Status tables: pipe-delimited rows with Component/Status/Location
#   Priority markers: (High Priority), (Medium Priority), (Low Priority)

ROADMAP_STATE=$(python3 - "$ROADMAP_PATH" << 'PYEOF'
import sys
import re
import json

# Read the file directly from disk (path is a short argv string; the file itself may be
# large, so we never pass its content through argv -- see the ALL_COMPLETED/ROADMAP_STATE
# temp-file fix below (~line 367) and the final report-building jq -n's --slurpfile fix
# (~line 795), both of which follow this exact file-not-argv pattern).
with open(sys.argv[1], "r") as f:
    content = f.read()
lines = content.split("\n")

phases = []
status_tables = []
current_phase = None
in_table = False
table_headers = []

for i, line in enumerate(lines):
    # Match phase headers: ## Phase N: Title (Priority)
    phase_match = re.match(r'^## Phase (\d+): (.+?)(?:\s+\((\w+ Priority)\))?$', line)
    if phase_match:
        if current_phase is not None:
            phases.append(current_phase)
        priority_text = phase_match.group(3) or ""
        priority = (priority_text.split()[0] if priority_text else "Medium")
        current_phase = {
            "number": int(phase_match.group(1)),
            "title": phase_match.group(2).strip(),
            "priority": priority,
            "checkboxes": {
                "total": 0,
                "completed": 0,
                "items": []
            }
        }
        in_table = False
        continue

    # Match checkboxes: - [ ] text or - [x] text
    if current_phase is not None:
        checkbox_match = re.match(r'^- \[([ xX])\] (.+)$', line)
        if checkbox_match:
            is_completed = checkbox_match.group(1).lower() == 'x'
            text = checkbox_match.group(2).strip()
            current_phase["checkboxes"]["total"] += 1
            if is_completed:
                current_phase["checkboxes"]["completed"] += 1
            current_phase["checkboxes"]["items"].append({
                "text": text,
                "completed": is_completed
            })
            continue

    # Match status table rows of ANY column count: | col | col | col | ... |
    # (previously a fixed-arity `^\|(.+)\|(.+)\|(.+)\|$` regex, which only matched exactly
    # 3-column rows and mis-split 4- and 5-column rows -- see defect 3, separator-regex fix.)
    table_row_match = re.match(r'^\|(.*)\|\s*$', line)
    if table_row_match:
        # Generic split on '|' works for any column count.
        cols = [c.strip() for c in table_row_match.group(1).split('|')]
        # A bare "|...|" line with no internal '|' (1 column) is not a real table row --
        # e.g. ASCII-art box-drawing lines using '|' as a vertical bar. Require >=2 columns.
        if len(cols) < 2:
            in_table = False
            continue
        # Skip separator rows (---, :---, ---:, :---: cells) for any column count.
        if all(re.match(r'^:?-+:?$', c) or c == '' for c in cols):
            continue
        # Detect header rows via lookahead: a row is a header iff the NEXT line is a
        # same-width separator row. This is robust regardless of cell content -- an earlier
        # keyword-based heuristic ("status" appears in some column) produced false positives
        # when a DATA cell happened to contain the substring "status" (e.g. a
        # "[...STATUS.md](...)" markdown link), silently swallowing that data row as a second
        # header.
        next_line = lines[i + 1] if i + 1 < len(lines) else ""
        next_row_match = re.match(r'^\|(.*)\|\s*$', next_line)
        next_cols = [c.strip() for c in next_row_match.group(1).split('|')] if next_row_match else None
        is_header = (
            next_cols is not None
            and len(next_cols) == len(cols)
            and all(re.match(r'^:?-+:?$', c) or c == '' for c in next_cols)
        )
        if is_header:
            table_headers = cols
            in_table = True
            continue
        if in_table:
            # Strip markdown bold from component name (first column).
            component = re.sub(r'\*\*(.+?)\*\*', r'\1', cols[0])
            # Status is not reliably at a fixed column index across tables of different
            # widths/headers (e.g. "Hardware Port" is the actual completion-status column in
            # several 4-/5-column ROADMAP tables, not column index 1). Scan all non-component
            # columns for a value that whole-word-matches the completion allowlist and use
            # that as the status; fall back to column index 1 for backward compatibility when
            # no column matches (informational only -- the matcher only treats an allowlist
            # match as a candidate).
            status_value = ""
            status_index = None
            for idx, c in enumerate(cols[1:], start=1):
                if re.search(r'\b(complete|resolved|done)\b', c, re.IGNORECASE):
                    status_value = c
                    status_index = idx
                    break
            if status_index is None and len(cols) > 1:
                status_index = 1
            # The annotator (Step 2.5.3) cannot locate or safely rewrite a table row from derived
            # cell values (component/status/location) alone -- those are copies, not a pointer
            # back into the source file. line_index/raw_line/status_index give it exactly enough
            # to find the originating line, verify it hasn't changed, and rewrite only the
            # matched status cell in place.
            status_tables.append({
                "component": component,
                "status": status_value if status_value else (cols[1] if len(cols) > 1 else ""),
                "location": cols[-1] if len(cols) > 1 else "",
                "columns": cols,
                "line_index": i,
                "raw_line": line,
                "status_index": status_index
            })
    else:
        in_table = False

# Add last phase
if current_phase is not None:
    phases.append(current_phase)

result = {
    "phases": phases,
    "status_tables": status_tables
}
print(json.dumps(result))
PYEOF
)

# ─── Roadmap-structure signal (always-on, every mode including parse-only) ───
#
# The script must never be able to report success while silently recognizing nothing and
# annotating nothing. These three counts and the always-present marker below are the mechanism:
# a consumer (human or /review) can see, unconditionally, exactly what structure was found,
# without having to infer it from an empty-looking diff.
PHASE_COUNT=$(echo "$ROADMAP_STATE" | jq '.phases | length')
CHECKBOX_COUNT=$(echo "$ROADMAP_STATE" | jq '[.phases[].checkboxes.total] | add // 0')
TABLE_ROW_COUNT=$(echo "$ROADMAP_STATE" | jq '.status_tables | length')

if [[ "$PHASE_COUNT" -eq 0 && "$CHECKBOX_COUNT" -eq 0 && "$TABLE_ROW_COUNT" -eq 0 ]]; then
  ROADMAP_PARSEABLE=false
else
  ROADMAP_PARSEABLE=true
fi

# Machine-readable marker, mirroring the literature-briefing.sh <!-- lit-coverage ... -->
# convention: always emitted, in every mode, so a consumer can grep the transcript for this line
# regardless of whether a banner also fired.
echo "<!-- roadmap-structure phases=${PHASE_COUNT} checkboxes=${CHECKBOX_COUNT} table_rows=${TABLE_ROW_COUNT} parseable=${ROADMAP_PARSEABLE} -->" >&2

if [[ "$ROADMAP_PARSEABLE" == "false" ]]; then
  echo "[UNPARSEABLE ROADMAP - 0 phases, 0 checkboxes, 0 table rows] The parser recognizes ## Phase N: headings with - [ ]/- [x] checkboxes, and pipe-delimited status tables; this file matched neither." >&2
fi

# ─── Step 2.5.2: Cross-reference roadmap with project state ──────────────────
#
# Match roadmap items to completed tasks using:
#   1. Item contains (Task N) reference    -> High confidence, auto-annotate
#   2. Item text matches task title        -> Medium confidence, suggest annotation
#   3. Item's file path exists             -> Medium confidence, suggest annotation
#   4. Partial keyword match               -> Low confidence, report only

# Get completed tasks from state.json
COMPLETED_TASKS=$(jq -r '
  .active_projects[] | select(.status == "completed") |
  {
    "number": .project_number,
    "name": .project_name,
    "title": (.description // .project_name),
    "completion_summary": (.completion_summary // ""),
    "roadmap_items": (.roadmap_items // [])
  }
' "$STATE_PATH" 2>/dev/null | jq -s '.' 2>/dev/null || echo "[]")

# Check archive/state.json too if it exists
ARCHIVE_STATE="${STATE_PATH%state.json}archive/state.json"
ARCHIVED_TASKS="[]"
if [[ -f "$ARCHIVE_STATE" ]]; then
  ARCHIVED_TASKS=$(jq -r '
    .completed_projects[] | select(.status == "completed") |
    {
      "number": .project_number,
      "name": .project_name,
      "title": (.description // .project_name),
      "completion_summary": (.completion_summary // ""),
      "roadmap_items": (.roadmap_items // [])
    }
  ' "$ARCHIVE_STATE" 2>/dev/null | jq -s '.' 2>/dev/null || echo "[]")
fi

ALL_COMPLETED=$(echo "$COMPLETED_TASKS $ARCHIVED_TASKS" | jq -s 'add // []')

# ACTIVE_TASKS: every active_projects[] entry whose status is non-terminal, per the status model
# documented in CLAUDE.md ("Terminal states: [COMPLETED], [ABANDONED], [EXPANDED]"; everything
# else is non-terminal). Deliberately an explicit allowlist rather than `.status != "completed"`,
# so an abandoned/expanded task reference (also terminal, just not completed) does NOT trip the
# reject rule below -- only a genuinely still-in-flight task should. Numbers and statuses only,
# not full records -- this feeds the explicit_task_ref reject rule (Step 2.5.2 python step,
# below), which only needs to know WHETHER a referenced task number is still non-terminal.
ACTIVE_TASKS=$(jq -r '
  .active_projects[] | select(.status as $s | [
    "not_started", "researching", "researched", "planning", "planned",
    "implementing", "partial", "blocked", "pr_ready"
  ] | index($s)) |
  {
    "number": .project_number,
    "status": .status
  }
' "$STATE_PATH" 2>/dev/null | jq -s '.' 2>/dev/null || echo "[]")

# ROADMAP_STATE and ALL_COMPLETED can each exceed Linux's MAX_ARG_STRLEN (131,072 bytes) once
# the task history grows (observed ~252KB), which would make argv-passing exit 126 ("Argument
# list too long"). Pass both via temp files instead and json.load() them in python -- stdin is
# reserved for the heredoc program source and env vars hit the identical argv-size limit.
TMP_ROADMAP_STATE=$(mktemp)
TMP_ALL_COMPLETED=$(mktemp)
# TMP_ACTIVE_TASKS carries ACTIVE_TASKS (built above) into the same python matching step via a
# third temp-file argument, matching this step's own established file-not-argv convention --
# never argv, even though ACTIVE_TASKS itself is small; consistency with TMP_ROADMAP_STATE/
# TMP_ALL_COMPLETED is the point, not a size concern for this particular payload.
TMP_ACTIVE_TASKS=$(mktemp)
# TMP_ROADMAP_STATE_SLURP/TMP_ROADMAP_MATCHES_SLURP are used later, by the final report-building
# jq -n (~line 795) -- declared and trapped here, alongside this step's own temp files, so a
# single EXIT trap covers every temp file this script creates. Do NOT add a second `trap ... EXIT`
# below; it would silently replace this one and leak whichever pair it doesn't also list.
TMP_ROADMAP_STATE_SLURP=$(mktemp)
TMP_ROADMAP_MATCHES_SLURP=$(mktemp)
# TMP_REPORT holds the final JSON report (built far below, at the very end of the script) before
# it is ever printed -- pre-created here, alongside the other temp files, so the shared EXIT trap
# can safely reference it even on an early exit before the report-building step is reached.
TMP_REPORT=$(mktemp)

# ANNOTATE_TARGET: in --annotate/--dry-run mode (DO_ANNOTATE=true), a private mktemp staging copy
# that the annotate loop (Step 2.5.3, below) reads and writes exclusively -- the real
# $ROADMAP_PATH is touched exactly once, at the very end, only after the JSON report has been
# fully built (see the `mv "$ANNOTATE_TARGET" "$ROADMAP_PATH"` there). In parse-only mode
# (DO_ANNOTATE=false) the annotate loop's body never executes, so ANNOTATE_TARGET is simply
# $ROADMAP_PATH itself -- read-only there, no copy needed. This is what makes a mid-run failure
# leave $ROADMAP_PATH byte-identical: every write during the run lands on the staging copy, never
# on the real file, until the single end-of-script commit succeeds.
if [[ "$DO_ANNOTATE" == "true" ]]; then
  ANNOTATE_TARGET=$(mktemp)
  cp "$ROADMAP_PATH" "$ANNOTATE_TARGET"
else
  ANNOTATE_TARGET="$ROADMAP_PATH"
fi

# The trap below conditionally removes ANNOTATE_TARGET only when it is a real staging temp file
# (DO_ANNOTATE=true) -- when DO_ANNOTATE=false, ANNOTATE_TARGET IS $ROADMAP_PATH, and `rm -f`ing
# it on exit would destroy the live roadmap file, which must never happen.
trap '
  rm -f "$TMP_ROADMAP_STATE" "$TMP_ALL_COMPLETED" "$TMP_ACTIVE_TASKS" "$TMP_ROADMAP_STATE_SLURP" "$TMP_ROADMAP_MATCHES_SLURP" "$TMP_REPORT"
  [[ "$DO_ANNOTATE" == "true" ]] && rm -f "$ANNOTATE_TARGET"
' EXIT
printf '%s' "$ROADMAP_STATE" > "$TMP_ROADMAP_STATE"
printf '%s' "$ALL_COMPLETED" > "$TMP_ALL_COMPLETED"
printf '%s' "$ACTIVE_TASKS" > "$TMP_ACTIVE_TASKS"

ROADMAP_MATCHES=$(python3 - "$TMP_ROADMAP_STATE" "$TMP_ALL_COMPLETED" "$TMP_ACTIVE_TASKS" << 'PYEOF'
import sys
import re
import json

with open(sys.argv[1], "r") as f:
    roadmap_state = json.load(f)
with open(sys.argv[2], "r") as f:
    all_completed = json.load(f)
with open(sys.argv[3], "r") as f:
    active_tasks = json.load(f)

matches = []

# Build lookup for task by number and by name/title keywords
task_by_number = {}
for task in all_completed:
    task_by_number[task["number"]] = task

# Lookup for a task number's non-terminal status, used by the explicit_task_ref reject rule
# below (Check 1) -- see the comment there for the concrete failure case this guards against.
active_by_number = {task["number"]: task["status"] for task in active_tasks}

def normalize(text):
    """Lowercase and strip punctuation for fuzzy matching."""
    return re.sub(r'[^a-z0-9 ]', ' ', text.lower()).strip()

def keywords(text):
    """Extract significant keywords (>3 chars) from text."""
    words = normalize(text).split()
    stopwords = {'with', 'from', 'that', 'this', 'have', 'been', 'will', 'also', 'into', 'than'}
    return set(w for w in words if len(w) > 3 and w not in stopwords)

# Strict, whole-word, case-insensitive allowlist of completion-status values that a table row's
# status column must match before it is even considered as a candidate for matching (defect 3,
# Option A). This mirrors the checkbox path's "completed": true gate -- only rows that are
# themselves marked complete become candidates, so an over-broad matcher can't annotate rows
# that are still in progress.
STATUS_ALLOWLIST_RE = re.compile(r'\b(complete|resolved|done)\b', re.IGNORECASE)

def find_match(item_text, item_norm, item_kw):
    """Shared (Task N) / explicit-roadmap-item / title-match / keyword-match heuristic, used by
    both the checkbox-item path and the table-row path (defect 3, Option A) so a single matcher
    implementation backs both roadmap formats."""
    # Check 1: Does item contain an explicit (Task N) / (task N) reference? Case-insensitive
    # since the ROADMAP.md table format spells this in lowercase (e.g. "Complete (task <N>)"),
    # unlike the checkbox format's title-case convention.
    #
    # Guards against a real false-positive: an item whose text names several in-flight/
    # not-started sibling task numbers in prose was wrongly checked off on an earlier, unrelated
    # completed-task context reference in the same item, because the original re.search only ever
    # inspected the FIRST (task N) occurrence in the item text and had no visibility into
    # non-terminal tasks at all. re.finditer collects EVERY reference, and the reject rule below
    # refuses the high-confidence verdict whenever any collected reference is still non-terminal
    # (per active_by_number, built above) -- even when an earlier reference in the same text
    # resolves to a genuinely completed task.
    task_refs = [int(m.group(1)) for m in re.finditer(r'\(task (\d+)', item_text, re.IGNORECASE)]
    if task_refs:
        # An unresolvable reference (neither completed nor active -- e.g. abandoned or
        # renumbered) is non-blocking for this reject rule; it just can't alone produce a match.
        has_non_terminal_ref = any(t in active_by_number for t in task_refs)
        if not has_non_terminal_ref:
            for t in task_refs:
                if t in task_by_number:
                    return task_by_number[t], "high", "explicit_task_ref"
        # else: at least one referenced task is still non-terminal -- reject the high-confidence
        # verdict and fall through to the remaining, lower-confidence checks below instead.

    # Check 2: Does a completed task have explicit roadmap_items matching this text?
    for task in all_completed:
        for ri in task.get("roadmap_items", []):
            ri_norm = normalize(ri)
            if ri_norm == item_norm or (len(ri_norm) > 10 and ri_norm in item_norm):
                return task, "high", "explicit_roadmap_item"

    # Check 3: Title match (exact or near-exact)
    for task in all_completed:
        task_title_norm = normalize(task["title"])
        if task_title_norm == item_norm:
            return task, "high", "exact_title_match"
        # Near-exact: one is a substring of the other
        if len(task_title_norm) > 10:
            if task_title_norm in item_norm or item_norm in task_title_norm:
                return task, "medium", "title_match"

    # Check 4: Keyword match (60%+ overlap)
    if len(item_kw) >= 3:
        best_overlap = 0
        best_match = None
        for task in all_completed:
            task_kw = keywords(task["title"] + " " + task.get("completion_summary", ""))
            overlap = len(item_kw & task_kw)
            overlap_ratio = overlap / len(item_kw)
            if overlap_ratio >= 0.6 and overlap > best_overlap:
                best_overlap = overlap
                best_match = task
        if best_match is not None:
            return best_match, "low", "keyword_match"

    return None, None, None

for phase in roadmap_state.get("phases", []):
    for item in phase.get("checkboxes", {}).get("items", []):
        item_text = item["text"]
        item_norm = normalize(item_text)
        item_kw = keywords(item_text)

        # Skip already-annotated items (contain "*(Completed:")
        if "*(Completed:" in item_text or "(Completed:" in item_text:
            continue

        # Skip already completed items
        if item.get("completed", False):
            continue

        best_match, best_confidence, best_match_type = find_match(item_text, item_norm, item_kw)

        if best_match is not None:
            completion_date = best_match.get("completion_date", "")

            matches.append({
                "roadmap_item": item_text,
                "phase": phase["number"],
                "match_type": best_match_type,
                "confidence": best_confidence,
                "matched_task": best_match["number"],
                "task_title": best_match["title"],
                "completion_date": completion_date
            })

# Table-row-based completion matcher (defect 3, Option A): iterate status_tables entries (any
# column width, per the generic parser fix above) and treat rows whose status column matches the
# strict completion allowlist as candidates, reusing the same (Task N)/title/keyword heuristics
# against the row's component + status + location text. This is additive to the checkbox matcher
# above -- ROADMAP.md's current table format has zero checkboxes, so without this loop
# annotations_made is always 0 regardless of how many completed items the table actually lists.
for row in roadmap_state.get("status_tables", []):
    status_text = row.get("status", "")
    if not STATUS_ALLOWLIST_RE.search(status_text):
        continue

    # Skip rows already annotated with a completion marker.
    if "*(Completed:" in status_text or "(Completed:" in status_text:
        continue

    # Build combined text for matching: component name + status text (which often carries the
    # explicit "(task N)" reference) + location.
    row_text = " ".join(
        filter(None, [row.get("component", ""), status_text, row.get("location", "")])
    )
    row_norm = normalize(row_text)
    row_kw = keywords(row_text)

    best_match, best_confidence, best_match_type = find_match(row_text, row_norm, row_kw)

    if best_match is not None:
        completion_date = best_match.get("completion_date", "")

        # "source" was previously dead output (nothing downstream branched on it); it is now
        # load-bearing for the Step 2.5.3 annotation loop, which uses it to pick the table-row
        # rewrite path over the checkbox path. line_index/raw_line/status_index are carried
        # through unchanged from the status_tables entry so the annotator never has to re-derive
        # them from cell values.
        matches.append({
            "roadmap_item": row.get("component", ""),
            "phase": None,
            "match_type": best_match_type,
            "confidence": best_confidence,
            "matched_task": best_match["number"],
            "task_title": best_match["title"],
            "completion_date": completion_date,
            "source": "status_table",
            "line_index": row.get("line_index"),
            "raw_line": row.get("raw_line"),
            "status_index": row.get("status_index")
        })

print(json.dumps(matches))
PYEOF
)

# ─── Step 2.5.3: Annotate completed roadmap items ────────────────────────────
#
# Annotation format:
#   Checkbox path:   - [x] {item text} *(Completed: Task {N}, {DATE})*
#   Table-row path:  the same suffix appended to the matched status cell, e.g.
#                     | Component | Complete (task N) *(Completed: Task N, DATE)* | Location |
#
# Safety rules:
#   - Skip items already annotated (contain "*(Completed:")
#   - Preserve existing formatting and indentation
#   - One edit per item (no batch edits)
#   - Only high-confidence matches auto-annotate
#
# Invariant: every annotation replaces exactly one line with exactly one line, so a match's
# captured line_index remains valid for the entire annotate loop -- no index ever shifts because
# a prior iteration inserted or removed a line.

ANNOTATIONS_MADE=0
ITEMS_SKIPPED=0
SKIPPED_REASONS=()
# Hoisted so it is always available for the JSON payload, not just when annotation runs. Stays 0
# when --annotate was not passed -- a parse-only run has no annotation no-op to report.
HIGH_CONFIDENCE_MATCHES=0

if [[ "$DO_ANNOTATE" == "true" ]]; then
  # Process high-confidence matches
  HIGH_CONF_MATCHES=$(echo "$ROADMAP_MATCHES" | jq '[.[] | select(.confidence == "high")]')
  MATCH_COUNT=$(echo "$HIGH_CONF_MATCHES" | jq 'length')
  HIGH_CONFIDENCE_MATCHES=$MATCH_COUNT

  for i in $(seq 0 $((MATCH_COUNT - 1))); do
    MATCH=$(echo "$HIGH_CONF_MATCHES" | jq ".[$i]")
    ITEM_TEXT=$(echo "$MATCH" | jq -r '.roadmap_item')
    TASK_NUM=$(echo "$MATCH" | jq -r '.matched_task')
    COMPLETION_DATE=$(echo "$MATCH" | jq -r '.completion_date // ""')
    # .source // "" makes checkbox matches (which have no "source" key at all) yield an empty
    # string, so this one field cleanly distinguishes the two annotation paths below.
    SOURCE=$(echo "$MATCH" | jq -r '.source // ""')
    LINE_INDEX=$(echo "$MATCH" | jq -r '.line_index // ""')
    RAW_LINE=$(echo "$MATCH" | jq -r '.raw_line // ""')
    STATUS_INDEX=$(echo "$MATCH" | jq -r '.status_index // ""')

    # Annotation-suffix construction stays exactly here: the single source of truth for the
    # completion marker format used by both branches below.
    if [[ -n "$COMPLETION_DATE" ]]; then
      ANNOTATION_SUFFIX="*(Completed: Task $TASK_NUM, $COMPLETION_DATE)*"
    else
      ANNOTATION_SUFFIX="*(Completed: Task $TASK_NUM)*"
    fi

    if [[ "$SOURCE" != "status_table" ]]; then
      # ─── Checkbox branch: pre-existing OLD_LINE/NEW_LINE/awk logic, unmodified ────────────
      # Safety check: skip if already annotated
      if grep -q "*(Completed:" "$ANNOTATE_TARGET" 2>/dev/null && \
         grep -q "$ITEM_TEXT" "$ANNOTATE_TARGET" 2>/dev/null; then
        # Check if this specific line is already annotated
        MATCHING_LINE=$(grep -F "$ITEM_TEXT" "$ANNOTATE_TARGET" 2>/dev/null | head -1)
        if echo "$MATCHING_LINE" | grep -q "*(Completed:"; then
          ITEMS_SKIPPED=$((ITEMS_SKIPPED + 1))
          SKIPPED_REASONS+=("already_annotated")
          continue
        fi
      fi

      # Build old and new strings for sed substitution
      OLD_LINE="- [ ] $ITEM_TEXT"
      NEW_LINE="- [x] $ITEM_TEXT $ANNOTATION_SUFFIX"

      # Existence check shared by dry-run and apply, so dry-run can never over-report an
      # annotation it could not actually apply: does the exact unchecked line exist at all?
      LINE_EXISTS=false
      if grep -qxF "$OLD_LINE" "$ANNOTATE_TARGET" 2>/dev/null; then
        LINE_EXISTS=true
      fi

      if [[ "$DRY_RUN" == "true" ]]; then
        if [[ "$LINE_EXISTS" == "true" ]]; then
          echo "[dry-run] Would annotate (checkbox): $OLD_LINE" >&2
          echo "[dry-run]                      with: $NEW_LINE" >&2
          ANNOTATIONS_MADE=$((ANNOTATIONS_MADE + 1))
        else
          echo "[dry-run] would skip (checkbox): line_not_found_exact" >&2
          ITEMS_SKIPPED=$((ITEMS_SKIPPED + 1))
          SKIPPED_REASONS+=("line_not_found_exact")
        fi
      else
        # Apply annotation: replace first occurrence of the unchecked item
        # Use a temp file to avoid in-place issues
        TMPFILE=$(mktemp)
        # Replace only the first match of this exact line
        awk -v old="$OLD_LINE" -v new="$NEW_LINE" '
          !replaced && $0 == old {
            print new
            replaced = 1
            next
          }
          { print }
        ' "$ANNOTATE_TARGET" > "$TMPFILE"

        if diff -q "$TMPFILE" "$ANNOTATE_TARGET" > /dev/null 2>&1; then
          # No change was made (line not found as exact match)
          ITEMS_SKIPPED=$((ITEMS_SKIPPED + 1))
          SKIPPED_REASONS+=("line_not_found_exact")
          rm -f "$TMPFILE"
        else
          mv "$TMPFILE" "$ANNOTATE_TARGET"
          ANNOTATIONS_MADE=$((ANNOTATIONS_MADE + 1))
          echo "Annotated (checkbox): Task $TASK_NUM -> $ITEM_TEXT" >&2
        fi
      fi
    else
      # ─── Table-row branch: locate by (line_index, raw_line), rewrite in place ─────────────
      # Component text is never used to locate a line here -- two rows with identical component
      # text would collide on a text-based lookup, so location is strictly by the captured
      # (line_index, raw_line) pair.
      ON_DISK_LINE=""
      if [[ -n "$LINE_INDEX" ]]; then
        ON_DISK_LINE=$(sed -n "$((LINE_INDEX + 1))p" "$ANNOTATE_TARGET")
      fi

      # Precise already-annotated check: read the on-disk line at the captured index instead of
      # grepping for component text.
      if [[ "$ON_DISK_LINE" == *"*(Completed:"* ]]; then
        ITEMS_SKIPPED=$((ITEMS_SKIPPED + 1))
        SKIPPED_REASONS+=("already_annotated")
        [[ "$DRY_RUN" == "true" ]] && echo "[dry-run] would skip (table row): already_annotated" >&2
        continue
      fi

      # Stale-reference guard: if the on-disk line at LINE_INDEX no longer equals the RAW_LINE
      # captured at parse time, the file changed underneath us -- never write on a mismatch.
      if [[ -z "$LINE_INDEX" || "$ON_DISK_LINE" != "$RAW_LINE" ]]; then
        ITEMS_SKIPPED=$((ITEMS_SKIPPED + 1))
        SKIPPED_REASONS+=("table_row_line_mismatch")
        [[ "$DRY_RUN" == "true" ]] && echo "[dry-run] would skip (table row): table_row_line_mismatch" >&2
        continue
      fi

      # Build the replacement line with the same parse the parser itself used: match
      # ^\|(.*)\|(\s*)$, split('|') the inner text, append the suffix to the STATUS_INDEX cell
      # (preserving its leading whitespace and its trailing single space), rejoin with '|', and
      # re-append the captured trailing whitespace. Column count is identical before and after.
      NEW_LINE=$(python3 - "$RAW_LINE" "$STATUS_INDEX" "$ANNOTATION_SUFFIX" << 'PYEOF'
import re
import sys

raw_line, status_index, suffix = sys.argv[1], int(sys.argv[2]), sys.argv[3]
m = re.match(r'^\|(.*)\|(\s*)$', raw_line)
if not m:
    print("")
    sys.exit(0)
inner, trailing = m.group(1), m.group(2)
cols = inner.split('|')
if status_index < 0 or status_index >= len(cols):
    print("")
    sys.exit(0)
cell = cols[status_index]
cell_match = re.match(r'^(\s*)(.*?)(\s?)$', cell)
lead, body, trail_space = cell_match.group(1), cell_match.group(2), cell_match.group(3)
cols[status_index] = f"{lead}{body} {suffix}{trail_space}"
print("|" + "|".join(cols) + "|" + trailing)
PYEOF
)

      if [[ -z "$NEW_LINE" ]]; then
        ITEMS_SKIPPED=$((ITEMS_SKIPPED + 1))
        SKIPPED_REASONS+=("table_row_not_found_at_line")
        [[ "$DRY_RUN" == "true" ]] && echo "[dry-run] would skip (table row): table_row_not_found_at_line" >&2
        continue
      fi

      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[dry-run] Would annotate (table row): $RAW_LINE" >&2
        echo "[dry-run]                       with: $NEW_LINE" >&2
        ANNOTATIONS_MADE=$((ANNOTATIONS_MADE + 1))
      else
        # Apply with awk, replacing only the exact captured line at the exact captured index --
        # mirrors the checkbox branch's temp-file-then-mv apply.
        TARGET_LINE=$((LINE_INDEX + 1))
        TMPFILE=$(mktemp)
        awk -v ln="$TARGET_LINE" -v old="$RAW_LINE" -v new="$NEW_LINE" '
          NR == ln && $0 == old {
            print new
            next
          }
          { print }
        ' "$ANNOTATE_TARGET" > "$TMPFILE"

        if diff -q "$TMPFILE" "$ANNOTATE_TARGET" > /dev/null 2>&1; then
          # No change was made -- misleading to call this "line_not_found_exact" (that name
          # implies a checkbox-style text search); this is a line-index-targeted apply instead.
          ITEMS_SKIPPED=$((ITEMS_SKIPPED + 1))
          SKIPPED_REASONS+=("table_row_not_found_at_line")
          rm -f "$TMPFILE"
        else
          mv "$TMPFILE" "$ANNOTATE_TARGET"
          ANNOTATIONS_MADE=$((ANNOTATIONS_MADE + 1))
          echo "Annotated (table row): Task $TASK_NUM -> $ITEM_TEXT" >&2
        fi
      fi
    fi
  done

  # Second loud banner: annotate mode ran, high-confidence matches existed, and yet nothing was
  # applied -- this is exactly the silent no-op this task exists to eliminate. Computed from the
  # skip reasons accumulated by the loop above, before the medium/low "low_confidence" reasons
  # (irrelevant to this banner) are appended below.
  if [[ "$HIGH_CONFIDENCE_MATCHES" -gt 0 && "$ANNOTATIONS_MADE" -eq 0 ]]; then
    if [[ ${#SKIPPED_REASONS[@]} -eq 0 ]]; then
      DISTINCT_SKIP_REASONS=""
    else
      DISTINCT_SKIP_REASONS=$(printf '%s\n' "${SKIPPED_REASONS[@]}" | sort -u | paste -sd, -)
    fi
    echo "[ROADMAP ANNOTATION NO-OP - ${HIGH_CONFIDENCE_MATCHES} high-confidence match(es), 0 applied] Skip reasons: ${DISTINCT_SKIP_REASONS}" >&2
  fi

  # Report skipped medium/low confidence matches
  MEDIUM_LOW_COUNT=$(echo "$ROADMAP_MATCHES" | jq '[.[] | select(.confidence == "medium" or .confidence == "low")] | length')
  if [[ "$MEDIUM_LOW_COUNT" -gt 0 ]]; then
    ITEMS_SKIPPED=$((ITEMS_SKIPPED + MEDIUM_LOW_COUNT))
    for i in $(seq 0 $((MEDIUM_LOW_COUNT - 1))); do
      SKIPPED_REASONS+=("low_confidence")
    done
  fi
fi

# ─── Build output JSON ────────────────────────────────────────────────────────

if [[ ${#SKIPPED_REASONS[@]} -eq 0 ]]; then
  SKIPPED_REASONS_JSON="[]"
else
  SKIPPED_REASONS_JSON=$(printf '%s\n' "${SKIPPED_REASONS[@]}" | jq -R . | jq -s .)
fi

# Stable string-code warnings array (defect signal, additive-only): unparseable_roadmap fires when
# no recognized structure of any kind was found; annotation_noop fires when annotate mode ran,
# found high-confidence matches, and applied none of them. Neither fires spuriously on a working
# table roadmap -- unparseable_roadmap explicitly requires table_rows == 0 as well, so a
# table-only roadmap (phases == 0, checkboxes == 0, table_rows > 0) never trips it.
SILENT_NOOP=false
WARNINGS=()
if [[ "$ROADMAP_PARSEABLE" == "false" ]]; then
  WARNINGS+=("unparseable_roadmap")
fi
if [[ "$HIGH_CONFIDENCE_MATCHES" -gt 0 && "$ANNOTATIONS_MADE" -eq 0 ]]; then
  SILENT_NOOP=true
  WARNINGS+=("annotation_noop")
fi

if [[ ${#WARNINGS[@]} -eq 0 ]]; then
  WARNINGS_JSON="[]"
else
  WARNINGS_JSON=$(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s .)
fi

# ROADMAP_STATE and ROADMAP_MATCHES can each exceed Linux's MAX_ARG_STRLEN (131,072 bytes) --
# ROADMAP_STATE embeds every parsed phase/checkbox/table row including raw_line text;
# ROADMAP_MATCHES embeds one object per candidate match, several carrying line_index/raw_line/
# status_index too. Pass both via --slurpfile (temp files, using the same TMP_ROADMAP_STATE_SLURP/
# TMP_ROADMAP_MATCHES_SLURP mktemp paths declared and trapped above at the ALL_COMPLETED step),
# exactly analogous to that step's own file-not-argv fix. `--slurpfile` always binds an array of
# the file's JSON values, hence the `[0]` dereference in the filter body below. The remaining
# --argjson bindings below are small/bounded (counts, booleans, short arrays) and unaffected.
printf '%s' "$ROADMAP_STATE" > "$TMP_ROADMAP_STATE_SLURP"
printf '%s' "$ROADMAP_MATCHES" > "$TMP_ROADMAP_MATCHES_SLURP"

# Order is load-bearing here: build the report into TMP_REPORT FIRST; only once that succeeds
# (jq's own exit code, backstopped by `set -e` -- a jq failure aborts the script right here, before
# the commit below, leaving $ROADMAP_PATH untouched) does the real $ROADMAP_PATH get replaced by
# the staging copy; only after that succeeds is the report actually printed. report -> commit ->
# print, never any other order, so a crash at any point up through report-building leaves
# $ROADMAP_PATH exactly as it was before this run started.
jq -n \
  --slurpfile roadmap_state_arr "$TMP_ROADMAP_STATE_SLURP" \
  --slurpfile roadmap_matches_arr "$TMP_ROADMAP_MATCHES_SLURP" \
  --argjson annotations_made "$ANNOTATIONS_MADE" \
  --argjson items_skipped "$ITEMS_SKIPPED" \
  --argjson skipped_reasons "$SKIPPED_REASONS_JSON" \
  --argjson high_confidence_matches "$HIGH_CONFIDENCE_MATCHES" \
  --argjson silent_noop "$SILENT_NOOP" \
  --argjson phases "$PHASE_COUNT" \
  --argjson checkboxes "$CHECKBOX_COUNT" \
  --argjson table_rows "$TABLE_ROW_COUNT" \
  --argjson parseable "$ROADMAP_PARSEABLE" \
  --argjson warnings "$WARNINGS_JSON" \
  '($roadmap_state_arr[0]) as $roadmap_state |
   ($roadmap_matches_arr[0]) as $roadmap_matches |
   {
    "roadmap_state": $roadmap_state,
    "roadmap_matches": $roadmap_matches,
    "annotation_summary": {
      "annotations_made": $annotations_made,
      "items_skipped": $items_skipped,
      "skipped_reasons": $skipped_reasons,
      "high_confidence_matches": $high_confidence_matches,
      "silent_noop": $silent_noop
    },
    "roadmap_structure": {
      "phases": $phases,
      "checkboxes": $checkboxes,
      "table_rows": $table_rows,
      "parseable": $parseable
    },
    "warnings": $warnings
  }' > "$TMP_REPORT"

# Commit: replace the real $ROADMAP_PATH with the fully-annotated staging copy exactly once, here
# -- only reachable after the report above was built successfully. In parse-only mode
# (DO_ANNOTATE=false), ANNOTATE_TARGET IS $ROADMAP_PATH already, so there is nothing to move.
if [[ "$DO_ANNOTATE" == "true" ]]; then
  mv "$ANNOTATE_TARGET" "$ROADMAP_PATH"
fi

# Print: only after the commit above has succeeded.
cat "$TMP_REPORT"
