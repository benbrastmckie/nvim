# Implementation Plan: Add purpose-written title fields to task records

- **Task**: 528 - Add purpose-written title fields to task records so TODO.md stops rendering truncated description prose as task names
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/528_state_json_title_fields_for_todo_readability/reports/01_title-fields-for-active-projects.md
- **Artifacts**: plans/01_state-json-title-fields.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`specs/state.json`'s `active_projects` array has 24 entries with no `.title`, and the two
generators that render task names fall back differently: `generate-todo.sh` derives a readable
heading from `project_name`, while `generate-task-order.sh` falls back to `.description` first
and truncates it to 65 characters, so the `## Task Order` section of TODO.md renders truncated
status prose instead of names. This plan writes a concise noun-phrase `.title` for each of those
24 entries through the mutex-guarded writer, regenerates TODO.md, proves both fallback chains
still work for a title-less entry, and corrects the schema documentation's false claim that
`.title` is "confirmed live on all current entries". Done means: every current `active_projects`
entry renders a purpose-written name in both TODO.md surfaces, the optional-field fallback is
empirically demonstrated to still work, and no generator, schema, or non-`title` field changed.

### Research Integration

The research report is integrated with three corrections, each re-verified live during this
planning pass:

- **The dispatch's cited figures are stale and are not used.** The dispatch names 61 title-less
  entries and a 28-number "wave-1" list; live `specs/state.json` has 151 entries, exactly 24
  title-less, and only six of the 28 cited numbers exist here at all. The authoritative target
  population is the live query, re-confirmed during this planning pass as exactly the report's
  24: 338, 412, 421, 439, 456, 502, 503, 504, 510, 511, 512, 521, 522, 567, 568, 569, 572, 573,
  589, 590, 591, 601, 602, 603.
- **Report Recommendation 2 (amend `file_scope` to add `specs/state.json` and `specs/TODO.md`) is
  rejected.** `scripts/lib/engine-written-state-paths-lib.sh` defines both paths as
  engine-written state that every `file_scope` Containment site admits *regardless* of the
  declared task's own `file_scope`, and its admission bar states a member must be "never
  legitimately declarable in any one task's own file_scope". Declaring them would be redundant
  (`git-commit-scoped.sh`, `git-commit-phase.sh`, and `orchestrate-cycle-postflight.sh` already
  splice them in) and would contradict that invariant. They are therefore deliberately absent
  from every phase's `Files to modify` block; see Risks & Mitigations for the residual exposure.
- **Report Recommendation 1's verification route needs splitting, because `--state` does not
  reach the Task Order section.** `generate-todo.sh` accepts `--state FILE`, but the Task Order
  section it embeds is produced by a nested `generate-task-order.sh --print` call that always
  reads the default `specs/state.json`, and `--print` mode discards the state override entirely
  (`STATE_ARG` is applied only under `--update-todo`). A single-command synthetic probe would
  therefore mix scratch-state headings with live-state Task Order output and silently prove
  nothing. Phase 3 uses two separately-scoped probes instead.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Write a concise noun-phrase `.title` (under 70 characters, no dates, no status prefixes, no
  task-number references) for all 24 currently title-less `active_projects` entries.
- Regenerate TODO.md and confirm the new titles render in both the per-task `### N. Title`
  headings and the embedded `## Task Order` grouped-by-topic listing.
- Demonstrate empirically that both fallback chains still serve a title-less entry, so `.title`
  remains optional in fact and not merely in documentation.
- Correct `state-management-schema.md`'s demonstrably false "confirmed live on all current
  entries" claim so the documentation states the real optional-field contract.

**Non-Goals**:
- No schema change: `.title` is already an accepted field in `validate-state.sh`'s known-field
  lists and is already consumed by both generators.
- No edit to `description`, `project_name`, `topic`, `status`, `dependencies`, or any other
  existing field on any entry.
