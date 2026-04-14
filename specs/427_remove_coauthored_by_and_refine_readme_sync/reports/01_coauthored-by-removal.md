# Research Report: Task #427

**Task**: 427 - Remove Co-Authored-By trailers and refine README.md sync exclusion
**Started**: 2026-04-13T12:00:00Z
**Completed**: 2026-04-13T12:15:00Z
**Effort**: Small-medium (mechanical removal across many files)
**Dependencies**: None
**Sources/Inputs**: - Codebase grep for "Co-Authored-By" across all .claude/, .opencode/, and specs/ directories
**Artifacts**: - specs/427_remove_coauthored_by_and_refine_readme_sync/reports/01_coauthored-by-removal.md
**Standards**: report-format.md

## Executive Summary

- 80+ occurrences of Co-Authored-By exist across .claude/ and .opencode/ directories in commit templates, examples, and documentation
- The CLAUDE.md already notes to "omit Co-Authored-By trailers from all commits" but this contradicts the templates that still contain them
- Files fall into two categories: (A) active templates/rules that instruct agents to add trailers (HIGH priority), and (B) example/documentation references (MEDIUM priority)
- The `.claude/CLAUDE.md` note referencing `feedback_no_coauthored_by.md` should be simplified to a direct policy statement rather than referencing an external auto-memory file
- The `.claude/docs/guides/creating-agents.md` line "Include Co-Authored-By line" actively instructs new agent creation to perpetuate the pattern

## Context & Scope

The user does not want any Co-Authored-By trailers anywhere in their agent system. This research catalogs every occurrence across the codebase (excluding specs/archive/ which are historical records). The focus is on files that actively instruct agents to include Co-Authored-By in commits, as well as examples that could be copied or referenced.

## Findings

### Category A: Active Rules and Templates (HIGH priority -- these instruct agents to add trailers)

These files contain commit format templates that agents actively follow:

| # | File | Lines | Count |
|---|------|-------|-------|
| 1 | `.claude/rules/git-workflow.md` | 95, 124, 132, 140 | 4 |
| 2 | `.claude/skills/skill-git-workflow/SKILL.md` | 115, 153, 171, 182 | 4 |
| 3 | `.claude/context/checkpoints/checkpoint-commit.md` | 23, 32, 41, 50, 59 | 5 |
| 4 | `.claude/context/patterns/checkpoint-execution.md` | 125 | 1 |
| 5 | `.claude/CLAUDE.md` | 162 (the "Note" referencing feedback file) | 1 |
| 6 | `.opencode/rules/git-workflow.md` | 93, 122, 130, 138 | 4 |
| 7 | `.opencode/skills/skill-git-workflow/SKILL.md` | 115, 153, 171, 182 | 4 |
| 8 | `.opencode/context/core/checkpoints/checkpoint-commit.md` | 23, 32, 41, 50, 59 | 5 |
| 9 | `.opencode/context/core/patterns/checkpoint-execution.md` | 125 | 1 |
| 10 | `.opencode/README.md` | 249 | 1 |
| 11 | `.opencode/AGENTS.md` | 150 | 1 |

**Subtotal: 31 occurrences in active rule/template files**

### Category B: Command Files (HIGH priority -- these contain commit examples agents follow)

| # | File | Lines | Count |
|---|------|-------|-------|
| 1 | `.claude/commands/implement.md` | 215, 230, 530, 543 | 4 |
| 2 | `.claude/commands/plan.md` | 189, 200, 469 | 3 |
| 3 | `.claude/commands/research.md` | 185, 196, 445 | 3 |
| 4 | `.claude/commands/review.md` | 1513 | 1 |

**Subtotal: 11 occurrences in command files**

### Category C: Skill Files (HIGH priority -- these instruct subagents)

