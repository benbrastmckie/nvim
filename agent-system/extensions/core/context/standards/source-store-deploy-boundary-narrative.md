# Source Store / Deploy Boundary — Full Narrative

This is the lazily-loaded companion to `rules/source-store-deploy-boundary.md`. The eager core
there carries the path pattern and principle an agent must know **before** writing under
`.claude/**`. This file carries the full resolution procedure, the unreachable-source-store
fallback, a worked example, the Exceptions list, and the Enforcement narrative — detail useful
once an agent is already following the core's one-line resolution instruction, but never itself
a pre-action gate.

## Correct Edit Target — Full Resolution Procedure

The source store's location is machine- and repository-specific, so it is resolved, not assumed.
Follow this procedure:

1. Read `<project-root>/.claude-extensions.json`.
2. Under its `extensions` object, select the entry for the owning extension: `core` for core
   system files (commands, skills, agents, rules, context, hooks, scripts, merge-sources), or the
   extension's own name (e.g. `nix`, `lean`) for extension-owned files.
3. Read that entry's `source_dir` field — an absolute path.
4. Confirm `source_dir` exists on disk.
5. Edit under `<source_dir>/**`, at the path mirroring the deployed one. For example, deployed
   `.claude/hooks/validate-meta-write.sh` mirrors to `<source_dir>/hooks/validate-meta-write.sh`
   (with `source_dir` resolved from the `core` entry).

### If the source store is unreachable

The source store is not reachable from this tree when any of the following holds:
- `.claude-extensions.json` is missing or unparseable.
- The `extensions` object has no entry for the relevant extension.
- The entry has no `source_dir` field.
- The recorded `source_dir` does not exist on disk on this machine.

In any of these cases, do **not** hand-author `.claude/**` as a substitute — it is exactly the
outcome this rule prevents. Instead, record the needed change as a task via `/task`, describing
the deployed path, the intended change, and the reason it could not be made directly. Filing a
task is the sanctioned outcome; a silent report or an in-place `.claude/**` edit is not.

## Worked Example

**Before** (observed anti-pattern, illustrative only):
```
Write .claude/hooks/validate-meta-write.sh
```

**After** (illustrating one machine's resolved value — read `source_dir` from
`.claude-extensions.json` per the procedure above rather than typing this path directly):
```
Write <source_dir>/hooks/validate-meta-write.sh
# e.g. /home/example/repo/agent-system/extensions/core/hooks/validate-meta-write.sh
```

## Exceptions

- Writes under `specs/**` (task-management artifacts) are unaffected — task creation and
  artifact authoring there is legitimate regardless of lifecycle stage.
- The deploy/reload process, which writes the entire `.claude/` tree by design, is not a
  violation.

## Enforcement

Two layers, neither of which alone is a guarantee:

- **Advisory hook**: `validate-meta-write.sh` (PostToolUse, non-blocking) fires on `Write`/`Edit`
  targeting `.claude/**` paths (including `.claude/scripts/**` and `.claude/hooks/**`) and injects
  a corrective `additionalContext` message naming the correct source-store target. It never
  blocks the write.
- **Agent reinforcement**: implementer-agent contracts include a MUST NOT bullet against
  hand-authoring `.claude/**` files (see agent files).

**Known limitation**: a PostToolUse hook sees only a `file_path` argument. It cannot know task
type, lifecycle stage, command context, or which repository the path belongs to — its
`specs/*|*/specs/*` skip matches unconditionally regardless of repo. It is therefore only ever an
advisory nudge on path *shape*, not a backstop for target-root correctness, and it is not a
guarantee that the rule is followed. The durable enforcement is this rule file plus the agent
contracts; the hook is the reminder.

**Task siting is a separate gap this hook cannot close either, for the same reason**: a hook
firing on a `Write`/`Edit` path has no way to check which repository the *task record* was
created in — that decision happens at task-creation time, before any source-store write occurs,
and may happen in a different tool call entirely. `rules/source-store-deploy-boundary.md`'s
"Task Siting" subsection states the durable rule: a task whose declared edit target is a
source-store path must be created in the repository whose local filesystem contains that
`source_dir`. Enforcement of that rule is documentary and agent-contract reinforcement only — no
blocking hook exists or is planned for it, consistent with this edit-target rule's own recorded
posture above (an advisory nudge plus agent contracts, never a guarantee).

## The Deploy Adds and Changes, But Does Not Delete — Except Where a Merge Target Sweeps Orphans

