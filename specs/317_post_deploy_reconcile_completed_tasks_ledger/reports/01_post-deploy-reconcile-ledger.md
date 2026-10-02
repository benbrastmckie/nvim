# Research Report: Task #317

**Task**: 317 - Post-deploy reconcile promotion must append to the batch's `completed_tasks` ledger
**Started**: 2026-10-02T00:00:00Z
**Completed**: 2026-10-02T00:00:00Z
**Effort**: Standard (single-session research, no `--hard`)
**Dependencies**: None blocking; overlaps task 265 (implement, same `orchestrate-cycle-plan.sh` /
`test-orchestrate-cycle-plan.sh` file scope) — per this task's own dispatch, do not run concurrently.
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`,
`reconcile-task-status.sh`, `update-task-status.sh`, `orchestrate-cycle-postflight.sh`,
`git-commit-scoped.sh`), `context/standards/git-staging-scope.md`,
`docs/architecture/orchestrate-state-machine.md`, `skills/skill-orchestrate/SKILL.md`,
`scripts/tests/test-orchestrate-cycle-plan.sh` (Group 29), `scripts/tests/test-orchestrate-cycle-postflight.sh`.
**Artifacts**: This report.
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- **Confirmed write site**: the post-deploy reconcile promotion loop in
  `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1132-1148` already detects a
  `promoted ... -> completed` outcome (via a stdout grep on `reconcile-task-status.sh`'s output,
  used to log `_pdr_outcome` and append to `post_deploy_reconcile_notices`) but never reflects
  that outcome into `.completed_tasks` on the multi-state file. This is the sole defect behind
  consequence 1 (under-reported `### Succeeded` table and skipped `.dispatch/` cleanup).
- **Recommendation for consequence 1**: option **(a)** — append the promoted task number to
  `.completed_tasks` at this exact site, reusing the already-computed `_pdr_outcome == "promoted"`
  condition and the same `(... + [$t] | unique)` idiom `orchestrate-cycle-postflight.sh:1427`
  already uses for the ordinary per-task completion path. Option (b) (make Move 4 derive
  `### Succeeded` from authoritative per-task status instead of the accumulator) is rejected: the
  accumulator model is sound everywhere else in the codebase (postflight already writes it
  correctly for every ordinary dispatch); only this one site forgot to. Widening the reporting
  contract to make the accumulator "advisory" trades a one-line fix for a cross-cutting
  re-architecture of a mechanism that works.
- **Recommendation for consequence 2**: the promotion loop must issue its own scoped commit
  (via `git-commit-scoped.sh`, explicit two-file pathspec: `specs/state.json` and
  `specs/TODO.md`) immediately inside the existing post-deploy-reconcile loop, right after
  `_pdr_outcome="promoted"` is determined. This is the *only* point before a possible
  `stop_reason="all_terminal"` exit (`orchestrate-cycle-plan.sh:1511-1514`, which runs in the very
  same invocation, after `current_statuses` is refreshed from the just-promoted state) — if the
  commit is not made here, there is no other code path that will ever make it. The alternative
  floated in the dispatch — have the engine refuse to stop on `all_terminal` while an uncommitted
  promotion is outstanding — is rejected: it would require a new, generic "is my promotion still
  uncommitted" signal built on working-tree dirtiness, which is actively unsafe in this script's
  own stated operating envelope (concurrent sibling tasks writing to the *same* shared working
  tree in the same batch cycle — see this task's own Territory block). A targeted, explicit-file
  commit made at the point of mutation needs no such signal and cannot be confused with a
  sibling's concurrent, unrelated dirtiness.
- Both fixes land entirely inside the already-serialized "one point in the whole cycle with no
  dispatch in flight" window the post-deploy reconcile pass's own header comment already
  documents — no new concurrency control is needed for either.
- A regression harness (`scripts/tests/test-orchestrate-cycle-plan.sh` Group 29) already drives
  exactly this promotion scenario end-to-end with the REAL `reconcile-task-status.sh` and a
  synthetic deploy-pending fixture (Arm A, `scripts/tests/test-orchestrate-cycle-plan.sh:4178-4201`).
  It currently asserts the promoted status and the stderr "promoted" line but has **zero**
  assertion on `.completed_tasks` and **zero** git/commit involvement at all (`WORKDIR` is not
  even a git repo in this suite today). Both gaps must be closed by the implementation phase;
  see Recommendations for the concrete extension plan, including the real-`git-commit-scoped.sh`
  + `git init` pattern `test-orchestrate-cycle-postflight.sh` already established for an
  equivalent commit assertion.

## Context & Scope

The dispatch (`.dispatch/21.md`) reports a live run (`sess_1790947016_5ff368`) in which a 5-task
batch completed all five tasks in `specs/state.json`, but the batch's own
`.return-meta-multi-*.json` / consolidated output only listed 3 of them as `completed_tasks`
(`[277, 294, 314]`, missing `309` and `315`), because those two reached `completed` via the
post-deploy reconcile path rather than ordinary per-task postflight. The same run also left the
two promotions' `state.json`/`TODO.md` changes uncommitted — the last git commit for each task
read "orchestration paused (cycle 4)", actively misstating the final outcome.

Scope of this research: confirm the exact write site, rule on consequence-1 remedy (a) vs (b),
rule on consequence-2 remedy (own commit vs. refuse-to-stop), and identify the test-suite changes
needed to close both gaps with a non-vacuous RED-then-GREEN regression case. This is explicitly
**not** the `.status`/`.persisted_status` divergence fix (already shipped) — that made a single
postflight's self-report honest; this task is about a promotion that bypasses postflight (and its
commit) entirely.

