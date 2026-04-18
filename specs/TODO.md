---
next_project_number: 480
---

# TODO

## Task Order

*Updated 2026-04-17. 3 active tasks remaining.*

### Pending

- **476** [COMPLETED] -- Consolidate extension system documentation into single source of truth
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 479. Fix remaining nvim-specific references in core extension sources
- **Effort**: Small
- **Status**: [PLANNED]
- **Task Type**: meta
- **Research**: [specs/479_fix_remaining_nvim_refs_in_core_ext/reports/01_nvim-refs-audit.md]
- **Plan**: [479_fix_remaining_nvim_refs_in_core_ext/plans/01_fix-nvim-refs.md]

**Description**: Fix remaining nvim/neotex references in core extension source files that were missed by task 478 and cause re-contamination on reload: (1) Replace "neotex extension loader" with "extension loader" in templates/claudemd-header.md, (2) Replace "Neovim Lua loader" with "extension loader" in context/guides/extension-development.md, (3) Replace "neovim" in extension example lists in context/architecture/system-overview.md, docs/architecture/system-overview.md, and merge-sources/claudemd.md with generic alternatives, (4) Fix meta-guide.md bug where ".claude/docs/README.md" was changed to duplicate ".claude/README.md, .claude/README.md", (5) Mirror all source changes to deployed copies. Root cause identified in zed post-reload audit report.

### 478. Make extension core docs editor-agnostic and handle project-overview.md per-project generation
- **Effort**: Small
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [specs/478_editor_agnostic_extension_docs/reports/01_team-research.md]
- **Plan**: [478_editor_agnostic_extension_docs/plans/01_editor-agnostic-docs.md]
- **Summary**: [478_editor_agnostic_extension_docs/summaries/01_editor-agnostic-docs-summary.md]

**Description**: Two related changes to prevent nvim-specific contamination when extension core files are synced to other projects: (1) Replace hardcoded `<leader>ac` references with generic "extension picker" language in `extensions/core/` docs (extension-development.md, loader-reference.md, extension-readme-template.md), following the multi-editor pattern already used in extensions/README.md. (2) Exclude project-overview.md from the core extension loader sync -- it describes this repo's specific structure and should not propagate to downstream projects. Instead, provide a stub/template (e.g., update-project.md) that detects when project-overview.md is missing and instructs Claude to suggest generating one based on analysis of the actual project structure. (3) Update deployed copies in `.claude/context/` to match. Existing project-overview.md in this nvim repo remains unchanged.

### 477. Fix generated CLAUDE.md duplicate header, restore README.md, and improve generation
- **Effort**: Medium
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [477_fix_generated_claudemd_and_restore_readme/reports/01_fix-claudemd-generation.md]
- **Plan**: [477_fix_generated_claudemd_and_restore_readme/plans/01_fix-claudemd-generation.md]
- **Summary**: [477_fix_generated_claudemd_and_restore_readme/summaries/01_fix-claudemd-generation-summary.md]

**Description**: Fix the generated `.claude/CLAUDE.md` file which has a duplicate header (lines 1-10). Restore the missing `.claude/README.md` from git history and update it for accuracy. Add a reference to the root `README.md` in the generated CLAUDE.md. Review the generated CLAUDE.md for additional improvements to how the file is produced.

### 476. Consolidate extension system documentation into single source of truth
- **Effort**: Medium
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [476_consolidate_extension_system_docs/reports/01_consolidate-ext-docs.md]
- **Plan**: [476_consolidate_extension_system_docs/plans/01_consolidate-ext-docs.md]
- **Summary**: [476_consolidate_extension_system_docs/summaries/01_consolidate-ext-docs-summary.md]

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

## Recommended Order

1. **479** -> research (independent)
