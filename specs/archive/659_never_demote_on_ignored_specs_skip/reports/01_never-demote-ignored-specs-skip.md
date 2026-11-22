# Research Report: Task #659

**Task**: 659 - Never demote on an ignored-specs skip
**Started**: 2026-11-19
**Completed**: 2026-11-19
**Effort**: medium
**Dependencies**: Builds directly on task 658's predicate (`scripts/lib/specs-ignore-lib.sh`) and V13 classification gate (exit codes 8/9 in `git-commit-scoped.sh`)
**Sources/Inputs**: - Codebase (`agent-system/extensions/core/scripts/**`, `context/standards/git-staging-scope.md`, `context/formats/issue-log.md`), git log, task 658's `.return-meta.json`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The headline demotion bug is already fixed.** Task 658 (completed before this dispatch)
  added the V13 classification gate (exit 8/9) to `git-commit-scoped.sh` AND added the matching
  exclusion to `orchestrate-cycle-postflight.sh`'s commit-landing status-correction block: exit
  8/9 are explicitly excluded from the `case "$commit_rc" in 2|3|4|5) ...` demotion arm
  (`scripts/orchestrate-cycle-postflight.sh:2176-2215`), with an explicit comment stating "a task
  whose only 'failure' is that its target repository ignores `specs/` must never be demoted to
  `partial`." `context/standards/git-staging-scope.md` (lines 1016-1042) documents this exclusion
  in full, including the deliberate statement **"No `issue-record.sh` entry is fired for this
  arm — these are not issues."**
- **The genuine open gap is "how the skip is reported."** That same documented decision — no
  durable record at all, only a stderr `NOTE:` — is exactly what task 659's dispatch asks to
  change: "A skip that leaves no trace is as wrong as one that demotes." This is a real,
  deliberate reversal of one specific facet of 658's design (recording), not a reversal of
  658's non-demotion fix (which must survive unchanged).
- **No automated negative-control test exists yet** for exit 8/exit 9 against the
  STATUS-DEMOTED check (existing cases 980/981/985/986 cover exit 6, exit 1, exit 2-5, and a
  non-implement dispatch — none covers exit 8 or 9). The dispatch's VERIFICATION section
  requires exactly this pair.
- **The "measured scope correction" in the dispatch file is confirmed accurate by direct
  re-measurement**: `reconcile-task-status.sh` and `task-lock.sh` issue no git-history read at
  all; `territory-contention-lib.sh`'s only "git log" mention is prose inside an advisory `note`
  string, never executed code. Only three readers need any attention, and two of the three
  already degrade correctly with no code change required.

## Context & Scope

Task 659's goal, per the dispatch, is twofold: (1) confirm the completed-vs-partial demotion
exception for a wholly/partly gitignored `specs/` tree is correctly narrowed (not removed), and
(2) ensure every consumer that reads specs' git history has a defined, non-silent answer when
that history does not exist, and that the skip itself is recorded as visible evidence without
affecting task status. The dispatch's own "MEASURED SCOPE CORRECTION" note already narrowed "THE
HISTORY READERS" from six items to three; this research re-measured all six directly rather than
trusting either list, per that note's own instruction.

Task 658 (same repository, prior task number) already implemented the shared ignored-path
predicate and the V13 exit-code gate plus the postflight non-demotion exclusion. This research
therefore focuses on: what remains undone, what already satisfies the DONE WHEN criteria, and
where the implementation phase's actual work is.

## Findings

### Codebase Patterns

**1. The demotion site (`scripts/orchestrate-cycle-postflight.sh`) — ALREADY CORRECT, verified.**

- The exit-code classification arm (`case "$commit_rc" in ... 8|9) ...`, lines 2141-2155) treats
  exit 8/9 as NOTE-level, non-fatal, with an empty `commit_attribution_note` (so the emitted
  verdict JSON carries no failure attribution for either code).
- The separate, subsequent "Commit-landing status correction" block (lines 2163-2215) demotes
  `completed` -> `partial` **only** for `commit_rc` in `2|3|4|5`, under the exact conjunction
  `dispatch_status = implemented` AND `implemented_gate_passed` AND no deploy-pending/staleness
  refusal. The `*) : ;;` catch-all explicitly covers "exit 1, exit 6, exit 8/9, and any
  unrecognized code: no demotion."
- `context/standards/git-staging-scope.md` lines 1038-1042 states the rationale verbatim: exit
  8/9 are excluded "for a stronger reason than [exit] 7's fail-open uncertainty: a task whose
  only 'failure' is that its target repository ignores `specs/` must never be demoted to
  `partial` at all."
