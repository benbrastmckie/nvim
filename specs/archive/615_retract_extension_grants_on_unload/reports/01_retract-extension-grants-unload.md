# Research Report: Task #615

**Task**: 615 - Retract extension grants on unload
**Started**: 2026-11-13T00:00:00Z
**Completed**: 2026-11-13T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (`lua/neotex/plugins/ai/shared/extensions/merge.lua`, `init.lua`,
  `state.lua`, `merge_spec.lua`), `.claude-extensions.json`, every loaded extension's
  `settings-fragment.json`, `.claude/rules/sapience-write-path.md`, and (read-only, for the
  contradiction check) `/home/benjamin/.dotfiles/specs/138_retire_machine_wide_sapience_surface/`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's cause analysis is confirmed exactly: `deep_merge`'s plain-array branch in
  `lua/neotex/plugins/ai/shared/extensions/merge.lua` (lines ~406-429) dedups against the target
  array *before* recording anything, so an item that already sits in the target is neither
  re-inserted nor tracked. `manager.resync_all` calls `manager.load(name, {force = true})` once
  per already-loaded extension and never unloads first, so every `[Reload All]`/`[Regenerate]`/
  individual-update pass re-merges a fragment whose items are already present, and
  `state_mod.mark_loaded` overwrites that extension's `merged_sections` wholesale with the new
  (now-empty) tracking data. The empty record is therefore the *expected steady state* after one
  reload, not a one-off corruption.
- The defect class is **wider than `permissions.allow`**. It also hits any hook-event array whose
  blocks lack a `matcher` key — `is_hook_event_array` requires `matcher` on every block, so a
  non-tool-matched event falls through to the same plain-array branch. In this repository today
  that is sapience's `SessionStart`, `UserPromptSubmit`, `SessionEnd`, and `Stop` blocks (measured:
  all four show `"type": "appended", "items": []` in `.claude-extensions.json`, not
  `"hook_merged"`). Only sapience's `PreToolUse` block (which does carry `matcher`) goes through
  `merge_hook_event_array`.
- **A fourth stale record exists beyond the three named in the dispatch.** `email`'s
  `permissions.deny` (7 items) is *also* `"type": "appended", "items": []` in
  `.claude-extensions.json` today — same defect, same empty-tracking consequence, just a `deny`
  array instead of an `allow` array. The dispatch's scope item 2 names only sapience/nix/lean;
  `email` should be repaired in the same pass.
- **The companion task's claim is contradicted, precisely.** `/home/benjamin/.dotfiles`'s task
  `retire_machine_wide_sapience_surface` dispatch states "The seven read-tool grants the companion
  added DO retract cleanly on unload. The four-grant residual is a merge-engine defect...". The
  measured record here is `.claude-extensions.json` ->
  `extensions.sapience.merged_sections.settings.permissions.children.allow.items` = `[]` — a
  single flat array covering all eleven grant strings, with no per-item provenance distinguishing
  the four write-tool grants from the seven read-tool grants. All eleven are equally untracked;
  none would be removed by `unmerge_settings` today, not only the four named ones.
- A fresh load into an *empty* target (first-ever load, or load after a wipe/regenerate) tracks
  correctly, because the dedup check against an empty target array always fails and every item is
  inserted and tracked. A wipe-and-regenerate (`manager.wipe` -> deletes `.claude/`, keeps the
  project-root `.claude-extensions.json` state file, then `manager.regenerate` re-loads every
  still-recorded extension into the now-empty tree) is therefore a correct, mechanically verified
  repair path for the three (now four) stale records — no new code is required to make it correct,
  only to make it the documented/sanctioned repair.
- No code outside `merge.lua`/`init.lua`/`state.lua` reads the `tracked`/`merged_sections` shape
  (confirmed by repo-wide grep), so changing that shape to add provenance information is a
  contained change with no other call sites to update.

## Context & Scope

