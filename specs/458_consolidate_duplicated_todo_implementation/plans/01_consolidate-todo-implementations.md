# Implementation Plan: Task #458

- **Task**: 458 - consolidate_duplicated_todo_implementation
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None live (459 is complete; 626 depends on this task, not the reverse)
- **Research Inputs**: specs/458_consolidate_duplicated_todo_implementation/reports/01_consolidate-todo-implementations.md
- **Artifacts**: plans/01_consolidate-todo-implementations.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Collapse the two divergent `/todo` implementations into one authoritative implementation by
keeping `agent-system/extensions/core/commands/todo.md` (the only copy either consumer system
actually dispatches) and removing `skills/skill-todo/SKILL.md` **together with** its
`manifest.json` registration and every registry, lint, test and prose reference that would
otherwise dangle. The `archived_projects`-blind orphan/misplaced-directory bug is fixed once, in
the survivor, before the duplicate is removed, so the fix is validated against a live dispatched
file rather than ported from a file about to be deleted. The change is net deletion of roughly a
thousand lines. Two redeploys are scheduled, not one: the deregistration phase must redeploy to
reach a green tree at all (the deploy script is additive, so a deleted source file leaves a
deployed orphan), and the final phase redeploys again to propagate the prose reconciliation.

### Research Integration

The research report re-measured every dispatch figure against the live source store and this plan
is built on the re-measured values, not the dispatch's 2026-11-02 snapshot. Carried figures
re-confirmed independently at plan time (2026-11-13):

| Claim | Dispatch value | Live value at plan time | Verdict |
|-------|----------------|--------------------------|---------|
| `commands/todo.md` line count | 886 | 886 | unchanged |
| `skills/skill-todo/SKILL.md` line count | 1120 | **1027** | superseded (research is right) |
| Combined footprint | 2006 | **1913** | superseded |
| `skill-todo` occurrences in `commands/todo.md` | 0 | 0 | unchanged |
| `CHANGE_LOG` occurrences in `commands/todo.md` | 0 | 0 | unchanged |
| Defective jq sites in `commands/todo.md` | lines 71, 88, 127 | lines 71, 88, 127 | unchanged |
| Defective jq sites in `skill-todo/SKILL.md` | lines 246, 263, 294 | lines 246, 263, 294 | unchanged |
| `system-overview.md` misleading routing row | line 417 | line 417, text verbatim `\| /todo \| Direct \| skill-todo \| (no agent) \| B \|` | unchanged |
| `manifest.json` registration | present | line 82, inside `extension.skills[]` | confirmed |
| Collision field "clear" | clear | **NOT clear**: task 626 (`not_started`) names `skills/skill-todo/SKILL.md` in `file_scope` | superseded, not a hazard (626 carries `dependencies: [625, 436, 458]`) |
| `state-management-schema.md` needs correction | yes | **no** — line 398 already names `commands/todo.md`'s Step 5.7.7 as the live renumbering path | superseded; zero edit needed there |

Two findings added at plan time beyond the research report:

1. **Deleting the source file is not enough to clear verify-deploy.** `deploy-headless.sh` is
   additive ("never removes anything"), while verify-deploy Gate 13 (`find_orphans`) fails on any
   deployed-but-undeclared file. The deployed `.claude/skills/skill-todo/SKILL.md` must be purged
   explicitly, in the same phase as the redeploy. Without this step the final gate fails by
   construction.
2. **Adding a new test suite carries a data obligation.** `scripts/tests/suite-classification.data`
   requires one row per discovered suite (`lint-unit-integration-boundary.sh` fails loudly on an
   unclassified suite), and `scripts/tests/*.sh` is the declared target of verify-deploy gates 27
   (subject-resolution declaration) and 29 (test-suite root resolution). Both are scheduled in the
   same phase that adds the test file.

### Prior Plan Reference

No prior plan. The abandoned record this revives (`todo_consolidate_and_optimize`) left an empty
artifact directory — no report, plan or summary to calibrate against.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch and no roadmap flag is set; this plan adds no
roadmap-review or roadmap-update phase.

## Goals & Non-Goals

**Goals**:
- One authoritative `/todo` implementation: `agent-system/extensions/core/commands/todo.md`.
- `skill-todo` deliberately and completely deregistered — never registered-but-absent, never
  present-but-unregistered.
- The `archived_projects`-blind detection bug fixed once, across all three scans, in the survivor,
  pinned by a test that demonstrates an abandoned-then-archived directory is no longer reported as
  an orphan.
- The vault operation existing in exactly one live place, with
  `context/reference/state-management-schema.md` naming that place correctly.
