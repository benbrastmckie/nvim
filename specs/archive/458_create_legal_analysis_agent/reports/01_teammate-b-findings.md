# Teammate B Findings: Alternative Approaches

**Task 458**: Create legal-analysis-agent for critical legal feedback
**Date**: 2026-04-16
**Focus**: Agent design patterns, command structure, /critic design

---

## Key Findings

### 1. The Founder Extension Has Two Distinct Command Patterns

There are two sharply different invocation patterns in the founder extension:

**Pattern A: Research-then-task (existing commands)**
- `/legal`, `/analyze`, `/strategy` all follow the same template
- Asks 3-4 forcing questions BEFORE creating a task
- Creates a task at [NOT STARTED], then stops
- Subsequent `/research N`, `/plan N`, `/implement N` complete the workflow
- Delegation chain: command -> skill -> agent -> postflight

**Pattern B: Immediate analysis (new /critic command)**
- User has a document they want critiqued NOW
- No task scaffolding needed (or optional)
- Agent reads the document, performs critical analysis, returns structured feedback
- More like a "review" command than a "research" command

The /critic command should follow Pattern B. The existing `/legal --quick` mode is the closest analog: it bypasses the task workflow and generates output immediately. `/critic` should always work this way.

### 2. The legal-analysis-agent is Fundamentally Different from legal-council-agent

| Dimension | legal-council-agent | legal-analysis-agent (new) |
|-----------|---------------------|---------------------------|
| Trigger | Contract review Q&A | Document critique request |
| Input | Forcing questions drive the work | Document provided upfront |
| Questions | 8+ mandatory forcing questions | 1-3 clarifying context questions only |
| Output | Research report for follow-on workflow | Immediate structured critique |
| Tone | Counsel gathering facts | Attorney identifying weaknesses |
| Use case | "Help me review this contract" | "What are the problems with this?" |
| Task integration | Yes (full workflow) | Optional (can work standalone) |

The new agent should read a document and immediately identify: legal risks, weak claims, problematic assumptions, missing protections, and concrete fixes -- not gather context through a forcing question session.

### 3. The /critic Command Needs a Flexible Input Model

Based on reading the `/legal` and `/analyze` command structures, the `/critic` command should accept:

- `/critic /path/to/document.md` -- Read file, ask 1-2 context questions, critique
- `/critic "describe the document or paste text"` -- Use text directly as subject
- `/critic N` -- Critique the latest artifact from task N (e.g. a plan or summary)
- `/critic N --attorney` -- Route specifically to legal-analysis-agent
- `/critic N --strategic` -- Route to strategy critique (future extension point)

The `--attorney` flag selects the legal-analysis-agent. Without `--attorney`, the command should ask what type of critique is needed (legal, strategic, financial). This makes `/critic` an extensible command that can route to multiple critique agents.

### 4. The legal-analysis-agent Should NOT Use Forcing Questions as Its Primary Mechanism

The existing agents (analyze-agent, strategy-agent, legal-council-agent) all follow a forcing-questions-first pattern. The legal-analysis-agent should NOT do this. Instead:

1. Receive the document (via path, text, or task artifact)
2. Read it thoroughly
3. Ask ONE clarifying question to understand the user's primary concern or what's at stake
4. Perform deep critical analysis
5. Return structured critique with severity ratings and concrete redline suggestions

The "attorney persona" means: find every problem the document has, prioritize by severity, and give the user exact language to fix each one. Not: gather context before analyzing.

### 5. Agent Structure Should Follow the canonical template with modifications

Required agent structure (from agent-template.md):
- Frontmatter: `name`, `description` (model: opus recommended for legal reasoning depth)
- Stage 0: Initialize early metadata
- Stage 1: Parse delegation context
- Stage 2: Read and load document
- Stage 3: Minimal context gathering (1 question maximum)
- Stage 4: Critical analysis (the core work)
- Stage 5: Write structured critique report
- Stage 6: Write metadata
- Stage 7: Return brief text summary

The agent should NOT write metadata files or integrate with skill-legal -- it needs its own skill (`skill-critic` or inline via the /critic command).

### 6. The /critic Command Architecture

Based on the pattern in `/legal` and `/analyze`, the `/critic` command should:

**Frontmatter**:
```yaml
---
description: Critical analysis with attorney-level feedback on documents, plans, and arguments
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: /path/to/doc.md | TASK_NUMBER | "description" | --attorney | --strategic
---
```

**Workflow**:
1. STAGE 0: Parse input type (file path, task number, description, flags)
2. STAGE 1: If no flag, ask which type of critique (attorney / strategic / financial)
3. STAGE 2: Route to appropriate agent based on flag or selection
4. GATE OUT: Verify critique was generated, display result

The `--attorney` flag skips the routing question and goes directly to legal-analysis-agent.

### 7. The legal-analysis-agent Needs Its Own Context References

The existing `legal-council-agent` loads:
- `@.claude/extensions/founder/context/project/founder/domain/legal-frameworks.md`
- `@.claude/extensions/founder/context/project/founder/patterns/contract-review.md`

The new `legal-analysis-agent` should load the same `legal-frameworks.md` but NOT `contract-review.md` (which is contract-Q&A-focused). It should reference a new context file such as:
- `@.claude/extensions/founder/context/project/founder/patterns/critical-analysis.md` (new)

This new context file would contain: attorney critique patterns, severity rating schema, redline format standards, and pushback patterns for weak legal arguments.

