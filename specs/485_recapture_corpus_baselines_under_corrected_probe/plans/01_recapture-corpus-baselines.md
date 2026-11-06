# Implementation Plan: Task #485

- **Task**: 485 - Recapture the corpus baseline figures the net-deletion acceptance criterion is measured against, now that the measurement instrument has been corrected
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None live. The record that fixed the probe (`specs/429_script_inventory_undercounts_untracked_files`, `completed`) is an *input* whose summary carries the exposure measurement this plan consumes, not a blocker. The parent record (`specs/328_systematic_script_and_test_corpus_efficiency`) is `completed` as of commit `fd86bf491`, so its plan files are no longer another task's live territory — the condition that made 429 decline to edit them has lapsed.
- **Research Inputs**: None. No research dispatch preceded this plan; the dispatch description carries the defect, the measured evidence, the affected-file list and the acceptance bar, and the remaining facts were established by direct reads of the probe, the two plan files, and git history at plan time (recorded under "Plan-Time Measurements" below). Prior measured evidence is drawn from `specs/429_script_inventory_undercounts_untracked_files/summaries/01_untracked-corpus-enumeration-summary.md`.
- **Artifacts**: plans/01_recapture-corpus-baselines.md (this file)
- **Standards**:
  - `.claude/context/formats/plan-format.md`
  - `.claude/context/standards/status-markers.md`
  - `.claude/context/standards/artifact-management.md`
  - `.claude/context/standards/tasks.md`
  - `.claude/rules/source-store-deploy-boundary.md`
- **Type**: meta
- **Lean Intent**: false

## Overview

The standing corpus probe `script-inventory.sh` enumerated its corpus from `git ls-files` alone,
so every figure it emitted was blind to untracked-but-not-ignored in-corpus files. That
enumeration now unions tracked with untracked and discloses the contribution via a trailing
`untracked=N` field. This plan determines, figure by figure, which of the baseline and running-net
figures frozen in the parent record's two plan files were captured under the old behaviour, states
the correction's magnitude explicitly (old, new, delta — including an explicit null result where
that is what the measurement shows), and restates the parent's running net against whatever
baseline survives the determination.

The work is measurement and adjudication, not refactoring. Every edit lands in `specs/**` markdown
— the two parent plan files plus this plan's own recording sections. No source-store file, no
deployed file, and no script is touched, so `rules/source-store-deploy-boundary.md` imposes no
redirect here.

### Research Integration

No research report accompanies this round. The determination rests on four classes of directly
verifiable evidence, each established at plan time and recorded below so the implementer confirms
rather than rediscovers them:

1. **The fix's landing instant.** `git log` on `agent-system/extensions/core/scripts/script-inventory.sh`
   places the union commit at `9341cfe7d` (2026-11-04 16:42:21 -0800), with the deploy of that
   change at `55875fdad` (2026-11-04 16:57:15 -0800). Every probe reading taken before that instant
   is tracked-only by construction; every reading after it is union-based — *provided* the copy
   actually invoked carried the fix, which is a separate question Phase 2 settles per figure.
2. **The one directly measured exposure.** The fixing record measured the live delta across the fix
   at a single instant: tracked-only `scripts=241 lines=96148 test_suites=174 test_lines=84259
   md_files=931 md_lines=232238` against union-based `scripts=241 lines=96208 test_suites=174
   test_lines=84369 md_files=932 md_lines=232270 untracked=1`. The portion attributable to the fix
   was `md_files +1 / md_lines +32`; the `lines`/`test_lines` deltas beyond that were concurrent
   sibling activity between the two measurement points, not an effect of the fix. That is the only
   instant at which the exposure was ever measured directly, and its magnitude is 32 lines.
3. **The live reading at plan time**, taken from the source copy:
   `script-inventory: scripts=249 lines=97567 test_suites=183 test_lines=87535 md_files=949
   md_lines=232244 cost_per_assertion_ms=191.5 untracked=0`. The untracked contribution to the
   corpus is **currently zero**, so a corrected reading taken now is numerically identical to a
   tracked-only one taken now.
