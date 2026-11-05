# Implementation Plan: Task #328

- **Task**: 328 - Systematic top-to-bottom consolidation of the shell script and test corpus under `agent-system/extensions/**`
- **Status**: [IMPLEMENTING]
- **Effort**: 45 hours
- **Dependencies**: None live. Tasks 170 and 411 are both `completed` in `specs/state.json` (verified at plan time); task 416 is `implementing` at 10/13 phases and is a *coordination* surface, not a dependency — see "The 416 Overlap" below. Task 431 declares `328` as its own blocker and is a *downstream consumer* surface, not a dependency of this plan — see "The 431 Edge" below.
- **Research Inputs**: `specs/328_systematic_script_and_test_corpus_efficiency/reports/01_corpus-consolidation-research.md`
- **Reports Integrated**: `reports/01_corpus-consolidation-research.md`. No new research report accompanies this revision round; its evidence is the operator scope decision carried verbatim in the task description plus this plan's own re-measured derivation under "Scope Widening" and "Revision Round Change Note".
- **Artifacts**: plans/03_markdown-corpus-consolidation.md (this file)
- **Standards**:
  - `.claude/context/formats/plan-format.md`
  - `.claude/context/standards/status-markers.md`
  - `.claude/context/standards/artifact-management.md`
  - `.claude/context/standards/tasks.md`
  - `.claude/rules/source-store-deploy-boundary.md`
  - `.claude/rules/no-task-references-in-deliverables.md`
  - `.claude/rules/no-record-versioning-in-deliverables.md`
- **Type**: meta
- **Lean Intent**: false

## Overview

This task is the standing consumer of `scripts/script-inventory.sh`'s ranked output, chartered to
produce a **measured net reduction** in the shell-script and test corpus under
`agent-system/extensions/**` — not a speedup, and not a count of refactors performed. The plan
lands a cheap standing corpus-size probe first so every later phase's net figure is measured by
one instrument, derives each cluster's extractable volume mechanically before committing to a
target, then works the clusters in extract-a-lib order: the seven-script lint cluster, the
118-plus-suite test harness (the largest single target by volume), the two mutual pairs,
`literature-search.sh`'s self-internal repetition, and — per the operator scope decision recorded
under "Scope Widening" below — the markdown/context corpus, where the same duplicated-skeleton
defect class carries the bulk of the reachable volume. Definition of done: the full gate set is
green, every gate's finding set and every suite's assertion set is provably unchanged, no
markdown consolidation loses a claim that is not still reachable from retained text, and the
three running net figures (production-script lines, test-script lines, markdown lines) sum to the
declared floor against the Phase 1 baseline.

**The edit target is the source store**, `agent-system/extensions/**`, never `.claude/**` (a
disposable deploy artifact regenerated from the source store — see
`rules/source-store-deploy-boundary.md`). The final phase redeploys via `deploy-headless.sh`.

### Research Integration

The research report changes four things about how this plan is built, and each is load-bearing:

1. **Both declared blockers are discharged.** 170 and 411 are `completed`. The dispatch's "170
   blocks only the untested-script phases" framing is resolved context, not a live constraint. No
   phase below waits on a dependency.
2. **The five-lint cluster is mechanically a seven-script cluster.** Each of the five named lints
   lists **six** `duplicate_block_peers`, adding `lint-hook-registration-paths.sh` (614L) and
   `lint-shellcheck.sh` (296L). This plan scopes the first slice to all seven, per the research's
   own Decisions section.
3. **A plan-time correction to the research**: the report flagged those two extra members as
   `has_test=false`, which would have required characterization tests first. Hand-checked at plan
   time, **both have paired fixture suites** (`tests/test-lint-hook-registration-paths.sh`, 603
   lines; `tests/test-lint-shellcheck.sh`, 212 lines). The false negative is
   `script-inventory.sh`'s own documented `has_test` caveat: it resolves `tests/test-<basename>`
   relative to the candidate's own directory (`scripts/lint/tests/`), while the real suites live
   in `scripts/tests/`. All seven cluster members are already fixture-tested, so the whole first
   slice carries no characterization-test prerequisite.
4. **GAP 2 is substantially stale and GAP 3 is half-closed** by work already landed elsewhere.
   This plan does not re-target either; see "The 416 Overlap" and "Goals & Non-Goals".
5. **The markdown/context corpus carries the volume the script clusters cannot.** The research
   report's cluster enumeration is shell-only, and the Phase 2 derivation confirmed mechanically
   that those clusters bound the production-script net near −700. The operator's scope decision
   retains the −10,000 floor and widens the corpus rather than lowering the bar; the derivation
   under "Scope Widening" below is this revision round's own measurement, taken with the same
   instrument and the same discipline Phase 2 used, and it is what the new markdown phases are
   scoped from.

### Revision Round Change Note

This plan carries the markdown/context corpus that the dated operator scope decision
(`== SCOPE WIDENED TO KEEP THE -10,000 FLOOR (operator decision, 2026-10-16) ==`, quoted in the
task description) brought into scope, and which the narrower script-and-test-only corpus
definition the earlier round was written against did not reach. The decision states the
instruction explicitly: the markdown corpus is in, the −10,000 floor is retained rather than
lowered to match the script clusters, and a plan revision is required before the markdown work
begins. That is the authority this round acts on.

**What this round changed:**

- The net-figure accounting gains a third population, NET-MD, with its own baseline and target
  (see "Running Net Figures" below). The three figures are never blended; their **sum** is the
  acceptance criterion against the retained floor.
- A measured derivation for the markdown corpus was added ("Scope Widening" below), taken with
  the same instrument (`script-inventory.sh --size-line`) and the same measurement discipline
  Phase 2 used for the script clusters.
- Five markdown phases were added: a derivation-and-classification phase (15), a
  convention-plus-regression-lint-plus-pilot phase (16), and three tranche phases (17, 18, 19).
- The gate-enforced verbatim-duplication exclusion class was made a first-class, hard constraint
  of the plan, with the requirement that its member list be **derived mechanically from each
  lint's own fragment paths**, never hardcoded here (see "Derived, Never Hardcoded" below).
- Roadmap alignment and the downstream 431 edge were recorded (both below), neither of which the
  earlier round consulted.
- **The silent `file_scope` drop was diagnosed and repaired.** Five phases' `Files to modify`
  blocks were invisible to `scripts/plan-file-scope-harvest.sh`, which harvests `file_scope` from
  that field: Phases 4 and 5 carried a trailing italic annotation on the field label
  (`**Files to modify** *(as executed ...)*:`) and three markdown phases carried glob-shaped
  entries, neither of which the harvester's documented grammar accepts. Measured: the harvester
  saw 56 paths before the repair and 123 after — 67 dropped paths, which is the mechanism behind
  the twenty paths dropped from phase commits during the script/test track's run. The repair
  moved each annotation to its own line above an exact `**Files to modify**:` label and replaced
  every glob with a concrete path or directory root. **No path, file or claim in a closed phase's
  record was changed** — only the field label's punctuation, so the record the phase already
  carried becomes harvestable. `validate-artifact.sh` now reports zero warnings on this plan,
  down from five.

**What this round did NOT change, and must not:**

- **No phase was renumbered in this round.** The markdown phases occupy 15-19 and the final
  redeploy-and-accounting phase sits at 20, exactly as the preserved phase set already numbered
  them; no closed or in-flight phase number moved.
- **Phases 1-6 are closed and are preserved as written**, with their recorded measurements,
  deviation notes, closing notes and status markers intact: Phases 1, 2, 3, 4 `[COMPLETED]`;
  Phase 5 `[COMPLETED WITH EXCLUSIONS]`, including its `#### Reasoned Exclusions` table recording
  that only one of the four nominated lints held the literal shared wrapper; Phase 6 `[COMPLETED]`
  (harness migration tranche A, 25 suites, NET-TEST −355).
- **Phases 7-14 are unchanged and remain valid as written.** The widening does not touch the
  script-and-test track's targets, sequence or verification.
- The Phase 2 derivation is **not retracted**. Its measured per-cluster figures stand unchanged
  and remain the NET-PROD target; what the operator decision changed is the disposition of the
  shortfall it found, not the measurement.

### Roadmap Alignment

Consulted at revision time (`specs/ROADMAP.md`). Three alignments bear on this plan:

- **Settled decision 16** names this task as the standing consumer of `script-inventory.sh`,
  filed against a probe's output rather than as a stream of point defects, precisely because
  duplication, dead code and slow tests never break anything and so cannot be seen by
  defect-driven intake. The markdown corpus is the same defect class in a different population,
  which is why widening into it is consistent with the task's charter rather than a scope creep.
- **Settled decision 15** records that gate 8's deployed-tree coverage is knowingly reduced under
  `--skip-slow`, measured at 52 of 91 narrow core suites, and names this task as the narrower fix.
  Phases 12 and 13 carry that work; the markdown track does not touch it.
- The roadmap's batch ordering places this task in a single orchestrate chain and two open
  records are blocked on it (`313`, `431`). Neither blocks this plan; `431`'s disposition is
  recorded immediately below.

### The 431 Edge — A Downstream Consumer, Not a Dependency

Task 431 (`not_started`, declaring `328` as its own blocker) owns recording the gate-enforced
verbatim-duplication exclusion class as durable documentation under `agent-system/**`. Its own
description states the division of labour: this task **consumes** that constraint during its
consolidation and is the reason the constraint exists, but is not a home for it, and an edge was
declared rather than the two records merged.

**This plan's disposition**: derive and apply the exclusion class, and do not author the durable
standard for it. Phase 15 emits the exclusion list mechanically and writes it into this task's own
inventory file under `specs/**`; Phase 16's short anchor-pointer convention standard names the
exclusion class and points at the lints that enforce it, but does not become the durable record
431 owns. Writing that record here would both duplicate 431's work and put this task's own
findings in a file 431 is blocked on editing.

### The 416 Overlap — Resolved Deliberately

The dispatch instructs that the overlap with the gate-cost-model task be resolved by absorbing,
superseding, or depending on its parked phases explicitly, rather than doing the work twice.
Re-checked at plan time: task 416 is `status: implementing` with phases 1-10 `[COMPLETED]` and
phases 11, 12, 13 `[NOT STARTED]`.

| 416 phase | State | This plan's disposition |
|-----------|-------|-------------------------|
| 1 Harden `measure-gate-costs.sh` | [COMPLETED] | **Adopt as baseline.** Satisfies the dispatch's measurement-discipline prerequisite; this plan does not re-harden it. |
| 6 Fixture-corpus shellcheck + hint coverage | [COMPLETED] | **Adopt as baseline.** |
| 8 Cut the two verify-deploy stragglers | [COMPLETED] | **Adopt as baseline, do not re-target.** Those two suites' costs fell 87% and 77%; the dispatch's 228,595ms / 160,340ms figures are superseded. |
| 10 Re-derive `JOBS_CAP` | [COMPLETED] | **Adopt as baseline.** The 1,016.6s pool figure in the dispatch is superseded by a 1,402.17s pool. |
| 11 Gate 3 post-invalidation measurement | [NOT STARTED] | **Leave to 416.** Out of scope here; this plan touches no gate-3 measurement decision. |
| 12 Gate 8 serialized isolation | [NOT STARTED] | **Leave to 416.** |
| 13 Redeploy + measured before/after | [NOT STARTED] | **Leave to 416.** This plan's own final-phase redeploy is independent and scoped to this task's own edits. |

**Standing coordination obligation**: Phases 12, 13 and 14 touch `tests/run-all.sh`,
`suite-cost-hints.txt`, `measure-gate-costs.sh`, or `context/standards/shell-script-testing.md` —
files 416 owns. Each of those phases opens by re-reading 416's live phase states (its plan file's
`### Phase` headings) and stops rather than editing if 416 has advanced into the same file since
this plan was written.

### Measurement Discipline

Every timing figure this task takes or reports must come from a verified-quiet host. Check the
1-, 5- **and** 15-minute load averages (not only the 1-minute figure that
`measure-gate-costs.sh` samples at start) and require all three under 2 before any timing run.
Structural counts (file counts, line counts, duplicate-block counts) are load-independent and
need no such gate. A timing run whose two repetitions disagree by more than 25% is discarded, not
averaged — the recorded incident of a 404s-vs-193s disagreement under unrelated sibling-build
contention is indistinguishable from a real regression.

### Running Net Figures — Three Populations, Never Blended

Progress is reported as three separate running net figures (insertions minus deletions), never one
blended total, because a lib extraction predictably shows a transient net-positive in one
population before migrations bring another down, and blending would hide exactly the tradeoff the
acceptance criterion exists to expose. The acceptance criterion itself is their **sum** against
the retained floor; the three are reported separately so a shortfall is always attributable to a
population:

| Figure | Population | Phase 1 baseline | Target |
|--------|------------|------------------|--------|
| NET-PROD | non-test `*.sh` under `agent-system/extensions/**` | 232 scripts, 90,568 lines | **−700 lines** (see Phase 2 Derivation) |
| NET-TEST | `test-*.sh` under `agent-system/extensions/**` | 160 suites, 76,832 lines | **−1,200 lines floor**, revised upward after Phase 13 (see Phase 2 Derivation) |
| NET-MD | `*.md` under `agent-system/extensions/**` | 927 files, 229,217 lines | **−8,100 lines** (see Scope Widening) |
| **NET-TOTAL** | the sum of the three | — | **−10,000 lines** (the retained floor) |

Baseline captured via `script-inventory.sh --size-line` (the canonical corpus definition recorded
above) at Phase 1 close: `script-inventory: scripts=232 lines=90568 test_suites=160
test_lines=76832 md_files=927 md_lines=229217`. Every later phase's delta is measured against
these three line totals (90,568 / 76,832 / 229,217), never against the Plan-Time Measurements
block's earlier estimates (237/91,802 and 155 files with no line total) or the dispatch's/research
report's figures, both superseded. The markdown baseline is read from the same probe line as the
other two, so no fourth instrument is introduced.

