# Implementation Plan: Task #597

- **Task**: 597 - Coupled generated surfaces in plan authoring
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None (task 596 `generated_file_scope_vs_readonly_risk` depends ON this task; task 599 shares `plan-format.md` territory with no dependency edge)
- **Research Inputs**: specs/597_coupled_generated_surfaces_in_plan_authoring/reports/01_coupled-generated-surfaces-plan-authoring.md
- **Artifacts**: plans/01_coupled-generated-surfaces-plan-authoring.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two plan-authoring guidance defects are repaired in the source store
(`/home/benjamin/.config/nvim/agent-system/extensions`, re-derived per-extension from
`.claude-extensions.json`, never under `.claude/**`). Defect A is a REACH gap plus a missing
general obligation: a repo-agnostic coupled-generated-surface declaration rule is added to
`plan-format.md`'s `Files to modify` contract, a `task_type`-gated domain-gotchas lookup is added
to `planner-agent.md`'s phase-authoring checklist so a `lean4` plan dispatch actually surfaces the
existing `plan-authoring-gate-collisions.md` checklist, and an advisory, repo-declared
`coupled_generated_surfaces` check is added to `validate-artifact.sh`. Defect B rewrites
Condition 7 of `plan-authoring-gate-collisions.md` with the `longFile` linter's real arithmetic,
read from the originating repository's own pinned Mathlib checkout.

The record is implemented, not abandoned. The dispatch's PRIOR RECORDS instruction asked for an
explicit decision: both prior records it names (`per_phase_generated_surface_gates_and_batch_defer`,
abandoned; `lean_plan_gate_collision_authoring_guidance`, completed) stayed behind in the source
repository's archive and were never migrated here, so there is nothing live to resurrect or to
re-prune, and the class recurred after that pruning with 10 fresh citations across two tasks. The
recurrence is the warrant; this plan proceeds.

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class line the dispatch flagged was checked against live state at planning time.
Result stated explicitly, including where it only confirms the description unchanged:

| Premise from the description | Check run | Result |
|---|---|---|
| Source store is `/home/benjamin/.config/nvim/agent-system/extensions` | `jq '.extensions \| to_entries[] \| .value.source_dir'` on `.claude-extensions.json` | CONFIRMED. All nine loaded extensions (approvals, memory, literature, email, nvim, core, lean, nix, sapience) resolve under that directory. The key is per-extension, as the dispatch warned |
| Condition 7 states the window as `N - 200 <= lines < N` | read the live file | CONFIRMED UNCHANGED. The wrong text is present verbatim in `plan-authoring-gate-collisions.md`'s Condition 7 |
| `plan-authoring-gate-collisions.md` is referenced only by `lean/EXTENSION.md` and `lean/index-entries.json` | `grep -rln` over the whole source store | CONFIRMED. Exactly those two files, no third referrer |
| `routing_agents.plan.lean4` = `planner-agent` | `jq '.routing_agents.plan'` on `lean/manifest.json` | CONFIRMED. All three lean plan routes (`lean4`, `lean4:lake`, `lean4:version`) resolve to `planner-agent` |
| `planner-agent.md` carries no pointer to the lean checklist and no lean context table | `grep -in lean` over the whole file | CONFIRMED. One hit only: the `**Lean Intent**:` output-template field, which the agent writes into a finished plan and never reads from |
| 10 citations across tasks 838 and 853 | existence check in the source repository | PARTIALLY RE-DERIVED. Both logs exist (`838.../issues.jsonl`, 27 entries; `853.../issues.jsonl`, 30 entries) and a spot-checked id (`iss_1794302533674_MPP05G`) resolves in the 853 log. The class count of 10 is the source record's own measurement and was not re-counted entry-by-entry here; nothing contradicts it |
| Defect B's rule should be derived from the linter's source for the pinned toolchain (Lean v4.33.0-rc1) rather than from two data points | read the PINNED checkout, not `master` | DONE, AND THE RESEARCH REPORT'S NAMED RISK IS CLOSED. `/home/benjamin/Projects/BimodalLogic/lean-toolchain` is `leanprover/lean4:v4.33.0-rc1`; its `lake-manifest.json` pins mathlib at rev `79d0395a1825a6264ad5d269e35e60537518955e` (inputRev `v4.33.0-rc1`); that checkout's `Mathlib/Tactic/Linter/Style.lean` is present locally and reads `let candidate := (lastLine / 100) * 100 + 200`, `let candidate := max candidate defValue`, `if linterBound == candidate \|\| linterBound + 100 == candidate then return`. No web re-check phase is needed |
| This repository declares no coupled surfaces today | `jq keys .claude-extensions.json` | CONFIRMED: `["extensions","version"]` only — no `derived_artifact_probes`, no `coupled_generated_surfaces`. The new check is therefore inert here and its tests must synthesize their own fixture repo root |

### Research Integration

The research report is adopted on all four substantive points: (1) the reach gap is real and
verified end to end; (2) adding `planner-agent` to the lean entry's `load_when.agents[]` is
UNSOUND, because `context-discovery.md`'s adaptive query ORs the agent, task-type and command
dimensions, so a cross-domain shared agent in `agents[]` leaks the entry into every domain's plan
dispatch — the reach mechanism is therefore a `task_type`-gated pointer inside `planner-agent.md`
itself, and `lean/index-entries.json` needs no edit at all (its entry already carries both
`task_types: ["lean4"]` and the `plan-authoring` keyword the lookup keys on); (3) the advisory
check models `derived_artifact_probes`' survivability and fail-open posture but needs its own
differently-shaped array, because that schema has no trigger-pattern field; (4) Defect B's
corrected rule, now re-derived from the pinned checkout rather than `master`.

