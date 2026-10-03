# Implementation Plan: Task #334

- **Task**: 334 - Fix two books-extension scaffold contract defects: the hard implementation
  agent's artifacts shape and hand-rolled task lookups in both hard skills
- **Status**: [NOT STARTED]
- **Effort**: 1.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/334_fix_books_scaffold_contract_defects/reports/01_books-scaffold-contract-defects.md
- **Artifacts**: plans/01_books-scaffold-contract-defects.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three source-store files in the books extension carry two standing lint failures that each fail a
`verify-deploy.sh` gate: `books-implementation-hard-agent.md` has no literal `"artifacts"`/
`"status"` JSON template (failing `lint-agent-contracts.sh` Checks E and F), and both hard
SKILL.md files hand-roll the narrow full-record jq task lookup (failing
`lint-task-lookup-adoption.sh`). Each defect has a passing sibling file in the same repository as
its literal copy source, so all three edits are mechanical. The task's fourth, broader mandate --
ruling on why the books scaffold's own completion postflight cleared a task carrying two standing
lint failures -- is answered by the research report and discharged here with the cheap, in-scope
half of its remedy: naming the concrete command that satisfies `plan-format.md`'s `full`
verification tier, so a future `full` declaration can no longer be honestly narrowed to a
self-chosen validator subset. Definition of done: `lint-agent-contracts.sh --verbose` and
`lint-task-lookup-adoption.sh --verbose` both clean, `verify-deploy.sh --skip-slow` fully green,
and `plan-format.md`'s `full` row naming `verify-deploy.sh`.

### Research Integration

The research report establishes, with live tool runs and commit-level provenance, that: (1) both
defects originate in the books scaffold commits (`8655007d1` phase 2, `985d05b47` phase 3,
2026-10-03), while both lint checks had already been live and wired into `verify-deploy.sh` for
roughly two months -- so this is not tooling catching up to old content; (2) Defect 1 fails two
checks (E, terminal status presence, and F, object-shaped artifacts) that a single copied fenced
JSON block fixes together, since the template itself carries the literal `"status": "implemented"`
line; (3) `skill_validate_input` (`skill-base.sh:336-376`) exports a strict superset of what the
hand-rolled block derives, including the identical terminal-state check plus archive-awareness;
(4) the root cause of the general defect is planning-time, not tooling: a
`**Verification Tier**: full` declaration is nowhere mechanically tied to an actual
`verify-deploy.sh` invocation, and two independent plans narrowed "full" to self-chosen subsets
without being wrong about the letter of the text; (5) the live `--skip-slow` failure count is 2 of
33, not the dispatch description's stale 3 -- so the expectation after this task is 33 of 33, not
1 of 33. The report's explicit prohibitions are carried into this plan as Non-Goals: do not
allowlist the two books hard skills, and do not "fix" `verify-deploy.sh` or either lint script,
all three of which are correct.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- `lint-agent-contracts.sh --verbose` reports zero findings for
  `books-implementation-hard-agent.md` (both the Check E status and Check F artifacts failures).
- `lint-task-lookup-adoption.sh --verbose` reports zero violations across
  `agent-system/extensions/books/**`.
- `verify-deploy.sh --skip-slow` returns fully green (expected 33 of 33).
- `plan-format.md`'s `## Verification Tiers` section names the concrete command that satisfies the
  `full` tier's "the complete gate set for the repository", closing the ambiguity the research
  identified as the mechanism behind the general defect.
- All edits land in the source store (`agent-system/extensions/**`), never under `.claude/**`.

**Non-Goals**:
- Adding the two books hard skills to `lint-task-lookup-adoption.sh`'s `EXCLUDED_FILES` allowlist.
  The allowlist is a shrinking, individually-reasoned list for *pending* migrations; adding these
  two would suppress the defect rather than fix it, directly against the task's framing.
- Editing `verify-deploy.sh`, `lint-agent-contracts.sh`, or `lint-task-lookup-adoption.sh`. The
  research establishes all three are correct and were already catching this failure class; the
  defect is in the content they lint and in planning-time convention.
