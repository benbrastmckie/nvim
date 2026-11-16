# Research Report: Task #634

**Task**: 634 - Mechanize /orchestrate conclusion-stage roadmap regenerate
**Started**: 2026-11-15T00:00:00Z
**Completed**: 2026-11-15T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/**: skills, scripts, context docs), measured run evidence named in the dispatch
**Artifacts**: - specs/634_mechanize_orchestrate_conclusion_roadmap_regenerate/reports/01_mechanize-conclusion-roadmap-regenerate.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Move 4 and Move 5 of `/orchestrate` are both **inline prose procedures the lead executes
  directly** — there is no wrapping "finalize" script for either. A single task number is the
  same four-move loop as a batch (no separate single-task code path), so whatever fix is chosen
  applies uniformly; no single-task-vs-batch branching exists to reconcile.
- The root cause matches the measured evidence precisely: `orchestrate-batch-results-template.md`
  already documents that its `### Conclusion` section is "rendered once per invocation, after
  this template's render completes, from Move 5" and is "ALWAYS placed last" — i.e. the design
  already intends the combined report to not exist, and therefore not be printable, until Move 5
  has run. `skills/skill-orchestrate/SKILL.md`'s Move 4 text currently instructs "Then: emit the
  consolidated output" immediately, before Move 5 has even started, which both contradicts the
  template's own stated intent and is the literal trigger for the observed failure (the lead
  printed a report that *looked* complete and stopped).
- Recommended ruling for GOAL (2): **adopt option (a) (reorder) as the primary fix** — move the
  verb "emit" (print-to-user) from Move 4 to the end of Move 5's own Step 6, so the single
  combined report (batch results + `### Conclusion` + `### Next Steps`) is never visible to the
  lead until Move 5 has actually executed. This is a documentation/sequencing correction, not a
  new mechanism, and directly closes the measured failure mode. A Stop-hook backstop (option
  (b)) is a secondary, defense-in-depth layer, not a replacement — see "Decision Points" below
  for why both are worth having and a proven precedent for (b) already exists in this codebase.
- Recommended ruling for GOAL (1): **extract Step 5 (roadmap regenerate) into one new script**
  (name recommendation: `orchestrate-roadmap-regenerate-step.sh`, or fold into
  `orchestrate-batch-gate.sh`'s sibling-script family), invoked unconditionally inside the
  existing Move 4 finalize sequence (same site as the already-reliable Batch Gate Stage, i.e.
  between numbered step 4 "reporting" and step 5 "consolidated output" of
  `orchestrate-state-machine.md`'s "Consolidated Output and Exit-Status Resolution" section) —
  **not** gated behind the lead continuing into Move 5 at all. `context/contracts/conclusion-
  stage.md`'s own Step 5 prose becomes a pointer to that script's one invocation site, never a
  second independent implementation — this satisfies the dispatch's "exactly one executable
  copy" requirement while keeping the authoritative contract prose in
  `conclusion-stage.md` (Step 5 numbering and surrounding Step 4/6/7 narrative stay there; only
  the executable body moves).
- Every script this mechanization needs already exists and is directly reusable:
  `scripts/lib/roadmap-preflight-lib.sh classify`, `scripts/roadmap-integration.sh --regenerate
  [--dry-run]` (idempotent; emits a stderr `OUTCOME:` line distinguishing "rewrote" from "left
  ... unchanged"), `scripts/events-append.sh`, `scripts/issue-record.sh`, and
  `scripts/git-commit-scoped.sh`. No new primitive is required — only a new thin orchestration
  script that sequences these exactly as `context/contracts/conclusion-stage.md`'s Step 5 already
  specifies.
- A concurrent sibling task (562, same cycle) declares `file_scope` overlap on
  `scripts/issue-record.sh`, `context/formats/issue-log.md`, `scripts/orchestrate-conclusion-
  aggregate.sh`, and `context/contracts/conclusion-stage.md` — all four of which this task's own
  plan will plausibly also touch. The implementation phase must re-read each before editing and
  commit only its own hunks (see territory contract in the dispatch file).

## Context & Scope

The dispatch asks for four things: (1) make the roadmap-regenerate step of `/orchestrate`'s Move
5 conclusion stage mechanically unskippable, on a script, in the Move 4 finalize path, for both
single-task and multi-task runs and on partial exits as well as `all_terminal`; (2) choose and
implement a mechanical backstop for the rest of Move 5 (channel classification, dispatch,
recording, next-batch suggestion); (3) add tests for the regenerate path (fires on
`all_terminal` and on a partial exit, single-task and batch; absent/unknown degrade never
writes; idempotent second run is a no-op); (4) update
`context/contracts/conclusion-stage.md`, `context/patterns/roadmap-update.md`'s caller table,
and `skills/skill-orchestrate/SKILL.md`'s Move 4/Move 5 text to state the resulting design.

This research covers the current architecture (where Move 4 and Move 5 live, what already
executes mechanically vs. only in prose, what the combined-report template already promises),
the available building-block scripts, and the two decision points GOAL (1) and (2) ask to be
ruled on, with a recommendation for each backed by what was found. It does not implement
anything — that is the plan/implement phases' job — and it does not re-derive the measured
evidence already stated verbatim in the dispatch (treated as ground truth here).

## Findings

### Codebase Patterns

**The Four-Move loop has no separate single-task path.** `skills/skill-orchestrate/SKILL.md`
states this explicitly at the top: "a single task number is a batch of size one through the SAME
four-move loop, no separate single-task code path." This resolves GOAL (1)'s "in single-task and
multi-task runs alike" requirement structurally — there is exactly one code path to fix, not two.

**Move 4's finalize sequence is nine inline steps, documented but not scripted as a unit.**
`docs/architecture/orchestrate-state-machine.md`'s "Consolidated Output and Exit-Status
Resolution" section numbers them 1–9: (1) read state fields, (2) compute
`forward_progress_violated`, (3) determine `exit_status` (`"implemented"`/`"partial"`), (4)
report deferred/observation categories, **Batch Gate Stage** (fires here, between steps 4 and
5), (5) emit the consolidated output per the template, (6) write
`.return-meta-multi-${session_id}.json`, (7) residue check, (8) release the session registry,
(9) remove `.dispatch/` for `completed_tasks` only. Steps 5/6 are exactly what the measured
evidence in the dispatch shows ran ("wrote ... at Move 4, printed its final report"); steps 7–9
are unconfirmed by that evidence but are cheap, non-blocking, best-effort operations unlikely to
be what the lead treated as "the end."

**The Batch Gate Stage is the existing precedent for "a script unconditionally wired into the
Move 4 sequence."** `scripts/orchestrate-batch-gate.sh`, invoked from `SKILL.md`'s Move 4 text
between `exit_status` resolution and consolidated-output emission, is a working example of
exactly the pattern GOAL (1) asks for: a script called inline, unconditionally (subject only to
its own no-op trigger condition — at least one implement dispatch occurred), writing its result
onto `mt_state_file` for the template to render. The dispatch's GOAL (1) requirement — "runs from
a script on the Move 4 finalize path ... so it cannot be skipped by a lead ending its turn
early" — is best satisfied by adding a sibling script at the **same site**, not by relying on
Move 5 continuing at all.

**`context/contracts/conclusion-stage.md`'s Step 5 is fully specified already, just not wired
into Move 4.** The full Step 5 text (preflight classify via `roadmap-preflight-lib.sh classify`;
on `classic`/`stage`, `roadmap-integration.sh --regenerate` then `git-commit-scoped.sh` on
`specs/ROADMAP.md` alone, then the advisory `lint/lint-roadmap-batch-proposals.sh`; on
`absent`/`unknown`, skip `--regenerate` entirely and degrade loudly via a named warning, an
`events-append.sh --event-type roadmap_regenerate_blocked` record + its own scoped commit, and a
best-effort per-task `issue-record.sh` loop) already exists verbatim in the contract. Nothing
about the *logic* needs to change — only *where it executes from*.

**The combined-report template already states the Move-5-must-run-first invariant.**
`context/patterns/orchestrate-batch-results-template.md`'s `### Conclusion` section documentation
(lines ~192–200) reads: "(Rendered once per invocation, after this template's render completes,
from Move 5 ... ALWAYS placed last, immediately before `### Next Steps`, since Move 5 runs only
after Move 4 has fully finalized, including this template's own render.)" This is the strongest
single piece of evidence in this research: the template's *own* contract already assumes the
whole document (batch results sections + `### Conclusion` + `### Next Steps`) is one single
emission that cannot happen before Move 5 completes. The measured failure is therefore best read
as `SKILL.md`'s Move 4 text telling the lead to "emit the consolidated output" at step 5 of the
numbered sequence (i.e., immediately, before Move 5 has even begun) — a wording defect that
contradicts the template it is supposed to be rendering, not a missing mechanism.

**A proven Stop-hook block precedent already exists in this codebase.**
`hooks/subagent-postflight.sh` is a `SubagentStop` hook that checks for a per-task
`.postflight-pending` marker (correlated to the stopping session via `cc_session_id`) and, when
present, returns `{"decision": "block", "reason": "..."}` to force continuation, with a
loop-guard cap (`MAX_CONTINUATIONS=3`) to avoid an infinite re-block loop and a
`stop_hook_active` escape to prevent hooks calling hooks. `/orchestrate` itself runs as
direct-execution in the top-level session (per the Skill-to-Agent Mapping table:
"skill-orchestrate | (direct execution)"), so the applicable hook event for a Move-5 backstop
would be the plain `Stop` event (already wired via `root-files/settings.json`'s `Stop` array,
alongside `post-command.sh`, `claude-stop-notify.sh`, `memory-nudge.sh`), not `SubagentStop` —
but the block/reason/loop-guard shape translates directly.

**Every script primitive Step 5 needs already exists and is independently tested.**
- `scripts/lib/roadmap-preflight-lib.sh classify <path>` → `absent|unknown|classic|stage`
  (four-way, run-as-script safe; sourcing `roadmap-integration.sh` directly is unsafe since it
  parses `$@` and calls bare `exit`).
- `scripts/roadmap-integration.sh --regenerate [--dry-run]` → idempotent; on a real write emits
  `OUTCOME: --regenerate rewrote ... (layout=..., ...)` to stderr, and on a no-op write emits
  `OUTCOME: --regenerate left ... unchanged (layout=..., no content change)` — this is the exact
  signal the "idempotent second run is a no-op" test (GOAL 3) should assert against, rather than
  diffing the file by hand.
- `scripts/events-append.sh --event-type roadmap_regenerate_blocked ...` and
  `scripts/issue-record.sh` for the `absent`/`unknown` degrade path.
- `scripts/git-commit-scoped.sh --session SID --message ... -- specs/ROADMAP.md` (or
  `specs/events.jsonl`) for the scoped commits.
- Existing test suites (`scripts/tests/test-orchestrate-batch-gate.sh`,
  `scripts/tests/test-orchestrate-conclusion-aggregate.sh`) establish the repo's standard test
  harness shape (`set -uo pipefail`, `common_test_resolve_subject`/`common_test_declare_subject`
  deploy-tree-first resolution, `mktemp -d` scratch root with a scratch `specs/state.json`, pass
  /fail/info counters, exit 0/1/2 convention) — the new script's test suite should follow this
  same shape rather than inventing a new one.

**The `conclusion_proposal_recorded` / `roadmap_regenerate_blocked` events and the
`issue-record.sh --class "roadmap regenerate blocked, no approval surface"` entry are already
wired to `specs/events.jsonl`/`issues.jsonl` by `conclusion-stage.md`'s existing Step 5 text** —
confirming the dispatch's own measured-evidence claim that none of these appeared for the
`sess_1794696615_44948d` run is consistent with Step 5 simply never having executed (not with a
defect inside Step 5's own logic).

### External Resources

Not applicable — this is a pure in-repo architectural/process task (`task_type: meta`); no
external documentation, library, or API is involved.

## Recommendations

1. **GOAL (1) ruling — extract-to-script, contract stays the authoritative prose.** Create one
   new script (e.g. `scripts/orchestrate-roadmap-regenerate-step.sh`) that performs exactly
   `conclusion-stage.md`'s current Step 5 body: classify → `--regenerate` + scoped commit +
   advisory lint on `classic`/`stage`, or the three-part loud degrade (named warning +
   `events-append.sh` + scoped commit + best-effort per-task `issue-record.sh` loop) on
   `absent`/`unknown`. Wire its **one** invocation into `SKILL.md`'s Move 4 text, at the same
   site as the Batch Gate Stage (between `exit_status` resolution/reporting and consolidated-
   output emission), unconditionally — i.e. it runs on every exit (`all_terminal`,
   `no_eligible_stuck`, `max_cycles`, any `partial`), never gated on whether the lead continues
   into Move 5 proper. Rewrite `conclusion-stage.md`'s own Step 5 text to state this: name the
   script, name its one call site (Move 4), and keep the step's numbering/surrounding narrative
   (so Step 4/6/7 context is undisturbed) but make clear the text is no longer independently
   executed from inside Move 5 — it is already done by the time Move 5 begins. This gives
   "exactly one executable copy" (the dispatch's own requirement) while leaving the contract
   file as the one place a future reader looks up *what* Step 5 does.
   - I checked whether this recommendation's own soundness survives contact with the live
     corpus, per the report-format.md Carried-Figure Discipline obligation for a recommendation
     that proposes changing a mechanical rule a corpus already relies on: `conclusion-stage.md`'s
     Step 5 is referenced from exactly three places repo-wide
     (`grep -rl "Step 5" agent-system/extensions/core/context agent-system/extensions/core/skills
     agent-system/extensions/core/docs` → `conclusion-stage.md` itself, `SKILL.md`'s Move 5
     one-line pointer, and `roadmap-update.md`'s Live Callers entry #1) — all three are named in
     GOAL (4) as files this task already updates, so none is left stale by the move.

2. **GOAL (2) ruling — adopt (a) reorder as primary; (b) Stop-hook block as a secondary,
   defense-in-depth backstop, not a replacement.** Reorder `SKILL.md`'s Move 4 text so step 5's
   "emit" verb (the actual print-to-user action) is deferred until Move 5's own Step 6 (Report)
   — i.e. Move 4 computes and stages the batch-results sections (everything through `### Batch
   Gate Stage Result`) but does not print them; Move 5 then runs its Steps 1–4/7, and Step 6
   appends `### Conclusion` and `### Next Steps` to the SAME staged document before the single
   combined report is ever shown to the user. This is a direct implementation of what
   `orchestrate-batch-results-template.md`'s own `### Conclusion` section documentation already
   asserts ("ALWAYS placed last ... since Move 5 runs only after Move 4 has fully finalized,
   including this template's own render") — it is a sequencing/wording correction aligning
   `SKILL.md` with a contract that already exists, not a new mechanism, and it removes the exact
   stopping condition the measured evidence names (treating Move 4's own output as the terminal
   report). Additionally, implement a lightweight `Stop`-hook backstop modeled directly on
   `hooks/subagent-postflight.sh`'s proven block/reason/loop-guard shape: on the main-session
   `Stop` event, check whether a session that wrote `.return-meta-multi-${session_id}.json` this
   turn has also written a "conclusion ran" marker for that same `session_id` (e.g. a small
   `specs/.orchestration/.conclusion-ran-${session_id}` marker, written as the very last action
   of Move 5's Step 6); if the multi-task meta file exists but the marker does not, block with a
   reason naming the missing stage, capped by the same kind of loop-guard counter to avoid an
   infinite re-block. This is strictly additive insurance for the case where (1)'s unconditional
   roadmap-regenerate script already protects the one most load-bearing Step 5 action, but the
   rest of Move 5 (channels a/b/c, Step 7) is still skipped for some other reason the reorder
   does not catch (e.g. the lead editing its own turn manually, a crash between Move 4 and Move
   5, or a future regression reintroducing an early-emit site). Both are cheap; neither
   supersedes GOAL (1)'s own unconditional script, which remains the sole load-bearing guarantee
   for roadmap regeneration specifically.

3. **GOAL (3) test coverage — four cases on the new script, reusing the existing harness shape**:
   (a) `all_terminal` exit with a `classic`/`stage` roadmap → `--regenerate` fires, commit lands,
   `OUTCOME: ... rewrote` observed; (b) a `partial` exit (e.g. synthesize a scratch
   `mt_state_file` with a non-empty `failed_tasks`) → same script call still fires identically
   (the script's own logic has no `exit_status` branch — it is invoked unconditionally
   regardless of which branch Move 4 took, so this case mainly proves the *call site*, not the
   script, is unconditional — likely best covered at the `SKILL.md`-level integration/review
   rather than inside the script's own unit suite); (c) `absent`/`unknown` classification →
   assert `--regenerate` is never invoked (no `OUTCOME:` line at all) and that the three-part
   degrade (warning text, `events.jsonl` entry, scoped commit) fires instead; (d) idempotent
   second run → run the script twice back-to-back with no intervening state change, assert the
   first run's `OUTCOME:` says `rewrote` (or is a no-op already) and the second says `left ...
   unchanged`. Single-task vs. batch is not a separate axis for this script (per the "no separate
   single-task code path" finding above) — a single-element `--tasks` list is a sufficient
   stand-in for both; no duplicate case is needed.

4. **GOAL (4) documentation updates** — update exactly the three named files: `conclusion-
   stage.md`'s Step 5 (per recommendation 1), `roadmap-update.md`'s Live Callers entry #1 (name
   the new script as the actual call site, keep the "non-interactive — loud degrade ... since
   this surface has no approver present" arm description, which is unchanged by this move), and
   `SKILL.md`'s Move 4/Move 5 text (name the new unconditional script call in Move 4; adjust the
   "emit consolidated output" wording per recommendation 2; add the Stop-hook backstop reference
   if implemented).

## Decisions

- Treated the dispatch's "MEASURED EVIDENCE" paragraph as ground truth and did not attempt to
  re-verify it mechanically (e.g. by re-running `/orchestrate 436, 626`) — it is cited verbatim
  in the dispatch from `specs/events.jsonl`/git log/`roadmap-integration.sh --regenerate
  --dry-run` output, and re-deriving it would not change this task's scope.
- Did not propose folding Step 5 fully into `orchestrate-batch-gate.sh` itself (as one more
  trigger-gated branch of that script) — `orchestrate-batch-gate.sh`'s own trigger condition
  ("at least one implement-phase dispatch occurred") is unrelated to and narrower than what
  roadmap regeneration should run on (every exit, implement dispatch or not — e.g. a research-
  only invocation that still completes a task should still regenerate the roadmap). A sibling
  script at the same call site, not a branch inside that script, keeps the two trigger
  conditions independent and correctly scoped.
- Left the exact marker filename/shape for the Stop-hook backstop (recommendation 2's `(b)`
  component) as a planning-phase decision rather than specifying byte-for-byte detail here — the
  precedent (`hooks/subagent-postflight.sh`) is unambiguous enough to scope the plan from, and
  over-specifying the marker shape in a research report would duplicate work the plan is meant
  to do.

## Risks & Mitigations

- **Risk**: moving the "emit" verb later in the sequence could be read as delaying useful
  feedback to an operator watching a live `/orchestrate` run. **Mitigation**: `/orchestrate` is
  explicitly `orchestrator_mode` — "no human is watching mid-run" per
  `orchestrate-state-machine.md`'s own language around `detected_defects` — so there is no
  interactive consumer whose feedback loop this reordering degrades; the only consumer of the
  combined report is whoever reads the final transcript, for whom one complete report beats two
  partial ones.
- **Risk**: the new unconditional roadmap-regenerate script, if miswired, could run on EVERY
  Move 4 exit including one that dispatched nothing (`no_eligible_stuck` with zero
  `task_numbers` touched). **Mitigation**: `roadmap-integration.sh --regenerate` is already
  idempotent and safe to call even with no state change (verified above via its `OUTCOME: ...
  left ... unchanged` branch) — an extra no-op call costs a classify + a no-op regenerate, not a
  correctness bug. The existing "no `#### Move 5` for an invocation that dispatched nothing"
  language in `orchestrate-state-machine.md` already anticipates a zero-dispatch Move 5 running
  and being a no-op in exactly this way.
- **Risk**: the sibling task 562's concurrent edits to `conclusion-stage.md`/
  `orchestrate-conclusion-aggregate.sh`/`issue-record.sh`/`issue-log.md` could collide with this
  task's edits to the same files during implementation. **Mitigation**: already flagged via
  `issue-record.sh` (recorded during this research dispatch) and covered by the dispatch's own
  territory contract (re-read immediately before editing, commit only this task's own hunks).

## Context Extension Recommendations

- **Topic**: "Move 4 finalize-sequence sibling scripts" (the `orchestrate-batch-gate.sh` /
  proposed-new-roadmap-regenerate-script pattern).
- **Gap**: `docs/architecture/orchestrate-state-machine.md`'s numbered 1–9 sequence documents
  *what* happens at each step but does not yet name a general pattern for "a script
  unconditionally wired into this sequence, independent of Move 5 continuing" — today only the
  Batch Gate Stage exists as a worked example, with no generalized naming.
  Context Extension Recommendations are an optional, non-mandatory section.
  Including it is informational for future readers once a second sibling script exists
  (the one recommendation 1 above proposes); it is not itself a blocking gap for this task.
- **Recommendation**: once this task's plan lands, consider a short addendum to
  `orchestrate-state-machine.md` naming both sibling scripts side by side as instances of one
  documented pattern, rather than leaving the second one to be discovered only via
  `conclusion-stage.md`'s own Step 5 text.

## Appendix

- Search queries / commands used: `grep -rln "return-meta-multi"`, `grep -n "Move 4\|Move 5"
  skills/skill-orchestrate/SKILL.md`, `grep -n "Conclusion Stage"
  context/standards/postflight-tool-restrictions.md`, `grep -n "finalize\|--regenerate\|roadmap-
  integration" scripts/orchestrate-cycle-plan.sh scripts/orchestrate-cycle-postflight.sh
  scripts/orchestrate-batch-gate.sh`, `grep -rln '"decision"\s*:\s*"block"' hooks/ scripts/`.
- Files read in full or substantial part: `context/contracts/conclusion-stage.md`,
  `context/patterns/roadmap-update.md`, `context/standards/postflight-tool-restrictions.md`
  (Conclusion Stage section), `docs/architecture/orchestrate-state-machine.md` (Consolidated
  Output / Move 5 sections), `context/patterns/orchestrate-batch-results-template.md` (Conclusion
  section), `skills/skill-orchestrate/SKILL.md` (Move 4/Move 5), `hooks/subagent-postflight.sh`,
  `hooks/post-command.sh`, `scripts/lib/roadmap-preflight-lib.sh` (header),
  `scripts/roadmap-integration.sh` (OUTCOME-line greps), `scripts/tests/test-orchestrate-batch-
  gate.sh` and `test-orchestrate-conclusion-aggregate.sh` (headers, for test-harness-shape
  reuse).
- `.claude-extensions.json` resolved `agent-system/extensions/core` as the `core` extension's
  `source_dir` — all paths above are relative to that directory, the correct edit target per
  `rules/source-store-deploy-boundary.md`.
