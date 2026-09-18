# Research Report: Task #212

**Task**: 212 - Postflight honesty: gate research on a report file and derive the handoff-writer predicate from the dispatch row
**Started**: 2026-09-18T17:18:38Z
**Completed**: 2026-09-18T18:10:00Z
**Effort**: research
**Dependencies**: Task 194, Task 213
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts, agents, skills, context, docs); this agent's own live system prompt (direct observation)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

This task absorbed a second defect (former task 195, dispatch-derived handoff-writer predicate)
verbatim into its own dispatch text. Both are researched below; the closing section shows they
share one root fix.

## Executive Summary

- **Root cause of the missing-report defect is CONFIRMED, not merely "possible."** The Claude
  Code harness appends a generic "Notes:" block to every Agent-tool subagent's system prompt,
  independent of `subagent_type` and independent of anything in this repo's source store. That
  block includes, verbatim, in *this very dispatch's own system prompt*: "Do NOT Write
  report/summary/findings/analysis .md files. Return findings directly as your final assistant
  message — the parent agent reads your text output, not files you create." This directly
  contradicts `general-research-agent.md`'s Stage 6 ("Create Research Report") and its own MUST
  DO #5 ("Create report file before writing completed/partial status"). It is not present
  anywhere in `agent-system/extensions/core/agents/general-research-agent.md`, the deployed
  `.claude/agents/general-research-agent.md`, `.claude/settings.json`, or the dispatch prompt —
  exactly the set of places the original incident's investigator checked and came up empty. This
  reframes research-128's and research-133's stated rationale ("this session's operating notes",
  "this session's no-report-file instruction") from *hallucinated justification* to *a real,
  external, harness-injected instruction that a subagent must be told, explicitly and
  repeatedly, to override*.
- **Current detection is a genuine gap, but not total silence.** `orchestrate-cycle-postflight.sh`
  already resolves `verdict=failed` (or `defer` if transport-exempt) when a dispatch produces
  neither a handoff nor a recoverable `.return-meta.json` — the task's status is never falsely
  advanced. What is missing: (1) no durable, named defect is ever recorded for this specific
  failure mode when the agent is not on the two-name `is_contractual_handoff_writer()`
  allowlist (i.e., for every research/plan/base-mode-implement agent — 100% of non-hard-mode
  dispatches), and (2) the agent's own message-borne findings, which *are* available to the
  orchestrator lead as the Agent tool's return value at Move 3, are never captured or persisted
  anywhere — they are lost the moment the turn ends.
- **The two absorbed defects share one root fix.** Task 195's favored option (b) — deriving
  writer-expectation from "reached postflight at all" rather than from a hardcoded agent-name
  allowlist — is structurally sound *today* (Move 3 loops `dispatch[]` rows only;
  `aux_dispatch[]` rows never reach postflight and never receive a `handoff_path`; see Findings
  below). Implementing option (b) as "record a defect on any double-miss (absent/stale handoff
  *and* failed `.return-meta.json` recovery), regardless of agent name" simultaneously closes
  task 212's own detection gap for base-mode research dispatches, because
  `general-research-agent` is exactly the kind of non-allowlisted agent whose double-miss
  currently produces a WARN and nothing else.
- **Recommended approach**: (1) harden `general-research-agent.md` (and sibling research/plan/
  implementation agent contracts) with an explicit, unambiguous override statement naming the
  harness's own conflicting guidance and stating that it does not apply to the report-file
  requirement; (2) generalize/rename the D1 predicate in `orchestrate-cycle-postflight.sh` so a
  genuine double-miss always records a defect, independent of `agent_name`; (3) add narrow,
  explicitly-justified logic at Move 3 (SKILL.md) — not inside the read-only postflight script —
  that persists the dispatched agent's own returned text into the report path (tagged
  "recovered from agent's message") when this double-miss fires for a research dispatch, then
  marks the task `[PARTIAL]` or lets it re-dispatch next cycle, never advancing to `researched`
  on the strength of a message alone; (4) add fixture coverage for both the postflight
  double-miss branch and (conceptually) the message-recovery path.

## Context & Scope

Researched: (a) what `skill-orchestrate`'s postflight does today when a research dispatch
returns without a report/`.return-meta.json`; (b)/(c)/(d) design considerations for hardening
the gate and the agent contracts, and reproduction; and the absorbed former-task-195 material on
`is_contractual_handoff_writer()`. This is a research-only dispatch — no source-store files were
edited. Constraint honored throughout: SOURCE STORE IS THE EDIT TARGET
(`agent-system/extensions/core/`, never `.claude/**`) for any future implementation.

