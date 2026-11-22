# Implementation Plan: Task #537

- **Task**: 537 - lean-implementation-agent's plan-compliance spot-check does not search
  plan-pinned evidence-probe locations outside `lean-src-roots.sh`'s roots
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/537_plan_compliance_spotcheck_probe_scope/reports/01_plan-compliance-probe-scope.md
- **Artifacts**: plans/01_probe-scoped-compliance-grep.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`lean-plan-compliance-check.sh` resolves every Goal name by grepping only the Lean source roots
`lean-src-roots.sh` returns, so a plan following this repository's evidence-probe convention —
Goals pinned in `specs/evidence/**/*.lean`, deliberately outside those roots — is reported
wholly `[MISSING]` and forced to `COMPLIANCE_CHECK: failed`, which the caller's own rule turns
into `status: partial`. This plan widens the search scope used by the two per-name lookup
functions (`find_decl_files`, `find_field_files`, which the `replacement_targets` integrity sweep
already reuses) from the resolved roots alone to the resolved roots **unioned with** paths the
plan itself declares — its own harvested `Files to modify` list plus the Challenge snapshot
manifest's pinned module — leaving `find_module_files`, step 0's resolve-or-abort posture, and
every other roots-only consumer of the Final Verification Stage untouched. Done when a
probe-scoped Goal resolves `[OK]`, an in-tree Goal still resolves exactly as it does today, the
suite pins both readings plus the fail-soft fallback, and the deployed tree carries the change.

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class claim the dispatch description carries was checked against live state before
this plan was written. Results, stated even where they only confirm the description:

- **"greps the plan's Goal names ONLY under the roots returned by `lean-src-roots.sh`" —
  CONFIRMED live.** Three per-name grep call sites consume `"${lean_roots[@]}"`:
  `lean-plan-compliance-check.sh:256` and `:269` (`find_decl_files`'s verbatim grep and its
  dotted-name namespace fallback) and `:294` (`find_field_files`'s bare-name branch).
  `find_module_files` consumes the array a fourth time at `:307`, as a directory loop.
- **The defect itself — CONFIRMED live by synthetic reproduction at plan time**, not inferred
  from the description. A fixture with `theorem probeOnly` declared only in
  `specs/evidence/probe/p.lean`, named by the plan's own `Files to modify` block, and a source
  root holding an unrelated declaration, yields `[MISSING] probeOnly — not found in the resolved
  source roots` / `COMPLIANCE_CHECK: failed` / exit 1, while `grep -rl` over the probe path finds
  the declaration and `plan-file-scope-harvest.sh` on the same plan returns exactly
  `["specs/evidence/probe/p.lean"]`. The whole fix mechanism is therefore validated end to end
  before any implementation step runs.
- **"the replacement-target integrity sub-check ... greps the same `"${lean_roots[@]}"` scope" —
  CONFIRMED, with one mechanical correction.** The sweep has no grep of its own: it calls
  `find_decl_files "$new_name"` (`:357`). It therefore inherits the blind spot rather than
  duplicating it, and inherits the widening automatically once the two lookup functions change —
  no separate code path is needed to satisfy the dispatch's "apply the same widened scope to the
  replacement-target sub-check" instruction. This is a correction to the *mechanism*, not to the
  conclusion.
- **"8 of 8 Goals MISSING while a probe-scoped grep found 8 of 8 present" — NOT re-verifiable
  here, and not load-bearing.** That measurement belongs to an archived task in the BimodalLogic
  repository (`iss_1791842368633_NJQxnS`, resolvable only there per this task's migration
  provenance). The live reproduction above establishes the same defect independently, so nothing
  in this plan rests on the carried ratio.
- **"(FormalSystem, Tests, BimodalTools)" as the resolved roots — NOT re-verified, and not
  load-bearing.** Those are one consuming repository's roots; `lean-src-roots.sh` resolves roots
  from the target project's own lakefile, and this plan changes nothing about that resolution.
- **"the edit target is the source store under `agent-system/extensions/lean/`" — CONFIRMED.**
  Both target files exist in the source store, and the deployed `.claude/scripts/` copies are
  regenerated artifacts (Phase 3 regenerates them rather than editing them).
- **Suite baseline — MEASURED at plan time: 19 passed, 0 failed.** The baseline is clean, so
  "19/19 still green" is a satisfiable absolute rather than a guessed delta.
- **Existing message-text assertions — MEASURED.** Only two existing cases assert on message
  prose beyond the identifier (`test-lean-plan-compliance-check.sh:431-433` on `found as a
  structure/class field`, `:464` on `found as a Lean module`), and both match a *leading*
  fragment. The trailing "in the resolved source roots" phrase is therefore free to change,
  provided those leading fragments stay byte-identical.

### Research Integration

The research report's recommendations are adopted essentially intact: widen only
`find_decl_files`/`find_field_files` (D1); change nothing at the call site, in step 0, or in
steps 1-4 of the Final Verification Stage (D2); reuse the already-deployed
`plan-file-scope-harvest.sh` rather than hand-rolling a second `Files to modify` parser (D3);
treat the Challenge manifest as optional (D4); and document the change as the sixth entry in the
script's own "Changes beyond the original" header inventory (D5). Two things this plan adds
beyond the report: the polarity restriction in Decision D6 below, and the harvester-path
resolution ladder in Decision D7, which the report's recommendation did not address and without
which the test suite cannot exercise the new code path from the source store at all.

### Prior Plan Reference

No prior plan. This is the task's first planning round.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag is set, so no roadmap was
consulted and no roadmap phases are added.

### Domain Plan-Authoring Gotchas

The deployed context index carries exactly one `project/**` entry keyed to `plan-authoring`
(`project/lean4/patterns/plan-authoring-gate-collisions.md`), and its `load_when.task_types` is
`["lean4"]`, which does not include this dispatch's `meta` task type — so by the adaptive-query
rule it does not apply. It was read anyway, cheaply, and all nine of its conditions concern a
consuming Lean repository's own generated surfaces (module inventories, `typst/generated/status.typ`,
Lean linters, import allowlists); none is triggered by a shell-script edit in this repository.
One condition is nonetheless honored because it is repository-agnostic in substance: Condition
2's rule that a `verify-deploy.sh`-shaped invocation's target must be a repository root holding
both a deployed `.claude/` tree and the `agent-system/extensions` source store — which is why
Phase 3's checks name `/home/benjamin/.config/nvim` rather than any extension subdirectory.