- Migrating the four already-allowlisted sibling hard skills (`cslib-implementation-hard`,
  `cslib-research-hard`, `lean-implementation-hard`, `lean-research-hard`), which are deferred
  pending a separate core-collapse sequencing decision.
- Building the plan-file content lint (research recommendation 3a) that would flag a `full`-tier
  phase whose own task list never reaches a full-gate invocation. See Decisions for why this is
  deferred rather than landed here.
- Re-litigating the closed `--gate` advisory-tier design or the books scaffold's broader design.
- Redeploying `.claude/**`. The deploy tree is a disposable artifact regenerated separately; both
  lints resolve the repository root and scan `agent-system/extensions`, so the source-store fix is
  sufficient for every gate in scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Hand-typing a new JSON block for Defect 1 produces a subtly different key set that still fails Check F's 6-line window search | M | M | Copy the sibling `books-implementation-agent.md` Stage 7 fenced block verbatim; do not retype it. Verify by re-running the lint, not by eye |
| `skill_validate_input` adds a terminal-state hard exit to `skill-books-research-hard`, which today has no such check | L | H (it is certain, by design) | Intentional tightening: it matches every other skill-layer call site and the impl-hard sibling. Flagged explicitly in Phase 3 rather than landed silently |
| An implementer "fixes" the general defect by editing the three already-correct lint/gate scripts | H | L | Stated as a Non-Goal above and repeated in Phase 4's own text; Phase 4's file list names exactly one file |
| A task-number reference ("task 334", "task 297") leaks into a file outside `specs/**` | M | M | All four edited files are outside `specs/**`, where `no-task-references-in-deliverables.md` applies. Cite durable anchors (filenames, section headings) only. Gate 4 (`check-task-references.sh`) catches this in Phase 5 |
| Concurrent sibling task 285 edits collide on this tree | M | L | Its declared scope (`orchestrate-record-decision.sh`, `orchestrate-cycle-postflight.sh`, `skill-orchestrate/SKILL.md`, `utility-scripts-inventory.md`) is disjoint from all four files here. Re-read each file immediately before editing; stage only this task's own files by explicit path; never a directory or glob `git add`; never `git-snapshot.sh` in reverting default mode |
| A gate failure in Phase 5 outside this task's four files is misread as this task's regression | M | L | Per the territory contract: check `git log` first; an out-of-scope failure may be a sibling's in-flight edit. Report rather than "fix" it |
| Editing `plan-format.md` renames or rephrases a frozen heading (`Files to modify`, `## Verification Tiers`) | H | L | Phase 4 is additive only: one table-cell amendment plus one new paragraph. No heading text is touched |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4 | -- |
| 2 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 1-4 touch four disjoint files and
share no symbol, so they are genuinely independent; Phase 5 is the aggregate gate and must run
last.

---

### Phase 1: Defect 1 -- object-shaped artifacts template in the hard implementation agent [NOT STARTED]

**Goal**: `books-implementation-hard-agent.md` Stage 7 carries a literal fenced JSON block with
`"status"` and an object-shaped `"artifacts"` array, so both `lint-agent-contracts.sh` Check E
(terminal status presence) and Check F (object-shaped artifacts, keys `type`/`path`/`summary`
within a 6-line window of the `"artifacts"` occurrence) pass.

**Tasks**:
- [ ] Re-read `agent-system/extensions/books/agents/books-implementation-hard-agent.md` (territory
      discipline: a sibling may have touched it) and locate `### Stage 7: Write Metadata File`
      (currently 4 lines of prose ending "same `artifacts` shape as the base agent").