## Findings

### Codebase Patterns

**Postflight's current handling of a missing report (WORK item a).**
`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` is the single shared
per-task postflight body (both single-task and multi-task engines). Relevant trace for a
research dispatch that writes neither `.orchestrator-handoff.json` nor `.return-meta.json`
(the exact incident shape — findings sent only via message):

1. `handoff_file` absent -> `handoff_stale` stays false, the handoff-present branch is skipped.
2. `orchestrate-recover-outcome.sh <task_dir> <window_start_ts> ...` is invoked (WORK (b),
   line ~499). With `.return-meta.json` absent, it emits
   `{"recovered": false, "status": "unknown", "reason": "META_MISSING", ...}` and exits 1.
3. Back in postflight, `recovered=false` -> falls into the "WORK (d): writer-contract-aware
   recording for an ABSENT handoff" branch (lines 550-654). Because `is_contractual_handoff_writer
   general-research-agent` returns 1 (false — only `cslib-implementation-hard-agent` and
   `lean-implementation-hard-agent` return 0), the script takes the `else` arm (line 573-575):
   emits **only** a `WARN` line to stderr — `"agent name '${agent_name}' is not on the
   contractual handoff-writer allowlist — treated as a non-writer, no defect recorded for the
   absent handoff."` — and calls `system-defect-record.sh` **zero times**.
4. `have_outcome` stays `false`, so the entire `case "$dispatch_status" in ...` status-transition
   block (line 668) is skipped — the task's status in `state.json` is **not** advanced to
   `researched`, and is **not** silently accepted as complete.
5. Verdict resolution (line 850-879): `offschema_dispatch_status` is false (never entered that
   branch), `have_outcome` is false, and — assuming this was an ordinary agent turn that
   returned text rather than a transport/API crash — `transport_error=false`, so
   `infra_exempt_cycle` is also false. The final `else` fires: **`verdict="failed"`**, `halt`
   stays false (off-schema-only signal).
