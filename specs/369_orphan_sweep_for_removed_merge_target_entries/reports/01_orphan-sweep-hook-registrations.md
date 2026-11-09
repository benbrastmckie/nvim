# Research Report: Task #369

**Task**: 369 - Orphan sweep for removed merge-target entries (hook registrations)
**Started**: 2026-11-08
**Completed**: 2026-11-08
**Effort**: Medium (one focused Lua function + one call-site + doc update + tests; no new
  subsystem)
**Dependencies**: None blocking this task. Task 527 (hook-registration SET lint) depends on
  this task landing first and consuming the identity notion this task settles.
**Sources/Inputs**: Codebase (lua/neotex/plugins/ai/shared/extensions/*.lua,
  agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh,
  agent-system/extensions/core/manifest.json, agent-system/extensions/core/root-files/settings.json,
  agent-system/extensions/core/merge-sources/settings-hooks.json), direct inspection of five
  real deployed repos (`~/.config/nvim` itself, ModelBuilder, Logos/Website, Logos/Theory,
  theorem_proving_in_lean4), specs/state.json (task 527's description)
**Artifacts**: - specs/369_orphan_sweep_for_removed_merge_target_entries/reports/01_orphan-sweep-hook-registrations.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The gap is real, reproducible, and **currently live in five repos**, including this very
  host repo's own deployed `.claude/settings.json` (not just the three/four repos the dispatch
  named) and including the task's own claimed "already repaired" control case, Logos/Theory,
  which is in fact only partially repaired.
- `merge.lua` already has the exact precedent to extend: `remove_orphaned_index_entries`
  (`lua/neotex/plugins/ai/shared/extensions/merge.lua:763`), called from `manager.load` in
  `init.lua` (lines 619-644) *before* `process_merge_targets` re-adds the current extension's
  fresh entries, using a "valid set excluding self, re-added immediately after" pattern. The
  hook-registration sweep should follow this exact call-siting shape, not invent a new one.
- The identity notion is split across two files today and must be unified in `merge.lua`:
  `hook_identity()` (merge.lua:228) recognizes only `.claude/hooks/NAME.sh`-shaped commands;
  `lint-hook-registration-paths.sh`'s `normalize_identity()`/Check C recognize **any** invoked
  script path (so `scripts/NAME.sh` counts too) and explicitly exempt `~/`-anchored paths from
  coverage checking. Both notions must be reconciled into one function both consumers call.
- A real, additional defect shape was found that neither this task's dispatch nor sibling task
  527's (a)/(b)/(c) taxonomy names: a hook surviving under a **different event**, not just a
  different matcher, than current source declares it under (Logos/Theory's
  `validate-no-task-references.sh`, live under both `PreToolUse|Write|Edit` and a stale
  `PostToolUse|Write|Edit` — it now runs twice per Write/Edit in that repo). Flagged as an open
  design question for the plan.
- The `~/`-anchored carve-out (claude-ready-signal.sh, deliberately outside `.claude/`) is a
  concrete, already-deployed example of the "MUST NOT remove a hand-written hook" acceptance
  criterion: it is identity-ineligible under both today's `hook_identity()` and the lint's own
  D1/D2 exemption, so any broadened identity notion must preserve that ineligibility rather than
  widen it to also catch `~/`-anchored commands.

## Context & Scope

This is a research-only dispatch for a `meta` task whose source-store edit target is
`agent-system/extensions/` and `lua/neotex/plugins/ai/` (never `.claude/**`, a disposable deploy
artifact). The goal, per the dispatch file, is to close a structural gap: the extension deploy
mechanism can add and change merge-target content but has no mechanism to remove a registration
whose source-store declaration was deleted, specifically for Claude Code hook registrations in
`.claude/settings.json`. The dispatch supplies two live instances and a described sub-behavior
(cross-matcher migration); this research independently re-verified both, found the sub-behavior
reproduced, and found additional instances and one additional defect shape the dispatch does not
name. No web research was needed or performed — this is an entirely internal, codebase-grounded
question about this repository's own extension-loader mechanics.

## Findings

### Codebase Patterns

**The existing orphan-removal precedent (`remove_orphaned_index_entries`).**
`lua/neotex/plugins/ai/shared/extensions/merge.lua:763` defines
`M.remove_orphaned_index_entries(index_path, valid_prefixes, context_dir)`: it keeps every
non-`project/`-prefixed index entry unconditionally, and for `project/`-prefixed entries keeps
only those matching a currently-valid-prefix AND (optionally) verified to exist on disk. It is
called from `manager.load` in `lua/neotex/plugins/ai/shared/extensions/init.lua:619-644`,
**once per extension load**, immediately **before** `process_merge_targets` (line 647) re-adds
that extension's own fresh entries. `valid_prefixes` is built from every *other* currently-loaded
extension's declared `provides.context` prefixes — the current extension is deliberately excluded
from the valid set at sweep time, because its own entries are about to be re-added by the very
next line. Over a full `resync_all` loop (which calls `manager.load` once per already-loaded
extension with `force=true`), this converges correctly regardless of iteration order, because
`state.json`'s loaded-extension list is already complete before the loop starts — `resync_all`
only ever re-processes extensions already marked loaded; it does not discover new ones mid-loop.

This is the structural precedent the dispatch names and the one to extend, not reinvent. A hook
orphan sweep should follow the identical shape: compute a valid identity set from every *other*
currently-loaded extension's hook declarations (plus root-files), sweep the target's hook arrays
against it immediately before `process_merge_targets`'s `merge_settings(target_path, fragment)`
call for the `settings` merge target (`init.lua:91-103`), relying on that immediately-following
merge to re-add the current extension's own entries.

**The identity split (merge.lua vs. the lint) — must be reconciled in one place.**
`hook_identity()` (`merge.lua:228-237`) resolves identity only for a command matching
`%.claude/hooks/([%w_%-]+%.sh)` — i.e., only paths anchored under `hooks/`. Its own doc comment
(lines 212-215) states explicitly: "a hand-written custom hook (one that does not invoke a
`.claude/hooks/*.sh` path at all) MUST NEVER be touched... every caller below falls through to
exact `vim.deep_equal` comparison whenever this returns nil." `find_hook_match` (line 247),
`normalize_hook_event_array` (line 279), and `merge_hook_event_array` (line 325) all consume this
one identity function, so today's merge-time dedup/replace logic already has a single identity
source *for the merge direction*.

`agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` independently defines
`normalize_identity()` (around line 319) with a **documented, deliberate divergence** (its own
"D4" comment, lines 68-73): "This lint's fragment-coverage identity notion (Check C) is
DELIBERATELY BROADER than merge.lua's own `hook_identity()`... This lint's identity covers ANY
invoked script path (so `scripts/NAME.sh` is a first-class identity too...) `merge.lua` is
outside this lint's file_scope; the divergence is accepted and recorded here, not reconciled.
Do NOT port `hook_identity()`'s `hooks/`-anchored pattern into this lint." The lint's identity key
is `(normalized_path, event, type)` — note it already includes **event**, not just the script
path, which is relevant to the cross-event finding below.

This task's scope statement is explicit that this divergence must now be resolved, in one place
both the sweep and the lint consume — and sibling task 527 (see below) is blocked on this task
landing that single definition first.

**The `~/`-anchor and relative-path carve-outs the lint already encodes (D1/D2) must survive.**
The lint accepts three anchor forms as "correctly resolvable" (`classify_anchor`, lines 303-314):
`"$CLAUDE_PROJECT_DIR"`-prefixed, `/`-absolute, and `~/`-prefixed — and deliberately **excludes
`~/`-anchored paths from both the fragment-coverage and existence checks** (D2, lines 55-57):
"It names a user-supplied, externally-provided script that may legitimately not exist anywhere
under this repo's source store; failing it for that would punish a correct, deliberate
reference." Any broadened identity function this task introduces must preserve this exemption —
a `~/`-anchored command must remain identity-ineligible for sweep purposes exactly as it is for
the lint's coverage check, even though (unlike a true custom hook) it may coincidentally still
"look like" a recognizable script invocation. See the concrete field example below
(`claude-ready-signal.sh`).

**Where fragment and root-files surfaces actually come from.**
`agent-system/extensions/core/manifest.json`'s `merge_targets.settings` entry declares
`source: merge-sources/settings-hooks.json`, `target: .claude/settings.json` — this is the
FRAGMENT surface for the `core` extension, read and merged by `process_merge_targets`
(`init.lua:91-103`) via `merge_mod.merge_settings`. This manifest entry's own `_comment` field
(read directly) already documents, in writing, the exact defect class this task fixes:
"deep_merge also does not self-heal drifted command paths: renaming a hook script here requires
manually removing the stale registration from already-synced repos' settings.json, or it will be
appended alongside the corrected one rather than replacing it (follow-up risk, not fixed by this
mechanism)." This is a prior, explicit, in-source acknowledgment of the gap — strong internal
corroboration that the gap is known and intentional-to-fix, not a surprise finding.

Separately, `agent-system/extensions/core/root-files/settings.json` is the ROOT-FILES surface:
copied via `loader.lua`'s `root_files` category descriptor (line 229-232), which is **install-once**
(`INSTALL_ONCE_ROOT_FILES`, line 134) — copied only when the target does not yet exist, never
overwritten on reload. It *also* carries a `hooks` block today (overlapping substantially, but
not identically, with `merge-sources/settings-hooks.json`'s content) — this is the "root-files
surface" the dispatch's SCOPE bullet names alongside "loaded extension's fragment." Both surfaces
must be unioned to form the valid identity set.

**Interaction with wipe/regenerate — already correctly explained by the dispatch, confirmed.**
`settings_backup.lua` snapshots `settings.json`/`settings.local.json` (plus `.syncprotect`-listed
paths) to a project-root staging directory before `manager.wipe` runs `rm -rf base_dir`
(`init.lua` `manager.wipe`, ~line 1406), and `manager.regenerate` (~line 1347) restores that
snapshot *before* its resync loop (`settings_backup.restore(project_dir, config)` then
`manager.resync_all(...)`, lines ~1369-1378) — restoring first, as the dispatch states, is itself
a deliberate fix for an earlier defect (restoring after the load loop would have clobbered
fragment merges). Confirmed by direct reading: this means a stale hook registration is
structurally immune to `[Reload All]`/`[Regenerate]`/`deploy-headless.sh --wipe`, because the
restored snapshot (carrying the stale entry) becomes the merge base `resync_all` merges fresh
fragments on top of. Only a sweep integrated into the load/merge path itself (or a one-time hand
repair) can remove it.

**Detection-only orphan mechanism already exists, but for a different axis entirely.**
`manager.find_orphans` (`init.lua:1289`) / `verify_mod.find_orphans`
(`lua/neotex/plugins/ai/shared/extensions/verify.lua:1000`) answer "what file is present in the
deploy tree that no active extension declares?" — a **whole-file, deploy-tree-relative** set
difference, explicitly **detection only** (never deletes, per its own header comment at
verify.lua:894-906: "the additive-only copy/merge semantics are deliberately preserved regardless
of what it finds"). `.claude/settings.json` itself is always "declared" (it is the install-once
root file), so it can never appear as an orphan under this mechanism — confirming this task's
gap is genuinely unaddressed by any existing code path, not a narrower case of something already
solved.

### Field Evidence (real deployed repos, inspected directly — not synthetic)

Five real repos were inspected directly against the current source store's two settings surfaces
(`agent-system/extensions/core/root-files/settings.json` and
`agent-system/extensions/core/merge-sources/settings-hooks.json`), none of which register
`tts-notify.sh`+`idle_prompt`, a bare `wezterm-notify.sh`, `wezterm-clear-status.sh`, or
`claude-ready-signal.sh` in any form:

| Repo | Orphans found (hook, event/matcher) | Notes |
|---|---|---|
| `~/.config/nvim` (host repo, deployed `.claude/settings.json`) | `claude-ready-signal.sh` under `SessionStart\|startup`, bare CWD-relative path `bash scripts/claude-ready-signal.sh` (no `.claude/` or `~/` anchor at all) | **This is the dispatch's own cited "LIVE INSTANCE," confirmed still unfixed today.** Also a lint-Check-A path-shape violation independently. |
| ModelBuilder | `tts-notify.sh`+`wezterm-notify.sh` under `Stop\|*`; `Notification` matcher widened to `permission_prompt\|idle_prompt\|elicitation_dialog`; `wezterm-clear-status.sh` under `UserPromptSubmit\|*`; `claude-ready-signal.sh` under `SessionStart\|startup` (`~/`-anchored form: `bash ~/.config/nvim/scripts/claude-ready-signal.sh`) | Also entirely on the old CWD-relative path form throughout — a separate, already-tracked lint concern, not this task's. |
| Logos/Website | Same pattern as ModelBuilder (`tts-notify.sh`/`wezterm-notify.sh` under `Stop\|*`, widened `Notification` matcher, `wezterm-clear-status.sh` under `UserPromptSubmit\|*`, `~/`-anchored `claude-ready-signal.sh`) | |
| theorem_proving_in_lean4 | None of the "shape (a)" orphan-registration class found by this inspection. Separately carries shape-(c) dead-script registrations (`claude-stop-notify.sh`, `wezterm-preflight-status.sh` both registered and both confirmed **absent on disk** in this repo's `.claude/hooks/`) — this is a deploy-completeness gap (registration references a real, currently-declared hook whose file never landed locally), a different defect class from an orphan sweep's target. | Confirmed via `ls`: both files genuinely missing. |
| Logos/Theory | **Incompletely repaired**, contrary to the dispatch's framing. Confirmed via direct inspection on 2026-11-08: (1) `wezterm-clear-status.sh` orphan still present under `UserPromptSubmit\|*`, CWD-relative, script absent from current source entirely; (2) a stale CWD-relative `validate-no-task-references.sh` duplicate registered under `PostToolUse\|Write\|Edit`, while current source registers that hook only under `PreToolUse\|Write\|Edit` — the hook now **runs twice** per Write/Edit tool call in this repo. Also still carries the `~/`-anchored `claude-ready-signal.sh` (correctly left alone — see carve-out discussion above). | The 2026-11-07 by-hand repair fixed the TTS-duplication/Notification-widening pair the dispatch described but missed these two. **The plan/implementation phase should re-verify Theory's state rather than treat it as clean.** |

Fourteen other deployed repos were not independently re-verified in this research pass (the
dispatch's own claim that they are clean is taken as given scope context, not independently
re-confirmed here, given the time budget); the plan/implementation phase's regression-safety
measurement (acceptance criterion 4) should include them as the no-change control set exactly as
scoped.

### An additional, previously unnamed defect shape: cross-EVENT survival

Sibling task 527 (`specs/state.json`, project_number 527, "Assert the deployed hook registration
SET matches the merge-source") names three measured drift shapes — (a) undeclared registration,
(b) same hook under two different matchers of one event (double-fire), (c) dead-script
registration — and task 369's own dispatch separately names the cross-matcher migration
sub-behavior (Notification's `idle_prompt` narrowing). Logos/Theory's `validate-no-task-references.sh`
finding above is a fourth, **cross-EVENT** shape: the *same* hook script now runs under
`PreToolUse` in current source, but a stale copy is retained under `PostToolUse` in the deployed
file — not a matcher change within one event, but a wholesale *event* change. `deep_merge`
(merge.lua:359) calls `merge_hook_event_array` once per top-level `hooks.<EVENT>` key
independently (each event's array is a separate `pairs(source)` iteration), so nothing in the
existing merge machinery — nor the dispatch's SUB-BEHAVIOR note, which is scoped to "across
blocks of the same event" — ever compares a `PreToolUse` registration against a `PostToolUse`
one. This is a genuine open design question for the plan: should "the source is authoritative
about WHERE its own hooks register" extend across events, not only across matchers within one
event? The lint's own identity key already includes `event` as a dimension
(`(normalized_path, event, type)`), which would make such a cross-event comparison natural to add
to the *same* reconciled identity notion this task is already settling — but it is a real scope
decision, not a mechanical consequence of anything already decided, and should be called out
explicitly as a plan-time choice rather than silently included or silently deferred.

## Recommendations

1. **Hoist a single, broadened identity function into `merge.lua`**, consumed by both the new
   sweep and (per task 527's stated dependency) the lint's existing Check C/D. Recommended shape:
   extend `hook_identity()` to recognize any invoked script path (not only `hooks/`-anchored
   ones) using the same anchor-stripping logic the lint's `normalize_identity()` already encodes,
   while preserving the `~/`-anchor exemption (never identity-eligible) and the existing
   bare-command-with-no-`.sh`-invocation-at-all exemption (never identity-eligible). `find_hook_match`,
   `normalize_hook_event_array`, and `merge_hook_event_array` need no changes beyond calling the
   broadened function — they already fall through to `vim.deep_equal` whenever identity
   resolution returns `nil`, which is exactly the required custom-hook carve-out.
2. **Site the sweep exactly where `remove_orphaned_index_entries` is sited**: inside
   `manager.load`, immediately before the `merge_targets.settings` branch of
   `process_merge_targets` runs for the current extension, over the union of (every *other*
   currently-loaded extension's `merge_targets.settings` fragment) and (`root-files/settings.json`'s
   own hooks). This reuses the exact "sweep-excluding-self, immediately re-added by the next
   line" convergence property that already makes the index-entry sweep order-independent across
   a `resync_all` loop.
3. **Decide the cross-event question explicitly in the plan**, rather than letting it default
   either way silently — see the dedicated finding above. Recommend making the identity-key
   dimension explicit in the design doc regardless of which way it is decided, so a future reader
   does not have to re-derive it from the two tasks' texts the way this research did.
3. **Plan the acceptance-criterion-6 documentation addition to extend, not duplicate,
   `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md`**
   (already indexed at `.claude/context/index.json` under
   `standards/source-store-deploy-boundary-narrative.md`) — it is the existing, already-discovered
   home for "what the deploy can and cannot do" statements; a new standalone file would duplicate
   rather than extend the established narrative.
4. **Re-verify Logos/Theory's actual state before using it as a "repaired" baseline** in the
   regression-safety before/after measurement — it is not currently clean (see Field Evidence
   table). Measure all five repos found with live orphans (including the host repo itself), not
   only the four the dispatch names, for acceptance criterion 4's before/after table.
5. **Model new regression tests on `merge_spec.lua`'s existing custom-hook-carve-out test**
   (`lua/neotex/plugins/ai/shared/extensions/merge_spec.lua:232-269`, "NEVER touches a hand-written
   hook whose command does not invoke a .claude/hooks/*.sh path") and its real-fragment-propagation
   test (lines 271-317, which reads the actual on-disk `settings-hooks.json` rather than a
   constructed fixture) — both are precedents for acceptance criterion 2's "dedicated regression
   test" and the dispatch's "never only a synthetic fixture" requirement. The `~/`-anchored
   `claude-ready-signal.sh` registration found in three real repos is a ready-made, already-field-
   verified fixture for exactly this test (a command that *would* be swept under a naively
   broadened identity function, and must not be).

## Decisions

- The single shared identity function belongs in `merge.lua` (the merge-time consumer), not in
  the lint script — `merge.lua` is the lower-level, dependency-free module both the loader and
  (via a lint-side `require`/port) the lint can consume; the lint already explicitly defers to
  merge.lua's eventual reconciliation (its own D4 comment names `merge.lua` as "outside this
  lint's file_scope" only because the divergence had not yet been resolved there).
- The sweep call site is `manager.load`'s per-extension loop in `init.lua`, mirroring
  `remove_orphaned_index_entries`'s existing call site exactly, not a new top-level pass in
  `resync_all` or `manager.regenerate` — consistency with the one mechanism this codebase already
  trusts for this exact shape of problem is itself a risk-reduction decision, not only a
  style preference.
- Logos/Theory must not be treated as a clean/repaired control in the before/after measurement;
  it is a fifth live-orphan repo, discovered by this research, and should be measured as such.

## Risks & Mitigations

- **Risk**: a broadened identity function could widen `~/`-anchored or truly custom hooks into
  sweep-eligibility, which the dispatch calls "the single most dangerous possible regression."
  **Mitigation**: the broadening must be a strict superset of path *shapes recognized as script
  invocations*, while keeping the lint's existing `~/`-anchor exemption and the no-`.sh`-token
  fallback-to-`nil` behavior completely intact; the `claude-ready-signal.sh` `~/`-anchored
  registration (found live in three repos) is a ready-made regression fixture proving this
  exemption holds under the new function, not only under the old one.
- **Risk**: sweeping before the current extension's own fresh merge (mirroring the index-entry
  pattern) could transiently remove an entry inside one `manager.load` call if the immediately-
  following `merge_settings` call fails partway. **Mitigation**: `process_merge_targets`'s
  existing failure path already triggers a full rollback (`init.lua:650-674`,
  `loader_mod.remove_installed_files` + `reverse_merge_targets`) on any `load_ok == false`; no new
  rollback mechanism is needed as long as the sweep runs inside the same `pcall`-guarded block the
  existing index-entry sweep already runs inside.
- **Risk**: the cross-event question (new finding above) could be implicitly decided in either
  direction by whichever engineer writes the identity function first, without anyone noticing a
  decision was made. **Mitigation**: the plan should state the decision explicitly rather than
  leaving it to fall out of an implementation detail.
- **Risk**: treating Logos/Theory as already-clean (per the dispatch's framing) could cause the
  before/after regression measurement to silently skip two real defects.  **Mitigation**: this
  research's Field Evidence table is itself the mitigation — the plan/implementation phase has it
  in hand now.

## Context Extension Recommendations

- **Topic**: hook-registration lifecycle (add/change/orphan-sweep) across the extension loader.
- **Gap**: `source-store-deploy-boundary-narrative.md` currently states the general add/change-
  not-delete boundary but does not yet enumerate *which* merge targets sweep orphans and which do
  not (index entries: yes, via `remove_orphaned_index_entries`; hook registrations: not yet,
  pending this task; MCP servers merged via the same `merge_settings`/`unmerge_settings` path:
  not addressed by either mechanism today and worth a one-line note once this task lands).
- **Recommendation**: this task's own acceptance criterion 6 already calls for exactly this
  addition to `source-store-deploy-boundary-narrative.md`; no separate new context file is
  needed. Flagging here only so the implementation phase does not independently rediscover that
  this is the right file (already confirmed indexed and already the established home for this
  exact class of statement).

## Appendix

- Search queries / inspection performed: `grep`/`find` across
  `lua/neotex/plugins/ai/shared/extensions/*.lua`,
  `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh`; direct `Read` of
  `merge.lua` (full file), `settings_backup.lua` (full file), relevant sections of `init.lua`
  (process_merge_targets, reverse_merge_targets, the per-extension load loop, resync_all,
  find_orphans) and `loader.lua` (INSTALL_ONCE_ROOT_FILES, CATEGORY_DESCRIPTORS); `python3 -c`
  JSON inspection of `agent-system/extensions/core/root-files/settings.json`,
  `agent-system/extensions/core/manifest.json`, `agent-system/extensions/core/merge-sources/settings-hooks.json`,
  and the deployed `.claude/settings.json` of `~/.config/nvim`, `~/Projects/ModelBuilder`,
  `~/Projects/Logos/Website`, `~/Projects/Logos/Theory`, `~/Projects/theorem_proving_in_lean4`;
  `jq` query of `specs/state.json` for task 527's description.
- Key file/line references: `merge.lua:228` (`hook_identity`), `:247` (`find_hook_match`), `:279`
  (`normalize_hook_event_array`), `:325` (`merge_hook_event_array`), `:763`
  (`remove_orphaned_index_entries`); `init.lua:91-103` (settings merge call site), `:619-644`
  (index-entry sweep call site, the precedent), `:1047-1101` (`resync_all`), `:1347-1389`
  (`regenerate`/`wipe`); `loader.lua:134-144` (`INSTALL_ONCE_ROOT_FILES`); `merge_spec.lua:232-269`
  and `:271-317` (test precedents); `lint-hook-registration-paths.sh` lines 1-150 (header
  commentary: D1-D6), `:303-337` (`classify_anchor`/`normalize_identity`/`check_exists`),
  `:515-551` (Check C/D jq-based inventory).
- Related task: 527 (`hook_registration_set_lint_assertion`), which depends on this task and must
  consume the identity notion this task settles rather than defining a second one.
