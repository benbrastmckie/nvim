# Implementation Plan: Task #515

- **Task**: 515 - Rebase the bounded-wait guidance on the measured foreground-backgrounding ceiling
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: 507 (recorded in state.json; admitted for this dispatch by the orchestrator)
- **Research Inputs**: specs/515_rebase_bounded_wait_guidance_on_180s_ceiling/reports/01_rebase-bounded-wait-ceiling.md
- **Artifacts**: plans/01_rebase-bounded-wait-ceiling.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research re-measured the foreground-Bash backgrounding boundary first-hand and **refuted** the
carried ~180s figure: on harness Claude Code 2.1.322, calls at 10s/170s/190s/350s/590s with the
Bash tool's own `timeout` parameter raised to `600000` all completed synchronously with exact
elapsed-time match, and only a 620s call was backgrounded — with the harness's own message naming
"600s timeout" verbatim. The numeric model in both pattern files (120000ms default, 600s ceiling,
raise-the-parameter remedy, 540s inner margin, 3a/3b sub-case split) is therefore **correct as
written**, and the dispatch's own FIRST OBLIGATION section pre-authorizes this as the successful
"close as no-change" outcome.

This plan implements the *second half* of that disposition — "close this record as no-change
**with the measurement recorded**", and "Record the harness version alongside the number, since
this is a harness behaviour and not a property of this repository". It makes **no numeric change
anywhere** and **no propagation change**: the copied canonical bullet pair stays byte-identical,
all 24 literal carriers stay untouched, and the nine `600000`-bearing markdown files keep every
figure they carry. The only edits are two small prose additions that make the measurement durable
in the corpus the next agent actually reads.

### Decision: record the measurement in the guidance, rather than a strict zero-edit close

The research report recommends no edits to either pattern file, and that reading is defensible.
This plan deliberately takes the narrower-but-non-empty route instead, for one reason: the
failure this record exists to close was an agent **mis-deriving a lower ceiling from a stall and
acting on it**, and a measurement that lives only in a `specs/**` report is invisible to the next
agent that hits the same stall. Two additions inoculate against a repeat at near-zero risk:

1. A dated, harness-versioned measurement-provenance record, so the 600s figure is pinned as
   *measured* rather than inferred and need not be re-litigated from a stall.
2. A diagnostic for the actual observed failure mode: a call backgrounded *well below* 600s means
   the call's own `timeout` parameter was not in fact raised — the remedy is to check that
   parameter's value in the offending call, never to infer a lower ceiling and rebase the
   guidance on it.

Neither addition changes a number, the 3a/3b split, the canonical idiom, or the copied bullet.
The strict zero-edit alternative is recorded in Risks & Mitigations below.

### Research Integration

- Measured boundary: **600s exactly**, harness Claude Code 2.1.322, six bracketed data points
  (170s/190s straddling the claimed ~180s figure; 590s/620s straddling the real boundary).
- The `timeout` parameter is **honoured**, not ignored — the direct contradiction of the carried
  claim, and the fact the diagnostic in Phase 1 rests on.
- The cited incident is a single after-the-fact self-report with no calibration calls of its own;
  the report's two candidate accounts (harness-version difference; the parameter never actually
  raised, so the `120000`ms default governed and "around 180s" is an imprecise recollection) are
  both consistent with the measurement without the documented ceiling being wrong.
- The propagation obligation is conditioned on the numbers being wrong and therefore **does not
  activate**.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied with this dispatch; ROADMAP.md not consulted.

## Premise Re-Validation (Carried-Figure Discipline)

Every line the dispatch flagged, checked against live state in this planning pass. Results are
stated even where they only confirm the description.

