# State Management Schema Reference

Complete schema reference for state.json, TODO.md, and artifact formats. For behavioral rules (transitions, update patterns), see `.claude/rules/state-management.md`.

## state.json Full Structure

```json
{
  "next_project_number": 346,
  "active_projects": [
    {
      "project_number": 334,
      "project_name": "task_slug_here",
      "status": "planned",
      "task_type": "general",
      "effort": "4 hours",
      "created": "2026-01-08T10:00:00Z",
      "last_updated": "2026-01-08T14:30:00Z",
      "dependencies": [332, 333],
      "artifacts": [
        {
          "type": "research",
          "path": "specs/334_task_slug_here/reports/01_research-findings.md",
          "summary": "Brief 1-sentence description of artifact"
        }
      ],
      "completion_summary": "1-3 sentence description of what was accomplished",
      "roadmap_items": ["Optional explicit roadmap item text to match"]
    }
  ],
  "repository_health": {
    "last_assessed": "2026-01-29T18:38:22Z",
    "status": "healthy"
  },
  "vault_count": 0,
  "vault_history": []
}
```

## TODO.md Entry Format

```markdown
### {NUMBER}. {TITLE}
- **Effort**: {estimate}
- **Status**: [{STATUS}]
- **Task Type**: {general|meta|markdown} or extension-provided type
- **Dependencies**: Task #{N}, Task #{N}  OR  None
- **Started**: {ISO timestamp}
- **Completed**: {ISO timestamp}
- **Research**: [{NNN}_{SLUG}/reports/01_slug.md]
- **Plan**: [{NNN}_{SLUG}/plans/01_slug.md]

**Description**: {full description}
```

## Field Reference

### Top-Level Fields

