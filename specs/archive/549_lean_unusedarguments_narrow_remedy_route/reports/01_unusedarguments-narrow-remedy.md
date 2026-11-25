# Research Report: Task #549

**Task**: 549 - Give the Lean unusedArguments remedy a narrow route instead of the wholesale runLinter --update rewrite
**Started**: 2026-11-22T15:19:00Z
**Completed**: 2026-11-22T16:05:00Z
**Effort**: low
**Dependencies**: None (state.json `dependencies: []`; the BimodalLogic-numbering "task 785" named in the task description was dropped at migration — see Findings)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`, `index-entries.json`, `EXTENSION.md`, git history for the pattern file, `specs/state.json` (tasks 549, 539, 544, 576, 502), `agent-system/extensions/core/scripts/validate-context-index.sh`
- Task description / dispatch file (`specs/549_.../.dispatch/6.md`), which carries the full measured incident
**Artifacts**: specs/549_lean_unusedarguments_narrow_remedy_route/reports/01_unusedarguments-narrow-remedy.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's framing ("file does not exist yet, task 785 creates it, this is a fourth
  gate-collision fact") is **stale relative to this repository's current state**: the target
  file `plan-authoring-gate-collisions.md` already exists, already carries nine numbered
  Conditions (1-9), and is already wired into `EXTENSION.md` and `index-entries.json`. The
  BimodalLogic-repo task that this record's own description names as its dependency ("task 785")
  was never migrated into this repository's numbering (`migrated_from.dropped_dependencies: [785]`
  in `specs/state.json`) — the file was independently authored here by other, already-completed
  local work (git log: `c48adb7cf` conditions 1-4, `6ffc0f227` conditions 5-9, `dd51473b8`
  task 597 phase 2 fix to Condition 7/1).
- Task 549's own `state.json` entry carries `dependencies: []` — there is no outstanding blocker.
  The deliverable is simply the **next** Condition (Condition 10) appended to the existing file,
  not a "fourth fact" into a yet-to-exist one.
- Checked both named relation tasks (539 = BimodalLogic #813, 544 = BimodalLogic #824): both are
  `not_started` with no reports yet, so there is nothing written to restate or collide with.
  Neither's description touches linter/nolints mechanics.
- Recommended approach: add **Condition 10 — `unusedArguments` From a Batch Env-Linter Is a
  Ledger-Row Remedy, Not an In-Source `set_option`** to the existing file, in the same style as
  Conditions 1-9 (see Recommendations for drafted text ready for the plan/implement phase).
  Decision: the ledger row (`nolints.json`) is the correct remedy for this linter category; an
  in-source `set_option` suppression is the correct mechanism for the *sibling* categories
  (`unusedVariables`, `unusedFintypeInType`) already suppressed that way on the same Goal, not for
  `unusedArguments` itself — see Decisions for the full reasoning and the rejected alternative.
- Downstream consumer: open task 576 (`lean_plan_tier_gate_naming_and_marker_duty`) already
  declares `dependencies: [549]` and a `file_scope` naming both this pattern file and
  `index-entries.json`, so it will append further Conditions after whatever this task leaves
  behind — numbering sequencing is already serialized correctly by that dependency edge.

## Context & Scope

This is a `meta` task whose sole deliverable is durable plan-authoring guidance for the lean
extension: a new entry in the "gate collision" checklist a Lean plan author consults before
writing a verification criterion. The research question was narrow: (1) confirm the actual
current state of the target file and its dependency chain (the dispatch text was written before
a repository migration and may not reflect the file's present state), (2) read the two named
relation tasks to avoid restating their content, (3) resolve the technical decision the dispatch
asks this record to make — ledger row vs. in-source `set_option` for the `unusedArguments`
finding — and record the rejected option on its own merits.

Out of scope, per the dispatch's own explicit constraints: this is not a data-repair record (the
four existing `nolints.json` exemption rows mentioned in the measured incident, and the Goals'
`set_option` lines, are in the *source* BimodalLogic/FormalSystem repository, not this one, and
this task must not re-run `lake exe runLinter --update` or re-edit any Goal). No experimental
verification of the `set_option`-vs-ledger decision was performed for the same reason — the
decision below is reasoned from linter architecture plus the measured incident's own evidence,
not independently tested, and is flagged as such.

## Findings

### Codebase Patterns

1. **The target file already exists and already has nine Conditions.** Read in full:
   `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`
   (228 lines, matching `index-entries.json`'s recorded `line_count: 228` exactly — no drift).
   Conditions 1-9 cover: (1) Lean line-count changes tripping two generated surfaces, (2)
   `verify-deploy.sh`'s target-argument shape, (3) unsatisfiable "matches nothing" sweeps over
   refutation-probe paths, (4) repo-wide lint criteria as baseline deltas rather than absolute
   zero, (5) `check-metalogic-cycles.sh` Assertion B's equality (not containment) check, (6) C26's
   `def`/`abbrev` underscore rule and `theorem`'s exemption, (7) the `longFile` 1500-line ceiling's
   narrow baselining-acceptance window, (8) the `show` tactic being linted plus CI's `--wfail`
   (any linter category is a hard gate), (9) C5's module-path-regex false positives on
   module-path-shaped declaration names, plus a trailing bare-conditions checklist (C15, C33,
   `FAIL INV`). **None of the nine addresses `unusedArguments`, `nolints.json`, or
   `runLinter --update`** — confirmed by reading the full file text, not inferred. There is no
   overlap to avoid; Condition 10 is genuinely new material.

2. **The file's authorship and wiring predate this task and are unrelated to the BimodalLogic
   migration lineage.** `git log --oneline -- context/project/lean4/patterns/plan-authoring-gate-collisions.md`
   shows three commits: `c48adb7cf` ("lean: author plan-authoring gate-collisions guidance,
   conditions 1-4"), `6ffc0f227` ("lean: extend plan-authoring gate-collisions guidance, conditions
   5-9"), `dd51473b8` ("task 597 phase 2: correct longFile Condition 7 and link Condition 1 to the
   general rule"). `EXTENSION.md` already lists the file (line 39: "Gate collisions for plan
   authoring"), and `index-entries.json` already carries a full entry for it (`domain: project`,
   `subdomain: lean`, `load_when.agents: [lean-research-agent, lean-implementation-agent]`,
   `load_when.task_types: [lean4]`, summary: "Nine gate surfaces a Lean plan author must
   enumerate...").

3. **The dependency the dispatch names ("task 785 creates it") was dropped at migration, not
   silently lost.** `specs/state.json`'s entry for project 549 carries
   `"dependencies": []` and `"migrated_from": {"dropped_dependencies": [785], ...}` — the
   migration record itself states (in the dispatch text's own MIGRATION PROVENANCE block):
   "dropped edge(s) on source-repository task(s) 785 -- each referent is completed, archived, or
   stays behind, so the edge cannot be expressed in this repository numbering space". No local
   task creates this file as a first-time act, because it was already created by local work
   unconnected to the BimodalLogic migration (see Finding 2). The dispatch's phrase "which does
   not exist yet" is accurate only for the point in time the BimodalLogic record was authored,
   not for this repository today.

4. **Downstream dependent already serializes correctly on this task.** Task 576
   (`lean_plan_tier_gate_naming_and_marker_duty`, `not_started`) carries
   `"dependencies": [549]` and `"file_scope": ["agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md", "agent-system/extensions/lean/index-entries.json"]`.
   Its own description (read in full) proposes three further conditions ("Condition A" — a
   verification-tier gate-naming rule — "Condition B" — the `Constraints consumed:` marker duty —
   and "Condition C" — the `lake-build-guard.sh` 900s replay window) and explicitly anticipates
   this task: "TERRITORY. `...plan-authoring-gate-collisions.md` is also claimed by the open
   record `lean_unusedarguments_narrow_remedy_route` ... A dependency edge on that record is
   declared to serialize the shared file. Read its landed state first: if it has already added a
   condition covering that linter, Condition A cites it for the remedy." This means: (a) this
   task's implementation should land as the next sequential Condition number after whatever is on
   disk at implement time (re-read the file immediately before editing, per the Territory block's
   concurrency note — no other sibling task in this cycle's Territory JSON touches this file, but
   576 is a future consumer that depends on 549 landing first); (b) 576's own future author should
   read this record's landed Condition before writing its Condition A, to avoid restating the
   `unusedArguments` trigger it only mentions in passing.

5. **Relation check performed on tasks 539 and 544 — no overlap found.** Both are local tasks
   corresponding to the BimodalLogic numbers the dispatch names (813 -> local 539
   `lean_plan_challenge_block_authoring_contract`; 824 -> local 544
   `fixture_dependent_challenge_statement_pinning`), confirmed by reading `specs/state.json`'s
   `project_name` fields directly rather than assumed from the number alone. Both are
   `status: "not_started"` with empty `artifacts` — there is no written report or plan to collide
   with. Read each task's full `description` field:
   - 539 concerns a Verification criterion contradicting a plan's own pinned Challenge Statements
     block, and a Verification criterion naming `lean-challenge-snapshot.sh --check` without
     scheduling the snapshot prerequisite. Nothing about linting or `nolints.json`.
   - 544 concerns the Challenge-pinning mechanism's inability to express a fixture-dependent gate
     statement (the snapshot assembler forces matched declarations, including `def`, to `sorry`).
     Nothing about linting or `nolints.json`.
   Neither restates, nor is restated by, this task's `unusedArguments`/`nolints.json` finding —
   they address different consequences of the same *pinning mechanism* (a Challenge Statements
   block), which is exactly the relationship the dispatch's RELATION note anticipated ("adds the
   LINTER-REMEDY consequence of pinning, not a new pinning rule").

6. **`index-entries.json`'s `line_count` field is advisory, not a blocking gate.**
   `agent-system/extensions/core/scripts/validate-context-index.sh` reads each entry's
   `line_count`, compares it against the file's actual line count with a tolerance, and on
   mismatch calls `log_warning` (not `log_error`) — confirmed by reading the script directly
   (lines ~119-150). A mismatch after this task appends Condition 10 is therefore a non-blocking
   warning, not a gate failure, and is correctable later (by this task's own implement phase, or
   by task 576's implement phase, which already declares `index-entries.json` in its
   `file_scope`) via `generate-context-line-counts.sh --write`. This is a minor planning note, not
   a blocker: the plan should still update `line_count` and the `summary` string in the same
   phase that appends Condition 10, since task 549's own `file_scope` in `state.json` currently
   names only the pattern file itself — the plan should add `index-entries.json` to file scope
   (via `proposed_file_scope`, below) rather than leave the metadata stale pending task 576.

### External Resources

No web research was needed. The relevant facts — Mathlib-style environment-linter architecture
(a batch `#lint`/`runLinter` pass driven by nolint attributes/ledgers, distinct from
elaboration-time `set_option linter.<name>` diagnostics) — are general Lean/Mathlib tooling
knowledge already corroborated by the measured incident's own evidence (see Decisions), and the
dispatch explicitly forbids re-running the linter or re-editing the Goals to re-verify it
experimentally in the source repository. No external documentation fetch was performed; the
decision below is marked accordingly as reasoned-not-tested.

