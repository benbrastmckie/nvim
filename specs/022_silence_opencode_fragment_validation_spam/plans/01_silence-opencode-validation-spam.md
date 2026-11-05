# Implementation Plan: Task #22

- **Task**: 22 - Silence opencode-agents.json fragment validation spam (absorbed: picker Reload
  All/Regenerate honesty fix; absorbed: Global Update repo-registration feature)
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: None blocking. One concurrent sibling (task 459) is scheduled this same
  `/orchestrate` cycle with `file_scope` limited to `specs/459_cross_task_traceability_and_changelog_verdict/`
  — no overlap with any path this plan touches.
- **Research Inputs**: specs/022_silence_opencode_fragment_validation_spam/reports/01_silence-opencode-validation-spam.md
- **Artifacts**: plans/01_silence-opencode-validation-spam.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task bundles three independent scopes that share only a task directory: (1) silencing the
per-extension `opencode-agents.json` validation spam emitted on every `<leader>al` reload, plus
the two companion items the frozen-`.opencode/` policy decision added (one fake-tool line, and
writing the policy down); (2) making the extension picker's `[Reload All]` and `[Regenerate]`
entries honest and self-documenting; (3) building the greenfield `Global Update` repo-registration
feature. Each scope touches a disjoint file set, so the phases below are mostly parallel and each
closes against its own acceptance criteria. Definition of done: a `<leader>al` reload from a
project carrying an `opencode.json.managed` marker emits no validation-failure spam; no
`.opencode/` file, fragment, or validator function is deleted; the frozen policy is written down;
all three bulk-operation picker entries render accurate one-liners and real Command Details
previews; and the `Global Update` entry reloads each registered repo's own loaded-extension set.

### Research Integration

The report's three-scope split and its phase-per-scope recommendation are adopted directly. Two
of its findings materially shape this plan:

- **The frozen-policy decision (2026-09-01) is the binding scope** for the opencode half: silence
  the spam, fix the one fake-tool line, record the policy. The older three-defect-class framing is
  historical evidence, not a checklist.
- **The lean wrong-path bug is deliberately left alone.** The report found its prescribed fix has
  no live target: `.opencode/agent/subagents/` holds 9 generic agent files and no
  language-specific ones, so the "correct files already exist" premise is stale. Under the frozen
  policy no path corrections are owed. Recorded as a Non-Goal.

One gap the report flagged for the planner has been closed at plan-authoring time: the report
asked whether gating belongs inside `generate_opencode_json` or needs a reload-level wrapper. It
needs the wrapper. `manager.resync_all`
(`lua/neotex/plugins/ai/shared/extensions/init.lua`) loops `manager.load(..., {force = true})`
once per loaded extension, and `manager.load` calls `merge_mod.generate_opencode_json` once per
invocation (`init.lua:643`; the unload path mirrors it at `init.lua:824`). A single summary
*per invocation* is therefore still one notification per extension — i.e. still spam. This is why
Decision 1 below puts the aggregation at the `resync_all` level rather than inside
`generate_opencode_json`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap path was provided in this dispatch; no ROADMAP.md consultation was performed.

## Goals & Non-Goals

**Goals**:
- A `<leader>al` reload against an `opencode.json.managed` project emits zero per-extension
  validation WARN notifications, while the missing-reference detail remains retrievable rather
  than destroyed.
- `.opencode/extensions/web/agents/web-implementation-agent.md` no longer teaches
  `browser_verify_text_visible` as a usable tool.
- The frozen-`.opencode/` policy (unmaintained, drift-expected, preserved for future refactoring,
  nothing deleted) is written where the next reader will find it.
- `[Reload All]`'s one-liner stops claiming it wipes; both it and `[Regenerate]` render real
  Command Details content; `"Unknown entry type"` is unreachable for any entry the picker ships.
- The redundancy ruling and the `"Step Through"` disposition are both recorded with reasoning.
- A `Global Update` picker entry reloads every registered repo's own loaded-extension set and
  reports failures in a message, success as a count.

**Non-Goals**:
- Deleting any `opencode-agents.json` fragment, the `validate_opencode_fragment` function, the
  managed-marker gating, or any file under `.opencode/`. This is the task's binding constraint.