Researched: why `permissions.allow` (and, as discovered, other plain arrays) fail to retract on
unload while hook-event arrays with a `matcher` key do not; the full set of currently-stale
tracking records in this repository; the sanctioned repair for those records; the shape of the
tracking-decision choice the plan phase must make; and whether the companion `.dotfiles` task's
claim about which grants retract cleanly is accurate. Scope follows the dispatch's four numbered
items verbatim; this report does not implement any fix (research phase only) and does not touch
`/home/benjamin/.dotfiles` (per `.claude/rules/source-store-deploy-boundary.md`'s task-siting
rule — that repository's own edit targets are out of this repository's reach, and this task's own
edit targets are all local to `/home/benjamin/.config/nvim`).

## Findings

### Codebase Patterns

**The defect, confirmed at the code level** (`lua/neotex/plugins/ai/shared/extensions/merge.lua:406-429`):

```lua
-- Array: append elements, track what we added
if target[key] == nil then
  target[key] = {}
  tracked[key] = { type = "new_array", items = {} }
elseif not tracked[key] then
  tracked[key] = { type = "appended", items = {} }
end

for _, item in ipairs(value) do
  -- Deduplicate
  local exists = false
  for _, existing in ipairs(target[key]) do
    if vim.deep_equal(existing, item) then
      exists = true
      break
    end
  end
  if not exists then
    table.insert(target[key], item)
    table.insert(tracked[key].items, item)
  end
end
```

An item already present in `target[key]` is skipped entirely: not re-inserted (correct — it is
already there) and not recorded into `tracked[key].items` (the defect — `unmerge_settings`'s
`remove_tracked` walks exactly this `items` list to decide what to delete, so an item it never
recorded can never be removed).

**The trigger is routine, not exceptional.** `manager.resync_all`
(`lua/neotex/plugins/ai/shared/extensions/init.lua:1199-1250`) is what both `[Reload All]` and
`[Global Update]` run; its loop is:

```lua
for _, name in ipairs(resync_order) do
  local ok, err, opencode_skips = manager.load(name, {
    confirm = false, project_dir = project_dir, force = true, notify_skips = notify_skips,
  })
```

`manager.load` is called once per *already-loaded* extension with `force = true`, and it never
calls `manager.unload` first. Each call re-runs `process_merge_targets` ->
`merge_mod.merge_settings` against the *already-populated* `settings.local.json`, so the dedup
check above fires for every item and the pass as a whole tracks nothing new. The returned
(empty) `merged_sections` is then written wholesale into `.claude-extensions.json` by
`state_mod.mark_loaded`, replacing whatever non-empty record the *first* load produced. One
`[Reload All]`, one `[Regenerate]`-then-reload, or even a single `Ctrl-l` update of the same
extension suffices to reach the empty steady state; the repository has evidently gone through at
least one such pass for every extension that declares `permissions.allow`/`permissions.deny`.