- `context/architecture/system-overview.md`'s `/todo` routing row stating what is actually true.
- A reported net-line figure (before, after, delta).
- A clean `verify-deploy.sh` after a `deploy-headless.sh` redeploy.

**Non-Goals**:
- Fixing `specs/CHANGE_LOG.md` staleness, or deciding whether CHANGE_LOG should exist. That
  question is owned by `cross_task_traceability_and_changelog_verdict` and this plan must not
  prejudge it. Removing `skill-todo`'s never-dispatched CHANGE_LOG stages changes no runtime
  behavior, because they have never run.
- Touching the three email-extension files that cite `skill-todo` as a design pattern. They belong
  to another extension and are outside this task's blast radius.
- Editing `.opencode/**` or reconciling the OpenCode deploy tree's own diverged `/todo` copy.
- Editing task 626's description, `file_scope` or plan. Its re-pointing is flagged, never
  performed from here.
- Porting `skill-todo`'s "TODO.md orphan" detection into the survivor (see Decisions).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deployed `.claude/skills/skill-todo/SKILL.md` survives the redeploy and trips Gate 13 orphan detection | H | H | Phase 2 explicitly purges the deployed copy before its redeploy and full gate; the gate-13 result is the check |
| A prose reference to `skill-todo` is missed and dangles | M | M | Phase 3 runs `audit-deletion-references.sh skill-todo` (literal + glob + reachability passes) as its own completion check, not a grep by hand |
| Deregistering the skill breaks `Skill(skill-todo)` for a caller that exists but was not found | M | L | Research confirmed zero dispatch sites across both consumer systems; the dispatch's own acceptance criterion sanctions complete deregistration as one of the two allowed outcomes |
| Re-grounding `task-reference-exemptions.md`'s `.memory/**` evidence invents a claim | M | M | That passage already cites a stage removed on 2026-11-10; Phase 3 instructs stating plainly that no live writer anchors it rather than naming a substitute that may not exist |
| Removing the Stage 15 shape from `test-todo-move-pair-staging.sh` loses assertion intent | M | L | The three surviving site shapes (Step 5D/5E.1/5F) already pin the same rule; the intent (every move pairs destination with vacated source) is preserved, which is what the acceptance criterion requires |
| New test file fails gates 27/29 (subject-resolution and root-resolution declarations) | L | M | Phase 1 models the new suite on `test-todo-move-pair-staging.sh`'s `common_test_resolve_subject` header and runs gates 27/29 in-phase |
| Net-line figure shows no reduction, meaning the work became a rewrite | M | L | Phase 4 reports the measured figure; a non-reducing result is a re-scope signal, stated in that phase's verification |
| `__WHOLE_TREE__` in this task's harvested `file_scope` makes its lock collide with every held task lock | M | M | Accepted and declared honestly; the token is required by the whole-tree-claim rule and is slashless, so it stays inert against every real path predicate |

## Decisions

- **`commands/todo.md` is the survivor; `skill-todo` is removed outright (option (b)).** It is the
  only implementation either consumer system dispatches; it is smaller (886 vs. 1027 lines); its
  own self-description carries no stale claims, unlike `skill-todo`'s frontmatter, which still
  advertises a memory-harvest stage removed on 2026-11-10; and
  `context/reference/state-management-schema.md` already names it as the live vault-renumbering
  path, so keeping it requires zero change to that document. A thin delegator (option (a)) would
  leave a second registered entry point with no consumer, against the net-deletion framing.
- **The vault operation needs no document correction.** `state-management-schema.md`'s "Renumber
  survival" paragraph (line 398) already names `commands/todo.md`'s Step 5.7.7 as the live
  renumbering path and already quarantines `scripts/deprecated/vault-operation.sh`. Removing
  `skill-todo`'s stage-10 copy leaves exactly one live implementation and makes that paragraph
  true rather than merely accurate-by-luck. This plan edits that file zero times; the acceptance
  criterion is satisfied by the removal, not by an edit.
- **`skill-todo`'s "TODO.md orphan" detection is dropped as obsolete, not ported.** TODO.md is
  generated from state.json; a TODO.md entry with no state.json entry is erased by the next
  `generate-todo.sh` run rather than persisting to be archived, so the condition is structurally
  unreachable under current tooling. The detection has never executed, because the skill carrying
  it has never been dispatched. Porting it would add roughly fifty lines to the survivor against
  this task's net-deletion framing, to guard a condition the generator already forecloses. This is
  stated here so the capability's disappearance is a recorded decision, not a silent side effect.
  `test-validate-state.sh`'s fixture (h) is **kept** — it pins the archive *validator's* tolerance
  of a sparse `created_at` / no-`task_type` entry shape that exists in historical archive data
  regardless of which implementation once produced it; only its comment's attribution changes.
