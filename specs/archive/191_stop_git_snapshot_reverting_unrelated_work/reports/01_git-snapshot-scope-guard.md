# Research Report: Task #191

**Task**: 191 - Stop git-snapshot reverting unrelated work
**Started**: 2026-09-09
**Completed**: 2026-09-09
**Effort**: medium (script guard + planner guidance + stash identity; all in one extension)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts/git-snapshot.sh, planner-agent.md, general-implementation-agent.md, general-research-agent.md, recovery.md, state-management-schema.md, test-guard-destructive-git.sh), live specs/state.json data, git history (task 186 plan)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The revert hazard is real and by design, not a bug in the script's logic: default mode's
  `git stash push -u` and `--branch` mode's commit-then-checkout both leave the tree clean at
  HEAD. `--no-revert` already exists, is correctly used everywhere the codebase's own agents
  call it (`general-implementation-agent.md`, `general-research-agent.md`), and MUST NOT change.
- The incident's actual origin is `specs/186_fix_deploy_headless_path_in_regeneration_doc/plans/01_fix-deploy-headless-invocation-path.md:191`, a plan step reading `Snapshot the working tree
  before any edits: bash .claude/scripts/git-snapshot.sh 186` — bare default mode, invented ad
  hoc by whatever wrote that plan. No template, format doc, or agent contract instructs emitting
  this step at all; `planner-agent.md`'s plan template has no snapshot boilerplate. The fix is
  two-layered: (1) a runtime guard in the script itself (primary, catches every caller
  regardless of source), (2) an explicit `MUST NOT` bullet in `planner-agent.md` (secondary,
  stops future plans from re-inventing the unsafe idiom).
- `file_scope` (the field the dispatch's design direction names as the scope oracle) is
  populated on 60/67 currently active tasks, but is optional, prospective/not
  filesystem-validated, and its entries mix exact paths, directory prefixes (`foo/bar/`), and
  glob patterns (`agent-system/extensions/*/agents/**`) — a guard comparing the dirty tree
  against it needs prefix+glob matching, not just string equality, and needs an explicit
  fallback for the ~10% of tasks with no `file_scope` at all.
- `guard-destructive-git.sh` only checks for a fresh `.git-snapshot-marker` file's existence/age
  — it never inspects the stash message string, so changing the stash/`git stash store` message
  format (to embed the task number) for the secondary stash-identity fix is safe and touches no
  other consumer.
- The existing fixture-driven test convention (`scripts/tests/test-guard-destructive-git.sh`,
  which drives a hook binary as a subprocess against a synthetic dirty git repo and asserts exit
  codes) is the template to reuse for the acceptance-criterion fixture test; it would live at
  `agent-system/extensions/core/scripts/tests/test-git-snapshot.sh` and is auto-discovered by
  `scripts/tests/run-all.sh`'s `test-*.sh` glob — no registration step needed.

## Context & Scope

Researched: (1) why `git-snapshot.sh` reverts by default and where that is/isn't already
guarded against, (2) where the plan-mandated bare-default-mode call actually came from, (3) the
shape and reliability of `file_scope` as the scope-comparison oracle the dispatch's design
direction names, (4) the stash-identity/accumulation problem, (5) the test convention to follow
for the required fixture test. Scope is source-store only (`agent-system/extensions/core/`),
per the dispatch's opening line — `.claude/**` is a disposable deploy artifact and is never the
edit target.

## Findings

### Codebase Patterns

**`git-snapshot.sh` (`agent-system/extensions/core/scripts/git-snapshot.sh`, 372 lines) mode
mechanics**:
- Default mode (lines ~322-331): `git stash push -u -m "git-snapshot-${TS}"` — reverts tracked
  and untracked changes, leaves tree clean at HEAD.
- `--branch` mode (lines ~271-287): commits dirty tree to `wip-snapshot-{ts}`, checks out
  original branch — same revert outcome via a different recovery handle.
- `--no-revert` mode (lines ~288-321): `git stash create` + `git stash store` (builds/records a
  stash *object* without touching the working tree or `refs/stash`), plus a manual copy of
  untracked files to `untracked-backup-{ts}/` since a diff can't represent them. Tree is left
  exactly as found. This mode already fully exists and is correct — nothing here should change.
- `resolve_task_dir()` (lines 151-213) already resolves TASK to a `specs/{NNN}_{SLUG}` dir from
  an explicit number/path, or by inference (single task with status `implementing` in
  `specs/state.json`, needs `jq`). This is the natural place to also resolve the task's
  `project_number` (from the directory basename) for a `file_scope` lookup, and `jq` is already
  a hard dependency of the inference path, so no new dependency is introduced by reading
  `file_scope` too.
- Correct callers already exist and must not be touched: `general-implementation-agent.md`
  line 360 and `general-research-agent.md` lines 178-182 both call
  `git-snapshot.sh --no-revert {task_number}` specifically *because* default/`--branch` would
  erase the RED work the checkpoint step exists to protect. `recovery.md`'s rung (c) (lines
  59-80) is the one documented case where the *reverting* default mode is the deliberately
  intended behavior — "only if truly required" as the precursor to an already-decided
  destructive rollback, never as a routine precaution.

**Where the incident's plan step actually came from**: grepping every plan under `specs/*/plans/`
for `git-snapshot.sh` turns up exactly two hits, and one is the smoking gun:
`specs/186_fix_deploy_headless_path_in_regeneration_doc/plans/01_fix-deploy-headless-invocation-path.md:191`:
```
- [x] Snapshot the working tree before any edits: `bash .claude/scripts/git-snapshot.sh 186`.
      *(completed: git-snapshot.sh's default mode reverted and stashed the tree as
      `git-snapshot-1788908157` (stash@{0}). This also stashed pre-existing, task-unrelated
      uncommitted changes that were present before this dispatch began; those were popped back
      cleanly immediately after with no conflicts and are present in the tree again -- see...)*