## Findings

### Codebase Patterns

**The promotion loop (confirmed write site)** —
`agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1132-1148`:

```bash
if [ "$dry_run" != "true" ] && [ "$post_deploy_reconcile_json" != "[]" ]; then
  for _pdr_t in $(echo "$post_deploy_reconcile_json" | jq -r '.[]' 2>/dev/null || true); do
    [ -n "$_pdr_t" ] || continue
    _pdr_rc=0
    _pdr_out="$(bash "$SCRIPT_DIR/reconcile-task-status.sh" "$_pdr_t" "$session_id" 2>&1)" || _pdr_rc=$?
    if [ "$_pdr_rc" -ne 0 ]; then
      _pdr_outcome="refused"
    elif printf '%s' "$_pdr_out" | grep -q "promoted .* -> completed"; then
      _pdr_outcome="promoted"
    else
      _pdr_outcome="no-op"
    fi
    echo "[orchestrate] REDEPLOY CHECKPOINT: post-deploy reconcile for task #${_pdr_t} — ${_pdr_outcome}" >&2
    mt_set --argjson entry "$(jq -n -c ... '{cycle:$c, task:$t, outcome:$o, exit_code:$rc}')" \
      '.post_deploy_reconcile_notices += [$entry]'
  done
  mt_save
fi
```

The `grep -q "promoted .* -> completed"` test is already precise: `reconcile-task-status.sh` emits
`"promoted $from -> $to"` lines for four phase transitions
(`researching -> researched` line 544, `planning -> planned` line 583,
`implementing -> completed` line 626, `partial -> completed` line 673), and only the latter two
end in `-> completed`. The existing regex therefore already isolates exactly the condition that
matters for `.completed_tasks` — no new detection logic is needed, only a new *action* taken on
the condition that already exists.

**The established `.completed_tasks` write idiom** — `orchestrate-cycle-postflight.sh:1427`
(WORK (j), the ordinary per-task postflight path):

```bash
if [ "$fresh_status" = "completed" ]; then
  jq --argjson t "$task_number" '.completed_tasks = ((.completed_tasks // []) + [$t] | unique)' \
    "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
fi
```

`orchestrate-cycle-plan.sh` already has its own in-memory equivalent of this read-modify-write
idiom via `mt_set`/`mt_save` (defined at lines 604-628, used throughout the file, including
immediately adjacent to the promotion loop for `post_deploy_reconcile_notices`). `.completed_tasks`
is already defaulted to `[]` at initial mt_json construction (line 542: `.completed_tasks //= []`),
so appending via `mt_set` needs no additional guard.

