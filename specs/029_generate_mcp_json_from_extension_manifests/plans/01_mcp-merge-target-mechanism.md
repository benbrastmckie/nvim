# Implementation Plan: Task #29

- **Task**: 29 - Generate .mcp.json from extension manifests, then register obsidian-memory through it
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: 22 (declared in state.json; not re-verified here)
- **Research Inputs**: specs/029_generate_mcp_json_from_extension_manifests/reports/01_mcp-json-generation-mechanism.md
- **Artifacts**: plans/01_mcp-merge-target-mechanism.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a `merge_targets.mcp` key to the extension manifest system so an extension can declare an MCP
server and have the deploy engine write it into a project-scoped `.mcp.json` at the repository
root — a surface that actually registers servers, unlike the `mcpServers` keys currently sitting
dead inside `settings-fragment.json` files. The mechanism mirrors the existing
`merge_targets.settings` dispatch path (`process_merge_targets` / `reverse_merge_targets` in
`lua/neotex/plugins/ai/shared/extensions/init.lua` calling `merge.lua`'s
`merge_settings` / `unmerge_settings`), so add-on-load, tracked-retract-on-unload, idempotent
redeploy, and survival of hand-written user entries all come from an already-proven primitive
rather than new design. Done means: the key validates, the engine writes and retracts entries, a
durable scratch-tree regression harness proves all four requirements end to end, the mechanism is
documented including its two user-visible gotchas (workspace-trust approval and
already-running-session invisibility), and the memory extension's dead, fabricated
obsidian-memory declaration is removed in favour of documenting Claude Code's native `/ide`
integration as that plugin's real connection path.

### Research Integration

Findings from `reports/01_mcp-json-generation-mechanism.md` that shape this plan:

- `manifest.lua`'s `validate_merge_targets()` is already generic (any key carrying `source` +
  `target` passes), so the new key needs **no validator change** — only test coverage. This plan
  keeps that open-set design; see Decisions for why, and for the pre-existing failing test the
  design decision resolves.
- `process_merge_targets()` / `reverse_merge_targets()` dispatch per key **explicitly**, not
  generically: `settings` and `index` have hardcoded branches, and `claudemd` / `opencode_json`
  are computed artifacts regenerated wholesale. A new `mcp` key therefore requires one new branch
  in each of those two functions and nothing in `merge.lua`.
- `deep_merge()` only adds keys/array items that are not already present and never overwrites, so
  requirement (d) (hand-written entries survive) holds by construction; `merge_settings()`'s
  `tracked` return, persisted into `.claude-extensions.json` via `state_mod.mark_loaded`, gives
  requirement (b) (unload retracts) across separate nvim sessions.
- Project-root placement is correct and already precedented: `.mcp.json` sits at the same tier as
  `.claude-extensions.json`, outside the disposable `.claude/` tree, so it needs none of
  `settings_backup.lua`'s snapshot/restore wrapper.
- `generate_opencode_json()`'s fully-computed-artifact idiom is explicitly ruled out — it does not
  preserve hand-written content.
- The obsidian-memory declaration's package `@anthropic-ai/obsidian-claude-code-mcp` **does not
  exist** (npm registry 404); the real project is an Obsidian plugin reached through Claude Code's
  native `/ide` integration, not `.mcp.json`. The settled decision (below) is to drop that wiring.
- Two latent risks the research flagged for empirical confirmation rather than speculative repair:
  tracked-unmerge data may thin across a full regenerate, and `write_json`'s `jq .` (order-
  preserving, not sorting) may not be byte-stable. Both are checked by the Phase 3 harness.

### Prior Plan Reference

No prior plan.

### Prior Decisions

From `.decisions.json` (cycle 1, settled — not re-asked): the obsidian-memory half resolves as
**Option 1** — drop the npx/`.mcp.json` wiring for obsidian-memory entirely, document Claude
Code's native `/ide` integration as the real connection path in the memory extension's docs, and
ship the generic `merge_targets.mcp` mechanism without a working obsidian-memory entry. Phase 5
implements exactly this and nothing beyond it: no substitute Obsidian MCP package is selected, and
no tool names are invented.

### Roadmap Alignment

`roadmap_path` was not provided in this dispatch and no `roadmap_flag` was set; no ROADMAP.md
consultation was performed.

## Goals & Non-Goals

**Goals**:

- A `merge_targets.mcp` manifest key that validates and is dispatched by the deploy engine to a
  project-root `.mcp.json`.
- Generated server entries carry an explicit `"type"` field (requirement a) — enforced by the
  fragment shape documented for extension authors and asserted by the regression harness.
- Unloading an extension removes its servers from `.mcp.json` (requirement b).
- Deploying twice yields a byte-identical `.mcp.json` (requirement c).
- Hand-written user entries survive regeneration (requirement d), with the decision recorded
  explicitly.