### 8. The Critique Output Format Should Be Structured, Not Narrative

The legal-analysis-agent output should be a structured critique report, not a flowing research report. Recommended format:

```markdown
# Legal Critique: {document title}
**Date**: {date}
**Analyst**: Attorney-mode analysis
**Severity Summary**: {N} Critical, {M} High, {P} Medium

## Executive Summary
One paragraph: overall legal risk posture and most urgent concern.

## Critical Issues (Must Fix)
### Issue 1: {Name}
- **Severity**: Critical
- **Location**: Section X, paragraph Y
- **Problem**: What's wrong and why it matters
- **Risk**: Specific harm if not fixed
- **Redline**: Exact replacement language

## High Priority Issues (Should Fix)
...

## Medium Priority Issues (Consider Fixing)
...

## What's Well Drafted
...

## Attorney Escalation Recommendation
Self-serve / Review recommended / Attorney required
```

---

## Recommended Approach

### Recommended Design: Immediate-analysis agent, not forcing-question agent

**Option A (Recommended)**: `/critic` as standalone command with immediate analysis
- `/critic /path/doc.md --attorney` reads the doc, asks ONE context question ("What's your primary concern or what's at stake?"), then generates a structured critique
- No task creation by default; optional `--task` flag to save as task
- `legal-analysis-agent` is the attorney-mode worker that does deep clause-by-clause critique
- Command routes via flag: `--attorney` -> legal-analysis-agent, `--strategic` -> (future), no flag -> ask

**Option B (Alternative)**: Extend the existing `/legal` command with a `--critic` mode
- Add `--critic` as a new mode to the existing `/legal` command
- Reuses skill-legal but with different agent routing
- Less clean separation between "contract review Q&A" and "document critique"
- Not recommended: the two workflows are too different

**Option C (Minimal)**: Add a new mode to `legal-council-agent`
- Add CRITIQUE mode alongside REVIEW/NEGOTIATE/TERMS/DILIGENCE
- Reuses existing agent without new file
- Not recommended: the forcing-questions pattern would need to be bypassed entirely for CRITIQUE mode, making the agent logic messy

**Verdict**: Option A is cleanest. Create:
1. `legal-analysis-agent.md` - new agent in founder/agents/
2. `critic.md` command in founder/commands/
3. `skill-critic` skill directory (or inline the skill in the command)
4. Optional: `critical-analysis.md` context file in founder/context/patterns/

### Minimal Viable Implementation (if scope must be tight)

If scope is a concern, the absolute minimum is:
1. `legal-analysis-agent.md` - the agent
2. `critic.md` command that only supports `--attorney` flag
3. Inline skill (no separate skill file, command invokes agent directly via Task tool)

This skips the extensibility (no --strategic routing) but delivers the core value.

---

## Evidence/Examples

### Command pattern from /legal (lines 1-6):
```yaml
---
description: Contract review and negotiation counsel with task integration
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/contract.md | --quick [contract type]
---
```
The `/critic` command should follow this exact frontmatter pattern.

### Agent frontmatter from legal-council-agent (lines 1-5):
```yaml
---
name: legal-council-agent
description: Contract review and negotiation counsel for AI startup founders
---
```
The `legal-analysis-agent` should use the same minimal frontmatter, with `model: opus` added since legal reasoning needs maximum depth.

### Skill-legal Stage 5 invocation pattern (lines 179-188):
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "legal-council-agent"
  - prompt: [Include task_context, forcing_data, contract_type, primary_concern, mode, metadata_file_path, metadata]
  - description: "Contract review and legal analysis"
```
The `/critic` command (or its skill) should use the same Task tool invocation pattern.

### Early metadata pattern from analyze-agent (lines 62-78):
All agents write `.return-meta.json` with `status: "in_progress"` before any substantive work. The `legal-analysis-agent` must do the same.

### Push-back patterns from legal-council-agent (lines 346-356):
The existing legal-council-agent has push-back patterns for vague answers. The legal-analysis-agent should have push-back patterns for weak legal arguments -- e.g. "This is industry standard" -> "Standard doesn't mean enforceable. What clause specifically?"

---

## What the /critic Command Does NOT Need

Based on pattern analysis, the following can be omitted from /critic:
- **Forcing questions session**: The document IS the context. One clarifying question is sufficient.
- **STAGE 0 pre-task gathering**: /critic is immediate-mode by design
- **Mode selection menu**: The --attorney flag handles routing; if no flag, ask a single routing question
- **Full task workflow integration**: Optional but not primary; `/critic` should work without task numbers
- **Escalation threshold ($100K)**: That's contract review logic, not document critique logic

---

## Confidence Level

**High confidence**:
- The command architecture (frontmatter, input type detection, Task tool invocation)
- The agent structure (Stage 0 metadata, delegation context, return format)
- The distinction between legal-council-agent (Q&A) and legal-analysis-agent (critique)
- The output format (structured critique with severity levels)
- That legal-analysis-agent should use `model: opus`

**Medium confidence**:
- Whether to create a full `skill-critic` skill file or inline the skill in the command
- Whether `critical-analysis.md` context file is necessary or if the agent prompt is sufficient
- The exact set of flags for `/critic` (--attorney, --strategic, etc.)
- Whether task integration should be optional (`--task`) or default-off

**Low confidence**:
- Whether the founder extension manifest needs to be updated to register `/critic`
- How skill routing table updates work in the founder extension (need to see manifest.json)
