# Implementation Plan: Replace directory pathspecs with explicit file lists

- **Task**: 309 - Replace directory pathspecs with explicit file lists at the three task-commit sites
- **Status**: [NOT STARTED]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/309_replace_directory_pathspecs_with_explicit_file_lists/reports/01_directory-pathspec-v5-gap.md
- **Artifacts**: plans/01_explicit-file-list-pathspecs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Every `bash .claude/scripts/git-commit-scoped.sh ... -- specs/` call site in the source store
stages the whole shared `specs/` tree, so a concurrent `/orchestrate` session's in-progress
artifact writes get swept into whichever session commits next (the mode-1b bleed). Research
confirmed by direct code reading that no layer defends against this — not the PreToolUse hook,
not `git-commit-scoped.sh`'s V2 classification, and not its V5 contention check (which compares
pathspec tokens by exact string equality, so a `specs/` token can never match a file-path
manifest entry, and none of these sites pass `--task` to invoke V5 anyway). The remedy is at the
call sites: replace each bare `-- specs/` with the explicit file list the recipe actually
touches, then add a standalone regression lint so the pattern cannot regrow.

### Research Integration

Four findings from `reports/01_directory-pathspec-v5-gap.md` shape this plan directly:

1. **V5 confirmed to slip past a directory pathspec by construction** (`git-commit-scoped.sh:239`
   tests `any(.path == $p)` — string equality only). The dispatch's expectation is confirmed:
   the primitive cannot compensate for a wide call site, so the fix must be at the call sites.
   No work in this plan touches `git-commit-scoped.sh`.
