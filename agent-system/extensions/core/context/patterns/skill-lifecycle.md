# Skill Lifecycle Pattern (Stage-N Skeleton)

## Overview

Every lifecycle skill (`skill-reviser`, `skill-spawn`, and every extension's
`skill-{domain}-research` / `skill-{domain}-implementation`) is a self-contained workflow that
owns its complete lifecycle in one skill invocation. The base lifecycle skills that originally
motivated this skeleton (and their `--hard` variants) have since been deleted; `skill-orchestrate`
now dispatches `general`/`meta`/`markdown` research/plan/implement work directly to agents
instead, following its own distinct multi-stage flow (see the "Not part of the per-skill stage
list" note below):

- **Preflight**: validate input, update task status, write a premature-termination marker
- **Delegate**: invoke an agent (via the `Agent` tool) to perform the actual work
- **Postflight**: parse the agent's return, update task status, link artifacts, commit, clean up
- **Return**: return a brief text summary (not JSON) to the caller

A single skill invocation replaces the older 3-skill gate-in/delegate/gate-out pattern, reducing
halt risk from 3-4 potential stop points per command down to 1.

```
/revise N
├── VALIDATE: Inline task lookup (command layer)
├── DELEGATE: Skill(skill-reviser)
│   ├── Stage 1-5b: preflight, context prep, subagent invocation (this doc's skeleton)
│   ├── Stage 6-9: postflight — status, artifacts, notify, cleanup (this doc's skeleton)
│   └── Return: brief text summary
└── COMMIT: command-level batch commit (CHECKPOINT 3)
```

**This document is the canonical map of that skeleton**: which numbered stage does what, and
which shared `@`-imported context block or `skill-base.sh` function is the one real
implementation of it. It does not repeat `skill-base.sh`'s authoring walkthrough or its full
function-signature table — see "Division of Labor" below for where that content lives.

---

## The Stage-N Skeleton

This is the stage list every converted lifecycle skill follows today, in numbered order. Every
skill uses the *same* stage numbers for the *same* purpose — a reader who knows "Stage 7 is
status update" in `skill-reviser` can carry that fact to `skill-nix-implementation` unchanged.
Not every skill has every stage (see "Optional / skill-specific stages" below), and skills differ
in how far they split the postflight stages apart (see "Two Postflight Shapes").

| Stage | Name | Canonical implementation | Owning file |
|-------|------|---------------------------|-------------|
| 1 | Input Validation | `skill_validate_input()` (in practice, most skills still hand-roll the task-lookup `jq` inline rather than calling this function — see the Known Gaps note below) | `scripts/skill-base.sh` |
| 2 | Preflight Status Update | `skill_preflight_update()` | `scripts/skill-base.sh`, imported via `@.claude/context/patterns/skill-preflight-flow.md` |
| 3 | Create Postflight Marker | `skill_create_postflight_marker()` (Shape A schema: `session_id`, `skill`, `task_number`, `operation`, `reason`, `created`, `stop_hook_active`) | same shared block as Stage 2 |
| 3a | Read/Calculate Artifact Number | Inline `jq` against `next_artifact_number`, with a disk-reconciliation scan (research adds a collision-avoidance loop over `reports/`). `skill_read_artifact_number()` exists in `skill-base.sh` as an available helper but no current skill calls it by name — the inline form remains the de facto implementation. | skill body (Stage 3a of each skill) |
| 4a | Memory Retrieval + Literature Detection | `memory-retrieve.sh` (skipped when `clean_flag=true`) plus the `--lit` resolution flow, imported via `@.claude/context/patterns/lit-stage4a-flow.md` | `scripts/memory-retrieve.sh`, `scripts/literature-lit-flag-resolve.sh` |
| 4 | Prepare Delegation Context | Prose: build the JSON delegation context (`session_id`, `delegation_depth`, `delegation_path`, `task_context`, domain-specific fields); `skill_context_injection()` fires the extension `context_injection` hook alongside it | skill body + `scripts/skill-base.sh` |
| 4b | Read/Inject Format or Plan Context | Prose: `cat` the relevant format spec (`report-format.md`/`plan-format.md`) or read the plan file, for inclusion in the Stage 5 prompt | skill body |
| 5 | Invoke Subagent | The `Agent` tool with an explicit `subagent_type` — never `Skill(...)` | skill body |
| 5a | *(implement dispatch only, historical)* Validate Subagent Return Format | Prose: sanity-check the returned metadata shape before Stage 6 — folded into `skill-orchestrate`'s own direct-dispatch return handling now that the base lifecycle implement skill is deleted | `skill-orchestrate/SKILL.md` |
| 5b | Self-Execution Fallback | The `.return-meta.json` write obligation when the skill performed work without spawning a subagent, imported via `@.claude/context/patterns/skill-self-execution-fallback.md` | same shared block |
| 5c | *(implement dispatch only, historical)* Continuation Loop Init | Prose: multi-turn continuation guard setup — folded into `skill-orchestrate`'s own `.orchestrator-loop-guard` handling now that the base lifecycle implement skill is deleted | `skill-orchestrate/SKILL.md` |
| 6 | Parse Subagent Return | Read and `jq`-parse `.return-meta.json`; `skill_read_metadata()` is the available helper | `scripts/skill-base.sh` |
| 6a | Validate Artifact Content | `skill_validate_artifact()` / `skill_validate_task_artifacts()` — non-blocking `validate-artifact.sh --fix` pass. `skill_validate_task_artifacts()` (the whole-directory sweep, called from `command-gate-out.sh`) now aggregates auto-repair, error, and warning counts across the sweep into four caller-visible globals — `SKILL_VALIDATE_FIXES`, `SKILL_VALIDATE_ERRORS`, `SKILL_VALIDATE_WARNINGS`, `SKILL_VALIDATE_FIXED_FILES` — instead of discarding them; `command-gate-out.sh` reports them unconditionally (repaired and clean alike) and appends one `artifact_auto_repair` row to `specs/events.jsonl`. See the "In-Place `--fix` Mutation on the Gate-Out Path (D-A)" subsection below for the reasoning. | `scripts/skill-base.sh`, `scripts/command-gate-out.sh` |
| 7 | Update Task Status (Postflight) | `skill_postflight_update()`, imported via `@.claude/context/patterns/skill-postflight-flow.md` | same shared block |
| 7a | Propagate Memory Candidates | `skill_propagate_memory_candidates()` | same shared block |
| 8 | Link Artifacts | `skill_link_artifacts()` (two-step `jq` pattern, Issue #1132-safe) | same shared block |
| 8a | Lifecycle TTS Notification | `skill_lifecycle_notify()` | same shared block |
| 9 | Git Commit *or* Cleanup | See "Two Postflight Shapes" below — this is the one stage number whose *meaning* diverges by skill family | varies |
| 10 | Cleanup *or* Return Brief Summary | See "Two Postflight Shapes" below | varies |
| 11 | Return Brief Summary | Prose: a 3-6 bullet text summary, never JSON | skill body |

**Not part of the per-skill stage list** (used only by `skill-orchestrate` — both effort modes,
one engine — not by the research/plan/implement skills above):
`skill_gate_completion_claim()` and `skill_corroborate_phase_counts()` implement the
completion-claim gate and plan-heading corroboration for autonomous orchestration. They live in
`scripts/skill-base.sh` alongside the Stage-N functions but are orchestrator-only — do not expect
them at any research/plan/implement skill's Stage 6-9.

### Known gaps between this table and the literal source

Two of the function-to-stage mappings above are the *intended* implementation, not a universal
call-site fact, and are stated that way on purpose rather than glossed over:

- `skill_validate_input()` exists and is exported, but every core and extension skill audited for
  this rewrite still hand-rolls its Stage 1 task lookup as an inline `jq` block rather than
  calling the function. Treat the function as available, not yet exclusive.
- `skill_read_artifact_number()` is similarly unreferenced by name in any `SKILL.md` today; Stage
  3a's inline `jq` (with research's additional disk-reconciliation and collision-avoidance logic)
  is the real implementation in every skill that has one.

A future conversion could route Stage 1 and Stage 3a through these functions the same way Stages
2/3/6/7/7a/8/8a/9(cleanup)/5b already were converted — that is out of scope for this rewrite,
which documents what skills actually do today.

### In-Place `--fix` Mutation on the Gate-Out Path (D-A)

`skill_validate_task_artifacts()`'s non-blocking sweep calls `validate-artifact.sh ... --fix`,
which mutates an artifact in place when it can. That mutation remains in-place-mutating on the
`command-gate-out.sh` path deliberately, not by default:

- The mutation is narrow and self-flagging: `validate-artifact.sh`'s fix block only ever inserts
  a literal `- **Field**: TBD` placeholder for a missing metadata field. It never fabricates
  prose and never touches required sections, so it cannot manufacture a false appearance of
  completeness.
- Every artifact under `specs/` is git-tracked, so the mutation's *content* was always auditable
  via `git diff`. The real gap was a missing *record that a repair happened at all* — that gap is
  what Stage 6a's aggregation globals and `command-gate-out.sh`'s report/events leg (see the
  Stage 6a table row above) now close.
- Disabling `--fix` on this path would turn every trivial missing-metadata-field omission into a
  hard stop in an otherwise-automated lifecycle step, which the reporting gap alone did not
  justify.
- Residual risk carried forward on purpose: `validate-artifact.sh` exits 2 for both "fixed and
  now fully clean" and "fixed a field but a required *section* is still missing." The gate-out
  report surfaces the errors-remaining count *alongside* the fix count specifically so the second
  case stays visible.

**Known sibling gap (deliberately out of scope for this record):** `skill_validate_artifact()`
(singular — the per-artifact validator used by ordinary per-command postflight, distinct from the
directory-sweep `skill_validate_task_artifacts()` documented above) discards
`validate-artifact.sh`'s fix/error/warning counts the same way `skill_validate_task_artifacts()`
used to before this aggregation was added. It can adopt the identical
exit-code-discriminated-parsing approach directly. Both functions live in `scripts/skill-base.sh`.

---

## Two Postflight Shapes

Every skill shares Stages 6, 6a, 7, 7a, 8, 8a. They diverge on **who commits, and how many
numbered stages that takes** — this is a real, intentional difference between skill families, not
drift to be flattened.

### Collapsed shape (domain/extension research and implementation thin wrappers)

`skill-{domain}-research` and `skill-{domain}-implementation` skills (neovim, nix, latex, typst,
z3, python, web, email, epidemiology, founder, present, etc.) fold Stages 7/7a/8/8a/9 into a
single `@`-import of `skill-postflight-flow.md`, where that block's own Stage 9 is **Cleanup**
(`skill_cleanup()`) — there is no inline git-commit stage in the skill body at all. These skills
rely entirely on a batch commit further up the call chain to persist their changes. The skill's
own numbering ends at Stage 9 (cleanup, via the shared block) followed by an unnumbered
`## Return Format` section (as in most domain thin wrappers) — this is compliant with the
skeleton; the final heading number is a readability choice, not a validated field.

### Split shape (skill-reviser, skill-spawn, and — historically — the deleted base plan/implement skills)

`skill-reviser` and `skill-spawn` interleave an explicit, inline **Stage 9: Git Commit** between
the shared block's TTS-notify stage and cleanup, calling `.claude/scripts/git-commit-scoped.sh`
directly (the sole sanctioned path-scoped, mutex-serialized committer; see
`@.claude/context/standards/git-staging-scope.md`) rather than relying solely on a higher-level
batch commit. The base lifecycle plan/implement skills — since deleted, `general`/`meta`/
`markdown` now dispatch through `skill-orchestrate` directly — used to follow this same shape.
Their Stage numbering runs one stage longer:

- Stage 9: Git Commit (inline, via `git-commit-scoped.sh`)
- Stage 10: Cleanup (`skill_cleanup()`, called explicitly rather than through the shared block's
  own Stage 9 slot, since that slot is now occupied by Git Commit)
- Stage 11: Return Brief Summary

`skill-orchestrate` itself also calls `git-commit-scoped.sh` inline per task during multi-task
dispatch (see its own commit-scope section), for the same reason: a genuinely concurrent site
where each in-flight task must commit its own changes rather than wait for a shared batch step.

**Rule of thumb**: if you are writing a skill whose caller may run several instances
concurrently (multi-task dispatch, or standalone tasks like `skill-reviser`/`skill-spawn` that
have no guaranteed batch-commit caller), give it an explicit Stage 9 Git Commit. If you are
writing a **domain/extension** thin wrapper (research or implementation) invoked one-at-a-time
under `skill-orchestrate`'s dispatch loop, follow the collapsed shape above and let the
higher-level batch commit own it, exactly as the existing domain skills already do.

---

## skill-base.sh Functions Referenced Here

The full function-signature table and step-by-step authoring walkthrough live in
`docs/guides/creating-skills.md` — this document does not duplicate that table. The functions
named in the Stage-N table above are exactly the subset `creating-skills.md` documents, plus two
orchestrator-only functions (`skill_gate_completion_claim`, `skill_corroborate_phase_counts`)
called out above as explicitly out of scope for the per-skill stage list. If a function name
appears here that you cannot find in `creating-skills.md`'s table, treat the gap as this
document's own error, not a reason to hand-roll the logic — grep `scripts/skill-base.sh` for the
authoritative signature and header comment.

---

## Frontmatter Requirements

**Core skills** (`.claude/skills/skill-{name}/SKILL.md`) — call `skill-base.sh` functions
directly and invoke agents with explicit `subagent_type`:

```yaml
---
name: skill-{name}
description: {description}. Invoke for {use case}.
allowed-tools: Agent, Bash, Edit, Read, Write
---
```

**Extension/domain skills** (`.claude/extensions/*/skills/skill-{name}/SKILL.md`) — thin wrappers
under ~110-170 lines, same shared-block imports, domain-specific Stage 4/4a content only:

```yaml
---
name: skill-{name}
description: {description}. Invoke for {use case}.
allowed-tools: Agent, Bash, Edit, Read, Write
---
```

See `docs/guides/creating-skills.md`'s "Pattern A" / "Pattern B" split and step-by-step guide for
the full frontmatter decision matrix (including the older `context: fork` + `agent:` shorthand
some skills still use).

---

## Status Transitions by Workflow Type

| Workflow | Preflight Status | Postflight Status | Artifact Type |
|----------|-------------------|---------------------|----------------|
| Research | researching | researched | research |
| Planning | planning | planned | plan |
| Implementation | implementing | completed/implementing | summary |

---

## Error Handling

### Preflight Errors
- If Stage 2 (`skill_preflight_update`) fails, abort immediately — do not proceed to Stage 3 with
  an unset/unchanged status, and do not invoke the subagent.

### Agent Errors
- If the subagent returns `partial` or `failed`, do NOT run the Stage 7 status advance
  (`skill_postflight_update` already no-ops on a non-success status). Keep the task in its
  preflight-set status (e.g. `researching`) so the next `/research`/`/plan`/`/implement` invocation
  resumes rather than silently re-reporting success.

### Postflight Errors
- Log the error but don't fail the workflow — artifacts were already created by the agent, and
  status can be corrected manually or by re-running the command.

---

## Exclusion Criteria

Not every skill needs this lifecycle pattern. Skills matching these patterns are excluded:

| Pattern | Description | Example Skills |
|---------|--------------|-----------------|
| **Utility** | Provides a utility function, no task state management | skill-git-workflow |
| **Task Creation** | Creates new tasks, does not transition existing tasks | skill-meta |
| **Autonomous Loop** | Runs multi-phase lifecycle autonomously, delegates to workflow skills | skill-orchestrate (both effort modes) |
| **Terminal State** | Operates only on completed/abandoned tasks | (archive operations) |
| **Non-Task** | Operates on different data like errors or reviews | (error/review skills) |
| **Mechanism** | IS the status update mechanism itself | skill-status-sync |

### Workflow Skills (Follow This Pattern)

These skills manage task lifecycle transitions and follow the Stage-N skeleton above:
- skill-reviser (researched -> revising -> researched, new plan version)
- Every extension's `skill-{domain}-research` / `skill-{domain}-implementation` pair
  (not_started/researched -> researching -> researched, researched -> planning -> planned,
  planned -> implementing -> completed)

For `general`/`meta`/`markdown` task types the base lifecycle research/plan/implement skills (and
their standalone hard-mode variants) that used to own these same transitions — not_started/
researched -> researching -> researched, researched -> planning -> planned, planned ->
implementing -> completed — are deleted. `skill-orchestrate` now runs these transitions itself
via its own dispatch stages (both effort modes) rather than delegating to a skill that follows
this Stage-N skeleton.

### Non-Workflow Skills (Excluded from Pattern)

- skill-status-sync: IS the mechanism, used for standalone operations
- skill-git-workflow: creates commits, no task state
- skill-orchestrate (both effort modes, one engine): runs the autonomous lifecycle loop
  (dispatches to workflow skills, which handle their own state)
- skill-meta: creates tasks via interview, no transitions

---

## Parallel Invocation

`/orchestrate` invokes multiple agents in a single message for multi-task dispatch (its
Stage MT loop; the former per-command `/research`/`/plan`/`/implement` multi-task dispatch has
been retired along with those commands):

```
/orchestrate 7, 22, 24 --research
  -> Agent(general-research-agent, task {N})   \
  -> Agent(general-research-agent, task {N})   > all invoked in a single message
  -> Agent(general-research-agent, task {N})  /
```

Each dispatched agent runs **independently** with its own preflight, delegation, postflight, and
(per the historical split-shape rationale above, now owned by `skill-orchestrate` itself) its own
inline git commit. Multiple parallel instances may write to `state.json` concurrently — this is
acceptable because every write is scoped to a specific `project_number` via
`select(.project_number == $num)`, so no instance touches another task's fields.

---

## Postflight Boundary Restrictions

After the subagent returns (Stage 6 onward), a skill MUST NOT edit source files, run build/test
commands, call MCP/WebSearch tools, or analyze/grep source — that is agent work. Postflight is
limited to: reading the metadata file, calling `update-task-status.sh` (via
`skill_postflight_update`), incrementing `next_artifact_number`, linking artifacts, committing,
and cleanup. Every agent-delegating skill MUST include a `## MUST NOT (Postflight Boundary)`
section stating this explicitly — `lint-postflight-boundary.sh` enforces the section's presence
across the full skill corpus. See `@.claude/context/standards/postflight-tool-restrictions.md`
for the complete allowed/prohibited operation tables and the MUST NOT section template.

---

## Division of Labor with `docs/guides/creating-skills.md`

These two documents used to overlap and drift apart (a stale Stage-0-through-6 layout here that
matched zero actual skills, while `creating-skills.md` carried its own independent stage sketch).
They now split cleanly:

- **`docs/guides/creating-skills.md`** owns: the `skill-base.sh` function-signature table, the
  thin-wrapper authoring walkthrough (step-by-step skill creation), the frontmatter decision
  matrix (Pattern A core vs. Pattern B extension), the validation checklist, and common-mistakes
  examples. Its claim that core skills "use `skill-base.sh` lifecycle functions directly" was
  aspirational (false) when originally written — no core skill called those functions yet at the
  time — and is now true, following the conversion this document's own Stage-N skeleton reflects.
  See this document (`skill-lifecycle.md`) for the concrete stage-by-stage mapping that makes that
  claim verifiable.
- **`skill-lifecycle.md`** (this document) owns: the Stage-N skeleton itself, the shared-block map
  (which `@`-import implements which stage), the two postflight shapes, and the exclusion
  criteria for which skills follow the pattern at all.

When updating one, check whether the other needs a matching update — but do not re-duplicate
content between them; cross-reference instead.

---

## References

- Inline patterns: `@.claude/context/patterns/inline-status-update.md`
- Shared preflight block: `@.claude/context/patterns/skill-preflight-flow.md`
- Shared postflight block: `@.claude/context/patterns/skill-postflight-flow.md`
- Shared self-execution fallback: `@.claude/context/patterns/skill-self-execution-fallback.md`
- Literature `--lit` resolution flow: `@.claude/context/patterns/lit-stage4a-flow.md`
- Anti-stop patterns: `@.claude/context/patterns/anti-stop-patterns.md`
- Subagent return format: `@.claude/context/formats/subagent-return.md`
- Postflight restrictions: `@.claude/context/standards/postflight-tool-restrictions.md`
- Git staging scope (per-operation commit contract): `@.claude/context/standards/git-staging-scope.md`
- Authoring walkthrough and function table: `docs/guides/creating-skills.md`
