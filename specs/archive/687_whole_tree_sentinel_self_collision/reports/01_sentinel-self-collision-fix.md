# Research Report: Task #687

**Task**: 687 - Whole-tree sentinel self-collision
**Started**: 2026-11-23T00:00:00Z
**Completed**: 2026-11-23T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts/lib/file-scope-overlap.sh, scripts/orchestrate-batch-admit.sh, scripts/lint/lint-roadmap-batch-proposals.sh, scripts/orchestrate-cycle-plan.sh, scripts/tests/test-orchestrate-batch-admit.sh, scripts/tests/test-lint-roadmap-batch-proposals.sh, context/patterns/file-footprint-overlap.md, context/patterns/batch-orchestration-guardrails.md, docs/architecture/batch-admit-schema.md)
**Artifacts**: - specs/687_whole_tree_sentinel_self_collision/reports/01_sentinel-self-collision-fix.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is real and precisely located: `scripts/lib/file-scope-overlap.sh`'s
  `scopes_overlap_first()` treats two literal `__WHOLE_TREE__` sentinel entries as an ordinary
  exact-match overlap (clause 1 of the Overlap Rule). This is not an accident — it is the
  documented, deliberately-chosen detection signal (`context/patterns/file-footprint-overlap.md`
  lines 57-63, `context/patterns/batch-orchestration-guardrails.md` lines 1695-1703) that both
  consumers currently read as a hard collision.
- `orchestrate-batch-admit.sh` relabels that same-sentinel hit into `defer_reason:
  "whole_tree_claim"` (lines 1070-1105) but still sets `decision: "defer"` — and
  `orchestrate-cycle-plan.sh`'s `whole_tree_claim)` case arm (lines 2066-2073) has no
  `--allow-X` bypass, so the deferred candidate is excluded from `dispatch_candidates` for that
  cycle exactly like a genuine `file_scope_collision`. The "ORDERING CONSTRAINT, not an
  exclusion" language already in the `reason` string is aspirational prose; the mechanical
  effect today is a per-cycle exclusion that repeats every cycle the other task stays
  non-terminal — this is surface (i)'s measured width-1 serialization.
- `lint/lint-roadmap-batch-proposals.sh`'s Finding (a) (lines 354-389) calls the *same*
  `scopes_overlap_first()` directly against a candidate's and a batch member's `file_scope`
  arrays, with no sentinel special-casing at all — surface (ii)'s 110-of-403 findings.
