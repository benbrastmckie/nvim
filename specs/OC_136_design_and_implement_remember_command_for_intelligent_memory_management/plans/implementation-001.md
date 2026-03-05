# Implementation Plan: Task #136

**Task**: OC_136 - Design and implement `/remember` command for intelligent memory management  
**Version**: 001  
**Created**: 2026-03-06  
**Language**: meta  

---

## Overview

This implementation plan creates a simple-but-effective memory management system using an Obsidian-compatible vault at `.opencode/memory/`. The approach leverages MCP (Model Context Protocol) servers for lookup and storage, avoiding complex custom indexing. The plan prioritizes getting basic functionality working quickly with a simple yes/no approval flow, flat file structure, and explicit --remember flag for memory-augmented research.

**Core Philosophy**: Start simple, get it working, then iterate. Phase 1 delivers minimal viable functionality; future phases can add advanced features.

---

## Phases

### Phase 1: Vault Structure and Configuration

**Status**: [NOT STARTED]  
**Estimated effort**: 1-2 hours  

**Objectives**:
1. Create `.opencode/memory/` vault directory structure
2. Set up basic Obsidian configuration files
3. Create directory structure (Inbox, Memories, Indices, Templates)
4. Create memory template and index files
5. Document MCP server setup instructions

**Files to Create**:
- `.opencode/memory/.obsidian/app.json` - Obsidian app configuration
- `.opencode/memory/.obsidian/appearance.json` - Theme settings
- `.opencode/memory/.obsidian/core-plugins.json` - Enabled plugins
- `.opencode/memory/00-Inbox/.gitkeep` - Inbox directory
- `.opencode/memory/10-Memories/.gitkeep` - Memories directory
- `.opencode/memory/20-Indices/index.md` - Master index with links
- `.opencode/memory/30-Templates/memory-template.md` - Template for new memories
- `.opencode/memory/README.md` - Vault documentation
- `.opencode/docs/memory-setup.md` - MCP server setup instructions

**Steps**:

1. **Create vault structure**
   ```bash
   mkdir -p .opencode/memory/{.obsidian/plugins,00-Inbox,10-Memories,20-Indices,30-Templates}
   ```

2. **Create Obsidian configuration**
   - Write app.json with default settings
   - Write appearance.json with Minimal theme preference
   - Write core-plugins.json enabling necessary plugins

3. **Create template file**
   ```markdown
   ---
   id: MEM-{{date}}-{{sequence}}
   title: "{{title}}"
   date: {{date}}
   tags: {{tags}}
   source: "{{source}}"
   ---
   
   # {{title}}
   
   {{content}}
   
   ## Connections
   <!-- Add links to related memories -->
   ```

4. **Create index.md**
   ```markdown
   # Memory Vault Index
   
   ## Quick Navigation
   - [Inbox](00-Inbox/) - Quick capture
   - [Memories](10-Memories/) - All memory entries
   - [Templates](30-Templates/) - Memory templates
   
   ## Recent Memories
   <!-- Auto-populated by /remember command -->
   
   ## By Topic
   <!-- Organized links to memory categories -->
   ```

5. **Create README.md**
   - Vault purpose and usage
   - MCP server setup instructions
   - Naming conventions
   - Git workflow (what to commit, what to ignore)

6. **Create setup documentation**
   - Step-by-step MCP server installation
   - Configuration examples
   - Testing instructions

**Verification**:
- [ ] Directory structure exists
- [ ] Obsidian can open `.opencode/memory/` as vault
- [ ] Template file is valid markdown with YAML frontmatter
- [ ] README explains vault organization
- [ ] Setup docs are clear and complete

---

### Phase 2: Basic /remember Command

**Status**: [NOT STARTED]  
**Estimated effort**: 2-3 hours  

**Objectives**:
1. Create `/remember` command specification
2. Implement input parsing (text vs file path)
3. Generate memory entries with auto-incrementing IDs
4. Simple yes/no interactive approval
5. Write approved memories to vault
6. Update index.md automatically

**Files to Create**:
- `.opencode/commands/remember.md` - Command specification
- `.opencode/skills/skill-remember/SKILL.md` - Direct execution skill

**Files to Modify**:
- `.opencode/memory/20-Indices/index.md` - Append new memory links

