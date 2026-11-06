# Research Report: Generate .mcp.json from extension manifests, then register obsidian-memory through it

- **Task**: 29 - Generate .mcp.json from extension manifests, then register obsidian-memory through it
- **Started**: 2026-11-06T06:56:48Z
- **Completed**: 2026-11-06T07:40:00Z
- **Effort**: ~2 hours (research only)
- **Dependencies**: 22 (declared in state.json; not re-verified here)
- **Sources/Inputs**:
  - Codebase: `lua/neotex/plugins/ai/shared/extensions/{init,merge,manifest,config,verify,settings_backup}.lua`, `lua/neotex/plugins/ai/claude/extensions/{merge,manifest,manifest_spec}.lua`
  - Codebase: `agent-system/extensions/{memory,lean,core}/manifest.json`, `agent-system/extensions/memory/{settings-fragment.json,README.md}`
  - Codebase: `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`, `agent-system/extensions/core/docs/architecture/extension-system.md`
  - Codebase: `lua/neotex/plugins/text/lean.lua` (worked `.mcp.json` example)
  - Web: npm registry API (`registry.npmjs.org`), GitHub README for `iansinnott/obsidian-claude-code-mcp`
- **Artifacts**: this report
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- The deploy engine already has the exact idiom this task should mirror: `merge_targets.settings`
  (manifest declaration) -> `process_merge_targets`/`reverse_merge_targets` in
  `lua/neotex/plugins/ai/shared/extensions/init.lua` -> `merge_settings`/`unmerge_settings` (additive,
  tracked deep-merge) in `merge.lua`. Adding a parallel `merge_targets.mcp` key that targets
  project-root `.mcp.json` is a small, well-precedented change, not new design.
- `.mcp.json` living at the **project root** (outside `.claude/`) is actually the *correct* and
  *already-precedented* placement: it is never touched by a `.claude/`-tree wipe/regenerate, so it
  needs none of the special snapshot/restore handling `settings_backup.lua` built specifically
  because `settings.json`/`settings.local.json` live *inside* `.claude/`.
- `manifest.lua`'s `validate_merge_targets()` is already generic (any key with `source`+`target`
  passes) — no implementation change is needed there to make `mcp` validate. A stale duplicate test
  in two `manifest_spec.lua` files currently asserts behavior the implementation does not have; see
  Findings.
- **Major finding on the absorbed obsidian-memory sub-task**: the currently-declared server
  (`npx -y @anthropic-ai/obsidian-claude-code-mcp@latest`) names an npm package that **does not
  exist** (confirmed via the npm registry API: 404). The real underlying project is an **Obsidian
  plugin**, not a spawnable CLI server, and Claude Code talks to it through its native `/ide`
  integration — a mechanism entirely separate from `.mcp.json`/`~/.claude.json` registration. This
  means the obsidian sub-task's premise (register it as a `stdio` `.mcp.json` entry) cannot be
  carried out as described; this is flagged as a `user_decision` below rather than silently
  "fixed" by substituting a different package.
- Documentation drift found and listed in Findings: `extension-system.md`'s registration-surface
  note is stale relative to `mcp-server-ownership.md`, and its merge.lua function table lists two
  functions (`merge_opencode_agents`/`unmerge_opencode_agents`) that no longer exist in source.

## Context & Scope

This task has two parts, bundled in one description (the second absorbed from a since-abandoned
sibling task):

1. **Mechanism**: add a deploy-engine merge target so an extension can declare an MCP server and
   have it land in a project-scoped `.mcp.json`, with add-on-load / remove-on-unload /
   idempotent-redeploy semantics, extending `manifest_spec.lua` validation coverage to match.
2. **Application**: move the memory extension's dead `mcpServers` declaration for obsidian-memory
   into the new mechanism, with an explicit `"type"` field, and grant its real tool names (verified
   empirically against a running server, not guessed) at the matching scope.

Research scope was: read the full existing merge-target dispatch path end to end (manifest parse ->
validate -> load -> process_merge_targets -> merge.lua primitives -> state tracking -> unload ->
reverse_merge_targets), read the already-existing MCP-ownership documentation produced by a prior,
completed task, and verify the obsidian-memory declaration's factual premises rather than assume
them. No code was written or deployed; `/home/benjamin/.config/nvim/agent-system/extensions/**` and
`lua/neotex/plugins/ai/**` were read-only in this phase, per the dispatch's SOURCE-STORE RULE and
"Do NOT deploy against this repository" verification instruction (both apply fully to
implementation, not research, but research made no edits either).

## Findings

### Codebase Patterns