- [ ] Copy the Stage 7 block from the passing sibling
      `agent-system/extensions/books/agents/books-implementation-agent.md` verbatim -- the
      `artifacts` shape prose paragraph plus the fenced ```json block with
      `"status": "implemented"` and the single `{type: "summary", path:
      "specs/{N}_{SLUG}/summaries/{NN}_{short-slug}-summary.md", summary: ...}` entry.
- [ ] Keep the hard agent's own prose that the sibling lacks: the `implemented`/`partial`/
      `blocked` status vocabulary note, since this agent genuinely reports all three. Per
      `return-meta-artifacts-template.md`'s own "Placement" guidance, prose is kept and the
      template is *added*; prose alone does not substitute for a copyable example.
- [ ] Leave Stages 8 and 9 (the H9 wrap-up discipline block) untouched.
- [ ] Confirm no task-number reference was introduced.

**Timing**: 0.3 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: the hypothesis is that one copied block closes *both* the Check E and
Check F failures on this file, because the copied template itself carries the literal
`"status": "implemented"` line. Confirm by running
`bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` and observing
that *both* previously-reported `books-implementation-hard-agent.md` FAIL lines are gone -- not
just the artifacts one. If only one clears, the status line's fenced form needs separate
attention before this phase closes.

**Files to modify**:
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` - replace Stage 7's
  prose-only cross-reference with the sibling's literal fenced JSON template, keeping the
  three-value status vocabulary note

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` reports zero
  findings for this file (the two FAIL lines named in the research report are both gone).
- `grep -c '"artifacts"' agent-system/extensions/books/agents/books-implementation-hard-agent.md`
  returns at least 1 (a literal key now exists where only prose did).
- A diff read-through confirms Stages 8-9 are byte-identical to before.

---

### Phase 2: Defect 2a -- adopt the shared task-lookup helper in skill-books-implementation-hard [NOT STARTED]

**Goal**: `skill-books-implementation-hard/SKILL.md`'s Stage 1 bash fence no longer hand-rolls
`'.active_projects[] | select(.project_number == $num)'`, and instead sources `skill-base.sh` and
calls `skill_validate_input`, reading the exported variables.

**Tasks**:
- [ ] Re-read `agent-system/extensions/books/skills/skill-books-implementation-hard/SKILL.md` and
      locate the `### Stage 1: Input Validation` fence (hand-rolled lookup at line ~52).
- [ ] Replace the fence body with the canonical pattern already used by
      `agent-system/extensions/web/skills/skill-web-implementation/SKILL.md`'s Stage 1:
      `source .claude/scripts/skill-base.sh`, `skill_validate_input "$task_number"`, then
      `task_data="$TASK_DATA"`, `task_type="$TASK_TYPE"`, `status="$TASK_STATUS"`,
      `project_name="$PROJECT_NAME"`, `description="$DESCRIPTION"`.
- [ ] Drop the now-dead local `if [ -z "$task_data" ]` not-found branch and the local
      `completed`/`abandoned`/`expanded` terminal-state branch: `skill_validate_input` exits 1
      itself on both, so both are unreachable. Carry the web sibling's explanatory comment
      verbatim in spirit so the removal reads as deliberate, not as a lost check.
- [ ] Leave Stage 1.5 (the hard-mode cost note) and every later stage untouched; do not
      restructure the file's stage numbering.
- [ ] Confirm no task-number reference was introduced.

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: the hypothesis is that this file contributes exactly one of the two
`lint-task-lookup-adoption.sh` violations and that no second hand-rolled occurrence hides
elsewhere in it. Confirm with
`grep -n 'active_projects\[\] | select' agent-system/extensions/books/skills/skill-books-implementation-hard/SKILL.md`
returning no matches after the edit, and with the lint's own violation count dropping by exactly
one when this phase lands alone.

**Files to modify**:
- `agent-system/extensions/books/skills/skill-books-implementation-hard/SKILL.md` - Stage 1
  Input Validation fence: hand-rolled jq lookup replaced by `skill-base.sh` +
  `skill_validate_input`; dead not-found and terminal-state branches removed

**Verification**:
- `grep -n 'active_projects\[\] | select' <file>` returns nothing.
- `bash agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh --verbose` no
  longer lists this file.
- A diff read-through confirms the variables consumed by later stages (`task_number`,
  `project_name`, `description`, `task_type`, `status`) are all still assigned.

---

### Phase 3: Defect 2b -- adopt the shared task-lookup helper in skill-books-research-hard [NOT STARTED]

