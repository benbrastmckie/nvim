# Research Report: Task #650

**Task**: 650 - Touched path verify entry and unmapped fallback
**Started**: 2026-11-18
**Completed**: 2026-11-18
**Effort**: large (6 deliverables + 2 cross-record edges)
**Dependencies**: None (edges to 610, 599, 586, 579, and the sibling orchestration-close record)
**Sources/Inputs**: - Codebase (agent-system/extensions/core source store: scripts/tests/run-all.sh, scripts/lib/suite-selection-lib.sh, scripts/orchestrate-build-dispatch.sh, scripts/orchestrate-batch-gate.sh, scripts/verify-deploy.sh, scripts/measure-gate-costs.sh, context/formats/plan-format.md, context/standards/shell-script-testing.md, context/standards/repo-level-declarations.md, context/contracts/batch-gate-stage.md); the two named consumer repositories' own task records (sf1-engine task 33, sapience-app task 50) as corroborating evidence
**Artifacts**: - specs/650_touched_path_verify_entry_and_unmapped_fallback/reports/01_touched-path-entry-and-fallback.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The task description's "WHAT EXISTS AND IS NOT WIRED TOGETHER" claims are all independently
  confirmed by direct read: `run-all.sh` already has `--only`/`--jobs auto`/`--timings`/`--class`/
  `--tag`/`--cost-class`/`--fail-on-new`; `suite-selection-lib.sh` already has
  `suite_selection_select`/`_unmapped`/`_classify`/`_select_annotated` and the `__FULL_SWEEP__`
  sentinel; the `## Batch Gate Deferral` directive (`orchestrate-build-dispatch.sh`) and
  plan-format.md's Verification Tiers section both explicitly hand an agent two raw invocations
  and leave suite resolution, job count, and `__FULL_SWEEP__` handling to the agent's own
  judgment — there is no single callable entry point today.