- **Recommended fix location is the shared library, exactly as the dispatch's "THE SHARED
  COMPARATOR" paragraph anticipates**: exclude the sentinel-vs-sentinel case from
  `scopes_overlap_first()`'s match clause, so neither consumer sees it as an overlap hit at all.
  A second, separate, purely-informational predicate (new) lets `orchestrate-batch-admit.sh`
  keep surfacing the same-claim pair as a non-blocking, always-admit advisory (an "ordering
  relation", matching the deliverable's own wording) rather than deleting the signal outright.
- This is a genuine **reversal** of an earlier, deliberate design decision (the `whole_tree_claim`
  defer_reason), not an oversight fix — the existing fixture `WHOLE-TREE-CODISPATCH` in
  `test-orchestrate-batch-admit.sh` (lines 524-574) currently pins `decision: "defer"` as the
  *target posture* and will need its assertions flipped to `decision: "admit"` for both
  candidates. This report documents that reversal explicitly rather than treating it as a bug
  in the old code (the old code matched its own contemporaneous design exactly).

## Context & Scope

Researched: the exact code path by which two tasks each declaring the `__WHOLE_TREE__`
file_scope sentinel are held in conflict, in both of the dispatch's named consumers
(`orchestrate-batch-admit.sh` for in-batch admission, `lint-roadmap-batch-proposals.sh` for
roadmap batch-proposal linting), plus the shared comparator library
(`scripts/lib/file-scope-overlap.sh`) both read. Also researched: every other touchpoint of the
sentinel across the core extension, to confirm which are in-scope for a self-collision fix and
which are not (per the dispatch's explicit SCOPE BOUNDARY: "this record owns the sentinel
self-collision only. It does not touch the general in-dispatch file_scope extension channel, and
it does not change what the roadmap renders or what the roadmap commit stages.").

Not researched (explicitly out of scope per the dispatch): the general in-dispatch file_scope
extension channel; roadmap rendering/commit-staging behavior; the stale-deploy READ hazard that
`batch-orchestration-guardrails.md` lines 1712-1719 calls out as a separate, unclosed non-goal.

## Findings

### Codebase Patterns

**The shared comparator (`scripts/lib/file-scope-overlap.sh`)**:
- `whole_tree_claim_sentinel` (around line 45 of the jq heredoc) names the literal
  `"__WHOLE_TREE__"` token as a constant, consumed by both bash (`scopes_overlap()`) and
  jq-splicing (`$FILE_SCOPE_OVERLAP_JQ_DEFS`) call shapes.
- `scopes_overlap_first(own_scope; other_scope)` is the one Overlap predicate both consumers
  read. Its match clause is:
  ```
  select($na == $nb or ($nb | startswith($na + "/")) or ($na | startswith($nb + "/")))
  ```
  Because the sentinel is slashless, it can only ever satisfy the `$na == $nb` (exact-match)
  branch, and only against another literal instance of itself — this is the documented
  "inertness against real paths" property. Two tasks each declaring the literal sentinel DO
  satisfy `$na == $nb`, and today that is read as a genuine collision by both consumers.

**Consumer 1 — `orchestrate-batch-admit.sh` (in-batch admission, surface (i))**:
- Line 930: `$c_has_whole_tree_claim` — a candidate's own scope contains the sentinel — computed
  unconditionally, merged into every verdict as `whole_tree_claim: true` (informational,
  decision-neutral; this part is fine and should be preserved).
- Lines 991-1136: the general (non-self-modifying) collision-scan branch computes `$comparison_set`
  (non-terminal tasks with no `dependencies[]` edge to the candidate) and `$overlaps` (every
  `scopes_overlap_first` hit against that set), then picks `$hit` (first in-batch-or-in-flight
  overlap).
- Line 1070: `elif ($hit.ov_path == whole_tree_claim_sentinel)` — detects that `$hit` matched on
  the sentinel specifically (both sides declared it), and relabels the verdict to
  `defer_reason: "whole_tree_claim"` (lines 1091-1105) **unless** the candidate's own
  `$phase_group` is `research` or `plan` (line 1088, same phase-exemption convention
  `self_modifying` and `absent_file_scope` already use).
- Critically: **this relabeled defer still sets `decision: "defer"`**, and the `reason` string's
  "ORDERING CONSTRAINT, not an exclusion" wording (line 1103) is not backed by any mechanism that
  actually re-admits the candidate in a *later* cycle sooner than an ordinary collision would —
  it only resolves once the colliding task's `status` turns terminal (the `comparison_set` filter
  at line 995 excludes terminal tasks), which for a multi-phase task (research → plan → implement)
  can span several `/orchestrate` cycles, exactly matching the measured "cycle 1 through 4"
  deferral in the originating incident.

**Consumer 1's downstream — `orchestrate-cycle-plan.sh`**:
- Lines 2034-2086: for every `defer` verdict, a `case "$dr"` dispatches to a ledger-recording arm.
  The `whole_tree_claim)` arm (lines 2066-2073) mirrors `file_scope_collision`'s shape (records
  `collision_scope`) but — like `file_scope_collision`, `session_active`, and
  `absent_file_scope`, and unlike `self_modifying` — has **no `--allow-X` bypass**. The task stays
  excluded from `dispatch_candidates` for the cycle (the `case` block at line 2034 runs before the
  bucketing loop at line 2107; nothing downstream re-admits a deferred task within the same
  cycle). This is the exact mechanism realizing surface (i)'s measured width-1 serialization —
  the admission-time relabeling in `orchestrate-batch-admit.sh` changes only the *reported
  reason*, never the *dispatch outcome*.

