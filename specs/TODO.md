---
next_project_number: 297
---

# TODO

## Task Order

*Updated 2026-03-25. 22 active tasks remaining.*

**Goal**: Post-refactor cleanup — fix stale references, extension-dependent paths, and documentation gaps from tasks 286-292.

### 1. Post-Refactor Cleanup (Tasks 293-296)

- **293** [COMPLETED] -- Fix stale context/core/ references in docs
- **294** [COMPLETED] -- Fix extension-dependent @-references in root CLAUDE.md and code-reviewer agent
- **295** [COMPLETED] -- Fix .memory/README.md OpenCode references
  - **Plan**: [02_memory-readme.md](specs/295_fix_memory_readme_opencode/plans/02_memory-readme.md)
- **296** [COMPLETED] -- Verify index.json domain/subdomain field semantics

### 2. Context System Refactor (Tasks 286-292) — Completed

- **286** [COMPLETED] -- Create .context/ directory for user project conventions (depends on nothing)
- **287** [COMPLETED] -- Reassign project context files to correct owners (depends on #286)
- **288** [COMPLETED] -- Flatten .claude/context/ structure (depends on #287)
- **289** [COMPLETED] -- Scope extension loader and project context boundaries (depends on #288)
- **290** [COMPLETED] -- Update context discovery for three-layer architecture (depends on #288, #289)
- **291** [COMPLETED] -- Update CLAUDE.md and agent references for new paths (depends on #290)
- **292** [COMPLETED] -- Document role boundaries for .context/, .memory/, extensions, auto-memory (depends on #291)

### 2. Previously Completed

- **281** [COMPLETED] -- Scope unscoped rules (add paths: frontmatter, deduplicate)
- **282** [COMPLETED] -- Slim nvim/CLAUDE.md (move reference material to context)
- **283** [COMPLETED] -- Create EXTENSION.md slim-down standard
- **284** [COMPLETED] -- Migrate large extensions to slim pattern (depends on #283)
- **285** [COMPLETED] -- Slim parent CLAUDE.md (convert to pointer file)
- **277** [COMPLETED] -- Research PDF annotation extraction tools
- **278** [COMPLETED] -- Create scrape-agent for PDF annotation extraction (depends on #277)
- **279** [COMPLETED] -- Create skill-scrape and /scrape command (depends on #278)
- **280** [COMPLETED] -- Update filetypes extension manifest and docs (depends on #279)

### 3. Pending

- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 286. Create .context/ directory for user project conventions
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_meta-research.md](286_create_context_directory_structure/reports/01_meta-research.md)

**Description**: Create a lightweight `.context/` directory at project root with `index.json` schema. This directory starts empty and is for user-defined project conventions only — not for files migrated from `.claude/context/project/` (those belong to core or extensions). Loaded alongside `.memory/` as independent systems for project knowledge.

---

### 287. Reassign project context files to correct owners
- **Effort**: 2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #286
- **Research**: [01_meta-research.md](287_migrate_project_context_files/reports/01_meta-research.md)

**Description**: Audit showed all 17 files in `.claude/context/project/` belong to either core or extensions — none are true project conventions. Move 12 core files (meta/, processes/, repo/) up to `.claude/context/` peers. Move 5 neovim files (standards + hooks) to the nvim extension's context directory. Nothing migrates to `.context/`.

---

### 288. Flatten .claude/context/ structure
- **Effort**: 2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #287
- **Research**: [01_meta-research.md](288_flatten_claude_context_structure/reports/01_meta-research.md)

**Description**: After task 287 empties `project/` and promotes core files, flatten by moving contents of `core/` to root level. Remove empty `core/` and `project/` directories. Update all paths in index.json and @-references.

---

### 289. Scope extension loader and project context boundaries
- **Effort**: 3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #288
- **Research**: [01_meta-research.md](289_update_extension_loader/reports/01_meta-research.md)

**Description**: Verify extension loader correctly copies core + extension context to `.claude/context/` and does not touch `.context/`. Document the three-layer architecture: agent context (loader-managed), project context (user-managed via `.context/index.json`), and project memory (`.memory/`, independent, loaded in parallel).

---

### 290. Update context discovery for three-layer architecture
- **Effort**: 2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #288, Task #289
- **Research**: [01_meta-research.md](290_update_context_discovery_patterns/reports/01_meta-research.md)

**Description**: Update jq query patterns for three-layer discovery: `.claude/context/index.json` (agent context, includes extensions merged by loader), `.context/index.json` (user project conventions, may be empty), and `.memory/` (loaded in parallel, independent). Extension context is merged into the main index by the loader, so no separate extension query needed.

---

### 291. Update CLAUDE.md and agent references for new paths
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #290
- **Research**: [01_meta-research.md](291_update_claudemd_references/reports/01_meta-research.md)

**Description**: Search-and-replace all `@.claude/context/core/` and `@.claude/context/project/` references. Core paths drop the `core/` prefix (flattened). Neovim standards now come from the nvim extension. Meta/processes/repo paths drop the `project/` prefix (promoted to core).

---

### 292. Document role boundaries for .context/, .memory/, extensions, auto-memory
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #291
- **Research**: [01_meta-research.md](292_document_role_boundaries/reports/01_meta-research.md)

**Description**: Create documentation defining the four-layer context architecture: extensions own domain-specific knowledge (nvim standards, lean4 patterns), `.claude/context/` holds core agent system patterns, `.context/` is for user project conventions not covered by extensions, `.memory/` stores learned facts (independent, loaded in parallel with `.context/`), and Claude auto-memory handles small behavioral gaps. Include decision tree.

---

### 293. Fix stale context/core/ references in docs
- **Effort**: 15 minutes
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_stale-doc-refs.md](293_fix_stale_doc_references/reports/01_stale-doc-refs.md)
- **Plan**: [02_stale-doc-refs.md](293_fix_stale_doc_references/plans/02_stale-doc-refs.md)

**Description**: Fix 3 remaining stale `context/core` references in `.claude/docs/guides/context-loading-best-practices.md` (lines 772, 826, 854). These are bash commands in diagnostic examples that still use the old path before the task 288 flatten.

---

### 294. Fix extension-dependent @-references in root CLAUDE.md and code-reviewer agent
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_extension-refs.md](294_fix_extension_dependent_refs/reports/01_extension-refs.md)
- **Plan**: [02_extension-refs.md](294_fix_extension_dependent_refs/plans/02_extension-refs.md)

**Description**: Fixed 8 extension-dependent references (4 in CLAUDE.md, 4 in code-reviewer-agent.md) by pointing to canonical extension source paths instead of loader-copied paths that only exist when extensions are loaded.

---

### 295. Fix .memory/README.md OpenCode references
- **Effort**: 15 minutes
- **Status**: [RESEARCHED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_memory-readme.md](295_fix_memory_readme_opencode/reports/01_memory-readme.md)

**Description**: Replace 7 "OpenCode" and `.opencode/` references in `.memory/README.md` with "Claude Code" and correct paths. The file was created from an OpenCode template and never adapted.

---

### 296. Verify index.json domain/subdomain field semantics
- **Effort**: 30 minutes
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_index-domains.md](296_fix_index_domain_semantics/reports/01_index-domains.md)
- **Plan**: [02_index-domains.md](296_fix_index_domain_semantics/plans/02_index-domains.md)

**Description**: After task 287 promoted meta/, processes/, repo/ from `project/` to core level, their index.json entries all have `"domain": "core"`. Verify subdomain fields are set correctly. May be a no-op if subdomains already distinguish these files.

---

### 281. Scope unscoped rules
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_meta-research.md](281_scope_unscoped_rules/reports/01_meta-research.md)
- **Plan**: [01_scope-rules-plan.md](281_scope_unscoped_rules/plans/01_scope-rules-plan.md)

**Description**: Add `paths:` frontmatter to `git-workflow.md` and `neovim-lua.md` in `~/.config/.claude/rules/` so they only load on relevant files. Deduplicate `git-workflow.md` which exists in near-identical form in both `~/.config/.claude/rules/` and `~/.config/nvim/.claude/rules/`. Saves ~310 lines of context per file touch in non-matching projects.

---

### 282. Slim nvim/CLAUDE.md
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_meta-research.md](282_slim_nvim_claudemd/reports/01_meta-research.md)
- **Plan**: [01_slim-claudemd-plan.md](282_slim_nvim_claudemd/plans/01_slim-claudemd-plan.md)

**Description**: Move reference material from `nvim/CLAUDE.md` (224 lines) to on-demand context files: box-drawing guide (52 lines), emoji policy (32 lines), documentation policy template (38 lines), Lua assertion patterns (39 lines). Keeps essential coding standards, commands, and project organization. Target: ~85 lines.

---

### 283. Create EXTENSION.md slim-down standard
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_meta-research.md](283_extension_slim_standard/reports/01_meta-research.md)
- **Implementation**: [extension-slim-standard.md](../.claude/docs/reference/standards/extension-slim-standard.md)

**Description**: Create authoring standard limiting EXTENSION.md to ~50-60 lines of essential routing info (language routing table, command list, context pointers). Detailed docs, examples, and migration guides move to context files loaded on-demand via index.json. Foundation for Task #284.

---

### 284. Migrate large extensions to slim pattern
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #283
- **Research**: [01_meta-research.md](284_migrate_large_extensions/reports/01_meta-research.md)
- **Plan**: [01_migrate-extensions-plan.md](284_migrate_large_extensions/plans/01_migrate-extensions-plan.md)

**Description**: Apply slim-down pattern to 5 largest EXTENSION.md files: founder (234->50), present (216->50), filetypes (143->50), memory (91->40), web (80->40). Move documentation to context files, update index-entries.json, verify extension loading. Target: ~534 lines saved.

---

### 285. Slim parent CLAUDE.md
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_meta-research.md](285_slim_parent_claudemd/reports/01_meta-research.md)
- **Plan**: [01_slim-parent-plan.md](285_slim_parent_claudemd/plans/01_slim-parent-plan.md)

**Description**: Convert `~/.config/CLAUDE.md` (224 lines) to a slim pointer file (~15-20 lines), matching the pattern of `~/.config/.claude/CLAUDE.md`. Move agent-system standards sections to `.claude/CLAUDE.md` where they belong. Saves ~200 lines from cross-project context loading.

---

### 277. Research PDF annotation extraction tools
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_meta-research.md](277_research_pdf_annotation_tools/reports/01_meta-research.md)

**Description**: Research and compare PDF annotation extraction tools (pdfannots vs PyMuPDF/fitz, pdfplumber, poppler-utils) to determine the best primary and fallback tools for the scrape-agent. Evaluate annotation type coverage, output formats, performance, and NixOS availability. Current implementation uses pdfannots in after/ftplugin/tex.lua.

---

### 278. Create scrape-agent for PDF annotation extraction
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #277
- **Research**: [01_meta-research.md](278_create_scrape_agent/reports/01_meta-research.md)
- **Plan**: [01_scrape-agent-plan.md](278_create_scrape_agent/plans/01_scrape-agent-plan.md)

**Description**: Create scrape-agent.md in .claude/extensions/filetypes/agents/ following the document-agent.md pattern. Agent should detect available annotation extraction tools with fallback chain, support multiple output formats (markdown, JSON), handle annotation type filtering, and return structured JSON matching subagent-return.md schema.

---

### 279. Create skill-scrape and /scrape command
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #278
- **Research**: [01_meta-research.md](279_create_skill_scrape_command/reports/01_meta-research.md)
- **Plan**: [01_skill-scrape-plan.md](279_create_skill_scrape_command/plans/01_skill-scrape-plan.md)

**Description**: Create skill-scrape/SKILL.md (thin wrapper with Task tool invocation) and scrape.md command (checkpoint-based execution with GATE IN/DELEGATE/GATE OUT/COMMIT) following existing convert.md and skill-filetypes patterns. Support PDF path argument, output path inference to Annotations/ directory, and format selection based on output extension.

---

### 280. Update filetypes extension manifest and documentation
- **Effort**: 30 minutes
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #279
- **Research**: [01_meta-research.md](280_update_filetypes_extension_manifest/reports/01_meta-research.md)
- **Plan**: [01_manifest-update-plan.md](280_update_filetypes_extension_manifest/plans/01_manifest-update-plan.md)

**Description**: Register scrape-agent, skill-scrape, and scrape.md in manifest.json. Update EXTENSION.md with /scrape command documentation. Add context index entries to index-entries.json. Update filetypes-router-agent to dispatch annotation extraction requests to scrape-agent.

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
