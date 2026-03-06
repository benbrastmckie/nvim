# Implementation Plan: Task #149

- **Task**: 149 - Review and update OpenCode documentation README files
- **Status**: [NOT STARTED]
- **Effort**: 6-8 hours
- **Dependencies**: None
- **Research Inputs**: specs/OC_149_review_update_opencode_documentation_readme_files/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: .opencode/context/core/formats/plan-format.md, .opencode/context/core/standards/status-markers.md, .opencode/context/core/standards/documentation-standards.md, .opencode/context/core/standards/task-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan addresses the systematic documentation audit of the `.opencode/` directory. The goal is to create README.md files for all 157 missing directories (88.7% of total), establish consistent navigation patterns, and reorganize the `docs/` directory. Work is phased by priority: core system first, then extension roots, then structure, then verification.

### Research Integration

The research identified 177 total directories with only 20 having README.md files. Key findings integrated:
- **Template based on**: `context/project/neovim/README.md` and `context/core/checkpoints/README.md` (excellent examples)
- **Priority order**: Critical (core system) → High (extension roots) → Medium (extension structure) → Lower (deep nested)
- **Navigation patterns**: Parent links (`../README.md`, `../../README.md`, etc.) and child directory links
- **Docs organization**: 3 loose files need moving to `guides/` subdirectory

## Goals & Non-Goals

**Goals**:
- Create README.md files for all 157 directories missing documentation
- Establish consistent README.md template across all directories
- Implement bidirectional navigation (parent/child links) in all README files
- Organize `docs/` directory by moving loose files to appropriate subdirectories
- Update existing README files to link to new child README files

**Non-Goals**:
- Do not modify content of existing markdown files (only create new READMEs and move files)
- Do not restructure directory hierarchy (only add documentation)
- Do not create content beyond directory descriptions and navigation
- Do not modify `.obsidian/` directory

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Broken relative links after file moves | High | Medium | Verify all links during Phase 6; use consistent depth calculation |
| Inconsistent README formatting | Medium | Medium | Use template script; review samples before bulk creation |
| Missing subdirectory links in parents | Medium | Low | Systematic verification in Phase 6; check parent README updates |
| Large volume of work (157 files) | Medium | High | Phased approach; template generation; batch commits |
| Template doesn't fit all directory types | Low | Medium | Create variants for leaf directories vs. container directories |

## Implementation Phases

### Phase 1: Template Creation & Core System [NOT STARTED]

**Goal**: Create standardized README template and document the 20 critical core system directories

**Tasks**:
- [ ] Create `.opencode/TEMPLATES/README-template.md` with standard structure
- [ ] Create `.opencode/agent/README.md` - Core agent system overview
- [ ] Create `.opencode/context/core/README.md` - Core context overview with 6 subdirs
- [ ] Create `.opencode/context/core/architecture/README.md`
- [ ] Create `.opencode/context/core/formats/README.md`
- [ ] Create `.opencode/context/core/orchestration/README.md`
- [ ] Create `.opencode/context/core/patterns/README.md`
- [ ] Create `.opencode/context/core/schemas/README.md`
- [ ] Create `.opencode/context/core/standards/README.md`
- [ ] Create `.opencode/context/core/templates/README.md`
- [ ] Create `.opencode/context/core/workflows/README.md`
- [ ] Create `.opencode/context/project/README.md` - Project context overview
- [ ] Create `.opencode/context/project/hooks/README.md`
- [ ] Create `.opencode/context/project/meta/README.md`
- [ ] Create `.opencode/context/project/neovim/domain/README.md`
- [ ] Create `.opencode/context/project/neovim/patterns/README.md`
- [ ] Create `.opencode/context/project/neovim/standards/README.md`
- [ ] Create `.opencode/context/project/neovim/templates/README.md`
- [ ] Create `.opencode/context/project/neovim/tools/README.md`
- [ ] Create `.opencode/context/project/processes/README.md`
- [ ] Create `.opencode/context/project/repo/README.md`
- [ ] Create `.opencode/skills/README.md` - Skills overview with links to 13 skill dirs
- [ ] Create `.opencode/rules/README.md` - Rules overview
- [ ] Update existing parent README files to link to new child READMEs

