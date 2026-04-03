# Implementation Plan: Multi-Task Operations Pattern

- **Task**: 350 - Create multi-task operations context pattern
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/350_multi_task_operations_pattern/reports/01_multi-task-ops.md
- **Artifacts**: plans/01_multi-task-ops-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a shared context pattern document at `.claude/context/patterns/multi-task-operations.md` that defines how workflow commands (`/research`, `/plan`, `/implement`) parse multi-task arguments and dispatch parallel agents. The research report provides a complete design including argument parsing, batch skill dispatch, commit formats, consolidated output, and partial-success error handling. This plan phases the writing of that single pattern document into logical sections, each independently verifiable.

### Research Integration

The research report (01_multi-task-ops.md) provides:
- Existing `parse_ranges()` function from routing.md as the parsing foundation
- `parse_task_args()` wrapper design for separating task numbers from remaining arguments
- Option B (batch skill dispatch) as the recommended architecture
- Complete batch commit and consolidated output format specifications
- Partial-success error handling categories and recovery strategies
- Backward compatibility analysis and edge case handling

## Goals & Non-Goals

**Goals**:
- Produce a complete, self-contained pattern document consumable by tasks 351-353
- Define argument parsing specification with examples and edge cases
- Define dispatch loop pattern (single-task fallthrough vs multi-task batch dispatch)
- Define batch commit format and consolidated output format
- Define partial-success error handling with error categories

**Non-Goals**:
- Modifying any existing command files (that is tasks 351-353)
- Creating executable scripts or code changes
- Implementing batch skill definitions (separate task)
- Supporting per-task flags or focus prompts in multi-task mode

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Pattern document too abstract for implementers | M | L | Include concrete examples and pseudocode for every section |
| Inconsistency with existing patterns (checkpoint-execution, team-orchestration) | M | M | Cross-reference existing patterns and use consistent terminology |
| Missing edge cases in argument parsing spec | L | M | Enumerate all examples from research; add explicit edge case table |

## Implementation Phases

### Phase 1: Document Structure and Argument Parsing [COMPLETED]

**Goal:** Create the pattern document with front matter, overview, and the argument parsing specification (sections 1-3 of the research outline).

**Tasks:**
- [ ] Create `.claude/context/patterns/multi-task-operations.md` with document header and overview section explaining motivation and scope
- [ ] Write argument parsing specification: `parse_task_args()` wrapper around `parse_ranges()`, regex pattern, examples table
- [ ] Write single-task fallthrough section explaining backward compatibility guarantees
- [ ] Include edge case table (deduplication, single-element ranges, ambiguous inputs)

**Timing:** 30 minutes

**Files to create:**
- `.claude/context/patterns/multi-task-operations.md` -- new pattern document (partial)

**Verification:**
- Document exists with overview and parsing sections
- Examples table covers all input formats from the research report
- Edge cases explicitly enumerated

---

### Phase 2: Dispatch Flow and Parallel Agent Spawning [COMPLETED]

**Goal:** Write the multi-task dispatch flow: validation, batch session ID, parallel agent spawning via Task tool, and result collection.

**Tasks:**
- [ ] Write STAGE 0 insertion point description (before existing GATE IN)
- [ ] Write dispatch decision logic (single vs multi-task branching)
- [ ] Write batch validation step (iterate tasks, check existence and status, collect valid/invalid)
- [ ] Write parallel agent spawning section using batch skill dispatch pattern (Option B from research)
- [ ] Write result collection and status tracking specification
- [ ] Document interaction with `--team` flag (orthogonal features, cost multiplication warning)

**Timing:** 25 minutes

**Files to modify:**
- `.claude/context/patterns/multi-task-operations.md` -- add dispatch and spawning sections

**Verification:**
- Dispatch flow clearly shows single-task vs multi-task branching
- Batch skill dispatch pattern is consistent with team-orchestration.md precedent
- Flag compatibility table included

---

### Phase 3: Output Formats and Error Handling [COMPLETED]

**Goal:** Write batch commit format, consolidated output format, and partial-success error handling sections.

**Tasks:**
- [ ] Write batch git commit format with examples (success and partial-success variants)
- [ ] Write consolidated output format (summary table, succeeded/failed/skipped sections, next steps)
- [ ] Write partial-success error handling: principle (never roll back), error categories table, per-task isolation
- [ ] Write command file modification guide summarizing what tasks 351-353 need to change in each command

**Timing:** 25 minutes

**Files to modify:**
- `.claude/context/patterns/multi-task-operations.md` -- add output and error handling sections

**Verification:**
- Commit message examples match existing git-workflow.md conventions
- Output format includes all fields from the research report
- Error categories cover: task not found, invalid status, agent timeout, agent failure, git conflict

---

### Phase 4: Index Registration and Final Review [COMPLETED]

**Goal:** Register the new pattern document in the context index and perform a final consistency review.

**Tasks:**
- [ ] Add entry to `.claude/context/index.json` for the new pattern document with appropriate `load_when` selectors (commands: /research, /plan, /implement; agents consuming multi-task patterns)
- [ ] Review full document for internal consistency and cross-references to existing patterns
- [ ] Verify all 11 sections from the research outline are covered
- [ ] Verify document uses terminology consistent with checkpoint-execution.md and team-orchestration.md

**Timing:** 15 minutes

**Files to modify:**
- `.claude/context/index.json` -- add new entry
- `.claude/context/patterns/multi-task-operations.md` -- final edits if needed

**Verification:**
- `jq` query for the new entry in index.json returns valid result
- Document contains all sections listed in research appendix outline
- No dangling references to undefined terms or patterns

## Testing & Validation

- [ ] Pattern document exists at `.claude/context/patterns/multi-task-operations.md`
- [ ] Document contains argument parsing spec with `parse_task_args()` pseudocode
- [ ] Document contains dispatch flow with single-task fallthrough
- [ ] Document contains batch commit format with examples
- [ ] Document contains consolidated output format
- [ ] Document contains partial-success error handling with categories
- [ ] Document contains command modification guide for tasks 351-353
- [ ] Entry exists in `.claude/context/index.json`
- [ ] Cross-references to routing.md, checkpoint-execution.md, team-orchestration.md are accurate

## Artifacts & Outputs

- `.claude/context/patterns/multi-task-operations.md` -- the pattern document (primary deliverable)
- `.claude/context/index.json` -- updated with new entry

## Rollback/Contingency

Since this creates a new file and adds one entry to index.json, rollback is straightforward: delete the pattern document and remove the index entry. No existing files are modified beyond the index addition.
