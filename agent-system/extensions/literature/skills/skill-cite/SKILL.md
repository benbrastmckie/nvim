---
name: skill-cite
description: Verify citation claims against Literature/ index and Zotero library. Invoke for /cite command.
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Cite Skill (Direct Execution)

Direct execution skill for verifying citation claims in task artifacts against the Literature/ index and Zotero library. Extracts citations, searches for source matches, scores confidence, presents findings interactively, and creates tasks for unverified claims.

**Key behavior**: Users always see citation findings BEFORE any tasks are created. Users select which unverified/gap claims to address via interactive prompts.

## Context References

Reference (do not load eagerly):
- Path: `@specs/state.json` - Machine state
- Path: `@specs/TODO.md` - Current task list
- Path: `@specs/literature/index.json` - Literature index for keyword matching

---

## Execution

### Step 1: Parse Arguments

Extract task number, optional description text, and flags from command input:

```bash
# Parse from command input
args="$ARGUMENTS"

# Extract task number (first numeric argument)
task_num=$(echo "$args" | grep -oP '^\s*\K\d+' | head -1)

# Check for --gaps flag (also show gap items separately)
show_gaps=false
if echo "$args" | grep -q -- '--gaps'; then
  show_gaps=true
fi

# Check for optional description text (everything after flags/number)
description_override=$(echo "$args" | sed 's/--[a-z-]*//g' | sed "s/$task_num//" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
```

If no task number is provided and no direct file path is given, report and exit:
```
## Error: No Task Specified

Usage: /cite N [--gaps]
  N        Task number to verify citations for
  --gaps   Also flag citations found but with no PDF source

Example: /cite 42
         /cite 42 --gaps
```

### Step 2: Generate Session ID

Generate session ID for tracking:

```bash
source .claude/scripts/lib/common.sh
session_id="$(common_session_id)"
```

### Step 3: Locate Task Artifacts

Read state.json to find the task slug and locate artifacts:

```bash
project_root="$(pwd)"
state_file="$project_root/specs/state.json"

# Find task slug from state.json
task_slug=$(jq -r --argjson num "$task_num" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  "$state_file")

# Also check archive
if [ -z "$task_slug" ] || [ "$task_slug" = "null" ]; then
  task_slug=$(jq -r --argjson num "$task_num" \
    '.archive[]? | select(.project_number == $num) | .project_name' \
    "$state_file" 2>/dev/null)
fi

# Construct task directory path (zero-padded 3 digits)
task_dir=$(printf "specs/%03d_%s" "$task_num" "$task_slug")

if [ ! -d "$project_root/$task_dir" ]; then
  echo "Error: Task directory not found: $task_dir"
  exit 1
fi

# Glob all artifact files (reports, plans, summaries)
artifact_files=()
while IFS= read -r -d '' f; do
  artifact_files+=("$f")
done < <(find "$project_root/$task_dir" -name "*.md" -print0 2>/dev/null)

if [ ${#artifact_files[@]} -eq 0 ]; then
  echo "No artifact files found in $task_dir"
  echo "Nothing to verify."
  exit 0
fi
```

### Step 4: Extract Citations

For each artifact file, run `cite-extract.sh` and aggregate results:

```bash
script_dir="$project_root/.claude/extensions/literature/scripts"
all_citations=()  # JSON objects as strings
total_found=0

for artifact_file in "${artifact_files[@]}"; do
  rel_path="${artifact_file#$project_root/}"

  # Run cite-extract.sh on the file
  raw_output=$("$script_dir/cite-extract.sh" --format=json "$artifact_file" 2>/dev/null) || {
    exit_code=$?
    # exit code 2 = no citations found (normal), anything else = error
    if [ $exit_code -ne 2 ]; then
      echo "Warning: cite-extract.sh failed for $rel_path (exit $exit_code)" >&2
    fi
    continue
  }

  # Add source_file field to each result and accumulate
  # cite-extract.sh output schema: [{claim, source_text, line_number, confidence, pattern_type}]
  enriched=$(echo "$raw_output" | jq --arg file "$rel_path" \
    '[.[] | . + {source_file: $file}]' 2>/dev/null) || continue

  count=$(echo "$enriched" | jq 'length' 2>/dev/null || echo 0)
  total_found=$((total_found + count))

  # Append to all_citations (collect as JSON array strings to merge later)
  all_citations+=("$enriched")
done

# Merge all citation arrays into one
if [ ${#all_citations[@]} -eq 0 ]; then
  combined_citations="[]"
else
  combined_citations=$(printf '%s\n' "${all_citations[@]}" | jq -s 'add // []')
fi
```

