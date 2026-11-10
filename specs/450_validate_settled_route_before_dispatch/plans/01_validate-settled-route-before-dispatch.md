# Implementation Plan: Make a Settled Route's Obligation Recordable, Required, and Propagated

- **Task**: 450 - Require a settled user-decision route to name the obligation it discharges, and check that claim before a dispatch spends a cycle on it
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None blocking. Territory edges declared in the task description: 447 (semantic — reconciled during research, see Overview), 449/407/443/274/275/378/328/435/448 (serialization-only; 328/435/448 operator-liftable)
- **Research Inputs**: `specs/450_validate_settled_route_before_dispatch/reports/01_validate-settled-route-before-dispatch.md`
- **Artifacts**: plans/01_validate-settled-route-before-dispatch.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md, no-record-versioning-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `/orchestrate` user-decision pipeline records an answer to `.decisions.json` and relays it
into the next dispatch file's `## Prior Decisions` section with the instruction "treat these as
settled", but nothing in the chain records — or can record — *what obligation the chosen route was
supposed to discharge*. The route therefore arrives at the implementer with the full authority of
a user decision and none of the checkability. This plan closes that gap by making the claim
recordable (an optional `obligation` field on each decisions entry), requiring it at proposal time
(a `user-decision-contract.md` amendment), and propagating it to the receiving agent with an
explicit verify-before-you-start instruction. Definition of done: a recorded route carries its
named obligation through to the dispatch file, the implementer is instructed to adjudicate it and
to raise a NEW blocking question (never a re-ask) if it does not hold, and every existing
four-field entry still validates and renders byte-identically.

**All edits land in the source store** (`agent-system/extensions/core/**`), never a deployed
`.claude/**` tree, followed by a redeploy — per `rules/source-store-deploy-boundary.md`.

### Mechanism Ruling (carried from research, not re-derived here)

**Adopt candidates (1)+(3). Reject candidate (2) as a general mechanism.**

- **(1) Make the claim recordable, then require it** — an optional `obligation` field on
  `.decisions.json` entries, written by the single sanctioned writer, documented in the one
  authoritative schema section, and required by the contract for any option offered as a ROUTE.
- **(3) Propagate the claim to the implementer** — render the obligation inline in the existing
  `## Prior Decisions` section with an instruction to verify discharge before beginning phase
  work and to raise a NEW, specific blocking question naming the second obstruction if it does
  not hold.
- **(2) Validate centrally between recording and dispatching — rejected.** The decisive reason is
  not cost but an architectural precedent already on record in the very script candidate (2) would
  modify: `context/formats/report-format.md`'s "Owner ruling — split by capability" paragraph
  states that for this composer's structurally closest existing feature, "the composer EMITS...
  The composer never adjudicates... The receiving agent ADJUDICATES", and that mechanical conflict
  detection was *excluded* because "deciding that a prior artifact's measurement contradicts a
  description's claim is a semantic relation between arbitrary spans". Judging whether a route
  discharges an obligation is that same relation. A narrow lexical check tuned to the one cited
  incident shape would be cheap but would not generalize; a general one would repeat a pattern
  this codebase has already written down, one section away, as out of scope for a composer. The
  known insertion seam is recorded for a future task that wants the narrow form anyway:
  `skills/skill-orchestrate/SKILL.md`'s Move 4, immediately after the record-decision call and
  before the next cycle's dispatch composition.
- **Field name decision**: `obligation` (not `discharges` or `discharges_obligation`) — snake-case
  single word, consistent with the existing optional `description_fingerprint`'s naming, and short
  enough to read inline in a rendered dispatch section. Recorded here so the contract amendment
  (Phase 2) does not have to wait on the writer change (Phase 1).

### Reconciliation with the Adjacent Composer Work (required ruling)

The task description required reconciling this record with the adjacent task that extended this
same composer's carried-figure obligation to "a dispatch's acted-on premise". **Ruling: that
mechanism does NOT already cover a settled route, so this record's scope stays full and does not
narrow to candidate (1) alone.** Two independent grounds, both from direct read:

1. **Different data source.** The `## Premise Re-Validation` block's `grep -nE` sweep runs over
   the task's `## Description` text only; it never opens `.decisions.json`. A decision's `answer`
   — the route — is invisible to it.