**Consumers of `.completed_tasks` (confirms consequence 1 end-to-end)** —
`docs/architecture/orchestrate-state-machine.md:1061` and `:1073` document that Move 4:
1. Reads `completed_tasks` (among other fields) from `mt_state_file` to compute the consolidated
   output / `.return-meta-multi-*.json`'s `tasks_completed`.
2. "For every task in `completed_tasks` only (never `failed_tasks`, never a still-non-terminal
   task...) removes that task's accumulated `.dispatch/` directory." — so the same defect that
   under-reports the `### Succeeded` table *also* silently leaves stale `.dispatch/` directories
   behind for every reconcile-promoted task. This is a derivative effect of the same root cause,
   not a third defect requiring its own fix — fixing the ledger write fixes both.
`skill-orchestrate/SKILL.md`'s Move 4 section independently corroborates both consumers
(lines 275-282).

**Why consequence 2 exists** — tracing the deploy-pending lifecycle:
1. When a task's `implemented` postflight is gated by the completion-deploy gate (exit 6),
   `orchestrate-cycle-postflight.sh:1008-1014` sets `deploy_pending_refusal=true` and explicitly
   does **not** write `status: completed` to `state.json` (stays at its in-flight status, e.g.
   `implementing`). The task's commit message for that cycle is
   `"task ${task_number}: orchestration paused (cycle ${cycle_count})"`
   (`orchestrate-cycle-postflight.sh:1365`), and that commit's `stage_paths` already include the
   task directory, `TODO.md`, and `state.json` (`orchestrate-cycle-postflight.sh:1341-1342`) — so
   the task's actual deliverable (e.g. its summary file) is already committed at this point, under
   a status of "paused", not "completed".
2. Later, inside the *same or a later* `/orchestrate` invocation, the Inter-Cycle Redeploy
   Checkpoint deploys successfully and runs the post-deploy reconcile pass. For a task at
   `implementing`/`partial` with a complete summary artifact, `reconcile-task-status.sh` calls
   `update-task-status.sh postflight ... implement` (lines 613-626 / 663-673), which writes
   `state.json` to `status: completed` and regenerates `TODO.md`
   (`update-task-status.sh:347, 176-182`) — **and nothing else**. Grep confirms
   `reconcile-task-status.sh` never calls `git-commit-scoped.sh` or any git command at all
   (only one comment references it, at line 279, about an unrelated exit-code-capture idiom
   borrowed from it).
3. Immediately after the reconcile loop, `orchestrate-cycle-plan.sh`'s own Status refresh
   ((a), after line 1148) re-reads `current_statuses[$t]` fresh from `state.json` — now
   `"completed"` — and the All-terminal check ((b), `orchestrate-cycle-plan.sh:1502-1514`) can
   immediately call `emit_and_exit` with `stop_reason="all_terminal"` if every task is now
   terminal. This is a same-invocation code path with **no intervening dispatch and no intervening
   postflight** — so no per-task commit is ever issued for the `completed` transition. The
   uncommitted `state.json`/`TODO.md` change is therefore real and matches the dispatch's observed
   evidence exactly (git log showing "orchestration paused (cycle 4)" as the last commit for both
   tasks, despite `state.json` reading `completed`).
4. Move 4's own residue check (`git status --porcelain -- specs/` — SKILL.md line 285-286) is
   explicitly "warn only, never commits" — it cannot close this gap on its own; it can only report
   it after the fact.

**File scope of the fix**: all three files a successful `implementing -> completed` or
`partial -> completed` promotion touches are `specs/state.json` and `specs/TODO.md` only — no
task-directory file is newly created or modified by `reconcile-task-status.sh`'s promotion branch
(the artifact it links, e.g. a summary file, already exists on disk and was already committed by
the earlier "orchestration paused" commit in step 1 above). The `link_artifact` helper
(`reconcile-task-status.sh:160-208`) writes only to `state.json` (via `state-write.sh`) and
regenerates `TODO.md` — it never touches the task directory itself.

### External Resources

Not applicable — this is a pure in-repo orchestration-engine defect; no external documentation
was consulted.

### Test Coverage (current state)