- Correcting the lean fragment's `{file:.claude/agents/lean-*-agent.md}` references, or any other
  per-repo-deploy `{file:}` path. Out of binding scope under the frozen policy, and the
  previously-prescribed swap target does not exist.
- Deploying or regenerating `.opencode/` from any source store. `.opencode/` has no entry in
  `.claude-extensions.json` and is hand-maintained; the source-store/deploy-boundary rule does
  not apply to it.
- Cross-repo behaviour for `[Reload All]` or `[Regenerate]`. Both remain single-repo, scoped to
  `vim.fn.getcwd()`. Cross-repo reload is `Global Update`'s job alone (Phase 5).

## Decisions

Four calls the task text explicitly required ("DECIDE, do not assume") are made here rather than
deferred to implementation.

**Decision 1 — spam gating: silence at the emitter, aggregate at the bulk-reload caller.**
`generate_opencode_json` stops notifying entirely and instead *returns* its per-extension skip
report; `manager.load` passes that report through as an additional return value; `resync_all`
accumulates reports across the whole bulk reload and emits at most **one** INFO summary at the
end. Chosen over the report's option (a) (one summary per `generate_opencode_json` invocation)
because — per the Research Integration note above — that still yields one notification per
extension. Chosen over option (b) (plain suppression) because plain suppression would make a
genuine future regression invisible, the risk the report itself flagged. This keeps the mechanism
intact (nothing deleted), satisfies "prefer gating over removing", and keeps the detail honest and
reachable.

**Decision 2 — previewer branch: one shared `entry_type == "special"` branch reading per-entry
fields, not per-flag branches.** Chosen because Phase 5 adds a third special entry
(`Global Update`) that then needs no previewer change at all, and because keeping each entry's
one-liner and its preview detail adjacent in `entries.lua` is what the acceptance criterion
"entries.lua one-liner and the previewer text for a given entry agree" actually asks for. The
existing dispatch chain already tests `is_help` before any `entry_type` branch, so
`[Keyboard Shortcuts]` (also `entry_type = "special"`) keeps its own `preview_help` rendering
unchanged.

**Decision 3 — redundancy ruling: keep both entries, with destructiveness stated first.**
Collapsing `[Regenerate]` into the `[Reload All]` submenu was weighed and rejected: it buries a
recovery operation two keypresses deep, and a third bulk entry (`Global Update`) is landing in
this same task, so a flat set of three self-describing entries is more discoverable than one entry
fronting a four-item submenu. Renaming alone was rejected as insufficient — the defect is a false
description, not an ambiguous name. The fix is corrected one-liners whose first words are the
destructive/non-destructive distinction.

**Decision 4 — `"Step Through"`: remove it.** It is a silent no-op that only reopens the picker.
Implementing a real stepwise resync is unscoped new feature work, and the submenu already offers
both real bulk operations. Removal is the honest minimal change; a future task may reintroduce it
as a working stepwise resync.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Silencing the WARN hides a genuine *new* broken reference (not a frozen-tree gap) | M | M | Decision 1 keeps the detail: the report is returned, aggregated, and surfaced as one INFO summary per bulk reload, plus an opt-in verbose flag that restores full per-extension WARN output |
| Adding a return value to `manager.load` breaks a caller | M | L | Extra Lua return values are ignored by `local ok, err = ...` call sites; Phase 1 enumerates and headless-loads every direct dependent rather than assuming |
| `Global Update` (Phase 5) is greenfield with no identified hook point for recording repo registration | M | M | Phase 4 budgets explicit investigation as its first step and lands the registry independently of any picker change, so Phase 5 consumes a known-shape API |
| `Global Update` reloads extensions in *other* repos — a destructive-adjacent, wide-blast operation | H | L | Phase 5 reloads via the existing non-destructive `resync_all` only (never `wipe`), reports per-repo failures, and prunes/skips unreachable registered repos rather than erroring out |
| Three absorbed scopes in one task directory risk a commit mixing unrelated file sets | L | M | Each phase below has a disjoint `Files to modify` set; commits stay per-phase and explicitly file-listed per `git-staging-scope.md` |
| A concurrent sibling edits a shared file mid-phase | L | L | Sibling 459's declared scope is `specs/459_*/` only; still, re-read each file immediately before editing per the dispatch's Territory block |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4 | -- |
| 2 | 5 | 3, 4 |
| 3 | 6 | 1, 2, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Silence the opencode fragment-validation spam [COMPLETED]