6. In `SKILL.md`'s Move 3 loop, `verdict="failed"` with `halt != "true"` appends the task to
   `failed_tasks` in the multi-state file (or the single-task equivalent). The task remains
   in-flight; a later cycle (within the same run's budget, or a future `/orchestrate` call) will
   re-dispatch the research phase.

**Conclusion for (a): the status-integrity half of the gate already exists** — a task can never
be marked `researched` on the strength of a message-only return, and the failure is charged
against the run's verdict/cycle bookkeeping. **The two real gaps are**: no durable, attributed
defect record for this specific failure shape from a non-allowlisted (i.e., ordinary base-mode)
agent, and — more importantly per the task's own MUST NOT — **the agent's message-borne findings
are discarded**. Nothing downstream of the Agent tool call ever reads or persists that text:
`orchestrate-cycle-postflight.sh` is read-only over files by the Context Flatness Constraint
(its own header: "MUST NOT ... Read report, plan, summary, or handoff PROSE"), and `SKILL.md`'s
Move 3 pseudocode (lines 166-208) only extracts `dispatch_status`/`verdict`/`halt`/
`infra_exempt_cycle` from the postflight JSON — it never touches the Agent tool's own return
value at all.

**The `context/contracts/recovery.md` pointer in this task's own dispatch text is a dead lead.**
The dispatch's WORK (b) says to "mark [PARTIAL] per context/contracts/recovery.md," but that
file is entirely about git fix-forward/rollback discipline ("Green Means Fix Forward", the
three-rung Recovery Ladder for RED build states) and says nothing about missing research
deliverables or `[PARTIAL]` task-status semantics for a dispatch outcome. The correct reference
for `[PARTIAL]` task-status semantics is `context/standards/status-markers.md` (or the
`partial`/`handoff_path` contract described in `context-exhaustion-detection.md`), not
`recovery.md`. A future plan/implement phase should not cite `recovery.md` for this behavior.

**Root cause, confirmed by direct observation (not reproduction).** This research dispatch is
itself a `general-research-agent` invocation under `orchestrator_mode: true`, structurally
identical to the five failing dispatches in the original incident (`sess_1788267679_adbb09`).
Its own system prompt — assembled from `general-research-agent.md`'s content plus a harness-
appended, agent-type-independent "Notes:" section — contains, verbatim:

> "Do NOT Write report/summary/findings/analysis .md files. Return findings directly as your
> final assistant message — the parent agent reads your text output, not files you create.
> (Files written as input to another tool are fine; this note is about report files.)"

This sits in the same prompt as, and directly after, `general-research-agent.md`'s own Stage 6
("Create Research Report") and Critical Requirements MUST DO #5 ("Create report file before
writing completed/partial status"). Grepping both the source-store agent file
(`agent-system/extensions/core/agents/general-research-agent.md`) and the deployed copy
(`.claude/agents/general-research-agent.md`) for this text returns nothing — it is not something
this repo's deploy pipeline adds. It is also not present in `.claude/settings.json`,
`settings.local.json`, or `~/.claude/settings.json`. This matches exactly what the original
incident's investigator found (and did not find). The most economical explanation: this "Notes:"
block is boilerplate the Claude Code harness attaches to every Agent-tool subagent turn
(alongside other harness-generic notes about cwd reset, emoji policy, and colon-before-tool-call
style, none of which are project-specific either), most likely inherited from generic
"general-purpose"/coding-subagent guidance where discouraging incidental scratch-file writes in
favor of an inline answer is normally correct — but which is actively wrong for an agent whose
*sole deliverable* is a file. research-128's "per this session's operating notes, findings were
delivered directly to team-lead via SendMessage rather than as report artifacts" and
research-133's "per this session's no-report-file instruction" read as accurate paraphrases of
this real, external note — not fabrications. research-123 and research-130, given the identical
prompt structure, evidently resolved the conflict the other way (task-specific contract beats
generic harness note); nothing in the artifacts examined explains that split other than ordinary
model-to-model judgment variance on an underspecified priority conflict.

**Implication**: the fix cannot remove the harness's own boilerplate (out of scope — it is not
part of `agent-system/extensions/**`, and no evidence suggests it is configurable from this
repo). The fix must be defensive at the contract layer: `general-research-agent.md` (and by the
same reasoning, `planner-agent.md`, `general-implementation-agent.md`, and any other lifecycle
agent) needs an explicit statement naming and overriding this class of ambient guidance, not
just a positively-phrased MUST DO. A plain "MUST DO: create the report file" was evidently not
enough to win a probabilistic priority contest against a later, generic "do NOT write files"
instruction in the same prompt.

**The `is_contractual_handoff_writer()` predicate (absorbed former task 195).**
`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` lines 421-426:

```bash
is_contractual_handoff_writer() {
  case "$1" in
    cslib-implementation-hard-agent|lean-implementation-hard-agent) return 0 ;;
    *) return 1 ;;
  esac
}
```

This predicate is consulted **only** inside the double-miss branch (handoff absent AND
`.return-meta.json` recovery also declined) — it is never consulted when either channel
succeeds. Confirmed via `SKILL.md`:

- Move 2 (dispatch) supplies `handoff_path` in the Agent-tool context **only** for `dispatch[]`
  rows (line 138: `handoff_path: "${task_dir_abs}/.orchestrator-handoff.json"`); the
  `aux_dispatch[]` loop explicitly omits it (line 147: "NO `handoff_path` key at all: an aux
  dispatch never writes `.orchestrator-handoff.json`").
- Move 3 (postflight) loops **only** over `plan_json.dispatch[]` (line 166); the file's own MUST
  NOT (line 151) states "an `aux_dispatch[]` row never reaches Move 3."

So, **today**, every agent invocation that ever reaches `orchestrate-cycle-postflight.sh` was, by
construction, a `dispatch[]` row that was handed a `handoff_path` in its context. This is exactly
the structural support the dispatch names as favoring option (b) (deriving writer-expectation
from dispatch-row shape rather than a hardcoded agent-name list): the invariant already holds,
it is just not exploited by the current predicate, which instead hardcodes two agent names that
have drifted behind the real agent roster (the observed incident: `general-implementation-agent`
crashed with `Prompt is too long`, produced neither file, and the predicate silently excused it
with only a WARN — no `HANDOFF_STALE_OR_ABSENT` defect).

**The wrinkle, resolved.** Postflight's own `Usage` block (its header, lines 82-87) shows its
full CLI contract: `<task_number> --session SID --state-file F --phase P --task-dir DIR
--task-type TYPE --agent NAME [--plan-path PATH] [--cycle-count N] [--transport-error ...]
[--force-invoked ...] [--loop-guard-file PATH] [--dispatch-seq N] [--dispatch-start-ts N]
[--command-suffix SUFFIX] [--hard] [--dry-run]`. There is **no** `--handoff-expected` flag today,
and `handoff_file` is derived purely from `--task-dir` (line 300:
`handoff_file="${TASK_DIR}/.orchestrator-handoff.json"`). Of the dispatch's two named shapes:

- **"Reached postflight at all" as the predicate** — the simpler shape. Correct *today*, given
  the verified Move-2/Move-3 invariant above, but implicit: it silently depends on that
  invariant continuing to hold (nothing enforces "only `dispatch[]` rows ever call this script"
  except the two `SKILL.md` prose MUST NOTs, which are documentation, not code).
- **An explicit `--handoff-expected true|false` flag threaded from the dispatch row through
  Move 2's call site** — more plumbing (a new field in `orchestrate-cycle-plan.sh`'s emitted
  `dispatch[]` row shape, a new flag parsed here, a new usage-block line), but makes the
  distinction self-documenting in the postflight script's own interface rather than an
  invariant a future reader has to go verify against `SKILL.md` prose.