- **Merge-target dispatch is centralized, not manifest-generic.** `manifest.lua`'s
  `validate_merge_targets()` (`lua/neotex/plugins/ai/shared/extensions/manifest.lua:91-113`) accepts
  *any* key under `merge_targets` as long as its value has `source` and `target` — there is no
  closed set of valid type names at the schema-validation layer. The actual *behavior* per key is
  hardcoded, though: `process_merge_targets()`/`reverse_merge_targets()`
  (`lua/neotex/plugins/ai/shared/extensions/init.lua:74-164`) only special-case `settings` and
  `index` explicitly; `claudemd`/`opencode_json` are handled completely differently, as **computed
  artifacts** regenerated wholesale on every load/unload by `generate_claudemd()` /
  `generate_opencode_json()` (`merge.lua:834-945`, `:1025-1165`) rather than merged/unmerged.
  **A new `mcp` key therefore requires an explicit new branch in both `process_merge_targets()` and
  `reverse_merge_targets()`**, mirroring the existing `settings` branch almost verbatim (different
  target path, same `merge_mod.merge_settings`/`unmerge_mod.unmerge_settings` calls) — adding the
  key to the manifest alone does nothing beyond passing schema validation.
- **`merge_settings()`/`unmerge_settings()` is the right primitive, and the dispatch's own framing
  of it is accurate.** `deep_merge()` (`merge.lua:353-426`) only *adds* keys/array-items that are not
  already present ("Scalar: only add if not exists"; array items deduplicated by `vim.deep_equal`);
  it never overwrites an existing value. This single property is what satisfies requirement (d)
  (hand-written user entries survive) essentially for free: a user's own `mcpServers.<name>` entry
  is never touched because the deep-merge of an extension's fragment never overwrites an existing
  key, by construction — not because of any special-casing that needs to be added.
- **Tracked-unmerge already gives requirement (b) for free too.** `merge_settings()` returns a
  `tracked` structure recording exactly what it added (`new_object`/`new_array`/`new_value`/
  `appended`/`merged`), which `unmerge_settings()` walks to remove *only* those additions. This
  tracked structure is persisted into `specs`-adjacent... no — into the project's own
  `.claude-extensions.json` (`root_state_file`) via `state_mod.mark_loaded(..., merged_sections, ...)`
  (`init.lua:633`) and read back at unload time via `state_mod.get_merged_sections()`
  (`init.lua:712`), so unload correctly reverses even across separate nvim sessions. The same
  pattern, reused for `mcp`, gives clean per-extension retraction on unload without new design.
- **Project-root placement is a feature, not a loose end.** `settings_backup.lua`'s entire reason
  for existing is that `settings.json`/`settings.local.json` live *inside* `config.base_dir`
  (`.claude/`) and are therefore destroyed by a full `rm -rf .claude/` regenerate — it snapshots them
  to a project-root staging dir first and restores after. `config.lua`'s own comment
  (`config.lua:32-35`) explains `root_state_file` (`.claude-extensions.json`) is deliberately placed
  at the project root "so it survives a `.claude`/`.opencode` wipe." `.mcp.json` sits at the same
  project-root tier, for the same reason, and needs no equivalent backup/restore wrapper: a
  `.claude/` wipe+regenerate simply never touches it, and the subsequent regenerate's re-merge of
  each still-loaded extension's `mcp` fragment is idempotent against whatever is already there (see
  Risks for one caveat on this point).
- **An almost-exact worked example already exists for the target shape.** `lua/neotex/plugins/text/lean.lua:12-25`
  documents the lean-lsp `.mcp.json` entry with an explicit `"type": "stdio"` field — exactly the
  shape requirement (a) asks for, and proof the explicit-`type` requirement is already understood
  elsewhere in this codebase, just not yet produced by the deploy engine itself.
- **The registration/permission split this task depends on was already settled by a prior,
  completed task.** `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` (produced
  by the completed task "reconcile_mcp_registration_surfaces", per its own cross-reference in
  state.json's sapience-task entry) already documents, in detail: that only `~/.claude.json` and
  project-scoped `.mcp.json` register servers (an `mcpServers` key in any settings file registers
  nothing — "empirically verified... not an inference from documentation silence"); the
  workspace-trust gate added in Claude Code v2.1.196 for `.mcp.json`; the session-start snapshot trap
  (a server added to `.mcp.json` is invisible to an already-running session, including the main
  session, not just subagents); the "grant permissions at the same scope where the server is
  registered" rule; and "prefer a wildcard (`mcp__{server}__*`) over enumeration" as the house style
  for permission grants (with `lean-lsp`'s own enumeration-drift history as the cautionary worked
  example). This task's job is almost entirely the *mechanical automation* half (making `.mcp.json`
  generation happen from a manifest declaration); the *conceptual* half was already done.
