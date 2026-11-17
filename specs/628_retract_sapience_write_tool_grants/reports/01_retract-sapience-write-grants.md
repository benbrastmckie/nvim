# Research Report: Task #628

- **Task**: 628 - Retract sapience write-tool grants from deployed repositories
- **Started**: 2026-11-17T00:00:00Z
- **Completed**: 2026-11-17T00:00:00Z
- **Effort**: ~2 hours (codebase-only; no web research needed)
- **Dependencies**: task 369 (`orphan_sweep_for_removed_merge_target_entries`, archived `[COMPLETED]`), task 527 (`hook_registration_set_lint_assertion`, `[COMPLETED]`)
- **Sources/Inputs**: codebase exploration only (merge engine Lua source, agent-system sapience extension, task 369/527 artifacts, live measurement of 5 deployed repos)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The actual merge/deploy engine for `.claude/**` is the Neovim Lua plugin at
  `lua/neotex/plugins/ai/shared/extensions/{merge,init,settings_backup,state}.lua` — this is
  genuine, directly-editable source code (not a `.claude/**` deploy artifact), loaded by
  `agent-system/extensions/core/scripts/deploy-headless.sh` via `nvim --headless` regardless of
  which repo is passed as its `TARGET_REPO` argument. Fixing it here fixes every target repo's
  future redeploys, including the four other repositories named in the dispatch.
