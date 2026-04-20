# Implementation Plan: Align skill-meta and agent frontmatter/references

- **Task**: 486 - Align skill-meta and agent frontmatter/references
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_team-research.md
- **Artifacts**: plans/01_align-skill-meta.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Four surgical edits across two deployed files (`.claude/skills/skill-meta/SKILL.md` and `.claude/agents/meta-builder-agent.md`) to fix frontmatter gaps, stale `subagent-return.md` references, and a hardcoded `latex` domain detection line. All changes are confined to this repository; the user will sync to other locations via the extension loader. Done when all four fixes pass grep verification.

### Research Integration

Team research (4 teammates) confirmed all four fixes are correct. Key resolutions: (1) do NOT add `context: fork` -- user confirms it is outdated and causes adverse runtime effects; (2) keep `allowed-tools` as-is (Task, Bash, Edit, Read, Write) to avoid breaking postflight git commit; (3) replace only the 3 specific stale `subagent-return.md` references, not all occurrences; (4) do NOT expand scope to v1-to-v2 protocol migration.

### Roadmap Alignment

No ROADMAP.md consulted. Research notes this advances the "Agent frontmatter validation" roadmap item.

## Goals & Non-Goals

**Goals**:
- Add `agent: meta-builder-agent` to skill-meta frontmatter
- Remove legacy commented-out context/tools blocks from skill-meta frontmatter
- Replace 3 stale `subagent-return.md` references with `return-metadata-file.md`
- Remove hardcoded `latex` keyword detection from meta-builder-agent

**Non-Goals**:
- Adding `context: fork` (outdated, causes adverse effects)
- Reducing `allowed-tools` in skill-meta
- Migrating meta-builder-agent from v1 to v2 return protocol
- Editing extension source copies (user syncs via loader)
- Adding memory integration to skill-meta

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing latex detection changes /meta behavior for latex-keyword prompts | L | L | Keywords now fall through to `general`, which is correct for /meta context |
| Stale reference replacement misses a reference | M | L | Verified by research: exactly 3 references at known line numbers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Apply all four fixes [NOT STARTED]

**Goal**: Complete all four surgical edits to the two deployed files.

**Tasks**:
- [ ] Fix 1: In `.claude/skills/skill-meta/SKILL.md`, add `agent: meta-builder-agent` field to frontmatter (after line 4, before the commented block)
- [ ] Fix 1 (cont): Remove the commented-out "Original context" and "Original tools" blocks (lines 5-11, the 7 comment lines)
- [ ] Fix 2: In `.claude/skills/skill-meta/SKILL.md`, replace `subagent-return.md` with `return-metadata-file.md` on line 109 (return validation section)
- [ ] Fix 2 (cont): Replace `subagent-return.md` with `return-metadata-file.md` on line 123 (return format section)
- [ ] Fix 3: In `.claude/agents/meta-builder-agent.md`, replace `subagent-return.md` with `return-metadata-file.md` in the Mode-Context Matrix table (line 93)
- [ ] Fix 4: In `.claude/agents/meta-builder-agent.md`, remove the line `- Keywords: "latex", "document", "pdf", "tex" -> task_type = "latex"` from DetectDomainType (line 240)

**Timing**: 15-20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-meta/SKILL.md` - Frontmatter cleanup (Fix 1) and stale reference replacement (Fix 2)
- `.claude/agents/meta-builder-agent.md` - Stale reference replacement (Fix 3) and latex detection removal (Fix 4)

**Verification**:
- `grep -c 'agent: meta-builder-agent' .claude/skills/skill-meta/SKILL.md` returns 1
- `grep -c 'context: fork' .claude/skills/skill-meta/SKILL.md` returns 0
- `grep -c 'Original context' .claude/skills/skill-meta/SKILL.md` returns 0
- `grep -c 'subagent-return.md' .claude/skills/skill-meta/SKILL.md` returns 0
- `grep -c 'subagent-return.md' .claude/agents/meta-builder-agent.md` returns 0
- `grep -c '"latex"' .claude/agents/meta-builder-agent.md` returns 0
- `grep -c 'return-metadata-file.md' .claude/skills/skill-meta/SKILL.md` returns 2 (the replacements)
- `grep -c 'return-metadata-file.md' .claude/agents/meta-builder-agent.md` returns 2 (1 existing + 1 replacement)

## Testing & Validation

- [ ] All verification grep commands pass with expected counts
- [ ] `grep -n 'agent:' .claude/skills/skill-meta/SKILL.md` shows the new frontmatter field
- [ ] No remaining `subagent-return.md` references in either file
- [ ] No remaining `latex` keyword detection in meta-builder-agent
- [ ] No `context: fork` added anywhere

## Artifacts & Outputs

- `specs/486_align_skill_meta_frontmatter/plans/01_align-skill-meta.md` (this plan)
- `specs/486_align_skill_meta_frontmatter/summaries/01_align-skill-meta-summary.md` (post-implementation)

## Rollback/Contingency

Both files are tracked by git. Revert with `git checkout HEAD -- .claude/skills/skill-meta/SKILL.md .claude/agents/meta-builder-agent.md`.