| # | Flagged claim | Result |
|---|---|---|
| 1 | Source store is the edit target; `source_dir` lives per-extension | **CONFIRMED.** `jq '.extensions.core.source_dir'` on `.claude-extensions.json` resolves to `/home/benjamin/.config/nvim/agent-system/extensions/core`; `lean` resolves alongside it. Nine extensions declared, all under `agent-system/extensions/`. |
| 2 | The defect: ~180s ceiling, `timeout` parameter ignored, `600000` remedy inert | **REFUTED** by the research phase's direct measurement. Boundary is 600s on harness 2.1.322; the parameter is honoured; the remedy is live, not inert. This is the finding the whole plan turns on. |
| 3 | `external-process-wait.md` Rule 1 content (required `600000` step, "inert unless raised FROM that default", "Why 540 < 600" paragraph, ceiling-defined 3a/3b split) | **CONFIRMED verbatim** by direct read of the source-store file (Rule 1 step (2), the two-sub-case paragraph, and the "Why 540 < 600" paragraph are all present as described; 187 lines total). Line numbers not cited — they move. |
| 4 | Generated-copy mechanism; Check H/Check K; "29 files carrying the MUST bullet" | **Mechanism CONFIRMED** (the file's own "Generated-Copy Source, Not an `@`-Import" section; `scripts/lint/lint-agent-contracts.sh` present in the source store). **Count RE-DERIVED as 24, not 29**: 23 agent bodies across 14 extension `agents/` directories plus the pattern source itself. Separately, `600000`-bearing markdown under `extensions/` re-derives to **nine** files — the six the description names, the two pattern files, **plus `lean/agents/lean-implementation-agent.md`, which the description's list omits**. No action follows from either correction: propagation is not triggered. |
| 5 | Liveness primitive is `pid=$!` + `kill -0`, enforced by `hooks/validate-bounded-waiter.sh` | **CONFIRMED.** The hook exists at `agent-system/extensions/core/hooks/validate-bounded-waiter.sh` with a test at `scripts/tests/test-validate-bounded-waiter.sh`; the canonical idiom in `bounded-build-waiter.md` uses exactly that pair. Nothing in this plan touches either. |
| 6 | #454 depends on this record landing first so it reasons from a corrected premise | **Edge CONFIRMED PRESENT, premise VOID.** `state.json` shows 454 `not_started`, `dependencies: [328, 435, 439, 515]`, and 439 `not_started`, `dependencies: [431, 515]` — both edges exist (the field is `dependencies`, not `depends_on`). But there is no corrected premise for either to wait on: #454's own objection, that "raise the timeout per the existing guidance" is inert, is itself what the measurement refutes. Edge disposition is surfaced as a non-blocking `user_decision`, not acted on here. |
| 7 | #392 landed "the tool-timeout half of the bounded-wait idiom" — read it before concluding the figure was never deliberate | **CONFIRMED present and deliberate.** `specs/archive/392_deliver_tool_timeout_half_of_bounded_wait_idiom/` holds a report, a 10-phase plan, ten phase-progress files and a summary — a deliberate, fully-executed delivery of the `600000` instruction, not an incidental figure. This strengthens, rather than weakens, the no-change conclusion. |

## Goals & Non-Goals

**Goals**:

- Pin the 600s ceiling in the guidance as a dated, harness-versioned **measurement**, so the next
  agent that stalls does not re-derive a lower number from the stall itself.
- State the diagnostic for a sub-600s backgrounding: the call's own `timeout` parameter was not
  raised — check it, do not rebase the ceiling.
- Prove and record that the no-change half holds: the copied canonical bullet is byte-identical,
  every `600000` figure is untouched, and the full lint/gate set stays green.
- Leave the two sibling-ordering edges to an operator, with the reasoning stated.

**Non-Goals**:

- Any numeric change to any ceiling, default, inner-bound, or margin figure anywhere.
- Any change to the canonical idiom, the copied bullet pair, or the 24 literal carriers.
- Promoting the sentinel-plus-poll "working remedy" into the guidance — its motivating premise (a
  sub-180s ceiling under which essentially every `lake build` falls in 3b) did not survive
  measurement, and the existing 3a/3b split already treats fits-under-600s as the common case.
- Re-opening the recorded rulings the dispatch lists as not-to-re-litigate (hard-variant
  inheritance, research-agent scope, Rule 5 non-propagation, the detachment livelock protection).
- Removing, adding, or editing any task dependency edge (operator action; see `user_decision`).
- Chasing the originating incident further. Per the report, that belongs in a record filed in the
  repository where it was observed, not here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A strict reading of "close as no-change" treats even provenance prose as out of scope | L | M | The additions are scoped to provenance and diagnosis only, change no number and no normative step, and are confined to two files; the whole plan is revertible by one `git revert` of a single commit. The decision and its alternative are recorded above rather than left implicit. |
| An edit near Rule 1 disturbs the copied bullet or a `600000` figure | H | L | Phase 1 and Phase 2 each pin byte-identity *before and after* the edit via `git diff` on the changed hunks plus lint Check H; Phase 3's lint run is the independent confirmation. No edit goes inside the "Copy this exact text" block. |
| Prose cites the originating incident in a way that trips the deliverable rules | M | M | Cite the issue **entry id** and the repository name only — never a `specs/{NNN}_{slug}/` path (it embeds a task number) and never a "task N" string. State the measurement on its own merits; no "previously", "no longer", "formerly", or supersession framing (`no-record-versioning-in-deliverables.md`). |
| A sibling session edits one of the two files mid-phase | M | L | Neither file appears in any concurrent sibling's declared `file_scope` (597, 600, 601, 490, 531, 603 all declare disjoint paths). Still re-read each file immediately before editing, stage only this task's own hunks via `git-commit-scoped.sh`, and never run `git-snapshot.sh` in its reverting default form. |
| The dispatch's "exercise the new poll idiom end to end" verification looks unmet | L | M | It is conditioned on a newly documented poll idiom; none is documented, so it does not activate. Phase 3 records that explicitly rather than silently skipping it, and notes the research phase's own 590s/620s bracket as the live exercise of the existing idiom's boundary. |
| Deploy regenerates the whole `.claude/` tree while siblings are active | M | M | Phase 3 declares `__WHOLE_TREE__` so batch admission serializes it; it uses the scoped commit narrowing rather than the full aggregator, per the dispatch's VERIFY section. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Record the measured ceiling and the misattribution diagnostic [COMPLETED]

**Goal**: `external-process-wait.md` carries a dated, harness-versioned record that the 600s
ceiling is measured, and the diagnostic that a sub-600s backgrounding means an unraised
parameter — with every existing figure and the copied bullet untouched.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/context/patterns/external-process-wait.md` in full
      immediately before editing (concurrency re-read obligation), and confirm Rule 1 step (2),
      the two-sub-case paragraph, and the "Why 540 < 600" paragraph are still as this plan
      describes. *(completed)*
- [x] Record the pre-edit state: `git diff --stat -- agent-system/extensions/core/context/patterns/external-process-wait.md`
      must be empty before starting (if not, a sibling touched it — stop and report per the
      concurrency note). *(completed: confirmed empty)*
- [x] Add one new subsection to Rule 1, placed **after** the "Why 540 < 600" paragraph and before
      `### 2. No no-op filler`, titled `#### The 600s Ceiling Is Measured, Not Assumed`. Do not
      renumber Rule 1-5 and do not reword any existing paragraph. *(completed)*
- [x] In that subsection, state: the harness version measured (Claude Code 2.1.322), the
      measurement date (2026-11-12, UTC), and the bracketed result — calls at 10s, 170s, 190s,
      350s and 590s issued with the tool `timeout` parameter at `600000` all returned
      synchronously with elapsed time matching the request exactly; a 620s call was moved to the
      background at the 600s mark with the harness's own message naming "600s". Conclude the one
      load-bearing fact: the `timeout` parameter is honoured, so step (2) is a live remedy and the
      600s figure in this file is the measured boundary, not an inferred one. *(completed)*
- [x] In the same subsection, add the diagnostic: **a call backgrounded well short of 600s is
      evidence that this call's own `timeout` parameter was not raised from its `120000`ms
      default, not evidence of a lower ceiling.** The remedy is to check the offending call's own
      parameter value; characterising a lower ceiling from a stall and rebasing this file's
      figures on it is the mis-derivation this record exists to prevent. Note that one such
      characterization — a ~180s ceiling with the parameter allegedly ignored — was recorded in a
      consumer repository's issue log (entry `iss_1793996881041_SDZX8Y`) as an after-the-fact
      stall explanation, and did not reproduce under the bracketed measurement above. Cite the
      entry id and the repository name only. *(completed)*
- [x] Verify no `600000`, `120000`, `540`, or `600` figure elsewhere in the file changed:
      `git diff -- <file> | grep -E '^[-+].*(600000|120000|540|600)'` must show only added lines
      from the new subsection and **no `-` (removed) lines at all**. *(completed: verified, zero
      removed lines)*
- [x] Verify the file carries no task-number reference and no record-versioning phrasing in the
      added hunk (grep the added lines for `task [0-9]`, `previously`, `no longer`, `formerly`,
      `supersede`, `v1`, `v2`). *(completed: verified, zero matches)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-detect-noop-bash.sh,test-orchestrate-build-dispatch.sh` is the suite set `suite_selection_select` returns verbatim for this phase's single file, and the edit is confined to added prose inside a markdown pattern document with no executable surface.

**Scope Hypothesis**: this phase touches exactly one file and adds only new lines — no existing
line is modified or removed. The implementer confirms it by requiring the phase's `git diff` to
show zero `-` lines for that file before closing the phase; a diff with any removed line means the
hypothesis failed and the edit must be redone as a pure addition.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/external-process-wait.md` - adds one
  `#### The 600s Ceiling Is Measured, Not Assumed` subsection inside Rule 1 carrying the
  harness-versioned measurement and the unraised-parameter diagnostic; no existing text altered.

**Verification**:

- `git diff -- agent-system/extensions/core/context/patterns/external-process-wait.md` shows
  added lines only, zero removed lines.
- The added hunk contains the harness version, the measurement date, both bracket endpoints
  (590s synchronous, 620s backgrounded), and the diagnostic sentence.
- No task-number reference and no record-versioning phrasing in the added hunk.

---

### Phase 2: Point the per-call pairing at the measurement record [COMPLETED]

**Goal**: a reader of `bounded-build-waiter.md`'s sizing subsection can reach the measurement
record without re-deriving it, and the file's own `600000` statements are visibly grounded.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/context/patterns/bounded-build-waiter.md`'s
      `### Sizing a Wait Near the Per-Call Ceiling` subsection immediately before editing, and
      confirm `git diff --stat` for the file is empty. *(completed)*
- [x] Append a single sentence to the subsection's final paragraph (the "same tool-`timeout`-
      parameter pairing applies to each call" paragraph) pointing at
      `external-process-wait.md`'s new `The 600s Ceiling Is Measured, Not Assumed` subsection as
      the provenance for the 600s figure and for the unraised-parameter diagnostic. Reference the
      **section title**, not a line number. *(completed: added as new trailing lines rather than
      rewriting the existing final line, so the diff carries zero removed lines)*
- [x] Do not touch the `## Canonical Agent-Contract Bullet (Generated-Copy Source)` section, the
      `### Copy this exact text` block, the `### Forbidden-Shape Lint Anchor` section, or the four
      Check K anchor lines (`NOTIFICATION_PHRASE`, `BACKGROUND_PHRASE_1`, `BACKGROUND_PHRASE_2`,
      `PROHIBITIVE_MARKER_PATTERN`). *(completed: verified untouched)*
- [x] Pin bullet byte-identity rather than asserting it: confirm `git diff -- <file>` contains no
      hunk inside the "Copy this exact text" block, and that
      `grep -c 'canonical idiom VERBATIM' <file>` is unchanged from its pre-edit value.
      *(completed: count unchanged at 1, diff has exactly one hunk outside that block)*
- [x] Grep the added line for task-number references and record-versioning phrasing, as in
      Phase 1. *(completed: zero matches)*

**Timing**: 0.3 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lake-build-guard.sh,test-lint-agent-contracts-await-notification.sh,test-lint-agent-contracts-handoff-section.sh,test-lint-agent-contracts-heartbeat.sh,test-lint-agent-contracts.sh,test-orchestrate-build-dispatch.sh` is the suite set `suite_selection_select` returns verbatim for this phase's single file, and the edit is one added prose sentence outside every lint-anchored block.

**Scope Hypothesis**: the edit is one added sentence in one paragraph, and the copied bullet pair
and all four Check K anchor lines are untouched. The implementer confirms it by checking that the
phase's `git diff` contains exactly one `+` hunk, located outside the "Copy this exact text"
block, before closing the phase.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` - appends one
  cross-reference sentence to the `### Sizing a Wait Near the Per-Call Ceiling` subsection's
  final paragraph; the generated-copy bullet block and Check K anchors untouched.

**Verification**:

- `git diff -- agent-system/extensions/core/context/patterns/bounded-build-waiter.md` shows one
  added hunk, outside the "Copy this exact text" block, with zero removed lines.
- `grep -c 'canonical idiom VERBATIM'` on the file is unchanged.
- All four Check K anchor lines still present and unmodified.

---

### Phase 3: Redeploy, prove the no-change half, and close [COMPLETED]

**Goal**: the source-store edits are deployed, the lint and gate set confirm nothing the plan
promised to leave alone has moved, the commit is scoped, and the no-change disposition is
recorded with its unactivated obligations named explicitly.

**Tasks**:

- [x] Redeploy from the source store: `bash agent-system/extensions/core/scripts/deploy-headless.sh`
      (the source store is the edit target; the deployed `.claude/` tree is regenerated, never
      hand-authored). *(completed: deploy landed; `.claude/` is gitignored in this repository, so
      no deploy path is tracked by git)*
- [x] Run `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` and confirm it
      passes, Checks H and K included. Record Check H's own verdict as the **pin** that the copied
      bullet is byte-identical across all carriers, rather than asserting byte-identity.
      *(completed: 377 passed, 12 warnings, 0 failed; Check H and Check K both all-PASS — Check
      H pins byte-identity of the copied bullet across all 24 carriers)*
- [x] Re-derive and record the carrier set rather than trusting a count:
      `cd agent-system/extensions && grep -rln 'bounded-build-waiter.md.*canonical idiom VERBATIM' --include='*.md' .`
      and `cd agent-system && grep -rln '600000' --include='*.md' extensions/`. Confirm the first
      returns the same 24 paths as before the change and the second the same nine.
      *(completed: re-derived counts are 24 and 9 respectively, matching the plan's expected
      sets exactly, including `lean/agents/lean-implementation-agent.md` in the nine)*
- [x] Run the named regression suites green:
      `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh`,
      `test-lint-agent-contracts-heartbeat.sh`, `test-lint-agent-contracts-handoff-section.sh`,
      `test-lint-agent-contracts-await-notification.sh`, and
      `test-validate-bounded-waiter.sh`. *(completed: all 5 green via run-all.sh --only)*
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store entry
      point: `agent-system/extensions/core/scripts/verify-deploy.sh`), resolving whichever entry
      point exists in this repository. *(deviation: altered — per the dispatch's Batch Gate
      Deferral directive for this final `Verification Tier: full` phase, this task's own
      narrowing invocations above (lint-agent-contracts.sh + the five named suites, which already
      are the suite set `suite_selection_select` returns for the two touched files) were run
      instead of the complete aggregator; the full set is deferred to the once-per-batch stage.
      Incidentally, `deploy-headless.sh`'s own internal fast-gate pass did run and reported 6 of
      41 checks failing — all on an unrelated orchestrator eager-load/context-budget ceiling
      (`skills/skill-orchestrate/SKILL.md` over its configured byte ceiling) that this phase's two
      markdown-only edits cannot have caused and do not touch; not independently chased here per
      the deferral directive)*
