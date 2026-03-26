# Research Report: Task #280

**Task**: 280 - Update filetypes extension manifest and documentation
**Generated**: 2026-03-25
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Register the new scrape components in the filetypes extension configuration
**Scope**: Extension manifest, documentation, and context index updates
**Affected Components**: manifest.json, EXTENSION.md, index-entries.json
**Domain**: filetypes extension
**Language**: meta

## Task Requirements

### manifest.json Updates

Add to `.claude/extensions/filetypes/manifest.json`:

```json
{
  "provides": {
    "agents": ["filetypes-router-agent.md", "document-agent.md", "spreadsheet-agent.md", "presentation-agent.md", "scrape-agent.md"],
    "skills": ["skill-filetypes", "skill-spreadsheet", "skill-presentation", "skill-scrape"],
    "commands": ["convert.md", "table.md", "slides.md", "scrape.md"]
  }
}
```

### EXTENSION.md Updates

Add `/scrape` command documentation to the extension's CLAUDE.md section:

- Command syntax and usage examples
- Supported annotation types
- Output format options
- Tool requirements (pdfannots)

### index-entries.json Updates

Add context index entries for:
- scrape-agent context references
- skill-scrape trigger conditions
- PDF annotation tool detection patterns

### filetypes-router-agent Updates

The router agent may need updating to dispatch to scrape-agent for annotation extraction requests (as distinct from document conversion).

**Routing Logic Addition**:
- If operation is "extract annotations" or "scrape" -> dispatch to scrape-agent
- If operation is "convert" -> dispatch to document-agent (existing)

## Integration Points

- **Component Type**: Configuration/documentation
- **Affected Area**: `.claude/extensions/filetypes/`
- **Action Type**: Update
- **Related Files**:
  - `.claude/extensions/filetypes/manifest.json`
  - `.claude/extensions/filetypes/EXTENSION.md`
  - `.claude/extensions/filetypes/index-entries.json`
  - `.claude/extensions/filetypes/agents/filetypes-router-agent.md`

## Dependencies

- Task #279: All components must exist before registering them in manifest

## Interview Context

### User-Provided Information
- Follow existing manifest.json structure for adding new entries
- Ensure router agent can dispatch to scrape-agent
- Update all extension documentation

### Effort Assessment
- **Estimated Effort**: 30 minutes
- **Complexity Notes**: Straightforward configuration updates; main effort is ensuring consistency with existing entries

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 280 [focus]` with a specific focus prompt.*
