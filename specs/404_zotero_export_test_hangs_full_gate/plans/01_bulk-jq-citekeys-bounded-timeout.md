# Implementation Plan: Fix the zotero-export suite's unbounded runtime

- **Task**: 404 - Fix test-zotero-generate-export.sh hanging indefinitely and breaking every full verify-deploy.sh run
- **Status**: [IMPLEMENTING]
- **Effort**: 4.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/404_zotero_export_test_hangs_full_gate/reports/02_quadratic-citekey-synthesis-diagnosis.md (primary); specs/404_zotero_export_test_hangs_full_gate/reports/01_hang-localized-to-orchestrator-mode.md (seed, superseded on mechanism)
- **Artifacts**: plans/01_bulk-jq-citekeys-bounded-timeout.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`test-zotero-generate-export.sh` does not deadlock -- it runs an algorithmically quadratic
code path to completion far outside any timeout anyone has applied, so every caller sees a
hang. The fix has two independent halves: replace `synthesize_citekeys()`'s per-item bash loop
in `zotero-generate-export.sh` (two full-array `jq` subprocess invocations per item, O(N) spawns
x O(N) JSON work) with a single bulk `jq` pass, and give the test suite its own bounded
wall-clock guard so a future regression of this shape produces a readable FAIL instead of an
open-ended wait. Done means: the suite terminates with a definite pass or fail inside a declared
wall-clock bound, the bound is proven to fire against a deliberately-stalled fixture, citekey
output is proven byte-identical to the pre-rewrite behavior, and the complete `verify-deploy.sh`
gate set exits 0.

### Research Integration

Findings carried in from `reports/02_quadratic-citekey-synthesis-diagnosis.md`:

- Both of the task description's candidate causes are refuted by a full source read: no bare
  stdin read exists in `zotero-generate-export.sh` or `zotero-resolve-sqlite-path.sh` (the one
  `read` builtin reads a local `profiles.ini` via redirection), and every `curl` call carries
  `--connect-timeout` plus `--max-time`. The plan therefore does **not** add a non-interactive
  stdin path or a network bound -- there is nothing to bound there.
- The mechanism is `zotero-generate-export.sh:607-665`'s `for (( i = 0; i < count; i++ ))` loop:
  per iteration it re-parses the whole `items_json` (`jq -c ".[$i]"`) and re-serializes the whole
  growing `result` (`jq --argjson e ... '. + [$e]'`).
- The failing scenario completes, uncontended, in ~121.7s at 2828 items, and the suite's other
  scenarios stay at N <= 350 (~13-20s), which is why no earlier run surfaced the cost. Under the
  observed ~1.7x CPU oversubscription the same ~5600 short-lived `jq` spawns stretched to the
  24-minute live observation.
- No per-suite `timeout` exists anywhere upstream: `run-all.sh` invokes each suite as bare
  `bash "$suite"` at both its sequential and parallel call sites. The bound must live inside this
  suite.
- Research Recommendation 3 option (b) is adopted: prove the bound fires via a standalone stalled
  fixture driven through the *same* wrapper the real scenarios use, rather than adding a
  test-only delay hook to the production script.

Carried figures above (the ~121.7s reproduction, the N=50..2000 benchmark table, the
2828/350 item counts, line range 607-665) are **CARRIED-UNVERIFIED** from that report; Phase 2
re-derives the ones that drive decisions (the pre- and post-rewrite timings) by measurement at
implementation time.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag was set; no ROADMAP.md was
consulted.

## Goals & Non-Goals

**Goals**:
- `synthesize_citekeys()` computes the same citekey assignment in a single bulk `jq` pass, with
  output byte-identical to the current implementation for every input shape it handles.
- `test-zotero-generate-export.sh` bounds every generator invocation by wall clock and turns an
  overrun into a loud, readable FAIL (distinguishable from a crash and from a pass).
- The bound is *exercised*: a deliberately-stalled fixture makes the wrapper fire rather than
  hang, verified as a committed scenario.
- Citekey behavior is pinned by committed assertions so the rewrite cannot silently change
  ordering, collision suffixes, or fallback keys.
