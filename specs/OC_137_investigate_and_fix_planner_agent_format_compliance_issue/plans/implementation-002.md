# Implementation Plan: Remove Embedded Templates, Strengthen Context Injection, and Optimize Progressive Disclosure [REVISED]

- **Task**: OC_137 - investigate_and_fix_planner_agent_format_compliance_issue
- **Status**: [NOT STARTED]
- **Effort**: 10 hours (increased from 6 hours to cover progressive disclosure optimization)
- **Dependencies**: None
- **Research Inputs**: 
  - specs/OC_137_investigate_and_fix_planner_agent_format_compliance_issue/reports/research-001.md - Context injection issues
  - specs/OC_137_investigate_and_fix_planner_agent_format_compliance_issue/reports/research-002.md - Embedded templates root cause
  - specs/OC_137_investigate_and_fix_planner_agent_format_compliance_issue/reports/research-003.md - Progressive disclosure optimization
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**: 
  - .opencode/context/core/formats/plan-format.md
  - .opencode/context/core/standards/status-markers.md
  - .opencode/context/core/standards/documentation-standards.md
  - .opencode/context/core/standards/task-management.md
  - .opencode/docs/guides/context-loading-best-practices.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This revised implementation plan addresses all findings from the three research reports. It removes non-compliant embedded templates, strengthens context injection mechanisms, and implements progressive disclosure optimizations to prevent context bloat while maintaining system reliability.

**Core Strategy**: 
1. **Remove embedded templates** - Ensure single source of truth in context files
2. **Strengthen context injection** - Ensure planner-agent always receives correct format context
3. **Optimize progressive disclosure** - Implement tiered, surgical context loading exactly when needed

**Approach**: Surgical precision over abundance - inject context exactly where needed rather than loading everything upfront.

## Goals & Non-Goals

**Goals**:
- Remove non-compliant embedded plan template from plan.md (lines 71-125)
- Audit and remove embedded templates from other command specifications
- Add context injection to revise.md (route through skill-planner or add <context_injection>)
- Enhance planner-agent.md with discovery-layer pattern and context prioritization
- Implement conditional status-marker injection (remove from non-transition skills)
- Optimize context loading for surgical precision - exactly when needed, not in abundance
- Add stage-progressive loading demonstration in skill-planner
- Test both /plan and /revise commands for format compliance
- Document progressive disclosure best practices

**Non-Goals**:
- Modifying plan-format.md standard
- Changing planner-agent.md Stage 5 template structure (already compliant)
- Removing status-markers from skills that DO perform status transitions
- Creating new commands or skills
- Modifying existing plan files (only affects future plans)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing embedded template breaks plan generation entirely | High | Low | Ensure planner-agent.md has robust fallback and context injection is working |
| Context injection still fails intermittently | High | Medium | Add multiple fallback layers and explicit error logging |
| Progressive disclosure causes agents to miss critical context | Medium | Low | Maintain Push model for truly critical context; add explicit stage-by-stage instructions |
| Other commands have embedded templates not found during audit | Medium | High | Comprehensive audit of all command specs |
| Removing status-markers from skills breaks their functionality | Low | Low | Only remove from read-only skills (learn, refresh); verify each skill's needs before removal |
| Changes affect non-planning commands | Low | Low | Scope changes to plan-related files only |
| Context budget enforcement is too restrictive | Low | Medium | Start with guidelines, not hard limits; measure before enforcing |

## Implementation Phases

### Phase 1: Remove Embedded Template from plan.md [NOT STARTED]

**Goal**: Remove the non-compliant embedded plan template from the /plan command specification

**Tasks**:
- [ ] Read current plan.md lines 71-125 (embedded template section)
- [ ] Remove the embedded plan template example (lines 71-125)
- [ ] Replace with reference to external templates only
- [ ] Update Step 6 to reference planner-agent.md and plan-format.md instead of showing template
- [ ] Add explicit instruction: "Do NOT use embedded templates - always reference plan-format.md via context injection"
- [ ] Verify plan.md still has clear instructions for plan creation without embedded template

**Files to Modify**:
- `.opencode/commands/plan.md` - Remove embedded template (lines 71-125), update Step 6

**Verification**:
- [ ] plan.md no longer contains embedded plan template
- [ ] plan.md still references correct standards and agents
- [ ] No syntax errors in modified file
- [ ] Clear instruction against embedded templates present

