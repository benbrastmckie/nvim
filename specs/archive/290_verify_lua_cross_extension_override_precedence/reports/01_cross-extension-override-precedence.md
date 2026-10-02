# Research Report: Verify gate 5 cross-extension override precedence

- **Task**: 290 - Verify Lua cross-extension override precedence
- **Started**: 2026-10-02T07:17:00Z
- **Completed**: 2026-10-02T07:45:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Sources/Inputs**:
  - `lua/neotex/plugins/ai/shared/extensions/verify.lua` (gate-5 implementation, hand-authored
    nvim plugin source, NOT a `.claude`/deploy-boundary path)
  - `lua/neotex/plugins/ai/shared/extensions/init.lua` (`manager.verify`, `manager.verify_all`,
    `manager.resync_all`, `manager.load`)
  - `lua/neotex/plugins/ai/shared/extensions/loader.lua` (`copy_category`/`copy_file` — the
    actual deploy-time overwrite semantics)
  - `lua/neotex/plugins/ai/shared/extensions/manifest.lua` (`get_extension`, `list_extensions`)
  - `agent-system/extensions/core/scripts/verify-deploy.sh` (gate 5 and gate 16 shell wrapper)
  - `agent-system/extensions/core/manifest.json`, `agent-system/extensions/lean/manifest.json`
    (`provides.context` declarations)
  - `agent-system/extensions/core/context/contracts/*.md`,
    `agent-system/extensions/lean/context/contracts/*.md`, deployed
    `.claude/context/contracts/*.md` (byte-level diffs)
  - `agent-system/extensions/core/context/guides/manifest-routing-schema.md` (`hard_contracts`
    semantics)
  - `agent-system/extensions/core/context/guides/hard-mode-routing.md`
  - `specs/TODO.md` (task 311-adjacent "collapse hard-routing" backlog entry describing the
    actual future of `routing_hard`/`routing_agents_hard`)
  - Live reproduction: `nvim --headless` invocation of `manager.verify_all` (gate 5's exact
    command) against this repo

## Executive Summary

- Root cause confirmed and reproduced live: gate 5's three false positives come from
  `verify.lua`'s `M.verify_extension`, which checks every manifest-declared path against *only
  that extension's own* source copy, with no awareness that another active extension may
  legitimately declare — and deploy — the same target path.
- `core` and `lean` are the only two of the 7 currently-loaded extensions whose manifests both
  declare the `contracts` directory under `provides.context`. Both ship their own copies of
  `adversarial-verification.md`, `anti-analysis.md`, and `reference-grounding.md`; byte-for-byte
  diff confirms the deployed `.claude/context/contracts/` copies match **lean's** files exactly
  and differ from **core's**.
- The actual deploy-time "winner" for an overlapping path is determined by load order, not by
  any explicit precedence field: `copy_file` always overwrites, and `manager.resync_all` (the
  mechanism `deploy-headless.sh` uses) processes extensions in Kahn's-algorithm topological
  order — dependencies before dependents — so `lean` (which depends on `core`) deploys after
  `core` and wins every overlapping path. There is no reusable, named "ownership resolver"
  today; the ordering logic is inlined inside `manager.resync_all` only.
- `verify_manifest_category`/`walk_category_leaves` (the functions actually responsible for the
  hash comparison) operate on one extension's manifest and source directory at a time, and
  `manager.verify_all` calls them once per loaded extension independently — this is the precise
  location the fix belongs, and it is a hand-authored nvim-plugin Lua file, not a `.claude/**`
  deploy artifact, so it is directly editable (no source-store/deploy-boundary redirection
  needed).
- Secondary, smaller finding confirmed: gate 16's warning hint ("migrate to the `hard_contracts`
  manifest key") is factually wrong per `manifest-routing-schema.md`'s own text — `hard_contracts`
  resolves an injected contract-file list, never a skill or agent name, so it cannot be a
  migration target for `routing_hard`/`routing_agents_hard`. The actual planned future (per the
  backlog) is outright removal of both blocks once hard mode collapses into a
  dispatch-prep injection step, not a key rename.

