# Research Report: Review .opencode/ Agent System for <leader>ao Picker Improvements

- **Task**: OC_155 - Review .opencode/ agent system for <leader>ao picker improvements
- **Started**: 2026-03-06T19:15:00Z
- **Completed**: 2026-03-06T20:30:00Z
- **Effort**: 2 hours
- **Priority**: High
- **Dependencies**: None
- **Sources/Inputs**: 
  - .opencode/ directory structure (641 files, 573 markdown files)
  - lua/neotex/plugins/ai/opencode/commands/picker.lua
  - lua/neotex/plugins/ai/claude/commands/picker/init.lua
  - lua/neotex/plugins/ai/claude/commands/parser.lua
  - lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua
  - lua/neotex/plugins/ai/shared/picker/config.lua
  - lua/neotex/plugins/editor/which-key.lua
  - specs/TODO.md (recent tasks OC_151-154)
  - .opencode/skills/ (15 skills)
  - .opencode/commands/ (14 commands)
  - .opencode/context/index.md
- **Artifacts**: This report
- **Standards**: status-markers.md, report-format.md, artifact-management.md

## Executive Summary

- The <leader>ao picker is a Telescope-based interface that provides comprehensive access to the OpenCode agent system through a unified UI
- **Current Coverage**: Commands (14), Skills (15), Agents (8 subagents), Extensions (dynamic), Docs, Scripts, Tests, Hooks (not used by OpenCode), Root Files, and Lib
- **Recent Changes (OC_151-154)**: Renamed /remember to /learn, fixed git commit attribution, resolved skill-implementer postflight execution issues, and identified architectural inconsistencies in /task command
- **Key Gaps Identified**: 
  1. Context files (90+ in .opencode/context/) are NOT surfaced in the picker
  2. Memory system (.opencode/memory/) has no picker integration
  3. Rules (.opencode/rules/) are not accessible via picker
  4. No visibility into recent task status or progress
  5. Missing integration with specs/ directory for active task overview
- **Critical Finding**: The picker uses a thin facade pattern that delegates to Claude's picker implementation, which may cause drift as .opencode/ evolves independently

## Context & Scope

### What is the <leader>ao Picker?

The `<leader>ao` keymap (defined in which-key.lua:261) triggers the `OpencodeCommands` user command, which opens a Telescope picker interface for browsing and interacting with the OpenCode agent system artifacts.

**Architecture**:
```
<leader>ao → :OpencodeCommands → opencode.lua:59-61 → commands/picker.lua → 
claude/commands/picker/init.lua (shared implementation)
```

### Directory Structure Analyzed

```
.opencode/
├── commands/          (14 command definitions)
│   ├── fix.md, learn.md, implement.md, plan.md
│   ├── research.md, review.md, task.md, todo.md
│   └── errors.md, meta.md, refresh.md, revise.md
├── skills/            (15 skill definitions)
│   ├── skill-fix, skill-learn, skill-implementer
│   ├── skill-orchestrator, skill-planner, skill-researcher
│   ├── skill-neovim-implementation, skill-neovim-research
│   ├── skill-git-workflow, skill-status-sync
│   ├── skill-meta, skill-refresh, skill-task, skill-todo
├── agent/
│   ├── orchestrator.md
│   └── subagents/     (8 agent definitions)
│       ├── general-implementation-agent.md
│       ├── general-research-agent.md
│       ├── meta-builder-agent.md
│       ├── neovim-implementation-agent.md
│       ├── neovim-research-agent.md
│       ├── planner-agent.md
│       ├── code-reviewer-agent.md
│       └── README.md
├── context/           (90+ context files - NOT in picker)
│   ├── core/          (orchestration, patterns, formats, standards)
│   ├── docs/          (guides, examples)
│   └── project/       (language-specific contexts)
├── memory/            (memory system - NOT in picker)
├── docs/              (covered via docs/README.md only)
├── scripts/           (covered)
├── hooks/             (OpenCode doesn't use - correctly excluded)
├── extensions/        (dynamic - covered)
├── rules/             (6 rule files - NOT in picker)
└── templates/         (covered)
```