## Decisions

**Decision**: the ledger row (a hand-inserted `nolints.json` entry, in the file's own existing
format, placed next to an existing exemption of the same shape) is the correct remedy for an
`unusedArguments` finding raised by a batch/environment-linter pass (the measured incident's own
framing: "gate C16's `env_linter` batch reported one `unusedArguments` finding"). An in-source
`set_option linter.unusedArguments false in` immediately preceding the Goal is **not** the
correct alternative for this specific category, and should not be pre-authorized as one in the
new Condition.

**Reasoning**:

1. **Architectural distinction between the two suppression surfaces available in this class of
   Lean library.** A batch/environment linter (Mathlib's `#lint` family, invoked here via
   `lake exe runLinter`) walks the whole declared environment after elaboration and reports
   findings keyed by declaration + linter name; its suppression mechanism is an out-of-band
   ledger (`nolints.json`) or an in-source *declaration attribute* (conventionally
   `@[nolint <linterName>]`), never a `set_option`. An elaboration-time linter (the kind that
   produces `unusedVariables`, `unusedFintypeInType`) is a different mechanism entirely: a
   `set_option linter.<name> false` toggles a per-elaboration diagnostic and is read by the
   elaborator itself while it processes that one declaration, which is exactly why it can be
   scoped locally with `set_option ... in` immediately above a single declaration.