**Steps**:

1. **Create command specification** (`.opencode/commands/remember.md`)
   ```markdown
   ---
   description: Add a memory to the vault
   ---
   
   # Command: /remember
   
   ## Usage
   /remember "text to remember"
   /remember /path/to/file.md
   
   ## Steps
   
   ### 1. Parse Input
   - Check if argument is existing file path
   - If yes: read file content
   - If no: use argument as text content
   
   ### 2. Generate Memory ID
   - Format: MEM-YYYY-MM-DD-NNN
   - Date: current date
   - NNN: next available sequence number (scan 10-Memories/)
   
   ### 3. Extract Metadata
   - Title: First line (if text) or filename (if file)
   - Source: "user input" or file path
   - Date: Current date
   - Tags: Empty (Phase 1), auto-extract (Phase 2+)
   
   ### 4. Create Memory Entry
   - Load template from 30-Templates/memory-template.md
   - Fill placeholders: {{date}}, {{sequence}}, {{title}}, {{tags}}, {{source}}, {{content}}
   - Generate full markdown content
   
   ### 5. Interactive Confirmation
   - Show preview (truncated to 500 chars)
   - Show destination path
   - Ask: "Add this memory? (yes/no)"
   
   ### 6. Write to Vault
   If confirmed:
   - Write file to 10-Memories/MEM-YYYY-MM-DD-NNN-slug.md
   - Append link to 20-Indices/index.md
   - Commit changes with message: "memory: add MEM-XXX"
   
   ### 7. Report Success
   - Display: "Memory MEM-2026-03-06-001 added to vault"
   - Show file path
   ```

2. **Create skill implementation** (`.opencode/skills/skill-remember/SKILL.md`)
   ```yaml
   ---
   name: skill-remember
   description: Add a memory to the vault with simple yes/no approval
   allowed-tools: Task, Bash, Edit, Read, Write, Grep
   ---
   
   # Remember Skill
   
   Direct execution skill for adding memories to the vault.
   
   <context>
     <system_context>OpenCode memory management.</system_context>
     <task_context>Add text or file content as memory entry.</task_context>
   </context>
   
   <role>Direct execution skill for memory creation.</role>
   
   <task>Parse input, generate memory entry, confirm with user, write to vault.</task>
   
   <execution>
     <stage id="1" name="ParseInput">
       <action>Determine if input is file path or text</action>
       <action>Read file if path exists, otherwise use text directly</action>
     </stage>
     <stage id="2" name="GenerateID">
       <action>Scan 10-Memories/ for existing IDs</action>
       <action>Generate next sequence number for today</action>
     </stage>
     <stage id="3" name="CreateEntry">
       <action>Load template from 30-Templates/memory-template.md</action>
       <action>Fill template placeholders with metadata</action>
     </stage>
     <stage id="4" name="Confirm">
       <action>Show preview to user</action>
       <action>Ask yes/no confirmation</action>
     </stage>
     <stage id="5" name="Write">
       <action>Write memory file to 10-Memories/</action>
       <action>Update index.md with new link</action>
       <action>Commit changes</action>
     </stage>
     <stage id="6" name="Report">
       <action>Return success message with memory ID</action>
     </stage>
   </execution>
   ```

3. **Implement ID generation logic**
   - Scan `.opencode/memory/10-Memories/` for files matching `MEM-YYYY-MM-DD-*.md`
   - Extract sequence numbers for today's date
   - Generate next number (001, 002, etc.)
   - Format: `MEM-2026-03-06-001`

4. **Implement template processing**
   - Read template file
   - Replace placeholders:
     - `{{date}}` → current date
     - `{{sequence}}` → sequence number
     - `{{title}}` → extracted title
     - `{{tags}}` → empty or extracted tags
     - `{{source}}` → source description
     - `{{content}}` → full content

5. **Implement interactive confirmation**
   - Use AskUserQuestion with single choice: yes/no
   - Show preview (first 500 chars of content)
   - Show destination path

6. **Implement file writing**
   - Create filename: `MEM-YYYY-MM-DD-NNN-slugified-title.md`
   - Write to `.opencode/memory/10-Memories/`
   - Update `.opencode/memory/20-Indices/index.md`
   - Git commit

