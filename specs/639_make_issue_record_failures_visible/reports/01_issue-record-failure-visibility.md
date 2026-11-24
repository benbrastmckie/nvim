# Research Report: Task #639

**Task**: 639 - Make issue-record.sh failures visible instead of silently losing the evidence entry
**Started**: 2026-11-23T00:00:00Z
**Completed**: 2026-11-23T00:00:00Z
**Effort**: 2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core source store), task-directory state.json/dispatch records
**Artifacts**: - specs/639_make_issue_record_failures_visible/reports/01_issue-record-failure-visibility.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed defect: `issue-record.sh`'s manual argument parser has no `*)` default other than
  `echo "error: unknown argument: $1" >&2; usage` (`agent-system/extensions/core/scripts/issue-record.sh:148`,
  reached from the `while` loop's `case` at lines 128-147). Every call site, including the
  hand-typed agent-facing template `orchestrate-build-dispatch.sh` renders at lines 922-926,
  prescribes `>/dev/null 2>&1 || echo "Note: issue recording failed (non-fatal)" >&2`, which
  redirects BOTH stdout and stderr before the caller's own fallback note fires. A mistyped flag
  (e.g. `--session-id` instead of `--session`) is therefore indistinguishable, from the outside,
  from a genuine, expected recording failure — both produce only the generic "non-fatal" note.
- The task description's cited line numbers (52-55, 139, 141) do not match the current file
  (the invocation-contract comment is now at lines 59-62; the unknown-argument arm is at line
  148) — expected drift from unrelated header-comment growth (the central-log-promotion
  paragraph), not a sign the defect was already fixed. Re-verified directly: the defect is live.
- `issue-record.sh` has exactly one non-zero exit code today (`1`, documented at lines 64-67) for
  every refusal class — argument/usage error and a resolution/lookup failure are not
  distinguished by exit status, only by stderr text that the documented invocation form
  discards.
- `test-issue-record.sh` case (i) already proves the *content-shaped* failure path (a
  `--task-dir` pointing at a nonexistent directory) stays non-fatal to the caller under the
  documented form, but no case exercises an *argument-shaped* failure (an unrecognized flag)
  under that same redirected form — the gap the acceptance criteria name.
- Three candidate fixes are available (named in the task description); this report assesses each
  against the acceptance criteria and recommends the breadcrumb/unconditional-diagnostic
  approach (or a minimal variant of it) as the lowest-blast-radius option, since it requires no
  change to any of the ~20 existing call sites' invocation text. See Recommendations.
- Territory: the migration-era contention list naming 20 overlapping records is now entirely
  stale — every one of the previously-cited contending tasks (484, 477, 535, 541, 486, 517, 567,
  675, 683, 398, 451, 504) shows `status: "completed"` in the live `specs/state.json`. The only
  current contention is this cycle's own concurrent siblings (tasks 693, 697, 645), none of which
  declare any of this task's seven `file_scope` paths by name — task 693 does declare
  `__WHOLE_TREE__`, which is a coarse/undeclared scope that could in principle touch anything;
  see Risks.

## Context & Scope

The task asks for a fix making a silently-dropped `issue-record.sh` call (due to a mistyped CLI
flag) produce a diagnostic some reader or agent can attribute to the mistyped flag, without
breaking the non-fatal guarantee every call site relies on. Scope is bounded to the seven files
the task's `file_scope` declares: `scripts/issue-record.sh`, `scripts/tests/test-issue-record.sh`,
`context/formats/issue-log.md`, `scripts/orchestrate-build-dispatch.sh`, `scripts/git-commit-phase.sh`,
`scripts/orchestrate-cycle-plan.sh`, `scripts/orchestrate-cycle-postflight.sh` (all under
`agent-system/extensions/core/`). This research phase verifies the defect directly against the
current source-store file state, maps every existing call site and its invocation form, confirms
the exact gap in the regression suite, and evaluates the three candidate fixes the task
description names — it does not implement any of them.

**Edit-target confirmation**: this repository's `.claude/` tree is the gitignored deploy
artifact; every file above resolves only under the source store at
`agent-system/extensions/core/`, consistent with `.claude-extensions.json`'s `core.source_dir`.
`issue-record.sh` itself refuses to run directly from the source store
(`deploy-root-guard.sh`'s by-design refusal) — a fact already captured in this task's injected
memory context and reconfirmed by reading `deploy-root-guard.sh`'s sourcing line in
`issue-record.sh`. The implementing dispatch must deploy before exercising the script, exactly as
the task description states.

## Findings

### Codebase Patterns

**The defect, precisely located.** `issue-record.sh`'s manual `while`-loop argument parser
(lines 128-147) has a catch-all case:

```bash
*) echo "error: unknown argument: $1" >&2; usage ;;
```

(`agent-system/extensions/core/scripts/issue-record.sh:148`). `usage()` prints the full usage
block to stderr and calls `exit 1` (lines 75-104). Every documented exit code the script
produces is `0` (appended) or `1` (any refusal — missing required argument, invalid closed-enum
value, malformed `--tags-json`, unresolvable `--task`/`--task-dir`, **or** an unrecognized flag).
There is no second, argument-shaped exit code today.

**The invocation contract swallows both streams.** The script's own header (lines 59-62) and
every call site document/use:

```bash
bash .claude/scripts/issue-record.sh ... >/dev/null 2>&1 || \
  echo "Note: issue recording failed (non-fatal)" >&2
```

`>/dev/null 2>&1` redirects stdout (the `entry_id` on success) and stderr (every error/warning
message) to `/dev/null` *before* the `||` fallback is evaluated. On any failure the caller sees
only the generic fallback note — it cannot distinguish "argument typo, nothing written" from
"task directory temporarily unresolvable, nothing written" from the leniency warnings the script
itself intentionally allows through on *successful* calls with an off-seed `--class` value (those
warnings are also discarded by this same redirection on a success path, which is arguably a
separate, smaller loss but not this task's acceptance criterion).

**Confirmed against the current file, not just the task description's citation.** The task
description cites line numbers (`--session-id` falls through at "line 141", contract at
"lines 52-55") that do not match the file as it stands today (unknown-argument arm at line 148;
contract at lines 59-62). This is pure drift from an unrelated header-comment addition (the
central-log-promotion paragraph documented at lines 20-27) made after the task was filed — not
evidence the defect was already addressed. The defect was re-derived directly by reading the
live file end-to-end rather than trusted from the citation, and is confirmed live.

**Call-site survey — every call site is a programmatic, not hand-typed, invocation except one.**
Searching `agent-system/extensions/core/scripts/*.sh` for every `issue-record.sh` call site
confirms the description's claim that all follow the documented non-fatal form:

- `git-commit-phase.sh` (4 call sites: lines 552, 562, 891, 902, 929 — all `>/dev/null 2>&1 ||
  warn "issue-record.sh call failed (non-fatal)"`)
- `orchestrate-cycle-plan.sh` (3 call sites: lines 1506, 1782, 1810)
- `orchestrate-cycle-postflight.sh` (11 call sites: lines 1137, 1367, 1559, 1599, 1616, 1802,
  1824, 1885, 2285, 2332 — all `>/dev/null 2>&1 || echo "Note: issue recording failed
  (non-fatal)" >&2`)
- `orchestrate-build-dispatch.sh` itself (line 370, a real programmatic call recording a
  `sapience-retrieve.sh` transport failure) **plus** the rendered agent-facing *template* at
  lines 922-926, which is the one a dispatched agent hand-copies and can mistype.

Every *programmatic* call site builds its flags from shell variables/constants, so a flag-name
typo there would be a code bug caught the first time that line executes (it either always works
or always fails identically) — not the silent, intermittent, per-dispatch loss the task
describes. **The actual risk surface for a mistyped flag is specifically the rendered
agent-facing template** (`orchestrate-build-dispatch.sh:922-926`, reproduced verbatim in this
task's own dispatch file's `## Issue Log` section), which an agent re-types or adapts by hand
when adding optional fields — exactly the scenario the cited `275` evidence (`--session-id` for
`--session`) demonstrates.

**Regression-suite gap, confirmed.** `test-issue-record.sh` case (i) ("non-fatal failure") tests
a *content*-shaped failure: `--task-dir` pointing at a directory that does not exist, which is a
true runtime/resolution failure after argument parsing succeeds. It proves the documented
non-fatal wrapper correctly absorbs that failure class. No existing case (a–v) exercises an
*argument*-shaped failure (an unrecognized or misspelled flag) at all, let alone under the
redirected non-fatal form — this is precisely acceptance criterion (3)'s gap. The suite's
existing harness (`build_scratch`, `run_ir`) already provides everything a new case needs: it
can invoke `run_ir "$scratch" --session-id ... ` (or any other misspelled flag) and assert (a)
the direct exit code is non-zero and no line was written (mirrors case (c)/(e)'s shape), and (b)
under the exact non-fatal wrapper form, the caller's own exit stays 0 while *some* diagnostic
(whatever the implementation adds) is observable to the caller.

**Documentation that must stay in sync.** `context/formats/issue-log.md` lines 57-59 state
"Recording is always non-fatal. ... Every call site uses the documented non-fatal invocation form
(see `scripts/issue-record.sh`'s header)." This sentence does not currently assert anything about
argument-error visibility, so it is not strictly contradicted today — but acceptance criterion
(4) requires it and the script's own header comment to agree with whatever the implementation
changes, which likely means adding a clause here regardless of which candidate fix is chosen.

### External Resources

Not applicable — this is a pure in-repo shell-scripting defect with no external library or API
surface; no web research was needed or performed.

## Recommendations

All three candidates the task description names are technically viable; they differ in blast
radius and in how cleanly they map onto the two acceptance criteria that pull in opposite
directions (visible diagnostic vs. untouched non-fatal guarantee for every *other* caller).

1. **Accept both flag spellings** (e.g. alias `--session-id` to `--session`). This fixes only the
   one historically-observed typo, not the general silence defect the task explicitly frames as
   the real problem ("THE DEFECT IS THE SILENCE, NOT THE FLAG NAME"). Recommended only as a
   supplementary, cheap addition alongside one of the other two — never as the sole fix, since it
   leaves every *other* possible mistyped flag just as silent as before.

2. **Separate argument/usage errors from write errors by exit code, and make the former survive
   output redirection via an unconditional diagnostic on an unredirected path or a breadcrumb
   file beside `issues.jsonl`.** This is the option that touches only `issue-record.sh` itself
   (plus its test and the two doc comments) and leaves every one of the ~20 existing call sites'
   invocation text completely untouched, because the new signal does not travel through stdout/
   stderr at all — it is written directly to a file path the caller's shell redirection cannot
   reach (a direct `>>` from inside the script to, say,
   `${TASK_DIR}/.issue-record-errors.log`, independent of the inherited fd 1/2 redirection).
   This is the **recommended** candidate: lowest blast radius (one file's logic changes, no
   caller needs to change), satisfies criterion (1) (a reader — human or a later agent/
   conclusion-stage pass — can discover the breadcrumb), and leaves criterion (2) untouched by
   construction (the caller's exit-code handling is unchanged). The new exit code (distinct from
   the existing `1`) is valuable mainly for the regression test's own assertions and for any
   future caller that wants to branch on it; it is not load-bearing for visibility, the
   breadcrumb file is.

3. **Revise the prescribed invocation form so stderr is no longer swallowed** (e.g.
   `>/dev/null || echo "Note: issue recording failed (non-fatal)" >&2`, redirecting only stdout).
   This makes the script's own `error:`/`warning:` lines visible in the dispatch's own
   transcript without any change to the script itself, and keeps the non-fatal `||` guarantee
   intact (the exit-code check is unaffected by which streams are redirected). Its cost is
   breadth: the contract change should then be propagated to the ~20 existing call sites and the
   two documentation sites (header comment, `issue-log.md`) for consistency, and it also exposes
   the script's *every* stderr output (including the intentional `--class` leniency warnings on
   otherwise-successful calls) into every caller's transcript, which may be a desirable side
   benefit (the `--class` warnings are currently invisible even on success) or undesirable noise,
   depending on how the implementing task judges it.

**Recommendation**: implement candidate (2) as the primary fix (breadcrumb file + distinct exit
code), optionally layering candidate (1) (accept `--session-id` too, since it is the one
concretely-observed typo) as a cheap belt-and-suspenders addition. Candidate (3) is a reasonable
alternative if the implementing task prefers a single-file contract change over a new on-disk
artifact, but it carries strictly more call sites to touch and a behavior change (every stderr
warning becomes visible) beyond what the acceptance criteria require — the implementing task
should weigh and justify its choice explicitly, as the task description itself asks.

Whichever candidate is chosen, the implementation must:
- Add a `test-issue-record.sh` case exercising a misspelled flag (e.g. `--session-id`) invoked
  through the exact documented non-fatal wrapper form, asserting (a) the caller's own exit stays
  0, and (b) the chosen diagnostic channel (breadcrumb file, new exit code, or visible stderr)
  actually surfaces something attributable to the mistyped flag.
- Update both `issue-record.sh`'s header invocation-contract comment and
  `context/formats/issue-log.md`'s "Recording is always non-fatal" sentence to describe the new
  behavior consistently (criterion 4).
- Re-run the full `test-issue-record.sh` suite (cases a–v) to confirm no regression (criterion
  5) — case (i) in particular, since it is the existing control for "non-fatal under redirection"
  and must keep passing unchanged.

## Decisions

- Scoped this research to verifying the defect and the regression-suite gap directly against the
  live source-store files rather than trusting the task description's line-number citations,
  per `report-format.md`'s Carried-Figure Discipline — the citations have drifted (expected) and
  the underlying defect is confirmed independently.
- Did not attempt to pick a single final implementation among the three candidates on this
  task's behalf; the task description explicitly frames this as a choice for the implementing
  dispatch to make and justify. This report provides a ranked recommendation (candidate 2,
  optionally with candidate 1) rather than a final binding decision.

## Risks & Mitigations

- **Territory**: this cycle's own concurrent siblings are tasks 693 (implement,
  `__WHOLE_TREE__` plus two named files), 697 (research, one unrelated test file), and 645
  (research, seven unrelated test files) — none of the named siblings declare any of this task's
  seven `file_scope` paths. Task 693's `__WHOLE_TREE__` declaration is coarse/undeclared and
  could in principle touch any file; mitigate by re-reading each of the seven target files
  immediately before editing/committing in the implement phase, and staging/committing only this
  task's own hunks (never a directory or glob add), per `context/contracts/territory.md`'s
  Cross-Task Territory guidance.
- **Stale migration-era contention list is superseded, not current**: the dispatch file's
  migration provenance section names 20 overlapping records as of the 2026-11-16 relocation;
  every one checked (484, 477, 535, 541, 486, 517, 567, 675, 683, 398, 451, 504) is now
  `completed` in `specs/state.json`. Risk of acting on that stale list as if it still describes
  live contention is low but worth flagging explicitly so the implementing dispatch does not
  over-serialize against records that no longer exist as open work.
- **Breadth risk if candidate 3 is chosen**: revising the invocation contract touches ~20 call
  sites across 3 scripts plus 2 doc files; a partial rollout (some call sites updated, others
  left on the old `>/dev/null 2>&1` form) would reintroduce exactly the inconsistency acceptance
  criterion (4) exists to prevent. Mitigate by grepping for every occurrence of `"issue recording
  failed (non-fatal)"` (9 files, confirmed by this research) before considering that candidate
  done.
- **Deploy-before-exercise friction**: `issue-record.sh` cannot run from the source store
  (`deploy-root-guard.sh` refusal, already documented in this task's own injected memory
  context). The implementing dispatch must deploy into a tree (or use a scratch
  `.claude/scripts/` mirror, as `test-issue-record.sh`'s own harness already does) before any
  manual exercise of the fix; the automated test suite's `build_scratch` harness already handles
  this correctly and needs no change in this respect.

## Context Extension Recommendations

None. The relevant conventions (non-fatal invocation form, issue-log schema, deploy/source-store
boundary) are already documented in `context/formats/issue-log.md`,
`context/contracts/territory.md`, and this task's own injected memory context; no new context
file is warranted by this research.

## Appendix

**Search queries / commands used**:
- `grep -n` over `issue-record.sh` for argument-parsing structure, exit codes, and the
  invocation-contract comment.
- `grep -rn "issue-record.sh"` across `agent-system/extensions/core/scripts/*.sh` to enumerate
  every call site and confirm the documented non-fatal form at each.
- `grep -rln "issue recording failed (non-fatal)"` across `agent-system/` to enumerate every
  file carrying the exact invocation-contract string (9 files: `issue-record.sh`,
  `orchestrate-cycle-postflight.sh`, `orchestrate-cycle-plan.sh`, `orchestrate-build-dispatch.sh`,
  `test-issue-record.sh`, `test-orchestrate-cycle-postflight.sh`, `test-orchestrate-cycle-plan.sh`,
  `context/contracts/phase-closure.md`, and one unrelated extension file
  `extensions/books/.../signal-tagging.md`, which is out of this task's scope and not touched by
  its `file_scope`).
- Read `test-issue-record.sh` in full (cases a–v) to confirm the exact regression-suite gap.
- Read `context/contracts/territory.md`'s Cross-Task Territory section per the dispatch's
  instruction, and cross-checked the dispatch's own Territory JSON and the task-directory
  migration provenance's territory-contention list against the live `specs/state.json` (all
  previously-cited contending tasks are now completed).

**References**:
- `agent-system/extensions/core/scripts/issue-record.sh` (lines 61-62 invocation contract,
  128-148 argument parser, 64-67 exit-code documentation)
- `agent-system/extensions/core/scripts/tests/test-issue-record.sh` (case (i), lines ~244-266)
- `agent-system/extensions/core/context/formats/issue-log.md` (lines 57-59)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (lines 922-926)
- Task description: `specs/639_make_issue_record_failures_visible/.dispatch/10.md`
