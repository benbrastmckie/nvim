---
next_project_number: 346
---

# TODO

## Task Order

*Updated 2026-03-31. 3 active tasks remaining.*

### Pending

- **345** [IMPLEMENTING] -- Port /deck command-skill-agent from Typst to Slidev
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 345. Port /deck command-skill-agent from Typst to Slidev
- **Effort**: 6 hours
- **Status**: [IMPLEMENTING]
- **Research Started**: 2026-03-31
- **Research Completed**: 2026-04-01
- **Planning Started**: 2026-04-01
- **Planning Completed**: 2026-04-01
- **Implementation Started**: 2026-04-01
- **Language**: founder:deck
- **Dependencies**: None
- **Research**:
  - [01_slidev-port-research.md](345_port_deck_typst_to_slidev/reports/01_slidev-port-research.md)
  - [02_slidev-standards.md](345_port_deck_typst_to_slidev/reports/02_slidev-standards.md)
  - [03_refactor-analysis.md](345_port_deck_typst_to_slidev/reports/03_refactor-analysis.md)
  - [05_deck-library-system.md](345_port_deck_typst_to_slidev/reports/05_deck-library-system.md)
  - [03_slidev-system-design.md](345_port_deck_typst_to_slidev/reports/03_slidev-system-design.md)
- **Plan**:
  - [02_implementation-plan.md](345_port_deck_typst_to_slidev/plans/02_implementation-plan.md)
  - [03_slidev-system-plan.md](345_port_deck_typst_to_slidev/plans/03_slidev-system-plan.md)

**Description**: Port the /deck command-skill-agent system from generating Typst/Touying pitch decks to Slidev markdown-based presentations. Replace 5 .typ templates with Slidev .md templates using themes and scoped CSS. Update deck-builder-agent to emit Slidev markdown and run `slidev export` instead of `typst compile`. Update deck-planner-agent template selection for Slidev themes. Update context patterns from Touying to Slidev conventions. Preserve: YC 10-slide structure, forcing questions workflow, material synthesis pattern, early metadata, non-blocking compilation, 4 deck modes, 3-question planning flow.

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