**Verification**:
- [ ] Can add text memory: `/remember "test content"`
- [ ] Can add file memory: `/remember /path/to/file.md`
- [ ] ID auto-increments correctly
- [ ] Interactive confirmation works
- [ ] File written to correct location
- [ ] Index.md updated with link
- [ ] Git commit created
- [ ] Success message shows memory ID

---

### Phase 3: MCP Server Integration and --remember Flag

**Status**: [NOT STARTED]  
**Estimated effort**: 2-3 hours  

**Objectives**:
1. Document MCP server setup (obsidian-cli-rest)
2. Implement memory search via MCP
3. Add --remember flag to /research command
4. Integrate memory results into research workflow
5. Test end-to-end flow

**Files to Create**:
- `.opencode/docs/mcp-setup.md` - Detailed MCP configuration

**Files to Modify**:
- `.opencode/commands/research.md` - Add --remember flag handling
- `.opencode/memory/.obsidian/plugins/obsidian-cli-rest/config.json` - MCP config template

**Steps**:

1. **Create MCP setup documentation** (`.opencode/docs/mcp-setup.md`)
   ```markdown
   # MCP Server Setup for Memory Vault
   
   ## Prerequisites
   - Obsidian desktop app installed
   - `.opencode/memory/` vault created
   
   ## Installation
   
   1. Open Obsidian
   2. Open `.opencode/memory/` as vault
   3. Settings > Community Plugins > Browse
   4. Search: "Obsidian CLI REST"
   5. Install and Enable
   6. Note the API key from plugin settings
   
   ## Configuration
   
   Add to your Claude Code MCP settings:
   
   ```json
   {
     "mcpServers": {
       "obsidian-memory": {
         "command": "npx",
         "args": ["-y", "@dsebastien/obsidian-cli-rest-mcp@latest"],
         "env": {
           "OBSIDIAN_API_KEY": "your-api-key-here",
           "OBSIDIAN_PORT": "27124"
         }
       }
     }
   }
   ```
   
   ## Testing
   
   Test the connection:
   ```bash
   curl -H "Authorization: Bearer YOUR_API_KEY" \
     http://127.0.0.1:27124/vault/
   ```
   
   ## Troubleshooting
   - Port conflicts: Change port in plugin settings
   - API key issues: Regenerate key in Obsidian
   - Connection refused: Ensure Obsidian is running
   ```

2. **Create MCP config template** (`.opencode/memory/.obsidian/plugins/obsidian-cli-rest/config.json`)
   ```json
   {
     "port": 27124,
     "host": "127.0.0.1",
     "authentication": {
       "type": "bearer"
     },
     "commands": {
       "enabled": ["*"]
     }
   }
   ```

3. **Modify /research command** (`.opencode/commands/research.md`)
   
   Add to Parse Input section:
   ```markdown
   ### Flag Detection
   
   Detect `--remember` flag in arguments:
   - Check if any argument equals "--remember"
   - Remove flag from arguments before processing
   - Set flag: `use_memory = true`
   ```
   
   Add Memory Search step:
   ```markdown
   ### Step 0: Memory Search (if --remember flag present)
   
   If `use_memory` is true:
   
   1. **Build search query**
      - Extract keywords from task description
      - Add focus prompt keywords if provided
      - Limit to 3-5 most significant terms
   
   2. **Query MCP server**
      ```json
      {
        "tool": "search_notes",
        "params": {
          "query": "extracted keywords",
          "limit": 5
        }
      }
      ```
   
   3. **Process results**
      - If results found: Read full content of top 3 memories
      - If no results: Note "No relevant memories found"
   
   4. **Include in research context**
      - Add "## Prior Knowledge from Memory Vault" section
      - Include memory summaries (truncated to 1000 chars each)
      - List memory IDs for reference
   
   5. **Mark as augmented**
      - Add metadata: "memory_augmented: true"
   ```

4. **Implement MCP search integration**
   - Use MCP tool call: `search_notes`
   - Parameters:
     - `query`: Extracted keywords from task
     - `limit`: 5 (configurable)
     - `folder`: "10-Memories" (optional filter)
   
5. **Implement memory content retrieval**
   - For each relevant result:
     - Use MCP tool: `read_note`
     - Extract frontmatter and content
     - Truncate to 1000 characters
     - Include in research report

