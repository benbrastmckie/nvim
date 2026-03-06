# Implementation Plan: Task #152

- **Task**: 152 - fix_git_commit_co_author_attribution
- **Status**: [NOT STARTED]
- **Effort**: 0.75 hours (45 minutes)
- **Dependencies**: None
- **Research Inputs**: research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: .opencode/context/core/formats/plan-format.md, .opencode/context/core/standards/status-markers.md, .opencode/context/core/standards/documentation-standards.md, .opencode/context/core/standards/task-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remove all co-author attribution ("Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>") from git commit commands across the .opencode codebase. The user has explicitly requested removal of model attribution entirely from git commits.

### Research Integration

Research found 15 files containing hardcoded co-author strings in git commit commands. The pattern appears as `\n\nCo-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>` appended to commit messages in shell commands. All instances must be removed while preserving the core git commit functionality.

## Goals & Non-Goals

**Goals**:
- Remove all co-author attribution strings from git commit commands
- Preserve proper git commit functionality
- Verify no co-author strings remain in the codebase
- Update all 15 identified files

**Non-Goals**:
- No changes to git workflow logic or commit strategies
- No changes to commit message content beyond removing co-author lines
- No changes to skill or agent behavior beyond the attribution removal

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Partial removal leaving some strings | Medium | Low | Use grep search to verify all instances removed |
| Breaking git commit command syntax | High | Low | Review each file to ensure command structure remains valid |
| Missing files not in research list | Low | Low | Run comprehensive search for "Co-Authored-By" pattern |

## Implementation Phases

### Phase 1: Core System Files [NOT STARTED]

**Goal**: Remove co-author strings from core commands and skills

**Files to modify**:
1. `.opencode/commands/implement.md`
2. `.opencode/commands/plan.md`
3. `.opencode/commands/research.md`
4. `.opencode/commands/review.md`
5. `.opencode/skills/skill-researcher/SKILL.md`
6. `.opencode/skills/skill-planner/SKILL.md`
7. `.opencode/skills/skill-implementer/SKILL.md`
8. `.opencode/agent/subagents/general-implementation-agent.md`

**Tasks**:
- [ ] Read each file to identify co-author string location
- [ ] Remove the `\n\nCo-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>` portion
- [ ] Verify git commit command syntax remains valid
- [ ] Save each modified file

**Timing**: 20 minutes

### Phase 2: Extension Files [NOT STARTED]

**Goal**: Remove co-author strings from extension-specific skills and agents

**Files to modify**:
1. `.opencode/extensions/filetypes/commands/convert.md`
2. `.opencode/extensions/nix/skills/skill-nix-research/SKILL.md`
3. `.opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md`
4. `.opencode/extensions/nix/agents/nix-implementation-agent.md`
5. `.opencode/extensions/web/skills/skill-web-research/SKILL.md`
6. `.opencode/extensions/web/skills/skill-web-implementation/SKILL.md`
7. `.opencode/extensions/web/agents/web-implementation-agent.md`

**Tasks**:
- [ ] Read each file to identify co-author string location
- [ ] Remove the `\n\nCo-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>` portion
- [ ] Verify git commit command syntax remains valid
- [ ] Save each modified file

**Timing**: 15 minutes

### Phase 3: Verification [NOT STARTED]

**Goal**: Confirm all co-author strings have been removed

**Tasks**:
- [ ] Run `grep -r "Co-Authored-By: Claude" .opencode/` to search for remaining strings
- [ ] Run `grep -r "Co-Authored-By" .opencode/` to search for any variant co-author strings
- [ ] Verify no results found (empty output)
- [ ] Verify all 15 files were modified

**Timing**: 10 minutes

## Testing & Validation

- [ ] Grep search returns zero results for "Co-Authored-By: Claude"
- [ ] Grep search returns zero results for any "Co-Authored-By" pattern
- [ ] All 15 identified files have been modified
- [ ] Git commit commands in modified files have valid syntax (proper quoting, flags preserved)

## Artifacts & Outputs

- 15 modified markdown files with co-author strings removed:
  - 4 command files (implement.md, plan.md, research.md, review.md)
  - 3 skill files (skill-researcher, skill-planner, skill-implementer)
  - 1 agent file (general-implementation-agent.md)
  - 7 extension files (filetypes/nix/web)

## Rollback/Contingency

**Rollback Plan**:
1. Git revert all modified files: `git checkout -- .opencode/`
2. Verify with grep that co-author strings are restored

**Contingency**:
- If any file has complex commit command patterns, create backup before editing
- If verification finds missed strings, create follow-up task for remaining instances

## Implementation Notes

**String Pattern to Remove**:
The exact pattern to remove is: `\n\nCo-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>`

This appears at the end of git commit message strings, typically in shell heredocs or command examples like:
```bash
git commit -m "message"$'\n\nCo-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>'
```

**Expected Result**:
Commands should become simple commits without co-author attribution:
```bash
git commit -m "message"
```

**Verification Command**:
```bash
grep -r "Co-Authored-By" .opencode/ --include="*.md"
```
Expected output: empty (no matches)