- [x] Commit with the scoped narrowing, not the full aggregator, naming only this task's own two
      source-store files plus the regenerated deploy paths and this task's `specs/**` artifacts:
      `bash .claude/scripts/git-commit-scoped.sh --message "task 515: complete implementation" --session <session_id> --task 515 -- <explicit file list>`.
      *(completed; see commit below)*
- [x] Record in the summary, explicitly and as outcomes rather than omissions: (a) the measured
      600s result and the refuted ~180s figure; (b) that no numeric correction was made anywhere
      and the propagation obligation never activated; (c) that the "exercise the newly documented
      poll idiom end to end" verification is inapplicable because no new idiom was documented,
      with the research phase's 590s/620s bracket standing as the live exercise of the existing
      idiom's boundary; (d) the two re-derived count corrections (24 carriers, nine
      `600000`-bearing files including `lean/agents/lean-implementation-agent.md`).
      *(completed: see summary artifact)*
- [x] Record a `kind: win` issue-log entry for the carried-figure refutation (a bracketed
      re-measurement overturning a carried incident figure before any edit was made), and an
      `issue` entry for anything that arose during the phases; non-fatal either way. *(completed)*

**Timing**: 0.7 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree from
  the source store.
- `specs/515_rebase_bounded_wait_guidance_on_180s_ceiling/summaries/01_rebase-bounded-wait-ceiling-summary.md` -
  the completion summary carrying the no-change disposition and its unactivated obligations.

