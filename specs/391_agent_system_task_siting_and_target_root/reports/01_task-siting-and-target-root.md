# Research Report: Task 391

- **Task**: 391 - Agent system task siting and target root
- **Started**: 2026-11-11T17:00:00Z
- **Completed**: 2026-11-11T17:45:00Z
- **Effort**: ~3 hours (research)
- **Dependencies**: 372, 373 (ordering only — both already declare `conclusion-stage.md` in their
  own file_scope; this task's substance does not wait on their conclusions)
- **Sources/Inputs**: codebase reading (`context/contracts/conclusion-stage.md`,
  `agents/meta-builder-agent.md`, `commands/meta.md`, `skills/skill-meta/SKILL.md`,
  `context/patterns/telemetry-meta-submode.md`, `skills/skill-telemetry/SKILL.md`,
  `rules/source-store-deploy-boundary.md`, `context/standards/source-store-deploy-boundary-narrative.md`,
  `context/reference/state-management-schema.md`, `docs/reference/standards/multi-task-creation-standard.md`,
  `context/standards/postflight-tool-restrictions.md`, `hooks/validate-meta-write.sh`); `git log`/`git blame`
  forensics on the files above; the dispatch file's own measured evidence (2026-10-11, 2026-11-05)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The root-cause diagnosis in the dispatch is correct as a description of the *measured incident*
  (channel (b) of the orchestrate conclusion stage dispatches `meta-builder-agent` without ever
  resolving or passing `target_root`), but is **stale** about the agent's current defenses:
  `agents/meta-builder-agent.md`'s Stage 1 already carries a `$TARGET_ROOT` defensive fallback
  (`${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}`, explicitly forbidding CWD) that predates
  both the 2026-10-11 and 2026-11-05 diagnosis dates. Remedy (b), as literally described in the
  dispatch ("ADDING" a resolution step), is not needed — a resolution step already exists. What
  is genuinely missing is **auditability**: the existing fallback is prose-only, its use is
  "noted in the run log" with no fixed location or mechanical check, and it demonstrably failed
  to prevent the 2026-11-05 recurrence despite already being in place.
- Exactly three call sites dispatch `meta-builder-agent` directly: `skill-meta/SKILL.md` (correct
  — resolves and threads `target_root`), `context/patterns/telemetry-meta-submode.md` (correct),
  and `context/contracts/conclusion-stage.md` Step 4b (broken — passes neither `target_root` nor
  `mode_target`). This confirms the dispatch's own claim that remedy (a) alone would have
  sufficed for the measured 2026-11-05 instance.
- `skill-meta/SKILL.md`'s acknowledged "carried by the prompt today... a dependent follow-up task
  makes it durable" gap (its own line, written the same day as the agent's Stage-1 fallback was
  added) is **already discharged** by that same-day follow-up — the acknowledgment text itself is
  now stale and should be updated, not left as a reason to add new agent logic.
- The deploy-path-in-`file_scope` convention used by the six `BimodalLogic` records is
  **legitimate, not an authoring slip**: a source-store edit's mandatory redeploy step genuinely
  rewrites the deployed mirror path, so declaring both paths states something true about what the
  task's execution touches, not an overload of the field's "expects to create or modify"
  contract. No second field or marker is needed; the convention should be written down as
  explicitly sanctioned, asymmetric by which repo owns the source store.
- Recommended remedy mix: adopt (a) (narrowest, closes the one known broken dispatcher), replace
  the existing silent fallback in `meta-builder-agent.md` with a loud refusal rather than adding a
  new resolution mechanism, and adopt (c) as a documented standing rule distinguishing task
  *artifact* location (already exempt, unaffected) from task *siting* when the task's own edit
  target is the source store (new, narrower rule).

## Context & Scope

This research covers task 391's two linked questions: (1) how the orchestrate conclusion stage's
channel (b) came to file agent-system tasks into the wrong repository, what else shares that
exposure, and what remedy or remedy-combination closes it; and (2) whether a deployed `.claude/**`
path declared in a cross-repo task's `file_scope` — alongside its `agent-system/**` source
counterpart — is a legitimate convention or an authoring defect, and where that answer should be
written down. Both questions are scoped to the diagnosis and candidate assessment only; no edit
was made to any agent-system file in this research pass (edits belong to the plan/implement
phases), and no change was made to the six already-mis-sited `BimodalLogic` records (owned by the
sibling migration record) or to the conclusion stage's three-channel/approval-ledger mechanics
beyond what passing `target_root` requires.

