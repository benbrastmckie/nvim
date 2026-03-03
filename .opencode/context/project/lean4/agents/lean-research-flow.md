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
    "task_number": "OC_259",
    "task_name": "prove_completeness_theorem",
    "description": "...",
    "language": "lean"
  },
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "lean-research-agent"]
  },
  "focus_prompt": "optional specific focus area",
  "metadata_file_path": "specs/OC_259_prove_completeness/.return-meta.json"
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
2. **Primary Search**: Based on query type (see Search Decision Tree in agent)
3. **Verification**: `lean_hover_info` on promising candidates
4. **Alternative Searches**: If primary yields few results, try other tools

### Rate Limit Management

- Track request counts per tool
- Space out rate-limited calls
- Prefer lean_leanfinder (10/30s) over leansearch/loogle (3/30s) when both work
- Use lean_local_search freely (no limit)

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

**Path**: `specs/OC_NNN_{SLUG}/reports/research-NNN.md`

**Structure** (from report-format.md):
```markdown
# Research Report: Task OC_{N}

**Task**: OC_{N} - {title}
**Started**: {ISO8601}
**Completed**: {ISO8601}
**Effort**: {estimate}
**Dependencies**: {list or None}
**Sources/Inputs**: - Mathlib, lean_leansearch, lean_loogle, etc.
**Artifacts**: - path to this report
**Standards**: report-format.md, subagent-return.md

## Project Context
- **Upstream Dependencies**: {Existing theorems/definitions this builds upon, e.g., "Soundness, Kripke.eval, Formula.subst"}
- **Downstream Dependents**: {Results that will use this, e.g., "Completeness, DecidabilityTheorem"}
- **Alternative Paths**: {Redundancy or different approaches, or "None identified"}
- **Potential Extensions**: {New directions this enables, e.g., "Multi-modal logics, temporal operators"}

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

## Decisions
- {Explicit decisions made during research}

## Recommendations
1. {Prioritized recommendations}

## Risks & Mitigations
- {Potential issues and solutions}

## Appendix: Context Knowledge Candidates
{See Stage 5.5 for format - include only if candidates exist}
```

---

## Stage 5.5: Context Knowledge Extraction (Optional)

After creating the report, evaluate findings for potential context file additions following `context-knowledge-template.md`.

**Purpose**: Identify domain-general Lean/Mathlib knowledge that may benefit future tasks.

**Include Candidates If**:
- Standard Mathlib patterns or idioms discovered
- Proof techniques applicable beyond this specific theorem
- Type class hierarchies or patterns worth documenting
- Tactic combinations that work well for certain problem types
- NOT task-specific lemmas or project-specific constructions

**Format in Report Appendix** (if candidates exist):
```markdown
## Appendix: Context Knowledge Candidates

### Candidate 1: {Brief Title}
**Type**: Pattern | Technique | Tactic | TypeClass
**Domain**: lean4-tactics | mathlib-patterns | proof-strategies
**Target Context**: {e.g., .opencode/context/project/lean4/patterns/}
**Content**: {The actual knowledge}
**Source**: {Mathlib module or documentation}
**Rationale**: {Why generally useful}
```

**Track in Metadata**: Set `context_candidates_count` to number of candidates (0 if none).

---

## Stage 6: Write Metadata File

**CRITICAL**: Write metadata to the specified file path, NOT to console.

Write to `specs/OC_NNN_{SLUG}/.return-meta.json`:

```json
{
  "status": "researched",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/OC_NNN_{SLUG}/reports/research-NNN.md",
      "summary": "Research report with {count} theorem findings and proof strategy"
    }
  ],
  "next_steps": "Run /plan OC_{N} to create implementation plan",
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "lean-research-agent",
    "duration_seconds": 123,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "lean-research-agent"],
    "findings_count": 5,
    "context_candidates_count": 0
  }
}
```

Use the Write tool to create this file.

---

## Stage 7: Return Brief Text Summary

**CRITICAL**: Return a brief text summary (3-6 bullet points), NOT JSON.

