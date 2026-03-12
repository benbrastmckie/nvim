---
name: skill-memory
description: Memory vault management - create, search, classify, and index memories. Invoke for /learn command memory operations.
allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion
---

# Memory Skill (Direct Execution)

Direct execution skill for memory vault management. Handles memory creation, similarity search, classification, and index maintenance through content mapping, MCP-based deduplication, and three memory operations (UPDATE, EXTEND, CREATE).

**MANDATORY INTERACTIVE REQUIREMENT — DO NOT SKIP**:
- STOP at Step 4 and call AskUserQuestion to show files. Write NOTHING to disk until user responds.
- STOP at Memory Search and call AskUserQuestion for each segment. Write NOTHING to disk until user responds.
- These are not optional. Running autonomously without user input is a critical failure.

## Context References

Reference (do not load eagerly):
- Path: `@.memory/30-Templates/memory-template.md` - Memory template
- Path: `@.memory/20-Indices/index.md` - Memory index
- Path: `@.opencode/context/project/memory/learn-usage.md` - Usage guide

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
      "topic": "neovim/plugins/telescope",
      "source_file": "/path/to/file.md",
      "source_lines": "15-42",
      "summary": "Telescope custom picker creation pattern",
      "estimated_tokens": 350,
      "key_terms": ["telescope", "picker", "finders", "sorters", "attach_mappings"]
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

### Search Result Presentation — MANDATORY STOP

**YOU MUST call AskUserQuestion for EACH segment before writing anything. Do NOT infer what the user wants. Do NOT skip segments. Do NOT write memory files without explicit user confirmation per segment.**

Present each segment with related memories via AskUserQuestion:

```
Segment: {segment.summary}
Topic: {segment.topic}
Key terms: {segment.key_terms.join(", ")}

Related Memories:
1. MEM-2026-03-05-042 (72% overlap) -> Recommended: UPDATE
2. MEM-2026-03-04-038 (45% overlap) -> Recommended: EXTEND
3. MEM-2026-03-03-015 (18% overlap) -> Recommended: CREATE (no strong match)

What would you like to do with this segment?
[ ] UPDATE MEM-2026-03-05-042 (replace content)
[ ] EXTEND MEM-2026-03-04-038 (append section)
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
---

# {segment.summary}

{segment_content}

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
```

**Note**: The MEM- prefix is preserved for grep discoverability (`grep -r "MEM-" .memory/`). Filenames follow the pattern `MEM-{semantic-slug}.md` (e.g., `MEM-telescope-custom-pickers.md`).

### Topic Inference

Infer topic using four-source priority:

```
1. Source directory path (highest priority)
   - /project/src/utils/ -> "project/utils"
   - /home/user/notes/neovim/ -> "neovim"

2. Keyword analysis
   - Extract domain indicators: neovim, lua, telescope, lazy
   - Map to topic: "neovim/plugins" or "neovim/config"

3. Related memory topics
   - If UPDATE/EXTEND: inherit topic from target memory
   - If CREATE with high-overlap match: suggest that topic

4. User confirmation/override
   - Always present inferred topic for confirmation
   - User can modify or create new topic path
```

### Index Maintenance

After each operation, update both `index.md` and `.memory/10-Memories/README.md`:

**index.md**:
```
1. Add/update entry in "## By Category" under appropriate tag
2. Add/update entry in "## By Topic" under topic path
3. Update "## Recent Memories" (prepend, keep last 10)
4. Update "## Statistics" counts
```

**`.memory/10-Memories/README.md`** — regenerate the full file listing:
```
1. List all MEM-*.md files in the directory (ls .memory/10-Memories/MEM-*.md)
2. For each file, extract: id, title, topic, tags from frontmatter
3. Rewrite README.md with updated count and one entry per memory:
   ### [MEM-YYYY-MM-DD-NNN](MEM-YYYY-MM-DD-NNN.md)
   **Title**: {title}
   **Topic**: {topic}
   **Tags**: {tags}
4. Keep "## Navigation" section at the bottom
```

### Index Regeneration Pattern

To avoid concurrent write conflicts, regenerate index.md from filesystem state rather than append:

```bash
# 1. List all memory files
memories=$(ls .memory/10-Memories/MEM-*.md 2>/dev/null)

# 2. Extract metadata from each file
for mem in $memories; do
  id=$(grep -m1 "^id:" "$mem" | cut -d: -f2 | tr -d ' ')
  title=$(grep -m1 "^title:" "$mem" | cut -d'"' -f2)
  topic=$(grep -m1 "^topic:" "$mem" | cut -d'"' -f2)
  date=$(grep -m1 "^date:" "$mem" | cut -d: -f2 | tr -d ' ')
  # Store for index generation
done

# 3. Regenerate index.md from extracted data
# Sort by date descending, write complete file
```

Benefits:
- No append conflicts (complete overwrite)
- Self-healing (missing entries recovered)
- Idempotent (multiple regenerations produce same result)

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
| Neovim | .fnl, .janet, .nix |

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

### Step 4: File Selection (Paginated) — MANDATORY STOP

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

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```
