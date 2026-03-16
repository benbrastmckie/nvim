# Research Report: Task #214

**Task**: 214 - restructure_context_grant_to_present
**Started**: 2026-03-16T00:00:00Z
**Completed**: 2026-03-16T00:01:00Z
**Effort**: 0.5-1 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (Glob, Grep, Read)
**Artifacts**: specs/214_restructure_context_grant_to_present/reports/01_context-restructure-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Directory rename: `context/project/grant/` to `context/project/present/` within present extension
- 16 path entries in index-entries.json need updating from `project/grant/` to `project/present/`
- 28 total references across 5 files require path updates
- Clean rename operation with no external dependencies

## Context & Scope

The task involves restructuring the grant context files within the present extension by renaming the directory from `grant/` to `present/`. This consolidates the grant-related content under the same subdomain as the deck-related content, creating a unified `project/present/` context hierarchy within the present extension.

### Current Structure

```
.claude/extensions/present/
├── context/project/
│   ├── grant/              # TO BE RENAMED -> present/
│   │   ├── README.md
│   │   ├── domain/
│   │   │   ├── funder-types.md
│   │   │   ├── grant-terminology.md
│   │   │   └── proposal-components.md
│   │   ├── patterns/
│   │   │   ├── budget-patterns.md
│   │   │   ├── evaluation-patterns.md
│   │   │   ├── narrative-patterns.md
│   │   │   └── proposal-structure.md
│   │   ├── standards/
│   │   │   ├── character-limits.md
│   │   │   └── writing-standards.md
│   │   ├── templates/
│   │   │   ├── budget-justification.md
│   │   │   ├── evaluation-plan.md
│   │   │   ├── executive-summary.md
│   │   │   └── submission-checklist.md
│   │   └── tools/
│   │       ├── funder-research.md
│   │       └── web-resources.md
│   └── present/            # ALREADY EXISTS (for deck content)
│       └── patterns/
│           ├── pitch-deck-structure.md
│           └── touying-pitch-deck-template.md
```

### Target Structure

```
.claude/extensions/present/
├── context/project/
│   └── present/            # MERGED (grant content moved here)
│       ├── README.md           # From grant/
│       ├── domain/             # From grant/
│       │   ├── funder-types.md
│       │   ├── grant-terminology.md
│       │   └── proposal-components.md
│       ├── patterns/           # MERGED (grant + deck patterns)
│       │   ├── budget-patterns.md
│       │   ├── evaluation-patterns.md
│       │   ├── narrative-patterns.md
│       │   ├── pitch-deck-structure.md      # Already exists
│       │   ├── proposal-structure.md
│       │   └── touying-pitch-deck-template.md  # Already exists
│       ├── standards/          # From grant/
│       │   ├── character-limits.md
│       │   └── writing-standards.md
│       ├── templates/          # From grant/
│       │   ├── budget-justification.md
│       │   ├── evaluation-plan.md
│       │   ├── executive-summary.md
│       │   └── submission-checklist.md
│       └── tools/              # From grant/
│           ├── funder-research.md
│           └── web-resources.md
```

## Findings

### Files Requiring Updates

#### 1. index-entries.json (16 path entries)

Location: `.claude/extensions/present/index-entries.json`

All 16 entries with `"path": "project/grant/..."` need to change to `"path": "project/present/..."`:

| Line | Current Path | Target Path |
|------|-------------|-------------|
| 32 | `project/grant/README.md` | `project/present/README.md` |
| 46 | `project/grant/domain/funder-types.md` | `project/present/domain/funder-types.md` |
| 60 | `project/grant/domain/proposal-components.md` | `project/present/domain/proposal-components.md` |
| 74 | `project/grant/domain/grant-terminology.md` | `project/present/domain/grant-terminology.md` |
| 88 | `project/grant/patterns/proposal-structure.md` | `project/present/patterns/proposal-structure.md` |
| 102 | `project/grant/patterns/budget-patterns.md` | `project/present/patterns/budget-patterns.md` |
| 116 | `project/grant/patterns/evaluation-patterns.md` | `project/present/patterns/evaluation-patterns.md` |
| 130 | `project/grant/patterns/narrative-patterns.md` | `project/present/patterns/narrative-patterns.md` |
| 144 | `project/grant/standards/writing-standards.md` | `project/present/standards/writing-standards.md` |
| 158 | `project/grant/standards/character-limits.md` | `project/present/standards/character-limits.md` |
| 172 | `project/grant/templates/executive-summary.md` | `project/present/templates/executive-summary.md` |
| 186 | `project/grant/templates/budget-justification.md` | `project/present/templates/budget-justification.md` |
| 200 | `project/grant/templates/evaluation-plan.md` | `project/present/templates/evaluation-plan.md` |
| 214 | `project/grant/templates/submission-checklist.md` | `project/present/templates/submission-checklist.md` |
| 228 | `project/grant/tools/funder-research.md` | `project/present/tools/funder-research.md` |
| 242 | `project/grant/tools/web-resources.md` | `project/present/tools/web-resources.md` |

**Note**: The `subdomain` field in each entry should ALSO be updated from `"grant"` to `"present"` for consistency with the new path structure.

