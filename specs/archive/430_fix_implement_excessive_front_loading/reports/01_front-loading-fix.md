# Research Report: Task #430

**Task**: 430 - Fix /implement excessive front-loading
**Started**: 2026-04-14T12:00:00Z
**Completed**: 2026-04-14T12:15:00Z
**Effort**: Small (3 targeted edits to existing files)
**Dependencies**: None
**Sources/Inputs**:
- `.claude/skills/skill-team-implement/SKILL.md` (663 lines)
- `.claude/skills/skill-implementer/SKILL.md` (435 lines)
- `.claude/agents/general-implementation-agent.md` (241 lines)
- `.claude/context/patterns/team-orchestration.md` (147 lines)
- `.claude/context/standards/postflight-tool-restrictions.md` (203 lines)
**Artifacts**: - This report: `specs/430_fix_implement_excessive_front_loading/reports/01_front-loading-fix.md`
**Standards**: report-format.md, artifact-formats.md

## Executive Summary

- The existing `postflight-tool-restrictions.md` standard prevents the skill from doing agent work AFTER delegation, but there is no equivalent "pre-delegation" constraint preventing the skill from doing agent work BEFORE delegation.
- `skill-team-implement/SKILL.md` Stage 5 instructs the lead to "parse implementation plan to identify parallelization opportunities" with heuristic file-overlap analysis, which tempts the lead to read source files to resolve ambiguities.
- `skill-implementer/SKILL.md` is already thin (no source reading), but Stage 4's delegation context could explicitly forbid pre-reading.
- `general-implementation-agent.md` Stage 2 says "Load and Parse Implementation Plan" but does not explicitly claim codebase exploration as its exclusive responsibility.
- Three targeted insertions and one modification will fix the problem across all three files.

## Context & Scope

When `/implement` runs, the orchestrating skill (either `skill-implementer` or `skill-team-implement`) should function as a thin coordinator: read the plan, extract structure, and immediately delegate to sub-agents. Currently, there is no explicit constraint preventing the lead from reading source files, grepping the codebase, or using MCP tools before spawning agents. The `postflight-tool-restrictions.md` standard covers the post-delegation boundary but not the pre-delegation boundary.

This research identifies exact insertion points for "anti-front-loading" constraints in each of the three affected files.

## Findings

### Finding 1: skill-team-implement/SKILL.md - Stage 5 Heuristic Invites Source Reading

**Location**: Lines 183-225 (Stage 5: Analyze Phase Dependencies)

The fallback heuristic inference block (lines 208-219) says:

```
if not has_explicit_deps:
  # Build dependency graph from file overlap analysis
  dependency_graph = {}
  for phase in phases:
    dependency_graph[phase.number] = {
      ...
      "files": phase.files_modified
    }
```

And lists "Implicit dependencies from file modifications" and "Cross-phase imports or references" as heuristic signals. While this is meant to operate on plan text, the phrase "file overlap analysis" and "Cross-phase imports" can be interpreted as requiring the lead to actually read source files to determine overlap and imports. The lead should only use file paths listed in the plan text, never read the actual source files.

**Insertion Point 1**: After Stage 5's fallback block (after line 219), add a constraint box clarifying that all analysis must use plan text only.

### Finding 2: skill-team-implement/SKILL.md - Stage 7 Prompt Template Is Correct But Needs Sourcing Clarification

**Location**: Lines 266-298 (Stage 7: Spawn Phase Implementers)

The Phase Implementer Prompt Template at line 267 includes:
- `{phase_details from plan}`
- `{files_list}`
- `{steps_from_plan}`
- `{verification_criteria}`

These template variables are ambiguous: `{files_list}` could be interpreted as "read the files and include their contents" rather than "list the file paths from the plan." The instruction at line 289 says "Read existing files before modifying" which correctly tells the SUB-AGENT to read files, but the lead might pre-read them to populate the template.

**Insertion Point 2**: Before the prompt template (before line 267), add a constraint that all template variables must be extracted from plan text only. The lead must NOT read source files to populate the template.

