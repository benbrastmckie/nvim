# Implementation Plan: Task #393

- **Task**: 393 - Propagate modified_files repo-relative-paths constraint to silent agents
- **Status**: [NOT STARTED]
- **Effort**: 7 hours
- **Dependencies**: None
- **Research Inputs**: specs/393_propagate_modified_files_constraint_to_silent_agents/reports/01_propagate-modified-files-constraint.md
- **Artifacts**: plans/01_propagate-modified-files-constraint.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Thirteen implementation agents never mention `modified_files` at all, so every one of them is
structurally capable of emitting the malformed entries that the drop-and-warn containment gate
(V9) in `git-commit-scoped.sh` now absorbs. This plan closes the producer-side gap by creating
one canonical fragment file carrying the constraint's exact text, inserting a literal copy of it
into each of the thirteen agent bodies (plus the `modified_files` key in each agent's metadata
JSON example), and adding a new `lint-agent-contracts.sh` check (Check L) with fixture coverage
so the copies cannot drift back out. Definition of done: the originating
`grep -L 'modified_files'` sweep returns nothing across all implementation agents, Check L passes
for every in-scope file, and the full gate set is green after a redeploy.

### Research Integration

The research report drives four decisions carried into this plan:

- **The propagation mechanism is not invented here.** This repo already propagates MUST-DO /
  MUST-NOT bullets across a curated agent set via a canonical fragment file under
  `context/contracts/` plus a matching `lint-agent-contracts.sh` check that greps every in-scope
  agent for the exact literal text (Checks C, G, H). This shape exists because `@`-references
  inside an agent body do **not** auto-resolve when Claude Code spawns a subagent — proven
  empirically and recorded in `context/contracts/no-task-references-bullet.md`'s
  "Generated-Copy Source, Not an `@`-Import" section. The fix must therefore be a literal copy in
  every agent body, kept in sync by the lint. Check L (next free letter: `A, B, C, E, F, G, H, I,
  J, K` are implemented, `D` is reserved for an unrelated deferred lint) follows Check C's shape
  directly.
- **The wording template is the no-progress-file one.** None of the thirteen target agents
  maintain a progress file or a `files_touched` accumulator, so the model to mirror is
  `email-implementation-agent.md`'s flat run-list wording (track on write -> flat list -> emit),
  not `general-implementation-agent.md`/`nix`/`neovim`'s progress-file-accumulation-plus-sum-step
  wording.
- **`modified_files` is not an artifact list.** The `implement` commit scope stages the whole task
  directory unconditionally, so the field exists for repo-tracked files touched *outside*
  `specs/{NNN}_{SLUG}/`. The propagated wording must not imply an agent should list its own
  summary or plan path.
- **There is no per-agent runtime test harness.** These are prompt files, not scripts. The static
  lint plus its fixture suite is the primary, repeatable verification surface; a live agent dry
  run is a spot-check, not the gate (see Phase 6 and Testing & Validation).

### Scope decision: thirteen agents, not ten

The dispatch's SCOPE line named ten agents, derived from
`grep -L 'modified_files' agent-system/extensions/*/agents/*implementation-agent.md`. That glob
cannot match a filename ending `-hard-agent.md`, so the three hard-mode implementation agents
(`cslib-implementation-hard-agent.md`, `lean-implementation-hard-agent.md`,
`books-implementation-hard-agent.md`) were never counted — and all three have zero mentions of
the field, the identical defect. This plan folds them in, as the research report recommends, for
three reasons: the defect is the same one, the edit is the same mechanical insertion, and
`lint-agent-contracts.sh`'s own in-scope arrays for Checks C/G/H already treat all three as
implementation agents. The widening is isolated in its own phase (Phase 4) so the ten agents the
dispatch named are delivered independently of it.

The four already-compliant agents (`general`, `email`, `nix`, `neovim`) are **not** edited and are
**not** in Check L's in-scope array. They document the constraint in their own pointer-style
voice, authored before this fragment existed; converting that established wording into the literal
bullet form is a uniformity decision with no defect behind it. This is a recorded exclusion with
its reason, written into both the fragment's classification rule and the lint's header comment —
not a silent omission.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- One canonical fragment file (`context/contracts/modified-files-bullet.md`) that is the single
  authoritative source for the propagated text, indexed like its sibling fragments.