**Goal**: `skill-books-research-hard/SKILL.md`'s Stage 1 bash fence no longer hand-rolls the
narrow full-record lookup, applying the same canonical `skill_validate_input` pattern as Phase 2.

**Tasks**:
- [ ] Re-read `agent-system/extensions/books/skills/skill-books-research-hard/SKILL.md` and locate
      the `### Stage 1: Input Validation` fence (hand-rolled lookup at line ~43).
- [ ] Apply the same replacement as Phase 2: `source .claude/scripts/skill-base.sh`,
      `skill_validate_input "$task_number"`, then read `TASK_DATA`/`TASK_TYPE`/`TASK_STATUS`/
      `PROJECT_NAME`/`DESCRIPTION` into the local names the later stages already use.
- [ ] Note the one asymmetry with Phase 2 and let it stand deliberately: this file's hand-rolled
      block has **no** terminal-state check today, so `skill_validate_input` adds one. That is an
      intentional tightening consistent with every other skill-layer call site and with the
      impl-hard sibling -- record it in the commit message body so it is not mistaken for an
      accidental behavior change.
- [ ] Leave Stage 1.5 and the later `Stage 2 + Stage 3` block (which already sources
      `skill-base.sh`) untouched; sourcing it twice is idempotent and harmless, so do not
      restructure to deduplicate.
- [ ] Confirm no task-number reference was introduced.

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: the hypothesis is that this file contributes the second and last
`lint-task-lookup-adoption.sh` violation, so that Phases 2 and 3 together take the violation count
to zero with no third site. Confirm with a repository-wide
`grep -rn 'active_projects\[\] | select' agent-system/extensions/books/` returning nothing, and
with the lint reporting zero violations once both phases have landed.

**Files to modify**:
- `agent-system/extensions/books/skills/skill-books-research-hard/SKILL.md` - Stage 1 Input
  Validation fence: hand-rolled jq lookup replaced by `skill-base.sh` + `skill_validate_input`;
  the helper's terminal-state exit is newly inherited here by design

**Verification**:
- `grep -n 'active_projects\[\] | select' <file>` returns nothing.
- `bash agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh --verbose` reports
  zero violations overall (assuming Phase 2 has also landed).
- A diff read-through confirms the variables later stages consume are all still assigned.

---

### Phase 4: General defect -- name the concrete command that satisfies the `full` verification tier [NOT STARTED]

**Goal**: `plan-format.md`'s `## Verification Tiers` section states the concrete command that
satisfies the `full` tier's "the complete gate set for the repository", so a `full` declaration can
no longer be honestly satisfied by a self-chosen validator subset -- the exact mechanism the
research identified behind a completion postflight clearing output that carried two standing lint
failures.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/formats/plan-format.md`, specifically the
      `## Verification Tiers` table's `full` row (currently line ~269) and the
      `### Enforcement level` subsection (currently lines ~308-315).
- [ ] Amend the `full` row's "In-phase verification" cell to name the command alongside the
      existing prose: `bash .claude/scripts/verify-deploy.sh` (source-store path:
      `agent-system/extensions/core/scripts/verify-deploy.sh`). Do not alter the row's other three
      cells, and do not touch any other tier row.
- [ ] Add one short paragraph immediately after the table (or appended to the existing
      **Non-negotiable invariant** paragraph) stating that a phase declaring `full` names that
      command, or the complete set of gates it aggregates, in its own verification criteria -- a
      `full` declaration whose task list reaches only a hand-picked subset of validators does not
      satisfy the tier.
- [ ] Extend the `### Enforcement level` subsection with one sentence recording the *content*
      check as a named, not-yet-built companion to the existing presence check: today
      `validate-artifact.sh` checks only that `**Verification Tier**:` is present (and only in
      `--strict`), never whether a declared `full` phase's own task list reaches a full-gate
      invocation. Write it as a recorded future item in the same register the existing
      "**Promotion criterion**" sentence already uses.
- [ ] Do not rename or rephrase any heading: `## Verification Tiers`, `### Commit modes`,
      `### Counts-are-hypotheses obligation`, `### Enforcement level`, and the frozen
      `Files to modify` string all stay byte-identical.
