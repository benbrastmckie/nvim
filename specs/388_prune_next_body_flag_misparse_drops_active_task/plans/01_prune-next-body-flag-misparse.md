# Implementation Plan: Task #388

- **Task**: 388 - Fix prune_next_body() mis-parsing a Run line when a CLI flag precedes the rationale comment.
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/388_prune_next_body_flag_misparse_drops_active_task/reports/01_prune_next_body_flag_misparse.md
- **Artifacts**: plans/01_prune-next-body-flag-misparse.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`prune_next_body()`'s `gsub(/[ \t]/, "", tasklist)` strips the separator space between a Run
line's comma-separated task-id list and a trailing CLI flag, fusing them into one token
(`"714 --hard"` -> `"714--hard"`) that can never match the plain-numeric `active[]` lookup. The
result is silent content loss: an active task vanishes from the Run order, and in the
single-task case the whole line disappears, with no error and exit 0. The same root cause
corrupts the sibling `count_pruned_next_ids()`, whose fused token makes `jq --argjson` exit
non-zero and be read as "not active," so the diagnostic `pruned=`/`retained=` stderr counters
mis-report the very run that lost content.

The fix segments the flag portion off the id list before whitespace-stripping, in both
functions, re-splices it verbatim into the partial-keep output branch, and adds a fail-safe
guard so an id token this parser does not understand causes the line to pass through unchanged
with a stderr warning rather than being dropped. Tests then cover the six scenarios across both
the classic and stage layouts, and `roadmap-format.md`'s Next Grammar is extended to formally
admit the flag segment that live roadmaps already author.

### Research Integration

Key findings carried into this plan from the research report:

- Defect site: `agent-system/extensions/core/scripts/roadmap-integration.sh`, `prune_next_body()`
  (the `gsub(/[ \t]/, "", tasklist)` line inside its awk program). The deployed mirror
  `.claude/scripts/roadmap-integration.sh` was confirmed byte-identical at research time, so the
  source store is the canonical edit target and a redeploy propagates the fix.
- Layout independence confirmed at the call sites: `mode_prune_classic()` and
  `mode_prune_stage()` both invoke the identical, unmodified function.
- Three distinct failure shapes: (1) the `kept == n2` verbatim-passthrough branch can never fire
  when a flag is present, so an all-active flagged line is still rewritten; (2) the partial-keep
  branch rebuilds the line from matched ids only, silently discarding the flag; (3) a flagged
  single-task line whose one task is active yields `kept=0, n2=1`, so neither output branch
  fires and the entire line vanishes.
- Sibling defect in `count_pruned_next_ids()` (same root cause, diagnostic counters only, no
  file-content effect).
- Zero existing flag-bearing fixtures in either `--prune` test group (classic "Case group 3",
  stage "Phase 5"), which is why this reached a live file undetected.
- The documented Next Grammar (`^/orchestrate ([\d, ]+)(\s{3}# (.+))?$`) does not admit a flag
  segment at all, while live roadmaps author one.

**One research recommendation is deliberately narrowed here.** Recommendation 1 proposes
splitting the pre-rationale portion "on the first run of whitespace" into id list and flags
remainder. That is incorrect against the documented grammar: `([\d, ]+)` admits intra-list
spaces, so `/orchestrate 716, 714 --hard` would split into `tasklist="716,"` and
`flags="714 --hard"` — a second, newly-introduced content-loss path. This plan anchors the
segmentation on the first whitespace-preceded `-` instead (see Phase 1).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap consultation was performed
and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- `prune_next_body()` round-trips a CLI flag segment losslessly in every output branch, for both
  the classic and stage layouts.
- A flagged Run line whose every named task is active survives byte-for-byte unchanged.
- A flagged Run line with mixed active/terminal ids keeps the active ids and the flag segment,
  with the exact `   # ` rationale separator preserved.
- A flagged single-task Run line naming an active task can never vanish.
- `count_pruned_next_ids()` only ever feeds a plain numeric id to `jq --argjson`, so the
  `pruned=`/`retained=` stderr markers are accurate on flag-bearing input.
