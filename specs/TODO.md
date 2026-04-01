---
next_project_number: 348
---

# TODO

## Task Order

*Updated 2026-04-01. 4 active tasks remaining.*

### Pending

- **347** [NOT STARTED] -- Add interactive deck plan picker
- **346** [COMPLETED] -- Refactor deck library from .context/ to founder extension
- **345** [COMPLETED] -- Port /deck command-skill-agent from Typst to Slidev
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 347. Add interactive deck plan picker
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: 345, 346

**Description**: Add an interactive question picker to the deck planning workflow (`/plan` on founder/deck tasks) so users can choose protocol/pattern, theme, content templates, and slide order before the plan is created. Currently `/plan` on a deck task routes to `skill-founder-plan` -> `founder-plan-agent` which generates a plan directly without user input. The desired behavior is that before the agent creates the plan, the user is presented with AskUserQuestion prompts to select from the deck library's available themes (5), patterns (5), animations (6), styles (9), and content templates (22) via the deck index.json. The selected choices should then be passed to the planning agent so the generated plan reflects the user's design preferences. Research what changes are needed to skill-founder-plan, founder-plan-agent, and/or the /plan command to support this interactive selection flow.

---

### 346. Refactor deck library from .context/ to founder extension
- **Effort**: 3-4 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-04-01
- **Research Completed**: 2026-04-01
- **Language**: meta
- **Dependencies**: 345
- **Research**: [01_team-research.md](346_refactor_deck_library_to_founder_extension/reports/01_team-research.md)
- **Plan**: [01_deck-library-refactor.md](346_refactor_deck_library_to_founder_extension/plans/01_deck-library-refactor.md)
- **Summary**: [01_deck-library-refactor-summary.md](346_refactor_deck_library_to_founder_extension/summaries/01_deck-library-refactor-summary.md)

**Description**: Move the reusable deck library from `.context/deck/` (repo-local, not loaded by extension loader) to `.claude/extensions/founder/context/project/founder/deck/` so that `/deck` functionality works in any repo where the founder extension is loaded. The library contains 53 general-purpose files: 5 themes, 5 patterns, 6 animations, 9 styles, 22 content templates, 4 Vue components, and index.json. All are general founder deck resources with no repo-specific content. Refactor requires: (1) move all `.context/deck/` files to the extension path, (2) update all path references in deck-planner-agent.md, deck-builder-agent.md, and deck.md command from `.context/deck/` to the new extension path, (3) update the founder extension's context index entries in `.claude/context/index.json` to include the deck library files, (4) update the library write-back paths in deck-builder-agent so new content generated at runtime gets written back to the extension location, (5) remove or gitignore the now-empty `.context/deck/` directory, (6) verify index.json queries still resolve correctly for pattern/theme/content selection workflow.

---

### 345. Port /deck command-skill-agent from Typst to Slidev
- **Effort**: 6 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-31
- **Research Completed**: 2026-04-01
- **Planning Started**: 2026-04-01
- **Planning Completed**: 2026-04-01
- **Implementation Started**: 2026-04-01
- **Implementation Completed**: 2026-04-01
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
- **Summary**: [02_slidev-system-summary.md](345_port_deck_typst_to_slidev/summaries/02_slidev-system-summary.md)

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
