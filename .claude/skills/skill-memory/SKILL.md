---
name: skill-memory
description: Memory vault management - create, search, classify, and index memories. Invoke for /learn command memory operations.
allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion
---

# Memory Skill (Direct Execution)

Direct execution skill for memory vault management. Handles memory creation, similarity search, classification, and index maintenance through content mapping, MCP-based deduplication, and three memory operations (UPDATE, EXTEND, CREATE).

**MANDATORY INTERACTIVE REQUIREMENT -- DO NOT SKIP**:
- STOP at Step 4 and call AskUserQuestion to show files. Write NOTHING to disk until user responds.
- STOP at Memory Search and call AskUserQuestion for each segment. Write NOTHING to disk until user responds.
- These are not optional. Running autonomously without user input is a critical failure.

## Context References

Reference (do not load eagerly):
- Path: `@.memory/30-Templates/memory-template.md` - Memory template
- Path: `@.memory/20-Indices/index.md` - Memory index
- Path: `@.memory/memory-index.json` - Machine-queryable memory index
- Path: `@.claude/context/project/memory/learn-usage.md` - Usage guide

---

## Execution Modes

| Mode | Input | Description |
|------|-------|-------------|
| `text` | Text content | Add quoted text as memory |
| `file` | File path | Add single file content as memory |
| `directory` | Directory path | Scan directory for learnable content |
| `task` | Task number | Review task artifacts and create memories |

All non-task modes flow through: **Content Mapping** -> **Memory Search** -> **Memory Operations**

---

## Content Mapping

Content mapping is the intermediate representation between input acquisition and memory operations. It segments input into topic-aligned chunks that can be matched against existing memories.

### Content Map Data Structure

```json
{
  "source": {
    "type": "text|file|directory",
    "path": "/path/to/input",
    "total_tokens": 2500
  },
  "segments": [
    {
      "id": "seg-001",
      "topic": "python/libs/requests",
      "source_file": "/path/to/file.md",
      "source_lines": "15-42",
      "summary": "HTTP request retry pattern with backoff",
      "estimated_tokens": 350,
      "key_terms": ["requests", "retry", "backoff", "session", "timeout"]
    }
  ]
}
```

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique segment identifier (seg-NNN) |
| `topic` | string | Inferred topic path (slash-separated hierarchy) |
| `source_file` | string | Original file path (for file/directory modes) |
| `source_lines` | string | Line range in source file (e.g., "15-42") |
| `summary` | string | 1-2 sentence summary of segment content |
| `estimated_tokens` | number | Approximate token count for this segment |
| `key_terms` | array | 3-5 significant terms for matching |

### Segmentation Algorithms

#### Structured Files (Markdown)

Split at heading boundaries:

```
1. Identify all headings (# ## ### ####)
2. Each heading starts a new segment
3. Segment includes all content until next same-or-higher level heading
4. Top-level content before first heading becomes its own segment
```

#### Structured Files (Code)

Split at blank-line-separated blocks:

```
1. Identify function/class definitions
2. Group related comments with their definitions
3. Separate standalone comment blocks as documentation segments
4. Keep import/require blocks together
```

#### Unstructured Text

Split at paragraph boundaries with topic grouping:

```
1. Split at double-newline (paragraph boundaries)
2. Group adjacent paragraphs with keyword overlap >40%
3. Single-sentence paragraphs merge with adjacent
```

#### Directory Input

Each file becomes an initial segment, then large files are split:

```
1. Each file is an initial segment
2. Files >800 tokens are split at section boundaries
3. Files <100 tokens are candidates for merging with related files
```

### Small-Input Bypass

Inputs under 500 tokens skip segmentation and become a single segment:

```
if total_tokens < 500:
  segments = [{
    "id": "seg-001",
    "topic": inferred_topic,
    "summary": first_line_or_60_chars,
    "estimated_tokens": total_tokens,
    "key_terms": extract_keywords(content, 5)
  }]
```

### Segment Size Guidelines

| Condition | Action |
|-----------|--------|
| Segment <100 tokens | Merge with adjacent same-topic segment |
| Segment 200-500 tokens | Ideal size, no action |
| Segment >800 tokens | Split at next heading/paragraph boundary |

### Key Term Extraction

Extract 3-5 significant terms per segment:

```
1. Remove stop words (the, a, is, are, etc.)
2. Extract nouns and technical terms (>4 characters)
3. Prioritize: proper nouns > technical terms > common nouns
4. Deduplicate (case-insensitive)
5. Return top 5 by frequency within segment
```

---

## Memory Search

After content mapping, each segment is matched against existing memories to determine the appropriate operation (UPDATE, EXTEND, or CREATE).

### MCP Search Path

When MCP server is available, use the execute pattern:

```
For each segment in content_map.segments:
  query = segment.key_terms.join(" ")
  results = execute("search", {
    "query": query,
    "vault": ".memory",
    "limit": 5
  })
```

### Grep Fallback Path

When MCP is unavailable, use keyword-based file search:

```bash
# For each segment
for keyword in $key_terms; do
  grep -l -i "$keyword" .memory/10-Memories/*.md 2>/dev/null
done | sort | uniq -c | sort -rn | head -5
```

### Overlap Scoring

Score keyword overlap between segment and each matching memory:

```
overlap_score = |segment_terms intersect memory_terms| / |segment_terms|

Where:
- segment_terms = segment.key_terms
- memory_terms = keywords extracted from memory content (same algorithm)
```

### Classification Thresholds

| Overlap Score | Classification | Action |
|---------------|----------------|--------|
| >60% | HIGH | UPDATE - Replace memory content |
| 30-60% | MEDIUM | EXTEND - Append new section |
| <30% | LOW | CREATE - New memory |

### Search Result Presentation -- MANDATORY STOP

**YOU MUST call AskUserQuestion for EACH segment before writing anything. Do NOT infer what the user wants. Do NOT skip segments. Do NOT write memory files without explicit user confirmation per segment.**

Present each segment with related memories via AskUserQuestion:

```
Segment: {segment.summary}
Topic: {segment.topic}
Key terms: {segment.key_terms.join(", ")}

Related Memories:
1. MEM-requests-retry-patterns (72% overlap) -> Recommended: UPDATE
2. MEM-python-http-patterns (45% overlap) -> Recommended: EXTEND
3. MEM-api-error-handling (18% overlap) -> Recommended: CREATE (no strong match)

What would you like to do with this segment?
[ ] UPDATE MEM-requests-retry-patterns (replace content)
[ ] EXTEND MEM-python-http-patterns (append section)
[ ] CREATE new memory
[ ] SKIP - don't save this segment
```

### Interactive Override

Users can override any recommendation:
- Change UPDATE to CREATE (preserve existing, create duplicate)
- Change EXTEND to UPDATE (replace instead of append)
- Skip any segment
- Merge segments before processing (combine into single memory)

---

## Memory Operations

Three distinct operations for memory management:

### UPDATE Operation

Replace memory content while preserving structure:

```
1. Read existing memory file
2. Preserve frontmatter: created (original), tags, topic
3. Update frontmatter: modified = today
4. Move current content to ## History section with date marker
5. Replace main content with new segment content
6. Preserve ## Connections section
7. Write updated memory
```

Template for UPDATE:

```markdown
---
title: "{new_title_from_segment}"
created: {original_created}
tags: {merged_tags}
topic: "{existing_or_updated_topic}"
source: "{new_source}"
modified: {today}
---

# {new_title}

{new_content_from_segment}

## History

### Previous Version ({original_created})

{previous_content}

## Connections
{preserved_connections}
```

### EXTEND Operation

Append new dated section without modifying existing content:

```
1. Read existing memory file
2. Find insertion point (before ## Connections, or end of file)
3. Add dated extension section
4. Update frontmatter: modified = today
5. Optionally update tags if new topics introduced
6. Write updated memory
```

Template for EXTEND:

```markdown
## Extension ({today})

**Source**: {segment.source_file}

{segment_content}
```

### CREATE Operation

Generate new memory from segment:

