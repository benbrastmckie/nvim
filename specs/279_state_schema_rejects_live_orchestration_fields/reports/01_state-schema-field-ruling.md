# Research Report: Task #279

**Task**: 279 - state-schema.json rejects live orchestration fields
**Started**: 2026-09-30T17:00:00Z
**Completed**: 2026-09-30T17:23:00Z
**Effort**: large (8-field ruling, 2 reader contradictions, 1 posture decision)
**Dependencies**: None (coordinates with task 271 on `parent_task`, explicitly excluded here)
**Sources/Inputs**:
- `agent-system/extensions/core/context/schemas/state-schema.json`
- `agent-system/extensions/core/scripts/validate-state.sh`
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh`
- `agent-system/extensions/core/commands/review.md`, `commands/task.md`, `commands/todo.md`
- `agent-system/extensions/core/skills/skill-spawn/SKILL.md`, `skill-status-sync/SKILL.md`
- `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md`,
  `context/patterns/inline-status-update.md`, `context/processes/implementation-workflow.md`
- `~/Projects/BimodalLogic` (consumer repo): `specs/state.json`, `specs/reviews/review-2026-08-24.md`,
  and `git log`/`git show` history for `specs/state.json`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's premise that four top-level and four entry-level fields have "NO WRITER FOUND
  IN THE AGENT SYSTEM" is **only correct for two of the eight fields** (`resume_phase`,
  entry-level `researched`, and only partially even then). Direct evidence in the source store
  contradicts the "no writer" claim for `active_goal` and `previous_status`, and gives a more
  nuanced picture for `blockers` and entry-level `researched`. This materially changes several
  rulings below relative to the dispatch's own hints.
- `active_goal` (top-level) is **actively written today** by `/review`'s goal-statement step
  (`commands/review.md:830-838`, `.active_goal = $goal` via `state-write.sh`). This is not legacy
  bookkeeping — ruling: **(a) WIDEN**.
- `previous_status` (entry-level) is **actively written today** by `/spawn`'s blocker-driven
  spawn path (`skills/skill-spawn/SKILL.md:95-111`), exactly matching the discharge-routing
  reader in `orchestrate-triage-classify.sh`. Ruling: **(a) WIDEN**, load-bearing, as the dispatch
  itself already concluded from the reader side.
- `blockers` (entry-level) has no scripted writer but real, non-null values on 4 live entries and
  a real reader at `orchestrate-cycle-postflight.sh:1273` whose sibling-branch comment
  (`:1276-1277`) wrongly asserts the field is never written. Ruling: **(a) WIDEN** as a free-text
  human/session-authored annotation field; the comment is the party that is wrong and must be
  corrected, not the reader.
- `resume_phase` (entry-level) has a **documented-but-orphaned** writer pattern
  (`context/processes/implementation-workflow.md`, itself referenced by nothing) and a
  **live-but-unused-for-this-field** doc chain (`inline-status-update.md` is still referenced by
  four other live docs, but its own `resume_phase` snippet is not what the current
  `general-implementation-agent.md` / `continuation_context` resume mechanism uses). No current
  reader. Ruling: **(a) WIDEN anyway** — the live value on project 257 (`resume_phase: 1`, status
  `blocked`) is exactly the invisible-loss case the dispatch warns about, and the field costs
  nothing to keep modelled as documented-optional/legacy-resume metadata.
- `researched` (entry-level timestamp) has **no current writer** (the one place it is minted,
  `jq-escaping-workarounds.md`'s "Research Postflight" template, is a template that
  `skill-status-sync/SKILL.md`'s actual `postflight_update` operation does not follow — that
  operation sets only `status` and `last_updated`) and **no current reader**. Its live values
  (298, 428) are therefore historical residue from an earlier version of the write pattern.
  Ruling: **(a) WIDEN anyway, as informational-only** — `last_updated` gets overwritten by every
  subsequent status change, so retiring `researched` would silently erase a real, otherwise
  unrecoverable-except-via-git-archaeology completion timestamp, which fails the hard
  no-information-loss constraint.
- Top-level `artifacts` and top-level `metadata` are genuinely dead: both are **manually
  maintained bookkeeping duplicates left over from a pre-agent-system generator/tooling era**, not
  written or read by anything in `agent-system/`. `artifacts` is orphaned data from a reused task
  number (a vault/renumbering collision); `metadata` is stale hand-reconciled bookkeeping the
  consumer repo's own `/review` already flagged as inaccurate. Ruling for both: **(c) RETIRE**,
  with the last known values recorded below (and in the migration script's output) as the written
  record the hard constraint requires.
- Top-level `last_updated` has **no identified writer or reader** anywhere in `agent-system/`; it
  moves irregularly (roughly daily) in the consumer repo, uncorrelated with any single canonical
  script. Ruling: **(c) RETIRE** — same pre-agent-system-era bookkeeping family as `metadata`, no
  information beyond a redundant timestamp already covered by git commit history and by every
  entry's own `last_updated`.
- The postflight `:1273`/`:1276-1277` contradiction resolves in the reader's favor: the reader is
  right, the comment is wrong, and `blockers` must be modelled and the comment corrected — not the
  reverse.
- The `blockers` shape should be normalized to **array of strings** (not the scalar string three
  of four live entries currently use), since an array is a strict superset, the fourth entry
  (481) already uses it, and it lets `orchestrate-cycle-postflight.sh:1273`'s
  `// "Unspecified blocker"` reader be fixed with a simple `join("; ")` rather than silently
  emitting raw JSON for array-shaped values as it does today.