**Consumer 2 — `lint-roadmap-batch-proposals.sh` (roadmap batch-proposal linting, surface (ii))**:
- Finding (a) (lines 319-402) is the "territory under-inclusion" check: a non-terminal task
  absent from an authored batch whose `file_scope` overlaps an in-batch member's `file_scope`.
  Its jq program (`FINDING_A_JQ_PROGRAM`, lines 355-376) splices in `$FILE_SCOPE_OVERLAP_JQ_DEFS`
  and calls `scopes_overlap_first($cand.file_scope; $bscope)` directly (line 369) — no
  sentinel-specific branch exists in this script at all. A header comment (lines 344-347)
  explicitly acknowledges the sentinel-vs-sentinel exact match is "the intended same-whole-tree-
  claim detection signal, not a false positive" — i.e., this script inherits exactly the same
  design-era framing as `orchestrate-batch-admit.sh`, just without ever relabeling it into
  something softer. This is why 110 of the 403 roadmap findings are sentinel self-collisions:
  every pair of non-terminal tasks that each declare a redeploy phase and are not in the same
  authored batch together produces a Finding (a) "shared file territory, batch mandatory" verdict.
- No test fixture in `test-lint-roadmap-batch-proposals.sh` currently pins sentinel-specific
  behavior for Finding (a) at all (confirmed via grep — only ordinary real-path fixtures exist),
  so there is no existing "target posture" assertion to reverse here, only new coverage to add.

**Documented design intent that must change** (confirms this is a deliberate reversal, not a
latent bug fix):
- `context/patterns/file-footprint-overlap.md` lines 57-63 ("Two DIFFERENT tasks each declaring
  the SAME reserved token DO produce an ordinary Overlap exact match against EACH OTHER... this
  is exactly the detection signal...") states, as settled prose, the exact behavior this task
  reverses.
- `context/patterns/batch-orchestration-guardrails.md`'s "Whole-Tree Regeneration Hazard: The
  Sixth Admission Dimension" section (lines 1643-1719), especially lines 1695-1703, documents the
  `whole_tree_claim` defer as the chosen mechanism and explicitly frames the resulting same-claim
  exact match as the intended signal for serialization, not an ordering-only advisory.
- `docs/architecture/batch-admit-schema.md` documents the full `whole_tree_claim` defer shape
  (lines 143-151, 222-239, 311-335, 410-417) as a first-class `defer_reason` value under the
  current `$schema: "orchestrate-batch-admit-v7"`. Per this codebase's own established
  versioning convention (`batch-admit-schema.md`'s "Version History" section, e.g. the v1→v2
  entry explaining why a `defer_reason` semantics change is a version bump, not an additive
  field), retiring/changing what `whole_tree_claim` means on the wire is itself a version-bump
  event (e.g. v7 → v8) under this project's own prior practice — and the `$schema` string literal
  is a schema-version axis explicitly exempted by `rules/no-record-versioning-in-deliverables.md`
  from the record-versioning prohibition, so an `-v8` bump is permitted vocabulary in the
  implementation, not merely tolerated.

**Existing fixture coverage (`test-orchestrate-batch-admit.sh`, lines 507-685)** — four
sentinel-specific fixtures already exist, written during the phase that introduced
`whole_tree_claim`:
- `WHOLE-TREE-CODISPATCH` (lines 524-574): two in-batch candidates with disjoint real scope, both
  carrying the sentinel. **Current target-posture assertion is `decision: "defer"` for the
  higher-numbered candidate with `defer_reason: "whole_tree_claim"`.** This is the one fixture
  this task's fix must flip to `decision: "admit"` for BOTH candidates.
- `WHOLE-TREE-PHASE-EXEMPT` (lines 580-610): same shape, but the higher-numbered candidate is
  `--phase-map`-ped to `plan`. Asserts `decision: "admit"` with `whole_tree_claim: true` already.
  Stays valid after the fix (the phase-exemption branch admits regardless; with the library fix
  the non-exempt branch will also admit, so this fixture's assertions do not need to change,
  though its "target posture" framing becomes moot/redundant — worth a comment update, not a
  logic change).
- `WHOLE-TREE-NO-SENTINEL` (lines 616-645): control case, no sentinel declared, both admit.
  Unaffected by the fix; stays green as-is.
- `WHOLE-TREE-INERT-PATH` (lines 651-681): sentinel-vs-real-path inertness. Unaffected by the fix
  (this report's recommended change touches only the sentinel-vs-sentinel branch of the match
  clause); stays green as-is.
- **No existing fixture pins the deliverable's explicitly required regression** — two
  sentinel-declaring tasks whose *other*, concrete `file_scope` entries also genuinely intersect.
  This must be added new.

**Other sentinel touchpoints confirmed OUT of this fix's scope** (verified by reading each, not
merely grep-counted): `plan-file-scope-harvest.sh`, `git-commit-scoped.sh`,
`git-commit-phase.sh`, `validate-artifact.sh`, and `source-store-path-lib.sh` all reference the
sentinel only as a recognized non-path placeholder for unrelated checks (deployed-tree-path
warnings, Containment-side glob/placeholder classification) — none of them call
`scopes_overlap_first` or depend on its sentinel-vs-sentinel exact-match behavior.
`orchestrate-predispatch-review.sh` references `whole_tree_claim` only by analogy (an
"own-scope-only, decision-neutral advisory" computation style it imitates for an unrelated
field), not by invoking the same predicate. `orchestrate-cycle-plan.sh`'s `whole_tree_claim)` case
arm (in scope, discussed above) is purely a ledger-recording consequence of
`orchestrate-batch-admit.sh`'s own verdict and requires no independent logic change beyond what
follows automatically once that verdict stops being `defer`.

