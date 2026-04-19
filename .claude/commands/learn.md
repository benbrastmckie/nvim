---
description: Add memories from text, files, directories, or task artifacts with content mapping and deduplication
---

# Command: /learn

**Purpose**: Takes text, file paths, directory paths, or task references and creates memories through content mapping, MCP-based deduplication, and three memory operations (UPDATE, EXTEND, CREATE).
**Layer**: 2 (Command File - Argument Parsing Agent)
**Delegates To**: skill-memory (direct execution)

**Input**: $ARGUMENTS

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments with four-mode priority:

    **Mode Priority Chain** (first match wins):
    1. `--task N` -> Task mode
    2. Directory path (ends with `/`, starts with `-d `, or filesystem check passes) -> Directory mode
    3. File path (starts with `-f `, has file extension, or filesystem check passes) -> File mode
    4. Quoted text or remaining args -> Text mode

    **CRITICAL**: Check string patterns FIRST before any filesystem checks. A trailing `/`
    unambiguously signals directory mode regardless of whether you can verify the path exists.

    ```
    task_mode = "--task" in $ARGUMENTS
    task_number = extract_value("--task") if task_mode

    If not task_mode:
      input = remaining args joined with spaces

      # Priority 2: Directory - string check first, no bash needed
      if input ends with "/" OR input starts with "-d " OR [ -d "$input" ]; then
        mode = "directory"
        directory_path = strip leading "-d " flag from input if present

      # Priority 3: File - string check first
      elif input starts with "-f " OR [ -f "$input" ]; then
        mode = "file"
        file_path = strip leading "-f " flag from input if present

      # Priority 4: Text
      else
        mode = "text"
        text_content = "$input"
      fi
    ```
  </step_1>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Delegate to Memory Skill</action>
    <input>
      Task mode:
        - skill: "skill-memory"
        - args: "mode=task, task_number={task_number}"

      Directory mode:
        - skill: "skill-memory"
        - args: "mode=directory, directory_path={directory_path}"

      File mode:
        - skill: "skill-memory"
        - args: "mode=file, file_path={file_path}"

      Text mode:
        - skill: "skill-memory"
        - args: "mode=text, text_content={text_content}"
    </input>
    <expected_return>
      {
        "status": "completed",
        "mode": "task|directory|file|text",
        "content_map": { ... },  // Intermediate representation
        "operations": [
          {
            "type": "UPDATE|EXTEND|CREATE",
            "segment_id": "...",
            "memory_id": "MEM-...",
            "memory_path": "..."
          }
        ],
        "memories_affected": 3,
        "artifacts_reviewed": [...]  // task mode only
      }
    </expected_return>
  </step_1>

  <step_2>
    <action>Present Results</action>
    <process>
      Task mode:
        - Number of artifacts reviewed
        - Artifacts processed by classification
        - Memories created per category

      Directory mode:
        - Files scanned and selected
        - Content segments identified
        - Memory operations by type (UPDATE/EXTEND/CREATE)

      File mode:
        - Content segments extracted
        - Memory operations performed
        - Related memories found/updated

      Text mode:
        - Memory operations performed
        - Related memories found/updated

      All modes:
        - Display operation summary (N updates, N extensions, N creates)
        - Display Git commit info
        - Display next steps guidance
    </process>
  </step_2>
</workflow_execution>

---

## Task Mode

When invoked with `--task N`, /learn enters task mode for reviewing task artifacts:

### Workflow

1. **Parse Task Directory**: Locate specs/{NNN}_{SLUG}/ directory
2. **Scan Artifacts**: Find all files in subdirectories:
   - reports/ - Research reports
   - plans/ - Implementation plans
   - summaries/ - Completion summaries
   - code/ - Code artifacts
   - Any other artifact directories
3. **Present Artifact List**: Show numbered list of all found files
4. **Interactive Selection**: Let user select which artifacts to review
5. **Content Mapping**: For large artifacts (>500 tokens), segment into topic chunks
6. **Memory Search**: Find related memories via MCP search or grep fallback
7. **Classification**: Present 5-category taxonomy for each segment:
   - [TECHNIQUE] - Reusable method or approach
   - [PATTERN] - Design or implementation pattern
   - [CONFIG] - Configuration or setup knowledge
   - [WORKFLOW] - Process or procedure
   - [INSIGHT] - Key learning or understanding
   - [SKIP] - Not valuable for memory