- An id token the parser cannot classify is fail-safe: the line passes through unchanged and a
  warning goes to stderr; content is never silently dropped.
- Test coverage in both `--prune` groups for: flagged + comment (mixed ids), flagged + comment
  (all active), flagged without comment, unflagged with comment (regression guard), multiple
  flags, and the single-task total-disappearance case.
- `roadmap-format.md`'s Next Grammar and Parsing Patterns Summary formally admit the optional
  flag segment (research Recommendation 4, option (a)).

**Non-Goals**:

- Broadening the Next Grammar beyond an optional flag segment (no arbitrary trailing text).
- Fixing `covered_ids_from()` (`roadmap-integration.sh`, around line 523). It scrapes
  `grep -oE '[0-9]+'` across the whole Run line including the rationale comment, so any digit in
  authored rationale prose — or a numeric flag argument such as `--max-tasks 8` — is
  mis-attributed as a covered task id. This is a pre-existing, independent defect with a
  different symptom (over-counted coverage suppressing a coverage-appendix entry) and a wider
  blast radius through `--regenerate`; it is outside this task's declared defect. Phase 2
  records it to the issue log rather than fixing it here.
- Touching any file in `~/Projects/BimodalLogic` or any other consumer repository. The live-shape
  re-verification in Phase 5 runs against a local fixture replicating that shape.
- Hand-editing `.claude/scripts/roadmap-integration.sh`. Per
  `.claude/rules/source-store-deploy-boundary.md` it is regenerated by deploy, never authored.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Flag re-splice reintroduces spacing drift (doubled space, lost 3-space `   # ` separator) | H | M | Every new test case asserts the exact full output line via `grep -Fx`, never "contains the flag" |
| Segmenting on first whitespace breaks grammar-legal `716, 714 --hard` | H | M | Anchor segmentation on the first whitespace-preceded `-` (Phase 1); include a `716, 714 --hard` fixture in Phase 3 |
| Fixing `count_pruned_next_ids()` changes `pruned=`/`retained=` values an existing fixture asserts | M | M | Re-run the full suite after Phase 2; hand-compute every changed count against the fixture's active/terminal sets before accepting it |
| A trailing space on a no-rationale line is mistaken for a flag segment | M | L | Right-trim `core` before segmentation; Phase 3's flagged-no-comment case asserts exact output |
| Sibling task edits land in the shared tree mid-dispatch | M | M | Re-read each file immediately before editing; stage only this task's own hunks by explicit file list; no `git-snapshot.sh` in reverting default mode |
| Deploy staleness (core, lean) masks or confuses gate results | M | H | Phase 5 redeploys before running the full gate set, with the bounded-wait idiom (`timeout 540`, Bash `timeout: 600000`) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Segment the Flag Portion in prune_next_body() [COMPLETED]

**Goal**: `prune_next_body()` separates an optional trailing CLI flag segment from the task-id
list before whitespace-stripping, preserves it verbatim in every output branch, and fails safe
on an unclassifiable token instead of dropping the line.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/roadmap-integration.sh` immediately before
      editing (sibling tasks are live on this tree) and confirm the `prune_next_body()` awk body
      still matches the research report's quoted shape. *(completed)*
- [x] Inside the awk program, after `core` is carved off from `rationale` by the existing
      `pos = index(line, "   # ")` logic, right-trim `core` so a trailing space on a
      no-rationale line cannot be read as a flag segment. *(completed)*
- [x] Segment `core` (post-`sub(/^\/orchestrate /, "", ...)`) on the **first whitespace-preceded
      `-`**, not on the first run of whitespace: locate it with `match(tasklist, /[ \t]+-/)`,
      assign everything before the match to the id list and everything from the `-` onward to a
      `flags` variable (verbatim, internal spacing preserved). When there is no match, `flags`
      is the empty string. This deliberately differs from research Recommendation 1's
      first-whitespace split, which would mis-split the grammar-legal `716, 714 --hard`.
      *(completed)*
- [x] Apply `gsub(/[ \t]/, "", ...)` to the id list **only**, then comma-split as before.
      *(completed)*
- [x] Add the fail-safe guard: if any post-split id token is not `^[0-9]+$`, `print line` and
      emit a named warning to stderr (`WARNING: prune_next_body: unparseable task id ...; Run
      line left unchanged`), then `next` — never drop a line this parser cannot classify.
      *(completed)*
- [x] Re-splice in the partial-keep branch: `print "/orchestrate " joined (flags != "" ? " "
      flags : "") rationale` (awk has no ternary issue here; use an explicit `if` building a
      `tail` variable if clearer). The `kept == n2` branch keeps printing `line` verbatim and so
      needs no change once the flag is no longer counted as an id. *(completed: used a `tail`
      variable combining flags and rationale)*
- [x] Replay the corrected function over the research Appendix's five inputs plus the multi-flag
      and single-active-task cases using a scratchpad harness (`active_ids_json='["714","716"]'`),
      and confirm each now yields the Expected column rather than the Actual column.
      *(completed: all 6 appendix-derived cases plus 3 additional mixed-set/fail-safe cases pass)*
- [x] Add the `/orchestrate 716, 714 --hard   # rationale text` (intra-list space) input to that
      harness and confirm it round-trips unchanged. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The edit is confined to one awk function inside one shell file with no
