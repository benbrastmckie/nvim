# Research Report: Task #161

- **Task**: 161 - Settle the unattended-refresh policy and update the systemd, skill, and command surfaces
- **Started**: 2026-09-07T00:00:00Z
- **Completed**: 2026-09-07T00:00:00Z
- **Effort**: small (documentation + a small unit-file diff)
- **Dependencies**: Task 160 (completed)
- **Sources/Inputs**:
  - `agent-system/extensions/core/systemd/claude-refresh.service`
  - `agent-system/extensions/core/systemd/claude-refresh.timer`
  - `agent-system/extensions/core/skills/skill-refresh/SKILL.md`
  - `agent-system/extensions/core/commands/refresh.md`
  - `agent-system/extensions/core/scripts/claude-refresh.sh` (`main()`, `print_help()`)
  - `agent-system/extensions/core/scripts/check-extension-docs.sh` (run against the deployed `.claude/` tree)
  - `systemd-analyze verify` (run against both unit files directly, no deploy needed)
  - `specs/TODO.md` entries #160 (completed, prior task in this chain) and #161 (this task)
  - `.gitignore` (confirms `/.claude/` deploy-tree disposability, line 6)
- **Artifacts**: `specs/161_unattended_refresh_policy_and_surfaces/reports/01_unattended-refresh-policy.md` (this report)
- **Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- Both open technical gates are already green: `systemd-analyze verify` exits 0 on both
  `claude-refresh.service` and `claude-refresh.timer` (the only warning printed is an unrelated
  `cups.socket` legacy-path notice from an unrelated system unit), and
  `check-extension-docs.sh` currently reports `core PASS` (its one `FAIL` is the unrelated
  `lean` extension). Both tools are available in this environment, so neither acceptance gate
  needs a "could not verify" fallback.
- The "confirm, do not re-litigate" question is **confirmed true and traceable to code**:
  `claude-refresh.sh`'s `main()` calls `run_claude_pass`, `run_lean_pass`, `run_zombie_pass`, and
  `run_mcp_fanout_pass` unconditionally in one sequence, all four gated by the same single
  `$DRY_RUN`/`$FORCE` pair passed through from the one `ExecStart` invocation. No new pass added
  since the service file was written needed (or needs) its own flag or its own `ExecStart` line;
  the timer's `--dry-run` invocation already reaches every pass. The service's existing comment
  states the non-destructive policy but does not yet say this explicitly for the newer passes —
  this is the one real gap in the "confirm" half of the task.
- The deploy-path question is a real, unresolved decision, not yet recorded anywhere. Recommend
  adding `ConditionPathExists=%h/.config/nvim/.claude/scripts/claude-refresh.sh` to the
  `[Unit]` section of `claude-refresh.service`: on a machine where the deploy tree is absent,
  this converts a silent/failed-unit outcome into a clean "condition not met" skip (systemd logs
  it as informational, not a failure, and does not mark the unit as failed in `systemctl
  --failed`), which is strictly safer for an unattended hourly cadence than either an unexplained
  `ExecStart` failure or documentation alone.
- The surfaces gap is real and matches the task's own diagnosis: `SKILL.md` and `refresh.md`
  document all seven passes, but only as a sequence of `Step 1..7` procedural blocks plus a
  `Process Safety`/`Process Protection` narrative section that itself only covers four of the
  seven (the two process passes plus the two newer report-only passes) — the three file/spec
  cleanup passes (postflight markers, task locks, session-scoped orchestration files/session
  registry) sit outside that narrative with no parallel "is this destructive" framing. Neither
  file currently has one place a reader can scan for "all N passes, each with its gate and
  destructiveness."
- `claude-refresh.sh --help` (`print_help()`) documents flags and the Lean env var but does not
  name that the script runs four distinct passes — worth a one-line addition for a reader who
  invokes the script directly rather than through `/refresh`.

## Context & Scope

Task 161 is explicitly scoped as narrow: two small, already-mostly-decided items (a unit-comment
addition confirming an existing invariant, and one explicit unit-behavior decision) plus a
documentation-coherence pass over two already-mostly-complete surface files. It follows a chain
of three prior tasks (158, 159, 160 — the last of which is `[COMPLETED]`) that each added a new
`claude-refresh.sh` pass and updated `SKILL.md`/`refresh.md` incrementally. This research
confirms the current state of every acceptance-relevant artifact and produces concrete,
verifiable recommendations for the plan/implementation phases; it makes no code or doc edits.

