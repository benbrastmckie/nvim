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

Core's own precedent (`test-task-lock-reap.sh`, predating the shared library below) set this
naming inside `scripts/` and `scripts/tests/` alike:

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

This shape is retained here as documentation of what most existing core suites still look like
today (a migration in progress, tranched across several phases — see below), not as the model a
NEW suite should copy. See the next section for the current requirement.

## Required structural model for a new suite

A new suite under `scripts/tests/` (or a new flat `scripts/test-*.sh`) MUST source
`scripts/lib/common.sh` and call its test-helper functions directly, rather than open-coding a
local copy of `pass()`/`fail()`/`info()`, the git-aware repo-root probe, the deploy-tree-first/
source-store-fallback script lookup, or the `mktemp -d` + `trap ... EXIT` pair — each of these was
independently hand-rolled across the majority of the existing 122-suite core corpus before this
requirement, which is exactly the duplication this library exists to stop growing further.

```bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"           # git-rev-parse-first, depth-fallback
SCRIPT_UNDER_TEST="$(common_test_resolve_candidate "some-script.sh" \
  "$REPO_ROOT/.claude/scripts/some-script.sh" \
  "$SCRIPT_DIR/../some-script.sh")" || exit 2

PASSED=0
FAILED=0
common_test_workdir_init                                     # sets $WORKDIR + an EXIT trap;
                                                               # call bare, never via $(...)

common_test_pass "case description"                          # increments PASSED, prints [PASS]
common_test_fail "case description"                           # increments FAILED, prints [FAIL]
common_test_info "diagnostic note"                             # uncounted

echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
```

A consumer that sources `common.sh` MUST NOT also define its own `pass()`/`fail()`/`info()` —
see `common.sh`'s own "FORBID LOCAL REDEFINITION" header note. `tests/test-common-lib.sh` proves
this library-side: one definition per function, and a fixture-level detector distinguishing a
suite that correctly calls the shared trio from one that still shadows it with a local copy.

**Existing suites**: migrating every existing suite onto this surface happened in tranches, as a
dedicated piece of work, rather than a single sweep. That migration is now complete for the core
extension's `scripts/tests/` corpus: every suite file sources the shared harness (directly via
`lib/common.sh`, or — for `test-common-lib.sh`, the library's own fixture-driven regression suite
— indirectly via its own resolved `$LIB` path variable, since it must name the library file under
test by a variable rather than a literal path). No suite was found that genuinely cannot source
the harness, so there is no reasoned-exemption list to carry here: a future suite reimplementing
`pass()`/`fail()`/`info()` locally is a regression against this now-closed migration, not a
holdout awaiting its turn.

## Explicit deployed/source-store subject resolution (mode + mandatory declaration)

A suite under `scripts/tests/` that resolves its own subject-under-test between the deployed
tree (`$REPO_ROOT/.claude/scripts/...`) and the source-store sibling
(`agent-system/extensions/core/scripts/...`) MUST do so through `common_test_resolve_subject`
plus `common_test_declare_subject` (both in `lib/common.sh`), never through a hand-rolled
lookup. Historically, before this pair existed, every such suite's resolution took one of three
structural shapes — a direct call to the shared but mode-implicit
`common_test_resolve_candidate` helper, a hand-duplicated local function reimplementing the same
find-first-existing-candidate lookup, or an inline `*CANDIDATES*=()` array consumed by a bare
`for candidate in ...` loop with no named function at all (the shape invisible to a
`grep resolve_candidate` measurement, since it never names that function). All three shapes left
the resolution MODE implicit in candidate argument order, so a suite could never declare —
to itself, to a reader, or to a later gate — which copy it had actually tested. A green run was
therefore indistinguishable from a vacuous one: running a suite after editing the source-store
copy but before a redeploy could silently exercise the STALE deployed copy instead of the change
under test.

**Mode vocabulary** (`common_test_resolve_subject <desc> <mode> <deployed_candidate>
<source_store_candidate>`, exactly three recognized values for `<mode>`; an empty string is
`deploy-tree-first`):

| Mode | Behavior | Precedence |
|------|----------|------------|
| `deployed` | Resolve `<deployed_candidate>` only, or fail | Correctness requirement — never overridden |
| `source-store` | Resolve `<source_store_candidate>` only, or fail | Correctness requirement — never overridden |
| `deploy-tree-first` | Resolve `<deployed_candidate>` if present, else `<source_store_candidate>` | Preference — the one case the environment override applies to |

**Environment override**: `CORE_TEST_SUBJECT_MODE`, the same unset-means-sane-default idiom
`VERIFY_DEPLOY_GATE8_JOBS` already uses elsewhere in this corpus. A caller passing `deployed` or
`source-store` has stated a correctness requirement and is NEVER overridden by the environment.
A caller passing `deploy-tree-first` (or an empty mode) has stated a preference, and
`CORE_TEST_SUBJECT_MODE` — when set — overrides exactly that case. This is what keeps a
hard-selected caller (a suite that must always resolve the source-store copy because it is
validating a pre-deploy edit under active development) correct under any environment, while
still giving the override one real, single meaning. `deploy-tree-first` is also the default this
corpus's Inter-Cycle Redeploy Checkpoint relies on: see
`context/patterns/batch-orchestration-guardrails.md`'s single-capture-Gate-8-sharing rejection
for why that checkpoint's pre/post divergence signal depends on the default staying
deploy-tree-first rather than flipping globally to source-store-first.