6. **Test end-to-end flow**
   - Add test memory: `/remember "neovim lsp configuration best practices"`
   - Run research with flag: `/research OC_136 --remember`
   - Verify:
     - Memory search executed
     - Relevant memory found
     - Memory content included in research context
     - Research report references memory

**Verification**:
- [ ] MCP setup docs are clear and complete
- [ ] Config template is valid JSON
- [ ] --remember flag detected correctly
- [ ] Memory search executes when flag present
- [ ] Relevant memories retrieved via MCP
- [ ] Memory content included in research context
- [ ] Research report shows memory-augmented status
- [ ] Graceful handling if MCP unavailable
- [ ] Graceful handling if no memories found

---

### Phase 4: Integration Testing and Documentation

**Status**: [NOT STARTED]  
**Estimated effort**: 1-2 hours  

**Objectives**:
1. Test complete workflow end-to-end
2. Verify git integration works correctly
3. Document usage examples
4. Create troubleshooting guide
5. Update main README with memory system info

**Files to Create**:
- `.opencode/docs/remember-usage.md` - Usage examples and tips
- `.opencode/docs/memory-troubleshooting.md` - Common issues and solutions

**Files to Modify**:
- `.opencode/README.md` - Add memory system section

**Steps**:

1. **End-to-end testing**
   - Test 1: Add text memory, verify file created
   - Test 2: Add file memory, verify content preserved
   - Test 3: Run research with --remember, verify memory search
   - Test 4: Add multiple memories, verify index updates
   - Test 5: Git workflow - commit, push, verify

2. **Create usage documentation** (`.opencode/docs/remember-usage.md`)
   ```markdown
   # /remember Command Usage Guide
   
   ## Basic Usage
   
   ### Adding Text Memories
   ```
   /remember "Your text content here"
   ```
   
   ### Adding File Memories
   ```
   /remember /path/to/file.md
   ```
   
   ## Memory-Augmented Research
   
   ### Using --remember Flag
   ```
   /research OC_136 --remember
   /research OC_136 "focus prompt" --remember
   ```
   
   ## Best Practices
   - Use descriptive first lines for better titles
   - Review index.md regularly for navigation
   - Commit memories to git for version history
   
   ## Examples
   <show 3-5 real examples>
   ```

3. **Create troubleshooting guide** (`.opencode/docs/memory-troubleshooting.md`)
   ```markdown
   # Memory System Troubleshooting
   
   ## MCP Server Not Connecting
   - Check Obsidian is running
   - Verify API key in settings
   - Check port 27124 is available
   
   ## Memories Not Found in Research
   - Verify --remember flag used
   - Check memory has relevant keywords
   - Try different search terms
   
   ## Git Conflicts
   - Pull before adding memories
   - Resolve conflicts in index.md
   
   ## Obsidian Not Recognizing Vault
   - Ensure .obsidian/ directory exists
   - Check folder permissions
   ```

4. **Update main README** (`.opencode/README.md`)
   - Add "Memory System" section
   - Link to /remember command
   - Brief description of vault
   - Link to setup documentation

5. **Verify git integration**
   - Confirm .gitignore excludes .obsidian/
   - Test: Add memory, commit, push
   - Test: Clone repo, verify vault structure preserved
   - Test: Merge conflicts in index.md

**Verification**:
- [ ] All 5 end-to-end tests pass
- [ ] Usage docs have clear examples
- [ ] Troubleshooting covers common issues
- [ ] README updated with memory section
- [ ] Git workflow works correctly
- [ ] Documentation links work

---

## Dependencies

- **Obsidian Desktop**: Required for MCP server (free, available for all platforms)
- **obsidian-cli-rest plugin**: Community plugin (free)
- **Git**: For version control of memories
- **npx/npm**: For MCP server execution

