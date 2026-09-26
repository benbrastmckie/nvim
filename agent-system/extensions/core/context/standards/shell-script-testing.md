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
  flakiness gate found two load-sensitive suites did not reliably benefit from parallelism under
  heavy ambient host load, so the flip to a parallel default was declined; `--jobs` remains a
  correct, verified opt-in. A nested-invocation guard (`RUN_ALL_NESTED=1`) forces `--jobs 1`
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

### Known pre-existing failures and flakes (baseline, not regressions)

None of these are introduced by the `--jobs`/`--timings`/`--only-gate` work above — record them so
the next person measuring this suite does not rediscover them:
- Consistently failing: `test-handoff-dispatch-identity.sh`, `test-orchestrate-context-growth.sh`,
  `test-lint-json-channel-discipline.sh`, `test-orchestrate-recover-message-findings.sh`.
- Known-intermittent: `test-gate-out-repair-reporting.sh`.
- Load-sensitive (may fail only under heavy ambient host load, e.g. several concurrent agent
  sessions): `test-lake-build-guard.sh`, `test-state-write-concurrency.sh`,
  `test-state-write-regen-timing.sh`, `test-four-tier-conflict.sh`, `test-run-all-parallel.sh`.

## Related

- `context/standards/testing.md` — a generic JS/AAA-pattern testing primer. It predates this
  convention, covers a different language and pattern (unit-test frameworks, mocks), and is not
  superseded by this doc; the two are complementary; cross-reference rather than merge.
- `context/standards/census-methodology.md` — the standard method for deriving and cross-checking
  repo-wide counts. Its shipped tooling and fixture suite follow this doc's conventions.