- No change to `generate-todo.sh`, `generate-task-order.sh`, or `validate-state.sh`.
- No renaming of task directories (their names derive from `project_name`, which stays untouched).
- No whole-tree deploy regeneration; no phase declares `__WHOLE_TREE__` because no phase invokes
  the deploy script or the picker's reload/regenerate entries.
- No archival of the three already-`completed` entries in the target set (569, 573, 589); they
  are titled like the rest and left for `/todo` to handle on its own schedule.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A concurrent sibling dispatch (391, 532, 507 are scheduled this same cycle) mutates `specs/state.json` between planning and the write | M | H | Phase 1 re-derives the title-less set live rather than trusting this plan's list; Phase 2 writes through `state-write.sh`, whose fail-closed `specs/.scope-lock` mutex serializes the read-modify-write |
| A jq rewrite of the whole file reflows unrelated records, producing a huge spurious diff | M | L | Verified during planning: `jq . specs/state.json` is byte-identical to the file today, so it is already jq-canonical and `state-write.sh`'s jq pass reflows nothing. Phase 2 re-checks this before writing and bounds the diff by entry count |
| `specs/state.json` / `specs/TODO.md` are undeclared in `file_scope` (see Research Integration), so a Containment site that failed to source `engine-written-state-paths-lib.sh` would read the writes as a scope excursion | M | L | Every consumer implements a documented fail-open fallback to the hardcoded `("specs/TODO.md" "specs/state.json")` pair, so a sourcing failure reproduces current behavior rather than narrowing scope. Phase 2 confirms the commit succeeds rather than assuming it |
| `!=` in a jq filter is mangled to `\!=` (Claude Code issue #1132), corrupting the write filter | H | M | Phase 2's filter uses only the `== ... | not` form; the filter is dry-run first via `state-write.sh --dry-run` before any live write |
| A drafted title silently reintroduces banned content (a date, a `RE-SCOPED`-style prefix, a task-number reference) | L | M | Phase 1 runs a mechanical screen over the finalized mapping for length, digit-runs, and the banned prefix vocabulary before Phase 2 consumes it |
| Titling all 24 entries leaves zero live title-less entries, making the optional-field contract look mandatory | L | M | Phase 3 proves the contract on scratch copies instead of leaving a live readability hole; additionally confirmed during planning that no core task-creation script writes `.title`, so title-less entries recur naturally and the fallback stays live-exercised |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Re-derive the live title-less set and finalize title text [NOT STARTED]

**Goal**: Produce a confirmed, constraint-screened `project_number -> title` mapping covering
exactly the entries that are title-less in the live `specs/state.json` at implement time, staged
as a scratch JSON file for Phase 2 to consume.

**Tasks**:
- [ ] Re-read `specs/state.json` immediately (territory concurrency: siblings 391, 532, 507 run
      this same cycle) and re-derive the live title-less set:
      `jq -r '.active_projects[] | select((.title // "") == "") | .project_number' specs/state.json`
- [ ] Diff that set against the 24 numbers in the table below. For any number that gained a
      `.title` or left `active_projects`, drop it. For any number newly title-less, read its
      `description` and `project_name` and draft a title under the same constraints.
- [ ] For each entry in the final set, read its live `description` and confirm the drafted title
      still describes it accurately (the table below is draft text carried from research, not
      pre-approved output).
- [ ] Screen every finalized title mechanically: length under 70 characters; no four-digit
      year or ISO date; no `RE-SCOPED`/`STANDING`/`HARD`/`CAPSTONE`/`SUPERSEDES`/`MIGRATED`
      prefix; no `task N` / `tasks N-M` / `(task N)` reference.
- [ ] Write the finalized mapping as a flat `{"<number>": "<title>", ...}` JSON object to a
      scratch file for Phase 2's `--argjson` input, keys as strings.

Draft titles (carried from research, three reworded during planning to drop a count or an
identifier that read like a task reference — 521, 568, 590):

| project_number | Draft `.title` |
|---|---|
| 338 | Classify every task-support file as tracked or ignored |
| 412 | Map core verification tiers to Lean build scopes |
| 421 | Close three gaps in the telemetry --meta evidence consumer |
| 439 | Rule on the propagation model for the bounded-wait agent contract |
| 456 | Exempt private npm/Cargo manifests from /tag's version gate |
| 502 | Require research reports to enumerate generated doc-sync surfaces |
| 503 | Document /revise's unavailability to a dispatched agent |
| 504 | Reconcile the Lean Goals-block harvester with its documented contract |
| 510 | Fix a missing lib dependency in the predispatch-review test fixture |
| 511 | Require git grep, not plain grep, for scope-hypothesis counts |
| 512 | Exempt built-in commands from the dead-command-recommendation lint |
| 521 | Fix the agent glob to match the -implement-agent.md variant |
| 522 | Fix report/summary heading-skeleton conformance across agents |
| 567 | Port the deployed-tree containment strip into git-commit-scoped.sh |
| 568 | Fix failing assertions in the orchestrate-cycle-postflight suite |
| 569 | Fix stale fixture dependency-copy lists across four test suites |
| 572 | Make the full verification tier honorable under batch concurrency |
| 573 | Fix two single-assertion test suite failures |
| 589 | Fix the hardcoded repo-root walk-up depth in five test suites |
| 590 | Resolve the /ide dead-command-recommendation findings |
| 591 | Decide the fate of the errors.json triage surface |
| 601 | Add a lint closing the repo-root walk-up defect class |
| 602 | Improve the conclusion stage's next-batch proposal quality |
| 603 | Make ROADMAP.md a generated artifact rendered from state.json |

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: the title-less population is exactly the 24 numbers tabled above (verified
live during planning: `jq '[.active_projects[] | select((.title // "") == "")] | length'` returned
24, and the number set matched the table exactly). The implementer confirms this by re-running
that same query and comparing set membership, not count alone, before drafting anything; a
mismatch adjusts the mapping rather than invalidating the phase.

**Tier Justification**: this phase writes no repository file at all — its only output is a
scratch JSON mapping outside the tree — so the `prose` row's diff read-through over the drafted
title text, plus the mechanical constraint screen in its own task list, is the complete covering
check.

**Files to modify**:

None. This phase is read-only against the repository; its only output is a scratch mapping file
written outside the tree, which is not a deliverable and is never committed.

**Verification**:
- The live title-less query and the finalized mapping have identical key sets.
- Every value in the mapping is under 70 characters and passes the banned-content screen.
- The mapping file parses as JSON (`jq empty`) and every key is a string.

---

### Phase 2: Apply the titles through state-write.sh and regenerate TODO.md [NOT STARTED]

**Goal**: Each entry in Phase 1's mapping carries its `.title`, no other field on any entry
changed, and TODO.md is regenerated from the new state.

**Tasks**:
- [ ] Confirm `specs/state.json` is still jq-canonical so the write reflows nothing:
      `jq . specs/state.json | diff - specs/state.json` must be empty (it was during planning).
- [ ] Re-read `specs/state.json` immediately before writing, per the dispatch's concurrency note.
- [ ] Dry-run the write first: `bash .claude/scripts/state-write.sh '<filter>' --session-id "$SID"
      --argjson t "$(cat <scratch-mapping>)" --dry-run`, with a filter that sets `.title` only
      where the mapping has a key AND the entry is still title-less. Use the `== ... | not` form
      throughout — never `!=`, which Claude Code issue #1132 mangles to `\!=`:
      `.active_projects |= map(if (($t[(.project_number|tostring)] == null) | not) and ((.title // "") == "") then .title = $t[(.project_number|tostring)] else . end)`
- [ ] Apply the write live (same invocation without `--dry-run`), then regenerate TODO.md with
      `bash .claude/scripts/generate-todo.sh` (or `state-write.sh --regen-todo` in the same call).
- [ ] Confirm the diff touches only `.title` keys: `git diff --stat specs/state.json` and a
      read-through of `git diff specs/state.json` showing added `"title":` lines and nothing else.
- [ ] Run `bash .claude/scripts/validate-state.sh` and confirm it passes.
- [ ] Commit `specs/state.json` and `specs/TODO.md` via `bash .claude/scripts/git-commit-scoped.sh`
      with an explicit two-file pathspec — never a directory or glob add, since siblings are live
      in this tree — and confirm the commit succeeds (this is also the live confirmation that the
      engine-written-state Containment splice admits both paths without a `file_scope` entry).

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: the write adds exactly as many `"title":` keys as Phase 1's mapping has
entries (expected 24, subject to Phase 1's re-derivation) and changes no other key anywhere in
the file. The implementer confirms this by counting added `"title":` lines in
`git diff specs/state.json` against the mapping's key count, and by confirming the diff contains
no removed lines other than the reflow-free context those additions sit in.

**Tier Justification**: every path this phase writes lies under `specs/**`, where the
suite-selection narrowing mechanisms do not apply (`specs/**` is the task-reference lint's own
exempt tree and doc-lint has no bearing on its content), so the honest covering check is the
purpose-built `bash .claude/scripts/validate-state.sh` over the edited file plus the
`git diff specs/state.json` read-through named in this phase's own task list.

**Files to modify**:

None declarable. This phase writes `specs/state.json` and regenerates `specs/TODO.md`, both of
which `scripts/lib/engine-written-state-paths-lib.sh` defines as engine-written state admitted by
every Containment site regardless of the declaring task's `file_scope`, and which that library's
own admission bar states are "never legitimately declarable in any one task's own file_scope".
Declaring them here would be redundant and would contradict that invariant.

**Verification**:
- `git diff specs/state.json` shows only added `"title":` lines, in count equal to the mapping's
  key count.
- `jq '[.active_projects[] | select((.title // "") == "")] | length' specs/state.json` returns 0
  (or exactly the count of any entry Phase 1 deliberately excluded).
- `bash .claude/scripts/validate-state.sh` passes.
- `git diff --stat` names only `specs/state.json` and `specs/TODO.md`.

---

### Phase 3: Confirm rendering in both surfaces and prove the fallback contract [NOT STARTED]

**Goal**: The new titles are confirmed visible in both TODO.md surfaces that render task names,
and both fallback chains are empirically shown to still serve a title-less entry — without
leaving any live entry title-less to demonstrate it.

**Tasks**:
- [ ] Confirm per-task headings: for a sample spanning the mapping (at least 338, 456, 591, 603),
      grep the regenerated `specs/TODO.md` for `### <N>. ` and confirm the heading now reads the
      purpose-written title rather than a `project_name`-derived string.
- [ ] Confirm the `## Task Order` surface: in the same `specs/TODO.md`, locate the grouped-by-topic
      listing and confirm the previously-truncated entries (338 rendered as
      `338 [NOT STARTED] — SOURCE STORE IS THE EDIT TARGET:...` before this task) now render the
      title. This is the surface where the defect actually manifested; the bare numeric dependency
      wave table carries no title or description text and is not a verification target.
- [ ] Prove the `generate-todo.sh` heading fallback on a scratch state: copy `specs/state.json`
      to a scratch path, delete `.title` from one entry with `jq 'del(...)'`, then run
      `bash .claude/scripts/generate-todo.sh --state <scratch-state> --dry-run --no-log` and
      confirm that entry's `### N.` heading renders the `project_name`-derived fallback. Read ONLY
      the heading from this output: the `## Task Order` section in it comes from the nested
      `generate-task-order.sh --print` call, which ignores `--state` and reads live
      `specs/state.json`, so that section of this output proves nothing about the scratch state.
- [ ] Prove the `generate-task-order.sh` description fallback separately, in the only mode that
      honors a state override: copy `specs/TODO.md` to a scratch path and run
      `bash .claude/scripts/generate-task-order.sh --update-todo <scratch-todo> <scratch-state>`,
      then confirm the stripped entry falls back to its truncated `.description` in the scratch
      TODO's grouped-by-topic listing. Confirm `specs/TODO.md` itself is unmodified afterwards
      (`git diff --stat` names it only if Phase 2's commit has not yet landed).
- [ ] Delete the scratch state and TODO copies.
- [ ] Record both probe commands and their observed outcomes in the phase's verification notes, so
      the optional-field contract has a durable evidence trail rather than an assertion.

**Timing**: 45 minutes

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: both fallback chains are per-entry and unconditional, so stripping `.title`
from one scratch entry is sufficient to exercise them (`generate-todo.sh`'s check is a per-entry
`[[ -z "$title" ]]` test with no cross-entry state; `generate-task-order.sh`'s is a per-entry
`(.title // .description // .project_name)` jq fallback). The implementer confirms this by
observing the stripped entry fall back while its neighbors keep their new titles in the same
scratch output.

**Tier Justification**: this phase writes no repository file — it runs two read-only generator
probes against scratch copies and reads the already-committed `specs/TODO.md` — so the `prose`
row's read-through over those outputs, against the two probe commands named in its own task list,
is the complete covering check.

**Files to modify**:

None. All probes read the repository and write only to scratch copies outside the tree, which are
deleted in this phase's own task list.

**Verification**:
- Every sampled entry's `### N.` heading in `specs/TODO.md` reads its new title.
- Every sampled entry's line in the `## Task Order` grouped-by-topic listing reads its new title,
  with no truncated-description prose remaining for any entry in the mapping.
- The scratch `generate-todo.sh --state ... --dry-run` output shows the stripped entry's heading
  falling back to its `project_name`-derived form.
- The scratch `generate-task-order.sh --update-todo` output shows the stripped entry falling back
  to its truncated `.description`.
- `git status --short` shows no leftover scratch files inside the repository.

---

### Phase 4: Correct the schema documentation's false presence claim and run the full gate [NOT STARTED]

**Goal**: `state-management-schema.md`'s Project Entry Fields table states the real
optional-field contract for `.title` instead of a presence claim that live data contradicts, and
the complete gate set passes over the task's whole body of work.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/reference/state-management-schema.md`'s
      Project Entry Fields table immediately before editing (the file is in this task's declared
      `file_scope`; no sibling declares it, but the tree is shared).
- [ ] Replace the `.title` row's "Documented-optional, confirmed live on all current entries"
      phrasing with an accurate statement: the field is optional, and the documented fallback
      chain covers a title-less entry — `generate-todo.sh` derives a heading from `project_name`,
      `generate-task-order.sh` falls back `(.title // .description // .project_name)`. The
      replacement must state the contract, not a live count, since any count goes stale the next
      time a task is created without a title.
- [ ] Apply the same correction to the `topic` and `session_id` rows, which carry the identical
      "confirmed live" phrasing and are likewise false: measured during planning, 3 entries lack
      `topic` and 119 lack `session_id`. Leaving two knowingly-false neighbors beside a corrected
      row is worse documentation than correcting all three, and a wording fix is not a schema
      change, so the NON-GOAL holds. Do not touch the `description` row — 0 entries lack it, so
      its claim is true today, though it carries the same brittleness.
- [ ] Confirm no row's `Type` or `Required` column changed: the edit is confined to the
      `Description` column of three rows.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path:
      `agent-system/extensions/core/scripts/verify-deploy.sh`). The no-argument form is valid here
      because this repository root holds both a deployed `.claude/` tree and the
      `agent-system/extensions` source store. Confirm every gate it aggregates passes; do not
      substitute `--only-gate`, `--only`, or `--skip-slow` for this run.
- [ ] Commit the schema-file edit via `bash .claude/scripts/git-commit-scoped.sh` with an explicit
      single-file pathspec.

**Timing**: 30 minutes plus the full gate run

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: exactly three rows of one table carry the false "confirmed live" phrasing
for a field that live data shows absent somewhere (`title`, `topic`, `session_id`), and the
`description` row's identical phrasing is currently true. The implementer confirms this before
editing by re-running, for each field named in that table,
`jq '[.active_projects[] | select((.<field> // "") == "")] | length' specs/state.json` and
matching the result against the row's claim — a fourth newly-false row is added to the edit, and
a row that has become true is left alone.

**Files to modify**:
- `agent-system/extensions/core/context/reference/state-management-schema.md` - correct the three
  rows (title, topic, session_id) whose "confirmed live on all current entries" phrasing in the
  Project Entry Fields table is false, so each states the real optional-field contract and its
  fallback chain instead.
  This file exists and is already in this task's declared `file_scope` (confirmed during planning);
  if the Project Entry Fields table or those row labels are absent when the phase runs, stop and
  report rather than inventing a target, since the correction has no other carrier.

**Verification**:
- `git diff agent-system/extensions/core/context/reference/state-management-schema.md` touches
  only the `Description` cell of the three named rows.
- No remaining row in that table asserts "confirmed live on all current entries" for a field that
  the live `jq` count shows absent on at least one entry.
- `bash .claude/scripts/verify-deploy.sh` passes with no failing gate.
- `bash .claude/scripts/validate-state.sh` still passes.
- `bash .claude/scripts/validate-artifact.sh specs/528_state_json_title_fields_for_todo_readability/plans/01_state-json-title-fields.md plan`
  passes.

## Testing & Validation

- [ ] `jq '[.active_projects[] | select((.title // "") == "")] | length' specs/state.json` returns
      0, or exactly the count of entries Phase 1 deliberately excluded.
- [ ] Every added title is under 70 characters and free of dates, status prefixes, and
      task-number references.
- [ ] `git diff specs/state.json` across the task shows only added `"title":` lines.
- [ ] `specs/TODO.md`'s per-task headings and `## Task Order` grouped-by-topic listing both render
      the new titles, with no truncated-description prose left for any entry in the mapping.
- [ ] Both fallback probes (Phase 3) observed falling back correctly on scratch copies.
- [ ] `bash .claude/scripts/validate-state.sh` passes.
- [ ] `bash .claude/scripts/verify-deploy.sh` passes (Phase 4, full gate set).
- [ ] No generator script and no non-`title` entry field was modified anywhere in the task's diff.

## Artifacts & Outputs

- `specs/state.json` — 24 (or the Phase-1-confirmed count of) entries gain a `.title`; no other
  field changes.
- `specs/TODO.md` — regenerated, rendering the new titles in both name-bearing surfaces.
- `agent-system/extensions/core/context/reference/state-management-schema.md` — three table rows'
  presence claims corrected to the real optional-field contract.
- `specs/528_state_json_title_fields_for_todo_readability/summaries/01_*-summary.md` — completion
  summary, including the two fallback-probe commands and their observed outcomes as the durable
  evidence trail for the optional-field contract.

## Rollback/Contingency

Each phase commits separately, so reverting is per-commit and needs no working-tree discard:
`git revert` the schema-file commit (Phase 4) and the `specs/state.json` + `specs/TODO.md` commit
(Phase 2) independently, then run `bash .claude/scripts/generate-todo.sh` to re-render TODO.md
from the reverted state. Nothing in this plan is destructive and no phase needs a precautionary
snapshot: the only non-additive operation is `state-write.sh`'s jq transform, which stages through
a private `mktemp` path under the `specs/.scope-lock` mutex and is dry-run before it is applied.
If a genuine rollback of uncommitted work ever becomes necessary mid-phase, follow
`context/contracts/recovery.md`'s rollback rung for the snapshot-then-rollback invocation shape
rather than discarding the tree directly — siblings 391, 532, and 507 share this working tree.