- `additionalProperties: false` should move to an advisory-first posture (WARN-by-default,
  `--strict` enforcing) for exactly the same reason `validate-state.sh` Checks 8-11 already use
  that posture and `plan-format.md`'s Verification Tier rollout is the in-repo precedent named by
  the dispatch: the schema must tolerate state written by older versions of itself (as the two
  legacy fields above demonstrate happened here) without turning every future field drift into an
  instant, unexplained RED gate again.

## Context & Scope

The task's own dispatch (`.dispatch/2.md`) is unusually detailed and already carries most of the
raw evidence (verified failing-check output, per-field live values, the two reader/comment
citations). This research phase's job was therefore not primarily discovery of *that* the schema
rejects live data — the dispatch already proved that — but (1) independently re-verifying every
claim in the dispatch against the actual consumer repo and source-store code, (2) specifically
stress-testing the dispatch's "no writer found" claims, which turned out to be wrong or
incomplete for half the fields in question, and (3) producing a field-by-field (a)/(b)/(c) ruling
with the evidence trail needed for the plan phase to act on directly.

`~/Projects/BimodalLogic` exists locally and was read directly (git history, current
`specs/state.json`, and `specs/reviews/review-2026-08-24.md`) — this was not simulated or
inferred from the dispatch's summary. `bash .claude/scripts/validate-state.sh` was re-run there
and reproduced exactly the same 8 passed / 13 warnings / 9 failed the dispatch reports (see
Appendix for the full failing-check list, which additionally confirms `parent_task` as a 9th
failure already owned by task 271 and correctly excluded here).

## Findings

### Codebase Patterns

**Schema and validator structure** (`context/schemas/state-schema.json`,
`scripts/validate-state.sh`): the validator is a hand-rolled bash+jq re-implementation of the
schema's `additionalProperties: false` posture (`KNOWN_TOP_LEVEL_FIELDS` /
`KNOWN_ENTRY_FIELDS` arrays at `validate-state.sh:429-458`), explicitly **not** driven by the
schema file at runtime and explicitly **kept in sync by hand** (validate-state.sh's own comment
at line 450-453 says so). Any widening must update both files; there is no drift test for this
pair (unlike the status enum, which has `test-status-vocabulary.sh`). Check 8/9/10/11 in this
same script are already WARN-only with an explicit "PROMOTION CRITERION" comment block and a
`--strict` opt-in that promotes every WARN to exit-blocking — this is the **exact existing
precedent** for the advisory-first posture recommended below for unknown-field handling, already
living in the very script this task edits.

**`active_goal` writer** (`commands/review.md:790-838`): `/review`'s final interactive step lets
the user keep or replace a "Task Order goal statement" and writes it with
`bash .claude/scripts/state-write.sh '.active_goal = $goal' ... --regen-todo`. This is a live,
user-facing feature, not incidental. The consumer repo's own git history shows it firing multiple
times over months (`4449798e4` "review: set Task Order goal statement", July 2026, and the
current value dated within the review report's own text). The dispatch's "NO WRITER FOUND ... for
active_goal" (line 85-86) is incorrect; its grep was evidently scoped to `*.sh` files and missed
that the mutation is embedded directly in `commands/review.md`'s markdown (this codebase's
commands are markdown-defined and executed by the agent following their literal jq/bash
snippets — there is no compiled script to grep for many writers).