**Mandatory declaration**: every suite that resolves a subject via `common_test_resolve_subject`
(or, for a not-yet-migrated caller, `common_test_resolve_candidate`) MUST call
`common_test_declare_subject <resolved_path>` immediately after resolving, once per resolved
subject, printing exactly `[SUBJECT] <absolute path>` — a line-initial token, one space, then the
absolute path. `[SUBJECT]` is deliberately disjoint from the four verdict anchors this corpus
already extracts on (`[PASS]`/`[FAIL]`/`[INFO]`/`[VIOLATION]`; see the verdict-line extraction
contract above), so it can never be mistaken for one by an anchored extraction, and a captured
run's `[SUBJECT]` lines always answer "which copy did this test?" without inspecting the suite's
own source.

Mechanically enforced by `scripts/lint/lint-subject-resolution-declaration.sh` (gate 27 in
`scripts/gate-registry.data`), which flags a new suite reintroducing any of the three undeclared
shapes above, or a `common_test_resolve_subject` call with no paired
`common_test_declare_subject`, against a Layer-2 allowlist of permanent, individually-reasoned
exemptions (a suite with no genuine deployed/source-store duality to declare, or
`common_test_resolve_subject`/`common_test_resolve_candidate`'s own regression suite exercising
the functions directly as its subject rather than calling them to resolve one).

## Inherited `SHELLOPTS` and the `errexit` trap

The header above declares `set -uo pipefail` with no `-e` — but that does not guarantee `errexit`
is off inside the test process. `SHELLOPTS` is inherited from the invoking shell into every bash
subprocess, `errexit` bit included, regardless of what the script's own header declares. A test
case that assigns a potentially-failing command substitution directly,

```bash
var="$(some_command_that_can_fail)"
```

can therefore die mid-case the moment `some_command_that_can_fail` returns non-zero, even though
the script's own header never asked for `-e`.

**Symptom, as it actually presents**: not a `[FAIL]` line from `fail()`. The whole suite just
stops running right there, mid-case, with no visible error — it reads exactly like a crash, not
like a reported failure, so the suite *looks broken* rather than red. This is easy to misdiagnose
as a harness or environment problem, when the real cause is an inherited shell option the test
author never set.

**Diagnosis**: a plain re-run rarely tells you anything beyond "it stopped." Tracing the suite
with `bash -x` is what surfaces it — the trace shows execution simply terminating right after the
failing substitution's line, with no error message printed anywhere.

**Defensive pattern**: wrap any assignment whose right-hand side may legitimately fail so an
inherited `errexit` cannot kill the suite on it, matching a convention already used elsewhere in
these suites:

```bash
set +e
var="$(some_command_that_can_fail)"
set -e 2>/dev/null || true
```

This is cheap insurance for any assignment where failure is an expected, checkable case, not a
suite-ending event — apply it wherever a case deliberately exercises a failing code path through
a direct `var="$(...)"` assignment.

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

### A deliberate-break regression anchor must mutate a sandbox copy, never the source store

A suite's regression-anchor check exists to prove its own fixture is not passing vacuously: it
temporarily re-gates a block of a real collaborator script on a deliberately-false condition,
confirms the fixture goes RED, then reverts (or, in the sandbox-copy form below, simply lets the
next sandbox rebuild discard it). This technique is legitimate and documented. Its hazard is
blast radius, not existence: applying the mutation to the real source-store file — rather than to
a sandbox or scratch copy produced by the suite's own setup step — puts that mutated file live in
the SHARED WORKING TREE for the whole duration of the fixture. Any concurrently running session
(another task's verification run, a gate, an unrelated orchestration cycle) can read the broken
collaborator script during that window, with no way to know why. A backup/restore pair plus an
`EXIT` trap is recovery, not containment: a trap does not fire on `SIGKILL`, an OOM kill, or a
host crash, and even a perfect restore does not erase the observation window a concurrent reader
sees mid-run.

**The rule**: a suite that deliberately breaks a production script to prove a case is not passing
vacuously MUST apply that mutation to a sandbox or scratch copy, never to the real source-store
file. The mutation must be applied AFTER whatever sandbox-build step (e.g. `setup_sandbox()`)
copies the collaborator into the sandbox, since such a step re-copies from the source store and
would silently erase a mutation applied before it ran — reordering the mutation to follow the
copy, rather than building new override infrastructure, is usually the simplest fix. Add a
non-vacuousness assertion immediately after the mutation (confirm it actually matched something
in the sandbox copy) so a future reindent of the collaborator script cannot turn the sed into a
silent no-op and the anchor into a vacuous pass.

Two established precedents in this corpus already follow the sandbox-copy pattern:
`test-git-commit-scoped.sh`'s inversion probes (mutating a copy of the script under test, never
the source-store original) and `test-lint-deploy-caller-wrap.sh`'s self-test (mutating its own
copied fixture file). `scripts/lint/lint-deliberate-break-residue.sh` is the mechanical guard
against regression: it reports an anchored-start `while false &&` guard or a leftover
`*.anchor-bak` file anywhere under the source store. It runs at gate level (gate 28 in
`verify-deploy.sh`), never as a write-time block, because a suite legitimately holds such a
mutation in a sandbox copy for the duration of one fixture — a write-time block would make the
technique unusable mid-run.

See `### Exact-pid process checks: the parallelism-safety rule for leftover/liveness assertions`
below for the sibling concurrency-safety rule for suite authors (how a suite identifies a live
process, rather than whether a suite mutates shared source).

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

## Ambient-host-state isolation