### Finding 3: skill-team-implement/SKILL.md - No Pre-Delegation Boundary Section

**Location**: After the "MUST NOT (Postflight Boundary)" section at lines 644-662

The file has a "MUST NOT (Postflight Boundary)" section but no equivalent pre-delegation boundary. This is the structural gap.

**Insertion Point 3**: Add a new "MUST NOT (Pre-Delegation Boundary)" section before or after the existing postflight boundary section (after line 662), establishing the mirror constraint.

### Finding 4: skill-implementer/SKILL.md - Stage 4-5 Needs Pre-Delegation Constraint

**Location**: Lines 137-215 (Stage 4: Prepare Delegation Context through Stage 5: Invoke Subagent)

The skill is already thin, but there is no explicit statement forbidding the lead from reading source files before delegation. The delegation context (Stage 4) and subagent invocation (Stage 5) should include a constraint.

**Insertion Point 4**: Between Stage 4 and Stage 4b (between lines 160 and 162), add a pre-delegation constraint note. Also add a "MUST NOT (Pre-Delegation Boundary)" section at the end of the file, mirroring the postflight boundary already referenced at line 434.

### Finding 5: general-implementation-agent.md - Stage 2 Should Claim Exclusive Codebase Responsibility

**Location**: Lines 33-39 (Stage 2: Load and Parse Implementation Plan)

Stage 2 says to "Read the plan file and extract" phase data, but it does not explicitly state that codebase exploration (reading source files, grepping, using MCP tools) is the agent's exclusive responsibility -- not the delegating skill's.

**Insertion Point 5**: After Stage 2 (after line 39), add a note establishing that all codebase exploration (Read of source files, Grep, Glob, MCP tools) happens here in the agent, not in the delegating skill.

### Finding 6: Existing Postflight Pattern Provides Template

The `postflight-tool-restrictions.md` standard provides a well-structured template with allowed/prohibited tables and a "MUST NOT Section Template." The pre-delegation constraint should follow the same structural pattern for consistency.

## Decisions

1. **Mirror the postflight boundary pattern**: Create a "Pre-Delegation Boundary" constraint that follows the same format as the existing "Postflight Boundary" in both skills.
2. **Constraint placement**: Add constraints at both the structural level (new MUST NOT section) and inline at the specific stages where front-loading is tempted.
3. **No new context file needed**: The constraint is small enough to live inline in the skill files. A separate `pre-delegation-tool-restrictions.md` context file would be overkill; instead, the postflight restrictions file can be extended with a brief pre-delegation section.

## Recommendations

### Change 1: skill-team-implement/SKILL.md (3 insertions)

**1a. Add anti-front-loading constraint to Stage 5** (after line 219):

Insert after the heuristic signals list:

```markdown
**CRITICAL: Plan-Text-Only Analysis**

All dependency analysis in this stage must use ONLY information extracted from the plan file text:
- File paths listed in phase "Files to Modify" sections
- Explicit "Depends on" fields
- Phase names and descriptions

The lead MUST NOT read source files, grep the codebase, or use MCP tools to resolve dependency ambiguities. If the plan lacks sufficient dependency information, default to sequential execution (each phase depends on the previous).
```

**1b. Add sourcing clarification to Stage 7** (before line 267, the prompt template):

Insert before "Phase Implementer Prompt Template":

```markdown
**CRITICAL: Template Population from Plan Text Only**

All template variables below (`{phase_details}`, `{files_list}`, `{steps_from_plan}`, `{verification_criteria}`) MUST be populated by extracting text from the plan file. The lead MUST NOT:
- Read source files to populate `{files_list}` or `{phase_details}`
- Grep the codebase to enrich step descriptions
- Use MCP tools to gather additional context

The sub-agent is responsible for reading source files after being spawned.
```

**1c. Add pre-delegation boundary section** (after the existing MUST NOT postflight section, after line 662):

