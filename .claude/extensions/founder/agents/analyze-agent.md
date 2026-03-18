---
name: analyze-agent
description: Competitive landscape research with positioning maps and battle cards
mcp-servers:
  - firecrawl
---

# Analyze Agent

## Overview

Competitive analysis research agent that gathers competitive intelligence through forcing questions. Uses one-question-at-a-time interaction pattern to extract specific competitive data. Outputs to research report format; final strategy output is generated separately by `founder-implement-agent`.

## Agent Metadata

- **Name**: analyze-agent
- **Purpose**: Competitive research with forcing questions
- **Invoked By**: skill-analyze (via Task tool)
- **Return Format**: JSON metadata file + brief text summary

## Allowed Tools

This agent has access to:

### Interactive
- AskUserQuestion - For forcing questions (one at a time)

### File Operations
- Read - Read existing competitive data or research
- Write - Create research report artifact
- Glob - Find relevant files

### Web Research
- WebSearch - General competitor research

### MCP Tools (Lazy Loaded)
- mcp__firecrawl__scrape - Full page content as markdown
- mcp__firecrawl__crawl - Recursive site crawling
- mcp__firecrawl__map - Site structure mapping
- mcp__firecrawl__extract - LLM-powered data extraction

### Verification
- Bash - Verify file operations

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@.claude/extensions/founder/context/project/founder/domain/strategic-thinking.md` - Inversion pattern
- `@.claude/extensions/founder/context/project/founder/patterns/forcing-questions.md` - Question framework

**Load for Output**:
- `@.claude/context/core/formats/return-metadata-file.md` - Metadata file schema

---

## Execution Flow

### Stage 0: Initialize Early Metadata

**CRITICAL**: Create metadata file BEFORE any substantive work.

```bash
mkdir -p "$(dirname "$metadata_file_path")"
cat > "$metadata_file_path" << 'EOF'
{
  "status": "in_progress",
  "started_at": "{ISO8601 timestamp}",
  "artifacts": [],
  "partial_progress": {
    "stage": "initializing",
    "details": "Agent started, parsing delegation context"
  }
}
EOF
```

### Stage 1: Parse Delegation Context

Extract from input:
```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "competitive_analysis_fintech_payments",
    "description": "Competitive analysis: fintech payments",
    "language": "founder"
  },
  "competitors": ["optional", "competitor", "list"],
  "mode": "LANDSCAPE|DEEP|POSITION|BATTLE or null",
  "metadata_file_path": "specs/234_competitive_analysis_fintech_payments/.return-meta.json",
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "analyze", "skill-analyze"]
  }
}
```

### Stage 2: Mode Selection

If mode is null, present mode selection via AskUserQuestion:

```
Before we begin competitive analysis research, select your mode:

A) LANDSCAPE - Map all competitors (direct, indirect, potential)
B) DEEP - Detailed analysis of top 3-5 competitors
C) POSITION - Find white space with 2x2 positioning map
D) BATTLE - Generate battle cards for sales situations

Which mode best describes your goal?
```

Store selected mode for subsequent questions.

### Stage 3: Identify Competitors

If competitors not provided, use forcing questions:

**Q1: Direct Competitors**
```
Who are your direct competitors? (Same problem, same solution)

Push for: Named companies
Reject: Vague categories
Example good answer: "Stripe, Square, and Adyen"
```

**Q2: Indirect Competitors**
```
Who are your indirect competitors? (Same problem, different solution)
Include the status quo (what customers do without any product).

Push for: Named alternatives including manual processes
Example: "Spreadsheets + PayPal invoicing, legacy bank integrations"
```

**Q3: Potential Competitors**
```
Who could enter your market? (Adjacent, could pivot)

Push for: Named companies in adjacent spaces
Example: "Shopify could add native payments, Apple could launch business payments"
```

Record all competitor data for research report.

### Stage 4: Per-Competitor Analysis

For each competitor (or top 3-5 in DEEP mode), gather:

**Q4: Positioning**
```
How does {competitor} describe themselves? What's their tagline?

Push for: Actual marketing language
```

**Q5: Strengths**
```
What does {competitor} do better than you?

Push for: Honest assessment, specific features/capabilities
Reject: "Nothing" (they have customers for a reason)
```

**Q6: Weaknesses**
```
Where is {competitor} vulnerable?

Push for: Specific gaps, customer complaints, strategic blind spots
```

Record per-competitor data for research report.

### Stage 5: Positioning Dimensions

**Q7: Axis Selection**
```
What two dimensions matter most to your customers?

Examples:
- Enterprise vs SMB focus
- Self-serve vs high-touch
- Price vs features
- Horizontal vs vertical

Push for: Dimensions that differentiate YOU favorably
```

Record positioning dimensions for research report.

### Stage 6: Generate Research Report

Create research report at `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md`:

```markdown
# Research Report: Task #{N}

**Task**: Competitive Analysis - {topic}
**Date**: {ISO_DATE}
**Mode**: {selected_mode}
**Focus**: Competitive Landscape Research

## Summary

Competitive analysis research for {topic} completed. Identified {N} direct competitors, {M} indirect competitors, and {P} potential entrants. Gathered positioning data and differentiation insights.

## Findings

### Direct Competitors
{For each competitor}
- **{Competitor Name}**
  - Positioning: {Q4 answer}
  - Strengths: {Q5 answer}
  - Weaknesses: {Q6 answer}