```
1. Generate semantic slug from topic and title:

   generate_slug() {
     local topic="$1"
     local title="$2"
     local base=""

     # Priority 1: Topic path (most specific segment)
     if [ -n "$topic" ]; then
       base=$(echo "$topic" | rev | cut -d'/' -f1 | rev)
     fi

     # Priority 2: First 2-3 words of title
     local title_slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | \
       sed 's/[^a-z0-9 ]/-/g' | tr ' ' '-' | \
       cut -d'-' -f1-3 | sed 's/-$//')

     # Combine
     if [ -n "$base" ]; then
       slug="${base}-${title_slug}"
     else
       slug="$title_slug"
     fi

     # Sanitize and truncate to 50 chars
     slug=$(echo "$slug" | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-50)

     # Handle collision - NOTE: MEM- prefix preserved for grep discoverability
     local final_slug="$slug"
     local counter=2
     while [ -f ".memory/10-Memories/MEM-${final_slug}.md" ]; do
       final_slug="${slug}-${counter}"
       counter=$((counter + 1))
     done

     echo "$final_slug"
   }

   slug=$(generate_slug "$topic" "$title")
   filename="MEM-${slug}.md"

2. Apply memory template with all fields
3. Infer and apply topic
4. Add to index (both category and topic sections)
5. Write new memory file
```

Template for CREATE:

```markdown
---
title: "{segment.summary}"
created: {today}
tags: {inferred_tags}
topic: "{segment.topic}"
source: "{segment.source_file or 'user input'}"
modified: {today}
keywords: {segment.key_terms}
summary: "{segment.summary}"
retrieval_count: 0
last_retrieved:
---

# {segment.summary}

{segment_content}

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
```

**Note**: The MEM- prefix is preserved for grep discoverability (`grep -r "MEM-" .memory/`). Filenames follow the pattern `MEM-{semantic-slug}.md` (e.g., `MEM-requests-retry-patterns.md`).

### Topic Inference

Infer topic using four-source priority:

```
1. Source directory path (highest priority)
   - /project/src/utils/ -> "project/utils"
   - /home/user/notes/python/ -> "python"

2. Keyword analysis
   - Extract domain indicators: python, requests, http, api
   - Map to topic: "python/libs" or "python/patterns"

3. Related memory topics
   - If UPDATE/EXTEND: inherit topic from target memory
   - If CREATE with high-overlap match: suggest that topic

4. User confirmation/override
   - Always present inferred topic for confirmation
   - User can modify or create new topic path
```

### Index Maintenance

> **Note**: After each operation, update all three indexes: `index.md`, `.memory/10-Memories/README.md`, and `memory-index.json`. See "JSON Index Maintenance" and "Index Regeneration Pattern" below.

After each operation, update both `index.md` and `.memory/10-Memories/README.md`:

**index.md**:
```
1. Add/update entry in "## By Category" under appropriate tag
2. Add/update entry in "## By Topic" under topic path
3. Update "## Recent Memories" (prepend, keep last 10)
4. Update "## Statistics" counts
```

**`.memory/10-Memories/README.md`** -- regenerate the full file listing:
```
1. List all MEM-*.md files in the directory (ls .memory/10-Memories/MEM-*.md)
2. For each file, extract: title, topic, tags, created from frontmatter
3. Rewrite README.md with updated count and one entry per memory:
   ### [MEM-{slug}](MEM-{slug}.md)
   **Title**: {title}
   **Topic**: {topic}
   **Tags**: {tags}
   **Created**: {created}
4. Keep "## Navigation" section at the bottom
```

### Index Regeneration Pattern

To avoid concurrent write conflicts, regenerate index.md from filesystem state rather than append:

```bash
# 1. List all memory files
memories=$(ls .memory/10-Memories/MEM-*.md 2>/dev/null)

# 2. Extract metadata from each file
for mem in $memories; do
  title=$(grep -m1 "^title:" "$mem" | cut -d'"' -f2)
  topic=$(grep -m1 "^topic:" "$mem" | cut -d'"' -f2)
  created=$(grep -m1 "^created:" "$mem" | cut -d: -f2 | tr -d ' ')
  # Store for index generation
done

# 3. Regenerate index.md from extracted data
# Sort by date descending, write complete file
```

Benefits:
- No append conflicts (complete overwrite)
- Self-healing (missing entries recovered)
- Idempotent (multiple regenerations produce same result)

### JSON Index Maintenance

After each CREATE, UPDATE, or EXTEND operation, regenerate `.memory/memory-index.json` from filesystem state:

```bash
# 1. Scan all memory files
memories=$(ls .memory/10-Memories/MEM-*.md 2>/dev/null)

# 2. For each file, extract frontmatter fields
for mem in $memories; do
  title=$(grep -m1 "^title:" "$mem" | sed 's/^title: *//' | tr -d '"')
  topic=$(grep -m1 "^topic:" "$mem" | sed 's/^topic: *//' | tr -d '"')
  created=$(grep -m1 "^created:" "$mem" | sed 's/^created: *//')
  modified=$(grep -m1 "^modified:" "$mem" | sed 's/^modified: *//')
  keywords=$(grep -m1 "^keywords:" "$mem" | sed 's/^keywords: *//')
  summary=$(grep -m1 "^summary:" "$mem" | sed 's/^summary: *//' | tr -d '"')
  retrieval_count=$(grep -m1 "^retrieval_count:" "$mem" | sed 's/^retrieval_count: *//')
  last_retrieved=$(grep -m1 "^last_retrieved:" "$mem" | sed 's/^last_retrieved: *//')
  status=$(grep -m1 "^status:" "$mem" | sed 's/^status: *//')
  # Default status to "active" when absent
  if [ -z "$status" ]; then status="active"; fi
  # Compute token_count: word_count * 1.3
  word_count=$(wc -w < "$mem")
  token_count=$(echo "$word_count * 1.3" | bc | cut -d. -f1)
  # Derive id from filename: MEM-{slug}.md -> MEM-{slug}
  id=$(basename "$mem" .md)
  # Derive category from first tag
  category=$(grep -m1 "^tags:" "$mem" | sed 's/^tags: *\[//' | cut -d, -f1 | tr -d '] ')
done

# 3. Build JSON structure
{
  "version": "1.0.0",
  "generated_at": "$(date +%Y-%m-%d)",
  "entry_count": N,
  "total_tokens": sum_of_token_counts,
  "entries": [...]
}

# 4. Write to .memory/memory-index.json (complete overwrite)
```

**Schema Fields per Entry**:

| Field | Type | Source |
|-------|------|--------|
| `id` | string | Filename without `.md` extension |
| `path` | string | Relative path from project root |
| `title` | string | Frontmatter `title` |
| `summary` | string | Frontmatter `summary` |
| `topic` | string | Frontmatter `topic` |
| `category` | string | First tag from frontmatter `tags` |
| `keywords` | array | Frontmatter `keywords` |
| `token_count` | number | Word count * 1.3, rounded down |
| `created` | string | Frontmatter `created` (ISO date) |
| `modified` | string | Frontmatter `modified` (ISO date) |
| `last_retrieved` | string/null | Frontmatter `last_retrieved` |
| `retrieval_count` | number | Frontmatter `retrieval_count` |
| `status` | string | Frontmatter `status` (default: "active" when absent; "tombstoned" for purged memories) |

### Validate-on-Read

Before using `memory-index.json` for retrieval or scoring, validate that the index matches the filesystem:

```
1. List all MEM-*.md files in .memory/10-Memories/
2. List all entry ids in memory-index.json
3. Compare:
   - Files on disk not in index -> INDEX STALE (missing entries)
   - Index entries with no file on disk -> INDEX STALE (orphaned entries)
   - All match -> INDEX VALID
4. If INDEX STALE: regenerate memory-index.json using JSON Index Maintenance procedure
5. If INDEX VALID: proceed with retrieval
```

This ensures the index is always consistent, even if manual file edits bypass the skill pipeline.

**Status Field Handling**: During regeneration, the `status` field is read from each memory's frontmatter. If absent, it defaults to `"active"`. Tombstoned memories (with `status: tombstoned` in frontmatter) retain their `"tombstoned"` status in the regenerated index. The `tombstoned_at` and `tombstone_reason` fields are also preserved when present.

---

## Task Mode Execution

Task mode has special handling for reviewing existing task artifacts.

### Step 1: Locate Task Directory

```bash
task_num=$task_number
padded_num=$(printf "%03d" $task_num)
task_dir=$(ls -d specs/${padded_num}_* 2>/dev/null | head -1)

if [ -z "$task_dir" ]; then
  task_dir=$(ls -d specs/${task_num}_* 2>/dev/null | head -1)
fi

if [ -z "$task_dir" ]; then
  echo "Task directory not found: specs/${padded_num}_*"
  exit 1
fi
```

### Step 2: Scan Artifacts

```bash
artifacts=$(find "$task_dir" -type f -name "*.md" | sort)

if [ -z "$artifacts" ]; then
  echo "No artifacts found for task ${task_number}"
  exit 1
fi
```

### Step 3: Present Artifact List

