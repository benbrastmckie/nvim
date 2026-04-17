# Research Report: Task #446

- **Task**: 446 - Add memory candidate emission to agents and return metadata
- **Started**: 2026-04-16T19:06:00Z
- **Completed**: 2026-04-16T19:12:00Z
- **Effort**: medium
- **Dependencies**: Task #445 (two-phase auto-retrieval, completed)
- **Sources/Inputs**:
  - Codebase: return-metadata-file.md, 3 agent definitions, 2 skill postflight files, skill-todo, state.json schema, memory system files
  - Context: context-layers.md, memory-index.json, memory-retrieve.sh, memory template
- **Artifacts**: specs/446_add_memory_candidate_emission_agents_return_metadata/reports/01_memory-emission-research.md
- **Standards**: report-format.md, status-markers.md, artifact-management.md

## Executive Summary

- The return metadata schema (`.return-meta.json`) currently has no field for memory candidates; adding a top-level `memory_candidates` array is straightforward and non-breaking
- All three agent definitions (general-research-agent, general-implementation-agent, planner-agent) follow a consistent stage-based execution flow with metadata writing at the end, making emission insertion predictable
- Skill postflight in both skill-researcher and skill-implementer already reads `.return-meta.json` via jq and propagates fields to state.json; adding `memory_candidates` propagation follows the existing `completion_data` pattern
- The `/todo` skill (Stage 7: HarvestMemories) already scans artifacts for memory candidates -- task 447 will upgrade it to consume structured candidates from state.json instead
- The memory-index.json schema and MEM-*.md template provide the target format that candidates must align with

## Context & Scope

This task extends the agent-to-skill data pipeline to include structured memory candidates. Currently agents produce research reports, implementation summaries, and completion_data. This task adds a new data channel: agents emit 0-3 structured memory candidates as part of their normal metadata output. No memory files are written -- candidates are stored as data for later `/todo` processing (task 447).

**Scope boundaries**:
- IN: Schema extension, agent emission logic, skill propagation to state.json
- OUT: Memory file creation, `/todo` consumption (task 447), `/distill` operations (task 449+)

## Findings

### Current Return Metadata Schema

The `.return-meta.json` schema (`.claude/context/formats/return-metadata-file.md`) has these top-level fields:

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `status` | enum | Yes | researched, planned, implemented, partial, failed, blocked, in_progress |
| `artifacts` | array | Yes | Report/plan/summary paths |
| `next_steps` | string | No | Guidance for next action |
| `metadata` | object | Yes | session_id, agent_type, delegation info |
| `errors` | array | No | Error objects when partial/failed |
| `started_at` | string | No | ISO8601 for in_progress |
| `partial_progress` | object | No | Resume tracking |
| `completion_data` | object | No | completion_summary, roadmap_items, claudemd_suggestions |

The `memory_candidates` array fits naturally as a new optional top-level field, parallel to `completion_data`. It should NOT be nested inside `completion_data` because:
1. Research and plan agents write `memory_candidates` but not `completion_data` (only implementation agents produce `completion_data`)
2. Memory candidates are relevant at all agent return statuses (researched, planned, implemented), not just "implemented"

### Agent Emission Points

Each agent has a clear insertion point for memory candidate generation:

**general-research-agent.md** (Stage 4 -> Stage 5):
- Between "Synthesize Findings" (Stage 4) and "Create Research Report" (Stage 5)
- Emit candidates based on novel findings: unexpected patterns, reusable configurations, workflow insights
- Cap at 0-3 candidates (research typically discovers the most memory-worthy content)

**general-implementation-agent.md** (Stage 6 -> Stage 7):
- Between "Create Implementation Summary" (Stage 6) and "Write Metadata File" (Stage 7)
- Emit candidates for reusable patterns discovered during implementation, configuration insights, debugging techniques
- Cap at 0-3 candidates

**planner-agent.md** (Stage 5 -> Stage 6):
- Between "Create Plan File" (Stage 5) and "Verify Plan and Write Metadata File" (Stage 6)
- Emit candidates only when planning reveals architectural patterns or dependency insights
- Cap at 0-1 candidates (planning rarely generates novel knowledge)

### Skill Postflight Propagation

Both skill-researcher and skill-implementer read `.return-meta.json` via jq in their Stage 6 (Parse Subagent Return). The existing pattern for `completion_data` in skill-implementer shows exactly how to propagate:

```bash
# Existing pattern (skill-implementer Stage 6):
completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")
claudemd_suggestions=$(jq -r '.completion_data.claudemd_suggestions // ""' "$metadata_file")
roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")
```

For memory_candidates:
```bash
# New extraction (both skills):
memory_candidates=$(jq -c '.memory_candidates // []' "$metadata_file")
```