**Timing**: 1 hour

### Phase 2: Audit All Command Specifications for Embedded Templates [NOT STARTED]

**Goal**: Identify all command specifications that may contain embedded plan templates

**Tasks**:
- [ ] Search all `.opencode/commands/*.md` files for embedded plan templates
- [ ] Look for patterns: "## Phases", "**Status**: [NOT STARTED]", "**Objectives**:", "**Estimated effort**:"
- [ ] Check for any markdown blocks showing plan structures
- [ ] Check for any embedded skill templates or agent definitions
- [ ] Document findings with file paths and line numbers
- [ ] Create list of files requiring template removal

**Files to Examine**:
- `.opencode/commands/*.md` (all command specs)

**Verification**:
- [ ] Complete audit report showing all embedded templates found
- [ ] List of files and line numbers to modify
- [ ] No embedded templates remain undetected

**Timing**: 1.5 hours

### Phase 3: Remove Embedded Templates from Other Commands [NOT STARTED]

**Goal**: Remove any additional embedded plan templates found during audit

**Tasks**:
- [ ] For each file identified in Phase 2:
  - Read the embedded template section
  - Remove or replace with reference to external specs
  - Ensure command still has clear instructions
- [ ] Update any command that shows plan examples to reference plan-format.md
- [ ] Verify all modified files have no syntax errors

**Files to Modify**:
- (TBD based on Phase 2 audit results)

**Verification**:
- [ ] All identified embedded templates removed
- [ ] Commands still function correctly
- [ ] No syntax errors in any modified files

**Timing**: 1.5 hours

### Phase 4: Add Context Injection to Revise Flow [NOT STARTED]

**Goal**: Ensure /revise command properly injects plan-format.md context when calling planner-agent

**Research Finding**: This is the HIGHEST priority fix - currently /revise produces non-compliant plans because it lacks context injection.

**Two Implementation Options**:

**Option A - Route through skill-planner (RECOMMENDED)**:
- Modify revise.md to route planning revisions through skill-planner instead of directly to planner-agent
- This ensures consistent context injection via existing skill-planner infrastructure
- Pros: Single source of truth for planning context, consistent with /plan command
- Cons: Slightly more complex routing logic

**Option B - Add context_injection to revise.md**:
- Add `<context_injection>` block directly to revise.md
- Inject plan-format.md and status-markers.md
- Pros: Direct and explicit
- Cons: Duplicates context injection logic from skill-planner

**Tasks**:
- [ ] Read current revise.md routing section (lines 93-133)
- [ ] Choose implementation approach (recommend Option A)
- [ ] Implement chosen approach:
  - Option A: Modify routing to use skill-planner for plan revisions
  - Option B: Add <context_injection> block with plan-format.md
- [ ] Update delegation to planner-agent to include context
- [ ] Document the chosen approach in revise.md
- [ ] Add fallback: If context injection fails, agent must load @.opencode/context/core/formats/plan-format.md directly

**Files to Modify**:
- `.opencode/commands/revise.md` - Add context injection or route through skill-planner

**Verification**:
- [ ] revise.md has working context injection
- [ ] /revise path injects plan-format.md
- [ ] Planner-agent receives context in both /plan and /revise flows
- [ ] Revised plans follow plan-format.md specification

**Timing**: 1.5 hours (increased from 1 hour due to routing decision complexity)

### Phase 5: Strengthen Context Injection in planner-agent.md [NOT STARTED]

**Goal**: Enhance planner-agent.md to prioritize context-injected files and implement discovery-layer pattern

**Research Finding**: Implement discovery-layer pattern - give agents awareness of available context without loading everything.

**Tasks**:
- [ ] Update Stage 5 introduction to emphasize using injected context
- [ ] Add explicit instruction: "MUST use plan_format context, NOT embedded templates"
- [ ] Add fallback logic: "If plan_format not injected, load @.opencode/context/core/formats/plan-format.md directly"
- [ ] **Implement Discovery-Layer Pattern**:
  - Replace "Always Load" / "Load When Creating" sections
  - Create "Context Discovery Index" listing available context files
  - Specify when to load each: "Load X when performing Y operation"
  - Example: "@.opencode/context/core/formats/plan-format.md - Load when creating/revising plans"