## Goals & Non-Goals

**Goals**:

- `find_decl_files` and `find_field_files` search the resolved Lean source roots unioned with the
  paths the plan under check itself declares, so a Goal pinned in an evidence probe resolves.
- The `replacement_targets` integrity sweep gets the same widened scope, via its existing reuse
  of `find_decl_files` rather than through any new code path.
- The widening is derived entirely from the `plan_file` argument the script already receives: no
  change to the step 5 call site in `lean-implementation-agent.md`, and no new argument.
- Every failure mode of the new derivation (no `jq`, unresolvable harvester, absent or
  unparseable Challenge manifest, a harvested path that does not exist or is not `.lean`) degrades
  to exactly today's roots-only behavior, never to a hard script failure.
- The new behavior, the preserved roots-only behaviors, and the fail-soft fallback are each pinned
  by their own regression case in `test-lean-plan-compliance-check.sh`.
- The deployed `.claude/scripts/` copy carries the change, because that is the copy the lean
  implementation agent actually invokes.

**Non-Goals**:

- Changing step 0's resolve-or-abort posture, or `lean-src-roots.sh` itself.
- Changing the four roots-only consumers the dispatch names explicitly: the sorry census, the
  axiom count, the vacuity check, and the build.
- Widening `find_module_files` (see Decision D1) — a Goal naming a bare *module path* inside a
  probe file remains unresolved, and the header bullet says so.
- Fixing step 6's comparator-gate Preflight 4, which carries the structurally identical blind
  spot in its own inline grep (see Risks) — out of scope, surfaced as a follow-up candidate.
