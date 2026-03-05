---
next_project_number: 148
---

# TODO

## Tasks

### OC_146. Research and implement subagent workflow best practices
- **Effort**: 6-8 hours
- **Status**: [RESEARCHED]
- **Language**: meta
- **Dependencies**: None

*Description**: Research and implement best practices for using subagents with isolated context windows and careful metadata passing in the .opencode/ agent system. Currently all research is conducted by the primary agent rather than being delegated to research subagents. Need to investigate 2026 best practices for:

1. **Isolated Context Windows**: How to properly delegate to subagents with clean, isolated context to prevent context pollution and reduce token usage
2. **Metadata Passing**: Careful passing of task metadata (task number, description, requirements) between primary agent and subagents
3. **Result Aggregation**: How subagents should return structured results that can be properly integrated back into the primary agent's workflow
4. **Error Handling**: Best practices for handling subagent failures and fallbacks
5. **Integration with Skills**: How subagent delegation should work within the existing skill-based architecture (skill-researcher, skill-implementer, skill-planner)

**Key Findings**:
- **System Architecture**: Three-layer delegation (Command → Skill → Agent) is working correctly
- **Isolated Context**: Uses `context: fork` mode with Task tool and `<context_injection>` blocks for clean, isolated context windows
- **Metadata Passing**: File-based metadata exchange via `.return-meta.json` files is reliable and avoids console pollution
- **Result Aggregation**: Skills use postflight pattern to read metadata, validate artifacts, update state, and commit changes
- **Error Handling**: Comprehensive patterns with early metadata creation, validation gates, timeout handling, and fallback chains
- **Gap Identified**: Primary agent currently performs research directly instead of delegating to research subagents - this is the core issue to address
- **Report**: [specs/OC_146_research_implement_subagent_workflow_best_practices/reports/research-001.md](specs/OC_146_research_implement_subagent_workflow_best_practices/reports/research-001.md)

---

### OC_143. Fix skill-researcher TODO.md linking regression
- **Effort**: medium
- **Status**: [PENDING]
- **Language**: meta
- **Dependencies**: OC_144 (part of systemic fix, but can be done separately)

**Description**: Fix the specific regression in skill-researcher where research reports are not being linked in TODO.md. Root cause is missing `metadata_file_path` parameter in the delegation prompt to general-research-agent. When the agent completes research, it doesn't know where to write the return metadata file, so postflight cannot extract artifact information to update TODO.md with the Research link.

**Changes Required**:
- Update skill-researcher Stage 3 delegation prompt to include metadata_file_path
- Add fallback logic in postflight for when metadata file is missing
- Update general-research-agent documentation to validate metadata_file_path
- May need to audit TODO.md and manually fix any missing Research links from past tasks

**Files to Modify**:
- .opencode/skills/skill-researcher/SKILL.md
- .opencode/agent/subagents/general-research-agent.md

---

### OC_142. Implement knowledge capture system
- **Effort**: large
- **Status**: [RESEARCHED]
- **Language**: meta
- **Dependencies**: OC_143, OC_144 (need working metadata delegation first)

**Description**: Implement a comprehensive knowledge capture system with three integrated features that were lost when reverting. This system enables capturing, classifying, and organizing knowledge from completed tasks and codebase scans.

**Phase 1: Rename /learn to /fix (1-2 hours)**
- Rename command from `/learn` to `/fix` for clarity
- Rename skill from `skill-learn` to `skill-fix`
- Update all documentation references (8+ files)
- Update command description and user guides

**Phase 2: Add task mode to /remember (3-4 hours)**
- Add mode detection to /remember command (task mode vs content mode)
- Implement task artifact collection from specs/OC_N_{name}/ directories
- Create knowledge classification algorithm (context vs memory vs project intelligence)
- Build interactive checkbox picker for routing knowledge to appropriate destinations
- Update skill-remember to handle both modes
- Create templates for context/, memory/, and project-intelligence/ entries

**Phase 3: Enhance /todo with auto features (2-3 hours)**
- Add automatic CHANGE_LOG.md updates when archiving tasks
- Extract completion_summary from state.json for changelog entries
- Add memory suggestions picker using interactive checkbox pattern
- Create classification logic for determining what knowledge to suggest
- Integrate with skill-remember for memory creation

**Phase 4: Documentation and templates (1-2 hours)**
- Create knowledge capture documentation explaining the three commands
- Create templates for context/, memory/, PI file formats
- Document decision framework: when to use context vs memory vs PI
- Update user guide with examples

**Files to Create/Modify**:
- .opencode/commands/fix.md (rename from learn.md)
- .opencode/skills/skill-fix/SKILL.md (rename from skill-learn)
- .opencode/commands/remember.md (add task mode)
- .opencode/skills/skill-remember/SKILL.md (add task mode stages)
- .opencode/commands/todo.md (add changelog and memory features)
- .opencode/context/core/templates/context-pattern-template.md
- .opencode/docs/guides/user-guide.md (add knowledge capture section)
- Multiple README and guide updates

---