- [ ] Update Critical Requirements section with stronger language about context priority
- [ ] Add verification step: "Check which template source was used and log it"
- [ ] Add instruction: "Never use embedded templates from command specifications"

**Files to Modify**:
- `.opencode/agent/subagents/planner-agent.md` - Stage 5, Stage 6a, Critical Requirements, Context References

**Verification**:
- [ ] planner-agent.md explicitly prioritizes context injection
- [ ] Discovery-layer pattern implemented (context awareness without bloat)
- [ ] Clear fallback mechanism documented
- [ ] Verification checks template source
- [ ] Explicit rejection of embedded templates

**Timing**: 1.5 hours (increased from 1 hour due to discovery-layer implementation)

### Phase 6: Implement Conditional Status-Marker Injection [NOT STARTED]

**Goal**: Remove status-markers.md from skills that don't perform status transitions

**Research Finding**: 4 skills inject status-markers.md unnecessarily, wasting ~400 lines of context.

**Skills to Modify** (remove status-markers.md from context_injection):
- `skill-learn` - Reads tags, doesn't transition status
- `skill-refresh` - Cleanup operations, status unchanged
- `skill-status-sync` - Synchronizes existing status, doesn't transition
- `skill-git-workflow` - Git operations, separate from task status

**Skills to KEEP status-markers.md** (perform status transitions):
- `skill-researcher` - not_started -> researching -> researched
- `skill-planner` - researched -> planning -> planned
- `skill-implementer` - planned -> implementing -> completed
- `skill-meta` - Depends on operation, may transition status
- `skill-orchestrator` - May transition status

**Tasks**:
- [ ] Read each skill's SKILL.md to verify it doesn't transition status
- [ ] Remove `<file path="...status-markers.md"...>` from context_injection blocks
- [ ] Update skill documentation to reflect context changes
- [ ] Verify skills still function correctly (they should - status is checked in preflight)

**Files to Modify**:
- `.opencode/skills/skill-learn/SKILL.md`
- `.opencode/skills/skill-refresh/SKILL.md`
- `.opencode/skills/skill-status-sync/SKILL.md`
- `.opencode/skills/skill-git-workflow/SKILL.md`

**Verification**:
- [ ] status-markers.md removed from 4 non-transition skills
- [ ] Each skill's SKILL.md updated
- [ ] Skills still validate status correctly in preflight (may need to load status-markers there instead)
- [ ] **CRITICAL**: Test that skills can still check status without injected context

**Timing**: 1 hour

**Note**: If removing status-markers breaks status validation, consider loading it only in Preflight stage rather than full injection.

### Phase 7: Demonstrate Stage-Progressive Loading [NOT STARTED]

**Goal**: Implement stage-progressive context loading in skill-planner as proof-of-concept

**Research Finding**: Currently all context loaded in Stage 1, but format specs only needed in Stage 3. Could reduce initial context by ~60%.

**Current Pattern** (all loaded at start):
```xml
<execution>
  <stage id="1" name="LoadContext">
    <action>Read plan-format.md, status-markers.md, task-breakdown.md</action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate (needs only status_markers)</action>
  </stage>
  <stage id="3" name="Delegate">
    <action>Create plan (needs plan_format + task_breakdown)</action>
  </stage>
</execution>
```

**Proposed Pattern** (Progressive loading):
```xml
<execution>
  <stage id="1" name="LoadMinimalContext">
    <action>Read only status_markers for validation</action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate using status_markers</action>
  </stage>
  <stage id="3" name="LoadFormatContext">
    <action>Read plan_format and task_breakdown</action>
  </stage>
  <stage id="4" name="Delegate">
    <action>Create plan with full format context</action>
  </stage>
</execution>
```

**Tasks**:
- [ ] Read current skill-planner SKILL.md execution stages
- [ ] Modify to load status-markers.md in Stage 1 (for preflight validation)
- [ ] Defer plan-format.md and task-breakdown.md loading to Stage 3
- [ ] Update delegation prompt to include only loaded context
- [ ] Add documentation explaining the progressive loading pattern
- [ ] Measure context savings (before/after line count)

**Files to Modify**:
- `.opencode/skills/skill-planner/SKILL.md` - Execution stages

