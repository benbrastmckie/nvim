# Roadmap

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`. Task
detail lives in `specs/TODO.md`; this file carries only ordering, gates and rulings. Measured
2026-10-05.*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's.

`MAX_TASKS` is 8, enforced in `commands/orchestrate.md`. `orchestrate-cycle-plan.sh` itself accepts
any count, so a dry-run over more than 8 is not evidence a call will run them.

**35 open tasks**: 21 ready, 13 blocked, 1 held. If that stops matching `state.json`, this file has
drifted — it is hand-derived until **306** makes it generated.

## Gate state

- **Deploy gates are GREEN**: `verify-deploy.sh --skip-slow` returns **PASS — 33 checks, 0
  failures** (measured 2026-10-05). The three standing reds recorded in earlier passes — the two
  books-scaffold defects and the orchestrator context-budget overage — are resolved. The redeploy
  checkpoint that cleared them resynced 7 extensions and dropped findings from 15 to 1, 0 newly
  introduced; the surviving manifest finding tracks an uncommitted source-store modification to
  `scripts/orchestrate-cycle-plan.sh` from a concurrent session, not a deploy fault.
- **`validate-state.sh --deep`**: 16 passed, 0 failed, 6 warnings. All six are `file_scope`: 300's
  coarse `scripts/tests/` (13 overlaps), 328's missing key, the visibility summary line reporting
  it, and three glob-shaped entries on 342 that collision detection cannot see. Treat any *new*
  warning, and any failure, as real.
- **Gate 8 (`tests/run-all.sh`) is not reliably runnable inside a dispatch.** It spans every
  extension (111+ suites observed in one invocation, 89 `test-*.sh` in core alone), and its
  recorded 117.9 s is a *parallel* figure — `verify-deploy.sh` requests `--jobs` (cap 4) while
  run-all.sh defaults to `--jobs 1`. A bare sequential run reached ~53 results in ~330 s without
  concluding. A 2026-10-05 dispatch could not finish it and closed the phase with a documented
  Reasoned Exclusion. **A gate that cannot conclude inside a dispatch budget stops being a gate and
  becomes a line in an exclusions table.** Owned by **170** (flakiness, host coupling) and **328**
  (runtime).
- **Consumer repos were all 8 STALE at last measurement (2026-10-03).** If work touches a consumer,
  run `check-consumer-freshness.sh` here and `deploy-headless.sh` **there** first; this repo never
  pushes into a consumer.

## Next

Nothing is in flight. Recommended order, by harm-now × actionable-now:

```
/orchestrate 325, 322      # /todo is broken in two independent ways; both small, same workflow
/orchestrate 337           # handoff validation fails and is swallowed — masks every other signal
/orchestrate 343           # bounded wait + stranded-dispatch detection
```

Then the unblocking plays, highest leverage first: **284** (frees 335 and feeds 304), **251**
(frees 170, which frees 328), **318** and **271**.

Scheduling constraints that bite:
- **337 and 343 must not share a batch** — both declare `orchestrate-cycle-postflight.sh`.
- **343 overlaps seven non-terminal tasks** on its four files; `orchestrate-batch-admit.sh` will
  raise a `cross_batch` advisory. Dispatch it alone or with tasks touching none of them.
- **300's `scripts/tests/` declaration overlaps 13 tasks.** Narrow it before co-scheduling.

## Open work

One line per task; detail in `TODO.md`. `blocked:N` means N is the open blocker.

**Orchestrator (14)**
```
271 ready            parent_task edge: schema, validation, TODO rendering
272 ready            honest session liveness for concurrent same-repo batches
299 ready            detect in-place plan revision concurrent with a live implement dispatch
311 ready            measured co-scheduling signal replacing static build-heavy family membership
319 ready            surface cross-task claim invalidation when research refutes a filed premise
337 ready            handoff required fields, and a dropped validation failure
343 ready            bound an agent's background wait; detect a stranded dispatch
273 blocked:271      three-channel conclusion stage with per-channel approval
275 blocked:272      per-repo orchestration queue, consumed by admission
302 blocked:300      pass --task at commit-staging sites to engage the contended-path lease
303 blocked:271      validate-state.sh default must resolve against the repo, not CWD
274 blocked:272,273,275   next-admissible-batch suggestion and alternatives-on-conflict
312 blocked:300,282  backlog reconciliation as a required task-creation component
304 blocked:273,284,302   one out-of-repo pathspec aborts staging; callers sink nonzero exits
```

**Core agent system (16)**
```
251 ready            context-corpus reachability probe, then act on dead and overlapping files
280 ready            forbid record-versioning language: rule, exemptions, pattern library
284 ready            exempt a task's own directory from the file_scope excursion advisory
300 ready            AskUserQuestion unreachable in dispatched subagents
306 ready            make ROADMAP.md a generated artifact
318 ready            wire lint-directory-pathspec-boundary.sh in as a numbered gate
322 ready            /todo: moved directory's vacated source never staged (verified regression)
325 ready            git add's gitignore advisory exit code aborts the whole commit
336 ready            in-dispatch phase-commit staging: 15 agents, no file_scope check, no lease
338 ready            sweep task support files: tracked or ignored
170 blocked:251      isolate shell test suites from ambient host state (memory, timing)
281 blocked:280      repo-wide record-versioning lint, blocking/advisory split
335 blocked:284      promote the file_scope excursion advisory into a staging-time gate
282 blocked:280,281  write-time PreToolUse hook blocking record-versioning language
313 blocked:306,328  advisory lint for hand-authored batch proposals in ROADMAP phase blocks
328 blocked:170,318,322,304,303   systematic script and test corpus efficiency
```

**Neovim (3)**
```
22  ready            freeze .opencode: silence fragment validation spam, record the policy
295 ready            add desc to 44 keymap.set calls
296 ready            repo hygiene: stale init.lua.backup, project-overview.md, README link
```

**Extensions (2)**
```
29  blocked:22       generate .mcp.json from extension manifests; register obsidian-memory
342 HOLD             books context corpus refactor — see below
```

**342's hold**: the dependency half is met (340 and 341 completed 2026-10-05). The only remaining
condition is the version stamp — 340 measured the consuming repository's Decision 19 at
`0.1.0-pre` (`d255518`); lift when that line reads `0.1.0`. Operator action, not an agent's.

## Checks before and after every call

- `orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>` — **space-separated**.
  Admits what you expect; `md5sum specs/state.json` unchanged. Research and plan dispatches are
  exempt from the self-modifying defer, so overlap only serializes at implement time.
- `validate-state.sh --deep` — compare against the 6 known warnings above.
- `tests/run-all.sh` — read the end-of-run failure roster and the `EXPECTED`/`NEW` split, not the
  tally; read the exit code directly, never through `tail`/`head`. A NEW failure is yours; an
  EXPECTED one is in `known-failures.txt` with a reason. `--fail-on-new` makes it a gate. Pass
  `--jobs 4` or expect the 4-5x sequential cost.
- `verify-deploy.sh --skip-slow` — measure *before* your work as well as after, and compare. Do not
  read a standing red as permission to ignore a new one. A self-modifying task is not finished until
  `.claude/` is resynced, and a resync whose verify is red is reported, not silently accepted.
- A completion postflight refused with **exit 6** needs no action: the Inter-Cycle Redeploy
  Checkpoint promotes the task on the next cycle. For the genuinely stuck case,
  `reconcile-task-status.sh <N> <session>`.

## Settled decisions (do not re-litigate)

1. **Batch of one.** One engine; single-task is a batch of one. Team mode is deleted. Hard mode is
   kept in full, per-invocation.
2. **The orchestrator never asks and never decides.** Only an agent-surfaced `user_decision` reaches
   the user, once, at cycle end. A `blocking: false` decision proceeds on the agent's recommendation
   and is surfaced, not prompted.
3. **Research-first is the default** for a fresh task; `--fast` restores planner-first.
4. **`--dry-run` prints the plan it would dispatch.** There is no separate dry-run report.
5. **No fixed consumer validation gates.** The checks above are recommended, not blocking.
6. **A linear chain of small tasks serializing on one file is one task with phases.** Apply at
   creation time.
7. **`file_scope` warnings are live input, not noise.** In-batch collisions block; cross-batch ones
   are advisory.
8. **Rule before mechanism** for the vimtex hazard. Re-file a mechanism task only if the rule proves
   insufficient.
9. **Skeleton plans terminate through the completion-claim gate.** No `pr_ready` routing outside
   `type=pr`.
10. **No third automated deploy-trigger site.** The sanctioned count stays at exactly two.
11. **One grant mechanism.** A push or other blocked git action is authorized by one single-use token
    bound to action, remote, branch and sha, minted only where the harness can prove the user typed
    it. Nothing the model can write is a grant. PR/MR creation and `/merge` stay user-only.
12. **A grant may authorize a plain push of the default branch** (user ruling). Every force form on
    the default branch, bare `--force` anywhere, and all bulk or deletion refspecs stay categorically
    excluded, checked before any grant lookup.
13. **`known-failures.txt` is the only known-failing list.** Advisory by construction; it never
    changes which suites run. Never keep a prose copy elsewhere — that is the drift mechanism.
14. **One shared working tree, always.** Per-dispatch `git worktree` isolation is removed, not
    narrowed. Concurrency safety rests on declared `file_scope`, dependency edges and the five
    contention inputs. Build contention is closed by refusing to co-schedule two build-heavy
    implement tasks in one cycle. Cost was not the reason for removal and must not be cited as it.
    Record: `specs/decisions/worktree-isolation-removal-verdict.md`.
15. **Gate 8's deployed-tree coverage is knowingly reduced** (accepted on wall-clock grounds). The
    redeploy checkpoint runs `--skip-slow`, so the ~40 core suites resolving their subject from the
    *deployed* tree are not verified against a fresh deploy. The narrower fix is in **328**'s scope.
16. **A systemic cost is filed as one standing task against a probe's output, not a stream of point
    defects.** Duplication, dead code and slow tests never break anything, so defect-driven intake
    cannot see them. 328 is the standing consumer of `script-inventory.sh`; 307, 308 and 270 were
    abandoned into it.

## Standing rules

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on reload.
2. **`.claude/**` is a deploy artifact.** Edit the source store under `agent-system/extensions/**`.
3. **`TODO.md` is generated from `state.json`.** Edit the `description` field via `state-write.sh`,
   then `generate-todo.sh`. A hand edit to `TODO.md` is wiped by the next regeneration — observed
   2026-10-05, losing three task revisions.
4. **Propose, then apply, across repos.**
5. **Verify by execution, not by reading.** Every number here was measured the day it was written;
   re-measure before acting on it.
6. **The lead never reads a report, plan, summary, description or context file during the loop.**
7. **This file describes the current plan only.** No revision history, no pass numbers.

## Unfiled observations (none worth a task yet)

- **Dependency edges can point at vaulted task numbers and silently freeze work.** 14 edges across
  12 tasks referenced numbers absent from `state.json` and `CHANGE_LOG.md`; all 14 were `completed`
  in `specs/vault/01-vault/state.json`, left behind by the 2026-08-10 vault reset. Cleared
  2026-10-05, which moved 4 tasks from blocked to ready. No mechanism prevents recurrence at the
  next vault operation, and `validate-state.sh` does not check it.
- **A rendered `**Goal**:` line in `TODO.md` cannot survive regeneration and fails validation while
  present.** `generate-task-order.sh --goal` writes it; `generate-todo.sh` drops it and never reads
  `active_goal` from `state.json`. So `active_goal` is write-only and the displayed goal is
  permanently blank. Belongs with **306**.
- **The probe's `inbound_callers` field cannot find dead code** — a script's own `manifest.json`
  entry counts as a caller of its basename, so it reports zero zero-caller scripts across 197 files.
  `has_test` is a filename-convention check and under-reports coverage. Both recorded inside **328**
  so they are not mistaken for answers.
- `plan-file-scope-harvest.sh` parses a `**Files to modify**:` field and finds nothing in a plan
  using a Territory Contract table instead. At least one BimodalLogic plan is invisible to it.
- The write-time task-reference hook fires on files in the session scratchpad; its path filter could
  exempt `/tmp/**`.
- The in-scope agent set for a contract rolled across implementation agents is **14** files, not the
  13 a sweep by directory suggests — `founder-implement-agent.md` also edits phase-heading markers.