A second, distinct asymmetry sits beside the edit-target boundary above: once a merge-target
entry (a hook registration, a context-index entry, a settings fragment) is deployed into a
repository, the deploy mechanism can later **add** a new entry and **change** an existing one's
content, but it cannot, by default, **delete** one whose source-store declaration has since been
removed. The fragment merge (`merge.lua`'s `deep_merge`/`merge_hook_event_array`) only ever visits
entries the source still provides; it has no mechanism for reconciling against a declaration the
source has stopped making. An entry that survives purely because nothing ever asked it to leave
is an **orphan**, and it survives indefinitely in every already-deployed repository until
something explicitly sweeps it.

**Per-merge-target sweep inventory** (the authoritative answer to "does this merge target clean
up after itself"):

| Merge target | Sweep function | Sited in |
|---|---|---|
| Context index entries (`.claude/context/index.json`) | `M.remove_orphaned_index_entries` | `manager.load`, before `process_merge_targets` |
| Hook registrations (`.claude/settings.json` / `.claude/settings.local.json`'s `hooks` key) | `M.remove_orphaned_hook_registrations` | `manager.load`, inside `process_merge_targets`, immediately before the settings merge |
| MCP server registrations (`merge_targets.mcp`, e.g. a project's `.mcp.json`) | **none** | — |

The MCP-server row is a known, deliberately uncovered gap: `merge_targets.mcp` rides the exact
same `merge_settings`/`deep_merge` path as hook registrations and has the identical
add-and-change-but-not-delete exposure, but no orphan sweep exists for it today. A removed MCP
server declaration will survive in an already-deployed `.mcp.json` the exact same way an
unswept hook registration does.

**The hook-registration sweep's mandatory carve-out** is part of the invariant, not an
implementation detail: a command not recognizable as a source-store hook invocation — including
every `~/`-anchored command — is never matched, moved, or swept, regardless of whether it
resembles anything in the current source. This is what makes the sweep safe to run
unconditionally on every ordinary load/resync: a user's own hand-written hook, or a deliberately
`~/`-anchored one (demonstrably cwd-independent, and in real, intentional use pointing outside
`.claude/` entirely), is structurally invisible to the sweep's survival predicate. Identity for
this purpose has exactly one definition
(`lua/neotex/plugins/ai/shared/extensions/hook_identity.lua`), shared by the sweep and by
`lint-hook-registration-paths.sh`'s fragment-coverage check — there is no second place a future
reader could find a different answer to "is this the same registration."

### Why No Loader Operation Heals a Pre-Sweep Deploy

A repository deployed before the hook-registration sweep existed cannot self-heal through any
existing loader operation, and this is deliberate, not an oversight to "just also fix":
`settings_backup.lua` snapshots `settings.json`/`settings.local.json` before `manager.wipe` runs
`rm -rf` on the base directory, and `manager.regenerate` **restores that snapshot as the merge
base** before re-running every surviving extension's fragments on top of it. That restore-before-
resync ordering is itself a deliberate fix for a defect class where an unordered wipe/reload lets
the load loop's own writes clobber fragment merges, and is not to be reverted. Its
consequence, though, is that `[Reload All]`, `[Regenerate]`, and
`deploy-headless.sh --wipe` all reintroduce the exact same stale `settings.json` as their merge
base — none of them removes a pre-existing orphan. Only an ordinary (non-wipe) resync, which now
runs the sweep inside each `manager.load` of its `resync_all` loop, or a by-hand repair, converges.

### By-Hand Repair for a Deploy Predating the Sweep

The lowest-cost repair for a repository that has not yet run the sweep-bearing version of
`manager.load` is simply to **run an ordinary (non-wipe) resync** — `deploy-headless.sh TARGET`
with no flags, or the picker's `[Reload All]`/per-extension reload — since the sweep is now sited
inside every `manager.load` call that resync loop makes. There is no need to hand-delete
`settings.json` for this path.

The by-hand fallback, for a target repo whose own copy of the loader predates this sweep entirely
(so an ordinary resync there cannot run the new code until its own `.claude/` is itself
redeployed from a current source store): `rm .claude/settings.json`, then reload. This works
because `root_files` is install-once (`loader.lua`'s `INSTALL_ONCE_ROOT_FILES`) — it copies a
fresh file only when the target is **absent**, never overwriting an existing one — so deleting
the stale file first forces a clean reseed. Its cost: this **discards that repository's own local
`permissions` and `env` customizations** in `settings.json`, which a targeted orphan-registration
removal (the sweep) never does. `deploy-headless.sh --wipe` is explicitly **not** a repair for
this: as the previous section states, it restores the very same stale snapshot as its merge base
and reintroduces the staleness it was meant to clear.

### Observed Field Case: An Unmanaged Repository

A repository with a deployed `.claude/` tree but no `.claude-extensions.json` at all (never
brought under the extension-selection mechanism, or predating it) presents an empty
loaded-extension list to `manager.load`'s valid-set builder. The hook sweep's own fail-safe gate
treats this as "skip the sweep entirely" (an incomplete valid set must never be swept against),
so the sweep does not fire there on its own. `ModelBuilder` and `theorem_proving_in_lean4` were
real field examples of exactly this case; both were brought current by an ordinary
`deploy-headless.sh TARGET` resync, which bootstraps `core` into the project's extension state as
part of the same invocation (see `deploy-headless.sh`'s own "Bootstrap safety" note), making the
loaded-extension list non-empty for that same call so the sweep runs normally. See
`specs/369_orphan_sweep_for_removed_merge_target_entries/records/02_after-measurements.md` for
the measured before/after result of that remediation.
