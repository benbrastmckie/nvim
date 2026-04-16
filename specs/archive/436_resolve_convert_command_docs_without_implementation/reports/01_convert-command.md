# Research Report: Task #436

**Task**: 436 - resolve_convert_command_docs_without_implementation
**Started**: 2026-04-14T00:00:00Z
**Completed**: 2026-04-14T00:05:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.claude/commands/`, `.claude/extensions/filetypes/`
- Documentation: `docs/guides/user-guide.md`, `docs/reference/standards/extension-slim-standard.md`
- Extension manifest: `.claude/extensions/filetypes/manifest.json`
**Artifacts**:
- `specs/436_resolve_convert_command_docs_without_implementation/reports/01_convert-command.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The `/convert` command DOES exist -- it lives at `.claude/extensions/filetypes/commands/convert.md`, not in the core `.claude/commands/` directory
- The filetypes extension has full conversion infrastructure: agents (filetypes-router-agent, document-agent, presentation-agent), skills (skill-filetypes, skill-presentation), and context files (conversion-tables.md, dependency-guide.md, tool-detection.md)
- The documentation references in `user-guide.md` and `extension-slim-standard.md` are accurate descriptions of the command's capabilities
- The issue is that `/convert` is presented in user-guide.md alongside core commands without noting it requires the filetypes extension to be loaded
- Recommendation: **Keep and clarify** -- add an "(extension)" annotation in user-guide.md, do NOT remove documentation

## Context & Scope

Task 436 was created because `/convert` appeared documented in `docs/guides/user-guide.md` and `docs/reference/standards/extension-slim-standard.md` but `commands/convert.md` did not exist in the core commands directory. The question was whether to implement the command or remove the documentation.

Investigation scope: all `/convert` references across the codebase, the filetypes extension infrastructure, and the zed repo for comparison.

## Findings

### 1. The Command Exists in the Extension

The file `.claude/extensions/filetypes/commands/convert.md` is a fully-implemented command specification (379 lines). It covers:
- PDF/DOCX/XLSX/PPTX/HTML to Markdown conversion
- Markdown to PDF conversion
- PPTX to Beamer/Polylux/Touying slide format conversion
- Tool detection and dependency guidance
- Error handling and edge cases

The filetypes extension `manifest.json` explicitly lists `convert.md` in its `provides.commands` array.

### 2. Full Infrastructure Exists

The filetypes extension provides complete conversion infrastructure:

| Component | Path | Purpose |
|-----------|------|---------|
| Command | `extensions/filetypes/commands/convert.md` | Command definition |
| Router agent | `extensions/filetypes/agents/filetypes-router-agent.md` | Routes by file type |
| Document agent | `extensions/filetypes/agents/document-agent.md` | General document conversion |
| Presentation agent | `extensions/filetypes/agents/presentation-agent.md` | PPTX slide conversion |
| Skill (general) | `extensions/filetypes/skills/skill-filetypes/` | General filetypes skill |
| Skill (presentation) | `extensions/filetypes/skills/skill-presentation/` | Presentation-specific skill |
| Conversion tables | `extensions/filetypes/context/project/filetypes/domain/conversion-tables.md` | Format support matrices |
| Tool detection | `extensions/filetypes/context/project/filetypes/tools/tool-detection.md` | Runtime tool availability |
| Dependency guide | `extensions/filetypes/context/project/filetypes/tools/dependency-guide.md` | Installation instructions |

### 3. Documentation References Audit

All references to `/convert` found in the codebase:

| File | Nature | Accurate? |
|------|--------|-----------|
| `docs/guides/user-guide.md` (lines 28, 462-484, 511) | User-facing guide with usage examples | Yes, but missing extension annotation |
| `docs/reference/standards/extension-slim-standard.md` (line 114) | Extension standard example | Yes, correctly scoped to filetypes extension |
| `context/patterns/context-discovery.md` (line 250) | Lists extension commands | Yes |
| `context/architecture/system-overview.md` (line 408) | Notes extension availability | Yes, correctly notes extension source |
| `extensions/filetypes/README.md` (multiple) | Extension documentation | Yes |
| `extensions/filetypes/commands/convert.md` | Command implementation | Yes |
| `extensions/filetypes/EXTENSION.md` (line 20) | Extension CLAUDE.md merge content | Yes |
| `extensions/filetypes/index-entries.json` (multiple) | Context index entries | Yes |
| `extensions/filetypes/skills/*/SKILL.md` (multiple) | Skill references | Yes |
| `extensions/present/README.md` (line 81) | Cross-reference from present extension | Yes |
| `extensions/present/commands/slides.md` (line 26) | Cross-reference | Yes |

### 4. Zed Repo Comparison

The file `/home/benjamin/.config/zed/.claude/commands/convert.md` exists in the zed repo, confirming this is a shared extension command that gets loaded into different editor configurations.

### 5. The Actual Problem

The user-guide.md presents `/convert` in section 4 "Utility Commands" alongside core commands `/meta` and `/fix-it`, without indicating it requires the filetypes extension. The command summary table at line 511 also lists it without qualification.

This is a **documentation clarity issue**, not a missing implementation.

## Decisions

- **Decision**: The `/convert` command should NOT be removed -- it has full infrastructure
- **Decision**: Documentation should be clarified to indicate extension dependency
- **Rationale**: The command is fully functional when the filetypes extension is loaded; removing documentation would make it harder for users to discover

## Recommendations

1. **[Primary] Annotate user-guide.md**: Add "(requires filetypes extension)" note to the /convert section header and the command summary table entry. This is a 2-line edit.

2. **[Optional] Add extension badge pattern**: Consider a consistent pattern for extension commands in user-guide.md, e.g., a note box: "This command is provided by the `filetypes` extension. Load it with `<leader>ac`."

3. **Do NOT create a core commands/convert.md**: The extension architecture is the correct pattern. Extension commands live in `extensions/*/commands/`, not in core `commands/`.

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| User confusion when /convert unavailable | Medium | Add extension requirement note in docs |
| Over-engineering the fix | Low | Keep it to a simple annotation edit |

## Appendix

### Search Queries
- `ls .claude/commands/convert.md` -- confirmed absence from core
- `grep -r /convert .claude/` -- found 60+ references across extension and docs
- `ls .claude/extensions/filetypes/commands/convert.md` -- confirmed existence in extension
- `cat .claude/extensions/filetypes/manifest.json` -- confirmed command registration
- `ls /home/benjamin/.config/zed/.claude/commands/convert.md` -- confirmed zed counterpart

### Key File Paths
- Extension command: `.claude/extensions/filetypes/commands/convert.md`
- User guide: `.claude/docs/guides/user-guide.md` (lines 462-484)
- Extension standard: `.claude/docs/reference/standards/extension-slim-standard.md` (line 114)
- Extension manifest: `.claude/extensions/filetypes/manifest.json`
