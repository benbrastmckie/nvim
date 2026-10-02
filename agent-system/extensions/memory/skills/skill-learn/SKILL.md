---
name: skill-learn
description: Memory creation - add memories from text, files, directories, or task artifacts, with content mapping and deduplication. Invoke for /learn command memory operations.
allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion
---

# Learn Skill (Direct Execution)

Direct execution skill for memory creation. Handles memory creation, similarity search, classification, and index maintenance through content mapping, MCP-based deduplication, and three memory operations (UPDATE, EXTEND, CREATE). This skill owns memory *creation* only; vault analysis and maintenance (scoring, health reporting, purge/merge/compress/refine/gc, and the telemetry-sourced sub-modes) live in the sibling `skill-distill` skill.

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

### Exact-Key Dedup for Reserved Namespaces

The reserved topic namespace `email/preferences/*` (see
`.claude/extensions/email/context/project/email/design/email-to-memory-preferences.md`) is a
**sanctioned, explicitly documented deviation** from the fuzzy Classification Thresholds below.
For a segment/candidate whose `topic` matches `email/preferences/*`, an **exact `topic ==` match**
against `.memory/memory-index.json` short-circuits classification straight to UPDATE/EXTEND
(disambiguated by the namespace-scoped tally-arithmetic variant two sections below) WITHOUT ever
computing keyword overlap:

```bash
jq --arg k "email/preferences/${ACCOUNT}/${KEY}" \
  '.entries[] | select(.topic == $k)' .memory/memory-index.json
```

Rationale: for this namespace the identity key (sender/domain normalization, computed
deterministically by `.claude/scripts/email-preference-harvest.sh`) is already a verified,
deterministic identity — re-deriving it via fuzzy keyword overlap would be strictly *fuzzier*
than the key itself. A miss (no exact match) falls through to CREATE by default; the ordinary
fuzzy path below still runs afterward as a **near-miss suggestion only** (e.g. flagging
`email/preferences/gmail/mail.foo.com` as a near-miss of an existing
`email/preferences/gmail/foo.com` entry) — presented to the human at gate time, never
auto-applied. This exact-key short-circuit applies ONLY to the reserved `email/preferences/*`
namespace; all other topics continue to use the Classification Thresholds below unchanged.

### Classification Thresholds

| Overlap Score | Classification | Action |
|---------------|----------------|--------|
| >60% | HIGH | UPDATE - Replace memory content |
| 30-60% | MEDIUM | EXTEND - Append new section |
| <30% | LOW | CREATE - New memory |

### Namespace-Scoped Tally-Arithmetic UPDATE/EXTEND (`email/preferences/*` only)

Distinct from the generic wholesale UPDATE/EXTEND templates elsewhere in this skill (which
replace/append full memory *content*), the reserved `email/preferences/*` namespace's
UPDATE/EXTEND operations mutate a small structured **tally block** in the memory body instead:

- **EXTEND** (this round's dominant confirmed action matches the memory's stored dominant
  action): append a dated `## History` line (`- {date}: +{action} (n={n_this_round},
  scope={inbox|archive})`) and bump the matching action's counter and `last_seen`. Existing
  content is never rewritten.
