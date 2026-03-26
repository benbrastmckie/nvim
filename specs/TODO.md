---
next_project_number: 286
---

# TODO

## Task Order

*Updated 2026-03-25. 11 active tasks remaining.*

**Goal**: Optimize context window usage and complete pending tasks.

### 1. Active Tasks

- **281** [COMPLETED] -- Scope unscoped rules (add paths: frontmatter, deduplicate)
- **282** [COMPLETED] -- Slim nvim/CLAUDE.md (move reference material to context)
- **283** [COMPLETED] -- Create EXTENSION.md slim-down standard
- **284** [COMPLETED] -- Migrate large extensions to slim pattern (depends on #283)
- **285** [COMPLETED] -- Slim parent CLAUDE.md (convert to pointer file)
- **277** [COMPLETED] -- Research PDF annotation extraction tools
- **278** [COMPLETED] -- Create scrape-agent for PDF annotation extraction (depends on #277)
- **279** [COMPLETED] -- Create skill-scrape and /scrape command (depends on #278)
- **280** [COMPLETED] -- Update filetypes extension manifest and docs (depends on #279)
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

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