4. **The parent's acceptance figure does not come from the probe at all.** The parent's
   `plans/03_markdown-corpus-consolidation.md` reports two instruments at its Phase 20 close and
   designates Instrument B — a mechanical sum of `git show --numstat` over the 77 commits matching
   `^task 328`, classified by the same three-population rule — as authoritative for the acceptance
   figure (NET-PROD +498, NET-TEST +1,402, NET-MD −681, NET-TOTAL +1,219). Instrument B never
   consults the probe and is immune to its enumeration by construction. Instrument A (the live
   probe reading, raw NET-TOTAL +20,729) is recorded there but explicitly disclaimed as not the
   acceptance figure. This asymmetry is the single most consequential fact for this record's scope,
   and Phase 3 must state it rather than leave a reader to infer that a probe correction could move
   the parent's verdict.

### Prior Plan Reference

No prior plan for this record. The parent record's own two plan files are the *subject* of this
work, not a template for it; their effort calibration and phase structure have no bearing here.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no roadmap consultation was performed.

## Plan-Time Measurements (established 2026-11-05)

Recorded here so each figure below is a hypothesis the implementer confirms against a live read,
never a fact inherited on trust. Every one of these drifts.

```
Probe fix (union + disclosure) committed:   9341cfe7d  2026-11-04 16:42:21 -0800
Probe fix deployed:                         55875fdad  2026-11-04 16:57:15 -0800
Parent Phase-1 baseline capture commit:     12a65c492  2026-10-16  (pre-fix by ~19 days)
Parent Phase-12.2 probe extension:          495b8db4f  2026-11-05 11:11:28 -0800
Parent Phase-20 final accounting commit:    4c2fd41db  2026-11-05 19:57:12 -0800  (post-fix)
Parent record completion commit:            fd86bf491  2026-11-05

Recorded probe lines in plans/01_corpus-consolidation-net-deletion.md:  5  (lines 138, 146, 150, 159, 168)
Recorded probe lines in plans/03_markdown-corpus-consolidation.md:      7  (lines 206, 214, 218, 227, 236, 251, 265)
Plan-level baseline tables (3 figures each):                            2  (01 lines 132-134; 03 lines 197-200)
In-corpus *.sh/*.md files first committed 2026-10-16..2026-10-17:      13
Live untracked in-corpus file count:                                    0
```

A detail that matters to the determination method: the parent's own Phase 12.2 extended
`--size-line` with a `cost_per_assertion_ms` field on 2026-11-05, and the 429 fix had already
appended `untracked=N` on 2026-11-04. The **field set** of a recorded probe line therefore dates
that line independently of any commit timestamp, and Phase 2 uses exactly that. The parent's
recorded Phase-20 line (`scripts=249 lines=97567 test_suites=183 test_lines=87535 md_files=949
md_lines=232244`) carries *neither* field even though both were in the probe by the time that
phase committed — which is a question to settle, not a discrepancy to wave through.

## Corrected Reading of Record (captured Phase 1)

Captured by running `bash agent-system/extensions/core/scripts/script-inventory.sh --size-line`
once; this is the single "new figure" instant every later phase cites.

```
script-inventory: scripts=249 lines=97567 test_suites=183 test_lines=87535 md_files=949 md_lines=232244 cost_per_assertion_ms=191.5 untracked=0
```

- **stderr**: silent on both the source and deployed copies — no untracked-path warning, consistent
  with `untracked=0`.
- **Observed field order**: `scripts, lines, test_suites, test_lines, md_files, md_lines,
  cost_per_assertion_ms, untracked` — `untracked=N` is the **final** field on the line, confirming
  the probe's own header contract holds even after the parent's Phase 12.2 inserted
  `cost_per_assertion_ms` ahead of it.
- **Host-load conditions at capture**: `up 3 days 14:31, 1 user, load average: 1.26, 1.32, 0.94`.
- **Source vs. deployed agreement**: the source copy
  (`agent-system/extensions/core/scripts/script-inventory.sh`) and the deployed copy
  (`.claude/scripts/script-inventory.sh`) emit **character-identical** `--size-line` output at this
  instant — no divergence to record.