2. **The measured incident is itself direct evidence for this split, not just a precedent for
   the ledger route.** The same Goal in the originating incident used `set_option` suppressions
   for `unusedVariables` and `unusedFintypeInType` — both elaboration-time categories — on the
   very same declaration, while using a `nolints.json` row specifically for `unusedArguments`.
   If `set_option linter.unusedArguments false in` had been a working local suppression for that
   batch-linter category, the same author, already reaching for `set_option` on that Goal for two
   sibling findings, had every incentive to use it for the third rather than hand-edit an
   external ledger. That they did not is circumstantial but pointed evidence that the batch pass
   does not consult that option name.
3. **The general rule to record in the new Condition** (stated as a checkable condition, per the
   dispatch's own "condition under which each is correct" instruction): use the ledger row (or,
   where the project's linter harness is confirmed to support it, an in-source
   `@[nolint unusedArguments]` declaration attribute — functionally the same remedy, just recorded
   in-source instead of externally) whenever the finding comes from the project's batch/env-linter
   pass; use an in-source `set_option linter.<name> false in` only for findings that are
   elaboration-time linter diagnostics, which is a different, narrower category that happens to
   include the two sibling suppressions already on this same Goal.

**Rejected alternative, stated on its own merits**: an in-source `set_option
linter.unusedArguments false in` colocated with the pinned hypothesis has real appeal — it keeps
the exemption visually next to the declaration that needs it, self-documents without touching a
shared external file at all, and would match the suppression pattern already used for this Goal's
other two findings, giving the Goal one uniform suppression style instead of two. It is rejected
here specifically because `unusedArguments` is raised by the batch/environment-linter pass rather
than by an elaboration-time linter category, and nothing in the measured incident or in this
harness's design indicates `linter.unusedArguments` is an option name the batch pass actually
reads — adopting it as the pre-authorized remedy risks a silent no-op (the Goal still fails gate
C16's batch check when it next runs) discovered only when the gate re-runs, which is precisely the
mid-phase discovery this record exists to prevent. This reasoning is **inferred from linter
architecture plus the measured incident's own contrastive evidence, not independently tested** in
the source repository — the dispatch forbids re-running `runLinter` or re-editing the Goals as
part of this record, so no experiment to directly confirm `set_option linter.unusedArguments`'s
effect (or lack of one) was performed.

## Recommendations

Append the following as **Condition 10** to
`agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`,
in the same style as the existing nine (a descriptive heading, the mechanism, then a
**Plan-authoring consequence** bullet). This text is drafted ready for the plan/implement phase
to lift with minimal editing; renumber only if the file has gained further Conditions between
this report and implementation (re-read the file first, per the Territory concurrency note):

> ## Condition 10 — `unusedArguments` From a Batch Env-Linter Is a Ledger-Row Remedy, Not an
> In-Source `set_option`
>
> `lake exe runLinter --update <lib>` regenerates the whole project lint ledger (e.g.
> `scripts/nolints.json`) in its own serialization; it is **not** an additive insert. Naming it as
> a phase's remedy for a single `unusedArguments` finding authorizes a repository-wide file
> rewrite in the middle of that phase — one measured run changed 1,119 lines for a single
> intended exemption.
>
> **The narrow route**: hand-insert the one exemption row directly in the ledger file's own
> existing format, placed next to an existing exemption of the same shape, never by running
> `--update`. Carry the reason in the in-source `set_option` suppressions already attached to the
> declaration for its other linter categories, not in the ledger row itself.
>
> **Why this finding is predictable, not incidental**: a Goal whose signature is PINNED by a
> plan's Lean Challenge Statements block will trip `unusedArguments` whenever the pinned
> hypothesis is not read by the proof body — the hypothesis exists in the signature because the
> Challenge pins it, not because the proof needs it. This is a predictable consequence of pinning,
> not a defect in the proof.
>
> **Ledger row vs. in-source `set_option` — use the correct surface for the category.**
> `unusedArguments` is raised by the project's batch/environment-linter pass (`lake exe
> runLinter`/`#lint`), which is suppressed by a ledger row or an in-source nolint *attribute*
> (`@[nolint unusedArguments]`, where the harness supports it) — never by a `set_option`.
> `set_option linter.<name> false in`, scoped to the one declaration, is the correct mechanism
> only for genuinely elaboration-time linter categories (for example `unusedVariables`,
> `unusedFintypeInType`), which is why those two can sit as `set_option` lines on the same Goal
> while `unusedArguments` cannot: the batch pass does not consult a `set_option` named after it.
>
> **Plan-authoring consequence**: a plan whose Challenge Statements block pins a hypothesis a
> Goal's proof will not read should pre-authorize the narrow ledger-row remedy for the resulting
> `unusedArguments` finding at authoring time — naming the exact file and the hand-insert
> technique — rather than discovering the collision mid-phase and reaching for
> `runLinter --update` or a non-functional `set_option`.

Additional process recommendations for the implementing phase:

- Add `agent-system/extensions/lean/index-entries.json` to this task's `proposed_file_scope` (it
  is currently absent from `state.json`'s declared `file_scope` for task 549, which names only
  the pattern file). The plan should update that entry's `line_count` (currently 228, becomes
  `228 + <lines Condition 10 adds>`) and broaden its `summary` string (currently "Nine gate
  surfaces...") to reflect ten. This is advisory (`validate-context-index.sh` only warns on
  drift), not a blocking gate, but is cheap to do in the same phase and avoids leaving the drift
  for task 576 to discover.