**Goal**: A bulk `<leader>al` reload emits at most one aggregate INFO notification about skipped
agent keys instead of one WARN per extension, with the per-extension detail preserved in return
values and restorable via an opt-in verbose flag. Nothing is deleted.

**Tasks**:
- [x] Re-read `lua/neotex/plugins/ai/shared/extensions/merge.lua` around
      `M.validate_opencode_fragment` and `M.generate_opencode_json` before editing. *(completed)*
- [x] Give `M.generate_opencode_json` an optional third `opts` parameter
      (`{ notify_skips = boolean }`, default `false`). Replace the in-loop
      `vim.schedule(vim.notify(..., WARN))` skip emission with accumulation into a local skip
      report table keyed by extension name; emit the per-extension WARN only when
      `opts.notify_skips` is true. *(completed)*
- [x] Return the skip report as a third return value from `M.generate_opencode_json`, documented
      in its LuaDoc block (`@param opts`, `@return table skips`). Leave
      `M.validate_opencode_fragment` itself untouched — it already collects every missing
      reference deterministically. *(completed)*
- [x] Add a comment at the emission site recording *why* the default is silent: missing `{file:}`
      deploy targets are an expected state under the frozen `.opencode/` policy, so they are not
      an error to shout about on every reload. *(completed)*
- [x] In `lua/neotex/plugins/ai/shared/extensions/init.lua`, have `manager.load` (the
      `generate_opencode_json` call near `init.lua:643`) capture the skip report and pass it
      through as an additional return value; mirror the capture on the unload path
      (near `init.lua:824`) without changing `manager.unload`'s contract if it has no consumer.
      *(completed)*
- [x] In `manager.resync_all`, accumulate each `manager.load` call's skip report across the whole
      resync loop and, after the loop, emit at most one INFO notification summarising the
      aggregate (extension count and skipped-key count, pointing at the verbose flag for detail).
      Emit nothing when the aggregate is empty. *(completed)*
- [x] Thread the verbose opt-in so an operator can still get the full per-extension WARN output on
      demand (a `notify_skips` option on `resync_all`/`load` that defaults false and is forwarded
      to `generate_opencode_json`). *(completed)*
- [x] Confirm no fragment, no validator function, and no `.opencode/` file was deleted by this
      phase (`git diff --stat` shows only the two Lua files). *(completed: verified via
      `git diff --stat` and `git diff --diff-filter=D`)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: `merge.lua`'s `generate_opencode_json` has exactly three non-comment
callers outside its own module — `lua/neotex/plugins/ai/opencode/core/init.lua:130`,
`lua/neotex/plugins/ai/opencode.lua:70`, and
`lua/neotex/plugins/ai/shared/extensions/init.lua` (two sites, `:643` load / `:824` unload) — and
`manager.load`'s existing callers all destructure at most two return values. Both figures were
re-derived by grep at plan-authoring time (2026-11-05), not carried from the research report.
Confirm at implementation time with `grep -rn "generate_opencode_json" lua/` and
`grep -rn "exts\.load\|manager\.load" lua/` before changing either signature, and widen the
dependent set if the grep disagrees.

**Tier Justification**: `generate_opencode_json` gains a parameter and a return value, so the
covering check is the `interface` row's module-plus-direct-dependents build — headless-require
each of `neotex.plugins.ai.shared.extensions.merge`,
`neotex.plugins.ai.shared.extensions.init`, `neotex.plugins.ai.opencode.core`, and
`neotex.plugins.ai.opencode`; no shell suite covers `lua/**` (`suite_selection_select` returns
`__FULL_SWEEP__` for these paths), so none is claimed.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - silence the per-extension skip WARN by
  default; accumulate and return a skip report; add `opts.notify_skips`
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - pass the skip report through
  `manager.load`; aggregate it in `manager.resync_all` into one INFO summary; forward
  `notify_skips`
- `__WHOLE_TREE__` - verification triggers a live `<leader>al` bulk reload (whole-tree
  regeneration of the deployed tree)

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.merge')" -c "q"` and the
  same for `...extensions.init`, `neotex.plugins.ai.opencode.core`, and
  `neotex.plugins.ai.opencode` — each loads with no error.
