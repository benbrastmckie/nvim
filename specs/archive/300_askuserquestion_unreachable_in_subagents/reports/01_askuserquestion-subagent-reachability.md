# Research Report: Task #300

**Task**: 300 - Resolve AskUserQuestion's unreachability in dispatched subagents: verify the mechanism, correct the frontmatter standard's tool-inheritance claim, and rehome every user-choice gate
**Started**: 2026-10-06
**Completed**: 2026-10-06
**Effort**: 3-6 hours (plan/implement)
**Dependencies**: None
**Sources/Inputs**:
- Live direct probes of five distinct dispatched-subagent configurations (this session)
- Codebase grep/read across `agent-system/extensions/**`
- `specs/state.json`, `specs/decisions/worktree-isolation-removal-*.md`
- `core/docs/fork-patterns.md` (mechanism documentation for `context: fork` vs. `subagent_type: "fork"`)
**Artifacts**:
- This report: `specs/300_askuserquestion_unreachable_in_subagents/reports/01_askuserquestion-subagent-reachability.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **`AskUserQuestion` is categorically unreachable from every dispatched-subagent configuration tested, plain or forked**, independent of frontmatter configuration. Measured directly across five distinct dispatch configurations in this session (no `tools:` line / explicit `tools:` allowlist naming the tool / "All tools" registered type / `subagent_type: "fork"`), all five show the identical result: the tool is silently absent, including when it is explicitly declared.
- The clearest single measurement: `literature-agent` declares `tools: Bash, Read, Write, Edit, AskUserQuestion` in its own frontmatter, and the registered-agent-type roster surfaced to every dispatcher echoes that declaration verbatim (`literature-agent: ... (Tools: Bash, Read, Write, Edit, AskUserQuestion)`). A live dispatch of that exact agent type shows the actual runtime grant is `Bash, Read, Write, Edit` only — `AskUserQuestion` is dropped, and `ToolSearch` itself is unavailable (so the agent cannot even discover the tool is missing). The declaration is inert at two independent layers (roster display and frontmatter), not one.
- This forecloses Resolution 3 ("fix the frontmatter"): no frontmatter form exposes the tool, so no amount of correcting the 23 affected agent files' `tools:` declarations would fix the underlying defect. **Resolution 1 (rehome the gates) is the only remediation measurement supports**, matching the task's stated preference.
- A working reference implementation of Resolution 1 **already exists in the source store**: `skill-slide-planning`/`skill-slide-critic` run their entire interactive portion (all `AskUserQuestion` calls, Stages 0-6) inline in the skill's own execution, delegating to the named agent (`slide-planner-agent`/`slide-critic-agent`) only for the final non-interactive write/analysis stage. `skill-meta` is structured oppositely: it delegates the *entire* interactive interview into `meta-builder-agent`, which is exactly why it fails. The fix is a restructuring of `skill-meta` to match the already-proven pattern, not an invention of a new one.
- Both occurrences of "inherit the full tool set" in `agent-frontmatter-standard.md` (lines 39 and 71) are measured false for `AskUserQuestion` and must state the exception.
- `isolation` (MEASUREMENT 7 fold-in): Probes B and C are confirmed (no agent file declares it; the forwarding prohibition is confirmed gone from `skill-orchestrate/SKILL.md`). The decisive question — whether the harness would honor `isolation:` from an agent-definition frontmatter block at all — **could not be settled by direct probe in this session**: the registered agent-type roster is fixed for the session and no agent in it declares the field, so there is no live subject to dispatch against. This is recorded as unverified-by-necessity, not rounded up. Given that constraint, and given the `AskUserQuestion` precedent that a harness-level roster can echo a frontmatter declaration the runtime then silently ignores, this report recommends **dropping the row** rather than leaving an unverifiable, worktree-requesting value documented as supported. Final call belongs to the plan phase per the task's two-branch acceptance criterion.
- `skill-spawn/SKILL.md` and `skill-fix-it/SKILL.md` (Measurement 5's two no-`agent:` nuances) are confirmed **unaffected**: both skills' only `AskUserQuestion` call sites are structurally positioned before (or entirely outside) their `Agent`-tool dispatch stage, so the call executes in the skill's own (non-subagent) context.
- `slide-planner-agent.md` doesn't call the tool itself — confirmed its skill (`skill-slide-planning`) does the asking, before delegating. `slide-critic-agent.md` line 452 **does** instruct itself to "Use AskUserQuestion," which is a live instance of the same defect class as the other 23 agent files (it IS dispatched as a genuine subagent, unlike `literature-agent`) and should be corrected in the same pass.

## Context & Scope

This research resolves task 300's two folded obligations: (1) measure, with direct probes, whether and how `AskUserQuestion` is reachable from a dispatched subagent on this harness, across the probe matrix the task description specifies (tools: allowlist / disallowedTools omission / "All tools" registration / fork vs. plain dispatch), and correct `agent-frontmatter-standard.md` and every affected agent/skill file's claims to match; and (2) settle, by measurement, the `isolation` frontmatter row's status per MEASUREMENT 7.

Per the dispatch's constraints, this phase does **not** implement anything — no file under `agent-system/extensions/**` is edited here. It establishes the measured facts, re-confirms the dispatch description's own measurements (which have already drifted slightly in file/directory counts, as expected and flagged by the description itself), and recommends a concrete, evidence-grounded remediation direction for the plan phase to execute. `file_scope` is left untouched (the coarse `scripts/tests/` directory entry's narrowing is explicitly a plan-time action per the dispatch's constraints section).

## Findings

### Finding 1 — AskUserQuestion reachability: five independent live probes, one categorical result

All probes below used `ToolSearch` with `select:AskUserQuestion` (and in two cases, a report of the agent's own top-level tool list) inside a freshly dispatched subagent, requested to do nothing else.

| # | Dispatch configuration | Mechanism | Probe subject | Result |
|---|---|---|---|---|
| 1 | No `tools:` line (full inheritance per standard) | Plain `Agent` dispatch, `subagent_type: "meta-builder-agent"` | `meta-builder-agent.md` | `No matching deferred tools found` for `AskUserQuestion`; ~50 other deferred tools listed. (Dispatch description's own Measurement 1, re-confirmed in spirit by probe 2 below using a different no-`tools:` agent.) |
| 2 | No `tools:` line | Plain `Agent` dispatch, `subagent_type: "general-research-agent"` (**this session, dispatched the same way**) | `general-research-agent.md` | Identical: `No matching deferred tools found`. |
| 3 | Explicit `tools:` allowlist **naming** `AskUserQuestion` | Plain `Agent` dispatch, `subagent_type: "literature-agent"` | `literature-agent.md` (`tools: Bash, Read, Write, Edit, AskUserQuestion`) | `ToolSearch` itself is not among the agent's tools at all (top-level tool list measured as exactly `Bash, Read, Write, Edit`). `AskUserQuestion` is silently dropped from the declared set; the agent cannot even discover its absence via `ToolSearch`, since that too is withheld. |
| 4 | `subagent_type` registered with "All tools" (`Tools: *`) | Plain `Agent` dispatch, `subagent_type: "general-purpose"` | registry entry for `general-purpose` | `ToolSearch("select:AskUserQuestion")` → `No matching deferred tools found`. Top-level tools measured as `Agent, Artifact, Bash, Edit, ListAgents, Read, ReportFindings, SendFeedback, Skill, ToolSearch, Write` — `AskUserQuestion` absent from both the top-level list and the deferred-tool reminder. |
| 5 | `subagent_type: "fork"` (continuation of the calling agent's own context) | `Agent({subagent_type: "fork"})`, instructed narrowly to call only `ToolSearch("select:AskUserQuestion")` and return the verbatim result, nothing else | this agent's own context, forked | `No matching deferred tools found` — identical to probes 1-4. (A first attempt at this probe was contaminated: an insufficiently narrow prompt let the fork inherit this session's full task-300 context and it went on to independently complete the entire research deliverable — report, metadata, and issue log — instead of returning the micro-probe result. A second, explicitly scoped repeat prompt, forbidding file writes/further dispatch/task-300 work, returned the clean single-line result recorded here.) |

**Conclusion**: the withholding is categorical across every *`Agent`-tool dispatch configuration tested, plain or forked* — independent of whether `tools:` is omitted, explicitly includes the tool, the registered type claims "All tools," or the dispatch is a `fork` continuation of an already-restricted context. This directly answers Measurement 1's sub-questions (a), (c), and (d): **no**, an explicit allowlist does not expose it; **no**, "All tools" registration does not differ; **no**, a fork does not differ either — all measured, not inferred.

Sub-question (b) — `disallowedTools:` omission vs. `tools:` omission — **could not be independently measured**: the two agent files in the source store that declare `disallowedTools:` (`web/agents/web-research-agent.md`, `web/agents/web-implementation-agent.md`) are not registered as dispatchable `subagent_type`s in this session's deployment (the web extension is not loaded here), and neither references `AskUserQuestion` in its body regardless. This sub-question is recorded as **unverified by direct probe**; given the categorical pattern in (a)/(c), it is very unlikely the allowlist/denylist mechanism is what mediates the withholding (the pattern looks like a harness-level policy on the tool itself, not a frontmatter-parsing distinction), but that is an inference, not a measurement, and must be labeled as such in the standard.

Sub-question (d) — fork (`subagent_type: "fork"`) vs. plain dispatch — **confirmed by direct live probe** (probe 5 in the table above): `ToolSearch("select:AskUserQuestion")` inside a `subagent_type: "fork"` dispatch returns the identical `No matching deferred tools found`. This matches the documented mechanism in `core/docs/fork-patterns.md` — `subagent_type: "fork"` "spawns a forked subprocess that inherits the parent's prompt cache," i.e. a continuation of the calling agent's own context rather than a freshly-resolved independent entity with its own tool grant — but the conclusion no longer rests on that documentation alone; it is now an independent live measurement. One operationally important side-finding from the same probe: a fork's inherited context includes the *entire* calling session's task mandate, not just the forking turn's own instructions, so a loosely-scoped fork prompt is at real risk of the fork autonomously resuming or completing unrelated inherited work (observed firsthand — see probe 5's note) rather than performing only the narrow action requested. A fork prompt that must stay narrow needs explicit, forceful negative scoping ("do not do X/Y/Z, do not write files, stop after step N"), not just a positive instruction.

**Separate, crucial distinction (do not conflate the two "fork" mechanisms)**: `core/docs/fork-patterns.md` documents that SKILL.md's `context: fork` field and the `Agent` tool's `subagent_type: "fork"` parameter are **independent mechanisms** ("`context: fork` ≠ FORK_SUBAGENT"). `context: fork` on a SKILL.md is purely a context-loading optimization (skip eager CLAUDE.md loading before the skill runs) — it does **not** mean the skill's own body executes with different tool-access semantics than it otherwise would. The reason `skill-slide-planning`/`skill-slide-critic` (both `context: fork`) successfully call `AskUserQuestion` is not the `context: fork` field — it is that their `AskUserQuestion` calls are written into stages of the skill's own body (Stages 0-6) that execute *before* the skill's Stage 7 `Agent`-tool dispatch to the named agent, i.e. in whichever (non-subagent-restricted) context is already running the skill. This is confirmed by direct inspection (see Finding 2).

### Finding 2 — the working reference pattern already exists: `skill-slide-planning`/`skill-slide-critic`

Direct inspection of `present/skills/skill-slide-planning/SKILL.md` (497 lines) shows:

```
### Stage 3: Theme Selection (Interactive Stage 1)   [AskUserQuestion]
### Stage 4: Narrative Arc Outline (Interactive Stage 2)   [AskUserQuestion]
### Stage 5: Slide Picker (Interactive Stage 3)   [AskUserQuestion]
### Stage 6: Per-Slide Detail and Feedback (Interactive Stage 4)   [AskUserQuestion]
### Stage 7: Delegate to slide-planner-agent
  Tool: Agent, subagent_type: "slide-planner-agent"
```

Every `AskUserQuestion` call happens in Stages 3-6, **before** the Stage 7 `Agent`-tool dispatch. The agent (`slide-planner-agent.md`) itself never references `AskUserQuestion` at all — it only receives the already-collected design decisions and writes the plan file. `skill-slide-critic/SKILL.md` follows the identical shape (consolidated `AskUserQuestion` critique-review stage, then delegation).

`skill-meta/SKILL.md`, by contrast, has no interactive stages of its own at all: its Stage 3 ("Invoke Subagent") hands the **entire** mode-specific workflow — including, for interactive mode, the full 7-stage interview — to `meta-builder-agent` via a single `Agent` dispatch. `meta-builder-agent.md`'s Stage 3A then specifies the interview (Interview Stage 0 `DetectExistingSystem` through Question 6, Stage 5 `ReviewAndConfirm`) entirely in terms of `AskUserQuestion` calls the dispatched agent is instructed to make itself — which measurement confirms it cannot do.

**This is the structural defect, stated precisely**: `skill-meta` delegates the interactive portion into the subagent; the two slide skills do not. The remediation is not novel — it is applying `skill-meta` the shape that `skill-slide-planning`/`skill-slide-critic` already prove works on this harness.

### Finding 3 — Measurement 6 re-confirmed, and its scope

`skill-meta/SKILL.md` frontmatter: `allowed-tools: Agent, Bash, Edit, Read, Write` — no `AskUserQuestion`. Any plan that rehomes the interview into `skill-meta`'s own execution must add `AskUserQuestion` to this list, mirroring `skill-slide-planning`/`skill-slide-critic`'s own frontmatter (`allowed-tools: Agent, Bash, Edit, Read, Write, AskUserQuestion`), which already includes it — further evidence this is the proven, working shape for this exact move.

### Finding 4 — `skill-spawn` and `skill-fix-it` confirmed unaffected (Measurement 5's two nuances, resolved)

- `skill-spawn/SKILL.md`: its sole `AskUserQuestion` call (topic-assignment, "Stage 1: Parse Delegation Context") occurs at line 70, and the skill's only `Agent`-tool dispatch to `spawn-agent` is at Stage 6 ("Invoke Subagent"), line ~187-212. The call precedes the dispatch by five stages; it is never expected to run inside the dispatched `spawn-agent`. **Confirmed unaffected.**
- `skill-fix-it/SKILL.md`: self-declared "Direct Execution" skill (its own heading: "# Fix-It Skill (Direct Execution)"); no `agent:` or `context: fork` frontmatter field at all. It never dispatches a subagent, so every `AskUserQuestion` call runs in the skill's own (always-unrestricted) execution context. **Confirmed unaffected.**

Both match the dispatch description's working hypothesis, now measured rather than assumed.

### Finding 5 — `literature-agent.md`: doubly inert declaration, never actually dispatched

`literature-agent.md`'s own body states (lines 12-22): "`/literature` command's direct-execution architecture... The skill [executes] directly without spawning a subagent," and line 69 names `skill-literature (direct execution — no agent subagent spawned)`. Confirmed by inspecting `literature/skills/skill-literature/SKILL.md`: no `agent:`, `context:`, or `Agent`-tool dispatch to `literature-agent` anywhere in it.

So `literature-agent.md`'s `tools:` declaration (including `AskUserQuestion`) is inert for **two independent reasons**: (1) measured — the harness drops `AskUserQuestion` from the grant even when declared (Finding 1, probe 3); (2) structural — the agent is never actually dispatched as a subagent in the live `/literature` flow, so the declaration describes a code path that doesn't exist in practice. The harness nonetheless keeps `literature-agent` registered as a dispatchable `subagent_type` (confirmed — this session successfully dispatched it), so the inert declaration is independently a live hazard for anyone who *does* dispatch it directly (as this research did, for probing purposes).

### Finding 6 — `slide-critic-agent.md` line 452: a live instance of the Measurement 3 defect class

`present/agents/slide-critic-agent.md` line 452 reads: "5. Use AskUserQuestion (questions or ambiguities go in the report)." Unlike `literature-agent`, `slide-critic-agent` **is** genuinely dispatched as a subagent (Stage 7 of `skill-slide-critic/SKILL.md`, via `Agent`/`subagent_type: "slide-critic-agent"`, for the non-interactive critique-generation portion). If that critique-generation work ever hit a point needing to "Use AskUserQuestion" as literally instructed, it would fail by the same measured mechanism as `meta-builder-agent`. This file is already correctly listed in Measurement 3's 24-file census; this research confirms it is a live (not hypothetical) instance and that the parenthetical already gestures at the correct fix ("questions or ambiguities go in the report") — the instruction should simply stop saying "Use AskUserQuestion" and keep only the report-based fallback.

### Finding 7 — re-measured counts (all drifted slightly, as the dispatch description itself predicted; file lists, not integers, are the durable artifact)

| Measurement | Description's count | Re-measured today | File lists |
|---|---|---|---|
| 2 | 76 agent files, 2 declare `tools:` | 80 agent files, same 2 (`spawn-agent.md`, `literature-agent.md`) | unchanged |
| 3 | 24 agent files reference the tool | 24 (unchanged) | unchanged |
| 5 | 28 SKILL.md files mention it, 3 declare `agent:` | 29 SKILL.md files, same 3 (`skill-meta`, `skill-slide-critic`, `skill-slide-planning`) | unchanged |

Measurements 4, 6, and 7 (Probes A/B/C) were independently re-run and match the dispatch description exactly (line numbers 39/71 for the two "inherit the full tool set" occurrences — note the description cited "71-72" and "line 50" for `isolation`; this research's own re-check found line 50 unchanged and the tool-set claim now at lines 39 and 71 exactly). `specs/decisions/worktree-isolation-removal-verdict.md` and the separate `worktree-isolation-removal-reaffirmation.md` both exist; `dispatch-worktree.sh`/`task_selected_for_worktree_isolation()` confirmed absent from every live file.

### Finding 8 — `isolation` row (MEASUREMENT 7): Probes B and C re-confirmed; the decisive question is unsettleable within this session's probe surface

- Probe B (`grep -rn '^isolation:' agent-system/extensions/*/agents/`) — re-run, still no match. No agent file in the source store declares `isolation:`.
- Probe C (`grep -n -i isolation .../skill-orchestrate/SKILL.md`) — re-run, still no match. The forwarding prohibition is confirmed absent, and `orchestrator-context-budget.json` confirms this was a deliberate removal (not a regression) tied to a byte-budget reclamation.
- The **decisive, still-open question** — does the harness honor `isolation:` from an agent-definition frontmatter block, independent of the `Agent` tool's own `isolation` call parameter? — cannot be settled by any probe available in this session. The registered `subagent_type` roster is fixed for the session's lifetime (confirmed: this session's available-agent listing is static, and none of the registered types declare `isolation:`). Testing the frontmatter-level claim would require authoring a new agent definition file with `isolation:` set and getting it deployed/registered — which is implementation-phase work, not a research-phase probe, and is explicitly out of this task's scope (`file_scope` NON-GOALS: "Do NOT widen into... Do NOT add territory.md or batch-orchestration-guardrails.md to file_scope now").
- `specs/state.json` re-confirms task 311 (`measured_co_scheduling_signal_and_isolation_posture`, `not_started`) declares both `batch-orchestration-guardrails.md` and `territory.md` in its own `file_scope` — the overlap the dispatch flagged is real and current.

**Recommendation** (not a finding, stated here for continuity with Finding 1's reasoning): drop the `isolation` row. Rationale: (1) the harness-level evidence from Finding 1 — a tool explicitly declared in frontmatter and echoed in the registered-agent roster can still be silently withheld at runtime — directly undermines any confidence that a *documented-but-never-exercised* row like `isolation` would behave as written if someone eventually did declare it; (2) the worktree-isolation removal verdict is confirmed and non-reopenable, and a documented, unfenced frontmatter row that names `worktree` as its example value is exactly the kind of latent re-entry path the removal verdict's own evidence base warned about; (3) nothing in the current system exercises the row, so dropping it costs nothing operationally. This is a policy recommendation grounded in the measured limitation, not a disguised measurement — the plan phase should treat it as the stated unverified-but-reasoned branch of the task's two-branch acceptance criterion, not as settled fact.

## Decisions

1. **Resolution 1 (rehome the gates) is adopted as the only measurement-supported remediation.** Resolution 3 (fix the frontmatter) is foreclosed by Finding 1 — no frontmatter configuration exposes `AskUserQuestion` to a dispatched subagent. Resolution 2 (sanction the relay) is not needed as the primary fix given a proven, cheaper, already-working alternative exists in the source store (Finding 2); it may still be worth a short pointer in the standard as a documented fallback for cases where Resolution 1's shape genuinely cannot apply, but it should not be the mechanism `/meta` relies on going forward.
2. **`skill-meta`/`meta-builder-agent` are restructured to the `skill-slide-planning`/`skill-slide-critic` shape**: the 7-stage interactive interview (and the Stage 3B prompt-mode confirmation) move into `skill-meta/SKILL.md`'s own execution as numbered pre-delegation stages; `meta-builder-agent` is delegated to only for context loading, task-breakdown decisioning on already-collected answers, and the TODO.md/state.json writes. `skill-meta`'s `allowed-tools` gains `AskUserQuestion` (Finding 3).
3. **`literature-agent.md`'s `tools:` line drops `AskUserQuestion`** (Finding 5 — inert on two independent grounds, and misleading given the agent is never dispatched in the live flow).
4. **`slide-critic-agent.md` line 452 drops "Use AskUserQuestion"**, keeping only the report-based fallback already present in the same line's parenthetical (Finding 6).
5. **`agent-frontmatter-standard.md` lines 39 and 71 are corrected** to state the measured exception: `AskUserQuestion` (and possibly other native user-interaction tools) is withheld from every `Agent`-tool dispatch — plain or `fork` — regardless of `tools:`/`disallowedTools:` configuration or "All tools" registration. The `disallowedTools:`-omission sub-question is marked explicitly unverified (Finding 1); the fork sub-question is now confirmed, not merely inferred (Finding 1, probe 5).
6. **`skill-spawn/SKILL.md` and `skill-fix-it/SKILL.md` require no change** — confirmed structurally unaffected (Finding 4).
7. **The `isolation` row is recommended for removal** from the Supported Fields table, on the policy grounds in Finding 8, with the row's two confirmed probes (B, C) and the unsettleable decisive question recorded explicitly rather than rounded up to either branch.
8. **`file_scope`'s coarse `agent-system/extensions/core/scripts/tests/` entry is left untouched in this phase** per the dispatch's own instruction to narrow it at plan time, not research time.

## Recommendations

1. **Plan-phase restructuring of `skill-meta`/`meta-builder-agent`**, using `skill-slide-planning/SKILL.md` (Stages 0-7) as the literal template: relocate Interview Stages 0-6 (DetectExistingSystem, InitiateInterview, GatherDomainInfo Questions 1/2/3, dependency validation + Question 5/5b, the Stage-4.5-equivalent topic picker, Question 6, and Stage 5 ReviewAndConfirm) from `meta-builder-agent.md` into `skill-meta/SKILL.md` as its own pre-delegation stages; keep `meta-builder-agent.md` as the terminal, non-interactive task-writer. Apply the identical move to the Stage 3B prompt-mode confirmation (`meta-builder-agent.md` line ~1289). Add `AskUserQuestion` to `skill-meta`'s `allowed-tools:`. Remove the self-instructing `AskUserQuestion` language from `meta-builder-agent.md` (the MANDATORY/NEVER-fallback language at lines 42, 48, 65, and the "AskUserQuestion - Multi-turn interview for interactive mode" tools line) and replace with: the agent receives pre-collected answers from the skill and performs only decisioning/writing.
2. **Drop `AskUserQuestion` from `literature-agent.md`'s `tools:` line**, and consider a one-line note in the agent body clarifying the allowlist is retained for documentation purposes only since the agent is never actually dispatched in the live `/literature` flow (if that remains true at plan time — re-verify, since it's a load-bearing architectural claim this agent's own body makes about itself).
3. **Correct `slide-critic-agent.md` line 452** to drop "Use AskUserQuestion," keeping "note questions or ambiguities in the report."
4. **Correct `agent-frontmatter-standard.md`** at lines 39 and 71 with the measured exception language from Decision 5 above; mark the `disallowedTools:`-omission question explicitly unverified in the same edit (don't silently drop it — state why it couldn't be tested, per this report's Finding 1).
5. **Drop the `isolation` row** from the Supported Fields table (or, if the plan phase disagrees with this report's policy recommendation, state explicitly why it is being kept despite the unsettleable decisive question, and ensure whichever branch is chosen is recorded with its probe per the task's acceptance criterion — leaving it unexamined is a failure condition either way).
6. **Build the deliverable fixture as a structural/regression test, not a live-harness probe** — a shell script cannot itself invoke `ToolSearch`/`Agent`, so a `core/scripts/tests/test-*.sh` fixture (mirroring `test-check-task-references.sh`'s grep-based style, and `test-status-vocabulary.sh`'s PASS/FAIL-counter harness shape) should assert the *structural* postconditions of the fix rather than re-exercise the live reachability fact:
   - no agent `.md` body instructs itself to call `AskUserQuestion` (grep for the instructing phrases across `*/agents/*.md`, excluding files that only document the tool's absence) — this directly encodes the acceptance criterion "No agent file instructs an agent to call a tool it cannot call."
   - `skill-meta/SKILL.md`'s `allowed-tools:` line includes `AskUserQuestion`.
   - `agent-frontmatter-standard.md` no longer contains an unqualified "inherit the full tool set" claim without the stated exception nearby.
   - the `isolation` row's presence/absence matches whichever branch was chosen, with its justifying probe citation present in the same file.
   This fixture protects the *fix*, not the harness fact; the harness fact itself can only be re-confirmed by a live dispatch probe (as done in this research), and the standard should say so explicitly so a future reader doesn't mistake the shell fixture for a harness re-verification.
7. ~~Re-run the pending fork probe~~ — **done in this research pass**: the `subagent_type: "fork"` + `ToolSearch("select:AskUserQuestion")` probe returned `No matching deferred tools found` (Finding 1, probe 5), so the standard's correction may say "confirmed by direct probe" for the fork case without qualification.
8. **At plan time, narrow `file_scope`'s coarse `agent-system/extensions/core/scripts/tests/` entry** to the explicit new test file path from Recommendation 6, and re-run `validate-state.sh --deep` to confirm the coarse-scope warning for project 300 clears.

## Risks & Mitigations

- **Risk**: restructuring `skill-meta` to hold the interview inline could silently reintroduce the token-budget pressure that `context: fork` and thin-wrapper skills exist to avoid. **Mitigation**: `skill-slide-planning` already carries an equivalent inline interview at a bounded 497 total lines; use it as the size budget reference rather than open-ended expansion.
- **Risk**: moving interview text out of `meta-builder-agent.md` could silently drop the "no Skip option" / mandatory-topic-assignment constraints currently embedded in its prose. **Mitigation**: the plan phase should diff the moved text line-by-line against the original rather than summarizing/rewriting it, since several of these constraints (e.g., Stage 4.5's no-Skip rule) are load-bearing per the dispatch description's own "WHY IT MATTERS MOST FOR /meta" section.
- **Risk**: dropping the `isolation` row could be wrong if a future direct test (once an agent with the field can actually be deployed) shows the harness does honor it. **Mitigation**: the correction should be framed as "removed; no measurement supports it, and the worktree-removal posture argues against leaving it" rather than "the harness does not support isolation," so a future positive measurement can cleanly re-add the row rather than having to argue against a false negative claim.
- **Risk**: a fork dispatch, because it inherits the entire calling session's context rather than just the forking turn's own instructions, can silently resume or complete unrelated inherited work instead of the narrow action a prompt requests — observed directly during this research's own fork probe (Finding 1, probe 5's note), where a first attempt autonomously produced a full report/metadata/issue-log write before a second, forcefully-scoped prompt returned the intended single-line result. **Mitigation**: any future use of `subagent_type: "fork"` for a narrow diagnostic action (as opposed to genuine task continuation) should use explicit negative scoping ("do not write files, do not dispatch further agents, stop after step N") and treat a scope-exceeding fork result as a process hazard worth naming in `core/docs/fork-patterns.md`, not just a one-off mistake.

## Context Extension Recommendations

- **Topic**: harness tool-withholding behavior for native user-interaction primitives.
- **Gap**: nothing in `.claude/context/` currently documents that `AskUserQuestion` (and possibly other native primitives) is categorically withheld from `Agent`-tool dispatches with an explicit `subagent_type`, independent of frontmatter. This is exactly the kind of measured-harness-fact the agent-frontmatter-standard correction (Decision 5) will encode, but a shorter, more discoverable pointer (e.g. in `context/patterns/` alongside `fork-patterns.md`) would help future agent/skill authors avoid re-introducing the same defect class in a new extension.
- **Recommendation**: after the plan/implement phases land the standard's correction, consider a short addendum to `core/docs/fork-patterns.md` itself (which already documents the two fork mechanisms precisely) noting which native tools are withheld from `Agent`-dispatched subagents and pointing at `agent-frontmatter-standard.md`'s corrected section as the canonical statement — this keeps the fact in exactly one place rather than risking a second, drifting copy.

## Appendix

### Search queries / probes used

- `ToolSearch({query: "select:AskUserQuestion", max_results: 5})` — dispatched inside: this agent (`general-research-agent`, no `tools:`), `literature-agent` (explicit `tools:` naming it), `general-purpose` ("All tools"), and `subagent_type: "fork"` (continuation of this agent's own context) — all five returned `No matching deferred tools found`.
- `find agent-system/extensions -path '*/agents/*.md' -type f | wc -l` → 80 (re-measured; description said 76).
- Per-file frontmatter `tools:`/`disallowedTools:` scan via `awk '/^---/{c++; if(c==2) exit} c==1' <file> | grep -q '^tools:'` → `spawn-agent.md`, `literature-agent.md` only.
- `grep -rl 'AskUserQuestion' --include='*.md' agent-system/extensions | grep '/agents/' | wc -l` → 24 (unchanged from description).
- `grep -rl 'AskUserQuestion' --include='SKILL.md' agent-system/extensions | wc -l` → 29 (re-measured; description said 28); same 3 files declare `agent:` (`skill-meta`, `skill-slide-critic`, `skill-slide-planning`).
- `grep -n 'inherits the full\|inherit the full\|Omit to inherit\|Omitting the field' agent-frontmatter-standard.md` → lines 39, 71.
- `grep -rn '^isolation:' agent-system/extensions/*/agents/` → no match (Probe B, re-confirmed).
- `grep -n -i isolation .../skill-orchestrate/SKILL.md` → no match (Probe C, re-confirmed).
- `grep -rln 'dispatch-worktree.sh\|task_selected_for_worktree_isolation' agent-system/` → no match (removal-layer absence, re-confirmed).
- `jq -r '.active_projects[] | select((.file_scope//[])[] | test("batch-orchestration-guardrails"))' specs/state.json` and the `territory.md` equivalent → both return project 311 (`measured_co_scheduling_signal_and_isolation_posture`, `not_started`), confirming the overlap.
- `bash .claude/scripts/validate-state.sh --deep` → re-confirms the coarse `scripts/tests/` warning for project 300 (current overlap set: 170,251,271,273,274,281,282,303,304,313,318,319,335,344,345,347 — drifted from the description's list, as expected).

### References

- `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`
- `agent-system/extensions/core/docs/fork-patterns.md`
- `agent-system/extensions/core/agents/meta-builder-agent.md`
- `agent-system/extensions/core/skills/skill-meta/SKILL.md`
- `agent-system/extensions/present/skills/skill-slide-planning/SKILL.md`
- `agent-system/extensions/present/skills/skill-slide-critic/SKILL.md`
- `agent-system/extensions/present/agents/slide-critic-agent.md`
- `agent-system/extensions/literature/agents/literature-agent.md`
- `agent-system/extensions/core/skills/skill-spawn/SKILL.md`
- `agent-system/extensions/core/skills/skill-fix-it/SKILL.md`
- `specs/decisions/worktree-isolation-removal-verdict.md`, `specs/decisions/worktree-isolation-removal-reaffirmation.md`
- `agent-system/extensions/core/context/contracts/territory.md`, `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
