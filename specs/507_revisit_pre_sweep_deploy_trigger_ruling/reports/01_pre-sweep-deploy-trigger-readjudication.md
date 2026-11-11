# Research Report: Task #507

**Task**: 507 - Re-adjudicate the declined pre-postflight-sweep deploy trigger against a measured whole-cycle gate cost
**Started**: 2026-11-11T16:09:59Z
**Completed**: 2026-11-11T16:19:36Z
**Effort**: medium (adjudication against existing mechanism + corpus-wide measurement, no code changes)
**Dependencies**: 418, 420 (both completed/archived; territory edges fully discharged)
**Sources/Inputs**: codebase read (agent-system/extensions/core/**), git log (`--all`), specs/*/issues.jsonl and specs/archive/*/issues.jsonl corpus, specs/state.json and specs/archive/state.json
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The durable anchor subsection (`context/patterns/batch-orchestration-guardrails.md`, "A
  Pre-Postflight-Sweep Deploy Trigger: Evaluated, Intentionally Not Built") was re-derived
  against the current tree. Grounds (a) and (b) are **unchanged**: every named mechanism, file,
  and mechanical assertion still exists with the shape the record assumes.
- Ground (c)'s cost was priced not just against the two cited batches but against the full
  `"stale deploy or source-store boundary"` class across this repository's entire issues.jsonl
  corpus: **68 of 396 completed `meta` tasks (~17.2%)** have hit this exact completion-deploy-gate
  refusal at least once.
- Of 59 measurable paused-to-reconciled wall-clock deltas, **57 resolved within the SAME
  `/orchestrate` session at a median of 336s (~5.6 min, mean 415s, range 105s-2,726s)** —
  empirical support for the record's "largely empty cycle round trip" characterization.
- The 2 remaining deltas (28,387s and 287,534s) are **cross-session resume gaps**, not
  intra-session cycle-boundary delays — a Move 2/Move 3 trigger would have had zero effect on
  either, since no cycle of any kind runs between separate `/orchestrate` invocations. These two
  outliers alone account for roughly 94% of the total measured deferral time across all 59
  samples, meaning the pre-sweep trigger's addressable benefit is concentrated entirely in the
  much smaller, already-modest median-5.6-minute tail.
- **Recommended ruling: REAFFIRM.** The new, corpus-wide figures sharpen rather than overturn the
  original cost/benefit call. Exact amendment text is provided in Recommendations below, ready
  for the plan/implement phases to apply verbatim.

## Context & Scope

Task 507 is an adjudication, not a build order (see dispatch `.dispatch/6.md`). The durable
anchor is `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`'s
subsection "A Pre-Postflight-Sweep Deploy Trigger: Evaluated, Intentionally Not Built" (lines
1475-1511 at research time), which records a proposal to fire the redeploy once per batch,
immediately after Move 2's dispatches return and before Move 3's per-task postflight sweep
begins, as evaluated and deliberately left unimplemented on four recorded grounds (a)-(d). This
record is the "later pass re-examining this question" the subsection's own closing sentence
anticipates.

Scope, per the dispatch: (1) re-derive each of the four grounds against the current tree, (2)
price ground (c) against the measured evidence (two independently-measured batches: 1/7 and
4/8), deriving the firing frequency from logs/issue corpus rather than asserting it, and (3) rule
REAFFIRM or SUPERSEDE, preserving all four original grounds and adding a dated amendment note.
If SUPERSEDE, implementation is explicitly out of scope for this record. This research phase does
not edit `agent-system/**`; it determines the ruling and hands the plan/implement phases an
exact, ready-to-apply amendment.

## Findings

### Codebase Patterns

**Ground (a) re-derived — concurrency narrowing at the Move 2/Move 3 boundary: UNCHANGED.**
`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`'s "Move 2: Dispatch" section
still states "Issue every Agent call named by `dispatch[]` AND `aux_dispatch[]` in **one
message** (multiple messages force sequential execution)", and "Move 3: Postflight" still opens
with "**After ALL Agent calls from Move 2 complete** (never interleaved with dispatch), run this
once per `dispatch[]` row". This is exactly the structural premise ground (a) depends on: the
boundary between Move 2 and Move 3 is the one point in the cycle with zero in-flight dispatch,
narrowing the surviving hazard to the same cross-session mutex race the two existing trigger
sites (`orchestrate-cycle-plan.sh`'s Inter-Cycle Redeploy Checkpoint, `command-gate-out.sh`'s
single-task trigger) already accept. No change found.

**Ground (b) re-derived — the structural cost of a third genuine caller: UNCHANGED, and slightly
sharper.** `agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh` (lines
150-161) still hard-asserts "exactly the two known genuine caller sites
(orchestrate-cycle-plan.sh, command-gate-out.sh)" via a mechanical classify-then-verify pass over
every `.sh` file in `agent-system/extensions/*/scripts/**`. Running the classification logic
against the current tree confirms the set is still exactly `{orchestrate-cycle-plan.sh,
command-gate-out.sh}` — no third caller has appeared organically.

Every mechanism ground (b) names as needing re-threading is confirmed present and in the same
shape:
- **Baseline-relative branches** — `orchestrate-cycle-plan.sh` (~lines 880-915) still implements
  the (a)/(b)/(c) branch structure (deploy failed / new findings relative to baseline / clean or
  self-attributed), sourcing `scripts/lib/deploy-baseline-lib.sh`.
- **Confirmation/attribution filters** — `deploy_baseline_confirm_new_findings` and
  `deploy_baseline_self_attributable_findings` are both still invoked from
  `orchestrate-cycle-plan.sh`'s checkpoint body.
- **Idempotence guard** — `.deployed_critical_paths` (session-scoped, within-invocation dedup)
  is still read and appended to at the same call site (`orchestrate-cycle-plan.sh` lines 611,
  926, 1095, 1114, 1182).
- **Durable ledger** — `scripts/lib/deploy-ledger-lib.sh` (308 lines) still backs
  `deploy_ledger_decide`/`deploy_ledger_read`/`deploy_ledger_write`, consulted at
  `orchestrate-cycle-plan.sh` lines 1005-1044 only.

One sharpening: `command-gate-out.sh` was checked directly and does **not** source
`deploy-ledger-lib.sh` or call any `deploy_ledger_*` function — only `orchestrate-cycle-plan.sh`
carries the durable, cross-invocation ledger. A new call site at the Move 2/Move 3 boundary would
therefore need the **full** mechanism stack (baseline branches + confirmation/attribution +
idempotence guard + durable ledger), not whichever subset either existing site happens to carry —
the record's "re-threading ... onto the new call site" is, if anything, undersold rather than
overstated. Separately, Move 3's own shared implementation
(`orchestrate-cycle-postflight.sh`) runs once **per dispatched task**, not once per batch, so
hosting a once-per-batch trigger there (or at a new site between Move 2 and Move 3) would also
need fresh idempotence-within-cycle logic distinct from anything either existing site needs today
— a complication the original record did not have occasion to name because no such site existed
to inspect.

**Grounds (a)/(b) are also unaffected by the task's two declared dependencies.** Tasks 418
(`explicit_lint_fixture_test_subject_resolution`) and 420 (`warn_plan_size_exceeds_cycle_budget`)
are both `status: completed` in `specs/archive/state.json`; their territory edges against
`batch-orchestration-guardrails.md` are discharged. `git log -L` on the subsection's line range
confirms the last edit to these specific lines was commit `2e8124ef8` (task 442, the originating
record) — no subsequent edit by 418, 420, or any other task has touched grounds (a)-(d)'s text.

### External Resources — Corpus-Wide Frequency and Cost Measurement

**Frequency, derived (not asserted).** The two batches cited in the dispatch (1 of 7 tasks; 4 of
8 tasks) are real but small samples. Querying every `issues.jsonl` under `specs/**` and
`specs/archive/**` for `class == "stale deploy or source-store boundary"`, `phase == "implement"`,
with `what_happened` matching the completion-deploy-gate refusal text, found **68 distinct task
numbers** that hit this exact gate at least once. Cross-referencing those 68 task numbers against
`specs/archive/state.json`'s `completed_projects` and `specs/state.json`'s `active_projects`
shows **all 68 are `task_type: meta`**, out of a total population of 396 completed `meta` tasks
(389 archived + 7 still active-but-completed). **Derived frequency: 68/396 ≈ 17.2%** of completed
meta tasks have triggered this gate at least once across the repository's full history — a much
larger and more stable base than either single-batch sample (14% and 50%).

**Cost per occurrence, derived from git history.** Each gate-refusal commits as `task {N}:
orchestration paused (cycle {C})`, and the subsequent reconcile (when it lands within the same
`/orchestrate` session) commits as `task {N}: complete implementation (post-deploy reconcile)`.
Pairing these two commit messages by task number across the full `git log --all` history yielded
**59 measurable deltas** (of the 68 gated tasks; the remaining 9 either reconciled via a
differently-worded commit or are still pending). Distribution:

| Metric | All 59 | Excluding 2 cross-session outliers (57) |
|---|---|---|
| min | 105s | 105s |
| median | 336s | 335s |
| mean | 5,756s | 415s |
| max | 287,534s | 2,726s |

Representative same-session samples include the two batches cited in the dispatch: task 419
(161s), task 360 (174s), task 444 (173s), task 449 (169s), task 450 (168s) — all near the low end
of the 57-sample distribution, consistent with the deploy-ledger's `skip_attributed` fast path
applying.

**The two outliers are cross-session resume gaps, not cycle-boundary delays.** Task 416's delta
(287,534s ≈ 79.9 hours) and task 357's delta (28,387s ≈ 7.9 hours) correspond to a gap between
*separate* `/orchestrate` invocations — the session that produced the `orchestration paused`
commit ended, and reconciliation happened only when a human or scheduled process later re-invoked
`/orchestrate` on that task. A Move 2/Move 3-boundary trigger operates **only within a single
running session's own cycle loop**; it cannot fire between invocations, so it would have closed
neither gap. These two outliers nonetheless account for roughly 94% of the raw sum of all 59
measured deltas (315,921s of 337,328s total) — meaning essentially all of the historically
*large* deferral cost in this corpus is a cold-start/resume-latency phenomenon this proposal does
not and cannot address, not a property of the cycle-boundary mechanism being adjudicated.

## Recommendations

**Ruling: REAFFIRM**, with a dated amendment note. Weighing:

- Ground (a): structurally re-confirmed, unchanged.
- Ground (b): structurally re-confirmed, unchanged, and shown to be undersold rather than
  overstated (a new call site would need the *full* mechanism stack, since `command-gate-out.sh`
  lacks the durable ledger, plus fresh per-cycle idempotence logic `orchestrate-cycle-postflight.sh`
  does not need today).
- Ground (c): now priced with a corpus-wide figure (68/396 ≈ 17.2% of completed meta tasks) in
  place of two single-batch samples, and with a wall-clock cost breakdown (median 336s / mean
  415s for the 57 same-session resolutions) that *confirms* rather than contradicts "largely
  empty cycle round trip." The dominant share of historically-measured total deferral time (94%)
  is a cross-session gap this trigger is structurally incapable of closing, which further narrows
  its addressable benefit to the already-modest median-5.6-minute tail.
- Ground (d): the cost/benefit balance is unchanged by this new data — if anything, it tightens
  in favor of the existing verdict, since the structural build cost (ground b) is unchanged while
  the addressable portion of the removed cost (ground c) is now shown to be smaller, in
  proportion, than the qualitative description implied.

**Proposed amendment text** (for the plan/implement phases to apply verbatim as a new paragraph
appended after the existing "(d) The verdict." paragraph, preserving all four original grounds
unedited, per `rules/no-record-versioning-in-deliverables.md`'s dated cross-document/same-document
amendment-note exemption):

> **Amended 2026-11-11 — re-adjudicated against a measured whole-cycle gate cost, REAFFIRMED.**
> Grounds (a) and (b) were re-derived against the tree at amendment time and found unchanged:
> Move 2 still issues every dispatch in one message and Move 3 still runs only after all of them
> return; `test-lint-deploy-caller-wrap.sh` still asserts exactly two genuine
> `deploy-headless.sh` callers, and the baseline-relative branches, confirmation/attribution
> filters, `deployed_critical_paths` idempotence guard, and durable `deploy_ledger_decide` ledger
> ground (b) names are all still present and still specific to `orchestrate-cycle-plan.sh`'s call
> site — `command-gate-out.sh` carries no durable ledger at all, so a third call site would need
> the full stack, not a subset. Ground (c) was priced against the full
> `"stale deploy or source-store boundary"` class across this repository's issues.jsonl corpus,
> not only the two batches that prompted this re-examination: 68 of 396 completed `meta` tasks
> (~17.2%) have triggered this exact gate at least once. Of 59 measurable paused-to-reconciled
> deltas (paired by commit message across `git log --all`), 57 resolved within the SAME
> `/orchestrate` session at a median of 336s (mean 415s, range 105s-2,726s) — direct support for
> "largely empty cycle round trip." The remaining 2 deltas (28,387s and 287,534s) are
> cross-session resume gaps between separate `/orchestrate` invocations, not cycle-boundary
> delays within one running session; a Move 2/Move 3 trigger could not have closed either, yet
> they account for roughly 94% of the total measured deferral time in this corpus. The verdict
> stands: the addressable cost this proposal would remove is real but modest (median ~5.6
> minutes, ~17% of meta tasks), the structural cost of a third caller is unchanged, and the
> dominant share of historically-measured deferral time is a cross-session gap orthogonal to
> this proposal entirely.

## Decisions

- RULING: REAFFIRM the existing "Evaluated, Intentionally Not Built" verdict. The pre-sweep
  trigger remains unimplemented.
- The four original grounds (a)-(d) are preserved verbatim; only an appended, dated amendment
  paragraph is proposed (no rewrite of the existing prose, no supersession framing).
- This research record does not itself edit `batch-orchestration-guardrails.md`; the exact
  amendment text above is handed to the plan/implement phases for a single, low-risk file edit
  plus a documentation-gate run over the touched file, matching the dispatch's VERIFY
  instruction.

## Risks & Mitigations

- **Risk**: the 68-task frequency figure is drawn from `issues.jsonl` entries, which are
  self-reported by dispatched agents (per `context/formats/issue-log.md`), not a mechanically
  instrumented counter. **Mitigation**: the figure is corroborated by git-commit-message pairing
  (`orchestration paused (cycle N)` / `complete implementation (post-deploy reconcile)`) for 59
  of the 68, an independent data source from the same corpus, and the two numbers (68 issue
  entries, 59 git-commit-pair deltas plus 9 unpaired) are consistent with each other.
- **Risk**: the cross-session-gap finding (ground c's dominant-cost observation) could be
  misread as motivating a *different* mechanism (e.g., a cold-start resume optimization).
  **Mitigation**: this report deliberately does not propose such a mechanism and flags it only
  as a side observation — it is out of this record's scope, which is strictly the Move 2/Move 3
  pre-sweep trigger's adjudication, per the dispatch's own IF-SUPERSEDE scoping language.
- **Risk**: a future narrower window (e.g., only the most recent N tasks) might show a different
  frequency than the full-history 17.2%, if the gate's firing rate has drifted (e.g., due to the
  D6 closure's widened `deploy_pending_any` predicate making the gate fire on *more* paths than
  before that closure landed). **Mitigation**: not attempted here, since the dispatch's HARD
  CONSTRAINTS ask for a derived figure with a named source, not a trend line; the full-history
  figure is the most defensible single number and is named with its exact derivation above for
  any future re-check.

## Context Extension Recommendations

None. This is a `meta`-type adjudication record whose only durable-anchor target
(`batch-orchestration-guardrails.md`) already exists and is the subject of the proposed
amendment; no new context file is warranted.

## Appendix

**Search queries / commands used**:
- `grep -n "Pre-Postflight-Sweep Deploy Trigger" agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- `grep -n "deploy-headless\.sh\|baseline\|idempoten\|ledger\|confirmation\|attribution" agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
- `grep -n "deploy-ledger-lib\|deploy_ledger" agent-system/extensions/core/scripts/command-gate-out.sh` (no match — confirms the asymmetry noted above)
- `git log --oneline -L1475,1512:agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- `for f in $(find specs -name "issues.jsonl"); do jq -c 'select(.class=="stale deploy or source-store boundary")' "$f"; done` (74 raw matches, narrowed to 68 distinct `phase:"implement"` gate-refusal tasks)
- `git log --all --format="%H|%ad|%s" --date=iso-strict` paired against `task {N}: orchestration paused (cycle {C})` / `task {N}: complete implementation (post-deploy reconcile)` per task number (Python, see Findings table)
- `jq '[.completed_projects[]?] | length' specs/archive/state.json` (422); `jq -r '.completed_projects[]?.task_type' specs/archive/state.json | sort | uniq -c` (389 meta)

**References**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (subsection under amendment)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Move 2, Move 3)
- `agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh`
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`, `command-gate-out.sh`
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh`, `deploy-ledger-lib.sh`
- `specs/archive/442_deploy_before_implement_postflight_to_avoid_cycle_cost/summaries/01_pre-postflight-deploy-evaluation-record-summary.md` (prior art)
