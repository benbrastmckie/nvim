# Research Report: Task #428

- **Task**: 428 - Enforce and detect planner-agent terminal return-meta write
- **Started**: 2026-11-04T00:00:00Z
- **Completed**: 2026-11-04T00:00:00Z
- **Effort**: ~1 hour (diagnosis only, no code changes)
- **Dependencies**: Task 378 (completed)
- **Sources/Inputs**: Codebase (agent-system/extensions/core/**), specs/archive (prior completed
  task 426), .claude/docs/architecture/handoff-schema.md
- **Artifacts**: specs/428_enforce_planner_agent_terminal_write/reports/01_terminal-write-enforcement.md
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The incident this task cites (task 328, `iss_1792162538950_NYX4YD`) was already fully
  diagnosed and substantially remediated by a prior, now-archived task (426,
  `recovery_declined_cannot_tell_stall_from_agent_fault`, completed 2026-10-18), which cites the
  **identical** entry_id as its own root cause.
- 426 fixed two concrete attribution bugs in `orchestrate-cycle-postflight.sh`'s
  `RECOVERY_DECLINED` arm (a hardcoded `--phase implement` and a structurally-always-empty
  `--dispatch-seq`) and added stall/strand-signal corroboration so a reader can distinguish an
  abandoned wrap-up (work intact, remedy is one re-prompt) from an uncorroborated agent-contract
  violation — all without touching the handoff-staleness gate.
- 426 also inspected `planner-agent.md`'s terminal-write contract directly and concluded, on the
  record, that it "needs no edit": the contract already states the write as a MUST at Stage 0
  (early, `in_progress`) and Stage 6b/6c (terminal), with explicit MUST-DO items and a
  documented error-handling branch for every failure mode the contract itself can specify text
  for.
- The genuine remaining gap is **structural, not textual**: nothing in the `/orchestrate` →
  `skill-orchestrate` → `planner-agent` dispatch path can mechanically force the dispatched
  subagent to execute through to its own terminal write before its turn ends. The one piece of
  harness-level enforcement infrastructure that exists in this codebase for exactly this purpose
  — the `.postflight-pending` marker plus the `SubagentStop`-wired `subagent-postflight.sh`
  block — is wired only into `skill-reviser`, `skill-spawn`, and the extension-provided
  `skill-{domain}-research`/`-implementation` skills. `skill-orchestrate`'s own direct
  Agent-tool dispatch of `planner-agent`/`general-research-agent`/`general-implementation-agent`
  for core task types (the exact path that produced the task 328 incident) never calls
  `skill_create_postflight_marker` at all, so that enforcement mechanism cannot fire for this
  dispatch path regardless of what the marker check does once triggered.
- Recommendation: treat 426 as having already discharged this task's "diagnose + close the
  detection/contract hole" scope for the cited incident. The one additional, well-bounded
  prevention mechanism identified here — wiring a per-dispatch postflight marker into
  `skill-orchestrate`'s own Agent-tool call so `SubagentStop` can check the just-finished
  dispatch's own `.return-meta.json` terminal status before allowing the stop — is new
  infrastructure with real design risk (loop-guard interaction, false blocks on legitimate
  stops) and is scoped out of this report as a candidate follow-up task rather than folded into
  428's own implementation, per the diagnosis below.

## Context & Scope

Task 428 asks to diagnose where `planner-agent`'s terminal `.return-meta.json` write can be
skipped and close that hole, in the agent's own contract, in postflight's detection, or both —
under the hard constraint that the existing handoff-staleness gate must not be weakened. The
citation is task 328's issue entry `iss_1792162538950_NYX4YD`: a planner-agent dispatch left
`.return-meta.json` at `status: in_progress` and wrote no `.orchestrator-handoff.json`, forcing
postflight's return-meta recovery fallback.

This report traces (1) what `planner-agent.md`'s contract currently requires, (2) what
`orchestrate-cycle-postflight.sh` and `orchestrate-recover-outcome.sh` currently do when this
exact shape occurs, (3) what a prior, completed task already changed in response to the *same*
cited incident, and (4) what harness-level enforcement machinery exists elsewhere in the
codebase that could, in principle, prevent rather than merely detect the gap.

## Findings

### Codebase Patterns

**`planner-agent.md`'s contract is already complete on paper.** (`agent-system/extensions/core/agents/planner-agent.md`)
- Stage 0: "Create `.return-meta.json` with `status: "in_progress"` BEFORE any substantive
  work" (line 36).
- Stage 6b: ordinary terminal write, `status: "planned"` (line 446).
- Stage 6c: `needs_research` terminal write when Stage 1.5 declines to plan (lines 481-509).
- Error Handling section: explicit branches for invalid task (write `failed`), timeout (write
  `partial` with resume info), file operation failure (write `failed` with error description)
  (lines 560-571).
- MUST-DO list items 1, 2, 7, 9 all restate the write obligation from different angles,
  including item 9's explicit override of any generic harness note that might otherwise
  discourage file writes (lines 574-584).

There is no documented code path in the contract text itself that reaches a `Stop`/return
without having executed one of Stage 6b/6c/the error-handling branches. The gap, when it
occurs, is therefore an *execution-time* failure to follow the agent's own already-correct
contract (model stops early, infra interruption, context exhaustion mid-dispatch, or any other
unrecoverable interruption before Stage 6b/6c runs) — not a hole in what the contract says.

**`orchestrate-recover-outcome.sh` already discriminates this exact shape precisely.**
(`agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh`)
- `META_MISSING` (no file), `META_STALE` (mtime predates the dispatch window — catches a
  leftover file from a *prior* dispatch, never this one), `META_UNPARSEABLE`,
  `META_DISPATCH_SEQ_MISMATCH` (D2, catches a still-live predecessor's or git-restored file)
  are all handled as separate, correctly-labeled reasons.
- `status == "in_progress"` is its own named case (`STATUS_IN_PROGRESS`), distinct from
  `STATUS_NOT_SUCCESS` (an out-of-vocabulary terminal value such as `"completed"`).
- `is_return_meta_success_status` is sourced from a single shared vocabulary library
  (`return-meta-status-vocabulary.sh`), not re-implemented per caller.

**`orchestrate-cycle-postflight.sh`'s absent-handoff / `RECOVERY_DECLINED` arm** (around line
1009 in the current file) branches on exactly this `decline_reason` set
(`STATUS_IN_PROGRESS|STATUS_NOT_SUCCESS|META_DISPATCH_SEQ_MISMATCH`) and records a
`RECOVERY_DECLINED` defect, attributed to the dispatched agent's own source file, via
`system-defect-record.sh` and an adjacent `issue-record.sh` call. This is the exact mechanism
that produced the cited `iss_1792162538950_NYX4YD` entry.

### Prior Work on This Exact Incident (Task 426, completed)

`specs/archive/426_recovery_declined_cannot_tell_stall_from_agent_fault/` is a **completed**
task whose own citation is `task 328, issues.jsonl entry_id iss_1792162538950_NYX4YD` — the
identical incident 428 cites. Reading its summary
(`summaries/01_recovery-declined-stall-strand-discrimination-summary.md`) and its original task
description (preserved in `specs/archive/state.json`), it:

1. **Confirmed the detection already fires correctly** — its own task description states, "this
   case is already DETECTED... The cited issue entry's `what_happened` text is verbatim that
   arm's own `recovery_declined_detail` string."
2. **Fixed DEFECT B**: the `issue-record.sh` call in the `RECOVERY_DECLINED` arm hardcoded
   `--phase implement`, so the cited planner dispatch's entry was mis-phased. Changed to pass
   the real `$phase`.
3. **Fixed DEFECT C**: the same call passed `--dispatch-seq "$handoff_dispatch_seq"`, a variable
   that is structurally always empty inside the absent-handoff branch (it is assigned only in
   the handoff-*present* branch). Changed to pass `$expected_dispatch_seq` (this cycle's own
   minted seq, which IS in scope).
4. **Addressed DEFECT A**: added arm-local, record-time-only corroboration
   (`rd_stall_corroborated`/`rd_stall_commit_count`, `rd_strand_corroborated`/`rd_strand_verdict`)
   so a `RECOVERY_DECLINED` record's own detail text, `--tags-json`, and the loop-guard row
   state whether the stall/strand signals (computed ~1080 lines later in the same script)
   corroborate an abandoned-wrap-up reading, without widening either canonical signal's own
   trigger expression (both carry on-the-record DELIBERATE NON-WIDENING rulings this task
   respected) and without changing the classification itself (every `RECOVERY_DECLINED`
   occurrence remains `blocking` severity).
5. **Explicitly inspected and declined to edit** `docs/architecture/handoff-schema.md`'s
   Postflight Boundary section, `infra-failure-discrimination.md`, and — directly on point for
   428 — `agents/planner-agent.md`'s terminal-write contract, "confirmed by inspection... the
   agent contract already states the terminal write as a MUST."
6. Extended `test-orchestrate-cycle-postflight.sh` with regression fixtures for all of the
   above; closed a test-sandbox gap (`issue-record.sh` was missing from the test harness's
   `require_file`/`setup_sandbox` copy list, silently no-opping the issue-write side of every
   prior `RECOVERY_DECLINED` fixture).
7. Did not touch the handoff-staleness gate at all (confirmed by `git diff` scoping in its own
   summary) — the same hard constraint 428 restates.

426's own Non-Goals/Follow-ups explicitly left two things out of its scope: (a) the sibling
`handoff_dispatch_seq`-pattern bug at several *successful*-recovery call sites (different defect
class, filed separately), and (b) a structural limitation where a single-task dispatch using
`--loop-guard-file` can never observe `stranded_suspected=true` (filed as a separate minor
issue). Neither bears on 428's cited incident or its hard constraint.

### Structural Gap: No Harness-Level Write Enforcement on This Dispatch Path

Given that 426 already closed the documented textual/detection gaps for the cited incident, this
report investigated whether a *preventive* mechanism — something that stops the dispatched
subagent from ending its own turn before its terminal write lands — exists or is feasible, since
that is the only remaining way to "close the hole" rather than classify it after the fact.

**A mechanism for exactly this purpose already exists in the codebase, but is wired to a
different set of callers:**

- `scripts/skill-base.sh`'s `skill_create_postflight_marker()` writes
  `{task_dir}/.postflight-pending`, keyed by `cc_session_id` (Claude Code's own native session
  UUID, captured from hook stdin's top-level `.session_id`).
- `hooks/subagent-postflight.sh` is registered under the `SubagentStop` hook matcher. On firing,
  it enumerates every `.postflight-pending` marker, selects the one whose `cc_session_id`
  matches the stopping session, and — if found — returns `{"decision": "block", "reason": ...}`,
  preventing the stop (subject to a `MAX_CONTINUATIONS` loop guard and a `stop_hook_active`
  re-entrancy guard).
- `hooks/events-log-lifecycle.sh` performs the identical marker-correlation lookup for its own
  `SubagentStop` branch, confirming the pattern is established, not one-off.

**However**, `skill_create_postflight_marker` is called only from `skill-reviser/SKILL.md`,
`skill-spawn/SKILL.md`, and the extension-provided `skill-{domain}-research`/
`skill-{domain}-implementation` skills (per `context/patterns/skill-lifecycle.md`'s Stage 3 and
`docs/guides/creating-skills.md`). A repository-wide search confirms **zero** occurrences of
`skill_create_postflight_marker`, `postflight-pending`, or `postflight_marker` in
`skill-orchestrate/SKILL.md`, `orchestrate-cycle-plan.sh`, or
`orchestrate-cycle-postflight.sh` — the exact files that drive the `/orchestrate` →
`planner-agent` dispatch path where the task 328 incident occurred. Per CLAUDE.md's own
"Core Task Types" table, this is architecturally expected: core task types (`general`, `meta`,
`markdown`) "route directly to agents via `skill-orchestrate`'s dispatch
(`command-route-agent.sh`), not through a dedicated research/plan/implement skill layer" — i.e.
there is no intermediate skill in this path that would ever call
`skill_create_postflight_marker` on `planner-agent`'s behalf.

**Consequence**: the one `SubagentStop`-level block mechanism in this codebase cannot fire for a
`planner-agent` dispatch issued by `/orchestrate`, regardless of what it would check once
triggered, because no marker is ever created for that dispatch. The gap this task cites is
therefore unreachable by extending `subagent-postflight.sh`'s existing check logic alone — it
would require *also* wiring marker creation into `skill-orchestrate`'s own dispatch flow, which
is new cross-cutting infrastructure (not a contract-text fix and not a postflight-detection fix
in the sense 428 names), with its own design surface:
  - `hooks/events-log-lifecycle.sh`'s own header notes Claude Code hook stdin "carries no
    *agent-system workflow* session_id or task number directly" — any new check still needs the
    marker's path-encoded `task_dir` to know which `.return-meta.json` to read, exactly as the
    existing two hooks already rely on.
  - The existing marker's *purpose* is to force the **orchestrating session's own** postflight
    to run (a different concern: "did the skill finish its own bookkeeping after the agent
    returned," not "did the agent itself finish writing before returning"). Reusing the same
    marker file for a second, different check (the dispatched agent's own return-meta
    completeness) would need to be scoped carefully so it does not, e.g., trip on a genuinely
    in-flight multi-phase implementation dispatch that legitimately has not yet reached a
    terminal status at some intermediate `SubagentStop` fire (`events-log-lifecycle.sh` already
    notes "a SubagentStop may fire more than once per loop-guard continuation").
  - `transcript_path`, the one other piece of per-subagent context hook stdin carries, has zero
    existing usages anywhere in `agent-system/extensions/core/` outside its own schema
    documentation (`context/formats/events-format.md`) — there is no established pattern in
    this codebase for deriving a task_dir from it, so it is not a ready-made alternative
    correlation key.

### External Resources

Not applicable — this is a self-contained codebase/architecture question; no external
documentation or library behavior is at issue.

## Decisions

- **Scope the "already addressed" portion out of further work.** The textual agent-contract gap
  and the postflight-detection gap that 428's description frames as the two candidate fix
  locations were both already investigated and closed by task 426 against the identical cited
  incident. Re-doing that work would duplicate 426's fixtures and findings without changing any
  behavior.
- **Treat the SubagentStop/marker-wiring prevention mechanism as a distinct, separately-scoped
  candidate**, not as 428's own implementation target. It is new infrastructure crossing a
  different architectural boundary (`skill-orchestrate`'s dispatch flow, which by design has no
  intermediate skill layer for core task types) rather than a close-the-contract-gap or
  narrow-the-detection fix, and carries non-trivial design risk (loop-guard interaction,
  legitimate-mid-dispatch false blocks, reuse-vs-separate-marker question) that a research
  report should surface, not resolve unilaterally.
- **Did not modify the handoff-staleness gate** in any file read during this investigation — no
  code changes were made in this research phase; this decision records that the diagnosis path
  taken never required touching that gate, consistent with the hard constraint.

## Recommendations

1. **Treat task 428 as substantially discharged by task 426 for the cited incident**, and use
   the plan phase to decide between two concrete, low-risk closing moves rather than new
   detection/contract work:
   - (a) Add a short, explicit note to `context/patterns/system-defect-discrimination.md`'s
     `RECOVERY_DECLINED` registry row (already annotated once by 426) or to
     `docs/architecture/handoff-schema.md`'s Postflight Boundary section, stating plainly that
     `RECOVERY_DECLINED` detection (task 426) is this system's deliberate, sole enforcement
     mechanism for a dispatched agent's terminal-write obligation on the `/orchestrate` path,
     and that no `SubagentStop`-level prevention exists for that path by design (core task types
     have no intermediate skill to carry a postflight marker). This closes 428 by documenting
     the already-correct state of the system rather than inventing new mechanism.
   - (b) If the team instead wants genuine *prevention* (blocking the dispatched agent's own
     stop before an incomplete terminal write), scope that as a distinct follow-up task: extend
     `skill-orchestrate`'s dispatch flow to call `skill_create_postflight_marker` (or an
     equivalent, dispatch-scoped marker) immediately before each Agent-tool call, and extend
     `subagent-postflight.sh` (or a new, narrowly-scoped sibling hook) to additionally check
     `{task_dir}/.return-meta.json`'s `.status` against the recognized terminal vocabulary before
     allowing the stop — reusing the exact `cc_session_id` correlation idiom
     `subagent-postflight.sh`/`events-log-lifecycle.sh` already establish. This is real new
     infrastructure and should be its own plan, not folded into 428's remaining budget.
2. Do not re-open or duplicate any of 426's fixtures (`test-orchestrate-cycle-postflight.sh`'s
   I2/J1/J2/J3 cases) — they already cover the `RECOVERY_DECLINED` phase/dispatch_seq
   attribution and stall/strand corroboration for this exact incident shape.
3. If the planner chooses option (b) above, explicitly carry forward the three design
   constraints found in this report: (i) the marker's existing purpose (force the orchestrator's
   own postflight) must not be silently overloaded without scoping the new check separately;
   (ii) `SubagentStop` can fire more than once per loop-guard continuation, so the new check must
   not misfire on a legitimately-still-running multi-phase dispatch; (iii) no existing
   `transcript_path`-based correlation precedent exists in this codebase to fall back on if the
   marker approach proves unworkable.

## Context Extension Recommendations

- **Topic**: Scope boundary of `skill_create_postflight_marker`/`SubagentStop` enforcement.
- **Gap**: `context/patterns/skill-lifecycle.md` and `docs/guides/creating-skills.md` document
  how a skill that already imports the shared postflight-marker block uses it, but nothing in
  the currently-loaded context states, as a cross-cutting fact, that `skill-orchestrate`'s own
  direct-to-agent dispatch path for core task types has no equivalent per-dispatch marker and
  therefore no `SubagentStop`-level enforcement at all. A future author reaching for
  `subagent-postflight.sh` as "the" terminal-write enforcement mechanism would otherwise
  reasonably assume it already covers the orchestrate path.
- **Recommendation**: add one sentence to `docs/architecture/handoff-schema.md`'s Postflight
  Boundary section (or `context/patterns/system-defect-discrimination.md`'s `RECOVERY_DECLINED`
  row) naming this scope boundary explicitly, per Recommendation 1(a) above.

## Appendix

- Searches/reads performed: `agent-system/extensions/core/agents/planner-agent.md`;
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (targeted `grep` over
  2416 lines, full read of RECOVERY_DECLINED-adjacent region via line-number index);
  `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` (full read);
  `specs/archive/426_recovery_declined_cannot_tell_stall_from_agent_fault/` (summary, plan
  metadata, archived task description in `specs/archive/state.json`);
  `specs/328_systematic_script_and_test_corpus_efficiency/issues.jsonl` (cited entry, verbatim);
  `agent-system/extensions/core/hooks/subagent-postflight.sh`,
  `agent-system/extensions/core/hooks/events-log-lifecycle.sh`,
  `agent-system/extensions/core/hooks/validate-meta-write.sh` (full reads);
  `agent-system/extensions/core/scripts/skill-base.sh` (`skill_create_postflight_marker` call
  sites, repo-wide grep); `.claude/docs/architecture/handoff-schema.md` (Postflight Boundary
  section); `agent-system/extensions/core/context/formats/return-metadata-file.md` (`in_progress`
  status documentation); `agent-system/extensions/core/context/patterns/
  dispatch-report-not-termination.md` (architectural philosophy cross-check); `specs/TODO.md` and
  `specs/state.json`/`specs/archive/state.json` entries for tasks 328, 378, 426, 428.
- No web search was needed; this is a self-contained repository-architecture question.
