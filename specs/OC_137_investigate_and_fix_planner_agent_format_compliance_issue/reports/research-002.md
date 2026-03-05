# Research Report: Task #137 - Follow-Up Analysis

**Task**: OC_137 - Investigate and fix planner-agent format compliance issue  
**Report**: research-002.md (Follow-up to research-001.md)  
**Date**: 2026-03-06  
**Status**: [COMPLETED]

---

## Executive Summary

**Root Cause Identified**: The planner-agent format non-compliance is caused by **multiple embedded non-compliant templates** throughout the system that override the correct context-injected format. The system has contradictory template sources, and the wrong ones are being used during plan generation.

**Key Finding**: The `/plan` command specification (plan.md) contains an embedded template that violates plan-format.md, and this template is being used instead of the correct planner-agent.md template. The OC_133 fix only addressed planner-agent.md but missed the embedded templates in command specifications.

---

## Investigation Results

### 1. Template Source Analysis

The system has **THREE sources** of plan templates:

| Source | Location | Status | Format Compliance |
|--------|----------|--------|-------------------|
| **plan-format.md** | `.opencode/context/core/formats/plan-format.md` | Reference standard | [COMPLIANT] |
| **planner-agent.md Stage 5** | `.opencode/agent/subagents/planner-agent.md` | Fixed in OC_133 | [COMPLIANT] |
| **plan.md embedded** | `.opencode/commands/plan.md` lines 71-125 | **NOT FIXED** | **[NON-COMPLIANT]** |

### 2. Non-Compliant Template Locations

#### A. `/plan` Command Specification (plan.md)
**Location**: `.opencode/commands/plan.md` lines 71-125

**Template excerpt showing violations**:
```markdown
## Phases                                    <- WRONG: should be "## Implementation Phases"

### Phase 1: <Name>

**Status**: [NOT STARTED]                    <- WRONG: status should be IN heading
**Estimated effort**: X hours                <- WRONG: should be "**Timing**"

**Objectives**:                              <- WRONG: should be "**Goal**"
1. <objective>

**Files to modify**:                         <- WRONG: not in phase format
- `path/to/file` - <what changes>

**Steps**:                                  <- WRONG: not in phase format
1. <step>

**Verification**:                            <- WRONG: not in phase format
- <how to verify this phase is done>

---                                          <- WRONG: separator not allowed
```

**Violations**:
1. Section named "## Phases" (should be "## Implementation Phases")
2. Separate "**Status**: [NOT STARTED]" line (should be in heading: "### Phase N: Name [NOT STARTED]")
3. "**Objectives**" field (should be "**Goal**")
4. "**Estimated effort**" field (should be "**Timing**")
5. Extra fields: **Files to modify**, **Steps**, **Verification** (not in format spec)
6. `---` separator between phases (not allowed per plan-format.md line 93)
7. Missing metadata fields: Effort, Dependencies, Research Inputs, Artifacts, Standards, Type
8. Wrong metadata structure: Version, Created, Language (not per plan-format.md)

#### B. `/revise` Command Flow
**Location**: `.opencode/commands/revise.md`

The `/revise` command:
- Routes directly to `planner-agent` without going through `skill-planner`
- Does NOT inject context (no `<context_injection>` block)
- Relies on planner-agent.md template alone
- Cannot use the embedded template from plan.md (different invocation)

**Invocation Path Comparison**:

| Flow | Path | Context Injection | Template Source |
|------|------|-------------------|-----------------|
| `/plan` | skill-planner -> planner-agent | plan-format.md injected | **Uses plan.md embedded template** [BUG] |
| `/revise` | revise -> planner-agent | NO context injection | Uses planner-agent.md Stage 5 |

### 3. Evidence from Plan Files

**Compliant Example (OC_135 implementation-002.md)**:
- Section: "## Implementation Phases" [CORRECT]
- Phase heading: "### Phase 1: Name [COMPLETED]" [CORRECT]
- Fields: **Goal**, **Tasks**, **Timing** [CORRECT]
- No separators [CORRECT]
- Full metadata block [CORRECT]

**Non-Compliant Example (OC_136 implementation-002.md)**:
- Section: "## Phases" [WRONG - matches plan.md template]
- Separate: "**Status**: [NOT STARTED]" [WRONG - matches plan.md template]
- Fields: **Objectives**, **Estimated effort** [WRONG - matches plan.md template]
- Has `---` separators [WRONG - matches plan.md template]
- Missing metadata fields [WRONG - matches plan.md template structure]

### 4. Why OC_133 Did Not Fully Fix the Issue

**OC_133 Implementation Summary** claimed:
> "Fixed planner-agent.md templates and verification to align with plan-format.md"

**What was actually fixed**:
- planner-agent.md Stage 5 template [FIXED]
- planner-agent.md Stage 6a verification [FIXED]
- planner-agent.md Critical Requirements [FIXED]

**What was NOT fixed**:
- plan.md embedded template [NOT FIXED - root cause]
- revise.md context injection [NOT ADDRESSED]
- Other command specifications with embedded templates

**Conclusion**: OC_133 fixed the agent specification but missed the command specification embedded templates that override the agent behavior.

### 5. Context Injection Failure Analysis

**skill-planner/SKILL.md** correctly has:
```yaml
<context_injection>
  <file path=".opencode/context/core/formats/plan-format.md" variable="plan_format" />
</context_injection>
```

**Delegation to planner-agent**:
```yaml
<stage id="3" name="Delegate">
  <action>Invoke planner-agent with injected context</action>
  - Call `Task` tool with `subagent_type="planner-agent"`
  - Prompt includes: {plan_format}
</stage>
```