### Step 5: Handle No Citations Found

If no citations were extracted:

```
## No Citations Found

**Task**: #{N} — {task_slug}
**Artifacts Scanned**: {count} files in {task_dir}

No citation patterns detected across task artifacts.

Patterns searched: author_year, parenthetical, phrase_attribution,
theorem_attr, direct_quote, numeric_bracket, alpha_num_bracket, latex_cite
```

Exit gracefully without prompts.

### Step 6: Search Literature/ Index

For each unique citation claim, extract query terms and search `specs/literature/index.json`:

```bash
if [ -n "${LITERATURE_DIR:-}" ] && [ -d "$LITERATURE_DIR" ]; then
  lit_index="$LITERATURE_DIR/index.json"
else
  lit_index="$project_root/specs/literature/index.json"
fi
index_available=false
if [ -f "$lit_index" ]; then
  index_available=true
fi

# For each citation, extract key terms from source_text and match against index
# index.json entry schema: {id, title, keywords[], file, summary}
# Match strategy: count how many query terms appear in (title + keywords joined)

score_against_index() {
  local source_text="$1"
  local query_terms

  # Extract significant words (strip common stop words, lowercase, split)
  query_terms=$(echo "$source_text" | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9 ]/ /g' \
    | tr ' ' '\n' \
    | grep -vE '^(a|an|the|in|on|at|of|to|for|and|or|by|as|is|are|was|were|be|that|this|from|with|it|its|et|al|pp|vol|no|doi)$' \
    | grep -v '^[0-9]\{1,4\}$' \
    | sort -u | tr '\n' ' ')

  if [ -z "$query_terms" ] || [ "$index_available" = "false" ]; then
    echo "0"
    return
  fi

  # Count term overlaps in title + keywords fields
  jq -r --arg terms "$query_terms" '
    .entries // [] | map(
      (.title + " " + ((.keywords // []) | join(" "))) |
      ascii_downcase |
      . as $haystack |
      ($terms | split(" ") | map(select(length > 2)) |
        map(if (($haystack | test(.; "i")) // false) then 1 else 0 end) |
        add // 0)
    ) | max // 0
  ' "$lit_index" 2>/dev/null || echo "0"
}
```

### Step 7: Search Zotero

For each unique citation claim, search via `zotero-search.sh`:

```bash
# Check if Zotero is configured (zotero-search.sh exits 1 if library not found)
zotero_available=false
if "$script_dir/zotero-search.sh" --limit=1 --format=json "test" &>/dev/null; then
  zotero_available=true
elif [ $? -eq 2 ]; then
  # exit 2 = no results (library exists, query returned nothing)
  zotero_available=true
fi

search_zotero() {
  local source_text="$1"
  if [ "$zotero_available" = "false" ]; then
    echo "[]"
    return
  fi

  # zotero-search.sh accepts query terms as positional args
  # Output schema: [{citation_key, title, authors, year, score, pdf_paths, abstract_snippet}]
  local query_words
  query_words=$(echo "$source_text" | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9 ]/ /g' \
    | tr ' ' '\n' \
    | grep -vE '^(a|an|the|in|on|at|of|to|for|and|or|by|as|is|et|al|pp)$' \
    | grep -v '^[0-9]\{1,4\}$' \
    | sort -u | head -8 | tr '\n' ' ')

  if [ -z "$query_words" ]; then
    echo "[]"
    return
  fi

  # shellcheck disable=SC2086
  "$script_dir/zotero-search.sh" --limit=5 --format=json $query_words 2>/dev/null \
    || echo "[]"
}
```

