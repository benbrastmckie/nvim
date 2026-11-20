# Absent Specs Git History

## Why This Exists

A consumer repository may add `specs/` (wholly or partly) to its own `.gitignore`, per
`scripts/lib/specs-ignore-lib.sh`'s predicate (Verified Finding V13). Several history readers in
this codebase consult the specs tree's git history — a log, a diff, or a `git show` of a prior
committed revision — and each needs a stated, discoverable answer for the case where that
history is thin or absent entirely, rather than inferring a failure from the absence. This
document gives that answer per reader, states the skip-recording contract that accompanies it,
and names the residuals honestly rather than silently.

## Per-Reader Stated Answers

| Reader | Behavior on an absent or thin specs git history |
|--------|---------------------------------------------------|
| `scripts/validate-state.sh`'s `--deep` artifact-loss check | Two explicit `log_warn` lines (around the terminal-status immutability check and the per-type artifact-loss check, D5) report "No git history found for `$STATE_FILE`" and skip that one check. This is a defined WARN-level skip, not a silent zero — no code change needed. |
| `scripts/dispatch-metrics.sh`'s churn split | `git log --numstat ... -- specs/` against a repository with no specs history yields no matching lines, and the pre-initialized `specs_added`/`specs_removed` counters stay at zero. Zero is the honest answer here: no committed churn under `specs/` occurred, because none *can* occur. The parallel `outside_specs` figure is computed independently and still reports real deliverable churn, so the metric as a whole degrades gracefully rather than going dark. |
| `scripts/git-commit-scoped.sh`'s `--honest-index-rows` addendum | The addendum's Python helper loads `HEAD:specs/state.json` and the staged `:specs/state.json` via `git show`; either `git show` call raising (an absent history, or a path that has never been committed) is caught and the helper exits before printing anything, which suppresses the addendum entirely rather than raising an error. |
| `scripts/reconcile-task-status.sh` | Issues no git-history read of any kind (`git log`, `git show`, `git ls-files`, `git rev-list`, `git diff`) — measured directly against the live source, not inferred. No change and no answer required. |
| `scripts/task-lock.sh` | Issues no git-history read of any kind — measured directly against the live source, same as above. No change and no answer required. |
| `scripts/lib/territory-contention-lib.sh` | Its only `git log` text is prose inside an agent-facing advisory note, not a command this library executes. No change and no answer required. |

## The V13 Recording Contract

A V13 skip (exit 8: wholly all-ignored; exit 9: partly ignored with the trackable siblings
already committed) leaves a durable, discoverable record through the channel its call site's
own context allows:

- **A task context exists** (the caller passes `--task`): `orchestrate-cycle-postflight.sh`'s own
  `8|9)` arm fires a deduped `issue-record.sh` entry with `--kind issue`,
  `--class "repository configuration"`, `--severity minor`, `--resolution fixed_inline`, and a
  `--what-happened` string naming the exit code and that this is the repository's own
  configuration rather than a defect. `--severity minor` (not `none`) is used because
  `issue-log.md`'s severity scale reserves the `none` rung for `kind: "win"` entries, and this is
  a `kind: "issue"` entry — a routine repository-configuration fact, not an achievement — so
  `minor` is the closest fit on a closed scale rather than widening it.
- **No task context exists** (the caller passes no `--task`): `git-commit-scoped.sh` itself
  appends one `specs/events.jsonl` line via `events-append.sh`, `--event-type
  ignored_pathspec_skip`, `--category deviation`. `--category deviation`, never `blocker`:
  `events-append.sh` promotes only a `blocker` line to the cross-repo central log, and a benign
  repository-configuration fact must never reach it.

**Dedup key**: both channels key their identity on `${session_id}|v13-skip|${exit_code}`
(truncated to a 16-character hex digest via `sha256sum`), looked up before writing so a
wholly-ignored-specs repository does not accumulate one entry per completing cycle — at most one
entry per `/orchestrate` invocation per exit code, never once per cycle.

**Hard properties**, true of both channels: never fatal (a recording failure is swallowed, never
propagated to the caller's own exit code or control flow); never status-bearing (the task's own
status transition and the emitted verdict JSON's attribution fields are untouched by either
write); never auto-routed to a follow-up (no `--suggested-channel` on the `issue-record.sh` call,
and the `events-append.sh` line's `deviation` category never reaches the cross-repo central log a
`follow_up_task`-style channel would consume).

## Named Residuals

- **`scripts/git-commit-phase.sh` and `scripts/lib/redeploy-checkpoint-lib.sh`** both always pass
  `--task` and own no task-local record of their own for a V13 skip at their call site. A V13
  skip there is visible on stderr (a `NOTE:`-level line, never `ERROR:`) but durable only through
  the conclusion stage's own reading of the dispatch that wrapped it — neither site gets a
  dedicated `issue-record.sh` entry, deliberately: adding a second, independent dedup
  implementation for one adjacent surface each is out of proportion to the gap.
- **`events-append.sh` resolves its own store from `SCRIPT_DIR`**, not from whichever repository
  a commit's pathspecs actually belong to. For every ordinary caller the two coincide. For a
  cross-repository commit caller, the event lands in the invoking repository's own event log —
  the honest home for it, not a second root-resolution path grafted on to chase the committed
  repository instead.