| # | File | Lines | Count |
|---|------|-------|-------|
| 1 | `.claude/skills/skill-implementer/SKILL.md` | 393 | 1 |
| 2 | `.claude/skills/skill-planner/SKILL.md` | 342 | 1 |
| 3 | `.claude/skills/skill-reviser/SKILL.md` | 384, 397 | 2 |
| 4 | `.claude/skills/skill-spawn/SKILL.md` | 411 | 1 |
| 5 | `.claude/skills/skill-fix-it/SKILL.md` | 533 | 1 |
| 6 | `.claude/skills/skill-team-implement/SKILL.md` | 398, 552 | 2 |
| 7 | `.claude/skills/skill-team-research/SKILL.md` | 537 | 1 |
| 8 | `.claude/skills/skill-team-plan/SKILL.md` | 522 | 1 |
| 9 | `.opencode/skills/skill-implementer/SKILL.md` | 329 | 1 |
| 10 | `.opencode/skills/skill-planner/SKILL.md` | 245 | 1 |
| 11 | `.opencode/skills/skill-researcher/SKILL.md` | 238 | 1 |
| 12 | `.opencode/skills/skill-fix-it/SKILL.md` | 289 | 1 |
| 13 | `.opencode/skills/skill-learn/SKILL.md` | 944 | 1 |

**Subtotal: 15 occurrences in skill files**

### Category D: Agent Files (HIGH priority)

| # | File | Lines | Count |
|---|------|-------|-------|
| 1 | `.claude/agents/general-implementation-agent.md` | 204 | 1 |
| 2 | `.claude/extensions/typst/agents/typst-implementation-agent.md` | 94 | 1 |
| 3 | `.claude/extensions/latex/agents/latex-implementation-agent.md` | 112 | 1 |
| 4 | `.opencode/agent/subagents/general-implementation-agent.md` | 331 | 1 |
| 5 | `.opencode/extensions/nix/agents/nix-implementation-agent.md` | 712 | 1 |
| 6 | `.opencode/extensions/web/agents/web-implementation-agent.md` | 367 | 1 |
| 7 | `.opencode/extensions/nvim/agents/neovim-implementation-agent.md` | 384 | 1 |

**Subtotal: 7 occurrences in agent files**

### Category E: Extension Skill Files (HIGH priority)

| # | File | Lines | Count |
|---|------|-------|-------|
| 1 | `.claude/extensions/memory/skills/skill-memory/SKILL.md` | 848 | 1 |
| 2 | `.claude/extensions/nix/skills/skill-nix-research/SKILL.md` | 198 | 1 |
| 3 | `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` | 323 | 1 |
| 4 | `.claude/extensions/lean/skills/skill-lean-research/SKILL.md` | 208 | 1 |
| 5 | `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` | 222 | 1 |
| 6 | `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md` | 198 | 1 |
| 7 | `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` | 289 | 1 |
| 8 | `.claude/extensions/web/skills/skill-web-research/SKILL.md` | 218 | 1 |
| 9 | `.claude/extensions/web/skills/skill-web-implementation/SKILL.md` | 323 | 1 |
| 10 | `.claude/extensions/present/skills/skill-slides/SKILL.md` | 308 | 1 |
| 11 | `.claude/extensions/present/skills/skill-timeline/SKILL.md` | 335 | 1 |
| 12 | `.claude/extensions/present/skills/skill-funds/SKILL.md` | 390 | 1 |
| 13 | `.claude/extensions/present/skills/skill-grant/SKILL.md` | 516, 893 | 2 |
| 14 | `.claude/extensions/present/skills/skill-budget/SKILL.md` | 294 | 1 |
| 15 | `.claude/extensions/founder/skills/skill-project/SKILL.md` | 271 | 1 |
| 16 | `.claude/extensions/founder/skills/skill-financial-analysis/SKILL.md` | 215 | 1 |
| 17 | `.claude/extensions/founder/skills/skill-deck-implement/SKILL.md` | 249 | 1 |
| 18 | `.claude/extensions/founder/skills/skill-founder-plan/SKILL.md` | 214 | 1 |
| 19 | `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md` | 476 | 1 |
| 20 | `.claude/extensions/founder/skills/skill-market/SKILL.md` | 289 | 1 |
| 21 | `.claude/extensions/founder/skills/skill-spreadsheet/SKILL.md` | 288 | 1 |
| 22 | `.claude/extensions/founder/skills/skill-legal/SKILL.md` | 289 | 1 |
| 23 | `.claude/extensions/founder/skills/skill-analyze/SKILL.md` | 290 | 1 |
| 24 | `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md` | 251 | 1 |
| 25 | `.claude/extensions/founder/skills/skill-meeting/SKILL.md` | 278 | 1 |
| 26 | `.claude/extensions/founder/skills/skill-finance/SKILL.md` | 292 | 1 |
| 27 | `.claude/extensions/founder/skills/skill-strategy/SKILL.md` | 292 | 1 |
| 28 | `.claude/extensions/founder/skills/skill-deck-research/SKILL.md` | 283 | 1 |
| 29 | `.opencode/extensions/memory/skills/skill-memory/SKILL.md` | 848 | 1 |
| 30 | `.opencode/extensions/nix/skills/skill-nix-research/SKILL.md` | 178 | 1 |
| 31 | `.opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md` | 307 | 1 |
| 32 | `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md` | 192 | 1 |
| 33 | `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md` | 223 | 1 |
| 34 | `.opencode/extensions/nvim/skills/skill-neovim-research/SKILL.md` | 178 | 1 |
| 35 | `.opencode/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` | 269 | 1 |
| 36 | `.opencode/extensions/web/skills/skill-web-research/SKILL.md` | 203 | 1 |
| 37 | `.opencode/extensions/web/skills/skill-web-implementation/SKILL.md` | 308 | 1 |