### Step 8: Score Confidence

Apply scoring to each extracted citation and classify it:

**Scoring thresholds** (based on search results):
- **confirmed**: Zotero top result score >= 3 OR index keyword overlap >= 2
- **partial**: Zotero top result score 1–2 OR index keyword overlap == 1
- **unconfirmed**: No match in either Zotero or Literature/ index
- **gap**: Citation pattern found but source text suggests a specific work that exists in index/Zotero yet has no associated PDF

```bash
score_citation() {
  local source_text="$1"
  local pattern_type="$2"
  local extract_confidence="$3"  # from cite-extract.sh (0.5–0.9)

  # Get index overlap score
  local index_overlap
  index_overlap=$(score_against_index "$source_text")

  # Get Zotero results
  local zotero_results zotero_top_score
  zotero_results=$(search_zotero "$source_text")
  zotero_top_score=$(echo "$zotero_results" | jq '.[0].score // 0' 2>/dev/null || echo 0)

  # Classify
  local status best_match
  if [ "$zotero_top_score" -ge 3 ] 2>/dev/null || [ "$index_overlap" -ge 2 ] 2>/dev/null; then
    status="confirmed"
    best_match=$(echo "$zotero_results" | jq -r '.[0] | "\(.authors[0] // "Unknown") (\(.year // "n.d.")). \(.title)"' 2>/dev/null \
      || echo "Literature index match (overlap: $index_overlap)")
  elif [ "$zotero_top_score" -ge 1 ] 2>/dev/null || [ "$index_overlap" -ge 1 ] 2>/dev/null; then
    status="partial"
    best_match=$(echo "$zotero_results" | jq -r '.[0] | "\(.authors[0] // "Unknown") (\(.year // "n.d.")). \(.title)"' 2>/dev/null \
      || echo "Weak literature index match (overlap: $index_overlap)")
  else
    status="unconfirmed"
    best_match="No match found"
  fi

  # Check for gap: pattern found but PDF unavailable
  if [ "$status" != "unconfirmed" ] && [ "$show_gaps" = "true" ]; then
    local pdf_count
    pdf_count=$(echo "$zotero_results" | jq '.[0].pdf_paths // [] | length' 2>/dev/null || echo 0)
    if [ "$pdf_count" -eq 0 ] && [ "$zotero_top_score" -ge 1 ] 2>/dev/null; then
      status="gap"
    fi
  fi

  echo "${status}|${best_match}|${index_overlap}|${zotero_top_score}"
}
```

### Step 9: Display Results

Present findings grouped by confidence status (confirmed first as display-only, then actionable items):

```
## Citation Verification Results

**Task**: #{N} — {task_slug}
**Artifacts Scanned**: {count} files
**Citations Found**: {total} total
  - Confirmed: {confirmed_count} (sources verified)
  - Partial: {partial_count} (weak match — may need review)
  - Unconfirmed: {unconfirmed_count} (no source found)
  - Gap: {gap_count} (found but PDF unavailable)

---

### Confirmed ({count}) — No action needed

| Claim | Source | File | Match |
|-------|--------|------|-------|
| {claim truncated 40 chars} | {source_text 30 chars} | {file}:{line} | {best_match 40 chars} |
...

---

### Partial Matches ({count}) — May need verification

| Claim | Source | File | Best Match |
|-------|--------|------|------------|
| {claim} | {source_text} | {file}:{line} | {best_match} |
...

---

### Unconfirmed ({count}) — No source found

| Claim | Source | File | Pattern |
|-------|--------|------|---------|
| {claim} | {source_text} | {file}:{line} | {pattern_type} |
...
```

If `--gaps` flag was passed, also show a Gap section.

### Step 10: Interactive Selection

If there are no unconfirmed/gap/partial claims, report and exit:
```
All {N} citations confirmed. No tasks needed.
```

Otherwise, present actionable items via `AskUserQuestion`.

