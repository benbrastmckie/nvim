---
next_project_number: 502
---

# TODO

## Task Order

*Updated 2026-04-25. 14 active tasks remaining.*

### Pending

- **494** [COMPLETED] -- Simplify status transition rules to allow iterative workflows
- **490** [COMPLETED] -- Wire --roadmap flag through /plan command
- **491** [COMPLETED] -- Add ROADMAP.md preflight to /research command
- **492** [COMPLETED] -- Ensure /review creates ROADMAP.md if missing
- **493** [COMPLETED] -- Add per-phase ROADMAP.md updates to planner (depends: 490)
- **499** [RESEARCHED] -- Research FORK_SUBAGENT patterns and context: fork optimization strategies
- **500** [NOT STARTED] -- Add context: fork frontmatter to core delegating skills (depends: 499)
- **501** [NOT STARTED] -- Optimize team-mode skills for FORK_SUBAGENT parallel cache sharing (depends: 499)
- **495** [NOT STARTED] -- Add multi-subagent continuation loop to skill-implementer
- **496** [NOT STARTED] -- Add prior-implementation context injection to /research
- **497** [NOT STARTED] -- Add per-phase plan item check-off to implementation agent (depends: 495)
- **498** [NOT STARTED] -- Make /spawn work from any non-terminal state with interactive confirmation
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 499. Research FORK_SUBAGENT patterns and context: fork optimization strategies
- **Effort**: 1-3 hours
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [499_research_fork_subagent_patterns/reports/01_fork-subagent-patterns.md]

**Description**: Deep-dive research into CLAUDE_CODE_FORK_SUBAGENT environment variable and `context: fork` skill frontmatter. Investigate: (1) How prompt cache sharing works between parent sessions and forked subagents -- do Task tool-based delegations already benefit or only `context: fork` skills? (2) The interaction between the env var and the frontmatter field. (3) Current cost implications of the existing thin-wrapper pattern (skills that use Task tool explicitly without `context: fork`). (4) Whether the system-overview.md note "Skills do NOT use context: fork" is intentional architecture or technical debt. (5) Document concrete recommendations for which skills/agents benefit most from forking. Research should include web sources on CLAUDE_CODE_FORK_SUBAGENT best practices and codebase analysis of the 8 core delegating skills plus 4 extension skills.

---

### 500. Add context: fork frontmatter to core delegating skills
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #499

**Description**: Based on research findings from task 499, update core delegating skills to use `context: fork` and `agent:` frontmatter fields for prompt cache efficiency. Currently only skill-meta uses `agent:` and only present-extension skills use `context: fork` -- the 8 core delegating skills (skill-researcher, skill-planner, skill-implementer, skill-reviser, skill-spawn, plus neovim-research, neovim-implementation, nix-research, nix-implementation) all delegate via explicit Task tool invocation without these fields. This creates a documentation-vs-reality gap (thin-wrapper-skill.md recommends fork+agent but core skills do not use them). Update skill frontmatter, verify subagent delegation still works correctly, update system-overview.md to reflect the new pattern, and ensure extension core copies stay synchronized.

---

### 501. Optimize team-mode skills for FORK_SUBAGENT parallel cache sharing
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #499

**Description**: Optimize skill-team-research, skill-team-plan, and skill-team-implement to maximize CLAUDE_CODE_FORK_SUBAGENT parallel cache sharing benefits. With FORK_SUBAGENT=1, teammates 2-N sharing the parent's cached prefix get ~90% input token cost reduction. Investigate: (1) Whether teammate spawning currently inherits the prompt cache or starts fresh. (2) If restructuring teammate dispatch order or context preparation can improve cache hit rates. (3) Whether the default team_size=2 should be reconsidered given reduced costs per additional teammate. (4) Update team orchestration patterns and metadata to track cache savings. Files: `.claude/skills/skill-team-research/SKILL.md`, `.claude/skills/skill-team-plan/SKILL.md`, `.claude/skills/skill-team-implement/SKILL.md`, `.claude/context/patterns/team-orchestration.md`.

---

### 495. Add multi-subagent continuation loop to skill-implementer
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: None

**Description**: Modify skill-implementer to detect partial/handoff returns from the implementation subagent and re-spawn new subagents to continue work. Wire the existing handoff-artifact.md and progress-file.md formats into general-implementation-agent so it writes structured handoffs before context exhaustion instead of simply returning "partial". Add a continuation loop in skill-implementer that reads the handoff artifact, injects it into a new subagent prompt, and continues spawning subagents until all phases are complete or a blocker/critical decision requires user input. The only appropriate causes for interrupting work are blockers or critical decisions -- context exhaustion should be handled transparently via handoff and re-spawn. Files: `.claude/skills/skill-implementer/SKILL.md`, `.claude/agents/general-implementation-agent.md`, `.claude/context/formats/handoff-artifact.md`, `.claude/context/formats/progress-file.md`.

---

### 496. Add prior-implementation context injection to /research
- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: None

**Description**: Modify skill-researcher preflight to detect when a task is in [IMPLEMENTING] or [PARTIAL] status and collect existing implementation artifacts (summaries, handoffs, progress files) from the task directory. Inject these as tagged context into the research agent prompt so it understands what was already done, what approaches were tried, what failed, and where work stalled. Update general-research-agent Stage 2 to use this prior-implementation context in its search strategy, focusing research on the gaps and blockers identified in the handoffs rather than starting from scratch. Files: `.claude/skills/skill-researcher/SKILL.md` (new Stage 4d), `.claude/agents/general-research-agent.md` (Stage 2 strategy update).

---

### 497. Add per-phase plan item check-off to implementation agent
- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #495

**Description**: Extend general-implementation-agent Stage 4 (Execute File Operations Loop) to, after completing each phase, parse the plan for individual checklist items, steps, or sub-tasks within that phase and mark them as completed (using `- [x]` check-off syntax or adding brief completion notes). This provides granular visibility into what was accomplished within each phase, aids handoff documents in knowing exactly where work stopped, and helps subsequent /research runs understand partial completion state. Depends on task 495 because the handoff mechanism determines what the "completion" tracking needs to feed into. Files: `.claude/agents/general-implementation-agent.md` (Stage 4C/4D enhancement).

---

### 498. Make /spawn work from any non-terminal state with interactive confirmation
- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: None

**Description**: Update spawn.md to remove the restriction blocking `researching` and `planning` statuses -- /spawn should work for any task in any non-terminal state (not just blocked/implementing/partial). Update spawn-agent to work without a blocker-focused analysis when the task is not actually blocked: instead, analyze the task holistically and present the user with interactive questions (AskUserQuestion) to confirm what tasks to spawn and provide feedback or discussion before creation. The agent should ask the user about their intent, propose task decomposition, and allow iterative refinement before committing to task creation. Files: `.claude/commands/spawn.md` (status validation table), `.claude/skills/skill-spawn/SKILL.md` (preflight status handling), `.claude/agents/spawn-agent.md` (analysis mode for non-blocked tasks, interactive confirmation).

---

### 494. Simplify status transition rules to allow iterative workflows
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [494_simplify_status_transitions/reports/01_simplify-status-transitions.md]
- **Plan**: [494_simplify_status_transitions/plans/01_simplify-status-transitions.md]
- **Summary**: [494_simplify_status_transitions/summaries/01_simplify-status-transitions-summary.md]

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