Display via AskUserQuestion:

```json
{
  "question": "Select artifacts to review for memory extraction:",
  "header": "Task Artifacts",
  "multiSelect": true,
  "options": [
    {
      "label": "{artifact_1_name}",
      "description": "{artifact_1_path}"
    }
  ]
}
```

### Step 4: Process Through Content Mapping

For each selected artifact:
1. Read content
2. If >500 tokens: run through content mapping (segmentation)
3. If <=500 tokens: treat as single segment
4. Proceed to Memory Search (Phase 4)
5. Proceed to Memory Operations (Phase 5)

### Step 5: Classification Taxonomy

For task artifacts, also present classification options:

```json
{
  "question": "Classify this segment:",
  "header": "Classification: {segment.summary}",
  "multiSelect": false,
  "options": [
    {"label": "[TECHNIQUE]", "description": "Reusable method or approach"},
    {"label": "[PATTERN]", "description": "Design or implementation pattern"},
    {"label": "[CONFIG]", "description": "Configuration or setup knowledge"},
    {"label": "[WORKFLOW]", "description": "Process or procedure"},
    {"label": "[INSIGHT]", "description": "Key learning or understanding"},
    {"label": "[SKIP]", "description": "Not valuable for memory"}
  ]
}
```

### Step 6: Return Result

```json
{
  "status": "completed",
  "mode": "task",
  "artifacts_reviewed": [...],
  "content_map": { ... },
  "operations": [
    {"type": "CREATE", "memory_id": "MEM-...", "category": "[PATTERN]"}
  ],
  "memories_affected": 3
}
```

---

## Directory Mode Execution

Directory mode scans a directory tree for learnable content.

### Step 1: Recursive Scanning

```bash
# Exclusion patterns
EXCLUDES="-path '*/.git' -prune -o -path '*/node_modules' -prune -o -path '*/__pycache__' -prune -o -path '*/.obsidian' -prune"

# Find all files
files=$(find "$directory_path" $EXCLUDES -type f -print | head -250)
```

### Step 2: Two-Tier Text Detection

**Tier 1: Extension Whitelist**

Recognized text extensions (alphabetized by category):

| Category | Extensions |
|----------|------------|
| Code | .c, .cpp, .cs, .go, .h, .hpp, .java, .js, .jsx, .kt, .lua, .php, .pl, .py, .r, .rb, .rs, .scala, .sh, .swift, .ts, .tsx, .vim |
| Config | .cfg, .conf, .ini, .json, .toml, .xml, .yaml, .yml |
| Data | .csv, .sql |
| Documentation | .adoc, .asciidoc, .md, .org, .rdoc, .rst, .tex, .txt |
| Web | .css, .htm, .html, .less, .sass, .scss, .svg |
| Scripting | .fnl, .janet, .nix |

**Tier 2: MIME-Type Fallback**

For files without recognized extensions:

```bash
mime=$(file --mime-type -b "$file")
if [[ "$mime" == text/* ]]; then
  # Include file
fi
```

### Step 3: Size Limits

```bash
# Per-file limit
if [ $(stat -c%s "$file") -gt 102400 ]; then
  echo "Skipping large file: $file (>100KB)"
  continue
fi

# Warning at 50 files
if [ ${#files[@]} -gt 50 ]; then
  echo "Warning: ${#files[@]} files found. Consider narrowing scope."
fi

# Hard limit at 200 files
if [ ${#files[@]} -gt 200 ]; then
  echo "Error: Too many files (${#files[@]}). Maximum is 200."
  echo "Narrow your path or use file mode for specific files."
  exit 1
fi
```

### Step 4: File Selection (Paginated) -- MANDATORY STOP

**YOU MUST call AskUserQuestion here. Do NOT skip to Step 5. Do NOT process any files until the user has made their selection.**

Present files in pages of 10 to avoid overwhelming the display. Accumulate selections across all pages before processing.

```
selected_files = []
page_size = 10
total_files = len(files)
page = 0

while page * page_size < total_files:
  start = page * page_size
  end = min(start + page_size, total_files)
  page_files = files[start:end]
  remaining = total_files - end
  page_num = page + 1
  total_pages = ceil(total_files / page_size)

  # Build options for this page
  options = [{"label": relative_path, "description": file_size} for each file in page_files]

  # Add navigation options at the bottom
  if remaining > 0:
    options.append({"label": "--- Continue to next page ---", "description": f"{remaining} more files remaining"})

  AskUserQuestion({
    "question": f"Select files to include (page {page_num}/{total_pages}, showing {start+1}-{end} of {total_files}):",
    "header": f"Directory Scan: {directory_path}",
    "multiSelect": true,
    "options": options
  })

  # Add any selected files (excluding the navigation option) to accumulated list
  selected_files.extend(user_selections excluding navigation option)

  # If user selected "Continue to next page" OR there are more pages, advance
  # If user did NOT select "Continue to next page" on the last page, stop
  if "--- Continue to next page ---" not in user_selections and remaining > 0:
    # User is done selecting (didn't ask for more)
    break

  page += 1

# After all pages processed, confirm total selection
if len(selected_files) == 0:
  print("No files selected. Exiting.")
  exit
```

Example page 1 of 3:
```json
{
  "question": "Select files to include (page 1/3, showing 1-10 of 28):",
  "header": "Directory Scan: /home/user/project/",
  "multiSelect": true,
  "options": [
    {"label": "README.md", "description": "4.1KB"},
    {"label": "src/main.lua", "description": "2.3KB"},
    {"label": "--- Continue to next page ---", "description": "18 more files remaining"}
  ]
}
```

### Step 5: Route Through Pipeline

For each selected file:
1. Read file content
2. Run through content mapping (directory-type segmentation)
3. Route segments through memory search
4. Route through memory operations
5. Update index

### Step 6: Return Result

```json
{
  "status": "completed",
  "mode": "directory",
  "files_scanned": 45,
  "files_selected": 12,
  "content_map": { ... },
  "operations": [...],
  "memories_affected": 8
}
```

---

## Text Mode Execution

### Step 1: Parse Input

```bash
content="$text_content"
source="user input"
```

### Step 2: Content Mapping

For text >500 tokens, segment at paragraph boundaries:

```
1. Split at double-newline
2. Group related paragraphs
3. Generate single content map
```

For text <500 tokens, create single segment.

### Step 3: Memory Search & Operations

Route through standard memory search and operations pipeline.

### Step 4: Return Result

```json
{
  "status": "completed",
  "mode": "text",
  "content_map": { ... },
  "operations": [...],
  "memories_affected": 1
}
```

---

## File Mode Execution

### Step 1: Read File

```bash
if [ ! -f "$file_path" ]; then
  echo "File not found: $file_path"
  exit 1
fi

content=$(cat "$file_path")
source="file: $file_path"
```

### Step 2: Content Mapping

Apply structured or unstructured segmentation based on file type.

### Step 3: Memory Search & Operations

Route through standard pipeline.

### Step 4: Return Result

```json
{
  "status": "completed",
  "mode": "file",
  "file_path": "...",
  "content_map": { ... },
  "operations": [...],
  "memories_affected": 2
}
```

---

## Error Handling

### No Content Provided

```
Usage: /learn <text or file path or directory> OR /learn --task N
```

### File Not Found

```
File not found: {path}
```

### Directory Not Found

```
Directory not found: {path}
```

### Empty Directory

```
No text files found in: {path}
```

### Too Many Files

```
Too many files ({N}). Maximum is 200.
Narrow your path or use file mode for specific files.
```

### Task Directory Not Found

```
Task directory not found: specs/{NNN}_*
```

### User Cancels

```
Memory operation cancelled. No files created.
```

### All Content Skipped

```
No memories created (all content skipped)
```

### MCP Unavailable

```
MCP search unavailable. Using grep-based fallback.
```

---

## Git Commit (Postflight)

After successful memory operations:

```bash
git add .memory/
git commit -m "memory: add/update ${memories_affected} memories

Session: ${session_id}
```

---

## Mode: distill

Memory vault distillation: scoring, health reporting, and maintenance operations. Invoked by `/distill` command with `mode=distill`.

### Prerequisites

**Validate-on-Read**: Before scoring, run the validate-on-read procedure from the "Validate-on-Read" section above to ensure `memory-index.json` is consistent with the filesystem. If stale, regenerate using the "JSON Index Maintenance" procedure before proceeding.

### Sub-Mode Dispatch

