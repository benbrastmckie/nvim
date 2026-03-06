---
next_project_number: 158
---

# TODO

## Tasks

### OC_158. Ensure workflow command uniformity - prevent /research from failing to call research agent
- **Effort**: 2-3 hours
- **Status**: [RESEARCHING]
- **Language**: meta
- **Dependencies**: None

**Description**: Prevent /research command from failing to call the research agent, making task workflow commands /research, /plan, /revise, and /implement uniform. Sometimes /research fails to call the research agent, conducting the research by the primary agent instead.

---

### OC_157. Fix task-creation-agent not found error
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Language**: meta
- **Dependencies**: None

**Description**: Fix task-creation-agent not found error. The skill-task.md references an agent type task-creation-agent that does not exist, causing Error: Unknown agent type: task-creation-agent is not a valid agent type. Need to either create the agent, update the skill to use general agent, or fix the reference.

**Artifacts**:
- [research-001.md](OC_157_fix_task_creation_agent_not_found_error/reports/research-001.md) - Research report analyzing /task command complexity and proposing 97% reduction through direct execution pattern, eliminating skill-task delegation and non-existent task-creation-agent dependency

---

### OC_156. Avoid tmp directory permission requests in agent system
- **Effort**: 2-3 hours
- **Status**: [PLANNED]
- **Research Started**: 2026-03-06
- **Research Completed**: 2026-03-06
- **Planning Started**: 2026-03-06
- **Planning Completed**: 2026-03-06
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](OC_156_avoid_tmp_directory_permission_requests_in_agent_system/reports/research-001.md) - Comprehensive analysis identifying 85+ occurrences of /tmp/state.json pattern across .opencode/ system. Recommended solution: replace with specs/tmp/state.json using existing project-local tmp directory.
- **Plan**: [implementation-001.md](OC_156_avoid_tmp_directory_permission_requests_in_agent_system/plans/implementation-001.md) - 8-phase implementation plan for migrating /tmp/state.json to specs/tmp/state.json across 85+ occurrences in 21 files

**Description**: Avoid permission requests for /tmp directory in opencode agent system. When using jq to update state.json, the current implementation writes to /tmp/state.json and moves it back, causing permission prompts. Use specs/tmp/ exclusively throughout .opencode/ agent system or find an elegant way to avoid temporary files altogether.

**Key Findings**:
1. **85+ occurrences** of `/tmp/state.json` pattern across codebase
2. **Solution**: Use existing `specs/tmp/` directory (user-owned, no permission issues)
3. **Files affected**: Commands (9), Skills (20+), Context docs (35+), Scripts (9)
4. **Migration**: Simple find-and-replace, no logic changes
5. **Pattern**: `> /tmp/state.json` becomes `> specs/tmp/state.json`

**Artifacts**:
- [research-001.md](OC_156_avoid_tmp_directory_permission_requests_in_agent_system/reports/research-001.md) - Comprehensive analysis and implementation plan
- [implementation-001.md](OC_156_avoid_tmp_directory_permission_requests_in_agent_system/plans/implementation-001.md) - 8-phase implementation plan for migrating /tmp/state.json to specs/tmp/state.json across 85+ occurrences in 21 files

---

### OC_155. Review .opencode/ agent system for <leader>ao picker improvements
- **Effort**: 2-3 hours
- **Status**: [IMPLEMENTING]
- **Research Started**: 2026-03-06
- **Research Completed**: 2026-03-06
- **Planning Started**: 2026-03-06
- **Planning Completed**: 2026-03-06
- **Implementation Started**: 2026-03-06
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](OC_155_review_opencode_agent_system_leader_ao_picker/reports/research-001.md) - Comprehensive analysis of .opencode/ agent system and <leader>ao picker identifying 6 major gaps: context files (90+ not surfaced), memory system not integrated, rules directory not exposed, no task status visibility, architectural coupling risks, and incomplete docs coverage.
- **Plan**: [implementation-001.md](OC_155_review_opencode_agent_system_leader_ao_picker/plans/implementation-001.md) - 6-phase implementation plan for adding context files, memory system, and rules directory to <leader>ao picker