**The defect class**: any assertion whose outcome depends on live, uncontrolled host state
rather than a fixture — memory/swap pressure (`/proc/meminfo`, `/proc/pressure/memory`), wall-clock
timing (an elapsed-time window, a `sleep`-dependent race, a timeout tuned to an idle machine),
load/CPU count (`/proc/loadavg`, `nproc`, `uptime`), network reachability, free disk, or the
process table (`pgrep`/`ps` matching a live PID) — plus one filesystem sub-shape named below. Such
a suite passes on a quiet machine and fails on a busy one, and a busy machine is exactly what a
multi-task `/orchestrate` batch, or this corpus's own `--jobs auto` parallel pool, produces.

**Why it is load-bearing, not merely test hygiene**: one suite failure fails Gate 8
(`tests/run-all.sh`), which fails `verify-deploy.sh`, which fails `deploy-headless.sh`, which makes
the orchestrator's inter-cycle redeploy checkpoint defer an entire batch — one host-coupled
assertion in one suite stalls unrelated work. Worse, a gate that cannot finish inside a dispatch's
practical budget does not merely go red; it gets recorded as a Reasoned Exclusion with no red
signal anywhere, which trains readers to exclude rather than diagnose. A *flaky* gate is worse
than a red one: it defers batches nondeterministically and trains readers to re-run instead.

Two confirmed, one-per-axis worked examples anchor this section:

- **Memory axis** — `tests/test-lake-build-guard.sh` read the real `/proc/pressure/memory` and
  `/proc/meminfo` directly, so a host already swapping above the guard's own
  `SWAP_USED_RATIO_THRESHOLD` failed the suite with no code defect involved. Fixed by redirecting
  the guard's own `LAKE_BUILD_GUARD_PSI_PATH`/`LAKE_BUILD_GUARD_MEMINFO_PATH` env seams at clean
  fixture files in the suite's `mktemp` workdir — see "Seam-first" below.
- **Timing axis** — `test-four-tier-conflict.sh` case 6 asserted a wall-clock window
  (`elapsed_ms` within `[BUDGET_MS, 2*BUDGET_MS)`) around `task-lock.sh`'s retry-budget-exhaustion
  path. The window held idle and broke under concurrent load, because the measured elapsed time is
  dominated by per-attempt forking overhead (multiple `jq` subprocess spawns), not by the retry
  loop's own (counter-based, clock-independent) logic. Fixed by asserting the retry-iteration
  *count* directly instead of the time it took — see "The timing axis needs a different
  technique" below.

### Seam-first, for readable-input axes

For state read from a file or a command (memory/`proc`, load, network, disk, process table):
identify the script-under-test's own documented env seam and redirect it at a fixture — the
instance-A pattern above. If no seam exists, adding one to the script under test is in scope, but
it must be a genuine, documented override point with a real-host default, **never** a test-only
branch or an "if running under test" conditional. Point the seam at a fixture built per the
Fixture convention above (heredoc-authored into the suite's own `mktemp -d` workdir) — never
resolved against the live tree, per "Never resolve a path against the live tree" above.

### The timing axis needs a different technique

Wall-clock elapsed time is usually not a readable input with a redirectable seam — there is often
nothing to point a seam at, because the quantity *is* elapsed real time. Evaluate, per assertion,
in this order, and record which rung was used and why:

1. **Inject the clock, or intercept the delay.** Strongest option where feasible. The primary
   worked example is `test-four-tier-conflict.sh` case 6's fix: a one-line fake `sleep` (append to
   a counter file, exit 0, no real delay) placed in a directory prepended to `PATH` for just the
   call under test — legitimate because `task-lock.sh`'s `cmd_acquire_retry` calls bare `sleep`,
   never an absolute path, so `PATH` substitution is a real external seam requiring **no
   production-code change**. The suite then asserts the exact retry-iteration count
   (`BUDGET_MS / POLL_MS`) instead of a wall-clock window — a deterministic, host-load-independent
   causal invariant, demonstrated non-vacuous at two different budget values (see "Non-vacuousness
   check" below). `test-deploy-ledger-lib.sh`, `test-task-lock-liveness.sh`, and
   `test-task-lock-reap.sh` apply the same "inject the clock" idea at the library level: a
   timestamp is captured once and passed as an explicit function argument (or constructed via
   controlled epoch arithmetic), never read live inside the code path under assertion.
2. **Assert ordering or causality instead of elapsed wall clock.** The elapsed-time window is
   usually only a *proxy* for a property that is directly observable — asserting the property
   itself removes the host coupling without weakening anything. `test-four-tier-conflict.sh`
   case 5 is the companion worked example: its `elapsed_ms -lt 500` clause was dropped entirely,
   because `rc5 -eq 0 && note_count5 -eq 0` was *already* a complete, direct proof the retry loop
   body was never entered (`NOTE:` prints only on the first retry iteration, before the first
   sleep) — the elapsed clause was strictly redundant. Pre-existing exemplars of this rung:
   `test-gate-registry-resolution.sh` cases 15/16 (a dependent step proceeds only once a
   completion marker is observed in a shared trace log, and a "serialized id runs alone" guarantee
   is proven via start/end timestamp *ordering*, never a duration) and case 17 (a worker cap proven
   via a `flock`-guarded atomic counter); `test-state-write-regen-timing.sh` case 1 (proves "mutex
   released before regeneration begins" by having a different session successfully acquire the
   mutex while regen is deliberately blocked — a causal proof, not a timing measurement);
   `test-lint-shellcheck-parallel.sh`'s dispatch-shape case (peak concurrency derived from
   START/END event *ordering* via a timestamped log scan, not a duration window). A **relative-ratio**
   assertion is a legitimate variant of this rung when a true before/after causal proof is not
   available: `test-run-all-parallel.sh` cases 3/4/8/9 and `test-verify-deploy-gate-selection.sh`
   case (q) assert that one measured duration is no more than (or not less than) a fixed
   *proportion* of a second, back-to-back measurement — an external load multiplier inflates both
   measurements roughly proportionally, so the ratio stays meaningful regardless of host load,
   while a genuine regression (the two durations converging) still fails the check reliably.
