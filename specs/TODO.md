---
next_project_number: 477
---

# TODO

## Task Order

*Updated 2026-04-17. 3 active tasks remaining.*

### Pending

- **476** [RESEARCHED] -- Consolidate extension system documentation into single source of truth
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 476. Consolidate extension system documentation into single source of truth
- **Effort**: Medium
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Research**: [476_consolidate_extension_system_docs/reports/01_consolidate-ext-docs.md]

**Description**: Consolidate extension system documentation into a single source of truth to eliminate contradictions between `docs/architecture/extension-system.md`, `context/guides/extension-development.md`, and `docs/guides/creating-extensions.md`. The files have drifted out of sync -- some describe CLAUDE.md as a computed artifact via `generate_claudemd()` while others regress to the old section-injection approach. Additional inconsistencies exist in conflict handling behavior, `provides` field coverage, loader function documentation, and validator expectations vs actual index.json schema.

Scope: (1) Audit the Lua loader implementation for ground truth, (2) designate `docs/architecture/extension-system.md` as the comprehensive reference with other files cross-referencing rather than restating, (3) eliminate content duplication so each concept is documented in exactly one place, (4) fix all contradictions to reflect actual implementation, (5) align `validate-context-index.sh` with actual index.json schema, (6) integrate untracked `loader-reference.md` and `index.schema.json`, (7) clean up stale references.

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