- The complete `verify-deploy.sh` gate set exits 0, restoring the repo-wide final-phase
  criterion the task description names as unsatisfiable today.

**Non-Goals**:
- No change to `run-all.sh` or `verify-deploy.sh` (no per-suite timeout at harness level) -- out
  of this task's file scope and a separate cross-suite decision (research Recommendation 4).
- No change to how suites are discovered or scheduled.
- No change to `curl-stub.sh`, `generate-zotero-page-fixtures.sh`, or
  `generate-zotero-sqlite-fixture.sh`.
- No test-only delay hook or artificial-stall branch inside the production generator.
- No broader refactor of `zotero-generate-export.sh` beyond `synthesize_citekeys()`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Bulk-`jq` rewrite changes disambiguation-suffix ordering or numbering | H | M | Phase 1 commits a characterization scenario pinning the exact ordered key sequence before any production edit; Phase 2 additionally diffs a golden capture of the extracted pre-rewrite function against the new one over a hand-built edge-case array |
| Bulk rewrite changes JSON object key *position* (jq appends a new key at the end) and so changes written bytes | M | L | Phase 2's golden comparison is a byte diff of the whole emitted array, not a key-set comparison, so a position change fails the check |
| Pre-existing (non-null) citation-keys stop being passed through untouched | H | L | Edge-case fixture in Phase 2 includes entries with a real key, an empty-string key, and the literal string `"null"` (which current code treats as absent -- a quirk that must be preserved) |
| A `jq` failure in the new single pass loses the whole array instead of one item | H | L | On `jq` failure the function emits a stderr diagnostic and nothing on stdout, so the existing `FINAL_COUNT` guard at the call site aborts loudly with no write (`zotero-generate-export.sh:818-822`); never `echo "[]"`, which would read as a genuinely empty library and reach the shrink guard |
| Timeout bound too tight -> suite becomes flaky on a loaded batch host | M | M | Bound set in the tens of seconds (default 60s) against a post-fix runtime measured in Phase 2, leaving >1 order of magnitude of headroom; env-overridable for unusually loaded hosts |
| Timeout bound too loose -> a future regression still looks like a hang for minutes | M | L | 60s is far below today's multi-minute-to-24-minute cost, so the regression shape this task fixes would be caught; Phase 4 records the measured whole-suite wall time so the margin is visible |
| Sibling tasks are editing the same working tree this cycle | M | M | Territory block lists no overlap with this task's two files; still re-read each file immediately before editing and stage only this task's own hunks (explicit file lists, never a directory or glob add) |
| Deployed `.claude/scripts/` copies drift from the edited source store | L | M | Edits land in `agent-system/extensions/literature/scripts/**` only; Phase 4 refreshes the deployed copies through the sanctioned deploy path if any gate reports divergence, never by hand-authoring under `.claude/**` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is fully sequential: the
characterization assertions must be green against the *unchanged* generator before the rewrite
(Phase 2) can be judged equivalent, and the timeout bound (Phase 3) must be chosen against the
*post-rewrite* runtime.

### Phase 1: Pin current citekey behavior with a characterization scenario [COMPLETED]

**Goal**: Commit assertions that capture today's citekey output exactly, while the production
script is still unchanged, so Phase 2's rewrite has a committed equivalence guard rather than a
recollection.

**Tasks**:
- [x] Re-read `agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh`
      immediately before editing (concurrent siblings share this tree). *(completed)*
- [x] Run `bash agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh itemtype-exclusion`
      and record the actual post-filter item count and the actual citekeys written for
      `CURL_STUB_ZOTERO_TOTAL=200`, by inspecting the scratch output JSON. Do not assume the
      count -- read it. *(completed: 140 post-filter items; every item collides on one base key
      "noauthornditem" (stub fixtures have no author and the title's first word is always
      "Item"); sequence is noauthornditem, noauthornditem-2, ..., noauthornditem-140 in array
      order)*