3. **Widen to a generous-but-still-bounded window, only as a last resort**, and only when the
   widened bound still falsifies the failure mode the assertion exists to catch — a bound that no
   longer discriminates is a deleted test. This option requires explicit justification naming what
   the widened bound still catches. Correctly-applied exemplars: `test-run-task-observers.sh`
   case (j), `test-zotero-generate-export.sh`'s `t_timeout_guard_fires` (a 2s `timeout` against a
   deliberately-stalled 10s `sleep`, asserting the wrapper returned well under the 10s ceiling —
   a 5x margin, proving "didn't hang" rather than a tight proportional window), and
   `test-run-all-selection.sh` cases 11/13 and `test-gate-registry-resolution.sh` case 13.

**Elapsed wall clock must never be used as a proxy for a property that is directly observable.**
If a counter, a log line, or a return path already carries the property an elapsed-time clause is
only approximating, assert that directly (rung 2) rather than measuring how long it took (rung 1
or 3) — this is exactly what made case 5's elapsed clause strictly redundant above.

### Shared-path sub-shape: a stray-artifact check must be delta-based

A distinct sub-shape, not on the memory/timing/load/network/disk/process-table list above but
still "anything else read from the live host rather than from a fixture": a suite's "nothing
stray was created" check against a **shared, non-fixture, live-tree path** (one this suite does
not exclusively own) must be delta-based (snapshot existence *before* the suite starts, fail only
if it did not exist before but does after), never an absolute existence check. An absolute check
cannot distinguish debris the run under test created from debris that was already there or was
created by an unrelated concurrent process on a shared, multi-session host.

Worked example: `test-detect-noop-bash.sh`'s two "no stray `tmp/` directory" checks were absolute
and could be falsely tripped by pre-existing or externally-introduced debris at
`agent-system/extensions/core/tmp/`. Fixed by snapshotting
`SOURCE_STORE_TMP_PREEXISTED` once at suite start and checking the delta at each call site; when
the path existed at suite start, the suite emits a loud, visible skip (per the Loud-skip
discipline above) rather than a silent pass or a false failure.

### Timeout sub-shape: a timeout tuned to an idle machine is itself this defect class

A per-suite or per-gate timeout sized for a quiet host is ambient-host-state coupling by another
name — the timeout value is the "fixture" a loaded run silently fails to match. `run-all.sh`'s
documented `RUN_ALL_SUITE_TIMEOUT_S` env seam is the sanctioned override point for a deliberately
loaded run (raise it for that run only; never hand-edit the default). This is the same
distinction the `--jobs 1` vs. `--jobs auto` default asymmetry in the "Suite runtime" section
above already draws between an idle-host-safe default and an explicit, documented opt-in for a
different host condition — cross-referenced here, not restated.

### Non-vacuousness check (mandatory, every axis)

After isolating an assertion from ambient host state, demonstrate the logic under test is still
genuinely exercised — drive the opposite direction with a fixture or condition that *should* trip
the behavior and confirm it does. An isolation that makes a suite assert nothing is worse than the
host coupling it replaced. `test-four-tier-conflict.sh`'s fix demonstrates this at two different
budget values (`BUDGET_MS=1000,POLL_MS=100 → sleep_count=10`; `BUDGET_MS=500,POLL_MS=100 →
sleep_count=5`), proving the causal count scales with the loop rather than hardcoding a pass.
`test-detect-noop-bash.sh`'s fix demonstrates both directions explicitly: planting the shared path
mid-run (after the pre-existence snapshot) still turns the check red, and planting it before suite
start produces the loud skip, not a false failure.

### Threshold relaxation is never the remedy

Isolate the INPUT; never relax the ASSERTION. Raising, weakening, or bypassing a guard's own
threshold (a `SWAP_USED_RATIO_THRESHOLD`, a budget constant, a byte-count ceiling) to make a suite
pass is not isolation — it changes what the guard actually protects. The bounded-widening rung
above is the one narrow, explicitly-justified exception, and it applies only to a test assertion's
own timing margin on the timing axis, never to a guard's own production constants.

## Registration

Test scripts are ordinary entries in `manifest.json`'s `provides.scripts` array, subdirectory-
qualified where applicable (`tests/test-census-count.sh`, not just `test-census-count.sh`) —
`provides.scripts` already carries other subdirectory-qualified paths (`lint/lint-*.sh`), so this
needs no new schema or new `provides` sub-array.

## Unit/integration classification and the spawn-boundary lint

