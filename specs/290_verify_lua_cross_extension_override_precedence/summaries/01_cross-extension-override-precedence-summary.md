# Implementation Summary: Verify gate 5 cross-extension override precedence

- **Task**: 290 - Verify Lua cross-extension override precedence
- **Status**: [COMPLETED]
- **Started**: 2026-10-02T07:34:50Z
- **Completed**: 2026-10-02T09:45:00Z
- **Effort**: ~6 hours (matches plan estimate)
- **Dependencies**: None
- **Artifacts**: plans/01_cross-extension-override-precedence.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Gate 5 of `verify-deploy.sh` (content-hash equality) compared every deployed path against only
the currently-verified extension's own source, producing three standing false positives on paths
the lean extension deliberately overrides from core. This implementation teaches the comparison
to resolve each deployed path against its actual deploy-order owner, so a deliberate
cross-extension override verifies clean while single-owner paths and genuine content drift are
completely unaffected. It also corrects gate 16's factually wrong `hard_contracts` migration hint
encountered along the way.

## What Changed

- `lua/neotex/plugins/ai/shared/extensions/init.lua` — extracted the Kahn's-algorithm
  dependency-topological sort out of `manager.resync_all` into a new, independently callable
  `manager.compute_deploy_order(loaded)`; added an internal `assemble_ordered_extensions` helper;
  `manager.verify_all` now builds the cross-extension ownership map once and shares it across
  every per-extension `manager.verify` call, which gained an optional third `ownership_map`
  argument (existing 2-argument form unaffected).
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` — added `M.build_ownership_map(extensions,
  target_dir, opts)`, resolving per-leaf deploy-order ownership (last writer wins, mirroring
  `loader.copy_file`'s overwrite semantics, per-leaf not per-directory-entry); extended
  `verify_manifest_category` with `opts.ownership`/`opts.extension_name` to skip the hash compare
  for a non-owner and report it in a new `result.overridden` list instead (never an error, never
  affecting `passed`/`status`); threaded the map through `M.verify_extension`'s new trailing
  `opts` argument. `file_hash` itself was not touched.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — corrected gate 16's header comment
  and `warn` hint text: the two blocks are slated for outright removal (not a migration to
  `hard_contracts`, which is unrelated — it resolves injected contract files, not skill/agent
  names). No pass/warn/fail behavior changed.
- `agent-system/extensions/core/scripts/tests/test-deploy-verify-overlap.sh` (new) — hermetic
  scratch-tree regression harness driving `M.build_ownership_map`/`M.verify_manifest_category`
  directly with two synthetic extensions across three isolated categories, covering: overlap
  clean (Assertion A), genuine drift still fires exactly once, attributed to the owner, never
  duplicated under a non-owner (Assertion B), single-owner path fully unaffected (Assertion C),
  and per-leaf granularity inside a shared directory entry (Assertion D). Registered in
  `agent-system/extensions/core/manifest.json`'s `provides.scripts`.
- `agent-system/extensions/core/context/guides/loader-reference.md` — updated the `init.lua` and
  `verify.lua` source-file rows and added a "Cross-extension path ownership" subsection recording
  the precedence rule and the rejected matches-any-declarer alternative.

## Decisions

- Ownership resolution happens strictly per leaf `rel_path`, never per manifest directory entry,
  so a file one extension ships under a directory another extension also declares (but does not
  itself ship that file) stays correctly attributed — confirmed by construction and by the
  regression harness's Assertion D.
- `manager.verify_all`'s result loop deliberately keeps iterating `manager.list_loaded` (not the
  filtered, deploy-ordered `extensions` array) so a loaded extension whose manifest cannot be
  resolved still surfaces its pre-existing "Extension not found" failure report rather than being
  silently dropped — the ordered array is used only to build the ownership map.
- The regression harness drives the Lua API directly (two synthetic extension source trees plus a
  hand-built deployed tree) rather than running a real two-extension deploy, per the plan's own
  "hermetic and fast" design choice; confirmed non-vacuous by temporarily short-circuiting the
  owner-gating code and observing 4 of 9 assertions fail, then restoring byte-identically.
- Gate 16's corrected wording avoids the literal substring "hard_contracts manifest key" (adjusted
  mid-Phase-6 after the first deploy) so the plan's own post-deploy acceptance grep
  (`grep -c "hard_contracts manifest key" .claude/scripts/verify-deploy.sh` → 0) holds, while
  still stating plainly that `hard_contracts` is an unrelated manifest key.

## Plan Deviations

- None (implementation followed plan). One minor self-correction during Phase 6 (see Decisions
  above): the first wording pass for gate 16 still contained the substring the plan's own
  acceptance grep checks for zero of; this was caught and fixed within the same phase, before
  closing it out, and both `deploy-headless.sh` and the full gate sweep were re-run afterward to
  reconfirm green.

## Impacts

- Gate 5 of `verify-deploy.sh` now reports zero findings against the real deployed tree (confirmed
  via the gate's exact headless invocation and the full `verify-deploy.sh --skip-slow` sweep):
  the three `context/contracts/{adversarial-verification,anti-analysis,reference-grounding}.md`
  false positives are gone.
- Gate 16 still only warns (never fails) when an extension declares
  `routing_hard`/`routing_agents_hard`, now with factually correct hint text.
- No change to deploy behavior (`loader.copy_file`'s last-write-wins overwrite is untouched), to
  `file_hash`'s hashing semantics, or to the manifest schema (no new `owner`/`precedence` field —
  precedence stays derived from dependency order).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet --jobs auto`: 105 discovered
  (confirmed against filesystem enumeration), 99 passed, 6 failed (4 already-documented in
  `known-failures.txt`; the remaining 2 — `test-typst-element-lint.sh` and
  `test-lake-build-guard.sh` — were independently confirmed unrelated to this task: the former is
  explicitly documented in `known-failures.txt`'s own header as traceable to a pre-existing,
  concurrently in-flight uncommitted change to `typst-element-lint.sh`; the latter passed 48/0
  when re-run standalone, indicating a parallel-execution load artifact, not a regression).

