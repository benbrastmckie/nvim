# Implementation Plan: Task #534

- **Task**: 534 - Stop the orchestrate postflight from writing a detail-free blocking issue-log entry on every blocker-bearing partial return, and settle that entry's classification.
- **Status**: [NOT STARTED]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/534_postflight_detail_free_blocking_partial_issue_entry/reports/01_postflight-blocking-partial-issue-entry.md
- **Artifacts**: plans/01_postflight-blocking-partial-issue-entry.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

All edits land in the `core` extension's source store (`agent-system/extensions/core/`), in
exactly two files: `scripts/orchestrate-cycle-postflight.sh`'s `partial)` case arm and that
script's own test file `scripts/tests/test-orchestrate-cycle-postflight.sh`. The work splits into
three independent halves the dispatch already separated — restore the lost blocker detail
(highest value, landed first), settle the entry's classification, and suppress near-duplicate
volume keyed on blocker identity — followed by a terminal redeploy-and-full-gate phase. Nothing
in this plan touches `scripts/issue-record.sh`, `context/formats/issue-log.md`, or
`context/contracts/conclusion-stage.md`'s filter predicate; that territory belongs to the sibling
null-resolution record, and every change here is expressible through the existing call site's own
arguments plus the already-open `--class` enum and `--tags-json` pass-through.

### Premise Re-Validation (Carried-Figure Discipline)

Each of the four trigger-class lines the dispatch extracted was checked against the research
report and against live source before this plan was written. Results, stated explicitly:

- **Dispatch line 3 — "root cause is a type mismatch … raw `join("; ")`": SUPERSEDED, not
  current.** The source-store call site (`orchestrate-cycle-postflight.sh`, the
  `partial_blockers_detail` assignment inside the `partial)` arm) already carries a
  `map(if type == "object" … else tostring end) | join("; ")` render, landed incidentally per the
  research report's git provenance. Re-derived both halves mechanically at plan time: running the
  dispatch's literal `(.blockers // []) | join("; ")` against an object-shaped `blockers[]`
  payload without `2>/dev/null` reproduces `jq: error … string ("") and object … cannot be added`
  at exit 5 exactly as described, while the expression actually present produces
  `phase implement: lemma X | tried: induction | failed: refuted by counterexample` at exit 0. The
  described mechanism is real; the described code is not what is there. The narrower residual
  defect — `verbatim_goal` never reaching the rendered prose — is measurable in that same output
  (`prove X` is absent) and is what Phase 1 fixes.
- **Dispatch line 7 — "the test suite passes over the defect": CONFIRMED, unchanged.** The
  blocker-bearing-partial regression case in `test-orchestrate-cycle-postflight.sh` (the fixture
  under `specs/830_candidate`) sets a `blockers[]` entry carrying `target`, `verbatim_goal`, and
  `why_it_failed`, then asserts `state.json` `.status`, `.verdict`, `.halt`,
  `.aux_signal.kind`, `.aux_signal.blocker_desc`, and `aux_pending` persistence. It never opens
  `issues.jsonl`. The fixture's blocker object carries no `phase` and no `what_was_tried`, which
  makes it a usable probe for the absent-optional-subfield case as well.
- **Dispatch line 9 — the three classification questions: CONFIRMED, unchanged.** `--class
  "environment"` and `--severity blocking` are both still hard-coded at the call site.
  `issue-log.md`'s seed table glosses `environment` as "the local or CI environment (missing
  binary, version mismatch, permissions) caused the cost", confirming the class is wrong for the
  general case; its Severity Scale admits `blocking` for work that "could not proceed at all …
  the dispatch stalled or had to hand off because of it", which the call site's own
  `partial_blocker_count -gt 0` guard instantiates directly. The volume mechanism is structural
  and so is confirmed by construction; the two near-identical entries the dispatch cites are not
  resolvable in this repository (the migration provenance note states the `iss_*` ids resolve only
  in the source repository), so no corpus remediation is implied and the fix is purely
  prospective.
- **Dispatch line 11 — the suppression ordering obstacle: CONFIRMED, unchanged.** The `partial)`
  arm precedes the `WORK (e): user_decision relay` block in the script's control flow, so the
  relay has not run when the issue is written. The relay's own reads (`.user_decision` off the
  handoff, then off `.return-meta.json`) are side-effect-free, so duplicating them earlier is
  mechanically possible. It is nonetheless not done here — see Goals/Non-Goals and Phase 3.

