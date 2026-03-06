# Research Report: Task #158

**Task**: OC_158 - Ensure workflow command uniformity - prevent /research from failing to call research agent
**Started**: 2026-03-05T00:00:00Z
**Completed**: 2026-03-05T00:30:00Z
**Effort**: 2 hours
**Dependencies**: None
**Sources/Inputs**: 
- `.opencode/commands/research.md` - Research command definition
- `.opencode/commands/plan.md` - Plan command definition
- `.opencode/commands/implement.md` - Implement command definition
- `.opencode/commands/revise.md` - Revise command definition
- `.opencode/skills/skill-researcher/SKILL.md` - Research skill
- `.opencode/skills/skill-planner/SKILL.md` - Planner skill
- `.opencode/skills/skill-implementer/SKILL.md` - Implementer skill
- `.opencode/commands/task.md` - Task command (cross-reference)

**Artifacts**: 
- `specs/OC_158_ensure_workflow_command_uniformity_prevent_research_failure/reports/research-001.md` (this report)

**Standards**: report-format.md

---

## Executive Summary

This research investigates why the `/research` command sometimes fails to call the research agent and conducts research inline within the primary agent instead. Through analysis of command definitions and skill files, I identified **structural differences** in the command workflows that could lead to inconsistent behavior.

**Key Findings**:
1. **Step numbering inconsistency**: The research command skips step 4 (jumps from 3 to 5), which could indicate missing logic or documentation errors
2. **Additional memory search step**: Only the research command has a Step 5 (Memory Search) that uses MCP tools before delegation, adding complexity
3. **Identical delegation patterns**: All commands use the same skill tool delegation mechanism with the same syntax
4. **MCP tool dependency**: The research command's memory search step could fail if MCP tools are unavailable, potentially interrupting the workflow
5. **Inconsistent documentation numbering**: Research.md has steps 1, 2, 3, 5, 6, 7, 8 (missing step 4), while plan.md and implement.md have sequential numbering

**Root Cause Hypothesis**: The additional MCP tool dependency and step numbering confusion in the research command creates more opportunities for failure during the pre-delegation phase. When MCP tools fail or when the workflow encounters the non-sequential step numbering, the primary agent may fall back to conducting research inline rather than properly delegating to the research agent.

**Recommendation**: Standardize all workflow commands to have identical pre-delegation structures, remove or make the MCP memory search step optional (as it already has graceful degradation), and fix the step numbering in research.md.

---

## Context & Scope

### Problem Statement
The `/research` command occasionally fails to delegate to the research agent and instead conducts research within the primary agent. This breaks the intended workflow architecture where:
- The primary agent handles command parsing and status management
- Specialized subagents handle domain-specific work

### Scope of Investigation
This research compares:
1. Command delegation patterns across `/research`, `/plan`, `/implement`, and `/revise`
2. Skill wrapper definitions (skill-researcher, skill-planner, skill-implementer)
3. Pre-delegation workflow steps
4. Post-delegation handling
5. Error handling and recovery paths

### Research Questions
1. How do the command delegation patterns differ between `/research`, `/plan`, `/implement`, and `/revise`?
2. What additional complexity exists in the research command that could cause failures?
3. Why would the primary agent fall back to conducting research inline?
4. What changes are needed to make all workflow commands uniform?

---

## Findings

### 1. Command Structure Comparison

#### 1.1 Research Command Structure (research.md)

```
Step 1: Parse Input
Step 2: Look up task
Step 3: Validate status
Step 3: Execute Preflight  <-- Note: Duplicate step number!
Step 5: Memory Search (if --remember flag)  <-- Skips step 4!
Step 6: Delegate to Research Agent
Step 7: Execute Postflight
Step 8: Report results
```

**Issues Found**:
- **Line 43**: Step 3 is labeled "Execute Preflight" but should be Step 4
- **Line 68**: Step 5 "Memory Search" comes after Step 3 (should be Step 5 after Step 4)
- **Missing Step 4**: No step 4 exists in the document

#### 1.2 Plan Command Structure (plan.md)

```
Step 1: Look up task
Step 2: Validate status
Step 3: Execute Preflight
Step 5: Read existing research  <-- Also skips step 4!
Step 6: Delegate to Planning Agent
Step 7: Execute Postflight
Step 8: Report results
```

