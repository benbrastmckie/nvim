# Research Report: Task #218

**Task**: 218 - implement_team_flag_for_research_command
**Started**: 2026-03-16T00:00:00Z
**Completed**: 2026-03-16T01:00:00Z
**Effort**: 8-12 hours
**Dependencies**: None
**Sources/Inputs**: ProofChecker commands, archived task 093, existing skills
**Artifacts**: specs/218_implement_team_flag_for_research_command/reports/01_team-flag-research.md
**Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- The ProofChecker project has implemented a full `--team` flag system for `/research`, `/plan`, and `/implement` commands
- The nvim config's `/research` command currently has NO flag parsing stage - arguments go directly to focus prompt
- Implementation requires: (1) Flag parsing stage in commands, (2) New team skills, (3) Team wave helpers, (4) Graceful degradation
- Archived task 093 recommended team mode as Priority 1 feature, estimated 8-12 hours implementation effort
- The experimental feature requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable

## Context & Scope

This research investigates implementing the `--team` flag for parallel multi-agent research, planning, and implementation. The investigation spans:

1. Current nvim config `/research`, `/plan`, `/implement` commands
2. ProofChecker's implementation of team mode
3. Archived task 093's recommendations from cross-repository investigation
4. Required new skills and utilities

## Findings

### 1. Current Command Structure (nvim)

The nvim config commands lack flag parsing entirely:

**research.md** (current):
```markdown
## Arguments

- `$1` - Task number (required)
- Remaining args - Optional focus/prompt for research direction
```

There is NO flag extraction stage. Any `--team` argument is passed as part of focus_prompt text.

**Routing table** (current):
| Language | Skill to Invoke |
|----------|-----------------|
| `general`, `meta`, `markdown` | `skill-researcher` |

No team skill routing exists.

### 2. ProofChecker Command Structure (Reference Implementation)

**research.md** (ProofChecker):
```markdown
## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--lean` | Force routing to `skill-lean-research` | (auto) |
| `--team` | Enable multi-agent parallel research | false |
| `--team-size N` | Number of teammates (2-4) | 2 |
```

**Has explicit STAGE 1.5: PARSE DOMAIN FLAGS**:
1. Extract domain override flags (`--lean`, `--logic`, etc.)
2. Extract `--team` and `--team-size N`
3. Remove all recognized flags from remaining args
4. Remaining text becomes `focus_prompt`

**Team routing override**:
```markdown
When `--team` is specified, research is delegated to `skill-team-research`
which spawns multiple research agents working in parallel.
```

### 3. ProofChecker Team Skills

ProofChecker has three dedicated team skills:

| Skill | Purpose | Team Size |
|-------|---------|-----------|
| `skill-team-research` | Parallel investigation with synthesis | 2-4 |
| `skill-team-plan` | Parallel plan generation with trade-off analysis | 2-3 |
| `skill-team-implement` | Parallel phase execution with debugger support | 2-4 |

**Key features**:
- Wave-based execution (Wave 1 parallel work, synthesis, optional Wave 2)
- Language-aware routing (different prompts for Lean vs general tasks)
- Model enforcement (`model: opus` for Lean, `model: sonnet` for others)
- Graceful degradation to single-agent when teams unavailable
- Run-scoped artifact naming (e.g., `research-001-teammate-a-findings.md`)
- Conflict detection and resolution during synthesis
- Successor teammate pattern for context exhaustion

### 4. Required Environmental Support

Team mode requires the experimental agent teams feature:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

**Graceful degradation** is required:
```
if [ "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" != "1" ]; then
  echo "Warning: Team mode unavailable, falling back to single agent"
  # Invoke regular skill instead