- From a project carrying an `opencode.json.managed` marker, trigger a `<leader>al` reload and
  confirm: zero `opencode-agents.json validation failed` / `skipped agent key(s)` WARN messages,
  and at most one INFO summary line in `:messages`.
- Re-run the same reload with the verbose opt-in set and confirm the full per-extension detail
  returns — proving the detail was gated, not destroyed.
- `git diff --name-only` lists only the two Lua files above.

---

### Phase 2: Fix the fake-tool line and record the frozen `.opencode/` policy [COMPLETED]

**Goal**: `.opencode/` no longer teaches a nonexistent tool, and its frozen/unmaintained status is
written down where the next reader will look.

**Tasks**:
- [x] Re-read `.opencode/extensions/web/agents/web-implementation-agent.md` around line 57 before
      editing. *(completed)*
- [x] Replace the `` `browser_verify_text_visible` -- Assert text is visible on page `` bullet
      with the retraction the source store already carries
      (`agent-system/extensions/web/agents/web-implementation-agent.md` and
      `agent-system/extensions/web/context/project/web/tools/playwright-mcp-guide.md` both state
      there is no such tool and map it to the real ones). Do not delete the surrounding tool list;
      correct the one line so it names a real tool or explicitly retracts the fake one.
      *(completed)*
- [x] Add a frozen-policy section near the top of `.opencode/README.md` stating: this tree is
      frozen — not maintained, not generated from any source store, not deleted; drift
      (particularly stale `{file:}` deploy-path references in `opencode-agents.json` fragments) is
      expected and tolerated; it is preserved intact for possible future refactoring; nothing in
      it may be deleted. *(completed)*
- [x] Cross-reference the policy from the source store's own docs tree so it is discoverable
      without opening `.opencode/` first (a one-line pointer where sibling systems are indexed).
      *(deviation: altered — the plan's target file `agent-system/docs/docs-README.md` does not
      exist; used `agent-system/extensions/core/docs/docs-README.md` instead, the real docs index
      deployed as `.claude/docs/docs-README.md`, which already names the OpenCode picker keymap
      in its Extensions section)*
- [x] Verify no task numbers appear in any text added outside `specs/**` — cite durable anchors
      (file paths, section headings) instead. *(completed: verified via grep and
      `verify-deploy.sh --only-gate 4`)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: every hunk is prose inside markdown files with no compile or elaboration
surface, and `suite_selection_select` returns `__FULL_SWEEP__` for these paths (no suite covers
them), so the covering checks are the `prose` row's diff read-through plus
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.config/nvim`
for the no-task-references lint on the newly added policy text — gate 3 (doc-lint) is not named
because it SKIPs outside the source store.

**Files to modify**:
- `.opencode/extensions/web/agents/web-implementation-agent.md` - replace the single
  `browser_verify_text_visible` bullet with the source store's retraction
- `.opencode/README.md` - add the frozen-policy section
- `agent-system/docs/docs-README.md` - one-line pointer to the frozen-policy section (adjust to
  whichever file actually indexes sibling systems; create no new index)

**Verification**:
- `grep -rn "browser_verify_text_visible" .opencode/` returns either no hits or only an explicit
  retraction — never a usable-tool listing.
- `.opencode/README.md` contains the frozen-policy section, and it states all four properties
  (unmaintained, ungenerated, drift-expected, nothing deleted).
- Diff read-through confirms every changed hunk is prose; no code, no deletions beyond the one
  corrected bullet.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.config/nvim`
  passes (no task-number references in the new text).
- `git diff --stat` shows no file under `.opencode/` deleted.

---

### Phase 3: Make `[Reload All]` and `[Regenerate]` honest and self-documenting [COMPLETED]

**Goal**: Both entries carry accurate one-liners whose first words state destructiveness, both
render real Command Details content via one shared special-entry preview branch, and
`"Unknown entry type"` is unreachable for any shipped entry. The redundancy ruling and the
`"Step Through"` disposition are recorded in code.

**Tasks**:
- [x] Re-read `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` (special-entry
      block) and `.../display/previewer.lua` (dispatch chain and `preview_help`) before editing.
      *(completed)*
