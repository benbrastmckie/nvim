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

## Phase 2: Parallelism-safety subsection and index-entries.json update

Landed `### Exact-pid process checks: the parallelism-safety rule for leftover/liveness
assertions` inside `agent-system/extensions/core/context/standards/shell-script-testing.md`'s
`## Suite runtime: --jobs, --timings, and gate selection` section, immediately before `###
Mapping a touched file to its suite`. Content covers all seven required points: the rule, the
mechanism-level rationale, the strictly-worse name-based-kill case, the copy-pasteable
pidfile/liveness-check shape (citing `test-gate-registry-resolution.sh` case13 by name),
`LOAD_SENSITIVE_BASENAMES` non-substitution, the re-runnable audit recipe with no frozen count,
and a cross-link to `context/patterns/bounded-build-waiter.md` as the related-but-distinct
agent-layer sibling discipline.

Updated the `standards/shell-script-testing.md` entry in `index-entries.json`: `keywords` +`pid`,
+`process-check`; `topics` +`parallelism-safety`; `line_count` corrected 1022 -> 1093. JSON
parses; the diff committed under this task's own commit touches only this one entry.

**Concurrent-sibling dirty-file note**: `index-entries.json` carried a second, pre-existing
uncommitted hunk at session start (`patterns/file-footprint-overlap.md` line_count 283 -> 330),
belonging to an unrelated concurrent sibling task. That hunk was never touched by this task: it
was temporarily reverted to its HEAD value in the working tree only for the duration of this
task's own commit, then restored to its working-tree value immediately afterward — never
committed, never discarded. Recorded in `issues.jsonl`.

`verify-deploy.sh --skip-slow --only-gate 3,4 <repo root>` is green for the `core` extension
after this change (doc-lint and task-reference lint both pass); the only Gate 3 failure present
is the `lean` extension's own pre-existing manifest/orphan drift, unrelated to this task.

## Phase 3: Redeploy and gate-set result

Redeployed via `bash agent-system/extensions/core/scripts/deploy-headless.sh` (whole-tree
regeneration). Confirmed the deployed tree carries both changes:
`.claude/context/standards/shell-script-testing.md:538` has the new subsection heading, and
`.claude/context/index.json` has `line_count: 1093` plus the `process-check`/`parallelism-safety`
keyword and topic additions.

**Batch Gate Deferral applied** (per this dispatch's own directive): rather than independently
running the full `verify-deploy.sh <repo root>` battery (which includes Gate 8's full ~184-suite
shell-test sweep) in this dispatch, this phase discharged against a scoped tier and recorded that
the full sweep is deferred to the once-per-invocation batch-level stage at the end of this
multi-task `/orchestrate` run:

- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow /home/benjamin/.config/nvim`
  — 39 of 40 fast-gate checks evaluated (Gate 8's slow suite sweep deferred); 4 reported FAIL.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate-registry-resolution.sh --jobs 4`
  — real (not skipped) coverage of the one suite this task's correctness claim rests on, under
  the parallel pool, post-redeploy: `1 passed, 0 failed`.

**Triage of the 4 fast-gate failures against the dispatch's known-unrelated baseline**:

| Failure | Attribution |
|---------|-------------|
| Gate 3 doc-lint: `lean` extension FAIL | Matches the dispatch's stated known-unrelated baseline ("Gate 3 lean4 doc-lint missing index.json entry") and the orchestrator's own prior note tracing this family to commits `41d544812`/`ce5b1588b`. `core` itself reports clean (`check-extension-docs.sh` summary: `core PASS`, `lean FAIL`). Not attributable to this task. |
| Gate 10 (`gate10_run`) exceeded its 30s timeout | Re-ran gate 10 alone (`--only-gate 10`): passes cleanly (`validate-state.sh --deep: specs/state.json passes`). Confirms a transient ambient-load timeout on a busy host (several concurrent `/orchestrate` dispatches active throughout this session), not a real failure and not something Phase 3's own changes introduced. Not in the dispatch's explicit baseline list, but confirmed transient by direct re-run. |
| Gate 13 whole-tree orphan detection: 6 findings | All 6 named orphans (`scripts/lean-plan-compliance-check.sh`, four `scripts/tests/fixtures/challenge/plan_r1[8-9]/r2[01]_*.md` fixtures, `scripts/tests/test-lean-plan-compliance-check.sh`) are `lean`-extension files — the same pre-existing manifest/orphan drift family as the Gate 3 failure above, not this task's `core`-extension edits. Not attributable to this task. |
| Gate 24 dead-command-recommendation lint: 2 violations | Both violations are in `agent-system/extensions/memory/context/project/memory/memory-setup.md:93` and `memory-troubleshooting.md:34`, naming a `/ide` command with no definition file. Unrelated to `core`'s `shell-script-testing.md`/`index-entries.json` edits or to the `lean` drift family; pre-existing documentation issue in a different extension entirely. Not attributable to this task. |

No failure in this run falls outside the dispatch's known-unrelated baseline once traced to its
actual source. The full, unselected `verify-deploy.sh <repo root>` battery (including Gate 8's
complete sweep) runs once at the end of this multi-task `/orchestrate` batch invocation and its
result is attributed back to this task via its own `modified_files`, per
`context/contracts/phase-closure.md`'s no-promotion-without-evidence carve-out.
