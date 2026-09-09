# Status Markers Convention

**Status**: Active  
**Created**: 2026-01-05  
**Purpose**: Single source of truth for status markers across TODO.md and state.json

---

## Overview

This document defines the complete set of status markers used throughout this agent system for tracking task and phase progress. It serves as the authoritative reference for:

- **Status Marker Definitions**: All valid status markers and their meanings
- **TODO.md Format**: How markers appear in TODO.md task entries
- **state.json Format**: How status values appear in state.json
- **Valid Transitions**: Which status changes are allowed
- **Command Mappings**: Which commands trigger which status changes

### Single source

The task-level status enum itself has exactly one machine-readable pair of anchors:
`context/schemas/state-schema.json`'s `definitions.taskStatus.enum` and the sourced shell library
`scripts/lib/status-vocabulary.sh` (kept byte-equal by `scripts/tests/test-status-vocabulary.sh`'s
drift assertion). This document is the authoritative **human-readable gloss** over that pair --
prose explaining meaning, transitions, and required fields -- not an independent third source. If
this document and the schema/library ever disagree, the schema/library wins.

---

## Status Marker Definitions

### Standard Status Markers

#### `[NOT STARTED]`
**TODO.md Format**: `- **Status**: [NOT STARTED]`  
**state.json Value**: `"status": "not_started"`  
**Meaning**: Task or phase has not yet begun.

**Valid Transitions**: Any command (research, plan, implement, revise) can run from this status.

#### `[RESEARCHING]`
**TODO.md Format**: `- **Status**: [RESEARCHING]`  
**state.json Value**: `"status": "researching"`  
**Meaning**: Research is actively underway.

**Valid Transitions**: Non-terminal; any command can run. Normally completes to `[RESEARCHED]`.

**Timestamps**: Always include `- **Researched**: YYYY-MM-DD` when started

**Two producers**: `preflight:research` (an ordinary research dispatch — `/orchestrate`'s own
research-first default for a `not_started` task, its own `--research` forcing it, or a direct
`/research` call) is the original producer. Under `/orchestrate`'s `--fast`-only escape hatch
(see "The Effort-Conditional Default with a `--fast` Escape Hatch" below), this resting state
also has a SECOND producer: `postflight:needs_research`, written when a planner declines to plan
and returns a `needs_research` verdict. Both producers resolve to the identical `researching`
resting state — the second reuses it rather than minting a new one — so the state itself carries
no signal about which producer wrote it; consult the task's `research_questions` field
(non-empty only on the `needs_research` path) or the dispatch history to tell them apart.

#### `[RESEARCHED]`
**TODO.md Format**: `- **Status**: [RESEARCHED]`  
**state.json Value**: `"status": "researched"`  
**Meaning**: Research completed, deliverables created.

**Valid Transitions**: Any command (research, plan, implement, revise) can run from this status.

**Required Artifacts**: Research report linked in TODO.md

#### `[PLANNING]`
**TODO.md Format**: `- **Status**: [PLANNING]`  
**state.json Value**: `"status": "planning"`  
**Meaning**: Implementation plan is being created.

**Valid Transitions**: Non-terminal; any command can run. Normally completes to `[PLANNED]`.

**Timestamps**: Always include `- **Planned**: YYYY-MM-DD` when started

#### `[PLANNED]`
**TODO.md Format**: `- **Status**: [PLANNED]`  
**state.json Value**: `"status": "planned"`  
**Meaning**: Implementation plan completed, ready for implementation.

**Valid Transitions**: Any command (research, plan, implement, revise) can run from this status.

**Required Artifacts**: Implementation plan linked in TODO.md

