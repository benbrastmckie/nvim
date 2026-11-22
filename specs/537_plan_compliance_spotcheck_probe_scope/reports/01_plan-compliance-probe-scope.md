# Research Report: Task #537

**Task**: 537 - lean-implementation-agent's plan-compliance spot-check does not search
plan-pinned evidence-probe locations outside `lean-src-roots.sh`'s roots
**Started**: 2026-11-22T00:00:00Z
**Completed**: 2026-11-22T00:00:00Z
**Effort**: small (one script, ~40-60 line change, plus a test-fixture addition)
**Dependencies**: None (purely additive; no change to callers)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/lean/agents/lean-implementation-agent.md`,
  `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh`,
  `agent-system/extensions/lean/scripts/lean-src-roots.sh`,
  `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`,
  `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh`,
  `agent-system/extensions/core/context/formats/plan-format.md`,
  `agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh`,
  `agent-system/extensions/lean/manifest.json`
- Originating issue: `specs/archive/775_residue_index_factorization_lemma/issues.jsonl`
  entry `iss_1791842368633_NJQxnS` (BimodalLogic repository, read cross-repo per this task's
  migration provenance)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The bug is real and precisely as described: `lean-plan-compliance-check.sh`'s per-name
  declaration lookup (`find_decl_files`, `find_field_files`, used both for the main Goals
  loop and for the `replacement_targets` integrity sweep) greps only
  `"${lean_roots[@]}"` — the array `lean-src-roots.sh` resolves — and this repository's
  evidence-probe convention deliberately pins Goal declarations in `specs/evidence/**/*.lean`,
  outside every resolved root. A plan following that convention gets a false `[MISSING]`
  for every Goal, forcing `compliance_check: failed` -> `status: partial` unless an
  implementer manually overrides the heuristic's verdict, which is exactly what happened on
  the originating task.
- A reusable, already-deployed primitive already does most of the work needed to fix this
  without inventing new plan-parsing: `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh`
  harvests the deduplicated union of every phase's `**Files to modify**:` paths from a plan
  file into a JSON array, with existing deployed-tree and unexpanded-variable refusals
  already built in. The lean extension already depends on the core extension and already
  calls other core scripts (e.g. `git-commit-scoped.sh`) from its own agent/script files, so
  a cross-extension call from `lean-plan-compliance-check.sh` to this harvester is
  precedented, not a new architectural seam.
- Recommended fix (Decision D1 below): inside `lean-plan-compliance-check.sh` only — no
  change needed to `lean-implementation-agent.md`'s step 5 invocation, to `lean-src-roots.sh`,
  or to steps 0-4 of the Final Verification Stage — compute a `extra_paths` array from (a)
  the plan's own harvested `Files to modify` list, filtered to existing `*.lean` files, and
  (b) the Challenge snapshot manifest's `challenge_path` (if `specs/{task_dir}/challenge/manifest.json`
  exists), then widen only the two functions that do per-name declaration/field lookup
  (`find_decl_files`, `find_field_files`) to search `"${lean_roots[@]}" "${extra_paths[@]}"`.
  `find_module_files` (directory-rooted module-path resolution) and the four named
  roots-only consumers (sorry census, axiom count, vacuity check, build) are left untouched,
  matching the dispatch's explicit scope.
- A concurrent sibling task (537's own territory block names #504) is scoped to edit the
  exact same two files (`lean-plan-compliance-check.sh` and its test suite) this cycle, for
  an unrelated defect (over-broad Goals-prose backtick harvest). The two changes touch
  different regions of the same script and should not conflict in substance, but both land
  in the same implementation window — see Risks & Mitigations.
- An adjacent, structurally identical blind spot exists one step further down the same
  stage (step 6's advisory comparator gate, Preflight 4's inline
  `grep -rl ... "${lean_roots[@]}"` resolving `comparator_solution_module`) but is explicitly
  out of this dispatch's stated scope (opt-in, advisory, and not named among the "leave
  unchanged" list, but also not named among the things to widen) — flagged as a follow-up
  candidate, not fixed here.

## Context & Scope

Researched: how `lean-implementation-agent.md`'s Final Verification Stage step 5 ("Plan
compliance spot-check") and its extracted script `lean-plan-compliance-check.sh` resolve the
search scope used to confirm a plan's `**Goals**` identifiers are present in the
implementation, why that scope misses the evidence-probe convention (`specs/evidence/**/*.lean`),
and what the minimal, scope-respecting fix looks like. Excluded, per the dispatch's explicit
boundary: step 0's resolve-or-abort posture, and the four roots-only consumers named
elsewhere in the stage (sorry census, axiom/vacuity checks, build).

## Findings

### Codebase Patterns

**The resolved-roots mechanism (step 0).** `lean-src-roots.sh` resolves this repo's Lean
source roots from `lakefile.toml`/`lakefile.lean`/`LEAN_SRC_ROOTS`, in that precedence order,
and fails loudly (named exit codes 64-69) rather than silently reporting a clean scan over
nothing. `lean-implementation-agent.md` step 0 captures this into a bash array `lean_roots`
and aborts the whole Final Verification Stage if the resolve itself fails. Every later step
(1-5, and step 6's comparator gate) consumes `"${lean_roots[@]}"` — none of them names a
literal root directory inline. This is deliberate, documented design (the script's own header:
"no taught snippet has to hardcode a literal directory name that only happens to be correct in
one consuming repo").

**The spot-check script's internal structure.** `lean-plan-compliance-check.sh` takes
`<plan_file> <lean_root> [<lean_root> ...]` and:
1. Harvests Goal names, preferring a `## Lean Challenge Statements` fenced-code-block
   declaration scan over the legacy `**Goals**`-prose backtick harvest (whichever yields
   names).
