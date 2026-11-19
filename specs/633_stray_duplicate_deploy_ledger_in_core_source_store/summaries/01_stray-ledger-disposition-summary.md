# Summary: Stray duplicate deploy ledger in the core source store

- **Status**: [COMPLETED]
- **Disposition**: deleted
- **Measured**: 2026-11-19

## What was there

`agent-system/extensions/core/.claude-extensions.json` — 68,178 bytes, untracked, mtime
2026-11-12 01:03:27 -0800, with an internal `loaded_at` of `2026-11-12T09:03:27Z` (the same
instant). Schema-identical to the real root ledger: same top-level `extensions`/`version` keys,
same per-extension field set.

## How it got there

The Neovim extension picker wrote it. `lua/neotex/plugins/ai/shared/extensions/init.lua`
resolves its load target as `project_dir = opts.project_dir or vim.fn.getcwd()` at four call
sites, and `lua/neotex/plugins/ai/shared/extensions/state.lua` appends the configured
`root_state_file` to whatever that yields. There is no git-root resolution and no guard that the
cwd is a project root rather than a directory inside a source store, so a load run from inside
`agent-system/extensions/core/` writes its ledger there.

The ledger's `source_git_head` was `fe5cfc98b` ("register new scripts in core manifest.json",
committed 01:02:17), one minute before its own timestamp — so a load ran immediately after that
commit from a Neovim whose cwd was the core source store.

## How it diverged from the root ledger

| | stray | root |
|---|---|---|
| `core.installed_files` | 691 | 731 |
| `loaded_at` | 2026-11-12T09:03:27Z | 2026-11-19T20:19:54Z |
| extensions recorded | `core` only | all eight |

It was also a phantom: `installed_dirs` was empty and no `.claude/` tree ever existed beside it,
so the 691 files it claimed to have installed were never present at the paths it named.

## What read it

Two resolvers can reach a nested ledger, and both were measured fail-open in this instance:

- `scripts/validate-artifact.sh`'s `_cgs_find_repo_root` walks **upward** from the artifact's own
  directory to the first `.claude-extensions.json`, so for any path under
  `agent-system/extensions/core/**` it stopped at the stray rather than the root. Silent only
  because neither ledger carries a `coupled_generated_surfaces` key today — both yield `[]`. This
  becomes a wrong answer the day that key is added to the root ledger.
- `scripts/skill-base.sh`'s `skill_get_extension_dir` reads a bare cwd-relative
  `.claude-extensions.json`, so anything invoked with cwd inside the source store saw only `core`
  as active. Silent because extension lifecycle hooks are non-blocking by contract — but it
  already meant every non-core extension's hooks skipped without a trace.

Two further consumers were checked and cannot reach it: `check-consumer-freshness.sh --discover`
scans at `find -maxdepth 3` and the stray sat at depth 4; `deploy-root-guard.sh`'s self-correct
branch would accept such a candidate, but only ever tests the output of
`git rev-parse --show-toplevel`, which is the repository root.

Nothing expects it: it appears in no `manifest.json`, and in no `installed_files` list.

## Acceptance

Met on the "gone" branch: the path was deleted. No resolver can reach a wrong ledger, because
only the root ledger now exists. A byte-identical copy remains inside
`specs/archive/603_roadmap_command_generated_from_state/untracked-backup-1794516883/`, which is
gitignored backup material and not on any resolver's path.

## Follow-on

Disposition is closed; prevention is not, and is tracked separately as `neovim`-type work
against `lua/neotex/plugins/ai/shared/extensions/` — resolve `project_dir` to the git toplevel,
or refuse a load whose cwd resolves under a source store. Without it, the next mis-rooted load
recreates this file.
