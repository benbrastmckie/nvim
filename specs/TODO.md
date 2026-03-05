---
next_project_number: 148
---

# TODO

## Tasks

### OC_148. Fix status updates during implementation phases
- **Effort**: 3-4 hours
- **Status**: [RESEARCHED]
- **Researched**: 2026-03-05
- **Language**: meta
- **Dependencies**: None
- **Artifacts**:
  - [specs/OC_148_fix_status_updates_in_implementations/reports/research-001.md](specs/OC_148_fix_status_updates_in_implementations/reports/research-001.md) - Research report identifying 6 specific status update gaps in skill-implementer and general-implementation-agent with detailed recommendations and file references

**Description**: Fix status update gaps in skill-implementer and general-implementation-agent. During OC_147 implementation, observed that:

1. **Phase Status**: Phases are NOT marked [IN PROGRESS] before starting work (though they ARE marked [COMPLETED] after finishing - this part works)
2. **Task Status Transition**: Task status in TODO.md, state.json, and plan file was NOT updated to [IMPLEMENTING] before starting work
3. **Task Status Completion**: Task status was NOT updated to [COMPLETED] after finishing all phases

The skill-implementer SKILL.md has preflight that updates status to implementing, and the agent should mark phases as IN PROGRESS before starting each phase. Need to ensure:
- Each phase is marked [IN PROGRESS] at the start of execution
- Task status transitions to [IMPLEMENTING] when /implement begins
- Task status transitions to [COMPLETED] when all phases finish
- Plan file phase statuses stay synchronized with actual progress

**Key Findings**:
- **Gap 1**: skill-implementer preflight lacks explicit jq commands to update status to implementing
- **Gap 2**: skill-implementer postflight lacks detailed stages for status transitions (implementing -> completed/partial)
- **Gap 3**: Missing TODO.md status update instructions in skill-implementer
- **Gap 4**: implement.md command has duplicate status update description that may conflict with skill
- **Gap 5**: Phase verification exists but doesn't catch [NOT STARTED] phases during active work
- **Solution**: Add detailed preflight/postflight stages to skill-implementer matching skill-researcher pattern

---

### OC_147. Fix artifact metadata linking in TODO.md
- **Effort**: 4-6 hours
- **Status**: [RESEARCHED]
- **Language**: meta
- **Dependencies**: None

**Description**: Research reports created by subagents are not being properly linked in the artifacts section of tasks. Instead, the report metadata appears at the bottom of the task entry in TODO.md. Need to investigate:

1. **Root Cause**: Why artifacts aren't appearing in state.json artifacts array properly
2. **Metadata Passing**: Ensure `.return-meta.json` files are being created and read correctly
3. **TODO.md Format**: Verify artifact linking format matches expected pattern
4. **Skill Postflight**: Check if skill postflight stages are properly updating TODO.md
5. **Subagent Pattern**: Review all subagents that create artifacts to ensure consistent behavior

The goal is to ensure artifact metadata flows correctly from subagent → metadata file → state.json → TODO.md without requiring the primary agent to read artifacts directly.

**Key Findings**:
- **Root Cause**: Inconsistent skill postflight implementations - skill-researcher lacks detailed postflight patterns found in skill-implementer
- **Metadata Flow**: Core architecture working - agents create `.return-meta.json`, state.json IS populated
- **TODO.md Gap**: Artifact links appear inconsistently due to missing standardized postflight instructions
- **Solution**: Update skill-researcher and skill-planner with file-metadata-exchange.md and jq-escaping-workarounds.md patterns
- **Research**: [specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-001.md](specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-001.md)

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

### OC_145. Restore settings.json format and state sync validation
- **Effort**: medium
- **Status**: [PENDING]
- **Language**: meta
- **Dependencies**: None

**Description**: Fix the settings.json format change that removed critical PreToolUse and PostToolUse hooks. The new format removed `permissions` object and validation hooks that ensured TODO.md and state.json stayed synchronized after writes. Need to restore either the old format or adapt the hooks to work with the new format. Without these hooks, state synchronization fails silently, causing TODO.md entries to not match state.json statuses.

