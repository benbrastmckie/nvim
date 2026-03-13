# Implementation Plan: Task #198

- **Task**: 198 - Complete Artifact Naming Convention Migration
- **Status**: [NOT STARTED]
- **Effort**: 1.5-2 hours
- **Dependencies**: None
- **Research Inputs**: [01_claude-commit-review.md](../reports/01_claude-commit-review.md)
- **Artifacts**: plans/02_complete-naming-migration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Task 195 partially migrated the artifact naming convention from `research-001.md`/`implementation-001.md` to `MM_{short-slug}.md`. Research found 45+ documentation, rules, and context files still using the old convention. This plan completes the migration by updating all remaining files, prioritized by impact: rules and README first (highest agent exposure), then workflow processes and format specs, then examples and patterns.

### Research Integration

From research report 01_claude-commit-review.md:
- 45+ files still reference old convention
- Rules files (state-management.md, git-workflow.md) auto-loaded by agents
- README.md is primary documentation entry point
- Format specs define artifact structure

## Goals & Non-Goals

**Goals**:
- Update all remaining old convention references to `MM_{short-slug}.md`
- Maintain consistency across all .claude/ documentation
- Prioritize high-impact files that agents reference frequently

**Non-Goals**:
- Restructure documentation beyond naming convention updates
- Add new documentation or features
- Modify actual artifact files in specs/ directories

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Miss some occurrences | Low | Medium | Grep verification after each phase |
| Break existing examples | Medium | Low | Update examples contextually, not blindly |
| Introduce typos | Low | Low | Review each change in context |

## Implementation Phases

### Phase 1: Update Rules Files [NOT STARTED]

**Goal**: Update auto-loaded rules that agents reference constantly

**Tasks**:
- [ ] Update `.claude/rules/state-management.md`:
  - Line 93: `reports/research-001.md` -> `reports/MM_{short-slug}.md`
  - Line 233: Artifact Linking examples
  - Line 239: Research Completion example
  - Line 278: Directory Creation example
- [ ] Update `.claude/rules/git-workflow.md`:
  - Line 57: Example modified files in commit scope

**Timing**: 15 minutes

**Files to modify**:
- `.claude/rules/state-management.md` - 4 references
- `.claude/rules/git-workflow.md` - 1 reference

**Verification**:
- `grep -n "research-001\|implementation-001\|research-NNN\|impl-NNN" .claude/rules/*.md` returns empty

---

### Phase 2: Update README and Core Documentation [NOT STARTED]

**Goal**: Update primary documentation entry point and high-visibility docs

**Tasks**:
- [ ] Update `.claude/README.md`:
  - Lines 365-366: Artifact path examples in Artifact Paths section
  - Line 422: Example artifact reference
  - Line 434: Example artifact reference
  - Lines 1054-1055: Additional examples
- [ ] Update `.claude/docs/architecture/system-overview.md`:
  - Lines 58-59: Artifact path examples
  - Line 142: Research report reference
- [ ] Update `.claude/docs/guides/user-guide.md`:
  - Search and update any old convention references
- [ ] Update `.claude/docs/guides/creating-agents.md`:
  - Search and update any old convention references

**Timing**: 25 minutes

**Files to modify**:
- `.claude/README.md` - 6 references
- `.claude/docs/architecture/system-overview.md` - 3 references
- `.claude/docs/guides/user-guide.md` - verify/update
- `.claude/docs/guides/creating-agents.md` - verify/update

**Verification**:
- `grep -rn "research-001\|implementation-001" .claude/README.md .claude/docs/` returns empty

---

### Phase 3: Update Format Specifications and Workflows [NOT STARTED]

**Goal**: Update format definitions that agents use when creating artifacts

**Tasks**:
- [ ] Update `.claude/context/core/formats/plan-format.md`:
  - Line 20: Example artifacts path
  - Lines 42, 59: reports_integrated path example
  - Lines 103, 131-132: Example skeleton artifacts
- [ ] Update `.claude/context/core/formats/return-metadata-file.md`:
  - Lines 27, 191, 226, 440: Artifact path examples