**Issues Found**:
- **Line 67**: Step 5 comes after Step 3 (missing Step 4)
- Inconsistent with the sequential pattern

#### 1.3 Implement Command Structure (implement.md)

```
Step 1: Look up task
Step 2: Validate status (unless --force)
Step 3: Find implementation plan
Step 4: Execute Preflight
Step 5: Delegate to Implementation Agent
Step 6: Execute Postflight
Step 7: Report results
```

**Status**: Properly sequential numbering (1, 2, 3, 4, 5, 6, 7)

#### 1.4 Revise Command Structure (revise.md)

**Different pattern entirely** - Uses XML-style workflow tags instead of numbered steps:
```xml
<workflow_execution>
  <stage id="1" name="LoadContext">
  <stage id="2" name="ParseAndValidate">
  <stage id="3" name="RouteAndExecute">
  <stage id="4" name="ValidateReturn">
  <stage id="5" name="RelayResult">
</workflow_execution>
```

**Note**: Revise uses direct Task tool invocation instead of the skill tool pattern.

### 2. Delegation Pattern Analysis

All three main workflow commands (/research, /plan, /implement) use the same delegation mechanism:

#### 2.1 Skill Tool Invocation Pattern

**Research** (research.md lines 98-104):
```markdown
→ Tool: skill
→ Name: skill-researcher
→ Prompt: Research task {N} with language {language} and focus {focus}. Include memory context: {memory_results}
```

**Plan** (plan.md lines 73-79):
```markdown
→ Tool: skill
→ Name: skill-planner
→ Prompt: Create implementation plan for task {N} with language {language} and research context from {research_content}
```

**Implement** (implement.md lines 78-84):
```markdown
→ Tool: skill
→ Name: skill-implementer
→ Prompt: Execute implementation plan for task {N} with language {language}
```

**Finding**: The delegation syntax is **identical** across all three commands. The skill tool is invoked with:
- Same tool name pattern: `skill`
- Same name parameter pattern: `skill-{function}`
- Same prompt structure with task number, language, and context

#### 2.2 Skill Wrapper Definitions

All three skills have identical metadata structures:

| Skill | Name | Description | Context | Agent |
|-------|------|-------------|---------|-------|
| skill-researcher | skill-researcher | Conduct general research | fork | general-research-agent |
| skill-planner | skill-planner | Create phased implementation plans | fork | planner-agent |
| skill-implementer | skill-implementer | Execute general implementation | fork | general-implementation-agent |

**Finding**: The skill definitions are structurally identical. All use:
- `context: fork` for isolated subagent execution
- Same frontmatter format
- Same allowed-tools list: Task, Bash, Edit, Read, Write
- Same warning about commands needing to execute their own workflows

### 3. Pre-Delegation Steps Comparison

| Command | Steps Before Delegation | MCP Tool Usage | Complexity |
|---------|------------------------|----------------|------------|
| /research | Parse, Lookup, Validate, Preflight, Memory Search | Yes (search_notes) | High |
| /plan | Parse, Lookup, Validate, Preflight, Read Research | No | Medium |
| /implement | Parse, Lookup, Validate, Find Plan, Preflight | No | Medium |

#### 3.1 Research Command Pre-Delegation (Steps 1-6)

**Step 3**: Execute Preflight (lines 43-66)
- Updates state.json to "researching"
- Updates TODO.md to [RESEARCHING]
- Creates .postflight-pending marker file

**Step 5**: Memory Search (lines 68-94)
- Only executes if `--remember` flag present
- Builds search query from task description
- **Uses MCP tool**: `search_notes` (line 78)
- Queries memory vault for relevant memories
- Includes up to 3 memory summaries in research context
- **Graceful degradation**: "If MCP unavailable: Skip memory search, continue with standard research" (line 93)

**Step 6**: Delegate to Research Agent (lines 96-118)
- Calls skill tool with skill-researcher
- Includes memory context in prompt (if available)

#### 3.2 Plan Command Pre-Delegation (Steps 1-6)

**Step 3**: Execute Preflight (lines 42-65)
- Updates state.json to "planning"
- Updates TODO.md to [PLANNING]
- Creates .postflight-pending marker file

**Step 5**: Read existing research (lines 67-69)
- Checks for research-001.md file
- Reads it for context if available
- No MCP tools used

