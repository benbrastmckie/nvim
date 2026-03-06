# Research Report: Task #158 (Follow-up)

**Task**: OC_158 - Ensure workflow command uniformity - prevent /research from failing to call research agent
**Started**: 2026-03-06T00:00:00Z
**Completed**: 2026-03-06T00:30:00Z
**Effort**: 1 hour
**Dependencies**: Task #159
**Sources/Inputs**:
- `specs/OC_158_ensure_workflow_command_uniformity_prevent_research_failure/reports/research-001.md` - Original research findings
- `specs/OC_159_require_planner_agent_for_plan_command/summaries/implementation-summary-20260306.md` - Task 159 implementation
- `.opencode/commands/research.md` - Current research command (post-159 changes)
- `.opencode/skills/skill-researcher/SKILL.md` - Current skill (post-159 changes)

**Artifacts**:
- `specs/OC_158_ensure_workflow_command_uniformity_prevent_research_failure/reports/research-002.md` (this report)

**Standards**: report-format.md

---

## Executive Summary

Task 159 ("Require planner agent for /plan command") substantially addresses task 158's core concern -- preventing /research from failing to delegate to the research agent. Task 159 added explicit DELEGATION REQUIREMENT blocks, EXECUTE NOW directives, FAILURE CONDITION language, and GATE OUT agent_type verification to the research command and skill-researcher. These changes directly target the delegation failure described in task 158.

However, task 159 used a **guardrail approach** (adding enforcement language) rather than the **structural approach** recommended by task 158's research (fixing step numbering, removing MCP dependency before delegation). Some structural issues remain unresolved but are effectively mitigated by the enforcement language.

**Recommendation**: Mark task 158 as **superseded** by task 159. The remaining structural issues (step numbering, MCP placement) are cosmetic/minor and do not warrant a separate task. They can be addressed opportunistically during future maintenance.

---

## Context & Scope

### Purpose of This Research

Task 158 was created to address intermittent failures where /research would conduct research inline (in the primary agent) instead of delegating to the research agent. Before this follow-up research began, task 159 was completed, which added explicit delegation enforcement to all workflow commands including /research.

This follow-up research determines whether task 159's implementation fully resolves task 158's concerns or whether additional work is needed.

---

## Findings

### 1. Original Issues from Research-001.md (Task 158)

The original research identified five issues:

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| 1 | Step numbering inconsistency | Medium | Steps go 1,2,3,5,6,7,8 (missing step 4, duplicate step 3) |
| 2 | MCP tool dependency before delegation | High | search_notes MCP call in step 5 could interrupt workflow |
| 3 | No explicit delegation guarantee | High | No language requiring delegation to occur |
| 4 | Pre-delegation complexity | Medium | Research has more steps than plan/implement |
| 5 | Plan.md also has step numbering gap | Low | Plan skips step 4 as well |

### 2. What Task 159 Addressed

Task 159 made changes to both `research.md` and `skill-researcher/SKILL.md`:

**In research.md**:
- Added DELEGATION REQUIREMENT section at step 6 (lines 113-124)
- Added language-based agent routing table (neovim vs general)
- Added EXECUTE NOW directive requiring Task tool invocation
- Added FAILURE CONDITION: "If the Task tool is not invoked... this command has FAILED"
- Added Step 7a-verify: GATE OUT agent_type verification (lines 148-174)

**In skill-researcher/SKILL.md**:
- Added EXECUTE NOW directive in Stage 3 (Delegate) (line 77)
- Added CRITICAL warning: "Do NOT conduct this research directly" (line 79)
- Added FAILURE CONDITION for skipped delegation (line 110)

### 3. Coverage Analysis: Issue by Issue

| # | Original Issue | Addressed by 159? | Status |
|---|----------------|-------------------|--------|
| 1 | Step numbering (1,2,3,5,6,7,8) | **No** | Still present in research.md |
| 2 | MCP dependency before delegation | **Partially** | MCP step still exists, but FAILURE CONDITION ensures delegation happens regardless |
| 3 | No explicit delegation guarantee | **Yes** | DELEGATION REQUIREMENT + EXECUTE NOW + FAILURE CONDITION added |
| 4 | Pre-delegation complexity | **No** (by design) | Not relevant -- enforcement approach doesn't require structural simplification |
| 5 | Plan.md step numbering gap | **No** | Still present in plan.md |

### 4. Effectiveness Assessment

**Issue 3 (No delegation guarantee)** was the root cause of the observed failure. The primary agent would sometimes process the research request itself instead of delegating. Task 159 directly addresses this with three layers of enforcement:

1. **Command-level**: DELEGATION REQUIREMENT block in research.md with EXECUTE NOW
2. **Skill-level**: CRITICAL + FAILURE CONDITION in skill-researcher/SKILL.md
3. **Verification**: GATE OUT agent_type check in Step 7a-verify

This is a robust solution. The enforcement language is clear, imperative, and redundant across multiple levels.

**Issues 1, 2, 4, 5 (structural)** are cosmetic or low-risk:

- **Step numbering** (issues 1, 5): The missing step 4 is a documentation artifact. The workflow executes correctly despite non-sequential numbering. The LLM follows step content, not step numbers.
- **MCP dependency** (issue 2): The MCP call is behind a `--remember` flag (optional) and has documented graceful degradation. Even if it fails, the FAILURE CONDITION from task 159 ensures delegation still occurs.
- **Pre-delegation complexity** (issue 4): This is inherent to the research command having a memory search feature. It does not cause delegation failures when proper enforcement language is present.

### 5. Remaining Gaps

The only gaps between task 158's recommendations and task 159's implementation are:

1. **Step renumbering**: Steps could be renumbered to be sequential (1-8). This is purely cosmetic.
2. **MCP call relocation**: The original research recommended moving the MCP search_notes call to the research agent instead of the command. This would be a minor structural improvement but is not necessary for correctness.
3. **Command template**: The original research suggested creating a standardized command template. This was not implemented but could be a future enhancement.

None of these gaps affect the correctness or reliability of delegation.

---

## Decisions

### Decision 1: Task 158 is Superseded by Task 159
**Decision**: Task 158 should be marked as superseded by task 159.

**Rationale**:
- The core problem (delegation failure) is fully addressed by task 159's enforcement language
- Remaining issues are cosmetic (step numbering) or low-risk (MCP placement)
- Implementing task 158's structural recommendations would provide marginal benefit over the enforcement approach
- The enforcement approach is actually more robust -- it works regardless of structural complexity

**Confidence**: High (90%)

### Decision 2: No Additional Implementation Needed
**Decision**: No implementation plan should be created for task 158.

**Rationale**:
- The enforcement language in task 159 is the industry-standard approach for LLM instruction following
- Step renumbering and MCP relocation can be done opportunistically during future edits
- Creating a separate task for cosmetic fixes would be over-engineering

**Confidence**: High (85%)

---

## Risks & Mitigations

### Risk 1: Enforcement Language May Not Be Sufficient Long-Term
**Likelihood**: Low
**Impact**: Medium
**Description**: As models evolve, the EXECUTE NOW / FAILURE CONDITION patterns may need updating.

**Mitigation**: Monitor delegation success rates. If failures recur, revisit structural recommendations from research-001.md.

### Risk 2: Step Numbering Confusion During Future Edits
**Likelihood**: Low
**Impact**: Low
**Description**: Future maintainers editing research.md may be confused by non-sequential step numbers.

**Mitigation**: Fix numbering opportunistically during next edit to research.md.

---

## Recommendations

### Immediate Action
1. **Mark task 158 as superseded by task 159** in state.json and TODO.md

### Optional Future Actions (No Separate Task Needed)
2. Fix step numbering in research.md (1,2,3,4,5,6,7,8) during next edit
3. Fix step numbering in plan.md during next edit
4. Consider moving MCP search_notes to the research agent if memory features are expanded

---

## Appendix

### Files Examined
- `specs/OC_158_ensure_workflow_command_uniformity_prevent_research_failure/reports/research-001.md`
- `specs/OC_159_require_planner_agent_for_plan_command/summaries/implementation-summary-20260306.md`
- `.opencode/commands/research.md` (current, post-159 changes)
- `.opencode/skills/skill-researcher/SKILL.md` (current, post-159 changes)

### Comparison: Task 158 Recommendations vs Task 159 Implementation

| Recommendation from 158 | Implemented in 159? | Notes |
|--------------------------|---------------------|-------|
| Fix step numbering in research.md | No | Cosmetic, not needed for correctness |
| Fix step numbering in plan.md | No | Cosmetic |
| Move MCP call to research agent | No | Mitigated by enforcement language |
| Standardize pre-delegation flow | Partially | Enforcement approach is different but effective |
| Add explicit delegation guarantee | **Yes** | DELEGATION REQUIREMENT + EXECUTE NOW |
| Add debugging output | **Yes** | GATE OUT verification with logging |
| Create command template | No | Nice-to-have, not blocking |
| Add workflow tests | No | Could be future work |

---

## End of Report

**Next Steps**:
1. Mark task 158 as superseded by task 159
2. No implementation plan needed