**Key Issues to Fix**:
1. Restore PreToolUse hook that validates state.json writes before they happen
2. Restore PostToolUse hook that runs validate-state-sync.sh after state.json writes
3. Either restore the detailed permissions.allow/permissions.deny structure or ensure new format supports equivalent functionality
4. The `$schema` field was added - determine if this is required or optional

**Files to Modify**:
- .opencode/settings.json - Restore hooks and proper format
- May need to update .opencode/hooks/validate-state-sync.sh if format changed

---

### OC_144. Fix systemic metadata delegation across all skills
- **Effort**: large  
- **Status**: [PENDING]
- **Language**: meta
- **Dependencies**: OC_145 (if settings issues block testing)

**Description**: Implement systemic fix for metadata delegation across all 6 skill/agent pairs. Currently, when skills delegate to agents via Task tool, the `metadata_file_path` parameter is missing from the delegation prompt. This causes agents to not know where to write `.return-meta.json` files, which breaks the postflight artifact linking system. Without proper metadata files, TODO.md cannot be updated with Research/Plan/Summary links.

**Skills/Agents to Fix**:
1. skill-implementer → general-implementation-agent
2. skill-planner → planner-agent  
3. skill-meta → meta-builder-agent
4. skill-neovim-implementation → neovim-implementation-agent
5. skill-neovim-research → neovim-research-agent
6. skill-researcher → general-research-agent (see OC_143)

**Changes Required Per Skill**:
- Update Stage 3 delegation prompt to include metadata_file_path
- Add preflight validation that metadata_file_path is present
- Add postflight fallback logic when metadata files are missing
- Update agent documentation to require metadata_file_path validation

