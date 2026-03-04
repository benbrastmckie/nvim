# Research Report: Task #133

**Task**: OC_133 - Fix planner agent not following plan-format.md specification
**Date**: 2026-03-04
**Language**: meta
**Focus**: Context loading chain from skill-planner → planner-agent → plan file

## Summary

The root cause is **not** a context loading failure, but rather a **format interpretation mismatch** in the planner-agent.md specification. While skill-planner correctly injects plan-format.md via `<context_injection>`, the planner-agent.md template produces output that deviates from the format standard in several ways: (1) phase headings lack required status markers, (2) phases include redundant `**Status**: [STATUS]` metadata lines that shouldn't exist, (3) `**Objectives**:` and `**Estimated effort**:` are used instead of the required `**Goal**:` and `**Timing**:` fields, and (4) phases use `---` separators that may conflict with the format. The planner-agent.md provides a template that doesn't match the plan-format.md Example Skeleton, leading to systematic non-compliance in all generated plans.

## Findings

### 1. Context Loading Chain is Working Correctly

The context injection mechanism is functioning properly:

**skill-planner/SKILL.md** (lines 18-22):
```xml
<context_injection>
  <file path=".opencode/context/core/formats/plan-format.md" variable="plan_format" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
  <file path=".opencode/context/core/workflows/task-breakdown.md" variable="task_breakdown" />
</context_injection>
```

The context files are being injected into the skill and passed to the planner-agent. The planner-agent.md also references these files with @-references (lines 63-67), confirming the context is available.

### 2. Plan-Format.md Specifies Clear Requirements

**From plan-format.md (lines 74-81)** - Phase format:
```markdown
## Implementation Phases (format)
- Heading: `### Phase N: {name} [STATUS]`
- Under each phase include:
  - **Goal:** short statement
  - **Tasks:** bullet checklist
  - **Timing:** expected duration or window
```

**From plan-format.md (lines 96-136)** - Example Skeleton:
```markdown
### Phase 1: {name} [NOT STARTED]

**Goal:** ...
**Tasks:**
  - [ ] ...
**Timing:** ...
```

Key requirements:
- Status marker MUST be in the heading: `### Phase N: Name [STATUS]`
- Required fields under phase: **Goal**, **Tasks**, **Timing**
- NO separate `**Status**: [STATUS]` line after heading
- NO `---` separator between phases

### 3. Planner-Agent.md Template is Incorrect

**planner-agent.md Stage 5 (lines 237-257)** provides a template that contradicts the format:

```markdown
### Phase 1: {Name} [NOT STARTED]

**Goal**: {What this phase accomplishes}  ✓ CORRECT

**Tasks**:  ✓ CORRECT
- [ ] {Task 1}
- [ ] {Task 2}

**Timing**: {X hours}  ✓ CORRECT (but see below)

**Files to modify**:  ✗ EXTRA - not in format
- `path/to/file` - {what changes}

**Verification**:  ✗ EXTRA - not in format
- {How to verify phase is complete}

---  ✗ WRONG - separator not in format
```

**Additional template issues in planner-agent.md**:
- Line 15: Shows `### Phase 1: Foundation & Formats` without `[STATUS]` marker
- Line 16: Shows `**Status**: [COMPLETED]` - this is the WRONG pattern
- Line 17: Shows `**Estimated effort**: 1 hour` instead of `**Timing**:`
- Line 19: Shows `**Objectives**:` instead of `**Goal**:`

### 4. Actual Plan Files Show the Non-Compliance Pattern

**specs/130_make_opencode_self_contained/plans/implementation-001.md**:
```markdown
### Phase 1: Foundation & Formats  ✗ Missing [STATUS] in heading

**Status**: [COMPLETED]  ✗ WRONG - should not exist
**Estimated effort**: 1 hour  ✗ WRONG - should be **Timing**:

**Objectives**:  ✗ WRONG - should be **Goal**:
```

**specs/132_create_context_loading_best_practices_guide/plans/implementation-001.md**:
```markdown
### Phase 1: Create Guide Structure and Core Content [COMPLETED]  ✓ CORRECT heading

**Status**: [COMPLETED]  ✗ WRONG - should not exist
**Completed**: 2026-03-04  ✗ EXTRA metadata
```

**specs/129_fix_plan_format_in_implementation_001_md/plans/implementation-001.md** (ironically, the task about fixing plan format):
```markdown
### Phase 1: Reformat Task 128 Plan File [NOT STARTED]  ✓ CORRECT heading

**Goal**: Bring the existing non-compliant plan file into compliance.  ✓ CORRECT

**Tasks**:  ✓ CORRECT
- [ ] Move status markers from body to phase headers
- [ ] Remove redundant `**Status**: [STATUS]` lines.
```

This last example shows the planner-agent CAN produce correct format when given explicit instructions in the task description to "remove redundant status lines."