**Hooks are not uniformly exempt — only `matcher`-bearing blocks are.**
`is_hook_event_array` (`merge.lua:199-224`) requires every block in the array to carry both a
`matcher` string and a `hooks` array; only then does `deep_merge` route the whole event array
through `merge_hook_event_array` (by-matcher merge with its own `hook_items`/`items` tracking
split, immune to this defect by construction — it tracks a replacement or an append explicitly,
never skips silently). A block without `matcher` fails that predicate and falls through to the
exact same plain-array branch quoted above. Reading
`agent-system/extensions/sapience/settings-fragment.json` directly: `PreToolUse` carries
`"matcher": "Edit|Write|MultiEdit"`, but `SessionStart`, `UserPromptSubmit`, `SessionEnd`, and
`Stop` carry no `matcher` key at all (Claude Code does not require one for those events). Cross-
checked against the live `.claude-extensions.json`, all four show up as `"type": "appended"`
(the vulnerable branch), and — consistent with the "steady state after a reload" mechanism above
— all four currently have `"items": []`. `PreToolUse` does show `"type": "hook_merged"`, also
with empty `items`/`hook_items`, but for the opposite (benign) reason: it is a true no-op
re-merge (the entry already `vim.deep_equal`s the fragment's), and hooks additionally get an
independent reconciliation pass at every *load* (`remove_orphaned_hook_registrations`, gated by a
`valid_set` built from every currently-loaded extension's own fragment) that does not depend on
the tracked-items record at all. Permissions have no equivalent independent reconciliation pass
today — `manager.unload` calls only `reverse_merge_targets`, which is driven solely by the
(possibly stale) tracked record.

**A survey of every loaded extension's merge fragment**, to bound the defect's current blast
radius in this repository (`python3`-driven read of each `agent-system/extensions/*/settings-
fragment.json`):

| Extension | Array(s) declared | Any block missing `matcher`? |
|---|---|---|
| sapience | `permissions.allow` (11), hooks on all 5 events | Yes — `SessionStart`, `UserPromptSubmit`, `SessionEnd`, `Stop` |
| nix | `permissions.allow` (2) | n/a (no hooks declared) |
| lean | `permissions.allow` (1) | n/a (no hooks declared) |
| email | `permissions.deny` (7) | No (its one hook, `PreToolUse`, carries `matcher: "Bash"`) |
| present, web | `permissions.allow` (0 — key present, empty array) | n/a |
| epidemiology, filetypes, founder | none | n/a |

Only sapience currently has a non-`matcher` hook-event array, so the hook half of the defect class
is latent (present in the engine) but only actually manifest for sapience's four events today.
The plain-array half is manifest for every extension with a non-empty `permissions.allow`/`deny`:
sapience, nix, lean, **and email** (see next finding).

**Live measurement of `.claude-extensions.json`** (project root, the file `state_mod.write`
produces from `mark_loaded`'s `merged_sections`), queried directly rather than inferred:

- `extensions.sapience.merged_sections.settings.permissions.children.allow.items` = `[]`
  (11 grants declared, 0 tracked).
- `extensions.sapience.merged_sections.settings.hooks.children.{SessionEnd,SessionStart,
  UserPromptSubmit,Stop}.items` = `[]` each; `.PreToolUse` is `hook_merged` with
  `items: []`, `hook_items: []`.
- `extensions.nix.merged_sections.settings.permissions.children.allow.items` = `[]`
  (2 grants declared, 0 tracked).
- `extensions.lean.merged_sections.settings.permissions.children.allow.items` = `[]`
  (1 grant declared, 0 tracked).
- `extensions.email.merged_sections.settings.permissions.children.deny.items` = `[]`
  (7 entries declared, 0 tracked) — **not named in the dispatch's scope item 2, but the same
  defect, same empty-record consequence.** `email`'s one hook block (`PreToolUse`, matcher
  `Bash`) *is* correctly tracked (`items` non-empty), because that whole matcher block was newly
  appended the last time it was merged, not idempotently re-merged.
- `extensions.core.merged_sections.settings.hooks` shows populated, non-empty `items` for its
  `PreToolUse` matcher blocks — core's hooks tracking is currently healthy, which is unsurprising
  (core's own hooks have presumably not gone through a redundant re-merge cycle since they were
  last actually changed) but is not evidence against the defect; it is evidence that the defect
  only *manifests* once a re-merge happens to find everything already present.

**Repair path, mechanically verified.** `manager.wipe`
(`lua/neotex/plugins/ai/shared/extensions/init.lua:1558-1583`) backs up settings/`.syncprotect`,
then `vim.fn.delete(target_dir, "rf")` (removes `.claude/` only — it does **not** touch the
project-root `.claude-extensions.json` state file, which lives outside `target_dir`), then calls
`manager.regenerate`, which re-`load`s every extension the surviving state file lists. Because
`target_dir` is now empty, every one of those re-loads is a *fresh* merge against an empty target:
the dedup-before-track check trivially fails for every item (nothing exists yet), so every item is
both inserted and tracked, and `mark_loaded` overwrites the stale empty record with a correct,
fully-populated one. This is `[Regenerate]` in the picker. A plain `[Reload All]`
(`manager.resync_all`, no wipe) does **not** repair the record — it is the exact mechanism that
produced the staleness in the first place (confirmed above) and would re-perpetuate it on any
extension whose grants are already present.

**No other code reads the tracked/`merged_sections` shape.** A repo-wide grep for
`merged_sections`, `get_merged_sections`, and the per-field names (`.children`, `.appended`,
`tracked[key].items`) outside `merge.lua`/`init.lua`/`state.lua` returned nothing. The only
consumers of the shape are: `process_merge_targets`/`deep_merge` (producer),
`unmerge_settings`/`remove_tracked` (consumer, for the removal decision), and `state.lua`'s
pass-through storage (schema-agnostic — it stores whatever table it is given). This bounds the
blast radius of any on-disk shape change the plan phase decides to make.

### External Resources

Not applicable — this is a pure in-repo Lua merge-engine defect with no external library or API
surface; no web research was needed or performed.

## Recommendations

**On the tracking decision (scope item 1), weighing the three named shapes:**

- **(i) Track every fragment item unconditionally.** Simplest change (drop the `if not exists`
  guard around the `table.insert(tracked[key].items, item)` call only, keeping the existing guard
  around the `target[key]` insert). Rejected as the *sole* mechanism: it reproduces exactly the
  hazard the dispatch names — a user's own hand-added entry in `settings.local.json` that happens
  to coincide with a fragment string would be deleted on unload, which is destructive to content
  the extension did not add.
- **(ii) Provenance-distinguished tracking** (`items` = newly inserted this merge, a new sibling
  field, e.g. `already_present`, = items the fragment declares that were already in the target
  before this merge ran). This is the shape `merge_hook_event_array` already models structurally
  for hooks (its `items`/`hook_items` split), so it is consistent with the engine's existing
  design language rather than a new pattern. Confirmed low-risk to adopt: no code outside
  `merge.lua`/`init.lua`/`state.lua` reads the tracked shape, so adding a field changes nothing
  else. This shape alone still does **not** solve a separate, pre-existing hazard present under
  ANY of the three shapes: if two loaded extensions both declare the same permission string and
  one unloads, provenance-per-extension does not know the other extension still needs it — see
  Risks below.
- **(iii) Drop the tracking record; reconcile at unload by re-reading the extension's own
  fragment.** Structurally mirrors the hook orphan-sweep already proven at load time
  (`remove_orphaned_hook_registrations` + `build_hook_valid_set`), just inverted to run at unload
  and scoped to one extension's own declared items. Handles the multi-grantor collision
  correctly for free, *if* the valid-set is built from every OTHER still-loaded extension's
  CURRENT fragment (not just the unloading one's) — the same plumbing `build_hook_valid_set`
  already performs for hooks. Its stated interaction risk (fragment edited between load and
  unload) is real but bounded: the unloading extension's *current* fragment is used to know what
  to attempt to remove, so if a grant was added to the fragment after load, unload would attempt
  to remove something that was never actually merged in — a harmless no-op removal attempt against
  the target array (the item either isn't there, in which case removal is a no-op, or it's there
  because something else added it too, in which case the valid-set-based "is any other loaded
  extension still declaring it" check protects it regardless).

**Recommendation: shape (ii), extended with the same still-needed-by-another-loaded-extension
guard that shape (iii) would also require.** Concretely: track provenance per item (new field,
e.g. `already_present`) so unmerge only *considers* removing items this extension's own merge
actually added; and, immediately before removing a considered item, check whether any other
currently-loaded extension's fragment still declares that same string (building this set is the
same traversal `build_hook_valid_set` already does for hooks — it is not new plumbing, only a new
call site) and skip the removal if so. This closes both named hazards (a coinciding user grant,
and a coinciding sibling-extension grant) with one additional check, reuses an existing proven
pattern instead of inventing a fourth, and keeps the on-disk shape change minimal and
backward-compatible (an old record missing the new field degrades to "nothing is known to have
been added by this merge," i.e. no removal — safe-by-default for every record a wipe/regenerate
has not yet refreshed).

**On the existing stale records (scope item 2):** repair via `[Regenerate]`
(`manager.wipe` -> `manager.regenerate`), not via a hand-written one-off script against
`.claude-extensions.json`. It is already the correct, mechanically verified repair (see Findings)
and requires no new code — only documenting it as the sanctioned repair route for this record
class, e.g. in this task's plan or in a short note alongside `merge.lua`'s `deep_merge` doc
comment. **Scope should be widened by one item**: `email`'s `permissions.deny` record is equally
stale today and was not named in the dispatch; it should be repaired in the same `[Regenerate]`
pass as sapience/nix/lean, not left behind as a fifth stale record discovered after the fact.

**On checking the defect class elsewhere (scope item 4):** the survey above is the complete
current-fragment enumeration for this repository (eight extension fragments read directly); the
plain-array branch and the non-`matcher`-hook-array branch are the only two array shapes
`deep_merge` has that exhibit dedup-before-track (the `mcpServers` object-keyed merge and
`append_index_entries`'s unconditional-track-every-processed-path both avoid it structurally, by
different mechanisms — see Risks for why `mcpServers` is not equivalently vulnerable). No
extension beyond sapience currently declares a non-`matcher` hook block, so the hook half of the
fix matters today only for sapience, but the fix itself (if implemented as a generic change to
the plain-array branch, which both `permissions.*` and non-`matcher` hook arrays fall through to)
automatically covers any future extension that adds one.

## Decisions

- Confirmed (not assumed) that `manager.resync_all` never unloads before re-loading, and that
  this — not a one-off edit, corruption, or operator error — is the reload path that produces the
  empty tracking record as a reachable, repeatable steady state.
- Confirmed the hook/permission asymmetry the dispatch states is correct only in the specific
  sense that `merge_hook_event_array`'s mechanism is immune to the defect by construction; it is
  *not* correct in the sense of "every hook-tracking record in this repo is currently non-stale" —
  sapience's four non-`matcher` events are equally stale right now, by the identical mechanism as
  `permissions.allow`.
- Confirmed the companion `.dotfiles` task's specific claim ("the seven read-tool grants... DO
  retract cleanly on unload") is factually wrong against the live record in this repository: the
  tracked array is a single flat list per settings key, carrying no per-item provenance that could
  distinguish "the seven" from "the four" — the measured `items: []` applies to all eleven
  identically. This report states the contradiction; correcting the claim in the other repository
  is explicitly out of this task's edit scope (per `.claude/rules/source-store-deploy-boundary.md`'s
  task-siting rule) and must be carried across by hand, as the dispatch anticipates.
- Decided not to recommend shape (i) as a standalone fix, given the dispatch's own framing names
  the coinciding-user-grant hazard as unacceptable, and a strictly better alternative (ii, or iii)
  is available at comparable implementation cost.

## Risks & Mitigations

- **Multi-grantor collision** (two loaded extensions declaring the same permission string, or the
  same non-`matcher` hook, under this repository's actual sapience/nix/lean/email fragments: not
  observed as an exact string collision today, but structurally possible for any future extension
  pair). Mitigation: whichever shape is implemented, add the "is this item still declared by any
  OTHER currently-loaded extension's fragment" guard before actually deleting it on unmerge,
  reusing `build_hook_valid_set`'s existing traversal pattern rather than writing a new one.
- **Shape (iii)'s fragment-drift-between-load-and-unload risk**, as the dispatch names it: if the
  fix is NOT shape (iii), this risk does not apply; if the plan phase chooses (iii) anyway, the
  mitigation is to always compute the valid-set from fragments as currently read from disk at
  unload time (matching `build_hook_valid_set`'s existing contract) and treat an attempted removal
  of an absent item as a silent no-op (already `unmerge_settings`'s existing behavior for the
  "appended" branch today — the removal loop only removes entries it finds by `vim.deep_equal`,
  so a target-side absence is already harmless).
- **`mcpServers` is a different (object-keyed) merge path and is not equivalently vulnerable** to
  the array-dedup defect, but this should be verified again if the plan phase touches the generic
  object-merge branch (`deep_merge`'s "Object: recurse" arm) for any reason — a first-time key
  insertion there IS tracked as `new_object`/`new_value` regardless of what its nested scalar/array
  fields later do, so whole-key removal on unmerge is correct independent of nested-field
  staleness. This report did not find a defect in that path; it is listed here only so the plan
  phase does not need to re-derive the "is `mcpServers` also broken?" question from scratch.
- **An unrelated on-disk anomaly was noticed, not investigated**: an untracked file
  `agent-system/extensions/core/.claude-extensions.json` exists in this repository's working tree
  (confirmed via `git status`), structurally resembling the project-root `.claude-extensions.json`
  state file but nested inside the `core` extension's own source-store directory. This is outside
  this task's scope (it is not a merge-tracking-record staleness issue, and no file under
  `agent-system/extensions/core/` should contain a copy of the project's own extension-state file)
  and is flagged here only so it is not lost; it may be worth a separate, small follow-up task to
  determine how it was created and whether it should simply be deleted.

## Context Extension Recommendations

- **Topic**: the merge-tracking contract for `permissions.allow`/`permissions.deny` and
  non-`matcher` hook-event arrays.
- **Gap**: no existing context file states that `deep_merge`'s plain-array branch is
  dedup-before-track, or that `manager.resync_all`'s `force`-reload-without-unload pattern is what
  turns that into an observable staleness. The only narrative is the in-code doc comments this
  report already cites.
- **Recommendation**: once the plan/implementation phases land a fix, add a short note (either a
  doc-comment expansion on `deep_merge`'s array branch, or a new
  `.claude/context/project/neovim/patterns/`-sited pattern file) stating the chosen tracking shape,
  the still-needed-by-another-loaded-extension guard, and `[Regenerate]`-as-repair, so a future
  reader investigating a similarly stale `merged_sections` record for some other extension does
  not have to re-derive this chain of reasoning from the source again.

## Appendix

Search/read operations performed (codebase only — no web search was needed for this defect):

- Read `lua/neotex/plugins/ai/shared/extensions/merge.lua` in full (array/object `deep_merge`
  branches, `is_hook_event_array`, `merge_hook_event_array`, `unmerge_settings`/`remove_tracked`,
  `prune_empty_hooks`).
- Read `lua/neotex/plugins/ai/shared/extensions/init.lua`'s `process_merge_targets`,
  `reverse_merge_targets`, `manager.load`, `manager.unload`, `manager.resync_all`, `manager.wipe`.
- Read `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua`'s existing `describe`/`it`
  structure (hook-identity-dedupe, orphan-sweep, and `.mcp.json` fragment-shape blocks) as the
  local model for shape, per the dispatch's pointer to `prune_empty_hooks` coverage.
- Queried the live `.claude-extensions.json` (`extensions.{sapience,nix,lean,email,core,nvim,
  approvals,literature}.merged_sections.settings`) directly via a one-off `python3 -c` JSON read,
  not inferred from prose.
- Read every loaded extension's `agent-system/extensions/*/settings-fragment.json`
  (sapience, nix, lean, email, present, web, epidemiology, filetypes, founder) to enumerate every
  declared array and check for hook blocks missing `matcher`.
- Read `.claude/rules/sapience-write-path.md`'s "Accepted Residual" section (the
  previously-known four-write-tool-grant residual this task's record widens).
- Read (read-only; `/home/benjamin/.dotfiles`, outside this task's edit scope):
  `specs/138_retire_machine_wide_sapience_surface/.dispatch/{1,2,3}.md` (item 2, "SEVEN READ-TOOL
  GRANTS -- AND THE 11 / 7 / 4 ACCOUNTING", containing the exact claim this report's Executive
  Summary and Decisions sections quote and contradict) and
  `specs/138_retire_machine_wide_sapience_surface/reports/01_retire-machine-wide-sapience.md`.