```
This is the exact incident the dispatch describes (same stash name, `git-snapshot-1788908157`,
appears in the dispatch's "OBSERVED LIVE" list). Grepping `planner-agent.md`,
`plan-format.md`, and `plan-format-enforcement.md` for any "snapshot"/"git-snapshot" guidance
returns nothing relevant — the plan template's `## Rollback/Contingency` section (planner-agent.md
lines 340-343) is a free-text placeholder with no boilerplate mentioning `git-snapshot.sh`, and
no MUST/MUST NOT bullet in planner-agent.md's Critical Requirements (lines 481-509) addresses it
either. **Conclusion: there is no template bug to fix — the plan-writing pass invented "snapshot
before any edits" as an ad hoc safety habit, generalizing from `git-workflow.md`'s "no
destructive git without a snapshot first" rule and `recovery.md`'s rung (c) without registering
that those both presuppose an imminent destructive op, not a routine start-of-phase
precaution.** The audit finding is therefore: add an explicit guardrail bullet rather than hunt
for a broken template.

**`file_scope` field (`context/reference/state-management-schema.md` lines 260-274)**:
- Optional, default `[]`; prospective ("anticipated ... paths or directory-prefixes"), not
  filesystem-validated; state.json-only (no TODO.md rendering).
- Live data check against `specs/state.json`: 60 of 67 active tasks have a non-empty
  `file_scope` (about 90%), so it is a workable signal in practice, but a guard MUST have a
  defined, non-silent behavior for the remaining ~10% with none declared — task 191 itself does
  not have one set (confirmed: no `file_scope` key on this task's entry in `state.json`).
- Entries are **not all bare file paths**. A scan of every `file_scope[]` value across
  `state.json` found entries in three shapes: exact file paths (e.g.
  `agent-system/extensions/core/commands/orchestrate.md`), directory prefixes with a trailing
  slash (e.g. `agent-system/extensions/core/scripts/tests/`), and shell-glob patterns (e.g.
  `agent-system/extensions/*/agents/**`, `agent-system/extensions/lean/**`). A scope-comparison
  guard needs prefix and glob matching (bash `[[ "$path" == $pattern ]]` handles all three shapes
  uniformly, since `**` behaves as `*` under plain pattern matching — no `globstar` dependency
  needed since this is string pattern matching, not filesystem traversal), not exact string
  equality.
- Distinct from (and never reconciled with) `modified_files`/`files_touched`, which are
  retrospective/self-reported post-hoc. `file_scope` is the only prospective field available at
  snapshot time, which is why the dispatch names it as the comparison oracle — but it also means
  a legitimate task can touch a file its own `file_scope` never anticipated (new test file,
  generated doc, etc.), so an out-of-scope hit is evidence to *surface*, not infallible proof of
  contamination. This favors "refuse and name the paths" (an operator/agent judgment call) over
  a hard block with no override, matching the dispatch's own "(or require an explicit override
  flag)" phrasing.