- [x] Replace `[Reload All]`'s one-liner `"Wipe and reload all loaded extensions"` with text whose
      first words state it is non-destructive and that it force-resyncs loaded extensions in
      dependency order. Leave `[Regenerate]`'s accurate one-liner's meaning intact while making
      its destructiveness the first thing it says, so the two lines are distinguishable at a
      glance. *(completed)*
- [x] Add a structured per-entry preview payload to both special entries in `entries.lua` (a
      `description` string plus a `detail` line list covering: what it does, what it touches,
      whether it is destructive, whether it prompts). Lift the already-correct wording from
      `previewer.lua`'s `preview_help` block rather than drafting new text, so the three
      renderings cannot disagree. *(completed)*
- [x] Add a comment at the entry definitions recording that the one-liner, the `detail` payload,
      and the implementation must be kept in sync, naming the implementation functions
      (`manager.resync_all`, `manager.wipe`) each describes. *(completed)*
- [x] Add one `elseif entry.value.entry_type == "special"` branch to `previewer.lua`'s
      `define_preview` chain, placed after the existing `is_help` test so
      `[Keyboard Shortcuts]` keeps `preview_help`, that renders the per-entry `description` and
      `detail` payload (per Decision 2). *(completed)*
- [x] Change the terminal `else` from the bare `"Unknown entry type"` line to a message naming the
      offending entry's `entry_type` and `name`, so the next gap is diagnosable rather than
      anonymous. *(completed)*
- [x] Record Decision 3 (keep both entries; destructiveness stated first) as a comment at the
      special-entry definitions, with its reasoning in one or two lines. *(completed)*
- [x] Remove the dead `"Step Through"` choice from the `[Reload All]` submenu in
      `lua/neotex/plugins/ai/claude/commands/picker/init.lua` and the no-op branch that handles
      it, leaving `{"Reload All", "Unload All", "Cancel"}`; record Decision 4's reasoning in a
      comment at the submenu. *(completed)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: the `define_preview` dispatch chain currently has no branch for
`is_reload_all`, `is_regenerate`, or `entry_type == "special"`, so both entries reach the terminal
`else`; and the `[Reload All]` submenu currently offers exactly
`{"Reload All", "Unload All", "Step Through", "Cancel"}` with `"Step Through"` only reopening the
picker. Both re-derived by reading `previewer.lua`'s chain and `picker/init.lua`'s submenu at
plan-authoring time (2026-11-05), not carried from the research report. Confirm at implementation
time by re-reading both regions, and widen the task list if a branch or choice has since been
added.

**Tier Justification**: the new `description`/`detail` payload is produced in `entries.lua` and
consumed in `previewer.lua`, a two-file producer/consumer contract, so the covering check is the
`interface` row's build of the changed modules plus their enumerated dependents — headless-require
`...picker.display.entries`, `...picker.display.previewer`, and `...picker` (the submenu edit) —
plus a live picker open; no shell suite covers `lua/**` (`__FULL_SWEEP__`), so none is claimed.

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - corrected one-liners for
  both special entries; structured `description`/`detail` preview payload; sync-obligation and
  redundancy-ruling comments
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - add the shared
  `entry_type == "special"` preview branch; make the terminal `else` name the offending entry
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - remove the `"Step Through"` submenu
  choice and its no-op branch; record Decision 4's reasoning

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.entries')" -c "q"`,
  the same for `...display.previewer`, and for `...commands.picker` — each loads with no error.
- Open `<leader>al` live and select `[Reload All]`: the Command Details pane shows real content
  (what it does, what it touches, non-destructive, no prompt) and not `"Unknown entry type"`.
- Open `<leader>al` live and select `[Regenerate]`: same, stating destructive and
  confirmation-required.
- The two visible one-liners no longer both begin "Wipe and ..." and are distinguishable at a
  glance.
- Open the `[Reload All]` submenu and confirm `"Step Through"` is gone and the remaining three
  choices all act.
- `grep -n "Unknown entry type" lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua`
  shows the message now names the entry, and no shipped entry reaches it.

---

### Phase 4: Repo registry for extension loads [COMPLETED]

**Goal**: A durable registry records which repositories `<leader>al` has loaded extensions into,
and which extensions each has loaded, with a small documented read/write API that Phase 5
consumes. No picker UI change in this phase.