- A literal copy of the canonical MUST-DO bullet and the canonical track-on-write line in each of
  the thirteen silent implementation agents' bodies, plus the `modified_files` key in each one's
  metadata JSON example.
- `check_l_modified_files_bullet` in `lint-agent-contracts.sh`, reading its expected text from the
  fragment at runtime (never hardcoded), wired into the main invocation list, with positive and
  negative fixtures and assertions in `test-lint-agent-contracts.sh`.
- Green full gate set after a redeploy, with the originating grep returning nothing.

**Non-Goals**:
- Editing the four already-compliant agents or folding them into Check L's array (recorded
  exclusion above).
- Changing `return-metadata-file.md`'s canonical `### modified_files (optional)` section — it is
  the source being propagated from and is already correct.
- Touching `git-commit-scoped.sh`'s V9 containment gate or anything else in sibling task 394's
  declared file scope.
- **Observed but deliberately out of scope**: the per-phase commit block in the smaller target
  agents (e.g. `z3-implementation-agent.md`'s Stage 4D) builds `stage_paths` from the task
  directory, `specs/TODO.md`, and `specs/state.json` only — it never stages the source files the
  phase just touched, unlike `general-implementation-agent.md`'s mechanized
  `git-commit-phase.sh` path. That is a distinct staging defect in the same files, not a
  `modified_files` self-report defect. Record it via `issue-record.sh` during implementation and
  leave it for its own task; do not fix it here.
- Dispatching all thirteen agents end-to-end for live verification (see Testing & Validation for
  the reasoning and the bounded substitute).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Adding Check L newly FAILs the existing `cslib-implementation-agent.md` scratch fixture, breaking two existing "produces no FAIL against it" assertions in `test-lint-agent-contracts.sh` | H | H | Known precisely, not discovered late: Phase 5 is a declared `atomic-batch` covering both the lint and the test suite, and its task list includes the fixture repair (adding both canonical lines to that fixture) as a first-class step — the same "required fixture repair" move Check E's rollout already made |
| The literal bullet text drifts between the fragment and the thirteen copies during a long multi-file phase | M | M | Check L reads the expected text from the fragment at runtime and FAILs any mismatch; Phases 2-4 each end with a `grep -cF` count over their own edited files before the phase closes |
| Per-agent stage shapes differ (`pr-review` has no development loop; the hard-mode agents have extra H-contract sections), so a mechanical "insert after Stage 4 step B" rule misplaces text | M | M | Placement is specified by role, not by line number: the track-on-write line goes under each agent's own apply-the-change step, the MUST-DO bullet as the next sequential item of its existing `**MUST DO**:` list, the JSON key into its own metadata example. Read each file immediately before editing it |
| New fragment file is absent from the deployed context index until the final redeploy, reading as a doc-lint finding | L | M | Doc-lint's deployed-index-orphan rule (Rule S) scans deployed `.claude/context/**` files, which the new fragment does not join until Phase 6's `deploy-headless.sh`. Rule R (source `line_count` accuracy) *does* apply at Phase 1, so Phase 1 sets `line_count` with `generate-context-line-counts.sh --write` rather than by hand |
| Sibling task 394 is dispatched this same cycle on this same working tree | M | M | Its declared file scope (`git-commit-scoped.sh`, `test-git-commit-scoped.sh`, `git-staging-scope.md`) is disjoint from every path in this plan. Re-read each file immediately before editing, stage only this task's own paths, never a directory or glob add, and report any foreign commit or modification rather than absorbing it |
| `pr-review-implementation-agent.md` commonly touches no file outside `specs/**`, so a generic bullet reads as if it should list its response artifacts | M | M | Its insertion carries one extra clause stating that `[]` is the expected and correct value on a response-only run, and that the field is populated only when a minor code change was actually applied |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |
| 4 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 2, 3, and 4 edit mutually disjoint
file sets.

### Phase 1: Author the canonical fragment and index it [NOT STARTED]

**Goal**: One authoritative fragment file carrying the exact text every later phase copies, plus
its context-index entry, so nothing downstream has to invent wording.

**Tasks**:
- [ ] Create `agent-system/extensions/core/context/contracts/modified-files-bullet.md`, modelled
      section-for-section on `context/contracts/no-task-references-bullet.md`: a
      "Generated-Copy Source, Not an `@`-Import" section citing that file's own empirical finding,
      the canonical text in fenced blocks, a classification rule, and a placement section.
- [ ] Record the canonical **MUST-DO bullet** in its own fenced block, as this exact single line
      (no digits, so it cannot trip `check-task-references.sh`'s own gate):
      ```
      Emit the top-level `modified_files` field in `.return-meta.json` on every dispatch: repo-relative paths only (never absolute), individual file paths only (never directory prefixes), paths inside this repository only, and `[]` when nothing was touched -- never omit the field -- per the "How Implementation Agents Populate modified_files" section of `.claude/context/formats/return-metadata-file.md`
      ```
- [ ] Record the canonical **track-on-write line** in a second fenced block, as this exact single
      line:
      ```
      Track on write: at the moment of every `Write`/`Edit`, append that file's repo-relative path to this run's flat touched-paths list immediately -- never reconstruct the list from memory at the end of the run -- then emit the deduped list as `modified_files` at the metadata-writing stage
      ```
- [ ] Write the classification rule: an agent carries both lines **iff** it is a dispatchable
      implementation agent that writes `.return-meta.json` for an `implement` operation. Enumerate
      the thirteen in-scope agents by relative path. Record the four already-compliant agents
      (`core/general`, `email`, `nix`, `nvim/neovim`) as an explicit exclusion with the reason
      given in this plan's "Scope decision" section.
- [ ] Write the placement rule: the track-on-write line goes under the agent's own
      apply-the-change step inside its development loop (or, for an agent without one, its
      code-change stage); the MUST-DO bullet goes as the next sequential item of the agent's
      existing `## Critical Requirements` `**MUST DO**:` list; the `"modified_files"` key goes
      into the agent's own metadata JSON example. Do not renumber or reword surrounding bullets.
- [ ] State in the fragment that the task directory is staged unconditionally by the `implement`
      commit scope, so this field exists for repo-tracked files touched **outside**
      `specs/{NNN}_{SLUG}/` — an agent must not list its own summary or plan path to satisfy it.
- [ ] Note in the fragment which of its content Check L verifies mechanically (both canonical
      lines, verbatim, plus presence of a `"modified_files"` key) and which is human-read guidance
      (the placement and classification prose).
- [ ] Add the matching entry to `agent-system/extensions/core/index-entries.json`, copying the
      field set of the existing `contracts/no-task-references-bullet.md` entry (`path`, `domain`,
      `subdomain`, `summary`, `line_count`, `keywords`, `topics`, `load_when` with three empty
      arrays, `on_demand: true`).
- [ ] Set `line_count` mechanically, never by hand:
      `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`, then
      confirm with `--check`.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3 /home/benjamin/.config/nvim`
— doc-lint is the only executable surface either touched file has, and its Rule R/Rule T checks
are exactly what an `index-entries.json` edit can break.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/modified-files-bullet.md` - new canonical fragment
- `agent-system/extensions/core/index-entries.json` - one new entry for the fragment

**Verification**:
- `generate-context-line-counts.sh --check` reports no drift for the new entry.
- The gate-3 subset above passes (TARGET is the repository root, not a per-extension `source_dir`
  — `verify-deploy.sh` requires both `$TARGET/.claude` and `$TARGET/agent-system/extensions`).
- Diff read-through confirming both canonical lines are byte-identical in intent to
  `return-metadata-file.md`'s Path form / Granularity / Empty behavior / remit-boundary rules.

---

### Phase 2: Propagate into five dispatch-named agents (books, cslib, pr-review, latex, lean) [NOT STARTED]

**Goal**: Five of the ten dispatch-named silent agents carry both canonical lines and the metadata
JSON key.

**Tasks**:
- [ ] For each file below, in order: re-read it immediately before editing (sibling task 394 is
      live on this tree), locate its apply-the-change step, its `**MUST DO**:` list, and its
      metadata JSON example.
- [ ] Insert the canonical track-on-write line verbatim under the apply-the-change step.
- [ ] Insert the canonical MUST-DO bullet verbatim as the next sequential item of the `**MUST DO**:`
      list, without renumbering or rewording surrounding items.
- [ ] Add `"modified_files": ["path/to/file/one.ext", "path/to/file/two.ext"],` to the agent's
      metadata JSON example as a top-level sibling of `artifacts`, never nested inside `metadata`
      or `completion_data`.
- [ ] `pr-review-implementation-agent.md` only: append one sentence to its MUST-DO insertion
      stating that `[]` is the expected and correct value on a response-only run, and that the
      field is populated only when a minor code change from the research report was actually
      applied to a file outside `specs/**`.
- [ ] `cslib-implementation-agent.md` and `lean-implementation-agent.md` are the two large files
      here (~735 and ~780 lines) and both have incidental "progress file" prose unrelated to
      `files_touched` — do not wire either into the progress-file accumulation shape; the flat
      run-list wording is correct for both.
- [ ] Count the result before closing: `grep -cF` each canonical line across the five files,
      expecting exactly one hit per line per file.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 6 /home/benjamin/.config/nvim`
— gate 6 runs `lint-agent-contracts.sh` over every agent file, the only executable surface an
agent prompt file has, and is what would catch a Check A-K regression caused by these insertions
(Check L does not exist until Phase 5, so the mechanical proof of the new lines is the `grep -cF`
count in this phase's own task list, not the lint).

**Scope Hypothesis**: five files, named below, each needing exactly three insertions. Confirm at
implementation time by re-running
`grep -L 'modified_files' agent-system/extensions/*/agents/*implementation-agent.md` before
starting — if the set has changed since 2026-10-16, adjust this phase's and Phase 3's file lists
and record the delta via `issue-record.sh` rather than silently editing a different set.

**Files to modify**:
- `agent-system/extensions/books/agents/books-implementation-agent.md` - track-on-write line, MUST-DO bullet, JSON key
- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` - track-on-write line, MUST-DO bullet, JSON key
- `agent-system/extensions/cslib/agents/pr-review-implementation-agent.md` - the three insertions plus the response-only `[]` clause
- `agent-system/extensions/latex/agents/latex-implementation-agent.md` - track-on-write line, MUST-DO bullet, JSON key
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - track-on-write line, MUST-DO bullet, JSON key

**Verification**:
- `grep -cF` of both canonical lines returns 1 per line for each of the five files.
- `grep -c '"modified_files"'` returns at least 1 for each of the five files.
- The gate-6 subset above passes with no new FAIL naming any of the five files.

---

### Phase 3: Propagate into the remaining five dispatch-named agents (python, rust, typst, web, z3) [NOT STARTED]

**Goal**: The other five dispatch-named silent agents carry both canonical lines and the metadata
JSON key.

**Tasks**:
- [ ] Apply Phase 2's identical three-insertion procedure to each file below, re-reading each file
      immediately before editing it.
- [ ] `web-implementation-agent.md` is the largest file in the task (~1009 lines) — locate its
      apply-the-change step and metadata example by heading, not by assuming the small agents'
      Stage 4 / Stage 7 numbering.
- [ ] Count the result before closing: `grep -cF` each canonical line across the five files,
      expecting exactly one hit per line per file.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 6 /home/benjamin/.config/nvim`
— same reasoning as Phase 2: gate 6's agent-contracts lint is the only check with any purchase on
an agent prompt file, and these five files share no surface with any other suite.

**Scope Hypothesis**: five files, named below, three insertions each; covered by Phase 2's
re-run-the-grep confirmation step (do not re-derive the set independently if Phase 2 already
recorded a delta).

**Files to modify**:
- `agent-system/extensions/python/agents/python-implementation-agent.md` - track-on-write line, MUST-DO bullet, JSON key
- `agent-system/extensions/rust/agents/rust-implementation-agent.md` - track-on-write line, MUST-DO bullet, JSON key
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` - track-on-write line, MUST-DO bullet, JSON key
- `agent-system/extensions/web/agents/web-implementation-agent.md` - track-on-write line, MUST-DO bullet, JSON key
- `agent-system/extensions/z3/agents/z3-implementation-agent.md` - track-on-write line, MUST-DO bullet, JSON key

**Verification**:
- `grep -cF` of both canonical lines returns 1 per line for each of the five files.
- `grep -c '"modified_files"'` returns at least 1 for each of the five files.
- The gate-6 subset above passes with no new FAIL naming any of the five files.

---

### Phase 4: Propagate into the three hard-mode agents [NOT STARTED]

**Goal**: The three hard-mode implementation agents the dispatch's glob could not reach carry the
same two canonical lines and the metadata JSON key.

**Tasks**:
- [ ] Confirm the gap still holds before editing:
      `grep -c 'modified_files' agent-system/extensions/{cslib,lean,books}/agents/*-implementation-hard-agent.md`
      expecting zero for all three.
- [ ] Apply the identical three-insertion procedure to each of the three files, re-reading each
      immediately before editing.
- [ ] Place each MUST-DO bullet inside the agent's existing `**MUST DO** (base agent
      requirements, plus):` list — these agents' Critical Requirements sections are phrased as
      deltas on the base agent, so do not restructure the heading.
- [ ] Leave every H-contract section (anti-analysis, territory, wrap-up discipline) untouched.
- [ ] Count the result before closing: `grep -cF` each canonical line across the three files,
      expecting exactly one hit per line per file.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 6 /home/benjamin/.config/nvim`
— gate 6's agent-contracts lint is the covering check for these three prompt files, exactly as in
Phases 2 and 3.

**Scope Hypothesis**: exactly three hard-mode implementation agents exist and all three currently
have zero `modified_files` mentions. Confirm with the `grep -c` call in this phase's first task;
if a fourth has appeared, add it here and record the delta via `issue-record.sh`.

**Files to modify**:
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` - track-on-write line, MUST-DO bullet, JSON key
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - track-on-write line, MUST-DO bullet, JSON key
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` - track-on-write line, MUST-DO bullet, JSON key

**Verification**:
- `grep -cF` of both canonical lines returns 1 per line for each of the three files.
- `grep -c '"modified_files"'` returns at least 1 for each of the three files.
- The gate-6 subset above passes with no new FAIL naming any of the three files.

---

### Phase 5: Add Check L and its fixture coverage [NOT STARTED]

**Goal**: The thirteen copies are mechanically enforced, and the lint's own regression suite
proves Check L fires on a missing copy, tolerates a conforming one, and fails loudly when the
fragment itself is absent.

**Tasks**:
- [ ] Add `MODIFIED_FILES_FRAGMENT="$REPO_ROOT/agent-system/extensions/core/context/contracts/modified-files-bullet.md"`
      alongside the existing fragment path variables.
- [ ] Add a `MODIFIED_FILES_IN_SCOPE_RELATIVE_PATHS` array holding the thirteen relative paths
      (the ten from Phases 2-3 plus the three from Phase 4), preceded by a header comment that
      records: why the set is curated rather than mechanically derived (mirroring Check C's own
      comment), and why the four already-compliant agents are deliberately absent.
- [ ] Implement `check_l_modified_files_bullet`, modelled on `check_c_no_task_references_bullet`:
      read both canonical lines from the fragment at runtime via `grep -F` on a distinctive
      anchor substring of each (never a hardcoded copy); `log_fail` by name if the fragment is
      missing; then, per in-scope file, FAIL if the file is absent, FAIL if either canonical line
      is missing, FAIL if no `"modified_files"` key is present, and `log_pass` by name otherwise.
- [ ] Use distinct, greppable FAIL message texts the test suite can assert on, in the established
      style — e.g. `"$rel: missing the modified_files MUST-DO bullet pair"` and
      `"$rel: missing a \"modified_files\" key"`, with the PASS line
      `"$rel: carries the modified_files bullet pair"`.
- [ ] Wire `check_l_modified_files_bullet` into `main()` after `check_k_await_notification_antipattern`,
      and add its one-line description to both the file header's check list and the `--help`
      output.
- [ ] **Fixture repair (do this in the same phase, before running the suite)**: add both canonical
      lines to the scratch `cslib/agents/cslib-implementation-agent.md` fixture in
      `test-lint-agent-contracts.sh`. That fixture is a real Check L in-scope path and is asserted
      twice to produce *no FAIL at all*, so Check L would otherwise break two existing assertions.
      Define the two lines as `MODIFIED_FILES_BULLET_LINE` / `MODIFIED_FILES_TRACK_LINE` shell
      variables next to the existing `BULLET_LINE` / `OWNERSHIP_BULLET_LINE` definitions, and give
      that fixture a `"modified_files": []` key as well.
- [ ] Add Check L assertions following the Check G/H assertion style already in the suite:
      (a) a missing-copy positive FAIL assertion against the scratch
      `z3/agents/z3-implementation-agent.md` fixture — a real Check L in-scope path that carries
      neither canonical line (the scratch `core/agents/general-implementation-agent.md` fixture is
      unsuitable here: that path is not in Check L's in-scope array);
      (b) a near-miss paraphrase positive case using the scratch
      `lean/agents/lean-implementation-agent.md` fixture, proving the match is verbatim rather
      than loose;
      (c) a no-FAIL plus explicit-PASS-by-name negative pair against the repaired
      `cslib/agents/cslib-implementation-agent.md` fixture;
      (d) a fragment-missing assertion against the existing bare `FRAGDIR` scratch tree, expecting
      a named `"Check L: canonical fragment not found"` line — never a silent pass.
- [ ] Update the test file's header comment to describe the Check L fixtures and the fixture
      repair, as the Check E and Check H rollouts each did for their own additions.
- [ ] Run the suite and the lint against the real tree, and only then commit the batch.

**Timing**: 1.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: local

**Commit Mode**: atomic-batch

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh`
-- strict basename pairing resolves `lint-agent-contracts.sh` to exactly that one suite, which is
the dedicated regression harness for every check in this script and the only suite either touched
file participates in.

**Scope Hypothesis**: `L` is the next free check letter (`A, B, C, E, F, G, H, I, J, K`
implemented; `D` reserved by an in-file comment for a deferred body-skeleton-drift lint). Confirm
by grepping the script for `check_[a-z]_` definitions and for the `D` reservation comment before
naming the new function; if `L` is taken, use the next free letter and update this plan's prose
via a deviation annotation.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - fragment path variable, in-scope array with its header comment, `check_l_modified_files_bullet`, `main()` wiring, header and `--help` text
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` - two new line variables, cslib fixture repair, four Check L assertion groups, header comment update

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh`
  passes (strict basename pairing resolves `lint-agent-contracts.sh` to exactly this suite), with
  zero failures and the new Check L assertions all reported as passed.
- `REPO_ROOT=/home/benjamin/.config/nvim bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`
  exits 0, with a Check L PASS line naming each of the thirteen in-scope files.
- The intermediate state after editing only one of the two files is expected red and is not
  committed; the phase commits once, when both are green.

---

### Phase 6: Redeploy and run the full gate set [NOT STARTED]

**Goal**: The source-store change is deployed, the whole repository is green, and the originating
defect sweep returns nothing.

**Tasks**:
- [ ] Re-run the originating sweep and expect no output:
      `grep -L 'modified_files' agent-system/extensions/*/agents/*implementation-agent.md agent-system/extensions/*/agents/*-implementation-hard-agent.md`.
- [ ] Redeploy so the deployed `.claude/` tree carries the new fragment, the thirteen edited agent
      bodies, the new lint check, and a regenerated `context/index.json`:
      `timeout 540 bash .claude/scripts/deploy-headless.sh` (use the Bash tool's own `timeout`
      parameter rather than ending the turn on an unresolved wait).
- [ ] Run the complete gate set: `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim`
      (TARGET is the repository root — `verify-deploy.sh` requires both `$TARGET/.claude` and
      `$TARGET/agent-system/extensions`, which no per-extension `source_dir` path satisfies).
- [ ] Triage every finding against this task's own file scope. A finding in a path outside it —
      particularly in sibling task 394's declared scope (`git-commit-scoped.sh`,
      `test-git-commit-scoped.sh`, `git-staging-scope.md`) — is reported, with `git log` /
      `git status` evidence of whose work it is, never absorbed or fixed here.
- [ ] Record the deliberately-deferred per-phase staging gap named in this plan's Non-Goals via
      `issue-record.sh --kind issue --class "..." --severity minor`.
- [ ] Confirm no live agent dry run is owed: the dispatch's "its own test fixtures if any exist, or
      a manual dry run" condition is satisfied by the fixture route, since fixtures now exist for
      this exact constraint (see Testing & Validation).

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:
- None planned (verification and deployment only; `deploy-headless.sh` regenerates the deployed `.claude/` tree, which is a disposable deploy artifact and is never hand-authored)

**Verification**:
- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes successfully.
- The complete gate set — `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim`,
  all gates including gate 3 (doc-lint), gate 4 (task-reference lint), gate 6 (agent contracts
  lint, now carrying Check L), and gate 8 (the full shell-suite battery) — reports no failures
  attributable to this task's file scope.
- The originating `grep -L` sweep produces no output across all implementation agents, hard-mode
  included.

---

## Testing & Validation

- [ ] `generate-context-line-counts.sh --check` clean for the new fragment entry (Phase 1).
- [ ] Both canonical lines present exactly once in each of the thirteen agent files, confirmed by
      `grep -cF` (Phases 2-4).
- [ ] A `"modified_files"` key present in each of the thirteen agents' metadata JSON examples
      (Phases 2-4).
- [ ] `run-all.sh --only test-lint-agent-contracts.sh` passes, including the four new Check L
      assertion groups and the repaired cslib fixture (Phase 5).
- [ ] `lint-agent-contracts.sh --verbose` exits 0 against the real tree with a Check L PASS line
      per in-scope file (Phase 5).
- [ ] Full `verify-deploy.sh` green after `deploy-headless.sh` (Phase 6).
- [ ] Originating `grep -L 'modified_files'` sweep returns nothing (Phase 6).

**On the "manual dry run" the dispatch mentions**: no per-agent runtime harness exists for "does
agent X emit a well-formed `modified_files` field" — these are LLM prompt files, not scripts, and
the only automated verification surface is the static lint plus its fixture suite. This plan makes
that surface cover the constraint for the first time (Check L), which satisfies the dispatch's
"its own test fixtures if any exist" branch and is strictly more repeatable than dispatching
thirteen agents end-to-end. A live dry run through one small agent (e.g. `z3` or `rust`) remains a
legitimate optional spot-check; it is not a gate and is not required for phase or task closure.

## Artifacts & Outputs

- `agent-system/extensions/core/context/contracts/modified-files-bullet.md` (new canonical fragment)
- One new entry in `agent-system/extensions/core/index-entries.json`
- Thirteen edited implementation agent definitions (ten dispatch-named, three hard-mode)
- `check_l_modified_files_bullet` in `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`
- Check L fixtures, assertions, and the cslib fixture repair in
  `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh`
- `specs/393_propagate_modified_files_constraint_to_silent_agents/summaries/01_propagate-modified-files-constraint-summary.md` (written at implementation close)

## Rollback/Contingency

Every change is additive text in markdown prompt files, one JSON index entry, and one new bash
function plus its fixtures — there is no migration, no state change, and no consumer that breaks
if the change is reverted. Phases 2, 3, and 4 are independently revertible by file, and Phase 5's
two files revert together as the single atomic batch they were committed as.

If a later gate run proves the change must come out, revert the specific commits rather than
discarding the working tree. If a rollback genuinely requires discarding uncommitted work first,
take the snapshot per `context/contracts/recovery.md`'s rollback rung — including its
out-of-scope override flag for the deliberate whole-tree case — and never reach for a bare
reverting `git-snapshot.sh` as a routine precaution. For an ordinary defensive checkpoint before
Phase 5's atomic batch, use the durable non-reverting form (`git-snapshot.sh --no-revert`).

A reverted deployed tree is recovered by re-running `deploy-headless.sh`, never by hand-patching
under `.claude/**`.
