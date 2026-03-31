---
next_project_number: 340
---

# TODO

## Task Order

*Updated 2026-03-31. 6 active tasks remaining.*

### Pending

- **336** [COMPLETED] -- Fix TODO.md status update bug in skill-implementer
- **338** [NOT STARTED] -- Consolidate duplicated references across .claude/ files
- **337** [NOT STARTED] -- Condense skill-implementer verbosity (depends: 336)
- **339** [NOT STARTED] -- Reduce agent boilerplate (depends: 338)
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 336. Fix TODO.md status update bug in skill-implementer
- **Effort**: Small
- **Status**: [COMPLETED]
- **Completed**: 2026-03-31
- **Language**: meta
- **Dependencies**: None
- **Summary**: Converted buried prose instructions to prominent structured Edit patterns in skill-implementer; added defensive TODO.md status check in implement.md GATE OUT

**Description**: The skill-implementer postflight (Stage 7, line 295) has a single prose instruction to update TODO.md status from [IMPLEMENTING] to [COMPLETED] that gets skipped because it's sandwiched between code blocks. Fix: (1) Convert the TODO.md status update to a scripted pattern or prominent instruction block, (2) Add defensive TODO.md status check in implement.md GATE OUT (currently only checks state.json), (3) Consider a shared update-task-status.sh script for atomic TODO.md+state.json updates.

---

### 337. Condense skill-implementer verbosity
- **Effort**: Medium
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: 336

**Description**: Restructure skill-implementer/SKILL.md so critical instructions are prominent rather than buried prose between code blocks. Apply same pattern to other verbose skills (skill-fix-it at 1005 lines, skill-todo at 926 lines). Key changes: elevate all TODO.md/state.json update instructions to consistent format (code blocks or explicit step markers), remove redundant explanations that duplicate rules/ files, reduce total line count while preserving all functional instructions.

---

### 338. Consolidate duplicated references across .claude/ files
- **Effort**: Medium
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: None

**Description**: Unify information that's duplicated across multiple files into single canonical sources: (1) Status markers defined in 4+ files -> single reference, (2) Artifact path explanations in 5+ places -> single reference, (3) Error handling re-explained in 12+ files -> cross-reference to error-handling.md, (4) Context discovery jq pattern duplicated in every agent -> shared template or include reference. Replace duplicates with cross-references to canonical sources. Target: eliminate ~800-1200 lines of redundancy.

---

### 339. Reduce agent boilerplate across all agents
- **Effort**: Medium-Large
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: 338

**Description**: Extract repeated boilerplate from 6 agent files (~100-150 lines each = 600-900 total). Repeated sections: Stage 0 (early metadata), Stage 1 (parse delegation), context discovery jq queries, error handling sections, artifact path explanations. Create a base-agent template or shared-sections pattern that agents can reference. Preserve agent-specific execution stages while eliminating structural repetition.

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