- **Conclusion**: the negative-control requirement's "genuine commit failure still demotes" half
  is already correct and tested (cases 980/981/985/986); the "ignored-specs repository completes
  without demotion" half is correct in code but has **no test case** exercising exit 8 or exit 9
  specifically (see Risks & Mitigations).

**2. How the skip is (not) reported — the real open item.**

- `git-commit-scoped.sh`'s V13 gate (lines 859-872, 906-915, 1350-1359) only ever `echo`s a
  `NOTE:` line to stderr for both the all-ignored (exit 8) and partial-ignore (exit 9) shapes.
  The dedicated `ignored_dropped` ledger exists (lines 745-752) precisely so this drop is never
  conflated with the ambiguous-cause `dropped_pathspecs` ledger V6 reads — but nothing ever
  reads `ignored_dropped` to produce a durable record.
- `orchestrate-cycle-postflight.sh`'s own 8|9 arm (lines 2150-2154) likewise only echoes a
  `NOTE:` to stderr — no `issue-record.sh` call, confirmed both by direct inspection and by
  `git-staging-scope.md`'s own explicit statement: "No `issue-record.sh` entry is fired for this
  arm — these are not issues."
- This means that **today**, in a repository whose `specs/` tree is wholly or partly gitignored,
  the fact that a per-cycle specs commit never lands leaves **zero durable trace** anywhere —
  only a transient stderr line that most orchestration callers do not persist. This is exactly
  the "silent-skip" failure mode task 659's description calls out as "as wrong as" the demotion
  bug.
- `issue-record.sh` (`(--task-dir PATH | --task N) --kind issue|win --class CLASS --severity
  blocking|costly|minor|none --what-happened "..." [--phase ...] [--dispatch-seq ...] ...`) is
  available at the `orchestrate-cycle-postflight.sh` call site with a task context already in
  scope (`$task_number`/`$TASK_DIR`/`$session_id`/`$dispatch_seq_flag` are all already used two
  arms above, at lines 2133-2139, for the 2-6 ERROR arm).
- `events-append.sh` (`--event-type TYPE --category deviation|blocker|milestone|success --session
  SID --message "..."`) is the channel named for "where no task context exists" — e.g. the
  roadmap-regeneration commit in `orchestrate-conclusion-roadmap.sh` (which also commits a
  `specs/` path, `specs/ROADMAP.md`, and could equally hit exit 8/9, but today falls through its
  own generic `*)` catch-all as an undifferentiated "treating as no commit" WARNING with no
  record at all either). **Category must be `deviation`, never `blocker`** — `blocker` is the
  one category `events-append.sh`'s own doc comment says gets promoted to the cross-repo central
  log, which would be a serious overclassification of a benign, repository-configuration fact.
- **Severity mismatch worth flagging for planning**: `context/formats/issue-log.md`'s four-rung
  severity scale reserves `none` ("No cost was incurred at all") explicitly for `kind: "win"`
  entries. A V13 skip genuinely costs nothing, but recording it as `kind: issue` therefore cannot
  legally use `severity: none` under the documented schema — the closest available value is
  `minor`. Recording it instead as `kind: win, severity: none` is schema-legal but semantically
  odd for a routine, repeated, repository-configuration fact rather than a dispatch performing
  unusually well. Planning should pick one explicitly rather than default to whichever is
  syntactically convenient.
- **Class**: none of the 17 seed classes in `issue-log.md` fit a "the repository's own
  `.gitignore` makes a bookkeeping commit impossible" fact precisely. `class` is "open,
  extensible" (warns to stderr and proceeds on an unrecognized value) — a new value such as
  `"repository configuration"` is the cleanest fit; `"environment"` is the closest existing seed
  class if a new value is undesirable.
- **Repeat-recording risk, explicitly called out by the dispatch**: in a repository whose
  `specs/` tree is wholly gitignored, **every single completing cycle** hits exit 8. A naive
  unconditional `issue-record.sh` call at this site would therefore write a near-duplicate entry
  to `issues.jsonl` every cycle for the lifetime of every task ever dispatched in that
  repository. `orchestrate-cycle-postflight.sh` already has a working precedent for exactly this
  dedup shape a few hundred lines above the commit block: the `partial_blocker_identity` /
  `partial_matched_entry_id` logic (lines 1545-1562) hashes an identity and checks
  `issues.jsonl` for an already-open entry with that identity before writing a second one. The
  dispatch's own framing ("whether a repeated skip should be recorded once per invocation rather
  than once per dispatch") maps directly onto this precedent: the natural dedup key is
  `session_id` (stable across every cycle of one `/orchestrate` invocation for a given task) plus
  a fixed marker (e.g. a literal class/tag identifying "V13 skip"), checked against
  `issues.jsonl` before writing, so only the FIRST cycle of a given invocation that hits exit 8/9
  records an entry — not every cycle.

