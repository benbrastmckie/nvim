# Shell Script Testing Convention (core)

This is the settled convention for testing core's own shell scripts
(`agent-system/extensions/core/scripts/**`). It exists so the next core-script author does not
have to re-derive a testing shape by reading two divergent existing examples: a flat single-script
suite (`scripts/test-task-lock-reap.sh`) and, in a sibling extension, a `tests/` subdirectory
holding narrow suites alongside a separate flat pipeline suite. Both patterns are legitimate; this
doc states which applies when.

## Location rule (scope-based, not extension-based)

- **Narrow, fixture-driven suite for a single script** -> `scripts/tests/<script-under-test>`-named
  test file, e.g. `scripts/tests/test-census-count.sh` tests `scripts/census-count.sh`.
- **Broad end-to-end / pipeline suite** that exercises multiple scripts together, or a full
  command-level workflow -> stays flat in `scripts/`, e.g. `scripts/test-session-registry.sh`.

This is a scope-based split, not "core always does X" or "follow whichever extension shipped
first." A sibling extension already mixes both shapes for exactly this reason: its narrow,
single-script regression suite lives in a `tests/` subdirectory, while its broader pipeline test
stays flat alongside production scripts.

**Known, intentionally tolerated exception**: `scripts/test-task-lock-reap.sh` predates this
convention. It is a narrow, single-script suite that would arguably belong under `scripts/tests/`
per the rule above, but migrating it is unrelated cleanup, not required by any task that merely
*adds* a new test under the `tests/` convention. Do not fold that migration into an unrelated
diff; if it happens, it should be its own deliberate, reviewed change.

## Helper-naming convention

Core's own precedent (`test-task-lock-reap.sh`) sets the naming inside `scripts/` and
`scripts/tests/` alike:

```bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }
```

- Integer counters `PASSED`/`FAILED`, incremented by `pass()`/`fail()`.
- `info()` for diagnostic context printed inside a failing case (not counted).
- `SCRIPT_DIR` resolved via `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` so the suite is
  runnable both from the source store and from a deployed `.claude/scripts/` copy.
- `mktemp -d` workdir with a `trap '...cleanup...' EXIT` — never touch the real `specs/` tree or
  any other real repo state from a test.
- Exit 0 when `FAILED` is 0 after all cases run; exit 1 otherwise.

This naming is a core-local convention. A different extension's `t_pass`/`t_fail` style used
inside its own `scripts/tests/` remains valid there — location is the shared rule across
extensions; helper naming is extension-local and does not need to be unified.

## Fixture convention

Fixtures are constructed inline via heredocs into the `mktemp -d` workdir created at suite
start — there is no committed fixture tree and no fixture-generator script for core's own suites.
This keeps each encoded case visible directly next to the assertion that consumes it, and avoids
registering non-script fixture files in `manifest.json`'s `provides` arrays, which have no slot
for fixture data.

A committed fixture generator (as used elsewhere for binary fixtures such as PDFs, where inline
heredocs are impractical) remains a reasonable choice for a future suite whose fixtures cannot be
expressed as plain text — this convention governs core's own suites, which to date are entirely
text-based.

### Never resolve a path against the live tree

A suite must never resolve an artifact path against the live `specs/` tree or the deployed
`.claude/` tree. Build or copy a scratch fixture repo (`build_fixture_repo()` in
`test-skill-base-lifecycle.sh` is the canonical structural model: a `mktemp -d` root with a real
`.claude/scripts/{,lib/}` copied in and a synthetic `specs/` task directory underneath) and
redirect `REPO_ROOT`/`PROJECT_ROOT` at it before invoking the code under test, rather than
pointing at, or falling back to, the real repository root for anything the suite itself reads.

