# Implementation Plan: Task #322

- **Task**: 322 - todo_move_vacated_source_never_staged
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: None (cross-references only: tasks 302, 318, 328 — not dependency edges)
- **Research Inputs**: specs/322_todo_move_vacated_source_never_staged/reports/01_todo-move-vacated-source-staging.md
- **Artifacts**: plans/01_todo-move-pair-staging.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`/todo`'s archival recipe performs directory moves but accumulates only each move's
DESTINATION into the commit pathspec, so every vacated source path's removal is left unstaged —
a verified regression from the explicit-pathspec migration (commit `c482bf40c`), measured live
at 173 unstaged ` D` entries and a wrong `phantom_paths: 109` baked into committed state. This
plan pairs both endpoints of every move at all affected sites in the two recipe copies, hoists
the invariant into `context/standards/git-staging-scope.md` as a named rule, and adds a
two-part regression suite (behavioral fixture plus static recipe-text assertions) that fails on
the pre-fix shape. Definition of done: both recipes pair both endpoints at every move site, the
standard names the rule, the new suite passes with its negative control demonstrating the old
shape is caught, and the redeployed tree clears `verify-deploy.sh`.

### Research Integration

The research report (`reports/01_todo-move-vacated-source-staging.md`) verified every factual
claim in the dispatch against the live source store and is confirmatory rather than
exploratory. Integrated findings:

- **Edit target is the source store**, resolved via `.claude-extensions.json`'s `source_dir` for
  the `core` extension: `agent-system/extensions/core/`. Never `.claude/**` directly
  (`source-store-deploy-boundary.md`).
