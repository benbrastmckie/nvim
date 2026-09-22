# Research Report: Task #221

**Task**: 221 - Correct the lean implementation-agent contracts: build-verdict method, waiter teardown, no-revert snapshot
**Started**: 2026-09-22T00:49:12Z
**Completed**: 2026-09-22T00:55:00Z
**Effort**: 3 hours
**Dependencies**: 172 (completed), 173 (completed), 194 (completed/archived)
**Sources/Inputs**: Codebase (source-store markdown contracts, `lake-build-guard.sh`, its test suite, `dispatch-report-not-termination.md`, `bounded-build-waiter.md`, `general-implementation-agent.md`), `specs/state.json`
**Artifacts**: - `specs/221_lean_build_verdict_evidence_contracts/reports/01_build_verdict_evidence_contracts.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All prerequisite guard-side and cross-cutting infrastructure this task depends on already
  exists and is verified present in the source store: the `result` subcommand, the un-piped
  exit-code discipline documentation, the `holder_pid`/`kill -0` waiter idiom, and the `pgrep -f`
  self-match prohibition are already in `lake-build-guard.sh`'s header and `print_help()`
  (guard-side, task 173, completed); the canonical bounded-waiter idiom is already fully
  specified in `context/patterns/bounded-build-waiter.md` (task 172, completed). This task is
  purely a documentation-and-pointer task across five files already named in `file_scope` — no
  script or test file is touched.
- Four checked gaps remain, each independently verifiable by absence in the current source
  store: (1) `long-builds.md` has no verdict-determination section at all; (2) its "Passive
  progress checks" section takes a `<PID>` from nowhere and never prohibits `pgrep -f`; (3)
  `lean4.md`'s "Build Commands" canonical invocation carries no exit-code capture discipline;
  (4) three `Record: build_passed (true/false)` sites (one in the plain agent, two in the hard
  agent) specify no method.
- A fifth, independently-scoped gap (from the absorbed former task 175): `dispatch-report-not-
  termination.md`'s "Tear Down Watchers/Monitors Before Reporting" section does not yet name the
  supersession transition, and its "Where This Is Referenced" list has exactly 3 entries, none
  covering a lean agent's own build waiter; neither lean agent file points at that rule or at
  `bounded-build-waiter.md`.
- A sixth, independently-scoped gap (from the absorbed former task 198): neither lean agent
  contract mentions `git-snapshot.sh`, `--no-revert`, or `orchestrator_mode` at all (grep-
  confirmed, zero matches in both files) — `general-implementation-agent.md` has only one
  existing `--no-revert` usage, inside its context-pressure checkpoint procedure, not a
  general "under orchestrator_mode, prefer --no-revert" bullet; the wording to mirror must be
  synthesized from that usage plus `git-snapshot.sh`'s own header language, not copied verbatim
  from an equivalent bullet elsewhere (no such general bullet currently exists in the core agent
  either).
- Recommended approach: five small, additive edits, each a single-statement-plus-pointer per
  the file's own established convention — one new section in `long-builds.md` (the evidence
  hierarchy, "strongest last"), one closed gap in the same file's existing "Passive progress
  checks" section, one added line in `lean4.md`, three one-line pointer replacements across the
  two agent files' `build_passed` sites, one extension to `dispatch-report-not-termination.md`
  plus two new one-line pointers in the lean agent files, and one new `--no-revert` bullet in
  each lean agent file.

## Context & Scope

This is a `meta` task whose edit target is the source store
(`agent-system/extensions/lean/**` and one `agent-system/extensions/core/**` file), never
`.claude/**` (a disposable, regenerated deploy artifact — see
`.claude/rules/source-store-deploy-boundary.md`). The task absorbed two prior tasks verbatim
(former task 175: waiter-teardown wiring; former task 198: git-snapshot `--no-revert`
mandate) alongside its own primary build-verdict-evidence work. `file_scope` in `specs/state.json`
names exactly five files, matching every edit site identified below:

```
agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md
agent-system/extensions/lean/agents/lean-implementation-agent.md
agent-system/extensions/lean/agents/lean-implementation-hard-agent.md
agent-system/extensions/lean/context/project/lean4/operations/long-builds.md
agent-system/extensions/lean/rules/lean4.md
```

Explicit non-goals (verified, do not re-litigate): editing `lake-build-guard.sh` or its test
suite (task 173's territory); editing `skill-lake-repair/SKILL.md` (its
`build_output=$(...2>&1); build_exit_code=$?` pattern is command substitution, not a pipeline,
and already captures the guard's own exit code correctly — confirmed by reading the file, lines
65-83); restating the bounded-waiter contract, the teardown rule, or the evidence hierarchy in
more than one place each; touching `core/scripts/git-snapshot.sh`, `core/rules/git-workflow.md`,
or the plan format (task 191's territory).

## Findings

### Codebase Patterns

**Guard-side infrastructure already complete (task 173).** Read in full:
`agent-system/extensions/core/scripts/lake-build-guard.sh`. Confirmed present today:
- A `result` subcommand with its own exit-code band (0 = passed, 20 = failed with the real code
  printed on stdout, 21 = still running, 22 = aborted/orphaned, 23 = no record, 24 =
  `--expect-pid`/`--expect-scope` mismatch, 77 = usage error).
- A "READING THE VERDICT" header block and a matching `print_help()` "Reading the verdict"
  section, both stating: a consumer MUST read the verdict via `result`'s exit code or an
  UN-PIPED `"$?"` immediately after `build`, and MUST NEVER read it from a pipeline's last
  stage's exit status (the `... | tail -60` false-pass shape this subcommand was built to close).
- A "STATUS line" (`lake-build-guard: STATUS: exit_status=N` on stderr, after output has closed)
  as a belt-and-braces signal for a caller that pipes anyway.
- Four named capture paths under `<root>/.lake/`: `build-guard.result`, `build-guard.stdout`,
  `build-guard.stderr`, `build-guard.log`.
- The `holder_pid`/`kill -0` waiter idiom and an explicit `pgrep -f` self-match prohibition, in
  both the header comment ("WAITING ON AN IN-FLIGHT GUARDED BUILD") and `print_help()`.
- Test suite confirmation: `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`
  case 21 (`pass "case 21: --help output documents the kill -0 wait idiom and the pgrep -f
  self-match pitfall"`) asserts this help text directly — this task must not touch that file or
  invalidate that assertion.

**Bounded-waiter infrastructure already complete (task 172).** Read in full:
`agent-system/extensions/core/context/patterns/bounded-build-waiter.md`. States the canonical
idiom (`cmd >log 2>&1 & pid=$!`, then `timeout N bash -c 'while kill -0 "$1" ...' _ "$pid"`),
names `lake-build-guard.sh` as a conforming example, and is explicitly the single place the
model lives — fix sites elsewhere point at it, never restate it.

**`long-builds.md`'s current structure** (read in full, 162 lines): has a "Passive progress
checks" section (`## Passive progress checks`, currently lines 101-125) listing four checks
(`.olean` mtime frontier, live PID's cmdline, accumulated CPU time, `VmRSS` trend) that all take
a `<PID>` the section never explains how to obtain, and a "### The liveness caveat" subsection
stating the checks prove liveness, never termination — but does not yet contain the sharper
"a process count is never evidence of a build's OUTCOME" statement the task specifies, nor any
`pgrep -f` prohibition. There is currently **no** section addressing how to determine a finished
build's pass/fail verdict anywhere in this file — a new section is a pure addition, not a
rewrite of existing prose.

**`lean4.md`'s "Build Commands" section** (currently lines 60-82): states the canonical
`bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- <lake args>` invocation shape
and points at `long-builds.md` for the detach+guard rationale, but contains no exit-code capture
guidance at all today.

**Three unmethoded `build_passed` sites**, confirmed by direct grep (`grep -n build_passed` on
both agent files):
1. `lean-implementation-agent.md`, Final Verification Stage, step 4 "Verify build passes"
   (currently lines 286-294): runs the guarded build detached, then `Record: build_passed
   (true/false), build_output (if failed)` — no method stated for the true/false determination.
2. `lean-implementation-hard-agent.md`, Stage 4 ("Execute File Operations Loop"), lettered step
   **D. "Verify Phase Completion"** (currently lines 232-240): runs a scoped guarded build,
   waits for the harness's completion notification, but the step's own prose never says how to
   read pass/fail from that notification — this is the dispatch's "phase-completion step D".
3. `lean-implementation-hard-agent.md`, Stage 6 ("Final Verification Stage"), step 4 "Verify
   build passes" (currently lines 390-398): identical shape and identical gap to site 1 above —
   this is the dispatch's "verification step 4".

All three currently say, in effect, "run the build, then know whether it passed" with no bridge
between the two — this unspecified predicate is exactly where the dispatch's "false green"
entered (an agent citing a `pgrep -f` process count, which can never return empty while its own
watcher lives, as evidence a build was still running/had not yet failed).

**Waiter-teardown wiring gap** (absorbed former task 175). Read in full:
`agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md`. Its "Tear
Down Watchers/Monitors Before Reporting" section (currently lines 52-59) states the general
obligation ("every agent that arms a watcher/monitor process during its own dispatch MUST tear
it down before reporting a terminal result") but does not yet name the **supersession**
transition (a waiter torn down before its watched build is cancelled/superseded, not only before
reporting) that the dispatch says actually orphaned the observed loops. Its "Where This Is
Referenced" list (currently lines 61-68) has exactly 3 entries today —
`skill-orchestrate/SKILL.md`'s Stage 5 staleness-gate comment, `context/contracts/territory.md`'s
Territory Declaration Template, and `context/standards/orchestrator-runtime-files.md` — none of
which is a build-waiter-arming agent contract. Grep-confirmed: neither lean agent file contains
the strings `bounded-build-waiter` or `dispatch-report-not-termination` in a teardown-obligation
context (the only `dispatch-report-not-termination.md` mentions in either file today are inside
the unrelated `.orchestrator-handoff.json` `dispatch_seq`-echo instructions, not near any build
invocation).

**Git-snapshot `--no-revert` gap** (absorbed former task 198). Grep-confirmed: `git-snapshot` and
`no-revert` each appear **zero times** in both `lean-implementation-agent.md` and
`lean-implementation-hard-agent.md`. `orchestrator_mode` does appear in both, but only in each
file's `.orchestrator-handoff.json`-writing section — unrelated to git-snapshot. In
`general-implementation-agent.md`, the only existing `--no-revert` usage (line 384) is inside
the CHECKPOINT-BEFORE-OVERFLOW procedure (Stage 4C, "Handoff on Context Pressure"), gated on
context pressure and RED/unconfirmed-green state, not on `orchestrator_mode` generally:

> "If dirty and RED (or green cannot be confirmed), run `bash .claude/scripts/git-snapshot.sh
> --no-revert {task_number}` instead of committing broken state (`--no-revert` is required here:
> the default and `--branch` modes both leave the tree clean at HEAD, erasing the very RED work
> this step protects)."

There is **no existing general-implementation-agent.md bullet** of the shape "MUST invoke
`git-snapshot.sh --no-revert` whenever `orchestrator_mode: true`" to copy verbatim — the
absorbed task's claim that the core agent "ALREADY calls it correctly... and explains why" is
accurate only for the narrower context-pressure case, not a general orchestrator_mode mandate.
`git-snapshot.sh`'s own header (read in full, lines 35-60) independently documents the hazard:
default mode runs `git stash push -u` with no pathspec ("WARNING: default and --branch modes
REVERT the working tree... NOT read-only"), and `--no-revert` is the durable-backup,
keep-working alternative built on `git stash create` + `git stash store`. The wording for the new
bullet should synthesize the hazard language from the script's own header (repo-global,
no-pathspec stash captures a concurrent sibling's in-flight edits) with the `--no-revert`
mechanism description already used in `general-implementation-agent.md`, since no single
existing sentence covers both the mechanism and the orchestrator_mode-triggered rationale.

### External Resources

Not applicable — this is a source-store internal-contract task with no external dependency;
all research was codebase-internal per the Search Priority (local codebase first).

### Recommendations

Five edit groups, each additive and pointer-based per the source store's established
single-statement-plus-pointer convention (the model lives in one file; every other site points
at it rather than restating it):

1. **`long-builds.md`** — add a new `## Reading the build's verdict` section (placement:
   logically before or adjacent to "Passive progress checks", since the passive checks are for
   interim observation and the verdict section is for the terminal outcome) stating the
   three-tier hierarchy from the dispatch text, strongest last:
   - Tier 1: the guard's own exit code, captured un-piped, or its `result` subcommand (point at
     the guard's own "READING THE VERDICT" documentation rather than restating the exit-code
     band).
   - Tier 2: the `Build completed successfully (N jobs)` line in the captured output file
     together with `grep -c 'error:'` returning 0 over both captured stdout and stderr.
   - Tier 3 (strongest): an `.olean`-newer-than-source check per touched module — proves
     presence in the build, not mere absence of complaint.
   State once, explicitly: never pipe the guard invocation into `tail`/`head`/`grep` and read
   `$?` afterward (that reads the pipe's own exit code); redirect to a log file and capture
   `GUARD_EXIT=$?` instead. Point at the guard's documented capture paths (`build-guard.result`,
   `.stdout`, `.stderr`, `.log`) by name rather than re-describing them.
   Also extend the same file's existing "Passive progress checks" section: name the PID source
   explicitly (`holder_pid` from the guard's result record, or `status --verbose`) so the four
   existing checks are usable without inventing a scan; add the `pgrep -f` self-match
   prohibition (any pattern naming the guard, the watcher, or the wrapper script self-matches the
   polling shell's own argv and can never return empty while the watcher lives — point at
   `bounded-build-waiter.md` Rule 2 and the guard's own header rather than re-deriving this, since
   both already state it); name the bracket-trick escape hatch (`pgrep -f '[b]in/lake build'` or
   similar) for the case a real non-self process match is genuinely needed; and strengthen "The
   liveness caveat" with the sharper statement: a process count is never evidence of a build's
   OUTCOME, and a count that cannot go to zero is not evidence of anything at all.

2. **`lean4.md`** — add the un-piped capture form (`... > log 2>&1; GUARD_EXIT=$?` shape) to the
   "Build Commands" section's canonical invocation block, plus a one-line pointer to
   `long-builds.md`'s new verdict section. Do not restate the hierarchy.

3. **Three `build_passed` sites** — replace `Record: build_passed (true/false)` (and the
   companion `build_output (if failed)` in the plain agent) with a one-line pointer to
   `long-builds.md`'s new "Reading the build's verdict" anchor, naming which tier is the minimum
   bar expected at that site (the plain agent's Final Verification Stage and the hard agent's
   Stage 6 are both terminal full-project verification and can plausibly require Tier 1+2
   together; the hard agent's Stage 4 step D is a scoped phase-end check and may accept Tier 1
   alone — this exact bar-setting decision belongs to the planning phase, not this report, since
   it is a design choice rather than a discovered fact).

4. **`dispatch-report-not-termination.md`** — extend the "Tear Down Watchers/Monitors Before
   Reporting" section with one added sentence naming the supersession transition explicitly (a
   waiter torn down before its watched build is cancelled or superseded — not only before
   reporting); add two entries to "Where This Is Referenced": the two lean agent contracts'
   build-invocation sites. In each lean agent file, add a one-line pointer (at or near the
   guarded-build invocation sites: `lean-implementation-agent.md`'s Final Verification step 4 and
   `lean-implementation-hard-agent.md`'s Stage 4 step D / Stage 6 step 4) to both
   `bounded-build-waiter.md` (the waiter idiom) and this file's teardown rule — never restating
   either.

5. **Git-snapshot `--no-revert` bullet** — add one new bullet to each lean agent file (a natural
   location is near each file's own `.orchestrator-handoff.json`/`orchestrator_mode` handling
   section, or in a pre-work-backup context if one exists) stating: `git-snapshot.sh` MUST be
   invoked with `--no-revert` whenever the dispatch runs under `orchestrator_mode: true`, and
   SHOULD be preferred generally when the agent intends to keep working after the snapshot,
   with the one-line rationale (default mode reverts the tree repo-globally via an unscoped
   `git stash push -u` and will capture a concurrent sibling's in-flight edits). Synthesize this
   wording from `git-snapshot.sh`'s own header hazard language plus the mechanism description
   already used in `general-implementation-agent.md`'s Stage 4C bullet, since no single existing
   sentence in the source store covers both the general orchestrator_mode trigger and the
   mechanism — there is nothing to copy verbatim, only a pattern to follow.

## Decisions

- Confirmed via direct file reads and greps (not assumed from the dispatch text alone) that all
  four "already covered elsewhere" claims in the dispatch are accurate: the guard's `result`
  mode, exit-code discipline, `holder_pid` idiom, and `pgrep -f` prohibition are genuinely
  present in `lake-build-guard.sh` today, and case 21 of its test suite genuinely asserts the
  help text. No guard-side or test-side work is needed or should be attempted.
- Confirmed the `skill-lake-repair/SKILL.md` non-defect claim: its `build_output=$(...)`  /
  `build_exit_code=$?` pattern is command substitution, correctly captures the guard's exit
  code, and must be left untouched.
- Confirmed the absorbed former-task-198 claim that `general-implementation-agent.md` "already
  calls it correctly" is true only in the narrow context-pressure-checkpoint sense, not as a
  general orchestrator_mode-triggered bullet — flagging this so the planner does not look for a
  verbatim sentence to copy that does not exist in that general form.
- All five target files are confirmed present, readable, and match `file_scope` in
  `specs/state.json` exactly. No sixth file is implicated by any of the three absorbed defect
  descriptions.

## Risks & Mitigations

- **Risk**: duplicating the evidence hierarchy, the waiter idiom, or the teardown rule into more
  than one file (explicitly forbidden by MUST NOT). **Mitigation**: every recommended edit above
  is phrased as a pointer to a single canonical location; the planner should enforce this as a
  phase-level acceptance check (grep for near-duplicate prose across the five files before
  closing).
- **Risk**: choosing an evidence-tier bar per `build_passed` site that is inconsistent between
  the plain agent and the hard agent's two sites, producing contracts that read as
  contradictory. **Mitigation**: treat the tier-per-site choice as one explicit planning
  decision applied uniformly by site *type* (terminal full-project verification vs. scoped
  phase-end check), not decided ad hoc per file.
- **Risk**: the acceptance criterion "redeploy and confirm the deployed tree matches" is easy to
  skip since these are source-store-only edits. **Mitigation**: the plan should include an
  explicit final phase step running the deploy script
  (`agent-system/extensions/core/scripts/deploy-headless.sh`, confirmed present) and diffing the
  regenerated `.claude/**` copies of the five touched files against the source store.
- **Risk**: this task's file_scope overlaps with a separate, currently-blocked sibling task
  (visible in `specs/TODO.md`) that depends on task 221 landing first and explicitly says line
  numbers there must be re-derived after this task lands — no action needed now, but the planner
  should not be surprised if a future task references stale line numbers into these same files.

## Context Extension Recommendations

- **Topic**: none identified as a gap in `.claude/context/` coverage — this task's subject
  matter (build-verdict evidence hierarchy, waiter teardown wiring, snapshot mode selection) is
  fully addressed by extending existing, correctly-scoped anchor files
  (`long-builds.md`, `dispatch-report-not-termination.md`, `bounded-build-waiter.md`); no new
  context file is warranted.

## Appendix

- Search queries / commands used: `grep -n` for `build_passed`, `pgrep`, `holder_pid`,
  `git-snapshot`, `no-revert`, `orchestrator_mode`, `bounded-build-waiter`,
  `dispatch-report-not-termination`, `Tear Down Watchers`, `case 21` across the five target
  files, `lake-build-guard.sh`, its test suite, `bounded-build-waiter.md`,
  `general-implementation-agent.md`, and `skill-lake-repair/SKILL.md`; full `Read`s of
  `long-builds.md`, `lean4.md` (rule file), both lean agent files' relevant sections,
  `bounded-build-waiter.md`, `dispatch-report-not-termination.md`, and the guard script's header
  and `print_help()`; `jq` queries against `specs/state.json` for task 221's `file_scope` and
  dependency status (172, 173, 194 — all completed/archived).
- Key file line references (subject to drift as the files are edited in the implementation
  phase; re-derive before applying edits): `long-builds.md` "Passive progress checks" at lines
  101-125; `lean4.md` "Build Commands" at lines 60-82; `lean-implementation-agent.md` Final
  Verification step 4 at lines 286-294; `lean-implementation-hard-agent.md` Stage 4 step D at
  lines 232-240 and Stage 6 step 4 at lines 390-398; `dispatch-report-not-termination.md` "Tear
  Down Watchers/Monitors Before Reporting" at lines 52-59 and "Where This Is Referenced" at
  lines 61-68.