- **Correcting `engine-written-state-paths-lib.sh`'s CHANGE_LOG comment does not prejudge the
  CHANGE_LOG verdict.** That comment asserts `specs/CHANGE_LOG.md` is "written only at archival
  (skill-todo)". After removal that is factually false. Stating that no live path writes it is a
  factual correction; whether it *should* be written remains entirely with
  `cross_task_traceability_and_changelog_verdict`.
- **Task 626 is flagged, not fixed.** It names `skills/skill-todo/SKILL.md` in its `file_scope`
  and already carries `dependencies: [625, 436, 458]`, so it is correctly sequenced after this
  task. Its wiring target must become `commands/todo.md`; that re-pointing belongs to whoever next
  revises 626, and this plan performs no edit to 626's record.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Fully sequential: each phase's subject either is created by, or is made true by, the phase before
it. Phases within the same wave could run in parallel; no wave here holds more than one phase.

---

### Phase 1: Fix the `archived_projects`-Blind Scans in the Survivor [COMPLETED]

**Goal**: `commands/todo.md`'s three detection scans read both archive arrays, and a test
demonstrates that an abandoned-then-archived task directory is no longer reported as an orphan.

**Tasks**:
- [x] Re-derive the three jq filter line numbers in
      `agent-system/extensions/core/commands/todo.md` with
      `grep -n 'completed_projects\[\]' agent-system/extensions/core/commands/todo.md` before
      editing. Expected at plan time: lines 71 (orphans-in-specs), 88 (orphans-in-archive), 127
      (misplaced-directory scan, section 2.6). Edit by matched text, never by line number alone.
      *(completed: confirmed unchanged at lines 71, 88, 127)*
- [x] At each of the three sites, replace the array selector
      `.completed_projects[]` with `(.completed_projects + .archived_projects)[]` inside the
      existing one-line filter, leaving the rest of the expression untouched. These three sites
      are the read-back scans only; do NOT touch the archive-WRITE jq at lines 378, 390 and 515,
      nor the vault count at 638 or the reinit at 657 — the write path is already correct and
      populates both arrays. *(completed)*
