# Implementation Plan: Task #280

- **Task**: 280 - Update filetypes extension manifest and documentation
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: Task #279 (scrape-agent, skill-scrape, scrape.md must exist)
- **Research Inputs**: specs/280_update_filetypes_extension_manifest/reports/01_meta-research.md
- **Artifacts**: plans/01_manifest-update-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Update three files in the filetypes extension to register the new scrape-agent, skill-scrape, and /scrape command: `manifest.json` adds the new components to the provides arrays; `EXTENSION.md` documents the /scrape command with usage, tool chain, and prerequisites; `index-entries.json` adds context discovery entries so scrape-agent can find tool-detection.md and dependency-guide.md.

### Research Integration

The filetypes extension manifest.json uses a `provides` object with arrays for agents, skills, commands, rules, context, scripts, and hooks. Each new component is registered as a filename string. EXTENSION.md uses a consistent table-and-code-block format already established for /convert, /table, and /slides. index-entries.json entries specify path, description, line_count estimate, and load_when conditions with agents and commands arrays.

## Goals & Non-Goals

**Goals**:
- Add `scrape-agent.md` to `manifest.json` provides.agents array
- Add `skill-scrape` to `manifest.json` provides.skills array
- Add `scrape.md` to `manifest.json` provides.commands array
- Add /scrape documentation section to `EXTENSION.md`
- Add `index-entries.json` entries for scrape-agent context loading
- Increment manifest.json version from 2.0.0 to 2.1.0 (minor version for new feature)

**Non-Goals**:
- Modifying filetypes-router-agent to route to scrape-agent (direct routing via skill-scrape)
- Creating new context documentation files (tool-detection.md already covers tool checking)
- Updating opencode-agents.json (optional, separate concern)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| manifest.json JSON syntax error | M | L | Validate with jq after editing |
| index-entries.json line_count estimate incorrect | L | L | Use approximate value; exact count not critical |
| EXTENSION.md merge section conflicts with existing content | L | L | Append new section at end before closing |

## Implementation Phases

### Phase 1: Update manifest.json [NOT STARTED]

**Goal**: Register the three new components in the extension manifest.

**Tasks**:
- [ ] Read current manifest.json content
- [ ] Add `"scrape-agent.md"` to the `provides.agents` array
- [ ] Add `"skill-scrape"` to the `provides.skills` array
- [ ] Add `"scrape.md"` to the `provides.commands` array
- [ ] Increment version from `"2.0.0"` to `"2.1.0"`
- [ ] Verify JSON is valid after edit

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/filetypes/manifest.json` - Add scrape components, bump version

**Verification**:
- `jq '.provides.agents | index("scrape-agent.md")' manifest.json` returns non-null
- `jq '.provides.skills | index("skill-scrape")' manifest.json` returns non-null
- `jq '.provides.commands | index("scrape.md")' manifest.json` returns non-null
- `jq '.version' manifest.json` returns `"2.1.0"`
- `jq '.' manifest.json` succeeds (valid JSON)

### Phase 2: Update EXTENSION.md [NOT STARTED]

**Goal**: Document the /scrape command for users in the merged CLAUDE.md section.

**Tasks**:
- [ ] Read current EXTENSION.md content
- [ ] Add "PDF Annotation Extraction (via /scrape)" subsection to Supported Conversions
- [ ] Add /scrape usage examples to Command Usage section
- [ ] Add scrape tool prerequisites to Prerequisites section
- [ ] Add scrape tool rows to Dependency Summary table
- [ ] Add scrape context documentation to Context Documentation table

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/filetypes/EXTENSION.md` - Add /scrape documentation

**Verification**:
- File contains `/scrape` command documentation
- Tool prerequisites for pymupdf, pypdf, pdfannots documented
- NixOS quick install section updated with new packages
- Usage examples show all supported argument patterns

### Phase 3: Update index-entries.json [NOT STARTED]

**Goal**: Add context index entries so scrape-agent can discover relevant context files at runtime.