**Verification**:
- [ ] skill-planner loads context progressively by stage
- [ ] Preflight validation still works (has status_markers)
- [ ] Plan creation has full format context (plan_format + task_breakdown)
- [ ] Measure and document context reduction
- [ ] /plan command produces compliant plans

**Timing**: 1.5 hours

**Benefits**:
- ~40-50% reduction in initial context window usage
- Demonstrates progressive disclosure pattern for other skills
- Faster skill startup for validation-only scenarios

### Phase 8: Document Progressive Disclosure Best Practices [NOT STARTED]

**Goal**: Update context-loading-best-practices.md with findings and recommendations

**Tasks**:
- [ ] Add section on "Stage-Progressive Loading" pattern
- [ ] Add section on "Conditional Context Injection" (status-markers example)
- [ ] Add section on "Discovery-Layer Pattern" for agents
- [ ] Add "Context Budget Guidelines" (keep skills under 800 lines injected)
- [ ] Document which skills use which pattern and why
- [ ] Add troubleshooting section: "How to tell if context is being loaded correctly"

**Files to Modify**:
- `.opencode/docs/guides/context-loading-best-practices.md`

**Verification**:
- [ ] All new patterns documented with examples
- [ ] Clear decision framework updated
- [ ] Context budget guidelines added

**Timing**: 1 hour

### Phase 9: Test and Validate All Changes [NOT STARTED]

**Goal**: Comprehensive testing of all changes across the system

**Tasks**:
- [ ] Create test task: `/task "Test plan format compliance after OC_137"`
- [ ] Run `/plan` on test task
- [ ] Verify generated plan follows plan-format.md exactly:
  - Section: "## Implementation Phases"
  - Phase format: "### Phase N: Name [STATUS]"
  - Fields: **Goal**, **Tasks**, **Timing**
  - No separators
  - Full metadata block
- [ ] Run `/revise` on the same task
- [ ] Verify revised plan also follows format (this tests Phase 4)
- [ ] Test `/research` command (ensure status validation still works without injected status-markers)
- [ ] Test `/implement` command (ensure it works with changed skill context)
- [ ] Verify skills without status-markers can still check status correctly
- [ ] Measure context window usage before/after changes
- [ ] Document any remaining issues

**Verification**:
- [ ] /plan generates compliant plans
- [ ] /revise generates compliant plans (CRITICAL - was broken before)
- [ ] All skills function correctly without their removed context
- [ ] Status validation works across all skills
- [ ] No non-compliant format patterns present
- [ ] Context window usage reduced where expected

**Timing**: 1.5 hours (increased from 1 hour due to comprehensive testing needs)

## Testing & Validation

### Phase-Level Verification
- [ ] Phase 1: plan.md has no embedded template
- [ ] Phase 2: All embedded templates identified
- [ ] Phase 3: All embedded templates removed
- [ ] Phase 4: revise.md has working context injection
- [ ] Phase 5: planner-agent.md has discovery-layer pattern
- [ ] Phase 6: status-markers removed from non-transition skills
- [ ] Phase 7: skill-planner demonstrates stage-progressive loading
- [ ] Phase 8: Best practices documented
- [ ] Phase 9: All changes validated end-to-end

### Format Compliance Testing
- [ ] Create new plan via /plan - verify format compliance
- [ ] Revise plan via /revise - verify format compliance (CRITICAL)
- [ ] Test research command still works
- [ ] Test implementation command still works