### Research Integration

The plan adopts the research report's settlement of all three classification questions and its
drop of the suppression idea. Four findings shape the phase structure concretely: (1) the
`--class` field is a documented open enum whose writer warns-and-proceeds on an unseeded value,
so the wrong class can be corrected with zero edits to `issue-log.md` — which is what keeps this
record's file scope disjoint from the sibling null-resolution record; (2) `tags` is likewise an
open object with an existing `--tags-json` pass-through, which supplies an exact dedup key and
removes any need to pattern-match prose; (3) `severity blocking` is exact rather than merely
defensible, so it does not move; (4) the `annotate, don't reclassify` precedent at the sibling
`RECOVERY_DECLINED` call site is the model Phase 3 follows.

The plan departs from the research report in one place: Recommendation 6 proposed computing the
dedup identity by direct string match over `phase`+`target` against existing entries'
`what_happened`. Phase 3 instead writes the identity into `tags.blocker_identity` on every entry
and matches on that field, which makes the predicate an exact JSON field comparison rather than a
substring search over prose that Phase 1 is simultaneously reformatting. This is a cheaper and
more robust discharge of the same recommendation, inside the same file scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap phases are
included and `specs/ROADMAP.md` is neither read nor written by this plan.

## Goals & Non-Goals

**Goals**:
- Render every field the handoff's `blockers[]` objects actually carry — including
  `verbatim_goal` — into the recorded `what_happened`, under an explicitly stated,
  test-asserted format.
- Surface a jq failure at this one substitution instead of silently substituting the generic
  fallback string.
- Extend the existing blocker-bearing-partial regression fixture (not replace it) so the recorded
  `issues.jsonl` entry's `what_happened` content is asserted, and demonstrate the assertion red
  against the unmodified script before the fix lands.
- Replace the hard-coded `--class "environment"` with an honest value, and record the severity
  argument at the call site rather than leaving it implicit.
- Collapse N near-duplicate blocking entries for one unresolved blocker into one, keyed on
  blocker identity rather than on dispatch.
- Land every edit in the `core` source store and redeploy, confirming `RESULT=landed_verify_clean`.

**Non-Goals**:
- No edit to `scripts/issue-record.sh`, `context/formats/issue-log.md`, or
  `context/contracts/conclusion-stage.md` — reserved to the sibling null-resolution record. If a
  prose amendment to `issue-log.md` becomes genuinely necessary mid-implementation, add a
  serializing dependency edge via `update-task-status.sh --depends-on-add` at that point rather
  than editing the file.
- No change to `--severity blocking`, `--resolution open`, or `--suggested-channel
  follow_up_task` on this call site's `issue_args`.
- No suppression of the entry on `user_decision` presence. Dropped on two independent grounds,
  either sufficient alone: no mechanical test for "answered" exists at the postflight's vantage
  point (`user-decision-contract.md` makes the payload relayed-never-resolved, so presence means
  "being asked now"), and `issues.jsonl` is capture-only and never reaches the user mid-run while
  the `ask_user` verdict is a structurally separate channel, so there is no user-visible duplicate
  for a suppression to remove. The volume concern the idea reached for is discharged by Phase 3
  instead, which needs no `user_decision` read and therefore has no ordering dependency.
- No promotion of the new class value into `issue-log.md`'s documented seed table; the
  Extensibility Rule makes that a separate, later documentation decision.
- No remediation of existing `issues.jsonl` entries anywhere in this repository.
- No hand edit under `.claude/**`. That tree is a regenerated deploy artifact; it is reached only
  by the Phase 4 redeploy.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Phase 1's red-then-green sequence leaves an uncommittable intermediate state (assertion added, script unfixed) | M | H | Phase 1 declares `Commit Mode: atomic-batch`: the two-file set is one objective, the intermediate red state is expected and is not committed, and the single commit fires only once the suite is green |