This reading is numerically identical to the Plan-Time Measurements "live reading at plan time"
figure above (`scripts=249 lines=97567 test_suites=183 test_lines=87535 md_files=949
md_lines=232244 cost_per_assertion_ms=191.5 untracked=0`), confirming the corpus has not drifted
between plan time and this capture. **The untracked contribution right now is zero**, so this
corrected reading is numerically identical to what a tracked-only reading would show today — the
correction, if any, applies only to the *historical* baselines Phase 2 and Phase 3 examine, not to
today's live figure.

## Goals & Non-Goals

**Goals**:
- A per-figure determination, stated either way, for every baseline and running-net figure recorded
  in `plans/01_corpus-consolidation-net-deletion.md` and `plans/03_markdown-corpus-consolidation.md`:
  captured under the undercounting behaviour, or not.
- The correction's magnitude reported explicitly as old figure, new figure, delta — including an
  explicit, reasoned null result where the untracked contribution at capture time was zero or
  negligible.
- The parent record's running net-deletion figure restated against whatever baseline the
  determination leaves standing, with the instrument each restated figure depends on named.
- An honest account of what is and is not retroactively knowable: an untracked file that was never
  committed leaves no trace in git, so the exposure at a past instant is boundable, not exactly
  recoverable, and the plan says so in the artifact rather than presenting a bound as a measurement.

**Non-Goals**:
- Re-running, re-deriving or re-litigating the parent record's consolidation work, its targets, or
  its verdict. If the corrected baseline leaves the verdict unchanged (the expected outcome, since
  the authoritative figure is git-numstat-derived), this record says so and closes.
- Fixing the sibling probe `context-reachability.sh`, which the fixing record identified as carrying
  the identical tracked-only enumeration. That is a separate exposure and belongs in its own record.
- Changing `script-inventory.sh` or any other script, source-store file, or deployed file.
- Reconciling the parent's `plans/01_...` plan-level `- **Status**: [IMPLEMENTING]` marker against
  the superseding `plans/03_...` plan's `[COMPLETED]`. Noted at plan time as an observation; it is a
  status-hygiene matter outside this record's chartered scope and is reported, not fixed.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The exposure at the Phase-1 capture instant is presented as an exact measurement when it is only a bound, giving a false sense of precision to the corrected baseline | H | M | Phase 3 is required to report an interval (lower bound 0, upper bound from the git-reconstruction method) and to label it as a bound in the artifact text wherever the corrected figure appears; a bound is never written into the baseline table as if it were a reading |
| A figure is declared unaffected on timestamp evidence alone when the copy actually invoked was a stale pre-fix deployed copy | H | M | Phase 2's determination test is the recorded line's **field set**, not its timestamp: a line lacking `untracked=` was not produced by a union-based copy, whatever its date. Timestamp is corroborating evidence only |
| Correcting a baseline silently absorbs ~19 days of unrelated concurrent sibling drift into the correction, overstating the fix's magnitude | H | M | Phase 3 attributes only the untracked-reconstruction figure to the fix and records all other movement as drift, following the parent's own established practice of never absorbing drift into a re-baseline; the fixing record's own measurement is cited as the precedent for separating the two |
| The restated net reads as a change to the parent's acceptance verdict when the authoritative instrument never touched the probe | H | M | Phase 3 states the Instrument A / Instrument B asymmetry explicitly before any restatement, and Phase 4 annotates the restated figures with the instrument each depends on |
| Editing the parent record's plan files collides with concurrent work | M | L | The parent is `completed` (`fd86bf491`) and none of the six concurrent siblings named in this dispatch's territory block declares any `specs/328_**` path. Phase 4 nonetheless re-reads each file immediately before editing and stages only its own explicit file list |
| The determination is performed over a stale reading because the live corpus drifts during the dispatch | M | M | Phase 1 captures the reading of record once, verbatim with every field, and every later phase cites that captured line rather than re-running the probe and silently comparing against a different instant |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel. Phase 1 (capture the live corrected reading)
and Phase 2 (date each recorded figure from git history and its own field set) consult disjoint
evidence and have no ordering constraint between them; Phase 3 needs both.

