# Implementation Plan: Fix Load Core loader so WezTerm lifecycle tab coloring propagates to all synced repos

- **Task**: 791 - Fix Load Core loader so WezTerm lifecycle tab coloring propagates to all synced repos
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/791_loader_wezterm_status_hook_merge/reports/01_loader-settings-merge.md
- **Artifacts**: plans/01_loader-settings-merge-plan.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: neovim

## Overview

WezTerm lifecycle tab coloring (driven by the `CLAUDE_STATUS` user variable) fails to propagate to repos the agent system is copied into because of two independent, compounding bugs identified by research. Bug A: the core manifest's `provides.hooks` allow-list is stale (phantom `wezterm-clear-status.sh`, missing the scripts the status hooks actually need), silently dropping those scripts from both the "Load Core" bulk-sync and "Load Extension" copy paths. Bug B: the settings.json registration-merge for the wezterm status hooks is never applied to "Load Core"-only repos, because `reinject_loaded_extensions()` is gated on `extensions.json` tracking state that `load_all_globally` never writes. This plan fixes both minimally: reconcile `provides.hooks` in both synced trees, add a `merge_targets.settings` fragment targeting the committed `.claude/settings.json`, patch the re-injection loop to always include `core`, and verify end-to-end against a throwaway copy of `/home/benjamin/Projects/BimodalLogic` including idempotency (Load Core twice = no duplicate entries).

### Research Integration

- Report `01_loader-settings-merge.md` is authoritative and fully integrated. Key facts carried into phases:
  - The settings fragment needs exactly 3 event arrays: `SessionStart`, `Stop`, `UserPromptSubmit` (Report Section 3). `wezterm-notify.sh` and `wezterm-utils.sh` are libraries/indirect scripts and must NOT appear in the fragment — they only need to exist on disk (fixed via `provides.hooks`).
  - Target file MUST be `.claude/settings.json` (committed), NOT `.claude/settings.local.json` (globally gitignored). This deliberately diverges from the lean/nix/epidemiology precedent's target file while reusing their exact `merge_targets.settings` schema shape.
  - `deep_merge`/`merge_settings` (merge.lua:172-257) is append-only, array-deduplicates by `vim.deep_equal` (idempotent for identical re-runs), and never overwrites existing scalars or removes array elements — so it will not clobber project permissions/MCP. It does NOT self-heal drifted command paths (Section 4c) — a documented limitation, out of scope.
  - **Refinement discovered during planning** (extends the report's "add 2 files" framing): the manifest is actually missing FOUR real files vs disk — `claude-stop-notify.sh`, `validate-meta-write.sh`, `wezterm-preflight-status.sh`, `wezterm-utils.sh` — plus the phantom `wezterm-clear-status.sh`. `claude-stop-notify.sh` is the `Stop`-event command in the new fragment, so it MUST be in `provides.hooks` or the `Stop` hook script will not be copied. Phase 1 therefore reconciles the FULL list against disk (matching the report's own verification step 2 `comm -3` expect-empty check), not merely the two wezterm files.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (roadmap flag not set).

## Goals & Non-Goals

**Goals**:
- Reconcile `provides.hooks` in `.claude/extensions/core/manifest.json` and `.opencode/extensions/core/manifest.json` so every real hook script (including the wezterm status scripts and `claude-stop-notify.sh`) is copied to target repos.
- Add `.claude/extensions/core/merge-sources/settings-hooks.json` (3 event arrays) and declare `merge_targets.settings` in the core manifest targeting `.claude/settings.json`.
- Patch `reinject_loaded_extensions()` in sync.lua to unconditionally include `"core"` so "Load Core"-only repos receive the settings merge.
- Verify end-to-end against a throwaway copy of BimodalLogic: scripts copied AND registered, no exit-127, no clobbering of permissions/MCP, idempotent on repeated Load Core.

