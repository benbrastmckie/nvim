---
next_project_number: 495
---

# TODO

## Task Order

*Updated 2026-04-25. 7 active tasks remaining.*

### Pending

- **494** [IMPLEMENTING] -- Simplify status transition rules to allow iterative workflows
- **490** [COMPLETED] -- Wire --roadmap flag through /plan command
- **491** [COMPLETED] -- Add ROADMAP.md preflight to /research command
- **492** [COMPLETED] -- Ensure /review creates ROADMAP.md if missing
- **493** [COMPLETED] -- Add per-phase ROADMAP.md updates to planner (depends: 490)
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 494. Simplify status transition rules to allow iterative workflows
- **Effort**: TBD
- **Status**: [IMPLEMENTING]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [494_simplify_status_transitions/reports/01_simplify-status-transitions.md]
- **Plan**: [494_simplify_status_transitions/plans/01_simplify-status-transitions.md]

**Description**: Replace the forward-only status transition model with a permissive one: any `/research`, `/plan`, `/revise`, or `/implement` command can run from any non-terminal status. Only terminal states (`[COMPLETED]`, `[ABANDONED]`, `[EXPANDED]`) block transitions. This enables the natural iterative workflow of cycling through /research -> /plan -> /implement -> /research -> ... without status gates blocking backward movement. Files to update: `.claude/context/standards/status-markers.md` (transition tables), `.claude/rules/state-management.md` ("Cannot regress" rule), `.claude/context/orchestration/state-management.md` (transition table), `.claude/skills/skill-orchestrator/SKILL.md` (Allowed Statuses table), `.claude/context/workflows/status-transitions.md` (deprecated but still loaded), and corresponding core extension copies under `.claude/extensions/core/`.

---

### 490. Wire --roadmap flag through /plan command to planner-agent
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [490_wire_roadmap_flag_plan_command/reports/01_wire-roadmap-flag.md]
- **Plan**: [490_wire_roadmap_flag_plan_command/plans/01_wire-roadmap-flag.md]
- **Summary**: [490_wire_roadmap_flag_plan_command/summaries/01_wire-roadmap-flag-summary.md]

**Description**: The /plan command does not currently parse or pass a `--roadmap` flag. The planner-agent has Stage 2.6 (Evaluate Roadmap Flag) architecturally prepared but never receives the flag. Wire the `--roadmap` flag from the /plan command through skill-planner delegation context to the planner-agent so Stage 2.6 activates. Files: `.claude/commands/plan.md`, `.claude/skills/skill-planner.md` (or SKILL.md), planner-agent delegation context.

---

### 491. Add ROADMAP.md preflight consultation to /research command
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [491_research_roadmap_preflight/reports/01_research-roadmap-preflight.md]
- **Plan**: [491_research_roadmap_preflight/plans/01_research-roadmap-preflight.md]
- **Summary**: [491_research_roadmap_preflight/summaries/01_research-roadmap-preflight-summary.md]

**Description**: The /research command should, by default, read `specs/ROADMAP.md` during preflight (before delegating to research subagents) and inject relevant roadmap context into the agent's delegation context. This gives research agents strategic awareness of project direction without requiring a flag. The `--clean` flag should suppress this auto-consultation (consistent with memory retrieval suppression). Files: `.claude/commands/research.md`, `.claude/skills/skill-researcher.md` (or SKILL.md), research agent delegation context.

---

### 492. Ensure /review creates ROADMAP.md if missing
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [492_review_create_roadmap/reports/01_review-create-roadmap.md]
- **Plan**: [492_review_create_roadmap/plans/01_review-create-roadmap.md]
- **Summary**: [492_review_create_roadmap/summaries/01_review-create-roadmap-summary.md]

**Description**: The /review command's Step 2.5 reads ROADMAP.md for cross-referencing but does not create a default ROADMAP.md if one doesn't exist (unlike /todo which does). Add creation-if-missing logic to /review's roadmap integration step, using the same default template as /todo. Files: `.claude/commands/review.md`.

---

### 493. Add per-phase ROADMAP.md update steps to planner roadmap mode
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: 490
- **Research**: [493_planner_per_phase_roadmap_updates/reports/01_per-phase-roadmap.md]
- **Plan**: [493_planner_per_phase_roadmap_updates/plans/01_per-phase-roadmap.md]
- **Summary**: [493_planner_per_phase_roadmap_updates/summaries/01_per-phase-roadmap-summary.md]

**Description**: When `--roadmap` is active, the planner currently generates a Phase 1 "Review and Snapshot" and a final "Update ROADMAP.md" phase. Strengthen this so: (a) Phase 1 updates ROADMAP.md with what is known with confidence at plan time, not just a snapshot; (b) each subsequent phase includes a ROADMAP.md update step at phase end (not just the final phase). This ensures the roadmap is incrementally updated as implementation progresses. Files: `.claude/commands/plan.md` (planner Stage 2.6 and Stage 3 phase decomposition), `.claude/context/formats/plan-format.md`.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Task Type**: neovim
- **Dependencies**: None
- **Research**: [087_investigate_wezterm_terminal_directory_change/reports/research-001.md]

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Planning Started**: 2026-02-13
- **Planning Completed**: 2026-02-13
- **Task Type**: neovim
- **Dependencies**: None
- **Research**: [078_fix_himalaya_smtp_authentication_failure/reports/research-001.md]
- **Plan**: [078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md]

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: "Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted". The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.