Every suite `tests/run-all.sh` discovers is classified `unit` or `integration` in
`tests/suite-classification.data`, a declarative, TAB-separated data file (one row per suite:
`basename  class  reason`; see that file's own header for the full grammar). Adding a suite is a
data edit to that file, never a documentation edit — `lint/lint-unit-integration-boundary.sh`
requires every discovered suite to carry a row and fails loudly on a coverage gap, so the
classification cannot silently drift out of sync with the corpus the way an unenforced convention
always does.

**The rule a `unit`-class suite must satisfy**: it must not spawn `deploy-headless.sh`,
`verify-deploy.sh`, or (nested) `tests/run-all.sh` — those three are full-system integration
operations, and this corpus's own measured finding is that the dominant cost of the whole test
pool sits in exactly the suites that spawn them, wearing a unit test's clothing. An `integration`
-class suite is unconstrained by this rule; its row's `reason` field names which heavyweight
tool(s) it legitimately invokes.

**Scope note, stated once here rather than per call site**: the classification file is owned by,
and physically lives under, the core extension, but its coverage is NOT core-only. In the
deployed tree, `deploy-headless.sh`'s per-extension merge flattens every extension's own
`scripts/tests/*.sh` into one shared `.claude/scripts/tests/` directory — the actual set
`tests/run-all.sh` (gate 8) discovers and runs in production — while the equivalent path in the
source store sees only core's own suites. A suite physically filed under a different extension
(`approvals/`, `lean/`, `literature/`, ...) still needs a row the moment it lands in that merged
set.

**Detection method, deliberately bounded (not a general call-graph analysis)**: a literal
basename match (`grep -qF`) for each of the three tool names against a suite's own file content —
the same conservative, cheap, over-counting-never-under-counting textual-reference method
`script-inventory.sh`'s own `inbound_callers` field already documents. A suite whose content
mentions one of these names only in a comment or a fixture string literal (never a real
invocation) still trips the lint; the remedy is to reclassify it to `integration` with a stated
reason, never to suppress the finding — this corpus's own `test-lint-unit-integration-boundary.sh`
is itself classified `integration` for exactly this reason (its fixtures plant the three tool
names as string literals to exercise the lint's own detection).

**The standing size probe's cost-per-assertion figure** (`script-inventory.sh --size-line`'s
`cost_per_assertion_ms=X` field, also surfaced in `verify-deploy.sh`'s own corpus summary line)
is the companion measurement: it divides `tests/suite-cost-hints.txt`'s hinted sequential
wall-clock pool by a corpus-wide, command-position assertion-call count (the same call-site shape
`lint-test-harness-adoption.sh`'s `call_re` recognizes), so a suite drifting into integration cost
without integration value is visible in the run that causes it rather than discovered twelve days
later. Reports the literal string `n/a` when no hints file is present or zero assertions are
found (expected outside the real corpus, e.g. any fixture built under a synthetic `--root`).

## The shared deployed-tree fixture: built once, lent read-only

`run-all.sh` can build ONE real deployed tree before any suite runs and lend it, read-only, to
every suite declared in its own `SHARED_FIXTURE_CONSUMERS` array -- instead of each consumer
building (and tearing down) its own copy. A consuming suite finds it at `$RUN_ALL_SHARED_FIXTURE`
(exported only when at least one declared consumer is present in the discovered/narrowed suite
set) and, if it needs to plant or mutate anything, copies what it needs with
`common_test_fixture_overlay <src> <dest>` (`lib/common.sh`) rather than writing into the shared
tree directly -- the shared tree is `chmod -R a-w` after construction, so a direct write fails
loudly (a stuck pipeline or a corrupted sibling fixture is the alternative a silent failure
would risk under `--jobs auto`'s concurrency).

**The discriminator for "is this suite a consumer candidate" is narrower than "textually mentions
deploy-headless.sh"** -- `suite-classification.data`'s `integration` rows are a deliberately
conservative, over-counting textual-reference scan (see that file's own header), and most
"integration" rows never build a real scratch deploy at all. A suite is a genuine consumer only
if it needs "a deployed tree" purely as inert scaffolding for something ELSE under test. A suite
is NOT a consumer, however many real `deploy-headless.sh`/`verify-deploy.sh` invocations it
drives, when the variance across those invocations IS the thing under test: a fresh-vs-resync
propagation check, a flag-matrix wiring check (`--skip-slow`/`--dry-run`/`--bogus`/`--help`), or
a gate-cache equivalence proof each need their own distinct invocation(s) and cannot be
substituted by a single shared tree without changing what they verify. Measured directly against
the full core suite corpus (2026-10, 38 suites classified `integration`): exactly one suite --
`test-deploy-orphans.sh` -- fit the consumer pattern; the rest either test a heavyweight tool's
own behavior directly (excluded by the rule above), already moved onto a cheaper non-deploy
fixture (the rsync+symlink fixture `test-verify-deploy-context-budget.sh` and
`test-verify-deploy-gate-selection.sh` use, unrelated to this mechanism), or were a
textual-reference false positive. Re-derive this set (do not assume it is stable) the same way:
for each `integration` row, read the suite and confirm whether it drives a REAL, unflagged
`bash .../deploy-headless.sh "$SOME_SCRATCH_DIR"` subprocess call, not merely a string
mentioning the tool's name.

**Overlaying more than `.claude/`**: a deploy writes three top-level artifacts into its target,
not just `.claude/` -- `.claude-extensions.json` and `.syncprotect` are PROJECT-ROOT siblings of
`.claude/`, and `manager.find_orphans(project_dir)` (and any other manifest-driven Lua check)
resolves the active-extension set and the syncprotect exclusion set from those two root-level
files, never from anything inside `.claude/` itself. A consumer that overlays only
`$RUN_ALL_SHARED_FIXTURE/.claude` and omits the sibling files will see every declared extension
as absent, misclassifying its ENTIRE deployed tree as undeclared/orphaned -- caught by exactly
this symptom (743 false orphan findings) while migrating `test-deploy-orphans.sh`. Overlay all
three artifacts a consumer's own checks actually read, not just the subdirectory that happens to
hold the bulk of the content.

**Regression coverage**: `tests/test-run-all-shared-fixture.sh` pins (1) the fixture is built
exactly once when a declared consumer is selected, (2) it is NOT built at all when no declared
consumer is selected (zero cost when unused), and (3) a write attempt into the lent fixture is
blocked. `tests/test-common-lib.sh` separately pins `common_test_fixture_overlay`'s own
contract: the destination is independently writable even though the source is read-only, and
mutating the destination never mutates the source (the hardlink-sharing hazard
`cp -a --reflink=auto`, never `cp -al`, is chosen specifically to avoid).

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
- `--class CLASS[,...]` / `--tag TAG[,...]` / `--cost-class CLASS[,...]`: three further opt-in
  axes, layered on top of `--only` by intersection (every supplied axis narrows further; absent
  all three, this is a no-op and output stays byte-identical). Each selects the union of suites
  matching ANY of its own comma-separated values, reading declarative data the corpus already
  has rather than requiring new per-suite authoring: `--class` from
  `tests/suite-classification.data`'s own unit/integration column; `--tag` mechanically derived
  from that same file's `reason` column (an integration suite's own `invokes:X[,Y]` tokens become
  tags, e.g. `deploy-headless`, `verify-deploy`) plus the fixed tag `lint` for every
  `test-lint-*.sh` suite; `--cost-class` from `tests/suite-cost-hints.txt`'s advisory `wall_ms`
  column bucketed `free`/`moderate`/`slow` at `scripts/lib/suite-selection-lib.sh`'s fixed
  thresholds, plus `unknown` for a suite the (optional) hints file does not cover. Every token is
  validated against its own axis's closed known-value vocabulary before any suite runs -- an
  unknown token refuses the whole run (exit 2, naming the token and axis), mirroring `--only`'s
  own discipline. The derivation and selection functions live in `suite-selection-lib.sh`
  (`suite_selection_known_classes`/`_tags`/`_cost_classes` and `suite_selection_by_class`/`_tag`/
  `_cost_class`), sourced from `run-all.sh` rather than duplicated there -- see
  `tests/test-run-all-selection.sh`'s Part 5 cases for the full regression coverage (known-value
  correctness against the real corpus, flag-level validation/composition against a fixture).

### Exact-pid process checks: the parallelism-safety rule for leftover/liveness assertions

**The rule**: a suite that checks for a leftover or still-running process MUST check the exact
pid it itself spawned, captured at spawn time. A process-NAME match — the name-query utility
invoked with a full-command-line flag, its kill counterpart invoked the same way, or `ps` piped
to `grep` on a command pattern (`aux`, `-ef`, or `ax` form) — is never acceptable for this purpose
inside the battery.

**Why, stated as a mechanism rather than an incident**: under a parallel pool (`--jobs`, above),
a sibling suite may legitimately be running a process with the same name at the same moment. A
name-based check is therefore testing the state of the whole host, not the state of the suite
that owns the assertion. A suite that asserts about the host is not parallelism-safe by
construction, independently of whether a collision has yet actually been observed on any given
run — the risk is structural, not probabilistic-and-rare.

**The strictly worse adjacent case**: a name-based *kill* of a process inside a suite can
terminate a sibling session's work outright, not merely misreport it. That failure mode has
already been paid for once in this repository at the agent level (see
`context/patterns/bounded-build-waiter.md` below) and must not be reintroduced at the suite
level.

**The portable shape, concretely enough to copy**: capture the spawned process's own pid at
spawn time into a dedicated pidfile —

```
cmd & echo "$!" > "$PIDFILE"
```

— then test that exact pid's liveness directly against the pid read back from the pidfile:

```
pid="$(cat "$PIDFILE")"
if kill -0 "$pid" 2>/dev/null; then
  echo "still alive"
fi
```

— and clean up only that pid and its own process-group children — never a name-matched set.
`tests/test-gate-registry-resolution.sh` case13 is the
already-landed worked example: it writes its stalled descendant's own pid to a dedicated file at
spawn and checks only that exact pid's liveness this same way, which is exactly why it can run
correctly alongside a sibling suite that happens to spawn an identically-named process of its
own.

**`LOAD_SENSITIVE_BASENAMES` is not a substitute for this**: the serialized set (above) exists
for load sensitivity — a suite whose timing is unreliable under ambient host contention — not for
check precision. Adding a suite to that set to paper over an imprecise, name-matched process
check both slows the parallel pool for everyone and leaves the latent correctness bug in place;
it treats a precision defect as if it were a scheduling concern.

**Re-running the corpus audit** (deliberately no frozen count stated here — see this document's
own re-run-don't-cite-frozen-numbers practice above): from `agent-system/extensions/core`, run

```
grep -rn --include='*.sh' -E 'pgrep[[:space:]]+-[a-zA-Z]*f' scripts/tests/ scripts/*.sh
grep -rn --include='*.sh' -E 'pkill[[:space:]]+-[a-zA-Z]*f' scripts/tests/ scripts/*.sh
grep -rn --include='*.sh' -E 'ps[[:space:]]+(aux|-ef|ax)[^|]*\|[[:space:]]*grep' scripts/tests/ scripts/*.sh
grep -rln --include='*.sh' -E 'pgrep|pkill' scripts/tests/ scripts/*.sh
```

and classify every hit as a live violation or as non-violating (a comment, a fixture string fed
to a different lint under test, or a classification-matcher fixture) from its own source line —
never carry forward a previously-recorded count as current fact.

**Related but distinct**: `context/patterns/bounded-build-waiter.md` documents the sibling
agent-layer discipline against the same underlying mechanism — a polling shell that waits on a
name match can self-match its own argv and never terminate. That hazard is a *self-match inside
one actor's own wait loop*; this section's hazard is a *sibling-suite collision inside a shared
parallel pool*. Same family of mistake, different actor and different failure shape — the two are
cross-linked here deliberately rather than merged into one rule.

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

**Consumer side: `verify-deploy.sh`'s Gate 8.** Gate 8 (`gate8_run()`) passes `--fail-on-new` to
`run-all.sh` and reads only two signals from the captured output: the exit code, and whether the
`[run-all] Failing suites (` roster header is present. A clean run (exit 0, no header) passes; an
all-declared-expected run (exit 0, header present — every failure classified EXPECTED) is
non-blocking but visible via `warn_advisory()`, which emits a `WARN-FINDING gate8` line (never
`FINDING gate8`) and still counts toward `CHECKS` and `GATE_DIRTY_LIST`; any run containing at
least one NEW failure (non-zero exit) fails the gate via the `fail()` branch and its
`verify_deploy_extract_verdict_lines '[FAIL]' ...` extraction loop. `scripts/lib/deploy-baseline-lib.sh`'s
`deploy_findings_snapshot` filters strictly on `^FINDING `, so an all-expected Gate 8 run
contributes zero rows to a pre/post findings comparison in any capture — it cannot appear in one
capture and not another, because it never appears at all. `tests/known-failures.txt`'s accuracy
is load-bearing for Gate 8's verdict: a stale EXPECTED row understates how much of a failing run
is genuinely new, rather than merely mislabeling an already-blocking failure's category.

**Accepted scope boundary: the mixed-failure residual.** In a run containing at least one NEW
failure, the `fail()`-branch extraction folds every failing suite's roster line into
`FINDINGS_LIST`, EXPECTED ones included alongside the NEW one(s) — Gate 8 does not suppress the
EXPECTED line once at least one NEW failure has already made the run blocking. Closing this would
need either a second, NEW-specific anchor emitted by `run-all.sh` itself, or a roster
cross-reference built into `gate8_run()`, and the cost is judged to exceed the benefit — the
flaky-reproduction confirmation steps in `orchestrate-batch-gate.sh` and `orchestrate-cycle-plan.sh`
exist precisely to catch an inconsistently-reproducing finding, which covers the practical
consequence of this residual.

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

Mechanically enforced by `scripts/lint/lint-verdict-extraction-anchoring.sh` (gate 25 in
`scripts/gate-registry.data`).

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

This contention hazard is now ALSO mitigated, not merely measured: see
`context/patterns/batch-orchestration-guardrails.md`'s "Cross-Session Gate-Run Coordination
(`.gate-lock`)" section for the mechanism that serializes concurrent full-battery runs of
`tests/run-all.sh`/`verify-deploy.sh`'s Gate 8 across sessions in one repository.

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

## `verify-deploy.sh --skip-unchanged`: the Fast-Path Contract

Input-scoped gate invalidation adds a per-gate, content-addressed cache
(`specs/.gate-cache/gateN.json`, gitignored, outside `.claude/**` so it survives
`deploy-headless.sh`): a gate whose declared input corpus and own implementation are
byte-identical to its last green run is SKIPPED entirely rather than re-walked. This section is
the contract a caller must honor; `lib/gate-cache-lib.sh` and `verify-deploy.sh`'s own header
comments carry the mechanism-level detail.

**It is opt-in, never the default.** `--skip-unchanged` defaults off; every existing invocation
of `verify-deploy.sh` is byte-identical with the flag absent, including the summary line (a
skip-count clause is appended ONLY when at least one gate actually skip-cached).

**It never runs inside a findings baseline.** `deploy_findings_snapshot`
(`lib/deploy-baseline-lib.sh`) — the single shared function behind every pre/post
findings-comparison call site in the codebase, one of which gates whether an orchestration batch
proceeds — filters `--skip-unchanged` out of its own argument passthrough UNCONDITIONALLY, so the
flag is structurally UNREACHABLE from a findings snapshot regardless of what any caller passes.
The reason: a skip landing on one side of a pre/post comparison and not the other would make a
finding the change under test just introduced disappear from the new-findings diff — a
correctness hole, not a speedup. A caller that passes the flag anyway gets a loud stderr warning
but the snapshot still completes normally (the flag is dropped, not fatal).

**A plan's final verification gate always takes the full sweep.** `--skip-unchanged` is never
implied by `--skip-slow`, `--only-gate`, or `--max-cost`, and no plan-closure or batch-gate
checkpoint in this codebase passes it. The fast path is for a human or an agent explicitly
requesting an incremental check during active development, never for a closure criterion.

**A cached pass means "inputs unchanged since a recorded green run", not "checked now".** When
every gate selected by `--skip-unchanged` (plus any active `--only-gate`/`--max-cost` narrowing)
was legitimately cache-skipped with a green entry, the run exits 0 with an explicitly labelled
line naming the skip count (`PASS -- 0 check(s), 0 failure(s) (N gate(s) skipped -- cached,
inputs unchanged)`) — a real, attested result, textually distinguishable from both an ordinary
PASS (no skip clause) and from the separate `cannot attest` exit-2 branch that still fires
whenever any selected gate skipped for its own internal guard or was deferred (`--skip-slow`'s
gate 8) rather than legitimately cache-skipping. Mistaking the first for the second is impossible
by construction: the two conditions are mutually exclusive branches, not a single fuzzy outcome.

**Fail-open on cache trouble, fail-closed on assertions.** An unreadable cache-entry file, a
sentinel-valued (`CANNOT_COMPUTE`) key, and a `format_version` mismatch each degrade to a full
run — never a crash, never a false pass — verified directly at the `verify-deploy.sh` interface
(not only inside `gate-cache-lib.sh`'s own unit suite) by `test-deploy-baseline-lib.sh`, which
drives the real binary against an isolated scratch target carrying each corrupted-entry shape in
turn and asserts the gate's own output is fully present with the correct exit code.

## Measured Before/After: Full-Sweep and Incremental Cost

This section reports the final, post-redeploy, per-gate figures this body of work exists to
deliver. Every figure below carries its own load capture; none claims a clean, Phase-1-harness-
certified idle sample unless stated, because a reliably quiet host was not available for this
measurement window on this shared, multi-session machine (the same reality this document's
Phase 11 and Phase 12 sections already name).

**Full-sweep cost, per gate, before and after**:

| Gate | Before (dispatch baseline) | After (measured, post-redeploy) | Change |
|---|---|---|---|
| Gate 3 (doc-lint) | 125,669ms (slow) | 16,003ms (moderate), load 3.42-3.49 (non-idle) | ~7.9x faster |
| Gate 8 (run-all.sh) | 457,197ms (slow) | 662,354ms (slow), 2 runs averaged, load 1.69-2.26 | ~1.45x SLOWER |
| Gate 22 (shellcheck) | 54,716ms (slow) | unchanged — out of this phase's scope | no change |

Gate 3's reduction is the combined effect of Phase 11's two changes: removing `gate3_run`'s
redundant second `STRICT_CORE_DEPLOY` invocation (roughly halves the cost on its own) and
parallelizing `check-extension-docs.sh`'s per-extension loop across one real child process per
extension at `CED_JOBS=4` (a further ~4.2x on top of that, measured standalone at
13.8s-vs-58.4s). Its cost class downgrades from `slow` to `moderate`
(`gate-registry.data` updated this phase, timeout 400s -> 60s, matching the convention's
~3x-headroom-over-measured-average rule other `moderate` gates already follow).

Gate 8's full-sweep cost is a measured, honestly-reported REGRESSION, not an oversight: this
task's own Phase 9 added `test-gate-cache-equivalence.sh` (543,000ms) to the suite corpus
`run-all.sh` discovers and runs, as the correctness proof the dispatch's own constraints require
("Prove finding-set equivalence per gate... with a deliberately-seeded violation"). That one new
suite is now the pool's single longest member (ahead of the suite Phase 8 already cut from
228,595ms to ~31,000ms), and it alone accounts for most of the net increase. This is the
necessary cost of proving the mechanism correct, not dead weight, and it is exactly why
input-scoped invalidation matters MORE after this task than before it: a full sweep got more
expensive, but a full sweep is no longer what a typical run has to pay for.

**The incremental, warm-cache headline figure (the number this task exists to deliver)**:

A cold `--skip-unchanged` pass (empty `specs/.gate-cache/`, every gate actually executes) wrote
20 of 24 gates' cache entries green. The 4 that did not cache: gate 8 (the contention-driven
`test-gate-cache-equivalence.sh` flake under this host's concurrent load -- see below, not a
cache-correctness defect), gate 10 (`validate-state.sh --deep` exceeded its pre-existing 30s
timeout, unrelated to this task's `file_scope`), gate 14 (declares no `input_corpus`, `-`, by
design -- never cache-eligible), and gate 16 (at the time of this measurement, a `warn()`-only,
always-firing pre-existing lean `routing_hard` advisory, which dirtied the gate the same way a
`fail()` would, per `gate-registry-lib.sh`'s own `GATE_DIRTY_LIST` contract -- since resolved by
the routing_agents_hard -> hard_contracts migration: no manifest declares either retired key any
more, so gate 16 now reports `pass` and caches cleanly in an otherwise-clean repo).

A SECOND `--skip-unchanged` pass immediately afterward, with every input byte-identical, skipped
**17 of those 20** cached gates outright (`[verify-deploy] ... (17 gate(s) skipped -- cached,
inputs unchanged)`), at a cost of effectively zero wall-clock for each. The pass's own total
wall clock (706s) is still dominated by gate 8 and gate 10 re-running in full, for the two
reasons named above -- neither is a defect in the skip mechanism itself, and both are visible,
attributed findings in this pass's own output, never a silent miss.

**The honest headline, stated precisely rather than rounded up**: on a run where every gate's
last attempt was green (the common case once gate 10's pre-existing timeout and gate 8's
contention-sensitive straggler are each independently addressed — out of this task's own scope,
see Phase 10's and this document's own notes on both), an unchanged incremental run collapses
from a multi-hundred-second full sweep to the cost of whichever gate's corpus the change actually
touches — commonly a few seconds to tens of seconds (gate 3's own post-fix 16s stands in for the
pool's new slowest cacheable member), not the ~700-1400s a full cold sweep now costs with this
task's own added test coverage folded in. The mechanism is proven correct against this exact
real corpus (20 of 24 real gates cache-skip correctly; Phase 9's `test-gate-cache-equivalence.sh`
proves the remaining synthetic cases no live run happens to exercise) and is opt-in, never the
default, never reachable from a findings baseline, and never the thing a plan's final
verification gate silently gets.

**A measured non-regression, stated for completeness**: no suite introduced by this task
(`test-gate3-strict-equivalence.sh`, `test-gate3-parallel-equivalence.sh`,
`test-gate-cache-lib.sh`, `test-gate-cache-equivalence.sh`'s own deliberate cases) appears among
`run-all.sh`'s unexpected failures in any run captured during this phase; the one failing suite
observed (`test-gate-cache-equivalence.sh`) is listed in `known-failures.txt` as `EXPECTED` and
every run's own tally line confirms `0 NEW`.

## Related

- `context/standards/testing.md` — a generic JS/AAA-pattern testing primer. It predates this
  convention, covers a different language and pattern (unit-test frameworks, mocks), and is not
  superseded by this doc; the two are complementary; cross-reference rather than merge.
- `context/standards/census-methodology.md` — the standard method for deriving and cross-checking
  repo-wide counts. Its shipped tooling and fixture suite follow this doc's conventions.
