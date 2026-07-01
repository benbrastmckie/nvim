# Research Report: Task #791

**Task**: 791 - Fix Load Core loader so WezTerm lifecycle tab coloring propagates to all synced repos
**Started**: 2026-06-30T18:15:45-07:00
**Completed**: 2026-06-30T19:10:00-07:00
**Effort**: Medium (2 manifest edits, 1 new fragment file, 1 code change in sync.lua, mirrored in `.opencode`)
**Dependencies**: None
**Sources/Inputs**: Codebase (sync.lua, merge.lua, loader.lua, init.lua, manifest.lua, state.lua), live repo state (`/home/benjamin/Projects/BimodalLogic`), `~/.config/wezterm/wezterm.lua`, three settings.json variants (nvim canonical, dotfiles legacy, BimodalLogic target)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Two independent, compounding bugs**, not one. (1) `core/manifest.json`'s `provides.hooks` allow-list is stale — it still lists a renamed file (`wezterm-clear-status.sh`, no longer on disk) and is **missing** `wezterm-preflight-status.sh` and `wezterm-utils.sh`. This causes *both* the "Load Core" bulk-sync path and the "Load Extension" install path to silently drop those two files when copying to a target repo — confirmed live in `/home/benjamin/Projects/BimodalLogic`, whose `.claude/settings.json` already references `wezterm-preflight-status.sh` (because that file happened to be copied wholesale on first install) but whose `.claude/hooks/` directory is missing the script, so the hook fails with exit 127 every time and is silently swallowed by `|| echo '{}'`. (2) The settings.json **registration**-merge gap described in the task is real but only reachable through `reinject_loaded_extensions()`, which is gated on `state_mod.list_loaded()` — so it is a no-op for any repo where `core` was never registered via the state-tracked "Load Extension" flow (i.e. pure "Load Core" bulk-sync users).
- Recommended fix is a **hybrid of (A) and a small state-independent fallback**: declare `merge_targets.settings` in the core manifest (following the exact fragment format already used by `lean`/`nix`/`epidemiology` extensions), but do **not** rely solely on `reinject_loaded_extensions()`'s state-gated loop — patch it (or `load_all_globally`) to always treat `core` as present, since "Load Core" is definitionally about the core extension regardless of `extensions.json` tracking state.
- Target file for the new fragment must be `.claude/settings.json` (tracked/committed), **not** `.claude/settings.local.json` (globally gitignored per `~/.config/git/ignore`, used by existing precedent for MCP servers/permissions). Hooks are core functionality, not personal preference.
- The precise fragment only needs 3 event arrays: `SessionStart` (`wezterm-clear-task-number.sh`), `Stop` (`claude-stop-notify.sh`, which internally calls `wezterm-notify.sh`), and `UserPromptSubmit` (`wezterm-task-number.sh`, `wezterm-preflight-status.sh`). `wezterm-notify.sh` itself and `wezterm-utils.sh` are never directly registered as hook events — they are a library and a script invoked by `claude-stop-notify.sh` / `.claude/scripts/lifecycle-notify.sh`, so they only need to exist on disk, not appear in the settings fragment.
- `merge_settings()`/`deep_merge()` (merge.lua:172-257) is append-only per-key and array-deduplicates by `vim.deep_equal`, which is idempotent for identical re-runs but will NOT self-heal a drifted command path (it will append a second, non-duplicate array entry alongside the stale one) — a real gap for goal 4(c) that must be called out, not silently assumed solved.
- The exact same `provides.hooks` staleness (missing `wezterm-preflight-status.sh`/`wezterm-utils.sh`, phantom `wezterm-clear-status.sh`) exists in `.opencode/extensions/core/manifest.json` and must be fixed there too. `.opencode/settings.json` sync already goes through the install-only "copy if absent, replace only if `.managed` marker" branch at sync.lua:894-910 (that code path is *live* for `.opencode`, unlike for `.claude` — see Findings).

## Context & Scope

Investigated the Neovim "Load Core Agent System" loader (`<leader>al` → picker → sync.lua `load_all_globally`) and the separate extension-picker "Load Extension" flow (`extensions/init.lua` `M.create(config).load`), to determine why WezTerm lifecycle tab coloring (driven by the `CLAUDE_STATUS` user variable) fails to propagate to repos the agent system is copied into. Scope: `.claude` and `.opencode` loader code paths in this repo (`~/.config/nvim`), the core extension manifest, `merge.lua`'s generic merge/unmerge primitives, and cross-repo verification against a real target (`/home/benjamin/Projects/BimodalLogic`).