Given `--dry-run`, `--force-invoked`, and the two dispatch-identity flags are already optional
flags threaded exactly this way from the dispatch row, the plumbing cost of the explicit-flag
shape is low and consistent with the script's existing flag-passing idiom — this is a point in
its favor beyond what the dispatch already argued, worth weighing in the plan phase alongside
the "simpler, but implicit" case for the first shape.

**Directly relevant precedent already in the codebase**: `ARTIFACTS_MISSING_ON_SUCCESS` is
already an enumerated `--defect-class` value in `system-defect-record.sh`'s closed 14-value enum
and is documented in `context/patterns/system-defect-discrimination.md` as "not currently
computed anywhere" — an already-acknowledged detection hole for the *adjacent* case (a
`.return-meta.json` that exists and reports a success status but has a null/absent/empty
`artifacts` field). Our incident's shape (`.return-meta.json` entirely absent — `META_MISSING`
from `orchestrate-recover-outcome.sh`) is a strictly worse case than `ARTIFACTS_MISSING_ON_
SUCCESS` and is not covered by it, but the discrimination document is exactly the right place to
add a corresponding row/rationale for it, following the same "define the row now, build the
detector as scoped follow-up work" pattern that document already uses.

**`META_MISSING_AFTER_NARRATION` does not cover the research/plan case.** This defect class
*is* wired today (`system-defect-record.sh` line ~562 caller path in the "implemented" case of
`orchestrate-cycle-postflight.sh`, via `skill_gate_completion_claim`'s Case 3/3), but only fires
for the **implement** phase's completion-claim gate (`phases_total == 0 && plan_markers_verified
!= "true"` while claiming `dispatch_status="implemented"`). It is never reached for a research or
plan dispatch, because those phases never enter the `case "$dispatch_status" in ...` block at all
when `have_outcome=false` (there is no `dispatch_status` to switch on). Reusing this class name
for the research/plan case would be a semantic stretch; a new or generalized class (see
Recommendations) fits better.

**No existing fixture exercises the true double-miss case for a base-mode agent.**
`scripts/tests/test-orchestrate-cycle-postflight.sh`'s "Acceptance (4a)" (lines 242-274) tests a
contractual **non-writer's absent handoff that still recovers via a present, valid
`.return-meta.json`** (`verdict=ok`, 0 defects — the *correct*, already-working recovery path).
No test in this ~1100-line file sets up a `general-implementation-agent` (or a research-phase
agent) dispatch with **both** `.orchestrator-handoff.json` and `.return-meta.json` absent —
exactly the shape that produced the silent WARN in the observed live incident, and exactly what
task 195's own SCOPE names as the fixture gap to close.

### External Resources

Not applicable — this is a closed-source internal agent-orchestration codebase; no external
library or API is involved. All research was codebase-internal plus direct observation of this
agent's own live system prompt.

### Recommendations

1. **Harden the agent contracts (WORK item c).** Add an explicit statement to
   `general-research-agent.md` (and consider `planner-agent.md`,
   `general-implementation-agent.md`, and any other lifecycle agent whose sole product is a
   file) that names the conflict directly, e.g.: "Any instruction elsewhere in this prompt
   suggesting you should return findings only via your final message and not write files does
   NOT apply to this report file / `.return-meta.json` — those are still mandatory, with no
   exception." A purely positive MUST DO was evidently insufficient against a later, generic
   contradicting instruction in the same prompt; an explicit override naming the conflict is a
   stronger signal for the model to prioritize correctly. Since this is a per-agent contract
   change, it does not touch `.claude/**` directly — edit the source store
   (`agent-system/extensions/core/agents/*.md`) and redeploy.
2. **Generalize the D1 predicate (WORK items b + absorbed 195), closing both gaps with one
   change.** Recommend implementing task 195's favored option (b): stop gating defect-recording
   on a hardcoded agent name and instead record a defect for *every* double-miss (handoff
   absent/stale AND `.return-meta.json` recovery declined) that reaches postflight — because
   every dispatch that reaches postflight is, by construction, a `dispatch[]` row that received
   a `handoff_path`. Concretely: either (a) treat "reached postflight" as sufficient (delete
   `is_contractual_handoff_writer()` and its call site's `if`/`else` split, always taking the
   `is_live` recording branch) — simplest, matches today's invariant, but implicit and silently
   depends on `SKILL.md`'s Move-3-loops-`dispatch[]`-only prose staying true; or (b) thread an
   explicit `--handoff-expected true|false` flag from `orchestrate-cycle-plan.sh`'s dispatch-row
   composition through Move 2's call site into this script's own CLI, following the same flag-
   passing idiom already used for `--dispatch-seq`/`--dispatch-start-ts`/`--force-invoked` — more
   plumbing, but makes the invariant an explicit, checkable contract rather than an implicit one.
   The plan phase should pick one and record why, per the dispatch's own instruction; the
   explicit-flag shape is more defensible long-term precisely because it does not depend on
   Move 3's dispatch[]-only loop remaining true forever, at a modest, already-precedented
   plumbing cost. This single change simultaneously satisfies task 212's own detection gap for
   `general-research-agent` (and every other non-allowlisted lifecycle agent) as a direct
   consequence — no separate detector is needed for the "research dispatch produced neither
   file" case once the predicate no longer excuses non-hard-mode agents.
3. **Message-recovery cannot live in `orchestrate-cycle-postflight.sh`.** That script is
   read-only over files by the Context Flatness Constraint and cannot see the Agent tool's raw
   text return at all — only the orchestrator lead (executing `SKILL.md` Move 3) receives that
   text. Persisting message-borne findings therefore requires a narrow, explicitly-justified
   addition at Move 3 itself, which today is constrained by the Postflight Boundary's MUST NOT
   #5 ("Write reports/plans/summaries — artifact creation is dispatched-skill work"). The plan
   phase must resolve this tension explicitly rather than silently overriding the boundary: one
   defensible framing is that *mechanically persisting a subagent's own already-produced text,
   tagged as a verbatim recovery, on the specific verdict=failed/double-miss path* is not
   "artifact creation" or "analysis" in the sense MUST NOT #5 is guarding against (which is about
   the lead doing original research/writing) — but this framing needs to be stated and justified
   in the plan/implementation phase, not assumed. A single narrow helper script (invoked by the
   lead with the recovered text and target report path) is likely the right mechanical shape,
   keeping the actual file-write logic (naming, "recovered from agent's message" framing,
   `.return-meta.json` synthesis) out of ad hoc inline `SKILL.md` bash.
4. **Reproduction (WORK item d).** A live, non-deterministic reproduction (dispatching several
   concurrent research subagents under bypass-permissions and hoping the same priority conflict
   resurfaces) is unlikely to be more convincing than what this research pass already
   established directly: the contradicting instruction is present, verbatim, in the current
   harness's own subagent system prompt, observed firsthand while writing this report under the
   identical `general-research-agent`/`orchestrator_mode: true` conditions as the original
   incident. Recommend treating this as sufficient confirmation and prioritizing the fixture-
   based acceptance test (WORK item's own ACCEPTANCE criterion: "a fixture simulates a research
   dispatch that returns findings by message with no report file") over a live-agent
   reproduction attempt, which would only add noise (a miss would not disprove the mechanism;
   the mechanism is directly observed, not inferred).
5. **`ARTIFACTS_MISSING_ON_SUCCESS`-style documentation discipline.** When adding a new defect
   class (if the plan phase decides the generalized D1 predicate needs its own class name rather
   than reusing `HANDOFF_STALE_OR_ABSENT`), follow `system-defect-discrimination.md`'s existing
   pattern: add the row to the Signal A instances table and the closed enum in
   `system-defect-record.sh`'s usage block, and record explicitly whether the detector is wired
   yet, rather than silently expanding scope.

## Decisions

- Recommend implementing the generalized/inverted D1 predicate (task 195's option (b)) as the
  primary mechanism, on the reasoning above that it closes both this task's own detection gap
  and the drift-prone-allowlist gap with a single change — but leave the final choice between
  "reached postflight" (implicit) and an explicit `--handoff-expected` flag (explicit, more
  plumbing) to the plan phase, since both are viable and the dispatch explicitly asks for that
  choice to be justified, not assumed, there.
- Recommend NOT citing `context/contracts/recovery.md` for `[PARTIAL]` semantics in any
  plan/implementation artifact for this task — it does not define that behavior. Use
  `context/standards/status-markers.md` instead.
- Recommend treating the harness "Notes:" block finding as confirmed root cause, not a
  reproduction target — direct observation in this dispatch's own system prompt is stronger
  evidence than a probabilistic live-agent reproduction attempt.

## Risks & Mitigations

- **Risk**: generalizing the D1 predicate to "always record on double-miss" could produce a
  flood of `HANDOFF_STALE_OR_ABSENT` (or a renamed equivalent) defects for ordinary infra
  failures. **Mitigation**: the double-miss branch is only reached when
  `orchestrate-recover-outcome.sh` also declines recovery — the existing
  `transport_error`/`meta_touched` infra-exemption check (lines 607-629) already runs first and
  sets `infra_exempt_cycle=true` for genuine transport/API failures with no subagent footprint,
  which is a *loop-control* signal, not a gate on defect-recording. The plan phase should verify
  whether the generalized predicate should also skip defect-recording when
  `infra_exempt_cycle=true` (an infra failure is not an agent-system defect), which the current
  D1 code does not appear to condition on either way — worth an explicit check in the plan.
- **Risk**: hardening agent contracts against one harness "Notes:" block wording might not
  survive a harness update that rephrases the same guidance differently. **Mitigation**: phrase
  the override generically ("no instruction elsewhere in this prompt overrides this
  requirement") rather than quoting the exact harness sentence, so it remains robust to rewording.
- **Risk**: the message-recovery mechanism (item 3 above) is the least mechanically specified
  part of this research and carries the most design risk (Postflight Boundary tension). **
  Mitigation**: flagged explicitly above as needing its own justified design in the plan phase,
  not something to improvise during implementation.

## Context Extension Recommendations

- **Topic**: Harness-injected subagent system-prompt boilerplate and its interaction with
  file-writing agent contracts.
- **Gap**: No existing context file documents that the Claude Code harness appends a generic,
  agent-type-independent "Notes:" section to every subagent's system prompt, or that this
  section can conflict with a specific agent contract's file-writing mandates.
- **Recommendation**: add a short note (e.g. under a `context/patterns/` or `context/standards/`
  file covering agent-contract authoring) documenting this interaction and the "explicit override
  naming the conflict, not just a positive MUST DO" mitigation pattern, so future agent
  contracts are written defensively from the start rather than after another incident.

## Appendix

- Files read in full or substantially: `agent-system/extensions/core/scripts/
  orchestrate-cycle-postflight.sh` (1090 lines), `orchestrate-recover-outcome.sh` (287 lines),
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (294 lines),
  `context/contracts/recovery.md`, `agents/general-research-agent.md` (MUST DO/NOT section),
  `system-defect-record.sh` (header/usage), `context/patterns/system-defect-discrimination.md`
  (predicate + Signal A table), `scripts/tests/test-orchestrate-cycle-postflight.sh` (acceptance
  3/4a fixtures), `docs/architecture/handoff-schema.md` (Postflight Boundary section).
- Direct observation: this dispatch's own assembled system prompt (harness "Notes:" section).
- Searches: grep for `AgentTool`/`Do not call the Agent` across `agent-system/` (no hits — not
  repo-controlled); grep for `--defect-class` enums across `scripts/*.sh`; grep for
  `is_contractual_handoff_writer`/`general-research-agent`/`general-implementation-agent` across
  the postflight test file.
