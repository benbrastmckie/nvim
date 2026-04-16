# Implementation Plan: Remove Co-Authored-By Trailers

- **Task**: 427 - Remove Co-Authored-By trailers and refine README.md sync exclusion
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/427_remove_coauthored_by_and_refine_readme_sync/reports/01_coauthored-by-removal.md
- **Artifacts**: plans/01_coauthored-by-removal.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remove all Co-Authored-By trailer references from ~75 active files across .claude/ and .opencode/ directories (~137 occurrences total). The CLAUDE.md already states to omit these trailers, but templates, rules, skills, agents, and commands still contain them, creating contradictory instructions. After removal, simplify the CLAUDE.md policy note and update creating-agents.md to prevent future re-introduction.

### Research Integration

Research identified 137 occurrences across 8 categories (A-H). Category H (archive files) is excluded. Files are grouped by function: core rules/templates (31 occurrences), commands (11), skills (15), agents (7), extension skills (39), extension commands (21), and context/docs (13). The removal is mechanical -- each occurrence is a `Co-Authored-By:` line in a commit message template, typically preceded by a blank separator line that should also be removed.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the "Subagent-return reference cleanup" roadmap item under Agent System Quality -- both are sweep-and-clean operations that remove stale references from the agent system. It also supports "Zero stale references to removed/renamed files" success metric.

## Goals & Non-Goals

**Goals**:
- Remove all Co-Authored-By lines from commit templates in active .claude/ and .opencode/ files
- Remove the CLAUDE.md policy note that references the external feedback file
- Update creating-agents.md to not instruct adding Co-Authored-By
- Remove preceding blank lines that only separated Co-Authored-By from Session lines

**Non-Goals**:
- Modifying archive files in specs/archive/
- Changing the auto-memory file at ~/.claude/projects/.../feedback_no_coauthored_by.md
- Refactoring commit message formats beyond trailer removal

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missing occurrences in rarely-loaded extensions | L | L | Final grep verification in Phase 5 |
| Sync operations re-introduce Co-Authored-By from unclean source | M | M | Clean .claude/ first (Phase 1-3), then .opencode/ (Phase 4) |
| Accidental removal of non-trailer text matching pattern | M | L | Review each file's context around the match line |
| New files added later re-introduce pattern | L | L | creating-agents.md fix prevents this |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Core Rules, Templates, and CLAUDE.md [COMPLETED]

**Goal**: Remove Co-Authored-By from the highest-impact files that directly instruct agents on commit format.

**Tasks**:
- [ ] `.claude/rules/git-workflow.md` -- Remove 4 Co-Authored-By lines from commit format examples
- [ ] `.claude/skills/skill-git-workflow/SKILL.md` -- Remove 4 Co-Authored-By lines
- [ ] `.claude/context/checkpoints/checkpoint-commit.md` -- Remove 5 Co-Authored-By lines
- [ ] `.claude/context/patterns/checkpoint-execution.md` -- Remove 1 Co-Authored-By line
- [ ] `.claude/CLAUDE.md` -- Remove the "Note" on line ~162 referencing feedback_no_coauthored_by.md
- [ ] `.claude/docs/guides/creating-agents.md` -- Remove "Include Co-Authored-By line" instruction (line ~422)

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/rules/git-workflow.md` -- Remove trailer lines from commit examples
- `.claude/skills/skill-git-workflow/SKILL.md` -- Remove trailer lines from commit examples
- `.claude/context/checkpoints/checkpoint-commit.md` -- Remove trailer lines from checkpoint examples
- `.claude/context/patterns/checkpoint-execution.md` -- Remove trailer line
- `.claude/CLAUDE.md` -- Remove policy note
- `.claude/docs/guides/creating-agents.md` -- Remove instruction to add trailer

**Verification**:
- `grep -rn "Co-Authored-By" .claude/rules/git-workflow.md .claude/skills/skill-git-workflow/SKILL.md .claude/context/checkpoints/ .claude/context/patterns/checkpoint-execution.md .claude/CLAUDE.md .claude/docs/guides/creating-agents.md` returns no results

---

### Phase 2: Commands and Core Skills [COMPLETED]

**Goal**: Remove Co-Authored-By from command files and core skill files that contain commit message examples.

**Tasks**:
- [ ] `.claude/commands/implement.md` -- Remove 4 Co-Authored-By lines
- [ ] `.claude/commands/plan.md` -- Remove 3 Co-Authored-By lines
- [ ] `.claude/commands/research.md` -- Remove 3 Co-Authored-By lines
- [ ] `.claude/commands/review.md` -- Remove 1 Co-Authored-By line
- [ ] `.claude/skills/skill-implementer/SKILL.md` -- Remove 1 line
- [ ] `.claude/skills/skill-planner/SKILL.md` -- Remove 1 line
- [ ] `.claude/skills/skill-reviser/SKILL.md` -- Remove 2 lines
- [ ] `.claude/skills/skill-spawn/SKILL.md` -- Remove 1 line
- [ ] `.claude/skills/skill-fix-it/SKILL.md` -- Remove 1 line
- [ ] `.claude/skills/skill-team-implement/SKILL.md` -- Remove 2 lines
- [ ] `.claude/skills/skill-team-research/SKILL.md` -- Remove 1 line
- [ ] `.claude/skills/skill-team-plan/SKILL.md` -- Remove 1 line

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/commands/implement.md` -- Remove trailer lines
- `.claude/commands/plan.md` -- Remove trailer lines
- `.claude/commands/research.md` -- Remove trailer lines
- `.claude/commands/review.md` -- Remove trailer line
- `.claude/skills/skill-implementer/SKILL.md` -- Remove trailer line
- `.claude/skills/skill-planner/SKILL.md` -- Remove trailer line
- `.claude/skills/skill-reviser/SKILL.md` -- Remove trailer lines
- `.claude/skills/skill-spawn/SKILL.md` -- Remove trailer line
- `.claude/skills/skill-fix-it/SKILL.md` -- Remove trailer line
- `.claude/skills/skill-team-implement/SKILL.md` -- Remove trailer lines
- `.claude/skills/skill-team-research/SKILL.md` -- Remove trailer line
- `.claude/skills/skill-team-plan/SKILL.md` -- Remove trailer line

