---
next_project_number: 138
---

# TODO

## Tasks

### OC_138. Fix plan metadata status synchronization
- **Effort**: 2-3 hours
- **Status**: [RESEARCHED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](OC_138_fix_plan_metadata_status_synchronization/reports/research-001.md) - Root cause: synchronization protocol only updates state.json and TODO.md, missing plan file line 4 metadata status
- **Plan**: Needed

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
- **Status**: [RESEARCHED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](OC_137_investigate_and_fix_planner_agent_format_compliance_issue/reports/research-001.md) - Initial analysis of context injection failures
  - [research-002.md](OC_137_investigate_and_fix_planner_agent_format_compliance_issue/reports/research-002.md) - **CRITICAL FINDING**: Embedded non-compliant templates in plan.md are the root cause
- **Plan**: Needed

**Description**: Investigation into why implementation plans created by opencode do not follow the plan-format.md specification, despite task OC_133 supposedly fixing this issue. OC_136 plan (created today) has wrong format while OC_135 plans (created after OC_133) have correct format.

**Root Cause Hypotheses**:
1. Regression in planner-agent.md after OC_133 fix
2. Context injection not working properly
3. Template still has wrong format embedded
4. Verification steps not being executed
5. Different invocation paths produce different results

**Required Investigation**:
1. Audit planner-agent.md current state vs plan-format.md requirements
2. Compare compliant (OC_135) vs non-compliant (OC_136) plans
3. Verify context injection is working
4. Test plan creation via different paths
5. Identify why verification isn't catching non-compliance

**Expected Outcome**:
- All plans must follow plan-format.md specification
- Automated verification prevents non-compliant plans
- Clear documentation of proper invocation path

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
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](087_investigate_wezterm_terminal_directory_change/reports/research-001.md)

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [IMPLEMENTING]
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
