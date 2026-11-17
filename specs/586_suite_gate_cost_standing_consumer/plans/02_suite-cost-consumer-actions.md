# Implementation Plan: Task #586

- **Task**: 586 - Suite/gate wall-clock cost standing consumer
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None blocking. Two concurrent siblings (604, 624) share this cycle's working
  tree; their declared `file_scope` sets are disjoint from this plan's — see Territory below.
- **Research Inputs**: `specs/586_suite_gate_cost_standing_consumer/reports/02_suite-cost-verdict-table.md`
  (primary), `specs/586_suite_gate_cost_standing_consumer/reports/01_suite-gate-cost-audit.md` (seed)
- **Artifacts**: plans/02_suite-cost-consumer-actions.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This record is the standing consumer for the suite/gate wall-clock cost probes, and the research
pass already rendered the verdict its owner ruling asked for: **0 DELETE, 14 KEEP** over the
genuine recursive meta-suite class. So this plan does not delete suites. It acts on the four
things the audit found that *do* have leverage: the one measured, arithmetic wall-clock lever
(a fixed per-invocation corpus probe inside `verify-deploy.sh`, paid 26-29 times over by each of
the two most expensive suites), the live and growing leaked-fixture corpus in `/tmp`, the two
stale probe artifacts that drive real scheduling and cost-class decisions, and the durable
recording of the verdict so the class is not re-litigated by the next naive grep.

Phase ordering is deliberate: the optimization lands **before** the probe artifacts are
regenerated, so the refreshed figures describe the system as it will actually run rather than
needing a second measurement pass.

### Carried-Figure Re-Validation (dispatch premise, re-derived live 2026-11-17)

Every figure this plan acts on was re-derived in this dispatch, per the Premise Re-Validation
block and ROADMAP Standing rule 5. Results, including where they only confirm the description:

| Premise claim | Live result | Verdict |
|---|---|---|
| 1,780 leaked `/tmp` fixtures, 1.1 GB | **1,739 entries, 1.4 GB**, every one owned by the invoking user, dated 2026-11-10 through today with no gap (107-475 per day) | CORRECTED: fewer entries, *more* bytes; leak is live and continuous |
| Read-only (`chmod a-w`) content blocks `rm -rf` (seed mechanism 2; research saw "at least 5 in a 400 sample") | **165 of 1,739 entries (9.5%)** contain at least one non-writable path | CORRECTED UPWARD: far more prevalent than sampled; the `chmod -R u+w` step is load-bearing |
| `gate-cost-model.csv` puts gate8 at 662,462ms | Row present and unchanged, but file header reads `# Generated: 2026-10-19`, `runs=2`, and the file holds **exactly one data row** — it models 1 of ~26 registered gates | CONFIRMED-BUT-STALE, and narrower in scope than "a cost model" suggests |
| 23.5 min total serial wall time | `suite-cost-hints.txt` sums to **1,406,493 ms = 23.44 min** across 156 rows | CONFIRMED (coincidentally; see research report for why) |
| `test-gate-cache-equivalence.sh` alone is 543s | Hint row unchanged, dated 2026-10-16 by `git log -S`; neither research nor this dispatch completed a live re-timing | CARRIED-UNVERIFIED — re-derived in Phase 4, never cited as fact before then |
| 149 suites | Multi-valued: core source-store `test-*.sh` = **157**, this repo's deployed `.claude/scripts/tests/` = **179**, `script-inventory.sh --size-line` reports `test_suites=204` | CORRECTED: "149" matches no live population; a bare suite count is not a safe citation (Phase 5 records the methodology) |
| 35 of 149 suites re-invoke the full battery | Research reclassified to **14** genuine members after removing stub-only and planted-fixture false positives | CORRECTED by research; not re-litigated here |
| Neither probe has a consumer acting on its output | Both have *mechanical* consumers: `suite-cost-hints.txt` → `run-all.sh` longest-first scheduling, `suite-selection-lib.sh`, `script-inventory.sh`'s `cost_per_assertion_ms`; `gate-cost-model.csv` → `deploy-baseline-lib.sh` and `gate-registry.data`'s `--max-cost` classes | REFINED: false as literally worded, true as intended — what is missing is a *remediation* consumer, which is this record |
| Owner ruling: MAY DELETE; DELETE when a gate already asserts it, KEEP when the fixture reaches an unreachable state | Standing instruction, not a measurement; unchanged, and applied verbatim by research to the corrected 14-member set | CONFIRMED UNCHANGED |
| Source store is the edit target: `agent-system/extensions/core/**` | `.claude-extensions.json` `.extensions.core.source_dir` resolves to `/home/benjamin/.config/nvim/agent-system/extensions/core` | CONFIRMED |

