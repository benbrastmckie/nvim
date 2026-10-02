# Implementation Plan: Verify gate 5 cross-extension override precedence

- **Task**: 290 - Verify Lua cross-extension override precedence
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: specs/290_verify_lua_cross_extension_override_precedence/reports/01_cross-extension-override-precedence.md
- **Artifacts**: plans/01_cross-extension-override-precedence.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Gate 5 of `verify-deploy.sh` (content-hash equality, implemented by `verify.lua`'s
`M.verify_extension` via `manager.verify_all`) reports three standing false positives because it
compares each deployed path against *only the currently-verified extension's own* source copy,
with no notion that another active extension may legitimately declare and deploy the same path.
This plan makes the hash comparison resolve each deployed path against its **actual deploying
owner** — the declaring extension that is latest in the same dependency-topological order
`manager.resync_all` already uses to deploy — so a deliberate cross-extension override verifies
clean while single-owner paths keep byte-identical behavior and real drift is still caught
exactly once, attributed to the owner. Secondarily (explicitly a "note while in here" item, not a
primary objective) it corrects gate 16's factually wrong migration-hint wording without touching
that gate's deliberate non-failing posture. Done when gate 5 reports zero findings on a cleanly
deployed tree, a planted genuine drift still fires, and a regression harness locks both behaviors
in.

### Research Integration

The research report (`reports/01_cross-extension-override-precedence.md`) reproduced the defect
live, confirmed its exact location, and settles four design questions this plan builds on
directly:

- **Confirmed location**: `verify_manifest_category` -> `walk_category_leaves` (verify.lua), called
  per-extension from `M.verify_extension`'s `hash_only_categories` and `uncovered_categories`
  loops, and driven per-extension-independently by `manager.verify_all` (init.lua). This is a
  verification defect only — the deployed files are provably correct (byte-identical to lean's
  deliberate override/parity sources).
- **Confirmed precedence mechanism**: there is no explicit manifest "owner" field. The deploy-time
  winner is whichever declaring extension is later in `manager.resync_all`'s Kahn's-algorithm
  dependency-topological order, because `loader.copy_file` unconditionally overwrites. `lean`
  depends on `core`, so `lean` deploys after `core` and wins all three contract paths.
- **Confirmed design choice**: the report's recommended **owner-resolution** design is adopted;
  the **matches-any-declarer fallback** is explicitly rejected (it cannot distinguish a legitimate
  different-owner deploy from a coincidental hash match against an unrelated file, weakening real
  divergence detection — the exact thing the task description forbids).
- **Confirmed no-touch zone**: `file_hash`'s line-joined (not raw-byte) hashing semantics are
  deliberate prior art that already fixed a different false-positive class. Only the *source
  selected for comparison* changes; `file_hash` itself is not modified.
- **Confirmed edit target**: `lua/neotex/plugins/ai/shared/extensions/*.lua` is hand-authored
  nvim-plugin source, absent from every manifest's `provides.*`, so it is edited directly.
  `source-store-deploy-boundary.md` does **not** apply to it. It *does* apply to
  `verify-deploy.sh` and `loader-reference.md`, which are edited under
  `agent-system/extensions/core/**` only.

### Prior Plan Reference

No prior plan. This is the first planning round for this task.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context and `roadmap_flag` was not
set, so no roadmap consultation was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Gate 5 reports zero findings on a cleanly deployed tree in this repository (the three
  `context/contracts/{adversarial-verification,anti-analysis,reference-grounding}.md` false
  positives are gone).
- A deployed path declared by two or more active extensions is hash-compared against the single
  resolved deploying owner's source, and the suppressed non-owner declarations are reported as
  informational (`overridden`), never silently dropped.
- Single-owner paths see byte-identical verification behavior (no suppression, no new exemption).
- Genuine content drift is still detected for both single-owner and overlapping paths, reported
  exactly once and attributed to the owner.
