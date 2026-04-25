# Research Report: Task #491

**Task**: 491 - research_roadmap_preflight
**Started**: 2026-04-25T00:00:00Z
**Completed**: 2026-04-25T00:15:00Z
**Effort**: Small (3 files to modify)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.claude/commands/research.md`, `.claude/skills/skill-researcher/SKILL.md`, `.claude/agents/general-research-agent.md`
- Codebase: `.claude/skills/skill-planner/SKILL.md` (comparison pattern)
- Codebase: `specs/ROADMAP.md`, `.claude/context/formats/roadmap-format.md`
- Codebase: `.claude/scripts/memory-retrieve.sh` (pattern reference)
**Artifacts**:
- specs/491_research_roadmap_preflight/reports/01_research-roadmap-preflight.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `roadmap_path` field is already passed in the delegation context from `skill-researcher` to `general-research-agent`, and the agent already has Stage 1.5 to read the roadmap -- but the roadmap content is NOT pre-read or injected by the skill, meaning the agent burns tokens reading it each time
- The task requests moving roadmap consultation to the skill preflight (like memory retrieval in Stage 4a), reading ROADMAP.md content and injecting it into the agent prompt so agents receive it without doing file I/O
- The `--clean` flag already suppresses memory retrieval in Stage 4a; it should also suppress roadmap injection using the same `clean_flag` check
- Three files need changes: `research.md` (document the flag behavior), `skill-researcher/SKILL.md` (add Stage 4c for roadmap reading), and `general-research-agent.md` (receive injected content instead of self-reading)
- The current ROADMAP.md is small (29 lines) so full content injection is feasible and preferred over summary extraction

## Context & Scope

The `/research` command flow is: `/research` command -> `skill-researcher` (preflight, delegation, postflight) -> `general-research-agent` (does the work). The task asks for roadmap consultation to happen during the skill's preflight phase, injected into the agent prompt alongside memory context, rather than having each agent read it independently.

Current state:
- `skill-researcher/SKILL.md` Stage 4 already sets `"roadmap_path": "specs/ROADMAP.md"` in the delegation context JSON
- `general-research-agent.md` Stage 1.5 already describes reading the roadmap file if `roadmap_path` is provided
- The `--clean` flag is parsed in `research.md` Stage 1.5 and passed as `clean_flag` to the skill
- `skill-researcher/SKILL.md` Stage 4a uses `clean_flag` to skip memory retrieval

## Findings

### Codebase Patterns

**Pattern: Memory retrieval as the template (Stage 4a in skill-researcher/SKILL.md)**

The memory retrieval pattern at Stage 4a is the exact template to follow:

1. Check `clean_flag` -- skip if true
2. Run a script/command to produce content
3. If non-empty, inject into Stage 5 prompt as a tagged block
4. If empty (file missing, error, etc.), skip gracefully

Memory uses `<memory-context>` tags. Roadmap should use `<roadmap-context>` tags for consistency.

**Pattern: Delegation context already includes roadmap_path**

The `skill-researcher/SKILL.md` Stage 4 delegation context already includes:
```json
"roadmap_path": "specs/ROADMAP.md"
```

This can remain (for agents that might want to re-read), but the primary mechanism shifts to injected content in the prompt.

**Pattern: Agent Stage 1.5 already handles roadmap**

The `general-research-agent.md` Stage 1.5 describes:
1. Read roadmap file if `roadmap_path` is provided
2. Extract current phase priorities
3. Store as `roadmap_context` for Stage 2

With preflight injection, Stage 1.5 becomes: "Parse the injected `<roadmap-context>` block if present, OR fall back to reading `roadmap_path` if no injected content."

**Pattern: skill-planner also passes roadmap_path**

The planner skill (SKILL.md line 196) also sets `"roadmap_path": "specs/ROADMAP.md"`. This same preflight injection pattern should eventually be applied to `/plan` and `/implement` for consistency, but that is out of scope for this task.

**Pattern: Team research skill**

`skill-team-research/SKILL.md` line 210 also passes `"roadmap_path": "specs/ROADMAP.md"` and line 292 instructs the roadmap teammate to read it. The team skill should also get the preflight injection, but this can be a follow-up.

### Roadmap Content Analysis

Current `specs/ROADMAP.md` is 29 lines with:
- Phase 1: Current Priorities (High Priority) -- 7 items across 2 categories
- Phase 2: Medium-Term Improvements -- 2 items
- Success Metrics -- 4 items

At 29 lines this is well within any reasonable injection budget. Full content injection is the right approach (no summarization needed). If the roadmap grows beyond ~100 lines, a future enhancement could extract only Phase 1 (current priorities).

### Recommendations

**Approach: Add Stage 4c to skill-researcher/SKILL.md**

Place the roadmap reading AFTER memory retrieval (Stage 4a) and BEFORE delegation context preparation (Stage 4). The ordering rationale:
- Memory retrieval (4a) is the primary context enhancement
- Roadmap is secondary strategic context
- Both feed into the delegation prompt (Stage 5)

**New Stage 4c: Roadmap Consultation (Auto)**

```bash
# Check clean_flag (same as memory retrieval)
roadmap_context=""
if [ "$clean_flag" != "true" ]; then
  roadmap_file="specs/ROADMAP.md"
  if [ -f "$roadmap_file" ]; then
    roadmap_context=$(cat "$roadmap_file")
  fi
