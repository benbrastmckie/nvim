---
next_project_number: 307
---

# TODO

## Task Order

*Updated 2026-03-26. 12 active tasks remaining.*

### Pending

- **306** [PLANNED] -- Persist core context index entries across reloads (depends on 301)
- **305** [COMPLETED] -- Persist metadata in extension source index-entries.json files (depends on 303)
- **304** [COMPLETED] -- Fix malformed @-references in extension rule source files
- **303** [COMPLETED] -- Fix filetypes extension source index-entries.json (verified no-op)
- **301** [RESEARCHED] -- Fix extension loader orphaned index entry cleanup (root cause)
- **302** [COMPLETED] -- Clean orphaned index entries from Website index.json
- **298** [COMPLETED] -- Add missing domain/subdomain metadata to index.json entries
- **299** [COMPLETED] -- Index 75 unindexed context files (depends on 298)
- **300** [COMPLETED] -- Add missing summaries to index.json entries (depends on 298)
- **297** [COMPLETED] -- Remove duplicate pitch-deck index entries
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 306. Persist core context index entries across reloads
- **Effort**: 2-3 hours
- **Status**: [PLANNED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Language**: neovim
- **Dependencies**: 301
- **Research**: [01_persist-core-entries.md](306_persist_core_index_entries/reports/01_persist-core-entries.md)
- **Plan**: [02_persist-core-entries.md](306_persist_core_index_entries/plans/02_persist-core-entries.md)

**Description**: Create a `core-index-entries.json` file in `.claude/context/` containing all ~90 core context entries (orchestration, standards, patterns, formats, templates, etc.) and modify the extension loader to always include it during index.json rebuilds. Task 299 added 75 core entries to the Website OUTPUT index.json, but the loader rebuilds from extension sources only, discarding core entries on reload. The recommended fix adds ~10 lines to the loader to load core entries before extension entries.

---

### 305. Persist metadata in extension source index-entries.json files
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Completed**: 2026-03-26
- **Language**: meta
- **Dependencies**: 303
- **Research**: [01_persist-metadata.md](305_persist_extension_metadata/reports/01_persist-metadata.md)
- **Plan**: [02_persist-metadata.md](305_persist_extension_metadata/plans/02_persist-metadata.md)

**Description**: Add missing `domain`, `subdomain`, and `summary` metadata to 11 extension source `index-entries.json` files (186 entries need domain/subdomain, 119 need summaries, 232 total entries across 14 extensions). Tasks 298 and 300 added this metadata to the output `index.json`, but the extension loader rebuilds from source on every reload, discarding the improvements. Fixing the source files ensures metadata persists. Domain is always `"project"`, subdomain is derived from the second path component (lean4 -> `"lean"`). Summaries follow noun-phrase style, 27-112 chars.

---

### 304. Fix malformed @-references in extension rule source files
- **Effort**: 30 minutes
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Completed**: 2026-03-26
- **Language**: meta
- **Dependencies**: None
- **Artifacts**:
  - **Research**: [01_rule-source-refs.md](304_fix_rule_source_refs/reports/01_rule-source-refs.md)
  - **Plan**: [02_rule-source-refs.md](304_fix_rule_source_refs/plans/02_rule-source-refs.md)

**Description**: Fix 13 malformed @-references in 2 extension rule source files. `nix.md` (8 refs) and `web-astro.md` (5 refs) use `@.claude/extensions/{ext}/context/project/...` but should use `@.claude/context/project/...` (the installed path after extension loader copies context files). The 3 refs in `neovim-lua.md` already use the correct pattern.

**Completion**: Fixed 13 @-references in 2 files: nix.md (8 refs) and web-astro.md (5 refs). Replaced `extensions/{ext}/context/` prefix with `context/` to point to installed paths.

---

### 303. Fix filetypes extension source index-entries.json
- **Effort**: 10 minutes
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Completed**: 2026-03-26
- **Language**: meta
- **Dependencies**: None
- **Artifacts**:
  - **Research**: [01_filetypes-index-source.md](303_fix_filetypes_index_source/reports/01_filetypes-index-source.md)
  - **Plan**: [02_filetypes-index-source.md](303_fix_filetypes_index_source/plans/02_filetypes-index-source.md)

**Description**: Verify and fix pitch-deck duplicate entries in filetypes extension source `index-entries.json`. Task 297 removed 2 duplicate pitch-deck entries from the output `index.json`, but the source file at `.claude/extensions/filetypes/index-entries.json` was suspected of still containing them. Research found the source file is already clean (no pitch-deck entries). The orphaned entries in the output `index.json` persist from direct additions, not from the source file. Covered by task 302.

**Completion**: Verified no-op. The filetypes source index-entries.json contains 7 entries with zero pitch-deck references. No changes needed.

---

### 301. Fix extension loader orphaned index entry cleanup
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Completed**: 2026-03-27
- **Language**: neovim
- **Dependencies**: None
- **Artifacts**:
  - **Research**: [01_loader-orphan-cleanup.md](301_fix_loader_orphan_cleanup/reports/01_loader-orphan-cleanup.md)
  - **Plan**: [02_loader-orphan-cleanup.md](301_fix_loader_orphan_cleanup/plans/02_loader-orphan-cleanup.md)

**Description**: Fix the extension loader (`lua/neotex/plugins/ai/shared/extensions/merge.lua`) to clean orphaned `index.json` entries during sparse extension reloads. The loader tracks entries added at load time but not entries added by external processes (e.g., tasks enriching metadata). On unload, only tracked entries are removed, leaving behind orphans. Fix: add path-prefix-based cleanup using `provides.context` from the extension manifest to remove all entries under an extension's owned prefix during unload.

**Completion**: Added `remove_index_entries_by_prefix()` to merge.lua and integrated it into the unload flow in init.lua. After tracked entry removal, the loader now scans remaining entries and removes any whose path matches the unloaded extension's `provides.context` prefixes.

---

### 302. Clean orphaned index entries from Website index.json
- **Effort**: 15 minutes
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Completed**: 2026-03-26
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_website-index-orphans.md](302_clean_website_index_orphans/reports/01_website-index-orphans.md)
- **Plan**: [02_website-index-orphans.md](302_clean_website_index_orphans/plans/02_website-index-orphans.md)

