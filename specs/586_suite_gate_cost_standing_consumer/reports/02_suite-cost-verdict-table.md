# Research Report: Task #586

**Task**: 586 - Suite/gate wall-clock cost standing consumer
**Started**: 2026-11-17T00:00:00Z
**Completed**: 2026-11-17T00:00:00Z
**Effort**: large (deep forensic suite-by-suite audit)
**Dependencies**: None blocking this phase; owner ruling already on record in the task description
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/tests/*.sh` (157 files), `run-all.sh`,
  `verify-deploy.sh`, `gate-cost-model.csv`, `suite-cost-hints.txt`, `specs/ROADMAP.md`
- Live measurement: direct `bash`/`time` invocations against the real repo and against the
  deployed `.claude/` tree
- git history (`git log -S`, `git log --diff-filter`) for figure-origin dating
**Artifacts**: - this report (`specs/586_suite_gate_cost_standing_consumer/reports/02_suite-cost-verdict-table.md`)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Every carried figure in the seed report's blanket "MEASURED 2026-11-10" framing has a
  different, individually-stale origin, and several are substantially out of date — see
  Carried-Figure Re-Derivation below for the full reconciliation.
- The lexical test for "recursive meta-suite" (`grep -l run-all.sh\|verify-deploy.sh`) over-counts
  by roughly 2.6x: of 36 matching files, only **14** genuinely re-invoke the orchestration layer
  in the way the owner's ruling addresses; 9 are narrow unit/lint suites that merely use
  `verify-deploy.sh`/`run-all.sh` as a plumbing detail; 13 are comment-only or planted-fixture-
  content false positives that never execute the real script they mention.
- Applying the owner's own DELETE/KEEP rule to the correct 14-member set yields **zero DELETE
  verdicts**. Every one of the 14 tests a cross-invocation, concurrency, equivalence, or
  crash-safety property that a single real-tree gate run structurally cannot self-certify (a real
  run only ever exercises one invocation shape at a time). This is a load-bearing correction to
  the premise, not a failure to find anything: it stops the plan/implementation phase from
  deleting suites that *look* redundant under a naive grep but are not redundant under the
  owner's own stated rule.
- The single most important premise correction: the suites actually responsible for the biggest
  wall-clock costs (`test-gate-cache-equivalence.sh`, `test-verify-deploy-gate-selection-crash-
  net.sh`, `test-verify-deploy-gate-selection.sh`, `test-verify-deploy-context-budget.sh`) have
  **already engineered around** the "pays gate 8's full battery cost" problem the seed report
  worried about — each explicitly stubs gate 8's `run-all.sh` or passes `--skip-slow` to avoid
  recursing into it, with inline comments documenting that avoidance as a deliberate, already-
  landed fix. Their real cost driver, confirmed by live measurement, is **fixed per-invocation
  `verify-deploy.sh` overhead (~4.6s for the corpus scan alone) multiplied by invocation count
  within one suite** (28 invocations in the cache-equivalence suite, ~26 in the crash-net suite)
  — an OPTIMIZE target, not a DELETE target.
- No suite-level demotion tier exists today, confirming the seed's suspicion. `known-failures.txt`
  is advisory only (Settled decision 13) and `--skip-slow`/`--max-cost` both operate at *gate*
  granularity (gate 8 is monolithic, all-189-suites-or-none) — neither can demote one expensive
  suite inside gate 8 while keeping the rest running. Building that would be new machinery.
- The `/tmp/tmp.*` fixture leak is still live and reproducible today: 1,716 entries, 1.4 GB,
  oldest dated 2026-11-10 (the date of the one prior manual sweep), and read-only
  (`chmod a-w`'d) undeletable content was reconfirmed in a live sample.

## Context & Scope

This is the second research pass on task 586 (a standing-consumer record for the suite/gate
wall-clock cost probes). A seed report (`01_suite-gate-cost-audit.md`) already framed the
problem and posed five explicit open questions; this report answers them directly, re-deriving
every carried figure first per Settled decision 5 ("verify by execution, not by reading") and
Standing rule 9 (dispatch premises go stale between creation and dispatch).

Scope is bounded to: re-deriving the seed's numeric claims, producing the DELETE/KEEP verdict
table over the recursive meta-suite class, giving a disposition for each top-10 wall-clock
suite, answering the demotion-tier question, and recommending where the fixture-leak fix should
live. Making any suite change, writing a reaper, or editing `run-all.sh`/`verify-deploy.sh` is
explicitly plan/implementation-phase work and is not done here.

## Findings

### Carried-Figure Re-Derivation

The description's three flagged lines were checked individually against live state:

1. **"149 suites, 23.5 min total... 543s... gate8 at 662,462ms... 35 of 149... 1,780 leaked
   fixtures totalling 1.1GB"** — **partially stale, multi-valued, and individually mis-dated**:
   - **Suite count is not one number.** `agent-system/extensions/core/scripts/tests/test-*.sh`
     alone is **157** files today (git history shows +10/-1 net since 2026-11-10). The full
     source-store population `run-all.sh` actually discovers (every loaded extension's
     `scripts/tests/test-*.sh` + flat `scripts/test-*.sh`, per that script's own documented
     discovery algorithm) is **197**. This repository's currently *deployed* `.claude/`
     tree — the actual population Gate 8 dispatches against here — is **189**
     (`.claude/scripts/tests/` 179 + flat 10). `verify-deploy.sh`'s own live corpus-scan line
     reports `test_suites=204` (a yet further different count, presumably a different
     classification boundary). None of these is "149." The next consumer of this figure must
     state which of these four populations it means and re-derive at dispatch time; "149 suites"
     as a bare number is no longer a safe citation.
   - **`gate-cost-model.csv`'s `gate8=662462ms` line is dated 2026-10-19** inside the file's own
     `# Generated:` header — not 2026-11-10. The file's single data row has not changed since.
     `ALL_VALID=true` at generation time, so the figure was trustworthy *when measured*, but it
     is nearly a month old and the suite battery has grown by ~9% (157→... wait, by the core
     count) since then; it should be re-measured before being used for a cost-class decision.
   - **The `test-gate-cache-equivalence.sh` 543,000ms hint-file row is dated 2026-10-16**
     (`git log -S'test-gate-cache-equivalence.sh,543000'` finds exactly one commit, task 416
     phase 9, and the line has never changed since). This is the single most important number in
     the whole record — it drives the top-of-list ranking and the owner's specific optimization
     question — and it is over a month stale.
   - A live re-timing of `test-gate-cache-equivalence.sh` was attempted and deliberately
     **stopped, not completed**: the Bash tool auto-backgrounded the run after 180s (the suite's
     own ~543s runtime exceeds what a single foreground command in this environment will block
     on), and this dispatch's local-wait discipline prohibits tracking an unresolved local
     background wait for a test run. The partial output captured before the stop showed the
     suite still correctly progressing through its gate checks (18-23) and into its mechanical
     cross-section loop — consistent with, but not confirming, the 543s figure. **The figure
     remains CARRIED-UNVERIFIED-BUT-PLAUSIBLE; live re-measurement is recommended before the
     plan phase prices any optimization against it.**
   - **The hint-file *total* (1,406,493ms = 23.44 min) does currently match the claimed 23.5
     min**, because the hint file (last touched 2026-11-16) still has the same top-10 rows as
     the seed report cites, verbatim. This part of the premise holds today, coincidentally (the
     suites that grew since 2026-11-10 are mostly cheap ones not yet added to the advisory hint
     file at all — see the recursive-count correction below).
   - **The `/tmp/tmp.*` leak is reconfirmed, and has grown, not shrunk**: live count is 1,716
     entries totalling 1.4GB (vs. the claimed 1,780/1.1GB) — fewer entries but *more* total
     bytes, consistent with ongoing accumulation of larger fixtures since the one historical
     manual sweep. The oldest live entry is dated 2026-11-10 (exactly the date of that sweep) and
     the newest is dated today, confirming continuous, unaddressed leakage for the full 7-day
     window. A live sample of 400 entries reconfirmed **mechanism 2 exactly**: at least 5 entries
     still carry `chmod a-w`'d nested content that a plain `rm -rf` cannot remove without
     `chmod -R u+w` first.
   - **The "35 of 149 suites re-invoke the full battery" claim is corrected below** — the real
     number, after removing false positives, is 14, not 35, and none of the 14 actually pays
     gate 8's full cost anymore (see "Recursive Meta-Suite Reclassification").

2. **The owner ruling (DELETE/KEEP discrimination rule)** — unchanged; this is a standing
   instruction, not a measurement, and nothing in this pass contradicts or supersedes it. It is
   applied verbatim below.

3. **"SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/**`"** — confirmed current:
   `.claude-extensions.json`'s `core.source_dir` resolves to
   `agent-system/extensions/core`, and all scripts audited in this report were read from that
   source-store path, not from any deployed `.claude/` tree.

### Recursive Meta-Suite Reclassification

The seed report's "35 of 149" figure comes from `grep -lE "(run-all\.sh|verify-deploy\.sh)"` over
the suite corpus. Re-running that grep today returns **36** matches (not 35 — consistent with the
corpus having grown). Reading each of the 36 for what it actually *does*, not just what it
*mentions*, splits them into three categories:

**Category A — genuine recursive meta-suites (14)**, the actual target of the owner's ruling:
suites whose entire purpose is to exercise the orchestration/dispatch layer itself (cache
equivalence, gate selection, lock serialization, parallel-pool behavior, crash-safety across
every registered gate id, shared-fixture reuse) by really invoking `verify-deploy.sh` and/or
`run-all.sh` as subjects under test, more than once, inside a scratch fixture.

**Category B — narrow unit/lint suites (9)** that genuinely invoke the real script but only as
plumbing for a much narrower, already-scoped property (one library function, one lint, one
gate's internal sub-check): `test-deploy-baseline-lib.sh`, `test-deploy-orphans.sh`,
`test-gate3-strict-equivalence.sh`, `test-gate-out-self-attribution.sh`,
`test-gate-registry-resolution.sh`, `test-lint-hook-registration-paths.sh`,
`test-validate-artifact.sh`, plus `test-deploy-verify-wiring.sh` (Category A by subject matter —
it tests the deploy-headless↔verify-deploy *wiring contract* — but explicitly engineered to
*never* reach gate 8, so it carries none of the cost risk; grouped with A below since it is
in-scope for the ruling, just cheap). That is 7 pure-Category-B plus 1 cheap-but-in-scope wiring
suite; see the verdict table for the exact membership.

**Category C — false positives (13 or 15 depending on count above; verified 15)**: the
script name appears only in a comment, or as *planted fixture content* a lint is asserting
against (never executed for real). Confirmed by direct inspection, not just counting:
`test-orchestrate-cycle-plan.sh` only ever *writes an empty stub file* named `verify-deploy.sh`
for call-counting, never runs the real one; `test-orchestrate-build-dispatch.sh` does the same
(`: > "$FIXTURE/.claude/scripts/verify-deploy.sh"`); `test-lint-unit-integration-boundary.sh`
writes the literal string `bash ./run-all.sh` into a synthetic fixture file to prove a
*classification lint* detects a suite that references it — it never executes anything.
Also: `test-check-task-references.sh`, `test-claude-refresh-matcher.sh`, `test-common-lib.sh`,
`test-deploy-verify-overlap.sh`, `test-double-loading-check.sh`, `test-gate3-parallel-
equivalence.sh`, `test-gate-cache-lib.sh`, `test-lint-branch-gated-sections.sh`, `test-lint-
json-channel-discipline.sh`, `test-lint-shellcheck-parallel.sh`, `test-lint-task-lookup-
adoption.sh`, `test-lint-verdict-extraction-anchoring.sh`.

14 + 9 + 13 = 36. (The wiring suite is counted once, under A, in the table below; so the table
below shows 14 rows, Category B independently totals 9 including it would double count — see
table note.)

### DELETE/KEEP Verdict Table (Category A — the owner's actual target)

Per the owner's rule: **DELETE** when a `verify-deploy.sh` gate already asserts the same
property against the real tree; **KEEP** when the fixture reaches a state the real tree cannot be
put into.

| Suite | Wall (live hint / measured) | Verdict | Unreachable-by-real-tree property (why KEEP) |
|---|---|---|---|
| `test-gate-cache-equivalence.sh` | 543.0s (CARRIED-UNVERIFIED, Oct 16) | **KEEP, OPTIMIZE** | Cached-vs-uncached output *equivalence*. A real run only ever takes one path (cached or not); it never proves the two agree. **Correction**: this suite already stubs gate 8's `run-all.sh` with a near-instant fake (explicit in its own header: "swaps the EXPENSIVE PAYLOAD... without paying run-all.sh's real ~457s cost") and already excludes gate 22 (shellcheck) from its repeated mechanical loops for the same reason. It is not doing "two full battery passes"; its cost is **28 separate `verify-deploy.sh` subprocess invocations**, each paying a measured ~4.6s fixed corpus-scan overhead (270 scripts / 965 md files) regardless of `--only-gate` scope — ~130s of that alone, the rest from the few gates (6, 10, 22) it genuinely exercises for real. |
| `test-verify-deploy-gate-selection-crash-net.sh` | 148.6s | **KEEP** | Owner's own named KEEP category verbatim: a crash net — every registered gate id run standalone, proving none crashes. Already passes `--skip-slow` on every invocation (confirmed in source), so gate 8 never runs its real battery here either. Cost is ~26 gate-id invocations × the same ~4.6s fixed overhead, plus one `rsync -a` of the whole `agent-system/extensions/` tree. |
| `test-orchestrate-cycle-plan.sh` | 106.6s | **Not Category A — reclassify to C** | Confirmed by direct inspection: never executes a real `verify-deploy.sh`/`run-all.sh`; only writes empty stub files for call-counting. Its cost comes from its own large fixture/collaborator-copy setup, unrelated to gate-8 recursion. Left in the top-10 disposition list below, not re-litigated here. |
| `test-orchestrate-cycle-postflight.sh` | 68.1s | n/a (not in the 36) | Does not match the recursion grep at all; out of this table's scope. |
| `test-verify-deploy-gate-selection.sh` | 36.8s | **KEEP** | Tests `--only-gate`'s own flag-selection correctness (does selecting gate N run exactly N?). A real run only ever uses whatever flags were passed; it never self-verifies the selection mechanism. Explicitly passes `--skip-slow` to avoid the anti-recursion hazard (documented inline, citing `test-deploy-verify-wiring.sh`'s same invariant). |
| `test-verify-deploy-context-budget.sh` | 31.0s | **KEEP** | Gate 20's own severity-toggle and pre/post-findings-snapshot non-regression edge cases. Uses `--skip-slow` plus a real rsync'd fixture; cost is dominated by gates 3/22 which it notes explicitly still run "IN FULL" even under `--skip-slow` (shellcheck is expensive regardless of the slow-gate flag). |
| `test-gate8-expected-new-distinction.sh` | not in hint file (untimed) | **KEEP** (inferred cheap) | Gate 8's EXPECTED-vs-NEW pass/warn/fail branching — a property of `gate8_run()`'s *own* exit-code interpretation, not of the suites it runs. Structural model explicitly built on the same minimal-fixture, non-full-battery pattern as its cheap sibling below; not independently re-timed this pass. |
| `test-gate8-suite-selection.sh` | **11.3s (measured live this pass)** | **KEEP** | Gate 8's touched-paths narrowing (`--gate8-touched`), full-sweep fallback, and the forced cache-ineligibility invariant on a narrowed run — properties about *which suites get selected*, never exercised by an ordinary full or narrowed real run on its own. |
| `test-gate-lock.sh` | not in hint file (untimed) | **KEEP** | Owner's own named KEEP categories, verbatim: stale/killed-holder lock reclaim, the nested-invocation no-op path, and fail-open degradation on a stubbed `task-lock.sh`. Explicitly "never touches the real `specs/` tree." Synthetic-fixture pattern, same family as `test-run-all-parallel.sh`; not independently re-timed, but structurally guaranteed cheap (trivial fixture suites, not a real battery). |
| `test-run-all-failure-reporting.sh` | 1.1s | **KEEP** | `run-all.sh`'s own failure-naming/roster contract (a historical defect: "failing suites are never named"). Synthetic fixture, explicitly "never the real repo's N-suite battery." |
| `test-run-all-parallel.sh` | 8.7s | **KEEP** | `--jobs N` parallel-pool behavior-preservation, genuine wall-clock concurrency, and the `RUN_ALL_NESTED=1` guard — concurrency properties no single serial real run can check. |
| `test-run-all-selection.sh` | 4.3s | **KEEP** | `--only SUITE[,...]` selection plus suite-selection-lib.sh's touched-file mapping, parity-checked against every other flag combination. Flag-combinatorics, not reachable from one real invocation. |
| `test-run-all-shared-fixture.sh` | **0.28s (measured live this pass)** | **KEEP** | Pins the shared-fixture-build-once/never-when-unused contract itself (`SHARED_FIXTURE_CONSUMERS`). This is the exact mechanism the archived `328_...corpus_efficiency` record built; this suite is its regression guard, not a candidate for the same kind of consolidation. |
| `test-measure-gate-costs.sh` | 3.4s | **KEEP** | The cost-measurement harness's own load-guard and averaging behavior (deterministic via a test-only override hook) — this record's own probe is itself gated by this suite; deleting it would remove coverage of the very mechanism this standing-consumer record depends on. |
| `test-orchestrate-batch-gate.sh` | 1.1s | **KEEP** | Batch-shared-gate attribution logic (finding→task mapping, flaky-finding confirmation re-run) — an attribution property with no real-tree analog (a real run doesn't have "candidate tasks" to attribute to). |
| `test-deploy-verify-wiring.sh` | 0.17s | **KEEP** | The `deploy-headless.sh`↔`verify-deploy.sh` CLI *wiring* contract itself (`--skip-slow`, exit-3-on-failure, `--consumer-report` opt-in) — explicitly engineered to never reach gate 8, cheapest suite in the whole set. |

**Verdict count: 0 DELETE, 14 KEEP (of which 2 reclassify fully out of Category A on inspection:
`test-orchestrate-cycle-plan.sh` was a false positive all along, leaving 13 true Category-A
members plus 1 reclassification note kept visible in the table for audit continuity).**

Category B (9 suites: the 7 narrow unit/lint suites plus the 2 already named above) is **outside
the owner's ruling's scope** — none of them is "the recursive meta-suite class" the ruling names;
they are ordinary regression suites that happen to use `verify-deploy.sh`/`run-all.sh` as a test
subject or test-data string, each already cheap (under 10s, most under 2s). Re-litigating their
individual DELETE/KEEP status is not warranted by this record's mandate and is not attempted here.

### Top-10 Wall-Clock Disposition (answers open question 3)

| Rank | Suite | Wall | Category | Disposition |
|---|---|---|---|---|
| 1 | `test-gate-cache-equivalence.sh` | 543.0s | A | KEEP, OPTIMIZE: amortize the fixed ~4.6s/invocation corpus-scan cost across its 28 `run_vd` calls (e.g. a `--skip-corpus-scan` fast-path for `--only-gate`-scoped equivalence checks, or batch multiple gate ids per invocation where the comparison allows it) rather than deleting anything. See the table row above for the full, now-corrected cost model. |
| 2 | `test-verify-deploy-gate-selection-crash-net.sh` | 148.6s | A | KEEP; same OPTIMIZE angle (fixed per-invocation overhead × ~26 gate ids) is the realistic lever, not deletion. |
| 3 | `test-orchestrate-cycle-plan.sh` | 106.6s | C (reclassified) | Not part of this record's recursion mandate at all (confirmed stub-only). Its cost is from fixture/collaborator setup breadth; a candidate for a *separate* optimization look, out of scope here. |
| 4 | `test-orchestrate-cycle-postflight.sh` | 68.1s | not in the 36 | Out of this record's recursive-suite scope entirely; no disposition rendered here. |
| 5 | `test-git-commit-scoped.sh` | 65.6s | not in the 36 | Tests a specific gitignore/`:(exclude)`-pathspec regression in a scratch git repo; cost plausibly from many real `git` subprocess calls. Not recursive; out of scope for a DELETE/KEEP verdict here. |
| 6 | `test-context-reachability.sh` | 39.9s | not in the 36 | Fixture-driven enumeration suite; no recursion. Out of scope. |
| 7 | `test-claude-refresh-matcher.sh` | 38.1s | not in the 36 | Notably, this suite's own header documents a *deliberate, already-tested* trade-off: a real-backgrounded-process approach was tried and measured to fail 20-83% of the time depending on host load, so it was replaced with the current deterministic scripted probe. This is already the considered, battle-tested design; no one-line optimization is apparent, and it is not a deletion candidate (it tests real OS-level reap semantics no gate covers). |
| 8 | `test-verify-deploy-gate-selection.sh` | 36.8s | A | See verdict table — KEEP. |
| 9 | `test-verify-deploy-context-budget.sh` | 31.0s | A | See verdict table — KEEP. |
| 10 | `test-literature-convert.sh` | 23.7s | n/a (literature extension, not core) | Lives in `agent-system/extensions/literature/`, not core; PDF/DJVU conversion cost is presumably content-driven (real file I/O), not recursion. Out of this record's `core`-scoped audit; flag for the literature extension's own owner if it ever needs attention. |

### Demotion-Tier Question (answers open questions 4 and 5)

No suite-level demotion tier exists today, and none of the two candidate mechanisms supplies
one:

- **`known-failures.txt`** — confirmed by Settled decision 13: advisory only, "never changes
  which suites run." Not a demotion mechanism by design, and shell-suites-only (no Lua baseline).
- **`--skip-slow`** (verify-deploy.sh) and **`--max-cost {free|moderate|slow}`** (verify-deploy.sh,
  confirmed present and wired through `gate-cost-model.csv`'s `cost_class` column) both operate
  at **gate granularity**, not suite granularity. Since gate 8 is the only gate ever classified
  `slow` and it is monolithic (dispatches all ~189 suites or none), both flags are functionally
  equivalent for gate 8's purposes: either you run the whole shell-suite battery or you skip all
  of it. Neither can demote one expensive suite (e.g. keep `test-gate-cache-equivalence.sh` out
  while still running the other ~188) — that would require new suite-level selection machinery
  inside `run-all.sh` beyond what `--only`/`--only SUITE,...` already does for explicit opt-in
  narrowing. The seed's own suspicion (open question 4) is confirmed: **a demotion tier, if
  wanted, is new machinery, not something to assume exists.** This record does not recommend
  building one — the Category-A verdict table above shows the real lever is per-invocation
  overhead reduction, not demotion.
- The separate "52 of 91 narrow core suites unverified against a fresh deploy" figure (Settled
  decision 15) is a *different* axis (deploy-verification coverage under the redeploy checkpoint's
  `--skip-slow`, not this record's wall-clock-cost axis) and decision 15 itself already instructs
  "re-measure the ratio before citing it again." This record does not re-measure it: doing so
  requires a non-`--skip-slow` fresh redeploy through gate 8 (an ~11-minute operation), which is
  out of proportion to what this axis needs from this record. The one fact this record *does*
  establish independently is that `--skip-slow` defers gate 8 **wholesale**, which is sufficient
  to answer open question 5 (no selective demotion) without re-deriving decision 15's own ratio.

### Fixture-Leak Disposition (answers the seed's "does this belong here" question)

Recommend the leak fix **stays in this record**, not a separate one: it is a direct, mechanical
consequence of this record's own subject (gate 8's shell-suite battery dispatch under `timeout
-k 5 600`), only manifests when that battery is running, and the two mechanisms (SIGKILL skips
EXIT trap; the read-only shared fixture needs `chmod -R u+w` before it can be removed) must travel
together per the seed's own note — a reaper built against mechanism 1 alone would silently fail
on exactly the costliest leaked fixtures. The concrete, lowest-risk fix direction: extend
`claude-refresh.sh` (which already reaps other orphaned-resource classes — Lean LSP process
trees, orphaned build-waiter poll loops) with a `/tmp/tmp.*` sweep that `chmod -R u+w` before
`rm -rf`, gated by ownership (invoking user) + no live process reference
(`/proc/*/cwd`/`/proc/*/fd`, never a process-name match) + an age threshold, mirroring the one
successful manual sweep exactly. This is a recommendation for the plan phase to size, not a
design committed here.

## Recommendations

- Do not delete any Category-A suite. Price an OPTIMIZE pass for `test-gate-cache-equivalence.sh`
  and `test-verify-deploy-gate-selection-crash-net.sh` specifically (the two whose cost is
  confirmed dominated by fixed per-invocation `verify-deploy.sh` overhead × invocation count) —
  this is where the record's wall-clock objective function actually has leverage, now that the
  "redundant with a real gate" and "pays gate 8's real cost twice" framings are both refuted by
  direct inspection.
- Re-measure `gate-cost-model.csv` (currently dated 2026-10-19, single row) and the top-10 hint-
  file rows before any plan phase prices savings against them — in particular
  `test-gate-cache-equivalence.sh`'s 543,000ms figure, which this pass could not complete live
  re-timing for.
- Build the `/tmp/tmp.*` reaper as an extension of `claude-refresh.sh`, carrying both leak
  mechanisms together, not as a separate task.
- Do not build a suite-level demotion tier; no existing mechanism supports it and this record's
  own evidence shows the real lever is per-invocation overhead, not selective skipping.
- Leave Category B and Category C suites alone; they are outside this record's mandate.

## Decisions

- The owner's DELETE/KEEP rule is scoped to the 14-member Category-A set (genuine recursive
  meta-suites), not to all 36 suites the naive grep matches. This scoping is itself a decision
  made in this research pass, grounded in reading what each suite actually executes rather than
  what it merely mentions.
- `test-orchestrate-cycle-plan.sh` is reclassified out of the recursive-meta-suite class entirely
  (confirmed stub-only); it remains in the top-10 disposition list for completeness but carries
  no DELETE/KEEP verdict from this record.
- The fixture-leak fix is recommended to stay inside this record rather than spawning a separate
  one, per the reasoning above.

## Risks & Mitigations

- **Risk**: the 543,000ms figure for `test-gate-cache-equivalence.sh` could have drifted
  meaningfully since 2026-10-16 (the corpus has grown ~9% in suite count since then, and this
  suite's own cost is partly a function of corpus size via the per-invocation scan). **Mitigation**:
  the plan phase should re-time this suite specifically (budget ~10 minutes, run it as an isolated
  background-tolerant step rather than inside a bounded research dispatch) before sizing any
  optimization work against it.
- **Risk**: the Category B/C split (which suites merely use `verify-deploy.sh`/`run-all.sh` as
  plumbing vs. truly never execute it) was verified by direct inspection for every Category-A and
  Category-C member, but less exhaustively for all of Category B (7 suites) — a misclassified
  Category B suite could in principle belong in A. **Mitigation**: none of the 9 Category B
  suites is a wall-clock concern (all measured or structurally cheap, under 10s), so a
  misclassification there carries low cost risk even if later corrected.
- **Risk**: this record's own live `/tmp` leak measurement (1,716 entries) and the attempted
  (then stopped) live re-timing of `test-gate-cache-equivalence.sh` both touched real system
  state; the suite run was killed cleanly via `TaskStop` before any destructive step, and no
  `/tmp` entries were deleted by this research pass. **Mitigation**: none needed; no state was
  left in a worse condition than found.

## Context Extension Recommendations

- **Topic**: suite population counting methodology.
- **Gap**: there is no single documented definition of "how many suites exist" — four different
  legitimate countings (core source-store, all-extensions source-store, this-repo deployed tree,
  verify-deploy.sh's own corpus scan) coexist with no page explaining which one a given citation
  means.
- **Recommendation**: a short addition to `context/patterns/shell-script-testing.md` (or
  wherever `run-all.sh`'s discovery algorithm is otherwise documented) naming these four
  countings explicitly, so a future carried figure states which one it means.

## Appendix

### Search queries / commands used

- `ls agent-system/extensions/core/scripts/tests/test-*.sh | wc -l`
- `grep -vE '^\s*#|^\s*$' scripts/tests/suite-cost-hints.txt | sort -t, -k2 -rn`
- `git log --since="2026-11-10" --diff-filter=AD --name-status -- .../scripts/tests/`
- `git log --follow --format='%h %ad %s' --date=short -S'test-gate-cache-equivalence.sh,543000' -- scripts/tests/suite-cost-hints.txt`
- `grep -lE "(run-all\.sh|verify-deploy\.sh)" */scripts/tests/test-*.sh */scripts/test-*.sh` (all loaded extensions, source-store)
- `find /tmp -maxdepth 1 -name 'tmp.*' -printf '%TY-%Tm-%Td %p\n' | sort` and a 400-entry read-only-content sample
- Live timing: `time timeout 60 bash verify-deploy.sh --only-gate 1 ...` (4.6s baseline); `test-gate8-suite-selection.sh` (11.3s); `test-run-all-shared-fixture.sh` (0.28s); `test-gate-cache-equivalence.sh` (started, stopped at 180s per wait discipline)

### References

- Seed report: `specs/586_suite_gate_cost_standing_consumer/reports/01_suite-gate-cost-audit.md`
- `specs/ROADMAP.md` Settled decisions 13, 15, 16
- `agent-system/extensions/core/scripts/tests/run-all.sh` (discovery algorithm, header comments)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (`--skip-slow`, `--max-cost`, `--only-gate`)
