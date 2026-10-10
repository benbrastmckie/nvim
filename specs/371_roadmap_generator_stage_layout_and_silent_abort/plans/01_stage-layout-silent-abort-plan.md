# Implementation Plan: Task #371

- **Task**: 371 - Teach roadmap-integration.sh the stage-based ROADMAP layout and fix its silent abort
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: None
- **Research Inputs**: specs/371_roadmap_generator_stage_layout_and_silent_abort/reports/01_stage-layout-silent-abort-research.md
- **Artifacts**: plans/01_stage-layout-silent-abort-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`core/scripts/roadmap-integration.sh` hardcodes an eight-header section vocabulary; against a
stage-based `specs/ROADMAP.md` every `extract_section()` returns empty, which makes `--regenerate`
die silently under `pipefail` and makes `--prune` silently succeed at a near-total content wipe.
This plan lands four independent repairs, in a safety-first order: the always-present stderr
marker plus a named failure line (diagnosability), a layout-recognition gate that refuses loudly
on a vocabulary it cannot round-trip (the permanent destructive-overwrite property), the single
unguarded no-match-as-error pipeline, and then stage-layout round-trip support built on
byte-for-byte retention of every authored section. The generation contract
`core/context/formats/roadmap-format.md` is updated last to describe the two layouts the
generator now recognises, because a generator/spec disagreement is the precondition that produced
this defect. Definition of done: `--regenerate` round-trips a stage-based roadmap without content
loss, the classic eight-section layout still round-trips byte-identically, an unrecognised
vocabulary is refused loudly with a named reason and no write, the stderr marker appears on every
mode-dispatching invocation including failures, and the full gate set is green after redeploy.

### Research Integration

The research report (`reports/01_stage-layout-silent-abort-research.md`) is integrated as follows:

- **Crash site confirmed, not assumed**: `mode_regenerate`'s bare
  `covered_ids_json="$(covered_ids_from "$authored_next")"` assignment — `set -e` kills the script
  after the assignment completes because the inner pipeline's leading `grep`s exit 1 on no-match
  under `pipefail`. Phase 3 targets exactly this.
- **`--prune` is the more dangerous half, and it is live**: a `--prune --dry-run` against the
  stage-based fixture exits 0 and diffs away ~280 lines of authored prose. The refusal gate
  (Phase 2) therefore covers both write modes, not just `--regenerate`.
- **`--print` is structurally unaffected** (`mode_print` never calls
  `load_existing_sections`/`extract_section`). Confirmed by the research, not assumed; `--print`
  is deliberately left behaviourally unchanged and is used in Phase 1/6 as the control.
- **Only one unguarded pipeline exists**: every other no-match-prone `grep`/`jq -e` in the script
  is already guarded with `|| true` or wrapped in `if`. The audit is still re-run mechanically in
  Phase 3 rather than trusted from the report snapshot.
- **The research's Recommendation 4 scope judgment is adopted** (see Decisions below): the stage
  layout is round-tripped by opaque-blob retention of every authored section, with only the
  run-order fenced block treated as mechanically meaningful. The report's observed header drift
  (two hand-renames of top-level stage headers inside the research window) is what makes
  exact-header matching the wrong detection mechanism.
- **The research's marker-format risk is honoured** by freezing the marker's six-field shape; see
  Decisions.
- **No caller resolves `scripts/deprecated/roadmap-integration.sh`** — confirmed by repo-wide
  grep. No work is owed there, and the deprecated copy is deliberately absent from this plan's
  file scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, so no roadmap item mapping was performed. This
repository's own `specs/ROADMAP.md` uses the classic eight-section layout, which is the reason
Phase 6's regression bar includes "the classic layout still round-trips byte-identically".

## Decisions

Three design choices are settled here so implementation does not re-open them:

1. **Layout detection is structural, never exact-header matching.** `classic` is recognised by the
   presence of all eight literal headers. `stage` is recognised by two structural predicates: at
   least one header matching `^## Stage [0-9]+` exists, and some `## ` section's body contains a
   fenced block carrying at least one `^/orchestrate ` line (that section is the run-order
   section, whatever it is titled). Anything else is `unknown` and refused. This survives the
   cosmetic renames the research already observed (`## Run order at a glance` ->
   `## Next batches`; `Stage 1 — Decidability of L+ (preempts everything)` -> `Stage 1 —
   Decidability of L+`), which an exact-string match would not.
