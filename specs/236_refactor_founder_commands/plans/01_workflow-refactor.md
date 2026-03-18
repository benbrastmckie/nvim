# Implementation Plan: Task #236

- **Task**: 236 - refactor_founder_commands
- **Status**: [COMPLETED]
- **Effort**: 5-6 hours
- **Dependencies**: None
- **Research Inputs**: [01_workflow-analysis.md](../reports/01_workflow-analysis.md)
- **Artifacts**: plans/01_workflow-refactor.md (this file)
- **Standards**:
  - .claude/context/core/standards/plan.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Refactor the `/market`, `/analyze`, and `/strategy` commands to follow the standard three-stage workflow pattern: research (with forcing questions) -> plan -> implement. Currently these commands auto-proceed through all stages in one execution. The fix involves modifying 11 files across commands, skills, and agents to separate concerns properly: agents write research reports with Q&A results, the planner reads those reports, and the implementer generates final strategy output.

### Research Integration

From `01_workflow-analysis.md`:
- Commands need to delegate to research skills instead of auto-invoking plan+implement
- Skills should follow the `skill-researcher` pattern (preflight->agent->postflight)
- Agents should produce research reports at `specs/{NNN}_{SLUG}/reports/`, not strategy output
- `founder-plan-agent` should read research reports instead of asking forcing questions
- `founder-implement-agent` already generates strategy output correctly, needs minor updates

## Goals & Non-Goals

**Goals**:
- Each command (`/market`, `/analyze`, `/strategy`) stops after research at [RESEARCHED]
- User explicitly runs `/plan N` and `/implement N` as separate steps
- Forcing questions happen once during research, answers captured in report
- Uniform workflow pattern across all three founder commands
- Final `strategy/*.md` output generated only by `founder-implement-agent`

**Non-Goals**:
- Changing the forcing questions themselves
- Modifying the strategy output format
- Adding new commands or workflows
- Changing other extension commands

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing workflow | High | Medium | Test each command after modification |
| Inconsistent patterns across commands | Medium | Low | Use template pattern, modify one then copy |
| Missing context in plan/implement stages | Medium | Medium | Ensure report includes all Q&A answers |
| Skill-researcher pattern mismatch | Low | Low | Reference existing skill-researcher.md |

## Implementation Phases

### Phase 1: Refactor Agents (Research Output Only) [COMPLETED]

**Goal**: Convert market-agent, analyze-agent, and strategy-agent to produce research reports instead of strategy output.

**Tasks**:
- [ ] Read existing market-agent.md to understand current structure
- [ ] Rewrite market-agent.md to:
  - Keep forcing questions logic
  - Output to `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md`
  - Write `.return-meta.json` with `status: "researched"`
  - Remove strategy output generation
- [ ] Apply same pattern to analyze-agent.md
- [ ] Apply same pattern to strategy-agent.md

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/extensions/founder/agents/market-agent.md` - Convert to research-only output
- `.claude/extensions/founder/agents/analyze-agent.md` - Convert to research-only output
- `.claude/extensions/founder/agents/strategy-agent.md` - Convert to research-only output

**Verification**:
- Each agent definition includes research report output path
- No references to `strategy/` output directory
- Metadata file instructions specify `status: "researched"`

---

### Phase 2: Refactor Skills (Researcher Pattern) [COMPLETED]

**Goal**: Rewrite skill-market, skill-analyze, and skill-strategy to follow the skill-researcher pattern.

**Tasks**:
- [ ] Read skill-researcher.md as reference pattern
- [ ] Rewrite skill-market.md:
  - Preflight: update status to [RESEARCHING]
  - Delegation: invoke market-agent
  - Postflight: update status to [RESEARCHED], link artifact, git commit
- [ ] Apply same pattern to skill-analyze.md
- [ ] Apply same pattern to skill-strategy.md

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/extensions/founder/skills/skill-market.md` - Rewrite as researcher pattern
- `.claude/extensions/founder/skills/skill-analyze.md` - Rewrite as researcher pattern
- `.claude/extensions/founder/skills/skill-strategy.md` - Rewrite as researcher pattern

**Verification**:
- Skills follow preflight -> delegate -> postflight structure
- Status transitions: [NOT STARTED] -> [RESEARCHING] -> [RESEARCHED]
- Artifact linking in postflight
- Git commit after status update

---

### Phase 3: Refactor Commands (Remove Auto-Proceed) [COMPLETED]

**Goal**: Remove auto-plan+implement stages from market.md, analyze.md, and strategy.md commands.