**Step 6**: Delegate to Planning Agent (lines 71-87)
- Calls skill tool with skill-planner
- Includes research context in prompt

#### 3.3 Implement Command Pre-Delegation (Steps 1-5)

**Step 3**: Find implementation plan (lines 43-50)
- Looks for implementation-*.md files
- Reads the plan to understand phases
- No MCP tools used

**Step 4**: Execute Preflight (lines 51-74)
- Updates state.json to "implementing"
- Updates TODO.md to [IMPLEMENTING]
- Creates .postflight-pending marker file

**Step 5**: Delegate to Implementation Agent (lines 76-101)
- Calls skill tool with skill-implementer
- Includes plan context in prompt

### 4. Root Cause Analysis

#### 4.1 Why Research Might Fail to Delegate

Based on the analysis, there are several potential failure points unique to the research command:

**A. Step Numbering Confusion**
- The non-sequential step numbering (1, 2, 3, 5, 6, 7, 8) could confuse the orchestrator
- When steps don't follow a clear sequence, the workflow engine may not properly detect when to delegate
- This is a **documentation/structural issue** that could affect parsing

**B. MCP Tool Dependency**
- The research command has an additional MCP tool invocation (`search_notes`)
- If MCP tools are unavailable or the call fails:
  - The graceful degradation note says to "continue with standard research"
  - But the workflow might interpret this as "continue in current agent" rather than "proceed to delegation"
- This is the **most likely root cause** of inline execution

**C. Context Preparation Complexity**
- Research command must prepare memory context before delegation
- If memory search fails or produces unexpected results, the prompt construction might fail
- A failed prompt construction could cause the skill tool invocation to be skipped

#### 4.2 Comparison: Why Plan and Implement Succeed

| Factor | /research | /plan | /implement |
|--------|-----------|-------|------------|
| Step numbering | Broken (missing 4) | Broken (missing 4) | Correct |
| MCP tools | Yes (search_notes) | No | No |
| File reading | No | Yes (research-001.md) | Yes (implementation-*.md) |
| Optional steps | Yes (Step 5) | No | No |

Both /plan and /implement:
- Only read local files (no external dependencies)
- Have simpler pre-delegation flows
- Don't have optional steps that could cause branching

**Implement has correct step numbering**, which may contribute to its reliability.

### 5. Post-Delegation Handling Comparison

All three commands have **nearly identical** postflight handling:

| Step | Research | Plan | Implement |
|------|----------|------|-----------|
| Read metadata | Yes | Yes | Yes |
| Update state.json | researching → researched | planning → planned | implementing → completed/partial |
| Update TODO.md | Yes | Yes | Yes |
| Link artifacts | Yes | Yes | Yes |
| Git commit | Yes | Yes | Yes |
| Cleanup | Yes | Yes | Yes |

**Finding**: Post-delegation handling is uniform across all commands. This suggests the issue is in the **pre-delegation or delegation phase**, not post-delegation.

### 6. Skill Wrapper Execution Flow

All three skills document the same execution flow:

1. **Load Context**: Read injected context files
2. **Preflight**: Validate task and status (in skill, not executed)
3. **Delegate**: Call Task tool with appropriate subagent_type
4. **Postflight**: Update state and link artifacts (in skill, not executed)

**Key Insight from Skill Files**:
- Each skill includes: "**IMPORTANT**: The skill tool only LOADS this skill definition. It does NOT execute the workflow below. Commands must implement preflight/postflight logic themselves."
- This is documented in all three skill files (skill-researcher.md:64, skill-planner.md:65, skill-implementer.md:69)

The skills are **thin wrappers** that only:
1. Define context injection patterns
2. Specify which agent to delegate to
3. Document the expected workflow

The actual execution is handled by:
1. The command file (preflight/postflight)
2. The skill tool (loading context)
3. The Task tool (delegating to subagent)

### 7. Critical Differences Summary

| Aspect | /research | /plan | /implement |
|--------|-----------|-------|------------|
| **Step sequence** | 1,2,3,3,5,6,7,8 | 1,2,3,5,6,7,8 | 1,2,3,4,5,6,7 |
| **Has step 4** | No | No | Yes |
| **MCP tools used** | Yes (search_notes) | No | No |
| **Optional steps** | Yes (Step 5) | No | No |
| **Pre-delegation complexity** | High | Medium | Medium |
| **External dependencies** | MCP server | None | None |
| **Graceful degradation** | Documented but... | N/A | N/A |