2. For each harvested name, in order: `find_decl_files` (grep for a top-level declaration
   line across `"${lean_roots[@]}"`, with a namespace-qualified fallback for dotted names) ->
   `find_field_files` (structure/class field lookup, same roots) -> `find_module_files`
   (module-PATH resolution: `<root>/<A/B/C>.lean` under one of `"${lean_roots[@]}"`, which is
   inherently directory-rooted logic, not a flat grep).
3. (must-exist polarity only) a `replacement_targets` integrity sweep that also calls
   `find_decl_files "$new_name"` to locate the new declaration's own file and grep its body
   for a forbidden delegation to the name it is meant to replace.

Because `find_decl_files` and `find_field_files` are the two functions the replacement-target
sweep already reuses, widening those two functions' search scope automatically widens the
sweep too — no separate code path is needed to satisfy "apply the same widened scope to the
replacement-target sub-check."

**The evidence-probe convention and the originating failure.** This repository's Lean
projects pin certain plans' Goal declarations under `specs/evidence/**/*.lean` — a directory
that is never one of `lean-src-roots.sh`'s resolved roots (confirmed against the originating
task's own `.return-meta.json`, which records both the literal-scope reading, 8/8 MISSING,
and the probe-scoped reading, 8/8 present, and states the implementer set `compliance_check`
from the probe-scoped reading by hand). The plan in question's phase-level `**Files to
modify**:` blocks name exactly this probe path repeatedly
(`specs/evidence/seam-gluing-ray-product/ladder-residue-index-refutation.lean`), confirming
that the information needed to widen the scope already lives in the plan the script already
receives as `$plan_file` — nothing new needs to be threaded through the call site.

**A reusable harvester already exists for "the plan's own Files-to-modify list."**
`agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` (deployed at
`.claude/scripts/plan-file-scope-harvest.sh`) parses every phase's `**Files to modify**:`
block in a plan file and emits a deduplicated, sorted JSON array of path strings on stdout,
exit 0 even when the result is `[]` (never signals "nothing harvested" through the exit
code). It already:
- Tolerates both bold-punctuation forms (`**Files to modify**:` / `**Files to modify:**`) and
  the list-item-wrapped header rendering, matching `plan-format.md`'s documented tolerance.
- Refuses (with a loud `>&2` warning, not a hard failure) any harvested entry that is a
  deployed-tree path (`.claude/**`) or an unexpanded shell-variable shape — exactly the kind
  of noise a naive re-implementation inside `lean-plan-compliance-check.sh` would have to
  reinvent.
- Is already called cross-extension today only by core-extension consumers
  (`orchestrator-postflight.sh`, `orchestrate-batch-admit.sh`, `reconcile-task-status.sh`,
  `validate-artifact.sh`, `backfill-file-scope.sh`, `update-task-status.sh`,
  `skill-base.sh`, `planner-agent.md`, `skill-reviser/SKILL.md`) — no lean-extension script
  calls it yet, but the lean extension's own `manifest.json` already declares `core` as a
  dependency, and lean-extension scripts/agents already call other core scripts directly
  (e.g. `.claude/scripts/git-commit-scoped.sh` is invoked from lean agent files). A new call
  from `lean-plan-compliance-check.sh` into `.claude/scripts/plan-file-scope-harvest.sh` is
  therefore an unremarkable, precedented cross-extension dependency, not a new architectural
  seam.

**The Challenge snapshot manifest as the second scope-widening source.**
`lean-challenge-snapshot.sh` writes `specs/{padded_num}_{project_name}/challenge/manifest.json`
with (among other fields) `project_root` and `challenge_path` (the pinned Challenge module's
path, relative to `project_root`). Step 6's comparator gate already reads this manifest and
joins `project_root` + `challenge_path` to retrieve the pinned Challenge content at a given
commit — confirming both fields' exact shape and join convention. `lean-plan-compliance-check.sh`
can derive the manifest's expected location purely from its own `$plan_file` argument: a plan
file always lives at `specs/{task_dir}/plans/*.md`, so `task_dir="$(dirname "$(dirname
"$plan_file")")"` reproduces exactly the same `specs/{padded_num}_{project_name}` directory
step 6 already builds from separate `padded_num`/`project_name` shell variables — no new
argument needs to be threaded into the step-5 call site for this either.

**Call-site independence.** `lean-implementation-agent.md`'s step 5 invokes the script as
`bash .claude/scripts/lean-plan-compliance-check.sh "$plan_file" "${lean_roots[@]}"` — both
pieces of information the fix needs (`$plan_file`, from which both the harvester call and the
manifest path derive) are already passed. **No change to the agent file's step 5 code block,
to step 0, or to steps 1-4 is required** — this is a self-contained change to
`lean-plan-compliance-check.sh` alone.

### External Resources

Not applicable — this is a pure codebase-internal contract fix; no external documentation
governs this repository's own plan-compliance heuristic or evidence-probe convention.

## Decisions

- **D1 (scope-widening mechanism)**: widen `find_decl_files` and `find_field_files`'s search
  target from `"${lean_roots[@]}"` to a new `search_roots=("${lean_roots[@]}"
  "${extra_paths[@]}")` array, where `extra_paths` is the deduplicated union of (a) every
  `*.lean` entry in the plan's harvested `Files to modify` list (via
  `.claude/scripts/plan-file-scope-harvest.sh "$plan_file"`) that exists on disk, and (b) the
  Challenge manifest's `project_root`/`challenge_path` join (if
  `specs/{task_dir}/challenge/manifest.json` exists and the joined path exists on disk).
  `find_module_files` is deliberately NOT widened — its logic is inherently rooted in treating
  each array member as a directory (`$(basename "$root")`, `$root/$rel`), so splicing
  individual files into the same array would silently miscompute paths for every entry after
  the first non-directory member. A Goal naming a bare module path (rather than a
  declaration or field) inside a probe file is an edge case the dispatch does not name and is
  left for a future, separately-scoped widening if it is ever observed in practice.
- **D2 (no caller-side change)**: leave `lean-implementation-agent.md`'s step 5 bash block,
  step 0's resolve-or-abort posture, and steps 1-4 (sorry census, vacuous-definition check,
  axiom count, build) completely untouched. The widening is entirely internal to
  `lean-plan-compliance-check.sh`, since it already receives everything it needs
  (`$plan_file`) as an existing argument.
- **D3 (dependency on an existing harvester, not a new parser)**: reuse
  `plan-file-scope-harvest.sh` rather than hand-rolling a second `**Files to modify**:` parser
  inside `lean-plan-compliance-check.sh`. `plan-format.md`'s own "Consumers of this field"
  section already tracks every independent reader of this heading; adding a fifth
  independent, divergent implementation (this script would be the one consumer that both
  depends on list-item shape AND lives in a different extension) multiplies the drift
  surface the heading-stability note already warns about. The one new risk this reuse
  introduces — a `jq` hard dependency the harvester already has and
  `lean-plan-compliance-check.sh` currently lacks — should degrade **fail-soft** inside
  `lean-plan-compliance-check.sh` (skip the Files-to-modify half of the widening, proceed with
  `lean_roots`-only behavior, exactly today's behavior) rather than aborting the whole
  compliance check, since `jq`'s absence is orthogonal to whether the roots-only check itself
  can still run.
- **D4 (manifest optional, not required)**: the Challenge-manifest half of the widening is
  consulted only when the manifest file exists; its absence is not an error (most plans have
  no Challenge snapshot and must not be penalized for it) — mirrors step 6's own `[ ! -f
  "$manifest_path" ]` -> `challenge_missing` preflight-skip posture, just without failing
  anything, since compliance-check is not opt-in gated the way the comparator is.
- **D5 (documentation obligation)**: the fix must add a new "Changes beyond the original
  (behaviour-preserving) extraction" bullet to `lean-plan-compliance-check.sh`'s own header
  comment (which already documents GOAL POLARITY, RESERVED-KEYWORD DENYLIST, COLON-OPTIONAL
  GOALS RANGE, DECLARATION-KIND AND DOTTED-NAME WIDENING, and CHALLENGE-STATEMENTS-PREFERRED
  HARVEST as the prior narrowings/widenings in the same established format) — this is the
  sixth such change and the header's own convention is to name and justify each one inline,
  not to let behavior drift undocumented from the header's own "Changes beyond the original"
  inventory.

## Recommendations

1. In `lean-plan-compliance-check.sh`, immediately before the `find_decl_files`/
   `find_field_files`/`find_module_files` function definitions (so the new array is in scope
   for all three, even though only two are widened), add:
   - A `extra_paths=()` accumulator.
   - A fail-soft call to `.claude/scripts/plan-file-scope-harvest.sh "$plan_file"` (guarded by
     `command -v jq` the same way the script's existing `jq` consumers elsewhere in this
     codebase guard it), filtering the JSON array to entries matching `\.lean$` and to paths
     that `[ -f ]` on disk.
   - A `task_dir="$(dirname "$(dirname "$plan_file")")"` derivation and a conditional read of
     `specs/{task_dir}/challenge/manifest.json`'s `project_root` + `challenge_path` fields
     (via `jq -r`), appended to `extra_paths` only if the joined path exists on disk.
   - Deduplicate `extra_paths`.
2. Change the two `grep -r...  "${lean_roots[@]}"` call sites inside `find_decl_files` (both
   the direct-spelling grep and the dotted-name namespace-fallback grep) and the one inside
   `find_field_files` to `"${lean_roots[@]}" "${extra_paths[@]}"` (introduce
   `search_roots=("${lean_roots[@]}" "${extra_paths[@]}")` once and reuse it at both call
   sites, rather than inlining the concatenation twice). Leave `find_module_files` iterating
   `"${lean_roots[@]}"` only, per Decision D1.
3. Leave the `replacement_targets` integrity sweep's code completely unchanged — it already
   calls `find_decl_files`, so it inherits the widened scope automatically once step 2 lands.
4. Add the header-comment bullet from Decision D5, following the existing "Changes beyond the
   original" section's established format (name, scope, and the false-positive/negative class
   it removes or avoids).
5. Extend `test-lean-plan-compliance-check.sh` (not replace existing cases) with at minimum:
   - A case whose plan's Goals name a declaration that exists ONLY in a file the plan's own
     `**Files to modify**:` block names, outside the fixture's `$ROOT` passed as `lean_root` —
     expect `passed`, `[OK]` (regression-reproduces the originating `iss_1791842368633_NJQxnS`
     symptom, inverted to the fixed outcome).
   - A case whose plan names a declaration that exists ONLY at a path recorded in a synthetic
     `challenge/manifest.json` next to the plan (not in `Files to modify` at all) — expect
     `passed`, `[OK]`, exercising the manifest-only widening path independently of the
     Files-to-modify path.
   - A case confirming the `replacement_targets` sweep still fires an `[INTEGRITY FAIL]` when
     the delegation lives inside a widened (probe) file rather than inside `$ROOT`.
   - A case with `jq` and/or the harvester script made unavailable (e.g. via `PATH`
     manipulation in the test, mirroring how other suites in this codebase simulate a missing
     dependency) confirming today's `lean_roots`-only behavior is preserved as the fail-soft
     fallback (Decision D3).
6. Do not touch step 6's comparator-gate Preflight 4 inline grep in this task — see Risks &
   Mitigations for why this is flagged rather than silently folded in.

## Risks & Mitigations

- **Risk**: a plan's `Files to modify` list could, in principle, name a file that happens to
  contain an unrelated, same-named declaration that the probe convention never intended to be
  checked against (a false `[OK]` masking a genuinely missing declaration in the *intended*
  probe file). **Mitigation**: this risk is bounded by construction — `extra_paths` only ever
  contains paths the PLAN ITSELF already committed to touching (either via its own
  authored `Files to modify` block or via the Challenge-snapshot it itself created), never an
  arbitrary repository-wide widening. A stray same-named declaration inside a file the plan
  already declared it is modifying is a pre-existing authoring risk this task does not create
  or worsen.
- **Risk**: territory overlap with concurrent sibling task #504, whose own file_scope names
  the identical two files this task's recommendation touches
  (`agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh` and
  `agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh`), for an
  unrelated defect (over-broad Goals-prose backtick harvest — narrowing WHICH names get
  harvested, vs. this task's WHERE harvested names get searched). **Mitigation**: the two
  changes land in different functions/regions of the same files (504's touches the
  `goal_names_raw`/harvest-source logic near the top of the script; 537's touches
  `find_decl_files`/`find_field_files` and a new pre-function `extra_paths` block, plus a
  distinct header-comment bullet) and should not textually conflict, but whichever of the two
  tasks reaches its implement phase second in this same orchestrate cycle MUST re-read both
  files immediately before editing, per this dispatch's own territory `concurrency_note`
  (re-read-before-edit, commit only its own hunks, treat a foreign in-flight commit as a
  stop-and-report condition, not noise).
- **Risk**: step 6's comparator-gate Preflight 4 (`comparator_solution_module` resolution) has
  the structurally identical blind spot — it is a separate inline `grep -rl ...
  "${lean_roots[@]}"`, not a call into `find_decl_files`, so widening `find_decl_files` does
  NOT fix it. **Mitigation / scope note**: the dispatch's own enumerated "leave unchanged"
  list names four specific roots-only consumers (sorry census, axiom count, vacuity check,
  build) but is silent on the comparator gate, which is opt-in/advisory and was not named
  either way. This report deliberately does not resolve that silence by fixing it anyway —
  doing so would exceed the stated deliverable ("apply the same widened scope to the
  replacement-target sub-check", naming exactly one additional sub-check, not the comparator)
  — and instead surfaces it as a candidate follow-up task: a probe-pinned plan that also opts
  into `--compare` would still hit `comparator_solution_module_unresolved` even after this
  task's fix lands.
- **Risk**: introducing a `jq` dependency (via the harvester call and the manifest read) into
  a script that currently has none. **Mitigation**: Decision D3's fail-soft posture — absence
  of `jq` degrades to today's `lean_roots`-only behavior, never to a hard script failure —
  keeps this additive rather than a new hard requirement. (Note: `jq` is already a hard
  dependency of `plan-file-scope-harvest.sh` itself and of several other scripts this same
  agent file's step 6 relies on, so in practice an environment running this agent already has
  it; the fail-soft guard is a defensive floor, not an expected-to-trigger path.)

## Context Extension Recommendations

- **Topic**: the evidence-probe convention (`specs/evidence/**/*.lean`) and its relationship
  to `lean-src-roots.sh`'s resolved roots.
- **Gap**: no `context/project/lean4/**` file documents, in one place, that this convention
  exists, why it deliberately sits outside the resolved source roots, or which verification
  tooling is probe-scope-aware (after this task's fix: `lean-plan-compliance-check.sh`'s
  widened scope) versus which remains deliberately roots-only (sorry census, axiom/vacuity
  checks, build, and — per the Risks section above — the comparator gate's Preflight 4).
- **Recommendation**: add a short domain note (or extend an existing one, e.g.
  `context/project/lean4/domain/challenge-snapshot.md`, which already documents adjacent
  Challenge-snapshot machinery) naming the probe convention, the roots-vs-probe-scope split
  across every Final Verification Stage consumer, and a pointer to this task's fix as the
  first consumer that bridges the two. This is a documentation gap, not a code defect, and is
  offered as a candidate follow-up rather than something this task's own deliverable commits
  to writing.

## Appendix

### Search queries / commands used

- `grep -n "Plan compliance spot-check\|Final Verification" agent-system/extensions/lean/agents/lean-implementation-agent.md`
- `cat agent-system/extensions/lean/scripts/lean-src-roots.sh`
- `cat agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh`
- `cat agent-system/extensions/core/scripts/plan-file-scope-harvest.sh`
- `grep -n "Files to modify\|Files-to-modify" agent-system/extensions/core/context/formats/plan-format.md`
- `grep -rl "iss_1791842368633_NJQxnS" /home/benjamin/Projects/BimodalLogic/specs/*/issues.jsonl`
  and the full `jq`-reproducible entry from `specs/archive/775_residue_index_factorization_lemma/issues.jsonl`
  in that cross-repo location
- `grep -n "Files-to-modify\|Goals\*\*\|Challenge\|evidence/" specs/archive/775_residue_index_factorization_lemma/plans/01_residue-index-parameter-refutation.md`
  (BimodalLogic repository, read cross-repo per this task's migration provenance)
- `grep -n "challenge_path\|project_root" agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`
- `grep -rln "plan-file-scope-harvest.sh" agent-system/ .claude/` (existing-caller census)
- `jq -r '.dependencies' agent-system/extensions/lean/manifest.json` (confirmed `core` is a
  declared dependency)
- `jq -r '.active_projects[] | select(.project_number==504) | .description' specs/state.json`
  (concurrent sibling task's own scope, for the territory-overlap risk)

### References

- `agent-system/extensions/lean/agents/lean-implementation-agent.md` (Final Verification
  Stage, steps 0 and 5; step 6 comparator gate Preflight 4)
- `agent-system/extensions/lean/scripts/lean-src-roots.sh`
- `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh`
- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`
- `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh`
- `agent-system/extensions/core/context/formats/plan-format.md` ("Files to modify" field
  definition and "Consumers of this field" subsection)
- `agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh`
- `agent-system/extensions/lean/manifest.json`
- Originating issue: `iss_1791842368633_NJQxnS` in
  `/home/benjamin/Projects/BimodalLogic/specs/archive/775_residue_index_factorization_lemma/issues.jsonl`
- Concurrent sibling scope: task #504 description in `specs/state.json`
