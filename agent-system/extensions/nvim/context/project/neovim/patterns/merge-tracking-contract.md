# Extension Merge Tracking Contract

How `deep_merge`'s tracking record is built and consumed, why an empty record was the steady
state for a `permissions.allow`/`permissions.deny` grant after a single reload, the fix and its
accepted residual, and the real repair route for a stale record.

## The defect, and why a reload (not just a fresh load) was enough to trigger it

`deep_merge` (in `lua/neotex/plugins/ai/shared/extensions/merge.lua`) walks a fragment's keys
and, for a plain array value (e.g. `permissions.allow`), deduped an item against the
target array *before* recording anything: `table.insert(tracked[key].items, item)` sat inside
the `if not exists` guard, alongside the `table.insert(target[key], item)` that actually inserts
it. An item already present in the target was therefore neither re-inserted nor recorded.

`manager.resync_all` re-loads every already-loaded extension with `force = true` and never
unloads first, so every grant an extension declared becomes "already present in the target" on
the very next resync. The tracking record for that key -- `tracked.permissions.children.allow`
-- comes back `{ type = "appended", items = {} }`: present, but empty. `M.unmerge_settings` can
only remove what a record names, so an unload after that point retracts nothing. This is the
steady state after ONE reload, not an occasional corruption: any path that re-merges a fragment
whose grants already sit in the target reproduces it -- a `[Reload All]`/`[Regenerate]` from the
picker, an individual `Ctrl-l` update, or a `deploy-headless.sh` run.

Hooks never showed this symptom, because a matcher-bearing hook-event array (`PreToolUse`, etc.)
routes through `merge_hook_event_array` instead, which tracks a block append or a hook
replacement explicitly in its own `items`/`hook_items` lists -- it has no dedup-then-skip
structure to begin with.

## The fix: record every fragment item, insert only the new ones

`deep_merge`'s plain-array arm now records every fragment item unconditionally, and dedups only
the INSERTION into the target array:

```lua
for _, item in ipairs(value) do
  table.insert(tracked[key].items, item)       -- always recorded

  local exists = false
  for _, existing in ipairs(target[key]) do
    if vim.deep_equal(existing, item) then
      exists = true
      break
    end
  end
  if not exists then
    table.insert(target[key], item)            -- only inserted if new
  end
end
```

This is engine-wide, not scoped to `permissions.allow` by key name: it fixes EVERY array reached
through this same arm, at any nesting depth -- see the array-path enumeration below.

## The tracking shape: track everything, guard at unmerge time

Three shapes were weighed for how to decide what an unload should retract:

- **(i) Track every fragment item unconditionally** (selected) -- simplest, and the only shape
  that actually produces a non-empty record on a re-merge.
- **(ii) Provenance distinction** ("we added this" vs. "it was already here") -- rejected: the
  distinction answers the wrong question. An item that was "already present" on a re-merge was
  typically added by THIS SAME extension's own earlier load; classifying it as pre-existing would
  make the next unload retract nothing, reproducing the exact defect this fix closes. It would
  also require persisting prior tracked state into `merge_settings`, new coupling for a
  distinction the four already-stale records in a given repository cannot recover (the
  information was never written).
- **(iii) Drop the record, reconcile at unload by re-reading the extension's own fragment** --
  rejected: once shape (i) lands, the record stays complete on every merge, so this shape's one
  advantage evaporates, leaving only its cost (a second authority alongside the record, plus a
  fragment-drift window between load and unload).

Shape (i) alone would let an unload strip a grant a SIBLING extension's fragment still declares
(two extensions can both list the same `permissions.allow` string). The fix therefore extends
`M.unmerge_settings(target_path, tracked_entries, opts)` with:

- `opts.retained_fragments`: an array of decoded settings-shaped fragment tables belonging to
  every OTHER currently loaded extension that shares this settings merge target. Before removing
  a tracked item in the `"appended"` branch (or the whole-block `items` half of `"hook_merged"`),
  the removal is skipped when the item is `vim.deep_equal` to an item in any retained fragment's
  array at the SAME key path -- built via `lua/neotex/plugins/ai/shared/extensions/init.lua`'s
  `build_retained_fragments` (beside `build_hook_valid_set`) and plumbed through
  `manager.unload` -> `reverse_merge_targets` -> `M.unmerge_settings`.
- `opts.skip_array_removal`: a fail-safe signal, set when `build_retained_fragments` could not
  reliably build the retained set (an unreadable manifest or unparseable sibling fragment). An
  INCOMPLETE retained set must widen protection, never narrow it, so this suppresses ALL
  array-item removal for that unload rather than remove against an uncertain set -- the mirror
  image of `build_hook_valid_set`'s own fail-safe direction for the orphan sweep (that one widens
  by skipping the sweep; this one widens by skipping the removal).

