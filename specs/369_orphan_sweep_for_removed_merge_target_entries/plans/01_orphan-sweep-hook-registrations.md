# Implementation Plan: Task #369

- **Task**: 369 - Orphan sweep for removed merge-target entries (hook registrations)
- **Status**: [IMPLEMENTING]
- **Effort**: 10 hours
- **Dependencies**: None blocking. Task 527 (hook-registration SET lint) consumes the identity
  notion this plan settles and should land after it.
- **Research Inputs**: specs/369_orphan_sweep_for_removed_merge_target_entries/reports/01_orphan-sweep-hook-registrations.md
- **Artifacts**: plans/01_orphan-sweep-hook-registrations.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The extension deploy mechanism adds and changes merge-target content but cannot delete it: a hook
registration whose source-store declaration was removed survives indefinitely in every
already-deployed `.claude/settings.json`, because the fragment merge only visits entries the
source still provides, root-files is install-once, and `settings_backup.restore` reintroduces the
stale file as the merge base even under a destructive wipe. This plan closes that gap by
extending the one mechanism this codebase already trusts for exactly this shape of problem —
`merge.lua`'s `remove_orphaned_index_entries` and its `manager.load` call-siting — to hook
registrations, reconciling the two divergent identity notions (`merge.lua`'s `hook_identity()`
and the hook-path lint's `normalize_identity()`) into one definition both consume, and stating the
add/change-but-not-delete invariant where a future editor will meet it. Done means: an ordinary
load/resync removes a registration no loaded extension's fragment or root-files surface provides;
a hand-written or `~/`-anchored hook survives untouched under a dedicated regression test; the
five real stale deploys are measured before and after with `env`/`permissions` byte-identical; and
the pre-existing extension/merge specs stay green.

### Research Integration

The research report is integrated as the plan's factual spine, and every field claim in it was
independently re-confirmed at plan time (see Decisions below):

- **Precedent to extend, not invent**: `M.remove_orphaned_index_entries`
  (`lua/neotex/plugins/ai/shared/extensions/merge.lua`) plus its call site in `manager.load`
  (`init.lua`, immediately before `process_merge_targets`), using the "valid set excluding self,
  re-added by the very next line" pattern that already converges order-independently across a
  `resync_all` loop. Phases 4 and 5 follow that shape rather than designing a new mechanism.
- **The identity split**: `hook_identity()` resolves only a `.claude/hooks/NAME.sh`-shaped
  command to `"<type>:<NAME.sh>"`; `lint-hook-registration-paths.sh`'s `normalize_identity()`
  (its own documented D4/D5 divergence) covers ANY invoked script path, keys on
  `(normalized_path, event, type)`, and exempts `~/`-anchored paths entirely. Phases 2 and 3
  reconcile these into one definition.
- **The `~/` carve-out is a live field case, not a hypothetical**: ModelBuilder, Logos/Website and
  Logos/Theory each carry `bash ~/.config/nvim/scripts/claude-ready-signal.sh`, while the host
  repo and theorem_proving_in_lean4 carry the *CWD-relative* `bash scripts/claude-ready-signal.sh`
  form of the same script. One must be swept, the other must not. This pair is the plan's primary
  regression fixture (Phase 4).
- **A fourth drift shape the dispatch does not name**: cross-EVENT survival (Logos/Theory's
  `validate-no-task-references.sh` live under both `PreToolUse|Write|Edit` and a stale
  `PostToolUse|Write|Edit`, so it fires twice per Write/Edit). The research flagged this as an
  open plan-time decision; it is decided below, not left to fall out of an implementation detail.
- **`find_orphans` does not already solve this**: it is whole-file, deploy-tree-relative and
  detection-only, and `.claude/settings.json` is always "declared" as the install-once root file,
  so it can never surface there.

### Prior Plan Reference

No prior plan. This is the task's first planning round.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch's delegation context and no ROADMAP consultation
was performed; `roadmap_flag` is absent, so no roadmap review/update phases are included.

## Goals & Non-Goals

**Goals**:

- One identity definition for "is this the same hook registration", consumed by both the merge-time
  sweep and the hook-path lint, with a conformance test asserting the two agree on a path outside
  `hooks/`.
- An orphan sweep for hook registrations in `.claude/settings.json`, sited exactly where the
  index-entry sweep is sited, that removes a registration no loaded extension's fragment or
  root-files surface still provides.
- Source-authoritative placement: a hook identity the source declares under one matcher or one
  event does not survive under a different matcher or event of the same hook.
- An absolute carve-out: a command not recognizable as a source-store hook invocation — including
  every `~/`-anchored command — is never matched, moved, deduped or swept.
- Before/after measurement for every affected deploy: registration count, zero per-event
  duplicates, `env` and `permissions` byte-identical.
- The add/change-but-not-delete invariant, the per-merge-target sweep inventory, and the by-hand
  repair for a pre-sweep deploy, stated in the existing source-store/deploy-boundary narrative.

**Non-Goals**:

- Script/test corpus duplication, dead code, slow tests (owned by the standing probe-consumer item).
- Context-corpus reachability and dead/overlapping context files (reachability probe item).
- Neovim repo hygiene, task support-file tracking, missing keymap `desc` fields (separate owners).
- Fixing the *anchor shape* of deployed commands (CWD-relative vs `"$CLAUDE_PROJECT_DIR"`-prefixed).
  That is the hook-path lint's own Check A question and is already tracked; this plan only decides
  identity and orphanhood, and must not silently rewrite anchors as a side effect.
- An MCP-server orphan sweep. `merge_targets.mcp` rides the same `merge_settings` path and has the
  same gap, but adding it is out of scope; the documentation phase records its absence as a known
  uncovered merge target rather than fixing it.
- A new permanent measurement script. Measurement uses a recorded, copy-pasteable `jq` recipe (see
  Phase 1), deliberately, because durable script-corpus growth is a cost owned by the probe item
  above.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A broadened identity widens sweep eligibility to a hand-written or `~/`-anchored hook and silently deletes a user's own registration (the single most dangerous regression in this task) | H | M | Broadening is a strict superset of *recognized script-invocation shapes* only: `~/`-anchored commands and commands containing no `*.sh` invocation return `nil` and fall through to exact `vim.deep_equal`, unchanged. Phase 2 pins both exemptions in the conformance corpus; Phase 4 adds dedicated survival specs using the real field commands |
| An under-computed valid set (an unreadable manifest or fragment for a loaded extension) causes an over-sweep | H | M | Fail-safe: if ANY loaded extension's manifest or declared settings fragment cannot be read, the sweep is skipped entirely for that load and the skip is logged. An incomplete valid set is never swept against (Phase 5) |
| Sweep removes self's entries and the immediately-following `merge_settings` fails, losing registrations | M | L | Read the current extension's fragment BEFORE sweeping; the sweep returns the removed entries so the existing `load_ok == false` rollback path (`remove_installed_files` + `reverse_merge_targets`, inside the same `pcall` block the index sweep already runs in) can restore them (Phase 5) |
| Transient removal mid-deploy in an unmanaged repo (no `.claude-extensions.json`): a repo whose extension state is empty sweeps against a near-empty valid set at the first extension's load | M | M | Skip the sweep when the loaded-extension list is empty, and rely on the deploy loading every extension in one run for convergence; Phase 6 measures the FINAL state of each repo and verifies a re-run is idempotent |
| Cross-matcher/cross-event removal deletes a deliberate second registration a user added under another matcher | M | L | Only identity-eligible commands are candidates; a user's own hand-written command is never identity-eligible. A user-added duplicate of a *source-store* hook under a different matcher is exactly what the dispatch asks to remove, and the documentation phase states that explicitly |
| Empty matcher blocks or an empty event array left behind, changing file shape in a way downstream readers mishandle | L | M | Prune emptied matcher blocks and emptied event arrays in the same write; assert the pruned shape in Phase 4 specs |
| Pre-existing extension/merge specs go red and the breakage is attributed elsewhere | M | M | Phase 8 runs `merge_spec.lua` and `manifest_spec.lua` plus the full gate set and treats any newly red pre-existing test as caused by this task (acceptance criterion 5) |
| The lint gains a hard dependency on an `nvim` subprocess and silently degrades to its own notion if the bridge fails | M | L | The bridge is invoked ONCE per lint run; a bridge failure makes the lint exit non-zero with a named error, never fall back to a second identity notion (Phase 3) |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 2 |
| 3 | 5 | 4 |
| 4 | 6, 7 | 1, 3, 5 |
| 5 | 8 | 6, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Baseline measurement and real-deploy fixture capture [COMPLETED]

**Goal**: Establish the before-state for every deployed repo and capture real stale
`settings.json` copies as read-only fixtures, so later phases verify against field files rather
than a fixture reconstructed from memory.

**Tasks**:

- [x] Enumerate deployed repos from the FILESYSTEM, not the extension repo registry: *(completed: 27 repos found; see records/01_baseline-measurements.md)*
      `find ~/Projects ~/Philosophy ~/.config/nvim ~/.dotfiles ~/Documents ~/Training -maxdepth 5 -type d -name .claude -not -path '*/.local/*' -not -path '/tmp/*'`.
      Record which of them carry a `.claude-extensions.json` (managed) and which do not.
- [x] Record, per repo, the three measurement quantities with this recipe (the measurement
      contract for acceptance criterion 4; no new permanent script is added):
      - registration count: `jq '[(.hooks // {}) | to_entries[] | .value[] | (.hooks // [])[]] | length' .claude/settings.json`
      - per-event duplicate count: `jq -r '(.hooks // {}) | to_entries[] | .key as $e | [.value[] | .matcher as $m | (.hooks//[])[] | "\($e)|\(.type)|\(.command)"] | group_by(.) | map(select(length > 1)) | length' .claude/settings.json`
      - `env`/`permissions` fingerprint: `jq -S '{env, permissions}' .claude/settings.json | sha256sum`
- [x] Copy each stale deploy's `.claude/settings.json` verbatim into
      `specs/369_orphan_sweep_for_removed_merge_target_entries/records/fixtures/` under a
      repo-named filename. These are read-only field inputs for Phases 4 and 6.
- [x] Write `records/01_baseline-measurements.md`: one row per repo (path, managed yes/no, *(completed: widened scope note added -- 14-clean-repo premise did not hold)*
      registration count, per-event duplicate count, `env`/`permissions` fingerprint, orphan
      commands observed), plus an explicit no-change control-set list.
- [x] Record in the same file that the extension repo registry
      (`~/.local/share/nvim/neotex-ai/extension-repo-registry.json`) was rejected as the
      enumeration source, and why.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this phase's paths
because every one lies under `specs/**`, which no suite maps; per plan-format.md's
`__FULL_SWEEP__` sub-case (a) the honest covering check is the `prose` row's diff read-through
over the written records, since `specs/**` is the task-reference lint's own exempt tree and
doc-lint has no bearing on it.

**Scope Hypothesis**: Five repos carry live orphans (host `~/.config/nvim`, ModelBuilder,
Logos/Website, Logos/Theory, theorem_proving_in_lean4) with registration counts 28, 12, 12, 30
and 13 respectively; the remaining deployed repos are a no-change control set. These counts are
carried from this plan's own authoring-time `jq` census (re-derived at plan time from the five
repos' deployed `.claude/settings.json`, confirming the research report's field table), not from
the report alone — confirm each by re-running the recipe above as the phase's first action, since
any repo may have been reloaded since.

