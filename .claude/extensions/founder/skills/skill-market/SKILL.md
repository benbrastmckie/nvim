---
name: skill-market
description: Market sizing analysis with TAM/SAM/SOM framework
allowed-tools: Task
---

# Market Skill

Thin wrapper that routes market sizing requests to the `market-agent`.

## Context Pointers

Reference (do not load eagerly):
- Path: `.claude/context/core/formats/subagent-return.md`
- Purpose: Return validation
- Load at: Subagent execution only

Note: This skill is a thin wrapper. Context is loaded by the delegated agent, not this skill.

## Trigger Conditions

This skill activates when:

### Direct Invocation
- User explicitly runs `/market` command
- User requests market sizing in conversation

### Implicit Invocation (during task implementation)

When an implementing agent encounters any of these patterns:

**Plan step language patterns**:
- "Analyze market size"
- "Calculate TAM/SAM/SOM"
- "Market sizing analysis"
- "Estimate addressable market"

**Target mentions**:
- "TAM", "SAM", "SOM"
- "total addressable market"
- "market opportunity"
- "market sizing"

### When NOT to trigger

Do not invoke for:
- Competitive analysis (use skill-analyze)
- GTM strategy (use skill-strategy)
- General business research (use skill-researcher)
- Revenue projections (not market sizing)

---

## Execution

### 1. Input Validation

Validate inputs:
- `industry` - Optional, string
- `segment` - Optional, string
- `mode` - Optional, one of: VALIDATE, SIZE, SEGMENT, DEFEND
- `session_id` - Required, string

```bash
# Validate session_id is present
if [ -z "$session_id" ]; then
  return error "session_id is required"
fi

# Validate mode if provided
if [ -n "$mode" ]; then
  case "$mode" in
    VALIDATE|SIZE|SEGMENT|DEFEND) ;;
    *) return error "Invalid mode: $mode. Must be VALIDATE, SIZE, SEGMENT, or DEFEND" ;;
  esac
fi
```

### 2. Context Preparation

Prepare delegation context:

```json
{
  "industry": "optional industry hint",
  "segment": "optional segment hint",
  "mode": "VALIDATE|SIZE|SEGMENT|DEFEND or null",
  "output_dir": "founder/",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "market", "skill-market"]
  }
}
```

### 3. Invoke Agent

**CRITICAL**: You MUST use the **Task** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "market-agent"
  - prompt: [Include industry, segment, mode, output_dir, metadata]
  - description: "Market sizing analysis with TAM/SAM/SOM"
```

The agent will:
- Present mode selection if not pre-selected
- Use forcing questions to gather market data
- Calculate TAM/SAM/SOM using appropriate methodology
- Generate market sizing artifact
- Return standardized JSON result

### 4. Return Validation

Validate return matches `subagent-return.md` schema:
- Status is one of: generated, partial, failed
- Summary is non-empty and <100 tokens
- Artifacts array present with output file path
- Metadata contains mode and methodology used

### 5. Return Propagation

Return validated result to caller without modification.

---

## Return Format

Expected successful return:
```json
{
  "status": "generated",
  "summary": "Generated TAM/SAM/SOM analysis for fintech payments segment. TAM: $50B, SAM: $8B, SOM Y1: $40M.",
  "artifacts": [
    {
      "type": "implementation",
      "path": "/absolute/path/to/founder/market-sizing-20260318.md",
      "summary": "Market sizing analysis with bottom-up methodology"
    }
  ],
  "metadata": {
    "session_id": "sess_...",
    "agent_type": "market-agent",
    "delegation_depth": 2,
    "mode": "SIZE",
    "methodology": "bottom_up",
    "questions_asked": 6,
    "data_sources": 4
  },
  "next_steps": "Review assumptions and validate data sources. Consider running /analyze for competitive context."
}
```

---

## Error Handling

### Session ID Missing
Return immediately with failed status.

### Agent Errors
Pass through the agent's error return verbatim.

### User Abandonment
Return partial status with progress made.