2. **The stderr marker's six-field shape is frozen; diagnosability is delivered separately.** The
   research floated adding a `status=ok|error` field, but the marker's regex is pinned in
   `roadmap-format.md`'s Parsing Patterns Summary and asserted `-->$`-anchored in the existing
   test suite, and `roadmap-update.md` (out of this task's file scope) documents caller reliance
   on its counts. Appending a field would be a silent contract break reaching a file this task
   may not edit. Instead: the same six-field marker is emitted on every mode-dispatching exit path
   via an idempotent `EXIT` trap, and a separate, clearly-prefixed `ERROR:` line (naming mode,
   failing line number, command and exit status) is emitted by an `ERR` trap. This satisfies
   sub-fault 1's actual complaint — undiagnosable without `bash -x` — without touching the
   machine-readable format.
3. **The marker's promise is scoped honestly rather than overclaimed.** The trap is installed
   after argument validation, so `--help` and usage/validation errors keep their current
   behaviour (they already print their own message and were never silent). The script header and
   `roadmap-format.md` are amended to state exactly that scope instead of the current
   unqualified "every invocation".

## Goals & Non-Goals

**Goals**:
- `--regenerate` works on the stage-based layout and round-trips it without content loss
  (preamble, every `## Stage N` section, "Not scoped as tasks", "Maintenance", "Related", and the
  hand-authored `/orchestrate` batch lines including the inline `# Stage N` comment lines inside
  the fence).
- The classic eight-section layout keeps its current behaviour exactly, including
  `--regenerate` idempotence (a second consecutive run is byte-identical).
- Both write modes refuse loudly — named reason, non-zero exit, no write — on a section
  vocabulary the script cannot round-trip. Permanent property, not a transitional guard.
- The promised stderr marker is emitted on every mode-dispatching invocation and every mode,
  including failure paths, and a failure additionally emits a named `ERROR:` line.
- No remaining no-match-as-error pipeline anywhere in the script.
- `roadmap-format.md` describes the layouts the generator now recognises, the detection rule, the
  refusal property, and the marker's exact scope.

**Non-Goals**:
- No change to `--print`'s behaviour (confirmed structurally independent of the file's header
  vocabulary).
- No edit to `context/patterns/roadmap-update.md` or `context/contracts/conclusion-stage.md` —
  the stale "no live caller" claim and the conclusion-stage caller-split documentation are the
  sibling record's territory.
- No structural parse of stage-section bullet prose (no per-task status-token extraction from
  stage bodies, no re-rendering of stage content). Stage sections are retained verbatim.
- No invention of an `## Open work` equivalent inside a stage-based roadmap.
- No change to `scripts/deprecated/roadmap-integration.sh` (confirmed dead).
- No general-pattern context file for "closed-vocabulary extraction must fail loudly" — the
  research suggested it as a possible follow-up, not as work owed here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Fixing the unguarded pipe before the refusal gate lands turns a loud crash into silent destruction on the stage fixture | H | H | Phase ordering is a hard constraint: Phase 2 (refusal gate) precedes Phase 3 (pipe fix). Never ship 3 without 2. |
| The run-order fenced block carries inline `# Stage N` comment lines the existing Next-line regex does not match, so a naive round-trip drops them | H | H | Stage-layout retention is byte-for-byte over the whole run-order body; only the coverage appendix is stripped and re-rendered. Phase 4's verification asserts comment-line survival explicitly. |
| Detection by exact header strings re-breaks on the next hand-rename | M | H | Decision 1: structural predicates only (`^## Stage [0-9]+` plus a fenced `/orchestrate` block). |
| An `EXIT`-trap marker fires twice, or fires with unset counters | M | M | Idempotence flag guards a single emission; task/topic counts are computed before the trap is installed, and every counter already has a `0` initialisation. |
| Adding a marker field would break the pinned regex and an out-of-scope caller doc | M | M | Decision 2: marker shape frozen; diagnosability via a separate `ERROR:` line. |
| A sibling task dispatched this same cycle edits a file this plan touches | M | L | Sibling 373's declared file scope does not intersect this plan's. Sibling 372 declares none: re-read every target file immediately before editing, stage only this task's own hunks by explicit file list, never a directory or glob add. |
| Refusal gate is too strict and starts refusing this repository's own classic roadmap | H | L | Phase 2 adds a positive regression assertion that the classic fixture and this repository's real `specs/ROADMAP.md` both classify as `classic`; `--dry-run` only, nothing written to the live file. |
| `--prune` on a stage layout has no coherent Open-work half | M | M | Phase 5 prunes only the run-order fenced block and retains everything else verbatim; if `prune_next_body` proves incompatible with the inline comment lines, the declared fallback is a loud named refusal for `--prune` on a stage layout — still non-destructive, never a silent wipe. |
| `roadmap-format.md` growing changes its `index-entries.json` `line_count` | L | H | `deploy-headless.sh` auto-repairs `line_count` before deploying; Phase 6 reviews that diff rather than hand-editing the value. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential: every phase
edits the same script, and Phase 2 must precede Phase 3 for the safety reason named in Risks.