## Before/After Record

**Before** (reproduced in the research report, `reports/01_cross-extension-override-precedence.md`):
```
VERIFY_FINDING core: Content differs from source: context/contracts/adversarial-verification.md
VERIFY_FINDING core: Content differs from source: context/contracts/anti-analysis.md
VERIFY_FINDING core: Content differs from source: context/contracts/reference-grounding.md
```

**After** (gate 5's exact headless invocation, post-implementation):
```
VERIFY_DONE count=7
```
Zero `VERIFY_FINDING` lines. The full `verify-deploy.sh --skip-slow` sweep reports
`[verify-deploy] PASS -- 33 check(s), 0 failure(s)`.

## Follow-ups

- The two "two dependent follow-on tasks" referenced by gate 16's corrected hint (removal of
  `routing_hard`/`routing_agents_hard` once their consumers no longer need them) are pre-existing,
  separately tracked work, not introduced or resolved by this task.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` (without `--skip-slow`, i.e.
  including gate 8/the full test suite) was not re-run end-to-end after Phase 6's final
  documentation edit; Phase 5's full run (99/105 passed, no regressions attributable to this
  task) and the `--skip-slow` full gate sweep together give high confidence, but a future task
  touching this area should feel free to re-run the complete suite for full reassurance.

## References

- `specs/290_verify_lua_cross_extension_override_precedence/plans/01_cross-extension-override-precedence.md`
- `specs/290_verify_lua_cross_extension_override_precedence/reports/01_cross-extension-override-precedence.md`
- `lua/neotex/plugins/ai/shared/extensions/init.lua`
- `lua/neotex/plugins/ai/shared/extensions/verify.lua`
- `agent-system/extensions/core/scripts/verify-deploy.sh`
- `agent-system/extensions/core/scripts/tests/test-deploy-verify-overlap.sh`
- `agent-system/extensions/core/manifest.json`
- `agent-system/extensions/core/context/guides/loader-reference.md`