**Tasks**:
- [x] Investigate before designing: locate every call site that loads an extension into a project
      directory (`grep -rn "exts\.load\|manager\.load" lua/`, plus the picker's own load path at
      `lua/neotex/plugins/ai/claude/commands/picker/init.lua`), and read
      `lua/neotex/plugins/ai/shared/extensions/state.lua` plus `config.lua` to see how per-project
      state (`root_state_file`) and the `global_dir` convention already work. Record the chosen
      hook point and registry location in a comment before writing code. *(completed: chosen
      hook point is `manager.load`'s success path in init.lua, recorded in that site's own
      comment; registry location/schema recorded in repo_registry.lua's header comment)*
- [x] Decide and document the registry's storage location — a single global JSON file (the
      `global_dir` / `vim.fn.stdpath("data")` convention, not a per-project file, since the
      registry's whole purpose is to span projects) — and its schema (per-repo path, the
      extensions loaded there, a last-seen timestamp). *(completed:
      `stdpath("data") .. "/neotex-ai/extension-repo-registry.json"`, reusing the existing
      `ai-tool-picker.lua` data_dir convention)*
- [x] Add a small registry module under `lua/neotex/plugins/ai/shared/extensions/` exposing read,
      upsert (register-or-update one repo), list, and prune-unreachable operations. Use `pcall`
      around all file I/O and return structured errors rather than raising. *(completed:
      repo_registry.lua)*
- [x] Hook the upsert into the extension-load path so loading an extension into any project
      directory registers that directory and its loaded-extension set. Make the hook non-fatal:
      a registry write failure logs and continues, never failing the load. *(completed)*
- [x] Do not register the host repo itself in a way that makes `Global Update` recurse into the
      current repo twice; decide and document whether the current repo is included or excluded.
      *(completed: excluded, via `vim.fn.stdpath("config")` identity check)*
- [x] Add LuaDoc for every public function per the repo's Lua standards (2-space indent,
      `snake_case`, `~100` char lines). *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: no repo-registration mechanism exists in any form — the research pass found
zero matches for `"Global Update"`, `"repo registration"`, `"register.*repo"`, and
`"registered_repos"` across `lua/neotex/plugins/ai/`. This figure is carried from
`specs/022_silence_opencode_fragment_validation_spam/reports/01_silence-opencode-validation-spam.md`
and was NOT re-derived at plan-authoring time. Confirm at implementation time by re-running that
grep set before writing any new module, so an interim implementation is extended rather than
duplicated.

**Tier Justification**: this phase adds a new module and a call into the existing load path, so
the covering check is the `interface` row's build of the new module plus its enumerated direct
dependents — headless-require the new registry module and `...shared.extensions.init`, plus a live
load of one extension to confirm the registry row appears; no shell suite covers `lua/**`
(`__FULL_SWEEP__`), so none is claimed.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/repo_registry.lua` - new module: read, upsert, list,
  prune-unreachable over the global registry JSON
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - non-fatal registry upsert on the
  extension-load path
- `lua/neotex/plugins/ai/shared/extensions/config.lua` - registry file location constant, if the
  investigation step concludes it belongs with the other path config

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.repo_registry')" -c "q"`
  and the same for `...extensions.init` — each loads with no error.
- Load one extension into a scratch project directory and confirm the registry file gains exactly
  one row naming that directory and that extension; load a second extension there and confirm the
  row updates rather than duplicating.
- Corrupt or remove the registry file and confirm an extension load still succeeds (non-fatal
  write path), with a logged warning.
- `prune-unreachable` removes a row whose directory no longer exists and leaves reachable rows
  untouched.

---

### Phase 5: `Global Update` picker entry [COMPLETED]

**Goal**: A `Global Update` picker entry reloads every registered repo's own loaded-extension set
via the non-destructive resync path, reports any failures in a message and otherwise success as a
total count, and reads as one coherent set with the two entries Phase 3 corrected.

**Tasks**:
- [x] Re-read Phase 3's corrected `entries.lua` one-liners and `detail` payloads, and Phase 4's
      registry API, before editing. *(completed)*
- [x] Add a `Global Update` special entry to `entries.lua` alongside `[Reload All]` and
      `[Regenerate]`, with a one-liner whose first words state it is cross-repo and
      non-destructive, and a `description`/`detail` payload in the same shape Phase 3 introduced
      (so the preview branch needs no change). *(completed: no previewer.lua change was needed)*