**Non-Goals**:
- Redesigning the wezterm.lua color palette or the `TASK_NUMBER` title mechanism (already works).
- Fixing command-path drift self-healing (`unmerge` before re-merge) — documented limitation, follow-up only.
- Fixing the disconnected dotfiles `~/.config/.claude` tree (out of scope per report Section 5 — not read by the loader; `scan.get_global_dir()` resolves to `~/.config/nvim`).
- Resolving the `.opencode` `wezterm-preflight-status.sh` textual content drift (separate follow-up per report Section 5).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `deep_merge` array-append yields two `"*"` matcher entries when target already has one for `Stop`/`UserPromptSubmit` | L | M | Safe (Claude Code runs all matching entries). Add a one-line code comment at the `merge_targets.settings` declaration noting the append semantics. Verified in Phase 4. |
| Reconciling the FULL `provides.hooks` list adds files (e.g. `validate-meta-write.sh`) beyond the wezterm scope | L | L | These are real on-disk hooks that SHOULD ship; adding them is correct per report verification step 2. Verify with `comm -3` expect-empty in Phase 1. |
| Fragment references `claude-stop-notify.sh` but it is absent from `provides.hooks` | H | Handled | Phase 1 (reconcile) is a prerequisite of Phase 2 (fragment) precisely so the `Stop` script ships. |
| Command-path drift not self-healed by `merge_settings` | M | L | Out of scope; document as follow-up risk in code comment (report Section 4c). |
| Editing `provides.hooks` and `merge_targets` in the same `manifest.json` file causes conflicting concurrent edits | L | L | Serialize: Phase 2 depends on Phase 1 so manifest.json is edited sequentially. |
| `.opencode` mirror or dotfiles cleanup scope-creeps the task | M | M | `.opencode` allow-list fix IS in scope (Phase 1); dotfiles tree and `.opencode` content drift are explicitly deferred to follow-ups. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Reconcile core manifest `provides.hooks` in both synced trees [COMPLETED]

- **Goal:** Make `provides.hooks` a faithful 1:1 allow-list of the real hook scripts on disk in both `.claude` and `.opencode` core manifests, so no status-hook script is silently dropped during copy.
- **Tasks:**
  - [x] Edit `.claude/extensions/core/manifest.json` `provides.hooks`: remove phantom `"wezterm-clear-status.sh"`; add `"claude-stop-notify.sh"`, `"validate-meta-write.sh"`, `"wezterm-preflight-status.sh"`, `"wezterm-utils.sh"`. Final array must equal the 14 `.sh` files in `.claude/extensions/core/hooks/`.
  - [x] Apply the identical reconciliation to `.opencode/extensions/core/manifest.json` `provides.hooks` (same stale phantom and omissions confirmed present). Reconcile against the `.opencode` tree's own `extensions/core/hooks/` disk contents (verify the `.opencode` hooks dir file list; it may differ slightly from `.claude` — reconcile each manifest against its own tree, not a shared assumption).
  - [x] Validate both manifests parse as JSON.
- **Timing:** 30-40 minutes
- **Depends on:** none
- **Files to modify:**
  - `.claude/extensions/core/manifest.json` — `provides.hooks` array (~lines 118-129)
  - `.opencode/extensions/core/manifest.json` — `provides.hooks` array
- **Verification:**
  ```bash
  cd /home/benjamin/.config/nvim
  jq . .claude/extensions/core/manifest.json >/dev/null && echo "claude JSON OK"
  jq . .opencode/extensions/core/manifest.json >/dev/null && echo "opencode JSON OK"
  # expect EMPTY output (full reconciliation, no phantom, no omission)
  comm -3 \
    <(jq -r '.provides.hooks[]' .claude/extensions/core/manifest.json | sort) \
    <(ls .claude/extensions/core/hooks/*.sh | xargs -n1 basename | sort)
  comm -3 \
    <(jq -r '.provides.hooks[]' .opencode/extensions/core/manifest.json | sort) \
    <(ls .opencode/extensions/core/hooks/*.sh | xargs -n1 basename | sort)
  ```
  Phase is green when both JSON validations pass and both `comm -3` invocations print nothing.

---

