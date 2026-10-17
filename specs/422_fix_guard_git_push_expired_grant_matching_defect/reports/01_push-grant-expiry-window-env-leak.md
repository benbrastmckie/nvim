# Research Report: Task #422

**Task**: 422 - Fix guard-git-push expired-grant matching defect
**Started**: 2026-10-17
**Completed**: 2026-10-17
**Effort**: small (one-line test fixture fix)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/lib/push-grant-lib.sh`,
  `agent-system/extensions/core/hooks/guard-git-push.sh`,
  `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh`
- Live environment: `~/.claude/settings.json` (deployed from
  `~/.dotfiles/config/claude/settings.json` via Home Manager)
- Prior artifacts: `specs/170_isolate_shell_suites_from_host_state/reports/01_ambient-host-state-audit.md`,
  `specs/170_isolate_shell_suites_from_host_state/reports/02_corpus-triage-ledger.md`,
  `agent-system/extensions/core/scripts/tests/known-failures.txt` (row 40)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's own "SUSPECTED ROOT CAUSE" is wrong, and so is the upstream corpus-triage
  ledger's "confirmed NOT ambient-host-state coupling" verdict it was carried forward from: the
  defect **is** ambient-host-state coupling, just a form that is always present rather than
  load- or order-dependent, which is why it looked environment-independent under triage.
- The real cause: this machine's `~/.claude/settings.json` `env` block (Home-Manager-managed
  from `~/.dotfiles/config/claude/settings.json`) exports `PG_EXPIRY_WINDOW=1800` for **every**
  Claude Code session, deliberately widening `pg_grant_fresh()`'s freshness window from
  `push-grant-lib.sh`'s documented default of 600s. The test suite's "expired" fixture ages its
  grant by a fixed 700s — past 600, but well inside 1800 — so under the real ambient
  environment the grant is genuinely still fresh and the guard correctly allows the push
  (`exit 0`), which is not a bug in the guard, the grant-matching logic, or the suite's
  isolation of `PUSH_GRANT_DIR`/`PUSH_GRANT_KEY_PATH`.
- Confirmed by direct toggle: `bash test-guard-git-push.sh` under the ambient environment gives
  `46 passed, 1 failed` (the named case); `env -u PG_EXPIRY_WINDOW bash test-guard-git-push.sh`
  gives `47 passed, 0 failed`. No other source-level change reproduces or fixes this — the
  single env var is the entire explanation.
- No grant-matching, test-isolation, or cross-fixture-pollution defect exists: every other
  invalidation/exclusion/success case in the 47-case suite passes under the ambient
  environment, and `pg_grant_find_match`'s per-candidate matching (remote, ref, force,
  head-sha, action-class, freshness) is exactly as strict as its header claims. There is
  exactly one grant file in the fixture directory at the point of failure (confirmed via direct
  reproduction with `ls`), so "an earlier case's still-fresh grant is being matched instead" is
  also ruled out directly, not just inferred.
- Recommended fix: `test-guard-git-push.sh` already isolates two of `push-grant-lib.sh`'s three
  environment-overridable knobs (`PUSH_GRANT_DIR`, `PUSH_GRANT_KEY_PATH` — see its own header
  comment, lines 11-16) but never isolates the third, `PG_EXPIRY_WINDOW`. Add
  `unset PG_EXPIRY_WINDOW` (or `export PG_EXPIRY_WINDOW=600` to pin the documented default
  explicitly) alongside the other two overrides near line 53-54, so the suite's fixed 700s
  "expired" offset is evaluated against the library's own documented default rather than
  whatever value happens to be exported in the invoking shell. This is a one-line fix entirely
  within the suite's own fixture construction — no change to `push-grant-lib.sh` or
  `guard-git-push.sh` is needed or warranted.

## Context & Scope

Dispatched to diagnose and fix a single failing case in
`agent-system/extensions/core/scripts/tests/test-guard-git-push.sh`:
`[FAIL] invalidation: expired grant expected exit 2, got 0`. The dispatch's description
supplied a specific hypothesis (a grant-matching/test-isolation defect causing an earlier
case's still-fresh grant to be matched instead of the deliberately-expired one) inherited from
`specs/170_isolate_shell_suites_from_host_state/reports/02_corpus-triage-ledger.md`, which had
already ruled out ambient-host-state coupling as the cause. Scope per the dispatch: diagnose
which grant the guard actually matches (adding temporary tracing if needed), fix the
matching/isolation defect wherever the diagnosis implicates it (guard, grant-selection logic, or
the suite's own fixture construction), verify via
`run-all.sh --only test-guard-git-push.sh` plus a direct run, and remove the
`known-failures.txt` row once fixed. This research dispatch performs the diagnosis; the fix
itself (a one-line test-file edit) is left to the implementation phase per this task's own
phase boundary.

## Findings

### Reproduction and isolation of the actual cause

Running the suite directly on this machine:

```
$ bash agent-system/extensions/core/scripts/tests/test-guard-git-push.sh
...
[FAIL] invalidation: expired grant expected exit 2, got 0
...
Results: 46 passed, 1 failed
```

Direct, minimal reproduction of just the failing case (fresh fixture, mint a grant, backdate
its `TIMESTAMP` by 700s, re-sign its HMAC, invoke the real hook) confirmed: exactly one grant
file exists in the fixture's `specs/.push-grant/` at the moment the hook runs (ruling out
"matching the wrong grant" — there is no other grant to match), and the hook still exits 0.

Sourcing `push-grant-lib.sh` directly and calling `pg_grant_fresh` with the exact same
timestamp used by the test showed the actual effective expiry window:

```
$ bash -c 'source push-grant-lib.sh; echo "window=$PG_EXPIRY_WINDOW"; pg_grant_fresh $(( $(date -u +%s) - 700 )) && echo FRESH'
window=1800
FRESH
```

`push-grant-lib.sh:101` reads `PG_EXPIRY_WINDOW="${PG_EXPIRY_WINDOW:-600}"` — an
environment-overridable default. On this machine, `PG_EXPIRY_WINDOW=1800` is exported for every
Claude Code session via `~/.claude/settings.json`'s `env` block
(`"PG_EXPIRY_WINDOW": "1800"`, with an inline `_PG_EXPIRY_NOTE` explaining the deliberate
widening "to leave room for a confirmation prompt and a short interruption between typing
`/please` and the push"). That file is Home-Manager-managed from
`~/.dotfiles/config/claude/settings.json`, which carries the identical `env` entry and note.
Every Bash tool call in a Claude Code session — including this suite's own invocation and the
guard hook subprocess it spawns — inherits this exported value.

**Direct confirmatory toggle** (the decisive check):

```
$ env -u PG_EXPIRY_WINDOW bash agent-system/extensions/core/scripts/tests/test-guard-git-push.sh
...
Results: 47 passed, 0 failed
```

With `PG_EXPIRY_WINDOW` unset (restoring the library's hardcoded default of 600s), the
previously-failing case passes, and nothing else changes — all other 46 cases remain green
either way. This is a clean, single-variable, reversible toggle: the ambient env var is both
necessary and sufficient to reproduce the failure.

### Why task 170's "confirmed NOT ambient-host-state coupling" verdict was wrong

`specs/170_.../reports/01_ambient-host-state-audit.md` and `02_corpus-triage-ledger.md` (and
`known-failures.txt` row 40, carried from them) reasoned that because the failure "reproduces
identically in isolation, is load-independent, and is a relative-age comparison rather than an
absolute-wall-clock one," it could not be ambient-host-state coupling, and must instead be a
grant-matching/test-isolation defect. That reasoning conflated two different senses of
"ambient": the triage's named ambient-host-state axes (documented in
`01_ambient-host-state-audit.md`) are things like wall-clock-dependent timestamps, test
*ordering*, or machine *load* — properties that vary run to run or environment to environment.
`PG_EXPIRY_WINDOW` is also ambient host state, but of a different, *session-environment*
flavor: a value baked into every Claude Code session's exported environment on this machine via
`settings.json`'s `env` block, present identically on every invocation regardless of load,
order, or isolation of the grant store's own directory/key paths. It therefore looks
load-independent and perfectly reproducible "in isolation" — because it is always present, not
because it is absent as a causal factor. The relative-vs-absolute framing was a correct
observation about `pg_grant_fresh()`'s arithmetic, but it was answering a different question
(is the *timestamp* wall-clock-anchored?) than the one that actually matters (is the *window*
itself a fixed constant the test can safely assume?). It is not: the window is
environment-overridable by design (so the hook and the `/please` wrapper agree on one value),
and this machine's own real-usage configuration deliberately overrides it.

This is being recorded as a machine-checked refutation (see the `claim_invalidations` entry in
`.return-meta.json`) of the corpus-triage-ledger's and `known-failures.txt`'s "not
ambient-host-state coupling" characterization — not of its separate, correct finding that this
defect is unrelated to the test *ordering*/load axes task 170 was auditing.

### Why the "grant-matching/test-isolation defect" hypothesis does not hold

- Only one grant file exists in the fixture directory for this case (confirmed by direct `ls`
  during reproduction) — there is no second, still-fresh grant from an earlier case to
  accidentally match. Each test case calls `make_push_fixture` to build a brand-new `mktemp -d`
  repo+bare-remote pair, and `mint_grant_in` additionally calls `pg_grant_revoke` before minting
  — grants never carry over between fixtures.
- `pg_grant_find_match()` (`push-grant-lib.sh:447-492`) requires an exact match on
  `action_class`, `remote`, `ref`/`force`, and `head_sha` in addition to the freshness check —
  there is no mechanism by which a grant from a *different* fixture (a different `mktemp -d`
  directory entirely, hence a different `PUSH_GRANT_DIR` resolution since it's cwd-relative)
  could even be visible to this fixture's `pg_grant_find_match` call.
- The suite's own isolation design (documented in its header, lines 11-16) already protects
  exactly the two knobs that would matter for cross-fixture pollution
  (`PUSH_GRANT_KEY_PATH`, `PUSH_GRANT_DIR`); the gap is specifically the third knob,
  `PG_EXPIRY_WINDOW`, which the header comment does not mention at all.

### Scope check: is any other suite exposed to the same gap?

`grep -rl 'PG_EXPIRY_WINDOW'` across `agent-system/extensions/core/scripts/tests/*.sh` matches
only `test-guard-git-push.sh`. No other shell-test fixture constructs a grant with a hardcoded
relative-age offset, so no other suite in the 153-suite corpus shares this exposure.

## Decisions

- The fix belongs entirely in the test suite's own fixture construction
  (`test-guard-git-push.sh`), not in `push-grant-lib.sh` or `guard-git-push.sh` — both behave
  exactly per their documented contract (an environment-overridable expiry window, a strict
  multi-field grant match). Changing either production file to "fix" this would weaken or
  complicate correct, already-tested production behavior to paper over a test fixture that
  omitted one of three isolation variables it otherwise correctly isolates.
- The `known-failures.txt` row 40 and the `02_corpus-triage-ledger.md` finding it cites both
  need their "not ambient-host-state coupling" / "grant-matching/test-isolation defect"
  characterization corrected once the fix lands (row 40 removed per the dispatch's own
  instruction; the ledger's prose is a `specs/**` artifact and outside this report's
  no-record-versioning constraints, but a future reader following the `known-failures.txt`
  owner pointer should not be misled by the stale diagnosis it currently points to).

## Recommendations

1. **Implementation fix** (one line, in `test-guard-git-push.sh` near lines 53-54, alongside the
   existing `PUSH_GRANT_KEY_PATH`/`PUSH_GRANT_DIR` isolation exports): add
   `unset PG_EXPIRY_WINDOW` so the suite always evaluates its fixed 700s "expired" offset
   against `push-grant-lib.sh`'s own documented default (600s) rather than whatever value the
   invoking shell happens to export. Update the header comment (lines 11-16) to mention this
   third isolated variable, matching its existing two-variable isolation narrative. Prefer
   `unset` over pinning `export PG_EXPIRY_WINDOW=600` only because `unset` makes the suite
   track the library's own default if that default is ever changed, rather than silently
   duplicating a magic number the suite would then need to keep in sync by hand; either form
   fixes the failure.
2. Re-run `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-guard-git-push.sh`
   and a direct `bash .../test-guard-git-push.sh` to confirm 47/47 under the ambient (unmodified)
   ```
   PG_EXPIRY_WINDOW=1800
   ```
   environment this machine always exports — the fix must pass with the real ambient value
   present, not just with it unset, since that is the condition under which the suite normally
   runs in this environment going forward.
3. Remove the `test-guard-git-push.sh` row from `known-failures.txt` (row 40) once the fix is
   verified, per that file's own header requirement and this task's dispatch instruction.
4. No change to `push-grant-lib.sh`, `guard-git-push.sh`, or any other production file is
   recommended or needed.

## Risks & Mitigations

- **Risk**: pinning `PG_EXPIRY_WINDOW` for the suite could mask a *future* real change to the
  library's default if someone edits `push-grant-lib.sh:101`'s fallback without noticing the
  test suite now pins a stale copy of it. **Mitigation**: use `unset` (recommendation 1) rather
  than `export PG_EXPIRY_WINDOW=600`, so the suite always re-derives the library's actual
  current default at run time instead of hardcoding a duplicate of it.
- **Risk**: a reviewer re-reading `known-failures.txt`'s current row 40 or the corpus-triage
  ledger before this fix lands could re-propagate the "not ambient-host-state coupling"
  characterization into a new task or decision. **Mitigation**: this report's
  `claim_invalidations` entry and the Decisions section above flag the correction explicitly;
  recommendation 3 removes the stale row once fixed.

## Context Extension Recommendations

- **Topic**: shell-test fixtures that construct relative-time-based "expired" assertions against
  a library value that is itself environment-overridable.
- **Gap**: no existing context file documents the pattern "a test fixture must isolate every
  environment-overridable knob the library under test reads, not just the ones that look
  state-bearing (file paths, keys) — a plain numeric threshold env var is just as capable of
  silently widening or narrowing a test's pass/fail boundary." The ambient-host-state-isolation
  task's own audit document names specific axes (wall-clock time, test order, machine load) but
  does not yet name "an environment variable the production code deliberately reads for
  legitimate session-wide configuration" as a fourth, distinct ambient-coupling axis.
- **Recommendation**: `specs/170_.../reports/01_ambient-host-state-audit.md` (or a durable
  context file it points to, if one exists for the ambient-host-state axis taxonomy) would
  benefit from an added axis: "deliberately-exported session-configuration env vars that a
  library reads via `${VAR:-default}`" — distinct from load/order/wall-clock — with this task's
  `PG_EXPIRY_WINDOW` case as the worked example.

## Appendix

### Search queries / commands used

- `bash agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` (baseline repro)
- `bash -c 'source push-grant-lib.sh; echo "window=$PG_EXPIRY_WINDOW"; pg_grant_fresh <ts>'`
  (isolated `pg_grant_fresh` check against the real effective window)
- Minimal standalone repro script (fixture + mint + backdate + re-sign + invoke real hook,
  confirming exactly one grant file present and `exit 0`)
- `env -u PG_EXPIRY_WINDOW bash .../test-guard-git-push.sh` (decisive toggle: 47/47 passed)
- `env | grep -i PG_EXPIRY` / `grep -rn PG_EXPIRY_WINDOW ~/.dotfiles ~/.claude/settings.json`
  (traced the ambient source)
- `grep -rl 'PG_EXPIRY_WINDOW' agent-system/extensions/core/scripts/tests/*.sh` (scope check:
  only this one suite is exposed)

### References

- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh:101` (`PG_EXPIRY_WINDOW` default)
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh:432-440` (`pg_grant_fresh`)
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh:447-492` (`pg_grant_find_match`)
- `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh:11-16,53-54,191-211`
- `~/.claude/settings.json` / `~/.dotfiles/config/claude/settings.json` (`env.PG_EXPIRY_WINDOW`)
- `specs/170_isolate_shell_suites_from_host_state/reports/01_ambient-host-state-audit.md`
- `specs/170_isolate_shell_suites_from_host_state/reports/02_corpus-triage-ledger.md`
- `agent-system/extensions/core/scripts/tests/known-failures.txt:40`
