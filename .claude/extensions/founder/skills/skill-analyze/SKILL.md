---
name: skill-analyze
description: Competitive landscape analysis with positioning maps
allowed-tools: Task
---

# Analyze Skill

Thin wrapper that routes competitive analysis requests to the `analyze-agent`.

## Context Pointers

Reference (do not load eagerly):
- Path: `.claude/context/core/formats/subagent-return.md`
- Purpose: Return validation
- Load at: Subagent execution only

Note: This skill is a thin wrapper. Context is loaded by the delegated agent, not this skill.

## Trigger Conditions

This skill activates when:

### Direct Invocation
- User explicitly runs `/analyze` command
- User requests competitive analysis in conversation

### Implicit Invocation (during task implementation)

When an implementing agent encounters any of these patterns:

**Plan step language patterns**:
- "Analyze competitors"
- "Competitive landscape"
- "Map the competition"
- "Positioning analysis"

**Target mentions**:
- "competitive analysis"
- "competitor profiles"
- "positioning map"
- "battle cards"
- "competitive intelligence"

### When NOT to trigger

Do not invoke for:
- Market sizing (use skill-market)
- GTM strategy (use skill-strategy)
- General business research (use skill-researcher)
- Product feature comparison (not strategic competitive analysis)

---

## Execution

### 1. Input Validation

Validate inputs:
- `competitors` - Optional, comma-separated string or array
- `mode` - Optional, one of: LANDSCAPE, DEEP, POSITION, BATTLE
- `session_id` - Required, string

```bash
# Validate session_id is present
if [ -z "$session_id" ]; then
  return error "session_id is required"
fi

# Validate mode if provided
if [ -n "$mode" ]; then
  case "$mode" in
    LANDSCAPE|DEEP|POSITION|BATTLE) ;;
    *) return error "Invalid mode: $mode. Must be LANDSCAPE, DEEP, POSITION, or BATTLE" ;;
  esac
fi
```

### 2. Context Preparation

Prepare delegation context:

```json
{
  "competitors": ["optional", "competitor", "list"],
  "mode": "LANDSCAPE|DEEP|POSITION|BATTLE or null",
  "output_dir": "founder/",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "analyze", "skill-analyze"]
  }
}
```

### 3. Invoke Agent

**CRITICAL**: You MUST use the **Task** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "analyze-agent"
  - prompt: [Include competitors, mode, output_dir, metadata]
  - description: "Competitive analysis with positioning maps"
```

The agent will:
- Present mode selection if not pre-selected
- Identify and categorize competitors
- Use forcing questions for per-competitor analysis
- Generate positioning map
- Create battle cards (BATTLE mode)
- Return standardized JSON result

### 4. Return Validation

Validate return matches `subagent-return.md` schema:
- Status is one of: generated, partial, failed
- Summary is non-empty and <100 tokens
- Artifacts array present with output file path
- Metadata contains mode and competitor count

### 5. Return Propagation

Return validated result to caller without modification.

---

## Return Format

Expected successful return:
```json
{
  "status": "generated",
  "summary": "Generated competitive analysis covering 5 competitors in payments space. Key differentiation: API-first approach vs legacy integrations.",
  "artifacts": [
    {
      "type": "implementation",
      "path": "/absolute/path/to/founder/competitive-analysis-20260318.md",
      "summary": "Competitive analysis with positioning map and battle cards"
    }
  ],
  "metadata": {
    "session_id": "sess_...",
    "agent_type": "analyze-agent",
    "delegation_depth": 2,
    "mode": "POSITION",
    "competitors_analyzed": 5,
    "positioning_axes": ["enterprise_vs_smb", "api_first_vs_integrated"]
  },
  "next_steps": "Use battle cards in sales calls. Consider /strategy for GTM planning."
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