- **UPDATE** (this round's dominant action contradicts the stored dominant action): increment
  the *opposite* counter (never overwrite/reset the matching one — the contradicting action's
  own count and `last_seen` are what change), which can flip the *derived* dominant action per
  the tie-break rule below; move the prior summary line to `## History` marked `(superseded)`.

Both operations reuse the exact same tally arithmetic (`.claude/scripts/email-preference-harvest.sh
tally-op`) — the EXTEND/UPDATE distinction is purely about which body sections get touched
(History append vs. superseded-summary move), not about a different counter-update rule.

**Dominant action** is always *derived*, never a stored scalar:
`dominant = argmax(delete_count, archive_count, keep_count)`, ties broken by whichever action has
the more recent per-action `last_seen` (`.claude/scripts/email-preference-harvest.sh dominant`).

**Memory body template** (§3.5 of the design; schema fields map 1:1 to what these operations
read/write):

```markdown
---
title: "Email preference: {domain-or-hash-key}"
created: {today}
tags: [email, preference, {domain}]
topic: "email/preferences/{account}/{key}"
source: "skill-email-cleanup harvest"
modified: {today}
keywords: [{domain}, email, preference]
summary: "Confirmed-decision tally for {domain-or-hash-key}: {dominant_action} ({dominant_count}/{total})"
retrieval_count: 0
last_retrieved:
category: preference
---

# Email preference: {domain-or-hash-key}

**Tally**: delete={delete_count} (last: {delete_last_seen}), archive={archive_count}
(last: {archive_last_seen}), keep={keep_count} (last: {keep_last_seen})
**Dominant action** (derived): {dominant_action}
**Evidence**: junked {delete_count + archive_count}, kept {keep_count}

## History

- {date}: +{action} (n={n_this_round}, scope={inbox|archive})

## Connections
<!-- Add links to related memories using [[MEM-filename]] syntax -->
```

**Archive-scope tally isolation**: archive-scope-sourced confirms (from `skill-email-cleanup
--archive`) are recorded in a distinct `### Archive-scope tally` sub-section within the SAME
memory (never a separate memory) — this preserves the "one evolving memory per sender/domain"
invariant while preventing a burst of old archive-triage confirms from silently dominating a
sender's current-inbox dominant action. The archive-scope sub-section carries its own
`{delete_count, archive_count, keep_count, last_seen}` tally, computed and derived identically to
the inbox-scope tally above, but never merged into it.

**Revocation/edit UX**: a user-invoked "forget this preference" action reuses the existing
tombstone pattern documented in the sibling `skill-distill/SKILL.md`'s Purge Sub-Mode
"Tombstone Application" subsection (`status: tombstoned`, `tombstoned_at`, `tombstone_reason`) —
set `tombstone_reason: "user_revoked"` for this case. This
is distinct from `/distill --purge` (automatic, staleness-driven) and is never automatic;
`skill-email-cleanup`'s Stage 7 wires the user-invoked trigger for it.

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
7. Write updated memory, then append its path to `touched_memory_paths` for the Git Commit
   stage's pathspec
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
6. Write updated memory, then append its path to `touched_memory_paths` for the Git Commit
   stage's pathspec
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
5. Write new memory file at `.memory/10-Memories/${filename}`, then append that path to
   `touched_memory_paths` for the Git Commit stage's pathspec
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
  # category: prefer an explicit frontmatter `category:` field when present (design §3.4 in
  # email-to-memory-preferences.md -- first real use of this field, e.g. `category: preference`
  # for email/preferences/* memories); fall back to the existing tags-derived heuristic when
  # absent. Non-breaking for any memory predating this field, none of which has a `category:`
  # field.
  category=$(grep -m1 "^category:" "$mem" | sed 's/^category: *//' | tr -d '"')
  if [ -z "$category" ]; then
    category=$(grep -m1 "^tags:" "$mem" | sed 's/^tags: *\[//' | cut -d, -f1 | tr -d '] ')
  fi
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
| `category` | string | Frontmatter `category:` field when present (e.g. `preference`), else first tag from frontmatter `tags` |
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

Also check for a completion-time reflection on the task's state.json entry, and present it as
an additional reviewable segment alongside the markdown artifacts (not written to disk -- it
comes from state.json, not the filesystem):

```bash
reflection=$(jq -c --argjson num "$task_num" \
  '.active_projects[] | select(.project_number == $num) | .reflection // null' \
  specs/state.json)

if [ "$reflection" != "null" ] && [ -n "$reflection" ]; then
  reflection_segment_available=true
fi
```

If `reflection_segment_available` is true, build a pseudo-artifact entry (`label`: "Reflection
(task ${task_number})", `description`: a short preview of `what_worked`/`successes`) and include
it in the Step 3 option list; its content is the reflection's four fields rather than file text.
When absent (`reflection == null`), behavior is unchanged -- only the file-based artifacts list
is presented.

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

When `reflection_segment_available` is true, append one additional option to the list above:
`{"label": "Reflection (task ${task_number})", "description": "Completion-time reflection: what
worked, what was hard, what was missed, successes"}`.

### Step 4: Process Through Content Mapping

For each selected artifact:
1. Read content (for the "Reflection" pseudo-artifact, this is the `reflection` object's four
   fields concatenated as text rather than file content)
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

After successful memory operations, stage the three indexes (always regenerated in full from
filesystem state, per Index Regeneration Pattern and JSON Index Maintenance above) plus every
individual memory file this run touched (`touched_memory_paths`, accumulated by each
UPDATE/EXTEND/CREATE operation above) — never a bare `.memory/` directory pathspec, which would
stage any OTHER concurrent session's uncommitted memory writes too:

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "memory: add/update ${memories_affected} memories" \
  --session "${session_id}" \
  -- .memory/10-Memories/README.md .memory/20-Indices/index.md .memory/memory-index.json \
     "${touched_memory_paths[@]}"
```

---

