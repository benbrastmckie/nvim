---
name: skill-remember
description: Add a memory to the vault with checkbox-based multi-select confirmation
allowed-tools: Bash, Edit, Read, Write, Grep, AskUserQuestion, Glob
---

# Remember Skill

Direct execution skill for adding memories to the vault using checkbox-based interactive confirmation.

<context>
  <system_context>OpenCode memory management with interactive multi-select.</system_context>
  <task_context>Add text, file content, or task artifacts as memory entry with user-guided actions.</task_context>
</context>

<role>Direct execution skill for memory creation with checkbox-based confirmation. Supports standard mode (text/file input) and task mode (artifact review with classification).</role>

<task>Parse input, generate memory entry, search for similar memories, present checkbox options, execute selected actions. In task mode, scan task artifacts and classify memories interactively.</task>

<execution>
  <stage id="1" name="ParseInput">
    <action>Determine mode and parse input</action>
    <process>
      1. Check if mode is "task" (--task OC_N provided)
      2. If task mode:
         - Extract task number
         - Validate task directory exists: specs/OC_{N}_*/
      3. If standard mode:
         - Check if input argument is an existing file path
         - If file exists: read file content, use filename as title base
         - If file doesn't exist: treat input as text content, use first line as title
    </process>
  </stage>
  
  <stage id="2" name="TaskModeScan" condition="mode == task">
    <action>Scan task directory for artifacts</action>
    <process>
      1. Locate task directory: specs/OC_{N}_*/
      2. Scan for artifact files in subdirectories:
         - reports/*.md - Research reports
         - plans/*.md - Implementation plans
         - summaries/*.md - Completion summaries
         - code/* - Code artifacts
         - Any other files in task directory
      3. Build artifact list with:
         - File path
         - File type (report/plan/summary/code/other)
         - File size (for chunking large files)
      4. If no artifacts found, return error
    </process>
  </stage>
  
  <stage id="3" name="TaskModeSelection" condition="mode == task">
    <action>Present artifacts for user selection</action>
    <process>
      1. Display artifact list with numbers:
         ```
         Artifacts found for Task OC_{N}:
         
         1. reports/research-001.md (Research Report)
         2. plans/implementation-003.md (Implementation Plan)
         3. summaries/implementation-summary-20260118.md (Summary)
         ```
      
      2. Use AskUserQuestion with multiSelect:
         ```json
         {
           "question": "Select artifacts to review for memory extraction:",
           "options": [
             {"label": "1. reports/research-001.md", "value": "reports/research-001.md"},
             {"label": "2. plans/implementation-003.md", "value": "plans/implementation-003.md"},
             {"label": "Select all", "value": "all"}
           ],
           "multiple": true
         }
         ```
      
      3. Store selected artifacts for review
    </process>
  </stage>
  
  <stage id="4" name="TaskModeReview" condition="mode == task">
    <action>Review selected artifacts and classify</action>
    <process>
      For each selected artifact:
      1. Read file content
      2. For large files (>5000 chars), show in chunks with navigation
      3. Display content preview:
         ```
         Reviewing: plans/implementation-003.md
         ─────────────────────────────────────────
         [File content preview - first 1000 chars]
         ...
         ─────────────────────────────────────────
         ```
      
      4. Present classification options with multiSelect:
         ```json
         {
           "question": "Classify this artifact for memory creation (Task OC_{N} - {filename}):",
           "options": [
             {"label": "[TECHNIQUE] - Reusable method or approach", "value": "TECHNIQUE"},
             {"label": "[PATTERN] - Design or implementation pattern", "value": "PATTERN"},
             {"label": "[CONFIG] - Configuration or setup knowledge", "value": "CONFIG"},
             {"label": "[WORKFLOW] - Process or procedure", "value": "WORKFLOW"},
             {"label": "[INSIGHT] - Key learning or understanding", "value": "INSIGHT"},
             {"label": "[SKIP] - Not valuable for memory", "value": "SKIP"}
           ],
           "multiple": false
         }
         ```
      
      5. Store classification per artifact
      6. If SKIP selected, skip to next artifact
    </process>
  </stage>
  
  <stage id="5" name="GenerateID">
    <action>Generate unique memory ID</action>
    <process>
      1. Scan .opencode/memory/10-Memories/ for existing MEM-YYYY-MM-DD-*.md files
      2. Extract sequence numbers for today's date
      3. Generate next number (001, 002, etc.)
      4. Format: MEM-YYYY-MM-DD-NNN (e.g., MEM-2026-03-06-001)
    </process>
  </stage>
  
  <stage id="6" name="CreateEntry">
    <action>Create memory entry from template</action>
    <process>
      1. Load template from .opencode/memory/30-Templates/memory-template.md
      2. Extract metadata:
         - Title: First line of text or filename
         - Date: Current date (YYYY-MM-DD)
         - Source: "user input", file path, or "Task OC_{N}"
         - Tags: Empty (for future auto-extraction)
         - Classification: Selected category (task mode only)
      3. Fill template placeholders:
         - {{date}} → current date
         - {{sequence}} → sequence number (001, 002, etc.)
         - {{title}} → extracted title
         - {{tags}} → empty or comma-separated tags
         - {{source}} → source description
         - {{content}} → full content
         - {{classification}} → category tag (task mode only)
      4. Generate markdown content
    </process>
  </stage>
  
  <stage id="7" name="FindSimilar">
    <action>Search for similar existing memories</action>
    <process>
      1. Extract keywords from title/content
      2. Search .opencode/memory/10-Memories/ for matching content
      3. If MCP server available, use search_notes tool for better results
      4. Extract top 3 similar memories with IDs and titles
      5. Store for display in confirmation dialog
    </process>
  </stage>
  
  <stage id="8" name="InteractiveConfirm">
    <action>Show preview and present checkbox options</action>
    <process>
      1. Display memory preview:
         ```
         Memory Preview:
         ─────────────────────────────────────────
         ID: MEM-2026-03-06-001
         Title: Neovim LSP Configuration Best Practices
         Source: user input
         Date: 2026-03-06
         Classification: [CONFIG] (task mode only)
         
         Content Preview (first 300 chars):
         When configuring LSP servers in Neovim, it's important to...
         ─────────────────────────────────────────
         
         Similar Memories Found:
         - MEM-2026-03-05-042: "LSP server setup guide"
         - MEM-2026-03-04-038: "Neovim configuration tips"
         ```
      
      2. Present checkbox options using AskUserQuestion with multiSelect:
         ```json
         {
           "question": "What would you like to do with this memory?",
           "options": [
             {"label": "Add as new memory", "value": "add_new"},
             {"label": "Update existing similar memory", "value": "update_existing"},
             {"label": "Edit content before saving", "value": "edit_content"},
             {"label": "Skip - don't save", "value": "skip"}
           ],
           "multiple": true
         }
         ```
      
      3. Handle user selections
    </process>
  </stage>
  
  <stage id="9" name="ExecuteActions">
    <action>Execute selected actions</action>
    <process>
      Based on user selections:
      
      **If "skip" selected (only option or with others)**:
      - Cancel operation for this memory
      - Return success with no actions taken
      
      **If "edit_content" selected**:
      - Open content in editable buffer
      - Allow user modifications
      - Use modified content for subsequent actions
      
      **If "add_new" selected**:
      - Generate filename: MEM-YYYY-MM-DD-NNN-slugified-title.md
      - Write to .opencode/memory/10-Memories/
      - Append link to .opencode/memory/20-Indices/index.md
      - Record "added" action
      
      **If "update_existing" selected**:
      - Display list of similar memories found in Stage 7
      - Let user select which memory to update
      - Read existing memory file
      - Append new content under "## Update History" section
      - Add timestamp: `### Update: YYYY-MM-DD HH:MM`
      - Record "updated" action
      
      **Handle multiple selections**:
      - Execute "edit_content" first (if selected)
      - Then execute "add_new" and/or "update_existing"
      - Support merge scenarios (add AND update in one flow)
    </process>
  </stage>
  
  <stage id="10" name="CommitAndReport">
    <action>Commit changes and report results</action>
    <process>
      1. Stage modified files with git add
      2. Create commit with descriptive message:
         - Single action: "memory: add MEM-2026-03-06-001"
         - Multiple actions: "memory: add MEM-2026-03-06-001, update MEM-2026-03-05-042"
         - Task mode: "memory: harvest from Task OC_{N} - {N} memories created"
      3. Generate success report:
         ```
         Memory Operations Completed:
         ✓ Added: MEM-2026-03-06-001 (.opencode/memory/10-Memories/...)
         ✓ Updated: MEM-2026-03-05-042 (appended new content)
         ✓ Index updated with 1 new link
         
         Git commit: <commit-hash>
         ```
      4. Return JSON with status, actions_taken, and memory IDs
    </process>
  </stage>
</execution>

<validation>Validate checkbox confirmation, file creation, index updates, and task mode classification.</validation>

<return_format>Return JSON: {"status": "completed", "mode": "task|standard", "memory_id": "...", "actions_taken": [...], "file_path": "...", "artifacts_reviewed": [...]}</return_format>

## Example Usage Flows

### Standard Mode
```
1. User: /remember "neovim lsp configuration best practices"
2. Skill: Generates ID, creates entry from template
3. Skill: Searches for similar memories
4. Skill: Shows preview + finds 2 similar memories
5. Skill: Displays checkbox:
   - [x] Add as new memory
   - [ ] Update existing similar memory
   - [ ] Edit content before saving
   - [ ] Skip - don't save
6. User selects: Add as new
7. Skill: Writes file to 10-Memories/
8. Skill: Updates index.md
9. Skill: Git commit
10. Skill: Returns success
```

### Task Mode
```
1. User: /remember --task 142
2. Skill: Scans specs/OC_142_*/ for artifacts
3. Skill: Finds: research-002.md, implementation-003.md, summary-001.md
4. Skill: Presents checkbox selection
5. User selects: All three artifacts
6. Skill: Reviews each artifact:
   - research-002.md → [INSIGHT]
   - implementation-003.md → [PATTERN]
   - summary-001.md → [WORKFLOW]