**Tasks**:
- [ ] Read current index-entries.json
- [ ] Add entry for `project/filetypes/tools/tool-detection.md` with `scrape-agent` in agents array and `/scrape` in commands array (update existing entry)
- [ ] Add entry for `project/filetypes/tools/dependency-guide.md` with `scrape-agent` in agents array and `/scrape` in commands array (update existing entry)
- [ ] Add new entry for `project/filetypes/patterns/pdf-annotations.md` (future context file placeholder with line_count: 0)
- [ ] Verify JSON is valid after edit

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/filetypes/index-entries.json` - Add scrape-agent to load_when arrays

**Verification**:
- `jq '.entries[] | select(.load_when.agents[] | contains("scrape-agent"))' index-entries.json` returns entries
- `jq '.' index-entries.json` succeeds (valid JSON)

## File Content Specifications

### manifest.json After Update

```json
{
  "name": "filetypes",
  "version": "2.1.0",
  "description": "File format conversion and manipulation for documents, spreadsheets, and presentations",
  "language": null,
  "dependencies": [],
  "provides": {
    "agents": [
      "filetypes-router-agent.md",
      "document-agent.md",
      "spreadsheet-agent.md",
      "presentation-agent.md",
      "scrape-agent.md"
    ],
    "skills": [
      "skill-filetypes",
      "skill-spreadsheet",
      "skill-presentation",
      "skill-scrape"
    ],
    "commands": [
      "convert.md",
      "table.md",
      "slides.md",
      "scrape.md"
    ],
    "rules": [],
    "context": [
      "project/filetypes"
    ],
    "scripts": [],
    "hooks": []
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_filetypes"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    },
    "opencode_json": {
      "source": "opencode-agents.json",
      "target": "opencode.json"
    }
  },
  "mcp_servers": {}
}
```

### EXTENSION.md New Content to Add

Under the "Supported Conversions" section, add:

```markdown
#### PDF Annotation Extraction (via /scrape)

| Source | Output Format | Primary Tool | Fallback 1 | Fallback 2 |
|--------|---------------|--------------|------------|------------|
| PDF    | Markdown      | PyMuPDF      | pypdf      | pdfannots  |
| PDF    | JSON          | PyMuPDF      | pypdf      | pdfannots  |

Supported annotation types: highlight, note, underline, strikeout, comment
```

Under "Command Usage", add:

```bash
# PDF annotation extraction
/scrape paper.pdf                              # -> paper_annotations.md
/scrape paper.pdf notes.md                    # -> notes.md
/scrape paper.pdf --format json               # -> paper_annotations.md (JSON)
/scrape paper.pdf --types highlight,note      # -> only highlights and notes
/scrape paper.pdf out.md --format json --types highlight
```

Under "Prerequisites", add:

```markdown
**PDF Annotation Extraction**:
- `pymupdf`: `pip install pymupdf` (recommended, best coverage)
- `pypdf`: `pip install pypdf` (pure Python fallback)
- `pdfannots`: `pip install pdfannots` (CLI fallback)
- `pikepdf`: `pip install pikepdf` (optional, for encrypted PDFs)
```

Under "NixOS Quick Install", extend the python packages list with:

```nix
pymupdf pypdf pdfannots pikepdf
```

Under "Dependency Summary", add rows:

```
| pymupdf   | PDF annotation extraction     | /scrape (primary) |
| pypdf     | PDF annotation extraction     | /scrape (fallback) |
| pdfannots | PDF annotation extraction     | /scrape (fallback) |
| pikepdf   | Decrypt encrypted PDFs        | /scrape (preprocess) |
```

### index-entries.json Updated Entries

The existing `tool-detection.md` and `dependency-guide.md` entries need `scrape-agent` added to their agents arrays and `/scrape` added to their commands arrays.

New entry to add for future annotation patterns context:

```json
{
  "path": "project/filetypes/patterns/pdf-annotations.md",
  "description": "PDF annotation extraction patterns and tool-specific implementation details",
  "line_count": 0,
  "load_when": {
    "agents": ["scrape-agent"],
    "languages": [],
    "commands": ["/scrape"]
  }
}
```

## Testing & Validation

- [ ] `manifest.json` version is `"2.1.0"`
- [ ] `manifest.json` provides.agents contains `"scrape-agent.md"`
- [ ] `manifest.json` provides.skills contains `"skill-scrape"`
- [ ] `manifest.json` provides.commands contains `"scrape.md"`
- [ ] `jq '.' manifest.json` succeeds without errors
- [ ] `EXTENSION.md` documents /scrape command with usage examples
- [ ] `EXTENSION.md` lists pymupdf, pypdf, pdfannots, pikepdf prerequisites
- [ ] `index-entries.json` tool-detection.md entry includes `scrape-agent`
- [ ] `index-entries.json` dependency-guide.md entry includes `scrape-agent`
- [ ] `jq '.' index-entries.json` succeeds without errors

## Artifacts & Outputs

- `.claude/extensions/filetypes/manifest.json` - Updated with scrape components, version 2.1.0
- `.claude/extensions/filetypes/EXTENSION.md` - Updated with /scrape documentation
- `.claude/extensions/filetypes/index-entries.json` - Updated with scrape-agent context entries

## Rollback/Contingency

All three files are edits to existing files. If any edit produces invalid JSON or malformed content, restore from git with `git checkout HEAD -- <file>`. The changes are additive (appending to arrays, adding sections) so rollback is clean. The version bump to 2.1.0 can be reverted independently of the component registration changes.