**Files to modify**:

- `specs/369_orphan_sweep_for_removed_merge_target_entries/records/01_baseline-measurements.md` - new; the before-state table and enumeration rationale
- `specs/369_orphan_sweep_for_removed_merge_target_entries/records/fixtures/` - new; verbatim copies of each stale deploy's settings.json

**Verification**:

- `records/01_baseline-measurements.md` exists, names every enumerated repo, and gives all three
  quantities for each.
- One fixture file per stale deploy exists and parses as JSON (`jq . <file> >/dev/null`).
- Diff read-through confirms every written hunk is prose or recorded measurement output, with no
  edit to any file outside `specs/**`.

---

### Phase 2: One identity definition, consumed by Lua [NOT STARTED]

**Goal**: Create the single normative hook-registration identity function and its conformance
corpus, and make `merge.lua` consume it in place of its own narrower `hook_identity()`.

**Tasks**:

- [ ] Create `lua/neotex/plugins/ai/shared/extensions/hook_identity.lua`: a pure-Lua module with
      no `vim.*` dependency, exposing `M.identity(command, hook_type)` returning
      `"<type>:<normalized_path>"` or `nil`.
- [ ] Define normalization so it is a strict superset of today's merge behavior and agrees with
      the lint's D5 rule: strip everything up to and including the LAST `.claude/` occurrence
      (so `.claude/hooks/a.sh`, `"$CLAUDE_PROJECT_DIR"/.claude/hooks/a.sh` and
      `/abs/path/.claude/hooks/a.sh` all normalize to `hooks/a.sh`, preserving today's
      stale/fixed collapse), otherwise strip a single leading `/`, and keep the remaining
      directory-qualified path exactly as written (so `scripts/a.sh` is a first-class identity).