## Findings

### What the Picker Currently Does Well

1. **Comprehensive Command Coverage**: All 14 slash commands are parsed from frontmatter and displayed hierarchically
2. **Skill Visibility**: All 15 skills are scanned from skill-*/SKILL.md files with metadata
3. **Agent Discovery**: 8 subagents in agent/subagents/ are properly indexed
4. **Extension Management**: Dynamic loading/unloading of extensions with status indicators
5. **Dual-Mode Support**: Both local project and global ~/.config/nvim sources are merged with priority
6. **Action Integration**: Rich keyboard shortcuts (Ctrl+E edit, Ctrl+L load locally, Ctrl+U update from global, etc.)
7. **Visual Distinction**: Local vs global artifacts marked with asterisk (*)

### Current Picker Sections (from entries.lua)

Based on `create_picker_entries()` in entries.lua:733-811:

| Section | Coverage | Status |
|---------|----------|--------|
| Commands | 14 files in .opencode/commands/ | Complete |
| Skills | 15 directories in .opencode/skills/ | Complete |
| Agents | 8 files in .opencode/agent/subagents/ | Complete |
| Extensions | Dynamic from extensions module | Complete |
| Docs | Only docs/README.md (not full docs/) | Partial |
| Scripts | .opencode/scripts/*.sh | Complete |
| Tests | .opencode/tests/test_*.sh | Complete |
| Hooks | Excluded (hooks_subdir = nil in config) | Correct |
| Root Files | README.md, settings.json, .gitignore, OPENCODE.md | Complete |
| Lib | .opencode/lib/*.sh | Complete |
| Templates | .opencode/templates/*.yaml | Complete |

### Major Gaps and Missing Coverage

#### 1. Context Files Not Surfaced (HIGH PRIORITY)

**Issue**: The .opencode/context/ directory contains 90+ files that define the system's behavior, but none are accessible via the picker.

**Impact**: Users cannot discover or navigate context files that agents use for workflows.

**Affected Files**:
- `.opencode/context/core/orchestration/` - State management, routing
- `.opencode/context/core/patterns/` - Anti-stop patterns, skill lifecycle
- `.opencode/context/core/formats/` - Report, plan, summary formats
- `.opencode/context/core/standards/` - Status markers, tasks, documentation
- `.opencode/context/docs/guides/` - Creating commands, skills, agents
- `.opencode/context/project/*/` - Language-specific contexts (lean4, neovim, etc.)

**Evidence**: context/index.md shows 704 lines of context documentation, but parser.lua has no `scan_context_directory()` function.

#### 2. Memory System Not Integrated (MEDIUM PRIORITY)

**Issue**: The /learn command creates memories in .opencode/memory/, but these are not browseable via the picker.

**Structure**:
```
.opencode/memory/
├── 10-Memories/       (Actual memory files MEM-YYYY-MM-DD-NNN.md)
├── 20-Indices/        (index.md with links)
└── 30-Templates/      (memory-template.md)
```

**Impact**: Users cannot review, search, or navigate stored knowledge.

**Evidence**: skill-learn/SKILL.md shows the memory system but entries.lua has no `create_memory_entries()` function.

#### 3. Rules Directory Not Exposed (MEDIUM PRIORITY)

**Issue**: .opencode/rules/ contains 6 critical rule files but no picker access.

**Files**:
- git-workflow.md
- state-management.md
- error-handling.md
- neovim-lua.md
- workflows.md
- artifact-formats.md

**Impact**: Users cannot reference workflow rules without manually browsing filesystem.

#### 4. No Task Status Visibility (HIGH PRIORITY)

**Issue**: The picker shows commands, skills, agents but provides no view into:
- Active tasks from specs/TODO.md
- Task status from specs/state.json
- Recent task artifacts (research, plans, summaries)

**Evidence**: OC_154 research showed agents struggle with task creation because they can't see existing task context easily.

**Recent Task History**:
- OC_151: Completed - Renamed /remember to /learn
- OC_152: Completed - Fixed git commit co-author attribution
- OC_153: Completed - Fixed skill-implementer postflight execution
- OC_154: Completed - Identified /task command architectural issues

#### 5. Architectural Coupling Risk (MEDIUM PRIORITY)

**Issue**: The OpenCode picker is a thin facade that delegates to Claude's picker implementation.

**Code Evidence**:
```lua
-- opencode/commands/picker.lua:8
local internal = require("neotex.plugins.ai.claude.commands.picker.init")
```

**Risk**: As .opencode/ evolves with unique features (context-heavy, skill-based), the shared implementation may not support OpenCode-specific needs.

**Specific Differences**:
| Feature | Claude | OpenCode |
|---------|--------|----------|
| Hooks | Yes (.claude/hooks/) | No (hooks_subdir = nil) |
| Agents | Simple agent.md files | Complex subagents/ with frontmatter |
| Context | Minimal | Extensive (90+ files) |
| Skills | Basic | Thin wrapper pattern with context injection |
| Commands | Direct execution | Skill delegation pattern |

### Recent Changes Analysis (OC_151-154)

#### OC_151: Rename /remember to /learn
- **Files Changed**: skill-remember/ → skill-learn/, commands/learn.md
- **Picker Impact**: Skill name updated in display
- **Status**: Picker correctly shows skill-learn

#### OC_152: Git Commit Co-Author Attribution
- **Files Changed**: 14 files with co-author attribution
- **Picker Impact**: None
- **Note**: No picker integration needed

#### OC_153: Skill-Implementer Postflight Not Executing
- **Root Cause**: Skill tool only loads definitions, doesn't execute workflows
- **Fix**: Commands must implement preflight/postflight themselves
- **Picker Impact**: Skills now show execution pattern notes in picker
- **Status**: Picker displays correctly, execution fixed in commands

#### OC_154: /task Command Fails to Create Entries
- **Root Cause**: /task is direct execution (no skill delegation) while other commands use skill pattern
- **Architectural Issue**: Agents interpret problem descriptions as requests to solve
- **Fix Created**: skill-task/SKILL.md - thin wrapper for task creation
- **Picker Impact**: 
  - skill-task now appears in picker
  - Task creation should be more reliable
  - But picker still doesn't show task status/progress

## Decisions

1. **Keep Shared Picker Implementation**: The thin facade pattern is working and reduces code duplication
2. **Add Context Section to Picker**: Create new section for browsing context files
3. **Add Memory Section**: Integrate .opencode/memory/ into picker
4. **Add Rules Section**: Expose .opencode/rules/ via picker
5. **Add Tasks Overview**: Show active tasks from specs/state.json
6. **Maintain Claude/OpenCode Separation**: Different subdirectories handled via config

## Recommendations

### Priority 1: Context Files Integration

**Add Context Section to Picker**

Create `entries.create_context_entries()` similar to existing sections:

```lua
-- New function in entries.lua
function M.create_context_entries(structure, config)
  -- Scan .opencode/context/ recursively
  -- Group by category (core/, docs/, project/)
  -- Show file descriptions from frontmatter or first heading