- Editing `lean-implementation-agent.md`, `manifest.json` (both scripts are already declared in
  `provides.scripts`), or any `.claude/**` file by hand.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent sibling task #504 declares the identical two files in its own `file_scope` this same cycle | M | H | #504 narrows *which* names are harvested (the Goals-prose backtick harvest near the top of the script); this task changes *where* harvested names are searched (the three lookup-function greps, plus a new pre-function block). Different regions, but the same files: every phase re-reads its target file immediately before editing, stages an explicit file list (never a directory or glob pathspec), and treats a foreign commit or foreign uncommitted modification as a STOP-and-report condition per `context/contracts/territory.md`. Line numbers cited in this plan are plan-time readings and are re-derived by grep, not trusted. |
| Widening under refutation polarity would manufacture the mirror false failure: a refutation plan's own evidence probe routinely declares the very identifier that must be ABSENT, so the probe file would be read as a presence and fail the plan for doing its job | H | H | Decision D6: the union applies under must-exist polarity only; refutation polarity keeps today's roots-only scope. Pinned by case C24. |
| Reworded output messages break an existing assertion | M | L | Measured at plan time: only two cases assert message prose, both on leading fragments (`found as a structure/class field`, `found as a Lean module`). The rewording changes only the trailing scope phrase and preserves those fragments byte-for-byte; the full suite is re-run in the same phase. |
| The harvester's own stderr warnings (deployed-tree and unexpanded-variable refusals) leak into the compliance check's captured output and perturb a negative assertion | L | M | The harvester call redirects its stderr to `/dev/null`: those refusals belong to the harvest-time `file_scope` consumer, not to this read-only reader of the same field. The compliance check's own fail-soft note is the only new stderr line it emits. |
| `jq` is a new dependency for a script that currently has none | M | L | One `command -v jq` guard gates the entire derivation; its absence skips the widening and leaves today's behavior exactly intact. Pinned by case C23. `jq` is already a hard dependency of the harvester itself and of other scripts the same agent stage relies on, so the guard is a defensive floor rather than an expected path. |
| The harvester resolves only in the deployed tree (both scripts side by side in `.claude/scripts/`) and not in the source store, where the two live in different extension directories — silently disabling the new path exactly where the suite runs | M | H | Decision D7's four-rung resolution ladder, whose source-store rung (`../../core/scripts/`) makes the suite exercise the real code path, plus an env override the suite uses to simulate the unresolvable case. |
| A plan-named file contains an unrelated declaration of the same name, yielding a false `[OK]` that masks a genuinely missing declaration | L | L | Bounded by construction: `extra_paths` only ever holds paths the plan itself committed to touching or the Challenge snapshot it itself created, never an arbitrary repo-wide widening. A stray same-named declaration inside a file the plan already declares it is modifying is a pre-existing authoring risk this change neither creates nor worsens. |
| Step 6's comparator-gate Preflight 4 keeps the identical blind spot in a separate inline grep, so a probe-pinned plan that also opts into `--compare` still hits `comparator_solution_module_unresolved` | L | M | Deliberately out of scope: the dispatch names exactly one additional sub-check to widen (the replacement-target sweep) and that sub-check is covered. Recorded here and in the final summary as a follow-up candidate rather than silently folded in. |
| Phase 3's `__WHOLE_TREE__` claim exact-matches another task's identical claim and serializes this task behind it | L | L | Designed behavior of the whole-tree-claim admission dimension, not a defect. The claim is declared with the reserved sentinel; no real wide path is substituted to evade serialization. |

## Decisions

- **D1 (widen two functions, not three)**: `find_decl_files` and `find_field_files` do flat greps
  over their scope array and widen correctly when individual files are spliced in.
  `find_module_files` treats each array member as a *directory* (`basename "$root"`,
  `"$root/$rel"`), so splicing files into the same array would silently miscompute paths. It stays
  roots-only, and the limitation is named in the header bullet rather than left for a reader to
  discover.
- **D2 (no caller-side change)**: the script already receives `$plan_file`, from which both
  widening sources derive. `lean-implementation-agent.md`'s step 5 block, step 0, and steps 1-4
  are untouched.
- **D3 (reuse the harvester, fail soft)**: call
  `plan-file-scope-harvest.sh` rather than adding a fifth independent `Files to modify` parser.
  Its absence, or `jq`'s, degrades to roots-only behavior rather than failing the check, because
  neither is relevant to whether the roots-only half can still run.