### Phase 2: Add settings-hooks.json fragment and declare `merge_targets.settings` [COMPLETED]

- **Goal:** Ship the 3-event wezterm status-hook registration fragment via the existing generic merge-target machinery, targeting the committed `.claude/settings.json`.
- **Tasks:**
  - [x] Create `.claude/extensions/core/merge-sources/settings-hooks.json` with exactly the 3 event arrays (`SessionStart` -> `wezterm-clear-task-number.sh`; `Stop` -> `claude-stop-notify.sh`; `UserPromptSubmit` -> `wezterm-task-number.sh` then `wezterm-preflight-status.sh`), each command wrapped `... 2>/dev/null || echo '{}'`, per report Section 3. Do NOT include `wezterm-notify.sh`, `wezterm-utils.sh`, or any `PreToolUse`/`PostToolUse`/`SubagentStop`/`Notification` entries.
  - [x] Add a `settings` entry to `merge_targets` in `.claude/extensions/core/manifest.json`: `{ "source": "merge-sources/settings-hooks.json", "target": ".claude/settings.json" }`. Match the schema shape used by the lean/nix/epidemiology manifests, but with target `.claude/settings.json` (NOT `.claude/settings.local.json`).
  - [x] Add a short comment (in the fragment via a `"_comment"` key, or in the manifest region if JSON comments are unsupported — confirm which the loader tolerates) noting: (a) `deep_merge` append semantics may produce a second `"*"` matcher entry for targets that already have one — safe but untidy; (b) `merge_settings` does not self-heal drifted command paths (follow-up risk, report Section 4c). *(deviation: altered — placed the `_comment` on the manifest's `merge_targets.settings` entry itself, not inside the merge-sources fragment. `process_merge_targets`/`reinject_loaded_extensions` only read `.source`/`.target` from this object, ignoring extra keys, so this is safe; putting it in the fragment instead would have injected a literal `_comment` key into every target repo's committed `.claude/settings.json` via `deep_merge`, which is undesirable pollution.)*
  - [x] Validate the fragment and manifest parse as JSON.
- **Timing:** 40-50 minutes
- **Depends on:** 1
- **Files to modify:**
  - `.claude/extensions/core/merge-sources/settings-hooks.json` — new file
  - `.claude/extensions/core/manifest.json` — `merge_targets` object (~lines 7-17)
- **Verification:**
  ```bash
  cd /home/benjamin/.config/nvim
  jq . .claude/extensions/core/merge-sources/settings-hooks.json >/dev/null && echo "fragment JSON OK"
  jq -e '.merge_targets.settings.target == ".claude/settings.json"' .claude/extensions/core/manifest.json && echo "target OK"
  # fragment declares exactly the 3 expected events and no others
  jq -r '.hooks | keys | sort | join(",")' .claude/extensions/core/merge-sources/settings-hooks.json
  # expect: SessionStart,Stop,UserPromptSubmit
  # Stop event references claude-stop-notify.sh (which Phase 1 added to provides.hooks)
  jq -e '.hooks.Stop[0].hooks[0].command | test("claude-stop-notify.sh")' .claude/extensions/core/merge-sources/settings-hooks.json && echo "Stop cmd OK"
  # every command referenced by the fragment is present in provides.hooks
  for f in wezterm-clear-task-number.sh claude-stop-notify.sh wezterm-task-number.sh wezterm-preflight-status.sh; do
    jq -e --arg f "$f" '.provides.hooks | index($f)' .claude/extensions/core/manifest.json >/dev/null \
      && echo "$f in provides.hooks" || echo "MISSING $f in provides.hooks"
  done
  ```
  Phase is green when the fragment parses, the target is `.claude/settings.json`, keys are exactly the 3 events, the `Stop` command references `claude-stop-notify.sh`, and all 4 fragment-referenced scripts are present in `provides.hooks`.

---

### Phase 3: Patch `reinject_loaded_extensions` to always include core [COMPLETED]

