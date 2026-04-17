# Research Report: Fix Documentation Regressions from Agent System Update

- **Task**: 456 - Fix documentation regressions from agent system update
- **Started**: 2026-04-16T00:00:00Z
- **Completed**: 2026-04-16T00:05:00Z
- **Effort**: 15 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - `.claude/extensions/memory/skills/skill-memory/SKILL.md` (current state)
  - `.claude/context/formats/return-metadata-file.md` (current state)
  - `.claude/context/formats/plan-format.md` (current state)
  - `/home/benjamin/.config/zed/specs/071_fix_doc_regressions_agent_update/reports/01_doc-regression-review.md` (source report from sibling project)
- **Artifacts**: `specs/456_fix_doc_regressions_agent_system_update/reports/01_fix-doc-regressions.md`
- **Standards**: report-format.md, artifact-management.md, tasks.md

## Executive Summary

- All four regressions described in the task are confirmed present in the current files.
- Fix 1 (High): The CREATE template in SKILL.md is missing `retrieval_count`, `last_retrieved`, `keywords`, and `summary` fields, causing an inconsistency with the JSON Index Maintenance section in the same file.
- Fix 2 (Medium): return-metadata-file.md has only 3 JSON examples; the "Planning Success" and "Implementation Partial" examples were removed and need restoration.
- Fix 3 (Medium): plan-format.md compressed the `plan_metadata` schema to a single paragraph, losing the JSON example block that shows `dependency_waves` array-of-arrays shape.
- Fix 4 (Low): plan-format.md Dependency Analysis section lacks a note about sequential plans still requiring wave tables.

## Context & Scope

The sibling project (`~/.config/zed/`) underwent an agent system update that compressed several documentation files. This nvim project received the same updates. The source report (task 71 in the zed project) identified six findings; four are actionable fixes that apply to this project. The remaining two (Finding 5: cosmetic memory_health inconsistency, Finding 6: merged into Finding 4) require no action.

## Findings

### Finding 1: SKILL.md CREATE template missing retrieval tracking fields (High)

**File**: `.claude/extensions/memory/skills/skill-memory/SKILL.md`
**Location**: Lines 360-378 (Template for CREATE)

The CREATE template currently has these frontmatter fields:
```yaml
title, created, tags, topic, source, modified
```

But the JSON Index Maintenance section (lines 466-473 of the same file) extracts these additional fields from frontmatter:
```bash
retrieval_count=$(grep -m1 "^retrieval_count:" "$mem" ...)
last_retrieved=$(grep -m1 "^last_retrieved:" "$mem" ...)
keywords=$(grep -m1 "^keywords:" "$mem" ...)
summary=$(grep -m1 "^summary:" "$mem" ...)
```

**Required change**: Add four fields to the CREATE template frontmatter, between the `modified` line and the closing `---`:
```yaml
keywords: {segment.key_terms}
summary: "{segment.summary}"
retrieval_count: 0
last_retrieved:
```

The UPDATE template (lines 258-280) should also be checked, but it is less critical since UPDATE operations typically preserve existing frontmatter fields.

### Finding 2: return-metadata-file.md missing Planning Success and Implementation Partial examples (Medium)

**File**: `.claude/context/formats/return-metadata-file.md`
**Location**: After line 351 (after the paragraph about "For other scenarios...")

The file currently has these examples:
1. Research Success (line 264)
2. Implementation Success (Non-Meta) (line 289)
3. Early Metadata (In Progress) (line 329)

Missing examples that need restoration:

**Planning Success example** -- needed because planner agents write unique fields not used by other agents:
```json
{
  "status": "planned",
  "artifacts": [
    {
      "type": "plan",
      "path": "specs/001_setup_lsp_config/plans/01_lsp-config-plan.md",
      "summary": "Implementation plan with 4 phases and dependency analysis"
    }
  ],
  "next_steps": "Run /implement 1 to execute the plan",
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "planner-agent",
    "duration_seconds": 240,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "plan", "planner-agent"]
  }
}
```