2. **Different claim shape.** Its six triggers are lexical carried-figure patterns (counts,
   pass/fail words, citations, absolute language). "Does this route discharge that obligation" is
   a structural claim, which the same Owner ruling assigns to the receiving agent.

The same adjacent work nonetheless supplies this plan's governing design shape: emit and point;
never adjudicate in the composer.

### Research Integration

- The writer already carries exactly one optional field beyond its four required ones
  (`description_fingerprint`), added via a **two-branch `jq -c -n` call** rather than an
  unconditional `+` merge — re-confirmed at `scripts/orchestrate-record-decision.sh:163-183`. That
  is the precedent Phase 1 imitates exactly.
- `handoff-schema.md`'s `## Decisions File Schema (.decisions.json)` section (around line 1075)
  documents `description_fingerprint` with shape/writer/omission-rule prose; Phase 1 adds the new
  field in the same documented shape.
- **Measured during planning, and it removes a whole phase**: `orchestrate-cycle-postflight.sh`'s
  WORK (e) relay (around line 1702) copies `.user_decision` **verbatim as a whole JSON object**
  (`jq -c '.user_decision // empty'`) into the `ask_user` verdict — it neither validates nor
  strips unknown keys. An added `obligation` key therefore flows from the agent's
  `.return-meta.json` through postflight into `pending_ask_user[]` with **zero postflight script
  change**. Only the Move 4 consumer needs wiring.
- `## Prior Decisions` rendering lives in two places that must change together: the
  `prior_decisions_block` jq expression (around `scripts/orchestrate-build-dispatch.sh:494-518`)
  and the section's emission/preamble (around the same file's lines 836-854).

### Premise Re-Validation (dispatch obligation, stated explicitly)

The dispatch's lexical extractor flagged five description lines. Each was checked against the
prior research report and against live state:

| Flagged claim | Result |
|---|---|
| Source store is the edit target; `.claude/**` is a disposable deploy artifact | **Confirmed unchanged.** All nine target paths exist under `agent-system/extensions/core/**`; `.claude-extensions.json` is present at the repo root |
| A grep of `user-decision-contract.md` for route/unblock/obligation/discharge/validate returns NOTHING | **Confirmed unchanged** by the research report's full read and re-confirmed here: the file's nine sections define `question`/`options`/`recommended`/`blocking` only, with no obligation or route language anywhere, including "When NOT to Raise One" |
| "Prefer (1)+(2) if the validation in (2) can be made cheap; fall back to (1)+(3)" | **Honored, with the basis sharpened.** Research ruled (2) out on architectural precedent rather than cost alone; this plan adopts (1)+(3) and records the ruling above |
| Do NOT weaken the do-not-re-ask instruction | **Carried into the plan as a hard constraint.** Phase 3's added instruction surfaces a NEW question naming the second obstruction; the existing "treat these as settled — do not re-ask" preamble wording is preserved verbatim and pinned by a test |
| Fail OPEN — a route whose validity cannot be determined mechanically must dispatch with a warning | **Satisfied structurally rather than by a flag.** Rejecting candidate (2) means no mechanical refusal path is built at all, so there is no false-refusal surface to fail open from; the composer continues to emit unconditionally and an absent `obligation` renders exactly as today |

Nothing in the description required correction. The incident narratives and measured costs remain
CARRIED-UNVERIFIED from the originating repository's issue log, as the description itself states —
they are not re-measurable here and no phase below depends on re-measuring them.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; `specs/ROADMAP.md` was not consulted and is not
modified by any phase.

## Goals & Non-Goals

**Goals**:
- Add an optional `obligation` field to `.decisions.json` entries via the single sanctioned
  writer, backward compatible and additive, following the `description_fingerprint` precedent.
- Document the field in the one authoritative schema section and in the writer's usage inventory
  entry.