**Stash accumulation / identity (`agent-system/extensions/core/scripts/git-snapshot.sh` lines
294, 296, 326)**: the only two `git stash create`/`store`/`push` call sites in the whole
`agent-system/extensions/core/scripts/` tree are inside `git-snapshot.sh` itself — it is the sole
producer of these stash entries, so a message-format change is fully self-contained. The current
message is `"git-snapshot-${TS}"` — a bare timestamp, with **no task association at all**. Given
`TASK_DIR` (already resolved by `resolve_task_dir()` before this point), the owning task number
is trivially recoverable from `basename "$TASK_DIR"`'s leading digits, so the message can become
`git-snapshot-{task}-{ts}` (or similar) with no new inputs. `guard-destructive-git.sh` (the only
other consumer in this area) never parses the stash message — it only checks
`.git-snapshot-marker` file existence and a 120-second freshness window (confirmed at
`agent-system/extensions/core/hooks/guard-destructive-git.sh` line 237 and the marker-contract
comment block atop `git-snapshot.sh`) — so this message change is safe and has no other
consumer to update.

**Test convention to reuse**: `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh`
is the closest sibling precedent — it drives a *different* script under test
(`guard-destructive-git.sh`) as a real subprocess inside a freshly created, genuinely dirty git
fixture repo (`make_dirty_repo()`/`make_clean_repo()` helpers), asserts on exit codes, and
follows the documented `pass()/fail()/info()` + `PASSED`/`FAILED` counter convention from
`context/standards/shell-script-testing.md`. Per that doc's location rule, a new narrow,
single-script suite for `git-snapshot.sh` belongs at
`agent-system/extensions/core/scripts/tests/test-git-snapshot.sh`, is auto-discovered by
`scripts/tests/run-all.sh`'s glob-based suite discovery (`test-*.sh` under both
`scripts/tests/` and flat `scripts/`) with no manual registration step, and should build its own
temp git fixture (a task dir with a `state.json`-style `file_scope`, plus tracked files both
inside and outside that scope, dirtied) exactly the way `make_dirty_repo()` does for the sibling
hook test.

### External Resources

Not applicable — this is a pure internal shell-scripting/agent-contract fix; no external
library or API is involved. `git stash create`/`git stash store` semantics were confirmed
directly from the existing, already-correct `--no-revert` implementation and its inline
comments rather than external docs.

### Recommendations