**New measurement this dispatch made, which the research report did not have**: the cost lever was
isolated exactly. `script-inventory.sh --root . --size-line` costs **2.37s** against the repo root
and **2.22s** against a non-git `rsync` copy of `agent-system/extensions/`, out of **4.07s** total
for `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 1`. So the corpus
probe is ~58% of a minimal gate-narrowed invocation, and — importantly — it fires in *both*
fixture shapes the expensive suites build (the `git worktree` fixture and the non-git `rsync`
fixture), because `script-inventory.sh` falls back to a filesystem walk when `git ls-files` finds
nothing. This refines the research report's blanket "~4.6s fixed corpus-scan overhead" (the whole
invocation is 4.07s today, of which the probe is 2.2-2.4s) and turns the savings estimate into
arithmetic.

### Research Integration

The research report's five recommendations map onto this plan one-for-one: do not delete any
Category-A suite (Phase 5 records that verdict instead of acting on it); price the OPTIMIZE pass
for the two suites whose cost is per-invocation overhead × invocation count (Phases 3-4);
re-measure both stale probe artifacts before pricing anything against them (Phase 4); build the
`/tmp` reaper as a `claude-refresh.sh` pass carrying *both* leak mechanisms together (Phases 1-2);
and do not build a suite-level demotion tier (Phase 5 records the non-recommendation so it is not
re-proposed).

One research recommendation is deliberately **redirected, not dropped**: the Context Extension
Recommendation named `agent-system/extensions/core/context/standards/shell-script-testing.md` as
the home for the suite-population-counting methodology. That exact file is in concurrent sibling
task 604's declared `file_scope` this same cycle, and it additionally carries an
`index-entries.json` `line_count` entry (1373) that an edit would make stale. Phase 5 therefore
puts the methodology in a `specs/decisions/` verdict record with a pointer comment in
`tests/run-all.sh`'s own header — the file that documents the discovery algorithm the four
countings differ over — keeping this plan's territory disjoint from both siblings and from every
coupled generated surface.

### Prior Plan Reference

No prior plan. This is the first plan for this record.

### Roadmap Alignment

