---
description: Competitive landscape analysis with positioning maps and battle cards
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read
argument-hint: "[competitor1,competitor2,...]" | --mode LANDSCAPE|DEEP|POSITION|BATTLE
---

# /analyze Command

Competitive analysis command that maps the competitive landscape, generates positioning maps, and produces battle cards for sales enablement.

## Overview

This command produces competitive analysis artifacts through structured analysis. It uses forcing questions to extract specific competitive intelligence and produces actionable competitive strategy documents.

## Syntax

- `/analyze` - Start competitive analysis with interactive mode selection
- `/analyze stripe,square,adyen` - Analyze specific competitors
- `/analyze --mode BATTLE` - Skip mode selection, use BATTLE mode

## Modes

| Mode | Posture | Focus |
|------|---------|-------|
| **LANDSCAPE** | Map the field | All competitors, categories |
| **DEEP** | Focus on key rivals | Top 3-5 detailed analysis |
| **POSITION** | Find white space | 2x2 maps, differentiation |
| **BATTLE** | Prepare for competition | Battle cards, objection handling |

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Analyze] Competitive Landscape Analysis
```

### Step 1: Generate Session ID

```bash
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

### Step 2: Parse Arguments

Parse $ARGUMENTS to extract:
- `competitors`: Optional comma-separated competitor names
- `--mode`: Optional mode selection (LANDSCAPE, DEEP, POSITION, BATTLE)

If no `--mode` flag, mode selection happens during execution.

### Step 3: Prepare Delegation Context

```json
{
  "competitors": ["optional", "competitor", "list"],
  "mode": "LANDSCAPE|DEEP|POSITION|BATTLE or null for interactive",
  "output_dir": "founder/",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "analyze", "skill-analyze"]
  }
}
```

---

## STAGE 2: DELEGATE

**Invoke Skill tool**:

```
skill: "skill-analyze"
args: "competitors={competitors} mode={mode} session_id={session_id}"
```

The skill will:
1. Present mode selection (if not pre-selected)
2. Use forcing questions to gather competitive intelligence
3. Generate positioning map
4. Create battle cards (if BATTLE mode)
5. Return structured JSON result

---

## CHECKPOINT 2: GATE OUT

### Step 1: Validate Return

Check return from skill:
- Status is one of: generated, partial, failed
- Summary is non-empty and <100 tokens
- Artifacts array present with output file path

### Step 2: Display Result

**On success**:
```
Competitive analysis generated.

Mode: {MODE}
Artifact: founder/competitive-analysis-{datetime}.md

Summary:
{summary}

Competitors Analyzed:
- {competitor1}: {positioning}
- {competitor2}: {positioning}
- {competitor3}: {positioning}

Positioning Insight: {key_insight}

Next: Review artifact and prepare for competitive situations
```

**On partial**:
```
Competitive analysis partially completed.

{partial_progress}

Resume: /analyze --mode {mode}
```

**On failure**:
```
Competitive analysis failed.

Error: {error_message}
Recovery: {recovery_guidance}
```

---

## Error Handling

### No Competitors Provided

Not an error - agent will ask interactively.

### User Abandons Analysis

Return partial status with progress made:
```json
{
  "status": "partial",
  "partial_progress": {
    "competitors_analyzed": 2,
    "competitors_total": 5,
    "sections_completed": ["landscape", "profiles"]
  }
}
```

### Invalid Mode

```
Invalid mode: {provided}
Valid modes: LANDSCAPE, DEEP, POSITION, BATTLE
```

---

## Output Artifacts

| Artifact | Location |
|----------|----------|
| Competitive analysis | `founder/competitive-analysis-{datetime}.md` |

Artifact follows template at `@context/project/founder/templates/competitive-analysis.md`.
