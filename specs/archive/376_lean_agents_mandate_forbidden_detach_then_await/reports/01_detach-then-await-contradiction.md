# Research Report: Task #376

**Task**: 376 - Lean implementation agents mandate the detach-then-await-notification path core forbids, stranding dispatches mid-phase
**Started**: 2026-10-17T06:47:06Z
**Completed**: 2026-10-17
**Effort**: medium
**Dependencies**: 393 (completed; `propagate_modified_files_constraint_to_silent_agents` touched `lean/agents/*implementation-agent.md` but not the wait-discipline sites)
**Sources/Inputs**: - Codebase (agent-system/extensions/{core,lean}), git history of the source store, a live `lint-agent-contracts.sh` run, prior task 405's own report/plan artifacts
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The contradiction is real, confirmed, and already fully diagnosed by a prior task (405,
  completed 2026-10-14): `lean/agents/lean-implementation-agent.md` and
  `lean-implementation-hard-agent.md` literally instruct `Bash(run_in_background: true)` followed
  by "wait for the harness's completion notification," the exact shape
  `general-implementation-agent.md` forbids. Task 405 built a lint (Check K) to detect this
  antipattern everywhere, then deliberately carved these two files out as a **time-boxed**
  exclusion "until 376 lands" — this task is that landing, not a fresh discovery.
- **The root-cause site is `extensions/lean/context/project/lean4/operations/long-builds.md`, not
  the two agent files in isolation.** That file's own "Obligation 1: detach" and "Completion
  discipline" sections mandate the forbidden harness-notification wait as the canonical shape
  ("every contract site in this extension copies this invocation shape verbatim"), while its own
  later "Blocking on a detached build" section points at `bounded-build-waiter.md`'s foreground
  idiom instead. The file contradicts itself; the two agent files are faithfully propagating one
  half of that self-contradiction.
- `lake-build-guard.sh` needs **no change**. Its `build` subcommand already blocks synchronously
  in the invoking shell and already documents the exact `kill -0 "$holder_pid"` liveness idiom
  `bounded-build-waiter.md` canonicalizes. The defect is entirely in how the agent-contract prose
  tells the agent to *wrap* that already-blocking call (harness-level `run_in_background: true`
  vs. shell-level `&`/`kill -0`/`timeout`), not in the guard script itself.
- A source-store git-history check proves a redeploy alone would **not** have prevented the
  measured incident: the contradictory wording was already present in the last source-store
  commit before the incident date, so a stale-vs-fresh deployed tree makes no difference here.
- Exactly two files (`lean-implementation-agent.md`, `lean-implementation-hard-agent.md`) carry
  the literal forbidden phrase today; `lean-research-agent.md` and `lean-research-hard-agent.md`
  (also in this task's declared `file_scope`) mention `run_in_background: true` for `lake build`
  verification but do **not** pair it with an explicit wait-for-notification instruction, and
  `lint-agent-contracts.sh` Check K already confirms them clean on their own merits (not via the
  exclusion list).
- The fix is mechanically demonstrable: once the two files' shape is migrated, remove them from
  `lint-agent-contracts.sh`'s `CHECK_K_EXCLUDED_RELATIVE_PATHS` (the file's own documented
  "REMOVAL CONDITION") and re-run the lint — Check K moving from silent-skip to an evaluated PASS
  on these two files, with 0 FAILs overall, is the acceptance criterion's required "real artifact"
  demonstration.

## Context & Scope

This is a `meta` task whose edit target is the source store (`agent-system/extensions/**`), never
a deployed `.claude/**` tree, per the task's own stated constraint. The research question is
narrowly scoped (confirm the contradiction, locate every site, determine the correct fix shape,
and settle five explicitly named sub-questions) rather than open-ended: the task description
already states the likely-correct fix direction (keep detachment, replace only the wait step) and
asks the research/plan phases to verify rather than re-litigate it. This report verifies that
direction against the actual file contents, extends it with the root-cause location inside
`long-builds.md`, and answers each "ALSO SETTLE" question with direct evidence rather than
inference.

The cross-extension duplication audit, and the question of whether the wait-discipline mandate
should be inherited from one shared place instead of restated per-extension, are explicitly out of
scope for this task per its own `## SCOPE DECISION`; this report records the grep evidence a
successor task needs (see Findings) without proposing to fix those other files here.

## Findings

### Codebase Patterns