**Problem**: Despite context injection, the embedded template in plan.md takes precedence or the agent falls back to it when uncertain about format requirements.

---

## Root Cause Conclusions

### Primary Root Cause: Embedded Non-Compliant Templates

The `/plan` command specification (plan.md) contains an embedded plan template that:
1. Predates plan-format.md standard
2. Was never updated when plan-format.md was created
3. Has all the format violations that appear in non-compliant plans
4. Overrides or takes precedence over context-injected format standards

### Secondary Root Cause: Context Injection Gaps

1. **No context injection in revise flow**: The `/revise` command bypasses skill-planner and calls planner-agent directly without injecting plan-format.md context.

2. **Agent may use embedded fallback**: When context injection fails or is unclear, the planner-agent appears to fall back to learned patterns from command specifications rather than its own Stage 5 template.

### Why OC_135 Was Compliant but OC_136 Was Not

| Factor | OC_135 | OC_136 |
|--------|--------|--------|
| Created via | `/plan` command | `/revise` command |
| Invocation | plan.md -> skill-planner -> planner-agent | revise.md -> planner-agent |
| Context injection | plan-format.md injected | NO context injection |
| Template available | plan.md embedded OR planner-agent.md | planner-agent.md only |
| Outcome | Compliant | Non-compliant |

**Hypothesis**: OC_135's plan was created by an earlier version of the system or through a different path that didn't trigger the embedded template bug. The compliance appears inconsistent based on which code path executes.

---

## Recommendations

### 1. Fix Embedded Templates (Priority: CRITICAL)

Update `.opencode/commands/plan.md`:
- Replace embedded template (lines 71-125) with plan-format.md compliant version
- Remove or correct the example plan structure
- Ensure embedded example matches the actual format specification

**Required changes**:
1. Change "## Phases" to "## Implementation Phases"
2. Move status marker into phase headings
3. Change "**Objectives**" to "**Goal**"
4. Change "**Estimated effort**" to "**Timing**"
5. Remove extra phase fields (Files to modify, Steps, Verification)
6. Remove `---` separators
7. Add full metadata block per plan-format.md line 13-27

### 2. Add Context Injection to Revise Flow (Priority: HIGH)

Update `.opencode/commands/revise.md`:
- Add `<context_injection>` block for plan-format.md
- OR route through skill-planner instead of direct planner-agent invocation
- Ensure all plan creation paths inject format context

### 3. Add Template Verification (Priority: MEDIUM)

Create a validation script that:
- Checks all command specifications for embedded templates
- Verifies templates match plan-format.md
- Runs in CI/CD to prevent non-compliant templates from being committed

### 4. Strengthen Agent Verification (Priority: MEDIUM)

Enhance planner-agent.md Stage 6a:
- Add stronger language: "MUST reject plan if format doesn't match"
- Add explicit check: "Verify plan does NOT use embedded template from command spec"
- Add logging: "Log which template source was used for debugging"

### 5. Remove Embedded Templates (Priority: LOW)

Long-term architectural fix:
- Remove all embedded templates from command specifications
- Only reference external templates (planner-agent.md)
- Ensure single source of truth for all templates

---

## Risks & Considerations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Changing plan.md template breaks existing plan generation | High | Medium | Test thoroughly with multiple tasks before deploying |
| Other commands have similar embedded templates | Medium | High | Audit all command specs for embedded templates |
| Agents may still use learned patterns from old templates | Medium | Medium | Add explicit format verification that rejects non-compliant output |
| Context injection may still fail intermittently | Medium | Low | Add fallback template selection logic in planner-agent |
| Multiple template sources create confusion | Low | High | Document template hierarchy and precedence clearly |

---

## Next Steps

1. **Create implementation plan** for fixing embedded templates (run `/plan OC_137`)
2. **Audit all command specifications** for other embedded templates
3. **Fix plan.md** embedded template to match plan-format.md
4. **Add context injection** to revise.md flow
5. **Test both /plan and /revise** commands with new templates
6. **Verify** all future plans follow format specification

---

## References

- **Original Research**: `specs/OC_137_investigate_and_fix_planner_agent_format_compliance_issue/reports/research-001.md`
- **plan-format.md**: `.opencode/context/core/formats/plan-format.md`
- **planner-agent.md**: `.opencode/agent/subagents/planner-agent.md`
- **plan.md**: `.opencode/commands/plan.md` (contains non-compliant embedded template)
- **revise.md**: `.opencode/commands/revise.md` (lacks context injection)
- **skill-planner**: `.opencode/skills/skill-planner/SKILL.md`
- **OC_133 Summary**: `specs/OC_133_fix_planner_agent_not_following_plan_format_specification/summaries/implementation-summary-20260304.md`
- **Compliant Example**: `specs/OC_135_enforce_workflow_command_delegation_to_prevent_direct_implementation/plans/implementation-002.md`
- **Non-Compliant Example**: `specs/OC_136_design_and_implement_remember_command_for_intelligent_memory_management/plans/implementation-002.md`

---

## Final Conclusion

The planner-agent format compliance issue is caused by **multiple template sources with conflicting formats**. While OC_133 fixed the planner-agent.md specification, it missed the embedded template in the `/plan` command specification (plan.md) which contains all the same format violations seen in non-compliant plans.

**To fix this issue**:
1. Update plan.md's embedded template to match plan-format.md
2. Add context injection to the revise flow
3. Consider removing embedded templates entirely to ensure single source of truth

The system is working as designed (context injection, proper templates) but the design includes contradictory template sources that override the intended behavior.
