# Return Metadata File Schema

## Overview

Agents write structured metadata to files instead of returning JSON to the console. This enables reliable data exchange without console pollution and avoids the limitation where Claude treats JSON output as conversational text.

## File Location

```
specs/{NNN}_{SLUG}/.return-meta.json
```

Where:
- `{N}` = Task number (unpadded)
- `{SLUG}` = Task slug in snake_case

Example: `specs/1_setup_lsp_config/.return-meta.json`

## Schema

```json
{
  "status": "researched|planned|implemented|needs_research|partial|failed|blocked",
  "artifacts": [
    {
      "type": "report|plan|summary|implementation|handoff",
      "path": "specs/001_setup_lsp_config/reports/01_lsp-config-research.md",
      "summary": "Brief 1-sentence description of artifact"
    }
  ],
  "next_steps": "Run /plan 1 to create implementation plan",
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "general-research-agent",
    "duration_seconds": 180,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "general-research-agent"]
  },
  "memory_candidates": [
    {
      "content": "Description of reusable knowledge",
      "category": "TECHNIQUE|PATTERN|CONFIG|WORKFLOW|INSIGHT",
      "source_artifact": "specs/001_setup_lsp_config/reports/01_lsp-config-research.md",
      "confidence": 0.85,
      "suggested_keywords": ["keyword1", "keyword2"]
    }
  ],
  "modified_files": [
    "specs/001_setup_lsp_config/reports/01_lsp-config-research.md"
  ],
  "proposed_file_scope": [
    "agent-system/extensions/core/scripts/example-script.sh"
  ],
  "errors": [
    {
      "type": "validation|execution|timeout",
      "message": "Error description",
      "recoverable": true,
      "recommendation": "How to fix"
    }
  ]
}
```

### Multiple Sequential Writers

`.return-meta.json` may be written by more than one process within a single `/orchestrate`
invocation — e.g. an implementation agent writes the rich object first, then
`skill-orchestrate`'s own postflight stage writes again at full-loop termination to update
`status`/`metadata`. Any writer that runs after an earlier writer in the same invocation MUST
merge onto the existing file (read-modify-write) rather than overwrite wholesale, touching only
the fields it owns. `modified_files`, `completion_data`, `memory_candidates`, `reflection`,
`proposed_file_scope`, and `artifacts` are producer-owned by the implementation agent and MUST
survive a later writer's update untouched.

## Field Specifications

### status (required)

**Type**: enum
**Values**: Contextual success values or error states

This table is the **normative** status vocabulary for `.return-meta.json`,
`specs/.orchestration/.return-meta-multi-{session_id}.json`, and — by reference — `.orchestrator-handoff.json`'s `status`
field (see `docs/architecture/handoff-schema.md`, which cross-references this table rather than
restating the enumeration independently). Any writer of one of those three files should draw its
`status` value from this table rather than re-deriving or restating it elsewhere.

| Value | Description |
|-------|-------------|
| `in_progress` | Work started but not finished (early metadata, see below) |
| `researched` | Research completed successfully |
| `planned` | Plan created successfully |
| `implemented` | Implementation completed successfully |
| `needs_research` | Planner-only outcome: the planner declined to write a plan and is asking for a research phase (see below) |
| `partial` | Partially completed, can resume |
| `failed` | Failed, cannot resume without fix |
| `blocked` | Blocked by external dependency |

**Note**: Never use `"completed"` - it triggers Claude stop behavior.

**`needs_research`**: written only by `planner-agent` (and, in principle, an extension planner
agent) when the task description plus what the agent can read in the codebase does not suffice to
write a plan meeting `plan-format.md`. It carries an empty `artifacts` array by design — no plan
is written on this path — and requires a populated `research_questions` array (a JSON array of
strings; see `context/reference/state-management-schema.md`) naming the focused questions a
research phase must answer. This is distinct from a normal `planned`/`researched` outcome and from
`user_decision` (a question only the user's judgment can answer, not an agent's).

