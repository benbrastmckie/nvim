---
next_project_number: 301
---

# TODO

## Task Order

*Updated 2026-03-26. 6 active tasks remaining.*

### Pending

- **298** [RESEARCHED] -- Add missing domain/subdomain metadata to index.json entries
- **299** [RESEARCHED] -- Index 75 unindexed context files (depends on 298)
- **300** [RESEARCHED] -- Add missing summaries to index.json entries (depends on 298)
- **297** [RESEARCHED] -- Create missing pitch-deck context files
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 299. Index 75 unindexed context files
- **Effort**: 1-2 hours
- **Status**: [RESEARCHED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Language**: meta
- **Dependencies**: 298
- **Research**: [01_unindexed-context.md](299_index_unindexed_context/reports/01_unindexed-context.md)

**Description**: Add index.json entries for 75 context files that exist on disk under Website `.claude/context/` but have no corresponding entry in `index.json`. All 75 are core agent system files (orchestration, standards, patterns, formats, templates, workflows, etc.) -- not extension-specific content. They function via `@`-imports but are invisible to programmatic context discovery queries. Depends on task 298 (metadata conventions) to ensure consistent domain/subdomain assignment.

---

### 298. Add missing domain/subdomain metadata to index.json entries
- **Effort**: 1-2 hours
- **Status**: [RESEARCHED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_index-metadata.md](298_add_index_metadata/reports/01_index-metadata.md)

**Description**: Add missing `domain` and `subdomain` metadata to 134 entries in the Website project's `.claude/context/index.json`. All 134 entries are under the `project/` path prefix and can be assigned `domain="project"` with `subdomain` derived from the second path component (e.g., `typst`, `logic`, `founder`, `math`, `nix`, `latex`, `python`, `memory`, `z3`, `physics`, `lean4`, `filetypes`, `web`). Many entries also lack `summary`, `keywords`, and `topics` fields, which could be addressed in a follow-up task (300).

---

### 300. Add missing summaries to index.json entries
- **Effort**: 30-45 minutes
- **Status**: [RESEARCHED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Language**: meta
- **Dependencies**: 298
- **Research**: [01_index-summaries.md](300_add_index_summaries/reports/01_index-summaries.md)

**Description**: Add missing `summary` fields to 67 index.json entries in the Website `.claude/context/` directory. All missing entries are in the `project/` subtree (extension context), primarily in typst (24), nix (11), and latex (10) domains. Summaries are not used in routing logic but aid agent context discovery. Depends on task 298 to establish metadata conventions first.

---

### 297. Create missing pitch-deck context files
- **Effort**: 30 minutes
- **Status**: [RESEARCHED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_pitch-deck-context.md](297_create_pitch_deck_context/reports/01_pitch-deck-context.md)

**Description**: Create 2 missing pitch-deck context files referenced in Website `.claude/context/index.json`. The files `pitch-deck-structure.md` and `touying-pitch-deck-template.md` exist in the `present` subdomain but are also referenced (and missing) in the `filetypes` subdomain. Research recommends removing the duplicate index entries rather than creating duplicate files.

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
