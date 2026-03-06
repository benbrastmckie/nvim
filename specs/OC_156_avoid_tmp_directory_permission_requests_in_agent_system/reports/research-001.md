# Research Report: Avoid /tmp Directory Permission Requests in Agent System

**Task**: OC_156 - Avoid tmp directory permission requests in agent system  
**Date**: 2026-03-06  
**Status**: RESEARCHED  
**Scope**: .opencode/ agent system

---

## Executive Summary

The OpenCode agent system currently writes temporary files to `/tmp/` when updating `specs/state.json` using `jq`. This causes permission prompts in certain environments. The solution is to use the existing `specs/tmp/` directory instead of `/tmp/` throughout the system.

## Problem Analysis

### Current Pattern

All status update commands use this pattern:
```bash
jq '...' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

This pattern appears in 85+ locations across the codebase.

### Root Cause

The global `/tmp/` directory may trigger permission prompts due to:
- System security policies restricting `/tmp/` access
- SELinux or AppArmor policies
- Container/sandboxed environment restrictions
- macOS permission prompts for `/tmp/` access

### Existing Solution Infrastructure

The `specs/tmp/` directory already exists and is the preferred local temporary location:
```bash
ls -la specs/tmp/
# drwxr-xr-x 2 benjamin users 4096 Mar 5 19:22 .
# drwxr-xr-x 14 benjamin users 4096 Mar 5 19:22 ..
```

## Affected Files

### 1. Command Files (9 occurrences)
- `.opencode/commands/research.md` (4 occurrences)
- `.opencode/commands/implement.md` (4 occurrences)
- `.opencode/commands/plan.md` (4 occurrences)
- `.opencode/commands/task.md` (2 occurrences)

### 2. Skill Files (20+ occurrences)
- `.opencode/skills/skill-researcher/SKILL.md` (3 occurrences)
- `.opencode/skills/skill-implementer/SKILL.md` (4 occurrences)
- `.opencode/skills/skill-planner/SKILL.md` (3 occurrences)
- `.opencode/skills/skill-task/SKILL.md` (2 occurrences)
- Extension skills (web, nix) with 8+ occurrences each

### 3. Context Pattern Documentation (35+ occurrences)
- `.opencode/context/core/patterns/inline-status-update.md` (11 occurrences)
- `.opencode/context/core/patterns/jq-escaping-workarounds.md` (13 occurrences)
- `.opencode/context/core/patterns/file-metadata-exchange.md` (2 occurrences)
- `.opencode/context/core/patterns/core-command-execution.sh` (3 occurrences)
- `.opencode/context/core/orchestration/preflight-pattern.md` (1 occurrence)
- `.opencode/context/core/orchestration/postflight-pattern.md` (1 occurrence)

### 4. Scripts (9 occurrences)
- `.opencode/scripts/postflight-research.sh` (3 occurrences)
- `.opencode/scripts/postflight-plan.sh` (3 occurrences)
- `.opencode/scripts/postflight-implement.sh` (3 occurrences)

## Recommended Solutions

### Option 1: Replace All `/tmp/` with `specs/tmp/` (Recommended)

Simple find-and-replace of `/tmp/state.json` with `specs/tmp/state.json`:

**Pros**:
- Simple to implement
- No logic changes required
- Maintains atomic file update pattern
- Uses existing project-local tmp directory

**Cons**:
- Requires updating 85+ locations
- Must update documentation too

**Implementation**:
```bash
# Before
jq '...' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# After
jq '...' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

### Option 2: In-Place Editing (More Complex)

Use `jq` with `-i` flag or sponge from `moreutils`:

**Pros**:
- No temporary file needed
- No permission issues

**Cons**:
- `jq -i` is not atomic (risk of corruption)
- Requires `sponge` dependency
- Major pattern change across codebase
- Violates established safety patterns

### Option 3: Environment Variable (Flexible)

Define `$OPENCODE_TMP` variable:

**Pros**:
- Configurable per environment
- Single point of change

**Cons**:
- Requires variable setup
- More complex than necessary
- Existing solution already in place

## Recommended Approach

**Adopt Option 1**: Replace all `/tmp/state.json` references with `specs/tmp/state.json`

This is the most pragmatic solution because:
1. `specs/tmp/` already exists and is user-owned
2. Minimal code changes (simple path substitution)
3. Maintains atomic update pattern
4. No new dependencies or environment setup required
5. Consistent with project-local storage philosophy

## Implementation Plan

### Phase 1: Update Core Commands
Update the 4 command files in `.opencode/commands/`

### Phase 2: Update Skills
Update skill definitions in `.opencode/skills/` and extensions

### Phase 3: Update Context Documentation
Update pattern documentation to reflect new best practice

### Phase 4: Update Scripts
Update postflight shell scripts

### Phase 5: Verification
Test status updates work without permission prompts

## Files to Modify (85 total)

### Priority 1: Active Commands (9 files)
1. `.opencode/commands/research.md`
2. `.opencode/commands/implement.md`
3. `.opencode/commands/plan.md`
4. `.opencode/commands/task.md`
5. `.opencode/skills/skill-researcher/SKILL.md`
6. `.opencode/skills/skill-implementer/SKILL.md`
7. `.opencode/skills/skill-planner/SKILL.md`
8. `.opencode/skills/skill-task/SKILL.md`
9. `.opencode/scripts/postflight-research.sh`
10. `.opencode/scripts/postflight-plan.sh`
11. `.opencode/scripts/postflight-implement.sh`

### Priority 2: Extensions (16 files)
- `.opencode/extensions/web/skills/skill-web-implementation/SKILL.md`
- `.opencode/extensions/web/skills/skill-web-research/SKILL.md`
- `.opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md`
- `.opencode/extensions/nix/skills/skill-nix-research/SKILL.md`

### Priority 3: Documentation (5 files)
- `.opencode/context/core/patterns/inline-status-update.md`
- `.opencode/context/core/patterns/jq-escaping-workarounds.md`
- `.opencode/context/core/patterns/file-metadata-exchange.md`
- `.opencode/context/core/patterns/core-command-execution.sh`
- `.opencode/context/core/orchestration/preflight-pattern.md`
- `.opencode/context/core/orchestration/postflight-pattern.md`

## Migration Pattern

```bash
# Old pattern (causes permission prompts)
jq '...' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# New pattern (uses project-local tmp)
jq '...' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

## Verification Steps

1. Update all occurrences
2. Run `/research` command on test task
3. Confirm no permission prompts appear
4. Verify `specs/state.json` updates correctly
5. Check `specs/tmp/` directory for temporary files during operations

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Missed occurrences | Use `grep -r "/tmp/state.json" .opencode/` to find all |
| Syntax errors | Test each file type after changes |
| Race conditions | Keep atomic `> tmp && mv` pattern |
| Documentation drift | Update context patterns immediately |

## Success Criteria

- [ ] No permission prompts when updating state.json
- [ ] All 85+ occurrences updated to use `specs/tmp/`
- [ ] Documentation reflects new pattern
- [ ] All commands continue to function correctly
- [ ] No references to `/tmp/state.json` remain

## Conclusion

The solution is straightforward: replace `/tmp/state.json` with `specs/tmp/state.json` throughout the codebase. The `specs/tmp/` directory already exists and is user-owned, eliminating permission issues while maintaining the atomic file update pattern that prevents data corruption.

**Estimated effort**: 2-3 hours  
**Complexity**: Low  
**Risk**: Low