## Findings

### The one broken dispatcher, confirmed by direct reading

`context/contracts/conclusion-stage.md` Step 4b ("Channel (b) execution: agent-system change",
lines 284-309) dispatches `meta-builder-agent` with `collected_answers.confirmed: true`, the
assembled change request, an anti-bypass restatement, and a source-store-boundary restatement —
but never resolves or mentions `target_root`/`mode_target` anywhere in that step or elsewhere in
the file. This matches the dispatch's own diagnosis exactly.

### Complete enumeration of direct `meta-builder-agent` dispatchers

Two differently-shaped sweeps were run and cross-checked, satisfying the enumeration-completeness
obligation (`report-format.md`'s "Carried-Figure Discipline" section):

1. **Broad pattern** — `grep -rl "meta-builder-agent" --include="*.md" .` under
   `agent-system/extensions/core/`: ~35 files, almost all of which are documentation/reference
   mentions (README, guides, architecture docs, templates) rather than dispatch sites.
2. **Narrow, differently-shaped pattern** — `grep -l "subagent_type"` restricted to the files
   found by pattern 1, then inspecting each hit: only `skill-meta/SKILL.md` carries the literal
   token `subagent_type: "meta-builder-agent"`. The other two genuine dispatch sites
   (`telemetry-meta-submode.md`, `conclusion-stage.md`) describe the dispatch in prose
   ("dispatch `meta-builder-agent` with...") rather than the structured token, which is why
   pattern 2 alone would under-count; reading every file matched by pattern 1 that contains the
   word "dispatch" near "meta-builder-agent" closed that gap.

Result — **exactly three direct dispatchers**, no fourth found by either sweep:

| Dispatcher | Resolves `target_root`? | Evidence |
|---|---|---|
| `skills/skill-meta/SKILL.md` Section 1/3/4 | Yes | Section 1 computes `GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"` and `target_root` from `local_mode`; Section 3's delegation context carries `target_root`; Section 4 additionally requires a path-qualification imperative in the dispatch prompt itself |
| `context/patterns/telemetry-meta-submode.md` (consumed by `skills/skill-telemetry/SKILL.md`'s `--meta` submode) | Yes | Line 14 resolves `target_root` first; the delegation-contract JSON (line ~133) carries `"target_root": "{resolved target_root}"` |
| `context/contracts/conclusion-stage.md` Step 4b | **No** | No `target_root`/`mode_target` field or resolution anywhere in the step or file |

This confirms the dispatch's own narrower claim: remedy (a) alone would have sufficed for the
measured 2026-11-05 instance, because every *other* direct dispatcher was already correct.

### The "no resolution step" premise is stale relative to measured file state

The dispatch's "ADDED EVIDENCE" section states: *"agents/meta-builder-agent.md's own Stage 1 says
it EXTRACTS target_root from the delegation context and holds it as $TARGET_ROOT ... So the agent
has no resolution step of its own to correct — remedy (b) means ADDING one"* and separately calls
the candidate "a silent **cwd** fallback."

Direct reading of `agents/meta-builder-agent.md` Stage 1 (lines 141-149) shows this is not
accurate as a description of the *current* file:

> **Defensive fallback**: if `target_root` is absent from the delegation context (an older caller
> or malformed input), resolve `TARGET_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"` and
> note the fallback was used in the run log. **CWD must never be the fallback** — CWD-as-default
> is the exact defect this contract exists to eliminate.

`git log`/`git blame` dates this text to commit `2d5ff5236` ("task 875 phase 1: establish
$TARGET_ROOT contract in Stage 1"), 2026-07-15 12:35 — **4 months before** the dispatch's own
2026-10-11 root-cause diagnosis and the 2026-11-05 recurrence. The fallback is not a CWD default;
it is the same `GLOBAL_ROOT` formula `commands/meta.md`'s Target Resolution section and
`skill-meta/SKILL.md` Section 1 already use, and it explicitly prohibits CWD.

This is a genuine discrepancy between the dispatch's premise and the measured current state, not
a quibble: it changes what remedy (b) should mean. The agent already has a resolution step; what
it lacks is **enforceable auditability**. "Note the fallback was used in the run log" names no
fixed field, no fixed location, and no mechanical check — it is exactly the kind of prose-only
compliance instruction that an LLM-executed, multi-step task-creation run (several tasks written,
a backlog-dedup pass run, `TODO.md`/`state.json` regenerated) can silently fail to apply
consistently, which is the most plausible explanation for how the 2026-11-05 incident still
happened four months after the fallback was written: the instruction to use `$TARGET_ROOT`
consistently was not re-derived at every Write call, and the agent's own natural default (writing
`specs/...` relative to session CWD) took over, exactly the behavior the fallback text calls out
as the one outcome it must never produce. This cannot be definitively re-run (the incident is a
past LLM execution, not a reproducible deterministic bug), but it is the explanation consistent
with every other measured fact: the fallback's *formula* has been correct and CWD-free since
July; its *enforcement* has no mechanical backstop anywhere in the codebase (confirmed below).

### `skill-meta`'s acknowledged gap is already discharged, not still open

`skill-meta/SKILL.md` lines 168-175 state the path-qualification imperative is "carried by the
prompt today; a dependent follow-up task makes it durable in the agent definition itself
(`meta-builder-agent.md`) rather than relying on prompt text alone." `git blame` dates this text
to commit `9a4231fcd0` ("task 873 phase 2: GLOBAL_ROOT resolution and chained postflight in
skill-meta"), 2026-07-15 11:00 — **95 minutes before** commit `2d5ff5236` (task 875) added
exactly the durable Stage-1 fallback this acknowledgment calls for. Task 875 is that dependent
follow-up, already landed, the same day. The acknowledgment text in `skill-meta/SKILL.md` was
simply never updated afterward and now describes a gap that has not existed since July. This is
one of the four "WHAT IS OWED" items from the dispatch, and the research answer is: **discharged**,
not "re-recorded as open" — `skill-meta/SKILL.md` lines 174-175 should be rewritten to state that
the agent now resolves (or should refuse on) `target_root` independently, making the prompt-text
instruction defense-in-depth rather than the sole mechanism.

### No mechanical enforcement exists for either the fallback or task siting

`hooks/validate-meta-write.sh` is the only runtime hook adjacent to this area. It fires on
`Write`/`Edit` targeting `.claude/**` paths and explicitly **skips `specs/*|*/specs/*` paths**
("those are legitimate task management writes") — so it has nothing to say about *where* a task
directory lands, only about accidental `.claude/**` hand-authoring. The
`source-store-deploy-boundary-narrative.md`'s own "Known limitation" paragraph states this
plainly for the adjacent edit-target rule: a PostToolUse hook "cannot know... which repository the
path belongs to... it is therefore only ever an advisory nudge on path *shape*, not a backstop for
target-root correctness." No code path anywhere checks that a newly created agent-system task's
`specs/` directory is inside the repository that actually owns the `agent-system/**` tree its
`file_scope` names. This is the structural reason the hole produced the 2026-11-05 recurrence
even with Stage 1's fallback text already written four months earlier: nothing catches a
compliance lapse after the fact, so an LLM agent's occasional drift from its own written
instruction is invisible until a human notices the misfiled task directory.

### GLOBAL_ROOT's "one repo owns everything" assumption holds in this installation

`commands/meta.md`'s Target Resolution section defines `GLOBAL_ROOT` once, globally, via
`CLAUDE_AGENT_GLOBAL_ROOT` (mirroring the `LIT_DIR`/`LITERATURE_DIR` convention), not per-extension.
Reading `.claude-extensions.json`'s `extensions.*.source_dir` values confirms every loaded
extension (`core`, `nix`, `lean`, `sapience`, `email`, `nvim`, `memory`, `approvals`, `literature`)
resolves to a path under the *same* repository's `agent-system/extensions/` tree. So the fallback
formula's implicit assumption — "the global agent-system home is one single repo" — is accurate
for this installation and is not itself a source of risk; the risk is purely the
auditability/enforcement gap described above.

### The deploy-path-`file_scope` convention is legitimate, not an authoring slip

The dispatch's framing already corrects an earlier wrong reading (treating the six `BimodalLogic`
records' dual `.claude/**`/`agent-system/**` declarations as an unchallenged defect) and asks
whether the convention itself is sound. Reading `context/reference/state-management-schema.md`'s
"File Scope Field" section settles this directly: `file_scope` is defined as "Anticipated
repo-relative paths or directory-prefixes this task expects to create or modify; used at
task-creation time to detect same-file overlap with sibling tasks" — its entire *purpose* is
overlap detection against whatever tree the declaring repo's own gate runs over, not a strict
literal "these are the only bytes a human types." Every agent-system task's description (as this
very dispatch demonstrates, verbatim, at its own top) carries a mandatory "SOURCE STORE IS THE
EDIT TARGET ... REDEPLOY AFTERWARDS via `deploy-headless.sh`" instruction. The redeploy step is
not optional cleanup; it is how the deployed `.claude/**` mirror is produced, and the mandated
redeploy genuinely rewrites that path as a mechanical consequence of the task's own execution. So
declaring both the source path and its deployed mirror in `file_scope` states something true, in
exactly the sense the field's own contract asks for — it is not an overload.

Whether a second field is needed to distinguish "edit target" from "declared collision surface"
("Decisions" below) depends on whether the two readings are ever in tension; they are not, because
both paths really are touched by the task's full execution (one directly, one via the mandated
redeploy). The asymmetry the dispatch asks about between the source-store-owning repo and a
deploy-only repo is real and already implicit in why the two repositories' comparable records
diverge: in the owning repo, the overlap gate runs over a tree where `agent-system/**` is the real,
present path and `.claude/**` is itself disposable (wiped/regenerated wholesale on reload, so a
`.claude/**`-vs-`.claude/**` collision between two source-store tasks is meaningless there); in a
deploy-only repo, the overlap gate can only ever see what physically exists on disk, which is
`.claude/**`, so a task declaring only its `agent-system/**` source path is genuinely invisible to
that gate — exactly the rationale the six `BimodalLogic` records' own "SOURCE-STORE BOUNDARY"
paragraphs state for themselves.

## Decisions

- **Remedy (a) — adopt.** Teach `conclusion-stage.md` Step 4b to resolve `target_root` the same
  way `skill-meta/SKILL.md` Section 1 and `telemetry-meta-submode.md` already do
  (`GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"`), and to include
  `"target_root"` and `"mode_target": "global"` in the dispatch body. Channel (b) has no `--local`
  analogue and should always resolve global — filing a channel-(b) task "locally" into whichever
  deploy-only repo `/orchestrate` happens to be running in is precisely the defect being closed,
  so there is no scenario where local mode is the right choice for this one call site. This is the
  cheapest, narrowest fix and directly closes the one measured-broken dispatcher.
- **Remedy (b) — adopt in a revised, narrower form: strengthen, not add.** The dispatch's framing
  ("ADDING" a resolution step, replacing "a silent cwd fallback") does not match the measured
  current file, which already resolves `$TARGET_ROOT` via the correct `GLOBAL_ROOT` formula and
  already forbids CWD. The genuine gap is auditability of compliance, not the resolution formula.
  Recommend replacing the *silent* fallback ("note... in the run log", no fixed field) with a
  **loud refusal**: when `target_root` is absent from the delegation context, Stage 1 writes
  `.return-meta.json` with `status: "blocked"` naming the missing field and the calling convention
  every other dispatcher already follows, and creates nothing, rather than guessing. This is
  strictly safer now that remedy (a) removes the one caller that would otherwise depend on the
  fallback at all: the refusal becomes a rare-path backstop for any not-yet-written caller, and it
  converts a future recurrence of this exact defect from a silent mis-filing (requiring by-hand
  relocation, as happened twice) into an immediately visible, auditable failure. Precedence is
  already unambiguous in the current contract and needs no new rule: an explicitly-passed
  `target_root` (global or `--local`) is always used as given; the refusal fires only on true
  absence of the key, never on a present-but-local value — so `--local` semantics are unaffected.
- **Discharge, do not re-record, `skill-meta`'s acknowledged gap.** Update
  `skill-meta/SKILL.md` lines 168-175 to state that `meta-builder-agent.md`'s own Stage 1 already
  resolves (or, per the revised remedy (b), refuses on) `target_root` independently, so the
  prompt's path-qualification imperative is now defense-in-depth rather than the sole mechanism.
  Do not leave the current "a dependent follow-up task makes it durable... " sentence as-is; it
  describes a gap that has not existed since the same day it was written. (Per
  `no-task-references-in-deliverables.md`, the replacement text must not cite a task number —
  describe the discharge by what changed, not by which task changed it.)
- **Remedy (c) — adopt as a standing rule, distinct from the existing edit-target rule.** Add a
  new, clearly separate principle — not folded into `rules/source-store-deploy-boundary.md`'s
  existing "Path Pattern" (which is scoped to `.claude/**` *writes*, i.e. edit targets) — stating
  that a task whose own edit target is the source store (an `agent-system/**` or extension-source
  path) must be *created* (sited) in the repository whose local filesystem actually contains that
  source directory (resolvable via `.claude-extensions.json`'s `source_dir`, mirroring the
  existing edit-target resolution procedure), never in a deploy-only repo where that path does not
  exist on disk. This is narrower than, and does not touch, the existing `specs/**` exemption: a
  task's own *artifacts* (reports, plans, summaries) may still legitimately live in whatever repo
  `/orchestrate` is running from — that exemption is about artifact location and stays exactly as
  written. The new rule is about the task's *creation site* when its declared edit target is the
  source store. Recommended placement: a new subsection in both
  `rules/source-store-deploy-boundary.md` (eager, short principle) and
  `context/standards/source-store-deploy-boundary-narrative.md` (the "Known limitation" paragraph
  already names this exact gap verbatim — "not a backstop for target-root correctness" — making it
  the natural anchor for the new narrative detail).
- **File_scope convention — legitimate; document, do not add a field.** Declaring both the
  source-store path and its deployed mirror in a cross-repo task's `file_scope` is a true
  statement about what the task's execution (edit + mandatory redeploy) touches, not an overload
  of the field's contract. No second field or marker is needed, because the two readings
  ("edit target" vs. "declared collision surface") are never actually in tension — both paths are
  genuinely touched. Record this as the settled answer in
  `context/reference/state-management-schema.md`'s "File Scope Field" section (the authoritative
  schema reference for the field), stating the asymmetry explicitly: the source-store-owning repo
  may declare the source path alone (its own `.claude/**` is disposable and not meaningful to
  overlap-check there); a deploy-only repo should declare both paths for the mirror's overlap-gate
  visibility, when such a task is filed there at all. Note, per the dispatch's own framing, that
  remedy (c) is expected to make the deploy-only-repo case exceptional going forward rather than
  dissolve the question outright — the six historical `BimodalLogic` records (left to the sibling
  migration task) and any deliberate future `--local` run from a deploy-only repo still need a
  written answer.
