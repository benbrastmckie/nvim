# Loader Settings-Defaults Surface — Seed Report

## Metadata

- **Task**: `583 - Add a settings-defaults surface to the agent system loader picker`
- **Started**: `2026-11-11T02:30:00Z`
- **Completed**: `2026-11-11T02:55:00Z`
- **Effort**: seed only (~25 min of direct measurement); full research not attempted
- **Dependencies**: 369 (shares `extensions/init.lua`), 563 (repo registry unusable for deploy enumeration)
- **Sources/Inputs**:
  - `lua/neotex/plugins/ai/shared/extensions/loader.lua` (descriptor table, install-once guard)
  - `lua/neotex/plugins/ai/shared/extensions/init.lua` (manager; single deploy engine)
  - `lua/neotex/plugins/ai/shared/extensions/merge.lua` (`write_json`, `deep_merge`)
  - `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` (special-entry pattern)
  - `lua/neotex/plugins/ai/claude/commands/picker/init.lua` (entry handlers)
  - `lua/neotex/plugins/ai/plugins/ai/claude/commands/picker/operations/sync.lua` (OpenCode install-only precedent)
  - `agent-system/extensions/core/manifest.json` (`provides.root_files`, `provides.settings`)
  - `agent-system/extensions/core/root-files/settings.{json,local.json}`
  - `~/.claude/settings.json` (global, Home-Manager-managed)
  - Live `.claude/settings.local.json` across 13 repos under `~`, `~/Projects`, `~/.dotfiles`
  - `claude --help` (flag surface)
- **Artifacts**: this report
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- The **enforcement half already exists and is verified working**: a per-key carve-out from the
  install-once guard re-asserts source-store-declared keys into an existing deployed settings
  file on every load. What is missing is a UI and a considered governed-key list.
- **One deploy engine serves every path.** `deploy-headless.sh` drives the same Lua `manager` as
  the interactive picker, so a single insertion point covers `<leader>al` and headless deploys.
- **`model` is the strongest addition**: measured drift includes a repo pinned to a stale
  `claude-opus-4-5-20251101` and two repos with no key at all.
- **`permissions` must never be governed.** Per-repo allow-lists run 1–68 entries against a
  46-entry template; governing it would delete real accumulated approvals.
- **The global settings file is not a maintenance burden to eliminate** — it is declaratively
  owned by Home Manager, and several of its keys cannot function per-repo.
- **Cross-repo propagation cannot be promised** until the repo-registry enumeration record lands.

## Context & Scope

In scope: the `<leader>al` picker as a control surface for agent-system-governed session
defaults, the governed-key list and where it is declared, per-key validation, and how a change
propagates.

Out of scope, with reasons recorded in Findings: the user-global `~/.claude/settings.json`,
`permissions` handling, and the loader's existing extension-toggle behavior.

Constraint spanning two trees: `lua/neotex/plugins/ai/**` is ordinary tracked configuration and
is edited directly; `agent-system/extensions/core/**` is the source store and its deployed
`.claude/**` mirror must never be hand-authored.

## Findings

### F1. The reconcile mechanism exists and is verified

`loader.lua` now carries `AUTHORITATIVE_ROOT_FILE_KEYS`
(`{["settings.local.json"] = {"outputStyle"}}`) and `reconcile_authoritative_keys()`, wired into
the install-once skip branch of `copy_category` and declared on the `root_files` descriptor as
`authoritative_keys`. Behavior was exercised against the real `copy_category` entry point with
scratch source and target directories, not by inspection:

| Case | Observed |
|---|---|
| Governed key differs at target | overwritten from template |
| Non-governed hand-edited keys present | preserved |
| Template key not in the governed list | not injected |
| Target JSON malformed | left byte-identical, not truncated |
| Governed key absent from template | target value preserved (absence is not a delete) |
| Already at governed value | file byte-identical, no reflow |

Writes go through `merge.write_json`, which pretty-prints via `jq` and falls back to compact
encoding on `jq` failure.

**Not yet verified**: behavior under a full real deploy. Scratch directories were used because a
concurrent session held in-flight work in this repo. Confirm end to end before relying on it.

### F2. One deploy engine, so one insertion point suffices