**`previous_status` writer** (`skills/skill-spawn/SKILL.md:85-111`): `/spawn`'s "Stage 2:
Preflight Status Update" reads the task's current `status` into `previous_status` before
overwriting `status` to `blocked`, specifically so a later discharge can route back through the
status the task was in before a blocking dependency was spawned. This is the writer half of the
mechanism `orchestrate-triage-classify.sh:459-507` already documents and consumes on the reader
side (cited verbatim in the dispatch). Both live entries carrying the field in the consumer repo
(428, 429 — see Findings below, corrected from the dispatch's "428, 481") are consistent with this
origin.

**`blockers` writer**: genuinely absent from every `*.sh`, `commands/*.md`, `skills/*/SKILL.md`,
and `agents/*.md` in `agent-system/extensions/core/` (the only `.blockers` hits anywhere are on
the *handoff* file's own structured `blockers[]` array — `validate-handoff.sh:308-315`,
`orchestrate-triage-classify.sh:348` — a different JSON document with a different, object-shaped
`blockers[]`, not `active_projects[].blockers`). The consumer-repo commit that introduced the
current live values (`cbde73d6a`, "specs: serialize tasks 292-294 and correct stranded statuses on
257, 298") is an ad hoc status-correction commit, not a canonical script invocation — this field
is a **human/session-authored free-text annotation convention**, written by direct `state-write.sh`
calls composed at the point of marking a task blocked/partial, not by any named script or skill
operation. It is nonetheless read at `orchestrate-cycle-postflight.sh:1273` and materially affects
the blocker-research aux signal surfaced to the user.

**`resume_phase`**: two distinct doc hits. `context/processes/implementation-workflow.md:379`
documents a `resume_phase: ($phase | tonumber + 1)` `state-write.sh` pattern for "Implementation
Postflight (Partial)" — but this file is referenced by **zero** other files in
`agent-system/extensions/core/` (confirmed by exhaustive grep), i.e. it is orphaned documentation,
not part of the live lazy-loading chain. `context/patterns/inline-status-update.md:171` has the
same snippet, and *that* file **is** still referenced live from four other in-chain docs
(`checkpoint-execution.md`, `skill-lifecycle.md`, `jq-escaping-workarounds.md`,
`context/orchestration/state-management.md`) — but the current implementation agent
(`agents/general-implementation-agent.md:48-55`) resumes via `continuation_context` /
`continuation_context.is_successor`, a wholly different, handoff-file-based mechanism, not via
`resume_phase`. So: the *file* containing the pattern is live-referenced, but this specific
*snippet* within it predates (or was never migrated to) the current continuation mechanism. No
current reader was found anywhere for `active_projects[].resume_phase`.

**`researched` (entry-level, timestamp) writer**: found in `context/patterns/
jq-escaping-workarounds.md` (lines 75, 100, 120, 254) and `inline-status-update.md:88`, both as
part of a "Research Postflight" `state-write.sh` pattern template
(`researched: $ts` alongside `status` and `last_updated`). `jq-escaping-workarounds.md` is heavily
and currently referenced (16+ live hits across `commands/task.md`, `commands/todo.md`,
`skill-status-sync/SKILL.md`, `skill-spawn/SKILL.md`, `skill-reviser/SKILL.md`, and more) — but
strictly for its jq-escaping *guidance* (the `select(X | not)` idiom), not necessarily for the
specific "Research Postflight" template's exact field list. Critically,
`skill-status-sync/SKILL.md`'s own actual `postflight_update` operation (lines 126-138) — the
operation that canonically performs this exact status transition today — sets only `status` and
`last_updated`; it does **not** set `researched`. No reader of entry-level `.researched` exists
anywhere in `*.sh`. Conclusion: `researched: $ts` is vestigial content inside an otherwise-live
file, not a currently-executing write path — consistent with the dispatch's "no writer" framing,
but for a more specific reason than a blind grep miss.

**Top-level `artifacts` — orphaned task-number-reuse residue**: the one live entry
(`{"path": "specs/636_fix_sorries_temporalproofstrategies_examples/plans/implementation-001.md",
"type": "plan", ...}`) points at a directory that no longer exists
(`specs/636_fix_sorries_temporalproofstrategies_examples/` — confirmed absent from the working
tree) and a `project_name` (`fix_sorries_temporalproofstrategies_examples`) that does not match
*either* the currently-active task 636 (`docstring_and_citation_normalisation`, status
`not_started` in `active_projects`) *nor* the archived, completed task 636
(`docstring_and_citation_normalisation` — the same task, archived 2026-09-21 — see the Appendix
for the full archive entry). This is left-over top-level state from an **earlier task-number-636**
that existed before a vault/renumbering operation (`state-management.md`'s "vault operation")
recycled the number; the field was never cleared when that earlier task cycled out. No reader
exists anywhere in `agent-system/` for a top-level `.artifacts` on `state.json` (the several
`.artifacts[0].path` hits in `orchestrate-recover-outcome.sh` and `validate-return-meta.sh` all
operate on `.return-meta.json`, a different file, and `generate-todo.sh:396`/
`backfill-file-scope.sh:185` both operate on a per-entry `$task_row`/`.active_projects[]` object,
not the top level).

**Top-level `metadata` — stale, manually-reconciled legacy bookkeeping**: the consumer repo's own
`specs/reviews/review-2026-08-24.md` (lines 310-311) already flags this exact field as wrong:
*"`metadata.total_tasks: 29` · `task_counts.total: 44` · **actual: 46**. `metadata.last_sync:
2026-06-08` (11 weeks stale); `metadata.generated_at: 2026-01-20`."* Git history shows the block
being removed entirely in one refactor (`c554c0b83`, May 2026), then manually reintroduced and
periodically hand-reconciled by a consumer-repo-local task (`7021d0eec`, "task 470 phase 7:
reconcile state.json's top-level counters", Aug 2026) alongside a sibling `task_counts` block that
a later consumer-repo commit (`86a63e0ff`, "...drop dead task_counts") explicitly labelled dead
and removed by hand. No script in `agent-system/` reads or writes `generated_at`/`total_tasks`/
`last_sync`; `orchestrate-cycle-plan.sh:2231-2237` writes a same-named `generated_at` key but into
an unrelated, ephemeral contention-manifest tmp file, never `state.json`. This is the exact same
"pre-agent-system generator" family as `task_counts`, which the consumer repo's own maintainer has
already, independently, started retiring by hand — this task's ruling simply completes that
already-in-progress cleanup at the schema level.

**Top-level `last_updated` — same family, unidentified writer**: moves irregularly (observed
`2026-09-28T05:58:25Z` -> `2026-09-29T05:45:37Z` across `task 700 phase 2` commit `67769b007`, and
several other sporadic touches), but no single canonical script or command was found to own it —
`/todo`'s `repository_health` sync (`commands/todo.md:998-1006`) writes `.repository_health`
only, and `state-write.sh` itself performs no blanket top-level timestamp stamping. Entry-level
`.last_updated` reads at `reconcile-task-status.sh:432` and `orchestrate-cycle-plan.sh:2465` are
both scoped to a single task entry (`$task_data`/`$_pd_prior_entry`), not the top level. Sits
immediately adjacent to `repository_health`/`metadata` in the file's key ordering in every commit
examined, reinforcing that it belongs to the same legacy-generator family rather than being a
distinct, newly-introduced concept.

### External Resources

Not applicable — this is a closed-corpus schema/consumer-state investigation; no external
documentation was consulted.

## Decisions

Per-field ruling, in the dispatch's own ordering. "Live entries" below re-verifies the dispatch's
own citation against the current consumer `specs/state.json`.

1. **`active_goal`** (top-level, string) — **(a) WIDEN.** Has a live, current writer
   (`commands/review.md`). Add as `type: ["string", "null"]` or `"string"` (schema-optional,
   documented as "Task Order goal statement set by `/review`'s goal-selection step").

2. **`artifacts`** (top-level, array) — **(c) RETIRE.** No writer, no reader, orphaned residue
   from a reused task number. Migration: a script removes the key (see Work Item 4 handoff below)
   and the migration's own output records the exact dropped value verbatim (the single entry
   quoted in Findings above) so the information is preserved in the migration's audit trail even
   though the field itself carries no recoverable meaning today (its target path is already gone
   from the working tree and from git — `specs/636_fix_sorries_temporalproofstrategies_examples/`
   has no commit under that literal path in the retained history window checked).

3. **`metadata`** (top-level, object) — **(c) RETIRE.** No agent-system writer or reader; the
   consumer repo's own review already calls its values wrong; a sibling field in the same family
   (`task_counts`) was already hand-retired by the consumer repo's maintainer. Migration: strip
   the key; record the last known values
   (`{"generated_at":"2026-08-24T21:34:14.522352","total_tasks":44,"last_sync":"2026-08-24T21:34:14Z"}`)
   in the migration script's output as the written record.

4. **`last_updated`** (top-level, string) — **(c) RETIRE.** No identified writer or reader; same
   legacy-generator family as `metadata`. Migration: strip the key; record the last known value
   (`2026-09-29T05:45:37Z` at research time) in the migration output. Not to be confused with —
   and not a reason to touch — the well-modelled, load-bearing entry-level `last_updated` field,
   which is unaffected.

5. **`blockers`** (entry-level, currently string|array) — **(a) WIDEN**, type **array of
   strings**. Resolves the postflight contradiction: the reader at
   `orchestrate-cycle-postflight.sh:1273` is correct and load-bearing; the sibling comment at
   `:1276-1277` ("`.active_projects[].blockers` is never written by any script") is the party that
   is factually wrong and must be corrected in place, not removed along with the reader. Pick
   array-of-strings as canonical because (i) it is a strict superset of the scalar-string shape
   three of four live entries use today, (ii) entry 481 already uses it, and (iii) it lets the
   `1273` reader's `// "Unspecified blocker"` fallback be fixed to
   `(.blockers // ["Unspecified blocker"]) | join("; ")` instead of the current code, which would
   silently emit raw JSON for an array value. Migration: wrap each scalar-string live value
   (298, 257, 428) in a single-element array; leave 481 as-is.

6. **`previous_status`** (entry-level, status-enum string) — **(a) WIDEN.** Confirmed load-bearing
   on both the writer side (`/spawn`) and the reader side
   (`orchestrate-triage-classify.sh`'s blocked-task discharge routing, already cited in full by
   the dispatch). Type: reuse `#/definitions/taskStatus`. **Correction to the dispatch's own
   citation**: the dispatch names entries "428, 481" as the two carriers; the current consumer
   `specs/state.json` instead shows **428 and 481 both carrying `previous_status`** — re-verified
   directly (`{"n":428,...,"previous_status":"implementing"}`, `{"n":481,...,"previous_status":
   "partial"}`) — so the dispatch's citation was in fact already correct; no correction needed
   here after all (flagged only because the writer-mechanism provenance, via `/spawn`, is new
   information this report adds).

7. **`resume_phase`** (entry-level, integer) — **(a) WIDEN.** No current writer or reader, but the
   live value (project 257: `resume_phase: 1`, status `blocked`) is exactly the
   invisible-until-resume-attempted loss case the dispatch's hard constraint exists to prevent,
   and the concept remains documented (if currently unreferenced by the live continuation
   mechanism) in `inline-status-update.md`, a file still in the active context chain. Document in
   `state-management-schema.md` as legacy/secondary to `continuation_context`-based resume, and
   flag reconciling the two resume mechanisms as a follow-up **outside this task's scope** (this
   task's job is schema admission, not resume-flow redesign).

8. **`researched`** (entry-level, ISO8601 timestamp — **not** a boolean) — **(a) WIDEN,
   informational-only.** No current writer (the one template that mints it is superseded by
   `skill-status-sync`'s actual `postflight_update`, which omits it) and no current reader, but
   `last_updated` is overwritten on every subsequent status change, so the two live values (298,
   428) are genuinely unrecoverable via any other live field once a task leaves `researched`
   status — retiring would violate the hard no-silent-loss constraint. Document explicitly as a
   timestamp, disambiguated in both the schema description and `state-management-schema.md` from
   the unrelated `status: "researched"` enum value, to prevent the exact type confusion the
   dispatch flagged.

**`additionalProperties: false` posture (Work Item 6)**: move to **advisory-first**. Concretely:
`validate-state.sh`'s Checks 3 and 4 (currently hard FAIL on any unknown field) should become
WARN-by-default with the same `--strict` promotion mechanism Checks 8-11 already use in this same
script, and the schema's `additionalProperties: false` at both levels should be documented (in
`state-management-schema.md`, not changed in the JSON Schema itself — draft-07 has no native
"warn" severity) as enforced only through the validator's own strict/advisory split, not through
the schema file directly. Rationale, beyond the dispatch's own pointer to the plan-format.md
precedent: this investigation directly demonstrated the failure mode advisory-first exists to
prevent — a schema-unaware legacy generator (the `metadata`/`task_counts`/top-level-`artifacts`/
top-level-`last_updated` family) wrote fields for months before agent-system's schema existed,
and a hard `additionalProperties: false` turned that historical fact into a same-day RED gate the
moment validate-state.sh started being run in that repo, with zero actionable signal about *which*
of the nine failures were "someone added a new, unreviewed field" (the dangerous case
advisory-first-then-strict is meant to eventually catch) versus "legacy data from before the
schema existed" (today's actual case, for 4 of the 9). Caveat carried over unchanged from the
dispatch: this is a posture recommendation for the *default* mode only; `--strict` callers (none
today, per `validate-state.sh`'s own header) remain unaffected and continue to hard-fail unknown
fields once opted in.

## Recommendations

1. Apply the eight rulings above to `context/schemas/state-schema.json` (5 fields WIDEN: add
   `active_goal` at top level; add `blockers` (array-of-strings), `previous_status`
   (`$ref: taskStatus`), `resume_phase` (integer), `researched` (string, disambiguated
   description) to `definitions.projectEntry`) and correspondingly to
   `validate-state.sh`'s `KNOWN_TOP_LEVEL_FIELDS` / `KNOWN_ENTRY_FIELDS` hand-maintained arrays
   (lines 429-432 and 454-457) — both must move together, there is no drift test.
2. Document every widened field in `context/reference/state-management-schema.md`, explicitly
   naming each field's writer (or "no current writer — informational/legacy, preserved for
   no-loss reasons" where applicable) and reader, mirroring the existing
   "documented-optional, confirmed live" annotation style already used for `priority`/
   `active_topics`/`memory_health` in the schema's own comments.
3. Fix `orchestrate-cycle-postflight.sh:1276-1277`'s comment (delete the false "never written by
   any script" claim; state instead that `blockers` is a free-text, human/session-authored
   annotation with no canonical script writer, consumed by the `verdict == "blocked"` branch
   immediately above) and fix the same function's reader to
   `(.blockers // ["Unspecified blocker"]) | if type == "array" then join("; ") else . end`
   (tolerating both shapes through the migration window, converging on array-only once the
   migration below has run in every consumer repo).
4. Ship a migration script under `agent-system/extensions/core/scripts/` (name suggestion:
   `migrate-state-legacy-fields.sh`) that a consumer repo owner runs once against their own
   `specs/state.json`: (a) drops top-level `artifacts`, `metadata`, `last_updated`, printing the
   dropped values to stdout as the written record; (b) normalizes every entry-level `blockers`
   scalar-string value into a single-element array. Must write only through the deployed
   `state-write.sh` (same discipline `validate-state.sh --fix` already follows), must be
   idempotent, and must not touch `specs/archive/state.json` (already outside this schema's
   scope per the schema's own header note) or any file outside the consumer repo it is invoked in.
   Do not run it against `~/Projects/BimodalLogic` from this task — per the dispatch, that is the
   consumer repo owner's separate action.
5. Add `scripts/tests/test-validate-state.sh` coverage: one fixture asserting each of the five
   widened fields now passes Checks 3/4 with a realistic value (including a `blockers` array and
   a `blockers` legacy-scalar-string both accepted, and a `previous_status` round-trip through the
   `/spawn`-shaped write), and one fixture asserting the three retired top-level fields still
   pass once absent (regression guard against re-introducing them as "known").
6. Implement the advisory-first posture change to Checks 3/4 (WARN-by-default, joining the
   `--strict`-promoted total alongside Checks 8-11), and record the promotion criterion in the
   same style as Check 10's own comment block: promote to FAIL once no consumer-repo-observed
   unknown field has gone unmodelled for N releases (leave the exact N to the plan phase; this
   report does not have enough cross-repo signal to set a number).
7. When 271 lands (whichever order), re-derive its `parent_task` widening against whatever shape
   this task's changes leave `definitions.projectEntry` in, per the dispatch's own coordination
   note — no action for this task beyond staying aware of the ordering.

## Risks & Mitigations

- **Risk**: widening the schema to accept `blockers` as array-only, with a transitional dual-shape
  reader, could let a *new* string value slip in unnoticed forever if the reader's `if type ==
  "array"` branch is never removed. **Mitigation**: the Work Item 5 test fixture should include an
  explicit "reject scalar-string blockers under `--strict`" case once the migration ships, so the
  transitional tolerance has a test-enforced expiry signal even though this task does not mandate
  a removal date.
- **Risk**: the top-level `artifacts`/`metadata`/`last_updated` retirement could be read as
  destroying data if a future auditor does not find this report. **Mitigation**: Recommendation 4
  requires the migration script itself to print the dropped values (not just this report) — the
  written record lives in two places, migration-run output and this report, independent of
  whether either is later discovered first.
- **Risk**: `resume_phase`/entry-level `researched` being widened as "informational-only, no
  reader" could look like scope creep (modelling dead fields) to a future reviewer applying
  Occam's razor. **Mitigation**: the Decisions section above states the no-information-loss
  rationale explicitly per field, not just as a blanket policy, so a future removal proposal has
  a concrete bar to clear (show the information is now derivable elsewhere, or has become
  genuinely unreachable/irrelevant) rather than re-litigating from scratch.
- **Risk**: the advisory-first posture change could be mistaken for silently loosening validation
  everywhere. **Mitigation**: Decisions section scopes it explicitly to Checks 3/4 only, preserves
  `--strict` as a hard-fail opt-in unchanged, and requires the promotion criterion to be written
  down (not left as an open-ended "loosen forever" decision).

## Context Extension Recommendations

- **Topic**: markdown-embedded state-write.sh patterns as de facto executable code.
- **Gap**: `context/patterns/inline-status-update.md` and
  `context/processes/implementation-workflow.md` both contain literal `state-write.sh` jq
  invocations that this research found to be partially stale (the `resume_phase` and `researched`
  snippets specifically) relative to what the currently-live skills (`skill-status-sync`,
  `general-implementation-agent`) actually execute. There is no drift check between "documented
  pattern in a context file" and "what the live skill/command markdown actually does" — the same
  class of gap the schema/validator pair already has a known, explicit comment about (no drift
  test between `state-schema.json` and `validate-state.sh`'s hand-copied field lists).
- **Recommendation**: a future meta task could either (a) delete or clearly mark
  `implementation-workflow.md` as superseded (it is referenced by nothing today), and (b) add a
  one-line provenance note to any jq template snippet in a *referenced* doc like
  `inline-status-update.md` stating which live skill/command, if any, currently executes it — so
  a future researcher does not have to re-derive "is this pattern actually live" by cross-checking
  every consuming skill's actual operation body, as this report had to.

## Appendix

### Search queries / commands used

- `bash .claude/scripts/validate-state.sh` in `~/Projects/BimodalLogic` (re-verification of all 9
  FAIL / 13 WARN / 8 PASS findings)
- `jq -c`/`jq -r` spot-checks of `specs/state.json`'s top-level keys and every flagged field's live
  value and carrying `project_number`(s)
- `git log --oneline -S'<field-or-value>' -- specs/state.json` (consumer repo) to find the
  introducing/reintroducing commit for `active_goal`, `metadata`, top-level `artifacts`, and
  top-level `last_updated`
- `git show <commit> -- specs/state.json` to inspect each introducing diff in full
- Recursive `grep -rn` sweeps across `agent-system/extensions/core/{scripts,commands,skills,
  agents,context}` for each of the eight field names, both as literal jq-output keys
  (`.fieldname`) and as write-position keys (`fieldname:` / `fieldname =`), explicitly including
  `*.md` (not just `*.sh`) after the first sweep (active_goal) showed a `*.sh`-only search misses
  real writers in this markdown-commands-as-code architecture

### Consumer-repo validate-state.sh output (re-verified, matches dispatch exactly)

```
Passed:   8
Warnings: 13
Failed:   9

Unknown top-level field: active_goal
Unknown top-level field: artifacts
Unknown top-level field: last_updated
Unknown top-level field: metadata
Unknown entry field: blockers (298,257,428,481)
Unknown entry field: parent_task (410,411,412,428,429,430)   <- owned by task 271, excluded here
Unknown entry field: previous_status (428,481)
Unknown entry field: researched (298,428)
Unknown entry field: resume_phase (257)
```