- [x] Add a `citekey-synthesis` scenario function (`t_citekey_synthesis`) that invokes
      `run_export CURL_STUB_ZOTERO_TOTAL=200 -- --orchestrator-mode true` and asserts, against
      the written export: (a) every entry has a non-empty `citation-key`; (b) keys are unique
      (`[.[].["citation-key"]] | length == (unique | length)`); (c) the keys are exactly the
      ordered sequence observed in the step above -- the un-suffixed base key first, then
      `-2`, `-3`, ... in array order (the stub's fixtures carry no author and no `issued`, so
      every item collides on one base key, which is precisely the collision path at issue).
      *(completed)*
- [x] Register the scenario in the `SCENARIOS` associative array and in `ORDER`, placing it
      early (before `short-mid-page`) so it reports before the slow scenario. *(completed)*
- [x] Add the scenario to the header comment's scenario list, matching the existing entry style.
      *(completed)*
- [x] Confirm the new scenario PASSES against the unchanged generator (it characterizes current
      behavior; a failure here means the assertions are wrong, not the generator). *(completed:
      `citekey-synthesis` PASSES in isolation)*
- [x] Commit (test file only). *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The edit is confined to one test file with no production surface, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-zotero-generate-export.sh`
is the one suite that covers that path.

**Scope Hypothesis**: That `CURL_STUB_ZOTERO_TOTAL=200` yields 140 post-filter items, and that
every fixture item lacks `author` and `issued` so all keys share one base
(`noauthor` + `nd` + first title word) -- both read from
`generate-zotero-page-fixtures.sh`'s item shape and the suite's existing 500->350 ratio, not
measured. Confirm at implementation time by running the scenario and reading the actual written
count and key list before freezing the assertions; if the count differs, assert the observed
value.

**Files to modify**:
- `agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh` - add
  `t_citekey_synthesis`, register it in `SCENARIOS`/`ORDER`, extend the header scenario list

**Verification**:
- `bash agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh citekey-synthesis`
  exits 0 and prints exactly one PASS line, in under ~15s.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-zotero-generate-export.sh`
  reports no new failures relative to the known pre-fix state (the slow `short-mid-page` scenario
  is still slow at this point -- that is expected until Phase 2).
- `git diff --staged` shows changes to the test file only.

---

### Phase 2: Replace the per-item loop with a single bulk jq pass [COMPLETED]

**Goal**: Make `synthesize_citekeys()` do all N items in one `jq` invocation, with provably
identical output and a loud failure mode.

**Tasks**:
- [x] Re-read `agent-system/extensions/literature/scripts/zotero-generate-export.sh` immediately
      before editing. *(completed)*
- [x] Capture a golden baseline of the CURRENT function: extract the
      `synthesize_citekeys()` body verbatim into a scratch script under the session scratchpad
      directory, build an edge-case fixture array covering, at minimum -- an entry with a real
      non-empty `citation-key`; one with `"citation-key": null`; one with `"citation-key": ""`;
      one with the literal string `"citation-key": "null"` (current code treats this as absent);
      two or more entries that collide on the same synthesized base key (to exercise `-2`,
      `-3`); an entry with no `author`; one with no `issued`; one with no `title`; one whose
      author family and title first word contain uppercase, punctuation, and non-ASCII
      characters (to exercise `ascii_downcase` + `gsub("[^a-z0-9]"; "")`); an entry whose
      `issued["date-parts"][0][0]` is a number rather than a string -- and record the emitted
      array to a golden file. *(completed: 10-entry fixture built in the session scratchpad;
      golden output recorded; the 3-way "jones1999collide"/"-2"/"-3" collision confirmed, and
      the literal string "null" citekey confirmed treated as absent)*
- [x] Rewrite `synthesize_citekeys()` as a single `jq` invocation (a `reduce range(0; length)`
      over the array carrying a counts object as state is the straightforward shape) preserving
      every observable behavior: input array order; first-seen-wins so the first use of a base
      key is un-suffixed and the n-th is `-n`; collision counting that includes **only** entries
      whose key is synthesized, never entries that arrived with a real key; the
      `noauthor`/`nd`/`notitle` fallbacks; `ascii_downcase` plus non-alphanumeric stripping on
      both the family name and the title's first whitespace-delimited word; `nd` for a missing or
      null year; an empty input array returning `[]` via the existing early return; and the exact
      key *position* in each emitted object. *(completed: implemented as `reduce .[] as $item`
      over the array, carrying `{out, counts}` state, rather than `reduce range(0; length)` --
      equivalent and avoids a re-index lookup per step)*
