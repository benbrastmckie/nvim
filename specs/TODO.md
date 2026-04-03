---
next_project_number: 368
---

# TODO

## Task Order

*Updated 2026-04-03. 16 active tasks remaining.*

### Pending

- **362** [COMPLETED] -- Create centralized update-task-status.sh script
- **363** [COMPLETED] -- Refactor skill-researcher for centralized status updates (depends: 362)
- **364** [COMPLETED] -- Refactor skill-planner for centralized status updates (depends: 362)
- **365** [COMPLETED] -- Refactor skill-implementer for centralized status updates (depends: 362)
- **366** [RESEARCHED] -- Add defensive status verification to /research and /plan GATE OUT (depends: 363, 364)
- **367** [COMPLETED] -- Refactor /revise to use skill delegation pattern (depends: 362)
- **358** [COMPLETED] -- Create process manager core module (lua/neotex/util/process.lua)
- **359** [COMPLETED] -- Create telescope process picker (depends: 358)
- **360** [COMPLETED] -- Add which-key mappings under leader-x for process management (depends: 358, 359)
- **361** [COMPLETED] -- Integrate typst preview with process manager (depends: 358, 360)
- **356** [COMPLETED] -- Add phase dependency analysis to plan format and planner agent
- **357** [COMPLETED] -- Update skill-team-implement to consume plan dependency analysis (depends: 356)
- **355** [COMPLETED] -- Update founder extension README and deck documentation
- **350** [COMPLETED] -- Create multi-task operations context pattern
- **351** [COMPLETED] -- Update /research command for multi-task support (depends: 350)
- **352** [COMPLETED] -- Update /plan command for multi-task support (depends: 350)
- **353** [COMPLETED] -- Update /implement command for multi-task support (depends: 350)
- **354** [COMPLETED] -- Update CLAUDE.md argument-hints and documentation (depends: 351, 352, 353)
- **349** [COMPLETED] -- Review and update .claude/ agent system documentation
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 362. Create centralized update-task-status.sh script
- **Effort**: 2-3 hours
- **Status**: [RESEARCHED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_meta-research.md](362_centralized_status_script/reports/01_meta-research.md)

**Description**: Create `.claude/scripts/update-task-status.sh` -- a centralized shell script that atomically updates task status across state.json (status, timestamps, session_id), TODO.md task entry (`- **Status**: [STATUS]`), and TODO.md Task Order section (`**{N}** [STATUS]`). Supports preflight (in-progress variants: researching, planning, implementing) and postflight (completed variants: researched, planned, completed) operations. Replaces duplicated inline jq/Edit patterns across skill-researcher, skill-planner, and skill-implementer. Includes optional plan file status update via existing update-plan-status.sh.

---

### 363. Refactor skill-researcher for centralized status updates
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: 362
- **Research**: [01_meta-research.md](363_refactor_skill_researcher/reports/01_meta-research.md)

**Description**: Replace inline preflight (Stage 2) and postflight (Stage 7) status update code in skill-researcher with calls to the centralized `update-task-status.sh` script. Fixes the gap where skill-researcher does not update the TODO.md Task Order section during status changes. Evaluate removing the skill-level git commit (Stage 9) to eliminate double-commit with the command-level CHECKPOINT 3.

---

### 364. Refactor skill-planner for centralized status updates
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: 362
- **Research**: [01_meta-research.md](364_refactor_skill_planner/reports/01_meta-research.md)

**Description**: Replace inline preflight (Stage 2) and postflight (Stage 7) status update code in skill-planner with calls to the centralized `update-task-status.sh` script. Fixes the gap where skill-planner does not update the TODO.md Task Order section during status changes. Near-identical refactoring to Task 363 (skill-researcher). Can be done in parallel.

---

### 365. Refactor skill-implementer for centralized status updates
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: 362
- **Research**: [01_meta-research.md](365_refactor_skill_implementer/reports/01_meta-research.md)

**Description**: Replace inline preflight (Stage 2) and postflight (Stage 7) status update code in skill-implementer with calls to the centralized `update-task-status.sh` script. More complex than Tasks 363/364 because skill-implementer also handles completion_data fields (completion_summary, claudemd_suggestions, roadmap_items), partial status with resume_phase, plan file updates, and Recommended Order removal. These additional fields may need to remain inline or the script may need an extension mechanism.

---

### 366. Add defensive status verification to /research and /plan GATE OUT
- **Effort**: 1 hour
- **Status**: [RESEARCHED]
- **Language**: meta
- **Dependencies**: 363, 364
- **Research**: [01_meta-research.md](366_defensive_gate_out/reports/01_meta-research.md)