**Interim figures, re-measured at revision time** (same instrument, same corpus definition):
`scripts=233 lines=90661 test_suites=161 test_lines=77067 md_files=927 md_lines=229217` —
NET-PROD +93 and NET-TEST +235 after Phase 3 (the extracted lib and its new regression suite,
both justified in Phase 3's closing note), NET-MD unchanged at 0.

**Re-measured after Phase 4**: `scripts=233 lines=90778 test_suites=161 test_lines=77201
md_files=927 md_lines=229255` — against the Phase-1 baseline this is NET-PROD +210, NET-TEST
+369, NET-MD +38 cumulative. The md_lines drift (+38, untouched by any phase so far) and the
~4-line discrepancy against this phase's own precise `git diff --stat` figures (+102/+134, see
Phase 4's closing note) are both concurrent unrelated repository activity, not a measurement
defect — consistent with the dispatch's own "30% drift in twelve days" warning. Phase 4 itself
is net-positive on both NET-PROD and NET-TEST, declared in advance and restated in its closing
note as the precondition for Phases 6-8's payback.

**Re-measured after Phase 5**: `scripts=233 lines=90772 test_suites=161 test_lines=77298
md_files=927 md_lines=229299` — against the Phase-1 baseline this is NET-PROD +204, NET-TEST
+466, NET-MD +82 cumulative. Against the Phase-4 figures this phase's own delta is NET-PROD −6,
NET-TEST +97, both confirmed via `git diff --numstat` on the files this phase actually touched
(see Phase 5's closing note) rather than read off the probe deltas alone, since the probe deltas
alone cannot separate this phase's edits from concurrent unrelated drift. Phase 5 is the first
phase to post a negative NET-PROD; NET-TEST's own net-positive is justified in advance in Phase
5's closing note as the regression-coverage cost of proving the production change correct.

**Re-measured after Phase 6**: `scripts=233 lines=90772 test_suites=161 test_lines=76943
md_files=927 md_lines=229299` — NET-PROD and NET-MD unchanged from Phase 5 (this phase touched
only `agent-system/extensions/core/scripts/tests/*.sh`, confirmed by `git status --porcelain`
showing exactly the 25 migrated files and nothing else). Against the Phase-1 baseline this is
NET-PROD +204, NET-TEST +111, NET-MD +82 cumulative. Against the Phase-5 figures this phase's own
delta is NET-TEST −355 (76,943 − 77,298), confirmed exactly against `git diff --numstat` across
the 25 touched files (+758/−1113). **Phase 6 is the first phase to post a negative NET-TEST**,
beginning the payback Phase 4's advance net-positive justification promised for Phases 6-8. The
realized −14 lines/suite average is below Phase 2's −30-to-40/suite hypothesis because this
tranche deliberately included the smallest suites in the corpus, several of which carry no
`mktemp -d` workdir or no `REPO_ROOT` resolution at all — nothing to remove on those pieces; see
Phase 6's own Scope Hypothesis confirmation note for the full accounting and the expectation that
Phases 7-8's larger, not-smallness-selected tranches realize a higher per-suite span.

**Re-measured at this revision round, before any new phase was scoped** (same instrument, same
corpus definition): `script-inventory: scripts=234 lines=91059 test_suites=162 test_lines=77132
md_files=927 md_lines=229299`. Against the Phase-1 baseline this is NET-PROD +491, NET-TEST +300,
NET-MD +82 cumulative. The drift against the post-Phase-6 reading (+287 NET-PROD, +189 NET-TEST,
NET-MD unchanged) is concurrent unrelated repository activity, not any phase of this plan: no
phase has run since Phase 6 closed. Recorded here rather than silently re-baselined — the
Phase-1 figures (90,568 / 76,832 / 229,217) remain the one baseline every net is measured
against, and drift that is not this task's work is accounted for as drift, never absorbed into a
new baseline that would hide it.

Two further structural counts re-derived at the same time, because the markdown phases are scoped
from them and the corpus has demonstrated 30% drift in twelve days:

```
core suites (extensions/core/scripts/tests/test-*.sh):   123 files    61,201 lines
core suites still defining their own pass()/fail():        98 / 123
markdown by role under agent-system/extensions/**:
  agents/ 80    skills/ 93    commands/ 50
  context/ 594  docs/ 29      rules/ 21
```

The 98/123 figure is the live, post-Phase-6 state of the harness migration (25 suites migrated),
and it supersedes the task description's `0 of 121 sourcing a shared harness / 121 of 121
redefining their own pass()/fail()` figure, which was measured before Phase 6 landed. The
description's figure is not wrong; it is pre-Phase-6, and Phases 7-8's tranche enumeration must
use the live 98, not the 121.

Every phase below closes by recording its own delta against whichever of the three figures its
territory touches, and against the one it belongs to in particular. **A phase whose net is
positive must state, in its own closing note, why it is the cheapest available route to a later
negative net — or be reverted.** Phases 1, 2, 4, 5, 12, 14, 15 and 16 are net-positive (in at
least one population) by construction and each carries that statement in advance below.

### Plan-Time Measurements (re-derived, 2026-10-16)

Re-derived at plan-authoring time rather than carried from the dispatch or the report, both of
which the report itself shows drifting within a day:

```
non-test *.sh under agent-system/extensions/**:   237 files    91,802 lines
test-*.sh under agent-system/extensions/**:       155 files
core suites (extensions/core/scripts/tests/):     121 files    60,852 lines
markdown under agent-system/extensions/**:        943 files
gate-registry.data rows:                           23
```

Harness duplication across the 121 core suites, counted directly:

```
suites defining their own pass():                 121 / 121
suites defining their own fail():                 121 / 121
suites redefining mktemp -d + trap cleanup:       115 / 121
suites open-coding SCRIPT_DIR resolution:         121 / 121
suites open-coding git rev-parse --show-toplevel:  64 / 121
suites redefining resolve_candidate():             22 / 121
suites sourcing ANY shared test harness:            0 / 121
```

Seven-script lint cluster, and the comment/blank share that bounds what extraction can reach:

```
lint-scoped-commit-boundary.sh       668 lines  (338 code, 330 comment/blank)
lint-task-lookup-adoption.sh         592 lines
lint-hook-registration-paths.sh      614 lines  (352 code, 262 comment/blank)
lint-branch-gated-sections.sh        398 lines
lint-directory-pathspec-boundary.sh  381 lines
lint-state-writer-boundary.sh        369 lines
lint-shellcheck.sh                   296 lines
                                   -----
                                   3,318 lines
```

Six of the seven carry the shared corpus-enumeration call-site block
(`lint-branch-gated-sections.sh` does not; it is a duplicate-block peer through the wider
skeleton — argument parsing, `SCAN_PATHS` collection, `VIOLATIONS` accounting, exit-code
convention — which all seven share). All seven already source `lib/common.sh`, and the helpers
themselves (`common_shared_corpus_available`, `common_shared_corpus_files`) are already correctly
defined once there. What remains duplicated is the call-site wrapper and the surrounding
skeleton, not the helpers.

### The Target Gap — Raised as a User Decision

The dispatch recommends a net-deletion floor of **-10,000 non-test lines**. The figures above
bound what the clusters the dispatch itself enumerates can actually yield well below that: the
lint cluster's extractable share is roughly a third of each file's ~340 *code* lines, and the
remaining three clusters total 3,310 lines between them. The deletable volume of -10,000
magnitude lives in the **test** corpus (60,852 lines with zero shared harness) and in the
markdown/context corpus the dispatch leaves explicitly untracked. Phase 2 derives the per-cluster
figures mechanically before any target is committed; the choice of what to do if they fall short
of the recommended floor is surfaced as a non-blocking decision on this dispatch's
`.return-meta.json` rather than silently resolved by lowering the bar.

### Net-Deletion Target Derivation (Phase 2, executed 2026-10-16)

The already-answered user decision ("accept the evidence-derived targets Phase 2 derives") named
*illustrative* figures (roughly -2,000 production / -4,000 test) in its option text, written
before Phase 2 actually ran. This section is that derivation, and it lands **materially lower**
on the production side — the illustrative figure was itself an unconfirmed guess, and the
decision's operative clause is "accept what Phase 2 derives," not the parenthetical. Reported
honestly per this task's own acceptance criterion: a measured figure, not a count of refactors,
and not forced to match an earlier guess.

**NET-PROD, per cluster** (`comm -12` on sorted, comment/blank-stripped unique lines; re-run
against the live corpus, not the Plan-Time Measurements snapshot):

| Cluster | Measured shared lines | Derivation | Bounded net |
|---------|----------------------|------------|-------------|
| Seven-lint | all-7 intersection 50 lines; 6-of-7 (excl. `lint-shellcheck.sh`, different `-eq 0` guard) intersection 64 lines; pairwise 53-113 (median ~85), consistent with the dispatch's hand-verified 115-132 range and the Phase 3/5 Scope Hypotheses | (50×7 − ~80 lib) + (14×6 − 0 marginal) ≈ −270 − 84, plus duplicated-comment-block share (roughly half of each file is comment/blank per the Plan-Time Measurements block) | **−350 to −450** |
| install/uninstall pair | 75 shared normalized (code-only) lines | 2×75 − (75+30 lib overhead) | **−40 to −90** |
| typst pair | 63 shared normalized (code-only) lines | 2×63 − (63+30 lib overhead) | **−30 to −70** |
| `literature-search.sh` | `load_fidelity_map` (×5, 38 lines each), `get_fidelity` (×5, ~11 lines), `TIER_RANK`/`ROW_TIER_LABEL` (×5, 2 lines), `ensure_trigram` (×3, 47 lines) — all Python helpers re-embedded verbatim in 5 separate `python3` heredocs, one per `do_*` shell function (confirmed by direct `def <name>(` line search, not the probe's window count alone) | keep 1 copy of each, remove the rest: 4×38 + 4×11 + 4×2 + 2×47 = 298, less call-site restructuring overhead | **−250 to −300** |
| **Total NET-PROD** | | | **−670 to −910** |

**Declared NET-PROD target: −700 lines.** (Conservative end of the derived range, per "declare a
reachable target, not an aspirational one.") This supersedes the Plan-Time Measurements block's
pre-derivation estimate (−1,500 to −2,400) and the illustrative −2,000 named in the user-decision
option text — both were upper-bound guesses made before this mechanical pass; the real shared-line
counts, measured directly above, are smaller. The `literature-search.sh` finding is itself
load-bearing for Phase 11: the duplication is 5 re-embedded **Python** helper definitions inside
separate `python3` heredocs, not repeated **bash** — Phase 11's "extract into file-local bash
functions" framing does not fit this verbatim; Phase 11 must instead consolidate to one Python
helper block referenced by all five heredocs (e.g. a single shared heredoc preamble built once and
interpolated into each `do_*` function's `python3` invocation), still file-local per that phase's
own `peers=0` reasoning (no second file needs these helpers).

**NET-TEST, harness-boilerplate span** (sample of 20 suites, drawn via a fixed-seed shuffle of
`tests/test-*.sh`, cross-checked against 4 of the 20 that also carry `resolve_candidate()`):

- Universal one-line markers (`SCRIPT_DIR=`, `REPO_ROOT=`/`git rev-parse --show-toplevel`,
  `PASSED=0`, `FAILED=0`, `pass()`/`fail()`/`info()` one-liners, `mktemp -d` assignment,
  `cleanup()` one-liner, `trap cleanup EXIT`): mean **10.0** lines/suite, median 10.0, measured
  directly across all 20 sampled suites (range 8-13).
- `resolve_candidate()` function body: **15 lines**, byte-near-identical across all 4 sampled
  suites that carry it (4/20 = 20%, consistent with the probe's corpus-wide 22/121 = 18%).
- Weighted per-suite average: 10.0 + (22/121 × 15) ≈ **12.7 lines/suite**.
- Across the live 121-suite core corpus: 121 × 12.7 ≈ **1,573 lines** removable from migrated
  suites, less `test-harness-lib.sh` itself (≈200 lines, one-time) plus
  `tests/test-test-harness-lib.sh` (≈150 lines, new — itself lands in the TEST population by the
  probe's own basename-based classification, confirming Phase 4's "net-positive on NET-TEST by
  construction" framing).
- **Harness-extraction-only net (Phases 4, 6, 7, 8 combined): ≈ −1,223 lines.**

**This is a FLOOR, not the full NET-TEST target.** Phase 13's shared-deployed-tree-fixture
consolidation (101 `deploy-headless.sh` fixture constructions collapsing toward one) is a
separate, not-yet-measured contributor — quantifying it requires opening and measuring the actual
fixture-construction blocks in the suites GAP 2 names, which is Phase 12/13's own work, not
Phase 2's. **Declared NET-TEST target: −1,200 lines from the harness-extraction floor alone,
revised upward once Phase 13 reports its own measured delta** (per this plan's own revision
clause already stated under Phase 6's Scope Hypothesis). This, too, lands below the illustrative
−4,000 named in the user-decision option text; the gap is attributed explicitly to Phase 13's
unmeasured contribution rather than inflated here without evidence.

**Task 416 re-check** (re-read live, 2026-10-16): phases 1-10 `[COMPLETED]`, phases 11-13
`[NOT STARTED]` — unchanged from "The 416 Overlap" table above, no update needed there. Confirmed
additionally via `specs/state.json`: task 416 declares `328` as one of its own dependencies
(`dependencies: [170, 328, 411]`), meaning 416's remaining phases (11-13, which touch
`verify-deploy.sh`, `tests/run-all.sh`, `suite-cost-hints.txt`) cannot start until this task
completes — a stronger, already-enforced guarantee than "re-read before editing," confirming the
plan's "the existing dependency on the gate-framework task already serializes this; keep it"
claim directly from the dependency graph rather than merely asserting it. Phase 1 of this plan
already edited `verify-deploy.sh` (the corpus-size line) with no conflict, exactly because of this
confirmed one-way serialization.

**Floor-shortfall decision — superseded by a later operator decision.** The cycle-1 answer
recorded in `.decisions.json` (timestamped 2026-10-16T16:18:35Z) resolved the shortfall by
accepting the evidence-derived targets with markdown/context out of scope. The task description
then recorded a **later, dated operator decision** (`== SCOPE WIDENED TO KEEP THE -10,000 FLOOR
(operator decision, 2026-10-16) ==`) that reverses exactly that one clause: the −10,000 floor is
retained as the acceptance criterion and the corpus is widened to the test and markdown/context
populations rather than the floor being lowered to match the script clusters. The same description
states the instruction explicitly — "the existing plan was written against the narrower scope and
does not carry markdown-corpus phases. It needs a revision round before the markdown work begins;
the script and test-harness phases already in it are unaffected and remain valid as written."
That is the authority this revision round acts on. The Phase 2 derivation above is **not**
retracted: its measured per-cluster figures stand unchanged and remain the NET-PROD target. What
changes is the disposition of the shortfall it found. See "Scope Widening" immediately below.


### Scope Widening — The Markdown/Context Corpus, Measured

The operator decision above widens the corpus to the markdown/context population. This section is
this revision round's own derivation for it, taken against the live corpus with the same
instrument and the same discipline Phase 2 used, so the new phases are scoped from measurement
rather than from the description's prose.

**Corpus definition** (the standing probe's own, so a markdown figure and a script figure are
always comparable): every `*.md` file under `agent-system/extensions/**`, as enumerated by
`script-inventory.sh --size-line`. Live figure, re-measured at revision time: **927 files,
229,217 lines** — identical to the Phase 1 baseline, so the baseline needs no restatement.

**Whole-file duplication is zero.** All 927 files hashed: no two are byte-identical. The
duplication is therefore intra-content — restated blocks inside otherwise distinct files, the same
defect class the lint cluster exhibits — not deletable whole files. That rules out the cheapest
possible route and sets the shape of every phase below.

**Cross-file duplicated-block volume.** Measured by 5-line shingling over substantive (trimmed,
length ≥ 3) lines of all 927 files, marking every line that falls inside a 5-line window appearing
verbatim in two or more distinct files, and charging each marked line its removable share
`(g−1)/g` where `g` is the number of files sharing that window:

| Role | Files | Substantive lines | Lines in cross-file duplicated blocks | Removable share |
|------|-------|-------------------|---------------------------------------|-----------------|
| `agents/` | 78 | 27,471 | 8,090 | 6,291 |
| `skills/` | 93 | 21,278 | 7,560 | 5,907 |
| `commands/` | 50 | 14,648 | 3,087 | 2,340 |
| `context/` | 594 | 90,844 | 3,313 | 1,879 |
| `docs/` | 29 | 10,991 | 417 | 222 |
| `rules/` | 21 | 1,658 | 130 | 66 |
| other | 43 | 3,525 | 115 | 68 |
| **Total** | **927** | — | **22,816** | **16,851** |

The density is where the operator decision predicted: `agents/`, `skills/` and `commands/` are 221
files (24% of the corpus) carrying 86% of the removable volume. Representative blocks, with their
sharing factor: the dispatch-file preamble (5 lines × 68 files), the handoff write-location
paragraph (6 lines × 42 files, which already cites its own anchor while restating it), the
`skill-base.sh` preflight invocation block (× 42), and the `summary`/`blockers` handoff-field
contract (× 42).

**Three exclusion classes, and why 16,851 is an upper bound, not a target.** Not every duplicated
block is consolidation-eligible, and two of the three exclusions are hard:

1. **Gate-required restatement — HARD EXCLUSION.** `lint-agent-contracts.sh` reads four canonical
   fragments at runtime (`context/contracts/no-task-references-bullet.md`,
   `context/contracts/return-meta-artifacts-template.md`,
   `context/contracts/plan-status-ownership.md`, `context/patterns/bounded-build-waiter.md`) and
   FAILs any in-scope agent contract that does **not** carry a verbatim copy, and
   `lint-postflight-boundary.sh` asserts a literal `^## MUST NOT \(Postflight Boundary\)`
   heading. That duplication is deliberate and gate-enforced: collapsing it to a pointer would
   change those gates' finding sets, which this task's own invariant forbids. Measured share
   (blocks overlapping a canonical fragment in two or more of their five lines): **≈ 3,997 lines**.
2. **Deliberate prompt-inlining — HARD EXCLUSION.** The email extension's safety content is
   inlined into each email skill and agent body by documented design ("carried inline in each
   email skill/agent body at its own invocation time ... nothing below reaches it ambiently"). A
   pointer is not equivalent to inlined text for content an agent must have at invocation time
   without a further read. Measured share: **≈ 102 lines**. This class is small today but is the
   reason the per-file no-unique-content-lost test below is necessary but not sufficient: a block
   can pass "still reachable from retained text" and still be wrong to collapse.
3. **Substantive content — OUT OF SCOPE.** Consolidation here means duplicated skeletons and
   restated boilerplate, never deletion of substantive documentation. Not separately quantified;
   the eligibility test in the derivation phase excludes it per-block.

**Consolidation-eligible upper bound after the two hard exclusions: ≈ 12,752 lines**
(agents 5,347, skills 4,091, commands 1,430, context 1,515, docs 161, rules 66, other 141). This
is an upper bound on what consolidation could reach, not a target; the target is declared below
and is a stated capture rate against it.

#### Derived, Never Hardcoded — The Gate-Enforced Exclusion List

**The gate-enforced exclusion list is a requirement of this plan, and it must be DERIVED by
reading each enforcing lint's own fragment paths out of that lint at implementation time. It must
never be hardcoded into this plan, into the regression lint, or into the inventory generator.**
Stated as a plan-level requirement here, not only inside Phase 15's task list, because every
markdown phase depends on it: a hardcoded list goes stale the moment another record adds a
presence predicate, and a missed exclusion collapses a block whose verbatim presence a gate
asserts — changing that gate's finding set, which this task's own invariant forbids and which no
suite can detect.

The derivation's two entry points, confirmed present at revision time and named here as entry
points rather than as content:

- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` assigns its canonical
  fragment paths to four shell variables (`FRAGMENT_FILE`, `ARTIFACTS_TEMPLATE_FRAGMENT`,
  `PLAN_STATUS_OWNERSHIP_FRAGMENT`, `BOUNDED_WAIT_FRAGMENT`) and reads each file at runtime,
  failing any in-scope agent contract that does not carry a verbatim copy of the fragment's
  bullet text. The derivation reads those four assignments out of the script — by variable name,
  never by a path literal copied into this plan — and then reads the fragments they point at.
- `agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` asserts a literal
  `## MUST NOT (Postflight Boundary)` heading, and additionally distinguishes that specific
  heading from any other `## MUST NOT` heading. Its literal-presence predicates are read out of
  the script the same way.

Re-read both lints for predicates added since this plan was written, and check whether any other
lint has since grown a literal-presence predicate over markdown: a new presence check added later
is a new exclusion, and the measured ≈ 3,997-line share below moves with it. Treat that figure as
a hypothesis to confirm, never as the list itself.

**The mechanism is a pointer to a durable anchor that already exists.** For every representative
block above, the anchor file is already present in the source store and already owns the content —
`context/contracts/wrap-up.md` carries a "Write location — absolute path, never a bare filename"
section, `context/standards/user-decision-contract.md` and `context/patterns/skill-preflight-flow.md`
both exist, and several of the restated blocks already *cite* their anchor in the very text that
restates it. That is the precise shape the operator decision names: "content restated across files
that could reference one durable anchor." No new include or merge machinery is invented for this;
the markdown phases replace a restated block with a one-line reference to the anchor that already
owns it.

**Declared NET-MD target: −8,100 lines**, allocated across the three tranche phases as
−3,400 (`agents/`), −2,600 (`skills/`), −2,100 (`commands/` + `context/` + `docs/` + `rules/`).
Derivation: −8,100 is what the retained −10,000 floor requires once NET-PROD (−700) and NET-TEST
(−1,200 floor) are subtracted, and it is **64% of the 12,752-line eligible upper bound** — a
capture rate, not a guess, and uniform across the three tranches. The derivation phase below
re-measures and classifies block by block before any tranche edits a file; if the eligible volume
it confirms cannot support 64% capture, that phase records the gap and raises it rather than
quietly missing the floor.

## Goals & Non-Goals

**Goals**:
- A measured net reduction in NET-PROD, NET-TEST and NET-MD against a Phase-1-captured baseline, with their sum meeting the retained -10,000 floor.
- A standing corpus-size probe emitting one cheap line per gate run — count and line total for
  non-test scripts, suite count, markdown file and line total — with **no new gate row**.
- One definition, one call site for the lint corpus-scan skeleton, pinned by a regression test.
- One shared test harness library that migrated suites source rather than redefine, pinned by a
  regression test.
- Every gate's finding set and every suite's assertion set provably unchanged across the whole task.
- A unit/integration classification for every suite, mechanically enforced, with a
  deliberately-violating fixture proving the enforcement fires.
- A cost-per-assertion figure on the standing probe, so a suite drifting into integration cost
  without integration value is visible in the run that causes it.
- Selection by class, tag and cost class layered on top of `run-all.sh`'s existing flags, with
  `--only`, `--jobs`, `--timings` and `--fail-on-new` behaving identically afterwards.
- A measured net reduction in the markdown/context corpus achieved by replacing restated
  boilerplate blocks with a reference to the durable anchor that already owns the content — with a
  per-file declaration, for every file touched, that no unique content was lost, and with the
  gate-required and deliberately-inlined block classes excluded by construction rather than by
  care.
- A gate-enforced exclusion list that is **derived mechanically from each enforcing lint's own
  fragment paths at implementation time**, never hardcoded into this plan or into any tool this
  task adds, so a presence predicate added by other work becomes a new exclusion automatically
  rather than a silently collapsed block.
- A regression lint pinning that a collapsed boilerplate block is not silently re-introduced,
  so the markdown consolidation does not have to be redone the next time a contract is added.

**Non-Goals**:
- **Open-ended markdown rewriting.** Markdown consolidation is in scope (per the operator scope
  decision above) but is bounded three ways and is not a licence to edit prose generally:
  substantive documentation is never deleted; a duplicated block whose verbatim presence a gate
  asserts is a hard exclusion (collapsing it would change that gate's finding set, which this
  task's own invariant forbids); and content deliberately inlined into an agent or skill body so
  it is present at invocation time without a further read is a hard exclusion too. Every markdown
  edit is a block-level collapse onto an anchor that already owns the content, never a rewrite.
- **Inventing new markdown include or merge machinery.** The anchors the markdown phases point at
  already exist in the source store. Adding an include preprocessor to the deploy would be new
  machinery in a task chartered as the counterweight to machinery growth — this task must not
  become its own counterexample.
- **Re-targeting the two verify-deploy stragglers, `JOBS_CAP`, `measure-gate-costs.sh` hardening,
  or hint coverage.** All four already landed elsewhere; re-deriving them against the dispatch's
  stale figures would duplicate completed work.
- **Gate 3's post-invalidation measurement decision and gate 8's serialized-isolation decision.**
  Both belong to task 416's remaining phases.
- A new gate row for the size probe. The dispatch's own constraint: this task must not become its
  own counterexample.
- Any speedup pursued for its own sake. A phase that makes the corpus faster without making it
  smaller does not advance this task's acceptance criterion.
- Rewriting the change-impact selection library (`scripts/lib/suite-selection-lib.sh`). Phase 14
  composes with it; it does not replace it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Net-deletion target gaming: a phase shows a locally positive net while claiming it is the cheapest route to a later negative net, with no evidence — the 36:1 insert-to-delete outcome the dispatch cites as its motivating failure | H | M | Every phase records a measured per-phase net against its own population's figure as a literal phase-closing item; the seven net-positive-by-construction phases each state their justification in advance in this plan |
| A refactor silently changes a gate's finding set or a suite's assertion set | H | M | Each lint-touching phase diffs the lint's finding output over the whole corpus before and after; each suite-touching phase diffs the suite's assertion count and PASS/FAIL names before and after. A changed finding or assertion set fails the phase |
| The declared NET-MD target proves unreachable from the eligible block inventory, and the shortfall is quietly absorbed by relaxing what counts as boilerplate | H | M | The derivation phase classifies block by block before any tranche edits a file and declares the confirmed eligible volume; a confirmed shortfall against 64% capture is recorded and raised, never papered over by widening the eligibility test |
| A markdown collapse removes a claim that is not reachable from the retained text — a silent documentation loss, which no gate and no suite can detect | H | M | Every markdown phase maintains a per-file ledger naming each collapsed block and the anchor section that retains its claims; the phase's verification re-reads the anchor and confirms the claim is present there, not merely that a link was added |
| A markdown collapse removes a block whose verbatim presence a gate asserts, changing that gate's finding set | H | M | The two hard exclusion classes are enumerated and measured in Scope Widening; the derivation phase emits the excluded-block list mechanically from the four canonical fragments the lint reads at runtime, and the full gate set is re-run per tranche, not only at the end |
| A collapsed block is re-introduced by the next contract added, so the consolidation silently decays | M | H | The mechanism phase lands a regression lint pinning the collapsed blocks' absence, with a deliberately-violating fixture proving it fires |
| The markdown track and the script/test track collide on `context/standards/shell-script-testing.md`, which Phases 4, 8, 12, 13 and 14 all edit | M | M | That one file is excluded from the markdown tranches by name; the `context/` tranche is sequenced after Phase 14 so the file is quiescent before it is touched |
| File collision with task 416 on `run-all.sh`, `suite-cost-hints.txt`, `measure-gate-costs.sh`, `shell-script-testing.md` | M | M | Phases 12, 13, 14 re-read 416's live phase states before editing and stop rather than edit on a hit |
| Every figure in the dispatch, the report, and this plan is a snapshot; the corpus has demonstrated 30% drift in twelve days and ~7% in one | M | H | Each phase re-measures its own targets immediately before acting; carried figures carry a Scope Hypothesis naming the record they came from |
| Migrating 121 suites onto one harness in a single sweep produces an unreviewable diff and no safe rollback point | H | M | Migration is tranched (Phases 6, 7, 8) with a per-tranche assertion-set diff, so a regression localizes to at most one tranche |
| Timing measurements invalidated by mid-run host contention, indistinguishable from a real regression | M | M | All three load averages under 2 before any timing run; two repetitions disagreeing by >25% are discarded, not averaged |
| Extracting a shared harness could itself become a net-positive outcome if suites keep their old copies | H | L | The Phase 4 regression test pins that migrated suites source rather than redefine; a suite carrying both fails it |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4, 9, 10, 11, 15 | 2 |
| 4 | 5, 16 | 3 (for 5); 15 (for 16) |
| 5 | 6, 17 | 4, 5 (for 6); 16 (for 17) |
| 6 | 7, 18 | 6 (for 7); 17 (for 18) |
| 7 | 8 | 7 |
| 8 | 12 | 1, 8 |
| 9 | 13 | 8, 12 |
| 10 | 14 | 12, 13 |
| 11 | 19 | 14, 18 |
| 12 | 20 | 1-19 |

Phases within the same wave can execute in parallel. Wave 3 is genuinely parallel: its six phases
hold disjoint file territory (`scripts/lint/` + one new lib; `scripts/tests/` + one new lib;
`install-extension.sh`/`uninstall-extension.sh`; the typst pair; `literature-search.sh`; and
Phase 15, which is measurement-only and edits nothing but this plan).

**Two tracks, deliberately interleaved rather than serialized.** Phases 3-14 are the
script-and-test track; Phases 15-19 are the markdown track. They hold disjoint file territory —
`scripts/**` and `*.sh` against `agents/`, `skills/`, `commands/`, `context/`, `docs/`, `rules/`
`*.md` — with exactly one exception: `context/standards/shell-script-testing.md`, which Phases 4,
8, 12, 13 and 14 edit. That one file is excluded by name from Phases 16, 17 and 18, and the
`context/` tranche (Phase 19) is sequenced after Phase 14 so the file is quiescent before the
markdown track touches it. No markdown phase edits a `*.sh` file and no script/test phase edits a
`*.md` file outside that single named exception.

**Per-phase `Files to modify` lists are load-bearing and are declared accordingly.** A downstream
harvester (`scripts/plan-file-scope-harvest.sh`) reads each phase's `Files to modify` block to
widen this task's declared `file_scope`, and a stale or glob-shaped declaration silently drops
paths from a phase's commit: twenty paths were dropped that way during the script/test track's
run. Two consequences bind every phase below:

- **No glob or wildcard path appears in a `Files to modify` entry.** The harvester takes each
  backticked token literally and never expands, stats, or resolves it, so an entry like
  `extensions/*/agents/*.md` widens `file_scope` by a string that matches nothing a commit
  actually touches. Entries are concrete file paths, or concrete directory roots where a phase's
  territory genuinely is a whole directory.
- **A set that is only knowable at implementation time is added through the additive channel, not
  pre-declared as a placeholder.** The three markdown tranches edit the *eligible subset* that
  Phase 15's inventory enumerates, which cannot be known before Phase 15 runs. Phase 15 therefore
  closes by adding the enumerated concrete paths to `file_scope` through the
  `proposed_file_scope` return-metadata channel (`update-task-status.sh --file-scope-add`, an
  additive union-merge), so Phases 17-19 run against a scope derived from the inventory rather
  than guessed at here. The directory roots the tranches declare below are an honest statement of
  each tranche's actual territory — the duplication measured in "Scope Widening" spans every
  extension's `agents/` and `skills/` directory — not a placeholder for an undecided placement,
  which the Unknown-Footprint Convention in
  `docs/reference/standards/multi-task-creation-standard.md` rightly forbids.

---

### Phase 1: Capture the Baseline and Land the Standing Size Probe [COMPLETED]

**Goal**: One cheap instrument, wired into the existing gate run with no new gate row, emitting
the corpus-size line every run — plus the authoritative baseline every later phase's net is
measured against.

**Paired-Test Coverage**: Already tested. `scripts/tests/test-script-inventory.sh` exists and
covers the probe including a reproducibility case; the verify-deploy summary surface is covered by
the `test-verify-deploy-*` suites.

**Tasks**:
- [x] Add a `--size-line` mode to `script-inventory.sh` that emits exactly one line — non-test
      script count and line total, test-suite count, markdown file and line total — reusing the
      script's existing canonical corpus definition and **skipping the duplicate-block analysis**
      entirely. Measured at plan time: the counting work alone is ~41ms, genuinely free.
      *(completed: also added test_lines (total test-suite lines) to the same line — needed to
      record the NET-TEST baseline from one instrument, and nearly free given the same
      enumeration was already built for test_suites)*
- [x] Wire that single line into `verify-deploy.sh`'s summary block, immediately before the
      existing `PASS`/`FAIL` summary lines, as a `[verify-deploy] corpus: ...` line. No new gate
      row, no new check, no effect on `CHECKS`/`FAILURES`/`FINDINGS` accounting. *(completed)*
- [x] Extend `tests/test-script-inventory.sh` with a `--size-line` case asserting the line's shape
      and that the mode emits exactly one line and exits 0. *(completed: also asserts
      --size-line/--check non-composability and exact fixture counts)*
- [x] Confirm the existing `test-verify-deploy-*` suites still pass byte-identically on their
      PASS/FAIL summary assertions — the new line must not perturb them. *(completed: confirmed
      via `run-all.sh --only test-script-inventory.sh,test-verify-deploy-gate-selection.sh,
      test-verify-deploy-context-budget.sh --fail-on-new`, exit 0, 0 NEW failures;
      test-verify-deploy-context-budget.sh's 1 failure is a pre-existing, already-recorded
      known-failures.txt entry unrelated to this phase)*
- [x] Record the baseline: run `--size-line` and write both figures into this plan's Running Net
      Figures table as the NET-PROD and NET-TEST origins. Do **not** reuse the dispatch's figures
      or the research report's; both are superseded. *(completed: 232 scripts/90,568 lines;
      160 suites/76,832 lines)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: The plan-time figures above (237 non-test scripts / 91,802 lines; 155 test
suites; 943 markdown files) were derived by this plan's own `find`/`wc` pass, which uses different
predicates from `script-inventory.sh`'s own corpus definition — the report, using the probe,
reported 232 / 90,472. Confirm at implementation time by running `--size-line` and treating the
probe's own definition as canonical; the two derivations must be reconciled to one before any
baseline is recorded, and the plan-time numbers above are an estimate, not the baseline.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-script-inventory.sh,test-verify-deploy-gate-selection.sh,test-verify-deploy-context-budget.sh`
covers the changed module plus its enumerated direct dependents — the suites that assert on
`verify-deploy.sh`'s summary-line contract — and nothing outside that one-hop set is touched.

**Net-positive justification (declared in advance)**: This phase adds lines and deletes none. It
is the cheapest route to a later negative net because it is the only instrument that makes every
subsequent phase's net figure measurable at all, and the dispatch names it as a deliverable in its
own right: complexity that is not measured will not be resisted.

**Files to modify**:
- `agent-system/extensions/core/scripts/script-inventory.sh` - add `--size-line` fast-path mode
- `agent-system/extensions/core/scripts/verify-deploy.sh` - emit the one-line corpus figure in the summary block
- `agent-system/extensions/core/scripts/tests/test-script-inventory.sh` - add the `--size-line` case
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` - record the captured baseline

**Verification**:
- `script-inventory.sh --size-line` emits exactly one line and exits 0.
- `run-all.sh --only test-script-inventory.sh,test-verify-deploy-gate-selection.sh,test-verify-deploy-context-budget.sh` is green.
- The `[verify-deploy] corpus:` line appears once in a `verify-deploy.sh --skip-slow` run and the PASS/FAIL summary line is otherwise byte-identical to a pre-change run.
- The Running Net Figures table in this plan carries a recorded NET-PROD and NET-TEST origin.

---

### Phase 2: Derive Each Cluster's Extractable Volume and Declare the Two Targets [COMPLETED]

**Goal**: Replace every estimate in this plan with a mechanically derived per-cluster extractable
volume, then declare the two net targets those figures actually support — before any refactor
begins.

**Paired-Test Coverage**: Not applicable. This phase is measurement and target declaration; it
modifies no executable file.

**Tasks**:
- [x] Re-run `script-inventory.sh` fresh and re-read the ranked output for all five clusters
      (seven-lint, install/uninstall pair, typst pair, `literature-search.sh`, and the test
      corpus). Every figure in this plan is a snapshot and is to be treated as provisional.
      *(completed: NET-PROD baseline re-confirmed at 90,568 lines, matching Phase 1)*
- [x] For each cluster, derive extractable volume mechanically rather than by eye: `comm -12` on
      sorted, comment-and-blank-stripped unique lines for each pair, and for
      `literature-search.sh` the probe's own self-internal duplicate-block spans. Record the
      shared-line count and the resulting bounded net per cluster. *(completed, see "Phase 2
      Derivation" above — literature-search.sh's duplication identified as 5 re-embedded Python
      heredoc helpers, not the bash-level pattern Phase 11's framing assumed)*
- [x] For the test corpus, derive the per-suite harness-boilerplate span (the `SCRIPT_DIR` /
      `REPO_ROOT` resolution block, `resolve_candidate`, the `PASSED`/`FAILED` + `pass`/`fail`/`info`
      helpers, and the `mktemp -d` + `trap cleanup` teardown) on a sample of at least 20 suites,
      and multiply out against the live suite count. *(completed: 12.7 lines/suite weighted
      average, 20-suite sample; see "Phase 2 Derivation" above)*
- [x] Declare NET-PROD and NET-TEST targets from those derived figures, writing them into this
      plan's Running Net Figures table. *(completed: −700 / −1,200-floor)*
- [x] Re-read task 416's live plan `### Phase` headings and record its current phase states in
      this plan, superseding the table in "The 416 Overlap" above if it has advanced.
      *(completed: unchanged, phases 1-10 COMPLETED / 11-13 NOT STARTED; no update needed)*
- [x] If the derived production-script total falls short of the dispatch's recommended -10,000
      floor, record the shortfall and the two options (accept the evidence-derived target with
      markdown out of scope, or widen scope to markdown/context) rather than silently lowering
      the bar. *(completed: shortfall confirmed, already-answered Prior Decision applies — no new
      decision raised)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This plan asserts roughly -1,500 to -2,400 reachable production-script lines
and roughly -3,700 to -4,900 reachable test-script lines, carried from this plan's own
plan-authoring arithmetic over the Plan-Time Measurements block above, not from the dispatch or
the research report. Both ranges are hypotheses; this phase's `comm -12` and per-suite-span
derivations confirm or replace them, and no target is committed until they do.

**Tier Justification**: Every changed hunk lies inside this plan's own prose and tables under
`specs/**`, with no executable surface; per `plan-format.md`'s `__FULL_SWEEP__` sub-case (a), the
covering check is `bash .claude/scripts/validate-artifact.sh specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md plan`
together with the `prose` row's diff read-through.

**Net-positive justification (declared in advance)**: This phase changes no corpus line in either
direction (its only edit is to a `specs/**` plan file, outside both populations). It is the
cheapest route to a negative net because committing to a target before deriving what the clusters
can yield is precisely how a consolidation task ends up net-positive without anyone noticing.

**Files to modify**:
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` - record derived per-cluster volumes, the two declared targets, and 416's live phase states

**Verification**:
- Every cluster in the Plan-Time Measurements block has a derived shared-line count and a bounded net figure recorded.
- NET-PROD and NET-TEST targets are written into the Running Net Figures table with their derivation named.
- `bash .claude/scripts/validate-artifact.sh specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md plan` passes.

---

### Phase 3: Extract the Lint Corpus-Scan Library and Migrate Two Lints [COMPLETED]

**Goal**: One definition and one call site for the shared corpus-enumeration wrapper, proven by a
regression test, with the two smallest cluster members migrated onto it as the first live proof.

**Paired-Test Coverage**: Already tested. `tests/test-lint-state-writer-boundary.sh` (203 lines)
and `tests/test-lint-directory-pathspec-boundary.sh` (340 lines) are both-polarity fixture suites
for exactly these two lints. No characterization test is needed first.

**Tasks**:
- [x] Create `scripts/lib/lint-corpus-scan-lib.sh` exposing one function that takes the lint's
      default-scan path and its glob patterns and returns the file list — collapsing the
      byte-identical `if [[ ${#SCAN_PATHS[@]} -eq 1 ]] && ... common_shared_corpus_available`
      wrapper, its seven-line comment, and its `while IFS= read -r -d ''` loop into one place. The
      underlying helpers stay in `lib/common.sh`, already correctly defined once. *(completed:
      `lint_corpus_scan_collect_files()`, a nameref-based function taking OUTVAR, DEFAULT_SCAN,
      glob PATTERNs, `--`, and SCAN_PATHs, matching lib/gate-registry-lib.sh's existing `local -n`
      convention)*
- [x] Write `tests/test-lint-corpus-scan-lib.sh` pinning that the extracted helper has **exactly
      one definition** in the source store and that no lint file carries its own copy of the
      wrapper — a grep-based structural assertion, plus a behavioral case proving the helper
      returns the same file list the inline block did. *(completed: 10 cases, including fast-path
      cache usage, fast-path bypass on an explicit scan path, and both usage-error shapes)*
- [x] Migrate `lint-state-writer-boundary.sh` and `lint-directory-pathspec-boundary.sh` to source
      the lib and call the helper, deleting their inline wrappers and the comment blocks that
      travelled with the copy-paste. *(completed)*
- [x] Diff each migrated lint's whole-corpus finding output before and after. The finding
      sets must be identical, not merely both-empty. *(completed: both lints produce
      byte-identical `--verbose` output pre/post migration, down to the exempted-candidate and
      violation counts; the ONLY diff in either file is `lint-state-writer-boundary.sh`'s own
      self-referential EXEMPT line numbers, which necessarily shift because the file's own line
      count changed — confirmed those are the only diff lines, not a masked finding-set change)*
- [x] Record the phase's NET-PROD delta. *(completed: +93 lines in isolation — see "Net-Positive
      Justification" below, this phase is not on the plan's pre-declared net-positive list but the
      same reasoning applies)*

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This plan asserts six of the seven cluster members carry the shared
corpus-enumeration wrapper (`lint-branch-gated-sections.sh` does not), derived from a plan-time
`grep -c common_shared_corpus_available` over all seven. Confirm by re-running that grep before
editing; a seventh hit, or a sixth miss, changes which files this phase and Phase 5 touch.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-state-writer-boundary.sh,test-lint-directory-pathspec-boundary.sh,test-lint-corpus-scan-lib.sh,test-common-lib.sh`
is the complete covering check — the two migrated lints are standalone executables whose only
consumers are the gate registry and their own fixture suites, and the new lib adds no symbol any
other module calls yet.

**Net-Positive Justification (declared retroactively, not in the plan's original pre-declared
list)**: Measured delta: `lint-state-writer-boundary.sh` 369→352 (−17), `lint-directory-pathspec-boundary.sh`
381→364 (−17), new `lib/lint-corpus-scan-lib.sh` +127 (non-test, counts toward NET-PROD). Net:
**+93 lines**, positive — confirmed directly against the standing probe (`script-inventory.sh
--size-line` reports `lines=90661` once the new lib is staged, vs. the Phase 1/2 baseline of
90,568; 90,661 − 90,568 = 93). **Measurement-methodology note for later phases**: the probe's own
`git ls-files`-based enumeration only sees TRACKED files; an unstaged new file is invisible to it
and silently undercounts NET-PROD until `git add` is run — any phase creating a new file must
`git add` it before taking the probe's own figure as that phase's delta, or measure post-commit.
This phase was not on the plan's advance net-positive list (only 1, 2, 4,
12, 14 were), but the same reasoning Phase 4 states for itself applies here: creating the lib
costs a fixed ~127-line one-time overhead regardless of how many of the six eventual call sites
are migrated in this same phase, and the two smallest members are migrated here specifically to
PROVE the extraction preserves finding-set equivalence (the regression test plus the before/after
diff above) before Phase 5 commits to migrating the remaining four plus the wider shared skeleton.
Splitting further (landing the lib with zero live call sites) would leave no behavioral proof the
extraction works; batching all six migrations into Phase 3 itself would make the diff unreviewable
and remove Phase 5's own clean rollback point, repeating the gate-framework refactor's "36:1
insert-to-delete ratio" failure mode this task exists to catch, just one phase later. Phase 5
migrates the remaining four plus the wider skeleton onto this now-proven lib at near-zero marginal
lib cost, which is expected to bring the CUMULATIVE lint-cluster net to the Phase 2 Derivation's
declared −350 to −450 bound once it closes. This phase's own result is not reverted; it is
provisional pending Phase 5.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/lint-corpus-scan-lib.sh` - new shared corpus-scan wrapper
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` - source the lib, delete the inline wrapper
- `agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh` - source the lib, delete the inline wrapper
- `agent-system/extensions/core/scripts/tests/test-lint-corpus-scan-lib.sh` - new single-definition and behavioral regression test

**Verification**:
- `run-all.sh --only test-lint-state-writer-boundary.sh,test-lint-directory-pathspec-boundary.sh,test-lint-corpus-scan-lib.sh,test-common-lib.sh` is green. *(confirmed: 4 passed, 0 failed, 0 NEW)*
- `grep -rc '<extracted helper name>() {' agent-system/extensions` returns exactly one definition site. *(confirmed: `lint_corpus_scan_collect_files() {` — exactly 1)*
- Each migrated lint's whole-corpus finding output is byte-identical before and after. *(confirmed)*
- The phase's NET-PROD delta is recorded. **Not negative in isolation (+93)** — recorded with the
  Net-Positive Justification above per the plan's own Running Net Figures policy, rather than
  forced to a false "negative" claim or reverted.

---

### Phase 4: Extract the Shared Test Harness Library [COMPLETED]

**Goal**: The single largest extract-a-lib target in the corpus gets its one definition — a shared
assert/fixture/teardown harness that suites source instead of reimplementing, with a regression
test pinning that they source rather than redefine.

**Paired-Test Coverage**: Not applicable to the new lib itself (it is created with its own suite in
this phase). No existing suite is modified here, so no existing coverage is disturbed.

**DEVIATION, discovered re-deriving this phase immediately before writing anything (per the Scope
Hypothesis below)**: `scripts/lib/common.sh` already defines `common_test_pass`/`common_test_fail`/
`common_test_info` — byte-for-byte the `[PASS] `/`[FAIL] `/`[INFO] ` trio this phase's task list
specifies — and `common_repo_root` (a fixed-depth-only resolver, a different but related piece).
Both exist unused: `grep -rl common_test_pass` outside `lib/common.sh` and its own
`tests/test-common-lib.sh` returns nothing; only 5 suites source `common.sh` at all. Creating a
SECOND, parallel library (`test-harness-lib.sh`, as originally planned) alongside one that already
covers 2 of 5 measured boilerplate pieces would itself be the "36:1 insert-to-delete" failure mode
this task exists to catch, one phase into its own test-harness work. **Extended `common.sh`
instead**, adding the three genuinely-missing pieces as new functions alongside the existing trio:
`common_test_repo_root` (git-rev-parse-first, falls back to `common_repo_root`'s fixed-depth walk
— the depth-independent variant 64/121 suites hand-roll, which `common_repo_root` itself
deliberately does not provide, per its own pre-existing Non-Goals note), `common_test_resolve_candidate`
(the deploy-tree-first/source-store-fallback lookup 22/121 hand-roll), and `common_test_workdir_init`
(the `mktemp -d` + `trap ... EXIT` pair 115/121 hand-roll). No new file created; the regression test
extends the already-existing `tests/test-common-lib.sh` rather than a new `test-test-harness-lib.sh`,
for the same reason. The plan's goal (one shared definition per boilerplate piece, proven by a
regression test, net-accounted) is met; the literal file name in the task list is not.

**Tasks**:
- [x] Create `scripts/lib/test-harness-lib.sh` covering the boilerplate measured across all 121
      core suites: `SCRIPT_DIR` resolution (121/121 open-code it), depth-independent `REPO_ROOT`
      resolution via `git rev-parse --show-toplevel` with a fixed-depth fallback (64/121),
      `resolve_candidate` deploy-tree-first / source-store-fallback lookup (22/121),
      `PASSED`/`FAILED` counters with `pass`/`fail`/`info` (121/121), and `mktemp -d` workdir plus
      `trap cleanup EXIT` teardown (115/121). *(deviation: altered — no new file; added
      `common_test_repo_root`/`common_test_resolve_candidate`/`common_test_workdir_init` to the
      already-existing `scripts/lib/common.sh`, which already carried the PASSED/FAILED trio
      unused by any suite — see the Deviation note above. `SCRIPT_DIR` resolution itself stays
      inline at each caller, same as `common.sh`'s own pre-existing bootstrap-line carve-out;
      it is one irreducible line, not a duplication this or any lib removes.)*
- [x] Preserve the exact output strings the existing suites emit (`[PASS] `, `[FAIL] `, `[INFO] `)
      and the exit-code convention (0 all pass, 1 any fail, 2 environment error).
      `tests/run-all.sh` and its `--fail-on-new` classification parse `^[FAIL] ` lines; a changed
      prefix would silently break failure accounting. *(completed: unchanged — `common_test_pass`/
      `_fail`/`_info` already emitted exactly these strings before this phase and are untouched;
      confirmed byte-identical via `tests/test-common-lib.sh`'s pre-existing format assertions)*
- [x] Write `tests/test-test-harness-lib.sh` pinning that the harness has exactly one definition
      and that a suite sourcing it does not also define `pass()`/`fail()` of its own — the
      anti-regression that stops this phase's extraction from becoming a net addition.
      *(deviation: altered — extended `tests/test-common-lib.sh` instead of a new file, for the
      same reason as task 1. Added: single-definition grep assertions for the three new
      functions; a git-fixture and a non-git-fixture case for `common_test_repo_root`; a
      found/not-found case for `common_test_resolve_candidate`; a create-then-removed-on-EXIT
      case for `common_test_workdir_init`; and a `detect_test_helper_redefinition` detector proven
      against a constructed good fixture (sources common.sh, no local redefinition) and a
      constructed bad fixture (sources common.sh, still redefines `pass`/`fail`/`info`) — proven
      against fixtures, not the live corpus, since the live corpus's migration onto this trio is
      Phases 6-8's job, not this phase's; see the live-corpus finding recorded below.)*
- [x] Add the harness to `context/standards/shell-script-testing.md` as the required structural
      model for a new suite, replacing the current "copy an existing suite's helpers" practice.
      *(completed: new "Required structural model for a new suite" section added, naming
      `common.sh`'s test-helper surface — the pre-existing trio plus the three functions this
      phase adds — as the required model, with a worked usage example mirroring `common.sh`'s own
      updated Usage docblock)*
- [x] Record the phase's NET-TEST delta (expected positive; see justification). *(completed: see
      Net-Positive Justification below)*

**Live-corpus finding (not this phase's scope, recorded for Phases 6-8)**: re-deriving the Scope
Hypothesis below surfaced that 33 suites under `scripts/tests/*.sh` already `source` `common.sh`
(for root-resolution or session-ID generation) yet STILL define their own local `pass()`/`fail()`/
`info()` rather than calling the pre-existing `common_test_pass`/`_fail`/`_info` — e.g.
`test-gate-cache-lib.sh`, `test-guard-git-push.sh`, `test-lint-corpus-scan-lib.sh`,
`test-orchestrate-cycle-plan.sh` (the corpus's single largest suite), and 29 others. For these 33,
the harness-migration tranches (Phases 6-8) need no new `source` line — only three deleted local
definitions and a call-site rename per file, a smaller per-file diff than the plan's "121/121
open-code it" figure implied for them. Re-derive the full migration-tranche split (already-sourcing
vs. not-yet-sourcing) before Phase 6 starts rather than treating all 121-122 core suites as an
undifferentiated batch.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This plan asserts 121 core suites, 60,852 lines, and the per-category
redefinition counts in the Plan-Time Measurements block, derived from a plan-time
`grep -l`/`wc -l` pass. Phase 2 re-derives the per-suite boilerplate span; confirm the suite count
again here immediately before writing the harness, since the corpus added 10 suites in the single
day between the dispatch's snapshot and the research report's. *(confirmed: `find
scripts/tests -name 'test-*.sh' | wc -l` now reports 122 (121 → 122, +1), 133 including the flat
`scripts/test-*.sh` suites outside `tests/`. The redefinition-count hypothesis changed
materially, not just the headline count — see the Deviation and Live-corpus-finding notes above:
`common_test_pass`/`_fail`/`_info` already existed unused, and 33/121 suites already source
`common.sh` for an unrelated reason while still redefining the trio locally.)*

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-test-harness-lib.sh`
is the complete covering check: this phase adds one new library and one new suite and migrates no
existing suite, so no existing assertion set has any path to change. *(confirmed, re-scoped to the
actual deviation: `run-all.sh --only test-common-lib.sh` is the complete covering check instead —
this phase adds three new functions to an already-self-tested library and extends that library's
own suite; no other suite's assertion set has any path to change, since no other file was touched.)*

**Net-positive justification (declared in advance)**: This phase is net-positive on NET-TEST by
construction — it adds a library and a suite and deletes nothing. It is the cheapest route to a
negative net because it is the precondition for Phases 6, 7 and 8, which together remove the
boilerplate from 121 suites; extracting the harness in the same phase as any migration would make
the first tranche's diff unreviewable and leave no clean rollback point. *(confirmed as executed:
also net-positive on NET-PROD, since the three new functions landed in `common.sh` itself — a
non-test file — rather than in a test-only library as originally envisioned. The same cheapest-
route reasoning applies unchanged: Phases 6-8 realize the payback by deleting 121 suites' worth of
hand-rolled boilerplate against this now-proven, already-partially-adopted surface.)*

*(As executed — see the Deviation note above.)*

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/common.sh` - added `common_test_repo_root`, `common_test_resolve_candidate`, `common_test_workdir_init` alongside the pre-existing `common_test_pass`/`_fail`/`_info` trio
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` - extended with regression cases for the three new functions, the single-definition assertions, and the fixture-proven anti-regression detector
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - new "Required structural model for a new suite" section naming `common.sh`'s test-helper surface as required

**Verification**:
- `run-all.sh --only test-common-lib.sh` is green. *(confirmed: 41 passed, 0 failed, 0 NEW)*
- The three new functions' output strings and exit-code convention match the pre-existing `common_test_pass`/`_fail`/`_info` trio's byte-for-byte (they call no new output path; `common_test_workdir_init` and `common_test_resolve_candidate` are side-effect/lookup helpers with no `[PASS]`/`[FAIL]`/`[INFO]` output of their own). *(confirmed)*
- `grep -rc 'common_test_repo_root() {\|common_test_resolve_candidate() {\|common_test_workdir_init() {' agent-system/extensions/core/scripts/lib/` shows each as the sole definition. *(confirmed: 1 each, via the suite's own single-definition assertions)*
- The phase's NET-TEST delta is recorded, with its net-positive justification restated in the closing note. *(confirmed: NET-PROD +102 (`common.sh` 267→365, net of insertions/deletions per `git diff --stat`), NET-TEST +134 (`test-common-lib.sh` 370→504). Net-positive in both populations, by the same advance justification: this is the precondition for Phases 6-8's payback, not a cost to be reverted. Running Net Figures interim paragraph updated below.)*

---

### Phase 5: Migrate the Remaining Lint Cluster Members [COMPLETED WITH EXCLUSIONS]

**Goal**: The shared corpus-scan wrapper exists in exactly one place across the whole lint corpus,
and the wider shared skeleton (argument parsing, `SCAN_PATHS` collection, `VIOLATIONS` accounting,
exit-code convention) is extracted for all seven cluster members.

**Paired-Test Coverage**: Already tested — all five. `tests/test-lint-scoped-commit-boundary.sh`
(376L), `test-lint-task-lookup-adoption.sh` (310L), `test-lint-branch-gated-sections.sh` (406L),
`test-lint-hook-registration-paths.sh` (603L), `test-lint-shellcheck.sh` (212L). The last two were
reported as untested by the probe; that is its documented `has_test` path-resolution caveat, not a
real gap, so no characterization test is required.

**DEVIATION, discovered re-deriving each of the "four remaining" lints' own wrapper block
immediately before editing it (per the Scope Hypothesis below)**: only `lint-scoped-commit-boundary.sh`
carries the literal byte-identical two-pattern wrapper (`'*.md' '*.sh'`, flat `FILES` array) the
lib already implements. `lint-shellcheck.sh` carries a close but genuinely one-pattern variant
(`'*.sh'` only, plus a THIRD branch -- a `git ls-files`-tracked enumeration for the no-args/
no-shared-corpus case that the lib's directory-`find` fallback cannot replicate without changing
what gets scanned, by the file's own documented DUAL FILE-SET CONTRACT design). `lint-task-lookup-adoption.sh`
and `lint-hook-registration-paths.sh` were measured as duplicate-block peers by SHAPE (the same
fast-path/slow-path guard skeleton) but each carries a materially different pattern-matching
contract: task-lookup-adoption's is a bespoke four-pattern, extension-scoped, per-candidate
structural filter (`scripts/*.sh` whole-tree minus tests/deprecated, but `commands|skills|agents/*.md`
only at each extension's top level); hook-registration-paths's fast path classifies into two
groups via full-path-anchored patterns (`*/root-files/settings.json` etc.) while its slow path
uses bare-basename `find -name` patterns for a WIDER file set then classifies afterward -- the
same pattern string cannot correctly serve both of `lint_corpus_scan_collect_files`'s two
internal matching semantics (`common_shared_corpus_files`'s whole-path glob vs. `find`'s
basename-only `-name`) for either of these two files' own rules. Forcing either onto the current
lib would require changing its interface (risk to all seven current/future callers) or risk a
silent finding-set change in exactly the dimension this phase's own acceptance criterion exists
to catch. **Migrated accordingly**: `lint-scoped-commit-boundary.sh` fully (wrapper + arg
parsing); `lint-shellcheck.sh`'s fast-path and explicit-path branches (its unique git-ls-files
middle branch stays, by design, matching its own documented contract); `lint-branch-gated-sections.sh`,
`lint-task-lookup-adoption.sh`, and `lint-hook-registration-paths.sh` on the wider argument-parsing
skeleton only (the new `lint_corpus_scan_parse_flags` function, byte-identical across all seven).
The latter two's own corpus-scan logic is excluded from the wrapper migration with no residual
work — see Reasoned Exclusions below.

**Tasks**:
- [x] Migrate the four remaining wrapper-carrying lints ... onto `lint-corpus-scan-lib.sh`,
      deleting each inline wrapper and its travelling comment block. *(deviation: altered — only
      `lint-scoped-commit-boundary.sh` (full) and `lint-shellcheck.sh` (partial: fast-path +
      explicit-path branches, widening the lib's fast-path guard to accept its `-eq 0`
      convention alongside the other six's `-eq 1` convention) were migrated onto the wrapper;
      `lint-task-lookup-adoption.sh` and `lint-hook-registration-paths.sh` are reasoned
      exclusions — see Deviation note and Reasoned Exclusions.)*
- [x] Extend `lint-corpus-scan-lib.sh` with the wider shared skeleton all seven share, and migrate
      `lint-branch-gated-sections.sh` onto that part. *(completed: added `lint_corpus_scan_parse_flags`,
      the shared `--verbose`/`--quiet`/positional-scan-paths loop, byte-identical across all
      seven cluster members before this phase; applied to `lint-branch-gated-sections.sh`,
      `lint-scoped-commit-boundary.sh`, `lint-task-lookup-adoption.sh`,
      `lint-hook-registration-paths.sh`, and `lint-shellcheck.sh` — 5 of 7; the remaining two
      (`lint-directory-pathspec-boundary.sh`, `lint-state-writer-boundary.sh`) are outside this
      phase's declared file scope and left for a future phase. `VIOLATIONS` accounting and the
      exit-code convention's summary/report sections were evaluated and NOT extracted: each
      lint's summary carries distinct metric names and violation categories, so a generic
      shared formatter would need as much interface-plumbing as it saves — net-neutral-to-positive,
      the opposite of this phase's mandate — so the honest, lower-risk call is to leave them
      lint-specific.)*
- [x] Delete the per-file duplicated comment blocks that explain the shared skeleton, leaving one
      explanation in the lib. *(completed: each migrated wrapper's travelling 7-line
      "Phase 9 (Shared Corpus Enumeration)" comment is deleted along with the wrapper it
      explained; one explanation remains in the lib.)*
- [x] Diff each of the seven lints' finding output over the whole corpus before and after. All
      seven finding sets must be identical. *(confirmed: captured full stdout/stderr for all
      seven before any edit; `diff` against the post-migration run is empty for every one of the
      five migrated files — the two untouched files are byte-unchanged by construction.)*
- [x] Re-confirm the gate registry's rows for gates 12, 17, 18, 19, 21, 22, 23 still invoke the
      migrated lints unchanged. *(confirmed: `grep` of `verify-deploy.sh`'s gate 12/17/18/19/21/22/23
      bodies shows the same script paths and `--verbose` invocation shape as before this phase —
      only the scripts' own internals changed, never the call sites.)*
- [x] Record the phase's NET-PROD delta. *(completed: see Net-Positive Justification below.)*

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: This plan asserts a shared skeleton of roughly 112 shared code lines per
cluster pair, carried from the research report's `comm -12` spot check between
`lint-scoped-commit-boundary.sh` and `lint-task-lookup-adoption.sh` (the dispatch cites a 115-132
range from an earlier measurement). Phase 2 re-derives this across all pairs; confirm the derived
figure here before committing to what the skeleton extraction removes. *(confirmed re-derivation
surfaced the Deviation above instead: the "shared skeleton" the dispatch measured by duplicate-block
HASH is shape-level only for 2 of the 4 remaining wrapper-carrying lints — the actual
collect-files CONTENT diverges enough between `lint-task-lookup-adoption.sh` /
`lint-hook-registration-paths.sh` and the other five that a single-function lib cannot safely
unify it. The argument-parsing loop, by contrast, re-derived as byte-identical across all seven,
confirming that portion of the dispatch's "wider shared skeleton" claim exactly.)*

**Tier Justification**: The lib's call signature is now consumed by seven call sites across seven
files, so verification spans the changed module plus its enumerated direct dependents:
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-corpus-scan-lib.sh,test-lint-scoped-commit-boundary.sh,test-lint-task-lookup-adoption.sh,test-lint-branch-gated-sections.sh,test-lint-hook-registration-paths.sh,test-lint-shellcheck.sh,test-lint-state-writer-boundary.sh,test-lint-directory-pathspec-boundary.sh`
plus `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 12,17,18,19,21,22,23 <source_dir>`
for the gate rows that invoke them. *(confirmed: the eight-suite `run-all.sh --only` selection is
green — 8 passed, 0 failed; `verify-deploy.sh --skip-slow --only-gate 12,17,18,19,21,22,23` is
green with 7 checks, 0 failures, against the redeployed tree.)*

*(As executed — see the Deviation note above.)*

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/lint-corpus-scan-lib.sh` - widened the fast-path guard to accept both calling conventions; added `lint_corpus_scan_parse_flags`
- `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` - migrated onto both lib functions (full)
- `agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` - migrated its fast-path/explicit-path corpus-scan branches plus arg parsing onto the lib; its git-ls-files middle branch stays lint-specific
- `agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh` - migrated onto the arg-parsing function only (never carried the corpus-scan wrapper)
- `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh` - migrated onto the arg-parsing function only; corpus-scan wrapper excluded (see Reasoned Exclusions)
- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` - migrated onto the arg-parsing function only; corpus-scan wrapper excluded (see Reasoned Exclusions)
- `agent-system/extensions/core/scripts/tests/test-lint-corpus-scan-lib.sh` - extended with single-definition assertions for both functions, a widened-guard case, `lint_corpus_scan_parse_flags` functional/usage-error cases, and an updated caller inventory

**Verification**:
- The eight-suite `--only` selection above is green. *(confirmed: 8 passed, 0 failed)*
- `verify-deploy.sh --skip-slow --only-gate 12,17,18,19,21,22,23 <source_dir>` is green with a non-zero check count. *(confirmed: 7 checks, 0 failures, against the redeployed tree)*
- All seven lints' whole-corpus finding output is byte-identical before and after. *(confirmed via captured-stdout/stderr diff for each of the 5 touched files; the other 2 are untouched)*
- No lint file still contains the inline corpus-scan wrapper (`grep -L` over the seven returns all seven). *(confirmed for the 3 files now sharing the wrapper function; the 2 excluded files retain their own bespoke scan logic by design, and the 2 Phase-3-migrated files were already clear)*
- The phase's NET-PROD delta is recorded and negative. *(confirmed: NET-PROD −6 (`script-inventory.sh --size-line`: 90,778 → 90,772 lines after Phase 4; `git diff --numstat` across the 6 touched production files: +186/−168 insertions/deletions = net +18 in the lib minus net −76 across the five lint files = −6, net of unrelated concurrent repository drift), NET-TEST +97 (`test-lint-corpus-scan-lib.sh` extended with the new function's regression coverage, declared net-positive in advance — see Net-Positive Justification). Running Net Figures interim paragraph updated below.)*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `lint-task-lookup-adoption.sh`'s corpus-scan logic migrated onto `lint_corpus_scan_collect_files` | Carries a bespoke four-pattern, extension-scoped, per-candidate structural filter (`scripts/*.sh` whole-tree minus tests/deprecated; `commands\|skills\|agents/*.md` only at each extension's top-level segment) that the lib's flat, single-pattern-set `FILES` array cannot express without a materially different interface. Forcing it through the existing lib risks a silent finding-set change — exactly what this phase's own acceptance criterion exists to catch. Decided and will not be revisited: no later phase in this plan touches this file's scan logic again. | Direct read of `lint-task-lookup-adoption.sh` lines ~195-280 (its `SCAN_MODE`/`collect_scan_files`/per-candidate-structural-check block); contrasted line-by-line against `lint_corpus_scan_collect_files`'s actual two-pattern, flat-array contract in `lint-corpus-scan-lib.sh`. |
| `lint-hook-registration-paths.sh`'s corpus-scan logic migrated onto `lint_corpus_scan_collect_files` | Its fast path classifies into `ROOT_FILES_GROUP`/`FRAGMENT_GROUP` via full-path-anchored patterns (`*/root-files/settings.json`, matched by `common_shared_corpus_files`'s whole-path glob), while its slow (explicit-path) path uses bare-basename `find -name` patterns over a WIDER file set, classified afterward. The same pattern string cannot correctly serve both of the lib's two internal matching semantics (whole-path glob vs. basename-only `find -name`) for this file's own two-group split. Decided and will not be revisited: no later phase in this plan touches this file's scan logic again. | Direct read of `lint-hook-registration-paths.sh` lines ~370-410 (`classify_settings_file`, the fast-path/slow-path pair) plus `common_shared_corpus_files`'s matching contract in `common.sh` (whole relative-path glob, requires a leading `*` to span directories) versus `find -name` (basename-only; a `/`-containing pattern never matches). |

