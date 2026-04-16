# Research Report: Task #433

**Task**: 433 - Move nvim-specific content from core .claude/ files to the neovim extension directory
**Started**: 2026-04-14T00:00:00Z
**Completed**: 2026-04-14T00:30:00Z
**Effort**: Medium (3-4 hours implementation)
**Dependencies**: Task 432 (sync hardening) - completed
**Sources/Inputs**:
- Codebase scan of `.claude/context/` (42 files matched neovim-related patterns)
- Codebase scan of `.claude/rules/` (1 file with incidental mention)
- Review of `.claude/extensions/nvim/` (31 files, well-structured)
- Review of `CLAUDE.md` files at root, `.claude/`, and `nvim/` levels
- Review of `specs/ROADMAP.md`
**Artifacts**:
- `specs/433_move_nvim_specific_content_to_neovim_extension/reports/01_extension-restructuring.md`
**Standards**: report-format.md, artifact-formats.md

## Executive Summary

- 42 core context files contain neovim-related references; however, most are **incidental examples** in otherwise generic documentation (routing examples using "neovim" as the sample task type)
- **3 files are purely neovim-specific** and should be moved entirely: `repo/project-overview.md`, the Neovim sections of `processes/research-workflow.md`, and the Neovim domain pattern in `meta/domain-patterns.md`
- **~15 files contain neovim as example data** in routing tables, JSON examples, and log samples -- these should be generalized to use placeholder names rather than moved
- The existing neovim extension at `.claude/extensions/nvim/` is already well-organized with 20+ context files; the main gap is that core files duplicate or hardcode neovim-specific content that should live exclusively in the extension
- The `nvim/CLAUDE.md` file is entirely neovim-specific (expected, as it's the project-level config), but its cross-references to extension paths are correct
- A corruption artifact ("cneovim") exists in `error-handling.md` and `delegation.md` from a previous bad find-replace, which should be fixed as part of this cleanup

## Context & Scope

This research identifies all neovim/nvim-specific content in core `.claude/` files (excluding the extension directory itself) and categorizes it into actionable groups. The goal is to make core files truly generic so the agent system can be reused across projects without neovim assumptions baked into its documentation.

**Constraints**:
- Core files must remain functional after extraction -- routing examples need replacement content
- The `nvim/CLAUDE.md` file is intentionally project-specific and is out of scope
- Extension loader merges extension index entries into `index.json` at runtime, so extension-only content should use `index-entries.json` in the extension

## Findings

### Category 1: Purely Neovim-Specific Files (MOVE)

These files are entirely about the neovim project and should be moved to the extension or replaced with generic templates.

| File | Lines | Neovim Hits | Action |
|------|-------|-------------|--------|
| `context/repo/project-overview.md` | 145 | 42 | **Move to extension** or replace with generic template |

**`repo/project-overview.md`** is 100% neovim-specific: describes lua/lazy.nvim/treesitter stack, nvim directory structure, plugin management, and verification commands using `nvim --headless`. This file should be replaced with a generic template that says "See extension context for project details" or moved entirely. The extension already has `project/neovim/README.md` which overlaps significantly.

### Category 2: Files with Neovim-Specific Sections (EXTRACT)

These files contain a mix of generic patterns and neovim-specific sections that should be extracted.

| File | Lines | Neovim Hits | Neovim Section |
|------|-------|-------------|----------------|
| `processes/research-workflow.md` | ~600 | 15 | "Neovim Research" section (lines 26-29), "Neovim-Specific Research Tools" section (lines 553+) |
| `meta/domain-patterns.md` | ~200 | 11 | "Neovim Configuration Domain Pattern" section (lines 133+) |
| `standards/error-handling.md` | ~1050 | 17 | Neovim MCP server error example (lines 506-524), "cneovim" corruption throughout |
| `processes/implementation-workflow.md` | ~180 | 2 | Neovim row in routing table, file path pattern |

### Category 3: Files Using Neovim as Example Data (GENERALIZE)

These files use "neovim" as the primary (often only) example in routing tables, JSON samples, and log output. The content is generic in nature but uses neovim-specific values as illustration.

| File | Neovim Hits | Nature of References |
|------|-------------|---------------------|
| `orchestration/routing.md` (DEPRECATED) | 45 | Routing validation examples, routing tables, troubleshooting |
| `formats/return-metadata-file.md` | 24 | JSON examples with neovim-research-agent, nvim/lua paths |
| `guides/extension-development.md` | 15 | Neovim extension as the worked example throughout |
| `architecture/system-overview.md` | 11 | Routing flow diagram, skill mapping tables |
| `standards/task-management.md` | 15 | Task type detection rules, routing validation |
| `orchestration/delegation.md` | 9 | JSON examples with neovim agent names, file paths |
| `orchestration/orchestration-core.md` | 6 | Routing tables, validation code |
| `orchestration/orchestration-reference.md` | 5 | Log examples, troubleshooting |
| `orchestration/state-management.md` | 4 | JSON example, jq query |
| `formats/subagent-return.md` | 6 | JSON examples with neovim agents, lua file paths |
| `formats/frontmatter.md` | 6 | Agent frontmatter example, plugin reference |
| `formats/report-format.md` | 8 | Context gap example using telescope.nvim |
| `formats/command-output.md` | 2 | Minor references |

**Recommended approach for Category 3**: Replace neovim-specific example values with generic placeholders (e.g., `{extension}-research-agent`, `src/module.ext`) or use a different non-project-specific example domain. This is lower priority than Categories 1-2 because the generic patterns are correct; only the example data is project-specific.

### Category 4: Incidental Mentions (LEAVE or MINOR FIX)

These files mention "neovim" once or twice in task type enum lists or as one option among many. No action needed beyond ensuring the enum format is `"neovim|general|meta|..."` rather than treating neovim as special.

| File | Hits | Nature |
|------|------|--------|
| `routing.md` (top-level) | 1 | Single row in routing table -- correct, this is how extensions declare routes |
| `plan-format-enforcement.md` | 1 | Lists "neovim" in task type enum |
| `templates/command-template.md` | 2 | Minor |
| `patterns/checkpoint-execution.md` | 1 | Minor |
| `workflows/command-lifecycle.md` | 1 | Minor |
| `standards/documentation-standards.md` | 1 | Minor |
| Various others | 1-2 each | Incidental |

### Category 5: Corruption Artifacts (FIX)

Two files contain "cneovim" -- a corrupted string from a previous find-replace operation:

| File | Occurrences | Examples |
|------|-------------|---------|
| `standards/error-handling.md` | ~6 | "Cneovim untracked files", "cneovimup", "Resource cneovimup" |
| `orchestration/delegation.md` | 1 | "PostflightCneovimup" |
| `formats/return-metadata-file.md` | 2 | "Cneovimup", "booneovim" |

These appear to be remnants of a global find-replace where "clean" was replaced with something involving "neovim", or vice versa. The original text was likely "Clean untracked files", "Cleanup", "boolean", "PostflightCleanup".

### Existing Extension Coverage

The neovim extension at `.claude/extensions/nvim/` is already well-organized:

- **Agents**: 2 (neovim-research-agent, neovim-implementation-agent)
- **Skills**: 2 (skill-neovim-research, skill-neovim-implementation)
- **Context files**: 20 (domain knowledge, patterns, standards, templates, tools)
- **Rules**: 1 (neovim-lua.md)
- **Index entries**: 20 entries in `index-entries.json`

The extension properly uses `load_when.languages: ["neovim"]` and agent-based loading. No structural changes needed to the extension itself.

### CLAUDE.md Files Analysis

**`nvim/CLAUDE.md`** (project root): Entirely neovim-specific, which is correct -- this is the project-level config. It already cross-references extension paths correctly (e.g., `.claude/extensions/nvim/context/project/neovim/standards/documentation-policy.md`). No changes needed.

**`.claude/CLAUDE.md`**: Contains neovim references in:
- `task_type: "neovim"` in state.json example -- acceptable as example data
- Extension loading references (`<leader>ac` in Neovim) -- this is a keybinding reference, should be generalized
- Routing table mentioning neovim extension -- acceptable, describes available extensions

## Decisions

1. **`repo/project-overview.md` must be replaced** with a generic template. The current file is entirely project-specific. A generic version should describe the task management structure (specs/, .claude/) and say "See project-specific documentation for codebase details."
2. **Neovim-specific sections should be extracted** from `research-workflow.md`, `domain-patterns.md`, and `error-handling.md` into extension context files or removed.
3. **Example data generalization is lower priority** -- the routing tables and JSON examples using "neovim" as the example task type are illustrative rather than prescriptive. They should be generalized eventually but are not blocking correctness.
4. **Corruption artifacts must be fixed** regardless of other changes -- "cneovim" strings are bugs.
5. **The deprecated `orchestration/routing.md` should be deleted** -- it's 778 lines of deprecated content that duplicates `orchestration-core.md` and `orchestration-reference.md`, and is the single largest source of neovim references in core files.

## Recommendations

### Phase 1: Critical Fixes (High Priority)

1. **Fix corruption artifacts** in `error-handling.md`, `delegation.md`, and `return-metadata-file.md`:
   - "Cneovim" -> "Clean"
   - "cneovimup" -> "cleanup"
   - "booneovim" -> "boolean"
   - "PostflightCneovimup" -> "PostflightCleanup"

2. **Delete deprecated `orchestration/routing.md`** (778 lines) -- it's already marked deprecated and superseded by `orchestration-core.md` + `orchestration-reference.md`. Remove its entry from `index.json`.

3. **Replace `repo/project-overview.md`** with a generic template:
   - Keep: specs/ and .claude/ directory structure description
   - Remove: all lua/nvim/treesitter/lazy.nvim content
   - Add: "Project-specific details are provided by loaded extensions"
   - Optionally move current content to extension as `project/neovim/project-structure.md`

### Phase 2: Section Extraction (Medium Priority)

4. **Extract neovim sections from `processes/research-workflow.md`**:
   - Move "Neovim Research" routing section and "Neovim-Specific Research Tools" section to extension
   - Replace with generic extension routing pattern

5. **Extract neovim domain pattern from `meta/domain-patterns.md`**:
   - The "Neovim Configuration Domain Pattern" section is a template example -- either move to extension or replace with a generic "{Extension} Domain Pattern" template

6. **Clean neovim examples from `standards/error-handling.md`**:
   - Replace neovim MCP server example with a generic MCP server example
   - Fix all "cneovim" corruption (covered in Phase 1)

### Phase 3: Example Generalization (Lower Priority)

7. **Generalize JSON examples** in format files (`return-metadata-file.md`, `subagent-return.md`, `frontmatter.md`, `delegation.md`):
   - Replace `neovim-research-agent` with `{extension}-research-agent` or use a neutral example
   - Replace `nvim/lua/plugins/lsp.lua` with `src/module.ext`

8. **Generalize routing tables** in orchestration files:
   - Use `{extension}` placeholder alongside concrete `general`, `meta`, `markdown` types
   - Keep one concrete extension example but note it comes from extension configuration

9. **Generalize `guides/extension-development.md`**:
   - This file appropriately uses neovim as its worked example -- consider adding a second example or noting that neovim is used as illustration only

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Removing routing examples breaks agent understanding | Medium | High | Replace with clearly marked placeholder examples, not deletion |
| Extension loader depends on specific core file paths | Low | Medium | Verify loader reads from `index-entries.json`, not core `index.json` paths |
| Over-generalization makes docs unhelpful | Medium | Medium | Keep one concrete example per pattern, mark as "example from nvim extension" |
| Corruption fix introduces new errors | Low | Medium | Use targeted replacements, verify with grep after |

## Appendix

### Search Methodology

1. Scanned all files in `.claude/context/` (excluding `extensions/`) with pattern: `neotex|neovim|nvim|treesitter|telescope|lazy\.nvim|mason|vim\.|vim\.keymap|vim\.api|ftplugin|busted|plenary`
2. Counted hits per file, examined top 15 files by hit count
3. Categorized each file's neovim content by type (pure, mixed, example, incidental, corrupt)
4. Reviewed extension structure and index entries for coverage gaps
5. Checked ROADMAP.md for alignment

### Files by Neovim Hit Count (Top 15)

| File | Hits | Category |
|------|------|----------|
| `orchestration/routing.md` | 45 | DEPRECATED - Delete |
| `repo/project-overview.md` | 42 | MOVE |
| `formats/return-metadata-file.md` | 24 | GENERALIZE + FIX corruption |
| `standards/error-handling.md` | 17 | EXTRACT + FIX corruption |
| `standards/task-management.md` | 15 | GENERALIZE |
| `guides/extension-development.md` | 15 | LEAVE (appropriate use as example) |
| `processes/research-workflow.md` | 15 | EXTRACT |
| `meta/domain-patterns.md` | 11 | EXTRACT |
| `architecture/system-overview.md` | 11 | GENERALIZE |
| `orchestration/delegation.md` | 9 | GENERALIZE + FIX corruption |
| `templates/thin-wrapper-skill.md` | 9 | GENERALIZE |
| `orchestration/orchestrator.md` | 9 | GENERALIZE |
| `formats/report-format.md` | 8 | GENERALIZE |
| `formats/frontmatter.md` | 6 | GENERALIZE |
| `orchestration/orchestration-core.md` | 6 | GENERALIZE |

### Estimated Implementation Effort

- Phase 1 (Critical Fixes): ~1 hour
- Phase 2 (Section Extraction): ~1.5 hours
- Phase 3 (Example Generalization): ~1.5 hours
- Total: ~4 hours
