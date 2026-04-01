# Implementation Plan: Review and Update Agent System Documentation

- **Task**: 349 - Review and update .claude/ agent system documentation for correctness and consistency
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_team-research.md (team research with 3 teammates)
- **Artifacts**: plans/01_documentation-review-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Systematically fix 21 documented issues across .claude/ documentation files, covering factual errors, missing content, and Unicode box-drawing consistency. Research identified incorrect extension names, missing commands/skills from tables, an outdated founder extension README, and ASCII box-drawing policy violations. Changes are grouped into 5 phases by file cluster to ensure each phase is independently committable.

### Research Integration

Team research report (3 teammates) identified 21 recommended changes across priority tiers: 4 factual errors, 11 missing content gaps, 3 box-drawing violations, and 3 minor improvements. All findings were cross-verified against actual filesystem contents with high confidence.

## Goals & Non-Goals

**Goals**:
- Fix all factual errors in documentation (wrong extension names, incorrect counts, missing tag types)
- Add all missing commands, skills, and agents to their respective tables
- Update outdated founder/README.md to document all 8 commands
- Convert ASCII box-drawing to Unicode in user-facing documentation
- Ensure consistency between README.md, CLAUDE.md, and component-level READMEs

**Non-Goals**:
- Converting ASCII boxes in agent context files (workflow-diagrams.md, team-orchestration.md) -- these are agent-consumed, not user-facing
- Converting intentional ASCII DAG output examples in meta-builder-agent.md
- Documenting the web extension skill-tag override behavior (low priority, no user impact)
- Creating a skill-template.md (may be intentionally absent)
- Fixing the gstack GitHub link in founder/README.md (cannot verify without web access)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Introducing new errors while fixing old ones | Medium | Low | Verify each edit against filesystem before committing |
| Box-drawing characters rendering incorrectly in some terminals | Low | Low | Use only standard Unicode box-drawing chars from box-drawing-guide.md |
| Merge conflicts if other tasks modify same files | Medium | Low | Commit each phase independently; phases touch distinct file sets |

## Implementation Phases

### Phase 1: Fix CLAUDE.md Errors and Gaps [COMPLETED]

**Goal**: Correct factual errors and add missing entries in the primary configuration file (.claude/CLAUDE.md)

**Tasks**:
- [ ] Fix "Four layers" to "Five layers" in Context Architecture section (Finding 13)
- [ ] Fix /fix-it description: change `Scan for FIX:/NOTE:/TODO: tags` to `Scan for FIX:/NOTE:/TODO:/QUESTION: tags` (Finding 11)
- [ ] Add `/merge` command to Command Reference table (Finding 1)
- [ ] Add `skill-orchestrator` and `skill-git-workflow` to Skill-to-Agent Mapping table (Finding 2)
- [ ] Add `founder` and `present` to extension language example list (Finding 17)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/CLAUDE.md` - All changes in this phase

**Verification**:
- grep confirms "Five layers" replaces "Four layers"
- /fix-it description includes all 4 tag types
- /merge appears in Command Reference table
- skill-orchestrator and skill-git-workflow appear in Skill-to-Agent Mapping
- Extension language list includes founder and present

---

### Phase 2: Fix README.md Errors and Gaps [COMPLETED]

**Goal**: Correct factual errors, add missing commands, flags, and extensions to the main README.md

**Tasks**:
- [ ] Fix extension names: `neovim` to `nvim`, `lean4` to `lean` in Extensions table (Finding 9)
- [ ] Add 7 missing extensions to Extensions table: z3, epidemiology, formal, filetypes, founder, present, memory (Finding 10)
- [ ] Fix /fix-it description: change `Scan for FIX:/TODO: tags` to `Scan for FIX:/NOTE:/TODO:/QUESTION: tags` (Finding 11)
- [ ] Add `/merge` and `/tag` to Quick Reference table (Findings 1, 5)
- [ ] Add `[--team]` flags to /research, /plan, /implement usage (Finding 12)
- [ ] Expand Skills table or add note pointing to CLAUDE.md for complete listing (Finding 2, A-3)
- [ ] Expand Context Organization table or add note about additional directories (Finding 14)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/README.md` - All changes in this phase

**Verification**:
- Extensions table lists all 14 extensions with correct directory names
- Quick Reference includes /merge and /tag
- /research, /plan, /implement show [--team] flag
- /fix-it includes all 4 tag types
- Skills section references CLAUDE.md for complete mapping

---

### Phase 3: Fix extensions/README.md and Component READMEs [COMPLETED]