**Verification**:

- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0, Checks H and
  K included.
- `bash .claude/scripts/verify-deploy.sh` (or the source-store entry point) passes every gate.
- The four `test-lint-agent-contracts*` suites and `test-validate-bounded-waiter.sh` are green.
- The carrier re-derivation returns the same 24 paths and the same nine `600000`-bearing files as
  before the change.
- `git log -1 --stat` shows a scoped commit containing only this task's own paths.

## Testing & Validation

- [ ] `lint-agent-contracts.sh` passes, Checks H and K included, with Check H standing as the pin
      that the copied bullet pair is byte-identical.
- [ ] `test-lint-agent-contracts.sh`, `-heartbeat.sh`, `-handoff-section.sh`,
      `-await-notification.sh` and `test-validate-bounded-waiter.sh` all green.
- [ ] `verify-deploy.sh` full gate set passes.
- [ ] Zero removed lines across both edited files' diffs; no numeric figure changed anywhere.
- [ ] Carrier re-derivation unchanged (24 bullet carriers, nine `600000`-bearing markdown files).
- [ ] No task-number reference and no record-versioning phrasing in any added hunk under
      `agent-system/**`.

## Artifacts & Outputs

- Two added prose hunks under `agent-system/extensions/core/context/patterns/` (one new
  subsection, one cross-reference sentence).
- The regenerated deployed `.claude/` tree.
- `specs/515_rebase_bounded_wait_guidance_on_180s_ceiling/summaries/01_rebase-bounded-wait-ceiling-summary.md`.
- One `kind: win` issue-log entry.

## Rollback/Contingency

Both edits are pure additions in two markdown files, landed in a single scoped commit, so
`git revert <sha>` followed by a redeploy restores the exact prior state — no data, schema, or
executable surface is involved. If `lint-agent-contracts.sh` Check H or K fails after either
edit, the correct response is to revert that phase's hunk rather than adjust the lint or the
copied bullet: the whole premise of this plan is that nothing the lint guards needs to change.
If the measurement itself is later contradicted by a reproducible sub-600s backgrounding **with
the parameter verifiably set to `600000` in the offending call**, that is a new record with its
own measurement, filed where it is observed — not a reason to edit the figures by hand.