| Sub-Mode | Description | Status |
|----------|-------------|--------|
| `report` | Generate health report with scoring | Available (task 449) |
| `purge` | Tombstone stale/zero-retrieval memories | Available (task 450) |
| `merge` | Combine memories with duplicate score > 0.6 | Available (task 451) |
| `compress` | Summarize memories with size penalty > 0.5 | Available (task 452) |
| `refine` | Improve memory quality (keywords, tags) | Available (task 452) |
| `gc` | Hard-delete tombstoned memories past grace period | Available (task 450) |
| `auto` | Automated distillation (Tier 1 refine only) | Available (task 452) |

All sub-modes are now available. No placeholder responses needed.

### Scoring Engine

The scoring engine computes a composite maintenance score for each memory in the vault. Higher scores indicate memories that are better candidates for maintenance operations.

#### Input

Read all entries from `.memory/memory-index.json` after validate-on-read. Each entry provides:
- `created` (ISO date)
- `modified` (ISO date)
- `last_retrieved` (ISO date or null)
- `retrieval_count` (number)
- `token_count` (number)
- `keywords` (array of strings)

#### Component 1: Staleness Score (weight: 0.3)

Measures how long since the memory was last useful.

```
days_since_last = days_between(today, last_retrieved or created)

staleness = min(1.0, days_since_last / 90)

# FSRS adjustment: reduce staleness for actively retrieved old memories
if retrieval_count > 0 AND days_since_created > 60:
  staleness = max(0, staleness - 0.3)
```

- Range: 0.0 (fresh) to 1.0 (90+ days stale)
- FSRS adjustment rewards memories that have proven useful over time

#### Component 2: Zero-Retrieval Penalty (weight: 0.25)

Penalizes memories that have never been retrieved after a grace period.

```
if retrieval_count == 0 AND days_since_created > 30:
  zero_retrieval = 1.0
else:
  zero_retrieval = 0.0
```

- Binary: 0.0 (has retrievals or too new) or 1.0 (never retrieved, older than 30 days)

#### Component 3: Size Penalty (weight: 0.2)

Penalizes oversized memories that may benefit from compression.

```
size_penalty = max(0, (token_count - 600) / 600)
```

- Range: 0.0 (600 tokens or fewer) to unbounded (linear above 600)
- A 1200-token memory scores 1.0; a 300-token memory scores 0.0

#### Component 4: Duplicate Score (weight: 0.25)

Measures keyword overlap with the most similar other memory in the vault.

```
for each other_memory in vault:
  overlap = |memory.keywords intersect other_memory.keywords| / |memory.keywords|

duplicate = max(overlap across all other memories)
```

- Range: 0.0 (no keyword overlap) to 1.0 (complete keyword subset)
- Uses Jaccard-like ratio: intersection size divided by the memory's own keyword count

#### Composite Score

```
composite = (staleness * 0.3) + (zero_retrieval * 0.25) + (size_penalty * 0.2) + (duplicate * 0.25)
composite = clamp(composite, 0, 1)
```

- Weights sum to 1.0 (0.3 + 0.25 + 0.2 + 0.25)
- Range: 0.0 (healthy memory) to 1.0 (strong maintenance candidate)

#### Topic-Cluster Grouping

Group memories by topic cluster for the health report. The cluster key is the first path segment of the memory's `topic` field:

```
cluster_key = topic.split("/")[0]

# Example:
# topic "python/libs/requests" -> cluster "python"
# topic "lua/patterns" -> cluster "lua"
# topic "" or null -> cluster "uncategorized"
```

### Maintenance Candidate Classification

Based on composite scores, classify each memory:

| Composite Score | Classification | Recommended Action |
|-----------------|----------------|-------------------|
| >= 0.7 | Purge candidate | Remove (--purge) |
| >= 0.5 | Merge/compress candidate | Merge duplicates (--merge) or compress (--compress) |
| >= 0.3 | Review candidate | May benefit from refinement (--refine) |
| < 0.3 | Healthy | No action needed |

Additionally, flag specific conditions:
- `duplicate > 0.6` -> Merge candidate regardless of composite
- `size_penalty > 0.5` -> Compress candidate regardless of composite
- `zero_retrieval == 1.0` -> Review for relevance

### Health Report Template

The `report` sub-mode generates a formatted health report displayed to the user. Template:

```
## Memory Vault Health Report

**Generated**: {today}
**Vault**: .memory/

---

### Overview

| Metric | Value |
|--------|-------|
| Total memories | {total_count} |
| Total tokens | {total_tokens} |
| Average tokens/memory | {avg_tokens} |
| Oldest memory | {oldest_date} ({oldest_id}) |
| Newest memory | {newest_date} ({newest_id}) |

---

### Category Distribution

| Category | Count | Tokens | Avg Score |
|----------|-------|--------|-----------|
| {category_1} | {count} | {tokens} | {avg_composite} |
| {category_2} | {count} | {tokens} | {avg_composite} |
| ... | ... | ... | ... |

---

### Topic Clusters

| Cluster | Memories | Avg Staleness | Avg Duplicate |
|---------|----------|---------------|---------------|
| {cluster_1} | {count} | {avg_staleness} | {avg_duplicate} |
| {cluster_2} | {count} | {avg_staleness} | {avg_duplicate} |
| ... | ... | ... | ... |

---

### Retrieval Statistics

| Metric | Value |
|--------|-------|
| Never retrieved | {never_retrieved_count} ({never_retrieved_pct}%) |
| Retrieved 1-3 times | {low_retrieval_count} |
| Retrieved 4+ times | {high_retrieval_count} |
| Most retrieved | {most_retrieved_id} ({most_retrieved_count} times) |

---

### Maintenance Candidates

#### Purge Candidates (score >= 0.7)
{purge_list or "None"}

#### Merge Candidates (duplicate > 0.6)
{merge_list or "None"}

#### Compress Candidates (size > 0.5)
{compress_list or "None"}

#### Review Candidates (score 0.3-0.7)
{review_list or "None"}

---

### Health Score

**Score**: {health_score}/100
**Status**: {status_emoji} {status_label}

Formula: `100 - (purge_count * 3) - (merge_count * 5) - (compress_count * 2)`

| Threshold | Status |
|-----------|--------|
| 80-100 | Healthy |
| 60-79 | Manageable |
| 40-59 | Concerning |
| 0-39 | Critical |

---

### Recommended Actions

{action_list based on candidates found}
```

#### Health Score Formula

```
health_score = 100 - (purge_count * 3) - (merge_count * 5) - (compress_count * 2)
health_score = clamp(health_score, 0, 100)
```

Where:
- `purge_count` = number of memories with composite score >= 0.7
- `merge_count` = number of memories with duplicate score > 0.6
- `compress_count` = number of memories with size_penalty > 0.5

#### Health Status Thresholds

| Score Range | Status | Description |
|-------------|--------|-------------|
| 80-100 | healthy | Vault is well-maintained |
| 60-79 | manageable | Some maintenance recommended |
| 40-59 | concerning | Significant maintenance needed |
| 0-39 | critical | Urgent maintenance required |

These thresholds mirror `repository_health.status` vocabulary in state.json.

### Sub-Mode: merge

Combine duplicate memories with high keyword overlap. The merge operation identifies pairwise duplicate candidates within topic clusters, presents them for interactive selection, merges content with a keyword superset guarantee, tombstones the absorbed secondary, updates cross-references, and regenerates indexes.

#### Edge Case Checks

Before candidate identification, validate:

```
1. Run validate-on-read to ensure memory-index.json is consistent
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If fewer than 2 non-tombstoned memories:
   Display: "Merge requires at least 2 active memories. Vault has {count}."
   Return early.
```

#### Pairwise Keyword Overlap Algorithm

Compute pairwise overlap within each topic cluster:

```
1. Group non-tombstoned memories by topic cluster:
   cluster_key = topic.split("/")[0]
   If topic is empty or null: cluster_key = "uncategorized"

2. For each cluster with 2+ memories, compute pairwise overlap:
   for each pair (A, B) in cluster:
     overlap_ab = |A.keywords intersect B.keywords| / |A.keywords|
     overlap_ba = |A.keywords intersect B.keywords| / |B.keywords|
     pair_overlap = max(overlap_ab, overlap_ba)

   Note: Use max of both asymmetric directions so that a small memory
   with all keywords contained in a larger memory is detected.

3. Handle empty keyword arrays:
   If either A.keywords or B.keywords is empty: pair_overlap = 0.0
   (Cannot merge memories with no keyword basis for comparison)

4. Filter pairs where pair_overlap >= 0.6 (60% threshold)

5. Sort candidate pairs by pair_overlap descending within each cluster
```

#### Dry-Run Mode