### External Resources

Not applicable — this is a self-contained internal-tooling defect with no external library or
API surface involved.

## Recommendations

1. **Fix at the shared library, not at either consumer** (confirms the dispatch's own framing).
   In `scripts/lib/file-scope-overlap.sh`'s `scopes_overlap_first()`, exclude the literal
   sentinel-vs-sentinel case from the match clause, e.g.:
   ```
   select(
     ($na == $nb or ($nb | startswith($na + "/")) or ($na | startswith($nb + "/")))
     and not ($na == whole_tree_claim_sentinel and $nb == whole_tree_claim_sentinel)
   ) | $pb
   ```
   This is additive-restrictive (narrows one specific case out of the existing match clause) and
   leaves every other comparison shape — sentinel-vs-concrete (already inert, unaffected),
   concrete-vs-concrete (untouched clause structure) — bit-for-bit identical to today, directly
   satisfying the deliverable's "leaving sentinel-versus-concrete-path and
   concrete-path-versus-concrete-path semantics exactly as they are today" requirement. Because
   `scopes_overlap_first` is the one predicate both `orchestrate-batch-admit.sh` and
   `lint-roadmap-batch-proposals.sh` call (directly or via the spliced `$FILE_SCOPE_OVERLAP_JQ_DEFS`
   text), this one edit reaches both surfaces without a second, parallel edit in either consumer's
   own jq program.

2. **Add a second, purely-informational predicate for the ordering-relation signal**, e.g.
   `whole_tree_claim_pair(own_scope; other_scope)`, returning true iff *both* arrays contain the
   literal sentinel — independent of concrete-path matching. This lets
   `orchestrate-batch-admit.sh` keep surfacing "this candidate and another non-terminal task both
   claim whole-tree regeneration" as a non-blocking advisory field (parallel in shape to the
   existing `dirty_scope_advisory`/`idle_overlap_advisory` fields: present on every verdict,
   admit or defer, never itself changing `decision`), rather than silently losing the signal.
   The deliverable's phrase "yield an ORDERING relation rather than a blocking overlap" reads
   most naturally as: keep telling the operator/ledger that the two tasks' redeploys should be
   sequenced (which `deploy-headless.sh`'s own `specs/.deploy-lock/` mutex already enforces
   mechanically, per `batch-orchestration-guardrails.md` line 1267, independent of batch
   admission), but stop using batch admission as the enforcement point.