fi
```

### 5. Archived Task 093 Analysis

Task 093 (investigate_agent_system_changes_cross_repo) was completed 2026-02-24 and recommended:

**Priority 1: Team Mode Skills** (8-12 hours)
- Create `skill-team-research`, `skill-team-plan`, `skill-team-implement`
- Add `team-orchestration.md`, `team-metadata-extension.md`, `team-wave-helpers.md`
- Modify `/research`, `/plan`, `/implement` to accept `--team` flag

**Implementation completed for task 093** (from summary):
- Context index schema (index.json)
- Model enforcement in agent frontmatter
- Agent context discovery integration
- Research agent enhancements

**NOT implemented**: Team Mode Skills (marked as optional, requires experimental features)

### 6. Supporting Files Needed

Based on ProofChecker's implementation:

| File | Purpose | Lines |
|------|---------|-------|
| `.claude/skills/skill-team-research/SKILL.md` | Team research orchestration | ~648 |
| `.claude/skills/skill-team-plan/SKILL.md` | Team planning orchestration | ~589 |
| `.claude/skills/skill-team-implement/SKILL.md` | Team implementation orchestration | ~701 |
| `.claude/utils/team-wave-helpers.md` | Reusable wave patterns | ~647 |
| `.claude/context/core/patterns/team-orchestration.md` | Wave coordination patterns | ~226 |
| `.claude/context/core/formats/team-metadata-extension.md` | Team result schema | ~100 |

### 7. Teammate Prompt Templates

ProofChecker uses structured teammate prompts with angles:

**Research teammates**:
- A: Primary implementation approaches
- B: Alternative patterns and prior art
- C: Risk analysis (optional, size >= 3)
- D: Devil's advocate (optional, size >= 4)

**Planning teammates**:
- A: Plan version A (incremental delivery focus)
- B: Plan version B (alternative phase boundaries)
- C: Risk/dependency analysis (optional)

**Implementation teammates**:
- Per-phase implementers (parallel independent phases)
- Debugger (spawned on error)

### 8. Command Modifications Required

**research.md changes**:
1. Add Options section with `--team` and `--team-size N`
2. Add STAGE 1.5: PARSE FLAGS after CHECKPOINT 1
3. Add team routing logic in STAGE 2:
   ```
   If --team flag present:
     skill = "skill-team-research"
   Else:
     skill = {language-based routing}
   ```

**plan.md changes**:
1. Add Options section with `--team` and `--team-size N`
2. Add flag parsing stage
3. Add team routing to `skill-team-plan`

**implement.md changes**:
1. Add Options section with `--team` and `--team-size N`
2. Add flag parsing stage
3. Add team routing to `skill-team-implement`

### 9. Wave-Based Execution Model

The team mode uses a wave-based parallel execution model:

```
Wave 1:
+----------------+  +----------------+  +----------------+
| Teammate A     |  | Teammate B     |  | Teammate C     |
| Primary Angle  |  | Alternatives   |  | Risk Analysis  |
+-------+--------+  +-------+--------+  +-------+--------+
        |                   |                   |
        +-------------------+-------------------+
                           |
                    +------+------+
                    |   Lead      |
                    | Synthesis   |
                    +------+------+
                           |
              (Optional Wave 2 if gaps exist)