### OC_140. Document progressive disclosure patterns in context-loading guide
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: OC_137 (completed)
- **Research**: [research-001.md](OC_140_document_progressive_disclosure_patterns/reports/research-001.md) - Documentation needed for stage-progressive loading, conditional injection, discovery-layer pattern, context budgets, and troubleshooting
- **Plan**: [implementation-001.md](OC_141_fix_agent_delegation_system_failure/plans/implementation-001.md) - 7-phase systematic audit and fix of skill-to-agent delegation

**Description**: Follow-up to OC_137 Phase 8. Update context-loading-best-practices.md with progressive disclosure patterns: stage-progressive loading, conditional context injection, discovery-layer pattern, context budget guidelines (keep under 800 lines), and troubleshooting section for context injection verification.

**Required Documentation**:
1. Stage-Progressive Loading Pattern - tiered loading by stage
2. Conditional Context Injection - when to inject vs when to skip
3. Discovery-Layer Pattern - context awareness without bloat
4. Context Budget Guidelines - measurable limits (800 lines, <10% for routing)
5. Troubleshooting - verifying context loading, debugging injection failures

---

### OC_139. Implement stage-progressive loading demonstration in skill-planner
- **Effort**: 1.5 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: OC_137 (completed)
- **Research**: [research-001.md](OC_139_implement_stage_progressive_loading_demo/reports/research-001.md) - Initial POC for progressive context loading in skill-planner
  - [research-002.md](OC_139_implement_stage_progressive_loading_demo/reports/research-002.md) - **Systematic review**: Comprehensive audit of all 11 skills with 30-60% optimization opportunities and 2026 best practices alignment
- **Plan**: [implementation-001.md](OC_139_implement_stage_progressive_loading_demo/plans/implementation-001.md) - 3-phase implementation with 40-50% context reduction target

**Description**: Follow-up to OC_137 Phase 7. Implement stage-progressive context loading in skill-planner as proof-of-concept: load status-markers.md in Stage 1 (for preflight validation), defer plan-format.md and task-breakdown.md to Stage 3 (for plan creation). Expected ~40-50% reduction in initial context window usage.

**Systematic Review Findings** (from research-002.md):
- **Current**: 100% context loaded in Stage 1 across all skills
- **Opportunity**: Stage-progressive loading reduces initial context by 40-60%
- **Priority Skills**: skill-planner, skill-implementer, skill-meta (highest impact)
- **2026 Best Practices**: Checkpoint-based loading, context budget enforcement, conditional domain context

**Implementation**:
- Modify skill-planner/SKILL.md execution stages
- Stage 1: Load minimal context (status-markers only)
- Stage 2: Preflight validation
- Stage 3: Load format context (plan-format.md, task-breakdown.md)
- Stage 4: Delegate to planner-agent with full context

---

### OC_138. Fix plan metadata status synchronization
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](OC_138_fix_plan_metadata_status_synchronization/reports/research-001.md) - Root cause: synchronization protocol only updates state.json and TODO.md, missing plan file line 4 metadata status
- **Plan**: [implementation-001.md](OC_141_fix_agent_delegation_system_failure/plans/implementation-001.md) - 7-phase systematic audit and fix of skill-to-agent delegation

**Description**: Fix the three-way status synchronization gap identified during OC_136 implementation. When tasks complete, the plan file's line 4 status metadata (`- **Status**: [NOT STARTED]`) is not updated, while state.json and TODO.md are correctly synchronized. This creates confusion and has persisted through multiple previous fix attempts.

**Root Cause**: Plan files have TWO levels of status - plan-level (line 4) and phase-level (within phases). Current synchronization protocol (phase-synchronization.md) only addresses state.json, TODO.md, and phase-level statuses, completely missing the plan-level status on line 4.

**Required Changes**:
1. Update phase-synchronization.md protocol to include plan metadata status
2. Update skill-implementer/SKILL.md Stage 4 (Postflight) to update plan file line 4
3. Add verification step to ensure all three locations are synchronized

**Expected Outcome**: When a task completes, ALL three locations show completed status:
- state.json: `"status": "completed"` ✓
- TODO.md: `[COMPLETED]` ✓  
- Plan file line 4: `[COMPLETED]` ✓ (currently missing!)

---
### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](087_investigate_wezterm_terminal_directory_change/reports/research-001.md)

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Planning Started**: 2026-02-13
- **Planning Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](078_fix_himalaya_smtp_authentication_failure/reports/research-001.md)
- **Plan**: [implementation-001.md](078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md)

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: "Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted". The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.

### 72. Fix himalaya sidebar help showing leader keybindings that conflict with toggle selection
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Language**: neovim
- **Dependencies**: None

**Description**: Fix himalaya sidebar help display (shown via '?') incorrectly showing leader keybindings (`<leader>mA` - Switch account, `<leader>mf` - Change folder, `<leader>ms` - Sync folder) in the Folder Management section. These leader commands should not be accessible or defined in the sidebar since `<leader>` is `<Space>` which is used for toggle selections in that buffer.