- [ ] Update `.claude/context/core/formats/command-output.md`:
  - Lines 74, 242, 252, 267, 277, 309: Output format examples
- [ ] Update `.claude/context/core/formats/summary-format.md`:
  - Search and update any old convention references
- [ ] Update `.claude/context/project/processes/research-workflow.md`:
  - Lines 161, 531: Research output path examples
- [ ] Update `.claude/context/project/processes/planning-workflow.md`:
  - Lines 20, 30, 341-343, 488: Plan path examples

**Timing**: 30 minutes

**Files to modify**:
- `.claude/context/core/formats/plan-format.md` - 5+ references
- `.claude/context/core/formats/return-metadata-file.md` - 4 references
- `.claude/context/core/formats/command-output.md` - 6 references
- `.claude/context/core/formats/summary-format.md` - verify/update
- `.claude/context/project/processes/research-workflow.md` - 2 references
- `.claude/context/project/processes/planning-workflow.md` - 5 references

**Verification**:
- `grep -rn "research-001\|implementation-001\|research-NNN" .claude/context/core/formats/ .claude/context/project/processes/` returns empty

---

### Phase 4: Update Remaining Context and Example Files [NOT STARTED]

**Goal**: Complete migration in all remaining files

**Tasks**:
- [ ] Update `.claude/docs/examples/research-flow-example.md`:
  - Lines 48, 228, 254, 292, 350: Research flow examples
- [ ] Update remaining context files identified by grep:
  - `.claude/context/core/patterns/jq-escaping-workarounds.md`
  - `.claude/context/core/patterns/file-metadata-exchange.md`
  - `.claude/context/core/patterns/inline-status-update.md`
  - `.claude/context/core/patterns/metadata-file-return.md`
  - `.claude/context/core/patterns/early-metadata-pattern.md`
  - `.claude/context/core/patterns/anti-stop-patterns.md`
  - `.claude/context/core/workflows/preflight-postflight.md`
  - `.claude/context/core/workflows/status-transitions.md`
  - `.claude/context/core/orchestration/delegation.md`
  - `.claude/context/core/orchestration/routing.md`
  - `.claude/context/core/orchestration/orchestration-reference.md`
  - `.claude/context/core/architecture/system-overview.md`
  - `.claude/context/core/standards/status-markers.md`
  - `.claude/context/core/formats/subagent-return.md`
- [ ] Update extension context files:
  - `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`
  - `.claude/extensions/web/skills/skill-web-research/SKILL.md`
  - `.claude/extensions/nix/agents/nix-implementation-agent.md`
  - `.claude/extensions/nvim/agents/neovim-implementation-agent.md`
  - `.claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`
  - `.claude/extensions/web/agents/web-implementation-agent.md`
  - `.claude/extensions/nix/agents/nix-research-agent.md`
  - `.claude/extensions/nvim/agents/neovim-research-agent.md`
  - `.claude/extensions/formal/agents/*.md`
  - `.claude/extensions/web/agents/web-research-agent.md`
  - `.claude/extensions/memory/context/project/memory/*.md`
- [ ] Update any remaining guides:
  - `.claude/docs/guides/creating-skills.md`

**Timing**: 40 minutes

**Files to modify**:
- All files listed above (25+ files)

**Verification**:
- `grep -rn "research-001\|implementation-001\|research-NNN\|impl-NNN" .claude/` returns only false positives (if any)

---

## Testing & Validation

- [ ] Run comprehensive grep to verify no old convention references remain
- [ ] Spot-check 5 updated files to ensure changes are contextually correct
- [ ] Verify plan-format.md example skeleton is internally consistent
- [ ] Verify README.md Artifact Paths section matches CLAUDE.md

## Artifacts & Outputs

- `plans/02_complete-naming-migration.md` (this file)
- `summaries/03_naming-migration-summary.md` (upon completion)

## Rollback/Contingency

All changes are to documentation files. If issues arise:
1. Revert to previous git commit
2. Re-examine which files actually need updates
3. Apply fixes incrementally with verification after each