- Amend `user-decision-contract.md` so an option offered as a ROUTE names the obligation it
  discharges, and so the mirror polarity (an option set presented as open when its alternatives
  are already structurally excluded by the task's own artifacts) is a proposal-time self-check.
- Render the named obligation inline in the existing `## Prior Decisions` section with a
  verify-before-you-start / raise-a-NEW-question instruction.
- Wire Move 4 to pass the relayed obligation to the writer.
- Pin, by test: legacy four-field round-trip, new-field round-trip, object-wrapper refusal with a
  byte-identical pre-existing file, unchanged heading and `POTENTIALLY SUPERSEDED` wording,
  byte-identical-when-absent rendering, and both regression polarities.

**Non-Goals**:
- Building any mechanical validator that adjudicates whether a route discharges an obligation
  (candidate 2 — rejected above, with the insertion seam recorded for a future task).
- Changing the `## Prior Decisions` heading string, the `POTENTIALLY SUPERSEDED` marker semantics,
  the four required fields, or the root-level array-type validation.
- Adding or moving any `## ` section in the dispatch file (which would collide with the adjacent
  task deciding that file's emitted section order — see Risks).
- Changing `orchestrate-cycle-postflight.sh` (measured unnecessary — see Research Integration).
- Re-measuring the originating incidents, which happened in another repository.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new section in the dispatch file collides with the adjacent task deciding that file's emitted section order | M | L | Phase 3 renders **inside** the existing `## Prior Decisions` section and adds no new heading, so no ordering decision is pre-empted. Phase 3's task list states this explicitly as a constraint to check before editing |
| The schema change is read as mandatory somewhere and breaks a legacy four-field entry | H | L | The field is optional and additive, built with the existing two-branch `jq -c -n` pattern (never an unconditional `+` merge); Phase 1's tests pin a legacy entry still validating and still appending |
| The composer's rendering change alters output for an entry with no obligation | M | M | Byte-identical-when-absent is an explicit task-list item and a pinned test case, reusing Group 10 Case A/B's existing byte-identical diff assertion technique |
| The added instruction is read as license to re-litigate a settled question | H | L | The instruction wording surfaces a NEW question naming the second obstruction and explicitly forbids re-asking the original; the existing "treat these as settled — do not re-ask" preamble is preserved verbatim and pinned |
| The contract amendment's fail-open tension: "raise a NEW blocking question" looks blocking-by-default | M | L | Fail-open governs *mechanical* validation, which this plan does not build. An informed agent adjudication that the route does not hold is the intended working case, not a false refusal. Phase 2 states this distinction in the landed prose |
| Running the full `verify-deploy.sh` aggregator collides with another active session | M | M | Every phase uses scoped narrowing (`run-all.sh --only SUITE`, `verify-deploy.sh --only-gate N`), per the task description's explicit instruction. The final phase's full gate set runs only once, at the end |
| A serialization-only territory edge (shared composer or shared test file) causes a conflicting concurrent edit | M | M | Edges are already declared as task dependencies; the implementer re-derives line numbers before editing (the description's own provenance instruction) rather than trusting any line number quoted in this plan |
| Task-number or record-versioning language leaks into a file under `agent-system/**` | M | M | Every phase's landed prose cites mechanisms by name, never by task number, and states the current design without narrating its own history; the final phase's gate 4 run is the mechanical backstop |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Make the Obligation Recordable — Writer, Schema, Inventory, Writer Tests [COMPLETED]

**Goal**: An optional `obligation` field exists on `.decisions.json` entries, written only by the
single sanctioned writer, documented in the one authoritative schema section and in the writer's
inventory entry, with every backward-compatibility property pinned by test.

**Tasks**:
- [x] Re-derive current line numbers in `scripts/orchestrate-record-decision.sh` before editing
      (the description's provenance instruction); the anchors to locate are the argument-parse
      `case` block, the required-argument error message, the `description_fingerprint` computation,
      and the two-branch `jq -c -n` record build. *(completed)*
- [x] Add an `--obligation "..."` argument to the parse `case` block. It is **optional**: it must
      NOT be added to the required-argument check, and its absence must not change any exit path. *(completed)*
- [x] Extend the record build so the field is present only when the argument was supplied. The
      existing shape is a two-branch `if`/`else` over `description_fingerprint`; with a second
      optional field this becomes four combinations — implement it as a base object plus
      conditional `+ {obligation: $obligation}` / `+ {description_fingerprint: $fp}` merges applied
      **only inside the branch where that value is non-empty**, never unconditionally. An empty or
      omitted `--obligation` must produce an entry with no `obligation` key at all (never an empty
      string), matching `description_fingerprint`'s documented omission rule. *(completed: implemented as a base object plus two independent conditional `+ {...}` merges, generalizing the two-branch pattern to four combinations)*
- [x] Verify by read that the write mechanics are untouched: `flock -x` still held across the whole
      read -> merge -> validate -> atomic-`mv` sequence, the append is still additive-only, the
      root-level array-type validation still runs both before and after merge, and an
      object-wrapped pre-existing file is still refused rather than coerced. *(completed: confirmed by diff read-through, no change inside the flock-guarded region)*
- [x] Update the script's own header usage block and `--help` text to list `--obligation` as
      optional, stating what it means (the specific obligation the recorded route is claimed to
      discharge) and that it is omitted entirely when not supplied. *(completed)*
- [x] Update `docs/architecture/handoff-schema.md`'s `## Decisions File Schema (.decisions.json)`
      section: add `obligation` to the field list in the same prose shape
      `description_fingerprint` already uses there (type, optional, writer, omission rule,
      consumer). Name the consumer as the dispatch composer's `## Prior Decisions` rendering.
      Leave the four required fields and the example block's required entries unchanged (the
      example may gain the optional field as a second illustrative entry). *(completed: added a second illustrative entry to the example block)*
- [x] Update `docs/reference/utility-scripts-inventory.md`'s entry for the writer so its quoted
      usage line includes the optional `--obligation` flag; keep the rest of that entry's prose
      intact. *(completed)*
- [x] Extend `scripts/tests/test-orchestrate-record-decision.sh`, modeling each new case on the
      suite's existing `description_fingerprint` fixtures: (a) a four-field legacy entry still
      validates and still appends; (b) an entry written with `--obligation` round-trips with the
      field present and its text intact; (c) an entry written **without** `--obligation` has no
      `obligation` key (asserted by `jq 'has("obligation")'`, not by string absence); (d) an
      object-wrapped pre-existing file is still refused and left byte-identical, with
      `--obligation` supplied; (e) the no-`sha256sum` stub path still works with `--obligation`
      supplied, proving the two optional fields are independent. *(completed: cases c3-c7 added, all 16 cases in the suite pass)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: four files, no new file created; the writer's diff is expected to be confined
to the argument parser, the record-build expression, and the header/usage text, with the
`flock`/validate/atomic-`mv` sequence untouched. Confirm by reading the actual diff before
committing: if the record-build change turns out to require restructuring the lock or validation
block, the hypothesis is wrong and the deviation is recorded in place.

**Tier Justification**: measured over this phase's own path set, `suite_selection_select` returns the `__FULL_SWEEP__` sentinel — one touched path is a source-store architecture document with no mapped suite — so no suite subset covers the phase, and the honest covering check is the gate subset `bash <repo_root>/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>` per the source-store markdown sub-case, together with the diff read-through and the per-path mapped suites named in Verification below.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-record-decision.sh` - optional `--obligation` argument, conditional record-build merge, header/usage text
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - document `obligation` in the Decisions File Schema section (exists; if the section heading has moved, locate it by its `## Decisions File Schema` text rather than by line number, and record the deviation)
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - add the optional flag to the writer's quoted usage line (exists)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh` - five new cases per the task list (exists)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-record-decision.sh,test-issue-record.sh,test-lean-mcp-preflight-check.sh` exits 0, with the five new cases reported PASS by name.
- `bash <repo_root>/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>` exits 0 (doc-lint and task-reference lint over the two markdown edits).
- Read the writer's diff and confirm no change inside the `flock`-guarded region other than the record-build expression.

---

### Phase 2: Require the Claim at Proposal Time — Contract Amendment [COMPLETED]

**Goal**: `user-decision-contract.md` requires an option offered as a ROUTE to name the obligation
it discharges, and requires the proposing agent to confirm each listed option is not already
structurally excluded by the task's own artifacts — the mirror polarity.

**Tasks**:
- [x] In `context/standards/user-decision-contract.md`'s `## Field Shape` section, add
      `obligation` to the JSON example and to the field table as an optional string: **required
      when the decision is a ROUTE decision** (the question is "which way do we go to get past
      this obstruction"), omitted for a pure-preference decision (the question is "which of these
      equally-workable things do you want"). State what the value must contain: the specific
      obligation the route is claimed to discharge, named concretely enough that the receiving
      agent can check it against the phase's own artifacts. *(completed)*
- [x] In the same section, state the downstream path in one or two sentences so the field is not
      an orphan: postflight relays the whole `user_decision` object verbatim, the loop's batched
      relay passes the value to the decision writer's `--obligation` argument, and the dispatch
      composer renders it to the next dispatch. Cite the mechanisms by name, not by task number. *(completed)*
- [x] Extend `## When NOT to Raise One` with the mirror-polarity self-check: an option belongs in
      `options` only when its alternatives are not already structurally excluded by facts already
      present in the task's own artifacts (a prior report's or plan's findings). An option set
      asserted to have several live members when it has one is the same defect as a route asserted
      to discharge an obligation it does not — both reach a dispatch carrying authority and no
      checkability. Give the worked shape (an alternative route foreclosed by a dependency
      direction already recorded in the task's own findings) **without** naming any task number. *(completed: worked shape is an import-cycle-foreclosed alternative proof route)*
- [x] Add one short paragraph distinguishing this from a license to re-litigate: this is a
      proposal-time self-check performed by the agent about to raise a question, never an
      instruction to re-ask an already-recorded answer; and an informed adjudication that a route
      does not hold is the intended working case, not a mechanical refusal, so the fail-open
      posture that governs mechanical validation does not apply to it. *(completed)*
- [x] Update `context/formats/return-metadata-file.md`'s `### user_decision (optional)` subsection
      so its one-line shape summary includes the new optional key. That subsection explicitly does
      not restate the contract, so add the key to the shape line and nothing more; the pointer to
      `user-decision-contract.md` already carries the rest. *(completed)*
- [x] Re-read both landed files for task-number references and record-versioning language
      ("previously", "no longer", "supersedes", a version label) and remove any. *(completed:
      one "previously-recorded" occurrence found and reworded to "recorded in an earlier cycle")*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: two files, prose-and-example only, no executable surface touched; the
expected diff is one example-block line plus one table row plus three short prose paragraphs in the
contract, and a single shape-line edit in the return-metadata format. Confirm against the actual
diff: if the `user_decision` field table turns out to be duplicated in a third file, that file is
added and the deviation recorded.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-lint-agent-contracts.sh,test-validate-return-meta.sh` is `suite_selection_select`'s verbatim output over both touched paths, so a real suite subset covers this edit and no sentinel claim is needed.

**Files to modify**:
- `agent-system/extensions/core/context/standards/user-decision-contract.md` - optional `obligation` in Field Shape, mirror-polarity self-check in When NOT to Raise One, re-litigation/fail-open distinction (exists)
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - add the key to the `user_decision` shape line only (exists)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-lint-agent-contracts.sh,test-validate-return-meta.sh` exits 0.
- `bash <repo_root>/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>` exits 0.
- `grep -nE 'task [0-9]+|tasks [0-9]+|#[0-9]{3}' ` over both landed files returns nothing.

---

### Phase 3: Propagate the Claim — Composer Emission and Architecture Note [COMPLETED]

**Goal**: The dispatch file's existing `## Prior Decisions` section renders each entry's named
obligation inline, with an explicit instruction to verify discharge before beginning phase work
and to raise a NEW blocking question if it does not hold — adding no new section and changing no
existing heading or marker wording.

**Tasks**:
- [x] Re-derive current line numbers before editing; the anchors are the `prior_decisions_block`
      assignment (three jq branches: with-fingerprint, without-fingerprint) and the
      `## Prior Decisions` emission block inside the dispatch-file writer. *(completed)*
- [x] **Check first, then edit**: confirm the change adds no new `## ` heading and moves no
      existing section. The adjacent task deciding this file's emitted section order must land
      first only if a section is added or moved; rendering inside an existing section pre-empts
      nothing. Record the confirmation in the phase's commit message. *(completed: confirmed no
      new heading added, no section moved — change lands entirely inside the existing
      `## Prior Decisions` section)*
- [x] Extend **every** `prior_decisions_block` jq branch (both the fingerprint-aware and the
      fingerprint-unavailable branch) to append an `Obligation: ...` line per entry when the field
      is present, using the same `(if ... then ... else "" end)` conditional shape the
      `POTENTIALLY SUPERSEDED` marker already uses. An entry with no `obligation` key must render
      exactly as today. *(completed; verified by hand-built fixture — see Verification)*
- [x] Leave the `POTENTIALLY SUPERSEDED` conditional and its wording byte-identical; do not
      reorder it relative to the new line in a way that changes an existing entry's render. *(completed: Obligation line placed before the POTENTIALLY SUPERSEDED conditional, neither changed)*
- [x] In the section's emission block, add the receiving-agent instruction — emitted only when at
      least one rendered entry carried an obligation, so a dispatch whose decisions all predate the
      field is byte-identical to today. The instruction must: direct the agent to verify the route
      discharges the named obligation before beginning phase work; direct it, if the route does
      not discharge it, to return a NEW, specific blocking `user_decision` naming the second
      obstruction; and forbid re-asking the original question. *(completed)*
- [x] Preserve the existing preamble wording verbatim in both of its forms (the plain
      "treat these as settled — do not re-ask a question already answered here" and the
      superseded-variant text). The new instruction is additive text, not a rewrite of either. *(completed: all 201 pre-existing test-orchestrate-build-dispatch.sh cases still pass)*
- [x] Update the script's own header comment block where it describes the Prior Decisions read path
      and supersession marking, so the header states that the optional obligation is rendered and
      that the composer emits it without adjudicating it. *(completed)*
- [x] Add a short subsection to `docs/architecture/orchestrate-state-machine.md` recording the
      propagation and the emit/adjudicate split: the writer records the claim, the composer emits
      it, the receiving agent adjudicates it, and a failed adjudication surfaces a new question
      rather than a re-ask. Do **not** edit the existing
      "Prior Decisions vs. Current Description: Precedence" section, which governs a different
      question (staleness, not validity). *(completed: added as a new "## Recording, Emitting,
      and Adjudicating a Route's Obligation" subsection; precedence section left untouched)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: two files; the composer's diff is expected to touch only the
`prior_decisions_block` jq branches, the Prior Decisions emission block, and the header comment —
no other block of that 900-line script. Confirm against the actual diff; if the conditional
instruction requires a new shell variable computed earlier in the script, that is an expected
widening within the same file, recorded in place rather than treated as out of scope.

**Tier Justification**: the change alters the emitted dispatch-file text that consumers across
several suites assert against, and `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-force-phases.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-record-decision.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-unwind-dispatch.sh,test-routing-resolution.sh,test-handoff-reader-parity.sh,test-lint-postflight-boundary.sh,test-resume-scan-nonconformance.sh,test-session-runtime-files.sh,test-stall-reprompt-wiring.sh` is `suite_selection_select`'s verbatim union over both touched paths — the enumerated one-hop dependent set this tier covers.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - render the obligation in every `prior_decisions_block` branch, add the conditional receiving-agent instruction, update the header comment (exists)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - new subsection recording the record/emit/adjudicate split; the existing precedence section is left untouched (exists; if its heading text has changed, locate the file's decision-related section by text and record the deviation)

**Verification**:
- The `--only` suite set named in the Tier Justification above exits 0.
- A hand-built fixture with a decisions file containing one obligation-bearing entry and one
  four-field entry produces a dispatch file in which the first renders an `Obligation:` line and
  the instruction appears once, and the second renders unchanged.
- A fixture whose decisions file contains only four-field entries produces a dispatch file
  byte-identical (`diff -q`) to one built before this phase's change.
- `grep -c 'Prior Decisions' ` on a rendered fixture confirms the heading string is unchanged, and
  the superseded-variant preamble text still appears verbatim for a mismatching-fingerprint entry.

---

### Phase 4: Pin Both Polarities — Composer Tests and Regression Fixtures [COMPLETED]

**Goal**: `test-orchestrate-build-dispatch.sh` pins the new rendering, pins that the existing
heading and marker wording are unchanged, and pins both regression polarities named in the task
description.

**Tasks**:
- [x] Extend the suite's existing `.decisions.json` fixture group (the absent / present-and-empty /
      present-with-entries group, and the fingerprint group after it) rather than creating a
      parallel group, reusing its `assert_contains` / `assert_not_contains` /
      byte-identical-`diff -q` helpers and its case-naming style. *(completed: added as "Group 10b"
      immediately after Group 10's own restore point, inside Group 10's own file region)*
- [x] Case: an entry **with** `obligation` renders an `Obligation:` line carrying the field's text
      verbatim, and the receiving-agent instruction appears exactly once in the dispatch file. *(completed)*
- [x] Case: a decisions file whose entries all lack `obligation` produces output byte-identical to
      the pre-change dispatch (same technique Case B already uses against the absent-file
      dispatch), and the receiving-agent instruction is absent. *(completed)*
- [x] Case: `## Prior Decisions` is still emitted with its exact heading string, the plain
      preamble ("treat these as settled — do not re-ask a question already answered here") is still
      emitted verbatim for a non-superseded set, and the `POTENTIALLY SUPERSEDED` variant is still
      emitted verbatim for a mismatching-fingerprint entry — asserted alongside an obligation-
      bearing entry, so the two features are proven not to interfere. *(completed: "coexistence" case)*
- [x] **Regression fixture, polarity one** (the cited incident shape): a decisions file carrying a
      recorded answer whose route does not discharge its stated obligation, in a task directory
      that already holds a plan whose own findings state the contrary dependency. Pin what the
      chosen mechanism actually surfaces: the dispatch file carries the named obligation and the
      verify-before-you-start instruction, so the receiving agent is handed both the claim and the
      duty to check it. Assert the obligation text, the instruction text, and the
      new-question-not-a-re-ask wording are all present. Add a header comment on this case stating
      plainly what it does and does not prove — it protects the propagation, not an adjudication
      the composer deliberately does not perform. *(completed)*
- [x] **Regression fixture, polarity two** (the mirror shape): a structural assertion over
      `context/standards/user-decision-contract.md` that the proposal-time structural-exclusion
      self-check is present — an option is listed only when its alternatives are not already
      excluded by facts in the task's own artifacts. This polarity never reaches
      `.decisions.json` (it is caught before any question is raised), so a schema-side fixture
      cannot express it; the contract prose is the only durable carrier, and this suite already
      covers that file per the suite-selection mapping. State that reasoning in the case's header
      comment. *(completed)*
- [x] Run the suite and confirm every pre-existing case still passes, not only the new ones. *(completed: 218 passed (201 pre-existing + 17 new), 0 failed)*

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: one file, test-only; six new cases expected, no change to any existing case's
assertions. Confirm against the actual diff: if pinning the byte-identical-when-absent property
requires adjusting a shared fixture used by an earlier group, that adjustment is recorded in place
and the earlier group's cases are re-run to prove they still pass.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-aux-dispatch.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh` is `suite_selection_select`'s verbatim output for the single touched test file.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - six new cases inside the existing decisions fixture groups (exists)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-aux-dispatch.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh` exits 0.
- The suite's own pass counter shows every pre-existing case still PASS, with the six new cases
  reported by name.

---

### Phase 5: Wire the Caller, Redeploy, and Run the Full Gate Set [NOT STARTED]

**Goal**: The loop's batched relay passes the agent-supplied obligation to the writer, the source
store is redeployed, and the complete gate set is green.

**Tasks**:
- [ ] In `skills/skill-orchestrate/SKILL.md`'s Move 4 batched relay paragraph, extend the
      record-decision instruction so the obligation from the relayed `user_decision` object is
      passed to the writer's `--obligation` argument when present, and omitted when absent. Keep
      the paragraph's existing instructions intact: one batched `AskUserQuestion` call per
      invocation, never mid-cycle, never hand-authored JSON.
- [ ] Add one sentence recording that the relay needs no postflight change because postflight
      copies the `user_decision` object verbatim — so the key arrives without any script in
      between needing to know about it.
- [ ] Re-read the landed paragraph for task-number references and record-versioning language.
- [ ] Redeploy the source store: `bash agent-system/extensions/core/scripts/deploy-headless.sh`
      (resolve the correct invocation from the script's own usage before running it). This
      regenerates the entire deployed `.claude/` tree, which is why this phase declares the
      whole-tree sentinel below.
- [ ] Confirm the deployed copies of all nine touched files match their source-store originals
      (`diff` each pair), so the deploy actually propagated this task's work rather than a stale
      tree.
- [ ] Run the complete gate set and confirm green.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: one real file edited plus a whole-tree regeneration; the regeneration is
expected to change only deployed-tree copies, never a source-store file. Confirm by running
`git status --short` after the deploy and checking that no `agent-system/**` path appears as
modified beyond this task's own edits — if one does, the deploy wrote back into the source store
and the deviation is recorded and investigated before committing.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Move 4 relay passes `--obligation`; note that postflight needs no change (exists)
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via the deploy script, which is an implicit scope claim over the entire deployed tree

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set the aggregator runs, exit 0.
  Per the task description, do not run the aggregator while another session is active: if one is,
  wait or run it under the scoped narrowing first and the full set once the host is clear, and
  record which was done.
- The deploy's own output reports success, and each of the nine touched files diffs clean between
  its source-store path and its deployed `.claude/**` counterpart.
- `git status --short` shows no unexpected `agent-system/**` modification introduced by the deploy.

---

## Testing & Validation

- [ ] A four-field legacy `.decisions.json` entry still validates and still appends (writer suite).
- [ ] An entry carrying `obligation` round-trips with the field and its text intact (writer suite).
- [ ] An entry written without `--obligation` has no `obligation` key at all, asserted by
      `jq 'has("obligation")'` rather than by string absence (writer suite).
- [ ] An object-wrapped pre-existing decisions file is still refused and left byte-identical, with
      `--obligation` supplied (writer suite).
- [ ] The `flock` / additive-append / validate-both-sides / atomic-`mv` sequence is unchanged,
      confirmed by diff read and by the suite's existing mechanics cases still passing.
- [ ] `## Prior Decisions` is still emitted with its exact heading string, and both preamble forms
      (plain and `POTENTIALLY SUPERSEDED` variant) are still emitted verbatim (composer suite).
- [ ] An obligation-bearing entry renders an `Obligation:` line and the receiving-agent
      instruction appears exactly once (composer suite).
- [ ] A decisions file with no obligation-bearing entry renders byte-identically to pre-change
      output, with no instruction emitted (composer suite).
- [ ] Regression polarity one: a route that does not discharge its stated obligation, with the
      contrary dependency already in the plan's own findings, reaches the dispatch file carrying
      both the obligation and the duty to check it (composer suite).
- [ ] Regression polarity two: the contract states the proposal-time structural-exclusion
      self-check for an option set presented as open (composer suite, structural assertion).
- [ ] No file landing under `agent-system/**` contains a task-number reference or
      record-versioning language (gate 4 plus a manual grep per phase).
- [ ] The complete `verify-deploy.sh` gate set is green after the redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-record-decision.sh` — optional `--obligation`
  argument and conditional record build.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — obligation rendered
  inside the existing `## Prior Decisions` section plus the conditional receiving-agent
  instruction.
- `agent-system/extensions/core/context/standards/user-decision-contract.md` — route-obligation
  requirement and the mirror-polarity proposal-time self-check.
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — `user_decision` shape
  line updated.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — `obligation` documented in
  the Decisions File Schema section.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — new subsection
  recording the record/emit/adjudicate split.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — writer usage line
  updated.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Move 4 relay wiring.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh` — five new
  cases.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — six new cases
  including both regression polarities.
- A regenerated deployed `.claude/` tree.

## Rollback/Contingency

Every phase is a small, independently revertible source-store edit, and each lands its own
commit per the per-substep commit mode, so the ordinary contingency is `git revert` of the
offending phase's commit followed by a redeploy — no working-tree discard is needed.

If a phase must be abandoned mid-edit with uncommitted changes present, take a durable
non-reverting checkpoint first (`bash .claude/scripts/git-snapshot.sh 450 --no-revert`) so nothing
is lost, then decide. Only a genuine rollback — discarding uncommitted work to return to a known
state — uses the reverting form, and then per `context/contracts/recovery.md`'s rollback rung for
the exact invocation shape, including its out-of-scope override flag.

Deploy-specific contingency: the deployed `.claude/` tree is a disposable artifact regenerated
from the source store, so a bad deploy is repaired by fixing the source store and redeploying,
never by hand-editing the deployed tree. The schema change is additive and optional throughout,
so a partially landed state (writer changed, composer not yet) leaves every existing entry valid
and every existing dispatch render unchanged — there is no intermediate state that breaks a
running orchestration.