**Early Metadata Pattern**: Agents should write metadata with `status: "in_progress"` at the START
of execution (Stage 0), then update to the final status on completion. This ensures metadata exists
even if the agent is interrupted. See `.opencode/context/patterns/early-metadata-pattern.md`.

### Three distinct vocabularies sharing the same words

The words "completed" and "implemented" appear in three separate, legitimately different
enumerations across the agent system. Conflating them is a recurring mistake — do not "fix" a
correct writer of one vocabulary by imposing another's rule.

| Vocabulary | Governs | `"completed"` valid? |
|------------|---------|----------------------|
| Skill-status vocabulary (this table) | `.return-meta.json`, `specs/.orchestration/.return-meta-multi-{session_id}.json`, and `.orchestrator-handoff.json`'s `status` field | No — forbidden, use `"implemented"` |
| state.json task status | `specs/state.json`'s `active_projects[].status` field and the corresponding TODO.md `[COMPLETED]` marker | Yes — this is the correct terminal value |
| Lifecycle/notification status | `orchestrator-postflight.sh`'s wezterm tab-color/TTS notification mapping | Yes — an unrelated vocabulary describing UI notification state, not skill or task status |

A writer that is correct for its own vocabulary should never be changed to match a different
vocabulary's rule just because the two files use an overlapping word.

### artifacts (required)

**Type**: array of objects

Each artifact object:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | `report`, `plan`, `summary`, `implementation`, `handoff` |
| `path` | string | Yes | Relative path from project root |
| `summary` | string | Yes | Brief 1-sentence description |

**A bare-string array element is never valid, in any context.** `"artifacts": ["path/to/file.md"]`
is not an accepted shorthand for the object shape above — every element MUST be an object carrying
non-empty `type`, `path`, and `summary`. This is enforced at four layers, none of which alone is
sufficient:

| Layer | Posture |
|-------|---------|
| This normative doc | Strict. A bare-string array is never valid, in any context. |
| `validate-return-meta.sh` | Strict. Bare strings FAIL (exit 1). `--fix` performs the unambiguous repair on request, never implicitly. |
| Consumer chokepoint (`skill_read_metadata` in `scripts/skill-base.sh`) | Normalizes so the artifact link is not lost, but emits a loud stderr notice AND records an `ARTIFACTS_SHAPE_MISMATCH` system defect. |
| Agent contracts | Strict. Every dispatchable agent that writes `.return-meta.json` carries a correct inline template; `lint-agent-contracts.sh` Check F fails the deploy if one does not. |

**Parallel but not identical to `.orchestrator-handoff.json`'s `artifacts` shape.**
`.orchestrator-handoff.json` has its own `artifacts` object shape, defined separately in
`handoff-schema.md`'s `### artifacts (required)` section. Both forbid bare-string elements, but
they differ in one field: `.return-meta.json` requires `summary`, while
`.orchestrator-handoff.json` treats `summary` as optional. A worked example from one file is not
directly transplantable to the other — check which file you are writing before copying a template.

The canonical copyable template every agent uses, the classification rule for which agents must
carry it, and the path-segment type-inference table are recorded in one place:
`context/contracts/return-meta-artifacts-template.md` (source:
`agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md`). Copy the
template from that fragment, not from this schema document — this document states the rule, the
fragment holds the exact copyable text.

### next_steps (optional)

**Type**: string
**Description**: What the user/orchestrator should do next

### dispatch_seq (optional)

**Type**: integer
**Description**: Echoed verbatim from this dispatch's own identity — the delegation context's
`dispatch_seq` field, or (equivalently) the dispatch file's Identity section `dispatch_seq` line.
Producer-owned: the agent copies the value it was given, never invents or increments one.

**Placement**: top-level, exactly like `.orchestrator-handoff.json`'s own `dispatch_seq` field
(`handoff-schema.md`) — the two files share this field's meaning and nesting so a single
identity-comparison consumer (e.g. `orchestrate-recover-outcome.sh`) can read either without a
file-specific special case. This is the ONE field this schema and the handoff schema agree to
nest identically; see the `phases_completed`/`phases_total` callout immediately below for a field
where they deliberately do not.