- A durable regression harness in `agent-system/extensions/core/scripts/tests/` so the mechanism
  does not bit-rot while it has no in-repo consumer.
- The workspace-trust gate and already-running-session invisibility documented where a user will
  find them before reporting the mechanism broken.
- The memory extension's fabricated obsidian-memory declaration removed and its docs corrected.

**Non-Goals**:

- Registering any real MCP server through the new mechanism. Per the settled decision, this task
  ships the mechanism with zero in-repo `merge_targets.mcp` declarations.
- Selecting a substitute Obsidian MCP package, or enumerating obsidian-memory tool names. Both are
  explicitly out of scope under the settled decision.
- Deploying against this repository. The dispatch forbids it; all verification runs against a
  scratch fixture tree. No phase invokes whole-tree regeneration, so no phase declares the
  `` `__WHOLE_TREE__` `` sentinel.
- Making `validate_merge_targets()` a closed set of known keys (see Decisions).
- Changing the `merge_targets.settings` path's own behavior. Every edit to shared code is additive
  and gated on `merge_targets.mcp` being present.

## Decisions

These are planning judgment calls recorded here so the implementer does not re-litigate them.

1. **Requirement (d) resolves as: hand-written entries survive by construction; `.mcp.json` does
   NOT declare itself generated.** `deep_merge`'s additive-only semantics make survival true
   regardless of self-declaration, and JSON has no comment syntax, so an in-file banner would mean
   inventing a pseudo-key. The self-documentation obligation is discharged in prose instead
   (Phase 4: `extension-development.md` and `extension-system.md`), where the file's dual nature —
   extension-managed entries plus whatever the user adds — is stated for both audiences.
2. **`.mcp.json` is not added to `.gitignore`.** It sits at the same project-root tier as the
   tracked `.claude-extensions.json`, and project-scoped MCP registration is conventionally
   repo-shared. Recorded as a decision because the alternative (treating it as a disposable deploy
   artifact like `.claude/`) is defensible but wrong here: the file can hold hand-written content
   that no source store owns.
3. **`validate_merge_targets()` stays open-set; no closed key enum is introduced.** Closing the set
   would hard-fail validation (and therefore silently exclude the whole extension) for any manifest
   in any consumer repository using a key this repo has not enumerated — a blast radius out of
   proportion to the benefit. The cost is accepted and named: a typo'd key (`mcpp`) validates and
   silently does nothing. That hole is pre-existing and identical for all four existing keys, is
   not newly introduced here, and is mitigated by documenting the valid key list (Phase 4) and by
   the Phase 1 verifier that reports a declared-but-not-landed `mcp` target.
