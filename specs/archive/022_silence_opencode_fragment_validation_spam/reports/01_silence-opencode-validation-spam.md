# Research Report: Task #22

**Task**: 22 - Silence opencode-agents.json fragment validation spam (absorbed: picker Reload
All/Regenerate honesty fix; absorbed: Global Update repo-registration feature)
**Started**: 2026-11-05
**Completed**: 2026-11-05
**Effort**: medium (three largely-independent sub-scopes in one task directory)
**Dependencies**: None blocking; coordinate commit boundaries with the two already-open
concurrent siblings listed in the dispatch's Territory block (unrelated file scopes, no overlap)
**Sources/Inputs**: Codebase read (`lua/neotex/plugins/ai/shared/extensions/merge.lua`,
`lua/neotex/plugins/ai/shared/extensions/init.lua`, `lua/neotex/plugins/ai/claude/commands/picker/init.lua`,
`lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`,
`lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua`,
`agent-system/extensions/*/opencode-agents.json`, `.opencode/**`), `specs/state.json` task-22
description history, `.claude/context/formats/return-metadata-file.md`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The task description is a layered merge of three originally-separate tasks, but only the
  **latest (2026-09-01) revision's 3-item "REVISED SCOPE"** is the currently binding scope for
  the spam/opencode half: (1) silence the `vim.notify` spam, (2) fix one fake-tool line in
  `.opencode/extensions/web/agents/web-implementation-agent.md`, (3) write down the frozen
  policy. All three are still unimplemented as of this research pass — verified by reading the
  live code, not assumed from the description.
- The two absorbed sibling scopes (picker `[Reload All]`/`[Regenerate]` honesty fix, and the
  `Global Update` repo-registration feature) are **also both still fully open** — verified by
  grep/read against the current picker and extension-manager code, which matches the
  description's "VERIFIED CURRENT BEHAVIOUR" section almost exactly.
- One piece of the task's own evidence has **drifted since it was last measured**: the lean
  `opencode-agents.json` fragment's wrong-path bug (defect class 2) was justified by "the correct
  files already exist at `.opencode/agent/subagents/lean-*-agent.md`" — that is no longer true;
  those two files do not exist anywhere under `.opencode/` today, and `.opencode/agent/subagents/`
  now holds only 9 generic agent files, none language-specific. This does not block the binding
  REVISED SCOPE (which does not list fixing the lean path as a requirement at all), but it means
  defect class 2 cannot currently be "fixed" by the previously-prescribed path swap — there is no
  live target to swap to.
- Recommended approach: a 3-phase plan mapped directly onto the three independent scopes
  (spam/opencode, picker honesty, Global Update), each phase touching a disjoint file set, so a
  partial-completion state after any one phase is still coherent and independently acceptance-
  testable.

## Context & Scope

Task 22's description field is the concatenation of (oldest first) an original description, two
in-place revisions of that same original scope, and two absorbed former tasks (45 and 202) each
pasted in verbatim with their own revision history. The newest-dated note at the very top
("STATUS REPAIRED 2026-09-22") is a state-management correction note only — it explains why the
task's status was reset to `not_started` (a prior dispatch wrote nothing) and does not change
scope. The scope-bearing text is:

1. **REVISED 2026-09-01** ("backlog streamline: .opencode declared FROZEN") — binding, current,
   supersedes everything below it for the spam/opencode half of the task. Its own text states it
   "settles the reframed design question" from the 2026-08-24 revision beneath it.
2. The three `=== ABSORBED ===` blocks (task 45, task 202) are each **independent, additive**
   scopes bolted onto this task directory, not revisions of the spam/opencode scope. Their own
   "VERIFIED CURRENT BEHAVIOUR" sections are evidence gathered at absorption time, not binding
   requirements by themselves — the binding requirements are each block's own "ACCEPTANCE"
   section.

This research pass re-verified all three scopes' live evidence against the current tree rather
than trusting the description's point-in-time snapshots, per the task's own repeated "measured
against a live project, not assumed" discipline.

## Findings

### Codebase Patterns

**Scope 1 — opencode spam/frozen-policy (merge.lua)**

- `M.validate_opencode_fragment` (`lua/neotex/plugins/ai/shared/extensions/merge.lua:964-1003`)
  already collects **every** missing `{file:...}` reference per fragment (sorted by agent name
  for determinism) and returns a `missing_by_key` map — this confirms defect class (3) from the
  2026-08-24 revision is genuinely fixed; no further work needed there.