#### Step 10.1: Unconfirmed and Gap Items

**Standard case (<=20 items)**:

```json
{
  "question": "Select unverified citations to create tasks for:",
  "header": "Citation Verification",
  "multiSelect": true,
  "options": [
    {
      "label": "{claim truncated 60 chars}",
      "description": "{file}:{line} — {pattern_type} — no source found"
    },
    ...
  ]
}
```

**Large number (>20 items)** — add "Select all" at top:

```json
{
  "question": "Select unverified citations to create tasks for:",
  "header": "Citation Verification ({N} items)",
  "multiSelect": true,
  "options": [
    {
      "label": "Select all ({N} items)",
      "description": "Create verification task for every unconfirmed/gap citation"
    },
    {
      "label": "{claim truncated 60 chars}",
      "description": "{file}:{line} — {pattern_type}"
    },
    ...
  ]
}
```

If user selects nothing, exit gracefully:
```
No citations selected. No tasks created.
```

#### Step 10.2: Partial Match Items (Separate Prompt)

If partial matches exist AND user selected at least one item in Step 10.1 (or confirmed they want to proceed):

```json
{
  "question": "Partial matches also found. Select any to include in tasks?",
  "header": "Partial Matches (lower confidence)",
  "multiSelect": true,
  "options": [
    {
      "label": "{claim truncated 60 chars}",
      "description": "{file}:{line} — weak match: {best_match truncated 50 chars}"
    },
    ...
  ]
}
```

Combine selected partial items with the unconfirmed/gap selections for task creation.

### Step 11: Task Creation

For each selected citation claim, create a research/verification task in state.json.

#### Step 11.1: Get Next Task Number

```bash
next_num=$(jq -r '.next_project_number' "$state_file")
```

#### Step 11.2: Determine Task Type

Infer task type from the source file path of the citation:

```bash
detect_task_type() {
  local source_file="$1"
  if [[ "$source_file" == *.lean ]]; then
    echo "lean4"
  elif [[ "$source_file" == *.tex ]]; then
    echo "latex"
  elif [[ "$source_file" == .claude/* || "$source_file" == specs/* ]]; then
    echo "meta"
  else
    echo "general"
  fi
}
```

#### Step 11.3: Create Each Task

For each selected citation:

```bash
title="Verify citation: {claim truncated 60 chars}"
description="Locate or obtain source for the following unverified citation:\n\n> {source_text}\n\n**Extracted from**: \`{source_file}:{line_number}\`\n**Pattern type**: {pattern_type}\n**Confidence score**: {confidence}\n\n## Verification Steps\n\n- [ ] Search Literature/ index by keyword\n- [ ] Search Zotero library via /literature --search\n- [ ] If found: add entry to specs/literature/index.json\n- [ ] If not found: obtain PDF and run /literature --convert\n- [ ] Update claim in source artifact with proper citation key\n\n## Search Hints\n\nQuery terms extracted: {query_terms}"

slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd 'a-z0-9_' | cut -c1-50)

# Write task entry to temp file (two-step jq pattern)
task_entry=$(cat <<EOF
{
  "project_number": $next_num,
  "project_name": "$slug",
  "status": "not_started",
  "task_type": "$task_type",
  "title": "$title",
  "description": "$description"
}
EOF
)

# Update state.json using two-step pattern (avoids jq escaping issues)
tmp_task=$(mktemp)
echo "$task_entry" > "$tmp_task"
tmp_state=$(mktemp)

jq --slurpfile new_task "$tmp_task" \
  '.active_projects += [$new_task[0]] | .next_project_number += 1' \
  "$state_file" > "$tmp_state" \
  && mv "$tmp_state" "$state_file"

rm -f "$tmp_task"
next_num=$((next_num + 1))
```

#### Step 11.4: Topic Auto-Inference

For each task, infer topic from the parent task directory and source file:

```bash
inferred_topic=""
if [[ "$task_dir" == *".claude/"* ]] || [[ "$task_dir" == *"specs/"* ]]; then
  inferred_topic="agent-system"
elif [[ "$source_file" == *.tex ]] || [[ "$source_file" == *.lean ]]; then
  inferred_topic="formal-methods"
fi
```

If `inferred_topic` is non-empty, confirm via AskUserQuestion (Mode C Suggest-Wrap; Accept /
Override only — no Skip option; topic assignment is mandatory):

```json
{
  "question": "Topic for citation task #{N}?",
  "header": "Topic Confirm",
  "multiSelect": false,
  "options": [
    {"label": "Accept: {inferred_topic}", "description": "Use auto-inferred topic"},
    {"label": "Override...", "description": "Enter a different topic name"}
  ]
}
```

If "Override..." selected, follow up:
```json
{"question": "Enter topic name (lowercase, kebab-case):"}
```

If `inferred_topic` is empty (the heuristic missed), invoke the Mode A universal fallback
instead of leaving the task topicless: follow
@.claude/context/patterns/topic-assignment-pattern.md (Mode A: Interactive, batch variant)
and capture the result in `topic`.

### Step 12: State Update and Commit

After all tasks have been written to state.json:

#### Step 12.1: Assign Topics (Non-Blocking)

`$topic` is non-empty by construction (Accept/Override confirm or Mode A universal
fallback above); the `-n` guard below is defensive only.

```bash
if [[ -n "$topic" ]]; then
  bash .claude/scripts/manage-topics.sh set "$task_num_created" "$topic" \
    2>/dev/null || echo "Warning: manage-topics.sh set failed (non-fatal)" >&2
fi
```

#### Step 12.2: Regenerate TODO.md (Non-Blocking)

```bash
bash .claude/scripts/generate-todo.sh \
  2>/dev/null || echo "Note: Failed to regenerate TODO.md (non-fatal)" >&2
```

#### Step 12.3: Display Results

```
## Citation Verification Complete

**Task**: #{N} — {task_slug}
**Citations Scanned**: {total}
**Confirmed**: {confirmed_count}
**Tasks Created**: {created_count}

### Created Tasks

| # | Claim | Source File | Pattern |
|---|-------|-------------|---------|
| {task_num} | {claim 50 chars} | {file}:{line} | {pattern_type} |
...

---

**Next Steps**:
1. Review new tasks in TODO.md
2. Run `/orchestrate {first_task_num}` to begin locating sources
3. Use `/literature --search "query"` to search the Zotero library
```

### Step 13: Git Commit (Postflight)

If tasks were created, commit changes:

```bash
task_count={number of tasks created}
git -C "$project_root" add specs/TODO.md specs/state.json
git -C "$project_root" commit -m "cite: create $task_count citation verification tasks for task $task_num

Session: $session_id
"
```

If commit fails, log non-fatal warning and continue.

---

## Error Handling

See `rules/error-handling.md` for general patterns. Skill-specific behaviors:

- **cite-extract.sh exit 1** (setup error): Log warning per file, skip that file; continue with remaining files
- **cite-extract.sh exit 2** (no citations): Normal — skip file silently
- **zotero-search.sh exit 1** (library not found): Set `zotero_available=false`, proceed with index-only matching; note in results display: "Zotero unavailable — index-only verification"
- **zotero-search.sh exit 2** (no results): Normal — treat as score 0
- **specs/literature/index.json missing**: Set `index_available=false`, proceed with Zotero-only matching; note in results display
- **state.json write failure**: Report partial success — list which tasks were created before failure
- **Git commit failure**: Non-blocking (tasks still created in state.json)
- **No task directory found**: Exit with clear error message showing expected path

## Standards Reference

Implements the multi-task creation pattern (partial compliance):
- Item Discovery: cite-extract.sh extraction
- Interactive Selection: AskUserQuestion multiSelect (Steps 10.1 and 10.2)
- User Confirmation: implicit via selection (no items selected = no tasks)
- State Updates: Atomic state.json + generate-todo.sh

See `.claude/docs/reference/standards/multi-task-creation-standard.md` for the full standard.