**Timing**: 2 hours

### Phase 2: Extension Root Directories [NOT STARTED]

**Goal**: Document all 11 extension root directories and establish extension structure pattern

**Tasks**:
- [ ] Create `.opencode/extensions/README.md` - Extensions overview with all 10 extension links
- [ ] Create `.opencode/extensions/epidemiology/README.md`
- [ ] Create `.opencode/extensions/filetypes/README.md`
- [ ] Create `.opencode/extensions/formal/README.md`
- [ ] Create `.opencode/extensions/latex/README.md`
- [ ] Create `.opencode/extensions/lean/README.md`
- [ ] Create `.opencode/extensions/nix/README.md`
- [ ] Create `.opencode/extensions/python/README.md`
- [ ] Create `.opencode/extensions/typst/README.md`
- [ ] Create `.opencode/extensions/web/README.md`
- [ ] Create `.opencode/extensions/z3/README.md`
- [ ] Update main `.opencode/README.md` to link to extensions/README.md

**Timing**: 1 hour

### Phase 3: Extension Structure Directories [NOT STARTED]

**Goal**: Create README.md files for all extension subdirectories (agents/, commands/, context/, rules/, scripts/, skills/)

**Tasks**:
- [ ] Create README.md for all 10 `extensions/*/agents/` directories
- [ ] Create README.md for all `extensions/*/commands/` directories (where they exist)
- [ ] Create README.md for all 10 `extensions/*/context/` directories
- [ ] Create README.md for all `extensions/*/rules/` directories (where they exist)
- [ ] Create README.md for all `extensions/*/scripts/` directories (where they exist)
- [ ] Create README.md for all 10 `extensions/*/skills/` directories
- [ ] Create README.md for `extensions/*/context/project/{domain}/` directories
- [ ] Update each extension root README.md to link to its subdirectories

**Timing**: 2.5 hours

### Phase 4: Docs Directory Organization [NOT STARTED]

**Goal**: Reorganize loose markdown files in docs/ and create missing subdirectory READMEs

**Tasks**:
- [ ] Create `.opencode/docs/examples/README.md`
- [ ] Move `.opencode/docs/memory-setup.md` → `.opencode/docs/guides/memory-setup.md`
- [ ] Move `.opencode/docs/memory-troubleshooting.md` → `.opencode/docs/guides/memory-troubleshooting.md`
- [ ] Move `.opencode/docs/remember-usage.md` → `.opencode/docs/guides/remember-usage.md`
- [ ] Update `.opencode/docs/README.md` to reflect new file locations
- [ ] Update `.opencode/docs/guides/README.md` to include moved files
- [ ] Update main `.opencode/README.md` if it references moved files
- [ ] Create any other missing subdirectory READMEs in docs/

**Timing**: 45 minutes

### Phase 5: Remaining Directories [NOT STARTED]

**Goal**: Create README.md files for all remaining directories (skills, hooks, logs, memory, scripts, systemd, templates, and deep nested directories)

**Tasks**:
- [ ] Create `.opencode/hooks/README.md`
- [ ] Create `.opencode/logs/README.md`
- [ ] Create `.opencode/memory/00-Inbox/README.md`
- [ ] Create `.opencode/memory/10-Memories/README.md`
- [ ] Create `.opencode/memory/20-Indices/README.md`
- [ ] Create `.opencode/memory/30-Templates/README.md`
- [ ] Create `.opencode/scripts/README.md`
- [ ] Create `.opencode/systemd/README.md`
- [ ] Create `.opencode/templates/README.md`
- [ ] Create README.md for all 13 `skills/skill-*/` directories
- [ ] Create README.md for formal extension deep subdirectories:
  - [ ] `extensions/formal/context/project/math/*/` (algebra, category-theory, etc.)
  - [ ] `extensions/formal/context/project/logic/*/` (domain, processes, standards)
