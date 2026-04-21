# Implementation Plan: Consolidate Extension System Docs

- **Task**: 476 - Consolidate extension system documentation into single source of truth
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/476_consolidate_extension_system_docs/reports/01_consolidate-ext-docs.md
- **Artifacts**: plans/01_consolidate-ext-docs.md (this file)
- **Standards**: plan-format.md, artifact-formats.md, state-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three documentation files describing the extension system have drifted out of sync with the Lua implementation and with each other. The architecture doc still describes section injection for CLAUDE.md, both the architecture doc and how-to guide claim conflicts cause abort, unload dependency handling is described as "warning + confirm" instead of the actual hard block, and provides/loader coverage is incomplete. Additionally, new files (loader-reference.md, index.schema.json) and validators require fields the loader never writes. This plan consolidates all docs to reflect the Lua ground truth, eliminates duplication by designating clear ownership per concept, and aligns validators with actual schema.

### Research Integration

The research report (01_consolidate-ext-docs.md) audited all 6 Lua source files against all 3 documentation files, 2 new untracked files, and 3 validator scripts. It identified 9 contradiction categories (sections 3.1-3.9), 7 duplication zones (sections 4.1-4.7), and validator mismatches (section 5). Key findings:
- `generate_claudemd()` is the ground truth for CLAUDE.md generation; section injection references are stale
- Conflict handling allows user override via confirmation dialog, not abort
- Unload with dependents is a hard block (ERROR + return false), not a warning
- 5 of 12 provides categories missing from architecture and how-to docs
- index.schema.json and validate-context-index.sh require version/generated fields the loader never writes

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

- Advances "Agent System Quality" items: this consolidation eliminates doc drift and stale references
- Supports "CI enforcement of doc-lint": fixing validator alignment makes check-extension-docs.sh reliable
- Supports "Subagent-return reference cleanup": the sweep through docs may catch stale references

## Goals & Non-Goals

**Goals**:
- Make extension-system.md the single comprehensive architecture reference with all implementation details
- Reduce extension-development.md to a focused agent-facing guide that cross-references the architecture doc
- Reduce creating-extensions.md to a step-by-step tutorial that cross-references the architecture doc
- Fix all 9 contradiction categories identified in research
- Align index.schema.json and validate-context-index.sh with actual index.json schema
- Wire loader-reference.md and index.schema.json into index.json

**Non-Goals**:
- Modifying the Lua implementation (docs align to code, not vice versa)
- Adding new features to the extension system
- Restructuring file paths (stability for agent context loading)
- Updating project-overview.md (its two-layer description is brief and correct enough)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agent context breaks if extension-development.md loses essential info | H | M | Keep all agent-needed information in the guide; only move detailed internals to architecture doc |
| Removing duplication makes docs less self-contained | M | M | Add clear cross-reference links with section anchors at each deduplication point |
| Validator changes reveal real data issues in index.json | L | L | Run validators after changes to confirm alignment; fix any revealed issues |
| Large diff makes review difficult | M | L | Phase the work so each phase produces a reviewable, independently correct change |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix extension-system.md (Architecture Reference) [COMPLETED]

**Goal**: Make extension-system.md fully accurate against the Lua implementation, covering all 12 provides categories, all 12 loader functions, correct CLAUDE.md generation, correct conflict/unload behavior, and correct schema examples.