- [x] Replace the current silent per-item failure handling (`|| continue`,
      `|| echo "$result"`) with a single loud failure path: if the bulk `jq` fails, print a
      diagnostic naming the function to stderr and emit nothing on stdout, so the existing
      `FINAL_COUNT` guard at the call site (`zotero-generate-export.sh`, immediately after
      `ITEMS="$(synthesize_citekeys "$ITEMS")"`) aborts with no write. Never emit `[]` on
      failure -- that is indistinguishable from a genuinely empty library. *(completed)*
- [x] Delete the now-unused `declare -A basekey_counts` and loop locals. *(completed)*
- [x] Update the function's header comment to describe the bulk pass, keeping the documented
      contract (lower(firstAuthorLast) + year + firstTitleWord, `-2`/`-3` on collision, real keys
      untouched) unchanged. *(completed)*
- [x] Diff the new function's output against the golden capture over the edge-case fixture; it
      must be byte-identical. *(completed: byte-identical, confirmed by extracting the
      synthesize_citekeys() body from the actual edited file and diffing its output against the
      golden capture -- also confirmed byte-identical over the real 140-item
      CURL_STUB_ZOTERO_TOTAL=200 fixture from Phase 1)*
- [x] Measure and record the post-rewrite wall time of the `short-mid-page` scenario (needed as
      input to Phase 3's bound). *(completed: post-rewrite `short-mid-page` (2828 items) wall
      time measured at ~6.3s, down from the ~121.7s CARRIED-UNVERIFIED pre-rewrite figure; a
      standalone 2828-item bulk-jq-only timing came in at ~0.27s, confirming the per-item bash
      loop's process-spawn/re-serialize overhead -- not the generator's other work -- was the
      dominant cost)*
- [x] Commit (generator only). *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The change is confined to one function in one standalone script whose
signature and call site are unchanged, and it is covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-zotero-generate-export.sh`
plus `bash agent-system/extensions/core/scripts/lint-shellcheck.sh --verbose` for the shell-lint
surface (Gate 22).

**Scope Hypothesis**: That the only call site is the single
`ITEMS="$(synthesize_citekeys "$ITEMS")"` line and that the post-rewrite `short-mid-page` runtime
drops from ~122s (CARRIED-UNVERIFIED from `reports/02_...md`) to under a few seconds. Confirm at
implementation time with `grep -n synthesize_citekeys` over the generator before editing, and by
timing the scenario after the rewrite; if the measured post-fix time is not comfortably under
10s, re-examine before choosing Phase 3's bound.

**Files to modify**:
- `agent-system/extensions/literature/scripts/zotero-generate-export.sh` - rewrite
  `synthesize_citekeys()` as a single bulk `jq` pass; loud-fail instead of silent per-item
  swallow; update the function header comment

**Verification**:
- Byte-identical diff between the golden pre-rewrite capture and the new function's output over
  the edge-case fixture array (`diff` exits 0).
- `bash agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh citekey-synthesis`
  still exits 0 (Phase 1's characterization assertions unchanged and still green).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-zotero-generate-export.sh`
  exits 0.
- `bash agent-system/extensions/core/scripts/lint-shellcheck.sh --verbose` reports the generator
  clean.
- `time bash agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh short-mid-page`
  passes, with the measured wall time recorded in the phase notes.

---

### Phase 3: Bound every generator invocation and prove the bound fires [NOT STARTED]

**Goal**: A wall-clock overrun in this suite becomes a readable FAIL with a definite exit, and a
committed scenario demonstrates the wrapper actually fires rather than hanging.

**Tasks**:
- [ ] Re-read the test file immediately before editing.
- [ ] Introduce a single bound variable near the suite's other configuration
      (`EXPORT_TIMEOUT="${ZOTERO_EXPORT_TEST_TIMEOUT:-60}"`), documented in the header comment
      with the rationale: comfortably above the post-Phase-2 runtime measured above, far below
      the pathological pre-fix cost.