- The dependency-topological ordering is reused from one place, not reimplemented a third time.
- Gate 16's warning hint names the actual plan (eventual removal) instead of a semantically
  impossible `hard_contracts` migration.
- A regression harness locks in: clean-overlap pass, genuine-drift fire, single-owner no-change.

**Non-Goals**:
- Changing deploy behavior. `loader.copy_category`/`copy_file`'s last-write-wins overwrite is
  correct and is not touched.
- Changing `file_hash`'s hashing semantics.
- Adding an explicit `owner`/`precedence` field to the manifest schema (precedence stays derived
  from dependency order; no schema change).
- Changing gate 16's pass/warn/fail behavior or its "awaiting two follow-on tasks" non-blocking
  posture — only the `warn` hint string changes.
- Resolving the `routing_hard`/`routing_agents_hard` removal itself (that is the two known
  follow-on tasks' work, not this task's).
- Changing which extension wins an overlapping path, or editing any of the three
  `context/contracts/*.md` files.
- Touching `verify_context`'s presence-only, index-entries.json-driven check, or the
  presence (`missing`) half of `verify_manifest_category`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Owner-gating accidentally suppresses a genuine drift on an overlapping path | H | M | Suppress the hash check for non-owners **only**; the owner itself still hash-compares normally. Phase 5 asserts a planted drift on an overlapping path still fires exactly once, attributed to the owner |