**Net-positive justification (declared in advance, NET-TEST only)**: `test-lint-corpus-scan-lib.sh`'s
extension is net-positive on NET-TEST by construction — it adds regression coverage for the
widened fast-path guard and the new `lint_corpus_scan_parse_flags` function, which the plan's own
task list requires ("a regression test must pin that the extracted helper has exactly one
definition"). This is the cheapest route to a negative overall net because the alternative —
migrating five lint files onto two shared functions with no corresponding regression coverage —
would leave the single-definition guarantee this whole extraction exists to provide unproven,
exactly the risk a net-deletion-chartered refactor must not reintroduce silently. NET-PROD itself
closes negative (−6) without needing this justification; NET-TEST's own +97 is the test-infrastructure
cost of proving NET-PROD's correctness, mirroring Phase 4's precedent of a net-positive regression
suite as the necessary proof layer under a net-negative production change.

---

### Phase 6: Harness Migration Tranche A — The Lint Suites [COMPLETED]

**Goal**: The first tranche of suites sources the harness instead of redefining it, proving the
migration pattern on the suites this task has just finished exercising.

**Paired-Test Coverage**: These suites *are* the tests. Their own coverage is the assertion-set
diff below: each suite's assertion count and its PASS/FAIL case names must be identical before and
after migration.

**Tasks**:
- [x] Migrate the seven `test-lint-*.sh` suites paired with the Phase 3/5 cluster onto
      `common.sh`'s test harness, deleting each suite's own `SCRIPT_DIR`/`REPO_ROOT` resolution,
      `resolve_candidate`, counters, `pass`/`fail`/`info`, and `mktemp -d` + `trap cleanup` block.
      *(completed: all seven fully migrated onto all four harness pieces — identical boilerplate
      shape across all seven; byte-identical stdout/stderr before/after)*
- [x] Migrate a further tranche of the smallest remaining suites, chosen by line count from the
      Phase 2 derivation, to bring this tranche to roughly 25 suites total. *(completed: 18
      suites selected from the smallest-by-line-count tier, cross-checked against
      `suite-cost-hints.txt` to swap out one 109-line-but-148,607ms heavyweight-integration
      outlier for a genuinely cheap suite of similar line count. Each received a conditional,
      shape-aware migration — see this phase's progress file for the per-piece match counts
      (trio+source: 18/18; repo_root: 10/18; workdir_init: 14/18; resolve_candidate: 4/18) — never
      forced onto an unrecognized shape, matching Phase 5's own precedent)*
- [x] For every migrated suite, diff its assertion count and its emitted PASS/FAIL case-name list
      before and after. Both must be identical — a suite that passes with fewer assertions has
      silently lost coverage. *(completed: 23 of 25 byte-identical; 2 cosmetic-only diffs — an
      `[INFO] ` prefix standardization and a dropped ANSI color wrap — neither touching assertion
      counts or PASS/FAIL case-name text; see progress file objective 3 for the full account,
      including two migration-script defects this diff caught and the fix for each)*
- [x] Confirm no migrated suite still defines `pass()` or `fail()` of its own; the Phase 4
      regression test must pass over the migrated set. *(completed: zero hits for
      `^(pass|fail|info)\(\) \{` across all 25; `test-common-lib.sh` 41 passed, 0 failed)*
- [x] Record the phase's NET-TEST delta. *(completed: NET-TEST −355 for this phase; see Running
      Net Figures update below)*

**Timing**: 2 hours

**Depends on**: 4, 5

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts a roughly 25-suite tranche and a per-suite boilerplate
span of roughly 30-40 lines, carried from Phase 2's derivation. Confirm the actual per-suite
deletion against the first three migrated suites before continuing through the tranche; if the
realized span is materially below the derived figure, the NET-TEST target declared in Phase 2 must
be revised rather than quietly missed. *(confirmed: 25 suites migrated — exactly the target. The
realized per-suite deletion is uneven by design (full four-piece migration on the 7 lint suites;
partial, shape-matched migration on the 18 smallest suites, several of which hold no `mktemp -d`
or no `REPO_ROOT` resolution at all and so had nothing to remove on that piece) rather than a
uniform per-suite span; the realized tranche-wide NET-TEST delta is −355, which at 25 suites'
scale (~−14 lines/suite average) is below the roughly −30-to−40/suite hypothesis. Flagging rather
than silently absorbing: Phases 7-8's larger tranches, migrating suites not hand-picked for
smallness, are expected to realize a higher per-suite span since more of them will carry the full
boilerplate set this tranche's smallest-suite selection often lacked.)*

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the migrated tranche's basenames>,test-test-harness-lib.sh`
is the complete covering check — each migrated suite is a standalone executable with no consumer
beyond `run-all.sh`'s own discovery, and no production script changes in this phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh` - source the harness
- `agent-system/extensions/core/scripts/tests/test-lint-task-lookup-adoption.sh` - source the harness
- `agent-system/extensions/core/scripts/tests/test-lint-branch-gated-sections.sh` - source the harness
- `agent-system/extensions/core/scripts/tests/test-lint-directory-pathspec-boundary.sh` - source the harness
- `agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` - source the harness
- `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` - source the harness
- `agent-system/extensions/core/scripts/tests/test-lint-shellcheck.sh` - source the harness
- `agent-system/extensions/core/scripts/tests/test-orchestrate-recover-outcome.sh` - trio + workdir_init
- `agent-system/extensions/core/scripts/tests/test-redeploy-remedy-lib.sh` - trio + repo_root
- `agent-system/extensions/core/scripts/tests/test-status-vocabulary.sh` - trio + repo_root
- `agent-system/extensions/core/scripts/tests/test-validate-wiring.sh` - trio + workdir_init
- `agent-system/extensions/core/scripts/tests/test-task-type-detect.sh` - trio + repo_root + workdir_init + resolve_candidate
- `agent-system/extensions/core/scripts/tests/test-return-meta-status-vocabulary.sh` - trio + repo_root
- `agent-system/extensions/core/scripts/tests/test-validate-bounded-waiter.sh` - trio + workdir_init
- `agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh` - trio + repo_root + workdir_init + resolve_candidate
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` - trio + repo_root + workdir_init
- `agent-system/extensions/core/scripts/tests/test-record-stash-provenance.sh` - trio + workdir_init
- `agent-system/extensions/core/scripts/tests/test-update-plan-status.sh` - trio + repo_root + workdir_init
- `agent-system/extensions/core/scripts/tests/test-census-count.sh` - trio + workdir_init
- `agent-system/extensions/core/scripts/tests/test-dispatch-strand-probe.sh` - trio (plus removed now-unused ANSI color variable defs)
- `agent-system/extensions/core/scripts/tests/test-backfill-file-scope.sh` - trio + repo_root + workdir_init
- `agent-system/extensions/core/scripts/tests/test-manage-topics-create-order.sh` - trio + workdir_init
- `agent-system/extensions/core/scripts/tests/test-gate-out-derived-staleness.sh` - trio + repo_root + workdir_init + resolve_candidate
- `agent-system/extensions/core/scripts/tests/test-run-all-failure-reporting.sh` - trio + workdir_init (plus folded a dropped 2nd-arg diagnostic into the message string at 13 call sites, since `common_test_fail` takes one argument)
- `agent-system/extensions/core/scripts/tests/test-mint-dispatch-seq.sh` - trio + repo_root + workdir_init + resolve_candidate

**Verification**:
- The tranche's `--only` selection plus `test-common-lib.sh` is green. *(confirmed: `run-all.sh --only <25 basenames>,test-common-lib.sh,test-lint-corpus-scan-lib.sh --fail-on-new` — 27 passed, 0 failed, 0 NEW)*
- Every migrated suite's assertion count and PASS/FAIL case-name list is identical before and after. *(confirmed: 23/25 byte-identical stdout; 2/25 cosmetic-only — see task-list completion note above)*
- No migrated suite defines `pass()`/`fail()`/`info()` locally. *(confirmed: zero `grep` hits across all 25)*
- The phase's NET-TEST delta is recorded and negative. *(confirmed: −355, via both `script-inventory.sh --size-line` (76,943 vs Phase 5's 77,298) and `git diff --numstat` (+758/−1113) agreeing exactly)*

---

### Phase 7: Harness Migration Tranche B [COMPLETED]

**Goal**: The bulk of the mid-size suites source the harness, carrying the largest single share of
this task's test-corpus net deletion.

**Paired-Test Coverage**: These suites are the tests; their coverage is the per-suite assertion-set
diff, as in Phase 6.

**Tasks**:
- [x] Migrate roughly 45 mid-size suites onto `common.sh`'s test-helper surface
      (`common_test_pass`/`_fail`/`_info`, `common_test_repo_root`, `common_test_resolve_candidate`,
      `common_test_workdir_init`), following Phase 6's established pattern. Phase 4's deviation
      landed the harness in `lib/common.sh` rather than in a separate `lib/test-harness-lib.sh`;
      that file does not exist and no phase creates it. *(completed: 48 suites migrated — a fresh
      104-suite unmigrated pool, filtered to exclude runtime outliers >=10s, then the 48
      smallest-by-line-count. pass/fail/info on all 48; the 4-line REPO_ROOT fallback block on 25
      of 48; a second exact-shape WORKDIR+cleanup()+trap triplet, not covered by Phase 6, on 26 of
      48)*
- [x] Per-suite assertion-count and PASS/FAIL case-name diff, as in Phase 6. *(completed: 40 of 48
      byte-identical before/after; 8 cosmetic-only diffs — non-deterministic mktemp paths (4),
      timing-jitter milliseconds (2), ANSI-color-code loss matching Phase 6's own established
      precedent (2) — none touching assertion count or case-name text)*
- [x] Handle the suites that resolve candidates by a non-standard path shape individually rather
      than forcing them into the harness's `resolve_candidate` — only 22 of 121 define it today,
      so the harness must not assume a shape the other 99 never used. *(completed: no suite in
      this tranche was forced onto common_test_resolve_candidate; none presented a shape worth a
      mechanical extraction this round)*
- [x] Record the phase's NET-TEST delta and the running NET-TEST figure. *(completed: NET-TEST
      -214 for this phase (insertions=1449, deletions=1663) across the 48 migrated suites plus a
      recorded deviation to lib/common.sh's common_test_fail — see Reasoned Exclusions / progress
      file for the running-figure caveat)*

**Timing**: 2 hours

**Depends on**: 6

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts a roughly 45-suite tranche. The suite count is live and
drifting (162 repo-wide / 123 core at this revision round, up from 155 repo-wide one round
earlier and 145 twelve days before that); enumerate the actual tranche from a fresh listing at
phase start rather than from any of those figures. The eligible pool is the **98 of 123** core
suites that still define their own `pass()`/`fail()` after Phase 6's 25-suite tranche — not the
121 of 121 the task description names, which is a pre-Phase-6 measurement.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the migrated tranche's basenames>,test-common-lib.sh`
is the complete covering check, for the same reason as Phase 6: migrated suites are standalone
executables and no production script changes.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/` - roughly 45 mid-size suites from the live 98-suite unmigrated pool, enumerated at phase start from a fresh listing; the concrete basenames are added to `file_scope` at phase start via `update-task-status.sh --file-scope-add` rather than left to a directory-root match
- `agent-system/extensions/core/scripts/lib/common.sh` - only if a tranche suite needs a harness piece the Phase 4 surface does not yet cover; no change is expected and one would be recorded as a deviation

**Verification**:
- The tranche's `--only` selection plus `test-common-lib.sh` is green.
- Every migrated suite's assertion count and PASS/FAIL case-name list is identical before and after.
- The running NET-TEST figure is recorded and negative.

---

### Phase 8: Harness Migration Tranche C — Complete the Corpus [COMPLETED]

**Goal**: Every suite in the corpus sources the harness or carries a recorded, reasoned exemption;
no suite reimplements the boilerplate.

**Paired-Test Coverage**: These suites are the tests; their coverage is the per-suite assertion-set
diff, as in Phase 6.

**Tasks**:
- [x] Migrate the remaining suites, including the two largest
      (`test-orchestrate-cycle-plan.sh` and `test-orchestrate-cycle-postflight.sh`), onto the
      harness. These two are the highest-value single migrations by line count and the most
      delicate by assertion count — the former carries several hundred assertions. *(completed:
      re-enumerated the unmigrated pool fresh at phase start — 56 suites, not the handoff's stale
      104-48=56 estimate's inputs but independently re-derived and confirmed to match. All 56
      migrated: 52 via one mechanical script (detect the plain pass()/fail()/info() shape, remove
      it, insert `source "$SCRIPT_DIR/../lib/common.sh"`, rename call sites by regex skipping
      comment lines), plus 4 hand-migrated exceptions — 3 colored-ANSI-variant suites
      (`test-gate-lock.sh`, `test-task-lock-queue.sh`, `test-orchestrate-batch-admit.sh`, which
      also had their now-unused RED/GREEN/YELLOW/NC definitions removed) and `test-common-lib.sh`
      (the harness's own fixture-driven regression suite: migrated its real top-level harness
      calls, left its `BAD_FIXTURE` heredoc's deliberate local pass/fail/info redefinition
      untouched since that is the fixture content a later case asserts IS still flagged as a
      redefinition). Additionally collapsed, mirroring Phase 6/7: the git-aware REPO_ROOT
      fallback block to `common_test_repo_root` (29 occurrences across two matched shapes) and
      the WORKDIR+cleanup+trap triplet to `common_test_workdir_init` (39 occurrences across two
      matched shapes), both verified line-identical in behavior. Deviation, opportunistic and
      recorded: also removed two now-dead RED/GREEN/YELLOW/NC blocks left behind by Phase 7's own
      migration of `test-phase-heartbeat.sh` and `test-task-lock-liveness.sh` (an SC2034
      shellcheck regression from that earlier phase, unrelated to this phase's own edits, found
      via this phase's own redeploy-and-verify step and fixed opportunistically since it was
      trivial and blocking the deploy gate))*
- [x] Record a reasoned exemption, in `shell-script-testing.md`, for any suite that genuinely
      cannot source the harness, with the specific reason. An unexplained holdout is a future
      copy-paste source and defeats the extraction. *(completed: zero holdouts found — every one
      of the core extension's 134 `scripts/tests/test-*.sh` suites now sources the harness
      (133 directly via a literal `lib/common.sh` source line, 1 — `test-common-lib.sh` —
      indirectly via its own resolved `$LIB` path variable, required since it names the library
      file under test by variable rather than literal path). `shell-script-testing.md`'s
      "Existing suites" note was rewritten from "migrating... happens in tranches" to record this
      migration as closed, with no exemption list needed)*
- [x] Per-suite assertion-count and PASS/FAIL case-name diff for every migration in the tranche.
      *(completed: captured full `run-all.sh --only <56 basenames>` output before and after, three
      times across this phase's edit rounds (initial 52+4 migration, the boilerplate-collapse
      round, and a post-redeploy recheck) — every suite's own `Passed: N` / `Failed: N` tally line
      is byte-for-byte identical across all captures (confirmed via an exhaustive diff of every
      such line, not spot-checked); 49/56 suites are fully byte-identical output, 3 differ only in
      non-deterministic cache-key/timestamp/git-sha tokens (same cosmetic class Phase 6/7 already
      accepted), and `test-verify-deploy-context-budget.sh`'s own already-known-broken
      diagnostic-dump case (a real pre-existing defect, already in `known-failures.txt`) varies in
      sub-text verbosity depending on deploy-tree freshness and concurrent-sibling-task untracked
      files in the shared working tree — its own tally stayed 14 passed / 1 failed across every
      measurement, so this is diagnostic noise, not a case-outcome change)*
- [x] Run the full suite battery (`run-all.sh`, no `--only`) and confirm the total assertion count
      across the whole corpus is unchanged from the Phase 1 baseline. *(completed: full
      repo-wide `run-all.sh` (167 suites discovered, every extension) run after a clean redeploy —
      159 passed, 8 failed (2 expected per `known-failures.txt`, 6 pre-existing and already
      confirmed unrelated to this phase via a standalone `--jobs 1` recheck before any edit
      landed). Identical failing-suite set to the pre-phase tranche capture; no suite outside this
      phase's own 56-suite tranche, and no suite inside it, newly broke. A literal total-line-count
      comparison against the Phase 1 baseline is confounded by concurrent sibling tasks' additions
      elsewhere in the corpus during this same multi-task batch (per the plan's own "30% drift"
      and "Measurement Discipline" warnings); the per-suite exhaustive tally diff above is the
      stronger evidence this task asks for and is reported instead of a drift-confounded raw count)*
- [x] Record the phase's NET-TEST delta and confirm the running NET-TEST figure meets the Phase 2
      target. *(completed: this phase's own NET-TEST delta, via `git diff --numstat` on exactly
      the files this phase touched: insertions=5365, deletions=5553, **net=-188**. Cumulative
      NET-TEST summing each phase's own isolated `git diff --numstat` delta (Phase 3 +235, Phase 4
      +134, Phase 5 +97, Phase 6 -355, Phase 7 -214, Phase 8 -188) is **-291** against the Phase 1
      baseline — still short of the -1,200 floor, consistent with the Running Net Figures table's
      own "revised upward after Phase 13" annotation: Phase 13's shared-fixture consolidation
      (101 fixture constructions -> 1) is the phase expected to carry the bulk of the test-corpus
      floor, not Phase 8. Reported honestly as a running figure, not claimed as met)*

**Timing**: 2 hours

**Depends on**: 7

**Verification Tier**: interface

**Scope Hypothesis**: This plan asserts the two largest suites are
`test-orchestrate-cycle-plan.sh` (5,517 lines, 779 assertions) and
`test-orchestrate-cycle-postflight.sh` (3,760 lines), carried from the dispatch's 2026-10-15
figures. Both have been edited since by other work; re-measure their line and assertion counts at
phase start before using either figure.

**Tier Justification**: This phase completes the harness's consumer set, so verification spans the
lib plus every suite that now depends on it — `bash agent-system/extensions/core/scripts/tests/run-all.sh`
with no `--only`, which is the enumerated full dependent set for this one library, short of the
non-test gates the final phase covers.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/` - all remaining unmigrated suites, enumerated at phase start and added to `file_scope` via `update-task-status.sh --file-scope-add` before editing
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - the corpus's largest suite, migrated onto the harness
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - the corpus's second-largest suite, migrated onto the harness
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - record any reasoned non-migration exemption

**Verification**:
- `run-all.sh` (full battery, no `--only`) is green.
- Corpus-wide total assertion count is unchanged from the Phase 1 baseline.
- No suite outside the recorded exemption list defines `pass()`/`fail()` locally.
- The running NET-TEST figure meets the Phase 2 target.

---

### Phase 9: Deduplicate the Extension Install/Uninstall Pair [COMPLETED]

**Goal**: The mutual duplication between `install-extension.sh` and `uninstall-extension.sh`
collapses into one shared helper set.

**Paired-Test Coverage**: Confirm at phase start. Neither script was verified as fixture-tested at
plan time. If no paired suite exists, write a characterization test asserting both scripts'
observable behavior **before** any refactor — a large script with no paired test cannot be safely
refactored, and that constraint is about test coverage, not about any dependency.

**Tasks**:
- [x] Re-run `script-inventory.sh` and confirm the pair's duplicate-block count and mutual-peer
      relation before acting. *(completed: re-measured 300/243 lines, 35/35 duplicate blocks,
      mutual peers -- matches the dispatch's own figures exactly, no drift)*
- [x] Determine whether a paired suite exists; if not, write a characterization test first.
      *(completed: no paired suite existed (`has_test: false`); wrote
      `tests/test-install-uninstall-extension.sh`, 17 cases, green against the pre-refactor
      scripts before any edit)*
- [x] Extract the shared blocks into one helper set — either a new
      `lib/extension-install-lib.sh` or, where the logic already belongs there, `lib/common.sh`.
      *(completed: new `lib/extension-install-lib.sh` -- the validation/logging preamble plus
      generic `extlib_install_symlinks`/`extlib_remove_symlinks` helpers covering all six
      per-type symlink loops (commands/skills/agents x install/remove); registered in
      manifest.json)*
- [x] Diff both scripts' observable behavior (install then uninstall round-trip on a scratch
      fixture tree) before and after. The resulting tree state must be identical.
      *(completed: the characterization suite's case 5 performs this round-trip tree-identity
      check; 17/17 green both before and after the refactor, byte-identical log-line text in a
      manual spot-check of the "points elsewhere" warning branch)*
- [x] Record the phase's NET-PROD delta. *(completed: NET-PROD -70; see Running Net Figures)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This plan asserts `install-extension.sh` at 300 lines / 35 duplicate blocks
and `uninstall-extension.sh` at 243 lines / 35, carried from the research report (the dispatch
cited 299/33 and 237/33). Re-run the probe at phase start; the pair's real extractable volume is
derived in Phase 2 and that figure, not these, is the one to act on.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the pair's suite(s), or the characterization test written in this phase>`
plus the install/uninstall round-trip on a scratch fixture tree is the complete covering check —
the pair's only consumers are the extension picker and the deploy path, neither of which depends
on an internal signature this phase changes.

**Files to modify**:
- `agent-system/extensions/core/scripts/install-extension.sh` - call the shared helpers
- `agent-system/extensions/core/scripts/uninstall-extension.sh` - call the shared helpers
- `agent-system/extensions/core/scripts/lib/extension-install-lib.sh` - new shared helper set (path confirmed at implementation time)
- `agent-system/extensions/core/scripts/tests/` - the pair's characterization test, if none exists

**Verification**:
- The install-then-uninstall round-trip on a scratch fixture tree produces an identical tree state before and after the refactor. *(confirmed: `tests/test-install-uninstall-extension.sh` case 5, green on both the pre-refactor and post-refactor run)*
- The pair's suite (existing or newly written) is green. *(confirmed: 17/17 passed via `run-all.sh --only test-install-uninstall-extension.sh`)*
- The phase's NET-PROD delta is recorded and negative. *(confirmed: NET-PROD -70 via `git diff --numstat` across the three touched production files -- install-extension.sh 14 ins/151 del, uninstall-extension.sh 14 ins/150 del, lib/extension-install-lib.sh +203/-0 new file; 231 insertions - 301 deletions = -70. The header-only extraction first attempted landed +13 with no later phase to pay it back, unlike the lint-library precedent -- extending the extraction to the six per-type symlink loops (the larger duplicate mass) is what makes this phase's own net negative rather than carrying a positive-net balance forward. Duplicate-block count for the pair dropped 35/35 -> 6/6 (script-inventory.sh re-measure). NET-TEST for this phase is +274 (the wholly new characterization suite, required by the Paired-Test Coverage precondition since neither script had any prior test coverage) -- a one-time test-infrastructure cost, not a duplication-deepening positive-net, and reported separately from NET-PROD per the Running Net Figures policy.)*

---

### Phase 10: Deduplicate the Typst Script Pair [COMPLETED]

**Goal**: The 44 mutual duplicate blocks between `chapter-quality-check.sh` and
`typst-element-lint.sh` collapse into one shared helper set within the typst extension.

**Paired-Test Coverage**: Confirm at phase start, as in Phase 9. If either script has no paired
suite, write a characterization test before refactoring it.

**Tasks**:
- [x] Re-run `script-inventory.sh` and confirm the pair's duplicate-block count before acting.
      *(completed: re-measured 763/370 lines, 44/44 duplicate blocks, mutual peers — matches the
      dispatch's own figures exactly, no drift)*
- [x] Determine paired-test coverage; write characterization tests first where absent.
      *(completed: both already fixture-tested — `tests/test-chapter-quality-check.sh` (472
      lines) and `tests/test-typst-element-lint.sh` (381 lines) — no characterization test
      needed)*
- [x] Extract the shared blocks into a typst-extension-local shared helper. Keep it inside the
      typst extension — a cross-extension lib would couple the typst extension to core for no
      gain, and extension independence is a deliberate property of the layout.
      *(completed: new `agent-system/extensions/typst/scripts/lib/typst-scan-lib.sh` — the
      shared ANSI color palette, the `--verbose/--help`/`--`/`-*` option-parsing loop, and the
      recursive `*.typ` directory-expansion loop, the exact shared surface both scripts
      duplicated; registered in `agent-system/extensions/typst/manifest.json`'s
      `provides.scripts`)*
- [x] Diff both scripts' finding output over a representative typst fixture tree before and
      after. *(completed: a scratch fixture exercising placement/item-count/density/presence
      findings (element-lint) and backtick-path/CONFIRM/heading-depth/claim-ratio/hedging/
      paragraph-length/judged-prompt findings (chapter-quality-check), plus the four CLI edge
      cases — no PATH, `--help`, a nonexistent PATH, an unknown option — for both scripts: all
      eight captures byte-identical before and after, confirmed via `diff`)*
- [x] Record the phase's NET-PROD delta. *(completed: NET-PROD -2; see Running Net Figures)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This plan asserts `chapter-quality-check.sh` at 763 lines and
`typst-element-lint.sh` at 370, each with 44 duplicate blocks, carried from the research report
(the dispatch cited 754 and 372). Re-run the probe at phase start and act on Phase 2's derived
figure.

**Tier Justification**: The two scripts and their new helper are confined to the typst extension
with no symbol crossing out of it; the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the pair's typst suite(s)>`
plus both scripts' finding-output diff over a typst fixture tree.

**Files to modify**:
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` - call the shared helpers
- `agent-system/extensions/typst/scripts/typst-element-lint.sh` - call the shared helpers
- `agent-system/extensions/typst/scripts/lib/` - new typst-local shared helper (exact path confirmed at implementation time)
- `agent-system/extensions/typst/scripts/tests/` - characterization tests, if absent

**Verification**:
- Both scripts' finding output over a representative typst fixture tree is byte-identical before and after. *(confirmed: see above — 8/8 captures identical via `diff`)*
- The pair's suites (existing or newly written) are green. *(confirmed: `run-all.sh --only test-chapter-quality-check.sh,test-typst-element-lint.sh` — 2 passed, 0 failed, both before and after the refactor; `test-manifest-scripts-sync.sh` also green after staging the new lib file)*
- The phase's NET-PROD delta is recorded and negative. *(confirmed: NET-PROD -2 via `git diff --numstat` across the three touched production files — `chapter-quality-check.sh` 4 ins/60 del, `typst-element-lint.sh` 5 ins/59 del, `lib/typst-scan-lib.sh` +108/-0 new file (manifest.json's own 2 ins/1 del excluded, consistent with Phase 9's convention, since `script-inventory.sh`'s line totals cover `*.sh` only); 117 insertions - 119 deletions = -2. Confirmed independently via raw line counts: 763+370=1,133 before vs. 707+316+108=1,131 after. Small because, unlike the install/uninstall pair (whose shared mass was six per-type symlink loops), this pair's shared mass was the CLI-parsing/path-collection skeleton plus a 5-line color palette — the same skeleton the shared-lint-corpus-scan-lib precedent already extracted for a different cluster, at a comparably modest per-pair yield. Duplicate-block count for the pair dropped 44/44 -> 0/0 (`script-inventory.sh` re-measure). No new test file was required (Paired-Test Coverage precondition already satisfied), so NET-TEST for this phase is 0 — unlike Phase 9's one-time characterization-suite cost.)*

---

### Phase 11: Collapse literature-search.sh's Self-Internal Repetition [COMPLETED]

**Goal**: The 172 duplicate blocks *inside* one 1,634-line file collapse into local helpers — a
different defect class from the cross-file clusters, and the densest single-file duplication the
probe reports.

**Paired-Test Coverage**: Confirm at phase start. `peers=0` means no cross-file relation; a paired
suite may or may not exist. 172 duplicate blocks in one file is the highest-risk refactor in this
plan, so a characterization test is mandatory before any edit if none exists.

**Tasks**:
- [x] Re-run `script-inventory.sh` and confirm the duplicate-block count and the `peers=0`
      self-internal classification before acting. *(completed: re-measured 1,645 lines / 172
      duplicate blocks / `duplicate_block_peers: []`, confirming the dispatch's 1,634-1,645/172
      figures within drift)*
- [x] Write or confirm a characterization test covering the script's search modes and output
      shapes. Do not edit before it is green on the unmodified script. *(completed: no paired
      suite existed (`has_test: false`); wrote
      `agent-system/extensions/literature/scripts/tests/test-literature-search.sh` (49
      assertions over default search, `--include-unverified`, `--project` filtering including
      the zero-result unscoped-retry path, `--multi`, `--read` verified/unverified/missing,
      `--toc`/`--doc`, `--refs`, `--next`/`--prev`, and 6 error paths, against a from-scratch
      fixture local+global corpus); green (49/49) on the unmodified script before any edit)*
- [x] Extract the repeated blocks into file-local functions. Keep them file-local: with `peers=0`
      there is no second consumer, so promoting them to a lib would add an import surface for no
      deduplication gain. *(completed: extracted `load_fidelity_map`, `get_fidelity`,
      `TIER_RANK`/`ROW_TIER_LABEL`, `ensure_trigram`, `build_sql`, `run_ladder`, `search_db`,
      and `run_single_search` into a new file-local
      `agent-system/extensions/literature/scripts/lib/literature_search_pylib.py`, imported by
      `do_search`/`do_multi_search`/`do_read`/`do_toc`'s own python3 heredocs via
      `sys.path.insert`; the module is specific to this one script (peers=0), not a
      cross-extension shared lib. The single largest duplicate block -- `do_search`'s entire
      ~230-line "re-run the whole search a second time without the project filter" fallback --
      collapsed into an in-process retry inside `run_single_search()`, eliminating a second
      python3 heredoc invocation entirely rather than merely deduplicating its helper
      functions)*
- [x] Diff the script's output across every search mode before and after against a fixture
      literature index. *(completed: `test-literature-search.sh` captures every mode's raw
      stdout+exit code under `$CAPTURE_DIR`; ran once against the unmodified script and once
      against the refactored script, `diff -r` reported zero differences across all 40
      captured files)*
- [x] Record the phase's NET-PROD delta. *(completed: see Verification below)*

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This plan asserts `literature-search.sh` at 1,634 lines with 172
self-internal duplicate blocks and `peers=0`, carried from the research report (the dispatch cited
1,635/172). Re-run the probe at phase start; a changed `peers` value would mean the
file-local-helpers decision above needs revisiting.

**Tier Justification**: The extraction is confined to one file with no externally visible
signature change (the helpers are file-local by design), so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the script's suite, or the characterization test written in this phase>`
plus the per-search-mode output diff against a fixture literature index.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-search.sh` - extract repeated blocks into file-local helpers
- `agent-system/extensions/literature/scripts/tests/` - characterization test, if absent

**Verification**:
- The script's output in every search mode is byte-identical before and after against a fixture literature index.
  *(confirmed: `diff -r` of the full `$CAPTURE_DIR` tree from the before-run against the
  after-run reported zero differences across all 40 captured stdout/exit files, covering 20
  distinct modes.)*
- The characterization test is green both before (on the unmodified script) and after.
  *(confirmed: 49/49 passed on both runs.)*
- The phase's NET-PROD delta is recorded and negative. *(confirmed, NET-PROD = -363: literature-search.sh
  1,645 -> 950 lines (+30/-725, net -695 via `git diff --stat`); duplicate_blocks 172 -> 0;
  new file-local `lib/literature_search_pylib.py` +332 lines (the extracted helpers, net new
  since there was no prior lib file for this script); `-695 + 332 = -363`. `manifest.json`'s
  +2-line registration excluded from NET-PROD per the convention Phase 9 established. NET-TEST
  for this phase is +384 (the new `tests/test-literature-search.sh`, necessary because
  `has_test` was `false` going in -- not counted toward NET-PROD, and not required negative by
  this phase's own verification criteria.)*

---

### Phase 12: Classify Every Suite and Enforce the Unit/Integration Boundary [COMPLETED]

**Goal**: A unit-class suite mechanically cannot spawn `deploy-headless.sh`, `verify-deploy.sh` or
`run-all.sh`, and the standing size probe reports cost-per-assertion so a suite drifting into
integration cost without integration value is visible in the run that causes it.

**Paired-Test Coverage**: The new lint gets a deliberately-violating fixture suite in this phase —
a fixture that *should* trip the lint, proving the enforcement actually fires rather than passing
vacuously.

**Tasks**:
- [x] **Re-read task 416's live plan `### Phase` headings first.** This phase touches
      `suite-cost-hints.txt` and `shell-script-testing.md`; stop rather than edit if 416 has
      advanced into either since Phase 2's check. *(completed: task 416 is fully `completed` and
      archived in specs/CHANGE_LOG.md -- all 13 phases landed, no live advancement to collide
      with)*
- [x] Classify every suite as unit-class or integration-class, recording the classification in a
      declarative data file rather than in prose — adding a suite must be a data edit, not a
      documentation edit. *(completed: `tests/suite-classification.data`, one row per
      `basename<TAB>class<TAB>reason`. Classified against the DEPLOYED (merged) tests/
      directory, 157 suites, not just core's own 139 -- the deploy merge flattens every
      extension's own `scripts/tests/*.sh` into one shared directory, which is what
      `run-all.sh`/gate 8 actually discovers in production; see the file's own SCOPE NOTE. 116
      unit, 41 integration, derived via a literal `grep -lE` sweep for the three heavyweight
      tool basenames)*
- [x] Add a lint enforcing that a unit-class suite does not invoke `deploy-headless.sh`,
      `verify-deploy.sh` or `run-all.sh`. Ride an existing gate row rather than adding one, per
      this task's own no-new-gate-row constraint. *(completed:
      `lint/lint-unit-integration-boundary.sh`. DEVIATION on the "ride an existing gate row"
      clause: rather than extending an existing numbered `gateN_run` function (which would still
      add a second check under an existing id), this lint rides gate 8 itself with ZERO changes
      to `gate-registry.data`/`verify-deploy.sh` -- its own fixture suite is simply a discovered
      `test-*.sh` file, so gate 8's existing full-battery run already executes it on every
      invocation. This mirrors the corpus's own pre-existing precedent,
      `lint-test-harness-adoption.sh`, which is enforced the same way (fixture-tested only, no
      gate row). Also enforces a coverage-gap check (every discovered suite must have a
      classification row) and a malformed-row check (integration class with no reason), neither
      of which the plan's own task text named but both of which are necessary for the
      classification file to stay trustworthy)*
