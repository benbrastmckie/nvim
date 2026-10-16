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

## Verdict-line extraction contract (producer/consumer)

Several verify-deploy.sh gates fold a producer script's own `[FAIL]`/`[VIOLATION]` output into
`FINDING` rows. The contract both sides must honor, stated once here:

**Producer side**: a verdict row is line-initial modulo a leading SGR (ANSI color) escape
sequence — optionally `\x1b[<params>m`, then the literal anchor token (`[FAIL]` or
`[VIOLATION]`), then exactly one space, then the message. Narration (as opposed to a verdict) uses
a visibly distinct prefix — e.g. `tests/run-all.sh`'s `[run-all] [PASS] $suite_name` — never the
bare anchor token at line start. `tests/run-all.sh` still carries a standing CRITICAL CONSTRAINT
comment (near its roster-block emission) stating that block must never contain the literal token
`[FAIL]` anywhere; keep that comment, but it is no longer the load-bearing defence against a
false-positive extraction — the consumer-side anchor below is.

**Consumer side**: extraction uses `verify_deploy_extract_verdict_lines <anchor_token>
<producer_output>` (`scripts/lib/gate-verdict-extract-lib.sh`), which strips SGR sequences from
every line FIRST, then selects only lines beginning with `<anchor_token> ` (one trailing space),
then strips that prefix. Stripping before anchoring is required, not merely tidy: of
verify-deploy.sh's producer scripts, most emit their verdict row as
`echo -e "${RED}[FAIL]${NC} $1"` with no TTY or `NO_COLOR` guard, so the row begins with an SGR
escape rather than the literal token. A bare `grep -E '^\[FAIL\] '` against raw output would
reject every one of those rows — converting a real gate into a silent zero-finding gate while
looking like a correctness fix. The anchor token is always an explicit parameter to the helper,
never inferred: the `[FAIL]` and `[VIOLATION]` token sets are disjoint and per-producer, and a
helper that guessed the token from a gate number would miss exactly the class of defect this
contract exists to prevent.

Why an unanchored `grep -F '[FAIL]'` was wrong in the first place (the defect this contract
replaces): it matches any line CONTAINING the token anywhere, not only a producer's own
line-initial verdict row. Measured live against a real batch-gate run, this folded a `[PASS]`
narration line whose own message text quoted the token, and an indented, fixture-internal
`[FAIL] ...` line from a suite's own inner output (not the suite runner's verdict on that suite),
into FINDING rows alongside genuine failures — inflating a true 4-failing-suite run to 13
"confirmed findings," including a `[PASS]` row, so a FINDING row could no longer be trusted to
denote an actual failure.

## Measurement discipline: a cost claim is only as good as its load average

Any wall-clock cost figure cited as justification for a prioritization or scheduling decision
(which gate or suite to parallelize first, which to leave alone, what a cost class boundary
should be) MUST carry the 1-minute load average observed at measurement time, and a figure taken
while that load average exceeded the measuring host's declared idle threshold is INVALID for
that purpose until re-taken idle — not merely "probably a bit high."

This is not a style preference. A contended measurement is wrong in BOTH directions at once:
contention from unrelated concurrent work inflates a gate's or suite's own wall time (it is
sharing cores it was not designed to share), while a scheduler or parallel pool measured under
the same contention can appear artificially FAST relative to its true cost if the ambient load
happens to mask a real serialization point. Citing either shape of contaminated number as
evidence silently corrupts whatever decision depends on it — see `scripts/measure-gate-costs.sh`
(this task's own mechanical cost-model harness), which refuses to record a measurement outright
rather than merely flagging it, specifically guarding against both directions by checking the
load average both immediately before AND immediately after the measurement window, not only at
the start.

Concretely demonstrated live during this task: a full `verify-deploy.sh --only-gate 8` run (the
gate that itself wraps the complete `tests/run-all.sh` battery) took measurably longer than its
own cost model would predict, directly attributable to multiple concurrently-running sibling
`/orchestrate` sessions independently invoking their own `run-all.sh`/`verify-deploy.sh` work on
the same host during the measurement window — the exact contention mode this task's own dispatch
describes as its primary motivation. A number produced under those conditions, cited without its
load average, would have looked like ordinary data rather than the contaminated reading it was.

A cost-model regeneration run (`measure-gate-costs.sh`, with or without `--regen-hints`) always
prints its observed 1-minute load average to stderr, both in its guard messages and in the
generated file's own header comment, so the figure's provenance travels with it rather than
living only in the terminal scrollback of whoever happened to run it.

## Gate-level parallelism-safety audit (Phase 7)

Extends `run-all.sh`'s own documented suite-level audit (the `LOAD_SENSITIVE_BASENAMES` set and
its rationale, `## Suite runtime` above) to the gate grain, per
`scripts/lib/gate-registry-lib.sh`'s `gate_registry_exec_concurrent_batch` — the gate-level
worker-slot-pool scheduler this task's Phase 7 added, ported in shape from `run-all.sh`'s own
proven pool rather than inventing a parallel notion of this discipline.

