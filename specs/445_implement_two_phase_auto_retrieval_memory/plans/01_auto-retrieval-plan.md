# Implementation Plan: Two-Phase Auto-Retrieval for Memory System

- **Task**: 445 - Implement two-phase auto-retrieval for memory system
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: Task 444 (memory-index.json creation -- completed)
- **Research Inputs**: specs/445_implement_two_phase_auto_retrieval_memory/reports/01_auto-retrieval-research.md
- **Artifacts**: plans/01_auto-retrieval-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Implement automatic memory retrieval for /research, /plan, and /implement commands using a two-phase approach: Phase 1 scores the memory-index.json to select top-K candidates by keyword overlap, topic match, and recency; Phase 2 reads only the selected memory files and injects them as context into the skill delegation. A shared bash script encapsulates the scoring and retrieval logic so all three skills call the same implementation. A --clean flag allows users to skip retrieval when desired.

### Research Integration

Key findings from the research report (01_auto-retrieval-research.md):
- memory-index.json already contains all fields needed for scoring (keywords, topic, category, token_count, retrieval_count, last_retrieved)
- The injection point is Stage 4 (Prepare Delegation Context) in each skill, as a new sub-stage 4a
- A shared script at `.claude/scripts/memory-retrieve.sh` avoids duplicating scoring logic across three skills
- The --clean flag follows existing flag-parsing patterns in STAGE 1.5 of each command file
- Token budget of 2000 tokens with greedy selection and max 5 entries recommended
- Prompt-based injection (text block) preferred over JSON field injection

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Make memory retrieval automatic (default on) for /research, /plan, /implement
- Implement two-phase retrieval: score JSON index, then read only selected files
- Keep retrieval fast by operating on the index rather than reading all memory files
- Track retrieval usage by updating retrieval_count and last_retrieved
- Provide --clean flag to skip retrieval when not wanted

**Non-Goals**:
- Replacing the existing --remember flag on /research (that uses MCP search, a different mechanism)
- Implementing semantic search or embedding-based retrieval
- Exposing token budget or max-entries as user-facing flags (constants in v1)
- Adding memory retrieval to team-mode skills (can be added later)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| memory-index.json missing or empty | L | M | Graceful skip -- script exits 1 silently, skill proceeds without memory |
| jq scoring logic fragile across platforms | M | M | Keep scoring simple (keyword overlap count), test with empty/single/multi-entry indexes |
| Skill SKILL.md edits break existing flow | H | L | Insert new Stage 4a as isolated block; existing stages unchanged |
| Token budget exceeded by large memories | M | L | Hard cap at 2000 tokens with greedy selection; max 5 entries |
| --clean flag conflicts with existing flags | L | L | Uses same parsing pattern as --fast/--hard; no naming collisions |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create Shared Retrieval Script [COMPLETED]

**Goal**: Build the memory-retrieve.sh script that encapsulates both phases of retrieval (score index, read files) and outputs formatted memory context.

