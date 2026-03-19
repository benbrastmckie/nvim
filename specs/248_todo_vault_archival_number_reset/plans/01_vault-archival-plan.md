# Implementation Plan: Task #248

- **Task**: 248 - Implement vault archival and number reset in /todo when tasks exceed 1000
- **Status**: [IMPLEMENTING]
- **Effort**: 4-6 hours
- **Dependencies**: None
- **Research Inputs**: [02_vault-renumbering-research.md](../reports/02_vault-renumbering-research.md)
- **Artifacts**: plans/01_vault-archival-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan implements vault archival functionality in the /todo command. When `next_project_number` exceeds 1000, the system moves the current archive to a numbered vault, resets task numbering, and renumbers active tasks > 1000. The state template already includes `project_numbering.policy: "increment_modulo_1000"`, indicating this feature was anticipated during initial design.

### Research Integration

Key findings from research report 02_vault-renumbering-research.md:
- Five components need modification: skill-todo, state.json schema, directory operations, TODO.md updates, documentation
- The vault operation involves 6 sub-phases: detection, confirmation, vault creation, renumbering, reset, and TODO.md header update
- Directory renaming must handle both 3-digit and 4-digit padded directories
- Dependencies between tasks > 1000 must also be renumbered

## Goals & Non-Goals

**Goals**:
- Implement vault threshold detection (next_project_number > 1000)
- Create vault directory structure with metadata
- Renumber active tasks > 1000 by subtracting 1000
- Update all artifact paths and dependencies during renumbering
- Rename task directories from 4-digit to 3-digit padding
- Reset next_project_number after renumbering
- Document vault operation in CLAUDE.md and rules

**Non-Goals**:
- Automatic vault triggering without user confirmation
- Vault rollback/undo functionality
- Cross-vault task references
- Vault merging or consolidation

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Directory rename failure | Medium | Low | Validate source exists before rename; atomic transaction |
| Artifact path mismatch | High | Medium | Use jq for atomic updates; validate paths after update |
| Broken dependencies | High | Medium | Update dependencies in same transaction as renumber |
| Partial completion | High | Low | Implement transaction with rollback markers |
| Race condition | Medium | Low | Lock state files during vault operation |

## Implementation Phases

### Phase 1: Schema Extensions [COMPLETED]

**Goal**: Add vault-related fields to state schema template and documentation

**Tasks**:
- [ ] Add `vault_count` field to state-template.json (default: 0)
- [ ] Add `vault_history` array to state-template.json
- [ ] Update state-json-schema.md with vault field documentation
- [ ] Add vault_history entry schema with fields: vault_number, vault_dir, created_at, task_range, archived_count, final_task_number

**Timing**: 30 minutes

**Files to modify**:
- `.claude/context/core/templates/state-template.json` - Add vault_count and vault_history fields
- `.claude/context/core/reference/state-json-schema.md` - Document vault schema

**Verification**:
- state-template.json contains vault_count: 0 and vault_history: []
- state-json-schema.md includes Vault Fields section with complete field reference

---

### Phase 2: Vault Detection Stage [IN PROGRESS]

**Goal**: Add vault threshold detection to skill-todo

**Tasks**:
- [ ] Add Stage 10.5: DetectVaultThreshold after ArchiveTasks stage
- [ ] Implement detection logic: check if next_project_number > 1000
- [ ] Identify active tasks with project_number > 1000
- [ ] Calculate renumbering mappings (old_number -> new_number = old - 1000)
- [ ] Store detection results for subsequent stages

**Timing**: 45 minutes

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Add Stage 10.5 DetectVaultThreshold

**Verification**:
- Detection stage identifies tasks > 1000 correctly
- Renumber mapping calculated correctly (e.g., 1003 -> 3)

---

### Phase 3: Vault User Confirmation [NOT STARTED]

**Goal**: Add interactive user confirmation for vault operation

**Tasks**:
- [ ] Add Stage 10.6: VaultConfirmation
- [ ] Implement AskUserQuestion prompt showing:
  - Current next_project_number value
  - Number of active tasks to be renumbered
  - Renumbering preview (1001 -> 1, 1003 -> 3, etc.)
- [ ] Handle user response: Yes (proceed) or No (skip)
- [ ] Store vault_approved flag for subsequent stages

**Timing**: 30 minutes

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Add Stage 10.6 VaultConfirmation

**Verification**:
- AskUserQuestion displays correct information
- User can approve or decline vault operation
- Declining skips all vault-related stages

---

### Phase 4: Vault Creation [NOT STARTED]

**Goal**: Create vault directory structure and move archive contents

**Tasks**:
- [ ] Add Stage 10.7: CreateVault
- [ ] Implement vault directory creation: specs/vault/{NN-vault}/
- [ ] Move specs/archive/ contents to specs/vault/{NN-vault}/archive/
- [ ] Move specs/archive/state.json to specs/vault/{NN-vault}/state.json
- [ ] Create specs/vault/{NN-vault}/meta.json with vault metadata:
  - vault_number, created_at, task_range, archived_count, last_task_number