## Findings

### 1. Root cause — confirmed and split into two independent bugs

**Bug A (script-copy allow-list is stale) — the actually-manifesting bug on the verified target repo.**

`core/manifest.json`'s `provides.hooks` array (`.claude/extensions/core/manifest.json:118-129`) is:

```json
"hooks": [
  "log-session.sh", "memory-nudge.sh", "post-command.sh", "subagent-postflight.sh",
  "tts-notify.sh", "validate-plan-write.sh", "validate-state-sync.sh",
  "wezterm-clear-status.sh", "wezterm-clear-task-number.sh",
  "wezterm-notify.sh", "wezterm-task-number.sh"
]
```

`wezterm-clear-status.sh` does **not exist** anywhere under `.claude/extensions/core/hooks/` or `.claude/hooks/` (confirmed via `find`); it is a stale pre-rename name. The list is also **missing** `wezterm-preflight-status.sh` and `wezterm-utils.sh`, both of which exist on disk in `.claude/extensions/core/hooks/` (added later, per `git log` — commit `bb42d80cc` "promote --hard mode to core extension first-class status" era and `599 phase 2` hooks-schema commit did not add these two filenames to `provides.hooks`).

This allow-list is consumed by **two** independent code paths, both broken by the same stale list:

1. **"Load Core" bulk sync** (`sync.lua` `scan_all_artifacts`, line 818): `artifacts.hooks = sync_scan("hooks", "*.sh", true, nil, "hooks")`. Inside `sync_scan` (lines 731-787), when an allow-list exists for category `"hooks"` (built by `manifest.build_allow_list(core_provides)`, `manifest.lua:281-292`, which is a literal 1:1 map of `core_provides.hooks` entries), files are post-filtered at lines 760-784: `if allowed[file_info.name] then ... end`. Since `wezterm-preflight-status.sh` and `wezterm-utils.sh` are not keys in `allowed`, they are silently dropped from the sync set even though they were physically found on disk during the scan.
2. **"Load Extension" install** (`extensions/init.lua` line 440 → `loader.lua` `M.copy_hooks`, lines 352-387): iterates `manifest.provides.hooks` directly (line 370: `for _, hook_name in ipairs(manifest.provides.hooks) do`) and only copies files named in that literal list — same two omissions.