- [x] Reconcile all three one-liners as a set: each must make its scope (current repo vs. all
      registered repos) and its destructiveness unambiguous, and no two may read as synonyms.
      Record that coherence obligation in the same sync comment Phase 3 added. *(completed)*
- [x] Implement the handler in `lua/neotex/plugins/ai/claude/commands/picker/init.lua`: list
      registered repos, and for each call `exts.resync_all({ project_dir = repo })` — the existing
      non-destructive path, never `exts.wipe`. *(completed)*
- [x] Skip (and report) a registered repo that is unreachable or no longer holds a loaded
      extension set, rather than aborting the whole operation; offer to prune it via Phase 4's
      prune operation. *(completed: unreachable repos are skipped, named in the report, and
      pruned from the registry automatically rather than via a separate interactive offer)*
- [x] Report the outcome in one message: a success count of total extensions resynced across all
      repos, plus an explicit per-repo failure list when any repo failed. *(completed)*
- [x] Add a correction to the operator mental model in the `[Regenerate]` detail text: it is
      single-repo and scoped to `vim.fn.getcwd()`, and cross-repo reload is `Global Update`'s job.
      *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Verification Tier**: interface

**Tier Justification**: the new entry's payload is produced in `entries.lua` and consumed by the
shared special-entry preview branch Phase 3 added in `previewer.lua`, and the handler calls
Phase 4's registry API, so the covering check is the `interface` row's build of the changed modules
plus those enumerated dependents — headless-require `...picker.display.entries`,
`...picker.display.previewer`, `...commands.picker`, and `...extensions.repo_registry` — plus a
live picker open and a two-repo `Global Update` run; no shell suite covers `lua/**`
(`__FULL_SWEEP__`), so none is claimed.

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - add the `Global Update`
  special entry with its one-liner and `detail` payload; reconcile all three bulk-entry one-liners
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - `Global Update` handler: iterate
  registered repos, `resync_all` each, aggregate and report
- `__WHOLE_TREE__` - the handler regenerates the deployed tree in every registered repo

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.entries')" -c "q"`,
  and the same for `...display.previewer`, `...commands.picker`, and
  `...shared.extensions.repo_registry` — each loads with no error.
- Open `<leader>al` live, select `Global Update`, and confirm its Command Details pane renders real
  content through Phase 3's shared branch with no previewer change.