---

### Phase 1: Capture the Corrected Reading of Record [COMPLETED]

**Goal**: One verbatim, fully-fielded corrected reading, taken once, that every later phase cites
as the single "new figure" side of the correction — so the determination is never performed against
two different instants of a drifting corpus.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/script-inventory.sh --size-line` and record the
      output line **verbatim, every field included**, into this plan's own
      "Corrected Reading of Record" section (create it below this plan's Plan-Time Measurements
      block). Do not trim `cost_per_assertion_ms` or `untracked=`; the field set is load-bearing
      evidence for Phase 2. *(completed)*
- [x] Capture the probe's stderr separately. A non-zero untracked count prints a warning naming each
      untracked path; record either that path list or the explicit fact that stderr was silent.
      *(completed: silent on both copies)*
- [x] Confirm `untracked=N` is present and is the **final** field on the line, as the probe's own
      header contract states. The parent's Phase 12.2 inserted `cost_per_assertion_ms` into this
      same line after the disclosure field was added, so the contract's "final field" clause is
      worth confirming rather than assuming; record the observed field order. *(completed: confirmed
      final field, order recorded)*
- [x] Record the host-load conditions at capture time (`uptime`), matching the parent's own practice
      of qualifying a probe reading taken on a loaded host. *(completed)*
- [x] Note in the recording whether the deployed copy (`.claude/scripts/script-inventory.sh`) and the
      source copy agree at this instant, by reading `--size-line` from both. A disagreement is
      itself a finding and must be recorded, not reconciled away. *(completed: character-identical)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The live reading at plan time was `scripts=249 lines=97567 test_suites=183