**Absent means**: the writer predates this contract, or is a call path (e.g. a non-`/orchestrate`
`/research`/`/plan`/`/implement` invocation) that never received a `dispatch_seq` to echo. A
consumer gating on this field MUST degrade gracefully on an absent value — emit a named `WARN`
and fall back to mtime-only discrimination — never treat absence as a hard failure. See
`orchestrate-recover-outcome.sh`'s own header for the consumer-side contract.

### metadata (required)

**Type**: object

| Field | Required | Description |
|-------|----------|-------------|
| `session_id` | Yes | Session ID from delegation context |
| `agent_type` | Yes | Name of agent (e.g., `general-research-agent`) |
| `duration_seconds` | No | Execution time |
| `delegation_depth` | Yes | Nesting depth in delegation chain |
| `delegation_path` | Yes | Array of delegation steps |

Additional optional fields for specific agent types:
- `findings_count` - Number of research findings
- `phases_completed` - Implementation phases completed
- `phases_total` - Total implementation phases

### `phases_completed` / `phases_total` nesting collision (cross-file)

These same two field names appear in `.orchestrator-handoff.json` too, with the OPPOSITE nesting
rule. A writer instruction correct for one file is wrong for the other — this has caused real
off-schema writes (agents pattern-matching one file's worked example onto the other).

| File | Nesting |
|------|---------|
| `.return-meta.json` (this file) | Nested under `metadata` (or under `partial_progress` for a `partial`/interrupted return) — never top-level |
| `.orchestrator-handoff.json` | Always top-level — never nested under any object |

When writing either file, check which one you are writing before reusing a worked example from
the other.

### started_at (optional)

**Type**: string (ISO8601 timestamp)
**Include if**: status is `in_progress` (early metadata)

Timestamp when agent started execution. Used to calculate duration on completion or detect
long-running interrupted agents.

### partial_progress (optional)

**Type**: object
**Include if**: status is `in_progress` or `partial`

Tracks progress for interrupted or partially completed work:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `stage` | string | Yes | Current execution stage (e.g., "strategy_determined", "phase_2_completed") |
| `details` | string | Yes | Human-readable description of progress |
| `phases_completed` | number | No | For implementation agents: phases completed |
| `phases_total` | number | No | For implementation agents: total phases |
| `handoff_path` | string | No | Path to handoff artifact written before context exhaustion (see `handoff-artifact.md`) |

**Purpose**: Enables skill postflight to determine resume point and provide user guidance when
an agent is interrupted before completion.

### completion_data (optional)

**Type**: object
**Include if**: status is `implemented` (required for successful implementations)

Contains fields needed for task completion processing. Skills extract this data during postflight to update state.json.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `completion_summary` | string | Yes | 1-3 sentence description of what was accomplished |
| `roadmap_items` | array of strings | No | Explicit ROADMAP.md item texts this task addresses (non-meta tasks only) |

**Notes**:
- `completion_summary` is mandatory for all `implemented` status returns
- `roadmap_items` is optional and only relevant for non-meta tasks
- Skills propagate these fields to state.json for use by `/todo` command
- These two fields live exclusively here — never in `.orchestrator-handoff.json` — and are
  written to state.json by exactly one shared function, `skill_propagate_completion_summary`
  in `scripts/skill-base.sh`. On the `/orchestrate` path they are read exclusively via
  `orchestrate-recover-outcome.sh`, regardless of whether a handoff is present for that dispatch.
  See `docs/architecture/handoff-schema.md`'s "Outcome Channels" section for the full rationale.

### comparator (optional)

**Type**: object
**Include if**: the task is a lean4 implementation dispatch AND `--compare` was passed
(`compare_flag == true`). Omitted entirely when `--compare` was not requested — there is no
`"ran": false` "not requested" record; `"ran": false` is reserved for a request that reached
preflight and stopped there without invoking the runner.

Carries the result of the advisory Comparator gate run by `lean-implementation-agent.md` /
`lean-implementation-hard-agent.md`'s Final Verification Stage against the snapshot Challenge
and the implemented Solution, scoped to the plan's named theorems. This block is lean-only and
does not alter the pre-existing `verification` block's keys (`verification_passed`,
`sorry_count`, `vacuous_count`, `axiom_count`, `build_passed`).