One research recommendation is narrowed. The report proposed a new
`scripts/lib/coupled-surface-lib.sh`. A new library file must be enumerated in
`core/manifest.json`'s `provides.scripts` (400 entries) or it never deploys, and
`core/manifest.json` is inside a concurrent sibling task's declared `file_scope` this cycle. With
exactly one consumer today, the reader is implemented INLINE in `validate-artifact.sh`, modeled
on `_derived_probe_load_entries_json`'s fail-open shape, with a header comment recording that a
second consumer is the trigger to promote it to a library. This avoids both a manifest edit and a
cross-task territory collision for no loss of behaviour.

### Prior Plan Reference

No prior plan. This is the task's first plan round.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no ROADMAP phases are required.

### This Plan's Own Coupled Surfaces (the obligation applied to itself)

Two couplings in THIS repository are tripped by this task's own edits, and are declared here
rather than rediscovered mid-phase:

- **`index-entries.json` `line_count` (Gate 3, `check-extension-docs.sh` Rule R)**: every edited
  file under an extension's `context/` tree has a `line_count` field that Rule R checks against
  `wc -l`. Editing `plan-format.md`, `context-discovery.md`, `repo-level-declarations.md`, or
  `plan-authoring-gate-collisions.md` makes that entry stale. `planner-agent.md`,
  `validate-artifact.sh` and the test file are NOT index entries and carry no such coupling.
- **Deployed-tree content-hash equality (Gate 5, `verify.lua`)**: any source-store edit makes the
  deployed `.claude/` tree stale, so a complete-gate-set pass requires a
  `deploy-headless.sh` regeneration first.

Neither check is commit-blocking in this repository — no `pre-commit` hook is installed
(`.git/hooks` has no `pre-commit`, `core.hooksPath` is unset). Under the very asymmetry rule this
task authors, a non-commit-blocking coupled surface may legitimately be reconciled in a later
phase provided the declaration is made; both are therefore declared and regenerated in the final
phase, whose `deploy-headless.sh` run auto-repairs `line_count` as a documented side effect.

## Goals & Non-Goals

**Goals**:

- A repo-agnostic coupled-generated-surface declaration obligation in
  `core/context/formats/plan-format.md`'s `Files to modify` contract, parallel in shape to the
  "Whole-tree-claim declaration rule" and "Correction-target existence obligation" subsections
  already there, with the commit-blocking / advisory asymmetry as its load-bearing clause.
- A reach mechanism that puts a domain's plan-authoring gotchas file in front of the plan author:
  a `task_type`-gated lookup step in `core/agents/planner-agent.md`'s phase-authoring checklist,
  generic rather than hardcoded to `lean4`.
- A named sibling hazard in `core/context/patterns/context-discovery.md` recording why the
  `agents[]` dimension cannot carry a cross-domain shared agent for domain-specific content.
- A corrected Condition 7 in `lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`,
  stating the pinned linter's real arithmetic and the incremental-re-tightening consequence.
- An advisory, repo-declared `coupled_generated_surfaces` check in
  `core/scripts/validate-artifact.sh`, fail-open on absence, with test coverage.
- A documented declaration schema in `core/context/standards/repo-level-declarations.md`.

**Non-Goals**:

- Repairing the originating repository's gates. `.githooks/pre-commit`,
  `scripts/typst-sync-check.sh`, `scripts/check-module-invariants.sh`,
  `scripts/nolint-attribute-allowlist.txt`, `typst/generated/status.typ` and the generated README
  inventory blocks are correct as they stand and are not edited.
- Declaring any `coupled_generated_surfaces` entry in THIS repository's
  `.claude-extensions.json`. The mechanism ships inert; a consumer repo opts in.
- Editing `lean/index-entries.json` or `lean/EXTENSION.md`. The existing index entry already
  carries everything the new lookup keys on; adding `planner-agent` to its `agents[]` is the
  rejected unsound option, not a smaller version of the chosen one.
- Promoting any new check to error severity, or promoting any existing advisory check.
- The generator-written vs. hand-edited read-only CATEGORY distinction. That is task 596's
  declared refinement of this remedy and is deliberately left to it.