### External Resources

Not applicable — this is a pure codebase-internal research task (no external library/API
surface).

### History-Reader-by-Reader Findings (confirms the dispatch's own re-measurement)

Each of the six originally-named readers, directly re-verified:

1. **`scripts/reconcile-task-status.sh`** — zero occurrences of `git log`/`git show`/
   `git ls-files`/`git rev-list`/`git diff`. **No git-history read exists; no change needed.**
2. **`scripts/task-lock.sh`** — same: zero occurrences of any git-history-reading invocation.
   **No change needed.**
3. **`scripts/lib/territory-contention-lib.sh`** — its only "git log" text is embedded inside
   the `concurrency_note` prose string emitted to agents (`"...STOP and report it -- after
   checking git log to confirm the work is not your own..."`), never an executed git invocation.
   **No change needed; this is advisory text for a human/agent reader, not code.**
4. **`scripts/validate-state.sh`'s `--deep` artifact-loss check (Checks D4/D5)** — fetches the
   prior committed `state.json` via `git -C "$state_dir" ls-files` then `git show
   <sha>:./<path>`. **Already handles an absent history gracefully**: when `git ls-files` returns
   nothing for `state.json` (exactly what happens when `specs/` is wholly gitignored, since the
   file is then untracked), `rel_path`/`prior_commit` stay empty and the script emits two
   explicit `log_warn` lines — `"No git history found for $STATE_FILE -- skipping
   terminal-status immutability check"` and the paired D5 skip message — then returns from that
   branch entirely. This is WARN-level, not FAIL-level, and is not silent. **No code change is
   required here; the existing behavior already is the "defined answer for an absent specs
   history" the dispatch calls for.** (The dispatch's "MEASURED SCOPE CORRECTION" framed this as
   "the one real casualty... needs a defined answer rather than a silent zero" — direct
   inspection shows it is in fact already non-silent and already a defined WARN-level skip, not
   a silent zero. Planning should record this as a verified-already-correct item, not schedule
   an unnecessary code change.)
5. **`scripts/dispatch-metrics.sh`'s churn split** (`metrics_commits_and_churn`,
   lines 285-340) — sums `git log --numstat -- specs/` and `-- . ':!specs/'` separately via
   `awk`. When no commits in the matched set touch any tracked `specs/` path (the exact shape an
   ignored `specs/` tree produces), the `awk` pipeline yields no output line, `specs_stat` stays
   empty, and the pre-initialized `specs_added=0 specs_removed=0` locals are left at zero. This
   **is** the "yields zero rather than an error" behavior the dispatch names. Verdict: **zero is
   the semantically correct answer, not a defect** — if `specs/` is genuinely untracked, zero
   specs-path churn is the honest truth, and the parallel `outside_specs` figure (computed from
   the same commit set, unaffected by the `specs/` pathspec) still correctly reports any real
   deliverable churn from the same commits. **No code change needed; only the verdict needs
   stating** (in the plan/implementation artifact) so a future reader does not mistake `{specs:
   {added: 0, removed: 0}}` for a broken metric in this repository shape.
