# Implementation Plan: Create Core Extension README

- **Task**: 474 - Create core extension README.md
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_team-research.md
- **Artifacts**: plans/01_core-extension-readme.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The core extension is the only extension without a README.md, causing `check-extension-docs.sh` to fail with two errors: missing README and "no routing block". This plan creates a README following the "System Payload Inventory" pattern (~150-180 lines) and fixes the validator script to exempt core from the routing block check. Definition of done: `check-extension-docs.sh` exits 0 with no failures for the core extension.

### Research Integration

- **reports/01_team-research.md**: Team research from 4 teammates identified core's unique nature as system payload (not domain extension), the validator's two-failure problem, recommended README structure, prior-art patterns from formal/filetypes/memory extensions, and the `routing_exempt` manifest flag approach.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

- **CI enforcement of doc-lint**: This task directly unblocks the CI doc-lint roadmap item by making `check-extension-docs.sh` exit 0 for core.
- **Manifest-driven README generation**: The manual README structure will inform the future generation script design.

## Goals & Non-Goals

**Goals**:
- Create `extensions/core/README.md` that passes all `check-extension-docs.sh` validators
- List all 14 commands by slash name (validator grep requirement)
- Explain core's role as foundational system payload and why it has no task-type routing
- Fix `check-extension-docs.sh` to exempt routing-exempt extensions from the routing block check
- Add `routing_exempt` flag to core's `manifest.json`

**Non-Goals**:
- Duplicating content already in `EXTENSION.md` or `docs/README.md`
- Creating a README template for other infrastructure extensions
- Modifying the manifest-driven generation script (future roadmap item)
- Changing core's actual functionality or provides

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| README content drifts from manifest.json over time | M | M | Use counts sparingly; cross-reference manifest.json for detailed lists |
| Validator grep patterns change, breaking README | L | L | Test README against current validator before finalizing |
| `routing_exempt` flag breaks other validator logic | M | L | Scope the flag check narrowly to `check_routing_block()` only |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Create core extension README.md [NOT STARTED]

**Goal**: Write the README following the System Payload Inventory pattern that passes all validator content checks.

**Tasks**:
- [ ] Read existing READMEs for structural reference (nix/README.md, formal/README.md, filetypes/README.md)
- [ ] Read core's manifest.json and EXTENSION.md to extract current provides inventory
- [ ] Write `extensions/core/README.md` with these sections:
  - Overview: core as foundational system payload, always active, not a domain extension
  - Always Active: explain no installation/loading needed
  - Commands: table of all 14 commands with `/cmdname` format (validator requirement)
  - Agents: condensed table of 8 agents
  - Architecture: directory tree of core's structure
  - No Task-Type Routing: explain why core has no routing block (following formal/filetypes pattern)
  - Intentionally Omitted Sections: list omitted sections with reasons (following formal/README.md pattern)
  - Related Documentation: links to EXTENSION.md, docs/README.md, CLAUDE.md
- [ ] Target ~150-180 lines

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/README.md` - Create new file

**Verification**:
- File exists at `.claude/extensions/core/README.md`
- All 14 command names appear as `/<cmdname>` in the file
- Sections follow the System Payload Inventory pattern

---

### Phase 2: Fix validator routing block exemption [NOT STARTED]

**Goal**: Add `routing_exempt` support to manifest.json and the validator script so core passes the routing block check.

**Tasks**:
- [ ] Read `check-extension-docs.sh` to locate the `check_routing_block()` function
- [ ] Add `"routing_exempt": true` to `.claude/extensions/core/manifest.json`
- [ ] Update `check_routing_block()` in `check-extension-docs.sh` to skip extensions where manifest.json contains `routing_exempt: true`
- [ ] Verify the routing_exempt check is scoped narrowly (does not affect other validator functions)

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/manifest.json` - Add `routing_exempt` field
- `.claude/scripts/check-extension-docs.sh` - Update `check_routing_block()` to honor exemption

**Verification**:
- `jq '.routing_exempt' .claude/extensions/core/manifest.json` returns `true`
- `check_routing_block()` skips extensions with `routing_exempt: true`

---

### Phase 3: Validate and verify [NOT STARTED]

**Goal**: Run the full validator and confirm zero failures for core.

**Tasks**:
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and verify core passes all checks
- [ ] Verify no regressions for other extensions (all should still pass their existing checks)
- [ ] Review README for accuracy against manifest.json provides inventory

**Timing**: 30 minutes

**Depends on**: 1, 2

**Files to modify**:
- `.claude/extensions/core/README.md` - Fix any issues found during validation
- `.claude/scripts/check-extension-docs.sh` - Fix any regressions found

**Verification**:
- `check-extension-docs.sh` exits 0 with no failures
- All 14 extensions pass their respective checks
- README content accurately reflects manifest.json

## Testing & Validation

- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 with no core failures
- [ ] `grep -c '/[a-z]' .claude/extensions/core/README.md` confirms all 14 commands present
- [ ] No regressions: other extensions still pass all validator checks
- [ ] README is ~150-180 lines and does not duplicate EXTENSION.md content

## Artifacts & Outputs

- `.claude/extensions/core/README.md` - New README file
- `.claude/extensions/core/manifest.json` - Updated with `routing_exempt` flag
- `.claude/scripts/check-extension-docs.sh` - Updated with routing exemption logic

## Rollback/Contingency

- Delete `.claude/extensions/core/README.md` to revert to pre-task state
- Revert `manifest.json` changes with `git checkout .claude/extensions/core/manifest.json`
- Revert script changes with `git checkout .claude/scripts/check-extension-docs.sh`
- All changes are additive; no existing functionality is modified