Confirmed against a live property-union scan of `specs/state.json` (see
`context/schemas/state-schema.json`, whose `additionalProperties: false` top-level shape is the
authoritative source this table glosses).

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `next_project_number` | number | Yes | Next task number to assign |
| `active_projects` | array | Yes | In-flight task entries (see Project Entry Fields below) |
| `default_task_type` | string or null | No | Documented-optional. Overrides the `/task` keyword-routing table for new tasks in this project when set to a non-null string (see the root CLAUDE.md's Task-Type-Based Routing section). Absent in the current live snapshot, but a real, consumed field (`commands/task.md`) |
| `active_topics` | array of strings | No | Documented-optional, confirmed live. Distinct topic strings currently in use across `active_projects[].topic` |
| `completed_projects` | array | No | Documented-optional, confirmed live (currently empty, `[]`). Reserved for a possible future completed-but-not-yet-archived staging array; completion today moves an entry through `active_projects[].status`, not into this array |
| `repository_health` | object | No | See Repository Health Fields below |
| `memory_health` | object | No | Documented-optional, confirmed live. Memory-vault health snapshot maintained by `/distill`: `last_distilled`, `distill_count`, `total_memories`, `never_retrieved`, `health_score`, `status` |
| `version` | string | No | Documented-optional, confirmed live. State-store schema/version marker string (e.g. `"1.1.0"`) |
| `vault_count` | number | No | See Vault Fields below |
| `vault_history` | array | No | See Vault Fields below |
| `deployment_versions` | object | No | Documented-optional, confirmed live. Semantic-version deployment record written by `skill-tag` (the `/tag` command): `last_deployed`, `last_deployed_at`, and a `deployment_history` array of `{version, deployed_at, commit_sha}` capped at ten most-recent-first entries. Modelled because the agent system writes it itself -- until it was added here, `additionalProperties: false` rejected a field one of its own skills produces, so every repo that had run `/tag` failed the unknown-top-level-field check |
| `active_goal` | string | No | Documented-optional. Free-prose statement of the repository's current overall aim, for human orientation. No script writes or reads it; it is authored by a repo owner or by whichever task owns the repository's framing. Modelled rather than retired so a repo holding a real goal string does not fail validation for it; omitting it is equally valid |

### Retired Top-Level Fields

These three top-level fields are **deliberately NOT modelled** in `state-schema.json` and are
**deliberately NOT in** `validate-state.sh`'s `KNOWN_TOP_LEVEL_FIELDS`. All three are
pre-agent-system, generator-era bookkeeping: no script, command, or skill anywhere in
`agent-system/` writes or reads any of them. A consumer repo carrying one of them from before the
agent system's schema existed gets an advisory WARN (not a hard FAIL -- see "Unknown-field
enforcement posture" below) and can retire it permanently by running
`scripts/migrate-state-legacy-fields.sh`, which prints each value before deleting it.

This is the written, no-information-loss record the retirement ruling requires: each field's last
known value, observed in a real consumer repo at the time of the ruling, is recorded here
verbatim so the information survives independently of any task artifact or migration run's own
stdout.

| Field | Type | Last known value (consumer repo, observed at ruling time) | Why retired |
|-------|------|-------------------------------------------------------------|-------------|
| `artifacts` | array | `[{"path": "specs/636_fix_sorries_temporalproofstrategies_examples/plans/implementation-001.md", "type": "plan", "summary": "2-phase plan: attempt proof completion first, remove incomplete exercises as fallback"}]` <!-- task-ref-ok quoted legacy consumer-repo data value, not a task citation; the directory name is orphaned residue from a reused task number, already absent from that repo's working tree --> | Orphaned residue from an earlier, since-recycled task number (a vault/renumbering collision); the target path no longer exists in the consumer repo's working tree or git history. No agent-system writer or reader for a top-level `.artifacts` (every `.artifacts[0].path` hit elsewhere operates on `.return-meta.json` or a per-entry `active_projects[]` object, never the top level) |
| `metadata` | object | `{"generated_at": "2026-08-24T21:34:14.522352", "total_tasks": 44, "last_sync": "2026-08-24T21:34:14Z"}` | Stale, manually-reconciled legacy bookkeeping; the consumer repo's own review artifacts already flagged these exact values as wrong (`total_tasks` undercounted, `last_sync` many weeks stale). A sibling field in the same family (`task_counts`) was already hand-retired by that repo's maintainer before this ruling. No agent-system writer or reader |
| `last_updated` (top-level) | string (ISO8601) | `"2026-09-29T05:45:37Z"` | Same legacy-generator family as `metadata`; moves irregularly with no single canonical script or command owning it. Not to be confused with, and not a reason to touch, the well-modelled, load-bearing **entry-level** `last_updated` field above, which is unaffected |

### Unknown-field enforcement posture

`state-schema.json` keeps `additionalProperties: false` at both the top level and on
`definitions.projectEntry` -- this is unchanged and deliberate; JSON Schema draft-07 has no native
"warn" severity, so a schema-level posture split is not expressible in the schema file itself.
The advisory/strict split instead lives entirely in `scripts/validate-state.sh`: Checks 3
(unknown top-level field) and 4 (unknown entry field) are WARN-by-default, joining Checks 8-11 in
that posture, with `--strict` promoting every WARN to exit-blocking for an opt-in caller. A schema
and its validator **disagreeing on severity** is therefore deliberate and documented, not a defect
-- but the two **disagreeing on the field set** (a field the schema models that the validator's
hand-copied `KNOWN_TOP_LEVEL_FIELDS`/`KNOWN_ENTRY_FIELDS` arrays omit, or vice versa) remains a
real defect, caught by the schema-to-validator drift test in
`scripts/tests/test-validate-state.sh`. See each check's own PROMOTION CRITERION comment block in
`validate-state.sh` for the concrete bar that moves Checks 3/4 back to hard-FAIL.

### Project Entry Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `project_number` | number | Yes | Unique task identifier |
| `project_name` | string | Yes | Snake_case slug from title |
| `status` | string | Yes | Current status (see Status Values) |
| `task_type` | string | Yes | Task type for routing (see Task Type Values). Bare values (`meta`, `general`) or compound `extension:subtype` (`present:grant`, `founder:deck`) |
| `title` | string | No | Documented-optional, confirmed live on all current entries. Human-readable task title |
| `topic` | string | No | Documented-optional, confirmed live on all current entries. Free-text topic label, aggregated into the top-level `active_topics` array |
| `description` | string | No | Documented-optional, confirmed live on all current entries. Full task description |
| `session_id` | string | No | Documented-optional, confirmed live. Session ID of the most recent status-changing command invocation (`sess_{timestamp}_{random}`) |
| `effort` | string | No | Estimated effort. Zero occurrences in the current active snapshot, but this is a lifecycle-timing artifact, not evidence of disuse -- 276 occurrences in `specs/archive/state.json` (populates once a task completes) |
| `created` | string | Yes | ISO8601 creation timestamp |
| `last_updated` | string | Yes | ISO8601 last update timestamp |
| `dependencies` | array | No | Array of task numbers this depends on |
| `file_scope` | array of strings | No | Anticipated repo-relative paths/prefixes this task expects to touch (default: `[]`) |
| `research_questions` | array of strings | No | Planner-issued focused question list, present only after a `needs_research` verdict; overwrite-on-write, see [Research Questions Field](#research-questions-field) |
| `hold_reason` | string | No | Documented-optional; present only while status is `hold`. Why the task is paused. See [Hold Fields](#hold-fields) |
| `held_at` | string | No | Documented-optional; present only while status is `hold`. YYYY-MM-DD date the hold was set -- the state.json twin of TODO.md's `- **Held**: YYYY-MM-DD` line. See [Hold Fields](#hold-fields) |
| `prior_status` | string | No | Documented-optional; present only while status is `hold`. The status the task returns to when the hold lifts -- the field that makes a hold reversible. See [Hold Fields](#hold-fields) |
| `artifacts` | array | No | Array of artifact objects |
| `next_artifact_number` | number | No | Next artifact sequence number (default: 1). Zero occurrences in the current active snapshot -- same lifecycle-timing sparsity as `effort`, 308 occurrences in `specs/archive/state.json` |
| `blockers` | array of strings | No | Documented-optional. Free-text, human/session-authored annotation naming what is blocking the task. No canonical script writer -- composed ad hoc by whoever marks the task `blocked`/`partial` -- but read by `scripts/orchestrate-cycle-postflight.sh`'s blocked-verdict branch to surface the blocker-research aux signal. Canonical shape is array of strings; a legacy scalar-string value is tolerated by that reader through the migration window (`scripts/migrate-state-legacy-fields.sh` normalizes it) |
| `previous_status` | string (`taskStatus` enum) | No | Documented-optional, **load-bearing, not bookkeeping**. Written by `/spawn`'s preflight status update (`skills/skill-spawn/SKILL.md`) before it overwrites `status` to `blocked`, recording the status the task was in beforehand. Read by `scripts/orchestrate-triage-classify.sh`'s blocked-task discharge routing: a discharged candidate with no recorded `previous_status` cannot determine its discharge phase and falls back to `needs_human` |
| `resume_phase` | integer | No | Documented-optional, **legacy/secondary**. Predates and is not consumed by the live `continuation_context`-based resume mechanism (see `agents/general-implementation-agent.md`); no current writer or reader in the agent system. Retained rather than retired because a live value on a blocked task is exactly the kind of resume-point information whose loss would be invisible until someone tries to resume. Reconciling this field with `continuation_context` is a separate, out-of-scope concern |
| `researched` | string (ISO8601 timestamp) | No | Documented-optional, **informational-only**. A phase-completion TIMESTAMP -- not a boolean, and not to be confused with the unrelated `status: "researched"` enum value. No current writer (the template that minted it predates `skill-status-sync`'s actual `postflight_update` operation, which sets only `status` and `last_updated`) and no current reader. Retained because entry-level `last_updated` is overwritten by every subsequent status change, so this is the only remaining record of when research completed for a task that has since moved on |

### task_type Field

The `task_type` field is the unified routing field for all tasks. It replaces the former `language` field and the former secondary `task_type` field.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `task_type` | string | Yes | - | Routing key: bare value or compound `extension:subtype` |

**Values**:
- **Bare values**: `meta`, `general`, `markdown`, plus extension-provided types (e.g., `lean4`, `latex`, etc.)
- **Compound values**: `present:grant`, `founder:deck`, `present:slides`, etc.
- Compound format: `{extension}:{subtype}` -- the extension prefix is used for routing to the correct extension, the subtype for sub-routing within the extension.

**Routing Behavior**: When a command is invoked on a task:
1. Read `task_type` from the task entry
2. If compound (contains `:`), split into base key and subtype
3. Route to extension matching base key, then to skill matching subtype
4. If bare value, route directly to matching extension or core skill

**Format Conversion**:

| state.json | TODO.md |
|------------|---------|
| `"meta"` | `- **Task Type**: meta` |
| `"general"` | `- **Task Type**: general` |
| `"present:grant"` | `- **Task Type**: present:grant` |

### Task Type Values

**Core Task Types** (always available):

| Task Type | Description |
|-----------|-------------|
| `general` | General programming, web research |
| `meta` | System building, .claude/ modifications |
| `markdown` | Documentation tasks |

**Extension Task Types** (when extensions loaded): See `.claude/extensions/*/manifest.json`.

### Unified Artifact Numbering (next_artifact_number)

The `next_artifact_number` field enables unified artifact numbering where all artifact types (reports, plans, summaries) share a single sequence number per task within a "round" of work.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `next_artifact_number` | number | 1 | Next artifact sequence number to use |

**Semantics**:
- **Research advances the sequence**: Research reads `next_artifact_number`, uses it for artifact naming, then increments it in postflight
- **Plan/Summary reuse current**: Plan and summary skills use `(next_artifact_number - 1)` since they're completing the current round started by research
- **Round concept**: A research report starts a new "round", and the corresponding plan and summary share that round's number

**Example Flow**:
```
Round 1:
  /research 309  -> reads 1, creates 01_report.md, increments to 2
  /plan 309      -> reads 2, uses (2-1)=1, creates 01_plan.md
  /implement 309 -> reads 2, uses (2-1)=1, creates 01_summary.md

Round 2 (after blocker):
  /research 309  -> reads 2, creates 02_report.md, increments to 3
  /plan 309      -> reads 3, uses (3-1)=2, creates 02_plan.md
  /implement 309 -> reads 3, uses (3-1)=2, creates 02_summary.md
```

**Backward Compatibility**:
When `next_artifact_number` is missing (legacy tasks), skills fall back to directory scanning:
```bash
# Fallback: count existing artifacts to determine next number
count=$(ls "specs/${padded_num}_${slug}/reports/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
artifact_number=$((count + 1))
```

### Artifact Object Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Artifact type: `research`, `plan`, `summary`, `implementation` |
| `path` | string | Yes | Relative path from project root |
| `summary` | string | Yes | Brief 1-sentence description |

### Completion Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `completion_summary` | string | Yes (when completed) | 1-3 sentence summary of accomplishment |
| `roadmap_items` | array | No | Explicit ROADMAP.md item texts (non-meta only) |
| `memory_candidates` | array | No | Structured memory candidates emitted by agents (see below) |
| `reflection` | object | No | Structured completion-time reflection emitted by agents (see below) |
| `skeleton_follow_ups` | array | No | Strategic-sorry follow-ups from a skeleton completion (see below) |

### Memory Candidates Field

The `memory_candidates` array on task entries accumulates structured memory candidates emitted by agents during research and implementation. Candidates are appended (not overwritten) so research and implementation candidates coexist.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `content` | string | Yes | Description of reusable knowledge (~300 tokens max) |
| `category` | string | Yes | One of: `TECHNIQUE`, `PATTERN`, `CONFIG`, `WORKFLOW`, `INSIGHT` |
| `source_artifact` | string | Yes | Path to the artifact that produced this candidate |
| `confidence` | number | Yes | Float 0-1 indicating reusability confidence |
| `suggested_keywords` | array of strings | Yes | Keywords for memory index retrieval |

**Lifecycle**:
- **Producer**: Skill postflight extracts `memory_candidates` from `.return-meta.json` and appends to the task entry
- **Consumer**: `/todo` processes candidates during task archival (writes memory files, updates index)
- **Semantics**: Append-only during task lifecycle; consumed and removed during archival

**Responsibility Split**:
- **`/implement` (Producer)**: Reports what was changed factually
- **`/todo` (Consumer)**: Evaluates content and decides what warrants CLAUDE.md updates

### Skeleton Follow-Ups Field

The `skeleton_follow_ups` array on task entries accumulates strategic-sorry follow-up entries
surfaced when a strategic-sorry skeleton plan (handoff `skeleton: true` — see
`handoff-schema.md`'s `skeleton` field) reaches `[COMPLETED]`. Entries are appended (not
overwritten), the same convention `memory_candidates` above uses, so follow-ups from more than
one skeleton completion on the same task coexist. Each entry is the corresponding
`sorry_inventory` entry (filtered to `strategic == true`) plus two fields recording when and by
whom it was recorded.

| Field | Type | Required | Description |
|-------|------|----------|--------------|
| `file` | string | Yes | Path to the file containing the strategic sorry |
| `line` | integer | Yes | Line number of the sorry |
| `statement` | string | Yes | The statement the sorry stands in for |
| `strategic` | boolean | Yes | Always `true` on a recorded entry — the non-strategic filter already ran |
| `assumption` | string | Yes | The assumption the sorry rests on |
| `why_deferred` | string | Yes | Why the sorry was deferred rather than closed |
| `follow_up_task` | string | Yes | Human-readable description of the follow-up work |
| `recorded_cycle` | integer | Yes | The `/orchestrate` cycle count at which this entry was recorded |
| `session_id` | string | Yes | The session that recorded this entry |

**Lifecycle**:
- **Producer**: `orchestrate-cycle-postflight.sh`'s `implemented)` case, via
  `skill_propagate_skeleton_follow_ups` (`scripts/skill-base.sh`) — fires only when the final
  implement handoff carries `skeleton: true` and a non-empty strategic `sorry_inventory[]`
- **Consumer**: The human, via `/task` — no auto-creation of follow-up tasks (deliberately; see
  `status-markers.md`'s `[COMPLETED]` subsection)
- **Semantics**: Append-only; never auto-filed as tasks; no archival-time (`/todo`) consumer today

### Reflection Field

The `reflection` object on task entries holds a single completion-time reflection emitted by an
implementation agent. Unlike `memory_candidates`, it is written with **overwrite** (not append)
semantics — the latest implementation's reflection replaces any prior one on the same task entry.

| Field | Type | Required | Description |
|-------|------|----------|--------------|
| `what_worked` | string | No | ~1-3 sentences on what approach or technique worked well |
| `what_was_hard` | string | No | ~1-3 sentences on what was difficult or friction-prone |
| `what_was_missed` | string | No | ~1-3 sentences on what was overlooked, deferred, or missed initially |
| `successes` | string | No | ~1-3 sentences summarizing concrete successes |

**Lifecycle**:
- **Producer**: Skill postflight reads `reflection` from `.return-meta.json` and writes it to the
  task entry, gated on `operation_type == "implement" && status == "implemented"`
- **Consumer**: `/todo` surfaces reflections read-only during its harvest stage (alongside
  `memory_candidates`); `/learn --task N` can pull a present reflection in as an additional
  reviewable segment
- **Semantics**: Overwrite, not append; absence is valid (optional even on a successful
  implementation)

**Sparsity note**: `reflection` has zero occurrences anywhere in `specs/state.json` or
`specs/archive/state.json` as of this writing -- unlike `effort`/`next_artifact_number` (sparse
in the active snapshot but abundant in archive), this is genuinely the one field that may not yet
have been exercised, per this document's own producer/consumer wiring description above. Not
evidence the field is dead; documented-optional pending its first real population.

### Dependencies Field

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `dependencies` | array of integers | No | `[]` | Task numbers that must complete before this task can start |

**Validation**:
- All task numbers must exist in `active_projects`
- No circular dependencies allowed
- No self-reference allowed

**Format Conversion**:

| state.json | TODO.md |
|------------|---------|
| `[]` | `None` |
| `[{N}]` | `Task #{N}` |
| `[{N}, {M}]` | `Task #{N}, Task #{M}` |

### File Scope Field

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|--------------|
| `file_scope` | array of strings | No | `[]` | Anticipated repo-relative paths or directory-prefixes this task expects to create or modify; used at task-creation time to detect same-file overlap with sibling tasks and derive serializing `dependencies[]` edges |

**Validation**:
- Paths need not exist yet (prospective, not filesystem-validated)
- Not a graph edge itself, so no cycle/self-reference checks apply (unlike `dependencies`)
- state.json-only: no TODO.md rendering (mirrors `next_artifact_number`; no
  `generate-todo.sh`/template change is needed)

**Contrast with `modified_files`/`files_touched`**: `file_scope` is prospective and set at
task-creation time (an anticipation of what the task will touch, used to detect same-file
overlap between sibling tasks and to auto-derive a serializing `dependencies[]` edge before any
work starts). `modified_files`/`files_touched` are retrospective and set during/after
implementation (the actual paths touched, self-reported by implementation agents for targeted
git staging — see `.claude/context/standards/git-staging-scope.md`). The two fields are
complementary and are never merged or reconciled against each other.

### Research Questions Field

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|--------------|
| `research_questions` | array of strings | No | absent | The focused question list a planner issues alongside a `needs_research` verdict (see `context/formats/return-metadata-file.md`'s `### research_questions (optional)` section), naming the facts a research phase must establish before a plan meeting `plan-format.md` can be written |

**Producer**: `scripts/update-task-status.sh`'s `--research-questions=<json-array>` flag, invoked
at postflight when `operation == postflight && target_status == needs_research` (i.e.
`skill-base.sh`'s `skill_postflight_update()` `needs_research)` case arm, forwarding the value it
reads off the planner's own `.return-meta.json`).

**Semantics: OVERWRITE-ON-WRITE, not additive.** This is the one deliberate contrast with
`file_scope` above (which is additive-only, union-merged, never subtractive): each
`needs_research` postflight call fully REPLACES `research_questions` with the value it carries,
because a planner returning `needs_research` a second time (after a research round that still
left a gap) is issuing a fresh, complete question list, not appending to a stale one. There is no
merge target and no accumulation across cycles.

**Consumer**: read at research-dispatch build time and joined into a single string, passed as
`--focus "<joined>"` to `orchestrate-build-dispatch.sh` -- the same already-built, already
phase-gated `--focus` flag `orchestrate-build-dispatch.sh` uses for the memory-retrieve
hand-off, requiring no change inside that script.

**Validation**: same shape as `--file-scope-add` -- a malformed value (non-array, or an array
containing a non-string element) is a hard validation error (exit 1) at `update-task-status.sh`,
never a silent no-op.

**state.json-only**: no TODO.md rendering, matching `file_scope`'s own convention.

### Hold Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|--------------|
| `hold_reason` | string | No | absent | Why the task is paused. Required (non-empty) whenever `status == "hold"` -- `scripts/update-task-status.sh`'s `--hold-reason=<string>` flag hard-fails rather than setting a hold with no recorded reason |
| `held_at` | string | No | absent | YYYY-MM-DD date the hold was set -- the state.json twin of TODO.md's `- **Held**: YYYY-MM-DD` line (rendered by `scripts/generate-todo.sh`) |
| `prior_status` | string | No | absent | The status the task returns to when the hold lifts |

**Producer**: `scripts/update-task-status.sh`'s `preflight:hold` arm, invoked via
`update-task-status.sh preflight <N> hold <session_id> --hold-reason=<string>`. All three fields
are written in the SAME `state-write.sh` invocation as the `status` field itself -- never a
second write. `prior_status` is captured from the task's REAL current status, read before the
overwrite -- EXCEPT when the task is already held (a `hold_reason` update, not a fresh hold), in
which case the EXISTING `prior_status` is preserved rather than overwritten with `"hold"` itself,
which would otherwise permanently break the eventual lift.

**`prior_status` is what makes a hold reversible** -- the single field that distinguishes a hold
from a one-way archival. Every other postflight-only terminus in this enum (`partial`, `blocked`,
`abandoned`) either resumes via the permissive "any non-terminal status -> any command" model or
is terminal outright; `hold` is the one status that is both non-resumable by ordinary commands
AND explicitly reversible, and `prior_status` is the mechanism that makes the reversal exact
rather than a guess.

**Lift surface (Decision 5)**: `preflight:unhold` -- `update-task-status.sh preflight <N> unhold
<session_id>`. Unlike every other `map_status()` arm (a closed `case` literal), `unhold`'s
resolved resting state is DYNAMIC: a preamble reads the task's own `prior_status`, validates it
against the closed status enum (`status_vocabulary_is_valid`), and uses it as the write target --
a missing, empty, or off-enum `prior_status` fails loudly, never falling back to `not_started` or
any other default. The three hold fields are removed via `del(.hold_reason, .held_at,
.prior_status)` -- field OMISSION, not nulling, matching this codebase's convention for
present-only-in-one-state fields (`completion_summary`).

**Sticky across a forced dispatch**: an ordinary preflight/postflight status write (research,
plan, implement, etc.) on an ALREADY-held task is downgraded to a no-op on the status field alone
by a dedicated hold-sticky guard in `update-task-status.sh` -- the actual mechanism (not the
rank-based `monotonic-max` clamp, which does not protect an unranked status) that lets an
explicit `/orchestrate --research|--plan|--implement` forcing-flag override admit a held task for
one dispatch while `status` stays `"hold"` afterward. See
`context/standards/status-markers.md`'s `[HOLD]` section for the full decision record.

### Repository Health Fields

| Field | Type | Description |
|-------|------|-------------|
| `last_assessed` | string | ISO8601 timestamp of last metrics update |
| `status` | string | `healthy`, `manageable`, `concerning`, `critical`, or `unknown`. Derived solely from `build_errors`: `null` -> `unknown` (not measured), `0` -> `healthy`, `>0` -> `critical`. `manageable` and `concerning` are reserved for a future graded metric and are not currently emitted by any producer |
| `todo_count` | number | Documented-optional, confirmed live. Count of TODO: tags found by the last scan |
| `fixme_count` | number | Documented-optional, confirmed live. Count of FIXME:/FIX: tags found by the last scan |
| `build_errors` | number or null | Documented-optional, confirmed live. Count of build/lint errors found by the last scan. `null` means no applicable structural probe found -- not measured (same nullable-field pattern as `memory_health.last_distilled`), distinct from both `0` and any positive count |
| `phantom_paths` | number | Count of git-index entries among the last scan's structural (`*.sh`/`*.json`) candidates that were absent from the worktree at assessment time (e.g. a tracked file moved or deleted but not yet staged). Always an integer, never `null` -- excluded from both `build_errors` and the candidate total it is derived from |

### Vault Fields

The vault system manages task number cycling when `next_project_number` exceeds 1000.

**Sparsity note**: `vault_count`/`vault_history` are 0/`[]` everywhere (both the active snapshot
and archive) as of this writing -- this is expected, not dead code: the vault trigger
(`next_project_number > 1000`) has simply never fired yet.

| Field | Type | Description |
|-------|------|-------------|
| `vault_count` | number | Number of completed vault archival operations (0 initially) |
| `vault_history` | array | History of vault operations with metadata |

**Vault History Entry Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `vault_number` | number | Sequential vault number (1-indexed) |
| `vault_dir` | string | Path to vault directory (e.g., `specs/vault/01-vault/`) |
| `created_at` | string | ISO8601 timestamp when vault was created |
| `task_range` | string | Range of task numbers archived (e.g., `1-999`) |
| `archived_count` | number | Number of tasks archived to vault |
| `final_task_number` | number | Last task number before reset |

**Vault Trigger Condition**: When `next_project_number > 1000`, the /todo command initiates vault operation.

**Vault Operation Steps**:
1. Move `specs/archive/` to `specs/vault/{NN-vault}/archive/`
2. Create `specs/vault/{NN-vault}/meta.json` with vault metadata
3. Reinitialize empty `specs/archive/` with fresh state.json
4. Renumber active tasks > 1000 by subtracting 1000
5. Rename task directories from 4-digit to 3-digit format
6. Update all artifact paths and dependencies
7. Reset `next_project_number` to max(renumbered tasks) + 1
8. Increment `vault_count` and add entry to `vault_history`

## Status Values Mapping

**Single source**: the authoritative status enum is `context/schemas/state-schema.json`'s
`definitions.taskStatus.enum`, mirrored as a sourced shell array in
`scripts/lib/status-vocabulary.sh` (the two are kept byte-equal by
`scripts/tests/test-status-vocabulary.sh`). The table below is a human-readable gloss over that
pair, not an independent authority -- if this table and the schema/library ever disagree, the
schema/library wins. See also `context/standards/status-markers.md` for full per-marker prose
definitions, transition rules, and required fields.

| TODO.md Marker | state.json status |
|----------------|-------------------|
| [NOT STARTED] | not_started |
| [RESEARCHING] | researching |
| [RESEARCHED] | researched |
| [PLANNING] | planning |
| [PLANNED] | planned |
| [IMPLEMENTING] | implementing |
| [PR READY] | pr_ready |
| [COMPLETED] | completed |
| [BLOCKED] | blocked |
| [ABANDONED] | abandoned |
| [PARTIAL] | partial |
| [EXPANDED] | expanded |

## Artifact Linking Formats

Links use bracket-only format `[path]` (not markdown `[text](url)` format).

### Research Completion
```markdown
- **Status**: [RESEARCHED]
- **Research**: [{NNN}_{SLUG}/reports/01_research-findings.md]
```

### Plan Completion
```markdown
- **Status**: [PLANNED]
- **Plan**: [{NNN}_{SLUG}/plans/02_implementation-plan.md]
```

### Implementation Completion
```markdown
- **Status**: [COMPLETED]
- **Completed**: 2026-01-08
- **Summary**: [{NNN}_{SLUG}/summaries/03_execution-summary.md]
```

### Count-Aware Linking

**Rule**: Use inline format for 1 artifact, multi-line list for 2+ artifacts.

**Single artifact**:
```markdown
- **Research**: [{NNN}_{SLUG}/reports/01_research-findings.md]
```

**Multiple artifacts**:
```markdown
- **Research**:
  - [{NNN}_{SLUG}/reports/01_research-findings.md]
  - [{NNN}_{SLUG}/reports/02_supplemental.md]
```

**Detection Patterns**:
- **No existing line**: `- **{Type}**:` not found in task entry
- **Existing inline**: Line matches `- **{Type}**: \[.*\]` (has link on same line)
- **Existing multi-line**: Line matches `- **{Type}**:$` (ends with colon, no link)

**Implementation Reference**: For the full four-case Edit tool logic used by skills during postflight, see `.claude/context/patterns/artifact-linking-todo.md`.

## Directory Creation

### Lazy Directory Creation Rule

Create task directories **lazily** - only when the first artifact is written:
```
specs/{NNN}_{SLUG}/
|- reports/      # Created when research agent writes first report
|- plans/        # Created when planner agent writes first plan
|- summaries/    # Created when implementation agent writes summary
```

**Note**: Directory numbers use 3-digit zero-padding (e.g., `014_task_name`). Use `printf "%03d" $task_num` for path construction.

**System-specific naming**: Claude Code uses `specs/{NNN}_{SLUG}/` (no prefix). OpenCode uses `specs/OC_{NNN}_{SLUG}/` (OC_ prefix).

**Correct Pattern**:
```bash
padded_num=$(printf "%03d" "$task_num")
mkdir -p "specs/${padded_num}_${slug}/reports"
write "specs/${padded_num}_${slug}/reports/01_research-findings.md"
```

## Examples

### New Task Entry
```json
{
  "project_number": 500,
  "project_name": "implement_new_feature",
  "status": "not_started",
  "task_type": "general",
  "created": "2026-02-25T10:00:00Z",
  "last_updated": "2026-02-25T10:00:00Z",
  "artifacts": []
}
```

### Task with Dependencies
```json
{
  "project_number": 502,
  "project_name": "integrate_feature",
  "status": "not_started",
  "task_type": "general",
  "dependencies": [500, 501],
  "created": "2026-02-25T10:30:00Z",
  "last_updated": "2026-02-25T10:30:00Z",
  "artifacts": []
}
```

### Completed Meta Task
```json
{
  "project_number": 510,
  "project_name": "add_merge_command",
  "status": "completed",
  "task_type": "meta",
  "created": "2026-02-26T09:00:00Z",
  "last_updated": "2026-02-26T12:00:00Z",
  "artifacts": [
    {
      "type": "implementation",
      "path": ".claude/commands/merge.md",
      "summary": "Unified /merge command with GitHub/GitLab detection"
    }
  ],
  "completion_summary": "Created /merge command with platform auto-detection."
}
```

## Enforcement and Update-Pattern Narrative

This section is the lazily-loaded elaboration for `rules/state-management.md`'s eager core. The
rule's core keeps the "Artifacts Are Append-Only" prohibition and the State-First Update Pattern's
two commands eager (an agent must know the prohibition and the commands before writing state); the
mechanism detail behind them lives here.

### Artifacts Are Append-Only — Enforcement Mechanism and Known Limitation

**Enforcement mechanism**: `validate-state.sh --deep` checks, per `project_number` and per
artifact `type`, that the count of paths removed relative to the prior git-committed version does
not exceed the count of paths added — a FAIL-level finding on any pair that violates this. A
genuine, intentional deletion is expressible via the repeatable
`--allow-artifact-removal <project_number>[:<type>]` opt-in flag on the validator; every
suppressed finding is still logged, never silent.

**Known limitation**: enforcement is periodic, not write-time. It runs only when
`validate-state.sh --deep` is invoked (currently via `verify-deploy.sh`'s gate 10), so a lossy
direct-`jq` write can still land between validation passes, and a subsequent legitimate commit
moves the comparison baseline forward, potentially hiding an earlier loss from a later diff. This
trade-off is accepted rather than closed by this rule; closing it fully would require a
synchronous (write-time) enforcement path, which is out of scope here.

### State-First Update Pattern — Explanation

When updating task status:

1. **Write state.json** via `jq` (machine state is the sole source of truth)
2. **Regenerate TODO.md** by calling `bash .claude/scripts/generate-todo.sh`

`update-task-status.sh` performs both steps automatically. Agents must not Edit TODO.md directly
for status or artifact changes — `generate-todo.sh` handles all TODO.md rendering from state.json.

### Error Handling

#### On Write Failure
1. Do not update either file partially
2. Log error with context
3. Preserve original state
4. Return error to caller

#### On Inconsistency Detection
1. Log the inconsistency
2. Use git blame to determine latest
3. Sync to latest version
4. Use git for recovery of overwritten versions

## Related Documentation

- [State Management Rule](../../../rules/state-management.md) - Behavioral constraints and update patterns
- [Artifact Formats Rule](../../../rules/artifact-formats.md) - Artifact naming conventions