When `--dry-run` is set, compute and display candidates without writing any files:

```
Display per cluster:
  ## Merge Candidates (Dry Run)

  ### Cluster: {cluster_key}

  | Primary | Secondary | Overlap | Shared Keywords |
  |---------|-----------|---------|-----------------|
  | {A.id} | {B.id} | {pair_overlap}% | {shared_keywords} |

  {total_pairs} merge candidate pair(s) found across {cluster_count} cluster(s).
  Run /distill --merge without --dry-run to execute.

Return early after display. No files are modified.
```

#### Interactive Selection (AskUserQuestion)

Present merge candidates per topic cluster for user selection:

```
For each cluster with candidates:
  AskUserQuestion({
    "question": "Select pairs to merge in cluster '{cluster_key}':",
    "header": "Merge Candidates: {cluster_key}",
    "multiSelect": true,
    "options": [
      {
        "label": "{A.title} + {B.title}",
        "description": "{pair_overlap}% overlap | Shared: {shared_keywords} | Retrievals: {A.retrieval_count}, {B.retrieval_count}"
      }
    ]
  })
```

If no pairs above threshold in any cluster:
```
Display: "No merge candidates found (no pairs with >= 60% keyword overlap)."
Return early.
```

If user selects no pairs across all clusters:
```
Display: "No pairs selected. No merges performed."
Return early.
```

#### Primary Determination

For each selected pair, determine which memory is primary (target) and which is secondary (absorbed):

```
Primary selection rules (first match wins):
1. Higher retrieval_count -> primary
2. If retrieval_count equal: older created date -> primary
3. If both equal: alphabetically first id -> primary (deterministic tiebreaker)
```

#### Merged Content Template

The primary memory file is rewritten with merged content:

**Frontmatter merging rules**:
```
title:            primary.title (unchanged)
created:          min(primary.created, secondary.created) -- earliest
modified:         today (ISO date)
tags:             union(primary.tags, secondary.tags) -- deduplicated
topic:            primary.topic (unchanged)
source:           primary.source (unchanged)
keywords:         union(primary.keywords, secondary.keywords) -- deduplicated, sorted
summary:          primary.summary (unchanged)
retrieval_count:  primary.retrieval_count + secondary.retrieval_count
last_retrieved:   max(primary.last_retrieved, secondary.last_retrieved) -- most recent, skip nulls
token_count:      recomputed after merge (word_count * 1.3, rounded down)
status:           omit (active is default when absent)
```

**Content structure**:
```markdown
---
{merged frontmatter}
---

# {primary.title}

{primary existing content - everything between title heading and first ## section}

## Merged From {secondary.id}

**Original Title**: {secondary.title}
**Merged**: {today}
**Overlap Score**: {pair_overlap}%

{secondary content - everything between title heading and ## Connections in secondary}

## Connections
{union of both connection sections, with [[{secondary.id}]] references replaced by [[{primary.id}]]}
```

#### Keyword Superset Guarantee

**CRITICAL INVARIANT**: Before writing the merged file, verify:

```
required_keywords = union(primary.keywords, secondary.keywords)
merged_keywords = merged_frontmatter.keywords

assertion: set(merged_keywords) >= set(required_keywords)

If assertion fails:
  Log error: "KEYWORD SUPERSET VIOLATION: missing keywords: {required - merged}"
  Abort this merge pair (do not write file)
  Preserve both original files unchanged
  Continue with remaining pairs
  Report violation in operation summary
```

This guarantee ensures no keyword coverage is lost during merging.

#### Tombstone Application

After successful merge, tombstone the secondary memory:

```
Add to secondary's frontmatter (preserve all existing fields):
  status: tombstoned
  tombstoned_at: {today ISO8601}
  tombstone_reason: "merged_into:{primary.id}"

Do NOT delete the file.
Do NOT remove from index (index regeneration will include tombstone status).
```

The tombstone fields are identical to those used by the purge sub-mode (task 450):
- `status: tombstoned`
- `tombstoned_at: {ISO8601 date}`
- `tombstone_reason: "{reason}"` -- for merge, reason is `"merged_into:{primary_id}"`

#### Cross-Reference Update

After tombstoning, update wiki-link references across all non-tombstoned memories:

```
1. Scan all .memory/10-Memories/*.md files
2. For each file that is NOT tombstoned:
   Search for [[{secondary.id}]] references
   Replace with [[{primary.id}]]
3. Log all replacements: "{file}: replaced [[{secondary.id}]] -> [[{primary.id}]]"
```

#### Index Regeneration

After ALL merges in the batch are complete (not after each individual merge):

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
   - Include tombstoned memories with status: "tombstoned"
2. Regenerate index.md using "Index Regeneration Pattern"
   - Exclude tombstoned memories from active listings
3. Regenerate .memory/10-Memories/README.md
   - Exclude tombstoned memories from the listing
```

#### Distill Log Entry

Log each merge operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "merge",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "post_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "affected_memories": [
    {
      "primary": "{primary.id}",
      "secondary": "{secondary.id}",
      "overlap_score": 0.75,
      "keywords_before": [5, 4],
      "keywords_after": 7,
      "keyword_superset_verified": true,
      "action": "merged"
    }
  ],
  "notes": "Merged {N} pair(s) across {M} cluster(s)"
}
```

The `keywords_before` array contains `[primary_keyword_count, secondary_keyword_count]`. The `keywords_after` value is the merged keyword count. The `keyword_superset_verified` boolean confirms the superset guarantee held for this pair.

### Sub-Mode: compress

Reduce oversized memories to key points while preserving essential information. The compress operation identifies memories with high size penalty, presents them interactively, generates compressed versions, preserves originals in a History section, and ensures keyword preservation.

#### Edge Case Checks

Before candidate identification, validate:

```
1. Run validate-on-read to ensure memory-index.json is consistent
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If no non-tombstoned memories:
   Display: "No memories in vault to compress."
   Return early.
```

#### Compress Candidate Identification

After scoring all memories via the Scoring Engine, select compress candidates:

```
compress_candidates = []
for each memory in scored_memories:
  if memory.status == "tombstoned":
    skip  # Already tombstoned
  if memory.size_penalty > 0.5:  # token_count > 900
    compress_candidates.append(memory)

Sort by size_penalty descending (largest memories first)
```

**Edge Case**: If `compress_candidates` is empty, display:
```
No compress candidates found. All memories are within size limits (token_count <= 900).
```
Then exit the compress sub-mode without further action.

#### Dry-Run Behavior

When `--dry-run` is active, show candidates with estimates without writing any files:

```
## Compress Candidates (Dry Run)

| Memory | Tokens | Size Penalty | Topic | Est. Compressed |
|--------|--------|-------------|-------|-----------------|
| {id} | {token_count} | {size_penalty:.2f} | {topic} | ~{token_count * 0.4} |

{count} compress candidate(s) found.
Run /distill --compress without --dry-run to execute.
```

Return early after display. No files are modified.

#### Interactive Selection -- MANDATORY STOP

**YOU MUST call AskUserQuestion here. Do NOT compress any memories without explicit user selection.**

Present candidates via AskUserQuestion multiSelect:

```json
{
  "question": "Select memories to compress. Original content will be preserved in a History section.",
  "header": "Compress Candidates ({count} found)",
  "multiSelect": true,
  "options": [
    {
      "label": "{memory.id}",
      "description": "Tokens: {token_count} | Size penalty: {size_penalty:.2f} | Topic: {topic} | Retrievals: {retrieval_count}"
    }
  ]
}
```

If the user selects no memories, display:
```
No memories selected for compression. Operation cancelled.
```
Then exit without changes.

#### Compression Execution

For each selected memory, compress following these steps:

```
1. Read the full memory file (.memory/10-Memories/MEM-{slug}.md)
2. Parse frontmatter and content sections
3. Extract original keywords from frontmatter

4. Generate compressed content:
   - Extract key points as bullet list
   - Preserve code blocks and examples verbatim
   - Remove redundant prose, verbose explanations, and filler
   - Target ~60% reduction (soft guideline, not enforced)
   - Maintain the core information and actionable details

5. Move original content to History section:
   - Insert before ## Connections section (if present), or at end of file
   - Use heading: ## History > ### Pre-Compression ({today})
   - Include full original content (between title heading and ## Connections)

6. Write compressed content as main body (between title heading and ## History)

7. Update frontmatter:
   - Recalculate token_count: word_count * 1.3, rounded down
   - Update modified to today (ISO date)
   - Preserve all other frontmatter fields unchanged

8. Keyword preservation check:
   original_keywords = set(memory.keywords)
   compressed_keywords = extract_keywords(compressed_content)
   missing = original_keywords - keywords_in_compressed_content

   If missing keywords found:
     - Add missing keywords explicitly to the compressed content
       (append "**Keywords**: {missing_keywords}" line if needed)
     - Log: "Keyword preservation: added {N} missing keywords to compressed content"

9. Write the updated memory file
```