The concrete failure mode this guards against: a suite that hardcodes a real, numbered task
directory as an "exists on disk" fixture breaks the moment `/todo` archives that task or a vault
operation renumbers it — a failure that looks exactly like flake (a suite that used to pass now
fails, on no code change of its own) and is not one. `test-validate-return-meta.sh` hit this
defect: it hardcoded `specs/052_return_meta_artifacts_shape_contract/...` as its "well-formed"
fixture, never overrode `REPO_ROOT`, and failed three cases deterministically on every run for a
week after `/todo` archived that directory. The fix was to build its own scratch fixture repo and
inject `REPO_ROOT` at every call site, exactly per the `build_fixture_repo()` pattern above.

A mechanical lint for this class of defect was attempted and dropped: distinguishing a live-path
literal that will actually be filesystem-checked from a synthetic literal used as inert JSON/text
fixture content requires per-validator data-flow knowledge a grep-level heuristic does not have,
and the attempt produced too many false positives against this codebase's real suites to be
trustworthy. Enforcement of this rule is therefore currently manual (author/reviewer discipline
at fixture-authoring and code-review time), not mechanical — read this section, not a lint
output, as the source of truth.

## Loud-skip discipline

A prerequisite that is unavailable (a missing interpreter, a missing script under test, a missing
optional environment variable that gates a stronger check) must either exit non-zero with a clear
message, or emit a visible skip warning naming exactly what was skipped and why. A silently
skipped check that reports nothing and still exits 0 is treated as a failure of the harness
itself — a suite that can silently do nothing provides no guarantee.

## Mutation checks for regex-shaped fixes

When a suite exists specifically to lock in a regex or pattern fix (as opposed to general
behavior), the suite is not trustworthy until it has been shown to fail against the pre-fix
pattern at least once. Revert the fix, confirm the suite goes red, then restore the fix. A suite
that passes unchanged against both the old and the new pattern is not testing the fix — it is
testing something both versions already got right, and provides no regression protection for the
gap the fix closed.

## Registration

Test scripts are ordinary entries in `manifest.json`'s `provides.scripts` array, subdirectory-
qualified where applicable (`tests/test-census-count.sh`, not just `test-census-count.sh`) —
`provides.scripts` already carries other subdirectory-qualified paths (`lint/lint-*.sh`), so this
needs no new schema or new `provides` sub-array.

## Suite runtime: `--jobs`, `--timings`, and gate selection

- `run-all.sh --timings FILE` writes one CSV row per suite (`suite_path,wall_ms,result`) plus a
  final `TOTAL` aggregate row. Additive only — absent the flag, output and exit codes match today.
