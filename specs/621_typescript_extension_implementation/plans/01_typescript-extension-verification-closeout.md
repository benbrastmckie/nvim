# Implementation Plan: Task #621

- **Task**: 621 - Implement the typescript extension in the source store with parity plus a verification-stage gate
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: Task 620 (COMPLETED)
- **Research Inputs**: specs/621_typescript_extension_implementation/reports/01_typescript-extension-implementation-readiness.md
- **Artifacts**: plans/01_typescript-extension-verification-closeout.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The build work this task's dispatch describes is already complete: all 20 files named in the
dispatch's parity list exist in `agent-system/extensions/typescript/`, committed and clean, and
the four items `python` lacks (`hard_contracts`, `keyword_overrides`, `rules/typescript-rules.md`,
the `verification`-stage lifecycle hook) are all present and correctly declared. The one item
genuinely left open is the dispatch's own VERIFICATION clause — deploy the extension via the
loader and confirm the merge targets — which task 620 explicitly scoped out. This plan therefore
closes that gap rather than rebuilding anything: re-confirm the baseline has not drifted, execute
the deploy verification against a disposable scratch target and record the evidence under this
task's own artifacts, and durably capture the non-obvious `opencode.json.managed` gating behavior
in the extension's own README so the next person verifying it does not misdiagnose a correctly
gated no-op as a broken merge target. Done means: baseline re-confirmed clean, all four merge
targets observed working with evidence recorded, and the full gate set green.

### Research Integration

The research report drives this plan's sizing directly. Its file-by-file inventory
(20/20 present), its manifest diff against `python` (all four parity-plus items confirmed), its
9/9 `index-entries.json` `line_count` match, and its five-lint re-run (all passing) together
establish that no build work remains. Its live headless `manager.load` test against a scratch
target — the dispatch's VERIFICATION clause, executed directly — confirmed all three named merge
targets plus `opencode_json`. The report's single most actionable discovery is the
`opencode.json.managed` gating in `merge.lua`'s `generate_opencode_json` (Step 1.2): without that
marker file in the target, the function returns `ok=true` and writes nothing, which reads as a
defect to a tester who does not know about it. Phase 2 reproduces the report's test procedure
rather than re-deriving it; Phase 3 makes that discovery durable.

### Prior Plan Reference

No prior plan exists for this task. Task 620's plan
(`specs/620_typescript_extension_design/plans/01_typescript-extension-build.md`) is the artifact
that produced the extension and is cited here as the authoritative file-list comparator via the
research report, not as a template. Its effort calibration is the relevant lesson: 620 absorbed
the entire build cost, which is exactly why this task's remaining cost is small.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed. `specs/ROADMAP.md` exists in this repository but was deliberately not read or
modified.

## Goals & Non-Goals

**Goals**:
- Re-confirm, freshly in this task's own lifecycle, that `agent-system/extensions/typescript/` is
  complete, clean, and passing every available lint — no drift since the research pass.
- Execute the dispatch's VERIFICATION clause and record the evidence against this task's own
  artifacts rather than leaving it attributed only to a research report.
- Durably capture the `opencode.json.managed` gating behavior and the scratch-target headless
  verification procedure in the extension's own README.
- Close the task with the complete gate set green.

**Non-Goals**:
- Re-creating or rewriting any of the 20 extension files. They exist, match the plan they came
  from, and pass every lint; re-creating them is redundant work against a clean baseline.
- Loading the `typescript` extension into this repository (or any real repository) via
  `.claude-extensions.json`. That is a user-driven decision, as task 620's summary already
  recorded; verification here uses a disposable scratch target only.
- Writing anything to any repository's `.claude/` deploy tree. All source-store writes go to
  `agent-system/extensions/typescript/`.
- Documenting the generic extension-verification procedure in core's own
  `context/guides/extension-development.md`. The research report recommends this as a context
  extension, but it lands outside this task's declared `file_scope`
  (`agent-system/extensions/typescript/`) and belongs in a follow-up task rather than widening
  this one's territory.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer reads the dispatch's "create in full" literally and rebuilds the 20 files, introducing drift against a passing baseline | H | M | Phase 1 runs first and its output is the explicit precondition for Phases 2-3; the plan's Non-Goals state the prohibition directly |