| Field | Type | Required | Description |
|-------|------|----------|--------------|
| `ran` | boolean | Yes | Whether the Comparator runner was actually invoked. `false` means a preflight check stopped the gate before invocation. |
| `verdict` | string | Yes | The verdict value. Any value other than `verified` MUST be surfaced loudly by postflight. |
| `verdict_source` | string | Yes | `runner` or `preflight` — which vocabulary `verdict` is drawn from (see table below). |
| `reason_detail` | string | No | Human-readable detail explaining a non-`verified` verdict. |
| `underlying_verdict` | string | No | Present only when `verdict` is `definition_hole_needs_human`; carries the runner's underlying classification. |
| `theorem_names` | array of strings | Yes | The theorem names checked, read from the Challenge manifest. |
| `permitted_axioms` | array of strings | Yes | The axiom whitelist passed to the runner. |
| `solution_module` | string | No | The derived Solution module path (absent when preflight stopped before derivation). |
| `challenge_commit` | string | No | The Challenge commit recorded in the manifest. |
| `solution_commit` | string | No | The post-implementation `HEAD` commit checked against the Challenge. |
| `runtime_seconds` | number | Yes | Wall-clock elapsed seconds for the Comparator invocation (0 when `ran` is `false`). |

**Verdict vocabularies**:

| Source | Verdicts |
|--------|----------|
| `runner` (from `lean-comparator-run.sh`, unchanged, closed) | `verified`, `statement_mismatch`, `axiom_violation`, `kernel_rejected`, `definition_hole_needs_human`, `comparator_unavailable`, `timeout`, `config_error`, `unclassified_failure` |
| `preflight` (agent-side, run before the runner is invoked) | `challenge_missing`, `challenge_drift`, `solution_module_unresolved`, `solution_module_ambiguous` |

**Notes**:
- The gate is **advisory only**: a `comparator` block, whatever its `verdict`, MUST NOT cause
  `verification_passed` to be set `false`, MUST NOT downgrade `status` to `partial`, and MUST NOT
  block completion. This is a binding constraint restated here so a reader of this schema alone,
  without the design record, still gets it.
- A run where `--compare` was not passed records no `comparator` block at all — see the
  **Include if** line above.
- This section documents a lean-only block. It does not alter the `verification` block's keys.

### memory_candidates (optional)

**Type**: array of objects (0-3 items)
**Include if**: Agent discovered reusable patterns, techniques, or insights during execution

Structured memory candidates emitted by agents for downstream processing. Candidates are stored in state.json task entries and consumed by `/todo` during archival.

Each candidate object:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `content` | string | Yes | Description of the reusable knowledge (~300 tokens max) |
| `category` | string | Yes | One of: `TECHNIQUE`, `PATTERN`, `CONFIG`, `WORKFLOW`, `INSIGHT` |
| `source_artifact` | string | Yes | Path to the artifact that produced this candidate |
| `confidence` | number | Yes | Float 0-1 indicating reusability confidence |
| `suggested_keywords` | array of strings | Yes | Keywords for memory index retrieval |

**Category Definitions**:
- `TECHNIQUE` - A reusable debugging, testing, or problem-solving technique
- `PATTERN` - A code or architecture pattern discovered in the codebase
- `CONFIG` - A configuration discovery (tool settings, flags, options)
- `WORKFLOW` - A workflow or process insight (command sequences, operational patterns)
- `INSIGHT` - A general insight about the project, domain, or tooling

