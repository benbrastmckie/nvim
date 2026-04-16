# Research Report: Task #425

**Task**: 425 - create_skill_slide_critic
**Started**: 2026-04-13T00:00:00Z
**Completed**: 2026-04-13T00:15:00Z
**Effort**: small-medium
**Dependencies**: slide-critic-agent (already created)
**Sources/Inputs**: Codebase exploration of existing present extension skills, agents, and patterns
**Artifacts**: specs/425_create_skill_slide_critic/reports/01_skill-slide-critic-research.md
**Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- skill-slide-critic should follow the established skill-internal postflight pattern used by skill-slides and skill-slide-planning
- The skill runs an interactive critique loop: delegate to slide-critic-agent, present issues to user grouped by category/severity, collect accept/reject/modify decisions, loop until resolved, produce final filtered report
- skill-slide-planning provides the canonical AskUserQuestion interactive loop pattern with consolidated questions to minimize round-trips
- The slide-critic-agent already produces structured per-slide findings with severity tags, categories, and recommendations -- the skill parses this report to build the interactive issue list
- A new `workflow_type: "slides_critique"` fits naturally into the existing skill-slides routing, or the skill can be standalone with its own trigger

## Context & Scope

This research examines the patterns needed to design skill-slide-critic: a new skill in the present extension that runs an interactive critique feedback loop. The skill delegates to the existing slide-critic-agent for initial material review, then iteratively presents findings to the user for accept/reject/modify decisions.

Key questions investigated:
1. How do existing present extension skills delegate to agents and handle postflight?
2. How does skill-slide-planning implement interactive AskUserQuestion loops?
3. What structured output does slide-critic-agent produce?
4. What is the correct skill template structure?

## Findings

### 1. Skill-Internal Postflight Pattern (from skill-slides)

skill-slides is the canonical example of the "thin wrapper with internal postflight" pattern:

**Structure** (11 stages):
1. Input validation (task lookup, type check)
2. Preflight status update (state.json + TODO.md markers)
3. Create postflight marker file (`.postflight-pending`)
4. Prepare delegation context JSON
5. Invoke subagent via **Task tool** (NOT Skill tool)
5b. Self-execution fallback (write `.return-meta.json` if no Task tool used)
6. Read metadata file from subagent
7. Update task status (postflight)
8. Link artifacts to state.json and TODO.md
9. Git commit
10. Cleanup (remove `.postflight-pending`, `.postflight-loop-guard`, `.return-meta.json`)
11. Return brief text summary

**Key pattern**: The skill creates `.postflight-pending` BEFORE invoking the subagent. The SubagentStop hook reads this marker to prevent premature termination. After the subagent returns, the skill reads `.return-meta.json` for status and artifact paths.

**Routing**: skill-slides routes by `workflow_type` + `output_format`:
- `slides_research` -> `slides-research-agent`
- `assemble` + `pptx` -> `pptx-assembly-agent`
- `assemble` + `slidev` -> `slidev-assembly-agent`

This suggests skill-slide-critic could either:
- **Option A**: Add `slides_critique` as a new workflow_type to skill-slides (consistent with existing pattern)
- **Option B**: Be a standalone skill with its own trigger (cleaner separation given the interactive loop)

### 2. Interactive AskUserQuestion Loop Pattern (from skill-slide-planning)

skill-slide-planning implements a 5-stage interactive Q&A flow before delegating to its agent:

**Interactive stages**:
- Stage 3: Theme selection (multiple choice A-E or custom text)
- Stage 4: Narrative arc review (reorder/add/remove/modify feedback)
- Stage 5: Slide picker (include/exclude by number)
- Stage 6: Per-slide detail feedback (consolidated single question for all slides)

**Key patterns for skill-slide-critic to adopt**:

1. **Consolidated questions minimize round-trips**: Stage 6 presents ALL included slides in one AskUserQuestion rather than asking one-by-one. For skill-slide-critic, present all issues grouped by category in one question.

2. **Structured response parsing**: Responses like "2: emphasize the clinical urgency more" are parsed as `{number}: {feedback}`. The skill should define a similar grammar for accept/reject/modify.