**Method**: every one of `verify-deploy.sh`'s 23 migrated gate functions' bodies was read for a
fixed-path write, lock, or socket outside its own `mktemp`-scoped fixture — the exact class of
pairwise resource collision `run-all.sh`'s own audit checked for at the suite grain. **Result**:
none found. Every gate is read-only against its own `$TARGET` tree and/or the deployed `.claude/`
copy, with any scratch file routed through `mktemp`/`mktemp -d` (unique per invocation, never a
fixed name a sibling gate could collide on).

**The one exception, already declared data, not a new finding**: gate 8 (`gate-registry.data`'s
`serialized=true`, the only `true` among the 23) wraps the complete `tests/run-all.sh` battery,
which itself spawns up to `run-all.sh`'s own `JOBS_CAP` (4) further nested processes when it
requests `--jobs auto`. Running gate 8 concurrently with the rest of the pool would risk
multiplying ambient process/core pressure well past what either pool was individually sized for
— an AMBIENT-LOAD precaution, not a resource-collision requirement (gate 8 shares no fixed path
with any other gate either). `gate_registry_exec_concurrent_batch` runs every `serialized=true`
id alone, strictly before the rest of its wave's pool starts, mirroring
`LOAD_SENSITIVE_BASENAMES`'s own "always first, regardless of the pool's own schedule" posture
exactly.

**Two gates independently invoke headless `nvim`** (gate 5's `manager.verify_all`, gate 13's
`manager.find_orphans`) — each its own process, read-only against `$TARGET`, with no shared
fixed-path output. Both are pool members (not serialized): concurrent `nvim --headless` startups
cost real CPU/memory but collide on nothing gate-specific, the same ambient-vs-collision
distinction the serialized-gate-8 case above draws.

**A real scheduler bug this audit's own test coverage caught, recorded here since it is exactly
the kind of thing this audit exists to catch**: the worker-cap dispatch loop's longest-first sort
used a `mapfile -t ... < <(... | sort | awk ...)` process substitution; its own background reader
could still be unwaited in bash's job table when the dispatch loop's first `wait -n` ran,
occasionally letting `wait -n` reap that reader instead of one of the loop's own backgrounded
pool jobs — decrementing the active-worker count with no real job having finished, letting one
extra job launch past the declared cap (reproduced directly: 6 synthetic jobs at a declared cap
of 2 occasionally ran 3 concurrently, ~1-in-10 to 1-in-15). Fixed with a bare `wait` immediately
after the sort pipeline and before the dispatch loop begins. A NAIVE, non-atomic
read-modify-write test counter could only ever UNDER-count such a violation (never fabricate
one), so it masked the bug for several initial test runs — a `flock`-guarded atomic counter,
cross-checked against real start/end timestamp overlap, is what exposed it reliably. Any future
gate-level (or suite-level) worker-pool scheduler built on this same
`mapfile < <(pipeline)`-then-dispatch shape should drain the sorting pipeline with a bare `wait`
before its own cap-dispatch loop begins, for the identical reason.

## Gate 8's Wall-Clock Discrepancy: Root-Cause Verdict