| Suppression becomes invisible, hiding a future mis-resolution | M | M | Populate `verification[category].overridden` with every suppressed `rel_path` + resolved owner name; never add it to `errors[]`. Phase 5 asserts the field is populated, not just that findings are zero |
| Overlap resolved at directory-entry granularity instead of per-leaf | H | M | Resolve ownership strictly on leaf `rel_path`. Core's `contracts/` files that lean does not ship stay core-owned. Phase 2 task list makes this explicit and Phase 5 asserts it |
| Extracting Kahn's sort from `resync_all` regresses deploy ordering | H | L | Extract as a pure function (inputs: ordered loaded-name list + per-name in-set dependency lists; output: ordered names); `resync_all` becomes its first caller with no behavior change. Phase 1 verifies the live order is unchanged (`core` before `lean`) before anything consumes it |
| A third reimplementation of the ordering logic | M | L | init.lua's own in-line comment states this is the shared entry point replacing two prior duplicates. The new helper lives in init.lua beside `resync_all`; verify.lua receives an **already-ordered** array and contains no ordering logic |
| `M.verify_extension` signature change ripples to unaudited call sites | M | L | Only three live call sites exist (`manager.verify`, and transitively `manager.verify_all`; plus gate 5's headless `verify_all` invocation) — confirmed by grep over `lua/` and `agent-system/`. The new parameter is optional and omitting it preserves today's exact behavior |
| Source-store edits (gate 16, loader-reference.md) create a *new* gate-5 content divergence until deployed | M | H | Phase 6 runs `deploy-headless.sh` before the final gate sweep, and the acceptance check is run against the post-deploy tree |
| Recomputing the ownership map once per extension makes `verify_all` O(n^2) in leaf walks | L | M | Build the map once in `manager.verify_all` and pass it down; `manager.verify` builds its own only when none was supplied, preserving standalone correctness |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 4 | -- |
| 2 | 3 | 1, 2 |
| 3 | 5 | 3 |
| 4 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Extract the deploy-order helper from `resync_all` [COMPLETED]

**Goal**: Make the dependency-topological ordering that decides deploy-time path ownership
callable from outside `manager.resync_all`, without writing a second copy of it.

**Tasks**:
- [x] In `init.lua`, extract the dependency-graph build plus Kahn's-algorithm block currently
      inlined in `manager.resync_all` (the "Build a dependency graph restricted to the
      currently-loaded set" through "Topological sort (Kahn's algorithm)" region) into a new
      function `manager.compute_deploy_order(loaded)` returning the ordered name array
      (roots/dependencies first, dependents last).
- [x] Keep the function pure with respect to deploy state: it reads only the passed `loaded` array
      and each name's `manifest.dependencies` via `manifest_mod.get_extension(name, config)`,
      restricting edges to the loaded set exactly as today.
- [x] Rewrite `manager.resync_all` to call `manager.compute_deploy_order(loaded)` for its
      `resync_order`, deleting the inlined copy. No change to `resync_all`'s signature, return
      shape, `force = true` semantics, or its non-destructive in-place reload behavior.
- [x] Update `resync_all`'s doc comment to state that the ordering now lives in
      `compute_deploy_order` and that deploy order is also the cross-extension path-ownership
      order (one sentence, pointing at the new consumer).
- [x] Add a doc comment on `compute_deploy_order` naming both consumers (`resync_all`, and
      gate-5 ownership resolution) and the "later in this order wins an overlapping path" rule.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: the Kahn's-algorithm ordering exists in exactly one place today
(`manager.resync_all` in `init.lua`), its two prior duplicates having already been collapsed into
it. Confirm at implementation time with `grep -rn "in_degree\|Kahn" lua/neotex/plugins/ai/shared/`
before extracting; if a second live copy is found, fold it onto the new helper in this phase
rather than leaving a divergent copy.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - add `manager.compute_deploy_order`; rewrite `manager.resync_all` to call it

**Verification**:
- `nvim --headless` smoke run of `manager.compute_deploy_order(manager.list_loaded('<repo>'))`
  prints an order containing all 7 active extensions exactly once, with `core` strictly before
  `lean` and `literature` strictly before `lean` (lean's two in-set dependencies).
- `luacheck`/`:luafile` load of `init.lua` is clean (no syntax or undefined-global errors).
- `bash .claude/scripts/deploy-headless.sh --dry-run` still reports the expected extension count
  (ordering path is reached without error).

---

### Phase 2: Owner-gated hash comparison in `verify.lua` [COMPLETED]

**Goal**: Teach the content-hash comparison which active extension actually owns each deployed
leaf, and compare only against that owner's source — reporting, never silently dropping, every
suppressed non-owner declaration.

**Tasks**:
- [x] Add `M.build_ownership_map(extensions, target_dir, opts)` to `verify.lua`, where
      `extensions` is an **already-ordered** array of `{name, source_dir, manifest}` in deploy
      order (Phase 1's order; verify.lua contains no ordering logic of its own). For each
      extension in order, for each hash-checked category, walk `walk_category_leaves` and record
      `map[leaf.rel_path] = {owner = name, source_path = leaf.source_path}` — last writer in the
      iteration wins, exactly mirroring `copy_file`'s overwrite semantics.
- [x] Resolve ownership strictly **per leaf `rel_path`**, never per manifest directory entry: a
      file core ships under `contracts/` that lean does not ship stays core-owned even though the
      `contracts` directory entry itself is declared by both.
- [x] Only record a leaf whose `source_path` is actually readable, so a declared-but-absent source
      never claims ownership away from an extension that really ships the file.
- [x] Cover the same category set the hash check covers (`hash_only_categories` plus
      `uncovered_categories`), driven off `loader.CATEGORY_DESCRIPTORS` as `walk_category_leaves`
      already is, so a future category is included by construction.
- [x] Extend `verify_manifest_category` with an `opts.ownership` map and `opts.extension_name`.
      When a leaf's resolved owner is a *different* extension, skip the hash comparison and append
      `{rel_path = ..., owner = ...}` to a new `result.overridden` list. Leave the presence
      (`missing`) check, the `.syncprotect` exemption, and the `install_once` exemption entirely
      unchanged, and leave behavior identical when `opts.ownership` is absent or the leaf has no
      recorded owner.
- [x] In `M.verify_extension`, accept the ownership map as an optional field on a new trailing
      `opts` argument (omitting it must preserve today's exact behavior), thread it into both the
      `hash_only_categories` and `uncovered_categories` `verify_manifest_category` call sites, and
      surface `verification[category].overridden` when non-empty — **never** appending to
      `verification.errors` and never changing `verification.status` on account of it.
- [x] Do not modify `file_hash`. Add a short comment at the owner-gating site stating that the
      comparison's *input source* is what ownership resolution changes, and that `file_hash`'s
      line-joined semantics remain the sole hashing contract.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: the only current overlap among the 7 active extensions is `core` + `lean`
both declaring `contracts` under `provides.context`, producing three overlapping leaves. Confirm
at implementation time by printing `build_ownership_map`'s entries whose recorded owner is not the
sole declarer (or by `jq -r '.provides.context[]'` across all 7 deployed manifests); if more
overlaps exist, they must all verify clean too — the design covers them by construction, but the
Phase 6 acceptance count must be derived from the real set, not from the assumed three.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` - add `M.build_ownership_map`; owner-gate the hash compare in `verify_manifest_category`; thread the optional ownership map through `M.verify_extension` and populate `overridden`

**Verification**:
- Direct headless call of `M.build_ownership_map` with the live ordered extension set records
  `lean` (not `core`) as owner for all three `context/contracts/*.md` overlapping leaves, and
  records `core` as owner for at least one core-only `contracts/` leaf lean does not ship.
- Direct headless call of `M.verify_manifest_category("context", core_manifest, core_dir,
  target_dir, {}, {ownership = map, extension_name = "core"})` returns zero `hash_mismatch`
  entries for the three paths and three `overridden` entries naming `lean`.
- The same call with `opts.ownership` omitted still returns the three `hash_mismatch` entries,
  proving the no-ownership path is unchanged.

---

### Phase 3: Wire ownership resolution into `manager.verify` / `manager.verify_all` [COMPLETED]

**Goal**: Give the verification entry points a shared, deploy-ordered view of every active
extension so the ownership map is built once and consumed by every per-extension verification.

**Tasks**:
- [x] In `init.lua`, add a small internal helper that assembles the ordered
      `{name, source_dir, manifest}` array for the active set — `manager.list_loaded(project_dir)`
      -> `manager.compute_deploy_order` (Phase 1) -> `manifest_mod.get_extension` per name —
      mirroring `manager.find_orphans`'s existing assembly pattern rather than inventing a new
      shape.
- [x] Have `manager.verify_all` build that array and the ownership map
      (`verify_mod.build_ownership_map`) **once**, then pass the map into each per-extension
      verification.
- [x] Extend `manager.verify(extension_name, project_dir, opts)` with an optional third argument
      carrying the prebuilt ownership map; when absent, `manager.verify` assembles the active set
      and builds the map itself, so a standalone single-extension verify is correct on its own.
      The existing two-argument call form must keep working.
- [x] Pass the map through to `verify_mod.verify_extension` via its new optional `opts` argument
      (Phase 2), alongside the existing `config`/`protected_paths` arguments.
- [x] Update `manager.verify` / `manager.verify_all` doc comments to state that content-hash
      equality is resolved against each path's deploy-order owner, and that a non-owner's
      declaration of an overlapping path is reported as `overridden`, not as an error.

**Timing**: 1 hour

**Depends on**: 1, 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - ordered active-set assembly helper; `manager.verify_all` builds the ownership map once; `manager.verify` gains an optional prebuilt-map argument and self-builds when omitted

**Verification**:
- Gate 5's exact headless invocation (`manager.verify_all('<repo>')`, the command in
  `verify-deploy.sh`) prints `VERIFY_DONE count=7` with **zero** `VERIFY_FINDING` lines.
- `manager.verify('core', '<repo>')` called with two arguments (no map) also reports zero
  content-difference errors, proving the self-building standalone path works.
- A headless call that counts `build_ownership_map` invocations (or a temporary print) confirms
  `verify_all` builds the map once, not once per extension.

---

### Phase 4: Correct gate 16's warning hint text [COMPLETED]

**Goal**: Replace gate 16's factually impossible `hard_contracts` migration instruction with
wording that matches the schema's own statement and the backlog's actual plan, changing no gate
behavior.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/verify-deploy.sh`'s gate 16, rewrite the `warn`
      call's second (hint) argument so it no longer instructs migration to `hard_contracts`.
      State instead that both blocks are slated for outright removal once the dependent hard-mode
      work lands, and that `hard_contracts` is unrelated (it resolves injected contract files,
      not skill or agent names), pointing at `context/guides/manifest-routing-schema.md`.
- [x] Correct the gate's own header comment ("migrate to the flat `hard_contracts` manifest key")
      the same way, so the comment and the emitted hint agree.
- [x] Leave untouched: the gate's selection guard, `CURRENT_GATE`, the `warn`-not-`fail` posture,
      the `gate16_hits == 0` -> `pass` branch, the `jq` predicate, and the `unset` cleanup. No
      pass/warn/fail semantics change.
- [x] Edit the source store only (`agent-system/extensions/core/scripts/verify-deploy.sh`); do not
      hand-edit `.claude/scripts/verify-deploy.sh`, which is a regenerated deploy artifact.

**Timing**: 0.3 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the misleading wording occurs in exactly two places in gate 16 — the gate's
header comment and the `warn` call's hint argument. Confirm with
`grep -n "hard_contracts" agent-system/extensions/core/scripts/verify-deploy.sh` before editing;
correct every occurrence the grep returns inside gate 16, and leave any occurrence outside gate 16
alone unless it repeats the same false claim.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - gate 16 header comment and `warn` hint text

**Verification**:
- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` is clean.
- `shellcheck` (if available) reports no new findings for the edited region.
- Running gate 16 alone still emits one warning per declaring manifest with the corrected text,
  still does not fail the script, and still prints the `pass` line when no manifest declares
  either key.
- `grep -n "migrate to the hard_contracts" agent-system/extensions/core/scripts/verify-deploy.sh`
  returns nothing.

---

### Phase 5: Regression harness for cross-extension ownership [NOT STARTED]

**Goal**: Lock in all three behaviors — overlapping path clean, genuine drift still fires,
single-owner unchanged — so a future refactor cannot silently reintroduce either failure mode.

**Tasks**:
- [ ] Add `agent-system/extensions/core/scripts/tests/test-deploy-verify-overlap.sh`, modeled
      structurally on the existing `test-deploy-orphans.sh` harness (`pass`/`fail`/`info`
      helpers, PASSED/FAILED counters, trap-based scratch `WORKDIR`, headless-nvim subprocess
      against the Lua module under test, exit convention 0 pass / 1 assertion failure / 2
      environment error with a loud skip message).
- [ ] Drive the assertions through the exported Lua entry points
      (`verify_mod.build_ownership_map`, `verify_mod.verify_manifest_category`) with synthetic
      extension source trees and synthetic manifests planted in the scratch tree, rather than
      requiring a two-extension real deploy — `verify_manifest_category` is already exposed "for
      the scratch-tree regression harness / direct inspection", and this keeps the harness
      hermetic and fast.
- [ ] Assertion A (overlap clean): two synthetic extensions, B depending on A, both declaring the
      same `provides.context` directory with **different** content; the deployed file matches B's
      copy. Assert zero `hash_mismatch` for both A and B, and exactly one `overridden` entry
      naming B when verifying A.
- [ ] Assertion B (genuine drift still fires): same setup, deployed file matching **neither**
      declarer. Assert exactly one `hash_mismatch`, reported for the owner B, and not duplicated
      under A.
- [ ] Assertion C (single-owner unchanged): a path declared by A only — assert a matching deploy
      reports zero findings and a staled deploy (appended line) reports exactly one
      `hash_mismatch`, with zero `overridden` entries in both cases.
- [ ] Assertion D (per-leaf granularity): a file A ships under the shared directory that B does
      not ship stays A-owned — assert A hash-compares it (staling it fires) and it never appears
      in `overridden`.
- [ ] Register the new suite in `agent-system/extensions/core/manifest.json`'s `provides.scripts`
      as `tests/test-deploy-verify-overlap.sh` so it is deployed (run-all.sh discovers it by glob,
      but deployment requires the manifest entry).
- [ ] Optionally add an advisory `basename,wall_ms` row to
      `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt`; skip it if the measured
      wall time is unremarkable, since the file is advisory-only.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: four assertions (A-D) are sufficient coverage, and the harness needs no real
two-extension deploy because the required Lua entry points are already exported. Confirm at
implementation time that `M.build_ownership_map` is reachable from a headless `require` of
`neotex.plugins.ai.shared.extensions.verify` (as `M.verify_manifest_category` already is); if it
is not, export it in Phase 2's file rather than widening this harness to a full deploy.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-deploy-verify-overlap.sh` - new scratch-tree regression harness (assertions A-D)
- `agent-system/extensions/core/manifest.json` - register the new suite under `provides.scripts`
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - optional advisory timing row

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-deploy-verify-overlap.sh` exits 0 with all
  four assertions passing.
- Temporarily reverting Phase 2's owner-gating makes Assertion A fail (proving the harness
  actually guards the fix, not a tautology); restore immediately after.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` discovers the new suite (its
  basename appears in the run output) and the full suite result is no worse than the pre-change
  baseline recorded at the start of this phase.

---

### Phase 6: Document, deploy, and verify the full gate sweep [NOT STARTED]

**Goal**: Record the precedence contract where the loader documentation already lives, regenerate
the deploy tree so the source-store edits land, and confirm the whole gate set is green with the
three false positives gone and no new findings.

**Tasks**:
- [ ] Extend `agent-system/extensions/core/context/guides/loader-reference.md`: update the
      `verify.lua` and `init.lua` rows to mention ownership-resolved content-hash equality and
      `compute_deploy_order`, and add a short "Cross-extension path ownership" subsection stating
      the rule (two active extensions may declare the same deployed path; the later one in
      dependency-topological order wins because `copy_file` overwrites; verification resolves the
      owner the same way and reports a non-owner's declaration as `overridden`, not an error).
      Keep it to the existing document's style; do not create a new context file (which would
      also require `provides.context` and `index-entries.json` registration).
- [ ] Record the rejected alternative in one sentence: the matches-any-declarer fallback was
      considered and rejected because a coincidental hash match against an unrelated extension's
      file would mask real drift.
- [ ] Edit the source store only; do not hand-edit `.claude/context/guides/loader-reference.md`.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` (default, non-destructive) so the Phase 4 and
      Phase 6 source-store edits land in `.claude/`. Confirm the
      `[deploy-headless] RESULT=landed_verify_clean` marker.
- [ ] Run the full `bash .claude/scripts/verify-deploy.sh` sweep and confirm gate 5 reports zero
      findings, gate 16 emits only the corrected warning text, and no gate regressed relative to
      the pre-change baseline captured at the start of this phase.
- [ ] Capture a short before/after record (the three original `VERIFY_FINDING` lines; the
      post-change zero-finding `VERIFY_DONE count=7`) for the implementation summary.

**Timing**: 1 hour

**Depends on**: 3, 4, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/guides/loader-reference.md` - `verify.lua`/`init.lua` rows plus a "Cross-extension path ownership" subsection

**Verification**:
- `bash .claude/scripts/deploy-headless.sh` prints `RESULT=landed_verify_clean` and exits 0.
- `bash .claude/scripts/verify-deploy.sh` (full sweep): gate 5 zero findings; gate 16 warning text
  no longer mentions migrating to `hard_contracts`; no newly failing gate versus the baseline.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` is no worse than the baseline.
- Post-deploy `grep -c "hard_contracts manifest key" .claude/scripts/verify-deploy.sh` returns 0,
  proving the deploy actually propagated the Phase 4 edit.

## Testing & Validation

- [ ] Gate 5 (`manager.verify_all`) reports zero findings on a cleanly deployed tree; the three
      `context/contracts/*.md` false positives are gone.
- [ ] `build_ownership_map` resolves `lean` as owner of the three overlapping contract leaves and
      `core` as owner of core-only `contracts/` leaves (per-leaf granularity).
- [ ] A staled deployed file on an overlapping path produces exactly one `hash_mismatch`,
      attributed to the resolved owner, not duplicated across declarers.
- [ ] A staled deployed file on a single-owner path still produces exactly one `hash_mismatch`
      with zero `overridden` entries (no regression in real divergence detection).
- [ ] Omitting the ownership map reproduces today's exact behavior (backward-compatible optional
      argument).
- [ ] `manager.compute_deploy_order` returns every active extension exactly once with `core` and
      `literature` before `lean`; `deploy-headless.sh` still deploys successfully.
- [ ] Gate 16 still warns (never fails) per declaring manifest, with corrected text, and still
      passes when no manifest declares either key.
- [ ] `bash -n` clean on the edited shell script; headless `require` of both edited Lua modules
      loads without error.
- [ ] `test-deploy-verify-overlap.sh` exits 0; `run-all.sh` no worse than baseline.

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/extensions/init.lua` - `manager.compute_deploy_order`; ordered
  active-set assembly; ownership map built once in `manager.verify_all`; optional prebuilt-map
  argument on `manager.verify`
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` - `M.build_ownership_map`; owner-gated hash
  comparison with an informational `overridden` report; optional `opts` on `M.verify_extension`
- `agent-system/extensions/core/scripts/verify-deploy.sh` - corrected gate 16 hint text and header
  comment
- `agent-system/extensions/core/scripts/tests/test-deploy-verify-overlap.sh` - new regression
  harness (assertions A-D)
- `agent-system/extensions/core/manifest.json` - new suite registered under `provides.scripts`
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - optional advisory timing row
- `agent-system/extensions/core/context/guides/loader-reference.md` - cross-extension path
  ownership contract
- Regenerated `.claude/` deploy tree (gitignored deploy artifact; produced by `deploy-headless.sh`,
  never hand-authored)
- `specs/290_verify_lua_cross_extension_override_precedence/summaries/01_*-summary.md` -
  implementation summary including the before/after gate-5 record

## Rollback/Contingency

All edits are confined to two hand-authored Lua files, one shell script, one manifest, one test
script, one optional hints file, and one source-store markdown file — every one of them tracked in
git, and every phase committed per-substep. Reverting is `git revert` of this task's commits (or
`git checkout <sha> -- <path>` for a single file from a clean tree), followed by
`bash .claude/scripts/deploy-headless.sh` to bring `.claude/` back in line with the restored
source store. No migration, no data transformation, and no deploy-behavior change is involved, so
a revert restores the exact prior state — including the three pre-existing gate-5 false positives,
which are a reporting nuisance rather than a correctness hazard, so a partial rollback that leaves
them in place is safe.

If a rollback must discard **uncommitted** working-tree changes, that is a genuine rollback
scenario: follow `context/contracts/recovery.md`'s rollback rung for the exact
`git-snapshot.sh` invocation shape (including its out-of-scope override flag for the deliberate
whole-tree case) before running the destructive command. For an ordinary defensive checkpoint
before risky work, use `git-snapshot.sh --no-revert` instead, which is durable without reverting
the working tree.

Per-phase contingency: Phase 1 is independently revertable (re-inline the ordering) without
touching Phases 2-3. If Phase 2's owner-resolution design proves more invasive than its budget
allows, the documented fallback is the matches-any-declarer check — but it is a **last resort**
only, it must be recorded explicitly in the summary as a deliberate weakening with the masking
trade-off named, and Phase 5's Assertion B must then be adjusted to document (not silently drop)
the case it can no longer distinguish.