**Live confirmation** in `/home/benjamin/Projects/BimodalLogic` (core extension loaded via the "Load Extension" flow on 2026-06-24, per `.claude/extensions.json`'s `loaded_at`):

```
$ ls .claude/hooks/ | grep wezterm
wezterm-clear-task-number.sh
wezterm-notify.sh
wezterm-task-number.sh
# wezterm-preflight-status.sh and wezterm-utils.sh are ABSENT

$ jq '.hooks.UserPromptSubmit' .claude/settings.json
[{ "matcher": "*", "hooks": [
  {"command": "bash .claude/hooks/wezterm-task-number.sh ..."},
  {"command": "bash .claude/hooks/wezterm-preflight-status.sh ..."}   <- registered but file missing
]}]

$ bash .claude/hooks/wezterm-preflight-status.sh
bash: .claude/hooks/wezterm-preflight-status.sh: No such file or directory   (exit 127)
```

BimodalLogic's `settings.json` **already has the correct registration** (because it had no pre-existing `settings.json` when core was first loaded, so `copy_root_files` — see Bug B below — wrote the canonical file wholesale). The tab-coloring failure there is caused entirely by Bug A: the hook command fails with exit 127 every UserPromptSubmit, silently swallowed by the `|| echo '{}'` fallback baked into every hook command in settings.json, so `CLAUDE_STATUS` is never set from that path. This directly falsifies the task's initial hypothesis for this specific repo (settings.json registration was *not* the missing piece there) but confirms the general registration-merge gap exists structurally (see Bug B) for a different class of target repo.

`wezterm-utils.sh` is a **sourced library**, not a hook itself — confirmed via `grep`:
```
wezterm-preflight-status.sh:28: source "$SCRIPT_DIR/wezterm-utils.sh"
wezterm-notify.sh:39:            source "$SCRIPT_DIR/wezterm-utils.sh"
```
So even where `wezterm-notify.sh` **is** in the allow-list and gets copied, it would also fail (`source: No such file`) in any target missing `wezterm-utils.sh`.

**Bug B (settings.json registration-merge gap) — the task's stated hypothesis, real but narrower and state-gated.**

Contrary to the task description's citation, the "install-only: copy if absent, replace only if `.managed` marker exists, otherwise skip" logic at `sync.lua:894-910` is inside the `root_files` loop, which is populated **only for `.opencode`**:

```lua
-- sync.lua:877-882
local root_file_names
if base_dir == ".opencode" then
  root_file_names = { "AGENTS.md", "OPENCODE.md", "settings.json", ".gitignore", ... }
else
  root_file_names = {}   -- .claude: EMPTY
end
```//
and explicitly commented at `sync.lua:871-876`: *"For .claude: all root files (settings, .gitignore, CLAUDE.md) are now managed by the extension loader (root_files provides + generate_claudemd), not synced."* Likewise `artifacts.settings` is populated only `if not core_source_base` (`sync.lua:866-868`), which is **false** for `.claude` (since `core_source_base = ".claude/extensions/core"` is always set at line 720 for `.claude`). So for `.claude`, `settings.json` is **not touched at all** by `scan_all_artifacts`/`execute_sync` — the 894-910 install-only branch the task cites is real code, but it is the code path *actually exercised only for `.opencode`*.

For `.claude`, `.claude/settings.json` is managed by two other mechanisms:

1. **`loader.lua` `M.copy_root_files`** (lines 551-579), invoked from `extensions/init.lua:464` during "Load Extension". This function's underlying `copy_file` helper (`loader.lua:54-82`) has **no existence check at all** — it unconditionally overwrites `target_path`. There is also no conflict detection for `root_files` in `check_conflicts` (`loader.lua:686-749`, whose `categories` list at line 694 is `{agents, commands, rules, scripts, hooks, docs, templates, systemd}` — `root_files`/`settings.json` is absent). So on a repo that already has a customized `.claude/settings.json` *before* core is ever "Load Extension"-loaded (or on re-load), this path would silently clobber it. On a fresh repo with no prior `settings.json` (BimodalLogic's actual history), the "clobber" is harmless because there was nothing to lose — which is exactly why BimodalLogic ended up with a correct registration despite the deeper design gap.
2. **`sync.lua` `reinject_loaded_extensions`** (lines 212-282), called unconditionally at the end of every non-merge-only "Load Core" run (`sync.lua:1153-1156`). This is the mechanism the task's FIX DIRECTION points at. It reads `state_mod.list_loaded(state)` (line 222) and, for each **already-state-tracked-as-active** extension, re-applies `merge_targets.settings` if declared (lines 248-257) via `merge_mod.merge_settings`. **Critically, this is state-gated**: `state_mod.list_loaded` (`state.lua:228-237`) only returns extensions whose `state.extensions[name].status == "active"` in `extensions.json`. `sync.lua`'s `load_all_globally` (the actual "Load Core" function) **never calls `state_mod.write`** — grepped, confirmed absent — so a repo that has only ever run "Load Core" (never "Load Extension") has no `core` entry in `extensions.json` at all, and `reinject_loaded_extensions` is a complete no-op for it, **even after** `merge_targets.settings` is added to the core manifest. This is the load-bearing subtlety the task's "FIX DIRECTION to validate/refine" needed: Approach (A) as literally stated ("rely on the existing `reinject_loaded_extensions()` path") is **necessary but not sufficient**.

### 2. Precise, minimal fix — recommendation and exact functions/lines to change

**Recommended approach: (A) + a state-independence patch**, i.e. declare the fragment via `merge_targets.settings` (matching existing precedent exactly) but make the re-injection loop unconditionally include `core`.

Step-by-step:

1. **Fix the stale allow-list first** (prerequisite — without this, the merged registration points at files that still won't exist). In `.claude/extensions/core/manifest.json` `provides.hooks` (lines 118-129): remove `"wezterm-clear-status.sh"`, add `"wezterm-preflight-status.sh"` and `"wezterm-utils.sh"`. Mirror the identical edit in `.opencode/extensions/core/manifest.json` `provides.hooks` (same stale entries confirmed present there too — see Consistency section).
2. **Add a new merge-source fragment** at `.claude/extensions/core/merge-sources/settings-hooks.json` (new file, following the existing convention: `claudemd.md` and `index-entries.json` already live under `merge-sources/` per `manifest.json:9,13`). Content is the authoritative hook fragment (see Section 3 below) — only the 3 event arrays needed for lifecycle coloring, not a full settings.json (deep_merge is additive per top-level key, so a partial `hooks` object is exactly what's needed).
3. **Declare it in the manifest** — add to `.claude/extensions/core/manifest.json`'s `merge_targets` object (currently lines 7-17, has only `claudemd` and `index`):
   ```json
   "settings": {
     "source": "merge-sources/settings-hooks.json",
     "target": ".claude/settings.json"
   }
   ```
   This exactly matches the shape used by `lean`/`nix`/`epidemiology` (`extensions/{lean,nix,epidemiology}/manifest.json`), except those three target `.claude/settings.local.json` (personal MCP/permissions, globally gitignored per `~/.config/git/ignore:1`: `**/.claude/settings.local.json`) — deliberately different from this case, where the fragment is core hook wiring that must ship in the **committed** `.claude/settings.json` for every clone/collaborator to get working tab coloring, not just the person who ran "Load Extension" locally.
4. **Patch the state-gating in `reinject_loaded_extensions`** (`sync.lua:220-226`). After `local loaded_names = state_mod.list_loaded(state)`, ensure `"core"` is always present regardless of tracking state, e.g.:
   ```lua
   local loaded_names = state_mod.list_loaded(state)
   local has_core = false
   for _, n in ipairs(loaded_names) do
     if n == "core" then has_core = true break end
   end
   if not has_core then table.insert(loaded_names, 1, "core") end
   ```
   This is the single-line-ish change that closes Bug B's remaining gap: "Load Core" (`load_all_globally`) already unconditionally treats `core`'s artifacts as always-in-scope (it doesn't consult `extensions.json` for anything else in `scan_all_artifacts`); making `reinject_loaded_extensions` consistent with that assumption specifically for `core` is the minimal, semantically-correct fix, and it also transparently repairs a **pre-existing, task-unrelated latent bug**: today, a "Load Core"-only repo (no state-tracked core) gets *no* defense-in-depth re-injection at all for the already-declared `claudemd`/`index` merge targets either — this patch fixes that too as a side effect.
5. **Do not touch `process_merge_targets`** (`extensions/init.lua:72-127`) or `M.create(config).load` — they already generically support `merge_targets.settings` (lines 89-101) and will pick up the new declaration automatically for the "Load Extension" flow once step 3 lands. No new code needed there.

Rejected alternatives:
- **(B) Change sync.lua's install-only branch to always merge a canonical hooks block**: would require new bespoke logic duplicating what `merge_mod.merge_settings` already does generically, and (per Finding 1) the `.claude` root_files branch isn't even the exercised code path — this would add a special case rather than closing the actual gap.
- **(C) `.managed`-marker approach**: already exists for `opencode.json` (`merge.lua:709` `managed_marker`) and for `.opencode`'s `settings.json`/`package.json` (`sync.lua:900-908`), but is fundamentally an install-only/replace-only gate, not a merge — it would force an all-or-nothing choice between "never touch user's settings.json again" and "blow away project-specific permissions/hooks/MCP servers," which is exactly what the task says must be avoided.

### 3. Authoritative hook fragment (event → matcher → command)

Cross-referencing `~/.config/wezterm/wezterm.lua` (`format-tab-title` at lines 306-339, `update-status` at lines 401-426) against `.claude/extensions/core/root-files/settings.json` (canonical, byte-identical to this repo's own `.claude/settings.json`):

- `format-tab-title` reads `active_pane.user_vars.CLAUDE_STATUS` (line 318) against a fixed lifecycle-state table (`needs_input, researching, researched, planning, planned, implementing, completed, blocked` — lines 322-331) and `active_pane.user_vars.TASK_NUMBER` (line 371) for the `#N` suffix.
- `update-status` (line 401) only *clears* `CLAUDE_STATUS` when it equals `"needs_input"` and the active tab changed (lines 411-420) — it does not set anything, so no hook is needed to support it.

Hooks/events that must be registered (this is the complete, minimal fragment — confirmed by tracing which scripts actually write `CLAUDE_STATUS`/`TASK_NUMBER` via `SetUserVar`):

| Event | Matcher | Command | Effect |
|---|---|---|---|
| `SessionStart` | `*` | `bash .claude/hooks/wezterm-clear-task-number.sh` | Clears `TASK_NUMBER` on new session |
| `Stop` | `*` | `bash .claude/hooks/claude-stop-notify.sh` | Internally invokes `wezterm-notify.sh` (no args) → sets `CLAUDE_STATUS=needs_input` |
| `UserPromptSubmit` | `*` | `bash .claude/hooks/wezterm-task-number.sh` then `bash .claude/hooks/wezterm-preflight-status.sh` | Sets `TASK_NUMBER`; sets `CLAUDE_STATUS` to `researching`/`planning`/`implementing` on lifecycle slash-commands (Tier 1), clears on other slash-commands (Tier 2), preserves on free text (Tier 3) |

Note: `wezterm-notify.sh` (`.claude/hooks/wezterm-notify.sh`) is **never itself a settings.json hook target**. It is invoked with an explicit lifecycle argument (`researched`, `planned`, `completed`, `blocked`, etc.) from `.claude/scripts/lifecycle-notify.sh`, which in turn is called from skill code at status-transition points (`skill-status-sync` and friends) — this is a script-level dependency, not a settings.json registration, and is out of scope for the settings-merge fix (the script already ships via `provides.scripts`, unaffected by this bug). `wezterm-utils.sh` is a sourced library, never a direct hook target, and only needs the `provides.hooks` allow-list fix (Finding 1) to reach target repos — it must NOT appear in the settings fragment.

The other entries visible in the canonical `settings.json` (`PreToolUse`/`PostToolUse` state-file guards, `SubagentStop`, `Notification`) are unrelated to WezTerm coloring and must **not** be included in the new fragment — the fragment should be narrowly scoped to the 3 rows above to avoid duplicating/conflicting with entries a target repo may already have customized for those other events.

Proposed `merge-sources/settings-hooks.json` content:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/wezterm-clear-task-number.sh 2>/dev/null || echo '{}'" }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/claude-stop-notify.sh 2>/dev/null || echo '{}'" }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/wezterm-task-number.sh 2>/dev/null || echo '{}'" },
          { "type": "command", "command": "bash .claude/hooks/wezterm-preflight-status.sh 2>/dev/null || echo '{}'" }
        ]
      }
    ]
  }
}
```
This is deliberately a **subset** of each event's full array (the canonical `settings.json` bundles `post-command.sh`/`memory-nudge.sh` into the same `Stop` matcher, and state-guard hooks into `PreToolUse`/`PostToolUse` — those are unrelated to this fix and already ship correctly via other mechanisms or are project-specific). `deep_merge`'s array-append semantics (`merge.lua:180-202`) mean this fragment's `Stop`/`UserPromptSubmit`/`SessionStart` arrays will be **appended to**, not replace, whatever a target already has for those matchers — so a target with a pre-existing `"*"` matcher entry for `Stop` would end up with two array elements for the same matcher (the existing entry, untouched, plus this fragment's `claude-stop-notify.sh`-only entry) rather than one merged entry with all commands combined. This is *safe* (no clobbering, Claude Code executes all matching hook entries) but produces a slightly less tidy settings.json than a manually-curated one — acceptable given the safety trade-off, and worth a one-line code comment when implemented.

### 4. Idempotency & safety — what `merge_settings` guarantees today, and what the fix must add

`merge_mod.merge_settings` → `deep_merge` (`merge.lua:172-257`):

- **(a) No duplication on repeated Load Core**: **guaranteed** for array entries via `vim.deep_equal` dedup (`merge.lua:190-197`) — re-running the exact same fragment twice is a true no-op. **Guaranteed** for scalars (`merge.lua:214-219`: only sets if `target[key] == nil`). **Guaranteed** for objects (recurses, `merge.lua:203-212`).
- **(b) No clobbering of project-specific content**: **guaranteed by design** — `deep_merge` never overwrites an existing scalar (line 215 `if target[key] == nil`) and never removes existing array elements, only appends new distinct ones. Project-specific permissions/MCP servers/other hooks under different matchers or different top-level keys are untouched.
- **(c) Update stale command paths if the registration drifted**: **NOT guaranteed — a real gap**. Because array dedup is by `vim.deep_equal` (exact structural equality), if the canonical fragment's command string changes (e.g., a future refactor renames `wezterm-preflight-status.sh` again, or adds a flag), the old array entry is *not* recognized as "the same logical hook with a different command" — it has no matching key to update, so the new entry is simply appended alongside the stale one, and both fire in every hook execution. This is exactly the class of bug already latent in the `wezterm-clear-status.sh`→`wezterm-preflight-status.sh` rename (Finding 1): had a settings-merge fragment existed back then, repos would now be running *both* the missing old command (which errors harmlessly to `{}`) and the new one — not this task's exact scenario, but the mechanism is now proven to be a live risk pattern for this repo's rename-prone hook filenames. **The fix should document this limitation** (e.g. a comment near the new `merge_targets.settings` declaration) rather than silently assume `merge_settings` "self-heals" drift; a true fix would require `unmerge_settings` (already tracked via `merged_sections.settings` at load time, `init.lua:96-99`) to run before every re-merge in `reinject_loaded_extensions`, which is out of scope for this minimal fix but worth flagging as a follow-up risk.
- **(d) Trackable for unmerge**: **guaranteed** — `merge_settings` returns `tracked` (`merge.lua:256`), consumed by `process_merge_targets` (`init.lua:96-99`) and stored in `state.extensions.core.merged_sections.settings`, reversible via `unmerge_settings` (`merge.lua:263-312`) from `reverse_merge_targets` (`init.lua:146-150`) on extension unload. However, `reinject_loaded_extensions` (the "Load Core" path) does **not** persist the returned `tracked` value anywhere (`sync.lua:255`: `merge_mod.merge_settings(target_path, fragment)` — return values discarded) — so settings merged via repeated "Load Core" runs (as opposed to the original "Load Extension" load) are not re-tracked into `extensions.json`'s `merged_sections`, meaning `unmerge_settings` on a later "unload core" would only remove what was tracked at the *original* load time, not anything added by subsequent Load-Core re-injections. This is a pre-existing minor gap (also true today for the `index` merge target) — acceptable to leave as-is for this fix (matches existing `index` merge-target behavior) but worth noting since it means unmerge is not perfectly complete for repos that ran "Load Core" many times after the original load.

### 5. Consistency — must the fix be mirrored elsewhere?

- **`.opencode` loader path**: **Yes, partially coupled.** `.opencode/extensions/core/manifest.json`'s `provides.hooks` has the **identical staleness** (`wezterm-clear-status.sh` present/nonexistent, `wezterm-preflight-status.sh`/`wezterm-utils.sh` missing) — confirmed via `jq '.provides.hooks' .opencode/extensions/core/manifest.json`. Fix Finding 1 (allow-list) must be applied to both manifests. However, `.opencode/extensions/core/manifest.json`'s `provides` has **no `root_files` key at all** (confirmed: `jq '.provides' ... | jq keys` omits it) — `.opencode/settings.json` is handled purely through `sync.lua`'s hardcoded `root_file_names` list for `base_dir == ".opencode"` (line 879, includes `"settings.json"`) and the install-only branch at lines 894-910, which — unlike for `.claude` — **is** the live, exercised code path. A `merge_targets.settings` declaration on `.opencode`'s core manifest would need the equivalent of Finding 2's fix (i.e., `reinject_loaded_extensions` is `base_dir`-agnostic and already runs for `.opencode` too via `get_extension_config(".opencode", ...)` at `sync.lua:1154`, so the same state-independent `core` patch covers `.opencode` automatically once mirrored). This is a reasonable but separate follow-on scope; the task's primary target (`.claude`) should land first. Also noted (informational, not blocking): `.opencode`'s copy of `wezterm-preflight-status.sh` has textually drifted from `.claude`'s (missing `/orchestrate` handling and slightly different comments) — a pre-existing content-drift issue unrelated to the merge-target fix, worth a separate follow-up task.
- **Two synced `.claude` trees (dotfiles `~/.config/.claude` vs. nvim `~/.config/nvim/.claude`)**: **Not coupled — dotfiles tree is out of scope.** `~/.config/.claude` (the "shared agent infrastructure" tree referenced by `~/.config/.claude/CLAUDE.md`) has **no `extensions.json` and no `extensions/core/` directory at all** — it predates or is simply disconnected from the extension-loader system entirely; `scan.get_global_dir()` (`scan.lua:8-17`) defaults to `~/.config/nvim`, confirming `~/.config/nvim` (this repo) — not `~/.config/.claude` — is the sole source-of-truth "global dir" the picker's "Load Core" reads from. `~/.config/.claude/hooks/` still has the **very old** `wezterm-clear-status.sh` (pre-rename, 1324 bytes, dated Feb 1) and lacks `wezterm-preflight-status.sh`/`wezterm-utils.sh` entirely, and its `settings.json` registers the old filename. This tree is manually/independently maintained and untouched by any fix to the nvim-repo loader; flagging it as a stale, disconnected artifact worth a separate cleanup task, but it must not be conflated with the Load Core loader fix in this task.

### 6. Verification plan

1. **Static check (no nvim needed)**: after editing `manifest.json` and adding `merge-sources/settings-hooks.json`, validate JSON:
   ```bash
   jq . /home/benjamin/.config/nvim/.claude/extensions/core/manifest.json >/dev/null
   jq . /home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/settings-hooks.json >/dev/null
   ```
2. **Allow-list fix verification**: confirm the new `provides.hooks` array contains exactly the 6 files present on disk under `.claude/extensions/core/hooks/` and no phantom entries:
   ```bash
   comm -3 \
     <(jq -r '.provides.hooks[]' .claude/extensions/core/manifest.json | sort) \
     <(ls .claude/extensions/core/hooks/*.sh | xargs -n1 basename | sort)
   # expect empty output
   ```
3. **Merge simulation against BimodalLogic** (the confirmed-broken target repo) without running nvim, using a throwaway copy to avoid mutating the real project:
   ```bash
   cp -r /home/benjamin/Projects/BimodalLogic /tmp/bimodal-test
   cd /tmp/bimodal-test
   jq -s '.[0] * .[1]' .claude/settings.json \
     /home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/settings-hooks.json \
     > /tmp/merged-settings.json
   diff <(jq -S . .claude/settings.json) <(jq -S . /tmp/merged-settings.json)
   ```
   Expect: `UserPromptSubmit`/`Stop`/`SessionStart` unchanged (BimodalLogic's settings.json already has these exact entries — this specific repo's bug is Bug A, not Bug B), demonstrating the merge is a true no-op/idempotent here. To exercise the actual registration-merge behavior, additionally test against a settings.json with those keys stripped:
   ```bash
   jq 'del(.hooks.UserPromptSubmit, .hooks.Stop, .hooks.SessionStart)' .claude/settings.json > /tmp/stripped-settings.json
   # then re-run the loader's merge_settings via a small nvim --headless harness (see step 5) against /tmp/stripped-settings.json
   # expect: UserPromptSubmit/Stop/SessionStart re-appear with exactly the fragment's entries, permissions/deny/env untouched
   ```
4. **Script-copy fix verification**: after fixing `provides.hooks`, re-run "Load Extension" (or "Load Core") against `/tmp/bimodal-test` and confirm both missing files now appear and the hook no longer exits 127:
   ```bash
   test -f /tmp/bimodal-test/.claude/hooks/wezterm-preflight-status.sh && echo OK
   test -f /tmp/bimodal-test/.claude/hooks/wezterm-utils.sh && echo OK
   cd /tmp/bimodal-test && bash .claude/hooks/wezterm-preflight-status.sh; echo "exit: $?"
   ```
5. **Headless nvim harness** (exercises the real Lua code, not a jq approximation):
   ```bash
   nvim --headless -u NONE --cmd "set rtp+=/home/benjamin/.config/nvim" \
     -c "lua local merge = require('neotex.plugins.ai.shared.extensions.merge'); \
         local ok, tracked = merge.merge_settings('/tmp/stripped-settings.json', vim.json.decode(io.open('/home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/settings-hooks.json'):read('a'))); \
         print(ok, vim.inspect(tracked))" \
     -c "qa"
   cat /tmp/stripped-settings.json  # inspect result
   ```
   Then re-run the same command a second time and diff the file before/after to confirm idempotency (no duplicate array entries).
6. **State-independence patch verification**: after patching `reinject_loaded_extensions` (Finding 2, step 4), simulate a repo with **no** `extensions.json` at all (or one where `core` is absent), run the equivalent of `load_all_globally`'s tail call, and confirm `merge_targets.settings` (and the pre-existing `claudemd`/`index` targets) are applied despite `core` never being "loaded" in state — this is the regression test proving Bug B is actually closed, not just theoretically addressed.
7. **Regression check**: confirm existing `lean`/`nix`/`epidemiology` `settings.local.json` merge behavior is unaffected (different target file, untouched by this change) by re-reading their manifests after the edit — no diff expected.

## Decisions

- Target the new fragment at `.claude/settings.json` (tracked/committed), not `.claude/settings.local.json`, because hooks are required agent-system functionality, not personal MCP/permission preference — this deliberately diverges from the `lean`/`nix`/`epidemiology` precedent's target file while reusing their exact `merge_targets.settings` schema shape.
- Recommend fixing the stale `provides.hooks` allow-list (Bug A) as a **prerequisite**, independent of and unconditionally required regardless of which settings-merge approach is chosen — it is the actually-manifesting bug on the one live target repo checked.
- Recommend patching `reinject_loaded_extensions` to unconditionally include `"core"` rather than requiring users to separately "Load Extension" core before "Load Core" works — this matches the semantic expectation that "Load Core" alone is suf's to get a working core agent system, and closes a second, pre-existing latent gap (defense-in-depth re-injection of `claudemd`/`index` was already broken for pure-"Load Core" repos).
- Scope the settings fragment narrowly to the 3 wezterm-relevant event/matcher rows, not a full copy of canonical settings.json's `hooks` object, to avoid the fix silently also merging unrelated hook registrations (state-file guards, TTS notification, subagent postflight) that may legitimately differ per target repo.

## Risks & Mitigations

- **Risk**: `deep_merge`'s array-append (not array-replace) semantics mean a target with a customized `Stop`/`UserPromptSubmit` matcher already present ends up with two array entries for the same `"*"` matcher instead of one combined entry. **Mitigation**: This is safe (Claude Code runs all matching entries) but slightly untidy; document in a code comment at the `merge_targets.settings` declaration. Not worth a bigger change given the safety trade-off.
- **Risk**: Command-path drift (Section 4c) is not self-healing via `merge_settings`. **Mitigation**: out of scope for this fix; flag as a follow-up (e.g., a periodic `/meta` or `/refresh` check that diffs registered hook commands against `provides.hooks`).
- **Risk**: `.opencode` mirror fix and dotfiles-tree cleanup are adjacent but distinct scopes that could scope-creep this task. **Mitigation**: implement `.claude` fix first (this task); file the `.opencode` manifest fix as a near-duplicate small follow-up (same 3-line edit, different file) and the dotfiles-tree cleanup as a separate, lower-priority task since it is fully disconnected from the loader.

## Context Extension Recommendations

- **Topic**: WezTerm hook registration/merge mechanics and the `provides.hooks` allow-list contract.
  **Gap**: `.claude/context/project/neovim/hooks/wezterm-integration.md` exists but (based on this investigation) does not document that `provides.hooks` in the core manifest is a hard allow-list gate consumed by both `copy_hooks` (extension-load) and the sync allow-list filter (Load Core), nor that adding a new hook script requires updating `provides.hooks` in **both** `.claude/extensions/core/manifest.json` and `.opencode/extensions/core/manifest.json`.
  **Recommendation**: Add a short "Adding a new hook script" checklist to `wezterm-integration.md` (or a new `.claude/context/project/neovim/hooks/hook-registration-checklist.md`) covering: (1) add script to `extensions/core/hooks/`, (2) add filename to `provides.hooks` in both core manifests, (3) if a settings.json event registration is needed, add/update the relevant `merge_targets.settings` fragment.

## Appendix

### Search queries / commands used
- `find . -iname "sync.lua" -print -o -iname "merge.lua" -print`
- `jq '.hooks' .claude/settings.json`, same for `~/.config/.claude/settings.json`, `.claude/extensions/core/root-files/settings.json`, BimodalLogic's `.claude/settings.json`
- `grep -n "CLAUDE_STATUS\|TASK_NUMBER\|format-tab-title\|update-status" ~/.config/wezterm/wezterm.lua`
- `grep -rl "\"settings\"" .claude/extensions/*/manifest.json` (found `lean`, `nix`, `epidemiology`)
- `bash .claude/hooks/wezterm-preflight-status.sh` in BimodalLogic (exit 127, confirmed missing file)
- `jq '.extensions.core' /home/benjamin/Projects/BimodalLogic/.claude/extensions.json`
- `diff .claude/extensions/core/hooks/wezterm-preflight-status.sh .opencode/extensions/core/hooks/wezterm-preflight-status.sh`

### Key files referenced (file:line)
- `.claude/extensions/core/manifest.json:7-17` (merge_targets), `:118-129` (provides.hooks, stale)
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua:212-282` (`reinject_loaded_extensions`), `:701-932` (`scan_all_artifacts`), `:860-921` (root_files / settings branch), `:938-1159` (`load_all_globally`)
- `lua/neotex/plugins/ai/shared/extensions/merge.lua:172-257` (`deep_merge`/`merge_settings`), `:259-312` (`unmerge_settings`)
- `lua/neotex/plugins/ai/shared/extensions/loader.lua:54-82` (`copy_file`), `:352-387` (`copy_hooks`), `:551-579` (`copy_root_files`), `:686-749` (`check_conflicts`)
- `lua/neotex/plugins/ai/shared/extensions/init.lua:72-127` (`process_merge_targets`), `:134-162` (`reverse_merge_targets`), `:439-467` (load-flow copy calls)
- `lua/neotex/plugins/ai/shared/extensions/state.lua:151-154` (`is_loaded`), `:228-237` (`list_loaded`)
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua:218-226` (`get_extension`), `:268-292` (`get_core_provides`/`build_allow_list`)
- `~/.config/wezterm/wezterm.lua:306-339` (`format-tab-title`), `:401-426` (`update-status`)
- `.claude/extensions/{lean,nix,epidemiology}/manifest.json` + `settings-fragment.json` (existing `merge_targets.settings` precedent, target `.claude/settings.local.json`)
- `~/.config/git/ignore:1` (`**/.claude/settings.local.json` globally ignored)