externally visible signature change, and is covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-roadmap-generation.sh,test-skill-base-lifecycle.sh`
(the two suites `suite_selection_select` resolves for this path).

**Scope Hypothesis**: The research report's claim that the deployed
`.claude/scripts/roadmap-integration.sh` is byte-identical to the source-store copy is CARRIED
from that report and must be re-confirmed at implementation time with
`diff agent-system/extensions/core/scripts/roadmap-integration.sh .claude/scripts/roadmap-integration.sh`
before editing; if it now differs, stop and report rather than assuming the deploy mirror is
clean.

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - `prune_next_body()`: flag-segment
  separation, id-list-only whitespace strip, non-numeric fail-safe guard, flag re-splice in the
  partial-keep branch

**Verification**:
- The scratchpad harness reproduces the Expected column for all seven inputs, asserted as exact
  full-line string equality, not substring containment.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-roadmap-generation.sh,test-skill-base-lifecycle.sh`
  exits 0 (existing unflagged fixtures unregressed).

---

### Phase 2: Apply the Same Segmentation to count_pruned_next_ids() [COMPLETED]

**Goal**: `count_pruned_next_ids()` only ever passes a plain numeric id to `jq --argjson`, so the
`pruned=`/`retained=` stderr counters are correct on flag-bearing Run lines, and a non-numeric
token can never be silently tallied as pruned.

**Tasks**:
- [x] Re-read the file (sibling-task concurrency) and confirm Phase 1's edit is the only change
      present in it. *(completed)*
- [x] In `count_pruned_next_ids()`, after `ids_csv="${ids_csv%%   #*}"`, cut the flag segment
      with `ids_csv="${ids_csv%% -*}"` (shortest prefix up to the first ` -`), then right-trim,
      then apply the existing `${ids_csv//[[:space:]]/}` collapse to the id list only.
      *(completed)*
- [x] Add a numeric guard inside the per-id loop: `[[ "$id" =~ ^[0-9]+$ ]] || { warn and
      continue; }` so a stray token can never reach `jq --argjson` and be mis-read as "not
      active" via jq's own non-zero exit. *(completed)*
- [x] Record the `covered_ids_from()` observation (Non-Goals above) non-fatally:
      `bash .claude/scripts/issue-record.sh --task-dir "$task_dir" --kind issue --class
      pre-existing-defect --severity minor --what-happened "covered_ids_from() scrapes all
      digits from the whole Run line including rationale prose and numeric flag arguments;
      out of scope here"` (append `|| echo "Note: issue recording failed (non-fatal)" >&2`).
      *(completed)*
- [x] Hand-compute the expected `pruned=`/`retained=` values for every existing fixture whose
      Run lines are flag-free (they must be unchanged) before running the suite.
      *(completed: confirmed every existing --prune fixture's Run lines are flag-free, so the
      flag-cut and numeric guard are no-ops on them; the one existing pruned=/retained= assertion
      — pruned=0 retained=0 — comes from a zero-/orchestrate-line fixture and is unaffected)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: A second single-file bash function edit with no signature change,
