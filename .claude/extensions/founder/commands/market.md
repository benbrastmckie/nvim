---
description: Analyze market size using TAM/SAM/SOM framework with forcing questions
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read
argument-hint: "[industry] [segment]" | --mode VALIDATE|SIZE|SEGMENT|DEFEND
---

# /market Command

Market sizing analysis command using TAM/SAM/SOM framework with forcing questions pattern.

## Overview

This command produces market sizing analysis artifacts through structured questioning. It uses forcing questions to extract specific, evidence-based market data and produces investor-ready market sizing documents.

## Syntax

- `/market` - Start market sizing with interactive mode selection
- `/market fintech payments` - Start with industry/segment hints
- `/market --mode VALIDATE` - Skip mode selection, use VALIDATE mode

## Modes

| Mode | Posture | Focus |
|------|---------|-------|
| **VALIDATE** | Test assumptions | Evidence gathering, bottom-up sizing |
| **SIZE** | Comprehensive | All three tiers with methodology |
| **SEGMENT** | Deep dive | Specific segment breakdown |
| **DEFEND** | Investor-ready | Credibility, data sources, conservative estimates |

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Market] TAM/SAM/SOM Market Sizing Analysis
```

### Step 1: Generate Session ID

```bash
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

### Step 2: Parse Arguments

Parse $ARGUMENTS to extract:
- `industry`: Optional industry hint (e.g., "fintech", "healthcare")
- `segment`: Optional segment hint (e.g., "payments", "SMB")
- `--mode`: Optional mode selection (VALIDATE, SIZE, SEGMENT, DEFEND)

If no `--mode` flag, mode selection happens during execution.

### Step 3: Prepare Delegation Context

```json
{
  "industry": "optional industry hint",
  "segment": "optional segment hint",
  "mode": "VALIDATE|SIZE|SEGMENT|DEFEND or null for interactive",
  "output_dir": "founder/",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "market", "skill-market"]
  }
}
```

---

## STAGE 2: DELEGATE

**Invoke Skill tool**:

```
skill: "skill-market"
args: "industry={industry} segment={segment} mode={mode} session_id={session_id}"
```

The skill will:
1. Present mode selection (if not pre-selected)
2. Use forcing questions to gather market data
3. Calculate TAM/SAM/SOM using appropriate methodology
4. Generate market sizing artifact
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
Market sizing analysis generated.

Mode: {MODE}
Artifact: founder/market-sizing-{datetime}.md

Summary:
{summary}

Key Numbers:
- TAM: ${TAM}
- SAM: ${SAM}
- SOM: ${SOM}

Next: Review artifact and validate assumptions
```

**On partial**:
```
Market sizing analysis partially completed.

{partial_progress}

Resume: /market --mode {mode}
```

**On failure**:
```
Market sizing analysis failed.

Error: {error_message}
Recovery: {recovery_guidance}
```

---

## Error Handling

### No Industry/Segment Provided

Not an error - agent will ask interactively.

### User Abandons Forcing Questions

Return partial status with progress made:
```json
{
  "status": "partial",
  "partial_progress": {
    "questions_completed": 3,
    "questions_total": 6,
    "data_gathered": ["TAM approach", "industry size"]
  }
}
```

### Invalid Mode

```
Invalid mode: {provided}
Valid modes: VALIDATE, SIZE, SEGMENT, DEFEND
```

---

## Output Artifacts

| Artifact | Location |
|----------|----------|
| Market sizing analysis | `founder/market-sizing-{datetime}.md` |

Artifact follows template at `@context/project/founder/templates/market-sizing.md`.