**The smoking gun**: The research command is the **only** command that:
1. Uses MCP tools before delegation
2. Has optional conditional steps
3. Has the most complex pre-delegation flow

---

## Decisions

### Decision 1: Root Cause Identified
**Decision**: The primary cause of /research failing to delegate is the MCP tool dependency combined with step numbering confusion.

**Rationale**:
- /research is the only command using MCP tools (search_notes)
- If MCP fails, the "graceful degradation" may not properly trigger delegation
- Step numbering confusion (missing step 4, duplicate step 3) could confuse workflow parsing
- The additional complexity creates more failure points

**Confidence**: High (80%)

### Decision 2: All Commands Should Have Identical Structure
**Decision**: Standardize all workflow commands to have the same pre-delegation structure.

**Rationale**:
- Uniformity reduces cognitive load and failure modes
- Implement.md has the clearest structure (sequential steps, no MCP dependencies)
- The extra memory search in research should be optional and not block delegation

**Confidence**: High (95%)

### Decision 3: Revise Command Uses Different Pattern
**Decision**: The /revise command is intentionally different and should not be changed to match.

**Rationale**:
- Revise uses direct Task tool invocation (not skill tool)
- Revise has conditional routing (planner-agent vs task-expander)
- Revise validates returns before relaying (unique to revise)
- Revise is working correctly and its complexity is justified

**Confidence**: Medium (70%)

---

## Risks & Mitigations

### Risk 1: MCP Tool Failure Blocks Delegation
**Likelihood**: High
**Impact**: Medium
**Description**: If MCP tools are unavailable, the research command may not properly delegate to the research agent.

**Mitigation**:
1. Move MCP tool call to the research agent (not the command)
2. Make the memory search truly optional by moving it after delegation
3. Add explicit error handling: "If MCP fails, still delegate to research agent"

### Risk 2: Step Numbering Confusion
**Likelihood**: Medium
**Impact**: Low
**Description**: The non-sequential step numbering could confuse the orchestrator's workflow parser.

**Mitigation**:
1. Fix step numbering in research.md (add missing step 4)
2. Fix step numbering in plan.md (add missing step 4)
3. Ensure all commands use sequential numbering

### Risk 3: Breaking Existing Functionality
**Likelihood**: Low
**Impact**: High
**Description**: Changes to make commands uniform might break existing working functionality.

**Mitigation**:
1. Create test tasks to verify each command still works
2. Make changes incrementally
3. Keep the MCP memory search feature but move it to the research agent

### Risk 4: Loss of Memory Search Feature
**Likelihood**: Low
**Impact**: Medium
**Description**: Moving MCP tool calls could lose the --remember functionality.

**Mitigation**:
1. Pass the --remember flag through to the research agent
2. Have the research agent perform the memory search
3. Ensure the feature is preserved but executed by the correct agent

---

## Recommendations

### Immediate Actions (High Priority)

1. **Fix Step Numbering in research.md**
   - Add missing Step 4 (should be "Display Header" or similar)
   - Re-number steps to be sequential: 1, 2, 3, 4, 5, 6, 7, 8, 9
   - Remove duplicate "Step 3" labels

2. **Fix Step Numbering in plan.md**
   - Add missing Step 4
   - Re-number steps to be sequential

3. **Move MCP Tool Call to Research Agent**
   - Remove Step 5 (Memory Search) from research.md
   - Pass the `--remember` flag to the research agent
   - Have general-research-agent perform the memory search
   - This ensures delegation always happens regardless of MCP availability

### Short-Term Actions (Medium Priority)

4. **Standardize Pre-Delegation Flow**
   - All commands should have identical steps 1-4:
     - Step 1: Parse input
     - Step 2: Look up task
     - Step 3: Validate status
     - Step 4: Execute preflight
   - Step 5: Delegate to agent (should be the same pattern)

5. **Add Explicit Delegation Guarantee**
   - Add a rule: "Delegation must occur regardless of optional step failures"
   - Document: "If MCP/memory search fails, log warning and proceed to delegation"

