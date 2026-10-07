# Research Report: Task #250

**Task**: 250 - Script-corpus inventory probe, then cut tests/run-all.sh runtime and decompose orchestrate-cycle-plan.sh
**Started**: 2026-10-02
**Completed**: 2026-10-02
**Effort**: large (multi-phase: standing probe + incremental behavior-preserving refactor)
**Dependencies**: Task 199, Task 245, Task 249, Task 259, Task 265, Task 266 (all COMPLETED — verified live, see Findings)
**Sources/Inputs**: Codebase exploration (agent-system/extensions/core/scripts/**), specs/state.json, specs/TODO.md, git history
**Artifacts**: specs/250_script_corpus_inventory_and_engine_decomposition/reports/01_script-corpus-inventory-probe-and-decomposition.md
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- The dispatch's own 2026-09-22 measurement is stale and must be re-taken: the non-test corpus
  has grown to **194 files / 71,337 lines** (was 182/63,740), and `orchestrate-cycle-plan.sh`
  specifically has grown to **3,026 lines** (was 2,279) — now 30.7% of a 9,844-line engine
  across 13 files (down from 14; two scripts were consolidated/retired since). `lib/` has grown
  to **17 libraries / 3,310 lines** (was 14/2,564). The ranked-ordering and size-threshold
  language in the task description should be treated as illustrative, not as fixed numbers to
  reproduce — Phase 1's probe is the re-measurement.
- Both of the dispatch's "ALSO OBSERVED" findings from 2026-10-02 (manifest-registration gap
  for `migrate-state-legacy-fields.sh`; `scheduled_tasks.lock` orphan false positive) are now
  **resolved** — tasks 323 and 324, both COMPLETED. Phase 1 should treat verify-deploy.sh as
  clean on these two points, not re-litigate them.
- All six declared dependencies (199, 245, 249, 259, 265, 266) are COMPLETED. The conflict
  these dependencies existed to avoid — concurrent rewrites of `orchestrate-batch-admit.sh` and
  an undecided working-tree/isolation posture — is cleared.
- **New risk not in the dispatch**: task 272 (`honest_session_liveness_concurrent_batches`,
  status `not_started`) declares `orchestrate-cycle-plan.sh` in its own `file_scope`. It is not
  in flight today, but a Phase 2 decomposition plan should either coordinate with it explicitly
  or re-check its status immediately before editing, since it is the same class of hazard the
  199/batch-admit dependency was filed to prevent.
- `build_contended_manifest()` (657 lines) plus its three helper functions
  `build_sibling_territory()`, `_paths_contend()`, and `_sibling_territory_classify_entry()`
  (93+20+14 lines) form a single, cleanly bounded 784-line "territory contention" concern —
  ~26% of the file — that is the single highest-leverage, lowest-risk first extraction target
  for Phase 2. `task_has_forced_phase()` (358 lines) + `task_is_build_heavy_implement()` (177
  lines) form a second, independent 535-line "task classification" concern.
- The manifest-registration check Phase 1's probe needs (item 5: "registered in the owning
  manifest's `provides.scripts`") already exists as Rule Q (`check_undeclared_scripts`,
  `check-extension-docs.sh:530-580`) — the probe should shell out to or share logic with that
  rule rather than reimplementing it, per the dispatch's own "reuse, do not reimplement"
  instruction.
- No existing duplicate-block-detection tooling was found anywhere in the repository. This
  probe item (Phase 1, bullet 4) has no precedent to reuse and must be built from scratch; it is
  the single largest unknown-cost item in Phase 1 and should be scoped simply (fixed-size
  normalized line-window hashing, not a general clone-detection algorithm) to avoid becoming its
  own analysis-only rabbit hole.

## Context & Scope

This is the **research phase only** for task 250. The task itself is explicitly two-phase
(Phase 1: build a standing mechanical inventory probe; Phase 2+: act on its ranked output to
decompose `orchestrate-cycle-plan.sh`), and the dispatch's own anti-analysis constraint states
that any phase whose only artifact is prose is out of contract. This report does not build the
probe or touch `orchestrate-cycle-plan.sh` — both are implementation work for later phases. Its
job is to re-verify the dispatch's stale measurements, confirm the dependency/conflict posture is
still safe to proceed, identify the concrete extraction candidates in the target file, locate
existing conventions and logic Phase 1 must reuse rather than reimplement, and surface anything
the dispatch did not already know (principally, the task 272 file-scope overlap).

The dispatch itself is unusually information-dense (a worked example, three closed-out
path-review entries, a re-measure confirmation) — this report deliberately does not restate that
content, only the parts that needed independent verification or that update it.

## Findings

### Codebase Patterns

**Re-measured corpus size (2026-10-02, this report).** Using
`find agent-system/extensions -name '*.sh' -type f | grep -v '/tests/' | grep -v '/test-'`:
- 194 non-test `.sh` files, 71,337 lines total (dispatch's 2026-09-22 figure: 182 files, 63,740
  lines — an 11.5% file-count increase and 11.9% line-count increase in ~10 days).
- 113 test files (`/tests/` dir + flat `test-*.sh`) in addition to the 194.

**Orchestrate engine, re-measured**: 13 `orchestrate-*.sh` scripts (not 14 — the roster has
changed), 9,844 lines total:

```
   177  orchestrate-recover-message-findings.sh
   223  orchestrate-churn.sh
   247  orchestrate-build-aux-dispatch.sh
   267  orchestrate-loop-guard-init.sh
   300  orchestrate-stage5-postflight.sh
   304  orchestrate-stage5-gates.sh
   335  orchestrate-recover-outcome.sh
   403  orchestrate-unwind-dispatch.sh
   550  orchestrate-triage-classify.sh
   568  orchestrate-build-dispatch.sh
   893  orchestrate-predispatch-review.sh
   991  orchestrate-batch-admit.sh
  3026  orchestrate-cycle-plan.sh
```

`orchestrate-cycle-plan.sh` is now 3,026 lines — 30.7% of the engine (was 27.8% of 8,207 at
2,279 lines), and roughly 5.5x the 550-line second-largest file
(`orchestrate-triage-classify.sh`) rather than the dispatch's cited 6.5x-of-median comparison
against a 14-script family. The file has grown, not shrunk, since the dispatch was written —
consistent with the task's own thesis that nothing currently reviews or pressures this corpus.

**`lib/`, re-measured**: 17 libraries, 3,310 lines (was 14/2,564):
`common.sh`, `continuation-pointer-lib.sh`, `deploy-baseline-lib.sh`, `deploy-freshness-lib.sh`,
`deploy-ledger-lib.sh`, `file-scope-overlap.sh`, `manifest-routing-lib.sh`,
`phase-heading-patterns.sh`, `plan-status-line.sh`, `push-grant-lib.sh`,
`return-meta-artifacts-lib.sh`, `return-meta-status-vocabulary.sh`, `runtime-file-patterns.sh`,
`status-vocabulary.sh`, `task-lookup-lib.sh`, `task-reference-patterns.sh`,
`task-type-detect.sh`. The extraction pattern the dispatch calls "established and working" is
confirmed current — three new libs have landed since 2026-09-22, so Phase 2's approach is
consistent with ongoing practice, not a one-off.

**`orchestrate-cycle-plan.sh` function-size breakdown** (top-level `name() {` definitions,
line-delta between consecutive definitions — a conservative proxy for function extent since it
includes any trailing blank lines before the next definition):

```
  688  line   762  orchestrate_cycle_plan_main()
  657  line  2370  build_contended_manifest()
  358  line  1585  task_has_forced_phase()
  177  line  1943  task_is_build_heavy_implement()
  163  line   319  usage()
  130  line   482  lookup_project()
  107  line   655  emit_and_exit()
  104  line  1450  aux_fixed_agent()
   93  line  2257  build_sibling_territory()
   87  line  2156  compose_focus()
   37  line   282  run_capture_stdout()
   29  line  2127  resolve_agent()
   25  line   630  mt_set()
   20  line  2350  _paths_contend()
   17  line  1554  is_terminal_status()
   14  line  2243  _sibling_territory_classify_entry()
   14  line  1571  in_json_array()
    9  line   621  mt_get_json()
    7  line  2120  cycle_plan_dispatch_hash()
    5  line   616  mt_get()
    4  line   612  mt_save()
```

Two cohesive, independently extractable concerns stand out:

1. **Territory/contention** — `build_contended_manifest()` (657 lines) +
   `build_sibling_territory()` (93) + `_paths_contend()` (20) +
   `_sibling_territory_classify_entry()` (14) = **784 lines (~26% of the file)**. These four
   functions are called in sequence and share no state with the rest of the file beyond
   `lookup_project()` and `jq`. `build_contended_manifest()` writes
   `$CONTENDED_MANIFEST_DIR/${session_id}.json`, consumed downstream by
   `git-commit-scoped.sh` (confirmed via grep: `git-commit-scoped.sh:19` references
   `build_contended_manifest` by name in a comment). This is the single largest, best-isolated
   extraction candidate in the file, and it is adjacent to — but does not duplicate — the
   existing `lib/file-scope-overlap.sh` (219 lines, `scopes_overlap()` / `path_covered_by_scope()`):
   that lib provides path-matching primitives; `build_contended_manifest()` is multi-task
   territory-manifest construction built on top of them. A new
   `lib/territory-contention-lib.sh` (or similarly named) that sources/complements
   `file-scope-overlap.sh` rather than re-deriving its primitives is the natural shape.
2. **Task classification** — `task_has_forced_phase()` (358 lines) +
   `task_is_build_heavy_implement()` (177 lines) = **535 lines (~18% of the file)**. Both take a
   task entry/number and return a classification used by `orchestrate_cycle_plan_main()`; neither
   appears to depend on the territory functions above or on each other beyond shared helpers
   (`lookup_project()`, `in_json_array()`, `is_terminal_status()`).
3. `orchestrate_cycle_plan_main()` itself (688 lines) is the main dispatch-assembly entry point
   and the hardest to extract cleanly — it is likely to need decomposition into named sub-stage
   functions (e.g. by reading its internal section comments) rather than a single lib pull-out,
   and should be sequenced **after** items 1 and 2 land and shrink the file, per the dispatch's
   own "size each extraction to one agent run" instruction.

Combined, extracting items 1 and 2 alone would remove ~1,319 lines (~44% of the file) in two
bounded, independently testable phases, without touching `orchestrate_cycle_plan_main()` at all.

**Existing probe conventions** (`scripts/assess-repo-health.sh`, 267 lines;
`scripts/measure-eager-context.sh`, 543 lines; `scripts/check-extension-docs.sh`, 1,516 lines)
confirm the shape the dispatch asks Phase 1 to follow: stdout-JSON, `--check`-style read-only
mode, extensive header comments documenting enumeration/existence-filter/degenerate-case
semantics up front, and `--root`-style override flags for fixture-driven testing rather than
hardcoded paths.

**Manifest-registration check already exists and should be reused, not reimplemented.** Phase
1's probe item 5 ("whether it is registered in the owning manifest's `provides.scripts`") is
Rule Q in `check-extension-docs.sh` (`check_undeclared_scripts`, lines 530-580): it enumerates
on-disk script files under `scripts/` not declared in `provides.scripts`, matching by full
relative path. The dispatch explicitly says "the same class of drift check-extension-docs.sh
already performs — reuse, do not reimplement"; the concrete reuse path is either (a) invoking
`check-extension-docs.sh` and parsing its `FAIL: script file on disk NOT in provides.scripts:
...` lines for the subset relevant to the probe's per-script report, or (b) factoring Rule Q's
core predicate into a shared lib function both scripts call. Given `check-extension-docs.sh` is
1,516 lines and multi-purpose (far more than just Rule Q), option (a) — shelling out and
filtering its output — is lower-risk than extracting shared logic from it in the same task that
is also trying to shrink a *different* oversized file.

**No existing duplicate-block-detection tooling.** Searched for `jscpd`, `simhash`,
`duplicate.*block`, `dup.*detect` across all `.sh` files: zero hits. Phase 1's bullet 4
("duplicated-block detection ACROSS scripts, so copy-paste that belongs in lib/ is visible") has
no precedent to reuse anywhere in this codebase. This is a genuine build-from-scratch item and
the least-specified part of the probe's contract — see Risks below for a scoping recommendation.

**Inbound-caller counting** likewise has no exact precedent: `check-extension-docs.sh`'s Rule E
(`check_referenced_scripts_declared`) scans docs/skills/agents for *script-name* references
against `provides.scripts`/`provides.hooks`, which is the closest existing pattern, but it answers
a different question (is this script declared) rather than counting inbound references from
other scripts via `source`/`bash`/direct invocation. A caller-count probe will need its own grep
pass (e.g. `grep -rl '\b<script-basename>\b'` across skills, agents, commands, manifests, hooks,
and other scripts, with the probed script's own file excluded) — straightforward, but new code,
not reuse.

### External Resources

None consulted — this is a self-contained codebase-structure task with no external API or
library dependency; all relevant precedent is internal.

### Dependency and Conflict Status

All six dependencies the task declares are confirmed COMPLETED in `specs/state.json`:

| Task | Status | Title |
|---|---|---|
| 199 | completed | concurrent_dispatch_isolation_posture |
| 245 | completed | batch_admit_defer_against_admitted_set_only |
| 249 | completed | restore_eager_context_budget |
| 259 | completed | allow_completion_on_a_gate_skipped_plan_branch |
| 265 | completed | parallelize_gate8_shell_test_suite |
| 266 | completed | deploy_pending_vs_identical_dispatch_guard |

The dispatch's two named reasons to wait — "199 decides the working-tree/isolation posture" and
"the in-flight admission task rewrites `orchestrate-batch-admit.sh`" (task 165,
`admission_posture_for_absent_file_scope`, which also lists `orchestrate-cycle-plan.sh` in its
own `file_scope`) — are both resolved: 199 is completed, and 165 is also completed (confirmed
directly in state.json, `project_number==165`, status `completed`).

**New finding, not in the dispatch**: task 272 (`honest_session_liveness_concurrent_batches`,
status `not_started`) declares `orchestrate-cycle-plan.sh` in its own `file_scope` (alongside
`orchestrate-predispatch-review.sh`, `task-lock.sh`, and others). It is not currently in flight,
so it is not a blocking dependency today, but it is the same hazard class the 199/165 dependency
pair existed to avoid: a concurrent task altering the same file's behavior while Phase 2
decomposes it structurally. `specs/TODO.md:1200` already documents this exact overlap generally
("#250, #165, #272, #265 and #293 touch orchestrate-cycle-plan.sh. Do not batch this task
concurrently with those."). Recommendation: at plan time, either (a) add task 272 to this task's
declared dependencies so batch admission defers it automatically, or (b) re-check its status
immediately before Phase 2 begins editing and abort/coordinate if it has moved off
`not_started`.

**verify-deploy.sh findings from the dispatch are resolved.** Both items the dispatch's
2026-10-02 "ALSO OBSERVED" entry flagged for re-checking are now closed:
- The `migrate-state-legacy-fields.sh` manifest-registration gap: fixed by task 323 (completed)
  — confirmed directly: `manifest.json:146` now lists `"migrate-state-legacy-fields.sh"`.
- The `scheduled_tasks.lock` gate-13 orphan false positive: fixed by task 324 (completed).

Phase 1's probe and Phase 2's acceptance checks should expect `verify-deploy.sh --skip-slow` to
be clean on these two points without needing to re-derive or re-litigate them; the 2 of 33
failures the dispatch recorded for 2026-10-02 are gone, not merely accounted for.

**`verify-deploy.sh` gate selector exists.** `--only-gate` is present and documented in
`verify-deploy.sh` (confirmed: `--only-gate N[,M,...]`, additive-only, `GATES_FILTER`
population) — consistent with the dispatch's closed-out worked example (the gate-selector
delivery from the completed test-suite-runtime task). No action needed here; noted only because
Phase 1's probe, if it ever needs to invoke `verify-deploy.sh` for a sub-check, should use
`--only-gate` rather than a full run.

## Decisions

- **Treat all dispatch-stated measurements (182 files/63,740 lines; 2,279-line
  `orchestrate-cycle-plan.sh`; 14 orchestrate scripts/8,207 lines; 14 libs/2,564 lines) as
  superseded by this report's re-measurement.** The plan phase should cite this report's numbers
  (194/71,337; 3,026 lines; 13 scripts/9,844 lines; 17 libs/3,310 lines), and Phase 1's own probe
  output — once it exists — becomes the next authoritative source, superseding even this report.
- **The two "ALSO OBSERVED" verify-deploy findings do not need to be re-investigated or
  included as probe findings.** They are closed (tasks 323, 324). Phase 1's probe should not
  special-case or re-flag `migrate-state-legacy-fields.sh` or `scheduled_tasks.lock`.
- **Phase 1's manifest-registration probe item reuses `check-extension-docs.sh` Rule Q by
  invocation, not by logic extraction**, given the size and multi-purpose nature of that 1,516
  line script relative to the scope of this task.
- **Phase 2's first two extraction targets, in order, are: (1) the territory/contention concern
  (`build_contended_manifest` + 3 helpers, 784 lines) and (2) the task-classification concern
  (`task_has_forced_phase` + `task_is_build_heavy_implement`, 535 lines).**
  `orchestrate_cycle_plan_main()` (688 lines) is deferred to a later phase, after the file has
  already shrunk from these two extractions, consistent with the dispatch's "size each
  extraction to one agent run" instruction.
- **Task 272's `orchestrate-cycle-plan.sh` file_scope overlap is a plan-time decision, not a
  blocking one** given its current `not_started` status, but it must be explicitly addressed
  (dependency addition or a pre-edit status re-check) rather than silently ignored, since it is
  materially the same risk class the dispatch already treats as dependency-worthy for 199/165.

## Recommendations

1. **Phase 1 probe implementation**: follow the `assess-repo-health.sh`/`measure-eager-context.sh`
   convention exactly (stdout JSON, `--check` mode, `--root` override, no side effects, extensive
   header comments documenting enumeration and degenerate cases). Emit, per non-test script:
   path, line count, byte count, inbound caller count, test-coverage boolean (paired against
   `scripts/tests/*.sh` and flat `scripts/test-*.sh` by basename convention), manifest-registration
   boolean (via Rule Q reuse), and a duplicated-block flag/count. Emit a stable ranked ordering
   (e.g., by line count descending with caller count as tiebreaker, or an explicit composite
   score) so Phase 2+ target selection is auditable.
2. **Scope the duplicate-block detector minimally**: fixed-size (e.g. 8-12 line) normalized
   (whitespace-collapsed, comment-stripped) line-window hashing within and across files, reporting
   only windows duplicated 3+ times or spanning 2+ files — not a general clone-detection engine.
   This is the one Phase 1 item with no existing precedent and the highest risk of scope creep;
   keep it simple enough to finish in-budget and revisit later if it proves too coarse or too
   noisy.
3. **Register the new probe in `docs/reference/utility-scripts-inventory.md`** alongside
   `assess-repo-health.sh` and `measure-eager-context.sh`'s existing entries, following their
   one-paragraph entry format exactly.
4. **Phase 2 extraction order**: territory/contention (784 lines) first, task classification (535
   lines) second, `orchestrate_cycle_plan_main()` decomposition (688 lines, likely into named
   sub-stages rather than a single lib) third and separately phased. Capture the `--dry-run` JSON
   payload and human table baseline for a representative multi-task invocation **before** any
   extraction begins (the dispatch's own instruction), and diff after each of the two
   independent extractions, not only at the end.
5. **At plan time, resolve the task 272 file-scope overlap explicitly** — either add it as a
   dependency (if still open when planning happens) or record a point-in-time status check
   immediately before Phase 2 begins editing.
6. **Do not re-derive or re-report** the run-all.sh timing data, the three refuted leads, or the
   two now-closed verify-deploy findings as if they were new — the dispatch is explicit and
   correct that this ground is already covered; Phase 1's probe should *consume* the existing
   per-suite timing baseline (`suite-cost-hints.txt`, referenced in the dispatch's 2026-10-02
   re-measure entry) as one input signal if a per-script/per-suite timing correlation is useful,
   rather than re-timing anything itself.

## Risks & Mitigations

- **Risk**: the corpus is growing faster than it is being measured (11.5% file-count growth in
  10 days) — any ranked-ordering snapshot in a report goes stale quickly.
  **Mitigation**: this is exactly why Phase 1 builds a *standing* probe rather than a one-off
  report; no further mitigation needed beyond landing Phase 1 promptly.
- **Risk**: duplicate-block detection (Phase 1 bullet 4) is unscoped and has no precedent;
  attempting a thorough clone-detection algorithm could consume the entire phase budget.
  **Mitigation**: see Recommendation 2 — bound it to simple fixed-window hashing with a
  conservative duplication threshold, explicitly deferring sophistication to a follow-up if the
  simple version proves inadequate.
- **Risk**: task 272 begins editing `orchestrate-cycle-plan.sh` concurrently with Phase 2's
  decomposition, reintroducing the exact hazard the 199/165 dependency pair was filed to avoid.
  **Mitigation**: see Decisions/Recommendation 5 — explicit dependency addition or pre-edit
  status re-check, not silent proceeding.
- **Risk**: `build_contended_manifest()`'s output file
  (`$CONTENDED_MANIFEST_DIR/${session_id}.json`) is consumed by `git-commit-scoped.sh`; an
  extraction that changes sourcing order or variable scoping could silently break that downstream
  consumer without any test in `test-orchestrate-cycle-plan.sh` (4,941 lines) catching it if that
  suite doesn't exercise the commit-scoped interaction.
  **Mitigation**: before extracting, confirm `test-orchestrate-cycle-plan.sh` and/or
  `git-commit-scoped.sh`'s own tests cover the contended-manifest file's presence/absence and
  content across a representative multi-task scenario; if not, add that coverage as part of (not
  after) the extraction, per the "never weaken or delete a test" and "green after each
  extraction" instructions already in the dispatch.
- **Risk**: function-size figures in this report (line-delta between consecutive top-level
  function definitions) are a conservative proxy, not an exact AST-level function-body line
  count — trailing comments/blank lines before the next definition are included. This does not
  change the ranking or the extraction recommendation, but Phase 1's probe should use a more
  precise measure (e.g. matching the function's own closing brace) if per-function size becomes
  part of its persistent output.

## Context Extension Recommendations

- **Topic**: standing repo-health probes
  **Gap**: `docs/reference/utility-scripts-inventory.md` documents `assess-repo-health.sh` and
  `measure-eager-context.sh` individually but has no single index describing the shared
  conventions (stdout JSON, `--check` mode, `--root` override, degenerate-case documentation
  style) that a new probe author should follow.
  **Recommendation**: once Phase 1's probe lands, consider adding a short "Probe Script
  Conventions" subsection to that doc (or a dedicated guide) distilling the shared shape across
  all three probes, so the next one doesn't require re-deriving the convention by reading prior
  scripts' source.

## Appendix

- Search queries/commands used: `find ... -name '*.sh'` corpus counts (whole-extensions and
  precise non-test variants), `wc -l` on `orchestrate-*.sh` and `lib/*.sh`, a Python pass over
  `grep -n '^[a-zA-Z_]*() {'` output to compute per-function line deltas in
  `orchestrate-cycle-plan.sh`, `jq` queries against `specs/state.json` for dependency/conflict
  task statuses, `grep` for `jscpd|simhash|duplicate.*block|dup.*detect` (no hits), and targeted
  reads of `check-extension-docs.sh` (Rules E and Q), `scripts/assess-repo-health.sh`'s header,
  and `verify-deploy.sh`'s `--only-gate` implementation.
- References: `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`,
  `agent-system/extensions/core/scripts/check-extension-docs.sh`,
  `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh`,
  `agent-system/extensions/core/scripts/assess-repo-health.sh`,
  `agent-system/extensions/core/scripts/measure-eager-context.sh`,
  `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`,
  `specs/state.json`, `specs/TODO.md` (task 250, 272, 323, 324 entries).
