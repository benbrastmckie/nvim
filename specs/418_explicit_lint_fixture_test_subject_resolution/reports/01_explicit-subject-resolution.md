# Research Report: Explicit Lint-Fixture-Test Subject Resolution

**Task**: 418 - Make the lint-fixture-test family's subject resolution explicit and self-declaring
**Started**: 2026-11-06T00:00:00Z
**Completed**: 2026-11-06T00:00:00Z
**Effort**: medium
**Dependencies**: None (sequenced after a chain of prior tasks on `context/standards/shell-script-testing.md` and `scripts/gate-registry.data`, already landed)
**Sources/Inputs**: Codebase exploration (`agent-system/extensions/core/scripts/tests/`, `scripts/lib/common.sh`, `scripts/gate-registry.data`, `scripts/lint/*.sh`), `context/standards/shell-script-testing.md`, `context/patterns/batch-orchestration-guardrails.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The "deploy-tree-first / source-store-fallback" resolution convention is real, load-bearing
  (the Inter-Cycle Redeploy Checkpoint's pre/post divergence signal depends on it), and currently
  implemented in **three different shapes**, only one of which is a shared helper. Re-measured
  population: **70 suites** under `agent-system/extensions/core/scripts/tests/` perform this
  dual-candidate resolution today — far more than either figure on record (the stale
  `context/patterns/batch-orchestration-guardrails.md` figure of 41/73, or this task's own
  at-creation re-measurement of 22/60/119).
- A shared helper (`common_test_resolve_candidate` in `scripts/lib/common.sh`) already exists and
  is used by 20 of the 70. The other 50 either hand-duplicate an identical local function (12
  suites) or inline a `CANDIDATES`-array `for` loop with no named function at all (38 suites) — a
  **third shape invisible to a `grep resolve_candidate` search**, which is why the task's own
  at-creation figure (22) undercounted by more than half.
- Direct inspection of call sites disproves the assumption that even today's implicit order is
  uniformly deploy-tree-first: at least two suites
  (`test-gate-out-derived-staleness.sh`, `test-install-uninstall-extension.sh`) pass the
  source-store candidate FIRST. The defect is exactly as the dispatch states — the preference is
  caller-specific and never declared — not a single rogue ordering to flip.
- Recommendation: extend the existing shared helper with an explicit `mode` parameter and a
  paired mandatory declaration call, both added to `scripts/lib/common.sh` (one home, matching the
  `gate-verdict-extract-lib.sh` precedent); migrate all three existing shapes onto it in staged
  batches within this task (mechanical, logic-preserving); and register a new structural+allowlist
  content lint (gate 27 in `scripts/gate-registry.data`) that blocks a NEW suite from reintroducing
  any of the three undeclared shapes, carrying an explicit, shrinking allowlist of the as-yet-
  unmigrated files so a passing lint is never misread as "fully migrated."

## Context & Scope

Researched: the real population of test suites performing deploy-tree-first/source-store-fallback
subject resolution under `agent-system/extensions/core/scripts/tests/`; the existing shared-helper
extraction (`common_test_resolve_candidate`) and its gaps; the load-bearing reason the preference
must stay caller-selectable rather than being globally flipped (the Inter-Cycle Redeploy
Checkpoint); the prior-art shape for a single-home library extension
(`scripts/lib/gate-verdict-extract-lib.sh`) and for a structural+allowlist content lint
(`lint-state-writer-boundary.sh`, `lint-verdict-extraction-anchoring.sh`); and the verdict-line
extraction contract's token-collision constraint on any new declaration line
(`context/standards/shell-script-testing.md`'s "Verdict-line extraction contract" section).

Out of scope (per dispatch): the separate future follow-up of running only the deploy-tree-first
suites against Gate 8 post-deploy; fixing the three listed known-unrelated pre-existing failures.

## Findings

### Codebase Patterns

**Re-measured population (method: see Appendix for exact commands).**

| Measure | Count | Note |
|---|---|---|
| Total `*.sh` under `scripts/tests/` | 144 | 143 `test-*.sh` + `run-all.sh` |
| Reference literal `$REPO_ROOT/.claude/scripts` | 70 | grep on the literal string |
| Call some form of `resolve_candidate` | 32 | 20 shared + 12 local-duplicate |
| Union of the two measures above | 73 | **coincidentally** also "73" — unrelated to the stale doc's "73 total files" claim; today's real total is 144, not 73 |
| Of that union, deployed-ONLY by design (no fallback; `deploy-root-guard.sh`-style hard requirement) | 3 | `test-backfill-file-scope.sh`, `test-double-loading-check.sh`, `test-update-task-status.sh` — excluded from the defect family: there is no ambiguity to declare when there is only one valid copy |
| **True dual-mode resolution family (the defect population)** | **70** | 73 − 3 |

The 70-suite family breaks down into three distinct implementation shapes:

1. **Shared helper** (`common_test_resolve_candidate`, `scripts/lib/common.sh:294`) — **20
   suites**. Variadic: returns the first argument that is a regular file, in the order the caller
   lists them. The function itself carries no mode concept — the caller's literal argument order
   *is* the policy, baked in at each call site.
2. **Local hand-duplicate** of the identical logic, named `resolve_candidate` (not
   `common_test_resolve_candidate`), re-declared inside the suite itself — **12 suites**
   (`test-lint-json-channel-discipline.sh`, `test-force-phases.sh`,
   `test-gate-out-repair-reporting.sh`, `test-gate-out-self-attribution.sh`,
   `test-handoff-reader-parity.sh`, `test-lint-test-harness-adoption.sh`,
   `test-orchestrate-build-dispatch.sh`, `test-lint-lifecycle-status-var.sh`,
   `test-lint-postflight-boundary.sh`, `test-skill-base-lifecycle.sh`,
   `test-run-task-observers.sh`, `test-todo-move-pair-staging.sh`). All 12 already source
   `scripts/lib/common.sh` for the harness trio (pass/fail/info) — the duplication is scoped
   narrowly to this one function, a residual the shared-helper extraction's own migration did not
   close for these files. This does not violate `common.sh`'s "FORBID LOCAL REDEFINITION" header
   (that note only forbids redefining the `common_`-prefixed names), but it is a copy-pasted block
   of exactly the kind `scripts/lib/gate-verdict-extract-lib.sh`'s own extraction precedent exists
   to eliminate.
3. **Inline `CANDIDATES`-array + `for` loop**, no named function at all — **38 suites** (e.g.
   `test-assess-repo-health.sh:71-80`, `test-deploy-freshness.sh`, `test-context-reachability.sh`,
   `test-consumer-freshness.sh`, and 34 others — full list in Appendix). This shape is why the
   task's own at-creation re-measurement (22 suites calling `resolve_candidate`) undercounted the
   true family by more than half: a plain-text search for the token `resolve_candidate` is blind
   to a resolution loop that was never wrapped in a function with that name.

**Order is not uniformly deploy-tree-first even today.** Two of the 20 shared-helper callers
reverse the order relative to the documented convention:

```
test-gate-out-derived-staleness.sh:
  SKILL_BASE_SRC="$(common_test_resolve_candidate "skill-base.sh (source store)" \
    "$REPO_ROOT/agent-system/extensions/core/scripts/skill-base.sh" \
    "$REPO_ROOT/.claude/scripts/skill-base.sh")" || exit 2