**Description**: Review my .opencode/ agent system to see what improvements could be made to the <leader>ao picker for managing my agent system since I have made many changes and worry not everything is tracked as it should be.

**Key Findings**:
1. **Context files** (90+ files) - NOT surfaced in picker
2. **Memory system** (.opencode/memory/) - no picker integration  
3. **Rules directory** (6 files) - not accessible via picker
4. **Task status** - no visibility into specs/state.json
5. **Architectural risk** - picker uses shared Claude implementation
6. **Docs coverage** - only shows README.md, missing guides/architecture

**Artifacts**:
- [research-001.md](OC_155_review_opencode_agent_system_leader_ao_picker/reports/research-001.md) - Comprehensive analysis identifying 6 major gaps and 6 prioritized recommendations

---

### OC_154. Task command fails to create entries - not a specs/ directory issue
- **Effort**: 2-4 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-06
- **Research Completed**: 2026-03-06
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](OC_154_task_command_fails_to_create_entries_not_specs_directory_issue/reports/research-001.md) - Comprehensive analysis identifying root cause: /task is a direct execution command (no skill delegation) while other commands delegate to skills. Agents interpret problem descriptions as requests to solve rather than following task.md CREATE mode steps.

**Description**: The /task command fails to create task entries even when specs/ directory exists with TODO.md and state.json. Initial diagnosis assumed the issue was missing specs/ directory when copying .opencode/ to other directories, but the command also fails in the current directory where specs/ is present. This indicates a deeper issue with the task command implementation or the agent's interpretation of the command rules.

**Root Cause (from research)**:
1. **Architectural Difference**: /task is a direct execution command (no skill delegation), while /implement, /research, /plan all delegate to skills
2. **Agent Behavior**: Agents naturally want to solve problems described in task descriptions, ignoring the "DO NOT IMPLEMENT" warnings in task.md
3. **Lack of Enforcement**: No skill-task exists to enforce CREATE mode execution, unlike other commands
4. **Task 151 Success**: Proves system works when agents follow instructions correctly

**Key Findings**:
- /task command file exists and is correct (.opencode/commands/task.md lines 7-144)
- Task 151 was successfully created (commit 39cbfe53) following proper CREATE mode
- Failed attempts show agents diagnosing instead of creating (current conversation)
- No system bug - the issue is agent adherence to task.md instructions

**Artifacts**:
- [research-001.md](OC_154_task_command_fails_to_create_entries_not_specs_directory_issue/reports/research-001.md) - Comprehensive analysis identifying root cause
- [research-002.md](OC_154_task_command_fails_to_create_entries_not_specs_directory_issue/reports/research-002.md) - Regression analysis: /task command broke due to architectural shift in task 153 phases 1-4 that changed other commands to 'command orchestrates workflow' pattern while /task remained on 'direct agent execution' pattern
- [implementation-001.md](OC_154_task_command_fails_to_create_entries_not_specs_directory_issue/plans/implementation-001.md) - 5-phase implementation plan for fixing /task command behavioral issues
- [implementation-002.md](OC_154_task_command_fails_to_create_entries_not_specs_directory_issue/plans/implementation-002.md) - REPLAN: 4-phase implementation plan based on regression analysis to fix architectural pattern inconsistency
- [.opencode/skills/skill-task/SKILL.md](.opencode/skills/skill-task/SKILL.md) - New skill definition for task creation context loading with thin wrapper pattern

---

### OC_153. Fix skill-implementer postflight not executing - status not updating after implementation
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research**: [research-001.md](OC_153_fix_skill_implementer_postflight_not_executing/reports/research-001.md) - Comprehensive analysis identifying that skill tool only loads definitions, doesn't execute workflows. Commands must implement preflight/postflight status updates themselves, not rely on skills to do it.
- **Plan**: [implementation-002.md](OC_153_fix_skill_implementer_postflight_not_executing/plans/implementation-002.md) - Revised 6-phase plan with clarifications: bug documentation, upgraded risk level, automatic status update success criterion
- **Language**: meta
- **Dependencies**: None