4. **The stale `"should reject manifest with invalid merge_targets type"` test is repaired to assert
   the real open-set contract, not deleted.** It currently fails (verified at plan-authoring time —
   see Phase 2's Scope Hypothesis), and it encodes exactly the wrong assumption a future reader
   would re-derive. Rewriting it to assert that an unknown-but-well-formed key *validates* turns a
   red test into a guard on decision 3.
5. **Spec coverage for the new key goes only in
   `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua`.** The research recommended both
   copies, but `shared/extensions/manifest_spec.lua` has no `validate` describe block at all (it
   covers `list_extensions` only), so adding one there would duplicate a suite rather than extend
   one. `claude/extensions/manifest.lua` is pure delegation to the shared validator, so the claude
   copy's assertions do exercise the shared implementation.
6. **The empty-file case is handled in the `mcp` branch, never in `merge.lua`.**
   `unmerge_settings()` rewrites its target even when the result is `{}`; for `.mcp.json` that
   leaves a residual empty file at the project root after the last extension unloads. The cleanup
   (remove the file when unmerge leaves no `mcpServers` entries and no other top-level keys) lives
   in `reverse_merge_targets()`'s new branch so the `settings` path is untouched.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Tracked-unmerge data thins across a full `.claude/` regenerate, so a later unload fails to retract entries that predate the regenerate | M | M | Phase 3 harness asserts the load -> regenerate -> unload sequence explicitly. If it reproduces, record it as a pre-existing limitation of the shared `merge_settings` path (it is not introduced by `mcp`) and do not expand scope to fix it |
| `write_json`'s `jq .` is order-preserving, not sorting, so a second deploy may not be byte-identical | M | L | Phase 3 asserts byte-identity with `cmp`, not a JSON-equality compare. Contingency, only if it reproduces: add an optional `sort_keys` argument to `M.write_json` (additive, backward-compatible) and pass it from the `mcp` branch only |
| The mechanism ships with zero in-repo consumers and bit-rots | M | M | Phase 3 lands a durable harness under `core/scripts/tests/`, picked up automatically by `run-all.sh` and therefore by verify-deploy Gate 8 |
| `claude mcp get` cannot be exercised non-interactively because of the v2.1.196+ workspace-trust gate | L | H | A truthful "could not verify, here is the gate that blocked it" is the correct outcome, and documenting that gate is itself a deliverable (Phase 4). Do not fabricate a passing result, and do not disable the gate |
| Deleting `memory/settings-fragment.json` strands a reference in `lint-hook-registration-paths.sh`'s header comment | L | H | Phase 5 updates that comment in the same phase that deletes the file |
| This repo's deployed `.claude/settings.local.json` keeps a stale merged `obsidian-memory` block (unmerge only runs on unload, and this task must not deploy) | L | H | Harmless — a settings file registers nothing. Note it in the completion summary rather than deploying to clear it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1 |
| 3 | 5 | 4 |
| 4 | 6 | 2, 3, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Deploy-engine `mcp` merge branch [COMPLETED]

**Goal**: `merge_targets.mcp` is dispatched on load and retracted on unload, mirroring the
`settings` branch, with a verifier that reports a declared-but-not-landed target.

**Tasks**:
- [x] In `process_merge_targets()`, add an `mcp` branch immediately after the existing `settings`
      branch: read the fragment with the local `read_json`, call
      `merge_mod.merge_settings(target_path, fragment)` where
      `target_path = project_dir .. "/" .. mt_config.target`, and store the result as
      `merged_sections.mcp`. Do not touch the `settings` or `index` branches. *(completed)*
- [x] In `reverse_merge_targets()`, add the matching branch guarded on
      `merged_sections.mcp and ext_manifest.merge_targets and ext_manifest.merge_targets.mcp`,
      calling `merge_mod.unmerge_settings(target_path, merged_sections.mcp)`. *(completed)*
- [x] In that same reverse branch, implement decision 6's cleanup: after a successful unmerge,
      re-read the target and delete the file when it is empty or carries only an empty
      `mcpServers` object. Guard with `pcall`/existence checks so a missing file is a no-op.
      *(completed)*
- [x] Add `verify_mcp_merge(extension_dir, ext_manifest, project_dir)` to
      `lua/neotex/plugins/ai/shared/extensions/verify.lua`, modelled on `verify_index_merge`: when
      the manifest declares `merge_targets.mcp`, read the source fragment, read the target, and
      report a failure when a declared server name is absent from the target's `mcpServers`.
      Derive `project_dir` inside `verify_extension` as
      `vim.fn.fnamemodify(target_dir, ":h")` — `verify_extension` receives the `.claude/` tree, not
      the project root. Return pass immediately when the manifest declares no `mcp` target.
      *(completed)*
- [x] Wire the new verifier into `verify_extension` alongside the existing index check, pushing a
      named error string into `verification.errors` on failure. *(completed)*
- [x] Confirm no change is needed in `verify.lua`'s orphan-detection helpers: `.mcp.json` lives
      outside `target_dir`, so `find_orphans` never walks it. Record the confirmation in the
      phase notes; make no edit if it holds. *(completed: confirmed by reading find_orphans/
      scan_directory_recursive -- only target_dir is walked; no edit made)*
- [x] Follow `.claude/rules/neovim-lua.md`: 2-space indent, LuaDoc comment on the new verifier,
      locals not globals, `pcall` around optional reads. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase assumes the two dispatch functions are the only sites requiring a
new branch, and that `verify.lua` needs exactly one new function plus one call site. Confirm at
implementation time by grepping `merge_targets` across `lua/neotex/plugins/ai/` before editing: the
only non-shim occurrences should be in `shared/extensions/{init,manifest,verify,merge}.lua` plus the
two `manifest_spec.lua` files. If a fifth site appears, widen this phase rather than deferring.

**Tier Justification**: the edit is confined to two modules whose exported signatures do not change
and whose new behavior is gated entirely on a manifest key that no extension in this repository
declares, so the covering check is a module-load probe plus the existing lua suites:
`nvim --headless -c "lua assert(require('neotex.plugins.ai.shared.extensions.init')); assert(require('neotex.plugins.ai.shared.extensions.verify'))" -c "qa!"` followed by
`nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua" -c "q"`.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - add the `mcp` branch to
  `process_merge_targets()` and `reverse_merge_targets()`, including the empty-target cleanup
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` - add `verify_mcp_merge()` and its
  `verify_extension` call site

**Verification**:
- Both edited modules load cleanly under the headless probe named in the Tier Justification.
- `nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua" -c "q"`
  reports no new failures relative to its pre-edit baseline (capture that baseline first).
- A manual read-through confirms the `settings` and `index` branches are byte-unchanged.

---

### Phase 2: Spec coverage for the new key and the `.mcp.json` merge shape [COMPLETED]

**Goal**: the new key's validity and the merge primitive's four required properties are asserted by
plenary specs, and the pre-existing failing manifest test is repaired.

**Tasks**:
- [x] In `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua`, add a positive case:
      a manifest whose `merge_targets` carries
      `mcp = { source = "mcp-fragment.json", target = ".mcp.json" }` validates
      (`valid == true`, `err == nil`). *(completed)*
- [x] Rewrite the failing `"should reject manifest with invalid merge_targets type"` test per
      decision 4: rename it to state the real contract (an unknown merge-target key with a valid
      `source` + `target` validates — the validator is deliberately open-set) and invert its
      assertions. Keep the two neighbouring `source is required` / `target is required` tests
      exactly as they are; they assert behavior the validator does have. *(completed)*
- [x] In `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua`, add a describe block for the
      `.mcp.json` fragment shape against `merge_settings`/`unmerge_settings`, using the file's
      existing temp-path fixture conventions. Four assertions, one per requirement:
      (a) a merged entry retains its explicit `"type": "stdio"` field verbatim;
      (b) a hand-written `mcpServers.<other>` entry already in the target is still present and
      unmodified after the merge;
      (c) merging the same fragment twice into the same target yields identical decoded content and
      the second merge's `tracked` result adds nothing new;
      (d) `unmerge_settings` with the first merge's `tracked` data removes the extension's own
      server and leaves the hand-written entry intact. *(completed)*
- [x] Run both spec files and confirm zero failures. *(deviation: altered -- manifest_spec.lua is
      18 Success / 0 Fail; merge_spec.lua is 10 Success / 1 Fail, where the 1 failure is the same
      pre-existing, unrelated hook-dedupe test recorded in the Phase 1 handoff, unchanged by this
      phase's edits. All 4 new mcp requirement tests pass)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that
`lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua` currently has exactly one failing test
(`should reject manifest with invalid merge_targets type`, failing at its line 124 assertion with
`Expected false, passed in true`) and that
`lua/neotex/plugins/ai/shared/extensions/manifest_spec.lua` contains no `validate` describe block.
Both were observed directly at plan-authoring time by running
`nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua" -c "q"`
(16 Success / 1 Fail) and reading the shared spec in full. Re-run that command before editing to
confirm the 16/1 baseline still holds; if the count differs, a sibling has changed the file and the
new failure must be understood before proceeding.

**Tier Justification**: the edit touches only two test files with no production code and no exported
signature, so the covering check is running exactly those two suites:
`nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua" -c "q"`
and
`nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua" -c "q"`.

**Files to modify**:
- `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua` - add the `mcp` positive case; repair
  the open-set contract test
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` - add the `.mcp.json`-shape describe
  block covering requirements (a)-(d)

**Verification**:
- Both spec files run green with zero failures and zero errors.
- The claude manifest spec's success count has increased by at least one relative to the 16-success
  baseline, and its failure count is now 0.

---

### Phase 3: Durable scratch-tree regression harness and empirical requirement check [NOT STARTED]

**Goal**: a committed shell harness proves, end to end against a throwaway fixture, that all four
requirements hold — and records the two latent risks' actual behavior rather than assuming it.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-mcp-merge-target.sh`, modelled
      structurally on `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh`:
      `pass()`/`fail()`/`info()` helpers, PASSED/FAILED integer counters, a trap-based `mktemp -d`
      WORKDIR, exit 0 (all pass) / 1 (an assertion failed) / 2 (environment error, nvim absent).
      Source `../lib/common.sh` and resolve the repo root with `common_test_repo_root`, as that
      harness does.
- [ ] Inside the harness, build two scratch trees: a fixture source store at
      `$WORKDIR/src/agent-system/extensions/mcpfixture/` holding a minimal `manifest.json`
      (`name`/`version`/`description` plus `merge_targets.mcp` pointing at `mcp-fragment.json`
      with target `.mcp.json`) and an `mcp-fragment.json` declaring one trivial stdio server with
      an explicit `"type": "stdio"`; and a fixture project at `$WORKDIR/project`, `git init`-ed.
- [ ] Drive the engine headlessly with the config override, not `deploy-headless.sh` (which would
      resolve the real source store): one `nvim --headless -c "lua ..." -c "qa!"` invocation per
      step, building the manager as
      `require('neotex.plugins.ai.shared.extensions.init').create(require('neotex.plugins.ai.shared.extensions.config').claude('$WORKDIR/src'))`
      and calling `manager.load('mcpfixture', { project_dir = '$WORKDIR/project', confirm = false })`
      / `manager.unload(...)`. `config.claude(dir)` appends `/agent-system/extensions` to its
      argument, which is why the fixture source store is nested that way.
- [ ] Assertion A (generation): after the load, `$WORKDIR/project/.mcp.json` exists, is valid JSON
      under `jq empty`, and its `.mcpServers["<fixture>"].type` is `"stdio"`.
- [ ] Assertion B (idempotency, requirement c): copy the file, load again, and compare with `cmp` —
      byte-identical, not merely JSON-equal. On failure, apply the Risks-table contingency (add an
      optional `sort_keys` argument to `merge.lua`'s `M.write_json` and pass it from the `mcp`
      branch only) and re-assert; if it passes, make no `merge.lua` edit at all.
- [ ] Assertion C (hand-written survival, requirement d): plant a second, hand-written server entry
      into the fixture project's `.mcp.json` before a reload; after the reload both entries are
      present and the hand-written one is unmodified.
- [ ] Assertion D (retraction, requirement b): after `manager.unload`, the fixture's server is gone
      while the planted hand-written entry survives; after removing the hand-written entry and
      unloading again from a clean load, the file itself is removed (decision 6's cleanup).
- [ ] Assertion E (the regenerate-then-unload risk): load, then re-run the load to simulate a
      regenerate's re-merge, then unload, and assert retraction still happens. If it does not,
      report it as a pre-existing limitation of the shared `merge_settings` tracking path, assert
      the observed behavior so the harness documents it honestly, and do not expand scope.
- [ ] Attempt the `claude mcp get <fixture-name>` check inside the fixture project and record what
      actually happens. A workspace-trust refusal is an acceptable, expected outcome: record the
      exact refusal and move on. Do not make this assertion fail the harness, and do not attempt to
      bypass the trust gate.
- [ ] Make the harness pass `shellcheck` (verify-deploy Gate 22) and `bash -n`.
- [ ] Record each empirical outcome in the phase notes, including the two risk findings and the
      `claude mcp get` result.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase assumes `config.claude(global_dir)` resolves its extension source
store as `global_dir .. "/agent-system/extensions"` and that `manager.load` accepts
`{ project_dir = ..., confirm = false }`, both read directly from
`lua/neotex/plugins/ai/shared/extensions/config.lua` and `init.lua` at plan-authoring time; and that
a fixture manifest with no `dependencies` array loads without bootstrapping `core`. Confirm the
latter by running the harness's first load step before writing the remaining assertions — if core
bootstrapping is forced, add `"dependencies": []` or accept a core load into the scratch project
(harmless, since the project is discarded).

**Tier Justification**: the only committed artifact is one new self-contained test script that no
other script sources, so the covering check is that script run directly
(`bash agent-system/extensions/core/scripts/tests/test-mcp-merge-target.sh`) plus
`bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` for the Gate 22
surface it newly occupies.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-mcp-merge-target.sh` - new scratch-tree
  regression harness for the four requirements plus the two latent-risk assertions
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - CONTINGENT, only if Assertion B shows the
  output is not byte-stable: add an optional `sort_keys` argument to `M.write_json`
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - CONTINGENT, paired with the above: pass
  `sort_keys` from the `mcp` branch only

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-mcp-merge-target.sh` exits 0 with every
  assertion reported PASS.
- `shellcheck` and `bash -n` are clean on the new script.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-mcp-merge-target` (or the
  suite name `suite_selection_select` resolves for the new file) picks the harness up, confirming it
  is wired into the Gate 8 surface.
- Nothing was deployed into this repository: `git status --short` shows no `.claude/` changes and no
  root `.mcp.json`.

---

### Phase 4: Document the mechanism and its two user-visible gotchas [NOT STARTED]

**Goal**: an extension author can find how to declare a server, and a user who sees "my server
isn't there" finds the workspace-trust and running-session explanations before filing it as broken.

**Tasks**:
- [ ] `agent-system/extensions/core/context/guides/extension-development.md`: document
      `merge_targets.mcp` alongside the existing `settings` / `index` / `claudemd` entries — the
      manifest snippet, the `mcp-fragment.json` source-file shape with its mandatory `"type"`
      field, the project-root target, and the load/unload semantics. State the valid merge-target
      key list explicitly (decision 3's mitigation) and note that an unrecognized key validates but
      is never dispatched.
- [ ] `agent-system/extensions/core/docs/architecture/extension-system.md`: add an `mcp` row to the
      `merge_targets` table; correct the registration-surface note that currently says only
      `~/.claude.json` registers servers, to name project-scoped `.mcp.json` as a real registration
      surface now produced by the deploy engine; add the `mcp` step to the load and unload process
      step lists; and extend the "Settings Merging" section's note so it points `mcpServers`
      declarations at the new key instead of leaving them as dead weight.
- [ ] In the same file, repair the two stale rows the research found incidentally: the merge.lua
      function table lists `merge_opencode_agents()` / `unmerge_opencode_agents()`, which no longer
      exist in `merge.lua`. Confirm their absence by grepping `merge.lua` before removing the rows.
- [ ] Add a short, named subsection — in `extension-system.md` next to the new `mcp` material — for
      the two user-visible gotchas, stated plainly enough to pre-empt a false bug report:
      (i) a project-scoped `.mcp.json` server needs workspace-trust approval before
      `claude mcp list` will read it (Claude Code v2.1.196+);
      (ii) a server added to `.mcp.json` is invisible to any already-running session, including the
      main one — verify against a fresh session or `claude -p`, never the current one.
      Record whatever Phase 3 actually observed for `claude mcp get`, including a trust-gate
      refusal, rather than asserting an unverified pass.
- [ ] Also document decision 1 here: `.mcp.json` carries both extension-managed and hand-written
      entries, hand-written entries survive regeneration by construction, and the file carries no
      in-file generated banner (JSON has no comments) — which is why this prose is the
      self-declaration.
- [ ] `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`: add the one-hop
      cross-reference the research recommended, from its Registration section to the new
      `extension-development.md` material, so the conceptual ownership doc reaches the mechanical
      how-to.
- [ ] Deliverable rule: no task numbers anywhere in these files. Cite filenames and section
      headings only.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase assumes four doc files carry the anchors named above, located at
plan-authoring time by grep: `extension-system.md`'s `merge_targets` table row (~line 225), its
`mcp_servers` registration note (~line 227), its merge.lua function table rows for
`merge_opencode_agents`/`unmerge_opencode_agents` (~lines 285-286), its load-process step list
(~line 375) and `## Settings Merging` section (~line 471, with the registration note ~line 498);
`extension-development.md`'s `merge_targets` manifest example (~line 58) and field table (~line 83).
Line numbers are an orientation aid only and will have drifted — re-locate every anchor by its
heading or surrounding text, never by line number, and widen the edit if an anchor has moved or
multiplied.

**Tier Justification**: every touched path is a source-store markdown file with no executable
surface, so `suite_selection_select` returns `__FULL_SWEEP__` and no test suite covers them; per
`plan-format.md`'s `__FULL_SWEEP__` sub-case (b), the honest covering check is the doc-lint and
task-reference-lint gate subset run with this repository's own root as TARGET —
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` —
together with the `prose` row's diff read-through of every changed hunk.

**Files to modify**:
- `agent-system/extensions/core/context/guides/extension-development.md` - document
  `merge_targets.mcp`, the fragment shape, and the valid-key list
- `agent-system/extensions/core/docs/architecture/extension-system.md` - `mcp` table row,
  registration-surface correction, load/unload steps, Settings Merging note, the two-gotcha
  subsection, decision 1's self-declaration prose, and the two stale merge.lua function rows
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` - one-hop cross-reference
  to the new mechanical how-to

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports no findings for the touched files, and does not report zero checks under the filter
  (a zero-check run attests to nothing).
- `grep -nE 'task [0-9]+|tasks [0-9]+' ` over the three touched files returns nothing.
- Diff read-through confirms every changed hunk is prose or a table row, and that the removed
  merge.lua function rows name functions genuinely absent from `merge.lua`.

---

### Phase 5: Resolve the obsidian-memory half per the settled decision [NOT STARTED]

**Goal**: the fabricated obsidian-memory declaration is gone, the memory extension's docs name
Claude Code's native `/ide` integration as the real connection path, and nothing is invented.

**Tasks**:
- [ ] Delete `agent-system/extensions/memory/settings-fragment.json`. Its entire content is the
      dead `mcpServers.obsidian-memory` block; it carries no permission grants, so nothing is lost.
      Confirm that by reading the file immediately beforehand.
- [ ] Remove the now-dangling `merge_targets.settings` entry from
      `agent-system/extensions/memory/manifest.json`, leaving `claudemd` and `index` untouched.
      Confirm with `jq empty` afterwards.
- [ ] `agent-system/extensions/memory/README.md`, `### MCP Server Setup`: remove the claim that the
      WebSocket option "is configured in `manifest.json`" (it never was, and under the settled
      decision it will not be). Replace the `obsidian-claude-code-mcp` row's launch story with the
      truth: that plugin is an Obsidian desktop plugin reached through Claude Code's native `/ide`
      command, not a spawnable server, and no `.mcp.json` or `~/.claude.json` entry participates.
      Keep the WebSocket port and the "Obsidian desktop + plugin" prerequisite, which are accurate.
      State the prerequisite plainly as the dispatch requires, and state explicitly that the tool
      surface was NOT verified against a running server, with the reason.
- [ ] `agent-system/extensions/memory/context/project/memory/memory-setup.md`: remove the
      `@anthropic-ai/obsidian-claude-code-mcp` npx configuration block from its Option 1 section —
      the package does not exist on the npm registry (404) and the block cannot work — and replace
      it with the `/ide` instructions. Leave the second `mcpServers` block alone if it belongs to
      the separate REST-API option; read it before deciding.
- [ ] `agent-system/extensions/memory/context/project/memory/memory-troubleshooting.md`: correct
      the install step that points at the plugin as an MCP server so it names the `/ide` path.
- [ ] In the memory README, cross-reference Phase 4's two-gotcha subsection for anyone who later
      does register a real server through `merge_targets.mcp`.
- [ ] Update `lint-hook-registration-paths.sh`'s `KNOWN FALSE-POSITIVE RISKS` header comment, which
      cites `memory/settings-fragment.json`'s `mcpServers.obsidian-memory.command: "npx"` as its
      worked example: restate the same closure argument ("npx" never yields an extracted `*.sh`
      token) without naming a file this phase deletes. Comment-only edit; change no logic.
- [ ] Do not select a substitute Obsidian MCP package, do not add a `merge_targets.mcp` entry to the
      memory manifest, and do not list obsidian tool names anywhere. All three are out of scope
      under the settled decision.
- [ ] Deliverable rule: no task numbers in any of these files.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that three memory-extension files carry the nonexistent
package or the false "configured in manifest.json" claim — `README.md` (~lines 238-258),
`context/project/memory/memory-setup.md` (~lines 35, 46, 73-76, 138) and
`context/project/memory/memory-troubleshooting.md` (~line 25) — and that
`lint-hook-registration-paths.sh`'s only reference to `memory/settings-fragment.json` is the header
comment at ~line 120 (its logic walks an enumerated glob, never that path literally), with
`test-lint-hook-registration-paths.sh`'s occurrence (~line 524) being self-contained fixture data
rather than a read of the real file. All were located by grep at plan-authoring time. Re-confirm
before editing with `grep -rn 'obsidian-claude-code-mcp\|settings-fragment' agent-system/extensions/memory agent-system/extensions/core/scripts`,
and in particular confirm the test occurrence is a heredoc fixture — if it reads the real file,
that test must be updated in this phase too.

**Tier Justification**: the edits are one manifest key removal, one file deletion, and prose in four
markdown files, none with a suite mapping, so the covering checks are
`jq empty agent-system/extensions/memory/manifest.json`,
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-hook-registration-paths`
for the one lint whose corpus changes, and the doc gate subset
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.

**Files to modify**:
- `agent-system/extensions/memory/settings-fragment.json` - DELETE (dead `mcpServers` block only)
- `agent-system/extensions/memory/manifest.json` - remove the dangling `merge_targets.settings`
  entry
- `agent-system/extensions/memory/README.md` - correct the MCP Server Setup section to the `/ide`
  path; state the prerequisite and the unverified-tool-surface fact plainly
- `agent-system/extensions/memory/context/project/memory/memory-setup.md` - remove the nonexistent
  npx package configuration; document the `/ide` path
- `agent-system/extensions/memory/context/project/memory/memory-troubleshooting.md` - correct the
  plugin install/connection step
- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` - header comment only:
  restate the false-positive closure without citing the deleted file

**Verification**:
- `jq empty agent-system/extensions/memory/manifest.json` passes and
  `jq '.merge_targets | keys' ` on it returns exactly `claudemd` and `index`.
- `grep -rn 'obsidian-claude-code-mcp@latest\|configured in \`manifest.json\`' agent-system/extensions/memory`
  returns nothing.
- `grep -rn 'settings-fragment' agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh`
  no longer names the memory extension's copy.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-hook-registration-paths`
  passes, and the doc gate subset above reports no findings for the touched files.
- No task-number references in any touched file.

---

### Phase 6: Full gate set and completion [NOT STARTED]

**Goal**: the complete repository gate set runs green over every change, with the no-deploy
constraint honored.

**Tasks**:
- [ ] Re-read the whole diff for this task before the gate run, per the dispatch's concurrency note,
      confirming no file outside this plan's declared scope was touched and no sibling's hunks are
      staged with ours.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` against this repository
      root, with the Bash tool `timeout` raised to `600000` and an inner `timeout 540`, per
      `context/patterns/external-process-wait.md`. Record the verdict and every FINDING line.
- [ ] Run the full shell suite explicitly so the new harness is exercised in the aggregate:
      `bash agent-system/extensions/core/scripts/tests/run-all.sh`.
- [ ] Run both lua spec files one final time against the finished tree.
- [ ] Triage every finding. Fix forward on anything this task introduced. For a pre-existing finding
      unrelated to this task's scope, record it by name in the completion notes rather than
      expanding scope.
- [ ] Confirm the dispatch's verification constraints held: no deploy was performed against this
      repository (`git status --short` shows no `.claude/` modifications and no root `.mcp.json`),
      and every empirical claim in the docs traces to a Phase 3 observation rather than an
      assumption. Any claim that could not be verified is marked as such with its reason.
- [ ] Record the Phase 3 risk findings (byte-identity, regenerate-then-unload) and the
      `claude mcp get` outcome in the completion notes, whichever way they came out.

**Timing**: 0.75 hours

**Depends on**: 2, 3, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `specs/029_generate_mcp_json_from_extension_manifests/summaries/01_mcp-merge-target-mechanism-summary.md` -
  completion summary (the only file this phase writes; all other phases' edits are already landed)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set it aggregates — gates 0 through 23,
  including Gate 8's `run-all.sh` shell battery, Gate 3 doc-lint, Gate 4 task-reference lint,
  Gate 13 orphan detection, Gate 21 hook-registration lint, Gate 22 shellcheck and Gate 23
  directory-pathspec lint) exits 0, or every remaining finding is named and shown to pre-date this
  task.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0.
- `nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua" -c "q"`
  and the same for `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` both report zero
  failures.
- `git status --short` confirms nothing under `.claude/` was modified and no root `.mcp.json` exists.

---

## Testing & Validation

- [ ] `merge_targets.mcp` validates (claude manifest spec positive case).
- [ ] The repaired open-set contract test passes, and the claude manifest spec has zero failures.
- [ ] Requirement (a): a generated entry retains its explicit `"type"` field — asserted in both the
      merge spec and the scratch harness.
- [ ] Requirement (b): unload removes the extension's servers and leaves hand-written entries —
      asserted in both.
- [ ] Requirement (c): a second deploy is byte-identical under `cmp`.
- [ ] Requirement (d): hand-written entries survive regeneration, with the decision recorded in
      prose.
- [ ] The regenerate-then-unload sequence's actual behavior is asserted, whichever way it comes out.
- [ ] `claude mcp get <fixture>` in the fixture project is attempted and its real outcome recorded,
      including a workspace-trust refusal.
- [ ] No deploy was performed against this repository.
- [ ] The complete gate set runs green (Phase 6).

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/extensions/init.lua` - `mcp` merge/unmerge branches
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` - `verify_mcp_merge()` plus call site
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` - `.mcp.json`-shape specs
- `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua` - `mcp` positive case; repaired
  open-set contract test
- `agent-system/extensions/core/scripts/tests/test-mcp-merge-target.sh` - new durable harness
- `agent-system/extensions/core/context/guides/extension-development.md` - `merge_targets.mcp`
  authoring guide
- `agent-system/extensions/core/docs/architecture/extension-system.md` - mechanism, gotchas, stale
  row repairs
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` - cross-reference
- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` - header comment
- `agent-system/extensions/memory/manifest.json` - `merge_targets.settings` removed
- `agent-system/extensions/memory/settings-fragment.json` - deleted
- `agent-system/extensions/memory/README.md`,
  `context/project/memory/memory-setup.md`,
  `context/project/memory/memory-troubleshooting.md` - `/ide` corrections
- `specs/029_generate_mcp_json_from_extension_manifests/summaries/01_mcp-merge-target-mechanism-summary.md`

## Rollback/Contingency

Every phase is a small, independently revertable commit, and no phase deploys into this repository,
so the blast radius of a bad landing is confined to the source store and the `lua/` engine — no
generated tree to rebuild.

- **A phase's own commit is wrong**: revert that single commit. The `mcp` branch is additive and
  gated on a manifest key no extension declares, so reverting Phase 1 alone restores exactly the
  prior deploy behavior.
- **Phase 3's Assertion B contingency makes things worse**: the `sort_keys` argument to
  `M.write_json` is optional and passed only from the `mcp` branch, so dropping that one commit
  leaves every other caller byte-unchanged.
- **Phase 5's deletion needs undoing**: `agent-system/extensions/memory/settings-fragment.json` and
  the manifest's `merge_targets.settings` entry are restored together from git history; the content
  is a dead block that registered nothing, so nothing depends on its presence.
- **Uncommitted work must be discarded to recover**: that is a genuine rollback, not a routine
  checkpoint — follow `context/contracts/recovery.md`'s rollback rung for the exact
  `git-snapshot.sh` invocation shape, including its out-of-scope override flag, before running any
  destructive git command. For an ordinary defensive checkpoint before the Phase 3 harness work, use
  `bash .claude/scripts/git-snapshot.sh 29 --no-revert`, which is durable without reverting the
  working tree.
