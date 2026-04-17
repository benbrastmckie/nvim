---
next_project_number: 465
---

# TODO

## Task Order

*Updated 2026-04-16. 2 active tasks remaining.*

### Pending

- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 464. Enable extension loading in global source repository without sync leakage
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Research**:
  - [01_team-research.md](464_enable_extensions_in_source_repo/reports/01_team-research.md)
  - [02_team-research.md](464_enable_extensions_in_source_repo/reports/02_team-research.md)

**Description**: Allow loading extensions (nvim/, memory/, etc.) in the global source repository (~/.config/nvim) so they function normally for development, without those extension artifacts becoming part of the core agent system that "Load Core Agent System" syncs to other repos. Currently a self-loading guard prevents any extension from being loaded in this repo. The desired behavior is that this repo is just another consumer of the extension system: it loads core + nvim + memory the same way any other repo loads core + its own extensions. The sync mechanism must ensure that only core artifacts propagate to other projects — no extension-injected content in CLAUDE.md sections, context/index.json entries, settings fragments, or discrete files (agents, skills, rules, context) should travel with the core sync. One possible direction is restructuring the core agent system as a base layer that every extension depends on, but the research phase should evaluate approaches before committing to an architecture.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Task Type**: neovim
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
- **Task Type**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](078_fix_himalaya_smtp_authentication_failure/reports/research-001.md)
- **Plan**: [implementation-001.md](078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md)

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: "Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted". The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.

## Recommended Order

1. **464** [RESEARCHED] -> plan (independent)
