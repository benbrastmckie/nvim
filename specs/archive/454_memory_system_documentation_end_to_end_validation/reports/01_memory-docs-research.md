# Research Report: Task #454

**Task**: 454 - Memory system documentation and end-to-end validation
**Started**: 2026-04-16T00:00:00Z
**Completed**: 2026-04-16T00:30:00Z
**Effort**: medium
**Dependencies**: 444, 445, 446, 447, 448, 449, 450, 451, 452, 453 (all completed)
**Sources/Inputs**: Codebase exploration (Glob, Grep, Read)
**Artifacts**: specs/454_memory_system_documentation_end_to_end_validation/reports/01_memory-docs-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All 10 prerequisite tasks (444-453) are completed. The memory system is fully implemented.
- CLAUDE.md has **no Memory Extension section**. The `merge_targets.claudemd` in manifest.json points to `EXTENSION.md` for section_id `extension_memory`, but this section has never been merged into `.claude/CLAUDE.md`.
- The skill-memory README.md documents `/learn` modes but has **no distill mode documentation**. The distill mode is fully specified in SKILL.md but the README only covers standard and task modes.
- The `context/index.json` has **no memory-related entries**. Extension entries in `index-entries.json` exist (6 entries) but are extension-scoped; the core index has zero memory references.
- No `distill-usage.md` context file exists. A learn-usage.md and knowledge-capture-usage.md exist but distill has no dedicated usage guide.
- No `--reindex` documentation exists anywhere in the codebase (search returned zero results). This feature may not be implemented or may need to be documented as a planned feature.
- The EXTENSION.md has stale `/distill --purge`, `--merge`, `--compress` entries marked as "placeholder" when all are now available.

## Context & Scope

This research examines the current state of the memory system documentation across all components created in tasks 444-453. The scope covers five documentation deliverables and an end-to-end validation checklist.

### System Components Surveyed

| Component | Location | Status |
|-----------|----------|--------|
| `/learn` command | `.claude/extensions/memory/commands/learn.md` | Complete |
| `/distill` command | `.claude/extensions/memory/commands/distill.md` | Complete |
| skill-memory SKILL.md | `.claude/extensions/memory/skills/skill-memory/SKILL.md` | Complete (2479 lines) |
| skill-memory README.md | `.claude/extensions/memory/skills/skill-memory/README.md` | Incomplete (no distill mode) |
| Extension README.md | `.claude/extensions/memory/README.md` | Stale (placeholders) |
| EXTENSION.md | `.claude/extensions/memory/EXTENSION.md` | Stale (placeholders) |
| manifest.json | `.claude/extensions/memory/manifest.json` | Complete |
| index-entries.json | `.claude/extensions/memory/index-entries.json` | Incomplete (no distill entry) |
| memory-retrieve.sh | `.claude/scripts/memory-retrieve.sh` | Complete |
| memory-nudge.sh | `.claude/hooks/memory-nudge.sh` | Complete, registered in settings.json |
| memory-index.json | `.memory/memory-index.json` | Complete (1 entry) |
| distill-log.json | `.memory/distill-log.json` | Complete (empty, no operations yet) |
| learn-usage.md | `.claude/extensions/memory/context/project/memory/learn-usage.md` | Complete |
| knowledge-capture-usage.md | `.claude/extensions/memory/context/project/memory/knowledge-capture-usage.md` | Complete |
| memory-setup.md | `.claude/extensions/memory/context/project/memory/memory-setup.md` | Complete |
| memory-troubleshooting.md | `.claude/extensions/memory/context/project/memory/memory-troubleshooting.md` | Complete |
| memory-reference.md | `.claude/extensions/memory/context/project/memory/domain/memory-reference.md` | Complete |

## Findings

### Finding 1: CLAUDE.md Missing Memory Extension Section

The `.claude/CLAUDE.md` file contains no `## Memory Extension` section and no reference to the memory system. The manifest.json specifies:

```json
"merge_targets": {
  "claudemd": {
    "source": "EXTENSION.md",
    "target": ".claude/CLAUDE.md",
    "section_id": "extension_memory"
  }
}
```

The EXTENSION.md content is ready to merge but has stale markers. The merge has never occurred. The CLAUDE.md should include:
- `/learn` and `/distill` commands in the Command Reference table
- `/memory --reindex` if implemented
- skill-memory in the Skill-to-Agent Mapping table
- `--clean` flag documentation (already present in the Command Reference for `/research`, `/plan`, `/implement`)
- `--remember` flag documentation (if still applicable; currently only referenced in memory extension README)