## Findings

### Systemd unit baseline (already green)

```
$ systemd-analyze verify agent-system/extensions/core/systemd/claude-refresh.service
/etc/systemd/system/cups.socket:5: ListenStream= references a path below legacy directory /var/run/, ...
$ echo $?
0
$ systemd-analyze verify agent-system/extensions/core/systemd/claude-refresh.timer
/etc/systemd/system/cups.socket:5: ...
$ echo $?
0
```

Both files verify cleanly against the two source files directly (no deploy required — this
tool reads unit files by path). The only printed line is a pre-existing, unrelated warning about
the system's own `cups.socket` unit; it does not reference either target file. This gate is
already satisfied before any edit and must remain so afterward — a comment addition and a single
`Condition*=` line are both syntactically inert to `systemd-analyze verify`.

### `check-extension-docs.sh` baseline (already green for `core`)

Run against the deployed `.claude/` tree (the script refuses to run from the
`agent-system/extensions/` source tree itself, by design — see its own error message, which
correctly named this as "not a deployed scripts/ tree"):

```
core            PASS
...
lean            FAIL   (unrelated to this task)
...
FAIL: 1 issue(s) found
```

`core` — the extension that owns `skill-refresh`, `refresh.md`, and the systemd units — already
passes. The lone `FAIL` is the `lean` extension, unrelated to this task's file scope. This
confirms the acceptance gate ("the doc-lint script check-extension-docs.sh exits zero") should be
read as "core's row stays PASS," since the script's overall exit code already reflects the
pre-existing, out-of-scope `lean` failure and is not something this task's edits can or should
change.

### The "no unit change needed" claim is verifiably true, at the code level

`claude-refresh.sh`'s `main()` (lines ~1315-1349):

```bash
run_claude_pass "$FORCE" "$DRY_RUN"
run_lean_pass "$FORCE" "$DRY_RUN"
run_zombie_pass "$FORCE" "$DRY_RUN"
run_mcp_fanout_pass "$FORCE" "$DRY_RUN"
```

All four passes run unconditionally, in this fixed order, on every invocation, threading through
the same `$FORCE`/`$DRY_RUN` pair that the *single* `ExecStart=... claude-refresh.sh --dry-run`
line already supplies. Two of the four (`run_zombie_pass`, `run_mcp_fanout_pass`) never terminate
anything under any flag combination — `$DRY_RUN` only gates their `[DRY RUN]` banner line, per
the script's own comments at lines ~905 and ~1134-1138. `run_lean_pass` only terminates under
`--force`, which the unit never passes. So: every pass added since the service file was authored
is reached by the existing `ExecStart` line with no flag or line change, and none of them can
terminate anything under the unit's `--dry-run` invocation. This is the fact the task asks to be
recorded in the unit comment, not re-derived from scratch each time a new pass is added.