**Optional**:
- **Obsidian Sync**: For mobile access (paid, optional)
- **Git sync**: Free alternative for mobile

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| MCP server not available | Medium | High | Graceful degradation - skip memory search, proceed with research |
| User doesn't have Obsidian | Low | High | Document that Obsidian is required for full features; direct file access still works |
| Vault grows too large | Low | Medium | Phase 1 doesn't auto-archive; user can manually organize; document best practices |
| Git conflicts in index.md | Medium | Low | Instructions for conflict resolution; index.md is simple list, easy to merge |
| Mobile access issues | Medium | Low | Document sync options; provide Git-based sync instructions |
| Performance degradation | Low | Medium | Monitor vault size; document when to consider Phase 2+ optimization |

---

## Success Criteria

- [ ] Vault structure created and functional
- [ ] `/remember` command adds memories with yes/no approval
- [ ] Memories stored as valid Markdown with YAML frontmatter
- [ ] `index.md` automatically updated with new memories
- [ ] `--remember` flag triggers memory search before research
- [ ] MCP server integration works for search and retrieval
- [ ] Documentation complete and clear
- [ ] Git workflow functional
- [ ] End-to-end tests pass

---

## Future Phases (Not in Scope for Phase 1)

These features are identified in research but intentionally excluded from Phase 1 to maintain simplicity:

### Phase 2: Enhanced Features (Future)
- Auto-tag extraction from content
- Content analysis for better metadata
- Duplicate detection
- Checkbox multi-select approval (instead of yes/no)

### Phase 3: Advanced Lookup (Future)
- Hybrid indexing (BM25 + vectors)
- Custom SQLite index for large vaults
- Semantic search
- Automatic relevance ranking

### Phase 4: Organization (Future)
- PARA method integration
- Automatic archiving
- Review date reminders
- Memory freshness scoring

### Phase 5: Integration (Future)
- Automatic research augmentation in /remember
- Memory suggestions based on context
- Cross-reference detection
- Graph visualization support

**Note**: The simplified Phase 1 approach uses MCP's built-in search instead of custom indexing. This is sufficient for vaults under 1,000 memories and avoids complexity. Transition to Phase 3+ approach if vault grows beyond that size or search performance becomes an issue.

---

## Implementation Notes

### Direct Execution Pattern

Following research-002.md findings, this implementation uses direct execution pattern (like skill-learn) rather than thin wrapper + agent delegation (which was reverted in OC_135). This means:

- Skills do NOT use `context: fork`
- Skills do NOT have `agent:` field
- All logic implemented directly in skill files
- No delegation to non-existent agents

### Git Workflow

```bash
# Adding a memory triggers:
1. Write memory file to 10-Memories/
2. Update index.md
3. Git add both files
4. Git commit -m "memory: add MEM-2026-03-06-001"

# User can then:
git push  # to sync with remote
```

**What to ignore**:
- `.opencode/memory/.obsidian/` - Obsidian config (user-specific)
- `.opencode/memory/*.sqlite` - Search indexes (rebuildable)

**What to commit**:
- All `.md` files in memory vault
- Templates and indices
- README and documentation

### MCP Tool Usage

Primary tools used from obsidian-cli-rest MCP server:

1. `search_notes` - Find relevant memories
2. `read_note` - Retrieve memory content
3. `write_note` - Create new memory (alternative to direct file write)
4. `list_notes` - Enumerate memories (for ID generation)

### Testing Checklist

Before marking Phase complete, verify:

**Phase 1**:
- [ ] Directory structure correct
- [ ] Obsidian opens vault without errors
- [ ] Template has all placeholders

**Phase 2**:
- [ ] Text input works
- [ ] File input works
- [ ] ID generation correct
- [ ] Confirmation prompt works
- [ ] File written correctly
- [ ] Index updated
- [ ] Commit created

**Phase 3**:
- [ ] MCP docs clear
- [ ] Config template valid
- [ ] --remember flag detected
- [ ] Search executes
- [ ] Results included in research

**Phase 4**:
- [ ] All tests pass
- [ ] Docs complete
- [ ] README updated
- [ ] Git workflow verified

---

## References

- **research-001.md**: General memory management patterns and best practices
- **research-002.md**: System state analysis post-OC_135 revert (direct execution pattern)
- **research-003.md**: Obsidian integration advantages, disadvantages, indexing best practices
- **research-004.md**: Simplified design specification (this plan's foundation)

---

## Next Steps

After plan approval, run `/implement OC_136` to begin Phase 1 implementation.

**Phase 1 can begin immediately** - no blockers or external dependencies required.