`deploy-headless.sh`'s own header states it "drives the manifest-driven extension loader
(`neotex.plugins.ai.shared.extensions.init`'s `manager`) headlessly -- the single deploy engine,
reachable both interactively (the picker's...) and headlessly". The reconcile therefore applies
to every deploy path without duplication.

### F3. Measured drift across 13 repos

Measured 2026-11-11 over every `.claude/settings.local.json` under `~`, `~/Projects` and
`~/.dotfiles`:

| Key | Observed spread | Governance verdict |
|---|---|---|
| `model` | `opus` in 10; absent in ModelBuilder and VSCodium; `claude-opus-4-5-20251101` in protocol | **Govern** — a stale pin silently selects an old model |
| `enableAllProjectMcpServers` | `true` in 12; absent in VSCodium | **Govern** — binary policy |
| `enabledMcpjsonServers` | `["lean-lsp"]` in 12; absent in VSCodium | Optional — no drift; note it is set even in non-Lean repos |
| `outputStyle` | now `Concise` in 11; absent in protocol, VSCodium | Already governed |
| `permissions.allow` | 0, 1, 1, 44, 44, 49, 50, 51, 53, 65, 66, 68, 68 entries | **Never govern** |

The `permissions` row is the decisive non-goal. The template declares 46 allow entries;
BimodalHarness carries 68. Governing the key would overwrite 22 real approvals, which is exactly
the loss the install-once guard was introduced to prevent.

### F4. Two mechanisms already exist and neither can flip an existing value

- **Install-once** (`INSTALL_ONCE_ROOT_FILES`, `loader.lua`): `settings.json` and
  `settings.local.json` are copied only when absent. Its comment records the motivation — "a
  hand-edited project settings file must survive every future 'Load Core' / extension reload".
  Consequence: a template edit never reaches a repo that already has the file.
- **`deep_merge`** (`merge.lua`, used by `provides.settings` → `merge-sources/settings-hooks.json`
  → `.claude/settings.json`): its scalar branch is explicitly "Scalar: only add if not exists
  (don't overwrite)". It can add a missing key but cannot change `"default"` to `"Concise"`.

Neither is a defect; both are deliberate. The authoritative-key carve-out in F1 is the narrowest
available third option.

### F5. The global settings file is managed, and parts of it cannot move

`~/.claude/settings.json` carries a `_NOTE` stating it is "Managed by Home Manager via
`~/.dotfiles/config/claude/settings.json`", merged rather than copied on switch, with `_NOTE`,
`env`, `hooks`, `model`, `permissions` and `statusLine` **force-restored** to repo values and
every other key keeping its live value.

| Layer | Keys | Can it move into this repo? |
|---|---|---|
| Global, enforced | `env` (`ANTHROPIC_DEFAULT_*_MODEL`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS`, `LITERATURE_DIR`, `PG_EXPIRY_WINDOW`) | No — process-level; per-repo copies fragment model routing |
| Global, enforced | `hooks` (systemd sleep-inhibitor; Sapience entries owned by `sapience.nix`) | No — a switch reverts anything written elsewhere |
| Global, enforced | `statusLine` | No — machine-level |
| Global, non-enforced | `editorMode`, `voice*`, `recapEnabled`, `autoCompactEnabled`, notification toggles | No, by design — left live so `/config` edits survive rebuilds |
| Per-repo | `outputStyle`, `model`, `enableAllProjectMcpServers`, `enabledMcpjsonServers` | Yes — these are this record's subject |
| Per-repo | `permissions` | No — see F3 |

A `model` note in global `env` matters for F3's recommendation: `ANTHROPIC_DEFAULT_OPUS_MODEL` is
declared "the single source of truth for the default Opus/Sonnet models". Governing per-repo
`model: opus` resolves through that alias rather than competing with it, which is why `opus` and
not a pinned ID is the right governed value.

### F6. No CLI flag route exists

Verified from `claude --help`: there is no `--output-style` flag. `--output-format` is
`--print`-mode only and `--brief` enables a messaging tool. Settings files are the only
persistent mechanism, so the picker cannot delegate to a flag.

### F7. The picker's special-entry pattern is the model to copy

`display/entries.lua` builds three special entries — `[Reload All]`, `[Regenerate]`,
`[Global Update]` — each with `entry_type = "special"`, an `is_*` flag, a `name` sorted with a
`~~~` prefix, a `%-40s %s` `display` line, and a `detail` array whose convention is to state
destructiveness explicitly. Handlers live in `picker/init.lua` keyed off the `is_*` flags.
`entry_type` already includes a `root_file` value, and seventeen entry types exist in total.

Propagation scope per entry, from their own `detail` text: `[Reload All]` and `[Regenerate]` are
current-repo only; `[Global Update]` iterates the repo registry and resyncs each registered
repo's own loaded set.

### F8. Two hazards specific to this feature

- **`manager.wipe` restores `settings.local.json`.** `[Regenerate]`'s documented sequence is
  "snapshot -> rm -rf base_dir -> regenerate -> restore `settings.local.json` and `.syncprotect`
  paths -> clear staging". If the restore runs after the reconcile, a governed key reverts to its
  pre-wipe value on the destructive path. Confirm the ordering.
- **The repo registry is unsound for enumeration.** The registry backing `[Global Update]` is
  `~/.local/share/nvim/neotex-ai/extension-repo-registry.json` (58 KB). The open record this task
  depends on measures it at 313 entries, most unusable as a deploy-enumeration source. Any claim
  that a defaults change reaches "every repo" is unsupportable until that lands.

### F9. `.syncprotect` is not an obstacle

The project-root `.syncprotect` lists one path (`context/repo/project-overview.md`), so no
settings file is sync-protected and the reconcile is not blocked by it.

## Decisions

Decisions already taken and implemented, recorded so the dispatch does not relitigate them:

1. **D1 — Per-key carve-out, not whole-file overwrite.** Install-once protection is retained for
   the file; only declared keys are re-asserted. Rejected: making `settings.local.json` a normal
   overwritten root file, which would destroy per-repo permissions.
2. **D2 — Reconcile fails soft.** Any unreadable or malformed input leaves the target untouched,
   because the skip it replaces is already the conservative outcome.
3. **D3 — Template absence is not a delete instruction.** A governed key missing from the
   template leaves the target's value alone.
4. **D4 — `outputStyle` governed value is `Concise`.** `Concise` was confirmed a usable value in
   practice; authoring a custom style file is unnecessary.
5. **D5 — Writes go through `merge.write_json`.** Reuses the established jq pretty-printer rather
   than introducing a second JSON writer.

Decisions this record explicitly leaves open: picker shape (single entry vs. submenu vs. section),
whether the governed-key list becomes manifest data, per-key allowed-value declaration, and the
final governed-key set beyond the recommendations below.

## Recommendations

1. **Confirm F1 end to end under a real deploy** before building UI on top of it. Highest
   priority and cheapest; everything else assumes it.
2. **Add `model` to the governed list**, value `opus`. Repairs the stale pin in protocol and the
   two absent keys, and composes with the global `ANTHROPIC_DEFAULT_OPUS_MODEL` alias.
3. **Add `enableAllProjectMcpServers`**, value `true`. Trivial, closes the one gap.
4. **Promote the governed-key list to data** if, and only if, the picker needs per-key labels and
   allowed values. Otherwise leave it as the Lua table and keep the diff small.
5. **Build the picker entry on the F7 pattern**, stating propagation scope in `detail` text and
   not implying cross-repo reach.
6. **Resolve F8's wipe-ordering question** before shipping, or the destructive path silently
   undoes the feature.
7. **Dispose of the subsumed output-style record** rather than running it alongside this one.
8. **Leave `permissions`, `enabledMcpjsonServers` and every global key alone**, per F3 and F5.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| A governed key added carelessly deletes per-repo state | Keep the list minimal; require a drift measurement before adding a key; `permissions` named as a permanent non-goal |
| Invalid value written, failing silently at session start | Per-key allowed-value list and selection-time validation (owed item 3) |
| `[Regenerate]` reverts a governed key | Resolve the restore-vs-reconcile ordering in F8 |
| Operator believes a change propagated everywhere | State current-repo scope in the entry's `detail`; do not claim global reach while the registry record is open |
| Divergence from the OpenCode install-only path in `operations/sync.lua` | That path has its own `root_file_names` install-only handling; decide explicitly whether it needs the same carve-out or is deliberately excluded |

## Context Extension Recommendations

- No context document currently describes the settings layering across global, `settings.json`,
  `settings.local.json` and the source-store template. F5's table is the only written form; if
  this feature lands, that table belongs in a durable context file rather than only in a report.

## Appendix

Verification commands used, for re-derivation:

```bash
# drift across repos
for d in ~/.config/nvim ~/.dotfiles ~/Projects/*/; do
  f="$d/.claude/settings.local.json"; [ -f "$f" ] || continue
  printf '%-28s model=%-10s style=%-9s permAllow=%s\n' "$(basename "$d")" \
    "$(jq -r '.model // "ABSENT"' "$f")" "$(jq -r '.outputStyle // "ABSENT"' "$f")" \
    "$(jq -r '(.permissions.allow // []) | length' "$f")"
done

# global enforced-key note
jq -r '._NOTE' ~/.claude/settings.json

# install-once and deep_merge scalar semantics
grep -n -A4 'INSTALL_ONCE_ROOT_FILES = ' lua/neotex/plugins/ai/shared/extensions/loader.lua
grep -n "Scalar: only add if not exists" lua/neotex/plugins/ai/shared/extensions/merge.lua

# flag surface
claude --help | grep -oE '^\s+--[a-z-]+' | sort -u
```
