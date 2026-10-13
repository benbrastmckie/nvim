# Research Report: Identical Dispatch Halt Does Not Fire

**Task**: 351 - Repair the IDENTICAL DISPATCH HALT mechanism in orchestrate-cycle-plan.sh, which is implemented but never fires
**Started**: 2026-10-08T00:45:22Z
**Completed**: 2026-10-08T00:58:00Z
**Effort**: Small (single-line regex fix + comment correction + one new regression fixture); the
  diagnosis dominates the cost, the fix itself is a one-line change.
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`,
  `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`,
  `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`,
  `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`,
  `agent-system/extensions/core/scripts/tests/known-failures.txt`
- `git log -S`, `git log --oneline`, `git show -s --format` for bisection by evidence
- Live reproduction: ran the real suite, then a workdir-preserving copy of it, diffed the two
  real composed dispatch files the SUT itself produced on cycle 1 vs. cycle 2, and hashed both
  with and without a corrected strip pattern

**Artifacts**:
- This report: `specs/351_identical_dispatch_halt_does_not_fire/reports/01_identical-dispatch-halt-regression.md`

**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause found and proven, not inferred.** `cycle_plan_dispatch_hash()` (the normalizer
  `orchestrate-cycle-plan.sh` uses to decide whether two dispatches are "identical") strips only
  the two Identity-block lines that were the sole per-cycle-varying content when the halt
  mechanism was written (`- dispatch_seq: N` / `- dispatch_start_ts: N`). A later, unrelated
  commit added a THIRD per-cycle-varying line to every composed dispatch file — the Issue Log
  instruction block's `[--dispatch-seq ${dispatch_seq}]` placeholder — without updating the
  normalizer. That line is never stripped, so the content hash of cycle N's dispatch never equals
  cycle N+1's hash for a genuinely unchanged task, the streak counter resets to 1 on every cycle
  instead of reaching 2, and the halt's own `_idh_streak -ge 2` trigger is simply never satisfied.
- **The regression is dated precisely.** `git log -S'[--dispatch-seq' -- orchestrate-build-dispatch.sh`
  returns exactly one commit: `21f282089` ("task 329 phase 5: thread issue log instruction to
  every dispatched agent", 2026-10-03). The halt landed 2026-09-25 (`167eb53d0`) and the Group 29
  reproduction tests landed 2026-09-28 (`43d469cc6`), both confirmed green at the time (task
  266's own summary records "300 passed, 0 failed"). `21f282089` is the regressing commit.
- **None of the three candidate culprits named in the dispatch — the trigger predicate, the
  back-out block, or the call site — is broken.** All three are correct as written and are never
  reached with a wrong value; they are starved of the `_idh_streak >= 2` input they need because
  the hash equality check one level up always reports "different" for genuinely identical
  dispatches. See "Which Part Is Broken, With Evidence" below.
- **The design intent is unchanged; the fixtures are not stale.** `docs/architecture/
  orchestrate-state-machine.md`'s own description of the mechanism ("keyed on the composed
  dispatch file's own content hash... halts the task for the rest of the run after a second
  consecutive identical dispatch") still matches what the code is trying to do and what Group
  28/29 assert. The recently-added "Not to be conflated with IDENTICAL DISPATCH HALT" note is a
  comparison against the unrelated `stall_suspected` mechanism and does not touch this contract.
  Group 28/29's fixtures construct genuinely identical dispatches (same task, same state, no
  real content change) — confirmed directly by diffing the two dispatch files the SUT itself
  wrote during a live repro run.
- **Recommended fix**: extend `cycle_plan_dispatch_hash()`'s strip pattern to also remove the
  Issue Log's `[--dispatch-seq N]` placeholder (or the whole boilerplate `--what-happened` line
  it lives on), and correct the function's own comment, which currently makes the now-false claim
  that the two already-stripped lines are the *only* per-cycle-varying content. Add a dedicated
  regression case to Group 27 (or a new sub-case) that pins exactly this failure mode: two composed
  dispatch files differing ONLY in `dispatch_seq`/`dispatch_start_ts` AND the Issue Log's
  `[--dispatch-seq N]` placeholder must hash identically.

## Context & Scope

Task 351's own dispatch describes a known-failures.txt-registered suite regression:
`test-orchestrate-cycle-plan.sh` fails 14 of 349 assertions, all in Group 28 (research-phase halt)
and Group 29 (implement-phase halt composed with the deploy-pending streak-freeze backstop, Arms
B/C/D). The mechanism ("IDENTICAL DISPATCH HALT") is present in the script, in the test suite,
and in the architecture doc — this is a regression in live code, not an unimplemented feature,
per the dispatch's own `git log -S` evidence pointing at the original feature commit (task 259
phase 2) and the later reproduction-test commit (task 266 phase 5).

This research (1) reproduced the failure live against the real, unstubbed collaborator scripts
(not just reading code), (2) isolated the exact byte-level difference between two "identical"
dispatch files that the guard was supposed to recognize as a repeat, (3) identified the
introducing commit by content-anchored `git log -S`, and (4) checked the two architecture
questions the dispatch asks to be settled before any fix lands (doc-vs-code drift, fixture
staleness).

**Out of scope for this research pass**: writing the fix itself, editing
`known-failures.txt`, and redeploying — those are implementation-phase actions. This report
gives the plan everything needed to do all of that in one phase.

## Findings

### Codebase Patterns

**The three-part mechanism, read end to end** (`orchestrate-cycle-plan.sh` lines ~2491-2583):

1. `cycle_plan_dispatch_hash()` (line 2024) computes `sha256sum` over the composed dispatch
   file's content after stripping lines matching
   `^- dispatch_seq: [0-9]+$|^- dispatch_start_ts: [0-9]+$`. Its own comment (lines 2009-2019)
   asserts this is a complete enumeration: "within one `/orchestrate` run, for an otherwise-
   unchanged task/phase, ONLY `- dispatch_seq: N` and `- dispatch_start_ts: N` vary — every
   other line... is reproduced byte-for-byte across cycles." **This claim was true when written
   (2026-09-25) and is false today.**
2. The accounting block (lines 2514-2549) computes `_idh_hash`, compares it against
   `last_dispatch_hash[$t]` (persisted in the per-session `mt_state_file`, keyed by `session_id`
   — confirmed via `runtime_mt_state_path()`, so it correctly survives across cycles of the same
   `/orchestrate` invocation), and increments `identical_dispatch_streak[$t]` only when the hash
   AND the phase both match the previous cycle's. A deploy-pending freeze backstop (lines
   2497-2513, 2534-2537) holds the streak steady rather than resetting it when the task's own
   `.return-meta.json` carries `deploy_pending: true` — this logic is also correct and is simply
   never exercised because the streak never gets past 1 in the first place.
3. The halt block (lines 2554-2583) fires when `_idh_streak -ge 2`: removes the just-composed
   dispatch file, restores the pre-dispatch `active_projects[]` entry (status/last_updated/
   session_id), releases the task lock, records the task in `identical_dispatch_halted[]`, and
   emits a `blocked[]` row — all logic here is correct and unreached.

**Live reproduction, byte-for-byte.** I ran the real suite once (confirmed the exact 335
passed/14 failed split named in the dispatch), then re-ran a workdir-preserving copy through
Group 28's own fixture (candidate #2801, two cycles, `--no-plan-cache`, same `--session`) using
the REAL `orchestrate-build-dispatch.sh` and `update-task-status.sh` (Group 27's preamble
restores these from stubs back to the real scripts, and nothing re-stubs them before Group 28).
`diff` on the two composed dispatch files it wrote:

```
13,14c13,14
< - dispatch_seq: 1
< - dispatch_start_ts: 1791420814
---
> - dispatch_seq: 2
> - dispatch_start_ts: 1791420815
39c39
<     --what-happened "..." [--phase research] [--dispatch-seq 1] \
---
>     --what-happened "..." [--phase research] [--dispatch-seq 2] \
```

Hashing both files through the CURRENT strip pattern produces two different digests
(`7f85113c...` vs `5a33a237...`). Hashing both through the strip pattern extended to also drop
the `[--dispatch-seq N]` line produces the SAME digest for both
(`386ce8d6...` = `386ce8d6...`). This is the defect, demonstrated mechanically rather than
inferred from reading.

**Where the extra line comes from.** `orchestrate-build-dispatch.sh` line 512:
```bash
echo "    --what-happened \"...\" [--phase ${phase}] [--dispatch-seq ${dispatch_seq}] \\"
```
This is part of the "Issue Log" instructional block every dispatch file now carries (the
`issue-record.sh` invocation template shown to the dispatched agent), and it is the ONLY place
in `orchestrate-build-dispatch.sh` where `${dispatch_seq}` is interpolated into the dispatch
BODY outside the already-stripped `- dispatch_seq: ${dispatch_seq}` Identity line (confirmed by
grepping every `${dispatch_seq}`/`${dispatch_start_ts}`/`${session_id}` interpolation site in the
script — `dispatch_file="${dispatch_dir}/${dispatch_seq}.md"` is the output FILENAME, never
echoed into the file's own content, so it never reaches the hash at all).

**Dated by evidence, not inference:**
```
167eb53d0  2026-09-25  task 259 phase 2: halt the run for a task after N=2 consecutive identical dispatches
43d469cc6  2026-09-28  task 266 phase 5: add Group 29 reproduction and regression tests
21f282089  2026-10-03  task 329 phase 5: thread issue log instruction to every dispatched agent
```
`git log -S'[--dispatch-seq' --oneline -- orchestrate-build-dispatch.sh` returns exactly
`21f282089` as the sole commit ever introducing this substring into the file. Task 266's own
summary (`specs/archive/266_deploy_pending_vs_identical_dispatch_guard/summaries/
01_deploy-pending-guard-composition-fix-summary.md`, line 91) records the suite at
"300 passed, 0 failed" at that commit — so the suite was fully green through 2026-09-28 and the
only commit between then and the 2026-10-06 discovery sweep that could plausibly have broken this
specific hash-equality contract is `21f282089`. The hypothesis is further corroborated
structurally: `21f282089`'s own diff stat shows it touching `orchestrate-build-dispatch.sh`
(+18 lines) and its own test file, but NOT `orchestrate-cycle-plan.sh` — i.e. it changed what a
dispatch file CONTAINS without anyone revisiting the sibling script's hash normalizer that reads
that content, which is exactly the shape of bug this is.

### Which Part Is Broken, With Evidence

The dispatch asks explicitly: trigger predicate, back-out block, or call site? **None of the
three.** The defect is one level upstream of all three, in the hash-equality INPUT the trigger
predicate consumes:

- Trigger predicate (`_idh_streak -ge 2`, line 2560): correct. Verified by Group 27 Cases C/D
  (still passing, unaffected by this bug) that streak accounting itself works correctly for a
  single dispatch and for a genuinely-different one.
- Back-out block (lines 2562-2581): correct and unreached. Confirmed by code reading — nothing in
  it depends on any value that could itself be wrong; it is simply never entered because its
  guard condition is never true.
- Call site: correct. The block executes in the right place in the loop (immediately after
  `dispatch_file` resolution, before any budget-charge side effect), exactly as its own comment
  describes and as Group 27 Case A/B/C/D exercise without issue.
- **The actual broken part**: `cycle_plan_dispatch_hash()`'s strip-pattern regex (line 2027) is
  stale against a sibling script's independent addition. This is "one early guard...
  short-circuiting," exactly as the dispatch's "Why It Matters" section hypothesizes — the guard
  in question is the hash-equality comparison at line 2533, not the halt predicate itself. Every
  one of the seven observed back-out-step failures (dispatch issued anyway, no blocked[] row, no
  stderr notice, `.dispatch/N.md` not removed, lock still held, `dispatch_seq_counter` advancing,
  `cycle_counts` advancing) and the third-cycle non-exclusion all follow from this single upstream
  cause: `_idh_streak` is reset to 1 every cycle instead of reaching 2, so the entire halt block is
  simply never entered — consistent with the dispatch's own observation that seven distinct
  symptoms failing together "suggests one early guard... short-circuiting, not seven separate
  bugs."

### Architecture Doc and Fixture Validity (the two "Also Settle" questions)

- **Doc vs. code**: `docs/architecture/orchestrate-state-machine.md`'s description of the halt
  ("a cross-cycle convergence guard, keyed on the composed dispatch file's own content hash...
  halts the task for the rest of the run after a second consecutive identical dispatch") matches
  the code's intent exactly and is unaffected by this bug — the bug is in the hash INPUT, not in
  what the mechanism is supposed to do. The adjacent "Not to be conflated with IDENTICAL DISPATCH
  HALT" note is purely a disambiguation against the unrelated `stall_suspected` liveness signal
  (a within-dispatch idle-agent re-prompt, a completely different trigger and a completely
  different remedy) and makes no claim about the hash normalizer's own correctness. No doc change
  is needed to the mechanism's description; no contract changed.
- **Fixture staleness**: Group 28/29's fixtures still construct genuinely identical dispatches.
  The task's own state (status, description, dependencies, file_scope) is unchanged across the
  two cycles in every arm; the only thing that legitimately changes between cycles is exactly the
  kind of bookkeeping noise (`dispatch_seq`, `dispatch_start_ts`, and now the Issue Log's
  placeholder echo of `dispatch_seq`) the hash function was explicitly designed to normalize away.
  The fixtures are correct; the normalizer's enumeration of "what varies per cycle" is
  incomplete. No fixture change is needed to Group 28/29 themselves — they should start passing
  once the normalizer is corrected.

### External Resources

Not applicable — this is a pure in-repo shell regression with no external dependency surface.

### Working-Tree State Encountered (file-ownership check required by the dispatch)

The dispatch explicitly warns not to assume the concurrent, uncommitted H1 marker/handoff-
mismatch fix to this same file is gone, and to resolve its ownership before editing the file if
it is still pending. **It is still pending.** `git diff -- orchestrate-cycle-plan.sh` shows
exactly the described change at the H1 block (~line 2178): replacing
`x=$(grep -c ... || echo 0)` with `x=$(grep -c ...) || x=0`, fixing a real two-line-output bug in
`grep -c`'s interaction with `|| echo 0` (grep -c already prints "0" before exiting 1 on zero
matches, so the old idiom emitted "0\n0"). I searched every active task's `file_scope` (none
list `orchestrate-cycle-plan.sh` as `implementing`/`in_progress` other than this task itself) and
every active task's description (`jq` full-text search across `active_projects[].description`
for `grep -c`/`H1 MARKER`/`MARKER/HANDOFF`) and found no claimant. It is orphaned — most likely
left over from a prior session that diagnosed but did not land the fix. It is mechanically
independent of this task's own fix (different code block, ~300 lines away, touching a different
variable namespace `h1_*` vs. `_idh_*`), so it poses no merge-conflict risk to this task's own
edit. **Recommendation for the plan**: land it as its own small, separately-staged commit before
(or alongside, in its own hunk) this task's own fix, rather than silently absorbing it into a
commit whose message describes only the identical-dispatch halt repair — the H1 fix is real,
correct, and otherwise has no owner to land it.

### Suite and Tooling Notes

- `shellcheck` is referenced by the acceptance criteria but is not currently resolvable on
  PATH in this environment (`/nix/store/.../shellcheck-0.11.0-bin/bin/shellcheck: No such file or
  directory` — a stale Nix store path). The implementation phase should re-check this before
  relying on a shellcheck gate; if still broken, note it as an environment gap rather than skip
  the check silently.
- Live reproduction left no stray files: a temporary copy of the test harness used to preserve
  the sandbox `$WORKDIR` for inspection was deleted after use, and the two `mktemp -d` sandboxes
  it created were removed.

## Recommendations

1. **Fix the normalizer, not the halt logic.** In `cycle_plan_dispatch_hash()`
   (`orchestrate-cycle-plan.sh` ~line 2027), extend the `grep -v -E` strip pattern to also remove
   the Issue Log's per-cycle `[--dispatch-seq N]` placeholder line, e.g. adding an alternation
   such as `\[--dispatch-seq [0-9]+\]` (matched anywhere in the line, since the placeholder is
   embedded mid-line rather than being the whole line) to the existing
   `^- dispatch_seq: [0-9]+$|^- dispatch_start_ts: [0-9]+$` pattern. Confirm the exact anchor
   choice against the literal boilerplate text in `orchestrate-build-dispatch.sh` line 512 at
   implementation time (the text may have additional characters that need escaping in the
   chosen regex flavor).
2. **Correct the now-false comment** directly above `cycle_plan_dispatch_hash()` (lines
   2009-2019), which currently asserts the two Identity lines are the ONLY per-cycle-varying
   content. Update it to name all three varying locations and note which commit introduced the
   third one, so a future addition of per-cycle content elsewhere in
   `orchestrate-build-dispatch.sh` is less likely to repeat this exact regression silently.
3. **Add a comment pointer from `orchestrate-build-dispatch.sh`'s Issue Log block (line ~512) back
   to `cycle_plan_dispatch_hash()`'s strip pattern**, so a future editor who adds yet another
   per-cycle-varying interpolation to the dispatch body is warned to update the normalizer in the
   same change — this is the structural fix that prevents a THIRD recurrence of this exact defect
   class, not just the second.
4. **Add a regression fixture** (most naturally as a new Group 27 Case, since that group already
   unit-tests `cycle_plan_dispatch_hash()`'s normalizer in isolation per Case A) asserting: two
   dispatch-file fixtures differing ONLY in `dispatch_seq`/`dispatch_start_ts` in the Identity
   block AND in the Issue Log's `[--dispatch-seq N]` placeholder must hash identically. This pins
   the exact failure mode found here (a THIRD varying location, not just the two original ones)
   independently of Group 28/29's full live pipeline, so a future similar addition fails fast in
   Group 27 rather than silently reappearing in Group 28/29's much more expensive live arms.
5. **Re-run the full suite after the fix** and confirm 349/349. Expect Group 28 and all of Group
   29's Arms B/C/D to flip to PASS with no other change, since the root cause is singular and
   upstream of all fourteen failing assertions (see "Which Part Is Broken" above).
6. **Close out `known-failures.txt`'s row** per the dispatch's REVISION section: since this is
   fixable (not a design-intent change), the row should be DELETED once the suite is green under
   `tests/run-all.sh` — not updated to carry this task's slug, since that owner field is only for
   a FORMAL ACCEPTANCE path, which does not apply here (the behavior being asserted is correct and
   achievable, not wrong).
7. **Resolve the orphaned H1 fix's landing** as its own commit (see "Working-Tree State
   Encountered" above) before or alongside this task's own commit, to avoid conflating two
   unrelated fixes to the same file under one commit message, per
   `context/standards/git-staging-scope.md`'s scoped-commit discipline.

## Decisions

- **The halt mechanism's trigger predicate, back-out block, and call site are all correct and
  unmodified by the forthcoming fix.** Only `cycle_plan_dispatch_hash()`'s strip pattern (and its
  adjacent stale comment) needs to change.
- **No change to `docs/architecture/orchestrate-state-machine.md`'s description of the halt is
  warranted.** The doc's contract and the code's intent agree; the "Not to be conflated" note is
  unrelated and does not touch this mechanism's semantics.
- **No change to Group 28/29's fixtures is warranted.** They construct genuinely identical
  dispatches; the normalizer's enumeration of what counts as "per-cycle noise" is what is
  incomplete.
- **The root cause is a single defect, not seven.** All fourteen failing assertions and the
  dispatch's seven-item symptom list trace to one upstream cause: the hash-equality check at
  line 2533 never reports a match for a genuinely identical dispatch once a dispatch file
  contains the Issue Log's `[--dispatch-seq N]` placeholder (introduced 2026-10-03,
  commit `21f282089`).
- **`known-failures.txt`'s row for this suite is a FIX-and-delete case**, not a formal-acceptance
  case — the asserted behavior is correct and achievable, confirmed by live reproduction.

## Risks & Mitigations

- **Risk**: an overly broad strip-pattern addition could accidentally normalize away a
  genuinely meaningful difference (e.g. if a future dispatch body legitimately contains the
  literal substring `[--dispatch-seq N]` for an unrelated reason, such as inside a task
  description being quoted verbatim). **Mitigation**: anchor the new alternation as tightly as
  practical to the actual boilerplate line shape (the full `--what-happened "..." [--phase X]
  [--dispatch-seq N] \` line, not a bare substring match), and prefer stripping the whole
  boilerplate line over just the numeric placeholder, since the whole line is itself invariant
  template text contributed by `orchestrate-build-dispatch.sh`, never task-authored content.
- **Risk**: the orphaned H1 fix could be silently lost (not landed by anyone) or could be landed
  carelessly in a way that conflates two unrelated defect fixes in one commit, muddying git
  history and this task's own commit attribution. **Mitigation**: land it as an explicit, separate
  staged commit (see Recommendation 7) with its own descriptive message, before this task's own
  fix is committed.
- **Risk**: a future addition to `orchestrate-build-dispatch.sh` could reintroduce a fourth
  per-cycle-varying location and silently regress the guard again, exactly as happened here.
  **Mitigation**: Recommendation 3 (back-pointer comment) plus Recommendation 4 (fast, isolated
  Group 27 regression case) together make the next such addition fail a cheap unit-style test
  immediately rather than silently degrading a live-pipeline guard that nothing else exercises
  end-to-end.

## Context Extension Recommendations

- **Topic**: cross-script content-hashing contracts (a script that computes a digest over
  content another script generates, where the generating script can silently invalidate the
  digest's normalization assumptions without either script's own tests catching it).
- **Gap**: no existing context file documents this specific "normalizer staleness" failure
  shape, which is a general risk whenever one script hashes/diffs content produced by a sibling
  script's own template. This repo does not currently have a named pattern for "when you add
  per-invocation-varying content to a template, check whether any other script normalizes that
  template's content" as a generalizable checklist item.
- **Recommendation**: if this failure shape recurs elsewhere (worth a `grep` for other
  `sha256sum`/content-normalizer patterns under `agent-system/extensions/core/scripts/` during
  the fix), consider a short pattern note under `context/patterns/` naming the convention: any
  script that strips known-varying lines before hashing/diffing another script's generated
  output should carry a comment in the GENERATING script pointing back to the normalizer, not
  just a comment in the normalizer listing what it strips. This report's Recommendation 3 above
  is one concrete instance of applying that convention here, but the convention itself is not yet
  written down anywhere durable.

## Appendix

### Commands/Queries Used

```bash
git diff -- agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh
jq -r '.active_projects[] | select((.file_scope // []) | any(contains("orchestrate-cycle-plan"))) | ...' specs/state.json
grep -rl "grep -c.*echo 0\|h1_marker_completed_count\|MARKER/HANDOFF MISMATCH" specs/
grep -n "IDENTICAL DISPATCH" agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh
grep -ni "identical.dispatch\|_idh_" agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh
bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh   # live run, 335 passed / 14 failed, matches dispatch exactly
grep -n "^\[FAIL\]" <run log>
# Workdir-preserving repro: copied the suite, disabled its cleanup trap, inserted an early exit
# right after Group 28's cycle-2 assertions, ran it, then:
diff "$WORKDIR/specs/2801_g28_halt/.dispatch/1.md" "$WORKDIR/specs/2801_g28_halt/.dispatch/2.md"
grep -v -E '^- dispatch_seq: [0-9]+$|^- dispatch_start_ts: [0-9]+$' <file> | sha256sum         # differs
grep -v -E '^- dispatch_seq: [0-9]+$|^- dispatch_start_ts: [0-9]+$|\[--dispatch-seq [0-9]+\]' <file> | sha256sum  # identical
git log -S'[--dispatch-seq' --oneline -- agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh
git show -s --format='%ci %H %s' 167eb53d0 43d469cc6 21f282089
grep -n "349/349\|test-orchestrate-cycle-plan" specs/archive/266_deploy_pending_vs_identical_dispatch_guard/summaries/*.md
```

### References

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` lines 2008-2030 (hash
  normalizer), 2491-2583 (Fix 2 accounting + halt block)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` line 512 (Issue Log
  `[--dispatch-seq N]` placeholder, the regression source)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` Groups 27, 28, 29
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`, "Not to be
  conflated with IDENTICAL DISPATCH HALT" subsection
- `agent-system/extensions/core/scripts/tests/known-failures.txt` line 35 (this suite's row)
- `specs/archive/266_deploy_pending_vs_identical_dispatch_guard/summaries/
  01_deploy-pending-guard-composition-fix-summary.md` (300/300 green at the time, corroborating
  the regression window's lower bound)
- Commits: `167eb53d0` (halt feature, 2026-09-25), `43d469cc6` (Group 29 tests, 2026-09-28),
  `21f282089` (regressing commit, 2026-10-03)