- Creating `scripts/lib/coupled-surface-lib.sh` (see Research Integration above for why).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A sibling task commits to one of this task's files between a phase's read and its commit | M | L | No concurrent sibling this cycle declares any file in this plan's scope (checked against all six sibling scopes in the dispatch territory block). The territory contract still applies: re-read immediately before editing, stage only this task's own hunks, never a directory or glob `git add` |
| `core/index-entries.json` and `lean/index-entries.json` already carry UNCOMMITTED foreign modifications at planning time (`git status` shows both as ` M`) | M | H (already true) | Those files are touched only by the final phase's `deploy-headless.sh` auto-repair. The implementer stages only files this task edited; if the `line_count` diff after the deploy names entries this task never touched, that residue is pre-existing, recorded via `issue-record.sh`, and NOT hand-corrected |
| The inline reader in `validate-artifact.sh` is later wanted by a second consumer, making the inline choice look like under-engineering | L | M | The decision and its trigger condition (a second consumer) are recorded in the script's own header comment and in `repo-level-declarations.md`, so promotion is a mechanical move rather than a rediscovery |
| Bash `[[ path == glob ]]` matching lets `*` cross `/`, so a declared `trigger_glob` matches more broadly than POSIX pathname-expansion intuition suggests | L | H (certain) | Documented explicitly in the schema section as the matching semantics, with the advice to write the simplest glob; the check is advisory-only, so an over-broad trigger costs a warning, never a failure |
| A mid-task phase's `--only-gate 3,4` discharge reports a Rule R `line_count` FAIL for the file that phase just edited | L | H (certain) | Each such phase's verification criteria name that specific FAIL as EXPECTED and deferred to the final phase; any OTHER finding naming the phase's own files is a real defect to fix forward |
| The final phase's `deploy-headless.sh` run regenerates the whole deployed tree while another dispatch is live on this shared tree | M | L | The phase declares the `` `__WHOLE_TREE__` `` sentinel, which is exactly the admission signal that serializes it against another whole-tree claim; the phase's first task re-checks for foreign in-flight work and STOPS rather than proceeding if it finds any |
| `deploy-headless.sh`'s internal fast-gate surfaces pre-existing, unrelated FAILs (state counter drift, eager-context budget) and is read as this task's regression | M | M | The final phase's criteria require every red finding to be attributed: either it names a file this task touched (a real defect) or it is demonstrably pre-existing and recorded, never silently accepted |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 1, 4 |
| 4 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Coupled-Generated-Surface Obligation in plan-format.md [COMPLETED]