**Description**: Add defensive correction logic to the CHECKPOINT 2: GATE OUT sections of `/research` (research.md) and `/plan` (plan.md) commands, matching the pattern already implemented in `/implement` (implement.md). Verify that state.json, TODO.md task entry, and TODO.md Task Order section all show the correct final status after skill postflight. Auto-correct any mismatches (e.g., status still showing [RESEARCHING] instead of [RESEARCHED]).

---

### 367. Refactor /revise to use skill delegation pattern
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: 362
- **Research**: [01_meta-research.md](367_refactor_revise_skill/reports/01_meta-research.md)

**Description**: Refactor the `/revise` command to follow the same skill delegation pattern used by `/research`, `/plan`, and `/implement`. Currently, `/revise` handles all work inline (plan loading, analysis, plan creation, status updates) without delegating to a skill or agent. Create a thin `skill-reviser` wrapper with proper postflight marker file protection and centralized status updates. Plan revision path should delegate to planner-agent; description update path can remain inline.

---

### 358. Create process manager core module
- **Effort**: 3 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-04-03
- **Research Completed**: 2026-04-03
- **Planning Completed**: 2026-04-03
- **Language**: neovim
- **Dependencies**: None
- **Research**: [01_process-mgr-core.md](specs/358_process_manager_core/reports/01_process-mgr-core.md)
- **Plan**: [01_process-mgr-core.md](specs/358_process_manager_core/plans/01_process-mgr-core.md)
- **Summary**: [01_process-mgr-core-summary.md](specs/358_process_manager_core/summaries/01_process-mgr-core-summary.md)

**Description**: Create `lua/neotex/util/process.lua` - a centralized process manager for background jobs. Features: job registry tracking pid, cmd, port, cwd, start_time, stdout/stderr buffer. API: `start(opts)` using `vim.fn.jobstart` with auto-detection of next available port, `stop(id)` via `vim.fn.jobstop` + cleanup, `list()` returning all tracked processes. Auto-open browser via `xdg-open` on launch (skip if already open for that port). Cleanup all tracked jobs on `VimLeavePre`. Filetype-aware launch: `.md` files in slidev directories run `npx slidev`, `.typ` files trigger typst-preview. Extensible for future filetypes.

---

### 359. Create telescope process picker
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Completed**: 2026-04-03
- **Research Completed**: 2026-04-03
- **Planning Completed**: 2026-04-03
- **Language**: neovim
- **Dependencies**: 358
- **Research**: [01_process-picker.md](specs/359_telescope_process_picker/reports/01_process-picker.md)
- **Plan**: [01_process-picker.md](specs/359_telescope_process_picker/plans/01_process-picker.md)
- **Summary**: [01_process-picker-summary.md](specs/359_telescope_process_picker/summaries/01_process-picker-summary.md)

**Description**: Create `lua/neotex/plugins/tools/process-picker.lua` - a telescope picker for viewing and managing background processes. Columns: name, command, port, uptime, status. Actions: `<CR>` to kill selected process, `<C-o>` to open port in browser. Preview pane shows recent stdout/stderr output. Integrates with the process.lua registry from task 358.

---

### 360. Add which-key mappings under leader-x for process management
- **Effort**: 45 minutes
- **Status**: [COMPLETED]
- **Research Completed**: 2026-04-03
- **Planning Completed**: 2026-04-03
- **Implementation Completed**: 2026-04-03
- **Language**: neovim
- **Dependencies**: 358, 359
- **Research**: [01_process-keymaps.md](specs/360_process_whichkey_mappings/reports/01_process-keymaps.md)
- **Plan**: [01_process-keymaps.md](specs/360_process_whichkey_mappings/plans/01_process-keymaps.md)
- **Summary**: [01_process-keymaps-summary.md](specs/360_process_whichkey_mappings/summaries/01_process-keymaps-summary.md)

**Description**: Add process management mappings to the existing `<leader>x` group in `lua/neotex/plugins/editor/which-key.lua`. Mappings: `<leader>xl` launch current file (filetype-aware: slidev for .md in slidev dirs, typst-preview for .typ), `<leader>xp` open telescope process picker, `<leader>xk` kill all background processes, `<leader>xo` open current file's port in browser. Must coexist with existing `<leader>x` text manipulation mappings (xa, xA, xd, xs, xw).

---

### 361. Integrate typst preview with process manager
- **Effort**: 30 minutes
- **Status**: [COMPLETED]
- **Research Completed**: 2026-04-03
- **Planning Completed**: 2026-04-03
- **Implementation Completed**: 2026-04-03
- **Language**: neovim
- **Dependencies**: 358, 360
- **Research**: [01_typst-integration.md](specs/361_typst_process_integration/reports/01_typst-integration.md)
- **Plan**: [01_typst-integration.md](specs/361_typst_process_integration/plans/01_typst-integration.md)