- **`generate_opencode_json()` is a cautionary counter-example for decision (d).** It is a fully
  computed artifact — read a base template, then rebuild `opencode.json` wholesale from every loaded
  extension's fragment, gated behind an `opencode.json.managed` marker file
  (`merge.lua:1025-1050`). This model does **not** preserve hand-written content the way
  `merge_settings`'s additive deep-merge does; it was deliberately chosen there for full
  determinism. The dispatch's explicit instruction to mirror `settings`, not invent a second idiom,
  rules this model out for `.mcp.json` — worth stating plainly since both idioms coexist in the same
  file and an implementer could reach for either.

### External Resources / Verified Facts

- **The obsidian-memory `.mcp.json` entry as currently declared cannot work.** Querying the npm
  registry API directly (`curl https://registry.npmjs.org/@anthropic-ai%2Fobsidian-claude-code-mcp`)
  returns `404 {"error":"Not found"}` — there is no such package published under the `@anthropic-ai`
  npm scope. `npx -y @anthropic-ai/obsidian-claude-code-mcp@latest` would fail at spawn with an npm
  "not found" error, not silently degrade.
- **The real project by that name is an Obsidian plugin, not an npx-spawnable server.**
  `iansinnott/obsidian-claude-code-mcp` is an Obsidian desktop plugin. It runs its own WebSocket
  server (default port 22360 — the same port number already present in the `OBSIDIAN_WS_PORT` value
  in `settings-fragment.json`, suggesting the port number itself is correct even though the launch
  command is not) and an HTTP/SSE endpoint. Critically: **Claude Code does not spawn this server at
  all.** It discovers the plugin automatically through its native IDE-integration mechanism (lock
  files under `$CLAUDE_CONFIG_DIR/ide/`, `~/.config/claude/ide/`, or `~/.claude/ide/`), selected
  interactively via Claude Code's own `/ide` command ("choose Obsidian from the IDE list"). No
  `command`/`args`/`env` fields, and no `.mcp.json`/`~/.claude.json` entry of any kind, are involved
  in connecting to it. `OBSIDIAN_WS_PORT` as an environment-variable name does not appear in that
  project's own documentation at all.
  - Tool names surfaced by the plugin's README (doc-sourced, **not** empirically verified against a
    running server, and must be treated as such): shared tools `view`, `str_replace`, `create`,
    `insert`, `get_current_file`, `get_workspace_files`, `obsidian_api`; WebSocket/IDE-only tools
    `getDiagnostics`, `openDiff`, `close_tab`, `closeAllDiffTabs`. These are offered as orientation
    only — the dispatch's own rule ("do NOT copy tool names from any existing documentation...
    enumerate them empirically") applies with full force here, and this list was never run through
    `tools/list` against a live server in this research phase.
- **Genuinely npm-published alternative Obsidian MCP servers do exist**, if a real `.mcp.json`
  `stdio` entry for Obsidian is still wanted: `obsidian-mcp` (by `stevenstavrakis`) and
  `@huangyihe/obsidian-mcp` both resolve on the npm registry (HTTP 200). Neither was investigated
  further — picking one would mean registering a *different* server under the `obsidian-memory` name
  than the one the task description assumed, which is exactly the kind of substitution this report
  flags for the user rather than making unilaterally (see Decisions/user-decision below).

## Decisions

- **Mirror `merge_targets.settings`'s idiom for the new `merge_targets.mcp` key** (additive,
  idempotent `deep_merge` via `merge_settings()`/`unmerge_settings()`, tracked in
  `merged_sections.mcp` and persisted through `state_mod.mark_loaded`), rather than the
  `generate_opencode_json()`-style fully-computed-artifact idiom. This was the dispatch's own
  explicit instruction and is independently the better fit: it is the only one of the two existing
  idioms that preserves hand-written user entries by construction (requirement d) while still
  giving clean per-extension add/retract semantics (requirement b) and idempotent redeploys
  (requirement c).
- **Target `.mcp.json` at the project root, not under `.claude/`.** This is already implied by
  Claude Code's own fixed read path for that file and matches the existing `root_state_file`
  precedent (`.claude-extensions.json`) for "things that must survive a `.claude/` wipe."
- **Decision (d) is resolved as: hand-written entries survive by construction; no separate
  "generated-file" banner/comment is required for correctness.** `deep_merge`'s additive-only
  semantics make this true regardless of whether the file documents itself as generated. A
  `// this section is extension-managed`-style note is still a reasonable usability nicety for the
  plan/implementation phase to consider (JSON has no comments, so this would need to be a sibling
  README/doc note, not an in-file comment), but it is not load-bearing for the requirement.