- **`commands/meta.md` — likely no edit needed.** `commands/meta.md`'s Target Resolution section
  already documents the correct pattern that `skill-meta/SKILL.md` implements; it is not itself a
  direct dispatcher and the measured defect does not touch it. Recommend the plan phase narrow it
  out of `file_scope` unless it adds a one-line cross-reference pointing future dispatcher authors
  at the pattern (an editorial, non-load-bearing addition).
- **`context/standards/postflight-tool-restrictions.md`'s Conclusion Stage Bash row — flag for
  plan-time addition.** Resolving `GLOBAL_ROOT` in Step 4b is a one-line shell variable expansion,
  not a new script, but the "Allowed Tool Surface" table's `Bash` row currently enumerates only
  named scripts (`orchestrate-conclusion-aggregate.sh`, `state-write.sh`, `generate-todo.sh`,
  `roadmap-integration.sh --regenerate`, `git-commit-scoped.sh`, `manage-topics.sh set`). For
  consistency with that table's own enumeration style, the plan phase should consider adding this
  resolution explicitly rather than relying on it being implicitly covered. This file was not
  named in the dispatch's own `FILE SCOPE` list and is surfaced here as a candidate addition for
  the plan phase to accept or reject.

## Recommendations

1. In `context/contracts/conclusion-stage.md` Step 4b, add an explicit `target_root`/`mode_target`
   resolution (always global, no `--local` branch) immediately before the dispatch, and include
   both fields in the dispatch body — mirroring `skill-meta/SKILL.md` Section 1/3's resolution
   code and Section 4's path-qualification imperative text verbatim where possible, so the three
   dispatch sites read as one maintained pattern rather than three independent re-derivations.