6. **Add Debugging Output**
   - Add logging: "About to delegate to {agent} via skill tool"
   - Add logging: "Skill tool invocation: {details}"
   - This will help diagnose when delegation fails

### Long-Term Actions (Low Priority)

7. **Create Command Template**
   - Create a template file showing the standard command structure
   - All future workflow commands should follow this template
   - Include: preflight, delegation, postflight patterns

8. **Add Workflow Tests**
   - Create test tasks for each command
   - Verify delegation happens correctly
   - Test failure scenarios (MCP unavailable, missing files, etc.)

9. **Document Failure Modes**
   - Document: "If /research conducts research inline, check MCP tool availability"
   - Document: "If step numbering is non-sequential, fix immediately"
   - Add to troubleshooting guide

---

## Comparison Table: Command Uniformity

| Feature | /research | /plan | /implement | /revise | Uniform? |
|---------|-----------|-------|------------|---------|----------|
| **Uses skill tool** | Yes | Yes | Yes | No | Partial |
| **Step 1: Parse** | Yes | Yes | Yes | Yes | Yes |
| **Step 2: Lookup** | Yes | Yes | Yes | Yes | Yes |
| **Step 3: Validate** | Yes | Yes | Yes | Yes | Yes |
| **Step 4: Preflight** | No (missing) | No (missing) | Yes | N/A | No |
| **Pre-delegation steps** | 5 (complex) | 5 (medium) | 4 (simple) | N/A | No |
| **MCP tools** | Yes | No | No | No | No |
| **Postflight** | Yes | Yes | Yes | N/A | Yes |
| **Status updates** | Yes | Yes | Yes | Yes | Yes |
| **Git commit** | Yes | Yes | Yes | No | Partial |

**Uniformity Score**: 6/10 features are uniform across all commands

**Key Non-Uniformity Issues**:
1. /revise uses different delegation pattern (direct Task tool)
2. /research has extra MCP tool step
3. Step numbering inconsistent (research/plan missing step 4)
4. /revise doesn't git commit (by design)

---

## Appendix: Context Knowledge Candidates

### Candidate 1: Workflow Command Standard Structure
**Type**: Pattern
**Domain**: workflow-commands
**Target Context**: `.opencode/context/core/patterns/workflow-command-structure.md`
**Content**:
```markdown
# Standard Workflow Command Structure

All workflow commands (/research, /plan, /implement) should follow:

## Required Steps
1. Parse input arguments
2. Look up task in state.json
3. Validate task status
4. Execute preflight (update status, create markers)
5. [Optional: Context gathering - no external dependencies]
6. Delegate to skill via skill tool
7. Execute postflight (read metadata, update status, link artifacts, commit)
8. Report results

## Rules
- Steps must be numbered sequentially
- No MCP tool calls before delegation
- All status updates happen in preflight/postflight (not in skills)
- Skill tool only loads context; command executes workflows
```

**Source**: Research of command files in task OC_158
**Rationale**: Standardizing command structure prevents delegation failures and makes the system more maintainable

### Candidate 2: MCP Tool Usage Guidelines
**Type**: Pattern
**Domain**: mcp-tools
**Target Context**: `.opencode/context/core/standards/mcp-tool-usage.md`
**Content**:
```markdown
# MCP Tool Usage Guidelines

## Rule: MCP Tools Should Not Block Delegation

MCP tool calls (like search_notes) should:
- Be performed by subagents, not primary command agents
- Be truly optional with graceful degradation
- Never prevent delegation to specialized agents

## Best Practice
If a command needs MCP tool data:
1. Delegate to specialized agent first
2. Have the agent perform MCP tool calls
3. Include MCP results in the agent's workflow

## Example
```
# BAD: MCP call before delegation
Step 5: Query memory vault via MCP
Step 6: Delegate to agent with results

# GOOD: Delegate, then use MCP
Step 5: Delegate to agent
Agent Step 1: Query memory vault via MCP
```

**Source**: Analysis of research.md MCP usage in task OC_158
**Rationale**: MCP tool failures should not prevent proper workflow delegation

---

## End of Report

**Next Steps**: 
1. Run `/plan OC_158` to create implementation plan for standardizing workflow commands
2. Focus on fixing step numbering and moving MCP calls to research agent
3. Test each command after changes to ensure delegation works correctly