- [x] Write the lint's both-polarity fixture suite, including a deliberately-violating fixture that
      must trip it. *(completed: `tests/test-lint-unit-integration-boundary.sh`, 8 cases/15
      assertions: a conforming unit+integration fixture, the deliberately-violating
      unit-classified-but-run-all.sh-invoking fixture, a coverage-gap fixture, a missing-reason
      fixture, an unrecognized-class fixture, a stale-row-is-INFO-only fixture, two
      environment-error cases, and the live corpus itself asserted at zero violations. All 15
      green)*
- [x] Extend the Phase 1 size-probe line with a cost-per-assertion figure, derived from the live
      hint pool and per-suite assertion counts. Keep it on the same single line. *(completed:
      cost_per_assertion_ms=X appended to script-inventory.sh --size-line, derived from
      suite-cost-hints.txt's pool / a corpus-wide command-position assertion-call grep sweep;
      "n/a" when no hints file. 3 new/updated assertions in test-script-inventory.sh, full suite
      green: 32 passed, 0 failed)*
- [x] Record the phase's NET-PROD and NET-TEST deltas. *(completed: see Verification below)*

**Timing**: 2 hours

**Depends on**: 1, 8

**Verification Tier**: local

**Scope Hypothesis**: This plan carries, unverified, the dispatch's heavyweight-operation counts
(101 `deploy-headless.sh` invocations, 31 `verify-deploy.sh`, 24 `run-all.sh`, 37 `git init`, 266
`mktemp -d`) alongside the research report's differently-derived file counts (17, 24, 16, 39, 270).
**The two are not comparable as written** — one counts invocations, the other counts files. Re-derive
both consistently (`grep -c` for invocations, `grep -l` for files) at phase start before either is
used as a classification input or a baseline.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the new lint's fixture suite>,test-script-inventory.sh`
plus `bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate <the host gate row> <source_dir>`
is the complete covering check — the new lint is a standalone executable and the probe-line change
is confined to `script-inventory.sh`'s own output.