| Phase 2's deploy test is run against this repository or the source store instead of a scratch directory, polluting a real tree | H | L | Phase 2's tasks name the scratch target explicitly and require it to be created under the session scratchpad and deleted afterward; `__WHOLE_TREE__` is deliberately NOT declared because no real deployed tree is regenerated |
| `opencode.json` merge target is misdiagnosed as broken because the `.managed` marker is absent | M | M | Phase 2 creates the marker explicitly before testing that target; Phase 3 writes the behavior into the README |
| Baseline has drifted between the research pass and this dispatch (another session touched the tree) | M | L | Phase 1 is a fresh `git status --short` plus a fresh lint re-run, not a citation of the report's results |
| Phase 3's source-store edit trips the completion-deploy gate's stale-deploy refusal (exit 6) | L | M | Known self-healing: the next cycle's Inter-Cycle Redeploy Checkpoint deploys and reconciles the task on its own; no manual deploy is required and none should be improvised |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Re-Confirm the Baseline Has Not Drifted [COMPLETED]

**Goal**: Establish, freshly in this dispatch rather than by citing the research report, that the
typescript extension tree is complete, committed, and passing every available lint — so Phases 2
and 3 build on a confirmed-clean baseline.

**Tasks**:
- [x] Run `git status --short -- agent-system/extensions/typescript/` and
      `git diff --stat HEAD -- agent-system/extensions/typescript/`; both must be empty. If
      either is non-empty, STOP and record the unexpected change before proceeding — do not
      silently absorb it. *(completed: both empty)*
- [x] Run `find agent-system/extensions/typescript -type f | sort` and confirm the file inventory
      against the research report's list (expected: 20 files). *(completed: 20 files confirmed)*
- [x] Confirm each `index-entries.json` entry's `line_count` against a live `wc -l` of its file
      (expected: 9 entries, zero mismatches). *(completed: 9/9 match)*
- [x] Confirm `manifest.json` still declares all four parity-plus items: `hard_contracts`,
      `keyword_overrides`, `provides.rules` containing `typescript-rules.md`, and the **top-level**
      `hooks.verification` key pointing at `scripts/typescript-verify.sh`. Note the two-place
      declaration: `provides.hooks` is `[]` by design and is NOT where the verification hook
      lives — a check that looks only there will wrongly report the hook missing. *(completed: all four confirmed present and correctly declared)*
- [x] Re-run the five lints: `lint-routing-wiring.sh`, `lint-extension-readme-table.sh`,
      `lint-agent-contracts.sh`, `lint-shellcheck.sh` (over `scripts/typescript-verify.sh`), and
      `check-extension-docs.sh`. Record pass/fail for each. *(completed: all 5 PASS — see Verification section below)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts 20 files, 9 `index-entries.json` entries with zero
`line_count` mismatches, and 5 passing lints, all carried from the research report. These are
hypotheses about the tree as it stood at research time, not facts about the tree at
implementation time — the phase's own commands are what confirm them, and a mismatch is a finding
to record, not a number to adjust silently.

**Tier Justification**: This phase modifies no file at all, so `suite_selection_select` has no
touched path to map and no suite covers it; the covering checks are the five lint commands the
task list names, whose output is the phase's entire deliverable.

**Files to modify**:
- none planned — this phase is read-only re-confirmation and writes nothing.

**Verification**:
- `git status --short -- agent-system/extensions/typescript/` and
  `git diff --stat HEAD -- agent-system/extensions/typescript/` both produce empty output.
- File count is 20; `index-entries.json` line counts match with zero mismatches.
- All five lints report PASS (`lint-agent-contracts.sh` may report pre-existing warnings; zero
  failures is the bar).

---

### Phase 2: Execute the Deploy Verification and Record the Evidence [NOT STARTED]

**Goal**: Perform the dispatch's own VERIFICATION clause — deploy the extension via the loader
and confirm the merge targets — against a disposable scratch target, and record the observed
evidence under this task's own `records/` directory so the result is attributable to this task
rather than only to a research report.