2. In `agents/meta-builder-agent.md` Stage 1, replace the "note the fallback was used in the run
   log" silent-fallback sentence with an explicit refusal: on an absent `target_root`, stop before
   any Write/Edit, write `.return-meta.json` with `status: "blocked"` and a message naming the
   missing field and pointing at the calling convention the other two dispatchers already use,
   and create nothing. Keep the GLOBAL_ROOT-vs-CWD distinction and the explicit-value-always-wins
   precedence exactly as already written — only the absent-key branch's *action* changes, from
   silent best-guess to loud stop.
3. Update `skill-meta/SKILL.md` lines 168-175 to describe the current, already-discharged state
   (the agent enforces its own `target_root` requirement) rather than an open follow-up —
   phrased without a task-number citation per `no-task-references-in-deliverables.md`.
4. Add a new, separately-labeled standing-rule subsection (not merged into the existing
   `.claude/**`-scoped "Path Pattern") to `rules/source-store-deploy-boundary.md` and its
   narrative, stating the task-siting rule for a task whose edit target is the source store, and
   explicitly distinguishing it from the unaffected `specs/**` artifact-location exemption.
5. Add a "Deploy-Path Declarations for Cross-Repo Visibility" note to
   `context/reference/state-management-schema.md`'s "File Scope Field" section recording the
   legitimacy verdict, the owning-repo-vs-deploy-only-repo asymmetry, and a cross-reference to the
   new standing rule in recommendation 4 — this is "the file carrying that contract" the dispatch
   asks to be added to `file_scope` once the convention question is settled in writing.
