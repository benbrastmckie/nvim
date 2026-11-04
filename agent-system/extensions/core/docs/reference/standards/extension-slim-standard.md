# EXTENSION.md Slim-Down Standard

## Purpose

EXTENSION.md files are injected into CLAUDE.md context when loaded via the [extension picker](../../../../README.md). Large EXTENSION.md files waste context window budget on documentation that agents rarely need during routing. This standard defines maximum size and required content for EXTENSION.md files, and (see "Shape-(a) Merge Sources" below) extends the same discipline to shape-(a) `merge-sources/claudemd.md` sources.

## Size Limit

**Maximum: 60 lines** for any EXTENSION.md file. Lint-enforced: `check-extension-docs.sh`'s
Rule U flags any EXTENSION.md exceeding 60 lines (severity controlled by
`SCHEMA_CONFORMANCE_GATE_MODE`, defaulting `hard`) -- run the lint for the current violator
count rather than trusting a hand-maintained total, which goes stale as extensions are added.

## Resource-Only / Non-EXTENSION.md-Source Extensions

This standard applies only to an extension whose manifest names `EXTENSION.md` as its
`merge_targets.claudemd.source` -- the file `generate_claudemd()` actually reads when composing
`.claude/CLAUDE.md`. Both the required-file check and Rule U in `check-extension-docs.sh` are
manifest-authoritative on this field (see that script's `claudemd_source_for` helper and its
rationale comment), not a hardcoded "every extension must have EXTENSION.md" assumption. Two
cases fall outside this standard's scope entirely:

- **A different claudemd source**: `core` points `merge_targets.claudemd.source` at
  `merge-sources/claudemd.md` instead of `EXTENSION.md`, and has no `EXTENSION.md` file at all.
  This 60-line, LINE-count limit does not apply to that shape-(a) source -- but a separate
  BYTE-count ceiling does; see "Shape-(a) Merge Sources" below.
- **No claudemd source (resource-only extensions)**: an extension with zero
  `provides.skills`/`provides.commands` that shares only context (e.g. `slidev`) may omit
  `merge_targets.claudemd` entirely, per `creating-extensions.md`'s "Resource-Only Extensions"
  section. `check-extension-docs.sh` emits an advisory (never a silent skip) if a NON-resource-only
  extension (non-empty `provides.skills` or `provides.commands`) omits `merge_targets.claudemd`,
  distinguishing an accidental omission from this intentional pattern.

Both `core/EXTENSION.md` and `slidev/EXTENSION.md` were deleted (not trimmed) because each was a
100% content subset of its own `README.md` and neither was reachable from `generate_claudemd()`'s
actual merge path.

## Shape-(a) Merge Sources

A shape-(a) source (`merge_targets.claudemd.source` naming something other than `EXTENSION.md`,
e.g. `merge-sources/claudemd.md`) has no natural line-count analog to Rule U's 60-line limit --
these files carry real, structured CLAUDE.md content (Task Management, Command Reference, and
similar sections), not a slim routing summary. Instead, each shape-(a) source is held to an
explicit **byte ceiling**, declared per-extension in
`context/config/claudemd-size-budget.json` and enforced by `check-extension-docs.sh`'s Rule V
(same `SCHEMA_CONFORMANCE_GATE_MODE` severity as Rule U). Today exactly two extensions are
shape-(a): `core` and `literature`; re-derive the shape-(a) set live via
`jq -r '.merge_targets.claudemd.source' agent-system/extensions/*/manifest.json` rather than
trusting this count, which goes stale as extensions are added.

Each named ceiling in the budget config is derived from that extension's own measured post-cut
size (round up to the next 500 B, then add ~5% headroom), recorded alongside the ceiling with a
`derivation` comment field. A `default_ceiling_bytes` value covers any future shape-(a)
extension with no named entry yet.

**Why an external config file, not a `manifest.json` field**: a manifest-schema task is in
flight at the time this ceiling was introduced, so the ceiling deliberately lands as an external
config rather than a new `merge_targets.claudemd.max_bytes` manifest field. Promoting it to a
manifest field once that schema work lands is a natural follow-up, not a rejected design.
`check-extension-docs.sh` reads the config from the SOURCE STORE
(`agent-system/extensions/core/context/config/claudemd-size-budget.json`, resolved via its own
`EXT_DIR`), so no deploy of the config file is required for Rule V to see current ceilings --
declaring the `config` directory in `core/manifest.json`'s `provides.context` is a
discoverability nicety, not a functional dependency for this rule.

## Required Sections

EXTENSION.md must contain only these four sections:

| Section | Lines | Content |
|---------|-------|---------|
| **Header** | 3-5 | Extension name, version, one-line description |
| **Routing Table** | 5-15 | Skill-to-agent mappings (primary purpose of EXTENSION.md) |
| **Command List** | 5-15 | Command name, usage, one-line description per row |
| **Context Pointers** | 3-5 | Lazy @-references to context files (max 5 pointers) |

See the Migration Template below for a concrete example of all four sections.

## Sections That Must Move to Context Files

The following content types do NOT belong in EXTENSION.md:

| Content Type | Move To | Example |
|---|---|---|
| Detailed usage examples | `context/project/{ext}/patterns/` | Command workflows, input/output examples |
| Architecture documentation | `context/project/{ext}/domain/` | System design, component relationships |
| Conversion/compatibility tables | `context/project/{ext}/domain/` | Format support matrices with fallbacks |
| Migration guides | `context/project/{ext}/domain/` | Version upgrade instructions |
| Troubleshooting | `context/project/{ext}/domain/` | Error resolution, debugging tips |
| Prerequisites/installation | `context/project/{ext}/tools/` | Dependency lists, platform setup |
| MCP tool integration | `context/project/{ext}/tools/` | Server config, API keys |
| Forcing data schemas | `context/project/{ext}/patterns/` | JSON structures, data formats |
| Mode descriptions | `context/project/{ext}/domain/` | Operational mode details |

## Context File Location

New context files go in the extension's existing context directory structure:

```
.claude/extensions/{ext}/
  context/project/{ext}/
    domain/       # Domain knowledge, reference tables
    patterns/     # Workflow patterns, usage examples
    tools/        # Tool setup, dependencies
    templates/    # Output templates
```

## Index Integration

Every new context file must have an entry in the extension's `index-entries.json`:

```json
{
  "path": "project/{ext}/domain/conversion-tables.md",
  "domain": "project",
  "subdomain": "{ext}",
  "summary": "Format conversion support matrix with fallback chains",
  "line_count": 45,
  "load_when": {
    "agents": ["relevant-agent"],
    "task_types": ["{ext}"]
  }
}
```

The authoritative field definition lives in
`agent-system/extensions/core/context/index.schema.json` -- if this example and that schema ever
disagree, the schema wins; fix this example rather than treating it as a second authority.

## Migration Template

### Before (143 lines - filetypes example)

```markdown
## Filetypes Extension
[3 lines description]
### Skill-Agent Mapping       -- KEEP (routing)
[8 lines]
### Supported Conversions     -- MOVE (detail tables)
[35 lines across 4 subsections]
### Command Usage             -- SLIM (keep table, move examples)
[22 lines with code blocks]
### Prerequisites             -- MOVE (installation docs)
[20 lines]
### NixOS Quick Install       -- MOVE (platform-specific)
[8 lines]
### Dependency Summary        -- MOVE (reference table)
[16 lines]
### Context Documentation     -- KEEP as pointers
[8 lines]
```

### After (~40 lines)

```markdown
## Filetypes Extension

File format conversion and manipulation: documents, spreadsheets, presentations, PDF annotations.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-filetypes | filetypes-router-agent | Format detection and routing |
| skill-filetypes-spreadsheet | filetypes-spreadsheet-agent | Spreadsheet to LaTeX/Typst |
| skill-presentation | presentation-agent | Slide extraction and generation |
| skill-scrape | scrape-agent | PDF annotation extraction |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| /convert | `/convert file.pdf` | Convert between document formats (incl. `/convert deck.pptx --format beamer`) |
| /table | `/table data.xlsx` | Convert spreadsheets to LaTeX/Typst tables |
| /scrape | `/scrape paper.pdf` | Extract PDF annotations to Markdown/JSON |

### Context

- @context/project/filetypes/domain/conversion-tables.md - Format support matrices
- @context/project/filetypes/tools/dependency-guide.md - Installation instructions
- @context/project/filetypes/patterns/spreadsheet-tables.md - Table conversion patterns
- @context/project/filetypes/patterns/presentation-slides.md - Slide generation patterns
```

## Verification Checklist

After slimming an EXTENSION.md:

1. [ ] File is under 60 lines
2. [ ] Header with name and description present
3. [ ] Routing table includes all skill-agent mappings
4. [ ] Command table lists all commands with usage
5. [ ] Context pointers reference moved content (max 5 lines)
6. [ ] Moved content exists in context files
7. [ ] New context files have index-entries.json entries
8. [ ] Extension loads without errors via the [extension picker](../../../../README.md)
9. [ ] Commands still route correctly after changes