| A new, unseeded `--class` literal reads as inconsistent with the seed-table-first convention | L | M | `issue-log.md`'s Extensibility Rule sanctions exactly this for a genuinely new failure mode; Phase 2 adds an inline comment at the call site naming why `environment`'s own admission test excludes this case, and no other call site in the script moves |
| The Phase 3 dedup read introduces a new read dependency on `issues.jsonl` at a call site that has none | M | M | The file is the task's own, created by this same script path; the read is advisory (skip-or-write only) and any failure or absence degrades to "write", today's behavior, never to a hard failure |
| Skipping a duplicate write loses evidence that the blocker recurred at a later dispatch | M | H | Phase 3 emits a diagnostic line to the script's own stream naming the matched prior `entry_id`, so recurrence stays visible in the run log; `metrics.jsonl` and the loop-guard file retain their own per-dispatch records independently |
| Removing `2>/dev/null` surfaces previously-invisible jq noise from a malformed handoff | L | L | The current render is total over any JSON element shape reachable from a schema-valid handoff, so the only realistic trigger is a genuinely malformed payload — the case where surfacing the diagnostic is correct behavior |
| Reformatting `what_happened` collides with Phase 3's identity matching if the latter matched on prose | M | M | Phase 3 matches on an exact `tags.blocker_identity` field written by the same call site, never on `what_happened` text |
| An edit lands in the deployed mirror and is wiped by the next regeneration | H | L | Every `Files to modify` entry below names a source-store path under `agent-system/extensions/core/`; Phase 4 is the only phase that reaches `.claude/**`, and it does so by running the deploy script |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Every wave here holds one phase: all four
phases edit the same five-line region of the `partial)` arm, so they are deliberately serialized
rather than batched.

---

### Phase 1: Restore the lost blocker detail and stop swallowing the jq error [NOT STARTED]

**Goal**: Every subfield the handoff's `blockers[]` objects carry reaches the recorded
`what_happened`, under a format stated explicitly here and asserted by the existing regression
fixture; a jq failure at this substitution becomes visible instead of degrading silently.

**The rendering format, decided explicitly (not left implicit in the jq expression)**: one
semicolon-separated clause per blocker entry. Within a clause, pipe-separated segments in this
fixed order:

```
phase <phase>: <target> | goal: <verbatim_goal> | tried: <what_was_tried> | failed: <why_it_failed>
```

- `phase` and `target` are the only two subfields `validate-handoff.sh` requires, so they are
  always rendered, each falling back to the empty string when absent — byte-for-byte the current
  behavior for these two, deliberately unchanged so the diff carries only the new field.
- `goal:`, `tried:`, and `failed:` are each omitted in their entirety — separator included —
  when the corresponding subfield is absent or empty, matching how the two already-rendered
  optional segments are guarded today.
- `goal:` is placed immediately after `target` because the refuted goal statement is the
  highest-value lost field; `tried:` and `failed:` keep their current relative order.
- A non-object element falls through to `tostring`, unchanged.

**Tasks**:
- [ ] Re-derive the premise at implementation time before editing: run the current
      `partial_blockers_detail` jq expression against a synthetic object-shaped `blockers[]`
      payload carrying all five subfields, with `2>/dev/null` removed, and confirm the output
      omits the `verbatim_goal` value. Record the observed output.
- [ ] Extend the existing blocker-bearing-partial regression fixture in
      `scripts/tests/test-orchestrate-cycle-postflight.sh` (the `specs/830_candidate` case) in
      place: add a `what_was_tried` and a `phase` to its `blockers[]` object so the fixture
      exercises every segment, then add assertions that read
      `$WORKDIR/specs/830_candidate/issues.jsonl` and require the recorded entry's
      `what_happened` to contain the blocker's `target`, `verbatim_goal`, `what_was_tried`, and
      `why_it_failed` values. Mirror the assertion style of the `aux_signal.blocker_desc`
      assertion immediately below it in the same fixture. Do not remove or renumber any existing
      assertion in that fixture.
- [ ] Run the suite and capture the RED result, confirming the new `verbatim_goal` assertion
      fails against the unmodified script. This is the acceptance bar's "show the assertion fails
      first" step; its output is recorded in the phase's verification notes. Do not commit this
      state.
- [ ] Add the `goal:` segment to the object branch of the `partial_blockers_detail` map
      expression in `scripts/orchestrate-cycle-postflight.sh`, guarded by the same non-empty check
      the existing optional segments use.
- [ ] Remove `2>/dev/null` from this one `partial_blockers_detail` substitution only, leaving
      every other `2>/dev/null` in the script untouched — including the `partial_blocker_count`
      substitution a few lines above, whose numeric-sanitizing `case` idiom depends on a quiet
      empty result. Add a one-line comment stating that the `[ -z … ]` fallback still fires
      identically and that only the visibility of *why* the output was empty changes.
- [ ] Re-run the suite and capture the GREEN result.
- [ ] Commit the two files together as one objective.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: atomic-batch