fi
```

If `roadmap_context` is non-empty, inject into Stage 5 prompt as:

```
<roadmap-context>
## Project Roadmap (auto-injected, read-only)

{roadmap_context}
</roadmap-context>
```

Place AFTER `<memory-context>` block and BEFORE task-specific instructions.

**Changes to general-research-agent.md Stage 1.5**

Update to prefer injected content:
- If `<roadmap-context>` is present in the prompt, parse it directly (no file I/O needed)
- If not present (e.g., `--clean` was used, or file was missing), optionally fall back to reading `roadmap_path` from delegation context
- Keep `roadmap_path` in delegation context as a fallback mechanism

**Changes to research.md**

Add documentation that `--clean` suppresses both memory retrieval AND roadmap consultation. Update the `--clean` flag description in the Options table:

Current: `--clean | Skip automatic memory retrieval | false`
New: `--clean | Skip automatic memory and roadmap retrieval | false`

## Decisions

1. **Full content injection over summary**: The roadmap is small enough (29 lines) to inject in full. No summarization logic needed.
2. **Stage 4c placement**: After memory (4a) and format injection (4b), before delegation context (Stage 4). This groups all "context injection" stages together.
3. **`--clean` suppresses roadmap**: Consistent with memory suppression. One flag controls all auto-injections.
4. **Keep `roadmap_path` in delegation context**: Backward compatibility -- agents that don't receive injected content can still self-read.
5. **`<roadmap-context>` tag name**: Follows the `<memory-context>` pattern for consistency.
6. **No script needed**: Unlike memory retrieval (which needs scoring/filtering), roadmap injection is a simple file read. No new script required.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Roadmap grows very large | Low | Medium (wasted tokens) | Add size check; if >100 lines, extract only Phase 1 headers and incomplete items |
| ROADMAP.md doesn't exist | Low | None | Graceful skip (empty string check) already in pattern |
| Team research skill not updated | Medium | Low | Team skill already passes roadmap_path; injected content is additive. Can update separately |
| Other commands (plan, implement) inconsistent | Medium | Low | Document as follow-up; they already pass roadmap_path for agent self-reading |

## Appendix

### Files to Modify

1. **`.claude/commands/research.md`** -- Update `--clean` flag description in Options table (line 39)
2. **`.claude/skills/skill-researcher/SKILL.md`** -- Add Stage 4c between Stage 4a (memory) and Stage 4b (format injection), update Stage 5 prompt injection instructions
3. **`.claude/agents/general-research-agent.md`** -- Update Stage 1.5 to prefer injected `<roadmap-context>` over self-reading, keep fallback

### Implementation Effort Estimate

- research.md: 1 line change (flag description)
- skill-researcher/SKILL.md: ~25 lines new (Stage 4c) + ~5 lines modified (Stage 5 injection)
- general-research-agent.md: ~10 lines modified (Stage 1.5 update)
- Total: ~40 lines across 3 files, straightforward pattern replication

### Search Queries Used

- Codebase: `roadmap` in `.claude/skills/` (found all skills passing roadmap_path)
- Codebase: `roadmap|clean_flag|--clean` in skill-planner for comparison pattern
- Codebase: Full read of research.md, skill-researcher/SKILL.md, general-research-agent.md, ROADMAP.md, roadmap-format.md
