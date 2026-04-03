---
next_project_number: 355
---

# TODO

## Task Order

*Updated 2026-04-02. 8 active tasks remaining.*

### Pending

- **350** [COMPLETED] -- Create multi-task operations context pattern
- **351** [NOT STARTED] -- Update /research command for multi-task support (depends: 350)
- **352** [NOT STARTED] -- Update /plan command for multi-task support (depends: 350)
- **353** [NOT STARTED] -- Update /implement command for multi-task support (depends: 350)
- **354** [NOT STARTED] -- Update CLAUDE.md argument-hints and documentation (depends: 351, 352, 353)
- **349** [COMPLETED] -- Review and update .claude/ agent system documentation
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

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
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: 350

**Description**: Update `.claude/commands/research.md` to accept multiple task numbers, ranges, or both (e.g., `/research 7, 22-24, 59`). Add a STAGE 0: PARSE TASK NUMBERS step before GATE IN that expands ranges into individual task numbers. When multiple tasks are provided, spawn one agent per task number (each running the existing single-task flow), collect results, and produce a single batch git commit and consolidated output. Single task number remains backward-compatible. Flags like `--team` apply to all tasks.

---

### 352. Update /plan command for multi-task support
- **Effort**: 1 hour
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: 350

**Description**: Update `.claude/commands/plan.md` to accept multiple task numbers, ranges, or both (e.g., `/plan 7, 22-24, 59`). Add a STAGE 0: PARSE TASK NUMBERS step before GATE IN that expands ranges into individual task numbers. When multiple tasks are provided, spawn one agent per task number (each running the existing single-task flow), collect results, and produce a single batch git commit and consolidated output. Single task number remains backward-compatible. Flags like `--team` apply to all tasks.

---

### 353. Update /implement command for multi-task support
- **Effort**: 1 hour
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: 350

**Description**: Update `.claude/commands/implement.md` to accept multiple task numbers, ranges, or both (e.g., `/implement 7, 22-24, 59`). Add a STAGE 0: PARSE TASK NUMBERS step before GATE IN that expands ranges into individual task numbers. When multiple tasks are provided, spawn one agent per task number (each running the existing single-task flow), collect results, and produce a single batch git commit and consolidated output. Single task number remains backward-compatible. Flags like `--team`, `--force` apply to all tasks.

---

### 354. Update CLAUDE.md argument-hints and documentation
- **Effort**: 30 minutes
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: 351, 352, 353

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