- **Did not decide, and explicitly defer to the user**: whether to (a) drop the obsidian-memory
  `.mcp.json`/`stdio` wiring entirely and instead document Claude Code's native `/ide` integration
  as the real path for that specific plugin, leaving the "register obsidian-memory" half of this
  task's title only partially satisfied by design; or (b) register a different, genuinely
  npm-published Obsidian MCP server (e.g. `obsidian-mcp` or `@huangyihe/obsidian-mcp`) under the
  `obsidian-memory` name instead, accepting that its tool surface differs from whatever the original
  task author expected. See `user_decision` in `.return-meta.json`.

## Recommendations

1. **Manifest schema** (`agent-system/extensions/memory/manifest.json`, and any other extension
   wanting to declare a server): add a `merge_targets.mcp` entry, e.g.
   `{"source": "mcp-fragment.json", "target": ".mcp.json"}`, parallel to the existing `settings`
   entry. No change is needed to `manifest.lua`'s `validate_merge_targets()` itself — add a
   positive test case to `manifest_spec.lua` (both the `shared/extensions/` and `claude/extensions/`
   copies) asserting a manifest with `merge_targets.mcp` validates, satisfying the dispatch's
   "extend manifest_spec.lua so the new key validates" instruction; this is test-coverage work, not
   a validator change.
2. **Deploy engine** (`lua/neotex/plugins/ai/shared/extensions/init.lua`): add an `mcp` branch to
   `process_merge_targets()` (around line 90, alongside the `settings` branch) and a matching branch
   to `reverse_merge_targets()` (around line 148), calling the same `merge_mod.merge_settings()` /
   `merge_mod.unmerge_settings()` functions already used for `settings`, just against the
   `merge_targets.mcp` config and a `.mcp.json` target path. No new function is needed in
   `merge.lua` itself.
3. **New source fragment file per extension** (e.g. `agent-system/extensions/memory/mcp-fragment.json`):
   shape `{"mcpServers": {"<name>": {"type": "stdio", "command": ..., "args": [...], "env": {...}}}}`
   — the explicit `"type"` field is mandatory per the dispatch's requirement (a) and the
   `lean.lua` precedent.
4. **Settings-fragment cleanup**: remove the dead `mcpServers` block from
   `agent-system/extensions/memory/settings-fragment.json` once its content moves to the new
   `mcp-fragment.json` — leaving both would recreate exactly the "dead weight that misleads a future
   reader" problem `mcp-server-ownership.md` already warns about for other extensions.
5. **Documentation updates** (both already in file_scope or directly adjacent to it):
   - `agent-system/extensions/core/context/guides/extension-development.md`: document the new
     `merge_targets.mcp` key alongside the existing `settings`/`index`/`claudemd` entries.
   - `agent-system/extensions/core/docs/architecture/extension-system.md`: update the
     registration-surface note (~line 227) to mention `.mcp.json` as a real registration surface
     (it currently names only `~/.claude.json`), add an `mcp` row to the `merge_targets` table
     (~line 225) and the Load/Unload Process step lists (~line 375, ~line 390), and document the new
     merge branch in the "Settings Merging" section. This file is not in the task's declared
     `file_scope` but documents the exact mechanism this task changes; leaving it stale would
     reintroduce the kind of doc/implementation drift this report already found once (see Findings).
   - `agent-system/extensions/memory/README.md`: correct the "configured in manifest.json" claim
     (it is not — no `mcp_servers` field exists in that manifest today, and the new mechanism uses
     `merge_targets.mcp`, not a `mcp_servers` field) and document the OBSIDIAN_WS_PORT / running-Obsidian
     prerequisite plainly, per the dispatch's explicit instruction.