**Confidence Scoring Guidance**:
- >= 0.8: Clearly reusable patterns or configurations with broad applicability
- 0.5-0.8: Potentially useful techniques or workflows, context-dependent
- < 0.5: Speculative insights, may not generalize

**Notes**:
- Agents emit 0-3 candidates per execution; absence is valid behavior
- Skill postflight propagates candidates to state.json task entries with append semantics
- `/todo` consumes candidates during archival
- The field uses `// []` fallback in all jq reads for backward compatibility

### reflection (optional)

**Type**: object
**Include if**: status is `implemented` and the agent captured a completion-time reflection
(optional even then)

A structured completion-time reflection, produced alongside `completion_data` and
`memory_candidates` by implementation agents. Unlike `memory_candidates` (which accumulates
across a task's history with append semantics), `reflection` is a single top-level object that
skill postflight propagates to the `state.json` task entry with **overwrite** (not append)
semantics — the latest implementation's reflection replaces any prior one.

Each `reflection` object has four string sub-fields:

| Field | Type | Required | Description |
|-------|------|----------|--------------|
| `what_worked` | string | No | ~1-3 sentences on what approach or technique worked well |
| `what_was_hard` | string | No | ~1-3 sentences on what was difficult or friction-prone |
| `what_was_missed` | string | No | ~1-3 sentences on what was overlooked, deferred, or missed initially |
| `successes` | string | No | ~1-3 sentences summarizing concrete successes |

All four fields are free text (all-or-nothing per agent judgment — an agent may populate all
four, a subset, or omit the object entirely if there is nothing worth capturing).

**Notes**:
- `reflection` is a top-level sibling of `memory_candidates`, not nested under `completion_data`.
- Skill postflight (the `orchestrator-postflight.sh` completion seam) reads this field, logs it
  once as a `reflection` event to the unified event store, and writes it to the matching
  `active_projects[]` entry in `state.json`, gated on `operation_type == "implement" && status ==
  "implemented"`.
- The write uses overwrite semantics: `state.json`'s `reflection` field always reflects the most
  recent implementation's reflection, not a history.
- Absence of `reflection` is valid behavior — it is optional even on a successful implementation.

### modified_files (optional)

**Type**: optional `string[]` at the **top level** of `.return-meta.json` — a sibling of
`memory_candidates` and `reflection`, not nested under `completion_data`.

**Include if**: the operation is `implement` (populated by implementation agents). Unused and
absent for `research` and `plan` operations.

**Path form**: entries are **repo-relative** paths, relative to the repository root. This is
load-bearing and must not be left implied: the skill postflight commit pipeline
(`orchestrator-postflight.sh`) passes these entries straight to `git add`, invoked from the repo
root, alongside other repo-relative literals in the same invocation. Absolute paths are not
permitted.

**Granularity**: entries are **individual file paths**. Directory prefixes are **not**
permitted.

**Empty behavior**: if no files were touched, write `"modified_files": []` — **never omit the
field**. An empty or absent array is non-fatal: the consumer falls back to staging the fixed
task-directory scope and emits a loud stderr warning. It never escalates to `git add -A`.

**Provenance**: the flattened, deduplicated union of every phase's every objective's
`files_touched` array from that task's progress files. See
[Progress File Schema](progress-file.md) for the `files_touched` field this is summed from, and
[Git Staging Scope Contract](../standards/git-staging-scope.md) for the fullest narrative
description of the staging contract this field drives.

#### How Implementation Agents Populate modified_files

This is the single producer-side procedure every implementation agent follows to arrive at the
`modified_files` value above. It serves both agents that maintain a progress file
(`progress-file.md`) and agents that do not — the four-step shape is the same either way; only
step 2's accumulation site differs.

1. **Track on write** — at the moment of every `Write`/`Edit`, append that file's repo-relative
   path to the current accumulation site immediately. Do not attempt to reconstruct the list from
   memory at the end of a run; by then earlier edits are easy to forget.
2. **Accumulate** — agents with a progress file append the path to the current objective's
   `files_touched` array, additively (never overwriting paths recorded earlier for the same
   objective), per `progress-file.md`. Agents without a progress file keep a single flat list of
   touched paths for the run instead.
3. **Sum** — before writing final metadata, flatten every phase's every `objectives[].files_touched`
   array (or the flat run-list, for agents without a progress file) into one list and de-duplicate
   it.
4. **Emit** — write the deduped list as the top-level `modified_files` field in
   `.return-meta.json`, as a sibling of `memory_candidates` and `reflection`.

**Field constraints** (restated here so an agent following this section alone cannot get them
wrong — see the field specification above for the authoritative statement):
- **Repo-relative**, never absolute.
- **Individual file paths**, never directory prefixes.
- **`[]` when nothing was touched — never omit the field.**

**Paths under the task directory are harmless if listed** — the fixed task-directory scope
already stages `specs/{NNN}_{SLUG}/` regardless. The load-bearing case this procedure exists for
is every repo-tracked file touched **outside** the task directory: those are staged only if this
procedure reports them here.

**Wrapper-only or non-file-editing agents**: emitting `modified_files: []` is correct schema
behavior for an agent whose work does not touch repo-tracked files (for example, a mailbox
triage run that only mutates IMAP/maildir state) — not a defect to be engineered around. Such an
agent has no use for the progress-file/objectives machinery in step 2 and should not adopt it
solely to populate this field.

**Retrospective vs. prospective**: `modified_files` (and the `files_touched` it is summed from)
is **retrospective** — what an agent actually touched, self-reported at implementation time, for
git staging. This is a distinct concept from `state.json`'s `file_scope`, which is
**prospective** — what a task is declared to touch, set at creation time, for lock-overlap
detection. The two are complementary and are never merged or reconciled against each other. See
[State Management Schema](../reference/state-management-schema.md), section "File Scope Field",
for the `file_scope` side of this contrast.

### proposed_file_scope (optional)

**Type**: optional `string[]` at the **top level** of `.return-meta.json` — a sibling of
`modified_files` and `memory_candidates`, not nested under `completion_data`.

**Include if**: the operation is `research` and research discovered concrete file targets not
already covered by the task's declared `file_scope`. Unused and absent for `plan` and
`implement` operations.

Research agents populate this field when research discovers concrete files the implementation
will need to touch, but which the task's `file_scope` (declared at creation time, per
`docs/reference/standards/multi-task-creation-standard.md` Component 4a's "Unknown-Footprint
Convention") does not yet name. It is a proposal of **additions only** — the consumer
union-merges it into `active_projects[].file_scope` and never removes an existing entry. An
absent, `null`, or empty (`[]`) value is a valid no-op: it means research found nothing beyond
what was already declared.

**Consumer**: `agent-system/extensions/core/scripts/update-task-status.sh`'s `--file-scope-add`
flag, invoked at research postflight (`operation == postflight && target_status == research`).
The merge runs inside that script's existing single mutex-guarded `state-write.sh` write — see
Component 4a's "Unknown-Footprint Convention" subsection (cross-referenced above) for the full
producer/consumer narrative.

**Producer ownership**: consistent with the "Multiple Sequential Writers" section above,
`proposed_file_scope` is producer-owned by the research agent that discovers the paths, and MUST
survive any later writer's read-modify-write update to this file untouched.

**Path form**: entries are repo-relative paths, matching `modified_files`'s path convention.

### research_questions (optional)

**Type**: optional `string[]` at the **top level** of `.return-meta.json` — a sibling of
`proposed_file_scope` and `modified_files`.

**Include if**: `status` is `needs_research`. Required and non-empty on that path; absent
otherwise.

`planner-agent` (and, in principle, an extension planner agent) populates this field with a
focused list of the questions a research phase must answer before a plan meeting
`plan-format.md` can be written. It is producer-owned by the planner, consistent with the
"Multiple Sequential Writers" section above.

**Consumer**: `agent-system/extensions/core/scripts/skill-base.sh`'s `skill_postflight_update()`
reads this field off the planner's `.return-meta.json` and forwards it as
`agent-system/extensions/core/scripts/update-task-status.sh --research-questions=<json-array>`,
which persists it to the task's `research_questions` field in `state.json` with
overwrite-on-write (not append) semantics — see
`context/reference/state-management-schema.md`. It is later read back at research-dispatch
build time and joined into a single string passed as `--focus` to
`orchestrate-build-dispatch.sh`.

### user_decision (optional)

**Type**: object at the **top level** of `.return-meta.json` — a sibling of `modified_files` and
`memory_candidates`, not nested under `completion_data`.

**Include if**: the agent hit a choice that genuinely requires the user's judgment (a preference
the artifacts cannot infer, an external cost or risk the user must accept, or an ambiguity
research cannot resolve). Absent in every other case — this is not a routine field.