test-install-uninstall-extension.sh:
  INSTALL_SCRIPT="$(common_test_resolve_candidate "install-extension.sh" \
    "$SCRIPT_DIR/../install-extension.sh" \
    "$REPO_ROOT/.claude/scripts/install-extension.sh")" || exit 2
```

A broader (heuristic, not exhaustive) scan of all 39 `common_test_resolve_candidate` call sites
across the 20 files found roughly half put the deployed candidate first — confirming this is not
a single rogue outlier but a real, caller-specific split. This is direct evidence for the
dispatch's central claim: the preference is correct per-caller but currently invisible and
unaudited, not a uniform default that merely needs documenting.

**Of the 23 `test-lint-*.sh` suites specifically** (the literal "lint-fixture-test" origin case
the issue was raised from), 16 are part of the 70-suite family; the other 7 do not resolve a
script-under-test this way. "Lint-fixture-test family" in the task title is therefore a historical
name from the originating case, not a scope restriction — the dispatch's own re-measurement
language and the ORIGIN section's "shared across the whole lint-fixture-test family" phrase both
already treat the convention as spanning the full `scripts/tests/` corpus, not literally only
`test-lint-*.sh` suites. This report follows that wider, already-intended scope.

**The load-bearing constraint, confirmed independently.** `context/patterns/batch-orchestration-
guardrails.md`'s "Inter-Cycle Redeploy Checkpoint" section (around line 851-922) records, as a
*resolved, code-unchanged* decision, that a single-capture Gate-8 sharing design was rejected
specifically because these suites' deploy-tree-first resolution is what lets a pre/post redeploy
pair observe divergence a redeploy itself introduces. That resolution rests entirely on the
*default* behavior of the existing ordering, never on any caller explicitly requesting
"deployed-copy" by name — confirming that whatever new explicit-mode mechanism is built, its
*unset/default* mode must still resolve exactly as today's majority convention does, so the
checkpoint's own two `verify-deploy.sh` passes keep diverging correctly.

### External Resources

No external documentation was consulted — this is a purely internal, codebase-structural task.
Prior art lives entirely inside this repository:

- **Single-home library extraction model**: `scripts/lib/gate-verdict-extract-lib.sh` exports
  exactly one function (`verify_deploy_extract_verdict_lines`), with an explicit required
  parameter (the anchor token — "ALWAYS an explicit parameter... never inferred, never
  defaulted"), a stated producer/consumer contract, and a "Rejected alternatives" section recorded
  so a later pass does not re-propose them. This is the structural model to copy for the new
  mode-explicit resolution helper.
- **Structural+allowlist content lint model**: `scripts/lint/lint-state-writer-boundary.sh` (gate
  12) and `scripts/lint/lint-verdict-extraction-anchoring.sh` (gate 25) both use the identical
  two-layer shape — Layer 1 detects the bad shape structurally (a regex/line-shape match), Layer 2
  is a short, explicitly-reasoned per-file allowlist with no bare paths. Both state their "KNOWN
  LIMITATION" plainly (regex-only, cannot see variable-indirected or cross-line constructions) and
  both are registered as a numbered gate in `scripts/gate-registry.data`.
- **Env-override idiom precedent**: `VERIFY_DEPLOY_GATE8_JOBS` (documented in
  `context/standards/shell-script-testing.md`'s "Suite runtime" section) — unset means a sane
  default (`auto`), set means an explicit override, with no new configuration channel invented.
- **Verdict-line token-collision constraint**: `context/standards/shell-script-testing.md`'s
  "Verdict-line extraction contract (producer/consumer)" section defines `[FAIL]`/`[VIOLATION]` as
  the only tokens `gate-verdict-extract-lib.sh` actually anchors extraction on; `common_test_pass`/
  `_fail`/`_info` additionally already own the `[PASS]`/`[FAIL]`/`[INFO]` tokens for the harness's
  own counted trio. A new declaration line must use a token disjoint from all four
  (`[PASS]`/`[FAIL]`/`[INFO]`/`[VIOLATION]`) to satisfy the dispatch's non-collision requirement
  without ambiguity.
- `scripts/gate-registry.data` currently holds gates 1-26, contiguous, enforced by
  `lint-gate-registry.sh`'s contiguity check (Check E). A new gate would be id 27.

## Decisions

- **The true population for this task's scope is 70 suites**, not the stale 41 figure in
  `context/patterns/batch-orchestration-guardrails.md`, nor the at-creation re-measurement figure
  of 22 (which only caught the `resolve_candidate`-named shapes, missing the 38-suite inline-loop
  shape entirely). `context/patterns/batch-orchestration-guardrails.md`'s "of the 73 files...41
  use..." sentence should be corrected to the measured 70/144 figures as part of this task's
  implementation, per the dispatch's explicit in-scope permission to do so.
- **Do not globally flip the default order.** The Inter-Cycle Redeploy Checkpoint's divergence
  signal depends on the *unset-mode default* continuing to resolve the deployed copy for the
  suites that today implicitly do so. The new mechanism's default (mode unset, both at the env-var
  level and at any caller that does not pass an explicit mode) MUST remain deploy-tree-first.
- **A single caller-selectable mode parameter, not three separate functions.** Mirrors the
  dispatch's own framing ("deployed copy, source-store copy, or the existing deploy-tree-first
  preference") and the `VERIFY_DEPLOY_GATE8_JOBS` idiom: one new environment variable (e.g.
  `CORE_TEST_SUBJECT_MODE`, exact name owned by the plan phase) read once by the shared helper,
  with the same three values as named literal arguments so a suite can also hard-select a mode in
  its own source without relying on the environment.
- **Declaration is a separate, paired call, not baked into the resolver's return value.** The
  resolver's job stays "echo the resolved path"; a new sibling helper (e.g.
  `common_test_declare_subject <path>`) emits the mandatory line using a token disjoint from
  `[PASS]`/`[FAIL]`/`[INFO]`/`[VIOLATION]` (e.g. `[SUBJECT] <absolute path>`), called once per
  resolved subject immediately after resolution. Keeping the two concerns separate matches
  `common.sh`'s existing one-function-one-job convention and lets a suite with multiple
  subjects-under-test (several exist, e.g. `test-install-uninstall-extension.sh`) declare each one
  individually.
- **Migrate all three existing shapes onto the new helper within this task, staged by batch, not
  deferred to a future task.** The underlying resolution logic is byte-identical across all three
  shapes (confirmed: the 12 local-duplicate functions are verbatim copies of
  `common_test_resolve_candidate`'s own body, and the 38 inline loops implement the same
  find-first-existing-candidate semantics) — this is a mechanical substitution, not a logic
  change, and the dispatch's own verification bar ("every migrated suite still produces its prior
  verdict on an unchanged, freshly-deployed tree") is checkable per-batch. 70 files in one
  implementation phase is sizable; splitting into batches (e.g. by shape: shared-helper callers
  first since they only need the declaration-line addition, then local-duplicates, then
  inline-loops) keeps each batch's diff reviewable and independently verifiable, consistent with
  this codebase's own precedent of tranched harness migrations recorded in
  `context/standards/shell-script-testing.md`.
- **The new lint ships in the FIRST batch, with a non-empty, explicit allowlist naming every
  not-yet-migrated file.** This is what prevents the unmigrated remainder from being read as
  already-safe: the lint's Layer-2 allowlist is not a blanket exemption, it is a literal,
  shrinking roster — a reader (or a future gate-registry audit) sees exactly how many files remain
  unconverted, and the count visibly drops to zero as later batches land, rather than the lint
  simply passing silently throughout. The lint's Layer-1 structural check (a locally-defined
  `resolve_candidate`-shaped function, or an inline `CANDIDATES`/`for candidate in`-shaped loop,
  found in a file NOT on the allowlist) blocks a brand-new suite from reintroducing any of the
  three old shapes from day one, regardless of migration progress on the existing corpus.

## Recommendations

1. Extend `scripts/lib/common.sh` with two new functions, following
   `gate-verdict-extract-lib.sh`'s single-home/explicit-parameter/documented-contract model:
   - `common_test_resolve_subject <desc> <mode> <deployed_candidate> <source_store_candidate>` —
     `<mode>` one of `deployed`/`source-store`/`deploy-tree-first` (or empty, meaning consult the
     env-var default, itself defaulting to `deploy-tree-first`). Keep the existing
     `common_test_resolve_candidate` untouched (it has a different, variadic signature already
     used by file-existence checks unrelated to the deployed/source-store duality) — add the new
     function alongside it rather than changing its signature, to avoid a breaking change to the
     20 existing call sites' arity.
   - `common_test_declare_subject <resolved_path>` — prints the mandatory `[SUBJECT] <path>` line
     (or whatever token the plan phase settles on, disjoint from `[PASS]`/`[FAIL]`/`[INFO]`/
     `[VIOLATION]`).
2. Register the new content lint as gate 27 in `scripts/gate-registry.data` (next contiguous id),
   modeled structurally on `lint-state-writer-boundary.sh`/`lint-verdict-extraction-anchoring.sh`:
   Layer 1 detects (a) a locally-defined function matching the `resolve_candidate`-shape body, or
   (b) an inline `for ... in ...; do if [[ -f "$candidate" ]]` -shaped loop over a plural
   `*CANDIDATES*`-named array, outside a small set of already-reasoned exemptions (the 3
   deployed-only suites and any genuinely non-subject-resolution use of the word "candidate").
   Layer 2 is the explicit, shrinking allowlist of not-yet-migrated files.
3. Stage the 70-file migration in batches by shape (shared-helper callers -> local-duplicates ->
   inline-loops), each batch verified against the dispatch's "prior verdict unchanged" bar before
   the next batch starts.
4. Correct `context/patterns/batch-orchestration-guardrails.md`'s stale "73 files... 41 use..."
   sentence to the measured figures in this report (70 of 144, with the three-shape breakdown),
   and add one sentence noting that the inline-loop shape is counted in that 70 even though it has
   no function named `resolve_candidate` — so a future grep-based re-measurement does not
   reproduce this task's own at-creation undercount.
5. Preserve every existing call site's current argument order exactly when migrating to the new
   helper's explicit-mode form — the two confirmed source-store-first callers
   (`test-gate-out-derived-staleness.sh`, `test-install-uninstall-extension.sh`) should migrate to
   `mode=source-store`, not silently flip to the new default, matching the dispatch's "every
   migrated suite still produces its prior verdict" requirement.

## Risks & Mitigations

- **Risk**: migrating 70 files in one pass is large enough to hide a silent behavior change in
  one or two call sites. **Mitigation**: stage by shape (recommendation 3), verify each batch
  independently, and specifically re-check the two confirmed non-default-order callers by name
  before and after migration.
- **Risk**: the new lint's Layer-1 structural detector could false-positive on an unrelated use of
  the word "candidate" or a `for` loop that happens to test `[[ -f ... ]]` for an unrelated
  reason. **Mitigation**: both prior-art lints (`lint-state-writer-boundary.sh`,
  `lint-verdict-extraction-anchoring.sh`) already document this exact class of limitation
  plainly in their own headers rather than over-fitting the regex; the new lint should do the
  same and lean on the allowlist for any genuine false positive rather than chasing a perfect
  detector.
- **Risk**: a future re-measurement repeats this task's own at-creation mistake (grepping only for
  the literal token `resolve_candidate`) and undercounts again once a fourth shape emerges.
  **Mitigation**: recommendation 4's doc correction explicitly calls out the inline-loop shape by
  name so a future reader knows to check for it.
- **Risk**: the declaration-line token collides with an existing or future consumer's extraction
  pattern. **Mitigation**: recommendation 1's token choice is disjoint from every currently-known
  anchor (`[PASS]`/`[FAIL]`/`[INFO]`/`[VIOLATION]`); the plan phase should grep the chosen token
  across `scripts/verify-deploy.sh` and `scripts/lib/gate-verdict-extract-lib.sh` once more before
  finalizing it, since this report's search was not exhaustive over every possible future
  consumer.

## Context Extension Recommendations

- **Topic**: the three-shape taxonomy of deploy-tree-first/source-store-fallback resolution
  (shared helper, local duplicate, inline array-loop).
- **Gap**: `context/standards/shell-script-testing.md`'s "Required structural model for a new
  suite" section documents only the shared-helper shape; it does not name the inline-loop shape as
  an equally-real instance of the same convention, which is exactly why a plain-text search for
  `resolve_candidate` undercounts the population.
- **Recommendation**: once the migration lands, update that section (or a new subsection) to state
  the taxonomy explicitly, so a future measurement of this population does not repeat this task's
  own at-creation undercount.

## Appendix

### Measurement commands (reproducible)

```bash
cd agent-system/extensions/core
# Total suites
find scripts/tests -maxdepth 1 -name '*.sh' | wc -l                      # 144
find scripts/tests -maxdepth 1 -name 'test-*.sh' | wc -l                 # 143