- Re-read `plan-authoring-gate-collisions.md` immediately before editing at implement time (per
  this dispatch's own Territory concurrency note) in case another dispatch has appended a
  Condition 10 or 11 in the interim; number this task's addition as the next free slot rather
  than hard-coding "10" if the file has moved.
- No change to `EXTENSION.md` is needed — it already references the file by path and description,
  and that description ("Gate collisions for plan authoring") does not need updating for one more
  condition.

## Context Extension Recommendations

None — this is a `meta` task; per the research-agent contract, this section is omitted/set to
none for meta tasks since the deliverable itself *is* the context extension.

## Appendix

**Search queries / commands used**:
- `jq` queries over `specs/state.json` for `project_number` 549, 785, 813, 824, 840, 539, 544, 576,
  502, and for `.active_projects[].file_scope[]? | contains("plan-authoring-gate-collisions")`.
- `grep -n` over `specs/TODO.md` for `785`, `813`, `824`, `plan-authoring-gate-collisions`.
- `jq -r '.extensions.lean.source_dir' .claude-extensions.json` to resolve the source-store path
  (per `rules/source-store-deploy-boundary.md`).
- `ls`, `test -f`, full `Read` of
  `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`.
- `grep -n "plan-authoring-gate-collisions" EXTENSION.md`, `git log --oneline -- <file>`.
- `grep -n "line_count" index-entries.json` / full index entry read; `grep -n "line_count"
  validate-context-index.sh` plus surrounding context read to confirm advisory (warning-only)
  behavior.
- Full reads of tasks 539 and 544's `description` fields via `jq -r` for the relation check.

**References**:
- `specs/549_lean_unusedarguments_narrow_remedy_route/.dispatch/6.md` (full dispatch text, the
  measured incident, and the DECIDE AND RECORD instruction)
- `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`
- `agent-system/extensions/lean/index-entries.json`
- `agent-system/extensions/lean/EXTENSION.md`
- `specs/state.json` (project entries 549, 539, 544, 576, 502)