- [ ] Reinitialize empty specs/archive/ with fresh state.json

**Timing**: 45 minutes

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Add Stage 10.7 CreateVault

**Verification**:
- Vault directory created with correct numbering (01-vault, 02-vault, etc.)
- Archive contents moved successfully
- meta.json contains accurate metadata
- Fresh archive/state.json created with empty completed_projects

---

### Phase 5: Task Renumbering [NOT STARTED]

**Goal**: Renumber active tasks > 1000 and update all references

**Tasks**:
- [ ] Add Stage 10.8: RenumberTasks
- [ ] For each task > 1000, update state.json:
  - project_number = old_number - 1000
  - Update all artifact paths (specs/1003_slug/ -> specs/003_slug/)
  - Update dependencies array (1002 -> 2)
- [ ] Rename task directories using padded format:
  - Find source: specs/1003_slug/ or specs/{4-digit}_slug/
  - Rename to: specs/003_slug/ (3-digit padded)
- [ ] Update TODO.md entries:
  - Task headers: ### 1003. Title -> ### 3. Title
  - Artifact links: Update all directory references

**Timing**: 1 hour

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Add Stage 10.8 RenumberTasks

**Verification**:
- All tasks > 1000 renumbered correctly
- Artifact paths updated in state.json
- Dependencies updated to new numbers
- Directories renamed to 3-digit format
- TODO.md entries updated with new numbers and paths

---

### Phase 6: State Reset [NOT STARTED]

**Goal**: Reset numbering state and update vault tracking

**Tasks**:
- [ ] Add Stage 10.9: ResetState
- [ ] Set next_project_number = max(renumbered tasks) + 1
  - Example: If tasks 1001, 1003, 1004 exist, set to 5
- [ ] Increment vault_count
- [ ] Add entry to vault_history array:
  - vault_number, vault_dir, created_at, task_range, archived_count, final_task_number
- [ ] Add vault transition comment to TODO.md:
  - `<!-- Vault transition: DATE - Tasks 1-999 archived to specs/vault/NN-vault/ -->`

**Timing**: 30 minutes

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Add Stage 10.9 ResetState

**Verification**:
- next_project_number set correctly based on renumbered tasks
- vault_count incremented
- vault_history contains new entry with accurate metadata
- TODO.md has vault transition comment

---

### Phase 7: Documentation Updates [NOT STARTED]

**Goal**: Update documentation with vault operation details

**Tasks**:
- [ ] Update .claude/commands/todo.md with vault operation documentation
- [ ] Update .claude/rules/state-management.md with vault schema fields
- [ ] Add vault operation section to CLAUDE.md State Synchronization
- [ ] Document edge cases: no tasks > 1000, gaps in numbering, OpenCode prefix handling

**Timing**: 45 minutes

**Files to modify**:
- `.claude/commands/todo.md` - Add vault operation section
- `.claude/rules/state-management.md` - Document vault_count and vault_history fields
- `.claude/CLAUDE.md` - Update State Synchronization section

**Verification**:
- All documentation accurately describes vault operation
- Edge cases documented
- User can understand vault trigger and behavior from docs

---

## Testing & Validation

- [ ] Create test state.json with next_project_number = 1005
- [ ] Create mock active tasks: 1001, 1003, 1004
- [ ] Execute vault operation with dry-run first
- [ ] Verify vault directory structure created correctly
- [ ] Verify tasks renumbered to 1, 3, 4
- [ ] Verify next_project_number set to 5
- [ ] Verify directories renamed from 4-digit to 3-digit format
- [ ] Verify artifact paths updated in state.json
- [ ] Verify dependencies updated
- [ ] Verify TODO.md entries updated
- [ ] Verify vault_history entry accurate

## Artifacts & Outputs

- plans/01_vault-archival-plan.md (this file)
- summaries/02_vault-archival-summary.md (after implementation)
- Modified files:
  - `.claude/skills/skill-todo/SKILL.md`
  - `.claude/context/core/templates/state-template.json`
  - `.claude/context/core/reference/state-json-schema.md`
  - `.claude/commands/todo.md`
  - `.claude/rules/state-management.md`
  - `.claude/CLAUDE.md`

## Rollback/Contingency

If vault operation fails mid-execution:
1. Restore archive from vault directory (mv specs/vault/{NN-vault}/archive/* specs/archive/)
2. Restore archive/state.json from vault
3. Manually revert state.json active_projects to pre-renumber state
4. Remove vault directory
5. Decrement vault_count
6. Remove vault_history entry

For atomic safety, implement progress markers:
- `.vault_in_progress` - Created at vault start, removed on success
- Contains: vault_number, original_next_project_number, renumber_mappings
- On next /todo run: detect marker and offer recovery options
