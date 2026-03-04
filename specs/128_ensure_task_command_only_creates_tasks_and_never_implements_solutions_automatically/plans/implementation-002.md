# Implementation Plan: Task #128

- **Task**: 128 - Implement "Push" Context Loading Model
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: specs/128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/plans/implementation-002.md
- **Standards**: .opencode/context/core/formats/plan-format.md, .opencode/context/core/standards/status-markers.md, .opencode/context/core/system/artifact-management.md, .opencode/context/core/standards/tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Systematically revise the `.opencode/` agent system to implement a "Push" context loading model. This replaces the current "Pull" (on-demand) model where agents must request context using `@-references` or `Read`. The new model ensures critical context is injected directly into the agent's prompt by the invoking skill, reducing cognitive load, ensuring consistency, and preventing context-missing errors.

**Note**: This plan interprets the user's request for a "pust" context loading model as a "Push" model, which is the standard opposite of the current "Pull" model.

### Research Integration

Analysis of the current system shows a heavy reliance on "Pull" context loading (e.g., `skill-planner` instructs agents to "Load these on-demand using @-references"). This creates a risk where agents fail to load necessary context. The "Push" model will mitigate this by injecting context upfront.

## Goals & Non-Goals

**Goals**:
- Define a standard "Push Context" pattern for all core skills.
- Update `skill-structure.md` and relevant documentation to reflect the new model.
- Migrate all core skills to the "Push" model:
  - `skill-orchestrator`
  - `skill-planner`
  - `skill-researcher`
  - `skill-implementer`
  - `skill-meta`
  - `skill-learn`
  - `skill-refresh`
  - `skill-status-sync`
  - `skill-git-workflow`
  - `skill-neovim-research`
  - `skill-neovim-implementation`
- Verify context propagation in end-to-end workflows.

**Non-Goals**:
- Migrate extension skills (deferred until core system is complete).
- Change the underlying agent architecture beyond context loading.
- Implement "Pull" context for non-critical information (optional context can remain on-demand).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Prompt Size Limits | H | M | Only push *critical* context; keep optional context as "Pull". Use concise summaries where possible. |
| Agent Confusion | M | L | Use clear XML delimiters (`<context>...</context>`) and structured prompts. |
| Regression in Existing Workflows | H | M | Test each skill migration individually and verify end-to-end workflows. |

## Implementation Phases

### Phase 1: Design & Standards Update [COMPLETED]

**Goal**: Define the "Push Context" pattern and update documentation.

**Tasks**:
- [x] Analyze current context dependencies for all core skills.
- [x] Define a standard "Push Context" block structure (e.g., XML format in `SKILL.md`).
- [x] Update `.opencode/context/core/formats/skill-structure.md` to reflect the new model.
- [x] Create a template for the new `SKILL.md` structure.

**Timing**: 1 hour

**Files to modify**:
- `.opencode/context/core/formats/skill-structure.md`
- `.opencode/context/core/templates/thin-wrapper-skill.md` (if applicable)

**Verification**:
- [x] Verify the new standard is clear and covers all use cases.

---

### Phase 2: Core Workflow Migration (Batch 1) [COMPLETED]

**Goal**: Migrate the primary workflow skills (Orchestrator, Research, Plan).

**Tasks**:
- [x] Migrate `skill-orchestrator`: Inject routing rules and state management context. [ALREADY COMPLETED - has context_injection]
- [x] Migrate `skill-planner`: Inject planning format and task breakdown guidelines. [ALREADY COMPLETED - has context_injection]
- [x] Migrate `skill-researcher`: Inject research format and analysis framework. [ALREADY COMPLETED - has context_injection]

**Timing**: 1.5 hours

**Files to modify**:
- `.opencode/skills/skill-orchestrator/SKILL.md`
- `.opencode/skills/skill-planner/SKILL.md`
- `.opencode/skills/skill-researcher/SKILL.md`

**Verification**:
- Run `/plan` and `/research` commands to verify context is present without agent requesting it.

---

### Phase 3: Core Workflow Migration (Batch 2) [COMPLETED]

**Goal**: Migrate the implementation and meta skills.

**Tasks**:
- [x] Migrate `skill-implementer`: Inject implementation standards and coding guidelines. [ADDED context_injection with return-metadata, postflight-control, file-metadata, jq-workarounds]
- [x] Migrate `skill-meta`: Inject system architecture and meta-guide. [ADDED context_injection with return-metadata, postflight-control, file-metadata]
- [x] Migrate `skill-learn`: Inject learning patterns and TODO management. [ADDED context_injection with TODO.md and state.json]

**Timing**: 1 hour

**Files to modify**:
- `.opencode/skills/skill-implementer/SKILL.md`
- `.opencode/skills/skill-meta/SKILL.md`
- `.opencode/skills/skill-learn/SKILL.md`

**Verification**:
- Run `/implement` and `/meta` commands to verify context injection.

---

### Phase 4: Utility Skill Migration (Batch 3) [COMPLETED]

**Goal**: Migrate the remaining utility skills.

**Tasks**:
- [x] Migrate `skill-refresh`: Inject cleanup rules. [ADDED context_injection with postflight-control]
- [x] Migrate `skill-status-sync`: Inject status transition rules. [ADDED context_injection with TODO.md, state.json, jq-workarounds]
- [x] Migrate `skill-git-workflow`: Inject git safety protocols. [ADDED context_injection with git-safety, git-workflow]
- [x] Migrate `skill-neovim-research` & `skill-neovim-implementation`: Inject Neovim-specific context. [ADDED context_injection with return-metadata, postflight-control, file-metadata, jq-workarounds]

**Timing**: 0.5 hours

**Files to modify**:
- `.opencode/skills/skill-refresh/SKILL.md`
- `.opencode/skills/skill-status-sync/SKILL.md`
- `.opencode/skills/skill-git-workflow/SKILL.md`
- `.opencode/skills/skill-neovim-research/SKILL.md`
- `.opencode/skills/skill-neovim-implementation/SKILL.md`

**Verification**:
- Verify utility commands function correctly with pushed context.

## Testing & Validation

- [ ] **End-to-End Test**: Run a full cycle (Research -> Plan -> Implement) for a dummy task.
- [ ] **Context Check**: Inspect agent logs (if available) or behavior to confirm they are not requesting context they already have.
- [ ] **Prompt Size Check**: Ensure pushed context does not cause token limit errors.

## Artifacts & Outputs

- Updated `SKILL.md` files for all core skills.
- Updated documentation for skill structure.

## Rollback/Contingency

If the "Push" model causes issues (e.g., token limits or confusion):
- Revert the `SKILL.md` changes to the previous "Pull" model.
- Restore the "Load on-demand" instructions.
