# Research Report: Task #482

**Task**: 482 - Create sapience extension
**Started**: 2026-11-04T00:00:00Z
**Completed**: 2026-11-04T00:00:00Z
**Effort**: medium (file-authoring only; no new scripts beyond one cheap hook)
**Dependencies**: None (core extension only)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/memory/`, `agent-system/extensions/approvals/`,
  `agent-system/extensions/literature/`, `agent-system/extensions/nvim/`,
  `agent-system/extensions/nix/`, `agent-system/extensions/lean/`,
  `agent-system/extensions/core/scripts/skill-base.sh`,
  `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`,
  `agent-system/extensions/core/docs/guides/creating-extensions.md`,
  `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`,
  `agent-system/extensions/core/agents/general-implementation-agent.md`
- Machine configuration: `~/.sapience/mcp.py`, `~/.sapience/upload.py`,
  `~/.dotfiles/config/claude/settings.json`, `~/.claude.json`, `~/.dotfiles/docs/sapience.md`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Gap 1 (missing write-tool permission grants) is real and closeable exactly as scoped, but the
  fix as specified is **repository-scoped, not machine-wide** — this is a real tradeoff that
  should be named explicitly, not left implicit (see Decisions and Risks).
- Gap 2 (postflight wrapup) is closeable purely as documentation in `EXTENSION.md` (merged into
  `.claude/CLAUDE.md`, which this very research dispatch's own system prompt proves is injected
  into every agent dispatch, subagents included) — no script or hook is needed.
- **Gap 3 as literally specified cannot work.** The manifest `hooks.context_injection`
  mechanism the dispatch names is resolved by `skill_get_extension_dir()` via exact string
  equality between the *current dispatched task's* `task_type` and a single extension's
  declared `task_type`. Verified by direct code reading (`skill-base.sh` lines ~160-260): the
  resolver returns **one** extension (first match, not "all loaded extensions"), and only when
  that extension's own `task_type` field equals the task's. Since non-goal (a) forbids
  `sapience` from declaring a `task_type` (correctly — it is not an implementable domain), and
  no task will ever be created with `task_type: "sapience"`, this hook can **never fire for any
  task, of any type, ever** — not "fires only for sapience tasks" (which would already be
  useless), but structurally unreachable under every task type the system has. This directly
  contradicts the dispatch's framing that the nvim/nix extensions "already exercise" the
  mechanism sapience needs: they exercise it successfully precisely *because* they each declare
  their own matching `task_type` (`nvim`, `nix`) and fire only on their own domain's tasks — a
  narrow, single-domain use the cross-cutting "every dispatch" goal for sapience does not share.
- The one existing cross-cutting, task-type-independent injection mechanism in this codebase
  (`<memory-context>` block injection, visible verbatim in this dispatch's own prompt) is **not**
  implemented through the generic extension-hook system at all — it is a bespoke, hardcoded call
  to `memory-retrieve.sh` inside core's own `orchestrate-build-dispatch.sh`. Replicating that
  shape for sapience would mean editing a shared core script, which is a materially bigger and
  differently-scoped change than "add a manifest hooks entry," and the dispatch's explicit
  anti-goal ("DO NOT ADD A SECOND PER-DISPATCH RETRIEVAL INJECTION") argues directly against
  building that second always-on, per-dispatch path for sapience in the first place.
- Recommended resolution for gap 3 (see Decisions/Recommendations): do not attempt a
  per-dispatch wiring at all. Document the orientation story as session-level only
  (SessionStart `--briefing-text`, already ambient, root session only) plus an on-demand
  `sf1`/`/v1/ask` escape hatch an agent can reach for explicitly when it needs cross-session
  recall mid-task — this is consistent with the dispatch's own "weakest case; sequence last"
  framing and its explicit anti-goal, and requires no code change at all, only documentation.

## Context & Scope

Scope was to research how to close three gaps (permission grants, postflight knowledge capture,
subagent orientation) blocking a sapience extension modeled on `agent-system/extensions/memory/`,
by reading the actual mechanisms involved rather than assuming the dispatch's prescriptions are
mechanically correct. All three gaps and the four non-goals named in the dispatch were checked
against the live code, not just the dispatch's own prose.

## Findings

### Codebase Patterns

**Extension shape without `task_type`/`routing_agents`** (needed for non-goal a): two existing
extensions already have this exact shape and are the correct models, not `memory/`:
- `approvals/manifest.json` — `routing_exempt: true`, no `task_type`, no `routing_agents`,
  `merge_targets` for `claudemd` + `index` only (no `settings` merge target — it has no
  `settings-fragment.json`).
- `literature/manifest.json` — same shape, slightly larger `provides.scripts`.

`memory/manifest.json` is the wrong top-level model for sapience: it declares
`"task_type": "memory"` and a full `routing_agents` block, both explicitly forbidden by non-goal
(a). Use `memory/` only for the *merge-target* and *directory-layout* pattern (EXTENSION.md →
CLAUDE.md section, index-entries.json → context/index.json, context/project/{name}/), not for
its top-level routing fields.

**`settings-fragment.json` shapes observed** across all nine extensions that declare one:
`web`/`present`/`nix` use `{"permissions":{"allow":[...]}}`; `lean` uses a wildcard
(`"mcp__lean-lsp__*"`); `email` uses `{"permissions":{"deny":[...]}}` plus a `hooks.PreToolUse`
block; `memory`'s own fragment declares an `mcpServers` block (`obsidian-memory`) — this is
stale/dead precedent per the finding below and must NOT be copied. `founder`/`filetypes` are
empty `{}`. The correct model for sapience's `settings-fragment.json` is `nix`'s or `web`'s shape:
`{"permissions":{"allow":[...]}}`, nothing else.

**Gap 1 — exact current permission state** (read from
`~/.dotfiles/config/claude/settings.json`, lines 58-64, and the live tool registry in
`~/.sapience/mcp.py` lines ~1208-1230):
- Granted today (7 entries): `mcp__sapience__sapience` (dead — see below),
  `mcp__sapience__sapience_search`, `_briefing`, `_context`, `_ask`, `_outstanding`, `_papers`.
- The MCP server exposes 12 tools total: the 6 above (minus the dead entry) plus `sapience_remember`,
  `sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`, `sapience_connect`, `sapience_join`.
- `mcp__sapience__sapience` (no trailing tool-name suffix) matches **nothing**: every real tool
  is registered as `mcp__sapience__sapience_<verb>` (confirmed against `mcp.py`'s own
  `TOOLS`/dispatch list), so this entry is dead weight in the existing dotfiles list. It lives in
  a different repository (`~/.dotfiles`) and is out of scope for this task to fix, but should be
  named as an observation.
- The dispatch's named gap (4 missing write tools: `sapience_remember`, `sapience_wrapup`,
  `sapience_handoff`, `sapience_adddoc`) is confirmed accurate. Two additional tools
  (`sapience_connect`, `sapience_join` — sharing/connect-code flows) are also ungranted but were
  not named in the dispatch's gap framing and are out of scope for this extension's stated
  purpose (no connect/sharing workflow is part of this task).

**Gap 1 — registration-vs-permission scope mismatch** (read from
`context/patterns/mcp-server-ownership.md`, "Grant permissions at the same scope where the
server is registered"): sapience is registered at **user scope**
(`~/.claude.json` top-level `mcpServers.sapience`, written by the nix module's activation). The
canonical rule in this codebase is that a user-scope-registered server's permission grant
belongs in **user-scope** `~/.claude/settings.json` (worked examples: `lean-lsp`, `playwright`).
The dispatch instead directs the grant into this repository's own
`settings-fragment.json` → `.claude/settings.local.json` (**project scope**), explicitly to
dodge the home-manager-enforced-key problem on `~/.claude/settings.json`. This is a deliberate,
reasoned tradeoff (editing `~/.dotfiles` is a different repository, out of this task's scope, and
a direct edit to the enforced file would be reverted on the next `home-manager switch` regardless)
— but it has a real, nameable consequence: **the fix only helps agent dispatches inside this
`nvim` config repository.** A sapience session in any *other* project on this machine will still
hit an interactive permission prompt on the four write tools (and the deny-by-prompt that implies
in a headless run), because that other project's `.claude/settings.local.json` never receives
this grant. This is the correct scope for *this task*, but the dispatch should not be read as
"fixes gap 1" in the fully general sense — only "fixes gap 1 for autonomous dispatches inside
this repository," which is in fact everything this task's own blocker (`/orchestrate` dispatches
in this repo) needs.

**Gap 2 — where the fix actually lives**: `general-implementation-agent.md` creates the
completion summary artifact at its own Stage 6 (`specs/{NNN}_{SLUG}/summaries/...`), immediately
before Stage 7's metadata write that drives the `[IMPLEMENTING]` → `[COMPLETED]` transition.
`EXTENSION.md` merges into `.claude/CLAUDE.md` at a fixed `section_id`
(`merge_targets.claudemd.section_id`), and this merged CLAUDE.md content is demonstrably loaded
ambiently into every agent's own prompt — this very dispatch's system prompt contains both
`CLAUDE.md` files verbatim, confirming subagents see it too, not just the root session. This
means GAP 2 needs **no new script and no new hook**: a short, explicit instruction in
`EXTENSION.md` ("at the `[IMPLEMENTING]` → `[COMPLETED]` transition, call `sapience_wrapup` with
3-8 distilled notes drawn from the summary artifact you just wrote") is sufficient, mirroring how
the memory extension documents (rather than mechanically enforces) `/todo`'s harvest step. The
dispatch's explicit scoping-out of a per-agent proactive-`sapience_remember` instruction is
correct and should stay: `sapience_wrapup`/`sapience_remember` both write straight to the hosted
vault (see Gap 2/review-gate finding below), so a per-dispatch instruction would flood the vault
across an `/orchestrate` batch exactly as the dispatch warns.

**Gap 2 — the review-gate boundary, confirmed from `~/.dotfiles/docs/sapience.md`**: this
machine's `config.json` sets `auto_approve: false`, so findings from the *transcript-extraction*
pipeline (`sapience sync` / `coverage` / `pending` / `review`, i.e. `upload.py`) stage locally and
require an explicit `sapience review` before anything uploads. This gate applies **only** to that
extraction path. `sapience_remember`/`sapience_wrapup`/`sapience_handoff`/`sapience_adddoc`,
called via MCP, write straight to the hosted vault with no staging and no review step — confirmed
directly from each tool's own description string in `mcp.py` (`sapience_wrapup`: "Each is saved
to the user's persistent cross-session memory... the next session starts from what this one
concluded" — no mention of staging). This boundary (staged-and-reviewed vs. direct-and-unreviewed)
is exactly the content the dispatch asks `context/project/sapience/` to document, and is the
reason the postflight-only, 3-8-notes-per-task scoping in gap 2 matters: it bounds how much
unreviewed content autonomous orchestration can push to the hosted vault per task, rather than
per tool call.

**Gap 2 — transcript-filter ceiling, confirmed from `~/.sapience/upload.py`**:
`source_skip()` (lines ~93-110) classifies a transcript as `'subagent'` by path
(`subagents/` in its parent path, or filename starting with `agent-`) or as `'harness-started'`
by reading its opening human turns — both final/cached classifications that are never revisited
once set, and the `'harness-started'` rule is explicitly documented (upload.py line ~300) as NOT
overridable by `SAPIENCE_INCLUDE_HEADLESS=1`. This confirms the dispatch's 1013/203 measurement is
architecturally expected, not anomalous: any transcript whose session is `/orchestrate`-dispatched
(the normal case in this repo) is filtered from extraction permanently, by design, regardless of
env vars — reinforcing that an explicit MCP tool call during (or at the end of) the run is the
*only* path into the vault for orchestrated work.

**Gap 3 — the hook-resolution mechanism, read in full from `skill-base.sh`**:
`skill_get_extension_dir(task_type)` loops over every *active* extension, but returns on the
**first** whose own manifest `task_type` string-equals the argument; it is not a "run every
active extension" loop. `skill_run_extension_hook()` is called from exactly four sites
(`skill_preflight_update`, `skill_context_injection`, `command-gate-out.sh`'s verification call,
`skill_postflight_update`), and every one of them passes the *current task's own* `TASK_TYPE` as
that argument — never a loop over all loaded extensions' own declared types. This is confirmed
further by `creating-extensions.md`'s own "Post-Task Observers" section, which exists
*specifically because* lifecycle hooks cannot express "fire for every task regardless of its own
`task_type`" — observers were built as a **separate** mechanism (matched on `topic` and/or
`task_type`, resolve-ALL across every loaded extension) precisely to cover the case lifecycle
hooks cannot. Even observers are the wrong shape here regardless: they fire only from
`orchestrate-cycle-postflight.sh`, i.e. **after** a task reaches a resting state — never before or
during agent delegation, so they could not deliver a pre-work subagent briefing even if the
task_type-matching problem were somehow solved.
`nvim-context.sh`/`nix-context.sh` are real, working examples of this hook firing — but only
because `nvim`/`nix` each declare `task_type: "nvim"`/`"nix"` and their hook fires *only when a
task of that exact type is dispatched*. There is no task type sapience could declare that would
ever be assigned to a task (since, correctly per non-goal a, no task is "a sapience task"), so
this mechanism is categorically unavailable to sapience, independent of what task happens to be
running.

**Gap 3 — the one cross-cutting precedent, and why it does not transfer**: the `<memory-context>`
block visible verbatim at the top of this very dispatch is real evidence that *some* mechanism in
this codebase injects content into every dispatch regardless of task type. Tracing it
(`orchestrate-build-dispatch.sh` lines ~337-342, ~710-711) shows it is a **direct, hardcoded call**
to `.claude/scripts/memory-retrieve.sh` written into core's own dispatch-building script — not a
manifest-driven extension hook, and not something an extension's own files can add without
editing a shared core script. Building sapience's equivalent this way would require: (a) editing
`orchestrate-build-dispatch.sh` (a core file, a materially different and larger change than "add a
`context_injection` hook" would be), and (b) a network round-trip (`sf1`/`/v1/ask`, since `mcp.py`
has no `--search`/`--ask` CLI mode) on every single dispatch in every batch — exactly the
"second per-dispatch retrieval injection" the dispatch's own anti-goal explicitly forbids.

### External Resources

No external web research was needed; this task is entirely about this codebase's own extension
mechanism and this machine's own sapience installation, both of which were read directly.

## Decisions

- **Model the manifest on `approvals/`/`literature/`, not `memory/`**, for the top-level fields:
  no `task_type`, no `routing_agents`, `routing_exempt: true` (matches the two existing
  no-domain extensions' own convention), `merge_targets` for `claudemd` + `index` + `settings`.
- **`settings-fragment.json` carries `permissions.allow` only** — model on `nix`/`web`'s shape,
  never `memory`'s stale `mcpServers` block, and never any `mcpServers` key at all (per the task
  29 constraint the dispatch names). List the four missing write tools explicitly
  (`mcp__sapience__sapience_remember`, `_wrapup`, `_handoff`, `_adddoc`) rather than a
  `mcp__sapience__*` wildcard, matching the existing dotfiles list's own explicit, one-tool-per-
  line convention rather than introducing a wildcard precedent this list does not otherwise use.
- **Accept gap 1's fix as repository-scoped**, not machine-wide, as a deliberate, documented
  tradeoff (see Findings) — not an oversight to silently fix by also editing `~/.dotfiles`, which
  is out of this task's scope.
- **Gap 2 is a documentation-only fix**: an `EXTENSION.md` instruction at the
  `[IMPLEMENTING]` → `[COMPLETED]` transition to call `sapience_wrapup` with 3-8 notes drawn from
  the just-written summary artifact. No new script, no new hook.
- **Gap 3, as the dispatch's prescribed mechanism (`hooks.context_injection`), cannot be
  implemented as specified** — it is not merely weak, it is structurally unreachable under the
  non-goal (a) constraint the same dispatch imposes. Recommend the plan phase drop the
  manifest-hook approach for gap 3 entirely rather than attempt to ship dead code, and instead
  document (in `context/project/sapience/`) that subagent orientation is intentionally
  session-level-only (root-session `SessionStart` briefing) plus an on-demand, explicitly-invoked
  `sf1 "question"` escape hatch — consistent with the dispatch's own "weakest case" framing and
  its anti-goal against a second always-on injection path. This is a text-only resolution: no
  script, no hook, no manifest `hooks` object at all for sapience.

## Recommendations

1. `manifest.json`: `name: "sapience"`, no `task_type`, no `routing_agents`, `routing_exempt:
   true`, `dependencies: ["core"]`, `provides.commands: []`, `provides.skills: []`,
   `provides.context: ["project/sapience"]`, `provides.scripts: []` (no gap-3 hook script to
   deploy, per the Decisions above), `merge_targets` for `claudemd`/`index`/`settings` exactly
   like `memory/`'s three (never add a `settings` merge target pointing anywhere but
   `.claude/settings.local.json`, and never add an `mcpServers` key anywhere in this file).
2. `EXTENSION.md`: model structure on `memory/EXTENSION.md` (short prose + a small table), merged
   at `section_id: extension_sapience`. Content: what sapience is (one line, pointing at
   `~/.dotfiles/docs/sapience.md` for machine config, never duplicating it); the three
   already-ambient hooks and seven already-ambient read grants (explicitly: do not re-register,
   do not re-grant); the gap-2 instruction (3-8 `sapience_wrapup` notes at the `[IMPLEMENTING]` →
   `[COMPLETED]` transition, sourced from the summary artifact); and an explicit statement that
   this extension provides no task type, no routing, and no slash command (the three terminal
   verbs — review/coverage/pending/stats — are already covered by the GNOME desktop launchers).
3. `index-entries.json`: model on `memory/index-entries.json`'s shape; entries under
   `project/sapience/` for the README and each domain note, `load_when` scoped narrowly (this is
   reference material, not something every dispatch needs eagerly — consistent with the
   dispatch's "Context Pointers... read-on-demand" convention used elsewhere in this CLAUDE.md
   for the email/lit/memory extensions).
4. `settings-fragment.json`:
   ```json
   {
     "permissions": {
       "allow": [
         "mcp__sapience__sapience_remember",
         "mcp__sapience__sapience_wrapup",
         "mcp__sapience__sapience_handoff",
         "mcp__sapience__sapience_adddoc"
       ]
     }
   }
   ```
5. `context/project/sapience/README.md` + domain notes: cover (a) the vault model
   (hosted at app.spnc.ai, MCP thin client, local `sf1`/`sapience` CLI, no `--search`/`--ask` CLI
   mode in `mcp.py`); (b) the review-gate boundary (staged-and-reviewed `sapience sync`/`review`
   extraction path vs. direct-and-unreviewed MCP write tools — the exact distinction surfaced in
   Findings above); (c) the transcript-filter ceiling (`source_skip()`'s permanent
   `subagent`/`harness-started` classification, immune to `SAPIENCE_INCLUDE_HEADLESS=1`, and why
   that makes an explicit tool call the only path in for orchestrated work); and (d) — new,
   surfaced by this research, not in the dispatch's own list — why no per-dispatch
   context-injection hook exists for sapience and what the deliberate alternative is (session-level
   briefing + on-demand `sf1`, no code).
6. **Do not** write `scripts/sapience-context.sh` or declare a `hooks.context_injection` entry.
   The dispatch's gap-3 deliverable item ("scripts/sapience-context.sh (the gap 3 hook)") should
   be dropped at plan time per the Decisions above, with the rationale recorded in the domain
   notes rather than silently omitted.

## Risks & Mitigations

- **Risk**: a future reader assumes gap 1 is fully closed machine-wide. **Mitigation**: state the
  repository-scoped tradeoff explicitly in `EXTENSION.md` and/or the domain notes, pointing at
  `~/.dotfiles/config/claude/settings.json` as the file that would need the same four entries
  added for machine-wide coverage, as a deliberately out-of-scope follow-up rather than a silent
  gap.
- **Risk**: a future edit to this extension (or a different task) re-attempts the gap-3 hook
  mechanism without re-deriving why it cannot work, because the dispatch's own prose made it sound
  achievable ("the mechanism already exercised by the nix and nvim extensions"). **Mitigation**:
  record the specific code citation (`skill_get_extension_dir`'s first-match-on-`task_type`
  resolution, `skill-base.sh`) in the domain notes so the refutation is checkable, not just
  asserted.
- **Risk**: listing the four write-tool grants explicitly (rather than a wildcard) means a future
  new write tool sapience ships is not auto-granted. **Mitigation**: this is the same tradeoff the
  existing 7-entry dotfiles list already makes (explicit, not wildcarded), so it is consistency
  with precedent, not a new risk introduced by this extension; note it in the domain notes so a
  future tool addition is a known, not surprising, maintenance item.

## Context Extension Recommendations

- **Topic**: cross-cutting (task-type-independent) pre-dispatch context injection.
- **Gap**: `creating-extensions.md` documents Lifecycle Hooks and Post-Task Observers as the two
  extension-declared injection seams, but neither can express "run before every dispatch
  regardless of the dispatched task's own `task_type`" — the only existing instance of that shape
  (`memory-context`) is a hardcoded core-script call, not a documented, reusable extension
  mechanism.
- **Recommendation**: if a future extension needs this shape again (sapience is the second
  candidate after memory), consider documenting a third, explicit "always-run injection" seam in
  `creating-extensions.md` rather than requiring each case to hand-edit
  `orchestrate-build-dispatch.sh`. Out of scope for this task — noted for a possible separate
  core-extension task, not an action item here.

## Appendix

### Search queries / investigation steps used
- Enumerated all extension manifests for `task_type`/`routing_agents` presence to find the
  correct no-domain model (`approvals`, `literature`).
- Enumerated every existing `settings-fragment.json` to find the correct `permissions.allow`-only
  shape and rule out the stale `mcpServers` precedent in `memory/`.
- Read `~/.dotfiles/config/claude/settings.json` directly for the current 7-entry
  `mcp__sapience__*` allow-list and the three existing hook commands.
- Read `~/.claude.json`'s `mcpServers.sapience` entry to confirm user-scope registration.
- Read `~/.sapience/mcp.py`'s full tool table (`TOOLS`/dispatch block, lines ~1208-1404) to
  enumerate all 12 real tool names and their descriptions (review-gate and bypass language is
  quoted directly from tool descriptions, not paraphrased).
- Read `~/.sapience/upload.py`'s `source_skip()` (lines ~65-110, ~300) for the transcript-filter
  mechanics and the `SAPIENCE_INCLUDE_HEADLESS` non-override confirmation.
- Read `agent-system/extensions/core/scripts/skill-base.sh` (`skill_get_extension_dir`,
  `skill_run_extension_hook`, `skill_context_injection`, lines ~160-545) line by line to trace the
  hook-resolution mechanism for gap 3.
- Read `agent-system/extensions/core/docs/guides/creating-extensions.md`'s Lifecycle Hooks and
  Post-Task Observers sections in full to confirm no alternative extension-declared mechanism
  covers the cross-cutting case, and to understand why Observers were built as a *separate*
  seam.
- Read `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (lines ~337-342,
  ~710-711) to trace the one working cross-cutting precedent (`<memory-context>`) to its actual
  (non-extension-hook) implementation.
- Read `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` in full for the
  registration-vs-permission-scope rule applied to gap 1.
- Read `agent-system/extensions/core/agents/general-implementation-agent.md` for the exact Stage
  at which the completion summary is written, to ground the gap-2 instruction's placement.
- Read `~/.dotfiles/docs/sapience.md` for the `auto_approve: false` review-gate configuration
  and the already-ambient-components inventory.

### References
- `agent-system/extensions/approvals/manifest.json`, `agent-system/extensions/literature/manifest.json`
- `agent-system/extensions/memory/{manifest.json,EXTENSION.md,index-entries.json,settings-fragment.json}`
- `agent-system/extensions/{nix,web,lean,email}/settings-fragment.json`
- `agent-system/extensions/core/scripts/skill-base.sh`
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`
- `agent-system/extensions/core/docs/guides/creating-extensions.md`
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `~/.sapience/mcp.py`, `~/.sapience/upload.py`
- `~/.dotfiles/config/claude/settings.json`, `~/.claude.json`, `~/.dotfiles/docs/sapience.md`