### 5. The Verification Stage is Insufficient

**planner-agent.md Stage 6a (lines 276-303)** attempts verification:

```markdown
#### 6a. Verify Required Metadata Fields
Re-read the plan file and verify ALL these fields exist...
- `- **Status**: [NOT STARTED]` - **REQUIRED** - Must be present in plan header
```

**Problem**: The verification instruction says "Must be present in plan header" which is ambiguous. It should say:
- "Status marker must be in phase heading like `### Phase N: Name [NOT STARTED]`"
- "Must NOT have separate `**Status**: [STATUS]` line after heading"

### 6. Root Cause Analysis

The chain of failure:

```
skill-planner (CORRECT)
    ↓ Injects plan-format.md via <context_injection>
planner-agent (AMBIGUOUS)
    ↓ Template contradicts format specification
plan file (INCORRECT)
    ↓ Non-compliant structure
```

**NOT a context loading problem** - the files are injected correctly.
**IS a template/interpretation problem** - the planner-agent.md contains templates that don't match plan-format.md.

Specific contradictions:

| plan-format.md Requirement | planner-agent.md Template | Status |
|---------------------------|---------------------------|--------|
| `### Phase N: Name [STATUS]` in heading | Heading without status, separate `**Status**` line | ✗ MISMATCH |
| **Goal**: field | **Objectives**: field | ✗ MISMATCH |
| **Timing**: field | **Estimated effort**: field | ✗ MISMATCH |
| No separator between phases | Uses `---` separator | ✗ MISMATCH |
| Required: **Goal**, **Tasks**, **Timing** | Adds **Files to modify**, **Verification** | ✗ EXTRA |

### 7. Why It Keeps Failing Despite Fixes

Previous attempts to fix this likely focused on:
1. Ensuring context files are loaded (already working)
2. Adding more instructions to the agent (not the root cause)

**The real fix**: Update planner-agent.md's Stage 5 template to match plan-format.md exactly, and fix Stage 6a verification instructions to check for the CORRECT patterns.

## Recommendations

### 1. **Fix planner-agent.md Stage 5 Template** (High Priority)

Replace the template section (lines 237-270) with one that matches plan-format.md exactly:

```markdown
### Phase N: {Name} [NOT STARTED]

**Goal**: {What this phase accomplishes}

**Tasks**:
- [ ] {Task 1}
- [ ] {Task 2}

**Timing**: {X hours}

(NO **Files to modify** - put in Overview)
(NO **Verification** - put in Testing & Validation section)
(NO `---` separator)
```

### 2. **Fix planner-agent.md Stage 6a Verification** (High Priority)

Update verification instructions (lines 276-303) to:
- Check phase headings have format: `### Phase N: Name [STATUS]`
- Check NO separate `**Status**: [STATUS]` lines exist
- Check fields are **Goal**, **Tasks**, **Timing** (not Objectives, Estimated effort)
- Check NO `---` separators between phases

### 3. **Fix planner-agent.md Example Templates** (High Priority)

Update line 15-19 to show correct format:
```markdown
### Phase 1: Foundation & Formats [COMPLETED]

**Goal**: Replace deprecated format files

**Tasks**:
- [ ] Read .claude format file
- [ ] Write to .opencode location

**Timing**: 1 hour
```

### 4. **Clarify "Metadata Block" vs "Phase Format"** (Medium Priority)

The term "metadata" is overloaded:
- Plan-level metadata block (lines 13-27) - REQUIRED
- Phase-level metadata (Goal, Tasks, Timing) - REQUIRED
- But `**Status**: [STATUS]` is NOT part of phase metadata

Clarify this distinction in plan-format.md and planner-agent.md.

### 5. **Add Template Validation to skill-planner Postflight** (Low Priority)

Consider adding a postflight check that:
1. Reads created plan file
2. Validates against plan-format.md requirements
3. Reports mismatches before committing

## Risks & Considerations

- **Template Changes Break Existing Behavior**: Updating planner-agent.md template may initially cause confusion, but will produce correct output.

- **Context Window**: The current template is already quite long; ensuring it matches format exactly without adding too much bulk is important.

- **Agent Adaptation**: The agent has learned the wrong template pattern from existing examples; clear instructions to ignore old examples and follow the format exactly are needed.

- **Verification Overhead**: Strict verification may add time to planning, but ensures compliance.

## Next Steps

Run `/plan OC_133` to create an implementation plan that:
1. Updates planner-agent.md Stage 5 template to match plan-format.md exactly
2. Updates planner-agent.md Stage 6a verification instructions with explicit checks
3. Fixes example templates in planner-agent.md that show incorrect format
4. Tests the corrected template by running /plan on a sample task
5. Optionally adds postflight validation to skill-planner

The fix is in the agent specification, not the context loading mechanism.