#### Compressed Content Template

```markdown
---
{preserved frontmatter with updated token_count and modified}
---

# {title}

{compressed content - key points as bullet list, preserved code blocks}

## History

### Pre-Compression ({today})

{original content that was between title heading and ## Connections}

## Connections
{preserved connections section}
```

#### Batch Index Regeneration

After ALL compressions in the batch are complete (not after each individual compression):

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
   - Updated token_count values will be reflected
2. Regenerate index.md using "Index Regeneration Pattern"
3. Regenerate .memory/10-Memories/README.md
```

#### Compress Log Entry

Log the compress operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "compress",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "post_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "affected_memories": [
    {
      "id": "{memory.id}",
      "tokens_before": N,
      "tokens_after": N,
      "compression_ratio": 0.42,
      "keywords_preserved": true,
      "action": "compressed"
    }
  ],
  "notes": "Compressed {N} memories. Total tokens saved: {tokens_saved}"
}
```

The `compression_ratio` is `tokens_after / tokens_before` (lower means more compression). The `keywords_preserved` boolean confirms all original keywords are present in the compressed content.

Update the distill-log.json `summary.total_compressed` counter by incrementing it by the number of compressed memories.

### Sub-Mode: refine

Improve memory metadata quality through two tiers of fixes. Tier 1 fixes are safe automatic corrections that require no user interaction. Tier 2 fixes are interactive improvements that require user confirmation via AskUserQuestion.

#### Edge Case Checks

Before candidate scanning, validate:

```
1. Run validate-on-read to ensure memory-index.json is consistent
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If no non-tombstoned memories:
   Display: "No memories in vault to refine."
   Return early.
```

#### Quality Issue Scanning

Iterate all non-tombstoned memories and scan for quality issues:

```
tier1_fixes = []   # Automatic, no confirmation needed
tier2_fixes = []   # Interactive, require AskUserQuestion

for each memory in non_tombstoned_memories:
  # Read full memory file for content analysis

  # --- Tier 1: Automatic Fixes ---

  # 1. Keyword deduplication
  if memory.keywords has duplicates (case-insensitive):
    tier1_fixes.append({
      "memory": memory.id,
      "fix": "keyword_dedup",
      "description": "Remove duplicate keywords (case-insensitive, keep first occurrence)",
      "before": memory.keywords,
      "after": deduplicated_keywords
    })

  # 2. Summary generation
  if memory.summary is empty or missing:
    generated_summary = first_line_of_content[:100]  # Truncate to ~100 chars
    tier1_fixes.append({
      "memory": memory.id,
      "fix": "summary_gen",
      "description": "Generate summary from first line of content",
      "before": "",
      "after": generated_summary
    })

  # 3. Topic normalization
  if memory.topic has uppercase letters OR missing "/" separators OR trailing slashes:
    normalized_topic = memory.topic.lower().strip("/")
    tier1_fixes.append({
      "memory": memory.id,
      "fix": "topic_normalize",
      "description": "Normalize topic path (lowercase, clean separators)",
      "before": memory.topic,
      "after": normalized_topic
    })

  # --- Tier 2: Interactive Fixes ---

  # 4. Keyword enrichment
  if len(memory.keywords) < 4:
    suggested_keywords = extract_keywords_from_content(memory.content, 5)
    new_keywords = [k for k in suggested_keywords if k not in memory.keywords]
    if new_keywords:
      tier2_fixes.append({
        "memory": memory.id,
        "fix": "keyword_enrich",
        "description": "Add suggested keywords based on content analysis",
        "current_keywords": memory.keywords,
        "suggested_additions": new_keywords[:5]
      })

  # 5. Category reclassification
  content_category = infer_category_from_content(memory.content)
  if content_category != memory.category:
    tier2_fixes.append({
      "memory": memory.id,
      "fix": "category_reclassify",
      "description": "Category may not match content",
      "current_category": memory.category,
      "suggested_category": content_category
    })

  # 6. Topic path correction
  cluster_topics = get_topic_patterns_from_cluster(memory.topic)
  if memory.topic not consistent with cluster_topics:
    tier2_fixes.append({
      "memory": memory.id,
      "fix": "topic_correct",
      "description": "Topic path inconsistent with cluster patterns",
      "current_topic": memory.topic,
      "suggested_topic": corrected_topic
    })
```

#### "No Issues Found" Early Return

If both `tier1_fixes` and `tier2_fixes` are empty:
```
No quality issues found. All memories have clean metadata.
```
Then exit without further action.

#### Tier 1 Execution (Automatic)

Tier 1 fixes run without user interaction:

```
1. Display summary of Tier 1 fixes to be applied:
   ## Tier 1 Automatic Fixes

   | Memory | Fix | Description |
   |--------|-----|-------------|
   | {id} | keyword_dedup | Removed {N} duplicate keywords |
   | {id} | summary_gen | Generated summary from content |
   | {id} | topic_normalize | Normalized topic path |

2. Apply each fix:
   - keyword_dedup: Rewrite keywords array in frontmatter (case-insensitive dedup, keep first)
   - summary_gen: Add/update summary field in frontmatter
   - topic_normalize: Update topic field in frontmatter

3. Update modified date to today for each affected memory
```

#### Tier 2 Interactive Selection -- MANDATORY STOP

**YOU MUST call AskUserQuestion here if Tier 2 fixes exist. Do NOT apply Tier 2 fixes without explicit user selection.**

If `tier2_fixes` is not empty, present via AskUserQuestion multiSelect:

```json
{
  "question": "Select quality improvements to apply (Tier 2 - interactive fixes):",
  "header": "Refine Candidates ({count} issues found)",
  "multiSelect": true,
  "options": [
    {
      "label": "{memory.id}: {fix_type}",
      "description": "{description} | Current: {current_value} | Suggested: {suggested_value}"
    }
  ]
}
```

If the user selects no fixes, display:
```
No Tier 2 fixes selected. Only Tier 1 automatic fixes were applied.
```

#### Tier 2 Execution

For each selected Tier 2 fix:

```
- keyword_enrich: Append suggested keywords to frontmatter keywords array
- category_reclassify: Update first tag in frontmatter tags array
- topic_correct: Update topic field in frontmatter

Update modified date to today for each affected memory.
```

#### Batch Index Regeneration

After ALL fixes (Tier 1 and Tier 2) are complete:

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
2. Regenerate index.md using "Index Regeneration Pattern"
3. Regenerate .memory/10-Memories/README.md
```

#### Refine Log Entry

Log the refine operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "refine",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "post_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "affected_memories": [
    {
      "id": "{memory.id}",
      "fixes_applied": ["keyword_dedup", "summary_gen"],
      "action": "refined"
    }
  ],
  "notes": "Refined {N} memories. Tier 1: {T1_count} fixes, Tier 2: {T2_count} fixes"
}
```

Update the distill-log.json `summary.total_refined` counter by incrementing it by the number of refined memories.

### Sub-Mode: auto

Automated non-interactive maintenance that runs only safe Tier 1 refine fixes. The auto mode is designed for routine maintenance without human oversight -- it explicitly excludes compress (requires AI-generated summaries that need review), purge, and merge.

#### Auto Execution Flow

```
1. Run validate-on-read:
   - Check memory-index.json consistency with filesystem
   - Regenerate if stale

2. Run Tier 1 refine fixes ONLY (no AskUserQuestion calls):
   - Keyword deduplication: remove duplicate keywords (case-insensitive, keep first)
   - Summary generation: for memories with empty/missing summary, generate from first line of content (~100 chars)
   - Topic normalization: lowercase all topic paths, ensure "/" separators, no trailing slashes

3. For each fix applied:
   - Update the memory file frontmatter
   - Update modified date to today

4. Rebuild memory-index.json from filesystem state:
   - Use "JSON Index Maintenance" procedure
   - Regenerate index.md and .memory/10-Memories/README.md

5. Update memory_health in state.json:
   - Recalculate health_score
   - Update last_distilled timestamp
   - Increment distill_count

6. Skip ALL interactive operations:
   - No AskUserQuestion calls
   - No Tier 2 refine fixes
   - No compress operations
   - No purge operations
   - No merge operations
```