test_lines=87535 md_files=949 md_lines=232244 cost_per_assertion_ms=191.5 untracked=0`, and the
untracked contribution is zero. Confirm by running the probe; treat the live output as
authoritative and this figure as the estimate it is. A non-zero `untracked=N` at capture time does
not invalidate anything in this plan — it changes only the "new figure" side of Phase 3's
correction, which is why it is captured before any determination is made.

**Tier Justification**: The only edit is to this record's own plan file under `specs/**`, so no
suite maps to it (the `__FULL_SWEEP__` sub-case (a)); the covering check is
`bash .claude/scripts/validate-artifact.sh specs/485_recapture_corpus_baselines_under_corrected_probe/plans/01_recapture-corpus-baselines.md plan`
alongside a diff read-through of the recorded block.

**Files to modify**:
- `specs/485_recapture_corpus_baselines_under_corrected_probe/plans/01_recapture-corpus-baselines.md` - add the "Corrected Reading of Record" section holding the verbatim line, the stderr disclosure, the observed field order, and the host-load note

**Verification**:
- `script-inventory.sh --size-line` exits 0 and emits exactly one line.
- The recorded line in this plan is character-identical to the probe's output, including every
  trailing field.
- `bash .claude/scripts/validate-artifact.sh specs/485_recapture_corpus_baselines_under_corrected_probe/plans/01_recapture-corpus-baselines.md plan` passes.

---

### Phase 2: Date Every Recorded Figure and Classify It by Instrument [NOT STARTED]

**Goal**: A complete, enumerated determination table covering every baseline and running-net figure
in the two parent plan files, each row stating the instrument that produced the figure, the instant
it was captured, and the verdict — captured under the undercounting behaviour, or not — with the
evidence for that verdict named.

**Tasks**:
- [ ] Enumerate every recorded figure in both files. Do not work from this plan's plan-time counts;
      re-derive the list live, because the files may have drifted. At minimum sweep for: the
      `script-inventory: scripts=… lines=…` probe lines, the `Figure | Population | Phase 1 baseline
      | Target` baseline tables, every `NET-PROD`/`NET-TEST`/`NET-MD`/`NET-TOTAL` cumulative figure
      stated in a re-measurement paragraph, the Plan-Time Measurements blocks, the markdown
      duplication-census tables, and the Phase-20 Instrument A and Instrument B blocks.
- [ ] Classify each figure by the instrument that produced it. Three classes, and the class decides
      the verdict:
      - **probe-derived** (`script-inventory.sh`, either mode) — exposed to the defect if captured
        before the fix;
      - **git-history-derived** (`git show --numstat` / `git diff --numstat` over named commits or
        files) — immune by construction, because each diff is against its own parent and no
        enumeration of the working tree is involved;
      - **other-instrument** (the duplication census, `comm -12` shared-line counts, per-file
        `wc -l` over an explicit file list, the harness-duplication tallies). For each
        other-instrument figure, read the instrument's own enumeration and state whether it shares
        the tracked-only `git ls-files` pattern. A `find`-based or explicit-file-list instrument
        carries no exposure; a `git ls-files`-based one carries the identical exposure and must be
        reported as such even though fixing it is out of scope here.
- [ ] For each probe-derived figure, determine the probe version in effect at its capture instant.
      The primary test is the recorded line's **field set**: a line carrying no `untracked=` field
      was not produced by a union-based copy, and a line carrying no `cost_per_assertion_ms` field
      predates the parent's Phase 12.2 extension (or was recorded non-verbatim — which is itself a
      recordable finding, since a trimmed line cannot be used as evidence of what the probe emitted).
      Corroborate with `git log` on the probe file against the figure's capture commit.
- [ ] Settle the Phase-20 Instrument A line specifically. Its six figures are identical to the live
      reading, it was committed roughly 27 hours after the fix was deployed, and yet it carries
      neither the `untracked=` nor the `cost_per_assertion_ms` field. Determine which of these holds,
      and state which: the reading came from a copy that carried the fix and the fields were trimmed
      when recording; or it came from a copy that did not carry the fix. Name the evidence
      (`git show 4c2fd41db` on the probe's then-current state, the deploy's own timestamp, the
      parent's Phase-20 closing note). If the evidence does not decide it, say that plainly and
      carry the ambiguity into Phase 3's bound rather than picking the convenient reading.
- [ ] Write the determination table into this plan's own artifact, one row per figure, with columns
      `Figure | Location | Instrument | Capture instant | Verdict | Evidence`. A figure that turns
      out to be unaffected gets a row stating so — the acceptance criterion requires the
      determination either way, so an unaffected figure is never simply omitted.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Roughly 12 probe-derived lines (5 in `plans/01_...`, 7 in `plans/03_...`), 6
plan-level baseline-table figures, and on the order of 15-25 derived cumulative net figures,
against a small number of other-instrument blocks. Of these, the figures captured on 2026-10-16
through the revision round are expected to fall on the pre-fix side and the Phase-20 blocks on the
post-fix side. Confirm by the live enumeration in this phase's first task and treat any count
stated here as the estimate it is; the determination table's own row count is the figure of record.

**Tier Justification**: The only edit is to this record's own plan file under `specs/**`, with no
mapped suite (`__FULL_SWEEP__` sub-case (a)); the covering check is
`bash .claude/scripts/validate-artifact.sh specs/485_recapture_corpus_baselines_under_corrected_probe/plans/01_recapture-corpus-baselines.md plan`
plus a read-through confirming every enumerated figure has exactly one table row.

**Files to modify**:
- `specs/485_recapture_corpus_baselines_under_corrected_probe/plans/01_recapture-corpus-baselines.md` - add the determination table and the per-instrument exposure findings

**Verification**:
- Every figure found by the live enumeration appears in the determination table exactly once,
  including figures determined to be unaffected.
- Every row names its instrument and its evidence; no row's verdict rests on a capture timestamp
  alone where the recorded line's field set was available.
- The Phase-20 Instrument A question is answered, or its ambiguity is explicitly recorded as
  unresolved with the reason.
- `bash .claude/scripts/validate-artifact.sh specs/485_recapture_corpus_baselines_under_corrected_probe/plans/01_recapture-corpus-baselines.md plan` passes.

---

### Phase 3: Bound the Phase-1 Baseline's Exposure and State the Correction [NOT STARTED]

**Goal**: The magnitude of the correction to the one baseline every parent net is measured against
— stated as old figure, new figure, delta — together with an explicit statement of what is
retroactively knowable and what is only boundable, and an explicit null result if that is what the
evidence shows.

**Tasks**:
- [ ] State the irrecoverability constraint first, in the artifact, before any number: an untracked
      file that was never subsequently committed leaves no trace in git history, so the untracked set
      at a past instant cannot be recovered exactly. What follows is a bound, and it is labelled as
      one everywhere it appears.
- [ ] Derive the upper bound of the untracked-at-capture set for the Phase-1 baseline commit
      (`12a65c492`, pre-fix): enumerate the in-corpus `*.sh` and `*.md` files whose first-ever commit
      is strictly after that commit, via `git log --diff-filter=A --name-only` restricted to
      `agent-system/extensions/**/*.sh` and `agent-system/extensions/**/*.md`. That set is a
      superset of what could have been untracked at capture.
- [ ] Narrow the superset by plausibility and state the narrowing rule explicitly. A file first
      committed days later did not exist on disk at capture; a file created by one of the parent's
      own later phases did not exist at capture by construction (the parent's Phase 3 created
      `lib/lint-corpus-scan-lib.sh`, for instance). Keep only files whose creation plausibly
      preceded the capture instant, name them, and sum their line counts at their first-committed
      state (`git show <sha>:<path> | wc -l`), not their current state.
- [ ] Report the correction per population, as old figure / new figure / delta:
      - NET-PROD baseline (recorded: 232 scripts, 90,568 lines)
      - NET-TEST baseline (recorded: 160 suites, 76,832 lines)
      - NET-MD baseline (recorded: 927 files, 229,217 lines)
      If the narrowed set is empty, report a delta of 0 for that population and say plainly that the
      baseline is confirmed sound. A null result is the outcome, not a failure to produce one.
- [ ] Corroborate the bound against the only directly measured exposure the system has: the fixing
      record's own across-the-fix measurement, whose fix-attributable component was `md_files +1 /
      md_lines +32` with zero contribution to either `*.sh` population, and this record's Phase-1
      reading of `untracked=N`. State the resulting order of magnitude against the parent's −10,000
      floor.
- [ ] Attribute everything outside the narrowed untracked set to concurrent sibling drift, never to
      the fix, following the parent's own established practice of accounting for drift as drift
      rather than absorbing it into a new baseline.
- [ ] State the direction of the residual error explicitly, since the dispatch turns on direction
      rather than magnitude. A baseline understated by untracked blindness makes every later
      probe-delta net *less* negative than the truth when the later reading is union-based, and a
      *later* tracked-only reading understates insertions and so biases the net favourably. Say
      which case each affected figure falls into, so the sign of the residual bias is on the record.
- [ ] State the Instrument A / Instrument B asymmetry as a finding in its own right: the parent's
      authoritative acceptance figure is the git-numstat sum over its own commits, which never
      consults the probe and cannot be moved by this correction in either direction. Bound the
      correction's reach to Instrument A's raw figure and to the baseline-versus-target framing.

**Timing**: 1 hour

**Depends on**: 1, 2

**Verification Tier**: local

**Scope Hypothesis**: 13 in-corpus files were first committed in the 2026-10-16..2026-10-17 window
at plan time, and most or all are creations of the parent's own later phases or of concurrent
sibling work that postdates the capture instant — so the narrowed plausible untracked-at-capture set
is expected to be empty or near-empty, and the correction to all three baselines immaterial or
exactly zero. Confirm by running the enumeration and the narrowing rule in this phase's own tasks;
the `--diff-filter=A` output is the figure of record, not this estimate.

**Tier Justification**: The only edit is to this record's own plan file under `specs/**`, with no
mapped suite (`__FULL_SWEEP__` sub-case (a)); the covering check is
`bash .claude/scripts/validate-artifact.sh specs/485_recapture_corpus_baselines_under_corrected_probe/plans/01_recapture-corpus-baselines.md plan`
plus a read-through confirming every reported delta carries its old and new figures.

**Files to modify**:
- `specs/485_recapture_corpus_baselines_under_corrected_probe/plans/01_recapture-corpus-baselines.md` - add the exposure bound, the per-population correction (old / new / delta), the direction-of-error statement, and the instrument-asymmetry finding

**Verification**:
- All three baseline populations have a stated old figure, new figure and delta, with a delta of 0
  stated explicitly where that is the result.
- The bound is labelled as a bound, with the irrecoverability constraint stated before the numbers.
- The narrowing rule is written down and each excluded file's exclusion reason is attributable to it.
- The direction of the residual error is stated per affected figure class.
- `bash .claude/scripts/validate-artifact.sh specs/485_recapture_corpus_baselines_under_corrected_probe/plans/01_recapture-corpus-baselines.md plan` passes.

---

### Phase 4: Apply the Determinations to Both Parent Plan Files [NOT STARTED]

**Goal**: Both parent plan files carry, per figure, either a confirmation that the figure is sound
or the corrected figure; and the parent's running net-deletion figure is restated against the
baseline the determination leaves standing, with each restated figure's instrument named.

**Tasks**:
- [ ] Re-read each parent plan file immediately before editing it, per the dispatch's territory
      directive, and confirm no foreign modification has landed since Phase 2's enumeration. Record
      the confirmation. If a foreign commit or foreign uncommitted modification to either file is
      observed, stop and report it rather than proceeding.
- [ ] In `plans/01_corpus-consolidation-net-deletion.md`: annotate the Running Net Figures baseline
      table and each recorded probe line with its determination. Where a figure is confirmed sound,
      say so against the evidence; where it shifts, give the corrected figure and keep the original
      alongside it so the correction is auditable rather than silently overwritten.
- [ ] In `plans/03_markdown-corpus-consolidation.md`: the same annotation pass, extended to the
      Phase-20 Instrument A and Instrument B blocks. Instrument A's raw NET-TOTAL is restated
      against the corrected baseline if the baseline shifted; Instrument B is annotated with the
      explicit statement that it is probe-independent and therefore unchanged.
- [ ] Restate the parent's running net-deletion figure. Name, for each of NET-PROD, NET-TEST, NET-MD
      and NET-TOTAL, the instrument the restated figure rests on, so a reader cannot mistake a
      probe-delta figure for the acceptance figure or vice versa.
- [ ] Where the correction is immaterial, state that plainly in both files — including the measured
      order of magnitude against the −10,000 floor — rather than leaving the reader to infer
      soundness from an absent correction.
- [ ] Record this record's own outcome in this plan file: the correction's magnitude, whether it was
      material, and the resulting disposition of the parent's acceptance determination.
- [ ] Stage only the explicit file list this phase touched — never a directory or glob pathspec — and
      review `git status --short` and `git diff --staged` before committing.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: Three files are touched (the two parent plan files and this one), and the
edits are annotation and restatement rather than restructuring, so neither parent file's phase
structure, phase headings, or phase status markers change. Confirm by `git diff --stat` on the three
files at phase close and by checking that the phase-heading set of each parent file is unchanged
before and after.

**Tier Justification**: Every touched path lies under `specs/**` with no mapped suite
(`__FULL_SWEEP__` sub-case (a)); the covering check is
`bash .claude/scripts/validate-artifact.sh <path> plan` run against each of the three plan files,
plus the diff read-through the `local` row prescribes.

**Files to modify**:
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/01_corpus-consolidation-net-deletion.md` - per-figure determination annotations and corrected figures where a shift is established
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` - the same, plus the restated running net and the Instrument A / Instrument B annotations
- `specs/485_recapture_corpus_baselines_under_corrected_probe/plans/01_recapture-corpus-baselines.md` - record this record's own outcome and disposition

**Verification**:
- Every figure in the Phase 2 determination table has a corresponding annotation in its parent plan
  file, including those determined sound.
- The parent's running net figure is restated with each population's instrument named.
- `bash .claude/scripts/validate-artifact.sh` passes for all three plan files.
- Each parent file's phase-heading set is byte-identical before and after this phase's edits.
- `git diff --staged` shows only the three enumerated files.

---

### Phase 5: Final Gate Set and Close [NOT STARTED]

**Goal**: The complete repository gate set observed green over the finished work, and the record
closed with the correction's magnitude and its disposition stated in the summary.

**Tasks**:
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. Record the gate count,
      failure count and result line. No `--skip-slow`, no `--only-gate` subset: this is the final
      phase, and a narrowed run is not evidence for it.
- [ ] Record the gate run's own corpus line verbatim, including its `untracked=` field, as a second
      independent reading of the corrected probe alongside Phase 1's — and note any divergence from
      Phase 1's reading as drift, with the elapsed interval.
- [ ] Re-validate all three plan files with `bash .claude/scripts/validate-artifact.sh <path> plan`.
- [ ] Write the completion summary to
      `specs/485_recapture_corpus_baselines_under_corrected_probe/summaries/01_recapture-corpus-baselines-summary.md`,
      leading with the correction's magnitude (old, new, delta per population) and stating plainly
      whether the result was material or null.
- [ ] Carry forward, as a follow-up note in the summary rather than as work in this record, the
      sibling exposure in `context-reachability.sh`'s own tracked-only enumeration and the parent
      plan-level status-marker observation recorded under Non-Goals.

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: full

**Files to modify**:
- `specs/485_recapture_corpus_baselines_under_corrected_probe/summaries/01_recapture-corpus-baselines-summary.md` - the completion summary

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` completes with 0 failures, and its gate count and result
  line are recorded.
- The gate run's corpus line is recorded verbatim with its `untracked=` field.
- `bash .claude/scripts/validate-artifact.sh` passes for all three plan files.
- The summary states the correction's magnitude as old / new / delta per population and names the
  result material or null explicitly.

---

## Testing & Validation

- [ ] `script-inventory.sh --size-line` exits 0, emits exactly one line, and that line carries
      `untracked=N` as its final field.
- [ ] Every figure enumerated from the two parent plan files has exactly one determination-table row
      and one corresponding annotation in its parent file.
- [ ] All three baseline populations carry an old figure, a new figure and a delta — with 0 stated
      explicitly where that is the result.
- [ ] `bash .claude/scripts/validate-artifact.sh <path> plan` passes for all three plan files.
- [ ] Each parent plan file's phase-heading set is unchanged by this record's edits.
- [ ] `bash .claude/scripts/verify-deploy.sh` runs green over the finished work.

## Artifacts & Outputs

- `specs/485_recapture_corpus_baselines_under_corrected_probe/plans/01_recapture-corpus-baselines.md`
  — this plan, extended in place with the Corrected Reading of Record, the determination table, the
  exposure bound and per-population correction, and this record's own outcome.
- `specs/485_recapture_corpus_baselines_under_corrected_probe/summaries/01_recapture-corpus-baselines-summary.md`
  — the completion summary, leading with the correction's magnitude.
- Annotated and, where a shift is established, corrected figures in
  `specs/328_systematic_script_and_test_corpus_efficiency/plans/01_corpus-consolidation-net-deletion.md`
  and `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md`.

## Rollback/Contingency

Every edit is confined to three markdown files under `specs/**`, with no script, source-store,
deployed, or state-file change, so reverting is a per-file git operation with no downstream
consequence. If a phase must be abandoned mid-way, revert that phase's own commit with
`git revert <sha>` — the per-phase commit granularity makes each phase independently revertible,
and no later phase depends on an earlier one's file content beyond what is recorded in this plan.

Two contingencies have pre-decided dispositions rather than open outcomes:

- **The bound cannot be narrowed to a defensible figure.** If the plausibility narrowing in Phase 3
  cannot distinguish the untracked-at-capture set from ordinary later creation, report the
  unnarrowed upper bound and the measured corroborating figures, label the baseline's comparability
  as unverifiable rather than corrected, and annotate the parent files to that effect. An honest
  "not retroactively determinable, bounded above by N lines" is a valid outcome; a fabricated exact
  correction is not.
- **The correction is immaterial or exactly zero.** This is the expected outcome on the plan-time
  evidence and it closes the record normally, with the null result stated explicitly in both parent
  files and in the summary. It is not a partial or blocked outcome.