### Context Optimization Testing
- [ ] Verify skills without status-markers still validate status correctly
- [ ] Measure context window usage in skill-planner before/after
- [ ] Verify progressive loading works (loads context at right stage)
- [ ] Verify discovery-layer pattern works (agents know what's available)

### Regression Testing
- [ ] All workflow commands still function
- [ ] Other commands unaffected
- [ ] State synchronization still works
- [ ] Git commits still work

## Artifacts & Outputs

1. Modified command specifications (plan.md, revise.md, possibly others)
2. Enhanced planner-agent.md with discovery-layer pattern
3. Updated skills (skill-planner with progressive loading, 4 skills without status-markers)
4. Updated documentation (context-loading-best-practices.md)
5. Test results documenting format compliance and context optimization
6. Audit report of embedded templates (from Phase 2)

## Success Criteria

- [ ] plan.md no longer contains non-compliant embedded template
- [ ] All command specs audited and cleaned of embedded templates
- [ ] revise.md has working context injection (CRITICAL - fixes compliance bug)
- [ ] planner-agent.md implements discovery-layer pattern
- [ ] 4 non-transition skills no longer inject status-markers.md (~400 lines saved)
- [ ] skill-planner demonstrates stage-progressive loading (~40-50% initial context reduction)
- [ ] /plan command generates compliant plans
- [ ] /revise command generates compliant plans
- [ ] All skills function correctly with optimized context
- [ ] Context-loading-best-practices.md updated with new patterns
- [ ] No plans produced with non-compliant format
- [ ] Future plans automatically follow plan-format.md

## Rollback/Contingency

If changes cause issues:

1. **Embedded template removal breaks generation**:
   - Restore from git: `git checkout -- .opencode/commands/plan.md`
   - Alternative: Keep minimal embedded template that explicitly references plan-format.md

2. **Status-marker removal breaks validation**:
   - Restore status-markers.md injection to affected skills
   - Alternative: Load status-markers only in Preflight stage (not full injection)

3. **Progressive loading causes context misses**:
   - Revert skill-planner to load all context in Stage 1
   - Document progressive loading as "experimental pattern" instead of default

4. **Context injection still unreliable**:
   - Add fallback in planner-agent.md to always load plan-format.md directly if not injected
   - Log warning when fallback occurs for debugging

## Notes

### Rationale for Comprehensive Approach

This revised plan incorporates all three research reports:

- **research-001.md**: Identified context injection as the core issue
- **research-002.md**: Found embedded templates as root cause
- **research-003.md**: Discovered opportunities for progressive disclosure optimization

The plan now addresses:
1. **Template hygiene** (remove embedded templates)
2. **Context reliability** (strengthen injection)
3. **Context efficiency** (progressive disclosure, surgical precision)

### Implementation Philosophy: Surgical Precision

Per the user constraint: "It is also important that context injection happens exactly where it is needed rather than in abundance which threatens to bloat context unnecessarily."

This plan implements that philosophy through:
- Conditional status-marker injection (only when needed)
- Stage-progressive loading (exactly when needed in workflow)
- Discovery-layer pattern (awareness without bloat)
- No universal "always load everything" approach

### Phase Interdependencies

- **Phase 1-3** (template removal) can happen in any order
- **Phase 4** (revise.md context) is HIGHEST priority - fixes current bug
- **Phase 5** (planner-agent.md) should happen after Phase 4
- **Phase 6** (status-markers) can happen anytime, test carefully
- **Phase 7** (progressive loading) is proof-of-concept, can be deferred if needed
- **Phase 8** (documentation) should happen after all patterns are implemented
- **Phase 9** (testing) must happen last

### Expected Impact

**Format Compliance**:
- 100% of new /plan commands produce compliant plans
- 100% of new /revise commands produce compliant plans (was broken)

**Context Optimization**:
- ~400 lines saved by removing unnecessary status-marker injection
- ~40-50% initial context reduction in skill-planner (demonstration)
- Better progressive disclosure patterns documented

**System Reliability**:
- Single source of truth (no embedded templates)
- Consistent context availability across all planning paths
- Clear documentation of context loading best practices

## References

- **research-001.md**: Initial analysis identifying context injection issues
- **research-002.md**: Root cause analysis identifying embedded templates
- **research-003.md**: Progressive disclosure optimization opportunities
- **plan-format.md**: The single source of truth for plan format
- **planner-agent.md**: Agent specification (to be enhanced with discovery-layer)
- **plan.md**: Command spec with embedded template to remove
- **revise.md**: Command spec needing context injection (HIGHEST priority)
- **context-loading-best-practices.md**: To be updated with new patterns
- **skill-structure.md**: Standards for skill context injection

## Next Steps

After plan approval, run `/implement OC_137` to begin.

**Recommended Phase Order**:
1. **Phase 4** first (highest priority - fixes current /revise bug)
2. **Phase 1** second (removes root cause of non-compliance)
3. **Phases 2-3** third (complete template removal)
4. **Phase 5** fourth (enhance agent context handling)
5. **Phases 6-7** fifth (optimization - can be deferred if needed)
6. **Phase 8** sixth (documentation)
7. **Phase 9** last (comprehensive testing)

**Phase 4 can begin immediately** - no blockers, just routing decision and implementation.