**Scope Hypothesis**: this phase asserts the edit touches exactly two files and, within
`orchestrate-cycle-postflight.sh`, only the `partial_blockers_detail` assignment line plus one
added comment line. Confirm at implementation time with `git diff --stat` before committing: a
third file, or a hunk outside the `partial)` arm, falsifies the hypothesis and must be
investigated rather than committed.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-corroborate-phase-counts.sh,test-deploy-baseline-lib.sh,test-force-phases.sh,test-gate-out-derived-staleness.sh,test-git-commit-scoped.sh,test-handoff-dispatch-identity.sh,test-handoff-reader-parity.sh,test-lint-deliberate-break-residue.sh,test-lint-json-channel-discipline.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-run-task-observers.sh,test-skill-base-lifecycle.sh,test-stall-reprompt-wiring.sh` is the complete covering set `suite_selection_select` returned, run at plan time, for this phase's two `Files to modify` paths.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - add the `goal:` segment to the `partial_blockers_detail` object branch; drop `2>/dev/null` from that one substitution
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - extend the `specs/830_candidate` blocker-bearing-partial fixture's `blockers[]` object and add `issues.jsonl` `what_happened` content assertions

**Verification**:
- The new assertion is demonstrated RED against the unmodified script, and the red output is
  recorded in the phase's verification notes.
- The suite named in the Tier Justification passes after the fix, with the `what_happened`
  assertions green.
- `git diff` on the script shows changes confined to the `partial_blockers_detail` assignment and
  one added comment line.

---

### Phase 2: Settle the entry's classification [NOT STARTED]

**Goal**: The entry carries an honest class instead of `environment`, severity stays `blocking`
on the strength of its own admission test, and both decisions are recorded at the call site
rather than left implicit.

**Tasks**:
- [ ] Replace `--class "environment"` with the literal `--class "unresolved task-domain blocker"`
      in the `partial)` arm's `issue_args` array. Pass it straight through `issue-record.sh`'s
      open `--class` enum; make no edit to `context/formats/issue-log.md`.
- [ ] Add an inline comment at the call site recording, in two or three lines: that
      `environment`'s own admission test names the local or CI environment and so almost never
      describes a blocker-bearing partial; that the actual class is not knowable from the
      postflight's vantage point, which is why the value states that honestly instead of guessing;
      and that no mechanical derivation from the handoff is attempted, because no field in the
      `blockers[]` object schema names a class and inferring one from free-text `why_it_failed`
      would be pattern-matching dressed as classification. Cite durable anchors only — the
      `issue-log.md` section names (`Seed Class Enum`, `Extensibility Rule`) and field names, no
      task numbers and no draft history.
- [ ] Add a second inline comment recording the severity argument on its own admission test: this
      call site is reachable only inside `partial_blocker_count -gt 0` within the `partial)` arm,
      which is a direct instance of the `Severity Scale`'s `blocking` rung ("work could not
      proceed at all … the dispatch stalled or had to hand off because of it"), so the value is
      exact rather than merely defensible and is not moved to reduce downstream channel volume.
- [ ] Extend the Phase 1 fixture's new `issues.jsonl` assertions to also require
      `.class == "unresolved task-domain blocker"` and `.severity == "blocking"` on the recorded
      entry, so the classification is pinned by the suite rather than only by prose.
- [ ] Run the suite and commit.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: the same complete `suite_selection_select` covering set as Phase 1 applies, these being the same two paths: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-corroborate-phase-counts.sh,test-deploy-baseline-lib.sh,test-force-phases.sh,test-gate-out-derived-staleness.sh,test-git-commit-scoped.sh,test-handoff-dispatch-identity.sh,test-handoff-reader-parity.sh,test-lint-deliberate-break-residue.sh,test-lint-json-channel-discipline.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-run-task-observers.sh,test-skill-base-lifecycle.sh,test-stall-reprompt-wiring.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - substitute the `--class` literal; add the class-rationale and severity-rationale comments
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - pin `.class` and `.severity` on the recorded entry

**Verification**:
- `grep -n '\-\-class "environment"' agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` returns nothing within the `partial)` arm.
- `--severity blocking`, `--resolution open`, and `--suggested-channel follow_up_task` are byte-identical to their pre-phase values.
- `git diff` touches neither `scripts/issue-record.sh` nor `context/formats/issue-log.md`.
- The suite named in the Tier Justification passes.

---

### Phase 3: Collapse repeat entries on blocker identity [NOT STARTED]

**Goal**: One unresolved blocker produces one open blocking entry per task, however many partial
dispatches it survives, with the recurrence still visible in the run log and no existing line
rewritten.

**The identity and the predicate, decided explicitly**:
- Identity is computed from the schema-guaranteed subfields only:
  `jq -r '[.blockers[]? | "\(.phase // "")|\(.target // "")"] | sort | join(",")'` over the
  handoff, then reduced to a short stable digest. `verbatim_goal`, `what_was_tried`, and
  `why_it_failed` are deliberately excluded — they are present-by-convention, not
  schema-enforced, and are free text an agent may reword between dispatches.
- The identity is written into `tags.blocker_identity` via the existing `--tags-json`
  pass-through on every entry this call site records, exploiting `issue-log.md`'s documented open
  `tags` seam. This is what makes the skip predicate an exact JSON field comparison rather than a
  substring search over `what_happened` — which Phase 1 is simultaneously reformatting, and which
  would therefore be a fragile key.
- The skip predicate: before calling `issue-record.sh`, if `$TASK_DIR/issues.jsonl` exists, skip
  the write when it already holds an entry with `.resolution == "open"` and
  `.tags.blocker_identity` equal to the computed identity. Any read failure, missing file, or
  unparseable line degrades to "write", today's behavior.
- `issue-log.md`'s `Occurrence Collapse` convention (`tags.occurrence`) is cited only to
  distinguish it: it serves a caller that already knows a repeat count before its first call,
  which this call site does not. No line is read-merged or rewritten, honoring the
  append-only-by-line invariant.

**Tasks**:
- [ ] Compute the blocker identity in the `partial)` arm, immediately after
      `partial_blockers_detail`, using the expression above with no `2>/dev/null` and a safe
      fallback to the empty string.
- [ ] Add `--tags-json` carrying `{"blocker_identity": "<identity>"}` to `issue_args` whenever the
      identity is non-empty.
- [ ] Add the skip guard reading `$TASK_DIR/issues.jsonl`. On a match, skip the
      `issue-record.sh` call and emit one diagnostic line to the script's own stream naming the
      matched prior `entry_id` and stating that the entry was not re-recorded — so the recurrence
      remains visible in the run log without a second `issues.jsonl` line.
- [ ] Add a short inline comment recording the dropped suppression-on-`user_decision` idea and
      why: `user-decision-contract.md` makes the payload relayed-never-resolved at this vantage
      point so no mechanical "answered" test exists, and `issue-log.md`'s capture-only property
      means the `ask_user` verdict is a separate channel with a different reader, so no
      user-visible duplicate exists for a suppression to remove. State it as the current design,
      citing those document and section names — no task numbers, no narration of alternatives
      considered over time.
- [ ] Add a new fixture (distinct from the Phase 1 one, not an overload of it) that runs the
      postflight twice against the same task directory with the same `blockers[]` identity across
      two dispatch sequence numbers, and assert `issues.jsonl` holds exactly one entry with that
      `tags.blocker_identity`.
- [ ] Add a companion assertion in the same new fixture that a *different* blocker identity on the
      second dispatch does produce a second entry, so the guard is shown to discriminate rather
      than to suppress unconditionally.
- [ ] Run the suite and commit.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts the dedup guard is expressible entirely within the
`partial)` arm — no new helper function, no change to `issue-record.sh`, and no new file. Confirm
at implementation time with `git diff --stat`: a diff reaching `scripts/issue-record.sh` or
`context/formats/issue-log.md` falsifies the hypothesis and means the serializing dependency edge
named in Non-Goals is owed before proceeding.

**Tier Justification**: the same complete `suite_selection_select` covering set as Phase 1 applies, these being the same two paths: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-corroborate-phase-counts.sh,test-deploy-baseline-lib.sh,test-force-phases.sh,test-gate-out-derived-staleness.sh,test-git-commit-scoped.sh,test-handoff-dispatch-identity.sh,test-handoff-reader-parity.sh,test-lint-deliberate-break-residue.sh,test-lint-json-channel-discipline.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-run-task-observers.sh,test-skill-base-lifecycle.sh,test-stall-reprompt-wiring.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - compute `blocker_identity`, pass it via `--tags-json`, add the skip guard and its diagnostic, add the suppression-drop comment
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - add the two-dispatch dedup fixture and its discriminating companion assertion

**Verification**:
- The new fixture shows exactly one entry for a repeated identity and two entries for two
  distinct identities.
- The Phase 1 and Phase 2 assertions still pass unchanged — the first write is not suppressed.
- `git diff` touches neither `scripts/issue-record.sh` nor `context/formats/issue-log.md`.
- The suite named in the Tier Justification passes.

---

### Phase 4: Redeploy and full-gate acceptance [NOT STARTED]

**Goal**: The source-store edits reach the deployed tree, and the complete gate set passes against
the result.

**Tasks**:
- [ ] Confirm every edit from Phases 1-3 lives under `agent-system/extensions/core/` and that
      `git status --short` shows no hand-authored change under `.claude/**`.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` and confirm the output reports
      `RESULT=landed_verify_clean`. Any other `RESULT` value halts this phase for diagnosis
      rather than being recorded as a pass.
- [ ] Confirm the deployed mirror `.claude/scripts/orchestrate-cycle-postflight.sh` now matches
      the source-store copy at the `partial)` arm.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (no `--skip-slow`, no
      `--only-gate`, no `--skip-unchanged`). Record the verdict.
- [ ] Record the verification notes and commit.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/**` tree; declared so the batch-admission `whole_tree_claim` dimension can serialize this phase against any concurrent task that also regenerates the tree

**Verification**:
- `deploy-headless.sh` reports `RESULT=landed_verify_clean` **and** exits 0; the `RESULT` line
  alone is not read as the pass signal.
- `bash .claude/scripts/verify-deploy.sh` exits 0 with every gate it aggregates run — no
  narrowing flag of any kind. A narrowed, `--skip-slow`, or `--skip-unchanged` pass does not
  satisfy this phase, and a zero exit is required rather than inferred from captured stdout.
- `bash .claude/scripts/tests/run-all.sh` exits 0 against the deployed tree.
- `git status --short` shows no residual uncommitted source-store change.

---

## Testing & Validation

- [ ] The blocker-bearing-partial fixture's new `what_happened` assertion is demonstrated RED
      against the unmodified script before the Phase 1 fix lands, and the red output is recorded.
- [ ] The recorded `what_happened` contains the blocker's `target`, `verbatim_goal`,
      `what_was_tried`, and `why_it_failed` values.
- [ ] A blocker object missing an optional subfield renders with that segment omitted entirely,
      separator included, and no stray `goal:`/`tried:`/`failed:` label.
- [ ] The recorded entry carries `class == "unresolved task-domain blocker"` and
      `severity == "blocking"`.
- [ ] `--resolution open` and `--suggested-channel follow_up_task` are unchanged.
- [ ] Two partial dispatches against one blocker identity yield exactly one open entry; two
      distinct identities yield two.
- [ ] No diff anywhere in this task reaches `scripts/issue-record.sh`,
      `context/formats/issue-log.md`, or `context/contracts/conclusion-stage.md`.
- [ ] `deploy-headless.sh` reports `RESULT=landed_verify_clean` and
      `bash .claude/scripts/verify-deploy.sh` passes unnarrowed.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — `partial)` arm:
  `verbatim_goal` rendered, jq error surfaced, honest `--class`, both classification rationales
  recorded inline, identity-keyed dedup guard and its diagnostic, suppression-drop rationale.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — the
  extended blocker-bearing-partial fixture plus one new dedup fixture.
- The regenerated `.claude/**` deploy mirror.
- `specs/534_postflight_detail_free_blocking_partial_issue_entry/summaries/01_*.md` at completion.

## Rollback/Contingency

Each phase is one commit, so `git revert` of that commit followed by
`bash .claude/scripts/deploy-headless.sh` restores the prior behavior of this call site without
touching anything else. Phase 1's `atomic-batch` commit is the only multi-file commit and reverts
as one unit. If an intentional rollback of uncommitted work is needed mid-phase, take a snapshot
first with `bash .claude/scripts/git-snapshot.sh 534` and then perform the destructive operation;
for an ordinary defensive checkpoint before the Phase 3 edit, use
`bash .claude/scripts/git-snapshot.sh --no-revert 534` instead, which is durable without
reverting the working tree. If Phase 4's deploy reports anything other than
`RESULT=landed_verify_clean`, do not force a second deploy: diagnose from that output, since a
stale or partial deploy is a worse state than an undeployed source-store edit.