6. Narrow the plan's `file_scope` to: `context/contracts/conclusion-stage.md`,
   `agents/meta-builder-agent.md`, `skills/skill-meta/SKILL.md`,
   `rules/source-store-deploy-boundary.md`, `context/standards/source-store-deploy-boundary-narrative.md`,
   `context/reference/state-management-schema.md`, and (candidate, plan-time decision)
   `context/standards/postflight-tool-restrictions.md`. Drop `commands/meta.md` from the
   mandatory set per the Decisions section above unless the plan phase wants the optional
   cross-reference addition.

## Risks & Mitigations

- **Risk**: converting the silent fallback to a refusal could, in principle, block a legitimate
  future caller that has some as-yet-unenvisioned reason to omit `target_root`. **Mitigation**:
  no such caller exists today (all three enumerated dispatchers are accounted for, and two already
  pass the field correctly); a future caller that needs to omit it is itself malformed by the same
  standard every existing dispatcher already meets, and the refusal's error message should name
  the convention so the fix is immediate and obvious rather than mysterious.
- **Risk**: the standing rule (remedy c) is, like the existing edit-target rule, enforceable only
  by documentation and agent-contract reinforcement — no blocking hook exists or is proposed here.
  **Mitigation**: this is accepted, consistent with the existing edit-target rule's own documented
  posture ("Known limitation" paragraph); remedies (a) and (b) are the load-bearing mechanical
  fixes, and (c) is the standing documentary backstop a reviewer or future author can point to,
  not a substitute for them.