- [ ] Implement the two mandatory ineligibility rules, each returning `nil`: a command written
      with a `~/`-anchored script path, and a command containing no `*.sh` invocation at all.
      Find the innermost invoked `*.sh` token so a `bash -c '...'` wrapper is transparent.
- [ ] Create `lua/neotex/plugins/ai/shared/extensions/hook_identity_fixtures.json`: the single
      conformance corpus, rows of `{command, type, expected_identity | null, note}`. Seed it with
      every shape found in the field and in the source store: both `claude-ready-signal.sh` forms
      (CWD-relative `scripts/...` -> eligible; `~/`-anchored -> `null`), both anchors of a
      `hooks/` hook, an absolute-path `.claude/hooks/` command, the `bash -c` wrapped
      `validate-state-sync.sh` registration, a hand-written `/opt/mytools/...` command
      (-> `null` under today's behavior and under the broadened function alike), and an
      `mcpServers`-style `"command": "npx"` value (-> `null`).
- [ ] Replace `merge.lua`'s local `hook_identity` body with a call into the new module, keep its
      existing doc comment's custom-hook carve-out language, and export it as `M.hook_identity`
      so the sweep (Phase 4) and the bridge (Phase 3) share one entry point. `find_hook_match`,
      `normalize_hook_event_array` and `merge_hook_event_array` need no other change — they
      already fall through to `vim.deep_equal` on a `nil` identity, which IS the carve-out.
- [ ] Add `merge_spec.lua` specs: a table-driven conformance test iterating the fixture corpus,
      plus an explicit assertion that the broadened function still collapses the stale/fixed
      anchor pair of the same `hooks/` hook exactly as the existing production-defect specs
      expect.

**Timing**: 1.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this phase's path
set (the new module and fixture corpus are unmapped, so no suite covers them), so the honest
covering check is the `local` row's single-module run — `nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua" -c "qa!"` —
and no suite-list claim is made.

**Scope Hypothesis**: The broadened function is expected to change the resolved identity STRING
for every currently-eligible command (from `type:NAME.sh` to `type:hooks/NAME.sh`) while changing
the eligibility VERDICT for no command that is eligible today; the only new eligibility is for
non-`hooks/` directory-qualified paths. Confirm by running the pre-existing `merge_spec.lua`
suite unchanged before adding new specs and observing it green, and by asserting in the
conformance corpus that each previously-`nil` hand-written command is still `nil`.

**Files to modify**:

- `lua/neotex/plugins/ai/shared/extensions/hook_identity.lua` - new; the single normative identity function
- `lua/neotex/plugins/ai/shared/extensions/hook_identity_fixtures.json` - new; the conformance corpus both implementations are pinned against
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - `hook_identity` delegates to the new module and is exported as `M.hook_identity`
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` - table-driven conformance specs plus the anchor-pair collapse assertion

**Verification**:

- `nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua" -c "qa!"`
  is green, including every pre-existing spec in that file.
- Every fixture row's expected identity is asserted; the corpus contains at least one `null` row
  for a `~/`-anchored command and one for a command with no `*.sh` invocation.
- `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.hook_identity')" -c "qa!"`
  loads the module cleanly.

---

### Phase 3: The lint consumes the same definition [NOT STARTED]

**Goal**: Remove the documented identity divergence by making `lint-hook-registration-paths.sh`
resolve identities through the Phase 2 module instead of its own `normalize_identity()`, and pin
the agreement with a test on a path outside `hooks/`.

**Tasks**:

- [ ] Create `lua/neotex/plugins/ai/shared/extensions/hook_identity_cli.lua`: a thin bridge with
      no logic of its own that reads `<type>\t<command>` lines on stdin and writes one identity
      per line (empty line for `nil`), in input order, by `dofile`-ing the sibling
      `hook_identity.lua` by absolute path. Runnable as
      `nvim --headless --noplugin -u NONE -l <abs path to hook_identity_cli.lua>`.
- [ ] Rewrite the lint's `collect_identities` to build its whole registration inventory first,
      then resolve every command through ONE bridge invocation, composing the Check C/D key as
      `<identity>|<event>` (the module supplies type and normalized path; event stays the lint's
      own dimension).
- [ ] Delete the lint's own `normalize_identity()` and replace the D4 header note with a note
      recording that identity now has exactly one definition, naming the module path. Leave
      `classify_anchor` untouched and state in the header that anchor SHAPE (Check A) and
      registration IDENTITY are separate questions, only the latter being shared.
- [ ] Make a bridge failure fatal: a non-zero exit, a missing bridge, or an output line count
      that does not match the input line count makes the lint print a named error and exit
      non-zero. Never fall back to a second identity notion. Record the invariant that the
      bridge is only ever needed in a repository that has settings surfaces to scan, which is
      the same repository that holds the module.
- [ ] Extend `test-lint-hook-registration-paths.sh` with the acceptance-criterion-3 test: a
      fixture registering a script OUTSIDE `hooks/` (e.g. `scripts/claude-ready-signal.sh`),
      asserting that the lint's resolved identity equals the Phase 2 module's own output for the
      same command, and a case asserting a `~/`-anchored command is identity-ineligible on both
      sides.
- [ ] Extend the same suite with a bridge-failure case asserting the loud non-zero exit.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this phase's path
set because the new bridge module is unmapped, so no suite covers it and no suite-list claim is
made; the honest covering check is the `local` row's single-module lint-plus-suite run named in
this phase's Verification section below.

**Scope Hypothesis**: After this phase's edits the selector's answer changes — the extended suite
will textually reference `hook_identity_cli.lua`, so stratum (b) will begin mapping that path and
a re-run of `suite_selection_select` will return real suite names instead of `__FULL_SWEEP__`.
Re-run the selector at the END of this phase and record the new answer rather than assuming this
phase's justification still describes the post-edit state.

**Files to modify**:

- `lua/neotex/plugins/ai/shared/extensions/hook_identity_cli.lua` - new; logic-free stdin/stdout bridge over the Phase 2 module
- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` - `collect_identities` resolves through the bridge; own `normalize_identity` removed; D4 note rewritten; loud bridge-failure path
- `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` - agreement test on a path outside `hooks/`, `~/`-ineligibility test, bridge-failure test

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` is green,
  including every pre-existing case in it.
- `bash agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh --verbose`
  reports the same verdict it reported before this phase on the unchanged source store (no new
  violations introduced by the identity change alone).
- `grep -c 'normalize_identity' agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh`
  is 0 outside the header note, proving the second definition is gone rather than merely unused.

---

### Phase 4: The sweep function in merge.lua [NOT STARTED]

**Goal**: Add `M.remove_orphaned_hook_registrations`, modeled structurally on
`M.remove_orphaned_index_entries`, with the carve-out and placement semantics decided in this
plan, and unit specs including the two survival regressions.

**Tasks**:

- [ ] Add `M.remove_orphaned_hook_registrations(target_path, valid_set)` to `merge.lua`,
      returning `(success, removed_count, removed_entries)` and mirroring the index sweep's
      shape: no-op-and-return-true on an unreadable or absent target, no write when
      `removed_count == 0`, `M.write_json` otherwise.
- [ ] Implement the single survival predicate: a hook entry survives iff
      `M.hook_identity(entry)` is `nil` (the carve-out — never matched, moved, deduped or swept),
      OR the tuple `(event, matcher, type, normalized_path)` is present in `valid_set`. This one
      predicate covers all four drift shapes at once: undeclared registration, cross-matcher
      migration, cross-EVENT survival, and a dead-script registration whose declaration is gone.
- [ ] Touch nothing outside the `hooks` key. `env`, `permissions`, `mcpServers` and every other
      top-level key are read and re-written unchanged.
- [ ] Prune a matcher block whose `hooks` array became empty, and an event array that became
      empty, in the same write.
- [ ] Add `merge_spec.lua` specs, all against a scratch `settings.json` under `vim.fn.tempname()`:
      - removes an undeclared registration (the host repo's CWD-relative
        `bash scripts/claude-ready-signal.sh` under `SessionStart|startup`), taken from the Phase 1
        fixture rather than retyped;
      - **survival regression, acceptance criterion 2**: a hand-written
        `bash /opt/mytools/my-custom-hook.sh --flag value` command survives a sweep byte-identical,
        even when nothing in `valid_set` resembles it;
      - **survival regression**: the `~/`-anchored `bash ~/.config/nvim/scripts/claude-ready-signal.sh`
        command survives a sweep byte-identical;
      - cross-matcher: `tts-notify.sh` under the widened `permission_prompt|idle_prompt|elicitation_dialog`
        matcher is removed when the source declares it only under `permission_prompt|elicitation_dialog`;
      - cross-event: `validate-no-task-references.sh` under `PostToolUse|Write|Edit` is removed
        when the source declares it only under `PreToolUse|Write|Edit`;
      - `env` and `permissions` sub-objects are byte-identical across a sweep that removes entries;
      - idempotency: a second sweep over the swept result removes 0 and does not rewrite the file;
      - emptied matcher blocks and event arrays are pruned.

**Timing**: 1.75 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over `merge.lua` and `merge_spec.lua` returns
exactly `test-deploy-propagation.sh` and `test-mcp-merge-target.sh`, so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-propagation.sh,test-mcp-merge-target.sh`
alongside the phase's own plenary spec run.

**Scope Hypothesis**: Eight new specs are added to `merge_spec.lua` and no pre-existing spec in
that file needs editing. Confirm by running the suite before adding specs and after, comparing the
pre-existing case names in both runs; if a pre-existing case does need editing, treat that as a
behavior change requiring its own note rather than a silent edit.

**Files to modify**:

- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - new `M.remove_orphaned_hook_registrations` plus its doc comment stating the carve-out and the four drift shapes it covers
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` - the eight sweep specs, including both survival regressions

**Verification**:

- `nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua" -c "qa!"`
  is green.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-propagation.sh,test-mcp-merge-target.sh`
  is green.
- The two survival specs assert byte-identity of the surviving command string, not merely its
  presence.

---

### Phase 5: Call-siting in manager.load [NOT STARTED]

**Goal**: Wire the sweep into `init.lua`'s per-extension load path exactly where the index-entry
sweep is sited, with a fail-safe valid-set computation and rollback restoration.

**Tasks**:

- [ ] Add a `valid_set` builder in `init.lua` that unions, for the settings merge target:
      every OTHER currently-loaded extension's declared settings fragment (resolved through
      `manifest_mod.get_extension` and its `merge_targets.settings.source`), plus
      `root-files/settings.json`'s own `hooks` block. Exclude the extension currently being
      loaded, mirroring the index sweep's "excluding self, re-added by the very next line"
      pattern.
- [ ] Key the set as `(event, matcher, type, normalized_path)` using the Phase 2 identity module
      for the type/path portion, so the merge-time and sweep-time notions cannot drift.
- [ ] Add the two fail-safe gates, each logged when it fires: skip the sweep entirely if the
      loaded-extension list is EMPTY (an unmanaged or fresh repo), and skip it entirely if ANY
      loaded extension's manifest or declared fragment cannot be read. An incomplete valid set is
      never swept against.
- [ ] Read the current extension's own fragment BEFORE invoking the sweep, and site the sweep
      immediately before the `merge_targets.settings` branch of `process_merge_targets`, inside
      the same `pcall`-guarded block the index sweep already runs in.
- [ ] Thread the sweep's `removed_entries` into the existing `load_ok == false` rollback path so
      a failed load restores the swept entries alongside `remove_installed_files` and
      `reverse_merge_targets`.
- [ ] Confirm the whole-tree sweep conclusion holds for `manager.regenerate`: `settings_backup.restore`
      still runs BEFORE `resync_all` (that ordering is a deliberate earlier fix and is not to be
      changed), and the sweep now runs inside each `manager.load` of that resync loop, which is
      what makes a wipe/regenerate converge instead of reintroducing staleness.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: interface

**Tier Justification**: `suite_selection_select` over `init.lua` and `merge.lua` returns exactly
`test-deploy-orphans.sh`, `test-deploy-verify-overlap.sh` and `test-mcp-merge-target.sh`, the
enumerated direct dependents of the changed load path, so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-orphans.sh,test-deploy-verify-overlap.sh,test-mcp-merge-target.sh`.

**Scope Hypothesis**: Only `init.lua`'s `manager.load` body changes; `process_merge_targets`,
`reverse_merge_targets`, `resync_all` and `manager.regenerate` need no edit beyond the rollback
threading. Confirm by `grep -n "remove_orphaned_hook_registrations" lua/neotex/plugins/ai/shared/extensions/init.lua`
returning call sites only inside `manager.load`, and by reading the regenerate path to confirm the
restore-then-resync ordering is unchanged.

**Files to modify**:

- `lua/neotex/plugins/ai/shared/extensions/init.lua` - `manager.load` valid-set builder, the two fail-safe gates, the sweep call site, and rollback restoration of swept entries
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - signature or return-shape adjustments only if the rollback threading requires them

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-orphans.sh,test-deploy-verify-overlap.sh,test-mcp-merge-target.sh`
  is green.
- `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.init')" -c "qa!"` loads
  cleanly.
- A scratch-repo load exercised headlessly shows the sweep logging a skip when the
  loaded-extension list is empty, and logging a removal count when it is not.

---

### Phase 6: Verify against the real stale deploys and measure after [NOT STARTED]

**Goal**: Demonstrate acceptance criteria 1 and 4 against field files: apply an ordinary
load/resync to each stale deploy, measure the after-state with the Phase 1 recipe, and prove
`env`/`permissions` survived byte-identical.

**Tasks**:

- [ ] Replay each Phase 1 fixture through the sweep in a scratch directory FIRST (a dry run
      against the real field file, before touching any live repo), and record removed/retained
      counts per fixture.
- [ ] Apply an ordinary load/resync to each stale deploy and record the after-state: registration
      count, per-event duplicate count (must be 0), and the `env`/`permissions` fingerprint
      (must equal the Phase 1 value byte-for-byte).
- [ ] For the three unmanaged repos (ModelBuilder, Logos/Website, theorem_proving_in_lean4, which
      carry a deployed `.claude/` but no `.claude-extensions.json`), record exactly which
      operation was used to reach them and whether the sweep fired or was skipped by the
      empty-state gate. If skipped, record the by-hand repair applied and carry that outcome into
      Phase 7's documentation.
- [ ] Verify the host repo's own `SessionStart|startup` `bash scripts/claude-ready-signal.sh`
      entry is gone and the `~/`-anchored form in the other repos is still present, unchanged —
      the acceptance-criterion-1 and criterion-2 field demonstration side by side.
- [ ] Re-run the resync once more per repo and confirm 0 further removals (idempotence on real
      files, not only on fixtures).
- [ ] Measure the no-change control set: registration count and `env`/`permissions` fingerprint
      unchanged for every repo Phase 1 recorded as clean.
- [ ] Write `records/02_after-measurements.md` with the before/after table for every affected
      deploy and the control-set result.

**Timing**: 1.5 hours

**Depends on**: 1, 3, 5

**Verification Tier**: full

**Tier Justification**: This phase regenerates deployed trees in repositories other than the one
under edit, a cross-cutting surface (every consumer repo's live `.claude/settings.json`, including
its `permissions` and `env` blocks) that no module-scoped or dependent-scoped tier observes.

**Scope Hypothesis**: The host repo drops from 28 registrations to 27 (one orphan removed);
ModelBuilder and Logos/Website drop from 12 and converge to the source-declared set for their
loaded extensions; Logos/Theory drops from 30 by at least 2 (the stale `PostToolUse` duplicate and
`wezterm-clear-status.sh`); theorem_proving_in_lean4 drops from 13. Every one of these is a
hypothesis about post-sweep state, not a target: record the actual counts and reconcile any
divergence against the valid set rather than adjusting the sweep to hit a predicted number.

**Files to modify**:

- `specs/369_orphan_sweep_for_removed_merge_target_entries/records/02_after-measurements.md` - new; the before/after table and control-set result
- `__WHOLE_TREE__` - this phase invokes load/resync against deployed trees, an implicit scope claim over each regenerated tree

**Verification**:

- Every affected deploy has a recorded before and after registration count, a per-event duplicate
  count of 0 after, and an `env`/`permissions` fingerprint identical to its Phase 1 value.
- The host repo's orphan command is absent after; the `~/`-anchored command is present and
  byte-identical in every repo that had it.
- A second resync per repo removes 0.
- Every control-set repo's registration count and fingerprint are unchanged.

---

### Phase 7: State the invariant in the boundary narrative [NOT STARTED]

**Goal**: Record the add/change-but-not-delete invariant, the per-merge-target sweep inventory,
and the by-hand repair for a pre-sweep deploy, in the file that already owns this class of
statement.

**Tasks**:

- [ ] Add a section to `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md`
      stating the invariant: the deploy ADDS and CHANGES merge-target content, and DELETES only
      where a merge target has an explicit orphan sweep. This file already exists and is the
      established home for "what the deploy can and cannot do"; if it has been renamed or removed
      by the time this phase runs, extend the file that `rules/source-store-deploy-boundary.md`
      then points at rather than creating a new standalone file.
- [ ] Add the per-merge-target sweep inventory: context index entries sweep orphans
      (`remove_orphaned_index_entries`); hook registrations in `settings.json` sweep orphans
      (`remove_orphaned_hook_registrations`, this task); `merge_targets.mcp` servers merged
      through the same `merge_settings` path have NO sweep today and are a known uncovered target.
- [ ] State the carve-out as part of the invariant, not as an implementation detail: a command not
      recognizable as a source-store hook invocation — including every `~/`-anchored command — is
      never swept, and identity has exactly one definition, naming the module path.
- [ ] Record why no loader operation heals a pre-sweep deploy: `settings_backup` snapshots
      `settings.json`, `manager.wipe` removes the base dir, and `manager.regenerate` restores the
      snapshot as the MERGE BASE before resyncing — a deliberate earlier fix, not to be reverted —
      so `[Reload All]`, `[Regenerate]` and `deploy-headless.sh --wipe` all preserve staleness.
- [ ] Record the by-hand repair for a deploy predating the sweep, with its cost stated:
      `rm .claude/settings.json` then reload works because root-files is install-once and copies
      fresh only when the target is ABSENT, but it discards that repo's local `permissions` and
      `env` customizations; targeted removal of the orphan entries is the lower-cost repair.
      Note explicitly that `deploy-headless.sh --wipe` is NOT a repair.
- [ ] Carry in the Phase 6 outcome for an unmanaged repo (deployed `.claude/` with no
      `.claude-extensions.json`), since that is the case where the empty-state fail-safe means the
      sweep does not fire on its own.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this markdown path,
so no suite covers it; per plan-format.md's sub-case (b) the covering check is
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
alongside the `prose` row's diff read-through.

**Files to modify**:

- `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md` - exists today (verified at plan authoring); add the invariant, the sweep inventory, the carve-out, the no-loader-operation-heals-this explanation, and the by-hand repair. If absent when this phase runs, extend whichever file `rules/source-store-deploy-boundary.md` then points at instead of creating a new one

**Verification**:

- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is green, with neither gate reporting SKIP.
- The narrative names all three merge targets and their sweep status, states the carve-out, and
  gives the by-hand repair with its cost.
- Diff read-through confirms every changed hunk is prose, with no task-number reference (this file
  is outside `specs/**`).

---

### Phase 8: Full gate set, pre-existing specs, and redeploy [NOT STARTED]

**Goal**: Close the task against the complete repository gate set, prove no pre-existing
extension/merge spec went red, and bring the deployed tree into sync with the source store.

**Tasks**:

- [ ] Run the pre-existing Lua specs in full and treat any newly red case as caused by this task
      (acceptance criterion 5): `merge_spec.lua` and `manifest_spec.lua`.
- [ ] Redeploy this repository's `.claude/` tree from the source store with the bounded-wait
      idiom: `timeout 540 bash .claude/scripts/deploy-headless.sh` (Bash tool `timeout` parameter
      raised to 600000). This also clears the `core` staleness this dispatch's deploy-freshness
      context reported.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. Gate 21
      (`lint-hook-registration-paths.sh`) and Gate 8 (`tests/run-all.sh`) are the two that
      directly observe this task's work; neither may be narrowed here.
- [ ] Re-run `suite_selection_select` over every file this task touched and record the post-edit
      answer, closing Phase 3's Scope Hypothesis.
- [ ] Confirm the host repo's own deployed `settings.json` after the redeploy: the orphan gone,
      `env`/`permissions` fingerprint matching the Phase 1 baseline, per-event duplicates 0.

**Timing**: 1 hour

**Depends on**: 6, 7

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the whole deployed tree
- `specs/369_orphan_sweep_for_removed_merge_target_entries/records/02_after-measurements.md` - append the post-redeploy host-repo measurement

**Verification**:

- `nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua" -c "qa!"`
  and the same for `manifest_spec.lua` are both green, with no pre-existing case newly failing.
- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes successfully.
- `bash .claude/scripts/verify-deploy.sh` is green across the complete gate set — the full
  aggregator, not `--only-gate` and not `--skip-slow`.
- The host repo's deployed `settings.json` after redeploy shows the orphan absent, per-event
  duplicates 0, and an `env`/`permissions` fingerprint equal to the Phase 1 baseline.

---

## Testing & Validation

- [ ] Conformance corpus asserted identically on both sides of the identity definition, including
      a path outside `hooks/` (acceptance criterion 3).
- [ ] Dedicated survival regression: a hand-written hook command survives a sweep byte-identical
      (acceptance criterion 2).
- [ ] Dedicated survival regression: a `~/`-anchored command survives a sweep byte-identical.
- [ ] Undeclared-registration removal demonstrated against the real field file, not a synthetic
      fixture (acceptance criterion 1).
- [ ] Cross-matcher and cross-event removal each covered by their own spec.
- [ ] `env` and `permissions` byte-identical across a sweep, asserted in specs and measured per
      deploy (acceptance criterion 4).
- [ ] Idempotence: a second sweep removes 0, on fixtures and on real deploys.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` green.
- [ ] `merge_spec.lua` and `manifest_spec.lua` green, with no pre-existing case newly red
      (acceptance criterion 5).
- [ ] `bash .claude/scripts/verify-deploy.sh` green across the complete gate set.

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/extensions/hook_identity.lua` - the single normative identity function
- `lua/neotex/plugins/ai/shared/extensions/hook_identity_fixtures.json` - the shared conformance corpus
- `lua/neotex/plugins/ai/shared/extensions/hook_identity_cli.lua` - logic-free bridge for the lint
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - delegating `hook_identity`, exported; new `remove_orphaned_hook_registrations`
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` - conformance and sweep specs
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - sweep call site, valid-set builder, fail-safes, rollback restoration
- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` - consumes the shared definition; own notion deleted
- `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` - agreement, ineligibility and bridge-failure tests
- `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md` - the invariant, sweep inventory, carve-out and by-hand repair
- `specs/369_orphan_sweep_for_removed_merge_target_entries/records/01_baseline-measurements.md`
- `specs/369_orphan_sweep_for_removed_merge_target_entries/records/02_after-measurements.md`
- `specs/369_orphan_sweep_for_removed_merge_target_entries/records/fixtures/` - verbatim field copies of each stale deploy's settings.json

## Rollback/Contingency

The whole change is additive at the Lua level: `M.remove_orphaned_hook_registrations` and its
`manager.load` call site are the only behavior-changing additions, and reverting the call site
alone disables the sweep while leaving the reconciled identity definition in place. Reverting the
identity reconciliation additionally requires restoring the lint's own `normalize_identity()`.

Before any rollback that would discard uncommitted work, follow `context/contracts/recovery.md`'s
rollback rung for the snapshot-then-revert invocation shape, including its out-of-scope override
flag for the deliberate whole-tree case; do not emit a bare precautionary snapshot as a routine
start-of-phase step.

For a deploy whose `settings.json` the sweep has already modified: the Phase 1 fixtures are
verbatim pre-sweep copies of every affected repo's file, so a single-repo restore is a copy of the
matching fixture back over `.claude/settings.json`. Because the sweep only ever edits the `hooks`
key, a restore cannot lose `env` or `permissions` content that the sweep itself did not touch —
and Phase 6's fingerprint comparison is what proves it did not.

## Decisions

- **The single identity definition lives in Lua, and the lint consumes it through a logic-free
  bridge** rather than each side keeping its own implementation pinned only by a shared fixture
  corpus. The merge path runs inside Neovim at load time, so Lua is the side that cannot shell
  out; the lint can, and does so once per run. The fixture corpus is retained as the conformance
  pin for both sides, but it is a test, not the definition — acceptance criterion 3's "exactly one
  place" is satisfied by the module, not by the corpus.
- **Cross-EVENT survival is IN scope**, resolving the research report's open question. It needs no
  extra mechanism: once the valid set is keyed `(event, matcher, type, normalized_path)`, a
  registration under an event the source no longer declares is simply absent from the set and is
  swept by the same predicate that handles an undeclared registration. Deciding it out would have
  required a deliberate exception to that predicate, which is harder to justify than including it.
- **Matcher is part of the valid-set key, deliberately**, which is what makes the dispatch's
  cross-matcher requirement work. A hook identity whose `(event, type, path)` IS source-declared
  still fails the predicate when its deployed matcher differs from every matcher the source
  declares it under — "the source is authoritative about WHERE its own hooks register."
- **Two fail-safe gates on the valid set, both absent from the index-entry precedent.** The index
  sweep deliberately runs even with an empty valid set; hook registrations are higher-stakes (an
  over-sweep deletes a user's own guard), so the hook sweep skips on an empty loaded-extension
  list and on any unreadable manifest or fragment. This is a considered divergence from the
  precedent, not an oversight.
- **Anchor shape stays the lint's question, not the sweep's.** Identity normalization collapses
  anchors so the sweep can recognize the same registration across command-string edits; it never
  rewrites a command's anchor. Check A's path-shape verdict is untouched by this task.
- **Measurement uses a recorded `jq` recipe, not a new permanent script**, because durable
  script-corpus growth is a systemic cost this task's non-goals assign to the probe-consumer item.
- **Deploy enumeration comes from the filesystem, not the extension repo registry.** The registry
  at `~/.local/share/nvim/neotex-ai/extension-repo-registry.json` held 313 entries at plan time, of
  which 311 were `/tmp` test fixtures and 2 were real repositories; a filesystem scan is the only
  reliable source for the affected-and-control repo sets.