**Note on --remember vs auto-retrieval**: The README documents `--remember` as a flag for `/research`, but the actual implementation uses **automatic retrieval** via `memory-retrieve.sh` in the skill-researcher preflight. The `--clean` flag **suppresses** this auto-retrieval. There is no `--remember` flag in the research.md command file. The README is outdated on this point -- auto-retrieval replaced the opt-in `--remember` design.

### Finding 2: skill-memory README.md Missing Distill Mode

The README.md at `.claude/extensions/memory/skills/skill-memory/README.md` documents:
- Standard Mode (text/file/directory)
- Task Mode

It does not mention:
- Distill mode (report, purge, merge, compress, refine, gc, auto sub-modes)
- The scoring engine
- Validate-on-read
- Any distill-related functionality

The SKILL.md itself contains full distill documentation (lines 933-2479), so the information source exists.

### Finding 3: context/index.json Has No Memory Entries

The core `.claude/context/index.json` contains zero entries for memory-related context files. The extension's `index-entries.json` has 6 entries:

| Path | Commands |
|------|----------|
| project/memory/learn-usage.md | /learn |
| project/memory/memory-setup.md | /learn |
| project/memory/memory-troubleshooting.md | (skill-memory) |
| project/memory/domain/memory-reference.md | /learn |
| project/memory/knowledge-capture-usage.md | /learn |
| project/memory/domain/memory-reference.md | /distill |

**Issues with index-entries.json**:
1. `memory-reference.md` is listed twice with different descriptions (once for /learn, once for /distill)
2. No entry references the `/distill` command's sub-modes or the scoring engine context
3. No entry is tagged for the general-research-agent (memory retrieval context)

### Finding 4: No distill-usage.md Context File

A `distill-usage.md` does not exist. The existing context files cover:
- `learn-usage.md` -- Usage guide for /learn
- `knowledge-capture-usage.md` -- Example workflows (includes /learn, /fix-it, /todo)
- `memory-setup.md` -- MCP configuration
- `memory-troubleshooting.md` -- Troubleshooting
- `domain/memory-reference.md` -- Reference card

A dedicated `distill-usage.md` would document:
- Bare `/distill` for health reports
- `/distill --purge` workflow
- `/distill --merge` workflow
- `/distill --compress` workflow
- `/distill --refine` workflow
- `/distill --gc` workflow
- `/distill --auto` for automated maintenance
- `--dry-run` and `--verbose` flags
- Scoring formula explanation for users
- Recommended maintenance cadence

### Finding 5: /memory --reindex Does Not Exist

Search for `--reindex` or `reindex` across the entire `.claude/` directory returned zero results. This feature is not implemented. The closest equivalent is the validate-on-read mechanism in SKILL.md which auto-regenerates `memory-index.json` when stale. If `--reindex` is desired as an explicit user command, it would need to be created as a new command or a flag on an existing command.

### Finding 6: EXTENSION.md Has Stale Placeholder Markers

The EXTENSION.md (merged into CLAUDE.md) contains:

```markdown
| `/distill` | `/distill --purge` | Remove low-value memories (placeholder) |
| `/distill` | `/distill --merge` | Combine duplicate memories (placeholder) |
| `/distill` | `/distill --compress` | Reduce oversized memories (placeholder) |
```

All three are now fully implemented (tasks 450, 451, 452). The "(placeholder)" markers need removal. Additionally, `--refine`, `--gc`, and `--auto` sub-modes are missing from EXTENSION.md entirely.

### Finding 7: Auto-Retrieval Architecture

The auto-retrieval system implemented in task 445 works as follows:

1. `memory-retrieve.sh` is called from skill-researcher, skill-planner, and skill-implementer preflights
2. It reads `.memory/memory-index.json`, extracts keywords from the task description
3. Scores entries by keyword overlap + topic match bonus
4. Greedily selects entries within TOKEN_BUDGET=2000 and MAX_ENTRIES=5
5. Formats output as `<memory-context>` XML block
6. Updates `retrieval_count` and `last_retrieved` in memory-index.json
7. The `--clean` flag in commands suppresses this retrieval

**Token budget discrepancy**: The task description mentions a 3000-token budget, but `memory-retrieve.sh` uses TOKEN_BUDGET=2000. This should be noted in the validation checklist.

### Finding 8: Memory Nudge Stop Hook

The `memory-nudge.sh` hook is:
- Registered in `.claude/settings.json` Stop hooks
- Pattern-matches for lifecycle completion signals (task completion, research, plan, implementation, archive, review)
- Extracts task number and suggests `/learn --task N`
- Has 5-minute cooldown via `specs/tmp/memory-nudge-last`
- Suppresses for subagent contexts (checks `agent_id`)
- Always exits 0 (never blocks Claude)

### Finding 9: /todo Memory Harvest