covered by the same
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-roadmap-generation.sh,test-skill-base-lifecycle.sh`
selection as Phase 1.

**Scope Hypothesis**: This plan asserts the two functions share one root cause but cannot share
one helper (one is awk, one is bash) — confirm at implementation time that no existing shared
shell helper in `roadmap-integration.sh` already performs id-list normalization that both could
call; if one exists, use it in both rather than writing a second parallel implementation.

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - `count_pruned_next_ids()`: flag
  cut before the whitespace collapse, plus a numeric guard around the `jq --argjson` lookup

**Verification**:
- A direct invocation of the function over a flag-bearing body returns the hand-computed pruned
  count (not the inflated pre-fix value).
- `jq --argjson` is never reached with a non-numeric argument: confirmed by running the function
  with `set -x` over a flag-bearing body and reading the traced `jq` invocations.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-roadmap-generation.sh,test-skill-base-lifecycle.sh`
  exits 0, and every `pruned=`/`retained=` assertion in the existing fixtures still holds at its
  hand-computed value.

---

### Phase 3: Flag-Bearing --prune Test Coverage in Both Layouts [COMPLETED]

**Goal**: Both `--prune` test groups carry flag-bearing fixtures covering all six scenarios, with
exact-output assertions that would catch any spacing or ordering drift.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` before
      editing. *(completed)*
- [x] Extend the classic `--prune` group ("Case group 3", the `scratch3` fixture) with Run lines
      covering: flagged + comment with mixed active/terminal ids; flagged + comment with all ids
      active; flagged with no comment; unflagged with comment (regression guard); multiple flags
      (`--hard --lit`); a single-task flagged line naming an active task; and an intra-list-space
      line (`716, 714 --hard`). *(completed: added as a new "Case group 3b" block with its own
      `write_roadmap_fixture_prune_flags` fixture and `scratch3b`, rather than mutating the
      shared `write_roadmap_fixture` used by other groups, to avoid any cross-group risk; also
      added an all-terminal-flagged absence case and a fail-safe case per the Verification
      bullets below)*
- [x] Mirror the same seven cases into the stage `--prune` group ("Phase 5", the `scratch10`
      fixture and its `write_state_fixture_prune_stage` helper), keeping each layout's own
      fixture conventions. *(completed: added as a "Phase 5b" block with its own
      `write_stage_vocabulary_fixture_prune_flags` fixture and `scratch10b`, reusing the existing
      `write_state_fixture_prune_stage` state fixture unmodified)*
- [x] Assert each surviving line with exact full-line equality (`grep -Fx '<exact line>'`), and
      assert the all-terminal flagged line is absent — never a substring "contains the flag"
      check. *(completed)*
- [x] Assert the `pruned=`/`retained=` stderr marker values for each new fixture against
      hand-computed expectations, so a future regression in `count_pruned_next_ids()` fails
      loudly here. *(completed: pruned=3 hand-computed and asserted for each layout)*
- [x] Add a case asserting the Phase 1 fail-safe: a Run line with a non-numeric id token passes
      through unchanged and the run emits the named stderr warning. *(completed; this full
      end-to-end run also surfaced a Phase 1 bash-quoting bug in the warning message itself,
      fixed in place and recorded to the issue log)*
- [x] Confirm the new cases follow the file's existing `pass`/`fail` helper conventions and do
      not disturb the surrounding groups' scratch-directory isolation. *(completed: new blocks
      use their own `scratch3b`/`scratch10b` variables via `build_scratch`, isolated from every
      other case group)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: The edit is confined to the test file itself, and its own covering check
is `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-roadmap-generation.sh,test-sweep-invalidated-claims.sh`
(the suites `suite_selection_select` resolves for this path).

**Scope Hypothesis**: This phase asserts the classic group is "Case group 3" and the stage group
is "Phase 5", with fixtures `scratch3`/`scratch10` and helper
`write_state_fixture_prune_stage` — figures CARRIED from the research report's reading of the
test file. Re-locate each group by its comment banner at implementation time rather than by line
number, and adjust if the file has since moved.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - seven new flag-bearing
  `--prune` cases in the classic group and seven in the stage group, plus marker-count and
  fail-safe-warning assertions

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-roadmap-generation.sh,test-sweep-invalidated-claims.sh`
  exits 0 with every new case reported as a pass.
