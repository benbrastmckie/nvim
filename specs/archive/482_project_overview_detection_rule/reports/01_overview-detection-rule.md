# Research Report: Task #482

**Task**: 482 - project_overview_detection_rule
**Started**: 2026-04-20T12:00:00Z
**Completed**: 2026-04-20T12:05:00Z
**Effort**: small
**Dependencies**: None (task 483 provides the generation workflow this rule would reference)
**Sources/Inputs**:
- Codebase exploration of `.claude/rules/` directory
- Core and nvim extension manifest and rules files
- `.claude/context/repo/project-overview.md` (contains the marker)
- `.claude/context/repo/update-project.md` (generation guide)
- `.claude/CLAUDE.md` (existing detection instructions)
**Artifacts**:
- `specs/482_project_overview_detection_rule/reports/01_overview-detection-rule.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Claude Code rules use YAML frontmatter with `paths:` globs to auto-apply when matched files are relevant
- The `project-overview.md` file already contains the `<!-- GENERIC TEMPLATE` HTML comment marker
- The CLAUDE.md already mentions detection but relies on manual reading; a rule automates this
- The rule should live in the core extension at `.claude/extensions/core/rules/` and be declared in its manifest
- The rule body should instruct the agent to check for the marker and notify the user
- Path pattern: `.claude/context/repo/project-overview.md` (or the glob variant `**/project-overview.md`)

## Context and Scope

The task asks for a detection rule that fires when `project-overview.md` contains the `<!-- GENERIC TEMPLATE` marker. Rules in Claude Code are markdown files with YAML frontmatter specifying path patterns. When the agent touches files matching those patterns, the rule content is injected as context.

The challenge: rules fire based on file path matching, not content inspection. The rule must instruct the agent to *check* the file content for the marker when the file is accessed.

## Findings

### Existing Rules System

Rules live at `.claude/rules/` with YAML frontmatter:

```yaml
---
paths: specs/**/*
---
```

or array form:

```yaml
---
paths: ["specs/**/*", ".claude/**/*"]
---
```

The `paths` field uses glob patterns. When any file matching the pattern is relevant to the agent's current operation, the rule content is automatically injected.

**Existing rules**:
| Rule | Path Pattern |
|------|------|
| artifact-formats.md | `specs/**/*` |
| error-handling.md | (implicit from `.claude/**/*`) |
| git-workflow.md | `["specs/**/*", ".claude/**/*"]` |
| plan-format-enforcement.md | `specs/**/*` |
| state-management.md | `specs/**/*` |
| workflows.md | `.claude/**/*` |
| neovim-lua.md | No frontmatter (legacy text format) |

### The Generic Template Marker

Located in `.claude/context/repo/project-overview.md` (line 1):
```html
<!-- GENERIC TEMPLATE: This file provides a default project overview...
```

This same file exists in:
- `.claude/context/repo/project-overview.md` (installed/active)
- `.claude/extensions/core/context/repo/project-overview.md` (extension source)
- `.opencode/context/project/repo/project-overview.md` (OpenCode copy)

### Existing Detection in CLAUDE.md

The CLAUDE.md already contains:
> **New repository setup**: If project-overview.md doesn't exist or contains the generic template notice (`<!-- GENERIC TEMPLATE`), run `/task "Generate project-overview.md for this repository"` to create a project-specific version. See `.claude/context/repo/update-project.md` for guidance.

This is passive -- it requires the agent to read CLAUDE.md and act on it. A rule makes it active by injecting directly when the file is touched.

### Extension Manifest Integration

The core extension `manifest.json` declares rules in `provides.rules` array. Adding the new rule requires:
1. Creating the rule file at `.claude/extensions/core/rules/project-overview-detection.md`
2. Adding `"project-overview-detection.md"` to the `provides.rules` array in manifest
3. Installing it to `.claude/rules/project-overview-detection.md`

### Path Pattern Choice

The rule should fire when `project-overview.md` is read or referenced:
- Option A: `**/project-overview.md` -- catches all copies
- Option B: `.claude/context/repo/project-overview.md` -- precise, only the active file

**Recommendation**: Use `.claude/context/repo/project-overview.md` since that is the file agents actually load. The extension source copy is irrelevant at runtime.

### Rule Content Design

Since rules cannot inspect file content themselves (they only fire on path match), the rule must instruct the agent to:
1. Check the first line of `project-overview.md` for the `<!-- GENERIC TEMPLATE` marker
2. If found, notify the user and suggest running the project-overview generation workflow
3. If not found (file has been customized), no action needed

## Decisions

1. **Placement**: Core extension (`.claude/extensions/core/rules/`) since project-overview.md is a core feature
2. **Path pattern**: `.claude/context/repo/project-overview.md` (precise targeting)
3. **Rule name**: `project-overview-detection.md`
4. **Behavior**: Conditional -- instruct agent to check content, only notify if marker present

## Recommendations

### Proposed Rule Content

```markdown
---
paths: .claude/context/repo/project-overview.md
---

# Project Overview Detection

When reading or referencing `.claude/context/repo/project-overview.md`, check if the file begins with the HTML comment `<!-- GENERIC TEMPLATE`. If this marker is present:

1. **Notify the user**: The project-overview.md contains the generic template and should be customized for this repository.
2. **Suggest action**: Recommend running `/task "Generate project-overview.md for this repository"` to create a project-specific version.
3. **Reference**: See `.claude/context/repo/update-project.md` for the generation guide.

If the marker is NOT present, the file has already been customized -- no notification needed.
```

### Implementation Steps

1. Create `.claude/extensions/core/rules/project-overview-detection.md` with the content above
2. Add `"project-overview-detection.md"` to `provides.rules` in `.claude/extensions/core/manifest.json`
3. Install to `.claude/rules/project-overview-detection.md` (copy or symlink)

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Rule fires too often (every time project-overview.md is in context) | Rule is conditional -- agent only notifies if marker present; silent otherwise |
| Agent overhead from checking file content | Minimal -- first line check is trivial |
| Rule not triggering if file is loaded via @-reference without path match | Claude Code @-references do trigger path-based rules |
| Sync operations overwriting customized project-overview.md | Existing `.syncprotect` mechanism handles this (documented in CLAUDE.md) |

## Appendix

### Files Examined
- `.claude/rules/` (all 8 existing rules)
- `.claude/extensions/core/manifest.json`
- `.claude/extensions/core/rules/` (source rules with frontmatter)
- `.claude/extensions/nvim/manifest.json` and rules
- `.claude/context/repo/project-overview.md` (marker present)
- `.claude/context/repo/update-project.md` (generation guide)
- `.claude/CLAUDE.md` (existing passive detection)
- `specs/ROADMAP.md`