```markdown
## MUST NOT (Pre-Delegation Boundary)

Before spawning phase implementer teammates, this skill MUST NOT:

1. **Read source files** - Codebase exploration is the sub-agent's job
2. **Grep or Glob source directories** - Pattern search is the sub-agent's job
3. **Use MCP tools** - Domain tools are for sub-agent use only
4. **Analyze file contents** - Only plan text should be parsed
5. **Resolve ambiguities by reading code** - Default to sequential if unclear

The pre-delegation phase is LIMITED TO:
- Reading the plan file (one Read call)
- Parsing phase structure, dependencies, and wave groupings from plan text
- Extracting file paths and step descriptions from plan text
- Constructing teammate prompts from extracted plan data
- State management (status updates, marker files)
```

### Change 2: skill-implementer/SKILL.md (2 insertions)

**2a. Add inline constraint after Stage 4** (between current Stage 4 closing and Stage 4b, around line 160):

```markdown
**CRITICAL: No Source Reading Before Delegation**

This skill is a thin delegation wrapper. Between Stages 1-5, the skill MUST NOT read source files, grep the codebase, or use MCP tools. The only file the skill reads is the plan file (to extract the plan path and pass it to the subagent). All codebase exploration is the subagent's responsibility.
```

**2b. Add pre-delegation boundary section** (before the existing "Postflight Boundary" line at 434):

```markdown
## MUST NOT (Pre-Delegation Boundary)

Before invoking the subagent, this skill MUST NOT:

1. **Read source files** - Codebase exploration is the subagent's job
2. **Grep or Glob source directories** - Pattern search is the subagent's job
3. **Use MCP tools** - Domain tools are for subagent use only
4. **Parse plan content deeply** - Only extract plan_path and pass to subagent

The pre-delegation phase is LIMITED TO:
- Validating task exists and status allows implementation
- Updating status to "implementing"
- Creating marker file
- Reading plan path (NOT plan contents beyond validation)
- Constructing delegation context JSON
- Spawning subagent via Task tool
```

### Change 3: general-implementation-agent.md (1 insertion)

**3a. Add exclusive responsibility note to Stage 2** (after line 39):

```markdown
**Codebase Exploration Responsibility**

All source file reading, grepping, globbing, and MCP tool usage happens in this agent -- NOT in the delegating skill. The skill only passes the plan path; this agent is responsible for:
- Reading source files before modifying them
- Understanding existing code structure and patterns
- Running verification commands (build, test, lint)
- Using MCP tools for domain-specific operations

This separation ensures the delegating skill remains a thin wrapper that does not front-load work that belongs to the implementation agent.
```

### Optional Change 4: postflight-tool-restrictions.md (extend)

Add a brief "Pre-Delegation Restrictions" section to the existing standard document, establishing the principle alongside the postflight restrictions. This makes the constraint discoverable for future skill authors.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Constraints too restrictive: lead cannot read plan file adequately | Constraints explicitly allow reading the plan file; only source files are prohibited |
| Heuristic fallback in Stage 5 becomes useless | Clarify that file-overlap analysis uses paths from plan text, not source file contents |
| Future skills copy old pattern without constraint | Adding to postflight-tool-restrictions.md makes the pattern discoverable |

## Appendix

### Files to Modify

| File | Lines | Change Type |
|------|-------|-------------|
| `.claude/skills/skill-team-implement/SKILL.md` | ~219, ~266, ~662 | 3 insertions |
| `.claude/skills/skill-implementer/SKILL.md` | ~160, ~434 | 2 insertions |
| `.claude/agents/general-implementation-agent.md` | ~39 | 1 insertion |
| `.claude/context/standards/postflight-tool-restrictions.md` | end of file | 1 optional insertion |

### Pattern Reference

The "Pre-Delegation Boundary" mirrors the existing "Postflight Boundary" pattern from `postflight-tool-restrictions.md`. Both constrain what the skill can do outside of the agent's execution window:

```
[Skill Pre-Delegation] -> [Agent Execution] -> [Skill Postflight]
  No source reading         Full codebase        No source reading
  No grep/glob              access               No grep/glob
  No MCP tools              All tools             No MCP tools
  Plan text only            Build/test/verify     State mgmt only
```