The failed-load rollback call site (`manager.load`'s own cleanup path) deliberately passes no
`opts`: a rollback reverses THIS load's own merge against the state it just created, so there is
no sibling grant for the guard to protect.

### Scope boundary: the retained-fragments guard does not cover whole-key removal

`opts.retained_fragments`/`opts.skip_array_removal` guard only the `"appended"` branch's
per-item removal and `"hook_merged"`'s whole-block-appended half. They do **not** guard
`"new_array"` or `"new_value"`, which unconditionally set `t[key] = nil` regardless of `opts`.
This matters only if the FIRST-ever extension to populate a shared array key is unloaded while a
sibling extension's own LATER contribution still sits in that same on-disk array: the unloading
extension's own tracked record for that key is fixed at `"new_array"` from its own load time and
never changes, so its removal is unconditional. This does not affect the records this contract
exists to describe: a repository's `permissions.allow`/`permissions.deny` arrays are essentially
never empty before a second extension merges into them, so an extension's own tracked type for
those keys is `"appended"`, not `"new_array"`, in every case observed in practice.

`"new_object"` is the one wholesale-removal type this no-longer applies to: `remove_tracked`
recurses into its `children` exactly like the `"merged"` branch, then drops the object only if
nothing is left inside it afterward. A sibling key added to that same object after this
extension's own load -- most notably a hand-written `mcpServers` entry a user added directly to
`.mcp.json` after this extension's own load first created the wrapper object -- survives a
retraction that would otherwise have deleted the whole object outright. This closes the gap
`mcpServers.<name>` first-time insertion exposed (see the array-path table below): a fresh
`.mcp.json`'s `mcpServers` key is `"new_object"` for whichever extension first populates it, so
the wholesale-removal reading previously in force here would have discarded any later
hand-written sibling entry on that extension's next forced reload or unload.

### The accepted residual

A grant a user hand-adds to `.claude/settings.local.json` that happens to equal one the
extension declares is removed when that extension unloads. This is accepted because: (a) while
the extension is loaded, the user's entry is redundant with the extension's own; (b) the user's
stated intent in unloading an extension is to revoke ITS tools; and (c) a grant meant to survive
independently of any extension's lifecycle belongs in `.claude/settings.json`, which no merge
path touches at all -- it is the durable home for that case. A flat per-key `items` array carries
no per-item provenance, so no claim of the form "these N of M grants retract cleanly while the
other M-N do not" can be true of this record shape: either ALL of an extension's declared items
in a key are tracked (the fixed behavior) or NONE are (the pre-fix defect) -- there is no
partial-retraction state this shape can represent.

Unloading the `email` extension now also removes its `permissions.deny` entries as a direct
consequence of the same fix -- a loosening, not a tightening, and the correct, symmetric
behavior: `deny` is governed by the identical plain-array arm as `allow`.

## Array-path enumeration (every array reachable from a fragment through `deep_merge`)

| Path | Verdict | Why |
|------|---------|-----|
| Plain array (`permissions.allow`, `permissions.deny`, any other flat array) | **Fixed by this contract's change** | Was dedup-before-track; now records every item unconditionally, at any nesting depth the recursion reaches. |
| Non-`matcher` hook-event array (e.g. sapience's `SessionStart`/`SessionEnd`/`UserPromptSubmit`/`Stop`, each a `{hooks = [...]}` block with no `matcher` key) | **Fixed by this contract's change** | `is_hook_event_array` rejects a block with no string `matcher` field, so the array falls through to the SAME plain-array arm above -- not a separate code path. |
| Matcher-bearing hook-event array (e.g. `PreToolUse`) | **Immune, unchanged** | Routes through `merge_hook_event_array`, which tracks a block append or a hook replacement explicitly into its own `items`/`hook_items` -- it never had a dedup-before-track structure to begin with. |
| `mcpServers.<name>` key, first-time insertion | **Also fixed, separately** | Object-keyed: deep_merge's "Object: recurse" arm tracks a never-before-seen server name as `"new_object"`. `remove_tracked`'s `"new_object"` branch now recurses into that record's `children` and prunes the object only when it ends up empty, rather than deleting it outright -- so a hand-written sibling entry added to the same `mcpServers` object after this extension's own load survives a later retraction (see the Scope boundary section above). |
| A nested array field inside an ALREADY-EXISTING `mcpServers.<name>` entry (e.g. re-merging the same fragment a second time touches `mcpServers.<name>.args`) | **Also fixed by this contract's change** | Once the server-name key already exists, deep_merge recurses into it as `"merged"`, and `args` (a plain array) is reached through the exact same plain-array arm as `permissions.allow` -- confirmed empirically while writing this contract's test coverage. This is not a second defect; it is the same arm, reached through one more level of object recursion, and the fix covers it identically. |
| `index.json` entries (`M.append_index_entries`) | **Immune, unchanged** | A separate function, not part of `deep_merge`. Every processed entry's path is appended to `added_paths` and tracked unconditionally, whether it was a fresh append or an in-place upsert replacement. |

## The real repair route for a stale record

A stale (empty) tracking record is repaired by a **plain redeploy** run after this contract's fix
lands: `bash .claude/scripts/deploy-headless.sh` (bootstrap core load plus `manager.resync_all`)
re-merges every already-loaded extension's fragment, and the fixed `deep_merge` now records a
complete item list on that very re-merge -- no wipe, and no hand-edit of
`.claude-extensions.json`, is needed or sanctioned.

`--wipe` / `[Regenerate]` is specifically **not** a repair for this, even though it looks like a
more thorough reset. `manager.wipe` snapshots `settings.json` and `settings.local.json`
(`settings_backup.BACKUP_FILES`) before `rm -rf .claude`, and `manager.regenerate` calls
`settings_backup.restore` BEFORE `manager.resync_all`. The restored `settings.local.json`
therefore reinstates every already-present grant as the merge base, the SAME dedup-before-track
check fires exactly as it did before the fix if that fix were not in place, and -- if run against
an unfixed engine -- the record would come back empty exactly as before. Against the FIXED
engine, `--wipe` and a plain redeploy converge on the same correct result, but a plain redeploy
is the simpler, sufficient operation and does not require discarding and restoring
`settings.local.json`/`settings.json` at all.