**Tasks**:
- [ ] Create a disposable scratch git repository under this session's scratchpad directory. It
      MUST NOT be this repository, any consumer repository, or anywhere under the source store,
      and it MUST NOT be registered in any `.claude-extensions.json`.
- [ ] Load `core` then `typescript` into that scratch target using the same headless Lua call
      `deploy-headless.sh` itself uses: `manager.load(name, {confirm=false, force=true,
      project_dir=SCRATCH})` via `nvim --headless`. Confirm `DEPLOY_OK`.
- [ ] Confirm merge target 1 (installed files): the scratch `.claude/` tree contains both agents,
      both skill directories, `rules/typescript-rules.md`, `scripts/typescript-verify.sh`, the
      contract file, and the full 8-file `context/project/typescript/` subtree — all correctly
      scoped under `.claude/`, with no duplicate at the target root.
- [ ] Confirm merge target 2 (`claudemd`): a `## TypeScript Extension` section is present in the
      generated `.claude/CLAUDE.md`, sourced from `EXTENSION.md`.
- [ ] Confirm merge target 3 (`index`): the generated `.claude/context/index.json` carries all 9
      `typescript`-tagged entries, matching `index-entries.json`.
- [ ] Confirm merge target 4 (`opencode_json`): create `opencode.json.managed` in the scratch
      target FIRST, then re-run the load. Without that marker, `merge.lua`'s
      `generate_opencode_json` (Step 1.2, managed/unmanaged gating) returns `ok=true` and writes
      no file — a correctly gated no-op, not a defect. With the marker present, confirm the
      regenerated `opencode.json` carries both `typescript-research` and
      `typescript-implementation` agent keys.
- [ ] Write the observed evidence (command shapes, per-target result, any deviation) to
      `specs/621_typescript_extension_implementation/records/deploy-verification-evidence.md`.
- [ ] Delete the scratch repository and every file it generated.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts four merge targets and an installed-file set of 16 files
under the scratch target's `.claude/`, both carried from the research report. The implementer
confirms each by direct inspection of the scratch tree and records what was actually observed; a
differing count is a finding for the evidence record, not a number to restate from this plan.

**Tier Justification**: The only file this phase writes lies entirely under `specs/**`, for which
`suite_selection_select` returns `__FULL_SWEEP__` (no suite covers it) and which is the
task-reference lint's own exempt tree, so the honest covering check is the `prose` row's diff
read-through of the new record — the deploy observations themselves are this phase's verification
criteria below, not a test suite.

**Files to modify**:
- `specs/621_typescript_extension_implementation/records/deploy-verification-evidence.md` - create; the observed per-merge-target evidence from the scratch deploy, including the `opencode.json.managed` gating behavior

**Verification**:
- `manager.load` reports `DEPLOY_OK` for both `core` and `typescript`.
- All four merge targets confirmed in the scratch tree, with `opencode_json` confirmed only after
  the `.managed` marker exists.
- The evidence record exists, is non-empty, and names each target's observed result.
- The scratch directory no longer exists; `git status --short` in this repository shows no
  stray artifact from the test.
- `__WHOLE_TREE__` is deliberately not declared for this phase: the loader runs against a
  disposable directory outside every repository, so no real deployed tree is regenerated and no
  whole-tree scope claim is made.

---

### Phase 3: Record the Verification Procedure in the Extension README and Close the Gate [NOT STARTED]

**Goal**: Make the scratch-target verification procedure and the `opencode.json.managed` gating
behavior durably discoverable from the extension itself, then close the task with the complete
gate set green.

**Tasks**:
- [ ] Extend the `## Verification` section of
      `agent-system/extensions/typescript/README.md` with a short subsection covering: the
      headless `manager.load` scratch-target invocation shape, the four merge targets to confirm,
      and the `opencode.json.managed` gating requirement for the `opencode_json` target. Keep it
      specific to verifying THIS extension; the generic, reusable procedure belongs in a
      follow-up task against core's `context/guides/extension-development.md`, which is out of
      scope here.