`roadmap_flag` was not set on this dispatch, so no roadmap phases are added and `specs/ROADMAP.md`
is not edited (it is generated from `state.json`'s `roadmap_batches`/`roadmap_notes` — Standing
rule 3). Read-only alignment: this record *is* the standing consumer Settled decision 16 asks for,
and decision 16's own note that the predecessor probe (`script-inventory.sh`) has had no standing
consumer since its work landed is directly relevant — Phase 4 regenerates the artifacts both
probes feed, and Phase 5 records the verdict so the decision's "one standing task, not a stream
of point defects" shape is honored. Settled decision 13 (`known-failures.txt` advisory only) and
decision 15 (gate 8's reduced deployed-tree coverage under `--skip-slow`) are both load-bearing
for Phase 5's demotion-tier record. Decision 17 governs the sibling-overlap handling below.

### Territory

Declared `file_scope` of this plan versus the two concurrent siblings:

- Sibling **604**: `scripts/gate-registry.data`, `docs/reference/utility-scripts-inventory.md`,
  `context/standards/shell-script-testing.md` — **disjoint** from every path below.
- Sibling **624**: `scripts/system-defect-record.sh`,
  `scripts/tests/test-orchestrate-cycle-postflight.sh` — **disjoint** from every path below.

One content-level (not file-level) interaction remains and is handled in Phase 4: regenerating
`suite-cost-hints.txt` rewrites all 156 rows, including rows naming suites the siblings own. That
is a whole-file regeneration of a generated artifact, not a hand edit of a sibling's file, so no
edge is owed under decision 17 — but Phase 4 re-reads the file immediately before committing and
stages it explicitly, per the dispatch's concurrency note.

## Goals & Non-Goals

**Goals**:
- Eliminate the measured fixed per-invocation corpus-probe cost from every gate-narrowed
  `verify-deploy.sh` invocation, which is where the two most expensive suites spend it 26-29 times
  each.
- Stop the leaked-fixture class at its reaper, carrying both leak mechanisms (SIGKILL skipping the
  `EXIT` trap; non-writable content defeating `rm -rf`) in one pass, and clear the 1.4 GB backlog.
- Refresh both stale probe artifacts so the figures that drive `--max-cost` cost classes and
  `run-all.sh`'s longest-first scheduling describe the post-optimization system.
- Record the 0-DELETE/14-KEEP verdict, the suite-population counting methodology, and the
  demotion-tier non-recommendation durably enough that none is re-litigated by a future grep.

**Non-Goals**:
- Deleting, demoting, or consolidating any suite. The owner's own discrimination rule, applied to
  the corrected 14-member set, yields zero DELETE verdicts; re-opening that is out of scope.
- Building a suite-level demotion tier. No existing mechanism supports one and the audit shows the
  real lever is per-invocation overhead.
- Re-litigating Category B (9 narrow unit/lint suites) or Category C (the false positives), or
  optimizing the non-recursive expensive suites (`test-orchestrate-cycle-plan.sh`,
  `test-git-commit-scoped.sh`, `test-claude-refresh-matcher.sh`'s own 38.1s) — each is outside this
  record's recursion mandate.
- Re-measuring Settled decision 15's "52 of 91" deployed-tree coverage ratio — a different axis,
  requiring a non-`--skip-slow` fresh redeploy.
- Editing `specs/ROADMAP.md`, `context/standards/shell-script-testing.md`, `gate-registry.data`,
  or any deployed `.claude/**` path by hand.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `measure-gate-costs.sh`'s load guard refuses (exit 2) because a sibling implement dispatch is building concurrently | H | H | Phase 4 checks 1-minute load *before* invoking and defers rather than forcing: the script's own `mgc_write_with_overwrite_guard` already refuses to overwrite an `ALL_VALID=true` artifact with a contaminated run, so the fail-safe exists — use it, record a `[PARTIAL]` phase, and re-run when the batch is quiet. Never raise `--load-threshold` to get a number. |
| Realized savings fall short of the ~2.3s × invocation-count estimate because some invocations are unfiltered (`--skip-slow` only, no `--only-gate`) and keep the probe | M | M | Phase 4 measures per-suite before/after directly instead of asserting the estimate; if short, the named follow-up is widening the guard to `--skip-slow`-only invocations, recorded in Phase 5 rather than attempted mid-phase. |
| Suppressing an output line breaks an assertion in a suite that greps `verify-deploy.sh` output | H | L | A repo-wide grep for `[verify-deploy] corpus` / `--size-line` found no consumer outside `verify-deploy.sh` and `script-inventory.sh`'s own suite. The guard is additive-only and leaves the *unfiltered* path byte-identical, so only gate-narrowed invocations change. Phase 3's full gate run is the backstop. |
| The reaper deletes a `/tmp/tmp.*` directory belonging to a live process (a sibling's in-flight fixture) | H | M | Three independent gates, all required: invoking-UID ownership, no live process reference via `/proc/*/cwd` + `/proc/*/fd` (never a process-name match), and an age threshold. Report-only by default; deletion only under `--force`, matching every existing pass's three-mode contract. |
| `test-gate-cache-equivalence.sh`'s 543s figure has drifted enough that the optimization is mispriced | M | M | Phase 4 re-times the suite directly as a backgrounded, bounded-waiter step; no phase prices work against the 2026-10-16 figure. |
| Regenerating `suite-cost-hints.txt` races a sibling adding or renaming a suite | M | L | Re-read immediately before committing, stage only that file explicitly, and confirm `git status --short` shows no foreign modification to it (dispatch concurrency note steps 1-2, 5). |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Leaked-Fixture Reaper Pass in claude-refresh.sh [COMPLETED]

**Goal**: `claude-refresh.sh` gains an independently-gated pass that finds and (under `--force`)
removes leaked `/tmp/tmp.*` test fixtures, carrying both leak mechanisms in one pass, with test
coverage.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/claude-refresh.sh` and study the three
      existing passes' shared shape: independently-gated predicates, one frozen snapshot per pass,
      and the documented three-mode contract (no-flag = report, `--dry-run` = identical output plus
      a banner, `--force` = act). The new pass must match that shape rather than invent one.
      *(completed: new pass follows run_claude_pass()/run_lean_pass()'s FORCE-gated contract,
      documented as deliberately distinct from run_build_waiter_pass()'s age-threshold-only one)*
- [x] Add a leaked-fixture pass with all three candidacy gates required, not merely preferred:
      (a) ownership by the invoking UID; (b) no live process reference — resolved through
      `/proc/*/cwd` and `/proc/*/fd`, never a process-name or command-line match; (c) an age
      threshold with a named default (the observed leak spans 2026-11-10 to today, so a
      conservative default such as 1 day leaves today's live fixtures alone). *(completed:
      run_tmp_fixture_pass()/take_tmp_fixture_live_refs(), TMP_FIXTURE_REAP_MIN default 1440 min)*
- [x] Carry **both** leak mechanisms in the removal step: `chmod -R u+w` the candidate before
      `rm -rf`, because 165 of 1,739 live entries contain non-writable paths a plain `rm -rf`
      cannot remove. A reaper built against the `EXIT`-trap mechanism alone would silently fail on
      exactly the entries most worth reclaiming. *(completed)*
- [x] Document, in the pass's own header comment, *why* the fixtures leak at all:
      `tests/run-all.sh` dispatches each suite under `timeout -k 5 "$RUN_ALL_SUITE_TIMEOUT_S"`
      (lines 702 and 894), and a `SIGKILL` from `-k` skips the suite's own `EXIT` trap. This is
      the pass's reason to exist and must not be rediscovered later. *(completed)*
- [x] Wire the pass into the usage text and the `--dry-run`/`--force` dispatch alongside the
      existing passes, preserving the documented no-flag/`--dry-run` output equivalence.
      *(completed: main()'s six-pass sequence, print_help(), and the --lean-tree/-snooze
      five-pass->six-pass comment corrections)*
- [x] Add cases to `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh`
      asserting, against a synthetic fixture: an owned, old, unreferenced directory is a
      candidate; a directory with non-writable content is still removed under `--force`; a
      directory referenced by a live process is NOT a candidate; a directory younger than the
      threshold is NOT a candidate; and the no-flag/`--dry-run` paths remove nothing. *(completed:
      assertion (l), 9 new cases including a bonus /proc/*/fd case beyond the required cwd case,
      plus the mutation-check function-name list/count extension)*
- [x] Run `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` over both edited
      files (gate 22 runs in full even under `--skip-slow`, so a shellcheck finding here would
      surface later at the worst time). *(completed: 0 findings after fixing two SC2178/SC2128
      same-name-across-functions false positives and two SC2034 false positives on the test
      file's final TMP_FIXTURE_REAP_MIN/PROC_ROOT assignments)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's two files returns exactly
`test-claude-refresh-matcher.sh` and `test-lake-build-guard.sh`, so
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-claude-refresh-matcher.sh,test-lake-build-guard.sh`
covers the edit.

**Scope Hypothesis**: 165 of 1,739 live `/tmp/tmp.*` entries carry non-writable content (measured
live 2026-11-17), which is what makes the `chmod -R u+w` step load-bearing rather than
precautionary. Confirm by re-running the same bounded scan at implementation time before sizing
the pass; if the count has collapsed to zero, keep the step anyway but say so in the commit
message rather than silently dropping it.

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` - new independently-gated
  leaked-fixture pass, usage text, dispatch wiring
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` - fixture-driven
  cases for the new pass's candidacy gates and three-mode contract

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-claude-refresh-matcher.sh,test-lake-build-guard.sh`
  reports 0 failures.
- `bash agent-system/extensions/core/scripts/claude-refresh.sh --dry-run` lists leaked-fixture
  candidates, deletes nothing (`find /tmp -maxdepth 1 -name 'tmp.*' | wc -l` unchanged across the
  invocation), and prints the `--dry-run` banner.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` reports no finding on either
  edited file.

---

### Phase 2: Clear the Leaked-Fixture Backlog [COMPLETED]

**Goal**: The 1.4 GB leaked-fixture backlog is reclaimed by the Phase 1 pass itself — which is
also the pass's only live validation — and the before/after figures are recorded.

**Tasks**:
- [x] Re-derive both figures immediately before acting, since the count grows continuously:
      `find /tmp -maxdepth 1 -name 'tmp.*' | wc -l` and
      `find /tmp -maxdepth 1 -name 'tmp.*' -print0 | du -sch --files0-from=- | tail -1`.
      Record both. *(completed: 1,733 entries / 1.4G, re-derived live 2026-11-17 -- differs
      slightly from this plan's carried 1,739-entry figure, as expected for a continuously
      growing count)*
- [x] Confirm no sibling dispatch is mid-run with a live fixture: run
      `bash agent-system/extensions/core/scripts/claude-refresh.sh --dry-run` first and read the
      candidate list for anything dated today, then check `git status --short` for foreign
      in-flight modifications per the dispatch's concurrency note. *(completed: all dry-run
      candidate ages were >=1d, i.e. none dated today; `git status --short` showed only foreign,
      disjoint-file_scope modifications from concurrent siblings 604/624/547)*
- [x] Run the reaper under `--force` and capture its own report of what it removed. *(completed:
      "Removed: 1493 fixture(s), Failed: 0 fixture(s)". Deviation note: invoking the whole script
      under --force also arms run_claude_pass()/run_lean_pass() in the same invocation -- both
      reported zero actions this run, recorded as a near-miss via issue-record.sh for future
      invocations to use a direct function call instead)*
- [x] Re-derive the same two figures afterwards and record the delta. A residual count is expected
      and correct (today's fixtures are below the age threshold) — do not chase it to zero by
      lowering the threshold. *(completed: after = 240 entries / 549M. Delta: -1,493 entries,
      -~851MB reclaimed)*
- [x] If any candidate survived removal, treat it as a third leak mechanism the pass does not yet
      carry: record it via `issue-record.sh` with the exact path and `ls -la` output rather than
      hand-deleting it, so Phase 5 can name it. *(completed: not applicable -- all 240 survivors
      are dated 2026-11-16/2026-11-17, fully explained by the existing age-threshold gate; no new
      leak mechanism was found, so no issue-record.sh call was needed for this item)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: This phase modifies no repository file at all — it only invokes the
already-verified Phase 1 pass against `/tmp` — so the `prose` row's diff read-through applies
vacuously and the covering check is the pass's own before/after counts recorded below.

**Scope Hypothesis**: 1,739 entries totalling 1.4 GB as of 2026-11-17, accumulating at 107-475
entries/day. Both numbers will have moved by implementation time; the two `find` commands above
are the confirmation, and the recorded delta must be the re-derived pair, never this plan's
figures.

**Files to modify**:
- (none — this phase mutates only `/tmp`, outside the repository)

**Verification**:
- The post-sweep `find /tmp -maxdepth 1 -name 'tmp.*' | wc -l` is materially below the pre-sweep
  count, and the `du` total is materially below 1.4 GB.
- Every surviving entry is explainable by a declared candidacy gate (too young, live-referenced,
  or not owned) — checked by reading the `--dry-run` report against the survivors, not assumed.
- No path outside `/tmp` was touched: `git status --short` shows no new or modified file from this
  phase.

---

### Phase 3: Suppress the Fixed Corpus Probe on Gate-Narrowed Invocations [COMPLETED]

**Goal**: `verify-deploy.sh` stops paying the 2.2-2.4s corpus-scan cost on every gate-narrowed
invocation, with an explicit opt-in to force it, and the behavior is pinned by assertions.

**Tasks**:
- [x] Re-read the standing corpus-size probe block at the end of
      `agent-system/extensions/core/scripts/verify-deploy.sh` (the `_VD_SCRIPT_INVENTORY` /
      `_VD_CORPUS_LINE` block immediately before the PASS/FAIL summary) and its existing guard,
      `[ -d "$TARGET/agent-system/extensions" ] && [ -f "$_VD_SCRIPT_INVENTORY" ]`. *(completed)*
- [x] Add a `--corpus-probe` opt-in flag to the argument parser (confirm first that the name
      collides with no existing flag), defaulting to off, declared with the other flag defaults
      *before* the parse loop — the file's own comment at the `GATE8_TOUCHED` declaration explains
      why a later declaration silently clobbers a parsed value. *(completed: confirmed no
      pre-existing collision via grep before adding; CORPUS_PROBE=false declared alongside
      GATE8_TOUCHED before the while-loop)*
- [x] Extend the probe guard so the inventory subprocess runs only when the invocation is **not**
      gate-narrowed (`GATES_FILTER` empty — which also covers `--max-cost`, since that resolves
      into the same variable) **or** `--corpus-probe` was passed. Keep the change additive-only:
      with no filter and no new flag, the emitted line and the whole code path must be
      byte-identical to today, because the standing full-run record is the probe's actual purpose.
      *(completed: `[ -z "$GATES_FILTER" ] || $CORPUS_PROBE`)*
- [x] Deliberately leave `--quiet` behavior untouched. The probe uses a raw `echo`, exactly as the
      PASS/FAIL summary lines do, so surviving `--quiet` is the existing intent; narrowing the
      change to the filter condition alone is what keeps the unfiltered path identical.
      *(completed: --quiet was not touched)*
- [x] Document the new flag and the suppression rule in `verify-deploy.sh`'s own header flag list,
      stating plainly that a gate-narrowed run is not the standing full verification the probe
      exists to record. *(completed: new "Standing corpus-size probe suppression" header
      subsection, inserted after the "Gate 8 touched-paths narrowing" section)*
- [x] Add cases to
      `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` against
      its existing `FIXTURE_RICH` (a real `rsync` copy of `agent-system/extensions/`, so the probe
      genuinely fires there): `--skip-slow --only-gate 1` emits no `[verify-deploy] corpus:` line,
      and `--skip-slow --only-gate 1 --corpus-probe` does. Honor that suite's stated
      anti-recursion invariant — every invocation keeps `--skip-slow`, and no case may drop the
      gate filter against `FIXTURE_RICH`. *(completed: case (t), both sub-cases pass. The
      complementary "unfiltered still fires" bullet was verified manually instead of as a third
      automated case -- see this phase's progress file `approaches_tried` for why: it would have
      required a full, unfiltered battery against FIXTURE_RICH, measured at ~22s, roughly
      doubling this suite's own cost for one assertion)*
- [x] Record the per-invocation saving measured in the fixture itself (time one `--only-gate 1`
      invocation against `FIXTURE_RICH` before and after), so Phase 4 inherits a measured
      per-invocation figure rather than this plan's repo-root numbers. *(completed: 3.805s with
      --corpus-probe (emulating the old always-on behavior) vs 1.400s without it (new default) --
      a ~2.405s saving per invocation, matching the plan's ~2.3s estimate)*
- [x] Run `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` over both edited
      files. *(completed: 0 findings)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Tier Justification**: `verify-deploy.sh` is the shared gate aggregator whose CLI surface and
output every gate-8-adjacent suite exercises — `suite_selection_select` over this phase's two
files returns 33 suites, including the entire Category-A recursive-meta-suite set, so no cheaper
subset meaningfully narrows the blast radius; the full gate run doubles as this phase's own
post-change gate-8 timing datum.

**Scope Hypothesis**: `test-gate-cache-equivalence.sh` has 29 static `run_vd` call sites and the
crash-net suite loops over ~26 registered gate ids, so the realized saving is roughly
2.3s × invocation count — but several call sites sit inside loops, making the true invocation
count higher than the static grep. Confirm by counting actual invocations (a counter incremented
in the fixture's own wrapper, or `set -x` line counting), not by trusting the static figure.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - `--corpus-probe` flag, the extended
  probe guard, header flag documentation
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` - suppressed
  and forced cases against `FIXTURE_RICH`

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set for the repository — is green
  (run after the Phase 5 redeploy if the deployed copy is what gate 8 dispatches; otherwise invoke
  the source-store copy against the repository root, which is simultaneously source store and
  deploy consumer).
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 1 .` emits no
  `[verify-deploy] corpus:` line and is measurably faster than the 4.07s baseline recorded above.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 1 --corpus-probe .`
  emits the corpus line.
- An unfiltered invocation still emits the corpus line (the standing record is preserved).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-gate-selection.sh`
  reports 0 failures.

---

### Phase 4: Re-Measure Both Probe Artifacts Against the Optimized System [NOT STARTED]

**Goal**: `gate-cost-model.csv` and `suite-cost-hints.txt` carry fresh, idle-validated figures
describing the post-optimization system, and the realized saving on the two expensive suites is
measured rather than estimated.

**Tasks**:
- [ ] Check the host is idle enough *before* invoking anything: read the 1-minute load average and
      compare it against `measure-gate-costs.sh`'s threshold. If it is over, stop and mark this
      phase `[PARTIAL]` with the observed load — do not raise `--load-threshold`, and do not let a
      contaminated sample overwrite an `ALL_VALID=true` artifact.
- [ ] Re-time the two expensive suites directly, as backgrounded steps with a bounded waiter (a
      hard timeout plus writer liveness via `kill -0` on the captured PID, per
      `context/patterns/bounded-build-waiter.md`), never a foreground run: the cache-equivalence
      suite exceeds what a foreground call will block on. Record the post-change wall time for
      `test-gate-cache-equivalence.sh` and `test-verify-deploy-gate-selection-crash-net.sh`
      against their 543.0s / 148.6s hint rows.
- [ ] Regenerate the suite-level hints:
      `bash agent-system/extensions/core/scripts/measure-gate-costs.sh --regen-hints
      --skip-gate-measure`, reading the written file's own `ALL_VALID` header to decide whether
      the sample is trustworthy — never stderr alone, per that script's own header.
- [ ] Regenerate the gate cost model with
      `bash agent-system/extensions/core/scripts/measure-gate-costs.sh`, and note in the commit
      message whether the result still covers only `gate8` or now carries rows for the other
      registered gates. The current single-row file is a 1-of-~26 model dated 2026-10-19; if the
      regeneration still produces one row, say so explicitly rather than leaving the reader to
      infer the model's real coverage.
- [ ] Re-read both artifacts immediately before staging, confirm `git status --short` shows no
      foreign modification to either, and stage them by explicit path only (never a directory or
      glob pathspec).
- [ ] Record the realized total saving: the regenerated hints file's new sum against the
      1,406,493 ms baseline, plus the two per-suite deltas.

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for both regenerated
artifacts — no suite maps either, which is expected for a mechanically generated data file — so
the covering check is each artifact's own `# ALL_VALID=true` header plus a diff read-through
confirming only values moved and no schema column changed.

**Scope Hypothesis**: the 543,000 ms hint row (2026-10-16) and `gate8=662,462 ms` (2026-10-19) are
both stale, and the saving projected in Phase 3 is ~2.3s × invocation count. Every figure this
phase reports must come from the regenerated artifacts' own validity-marked output or from the
bounded re-timing, never from this plan's estimates; a projection that the measurement contradicts
is recorded as a correction, not reconciled toward the projection.

**Files to modify**:
- `agent-system/extensions/core/scripts/gate-cost-model.csv` - regenerated per-gate cost model
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - regenerated suite-level
  scheduling hints

**Verification**:
- Both regenerated files carry a `# Generated:` header dated this phase's run and
  `ALL_VALID=true`; a `false` is treated as a refusal to accept the sample, not a caveat to note.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-measure-gate-costs.sh,test-script-inventory.sh,test-run-all-selection.sh`
  reports 0 failures (the three suites that read these artifacts' format).
- `bash agent-system/extensions/core/scripts/script-inventory.sh --root . --size-line` still
  reports a numeric `cost_per_assertion_ms` (not `n/a`), proving the regenerated hints file is
  still parseable by its consumer.
- The recorded post-change wall time for each of the two expensive suites, and the hints-file
  total against 1,406,493 ms, are both written into the phase's commit message.

---

### Phase 5: Record the Verdict, the Counting Methodology, and the Non-Recommendations [NOT STARTED]

**Goal**: The audit's durable output exists as a decision record — the 0-DELETE/14-KEEP verdict
with the owner's rule applied, the four-way suite-population counting methodology, and the
demotion-tier non-recommendation — and the whole task is verified green against a freshly deployed
tree.

**Tasks**:
- [ ] Confirm the correction target before writing to it: `specs/decisions/` exists and already
      holds four verdict records (the directory ROADMAP Settled decision 14 cites for
      `worktree-isolation-removal-verdict.md`). Write the new record there as a sibling. If the
      directory is somehow absent at implementation time, create it rather than relocating the
      record, and say so in the commit message.
- [ ] Write `specs/decisions/suite-cost-delete-keep-verdict.md` carrying, on its own merits:
      (a) the owner's DELETE/KEEP discrimination rule as the governing test; (b) the 14-member
      Category-A roster with the unreachable-by-real-tree property that earns each a KEEP, and the
      explicit **0 DELETE** count; (c) why the naive
      `grep -lE "(run-all\.sh|verify-deploy\.sh)"` over-counts by ~2.6x (stub-only files written
      for call counting, and planted fixture content a classification lint asserts against), so
      the next reader does not re-derive the wrong 35-ish figure; (d) the four legitimate
      suite-population countings — core source-store `test-*.sh` (157), all-loaded-extensions
      source-store (197), this repo's deployed `.claude/scripts/tests/` (179), and
      `script-inventory.sh --size-line`'s `test_suites` (204) — each with the command that
      produces it and the instruction that a bare suite count is never a safe citation; (e) the
      demotion-tier finding: `known-failures.txt` is advisory by design (decision 13),
      `--skip-slow` and `--max-cost` are both gate-granular, gate 8 is monolithic, so a
      suite-level tier is new machinery and is **not recommended**; (f) the realized savings from
      Phases 3-4 and the residual leak figure from Phase 2.
- [ ] Write it as a standing record, not a narrative of this task: no task numbers, no "v2", no
      supersession framing, no phase-by-phase history. Cite durable anchors — filenames, the
      owner's rule, Settled decision numbers, and the commands that re-derive each figure.
- [ ] Add a short pointer comment to `agent-system/extensions/core/scripts/tests/run-all.sh`'s
      header — the file that documents the suite-discovery algorithm the four countings differ
      over — naming the decision record as the place the counting methodology is written down.
      Comment-only; no behavior change.
- [ ] If Phase 2 found a third leak mechanism, name it in the record as owed follow-up work rather
      than leaving it only in `issues.jsonl`.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` and confirm `RESULT=landed_verify_clean`, so
      gate 8 dispatches the deployed copies of the Phase 1 and Phase 3 edits rather than stale
      ones.
- [ ] Confirm `git status --short` shows no hand-authored file under `.claude/**` — every landed
      path there must be a deploy product.

**Timing**: 1.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: this phase writes down six figures it does not itself produce — the
14-member Category-A roster and 0-DELETE count (from research), the four suite-population
countings (157 / 197 / 179 / 204, measured 2026-11-17), and the realized savings and residual
leak count (from Phases 2-4). Every one is re-derived with the command the record itself names
immediately before the record is written; a figure that has moved is written at its new value
with its own re-derivation date, never copied forward from this plan.

**Files to modify**:
- `specs/decisions/suite-cost-delete-keep-verdict.md` - the standing verdict, counting
  methodology, and non-recommendations record
- `agent-system/extensions/core/scripts/tests/run-all.sh` - header pointer comment to the decision
  record (comment-only)
- `__WHOLE_TREE__` - this phase runs `deploy-headless.sh`, which regenerates the entire deployed
  tree

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set for the repository — is green.
- `bash .claude/scripts/deploy-headless.sh` reports `RESULT=landed_verify_clean`.
- A diff read-through confirms every changed hunk in `run-all.sh` lies inside a comment region
  (the pointer is comment-only and must not reach executable lines).
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 — doc-lint and the task-reference lint over the markdown this phase adds, run from the
  repository root that is simultaneously deploy consumer and source store. This is a subset of the
  complete gate run above, named separately because it is the fast pre-check to run while
  authoring.
- A reader of the decision record alone can state the DELETE/KEEP rule, the 0-DELETE verdict, why
  the naive grep over-counts, which of four suite populations a given count means, and why no
  demotion tier was built — without consulting this plan or either research report.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-claude-refresh-matcher.sh,test-lake-build-guard.sh`
      reports 0 failures (Phase 1).
- [ ] The leaked-fixture pass removes nothing under the no-flag and `--dry-run` paths, and removes
      non-writable-content fixtures under `--force` (Phases 1-2).
- [ ] `verify-deploy.sh --only-gate N` emits no corpus line; `--only-gate N --corpus-probe` does;
      an unfiltered run still does (Phase 3).
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-gate-selection.sh`
      reports 0 failures (Phase 3).
- [ ] Both regenerated probe artifacts carry a fresh `# Generated:` header and `ALL_VALID=true`
      (Phase 4).
- [ ] `script-inventory.sh --size-line` still reports a numeric `cost_per_assertion_ms` against the
      regenerated hints file (Phase 4).
- [ ] `bash .claude/scripts/verify-deploy.sh` is green and `deploy-headless.sh` reports
      `RESULT=landed_verify_clean` (Phase 5).
- [ ] No hand-authored file exists under `.claude/**` at completion (Phase 5).

## Artifacts & Outputs

- A leaked-fixture reaper pass in `claude-refresh.sh`, with fixture-driven test coverage.
- A reclaimed `/tmp`, with before/after entry counts and byte totals recorded.
- A `--corpus-probe` opt-in flag and a gate-narrowed suppression guard in `verify-deploy.sh`, with
  assertions in the gate-selection suite.
- Freshly measured, validity-marked `gate-cost-model.csv` and `suite-cost-hints.txt`.
- `specs/decisions/suite-cost-delete-keep-verdict.md` — the standing verdict, the suite-population
  counting methodology, and the demotion-tier non-recommendation.
- A redeployed `.claude/` tree verified green by the complete gate set.

## Rollback/Contingency

Every code change is additive and independently revertable, and the phases are separately
committed, so rollback is per-phase rather than wholesale:

- **Phase 3** is the only change touching a shared aggregator. Reverting the guard restores the
  unconditional probe; because the unfiltered path is byte-identical by construction, a revert
  cannot change full-run behavior at all. If the saving proves illusory, revert the guard and keep
  the `--corpus-probe` flag documentation only if a test still asserts it.
- **Phase 1** is a new, independently-gated pass: reverting the `claude-refresh.sh` hunk removes
  it without touching the three existing passes, which keep their own snapshots and gates.
- **Phase 2** is not revertable (deleted fixtures are gone), which is why its candidacy gates are
  required rather than preferred and why the `--dry-run` read precedes the `--force` run. A
  wrongly reaped live fixture manifests as a failing sibling suite, recoverable by re-running that
  suite.
- **Phase 4** regenerates two generated artifacts; the prior contents are recoverable from git
  history, and the generator's own overwrite guard already refuses to replace a trustworthy sample
  with a contaminated one.
- **Phase 5** is a new file plus a comment; reverting is a file removal and a one-hunk revert.

If the host is never quiet enough for Phase 4 within this task's budget, close Phases 1-3 and 5
and leave Phase 4 `[PARTIAL]` with the observed load recorded — a contaminated cost artifact is
worse than a stale one, because `--max-cost` and `run-all.sh`'s scheduler both act on it.