- `M.generate_opencode_json` (`merge.lua:1006` onward) still emits one `vim.notify(..., WARN)`
  **per extension with any skipped agent key**, unconditionally, every time the function runs
  (`merge.lua:1091-1104`). This is the live spam source. It is gated only on the
  `opencode.json.managed` marker file existing (`merge.lua:1026-1028`) — there is **no** gating
  on a "frozen policy" flag or similar; that gate does not exist yet. This confirms REVISED-SCOPE
  item (1) is unimplemented.
- The function is invoked once per resynced extension (consistent with the description's
  "runs once per resynced extension rather than once per reload" observation in the original
  defect-class-3 text, which was about validation reporting, not about this call-frequency
  mechanism — call frequency itself was not re-verified at the call-site level in this pass and
  is worth the planner confirming directly, since it determines whether gating belongs inside
  `generate_opencode_json` (dedupes naturally per call) or needs an additional single
  reload-level dedupe wrapper).
- No existing code path reads or writes anything resembling a ".opencode is frozen" flag/marker.
  Gating "behind the frozen policy" (per REVISED SCOPE item 1's phrasing) is therefore a new
  design decision for the plan, not a flag flip — see Decisions below for the two real options
  the codebase supports today.

**Scope 1 — fake tool line**

- `.opencode/extensions/web/agents/web-implementation-agent.md:57` still reads:
  `` - `browser_verify_text_visible` -- Assert text is visible on page `` — teaching it as a real
  tool.
- The source store already retracts it in two places:
  `agent-system/extensions/web/agents/web-implementation-agent.md:80` ("there is no
  `browser_verify_text_visible` tool") and
  `agent-system/extensions/web/context/project/web/tools/playwright-mcp-guide.md:43` (same
  retraction with a mapping to real tools). This confirms REVISED-SCOPE item (2) is
  unimplemented and the fix target is a single line in `.opencode/extensions/web/agents/web-implementation-agent.md`.
- `.opencode/` is independently git-tracked (its own commit history exists, e.g. "task 157 phase
  6: mirror to .opencode/", "task 27: remove dead .opencode command router") and has **no**
  entry or `source_dir` reference in `.claude-extensions.json` — confirming the task's own claim
  that the source-store/deploy-boundary rule does not apply to `.opencode/**`; it is a
  hand-maintained tree, not a generated deploy artifact of the `.claude/` system.

**Scope 1 — frozen-policy documentation**

- `.opencode/README.md` currently describes `.opencode/` as a live, maintained task-management
  system (full lifecycle diagram, routing tables, checkpoint execution) with no mention that it
  is frozen, unmaintained, or drift-expected. `agent-system/docs/` has zero mentions of
  `.opencode` at all. REVISED-SCOPE item (3) ("record the policy where the next person will
  look") is confirmed unimplemented; `.opencode/README.md` is the natural primary location
  (it is the first file a reader opens), with the nvim extension's own CLAUDE.md section (which
  already documents the `.claude/`-side extension system) a plausible secondary cross-reference
  point if the plan wants one.

**Scope 1 — drifted evidence (defect class 2, lean path bug)**

- `agent-system/extensions/lean/opencode-agents.json` still references
  `{file:.claude/agents/lean-research-agent.md}` and
  `{file:.claude/agents/lean-implementation-agent.md}` — paths that resolve relative to
  whatever project directory `opencode.json` is generated into, not to this repo's own
  `.claude/agents/` (which does happen to contain files of those names, as deploy artifacts of
  the source-store system, but that is a different resolution context).
- The description's claim that the "correct" alternative,
  `.opencode/agent/subagents/lean-research-agent.md` /
  `lean-implementation-agent.md`, "ALREADY EXIST on disk" is **no longer true**:
  `.opencode/agent/subagents/` currently holds exactly 9 files — `code-reviewer-agent.md`,
  `general-implementation-agent.md`, `general-research-agent.md`, `meta-builder-agent.md`,
  `planner-agent.md`, `reviser-agent.md`, `spawn-agent.md`, `synthesis-agent.md`, `README.md` —
  none language-specific (no lean/latex/typst/math/logic/physics/formal files at all). An issue
  was recorded for this drift (`issue-record.sh`, class `stale-task-description`).
- Consequence for scope: the binding REVISED SCOPE's 3-item list does **not** require fixing
  this lean path bug at all (it only requires silencing spam, fixing the fake-tool line, and
  recording the policy). Given the frozen policy's own stated rationale — "under a frozen
  mirror, no path corrections are owed" — this omission reads as intentional, not an oversight:
  the lean path bug is the same class of per-project-deploy-path staleness the frozen policy
  already declares tolerated, just surfaced via a different file than the "missing deploy
  target" framing used for defect class (1). The plan does not need to fix it, but may choose to
  (it is a one-line, low-risk change) without touching the binding acceptance criteria.

**Scope 2 — picker `[Reload All]` / `[Regenerate]` honesty (absorbed former task 202)**

Re-verified against live source, matching the description's own "VERIFIED CURRENT BEHAVIOUR"
section exactly:

- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua:981` still renders
  `[Reload All]`'s one-liner as `"Wipe and reload all loaded extensions"` — still factually wrong
  (it never wipes; confirmed by `init.lua`'s comment at line 271: "manager-level non-destructive
  force-resync... never unloads").
- `[Regenerate]`'s one-liner at `entries.lua:996` ("Wipe and rebuild from the extension
  manifest") remains accurate and unchanged.
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua`'s `define_preview`
  dispatch chain (lines 632-659) still has no branch for `is_reload_all`/`is_regenerate`/
  `entry_type == "special"`; both fall through to the terminal `else` at line 658-659, which
  writes the single line `"Unknown entry type"`. Confirmed still reachable for both entries.
- `preview_help` (`previewer.lua:75-134`, reachable only via the separate `[Keyboard Shortcuts]`
  entry) already carries correct, accurate one-line descriptions for both operations at lines
  124-128 — this is the "real documentation... buried" the description refers to, confirmed
  present and accurate, giving the planner ready-made correct text to lift into a per-entry
  preview branch rather than drafting new wording from scratch.
- `init.lua:159-286` confirms the `[Reload All]` submenu still offers exactly
  `{"Reload All", "Unload All", "Step Through", "Cancel"}` (line 170), and `"Step Through"`
  (lines 180-185) still does nothing but reopen the picker — the dead-choice claim is current.
- `init.lua:110-156` confirms `[Regenerate]` still calls `exts.wipe({project_dir =
  vim.fn.getcwd()})` with a confirmation prompt (lines 116-120) before the destructive
  `vim.fn.delete(..., "rf")` inside `wipe()`.

**Scope 3 — Global Update / repo registration (absorbed former task 45)**

- Grep across `lua/neotex/plugins/ai/` for `"Global Update"`, `"repo registration"`,
  `"register.*repo"`, `"registered_repos"` returned zero matches. This feature does not exist in
  any form yet — fully greenfield within this task's scope. The description's own framing
  ("already-filed, not-yet-started piece of work") is confirmed accurate.
- No existing data structure records "which repos has `<leader>al` loaded extensions into" —
  this is new state the implementation will need to introduce (likely a small JSON file
  alongside the existing extension-system state, written whenever an extension is loaded into a
  project directory other than this one). This research pass did not locate the extension-load
  call site that would need to grow this side-effect; the planner should locate
  `exts.load`'s call sites under the picker before committing to a specific hook point.

### External Resources

Not applicable — this is a self-contained Neovim-config Lua/JSON task with no external
library or API dependency; all relevant knowledge is in the local codebase.

## Decisions

- **Binding scope for the spam/opencode half is the 2026-09-01 REVISED SCOPE's 3 items only.**
  The older "REFRAME around the one live question" text and the three original defect classes
  are historical evidence/reasoning, already resolved by the frozen-policy decision; they are
  not a separate checklist to satisfy.
- **The lean wrong-path bug (defect class 2) is out of the binding acceptance criteria** for this
  task, per the REVISED SCOPE's own text and the drifted-evidence finding above. The plan may
  still choose to normalize it as a low-risk extra (nothing in the binding constraints forbids
  touching `agent-system/extensions/lean/opencode-agents.json`), but it is not required and
  should not be treated as blocking phase-closure if left alone.
- **Gating mechanism for the spam (open design call for the plan, not resolved here)**: the
  codebase supports two natural approaches, neither implemented yet —
  (a) collapse the per-extension WARN spam into a single INFO-level summary notification once
  per `generate_opencode_json` invocation (e.g. "N extension(s) skipped M agent key(s) due to
  frozen .opencode/ deploy gaps — see :messages" or similar), or
  (b) suppress the notification entirely under the frozen policy and rely on the function's
  return value / a `:checkhealth`-style on-demand report instead. Both satisfy "no validation-
  failure spam" without deleting `validate_opencode_fragment` or any fragment, satisfying the
  binding constraint. The plan should pick one and justify it against the "prefer gating...
  over deleting the mechanism" instruction already in the task text.
- **Scope 2 and Scope 3 are independent of Scope 1 and of each other** — distinct files
  (`picker/**` + `shared/extensions/init.lua` for Scope 2/3, `shared/extensions/merge.lua` +
  `.opencode/**` for Scope 1), distinct acceptance criteria, no shared code path. The plan should
  phase them separately so a partial run leaves each phase's own acceptance criteria
  independently checkable.

## Recommendations

1. **Phase 1 — Scope 1 (opencode spam + fake-tool line + policy doc)**: implement the chosen
   gating approach in `generate_opencode_json`/`validate_opencode_fragment`
   (`lua/neotex/plugins/ai/shared/extensions/merge.lua`), fix the one-line fake-tool reference in
   `.opencode/extensions/web/agents/web-implementation-agent.md:57`, and add a frozen-policy
   section to `.opencode/README.md` (and optionally a short cross-reference from this repo's own
   nvim-extension CLAUDE.md section). Verify by reproducing the original symptom: load a project
   with `opencode.json.managed` present, trigger `<leader>al` reload, confirm no WARN spam and
   that `:messages` still shows an honest, non-silent summary if that is the chosen approach.
2. **Phase 2 — Scope 2 (picker honesty)**: fix `entries.lua:981`'s one-liner, add a
   `define_preview` branch (keyed on `is_reload_all`/`is_regenerate` or on `entry_type ==
   "special"` with a per-entry description field — the plan should pick one, per the task's own
   "DECIDE, do not assume" instruction) that renders the already-correct text lifted from
   `preview_help` (`previewer.lua:124-128`), rule on and record the redundancy question (keep
   both / collapse / rename — the task lists three concrete options to weigh), and decide
   "Step Through"'s disposition (implement or remove). Verify by opening `<leader>al` and
   selecting each entry live, per the task's own acceptance note — not by reading the diff alone.
3. **Phase 3 — Scope 3 (Global Update)**: design and implement repo registration (new small
   state file recording which repos have had extensions loaded into them via `<leader>al`) plus
   a `Global Update` picker entry that reloads each registered repo's own loaded-extension set,
   reporting success/failure counts. Coordinate the final entries.lua wording with Phase 2's
   output so all three bulk-operation entries (`Reload All`, `Regenerate`, `Global Update`) read
   as one coherent, non-redundant set, per the task's explicit coordination note.
4. Order phases 1-3 independently; none blocks another. If the plan must sequence them for
   commit-hygiene reasons, Phase 2 before Phase 3 is natural since Phase 3's final entry wording
   depends on Phase 2 having already fixed the other two entries' text.

## Risks & Mitigations

- **Risk**: choosing full suppression (option (b) above) for the spam gate could make a genuine
  future regression (e.g. a *newly* broken, non-frozen-tree reference) silently invisible.
  **Mitigation**: prefer the single-summary-notification option (a), or at minimum retain an
  on-demand way to see the full missing-reference detail (e.g. keep the existing WARN but behind
  a debug/verbose flag) rather than deleting the detail entirely.
- **Risk**: Scope 3 (Global Update) is genuinely greenfield with no existing hook point
  identified in this research pass for where extension-load events should record repo
  registration. **Mitigation**: the plan phase for Scope 3 should budget explicit investigation
  time to locate `exts.load`'s picker-side call sites before committing to an implementation
  shape, rather than assuming the hook point from this report alone.
- **Risk**: three absorbed scopes in one task directory increases the chance a single commit
  accidentally mixes unrelated file sets. **Mitigation**: the phase-per-scope split above keeps
  each phase's file set disjoint (`shared/extensions/merge.lua` + `.opencode/**` vs.
  `claude/commands/picker/**` vs. `claude/commands/picker/**` + `shared/extensions/init.lua`),
  so per-phase commits stay scoped per `git-staging-scope.md`.

## Context Extension Recommendations

- **Topic**: `.opencode/` lifecycle status.
- **Gap**: no existing context file states that `.opencode/` is frozen/unmaintained; a future
  task touching `.opencode/` would have to rediscover this from task 22's own history.
- **Recommendation**: once Phase 1 lands the policy note in `.opencode/README.md`, consider also
  adding a one-line pointer to it from wherever `agent-system/docs/` indexes sibling systems
  (none currently references `.opencode` at all), so the policy is discoverable from the source
  store's own docs tree too, not only from inside `.opencode/` itself.

## Appendix

- Searches/reads performed: `merge.lua` (full `validate_opencode_fragment` +
  `generate_opencode_json`), `picker/init.lua` (lines 110-300), `picker/display/entries.lua`
  (special-entry definitions), `picker/display/previewer.lua` (dispatch chain + `preview_help`),
  grep for `browser_verify_text_visible` across `.opencode/` and `agent-system/`, grep for
  `"Global Update"`/`"registered_repos"` across `lua/neotex/plugins/ai/`, `ls`/`git log` on
  `.opencode/` to confirm git-tracked/no-source-store status, `jq` on `.claude-extensions.json`
  to confirm no `.opencode` entry, directory listing of `.opencode/agent/subagents/` to check the
  lean-agent-file drift claim.
- `specs/state.json` task-22 `description` field (full revision history) was read in full as the
  primary scope source.