- [ ] Create README.md for any other remaining domain-specific subdirectories

**Timing**: 1.5 hours

### Phase 6: Verification & Cross-Linking [NOT STARTED]

**Goal**: Verify all README files exist, check navigation links, ensure parent READMEs link to children

**Tasks**:
- [ ] Run directory scan to confirm 177 directories have README.md (100% coverage)
- [ ] Verify all parent README files link to their child subdirectory READMEs
- [ ] Verify all README files have correct parent navigation link (`../`, `../../`, etc.)
- [ ] Check for broken relative links in all README files
- [ ] Verify docs/ directory reorganization complete and all references updated
- [ ] Update main `.opencode/README.md` with any missing top-level links
- [ ] Run final git status to ensure all new files tracked

**Timing**: 45 minutes

## Navigation Linking Reference

All README files must include bidirectional navigation:

### Parent Links (by depth)

| Depth | Directory Pattern | Parent Link |
|-------|------------------|-------------|
| 1 | `.opencode/X/` | `../README.md` |
| 2 | `.opencode/X/Y/` | `../../README.md` |
| 3 | `.opencode/extensions/X/` | `../../README.md` |
| 4 | `.opencode/extensions/X/agents/` | `../../../README.md` |
| 5 | `.opencode/extensions/X/context/project/Y/` | `../../../../README.md` |
| 6 | `.opencode/extensions/X/context/project/Y/Z/` | `../../../../../README.md` |

### Child Links Format

Parent READMEs should link to child directories:

```markdown
## Subdirectories

- [agents/](agents/README.md) - Agent definitions and implementations
- [commands/](commands/README.md) - Command implementations
- [context/](context/README.md) - Context organization
```

## README.md Template

Create `.opencode/TEMPLATES/README-template.md`:

```markdown
# [Directory Name]

Brief description of the directory's purpose and contents.

## Contents

### Files

- `file1.md` - Description of what this file contains
- `file2.md` - Description of what this file contains

### Subdirectories

- [subdir1/](subdir1/README.md) - Brief description
- [subdir2/](subdir2/README.md) - Brief description

## [Optional: Usage/Context]

Additional information about using this directory's contents.

---

## Navigation

- [← Parent Directory](../README.md)
- [Subdirectory 1 →](subdir1/README.md)
- [Subdirectory 2 →](subdir2/README.md)
```

## Testing & Validation

- [ ] All 177 directories have README.md files
- [ ] All README files follow template structure
- [ ] All README files have correct parent navigation links
- [ ] All parent READMEs link to child subdirectory READMEs
- [ ] No broken relative links exist in any README file
- [ ] Docs/ directory reorganization complete (3 files moved)
- [ ] Main `.opencode/README.md` updated with new links
- [ ] Git status shows all expected new files

## Artifacts & Outputs

- `.opencode/TEMPLATES/README-template.md` - Standard template for future use
- 157 new `README.md` files across all directories
- Updated existing README files with new navigation links
- Reorganized `docs/` directory with files moved to `guides/`
- Verification report documenting 100% coverage

## Rollback/Contingency

If implementation fails or needs to be abandoned:

1. **Git reset**: `git reset --hard HEAD` before any commits (if no commits made)
2. **Selective removal**: If partially complete, remove only the new README files:
   ```bash
   find .opencode -name "README.md" -newer .opencode/README.md -delete
   ```
3. **Docs reversion**: Move files back from `guides/` to `docs/` root if needed
4. **Reference restoration**: Keep a backup of original parent README files before modification

**Partial completion strategy**: If time runs out, prioritize completing phases in order (core system is most important, then extensions, then remaining directories).