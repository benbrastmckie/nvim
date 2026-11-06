# Research Report: Task #408

**Task**: 408 - Gate the formal extension's mandatory Mathlib-lookup step on an actual Lean target
**Started**: 2026-11-06
**Completed**: 2026-11-06
**Effort**: low
**Dependencies**: Task 359
**Sources/Inputs**: Source store (agent-system/extensions/formal/**), agent-system/extensions/lean/** (preflight/readiness precedent), agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh, specs/state.json, specs/TODO.md
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The unconditional Mathlib-lookup obligation appears at 8 surfaces across 4 agent contracts and
  their 4 skill wrappers in `agent-system/extensions/formal/` (verified present; this repo's
  `.claude-extensions.json` has no `formal` entry and the extension is not currently deployed
  here, which matches the task's own provenance note).
- A mechanically equivalent "is this a Lean target" signal already exists and is load-bearing
  elsewhere in the codebase: `lean-mcp-preflight-check.sh`'s `--dispatch-block` mode gates on
  lakefile presence (never on `task_type`) precisely because, per its own header comment,
  "a per-extension manifest hooks.preflight registration ... cannot reach a non-lean4-typed Lean
  project." The same structural gap applies here: the four formal agents are routed only under
  `task_type` values `formal`, `formal:logic`, `formal:math`, `formal:physics` — never `lean4` —
  so a literal "lean4-routed task_type" check (as worded in the task description) will almost
  never fire for these agents even on a genuine mixed Lean+philosophy task.
- `file_scope` containing a `*.lean` path is independently established prior art:
  `plan-file-scope-harvest.sh` already treats "the harvested array contains at least one
  `*.lean` path" as its trigger condition for a different feature. This gives a second,
  grounded signal beyond task_type.
- The task-173 observation's own mechanism — "ToolSearch returned no match" for the four
  `lean_*` tool names — is the session-level signal for "(b) the lookup tools being registered."
  This requires no new infrastructure; it is exactly what already happened in that dispatch.
- Recommendation: gate on `(file_scope has a *.lean entry) OR (task_type contains "lean")` for
  condition (a), `AND` tool-registration confirmed via `ToolSearch` for condition (b); the step
  is mandatory only when both (a) is true and (b) resolves affirmatively. When either is false,
  skip and log one line in the report (mirroring the existing "Note in report that Mathlib
  lookup was limited" phrasing already used for the tool-failure case) plus a sibling metadata
  field next to the existing `mathlib_lookups_performed`.
- To avoid "one gated and three ungated copies," extract the gate logic into one new shared
  pattern file under `agent-system/extensions/formal/context/patterns/` and have all 8 surfaces
  point to it, rather than duplicating the gate prose 8 times.

## Context & Scope

Researched: the exact wording and line locations of the mandatory Mathlib-lookup obligation at
every surface named in the task description, within the source store (never the deployed
`.claude/` tree, per `rules/source-store-deploy-boundary.md`); existing codebase precedent for
detecting "this task/session has a genuine Lean target" and for detecting "the Lean lookup MCP
tools are registered"; and how those two signals are, or are not, already available to a
dispatched research agent without new plumbing.

Out of scope for this research pass: writing the actual contract edits (that is the
implementation phase's job) and redeployment (`deploy-headless.sh`), which the task description
requires as a post-implementation step.

## Findings

### Codebase Patterns

**Source-store resolution confirmed.** `.claude-extensions.json` has no top-level `source_dir`
and no `formal` entry at all (its `extensions` object lists only `approvals`, `core`, `email`,
`lean`, `literature`, `memory`, `nix`, `nvim`, `sapience`). The `formal` extension is not
currently deployed into this repo's `.claude/` tree (`.claude/agents/logic-research-agent.md`
does not exist here). This matches the task's own migration note: the record was authored
against a different repository's deployed copy and relocated here because every surface it
names resolves only under this repo's source store,
`agent-system/extensions/formal/{agents,skills}/`. All four named agent files and four named
skill files are verified present there:
- `agent-system/extensions/formal/agents/logic-research-agent.md` (385 lines)
- `agent-system/extensions/formal/agents/math-research-agent.md` (384 lines)
- `agent-system/extensions/formal/agents/physics-research-agent.md` (353 lines)
- `agent-system/extensions/formal/agents/formal-research-agent.md` (290 lines)
- `agent-system/extensions/formal/skills/skill-logic-research/SKILL.md`
- `agent-system/extensions/formal/skills/skill-math-research/SKILL.md`
- `agent-system/extensions/formal/skills/skill-physics-research/SKILL.md`
- `agent-system/extensions/formal/skills/skill-formal-research/SKILL.md`

These eight files are exactly `specs/state.json`'s `file_scope` for project 408 (confirmed via
`jq`), so the implementation phase's file list is already pinned and needs no further
discovery.

**Surface-by-surface inventory (source-store line numbers; the task description's line numbers
were measured against a different repo's *deployed* copy and are consistently offset — the
source store runs ~20-25 lines earlier throughout `logic-research-agent.md`, confirming it is
the same logical file after re-deriving against the source store as the dispatch instructs):**

`agents/logic-research-agent.md`:
- L48-57: "Mathlib Lookup MCP Tools" table (4 tools, purpose, rate limit) + L59-63 example
  queries, under `## Allowed Tools`.
- L105-106: Research Strategy Decision Tree item 3, "What Mathlib theorems apply? -> Use
  lean_leansearch, lean_loogle, lean_leanfinder for theorem discovery."
- L118-122: "**Search Priority**" numbered list, item 2 "Mathlib lookup (theorem discovery)".
- L178-182: "**Step 2: Mathlib Lookup (For Theorem Discovery)**" under Stage 3 (Execute Primary
  Searches) — the step itself.
- L196-197: Stage 4 synthesis bullet "Relevant Mathlib theorems (from lookup tools)".
- L219: report template `**Sources/Inputs**` line naming "Mathlib lookup MCP".
- L237-238: report template `### Mathlib Theorems` section under `## Findings`.
- L257-258: report template `## Appendix` bullet "Mathlib lookup results".
- L291: `mathlib_lookups_performed` metadata field in the Stage 6 JSON example.
- L300-308: Stage 7 example return bullet "Used lean_leansearch to find 5 relevant Mathlib
  theorems."
- L343-347: "### MCP Tool Errors" — "When Mathlib lookup tools fail" handling block (already
  conditional on failure, but still implies the step was mandatorily attempted).
- L372: MUST DO closing list, item 8, "Use Mathlib lookup tools for theorem discovery."

`agents/math-research-agent.md` and `agents/physics-research-agent.md` mirror this structure
almost line-for-line (same table at ~L48-57/L62-71, same decision-tree item at ~L112-113, same
Step 2 header at ~L183-187/L177-181, same report-template sections, same
`mathlib_lookups_performed` field, same MUST-DO closing item). `physics-research-agent.md` also
has one unrelated mention — "Mathlib4 integration patterns" at L36, inside a domain-knowledge
bullet, not part of the lookup obligation — which should NOT be touched by this change.

`agents/formal-research-agent.md` (the cross-domain coordinator) has a thinner footprint: the
same MCP tool table at L60-67 (no examples), "Use Mathlib lookup tools" as a bare Stage 3 bullet
at L135, the `**Sources/Inputs**` report-template line at L159, `mathlib_lookups_performed` at
L226, an example-return bullet at L241, and MUST-DO closing item 5 at L280. It has no decision
tree, no "Step 2" header, and no `### Mathlib Theorems` report section of its own (it uses
`### {Domain N} Findings` instead) — consistent with it delegating actual lookup work to the
three domain specialists it routes to.

The four `SKILL.md` files restate the obligation exactly once each, in narrative "the subagent
will ..." prose inside the Required Tool Invocation section (not a MUST-DO numbered list):
`skill-logic-research/SKILL.md:110` and `skill-math-research/SKILL.md:92` additionally echo it a
second time in their own example-return bullet ("Used Mathlib lookup tools to discover relevant
theorems" at `skill-logic-research/SKILL.md:172` and `skill-math-research/SKILL.md:154`);
`skill-physics-research/SKILL.md:92` and `skill-formal-research/SKILL.md:93` have the single
narrative mention only.

**Existing precedent for signal (a) — "has a Lean target":**
`agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh` already solves a structurally
identical problem for a different purpose. Its header comment (L17-20, L454-461 of the caller
`orchestrate-build-dispatch.sh`) states explicitly: its `--dispatch-block` mode is called
*unconditionally* from the dispatch builder, "rather than gated on task_type," because "a
per-extension manifest hooks.preflight registration is resolved by task_type, so it
structurally cannot reach a Lean project whose task_type is declared by a DIFFERENT extension
(e.g. 'formal')." Its own detection is lakefile presence (`lakefile.lean`/`lakefile.toml` at CWD
or git root), not `task_type`. This is the exact gap the task-408 description's literal
"lean4-routed task_type" wording would walk back into if implemented naively: these four
agents are dispatched only under `task_type` `formal`/`formal:logic`/`formal:math`/
`formal:physics`, so a check for `task_type == "lean4"` (or similarly lean4-specific) would
almost never be true for them, even for a task that genuinely touches `.lean` files alongside
philosophy/math prose.

**Existing precedent for signal (a), alternative form — `file_scope` containing `*.lean`:**
`agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` (L67) already uses "the
harvested array contains at least one `*.lean` path" as a trigger condition for an unrelated
feature (generated-surface harvesting). This confirms `file_scope`-scanning for `.lean` paths is
an established, non-novel detection idiom in this codebase, not something being invented here.
However, `orchestrate-build-dispatch.sh` does **not** currently echo the *current* task's own
`file_scope` into the dispatch file it builds (grep confirms the only `file_scope` mentions in
that script concern *sibling* tasks' territory, for the Territory block) — only
`specs/state.json`'s `active_projects[].file_scope` carries it. A research agent wanting to
check its own task's `file_scope` would need to read it from `specs/state.json` (e.g.
`jq --arg n "$TASK_NUMBER" '.active_projects[] | select(.project_number==($n|tonumber)) |
.file_scope'`), not from the dispatch file alone. (Field name confirmed as `project_number`,
not `task_number`, in the live schema.)

**Existing precedent for signal (b) — "tools registered in the session":** the task-173
observation that motivated this task already describes the exact, pre-existing mechanism:
"ToolSearch returned no match for them." No new infrastructure is needed for this signal — it
is a single `ToolSearch` call (e.g. `select:lean_leansearch,lean_loogle,lean_leanfinder,
lean_local_search`) made once before Step 2, with an empty/no-match result meaning "not
registered."

**Degraded-mode framing precedent.** `lean-mcp-preflight-check.sh`'s `emit_dispatch_block()`
explicitly frames "Lean work without lean-lsp" as "an accepted degraded mode (compiled probes
remain available)," never an error. The same framing fits this gate: when a genuine Lean target
exists but the tools are not registered, that is a degraded-but-accepted mode (skip-and-log),
not a failure — i.e., condition (b) failing should produce the same skip-and-log outcome as
condition (a) failing, not a `partial` status or an error. This matches the task description's
own framing ("and/or ... emit a one-line log when the step is skipped for either reason").

**No existing gate pattern to reuse as-is.** A search of `agent-system/extensions/*/agents/` and
`*/skills/` for existing "skip-and-log a conditional step" prose, and of
`agent-system/extensions/core/context/patterns/` for a generically named gating pattern,
returned nothing closer than `mcp-tool-recovery.md` — which addresses recovering *after* a tool
call fails mid-use, not deciding *whether to attempt* the call at all. This is a genuinely new,
small pattern, not a mis-filed duplicate of something that already exists.

**Territory and duplicate-check already done.** The dispatch file's Territory block lists five
concurrent siblings (464, 465, 466, 478, 489), none touching any of this task's 8 files. The
task description itself records a hand-declared edge against a separate lint-curated-array
record (same four agent files, different bullet: a bounded-wait pair) and a duplicate check
against three Mathlib-adjacent records, all correctly rejected as non-candidates. No further
duplicate-check action is needed from this research pass.

### External Resources

Not applicable — this is a self-contained contract-text change confined to the source store;
no external documentation or literature bears on it.

## Recommendations

1. **Gate definition** (apply uniformly at all 8 surfaces, via the shared pattern file in
   recommendation 2): the Mathlib-lookup step is mandatory only when BOTH of the following hold;
   otherwise skip it and log one line.
   - **(a) Lean-target signal** — true when EITHER: the task's `file_scope` (read from
     `specs/state.json`'s `active_projects[].file_scope`, matched by `project_number`) contains
     at least one `*.lean` path, OR the task's `task_type` (from the delegation context's
     `task_context.task_type`) names the `lean4` extension's routing value. Do not phrase this
     as a bare `task_type == "lean4"` check without the `file_scope` alternative — per the
     Findings above, these four agents never actually see `task_type: "lean4"`, so the
     `file_scope` check is the one that will actually fire in practice for a mixed Lean+formal
     task.
   - **(b) Tool-registration signal** — true when a `ToolSearch` call for the four tool names
     (`lean_leansearch`, `lean_loogle`, `lean_leanfinder`, `lean_local_search`) returns at least
     one match. Make this call once, before attempting Step 2, not after a failure.
   - When (a) is false: skip unconditionally regardless of (b) — there is no point querying
     Mathlib for a task with no Lean target even if the tools happen to be registered in the
     session for an unrelated reason.
   - When (a) is true but (b) is false: skip as an accepted degraded mode (mirroring
     `lean-mcp-preflight-check.sh`'s framing), not as a `partial`-status failure.
   - When both are true: the step remains mandatory, unchanged from today.

2. **Extract one shared pattern file** rather than editing 8 near-identical prose blocks
   independently. Create `agent-system/extensions/formal/context/patterns/mathlib-lookup-gate.md`
   (new directory; the extension currently has no `context/patterns/` tier) stating the gate
   definition from recommendation 1, the skip-log wording from recommendation 3, and the
   `mathlib_lookups_performed`-sibling metadata field from recommendation 4 — one source of
   truth. Have each of the 4 agent `.md` files replace their "Mathlib Lookup MCP Tools" section
   intro and their "Step 2"/decision-tree/MUST-DO-list wording with a short pointer to this new
   file plus the domain-specific residue (the per-domain example queries, which should stay
   inline since they differ by domain). Have each of the 4 `SKILL.md` files' single narrative
   mention gain the same pointer. This directly addresses the task description's own concern —
   "so the extension does not end up with one gated and three ungated copies of the same step."
3. **Skip-log wording**: when the gate resolves to skip, the agent should record exactly one line
   in the research report, in the same place and register as the existing tool-*failure*
   handling already uses ("Note in report that Mathlib lookup was limited") — e.g. "Mathlib
   lookup skipped: no Lean target in file_scope and lean4-routed task_type absent" or "Mathlib
   lookup skipped: lookup tools not registered in this session (ToolSearch: no match)." This
   reuses an existing convention rather than inventing a new logging channel, and keeps the
   per-dispatch `issue-record.sh` call (already mandatory for every dispatch via the Issue Log
   section) free for genuine issues/wins rather than conflating it with routine, expected gate
   outcomes.
4. **Metadata**: add one boolean/string sibling field next to the existing
   `mathlib_lookups_performed` in the Stage 6 JSON example of all 4 agent contracts (e.g.
   `"mathlib_lookup_gated": "skipped_no_lean_target" | "skipped_tools_unregistered" |
   "performed"`), so a skip is machine-visible in `.return-meta.json`, not only in report prose.
   `mathlib_lookups_performed` should read `0` (not be omitted) when skipped, consistent with its
   existing integer type.
5. **Leave the physics-specific "Mathlib4 integration patterns" domain-knowledge bullet
   (`physics-research-agent.md:36`) untouched** — it is unrelated context-loading guidance, not
   part of the lookup-step obligation, and gating it would be a scope overreach beyond what the
   task description asks for.
6. **Redeploy note for the implementation phase**: because `formal` is not currently an active
   extension in this repo's `.claude-extensions.json`, the task description's required
   `deploy-headless.sh` run to `RESULT=landed_verify_clean` will exercise the repo's *currently
   active* extensions' deploy path as general hygiene verification — it will not itself deploy
   `formal` into `.claude/` here (there is no entry to deploy). This is expected and not a
   blocker; it does not change what the implementation phase edits in the source store.

## Decisions

- Treat the task description's literal "(a) ... a .lean path in file_scope, or a lean4-routed
  task_type" as an OR of two sub-signals (file_scope-based and task_type-based), per its own
  wording, rather than collapsing it to task_type alone — the Findings above show the
  file_scope sub-signal is the one that will actually matter for these four agents in practice.
- Recommend a NEW shared pattern file (`context/patterns/mathlib-lookup-gate.md`) rather than
  duplicating the gate prose at all 8 surfaces, directly to satisfy the task description's own
  "does not end up with one gated and three ungated copies" instruction.
- Treat condition (b) failing (tools unregistered) as a skip-and-log outcome, never a `partial`
  status, mirroring the lean extension's own "accepted degraded mode" framing for the structurally
  analogous Lean-without-lean-lsp case.
- Scope the change to exactly the 8 files already pinned in `specs/state.json`'s `file_scope`
  for this task; `physics-research-agent.md`'s unrelated "Mathlib4 integration patterns" mention
  is explicitly out of scope.

## Risks & Mitigations

- **Risk**: a naive implementation checks only `task_type == "lean4"` for condition (a), which
  will never be true for these four formal agents (they are routed under `formal*` task types
  only), silently making the "and/or" gate behave as if condition (a) is always false and the
  step is gated solely on tool registration. **Mitigation**: implement the `file_scope`
  `*.lean`-path check as the primary, actually-firing form of condition (a); state this
  explicitly in the plan so it isn't lost.
- **Risk**: duplicating the new gate prose across 8 files independently produces drift (exactly
  the "one gated, three ungated" failure mode this task exists to prevent, recurring one level
  down). **Mitigation**: the shared-pattern-file extraction in Recommendation 2.
- **Risk**: a research agent cannot read its own task's `file_scope` from the dispatch file
  alone (confirmed: `orchestrate-build-dispatch.sh` only echoes *sibling* tasks' `file_scope`,
  for Territory purposes). **Mitigation**: the plan must instruct a direct
  `specs/state.json` read, matched by `project_number` (not `task_number` — confirmed field name
  in the live schema), as part of the gate-check procedure.
- **Risk**: conflating a routine, expected gate-skip with the dispatch-level Issue Log
  (`issue-record.sh`), which is meant for genuine deviations/wins. **Mitigation**: Recommendation
  3 keeps the skip-log in report prose plus a metadata field, not the issue log.

## Appendix

- Search queries / commands used: `jq '.extensions.formal.source_dir' .claude-extensions.json`;
  `jq '.extensions | keys'`; `grep -n -i "mathlib\|lean_leansearch\|lean_loogle\|
  lean_leanfinder\|lean_local_search\|mathlib_lookups_performed"` across all 8 target files;
  `grep -rn "lean target\|lean4-routed\|has_lean_target\|lean_target"`;
  `grep -n "file_scope\|task_type" agent-system/extensions/core/scripts/
  orchestrate-build-dispatch.sh`; `jq -r '.active_projects[] | select(.project_number==408)'
  specs/state.json`; `diff` of deployed vs. source-store `logic-research-agent.md` excerpt
  (confirmed `formal` not deployed here).
- Files read in full: `agents/logic-research-agent.md`, `agents/formal-research-agent.md`,
  `lean-mcp-preflight-check.sh`, `mcp-fallback-table.md`, `mcp-tool-recovery.md`,
  `delegation-context.md`.
- Files grepped/partially read: `agents/math-research-agent.md`,
  `agents/physics-research-agent.md`, all 4 `SKILL.md` files, `manifest.json`
  (`agent-system/extensions/formal/`), `backfill-file-scope.sh`, `plan-file-scope-harvest.sh`.
