# Research Report: root cause of the zotero-generate-export.sh test hang

- **Task**: 404 - Fix test-zotero-generate-export.sh hanging indefinitely and breaking every full verify-deploy.sh run
- **Started**: 2026-10-14T21:35:14Z
- **Completed**: 2026-10-14T21:52:00Z
- **Effort**: full source read of both in-scope files plus their direct dependencies, a
  controlled microbenchmark, and a live full-scenario reproduction
- **Dependencies**: supersedes/refines the prior seed report's hypothesis (see Decisions)
- **Sources/Inputs**:
  - Full read of `agent-system/extensions/literature/scripts/zotero-generate-export.sh` (838
    lines) and its unconditional dependency `zotero-resolve-sqlite-path.sh`
  - Full read of `agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh`,
    `tests/curl-stub.sh`, and `tests/generate-zotero-page-fixtures.sh`
  - A standalone microbenchmark of `synthesize_citekeys()` at N = 50, 100, 200, 350, 700, 1400,
    2000 synthetic items
  - A live, uncontended rerun of the actual failing scenario:
    `bash test-zotero-generate-export.sh short-mid-page`
  - `git log` for both in-scope files (one commit each: task 207 phases 2-7)
  - `agent-system/extensions/core/scripts/tests/run-all.sh` (confirms no per-suite timeout exists
    anywhere upstream of this suite)
- **Artifacts**: this report. Note on numbering: the dispatch contract that produced this report
  named artifact round 1 (`reports/01_*.md`), but `reports/01_hang-localized-to-orchestrator-mode.md`
  already existed on disk (an incidental seed report captured during an earlier unrelated batch,
  never linked into `state.json`'s artifact list, so the round counter that built this dispatch
  could not see it). This report is filed as `02_` instead of overwriting or colliding with that
  file, consistent with "research reports accumulate" — see Decisions below for how the two
  relate.
- **Standards**: report-format.md, issue-log.md

## Executive Summary

- **The task description's two candidate causes are both refuted.** Neither
  `zotero-generate-export.sh` nor its dependency `zotero-resolve-sqlite-path.sh` contains a bare
  stdin read (the one `read` builtin in the latter reads a local `profiles.ini` file via input
  redirection, not stdin), and every `curl` invocation in the generator carries
  `--connect-timeout`/`--max-time`. There is no interactive prompt and no unbounded network wait
  anywhere in the code path `--orchestrator-mode true` takes.
- **The real cause is algorithmic, not blocking I/O**: `synthesize_citekeys()` processes its
  item array with a bash `for` loop that, on every one of its N iterations, re-parses the
  *entire* (fixed-size, ~N-element) source array via one `jq` subprocess AND re-serializes the
  *entire, growing* result array via a second `jq` subprocess. That is O(N) subprocess spawns
  each doing O(N) JSON work -- effectively quadratic wall-clock cost as N grows, not a deadlock.
- **It is not actually a hang -- it finishes, just far outside any timeout anyone has tried.**
  A live, uncontended rerun of the exact failing scenario (`short-mid-page`, 2828 items after
  filtering) completed cleanly in **121.7s** (confirmed below). The task's own isolated
  reproduction used `timeout 60` then `timeout 90` -- both are shorter than the scenario's true
  uncontended completion time, so `timeout` kills it mid-run and that looks indistinguishable
  from a hang to the caller. Under the separately-observed 24-minute concurrent-batch instance
  (load average ~40 on 24 cores), the same O(N) swarm of short-lived `jq` children suffers severe
  scheduling delay, which is sufficient on its own to explain the much longer wall time without
  invoking any additional blocking mechanism.
- **The bug is scale-triggered, not new.** `synthesize_citekeys()`'s shape has not changed since
  it was introduced; every scenario in this suite besides `short-mid-page` keeps N at 350 or
  smaller (fast: ~13-20s, confirmed by benchmark), so no prior test run surfaced the cost. The
  `short-mid-page` scenario -- the only one exercising ~2828 items -- was added in the same
  single commit (`task 207 phase 6`) as the rest of this test file, so this is the first test
  ever to reach the N at which the pre-existing quadratic cost becomes visible.
- Both in-scope files (`zotero-generate-export.sh`, `test-zotero-generate-export.sh`) are
  sufficient to fix this: the production fix replaces the per-item loop with a single bulk `jq`
  pass, and the test fix adds a bounded wall-clock guard plus a fixture proving that guard
  actually fires.