**Description**: Removed 2 orphaned pitch-deck entries from Website `.claude/context/index.json` (256 -> 254 entries). The 24 lean4 orphans from the original research had already been removed by prior tasks. Zero orphans remain.

---

### 299. Index 75 unindexed context files
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Completed**: 2026-03-26
- **Language**: meta
- **Dependencies**: 298
- **Artifacts**:
  - **Research**: [01_unindexed-context.md](299_index_unindexed_context/reports/01_unindexed-context.md)
  - **Plan**: [02_unindexed-context.md](299_index_unindexed_context/plans/02_unindexed-context.md)

**Description**: Add index.json entries for 75 context files that exist on disk under Website `.claude/context/` but have no corresponding entry in `index.json`. All 75 are core agent system files (orchestration, standards, patterns, formats, templates, workflows, etc.) -- not extension-specific content. They function via `@`-imports but are invisible to programmatic context discovery queries. Depends on task 298 (metadata conventions) to ensure consistent domain/subdomain assignment.

**Completion**: Added 75 new entries to index.json (254 -> 329). All entries use domain="core", subdomain from directory name, summary=null, empty keywords/topics/load_when. Zero unindexed .md files remain.

---

### 298. Add missing domain/subdomain metadata to index.json entries
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Language**: meta
- **Dependencies**: None
- **Artifacts**:
  - **Research**: [01_index-metadata.md](298_add_index_metadata/reports/01_index-metadata.md)
  - **Plan**: [02_index-metadata.md](298_add_index_metadata/plans/02_index-metadata.md)

**Description**: Add missing `domain` and `subdomain` metadata to 134 entries in the Website project's `.claude/context/index.json`. All 134 entries are under the `project/` path prefix and can be assigned `domain="project"` with `subdomain` derived from the second path component (e.g., `typst`, `logic`, `founder`, `math`, `nix`, `latex`, `python`, `memory`, `z3`, `physics`, `lean4`, `filetypes`, `web`). Many entries also lack `summary`, `keywords`, and `topics` fields, which could be addressed in a follow-up task (300).

---

### 300. Add missing summaries to index.json entries
- **Effort**: 30-45 minutes
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Planning Started**: 2026-03-26
- **Planning Completed**: 2026-03-26
- **Completed**: 2026-03-26
- **Language**: meta
- **Dependencies**: 298
- **Artifacts**:
  - **Research**: [01_index-summaries.md](300_add_index_summaries/reports/01_index-summaries.md)
  - **Plan**: [02_index-summaries.md](300_add_index_summaries/plans/02_index-summaries.md)

**Description**: Add missing `summary` fields to 67 index.json entries in the Website `.claude/context/` directory. All missing entries are in the `project/` subtree (extension context), primarily in typst (24), nix (11), and latex (10) domains. Summaries are not used in routing logic but aid agent context discovery. Depends on task 298 to establish metadata conventions first.

**Completion**: Added summaries to 69 project/ entries (67 original + 2 added by task 299). All follow noun-phrase style, 27-112 chars, no trailing period. Zero null summaries remain in project/ entries.

---

### 297. Remove duplicate pitch-deck index entries
- **Effort**: 30 minutes
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Planning Started**: 2026-03-26
- **Planning Completed**: 2026-03-26
- **Language**: meta
- **Dependencies**: None
- **Artifacts**:
  - **Research**: [01_pitch-deck-context.md](297_create_pitch_deck_context/reports/01_pitch-deck-context.md)
  - **Plan**: [02_pitch-deck-context.md](297_create_pitch_deck_context/plans/02_pitch-deck-context.md)

**Description**: Remove 2 duplicate pitch-deck index entries from Website `.claude/context/index.json` that reference non-existent files in the `filetypes` subdomain. The correct entries already exist in the `present` subdomain with richer metadata (keywords, topics, languages, commands).

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