- Both consumer repositories the user is orchestrating in parallel independently corroborate this
  record's premises without further investigation needed: sf1-engine's own task 33 ("Scoped
  verify and orchestration close battery") is a near-verbatim mirror of deliverables 1-2 against
  its own 3-root shell-suite tree; sapience-app's task 50 ("Tiered pytest gate and change aware
  selection") is the measured non-shell-backend evidence deliverable 6 itself cites, and that
  task's own text states it will adopt deliverable 6's resolver output shape only if this record
  has already landed and redeployed — otherwise it will choose its own shape and record it for
  later reconciliation. This confirms the sequencing claim is real, not merely asserted, and
  gives this record's planning phase a live, externally-motivated reason to settle the resolver
  output shape precisely rather than loosely.
- A durable design pattern already in this corpus answers most of the "how do I declare X" open
  questions in the task description: `.claude-extensions.json`'s top-level sibling-key surface
  (`context/standards/repo-level-declarations.md`), which already carries two schemas
  (`derived_artifact_probes`, `coupled_generated_surfaces`) with an established
  fail-open-on-absence contract. Deliverables 5 and 6 should add new sibling keys to this same
  surface rather than inventing a second declaration mechanism — and task 599's directive-level
  "repository's own project gates" need and task 651's "repository declares its own closing gate"
  need are the same surface by design; all three records must agree on one schema.
- Deliverable 4's apparent tension ("say how timings refresh suite-cost-hints.txt without
  becoming the self-maintaining mutable cache run-all.sh's header already rejects") resolves
  cleanly once `measure-gate-costs.sh --regen-hints`'s own guarantees are read: that script's
  regeneration of `suite-cost-hints.txt` is idle-guarded (refuses above a load threshold),
  multi-run-averaged, and overwrite-protected against contamination. A scoped, single-sample,
  arbitrary-load touched-path run can never meet those guarantees, so the new entry point's own
  `--timings` output must NOT be read by the `suite-cost-hints.txt` regeneration path at all — it
  is a diagnostic-only artifact for the dispatch/human that ran it, and task 586 (the standing
  cost-probe consumer) remains the sole owner of `suite-cost-hints.txt`'s actual refresh.
- Deliverable 3's authority question has a concrete existing precedent: `verify-deploy.sh`'s
  `gate0` already runs argument/target validation strictly before any gate selection is
  consulted, and is itself never filterable by `--only-gate`. The new entry point's own
  "preflight" (map/class files parse, every named suite exists, fallback set non-empty) should
  follow the identical shape — a check that structurally cannot be skipped by the very selection
  it is validating.
- Deliverable 2's "owed, not paid" record has no existing durable-record implementation to reuse
  verbatim, but plan-format.md already states the sanctioned pattern for exactly this shape (a
  record whose existence is contingent on a prior dispatch, consulted by a later one): a file
  under the task's own `records/` directory, or a `specs/state.json` field — never a
  dispatch-written sidecar the plan cannot guarantee is present. The natural discharge site is
  `orchestrate-batch-gate.sh` (Move 4), which already runs the complete, unnarrowed gate set
  exactly once per invocation and is the sibling orchestration-close record's (task 651)
  explicitly named discharge point for this exact record's owed-sweep output.

## Context & Scope

Researched: how to wire `run-all.sh`'s existing selection/parallelism/timing flags and
`suite-selection-lib.sh`'s existing resolution functions into one callable entry point, and how
to replace the `__FULL_SWEEP__` unmapped-path fallback with a classified, non-silent outcome —
the six deliverables and the two hard cross-record sequencing dependencies (610's mechanical
full-battery guard; 651's "orchestration, not task, closes on the full battery" ruling) stated in
the task description. No code was written in this phase; this report establishes the ground
truth every claim in the task description rests on, re-derives the design space each deliverable
must choose within, and names the concrete decisions planning should make explicitly.

## Findings

### Codebase Patterns

**`run-all.sh` (`agent-system/extensions/core/scripts/tests/run-all.sh`)**: confirmed flags
exactly as described — `--only`, `--jobs N|auto` (default `auto`), `--timings FILE`, `--class`,
`--tag`, `--cost-class`, `--fail-on-new`. `--only` validates every token against the discovered
suite set before any suite runs (exit 2 on an unknown token, naming it) and filters at exactly
one site before `TOTAL_DISCOVERED` is computed, so every downstream mechanism (parallel
scheduling, `--timings`, `known-failures.txt` classification) inherits the narrowing for free.
A full, unfiltered run from a non-nested, non-guest invocation holds a repo-scoped
`specs/.gate-lock` mutex for its duration; `--only`-narrowed runs skip that mutex entirely
(confirmed in the header and cross-referenced in `batch-gate-stage.md`).

**`suite-selection-lib.sh`**: confirmed public API — `suite_selection_select`,
`suite_selection_unmapped`, `suite_selection_classify`, `suite_selection_select_annotated`,
`suite_selection_known_classes`/`_tags`/`_cost_classes`, `suite_selection_by_class`/`_tag`/
`_cost_class`. Mapping runs three strata (self-identity, strict basename pairing, grep-based
reference lookup); a zero-hit path on both real strata escalates the *whole multi-path call* to
`__FULL_SWEEP__` — the aggregation rule is "union of per-path selections, except one unmappable
path escalates everything" (this exact rule is also the subject of the separate, narrower record
579, which patches the *authoring-contract* gap where a planner forgot it, not the mechanism
itself). The library already resolves per-extension scripts roots in source-store mode (a
touched path naming `agent-system/extensions/<ext>/scripts/...`) and is marked explicitly as the
single source of truth both `run-all.sh` and any future caller share — this record's entry point
is exactly that "future caller" the library's own header anticipates.

**Where the gap actually is**: `orchestrate-build-dispatch.sh`'s `## Batch Gate Deferral` section
(composed only for implement-phase dispatches under `--batch-gate-deferral`) and
`plan-format.md`'s Verification Tiers section both tell an agent, in prose, to run
`run-all.sh --only SUITE[,SUITE...]` — but neither names how the agent gets the SUITE list, nor
what to do when `suite_selection_select` would answer `__FULL_SWEEP__`. The two-candidate,
existence-checked resolution pattern that decides whether `run-all.sh`/`verify-deploy.sh` resolve
to a deployed mirror (`${REPO}/.claude/scripts/...`) or the source-store path
(`${REPO}/agent-system/extensions/core/scripts/...`) is already implemented exactly once, inline,
in `orchestrate-build-dispatch.sh`'s `run_all_candidates=(...)`/`verify_deploy_candidates=(...)`
arrays. Deliverable 1's entry point must perform the *identical* dual-mode resolution (it is
explicitly required to "work in source-store mode and in deployed mode in any consumer
repository"), and should almost certainly factor this resolution into a small shared helper
(`deploy-root-guard.sh` already exists as a precedent for a shared "which mode am I in" helper
sourced by multiple scripts) rather than re-deriving the two-candidate array a third time.

**`--gate8-touched` precedent (`verify-deploy.sh`)**: a directly analogous mechanism already
exists one layer up — `verify-deploy.sh` accepts `--gate8-touched PATH[,PATH...]`, resolves it
through the *same* `suite_selection_select`, and narrows Gate 8's *own internal* `run-all.sh`
call to `--only <that set>` when a real suite set comes back, falling back to the unnarrowed
invocation on the sentinel. Its narrowed-pass message is deliberately a *different string* from
the unnarrowed one ("not a full-battery pass," distinct from `test-gate8-expected-new-distinction.sh`'s
and `test-gate-lock.sh`'s asserted unnarrowed string) — the exact "verdict that can never be
mistaken for a full-battery pass" deliverable 1 asks for already has one working implementation
to model the new entry point's own verdict line on. `--gate8-touched` is also explicitly
documented as caller-supplied, never self-deriving touched paths from git — wiring an actual
caller (an orchestrator batch-gate call site) is named as separate, not-yet-built work in that
same section. This record's deliverable 1 is a natural candidate to become exactly that caller,
or at minimum to share its path-resolution front end with it.

**`gate0` as the preflight precedent (deliverable 3)**: `verify-deploy.sh`'s `gate0` performs
argument/target validation strictly before any gate selection is consulted and is structurally
never filterable by `--only-gate` — it always runs and always can emit a `FINDING gate0` line
independent of what else was selected. This is the exact shape deliverable 3's "cheap preflight
outside run-all.sh's discovery" needs: a check that sits *outside* the selection mechanism it
validates, so a selected run can never accidentally deselect its own guard. `run-all.sh` has no
equivalent "gate0" today (it begins directly at flag parsing and discovery); the new entry point
is the natural place to add one, checked once per invocation of the entry point itself (map/class
data files parse, every suite basename named by any axis actually exists on disk, the fallback
set under "owed" is non-empty) — this preflight guards the *entry point's own* resolution step,
distinct from and prior to `run-all.sh --only`'s own per-token existence validation.

**Suites that assert properties of selection itself**: confirmed — `test-run-all-selection.sh`
(both halves: the library's mapping/escalation/classification correctness, and `run-all.sh`'s
`--only` flag behavior and parity) and `test-gate8-suite-selection.sh`/
`test-verify-deploy-gate-selection.sh`/`test-verify-deploy-gate-selection-crash-net.sh` are all
real, discovered `test-*.sh` suites living inside the very battery a narrowed `--only` run can
omit. A touched-path selection whose resolved suite set happens not to include one of these
(e.g. a change to an unrelated `lib/` file) genuinely deselects the suite that would have caught
a regression in selection itself — this is not a hypothetical, it follows mechanically from how
`--only`'s single filtering site works. Per the task's own framing, the correct authority split
is: (1) the complete, unfiltered run (at whatever moment now owns "the full battery" —
orchestration close, per the sibling record 651, once it lands) is the only run whose PASS on
these suites is authoritative; (2) the new entry-point-level preflight (previous paragraph) is a
second, independent, structurally-outside-selection guard that catches the *cheap, mechanical*
subset of what could go wrong (bad map data, a named suite that does not exist, an empty fallback
set) without needing to run any suite at all. Neither guard needs these suites to be *forced*
into every scoped run — that would defeat scoping's own purpose and duplicate what the preflight
and the final full run already cover between them.

**Declarative selection axes (`--class`/`--tag`/`--cost-class`)**: confirmed present and exactly
as documented, reading `tests/suite-classification.data` (class), a mechanically-derived
tag set (invoked-tool tokens from `integration`-class rows' `reason` column, plus the fixed
`lint` tag), and `tests/suite-cost-hints.txt`'s bucketed wall-clock (free/moderate/slow/unknown
at fixed thresholds 2000ms/30000ms). These are exactly the "selected through `--cost-class` or
`--class`, never a hand list" mechanism deliverable 2(c)'s owed-not-paid fallback set must use —
the mechanism to select a small, declared, non-arbitrary fallback set already exists; what is
missing is only the entry point that invokes it on the unmapped-path branch.

**Timings consumer chain (deliverable 4)**: confirmed `run-all.sh --timings FILE` writes a
per-suite CSV row plus a final aggregate row; confirmed `measure-gate-costs.sh --regen-hints`
is the *sole* mechanism that regenerates `tests/suite-cost-hints.txt`, and it does so by running
its *own* internal, idle-load-guarded (refuses above a configurable 1-minute-load threshold),
multi-run-averaged (`MEASURE_RUNS`, default/minimum 2) `run-all.sh --timings` invocation, with
explicit overwrite protection against writing a contaminated sample over a previously-clean
artifact. This script's own header states plainly that a single, unguarded sample must never be
trusted for a cost-class decision. A touched-path-scoped entry-point run is, by construction,
exactly the kind of sample this guard exists to reject as an input to `suite-cost-hints.txt`:
it is scoped (not the full corpus), typically single-sample, and runs under whatever load happens
to exist at dispatch time. Folding its `--timings` output into `suite-cost-hints.txt` directly
would be precisely the "self-maintaining mutable cache" `run-all.sh`'s own `--jobs` header
explicitly rejects as a design (see that header's own "Rejected alternatives for `--jobs`" list,
first bullet). Task 586 ("suite_gate_cost_standing_consumer") is filed exactly to be the standing
consumer of these probes' output and must not be duplicated by this record (an explicit
constraint already named in this task's own BINDING and TERRITORY EDGES sections).

**Declaration surface precedent (deliverables 5 and 6)**: confirmed
`context/standards/repo-level-declarations.md` documents `.claude-extensions.json`'s top-level
sibling-key surface, chosen specifically because the Lua loader's read/write path round-trips
the whole top-level table without stripping unknown keys, so a hand-authored sibling key survives
every load/unload/redeploy cycle. Two schemas already live there
(`derived_artifact_probes`, `coupled_generated_surfaces`), each with an established
fail-open-on-absence table (no file / no `jq` / absent key / empty array / malformed entry all
degrade to zero effect, never a block). This is the clear precedent surface for: (a) deliverable
5's tree-root-and-root-set declaration (a repository with several deploy roots, or project
sources outside the deploy tree); (b) deliverable 6's resolver-backend declaration (a consumer
repository's own command emitting the resolver interface's output shape). Both task 599
("batch_gate_deferral_narrowing_for_project_sources," owning how the deferral directive resolves
a consumer repository's own gates) and task 651 ("orchestration_close_owns_full_battery,"
deliverable 5, "the same declaration surface the project-sources narrowing record designs") name
this *same* surface as the one they need — all three records (650, 599, 651) must converge on one
schema addition, not three independent ones. This record's own deliverable 5 text already says
so explicitly ("Coordinate the declaration shape with the record that owns narrowing forms for
project sources").

### External Resources

No web research was needed or performed — every claim in the task description is directly
re-derivable from this repository's own source store and from the two consumer repositories the
user named, both of which were directly readable on this machine.

**sf1-engine task 33** (`/home/benjamin/Projects/Sapience/sf1-engine/specs/TODO.md`, "Scoped
verify and orchestration close battery," status `[NOT STARTED]`): independently measures the
identical shape — a 77-suite tree run across three deploy roots by a single-flight-unguarded
`integration/tools/run-core-suite-three-roots.sh` wrapper that uses none of `run-all.sh`'s own
narrowing/scheduling; its own deliverables 2-4 are a near-verbatim restatement of this record's
deliverables 1-2 (same `verify-touched.sh` shape, same NO-SUITE-BY-CLASS/EXPLICIT MAP
ROW/OWED-NOT-PAID/coverage-report four-way classification, same "owed, not paid" vocabulary
verbatim) scoped to its own tree. This repository's own task explicitly treats `run-all.sh` and
`suite-selection-lib.sh` as *upstream, copied* files it must not locally diverge without
recording the divergence beside existing notes in its own `extensions/core/README.md` — i.e. it
is a consumer of whatever this record builds, not an independent reimplementation competing with
it, and its own deliverable 6 explicitly defers the "declare it as this repository's closing
gate" step to "whatever repository-level declaration surface the deployed agent system reads" —
the same surface named above.

**sapience-app task 50** (`/home/benjamin/Projects/Sapience/sapience-app/specs/TODO.md`, "Tiered
pytest gate and change aware selection," status `[NOT STARTED]`): this is the exact measured
evidence the task description cites for deliverable 6 ("suite_selection_select returns
`__FULL_SWEEP__` for every path in that repository's declared scope"), confirmed verbatim in that
task's own WHY paragraph. Critically, that task's own "CROSS-REPOSITORY EDGES" section states the
sequencing explicitly and bidirectionally: it needs this record's resolver-interface output shape
(a selection token set plus a per-path unresolved list, with "cannot resolve" distinct from
"resolved to nothing") to avoid inventing a second one, but will proceed with its *own* chosen
shape and record the reasoning if this record has not landed and redeployed by the time its own
deliverable 2 is written — with no blocking dependency declared in either direction. This is a
real, live, externally-verified reason for this record's own planning phase to settle the
resolver interface's exact output shape with enough precision that a non-shell, non-core backend
author (who will never read this record's source code, only its published contract in
`context/standards/shell-script-testing.md`) can implement a conforming backend without
guessing.

## Recommendations

1. **Deliverable 1 (entry point)**: implement as a new script under
   `agent-system/extensions/core/scripts/` (name TBD in planning — candidates: `verify-touched.sh`,
   mirroring both named consumer repositories' own chosen name, or `scoped-verify.sh`) that (a)
   resolves touched paths (default: `git diff --name-only` against working tree + staged, against
   a named base — mirror the two-candidate deploy/source-store resolution pattern already inline
   in `orchestrate-build-dispatch.sh`, factored out rather than copied a third time); (b) calls the
   deliverable 6 resolver interface (default backend `suite_selection_select`); (c) on a real
   suite set, invokes `run-all.sh --only <resolved> --jobs auto --timings <file>`; (d) on
   `__FULL_SWEEP__`/unmapped paths, invokes the deliverable 2 classified fallback instead of a
   full sweep; (e) prints the resolved suites, the unresolved paths, and a verdict string
   deliberately distinct from both the unnarrowed-pass string and `--gate8-touched`'s own
   narrowed-pass string (three distinct strings total across the corpus, each asserted verbatim
   by its own regression suite — do not collide with either existing one). This is the single
   command `plan-format.md`'s Tier Justification authoring rule and the Batch Gate Deferral
   directive should both be rewritten to name, replacing their current two-raw-invocation prose.

2. **Deliverable 2 (classified fallback)**: implement the four outcomes as described, with the
   owed record (2c) written as a file under the invoking task's own `records/` directory (the
   plan-format.md-sanctioned durable-record shape for a cross-dispatch-contingent fact), never a
   dispatch-written sidecar. Decide in planning, not research, the exact file naming and whether
   one record aggregates multiple owed paths or one file per path — but anchor the decision on
   the discharge consumer: `orchestrate-batch-gate.sh` (Move 4) is the concrete, already-existing,
   once-per-invocation unnarrowed-run site the sibling orchestration-close record (651,
   deliverable 6) explicitly names as this record's owed-sweep discharge point, so the record's
   shape should be whatever Move 4 can cheaply enumerate and clear (e.g., one row per task
   directory it already iterates for finding-attribution, not a corpus-wide scan it would have to
   invent). Recommend keeping `__FULL_SWEEP__` itself as an opt-in strict mode (a `--full-sweep`
   flag on the new entry point) for a caller that genuinely wants the pre-existing behavior,
   rather than removing the sentinel from `suite-selection-lib.sh` — the library's own public
   contract (the sentinel constant) is explicitly out of scope for a second implementation per
   this task's BINDING paragraph, and callers other than this new entry point (direct scripting,
   `--gate8-touched`'s own fallback) still depend on it unchanged.

3. **Deliverable 3 (preflight + authority)**: add a preflight step to the new entry point itself
   (not to `run-all.sh`), modeled on `verify-deploy.sh`'s `gate0` — validate map/class data files
   parse, every suite basename any axis names actually exists on disk, and the declared fallback
   set is non-empty, before any resolution or `--only` invocation runs. State in
   `context/standards/shell-script-testing.md` (alongside the existing "Mapping a touched file to
   its suite" subsection) the authority ruling: `test-run-all-selection.sh` and the
   `test-*-gate-selection*.sh` suites' PASS is authoritative only under the complete, unfiltered
   run (orchestration close, once 651 lands), and the new entry point's own preflight is a
   second, independent, pre-selection guard for the narrower class of defects it can catch
   mechanically — neither guard requires forcing these suites into every scoped selection.

4. **Deliverable 4 (timings)**: state plainly that the new entry point's `--timings` output is a
   per-invocation diagnostic artifact only — written wherever the caller names (default:
   plausibly a path under the invoking task's own directory when run from a dispatch, or a
   `mktemp` location otherwise; decide the exact default in planning) — and is explicitly NOT an
   input to `suite-cost-hints.txt`'s regeneration, which remains exclusively
   `measure-gate-costs.sh --regen-hints`'s job (task 586's territory) because that script's
   idle-guard and multi-run averaging cannot be satisfied by a scoped, single-sample, ambient-load
   run. Document this non-consumption explicitly in the new script's own header so a future reader
   does not "helpfully" wire it in and reintroduce the self-maintaining mutable cache
   `run-all.sh`'s own header already rejected.

5. **Deliverable 5 (multi-root/project trees)** and **deliverable 6 (resolver interface)**: add
   both as new sibling keys under `.claude-extensions.json`, following
   `repo-level-declarations.md`'s established schema conventions (named entries, a documented
   fail-open-on-absence table, an inline or `scripts/lib/`-promoted reader keyed on a
   single-vs-multiple-consumer threshold exactly as that document's own
   `coupled_generated_surfaces` precedent states). Planning must explicitly coordinate the exact
   key names and shapes with task 599 (directive-level consumer-gate resolution) and task 651
   (deliverable 5, closing-gate declaration) — all three need variations of "this repository's own
   gates/roots/backend," and a fourth independently-shaped key would contradict this task's own
   "not a second declaration surface" framing. For the resolver interface itself (deliverable 6),
   the output shape must be settled precisely enough for sapience-app's task 50 to consume
   without guessing (see Findings above) — at minimum: a selection-token-set stream, a per-path
   unresolved list, and a distinguishable exit/output signal for "this backend cannot resolve at
   all" versus "resolved to the empty set," with the conformance check deliverable 6 asks for
   validating exactly this shape against a declared backend command before trusting its output.
   Decide explicitly in planning whether a declared backend replaces the default basename backend
   or composes with it (union) — recommend union-by-default (never silently losing core's own
   basename coverage for a repository that also ships a few core-authored shell suites alongside
   its primary non-shell suite), with the rejected alternative (full replacement) recorded.

## Decisions

- The two narrowing-invocation resolution pattern already inline in
  `orchestrate-build-dispatch.sh` (deployed-mirror-first, source-store-fallback, degrade-to-prose
  if neither exists) is the correct model for the new entry point's own dual-mode resolution, and
  should be factored into a shared location rather than copied a third time — this is a planning
  decision, not merely a research observation, because at least three sites now need the same
  resolution (the directive composer, the new entry point, and potentially a future
  `--gate8-touched` caller).
- `__FULL_SWEEP__` as a library-level sentinel is NOT being replaced or removed by this record;
  only the new entry point's own unmapped-path *handling* of it changes (classified fallback
  instead of blind full sweep). The rejected alternative — retiring the sentinel outright — is
  explicitly rejected because other callers of `suite_selection_select` (direct scripting,
  `--gate8-touched`'s own fallback inside `verify-deploy.sh`) depend on its existing contract and
  this record's BINDING clause rules out a second selection engine.
- `suite-cost-hints.txt`'s regeneration authority stays exclusively with
  `measure-gate-costs.sh --regen-hints` (task 586's territory); the new entry point's `--timings`
  output is diagnostic-only and must not feed that regeneration path, rejecting the
  self-maintaining-mutable-cache alternative `run-all.sh`'s own header already rejected for a
  different flag.
- Deliverables 5 and 6's declarations belong on the existing `.claude-extensions.json`
  sibling-key surface, not a new declaration mechanism — rejecting a per-repository config file
  or an environment-variable-based declaration as alternatives, because the existing surface
  already has the survival guarantee, the fail-open convention, and three other records (599,
  651, and this one) all independently converging on needing "this repository's own X" data from
  exactly that location.

## Risks & Mitigations

- **Risk**: three records (650, 599, 651) each add declaration keys to `.claude-extensions.json`
  independently and converge on incompatible shapes. **Mitigation**: this record's planning phase
  should not finalize the key schema without first reading whichever of 599/651 has a plan or
  report artifact already on disk at planning time, and should explicitly record the chosen shape
  so the other two can adopt it rather than re-deriving it (same posture sapience-app's task 50
  already states for itself).
- **Risk**: the owed-record discharge mechanism (deliverable 2c) is designed before task 651
  (which owns Move 4 and the orchestration-close ruling) has decided its own final shape for
  "what Move 4 does," producing a record format Move 4 cannot actually consume. **Mitigation**:
  task 651 already names this record's owed-sweep output as its own deliverable 6 input — treat
  that as the authoritative consumer contract and keep the owed-record shape minimal and
  inspectable (plain per-path/per-task rows) rather than inventing machinery Move 4 would need to
  be taught separately.
- **Risk**: the resolver interface (deliverable 6) is specified loosely enough that
  sapience-app's task 50 cannot conform to it without guessing, forcing a second interface
  revision after a real non-shell backend already exists. **Mitigation**: write the interface
  contract and its conformance check in the same planning pass, using sapience-app's task 50 own
  stated needs (selection token set, per-path unresolved list, distinguishable "cannot resolve"
  signal) as the acceptance test for the contract's own completeness, even though that repository
  is not this task's territory.

## Context Extension Recommendations

- **Topic**: a single canonical name/shape for "this repository's own gates/roots/resolver
  backend" declared via `.claude-extensions.json`.
- **Gap**: `repo-level-declarations.md` currently documents two schemas
  (`derived_artifact_probes`, `coupled_generated_surfaces`) but no general guidance for *how many
  more* sibling keys this surface is expected to grow to, or a naming convention that would help
  three concurrently-planned records (650, 599, 651) land non-colliding, mutually-consistent keys
  without an explicit coordination step each time.
- **Recommendation**: once this record's (and 599's and 651's) planning settles the actual key
  names, add a short "Declared gate/root/backend keys" subsection to
  `repo-level-declarations.md` cataloguing every sibling key by name and owning record, the same
  way this document already distinguishes its two existing schemas by their different questions
  ("is this derived artifact stale now?" vs. "did the plan author declare this derived
  artifact?") — so a fourth future record can find the existing convention before adding a fifth,
  independently-shaped key.

## Appendix

- Direct file reads (no web search performed): `scripts/tests/run-all.sh` (full header + flag
  parsing), `scripts/lib/suite-selection-lib.sh` (full file, 646 lines), `scripts/orchestrate-build-dispatch.sh`
  (lines ~600-800, the Batch Gate Deferral composition block), `context/formats/plan-format.md`
  (Verification Tiers section, lines 401-560), `context/standards/shell-script-testing.md`
  (lines 886-1105, suite-selection and gate8-touched subsections), `context/standards/repo-level-declarations.md`
  (full file), `context/contracts/batch-gate-stage.md` (lines 1-60), `scripts/orchestrate-batch-gate.sh`
  (header), `scripts/measure-gate-costs.sh` (header), `scripts/tests/suite-cost-hints.txt`
  (header), `specs/TODO.md` entries for tasks 650, 651, 610, 599, 586, 579.
- Cross-repository reads: `/home/benjamin/Projects/Sapience/sf1-engine/specs/TODO.md` (task 33),
  `/home/benjamin/Projects/Sapience/sapience-app/specs/TODO.md` (task 50), both repositories'
  `.claude-extensions.json` (extension manifests only, to confirm loaded extension sets).
- No `user_decision` is set: every open question this report surfaces (declaration key names,
  owed-record file shape, entry-point script name, union-vs-replace resolver composition) is a
  planning-level design choice this record's own planning phase can resolve from the evidence
  above, not a preference requiring the user's judgment.