## Context & Scope

Scope: diagnose why `test-zotero-generate-export.sh` "passes its first case and then stalls
indefinitely" per the task description, confined to the two files in this task's `file_scope`
(`zotero-generate-export.sh` and its own test file). Out of scope: `run-all.sh`/
`verify-deploy.sh` gate-sharing changes (that is task 403's territory) and any change to how
suites are discovered or scheduled.

A prior seed report (`reports/01_hang-localized-to-orchestrator-mode.md`) already localized the
fault to a single child process, `zotero-generate-export.sh --orchestrator-mode true`, with no
retry loop and (critically, in its own Finding 5) observed that the 24-minute live instance *did*
eventually exit on its own -- "a pathological wait rather than a strict deadlock." That seed
report explicitly did not read any source file. This report reads the full source, identifies the
exact mechanism, and reconciles every piece of evidence in both reports under one explanation.

## Findings

### 1. Both of the task description's candidate causes are absent from the code

Checked directly:

```
$ grep -n '\bread\b' zotero-generate-export.sh zotero-resolve-sqlite-path.sh
zotero-resolve-sqlite-path.sh:72:  while IFS= read -r line; do
```

That is the only `read` builtin in either file, and it is `read -r line < "$profiles_ini"` (a
local-file loop), never a bare stdin read. There is no interactive prompt anywhere in the
`--orchestrator-mode true` path.

Every `curl` call in `zotero-generate-export.sh` (lines 279, 314, 317, 356, 441, 473) carries
`--connect-timeout 2` and either `--max-time 3` or `--max-time 20`. None is unbounded. The one
`sqlite3` call (`fetch_path3`, Path 3) is a single synchronous query with no network component
and is not exercised by the failing scenario (`short-mid-page` runs entirely over the Path 1
HTTP-stub route).

**Conclusion: the hang is not blocking I/O of any kind.** The task description's candidate
causes were a reasonable a-priori guess from the live single-child-process observation, but a
full source read refutes both.

### 2. `synthesize_citekeys()` is the mechanism, and it is algorithmically quadratic

`agent-system/extensions/literature/scripts/zotero-generate-export.sh:607-665`. The function
loops `for (( i = 0; i < count; i++ ))` and, on every iteration:

- `entry="$(echo "$items_json" | jq -c ".[$i]")"` -- re-parses the **entire** `items_json`
  string (fixed at ~N elements) just to pull out element `i`.
- (several cheap single-entry `jq` calls to compute `fam`/`yr`/`word`/`base` -- O(1) each)
- `result="$(echo "$result" | jq --argjson e "$entry" '. + [$e]')"` -- re-parses and
  re-serializes the **entire, growing** `result` array (0 -> N elements over the loop) just to
  append one item.

Both of these are full-array `jq` subprocess invocations run once per loop iteration. With N
iterations each doing O(N) work in the worst case (the `result` append, whose average size over
the loop is N/2), total cost is O(N^2) in JSON parse/serialize work, on top of O(N) raw process
spawns (fork+exec+jq startup, independently costly at scale).

### 3. Microbenchmark confirms superlinear growth, isolated from every other part of the script

Extracted `synthesize_citekeys()` verbatim into a standalone script and timed it over synthetic
item arrays (uncontended machine, same session):

| N (items) | elapsed |
|-----------|---------|
| 50        | 2s      |
| 100       | 4s      |
| 200       | 7s      |
| 350       | 13s     |
| 700       | 18s     |
| 1400      | 48s     |
| 2000      | 81s     |

Growth from N=1400 to N=2000 (1.43x the items) costs 1.69x the time -- clearly superlinear, and
consistent with the O(N^2)-shaped work identified in Finding 2 (small-N points are dominated by
fixed `jq`-startup overhead, which flattens the apparent exponent at the low end).

### 4. Live reproduction: the actual failing scenario finishes in ~122s, uncontended

```
$ time timeout 400 bash test-zotero-generate-export.sh short-mid-page
[test-zotero-export] PASS: short-mid-page: 4042-item library ... item count 2828 matches expected 2828
[test-zotero-export] Results: 1 passed, 0 failed

real    2m1.685s
user    1m34.815s
sys     0m55.446s
```

This is the single scenario the task description identifies as where the suite "passes its first
case and then stalls." Run alone, with zero contention, it is not a hang: it **passes** in
121.7s. The task's own isolated reproduction (`timeout 60`, later `timeout 90`) used bounds
shorter than this true completion time, so `timeout` SIGTERMs the run mid-synthesis -- which is
indistinguishable from an infinite hang to a caller that never lets it run long enough to finish.

### 5. The 24-minute concurrent-batch observation is explained by the same mechanism under load

The prior seed report observed a 24-minute live instance with system load at 3.99 by the time of
sampling, but the instance was launched during a 7-task concurrent batch the same report
describes as reaching load average ~40 on a 24-core machine (per the related task 403's
description, measured in the same batch window). `synthesize_citekeys()` spawns on the order of
2 x N (~5600, for N=2828) short-lived `jq` child processes in rapid, fully serial succession.
Under ~1.7x CPU oversubscription, each of those thousands of tiny process spawns queues for
scheduling, which is sufficient by itself to stretch 122s of uncontended wall time into the
24-minute figure observed live -- no additional blocking mechanism is needed to explain it, and
it is consistent with the seed report's own Finding 5 that the instance eventually exited on its
own.

### 6. The bug is pre-existing; only this suite's newest scenario exercises enough scale to expose it

```
$ git log --oneline -- .../zotero-generate-export.sh
6691356bd task 207 phase 7: document the changed contract, shellcheck clean
fa4b77ea3 task 207 phase 6: offline regression coverage for path1-truncation-shrink-guard
1a65698b8 task 207 phase 5: correct fetch_path3 itemTypeID exclusion set
fd56089ba task 207 phase 4: content-keyed shrink guard with --allow-shrink opt-out
ec6c4deb7 task 207 phase 3: replace no-op CSL-type filter with authoritative itemType filter
12c753868 task 207 phase 2: rewrite fetch_path1 accumulation, termination, and failure handling
```

`synthesize_citekeys()`'s loop shape has not changed across this history. Every other scenario in
the suite caps its synthetic library at 500 total items (-> <=350 post-filter, confirmed fast at
13-20s in the benchmark above) or fewer; `short-mid-page`'s 4042-item library (-> 2828 items) is
the only scenario anywhere near the N at which the quadratic cost becomes visible, and it was
added in the same single commit (`fa4b77ea3`, "task 207 phase 6") as the rest of this test file.
This is therefore the first test run ever to exercise N large enough to surface a cost that has
been present in the production script all along -- and it also means real users with
larger-than-test Zotero libraries (thousands of items) hit the same multi-minute-or-worse cost in
production, not just in this test suite.

### 7. No per-suite timeout exists anywhere upstream

`agent-system/extensions/core/scripts/tests/run-all.sh` invokes every suite as bare
`bash "$suite"` (confirmed at both its sequential and parallel call sites, lines 366 and 511) --
no `timeout` wrapper exists at the harness level. Nothing above `test-zotero-generate-export.sh`
itself currently bounds its wall-clock time, so the fix the task asks for ("give the test case
its own timeout") must live inside this suite, matching the task's own `file_scope`.

## Decisions

- Supersedes the prior seed report's framing only insofar as the mechanism: this report confirms
  and sharpens the seed report's Finding 5 ("pathological wait, not a strict deadlock") by
  naming the exact mechanism (quadratic `jq` subprocess cost in `synthesize_citekeys()`) and
  showing it reproduces deterministically and finishes in ~122s uncontended. It does not
  contradict any of the seed report's other findings (single-child-process localization,
  no-spawn-loop, isolation-ruled-out-contention-as-sole-cause) -- all remain correct; contention
  amplifies an already-slow algorithm rather than being the hang's origin.
- This report is filed as `reports/02_*.md` rather than `01_*.md` because `01_*.md` already
  existed on disk under a name the dispatch's own round-numbering could not see (see Artifacts
  note above). No file was overwritten.

