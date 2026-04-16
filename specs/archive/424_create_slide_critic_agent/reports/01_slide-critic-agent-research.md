# Research Report: Task #424

**Task**: 424 - create_slide_critic_agent
**Started**: 2026-04-13T00:00:00Z
**Completed**: 2026-04-13T00:05:00Z
**Effort**: Small (agent file creation)
**Dependencies**: Task 423 (critique-rubric.md -- completed)
**Sources/Inputs**:
- Codebase: `.claude/extensions/present/agents/slides-research-agent.md`
- Codebase: `.claude/extensions/present/agents/slide-planner-agent.md`
- Codebase: `.claude/extensions/present/context/project/present/talk/critique-rubric.md`
- Codebase: `.claude/extensions/present/index-entries.json`
- Codebase: `.claude/extensions/present/manifest.json`
- Standard: `.claude/docs/reference/standards/agent-frontmatter-standard.md`
- Standard: `.claude/context/formats/return-metadata-file.md`
- Guide: `.claude/docs/guides/creating-agents.md`
**Artifacts**: - `specs/424_create_slide_critic_agent/reports/01_slide-critic-agent-research.md`
**Standards**: report-format.md, artifact-management.md, tasks.md

## Executive Summary

- The present extension has two existing slide-workflow agents (slides-research-agent, slide-planner-agent) that provide a consistent structural template: YAML frontmatter, 8-stage execution flow, file-based metadata return, and context references with `load_when` index entries.
- The critique-rubric.md (task 423) defines 6 evaluation categories, 3 severity levels, a talk-type priority matrix, and explicit output format guidance that the critic agent should directly consume.
- The slide-critic-agent should use `model: opus` (complex analytical reasoning required), accept source materials + research reports + plans + existing slides as input, and produce a structured issue list as its primary artifact.
- The agent needs a new index entry in `index-entries.json` for the critique-rubric.md context, and a new routing entry will eventually be needed in `manifest.json` for the `/slides` command's critique mode.

## Context & Scope

This research informs the design of a `slide-critic-agent` that will review presentation materials against the critique rubric and produce structured feedback. The agent will be placed at `.claude/extensions/present/agents/slide-critic-agent.md` and follow the established patterns of sibling agents in the same extension.

### Constraints
- Must follow the agent-frontmatter-standard (name, description, model fields)
- Must use file-based metadata return (`.return-meta.json`), not console JSON
- Must follow the 8-stage execution flow pattern
- Must produce output in the format specified by critique-rubric.md (per-slide findings, summary, recommendations)

## Findings

### 1. Agent Frontmatter Pattern

Both existing slide agents use identical frontmatter structure:

```yaml
---
name: {agent-name}
description: {purpose description}
model: opus
---
```

The critic agent should use `model: opus` because critique requires deep analytical reasoning -- evaluating narrative flow, audience alignment, timing balance, content depth, evidence quality, and visual design across all slides simultaneously.

### 2. Execution Flow Structure (8 Stages)

Both agents follow this exact stage pattern:

| Stage | Purpose | Notes |
|-------|---------|-------|
| 0 | Initialize early metadata | Write `in_progress` to `.return-meta.json` |
| 1 | Parse delegation context | Extract task_context, forcing_data, metadata_file_path |
| 2 | Load primary inputs | Research agent reads source materials; planner reads research report |
| 3 | Load supporting context | Talk pattern JSONs, theme JSONs based on talk_type |
| 4 | Core analysis/processing | Content mapping (research) or decision application (planner) |
| 5 | Gap identification / output | Content gaps (research) or per-slide specs (planner) |
| 6 | Write artifact | Report or plan file to specs/{NNN}_{SLUG}/ |
| 7 | Write final metadata | Status, artifacts, metadata to `.return-meta.json` |
| 8 | Return brief text summary | 3-6 bullet points, NOT JSON |

For the critic agent, the stages should map to:

| Stage | Critic Purpose |
|-------|---------------|
| 0 | Initialize early metadata |
| 1 | Parse delegation context (task info, materials paths, talk_type) |
| 2 | Load critique rubric and talk-type priority matrix |
| 3 | Load all review materials (source files, research reports, plans, slides) |
| 4 | Evaluate each slide/material against rubric criteria |
| 5 | Aggregate findings, compute severity counts, rank issues |
| 6 | Write critique report artifact |
| 7 | Write final metadata |
| 8 | Return brief text summary |

### 3. Delegation Context Pattern

Both agents receive a structured delegation context with these common fields:

```json
{
  "session_id": "sess_...",
  "task_context": {
    "task_number": N,
    "task_name": "...",
    "description": "...",
    "task_type": "present:slides"
  },
  "forcing_data": {
    "talk_type": "CONFERENCE|SEMINAR|DEFENSE|POSTER|JOURNAL_CLUB",
    "source_materials": ["task:N", "/path/to/file"],
    "audience_context": "description"
  },
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

The critic agent will need additional fields in its delegation context:

```json
{
  "forcing_data": {
    "talk_type": "CONFERENCE|SEMINAR|DEFENSE|POSTER|JOURNAL_CLUB",
    "materials_to_review": [
      {"type": "source", "path": "path/to/manuscript.md"},
      {"type": "research_report", "path": "specs/.../reports/01_slides-research.md"},
      {"type": "plan", "path": "specs/.../plans/02_slide-plan.md"},
      {"type": "slides", "path": "talks/N_slug/slides.md"}
    ],
    "audience_context": "description",
    "focus_categories": ["narrative_flow", "evidence_quality"]
  }
}
```

The `focus_categories` field is optional -- when omitted, all 6 rubric categories are evaluated. When provided, the agent prioritizes those categories but still checks all categories at reduced depth.

### 4. Context Loading Pattern

Existing agents declare context references in two ways:

**A. In-agent @-references (always load)**:
```markdown
**Always Load**:
- `@.claude/context/formats/return-metadata-file.md`
```

**B. Via index-entries.json (conditional load)**:
Each context file has a `load_when` block:
```json
{
  "load_when": {
    "languages": ["present"],
    "agents": ["slides-research-agent", "slide-planner-agent"],
    "commands": ["/slides"]
  }
}
```

The critic agent needs:

**Always load**:
- `@.claude/context/formats/return-metadata-file.md` -- metadata schema
- `@.claude/extensions/present/context/project/present/talk/critique-rubric.md` -- the rubric itself

**Conditionally load (via index entry)**:
- `presentation-types.md` -- audience, duration, format per mode
- `talk-structure.md` -- slide density, visual elements, timing rules
- The relevant talk pattern JSON (conference-standard.json, etc.)

The critique-rubric.md currently has **no index entry** in `index-entries.json`. An entry must be added with `agents: ["slide-critic-agent"]`.

### 5. Critique Rubric Output Format

The rubric (task 423) explicitly defines the expected output structure:

**Per-Slide Findings**:
```
- Slide {N} ({slide_type}):
  - [{severity}] {category}: {finding}