**1. Prior task 405 already fully diagnosed this and deliberately deferred the fix here.**
`specs/405_detect_stranded_dispatch_from_stale_heartbeat/reports/01_detect-stranded-dispatch.md`
(dated 2026-10-14, five days after the measured incident) names this task by number, quotes its
`## EXPLICIT NON-GOALS` section as binding, and states explicitly: *"Treat the six
`lean-implementation-agent.md` / `lean-implementation-hard-agent.md` occurrences of the literal
forbidden phrase ... as already-known, already-tracked by task 376 rather than evidence this task
must independently re-fix."* Its own plan phase 7 then added `lint-agent-contracts.sh` Check K (a
mechanical absence-of-contradiction scan) and, in the same commit, added a **curated exclusion**
for exactly these two files with an explicit removal condition:

> "RECORDED 2026-10-14: only these two files carry the literal phrase outside the canonical
> prohibitive prose homes. REMOVAL CONDITION: once either file's background-then-wait shape is
> migrated to the foreground bounded-wait idiom (or the file is otherwise removed from the
> dispatchable-agent set), drop its entry here — a stale exclusion remaining after its own
> migration would mask a reintroduced violation behind a silent skip instead of a FAIL."
> (`lint-agent-contracts.sh:936-946`)

This means the plan phase does not need to re-derive whether this is a real defect — it is
settled, on the record, by an independent prior task — only to execute the fix and discharge the
removal condition.