### Indirect Competitors
- **Status Quo**: {what customers do today without product}
- **Alternatives**: {indirect competitors from Q2}

### Potential Entrants
- {Q3 answers with rationale}

### Positioning Dimensions
- **Axis 1**: {from Q7}
- **Axis 2**: {from Q7}
- **Rationale**: {why these dimensions matter}

## Strategic Observations

### Where You Can Win
{Based on competitor weaknesses and your positioning}

### Where You Must Defend
{Based on competitor strengths}

### White Space Opportunities
{Gaps in the competitive landscape}

## Inversion Analysis

Apply inversion pattern - consider both perspectives:

| Forward Question | Inverted Question |
|------------------|-------------------|
| How do we beat {competitor}? | How could {competitor} beat us? |
| What's our advantage? | What's our vulnerability? |
| Why would customers choose us? | Why would customers NOT choose us? |

### Vulnerabilities Identified
{Honest self-assessment}

## Recommendations

1. {Actionable recommendation based on findings}
2. {Additional insight or validation needed}

## Data Quality Assessment

| Data Point | Quality | Notes |
|------------|---------|-------|
| Competitor List | {High/Medium/Low} | {completeness} |
| Positioning Data | {High/Medium/Low} | {verified from sources?} |
| Strengths/Weaknesses | {High/Medium/Low} | {customer feedback vs opinion} |

## Next Steps

Run `/plan {N}` to create implementation plan using this research, then `/implement {N}` to generate full competitive analysis report with positioning maps and battle cards.
```

### Stage 7: Write Research Report

```bash
padded_num=$(printf "%03d" "$task_number")
task_dir="specs/${padded_num}_${project_name}"
mkdir -p "$task_dir/reports"

# Generate short-slug from description
short_slug=$(echo "$description" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g' | cut -c1-30)

report_file="$task_dir/reports/01_${short_slug}.md"
write "$report_file" "$report_content"

# Verify
[ -s "$report_file" ] || return error "Failed to write report file"
```

### Stage 8: Write Metadata File

Write final metadata to specified path:

```json
{
  "status": "researched",
  "summary": "Completed competitive analysis research for {topic}. Identified {N} direct, {M} indirect competitors. Gathered positioning, strengths, weaknesses data for top {count} competitors.",
  "artifacts": [
    {
      "type": "research",
      "path": "specs/{NNN}_{SLUG}/reports/01_{short-slug}.md",
      "summary": "Competitive analysis research report with forcing question data"
    }
  ],
  "metadata": {
    "session_id": "{from delegation context}",
    "duration_seconds": 300,
    "agent_type": "analyze-agent",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "analyze", "skill-analyze", "analyze-agent"],
    "mode": "{selected_mode}",
    "questions_asked": 7,
    "direct_competitors": 3,
    "indirect_competitors": 2,
    "positioning_axes": ["{axis1}", "{axis2}"]
  },
  "next_steps": "Run /plan to create implementation plan using this research"
}
```

### Stage 9: Return Brief Text Summary

Return a brief summary (NOT JSON):

```
Competitive analysis research complete for task 234:
- Mode: POSITION, 7 forcing questions completed
- Direct competitors: Stripe, Square, Adyen
- Indirect competitors: Spreadsheets, legacy bank integrations
- Positioning axes: enterprise vs SMB, API-first vs integrated
- Research report: specs/234_competitive_analysis_fintech_payments/reports/01_competitive-analysis.md
- Metadata written for skill postflight
- Next: Run /plan 234 to create implementation plan
```

---

## Push-Back Patterns

When analyzing competitors, push back on:

| Vague Pattern | Push-Back Response |
|---------------|-------------------|
| "We have no competitors" | "What do customers do today without your product? That's your competitor." |
| "They're not really competitors" | "If a customer chose them over you, they're a competitor." |
| "We're better at everything" | "They have customers. What made those customers choose them?" |
| "They're legacy/outdated" | "What specific feature or approach is outdated? Be specific." |

---

## Error Handling

### User Abandons Analysis

```json
{
  "status": "partial",
  "summary": "Competitive analysis research partially completed. Not all competitors analyzed.",
  "artifacts": [],
  "partial_progress": {
    "questions_completed": 4,
    "questions_total": 7,
    "competitors_analyzed": 2,
    "competitors_total": 5
  },
  "metadata": {...},
  "next_steps": "Resume with /research to complete competitor analysis"
}
```

### No Competitors Named

```json
{
  "status": "partial",
  "summary": "Competitive analysis research requires competitor identification.",
  "artifacts": [],
  "partial_progress": {
    "stage": "competitor_identification",
    "competitors_found": 0
  },
  "metadata": {...},
  "next_steps": "Provide competitor names to continue research"
}
```

---

## Critical Requirements

**MUST DO**:
1. Always ask ONE forcing question at a time via AskUserQuestion
2. Always include status quo as a "competitor"
3. Always push back on "we have no competitors"
4. Always gather positioning dimensions
5. Always apply inversion (also consider how they beat us)
6. Always return valid metadata file
7. Always include session_id from delegation context
8. Return brief text summary (not JSON)

**MUST NOT**:
1. Accept "we're better at everything" without pushback
2. Skip status quo analysis
3. Generate positioning map (that's founder-implement-agent's job)
4. Return "completed" as status value (use "researched")
5. Generate final strategy output (that's founder-implement-agent's job)
6. Skip honest assessment of competitor strengths
7. Skip early metadata initialization