**Goal**: Fix the present extension attribution error, add spawn-agent to agents table, add orphaned guide to docs index, and add core-index-entries.json path

**Tasks**:
- [ ] Fix `present` row in extensions/README.md: remove `deck` language, change to `present` language only, update description to "Grant writing and proposal development" (Finding 15)
- [ ] Add full path `.claude/context/core-index-entries.json` to loading procedure step 2 (Finding 18)
- [ ] Add `spawn-agent` to `agents/README.md` table (Finding 3)
- [ ] Add `tts-stt-integration.md` to `docs/README.md` guides section (Finding 4)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/README.md` - Fix present row, add path
- `.claude/agents/README.md` - Add spawn-agent
- `.claude/docs/README.md` - Add orphaned guide reference

**Verification**:
- extensions/README.md present row shows language "present" (not "deck, grant")
- core-index-entries.json has full path in loading steps
- agents/README.md lists 6 agents including spawn-agent
- docs/README.md references tts-stt-integration.md

---

### Phase 4: Update founder/README.md [COMPLETED]

**Goal**: Bring founder extension README up to date with all 8 commands, 12 agents, and 12 skills

**Tasks**:
- [ ] Update command count from "five" to "eight" in overview text
- [ ] Add `/deck`, `/finance`, `/sheet` to the commands overview table with purposes and outputs
- [ ] Add deck, finance, and spreadsheet agents to the Per-Type Research Agents table
- [ ] Update the architecture tree to include all missing files: 3 commands, 5 skills, 5 agents, deck context directory
- [ ] Add brief command documentation sections for /deck, /finance, /sheet (syntax, modes, outputs)

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/README.md` - All changes in this phase

**Verification**:
- README references "eight commands" consistently
- Commands table lists all 8 commands
- Per-Type Research Agents table lists all agents
- Architecture tree matches actual directory listing
- Each new command has a documentation section

---

### Phase 5: Convert ASCII Box-Drawing to Unicode [COMPLETED]

**Goal**: Replace ASCII box-drawing characters with Unicode equivalents in user-facing documentation per box-drawing-guide.md

**Tasks**:
- [ ] Convert README.md architecture diagram (lines ~35-62): replace `+---+` with `┌───┐`, `|` with `│`, etc.
- [ ] Convert docs/architecture/system-overview.md three-layer diagram: same ASCII-to-Unicode conversion
- [ ] Convert docs/architecture/extension-system.md extension flow diagram (lines ~15-28)
- [ ] Update docs/architecture/system-overview.md commands table: add 5 missing commands (/fix-it, /refresh, /tag, /spawn, /merge) (Finding 5)
- [ ] Update docs/architecture/system-overview.md skills table: replace extension-specific skills with core skills (Finding 7)

**Timing**: 1 hour 15 minutes

**Files to modify**:
- `.claude/README.md` - Architecture diagram only
- `.claude/docs/architecture/system-overview.md` - Diagram + tables
- `.claude/docs/architecture/extension-system.md` - Diagram only

**Verification**:
- No `+---+` or `+----+` patterns remain in modified diagram sections (excluding code blocks showing generated output)
- All box-drawing uses Unicode characters: `┌`, `┐`, `└`, `┘`, `│`, `─`, `├`, `┤`, `┬`, `┴`, `┼`
- system-overview.md commands table lists all 14 commands
- system-overview.md skills table lists core skills, not extension skills

## Testing & Validation

- [ ] All modified files are valid Markdown (no broken tables or formatting)
- [ ] grep for `+---` in modified files confirms no remaining ASCII boxes (outside code blocks/DAG examples)
- [ ] Cross-reference: every command in `.claude/commands/` appears in at least CLAUDE.md or README.md
- [ ] Cross-reference: every skill in `.claude/skills/` appears in CLAUDE.md Skill-to-Agent Mapping
- [ ] Cross-reference: every agent in `.claude/agents/` appears in agents/README.md
- [ ] founder/README.md command count matches `ls .claude/extensions/founder/commands/ | wc -l`
- [ ] extensions/README.md extension count matches `ls -d .claude/extensions/*/ | wc -l`

## Artifacts & Outputs

- plans/01_documentation-review-plan.md (this file)
- summaries/01_documentation-review-summary.md (post-implementation)
- Modified files across 5 phases (listed per phase above)

## Rollback/Contingency

Each phase modifies a distinct set of files and is committed independently. To revert any phase, use `git revert <commit-hash>` for the specific phase commit. No phase creates or deletes files; all changes are edits to existing documentation.