- **Risk**: documenting the deploy-path `file_scope` convention without a second field leaves
  no machine-readable way to tell "edit target" apart from "collision-visibility declaration" if a
  future consumer ever needs that distinction (e.g. a stricter overlap-gate variant).
  **Mitigation**: no current consumer needs it (both paths are genuinely touched by the task's
  execution, so no reading is ever wrong), and the dispatch's own six-record sample plus this
  repo's own sample already demonstrate the convention is stable without one; revisit only if a
  concrete new consumer need arises.

## Context Extension Recommendations

- **Topic**: cross-repository task siting for source-store-targeting work.
- **Gap**: prior to this task, nothing in `context/standards/source-store-deploy-boundary-narrative.md`
  addressed *where a task is created*, only *where an edit lands*; the narrative's own "Known
  limitation" paragraph already named the gap in passing ("not a backstop for target-root
  correctness") without resolving it.
- **Recommendation**: the standing rule added under Decisions/Recommendations above closes this
  gap directly; no separate context file is needed beyond that addition.

## Appendix

- Search patterns used for the dispatcher enumeration (see Findings above for the
  completeness obligation this satisfies): `grep -rl "meta-builder-agent" --include="*.md" .`
  (broad); `grep -l "subagent_type"` restricted to that result set, then manual inspection of
  every file in the broad set containing "dispatch" near "meta-builder-agent" (narrow,
  differently shaped).
- `git log --all -S"Defensive fallback" --oneline -- agents/meta-builder-agent.md` →
  `2d5ff5236` ("task 875 phase 1: establish $TARGET_ROOT contract in Stage 1"), 2026-07-15.
- `git blame -L 168,176 -- skills/skill-meta/SKILL.md` →
  `9a4231fcd0` ("task 873 phase 2: GLOBAL_ROOT resolution and chained postflight in skill-meta"),
  2026-07-15, 95 minutes before the commit above.
- `jq -r '.extensions | to_entries[] | "\(.key): \(.value.source_dir)"' .claude-extensions.json`
  confirmed every loaded extension's `source_dir` resolves under this installation's single
  `agent-system/extensions/` tree.