- [ ] Correction-target check: the `## Verification` section was confirmed present in
      `README.md` at planning time. If it is absent when this phase runs, add the new content as
      its own `## Verification` section rather than skipping the task or inventing a different
      target.
- [ ] Coupled-generated-surface check: `README.md` is NOT among `index-entries.json`'s 9 entries
      (confirmed at planning time — those are the 8 `project/typescript/**` context files plus
      the 1 contract file), so this edit moves no `line_count` and `index-entries.json` is
      correctly absent from this phase's file list. If that turns out not to hold when the phase
      runs, declare `index-entries.json` and reconcile it in this same phase.
- [ ] Re-run `check-extension-docs.sh` and `lint-extension-readme-table.sh` to confirm the README
      edit broke neither the per-extension docs rules nor the registry table.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` from the repository root.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly one modified file,
`agent-system/extensions/typescript/README.md`, and deliberately excludes `EXTENSION.md` (editing
it would push this content into every consumer's merged `CLAUDE.md`, an ambient cost this
discovery does not warrant) and `index-entries.json` (per the coupled-surface check above). The
task list above requires neither of those two files, consistent with this exclusion.

**Files to modify**:
- `agent-system/extensions/typescript/README.md` - extend the existing `## Verification` section with the scratch-target headless deploy procedure and the `opencode.json.managed` gating note

**Verification**:
- `README.md`'s `## Verification` section names the `manager.load` scratch-target invocation, the
  four merge targets, and the `.managed` marker requirement.
- `check-extension-docs.sh` reports PASS for `typescript`.
- `lint-extension-readme-table.sh` reports 0 violations.
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set, run from the repository root so
  the source-store-only gates resolve rather than SKIP) exits 0. A gate-6 style stale-deploy
  finding arising solely from this source-store edit is the known self-healing case — the next
  cycle's Inter-Cycle Redeploy Checkpoint reconciles it; do not improvise a manual deploy.

---

## Testing & Validation

- [ ] `git status --short -- agent-system/extensions/typescript/` empty at Phase 1 and again
      before Phase 3's commit (modulo Phase 3's own intended README change).
- [ ] 20-file inventory and 9/9 `index-entries.json` line counts confirmed live.
- [ ] Five lints pass: `lint-routing-wiring.sh`, `lint-extension-readme-table.sh`,
      `lint-agent-contracts.sh`, `lint-shellcheck.sh`, `check-extension-docs.sh`.
- [ ] All four merge targets (`.claude/` files, `claudemd`, `index`, `opencode_json`) confirmed
      end-to-end against a disposable scratch target, with evidence recorded.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0.

## Artifacts & Outputs

- `specs/621_typescript_extension_implementation/records/deploy-verification-evidence.md` — the
  recorded deploy-verification evidence (new).
- `agent-system/extensions/typescript/README.md` — extended `## Verification` section (modified).
- `specs/621_typescript_extension_implementation/summaries/01_*-summary.md` — the implementation
  summary, which should state plainly that this task closed as a verification pass over an
  already-built extension rather than as a build.

## Rollback/Contingency

Phase 1 and Phase 2 write nothing into the source store; Phase 2's only repository write is a new
file under `specs/**`, and its scratch target lives outside every repository. Rolling back either
phase therefore means deleting the evidence record — no git operation on the working tree is
needed or warranted.

Phase 3's single README edit is reverted with a targeted `git checkout HEAD --
agent-system/extensions/typescript/README.md` once the surrounding tree is clean. If uncommitted
work elsewhere makes that a destructive operation on a dirty tree, take a durable non-reverting
checkpoint first (`bash .claude/scripts/git-snapshot.sh 621 --no-revert`) rather than the default
reverting form; for a genuine whole-tree rollback see `context/contracts/recovery.md`'s rollback
rung for the correct invocation shape, including its out-of-scope override flag.

If Phase 1 finds unexpected drift in the extension tree, do not proceed to Phases 2-3: record the
drift, mark the task `[PARTIAL]`, and surface it — an unexplained change to a committed, lint-clean
baseline is a finding that needs a decision, not an obstacle to work around.