Shape: `{question, options: [...], recommended, blocking: true|false}`. See
`context/standards/user-decision-contract.md` for the full contract — when to set it, when NOT
to, the blocking/non-blocking distinction, and how postflight relays it as an `ask_user` verdict.
This subsection does not restate that contract.

**Producer ownership**: consistent with the "Multiple Sequential Writers" section above,
`user_decision` is producer-owned by the agent that sets it, and MUST survive any later writer's
read-modify-write update to this file untouched.

### errors (optional)

**Type**: array of objects
**Include if**: status is `partial`, `failed`, or `blocked`

Each error object:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Error category |
| `message` | string | Yes | Human-readable error message |
| `recoverable` | boolean | Yes | Whether retry may succeed |
| `recommendation` | string | Yes | How to fix or proceed |

## Agent Instructions

### Writing Metadata

At the end of execution, agents MUST:

1. Create the metadata file:
```bash
mkdir -p "specs/${padded_num}_${task_slug}"
```

2. Write the JSON:
```json
// Write to specs/{NNN}_{SLUG}/.return-meta.json
{
  "status": "researched",
  "artifacts": [...],
  "metadata": {...}
}
```

3. Return a brief summary (NOT JSON) to the console:
```
Research completed for task {N}:
- Found 5 relevant implementation patterns
- Identified configuration strategy using modular approach
- Created report at specs/001_setup_lsp_config/reports/01_lsp-config-research.md
```