```

**Summary**:
```
- Critical: {count} findings
- Major: {count} findings
- Minor: {count} findings
- Top issues: {ranked list}
- Strengths: {what works well}
```

**Recommendations**:
```
- Must fix: {critical items, ordered by impact}
- Should fix: {major items, ordered by effort}
- Nice to fix: {minor items}
```

The agent's artifact should use this exact structure, wrapped in a standard report format with metadata headers.

### 6. Talk-Type Priority Matrix

The rubric includes a priority matrix that adjusts category importance by talk type:

| Category | CONFERENCE | SEMINAR | DEFENSE | POSTER | JOURNAL_CLUB |
|----------|-----------|---------|---------|--------|--------------|
| Narrative Flow | High | Critical | High | Medium | High |
| Audience Alignment | Critical | High | High | High | Medium |
| Timing Balance | Critical | High | Medium | N/A | Medium |
| Content Depth | Medium | High | Critical | Medium | Critical |
| Evidence Quality | High | High | Critical | High | Critical |
| Visual Design | High | Medium | Medium | Critical | Low |

The critic agent should use this matrix to weight findings -- a "Major" finding in a "Critical" priority category should be elevated in the ranked output.

### 7. Allowed Tools Pattern

Both existing agents declare tools by category:

- **File Operations**: Read, Write, Edit, Glob, Grep
- **Build Tools**: Bash (shell commands)
- **Web Tools**: WebSearch, WebFetch (slides-research-agent only)

The critic agent should have:
- **File Operations**: Read, Glob, Grep (read-only except for writing the report artifact)
- **Write**: Write (for creating the critique report)
- **Build Tools**: Bash (for file operations, jq queries)
- No web tools needed (critique is about reviewing existing materials, not external research)

### 8. Metadata Return Pattern

Final metadata follows the return-metadata-file.md schema:

```json
{
  "status": "researched",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/{NNN}_{SLUG}/reports/{MM}_slide-critique.md",
      "summary": "Critique report: {critical_count} critical, {major_count} major, {minor_count} minor findings"
    }
  ],
  "next_steps": "Review critique findings and address critical issues before presenting",
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "slide-critic-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "slides", "skill-slides", "slide-critic-agent"],
    "findings_count": N
  }
}
```

Note: The status should be `"researched"` since critique is an analytical/review operation, not an implementation.

### 9. Error Handling Patterns

Both agents document fallback behavior:

| Condition | slides-research-agent | slide-planner-agent | Recommended for critic |
|-----------|----------------------|---------------------|----------------------|
| Missing materials | Log, continue with available | Warn, use defaults | Log, critique available materials only |
| Invalid talk type | Default to CONFERENCE | Default to CONFERENCE | Default to CONFERENCE priority matrix |
| Write failure | Write error metadata | Write error metadata | Write error metadata |
| Timeout | Save partial, write partial status | Save partial | Save partial critique, write partial status |

### 10. Integration Points

**manifest.json**: Currently has no critique routing. The implementation task should add a critique mode route, potentially:
```json
{
  "routing": {
    "critique": {
      "present:slides": "skill-slides:critique"
    }
  }
}
```

Or the critique could be integrated into the existing `/slides` workflow as a post-assembly verification step invoked by `skill-slides`.

**index-entries.json**: Needs a new entry for critique-rubric.md:
```json
{
  "path": "project/present/talk/critique-rubric.md",
  "domain": "project",
  "subdomain": "present",
  "topics": ["critique", "rubric", "evaluation", "slides", "review"],
  "keywords": ["critique", "rubric", "severity", "narrative", "audience", "timing"],
  "summary": "6-category critique rubric with severity definitions, talk-type priority matrix, and structured output format",
  "line_count": 249,
  "load_when": {
    "task_types": ["present"],
    "agents": ["slide-critic-agent"],
    "commands": ["/slides"]
  }
}
```

**provides.agents** in manifest.json: Must add `"slide-critic-agent.md"` to the agents array.

## Decisions

- **Model**: Use `model: opus` -- critique requires complex multi-dimensional reasoning across 6 categories.
- **Status value**: Use `"researched"` for successful critique output (analytical, not implementation).
- **Artifact type**: Use `"report"` artifact type for the critique output.
- **No web tools**: Critique is entirely local material review; no WebSearch/WebFetch needed.
- **Output format**: Follow the rubric's explicit output format guidance exactly (per-slide findings, summary, recommendations).
- **Priority weighting**: Implement talk-type priority matrix to adjust issue ranking.

## Recommendations

1. **Agent file structure**: Follow the slides-research-agent pattern closely, adapting the 8-stage flow for critique-specific operations. The stages should map as described in Finding #2.

2. **Delegation context**: Include a `materials_to_review` array in `forcing_data` that can accept source files, research reports, plans, and assembled slides. Include an optional `focus_categories` field for targeted review.

3. **Index entry for critique-rubric.md**: Add the entry described in Finding #10 to `index-entries.json` so the rubric loads automatically for the critic agent.

4. **Manifest updates**: Add `"slide-critic-agent.md"` to `provides.agents`. Consider adding a critique routing entry, though this may be deferred until the invoking skill is created.

5. **Critique report artifact path**: Use `specs/{NNN}_{SLUG}/reports/{MM}_slide-critique.md` with standard metadata headers.

6. **Severity weighting**: Implement a simple weighting scheme where findings in categories rated "Critical" for the talk type are automatically elevated by one severity level in the ranked output (e.g., a "Major" finding in a "Critical" category sorts above other "Major" findings).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Materials provided in inconsistent formats | Medium | Medium | Accept multiple input types; use Glob/Grep to discover materials if paths are missing |
| Rubric categories produce too many findings | Low | Medium | Cap detailed per-slide output; summarize patterns instead of listing every instance |
| Talk type not specified | Low | Low | Default to CONFERENCE priority matrix (most common) |
| No invoking skill exists yet | None (deferred) | N/A | Agent can be tested directly; skill creation is a separate task |

## Appendix

### Files Examined
- `.claude/extensions/present/agents/slides-research-agent.md` (304 lines)
- `.claude/extensions/present/agents/slide-planner-agent.md` (352 lines)
- `.claude/extensions/present/context/project/present/talk/critique-rubric.md` (249 lines)
- `.claude/extensions/present/index-entries.json` (494 lines)
- `.claude/extensions/present/manifest.json` (66 lines)
- `.claude/docs/reference/standards/agent-frontmatter-standard.md` (138 lines)
- `.claude/context/formats/return-metadata-file.md` (503 lines)
- `.claude/docs/guides/creating-agents.md` (694 lines)

### Key Pattern Summary

| Pattern | Source | Application |
|---------|--------|-------------|
| YAML frontmatter (name, description, model) | agent-frontmatter-standard.md | Required agent header |
| 8-stage execution flow | creating-agents.md + existing agents | Stage structure for critic |
| File-based metadata return | return-metadata-file.md | `.return-meta.json` output |
| Early metadata (Stage 0) | early-metadata-pattern.md | Write `in_progress` before work |
| Context @-references | existing agents | Lazy-load rubric and talk patterns |
| `load_when` index entries | index-entries.json | Route context to agent automatically |
| Talk-type priority matrix | critique-rubric.md | Weight findings by presentation mode |
| Structured output format | critique-rubric.md | Per-slide findings + summary + recommendations |
