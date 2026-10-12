# Research Report

**Task**: 302 - Scoped commit directory pathspec and task lease
**Started**: 2026-10-11T18:10:00Z
**Completed**: 2026-10-11T19:05:00Z
**Effort**: Research pass, single dispatch
**Dependencies**: None (Half 1 of this task is complete; task 322, the rename-staging
regression it caused, is already completed and archived)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/git-commit-scoped.sh`,
  `agent-system/extensions/core/context/standards/git-staging-scope.md`,
  `agent-system/extensions/core/scripts/lib/territory-contention-lib.sh`,
  `agent-system/extensions/core/scripts/task-lock.sh`,
  `agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh`, and the nine
  declared recipe files in this task's `file_scope`
- `specs/state.json` (file_scope declarations, task 322/390 lookups)
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Half 1 (directory-pathspec-to-explicit-file-list replacement) is independently reconfirmed
  complete; no re-audit was performed per the dispatch's instruction, only a spot check of the
  Half-1 completion claim via the same grep the dispatch cites.
- Of the 9 declared `file_scope` recipe files, 8 contain one or more live
  `git-commit-scoped.sh` call sites that currently omit `--task`. Per-site ruling (below): **8
  sites should gain `--task {N}`** (single-task-creation commits that already carry
  `--honest-index-rows {N}` on the identical number), and **3 sites should document, not
  acquire, the omission** (two multi-task-spanning `commands/todo.md` commits and one
  N-task-batch commit in `agents/meta-builder-agent.md`, none of which has a single owning task
  number for `--task` to key on).
- The "ALSO IN SCOPE" carve-out question (should the ~25-36 sanctioned task-scoped-directory
  sites be narrowed to explicit file lists) should be **ruled closed as "leave as-is"**: a newly
  surfaced fact not in the dispatch's own framing — `task-lock.sh`'s per-task-number
  acquire/release lock, already invoked at `command-gate-in.sh` for every command — structurally
  prevents the "concurrent in-place plan revision" scenario the dispatch posed as the main
  argument for narrowing. Combined with the already-documented own-territory confinement and
  exclude-injection arguments, narrowing ~36 live call sites across 15 extension files buys no
  safety benefit commensurate with the rename-pairing audit cost it would impose.
- The "CLOSE BY" live-refusal demonstration is already satisfied **at the primitive level** by
  `test-git-commit-scoped.sh`'s existing V4 case (a path held by another live task refuses with
  exit 3, HEAD unchanged). A **recipe-level** demonstration (one of this task's own
  newly-`--task`-engaged call sites, post-edit, actually refusing) cannot be produced during
  research — it requires the edits to exist first — and is recorded below as the implementation
  phase's concrete verification recipe.

## Context & Scope

This is the research phase for task 302's Half 2: auditing every commit-staging recipe site
declared in `file_scope` for whether `git-commit-scoped.sh`'s `--task <N>` lease-consulting flag
is passed, ruling per-site (never blanket) on whether to add it, and separately ruling on
whether the sanctioned task-scoped-directory pathspec carve-out in
`context/standards/git-staging-scope.md` / `lint-directory-pathspec-boundary.sh` should be
narrowed. Per the dispatch, Half 1 is done and not re-audited; task 322 (the rename-staging
regression Half 1 introduced) is confirmed completed and archived
(`specs/archive/state.json` `completed_projects[]` entry for project_number 322,
`status: "completed"`), so its rename-pairing fix and the `git-staging-scope.md` "Rename and
Directory-Move Staging" section are already in place and were read, not re-derived.

All findings below are scoped to the 9 files in task 302's declared `file_scope`:
`agents/meta-builder-agent.md`, `commands/task.md`, `commands/todo.md`,
`context/standards/git-staging-scope.md`, `skills/skill-git-workflow/SKILL.md`,
`skills/skill-meta/SKILL.md`, `epidemiology/commands/epi.md`, `present/commands/grant.md`,
`present/commands/slides.md`, `present/commands/timeline.md` (all under
`agent-system/extensions/`).

## Findings

### How the `--task` lease actually works (mechanism recap, for the per-site ruling below)

`git-commit-scoped.sh --task <N>` (`agent-system/extensions/core/scripts/git-commit-scoped.sh`,
V5 gate) checks each **positive** pathspec entry against
`specs/.contention-manifest/${session_id}.json` — a manifest built once per `/orchestrate`
cycle by `build_contended_manifest()` in `scripts/lib/territory-contention-lib.sh`, populated
**only** from the declared `file_scope` of tasks dispatched that same cycle. A path is
"contended" only if **two or more** cycle-dispatched tasks declare an overlapping `file_scope`
entry for it. If no manifest exists (no `/orchestrate` cycle, or a single-task cycle), or the
named path is not in any manifest, `--task` is a complete no-op — this is the fail-open design,
confirmed in the script's own header and reproduced by the test suite's V1/V7 cases.

**Load-bearing fact for the per-site ruling**: `specs/state.json` and `specs/TODO.md` are *not*
structurally exempt from ever being contended. A live query of `specs/state.json` found three
tasks (273, 344, completed; 390, not yet started) that declare `specs/state.json` and/or
`specs/TODO.md` literally in their own `file_scope` — i.e., tasks about the state-management
system itself. If such a task is ever dispatched in the same `/orchestrate` cycle as one of this
task's recipe sites' commits, `--task` is the only thing that makes the lease on those two
universally-shared files actually get consulted. This is exactly the systemic shape the dispatch
describes ("the mechanism did not fail; it was never consulted") — and it is *this* class of
site, not an unusual one, that stands to benefit most, since `specs/state.json` /
`specs/TODO.md` are the single most-shared files in the whole system.

### Per-site ruling (8 files, 12 concrete call sites)

| # | File : site | Current state | Ruling | Reason |
|---|---|---|---|---|
| 1 | `skills/skill-git-workflow/SKILL.md` "Task Commit" template (~line 206) | Carries `--honest-index-rows {N}`, no `--task` | **Add `--task {N}`** | Single, known task number; this is the documentation-front template other recipes copy — fixing it here keeps future copies correct by default |
| 2 | `skills/skill-git-workflow/SKILL.md` "Standard Commit" template (~line 200) | No task-number concept at all (arbitrary `{files}` scope) | **N/A — leave as-is** | This form is explicitly for operations with no governing task number (e.g. `sync:`, `review:`); there is nothing to key `--task` on |
| 3 | `commands/task.md` Step 7 (~line 245) | Carries `--honest-index-rows {N}`, no `--task` | **Add `--task {N}`** | Single newly-created task number, identical to what `--honest-index-rows` already uses |
| 4 | `commands/todo.md` Step 6, archival commit (3 message variants, ~lines 756-772) | No `--honest-index-rows`, no `--task`; already documents the `--honest-index-rows` omission inline ("this archival operation legitimately spans many tasks' rows in one commit") | **Document, do not add** | This commit spans an arbitrary number of archived tasks in `stage_paths`; there is no single owning task number, by the same reasoning already in the file for `--honest-index-rows` |
| 5 | `commands/todo.md` Step 6.5.3, metrics-sync commit (~line 822) | No `--honest-index-rows` ("this commit touches nothing task-scoped at all"), no `--task` | **Document, do not add** | Stages only `specs/state.json` for a repo-wide metrics field; no task identity applies at all |
| 6 | `agents/meta-builder-agent.md` Stage 6 git commit (~line 964) | Explicitly documents the `--honest-index-rows` omission ("creates N tasks in one call, so there is no single owning task number") | **Document, do not add** | Same N-task-batch shape as todo.md's archival commit; even the N=1 case runs through this same batch code path with no per-task branch to key `--task` off |
| 7 | `skills/skill-meta/SKILL.md` postflight commit (~line 327) | Carries `--honest-index-rows {N}`, no `--task` | **Add `--task {N}`**, with a caveat | See "Caveat" below — the template's own worked example shows `tasks_created: 2`, i.e. this path is not always single-task despite its singular `{N}`/`{title}` message form |
| 8 | `epidemiology/commands/epi.md` Step 5 (~line 318) | Carries `--honest-index-rows {N}`, no `--task` | **Add `--task {N}`** | Single newly-created task number |
| 9 | `present/commands/grant.md` Step 8, create (~line 216) | Carries `--honest-index-rows {N}`, no `--task` | **Add `--task {N}`** | Single newly-created task number |
| 10 | `present/commands/grant.md` CHECKPOINT 2, revision (~line 472) | Carries `--honest-index-rows {NEW_N}`, no `--task` | **Add `--task {NEW_N}`** | Single newly-created revision task number |
| 11 | `present/commands/slides.md` Step 5 (~line 316) | Carries `--honest-index-rows {N}`, no `--task` | **Add `--task {N}`** | Single newly-created task number |
| 12 | `present/commands/timeline.md` Step 8 (~line 220) | Carries `--honest-index-rows {N}`, no `--task` | **Add `--task {N}`** | Single newly-created task number |

**Mechanical rule used to decide, stated once rather than repeated per row**: wherever
`--honest-index-rows {N}` (or `{NEW_N}`) is already present and keyed to one concrete,
newly-created task number, `--task` on that identical number is a direct, low-risk, symmetry-
preserving addition — both flags consult the same "is this commit genuinely scoped to one task"
question, just from opposite directions (one flags unexpected *other* rows swept in; the other
refuses before staging if *this* commit's own named paths are held by another task). Wherever
`--honest-index-rows` is *already* documented as inapplicable because no single task number
governs the commit, `--task` inherits the identical inapplicability for the identical reason —
there is no number to pass, not merely an unused opportunity to pass one.

**Caveat on row 7** (`skill-meta/SKILL.md`): unlike the other single-task sites, this skill's own
worked examples (`"mode": "interactive", "tasks_created": 2`) show that its postflight commit can
legitimately fire after a *batch* of tasks was created by `meta-builder-agent`, not only after
one. Its message template (`"task {N}: create {title}"`) and its `--honest-index-rows {N}` are
*already* ambiguous in that N>1 case today — this is a pre-existing gap, not one introduced by
this task. Adding `--task {N}` inherits that same ambiguity rather than worsening it, and is
safe in the dominant case (the agent's own Stage-6 commit, which never takes `--task`, already
landed the batch commit, so this postflight commit finds nothing staged and the lease check
never matters). Fully resolving the N>1 identity gap would require redesigning this template to
branch on `tasks_created`, which is out of this task's scope — flagged here as a recommended
follow-up, not a blocker to the mechanical `--task {N}` addition.

### The task-scoped directory carve-out: ruling — leave as-is

**Scale check**: running `lint-directory-pathspec-boundary.sh --verbose` and filtering to live
call sites (excluding `docs/`, `context/`, and the lint's own test fixtures) found **36**
sanctioned task-scoped-directory tokens across 15 files in `founder/`, `lean/`, `present/`,
`epidemiology/`, `web/`, and `core/` (`skill-reviser/SKILL.md`) — close to, and likely the source
of, the dispatch's "~25" estimate. None of the 36 live sites are at a rename/move operation; they
are all ordinary research/plan/implement-completion commits staging one task's own artifact
subdirectory (`reports/`, `plans/`, `summaries/`, or the whole `${task_dir}/`).

**Arguments weighed, per the dispatch's own framing**:

1. *For narrowing*: a task-scoped directory pathspec over-stages *within* the task's own
   territory — it would sweep in any uncommitted write to that same directory, from any source,
   not just the content this specific operation produced. The dispatch names "a concurrent
   in-place plan revision" as the concrete scenario.
2. *Against narrowing* (already in `git-staging-scope.md`): the over-stage is confined to one
   task's own directory, so the cross-session bleed Half 1 fixed does not apply; and
   `git-commit-scoped.sh` already injects `:(exclude)...` entries for the canonical
   ephemeral-runtime-file candidate set (`.orchestrator-loop-guard`, `.orchestrator-churn-state.json`,
   `.drift-inspection.json`, `.lock/`, `.dispatch/`) for exactly these directories, so the
   specific *known-risky* content is already carved out.

**New finding, not present in the dispatch's own framing, that resolves the weighing**:
`task-lock.sh`'s per-task-number `.lock/` acquire/release mechanism (`acquire`/`acquire-retry`/
`release`/`check`) is invoked at `command-gate-in.sh` — the shared preflight gate for commands —
and explicitly by `commands/revise.md`, alongside the `/orchestrate` planning/admission scripts
(`orchestrate-triage-classify.sh`, `orchestrate-batch-admit.sh`, `orchestrate-predispatch-review.sh`,
`orchestrate-cycle-plan.sh`). This means **two dispatches against the same task number cannot run
concurrently** under the lock-respecting flow every command already goes through. The
"concurrent in-place plan revision" scenario argument (1) requires — a second write to the same
task's directory happening *while* this task's own commit is being staged — is therefore not a
gap this staging-pathspec question needs to close; it is already closed, by a different,
orthogonal mechanism, before the question of *what to stage* is ever reached.

**Conclusion**: narrowing the carve-out would cost a real, non-trivial implementation effort (36
call sites across 15 files, each requiring the "Rename and Directory-Move Staging" both-endpoints
audit the dispatch itself warns is easy to get wrong — task 322 is the demonstrated cost of
exactly that mistake) for a scenario the system already prevents at the dispatch-lock layer. The
carve-out should be **ruled closed: leave as-is**, and the ruling — including the task-lock
finding above, which is new and should be added rather than merely repeating the dispatch's own
two bullets — should be recorded in `context/standards/git-staging-scope.md`'s existing
cross-reference to `lint-directory-pathspec-boundary.sh` (the "**Not yet** wired as a
`verify-deploy.sh` gate" paragraph is the natural place to add a short "and deliberately not
narrowed" note, since it already discusses this exact lint and carve-out).

### "Close by": live-refusal demonstration — status and recommended recipe

The underlying *primitive* is already proven live, not merely textually present:
`scripts/tests/test-git-commit-scoped.sh`'s V1-V7 block (`task-ref-ok` fixture data, synthetic
task numbers 401 etc.) includes a case explicitly asserting exit 3 — "V4: a path held by another
live task refuses (exit 3), HEAD unchanged" — by constructing a
`specs/.contention-manifest/<session>.json` naming a path as contended, pre-claiming it under a
different task number via `task-lock.sh claim-acquire`, then invoking `git-commit-scoped.sh
--task <other N>` against that same path and asserting the exit code and that `HEAD` did not
advance.

What this task's own "CLOSE BY" instruction additionally asks for — a **recipe-level**
demonstration, i.e. one of the 8 call sites in the ruling above, post-edit, actually refusing —
cannot be produced now: the `--task` flag does not yet exist in any of those files, so there is
nothing recipe-level to run. This is recorded as the implementation phase's own verification
step, with a concrete recipe rather than a vague "add a test" instruction:

1. Pick one edited site, e.g. `commands/task.md` Step 7 (`--task {N}` added).
2. In a scratch git repo (mirroring `test-git-commit-scoped.sh`'s own harness pattern, never the
   live repo), create `specs/.contention-manifest/<session>.json` naming `specs/state.json` as
   contended between two synthetic task numbers.
3. Pre-claim `specs/state.json` under task A via `task-lock.sh claim-acquire`.
4. Run the exact bash block from `commands/task.md` Step 7 with `--task <task B>` and the
   session id used to build the manifest.
5. Assert exit code 3, and that `specs/state.json`/`specs/TODO.md` are unchanged in the index —
   proving the specific recipe's own invocation, not just the underlying primitive, refuses.

This is the natural first phase-1 verification item for the implementation plan, and should be
written as a small, throwaway integration probe (or an additional case appended to
`test-git-commit-scoped.sh` itself, parameterized by the recipe's own invocation form) rather
than skipped.

## Decisions

- Half 1 is not re-audited; its completion is independently reconfirmed via the dispatch's own
  cited grep, which returns only `git status`/`git diff`/fixture matches, no live staging sites.
- 8 of 12 audited call sites across the 9 declared `file_scope` files get `--task {N}` added,
  mirroring the identical number each already uses for `--honest-index-rows`; 4 of 12 (2 in
  `commands/todo.md`, 1 in `agents/meta-builder-agent.md`, plus `skill-git-workflow/SKILL.md`'s
  generic "Standard Commit" template) are ruled inapplicable and should instead gain a short
  documentation note explaining why, mirroring the `--honest-index-rows`-omission prose already
  present at two of those three sites.
- `skill-meta/SKILL.md`'s site gets `--task {N}` too, with an explicitly flagged pre-existing
  `tasks_created > 1` identity ambiguity recorded as a follow-up, not a blocker.
- The task-scoped directory carve-out in `git-staging-scope.md` / `lint-directory-pathspec-
  boundary.sh` is ruled **closed: leave as-is**, on the strength of a newly surfaced fact (the
  per-task `task-lock.sh` dispatch lock) that the dispatch's own framing did not have in hand.
- The "CLOSE BY" live-refusal demonstration is satisfied at the primitive level today
  (`test-git-commit-scoped.sh`'s existing V4 case); a recipe-level demonstration is deferred to
  the implementation phase as a concrete, five-step verification recipe (above), since it
  structurally requires the edits to exist first.

## Risks & Mitigations

- **Risk**: mechanically adding `--task {N}` to 8 sites without re-reading each file immediately
  before editing could collide with a concurrent sibling dispatch touching the same files this
  cycle (per this dispatch's own Territory block: tasks 373 and 347 are concurrent siblings this
  cycle, but neither touches any of this task's 9 declared files, so no overlap is expected —
  still, the implementation phase should re-check `git status` immediately before each edit per
  the standing concurrency note).
- **Risk**: the `skill-meta/SKILL.md` `tasks_created > 1` ambiguity (noted above) could, in a
  rare case, cause an incorrect lease claim attributed to the wrong task number. Mitigated by
  the dominant-case analysis above (the agent's own commit almost always lands first, leaving
  nothing for this postflight commit to stage) and by flagging it explicitly rather than quietly
  accepting a false precision.
- **Risk**: leaving the carve-out as-is without recording the task-lock finding would leave a
  future auditor re-deriving the same "should we narrow this" question from the same two
  dispatch-framed arguments alone, absent the fact that actually settles it. Mitigated by
  recommending the finding be written into `git-staging-scope.md` itself (implementation phase),
  not left only in this report.

## Context Extension Recommendations

- **Topic**: per-task dispatch locking as a factor in staging-scope decisions.
- **Gap**: `git-staging-scope.md`'s "Concurrency Qualifier" section discusses the contended-path
  lease (`--task`) and working-tree isolation as the two remedies for cross-dispatch hazards, but
  does not mention `task-lock.sh`'s per-task-number lock at all, even though it is directly
  relevant to reasoning about *same-task* concurrent-write hazards (as opposed to the
  *cross-task* hazard the rest of that section is about).
- **Recommendation**: when the implementation phase edits `git-staging-scope.md` to record the
  carve-out ruling, also add a one-paragraph cross-reference from the "Concurrency Qualifier"
  section to `task-lock.md`'s per-task lock, so a future reader evaluating a same-task staging
  question does not have to re-discover it via a fresh codebase search.

## Appendix

### Search queries / commands used

- `grep -rn -E -- '--[[:space:]]+specs/([[:space:]]|$|\\)' agent-system/extensions/` (Half 1
  reconfirmation, per dispatch's own cited command)
- `grep -rn "git-commit-scoped.sh" agents/meta-builder-agent.md commands/task.md commands/todo.md
  skills/skill-git-workflow/SKILL.md skills/skill-meta/SKILL.md` and the four extension command
  files, read in full context around each match
- `jq -r '.active_projects[].file_scope[]?' specs/state.json | sort -u | grep -i
  "state.json\|TODO.md"` and the follow-up `select(...)` query identifying tasks 273/344/390
- `bash agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh --verbose`
  filtered to live call sites (excluding `docs/`, `context/`, and the lint's own fixtures)
- `grep -rln "task-lock.sh acquire\b\|task-lock.sh acquire-retry"` across `scripts/`, `skills/`,
  `commands/`
- Read: `git-commit-scoped.sh` (full), `git-staging-scope.md` (full),
  `territory-contention-lib.sh` (build_contended_manifest), `task-lock.sh` (header/usage),
  `test-git-commit-scoped.sh` (V1-V7 contention block)

### References

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — `--task` / V5 gate implementation
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — per-operation scope
  contract, carve-out documentation, rename-pairing rule (task 322's landed fix)
- `agent-system/extensions/core/scripts/lib/territory-contention-lib.sh` — contention manifest
  producer
- `agent-system/extensions/core/scripts/task-lock.sh` — per-task lock and claim-lease verbs
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — existing V1-V7
  contention test block