1. **Runtime guard in `git-snapshot.sh` (primary defense)**: in default mode (and arguably
   `--branch` mode too, since the dispatch's own header already documents that `--branch`
   "does NOT avoid the revert" — the implementer should decide whether to extend the guard to
   both or scope it to default mode only per the dispatch's literal wording), before reverting
   anything:
   - Resolve the task's `project_number` from `TASK_DIR`'s basename.
   - Read `file_scope` for that project from `specs/state.json` via `jq` (already a hard
     dependency on the inference path).
   - Compute `git status --porcelain` paths (already computed for the clean-tree check at line
     233) and classify each tracked, dirty path as in-scope or out-of-scope using
     prefix/glob matching against `file_scope`.
   - If any out-of-scope tracked path exists: refuse by default (exit non-zero, name every
     offending path on stderr, do NOT stash/revert anything), unless an explicit override flag
     (e.g. `--force` or `--allow-out-of-scope`) is passed. This must be a *new* flag, layered
     independently of the existing three-mode selector — it must not be confusable with
     `--no-revert`, which solves a different problem (durable-without-reverting) and stays
     untouched.
   - Explicit, non-silent fallback needed for tasks with empty/absent `file_scope` (~10% of
     current tasks, including task 191 itself) — the dispatch's acceptance criterion is about a
     tree that *has* declared scope, so the implementer should decide and document the
     no-scope-declared behavior (options include: warn-and-proceed, treat "no scope" as "no
     restriction," or require the override flag unconditionally) rather than leaving it
     implicit.
   - Untracked files are already handled separately from this concern (they are always fully
     swept by `-u` in default mode) — the dispatch's incident and acceptance criterion are both
     specifically about *tracked* modifications, so the guard's scope can stay tracked-only
     unless the implementer finds a reason to extend it.

2. **Planner guidance (secondary defense)**: add a `MUST NOT` bullet to `planner-agent.md`'s
   Critical Requirements (after item 10, line ~509) forbidding emission of a bare
   `git-snapshot.sh` call (without `--no-revert`) as a routine start-of-phase/precautionary
   step — reverting default mode is only for `recovery.md` rung (c)'s genuine-rollback scenario,
   never a generic "snapshot before any edits" habit. This directly targets the mechanism that
   produced the task-186 plan step and prevents recurrence at the source, independent of the
   script-level guard.

3. **Stash identity (in-scope secondary item)**: change the two message strings in
   `git-snapshot.sh` (`git stash create "git-snapshot-${TS}"` at line 294 and
   `git stash push -u -m "git-snapshot-${TS}"` at line 326, plus the matching `store -m` at line
   296) to embed the resolved task number, e.g. `git-snapshot-{task}-{ts}`. This is additive-only
   (no existing consumer parses the message), gives every future `git stash list` entry enough
   identity to judge safety of removal by task, and does **not** implement or invoke any reaper
   — no `git stash drop`/`clear` is touched, per the dispatch's MUST NOT.

4. **Fixture test**: new `agent-system/extensions/core/scripts/tests/test-git-snapshot.sh`
   modeled on `test-guard-destructive-git.sh`'s dirty-fixture-repo pattern — build a temp repo
   with a `specs/{NNN}_x/` task dir and a minimal `state.json` declaring `file_scope`, commit and
   then dirty both an in-scope and an out-of-scope tracked file, run `git-snapshot.sh` in default
   mode, and assert it refuses (non-zero exit, tree still dirty with the out-of-scope file
   intact) rather than stashing. This is the acceptance criterion's required fixture and should
   fail against the current (pre-fix) script by construction.

## Decisions

- Treat the script-level runtime guard as the primary fix and the planner-agent.md bullet as a
  secondary, cheap, source-of-recurrence fix — matching the dispatch's own stated preference
  ("Prefer a runtime guard... over documentation alone... Also audit how planners emit this
  step").
- Do not touch `--no-revert`, `guard-destructive-git.sh`'s marker contract, or any existing
  correct caller (`general-implementation-agent.md`, `general-research-agent.md`,
  `recovery.md`) — all three are already correct and out of scope.
- Do not implement a stash reaper; only strengthen the identity embedded in future stash
  messages, per the dispatch's explicit "a reaper is optional and may be split out."

## Risks & Mitigations

- **Risk**: an out-of-scope refusal blocks a legitimate task whose `file_scope` simply didn't
  anticipate every file it will touch (e.g. a new test file). **Mitigation**: refuse-with-named-
  paths-and-override-flag (as the dispatch itself suggests), not a hard, un-overridable block;
  the override is a deliberate, visible choice rather than a silent default.
- **Risk**: tasks with no `file_scope` declared (~10%) get no protection from the new guard.
  **Mitigation**: this must be a documented, deliberate decision by whoever implements the
  guard (see Recommendation 1's fallback bullet), not an accidental gap — flag it explicitly in
  the plan.
- **Risk**: extending the guard to `--branch` mode as well as default mode is not explicitly
  required by the dispatch's literal wording ("in default mode") but the same hazard is
  documented for `--branch` in the script's own header. **Mitigation**: the plan should make an
  explicit, reasoned choice on this rather than address only the literal word "default" while
  leaving `--branch` silently as hazardous as before.

## Context Extension Recommendations

- **Topic**: safe vs. unsafe `git-snapshot.sh` usage patterns for plan authors.
- **Gap**: `planner-agent.md` and `plan-format.md` currently say nothing about when a plan step
  may or may not invoke `git-snapshot.sh` in its reverting modes; the only correct guidance lives
  in `recovery.md` (aimed at implementation-time rollback decisions, not plan authoring) and in
  the two agent files that already call it correctly for the overflow-checkpoint case.
- **Recommendation**: the `MUST NOT` bullet recommended above in `planner-agent.md` is the
  minimal fix; a longer-term option is a one-paragraph cross-reference from `plan-format.md`'s
  `## Rollback/Contingency` template section to `recovery.md`'s rung (c), so a future plan author
  reaches the correct mode distinction without having to already know `recovery.md` exists.

## Appendix

- Search queries / commands used: `grep -rn "git-snapshot" agent-system/extensions/core`,
  `grep -rln "git-snapshot.sh" specs/*/plans/*.md`, `jq` queries against `specs/state.json` for
  `file_scope` population rate and shape, `grep -rn "git stash push\|git stash create\|git stash
  store"` across `agent-system/extensions/core/scripts/*.sh` and `hooks/*.sh`.
- Key files read in full or in relevant part: `agent-system/extensions/core/scripts/git-snapshot.sh`,
  `agent-system/extensions/core/agents/planner-agent.md`,
  `agent-system/extensions/core/agents/general-implementation-agent.md`,
  `agent-system/extensions/core/agents/general-research-agent.md`,
  `agent-system/extensions/core/context/contracts/recovery.md`,
  `agent-system/extensions/core/context/reference/state-management-schema.md`,
  `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh`,
  `agent-system/extensions/core/context/standards/shell-script-testing.md`,
  `specs/186_fix_deploy_headless_path_in_regeneration_doc/plans/01_fix-deploy-headless-invocation-path.md`.