**Tasks**:
- [ ] Read existing market.md command structure
- [ ] Rewrite market.md:
  - GATE IN: validate input, create task (unchanged)
  - DELEGATE: invoke skill-market (replaces auto-plan+implement)
  - GATE OUT: verify [RESEARCHED] status
  - Remove stages 2A (auto-plan) and 2B (auto-implement)
- [ ] Apply same pattern to analyze.md
- [ ] Apply same pattern to strategy.md

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/commands/market.md` - Remove auto-proceed, single delegation
- `.claude/extensions/founder/commands/analyze.md` - Remove auto-proceed, single delegation
- `.claude/extensions/founder/commands/strategy.md` - Remove auto-proceed, single delegation

**Verification**:
- Commands have single delegation point (not multi-stage)
- No references to `/plan` or `/implement` auto-invocation
- GATE OUT expects [RESEARCHED] status

---

### Phase 4: Update founder-plan-agent (Read Report) [COMPLETED]

**Goal**: Modify founder-plan-agent to read research report instead of asking forcing questions.

**Tasks**:
- [ ] Read existing founder-plan-agent.md
- [ ] Identify where forcing questions are asked
- [ ] Replace question logic with report reading:
  - Locate report at `specs/{NNN}_{SLUG}/reports/01_*.md`
  - Parse forcing question answers from report
  - Use answers as context for plan generation
- [ ] Update plan output to reference research report in metadata

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Read report, remove questions

**Verification**:
- No interactive forcing questions in plan agent
- Report path discovery logic present
- Research integration section in generated plan
- Plan references research report in "Research Inputs" field

---

### Phase 5: Update founder-implement-agent (Minor Enhancements) [COMPLETED]

**Goal**: Ensure founder-implement-agent reads both plan and research report for full context; support optional output path.

**Tasks**:
- [ ] Read existing founder-implement-agent.md
- [ ] Add report reading logic alongside plan reading
- [ ] Add optional output path parameter (default: `strategy/`)
- [ ] Ensure both plan and report inform strategy generation

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Add report reading, optional path

**Verification**:
- Agent reads both plan file and research report
- Output path is configurable with `strategy/` default
- Strategy output references both inputs

---

### Phase 6: Integration Testing [COMPLETED]

**Goal**: Verify the complete workflow works end-to-end for each command.

**Tasks**:
- [ ] Test `/market "test description"` workflow:
  - Creates task with [NOT STARTED]
  - Asks forcing questions
  - Writes research report
  - Task ends at [RESEARCHED]
- [ ] Test `/plan N` on market task:
  - Reads research report
  - Creates implementation plan
  - Task ends at [PLANNED]
- [ ] Test `/implement N` on market task:
  - Reads plan and report
  - Generates `strategy/market-sizing-*.md`
  - Task ends at [COMPLETED]
- [ ] Repeat tests for `/analyze` workflow
- [ ] Repeat tests for `/strategy` workflow
- [ ] Verify uniform behavior across all three

**Timing**: 0.5 hours

**Files to modify**:
- None (testing only)

**Verification**:
- All three commands follow identical workflow pattern
- Each stage produces expected artifacts
- Status transitions are correct
- `strategy/` output only appears after `/implement`

## Testing & Validation

- [ ] `/market "test"` stops at [RESEARCHED] with research report
- [ ] `/analyze "test"` stops at [RESEARCHED] with research report
- [ ] `/strategy "test"` stops at [RESEARCHED] with research report
- [ ] `/plan N` reads report and produces plan without asking questions
- [ ] `/implement N` generates strategy output using both plan and report
- [ ] Forcing questions appear once (during research), not during planning
- [ ] No auto-progression from research to plan to implement

## Artifacts & Outputs

- `.claude/extensions/founder/agents/market-agent.md` (modified)
- `.claude/extensions/founder/agents/analyze-agent.md` (modified)
- `.claude/extensions/founder/agents/strategy-agent.md` (modified)
- `.claude/extensions/founder/skills/skill-market.md` (modified)
- `.claude/extensions/founder/skills/skill-analyze.md` (modified)
- `.claude/extensions/founder/skills/skill-strategy.md` (modified)
- `.claude/extensions/founder/commands/market.md` (modified)
- `.claude/extensions/founder/commands/analyze.md` (modified)
- `.claude/extensions/founder/commands/strategy.md` (modified)
- `.claude/extensions/founder/agents/founder-plan-agent.md` (modified)
- `.claude/extensions/founder/agents/founder-implement-agent.md` (modified)
- `specs/236_refactor_founder_commands/summaries/01_workflow-refactor-summary.md` (created on completion)

## Rollback/Contingency

If implementation causes issues:
1. Git revert to commit before Phase 1 changes
2. Each phase is committed separately, enabling partial rollback
3. Original command behavior can be restored from git history
4. Extension can be temporarily disabled via manifest if needed