**Verification**:
- `grep -rn "Co-Authored-By" .claude/commands/ .claude/skills/` returns no results

---

### Phase 3: Agents, Extension Skills, Extension Commands, and Context [COMPLETED]

**Goal**: Remove Co-Authored-By from all .claude/ agent files, extension skill files, extension command files, and context/documentation files.

**Tasks**:
- [ ] `.claude/agents/general-implementation-agent.md` -- Remove 1 line
- [ ] `.claude/extensions/typst/agents/typst-implementation-agent.md` -- Remove 1 line
- [ ] `.claude/extensions/latex/agents/latex-implementation-agent.md` -- Remove 1 line
- [ ] All 28 .claude extension skill files (Category E) -- Remove 1-2 lines each
- [ ] All 17 .claude extension command files (Category F) -- Remove 1-2 lines each
- [ ] `.claude/context/standards/ci-workflow.md` -- Remove 2 lines
- [ ] `.claude/context/patterns/multi-task-operations.md` -- Remove 4 lines
- [ ] `.claude/context/patterns/file-metadata-exchange.md` -- Remove 1 line
- [ ] `.claude/context/troubleshooting/workflow-interruptions.md` -- Remove 1 line
- [ ] `.claude/docs/examples/fix-it-flow-example.md` -- Remove 1 line

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- 3 agent files, 28 extension skill files, 17 extension command files, 5 context/doc files (53 files total)

**Verification**:
- `grep -rn "Co-Authored-By" .claude/agents/ .claude/extensions/ .claude/context/ .claude/docs/` returns no results

---

### Phase 4: OpenCode System [COMPLETED]

**Goal**: Mirror all removals in the .opencode/ directory to maintain parity between Claude Code and OpenCode agent systems.

**Tasks**:
- [ ] `.opencode/rules/git-workflow.md` -- Remove 4 lines
- [ ] `.opencode/skills/skill-git-workflow/SKILL.md` -- Remove 4 lines
- [ ] `.opencode/context/core/checkpoints/checkpoint-commit.md` -- Remove 5 lines
- [ ] `.opencode/context/core/patterns/checkpoint-execution.md` -- Remove 1 line
- [ ] `.opencode/README.md` -- Remove 1 line
- [ ] `.opencode/AGENTS.md` -- Remove 1 line
- [ ] All 5 .opencode skill files (Category C) -- Remove 1 line each
- [ ] All 4 .opencode agent files (Category D) -- Remove 1 line each
- [ ] All 9 .opencode extension skill files (Category E) -- Remove 1 line each
- [ ] All 4 .opencode extension command files (Category F) -- Remove 1 line each
- [ ] `.opencode/context/core/standards/ci-workflow.md` -- Remove 2 lines
- [ ] `.opencode/context/core/patterns/file-metadata-exchange.md` -- Remove 1 line

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- ~29 .opencode/ files across rules, skills, agents, extensions, and context

**Verification**:
- `grep -rn "Co-Authored-By" .opencode/` returns no results

---

### Phase 5: Final Verification and Cleanup [COMPLETED]

**Goal**: Run comprehensive grep across all active directories to confirm zero remaining Co-Authored-By references (excluding archive).

**Tasks**:
- [ ] Run `grep -rn "Co-Authored-By" .claude/ .opencode/` and confirm zero results
- [ ] Run `grep -rni "co-authored" .claude/ .opencode/` (case-insensitive) and confirm zero results
- [ ] Verify commit format examples in modified files still have valid structure (Session line is last line of commit body)
- [ ] Spot-check 3-5 modified files to ensure no blank-line artifacts remain

**Timing**: 15 minutes

**Depends on**: 4

**Files to modify**:
- None (verification only, unless issues found)

**Verification**:
- Zero grep matches for "Co-Authored-By" in .claude/ and .opencode/
- Zero grep matches for "co-authored" (case-insensitive) in .claude/ and .opencode/
- Modified commit templates maintain valid structure

## Testing & Validation

- [ ] `grep -rn "Co-Authored-By" .claude/ .opencode/` returns empty
- [ ] `grep -rni "co-authored" .claude/ .opencode/` returns empty
- [ ] `.claude/CLAUDE.md` no longer references `feedback_no_coauthored_by.md`
- [ ] `.claude/docs/guides/creating-agents.md` no longer instructs adding Co-Authored-By
- [ ] Commit format examples in git-workflow.md end with Session line (no trailing blank lines)

## Artifacts & Outputs

- Modified ~75 files across .claude/ and .opencode/ with Co-Authored-By lines removed
- Updated CLAUDE.md with simplified commit convention (no policy note)
- Updated creating-agents.md with corrected guidance

## Rollback/Contingency

All changes are to tracked files in git. Rollback via `git checkout -- .claude/ .opencode/` to restore all files to pre-implementation state. Since the change is purely mechanical removal of trailer lines, partial rollback of individual files is also straightforward.