8. **Memory Operations**: Execute UPDATE/EXTEND/CREATE based on overlap
9. **Update Index**: Link new memories in vault index (both category and topic)

### Example Usage

```bash
/learn --task 142                    # Review all artifacts from task 142
/learn --task 142 --category PATTERN # Focus on pattern extraction only
```

---

## Directory Mode

When invoked with a directory path, /learn enters directory mode:

### Workflow

1. **Recursive Scan**: Find all text files in directory tree
2. **Exclusion Patterns**: Skip .git/, node_modules/, __pycache__, .obsidian/, binary files
3. **Two-Tier Detection**: Extension whitelist first, then `file --mime-type` fallback
4. **Size Limits**: 100KB per file, warning at 50 files, hard limit at 200 files
5. **File Selection**: Present multiSelect with file sizes for user to choose
6. **Content Mapping**: Segment selected files into topic chunks
7. **Memory Search**: Find related memories for each segment
8. **Memory Operations**: Present UPDATE/EXTEND/CREATE recommendations
9. **Execute Operations**: Apply confirmed memory operations
10. **Update Index**: Add entries to both category and topic sections

### Example Usage

```bash
/learn ./src/utils/              # Scan utils directory for learnable content
/learn ~/notes/python/           # Import notes directory to memory vault
```

---

## File Mode

When invoked with a single file path, /learn enters file mode:

### Workflow

1. **Read File**: Load file content
2. **Content Mapping**: Segment into topic chunks at heading/paragraph boundaries
3. **Small-Input Bypass**: Files under 500 tokens become single segment
4. **Memory Search**: Find related memories via MCP or grep
5. **Present Options**: Show segments with overlap scores and recommendations
6. **Memory Operations**: Execute confirmed UPDATE/EXTEND/CREATE operations
7. **Update Index**: Link new/updated memories

### Example Usage

```bash
/learn /path/to/notes.md         # Add file content as memory
/learn ~/docs/patterns.txt       # Import from external file
```

---

## Text Mode

When invoked with text content, /learn enters text mode:

### Workflow

1. **Parse Input**: Extract text content from arguments
2. **Content Mapping**: For text >500 tokens, segment at paragraph boundaries
3. **Memory Search**: Find related memories via MCP or grep
4. **Present Options**: Show preview with overlap scores
5. **Memory Operations**: Execute confirmed UPDATE/EXTEND/CREATE
6. **Update Index**: Link new/updated memories

### Example Usage

```bash
/learn "Use pcall() in Lua for safe function calls"  # Add text as memory
/learn "Pattern: always use explicit returns in modules"
```

---

## Error Handling

<error_handling>
  <argument_errors>
    - No arguments provided -> "Usage: /learn <text|file|directory> OR /learn --task N"
    - Invalid file path (file mode) -> "File not found: {path}"
    - Invalid directory path (directory mode) -> "Directory not found: {path}"
    - Invalid task number (task mode) -> "Task not found: {N}"
    - Non-existent task directory -> "Task directory not found: specs/{NNN}_*"
  </argument_errors>

  <directory_errors>
    - Empty directory -> "No text files found in: {path}"
    - No text files after filtering -> "No supported text files found in: {path}"
    - Too many files (>200) -> "Too many files ({N}). Narrow your path or use file mode."
    - Warning at 50 files -> "Large directory ({N} files). Consider narrowing scope."
  </directory_errors>

  <execution_errors>
    - Skill failure -> Return error details
    - MCP unavailable -> Continue with grep-based search (graceful degradation)
    - No artifacts found in task -> "No artifacts found for task {N}"
  </execution_errors>

  <interactive_errors>
    - User cancels -> Exit gracefully, no files created
    - All artifacts/segments skipped -> "No memories created (all content skipped)"
  </interactive_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    - specs/{NNN}_*/ (task mode - artifact directories)
    - {directory_path}/**/* (directory mode - recursive scan)
    - {file_path} (file mode - single file)
    - .memory/30-Templates/memory-template.md
    - .memory/10-Memories/ (for ID generation, similarity search)
    - .memory/20-Indices/index.md (for topic hierarchy)
  </reads>

  <writes>
    - .memory/10-Memories/*.md (new/updated memory files)
    - .memory/20-Indices/index.md (updated links in category and topic sections)
  </writes>
</state_management>