3. **"Looks good" / "done" shortcut**: Users can skip with "looks good" for no changes. The critique skill needs similar escape hatches ("accept all", "done").

4. **Existing design decisions reuse**: Stage 2 checks for existing decisions and asks if user wants to reuse or start fresh. The critique skill should support re-running on already-critiqued tasks.

5. **Section grouping for long content**: Stage 6 groups slides by section for talks with 20+ slides. The critique skill should group issues by category and severity.

### 3. Slide-Critic-Agent Output Structure

The agent produces a structured critique report at `specs/{NNN}_{SLUG}/reports/{MM}_slide-critique.md` with:

**Per-slide findings format**:
```
### Slide N ({slide_type})
- [{severity}] {category}: {finding}
  Suggested improvement: {actionable fix}
```

**Summary section**:
```
- Critical: {count} findings
- Major: {count} findings
- Minor: {count} findings
- Top issues: {ranked list}
- Strengths: {what works well}
```

**Recommendations in three tiers**: Must Fix, Should Fix, Nice to Fix

**Metadata returned** (in `.return-meta.json`):
```json
{
  "status": "researched",
  "metadata": {
    "findings_count": { "critical": N, "major": N, "minor": N, "total": N },
    "categories_evaluated": [...],
    "talk_type": "CONFERENCE"
  }
}
```

The skill needs to **parse the markdown report** to extract individual findings into a structured list for the interactive loop. Each finding has: slide number, severity, category, criterion, description, suggested improvement.

### 4. Skill Template and Frontmatter

From the creating-agents guide and existing skills, the SKILL.md frontmatter should be:

```yaml
---
name: skill-slide-critic
description: Interactive critique loop for slide presentations. Delegates to slide-critic-agent, presents findings to user, collects responses, produces final report.
allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion
context: fork
agent: slide-critic-agent
---
```

The `context: fork` field (used by skill-slide-planning) indicates the skill manages its own context fork for the subagent delegation.

### 5. Manifest Integration

The present extension manifest (`manifest.json`) currently does NOT include `skill-slide-critic` in its routing or provides arrays. It needs:
- Add to `provides.skills`: `"skill-slide-critic"`
- Add routing entry (if standalone): e.g., a new command or a workflow_type within existing routing

Currently the manifest routes `present:slides` research to `skill-slides` and plan to `skill-slide-planning`. A critique operation could be triggered by a new command `/critique` or by adding a critique workflow to the existing `/slides` command.

### 6. Report-Format Compliance for Final Critique Report

The skill's final output (after user filtering) should be a **filtered critique report** that retains only accepted/modified issues and incorporates user modifications. This report becomes the input for `/plan` to guide slide redesign.

Recommended format for the final filtered report:
```markdown
# Filtered Critique Report: {title}

## Accepted Issues ({count})
### Must Fix ({count})
- Slide {N}: [{severity}] {category}: {description} [USER: {modification if any}]

### Should Fix ({count})
- ...

### Nice to Fix ({count})
- ...

## Rejected Issues ({count})
{Listed for reference but marked as dismissed}

## User Notes
{Any freeform feedback the user provided}
```

## Decisions

1. **Standalone skill** (Option B): skill-slide-critic should be a standalone skill rather than a new workflow_type in skill-slides, because:
   - It has a fundamentally different execution pattern (interactive loop vs. simple delegation)
   - skill-slides is already complex with 3 agent routing paths
   - Cleaner separation of concerns

2. **Two-pass architecture**: First pass delegates to slide-critic-agent (non-interactive), second pass presents findings to user (interactive). This keeps the agent simple and read-only.

3. **Consolidated AskUserQuestion**: Present all issues in one question grouped by category/severity, following skill-slide-planning Stage 6 pattern.

4. **Parse markdown report**: Rather than inventing a new structured data exchange format, parse the markdown critique report that the agent already produces. This avoids modifying the agent.

## Recommendations

### Proposed Execution Flow