- Deliberately reverting Phase 1's `gsub` fix in a scratch copy of the script makes the new cases
  fail — confirming they actually exercise the defect rather than passing vacuously.

---

### Phase 4: Admit the Flag Segment in the Next Grammar [COMPLETED]

**Goal**: `roadmap-format.md` documents the optional flag segment that live roadmaps already
author, so the generation contract stops silently diverging from authoring practice (research
Recommendation 4, option (a)).

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/formats/roadmap-format.md` before editing.
      *(completed)*
- [x] In the `## Next Grammar` section, extend the Run-line pattern to admit an optional flag
      segment between the id list and the rationale comment, and update the displayed grammar
      line (`/orchestrate {task_list}   # {rationale}`) to show the optional `{flags}` position.
      *(completed: pattern is now `^/orchestrate ([\d, ]+)(\s+(-\S.*?))?(\s{3}# (.+))?$`,
      displayed line is `/orchestrate {task_list} {flags}   # {rationale}`)*
- [x] Update the matching `Next Run line` row in the `## Parsing Patterns Summary` table to the
      same pattern — the two must not drift. *(completed)*
- [x] State the round-trip guarantee in prose: `--prune` preserves an authored flag segment
      verbatim in every outcome, and never drops a Run line it cannot fully parse. *(completed)*
- [x] Scope the change narrowly to a flag segment: do not admit arbitrary trailing text.
      *(completed: prose explicitly states no arbitrary trailing text is admitted)*
- [x] Confirm no task-number references are introduced (this file is outside `specs/**`).
      *(completed: the only numeric ids mentioned are illustrative fixture ids, not a citation of
      this repository's own task-management numbering)*

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: The edit is markdown-only with zero compile or elaboration surface, and
the diff read-through is paired with its one covering suite,
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-roadmap-generation.sh`,
which `suite_selection_select` resolves for this path (so this is not a `__FULL_SWEEP__` case).

**Files to modify**:
- `agent-system/extensions/core/context/formats/roadmap-format.md` - `## Next Grammar` Run-line
  pattern and displayed grammar line; the `Next Run line` row of `## Parsing Patterns Summary`;
  a round-trip-guarantee sentence

**Verification**:
- Diff read-through confirms every changed hunk is prose or a pattern cell, with no executable
  surface touched.
- The two Run-line patterns (Next Grammar and Parsing Patterns Summary) are byte-identical to
  each other after the edit, confirmed by extracting both and comparing.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-roadmap-generation.sh`
  exits 0.

---

### Phase 5: Redeploy and Full Gate Set [NOT STARTED]

**Goal**: The fix reaches the deployed tree through the sanctioned deploy path, the complete gate
set passes, and the originally-reported live shape is confirmed fixed against a local fixture.

**Tasks**:
- [ ] Build a scratchpad fixture replicating the live stage-based shape that surfaced the defect
      (a stage-layout roadmap whose run-order fence contains
      `/orchestrate 716,714 --hard   # rationale text`) with a matching `--state` JSON in which
      716 is terminal and 714 is active; run `--prune` read-only (`--dry-run` first, then a real
      run on the scratch copy) and confirm 714 and the flag both survive.
- [ ] Confirm nothing outside this repository is read or written: the fixture is local, no path
      under `~/Projects/BimodalLogic` is touched.
- [ ] Redeploy to propagate the source-store fix into `.claude/scripts/` (the dispatch reports
      the deployed tree stale for `core` and `lean`), using the bounded-wait idiom:
      `timeout 540 bash .claude/scripts/deploy-headless.sh` with the Bash tool `timeout`
      parameter raised to 600000.
- [ ] Confirm post-deploy that `diff agent-system/extensions/core/scripts/roadmap-integration.sh
      .claude/scripts/roadmap-integration.sh` is empty, and that
      `.claude/context/formats/roadmap-format.md` carries Phase 4's grammar change.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (no `--skip-slow`, no
      `--only-gate` narrowing) and confirm it exits 0.