**Tasks**:
- [ ] Replace section injection diagram and language with `generate_claudemd()` documentation (research 3.1: lines 25, 178-179, 188-196, 258, 279)
- [ ] Fix conflict handling from "abort" to "confirmation dialog with override option" (research 3.2: lines 391-395)
- [ ] Fix unload dependency handling from "warning + confirm" to "hard block with ERROR notification" (research 3.3: lines 272-273)
- [ ] Add missing 5 provides categories: data, docs, templates, systemd, root_files (research 3.4)
- [ ] Add missing 6 loader functions: copy_hooks, copy_docs, copy_templates, copy_systemd, copy_root_files, copy_data_dirs (research 3.5)
- [ ] Fix extensions.json schema example: remove merged_sections.claudemd, add data_skeleton_files (research 3.6)
- [ ] Clarify mcp_servers vs merge_targets.settings relationship (research 3.9)
- [ ] Add complete merger function list including generate_claudemd() (research 1.5)
- [ ] Cross-reference loader-reference.md for detailed function signatures

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/docs/architecture/extension-system.md` - Major rewrite of CLAUDE.md generation, conflict handling, unload behavior, provides/loader coverage, schema examples

**Verification**:
- All 12 provides categories documented
- All 12 loader functions listed
- No references to section injection for CLAUDE.md
- Conflict handling says "confirmation dialog" not "abort"
- Unload dependency says "hard block" not "warning + confirm"
- extensions.json example matches actual on-disk format

---

### Phase 2: Align Validators and Schema with Reality [COMPLETED]

**Goal**: Fix index.schema.json and validate-context-index.sh so they match the actual index.json format the loader produces, and wire new files into index.json.

**Tasks**:
- [ ] Update index.schema.json: make `version` and `generated` optional (not required), keep `entries` required (research 3.7)
- [ ] Update validate-context-index.sh: remove requirement for `version` and `generated` fields, keep entry-level validation (research 5.1)
- [ ] Add index.json entries for loader-reference.md and index.schema.json with appropriate load_when conditions
- [ ] Run validate-context-index.sh against actual index.json to confirm it passes
- [ ] Run validate-wiring.sh to confirm no regressions

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `.claude/context/index.schema.json` - Make version/generated optional
- `.claude/scripts/validate-context-index.sh` - Remove version/generated requirement
- `.claude/context/index.json` - Add entries for loader-reference.md and index.schema.json

**Verification**:
- `bash .claude/scripts/validate-context-index.sh` exits 0
- `bash .claude/scripts/validate-wiring.sh` exits 0
- index.schema.json required fields match actual index.json structure

---

### Phase 3: Deduplicate extension-development.md and creating-extensions.md [COMPLETED]

**Goal**: Remove duplicated content from the agent guide and how-to guide, replacing verbose sections with cross-references to extension-system.md while retaining all information agents and developers need in context.

**Tasks**:
- [ ] extension-development.md: Fix unload dependency handling from "warning + confirm" to "hard block" (research 3.3: lines 254-258)
- [ ] extension-development.md: Replace full manifest schema example with a concise summary table + cross-reference to extension-system.md
- [ ] extension-development.md: Replace duplicated two-layer architecture explanation with brief statement + cross-reference
- [ ] extension-development.md: Replace duplicated directory structure listing with cross-reference
- [ ] extension-development.md: Verify all 12 provides categories remain listed (this doc has them -- do not remove)
- [ ] creating-extensions.md: Fix conflict handling language from "abort" to "confirmation dialog" (research 3.2: lines 657-660)
- [ ] creating-extensions.md: Fix task_type from required to optional (research 3.8: line 106)
- [ ] creating-extensions.md: Add missing 5 provides categories (data, docs, templates, systemd, root_files)
- [ ] creating-extensions.md: Update "Content injected into CLAUDE.md" to "Content included via generate_claudemd()" (research 3.1: line 117)
- [ ] creating-extensions.md: Replace full manifest template with streamlined version + cross-reference
- [ ] creating-extensions.md: Replace duplicated resource-only extension section with cross-reference

**Timing**: 1.25 hours

**Depends on**: 1

**Files to modify**:
- `.claude/context/guides/extension-development.md` - Fix unload behavior, deduplicate via cross-references
- `.claude/docs/guides/creating-extensions.md` - Fix contradictions, add missing provides, deduplicate via cross-references

**Verification**:
- extension-development.md still contains all 12 provides categories
- No doc claims conflicts cause abort
- No doc claims unload with dependents allows user confirmation
- task_type not marked as required in any doc
- Cross-references to extension-system.md use correct section anchors
- grep for "inject_section" and "section marker" returns zero hits across all three docs (for CLAUDE.md context)

---

### Phase 4: Update project-overview.md and Final Validation [COMPLETED]

**Goal**: Ensure project-overview.md cross-references are correct, run all validators, and confirm end-to-end consistency.

**Tasks**:
- [ ] Update project-overview.md if its extension system description references stale concepts (check two-layer architecture description)
- [ ] Run check-extension-docs.sh to validate extension manifest/doc consistency
- [ ] Run validate-context-index.sh to confirm index.json alignment
- [ ] Run validate-wiring.sh to confirm skill/agent wiring
- [ ] Grep all .claude/ docs for stale terms: "inject_section" (in CLAUDE.md context), "section marker", "loading is aborted", "warning.*confirm.*unload"
- [ ] Verify loader-reference.md is referenced from extension-system.md
- [ ] Verify index.schema.json is referenced from extension-system.md or validate-context-index.sh

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3

**Files to modify**:
- `.claude/context/repo/project-overview.md` - Update extension references if stale (may be no-op)

**Verification**:
- All three validator scripts exit 0
- Zero stale terminology hits across .claude/ docs
- loader-reference.md and index.schema.json properly wired into the documentation graph

## Testing & Validation

- [ ] `bash .claude/scripts/validate-context-index.sh` exits 0
- [ ] `bash .claude/scripts/validate-wiring.sh` exits 0
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0
- [ ] Grep for "inject_section" in CLAUDE.md context across all docs returns 0 matches
- [ ] Grep for "loading is aborted" across all docs returns 0 matches
- [ ] All 12 provides categories documented in extension-system.md
- [ ] All 12 loader functions documented in extension-system.md
- [ ] extension-development.md retains all agent-needed information (provides list, manifest essentials, dependency system)
- [ ] Cross-references between docs resolve to valid section anchors

## Artifacts & Outputs

- `.claude/docs/architecture/extension-system.md` - Rewritten as single source of truth
- `.claude/context/guides/extension-development.md` - Streamlined agent guide with cross-references
- `.claude/docs/guides/creating-extensions.md` - Streamlined tutorial with cross-references
- `.claude/context/index.schema.json` - Corrected schema (version/generated optional)
- `.claude/scripts/validate-context-index.sh` - Aligned with actual index.json format
- `.claude/context/index.json` - New entries for loader-reference.md and index.schema.json
- `.claude/context/repo/project-overview.md` - Minor updates if needed

## Rollback/Contingency

All changes are to documentation and validation scripts within `.claude/`. Git revert of the implementation commit(s) restores the previous state. No runtime behavior depends on these files -- they are consumed by agents and validators only. If a partial rollback is needed, each phase produces independently correct changes that can be reverted individually.
