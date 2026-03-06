---
next_project_number: 148
---

# TODO

## Tasks

### OC_150. Fix /todo orphan detection for completed tasks not in state.json
- **Effort**: 2-3 hours
- **Status**: [PLANNED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](OC_150_fix_todo_orphan_detection/reports/research-001.md) - Analysis of orphan detection gap where completed tasks in TODO.md but removed from state.json are not archived
  - [research-002.md](OC_150_fix_todo_orphan_detection/reports/research-002.md) - Comparative analysis of .claude/ vs .opencode/ /todo implementations with implementation patterns
- **Plan**: [implementation-001.md](OC_150_fix_todo_orphan_detection/plans/implementation-001.md) - 7-phase implementation plan for TODO.md orphan detection
  - [implementation-002.md](OC_150_fix_todo_orphan_detection/plans/implementation-002.md) - 5-phase implementation plan for fixing /todo orphan detection (updated)

**Description**: Fix /todo command's orphan detection to properly handle completed tasks that appear in TODO.md but have been manually removed from state.json. Currently, tasks like OC_138, OC_139, OC_140 are marked [COMPLETED] in TODO.md and have directories in specs/, but are not being archived because they're not in state.json's active_projects array.

**Problem:**
The /todo command's Stage 3 (ScanTasks) only looks for tasks with status "completed" or "abandoned" in state.json. It misses tasks that:
1. Have [COMPLETED] or [ABANDONED] status in TODO.md
2. Have directories existing in specs/
3. Are NOT in state.json active_projects (manually removed)

**Key Findings:**
- OC_138, OC_139, OC_140 are actual orphans - marked [COMPLETED] in TODO.md, have directories in specs/, but not in state.json
- Detection logic needs to scan TODO.md AND cross-reference with state.json
- Fix required in skill-todo stages 3, 9, 10, and 11
- **From .claude/ comparison**: Filesystem-first detection pattern catches all orphans by scanning directories first
- **From .claude/ comparison**: Cross-reference TODO.md entries with state.json to identify tracking gaps
- **Best practice**: Combine .claude/'s filesystem scanning with .opencode/'s memory harvesting

**Fix Required:**
1. Add TODO.md scanning to identify completed/abandoned entries
2. Cross-reference with state.json active_projects array
3. Cross-reference with filesystem directories
4. Identify "TODO.md orphans" - tasks in TODO.md that should be archived but aren't tracked
5. Include these in the archival workflow

**Files to Modify:**
- .opencode/skills/skill-todo/SKILL.md (Stages 3, 9, 10, 11)

---

### OC_149. Review and update .opencode/ documentation with comprehensive README files
- **Effort**: 3-4 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [research-001.md](OC_149_review_update_opencode_documentation_readme_files/reports/research-001.md) - Comprehensive audit of .opencode/ directory: 177 directories, only 20 have README.md (11.3%), 157 need creation
- **Plan**: [implementation-001.md](OC_149_review_update_opencode_documentation_readme_files/plans/implementation-001.md) - 6-phase plan: core system → extension roots → extension structure → docs organization → remaining directories → verification. Total 6-8 hours.
- **Summary**: [implementation-summary-20260305.md](OC_149_review_update_opencode_documentation_readme_files/summaries/implementation-summary-20260305.md) - Complete implementation: 183 new README files, 197 directories with 100% coverage

**Description**: Review and systematically update the documentation in .opencode/ so that every subdirectory has a README.md that fully reports the contents of that directory and links to the README.md files in any further subdirectories that it contains as well as backlinking. Also, organize the markdown files in /home/benjamin/.config/nvim/.opencode/docs/ into appropriate subdirectories (aside from README.md which should live in that docs/ directory to report on the subdirectories it contains).

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
