# Implementation Summary: Exact-PID Process Check Standard

## Phase 1: Live corpus audit, collision reproduction, and lint declination record

### Audit scope and recipe

Boundary: `agent-system/extensions/core/scripts/tests/` and flat `agent-system/extensions/core/scripts/*.sh`.
Other extensions' suite corpora (lean, latex, python, typst, z3, cslib, ...) were not audited and
this record makes no claim about them.

Four searches, run from `agent-system/extensions/core`:

```bash
grep -rn --include='*.sh' -E 'pgrep[[:space:]]+-[a-zA-Z]*f' scripts/tests/ scripts/*.sh
grep -rn --include='*.sh' -E 'pkill[[:space:]]+-[a-zA-Z]*f' scripts/tests/ scripts/*.sh
grep -rn --include='*.sh' -E 'ps[[:space:]]+(aux|-ef|ax)[^|]*\|[[:space:]]*grep' scripts/tests/ scripts/*.sh
grep -rln --include='*.sh' -E 'pgrep|pkill' scripts/tests/ scripts/*.sh
```

### Result: zero live violations

Live-violation count: **0**. Every textual hit across the four searches classifies as
non-violating. Per-file breakdown:

| File | Lines | Classification |
|------|-------|-----------------|
| `scripts/tests/test-validate-bounded-waiter.sh` | 91-131, 151 | Fixture command-text strings fed to `validate-bounded-waiter.sh`'s own lint under test (the hook that blocks agents from authoring a name-match wait loop); the suite itself performs no process check |
| `scripts/tests/test-lake-build-guard.sh` | 615, 620, 695, 1462 | Comments/test-case descriptions documenting the guard's own avoidance of name-match polling; no executed `pgrep`/`pkill` call |
| `scripts/tests/test-claude-refresh-matcher.sh` | 2130, 2133 | A fixture string (`'ps aux | grep -q "[b]ash check.sh"'`) classified by `build_waiter_family` under test; not a process check performed by the suite |
| `scripts/tests/test-gate-registry-resolution.sh` | 222 | Comment inside case13 (the already-fixed origin case) naming the anti-pattern it avoids; the case's own check is `kill -0` on a captured pid |
| `scripts/lake-build-guard.sh` | 115, 117, 354-355, 710, 718 | Header/inline comments warning against `pgrep -f` self-match; no executed `pgrep`/`pkill` call |
| `scripts/orchestrate-build-dispatch.sh` | 111, 821 | Comment and an echoed `--help`-style guidance string; no executed `pgrep`/`pkill` call |
| `scripts/dispatch-strand-probe.sh` | 37 | Comment naming the forbidden lookups; no executed `pgrep`/`pkill` call |
| `scripts/claude-refresh.sh` | 1577 | Comment describing a classifier's "Family B" pattern name; no executed `pgrep`/`pkill` call |

No `pkill -f` hits at all (the second search returned empty).

**"Fix any remaining occurrences" directive: produced zero changes.** No suite or script was
edited in this phase; the search set above is the re-run recipe for a future reader to confirm
this independently.

### Collision reproduction (deliberate, on purpose)

Reproduced the original collision shape against the already-fixed suite:

1. Spawned an unrelated sibling noise process using the exact same command text as case13's
   stalling fixture (`sleep 30 &`), capturing its own pid at spawn (pid `1988365`).
2. Ran the full suite (`bash scripts/tests/test-gate-registry-resolution.sh`) while that noise
   process was alive. Result: `35 passed, 0 failed`. Case13 itself:
   `[PASS] case13: a stalling function times out (rc=124) within margin (2418ms) with no leftover
   descendant process (checked exact pid 1988763)` — its own stalled descendant pid (`1988763`)
   is distinct from the noise pid (`1988365`), and the case correctly reports no leftover.
3. Confirmed via a standalone `kill -0 1988365` that the noise process was still alive
   immediately after the suite finished (the collision window was real, not already-reaped).

### Non-vacuousness check

While the noise process was still alive, a one-shot name-match probe
(`pgrep -f "sleep 30"`) was run standalone (not inside a wait loop). It returned three pids,
including the injected noise pid `1988365` — confirming a name-based check against that command
text would indeed have matched the sibling noise process. (The other two returned pids were
other, unrelated `sleep 30` processes live on the host at that moment from concurrent sibling
work in this same session — further, unplanned corroboration of exactly the collision risk this
standard addresses: a busy host routinely has more than one process sharing that command text at
once.) Case13's own stalled-descendant pid (`1988763`) was correctly absent from the probe's
output, confirming the suite's own `kill -0`-on-exact-pid check and a hypothetical name-based
check would have disagreed on this run: the exact-pid check correctly reported no leftover, while
a name-based check would have wrongly flagged the sibling's `sleep 30` as case13's own leftover.
The noise pid was then terminated by its own captured pid only (`kill 1988365`), confirmed dead
by a follow-up `kill -0` check.

### Declined-mechanical-lint decision

**Declined.** Every one of the 8 files carrying a textual hit above is non-violating, so 100% of
current hits would need an allowlist entry if a lint were added today, and there is no live
violating target in the corpus to prove detection against (any fixture would have to be
synthetic, seeded purely to exercise the lint itself). A mechanical check that needs an exemption
on virtually all of its hits, with no real violation to validate it against, costs more than it
returns right now. Revisit this decision only if a second live, executed `pgrep -f`/`pkill -f`/
`ps | grep`-style process check actually appears in `scripts/tests/**` or flat `scripts/*.sh` —
at that point there would be a real detection target and the allowlist-to-hit ratio would no
longer be total.

### Boundary statement

This audit and its zero-violation result cover `agent-system/extensions/core/scripts/tests/**`
and flat `agent-system/extensions/core/scripts/*.sh` only. No other extension's suite corpus
(lean, latex, python, typst, z3, cslib, ...) was searched, and this record makes no claim —
positive or negative — about those corpora.