Propagation to state.json follows the existing pattern (skill-implementer Stage 7, Step 3):
```bash
if [ "$memory_candidates" != "[]" ] && [ -n "$memory_candidates" ]; then
    jq --argjson candidates "$memory_candidates" \
      '(.active_projects[] | select(.project_number == '$task_number')).memory_candidates = $candidates' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

### State.json Integration

The `memory_candidates` field belongs on the task entry in `active_projects[]`, similar to `completion_summary` and `roadmap_items`. It accumulates across operations: research may add candidates, then implementation may add more. The `/todo` command (task 447) will consume all accumulated candidates when archiving.

**Accumulation strategy**: Each skill postflight should APPEND to existing candidates rather than overwrite. This allows research + implementation candidates to coexist:

```bash
# Append pattern (avoids overwriting research candidates when implementation runs):
jq --argjson new_candidates "$memory_candidates" \
  '(.active_projects[] | select(.project_number == '$task_number')).memory_candidates =
    ((.active_projects[] | select(.project_number == '$task_number')).memory_candidates // []) + $new_candidates' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

### Memory Candidate Schema

Based on the task description and alignment with the existing memory-index.json entry schema:

```json
{
  "content": "string, max ~300 tokens, the memory text",
  "category": "TECHNIQUE|PATTERN|CONFIG|WORKFLOW|INSIGHT",
  "source_artifact": "specs/NNN_slug/reports/01_slug.md",
  "confidence": 0.0-1.0,
  "suggested_keywords": ["keyword1", "keyword2"]
}
```

The `confidence` field enables the three-tier pre-classification in task 447:
- Tier 1 (pre-selected): PATTERN or CONFIG with confidence >= 0.8
- Tier 2 (presented, not pre-selected): WORKFLOW or TECHNIQUE with confidence >= 0.5
- Tier 3 (omitted): confidence < 0.5

### Existing Memory Pipeline

The current memory pipeline:
1. **Creation**: `/learn` command creates MEM-*.md files manually
2. **Retrieval**: `memory-retrieve.sh` scores memory-index.json entries by keyword overlap, injects into delegation context
3. **Harvest**: `/todo` Stage 7 scans artifacts for memory-worthy content (currently text scanning, task 447 will upgrade to structured candidates)
4. **Maintenance**: `/distill` command (task 449) manages scoring, health, and cleanup

This task fills the gap between agent work and `/todo` harvest by providing structured candidates instead of requiring `/todo` to scan free-form artifacts.

### Files to Modify (6 files)

1. `.claude/context/formats/return-metadata-file.md` -- Add `memory_candidates` array to schema, field specifications, and examples
2. `.claude/agents/general-research-agent.md` -- Add emission stage between Stage 4 (Synthesize) and Stage 5 (Create Report)
3. `.claude/agents/general-implementation-agent.md` -- Add emission stage between Stage 6 (Create Summary) and Stage 7 (Write Metadata)
4. `.claude/agents/planner-agent.md` -- Add emission stage between Stage 5 (Create Plan) and Stage 6 (Verify + Write Metadata)
5. `.claude/skills/skill-researcher/SKILL.md` -- Add extraction in Stage 6 and propagation in new step after Stage 7
6. `.claude/skills/skill-implementer/SKILL.md` -- Add extraction in Stage 6 and propagation in new step after Stage 7

### State Schema Addition

The state-management-schema.md should document `memory_candidates` as an optional task field:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `memory_candidates` | array | No | Structured memory candidates from agents, accumulated across operations |

## Decisions

- **Top-level field, not nested in completion_data**: Memory candidates are emitted by all agent types, not just implementation agents. Putting them at the `.return-meta.json` root level (alongside `completion_data`, `errors`, etc.) is cleaner.
- **Append semantics in state.json**: Research and implementation both contribute candidates. Skills should append, not overwrite, so candidates accumulate across the task lifecycle.
- **Confidence field included**: Even though this task does not implement consumption logic, including `confidence` in the schema enables the three-tier classification in task 447 without a schema change.
- **Agent instructions are guidance, not enforcement**: Agents are instructed to emit 0-3 candidates. Since these are LLM-generated, the cap is advisory. No validation needed in the schema itself.
- **No skill-planner propagation needed**: The planner agent writes metadata, but skill-planner's postflight does not propagate to state.json task entries the same way. Since planner candidates are rare (0-1), and the plan status is "planned" (not a terminal state), plan candidates can be omitted from skill-planner propagation. The implementation agent can re-discover the same insights. This keeps the change set minimal.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agents emit low-quality candidates | Low | Medium | Confidence field + task 447 filtering provides quality gate |
| State.json grows with unused candidates | Low | Low | `/todo` consumes and removes candidates during archival |
| jq escaping issues (Issue #1132) | Medium | Low | Use standard patterns from jq-escaping-workarounds.md; no `!=` needed |
| Agents forget to emit candidates | Low | Medium | Emission is optional (0-3); absence is valid |
| Schema change breaks existing metadata parsing | Low | Very Low | Field is optional with `// []` fallback in all jq reads |

## Context Extension Recommendations

This is a meta task -- no context extension recommendations apply.

## Appendix

### Files Read During Research

- `.claude/context/formats/return-metadata-file.md` (309 lines) - Current schema
- `.claude/agents/general-research-agent.md` (239 lines) - Research agent stages
- `.claude/agents/general-implementation-agent.md` (247 lines) - Implementation agent stages
- `.claude/agents/planner-agent.md` (305 lines) - Planner agent stages
- `.claude/skills/skill-researcher/SKILL.md` (431 lines) - Research skill with postflight
- `.claude/skills/skill-implementer/SKILL.md` (508 lines) - Implementation skill with postflight
- `.claude/skills/skill-todo/SKILL.md` (679 lines) - Todo skill with HarvestMemories stage
- `.claude/context/formats/report-format.md` (89 lines) - Report format standard
- `.claude/rules/state-management.md` (80 lines) - State management rules
- `.claude/context/reference/state-management-schema.md` (400 lines) - Full state schema
- `.claude/context/architecture/context-layers.md` (55 lines) - Context layer boundaries
- `.claude/scripts/memory-retrieve.sh` (165 lines) - Auto-retrieval script
- `.memory/memory-index.json` (28 lines) - Current index schema
- `.memory/30-Templates/memory-template.md` (20 lines) - Memory entry template
- `.memory/README.md` (107 lines) - Memory vault documentation
- `specs/state.json` (293 lines) - Current state with memory system tasks
- `specs/TODO.md` (task 446-448 descriptions) - Task requirements