- `run-all.sh --jobs N` (or `--jobs auto`, capped at 4) runs suites in parallel by file, using
  longest-first scheduling from the advisory `tests/suite-cost-hints.txt` file (regenerate it from
  a `--timings` run; a missing, stale, or partial hints file never skips, duplicates, or
  reorders-away a suite). **Default stays `1`** (today's sequential behavior) — a 3-run
  flakiness gate (211.9s / 219.3s / 211.9s at `--jobs 4` vs. 507.9s at `--jobs 1`, a 58% battery
  reduction on a dedicated, quiet host) found two load-sensitive suites did not reliably benefit
  from parallelism under heavy ambient host load, so the flip to a parallel default was declined;
  `--jobs` remains a correct, verified opt-in. A nested-invocation guard (`RUN_ALL_NESTED=1`) forces `--jobs 1`
  whenever `run-all.sh` runs inside another `run-all.sh` invocation (e.g. `verify-deploy.sh`
  gate 8 calling a suite that itself shells out to `verify-deploy.sh`), so job counts never
  multiply. A fixed `LOAD_SENSITIVE_BASENAMES` set (below) always runs serially, outside the
  parallel pool, regardless of `--jobs`.
- `verify-deploy.sh --only-gate N[,M,...]` runs only the named gate(s) instead of the full
  20-gate battery. Additive and opt-in — absent the flag, every gate still runs. Use it to let a
  suite exercise one gate's logic cheaply (`test-verify-deploy-gate-selection.sh` is the reference
  example). **At least one full-battery `verify-deploy.sh` invocation must remain in the suite**
  (currently `test-verify-deploy-context-budget.sh`'s baseline case) so the "every gate runs
  together" contract stays covered somewhere.
- `verify-deploy.sh --skip-slow` defers Gate 8 (`run-all.sh` itself, the 105-suite shell battery)
  only — every other gate still runs. The orchestrator's own redeploy checkpoints
  (`orchestrate-cycle-plan.sh`'s three `deploy_findings_snapshot` calls and
  `command-gate-out.sh`'s two) now pass this flag, because those checkpoints were found to
  re-run the full shell-test battery 2-3 times per cycle on top of every dispatched
  implementation agent's own phase-gate run of the identical battery against the identical
  source-store tree — a measured, dominant wall-clock cost, not additional coverage (deploy
  merely copies files; it does not change suite source). See
  `context/patterns/batch-orchestration-guardrails.md`'s "Inter-Cycle Redeploy Checkpoint"
  subsection for the accepted trade-off this decision carries.
- `verify-deploy.sh`'s own Gate 8 (the `run-all.sh` call site, distinct from `run-all.sh`'s own
  `--jobs` flag above) now requests `run-all.sh`'s opt-in parallelism itself: `--jobs
  "$VERIFY_DEPLOY_GATE8_JOBS"`, defaulting to `auto` (`VERIFY_DEPLOY_GATE8_JOBS` unset), with `1`
  as the documented override for a `nproc=1`, memory-pressured, or heavily-loaded host --
  operational, no code change needed. `run-all.sh`'s own nested-invocation guard
  (`RUN_ALL_NESTED`) is unaffected and still forces sequential execution when Gate 8 is itself
  reached from inside another `run-all.sh` suite. Measured on a heavily-loaded host (several
  concurrent agent sessions active): a full `verify-deploy.sh` run (no `--skip-slow`) went from
  14m1.5s sequential to 6m47.4s under `--jobs auto` (51.6% reduction), with an identical `[FAIL]`
  set across the two runs except for one suite already on `run-all.sh`'s own
  `LOAD_SENSITIVE_BASENAMES` list (which always runs serially before the pool regardless of
  `--jobs`, so this change cannot be its cause) -- `VERIFY_DEPLOY_GATE8_JOBS=1` reproduced the
  sequential baseline's `[FAIL]` set exactly on a separate rerun. This full-`verify-deploy.sh`
  percentage is somewhat lower than the dedicated, quieter-host `run-all.sh`-only flakiness-gate
  measurement cited above (507.9s to ~212s, 58%), consistent with the ~2-3 fixed minutes of the
  other 19 gates diluting the parallel fraction, plus this measurement's heavier ambient load.
- `run-all.sh --only SUITE[,SUITE,...]` runs ONLY the named suite basename(s) instead of the full
  discovered battery. Strictly additive and opt-in -- absent the flag, `SUITES` is never touched
  and output is byte-identical to a pre-`--only` run (proven exactly on a deterministic synthetic
  fixture; see `tests/test-run-all-selection.sh`'s case5). Every comma-separated token is
  validated against the discovered basename set BEFORE any suite runs -- one unknown token exits
  2, naming the token, and runs nothing at all (mirrors `--only-gate`'s "a partially-valid list
  must refuse loudly, not silently run a subset"). Filtering happens at exactly one site
  (immediately after the self-exclusion block, before `TOTAL_DISCOVERED`), so `--jobs`, the
  nested guard, `LOAD_SENSITIVE_BASENAMES` serialization, `TOTAL_ACCOUNTED`,
  `known-failures.txt` classification, and `--timings` all inherit the narrowing for free with
  zero duplicated filtering logic. **Honesty constraint, stated here because it is the single
  most important thing to get right about this flag**: a selected-subset pass is NOT evidence
  that doc-sync pins hold -- the same already-accepted trade-off this doc already records for
  `--skip-slow` two bullets up. Selection is also a strictly separate axis from
  `known-failures.txt` (that manifest is advisory and never changes which suites run, only how a
  failure is annotated) -- the two mechanisms must never be conflated. Gate 8's own invocation
  (`verify-deploy.sh`, two bullets up) keeps running the full, unselected sweep unchanged; `--only`
  is for a cheaper mid-task phase gate that needs real (not skipped) coverage of what the phase
  actually touched, which `--skip-slow` cannot provide.

### Mapping a touched file to its suite: `scripts/lib/suite-selection-lib.sh`

`--only` takes an exact, pre-resolved basename list -- it does not itself know which suites
correspond to a given touched source file. That mapping lives in one sourced-only library,
`scripts/lib/suite-selection-lib.sh` (never executed; modelled structurally on
`scripts/lib/manifest-routing-lib.sh`), so both `run-all.sh` and any future caller share one
implementation rather than maintaining drifting copies. A caller resolves suite names there
first, then passes the resolved list to `run-all.sh --only <list>` -- the two pieces compose,
neither calls the other.

The mapping runs in three ordered strata per touched path, against the same two fixed suite
locations `run-all.sh` itself scans (`scripts/tests/test-*.sh` and flat `scripts/test-*.sh`):

1. **Strict basename pairing** -- `NAME.sh` -> `test-NAME.sh` (covers `lint/lint-*.sh` and flat
   `scripts/*.sh`), plus the corpus's `lib/` suffix variant for a `lib/` file not already named
   `NAME-lib.sh`: `NAME.sh` -> `test-NAME-lib.sh` (e.g. `lib/common.sh` ->
   `tests/test-common-lib.sh`).
2. **Grep-based reference lookup** -- every suite that textually references the touched
   basename, many-to-one allowed (e.g. `lib/task-lookup-lib.sh` is referenced by two dozen
   suites; a shared `lib/` file's fan-out can be large, which bounds how much a selection
   touching it can save -- see the measured figures below).
3. **Zero hits in both strata above -> the full-sweep sentinel.** This is the dangerous case: an
   unmapped touched file must escalate the WHOLE call to the full, unselected sweep, never select
   nothing silently. A single unmappable path among several touched paths escalates the entire
   multi-path call (the aggregation rule is "union of per-path selections, except one
   unmappable path escalates everything").

The library also classifies each selected suite's resolution order for the touched basename as
one of `source-only` / `source-first` / `deployed-first` -- advisory only, never
selection-blocking (a `deployed-first` suite is still selected and still reported as such). This
exists because a naive basename mapping can select a suite whose subject-under-test actually
resolves to the deployed `.claude/` copy rather than the source-store copy being edited, which is
not proof the source edit is covered. The classification is a textual heuristic over suite
source code (not a semantic trace of runtime path resolution), deliberately conservative, and
documented as an approximation in the library's own header.

**Deliberately NOT reused**: `scripts/script-inventory.sh`'s `has_test` resolves test candidates
against each candidate's own enclosing directory (`lib/tests/test-X.sh`), a path shape this
corpus never actually uses -- every suite here lives at exactly one of the two fixed locations
named above. Reusing `has_test` verbatim would structurally under-report `lib/` and `lint/`
coverage. Fixing that directory-resolution bug is a separately-scoped standing task's ground, not
this library's job -- this is a pointer caveat only.

**Measured figures** (re-derived at this feature's own implementation time rather than carried
from an earlier report, per this doc's own re-run-don't-cite-frozen-numbers practice): 93 narrow
+ 9 flat core suites; 52/93 (55.9%) deployed-preferring (`grep -l '$REPO_ROOT/.claude'
tests/*.sh`); a 19-script zero-reference set (the fail-safe fixture population: e.g.
`memory-harvest.sh`, `migrate-directory-padding.sh` -- re-derive live, these counts drift as the
corpus grows). On a heavily-loaded host (concurrent sibling sessions active throughout, `uptime`
load average observed between 3.99 and 12.90 across the measurement window -- heavier than this
doc's own previously recorded "loaded" condition): a representative 5-file touched set spanning
`lint/`, `lib/`, and flat `scripts/` resolved to 32 suites and ran in 375,669ms (~6.3min)
`--jobs auto`, versus 760,286ms (~12.7min) for the full 123-suite sweep -- selected was ~49.4% of
full-sweep wall-clock. The selected run's result set was verified a byte-identical subset of a
freshly-measured full run across all 32 overlapping suites (zero suites reporting differently).
**Honest caveat, not smoothed over**: the single most expensive suite in the corpus
(`test-verify-deploy-context-budget.sh`) was pulled into this particular 5-file selection via a
`lint/` file's grep-stratum reference and accounted for 99.8% of the selected run's own
wall-clock -- most of the measured saving came from NOT running the ~90 other, mostly-cheap
suites, not from avoiding the single heaviest one. A touched-file set whose many-to-one `lib/`
fan-out pulls in the corpus's few genuinely expensive suites will see a correspondingly smaller
saving; this is a property of the mapping being honest (many-to-one, not tuned), not a defect.

**Declined alternatives** (recorded so a future reader does not re-propose them):
- `--filter PATTERN` (a human-typed glob/regex matched against discovered basenames) --
  declined-for-now. No concrete interactive caller was identified, and the mapping library always
  emits an exact resolved basename list, never a pattern, so nothing today would consume pattern
  syntax. Revisit if a caller needs pattern matching the library's own strata cannot express.
- A `verify-deploy.sh` pass-through for `--only` -- not built. Gate 8 keeps invoking the full
  sweep unchanged by design (narrowing Gate 8's own default would violate the non-negotiable
  "tiering governs granularity only, never the final gate" invariant), and a cheaper mid-task
  phase gate can invoke `run-all.sh --only` directly without going through `verify-deploy.sh` at
  all. Revisit as a follow-up only if a concrete caller needs `--only` reachable specifically
  through the `verify-deploy.sh` CLI surface.

Regression coverage for both halves of this mechanism (the mapping library's escalation and
classification behavior, and the flag's validation/parity behavior on a deterministic synthetic
fixture) lives in `tests/test-run-all-selection.sh`.

### End-of-run failure roster and the known-failures baseline

`run-all.sh` prints two things beyond the per-suite `[FAIL] <path>` lines: an end-of-run roster
(`[run-all] Failing suites (N):` followed by one indented path per failure, printed unconditionally
— not `--quiet`-suppressed) immediately before the final tally, and, when
`scripts/tests/known-failures.txt` is present, an EXPECTED/NEW classification on both the roster
entries and the tally line itself
(`[run-all] N passed, M failed (E expected, X NEW), S skipped, T total`). The roster and its
annotations are deliberately free of the literal token `[FAIL]` — `verify-deploy.sh`'s Gate 8
folds every `grep -F '[FAIL]'` occurrence into a `FINDING gate8` row, so a roster carrying that
token would silently double every finding.

`--fail-on-new` is an opt-in flag that exits non-zero only when at least one failure classifies as
NEW (unlisted in the manifest); the DEFAULT exit-code semantics are unchanged regardless of the
manifest's presence — exit 1 if any suite failed, EXPECTED or not. A missing or truncated
`known-failures.txt` degrades to exactly the pre-manifest tally, roster, and exit code; deleting
the file is the designed escape hatch, not a workaround.

Regression coverage for all of the above (naming, roster, the double-count guard, `--quiet`/
`--jobs N` parity, and the manifest/`--fail-on-new` cases) lives in
`tests/test-run-all-failure-reporting.sh`.

### Known pre-existing failures and flakes (baseline, not regressions)

**Source of truth: `scripts/tests/known-failures.txt`**, not this section. Maintaining the same
fact in two places (a checked-in manifest AND a prose list here) is exactly the drift mechanism
that produced a stale version of this list once already — it named suites as failing that a later
fix had already cleared, and omitted the actual defects a live run turned up. Consult the manifest
for the current failing set, its category, its reason, and its owner (or `needs-owner`).

What the categories mean (unchanged prose, kept here rather than in the manifest so the manifest
itself stays terse and data-shaped):
- `real-defect` — a genuine bug in the suite's subject, not the suite itself; fix the subject or
  spawn a follow-up task, do not weaken the suite's assertions to paper over it.
- `intermittent` — a flake under heavy ambient host load or similar non-deterministic conditions,
  already evaluated and deliberately accepted rather than fixed (see the suite's own comment for
  the specific rejected-alternatives account, if one exists). Before accepting a new row under this
  category, rule out a DETERMINISTIC cause masquerading as load-sensitivity — e.g.
  `test-run-all-parallel.sh` was once attributed purely to ambient load, but part of its failure
  was actually a nested-environment inheritance bug (an outer `run-all.sh`'s exported
  `RUN_ALL_NESTED=1` leaking into this suite's own "unguarded" fixture measurements, forcing them
  sequential too) that reproduced 100% of the time under `RUN_ALL_NESTED=1` regardless of host
  load, and is now fixed. A failure that reproduces deterministically under a specific environment
  condition is a `real-defect`, not `intermittent`, even if it was first observed on a loaded host.
- `load-sensitive` — the runtime-scheduling category `run-all.sh`'s `LOAD_SENSITIVE_BASENAMES`
  array already covers (see the `--jobs` section above); a suite belongs in `known-failures.txt`
  under this category only if it is ALSO known-failing, which is a different condition from being
  merely excluded from the parallel pool.
- `wip-transient` — the suite's redness traces to uncommitted, in-flight working-tree state at
  seed time rather than a committed defect; do not commit a `wip-transient` row against a suite
  that is actually red on a clean, fully-committed tree — recategorize it as `real-defect` instead.

To add or retire a row: edit `known-failures.txt` directly (it is advisory, optional, and
basename-keyed — see its own header for the exact format). Do not restore a second prose copy of
the failing set here when doing so.

### Re-validate a row's claimed symptom against live output before scoping work from it

A `known-failures.txt` row's `reason` text is a snapshot taken at seed time, not a live fact. A
row can be seeded AFTER the defect it originally described was already fixed by an unrelated
commit, while the suite stays red for a later, different reason that happens to touch the same
counters or the same case numbers. Treating the row's prose as the authoritative description of
what is currently wrong — without re-running the suite and comparing its live `[FAIL]` text
against the row's claimed shape — risks scoping an entire task around a symptom that no longer
exists, while the suite's actual (and possibly much narrower) live failure goes unaddressed.

Before taking on a `needs-owner` row as a task's scope: re-run the named suite, capture its live
`[FAIL]` line(s) and any shape it reports (e.g. a `fixes=N errors=N` count), and compare that
verbatim against the row's claimed symptom. If they match, the row's prose is still an accurate
scope. If they do not — the row describes a defect pattern no longer reproducible, or a different
case now fails than the one named — treat the LIVE output as the scope, not the row's text; the
row's staleness is itself worth recording in whatever artifact supersedes it (e.g. a plan's
Overview), but the manifest itself stays terse and data-shaped per the Source of truth note above
— do not add a suite-status list here.

Concretely demonstrated once by `test-gate-out-repair-reporting.sh`: its underlying production
fix (reset-at-entry plus per-file accumulation in `skill-base.sh`) landed via commit `d6934a269`
(2026-09-03), and its own fixture-driven regression suite landed the same day via `acb984656`.
A row was nonetheless seeded against this suite on 2026-09-30 via `0f1b721a4`, describing a
"does not accumulate / not reset between calls" symptom that the Sep 3 commits had already
fixed. The suite stayed red regardless, but for an unrelated reason introduced by a later,
separate feature (a plan-level Status-line grammar check, landed 2026-09-29 via `5abc55db8`)
interacting with one fixture's choice of omitted metadata field. A re-run and a live-output
comparison at claim time would have caught the mismatch immediately, rather than after a task's
scope had already been drafted around the stale description.

## Related

- `context/standards/testing.md` — a generic JS/AAA-pattern testing primer. It predates this
  convention, covers a different language and pattern (unit-test frameworks, mocks), and is not
  superseded by this doc; the two are complementary; cross-reference rather than merge.
- `context/standards/census-methodology.md` — the standard method for deriving and cross-checking
  repo-wide counts. Its shipped tooling and fixture suite follow this doc's conventions.