> **Removal note**: the two intermediate plan-revision markers formerly documented here -- an
> in-progress marker (state.json value ending "-ing") and its completion counterpart (state.json
> value ending "-ed") -- were deleted from this document (and are not members of the closed enum
> in `state-schema.json` / `status-vocabulary.sh`) as dead vocabulary, not merely
> under-documented. Three independent pieces of evidence: `update-task-status.sh`'s
> `map_status()` has no case for the `/revise` target, so both values are unreachable through the
> one canonical status writer; `state-management-schema.md` never mentioned them; and
> `skill-reviser/SKILL.md` explicitly documents skipping the intermediate status by design ("No
> intermediate status update is needed mid-revision. The task transitions directly to 'planned'
> on success (via postflight). Skip preflight status update."). `/revise` remains a real command
> -- only the two intermediate status VALUES were removed, not the command itself. Do not
> silently reintroduce these values without re-reading `skill-reviser/SKILL.md`'s documented
> decision.

#### `[IMPLEMENTING]`
**TODO.md Format**: `- **Status**: [IMPLEMENTING]`  
**state.json Value**: `"status": "implementing"`  
**Meaning**: Implementation work is actively underway.

**Valid Transitions**: Non-terminal; any command can run. Normally completes to `[COMPLETED]` or `[PARTIAL]`.

**Timestamps**: Always include `- **Implemented**: YYYY-MM-DD` when started

#### `[PR READY]`
**TODO.md Format**: `- **Status**: [PR READY]`  
**state.json Value**: `"status": "pr_ready"`  
**Meaning**: `task_type == "pr"` only. Implementation complete; the PR is awaiting a
user-invoked `/merge` to submit it. This is a `task_type == "pr"`-only resting state — see the
"Target Arguments vs. Resting States" subsection below for what happens when `pr_ready` is passed
as a script argument for other task types.

**Valid Transitions**: To `[COMPLETED]` after `/merge` submits the PR; back to `[IMPLEMENTING]` if
PR review finds issues (re-dispatch).

#### `[COMPLETED]`
**TODO.md Format**: `- **Status**: [COMPLETED]`  
**state.json Value**: `"status": "completed"`  
**Meaning**: Task is finished successfully.

**Valid Transitions**: Terminal state (no further transitions)

**Required Information**:
- `- **Completed**: YYYY-MM-DD` timestamp
- Do not add emojis; rely on status marker and text alone

#### `[PARTIAL]`
**TODO.md Format**: `- **Status**: [PARTIAL]`  
**state.json Value**: `"status": "partial"`  
**Meaning**: Implementation partially completed (can resume).

**Valid Transitions**: Any command (research, plan, implement, revise) can run from this status.

#### `[BLOCKED]`
**TODO.md Format**: `- **Status**: [BLOCKED]`  
**state.json Value**: `"status": "blocked"`  
**Meaning**: Task is blocked by dependencies or issues.

**Valid Transitions**: Any command (research, plan, implement, revise) can run from this status.

**Required Information**:
- `- **Blocked**: YYYY-MM-DD` timestamp
- `- **Blocking Reason**: {reason}` or `- **Blocked by**: {dependency}`

#### `[ABANDONED]`
**TODO.md Format**: `- **Status**: [ABANDONED]`  
**state.json Value**: `"status": "abandoned"`  
**Meaning**: Task was started but abandoned without completion.

**Valid Transitions**: Terminal state. No further transitions (use `/task --recover` to restart).

**Required Information**:
- `- **Abandoned**: YYYY-MM-DD` timestamp
- `- **Abandonment Reason**: {reason}`

---

### Plan-level vs. phase-level markers

The full marker set above is the **task-level** vocabulary (TODO.md / state.json). Plan artifacts
use a related but narrower vocabulary at two further grains, and the differences between all
three are intentional:

- **Plan-level Status field** (the single `- **Status**:` line in a plan artifact's metadata
  block) uses the subset `{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED, ABANDONED, COMPLETED}`.
- **Phase-heading markers** (`### Phase N: {name} [STATUS]`) are scoped to a single phase within
  a plan and never include `ABANDONED` — see plan-format.md's Implementation Phases format.
  Alongside `[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`, `[PARTIAL]`, and `[BLOCKED]`, the
  phase-heading vocabulary also includes `[COMPLETED WITH EXCLUSIONS]` (see below) — a
  phase-heading marker only, absent from both the task-level vocabulary above and the plan-level
  Status subset.

See plan-format.md's "Plan-level vs. phase-level markers" subsection (under Status Marker
Requirements) for the full rationale: `ABANDONED` is deliberately plan/task-level only (no code
path abandons a single phase while leaving siblings active), and plan-level `PARTIAL` is an
aggregate whole-document signal distinct from, and compatible with, an individual phase heading
carrying its own `[PARTIAL]`.