### Phase 1: Always-present stderr marker and named failure diagnostics [COMPLETED]

**Goal**: Make the script's own "always-present marker" promise true on every mode-dispatching
exit path including failures, and make a failure diagnosable without `bash -x`.

**Tasks**:
- [x] Move the `task_count` / `topic_count` computations from the bottom of the file to just after
      `active_topics_json` is built, so their values exist before any mode runs. *(completed)*
- [x] Add `emit_marker()` printing the existing six-field marker verbatim
      (`mode`, `tasks`, `topics`, `runs`, `pruned`, `retained`), reading `${task_count:-0}` /
      `${topic_count:-0}` and the already-`0`-initialised `RUNS_COUNT`/`PRUNED_COUNT`/
      `RETAINED_COUNT`, guarded by a `MARKER_EMITTED` flag so it prints exactly once. *(completed)*
- [x] Install `trap emit_marker EXIT` immediately after argument validation (after the
      `--state` existence check), and delete the bottom-of-file marker `echo` it replaces.
      *(completed)*
- [x] Add `trap '...' ERR` emitting one `ERROR: roadmap-integration.sh failed (mode=$MODE) at
      line $LINENO: exit status N` stderr line before the EXIT trap's marker. *(completed: no
      `set -o errtrace` -- adding it double-printed the line from both the failing subshell and
      the parent assignment; default non-inherited ERR trap already covers the real crash shape,
      a top-level assignment whose command substitution fails, with exactly one line)*
- [x] Amend the script header's marker paragraph (currently "Every invocation, every mode") to
      state the precise scope settled in Decision 3: every invocation that reaches mode dispatch,
      including failure paths; `--help` and usage/validation errors print their own message
      instead. *(completed)*
- [x] Add a test case to `test-roadmap-generation.sh`: force a failure path (a `--regenerate`
      against a roadmap the current code cannot parse, or an injected failure) and assert both
      that a `<!-- roadmap-generation ... -->` line is present on stderr and that an `ERROR:`
      line naming the mode is present. *(completed: injected failure via malformed `--state`
      JSON, chosen over a ROADMAP.md parse failure because the latter's crash shape is exactly
      what Phase 3 fixes, which would silently turn this regression test false after Phase 3
      landed)*
- [x] Confirm no file landing under `agent-system/**` gains a task-number reference. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Tier Justification**: The edit is confined to one script plus its own suite, changes no
externally visible signature, and is covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-roadmap-generation.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - marker function, EXIT/ERR traps, count hoist, header text
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - failure-path marker and ERROR-line assertions

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-roadmap-generation.sh` exits 0 (checked by exit status, not by diffing output).
- `--print`, `--regenerate --dry-run`, `--prune --dry-run` against the classic fixture each emit exactly one marker line (count it, confirm it is 1 not 2).
- `--help` exit status and output are unchanged from before the edit.

---

### Phase 2: Layout recognition and loud destructive-overwrite refusal [NOT STARTED]

**Goal**: Give both write modes a permanent gate that classifies the existing roadmap's section
vocabulary and refuses loudly, with a named reason and no write, when it is one the script cannot
round-trip.

**Tasks**:
- [ ] Add `detect_layout FILE` returning `classic` / `stage` / `unknown` by the structural
      predicates in Decision 1 (all eight literal classic headers present -> `classic`; a
      `^## Stage [0-9]+` header plus some section body containing a fenced block with at least
      one `^/orchestrate ` line -> `stage`; otherwise `unknown`).