#### 2. grant-agent.md (6 @-references)

Location: `.claude/extensions/present/agents/grant-agent.md`

| Line | Current Reference | Target Reference |
|------|------------------|------------------|
| 48 | `@.claude/extensions/grant/context/project/grant/README.md` | `@.claude/extensions/present/context/project/present/README.md` |
| 51 | `project/grant/domain/funder-types.md` | `project/present/domain/funder-types.md` |
| 52 | `project/grant/templates/proposal-template.md` | `project/present/templates/proposal-template.md` |
| 53 | `project/grant/templates/budget-template.md` | `project/present/templates/budget-template.md` |
| 54 | `project/grant/patterns/progress-tracking.md` | `project/present/patterns/progress-tracking.md` |

**Note**: Line 48 also has a typo - it references `.claude/extensions/grant/` which should be `.claude/extensions/present/`.

#### 3. EXTENSION.md (4 @-references)

Location: `.claude/extensions/present/EXTENSION.md`

| Line | Current Reference | Target Reference |
|------|------------------|------------------|
| 38 | `@.claude/context/project/grant/README.md` | `@.claude/context/project/present/README.md` |
| 39 | `@.claude/context/project/grant/domain/` | `@.claude/context/project/present/domain/` |
| 40 | `@.claude/context/project/grant/templates/` | `@.claude/context/project/present/templates/` |
| 41 | `@.claude/context/project/grant/patterns/` | `@.claude/context/project/present/patterns/` |

#### 4. manifest.json (1 provides.context entry)

Location: `.claude/extensions/present/manifest.json`

| Line | Current Value | Target Value |
|------|--------------|--------------|
| 12 | `"context": ["project/grant", "project/present"]` | `"context": ["project/present"]` |

**Note**: After the rename, both grant and deck content will be under `project/present/`, so only one entry is needed.

#### 5. skill-grant/SKILL.md (1 @-reference)

Location: `.claude/extensions/present/skills/skill-grant/SKILL.md`

| Line | Current Reference | Target Reference |
|------|------------------|------------------|
| 6 | `.claude/extensions/grant/context/project/grant/README.md` | `.claude/extensions/present/context/project/present/README.md` |

**Note**: This also has the same typo as grant-agent.md (references `extensions/grant/` instead of `extensions/present/`).

### Reference Count Summary

| File | Reference Count | Type |
|------|-----------------|------|
| index-entries.json | 16 | path fields |
| grant-agent.md | 6 | @-references |
| EXTENSION.md | 4 | @-references |
| manifest.json | 1 | provides.context |
| skill-grant/SKILL.md | 1 | comment reference |
| **Total** | **28** | |

### Directory Operation

The actual directory rename involves:

1. **Move grant content to present**: Move contents of `context/project/grant/` to `context/project/present/`
2. **Handle patterns/ merge**: The `patterns/` subdirectory already exists in `present/` with deck content. Grant patterns must be merged (copied alongside existing files).
3. **Remove grant directory**: After successful move, remove the now-empty `context/project/grant/` directory.

## Decisions

1. **Subdomain field**: Update subdomain from "grant" to "present" in index-entries.json for affected entries
2. **Fix extension typos**: Correct references from `extensions/grant/` to `extensions/present/` in grant-agent.md and SKILL.md
3. **Simplify manifest.json**: Remove duplicate `project/grant` entry since all content will be under `project/present`
4. **Preserve existing deck content**: The patterns/ directory merge must not overwrite existing deck patterns

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Overwriting deck patterns during merge | Check for filename conflicts before merge; none exist |
| Breaking extension loading | Test extension load after changes |
| Missing reference updates | Use global grep to verify all `project/grant` references are updated |
| Index.json merge failure | Extension uses index-entries.json which merges to main index.json; verify merge target path is correct |

## Implementation Approach

1. **Phase 1: Directory Operations**
   - Create target directories if needed (present/domain/, present/standards/, present/templates/, present/tools/)
   - Move grant files to present (preserving existing deck content in patterns/)
   - Remove empty grant/ directory

2. **Phase 2: File Updates**
   - Update all 16 paths in index-entries.json (also update subdomain fields)
   - Update 6 references in grant-agent.md (including typo fixes)
   - Update 4 references in EXTENSION.md
   - Update 1 entry in manifest.json
   - Update 1 reference in skill-grant/SKILL.md (including typo fix)

3. **Phase 3: Validation**
   - Grep for any remaining `project/grant` references
   - Verify directory structure is correct
   - Test extension load

## Appendix

### Search Queries Used

```bash
# Find all references to project/grant in present extension
grep -r "project/grant" .claude/extensions/present/

# List grant directory structure
ls -la .claude/extensions/present/context/project/grant/

# Count files in grant directory
find .claude/extensions/present/context/project/grant/ -type f | wc -l
```

### File Counts

- Files in grant/: 16 total
  - README.md: 1
  - domain/: 3 files
  - patterns/: 4 files
  - standards/: 2 files
  - templates/: 4 files
  - tools/: 2 files
- Files in present/patterns/: 2 (deck content)