Task 447 added a Stage 7 "HarvestMemories" to skill-todo that:
- Collects `memory_candidates` from state.json entries of completed tasks
- Deduplicates against existing memory-index.json by keyword overlap
- Pre-classifies candidates (TECHNIQUE, PATTERN, CONFIG, WORKFLOW, INSIGHT)
- Presents via AskUserQuestion for batch review
- Executes selected operations (CREATE/EXTEND/UPDATE)

### Finding 10: Tombstone Exclusion

Task 453 integrated tombstone filtering into:
- `memory-retrieve.sh`: Pre-filters with `select((.status // "active") == "active")`
- SKILL.md MCP search path: Post-filter excludes tombstoned entries
- SKILL.md grep fallback: Checks frontmatter status before including
- Scoring engine: Skips tombstoned memories before computing scores

## Decisions

1. **--reindex**: Will document as "not implemented" and recommend it as either a future feature or note that validate-on-read provides equivalent functionality automatically.
2. **--remember vs --clean**: The README's `--remember` documentation is outdated. Auto-retrieval is the default behavior; `--clean` suppresses it. Documentation should reflect current architecture.
3. **Token budget**: Note the 2000-token constant in memory-retrieve.sh vs the 3000-token reference in the task description as a discrepancy for the implementation plan to resolve.

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| EXTENSION.md merge into CLAUDE.md may conflict with manual edits | Medium | Review CLAUDE.md diff carefully before merging |
| index-entries.json duplicate entry for memory-reference.md | Low | Deduplicate in implementation |
| Token budget discrepancy (2000 vs 3000) | Low | Verify intended budget with user during planning |
| No --reindex command exists | Medium | Document validate-on-read as the reindex mechanism |

## End-to-End Validation Checklist

This checklist documents what needs testing (not running tests). Each item maps to a specific system component.

### Self-Learning Subsystem (Tasks 444-448)

| # | Test Case | Component | How to Validate |
|---|-----------|-----------|-----------------|
| 1 | Auto-retrieval via memory-index.json | memory-retrieve.sh | Run `/research N` on a task with keywords matching existing memories; verify `<memory-context>` block appears in agent context |
| 2 | `--clean` flag skips retrieval | research.md, skill-researcher | Run `/research N --clean`; verify no memory-retrieve.sh call in agent context |
| 3 | memory-index.json validity | memory-index.json | Verify JSON schema: version, generated_at, entry_count, total_tokens, entries array with required fields per entry |
| 4 | Validate-on-read stale detection | SKILL.md validate-on-read | Add a MEM-*.md file manually to .memory/10-Memories/ without updating memory-index.json, then run /distill; verify index regenerates |
| 5 | /todo memory candidate harvest | skill-todo Stage 7 | Complete a task with memory_candidates in state.json, run /todo; verify candidates are presented for selection |
| 6 | Memory nudge stop hook | memory-nudge.sh | Complete a task lifecycle step; verify "[memory] Task N lifecycle step completed" message appears |
| 7 | Nudge cooldown (5 min) | memory-nudge.sh | Trigger nudge twice within 5 minutes; second should be suppressed |
| 8 | Nudge subagent suppression | memory-nudge.sh | Verify no nudge when agent_id is present in stop hook context |

### Distillation Subsystem (Tasks 449-453)

| # | Test Case | Component | How to Validate |
|---|-----------|-----------|-----------------|
| 9 | /distill health report | SKILL.md report sub-mode | Run bare `/distill`; verify formatted health report with overview, categories, clusters, retrieval stats, candidates, health score |
| 10 | /distill flag parsing | distill.md | Test each flag: `--purge`, `--merge`, `--compress`, `--refine`, `--gc`, `--auto`, `--dry-run`, `--verbose` |
| 11 | Scoring formula validation | SKILL.md scoring engine | For a known memory, manually compute: staleness(0.3) + zero_retrieval(0.25) + size_penalty(0.2) + duplicate(0.25); verify matches reported score |
| 12 | Tombstone exclusion from retrieval | memory-retrieve.sh + SKILL.md | Tombstone a memory, run `/research N`; verify tombstoned memory does not appear in retrieval results |
| 13 | Token budget enforcement | memory-retrieve.sh | Add memories totaling >2000 tokens; verify retrieval stops at TOKEN_BUDGET=2000 and MAX_ENTRIES=5 |
| 14 | Vault under 50 files | .memory/10-Memories/ | Verify `ls .memory/10-Memories/MEM-*.md | wc -l` returns count < 50 |
| 15 | Purge tombstone application | SKILL.md purge sub-mode | Run `/distill --purge`; verify frontmatter gets status:tombstoned, tombstoned_at, tombstone_reason fields |
| 16 | Merge keyword superset guarantee | SKILL.md merge sub-mode | Merge two memories; verify merged keywords contain union of both original keyword sets |
| 17 | Compress keyword preservation | SKILL.md compress sub-mode | Compress a memory; verify all original keywords are present in compressed content |
| 18 | Refine Tier 1 auto-fixes | SKILL.md refine sub-mode | Run `/distill --refine` on a memory with duplicate keywords; verify deduplication without user interaction |
| 19 | GC grace period enforcement | SKILL.md gc sub-mode | Tombstone a memory today; run `/distill --gc`; verify memory is NOT eligible (7-day grace) |
| 20 | Auto mode (Tier 1 only) | SKILL.md auto sub-mode | Run `/distill --auto`; verify only Tier 1 fixes applied, no AskUserQuestion calls |
| 21 | distill-log.json logging | distill-log.json | After any distill operation, verify log entry with correct type, pre_metrics, post_metrics, affected_memories |
| 22 | state.json memory_health update | state.json | After /distill, verify memory_health field updated with last_distilled, health_score, total_memories |
| 23 | Dry-run mode (no writes) | SKILL.md all sub-modes | Run `/distill --purge --dry-run`; verify no files are modified |