- **Goal:** Close Bug B so a repo that only ever ran "Load Core" (no `extensions.json` core entry) still receives the `merge_targets.settings` (and pre-existing `claudemd`/`index`) re-injection.
- **Tasks:**
  - [x] In `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`, `reinject_loaded_extensions()` (~lines 212-282), after `local loaded_names = state_mod.list_loaded(state)` (~line 222), unconditionally ensure `"core"` is present in `loaded_names` when absent (insert at front). Follow the report's snippet (Section 2, step 4). *(deviation: altered — also removed the now-unreachable `if #loaded_names == 0 then return end` early-exit guard that followed, since inserting "core" guarantees loaded_names is never empty after this point; leaving it would have been dead code)*
  - [x] Add a brief comment explaining WHY: "Load Core" (`load_all_globally`) never writes state, so `core` is never state-tracked; it is definitionally in scope for Load Core regardless of `extensions.json`.
  - [x] Confirm no `pcall`/nil-safety regression: `loaded_names` is a list; guard against it being nil before iterating (use `loaded_names or {}`).
- **Timing:** 25-35 minutes
- **Depends on:** none
- **Files to modify:**
  - `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` — `reinject_loaded_extensions()` (~lines 212-282)
- **Verification:**
  ```bash
  cd /home/benjamin/.config/nvim
  # Lua loads without syntax error
  nvim --headless -u NONE --cmd "set rtp+=/home/benjamin/.config/nvim" \
    -c "lua local ok, m = pcall(require, 'neotex.plugins.ai.claude.commands.picker.operations.sync'); print('load:', ok)" \
    -c "qa" 2>&1 | grep -E "load: true" && echo "module loads"
  # confirm the always-include-core logic exists textually
  grep -n '"core"' lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua | head
  ```
  Phase is green when the module loads without error and the always-include-core branch is present in `reinject_loaded_extensions`.

---

### Phase 4: End-to-end verification and idempotency against BimodalLogic copy [NOT STARTED]

- **Goal:** Prove all three fixes work together on a real broken target without mutating the real project: scripts copied, hooks registered, no exit-127, no clobbering, idempotent on repeated Load Core.
- **Tasks:**
  - [ ] Copy `/home/benjamin/Projects/BimodalLogic` to `/tmp/bimodal-test` (throwaway; never touch the real repo).
  - [ ] Static merge simulation: confirm merging the fragment into a settings.json that HAS the keys is a no-op, and into one with the keys stripped re-adds exactly the fragment entries with permissions/MCP untouched (report verification steps 3).
  - [ ] Headless nvim harness: call `merge.merge_settings` against `/tmp/stripped-settings.json` twice; diff before/after the second run to confirm NO duplicate array entries (idempotency; report step 5).
  - [ ] Script-copy check: after the manifest fix, confirm `wezterm-preflight-status.sh`, `wezterm-utils.sh`, and `claude-stop-notify.sh` now appear in a copy target's `.claude/hooks/` and that `bash wezterm-preflight-status.sh` no longer exits 127 (report step 4).
  - [ ] State-independence check: simulate a target with no `core` entry in `extensions.json`; confirm `merge_targets.settings` (and `claudemd`/`index`) still applied after the reinject patch (report step 6).
  - [ ] Regression check: confirm lean/nix/epidemiology `settings.local.json` merge behavior is unaffected (different target file) — no diff to their manifests (report step 7).
  - [ ] Cleanup: `rm -rf /tmp/bimodal-test /tmp/stripped-settings.json /tmp/merged-settings.json`.