**2. The textual contradiction is confirmed verbatim, at the current line numbers (unchanged by
task 393's intervening edit to the same file).**

- `extensions/core/agents/general-implementation-agent.md:188` — "**MUST NOT** use
  `Bash(run_in_background: true)` or arm a `Monitor` to watch a local verification, gate, build,
  or test process from within this dispatched subagent."
- `extensions/core/agents/general-implementation-agent.md:218` — "**MUST NOT** end the turn on an
  unresolved local background wait. Detaching a local command and then stopping to wait for a
  harness completion notification hands the dispatch back unfinished with no handoff and no
  `.return-meta.json`."
- `extensions/lean/agents/lean-implementation-agent.md:337-340` — "Run this via
  `Bash(run_in_background: true)` ... and wait for the harness's completion notification before
  recording the result." This is the one site in the non-hard file that still carries the literal
  phrase today; it is word-wrapped across two physical lines
  (`...completion\n   notification...`), which is exactly why `lint-agent-contracts.sh`'s own
  Check K joins a multi-line window before matching (`_check_k_file_has_violation()`,
  lines 978-983) rather than grepping single lines.
- `extensions/lean/agents/lean-implementation-hard-agent.md:244` and `:454` carry the identical
  phrase, each on a single un-wrapped line.
- Four more sites in the non-hard file (`:30`, `:70`, `:741`, `:768-771`) and several more in the
  hard file (`:47`, `:69`, `:452-460`, `:782`, `:806`) instruct `Bash(run_in_background: true)`
  for the build-guard invocation without repeating the explicit wait-for-notification sentence at
  that exact spot — but `run_in_background: true` **is** the forbidden mechanism regardless of
  whether that one sentence is repeated beside it each time, so every one of these sites still
  needs to change, not only the two sites carrying the literal phrase.
- `lean-implementation-agent.md`'s MUST NOT item 13 (`:768-771`) forbids running `lake build` "as
  a plain foreground Bash call" and names `Bash(run_in_background: true)` as the only sanctioned
  alternative — so the agent is simultaneously told the one path is unresumable and the other
  path is prohibited, with no third option stated in its own text.

**3. The actual root cause is `extensions/lean/context/project/lean4/operations/long-builds.md`,
which self-contradicts, not merely "the agent files drifting independently."** This file states,
under "## The canonical invocation": *"Every contract site in this extension copies this
invocation shape verbatim, run under `Bash(run_in_background: true)`."* Its "## Obligation 1:
detach" section describes that call as one that "re-invokes the agent with a completion
notification when the underlying process exits," and its "## Completion discipline" section states
flatly: *"The dispatch is not complete, and final metadata must not be written, until the
harness's own completion notification for that background job has arrived."* All three of these
sections prescribe the exact forbidden shape as the canonical one.

The same file's own later "## Blocking on a detached build" section says the opposite: *"When a
dispatch must block on a detached build within the same turn, rather than merely observe it, the
sanctioned bounded, PID-liveness, one-waiter-per-log idiom is defined once, canonically, in core's
`context/patterns/bounded-build-waiter.md`. Consult that file instead of improvising a poll loop or
ending the turn."* This is the foreground, single-Bash-call idiom general-implementation-agent.md
requires. The two agent files are not independently inventing the forbidden instruction; they are
each faithfully copying one half of an already-self-contradictory root document. **Any fix that
edits only the two agent files and leaves `long-builds.md`'s "Obligation 1" / "Completion
discipline" prose unchanged will leave the actual root cause in place** — a future edit to either
agent file, or a new agent reading `long-builds.md` directly ("always load before running any
build," per both agents' own Context References section), would re-derive the forbidden shape from
the root document even after the two propagated copies are fixed.

**4. `lake-build-guard.sh` already supports the correct idiom; it requires no change.** The
guard's `build` subcommand runs synchronously in the invoking shell — it is not itself detaching
anything. Its own header already documents the exact liveness idiom
(`scripts/lake-build-guard.sh:112-138`): *"WAITING ON AN IN-FLIGHT GUARDED BUILD: read `holder_pid`
from the result record ... `while kill -0 "$holder_pid" 2>/dev/null; do sleep 1; done`."* This is
`bounded-build-waiter.md`'s Rule 2 idiom, already present and already correct in the guard script
itself. The "ALSO SETTLE" question of whether the guard should expose a "blocking foreground
mode, so the correct idiom is the path of least resistance" is answered: it already is the path of
least resistance at the script layer — a plain `bash .claude/scripts/lake-build-guard.sh build
--timeout 1800 -- build` call already blocks until the build finishes. The forbidden detachment is
introduced one layer up, by the agent-contract prose wrapping that already-blocking call in
`Bash(run_in_background: true)` instead of leaving it as a plain foreground Bash tool call (or
wrapping it in the shell-level `&`/`kill -0`/outer-`timeout` idiom only when the expected duration
plausibly exceeds the Bash tool's own ceiling, per `bounded-build-waiter.md`'s stated preference
order).

**5. `lean-research-agent.md` and `lean-research-hard-agent.md` (both in this task's declared
`file_scope`) are not carrying the contradiction.** A direct check (both single-line and a
multi-line-aware scan for the word-wrapped case) found the literal "completion notification"
phrase in exactly three files system-wide: `general-implementation-agent.md` (the prohibition's
own canonical home — a MUST NOT sentence, not an instruction), `lean-implementation-agent.md`, and
`lean-implementation-hard-agent.md`. The two lean research agents mention
`Bash(run_in_background: true)` only in the context of describing their Bash tool's scope ("Run
`lake build` for verification (detached via `Bash(run_in_background: true)`...)") without an
accompanying wait-for-notification instruction, and a live `lint-agent-contracts.sh` run confirms
Check K evaluates both and PASSes them on their own merits (they are not on the curated exclusion
list at all). They therefore satisfy this task's `## ACCEPTANCE` criterion as written today, but
carry the same imprecise `run_in_background: true` phrasing that produced the defect in the
implementation agents — a latent risk if a future edit to either research agent adds an explicit
wait step by analogy with the (currently broken) implementation-agent text. Recommended, not
required: align their wording with whatever corrected phrasing lands in the implementation agents,
for consistency, while leaving their actual scope decision (verification-only Bash access) alone.

**6. A git-history check answers the "stale deployed tree" question directly, without needing
access to the deployed tree's historical state.** The incident's own repository (BimodalLogic) has
`.claude/` gitignored with no snapshot, so the exact deployed-tree content at the incident
timestamp (2026-10-09) cannot be recovered. But the **source store's own history** answers the more
important half of the question: the last source-store commit before the incident date
(`4c90b876e`, 2026-10-08) already contains the identical contradictory wording at the same line
numbers in both `general-implementation-agent.md` and `lean-implementation-agent.md` as the
current tree. A redeploy that brought a stale deployed tree current with the source store, at the
time of the incident, would therefore have changed nothing — **the bug was already in the
authoritative source, not only in a lagging deployed copy.** This forecloses "a redeploy alone
would have prevented this" as an explanation and confirms the task's own instruction (fix the
source store, then redeploy) is the only path that actually closes the gap.

**7. Cross-extension grep evidence for the successor task (recorded, not acted on).** Re-running
the exact `BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS` set `lint-agent-contracts.sh`'s Check H already
maintains, and the literal-phrase scan above, gives a materially calmer picture than the task
description's own precautionary framing ("~18 other `*-implementation-agent.md` files ... may each
carry a divergent copy of the wait rule") suggested:

- 12 non-hard implementation-agent files reference `run_in_background`/`bounded-build-waiter`:
  `books`, `cslib`, `cslib` (pr-review), `email`, `latex`, `nix`, `nvim` (neovim), `python`,
  `rust`, `typst`, `web`, `z3`.
- Plus 2 hard-variant files: `books-implementation-hard-agent.md`,
  `cslib-implementation-hard-agent.md`.
- All 14 are **already** in Check H's curated in-scope list (the list requiring presence of the
  correct canonical bullet pair), and a live lint run confirms **all 14 currently PASS both Check H
  (bullet present) and Check K (no contradicting instruction)** — they are not drifting copies of
  a broken rule; they already carry the generic, correct bullet pair `bounded-build-waiter.md`
  generates. The duplication that exists is 14 **correct** literal copies of one canonical bullet
  pair (by deliberate design — see `bounded-build-waiter.md`'s own "Generated-Copy Source, Not an
  `@`-Import" rationale: `@`-references do not auto-resolve into a spawned subagent's context, so
  a literal copy is required in each file regardless of a shared canonical source existing).