`scripts/tests/test-orchestrate-cycle-plan.sh` Group 29 ("deploy_pending vs identical-dispatch
guard composition", lines ~4040-4320+) already builds exactly the scenario this task is about:
`g29_write_task_fixture` creates an `implementing` candidate with a completed plan, a summary
artifact, and a `.orchestrator-handoff.json` reporting `implemented`; `g29_seed_state_and_mt`
seeds `state.json` + the multi-state file with `deploy_pending: true`; the REAL
`reconcile-task-status.sh` (and its real dependency chain: `state-write.sh`, `generate-todo.sh`,
`update-task-status.sh`, `lib/status-vocabulary.sh`) is installed starting at this group. Arm A
(lines 4178-4201) runs the SUT and asserts:
- the stderr line `post-deploy reconcile for task #9201 ... promoted` appears;
- `state.json`'s status becomes `completed`;
- zero `implement` dispatch rows are emitted;
- `deploy_pending` is cleared from `.return-meta.json`.

**Gaps confirmed by direct grep** (both return empty today):
- No assertion anywhere in this file reads `.completed_tasks` from the multi-state file.
- No reference anywhere in this file to `git-commit-scoped.sh`, `git init`, `git log`, or
  `git rev-parse` — `$WORKDIR` in this suite is not a git repository at all today (only a
  *separate*, throwaway `$G29_SRC_REPO` used purely for the deploy-ledger's hash-scope root is
  git-initialized).

This means Arm A's fixture is reusable almost as-is for the new regression case, but the harness
itself needs two additions: (1) a `.completed_tasks` assertion after Arm A's existing assertions,
and (2) making `$WORKDIR` a real git repo with the real `git-commit-scoped.sh` installed, so a
before/after `git rev-parse HEAD` (or `git log -1 --format=%s`) assertion can prove a commit was
actually made. `scripts/tests/test-orchestrate-cycle-postflight.sh` already establishes the exact
pattern needed for this: it `git init -q`'s `$WORKDIR` and a throwaway `$src_repo`, stages an
initial fixture commit, then asserts `before_head`/`after_head` (`git rev-parse HEAD`) differ and
`git log -1 --format=%s` matches the expected commit message, around its own Phase 9
(lines 86-121, 1210-1220, 1952-2064). The same before/after-HEAD pattern — not a stub — is the
right choice here because this task's point is specifically that a *real* commit lands; a stub
that only records "I was called with the right pathspec" would not catch a regression where the
call is made but the underlying commit silently fails.

## Decisions

1. **Consequence 1 fix is option (a)**: append the promoted task number to `.completed_tasks` at
   `orchestrate-cycle-plan.sh`'s existing promotion loop (around line 1140-1144), gated on the
   already-computed `_pdr_outcome == "promoted"` condition, using the same
   `(.completed_tasks // []) + [$t] | unique` idiom `orchestrate-cycle-postflight.sh:1427` uses.
   Option (b) (re-deriving Move 4's `### Succeeded` set from authoritative per-task status) is
   explicitly rejected as unnecessarily wide: it would touch the reporting contract consumed by
   every ordinary (non-reconcile) completion too, for a defect that is scoped to exactly one write
   site that simply forgot to update an otherwise-correct accumulator.
2. **Consequence 2 fix is "promotion issues its own scoped commit"**, not "engine refuses to stop
   on `all_terminal`". The commit is issued inside the same post-deploy-reconcile loop, immediately
   after `_pdr_outcome="promoted"` is determined (same iteration, same already-serialized
   checkpoint window the surrounding comment already documents as "the one point in the whole
   cycle with no dispatch in flight"). It must use `git-commit-scoped.sh` with an **explicit
   two-entry pathspec** (`"$STATE_FILE"` and `"$(dirname "$STATE_FILE")/TODO.md"`) — never a
   directory pathspec — per `context/standards/git-staging-scope.md`'s directory-pathspec rule,
   and should pass `--task "$_pdr_t"` (V5 contended-path refusal) and `--session "$session_id"`,
   mirroring `orchestrate-cycle-postflight.sh:1392`'s own call shape minus the task-directory
   entry (not needed here — see Findings' "File scope of the fix"). A commit message such as
   `"task ${_pdr_t}: complete implementation (post-deploy reconcile)"` keeps the durable git
   record honest about *why* this commit exists, distinct from the ordinary
   `"task {N}: complete implementation"` postflight message.
3. **A failed commit at this site must be non-blocking**, exactly like every other commit-failure
   path already documented in this codebase (`orchestrate-cycle-postflight.sh:1392`'s own
   `|| echo ... WARNING ... non-blocking`): log a `REDEPLOY CHECKPOINT WARNING`, continue the loop
   for remaining tasks. This matches the dispatch's "either remedy must close it, not just report
   it" requirement for the *common* case (commit succeeds, which is the overwhelming majority —
   this is the one serialized point in the cycle with no concurrent dispatch) while not inventing
   a new retry/escalation mechanism for the rare V5 contention case, which the codebase already
   treats as acceptable to defer.
4. **No `user_decision` is warranted** for this task: both remedies are fully determined by the
   codebase's own existing conventions (the postflight accumulator idiom, the scoped-commit
   pathspec rule, the non-blocking-commit-failure convention) — there is no user preference,
   external cost, or genuine ambiguity left for a human to resolve.

## Recommendations

1. In `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`, inside the promotion loop
   at lines 1132-1148, immediately after the `elif printf '%s' "$_pdr_out" | grep -q "promoted .* -> completed"; then _pdr_outcome="promoted"` branch sets `_pdr_outcome="promoted"`:
   - Append `$_pdr_t` to `.completed_tasks` via `mt_set`/`mt_save` (or batch into the existing
     `mt_save` call at the end of the loop — either is fine; batching at the end avoids an extra
     temp-file write per promoted task in a multi-promotion cycle).
   - Issue the scoped commit via `git-commit-scoped.sh` with the explicit `state.json`/`TODO.md`
     pathspec, `--task "$_pdr_t"`, `--session "$session_id"`, and a commit message naming the task
     and the reconcile origin. Treat a non-zero exit as non-blocking (warn via the same
     `REDEPLOY CHECKPOINT WARNING` idiom used elsewhere in this file, e.g. lines 922, 1055).
2. Extend `scripts/tests/test-orchestrate-cycle-plan.sh` Group 29:
   - Make `$WORKDIR` a real git repository (mirroring
     `test-orchestrate-cycle-postflight.sh`'s `git init -q` + initial fixture commit pattern) and
     install the real `scripts/git-commit-scoped.sh` into `$WORKDIR/.claude/scripts/` alongside
     the other Group 29 real collaborators already copied in (`cp "$CORE_DIR/git-commit-scoped.sh" ...`).
   - In Arm A (or a new Arm immediately after it), capture `before_head=$(git -C "$WORKDIR" rev-parse HEAD)`
     before `run_sut`, then after it assert: (i) `jq -r '.completed_tasks' "$mt_state_file"`
     contains `9201`; (ii) `git -C "$WORKDIR" rev-parse HEAD` differs from `before_head`; (iii)
     `git -C "$WORKDIR" status --porcelain -- specs/state.json specs/TODO.md` is empty (nothing
     left uncommitted for those two paths).
   - Run this new case against the **unfixed** source first (confirming RED: `.completed_tasks`
     does not contain `9201` and/or `HEAD` is unchanged) before applying the fix above, per the
     dispatch's "Close By" requirement, then confirm GREEN after.
3. No other file needs changes. `skill-orchestrate/SKILL.md`'s Move 3/Move 4 and
   `docs/architecture/orchestrate-state-machine.md`'s consumer documentation already describe
   `.completed_tasks` correctly — once the accumulator is complete, the existing consumers need no
   change, confirming option (a) over option (b).
4. All edits land under `agent-system/extensions/core/` (`scripts/orchestrate-cycle-plan.sh`,
   `scripts/tests/test-orchestrate-cycle-plan.sh`), per
   `.claude/rules/source-store-deploy-boundary.md` — never under `.claude/**` directly. Both files
   are also listed in task 265's concurrent `file_scope` for this same cycle; per this task's own
   dispatch note, the two tasks must not be run concurrently.

## Risks & Mitigations

- **Risk**: adding a commit call inside the post-deploy reconcile loop could reintroduce a
  concurrency hazard if this loop is ever moved out of its current "no dispatch in flight"
  window. **Mitigation**: the loop's own header comment already documents and relies on this
  placement invariant for other reasons (no new lock needed); the new commit call rides the same
  invariant and should carry a comment cross-referencing it, so a future mover of this code sees
  the dependency.
- **Risk**: `git-commit-scoped.sh`'s V5 contended-path refusal (exit 3) could, in principle, leave
  a `completed` status uncommitted indefinitely if the contention never clears. **Mitigation**:
  this is identical in kind to the existing non-blocking commit-failure posture used everywhere
  else in this file and in `orchestrate-cycle-postflight.sh`; it is an accepted, pre-existing
  residual risk class in this codebase, not a new one introduced by this fix. Move 4's residue
  check will still surface it (warn-only) if it occurs.
- **Risk**: the new test assertions could be flaky if `$WORKDIR`'s git repo is not seeded with an
  initial commit before `run_sut`, since `git rev-parse HEAD` on a repo with zero commits errors.
  **Mitigation**: follow `test-orchestrate-cycle-postflight.sh`'s exact precedent (initial fixture
  commit via `git add specs/ .claude/ && git commit -q -m fixture` right after `git init`).

## Context Extension Recommendations

- **Topic**: post-deploy reconcile's commit obligation.
- **Gap**: `orchestrate-cycle-plan.sh`'s post-deploy reconcile block header comment documents the
  *placement* rationale (serialized window, no new lock needed) but says nothing about the
  ledger/commit obligation this task adds. Once implemented, that header comment should be
  extended in place (not a new context file) to state that a promotion must update
  `.completed_tasks` and commit its own `state.json`/`TODO.md` change, so a future reader does not
  reintroduce this exact gap for a new promotion branch.
- **Recommendation**: this is a one-paragraph addition to the existing inline comment at
  `orchestrate-cycle-plan.sh:1111-1131`, to be made by the implementation phase alongside the
  code change — no new standalone `.claude/context/` file is warranted for a single-site,
  single-loop invariant.

## Appendix

### Search queries / commands used
- `grep -n "completed_tasks\|post_deploy_reconcile\|REDEPLOY CHECKPOINT\|promoted\|all_terminal" scripts/orchestrate-cycle-plan.sh`
- `grep -n "completed_tasks" scripts/orchestrate-cycle-postflight.sh scripts/reconcile-task-status.sh`
- `grep -n "git-commit-scoped\|git commit\|commit" scripts/reconcile-task-status.sh`
- `grep -n "stage_paths" scripts/orchestrate-cycle-postflight.sh`
- `grep -n "directory-pathspec\|directory pathspec\|TASK_DIR" context/standards/git-staging-scope.md`
- `grep -n "post_deploy_reconcile\|REDEPLOY CHECKPOINT\|reconcile-task-status" scripts/tests/test-orchestrate-cycle-plan.sh`
- `grep -n "git-commit-scoped\|git init\|git log" scripts/tests/test-orchestrate-cycle-postflight.sh`
- `grep -n "completed_tasks" context/patterns/batch-orchestration-guardrails.md docs/architecture/orchestrate-state-machine.md`

### Key file:line references
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1111-1148` — post-deploy
  reconcile pass (write site to extend).
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1502-1514` — all-terminal check
  and `emit_and_exit` (the point of no return for an uncommitted promotion).
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh:1341-1392` — the
  established `stage_paths` + `git-commit-scoped.sh` call shape to mirror.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh:1425-1429` — the
  established `.completed_tasks` append idiom to mirror.
- `agent-system/extensions/core/scripts/reconcile-task-status.sh:613-626,663-673` — the two
  `promoted ... -> completed` transitions this task cares about.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh:4075-4201` — Group 29
  Arm A, the reusable fixture for the new regression case.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh:86-121,1210-1220`
  — the real-git-repo + before/after-HEAD assertion pattern to replicate.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md:1061,1073` —
  authoritative description of Move 4's two `completed_tasks` consumers.