- **Three dest-only sites in `commands/todo.md`** confirmed verbatim. Line numbers re-verified
  at plan time as **665, 686, 752** (the report's 663/685/749 had already drifted back; this is
  exactly why the report's own mitigation says re-grep rather than trust a line number).
- **The vault site at ~898-912 already does it correctly** and carries the explanatory comment
  this fix should mirror; **Step 5.7.7's prose at ~948-953 restates the rule a second time.** The
  invariant is stated twice in the same file that violates it three times.
- **`skill-todo/SKILL.md` has the same class of gap by a different mechanism** — a hand-written
  `git add` line at Stage 15, not an accumulator — so it needs a genuinely different edit.
- **No existing gate can catch this**: the directory-pathspec lint classifies only tokens that
  are *present*; `git-commit-scoped.sh`'s V2/V5/V6 inspect only pathspecs they are *given*. An
  omission is structurally invisible to both.
- **Insertion point for the new standard**: a new `##` section immediately after
  `## Forbidden Operations` (confirmed at line 224, ending line ~253, before
  `## Commit-Level Path Scoping and Cross-Process Serialization` at 255).
- **`scripts/orchestrate-cycle-postflight.sh` stays untouched** — audited clean in the dispatch
  and independently spot-checked in research.
- **Stale cross-reference**: the dispatch's task-307 sibling reference is superseded; 307 is
  archived and its substance folded into task 328, which restates the identical serialization
  constraint (this task lands first). Awareness only; no action, no scope change.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, and `roadmap_flag` is not set, so no roadmap
consultation was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Pair both endpoints of every directory `mv` into the commit pathspec at all three dest-only
  sites in `agent-system/extensions/core/commands/todo.md`, with an inline comment at each site
  stating the pairing is deliberate and is NOT a bare shared-directory token.
- Close the same-class gap in `agent-system/extensions/core/skills/skill-todo/SKILL.md` by its
  own (different) mechanism: an explicit vacated-source accumulator across Stage 10's move
  sites, consumed by Stage 15's `git add`.
- Name the invariant once, durably, as a new `## Rename and Directory-Move Staging` section in
  `agent-system/extensions/core/context/standards/git-staging-scope.md`.
- Add a regression suite that fails on the pre-fix dest-only shape (negative control) and
  passes on the fixed shape, asserting the dispatch's three measured consequences: no unstaged
  ` D` under `specs/`, matching `delete mode`/`create mode` pairs, and `phantom_paths: 0`.

**Non-Goals**:

- **Not building a new lint.** Whether the too-narrow-pathspec check is worth automating as a
  repo-wide lint is explicitly deferred to task 318 by this task's own dispatch. The detection
  logic therefore stays inside the new test suite and is not extracted into
  `scripts/lint/`, so nothing here pre-empts 318's open question or requires a new
  `verify-deploy.sh` gate.
- **Not touching `scripts/orchestrate-cycle-postflight.sh`** — audited clean; its moves are
  atomic temp-rewrite-in-place or already covered by the task-scoped `"${TASK_DIR}/"` token.
- Not consolidating the two `/todo` recipe copies (task 328's territory), and not refactoring
  anything in either file beyond the staging lines and their comments.
- Not changing `git-commit-scoped.sh`, `lint-directory-pathspec-boundary.sh`, or any gate
  semantics.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Line numbers drift again before/while editing (both recipes are live, concurrently contended files) | M | H | Re-grep for the distinguishing code snippet at every site immediately before editing; never seek by line number. The anchors are `stage_paths+=` in `commands/todo.md` and `mv ` / `git add specs/archive/` in `SKILL.md` |
| A future reader "simplifies" a two-token pairing back to one token or to a directory token | H | M | Mandatory inline comment at each fixed site stating the pairing is deliberate and both tokens name exact paths, plus the named standard section as the citable rule, plus the static half of the new test suite as the mechanical backstop |
| Fixing `SKILL.md` Stage 15 by widening the pathspec (e.g. staging `specs/` itself) would "work" by accident and reintroduce the cross-session-bleed hazard task 309 closed | H | M | Phase 2 enumerates the moved source paths explicitly via an accumulator and additionally REMOVES the existing bare `specs/archive/` directory token; the suite asserts no bare `specs/` or `specs/archive/` token survives on that line |
| Sibling tasks (325, 337) are dispatched this same cycle on this shared tree | M | M | Their declared `file_scope` sets (`git-commit-scoped.sh`; `validate-handoff.sh`, `orchestrate-cycle-postflight.sh`, `handoff-schema.md`) are disjoint from this task's four files. Still: re-read each file immediately before editing, stage only this task's own hunks, never a directory add, and never run `git-snapshot.sh` in its reverting default mode |
| Source-store edits do not take effect until redeployed, so `verify-deploy.sh` fails on a stale `.claude/` tree | L | H | Phase 5 redeploys via `deploy-headless.sh` before running the full gate set |
| The behavioral half of the suite cannot execute the recipes themselves (they are agent-executed markdown, not scripts) | M | H | The fixture reproduces the exact staging *pattern* in a throwaway git repo rather than the recipe text, and the static half asserts the recipes actually use that pattern. The two halves together are the regression net; neither alone is. Stated as a known limitation in the suite's own header |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Pair Both Endpoints at the Three `commands/todo.md` Move Sites [COMPLETED]

**Goal**: Every directory `mv` in `commands/todo.md` contributes BOTH its old and new path to
`stage_paths[]`, matching the vault site's existing correct pattern and its stated rationale.

**Tasks**:

- [x] Re-read the file and re-grep `grep -n 'stage_paths+=' agent-system/extensions/core/commands/todo.md` to re-establish current line numbers before any edit. *(completed)*
- [x] Step 5D (archive a completed/abandoned/expanded task, currently line 665, inside the existing `if [ -n "$src" ] && [ -d "$src" ]; then` guard so an absent source is still skipped): change `stage_paths+=("$dst")` to `stage_paths+=("$src" "$dst")`. *(completed)*
- [x] Step 5E.1 (move an approved orphan, currently line 686): change `stage_paths+=("specs/archive/${dir_name}")` to `stage_paths+=("$orphan_dir" "specs/archive/${dir_name}")`. *(completed)*
- [x] Step 5F (move a misplaced directory, currently line 752): change `stage_paths+=("$dst")` to `stage_paths+=("$dir" "$dst")`. *(completed)*
- [x] At each of the three sites, add an inline comment — mirroring the vault site's existing comment at ~908-911 in wording and intent — stating that the two tokens name the two exact paths this one `mv` touched, that this is deliberately NOT a bare shared-directory pathspec, and that the pairing must not be collapsed back to a single token. Cite the standard section added in Phase 3 by name (`Rename and Directory-Move Staging`), not by line number. *(completed)*
- [x] Confirm the three pre-existing non-move stages are left alone: line 602 (`specs/archive/state.json`), line 831 (`specs/ROADMAP.md`), and the already-correct vault pairing at line 912. *(completed: line numbers shifted to 602, 842, 923 after this phase's edits but content unchanged)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts there are exactly THREE dest-only move sites in
`commands/todo.md` (currently 665, 686, 752) and that the other four `stage_paths+=` occurrences
(602, 831, 912, and the prose restatement at 948) need no change. Confirm at implementation time
by re-running `grep -n 'stage_paths+=' agent-system/extensions/core/commands/todo.md` and
reading each hit's surrounding ten lines for a preceding `mv`; a fourth move site, or a shifted
count, invalidates the hypothesis and must be reported rather than silently absorbed.

**Files to modify**:

- `agent-system/extensions/core/commands/todo.md` - three `stage_paths+=` lines changed from one token to two (old, new), each with a new anti-simplification comment

**Verification**:

- `grep -n 'stage_paths+=' agent-system/extensions/core/commands/todo.md` shows a two-token form at each of the three former dest-only sites.
- For each of the three sites, reading the ten lines above the `stage_paths+=` line shows the variable named as the first token is exactly the `mv` source on the preceding `mv` line.
- No token added in this phase ends in `/` without a task-identifying component, so `bash agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh --verbose` still passes.

---

### Phase 2: Add an Explicit Move-Pair Accumulator to `skill-todo/SKILL.md` [NOT STARTED]

**Goal**: Stage 15's `git add` stages every vacated source path this run moved, enumerated
explicitly, and no longer relies on a bare `specs/archive/` directory token for the destination
side.

**Tasks**:

- [ ] Re-read the file and re-grep `grep -n 'mv \|<stage id=\|git add' agent-system/extensions/core/skills/skill-todo/SKILL.md` to re-establish the current move-site inventory and the Stage 15 line.
- [ ] Introduce a `moved_paths[]` accumulator convention, declared once at the top of Stage 10's `<process>`, explicitly described as mirroring `commands/todo.md`'s `stage_paths[]` and holding BOTH endpoints of every move, old path first.
- [ ] Thread the accumulator through each Stage 10 move site, prose-level where the step is prose and bash-level where it is bash: step 4 (move project directories to `specs/archive/`), step 5 (track orphaned directories), step 7 (move misplaced directories), step 8c (TODO.md orphan archive, currently the `mv "$source_dir" "$target_dir"` at ~561), the vault moves (~691 `specs/archive` -> `${vault_path}/archive`, ~700 the archive `state.json` rename), and the renumber rename (~821).
- [ ] Rewrite Stage 15's step 2 so the `git add` invocation is `git add specs/TODO.md specs/state.json "${moved_paths[@]}"` plus the existing conditional additions, **removing** the bare `specs/archive/` directory token. Keep the existing conditional list (`specs/CHANGE_LOG.md`, `specs/ROADMAP.md`, updated `README.md` files, `.memory/`) unchanged in behavior.
- [ ] Add a short note at Stage 15 stating why the destinations are now enumerated rather than swept by `specs/archive/`: a directory token cannot reach the source side by construction, and the token is itself forbidden by `git-staging-scope.md`'s `## Forbidden Operations`. Cite the Phase 3 standard section by name.
- [ ] Guard the empty case: when no directories were moved, `moved_paths[]` is empty and the `git add` must not degenerate into a bare `git add` with no pathspec — state the guard explicitly.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts SEVEN move sites in `skill-todo/SKILL.md` — three
prose-level (Stage 10 steps 4, 5, 7) and four bash-level (~561, ~691, ~700, ~821) — and exactly
ONE `git add` line (currently 1054). Confirm at implementation time with
`grep -n 'mv \|git add' agent-system/extensions/core/skills/skill-todo/SKILL.md`; the count
being different, or a second `git add` line existing, invalidates the hypothesis and must be
reported. Note this phase's scope is deliberately one step wider than "add the sources": it also
removes the pre-existing `specs/archive/` directory token, because leaving a forbidden
directory token in place while Phase 3 writes the rule forbidding it would be internally
inconsistent — the same internal asymmetry this whole task exists to fix.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-todo/SKILL.md` - `moved_paths[]` accumulator declared in Stage 10 and threaded through its seven move sites; Stage 15's `git add` consumes it and drops the `specs/archive/` directory token

**Verification**:

- `grep -n 'git add' agent-system/extensions/core/skills/skill-todo/SKILL.md` returns one line, containing `"${moved_paths[@]}"` and no `specs/archive/` or bare `specs/` token.
- Every `mv ` line in the file has a `moved_paths+=` (or an explicit prose instruction to append both endpoints) within its own step.
- `bash agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh --verbose` passes.

---

### Phase 3: Name the Invariant in `git-staging-scope.md` [NOT STARTED]

**Goal**: The rename/directory-move staging invariant exists once, as a named, citable section
of the staging standard, so a fourth violation has a rule to be caught against.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/context/standards/git-staging-scope.md` and confirm the section boundaries (`## Forbidden Operations` at 224, `## Commit-Level Path Scoping and Cross-Process Serialization` at 255).
- [ ] Insert a new `## Rename and Directory-Move Staging` section immediately after `## Forbidden Operations` and before `## Commit-Level Path Scoping and Cross-Process Serialization`.
- [ ] State the rule as a positive requirement: any `mv` whose two endpoints are both inside the staged tree MUST contribute BOTH endpoints to the pathspec list, together, in the same commit. An explicit list only covers what it names; a directory token that used to cover both sides incidentally is not a substitute and is itself forbidden by the preceding section.
- [ ] Explain the failure mode in one short paragraph: with only the destination named, `git add` is never asked to record the source's removal, the copy lands as a fresh `create mode`, the old tree stays in the index pointing at files that no longer exist, and the commit still exits 0 reporting success.
- [ ] Record why no existing gate catches an omission: the directory-pathspec lint classifies only tokens that are present, and `git-commit-scoped.sh`'s V2/V5/V6 gates inspect only pathspecs they are given. A missing token is an omission, not a textual pattern.
- [ ] Quote the vault site's existing comment as the canonical illustration, and name both mechanisms this rule must be honored under as worked examples: an accumulator array (`commands/todo.md`) and a hand-written `git add` line (`skill-todo/SKILL.md` Stage 15). Reference both by file plus step/stage name, never by line number.
- [ ] Add a cross-reference from `## Forbidden Operations`' explicit-multi-file-list carve-out bullet to the new section, so the rename case is reachable from the prohibition it elaborates.
- [ ] Observe `.claude/rules/no-task-references-in-deliverables.md`: no task numbers anywhere in this section — cite durable anchors (file names, section headings, the commit SHA) instead.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/context/standards/git-staging-scope.md` - new `## Rename and Directory-Move Staging` section after `## Forbidden Operations`, plus a cross-reference bullet inside that preceding section

**Verification**:

- `grep -n '^## ' agent-system/extensions/core/context/standards/git-staging-scope.md` shows `## Rename and Directory-Move Staging` positioned between `## Forbidden Operations` and `## Commit-Level Path Scoping and Cross-Process Serialization`.
- Diff read-through confirms every changed hunk is prose/markdown with no executable surface.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` passes (no task-number references introduced outside `specs/**`).

---

### Phase 4: Regression Suite — Behavioral Fixture Plus Static Recipe Assertions [NOT STARTED]

**Goal**: A suite that fails on the pre-fix dest-only shape and passes on the fixed shape,
pinning all three consequences the live run measured.

**Tasks**:

- [ ] Create `agent-system/extensions/core/scripts/tests/test-todo-move-pair-staging.sh` (auto-discovered by `scripts/tests/run-all.sh` on the `test-*.sh` glob; no runner wiring needed), executable, following `context/standards/shell-script-testing.md` conventions already used by the sibling suites.
- [ ] Write a header stating plainly what the suite can and cannot cover: the two recipes are agent-executed markdown, not scripts, so the behavioral half reproduces the staging *pattern* in a throwaway git repo while the static half asserts the recipes actually use that pattern. Neither half alone is the regression net.
- [ ] Behavioral half — positive case: in a temp git repo, create `specs/001_fixture/` with a couple of committed files, `mv` it to `specs/archive/001_fixture`, stage with the paired form `git add -- specs/001_fixture specs/archive/001_fixture`, commit, then assert (a) `git status --porcelain` reports no entry matching `^ D` under `specs/`, (b) `git show --stat --summary HEAD` contains a `delete mode` entry for every `create mode` entry, (c) `bash agent-system/extensions/core/scripts/assess-repo-health.sh --root <fixture>` reports `phantom_paths: 0`.
- [ ] Behavioral half — negative control (the piece that proves the suite would have caught the bug): the identical fixture staged dest-only must produce at least one unstaged ` D` entry, a commit with `create mode` but zero `delete mode` entries, and a nonzero `phantom_paths`. A negative control that passes is itself a suite failure.
- [ ] Behavioral half: one case per affected site shape — Step 5D (padded archive destination), Step 5E.1 (orphan move), Step 5F (misplaced move), and the Stage 15 shape (explicit enumerated list rather than an accumulator).
- [ ] Static half, `commands/todo.md`: for every `mv ` line, assert a `stage_paths+=` within its enclosing block names both endpoints. Allowlist, with a documented inline reason per entry, the atomic temp-rewrite-in-place shape (`foo.tmp` -> `foo`, identical destination, no vacated source) so it is exempt by rule rather than by accident.
- [ ] Static half, `skill-todo/SKILL.md`: assert the single `git add` line contains `"${moved_paths[@]}"` and contains neither `specs/archive/` nor a bare `specs/` token.
- [ ] Static half, the standard: assert `## Rename and Directory-Move Staging` exists in `context/standards/git-staging-scope.md`.
- [ ] Keep all detection logic inside this suite. Do not extract it to `scripts/lint/` and do not add a `verify-deploy.sh` gate — promotion to a repo-wide lint is task 318's open question, and pre-empting it here would widen this task's scope past its own stated boundary.
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-todo-move-pair-staging.sh` and confirm green; then confirm it goes red when Phase 1's first site is temporarily reverted in a scratch copy (do not revert the real file).

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts `assess-repo-health.sh` accepts a `--root` flag and can
run against a throwaway fixture repo (its own header describes it as "standalone, portable,
fixture-testable"), making the `phantom_paths: 0` assertion automatable. Confirm at
implementation time by running it against a scratch directory before building the assertion
around it. If it turns out to require repo-specific state, drop assertion (c) with a loud,
named `[SKIP]` carrying the reason in the suite output — never silently, and never by weakening
assertions (a) and (b).

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-todo-move-pair-staging.sh` - new suite: behavioral fixture (positive plus negative control, one case per site shape) and static recipe-text assertions over both recipes and the standard

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-todo-move-pair-staging.sh` exits 0 and reports every case run, with no silent skips.
- The negative control is present and passing-as-negative (it asserts the broken shape IS detected).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` discovers the new suite (its path appears in the run) and the whole run stays green.
- The file is executable (`test -x`), so `run-all.sh`'s loud-skip discipline is not triggered.

---

### Phase 5: Redeploy and Clear the Full Gate Set [NOT STARTED]

**Goal**: The deployed `.claude/` tree reflects the four source-store edits, and the complete
gate set passes.

**Tasks**:

- [ ] Re-read `git status --short` and confirm only this task's four files are staged/modified by this task; a sibling's in-flight edit elsewhere in the tree is theirs, not a regression of this task's (see the Territory concurrency note).
- [ ] Redeploy the source store with `bash agent-system/extensions/core/scripts/deploy-headless.sh` (no `--wipe`), so `.claude/commands/todo.md`, `.claude/skills/skill-todo/SKILL.md`, `.claude/context/standards/git-staging-scope.md`, and `.claude/scripts/tests/test-todo-move-pair-staging.sh` reflect the edits.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path: `agent-system/extensions/core/scripts/verify-deploy.sh`). This is the `full` tier's named invocation and aggregates the deploy-freshness, hook-registration, suite-runner (Gate 8 -> `run-all.sh`), and scoped-commit-boundary lint gates.
- [ ] If any gate fails, fix forward within this task's four files only; a failure attributable to a file outside this task's scope is reported, not absorbed.
- [ ] Confirm the deployed copies are byte-identical to their source-store originals for the four files (the deploy-freshness gate covers this; spot-check with `diff` on at least `commands/todo.md`).

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- none planned — this phase deploys and verifies; any edit it makes is a fix-forward inside the four files already named by Phases 1-4

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` exits 0.
- `bash .claude/scripts/tests/run-all.sh --quiet` exits 0 with the new suite among the discovered suites.
- `diff agent-system/extensions/core/commands/todo.md .claude/commands/todo.md` is empty.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-todo-move-pair-staging.sh` passes, with its negative control demonstrating the pre-fix dest-only shape is detected.
- [ ] `bash .claude/scripts/tests/run-all.sh --quiet` passes and discovers the new suite.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh --verbose` passes — no token introduced by this task is a bare shared-directory pathspec, and Phase 2 removes one that was.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh --verbose` passes.
- [ ] `bash agent-system/extensions/core/scripts/check-task-references.sh` passes (no task-number references introduced outside `specs/**`).
- [ ] `bash .claude/scripts/verify-deploy.sh` passes against the redeployed tree.
- [ ] **Deferred to the next real archival run (not automatable here, stated rather than hidden)**: the dispatch's end-to-end assertion — that an actual `/todo` run which moves at least one directory leaves no unstaged ` D` under `specs/` and records matching `delete mode`/`create mode` pairs, with `assess-repo-health.sh` reporting `phantom_paths: 0` afterwards — cannot be executed by this task, because `/todo` is an agent-executed markdown recipe with no scripted entry point. Phase 4's fixture pins the pattern and Phase 4's static half pins the recipes' use of it; the live confirmation is a one-line check on the next `/todo` archival run: `git status --porcelain | grep '^ D specs/'` must be empty.

## Artifacts & Outputs

- `agent-system/extensions/core/commands/todo.md` - three move sites paired, each with an anti-simplification comment
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` - `moved_paths[]` accumulator across Stage 10, consumed by Stage 15's `git add`, `specs/archive/` directory token removed
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - new `## Rename and Directory-Move Staging` section plus a cross-reference from `## Forbidden Operations`
- `agent-system/extensions/core/scripts/tests/test-todo-move-pair-staging.sh` - new regression suite (behavioral fixture plus static recipe assertions)
- Redeployed `.claude/` copies of all four files
- `specs/322_todo_move_vacated_source_never_staged/summaries/01_*-summary.md` - implementation summary

## Rollback/Contingency

All four edits are small, additive, and confined to files this task owns; each phase commits
separately under the per-substep mandate, so reverting is a `git revert` of the offending phase
commit rather than a working-tree rollback.

If a rollback that discards uncommitted work does become necessary, follow
`context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
shape, including its out-of-scope override flag for the deliberate whole-tree case. Do not take
a bare reverting snapshot as a routine start-of-phase precaution; an ordinary defensive
checkpoint uses `--no-revert`, which is durable without touching the working tree.

Partial-landing contingency: Phases 1, 2, and 3 are independently valuable and independently
revertable. If Phase 4's suite cannot be made green within its budget, Phases 1-3 still close
the live defect and the standard still names the rule; record the suite as the outstanding item
rather than holding the fix back behind it.