**Description**: Fix the issue where task status is not being updated to [COMPLETED] after implementation finishes. The root cause is that the skill tool only loads skill definitions but doesn't execute the skill workflow (preflight/postflight). After implementing OC_151, state.json still shows "planning", TODO.md shows [PLANNING], and the plan file header shows [NOT STARTED], even though all phases were completed and .return-meta.json was created correctly.

**Root Cause**: 
- The `/implement` command documents calling `skill` tool to "execute the implementation workflow"
- But `skill` tool only **loads** skill content, it doesn't **execute** the workflow
- The preflight/postflight stages defined in skill-implementer/SKILL.md never run
- Therefore state.json, TODO.md, and plan file status are never updated

**Artifacts**:
- [implementation-summary-20260306.md](OC_153_fix_skill_implementer_postflight_not_executing/summaries/implementation-summary-20260306.md) - Complete implementation summary documenting all 6 phases, technical details, and verification results

**Required Changes**:
1. Investigate how skills should actually be invoked to execute their workflow
2. Fix the `/implement` command to properly trigger skill-implementer postflight
3. Fix the `/plan` command to properly trigger skill-planner postflight  
4. Add missing postflight execution to complete status updates
5. Remediate OC_151 status manually (currently stuck at "planning")

**Files to Modify**:
- `.opencode/commands/implement.md` - Add actual postflight execution
- `.opencode/commands/plan.md` - Add actual postflight execution
- `.opencode/skills/skill-implementer/SKILL.md` - Clarify execution mechanism
- `.opencode/skills/skill-planner/SKILL.md` - Clarify execution mechanism
- `specs/state.json` - Fix OC_151 status
- `specs/TODO.md` - Fix OC_151 status
- `specs/OC_151_*/plans/implementation-001.md` - Fix header status

---

### OC_152. Fix git commit co-author attribution showing Claude Opus instead of actual model
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Research**: [research-001.md](OC_152_fix_git_commit_co_author_attribution/reports/research-001.md) - Research report identifying 14 files with incorrect 'Claude Opus 4.5' co-author attribution that should be standardized to 'OpenCode'
- **Plan**: [implementation-001.md](OC_152_fix_git_commit_co_author_attribution/plans/implementation-001.md) - 3-phase implementation plan for removing co-author attribution from 15 files
- **Language**: meta
- **Dependencies**: None

**Description**: Fix git commit co-author attribution showing 'Co-Authored-By: Claude Opus 4.5' when using Kimi K2.5 in OpenCode. The commit messages incorrectly attribute co-authorship to Claude Opus when the actual model being used is Kimi K2.5. Need to investigate where this attribution is coming from and either correct it to reflect the actual model or remove it entirely.

**Artifacts**:
- [research-001.md](OC_152_fix_git_commit_co_author_attribution/reports/research-001.md) - Research report identifying 14 files with incorrect 'Claude Opus 4.5' co-author attribution
- [implementation-001.md](OC_152_fix_git_commit_co_author_attribution/plans/implementation-001.md) - 3-phase implementation plan for removing co-author attribution from 15 files
- [implementation-summary-001.md](OC_152_fix_git_commit_co_author_attribution/summaries/implementation-summary-001.md) - Implementation summary with file list and verification results

---

### OC_151. Rename /remember command to /learn
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](OC_151_rename_remember_command_to_learn/reports/research-001.md) - Comprehensive research report identifying 47+ references to skill-remember and /remember across the OpenCode system. Categorized by priority and provided clean-break rename recommendations based on OC_142 precedent.

**Description**: Rename the /remember command to /learn throughout the OpenCode system. This involves updating the skill definition (skill-remember → skill-learn), command registration, and all documentation references.

**Artifacts**:
- [research-001.md](OC_151_rename_remember_command_to_learn/reports/research-001.md) - Comprehensive research report identifying 47+ references to skill-remember and /remember across the OpenCode system
- [implementation-001.md](OC_151_rename_remember_command_to_learn/plans/implementation-001.md) - 6-phase implementation plan for clean-break rename with no backward compatibility aliases

---
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
- **Status**: [PLANNED]
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
