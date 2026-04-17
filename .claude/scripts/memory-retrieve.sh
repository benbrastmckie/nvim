#!/usr/bin/env bash
# memory-retrieve.sh - Two-phase auto-retrieval for memory system
#
# Usage: memory-retrieve.sh <description> <task_type> [focus_prompt]
#
# Phase 1: Score memory-index.json entries by keyword overlap + topic match
# Phase 2: Read selected memory files, format as <memory-context> block
#
# Exit 0 with content on stdout when memories found
# Exit 1 (empty stdout) when no matches or index missing
#
# Constants:
#   TOKEN_BUDGET=2000  - Maximum total tokens to include
#   MAX_ENTRIES=5      - Maximum number of memory entries
#   MIN_SCORE=1        - Minimum score threshold (must be > 0)

set -euo pipefail

# --- Constants ---
TOKEN_BUDGET=2000
MAX_ENTRIES=5
MIN_SCORE=1

# --- Arguments ---
description="${1:-}"
task_type="${2:-}"
focus_prompt="${3:-}"

if [ -z "$description" ] || [ -z "$task_type" ]; then
  exit 1
fi

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INDEX_FILE="$PROJECT_ROOT/.memory/memory-index.json"

# --- Phase 0: Validate index exists and has entries ---
if [ ! -f "$INDEX_FILE" ]; then
  exit 1
fi

entry_count=$(jq -r '.entry_count // 0' "$INDEX_FILE" 2>/dev/null)
if [ "$entry_count" = "0" ] || [ "$entry_count" = "null" ] || [ -z "$entry_count" ]; then
  exit 1
fi

# --- Phase 1: Extract keywords and score entries ---

# Combine description and focus prompt for keyword extraction
combined_text="$description $focus_prompt"

# Extract keywords: lowercase, split on non-alpha, remove stop words, filter short words, deduplicate, top 10
STOP_WORDS="the|a|an|and|or|but|in|on|at|of|to|for|is|are|was|were|be|been|being|have|has|had|do|does|did|will|would|could|should|may|might|can|shall|not|no|with|by|from|as|into|through|during|before|after|above|below|between|out|off|over|under|again|further|then|once|here|there|when|where|why|how|all|both|each|few|more|most|other|some|such|only|own|same|so|than|too|very|just|about|up|its|it|this|that|these|those|what|which|who|whom"

keywords=$(echo "$combined_text" | \
  tr '[:upper:]' '[:lower:]' | \
  tr -cs '[:alpha:]' '\n' | \
  grep -v -E "^($STOP_WORDS)$" | \
  awk 'length > 3' | \
  sort -u | \
  head -10 | \
  tr '\n' ' ' | \
  sed 's/ *$//')

if [ -z "$keywords" ]; then
  exit 1
fi

# Convert keywords to JSON array for jq
keywords_json=$(echo "$keywords" | tr ' ' '\n' | jq -R . | jq -s .)

# Score each entry: keyword overlap count + topic match bonus (+2)
scored_entries=$(jq --argjson kw "$keywords_json" --arg tt "$task_type" '
  .entries // [] |
  # Pre-filter: exclude tombstoned memories (absent status defaults to "active")
  map(select((.status // "active") == "active")) |
  map(
    . as $entry |
    ($entry.keywords // []) as $entry_kw |
    # Count keyword overlaps (case-insensitive)
    ([$kw[] | ascii_downcase] | map(
      . as $k |
      if ([$entry_kw[] | ascii_downcase] | index($k)) then 1 else 0 end
    ) | add // 0) as $kw_score |
    # Topic match bonus
    (if ($entry.topic // "") == $tt then 2
     elif ($entry.category // "") == $tt then 1
     else 0 end) as $topic_bonus |
    ($kw_score + $topic_bonus) as $total_score |
    {
      id: $entry.id,
      path: $entry.path,
      title: $entry.title,
      summary: $entry.summary,
      token_count: ($entry.token_count // 200),
      score: $total_score,
      retrieval_count: ($entry.retrieval_count // 0),
      last_retrieved: ($entry.last_retrieved // null)
    }
  ) | map(select(.score >= 1)) | sort_by(-.score)
' "$INDEX_FILE" 2>/dev/null)

if [ -z "$scored_entries" ] || [ "$scored_entries" = "[]" ] || [ "$scored_entries" = "null" ]; then
  exit 1
fi

# --- Phase 2: Greedy selection within token budget, max entries ---
selected=$(echo "$scored_entries" | jq --argjson budget "$TOKEN_BUDGET" --argjson max "$MAX_ENTRIES" '
  reduce .[] as $entry (
    {selected: [], total_tokens: 0, count: 0};
    if .count < $max and (.total_tokens + $entry.token_count) <= $budget then
      .selected += [$entry] |
      .total_tokens += $entry.token_count |
      .count += 1
    else .
    end
  ) | .selected
')

if [ -z "$selected" ] || [ "$selected" = "[]" ]; then
  exit 1
fi

# --- Read selected memory files and format output ---
output="<memory-context>\n"
output+="The following memories from previous sessions may be relevant to this task.\n\n"

selected_ids=()
while IFS= read -r entry_json; do
  entry_path=$(echo "$entry_json" | jq -r '.path')
  entry_title=$(echo "$entry_json" | jq -r '.title')
  entry_score=$(echo "$entry_json" | jq -r '.score')
  entry_id=$(echo "$entry_json" | jq -r '.id')

  full_path="$PROJECT_ROOT/$entry_path"

  if [ -f "$full_path" ]; then
    content=$(cat "$full_path")
    output+="### $entry_title (relevance: $entry_score)\n"
    output+="$content\n\n"
    selected_ids+=("$entry_id")
  fi
done < <(echo "$selected" | jq -c '.[]')

output+="</memory-context>"

# Check we actually got content
if [ ${#selected_ids[@]} -eq 0 ]; then
  exit 1
fi

# --- Update retrieval metadata in memory-index.json ---
today=$(date -u +%Y-%m-%d)
for id in "${selected_ids[@]}"; do
  jq --arg id "$id" --arg today "$today" '
    .entries |= map(
      if .id == $id then
        .retrieval_count = ((.retrieval_count // 0) + 1) |
        .last_retrieved = $today
      else . end
    )
  ' "$INDEX_FILE" > "${INDEX_FILE}.tmp" && mv "${INDEX_FILE}.tmp" "$INDEX_FILE"
done

# --- Output ---
printf '%b' "$output"
exit 0