```

**Synthesis responsibilities**:
1. Extract key findings from each teammate
2. Detect and resolve conflicts
3. Identify coverage gaps
4. Decide on Wave 2 if needed
5. Generate unified output

### 10. Metadata Extension for Team Mode

Team execution metadata adds these fields:

```json
{
  "team_execution": {
    "enabled": true,
    "wave_count": 1,
    "teammates_spawned": 3,
    "teammates_completed": 3,
    "teammates_failed": 0,
    "token_usage_multiplier": 5.0,
    "degraded_to_single": false
  },
  "teammate_results": [...],
  "synthesis": {
    "conflicts_found": 2,
    "conflicts_resolved": 2,
    "gaps_identified": 0,
    "wave_2_triggered": false
  }
}
```

## Decisions

1. **Implement for all three commands**: `/research`, `/plan`, and `/implement` should all support `--team`
2. **Graceful degradation required**: Must fall back to single-agent if experimental feature unavailable
3. **Model enforcement**: Use `sonnet` for general/meta tasks (cost-effective for non-Lean work)
4. **Adapt prompts for nvim context**: Remove Lean-specific references, focus on neovim/meta patterns

## Recommendations

### Implementation Approach

**Phase 1: Command Flag Parsing (2-3 hours)**
1. Add STAGE 1.5: PARSE FLAGS to research.md
2. Add Options section with `--team`, `--team-size N`
3. Extract flags from remaining args before building focus_prompt
4. Repeat for plan.md and implement.md

**Phase 2: Team Research Skill (3-4 hours)**
1. Create `skill-team-research/SKILL.md`
2. Adapt ProofChecker template for nvim/meta focus
3. Include graceful degradation to skill-researcher
4. Add language routing for meta vs general

**Phase 3: Team Plan Skill (2-3 hours)**
1. Create `skill-team-plan/SKILL.md`
2. Adapt planning teammate prompts
3. Include synthesis with trade-off analysis

**Phase 4: Team Implement Skill (3-4 hours)**
1. Create `skill-team-implement/SKILL.md`
2. Include parallel phase execution
3. Add debugger teammate support

**Phase 5: Supporting Files (2-3 hours)**
1. Create `.claude/utils/team-wave-helpers.md`
2. Create `.claude/context/core/patterns/team-orchestration.md`
3. Create `.claude/context/core/formats/team-metadata-extension.md`

### Natural Improvements from ProofChecker

1. **Unified flag parsing pattern**: Extract to shared helper or document standard approach
2. **Environment variable documentation**: Document `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` requirement in CLAUDE.md
3. **Token usage awareness**: Log team token multiplier (~5x) in metadata for cost tracking
4. **Successor teammate pattern**: Enable long-running tasks to continue via context handoff

## Risks & Mitigations

### Risk: Experimental Feature Instability
- **Impact**: Breaking changes could disrupt team mode
- **Mitigation**: Graceful degradation to single-agent is mandatory, team mode optional

### Risk: Token Cost Increase
- **Impact**: Team mode uses ~5x tokens vs single agent
- **Mitigation**: Default team_size=2 (minimum), document cost implications, use only when explicitly requested

### Risk: Teammate Coordination Complexity
- **Impact**: Synthesis could fail or miss conflicts
- **Mitigation**: Start with Wave 1 only (no Wave 2), simple synthesis logic

### Risk: Context Exhaustion in Long Tasks
- **Impact**: Teammates could hit context limits without completing
- **Mitigation**: Implement successor teammate pattern (Phase 5 or follow-up task)

## Appendix

### Files Examined

**nvim config** (current state):
- `.claude/commands/research.md` - No flag parsing (127 lines)
- `.claude/commands/plan.md` - No flag parsing (125 lines)
- `.claude/commands/implement.md` - No flag parsing (232 lines)
- `.claude/skills/skill-researcher/SKILL.md` - Single-agent delegation (312 lines)

**ProofChecker** (reference implementation):
- `.claude/commands/research.md` - With flag parsing (180 lines)
- `.claude/commands/plan.md` - With flag parsing (135 lines)
- `.claude/commands/implement.md` - With flag parsing (320 lines)
- `.claude/skills/skill-team-research/SKILL.md` (648 lines)
- `.claude/utils/team-wave-helpers.md` (647 lines)

**Archived task 093**:
- `specs/archive/093_investigate_agent_system_changes_cross_repo/reports/research-001.md`
- `specs/archive/093_investigate_agent_system_changes_cross_repo/summaries/implementation-summary-20260224.md`

### ProofChecker vs nvim Differences

| Aspect | ProofChecker | nvim |
|--------|-------------|------|
| Primary language | Lean 4 | Meta/Neovim |
| MCP tools | lean-lsp-mcp | None |
| Model preference | Opus for Lean | Sonnet for all |
| Blocked tools | lean_diagnostic_messages, lean_file_outline | None |
| Domain flags | --lean, --logic, --math, --latex, --typst | None (extension-based) |

### Flag Parsing Pattern (from ProofChecker)

```markdown
### STAGE 1.5: PARSE FLAGS

1. **Extract Team Options**
   Check remaining args for team flags:
   - `--team` -> `team_mode = true`
   - `--team-size N` -> `team_size = N` (clamp 2-4)

   If no team flag: `team_mode = false`, `team_size = 2`

2. **Extract Domain Override** (if applicable)
   Check for domain flags: `--lean`, `--logic`, etc.

3. **Extract Focus Prompt**
   Remove all recognized flags from remaining args.
   Remaining text is `focus_prompt`.
```

## Next Steps

Run `/plan 218` to create the implementation plan.