**Description**: Migrate `after/ftplugin/typst.lua` job tracking (`typst_watch_job` variable, `vim.fn.jobstart`/`jobstop` calls) to use the shared process registry from task 358. Typst jobs should appear in the telescope process picker from task 359. Unify `<leader>lp` (typst preview) to go through the process manager so all browser-serving processes are tracked uniformly.

---

### 356. Add phase dependency analysis to plan format and planner agent
- **Effort**: 2 hours
- **Status**: [COMPLETED]
- **Research Completed**: 2026-04-03
- **Planning Completed**: 2026-04-03
- **Completed**: 2026-04-03
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_plan-phase-deps.md](specs/356_plan_phase_dependencies/reports/01_plan-phase-deps.md)
- **Plan**: [01_plan-phase-deps.md](specs/356_plan_phase_dependencies/plans/01_plan-phase-deps.md)

**Description**: Update plan-format.md to add a `Depends on:` field to each phase and a `## Dependency Analysis` section after `## Implementation Phases` heading that groups phases into execution waves (phases with no unfinished dependencies run in the same wave). Update planner-agent.md Stage 4 to generate explicit inter-phase dependencies and the wave analysis section. Update the plan_metadata schema in state.json to include `dependency_waves` (array of phase number arrays). Update the example skeleton in plan-format.md to show both additions. This provides structured dependency information that skill-team-implement can consume directly.

**Files to modify**:
- `.claude/context/formats/plan-format.md` - Add `Depends on:` field, `## Dependency Analysis` section, update skeleton
- `.claude/agents/planner-agent.md` - Add dependency analysis to Stage 4, include in Stage 5 output
- `.claude/context/formats/plan-format.md` - Update plan_metadata schema with `dependency_waves`

---

### 357. Update skill-team-implement to consume plan dependency analysis
- **Effort**: 30 minutes
- **Status**: [COMPLETED]
- **Research Completed**: 2026-04-03
- **Planning Completed**: 2026-04-03
- **Completed**: 2026-04-03
- **Language**: meta
- **Dependencies**: 356
- **Research**: [01_team-implement-deps.md](specs/357_team_implement_consume_deps/reports/01_team-implement-deps.md)
- **Plan**: [01_team-implement-deps.md](specs/357_team_implement_consume_deps/plans/01_team-implement-deps.md)

**Description**: Simplify skill-team-implement Stage 5 (Analyze Phase Dependencies) and Stage 6 (Calculate Implementation Waves) to parse the explicit `## Dependency Analysis` section and per-phase `Depends on:` fields from the plan artifact, instead of inferring dependencies from file modifications and cross-references. The plan now provides wave groupings directly, so team-implement reads them rather than computing them. Keep fallback logic for plans that lack the new section (backward compatibility with existing planned tasks).

**Files to modify**:
- `.claude/skills/skill-team-implement/SKILL.md` - Simplify Stage 5-6 to read plan dependencies

---

### 355. Update founder extension README and deck documentation
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Planning Completed**: 2026-04-02
- **Research Completed**: 2026-04-02
- **Completed**: 2026-04-02
- **Language**: founder
- **Research**: [01_team-research.md](specs/355_update_founder_readme_deck_docs/reports/01_team-research.md)
- **Plan**: [01_founder-readme-deck-docs.md](specs/355_update_founder_readme_deck_docs/plans/01_founder-readme-deck-docs.md)
- **Summary**: [01_founder-readme-deck-docs-summary.md](specs/355_update_founder_readme_deck_docs/summaries/01_founder-readme-deck-docs-summary.md)

**Description**: Update /home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/README.md and add content to /home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/deck/README.md providing complete, consistent, clear, and concise documentation

### 350. Create multi-task operations context pattern
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Research Completed**: 2026-04-02
- **Planning Completed**: 2026-04-02
- **Completed**: 2026-04-02
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_multi-task-ops.md](specs/350_multi_task_operations_pattern/reports/01_multi-task-ops.md)
- **Plan**: [01_multi-task-ops-plan.md](specs/350_multi_task_operations_pattern/plans/01_multi-task-ops-plan.md)
- **Summary**: [01_multi-task-ops-summary.md](specs/350_multi_task_operations_pattern/summaries/01_multi-task-ops-summary.md)

**Description**: Create a shared context pattern document (`.claude/context/patterns/multi-task-operations.md`) defining how workflow commands parse multi-task arguments (single numbers, comma-separated lists, ranges like `22-24`, and combinations like `7, 22-24, 59`). Document the dispatch loop pattern (spawn one agent per task via Agent tool), batch commit format, consolidated output format, and partial-success error handling. This pattern is consumed by tasks 351-353.

---