#### Explicitly Excluded Operations

| Operation | Reason for Exclusion |
|-----------|---------------------|
| Compress | AI-generated summaries require human review |
| Purge | Tombstoning decisions need user judgment |
| Merge | Content combination needs user oversight |
| Tier 2 Refine | Interactive fixes require user selection |

#### Change Summary Display

After auto mode completes, display a summary of changes:

```
## Auto Distill Complete

| Fix Type | Count | Details |
|----------|-------|---------|
| Keyword dedup | {N} | Removed duplicates in {N} memories |
| Summary gen | {N} | Generated summaries for {N} memories |
| Topic normalize | {N} | Normalized topics in {N} memories |

**Total fixes**: {total_count} across {memory_count} memories
**Health score**: {score}/100 ({status})
```

#### "No Changes Needed" Edge Case

If no Tier 1 fixes are applicable:
```
Auto distill: No changes needed. All memories have clean metadata.
Health score: {score}/100 ({status})
```

#### Auto Log Entry

Log the auto operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "refine",
  "session_id": "sess_...",
  "pre_metrics": { ... },
  "post_metrics": { ... },
  "affected_memories": [
    {
      "id": "{memory.id}",
      "fixes_applied": ["keyword_dedup"],
      "action": "refined"
    }
  ],
  "notes": "auto mode - Tier 1 fixes only. Applied {N} fixes to {M} memories"
}
```

Note: Auto mode uses `type: "refine"` (not a separate type) with `"notes"` containing `"auto mode"` to distinguish from interactive refine operations.

### Distill Log Schema

Operations are logged to `.memory/distill-log.json` for tracking maintenance history.

#### Schema

```json
{
  "version": "1.0.0",
  "operations": [
    {
      "id": "distill_{timestamp}",
      "timestamp": "ISO8601",
      "type": "report|purge|merge|compress|refine|gc",
      "session_id": "sess_...",
      "pre_metrics": {
        "total_memories": 0,
        "total_tokens": 0,
        "health_score": 100,
        "purge_candidates": 0,
        "merge_candidates": 0,
        "compress_candidates": 0
      },
      "post_metrics": {
        "total_memories": 0,
        "total_tokens": 0,
        "health_score": 100,
        "purge_candidates": 0,
        "merge_candidates": 0,
        "compress_candidates": 0
      },
      "affected_memories": [],
      "notes": ""
    }
  ],
  "summary": {
    "total_operations": 0,
    "total_purged": 0,
    "total_merged": 0,
    "total_compressed": 0,
    "total_refined": 0,
    "total_gc_deleted": 0,
    "last_operation": null
  }
}
```

#### Operation Types

| Type | Description | Task |
|------|-------------|------|
| `report` | Health report generated (read-only) | 449 |
| `purge` | Memories removed via tombstone pattern | 450 |
| `merge` | Duplicate memories combined | 451 |
| `compress` | Oversized memories summarized | 452 |
| `refine` | Memory quality improved | 452 |
| `gc` | Hard-delete tombstoned memories past grace period | 450 |

For `report` operations, `pre_metrics` and `post_metrics` are identical (no changes made).

### State Integration

After each distill operation, update `memory_health` in `specs/state.json`:

```json
{
  "memory_health": {
    "last_distilled": "ISO8601 timestamp",
    "distill_count": 1,
    "total_memories": 5,
    "never_retrieved": 2,
    "health_score": 85,
    "status": "healthy"
  }
}
```

The `memory_health` field is a top-level sibling of `repository_health` in state.json. Update it after every distill operation (including report-only operations).

**Field update rules by sub-mode**:

| Field | report | purge/merge/compress/refine/gc/auto |
|-------|--------|-------------------------------------|
| `last_distilled` | Updated | Updated |
| `distill_count` | NOT incremented | Incremented |
| `total_memories` | Updated | Updated |
| `never_retrieved` | Updated | Updated |
| `health_score` | Updated | Updated |
| `status` | Updated | Updated |

**Rationale**: The `report` sub-mode is read-only -- it generates a health report without modifying any memory files. Since `distill_count` tracks the number of maintenance operations that actually changed the vault, report-only invocations should not increment it. The `last_distilled` timestamp is still updated for all sub-modes because it tracks when the vault was last assessed, not when it was last modified.

### Purge Sub-Mode

The purge sub-mode identifies stale or zero-retrieval memories, presents candidates interactively, and applies a tombstone pattern (frontmatter mutation) rather than deleting files.

#### Purge Candidate Identification

After scoring all memories via the Scoring Engine, select purge candidates using an OR condition:

```
purge_candidates = []
for each memory in scored_memories:
  if memory.status == "tombstoned":
    skip  # Already tombstoned
  if memory.zero_retrieval_penalty == 1.0 OR memory.staleness_score > 0.8:
    purge_candidates.append(memory)
```

**Edge Case**: If `purge_candidates` is empty, display:
```
No purge candidates found. All memories are healthy or already tombstoned.
```
Then exit the purge sub-mode without further action.

#### Category-Aware TTL Advisory Thresholds

Category TTL thresholds affect **ranking only**, not automatic selection. Memories past their category TTL are sorted to the top of the candidate list.

| Category | TTL (days) | Description |
|----------|-----------|-------------|
| CONFIG | 180 | Configuration knowledge becomes stale fastest |
| WORKFLOW | 365 | Processes evolve but have longer relevance |
| PATTERN | 540 | Design patterns remain relevant longest |
| TECHNIQUE | 270 | Methods need periodic refresh |
| INSIGHT | none | Insights have no TTL (never auto-prioritized) |

#### TTL-Based Ranking

Sort purge candidates for presentation:

```
for each candidate in purge_candidates:
  category = candidate.category
  ttl = TTL_THRESHOLDS[category]  # from table above
  days_since_created = days_between(today, candidate.created)

  if ttl is not None AND days_since_created > ttl:
    candidate.past_ttl = true
    candidate.ttl_excess_days = days_since_created - ttl
  else:
    candidate.past_ttl = false
    candidate.ttl_excess_days = 0

# Sort: past-TTL memories first (by excess days descending), then by composite score descending
purge_candidates.sort(key=lambda c: (-int(c.past_ttl), -c.ttl_excess_days, -c.composite_score))
```

#### Interactive Selection -- MANDATORY STOP

**YOU MUST call AskUserQuestion here. Do NOT tombstone any memories without explicit user selection.**

Present candidates via AskUserQuestion multiSelect:

```json
{
  "question": "Select memories to tombstone (purge). Tombstoned memories are excluded from retrieval but preserved on disk for 7 days before gc can hard-delete them.",
  "header": "Purge Candidates ({count} found)",
  "multiSelect": true,
  "options": [
    {
      "label": "{memory.id}",
      "description": "Score: {composite_score:.2f} | Created: {created} | Retrievals: {retrieval_count} | Tokens: {token_count} | Category: {category}{ttl_warning}"
    }
  ]
}
```

Where `{ttl_warning}` is:
- ` | PAST TTL by {ttl_excess_days}d` if `past_ttl == true`
- empty string if `past_ttl == false`

If the user selects no memories, display:
```
No memories selected for purge. Operation cancelled.
```
Then exit without changes.

#### Dry-Run Behavior

When `--dry-run` is active, show the candidate list and scores but skip tombstone application:

```
[DRY RUN] Would tombstone {count} memories:
  - {memory.id} (score: {composite_score:.2f}, category: {category})
  - ...

No changes made.
```

Exit after displaying the dry-run summary.

#### Tombstone Application

For each selected memory, apply the tombstone by mutating its YAML frontmatter:

```
1. Read the memory file (.memory/10-Memories/MEM-{slug}.md)
2. Parse YAML frontmatter (between --- delimiters)
3. Add three fields after the `summary` field (before `token_count` if present):
   status: tombstoned
   tombstoned_at: {ISO8601 date, e.g., 2026-04-16}
   tombstone_reason: "purge"