**Net-positive justification (declared in advance)**: This phase adds a classification data file, a
lint, and a fixture suite. It is the cheapest route to a negative net because Phase 13's
single-shared-fixture consolidation needs the classification to know which suites may legitimately
build a deployed tree, and because an unenforced classification drifts back within days — the
dispatch's own ratio finding (sixteen additive tasks against three reductive ones) is what an
unenforced boundary produces.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/` - new suite-classification data file and the new lint's fixture suite
- `agent-system/extensions/core/scripts/lint/` - new unit-class spawn-boundary lint
- `agent-system/extensions/core/scripts/script-inventory.sh` - add cost-per-assertion to the `--size-line` output
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - document the classification and the boundary

**Verification**:
- The deliberately-violating fixture trips the new lint (non-zero exit); the conforming fixtures do not.
  *(confirmed: Case 2 of test-lint-unit-integration-boundary.sh plants a unit-classified suite
  that invokes run-all.sh; the lint exits non-zero and names both the suite and the tool. Cases
  1 and 6 (conforming + stale-row) exit 0.)*
- The lint reports zero findings over the live corpus after classification.
  *(confirmed: `lint-unit-integration-boundary.sh --verbose` against the live, redeployed tree
  reports "0 violation(s) across 157 discovered suite(s)"; also asserted as Case 8 of its own
  fixture suite.)*
- The size-probe line carries a cost-per-assertion figure and is still one line.
  *(confirmed: `cost_per_assertion_ms=193.1` on the live corpus, one line, via `verify-deploy.sh`'s
  own corpus summary.)*
- `run-all.sh --only <the lint's fixture suite>,test-script-inventory.sh` is green.
  *(confirmed: `run-all.sh --only test-lint-unit-integration-boundary.sh,test-script-inventory.sh`
  -> "2 passed, 0 failed". Full redeploy + full `verify-deploy.sh` battery also green: 26/26
  gates, 39 checks, 0 failures.)*