- [x] Create `agent-system/extensions/core/scripts/tests/test-todo-archived-projects-scan.sh`,
      modelled structurally on `scripts/tests/test-todo-move-pair-staging.sh`: resolve its subject
      via `common_test_resolve_subject` (gate 27's declaration requirement) and resolve its repo
      root by the same convention that file uses (gate 29). *(completed)*
- [x] Give the new suite a BEHAVIORAL half: build a throwaway `specs/archive/state.json` fixture
      holding one entry in `archived_projects[]` and one in `completed_projects[]`, run the fixed
      filter against it, and assert BOTH are found (i.e. neither is reported as an orphan). Add
      the negative control: run the old `.completed_projects[]`-only filter against the same
      fixture and assert it MISSES the `archived_projects[]` entry. A negative control that passes
      as positive is itself a suite failure — it would mean the suite could not have caught the
      live defect. *(completed)*
- [x] Give the new suite a STATIC half over the real recipe text: assert that
      `commands/todo.md` contains zero remaining bare `.completed_projects[] | select(.project_number`
      read-back filters, and that all three surviving read-back sites name both arrays.
      *(completed)*
- [x] Add one TAB-separated row for the new suite to
      `agent-system/extensions/core/scripts/tests/suite-classification.data`, classified `unit`
      (it spawns none of `deploy-headless.sh`, `verify-deploy.sh`, `run-all.sh`), with a reason
      field in the style of the rows already present. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: three defective read-back sites exist in `commands/todo.md` (expected at
lines 71, 88 and 127) and the fix is a zero-net-line token swap at each. Confirm at
implementation time by re-running the `grep -n` in the first task and by checking the post-edit
diff is three single-line hunks with no line-count change; if a fourth read-back site or a
structural rewrite is required, stop and re-scope rather than widening silently.

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel for this
phase's touched paths — the new suite does not exist on disk at plan time — so no suite is
claimed to cover them, and the covering check is
`bash .claude/scripts/verify-deploy.sh --only-gate 3,4,22,27,29`, which exercises doc-lint, the
task-reference lint, shellcheck, and the subject-resolution and root-resolution declarations the
new source-store test file must satisfy.

**Files to modify**:
- `agent-system/extensions/core/commands/todo.md` - all three read-back jq filters switched to
  the both-arrays selector
- `agent-system/extensions/core/scripts/tests/test-todo-archived-projects-scan.sh` - NEW:
  behavioral fixture (positive + negative control) plus static recipe-text assertions
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - one new `unit` row for
  the new suite (coupled data surface; `lint-unit-integration-boundary.sh` requires a row for
  every discovered suite, so the row lands in the same phase that creates the suite)

**Verification**:
- `grep -c '\.completed_projects\[\] | select(\.project_number' agent-system/extensions/core/commands/todo.md`
  returns 0.
- `verify-deploy.sh --only-gate 3,4,22,27,29` exits 0.
- Additionally (coverage beyond the declared tier, not a substitute for it): the new suite and
  `test-todo-move-pair-staging.sh` both pass under
  `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-todo-archived-projects-scan.sh,test-todo-move-pair-staging.sh`,
  with the new suite's negative control detecting the old filter's blindness.

---

### Phase 2: Remove `skill-todo`, Deregister It, and Redeploy to a Clean Tree [COMPLETED WITH EXCLUSIONS]

**Goal**: `skills/skill-todo/SKILL.md` no longer exists in the source store, no mechanical
registry (manifest, lint allowlist, test subject) still claims it, and the deployed tree carries
no residue of it.

**Why the redeploy lands in this phase rather than at the end**: `deploy-headless.sh` is additive
and never removes anything, while verify-deploy Gate 13 (`find_orphans`) fails on any
deployed-but-undeclared file. Deleting the source file without purging and redeploying leaves a
tree in which the complete gate battery cannot pass — so a manifest deregistration and its
redeploy are one unit of work, not two.

**Tasks**:
- [x] Delete `agent-system/extensions/core/skills/skill-todo/SKILL.md` and the now-empty
      `skills/skill-todo/` directory. Confirm first that `SKILL.md` is the directory's only file
      (verified at plan time; re-check with `ls -A`). *(completed: 1027 lines deleted)*
- [x] Remove the `"skill-todo",` element from `agent-system/extensions/core/manifest.json`'s
      `extension.skills[]` array (expected at line 82, between `"skill-telemetry"` and
      `"skill-zulip"`). Re-derive the line; edit the matched element, keeping the array's JSON
      valid and its surrounding formatting untouched. *(completed: confirmed at line 82)*
- [x] Remove the
      `"agent-system/extensions/core/skills/skill-todo/SKILL.md"` entry from
      `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh`'s exemption
      registry (expected at line 224). Leave the `commands/todo.md` and
      `scripts/deprecated/vault-operation.sh` siblings and the explanatory comment block above
      them in place — that exemption is about the vault-restore `mv`, which the survivor still
      carries. *(completed)*
- [x] Remove the "Stage 15 shape" from
      `agent-system/extensions/core/scripts/tests/test-todo-move-pair-staging.sh`: its
      `SKILL_MD` subject resolution (expected lines 68-70), its behavioral pair, its static half
      (expected lines 256-303), and the two header bullets that enumerate it (expected lines 26-27
      and 39-40). Leave the Step 5D / 5E.1 / 5F shapes and the suite's own framing intact. Update
      the header's opening sentence so it no longer describes the defect as affecting "both of
      /todo's recipe copies". *(completed: 24/24 cases pass, three surviving site shapes with
      negative controls intact)*
