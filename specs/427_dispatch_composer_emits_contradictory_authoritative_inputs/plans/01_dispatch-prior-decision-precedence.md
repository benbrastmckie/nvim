# Implementation Plan: Stop the Dispatch Composer Emitting a Superseded Prior Decision as Settled

- **Task**: 427 - Stop the dispatch composer emitting a superseded Prior Decision as settled
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/427_dispatch_composer_emits_contradictory_authoritative_inputs/reports/01_dispatch-prior-decision-precedence.md
- **Artifacts**: plans/01_dispatch-prior-decision-precedence.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`orchestrate-build-dispatch.sh` renders every `.decisions.json` entry under a hardcoded,
unconditional authority claim ("Treat these as settled — do not re-ask a question already
answered here") with no cross-reference to the `## Description` block emitted a few hundred lines
earlier in the same file. When an operator amends a task's description after an answer was
recorded, the composer actively instructs the dispatched agent to treat the superseded clause as
settled. This plan adds an optional `description_fingerprint` field to *newly written*
`.decisions.json` entries, has the composer recompute the same digest over the current
description at render time, marks a mismatching entry `POTENTIALLY SUPERSEDED` inline, softens the
blanket authority prose only when at least one entry actually mismatches, and states the
precedence rule once in `docs/architecture/orchestrate-state-machine.md`. Definition of done: the
four VERIFY fixtures in the task description pass, the no-conflict and no-`.decisions.json` cases
render byte-identically to today, and no existing `.decisions.json` record is mutated.

### Research Integration

The research report settles the mechanism choice and this plan implements it without
re-litigating it. Key findings carried forward and re-verified at plan-authoring time:

- **`state.json`'s `last_updated` is too noisy to be the staleness signal** — bumped per cycle by
  `dispatch_seq_counter`, `cycle_count`, `pending_dispatch`, and `infra_failures` writes that
  never touch the description. Rejected as the detector.
- **The inline `== ... (operator decision, DATE) ==` marker convention is unschemed** — one
  observed occurrence, no scripted writer, hand-authored. Rejected as the detector.
- **A sha256 content fingerprint is the chosen detector**, reusing the `command -v sha256sum ||
  degrade` idiom already present in `scripts/lib/deploy-ledger-lib.sh` and
  `orchestrate-cycle-plan.sh`'s identical-dispatch convergence guard.
- **Re-verified in the code at plan-authoring time** (so these are not carried-unverified
  figures): the composer's prior-decisions read block builds `prior_decisions_block` from a single
  `jq -r '.[] | "- Question: ..."'` expression and its render block emits the three-line
  unconditional intro; `orchestrate-record-decision.sh` builds its entry in one `jq -c -n` call
  with exactly `{question, answer, cycle, timestamp}`; `handoff-schema.md`'s "Decisions File
  Schema (`.decisions.json`)" section documents those four fields as "at minimum";
  `docs/architecture/orchestrate-state-machine.md` contains **zero** occurrences of
  `decisions.json` or `Prior Decision` today, so the precedence section in Phase 3 is genuinely
  new text, not an edit to existing prose.
- **Suite coverage re-resolved at plan-authoring time** via `suite_selection_select`, so the
  per-phase Tier Justification commands below name real covering suites rather than guesses.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Add `description_fingerprint` (sha256 hex of the task's description text at answer time) as a
  documented-optional fifth field written by `orchestrate-record-decision.sh` from this point
  forward.
- Have `orchestrate-build-dispatch.sh` recompute the digest over the current description and mark
  each mismatching Prior Decision `POTENTIALLY SUPERSEDED` inline.
- Replace the unconditional "Treat these as settled" prose with a conditional form that fires
  only when at least one entry in that render actually mismatches.
- State the precedence rule once, for both the composer and a human reader, in
  `docs/architecture/orchestrate-state-machine.md`.
- Pin all four VERIFY cases from the task description mechanically.

**Non-Goals**:
- Mutating, backfilling, or rewriting any existing `.decisions.json` record. Explicitly forbidden
  by the task's CONSTRAINT.
- Suppressing a superseded entry. Its question, answer, cycle, and timestamp stay fully visible;
  only an explanatory marker and a conditional qualifier are added.
- Retroactively fixing the live reproducer. `specs/328_.../.decisions.json`'s entries carry no
  `description_fingerprint`, so that exact file will still render as settled after this change.
  That is the documented, accepted limitation of the no-mutation constraint — not an oversight,
  and Phase 3's doc text must say so plainly.
- Introducing a separate `## Conflicting Inputs` callout section. Considered and rejected in the
  research report: heavier for no added legibility over marking the specific entry in the section
  that already exists for exactly this content.
- Adding a shared fingerprint helper to `scripts/lib/common.sh`. See Decisions below.

## Decisions Recorded in This Plan

1. **The digest shape is fixed and duplicated, not extracted into `lib/common.sh`.** Both scripts
   compute `printf '%s' "$description" | sha256sum | awk '{print $1}'` — `printf '%s'`, never
   `echo` (which appends a newline and would make the two sides disagree). A shared helper in
   `lib/common.sh` would be the more DRY design, but `common.sh` is sourced by essentially every
   script in the store, making its blast radius a full sweep for a two-line helper, during a cycle
   with three concurrent sibling tasks on this same tree. Instead, the shape is pinned
   **mechanically from both sides**: Phase 1's recorder test computes the expected digest
   independently and asserts equality with the written field, and Phase 2's matching-fingerprint
   fixture computes the fixture's fingerprint with the identical shape — so a drift on either side
   (e.g. one switching to `echo`) fails a test rather than silently disabling detection.
2. **`jq` comparisons use the `| not` form, never `!=`.** Per `.claude/CLAUDE.md`'s "jq Command
   Safety" section (Claude Code Issue #1132), `!=` is escaped as `\!=` and produces a parse error.
   Write `((.description_fingerprint == $cur_fp) | not)`, not `(.description_fingerprint != $cur_fp)`.
   This applies to every comparison added in Phases 1 and 2.
3. **An entry lacking the field is never marked.** Absence means "cannot be verified", not
   "superseded". Every pre-existing record, and any record written while `sha256sum` was
   unavailable, renders exactly as it does today.
4. **The conditional prose fires per-render, not per-entry-presence.** A render in which every
   entry's fingerprint matches (or in which no entry carries the field) emits today's exact
   three-line unconditional intro, byte for byte.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Digest shape drifts between writer and reader, silently disabling detection | H | M | Decision 1 above: pinned from both sides by tests; `printf '%s'` named explicitly in both phases |
| `jq` `!=` escaping bug (Issue #1132) breaks the new comparison at runtime | H | M | Decision 2: `| not` form mandated; Phase 2 verification runs the composer for real, which would surface a parse error immediately |
| Byte-identity regression in the no-conflict path (the composer's standing no-change-when-nothing-applies precedent) | H | M | VERIFY item 1 is a `diff -q` fixture against a stored pre-change dispatch, modelled on Group 10 Case A/B's existing byte-identity assertions |
| `sha256sum` absent on an execution host | M | L | Omit the field at write time (never an empty placeholder); skip comparison and fall back to today's unconditional rendering at read time; never a hard failure in either script |
| An inconsequential description edit (typo fix) flips the fingerprint and marks an unrelated decision | L | H | Accepted tradeoff, per the task's NON-GOAL: over-surfacing is the safer failure mode than under-surfacing. Doc text in Phase 3 states this explicitly |
| The description could change between the `AskUserQuestion` answer and the recorder's write, so the fingerprint approximates "description at answer time" | L | L | Accepted approximation; both happen inside the same loop branch move. Noted in the Phase 3 doc text rather than engineered around |
| Composer output change perturbs `cycle_plan_dispatch_hash()` stability (test Group 18) | M | L | The new content is derived only from `.decisions.json` + the description, never from mtime/date/stat; Group 18 is in Phase 2's `--only` suite list |
| A concurrent sibling task edits a file in this task's scope | M | L | No overlap: siblings 425/400/422 declare `orchestrate-cycle-postflight.sh`, `validate-state.sh`, `state-write.sh`, `push-grant-lib.sh`, and their tests — disjoint from this task's six files. Re-read each file immediately before editing; stage explicit file lists only |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is fully sequential: Phase 2's
fixtures depend on the digest shape Phase 1 pins, Phase 3's doc text describes the behavior Phase
2 makes live, and Phase 4 gates all of it.

---

### Phase 1: Writer — record `description_fingerprint` on new entries [COMPLETED]

**Goal**: `orchestrate-record-decision.sh` writes an optional fifth field carrying the sha256
digest of the task's description as of answer time, documented in the schema and pinned by tests,
with a graceful degrade when `sha256sum` is unavailable.

**Tasks**:
- [x] In `orchestrate-record-decision.sh`, after `task_entry` is resolved and validated, extract
      `description="$(echo "$task_entry" | jq -r '.description // empty')"` — mirroring
      `skill-base.sh`'s own extraction of the same field. *(completed)*
- [x] Compute `description_fingerprint` as `printf '%s' "$description" | sha256sum | awk '{print $1}'`,
      guarded by `command -v sha256sum >/dev/null 2>&1`. When `sha256sum` is absent, leave the
      variable empty. *(completed)*
- [x] Extend the existing single `jq -c -n` entry construction to add the field **only when the
      digest is non-empty** — two `jq -c -n` branches, or one invocation plus a conditional
      `+ {description_fingerprint: $fp}`. The field must be **omitted entirely**, never emitted as
      an empty string. Do not restructure the surrounding `flock`/merge/validate/`mv` sequence.
      *(completed: implemented as two jq -c -n branches)*
- [x] In `docs/architecture/handoff-schema.md`'s "Decisions File Schema (`.decisions.json`)"
      section, add `description_fingerprint` to the field list as
      `(string, optional, sha256 hex)`, following the existing documented-optional
      "absence means X" convention: absence means the entry predates this field or was written on
      a host without `sha256sum`, and such an entry can never be marked superseded. State the
      exact digest shape (`printf '%s' "<description>" | sha256sum`) here as the one authoritative
      definition, and note the composer as the field's consumer. *(completed)*
- [x] In `test-orchestrate-record-decision.sh`, add a case asserting the written entry's
      `description_fingerprint` equals a digest the test computes independently from the scratch
      `state.json` description with the identical `printf '%s' | sha256sum` shape.
      *(completed: case (c1))*
- [x] In the same suite, add a case asserting the field is **absent** (`has(...)` false, not
      `== ""`) when `sha256sum` is masked from `PATH` for the invocation, and that the append
      still exits 0. *(completed: case (c2); required a `type -P`-based stub PATH builder rather
      than `command -v`, since this shell environment exports a `grep` shell function that
      `command -v` resolves to a bare non-path name)*
- [x] Confirm existing case (c)'s shape-conformance assertion still passes — it asserts the four
      legacy fields via `has(...)`, not an exact key set, so an additive field must not break it.
      *(completed: confirmed passing)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase assumes `orchestrate-record-decision.sh` builds its entry in
exactly one `jq -c -n` invocation with exactly four fields, and that
`test-orchestrate-record-decision.sh`'s case (c) asserts field presence via `has(...)` rather than
an exact key-set match — both re-derived from the files at plan-authoring time rather than carried
from the research report. Confirm by reading the `jq -c -n` block and case (c) immediately before
editing; if either differs, adapt the edit rather than the assertion.

**Tier Justification**: the new field crosses from this writer into
`orchestrate-build-dispatch.sh`'s read path, so the covering check is the writer's mapped suites
plus its one direct dependent —
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-record-decision.sh,test-issue-record.sh,test-orchestrate-build-dispatch.sh`
— together with `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim/agent-system/extensions/core`
for the `handoff-schema.md` edit, which `suite_selection_select` maps to `__FULL_SWEEP__`
(source-store markdown, sub-case (b): explicit `TARGET` required, never the bare no-argument
form).

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-record-decision.sh` - extract description, compute optional digest, add field conditionally to the `jq -c -n` entry
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - document the optional fifth field and the authoritative digest shape in the "Decisions File Schema" section
- `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh` - add the digest-equality case and the `sha256sum`-unavailable omission case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-record-decision.sh,test-issue-record.sh,test-orchestrate-build-dispatch.sh`
  exits 0, with the two new cases reported as PASS by name (not merely an absence of failures).
- `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim/agent-system/extensions/core`
  exits 0 — exit status checked, not just a stdout diff.
- `jq -e '.[0] | has("description_fingerprint") and (.description_fingerprint | test("^[0-9a-f]{64}$"))'`
  holds for an entry written by a manual scratch invocation.

---

### Phase 2: Reader — detect the mismatch and render it [NOT STARTED]

**Goal**: `orchestrate-build-dispatch.sh` recomputes the digest over the current description,
marks each mismatching Prior Decision `POTENTIALLY SUPERSEDED` inline, switches the section intro
to a conditional form only when at least one entry mismatched, and is pinned by all four VERIFY
fixtures.

**Tasks**:
- [ ] In the prior-decisions read block, after `decisions_count` is known to be `> 0`, compute
      `cur_fp` over `$description` with the identical `printf '%s' "$description" | sha256sum | awk '{print $1}'`
      shape from Phase 1, guarded by `command -v sha256sum`. Empty `cur_fp` means "cannot compare"
      and must take the unchanged path.
- [ ] Compute a single boolean `any_superseded` with one `jq` call using the `| not` form, e.g.
      `jq -r --arg cur_fp "$cur_fp" 'any(.[]; (((.description_fingerprint // "") == "") | not) and ((.description_fingerprint == $cur_fp) | not))'`.
      Treat a `jq` failure or an empty `cur_fp` as `false`.
- [ ] Extend the existing single render expression with `--arg cur_fp` so a mismatching entry gains
      exactly one additional indented line, appended after its `Answered in cycle ... at ...` line:
      `  POTENTIALLY SUPERSEDED — the task description has changed since this answer was recorded; the current \`## Description\` above governs on conflict.`
      An entry with no field, or with a matching field, gains nothing.
- [ ] In the render block, branch the intro prose on `any_superseded`. **False** emits today's
      exact three lines, unchanged and byte for byte. **True** emits the conditional form: keep
      the first sentence naming `.decisions.json`, replace "Treat these as settled — do not
      re-ask a question already answered here." with "Treat an **unmarked** answer as settled —
      do not re-ask a question already answered here.", and add that one or more answers below
      are marked POTENTIALLY SUPERSEDED because the task description has changed since they were
      recorded, so the current `## Description` governs on conflict, pointing at
      `docs/architecture/orchestrate-state-machine.md`'s precedence section (authored in Phase 3)
      by section name.
- [ ] Update the script's own header comment (the block that already describes the Prior Decisions
      read path and its byte-identical-when-absent precedent) to describe the new conditional
      behavior.
- [ ] Extend `test-orchestrate-build-dispatch.sh` Group 10 with **VERIFY item 1**: an entry whose
      `description_fingerprint` matches the fixture's current description (digest computed in the
      test with the same `printf '%s' | sha256sum` shape) renders with no marker, with today's
      unconditional prose, and `diff -q`-identical to a dispatch stored from before the change.
- [ ] Extend Group 10 with **VERIFY item 2**: an entry whose fingerprint was computed against an
      earlier description, with the fixture's `state.json` description changed afterward — asserts
      the `POTENTIALLY SUPERSEDED` marker is present on that entry, that the conditional intro
      fired, that the entry's own question/answer/cycle/timestamp text is **still fully present**
      (the NON-GOAL: nothing suppressed), and that a second, matching entry in the same file is
      **not** marked.
- [ ] **VERIFY item 3**: confirm existing Group 10 Case A (absent `.decisions.json` → no
      `## Prior Decisions` section at all) and Case B (present-and-empty → byte-identical to
      absent) still pass unchanged. Confirm, do not re-author.
- [ ] **VERIFY item 4**: add an explicit `assert_not_contains ... "POTENTIALLY SUPERSEDED"` to the
      existing Case C (whose fixture already carries only the four legacy fields), so the
      "pre-existing entry lacking the new field renders without error and unmarked" claim is
      pinned by an assertion rather than merely implied by the absence of a failure.
- [ ] Refresh `test-orchestrate-record-decision.sh` case (h), which hand-copies the composer's
      render jq expression: update the copy to the new expression so the cross-script pin stays
      meaningful rather than silently asserting against a stale expression.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase assumes the composer's prior-decisions read and render blocks are
the only two sites touching `prior_decisions_block`, that `$description` at render time is the
same string the recorder hashed (both sourced from `state.json`'s `.description`), and that Group
10's Case A/B already discharge VERIFY item 3 and Case C's fixture already carries only the four
legacy fields. All four were re-derived from the files at plan-authoring time; confirm each by
reading the relevant block immediately before editing, and in particular confirm Case C's fixture
still lacks `description_fingerprint` before relying on it for VERIFY item 4.

**Tier Justification**: the composer's output is consumed by every dispatched agent and by
`orchestrate-cycle-plan.sh`'s dispatch-hash guard, so the covering check is its full mapped
dependent set:
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-record-decision.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-unwind-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-recover-message-findings.sh,test-force-phases.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - digest computation, `any_superseded` detection, per-entry marker in the render expression, conditional intro prose, header-comment update
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - Group 10 extension for VERIFY items 1, 2, and 4; confirm items 3's existing cases
- `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh` - refresh case (h)'s copied render expression

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-record-decision.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-unwind-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-recover-message-findings.sh,test-force-phases.sh`
  exits 0, with every new Group 10 case reported as PASS by name.
- Group 18 (`cycle_plan_dispatch_hash()` stability across a plan edit) still passes — the new
  content must not introduce per-cycle-varying material.
- A manual scratch run of the composer against a fixture with one mismatching and one matching
  entry shows: the conditional intro, the marker on exactly one entry, and both entries' full
  question/answer/cycle/timestamp text.

---

### Phase 3: State the precedence rule once [NOT STARTED]

**Goal**: `docs/architecture/orchestrate-state-machine.md` carries one authoritative statement of
how a Prior Decision relates to a later change in the task's own Description, so the composer and
a human reading a dispatch apply the same rule.

**Tasks**:
- [ ] Add a new top-level `## Prior Decisions vs. Current Description: Precedence` section. Site
      it after `## Abandoned Wrap-Up: Re-Prompt Once Before Accepting a No-Outcome Verdict` and
      before `## Diagnosing Dispatch Liveness: A Probe for External Watchers`, which places it
      adjacent to the Move 4 / batched-`AskUserQuestion` relay material it concerns. Confirm the
      neighbouring headings before inserting.
- [ ] State the rule, in this order: (a) `.decisions.json` is historical and immutable — a
      decision is never rewritten once recorded; (b) the task's current `## Description` is always
      the authoritative instruction; (c) a Prior Decision renders `POTENTIALLY SUPERSEDED` exactly
      when its recorded `description_fingerprint` no longer matches the current description's
      digest; (d) on such a conflict the current Description governs and the agent follows it, not
      the superseded answer; (e) an entry carrying no `description_fingerprint` cannot be verified
      and renders as settled.
- [ ] State (e)'s limitation plainly as a known, accepted consequence of the no-mutation
      constraint — including that every record written before this field existed is permanently
      unverifiable, so the original reproducer's own file will still render as settled. A reader
      must not mistake this for a bug.
- [ ] Note the two accepted approximations: an inconsequential description edit will flip the
      digest and mark an entry that still holds (over-surfacing chosen deliberately over
      under-surfacing), and the digest is taken at recorder-write time rather than at the instant
      the user answered.
- [ ] Cross-reference `handoff-schema.md`'s "Decisions File Schema" section for the field's shape
      rather than restating the digest command, so the two documents cannot drift.
- [ ] Reference the composer and recorder by script and section name, never by line number.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase assumes `orchestrate-state-machine.md` today contains zero
occurrences of `decisions.json` or `Prior Decision` (so the section is new text, not an edit to
existing prose) and that the two named neighbouring `##` headings still bracket the chosen
insertion point. Confirm with `grep -n 'decisions.json\|Prior Decision'` and `grep -n '^## '` over
the file immediately before inserting.

**Tier Justification**: the edit is confined to markdown prose with no compile or elaboration
surface, so the prose row's diff read-through applies, run together with the doc-mapped covering
suites `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-handoff-reader-parity.sh,test-lint-postflight-boundary.sh,test-resume-scan-nonconformance.sh,test-routing-resolution.sh,test-session-runtime-files.sh,test-stall-reprompt-wiring.sh`
(the set `suite_selection_select` resolves for `orchestrate-state-machine.md`, so this file is
**not** a `__FULL_SWEEP__` case).

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - new `## Prior Decisions vs. Current Description: Precedence` section

**Verification**:
- Diff read-through confirming every changed hunk is prose inside the new section, with no edit
  bleeding into a neighbouring section's content.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-handoff-reader-parity.sh,test-lint-postflight-boundary.sh,test-resume-scan-nonconformance.sh,test-routing-resolution.sh,test-session-runtime-files.sh,test-stall-reprompt-wiring.sh`
  exits 0.
- The marker string and intro wording in the new section match the strings Phase 2 actually emits,
  checked by grepping both the doc and `orchestrate-build-dispatch.sh` for
  `POTENTIALLY SUPERSEDED`.

---

### Phase 4: Full gate [NOT STARTED]

**Goal**: the complete repository gate set runs green over all of this task's changes.

**Tasks**:
- [ ] Re-read each of the six touched files for foreign modifications by a concurrent sibling
      before the final commit; `git log` to confirm any unexpected change is not this task's own.
- [ ] Run the complete gate set: `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim/agent-system/extensions/core`
      (explicit `TARGET`, no `--only-gate` filter, no `--skip-slow` — `--skip-slow` is never
      evidence that doc-sync pins hold).
- [ ] Confirm the full shell-suite battery (Gate 8) passes, and that no suite newly appears in
      `scripts/tests/known-failures.txt` as a result of this task.
- [ ] Commit with explicit file lists only; never `git add -A`, a directory pathspec, or a glob.
- [ ] Record the issue-log entries accumulated during the phases, and attest explicitly if there
      were none.

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- none planned — this phase runs the complete gate set and commits the work of Phases 1-3; any file it touches is a repair to one of the six files already enumerated above, not a new target.

**Verification**:
- `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim/agent-system/extensions/core`
  exits 0 — exit status checked directly, never inferred from a stdout diff.
- Every gate the aggregator runs reports PASS or a pre-existing, named SKIP; no gate reports
  zero-checks-under-filter.
- `git status --short` and `git diff --staged` reviewed before each commit, showing only this
  task's six files.

## Testing & Validation

- [ ] VERIFY 1: the no-conflict case (every entry's fingerprint matches) renders byte-identically
      to the pre-change dispatch — `diff -q` against a stored copy.
- [ ] VERIFY 2: an entry whose fingerprint predates a description change renders with the
      `POTENTIALLY SUPERSEDED` marker and the conditional intro, with its own text intact.
- [ ] VERIFY 3: a task with no `.decisions.json` emits no `## Prior Decisions` section at all
      (existing Group 10 Case A, confirmed unchanged).
- [ ] VERIFY 4: a pre-existing entry carrying only the four legacy fields renders without error
      and unmarked (existing Case C, with a new explicit negative assertion).
- [ ] Recorder: the field is written as a 64-hex digest matching an independently computed digest.
- [ ] Recorder: the field is omitted entirely — not emitted empty — when `sha256sum` is absent,
      and the append still exits 0.
- [ ] Degrade: with `sha256sum` masked at render time, the composer falls back to today's
      unconditional rendering and exits 0.
- [ ] No `.decisions.json` file anywhere under `specs/` is modified by this task — confirmed with
      `git status --short specs/`.
- [ ] Final: the complete `verify-deploy.sh` gate set exits 0.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-record-decision.sh` — optional
  `description_fingerprint` field on newly written entries
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — mismatch detection,
  inline `POTENTIALLY SUPERSEDED` marker, conditional section intro
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — the field documented as
  optional, with the authoritative digest shape
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — the precedence
  rule stated once
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — Group 10
  extended for all four VERIFY items
- `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh` — digest-equality
  and omission cases, refreshed case (h)
- `specs/427_dispatch_composer_emits_contradictory_authoritative_inputs/summaries/01_dispatch-prior-decision-precedence-summary.md`
  — implementation summary

## Rollback/Contingency

Every phase is an independent, committed, green increment, so the cheapest rollback is a forward
fix or `git revert` of the specific phase commit — all six files are additive, backward-compatible
edits with no migration to unwind, and no `.decisions.json` record is ever mutated.

If a rollback of *uncommitted* work is genuinely required (not as a routine precaution), take a
snapshot first per `context/contracts/recovery.md`'s rollback rung, then run the destructive
command. Do not emit `git-snapshot.sh` in its default reverting form as a start-of-phase
checkpoint; for an ordinary defensive checkpoint before risky work use
`bash .claude/scripts/git-snapshot.sh 427 --no-revert`, which is durable without reverting the
working tree.

Partial-state note: if the task stops after Phase 1 or 2, the system is still coherent — the field
is optional and unread (after Phase 1) or read with the rule stated only in the research report
(after Phase 2). Phase 3's doc section is the one deliverable whose absence leaves the original
defect's documentation gap open, so it must not be dropped if scope is cut.