4. Write the updated file back to disk
5. Update memory-index.json: set the entry's `status` to "tombstoned"
```

**Frontmatter Example (before)**:
```yaml
---
title: "HTTP request retry patterns"
created: 2026-01-15
tags: [PATTERN]
topic: "python/libs/requests"
source: "user input"
modified: 2026-01-15
summary: "HTTP retry with exponential backoff"
retrieval_count: 0
last_retrieved:
---
```

**Frontmatter Example (after)**:
```yaml
---
title: "HTTP request retry patterns"
created: 2026-01-15
tags: [PATTERN]
topic: "python/libs/requests"
source: "user input"
modified: 2026-01-15
summary: "HTTP retry with exponential backoff"
status: tombstoned
tombstoned_at: 2026-04-16
tombstone_reason: "purge"
retrieval_count: 0
last_retrieved:
---
```

#### Purge Log Entry

After tombstoning, log the operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "purge",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": 10,
    "total_tokens": 5000,
    "health_score": 65,
    "purge_candidates": 4,
    "merge_candidates": 2,
    "compress_candidates": 1
  },
  "post_metrics": {
    "total_memories": 10,
    "total_tokens": 5000,
    "health_score": 78,
    "purge_candidates": 1,
    "merge_candidates": 2,
    "compress_candidates": 1
  },
  "affected_memories": ["MEM-slug-1", "MEM-slug-2", "MEM-slug-3"],
  "notes": "Tombstoned 3 memories. Link-scan warnings: [list or 'none']"
}
```

**Key semantics**: `total_memories` and `total_tokens` remain unchanged in post_metrics because tombstoning preserves files on disk. `purge_candidates` decreases because tombstoned memories are excluded from future scoring. `health_score` improves as maintenance candidates are addressed.

Update the distill-log.json `summary.total_purged` counter by incrementing it by the number of tombstoned memories.

### Link-Scan Procedure

After tombstone application, scan for stale `[[MEM-{slug}]]` references in non-tombstoned memories.

#### Link-Scan Execution

```bash
# For each tombstoned memory slug
for slug in "${affected_slugs[@]}"; do
  # Search non-tombstoned memories for references
  grep -l "\[\[MEM-${slug}\]\]" .memory/10-Memories/MEM-*.md 2>/dev/null | while read ref_file; do
    # Check if the referencing file is itself tombstoned
    ref_status=$(grep -m1 "^status:" "$ref_file" | sed 's/^status: *//')
    if [ "$ref_status" == "tombstoned" ]; then
      continue  # Skip tombstoned files
    fi
    echo "WARNING: ${ref_file} references tombstoned [[MEM-${slug}]]"
  done
done
```

#### Warning Display

Display link-scan warnings to the user (no automatic modification):

```
## Link-Scan Warnings

The following active memories reference tombstoned memories:
- .memory/10-Memories/MEM-http-patterns.md -> [[MEM-requests-retry-patterns]] (tombstoned)
- .memory/10-Memories/MEM-library-setup.md -> [[MEM-requests-retry-patterns]] (tombstoned)

These references will become stale. Consider manually updating the Connections section
in the above files to remove or replace the references.
```

If no stale references are found:
```
Link-scan: No stale references found.
```

#### Link-Scan in Log

Include link-scan warnings in the purge operation's `notes` field in distill-log.json:

```
"notes": "Tombstoned 3 memories. Link-scan warnings: MEM-http-patterns.md->MEM-slug-1, MEM-library-setup.md->MEM-slug-1"
```

Or if none:
```
"notes": "Tombstoned 3 memories. Link-scan warnings: none"
```

### Retrieval Exclusion

Tombstoned memories must be excluded from all retrieval paths.

#### MCP Search Path Exclusion

After MCP search returns results, post-filter to exclude tombstoned entries:

```
For each segment in content_map.segments:
  query = segment.key_terms.join(" ")
  results = execute("search", {
    "query": query,
    "vault": ".memory",
    "limit": 5
  })

  # Post-filter: exclude tombstoned memories
  filtered_results = []
  for result in results:
    id = derive_id_from_result(result)
    index_entry = memory_index.entries[id]
    if index_entry.status == "tombstoned":
      continue  # Skip tombstoned memory
    filtered_results.append(result)
  results = filtered_results
```

#### Grep Fallback Path Exclusion

When using grep-based search, check frontmatter status before including in results:

```bash
# For each segment
for keyword in $key_terms; do
  grep -l -i "$keyword" .memory/10-Memories/*.md 2>/dev/null
done | sort | uniq -c | sort -rn | head -10 | while read count file; do
  # Check if memory is tombstoned
  status=$(grep -m1 "^status:" "$file" | sed 's/^status: *//')
  if [ "$status" == "tombstoned" ]; then
    continue  # Skip tombstoned memory
  fi
  echo "$count $file"
done | head -5
```

#### Scoring Engine Exclusion

In the scoring engine, skip tombstoned memories before computing scores:

```
for each entry in memory_index.entries:
  if entry.status == "tombstoned":
    skip  # Do not score tombstoned memories
  # Proceed with scoring...
```

This ensures tombstoned memories do not appear in:
- Purge candidates (already addressed)
- Merge candidates
- Compress candidates
- Health report statistics (except in a dedicated "Tombstoned Memories" section)

### Health Report -- Tombstoned Memories Section

Add a "Tombstoned Memories" section to the health report template, placed after the "Maintenance Candidates" section:

```
---

### Tombstoned Memories

| Memory | Tombstoned Date | Reason | Days Until GC |
|--------|----------------|--------|---------------|
| {memory.id} | {tombstoned_at} | {tombstone_reason} | {7 - days_since_tombstoned} |
| ... | ... | ... | ... |

**Total tombstoned**: {tombstoned_count}
**Eligible for GC**: {gc_eligible_count} (past 7-day grace period)
```

If no tombstoned memories exist:
```
### Tombstoned Memories

None.
```

### GC Sub-Mode

The gc sub-mode performs hard deletion of tombstoned memories that have passed the 7-day grace period.

#### Grace Period Scan

Identify tombstoned memories eligible for garbage collection:

```
gc_candidates = []
for each entry in memory_index.entries:
  if entry.status == "tombstoned":
    tombstoned_at = parse_date(entry.tombstoned_at or read from frontmatter)
    days_since_tombstoned = days_between(today, tombstoned_at)
    if days_since_tombstoned >= 7:
      gc_candidates.append(entry)
```

**Edge Case**: If no tombstoned memories are past the grace period, display:
```
No tombstoned memories past the 7-day grace period.
{tombstoned_count} tombstoned memories are still within the grace period.
```
Then exit without further action.

#### GC Interactive Selection -- MANDATORY STOP

**YOU MUST call AskUserQuestion here. Do NOT delete any memories without explicit user confirmation.**

Present eligible memories via AskUserQuestion multiSelect:

```json
{
  "question": "Select tombstoned memories to permanently delete. This action cannot be undone.",
  "header": "GC Candidates ({count} past 7-day grace period)",
  "multiSelect": true,
  "options": [
    {
      "label": "{memory.id}",
      "description": "Tombstoned: {tombstoned_at} | Reason: {tombstone_reason} | Original score: {composite_score:.2f} | Tokens: {token_count}"
    }
  ]
}
```

If the user selects no memories, display:
```
No memories selected for deletion. GC cancelled.
```
Then exit without changes.

#### Dry-Run Behavior

When `--dry-run` is active, show eligible memories without deleting:

```
[DRY RUN] Would permanently delete {count} memories:
  - {memory.id} (tombstoned: {tombstoned_at}, reason: {tombstone_reason})
  - ...

No changes made.
```

#### GC Deletion Sequence

For each selected memory, perform hard deletion in this order:

```
1. Delete the .md file:
   rm .memory/10-Memories/MEM-{slug}.md

2. Remove the entry from memory-index.json:
   - Filter out the entry with matching id
   - Decrement entry_count
   - Subtract the entry's token_count from total_tokens
   - Write updated memory-index.json

3. Regenerate index.md:
   - Use the Index Regeneration Pattern (existing procedure)
   - Tombstoned+deleted entries will be absent from filesystem scan

4. Regenerate .memory/10-Memories/README.md:
   - Use the existing README regeneration procedure
   - Deleted files will be absent from the ls scan

5. Update memory_health in specs/state.json:
   - Decrement total_memories by the number of deleted memories
   - Recalculate health_score after removal
```

#### GC Log Entry

Log the gc operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "gc",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": 10,
    "total_tokens": 5000,
    "health_score": 78,
    "purge_candidates": 1,
    "merge_candidates": 2,
    "compress_candidates": 1
  },
  "post_metrics": {
    "total_memories": 7,
    "total_tokens": 3500,
    "health_score": 85,
    "purge_candidates": 1,
    "merge_candidates": 1,
    "compress_candidates": 1
  },
  "affected_memories": ["MEM-slug-1", "MEM-slug-2", "MEM-slug-3"],
  "notes": "Hard-deleted 3 tombstoned memories"
}
```

**Key semantics**: `total_memories` and `total_tokens` are decremented in post_metrics because gc removes files from disk. `health_score` is recalculated after deletion.