**Implementation Partial example** -- needed because error recovery metadata has conditional fields:
```json
{
  "status": "partial",
  "artifacts": [
    {
      "type": "summary",
      "path": "specs/001_setup_lsp_config/summaries/01_lsp-config-summary.md",
      "summary": "Partial implementation summary with 2 of 4 phases completed"
    }
  ],
  "partial_progress": {
    "stage": "phase_2_completed",
    "details": "Phases 1-2 completed, phase 3 failed due to build error",
    "phases_completed": 2,
    "phases_total": 4
  },
  "errors": [
    {
      "type": "execution",
      "message": "Build failed: missing dependency in configuration",
      "recoverable": true,
      "recommendation": "Install dependency and run /implement 1 to resume from phase 3"
    }
  ],
  "metadata": {
    "session_id": "sess_1736700000_ghi789",
    "agent_type": "general-implementation-agent",
    "duration_seconds": 1800,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "implement", "general-implementation-agent"],
    "phases_completed": 2,
    "phases_total": 4
  }
}
```

### Finding 3: plan-format.md missing plan_metadata JSON example block (Medium)

**File**: `.claude/context/formats/plan-format.md`
**Location**: After line 29 (after the compressed `plan_metadata` paragraph)

The compressed paragraph on line 29 adequately lists field names and types, but the `dependency_waves` nested array-of-arrays shape (`[[1], [2, 3], [4, 5]]`) is not self-evident from text alone. An agent might produce `[1, [2, 3]]` or `{"wave_1": [1]}` without seeing a concrete example.

**Required change**: Add JSON example block after the paragraph:

```json
{
  "phases": 5,
  "total_effort_hours": 8,
  "complexity": "medium",
  "research_integrated": true,
  "plan_version": 1,
  "dependency_waves": [[1], [2, 3], [4, 5]],
  "reports_integrated": [
    {
      "path": "reports/01_{short-slug}.md",
      "integrated_in_plan_version": 1,
      "integrated_date": "2026-01-05"
    }
  ]
}
```

### Finding 4: plan-format.md Dependency Analysis missing sequential plan note (Low)

**File**: `.claude/context/formats/plan-format.md`
**Location**: Line 52, the Dependency Analysis description

Current text: "Place a **Dependency Analysis** wave table immediately after `## Implementation Phases` and before the first `### Phase`."

This lacks a note that sequential (non-parallel) plans still require a wave table where each wave contains exactly one phase. Without this note, agents may skip the wave table entirely for simple sequential plans.

**Required change**: Add to the end of the Dependency Analysis description paragraph (after "Generate from per-phase `Depends on` fields." on line 52): "For fully sequential plans, each wave contains one phase."

## Decisions

- Follow the source report's recommendations for all four fixes.
- The UPDATE template in SKILL.md is not included in scope since UPDATE operations preserve existing frontmatter; only CREATE is critical.
- Finding 5 from the source report (memory_health cosmetic inconsistency) is excluded -- the current architecture is correct.
- The exact JSON for restored examples follows the schema already documented in return-metadata-file.md.

## Recommendations

1. **Priority 1 (High)**: Add `keywords`, `summary`, `retrieval_count`, `last_retrieved` to the CREATE template in SKILL.md (4 lines added to frontmatter block)
2. **Priority 2 (Medium)**: Add "Planning Success" and "Implementation Partial" example sections to return-metadata-file.md (approximately 60 lines)
3. **Priority 3 (Medium)**: Add `plan_metadata` JSON example block after the compressed paragraph in plan-format.md (approximately 15 lines)
4. **Priority 4 (Low)**: Add sequential plan sentence to Dependency Analysis description in plan-format.md (1 sentence)

## Risks & Mitigations

- **Risk**: Restored examples may drift from the schema over time. **Mitigation**: The examples reference the same schema fields documented above them; any schema change should update examples in the same edit.
- **Risk**: Adding lines increases context budget usage. **Mitigation**: All additions are within reasonable bounds (approximately 80 lines total across 3 files).

## Appendix

- Source report: `/home/benjamin/.config/zed/specs/071_fix_doc_regressions_agent_update/reports/01_doc-regression-review.md`
- Affected files (3): `.claude/extensions/memory/skills/skill-memory/SKILL.md`, `.claude/context/formats/return-metadata-file.md`, `.claude/context/formats/plan-format.md`