7. Skill: Creates 3 memories with classification tags
8. Skill: Updates index.md with all 3
9. Skill: Git commit: "memory: harvest from Task OC_142 - 3 memories"
10. Skill: Returns success with artifact list
```

## Error Handling

- **File not found**: Return error with guidance
- **Empty content**: Warn user, ask to confirm
- **MCP unavailable**: Continue with file-based search
- **User cancels**: Exit gracefully, no changes
- **Git errors**: Log warning, continue
- **Task not found**: Return error "Task directory not found"
- **No artifacts**: Return error "No artifacts found for task"

## Similar Memories Detection

Uses simple keyword matching on titles and content:
1. Extract words from title (3+ characters)
2. Count matches in existing memory files
3. Return top 3 with most matches
4. If MCP available, use search_notes for better results

## Classification Taxonomy (Task Mode)

| Category | Description | Example |
|----------|-------------|---------|
| TECHNIQUE | Reusable method or approach | "Three-phase debugging process" |
| PATTERN | Design or implementation pattern | "Agent delegation wrapper pattern" |
| CONFIG | Configuration or setup knowledge | "Neovim LSP keymap configuration" |
| WORKFLOW | Process or procedure | "Code review checklist workflow" |
| INSIGHT | Key learning or understanding | "Root cause of race condition" |
| SKIP | Not valuable for memory | N/A - skip this artifact |