- [ ] Call it once at the top of both `mode_regenerate()` and `mode_prune()`, immediately before
      `load_existing_sections`, and on `unknown` print a named refusal to stderr
      (listing the file's actual `## ` headers and naming the two recognised vocabularies) and
      return a non-zero status with no write attempted.
- [ ] Route `stage` to the same refusal for now, with a distinct reason string — Phases 4 and 5
      replace that branch with real support. This keeps every intermediate commit non-destructive.
- [ ] Document the refusal in the script header as a permanent property, not a transitional guard.
- [ ] Add test cases: an `unknown`-vocabulary fixture is refused by `--regenerate` and by
      `--prune` (non-zero exit, file checksum unchanged, named reason on stderr); the classic
      fixture still classifies `classic` and still succeeds.
- [ ] Classify this repository's real `specs/ROADMAP.md` as a smoke check using a scratch copy
      (never the live file, never a write mode against it).

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the classic vocabulary is exactly the eight literal
headers listed in `roadmap-format.md`'s Section Order table and matched at
`load_existing_sections`' eight `extract_section` call sites. Confirm at implementation time by
re-reading both lists and this repository's own `grep -n '^## ' specs/ROADMAP.md` output before
coding the predicate; the figure is carried from `roadmap-format.md` and the research report, not
re-derived here.

**Tier Justification**: Confined to one script and its own suite with no signature change, and
covered by `run-all.sh --only test-roadmap-generation.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - `detect_layout`, refusal branches in both write modes, header note
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - unknown-vocabulary refusal cases, classic-still-accepted assertions

**Verification**:
- `run-all.sh --only test-roadmap-generation.sh` exits 0.
- `--regenerate` and `--prune` against an unknown-vocabulary fixture: non-zero exit, `sha256sum` of the fixture unchanged, refusal reason on stderr, marker still emitted (Phase 1 regression).
- Classic fixture `--regenerate` still produces the same output as before this phase.

---

### Phase 3: Eliminate the no-match-as-error pipeline and re-run the audit [NOT STARTED]

**Goal**: Make `covered_ids_from()` treat no-match as the normal condition it is, and
mechanically re-confirm no other call site has the same shape.

**Tasks**:
- [ ] Guard `covered_ids_from()`'s pipeline so an empty or `/orchestrate`-free body yields `[]`
      with exit 0, matching the `|| true` pattern already used two lines below it for
      `RUNS_COUNT`.
- [ ] Re-run the whole-script audit mechanically rather than trusting the report: enumerate every
      `grep`/`jq -e` in a pipeline or command substitution
      (`grep -nE 'grep|jq -e' agent-system/extensions/core/scripts/roadmap-integration.sh`) and
      check each for an `if`/`while`/`||`/`! ` guard; record the enumeration in the phase's
      progress notes.
- [ ] Add a regression test case: `--regenerate` against a classic-layout fixture whose `## Next`
      body contains zero `/orchestrate` lines exits 0 and renders a coverage appendix for all
      ready tasks.
- [ ] Re-confirm, with the Phase 2 gate in place, that no code path can now reach
      `assemble_roadmap` on an unrecognised vocabulary.

**Timing**: 45 minutes

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts `covered_ids_from()` is the *only* unguarded
no-match-prone pipeline in the script — a figure carried from the research report's audit
(`reports/01_stage-layout-silent-abort-research.md`, Codebase Patterns), not re-derived at plan
time. Confirm at implementation time by running the enumeration grep above over the current file
and inspecting each hit, before declaring the audit discharged.

**Tier Justification**: One-line pipeline guard plus a new test case in the same two files, with
no signature change, covered by `run-all.sh --only test-roadmap-generation.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - `covered_ids_from` guard
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - empty-Next regression case

**Verification**:
- `run-all.sh --only test-roadmap-generation.sh` exits 0.
- `--regenerate --dry-run` against a classic fixture with an empty `## Next` body exits 0 (this is the exact crash reproduction, now passing).
- The audit enumeration shows every remaining `grep`/`jq -e` guarded; the list is recorded in the progress notes.

---

### Phase 4: Stage-layout round-trip for --regenerate [NOT STARTED]

**Goal**: Teach `--regenerate` to round-trip a stage-based roadmap by retaining every authored
section byte-for-byte and rebuilding only the coverage appendix under the run-order section.

**Tasks**:
- [ ] Add a vocabulary-agnostic splitter: read the file into the title line, the preamble
      (reuse the already-correct `extract_preamble`), and an ordered list of
      `(header, body)` pairs for every `^## ` section, preserving header text and order exactly.
- [ ] Add a stage-layout reassembler that emits title, preamble, then each retained
      `(header, body)` pair in its original order — the stage analogue of `assemble_roadmap`,
      with no fixed template and no section invented or dropped.
- [ ] Identify the run-order section by the Decision 1 predicate (first section whose body holds a
      fenced block with a `^/orchestrate ` line), strip any previously-generated coverage appendix
      from its body with the existing `strip_coverage_appendix`, compute `covered_ids_from` over
      the retained body, and append a freshly rendered coverage appendix.
- [ ] Replace Phase 2's `stage` refusal branch in `mode_regenerate()` with this path; set
      `RUNS_COUNT` from the retained run lines and `RETAINED_COUNT` to the retained-section count
      so the marker stays meaningful.
- [ ] Add a stage-layout fixture to the test suite, faithful to the real regression fixture's
      shape: a preamble, a run-order section whose fence mixes `# Stage N — ...` comment lines
      with `/orchestrate ...` lines, several `## Stage N — ...` sections with bullet prose, and
      `## Not scoped as tasks` / `## Maintenance` / `## Related` sections.
- [ ] Add test cases: round-trip preserves every stage section and the inline fence comment lines
      byte-for-byte; a second consecutive `--regenerate` is byte-identical (idempotence); a
      previously-generated appendix is replaced, not accumulated.
- [ ] Verify against the real regression fixture read-only: copy
      `~/Projects/BimodalLogic/specs/ROADMAP.md` into a scratch tree alongside a `state.json`,
      run `--regenerate --dry-run` there, and confirm the diff touches only the coverage appendix.
      Nothing in that repository is read-write or modified.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the stage layout's authored sections are the set the
research enumerated for the regression fixture (`## Run order at a glance`/`## Next batches`,
`## Stage 0`-`## Stage 4`, `## Not scoped as tasks`, `## Maintenance`, `## Related`) — carried
from the research report and the task description, not re-derived at plan time, and already
observed drifting by hand-rename. Confirm at implementation time with
`grep -n '^## ' ~/Projects/BimodalLogic/specs/ROADMAP.md`, and treat any difference as expected:
the implementation must be driven by the structural predicate, never by this enumeration.

**Tier Justification**: The new code path is additive and reached only for a layout the previous
phase refused, so the classic path's behaviour is unchanged; both the new and the preserved path
are covered by `run-all.sh --only test-roadmap-generation.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - section splitter, stage reassembler, run-order resolution, stage branch in `mode_regenerate`
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - stage fixture, round-trip, idempotence and appendix-replacement cases

**Verification**:
- `run-all.sh --only test-roadmap-generation.sh` exits 0.
- Stage fixture: `--regenerate` then a second `--regenerate` produce byte-identical files (`sha256sum` comparison).
- Stage fixture: every `## Stage N` body and every in-fence `# Stage N` comment line is present verbatim after a round-trip.
- Scratch copy of the real regression fixture: `--regenerate --dry-run` diff contains only coverage-appendix hunks; no Stage 0-4 or rationale-prose lines are removed.
- Classic fixture behaviour unchanged (re-run the pre-existing classic cases).

---

### Phase 5: Stage-layout handling for --prune [NOT STARTED]

**Goal**: Close `--prune`'s silent-destruction path on a stage layout by pruning only the
run-order fenced block and retaining every other section byte-for-byte.

**Tasks**:
- [ ] Replace Phase 2's `stage` refusal branch in `mode_prune()` with the Phase 4 splitter plus
      reassembler, applying `prune_next_body` (or its stage-aware equivalent) to the run-order
      section's body only.
- [ ] Confirm `prune_next_body` leaves in-fence `# Stage N` comment lines intact; if it does not,
      take the declared fallback: keep `--prune` refusing loudly on a stage layout with a named
      reason and record that decision in the phase notes and in Phase 6's contract update. Either
      outcome is non-destructive; a silent wipe is not an acceptable outcome of this phase.
- [ ] Set `PRUNED_COUNT` from the run lines actually dropped and leave the Open-work half a
      documented no-op (a stage layout has no `## Open work` section to prune).
- [ ] Add test cases: stage fixture `--prune --dry-run` writes nothing; stage fixture `--prune`
      drops only all-terminal run lines and preserves every other section verbatim; the
      previously-reproduced total-wipe diff cannot recur.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Tier Justification**: Confined to the same script and suite with no signature change, and
covered by `run-all.sh --only test-roadmap-generation.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - stage branch in `mode_prune`, `PRUNED_COUNT` accounting
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - stage-layout prune cases

**Verification**:
- `run-all.sh --only test-roadmap-generation.sh` exits 0.
- Stage fixture `--prune --dry-run`: file checksum unchanged.
- Stage fixture `--prune`: the diff drops only all-terminal run lines; every `## Stage N`, `## Not scoped as tasks`, `## Maintenance` and `## Related` section survives verbatim (or, on the declared fallback, the run exits non-zero with a named reason and writes nothing).
- Classic-layout prune cases unchanged.

---

### Phase 6: Update the generation contract and redeploy [NOT STARTED]

**Goal**: Bring `roadmap-format.md` into agreement with the generator's actual behaviour, redeploy
the source store, and run the full gate set.

**Tasks**:
- [ ] Rewrite `roadmap-format.md`'s `## Section Order` to describe two recognised layouts: the
      classic eight-section vocabulary (unchanged, with its table) and the stage-based layout
      (structural predicate, not an enumerated header list), stating that stage sections are
      retained byte-for-byte and only the coverage appendix is generated.
- [ ] Add a subsection documenting the destructive-overwrite refusal as a permanent property:
      what makes a vocabulary unrecognised, the loud named refusal, non-zero exit, no write, for
      both write modes.
- [ ] Amend `## Generation`'s marker paragraph to state the marker's exact scope (every invocation
      reaching mode dispatch, including failures; `--help` and usage errors excluded) and to
      mention the separate `ERROR:` diagnostic line. Leave the Parsing Patterns Summary's marker
      regex unchanged — the six-field shape is frozen per Decision 2.
- [ ] Record the stage-layout `--prune` semantics actually implemented in Phase 5 (run-order
      pruning only, or the declared refusal fallback).
- [ ] Confirm no task-number reference lands in any `agent-system/**` file.
- [ ] Redeploy: `bash agent-system/extensions/core/scripts/deploy-headless.sh` (or the repository's
      standard invocation), and review the auto-repaired `index-entries.json` `line_count` diff
      rather than hand-editing it.
- [ ] Run the full gate set and record the result.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/formats/roadmap-format.md` - two-layout section order, refusal property, marker scope, prune semantics
- `agent-system/extensions/core/index-entries.json` - `line_count` for the format spec, auto-repaired by the deploy script (review only, do not hand-edit)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set, not a hand-picked subset; capture and record the exit status.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0 (the whole suite, not `--only`).
- `bash .claude/scripts/roadmap-integration.sh --regenerate --dry-run` against this repository's own classic `specs/ROADMAP.md` exits 0 and produces a diff confined to generated sections.
- `roadmap-format.md` and the script agree on: recognised layouts, refusal behaviour, marker scope. Read both side by side as the final check.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0 (whole suite).
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 after redeploy.
- [ ] Classic eight-section fixture: `--print`, `--regenerate`, `--prune` behaviour identical to pre-change, including `--regenerate` idempotence.
- [ ] Stage-based fixture: `--regenerate` round-trips without content loss and is idempotent; `--prune` is non-destructive.
- [ ] Unknown-vocabulary fixture: both write modes refuse with a named reason, non-zero exit, zero bytes written.
- [ ] Every mode-dispatching invocation emits exactly one stderr marker; every failure additionally emits one named `ERROR:` line.
- [ ] A scratch copy of the real regression fixture (`~/Projects/BimodalLogic/specs/ROADMAP.md`) round-trips with a coverage-appendix-only diff; that repository is never written.
- [ ] No task-number reference in any file landing under `agent-system/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/roadmap-integration.sh` - layout detection, loud refusal, stage round-trip, guarded pipeline, always-present marker, named failure line
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - stage fixture plus refusal, round-trip, idempotence, empty-Next and marker-on-failure cases
- `agent-system/extensions/core/context/formats/roadmap-format.md` - two-layout generation contract, permanent refusal property, marker scope
- `agent-system/extensions/core/index-entries.json` - auto-repaired `line_count`
- Deployed `.claude/` tree regenerated by the deploy script
- `specs/371_roadmap_generator_stage_layout_and_silent_abort/summaries/01_*-summary.md` at completion

## Rollback/Contingency

Every phase is a single-file-plus-test commit, so the cheapest contingency is a forward fix or a
revert of the offending commit. If a mid-phase state must be abandoned with uncommitted work
present, take a durable non-reverting checkpoint first
(`bash .claude/scripts/git-snapshot.sh 371 --no-revert`) and fix forward; only a genuine rollback
uses the reverting form, per `context/contracts/recovery.md`'s rollback rung. If Phase 4's stage
round-trip proves unworkable, the safe resting state is the end of Phase 3: both write modes
refuse loudly on a stage layout, the crash is gone, nothing is destroyed, and the contract update
in Phase 6 records the refusal rather than support. That resting state satisfies the
destructive-overwrite and silent-abort halves of what is owed, and leaves only stage round-trip
outstanding.