6. **`scripts/init-specs.sh`'s `git ls-files -- specs/` probe** (line 174) — confirmed present,
   but the dispatch's own correction explicitly assigns this to a different task ("the
   scaffolding record's own subject and not this one's" — the sibling task 660 territory in this
   dispatch's `## Territory` block names `init-specs.sh` as task 660's own file scope). **Out of
   scope for 659; no action and no co-admission with task 660 into one batch** (per the
   dispatch's "shared territory, declared not blocking" note for the separate task 501 overlap,
   and task 660's own declared file_scope for this file).

### A related, not-yet-covered reader found during this research (not in the original six)

`git-commit-scoped.sh`'s own `--honest-index-rows` addendum (lines 1146-1174) reads
`HEAD:specs/state.json` and the staged `:specs/state.json` via a small inline Python helper
(`load_ref`), wrapping each `git show` in a broad `except Exception: return None`. When
`specs/state.json` is untracked (ignored-specs case), `load_ref('HEAD:specs/state.json')` raises
`CalledProcessError` (caught) and returns `None`, and the function `sys.exit(0)` immediately,
leaving `also_carries=""`. The caller then simply omits the "Also carries current index rows for
tasks: ..." addendum from the commit message. **This already degrades correctly and silently
(in the good sense: no crash, no spurious failure, just omits an addendum that has nothing
truthful to say) — no code change needed, but worth naming explicitly since the dispatch's
description singled out "`git-commit-scoped.sh`'s honest-index-rows comparison as consumed by
its callers" as one of the six readers to give a stated answer for.** The stated answer is: an
absent/untracked `specs/state.json` silently and correctly suppresses the addendum rather than
erroring.

## Recommendations

1. **Do not touch the demotion exclusion logic itself.** It is already correct, already
   documented, and already has partial test coverage (cases 980/981/985/986, none of which
   covers exit 8/9, but none of which would need to change). Re-implementing or "fixing" it risks
   regressing a working, carefully-reasoned exclusion.
2. **Add the skip-recording call** at `orchestrate-cycle-postflight.sh`'s existing `8|9)` arm
   (lines 2150-2154): an `issue-record.sh` call (task context is already in scope at this call
   site) with `--kind issue --severity minor` (per the severity-scale finding above — `none` is
   reserved for `kind: win`), a new or reused `--class` value (`"repository configuration"`
   recommended; `"environment"` is the closest existing seed class if a new value is avoided),
   and `--what-happened` text naming the exit code (8 or 9), the task, and that this is the
   repository's own `.gitignore` configuration rather than a defect — mirroring the existing
   prose already used in the stderr `NOTE:` lines at this call site. Gate this call behind the
   dedup check described above (session_id-keyed, checked against `issues.jsonl` before writing)
   so a wholly-ignored-specs repository does not accumulate one entry per cycle for the task's
   entire lifetime.
3. **Decide, at plan time, whether `git-commit-scoped.sh`'s OWN V13 arms (lines 859-872,
   906-915, 1350-1359) should also gain a direct `events-append.sh` call**, independent of the
   `orchestrate-cycle-postflight.sh` caller, to cover callers that do NOT pass `--task` (e.g.
   `orchestrate-conclusion-roadmap.sh`'s roadmap-regeneration commit, `orchestrate-unwind-
   dispatch.sh`, `lib/redeploy-checkpoint-lib.sh`) and therefore have no task context for
   `issue-record.sh` at all. This matches the dispatch's own stated split ("issue-record.sh
   where a task context exists, events-append.sh where none does") and would give a durable
   trace for the roadmap-commit case too, which today silently falls into a generic, undated
   "treating as no commit" WARNING whenever `specs/ROADMAP.md` is itself gitignored. This is a
   genuine scope decision the dispatch leaves open ("research settles which channel") — flagging
   it here as a concrete planning choice rather than resolving it unilaterally, since it widens
   the file footprint beyond `orchestrate-cycle-postflight.sh` alone.
4. **Add the missing negative-control test pair** to
   `scripts/tests/test-orchestrate-cycle-postflight.sh`, mirroring cases 980/981/985/986's
   existing structure: one case driving `commit_rc=8` (all-ignored) through an `implemented`
   dispatch with `implemented_gate_passed=true`, asserting (a) no `STATUS DEMOTED` line and (b)
   the task's final status is `completed`; and, if recommendation 2 is adopted, a companion
   assertion that the skip WAS durably recorded (an `issues.jsonl` entry, or the dedup-skip path
   on a second invocation). A parallel case for `commit_rc=9` (partial-ignore, commit already
   landed) follows the same shape. These are the dispatch's own VERIFICATION requirement's two
   halves, and the "genuine commit failure still demotes" half is already proven by the existing
   cases 980/985 — only the "ignored-specs repository completes" half is missing.
5. **No code change** is needed for `validate-state.sh`, `dispatch-metrics.sh`,
   `reconcile-task-status.sh`, `task-lock.sh`, or `territory-contention-lib.sh`. The plan/summary
   artifacts should explicitly record this "verified already correct, no change" verdict for
   each (per the dispatch's DONE WHEN clause "every history reader named above has a stated and
   implemented answer for an absent specs history" — a stated answer of "already correct" with
   a cited line reference satisfies this without a diff).
6. **Leave `init-specs.sh` untouched** and do not co-admit with task 660 into one batch, per the
   dispatch's own explicit territory note.

## Decisions

- The research scope for implementation is: (a) one new `issue-record.sh` call with dedup, sited
  inside `orchestrate-cycle-postflight.sh`'s existing `8|9)` arm; (b) a documentation update to
  `context/standards/git-staging-scope.md`'s lines 1016-1042 (and possibly
  `context/formats/issue-log.md`'s class seed-list) reflecting the new recording behavior,
  superseding the current "No `issue-record.sh` entry is fired for this arm — these are not
  issues" sentence with the narrower, corrected claim (recorded as evidence, never as a failure,
  never status-bearing); (c) two new test cases for the exit 8/9 negative control; (d) a stated,
  no-diff verdict for the five already-correct readers.
- `events-append.sh`'s broader rollout (recommendation 3) is left as an explicit planning
  decision rather than settled here, since it changes a second file's (`git-commit-scoped.sh`'s)
  footprint and touches callers outside the dispatch's named territory.
- Severity for the new `issue-record.sh` entry is recommended as `minor` (not `none`, which the
  schema reserves for `kind: win`); class is recommended as a new extensible value
  (`"repository configuration"`) rather than forcing a seed class that does not quite fit.

## Risks & Mitigations

- **Risk**: an unconditional `issue-record.sh` call on every exit-8/9 cycle floods
  `issues.jsonl` in a wholly-ignored-specs repository (every completing cycle, for the task's
  entire lifetime). **Mitigation**: dedup by `session_id` against `issues.jsonl` before writing,
  mirroring the existing `partial_blocker_identity`/`partial_matched_entry_id` pattern already in
  this same script (lines 1545-1562).
- **Risk**: recording the skip could be mistaken, by a future reader of `issues.jsonl` or by
  conclusion-stage tooling that reads `suggested_channel`/`resolution`, as evidence of a real
  problem needing follow-up. **Mitigation**: use `--resolution fixed_inline` or omit
  `--suggested-channel` entirely (a missing hint is absorbed, not defaulted, per
  `issue-log.md`'s own field table) so nothing routes this to a follow-up task automatically; the
  `--what-happened` text should state plainly that this is the repository's own configuration,
  not a defect, exactly as the existing stderr `NOTE:` text already does.
- **Risk**: widening `git-commit-scoped.sh`'s V13 arms to also call `events-append.sh` directly
  (recommendation 3) could double-record a skip when a caller like
  `orchestrate-cycle-postflight.sh` ALSO records one via `issue-record.sh` for the same exit
  code. **Mitigation**: if recommendation 3 is adopted, scope the `events-append.sh` call to
  fire only in `git-commit-scoped.sh` itself when `--task` was NOT supplied (i.e., exactly the
  "no task context" callers), never alongside a caller that already records via
  `issue-record.sh`.
- **Risk**: a plan that tries to "fix" `validate-state.sh` or `dispatch-metrics.sh` based on the
  dispatch description's pre-correction framing ("needs a defined answer rather than a silent
  zero") without re-reading the MEASURED SCOPE CORRECTION paragraph would spend implementation
  effort on code that already behaves correctly. **Mitigation**: this report's "History-Reader-
  by-Reader Findings" section above states the already-correct verdict with exact line
  references for both.

## Context Extension Recommendations

None — task_type is `meta`; per the agent's own Stage 4.5 instruction, this section is omitted
for meta tasks.

## Appendix

- Search queries / commands used: `grep -n "STATUS DEMOTED|demote|partial|exit_code|git-commit-scoped" scripts/orchestrate-cycle-postflight.sh`;
  `grep -n "git show|git log|git ls-files|git rev-list|git diff" scripts/validate-state.sh`;
  `grep -n "git log|numstat|specs/" scripts/dispatch-metrics.sh`;
  `grep -n "exit 8|exit 9|V13|ignored_dropped|issue-record|events-append" scripts/git-commit-scoped.sh`;
  direct re-measurement greps for git-history calls in `reconcile-task-status.sh`,
  `task-lock.sh`, `lib/territory-contention-lib.sh`; `grep -n "V13|exit 8|exit 9|STATUS DEMOTED|gitignored" scripts/tests/test-orchestrate-cycle-postflight.sh`.
- Files read in full or in relevant part: `scripts/orchestrate-cycle-postflight.sh` (lines
  2080-2340), `scripts/git-commit-scoped.sh` (lines 1140-1260 and the grepped V13/ledger
  sections), `scripts/validate-state.sh` (lines 1440-1600), `scripts/dispatch-metrics.sh` (lines
  280-400), `scripts/init-specs.sh` (relevant lines), `scripts/events-append.sh` (header),
  `scripts/issue-record.sh` (header/usage), `context/standards/git-staging-scope.md` (lines
  858-1065), `context/formats/issue-log.md` (field table, severity scale, class seed list),
  `specs/658_ignored_specs_predicate_and_commit_path/.return-meta.json`.
- Prior task: 658 (completed; added `scripts/lib/specs-ignore-lib.sh`, the V13 gate, and the
  postflight non-demotion exclusion this report builds on).