### Reading Metadata (Skill Postflight)

Skills read the metadata file during postflight:

```bash
# Read metadata file
metadata_file="specs/${padded_num}_${task_slug}/.return-meta.json"
if [ -f "$metadata_file" ]; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary' "$metadata_file")
fi
```

### Cleanup

After postflight, delete the metadata file:

```bash
rm -f "specs/${padded_num}_${task_slug}/.return-meta.json"
```

## Examples

### Research Success

```json
{
  "status": "researched",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/001_setup_lsp_config/reports/01_lsp-config-research.md",
      "summary": "Research report with 5 plugin patterns and configuration strategy"
    }
  ],
  "next_steps": "Run /plan 1 to create implementation plan",
  "proposed_file_scope": [
    "lua/neotex/plugins/lsp/servers/example-server.lua"
  ],
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "general-research-agent",
    "duration_seconds": 180,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "general-research-agent"],
    "findings_count": 5
  }
}
```

### Implementation Success (Non-Meta)

```json
{
  "status": "implemented",
  "artifacts": [
    {
      "type": "implementation",
      "path": "src/config/server-setup.ext",
      "summary": "Server configuration with 4 integrations"
    },
    {
      "type": "summary",
      "path": "specs/1_setup_lsp_config/summaries/01_lsp-config-summary.md",
      "summary": "Implementation summary with verification results"
    }
  ],
  "completion_data": {
    "completion_summary": "Configured 4 server integrations with automated installation. Implemented keybindings for common actions.",
    "roadmap_items": ["Configure server integrations"]
  },
  "memory_candidates": [
    {
      "content": "When configuring multiple server integrations, use a shared base config table and merge per-server overrides with vim.tbl_deep_extend. This avoids duplication and makes adding new servers trivial.",
      "category": "PATTERN",
      "source_artifact": "specs/001_setup_lsp_config/summaries/01_lsp-config-summary.md",
      "confidence": 0.85,
      "suggested_keywords": ["lsp", "server-config", "vim.tbl_deep_extend", "merge"]
    }
  ],
  "reflection": {
    "what_worked": "Reading the existing server-config module before editing revealed a shared base table pattern that made the merge approach obvious.",
    "what_was_hard": "Determining which server-specific overrides were safe to merge versus which needed to remain isolated took a few iterations.",
    "what_was_missed": "The initial pass missed one server's custom on_attach hook, caught only during final verification.",
    "successes": "All 4 integrations configured and verified working with a single shared base config, avoiding the duplication the prior setup had."
  },
  "modified_files": [
    "src/config/server-setup.ext",
    "src/config/keybindings.ext"
  ],
  "next_steps": "Review implementation and verify with /test",
  "metadata": {
    "session_id": "sess_1736700000_def456",
    "agent_type": "general-implementation-agent",
    "duration_seconds": 3600,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "implement", "general-implementation-agent"],
    "phases_completed": 4,
    "phases_total": 4
  }
}
```