- [ ] Do not reference any task number: this file is outside `specs/**`. Cite durable anchors
      (file names, section headings) only.

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: the hypothesis is that this is a purely additive documentation change with
no mechanical consumer -- no lint, script, or budget config reads this file's tier table, and
`plan-format.md` does not appear in `orchestrator-context-budget.json`. Confirm at implementation
time with `grep -rn 'plan-format.md' agent-system/extensions/core/scripts/` and
`grep -n 'plan-format' agent-system/extensions/core/context/config/orchestrator-context-budget.json`
before editing; if either now returns a consumer that parses the table, stop and re-scope rather
than proceeding.

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` - `## Verification Tiers`: the
  `full` row's in-phase-verification cell names `verify-deploy.sh`; one new paragraph binding a
  `full` declaration to that command; one new sentence in `### Enforcement level` recording the
  unbuilt content check

**Verification**:
- `grep -n 'verify-deploy.sh' agent-system/extensions/core/context/formats/plan-format.md` returns
  the new occurrences in the `full` row and the new paragraph.
- `diff` of section headings before and after shows no heading text changed (e.g. compare
  `grep -n '^#\{2,3\} ' <file>` output across the edit).
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet` still exits 0.
- `bash .claude/scripts/check-task-references.sh --quiet` still exits 0 (no task number leaked
  into a non-`specs/**` file).

---

### Phase 5: Aggregate gate and close [NOT STARTED]

**Goal**: the full repository gate set runs and is green, confirming both named gates now pass and
that no other gate regressed. This phase also models the convention Phase 4 documents: a `full`
tier declaration whose own verification criteria name `verify-deploy.sh` explicitly.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` and
      confirm zero findings.
- [ ] Run `bash agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh --verbose`
      and confirm zero violations.
- [ ] Run `bash .claude/scripts/verify-deploy.sh --skip-slow` and record the pass/fail tally
      verbatim in the summary.
- [ ] If any gate fails, classify before acting: a failure in one of this task's four files is
      this task's own regression and must be fixed here; a failure elsewhere may be concurrent
      sibling task 285's in-flight edit -- check `git log` to confirm the work is not this task's,
      then STOP and report rather than "fixing" a foreign file.
- [ ] Commit each green phase as it lands, staging only that phase's own file by explicit path --
      never `git add -A`, never a directory or glob pathspec.

**Timing**: 0.25 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: the hypothesis is that `verify-deploy.sh --skip-slow` goes fully green at 33
of 33, not merely from 3 failures down to 1. The dispatch description's "FAIL 3 of 33" is stale:
the research's live run measured 2 of 33 (gates 6 and 18, exactly this task's two defects),
because the third failure -- the orchestrator context-budget ceiling, tracked separately -- was
already closed by commit `29766b2c8`. Confirm by reading the gate tally from the live run output;
if a third gate is failing, identify it and determine whether it is in scope before closing.

**Files to modify**:
- none planned (verification only; any edit this phase provokes belongs to the phase that owns
  the offending file)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --skip-slow` reports zero failed checks (expected: 33 of
  33 passing).
- Gates 6 (agent contracts lint) and 18 (task-lookup adoption lint) are both in the passing set.
- `git status --short` shows no unstaged leftovers from this task's four files, and
  `git log --oneline` shows one scoped commit per landed phase.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` -- zero
      findings (was 2 FAILs, both on `books-implementation-hard-agent.md`).
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh --verbose` --
      zero violations (was 2, one per hard SKILL.md).
- [ ] `bash .claude/scripts/verify-deploy.sh --skip-slow` -- fully green, expected 33 of 33.
- [ ] `bash .claude/scripts/check-task-references.sh --quiet` -- exit 0 (no task number in any of
      the four edited non-`specs/**` files).
- [ ] `bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet` -- exit 0.
- [ ] `grep -rn 'active_projects\[\] | select' agent-system/extensions/books/` -- no matches.
- [ ] Every edit path begins with `agent-system/extensions/` -- nothing was hand-authored under
      `.claude/**`.

## Artifacts & Outputs

- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` (Stage 7 template)
- `agent-system/extensions/books/skills/skill-books-implementation-hard/SKILL.md` (Stage 1)
- `agent-system/extensions/books/skills/skill-books-research-hard/SKILL.md` (Stage 1)
- `agent-system/extensions/core/context/formats/plan-format.md` (`## Verification Tiers`)
- `specs/334_fix_books_scaffold_contract_defects/summaries/01_*-summary.md` (implementation
  summary, recording the `verify-deploy.sh --skip-slow` tally verbatim and the general-defect
  ruling)
- Recommended follow-on, not created by this task: a plan-file content lint flagging any phase that
  declares `**Verification Tier**: full` while its own task list reaches no full-gate invocation.
  See Decisions for why it is scoped as its own task.

## Decisions

- **The general defect is discharged by remedy (b), not (a).** The research offered two candidate
  remedies and deliberately did not pick. This plan picks (b) -- naming `verify-deploy.sh` as the
  `full` tier's concrete command -- and defers (a), the plan-file content lint. Rationale: (b) is a
  single additive documentation edit against the exact ambiguity the research traced, with no
  mechanical consumer to break. (a) is a new lint over every plan file under `specs/**`, which
  would immediately flag the historical plans the research cites as evidence (and whose tasks are
  already `[COMPLETED]`), forcing either a broad allowlist or a retroactive-plan-editing pass --
  a surface that deserves its own task with its own research, not a rider on a three-file fix.
  Landing (b) now does not foreclose (a); Phase 4 explicitly records (a) as a named future item in
  `plan-format.md`'s own `### Enforcement level` register.
- **`skill_validate_input`, not `gate_in`.** `skill_validate_input` is the skill-layer convention
  (`skill-web-implementation`, `skill-spawn`); `gate_in` is reserved for command-layer `.md` call
  sites, which these SKILL.md files are not.
- **Replace the Stage 1 fence rather than delete it.** The research noted the non-hard siblings
  carry no Stage 1 bash at all, and that deleting the fence entirely would also satisfy the lint.
  The replacement shape is chosen because it keeps an explicit, local validation step next to the
  hard skills' own Stage 1.5 hard-mode work, and because it matches the `skill-web-*` pattern that
  the rest of the codebase converged on -- a lint-satisfying deletion would leave these two files
  as the only hard skills with no visible validation step at all.
- **No allowlist entry.** Four sibling extensions' hard skills carry the identical anti-pattern and
  sit in `lint-task-lookup-adoption.sh`'s `EXCLUDED_FILES` as explicitly-reasoned pending
  migrations. That list is a shrinking exception register, not a precedent licensing new entries.
- **No redeploy phase.** Both lints resolve the repository root and scan `agent-system/extensions`
  directly, and the books extension is not deployed in this repository's `.claude/` tree at all, so
  no gate in scope depends on a regenerated deploy tree. The deployed copy of `plan-format.md`
  stays behind its source until the next ordinary deploy, which is the expected steady state under
  `source-store-deploy-boundary.md`.

## Rollback/Contingency

Each of Phases 1-4 is a single-file, additive or in-place documentation edit with its own scoped
commit, so reverting is per-phase and independent: `git revert <phase-commit>` for the offending
phase, leaving the others in place. No phase introduces a schema, state, or script change, so
there is no migration to undo and no state.json mutation to repair.

If a rollback must discard uncommitted work rather than revert a commit, take a durable checkpoint
first -- see `context/contracts/recovery.md`'s rollback rung for the exact `git-snapshot.sh`
invocation shape, including its out-of-scope override flag. For an ordinary defensive checkpoint
before risky work (not a rollback), use `bash .claude/scripts/git-snapshot.sh 334 --no-revert`,
which is durable without reverting the working tree; never the bare reverting default form.

Contingency if Phase 5 finds a gate failing outside this task's four files: do not fix it here.
Per the territory contract, check `git log` to confirm the work is not this task's, then report the
foreign modification and leave this task's own phases committed and green.