- With two registered repos, run `Global Update` and confirm each repo's own loaded-extension set
  was resynced (not the host repo's set applied to both), and that the reported success count
  equals the sum across repos.
- Register an unreachable directory and confirm `Global Update` reports it and completes the
  reachable repos rather than aborting.
- All three bulk-entry one-liners read side by side in the picker as a coherent, non-synonymous
  set.

---

### Phase 6: Full acceptance sweep and gate run [NOT STARTED]

**Goal**: Every acceptance criterion from all three scopes is verified live and together, and the
repository's complete gate set passes.

**Tasks**:
- [ ] Reproduce the original symptom end to end: from a project carrying an
      `opencode.json.managed` marker, trigger a `<leader>al` reload and confirm zero
      validation-failure notifications, with at most one aggregate INFO summary.
- [ ] Confirm nothing was deleted: every `opencode-agents.json` fragment, the
      `validate_opencode_fragment` function, the managed-marker gating, and every `.opencode/`
      file are all still present (`git diff --diff-filter=D --name-only` lists nothing under
      `.opencode/` or `agent-system/extensions/*/opencode-agents.json`).
- [ ] Confirm `browser_verify_text_visible` no longer appears anywhere in `.opencode/` as usable
      guidance, and that the frozen policy is written down and cross-referenced.
- [ ] Open `<leader>al` and select each of the three bulk entries in turn, confirming accurate
      one-liners, real Command Details content, and that `"Unknown entry type"` is unreachable for
      every shipped entry.
- [ ] Confirm the `"Step Through"` choice is gone and that both recorded rulings (redundancy,
      `"Step Through"`) are present in the source with their reasoning.
- [ ] Run the complete gate set and record the result.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 5

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - the acceptance sweep triggers a live `<leader>al` bulk reload and the
  `Global Update` cross-repo resync
- (no source file changes planned in this phase; it is verification only — any defect found is
  fixed in the owning phase's files and that phase re-verified)

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh` — the complete gate set the
  repository aggregates, run in full (no `--skip-slow`, no `--only-gate` narrowing, since a
  narrowed or slow-skipped pass is not evidence the full set holds).
- Every acceptance bullet from the task's three scopes is confirmed live, not from the diff alone:
  no validation spam on reload; the fake tool name gone as usable guidance; the frozen policy
  written down; nothing under `.opencode/` deleted; all three picker entries honest with real
  previews; `"Unknown entry type"` unreachable; both rulings recorded; `"Step Through"` resolved.

---

## Testing & Validation

- [ ] Headless module loads pass for every touched Lua module (`merge`, `extensions.init`,
      `repo_registry`, `config`, `picker`, `picker.display.entries`, `picker.display.previewer`,
      `opencode.core`, `opencode`).
- [ ] A `<leader>al` reload from an `opencode.json.managed` project emits zero
      validation-failure notifications and at most one aggregate INFO summary.
- [ ] The verbose opt-in restores full per-extension skip detail, proving the detail was gated and
      not destroyed.
- [ ] No file under `.opencode/`, no `opencode-agents.json` fragment, and no validator function is
      deleted (`git diff --diff-filter=D --name-only`).
- [ ] `grep -rn "browser_verify_text_visible" .opencode/` yields no usable-tool listing.
- [ ] `.opencode/README.md` states all four frozen-policy properties, and a source-store docs
      pointer reaches it.
- [ ] All three bulk picker entries render accurate one-liners and real Command Details content;
      `"Unknown entry type"` is unreachable for shipped entries and names the entry if ever hit.
- [ ] `"Step Through"` is removed and both recorded rulings are present with reasoning.
- [ ] `Global Update` resyncs each registered repo's own loaded-extension set, reports failures,
      and survives an unreachable registered repo.
- [ ] `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh` passes in full.
- [ ] No task-number references appear in any text added outside `specs/**`
      (`--only-gate 4` run in Phase 2, full gate 4 run in Phase 6).

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - silent-by-default skip reporting with an
  `opts.notify_skips` escape hatch and a returned skip report
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - skip-report pass-through on `manager.load`,
  one aggregate INFO summary in `manager.resync_all`, non-fatal registry upsert
- `lua/neotex/plugins/ai/shared/extensions/repo_registry.lua` - new cross-repo registry module
- `lua/neotex/plugins/ai/shared/extensions/config.lua` - registry location constant (if concluded)
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - three honest bulk-entry
  one-liners plus structured preview payloads
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - shared special-entry
  preview branch; diagnosable terminal fallback
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - `"Step Through"` removed;
  `Global Update` handler added
- `.opencode/extensions/web/agents/web-implementation-agent.md` - fake-tool line corrected
- `.opencode/README.md` - frozen-policy section
- `agent-system/docs/docs-README.md` - pointer to the frozen policy
- `specs/022_silence_opencode_fragment_validation_spam/summaries/01_silence-opencode-validation-spam-summary.md` -
  implementation summary (written at completion)

## Rollback/Contingency

Every phase's changes are confined to its own `Files to modify` list and land as one commit per
phase, so reverting a single phase is `git revert` of that phase's commit — no cross-phase
entanglement, since Waves 1 and 2 touch disjoint files except where Phase 5 deliberately extends
Phase 3's `entries.lua` payload shape (revert Phase 5 before Phase 3 if both must go).

If a genuine rollback of uncommitted work becomes necessary, take the snapshot first per
`context/contracts/recovery.md`'s rollback rung — including its out-of-scope override flag for the
deliberate whole-tree case — and never discard uncommitted changes to reach a passing state. For
an ordinary defensive checkpoint before the Phase 4/5 greenfield work, use
`bash .claude/scripts/git-snapshot.sh 22 --no-revert`, which is durable without reverting the
working tree.

Per-scope contingency: Scope 1 (Phases 1-2) is the task's original core and must land; if Scope 3
(Phases 4-5) proves larger than budgeted, closing after Phase 3 leaves a coherent state in which
the spam is silenced, the policy is recorded, and the two existing picker entries are honest —
`Global Update` is then the only outstanding item and is independently re-dispatchable.