- [ ] Wrap both generator invocation sites in `timeout "$EXPORT_TIMEOUT"`: the
      `env "${envs[@]}" "$GENERATOR_SH" "$@"` call inside `run_export`, and the direct
      `"$GENERATOR_SH" --orchestrator-mode true` call inside `t_path3_itemtype`. Confirm by
      grep that no third invocation site exists.
- [ ] Add shared handling so an `rc` of 124 produces a loud FAIL naming the bound and the
      scenario (e.g. "exceeded the ${EXPORT_TIMEOUT}s wall-clock bound (timeout rc=124) -- the
      generator did not terminate"), distinct from both a pass and an ordinary non-zero exit.
      Keep the existing `RC`/`ERR` globals' contract intact so no existing scenario's
      expected-non-zero assertions (`loud-fail-transport`, `loud-fail-malformed`,
      `shrink-guard-blocks`) start misreading 124 as their own expected code.
- [ ] Add a `timeout-guard-fires` scenario (`t_timeout_guard_fires`) that drives a deliberately
      stalled command (a plain `sleep` well past the bound) through the *same* timeout wrapper
      with a deliberately tiny bound (e.g. `ZOTERO_EXPORT_TEST_TIMEOUT=2`), and PASSES only if
      the wrapper returns 124 within a few seconds -- proving the mechanism converts an overrun
      into a bounded failure. Add no stall hook to the production generator.
- [ ] Assert in that scenario that its own wall time stayed under a small ceiling (e.g. 10s), so
      a wrapper that silently stopped bounding would fail rather than pass slowly.
- [ ] Register `timeout-guard-fires` in `SCENARIOS` and `ORDER`, and add both new scenarios'
      descriptions to the header comment list.
- [ ] Commit (test file only).

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: The edit is confined to one test file with no production surface, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-zotero-generate-export.sh`
is the one suite covering it.

**Scope Hypothesis**: That exactly two generator invocation sites exist in the test file
(`run_export`'s `env ... "$GENERATOR_SH"` call and `t_path3_itemtype`'s direct call). Confirm at
implementation time with `grep -n '"$GENERATOR_SH"'` over the test file before wrapping; wrap
every site the grep reports, not two by assumption.

**Files to modify**:
- `agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh` - add
  `EXPORT_TIMEOUT`, wrap both generator invocations in `timeout`, add rc=124 loud-FAIL handling,
  add `t_timeout_guard_fires`, register both new scenarios, extend the header comment

**Verification**:
- `bash agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh timeout-guard-fires`
  exits 0, prints one PASS, and completes in under ~10s (the bound fired; it did not hang).
- A deliberate temporary experiment confirms the real path is wrapped: run one scenario with
  `ZOTERO_EXPORT_TEST_TIMEOUT=1` and observe the rc=124 loud FAIL message naming the bound, then
  revert the experiment (no committed change).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-zotero-generate-export.sh`
  exits 0 with every scenario reporting, and no scenario's expected-exit-code assertion
  regressed.

---

### Phase 4: Whole-suite determinism and the complete gate set [NOT STARTED]

**Goal**: Prove the suite terminates with a definite result inside a wall-clock bound and that
the repo-wide final-phase criterion ("verify-deploy.sh exits 0 -- the complete gate set") is
satisfiable again.

**Tasks**:
- [ ] Run the whole suite under an outer bound:
      `time timeout 600 bash agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh`
      and confirm exit 0 (not 124) with every scenario reporting a definite PASS/FAIL; record the
      measured wall time and the margin against the 600s outer bound.
- [ ] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh` (all suites, no `--only`)
      and confirm exit 0, so the suite's new behavior holds under the harness's own parallel
      scheduling rather than only in isolation.
- [ ] Run the complete gate set with no `--skip-slow` and no `--only-gate`:
      `bash .claude/scripts/verify-deploy.sh` (source-store path:
      `bash agent-system/extensions/core/scripts/verify-deploy.sh`) and confirm exit 0. Record
      the gate count and the total wall time.
- [ ] If any gate reports divergence between the edited source store and the deployed
      `.claude/scripts/zotero-generate-export.sh` /
      `.claude/scripts/tests/test-zotero-generate-export.sh` copies, refresh them through the
      sanctioned deploy path. Never hand-author under `.claude/**`
      (`rules/source-store-deploy-boundary.md`).
- [ ] Record in the task summary: the measured pre-fix vs post-fix `short-mid-page` timings, the
      whole-suite wall time, the chosen bound and its headroom, and the evidence that the bound
      fires.
- [ ] Commit the completion (no production or test source changes expected in this phase beyond
      a possible deploy refresh).

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Files to modify**:
- none planned -- verification-only phase; a deploy refresh of the two deployed `.claude/scripts/`
  copies through the sanctioned deploy path is the only write this phase may produce

**Verification**:
- `timeout 600 bash agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh`
  exits 0 (a definite pass, not 124), with the measured wall time recorded.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0.
- `bash .claude/scripts/verify-deploy.sh` exits 0 -- the complete gate set, every gate run, no
  `--skip-slow` and no `--only-gate` narrowing.
- The `timeout-guard-fires` scenario is among the reported PASSes in the full-suite run, so the
  bound's liveness is attested by the same run that attests termination.

---

## Testing & Validation

- [ ] `citekey-synthesis` scenario passes against the unchanged generator (Phase 1) and still
      passes after the rewrite (Phase 2) -- the equivalence guard.
- [ ] Byte-identical golden diff of the extracted pre-rewrite function vs. the bulk-`jq` function
      over an edge-case fixture covering real/null/empty/`"null"` existing keys, base-key
      collisions, missing author/year/title, and punctuation/case stripping.
- [ ] `timeout-guard-fires` passes, in seconds, proving an overrun becomes rc=124 and a loud FAIL.
- [ ] Every pre-existing scenario still passes with its original expected exit code
      (`boundary-128kib`, `short-mid-page`, `loud-fail-transport`, `loud-fail-malformed`,
      `itemtype-exclusion`, `stub-dispatch`, the three `shrink-guard-*`, `path3-itemtype`,
      `pre-existing-suite`).
- [ ] `lint-shellcheck.sh --verbose` clean on both edited files.
- [ ] `run-all.sh` (full, parallel) exits 0.
- [ ] `verify-deploy.sh` complete gate set exits 0.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/zotero-generate-export.sh` - bulk-`jq`
  `synthesize_citekeys()` with a loud failure path.
- `agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh` - bounded
  generator invocations, rc=124 loud FAIL handling, and two new scenarios
  (`citekey-synthesis`, `timeout-guard-fires`).
- `specs/404_zotero_export_test_hangs_full_gate/summaries/01_*-summary.md` - completion summary
  recording the measured timings, the chosen bound and its headroom, and the bound-fires evidence.
- Possible deploy refresh of `.claude/scripts/zotero-generate-export.sh` and
  `.claude/scripts/tests/test-zotero-generate-export.sh` (generated, not hand-authored).

## Rollback/Contingency

Each phase commits independently and touches one file, so the ordinary contingency is a forward
fix on the single failing phase rather than a tree-wide revert.

- If the bulk-`jq` rewrite cannot be made byte-identical over the edge-case fixture, keep Phases
  1, 3, and 4 (the bound alone already converts the hang into a readable, bounded result) and
  revert only Phase 2's commit, recording the residual slowness as a known cost. The bound must
  then be set above the measured ~122s rather than at 60s, and that choice documented.
- If the timeout wrapper interferes with an existing scenario's expected exit code, narrow the
  wrapper to `run_export` only and bound `t_path3_itemtype` separately.
- If a rollback of uncommitted work is genuinely required mid-phase, follow
  `context/contracts/recovery.md`'s rollback rung for the exact `git-snapshot.sh` invocation
  shape (including its out-of-scope override flag); do not take a bare precautionary snapshot in
  its reverting default mode. For an ordinary defensive checkpoint before a risky edit, use
  `bash .claude/scripts/git-snapshot.sh --no-revert`.