---

#### `[COMPLETED WITH EXCLUSIONS]` (phase-heading marker only)

A third terminal phase-heading outcome, distinct from both plain outcomes on either side of it:

- `[COMPLETED]` — nothing was excluded; every planned item was done.
- `[PARTIAL]` — work remains and is resumable; a future dispatch is expected to continue it.
- `[COMPLETED WITH EXCLUSIONS]` — every remaining item was **decided, justified, and will not be
  revisited**. Nothing is left for a future dispatch to pick up; the phase is closed, not stalled.

This outcome is a **generalization of the existing strategic-sorry mechanism**
(`context/contracts/anti-analysis.md`'s "Strategic sorries" section), not a second, competing
mechanism. Both are members of one documented family — "documented incompleteness that still
counts as success" — differing on exactly one axis: a strategic sorry is *deferred with a
tracked follow-up* (`sorry_inventory.follow_up_task` is non-null), while a reasoned exclusion is
*decided and will not be revisited* (no follow-up field exists at all). See
`context/contracts/anti-analysis.md` for the cross-reference in the other direction.

**Character-class constraint**: the phase-accounting TOTAL regex in
`scripts/update-task-status.sh`'s `count_plan_phases()` is `[A-Z][A-Z ]*` — uppercase letters and
spaces only. Any phase-heading marker text, including this one, must satisfy that class exactly;
a name containing a dash, digit, or parenthesis silently falls out of the denominator. This is
why the chosen marker text is `COMPLETED WITH EXCLUSIONS` rather than a hyphenated or
parenthetical variant.

**Admission test**: A phase may close as `[COMPLETED WITH EXCLUSIONS]` only when ALL five
conditions hold — this is a direct, mode-neutral and task-type-neutral generalization of the
five-condition strategic-sorry test in `context/contracts/anti-analysis.md`:

1. **Decision, not abandonment**: The exclusion is a deliberate decision that the remaining
   item(s) are not applicable — not a stuck or abandoned attempt.
2. **Tightly scoped**: The exclusion is scoped to specific, enumerated items — never "the rest of
   the phase."
3. **Documented reason**: Each excluded item carries a stated reason.
4. **Evidenced**: Each reason carries evidence — command output, a quoted match count, a diff
   excerpt, or an artifact reference confirming it.
5. **No residual work**: Nothing remains that a future dispatch would need to do. This is exactly
   why no follow-up task is recorded — there is nothing to hand off.

Failing any one of these five conditions means the phase is `[PARTIAL]`, not exclusion-closed.
See `context/formats/plan-format.md`'s `#### Reasoned Exclusions` record format for the required
per-item record, and `context/contracts/anti-analysis.md` for the strategic-sorry counterpart.

**Whole-phase exclusion is a valid, intended case, not a degenerate one**: the excluded set may
be a subset of a phase's remaining items or the *entire* remainder — the five-condition test above
is satisfied identically either way, since none of its conditions distinguish "some" from "all."
A plan author facing a whole-phase exclusion should reach for `[COMPLETED WITH EXCLUSIONS]` here,
not invent a fourth marker.

**`[DESCOPED]` is rejected as a phase-heading marker.** It is not a member of the closed
status-marker enum and must not be used, including for the whole-phase case above — use
`[COMPLETED WITH EXCLUSIONS]` with a full `#### Reasoned Exclusions` record instead. Admitting a
semantically-overlapping fourth marker would require re-touching every site
`[COMPLETED WITH EXCLUSIONS]` already wired for no expressive gain.

---

#### `[EXPANDED]`
**TODO.md Format**: `- **Status**: [EXPANDED]`
**state.json Value**: `"status": "expanded"`
**Meaning**: Parent task has been expanded into subtasks; work continues in subtasks.

**Valid Transitions**: Terminal state. No further transitions (work continues in subtasks).

**Note**: Any non-terminal status can transition to `[EXPANDED]` when task is divided.

**Required Information**:
- `- **Subtasks**: {list}` in TODO.md
- `"subtasks": [...]` array in state.json

---

## TODO.md vs state.json Mapping

| TODO.md Marker | state.json Value | Description |
|----------------|------------------|-------------|
| `[NOT STARTED]` | `not_started` | Task not begun |
| `[RESEARCHING]` | `researching` | Research in progress |
| `[RESEARCHED]` | `researched` | Research completed |
| `[PLANNING]` | `planning` | Planning in progress |
| `[PLANNED]` | `planned` | Plan created |
| `[IMPLEMENTING]` | `implementing` | Implementation in progress |
| `[PR READY]` | `pr_ready` | `task_type == "pr"` only; implementation complete, awaiting `/merge` |
| `[COMPLETED]` | `completed` | Task fully completed |
| `[PARTIAL]` | `partial` | Implementation partially complete |
| `[BLOCKED]` | `blocked` | Task blocked |
| `[ABANDONED]` | `abandoned` | Task abandoned |
| `[EXPANDED]` | `expanded` | Task expanded into subtasks |

**Conversion Rules**:
- TODO.md uses uppercase with underscores in brackets: `[NOT STARTED]`
- state.json uses lowercase with underscores: `"not_started"`
- Conversion: Remove brackets, convert to lowercase

---

## Command → Status Mapping

| Command | Preflight Status | Postflight Status | Notes |
|---------|------------------|-------------------|-------|
| `/research` | `[RESEARCHING]` | `[RESEARCHED]` | Creates research report |
| `/plan` | `[PLANNING]` | `[PLANNED]` | Creates implementation plan |
| `/revise` | N/A (preflight status update skipped by design) | `[PLANNED]` | Creates new plan version; `skill-reviser/SKILL.md` documents skipping the intermediate mid-revision status entirely (see the removal note above) |
| `/implement` | `[IMPLEMENTING]` | `[COMPLETED]` or `[PARTIAL]` | Executes implementation |
| `/review` | N/A | N/A | Creates new tasks |

**Preflight**: Status updated BEFORE work begins  
**Postflight**: Status updated AFTER work completes

### The Effort-Conditional Default with a `--fast` Escape Hatch

The table above describes each command's OWN preflight/postflight status pair in isolation.
`/orchestrate`'s own routing decision for a fresh (`not_started`) task is a separate concern. The
default `/orchestrate` lifecycle is `research → plan → implement`: a `not_started` task
dispatches straight to research, before any planner assessment runs at all. Passing `--fast`
inverts this for that one invocation, reverting to the pre-research-first `plan → implement`
lifecycle: the task dispatches straight to the planner instead, which itself decides whether
research is needed anyway (an opening assessment step in `agents/planner-agent.md`) and requests
a research phase on demand — via the `needs_research` verdict noted under `[RESEARCHING]`'s "Two
producers" above — only when its own assessment says the description does not suffice. `--hard`
does NOT skip research (only the literal effort value `fast` alters routing); `--research` (the
phase-forcing flag) still runs `/research` unconditionally first, independent of and overriding
this default, even under `--fast`. See `docs/architecture/orchestrate-state-machine.md`'s "The
`needs_research` Fork" section for the full routing narrative, the worked-example flows, and the
state table detail — this document only notes the status-marker-level consequence (a second
producer for `[RESEARCHING]`), not the routing mechanics themselves.

---

### Target Arguments vs. Resting States

The status value passed to `update-task-status.sh` as `$target_status` is a **request**, not a
guarantee. `update-task-status.sh`'s own `map_status()` function resolves the actual persisted
status from the target argument AND the `preflight`/`postflight` operation together — the same
target argument can resolve to different resting states depending on which operation it is paired
with. The value that is actually written to `state.json` and `TODO.md` is the **resting state**;
the two are not always equal.

**Concrete instance**: `postflight:pr_ready` resolves to a `completed` resting state
(`STATE_STATUS="completed"`), regardless of task type. A non-`pr` task can therefore pass
`pr_ready` as the target argument to a `postflight` call — using `--allow-pr-ready` to pass the
script's guard — and still come to rest at `[COMPLETED]`, never at `[PR READY]`. The `[PR READY]`
resting state defined above is reachable only via a `preflight:pr_ready` call, which the guard
permits unconditionally only for `task_type == "pr"`.

---

## Valid Transition Diagram

```
                    ┌─────────────────────────────────────────┐
                    │         Any Non-Terminal Status          │
                    │                                         │
                    │  NOT STARTED, RESEARCHING, RESEARCHED,  │
                    │  PLANNING, PLANNED, IMPLEMENTING,       │
                    │  PARTIAL, BLOCKED                       │
                    └──────────────┬──────────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                     │
              ▼                    ▼                     ▼
        /research             /plan, /revise        /implement
              │                    │                     │
              ▼                    ▼                     ▼
        [RESEARCHING]        [PLANNING]           [IMPLEMENTING]
              │                    │              ┌──────┴──────┐
              ▼                    ▼              ▼             ▼
        [RESEARCHED]         [PLANNED]      [COMPLETED]   [PARTIAL]

    Note: /revise skips the intermediate status update on preflight by design (see the
    removal note above) and lands directly on [PLANNED] via postflight, same as /plan.

    Terminal states (no further transitions):
    [COMPLETED], [ABANDONED], [EXPANDED]
```

---

## Status Update Protocol

Status updates are performed by `skill-base.sh` functions that all workflow skills source:

- `skill_preflight_update()` -- called BEFORE work begins. Sets the in-progress status variant (e.g., `[RESEARCHING]`, `[IMPLEMENTING]`) in both `state.json` and `TODO.md`.
- `skill_postflight_update()` -- called AFTER work completes. Sets the final status variant (e.g., `[RESEARCHED]`, `[COMPLETED]`) and links artifacts.

Both functions delegate to `update-task-status.sh` for the actual atomic file updates.

For manual corrections and recovery operations outside the normal workflow, use the `skill-status-sync` skill, which provides standalone preflight, postflight, and artifact-link operations.

### Preflight Status Update

**When**: BEFORE work begins  
**Path**: `skill_preflight_update()` in `skill-base.sh` -> `update-task-status.sh`  
**Purpose**: Signal work has started  
**Example**: `/research` calls `skill_preflight_update()` to set `[RESEARCHING]` before beginning research

### Postflight Status Update

**When**: AFTER work completes  
**Path**: `skill_postflight_update()` in `skill-base.sh` -> `update-task-status.sh`  
**Purpose**: Signal work has finished and link artifacts  
**Example**: `/research` calls `skill_postflight_update()` to set `[RESEARCHED]` after creating research report

---

## Atomic Synchronization

`update-task-status.sh` performs updates atomically in this order:
1. `state.json` (status field, timestamps, artifact_paths)
2. `TODO.md` (status marker, timestamps, artifact links)
3. Plan file (phase status markers, if plan exists)

All files are updated via temp-file + atomic rename so no partial state is written on failure.

---

## Validation Rules

### Status Transition Validation

**Permissive Rule**: Any command can run from any non-terminal status.

**Terminal States** (block all transitions):
- `[COMPLETED]` - No further transitions
- `[ABANDONED]` - No further transitions (use `/task --recover` to restart)
- `[EXPANDED]` - No further transitions (work continues in subtasks)

### Required Fields Validation

**For `[BLOCKED]` status**:
- MUST include `blocking_reason` or `blocked_by` parameter
- MUST include `- **Blocked**: YYYY-MM-DD` timestamp in TODO.md

**For `[ABANDONED]` status**:
- MUST include `abandonment_reason` parameter
- MUST include `- **Abandoned**: YYYY-MM-DD` timestamp in TODO.md

**For `[EXPANDED]` status**:
- MUST include `subtasks` array with subtask numbers
- MUST include `- **Subtasks**: {list}` in TODO.md

**For completion statuses** (`[RESEARCHED]`, `[PLANNED]`, `[COMPLETED]`):
- MUST include `validated_artifacts` array with artifact paths
- Artifacts MUST exist on disk and be non-empty

---

## References

- **state-management.md**: Complete state management standard
- **skill-base.sh**: Source for `skill_preflight_update()` and `skill_postflight_update()` functions
- **update-task-status.sh**: Atomic status update script called by skill-base.sh functions
- **skill-status-sync/SKILL.md**: Standalone skill for manual status corrections and recovery

---

**Last Updated**: 2026-01-05