- The genuine open question for the successor task is therefore the one the current task's
  description already names precisely: *whether* 14 independently-maintained literal copies of one
  correct rule (verified in sync today by `lint-agent-contracts.sh` Check H, which would catch
  future drift) is the right long-term shape, or whether a different propagation mechanism should
  replace it — not "these files are broken and need fixing." The successor task should carry this
  reframing forward rather than the more alarming "~18 files may each carry a divergent copy"
  framing, which this research found unsupported by direct measurement.

### External Resources

Not applicable. This is an internal agent-contract consistency question with no external
library, API, or published-practice dependency.

## Decisions

- Treat task 405's existing diagnosis and Check K's documented "REMOVAL CONDITION" as the binding
  acceptance mechanism for this task's fix, rather than re-deriving a fresh detection method: once
  the two agent files' wait-shape is migrated, remove them from
  `lint-agent-contracts.sh`'s `CHECK_K_EXCLUDED_RELATIVE_PATHS` and a passing lint run (0 FAILs,
  both files evaluated and PASSing on their own merits rather than silently skipped) is the
  acceptance criterion's required "demonstrated against a real artifact ... a lint run."
- Treat `extensions/lean/context/project/lean4/operations/long-builds.md` as the primary fix site
  (not merely a "possibly" touched file per the task's own tentative `## FILE SCOPE` wording) — its
  "Obligation 1: detach" and "Completion discipline" sections are the literal source of the
  forbidden shape that both agent files faithfully copy, and its "Blocking on a detached build"
  section already states the corrected direction. The fix should resolve this file's own internal
  contradiction first, then bring the two agent files' prose into agreement with the corrected
  version, so a future reader of `long-builds.md` alone cannot re-derive the forbidden shape.
- Treat `lake-build-guard.sh` as out of scope for any code change — it already supports and
  documents the correct liveness idiom; only the Markdown prose describing how to invoke it needs
  to change.
- Treat the cross-extension duplication audit's actual finding (14 files already correct, verified
  by an existing passing lint check) as the evidence record a successor task inherits, rather than
  the task description's own more alarming precautionary framing — the successor's real question is
  about propagation architecture (one canonical source vs. 14 literal copies), not about an unfixed
  defect in those 14 files.
- Treat `lean-research-agent.md` and `lean-research-hard-agent.md` as confirmed clean of the
  acceptance-blocking defect today (Check K PASSes them on merit), with a non-blocking wording
  consistency recommendation only.

## Recommendations

1. **Fix `long-builds.md` first.** Rewrite "## Obligation 1: detach", "## Completion discipline",
   and "## The canonical invocation" so that "detach" means the shell-level `cmd & pid=$!`
   backgrounding `bounded-build-waiter.md`'s canonical idiom uses (never the harness's
   `Bash(run_in_background: true)` tool parameter), and so the canonical invocation example shown
   is the full idiom (captured `pid`, `kill -0` loop, outer `timeout`) wrapping the guard call,
   not a bare guard command annotated "run under `Bash(run_in_background: true)`." Reconcile
   "Completion discipline" with the existing "Blocking on a detached build" section so the file no
   longer states both "wait for the async notification before finishing" and "use the bounded
   foreground idiom instead of ending the turn" as if they were compatible.
