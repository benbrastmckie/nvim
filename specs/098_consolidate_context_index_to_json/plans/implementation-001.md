# Implementation Plan: Task #98

- **Task**: 98 - Remove deprecated index.md and consolidate context index to JSON
- **Status**: [NOT STARTED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remove the deprecated `.claude/context/index.md` file and update all 18 active references in `.claude/` plus 17 references in `.opencode/` to use `index.json` consistently. The `index.schema.json` file is kept in place as it provides idiomatic JSON Schema documentation and IDE validation support. The migration guide is preserved and updated to reflect the completed transition.

### Research Integration

Research confirmed that index.md has been deprecated since 2026-02-24, contains a deprecation notice, and is fully superseded by index.json. All 18 `.claude/` references and 17 `.opencode/` references were catalogued and categorized. No runtime (bash/lua) code references index.md, reducing risk. The schema file serves a legitimate documentation purpose and should remain co-located with index.json.

## Goals & Non-Goals

**Goals**:
- Remove the deprecated index.md file from both `.claude/context/` and `.opencode/context/`
- Update all active references to point to index.json or remove them where redundant
- Update the migration guide to reflect completion of the transition
- Verify no functionality is broken after removal

**Non-Goals**:
- Modifying archive files in `specs/archive/`
- Moving or removing `index.schema.json`
- Restructuring the context discovery system
- Changing how index.json itself works

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missed reference causes agent load failure | Medium | Low | Comprehensive grep verified all references; post-removal grep verification |
| .opencode mirror diverges from .claude | Low | Low | Both updated in same implementation pass |
| Future contributors look for index.md | Low | Low | Migration guide documents the change; deprecation period was observed |

## Implementation Phases

### Phase 1: Update Agent and Skill References [NOT STARTED]

**Goal**: Update the 4 files in Category A (active agent/skill context loading) that directly load index.md as context. These are the highest-risk references since they affect agent behavior.

**Tasks**:
- [ ] Update `.claude/agents/general-implementation-agent.md` (line 53): change `@.claude/context/index.md` to `@.claude/context/index.json` or remove if agents already use jq-based discovery
- [ ] Update `.claude/agents/meta-builder-agent.md` (lines 70, 98, 130): update all 3 references from index.md to index.json in analyze mode context loading
- [ ] Update `.claude/skills/skill-orchestrator/SKILL.md` (line 17): update context loading reference
- [ ] Update `.claude/skills/skill-git-workflow/SKILL.md` (line 16): update context loading reference
- [ ] Update corresponding `.opencode/` mirror files:
  - `.opencode/agents/general-implementation.md`
  - `.opencode/agents/meta-builder.md`
  - `.opencode/agents/general-research.md`
  - `.opencode/skills/skill-orchestrator/SKILL.md`
  - `.opencode/skills/skill-git-workflow/SKILL.md`

**Timing**: 20 minutes

**Files to modify**:
- `.claude/agents/general-implementation-agent.md` - Remove or update index.md context reference
- `.claude/agents/meta-builder-agent.md` - Update 3 index.md references to index.json
- `.claude/skills/skill-orchestrator/SKILL.md` - Update context loading reference
- `.claude/skills/skill-git-workflow/SKILL.md` - Update context loading reference
- `.opencode/agents/general-implementation.md` - Mirror update
- `.opencode/agents/meta-builder.md` - Mirror update
- `.opencode/agents/general-research.md` - Mirror update (1 reference)
- `.opencode/skills/skill-orchestrator/SKILL.md` - Mirror update
- `.opencode/skills/skill-git-workflow/SKILL.md` - Mirror update

**Verification**:
- Grep for `index\.md` in all modified files returns zero matches
- Each modified file still contains valid context loading references

---

### Phase 2: Update Documentation and Template References [NOT STARTED]

**Goal**: Update Categories B, C, and D (documentation, templates, config schemas, workflow docs) to reference index.json instead of index.md. These are lower risk since they affect documentation accuracy rather than runtime behavior.

**Tasks**:
- [ ] Update `.claude/docs/guides/context-loading-best-practices.md` (18 occurrences): bulk replace `index.md` with `index.json` in YAML config examples
- [ ] Update `.claude/context/core/schemas/subagent-frontmatter.yaml` (1 occurrence): update index field default
- [ ] Update `.claude/context/core/templates/agent-template.md` (5 occurrences): update template examples
- [ ] Update `.claude/context/core/formats/frontmatter.md` (5 occurrences): update format examples
- [ ] Update `.claude/context/core/standards/xml-structure.md` (3 occurrences): update XML structure examples
- [ ] Update `.claude/context/project/processes/planning-workflow.md` (1 occurrence): update workflow reference
- [ ] Update `.claude/context/project/processes/research-workflow.md` (1 occurrence): update workflow reference
- [ ] Update `.claude/context/project/processes/implementation-workflow.md` (1 occurrence): update workflow reference
- [ ] Update `.claude/context/core/orchestration/routing.md` (1 occurrence): update routing reference
- [ ] Update `.claude/context/project/meta/architecture-principles.md` (2 occurrences): update architecture references
- [ ] Update `.claude/docs/guides/adding-domains.md` (1 occurrence): update domain guide reference
- [ ] Update `.claude/docs/templates/agent-template.md` (2 occurrences): update template references
- [ ] Update `.claude/docs/templates/README.md` (2 occurrences): update template README references
- [ ] Update corresponding `.opencode/` mirror files (12 files with matching references)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/docs/guides/context-loading-best-practices.md` - Replace 18 occurrences
- `.claude/context/core/schemas/subagent-frontmatter.yaml` - Replace 1 occurrence
- `.claude/context/core/templates/agent-template.md` - Replace 5 occurrences
- `.claude/context/core/formats/frontmatter.md` - Replace 5 occurrences
- `.claude/context/core/standards/xml-structure.md` - Replace 3 occurrences
- `.claude/context/project/processes/planning-workflow.md` - Replace 1 occurrence
- `.claude/context/project/processes/research-workflow.md` - Replace 1 occurrence
- `.claude/context/project/processes/implementation-workflow.md` - Replace 1 occurrence
- `.claude/context/core/orchestration/routing.md` - Replace 1 occurrence
- `.claude/context/project/meta/architecture-principles.md` - Replace 2 occurrences
- `.claude/docs/guides/adding-domains.md` - Replace 1 occurrence
- `.claude/docs/templates/agent-template.md` - Replace 2 occurrences
- `.claude/docs/templates/README.md` - Replace 2 occurrences
- `.opencode/` mirror equivalents - Replace matching occurrences

**Verification**:
- Grep for `index\.md` in all modified files returns zero matches (excluding self-references in migration guide)
- YAML files still parse correctly
- Template files maintain valid structure

---

### Phase 3: Update Migration Guide and Delete index.md [NOT STARTED]

**Goal**: Update the migration guide to reflect the completed transition, then delete the deprecated index.md files from both `.claude/context/` and `.opencode/context/`.

**Tasks**:
- [ ] Update `.claude/docs/guides/development/context-index-migration.md`: change language from "being deprecated" to "has been removed", update status to reflect completed migration, preserve as historical reference
- [ ] Delete `.claude/context/index.md`
- [ ] Delete `.opencode/context/index.md` (if it exists as a mirror copy)
- [ ] Verify `index.schema.json` `$schema` reference in `index.json` is unaffected (it references schema, not index.md)

**Timing**: 10 minutes

**Files to modify**:
- `.claude/docs/guides/development/context-index-migration.md` - Update migration status language
- `.claude/context/index.md` - DELETE
- `.opencode/context/index.md` - DELETE

**Verification**:
- `.claude/context/index.md` does not exist
- `.opencode/context/index.md` does not exist
- `.claude/context/index.json` still exists and is unchanged
- `.claude/context/index.schema.json` still exists and is unchanged
- `index.json` `$schema` pointer still references `./index.schema.json` correctly

---

### Phase 4: Final Verification [NOT STARTED]

**Goal**: Comprehensive verification that no remaining references to index.md exist in active files and that the context discovery system works correctly with index.json only.

**Tasks**:
- [ ] Run `grep -rl "index\.md" .claude/` and verify only the migration guide and possibly context-discovery.md (schema validation examples) still reference it -- and only in historical/documentation context
- [ ] Run `grep -rl "index\.md" .opencode/` and verify zero active references remain
- [ ] Verify `index.json` is valid JSON: `python3 -c "import json; json.load(open('.claude/context/index.json'))"`
- [ ] Verify no self-referencing entry for index.md exists inside index.json itself
- [ ] Spot-check 2-3 modified agent files to confirm context loading sections are coherent

**Timing**: 10 minutes

**Files to modify**: None (verification only)

**Verification**:
- Zero unexpected references to index.md in `.claude/` (migration guide references are acceptable as historical documentation)
- Zero references to index.md in `.opencode/`
- index.json parses as valid JSON
- No entries in index.json reference the deleted index.md file

## Testing & Validation

- [ ] Grep verification: no unexpected index.md references remain in active files
- [ ] JSON validation: index.json parses correctly
- [ ] Schema validation: index.schema.json is present and referenced by index.json
- [ ] File deletion confirmed: index.md removed from both .claude/context/ and .opencode/context/
- [ ] Migration guide updated to reflect completed status
- [ ] No archive files were modified

## Artifacts & Outputs

- Updated 18 files in `.claude/` to remove index.md references
- Updated 17 files in `.opencode/` mirror to remove index.md references
- Deleted `.claude/context/index.md`
- Deleted `.opencode/context/index.md`
- Updated migration guide to document completed transition
- Preserved `index.schema.json` in place (no changes)

## Rollback/Contingency

If issues are discovered after removal:
1. `git checkout HEAD -- .claude/context/index.md` to restore the deleted file
2. `git checkout HEAD -- .opencode/context/index.md` to restore the mirror copy
3. All reference updates can be reverted with `git checkout HEAD -- <file>` for individual files
4. Since index.md was already deprecated and not used by runtime code, rollback risk is minimal