Gate 8 (`verify-deploy.sh`'s wrapper around `tests/run-all.sh --jobs auto`) was once measured,
idle, at 457,197ms against an earlier projection of roughly 103s — a 4.4x gap. Three candidate
causes were named for this gap (the suite pool is larger than `suite-cost-hints.txt` knew; the
parallel path is not delivering the concurrency the scheduler believes it requests; `JOBS_CAP=4`
binds harder than expected), plus a fourth, structural one the gate tree's own shape invites: a
suite inside gate 8 re-enters `verify-deploy.sh` wholesale.

**Suite-pool size (re-derived mechanically, not assumed)**: `run-all.sh`'s own discovery finds
151 suites today; `suite-cost-hints.txt` carries 148 hinted rows. The 3 unhinted suites
(`test-check-record-versioning.sh`, `test-gate-registry-resolution.sh`,
`test-lint-shellcheck-parallel.sh`) are a 2% gap, not a dominant one — this candidate is a minor
contributor at most.

**Scheduler concurrency (tested directly, host-load-independent)**: a synthetic probe of N
trivial suites (each a bare `sleep 6; exit 0` — CPU-contention-immune, since `sleep` is a kernel
timer wait, not CPU work) run through the unmodified scheduler at `--jobs 4`, `--jobs 8`,
`--jobs 12`, and `--jobs auto` reproduces the exactly-predicted wall clock for true N-way
concurrency every time: 8 suites at `--jobs 4` complete in ~14s (2 waves of 6s, matching `8/4=2`),
12 suites at `--jobs 8` complete in ~15s (2 waves, `12/8`→2), 12 suites at `--jobs 12` complete in
~9.5s (1 wave), and 12 suites at `--jobs auto` complete in ~21s (3 waves, `12/4=3` — confirming
`auto` resolves to the `JOBS_CAP` of 4, not `nproc`). The scheduler's worker pool delivers exactly
the concurrency it requests, every time measured. **This candidate is refuted**: the dispatch
mechanism itself is not the gap's source.

**`JOBS_CAP=4` and the real suite-cost distribution**: the hinted suites' wall-clock sum is
1,038,445ms. A perfectly load-balanced 4-way split would land near `1,038,445/4 ≈ 259,611ms` —
but the single most expensive suite, `test-verify-deploy-context-budget.sh`, is hinted at
228,595ms alone: 22% of the entire 151-suite serial sum, on its own nearly as large as the
4-way-ideal wall clock for the *whole pool*. The second- and third-largest suites
(`test-verify-deploy-gate-selection.sh` at 160,340ms, `test-orchestrate-cycle-plan.sh` at
106,551ms) each occupy a worker slot for a large fraction of the run regardless of how well the
remaining small suites are packed. The realized idle speedup (`1,038,445 / 457,197 ≈ 2.27x`)
falls well short of a naive 4x precisely because 3 of the 4 worker slots are bound to large,
mostly-serial items for most of the run — `JOBS_CAP` is a real, binding constraint on this
specific suite-cost distribution, but raising it mainly buys slack for the *small* suites; it
does not shrink the big stragglers' own wall-clock floor.

**The recursive component (the suite that dominates the gap)**: `test-verify-deploy-context-budget.sh`
invokes `$VERIFY_DEPLOY` at exactly 3 call sites (not the 12 a bare `grep -c "verify-deploy.sh"`
returns — that count includes comments, header prose, and a binary-existence check). Of those 3,
only ONE (the suite's own "baseline" check) is a full-battery `--skip-slow` invocation that
re-pays gate 3 (~125s) and gate 22 (~55s) against the fixture on every run; the other two
call sites (`run_gate20()`, invoked across a 3-iteration mode loop, and one `deploy_findings_snapshot`
call) are deliberately scoped via `--only-gate 20` and do not re-pay gate 3 or gate 22 at all.
This single full-battery call site is why one suite alone (228,595ms hinted; 230,291ms measured
under contention) accounts for roughly a fifth of gate 8's entire discovered-suite-pool cost, and
it is a structural property of the gate tree re-entering itself — no amount of worker-level
`JOBS_CAP` tuning shrinks a suite whose own cost is dominated by one nested full
`verify-deploy.sh` pass.

**Verdict table**:

| Candidate | Verdict | Evidence |
|---|---|---|
| 1. Suite pool larger than hints knew | Minor contributor | 151 discovered vs. 148 hinted (2% gap) |
| 2. Parallel path not delivering requested concurrency | Refuted | Synthetic sleep-probe reproduces exact N-way wall clock at `--jobs 4/8/12/auto` every time |
| 3. `JOBS_CAP=4` binds harder than expected | Supported, but not the proximate cause | Realized 2.27x vs. naive 4x; 3 of 4 slots pinned by 3 large suites for most of the run |
| 4. Gate tree re-enters itself (not originally named; structural) | Primary root cause | One suite's one full-battery nested `verify-deploy.sh` call is ~22% of the entire 151-suite serial-cost sum, by itself |

**Measurement caveat**: a from-scratch idle (`load < 2`, Phase 1 harness-gated) re-measurement of
gate 8 at `--jobs auto` was attempted twice during this work and both attempts were contaminated
mid-run by concurrent, unrelated sibling activity on the same host (1-minute load rose to 4.7–9.0
during the run; the harness correctly marked both samples `ALL_VALID=false` and refused to treat
them as trustworthy). The contaminated samples (611s, 634s, and a third `--timings`-instrumented
run at 626s) are directionally consistent with the standing 457s idle figure (all three are
higher, consistent with added contention, not a step-change) but are not themselves evidence for
a revised cost-class boundary. The scheduler-concurrency and suite-cost-distribution findings
above do not depend on host idleness (a `sleep`-based probe and a hinted-cost-sum comparison are
both load-independent) and stand on their own.

## Related

- `context/standards/testing.md` — a generic JS/AAA-pattern testing primer. It predates this
  convention, covers a different language and pattern (unit-test frameworks, mocks), and is not
  superseded by this doc; the two are complementary; cross-reference rather than merge.
- `context/standards/census-methodology.md` — the standard method for deriving and cross-checking
  repo-wide counts. Its shipped tooling and fixture suite follow this doc's conventions.