**Goal**: The `Files to modify` contract states a repo-agnostic obligation to declare and
schedule a coupled generated surface, with the commit-blocking / advisory asymmetry as its
load-bearing clause, plus the paired enforcement-level subsection the later advisory check is
advisory-side of.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/formats/plan-format.md`'s `Files to modify`
      block (currently the region holding "Correction-target existence obligation" and
      "Whole-tree-claim declaration rule") immediately before editing, per the territory contract.
      *(completed)*
- [x] Add a subsection **immediately after** the "Whole-tree-claim declaration rule" paragraph and
      **before** "**Consumers of this heading contract**", titled
      `**Coupled-generated-surface declaration obligation.**`, matching the shape of its two
      siblings (plain-language rule, worked consequence, pointer to the enforcement subsection).
      It must state: a phase whose edits move a quantity that a generated artifact DERIVES MUST
      declare that artifact's path in the same phase's `Files to modify` block; and when the
      check that detects the drift is COMMIT-BLOCKING (a pre-commit hook or equivalent), that
      phase MUST also schedule the regeneration step in that same phase, never in a later
      reconciliation phase. A check that is advisory-only or later-verification-only may
      legitimately be reconciled in a later phase, but the DECLARATION is owed either way.
      *(completed)*
- [x] State the two facts that make the rule non-obvious, without naming any one repository's
      paths as the rule's content: (a) a prose-only edit can be enough to move a derived quantity
      (a docstring addition changes a line count), so "I changed no code" is not a reason to skip
      the declaration; (b) the asymmetry is per-surface, so a phase touching two coupled surfaces
      can owe same-phase regeneration for one and legitimate deferral for the other. *(completed)*
- [x] Add one worked illustration drawn from THIS repository rather than from any consumer repo,
      so the subsection is self-demonstrating and repo-agnostic at once: an edit to an indexed
      `context/**` file moves that entry's `index-entries.json` `line_count`, which
      `check-extension-docs.sh` Rule R checks and `deploy-headless.sh` auto-repairs; it is not
      commit-blocking here, so it is declared with the reconciliation phase. *(completed)*
- [x] Add `### Enforcement level (Coupled generated surfaces)` immediately after the existing
      `### Enforcement level (Files to modify authoring shape)` subsection, following the same
      advisory-first template the four enforcement subsections on that page already use: warning
      via `log_warn` only, `--strict` promotion through the existing
      `total_issues = errors + warnings` branch, no new strictness logic, a named promotion
      criterion, and an honest statement that the residue is UNMEASURED at authoring time because
      no repository declares the key yet (do not invent a measured count). *(completed)*
- [x] Cross-reference `context/standards/repo-level-declarations.md` as the declaration point and
      `scripts/validate-artifact.sh` as the enforcing consumer, by name, so the three parts are
      navigable from any one of them. *(completed)*
- [x] Verify the added prose cites no task number and carries no draft-lineage/version language
      (`.claude/rules/no-task-references-in-deliverables.md`,
      `.claude/rules/no-record-versioning-in-deliverables.md`). *(completed: check-task-references.sh
      and check-record-versioning.sh both report zero findings for the new prose)*

**Timing**: 1 hour 15 minutes

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --only test-lean-challenge-snapshot.sh,test-orchestrate-build-dispatch.sh,test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh` is the covering check — `suite_selection_select` returns exactly these five suites for this phase's single touched path.

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` - new `Files to modify` subsection stating the coupled-generated-surface declaration obligation, plus the paired `### Enforcement level (Coupled generated surfaces)` subsection

**Verification**:
- The five suites named in the Tier Justification pass:
  `bash .claude/scripts/tests/run-all.sh --only test-lean-challenge-snapshot.sh,test-orchestrate-build-dispatch.sh,test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh` exits 0. The deployed entry point is named deliberately: it aggregates every extension's suites, so the lean-provided suite in this set resolves there and not under the core source store's own `tests/` directory.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` exits 0, OR its only finding naming this phase's file is the
  expected Rule R `line_count` mismatch for `formats/plan-format.md` (declared and reconciled in
  Phase 6); any other finding naming this file is a defect to fix forward.
- The new subsection sits between "Whole-tree-claim declaration rule" and "**Consumers of this
  heading contract**", and the new enforcement subsection sits immediately after "Enforcement
  level (Files to modify authoring shape)" — confirmed by reading the two boundary lines, not by
  assuming the insertion landed.
- `bash /home/benjamin/.config/nvim/.claude/scripts/check-task-references.sh --quiet` reports no
  finding for this file.

---

### Phase 2: Correct Condition 7 and Link Condition 1 to the General Rule [COMPLETED]

**Goal**: Condition 7 states the pinned `longFile` linter's real arithmetic and the incremental
re-tightening consequence; Condition 1 points at the new general obligation so the Lean instance
and the repo-agnostic rule are navigable from each other.

**Tasks**:
- [x] Re-read `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`
      immediately before editing (the file carries uncommitted foreign modifications in its own
      extension tree; confirm via `git status --short` that this specific file is not among them,
      and STOP and report if it is). *(completed: `git status --short` showed the file clean)*
- [x] Replace Condition 7's wrong acceptance-window sentence (`the linter accepts a baseline N
      only when N - 200 <= lines < N`) with the verified rule: `candidate = max(defValue,
      (lines / 100) * 100 + 200)` where `defValue` is `linter.style.longFileDefValue`
      (1500 by default), and the declared baseline `N` is accepted without warning only when
      `N == candidate` or `N + 100 == candidate` — i.e. exactly the two values
      `{candidate - 100, candidate}`. Any other value produces
      "The current limit is {N}, but it is expected to be {candidate}". *(completed)*
- [x] State the two reproductions as evidence, not as the derivation: 2967 lines against a 3400
      baseline yields `candidate = 3100`; 3200 lines against a 3200 baseline yields
      `candidate = 3400` (not 3300). Name the source the rule was read from — the pinned
      toolchain's own Mathlib checkout, `Mathlib/Tactic/Linter/Style.lean` at the rev the
      originating repository's `lake-manifest.json` pins for `leanprover/lean4:v4.33.0-rc1` — and
      note that the linter's internals can drift with a toolchain bump, so a plan author on a
      different pin re-reads the source rather than trusting the arithmetic quoted here.
      *(completed: both reproductions verified by hand against the pinned checkout's source)*
- [x] Correct the `longFile 0` sentence only if it is wrong (it is not: the pinned source returns
      early when `linterBound == 0`, so "turns the linter off rather than recording a ceiling" is
      accurate and stays). Do not rewrite accurate text. *(completed: left unchanged, confirmed
      accurate)*
- [x] Rewrite the "Plan-authoring consequence" clause to carry the incremental consequence
      explicitly: because `candidate` is a function of the file's CURRENT length, a single early
      bump to the final expected value is itself a new warning, so each phase that moves the
      file's line count owns its own re-tightening to that phase's own `candidate`. *(completed)*
- [x] Add one sentence to Condition 1, after its "Plan-authoring consequence" paragraph, pointing
      at `context/formats/plan-format.md`'s "Coupled-generated-surface declaration obligation" as
      the repo-agnostic statement of the same rule, with Condition 1 as this repository's
      instance of it. Do not restate the general rule here. *(completed)*
- [x] Verify the added prose cites no task number and carries no draft-lineage/version language.
      *(completed: check-task-references.sh and check-record-versioning.sh both report zero
      findings for the new prose)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this phase's single touched path (no suite covers it), so the covering check is sub-case (b): `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`, plus the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md` - Condition 7 rewritten with the verified `candidate`/±100 rule and the incremental re-tightening consequence; one pointer sentence added to Condition 1

**Verification**:
- Diff read-through confirms every changed hunk lies inside Condition 1's or Condition 7's prose,
  with Conditions 2-6 and 8-9 byte-identical (`git diff` shows no hunk outside those two
  sections).
- The corrected text reproduces both measurements when applied by hand: `(2967/100)*100+200 =
  3100` and `(3200/100)*100+200 = 3400`, and a declared `3300` against 3200 lines is rejected by
  `N == candidate || N + 100 == candidate`.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` exits 0, OR its only finding naming this file is the expected Rule R
  `line_count` mismatch (reconciled in Phase 6).
- `bash /home/benjamin/.config/nvim/.claude/scripts/check-task-references.sh --quiet` reports no
  finding for this file.

---

### Phase 3: Reach Mechanism in planner-agent.md, and the Named agents[] Hazard [COMPLETED]

**Goal**: A `lean4` (or any future domain's) plan dispatch surfaces that domain's
plan-authoring gotchas file before phase decomposition, via a `task_type`-gated lookup the plan
agent itself performs; and the reason the index-entries alternative was rejected is recorded
where the next author will look for it.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/agents/planner-agent.md`'s Stage 4 checklist (items
      1-12) and `agent-system/extensions/core/context/patterns/context-discovery.md`'s
      "Hook-Shape Policy" and "Check Command Scope" sections immediately before editing.
      *(completed)*
- [x] Add Stage 4 checklist item 13, `**Surface This Domain's Plan-Authoring Gotchas Before
      Decomposing**`, written GENERICALLY — keyed on the dispatch's own `task_type`, never on the
      literal string `lean4`: query the deployed context index
      (`.claude/context/index.json`) for a `project/**` entry whose `load_when.task_types[]`
      contains this dispatch's `task_type` AND whose `keywords[]` (or `topics[]`) name
      `plan-authoring`; `Read` every hit before decomposing phases; treat each enumerated
      condition in such a file as an additional checklist item for this plan. State the fallback
      explicitly: zero hits is the normal case for most task types and is not an error.
      *(completed)*
- [x] Give item 13 a `**MUST NOT**` clause in the same shape as items 9-12: do not resolve this
      by adding `planner-agent` to a domain entry's `load_when.agents[]` — the adaptive query ORs
      the agent, task-type and command dimensions, so a cross-domain shared agent in `agents[]`
      loads that domain's content into every other domain's plan dispatch. Point at
      `context/patterns/context-discovery.md` for the hazard. *(completed)*
- [x] Add Stage 4 checklist item 14, `**Declare a Coupled Generated Surface in the Phase That
      Moves Its Input**`, mirroring items 9-12's shape: when a phase's edits move a quantity a
      generated artifact derives, declare that artifact's path in the same phase's `Files to
      modify`, and schedule its regeneration in that same phase when the detecting check is
      commit-blocking. `**MUST NOT**`: do not defer a commit-blocking surface's regeneration to a
      later reconciliation phase, and do not omit the declaration for a non-blocking one. Point
      at `context/formats/plan-format.md`'s "Coupled-generated-surface declaration obligation".
      *(completed)*
- [x] Add a matching `**MUST NOT**` entry to the agent's `## Critical Requirements` list for the
      coupled-surface omission, consistent with how items 8-13 of that list already mirror
      Stage 4's obligations. *(completed: added as MUST NOT item 14)*
- [x] Add a short subsection to `context-discovery.md`, immediately after "Hook-Shape Policy:
      `agents[]` vs. `commands[]` vs. Both" (its nearest sibling in subject matter), naming the
      cross-domain-shared-agent hazard for the `agents[]` dimension: a domain-specific
      `project/**` entry must not add a cross-domain shared agent (`planner-agent`,
      `general-implementation-agent`, `general-research-agent`) to `agents[]`, because the
      adaptive query's OR semantics make that one clause sufficient on its own for every
      dispatch of that agent regardless of `task_type`; the sanctioned alternative is a
      `task_type`-gated pointer inside the shared agent's own file. Note why
      domain-exclusive agents (`lean-research-agent`, `lean-implementation-agent`) tolerate the
      OR harmlessly — they never run for a non-domain task. *(completed)*
- [x] Confirm `lean/index-entries.json` needs NO edit: its
      `project/lean4/patterns/plan-authoring-gate-collisions.md` entry already carries
      `task_types: ["lean4"]` and the `plan-authoring` keyword the new lookup keys on. Record
      that confirmation rather than editing the file. *(completed: confirmed via jq query; no
      edit made)*
- [x] Verify the added prose cites no task number and carries no draft-lineage/version language.
      *(completed: check-task-references.sh and check-record-versioning.sh both report zero new
      findings)*

**Timing**: 1 hour 15 minutes

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: this phase is hypothesized to touch exactly two files and to require NO edit to `lean/index-entries.json`, `lean/EXTENSION.md`, or any manifest. The implementer confirms the index-entries half by querying that entry for `task_types` and `keywords` before concluding no edit is needed, and confirms the two-file count with `git status --short` at phase end; if the lookup as written does not in fact match the existing entry, the correct repair is to the lookup's predicate in `planner-agent.md`, not to the lean entry's `agents[]` array (the rejected option).

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this phase's two touched paths together (no suite covers them), so the covering check is sub-case (b): `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`, plus the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/agents/planner-agent.md` - Stage 4 checklist items 13 and 14, plus one matching `MUST NOT` entry in Critical Requirements
- `agent-system/extensions/core/context/patterns/context-discovery.md` - new subsection naming the cross-domain-shared-agent hazard for the `agents[]` dimension

**Verification**:
- Diff read-through confirms every changed hunk is prose inside Stage 4's checklist, the Critical
  Requirements list, or the new `context-discovery.md` subsection; no stage numbering or existing
  checklist item is renumbered or reworded.
- The lookup predicate in item 13, executed by hand against the deployed index, returns the lean
  gate-collisions entry for `task_type=lean4` and returns nothing for `task_type=meta`:
  `jq '[.entries[] | select((.path|test("^project/")) and any(.load_when.task_types[]?; . == "lean4") and ((.keywords // []) + (.topics // []) | any(. == "plan-authoring")))] | length' .claude/context/index.json` is `1`, and the same query with `"meta"` is `0`.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` exits 0, OR its only finding naming either file is the expected
  Rule R `line_count` mismatch for `patterns/context-discovery.md` (reconciled in Phase 6).
- `bash /home/benjamin/.config/nvim/.claude/scripts/lint-agent-contracts.sh --verbose` reports no
  new finding against `planner-agent.md` relative to its pre-change output.
- `bash /home/benjamin/.config/nvim/.claude/scripts/check-task-references.sh --quiet` reports no
  finding for either file.

---

### Phase 4: Document the coupled_generated_surfaces Declaration Schema [COMPLETED]

**Goal**: `repo-level-declarations.md` documents a second sibling top-level key with its own
schema, matching behaviour, and fail-open-on-absence guarantee, so the check implemented in
Phase 5 has a declaration contract to read rather than invent.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/standards/repo-level-declarations.md`
      immediately before editing. *(completed)*
- [x] Generalize the document's framing minimally: its Overview currently records
      `derived_artifact_probes` as "the one declaration schema the agent system currently reads".
      Update that to name two, without restructuring the page or renarrating its history.
      *(completed)*
- [x] Add a `## The coupled_generated_surfaces Entry Schema` section after the existing
      `derived_artifact_probes` schema section, with the fielded contract:
      `trigger_glob` (string, required — a repo-root-relative glob identifying the SOURCE paths
      whose edits move a derived quantity), `generated_paths` (array of repo-root-relative
      strings, required — the derived artifacts that go stale), `commit_blocking` (boolean,
      optional, default `true` — whether the detecting check refuses the commit), `note` (string,
      optional, diagnostic output only, never interpreted). *(completed)*
- [x] State the matching semantics exactly, because they are not POSIX pathname expansion: a
      phase path matches when bash's `[[ path == glob ]]` matches, where `*` CROSSES `/`. So
      `FormalSystem/**/*.lean` and `FormalSystem/*.lean` are equally broad; write the simplest
      glob that expresses the intent and expect directory-crossing. *(completed)*
- [x] State the fail-open-on-absence guarantee in the same table shape the page already uses for
      `derived_artifact_probes`: no file, no `jq`, absent key, empty array, or a malformed entry
      each yield zero effect, with at most one named warning per dropped entry; a repository that
      declares nothing — this one included — is byte-for-byte unaffected. *(completed)*
- [x] State the one asymmetry against `derived_artifact_probes` explicitly: this declaration is
      read at PLAN-ACCEPTANCE time by an ADVISORY check and never executes a command, so it has
      no timeout, no privilege posture, and no blocking behaviour; the blocking promotion
      `derived_artifact_probes` carries does not extend to it. *(completed)*
- [x] Record why the two schemas are not unified: `derived_artifact_probes` has no
      trigger-pattern field because it answers "is this derived artifact stale now?" at
      postflight, whereas this one answers "did the author declare this derived artifact?" at
      plan acceptance. Keep both, and say so, so a future reader does not fold one into the other.
      *(completed)*
- [x] Record the single-consumer inline-reader decision and its promotion trigger (a second
      consumer), pointing at `scripts/validate-artifact.sh` as the reader's current home.
      *(completed)*
- [x] Add the new section to the page's `## See Also` list where appropriate, and verify the added
      prose cites no task number and carries no draft-lineage/version language. *(completed:
      check-task-references.sh and check-record-versioning.sh both report zero new findings)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this phase's single touched path (no suite covers it), so the covering check is sub-case (b): `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`, plus the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` - new `coupled_generated_surfaces` schema section, generalized Overview framing, and the non-unification + inline-reader decisions

**Verification**:
- Diff read-through confirms every changed hunk is prose, and that the existing
  `derived_artifact_probes` schema, fail-open table, bounded-execution section, and
  "This Is the System's First *Blocking* Staleness Gate" section are unchanged except for the
  Overview's two-schema framing.
- The documented schema is self-consistent with Phase 5's implementation: every field name and
  default in the section matches what the check actually reads (cross-checked after Phase 5
  lands, as part of Phase 6's reconciliation).
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` exits 0, OR its only finding naming this file is the expected Rule R
  `line_count` mismatch (reconciled in Phase 6).
- `bash /home/benjamin/.config/nvim/.claude/scripts/check-task-references.sh --quiet` reports no
  finding for this file.

---

### Phase 5: Advisory coupled_generated_surfaces Check in validate-artifact.sh [COMPLETED]

**Goal**: `validate-artifact.sh`'s per-phase `plan` loop warns when a phase's `Files to modify`
entries match a declared `trigger_glob` but omit one of that entry's `generated_paths`, reading
the repo's own declaration and failing open when there is none, with fixtures pinning every
branch.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/validate-artifact.sh`'s per-phase `plan` loop
      (the `Files to modify` presence check, the authoring-shape advisory scan, and the Tier
      Justification measurement check) and
      `agent-system/extensions/core/scripts/lib/derived-artifact-probe-lib.sh`'s
      `_derived_probe_load_entries_json` / `derived_probe_entries` pair immediately before
      editing. *(completed)*
- [x] Add an inline reader near the script's other lazy, fail-soft helpers, modeled on
      `_derived_probe_load_entries_json`: resolve the repo root by walking upward from the
      artifact path's directory and then from `$(pwd)` looking for `.claude-extensions.json`;
      read `.coupled_generated_surfaces // []`, coerce a non-array to `[]`, and return `[]` for
      every absence case (no file, no `jq`, unparseable JSON, absent key). Drop a malformed entry
      (missing/empty `trigger_glob`, `generated_paths` absent or not an array of non-empty
      strings) with ONE named warning naming the entry, never aborting the read. *(completed; a
      hard-crash-on-empty-repo_root defect in the first draft was caught and fixed during
      verification -- see the issue log)*
- [x] Add a header comment recording: the single-consumer inline decision, its promotion trigger
      (a second consumer promotes this to `scripts/lib/`), the fail-open posture, and the
      declaration point with a pointer to `context/standards/repo-level-declarations.md`.
      *(completed)*
- [x] Reuse the EXISTING `_ftm_block` body capture from the authoring-shape scan for the phase's
      entry lines rather than adding a second capture grammar; extract each entry's first
      backtick-delimited token with the same `sed -E` extraction already used there. *(completed)*
- [x] For each validated declaration entry, warn once per phase when at least one of the phase's
      extracted paths matches `trigger_glob` under `[[ path == glob ]]` and at least one of that
      entry's `generated_paths` is absent from the phase's extracted path set. The warning names
      the phase number, the matched trigger, every missing generated path, and — when
      `commit_blocking` is `true` — that same-phase regeneration is owed, not merely the
      declaration. Emit via `log_warn` only. *(completed)*
- [x] Skip the whole check, silently, when the reader yields `[]` — the state of every repository
      today, including this one. No warning, no info line, no behaviour change. *(completed,
      confirmed via byte-identical pre/post-change comparison)*
- [x] Update the script's usage/exit-code header only if the new check changes an exit code (it
      must not: advisory-only, `log_warn`, no new exit path, no `--fix` participation).
      *(completed: no header change, since no exit code changed)*
- [x] Add fixtures to `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh`
      following the file's existing helper/fixture idiom: (a) a declared trigger matched with the
      generated path MISSING warns; (b) the same declaration with the generated path PRESENT is
      silent (no false positive); (c) no declaration key at all is silent; (d) a malformed entry
      is dropped with its named warning while a sibling valid entry still applies; (e) the
      warning is promoted by `--strict` through the existing `total_issues` branch; (f) a phase
      whose paths match no trigger is silent. Each fixture synthesizes its own temporary repo root
      holding a `.claude-extensions.json` — this repository declares nothing and must not be
      edited to make a test pass. *(completed: all six CGS fixtures added and passing)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` and confirm
      every pre-existing assertion still passes alongside the new ones. *(completed: 145 passed,
      0 failed, up from 136 pre-change)*
- [x] Run `bash /home/benjamin/.config/nvim/.claude/scripts/lint-shellcheck.sh --verbose` scoped to the
      two edited scripts and confirm no new finding relative to their pre-change output.
      *(completed: 0 findings after adding one deliberate `shellcheck disable=SC2053` for the
      intentional unquoted glob match)*

**Timing**: 2 hours

**Depends on**: 1, 4

**Verification Tier**: local

**Scope Hypothesis**: this phase is hypothesized to touch exactly two files — the script and its test file — and to add NO new library file and NO manifest entry (see the plan's Research Integration note for why the library was rejected). The implementer confirms with `git status --short` at phase end; if the inline reader turns out to need a second consumer during this phase, that is the documented trigger to revisit the decision, which requires `core/manifest.json` and therefore a territory re-check against the concurrent sibling that declares it.

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --only test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-orchestrate-cycle-postflight.sh,test-validate-artifact.sh` is the covering check — `suite_selection_select` returns exactly these four suites for this phase's two touched paths.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-artifact.sh` - inline `coupled_generated_surfaces` reader plus the advisory per-phase declaration-completeness check in the existing plan loop
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` - six fixtures pinning the matched-and-missing warning, the no-false-positive case, the absent-key fail-open case, malformed-entry drop, `--strict` promotion, and the no-trigger-match case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` exits 0 with
  `FAILED: 0`, and its `PASSED` count exceeds the pre-change count by the number of added
  assertions.
- The four suites named in the Tier Justification pass:
  `bash .claude/scripts/tests/run-all.sh --only test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-orchestrate-cycle-postflight.sh,test-validate-artifact.sh` exits 0.
- Inertness in this repository, checked rather than assumed: running
  `bash agent-system/extensions/core/scripts/validate-artifact.sh specs/597_coupled_generated_surfaces_in_plan_authoring/plans/01_coupled-generated-surfaces-plan-authoring.md plan`
  from the repo root produces byte-identical output to the same invocation of the pre-change
  script (this repo declares no `coupled_generated_surfaces` key).
- `bash /home/benjamin/.config/nvim/.claude/scripts/lint-shellcheck.sh --verbose` reports no new
  finding for either edited script, and its exit status is checked, not only its output diffed.

---

### Phase 6: Reconcile the Coupled Surfaces, Deploy, and Run the Complete Gate Set [IN PROGRESS]

**Goal**: The deployed tree is regenerated from the source store, both coupled generated surfaces
this task trips are reconciled, and the complete gate set is green or every red finding is
attributed.

**Tasks**:
- [ ] Before anything else, check for foreign in-flight work on this shared tree: `git log
      --oneline -5`, `git status --short`. If a foreign commit, a foreign uncommitted
      modification to any file this task edited, or a running build this dispatch did not start
      is present, STOP and report rather than proceeding — a whole-tree regeneration is not safe
      to run over another writer's in-flight state.
- [ ] Cross-check Phase 4's documented schema against Phase 5's implementation field by field
      (`trigger_glob`, `generated_paths`, `commit_blocking`, `note`, the default, and the glob
      semantics). Any mismatch is fixed in whichever file is wrong, in this phase, before the
      deploy.
- [ ] Run `timeout 540 bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh` to
      regenerate the deployed `.claude/` tree from the source store, and record its exit status.
      Its documented side effect is the `line_count` auto-repair that reconciles the Rule R
      coupling for every context file this task edited; do NOT hand-edit any `line_count`.
- [ ] Inspect `git diff -- agent-system/extensions/core/index-entries.json
      agent-system/extensions/lean/index-entries.json`. Stage and commit only the `line_count`
      hunks for entries this task's own phases edited. If the deploy also repaired entries this
      task never touched, that residue is pre-existing (both files carried uncommitted foreign
      modifications before this task started): record it via `issue-record.sh` and leave it
      unstaged rather than absorbing it.
- [ ] Confirm each edited source-store file's content is present in the deployed tree
      (`.claude/context/formats/plan-format.md`, `.claude/agents/planner-agent.md`,
      `.claude/context/patterns/context-discovery.md`,
      `.claude/context/standards/repo-level-declarations.md`,
      `.claude/scripts/validate-artifact.sh`,
      `.claude/context/project/lean4/patterns/plan-authoring-gate-collisions.md`), which proves
      the edit target was the source store and that nothing was hand-authored under `.claude/**`.
- [ ] Run the complete gate set and attribute every finding: red findings naming a file this task
      touched are defects to fix forward; red findings naming nothing this task touched are
      recorded as pre-existing via `issue-record.sh`, never silently accepted and never claimed
      as green.
- [ ] Self-audit this plan against its own new obligation: confirm that Phase 6 declares both
      `index-entries.json` paths and the `` `__WHOLE_TREE__` `` sentinel, and that no earlier
      phase deferred a COMMIT-BLOCKING surface (neither coupling here is commit-blocking in this
      repository, which is the documented reason the deferral is legitimate). Record the audit
      result in the task's issue log.
- [ ] Attest the issue log explicitly: if nothing noteworthy arose in a phase, say so rather than
      recording nothing.

**Timing**: 45 minutes

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: this phase writes no source file of its own beyond the two `index-entries.json` `line_count` reconciliations the deploy performs; its other write is the whole-deployed-tree regeneration, declared below with the reserved sentinel. The implementer confirms with `git status --short` that no modification under `agent-system/` is attributable to this phase other than those two files.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the entire deployed `.claude/` tree, which is an implicit scope claim over that whole tree
- `agent-system/extensions/core/index-entries.json` - `line_count` reconciliation for the three edited core context files, written by the deploy's own auto-repair, never by hand
- `agent-system/extensions/lean/index-entries.json` - `line_count` reconciliation for the edited lean context file, written by the deploy's own auto-repair, never by hand

**Verification**:
- `timeout 540 bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh` exits 0; if it
  exits non-zero, its internal fast-gate findings are each attributed as above and the deploy's
  own file placement is separately confirmed to have landed.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh` (the complete gate set, not
  a subset, and with its exit status checked) is green, OR every red finding is demonstrably
  pre-existing and names no file this task touched. In particular Gate 3 reports no Rule R
  `line_count` finding for any file this task edited, and Gate 5 reports no content-hash
  inequality for any of them.
- `bash /home/benjamin/.config/nvim/.claude/scripts/check-task-references.sh --quiet` and the
  record-version check (`bash /home/benjamin/.config/nvim/.claude/scripts/check-record-versioning.sh
  agent-system/extensions`) report no BLOCKING finding for any file this task edited.
- `git diff --name-only` against this task's base commit lists exactly the six source-store files
  from Phases 1-5 plus the two `index-entries.json` files, and nothing else under
  `agent-system/`.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` exits 0 with
      `FAILED: 0`, including the six new coupled-surface fixtures.
- [ ] The new check is provably inert in a repository that declares nothing: pre-change and
      post-change `validate-artifact.sh` output on the same plan artifact is byte-identical in
      this repository.
- [ ] `--strict` promotes the new warning through the existing `total_issues = errors + warnings`
      branch, pinned by a fixture, with no new strictness logic added.
- [ ] The corrected Condition 7 reproduces both cited measurements by hand (2967 -> 3100;
      3200 -> 3400) and rejects 3300 at 3200 lines.
- [ ] The item 13 lookup predicate returns exactly the lean gate-collisions entry for
      `task_type=lean4` and nothing for `task_type=meta`.
- [ ] `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh` is green, or every red
      finding is attributed to pre-existing state naming no file this task touched.

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/plan-format.md` — coupled-generated-surface
  declaration obligation plus its paired enforcement-level subsection.
- `agent-system/extensions/core/agents/planner-agent.md` — Stage 4 items 13 and 14 and a matching
  Critical Requirements entry.
- `agent-system/extensions/core/context/patterns/context-discovery.md` — the
  cross-domain-shared-agent `agents[]` hazard.
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` — the
  `coupled_generated_surfaces` schema.
- `agent-system/extensions/core/scripts/validate-artifact.sh` — inline declaration reader and
  advisory per-phase check.
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` — six new fixtures.
- `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`
  — corrected Condition 7, Condition 1 pointer.
- `agent-system/extensions/core/index-entries.json`,
  `agent-system/extensions/lean/index-entries.json` — `line_count` reconciliation (deploy-written).
- Regenerated `.claude/` deploy tree (disposable artifact, not committed).

## Rollback/Contingency

Every phase is an additive edit to an existing file plus, in Phase 5, additive fixtures; nothing
is deleted and no existing behaviour is modified. Reverting any single phase is
`git revert` of that phase's own commit, which is scoped to that phase's declared files.

- If Phase 5's check produces a false positive against a real declaration shape discovered later,
  the check is advisory-only and can be left in place while the glob semantics documented in
  Phase 4 are tightened; no plan validation fails because of it.
- If Phase 6's deploy cannot run (nvim unavailable, a foreign writer live on the tree), the
  source-store edits from Phases 1-5 are already committed and correct; the deploy and the
  complete-gate-set discharge resume in a later dispatch, with the two `index-entries.json`
  `line_count` entries left stale and recorded rather than hand-edited.
- If a rollback of the whole task is wanted, revert the six source-store file commits in reverse
  order and re-run `deploy-headless.sh`; the deployed tree is regenerated from the source store,
  so it needs no separate rollback.