### Cross-Cutting Validation

| # | Test Case | Component | How to Validate |
|---|-----------|-----------|-----------------|
| 24 | Extension loading | manifest.json | Load memory extension; verify commands /learn and /distill become available |
| 25 | MCP graceful degradation | SKILL.md, memory-retrieve.sh | Close Obsidian; verify grep-based fallback works for both /learn search and retrieval |
| 26 | Index regeneration idempotency | SKILL.md | Run index regeneration twice; verify identical output |

## Appendix

### Documentation Deliverables Summary

| # | Deliverable | Current State | Action Needed |
|---|-------------|---------------|---------------|
| 1 | CLAUDE.md Memory Extension section | Missing entirely | Create section with commands, skill mapping, auto-retrieval docs |
| 2 | skill-memory README.md distill mode | Missing | Add Distill Mode section documenting all 7 sub-modes |
| 3 | context/index.json memory entries | No core entries (extension entries exist in index-entries.json) | Add/fix entries in index-entries.json; ensure /distill context loads |
| 4 | New distill-usage.md context file | Does not exist | Create with sub-mode workflows, scoring explanation, maintenance cadence |
| 5 | /memory --reindex documentation | Feature not implemented | Document validate-on-read as automatic equivalent; note --reindex as not applicable |

### EXTENSION.md Updates Needed

| Line | Current | Should Be |
|------|---------|-----------|
| 20 | `Remove low-value memories (placeholder)` | `Tombstone stale memories (interactive purge)` |
| 21 | `Combine duplicate memories (placeholder)` | `Combine duplicate memories by keyword overlap` |
| 22 | `Reduce oversized memories (placeholder)` | `Summarize oversized memories to key points` |
| -- | (missing) | `/distill --refine` - Improve memory metadata quality |
| -- | (missing) | `/distill --gc` - Hard-delete tombstoned memories past grace period |
| -- | (missing) | `/distill --auto` - Automated Tier 1 maintenance |

### Files Created/Modified by Tasks 444-453

| Task | Key Files Created/Modified |
|------|---------------------------|
| 444 | learn.md, SKILL.md (learn modes), manifest.json, README.md, EXTENSION.md, index-entries.json, context files, .memory/ vault structure |
| 445 | memory-retrieve.sh, skill-researcher/planner/implementer preflight sections, --clean flag in commands |
| 446 | return-metadata-file.md (memory_candidates field), agent .md files (memory candidate emission sections) |
| 447 | skill-todo/SKILL.md (Stage 7 HarvestMemories), knowledge-capture-usage.md |
| 448 | memory-nudge.sh, settings.json (Stop hook registration) |
| 449 | distill.md, SKILL.md (scoring engine, report sub-mode, distill-log schema, state integration) |
| 450 | SKILL.md (purge sub-mode, tombstone pattern, gc sub-mode, link-scan, retrieval exclusion) |
| 451 | SKILL.md (merge sub-mode, pairwise overlap, keyword superset guarantee, cross-reference update) |
| 452 | SKILL.md (compress sub-mode, refine sub-mode, auto sub-mode) |
| 453 | memory-retrieve.sh (tombstone pre-filter), SKILL.md (tombstone exclusion in scoring, grep fallback, MCP path) |

### Search Queries Used

- `Glob **/*memory*` in `.claude/` and `.memory/`
- `Glob **/*distill*` in `.claude/`
- `Grep --reindex` (zero results)
- `Grep --clean|memory.retrieve|auto.*retrieval`
- `Grep memory.*nudge|todo.*harvest|memory.*candidate`
- `Grep --remember` across `.claude/`
- Direct reads of all memory extension files, hooks, scripts, index files, and distill-log