1. **Input validation**: Accept task_number + optional focus_categories, audience_context
2. **Preflight**: Update status, create postflight marker
3. **Delegate to slide-critic-agent**: Via Task tool with full delegation context
4. **Parse critique report**: Extract findings from the markdown report into structured list
5. **Interactive critique loop** (core innovation):
   - Present findings grouped by category, ordered by severity
   - User responds with: `A` (accept), `R` (reject), `M: {modification}` per issue number
   - Support shortcuts: "accept all critical", "reject all minor", "done"
   - Loop if user requests re-review of specific categories
6. **Generate filtered report**: Write final report with user decisions
7. **Postflight**: Status update, artifact linking, git commit, cleanup
8. **Return summary**

### Input Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `task_number` | Yes | Task with task_type containing "slides" |
| `session_id` | Yes | From orchestrator |
| `focus_categories` | No | Subset of 6 rubric categories to prioritize |
| `audience_context` | No | Audience description for calibrating review |
| `materials_to_review` | No | Override default material discovery |

### AskUserQuestion Design

**Presentation format** (one consolidated question):
```
Critique findings for your {talk_type} presentation ({N} total issues):

=== MUST FIX ({count}) ===

 1. [Critical] Narrative Flow - Slide 3: {description}
    Suggested: {improvement}

 2. [Critical] Audience Alignment - Slide 7: {description}
    Suggested: {improvement}

=== SHOULD FIX ({count}) ===

 3. [Major] Timing Balance - General: {description}
    Suggested: {improvement}

...

=== NICE TO FIX ({count}) ===

...

For each issue, respond with its number and action:
  1: A          (accept as-is)
  3: R          (reject/dismiss)
  5: M add comparison to Smith 2024  (modify the suggestion)

Shortcuts: "accept all", "reject all minor", "done" (accept remaining)
```

**Response parsing grammar**:
- `{N}: A` -> accept issue N
- `{N}: R` -> reject issue N
- `{N}: M {text}` -> modify issue N with user's text
- `accept all` -> accept all remaining unaddressed issues
- `reject all minor` -> reject all Minor severity issues
- `done` -> accept all remaining unaddressed issues
- `review {category}` -> re-present issues from that category

### Looping Behavior

After processing user responses:
- If all issues are addressed (accepted, rejected, or modified): proceed to final report
- If user asks to "review {category}": re-present just that category's issues
- Maximum 3 loop iterations to prevent infinite cycles (then auto-accept remaining)

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Critique report parsing fails (markdown format changes) | Low | High | Use robust regex patterns; fall back to presenting raw report sections |
| Too many findings overwhelm user | Medium | Medium | Group by tier (must/should/nice); allow bulk actions ("accept all minor") |
| User abandons mid-loop | Low | Medium | Save partial decisions; support resume on re-run |
| Agent produces no findings | Low | Low | Handle gracefully; report "no issues found" as success |
| Manifest routing conflict | Low | Medium | Register as standalone skill with clear trigger conditions |

## Appendix

### Files Examined

| File | Purpose |
|------|---------|
| `.claude/extensions/present/skills/skill-slides/SKILL.md` | Agent delegation + postflight pattern |
| `.claude/extensions/present/skills/skill-slide-planning/SKILL.md` | Interactive AskUserQuestion loop pattern |
| `.claude/extensions/present/agents/slide-critic-agent.md` | Agent output structure and input contract |
| `.claude/extensions/present/manifest.json` | Extension routing configuration |
| `.claude/extensions/present/context/project/present/talk/critique-rubric.md` | Evaluation rubric (6 categories, severity definitions) |
| `.claude/context/formats/return-metadata-file.md` | Metadata file schema |
| `.claude/context/patterns/postflight-control.md` | Marker file protocol |
| `.claude/docs/guides/creating-agents.md` | Skill/agent template structure |

### Key Patterns Summary

| Pattern | Source | Application |
|---------|--------|-------------|
| Skill-internal postflight | skill-slides | Postflight stages 6-10 |
| Consolidated AskUserQuestion | skill-slide-planning Stage 6 | Single question with all issues |
| Response parsing grammar | skill-slide-planning Stage 6 | `{N}: {action}` format |
| Postflight marker | postflight-control.md | `.postflight-pending` file |
| Task tool delegation | skill-slides Stage 5 | Spawn slide-critic-agent |
| Metadata file exchange | return-metadata-file.md | `.return-meta.json` protocol |