The file/spec-cleanup passes (orphaned postflight markers, stale task locks, stale
session-scoped orchestration files, stale session registry entries) are a separate case, already
correctly out of scope for the *unit*: they live in `skill-refresh/SKILL.md`'s Steps 3, 4, 4.5,
4.6 — invoked only through the `/refresh` skill, never through `claude-refresh.sh` (the systemd
`ExecStart` target). `refresh.md` already states this scoping explicitly for both the task-lock
reap and the session-runtime-file reap ("This cleanup runs only on explicit `/refresh`
invocation... not on the hourly systemd cadence"). No inconsistency found here; this confirms
the unit-comment claim should be scoped to `claude-refresh.sh`'s four internal passes, not framed
as covering all seven surface-level passes (three of which the unit never touches at all).

### Deploy-path decision: recommend `ConditionPathExists`

`ExecStart=%h/.config/nvim/.claude/scripts/claude-refresh.sh --dry-run` targets the gitignored,
regenerated `.claude/` deploy tree (`.gitignore` line 6: `/.claude/`, with a comment explicitly
calling it "a disposable build artifact regenerated from the source store"). On a machine where
that tree has not yet been deployed (fresh clone, or the `.claude/` wipe/regenerate cycle mid-run),
the unit's oneshot service will fail with a "No such file or directory" `ExecStart` error, which
systemd records as a failed unit — visible in `systemctl --failed` and the journal every hour
until the tree is regenerated, with no actionable signal beyond "path not found."

Adding `ConditionPathExists=%h/.config/nvim/.claude/scripts/claude-refresh.sh` to the `[Unit]`
section changes this outcome: systemd `Condition*=` directives that evaluate false cause the unit
to be **skipped**, not failed — logged at informational level, and specifically excluded from
`systemctl --failed`/exit-code propagation (this is systemd's standard, documented distinction
between a condition check and an actual execution failure). For an unattended, no-confirmation,
hourly cadence, "skip cleanly until the dependency exists" is a strictly safer default than
"fail loudly and repeatedly," and costs one line. No existing unit in this repo uses
`Condition*=` yet (`claude-refresh.service`/`.timer` are the only two `.service`/`.timer` files
present), so there is no established local convention to match or break.

Recommendation for the plan phase: add the `ConditionPathExists=` line to `[Unit]` in
`claude-refresh.service`, and document the choice (both the "why a Condition, not a hard
failure" reasoning and the fact that a skipped run produces no output/log noise) directly in the
unit's own comment block, satisfying the acceptance criterion "the service comment states the
ruling on... the deploy-path dependency" in the same place as the destructive-passes ruling.

### Surfaces: what "coherent inventory" requires, concretely

Current structure (already close, not "four bolted-on additions" in the sense of *missing*
content — every one of the seven passes is in fact documented — but scattered across two
different organizing schemes):

| Pass | Currently documented in `SKILL.md` | Currently documented in `refresh.md` |
|------|-------------------------------------|----------------------------------------|
| Orphaned Claude processes | Step 2 + "Process Safety" narrative | "Process Cleanup" + "Process Protection" narrative |
| `~/.claude/` directory cleanup | Steps 6-7 | "Directory Cleanup" table |
| Orphaned postflight markers | Step 3 (no destructiveness framing) | not present in "What It Cleans"; absent entirely |
| Stale task `.lock` dirs | Step 4 | "Stale Task Locks" section (states cadence scoping) |
| Stale session-orchestration files | Step 4.5 | "Stale Session-Scoped Orchestration Files" section |
| Stale session registry entries | Step 4.6 (no `refresh.md` mirror noted) | not present as its own subsection |
| Lean LSP reclamation | "Process Safety" narrative (bulleted) | "Process Protection" narrative (bulleted) |
| MCP fan-out reporting | "Process Safety" narrative (bulleted) | "Process Protection" narrative (bulleted) |
| Zombie reporting | "Process Safety" narrative (bulleted) | "Process Protection" narrative (bulleted) |

Two concrete gaps beyond reorganization:
1. Orphaned postflight markers (Step 3) has no destructiveness statement anywhere (it deletes
   unconditionally past a 60-minute age threshold, with no interactive confirmation, when not
   `--dry-run` — this is a destructive pass, distinctly different in gating from the
   confirmation-gated process-termination passes, and should say so).
2. Stale session registry entries (Step 4.6) is documented in `SKILL.md` but has no corresponding
   subsection in `refresh.md`'s "What It Cleans" — every other Step 3-4.6 item has a `refresh.md`
   mirror; this one does not.

Recommendation for the plan phase: add one small, single-location table (in both `SKILL.md` and
`refresh.md`, near the top of each, before the step-by-step procedure) listing all seven items —
name, gate (interactive-confirm / `--dry-run` preview / age-threshold-only / report-only-always),
and destructive (yes/no, with "recoverable" noted for Lean reclamation) — so a reader gets the
full inventory in one place rather than assembling it from Steps 1-7 plus two narrative sections
that only cover a subset. This directly answers the task's own diagnosis ("rather than as four
bolted-on additions to a document written for the original four") without requiring a rewrite of
the existing, correct step-by-step procedural content — the table supplements it as a summary,
it does not replace the steps.

### `--help` text: minor optional addition

`claude-refresh.sh print_help()` (lines ~634-646) documents `--force`, `--dry-run`, the no-flag
status mode, and `LEAN_LSP_IDLE_THRESHOLD_MIN`, but does not name that the script runs four
distinct passes (Claude process, Lean LSP, zombie reporting, MCP fan-out reporting) each time.
This is optional per the task's own "possibly... for --help text only" framing. Recommend a
short one-line addition (e.g. "Runs four passes each invocation: Claude-process reclamation,
Lean LSP reclamation, zombie reporting, MCP fan-out reporting.") for a reader who invokes the
script directly rather than through `/refresh`, but this is not required by any of the five
stated acceptance criteria (none of them reference `--help` output specifically — the
"`/refresh --dry-run` help text matches the documented inventory" criterion is about
`/refresh --dry-run`'s runtime section-header output matching what `SKILL.md`/`refresh.md`
document, which is already true today: every `echo "=== ... ==="` banner in `SKILL.md`'s Steps
3-7 has a matching prose section in `refresh.md`, with the one Step 4.6 gap noted above).

## Decisions

- Treat the "new passes require no unit change" claim as **confirmed** (code-level, cited above)
  rather than re-litigated; the implementation phase should add a short, factual comment
  addendum to `claude-refresh.service` recording this, not reopen the question.
- Recommend the `ConditionPathExists=%h/.config/nvim/.claude/scripts/claude-refresh.sh` approach
  for the deploy-path question over both bare alternatives (leave as-is silently, or comment-only
  documentation with no behavior change) — it is the only option that changes the actual failure
  mode on a machine without a deployed tree, at negligible cost, with no local convention it
  would break.
- Recommend a single small inventory table added to both `SKILL.md` and `refresh.md` (not a
  restructure of the existing Steps 1-7 or the Process Safety/Protection narrative) as the
  mechanism for "describe the full pass inventory coherently."
- The `--help` text addition is optional, not required by any stated acceptance criterion;
  leave it to implementer judgment whether the one-line addition is worth the diff.

## Risks & Mitigations

- **Risk**: `ConditionPathExists` could be construed as adding scope beyond "decide and record."
  **Mitigation**: it is a single, standard, well-documented systemd directive; the task text
  explicitly names it as one of three considered options ("keep it as-is, add a
  ConditionPathExists, or document the dependency"), so implementing it is within the task's own
  named scope, not an expansion of it.
- **Risk**: reorganizing `SKILL.md`/`refresh.md` into a table could drift from the actual runtime
  banners if a future pass is added without updating the table. **Mitigation**: keep the table as
  a thin summary that cites the existing Step numbers/section names rather than duplicating their
  content, so one place needs updating (the step/section itself) and the table's row can point to
  it rather than restate it.
- **Risk**: `check-extension-docs.sh`'s overall non-zero exit (from the unrelated `lean` FAIL)
  could be misread by an implementer as this task's own gate failing. **Mitigation**: this report
  states explicitly that `core`'s row is the acceptance-relevant signal, confirmed already `PASS`
  pre-edit.

## Context Extension Recommendations

- **Topic**: systemd unit `Condition*=` usage precedent.
- **Gap**: no existing context file documents when/how this repo uses systemd `Condition*=`
  directives (this task would establish the first instance).
- **Recommendation**: not urgent enough to warrant a new context file for a single directive on
  two units; if a third systemd unit is later added to this repo, revisit whether a short
  `context/patterns/systemd-unit-conventions.md` becomes worthwhile at that point.

## Appendix

- Search queries / commands used: `systemd-analyze verify` (both unit files, run directly against
  the source-store paths); `bash .claude/scripts/check-extension-docs.sh` (run against the
  deployed tree, per the script's own refusal-to-run-from-source-store guard); `grep -n
  "^##|^###"` over `SKILL.md` and `refresh.md` to enumerate section structure; `grep -n
  "run_main\|run_claude_pass\|run_lean_pass\|run_zombie\|run_mcp"` over `claude-refresh.sh` to
  confirm the unconditional pass sequence in `main()`.
- `agent-system/extensions/core/scripts/claude-refresh.sh` line references: `print_help()`
  ~634-646, `run_claude_pass()` ~656-792, `run_lean_pass()` ~801-901, `run_zombie_pass()`
  ~961-1058, `run_mcp_fanout_pass()` ~1139-1313, `main()` ~1315-1349.