- **D4 (Challenge manifest optional)**: consulted only when
  `{task_dir}/challenge/manifest.json` exists; absence is normal, never an error. The join is
  `project_root` + `challenge_path`, the two fields `lean-challenge-snapshot.sh` writes and step 6
  already joins the same way.
- **D5 (header inventory entry)**: the script's header documents each deliberate change beyond the
  original extraction (five entries today: goal polarity, keyword denylist, colon-optional range,
  declaration-kind/dotted-name widening, Challenge-statements-preferred harvest). This change is
  the sixth and is documented in the same format, including what it deliberately does *not* widen.
- **D6 (must-exist polarity only — this plan's own addition)**: the union is applied under
  must-exist polarity; refutation polarity keeps the resolved roots alone. Rationale: refutation
  semantics asserts that an identifier is absent from the *library*, and a refutation plan's
  evidence probe routinely pins the refuted statement's body on purpose — unioning the probe into
  the scope would report that body as a presence and fail the plan for achieving its goal, which
  is the exact mirror of the false failure this task exists to remove. Implemented as a single
  polarity-conditioned `search_roots` assignment, so neither lookup function is duplicated.
- **D7 (harvester resolution ladder — this plan's own addition)**: resolve the harvester through
  an env override, then the sibling-directory default (the deployed layout, both scripts in
  `.claude/scripts/`), then the repo-relative deployed path, then the source-store sibling-extension
  path (`../../core/scripts/`) — first existing wins, none found means fail-soft. This follows the
  env-override-with-sibling-default precedent already used in `lean-comparator-run.sh` for
  `lake-build-guard.sh` and `lean-comparator-landrun-shim.sh`, and it is what lets the suite
  exercise the real code path while running the script straight out of the source store.
- **D8 (honest output prose)**: the per-name output lines currently end "in the resolved source
  roots". Once a hit can come from a plan-named path, that phrasing is false for exactly the case
  this task adds, and the originating incident was precisely a human having to reconcile a
  mis-scoped reading by hand. The trailing phrase is reworded to name the actual scope; each
  message's leading fragment is preserved byte-for-byte so the two existing prose assertions keep
  matching.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. This plan is a strict chain: the behavior
must exist before cases can pin it, and both must be final before the tree is regenerated from
them.

---

### Phase 1: Widen the per-name lookup scope to the plan's own declared paths [COMPLETED]

**Goal**: `find_decl_files` and `find_field_files` search the resolved roots unioned with
plan-derived paths under must-exist polarity, deriving that union from `$plan_file` alone and
degrading to today's behavior on every failure mode; the `replacement_targets` sweep inherits the
widened scope through its existing `find_decl_files` call; `find_module_files` and refutation
polarity are unchanged; the script's header documents all of it.

**Tasks**:

- [x] Re-read `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh` in full
      immediately before editing. Sibling task #504 declares this same file this cycle, so
      confirm by `git log`/`git status` that no foreign commit or foreign uncommitted modification
      has landed; STOP and report if one has, rather than proceeding. *(completed: #504's commits
      to this file (8e3d64d56, c9e743fb2) are already-committed history, not a foreign uncommitted
      modification; `git status --porcelain` on the two target files was clean)*
- [x] Re-derive the call-site inventory by grep rather than trusting this plan's line numbers:
      `grep -n '"\${lean_roots\[@\]}"' <file>` must show exactly four consumers — two in
      `find_decl_files`, one in `find_field_files`'s bare-name branch, one in
      `find_module_files`'s directory loop. If the count differs, stop and reconcile before
      editing. *(completed: confirmed exactly four, matching the hypothesis)*
- [x] Add a harvester-resolution ladder near the top of the script, following
      `lean-comparator-run.sh`'s env-override-with-sibling-default precedent: honor
      `LEAN_PLAN_COMPLIANCE_HARVESTER` when set, else take the first of
      `$(dirname "${BASH_SOURCE[0]:-$0}")/plan-file-scope-harvest.sh`,
      `.claude/scripts/plan-file-scope-harvest.sh`, and
      `$(dirname "${BASH_SOURCE[0]:-$0}")/../../core/scripts/plan-file-scope-harvest.sh` that
      exists and is readable. Resolving to nothing is a fail-soft condition, not an error.
      *(completed: a SET override is terminal -- used if readable, else treated as unresolved
      outright, never falling through to the remaining three rungs; see the plan's own
      Verification bullet 3, which requires the nonexistent-path override to reach the fully
      fail-soft outcome rather than silently falling through to the always-present source-store
      rung)*
- [x] Add an `extra_paths=()` derivation block positioned after the polarity resolution and before
      the three lookup-function definitions, gated as a whole by `command -v jq >/dev/null 2>&1`:
      (a) run the resolved harvester on `"$plan_file"` with its stderr redirected to `/dev/null`
      (its deployed-tree and unexpanded-variable refusals belong to the `file_scope` consumer, not
      to this reader), read the JSON array with `jq -r '.[]'`, and keep only entries matching
      `\.lean$` that satisfy `[ -f ]`; (b) derive
      `task_dir="$(dirname "$(dirname "$plan_file")")"` and, when
      `$task_dir/challenge/manifest.json` exists, append the `project_root` + `challenge_path`
      join when that joined path satisfies `[ -f ]`. Deduplicate the result. *(completed)*
- [x] Make every failure path in that block emit at most one `>&2` note and continue: no `jq`, no
      resolvable harvester, a non-zero harvester exit, an absent or unparseable manifest, or an
      empty result each leave `extra_paths` empty and the rest of the check running unchanged.
      *(completed: the absent/unparseable-manifest case is silent per Decision D4's "never an
      error" framing, rather than emitting a note for a routine/expected condition)*
- [x] Assign the search scope exactly once, conditioned on polarity (Decision D6):
      `search_roots=("${lean_roots[@]}" "${extra_paths[@]}")` under must-exist polarity,
      `search_roots=("${lean_roots[@]}")` under refutation polarity. Do not duplicate either
      lookup function to express this. *(completed)*
- [x] Replace `"${lean_roots[@]}"` with `"${search_roots[@]}"` at exactly the three per-name grep
      sites confirmed above (both greps in `find_decl_files`, the bare-name grep in
      `find_field_files`). Leave `find_module_files`'s `for root in "${lean_roots[@]}"` loop
      reading the roots array directly. *(completed)*
- [x] Leave the `replacement_targets` sweep's code untouched and confirm by reading it that it
      still obtains its file through `find_decl_files` — that reuse is what discharges the
      dispatch's "same widened scope for the replacement-target sub-check" requirement.
      *(completed: confirmed by reading -- no edit made)*
- [x] Reword the trailing scope phrase in the per-name `[OK]`/`[MISSING]`/`[PRESENT]` messages so
      a plan-named hit is not reported as a roots hit (Decision D8), keeping the leading fragments
      `found as a structure/class field` and `found as a Lean module` byte-identical. *(completed:
      only the must-exist-polarity [OK]/[MISSING] decl/field lines were reworded; the module [OK]
      line and all refutation-polarity lines keep their original, still-accurate phrasing since
      their scope was not widened)*
- [x] Add the sixth entry to the header's "Changes beyond the original (behaviour-preserving)
      extraction" inventory, in that section's established format: what widened, that the
      replacement-target sweep inherits it, that refutation polarity and `find_module_files` are
      deliberately excluded and why, and that the whole derivation is fail-soft. *(completed)*
- [x] Run `bash agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh` and
      require `19 passed, 0 failed` — the clean baseline measured at plan time. *(completed:
      live re-read found the baseline had drifted to 22 passed, 0 failed (C1-C19, C21, C22) since
      sibling task #504 committed C21/C22 after this plan was written; re-verified 22 passed, 0
      failed unchanged after this phase's edits, per the pre-write re-read obligation rather than
      the stale plan-time count)*
- [x] Reproduce the fix against a scratch fixture mirroring the plan-time reproduction (a
      declaration present only in a `.lean` file named by the fixture plan's own `Files to modify`
      block, with a source root holding something else) and confirm the verdict flips from
      `[MISSING]`/failed/exit 1 to `[OK]`/passed/exit 0. *(completed: also confirmed the negative
      case (genuinely absent name) still fails, and the `LEAN_PLAN_COMPLIANCE_HARVESTER`-unresolved
      fail-soft fallback returns to `[MISSING]`/failed/exit 1 with exactly one stderr note)*
- [ ] Commit with an explicit single-file pathspec via `.claude/scripts/git-commit-scoped.sh`,
      after reviewing `git status --short` and `git diff --staged`.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: exactly three per-name grep call sites consume `"${lean_roots[@]}"` and need
the swap (two in `find_decl_files`, one in `find_field_files`), with `find_module_files`'s
directory loop the only other consumer inside the three lookup functions — read from the file at
plan time at lines 256, 269, 294 and 307. The line numbers are hypotheses and will have moved if
sibling #504 lands first; the implementer confirms the *count* and the *owning function* of each
consumer by grep in the re-read file, as the second task above requires, before editing.

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh`
runs the `test-lean-plan-compliance-check.sh` suite — the single suite the selector returns for
this path, and this file's own covering suite.

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh` - harvester-resolution
  ladder, fail-soft `extra_paths` derivation, polarity-conditioned `search_roots`, the three grep
  call-site swaps, the reworded output scope phrases, and the sixth header-inventory entry

**Verification**:
- The existing suite reports `19 passed, 0 failed` (the plan-time baseline), unchanged.
- The scratch probe-scoped fixture reports `[OK]` and `COMPLIANCE_CHECK: passed`, exit 0; the same
  fixture with the Goal name absent everywhere still reports `[MISSING]` and exit 1.
- With `LEAN_PLAN_COMPLIANCE_HARVESTER` pointed at a nonexistent path, the probe-scoped fixture
  returns to `[MISSING]`/failed/exit 1 with no bash error output beyond the single fail-soft note —
  proving the fallback is a degradation, not a crash.
- `grep -n '"\${search_roots\[@\]}"'` shows exactly three occurrences and
  `grep -n 'for root in "\${lean_roots\[@\]}"'` still shows `find_module_files`'s loop.
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh`
  exits 0, checked as an exit status in its own right rather than inferred from quiet output.

---

### Phase 2: Pin the widened scope, the preserved scopes, and the fallback with regression cases [NOT STARTED]

**Goal**: `test-lean-plan-compliance-check.sh` characterizes every behavior Phase 1 introduced or
deliberately preserved, so a later reader cannot mistake any of them for an accident and a
regression in any one of them fails loudly.

**Tasks**:

- [ ] Re-read `agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh` and
      take the suite's current highest case number from its tail (C19 at plan time) rather than
      assuming it; sibling task #504 may have appended its own cases first. Apply the same
      foreign-commit STOP check as Phase 1.
- [ ] Add a probe fixture outside `$ROOT` (e.g. `$WORKDIR/probe/Probe.lean`) declaring one
      theorem, one `structure` with a field, and one declaration that delegates to a name the
      fixture plan states it replaces.
- [ ] Append a case (C20 at plan-time numbering): a must-exist plan whose Goal names a declaration
      present ONLY in a `.lean` file its own `**Files to modify**:` block names, outside the
      `lean_root` argument. Expect `[OK]` and `COMPLIANCE_CHECK: passed`, exit 0 — the inverted
      regression for the originating symptom. Include in the same fixture's `Files to modify`
      block one non-`.lean` entry and one nonexistent `.lean` entry, asserting both are filtered
      silently with no grep error in the output.
- [ ] Append a case (C21): a plan with no probe path in `Files to modify` whose Goal names a
      declaration present only at the path recorded by a synthetic
      `challenge/manifest.json` written next to the plan's own task directory (`project_root` +
      `challenge_path`). Expect `[OK]`, passed — exercising the manifest half independently.
- [ ] Append a case (C22): a must-exist plan whose prose declares a replacement target and whose
      new declaration — living in a widened probe file, not under `$ROOT` — still delegates to the
      replaced name. Expect `[INTEGRITY FAIL]` and failed, proving the sweep inherited the widened
      scope.
- [ ] Append a case (C23): the same fixture as C20 with `LEAN_PLAN_COMPLIANCE_HARVESTER` set to a
      nonexistent path. Expect today's roots-only outcome — `[MISSING]`, failed, exit 1 — with no
      hard error, pinning the fail-soft fallback.
- [ ] Append a case (C24): a refutation-polarity plan whose Goal names an identifier present ONLY
      in a probe file its own `Files to modify` block names. Expect `[OK]` and passed — refutation
      polarity keeps the roots-only scope, so the probe body is not read as a presence. Give the
      case a header comment naming Decision D6 as the reason, so the behavior reads as chosen
      rather than overlooked.
- [ ] Append a case (C25): a must-exist plan whose Goal names a `structure` FIELD present only in
      a widened probe file. Expect `[OK]` with the preserved `found as a structure/class field`
      fragment, exercising `find_field_files`'s own widened grep rather than reaching the result
      through `find_decl_files`.
- [ ] Update the suite's header comment to name the new cases and what each pins, matching the
      existing header's per-case-group convention.
- [ ] Run the suite and require every case green, old and new, with the total equal to the
      plan-time baseline of 19 plus the cases actually appended.
- [ ] Commit with an explicit single-file pathspec after reviewing `git status --short` and
      `git diff --staged`.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: six new cases, numbered C20-C25, appended after the suite's current highest
case C19 — both the count and the starting number are plan-time readings of the file's tail. The
implementer takes the actual starting number from the re-read file (the first task above) and, if
a sibling's cases already occupy those numbers, renumbers this phase's additions upward rather
than reusing a number.

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh`
runs the `test-lean-plan-compliance-check.sh` suite — the single suite the selector returns for
this path, and the very file being edited.

**Files to modify**:
- `agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh` - the probe
  fixture plus the six appended regression cases and the header-comment update

**Verification**:
- The suite exits 0 with every case passing and a total of 25 at plan-time numbering (19 baseline
  + 6 appended); any lower total means a case was dropped rather than added.
- Reverting Phase 1's three call-site swaps in a scratch copy of the script makes C20, C21, C22 and
  C25 fail while C23 and C24 still pass — confirming the new cases actually bind to the widening
  rather than passing for an unrelated reason.
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh`
  exits 0, checked as an exit status in its own right.

---

### Phase 3: Regenerate the deployed tree and close the gate obligation [NOT STARTED]

**Goal**: the runtime copy the lean implementation agent actually invokes
(`.claude/scripts/lean-plan-compliance-check.sh`) carries the widened scope and resolves its
harvester sibling, and this task's touched paths are verified as a scoped set with the complete
gate set explicitly deferred to the orchestration close.

**Tasks**:

- [ ] Confirm the working tree holds both committed phases and nothing unrelated to this task is
      staged.
- [ ] Regenerate the deployed tree with the bounded-wait idiom the deploy path requires:
      `timeout 540 bash .claude/scripts/deploy-headless.sh`, invoked with the Bash tool's
      `timeout` parameter raised to 600000 rather than its 120000ms default (see
      `context/patterns/external-process-wait.md` Rule 1). Require exit 0. This is whole-tree
      regeneration, which is why `__WHOLE_TREE__` is declared below.
- [ ] Confirm `.claude/scripts/lean-plan-compliance-check.sh` and
      `.claude/scripts/tests/test-lean-plan-compliance-check.sh` are byte-identical to their
      source-store counterparts (`diff` on each, expecting no output).
- [ ] Confirm the deployed script's harvester resolution succeeds on its first non-override rung:
      `.claude/scripts/plan-file-scope-harvest.sh` exists next to it and is readable.
- [ ] Run the suite from its deployed location
      (`bash .claude/scripts/tests/test-lean-plan-compliance-check.sh`) and require every case
      green there too — the source-store run in Phase 2 exercises the source-store resolution
      rung, and this run exercises the sibling-directory rung that production actually uses.
- [ ] Run the scoped touched-path check that discharges this phase's own in-dispatch obligation:
      `bash .claude/scripts/verify-touched.sh agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh`
      (one invocation over the whole touched set, never one per path). Require exit 0.
- [ ] State explicitly, in the dispatch's own return, that the complete gate set is deferred to
      the orchestration close (`context/contracts/batch-gate-stage.md`) and is NOT run
      independently in this phase.
- [ ] Record the comparator-gate Preflight 4 blind spot as a follow-up candidate in the task's
      issue log, so the out-of-scope decision leaves a durable trace rather than only a sentence
      in this plan.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - whole-tree regeneration via `deploy-headless.sh`; no tracked source file is
  edited in this phase

**Verification**:
- `timeout 540 bash .claude/scripts/deploy-headless.sh` exits 0 and reports no stale extension.
- Both deployed copies `diff` clean against their source-store counterparts.
- The suite run from `.claude/scripts/tests/` passes every case.
- `bash .claude/scripts/verify-touched.sh` over this task's two touched paths exits 0.
- The complete gate set is deferred to the orchestration close rather than invoked here; any gate
  finding surfaced there that names a file outside this task's two touched paths is reported as
  pre-existing, with the evidence that each touched path passes individually, rather than treated
  as this task's regression (see `plan-authoring-gate-collisions.md` Condition 4's
  implementer-side corollary).

---

## Testing & Validation

- [ ] The pre-existing 19 cases of `test-lean-plan-compliance-check.sh` remain green after every
      phase — the clean baseline measured at plan time, so no delta framing is needed.
- [ ] A Goal present only in a plan-named `Files to modify` `.lean` path resolves `[OK]` under
      must-exist polarity (C20).
- [ ] A Goal present only at the Challenge manifest's `project_root`+`challenge_path` join resolves
      `[OK]` with no `Files to modify` contribution at all (C21).
- [ ] The `replacement_targets` sweep reports `[INTEGRITY FAIL]` for a delegation living in a
      widened probe file (C22).
- [ ] With the harvester unresolvable, behavior is byte-for-byte today's roots-only behavior and
      the script still exits 0/1 by verdict rather than erroring (C23).
- [ ] Refutation polarity is unaffected by the widening (C24).
- [ ] A structure field present only in a widened probe file resolves through `find_field_files`
      (C25).
- [ ] A Goal naming a bare module path inside a probe file still reports `[MISSING]` — the
      documented, deliberate limitation of leaving `find_module_files` roots-only, confirmed rather
      than assumed.
- [ ] The deployed copies are byte-identical to the source store and the suite passes from the
      deployed location.

## Artifacts & Outputs

- `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh` - widened per-name lookup
  scope, fail-soft plan-derived path derivation, sixth header-inventory entry
- `agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh` - six new
  regression cases plus the probe fixture and header-comment update
- `.claude/scripts/lean-plan-compliance-check.sh` and
  `.claude/scripts/tests/test-lean-plan-compliance-check.sh` - regenerated deploy artifacts, not
  hand-edited
- `specs/537_plan_compliance_spotcheck_probe_scope/summaries/01_*-summary.md` - completion summary,
  carrying the comparator-gate Preflight 4 follow-up candidate
- `specs/537_plan_compliance_spotcheck_probe_scope/issues.jsonl` - issue/win entries recorded as
  they arise

## Rollback/Contingency

Each phase commits exactly one file with an explicit pathspec, so reverting is a per-phase
`git revert` of that commit — no working-tree discard is needed, and none should be attempted
while sibling task #504 may hold uncommitted edits to the same two files.

If Phase 1's widening turns out to break a behavior the suite does not cover, the minimal
containment is to narrow `search_roots` back to `("${lean_roots[@]}")` unconditionally, which
restores today's behavior exactly while leaving the derivation block, the ladder and the header
entry in place for a corrected second attempt — the one-line retreat the polarity-conditioned
single-assignment design in Decision D6 exists to make possible.

If the Phase 3 redeploy fails or produces a stale tree, the source-store commits stand on their
own and the deploy is retried; nothing in Phases 1-2 depends on the deploy having happened. Should
a genuine rollback of uncommitted work ever be required, take the snapshot first per
`context/contracts/recovery.md`'s rollback rung (which names the invocation shape and its
out-of-scope override flag) rather than running a destructive git command directly.