2. **Propagate the corrected wording to the two agent files' seven-plus sites** named in Finding 2
   (`lean-implementation-agent.md:30,70,337-341,741-744,768-771`;
   `lean-implementation-hard-agent.md:47,69,244,452-460,782,806`), replacing every
   `Bash(run_in_background: true)` build-guard invocation with the bounded-waiter idiom and
   removing the literal "wait for the harness's completion notification" sentence (or keeping it
   only inside a MUST-NOT-style prohibition, mirroring how `general-implementation-agent.md` itself
   uses the phrase safely).
3. **Make the `lake build`-specific scope explicit**, per the task's own "ALSO SETTLE" note that
   the measured incident's gate was a probe-sweep script, not a `lake build`: add an explicit
   cross-reference from `lean-implementation-agent.md` to
   `general-implementation-agent.md`'s "Local Long-Running Command Discipline" subsection for any
   local gate/test/probe script that is *not* a `lake`-family invocation through
   `lake-build-guard.sh`, so a future dispatch cannot generalize the lake-specific detach-and-guard
   mandate to an unrelated script the way the measured incident's agent did.
4. **Discharge Check K's removal condition** (`lint-agent-contracts.sh:943-949`): once the above
   lands, delete both lean paths from `CHECK_K_EXCLUDED_RELATIVE_PATHS` and re-run
   `bash scripts/lint/lint-agent-contracts.sh` to confirm both files now PASS Check K on their own
   merits. Leave Check H's separate exclusion list (`bounded-build-waiter.md`'s Classification
   Rule) as-is — it concerns presence of the *generic* bullet pair, which these two files are not
   expected to carry verbatim given their domain-specific build-guard prose; only Check K's
   absence-of-contradiction exclusion is time-boxed and needs removal.
5. **Do not touch `lake-build-guard.sh`.** No change is needed there; it already supports the
   correct idiom.
6. **Create the named successor task** for the cross-extension duplication/inheritance question at
   this task's wrap-up, carrying forward Finding 7's grep evidence and its corrected framing (14
   files already correct and lint-verified; the open question is propagation architecture, not an
   unfixed defect) rather than re-deriving the audit from scratch.
7. **Redeploy after the source-store edit lands**, and note in the summary (per Finding 6) that the
   redeploy is necessary regardless of deployed-tree staleness, since the defect was already present
   in the source store itself, not only in a lagging deployed copy.
8. Optionally, align `lean-research-agent.md` / `lean-research-hard-agent.md`'s
   `run_in_background: true` wording with whatever corrected phrasing lands in the implementation
   agents (Finding 5) — non-blocking, since both already pass Check K today.

## Context Extension Recommendations

- **Topic**: None identified. The relevant context (`long-builds.md`, `bounded-build-waiter.md`,
  `general-implementation-agent.md`, `lint-agent-contracts.sh`) is already well-documented and
  internally cross-referenced; the gap found here is a wording defect inside existing
  documentation, not a missing documentation topic.

## Appendix

### Search queries / commands used

- `grep -n "run_in_background\|bounded-build-waiter\|completion notification\|detach" agents/lean-implementation-agent.md` (and the hard/research variants)
- `find . -path "*/agents/*.md" | xargs grep -l "completion notification"` and a `perl -0777` multi-line-aware variant to catch the word-wrapped occurrence
- `git log -1 --before="2026-10-10" --format=%H -- <file>` plus `git show <sha>:<file>` to establish the source-store wording predates the incident date
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` (live baseline run: 344 passed, 13 warnings, 0 failed; confirmed Check K silently skips the two lean implementation-agent files via its curated exclusion, and PASSes the two lean research-agent files on merit)
- Read of `specs/405_detect_stranded_dispatch_from_stale_heartbeat/reports/01_detect-stranded-dispatch.md` and its plan/summary for the prior diagnosis and the Check K exclusion's documented removal condition

### References

- `agent-system/extensions/core/agents/general-implementation-agent.md:160-237`
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` (full file; Classification Rule, Check K anchor block, "Item 4 Ruling")
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh:649-718` (Check H), `:912-1020` (Check K)
- `agent-system/extensions/core/scripts/lake-build-guard.sh:1-138` (header/documentation of the already-correct liveness idiom)
- `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` (full file)
- `agent-system/extensions/lean/agents/lean-implementation-agent.md:25-90,320-351,725-779`
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md:236-270,448-462,780-810`
- `agent-system/extensions/lean/agents/lean-research-agent.md:58-65,185-196`
- `specs/405_detect_stranded_dispatch_from_stale_heartbeat/reports/01_detect-stranded-dispatch.md`
- `specs/405_detect_stranded_dispatch_from_stale_heartbeat/plans/01_stranded-dispatch-detection.md:109-110,608-609,642`