- **Timing:** 45-60 minutes
- **Depends on:** 1, 2, 3
- **Files to modify:** none (verification only; operates on `/tmp` throwaway copies)
- **Verification:**
  ```bash
  cd /home/benjamin/.config/nvim
  cp -r /home/benjamin/Projects/BimodalLogic /tmp/bimodal-test
  # 1) no-op merge on a settings.json that already has the keys
  jq -s '.[0] * .[1]' /tmp/bimodal-test/.claude/settings.json \
    .claude/extensions/core/merge-sources/settings-hooks.json > /tmp/merged-settings.json
  diff <(jq -S .hooks /tmp/bimodal-test/.claude/settings.json) <(jq -S .hooks /tmp/merged-settings.json) \
    && echo "no-op merge OK (idempotent on already-registered repo)"
  # 2) stripped repo -> keys reappear, permissions untouched
  jq 'del(.hooks.UserPromptSubmit, .hooks.Stop, .hooks.SessionStart)' \
    /tmp/bimodal-test/.claude/settings.json > /tmp/stripped-settings.json
  nvim --headless -u NONE --cmd "set rtp+=/home/benjamin/.config/nvim" \
    -c "lua local merge = require('neotex.plugins.ai.shared.extensions.merge'); \
        local frag = vim.json.decode(io.open('/home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/settings-hooks.json'):read('a')); \
        merge.merge_settings('/tmp/stripped-settings.json', frag); \
        merge.merge_settings('/tmp/stripped-settings.json', frag)" \
    -c "qa"
  # after TWO merges, each event has exactly the fragment's entry count (no duplicates)
  jq '.hooks.Stop | length, .hooks.SessionStart | length, .hooks.UserPromptSubmit[0].hooks | length' /tmp/stripped-settings.json
  # permissions/env preserved
  jq -e '.permissions // .env // "present"' /tmp/stripped-settings.json >/dev/null && echo "non-hook keys preserved"
  rm -rf /tmp/bimodal-test /tmp/stripped-settings.json /tmp/merged-settings.json
  ```
  Phase is green when: the already-registered repo merge is a true no-op; the stripped repo regains the 3 events; running the merge twice produces no duplicate array entries; and non-hook keys (permissions/MCP/env) are preserved.

## Testing & Validation

- [ ] Both core manifests parse as JSON and `provides.hooks` fully reconciles against on-disk hooks (`comm -3` empty) in each tree.
- [ ] `settings-hooks.json` parses, declares exactly `SessionStart`/`Stop`/`UserPromptSubmit`, and every command it references is present in `provides.hooks`.
- [ ] `merge_targets.settings.target == ".claude/settings.json"` (committed file, not `.local`).
- [ ] `sync.lua` loads headlessly without error and `reinject_loaded_extensions` always includes `core`.
- [ ] Merge into an already-registered settings.json is a no-op (idempotent); merge into a stripped one re-adds exactly the fragment entries.
- [ ] Running the merge twice produces zero duplicate array entries.
- [ ] Project-specific `permissions`/MCP/`env` keys are never clobbered.
- [ ] Copied target `.claude/hooks/` now contains `wezterm-preflight-status.sh`, `wezterm-utils.sh`, `claude-stop-notify.sh`; `wezterm-preflight-status.sh` no longer exits 127.
- [ ] lean/nix/epidemiology `settings.local.json` merge behavior unaffected (regression check).

## Artifacts & Outputs

- `.claude/extensions/core/manifest.json` — reconciled `provides.hooks` + new `merge_targets.settings`.
- `.opencode/extensions/core/manifest.json` — reconciled `provides.hooks`.
- `.claude/extensions/core/merge-sources/settings-hooks.json` — new 3-event registration fragment.
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` — patched `reinject_loaded_extensions`.
- `specs/791_loader_wezterm_status_hook_merge/plans/01_loader-settings-merge-plan.md` (this file).
- `specs/791_loader_wezterm_status_hook_merge/summaries/01_loader-settings-merge-summary.md` (on /implement).

## Rollback/Contingency

- All edits are localized to 3 tracked files plus 1 new file; revert via `git checkout -- <file>` and `rm .claude/extensions/core/merge-sources/settings-hooks.json`.
- Verification operates only on `/tmp` throwaway copies; the real BimodalLogic repo is never mutated.
- If the merge produces undesirable duplicate entries in practice, the fragment can be narrowed or the `merge_targets.settings` declaration removed without affecting the Phase 1 allow-list fix (the two fixes are independent — Phase 1 alone repairs the actually-manifesting exit-127 bug on the verified target).