3. **Retire `orchestrate-batch-admit.sh`'s `elif ($hit.ov_path == whole_tree_claim_sentinel)`
   branch** (lines 1070-1105): after recommendation 1 lands, `$hit` can never carry the sentinel
   value again (scopes_overlap_first will never return it), so this branch becomes dead code.
   Remove it rather than leave an unreachable branch; replace its informational half with
   recommendation 2's advisory, computed alongside the existing `$whole_tree_claim_frag` (around
   line 930) so it is available uniformly across both the self-modifying and non-self-modifying
   branches, not only inside the collision-scan `else` arm where `$hit` lived.

4. **`orchestrate-cycle-plan.sh`'s `whole_tree_claim)` case arm** (lines 2066-2073) needs no
   independent logic change — it only fires when `orchestrate-batch-admit.sh` emits
   `defer_reason: "whole_tree_claim"`, which recommendation 3 stops emitting. Leave the arm in
   place defensively (it already has the loud-unrecognized-value fallback pattern this codebase
   favors for forward compatibility) or remove it as dead code — a judgment call for the
   planning phase, not a correctness requirement either way.

5. **Fixture updates, matching the deliverable's explicit three-shape-plus-regression
   requirement**:
   - Flip `WHOLE-TREE-CODISPATCH` (`test-orchestrate-batch-admit.sh` lines 524-574) to assert
     `decision: "admit"` for **both** `$NUM_WT1` and `$NUM_WT2`, each still carrying
     `whole_tree_claim: true`, and (if recommendation 2 is adopted) the new ordering-advisory
     field naming the peer. Update the surrounding prose comment (lines 525-546) to describe the
     new target posture instead of the old one — this file already has a documented convention
     of narrating target-posture-vs-today's-behavior inline, so the convention itself does not
     need to change, only the content.
   - `WHOLE-TREE-PHASE-EXEMPT` and `WHOLE-TREE-NO-SENTINEL` and `WHOLE-TREE-INERT-PATH`: no
     assertion changes required; re-verify green after the fix (they exercise shapes 2 and 3 of
     the deliverable's "three comparison shapes" — sentinel-vs-concrete and the no-sentinel
     control — already).
   - **New fixture** (the deliverable's explicit regression, not present today): two
     sentinel-declaring, in-batch candidates whose *other* declared `file_scope` entries also
     genuinely intersect (e.g. both declare `scope/shared` alongside `__WHOLE_TREE__`). Assert
     the higher-numbered candidate still defers, with `defer_reason: "file_scope_collision"` and
     `overlapping_path: "scope/shared"` (never `claim_sentinel`) — proving the fix narrows only
     the sentinel-vs-sentinel case and a genuine concrete-path collision between two
     sentinel-carrying tasks is unaffected.
   - **New fixture(s)** in `test-lint-roadmap-batch-proposals.sh`: (a) two non-terminal tasks,
     one absent from an authored batch, both declaring only the sentinel (no real overlap) —
     assert Finding (a) does NOT fire; (b) the same shape but with an additional genuinely
     overlapping concrete path — assert Finding (a) DOES fire, naming the concrete path.

6. **Documentation updates** (three files, all already identified above under Findings):
   `context/patterns/file-footprint-overlap.md`'s "Reserved sentinels" section (the lines 57-63
   claim needs to become "two tasks declaring the same sentinel do NOT produce an Overlap match
   against each other; see the dedicated `whole_tree_claim_pair` ordering predicate instead"),
   `context/patterns/batch-orchestration-guardrails.md`'s "Whole-Tree Regeneration Hazard"
   section (lines 1686-1703 describe the now-superseded mechanism), and
   `docs/architecture/batch-admit-schema.md` (the `whole_tree_claim` defer-shape rows and the
   "NEW in v7" relabeling-precedence paragraph, lines 143-417, plus a new Version History entry
   for the schema bump this change likely warrants per the project's own established
   versioning-is-a-bump convention for `defer_reason` semantics changes).

## Decisions

- **Fix locus confirmed as the shared library** (`scripts/lib/file-scope-overlap.sh`), not a
  parallel edit in each consumer — directly verified by reading both consumers' call sites, not
  merely asserted from the dispatch's own framing.
- **This is a design reversal, not a latent-bug fix** — the current sentinel-vs-sentinel
  exact-match behavior is deliberately documented in three separate places (a pattern file, a
  guardrails doc, and the schema doc) and pinned by an existing TDD target-posture fixture
  (`WHOLE-TREE-CODISPATCH`). The planning phase should treat updating those three docs and
  flipping that one fixture's assertions as in-scope deliverables, not optional cleanup.
- **No fix is needed in `lint-roadmap-batch-proposals.sh`'s own jq program** — it inherits the
  library fix for free via its existing `$FILE_SCOPE_OVERLAP_JQ_DEFS` splice; only new fixture
  coverage is needed there, confirming the dispatch's "the fix is NOT two parallel edits" claim
  as literally true for this consumer (zero production-code change), while
  `orchestrate-batch-admit.sh` does need its own dead-branch removal and (optionally) a new
  advisory field, since it has consumer-specific logic layered on top of the shared predicate.

## Risks & Mitigations

- **Risk**: deleting the `elif ($hit.ov_path == whole_tree_claim_sentinel)` branch outright,
  without first confirming it is truly unreachable post-fix, could silently change behavior if
  some other code path still produces a sentinel-valued `$hit`. **Mitigation**: the new
  regression fixture (recommendation 5, third bullet) exercises exactly this — a genuine
  concrete-path collision between two sentinel-carrying tasks — and the existing
  `WHOLE-TREE-INERT-PATH` fixture already pins that sentinel-vs-real-path never matches; between
  the two, every path that could produce a sentinel-valued `$hit` is covered by a fixture that
  must stay green.
- **Risk**: schema consumers outside this codebase (if any exist) that branch on
  `defer_reason == "whole_tree_claim"` would silently stop receiving that value. **Mitigation**:
  grep confirms the only consumer is `orchestrate-cycle-plan.sh`'s own ledger-recording case arm,
  already identified and addressed in recommendation 4; no external consumer was found.
  `docs/architecture/batch-admit-schema.md`'s versioning convention (bump `$schema` on a
  `defer_reason` semantics change) exists precisely to make this kind of change loud rather than
  silent, so following that convention (recommendation 6) is itself the mitigation, not an
  optional extra.
