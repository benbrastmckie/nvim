#!/usr/bin/env bash
# memory-harvest.sh - Harvest memory candidates from state.json into the memory vault
#
# NOTE: this script is presently uncalled (no caller in the skill/command pipeline).
# memory_candidates is consumed via skill-todo's inline harvest logic (HarvestMemories stage),
# not via this script.
#
# Usage: memory-harvest.sh <task_number>
#
# Reads memory_candidates from state.json for the given task number,
# filters candidates with confidence >= 0.7, writes qualifying candidates
# to the memory vault, and updates the memory index.
#
# Exit codes:
#   0 - Success (even if no candidates to harvest)
#   1 - Error (missing arguments, state.json not found, etc.)
#
# Outputs:
#   stdout: Number of memories harvested (integer, for caller integration)
#   stderr: Diagnostic messages (errors, skipped duplicates)

set -euo pipefail

# --- Arguments ---
task_number="${1:-}"

if [ -z "$task_number" ]; then
  echo "Usage: memory-harvest.sh <task_number>" >&2
  exit 1
fi

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"
MEMORY_DIR="$PROJECT_ROOT/.memory/10-Memories"
INDEX_FILE="$PROJECT_ROOT/.memory/memory-index.json"
CONFIDENCE_THRESHOLD="0.7"

# --- Validate inputs ---
if [ ! -f "$STATE_FILE" ]; then
  echo "error: state.json not found at $STATE_FILE" >&2
  exit 1
fi

if [ ! -d "$MEMORY_DIR" ]; then
  echo "error: memory directory not found at $MEMORY_DIR" >&2
  exit 1
fi

if [ ! -f "$INDEX_FILE" ]; then
  echo "error: memory-index.json not found at $INDEX_FILE" >&2
  exit 1
fi

# --- Extract memory candidates from state.json ---
candidates=$(jq --argjson task "$task_number" --argjson threshold "$CONFIDENCE_THRESHOLD" '
  .active_projects[]? |
  select(.project_number == $task) |
  (.memory_candidates // []) |
  map(select((.confidence // 0) >= $threshold))
' "$STATE_FILE" 2>/dev/null)

if [ -z "$candidates" ] || [ "$candidates" = "null" ] || [ "$candidates" = "[]" ]; then
  # No candidates -- exit cleanly
  echo "0"
  exit 0
fi

candidate_count=$(echo "$candidates" | jq 'length')
if [ "$candidate_count" = "0" ]; then
  echo "0"
  exit 0
fi

# --- Process each candidate ---
harvested=0
today=$(date -u +%Y-%m-%d)

while IFS= read -r candidate_json; do
  # Extract fields
  content=$(echo "$candidate_json" | jq -r '.content // ""')
  category=$(echo "$candidate_json" | jq -r '.category // "INSIGHT"')
  source_artifact=$(echo "$candidate_json" | jq -r '.source_artifact // ""')
  confidence=$(echo "$candidate_json" | jq -r '.confidence // 0')
  keywords_json=$(echo "$candidate_json" | jq -r '.suggested_keywords // [] | join(",")')

  if [ -z "$content" ]; then
    echo "warning: skipping candidate with empty content" >&2
    continue
  fi

  # Extract first two keywords for ID generation
  kw1=$(echo "$candidate_json" | jq -r '.suggested_keywords[0] // "unknown"')
  kw2=$(echo "$candidate_json" | jq -r '.suggested_keywords[1] // "general"')

  # Normalize keywords: lowercase, replace non-alphanum with hyphens, trim leading/trailing hyphens
  kw1_norm=$(echo "$kw1" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]-' '-' | sed 's/^-//;s/-$//')
  kw2_norm=$(echo "$kw2" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]-' '-' | sed 's/^-//;s/-$//')
  cat_norm=$(echo "$category" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]-' '-' | sed 's/^-//;s/-$//')

  mem_id="MEM-${cat_norm}-${kw1_norm}-${kw2_norm}"
  mem_file="$MEMORY_DIR/${mem_id}.md"
  mem_rel_path=".memory/10-Memories/${mem_id}.md"

  # --- Duplicate check via index ---
  existing=$(jq --arg id "$mem_id" '.entries[] | select(.id == $id) | .id' "$INDEX_FILE" 2>/dev/null || true)
  if [ -n "$existing" ]; then
    echo "info: skipping duplicate memory $mem_id" >&2
    continue
  fi

  # --- Also check filesystem ---
  if [ -f "$mem_file" ]; then
    echo "info: skipping existing file $mem_id" >&2
    continue
  fi

  # --- Derive title from first sentence of content ---
  title=$(echo "$content" | sed 's/\. .*//' | cut -c1-80)

  # --- Build keywords array for frontmatter ---
  keywords_frontmatter=$(echo "$candidate_json" | jq -r '.suggested_keywords // [] | map("  - " + .) | join("\n")')

  # --- Estimate token count (approx: chars / 4) ---
  char_count=${#content}
  token_count=$(( char_count / 4 + 20 ))

  # --- Write memory file ---
  cat > "$mem_file" <<MEMEOF
---
title: "${title}"
created: ${today}
tags: [${category}]
topic: "task-${task_number}"
source: "${source_artifact}"
modified: ${today}
retrieval_count: 0
last_retrieved: null
keywords:
${keywords_frontmatter}
summary: "${title}"
token_count: ${token_count}
---

# ${title}

${content}

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
MEMEOF

  # --- Update index ---
  # Build new index entry
  new_entry=$(jq -n \
    --arg id "$mem_id" \
    --arg path "$mem_rel_path" \
    --arg title "$title" \
    --arg summary "$title" \
    --arg category "$category" \
    --argjson keywords "$(echo "$candidate_json" | jq '.suggested_keywords // []')" \
    --argjson token_count "$token_count" \
    --arg today "$today" \
    '{
      id: $id,
      path: $path,
      title: $title,
      summary: $summary,
      topic: ("task-" + ($id | split("-")[2] // "general")),
      category: $category,
      keywords: $keywords,
      token_count: $token_count,
      created: $today,
      modified: $today,
      last_retrieved: null,
      retrieval_count: 0
    }')

  # Append entry to index and update counters
  jq --argjson entry "$new_entry" --argjson tc "$token_count" '
    .entries += [$entry] |
    .entry_count = (.entries | length) |
    .total_tokens = ((.total_tokens // 0) + $tc)
  ' "$INDEX_FILE" > "${INDEX_FILE}.tmp" && mv "${INDEX_FILE}.tmp" "$INDEX_FILE"

  harvested=$(( harvested + 1 ))
  echo "info: harvested $mem_id (confidence: $confidence)" >&2

done < <(echo "$candidates" | jq -c '.[]')

# --- Output harvest count ---
echo "$harvested"
exit 0