end
```

**Rationale**: Context files are critical for understanding agent behavior. Making them discoverable improves system transparency.

**Estimated Effort**: 2-3 hours

### Priority 2: Memory System Integration

**Add Memory Section**

Create `entries.create_memory_entries()`:

```lua
function M.create_memory_entries(config)
  -- Scan .opencode/memory/10-Memories/
  -- Parse MEM-YYYY-MM-DD-NNN.md files
  -- Show title, date, classification tags
  -- Link to index.md for browsing
end
```

**Rationale**: Memories are user-curated knowledge. Browseable access enables knowledge reuse.

**Estimated Effort**: 2 hours

### Priority 3: Task Status Dashboard

**Add Tasks Section**

Create `entries.create_tasks_entries()`:

```lua
function M.create_tasks_entries(config)
  -- Read specs/state.json
  -- Show active projects with status
  -- Link to task directories
  -- Show recent artifacts
end
```

**Rationale**: Provides at-a-glance view of work in progress without leaving Neovim.

**Estimated Effort**: 3-4 hours

### Priority 4: Rules Directory

**Add Rules Section**

Create `entries.create_rules_entries()`:

```lua
function M.create_rules_entries(config)
  -- Scan .opencode/rules/*.md
  -- Show rule descriptions
  -- Quick access to workflow standards
end
```

**Estimated Effort**: 1 hour

### Priority 5: Enhanced Docs Coverage

**Expand Docs Section**

Currently only shows docs/README.md. Expand to:
- docs/guides/*.md
- docs/architecture/*.md
- docs/examples/*.md

**Rationale**: Full documentation coverage improves discoverability.

**Estimated Effort**: 1-2 hours

### Priority 6: Picker Configuration Persistence

**Add User Preferences**

Allow users to:
- Toggle section visibility
- Set default filters
- Remember last selection
- Custom keybindings per section

**Rationale**: Power users may want streamlined views.

**Estimated Effort**: 4-6 hours

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Context files are too numerous | Picker becomes unwieldy | Group by subdirectory, add search/filter |
| Performance with 90+ context files | Slow picker load | Lazy load on section expand, cache structure |
| Memory files grow large | Picker bloat | Pagination, date-based filtering |
| Breaking changes to shared picker | Both systems affected | Maintain backward compatibility, version config |
| User confusion with many sections | Information overload | Collapsible sections, user preferences |
| Task status staleness | Outdated info shown | Auto-refresh on picker open, manual refresh key |

## Appendix

### File References

**Picker Implementation**:
- `lua/neotex/plugins/ai/opencode.lua:59-61` - User command registration
- `lua/neotex/plugins/ai/opencode/commands/picker.lua:8-17` - Facade delegation
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua:22-281` - Main picker logic
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua:728-811` - Entry creation
- `lua/neotex/plugins/ai/claude/commands/parser.lua:470-567` - Skill scanning
- `lua/neotex/plugins/ai/shared/picker/config.lua:72-89` - OpenCode config

**Keymaps**:
- `lua/neotex/plugins/editor/which-key.lua:261-267` - <leader>ao mapping

**Recent Tasks**:
- `specs/TODO.md:9-127` - Tasks OC_151-156
- `specs/OC_151_rename_remember_command_to_learn/` - Completed
- `specs/OC_152_fix_git_commit_co_author_attribution/` - Completed
- `specs/OC_153_fix_skill_implementer_postflight_not_executing/` - Completed
- `specs/OC_154_task_command_fails_to_create_entries_not_specs_directory_issue/` - Completed

**Skills**:
- `.opencode/skills/skill-task/SKILL.md:1-195` - New task skill
- `.opencode/skills/skill-learn/SKILL.md:1-326` - Memory skill
- `.opencode/skills/skill-orchestrator/SKILL.md:1-53` - Routing skill

**System Documentation**:
- `.opencode/README.md:1-280` - System overview
- `.opencode/context/index.md:1-704` - Context index

### Metrics

- Total .opencode/ files: 641
- Markdown files: 573
- Commands: 14
- Skills: 15
- Subagents: 8
- Context files: 90+
- Rules: 6
- Memory entries: Variable

### Test Recommendations

When implementing picker enhancements:

1. **Test with empty directories** - Ensure picker handles missing sections gracefully
2. **Test with 100+ context files** - Verify performance remains acceptable
3. **Test dual-mode** - Verify local vs global artifact merging
4. **Test keyboard shortcuts** - All existing shortcuts must continue working
5. **Test extension loading** - Extensions should still be toggleable

---

**End of Report**