### 351. Update /research command for multi-task support
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Completed**: 2026-04-02
- **Language**: meta
- **Dependencies**: 350
- **Research**: [01_research-cmd-multi-task.md](specs/351_research_multi_task_support/reports/01_research-cmd-multi-task.md)
- **Plan**: [01_research-cmd-multi-task.md](specs/351_research_multi_task_support/plans/01_research-cmd-multi-task.md)
- **Summary**: [01_research-cmd-multi-task-summary.md](specs/351_research_multi_task_support/summaries/01_research-cmd-multi-task-summary.md)

**Description**: Update `.claude/commands/research.md` to accept multiple task numbers, ranges, or both (e.g., `/research 7, 22-24, 59`). Add a STAGE 0: PARSE TASK NUMBERS step before GATE IN that expands ranges into individual task numbers. When multiple tasks are provided, spawn one agent per task number (each running the existing single-task flow), collect results, and produce a single batch git commit and consolidated output. Single task number remains backward-compatible. Flags like `--team` apply to all tasks.

---

### 352. Update /plan command for multi-task support
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Completed**: 2026-04-02
- **Language**: meta
- **Dependencies**: 350
- **Research**: [01_plan-cmd-multi-task.md](specs/352_plan_multi_task_support/reports/01_plan-cmd-multi-task.md)
- **Plan**: [01_plan-cmd-multi-task.md](specs/352_plan_multi_task_support/plans/01_plan-cmd-multi-task.md)
- **Summary**: [01_plan-cmd-multi-task-summary.md](specs/352_plan_multi_task_support/summaries/01_plan-cmd-multi-task-summary.md)

**Description**: Update `.claude/commands/plan.md` to accept multiple task numbers, ranges, or both (e.g., `/plan 7, 22-24, 59`). Add a STAGE 0: PARSE TASK NUMBERS step before GATE IN that expands ranges into individual task numbers. When multiple tasks are provided, spawn one agent per task number (each running the existing single-task flow), collect results, and produce a single batch git commit and consolidated output. Single task number remains backward-compatible. Flags like `--team` apply to all tasks.

---

### 353. Update /implement command for multi-task support
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Completed**: 2026-04-02
- **Language**: meta
- **Dependencies**: 350
- **Research**: [01_implement-cmd-multi-task.md](specs/353_implement_multi_task_support/reports/01_implement-cmd-multi-task.md)
- **Plan**: [01_implement-cmd-multi-task.md](specs/353_implement_multi_task_support/plans/01_implement-cmd-multi-task.md)
- **Summary**: [01_implement-cmd-multi-task-summary.md](specs/353_implement_multi_task_support/summaries/01_implement-cmd-multi-task-summary.md)

**Description**: Update `.claude/commands/implement.md` to accept multiple task numbers, ranges, or both (e.g., `/implement 7, 22-24, 59`). Add a STAGE 0: PARSE TASK NUMBERS step before GATE IN that expands ranges into individual task numbers. When multiple tasks are provided, spawn one agent per task number (each running the existing single-task flow), collect results, and produce a single batch git commit and consolidated output. Single task number remains backward-compatible. Flags like `--team`, `--force` apply to all tasks.

---

### 354. Update CLAUDE.md argument-hints and documentation
- **Effort**: 30 minutes
- **Status**: [COMPLETED]
- **Research Completed**: 2026-04-02
- **Planning Completed**: 2026-04-02
- **Completed**: 2026-04-02
- **Language**: meta
- **Dependencies**: 351, 352, 353
- **Research**: [01_docs-update-scope.md](specs/354_update_docs_multi_task/reports/01_docs-update-scope.md)
- **Plan**: [01_docs-update-plan.md](specs/354_update_docs_multi_task/plans/01_docs-update-plan.md)
- **Summary**: [01_docs-update-summary.md](specs/354_update_docs_multi_task/summaries/01_docs-update-summary.md)

**Description**: Update argument-hint frontmatter in research.md, plan.md, and implement.md to reflect new multi-task syntax. Update the command reference table in `.claude/CLAUDE.md` to show the new argument formats. Add a brief note about multi-task dispatch to the Command Reference section.

---

### 349. Review and update .claude/ agent system documentation for correctness and consistency
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Research**: [01_team-research.md](specs/349_review_update_claude_agent_system_docs/reports/01_team-research.md)
- **Plan**: [01_documentation-review-plan.md](specs/349_review_update_claude_agent_system_docs/plans/01_documentation-review-plan.md)
- **Summary**: [01_documentation-review-summary.md](specs/349_review_update_claude_agent_system_docs/summaries/01_documentation-review-summary.md)

**Description**: Systematically review the .claude/ agent system and its various extensions, ensuring all documentation is correct, consistent, clear, complete, and concise. Focus particularly on .claude/README.md, .claude/extensions/README.md, and .claude/extensions/founder/README.md. Ensure Unicode box-drawing characters are used consistently (as in line 35+ of .claude/README.md).

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](087_investigate_wezterm_terminal_directory_change/reports/research-001.md)

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

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

---

## Recommended Order