**Subtotal: 39 occurrences in extension skill files**

### Category F: Extension Command Files (MEDIUM priority)

| # | File | Lines | Count |
|---|------|-------|-------|
| 1 | `.claude/extensions/present/commands/grant.md` | 219, 470 | 2 |
| 2 | `.claude/extensions/present/commands/slides.md` | 322 | 1 |
| 3 | `.claude/extensions/present/commands/budget.md` | 252 | 1 |
| 4 | `.claude/extensions/present/commands/funds.md` | 266 | 1 |
| 5 | `.claude/extensions/present/commands/timeline.md` | 223 | 1 |
| 6 | `.claude/extensions/filetypes/commands/scrape.md` | 183 | 1 |
| 7 | `.claude/extensions/filetypes/commands/edit.md` | 194 | 1 |
| 8 | `.claude/extensions/filetypes/commands/table.md` | 194 | 1 |
| 9 | `.claude/extensions/founder/commands/deck.md` | 264 | 1 |
| 10 | `.claude/extensions/founder/commands/strategy.md` | 256 | 1 |
| 11 | `.claude/extensions/founder/commands/sheet.md` | 255 | 1 |
| 12 | `.claude/extensions/founder/commands/project.md` | 451 | 1 |
| 13 | `.claude/extensions/founder/commands/meeting.md` | 199 | 1 |
| 14 | `.claude/extensions/founder/commands/analyze.md` | 248 | 1 |
| 15 | `.claude/extensions/founder/commands/finance.md` | 285 | 1 |
| 16 | `.claude/extensions/founder/commands/market.md` | 265 | 1 |
| 17 | `.claude/extensions/founder/commands/legal.md` | 275 | 1 |
| 18 | `.opencode/extensions/filetypes/commands/deck.md` | 233 | 1 |
| 19 | `.opencode/extensions/filetypes/commands/slides.md` | 227 | 1 |
| 20 | `.opencode/extensions/filetypes/commands/convert.md` | 168 | 1 |
| 21 | `.opencode/extensions/filetypes/commands/table.md` | 194 | 1 |

**Subtotal: 21 occurrences in extension command files**

### Category G: Context/Documentation Files (MEDIUM priority)

| # | File | Lines | Count |
|---|------|-------|-------|
| 1 | `.claude/context/standards/ci-workflow.md` | 82, 92 | 2 |
| 2 | `.claude/context/patterns/multi-task-operations.md` | 338, 349, 361, 373 | 4 |
| 3 | `.claude/context/patterns/file-metadata-exchange.md` | 279 | 1 |
| 4 | `.claude/context/troubleshooting/workflow-interruptions.md` | 222 | 1 |
| 5 | `.claude/docs/guides/creating-agents.md` | 422 | 1 |
| 6 | `.claude/docs/examples/fix-it-flow-example.md` | 372 | 1 |
| 7 | `.opencode/context/core/standards/ci-workflow.md` | 80, 90 | 2 |
| 8 | `.opencode/context/core/patterns/file-metadata-exchange.md` | 279 | 1 |

**Subtotal: 13 occurrences in context/documentation files**

### Category H: Archive/Historical Files (NO ACTION -- read-only history)

Files in `specs/archive/` are historical records and should NOT be modified. These include:
- `specs/archive/111_compare_opencode_agent_systems/`
- `specs/archive/392_refactor_present_extension_commands/`
- `specs/archive/396_review_claude_architecture_docs/`
- `specs/archive/OC_152_fix_git_commit_co_author_attribution/`
- `specs/archive/004_add_phase_checkpoint_protocol_to_neovim/`
- `specs/archive/221_fix_phase_status_markers_implementation_agents/`
- `specs/archive/414_remove_phase_checkpoint_protocol/`
- And several others