- The merge engine's single-call primitive (`deep_merge`/`M.merge_settings`) is additive-only by
  design and always will be: on every call it re-records every item the fragment currently
  declares into the tracked structure (so unload always has something to remove), but it never
  removes an item from the target that is simply no longer declared. This is confirmed directly
  from the code and its own comment ("Recording every item -- not only the ones this merge
  actually appended -- is load-bearing for unload...").
- **Retraction already exists as two separate, already-tested mechanisms in this codebase** —
  this is not a gap that needs a new concept, only a wiring gap:
  1. `M.unmerge_settings` + `build_retained_fragments`, driven by an extension's own previously
     recorded `merged_sections` (persisted per-extension in `.claude-extensions.json`), called
     only from `manager.unload` (and therefore from `manager.reload`, which is unload-then-load).
  2. A load-time "hook orphan sweep" (`build_hook_valid_set` + `M.remove_orphaned_hook_registrations`,
     built by task 369 and extended into a detection-only lint by task 527's Check E), which runs
     inside **every** `manager.load` call -- including the forced in-place reloads
     `manager.resync_all` performs -- but is deliberately, explicitly scoped to the `hooks` key
     only. Both its own doc comment and the lint's "D6" ruling state in so many words that
     `permissions`/`env`/`mcpServers`/`settings.local.json` are read and rewritten byte-for-byte
     unchanged.
- `deploy-headless.sh`'s default (non-`--wipe`) path — the one the dispatch instructs this task
  to use for redeploy — calls `manager.resync_all`, whose own doc comment states it **"Never
  unloads"**, specifically to avoid a destructive intermediate state during a bulk resync. This is
  why the narrowed sapience fragment (7 grants) never reaches any of the five already-loaded
  repos even after repeated redeploys: nothing in that path ever calls `unmerge_settings`.
- `deploy-headless.sh --wipe` (`manager.wipe`) does **not** help either, and should not be
  reached for as a workaround: it snapshots `settings.local.json` byte-for-byte to a staging
  directory and restores that exact same byte content after rebuilding `.claude/`, rather than
  re-merging from the live fragments. A wipe round-trips the stale 11-grant file unchanged.
- Measured live: all five repositories named in the dispatch (`~/.dotfiles`, this repo,
  `~/Projects/BimodalLogic`, `~/Projects/Sapience/sf1-engine`, `~/Projects/Sapience/sapience-app`)
  currently carry exactly 11 `mcp__sapience__*` grants in `.claude/settings.local.json`,
  confirming the dispatch's measured evidence is still accurate today.
- **Recommendation**: generalize mechanism (1) above -- reuse `unmerge_settings` and the
  already-persisted per-extension `merged_sections` -- into `manager.load`'s forced-reload branch
  (when `opts.force` is set and the extension is already loaded), applied across every
  `merge_targets.settings`/`merge_targets.mcp` key uniformly (hooks, permissions, and any future
  key), not only permissions. This is the "general fix, same shape as 527" the dispatch
  anticipated, but it turns out to require no new retraction concept: it is purely a sequencing
  fix (call the existing unmerge with the extension's *own* prior tracked record, using the
  already-existing sibling-retention guard, immediately before the existing merge call) in a code
  path that currently skips it. See Recommendations for the full reasoning and the discrimination
  rule, and Risks & Mitigations for why a parallel permissions-specific orphan sweep (mirroring
  task 369's hook sweep) is a viable but strictly inferior alternative.

## Context & Scope

The dispatch (`specs/628_retract_sapience_write_tool_grants/.dispatch/11.md`) asks this phase to
determine why the sapience extension's narrowed 7-tool permission grant (`settings-fragment.json`)
never reaches any of the five repositories that loaded the extension before the narrowing, and to
decide between (1) teaching the merge engine a general retraction mechanism, coordinated with
task 527's mechanism rather than duplicating it, or (2) a one-time migration pass plus a
`verify-deploy.sh` gate. Research was scoped to: reading task 527's actual plan/summary (to learn
precisely what mechanism it built, since the dispatch's framing assumed it might already supply
retraction); reading the merge engine's Lua source directly; and measuring the five live
repositories named in the dispatch. No web research was needed or used — this is a purely
internal, codebase-specific question.

## Findings

### Codebase Patterns

**What task 527 actually built** (read directly from
`specs/527_hook_registration_set_lint_assertion/{plans,summaries}/01_*.md`): a fifth check
("Check E") inside the existing `lint-hook-registration-paths.sh`, wired into Gate 21 of
`verify-deploy.sh`, that *detects* three shapes of drift between a deployed `.claude/settings.json`'s
`(event, matcher, hook-identity)` registration set and what the source declares. It is
**detection-only** — the plan's own Non-Goals list states "Remediating any other repo's measured
drift... is not this task" — and it is explicitly scoped to the `hooks` key: its design note D6
states "`root-files/settings.local.json` is OUT OF SCOPE for every check in this lint", and its
own Non-Goals list `env`, `permissions`, `statusLine` and `mcpServers` as "out of scope, never
reported, never touched." So task 527 supplies neither a retraction mechanism nor any permissions
coverage; "coordinating with its mechanism" means reusing its *pattern* (a declared-vs-deployed
set comparison, wired into the existing Gate 21) for detection if a new permissions check is
added, not finding retraction machinery already built there.

**The merge engine's additive-only core** (`lua/neotex/plugins/ai/shared/extensions/merge.lua`,
`deep_merge`, lines 376-456): every array-valued key is merged by recording **every** item the
fragment currently declares into `tracked[key].items`, inserting into the target only those not
already present (`vim.deep_equal` dedup). The function's own comment explains this is
intentional: dedup-before-track would make unload a no-op after the first reload. The practical
consequence verified against this repo's own `.claude-extensions.json`: its
`extensions.sapience.merged_sections.settings.permissions.allow.items` array already lists
exactly the 7 current grants (the tracked record was correctly refreshed to the new, narrow
fragment at some prior reload), while `.claude/settings.local.json` on disk still carries all 11
— direct, reproducible proof that a reload recomputes the tracked record from the new fragment
but never diffs it against the *old* tracked record to find and remove what dropped out.

**Retraction mechanism 1 — `M.unmerge_settings`** (`merge.lua` lines 517-653): removes exactly the
items recorded in a passed-in `tracked_entries` table (an extension's own prior `merged_sections`),
with an `opts.retained_fragments` guard that re-checks every currently-loaded *sibling*
extension's own current fragment at the same key path before removing an item, so an item two
extensions both declare is never dropped by one extension's unload/retraction. This function is
format-agnostic over the merge target — it already correctly handles `permissions.allow` arrays
(the "appended" branch), not just hooks. It is called only from `manager.unload`
(`init.lua` ~line 1037-1050) and, transitively, from `manager.reload` (unload then load,
`init.lua` line 1165-1189).

**Retraction mechanism 2 — the hook orphan sweep** (`build_hook_valid_set` +
`M.remove_orphaned_hook_registrations`, built by task 369, `init.lua` lines 115-158 and
`merge.lua` lines 930-1023): runs inside **every** `manager.load` call, including a forced
in-place reload, by unioning the *current* fragments of every other loaded extension and removing
any deployed hook registration whose `(event, matcher, identity)` is absent from that union — this
is the load-time analogue that actually does fix stale *hook* drift across a bulk `resync_all`.
Its own doc comment states explicitly: "Touches nothing outside the `hooks` key: every other
top-level key (`env`, `permissions`, `mcpServers`, ...) is read and re-written byte-for-byte
unchanged." Task 369's own before/after measurements independently confirm this: every repo's
`env`/`permissions` fingerprint (`jq -S '{env, permissions}' .claude/settings.json | sha256sum`)
is asserted byte-identical before and after the sweep, in both the implementation plan and the
two measurement records — i.e., leaving `permissions` untouched was a *deliberate, verified
invariant* of that task, not an oversight.

**Why `deploy-headless.sh`'s default path cannot retract anything**: its non-`--wipe` branch
invokes `manager.resync_all` (`init.lua` lines 1259-1280+), whose doc comment states: "**Never
unloads**: each extension is re-loaded in place via `manager.load(..., {force = true})`, so there
is no destructive intermediate 'everything unloaded' state." Since `manager.load`'s own body
never calls `unmerge_settings` (only `manager.unload` does), and the hook orphan sweep inside
`manager.load` is scoped to `hooks` only, nothing in the default redeploy path can ever retract a
stale `permissions.allow` entry, for sapience or for any other extension.

**Why `--wipe` is not a usable workaround**: `manager.wipe` (`init.lua` lines 1639-1664) calls
`settings_backup.backup` before `rm -rf .claude`, then `manager.regenerate`, and the caller is
expected to follow with `settings_backup.restore`. `settings_backup.lua` (read in full) snapshots
`settings.json`/`settings.local.json` as raw file content and restores that *exact same content*
verbatim after regeneration — it is a lossless round-trip of the pre-wipe file, not a re-merge
from fresh fragments. A wipe therefore reproduces the stale 11-grant `settings.local.json`
unchanged.

**Where the fix must live, and why it already reaches all five repos**: `deploy-headless.sh`
(lines ~388-403) runs `nvim --headless` with `cd "$TARGET"` only setting the working directory the
Lua code passes as `project_dir` — Neovim's own runtime/config path (where
`lua/neotex/plugins/ai/shared/extensions/*.lua` is `require`d from) is this repository
(`~/.config/nvim`), independent of `$TARGET`. `deploy-headless.sh --minimal-init DIR
[TARGET_REPO]` already accepts an explicit target-repo argument. So a fix landed in this
repository's merge engine takes effect for every repository redeployed from here, including the
four other repositories named in the dispatch, with no separate migration script needed — each
simply needs `deploy-headless.sh` run against it once after the fix lands.

**Discrimination rule already built into `unmerge_settings`** (relevant to the dispatch's
explicit requirement that retraction "not clobber hand-added local grants a user legitimately
owns"): `remove_tracked` (the function `unmerge_settings` drives) iterates only the keys present
in the **tracked** structure passed to it — never the keys/items actually present in the live
settings file. A grant a user hand-added directly in `settings.local.json` was never recorded in
any extension's `merged_sections`, so it is never visited by `remove_tracked` at all; it survives
structurally, by construction, with no special-case needed. The only residual edge case (already
accepted today by the existing unload path, not newly introduced by extending its use) is a
user-typed grant that happens to be *byte-identical* to a string a loaded extension's fragment
also declares — `vim.deep_equal` cannot distinguish provenance for an identical string, same as
today.

### Live Measurement (reproducing the dispatch's MEASURED EVIDENCE)

```
~/.dotfiles                              : 11 sapience grants
~/.config/nvim (this repo)                : 11 sapience grants
~/Projects/BimodalLogic                  : 11 sapience grants
~/Projects/Sapience/sf1-engine           : 11 sapience grants
~/Projects/Sapience/sapience-app         : 11 sapience grants
```
All five currently grant all four write tools (`sapience_remember`, `sapience_wrapup`,
`sapience_handoff`, `sapience_adddoc`) alongside the seven read-shaped tools. The dispatch's
"11/7" figure is confirmed unchanged today.

### External Resources

None consulted — this is an internal merge-engine question with no external documentation
surface; the codebase itself is authoritative.

## Recommendations

1. **Adopt SCOPE option (1), generalized, not a permissions-specific reimplementation.** Extend
   `manager.load`'s already-loaded + `opts.force` branch (the one `manager.resync_all` and a
   direct `manager.load(name, {force=true})` call both exercise) so that, immediately *before*
   `process_merge_targets` runs for this extension, it:
   - Reads this extension's own prior `merged_sections` from the state snapshot already taken at
     the top of `manager.load` (via `state_mod.get_merged_sections`, which already exists and is
     already used by `manager.unload` for exactly this purpose) — i.e. the record from *before*
     this call's own merge overwrites it.
   - Builds `retained_fragments` via `build_retained_fragments` (already a local function in
     `init.lua`, already used by `manager.unload`) over every *other* currently-loaded extension
     declaring the same merge target.
   - Calls `merge_mod.unmerge_settings(target_path, old_merged_sections.settings,
     {retained_fragments = ...})` (and the parallel call for `.mcp`, if present) using the
     existing function verbatim — no new removal logic.
   - Only then runs the normal `process_merge_targets` merge against the *current* fragment, as
     today.

   This generalizes across every settings/mcp key (hooks, permissions, and any future key any
   extension's fragment declares) in one place, reuses 100% of already-tested primitives
   (`unmerge_settings`, `build_retained_fragments`, `get_merged_sections`), and requires no new
   data to be tracked (the per-extension `merged_sections` record already persists in
   `.claude-extensions.json` today). It is a sequencing fix, not a new mechanism — the exact
   "general fix, same shape task 527 needs" the dispatch anticipated, except that the reusable
   shape already existed (`unmerge_settings`) rather than needing task-527-style new
   construction.

2. **Let redeploy do the actual remediation; do not write a separate migration script.** Because
   Neovim's runtime config (where the merge engine lives) is this repository regardless of
   `deploy-headless.sh`'s `TARGET_REPO` argument, landing recommendation 1 and then running
   `deploy-headless.sh` once against each of the five repositories (this one plus the four others
   named in the dispatch) is itself the full remediation for ACCEPTANCE's "all five repositories'
   ... grant exactly the seven read-shaped sapience tools" — no hand-edit or separate migration
   script is needed or should be written. The implementing task should budget one
   `deploy-headless.sh <target>` run per repository (five total, one of them this repo) as its
   verification step for this criterion, each confirmed via `verify-sapience-mcp.sh` (check (e)
   for this repo; a parity check of the merged grant count for the other four, which do not carry
   this repo's own `verify-sapience-mcp.sh` invocation context without `--project`).

3. **Rewrite `sapience-write-path.md`'s pre-existing-residual caveat** (ACCEPTANCE's fourth
   bullet) once recommendation 1 lands and has been exercised: the current paragraph ("A
   repository that loaded sapience before this grant was narrowed keeps the already-merged
   write-tool entries... until the additive-only merge engine gains retraction, or the file is
   hand-edited") should be replaced with a statement that a force-reload/resync now retracts a
   narrowed grant automatically, and that the merge engine's core `deep_merge` primitive remains
   additive-only by design — retraction is a separate, now-wired step, not a property of
   `deep_merge` itself.

4. **Leave task 527's lint and Gate 21 untouched for this task.** A parallel permissions-SET
   detection check (mirroring Check E's pattern against `permissions.allow`/`settings.local.json`)
   is a reasonable follow-up in its own right, but is not required to satisfy this task's
   ACCEPTANCE criteria once recommendation 1 is implemented and exercised across the five repos:
   `verify-sapience-mcp.sh`'s own check (e) already exists and is sapience-specific, and
   ACCEPTANCE names that check, not a new generic gate. Building a new detection check now would
   duplicate effort the plan phase should treat as optional, out-of-scope polish rather than a
   blocking requirement — see Risks & Mitigations for the fuller tradeoff if the plan phase wants
   to include it anyway.

## Decisions

- **Option (1) (merge-engine retraction), not option (2) (migration + gate), is the right choice**,
  because the "retraction mechanism" it requires already exists (`unmerge_settings` +
  `build_retained_fragments` + `get_merged_sections`) and only needs a new call site, making it
  *lower* effort and *more general* than hand-migrating five files and building a new gate that
  would need to be re-run by hand again the next time any extension's fragment narrows anything.
- **The fix belongs in `manager.load`'s forced-reload branch, not in a new permissions-specific
  orphan sweep modeled on task 369's hook sweep.** The hook sweep's cross-extension "valid set
  from everyone's current fragment" design was necessary there because hook commands carry no
  reliable notion of "which extension, and which of its own past tracked items, put this exact
  entry here" cheaply available at sweep time for an arbitrary already-loaded extension *other*
  than the one being (re)loaded. For a forced reload, that information already exists for free:
  the extension being reloaded is exactly the one whose own prior `merged_sections` is already on
  disk, so the narrower, already-tested `unmerge_settings` primitive is the correct, minimal tool.
- **The discrimination rule for not clobbering a user's hand-added grant is the existing one
  `unmerge_settings`/`remove_tracked` already enforces by construction** (only items present in
  the extension's own previously-recorded tracked structure are ever candidates for removal) —
  this task does not need to invent a new rule, only to exercise the existing one from a new call
  site.
- **No new migration script and no new verify-deploy.sh gate are required artifacts of this
  task.** `deploy-headless.sh <target_repo>`, run once per repository after the engine fix lands,
  is both the remediation and (together with `verify-sapience-mcp.sh`) the verification.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The forced-reload unmerge-then-remerge sequencing change has a behavior-changing side effect on hooks too (since it now also runs ahead of the existing hook orphan sweep for every extension, not only sapience) | H | L | Mirror task 527 Phase 2's own precedent: capture the full `--verbose`/settings-file output for every currently-loaded extension's force-reload before the change, and diff it byte-for-byte after, for both the hooks and permissions keys, before accepting the change. |
| `get_merged_sections`'s stored record could itself already be stale/wrong for an extension whose fragment changed more than once without an intervening force-reload (e.g. skipped a cycle) | M | L | The record is always refreshed to the *current* fragment at every `process_merge_targets` call (confirmed above for this repo's own sapience entry), so staleness cannot accumulate across multiple narrowings between reloads -- each reload's "old" record already reflects the most recent prior reload, by construction. |
| A permissions-SET detection check (recommendation 4's deferred follow-up) is wanted anyway for future regression coverage | M | M | Defer to a follow-up task rather than this one; if the plan phase chooses to include it, model it directly on Check E's declared-vs-deployed pattern and Gate 21's wiring, as a new check inside the same lint or a narrow sibling, never a parallel reimplementation of the identity/carve-out concept. |
| Running `deploy-headless.sh` against the four *other* repositories from this session requires those repositories to be reachable on this machine and their own deploy-lock/territory discipline respected | M | L | All four are local paths on this same machine (confirmed reachable during this research's measurement pass); the implementing phase should still treat each as an independent, out-of-tree target and avoid any destructive git operation there, per `context/patterns/external-process-wait.md`/git-safety norms applied per-repo. |
| `--wipe` is reached for as a "simpler" workaround during implementation | M | L | Explicitly ruled out in this report (Findings, "Why `--wipe` is not a usable workaround") with the exact mechanism (byte-for-byte `settings_backup` round-trip) cited; the plan should not need to re-derive this. |

## Context Extension Recommendations

- **Topic**: the merge engine's retraction primitives and their current call-site coverage
  (`unmerge_settings`/`build_retained_fragments` at unload-only; the hook orphan sweep at
  load-time but hooks-only; `resync_all`'s "never unloads" design).
- **Gap**: no existing `.claude/context/` or `agent-system/extensions/*/context/` file documents
  this three-way mechanism map in one place; a reader has to read `merge.lua`/`init.lua` directly
  (as this report did) to learn it, or re-derive it from task 369/527's archived artifacts, which
  are task-scoped and will eventually be archived further / renumbered.
- **Recommendation**: once the implementing task lands recommendation 1, add a short subsection
  to `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md`
  (which already carries the hooks-specific "Source-Store-Relative vs. Deploy-Target-Relative
  Existence" subsection task 527 added) or a new sibling narrative file, naming by durable
  function name (never by task number): `M.unmerge_settings`, `build_retained_fragments`,
  `get_merged_sections`, the hook orphan sweep, and `manager.resync_all`'s "never unloads"
  invariant, plus the forced-reload retraction sequencing this task adds. This closes the same
  kind of knowledge gap task 527's own D7 note closed for the existence-boundary question.

## Appendix

### Search queries / commands used

- `jq '.extensions.sapience' .claude-extensions.json` (this repo) — confirmed `merged_sections`
  already reflects the narrow 7-grant fragment while the deployed file does not.
- `jq '.permissions.allow[]? | select(startswith("mcp__sapience__"))' .claude/settings.local.json`
  — run against all five repositories named in the dispatch; all five returned all 11 grants.
- Direct reads of `lua/neotex/plugins/ai/shared/extensions/{merge,init,settings_backup,state}.lua`
  (the actual merge engine) and `agent-system/extensions/core/scripts/deploy-headless.sh` (the
  headless invocation wrapper).
- Direct reads of `specs/527_hook_registration_set_lint_assertion/{plans,summaries}/01_*.md` and
  `specs/archive/369_orphan_sweep_for_removed_merge_target_entries/{plans,records,summaries}/*.md`.
- Direct reads of `agent-system/extensions/sapience/{manifest.json,settings-fragment.json}` and
  `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` (D6 ruling).

### References

- `lua/neotex/plugins/ai/shared/extensions/merge.lua` (lines 376-456 `deep_merge`; 465-496
  `M.merge_settings`; 517-653 `M.unmerge_settings`; 930-1023 `M.remove_orphaned_hook_registrations`).
- `lua/neotex/plugins/ai/shared/extensions/init.lua` (lines 115-158 `build_hook_valid_set`;
  179-215 `build_retained_fragments`; 474-920+ `manager.load`; 1165-1189 `manager.reload`;
  1259-1370+ `manager.resync_all`; 1639-1664 `manager.wipe`).
- `lua/neotex/plugins/ai/shared/extensions/settings_backup.lua` (full file read; confirms
  byte-for-byte snapshot/restore semantics).
- `lua/neotex/plugins/ai/shared/extensions/state.lua` (line 235 `M.get_merged_sections`).
- `agent-system/extensions/core/scripts/deploy-headless.sh` (TARGET_REPO argument; default
  `resync_all` path; `--wipe` path).
- `agent-system/extensions/sapience/{manifest.json,settings-fragment.json}`,
  `agent-system/extensions/core/rules/sapience-write-path.md` (the caveat paragraph ACCEPTANCE
  asks to be rewritten).
- `specs/527_hook_registration_set_lint_assertion/plans/01_hook-registration-set-lint.md` and its
  summary (Check E is detection-only, scoped to `hooks`, D6, Non-Goals).
- `specs/archive/369_orphan_sweep_for_removed_merge_target_entries/{plans,records}/*` (the hook
  orphan sweep's own `env`/`permissions`-byte-identical invariant, independently confirming
  `permissions` was deliberately left untouched).