**Files to Modify**:
- .opencode/skills/skill-*/SKILL.md (6 files)
- .opencode/agent/subagents/*-agent.md (6 files)

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

### OC_141. Fix agent delegation system failure
- **Summary**: [implementation-summary-20260306.md](OC_141_fix_agent_delegation_system_failure/summaries/implementation-summary-20260306.md)
- **Effort**: 4-6 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None (foundational fix)
- **Research**: [research-001.md](OC_141_fix_agent_delegation_system_failure/reports/research-001.md) - Critical system failure: Skills displayed instead of executed
- **Plan**: [implementation-001.md](OC_141_fix_agent_delegation_system_failure/plans/implementation-001.md) - 7-phase systematic audit and fix of skill-to-agent delegation

**Description**: Skills are being displayed instead of executed. When `/plan` command attempts to invoke skill-planner, the skill specification content is output rather than delegating to planner-agent via Task tool. This is a system-wide failure affecting all workflow commands that depend on skill-to-agent delegation.

**Root Cause**: The skill tool appears to only load skill content for reference but not execute the workflow stages. Commands describe skill invocation but don't actually trigger the Task tool with subagent delegation.

**Impact**: CRITICAL - All workflow commands broken (/plan, /implement, /research, /revise, etc.)

**Files to Audit**:
- All 12+ command specifications (.opencode/commands/*.md)
- All 11+ skill definitions (.opencode/skills/skill-*/SKILL.md)
- All subagent definitions (.opencode/agent/subagents/*.md)
- System configuration (.opencode/AGENTS.md)

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

### OC_137. Investigate and fix planner-agent format compliance issue
- **Effort**: 3-4 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](OC_137_investigate_and_fix_planner_agent_format_compliance_issue/reports/research-001.md) - Initial analysis of context injection failures
  - [research-002.md](OC_137_investigate_and_fix_planner_agent_format_compliance_issue/reports/research-002.md) - **CRITICAL FINDING**: Embedded non-compliant templates in plan.md are the root cause
  - [research-003.md](OC_137_investigate_and_fix_planner_agent_format_compliance_issue/reports/research-003.md) - Context injection optimization: 5 recommendations for progressive disclosure improvement
- **Plan**: [implementation-001.md](OC_137_investigate_and_fix_planner_agent_format_compliance_issue/plans/implementation-001.md) - Original 6-phase plan
  - [implementation-002.md](OC_137_investigate_and_fix_planner_agent_format_compliance_issue/plans/implementation-002.md) - **REVISED: 9-phase comprehensive plan**
- **Summary**: [implementation-summary-20260306.md](OC_137_investigate_and_fix_planner_agent_format_compliance_issue/summaries/implementation-summary-20260306.md)

**Description**: Investigation into why implementation plans created by opencode do not follow the plan-format.md specification. OC_136 plan had wrong format while OC_135 plans had correct format.

**Root Causes Identified & Fixed**:
1. ✅ **revise.md lacked context injection** (CRITICAL) - Fixed by adding `<context_injection>` block with plan-format.md
2. ✅ **plan.md contained embedded non-compliant template** - Fixed by removing template, delegating to planner-agent
3. ✅ **planner-agent fell back to embedded templates** - Fixed by implementing discovery-layer pattern with context prioritization

**Phases Completed**:
- Phase 1: Removed embedded template from plan.md
- Phase 2 & 3: Audited all command specs (only plan.md had templates)
- Phase 4: Added context injection to revise.md (CRITICAL FIX)
- Phase 5: Implemented discovery-layer pattern in planner-agent.md
- Phase 6: Verified status-marker injection (already optimized)
- Phase 9: Testing and validation

**Deferred to Follow-up Tasks**:
- Phase 7: Stage-progressive loading → OC_139
- Phase 8: Documentation updates → OC_140

**Files Modified**:
- `.opencode/commands/revise.md` - Context injection added
- `.opencode/commands/plan.md` - Embedded template removed
- `.opencode/agent/subagents/planner-agent.md` - Discovery-layer pattern

**Outcome**: Both /plan and /revise now have consistent context injection ensuring all future plans follow plan-format.md specification.

### OC_136. Design and implement `/remember` command for intelligent memory management
- **Effort**: 6-8 hours
- **Status**: [COMPLETED]
- **Researched**: 2026-03-05
- **Planned**: 2026-03-06
- **Implemented**: 2026-03-06
- **Summary**: [implementation-summary-20260306.md](OC_136_design_and_implement_remember_command_for_intelligent_memory_management/summaries/implementation-summary-20260306.md)
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](OC_136_design_and_implement_remember_command_for_intelligent_memory_management/reports/research-001.md), [research-002.md](OC_136_design_and_implement_remember_command_for_intelligent_memory_management/reports/research-002.md), [research-003.md](OC_136_design_and_implement_remember_command_for_intelligent_memory_management/reports/research-003.md), [research-004.md](OC_136_design_and_implement_remember_command_for_intelligent_memory_management/reports/research-004.md)
- **Plan**: [implementation-003.md](OC_136_design_and_implement_remember_command_for_intelligent_memory_management/plans/implementation-003.md) (Follows plan-format.md specification)

**Description**: Design and implement a `/remember` command that takes either a prompt or file path as input, learns what it can from what has been passed in, compares existing content in the `.opencode/context/memory/` files, conducts further research online if more information would be helpful, identifies key additions to make to the memory files in a natural and well-orchestrated way, then proposes these additions for the user to approve with interactive checkboxes.

**Key Features Required**:
1. **Input Handling**: Support both text prompts and file paths as input sources
2. **Content Analysis**: Extract key concepts, patterns, and important information from input
3. **Memory Comparison**: Compare against existing `.opencode/context/memory/` files to avoid duplicates and identify gaps
4. **Research Augmentation**: Conduct web research when additional context would strengthen the memory entry
5. **Interactive Approval**: Present proposed memory additions with checkboxes for user selection
6. **Natural Integration**: Additions should fit naturally into existing memory structure
7. **Orchestrated Workflow**: Well-designed flow from input → analysis → research → proposal → approval → storage

**Components to Create**:
- **Command**: `.opencode/commands/remember.md` - User-facing entry point with argument parsing
- **Skill**: `.opencode/skills/skill-remember/SKILL.md` - Validation and delegation logic
- **Agent**: `.opencode/agents/remember-agent.md` - Core execution agent for analysis and proposal

**Workflow Design**:
```
User Input (prompt or file)
    |
    v
Input Parsing & Validation
    |
    v
Content Analysis (extract key info)
    |
    v
Memory File Comparison (check existing)
    |
    v
Research Decision (need more info?)
    |-- YES --> Web Research
    |-- NO ----> Skip
    |
    v
Generate Proposed Additions
    |
    v
Interactive Approval (checkboxes)
    |
    v
Update Memory Files
    |
    v
Confirmation & Summary
```

**Research Requirements**:
- Review existing memory management patterns in opencode ecosystem
- Study best practices from AGENTS.md pattern (project context files)
- Understand interactive checkbox workflows in opencode
- Design natural memory file organization structure

---

### OC_135. Enforce workflow command delegation to prevent direct implementation
- **Effort**: 3-4 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-05
- **Researched**: 2026-03-05
- **Revised**: 2026-03-05
- **Implemented**: 2026-03-05
- **Language**: meta
- **Research**: [research-001.md](OC_135_enforce_workflow_command_delegation_to_prevent_direct_implementation/reports/research-001.md), [research-002.md](OC_135_enforce_workflow_command_delegation_to_prevent_direct_implementation/reports/research-002.md)
- **Plan**: [implementation-002.md](OC_135_enforce_workflow_command_delegation_to_prevent_direct_implementation/plans/implementation-002.md)
- **Summary**: [implementation-summary-20260305.md](OC_135_enforce_workflow_command_delegation_to_prevent_direct_implementation/summaries/implementation-summary-20260305.md)

**Description**: When the user types workflow commands like `/plan N`, `/research N`, or `/implement N`, the AI is currently executing these directly instead of routing them through the skill system with proper delegation to subagents. This causes the main agent to implement when it should only plan, or research when it should delegate. The root cause is missing command interception/routing infrastructure that should detect workflow commands and ensure they are processed by the appropriate skill with forked subagent delegation. Need to design and implement a command routing system that enforces proper delegation boundaries.

**Description**: When the user types workflow commands like `/plan N`, `/research N`, or `/implement N`, the AI is currently executing these directly instead of routing them through the skill system with proper delegation to subagents. This causes the main agent to implement when it should only plan, or research when it should delegate. The root cause is missing command interception/routing infrastructure that should detect workflow commands and ensure they are processed by the appropriate skill with forked subagent delegation. Need to design and implement a command routing system that enforces proper delegation boundaries. **[REVISED]**
- **Previous Plan**: [implementation-001.md](OC_135_enforce_workflow_command_delegation_to_prevent_direct_implementation/plans/implementation-001.md)

**Description**: When the user types workflow commands like `/plan N`, `/research N`, or `/implement N`, the AI is currently executing these directly instead of routing them through the skill system with proper delegation to subagents. This causes the main agent to implement when it should only plan, or research when it should delegate. The root cause is missing command interception/routing infrastructure that should detect workflow commands and ensure they are processed by the appropriate skill with forked subagent delegation. Need to design and implement a command routing system that enforces proper delegation boundaries.

---

### OC_134. Fix workflow command header not showing task number and name
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-04
- **Language**: meta
- **Research**: [research-001.md](OC_134_fix_workflow_command_header_display/reports/research-001.md), [research-002.md](OC_134_fix_workflow_command_header_display/reports/research-002.md)
- **Plan**: [implementation-001.md](OC_134_fix_workflow_command_header_display/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260304.md](OC_134_fix_workflow_command_header_display/summaries/implementation-summary-20260304.md)

**Description**: When running the workflow commands /research, /plan, /revise, or /implement, the header doesn't correctly show the task number and name. The header should display "OC_N. Task Name" at the beginning of the output to clearly identify which task is being processed, but this is currently not working. Need to identify the root cause and plan an elegant solution.

---

### OC_133. Fix planner agent not following plan-format.md specification
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-04
- **Research**: [research-001.md](OC_133_fix_planner_agent_not_following_plan_format_specification/reports/research-001.md)
- **Plan**: [implementation-001.md](OC_133_fix_planner_agent_not_following_plan_format_specification/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260304.md](OC_133_fix_planner_agent_not_following_plan_format_specification/summaries/implementation-summary-20260304.md)
- **Language**: meta

**Description**: When running `/plan 132`, the created plan file at `specs/132_create_context_loading_best_practices_guide/plans/implementation-001.md` fails to follow the format specified in `.opencode/context/core/formats/plan-format.md`. This has happened repeatedly despite multiple attempts to fix it. The root cause may be: (1) planner agent not loading the plan-format.md context, (2) planner agent loading context but not following it, (3) skill-planner not properly injecting context via <context_injection> blocks, or (4) general-implementation-agent not passing plan-format requirements to the planner subagent. The solution requires investigating the context loading chain from skill-planner → planner-agent → plan file creation to ensure the plan-format.md specification is actually being read and applied.

---


### OC_132. Create context loading best practices guide
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Research**: [research-001.md](132_create_context_loading_best_practices_guide/reports/research-001.md)
- **Plan**: [implementation-001.md](132_create_context_loading_best_practices_guide/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260304.md](132_create_context_loading_best_practices_guide/summaries/implementation-summary-20260304.md)

**Description**: Document the "Push vs Pull" context loading strategy that was implemented in task 128. Create `docs/guides/context-loading-best-practices.md` explaining: (1) Push model - critical context injected directly into agent prompts via `<context_injection>` blocks in SKILL.md files, (2) Pull model - context loaded on-demand via @-references, (3) When to use each approach - Push for strict formats/rules that must be followed, Pull for optional documentation and code examples, (4) How to implement Push loading in skills with examples from skill-planner, skill-researcher, and skill-implementer. This guide will help future skill developers understand and apply the context loading patterns correctly.

---

### OC_131. Synchronize state.json, TODO.md, and plan files during /implement execution
- **Effort**: 3-4 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Research**: [research-001.md](OC_131_sync_state_todo_plan_during_implementation/reports/research-001.md)
- **Plan**: [implementation-001.md](OC_131_sync_state_todo_plan_during_implementation/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260304.md](OC_131_sync_state_todo_plan_during_implementation/summaries/implementation-summary-20260304.md)

**Description**: When running `/implement OC_N`, the state.json, TODO.md, and plan implementation-NNN.md files become out of sync. The plan file tracks phase status ([NOT STARTED], [IN PROGRESS], [COMPLETED], [PARTIAL]) but these are not automatically updated during execution. The root cause is that the /implement command specification lacks real-time status tracking mechanisms. The solution requires adding phase status update steps to the implementation workflow: mark phase as [IN PROGRESS] when starting, [COMPLETED] when finished, [PARTIAL] when blocked. Additionally, when phases complete, the plan status summary should reflect overall progress. This ensures all three files (state.json for task metadata, TODO.md for task overview, plan.md for detailed phase tracking) remain synchronized throughout the implementation process.

---

### OC_130. Make .opencode system self-contained
- **Effort**: 2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Research**: [research-001.md](130_make_opencode_self_contained/reports/research-001.md)
- **Plan**: [implementation-001.md](130_make_opencode_self_contained/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260304.md](130_make_opencode_self_contained/summaries/implementation-summary-20260304.md)

**Description**: The .opencode system should be self-contained and not rely on references to .claude/ directories or files. Currently, files like `plan-format.md` are deprecated and claim to use Claude format specifications. The goal is to remove all references to `.claude/` within `.opencode/` and ensure `.opencode/` uses its own format specifications and is fully self-contained.

---

### OC_129. Fix plan format in implementation-001.md to follow plan-format.md standards
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Research**: [research-001.md](129_fix_plan_format_in_implementation_001_md/reports/research-001.md)
- **Research**: [research-002.md](129_fix_plan_format_in_implementation_001_md/reports/research-002.md)
- **Plan**: [implementation-001.md](129_fix_plan_format_in_implementation_001_md/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260304.md](129_fix_plan_format_in_implementation_001_md/summaries/implementation-summary-20260304.md)
- **Language**: meta

**Description**: The plan file /home/benjamin/.config/nvim/specs/128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/plans/implementation-001.md was created with incorrect format. It contains `**Status**: [STATUS]` metadata lines after each phase heading instead of the correct format from plan-format.md which requires status markers ONLY in the phase headings (e.g., `### Phase N: Name [STATUS]`). Need to update the file to follow the standard format with status only in headings and no separate metadata lines per phase.


### 128. Ensure /task command only creates tasks and never implements solutions automatically
- **Effort**: 2-4 hours
- **Status**: [COMPLETED]
- **Language**: general
- **Planning Started**: 2026-03-04
- **Planning Completed**: 2026-03-04
- **Implementation Started**: 2026-03-04
- **Implementation Completed**: 2026-03-04
- **Research**: [research-001.md](128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/reports/research-001.md)
- **Plan**: [implementation-001.md](128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/plans/implementation-001.md)
- **Plan**: [implementation-002.md](128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/plans/implementation-002.md)
- **Summary**: [implementation-summary-20260304.md](128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/summaries/implementation-summary-20260304.md)
- **Summary**: [implementation-summary-push-context-20260304.md](128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/summaries/implementation-summary-push-context-20260304.md)

**Description**: Ensure /task command only creates tasks and never implements solutions automatically.

---

### 127. Migrate OPENCODE.md to README.md and rename QUICK-START.md to INSTALLATION.md
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-03
- **Planning Started**: 2026-03-03
- **Planning Completed**: 2026-03-03
- **Research**: [research-001.md](127_migrate_opencode_md_to_readme_and_rename_quick_start_to_installation/reports/research-001.md)
- **Plan**: [implementation-001.md](127_migrate_opencode_md_to_readme_and_rename_quick_start_to_installation/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260303.md](127_migrate_opencode_md_to_readme_and_rename_quick_start_to_installation/summaries/implementation-summary-20260303.md)

**Description**: Migrate /home/benjamin/.config/nvim/.opencode/OPENCODE.md into /home/benjamin/.config/nvim/.opencode/README.md to provide a single README.md file with systematic coverage of all features of the core .opencode/ agent system as well as the various extensions provided and cross links to relevant README.md files scattered throughout the subdirectories. Rename /home/benjamin/.config/nvim/.opencode/QUICK-START.md to INSTALLATION.md which should focus entirely on what is needed to install all dependencies.

---

### 126. Fix <leader>ao picker to load extensions into correct subdirectory
- **Effort**: 2-4 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](126_fix_ao_picker_extension_loading_path/reports/research-001.md)
- **Plan**: [implementation-001.md](126_fix_ao_picker_extension_loading_path/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260304.md](126_fix_ao_picker_extension_loading_path/summaries/implementation-summary-20260304.md)

**Description**: Fix the `<leader>ao` picker to load extensions into the correct `.opencode/agents/subagents/` subdirectory instead of directly into `.opencode/agents/`. Currently, when loading extensions via `<leader>ao` in `/home/benjamin/Projects/Logos/Theory/`, files are being placed at `.opencode/agents/formal-research-agent.md` instead of the desired `.opencode/agents/subagents/`. This functionality must be distinct from `<leader>ac` which should continue loading directly into `.claude/agents/`.

---

### 125. Add epidemiology research extension for R and related tooling
- **Effort**: 7 hours
- **Status**: [COMPLETED]
- **Planning Started**: 2026-03-04
- **Planning Completed**: 2026-03-04
- **Research Started**: 2026-03-03
- **Research Completed**: 2026-03-04
- **Implementation Started**: 2026-03-04
- **Implementation Completed**: 2026-03-04
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](125_epidemiology_r_extension/reports/research-001.md)
- **Research**: [research-002.md](125_epidemiology_r_extension/reports/research-002.md)
- **Plan**: [implementation-001.md](125_epidemiology_r_extension/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260304.md](125_epidemiology_r_extension/summaries/implementation-summary-20260304.md)

**Description**: Add an extension for conducting epidemiology research using R and any other standard software, MCP servers, agents, skills, and commands that would help to streamline the workflow. The same extension should be added to both .opencode/extensions/ and .claude/extensions/

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