**These should be left as-is.**

### Special: The CLAUDE.md Policy Note

`.claude/CLAUDE.md` line 162 currently reads:
```
**Note**: Per user preference (see `~/.claude/projects/.../feedback_no_coauthored_by.md`), omit `Co-Authored-By` trailers from all commits.
```

This should be simplified. Once all Co-Authored-By lines are removed from templates, the note becomes unnecessary -- there will be nothing to omit. The commit convention section should simply not include any Co-Authored-By trailer.

### Special: creating-agents.md Guide

`.claude/docs/guides/creating-agents.md` line 422 contains:
```
   - Include Co-Authored-By line
```

This actively instructs developers creating new agents to include Co-Authored-By lines. This must be removed or changed to explicitly state NOT to include Co-Authored-By.

## Decisions

1. **Archive files**: Leave all `specs/archive/` files untouched -- they are historical records
2. **Active files**: Remove all Co-Authored-By lines from commit templates in categories A through G
3. **CLAUDE.md note**: Remove the note about omitting Co-Authored-By; instead, the convention simply will not include it
4. **creating-agents.md**: Remove the "Include Co-Authored-By line" instruction

## Recommendations

### Priority 1: Core Rules and Templates (highest impact)
1. `.claude/rules/git-workflow.md` -- Remove 4 Co-Authored-By lines from commit format examples
2. `.claude/skills/skill-git-workflow/SKILL.md` -- Remove 4 Co-Authored-By lines
3. `.claude/context/checkpoints/checkpoint-commit.md` -- Remove 5 Co-Authored-By lines
4. `.claude/CLAUDE.md` -- Remove the "Note" on line 162
5. `.claude/docs/guides/creating-agents.md` -- Remove "Include Co-Authored-By line" instruction

### Priority 2: Commands (direct agent instructions)
6. `.claude/commands/implement.md` -- Remove 4 lines
7. `.claude/commands/plan.md` -- Remove 3 lines
8. `.claude/commands/research.md` -- Remove 3 lines
9. `.claude/commands/review.md` -- Remove 1 line

### Priority 3: Skills and Agents
10. All 15 .claude skill files listed in Category C
11. All 3 .claude agent files listed in Category D
12. All 28 .claude extension skill files listed in Category E

### Priority 4: Extension Commands and Context
13. All 17 .claude extension command files listed in Category F
14. All 8 .claude context/doc files listed in Category G

### Priority 5: OpenCode System (mirror changes)
15. All .opencode/ files listed across categories A, C, D, E, F

### Implementation Approach

The removal is mechanical. In most files, the Co-Authored-By appears as part of a git commit message template like:
```
git commit -m "task N: action

Session: sess_123

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

The fix is to remove the `Co-Authored-By` line (and any blank line before it that was only separating it from the session ID). The commit message should end after the Session line.

**Total files to modify**: ~75 active files (excluding archive)
**Total occurrences to remove**: ~137 across .claude/ and .opencode/

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Missing an occurrence in a rarely-loaded extension | Low | Low | Run final grep verification after implementation |
| Sync operation re-introduces Co-Authored-By from source | Medium | Medium | Ensure the source (nvim) is clean first; sync targets will inherit clean templates |
| New files added later re-introduce the pattern | Low | Low | The creating-agents.md fix prevents this; no template suggests adding it |

## Appendix

### Search Queries Used
```bash
grep -rn "Co-Authored-By" .claude/ .opencode/
grep -rni "co-authored" .claude/ .opencode/
grep -rn "feedback_no_coauthored" .
grep -rn "coauthored|co.authored|no.trailer|omit.*Co-Authored" .claude/ .opencode/
```

### File Count Summary
| Category | .claude/ files | .opencode/ files | Total |
|----------|---------------|------------------|-------|
| A: Rules/Templates | 5 | 5 | 10 |
| B: Commands | 4 | 0 | 4 |
| C: Skills | 8 | 5 | 13 |
| D: Agents | 3 | 4 | 7 |
| E: Extension Skills | 28 | 9 | 37 |
| F: Extension Commands | 17 | 4 | 21 |
| G: Context/Docs | 6 | 2 | 8 |
| H: Archive (no action) | - | - | - |
| **Total** | **71** | **29** | **100** |
