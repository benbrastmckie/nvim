# Research Report: Task #248

**Task**: 248 - Implement vault archival and number reset in /todo when tasks exceed 1000
**Generated**: 2026-03-19
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: When next_project_number exceeds 1000, /todo initiates a special vault operation that moves all archived tasks into a numbered vault directory (specs/vault/{NN-vault}/) and resets task numbering back to 1.

**Scope**: /todo command, state.json schema, directory structure
**Affected Components**: .claude/commands/todo.md, specs/state.json, specs/archive/
**Domain**: meta
**Language**: meta

## Task Requirements

Implement a complete vault archival system with three integrated components:

### 1. Vault State Schema Design

Define how vault operations are tracked in state.json:

- Add `vault_count` integer field tracking number of vaults created (starts at 0)
- Add `vault_history` array tracking past vault operations with metadata
- Vault directory naming convention: `specs/vault/{NN-vault}/` where NN is zero-padded vault number (e.g., `01-vault`, `02-vault`)
- Each vault entry records: vault_number, created_at, task_range (first-last archived task numbers), archived_count

Example state.json extension:
```json
{
  "next_project_number": 1,
  "vault_count": 1,
  "vault_history": [
    {
      "vault_number": 1,
      "vault_dir": "specs/vault/01-vault/",
      "created_at": "2026-03-19T...",
      "task_range": "1-999",
      "archived_count": 847
    }
  ]
}
```

### 2. Vault Archival Operation in /todo

Threshold detection and vault triggering:

- Check: `next_project_number > 1000` at end of regular /todo run (after normal archival completes)
- If threshold met, prompt user with AskUserQuestion before proceeding
- Vault operation steps:
  1. Create `specs/vault/{NN-vault}/` directory
  2. Move entire `specs/archive/` directory contents into `specs/vault/{NN-vault}/archive/`
  3. Move `specs/archive/state.json` into vault as `specs/vault/{NN-vault}/state.json`
  4. Reinitialize fresh `specs/archive/` directory with empty `archive/state.json`
  5. Update main `specs/state.json` with vault metadata

- User confirmation prompt:
  ```
  Task numbering has reached {N}. Vault {M} archived tasks?
  Options: Yes (vault and reset), No (skip for now)
  ```

### 3. Task Number Reset

After vault archival completes:

- Reset `next_project_number` to 1 in state.json
- Add a TODO.md comment/header noting the vault transition
- The reset means new tasks start at #1 again in the new "era"
- Active tasks (non-archived) retain their current numbers - no renumbering

## Integration Points

- **Component Type**: command modification + state schema extension
- **Affected Area**: .claude/commands/todo.md, specs/state.json
- **Action Type**: modify + extend
- **Related Files**:
  - `.claude/commands/todo.md` - Primary file to modify
  - `specs/state.json` - Schema extension for vault tracking
  - `specs/archive/state.json` - Gets moved to vault

## Dependencies

None - this task can be started independently.

## Interview Context

### User-Provided Information

The user wants:
- Trigger condition: tasks exceed 1000 (next_project_number > 1000)
- Destination: `specs/vault/{NN-vault}/` where NN is a sequential vault number
- After vault: restart numbering at 1
- The vault operation should be integrated into the existing /todo command flow

### Effort Assessment

- **Estimated Effort**: 3-5 hours
- **Complexity Notes**: Medium complexity - primarily modifying an existing command with well-defined behavior. The vault operation is a natural extension of the existing archive pattern. Key challenges: ensuring the vault directory naming is robust, handling the number reset cleanly, and providing clear user feedback during the operation.

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 248 [focus]` with a specific focus prompt.*