### Early Metadata (In Progress)

Written at Stage 0, before substantive work begins:

```json
{
  "status": "in_progress",
  "started_at": "2026-01-28T10:30:00Z",
  "artifacts": [],
  "partial_progress": {
    "stage": "initializing",
    "details": "Agent started, parsing delegation context"
  },
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "general-research-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "general-research-agent"]
  }
}
```

### Planning Success

Written by planner-agent after successful plan creation:

```json
{
  "status": "planned",
  "artifacts": [
    {
      "type": "plan",
      "path": "specs/001_setup_lsp_config/plans/01_lsp-config-plan.md",
      "summary": "Implementation plan with 4 phases and dependency analysis"
    }
  ],
  "next_steps": "Run /implement 1 to execute the plan",
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "planner-agent",
    "duration_seconds": 240,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "plan", "planner-agent"]
  }
}
```

### Implementation Partial

Written when implementation is interrupted or fails mid-execution:

```json
{
  "status": "partial",
  "artifacts": [
    {
      "type": "summary",
      "path": "specs/001_setup_lsp_config/summaries/01_lsp-config-summary.md",
      "summary": "Partial implementation summary with 2 of 4 phases completed"
    }
  ],
  "partial_progress": {
    "stage": "phase_2_completed",
    "details": "Phases 1-2 completed, phase 3 failed due to build error",
    "phases_completed": 2,
    "phases_total": 4
  },
  "errors": [
    {
      "type": "execution",
      "message": "Build failed: missing dependency in configuration",
      "recoverable": true,
      "recommendation": "Install dependency and run /implement 1 to resume from phase 3"
    }
  ],
  "metadata": {
    "session_id": "sess_1736700000_ghi789",
    "agent_type": "general-implementation-agent",
    "duration_seconds": 1800,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "implement", "general-implementation-agent"],
    "phases_completed": 2,
    "phases_total": 4
  }
}
```

For other scenarios (meta tasks, blocked), combine the schema fields above.

**Note**: The file-based metadata format supersedes the earlier console-based `subagent-return.md` pattern. See that file for historical context only.

## Related Documentation

- `.opencode/context/formats/subagent-return.md` - Original console-based format
- `.opencode/context/patterns/postflight-control.md` - Marker file protocol
- `.opencode/context/patterns/file-metadata-exchange.md` - File I/O patterns
- `.opencode/context/patterns/early-metadata-pattern.md` - Early metadata creation pattern
- `.opencode/rules/state-management.md` - State update patterns
- `.opencode/rules/error-handling.md` - Error types including mcp_abort_error and delegation_interrupted