**Tasks**:
- [ ] Create `.claude/scripts/memory-retrieve.sh` with usage interface: `memory-retrieve.sh <description> <task_type> [focus_prompt]`
- [ ] Implement keyword extraction from description+focus: lowercase, remove stop words, filter words <= 3 chars, deduplicate, take top 10
- [ ] Implement validate-on-read: check `.memory/memory-index.json` exists and has entries, skip gracefully if not
- [ ] Implement Phase 1 scoring: keyword overlap count between task keywords and entry keywords using jq, with topic match bonus
- [ ] Implement Phase 2 selection: sort by score descending, greedy select top-K entries within 2000-token budget, max 5 entries, minimum score threshold > 0
- [ ] Read selected memory files and format as `<memory-context>` text block with entry titles and relevance scores
- [ ] Update retrieval_count (increment by 1) and last_retrieved (today's ISO date) in memory-index.json for each selected entry
- [ ] Handle edge cases: no matches above threshold, index file missing, malformed entries
- [ ] Exit code 0 with content on stdout when memories found; exit code 1 (empty stdout) when no matches or index missing

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/memory-retrieve.sh` -- NEW: shared retrieval script

**Verification**:
- Script runs without errors when memory-index.json exists with entries
- Script exits 1 silently when memory-index.json is missing
- Script exits 1 when no keywords match any entries
- Output contains `<memory-context>` wrapper with formatted memory content
- retrieval_count increments and last_retrieved updates in memory-index.json after successful retrieval

---

### Phase 2: Integrate Retrieval into Skills [COMPLETED]

**Goal**: Add Stage 4a (Memory Retrieval) to skill-researcher, skill-planner, and skill-implementer, injecting retrieved memory into the delegation prompt.

**Tasks**:
- [ ] Add Stage 4a to `.claude/skills/skill-researcher/SKILL.md` between artifact number calculation and delegation context preparation
- [ ] Add Stage 4a to `.claude/skills/skill-planner/SKILL.md` at the same injection point
- [ ] Add Stage 4a to `.claude/skills/skill-implementer/SKILL.md` at the same injection point
- [ ] In each Stage 4a: check `clean_flag` field from delegation context; if true, skip retrieval
- [ ] In each Stage 4a: call `memory-retrieve.sh "$description" "$task_type" "$focus_prompt"` and capture output
- [ ] Inject memory_context into the delegation prompt using `<memory-context>` block (alongside existing format injection in Stage 4b/5)
- [ ] Ensure empty memory_context (no matches) does not inject an empty block

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` -- Add Stage 4a memory retrieval block
- `.claude/skills/skill-planner/SKILL.md` -- Add Stage 4a memory retrieval block
- `.claude/skills/skill-implementer/SKILL.md` -- Add Stage 4a memory retrieval block

**Verification**:
- Each skill SKILL.md contains a Stage 4a section with memory retrieval logic
- Stage 4a checks clean_flag and skips when true
- Memory context is injected into the delegation prompt only when non-empty
- Existing skill flow (Stages 1-4, 5+) is not disrupted

---

### Phase 3: Add --clean Flag to Commands [IN PROGRESS]

**Goal**: Parse the --clean flag in /research, /plan, and /implement commands and pass it through to the skill delegation context.

**Tasks**:
- [ ] Add `--clean` case to flag parsing in `.claude/commands/research.md` STAGE 1.5 (between effort flags and remaining text extraction)
- [ ] Add `--clean` case to flag parsing in `.claude/commands/plan.md` at the equivalent stage
- [ ] Add `--clean` case to flag parsing in `.claude/commands/implement.md` at the equivalent stage
- [ ] In each command, pass `clean_flag` field in the delegation context JSON sent to the skill
- [ ] Update command reference table in `.claude/CLAUDE.md` to document --clean flag on all three commands

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/commands/research.md` -- Add --clean flag parsing and passthrough
- `.claude/commands/plan.md` -- Add --clean flag parsing and passthrough
- `.claude/commands/implement.md` -- Add --clean flag parsing and passthrough
- `.claude/CLAUDE.md` -- Update command reference table with --clean flag

**Verification**:
- Each command file has a `--clean)` case in its flag parsing section
- Delegation context includes `clean_flag: true` when --clean is passed
- CLAUDE.md command table shows --clean flag on /research, /plan, /implement

---

### Phase 4: Validation and Documentation [NOT STARTED]

**Goal**: End-to-end validation of the auto-retrieval pipeline and final documentation updates.

**Tasks**:
- [ ] Verify memory-retrieve.sh produces correct output with the existing memory-index.json entries
- [ ] Verify --clean flag correctly suppresses retrieval (no memory-retrieve.sh call)
- [ ] Verify retrieval_count and last_retrieved update correctly in memory-index.json after a retrieval
- [ ] Verify graceful degradation when memory-index.json is missing or has zero entries
- [ ] Check all three skill SKILL.md files have consistent Stage 4a implementations
- [ ] Check all three command files have consistent --clean flag parsing
- [ ] Verify no regressions in existing --remember flag behavior on /research

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Files to modify**:
- No new files; validation only with possible minor fixes to files from earlier phases

**Verification**:
- Full pipeline works: command parses flags -> skill calls retrieval script -> memory injected into delegation prompt
- --clean flag suppresses the entire retrieval path
- Missing or empty index does not cause errors
- Existing --remember functionality on /research is unaffected

## Testing & Validation

- [ ] memory-retrieve.sh returns formatted output when matching memories exist
- [ ] memory-retrieve.sh exits silently (code 1) when no index exists
- [ ] memory-retrieve.sh exits silently (code 1) when no keywords match
- [ ] memory-retrieve.sh respects 2000-token budget and 5-entry maximum
- [ ] retrieval_count increments and last_retrieved updates after successful retrieval
- [ ] Skill Stage 4a integrates cleanly between existing stages
- [ ] --clean flag parsed correctly in all three commands
- [ ] --clean flag suppresses memory retrieval in all three skills
- [ ] Existing --remember flag on /research still works independently
- [ ] Empty memory context does not inject empty `<memory-context>` block

## Artifacts & Outputs

- `.claude/scripts/memory-retrieve.sh` -- New shared retrieval script
- `.claude/skills/skill-researcher/SKILL.md` -- Updated with Stage 4a
- `.claude/skills/skill-planner/SKILL.md` -- Updated with Stage 4a
- `.claude/skills/skill-implementer/SKILL.md` -- Updated with Stage 4a
- `.claude/commands/research.md` -- Updated with --clean flag
- `.claude/commands/plan.md` -- Updated with --clean flag
- `.claude/commands/implement.md` -- Updated with --clean flag
- `.claude/CLAUDE.md` -- Updated command reference

## Rollback/Contingency

All changes are additive: a new script file and new Stage 4a blocks in existing files. Rollback consists of:
1. Delete `.claude/scripts/memory-retrieve.sh`
2. Remove Stage 4a blocks from the three skill SKILL.md files
3. Remove --clean flag parsing from the three command files
4. Revert CLAUDE.md command table changes

No existing functionality is modified, only extended. The --clean flag and Stage 4a are isolated additions that do not alter existing stages or flag parsing.