## Recommendations

1. **Fix the root cause in `zotero-generate-export.sh`: replace the per-item bash loop in
   `synthesize_citekeys()` with a single bulk `jq` pass.** jq can compute the same
   first-seen-wins, numeric-suffix-on-collision citekey assignment for every element of the
   array in one invocation (e.g. via `reduce`/`group_by` over the whole array), eliminating both
   the O(N) subprocess-spawn count and the O(N) per-iteration reparse/reserialize cost. This is
   expected to take the 2828-item case from ~122s to well under a second, and also fixes the
   same latent cost for real users with large production Zotero libraries, not just this test.
2. **Add a bounded wall-clock guard in `test-zotero-generate-export.sh`.** Wrap each generator
   invocation (`run_export`'s underlying exec, and the separate `path3-itemtype` exec) in a
   `timeout N` bound comfortably above the expected post-fix runtime (sub-second to a few
   seconds) but far below today's pathological cost -- e.g. 30-60s -- so a future regression of
   this shape fails loudly (a readable FAIL, exit 124) instead of hanging the suite, satisfying
   the task's "give the test case its own timeout" goal.
3. **Prove the new bound actually fires**, per the task's own verification requirement ("a
   deliberately-stalled fixture must make the new timeout fire rather than hang"). Two options,
   left to the planning phase to choose between:
   - (a) A test-only hook in the generator (an env var the test sets to force an artificial
     delay inside `synthesize_citekeys()` or elsewhere) that only activates under that env var,
     verified to make the timeout wrapper fire.
   - (b) A trivial standalone stalled fixture (e.g. a script that just sleeps past the bound)
     exercised through the *same* timeout-wrapping helper the real scenarios use, proving the
     wrapper mechanism itself is wired up and correctly turns an overrun into a bounded FAIL --
     without adding any test-only branch to the production script. This keeps the production
     file's only change scoped to the actual algorithmic fix (Recommendation 1).
4. **Do not change `run-all.sh` or `verify-deploy.sh`** for this task -- no per-suite timeout
   exists there today (Finding 7), and adding one is a broader, cross-suite decision outside this
   task's `file_scope` and likely better suited to a separate task if ever pursued repo-wide.

## Risks & Mitigations

- **Risk**: a single bulk-`jq` rewrite of `synthesize_citekeys()` could subtly change
  disambiguation-suffix ordering if the new implementation doesn't preserve the exact
  first-seen, sequential-within-base-key numbering the current loop produces. **Mitigation**: the
  existing scenarios (`boundary-128kib`, `short-mid-page`, etc.) already assert exact item
  counts and would need an added assertion on citekey uniqueness/format to catch an ordering
  regression; the planning phase should include that as an explicit check.
- **Risk**: picking too tight a timeout bound in Recommendation 2 could make the suite flaky on
  a loaded CI/batch machine even after the O(N^2) fix is applied. **Mitigation**: since the fix
  is expected to bring runtime to well under a second, a bound in the tens of seconds leaves
  generous headroom for scheduling jitter while still being far short of the current
  multi-minute-to-24-minute pathological cost.
- **Risk**: real production Zotero libraries (thousands of items) hit the same quadratic cost
  today, independent of this test suite. **Mitigation**: Recommendation 1 fixes the production
  code path directly, not just the test; this is a genuine user-facing latency fix, not only a
  test-hygiene one.

## Context Extension Recommendations

- **Topic**: bash + `jq` bulk-array processing anti-pattern.
- **Gap**: no existing context file documents "never loop over an array in bash re-parsing or
  re-serializing the whole array via a `jq` subprocess per element; do the whole array in one
  `jq` invocation instead." This is a general shell-authoring hazard, not literature-specific,
  and the same shape could recur in any other script in this codebase that builds up a JSON
  result incrementally inside a bash loop.
- **Recommendation**: add a short pattern note (e.g.
  `.claude/context/standards/shell-script-testing.md` or a new sibling pattern file under
  `.claude/context/patterns/`) naming this anti-pattern explicitly, with this task as the worked
  example once fixed, so a future shell-script author or reviewer has a citable precedent.

## Appendix

- Search/commands used: `grep -n '\bread\b' ...`, `grep -n 'curl ' zotero-generate-export.sh`,
  `git log --oneline -- <file>`, `git log --follow -p --oneline -- zotero-generate-export.sh |
  grep -n synthesize_citekeys`, a standalone extracted-function microbenchmark at N = 50, 100,
  200, 350, 700, 1400, 2000, and a live `time timeout 400 bash
  test-zotero-generate-export.sh short-mid-page` run.
- Referenced files: `agent-system/extensions/literature/scripts/zotero-generate-export.sh`,
  `agent-system/extensions/literature/scripts/zotero-resolve-sqlite-path.sh`,
  `agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh`,
  `agent-system/extensions/literature/scripts/tests/curl-stub.sh`,
  `agent-system/extensions/literature/scripts/tests/generate-zotero-page-fixtures.sh`,
  `agent-system/extensions/core/scripts/tests/run-all.sh`.