6. **Obsidian-memory sub-task**: do not fabricate a tool list or "fix" the command by guessing a
   substitute package. Resolve the `user_decision` below first; whichever branch the user picks,
   the actual tool-name enumeration against a live server (or the documented "could not verify, here
   is why" outcome) is implementation-phase work requiring a running Obsidian instance with the
   companion plugin, not something research can complete.
7. **Verification mechanism**: Follow the dispatch's own scratchpad-fixture plan
   (build a throwaway fixture project, load an extension declaring a trivial `stdio` server, confirm
   `.mcp.json` generation / idempotent redeploy / clean unload / `claude mcp get <name>` reporting
   `Scope: Project config`). Consider also adding an automated check to
   `lua/neotex/plugins/ai/shared/extensions/verify.lua` (which already has per-merge-target
   verification helpers for `settings`/`index`/`opencode_json`) for the new `mcp` target, as a
   follow-up rather than a blocking requirement of this task.

## Risks & Mitigations

- **Idempotency across a full regenerate may silently thin tracked-unmerge data.** `deep_merge`'s
  tracking records only what it *adds*; re-running `process_merge_targets()` against an `.mcp.json`
  that already contains an extension's entries (e.g. during `manager.regenerate()` after a
  `.claude/`-wipe) will find those keys already present and record little-to-no new tracked data for
  them. This appears to already be a latent property of the existing `settings` merge path today,
  not something newly introduced by `mcp` — but it means an unload performed *after* a regenerate
  could, in principle, fail to retract entries that long predate that regenerate. **Mitigation**:
  verify this empirically in the implementation phase's fixture test (load -> regenerate -> unload
  -> confirm removal) before relying on it; if it reproduces, it is a pre-existing limitation worth
  a separate finding, not something this task needs to fix.
- **JSON key-ordering and idempotent byte-identity.** `merge.lua`'s `write_json()` pretty-prints via
  `jq .`, which preserves input order rather than sorting it; Lua's own `pairs()` iteration order for
  a freshly-decoded table is not formally guaranteed stable, though it is deterministic in practice
  for a fixed key set under LuaJIT's non-randomized string hashing. **Mitigation**: the dispatch's
  own verification step ("confirm a second deploy is a no-op") should diff the file bytes, not just
  parse-and-compare the JSON, to catch this empirically; if it is not byte-stable, switching
  `write_json` to `jq -S .` (sort keys) for this target only is a minimal, safe fix.
- **Obsidian-memory's runtime prerequisite cannot be satisfied in a research/CI-style
  environment.** No Obsidian instance with the companion plugin is running here, and the real
  connection path (Claude Code's `/ide` command) is interactive and session-scoped, not something a
  background dispatch can exercise. This was already anticipated by the dispatch's own "truthful
  'could not verify' is the correct outcome" instruction; this report's additional finding (the
  declared package does not exist) makes that outcome even more clearly correct than a simple
  "couldn't reach the port" would have.
- **Doc drift compounding.** Two more pre-existing documentation inconsistencies were found
  incidentally (not part of this task's direct scope): `extension-system.md`'s merge.lua function
  table lists `merge_opencode_agents()`/`unmerge_opencode_agents()`, which do not exist in the
  current `merge.lua`; and both `manifest_spec.lua` test files assert an "Invalid merge_targets
  type" rejection that the current generic validator does not implement. Neither blocks this task,
  but both are easy wins to fold into the same doc-touching implementation phase since the files are
  already open.

## Context Extension Recommendations

- **Topic**: MCP server registration via `.mcp.json` generation.
- **Gap**: `mcp-server-ownership.md` documents the registration/permission *model* thoroughly but
  (as of this research) still describes `.mcp.json` as something "extension-declared servers" should
  use "going forward" without yet describing *how* an extension declares one through the manifest
  system (because that mechanism does not exist yet — this task builds it).
- **Recommendation**: once this task ships the `merge_targets.mcp` mechanism, add a short
  cross-reference from `mcp-server-ownership.md`'s "Registration" section to the new
  `extension-development.md` section documenting the manifest key, so a future extension author
  reaches the *mechanical* how-to from the *conceptual* ownership doc in one hop.

## Appendix

- Search/verification commands used: `grep`/`find` over `lua/neotex/plugins/ai/**` and
  `agent-system/extensions/**`; `curl https://registry.npmjs.org/@anthropic-ai%2Fobsidian-claude-code-mcp`
  (404); `curl https://registry.npmjs.org/obsidian-mcp` and `.../@huangyihe%2Fobsidian-mcp` (both 200);
  `WebSearch` for `obsidian-claude-code-mcp @anthropic-ai npm tools list OBSIDIAN_WS_PORT` and for the
  exact `@anthropic-ai/obsidian-claude-code-mcp` package name; `WebFetch` of the
  `iansinnott/obsidian-claude-code-mcp` GitHub README for its Claude Code connection model and tool
  names (doc-sourced only, not empirical).
- Key files read: `lua/neotex/plugins/ai/shared/extensions/{init,merge,manifest,config,verify,settings_backup}.lua`;
  `lua/neotex/plugins/ai/claude/extensions/{merge,manifest,manifest_spec}.lua`;
  `agent-system/extensions/{memory,lean,core}/manifest.json`;
  `agent-system/extensions/memory/{settings-fragment.json,README.md}`;
  `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`;
  `agent-system/extensions/core/docs/architecture/extension-system.md`;
  `lua/neotex/plugins/text/lean.lua`.