## Context & Scope

Scope is gate 5 of `verify-deploy.sh` (manifest-driven category parity + content-hash equality,
implemented by `neotex.plugins.ai.shared.extensions.verify`'s `manager.verify_all`), specifically
its three standing false positives on `context/contracts/{adversarial-verification,anti-analysis,
reference-grounding}.md`, all reported under the `core` extension. Secondary, deliberately small
scope: gate 16's misleading warning-hint wording, flagged by the task description as "note while
in here" rather than a primary objective.

Out of scope (confirmed, not investigated further): the deploy copy engine itself
(`loader.copy_category`) is not the bug — it correctly performs a last-write-wins overwrite and
the deployed files are provably correct (byte-identical to lean's deliberate override/parity
sources). This is purely a verification/reporting defect, not a deploy defect.

## Findings

### 1. Reproduction

Running gate 5's exact `nvim --headless` invocation against this repo reproduces the reported
findings exactly:

```
VERIFY_FINDING core: Content differs from source: context/contracts/adversarial-verification.md
VERIFY_FINDING core: Content differs from source: context/contracts/anti-analysis.md
VERIFY_FINDING core: Content differs from source: context/contracts/reference-grounding.md
VERIFY_DONE count=7
```

`manager.list_loaded()` reports 7 active extensions: `core, email, lean, literature, memory,
nix, nvim`. Of these, only `core` and `lean` declare `"contracts"` in `provides.context` (checked
all 7 manifests). `diff -q` confirms all three deployed `.claude/context/contracts/*.md` files
are identical to `agent-system/extensions/lean/context/contracts/*.md` and differ from
`agent-system/extensions/core/context/contracts/*.md`.

### 2. Why lean wins the overlapping paths

`lean`'s manifest declares `"dependencies": ["core", "literature"]`. Deploys run via
`deploy-headless.sh`'s default path: bootstrap-load `core` with `force=true`, then call
`manager.resync_all()`. `resync_all` (init.lua, "Non-destructive force-resync..." section) builds
a dependency graph restricted to the loaded set and runs Kahn's algorithm so dependencies are
resynced before their dependents — `core` before `lean`. Each extension's resync calls
`loader_mod.copy_category("context", ...)` which (via `copy_file`) unconditionally overwrites the
target. Net effect: for any target path two active extensions both declare, the extension that
is *later* in dependency-topological order always wins the deployed content — an implicit,
load-order-derived precedence with no explicit "owner" field anywhere in the manifest schema.

### 3. Where the verification defect actually lives

`verify.lua`'s call chain, per extension, in `M.verify_extension` (lines ~564-760):

- `verify_context` (presence-only, index-entries.json driven) — **not** affected; it only checks
  file existence, never content, so it is not the source of these findings.
- The `hash_only_categories = { "agents", "skills", "rules", "context" }` loop (~705-718) calls
  `verify_manifest_category("context", manifest, extension_dir, target_dir, protected_paths, ...)`
  — **this is the exact source of the false positives**. `manifest`/`extension_dir` here are
  always the *single currently-verified extension's own* manifest and source directory.
- `verify_manifest_category` (~237-262) delegates to `walk_category_leaves` (~147-217), which
  enumerates `{rel_path, source_path, target_path, entry_name}` purely from one manifest's
  `provides.context` list against one `source_dir`. For the `contracts` directory entry, when
  called with `core`'s manifest/dir, it produces leaves whose `source_path` points at core's own
  `adversarial-verification.md` etc. — correctly reflecting core's declared intent, but blind to
  the fact that `lean` also declares this directory and is the one that actually deployed it.
  `verify_manifest_category` then compares `file_hash(leaf.source_path)` (core's copy) against
  `file_hash(leaf.target_path)` (the deployed file, which is lean's copy) — a guaranteed mismatch
  whenever an overlapping path exists and the two sources genuinely differ, independent of
  whether the deploy was correct.
- One level up, `manager.verify_all` (init.lua, ~1093-1104) is the loop that makes this a
  cross-extension problem: it calls `manager.verify(ext_name, project_dir)` — and transitively
  `verify_mod.verify_extension(extension_name, extension.path, target_dir, config,
  protected_paths)` — **independently for every loaded extension**, with no shared view across
  extensions of which declared paths overlap or which extension is the deploy-time owner of an
  overlapping one.

No part of this chain is itself a `.claude/**` deploy artifact subject to the
source-store/deploy-boundary rule — `lua/neotex/plugins/ai/shared/extensions/*.lua` is
hand-authored nvim-plugin source living directly in the repo's `lua/` tree, confirmed by its
absence from any extension manifest's `provides.*` lists (no "lua" category exists in the schema
`loader.lua`'s `CATEGORY_DESCRIPTORS` recognizes). It is edited directly, in place — no
`source_dir` redirection applies to it.

### 4. The file-hash comparison itself is sound and should be preserved as-is

`file_hash` (~109-132) deliberately hashes `vim.fn.readfile`-joined lines (not raw bytes) to
match `copy_file`'s own read/write semantics, specifically to avoid a prior false-positive class
(a source file missing a final trailing newline hashing differently from its faithfully-deployed
copy — documented in-line as "confirmed empirically... reproduced exactly this false positive
before this fix"). This is the right prior-art pattern to follow for the present fix: resolve the
comparison's *inputs* (which source counts as "the" expected content) rather than touching the
hash function itself, and verify empirically against the three known-good override/parity-copy
files plus at least one genuine single-owner path (to confirm no regression in real divergence
detection).

### 5. No existing reusable "ownership resolution" primitive

`resync_all`'s Kahn's-algorithm topological sort is inlined directly in that function (init.lua,
"Non-destructive force-resync" section); it is not factored into a separate, callable helper.
The in-line comment there explicitly frames this sort as "the single... entry point shared by the
picker's 'Reload All' and... headless callers," having already replaced two prior independent
reimplementations — i.e., there is a known, stated project preference against a third
reimplementation of this ordering logic. A fix that needs deploy-order "who wins this path"
semantics should reuse this existing ordering rather than re-deriving it a third/fourth time.

`manifest.lua` already exposes what a fix needs without new plumbing: `M.get_extension(name,
config)` resolves `{name, path, manifest}` for any extension name, and
`manager.list_loaded(project_dir)` returns the active set. `manager.find_orphans` (init.lua,
~1115-1136) already demonstrates the pattern of assembling `{name, source_dir, manifest}` for
every loaded extension before calling into `verify_mod` — a close structural precedent for what
a cross-extension-aware gate-5 fix would need to assemble and pass down.

### 6. Secondary finding: gate 16's warning hint is factually wrong

`verify-deploy.sh` gate 16 (~857-880) warns any manifest still declaring `routing_hard` or
`routing_agents_hard` to "migrate to the `hard_contracts` manifest key." Per
`manifest-routing-schema.md`'s own "Five Blocks" section (lines ~35-37, verbatim): *"`hard_contracts`
is unrelated to either pair — it does not resolve a skill or an agent name, it resolves the list
of behavioral-contract files injected into a `--hard` dispatch's prompt."* `hard_contracts` is
also a one-level `{task_type: [...]}` map, structurally incompatible with `routing_hard`/
`routing_agents_hard`'s two-level `{op: {task_type: value}}` shape — there is no mechanical way to
"migrate" an existing `routing_hard`/`routing_agents_hard` declaration into it; the semantics
don't correspond.

The backlog (`specs/TODO.md`, "collapse hard-routing" entry) describes the actual planned future:
once `/research`/`/plan`/`/implement` are deleted and hard mode collapses into a dispatch-prep
injection step, `routing_hard`/`routing_agents_hard` are simply **removed** from every manifest
(retaining only `routing_agents`), not renamed into `hard_contracts`. The gate's own surrounding
comment (lines 858-862) correctly describes this as awaiting two dependent follow-on changes and
deliberately non-failing in the interim — that framing is accurate and should be kept; only the
`warn` call's pointed instruction text (lines 873-874, "migrate to the hard_contracts manifest
key") is the misleading part, since it names a destination that is not actually where
`routing_hard`/`routing_agents_hard` content goes.

## Decisions

- Confirmed the bug is a verification-logic defect, not a deploy defect: the deployed files are
  provably correct and should continue to deploy exactly as they do today.
- Confirmed the fix belongs in `lua/neotex/plugins/ai/shared/extensions/verify.lua` (and,
  depending on the chosen design, possibly a small addition to `init.lua` to expose/reuse
  `resync_all`'s ordering or an equivalent "which active extensions declare this active
  extension's manifest paths" lookup) — not in any `.claude/**` path, and not via the
  source-store/deploy-boundary redirection (this file is not deploy-managed).
- Confirmed `file_hash`'s line-joined hashing semantics are correct prior art and should not be
  touched; only the *source selected for comparison* needs to change for overlapping paths.
- Scoped gate 16's fix to the `warn` hint text only; the gate's non-failing, awaiting-follow-on-
  tasks posture is correct as-is and should not change.

## Recommendations

1. **(Primary) Make gate-5's per-category hash comparison cross-extension-aware.** Two viable
   designs, in order of fidelity to the task's explicit framing ("resolves against its actual
   deploying owner"):
   - **Owner-resolution design (recommended)**: when verifying extension `E`'s declared leaf at
     `rel_path`, first determine the full set of currently-active extensions that also declare
     `rel_path` (via `manifest_mod.get_extension` for each name in `manager.list_loaded`, mirroring
     `manager.find_orphans`'s existing assembly pattern). If more than one extension declares it,
     resolve the actual deploying owner using the same dependency-topological ordering
     `manager.resync_all` already computes (factor that Kahn's-algorithm block out of
     `resync_all` into a small reusable function — e.g. `manager.compute_resync_order(loaded,
     config)` — so this becomes the second caller instead of a third reimplementation, directly
     addressing the in-line "shared... entry point" precedent in finding 5). Compare the deployed
     hash only against the resolved owner's source; report a mismatch (if any) attributed to that
     owner, and suppress the mismatch finding entirely for every other declaring extension at that
     path (they correctly did not win the deploy). Single-owner paths see zero behavior change.
   - **Matches-any-declarer fallback (simpler, less precise)**: for an overlapping `rel_path`,
     treat the deployed hash as passing if it equals *any* currently-active declaring extension's
     source hash, without computing a specific "owner." Cheaper to implement (no ordering
     extraction needed) but weaker: it cannot distinguish "legitimately deployed by a different
     owner" from "coincidentally matches an unrelated extension's unrelated file," and would
     under-report real divergence if a stale deployed file happens to match some other declarer's
     source by chance. Note as a documented fallback only if the owner-resolution design proves
     too invasive for the plan's effort budget.
   - Either design must preserve single-owner-path behavior exactly (verified by a case where
     only one active extension declares a path — e.g. anything under `context/patterns/` that is
     core-only) and must continue to catch genuine drift (verified by temporarily staling a
     deployed file with an appended line, mirroring the empirical-verification discipline already
     used for the `file_hash` trailing-newline fix cited in finding 4).
   - Implementation surface to touch: `verify.lua`'s `verify_manifest_category`/
     `walk_category_leaves` (need an additional parameter carrying sibling-extension
     source/ownership info) and `M.verify_extension`'s two call sites (`hash_only_categories` and
     `uncovered_categories` loops, ~705-754) that currently call it; `init.lua`'s `manager.verify`/
     `manager.verify_all` (need to assemble and pass the full active-extension set, not just the
     one being verified) and, if the owner-resolution design is chosen, a small extraction from
     `manager.resync_all`.
   - This generalizes beyond the three `contracts` files: any other manifest category where two
     active extensions declare an overlapping directory entry (currently only `core`+`lean` on
     `contracts`, but not structurally prevented elsewhere) gets the same correct treatment for
     free, matching the task's "without weakening real divergence detection for single-owner
     paths" requirement by construction.

2. **(Secondary, small) Fix gate 16's warning hint text.** In
   `agent-system/extensions/core/scripts/verify-deploy.sh` (~873-874), remove or correct the
   `"migrate to the hard_contracts manifest key"` instruction — it names a destination with
   categorically different semantics (contract-file injection list, one-level map) from
   `routing_hard`/`routing_agents_hard` (skill/agent name resolution, two-level map), per
   `manifest-routing-schema.md`'s own text. Replace with wording consistent with the gate's own
   surrounding comment and the backlog's actual plan — e.g. that the two blocks are slated for
   outright removal once the dependent hard-mode-collapse work lands, with no manifest-key
   migration involved. Do not touch the gate's pass/warn/fail behavior or its "awaiting two
   follow-on tasks" non-blocking posture — both are already correct.
3. Add or extend a regression test alongside the existing
   `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` /
   `test-deploy-verify-wiring.sh` family covering: two active extensions declaring an overlapping
   `provides.context` directory entry with different content, asserting gate 5 reports zero
   findings when the deployed content matches the correct (dependency-order) owner, and a nonzero
   finding when it matches neither declarer (genuine drift).

## Risks & Mitigations

- **Risk**: the owner-resolution design couples `verify.lua` to `init.lua`'s internal ordering
  logic, which today only exists inlined inside `resync_all`. **Mitigation**: extract it as a
  small, independently testable pure function (inputs: loaded-name list + per-name dependency
  list; output: topological order) rather than threading `manager`'s closure state into `verify.lua`.
- **Risk**: a fix that reports "no finding" whenever *any* active extension's source matches could
  silently mask a case where the actually-intended owner's file drifted but an unrelated
  extension's unrelated file happens to hash-match by coincidence. **Mitigation**: prefer the
  owner-resolution design (recommendation 1, first bullet) specifically to avoid this; if the
  simpler matches-any-declarer fallback is chosen instead for schedule reasons, document the
  trade-off explicitly in the plan and add the drift-case regression test from recommendation 3.
- **Risk**: touching `M.verify_extension`'s signature (adding sibling-extension context) ripples
  into every call site, including `manager.verify` (single-extension interactive verify from the
  picker), which currently has no "list of other active extensions" concept either.
  **Mitigation**: `manager.verify` already has access to `project_dir`/`config` and can compute
  `manager.list_loaded(project_dir)` itself before delegating, exactly mirroring
  `manager.find_orphans`'s existing assembly pattern (finding 5) — no new external input is
  required, only an internal assembly step shared by both `manager.verify` and
  `manager.verify_all`.

## Appendix

- Live reproduction command (gate 5's exact invocation, abbreviated):
  `nvim --headless ... -c "lua ... manager.verify_all('<repo>') ..." -c "qa!"` →
  `VERIFY_FINDING core: Content differs from source: context/contracts/{adversarial-verification,
  anti-analysis,reference-grounding}.md`, `VERIFY_DONE count=7`.
- `manager.list_loaded()` → `core,email,lean,literature,memory,nix,nvim`; only `core` and `lean`
  manifests declare `"contracts"` under `provides.context` (checked all 7).
- `diff -q .claude/context/contracts/{adversarial-verification,anti-analysis,reference-grounding}.md`
  against both `agent-system/extensions/core/context/contracts/` and
  `agent-system/extensions/lean/context/contracts/`: identical to lean, differs from core, for all
  three files.
- `lean` manifest `"dependencies": ["core", "literature"]` — establishes `core` as a topological
  predecessor, hence `lean` deploys (and overwrites) after `core` in `manager.resync_all`'s order.
- Gate 16 line references: warning text at `agent-system/extensions/core/scripts/verify-deploy.sh`
  lines ~873-874; the gate's own correct "awaiting follow-on tasks" framing at lines ~858-862;
  `hard_contracts` unrelatedness statement at `agent-system/extensions/core/context/guides/
  manifest-routing-schema.md` lines ~35-37; actual planned removal (not migration) of
  `routing_hard`/`routing_agents_hard` described in `specs/TODO.md`'s "collapse hard-routing"
  backlog entry.
