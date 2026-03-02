# Lean Research Execution Flow

Reference: Load when executing lean-research-agent after Stage 0.

## Prerequisites

- Early metadata initialized (Stage 0 complete)
- Task context parsed from delegation

---

## Stage 1: Parse Delegation Context

Extract from input:
```json
{
  "task_context": {
    "task_number": 123,
    "task_name": "prove_theorem",
    "description": "...",
    "language": "lean"
  },
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "lean-research-agent"]
  },
  "focus_prompt": "optional specific focus area",
  "metadata_file_path": "specs/123_theorem/.return-meta.json"
}
```

---

## Stage 2: Analyze Task and Determine Search Strategy

Based on task description and focus:

1. **Theorem Discovery**: Need natural language -> use leansearch
2. **Type Matching**: Have specific type signature -> use loogle
3. **Conceptual Search**: Looking for mathematical concept -> use leanfinder
4. **Goal-Directed**: Have specific proof goal -> use state_search
5. **Local Verification**: Check what exists in project -> use local_search

---

## Stage 3: Execute Primary Searches

Execute searches based on strategy:

1. **Always Start**: `lean_local_search` for relevant terms (no rate limit)
2. **Primary Search**: Based on query type
3. **Verification**: `lean_hover_info` on promising candidates
4. **Alternative Searches**: If primary yields few results

### Rate Limits Reference

| Tool | Limit |
|------|-------|
| `lean_local_search` | No limit |
| `lean_leanfinder` | 10 req/30s |
| `lean_leansearch` | 3 req/30s |
| `lean_loogle` | 3 req/30s |
| `lean_state_search` | 3 req/30s |
| `lean_hammer_premise` | 3 req/30s |

---

## Stage 4: Synthesize Findings

Compile discovered information:
- Relevant theorems/lemmas with type signatures
- Documentation excerpts
- Usage patterns from existing code
- Potential proof strategies

---

## Stage 5: Create Research Report

Create directory and write report.

**Path**: `specs/{N}_{SLUG}/reports/research-{NNN}.md`

**Structure**:
```markdown
# Research Report: Task #{N}

**Task**: {id} - {title}
**Started**: {ISO8601}
**Completed**: {ISO8601}
**Sources/Inputs**: Mathlib, lean_leansearch, lean_loogle, etc.

## Executive Summary
- Key finding 1
- Key finding 2
- Recommended approach

## Context & Scope
{What was researched, constraints}

## Findings
### Relevant Theorems
- `Theorem.name` : {type signature}
  - {description, usage}

### Proof Strategies
- {Recommended approaches}

### Dependencies
- {Required imports, lemmas}

## Recommendations
1. {Prioritized recommendations}

## Risks & Mitigations
- {Potential issues and solutions}
```

---

## Stage 6: Write Metadata File

Write to `specs/{N}_{SLUG}/.return-meta.json`:

```json
{
  "status": "researched",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/{N}_{SLUG}/reports/research-{NNN}.md",
      "summary": "Research report with theorem findings"
    }
  ],
  "next_steps": "Run /plan {N} to create implementation plan",
  "metadata": {
    "session_id": "...",
    "agent_type": "lean-research-agent",
    "findings_count": 5
  }
}
```

---

## Stage 7: Return Brief Text Summary

Return 3-6 bullet points (NOT JSON).

---

## Error Handling

### Rate Limit Handling

When a search tool rate limit is hit:
1. Switch to alternative tool (leansearch <-> loogle <-> leanfinder)
2. Use lean_local_search (no limit) for verification
3. Continue with partial results

### No Results Found

1. Try broader/alternative search terms
2. Search for related concepts
3. Write `partial` status with recommendations

---

## Search Fallback Chain

```
Primary: leansearch (natural language)
    | no results
    v
Fallback 1: loogle (type pattern)
    | no results
    v
Fallback 2: leanfinder (semantic)
    | no results
    v
Fallback 3: local_search (broader terms)
    | no results
    v
Write partial status with recommendations
```
