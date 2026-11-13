# Implementation Plan: Task #615

- **Task**: 615 - Retract extension grants on unload
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: specs/615_retract_extension_grants_on_unload/reports/01_retract-extension-grants-unload.md
- **Artifacts**: plans/01_retract-extension-grants-unload.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`deep_merge`'s plain-array branch in `lua/neotex/plugins/ai/shared/extensions/merge.lua` dedups a
fragment item against the target *before* recording it, so any item already present in the target
is neither re-inserted nor tracked — and `unmerge_settings` can only remove what was tracked.
Because `manager.resync_all` re-loads every already-loaded extension with `force = true` and never
unloads first, the empty tracking record is the steady state after a single reload, not a
corruption. This plan moves the `tracked[key].items` insert outside the dedup guard so the record
is complete, adds a still-declared-by-another-loaded-extension guard so unload cannot strip a
grant a sibling extension still needs, covers the behavior in `merge_spec.lua`, documents the
decision, and repairs the four stale records this repository carries today.

Definition of done: a load into a repository that already holds the fragment's grants produces a
non-empty tracking record; an unload retracts exactly the declared set minus what another loaded
extension still declares; `merge_spec.lua` passes headless with the new coverage; and
`.claude-extensions.json` carries populated records for `sapience` (11), `nix` (2), `lean` (1),
and `email` (7).

### Premise Re-Validation (Carried-Figure Discipline)

Every measured figure in the dispatch description was re-checked against live state during this
planning pass, not carried on trust. Results:

- **Confirmed unchanged.** `extensions.sapience.merged_sections.settings.permissions.children.allow.items`
  is `[]` against 11 declared grants; `nix` is `[]` against 2; `lean` is `[]` against 1. All
  eleven sapience grants are live in `.claude/settings.local.json` (58 allow entries total) and
  none appear in `.claude/settings.json` (23 allow entries, zero sapience). The cause located in
  the dispatch (`deep_merge`'s dedup-before-track) is confirmed at the source.
- **Confirmed, and wider than the dispatch states.** `email`'s `permissions.deny` is also
  `"type": "appended", "items": []` against 7 declared entries — a fourth stale record. Sapience's
  `SessionEnd`, `SessionStart`, `UserPromptSubmit`, and `Stop` hook blocks carry no `matcher`, so
  `is_hook_event_array` rejects them and they fall through the same plain-array branch; all four
  record `"appended"` with empty `items`. Only sapience's `PreToolUse` (matcher-bearing) routes
  through `merge_hook_event_array`. `core`'s hook records are populated and healthy.
- **Corrected.** The research report's scope-item-2 recommendation — that `[Regenerate]` /
  `manager.wipe` is a mechanically verified repair for the stale records — is **wrong**.
  `manager.wipe` calls `settings_backup.backup` (whose `BACKUP_FILES` is
  `{ "settings.json", "settings.local.json" }`) before `rm -rf .claude`, and `manager.regenerate`
  calls `settings_backup.restore` **before** `manager.resync_all`. The restored
  `settings.local.json` therefore reinstates all eleven grants as the merge base, the
  dedup-before-track check fires exactly as it does on an ordinary resync, and the record comes
  back empty. The report's reasoning assumed the merge ran against an empty target; it does not.
  This plan replaces that repair route (see Phase 6).
- **Corrected.** The dispatch's line 68 (shape (iii): "re-reading the extension's own fragment, so
  the record cannot go stale in the first place") is accurate as a description of shape (iii), but
  the premise it implies — that only shape (iii) removes the staleness — does not hold: the Phase 2
  fix makes the record complete on every merge, so it cannot go stale under any of the three
  shapes once the dedup guard no longer covers the tracking insert. Shape (iii)'s distinguishing
  advantage is therefore smaller than the dispatch's framing suggests (see Decisions).
- **Newly measured, not in any prior artifact.** `merge_spec.lua` is **already red** before any
  change: 21 passed, 3 failed, headless. All three failures come from `read_host_fixture`, which
  reads `specs/369_orphan_sweep_for_removed_merge_target_entries/records/fixtures/host-settings.json`
  — a task directory that no longer exists after archival. The fixture survives in git at commit
  `fc8cca3f0`. The acceptance bar requires `merge_spec.lua` to pass headless, so Phase 1 repairs
  this before any engine change, and the implementer must not mistake these three for regressions.

### Research Integration

The research report's cause analysis, defect-class survey, and `email`-as-fourth-record finding
are adopted in full and drive Phases 2, 4, and 5. Its scope-item-2 repair recommendation and its
shape-(ii) tracking recommendation are **not** adopted — see Premise Re-Validation above and
Decisions below for the reasoning in each case. Its observation that no code outside
`merge.lua` / `init.lua` / `state.lua` reads the `merged_sections` shape is adopted and is what
bounds Phase 2's blast radius.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided to this dispatch.

## Goals & Non-Goals

**Goals**:

- Make `deep_merge`'s plain-array branch record every fragment item, so the tracking record is
  complete whether or not the item was already in the target.
- Make `unmerge_settings` refuse to remove an item that another currently-loaded extension's
  fragment still declares.
- Cover the fresh-merge, re-merge, unmerge-after-each, coinciding-user-grant, sibling-extension-
  retention, and hooks-non-regression cases in `merge_spec.lua`, and restore the spec to green.
- Repair the four stale records (`sapience`, `nix`, `lean`, `email`) in this repository.
- Record the chosen tracking shape, its accepted residual, and the real repair route where a
  future reader will find them.

**Non-Goals**:

- Editing `/home/benjamin/.dotfiles`. The companion task's incorrect 7-retract/4-survive claim is
  stated in the research report and restated in Phase 5's documentation; carrying the correction
  into that repository is manual and out of this task's edit scope per
  `.claude/rules/source-store-deploy-boundary.md`'s task-siting rule.
- Changing `mcpServers`' object-keyed merge path or `append_index_entries`. Both avoid the defect
  structurally; Phase 5 re-confirms this rather than modifying either.
- Investigating the untracked `agent-system/extensions/core/.claude-extensions.json` the research
  report flagged. Noted in Risks, left for a separate task.
- Narrowing, widening, or otherwise changing any extension's declared grants. This task changes
  the engine's bookkeeping, never a fragment's content.

## Decisions

### The tracking shape (dispatch scope item 1)

**Selected: shape (i) — track every fragment item unconditionally — extended with a
still-declared-by-another-loaded-extension guard at unmerge time.**

Why not **shape (ii)** (provenance distinction between "we added this" and "it was already
here"), which the research report recommended: the provenance flag answers the wrong question.
"Already present in the target when this merge ran" is not "not added by this extension" — the
eleven sapience grants *were* added by sapience's first load, and are only "already present" on
every merge after it. Under shape (ii), the next merge would classify all eleven as pre-existing,
unload would still retract nothing, and the task's own acceptance criterion ("a subsequent unload
retracts exactly the set the selected shape says it should") would fail on the exact case that
motivated the task. Making shape (ii) work would require carrying forward the prior tracked
record across merges, which means plumbing `.claude-extensions.json` state into
`merge_settings` — real new coupling for a distinction that is unrecoverable for the four records
already stale, since the information was never written.

Why not **shape (iii)** (drop the record, reconcile at unload by re-reading the fragment): once
Phase 2 lands, the record can no longer go stale, so shape (iii)'s one distinguishing advantage
evaporates. What remains is its cost: a second authority (fragment-as-read-at-unload) alongside
the record, plus the fragment-drift window between load and unload that the dispatch names. The
guard this plan adopts — reading *other* loaded extensions' fragments at unload — is the one piece
of shape (iii)'s machinery that is genuinely needed, and Phase 3 takes exactly that piece.

**Accepted residual, stated plainly**: a grant a user hand-added to `.claude/settings.local.json`
that happens to equal one the extension declares will be removed when that extension unloads. This
is acceptable because (a) while the extension is loaded the user's entry is redundant, (b) the
user's stated intent in unloading is to revoke the extension's tools, and (c) a grant the user
wants to hold independently of any extension belongs in `.claude/settings.json`, which no merge
path touches — measured: it carries 23 allow entries today and zero sapience entries. Phase 5
documents this.

### The repair route (dispatch scope item 2)

**Selected: a plain redeploy run after the Phase 2 fix lands.** Once `deep_merge` records every
fragment item, the next merge of each affected extension writes a complete record, so
`bash .claude/scripts/deploy-headless.sh` (bootstrap core load + `manager.resync_all`) repairs all
four records as an ordinary side effect. No wipe is needed, and no hand-edit of
`.claude-extensions.json` is sanctioned. `--wipe` is specifically **not** the repair, for the
reason measured in Premise Re-Validation above.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Phase 6's redeploy regenerates the whole deployed tree while sibling tasks 616/617 are editing this same working tree with undeclared scope | H | M | Phase 6 declares `__WHOLE_TREE__`; before running, re-read `git status --short` and `git log --oneline -5`, and STOP and report if a foreign commit or foreign uncommitted modification is present rather than proceeding (per the dispatch's Territory block) |
| The three pre-existing `merge_spec.lua` failures are mistaken for regressions introduced by Phases 2-4 | M | H | Phase 1 repairs them first and records the resulting 24/24 green baseline before any engine change |
| Tracking every item causes an unload to strip a permission a sibling extension still needs | H | L | The Phase 3 retained-set guard; asserted directly by a Phase 4 spec case |
| Unloading `email` now removes its 7 `permissions.deny` entries — a loosening, not a tightening | M | L | Correct per-repo-gating behavior and symmetric with `allow`; called out explicitly in the Phase 5 documentation so it is not discovered by surprise |
| `vim.json.encode`-based set keys would compare hook-block tables unstably (key order is not guaranteed) | M | M | Phase 3 builds the retained set as a flat list compared with `vim.deep_equal`, never an encoded-string set; the lists are a handful of items, so the O(n*m) scan is irrelevant |
| `.claude-extensions.json` is already modified in the working tree and is also a redeploy output | M | M | Stage it explicitly by path at the Phase 6 commit, never a directory or glob add; review `git diff --staged` first |
| The untracked `agent-system/extensions/core/.claude-extensions.json` anomaly is unexplained | L | L | Out of scope; left untouched and unstaged by every phase here, flagged for a separate task |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5 | 3 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Restore merge_spec's host fixture and establish a green baseline [COMPLETED]

**Goal**: Bring `merge_spec.lua` from its current 21-pass/3-fail state to fully green, and remove
the task-numbered `specs/**` path the spec depends on, before any engine change makes a new
failure hard to attribute.

**Tasks**:
- [x] Run `nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua"` and record the exact pass/fail counts as the pre-change baseline. *(completed: confirmed 21 passed, 3 failed, 0 errors -- matches the plan's measured premise)*
- [x] Recover the fixture: `git show fc8cca3f0:specs/369_orphan_sweep_for_removed_merge_target_entries/records/fixtures/host-settings.json`. *(completed)*
- [x] Write it to `lua/neotex/plugins/ai/shared/extensions/host_settings_fixture.json`, siting it beside the spec exactly as `hook_identity_fixtures.json` already is. *(completed)*
- [x] Point `read_host_fixture` (around `merge_spec.lua:528`) at the new sibling path, resolved relative to the spec rather than to `vim.fn.getcwd()` where that is practical. *(completed: used the same debug.getinfo(1, "S").source arg[0]-independent idiom hook_identity_cli.lua already uses)*
- [x] Confirm no other `specs/` path remains in any file under `lua/neotex/plugins/ai/shared/extensions/` (`grep -rn "specs/" lua/neotex/plugins/ai/shared/extensions/`). *(completed: remaining hits are a comment and fixture-content string literal, not path dependencies)*
- [x] Re-run the spec headless and confirm all three previously-failing cases now pass with zero new failures. *(completed: 24 passed, 0 failed, 0 errors)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` over this phase's touched paths, so no suite covers them and the covering checks are `bash .claude/scripts/verify-deploy.sh --only-gate 4 /home/benjamin/.config/nvim` — the task-reference lint, which is exactly what the removed `specs/369_...` path trips — together with the spec's own `nvim --headless -c "PlenaryBustedFile ..."` run.

**Scope Hypothesis**: Exactly one reader (`read_host_fixture`) and three `it` cases depend on the missing fixture, and `merge_spec.lua:529` is the only `specs/` reference in the whole extensions module directory. Confirm with the `grep -rn "specs/"` step above before editing; if other readers appear, repoint each of them the same way rather than narrowing the phase.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` - repoint `read_host_fixture` at the new sibling fixture
- `lua/neotex/plugins/ai/shared/extensions/host_settings_fixture.json` - new file, recovered verbatim from commit `fc8cca3f0`

**Verification**:
- The headless spec run reports 24 successes, 0 failures, 0 errors.
- `grep -rn "specs/" lua/neotex/plugins/ai/shared/extensions/` returns nothing.
- `bash .claude/scripts/verify-deploy.sh --only-gate 4 /home/benjamin/.config/nvim` exits 0.

---

### Phase 2: Record every fragment item in deep_merge's plain-array branch [NOT STARTED]

**Goal**: Make the tracking record complete — an item already present in the target is recorded
even though it is not re-inserted — and give `unmerge_settings` the parameter it needs to honor a
retained set.

**Tasks**:
- [ ] In `deep_merge`'s `else -- Array: append elements, track what we added` arm, move `table.insert(tracked[key].items, item)` out of the `if not exists` guard so it runs for every fragment item, leaving the `table.insert(target[key], item)` insert guarded exactly as it is today.
- [ ] Rewrite that arm's comment to state what is now true ("record every fragment item; insert only those not already present") and why, citing the unload-retraction consequence rather than describing the diff.
- [ ] Extend `M.unmerge_settings(target_path, tracked_entries)` with a third optional `opts` argument carrying `opts.retained_fragments`: an array of decoded fragment tables belonging to other currently-loaded extensions. Omitting it must behave exactly as today.
- [ ] In `remove_tracked`, thread the parallel sub-tables of each retained fragment down the recursion alongside `t[key]` / `info.children`, so that at any key path the function can see the sibling fragments' value at that same path.
- [ ] Before removing an item in the `appended` branch (and in `hook_merged`'s `items` branch), skip the removal when the item is `vim.deep_equal` to any item in any retained fragment's array at the same key path. Compare with `vim.deep_equal` against a flat list — never an encoded-string set, whose key ordering is not stable for table items.
- [ ] Update the doc comments on `M.unmerge_settings` and `deep_merge` to describe the new parameter and the guard.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: `M.unmerge_settings`'s signature changes and its call sites live in `lua/neotex/plugins/ai/shared/extensions/init.lua` (`reverse_merge_targets`, two call sites), so the one-hop dependent must build; covered by `bash .claude/scripts/tests/run-all.sh --only test-mcp-merge-target.sh` — the suite `suite_selection_select` returns for `merge.lua` — plus the headless spec run.

**Scope Hypothesis**: The defective structure appears in exactly one place — the plain-array arm at roughly `merge.lua:406-429` — and `merge_hook_event_array` tracks explicitly rather than skipping, so it needs no equivalent change. Confirm before editing by grepping `merge.lua` for every `tracked\[key\]\.items` and `tracked.items` insert and checking each against the dedup-before-track shape; if a second site matches, fix it here rather than deferring it to Phase 5.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - move the tracking insert outside the dedup guard; add `opts.retained_fragments` to `unmerge_settings` and honor it in `remove_tracked`

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.merge')" -c "q"` loads clean.
- The Phase 1 spec run still reports 24/0/0 (no regression; the new cases arrive in Phase 4).
- `bash .claude/scripts/tests/run-all.sh --only test-mcp-merge-target.sh` passes.

---

### Phase 3: Plumb the retained set through the unload path [NOT STARTED]

**Goal**: Build the other-loaded-extensions retained set in `manager.unload` and pass it to
`unmerge_settings`, so the guard added in Phase 2 is actually supplied with data.

**Tasks**:
- [ ] Add a helper beside `build_hook_valid_set` in `init.lua` that, given the settings target path, the unloading extension's name, `loaded_names`, and `config`, returns an array of decoded fragments belonging to every *other* loaded extension whose `merge_targets.settings.target` equals the same target. Model its traversal and its manifest/fragment lookups directly on `build_hook_valid_set`.
- [ ] Mirror `build_hook_valid_set`'s fail-safe posture, inverted for this direction: an unreadable manifest or unparseable fragment must make the retained set *more* inclusive, never less. Return a signal that causes the unmerge to skip removal of array items entirely rather than removing items a sibling may still need — and surface that skip to the caller rather than failing silently.
- [ ] In `manager.unload`, build the retained set after `loaded_names` is computed (it already is, for the dependents check) and before `reverse_merge_targets` is called.
- [ ] Extend `reverse_merge_targets` to accept and forward the retained set to both `unmerge_settings` call sites (settings and mcp). The mcp target is object-keyed and unaffected in practice, but forwarding keeps the two paths uniform.
- [ ] Leave the failed-load rollback call site at `init.lua:816` passing no retained set: a rollback reverses *this* load's own merge against the state it just created, where the guard has nothing to protect. Add a one-line comment recording that this asymmetry is deliberate.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Tier Justification**: `reverse_merge_targets`'s signature changes and its callers span `manager.unload` and the failed-load rollback path in the same module while consuming `merge.lua`'s new parameter; covered by `bash .claude/scripts/tests/run-all.sh --only test-deploy-orphans.sh,test-deploy-verify-overlap.sh,test-mcp-merge-target.sh` — the suites `suite_selection_select` returns for `init.lua`.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - new retained-set builder beside `build_hook_valid_set`; build it in `manager.unload`; forward it through `reverse_merge_targets`

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions')" -c "q"` loads clean.
- `bash .claude/scripts/tests/run-all.sh --only test-deploy-orphans.sh,test-deploy-verify-overlap.sh,test-mcp-merge-target.sh` passes.
- The Phase 1 spec run still reports 24/0/0.

---

### Phase 4: Test coverage in merge_spec.lua [NOT STARTED]

**Goal**: Assert the chosen shape's behavior explicitly — including the accepted residual — rather
than leaving it implicit, covering all five cases the dispatch's scope item 3 names plus the
sibling-retention case the chosen shape requires.

**Tasks**:
- [ ] Add a `describe("shared.extensions.merge permission array tracking", ...)` block following the existing scratch-dir `before_each`/`after_each` and `write_target`/`read_target` conventions.
- [ ] Case 1 — fresh merge: merge a fragment with a `permissions.allow` array into a target that has none; assert the target holds every grant and the returned `tracked` records every one of them.
- [ ] Case 2 — re-merge over already-present grants: merge the same fragment a second time into the now-populated target; assert the target is unchanged (no duplication) **and** the second merge's `tracked` records every grant, not an empty array. This is the regression test for the defect.
- [ ] Case 3 — unmerge after each: run `unmerge_settings` with each of the two tracked results and assert the target's `permissions.allow` returns to its pre-merge content in both cases.
- [ ] Case 4 — coinciding user grant: seed the target with a hand-added grant string that the fragment also declares, merge, then unmerge; assert the grant **is** removed, and comment the case to state that this is the selected shape's accepted residual, not an oversight.
- [ ] Case 5 — sibling-extension retention: unmerge with `opts.retained_fragments` carrying a second fragment that declares one of the same grants; assert that grant survives and the rest are removed.
- [ ] Case 6 — hooks non-regression: assert a matcher-bearing hook event still produces `type = "hook_merged"` and round-trips as it does today, and that a non-`matcher` hook event array (sapience's `SessionStart` shape) now records its blocks under `appended` and is retracted by unmerge.
- [ ] Re-run the full spec headless and confirm zero failures.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: The edit is confined to one spec file with no externally visible signature, and is covered by `bash .claude/scripts/tests/run-all.sh --only test-deploy-propagation.sh` — the suite `suite_selection_select` returns for `merge_spec.lua` — together with the spec's own headless `PlenaryBustedFile` run, which is what actually exercises the new assertions.

**Scope Hypothesis**: Six `it` cases in one new `describe` block suffice; no existing case needs modification, because none asserts the empty-tracking behavior the fix changes. Confirm by re-running the spec after Phase 2/3 and before adding cases — if any existing case flips to red, that case was asserting the defect and must be corrected here with a comment saying so, not worked around.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` - new `describe` block covering all six cases

**Verification**:
- `nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua"` reports 30 successes, 0 failures, 0 errors.
- Every one of the six cases is present and named.

---

### Phase 5: Sweep the defect class and document the decision [NOT STARTED]

**Goal**: Confirm no other reachable array path carries the same dedup-before-track structure, and
put the selected shape, its accepted residual, and the real repair route where a future reader
investigating a stale `merged_sections` record will find them.

**Tasks**:
- [ ] Enumerate every array target reachable from a fragment through `deep_merge` and record the verdict for each: the plain-array arm (fixed in Phase 2), non-`matcher` hook-event arrays (same arm, fixed by the same change), `merge_hook_event_array` (immune — tracks explicitly), `mcpServers` (object-keyed; a first-time key insertion is tracked as `new_object`/`new_value` regardless of nested fields), and `M.append_index_entries` (tracks every processed path unconditionally).
- [ ] Re-confirm the `mcpServers` verdict by reading the `else -- Object: recurse` arm rather than carrying the research report's conclusion forward unchecked.
- [ ] Write `agent-system/extensions/nvim/context/project/neovim/patterns/merge-tracking-contract.md` stating: the dedup-before-track defect and why `manager.resync_all` makes an empty record the steady state; the selected tracking shape and the sibling-retention guard; the accepted residual, naming `.claude/settings.json` as the home for a user grant meant to outlive an unload; that unloading `email` now removes its `permissions.deny` entries; and that a plain redeploy — **not** `--wipe`, which restores `settings.local.json` as the merge base before resyncing — is the repair for a stale record.
- [ ] State in that file that a flat per-key `items` array carries no per-item provenance, so no claim of the form "these N of M grants retract cleanly while the other M-N do not" can be true of this record shape — the correction the companion work needs, written against durable anchors rather than task numbers.
- [ ] Add the file's entry to `agent-system/extensions/nvim/index-entries.json` (path, domain `project`, subdomain `neovim`, topics, keywords, summary, `line_count`, `load_when`), matching the shape of the existing `project/neovim/patterns/*` entries.
- [ ] Update `agent-system/extensions/nvim/README.md` if it enumerates the patterns directory's contents.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and resolve anything it reports for the nvim extension other than a `line_count` drift, which Phase 6's redeploy reconciles.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` over this phase's touched paths, so no suite covers them and the covering check is `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` — doc-lint and task-reference lint, run from the repository root that holds both the deployed tree and the source store — together with `bash .claude/scripts/check-extension-docs.sh` and a diff read-through of the prose.

**Scope Hypothesis**: Five array paths exist through `deep_merge` and only the plain-array arm is defective — the enumeration task above is the confirmation, not an assumption; if a sixth path or a second defective arm turns up, record it here and fix it in this phase rather than closing the sweep against the hypothesis.

**Files to modify**:
- `agent-system/extensions/nvim/context/project/neovim/patterns/merge-tracking-contract.md` - new pattern file recording the tracking contract, the residual, and the repair route
- `agent-system/extensions/nvim/index-entries.json` - new entry for the pattern file; its `line_count` is a derived quantity this phase moves, reconciled by Phase 6's redeploy (no pre-commit hook is installed in this repository, so the drift check is not commit-blocking)
- `agent-system/extensions/nvim/README.md` - patterns listing, if it enumerates directory contents

**Verification**:
- The array-path enumeration is written down with a per-path verdict, including the re-read `mcpServers` arm.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` exits 0.
- `bash .claude/scripts/check-extension-docs.sh` reports nothing for the nvim extension beyond a `line_count` drift.

---

### Phase 6: Repair the four stale records and run the full gate [NOT STARTED]

**Goal**: Replace the four empty tracking records with complete ones by redeploying against the
fixed engine, and verify the whole change set against the complete gate set.

**Tasks**:
- [ ] Re-read `git status --short` and `git log --oneline -5` immediately before starting. Tasks 616 and 617 share this working tree with undeclared scope; if a foreign commit or a foreign uncommitted modification is present, STOP and report it rather than proceeding.
- [ ] Record the four records' pre-repair state (`sapience` allow, `nix` allow, `lean` allow, `email` deny — all `"appended"` with `items: []`) so the repair is demonstrable rather than asserted.
- [ ] Run `timeout 540 bash .claude/scripts/deploy-headless.sh` with the Bash tool's `timeout` parameter raised to 600000. This is the ordinary bootstrap-plus-`resync_all` mode — **not** `--wipe`, which restores `settings.local.json` as the merge base before resyncing and would reproduce the empty records.
- [ ] Re-read `.claude-extensions.json` and assert the four records are now populated with 11, 2, 1, and 7 items respectively, and that sapience's four non-`matcher` hook events also carry non-empty `items`.
- [ ] Confirm `.claude/settings.local.json` still holds all eleven sapience grants and that the redeploy neither duplicated nor dropped any entry.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`.
- [ ] Re-run `nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua"` and confirm it is still fully green after the redeploy.
- [ ] Stage and commit only this task's own files by explicit path — never `git add -A`, a directory, or a glob — reviewing `git status --short` and `git diff --staged` first. Leave `agent-system/extensions/core/.claude-extensions.json` untracked and unstaged.

**Timing**: 1 hour

**Depends on**: 4, 5

**Verification Tier**: full

**Scope Hypothesis**: Exactly four stale records exist in this repository (`sapience` allow, `nix` allow, `lean` allow, `email` deny), plus sapience's four non-`matcher` hook events — measured live during planning. Confirm by re-reading `.claude-extensions.json` before the redeploy; if a fifth appears, assert its repair too rather than closing against the hypothesis.

**Files to modify**:
- `.claude-extensions.json` - the four tracking records, repopulated as a side effect of the redeploy
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set — passes.
- `.claude-extensions.json` shows `items` lengths of 11 (`sapience` allow), 2 (`nix` allow), 1 (`lean` allow), and 7 (`email` deny), and non-empty `items` for sapience's `SessionStart`, `SessionEnd`, `UserPromptSubmit`, and `Stop`.
- `merge_spec.lua` reports 30 successes, 0 failures, 0 errors headless.
- `.claude/settings.local.json` still contains all eleven sapience grants, unduplicated.

---

## Testing & Validation

- [ ] `merge_spec.lua` passes headless with zero failures, covering: fresh merge, re-merge over already-present grants, unmerge after each, a coinciding user grant (removed — the accepted residual, asserted explicitly), sibling-extension retention, and the hooks path as a non-regression.
- [ ] `bash .claude/scripts/tests/run-all.sh --only test-mcp-merge-target.sh,test-deploy-orphans.sh,test-deploy-verify-overlap.sh,test-deploy-propagation.sh,test-index-entries-schema.sh` passes.
- [ ] `bash .claude/scripts/verify-deploy.sh` passes.
- [ ] `.claude-extensions.json`'s four previously-empty records are populated with the declared counts.
- [ ] `grep -rn "specs/" lua/neotex/plugins/ai/shared/extensions/` returns nothing.

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - tracking fix and retained-set-aware unmerge
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - retained-set builder and plumbing
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` - six new cases plus the repointed fixture reader
- `lua/neotex/plugins/ai/shared/extensions/host_settings_fixture.json` - recovered test fixture
- `agent-system/extensions/nvim/context/project/neovim/patterns/merge-tracking-contract.md` - the tracking contract, residual, and repair route
- `agent-system/extensions/nvim/index-entries.json` - index entry for the above
- `.claude-extensions.json` - four repaired tracking records

## Rollback/Contingency

Every phase is a single-file or two-file edit committed separately, so reverting is per-commit
(`git revert <sha>`) and needs no working-tree discard. If the Phase 6 redeploy leaves the
deployed tree or `.claude/settings.local.json` in a bad state, re-run
`timeout 540 bash .claude/scripts/deploy-headless.sh` — it is idempotent — rather than hand-patching
anything under `.claude/**`, which `.claude/rules/source-store-deploy-boundary.md` forbids and
which the next regeneration would silently wipe.

Should a genuine working-tree rollback become necessary, take a snapshot first per
`context/contracts/recovery.md`'s rollback rung, including its out-of-scope override flag for the
deliberate whole-tree case; an ordinary defensive checkpoint before the Phase 6 redeploy uses
`bash .claude/scripts/git-snapshot.sh 615 --no-revert`, which is durable without reverting the
working tree — important here, because sibling tasks 616 and 617 share this tree and a reverting
snapshot would discard their in-flight work.
