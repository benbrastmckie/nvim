# Decision Record: Suite/Gate Wall-Clock Cost — DELETE/KEEP Verdict, Suite-Population Counting Methodology, and Demotion-Tier Non-Recommendation

This record is the standing consumer for the suite/gate wall-clock cost probes
(`measure-gate-costs.sh` -> `gate-cost-model.csv`, `tests/suite-cost-hints.txt`), per ROADMAP
Settled decision 16: a systemic cost is filed as one standing task against a probe's output, not
as a stream of point defects.

## The Governing Test

The owner's own discrimination rule for the recursive meta-suite class — a suite whose entire
purpose is to exercise the orchestration/dispatch layer itself (`run-all.sh` and/or
`verify-deploy.sh`) as a subject under test, more than once, inside a scratch fixture:

**DELETE** when a `verify-deploy.sh` gate already asserts the same property against the real
tree. **KEEP** when the fixture reaches a state the real tree cannot be put into (crash nets,
stale-lock reclaim, nested invocation, fail-open degradation, cross-invocation or concurrency
equivalence a single real run structurally cannot self-certify).

## The Verdict: 0 DELETE, 14 KEEP

A naive lexical test (`grep -lE "(run-all\.sh|verify-deploy\.sh)"` over the core suite corpus)
returns 36 matches. Reading each for what it actually *executes*, not merely what it *mentions*,
splits them three ways: 14 genuine recursive meta-suites (Category A, the rule's actual target),
9 narrow unit/lint suites that use the real script only as plumbing for a much narrower property
(Category B, outside the rule's scope), and 13 false positives — a comment-only mention, or
planted fixture content a classification lint asserts against, never executed for real
(Category C). 14 + 9 + 13 = 36. **The naive grep over-counts the genuine recursive-meta-suite
class by roughly 2.6x** (36 ÷ 14): a future reader re-running that grep and trusting its raw
count alone will land on a number close to the incorrect "35" figure some citations carry, not
the correct 14.

Applying the owner's rule to the correct 14-member Category-A set yields **zero DELETE
verdicts**. Every one of the 14 tests a cross-invocation, concurrency, equivalence, or
crash-safety property a single real-tree gate run structurally cannot self-certify (a real run
only ever exercises one invocation shape at a time):

| Suite | Unreachable-by-real-tree property (why KEEP) |
|---|---|
| `test-gate-cache-equivalence.sh` | Cached-vs-uncached output *equivalence* — a real run only ever takes one path. Already stubs gate 8's `run-all.sh` with a near-instant fake and excludes gate 22 from its mechanical loops; its real cost is per-invocation `verify-deploy.sh` overhead × invocation count, not a second full battery pass. |
| `test-verify-deploy-gate-selection-crash-net.sh` | A crash net: every registered gate id run standalone, proving none crashes. Already passes `--skip-slow` on every invocation. |
| `test-verify-deploy-gate-selection.sh` | `--only-gate`'s own flag-selection correctness (does selecting gate N run exactly N?) — a real run only ever uses whatever flags were passed; it never self-verifies the selection mechanism. |
| `test-verify-deploy-context-budget.sh` | Gate 20's own severity-toggle and pre/post-findings-snapshot non-regression edge cases. |
| `test-gate8-expected-new-distinction.sh` | Gate 8's EXPECTED-vs-NEW pass/warn/fail branching — a property of `gate8_run()`'s own exit-code interpretation, not of the suites it runs. |
| `test-gate8-suite-selection.sh` | Gate 8's touched-paths narrowing, full-sweep fallback, and the forced cache-ineligibility invariant on a narrowed run — properties about *which suites get selected*. |
| `test-gate-lock.sh` | Stale/killed-holder lock reclaim, the nested-invocation no-op path, and fail-open degradation on a stubbed `task-lock.sh`. Never touches the real `specs/` tree. |
| `test-run-all-failure-reporting.sh` | `run-all.sh`'s own failure-naming/roster contract against a synthetic fixture, never the real battery. |
| `test-run-all-parallel.sh` | `--jobs N` parallel-pool behavior-preservation and genuine wall-clock concurrency — no single serial real run can check this. |
| `test-run-all-selection.sh` | `--only SUITE[,...]` selection parity-checked against every other flag combination — flag combinatorics, not reachable from one real invocation. |
| `test-run-all-shared-fixture.sh` | Pins the shared-fixture-build-once/never-when-unused contract itself. |
| `test-measure-gate-costs.sh` | The cost-measurement harness's own load-guard and averaging behavior — this very record's probe is gated by this suite. |
| `test-orchestrate-batch-gate.sh` | Batch-shared-gate finding-to-task attribution logic — a real run has no "candidate tasks" to attribute to. |
| `test-deploy-verify-wiring.sh` | The `deploy-headless.sh` <-> `verify-deploy.sh` CLI wiring contract itself, explicitly engineered to never reach gate 8. |

Category B (9 suites — the real script used only as plumbing for one library function, one
lint, or one gate's internal sub-check, each already cheap, under 10 seconds) is outside the
owner's ruling's scope entirely; it is not the recursive meta-suite class the ruling names, and
re-litigating its individual status is not this record's mandate. Category C (13 files whose
only reference to the real script is a comment or a lint's planted fixture string) requires no
disposition at all, since nothing about them is actually recursive.

## Why the Naive Grep Over-Counts

Two concrete mechanisms, confirmed by direct inspection, account for the gap between 36 and 14:

1. **Stub-only files written for call counting.** `test-orchestrate-cycle-plan.sh` and
   `test-orchestrate-build-dispatch.sh` each write an *empty stub file* literally named
   `verify-deploy.sh` into a scratch fixture, purely to count how many times their own code under
   test would have invoked it — the real script is never executed.
2. **Planted fixture content a classification lint asserts against.** `test-lint-unit-
   integration-boundary.sh` writes the literal string `bash ./run-all.sh` into a synthetic
   fixture file to prove a *lint* correctly detects a suite that references it; the string is
   data for the lint under test, never a command the suite itself runs.

A bare occurrence count from the naive grep conflates both of these with the 14 suites that
genuinely re-invoke the orchestration layer. The correct discriminator is always "what does this
file *execute*", never "what does this file *mention*".

## Four Suite-Population Countings, and Why a Bare Count Is Never a Safe Citation

"How many suites exist" has no single answer — four different, legitimate countings coexist,
each answering a different question, re-derived live at the time this record was written:

| Population | Count | Command |
|---|---|---|
| Core source-store `test-*.sh` | 157 | `ls agent-system/extensions/core/scripts/tests/test-*.sh \| wc -l` |
| All-loaded-extensions source-store | 197 | `find agent-system/extensions/*/scripts/tests -maxdepth 1 -name 'test-*.sh'` plus each extension's flat `scripts/test-*.sh` |
| This repository's deployed tree | 179 (`.claude/scripts/tests/`), 189 including the flat `.claude/scripts/test-*.sh` siblings | `ls .claude/scripts/tests/test-*.sh \| wc -l` (plus the flat count) |
| `script-inventory.sh`'s own corpus scan | 204 (`test_suites`) | `bash agent-system/extensions/core/scripts/script-inventory.sh --root . --size-line` |

Each of these is correct for the question it answers; none of them is "the" suite count. A future
citation of a bare suite-count number is not safe without naming which of these four populations
it means and re-deriving it with the command above — the exact commands this table provides exist
so a future reader never has to guess which population a prior number meant, or re-derive the
methodology from scratch.

## Demotion-Tier Finding: Not Recommended

No suite-level demotion tier exists today, and no existing mechanism supports building one
without new machinery:

- `known-failures.txt` is advisory by design (ROADMAP Settled decision 13: "never changes which
  suites run"). It is not a demotion mechanism and was never meant to be one.
- `--skip-slow` and `--max-cost {free|moderate|slow}` (`verify-deploy.sh`) both operate at *gate*
  granularity, not suite granularity. Gate 8 is the only gate ever classified `slow`, and it is
  monolithic — it dispatches the entire shell-suite battery or none of it. Neither flag can
  demote one expensive suite inside gate 8 while leaving the rest running; that would require new
  suite-level selection machinery inside `run-all.sh` beyond what `--only SUITE[,...]` already
  does for explicit, caller-driven narrowing.
- The separate "52 of 91 narrow core suites unverified against a fresh deploy" figure (ROADMAP
  Settled decision 15) is a different axis entirely — deploy-verification coverage under the
  redeploy checkpoint's `--skip-slow`, not this record's wall-clock-cost axis — and is not
  re-measured here; decision 15 already instructs re-measuring that ratio before it is next
  cited, and this record's own finding (that `--skip-slow` defers gate 8 wholesale) is sufficient
  to answer the demotion question on its own terms.

A suite-level demotion tier is **not recommended**. The real, measured lever against this
record's wall-clock objective is per-invocation overhead reduction (see below), not selective
skipping.

## Realized Savings and Residual State

- **Fixed per-invocation corpus-probe overhead** (`verify-deploy.sh`'s standing corpus-size
  probe, which shells out to `script-inventory.sh --size-line` on every invocation): now
  suppressed on any gate-narrowed invocation (`--only-gate`/`--max-cost`) unless the new
  `--corpus-probe` opt-in flag is passed; an unfiltered invocation is unaffected. Measured saving:
  ~2.4 seconds per gate-narrowed invocation (3.805s with the probe forced, emulating the prior
  always-on behavior, versus 1.400s without it, against a real-copy fixture). `test-gate-cache-
  equivalence.sh` and `test-verify-deploy-gate-selection-crash-net.sh` are the two suites that pay
  this cost dozens of times per run (28 and ~26 invocations respectively), so this is where the
  savings compound.
- **`test-verify-deploy-gate-selection-crash-net.sh`**: re-timed cleanly at 78.68s against a prior
  148.6s hint-file figure — a ~47% reduction, consistent with the per-invocation saving above
  multiplied across its ~26 gate-id invocations.
- **Leaked test-fixture backlog** (`/tmp/tmp.*` directories orphaned when `run-all.sh`'s
  `timeout -k 5` grace-period escalation SIGKILLs a suite, which skips its own `EXIT` trap):
  reclaimed by a new, independently-gated `claude-refresh.sh` pass carrying both observed leak
  mechanisms together (the SIGKILL/EXIT-trap gap, and non-writable fixture content a plain
  `rm -rf` cannot remove — `chmod -R u+w` first). Measured reclamation: 1,733 entries / 1.4 GB
  before, 240 entries / 549 MB after (all 240 survivors explained by the age-threshold gate alone
  — each is younger than the reap threshold, not a new leak mechanism).
- **Owed follow-up, named explicitly rather than left silent**: `gate-cost-model.csv` and
  `tests/suite-cost-hints.txt` were NOT regenerated against the optimized system. Host load rose
  to 3.26-3.86 (above `measure-gate-costs.sh`'s 2.0 threshold) partway through this record's own
  measurement pass — confirmed via live `ps` (a concurrent Lean build and other active sessions
  on a shared desktop host) — and a contaminated cost artifact is worse than a stale one, since
  `--max-cost` and `run-all.sh`'s own scheduler both act on these files. Both artifacts remain at
  their pre-existing values (`gate-cost-model.csv` still a single-row, `gate8`-only model dated
  2026-10-19; `suite-cost-hints.txt` still summing to the pre-optimization 1,406,493 ms). A future
  invocation of `bash agent-system/extensions/core/scripts/measure-gate-costs.sh --regen-hints
  --skip-gate-measure` followed by `bash agent-system/extensions/core/scripts/measure-gate-
  costs.sh`, run once the host is confirmed idle throughout, closes this gap — read each
  artifact's own `# ALL_VALID=` header before trusting the result, never stderr alone.
  `test-gate-cache-equivalence.sh`'s own re-timing attempt under that same contention (576.6s) is
  likewise contaminated-suspected and should be re-taken under confirmed-idle conditions rather
  than cited as a confirmed figure either way.

## Scope Boundary Honored

This record decides the DELETE/KEEP verdict over the Category-A recursive-meta-suite class, the
suite-population counting methodology, and the demotion-tier question. It does not decide, and
leaves untouched: Category B's or Category C's individual suites (outside the owner's ruling's
scope), the "52 of 91" deployed-tree coverage ratio (a different axis, ROADMAP Settled decision
15's own), or any further optimization beyond the corpus-probe suppression already landed.