- **Risk**: the roadmap-side fixture gap (no existing sentinel-specific Finding (a) test) means
  there is no "before" baseline proving the 110-finding reduction actually occurs for this
  specific run; the dispatch's 110-of-403 figure is drawn from the *originating* run's measured
  output, not from a reproducible fixture in this repository. **Mitigation**: the new
  fixtures recommended above (recommendation 5, roadmap bullets) establish a reproducible,
  minimal regression test of the same shape, which is the available substitute for re-running
  the original 403-finding scan.

## Context Extension Recommendations

- **Topic**: none — the relevant design is already thoroughly documented in
  `context/patterns/file-footprint-overlap.md` and `context/patterns/batch-orchestration-
  guardrails.md`; this task's implementation phase should UPDATE those existing files (per
  Recommendation 6) rather than create new context files.

## Appendix

- Search queries / commands used: `grep -n "whole_tree_claim_sentinel\|WHOLE_TREE\|scopes_overlap_first\|sentinel"` across `orchestrate-batch-admit.sh` and `lint-roadmap-batch-proposals.sh`; `grep -rln "__WHOLE_TREE__\|whole_tree_claim_sentinel\|whole_tree_claim"` across `agent-system/extensions/core/`; targeted `Read` of `scripts/lib/file-scope-overlap.sh` (full file), `orchestrate-batch-admit.sh` (lines 900-1136), `lint-roadmap-batch-proposals.sh` (lines 300-400), `orchestrate-cycle-plan.sh` (lines 2020-2110), `test-orchestrate-batch-admit.sh` (lines 500-690), `test-lint-roadmap-batch-proposals.sh` (grep only), `file-footprint-overlap.md` (lines 30-99), `batch-orchestration-guardrails.md` (lines 1640-1719), `batch-admit-schema.md` (grep + targeted lines).
- Key files/line references are inlined throughout Findings and Recommendations above rather
  than repeated here.