Example return:
```
Research completed for task OC_259:
- Found 5 relevant Mathlib theorems including Nat.add_comm and List.length_append
- Identified proof strategy using structural induction
- Created report at specs/OC_259_prove_completeness/reports/research-001.md
- Metadata written to specs/OC_259_prove_completeness/.return-meta.json
```

**DO NOT return JSON to the console**. The skill reads metadata from the file.

---

## Error Handling

### MCP Tool Error Recovery

When MCP tool calls fail (AbortError -32001 or similar):

1. **Log the error context** (tool name, operation, task number, session_id)
2. **Retry once** after 5-second delay for timeout errors
3. **Try alternative search tool** per this fallback table:

| Primary Tool | Alternative 1 | Alternative 2 |
|--------------|---------------|---------------|
| `lean_leansearch` | `lean_loogle` | `lean_leanfinder` |
| `lean_loogle` | `lean_leansearch` | `lean_leanfinder` |
| `lean_leanfinder` | `lean_leansearch` | `lean_loogle` |
| `lean_local_search` | (no alternative) | Continue with partial |

4. **If all fail**: Continue with codebase-only findings
5. **Update metadata** with partial_progress:
   ```json
   {
     "status": "in_progress",
     "partial_progress": {
       "stage": "mcp_recovery",
       "details": "MCP tool {tool_name} failed. Continuing with available data."
     }
   }
   ```
6. **Document in report** what searches failed and recommendations

See `.opencode/context/core/patterns/mcp-tool-recovery.md` for detailed recovery patterns.

### Rate Limit Handling

When a search tool rate limit is hit:
1. Switch to alternative tool (leansearch <-> loogle <-> leanfinder)
2. Use lean_local_search (no limit) for verification
3. If all limited, wait briefly and continue with partial results

### No Results Found

If searches yield no useful results:
1. Try broader/alternative search terms
2. Search for related concepts
3. Write `partial` status to metadata file with:
   - What was searched
   - Recommendations for alternative queries
   - Suggestion to manually search Mathlib docs

### Timeout/Interruption

If time runs out before completion:
1. Save partial findings to report file
2. Write `partial` status to metadata file with:
   - Completed sections noted
   - Resume point information
   - Partial artifact path

### Invalid Task

If task number doesn't exist or status is wrong:
1. Write `failed` status to metadata file
2. Include clear error message
3. Return brief error summary

---

## Search Fallback Chain

When primary search fails, try this chain:

```
Primary: leansearch (natural language)
    | no results
    v
Fallback 1: loogle (type pattern extracted from description)
    | no results
    v
Fallback 2: leanfinder (semantic/conceptual)
    | no results
    v
Fallback 3: local_search with broader terms
    | no results
    v
Write partial status with recommendations
```

---

## Partial Result Guidelines

Results are considered **partial** if:
- Found some but not all expected theorems
- Rate limits prevented complete search
- Timeout occurred before synthesis
- Some searches failed but others succeeded

Partial results should include:
- All findings discovered so far
- Clear indication of what's missing
- Recovery recommendations

---

## Return Format Examples

### Successful Research (Text Summary)

```
Research completed for task OC_259:
- Found 5 relevant Mathlib theorems for completeness proof
- Key theorems: Nat.add_comm, List.length_append, Set.mem_union
- Identified proof strategy using structural induction with these lemmas
- Created report at specs/OC_259_prove_completeness/reports/research-001.md
- Metadata written for skill postflight
```

### Partial Research (Text Summary)

```
Research partially completed for task OC_259:
- Found 2 relevant theorems via local_search
- leansearch rate limit prevented comprehensive Mathlib search
- Partial report saved at specs/OC_259_prove_completeness/reports/research-001.md
- Metadata written with partial status
- Recommend: retry after 30 seconds or use alternative search terms
```

### Failed Research (Text Summary)

```
Research failed for task OC_259:
- Task not found in state.json
- No artifacts created
- Metadata written with failed status
- Recommend: verify task number with /task --sync
```