- [ ] Review `git status --short` and `git diff --staged`, stage only this task's own three
      source-store files by explicit file list, and commit per `.claude/rules/git-workflow.md`.
- [ ] Record a `kind: win` or `kind: issue` issue-log entry for this phase per the dispatch's
      Issue Log contract, or attest explicitly that nothing arose.

**Timing**: 0.75 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: This phase assumes a redeploy is required and will succeed within 540
seconds, based on the dispatch's `<deploy-freshness-context>` naming `core lean` stale. Confirm
the staleness still holds before redeploying (a sibling task may have redeployed already), and
if `deploy-headless.sh` exceeds the bounded wait, report it rather than extending the timeout
silently.

**Files to modify**:
- `.claude/scripts/roadmap-integration.sh` - regenerated by `deploy-headless.sh`; never
  hand-edited
- `.claude/context/formats/roadmap-format.md` - regenerated by `deploy-headless.sh`; never
  hand-edited

**Verification**:
- The live-shape fixture's `--prune` run preserves both the active task id and the flag segment,
  asserted as exact full-line equality.
- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes and the post-deploy `diff`
  between source-store and deployed `roadmap-integration.sh` is empty.
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set this repository
  aggregates, with no gate or suite narrowing applied.
- `git diff --staged` shows exactly the three source-store files this task owns and no sibling
  task's hunks.

## Testing & Validation

- [ ] All seven flag-bearing scenarios pass in the classic `--prune` group with exact-output
      assertions.
- [ ] All seven pass identically in the stage `--prune` group.
- [ ] The unflagged-with-comment regression guard still passes in both layouts.
- [ ] A flagged single-task Run line naming an active task is never dropped.
- [ ] `pruned=`/`retained=` stderr marker values match hand-computed expectations for every new
      and existing fixture.
- [ ] A non-numeric id token triggers the fail-safe passthrough plus the named stderr warning.
- [ ] Reverting the `gsub` fix in a scratch copy makes the new cases fail (anti-vacuity check).
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 after redeploy.

## Artifacts & Outputs

- Fixed `agent-system/extensions/core/scripts/roadmap-integration.sh`
  (`prune_next_body()` + `count_pruned_next_ids()`).
- Extended `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` (14 new cases
  across both layouts, plus marker-count and fail-safe assertions).
- Extended `agent-system/extensions/core/context/formats/roadmap-format.md` Next Grammar and
  Parsing Patterns Summary.
- A redeployed `.claude/` tree carrying both.
- An issue-log entry recording the out-of-scope `covered_ids_from()` observation.

## Rollback/Contingency

All three edits are additive or localized within existing functions and sections, so the primary
rollback is `git revert` of this task's own commits — no schema, state, or on-disk roadmap file
is mutated by the fix itself.

- If Phase 1's segmentation proves to interact badly with an authoring shape not anticipated
  here, the fail-safe guard is the contingency: an unclassifiable line passes through unchanged,
  which is strictly safer than the current silent drop, so a partial landing of Phase 1 alone is
  still a net improvement over the pre-fix state.
- If Phase 2's fix changes an existing fixture's `pruned=`/`retained=` assertion in a way that
  cannot be hand-justified, stop and report rather than editing the assertion to match — a
  count that cannot be hand-derived is evidence the fix is wrong, not that the fixture is.
- If an intentional rollback of uncommitted work becomes necessary, snapshot first with
  `bash .claude/scripts/git-snapshot.sh 388` before any destructive git command; for an ordinary
  defensive checkpoint mid-phase use `--no-revert` instead.
- Sibling tasks are live on this working tree. If a foreign commit or foreign uncommitted
  modification to any of this task's three files is observed, STOP and report after checking
  `git log` — do not proceed and do not dismiss it as noise.