- [x] Run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/audit-deletion-references.sh skill-todo`
      and capture the triage checklist. Do NOT act on its prose hits in this phase — they are
      Phase 3's work. Record the hit list so Phase 3 has a measured target set rather than a
      re-derived one. *(completed: 25 literal hits captured, matching the four-mechanical-
      registration Scope Hypothesis -- no fifth registration found; hits are either Phase 3's
      prose/comment targets or the three expected email-extension files)*
- [x] Purge the deployed copy: `rm -rf .claude/skills/skill-todo/`. Without this, the deployed
      `SKILL.md` survives the additive redeploy as a deployed-but-undeclared file and Gate 13
      fails by construction. *(completed)*
- [x] Redeploy with the bounded-wait idiom: raise the Bash tool timeout to 600000 and run
      `timeout 540 bash .claude/scripts/deploy-headless.sh`. Never hand-patch a deployed file to
      reach a green gate. *(completed; also required a second manifest.json edit -- see deviation
      recorded in progress/phase-2-progress.json -- to register the new test file's
      provides.scripts entry, without which the deploy copier never deployed it)*
- [x] Confirm the regenerated root `.claude-extensions.json` no longer lists
      `.claude/skills/skill-todo/SKILL.md`. *(completed: grep -c returns 0)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: exactly four mechanical registrations claim `skill-todo` —
`manifest.json`'s skills array, `lint-state-writer-boundary.sh`'s exemption registry,
`test-todo-move-pair-staging.sh`'s Stage 15 subject, and the file itself; every other live
reference is prose or a comment and belongs to Phase 3. Confirm at implementation time with the
`audit-deletion-references.sh` run in the last task: any hit it reports in a `.json`, a lint
allowlist, or a test's subject-resolution block is a fifth mechanical registration and belongs in
THIS phase, not Phase 3.

**Tier Justification**: deregistering a manifest-listed, deployed skill moves two cross-cutting
surfaces that no suite subset reaches — Gate 5's manifest-driven category parity and content-hash
equality between source store and deployed tree, and Gate 13's whole-tree `find_orphans` sweep —
and `suite_selection_select` maps this phase's `manifest.json` and `SKILL.md` paths to roughly
seventy suites, i.e. Gate 8's battery itself, so the complete gate set is the cheapest honest
cover.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` - DELETED (1027 lines)
- `agent-system/extensions/core/manifest.json` - `skill-todo` removed from `extension.skills[]`
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` - exemption-registry
  entry removed
- `agent-system/extensions/core/scripts/tests/test-todo-move-pair-staging.sh` - Stage 15 shape
  (subject resolution, behavioral pair, static half, header bullets) removed
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the entire deployed
  tree; declared with the reserved sentinel per the whole-tree-claim rule rather than with a wide
  real path
- `.claude-extensions.json` - root deploy ledger whose `extensions.core.installed_files[]`
  currently lists the skill; its input moves in this phase, so it is declared here, and it is
  regenerated here too by the redeploy, which is its only sanctioned writer. Never hand-edited.

**Verification**:
- `test -e agent-system/extensions/core/skills/skill-todo/SKILL.md` returns false.
- `jq -e '.extension.skills | index("skill-todo")' agent-system/extensions/core/manifest.json`
  returns null, and `jq empty agent-system/extensions/core/manifest.json` exits 0.
- `test -e .claude/skills/skill-todo/SKILL.md` returns false and
  `grep -c 'skill-todo' .claude-extensions.json` returns 0.
- `bash .claude/scripts/verify-deploy.sh` exits 0 with every gate green — Gate 5 reporting
  manifest parity, Gate 13 reporting "no deployed-but-undeclared files or ghost
  context/index.json rows", and Gate 8 passing the full suite battery with
  `test-todo-move-pair-staging.sh` still exercising its three surviving site shapes and their
  negative controls.
- The `audit-deletion-references.sh skill-todo` triage checklist is captured for Phase 3.

#### Reasoned Exclusions

`bash .claude/scripts/verify-deploy.sh` does not exit 0 end to end; every in-scope criterion
above it (SKILL.md absent from source store and deployed tree, manifest.json clean, Gate 5,
Gate 13, both `/todo` test suites standalone) is independently green. The remaining gate
failures are excluded here, specific and evidenced, rather than silently absorbed into a bare
`[COMPLETED]`:

| Item | Reason | Evidence |
|------|--------|----------|
| Gate 4 (task-reference lint) | Pre-existing hit in `agent-system/extensions/core/context/config/orchestrator-context-budget.json`'s own historical commentary (mentions a prior task number in prose), outside this task's `file_scope` | `git log --oneline -1` on that file shows it last committed under an unrelated task ("close outstanding gate20 finding"); `git status --porcelain` on it is clean -- the hit predates this dispatch |
| Gate 20 (eager-load-over-baseline) | Pre-existing 44 B drift (70444 B vs. 70400 B baseline) unrelated to `/todo` or `skill-todo` | Gate 20's own `[FAIL]` line names `commands/orchestrate.md` and `skill-orchestrate/SKILL.md`, neither touched by this task; this task's `file_scope` contains neither path |
| Gate 29 (test-root-resolution lint) | Pre-existing violation in `agent-system/extensions/typescript/scripts/tests/test-typescript-verify.sh`, outside this task's `file_scope` | `git log --oneline -1` on that file shows it committed under task 622; `git status --porcelain` on it is clean; the violation text itself (an unconditional fixed-depth `REPO_ROOT` walk) has nothing to do with `/todo` or `skill-todo` |
| Gates 21/23 (hook-registration-path lint, directory-pathspec-boundary lint) | Flaky inside the full battery only; both report zero violations when invoked standalone immediately after the same redeploy, twice | `bash agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh --verbose` and `lint-directory-pathspec-boundary.sh --verbose` both print "Total violations: 0" run directly; attributed to this heavily shared, concurrently-loaded dev environment (6+ other `claude` agent processes observed mid-dispatch via `ps aux`), not to any edit in this task's `file_scope` |
| Gate 8, `test-deploy-propagation.sh` (NEW) | Its own header comment documents assertions A/B as expected-red by design (a pre-existing "two-engine defect" in `load_all_globally`); not yet added to `known-failures.txt` | `grep -l skill-todo` on the file returns no match; the suite's in-file comment literally states "A green A/B at this point in the plan means the diagnosis is wrong" |
| Gate 8, `test-gate-registry-resolution.sh` (NEW) | Its case32 fails only because gate 29 itself is red (the typescript violation above), not because of any registry-resolution defect | `grep -l skill-todo` on the file returns no match; case32's own captured output shows the failure is `verify-deploy.sh --only-gate 29` itself returning non-zero, i.e. the same gate-29 finding already excluded above |
| Gate 8, 5 other suites (`test-double-loading-check.sh`, `test-gate-cache-equivalence.sh`, `test-lint-unit-integration-boundary.sh`, `test-orchestrate-cycle-postflight.sh`, `test-verify-deploy-context-budget.sh`) | Already tracked as pre-existing, needs-owner `real-defect`/`load-sensitive` rows | `agent-system/extensions/core/scripts/tests/known-failures.txt` carries a dated row for each, none mentioning `/todo` or `skill-todo` |

---

### Phase 3: Reconcile Every Remaining Reference to Post-Removal Reality [NOT STARTED]

**Goal**: every surviving prose and comment reference to `skill-todo` describes what is actually
true, and `context/architecture/system-overview.md`'s `/todo` routing row no longer places a skill
in a path it was never in.

**Tasks**:
- [ ] `context/architecture/system-overview.md` line 417: change
      `| /todo | Direct | skill-todo | (no agent) | B |` to
      `| /todo | Direct | (direct execution) | (no agent) | B |`, matching the phrasing the same
      table already uses for `/review` and `/errors`. Re-verify the line number and the row's
      current text before editing.
- [ ] `context/reference/skill-agent-mapping.md` line 39: remove the
      `| skill-todo | Archive completed tasks, sync metrics |` row.
- [ ] `merge-sources/claudemd.md` line 165: remove the `| skill-todo | (direct execution) |` row
      from the Skill-to-Agent mapping table.
- [ ] `README.md` line 96: remove the `skill-todo/` entry from the directory tree listing,
      preserving the surrounding box-drawing characters' alignment.
- [ ] `context/patterns/roadmap-update.md` line 154: rewrite
      "Neither `/todo`'s skill (`skills/skill-todo/SKILL.md`) nor `/review` (`commands/review.md`)
      invokes this script" so it names `/todo`'s actual implementation
      (`commands/todo.md`). The ruling that follows it is unchanged.
- [ ] `context/patterns/context-protective-lead.md` line 260: this table is a point-in-time audit
      record, not a live dependency list. Annotate the `skill-todo` row the way the same table
      already annotates `skill-orchestrator` ("historical -- skill retired; this row is a
      point-in-time audit record, not a functional dependency") rather than deleting it.
- [ ] `context/patterns/task-lock.md` lines 829 and 870: at 829, drop
      `skills/skill-todo/SKILL.md` from the list of `--state-file`/`--init` callers. At 870, the
      passage already frames a set of skills as "since deleted outright"; move `skill-todo` into
      that framing rather than leaving it in the list of survivors that call `state-write.sh`.
- [ ] `context/standards/git-staging-scope.md` line 707: the "hand-written `git add` line"
      mechanism bullet attributes itself to `skill-todo/SKILL.md`'s GitCommit stage, which no
      longer exists. Keep the mechanism described — the rule is general — but strip the named
      exemplar and adjust the closing "Both mechanisms" paragraph so it does not imply two live
      exemplars where only the `commands/todo.md` accumulator survives.
- [ ] `context/standards/task-reference-exemptions.md` line 102: this passage grounds its
      "`.memory/**` coverage, empirically verified" claim on `skill-todo`'s Stage 14
      memory-harvest, a stage removed on 2026-11-10 — so the citation is already stale
      independent of this task. Re-ground it on a durable anchor. If no live `.memory/**` writer
      exists to anchor it, say that plainly; do NOT substitute a named writer that has not been
      verified to exist.
- [ ] `scripts/validate-state.sh` line 731: the comment attributes the `created_at` field shape to
      `skills/skill-todo/SKILL.md`'s "Archive TODO.md orphans" step. Re-ground it on the shape
      itself — a sparse archive entry carrying `created_at` and no `task_type`, present in
      historical archive data — with no producer named.
- [ ] `scripts/tests/test-validate-state.sh` lines 2063 and 2081: apply the same re-grounding to
      fixture (h)'s comment and its `common_test_pass` message. The assertion itself is KEPT
      unchanged — it pins the validator's tolerance, which is independent of any producer.
- [ ] `scripts/skill-base.sh` line 606: the comment cites "skill-todo's archival jq, which copies
      the whole active_projects entry unmodified". Re-point it at `commands/todo.md`'s archival jq
      (the `.completed_projects = ([$tasks[] | ...])` assignment, expected near line 390), which
      has the identical shape.
- [ ] `scripts/lib/engine-written-state-paths-lib.sh` line 24: the comment states
      `specs/CHANGE_LOG.md` is "written only at archival (skill-todo)". Correct it to state that
      no live path writes it. State the fact only — do not add a judgment about whether it should
      be written; that question belongs to another record.
- [ ] `scripts/lint/lint-postflight-boundary.sh` line 70: remove `skill-todo` from the
      parenthetical list of direct-execution skills in the comment.
- [ ] `scripts/deprecated/README.md` lines 19 and 132: both sentences name
      `commands/todo.md` *and* `skills/skill-todo/SKILL.md` as the pair that hand-implements the
      quarantined behaviors. Drop the `skill-todo` half; `commands/todo.md` alone is the
      authoritative implementation these quarantine notes already point at.
- [ ] Re-run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/audit-deletion-references.sh skill-todo`
      and read every remaining hit. A hit is a candidate for triage, not a failure: the three
      email-extension files and this plan's own `specs/**` artifacts are expected, legitimate
      residual hits and are left alone.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: fourteen source-store files outside `skills/skill-todo/` carry a prose or
comment reference needing reconciliation, and three email-extension files carry references that
are deliberately EXCLUDED from this phase. Confirm at implementation time against Phase 2's
captured `audit-deletion-references.sh` checklist: a hit outside the fourteen and outside the
three excluded email files is a new reference and must be reconciled here; a hit inside the three
email files is left untouched. No task in this phase requires editing an email-extension file.

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel for this
phase's touched paths, so no suite is claimed to cover them, and the covering check is
`bash .claude/scripts/verify-deploy.sh --only-gate 3,4,22` — doc-lint for the markdown edits, the
task-reference lint for prose landing under `agent-system/**`, and shellcheck for the five
comment-only `.sh` edits — because every changed hunk lies inside a comment, a prose paragraph,
or a markdown table cell, with no executable statement altered.

**Files to modify**:
- `agent-system/extensions/core/context/architecture/system-overview.md` - `/todo` routing row
  names no skill
- `agent-system/extensions/core/context/reference/skill-agent-mapping.md` - `skill-todo` row
  removed
- `agent-system/extensions/core/merge-sources/claudemd.md` - `skill-todo` mapping row removed
- `agent-system/extensions/core/README.md` - `skill-todo/` tree entry removed
- `agent-system/extensions/core/context/patterns/roadmap-update.md` - names the surviving command
  implementation instead of the removed skill
- `agent-system/extensions/core/context/patterns/context-protective-lead.md` - audit row
  annotated as historical
- `agent-system/extensions/core/context/patterns/task-lock.md` - two passages re-grounded
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - dead exemplar stripped,
  rule preserved
- `agent-system/extensions/core/context/standards/task-reference-exemptions.md` - `.memory/**`
  evidence re-grounded or honestly unanchored
- `agent-system/extensions/core/scripts/validate-state.sh` - comment re-grounded on the entry
  shape
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - fixture (h) comment and
  pass message re-grounded; assertion unchanged
- `agent-system/extensions/core/scripts/skill-base.sh` - comment re-pointed at the survivor's own
  archival jq
- `agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh` - CHANGE_LOG
  comment corrected to state no live writer
- `agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` - comment list updated
- `agent-system/extensions/core/scripts/deprecated/README.md` - two quarantine notes name the
  surviving command implementation alone

**Verification**:
- `grep -rn 'skill-todo' agent-system/extensions/core/` returns zero hits.
- `grep -rn 'skill-todo' agent-system/extensions/` returns only the three expected
  email-extension files.
- `verify-deploy.sh --only-gate 3,4,22` is green.
- The `audit-deletion-references.sh skill-todo` re-run shows no unexplained hit; every remaining
  hit is one of the three email files or this task's own `specs/**` artifacts.

---

### Phase 4: Redeploy the Reconciled Tree, Run the Full Gate, Report the Net-Line Figure [NOT STARTED]

**Goal**: Phase 3's reconciliation reaches the deployed tree, the complete gate battery is green
end to end, and the net-line figure is measured and reported.

**Tasks**:
- [ ] Redeploy with the bounded-wait idiom: raise the Bash tool timeout to 600000 and run
      `timeout 540 bash .claude/scripts/deploy-headless.sh`, so Phase 3's prose and comment
      corrections reach `.claude/**`. Never hand-patch a deployed file to reach a green gate.
- [ ] Run the complete battery: `bash .claude/scripts/verify-deploy.sh`. Confirm specifically that
      gate 5 (manifest category parity and content-hash equality), gate 8 (full shell suite,
      including the new `test-todo-archived-projects-scan.sh`), gate 13 (whole-tree orphan
      detection), and the lints the acceptance criteria name — `lint-agent-contracts.sh` (gate 6),
      `lint-postflight-boundary.sh` (gate 9), `lint-state-writer-boundary.sh` (gate 12) — are all
      green, alongside `validate-index.sh` and `validate-state.sh`.
- [ ] Measure the BEFORE line total from this task's base commit for every path it touched, using
      `git show <base>:<path> | wc -l` per path (with the deleted `SKILL.md` counted at its
      pre-deletion size), so the figure is derived from git rather than from this plan's estimate.
- [ ] Measure the AFTER line total over the same path set and report lines-before, lines-after and
      the delta. If the delta is not a reduction, stop and report it: per this task's framing a
      consolidation that does not reduce total lines has become a rewrite and should be re-scoped
      rather than completed.
- [ ] State in the summary that `Skill(skill-todo)` is now deliberately and completely
      deregistered (not registered-but-absent), and flag for whoever next revises task 626 that
      its `file_scope` names a file that no longer exists and its wiring target should become
      `commands/todo.md`. Do not edit 626's record.

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: Phase 2's purge and redeploy already cleared every `skill-todo` residue from
the deployed tree, so this phase's redeploy propagates prose corrections only and introduces no
new orphan. Confirm at implementation time from gate 13's own `ORPHAN_FINDING` output: any orphan
it reports is a finding to investigate, not a path to purge reflexively.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the entire deployed
  tree; declared with the reserved sentinel per the whole-tree-claim rule rather than with a wide
  real path
- `.claude-extensions.json` - deploy ledger, regenerated by `deploy-headless.sh`; never
  hand-edited

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 with every gate green, gate 13 reporting "no
  deployed-but-undeclared files or ghost context/index.json rows".
- `grep -rn 'skill-todo' .claude/` returns zero hits.
- `grep -c 'skill-todo' .claude-extensions.json` returns 0.
- A net-line figure (before, after, delta) is reported, and the delta is a reduction.

---

## Testing & Validation

- [ ] `test-todo-archived-projects-scan.sh` passes, with its negative control demonstrating that
      the pre-fix filter misses an `archived_projects[]` entry.
- [ ] `test-todo-move-pair-staging.sh` passes with its three surviving site shapes and their
      negative controls, and no longer resolves a `skill-todo` subject.
- [ ] `test-validate-state.sh` passes with fixture (h) unchanged in assertion.
- [ ] `scripts/tests/run-all.sh` (gate 8) discovers and passes every suite, with the new suite
      classified in `suite-classification.data`.
- [ ] `validate-index.sh`, `validate-state.sh`, `lint-agent-contracts.sh`,
      `lint-postflight-boundary.sh` and `lint-state-writer-boundary.sh` are all green.
- [ ] `verify-deploy.sh` is clean end to end after the redeploy.
- [ ] No file landing under `agent-system/**` contains a task-number reference or
      record-versioning language.

## Artifacts & Outputs

- One authoritative `/todo` implementation: `agent-system/extensions/core/commands/todo.md`, with
  the `archived_projects` fix applied at all three read-back scans.
- `agent-system/extensions/core/scripts/tests/test-todo-archived-projects-scan.sh` (new suite)
  plus its `suite-classification.data` row.
- `skills/skill-todo/` removed from the source store, the deployed tree, the manifest, the deploy
  ledger, and every registry, lint and prose reference.
- A clean `verify-deploy.sh` run and a reported net-line figure (expected: a reduction of roughly
  one thousand lines; the measured figure governs).

## Rollback/Contingency

Each phase is a separate commit, so rollback is per phase. Before any intentional rollback that
would otherwise be blocked by `guard-destructive-git.sh`, run
`bash .claude/scripts/git-snapshot.sh 458` and then the destructive command.

- **Phase 1 fails**: revert the three token swaps and the new test file. No other phase has run,
  so nothing else is affected.
- **Phase 2 fails**: `git revert` its commit and redeploy. The source store returns to a state
  where `skill-todo` exists and is registered — consistent, if duplicated.
- **Phase 3 fails**: `git revert` its commit. The tree is left post-removal with some stale prose,
  which is recoverable by re-running Phase 3; nothing mechanical depends on it.
- **A gate fails in Phase 2 or Phase 4**: do NOT hand-patch a deployed file. Fix the source store
  and redeploy. If gate 13 reports the `skill-todo` orphan, the purge step was skipped — run it
  and redeploy. If gate 5 reports a content-hash mismatch, the deploy did not complete; re-run it
  under the bounded-wait idiom rather than editing `.claude/**`.
- **Net-line delta is not a reduction**: stop and report rather than completing. That outcome
  means the consolidation became a rewrite and the task should be re-scoped.