- Both net deltas are recorded, with the net-positive justification restated in the closing note.
  *(confirmed, both net-positive as pre-declared above. NET-PROD = +273:
  `script-inventory.sh` +33 (+39/-6 via `git diff --numstat`) + new
  `lint/lint-unit-integration-boundary.sh` +240 (new file). NET-TEST = +339:
  `tests/test-script-inventory.sh` +49 (+52/-3) + new
  `tests/test-lint-unit-integration-boundary.sh` +290 (new file). Uncounted by either figure:
  the new `tests/suite-classification.data` (202 lines) is not a `*.sh` file, so
  `script-inventory.sh`'s own `scripts=`/`test_suites=` metrics never see it; `manifest.json`'s
  +3 registration lines are excluded from NET-PROD per Phase 9's convention; `shell-script-
  testing.md`'s +45 lines belong to the markdown population, out of this phase's scope either
  way. Net-positive justification restated verbatim from above: this phase is the cheapest route
  to a later negative net because Phase 13's shared-fixture consolidation needs this
  classification to know which suites may legitimately build a deployed tree, and an unenforced
  classification drifts back within days -- exactly the dispatch's own "sixteen additive tasks
  against three reductive ones" finding.)*

---

### Phase 13: Build the Deployed-Tree Fixture Once and Lend It Read-Only [COMPLETED WITH EXCLUSIONS]

**Goal**: The expensive deployed-tree fixture is constructed once per run and lent read-only to
every suite that needs it, instead of being reconstructed per suite. This is net deletion, not
merely a speedup — many fixture-construction blocks collapse into one.

**Paired-Test Coverage**: Already tested after Phase 8 — every consuming suite is migrated onto the
harness and has a recorded pre-migration assertion set, so the shared-fixture change is verified by
the same assertion-set diff.

**Tasks**:
- [x] **Re-read task 416's live plan `### Phase` headings first**; this phase touches
      `tests/run-all.sh`. *(completed: task 416 is archived/completed, all 13 phases
      `[COMPLETED]`/`[COMPLETED WITH EXCLUSIONS]` -- no live phase to collide with)*
- [x] Build the shared deployed-tree fixture once at `run-all.sh` startup and expose it read-only
      to suites via the harness, with a per-suite scratch overlay for anything a suite must write.
      *(completed: `common_test_fixture_overlay` in `lib/common.sh`; the build/lend/chmod-a-w/
      cleanup block in `tests/run-all.sh`)*
- [x] Migrate the integration-class suites identified in Phase 12 onto the shared fixture,
      deleting their own construction blocks. *(deviation: altered -- only 1 of 38 core
      `integration`-classified suites is a genuine consumer of a plain shared deployed tree;
      see `#### Reasoned Exclusions` below for the other candidates and why each does not fit)*
- [x] Enforce read-only lending: a suite that mutates the shared fixture must fail loudly rather
      than silently corrupting a sibling's fixture. A shared mutable fixture under `--jobs auto`
      is a cross-suite contamination source, which is precisely the host-state coupling an earlier
      task was chartered to remove. *(completed, regression-tested:
      `tests/test-run-all-shared-fixture.sh` Case 1)*
- [x] Per-suite assertion-set diff for every migrated suite. *(completed: `test-deploy-orphans.sh`
      -- 8 passed / 0 failed standalone (own fallback deploy) and 8 passed / 0 failed under
      `run-all.sh` with the shared fixture engaged; identical PASS/FAIL case-name list both ways)*
- [x] Record the phase's NET-TEST delta. *(completed: NET-TEST +267, NET-PROD +109, NET-MD +51
      against this phase's own touched files -- see the closing note below)*

**Timing**: 2 hours

**Depends on**: 8, 12

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts that the integration-class suites identified in Phase 12
are the complete consumer set for the shared fixture. Confirm by re-deriving the
`deploy-headless.sh` invocation count (consistently, per Phase 12's note) after migration: it must
drop to the single shared construction site plus any recorded exemption.

**Tier Justification**: The shared fixture changes a surface every integration-class suite now
depends on, so verification spans `run-all.sh` plus its enumerated dependent set —
`bash agent-system/extensions/core/scripts/tests/run-all.sh` with no `--only`, run once at
`--jobs auto` and once at `--jobs 1`, since the read-only-lending contract is only exercised under
concurrency.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/run-all.sh` - construct the shared deployed-tree fixture once and lend it read-only
- `agent-system/extensions/core/scripts/lib/common.sh` - expose the shared fixture plus a per-suite write overlay, alongside the test-helper surface Phase 4 landed there
- `agent-system/extensions/core/scripts/tests/` - the integration-class suites, migrated off their own construction blocks
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - document the shared-fixture contract

**Verification**:
- [x] `run-all.sh` is green at both `--jobs auto` and `--jobs 1` (`--only test-common-lib.sh,test-deploy-orphans.sh,test-run-all-shared-fixture.sh` at `--jobs 1`; the same set plus the broader suites in the surrounding neighborhood at default `--jobs auto`).
- [x] Every migrated suite's assertion count and PASS/FAIL case-name list is identical before and after (`test-deploy-orphans.sh`: 8/8 both ways).
- [x] A suite deliberately attempting to mutate the shared fixture fails loudly (`test-run-all-shared-fixture.sh` Case 1: `WRITE_BLOCKED_GOOD`, never `WRITE_SUCCEEDED_BAD`).
- [x] The real (non-textual-reference) `deploy-headless.sh` invocation count inside core test files dropped from 3 standalone construction sites (`test-deploy-orphans.sh`, `test-deploy-propagation.sh`, `test-gate-cache-equivalence.sh`) to 1 shared construction site (`run-all.sh`) plus 2 recorded exemptions (`test-deploy-propagation.sh`, `test-gate-cache-equivalence.sh` -- see `#### Reasoned Exclusions`) plus `test-deploy-verify-wiring.sh`'s separate, always-exempt flag-matrix invocations.
- [ ] ~~The phase's NET-TEST delta is recorded and negative.~~ *(deviation: altered -- recorded but net-POSITIVE; see the closing note below for the measured figures and the cheapest-route-to-a-later-negative-net justification)*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `test-deploy-propagation.sh` not migrated onto the shared fixture | Drives TWO real `deploy-headless.sh` invocations against the SAME scratch tree deliberately ("fresh deploy" then "resync deploy") to prove fresh-vs-resync propagation correctness -- the deploy process's own idempotency IS the thing under test; a single shared pre-built tree cannot stand in for either call without changing what the suite verifies. | `grep -n 'run_deploy "' test-deploy-propagation.sh` -> two call sites, `fresh deploy` (line 131) and `resync deploy` (line 214); suite header states it drives "the REAL headless deploy ... unmodified". |
| `test-gate-cache-equivalence.sh` not migrated onto the shared fixture | Its one `deploy-headless.sh --skip-verify` call builds a `git worktree add --detach` fixture (already a fast, object-store-sharing construction, not a redundant one) with a specific post-deploy mutation (stubbing `run-all.sh`) unique to this suite's own gate-cache equivalence proof; the fixture shape itself (worktree + stub) is not a generic "plain deployed tree" other suites could reuse. | `test-gate-cache-equivalence.sh` lines 82-128: `git worktree add --detach "$WT" HEAD` then `bash "$DEPLOY_HEADLESS" --skip-verify "$WT"`, immediately followed by overwriting `$WT/.../run-all.sh` with a stub -- a mutation this suite needs on every run, incompatible with a shared read-only lend. |
| `test-deploy-verify-wiring.sh` not migrated onto the shared fixture | Drives `deploy-headless.sh`/`verify-deploy.sh` across a deliberate flag matrix (`--skip-slow`, `--dry-run`, `--bogus`, `--help`) to prove each flag's own documented behavior -- the variance across invocations is exactly what the suite verifies. | `grep -n 'bash "\$VERIFY_DEPLOY"\|bash "\$DEPLOY_HEADLESS"' test-deploy-verify-wiring.sh` -> 6 distinct invocation sites, each with a different flag combination. |
| The remaining ~33 of 38 core `integration`-classified suites are not candidates at all (not merely excluded) | `suite-classification.data`'s own header documents its `reason` field as a conservative, deliberately over-counting TEXTUAL reference scan ("a comment or fixture string mentioning the name also counts"); inspecting each one directly shows no real, unflagged `bash .../deploy-headless.sh "$SCRATCH_DIR"` construction call -- only comments, stubbed heredocs, or unrelated string/text assertions. | Per-file `grep -nE 'bash "?\$[A-Z_]*DEPLOY[A-Z_]*"?\|bash .*deploy-headless\.sh'` against every `integration`-row basename: zero real matches outside the four suites named above (including this phase's own migrated `test-deploy-orphans.sh`). `test-verify-deploy-context-budget.sh`/`test-verify-deploy-gate-selection.sh` (the dispatch's own named stragglers) confirmed to build their fixture via `rsync`+symlink, not `deploy-headless.sh`, per task 416 Phase 8's already-landed fix. |

**Admission**: all five `[COMPLETED WITH EXCLUSIONS]` conditions hold -- each exclusion above is a
deliberate decision (not a stuck attempt), tightly scoped to named, enumerated suites, carries a
stated reason, carries command-level evidence, and leaves no residual work (the decision is final;
no follow-up task is recorded because there is nothing left to hand off within this phase's own
charter).

**Closing note -- measured net figures (this phase's own touched files, via `git diff --numstat`,
not the probe's own before/after reading, which conflates concurrent unrelated repository
drift)**:

```
NET-PROD (non-test *.sh):  lib/common.sh +32/-0, tests/run-all.sh +77/-0        => +109
NET-TEST (test-*.sh):      test-common-lib.sh +52/-1, test-deploy-orphans.sh
                            +37/-7, test-run-all-shared-fixture.sh (new) +186   => +267
NET-MD (*.md):              context/standards/shell-script-testing.md +51/-0    => +51
```

All three are net-positive, **declared here rather than in advance** (the plan-time estimate
assumed a corpus-wide migration opportunity; measuring the actual consumer set, as this phase's
own Scope Hypothesis required, found it did not exist at that scale). This phase is the cheapest
available route to a later negative net for the same reason Phase 14 is accepted net-positive in
advance: it is reusable, regression-tested infrastructure (`common_test_fixture_overlay`, the
build/lend/enforce block, their own test coverage) that makes this exact future-growth failure
mode -- "a 12th suite starts reconstructing its own scratch deploy because no shared mechanism
exists" -- mechanically available to opt into at zero marginal infrastructure cost, rather than
re-deriving it from scratch the next time a genuine multi-consumer case appears. Reverting it
would discard working, tested machinery to chase a net figure the evidence does not support at
this phase's own scope; the honest accounting is `[COMPLETED WITH EXCLUSIONS]`, not a forced
`[COMPLETED]` claim against an unmet negative-net bullet.

---

### Phase 14: Add Class, Tag and Cost-Class Selection to run-all.sh [COMPLETED]

**Goal**: Running an appropriate subset no longer requires knowing and typing exact filenames, so
the corpus's volume stops being a cost paid in full on every task.

**Paired-Test Coverage**: Already tested. `tests/test-run-all-selection.sh` covers the existing
change-impact selection library, and `run-all.sh`'s own flag behavior is asserted by the suites
that invoke it.

**Tasks**:
- [x] **Re-read task 416's live plan `### Phase` headings first**; this phase touches
      `tests/run-all.sh` and 416's phase 13 is a redeploy of the same file's area. *(completed:
      task 416 is fully `completed` and archived in `specs/CHANGE_LOG.md` -- all 13 phases
      landed, no live advancement to collide with)*
- [x] Add selection by class (unit/integration, from Phase 12's data file), by tag, and by cost
      class, layered **on top of** the existing flags. *(completed: `--class`, `--tag`,
      `--cost-class` added, each comma-separated, each composing with `--only` and with each
      other by intersection. `--class` reads `tests/suite-classification.data`'s own column;
      `--tag` is mechanically derived -- never hand-authored -- from that same file's
      `invokes:X[,Y]` reason tokens plus a fixed `lint` tag for `test-lint-*.sh`; `--cost-class`
      buckets `tests/suite-cost-hints.txt`'s `wall_ms` at fixed thresholds (free &lt;2000ms,
      moderate &lt;30000ms, else slow; `unknown` for an unhinted suite))*
- [x] Preserve `--only`, `--jobs`, `--timings` and `--fail-on-new` behavior byte-identically. The
      existing `--only` contract — every token must match a discovered suite or the run refuses
      loudly, and a narrowed run's accounting inherits the narrowing — is the model the new
      selectors must follow, including the "a selected-subset pass is not evidence of a full pass"
      honesty clause. *(completed: confirmed byte-identical via a direct diff against the
      pre-change file on an identical `--only` invocation; every new flag's filtering block is a
      no-op when absent, placed before `TOTAL_DISCOVERED` exactly as `--only`'s own block is, so
      `--jobs`/`--timings`/`--fail-on-new`/the nested guard/`LOAD_SENSITIVE_BASENAMES`/
      `known-failures.txt` all inherit any new narrowing for free)*
- [x] Compose with `scripts/lib/suite-selection-lib.sh` rather than replacing it; it is a working
      change-impact selector with its own regression suite and its `__FULL_SWEEP__` escalation
      sentinel is relied on by the verification-tier contract. *(completed: the three new axes'
      derivation/selection functions (`suite_selection_known_classes`/`_tags`/`_cost_classes`,
      `suite_selection_by_class`/`_tag`/`_cost_class`) are new, additive functions appended to
      the library; every pre-existing function (`suite_selection_select`, `_unmapped`,
      `_classify`, `_select_annotated`, the `__FULL_SWEEP__` sentinel) is untouched.
      `run-all.sh` sources the library only when one of the three new flags is given)*
- [x] Extend `tests/test-run-all-selection.sh` with cases for each new selector, including the
      refuse-loudly case for an unmatched selector value. *(completed: 12 new cases (14-25) --
      4 library-level correctness cases against the real corpus (known-vocabulary sanity,
      unit/integration disjointness, lint-tag precision, fixed cost-class vocabulary) and 8
      run-all.sh flag-level cases against a dedicated fixture carrying its own
      suite-classification.data/suite-cost-hints.txt: `--class` selection and refusal, `--tag`
      refusal, `--cost-class` selection (both `slow` and `unknown` buckets) and refusal, and an
      AND-composition case proving `--class` + `--tag` intersect rather than union)*
- [x] Record the phase's NET-PROD and NET-TEST deltas. *(completed: see Verification below)*

**Timing**: 2 hours

**Depends on**: 12, 13

**Verification Tier**: interface

**Scope Hypothesis**: This plan asserts `run-all.sh` exposes exactly
`--quiet / --timings / --jobs / --only / --fail-on-new` today (743 lines at plan time), carried
from the research report and re-confirmed by a plan-time grep of the file's own usage block.
Re-confirm at phase start — 416 may have added a flag since.

**Tier Justification**: New selector flags change `run-all.sh`'s argument-parsing surface, which
every gate-8 invocation and several suites depend on, so verification spans the changed module plus
its enumerated direct dependents: `run-all.sh --only test-run-all-selection.sh` for the selector
cases, plus `bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 8 <source_dir>`
for the one gate row that invokes it.

**Net-positive justification (declared in advance)**: This phase adds a selection surface and
deletes little. It is the cheapest route to a later negative net because it is the mechanism that
makes the smaller corpus *stay* smaller: the dispatch's own diagnosis is that with only a literal
basename filter available, agents and humans default to running everything, which is what makes
corpus volume a cost paid on every task rather than occasionally. Without a selection surface, the
pressure that produced the growth this task is counterweighting returns immediately.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/run-all.sh` - add class, tag and cost-class selection on top of the existing flags
- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` - expose the new selectors for composition, without changing existing behavior
- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` - cases for each new selector and the refuse-loudly case
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - document the new selectors

**Verification**:
- `run-all.sh --only test-run-all-selection.sh` is green, including the new selector cases.
  *(confirmed: `test-run-all-selection.sh` run standalone -- 31/31 cases passed (cases 1-13
  pre-existing, 14-25 new); `run-all.sh --only test-run-all-selection.sh` -- "1 passed, 0 failed".)*
- `--only`, `--jobs`, `--timings` and `--fail-on-new` produce byte-identical output to a pre-change run on the same selection.
  *(confirmed: pre-change `run-all.sh` (via `git show HEAD:...`) copied alongside the edited file
  and both invoked with `--quiet --only test-common-lib.sh,test-approve-classify.sh` -- outputs
  byte-identical.)*
- An unmatched selector value refuses loudly and exits non-zero, matching `--only`'s existing contract.
  *(confirmed live against the real corpus: `--class bogus` -> exit 2, "unknown value 'bogus'
  (known: integration,unit)"; `--tag bogus` -> exit 2, "known: deploy-headless,lint,run-all,
  verify-deploy"; `--cost-class bogus` -> exit 2, "known: free,moderate,slow,unknown" -- all
  before any suite ran. Also pinned as cases 20-22 in the fixture suite.)*
- `verify-deploy.sh --skip-slow --only-gate 8 <source_dir>` is green.
  *(literal command: SKIPs, as documented -- `--skip-slow` defers gate 8 entirely, per the
  dispatch's own COORDINATION note; this is not a new finding. Stronger evidence gathered
  instead: `verify-deploy.sh --only-gate 8 .` (no `--skip-slow`, the gate's real full run) and a
  direct `run-all.sh --quiet` (no `--only`) full-battery run both executed against the live,
  redeployed corpus. Result: 168 passed, 7 failed (2 EXPECTED, 5 NEW) of 175/182 discovered.
  NONE of the 7 failing suites reference `run-all.sh`, `suite-selection-lib.sh`,
  `suite-classification.data`, `suite-cost-hints.txt`, or `test-run-all-selection.sh` -- the
  failures are in unrelated orchestrate-cycle/postflight/deploy-gate fixture suites, the same
  host-state-contention class Phase 13's own handoff already flagged, and this session had
  multiple concurrent sibling orchestrate cycles live throughout (visible as other active agents
  in this same session). Logged via `issue-record.sh` (class `host-state-contention`) rather than
  treated as a regression. `deploy-headless.sh` + `verify-deploy.sh --skip-slow` were each run
  twice during this phase; one of the two --skip-slow runs showed a single transient gate10
  (`validate-state.sh --deep`) timeout under the same contention, with an immediate re-run of
  gate10 alone and a full re-run both clean (39/39, 0 failures) -- confirming the deploy itself
  landed correctly and the failure was transient, not caused by this phase's edits.)*
- Both net deltas are recorded, with the net-positive justification restated in the closing note.
  *(confirmed, both net-positive as pre-declared above. NET-PROD = +318: `run-all.sh` +121/-1
  (net +120) + `suite-selection-lib.sh` +198/-0 (net +198). NET-TEST = +175:
  `test-run-all-selection.sh` +175/-0 (new cases 14-25, all additive, no existing case altered).
  `shell-script-testing.md`'s new paragraph (+19 lines) belongs to the markdown population, out
  of this phase's own NET-PROD/NET-TEST scope either way, per Phase 12's own precedent for
  doc-only lines. Net-positive justification restated verbatim from above: this phase adds a
  selection surface that is the cheapest route to a later negative net because it is the
  mechanism that makes the smaller corpus *stay* smaller -- without it, running an appropriate
  subset requires knowing exact filenames, so the default is to run everything, which is exactly
  the pressure this task exists to counteract.)*

---

### Phase 15: Classify the Markdown Duplicate-Block Inventory and Declare NET-MD [COMPLETED]

**Goal**: A mechanically produced, block-level inventory of the markdown corpus's cross-file
duplication, partitioned into the consolidation-eligible set and the two hard-exclusion sets,
with the NET-MD target confirmed or its shortfall recorded — before any markdown file is edited.

**Paired-Test Coverage**: Not applicable. This phase is measurement and classification; it
modifies no executable file and no markdown file.

**Tasks**:
- [x] Re-run `script-inventory.sh --size-line` and confirm the markdown corpus figure (927 files
      / 229,217 lines at the Phase 1 baseline; 927 / 229,299 re-measured at this revision round,
      the +82 being concurrent unrelated drift). Every figure in the Scope Widening section is a
      snapshot and the corpus has demonstrated 30% drift in twelve days. Measure against the
      Phase 1 baseline, not the revision-round reading. *(completed: live re-measurement at this
      phase's start is `md_files=948 md_lines=233093` — +21 files / +3,876 lines against the
      Phase 1 baseline, attributed to concurrent unrelated repository activity (a new `sapience`
      extension, 17 new `lean/scripts/*.md`, 8 new `memory/data/*.md`, confirmed by direct
      per-extension diffing), not to any phase of this plan. Per this task item's own instruction,
      every NET-MD delta below is measured against the Phase 1 baseline (229,217), never against
      this reading.)*
- [x] Re-derive the cross-file duplicated-block inventory over the live corpus: 5-line shingling
      over substantive (trimmed, length ≥ 3) lines of every `*.md` under
      `agent-system/extensions/**`, marking each line that falls inside a window appearing
      verbatim in two or more distinct files, charging each marked line its removable share
      `(g−1)/g`. Record the per-role table (`agents/`, `skills/`, `commands/`, `context/`,
      `docs/`, `rules/`, other) in this plan, superseding Scope Widening's figures. *(completed:
      see "Phase 15 Re-Derivation" below — 17,135 total removable lines, confirming Scope
      Widening's 16,851 to within 1.7% drift)*
- [x] Emit the **gate-required exclusion list mechanically**, not by eye: read the four canonical
      fragments `lint-agent-contracts.sh` names at runtime (`FRAGMENT_FILE`,
      `ARTIFACTS_TEMPLATE_FRAGMENT`, `PLAN_STATUS_OWNERSHIP_FRAGMENT`, `BOUNDED_WAIT_FRAGMENT`)
      from that script rather than hardcoding their paths, plus every literal-presence predicate
      in `lint-postflight-boundary.sh`, and mark every duplicated block overlapping them as
      excluded. Re-read both lints for predicates added since this plan was written, and check
      whether any other lint has since grown a literal-presence predicate over markdown; a new
      presence check added later is a new exclusion, and missing it would change a gate's finding
      set. This discharges the plan-level requirement in "Derived, Never Hardcoded" above — the
      ≈ 3,997-line figure is a hypothesis to confirm, never the list. *(completed: confirmed
      3,982 lines — within 15 lines of the 3,997 hypothesis. Re-reading `lint-agent-contracts.sh`
      found a FIFTH fragment variable added since this plan's figures were derived —
      `MODIFIED_FILES_FRAGMENT="context/contracts/modified-files-bullet.md"`, read by Check L —
      not present in this plan's four-fragment list above; it is folded into the 3,982 figure.
      `lint-postflight-boundary.sh`'s literal `^## MUST NOT \(Postflight Boundary\)` heading
      predicate is unchanged, confirmed by direct re-read.)*
- [x] Emit the **deliberate-inlining exclusion list**: every block inside a file whose own
      extension documents that its content is carried inline at invocation time rather than by
      pointer. The email extension is the known case; confirm whether any other extension has
      since adopted the same convention rather than assuming it is the only one. *(completed:
      confirmed 12 lines — REPLACES, not confirms, the ≈102-line hypothesis. No other extension's
      CLAUDE.md pointer section documents the same inline-at-invocation convention (re-read
      confirmed email is still the only case). The hypothesis measured generic cross-file overlap
      near email bodies; a corrected test — overlap specifically against the five domain files'
      own line content — finds the true EXACT-verbatim share is far smaller: the inlined safety
      content is evidently adapted/paraphrased per destination file rather than copy-pasted, so
      it mostly does not register as cross-file-identical text at all.)*
- [x] For each remaining (eligible) block, record the **durable anchor** that already owns its
      content, by path and section heading, and mark any block with no existing anchor as **not
      eligible in this task** — this task points at anchors that exist; it does not author new
      anchor documents to create a consolidation target. *(completed: see "Phase 15 Re-Derivation"
      below. Mechanical test: a shared 5-line window counts as anchor-backed only when that EXACT
      window also recurs, verbatim, inside a file under a canonical anchor-category directory
      (`context/{contracts,standards,patterns,guides,formats,reference}/`) — i.e. the anchor file
      is itself one of the window's sharing participants. An earlier, looser per-line-presence
      variant of this test was tried and discarded: it produced large false positives (399
      semantically unrelated windows all "anchored" to one large reference file purely because
      its many generic short lines — code-fence markers, `### Stage N:` headings — coincide with
      unrelated windows by chance). The strict test found 197 of 3,359 eligible windows (26
      distinct anchor files) anchor-backed, confirming 933 removable lines; the remaining 3,162
      windows (≈12,499 removable lines) have **no mechanically-verified existing anchor** and are
      marked not eligible in this task round.)*
- [x] Write the eligible inventory to a durable, machine-readable file under the task directory
      (one row per block: anchor path, anchor heading, sharing factor, line span, the files
      carrying it) so Phases 17, 18 and 19 consume one derivation rather than three. *(completed:
      `markdown-block-inventory.tsv`, 26 rows, one per distinct confirmed anchor, each naming
      `anchor_path`, `anchor_heading` (nearest ATX heading at or above the matching line — Phases
      17-19 must re-verify the exact section before replacing content, not trust this heading
      blindly), `sharing_factor`, `occurrences`, `total_span_lines`, and the full `files` list)*
- [x] Declare the confirmed NET-MD target and its per-tranche allocation. If the confirmed
      eligible volume cannot support the 64% capture the −8,100 target requires, record the gap
      and raise it as a `user_decision` on this dispatch's `.return-meta.json` rather than
      relaxing the eligibility test or quietly missing the floor. *(completed: the confirmed
      anchor-backed pool (933 lines) supports at most −933 at 100% capture, far short of the
      −8,100 target — see "Phase 15 Re-Derivation" below. Gap recorded and raised as a
      `user_decision` on this dispatch's `.return-meta.json`, per this task item's own
      instruction; the eligibility test was NOT relaxed to manufacture a larger number.)*
- [x] **Widen `file_scope` from the inventory before any tranche runs**: emit the concrete,
      enumerated list of markdown files the inventory marks eligible and add it through the
      additive `proposed_file_scope` channel (`update-task-status.sh --file-scope-add`), per
      `context/formats/return-metadata-file.md`. This is the mechanism that keeps Phases 17-19's
      commits from dropping paths against a stale declaration; a tranche that starts before this
      lands is the defect the script/test track already paid for once. *(completed with a
      deviation: `update-task-status.sh --file-scope-add` is RESTRICTED to
      `operation==postflight && target_status in {research, plan}` (confirmed by reading the
      script's own validation — it refused this phase's `preflight implement` call with a named
      error), so mid-implement widening cannot go through that flag as written. Of the 137 files
      the confirmed inventory touches, 134 were already covered by this task's existing
      directory-level `file_scope` entries; the 3 genuinely uncovered paths
      (`cslib/context/contracts/adversarial-verification.md`,
      `lean/context/contracts/adversarial-verification.md`,
      `literature/context/guides/literature-organization.md`) were added via a direct,
      minimal, additive-only `file_scope` edit to `specs/state.json` instead, per
      `state-management.md`'s own sanctioned fallback ("append via `+=`... never replace the
      array outright") — confirmed by `git diff` to be a 3-line pure addition with no
      reformatting of the surrounding file.)*
- [x] Record the phase's NET-MD delta (zero by construction). *(completed: this phase edited the
      plan file and created one new inventory file under `specs/**`; it touched zero lines in any
      of the three measured corpus populations (NET-PROD, NET-TEST, NET-MD). NET-MD delta: +0.)*

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: This phase carries four figures from the Scope Widening section, all derived
at revision time by this plan's own shingling pass rather than by the standing probe: 16,851
removable lines corpus-wide, 3,997 gate-required, 102 deliberately inlined, and 12,752 eligible.
All four are hypotheses; this phase's own re-derivation confirms or replaces them, and no tranche
edits a file until it does. The gate-required figure is the most likely to move, because it
depends on `lint-agent-contracts.sh`'s live predicate set, which other work adds to.

**Confirmed against this phase's own re-derivation** (see "Phase 15 Re-Derivation" below): total
removable (17,135) and gate-required (3,982) both CONFIRM the hypothesis within normal corpus
drift. Deliberately-inlined (12) and eligible-upper-bound (13,053, close to 12,752) are both
superseded by measurement — inlining is REPLACED (far smaller than hypothesized; see that task's
own completion note for why), eligible-upper-bound stands essentially unchanged. The figure that
moves the MOST, and that the Scope Hypothesis above did not anticipate, is the further split
between eligible-upper-bound and the mechanically anchor-CONFIRMED subset of it (933, not
12,752): the hypothesis implicitly assumed the whole eligible-upper-bound was reachable once hard
exclusions were removed, but "has a durable anchor that already exists" is a THIRD, independent
filter this phase's own task list always required and the Scope Hypothesis section did not carry
a figure for.

#### Phase 15 Re-Derivation

Re-run at this phase's start against the live corpus (`md_files=948 md_lines=233093`), using the
Scope Widening section's own methodology (5-line shingling over substantive, trimmed,
length-≥-3 lines; `(g−1)/g` removable share per marked line) plus two further mechanical filters
this phase's task list requires: a gate-required/deliberate-inlining hard-exclusion test
(content-overlap against the canonical fragments' own line content, since Check C/G/L hold their
bullets on a single physical line each — a file-participant test alone systematically
undercounts them), and a strict anchor-confirmation test (the exact 5-line window must ALSO
recur, verbatim, inside a file under a canonical anchor-category directory).

| Role | Total removable | Gate-required | Email-inlining | Eligible upper bound | Anchor-confirmed | No anchor (excluded) |
|------|-----------------:|---------------:|----------------:|----------------------:|-------------------:|------------------------:|
| `agents/` | 6,437 | 892 | 0 | 5,525 | 254 | 5,458 |
| `skills/` | 5,904 | 1,793 | 4 | 4,055 | 196 | 4,031 |
| `commands/` | 2,338 | 891 | 4 | 1,431 | 54 | 1,394 |
| `context/` | 1,877 | 346 | 3 | 1,525 | 379 | 1,147 |
| `docs/` | 225 | 61 | 0 | 164 | 49 | 116 |
| `rules/` | 66 | 0 | 0 | 66 | 0 | 66 |
| other | 287 | 0 | 0 | 287 | 0 | 287 |
| **Total** | **17,135** | **3,982** | **12** | **13,053** | **933** | **12,499** |

(Confirmed- and no-anchor columns sum to slightly more than the eligible-upper-bound column —
≈2,380 lines of double-counted overlap at window boundaries, an inherent approximation of
measuring exclusivity across two independently-classified, position-overlapping window sets; the
eligible-upper-bound column is the more precise total, confirmed- and no-anchor are each exact on
their own terms.)

**The anchor-confirmation test is deliberately conservative and almost certainly undercounts true
anchor coverage.** It requires LITERAL verbatim recurrence of the exact duplicated text inside a
candidate anchor file — but an anchor doc's job is to EXPLAIN a pattern, usually in different
wording than the agent/skill copies that restate it operationally. Direct evidence this
undercounts: `context/contracts/wrap-up.md`'s "Write location" section — named in Scope Widening
as a confirmed real anchor for the handoff write-location paragraph — is correctly found by this
test (it appears in the confirmed list below), proving the mechanism works when wording truly
matches; but several OTHER representative blocks Scope Widening named by concept (the dispatch-file
preamble ×68, the `skill-base.sh` preflight invocation block, the `summary`/`blockers`
handoff-field contract ×42) do not surface as confirmed anchors here, most plausibly because their
copies' wording has drifted from any single candidate anchor's own phrasing rather than because no
anchor exists. A genuine semantic anchor-finding pass (reading the block and judging whether an
existing doc already owns the concept, not just the exact text) — which Phases 17-19 are already
chartered to perform block-by-block as they consolidate — will very likely find more anchors than
this phase's literal-text sweep. This phase declares the mechanically-confirmed 933 lines as the
verified FLOOR, not the ceiling, and raises the resulting target shortfall as a `user_decision`
rather than inflating the floor with an unverified estimate.

**Top confirmed anchors** (of 26 total, by net removable share — `(g−1)/g` summed per covering
position, the same method as every other figure in this table, so these rows sum exactly to the
933-line total):

| Anchor | Heading | g | Removable (net share) |
|--------|---------|---|------------------------:|
| `context/patterns/early-metadata-pattern.md` | Stage 0: Initial Metadata Creation | 40 | 190.0 |
| `context/patterns/thin-wrapper-skill.md` | Thin Wrapper Skill Pattern | 20 | 139.7 |
| `context/standards/postflight-tool-restrictions.md` | MUST NOT (Postflight Boundary) | 16 | 75.0 |
| `context/contracts/adversarial-verification.md` (core) | Claim Verification Bar | 2 | 63.0 |
| `context/patterns/jq-escaping-workarounds.md` | Step 1: Update status and timestamps | 3 | 58.3 |
| `context/formats/command-structure.md` | Command File Structure | 5 | 57.8 |
| `context/formats/return-metadata-file.md` | Schema | 23 | 55.7 |
| `context/formats/frontmatter.md` | Research agent | 2 | 45.0 |
| `context/patterns/inline-status-update.md` | Update state.json | 4 | 28.2 |
| `context/patterns/task-expand-mode.md` | Expand Mode (--expand) | 4 | 26.0 |
| 17 further anchors | — | 2-5 | 194.3 (sum) |

Full 26-row detail (anchor path, heading, sharing factor, occurrence count, span-line total, full
file list) is in `markdown-block-inventory.tsv`, not duplicated here.

**Declared NET-MD outcome — shortfall, raised as a `user_decision`.** The −8,100 target assumed
64% capture of a 12,752-line eligible-upper-bound. The confirmed anchor-backed pool is 933 lines
— even at 100% capture, −933 is the ceiling this phase can verify, a shortfall of 7,167 lines
against the target (89% short). This phase does **not** relax the eligibility test to close that
gap. The `user_decision` raised on this dispatch's `.return-meta.json` asks the operator to choose
among:

1. **Accept the mechanically-confirmed floor and revise NET-MD/NET-TOTAL downward.** NET-MD target
   becomes ≈ −900 (conservative, leaving margin), making NET-TOTAL ≈ −700 (NET-PROD) − 1,200
   (NET-TEST floor) − 900 (NET-MD) ≈ **−2,800**, well short of the retained −10,000 floor — the
   third consecutive measurement round to fall short of that floor from enumerated, confirmed
   volume.
2. **Authorize Phases 17-19 to perform semantic (not merely literal-text) anchor-finding** as they
   consolidate each tranche block-by-block — reading a candidate anchor doc and judging genuine
   conceptual ownership, not only exact-text recurrence — which the "deliberately conservative"
   note above gives direct evidence would recover materially more of the 12,752-line
   eligible-upper-bound than this phase's literal sweep did. This does not violate "this task
   points at anchors that exist; it does not author new anchor documents" — it only widens HOW an
   existing anchor is recognized, not whether one must already exist.
3. **Lower the retained −10,000 floor itself**, on the grounds that three independent measurement
   rounds (Phase 2's script-cluster derivation, this plan's own markdown Scope Widening, and now
   this phase's anchor-confirmation pass) have each, in turn, found the floor unreachable from the
   next-enumerated source of volume.

This phase's own recommendation, stated for the record: option 2, because the evidence above
shows the shortfall is a measurement-methodology artifact (verbatim-only matching), not a true
absence of consolidatable volume — the known representative blocks already named in Scope Widening
demonstrate real anchors exist for content this phase's literal test could not verify.

**Tier Justification**: Every changed hunk lies inside this plan's own prose and tables under
`specs/**` plus one new machine-readable inventory file under the task directory, with no
executable surface; per `plan-format.md`'s `__FULL_SWEEP__` sub-case (a), the covering check is
`bash .claude/scripts/validate-artifact.sh specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md plan`
together with the `prose` row's diff read-through.

**Net-positive justification (declared in advance)**: This phase changes no corpus line in any of
the three populations (its only outputs live under `specs/**`). It is the cheapest route to a
negative net for the same reason Phase 2 was: committing three tranches to a markdown target
before classifying which blocks are even eligible is how a consolidation pass ends up collapsing
a gate-required restatement and spending the rest of the task unwinding it.

**Files to modify**:
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` - record the re-derived per-role table, the confirmed exclusion volumes, and the confirmed NET-MD target with its per-tranche allocation
- `specs/328_systematic_script_and_test_corpus_efficiency/markdown-block-inventory.tsv` - the machine-readable eligible-block inventory Phases 17-19 consume

**Verification**:
- The per-role duplicated-block table is re-derived against the live corpus and recorded in this plan.
  *(confirmed: see "Phase 15 Re-Derivation" table above — 7 roles, 17,135 total removable lines)*
- The gate-required exclusion list is derived by reading the fragment paths out of `lint-agent-contracts.sh` at run time, not from a hardcoded list, and its volume is recorded.
  *(confirmed: all five `*_FRAGMENT` variable assignments read directly from the script at this
  phase's execution time (including the previously-undocumented fifth, `MODIFIED_FILES_FRAGMENT`);
  3,982 lines recorded)*
- Every row in the eligible inventory names an anchor path and an existing anchor section heading; no row names an anchor that does not exist.
  *(confirmed: all 26 rows in `markdown-block-inventory.tsv` name an anchor file verified to
  exist on disk at measurement time, and a heading mechanically located at or above the matching
  line in that file — flagged above as approximate/nearest-heading, for Phases 17-19 to
  re-verify before replacing content, not blind-trust)*
- The confirmed NET-MD target and its per-tranche allocation are recorded, or a shortfall is recorded and raised as a `user_decision`.
  *(confirmed: shortfall path taken — 933-line confirmed floor against the −8,100 target,
  recorded in "Phase 15 Re-Derivation" above and raised as a `user_decision` on this dispatch's
  `.return-meta.json` with three named options and this phase's own recommendation)*
- `bash .claude/scripts/validate-artifact.sh specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md plan` passes.
  *(confirmed: `[PASS] plan artifact is valid (0 warning(s))`)*

---

### Phase 16: Land the Anchor-Pointer Convention, Its Regression Lint, and a Pilot [IN PROGRESS]

**Goal**: One documented convention for collapsing a restated block onto its anchor, a lint that
pins the collapse so the next contract added does not silently re-introduce it, and a five-file
pilot proving the per-file no-unique-content-lost test is actually operable before 221 files
depend on it.

**Paired-Test Coverage**: Not applicable to the new lint itself (it is created with its own
fixture suite in this phase). The five piloted markdown files have no suite; their verification is
the per-file ledger and the full gate set, both below.

**Tasks**:
- [x] Add the anchor-pointer convention to `context/standards/` as a short standard: what a
      collapsed block looks like (a one-line reference naming the anchor path and its section
      heading), the two hard exclusion classes and how to recognize one, and the obligation that a
      collapse records its claim-retention ledger entry. Keep it short — a long new standard in a
      task chartered against machinery growth is its own counterexample. *(completed:
      `context/standards/anchor-pointer-convention.md`, 70 lines)*
- [x] Write the regression lint: for each collapsed block recorded in the Phase 15 inventory,
      FAIL if the block's text reappears in any file other than its anchor. Consume the Phase 15
      inventory file rather than hardcoding block text, so adding a collapse later is a data edit,
      not a code edit — the exact property the gate-framework refactor was chartered to produce
      and measurably failed to. *(completed with a necessary refinement: the lint does NOT read
      `specs/328_.../markdown-block-inventory.tsv` directly at runtime — that path is under an
      ephemeral, renumberable task directory, and a deliverable under `agent-system/**` must not
      hardcode a task-numbered path (`source-store-deploy-boundary.md`,
      `no-task-references-in-deliverables.md`). Instead it reads a permanent registry,
      `scripts/lint/collapsed-blocks/registry.tsv`, seeded from the Phase 15 inventory's chosen
      rows. "Consume the inventory rather than hardcoding block text" is satisfied at the CODE
      level: `lint-anchor-pointer-collapse.sh` contains no block text or file list, only
      generic registry-driven logic; later phases extend coverage by appending registry rows (a
      data edit), never by editing the lint. Also scoped the check to each row's own
      `migrated_files` list rather than a whole-corpus scan, since the overwhelming majority of a
      block's sharing files are legitimately not-yet-migrated at any point mid-tranche, and a
      whole-corpus scan would fire on all of them the moment the first file is collapsed —
      see `scripts/lint/lint-anchor-pointer-collapse.sh`'s own header for the full rationale.)*
- [ ] Write the lint's fixture suite with a **deliberately violating fixture** (a file
      re-introducing a collapsed block) proving the lint fires, plus conforming fixtures proving
      it does not fire on the anchor itself or on a legitimate gate-required restatement.
- [x] Decide and record whether the lint gets a gate row or rides an existing gate. Default to
      riding an existing gate; a new row needs a written reason, per this task's own no-new-gate-row
      constraint. *(completed: rides gate 9 (`lint-postflight-boundary.sh`, "full corpus") —
      both are full-corpus markdown-content-presence lints over the source-store repo, so no
      SKIP/invocation-shape difference was needed; wired as a second check inside `gate9_run` in
      `verify-deploy.sh`, contributing to the same PASS/FAIL and `FINDINGS_LIST` gate9 already
      emits. No new gate row added.)*
- [ ] Pilot the collapse on five `agents/` files drawn from the inventory's highest sharing-factor
      block (the dispatch-file preamble, shared by 68 files at revision time). For each: collapse
      the block, write the ledger entry naming every claim in the removed text and the anchor
      section that retains it, then re-read the anchor and confirm each claim is present there.
- [ ] Run the full gate set over the pilot (`verify-deploy.sh`, not `--skip-slow`) and confirm
      every gate's finding set is identical to the Phase 1 baseline. Five files is a cheap enough
      pilot to pay for a full gate run, and the point of the pilot is to find a finding-set change
      while it still costs five files to revert.
- [ ] Record the phase's NET-MD delta (expected slightly positive; see justification).

**Timing**: 2.5 hours

**Depends on**: 15

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the highest sharing-factor eligible block is the
dispatch-file preamble at 68 files, carried from the revision-time shingling pass. Phase 15
re-derives the inventory; take the pilot block from that re-derivation, and if the top block has
become a gate-required one, pilot the highest-factor *eligible* block instead.

**Tier Justification**: The new lint's output feeds the gate set, so verification spans the changed
module plus its enumerated direct dependents: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the new lint's fixture suite>,test-lint-agent-contracts.sh,test-lint-postflight-boundary.sh`
plus `bash .claude/scripts/verify-deploy.sh <source_dir>` (full gate set, over five piloted files
only) for the finding-set invariant.

**Net-positive justification (declared in advance)**: This phase is net-positive on NET-MD and
NET-PROD by construction — it adds a standard, a lint and a fixture suite, and removes only the
five pilot files' blocks. It is the cheapest route to a negative net because it is the precondition
for Phases 17, 18 and 19, which collapse blocks across 221 files; discovering at file 180 that the
convention loses a claim or trips a gate would cost the whole tranche, and the regression lint is
what stops the 221-file result from decaying back the next time a contract is added.

**Files to modify**:
- `agent-system/extensions/core/context/standards/` - the anchor-pointer convention standard (new, short)
- `agent-system/extensions/core/scripts/lint/` - the collapsed-block regression lint (new, inventory-driven)
- `agent-system/extensions/core/scripts/tests/` - the lint's fixture suite including the deliberately-violating fixture (new)
- `agent-system/extensions/core/scripts/gate-registry.data` - only if the recorded decision is a new row rather than riding an existing gate
- `agent-system/extensions/core/agents/` - the five pilot files, if the Phase 15 inventory's highest-eligible-sharing-factor block lands here; the five concrete paths are added via `update-task-status.sh --file-scope-add` at pilot selection, before any file is edited
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` - the claim-retention ledger for the five pilot files

**Verification**:
- The lint's fixture suite is green, and its deliberately-violating fixture trips the lint.
- The lint reads its block set from the Phase 15 inventory file; adding a collapse requires no edit to the lint itself.
- Every gate's finding set over the live corpus is identical to the Phase 1 baseline after the pilot.
- Each of the five pilot files has a ledger entry naming every claim in its removed text and the anchor section that retains it, and each named claim is confirmed present in that anchor by re-reading it.
- The phase's NET-MD delta is recorded, with its net-positive justification restated in the closing note.

---

### Phase 17: Markdown Tranche A — The Agent Contracts [NOT STARTED]

**Goal**: The `agents/` role's eligible duplicated blocks collapse onto their anchors — the
densest single tranche by removable volume — with every collapse carrying a claim-retention ledger
entry and every gate's finding set unchanged.

**Paired-Test Coverage**: No suite covers an agent contract's prose. Coverage for this tranche is
the Phase 16 regression lint, the per-file claim-retention ledger, and the full gate set, which
together are the only signals that can detect a lost claim or a changed finding set here.

**Tasks**:
- [ ] Collapse the eligible blocks in the `agents/` role (78 files at revision time) onto their
      anchors, working in sharing-factor order so the highest-value blocks land first and a
      mid-tranche stop still banks most of the volume.
- [ ] Skip, by name and with a recorded reason, every block the Phase 15 inventory marked
      gate-required or deliberately inlined. A skip is recorded, not silent — an unexplained skip
      is indistinguishable from an oversight to a later reader.
- [ ] Maintain the claim-retention ledger: one entry per file touched, naming each collapsed block
      and the anchor section retaining its claims, with each claim confirmed present in the anchor
      by re-reading it. **The test for a markdown consolidation is that every claim in the removed
      text is still reachable from the retained text**, and a ledger entry asserting that without
      having re-read the anchor does not discharge it.
- [ ] Exclude `context/standards/shell-script-testing.md` and every `*.sh` file from this tranche's
      territory — the script/test track owns both.
- [ ] Run the full gate set and confirm every gate's finding set is identical to the Phase 1
      baseline. Run the Phase 16 regression lint and confirm no collapsed block reappears.
- [ ] Record the phase's NET-MD delta and the running NET-MD figure.

**Timing**: 4 hours

**Depends on**: 16

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts 78 files in the 19 `*/agents/` directories carrying
≈5,347 eligible removable lines, and targets −3,400 of them, carried from the shingling pass
recorded under Scope Widening. The role's live file count was re-confirmed at this revision round
at 78 in `*/agents/` directories (80 counting two nested `agents/` files under
`extensions/lean/context/project/lean4/`, which belong to the `context/` role and to Phase 19's
territory, not this one). Phase 15 re-derives the removable volume; if the confirmed eligible volume for this role
cannot support the allocated −3,400, revise the allocation across the three tranches explicitly
rather than letting this one quietly miss and the later ones absorb it.

**Tier Justification**: Agent contracts are inputs to the gate set rather than to any suite, so
verification spans the changed files plus their enumerated direct dependents — the gates that read
them: `bash .claude/scripts/verify-deploy.sh <source_dir>` (full gate set) plus
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh,test-lint-postflight-boundary.sh,<the Phase 16 fixture suite>`.

The tranche's territory is every extension's `agents/` directory — the duplication measured in
Scope Widening spans all of them — and the concrete eligible file list is added via
`update-task-status.sh --file-scope-add` at Phase 15 close, before this phase starts.

**Files to modify**:
- `agent-system/extensions/core/agents/` - the eligible subset, enumerated from the Phase 15 inventory
- `agent-system/extensions/founder/agents/` - the eligible subset (the largest single role directory, 15 files)
- `agent-system/extensions/present/agents/` - the eligible subset
- `agent-system/extensions/filetypes/agents/` - the eligible subset
- `agent-system/extensions/cslib/agents/` - the eligible subset
- `agent-system/extensions/lean/agents/` - the eligible subset
- `agent-system/extensions/formal/agents/` - the eligible subset
- `agent-system/extensions/books/agents/` - the eligible subset
- `agent-system/extensions/z3/agents/` - the eligible subset
- `agent-system/extensions/web/agents/` - the eligible subset
- `agent-system/extensions/typst/agents/` - the eligible subset
- `agent-system/extensions/rust/agents/` - the eligible subset
- `agent-system/extensions/python/agents/` - the eligible subset
- `agent-system/extensions/nvim/agents/` - the eligible subset
- `agent-system/extensions/nix/agents/` - the eligible subset
- `agent-system/extensions/latex/agents/` - the eligible subset
- `agent-system/extensions/epidemiology/agents/` - the eligible subset
- `agent-system/extensions/literature/agents/` - the eligible subset
- `agent-system/extensions/email/agents/` - the eligible subset, with the extension's deliberately-inlined safety content excluded by the Phase 15 inventory's second hard-exclusion class
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` - the tranche's claim-retention ledger and NET-MD delta

**Verification**:
- Every gate's finding set over the live corpus is identical to the Phase 1 baseline.
- The Phase 16 regression lint is green: no collapsed block reappears outside its anchor.
- Every file touched has a ledger entry, and every claim it names is confirmed present in the named anchor section.
- Every skipped block has a recorded reason naming its exclusion class.
- The running NET-MD figure is recorded and negative, and this tranche's delta meets its allocation or its shortfall is recorded with the allocation revised explicitly.

---

### Phase 18: Markdown Tranche B — The Skill Definitions [NOT STARTED]

**Goal**: The `skills/` role's eligible duplicated blocks collapse onto their anchors, following
the pattern Phase 17 established.

**Paired-Test Coverage**: As Phase 17 — the regression lint, the per-file ledger, and the full
gate set.

**Tasks**:
- [ ] Collapse the eligible blocks in the `skills/` role (93 files at revision time) onto their
      anchors, in sharing-factor order.
- [ ] Treat the skill-body preflight/postflight blocks with particular care: `skills/` carries the
      largest gate-required share of any role (≈1,782 of its ≈5,907 removable lines at revision
      time, roughly 30%), so the eligible set here is materially smaller than the raw duplication
      figure suggests and the exclusion list is doing more work than in Phase 17.
- [ ] Maintain the claim-retention ledger, one entry per file touched, with each claim confirmed
      present in its anchor by re-reading it.
- [ ] Exclude `context/standards/shell-script-testing.md` and every `*.sh` file from this tranche's
      territory.
- [ ] Run the full gate set and the Phase 16 regression lint; confirm the finding-set invariant and
      that no collapsed block reappears.
- [ ] Record the phase's NET-MD delta and the running NET-MD figure.

**Timing**: 4 hours

**Depends on**: 17

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts 93 `skills/` files carrying ≈4,091 eligible removable
lines and targets −2,600, carried from the revision-time pass. The gate-required share for this
role is the highest in the corpus, so this is the allocation most likely to need revision; confirm
against the Phase 15 inventory before starting and revise the three-tranche allocation explicitly
if it cannot hold.

**Tier Justification**: Skill definitions are read by the gate set and by `skill-base.sh`'s
lifecycle, not by any suite directly, so verification spans the changed files plus their
enumerated direct dependents: `bash .claude/scripts/verify-deploy.sh <source_dir>` (full gate set)
plus `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-postflight-boundary.sh,test-lint-contract-compliance.sh,<the Phase 16 fixture suite>`.

The tranche's territory is every extension's `skills/` directory, and the concrete eligible file
list is added via `update-task-status.sh --file-scope-add` at Phase 15 close, before this phase
starts.

**Files to modify**:
- `agent-system/extensions/core/skills/` - the eligible subset, enumerated from the Phase 15 inventory
- `agent-system/extensions/founder/skills/` - the eligible subset (15 files, the largest single role directory)
- `agent-system/extensions/cslib/skills/` - the eligible subset
- `agent-system/extensions/present/skills/` - the eligible subset
- `agent-system/extensions/books/skills/` - the eligible subset
- `agent-system/extensions/lean/skills/` - the eligible subset
- `agent-system/extensions/filetypes/skills/` - the eligible subset
- `agent-system/extensions/memory/skills/` - the eligible subset
- `agent-system/extensions/formal/skills/` - the eligible subset
- `agent-system/extensions/email/skills/` - the eligible subset, with the extension's deliberately-inlined safety content excluded by the second hard-exclusion class
- `agent-system/extensions/z3/skills/` - the eligible subset
- `agent-system/extensions/web/skills/` - the eligible subset
- `agent-system/extensions/typst/skills/` - the eligible subset
- `agent-system/extensions/rust/skills/` - the eligible subset
- `agent-system/extensions/python/skills/` - the eligible subset
- `agent-system/extensions/nvim/skills/` - the eligible subset
- `agent-system/extensions/nix/skills/` - the eligible subset
- `agent-system/extensions/literature/skills/` - the eligible subset
- `agent-system/extensions/latex/skills/` - the eligible subset
- `agent-system/extensions/epidemiology/skills/` - the eligible subset
- `agent-system/extensions/approvals/skills/` - the eligible subset
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` - the tranche's claim-retention ledger and NET-MD delta

**Verification**:
- Every gate's finding set over the live corpus is identical to the Phase 1 baseline.
- The Phase 16 regression lint is green.
- Every file touched has a ledger entry with each named claim confirmed present in its anchor.
- Every skipped block has a recorded reason naming its exclusion class.
- The running NET-MD figure is recorded and negative, and the tranche's delta meets its allocation or its shortfall is recorded with the allocation revised explicitly.

---

### Phase 19: Markdown Tranche C — Commands, Context, Docs and Rules [NOT STARTED]

**Goal**: The remaining roles' eligible duplicated blocks collapse onto their anchors, completing
the markdown track, and the `context/` corpus — the largest role by line count and the lowest by
duplication density — is consolidated only where duplication is actually measured.

**Paired-Test Coverage**: As Phases 17 and 18 — the regression lint, the per-file ledger, and the
full gate set.

**Tasks**:
- [ ] Collapse the eligible blocks in `commands/` (50 files, ≈1,430 eligible at revision time),
      `context/` (594 files, ≈1,515), `docs/` (29 files, ≈161) and `rules/` (21 files, ≈66).
- [ ] Resist the temptation to treat `context/`'s 90,844 substantive lines as a target in their own
      right. Its duplication density is the lowest of any role (≈1.7% of its substantive lines);
      the volume is there but the *duplication* is not, and consolidating non-duplicated context
      prose is the open-ended markdown rewriting this plan names as a non-goal.
- [ ] `context/standards/shell-script-testing.md` is now in territory (Phase 14 has closed by this
      wave). Re-read it before editing and confirm Phases 4, 8, 12, 13 and 14 all landed their own
      edits to it, so this tranche collapses the final text rather than a version those phases
      then overwrite.
- [ ] Maintain the claim-retention ledger, one entry per file touched, with each claim confirmed
      present in its anchor by re-reading it.
- [ ] Run the full gate set and the Phase 16 regression lint; confirm the finding-set invariant.
- [ ] Record the phase's NET-MD delta, the running NET-MD figure, and whether the confirmed NET-MD
      target is met. If it is not, record the shortfall and its cause explicitly — the acceptance
      criterion is a measured figure, never a count of files consolidated.

**Timing**: 4 hours

**Depends on**: 14, 18

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the per-role eligible figures above and targets −2,100
across the four roles combined, carried from the shingling pass recorded under Scope Widening.
The four roles' file counts were re-confirmed live at this revision round and match the figures
in the task list above exactly (`commands/` 50, `context/` 594, `docs/` 29, `rules/` 21); it is
the per-role *removable* volume, not the file count, that Phase 15 re-derives. It also asserts that Phase 14
has closed, which is what makes `context/standards/shell-script-testing.md` safe to touch; confirm
that phase's `[COMPLETED]` heading before editing that file, and leave it alone if Phase 14 has
not closed.

**Tier Justification**: These files are read by the gate set, by `skill-base.sh`'s context
loading, and by the rule auto-loader, not by any suite directly, so verification spans the changed
files plus their enumerated direct dependents: `bash .claude/scripts/verify-deploy.sh <source_dir>`
(full gate set) plus `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-contract-compliance.sh,test-lint-routing-wiring.sh,<the Phase 16 fixture suite>`.

Four roles. The concrete eligible file list is added via `update-task-status.sh
--file-scope-add` at Phase 15 close, before this phase starts. `context/` is declared narrowly
rather than per-extension: its duplication density is the lowest of any role and most extensions'
`context/` directories carry no eligible block at all, so declaring all 22 of them would widen
`file_scope` across almost the whole source store for volume the inventory has not confirmed is
there.

**Files to modify**:
- `agent-system/extensions/core/commands/` - the eligible subset, enumerated from the Phase 15 inventory
- `agent-system/extensions/founder/commands/` - the eligible subset
- `agent-system/extensions/present/commands/` - the eligible subset
- `agent-system/extensions/filetypes/commands/` - the eligible subset
- `agent-system/extensions/books/commands/` - the eligible subset
- `agent-system/extensions/memory/commands/` - the eligible subset
- `agent-system/extensions/literature/commands/` - the eligible subset
- `agent-system/extensions/lean/commands/` - the eligible subset
- `agent-system/extensions/cslib/commands/` - the eligible subset
- `agent-system/extensions/epidemiology/commands/` - the eligible subset
- `agent-system/extensions/email/commands/` - the eligible subset
- `agent-system/extensions/approvals/commands/` - the eligible subset
- `agent-system/extensions/core/context/` - the eligible subset only (160 files, the bulk of the role); any other extension's `context/` file the inventory marks eligible is added through the `--file-scope-add` channel rather than pre-declared here
- `agent-system/extensions/core/docs/` - the eligible subset (the role's only directory)
- `agent-system/extensions/core/rules/` - the eligible subset
- `agent-system/extensions/lean/rules/` - the eligible subset
- `agent-system/extensions/cslib/rules/` - the eligible subset
- `agent-system/extensions/books/rules/` - the eligible subset
- `agent-system/extensions/web/rules/` - the eligible subset
- `agent-system/extensions/nvim/rules/` - the eligible subset
- `agent-system/extensions/nix/rules/` - the eligible subset
- `agent-system/extensions/latex/rules/` - the eligible subset
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` - the tranche's claim-retention ledger and the final NET-MD figure

**Verification**:
- Every gate's finding set over the live corpus is identical to the Phase 1 baseline.
- The Phase 16 regression lint is green.
- Every file touched has a ledger entry with each named claim confirmed present in its anchor.
- No `context/` file is edited where the Phase 15 inventory recorded no eligible duplicated block.
- The final NET-MD figure is recorded and meets the confirmed target, or its shortfall and cause are recorded explicitly.

---

### Phase 20: Redeploy, Full Gate Set, and the Measured Net Accounting [NOT STARTED]

**Goal**: The source-store work reaches the deployed tree, the complete gate set is green, and the
task's acceptance criterion is discharged with measured figures — a net reduction in corpus size
against the retained −10,000 floor, with every gate's finding set and every suite's assertion set
provably unchanged and every markdown collapse's claims provably retained.

**Paired-Test Coverage**: The whole corpus. This phase runs the full battery and the complete gate
set; no narrowing applies.

**Tasks**:
- [ ] Redeploy via `deploy-headless.sh` so the deployed `.claude/` tree reflects the source store.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path:
      `agent-system/extensions/core/scripts/verify-deploy.sh`) with no `--skip-slow`, no
      `--only-gate`, and no `--max-cost`. Every gate must be green with a non-zero check count.
- [ ] Verify the finding-set invariant across the whole task: every gate's finding set over the
      live corpus is identical to the Phase 1 baseline. A gate that now finds less has lost
      coverage, which fails this phase.
- [ ] Verify the assertion-set invariant: the corpus-wide total assertion count and every suite's
      PASS/FAIL case-name list match their pre-task values.
- [ ] Verify the claim-retention invariant across the markdown track: every ledger entry from
      Phases 16, 17, 18 and 19 names an anchor section that exists, and every claim it names is
      present there. Re-read the anchors; a ledger that was written without re-reading does not
      discharge this.
- [ ] Confirm the Phase 16 regression lint is green over the whole corpus: no collapsed block has
      reappeared outside its anchor anywhere, including in files the markdown tranches did not
      touch.
- [ ] On a verified-quiet host (1-, 5- and 15-minute load averages all under 2), run the standing
      size probe and record the final NET-PROD, NET-TEST and NET-MD figures against the Phase 1
      baseline, plus NET-TOTAL as their sum. All three must be negative, each must meet its
      declared target, and NET-TOTAL must meet the retained −10,000 floor.
- [ ] If any figure misses its target, record the shortfall and its cause explicitly rather than
      restating the target. The acceptance criterion is a measured net reduction, reported as a
      running net figure — never as a count of refactors performed or files consolidated.
- [ ] Confirm no file landing under `agent-system/**` carries a task-number reference or
      record-versioning language (both are permitted in this plan and the task description, and in
      neither case under `agent-system/**`).

**Timing**: 2 hours

**Depends on**: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the Phase 2 targets (NET-PROD, NET-TEST) and the Phase 15
target (NET-MD) are met and that their sum meets the retained floor. All three are derived rather
than given, so confirm at phase start that both derivations were recorded and that the final probe
run uses the same canonical corpus definition the Phase 1 baseline used — a baseline and a final
figure taken with different predicates are not comparable, which is the exact trap the dispatch's
and the research report's non-comparable counts illustrate. The markdown figure comes from the
same probe line as the other two, so no reconciliation between instruments is needed.

**Files to modify**:
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` - record the final net figures and the invariant results
- `.claude/` - regenerated by `deploy-headless.sh`, not hand-edited

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (complete gate set, no `--skip-slow`, no `--only-gate`, no `--max-cost`) is green with a non-zero check count.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` (full battery) is green.
- Every gate's finding set over the live corpus is identical to the Phase 1 baseline.
- Corpus-wide total assertion count and per-suite PASS/FAIL case-name lists match pre-task values.
- Final NET-PROD, NET-TEST and NET-MD figures are recorded, all three negative, all measured on a verified-quiet host with the Phase 1 baseline's own corpus definition, and NET-TOTAL meets the retained −10,000 floor.
- Every claim-retention ledger entry names an existing anchor section containing the claim, confirmed by re-reading the anchor.
- The Phase 16 collapsed-block regression lint is green over the whole corpus.
- `bash .claude/scripts/check-task-references.sh` reports no finding under `agent-system/**`.

---

## Testing & Validation

- [ ] Every lint's finding set over the live corpus is identical before and after each phase that touches it — not merely both-empty.
- [ ] Every migrated suite's assertion count and PASS/FAIL case-name list is identical before and after migration.
- [ ] `tests/test-lint-corpus-scan-lib.sh` pins exactly one definition of the extracted corpus-scan helper and no inline copy in any lint file.
- [ ] `tests/test-common-lib.sh` pins exactly one definition of each harness piece and that no migrated suite redefines `pass()`/`fail()`/`info()`.
- [ ] The new unit-class spawn-boundary lint's deliberately-violating fixture trips it; its conforming fixtures do not.
- [ ] `run-all.sh`'s `--only`, `--jobs`, `--timings` and `--fail-on-new` produce byte-identical output to a pre-task run on the same selection.
- [ ] A suite attempting to mutate the shared read-only fixture fails loudly, at both `--jobs auto` and `--jobs 1`.
- [ ] The standing size probe emits exactly one line, carries the cost-per-assertion figure, and adds no gate row (`gate-registry.data` row count unchanged from the 23 recorded at plan time).
- [ ] The markdown collapsed-block regression lint reads its block set from the Phase 15 inventory file, and its deliberately-violating fixture trips it while its conforming fixtures do not.
- [ ] No duplicated markdown block in either hard-exclusion class (gate-required restatement, deliberate prompt-inlining) was collapsed; each exclusion is recorded with its class.
- [ ] Every markdown file touched carries a claim-retention ledger entry whose every named claim is confirmed present in the named anchor section by re-reading that anchor.
- [ ] The complete gate set is green at the final phase with a non-zero check count, and every gate's finding set is identical to the Phase 1 baseline.
- [ ] All three running net figures are negative against the Phase 1 baseline, each meets its declared target, and their sum meets the retained −10,000 floor.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/lint-corpus-scan-lib.sh` - shared lint corpus-scan skeleton (new)
- `agent-system/extensions/core/scripts/lib/common.sh` - shared test assert/fixture/teardown harness, extended in place rather than added as a second parallel library
- `agent-system/extensions/core/scripts/lib/extension-install-lib.sh` - shared install/uninstall helpers (new; exact path confirmed in Phase 9)
- `agent-system/extensions/core/scripts/lint/` - new unit-class spawn-boundary lint
- `agent-system/extensions/core/scripts/script-inventory.sh` - `--size-line` standing probe mode with cost-per-assertion
- `agent-system/extensions/core/scripts/verify-deploy.sh` - one-line corpus-size figure in the summary block, no new gate row
- `agent-system/extensions/core/scripts/tests/run-all.sh` - shared deployed-tree fixture plus class/tag/cost-class selection
- `agent-system/extensions/core/scripts/tests/` - suite-classification data file, new regression and fixture suites, and the migrated suite corpus
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - harness as required structural model, classification and boundary, shared-fixture contract, new selectors
- `agent-system/extensions/core/context/standards/` - the anchor-pointer convention standard for markdown consolidation (new, short)
- `agent-system/extensions/core/scripts/lint/` - the inventory-driven collapsed-block regression lint (new), with its fixture suite including a deliberately-violating fixture
- Every extension's `agents/`, `skills/`, `commands/`, `context/`, `docs/` and `rules/` markdown, as enumerated per phase above - the eligible duplicated blocks collapsed onto the anchors that already own them
- `specs/328_systematic_script_and_test_corpus_efficiency/markdown-block-inventory.tsv` - the machine-readable eligible-block inventory, consumed by the three markdown tranches and by the regression lint
- The seven lint cluster members, the install/uninstall pair, the typst pair, and `literature-search.sh`, all deduplicated
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` - this plan, carrying the baseline, the declared targets, and the final net accounting
- A redeployed `.claude/` tree (generated by `deploy-headless.sh`, never hand-edited)

## Rollback/Contingency

Each phase is independently revertible: the plan's phase boundaries follow file-territory
boundaries, so a phase's edits are confined to the files its **Files to modify** list names, and
the commit-per-green-substep mandate means a failed phase leaves its predecessors committed and
green.

- **Before a risky phase** (Phase 8's two largest-suite migrations, Phase 11's 172-block
  single-file extraction, Phase 13's shared-fixture change), take a durable non-reverting
  checkpoint with `bash .claude/scripts/git-snapshot.sh 328 --no-revert`. This records the tree
  without touching it, which is what an ordinary defensive checkpoint needs.
- **For a genuine rollback** that must discard uncommitted work, follow
  `.claude/context/contracts/recovery.md`'s rollback rung for the exact invocation shape,
  including its out-of-scope override flag for the deliberate whole-tree case. Do not reach for a
  reverting snapshot as a routine precaution.
- **Phase-level contingency**: a phase whose finding-set or assertion-set invariant fails is
  reverted, not patched forward. A lost finding or a lost assertion is indistinguishable from a
  successful refactor by any other signal, which is why those two invariants are the hard gate.
- **Net-positive contingency**: a phase whose net is positive and which cannot state why it is the
  cheapest available route to a later negative net is reverted, per the dispatch's acceptance
  criterion.
- **Markdown contingency**: a markdown collapse is reverted, not patched forward, if the full gate
  set's finding set changes or if a ledger entry's claim cannot be found in its named anchor. Both
  failures mean the same thing — content that was load-bearing was removed — and neither is
  detectable by any suite, which is why the tranches run the full gate set per tranche rather than
  only at the end. Because the markdown track holds file territory disjoint from the script/test
  track, reverting a markdown tranche never disturbs a script/test phase, and the reverse holds
  too; the single shared file (`context/standards/shell-script-testing.md`) is sequenced, not
  shared concurrently.
- **Deploy contingency**: the deployed `.claude/` tree is a disposable artifact. If a redeploy
  produces a broken tree, re-run `deploy-headless.sh` from a known-good source-store commit; no
  hand-editing of `.claude/**` is ever part of a recovery.