# Literal REPO_ROOT/.claude/scripts reference
grep -l '\$REPO_ROOT/\.claude/scripts' scripts/tests/*.sh | wc -l         # 70

# Any resolve_candidate call (shared or local)
grep -l 'resolve_candidate' scripts/tests/*.sh | wc -l                    # 32
grep -l 'common_test_resolve_candidate' scripts/tests/*.sh | wc -l        # 20
grep -L 'common_test_resolve_candidate' scripts/tests/*.sh \
  | xargs grep -l 'resolve_candidate' | wc -l                             # 12

# Inline CANDIDATES-array loop, no named function (manually filtered for 2 false
# positives describing a PRODUCTION script's own internal resolution rather than the
# test harness's resolution of its subject)
grep -L 'resolve_candidate' scripts/tests/*.sh \
  | xargs grep -l 'CANDIDATES\|for candidate in' | wc -l                 # 40 raw, 38 after
                                                                           # excluding
                                                                           # test-check-record-versioning.sh
                                                                           # and
                                                                           # test-check-task-references.sh
```

### Full inline-loop-shape file list (38, after excluding the 2 false positives)

test-assess-repo-health.sh, test-deploy-freshness.sh,
test-engine-written-state-paths-lib.sh, test-deploy-root-guard.sh,
test-generate-task-order.sh, test-corroborate-phase-counts.sh,
test-context-reachability.sh, test-consumer-freshness.sh,
test-derived-artifact-probe-lib.sh, test-deploy-propagation.sh,
test-dispatch-metrics.sh, test-orchestrate-conclusion-aggregate.sh,
test-errors-append.sh, test-issue-record.sh, test-deploy-orphans.sh,
test-manifest-scripts-sync.sh, test-roadmap-generation.sh,
test-deploy-verify-wiring.sh, test-phase-heading-patterns.sh,
test-return-meta-status-vocabulary.sh, test-status-vocabulary.sh,
test-validate-handoff.sh, test-orchestrate-record-decision.sh,
test-reconcile-demote-stranded.sh, test-redeploy-checkpoint-promotion.sh,
test-resume-scan-nonconformance.sh, test-index-entries-schema.sh,
test-orchestrate-suggest-next-batch.sh, test-reconcile-handoff-status.sh,
test-postflight-deploy-gate.sh, test-redeploy-remedy-lib.sh,
test-sweep-invalidated-claims.sh, test-record-version-patterns.sh,
test-script-inventory.sh, test-validate-return-meta.sh,
test-update-plan-status.sh, test-validate-state.sh, test-validate-artifact.sh

### Full local-duplicate-shape file list (12)

test-lint-json-channel-discipline.sh, test-force-phases.sh,
test-gate-out-repair-reporting.sh, test-gate-out-self-attribution.sh,
test-handoff-reader-parity.sh, test-lint-test-harness-adoption.sh,
test-orchestrate-build-dispatch.sh, test-lint-lifecycle-status-var.sh,
test-lint-postflight-boundary.sh, test-skill-base-lifecycle.sh,
test-run-task-observers.sh, test-todo-move-pair-staging.sh

### Sources consulted

- `agent-system/extensions/core/scripts/lib/common.sh` (lines 1-419, especially
  `common_test_resolve_candidate` at line 294 and the "Required structural model" consumer list)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (lines 1-536, 774-815)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (lines 777-926)
- `agent-system/extensions/core/scripts/lib/gate-verdict-extract-lib.sh` (full file)
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` (header)
- `agent-system/extensions/core/scripts/lint/lint-verdict-extraction-anchoring.sh` (header)
- `agent-system/extensions/core/scripts/lint/lint-gate-registry.sh` (header, checks A-G)
- `agent-system/extensions/core/scripts/gate-registry.data` (full file, gates 1-26)
- `agent-system/extensions/core/scripts/deploy-root-guard.sh` (header)
- `agent-system/extensions/core/scripts/tests/test-lint-shellcheck.sh`,
  `test-gate-out-derived-staleness.sh`, `test-install-uninstall-extension.sh`,
  `test-assess-repo-health.sh`, `test-backfill-file-scope.sh`, `test-double-loading-check.sh`,
  `test-update-task-status.sh`, `test-check-record-versioning.sh` (direct inspection)