2. **The footprint is 17 occurrences across 8 files in 3 extensions, not 3.** Confirmed
   independently during planning: 11 multi-line invocation sites plus 6 single-line
   message-variant examples in `commands/todo.md`. The plan fixes all 17, because the task's own
   closing requirement ("a regression check that no commit recipe in the source store passes a
   bare directory pathspec") cannot be satisfied while 14 known violations remain.
3. **`lint-scoped-commit-boundary.sh` cannot be extended** — its Layer-1 classifier treats "ends
   in a trailing `-- <pathspec>`" as the *compliant* shape, which is exactly the shape all 17
   violations have. A new, separate lint is required, mirroring its two-layer structure.
4. **Do not fix this inside `git-commit-scoped.sh`** — legitimate call sites intentionally pass a
   task-scoped directory pathspec today, and that form is explicitly sanctioned by
   `context/standards/git-staging-scope.md`'s own per-operation scope
   (`specs/{padded}_{slug}/ "${ephemeral_excludes[@]}"`). A blanket internal rejection would
   break them.

**One material correction to the research report's scope conclusion.** The report states that no
plausible file needed for this fix appears in `orchestrator-critical-paths.json`. That holds for
the eight recipe files and the two new lint/test files, but **`scripts/verify-deploy.sh` IS a
critical path** (entry 12, "deploy verification gate") — and it is the natural wiring point for a
new lint gate, since gate 17 is where the sibling `lint-scoped-commit-boundary.sh` is wired. The
dispatch's SCOPE NOTE forbids widening `file_scope` to include any critical path, so **wiring the
new lint as a `verify-deploy.sh` gate is excluded from this task** and recorded as a follow-up in
Phase 5. The lint still ships, is registered in `manifest.json`, and runs green under
`scripts/tests/run-all.sh` (which auto-discovers `scripts/tests/test-*.sh`, so no registration is
needed for its test) — it is simply not yet a deploy gate.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in the delegation context; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Replace all 17 bare `-- specs/` pathspec occurrences with explicit file lists naming exactly
  what each recipe touches.
- Add `scripts/lint/lint-directory-pathspec-boundary.sh`: a standalone regression lint that fails
  when a `git-commit-scoped.sh` invocation passes a bare shared-directory pathspec, paired with a
  both-polarity fixture test.
- Leave the lint green against the live source store at task close, with no allowlist entry
  standing in for an unfixed violation.
- Cross-reference the new lint from `context/standards/git-staging-scope.md`, mirroring how that
  file already names `lint-scoped-commit-boundary.sh`.

**Non-Goals**:
- **Wiring the new lint into `verify-deploy.sh`** — that file is an orchestrator-critical path and
  the SCOPE NOTE forbids including one. Recorded as a follow-up in Phase 5.
- **Any change to `git-commit-scoped.sh`** — research recommendation 4; also owned by concurrently
  dispatched task 277 this same cycle.
- **The task-scoped directory pathspec class** (`-- "${task_dir}/"`,
  `-- "specs/${padded_num}_${slug}/reports/"`, ~25 sites across lean/founder/web/present/epi
  skills). These are narrower by construction (one task's own directory, so a cross-session bleed
  is impossible) and the form is explicitly sanctioned by `git-staging-scope.md`'s per-operation
  scope. The new lint deliberately does not flag them; the distinction is documented in the lint's
  own header rather than left implicit.
- Any change to `specs/`-tree runtime data, `state.json` schema, or the commit-lock mechanism.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A replacement file list omits a file the recipe actually writes, so that write silently stops being committed | H | M | Per site, derive the list from the recipe's own surrounding steps (which scripts it runs, which files those write), not from a template. Phase 5 re-runs each touched recipe class mentally against its list and records the derivation inline. |
| The new lint's classifier is too broad and flags the sanctioned task-scoped directory form, making it un-greenable | H | M | The classifier distinguishes a *shared* directory token (no task-identifying component) from a *task-scoped* one (carries a `${...}` interpolation or a `{NNN}_`/`{N}` placeholder). Both polarities are fixture-tested in Phase 1 before any site is fixed. |
| A concurrent sibling task edits a file in this plan's scope | M | L | Territory check done at plan time: siblings 277/314/315/294 own `git-commit-scoped.sh`, `orchestrate-cycle-{plan,postflight}.sh`, `skill-orchestrate/SKILL.md`, `test-handoff-dispatch-identity.sh`, `orchestrate-state-machine.md`, `commands/orchestrate.md`, `CLAUDE.md` and two test files — **zero overlap** with this plan's 11 files. Per the concurrency note, still re-read each file immediately before editing. |
| Editing `.claude/**` instead of the source store, so the fix is wiped on next deploy | H | L | Every path in this plan is under `agent-system/extensions/`. Phase 5's deploy step is what propagates to `.claude/`. |
| `--honest-index-rows` becomes newly applicable at a site once it explicitly stages `state.json`/`TODO.md`, and is silently skipped | M | M | Phase 2 handles the two sites that lack it explicitly (add at one, document the deliberate omission at the other), rather than leaving the question implicit. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 2, 3, and 4 touch disjoint file sets
(core recipe trio / core command files / non-core extension command files) and are safe to run
concurrently.

### Phase 1: Create the directory-pathspec regression lint [NOT STARTED]

**Goal**: A standalone lint exists that mechanically identifies every bare shared-directory
pathspec passed to `git-commit-scoped.sh`, with its detection boundary fixture-tested in both
polarities, so Phases 2-4 have an objective completeness oracle rather than a hand-maintained list.

**Tasks**:
- [ ] Re-confirm the violation inventory mechanically and record the exact count as the baseline
      for this phase's verification:
      `grep -rn -- '^[[:space:]]*--[[:space:]]specs/$' agent-system/extensions/` (expect 11) and
      `grep -rn -- '-- specs/$' agent-system/extensions/core/commands/todo.md` (expect 7 total in
      that file, 1 multi-line + 6 single-line).
- [ ] Write `agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh`,
      mirroring `lint-scoped-commit-boundary.sh`'s structure: same `resolve_project_root` walk-up,
      same default scan root (`$PROJECT_ROOT/agent-system/extensions`), same
      `--verbose`/`--quiet`/`[path...]` flags, same exit codes (0 clean / 1 violations / 2 script
      error), same `.md`+`.sh` file discovery.
- [ ] Implement the two-layer detection model:
      **Layer 1 (candidate window)** — a line is a candidate when it carries a trailing
      `-- <pathspec>` AND lies within a `git-commit-scoped.sh` invocation. Handle both the
      single-line form and the backslash-continued multi-line form by maintaining a small
      lookback window (a line containing `git-commit-scoped.sh` opens a window of N subsequent
      lines; the window closes at the first line not ending in `\`).
      **Layer 2 (structural classifier)** — for each positive pathspec token in a candidate:
      `VIOLATION` when the token ends in `/` and carries no task-identifying component;
      `EXEMPT: task-scoped directory (sanctioned by git-staging-scope.md)` when it ends in `/` but
      contains a `${...}` interpolation or a `{N}`/`{NNN}`-style placeholder;
      `EXEMPT: explicit file path` otherwise. A `:(exclude)...` token is never a positive
      pathspec and is skipped.
- [ ] Add a file-level allowlist (Layer 3, mirroring the sibling lint's `EXCLUDED_FILES`) holding
      only self-reference entries: the lint itself and its fixture test. Every entry carries its
      reason inline. **No entry may stand in for an unfixed violation** — that is what makes
      Phase 5's green run meaningful.
- [ ] Document in the script header, plainly: the KNOWN LIMITATION (regex/line-oriented, cannot
      follow a variable-indirected pathspec or an invocation assembled beyond the lookback
      window), and the deliberate task-scoped-directory carve-out with its
      `git-staging-scope.md` justification.
- [ ] Write `agent-system/extensions/core/scripts/tests/test-lint-directory-pathspec-boundary.sh`,
      mirroring `test-lint-scoped-commit-boundary.sh`'s both-polarity fixture model: dirty
      fixtures (bare `-- specs/` multi-line, bare `-- specs/` single-line, a bare `-- .claude/`)
      must be flagged; clean fixtures (`-- specs/TODO.md specs/state.json`,
      `-- "specs/${padded}_${slug}/" specs/TODO.md`, `-- "${task_dir}/" specs/state.json`, a
      `git add`-free prose mention) must not be. Assert exit codes, not just output text.
- [ ] Register both new scripts in `agent-system/extensions/core/manifest.json`'s `provides`
      arrays, alongside the existing `lint/lint-scoped-commit-boundary.sh` (line ~133) and
      `tests/test-lint-scoped-commit-boundary.sh` (line ~211) entries.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts the live source store contains exactly **17** bare
`-- specs/` occurrences across **8** files (core: `skills/skill-git-workflow/SKILL.md` 1,
`agents/meta-builder-agent.md` 1, `skills/skill-meta/SKILL.md` 1, `commands/task.md` 2,
`commands/todo.md` 7; epidemiology: `commands/epi.md` 1; present: `commands/grant.md` 2,
`commands/slides.md` 1, `commands/timeline.md` 1 — 9 core + 5 non-core across 9 file paths in 3
extensions). Confirm at implementation time with the two greps in the first task above **before**
writing the lint, and reconcile the lint's own first run against that count. If the counts
disagree, the discrepancy is the finding — record it and adjust Phases 2-4's file lists rather
than forcing the number.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh` - new lint
- `agent-system/extensions/core/scripts/tests/test-lint-directory-pathspec-boundary.sh` - new both-polarity fixture test
- `agent-system/extensions/core/manifest.json` - register the two new scripts in `provides`

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-directory-pathspec-boundary.sh`
  exits 0 with every fixture asserted in both polarities.
- `bash agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh --verbose`
  exits 1 and reports exactly the confirmed violation count from the Scope Hypothesis — this
  expected-RED run is the phase's completeness oracle, not a failure.
- The same command run with `--verbose` reports the ~25 task-scoped-directory sites as
  `[EXEMPT]` with the task-scoped reason, confirming the carve-out works and the lint is
  greenable.
- `bash -n` parses both new scripts; `shellcheck` reports no new errors if available.

---

### Phase 2: Fix the three named recipe sites [NOT STARTED]

**Goal**: The three recipes the task names — the most-copied generic "Task Commit" template plus
the two meta-task-creation commit blocks — stage explicit file lists.

**Tasks**:
- [ ] Re-read each file immediately before editing (concurrency note, item 1).
- [ ] `skills/skill-git-workflow/SKILL.md:216` — the generic "Task Commit" recipe, the most-copied
      of the three. Replace `-- specs/` with `-- specs/TODO.md specs/state.json {artifact paths}`,
      keeping the `{...}` placeholder convention already used by the "Standard Commit" recipe
      directly above it (`-- {files}`). Add `--honest-index-rows {N}` — this is a single-task
      commit by definition, and `git-staging-scope.md`'s "required at every site staging
      `specs/state.json` or `specs/TODO.md`" rule becomes directly applicable once the recipe
      names those two files explicitly.
- [ ] `agents/meta-builder-agent.md:1496` (Stage 6) — replace `-- specs/` with
      `-- specs/TODO.md specs/state.json`. This recipe's own surrounding steps write only
      `state.json` (task rows plus `active_topics`, via `manage-topics.sh`) and the regenerated
      `TODO.md`; newly created task directories are empty at this point and contribute nothing to
      a commit. Add a one-line inline note recording why `--honest-index-rows` is deliberately
      **not** added here (the commit creates N tasks, so there is no single owning task number for
      the flag to key on), mirroring the equivalent documented omission at `commands/todo.md:985`.
- [ ] `skills/skill-meta/SKILL.md:287` (postflight commit block) — replace `-- specs/` with
      `-- specs/TODO.md specs/state.json`. Leave the existing `--honest-index-rows {N}` in place.
- [ ] Verify each edit landed inside the fenced `bash` block and that backslash continuations
      still line up.

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts each of these three recipes writes only
`specs/state.json` and `specs/TODO.md` (plus, for the generic template, caller-supplied artifact
paths). Confirm at implementation time by reading each recipe's own preceding steps for the
scripts it invokes and the files those write — do not carry the list over from a sibling site.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md` - Task Commit recipe: explicit list + `--honest-index-rows`
- `agent-system/extensions/core/agents/meta-builder-agent.md` - Stage 6 commit: explicit list + inline omission note
- `agent-system/extensions/core/skills/skill-meta/SKILL.md` - postflight commit: explicit list

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh --verbose
  agent-system/extensions/core/skills/skill-git-workflow/SKILL.md
  agent-system/extensions/core/agents/meta-builder-agent.md
  agent-system/extensions/core/skills/skill-meta/SKILL.md` exits 0.
- `grep -n -- '-- specs/$'` over the three files returns nothing.
- `bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh --quiet` still
  exits 0 (the sibling lint was not regressed — the edited lines still end in a trailing
  pathspec, which is its compliant shape).

---

### Phase 3: Fix the remaining core command sites [NOT STARTED]

**Goal**: `commands/task.md` and `commands/todo.md` — the remaining 9 core occurrences — stage
explicit file lists, including `todo.md`'s six message-variant example lines.

**Tasks**:
- [ ] Re-read both files immediately before editing.
- [ ] `commands/task.md:259` (Step 7, task creation) and `commands/task.md:893` (review/spawn
      follow-up-task commit) — replace `-- specs/` with `-- specs/TODO.md specs/state.json`,
      matching `skill-fix-it/SKILL.md:629`'s already-correct in-repo model. Both sites already
      pass `--honest-index-rows`; leave it.
- [ ] `commands/todo.md:993` (Step 6 archival commit) — replace `-- specs/` with the archival
      operation's actual write set, enumerated: `specs/TODO.md specs/state.json
      specs/CHANGE_LOG.md specs/archive/` plus the specific archived task directories the step
      moved. Keep the existing comment at lines 983-985 explaining why `--honest-index-rows` does
      not apply, and extend it with one sentence distinguishing "legitimately spans many tasks'
      *committed* rows" (true, and why the flag is skipped) from "sweeps in another session's
      *uncommitted* in-flight writes" (the mode-1b hazard the explicit list closes) — the two
      claims are different, and only the explicit list separates them.
- [ ] `commands/todo.md:999,1002,1005,1008,1011,1014` — the six single-line message-variant
      examples. Apply the identical pathspec replacement to each. These are examples, not a second
      code path, so they must not drift from line 993's list.
- [ ] Confirm all 7 `todo.md` occurrences carry the same pathspec list, so a reader copying any
      variant gets the same scope.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts **9** occurrences across 2 files (`task.md` 2,
`todo.md` 7), and that the archival write set is `specs/TODO.md`, `specs/state.json`,
`specs/CHANGE_LOG.md`, `specs/archive/`, plus the moved task directories. Confirm at
implementation time by re-reading `commands/todo.md`'s Steps 1-6.5 for every file the archival
flow writes (it also runs a metrics sync at Step 6.5 — check whether that lands before or after
the Step 6 commit, and include its output file only if it lands before). Adjust the list to what
the recipe actually does rather than to this hypothesis.

**Files to modify**:
- `agent-system/extensions/core/commands/task.md` - 2 occurrences (lines ~259, ~893)
- `agent-system/extensions/core/commands/todo.md` - 7 occurrences (line ~993 plus 6 variants at ~999-1014), and the comment extension at ~983-985

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh --verbose
  agent-system/extensions/core/commands/task.md
  agent-system/extensions/core/commands/todo.md` exits 0.
- `grep -c -- '-- specs/$' agent-system/extensions/core/commands/todo.md` returns 0.
- All 7 `todo.md` pathspec lists are byte-identical (diff the extracted pathspec tails).

---

### Phase 4: Fix the non-core extension sites [NOT STARTED]

**Goal**: The 5 occurrences in the epidemiology and present extensions stage explicit file lists,
closing the same hazard outside core.

**Tasks**:
- [ ] Re-read each file immediately before editing.
- [ ] `agent-system/extensions/epidemiology/commands/epi.md:325` (Step 5, task creation) —
      replace `-- specs/` with `-- specs/TODO.md specs/state.json`. Already passes
      `--honest-index-rows {N}`; leave it.
- [ ] `agent-system/extensions/present/commands/grant.md:223` (task creation) and
      `grant.md:476` (CHECKPOINT 2 revision commit) — same replacement. Both already pass
      `--honest-index-rows`.
- [ ] `agent-system/extensions/present/commands/slides.md:323` (Step 5, task creation) — same
      replacement.
- [ ] `agent-system/extensions/present/commands/timeline.md:227` (task creation) — same
      replacement. Note this site's block is indented 5 spaces inside a numbered list; preserve
      the indentation and the backslash continuation alignment.

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts **5** occurrences across 4 files, all task-creation (or
task-revision-creation) commits whose write set is exactly `specs/state.json` + `specs/TODO.md`.
Confirm at implementation time per site by reading its own preceding step for the scripts it
runs; `grant.md:476`'s revision commit in particular may also touch a grant-specific artifact
path, which must then be enumerated rather than assumed away.

**Files to modify**:
- `agent-system/extensions/epidemiology/commands/epi.md` - 1 occurrence (line ~325)
- `agent-system/extensions/present/commands/grant.md` - 2 occurrences (lines ~223, ~476)
- `agent-system/extensions/present/commands/slides.md` - 1 occurrence (line ~323)
- `agent-system/extensions/present/commands/timeline.md` - 1 occurrence (line ~227)

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh --verbose
  agent-system/extensions/epidemiology agent-system/extensions/present` exits 0.
- `grep -rn -- '-- specs/$' agent-system/extensions/epidemiology agent-system/extensions/present`
  returns nothing.

---

### Phase 5: Close out — lint green, docs cross-reference, deploy, follow-up [NOT STARTED]

**Goal**: The regression lint runs green across the whole source store with no violation-covering
allowlist entry, the standards doc points at it, the deploy tree reflects the source-store edits,
and the deliberately-excluded `verify-deploy.sh` gate wiring is recorded as a follow-up rather
than left as an undocumented hole.

**Tasks**:
- [ ] Run the new lint across the full default scan root with no path arguments. It must exit 0.
      If it still reports a violation, that is a Phase 2-4 miss — fix the site, never add an
      allowlist entry.
- [ ] Re-run `bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh
      --verbose` to confirm the sibling lint was not regressed by any of the edits.
- [ ] Add a cross-reference bullet to `agent-system/extensions/core/context/standards/git-staging-scope.md`'s
      closing reference list (alongside the existing `lint-scoped-commit-boundary.sh` bullet at
      ~line 376), naming the new lint as the mechanical guardrail against the bare
      shared-directory pathspec, and stating that it is **not yet** wired as a `verify-deploy.sh`
      gate with the one-line reason (critical-path exclusion) so the gap is self-documenting.
- [ ] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh` (or at minimum the two
      lint test suites) and confirm the new suite is auto-discovered and passes — `run-all.sh`
      discovers `scripts/tests/test-*.sh` with no registration step, so discovery itself is the
      check.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` so `.claude/` reflects the source-store edits,
      then confirm the deployed copies of the two new scripts exist at
      `.claude/scripts/lint/lint-directory-pathspec-boundary.sh` and
      `.claude/scripts/tests/test-lint-directory-pathspec-boundary.sh` (this is what validates the
      `manifest.json` registration from Phase 1).
- [ ] Run the full gate set (`bash .claude/scripts/verify-deploy.sh`) and confirm no gate
      regressed — in particular gate 8 (shell test suites) and gate 17 (the sibling commit-boundary
      lint).
- [ ] Record the follow-up explicitly in the task summary: wire
      `lint-directory-pathspec-boundary.sh` as a new `verify-deploy.sh` gate (gate 18), which
      requires editing an orchestrator-critical path and therefore belongs to a task that admits
      one. Also record the second, separate follow-up research identified: the ~25
      task-scoped-directory pathspec sites, and whether `git-staging-scope.md`'s sanctioning of
      that form should be narrowed.

**Timing**: 1 hour

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts that after Phases 2-4 the new lint's allowlist contains
exactly **2** entries, both self-reference (the lint and its test), and **zero** entries covering
a real violation. Confirm by reading the `EXCLUDED_FILES` array and checking each entry's inline
reason is a self-reference, not a deferral.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - add the new lint to the reference list, with the not-yet-gated note

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh` exits 0
  with no path arguments (full default scan root).
- `bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` exits 0.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0 and its discovered-suite
  count is one higher than before Phase 1.
- `bash .claude/scripts/deploy-headless.sh` exits 0 and both new scripts are present under
  `.claude/scripts/`.
- `bash .claude/scripts/verify-deploy.sh` exits 0.

---

## Testing & Validation

- [ ] `test-lint-directory-pathspec-boundary.sh` passes, asserting both polarities: every dirty
      fixture flagged, every clean fixture (explicit file list, task-scoped directory,
      `:(exclude)` token, prose mention) not flagged.
- [ ] `lint-directory-pathspec-boundary.sh` exits 1 against the pre-fix tree (Phase 1) and 0
      against the post-fix tree (Phase 5) — the before/after pair is the real regression evidence.
- [ ] `lint-scoped-commit-boundary.sh` still exits 0 (no sibling-lint regression).
- [ ] `grep -rn -- '-- specs/$' agent-system/extensions/` returns nothing.
- [ ] `bash -n` parses both new scripts.
- [ ] `run-all.sh` auto-discovers the new suite (discovered count +1).
- [ ] `verify-deploy.sh` exits 0 after `deploy-headless.sh`.
- [ ] No file under `.claude/**` was hand-edited (all changes originate in
      `agent-system/extensions/`); `git diff --stat` confirms.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-lint-directory-pathspec-boundary.sh` (new)
- `agent-system/extensions/core/manifest.json` (2 `provides` entries added)
- 9 recipe files with 17 pathspec occurrences replaced:
  `skills/skill-git-workflow/SKILL.md`, `agents/meta-builder-agent.md`,
  `skills/skill-meta/SKILL.md`, `commands/task.md`, `commands/todo.md` (core);
  `epidemiology/commands/epi.md`; `present/commands/{grant,slides,timeline}.md`
- `agent-system/extensions/core/context/standards/git-staging-scope.md` (cross-reference bullet)
- `specs/309_replace_directory_pathspecs_with_explicit_file_lists/summaries/01_*-summary.md`
  recording both follow-ups (the `verify-deploy.sh` gate wiring, and the task-scoped-directory
  pathspec class)

## Rollback/Contingency

Every change is a text edit to markdown recipes plus two new, unwired script files — there is no
runtime state to unwind and no migration to reverse. Phases 2, 3, and 4 are independently
revertable per file, and the commit-per-green-substep granularity means each file's revert is a
single `git revert` of its own commit.

If a rollback of uncommitted work becomes necessary, take a snapshot first per
`context/contracts/recovery.md`'s rollback rung (which gives the exact invocation shape,
including its out-of-scope override flag) before running any working-tree-discarding git command.
Do not emit a bare precautionary `git-snapshot.sh 309` at the start of a phase; if a defensive
checkpoint is wanted mid-phase, use the durable non-reverting `--no-revert` form instead.

Partial-completion contingency: Phase 1's lint is inert until wired into a gate, so shipping it
while some sites remain unfixed is safe but leaves the task's closing requirement unmet — in that
case mark the task `[PARTIAL]` and enumerate the unfixed sites from the lint's own output, rather
than adding allowlist entries to force a green run.
