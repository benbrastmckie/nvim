# Implementation Plan: Task #634

- **Task**: 634 - Mechanize /orchestrate conclusion-stage roadmap regenerate
- **Status**: [IMPLEMENTING]
- **Effort**: 7.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/634_mechanize_orchestrate_conclusion_roadmap_regenerate/reports/01_mechanize-conclusion-roadmap-regenerate.md
- **Artifacts**: plans/01_mechanize-conclusion-roadmap-regenerate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The roadmap regenerate that `/orchestrate`'s conclusion stage owns is specified completely but
executes only if the lead voluntarily continues past Move 4's consolidated output — a prose
pointer with no mechanical backstop. This plan extracts that step's executable body into one new
script invoked unconditionally from Move 4's finalize sequence (the same call site the Batch Gate
Stage already proves reliable), defers the consolidated output's *emission* until after the
conclusion stage has run, and adds a `Stop`-hook pending-marker backstop modeled on the proven
`subagent-postflight.sh` shape. Six phases: script, wiring/reorder, backstop hook, tests,
contract prose, deploy-and-gate.

### Research Integration

The research report's two rulings are adopted as written, with one naming change and two
placement refinements:

- **GOAL (1) — extract to a script, contract keeps the authoritative prose.** Confirmed: every
  primitive the step needs already exists (`lib/roadmap-preflight-lib.sh classify`,
  `roadmap-integration.sh --regenerate`, `events-append.sh`, `issue-record.sh`,
  `git-commit-scoped.sh`, `lint/lint-roadmap-batch-proposals.sh`). The new script sequences
  them; it invents no primitive.
- **GOAL (2) — adopt (a) reorder as primary AND (b) Stop-hook as defense in depth.** Confirmed
  by the template's own text, which already asserts the invariant the skill body violates.
- **Script name**: `orchestrate-conclusion-roadmap.sh`, not the report's
  `orchestrate-roadmap-regenerate-step.sh` — it sits beside `orchestrate-conclusion-aggregate.sh`
  in the same family and names the stage it belongs to rather than the mechanism it wraps.
- **Backstop marker polarity**: a *pending* marker written by the new script at Move 4 and
  deleted at the end of Move 5's Step 6, rather than a "conclusion ran" marker whose absence
  must be inferred. This mirrors `.postflight-pending` exactly, including where the
  loop-guard counter lives (inside the marker), so the backstop reuses a proven shape instead of
  inventing an inverted one.
- **Invocation is foreground, not backgrounded.** Unlike the Batch Gate Stage (which wraps a full
  `verify-deploy.sh` run and therefore needs the nohup/pid-capture/bounded-`kill -0` idiom), a
  classify plus an idempotent regenerate is a sub-second operation. It is called directly.

Four findings from this dispatch's own reads extend the report:

1. **`manifest.json`'s `provides.scripts` and `provides.hooks` are explicit file lists**, not
   globs (407 and 27 entries). A new script or hook that is not declared there is not deployed,
   and `check-extension-docs.sh`'s Rule Q (gate 3, commit-blocking) fails on an undeclared
   script. `sync-manifest-scripts.sh --write` is the sanctioned writer.
2. **A new test suite owes a `scripts/tests/suite-classification.data` row** and must satisfy
   gates 27 (subject-resolution declaration) and 29 (test-root resolution), both commit-blocking
   and both scoped to `scripts/tests/*.sh`.
3. **The pending marker needs no runtime-file-pattern or `.gitignore` change.**
   `specs/.orchestration/` is already the 19th, directory-class member of
   `scripts/lib/runtime-file-patterns.sh`, and `git check-ignore -v` confirms
   `specs/.gitignore:33` (`**/.orchestration/`) already ignores a representative marker path.
   Gate 14 is satisfied without edits, and no class-member count figure moves.
4. **A fifth and sixth prose surface are owed beyond the dispatch's named three.**
   `context/standards/postflight-tool-restrictions.md`'s Conclusion Stage `Bash` row enumerates
   the Step-5 primitives individually and must name the script instead; and
   `context/patterns/orchestrate-batch-results-template.md`'s own opening line attributes the
   emission to "Move 3", which the reorder makes actively wrong.

### Premise Re-Validation

Checked each carried figure in the dispatch `## Description` against live state, per the
Carried-Figure Discipline. Three of four hold; one has moved and is recorded here rather than
carried forward silently.

| Carried claim | Verdict |
|---|---|
| `specs/events.jsonl` carries no `conclusion_proposal_recorded` / `roadmap_regenerate_blocked` event for `sess_1794696615_44948d` | **Confirmed.** 24 events exist for that session; 0 are of either type. |
| git log carries no "orchestrate conclusion: roadmap regenerate" commit for that session | **Confirmed, with a refinement.** Two such commits exist in history — `3b15c5abe` (`sess_1794792661_b8da9f`) and `ab1f83c4d` (`sess_1794726236_c43de4`) — neither from `sess_1794696615_44948d`. The claim as scoped to that session holds. |
| `roadmap-integration.sh --regenerate --dry-run` reports "content would change" (436/626 still listed, 629-633 missing) | **No longer true — superseded by intervening work.** A live `--regenerate --dry-run` now reports `wrote nothing (layout=classic, no content change)`. Commit `5c0bf002a roadmap: full maintenance pass` settled that specific drift. The *mechanism* defect this task fixes is untouched by that; only the particular stale content the description cited has since been cleaned up by hand. |
| `SKILL.md`'s "Move 5: Conclusion" is a four-line prose pointer placed after the consolidated-output step; nothing in `settings.json` or `hooks/` checks that it ran | **Confirmed.** `SKILL.md` lines 353-358 are a four-line pointer; the `Stop` array in `root-files/settings.json` holds four hooks (`post-command.sh`, `claude-stop-notify.sh`, `memory-nudge.sh`, `events-log-lifecycle.sh`), none of which checks Move 5. |

One **premise strengthening** the description does not state: the two successful conclusion
commits above prove Move 5 *does* run on some invocations. The defect is therefore an
unreliable, lead-discretion-dependent step, not a dead one — which is exactly what makes a
mechanical call site the right fix rather than a repair of Step 5's own logic.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` line 142 pairs this task with `562` in one run
(`/orchestrate 634, 562`) and line 174 states the intent this plan implements: "`634` moves the
regenerate onto the Move 4 finalize path". Lines 187-190 record that `634` declares no
`file_scope`, making its real overlap with `562` on `conclusion-stage.md` invisible to the
territory scan. This plan's per-phase `Files to modify` blocks resolve that: the harvest pipeline
populates `file_scope` from them, so the overlap becomes declared rather than latent.

## Goals & Non-Goals

**Goals**:
- The roadmap regenerate runs from a script on Move 4's finalize path, unconditionally, in
  single-task and batch runs and on every exit status, with exactly one executable copy.
- A mechanical backstop covers the remainder of Move 5 (channels, Step 7) — both the reorder and
  the `Stop`-hook check, with the ruling recorded in the contract.
- Test coverage for: fires on `all_terminal` and on a partial exit; the `absent`/`unknown`
  degrade still never writes; a second run is a no-op.
- The six prose surfaces state the resulting design.

**Non-Goals**:
- No change to Step 5's own *logic* — classify, regenerate, scoped commit, advisory lint, and the
  three-part degrade are moved verbatim, not redesigned.
- No change to `--prune`'s deprecated-alias status, to the approval-ledger contract, or to any
  channel (a)/(b)/(c) gate.
- No rescoping or retirement of `lint/lint-roadmap-batch-proposals.sh` — that decision belongs to
  its own owner and `roadmap-update.md` already says so.
- No edits to `scripts/issue-record.sh`, `context/formats/issue-log.md`, or
  `scripts/orchestrate-conclusion-aggregate.sh` — all three are in the concurrent sibling's
  declared territory and this plan invokes them without modification.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent sibling (`562`, same cycle) edits `context/contracts/conclusion-stage.md`, which Phase 5 also rewrites | M | H | Phase 5 re-reads the file immediately before editing, edits only the Step 5 / Executable Stage Body region, and stages that one path explicitly. Never a directory or glob add. The other three paths in `562`'s scope are explicit Non-Goals here. |
| Gate 20 (orchestrator context budget lock) trips on SKILL.md growth | M | L | Net eager context should *fall*: Step 5's ~70-line executable body in `conclusion-stage.md` collapses to a pointer, while SKILL.md gains ~6 lines. Phase 2 verifies with `verify-deploy.sh --only-gate 20` before closing. |
| A new script undeclared in `manifest.json` is silently not deployed, and gate 3's Rule Q fails | H | M | Phase 1 runs `sync-manifest-scripts.sh --write` and declares `manifest.json` in its own `Files to modify`. Same obligation discharged again in Phases 3 and 4 for the hook and the suites. |
| The `Stop`-hook backstop re-blocks forever, or blocks a session that is not an orchestrate run | H | L | Copy `subagent-postflight.sh`'s proven guards exactly: `cc_session_id` correlation against hook stdin `.session_id`, a `MAX_CONTINUATIONS` cap stored in the marker with cap-reached deletion, and a `stop_hook_active` escape. No marker for this cc session means exit with `{}` — the hook is inert for every non-orchestrate session. |
| The existing `Stop` registrations wrap each hook as `… 2>/dev/null \|\| echo '{}'`, which would mask a block decision on a non-zero exit | M | M | The backstop returns its block JSON on stdout with exit 0 (the same convention `subagent-postflight.sh` uses under an identically-wrapped `SubagentStop` registration), so the `\|\| echo '{}'` arm never fires on the decision path. Phase 3 asserts this in its own test case. |
| Moving the emission later delays operator feedback | L | L | `/orchestrate` is `orchestrator_mode` — no human watches mid-run. One complete report beats two partial ones. |
| The unconditional call fires on a zero-dispatch invocation that touched nothing | L | M | `--regenerate` is already idempotent; the no-op path costs a classify plus a diff and emits `OUTCOME: … left … unchanged`. Verified live this dispatch. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 3 |
| 4 | 5 | 1, 2, 3 |
| 5 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Extract Step 5 into `orchestrate-conclusion-roadmap.sh` [COMPLETED]

**Goal**: One executable copy of the roadmap-update step exists as a script, with the pending
marker it must write for Phase 3's backstop.

**Tasks**:
- [x] Read `context/contracts/conclusion-stage.md`'s `### Step 5 — Roadmap update` in full and
      transcribe its body into the new script without logic change: classify via
      `lib/roadmap-preflight-lib.sh classify specs/ROADMAP.md`; on `classic`/`stage` run
      `roadmap-integration.sh --regenerate`, then `git-commit-scoped.sh … -- specs/ROADMAP.md`,
      then the advisory `lint/lint-roadmap-batch-proposals.sh` (exit code never acted on); on
      `absent`/`unknown` skip both the regenerate and the commit and run the three-part degrade
      (named structured warning naming verdict + path + the `/roadmap` remedy;
      `events-append.sh --event-type roadmap_regenerate_blocked` plus its own scoped commit of
      `specs/events.jsonl`; then the best-effort per-task-dir `issue-record.sh` loop). *(completed)*
- [x] Define the CLI as `--session SID --state-file PATH [--dry-run]`, modeled on
      `orchestrate-batch-gate.sh`'s own contract: `--state-file` is the multi-task state file
      directly (never `specs/state.json`); task numbers for the degrade loop are read from that
      file's `.task_numbers`, and task directories resolved through the sanctioned task-lookup
      helper (gate 18 forbids an ad hoc glob). `--dry-run` computes and prints the same summary
      but performs no write and no commit. *(completed)*
- [x] Give the script the standard header block in the house shape (purpose, the single call
      site, usage, exit codes `0`/`2`, and an explicit "never sourced" note), `set -euo pipefail`,
      the `deploy-root-guard.sh` source, and `lib/common.sh` — copying
      `orchestrate-batch-gate.sh`'s opening 55 lines as the structural model. *(completed)*
- [x] Record in the header why the trigger condition is *unconditional*, unlike
      `orchestrate-batch-gate.sh`'s `.implement_agents` gate: a research-only or plan-only
      invocation that still moved a task's status changes what `--regenerate` would render, so
      gating on an implement dispatch would reintroduce the skip this task exists to close. *(completed)*
- [x] Add a shared marker-path resolver beside the two existing session-scoped resolvers in
      `scripts/lib/runtime-file-patterns.sh`, returning
      `<specs_dir>/.orchestration/.conclusion-pending-<session_id>.json`, so the script and
      Phase 3's hook never duplicate the path. Add no class member and touch no pattern array —
      `specs/.orchestration/` is already covered directory-class, so no count figure and no
      `.gitignore` entry moves. *(completed)*
- [x] Write the pending marker as the script's last action (`mkdir -p` the directory first),
      carrying `session_id`, `cc_session_id` (from `$CLAUDE_CODE_SESSION_ID`, empty-tolerated),
      `continuation_count: 0`, and `created_ts`. Skip the marker write entirely under `--dry-run`. *(completed)*
- [x] Emit the step's outcome to stdout in one named, parseable block so Move 4 can fold it into
      the report that Phase 2 defers: the verdict, the `OUTCOME:` line verbatim, the commit sha or
      `none`, and the advisory lint's findings. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write` and
      confirm both new/changed paths appear in `provides.scripts`. *(completed: required `git add` of the new file first, since the script discovers via `git ls-files`)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `lint-shellcheck.sh` plus the script's own `--dry-run` self-exercise and
`check-extension-docs.sh --quiet` (Rule Q) cover a self-contained new script with no caller yet.

**Scope Hypothesis**: Step 5's body is asserted to transcribe into a single script with no logic
change and no primitive beyond the five already named. Confirm by diffing the script's sequence
against `conclusion-stage.md`'s Step 5 text line by line before closing the phase; if any
primitive proves to need a behavior change, stop and record it rather than quietly redesigning
the step.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-conclusion-roadmap.sh` - new; the single
  executable copy of the roadmap-update step
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` - add the pending-marker
  path resolver beside the existing session-scoped resolvers
- `agent-system/extensions/core/manifest.json` - `provides.scripts` declaration, regenerated by
  running sync-manifest-scripts.sh in write mode; a coupled generated surface for the new
  script, commit-blocking via gate 3's Rule Q

**Verification**:
- `bash .claude/scripts/lint/lint-shellcheck.sh` passes on the new script
- `bash agent-system/extensions/core/scripts/orchestrate-conclusion-roadmap.sh --session
  sess_probe --state-file <scratch state file> --dry-run` exits 0, prints the outcome block, and
  leaves `specs/ROADMAP.md`, `specs/events.jsonl`, and the marker path untouched
- `bash .claude/scripts/check-extension-docs.sh --quiet` reports no undeclared script

---

### Phase 2: Wire the one call site and defer the emission [COMPLETED WITH EXCLUSIONS]

**Goal**: The script runs on every Move 4 finalize path, and the consolidated output is no longer
printable before the conclusion stage has run.

**Tasks**:
- [x] In `skills/skill-orchestrate/SKILL.md`'s Move 4, immediately after the Batch Gate Stage
      paragraph and before the emission step, add the unconditional foreground invocation of
      `orchestrate-conclusion-roadmap.sh --session "$session_id" --state-file "$mt_state_file"`,
      stating explicitly that it is not backgrounded (a sub-second classify-plus-regenerate needs
      no bounded-waiter idiom) and not trigger-gated (it fires on `all_terminal`,
      `no_eligible_stuck`, `max_cycles`, and every `partial` alike). *(completed)*
- [x] Rewrite Move 4's "Then: emit the consolidated output …" sentence so Move 4 *renders and
      stages* the batch-results sections but does not print them, and name Move 5's Step 6 as the
      sole emission site. Keep the rest of that sentence's finalize list (residue check, session
      registry release, queue archive, `.dispatch/` removal, `.return-meta-multi` write) exactly
      where it is. *(completed)*
- [x] Rewrite Move 5's four-line pointer to state: the roadmap step has already run from Move 4
      (naming the script), the pending marker is live until Step 6 completes, and Step 6 is where
      the single combined report is emitted. *(completed)*
- [x] In `docs/architecture/orchestrate-state-machine.md`'s "Consolidated Output and Exit-Status
      Resolution", change numbered item 5 from "Emits the consolidated output" to render-and-stage
      with the emission attributed to Move 5 Step 6, and add a subsection beside
      "### Batch Gate Stage (between steps 4 and 5 above)" naming the roadmap step as the second
      sibling script at that same site — including the one axis on which the two differ (the
      batch gate is trigger-gated on `.implement_agents`; this one is unconditional). *(completed)*
- [x] In the same file's "## Move 5: Conclusion Stage" paragraph, correct the "items 5 through 9"
      enumeration so it no longer claims the consolidated output render precedes Move 5. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Tier Justification**: `skills/skill-orchestrate/SKILL.md` is the orchestrate loop's own body —
the suite selector returns 26 suites for it (dispatch building, cycle plan/postflight, handoff
identity, routing resolution, context budget, stall reprompt, and the postflight-boundary and
task-lookup lints among them), so no cheaper tier covers this phase's blast radius.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Move 4 invocation + the
  render/emit split; Move 5 pointer rewrite
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - numbered item 5,
  the sibling-script subsection, and the Move 5 placement paragraph

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 (the complete gate set, gate 20's eager-context
  budget lock and gate 8's full runner included) — **did not exit 0**; see Reasoned Exclusions below
- `bash .claude/scripts/tests/run-all.sh` exits 0 — **did not exit 0**; see Reasoned Exclusions below
- `grep -n "emit the consolidated output" SKILL.md` returns no occurrence inside Move 4 — confirmed
  (exit 1, no match, against both the source-store file and its deployed copy)
- `bash .claude/scripts/lint/lint-postflight-boundary.sh .claude/skills/skill-orchestrate` exits 0 —
  confirmed (0 violations); the full-corpus run inside `verify-deploy.sh` gate 9 also reports
  `[PASS] postflight boundary lint reports no failures (full corpus)`

#### Reasoned Exclusions

| Item | Reason | Evidence |
|---|---|---|
| `verify-deploy.sh` gate 29 (`lint-test-root-resolution.sh`) | Pre-existing violation in a different extension entirely, outside this task's `Files to modify`/Non-Goals: `agent-system/extensions/typescript/scripts/tests/test-typescript-verify.sh:40` has an unconditional fixed-depth `REPO_ROOT` walk at effective depth 5, exceeding that file's own 2-level safe boundary. | `bash .claude/scripts/lint/lint-test-root-resolution.sh --verbose` names exactly that one file/line; `git log -- agent-system/extensions/typescript/scripts/tests/test-typescript-verify.sh` shows it landed in commit `35725799c` (2026-11-13, "task 622 phase 2: regression suite and manifest script declaration"), 3 days before this dispatch and touching no file this task's `Files to modify` lists. |
| `verify-deploy.sh` gate 10 (`validate-state.sh --deep`) | Load-induced timeout, not content-dependent: this host ran this dispatch's work concurrently with sibling task `562`'s own session plus several unrelated desktop processes (observed via `ps -eo pid,ppid,etimes,pcpu,cmd --sort=-pcpu` showing multiple concurrent `claude`/`nvim`/browser processes). Reproduced identically (gate10 killed at its 60s timeout) on two independent full `verify-deploy.sh` runs in this same phase, regardless of which files were staged. | Both runs' own output: `[FAIL] gate10 (gate10_run) exceeded its 60s timeout and was killed`, unchanged between the first run (which also hit a stale `specs/.gate-lock` holder from an earlier exploratory command in this same dispatch, since cleaned up) and the second, cleaner run. |
| `tests/run-all.sh`'s one `NEW` failure, `test-gate-registry-resolution.sh` case32 | Directly downstream of the same gate-29 pre-existing violation above, not a regression from this phase's edits: case32 asserts `--only-gate 29` is accepted (rc=0) against the real tree, which genuinely finds the pre-existing typescript violation and returns rc=1. The other 5 `run-all.sh` failures this run are independently pre-existing and already tracked. | `tests/run-all.sh`'s own summary: `179 passed, 6 failed (5 expected, 1 NEW)`; `known-failures.txt` already lists all 5 "expected" suites (`test-double-loading-check.sh`, `test-gate-cache-equivalence.sh`, `test-lint-unit-integration-boundary.sh`, `test-orchestrate-cycle-postflight.sh`, `test-verify-deploy-context-budget.sh`) each with its own pre-existing, unrelated `real-defect`/`load-sensitive` reason; case32's own failing-case output shows the nested `--only-gate 29` sub-invocation reproducing gate 29's exact finding. |

None of the three excluded items names a file this phase's `Files to modify` list declares, and
none requires any further action from this task — `agent-system/extensions/typescript/**` and
`validate-state.sh`'s own timeout budget are outside this task's Non-Goals-adjacent scope.
Recorded as issues (non-blocking) via `issue-record.sh` in this task's own `issues.jsonl` for the
conclusion stage's evidence base, per the Carried-Figure/Issue-Log discipline, rather than fixed
here.

---

### Phase 3: `Stop`-hook backstop for the remainder of Move 5 [COMPLETED]

**Goal**: A session that wrote the pending marker cannot end its turn without Move 5 having run.

**Tasks**:
- [x] Create `hooks/orchestrate-conclusion-backstop.sh` on
      `hooks/subagent-postflight.sh`'s proven structure: read hook stdin, take `.session_id` as
      `CC_SESSION_ID`, enumerate `specs/.orchestration/.conclusion-pending-*.json`, and select
      only the marker whose `cc_session_id` equals it. No match, an empty `cc_session_id`, or a
      malformed marker: print `{}` and exit 0 — inert for every non-orchestrate session. *(completed)*
- [x] On a match, return `{"decision": "block", "reason": …}` on stdout with exit 0, the reason
      naming the missing stage, the contract path, and the specific remaining steps (channels
      (a)/(b)/(c), Step 7's next-batch suggestion, Step 6's report). Build the JSON with
      `jq -n --arg` so the reason is escaped, exactly as the precedent does. *(completed)*
- [x] Copy both loop guards verbatim in shape: a `MAX_CONTINUATIONS` cap incremented in the
      marker, deleting the marker and allowing the stop once reached; and a `stop_hook_active`
      escape so hooks cannot call hooks. Log each delete with its reason, as the precedent does.
      *(deviation: altered — `stop_hook_active` is read from hook stdin, Claude Code's own live
      harness-maintained flag, rather than from the marker's own field, which the precedent's
      sole writer always sets to a vestigial, permanently-`false` value; see the hook's own
      header comment for the full reasoning)*
- [x] Register the hook in `root-files/settings.json`'s `Stop` array using the same
      `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/… 2>/dev/null || echo '{}'` form as its four
      siblings, with a `timeout`. Confirm the block decision travels on stdout with exit 0, so the
      `|| echo '{}'` arm cannot swallow it. *(completed: also required the matching
      `merge-sources/settings-hooks.json` fragment entry, caught by gate 21's fragment-coverage
      check)*
- [x] Declare the hook in `manifest.json`'s `provides.hooks`. *(completed)*
- [x] Add the marker's deletion as the final action of Move 5's Step 6 in
      `context/contracts/conclusion-stage.md`, using the Phase 1 resolver's path. (This is the one
      Phase-3 edit to a file the concurrent sibling also declares: re-read the file immediately
      before editing, confine the change to Step 6's tail, and stage that path alone.) *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: the hook's contract is the deployed `settings.json` registration itself,
which only gates 2 and 21 exercise — no local check reads that cross-file surface.

**Files to modify**:
- `agent-system/extensions/core/hooks/orchestrate-conclusion-backstop.sh` - new; the `Stop`-event
  backstop
- `agent-system/extensions/core/root-files/settings.json` - `Stop` array registration (coupled
  generated surface: the deployed `.claude/settings.json` gate 2 validates derives from this file)
- `agent-system/extensions/core/manifest.json` - `provides.hooks` declaration
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - Step 6 gains the marker
  deletion as its final action

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --only-gate 2,21` exits 0 (deployed hook registrations
  and hook-registration paths) — confirmed: `PASS -- 4 check(s), 0 failure(s)`
- `bash .claude/scripts/lint/lint-shellcheck.sh` passes on the new hook — confirmed clean
- Hand probe: piping `{"session_id":"X"}` with no matching marker prints `{}` and exits 0; with a
  matching marker prints a `decision: block` object and exits 0 — both confirmed, plus three
  further cases exercised: `stop_hook_active: true` escapes with `{}` and leaves the marker
  untouched; a marker at `continuation_count: 3` (the cap) is deleted and returns `{}`; a
  mismatched `cc_session_id` returns `{}` without selecting the foreign marker

---

### Phase 4: Test coverage [COMPLETED]

**Goal**: The regenerate step's four required cases and the backstop's guards are covered by
suites the gate-8 runner discovers.

**Tasks**:
- [x] Create `scripts/tests/test-orchestrate-conclusion-roadmap.sh` on the structural model of
      `test-orchestrate-batch-gate.sh` (`set -uo pipefail`, `common_test_repo_root`,
      `common_test_resolve_subject`/`common_test_declare_subject` source-store-first resolution,
      `mktemp -d` scratch root with a scratch `specs/state.json` and scratch git repo, pass/fail
      counters, exit `0`/`1`/`2`). *(completed)*
- [x] Case A — `all_terminal`, `classic`/`stage` roadmap: the regenerate fires, the scoped commit
      lands on `specs/ROADMAP.md` alone, and stderr carries `OUTCOME: --regenerate rewrote`.
      *(completed)*
- [x] Case B — partial exit: a scratch state file with a non-empty `failed_tasks` produces an
      identical call outcome, proving the script carries no `exit_status` branch. Pair it with a
      grep-level assertion over the deployed `SKILL.md` that the invocation sits above the
      emission step and under no conditional — the call site, not the script, is what makes the
      partial-exit case true. *(completed)*
- [x] Case C — `absent`/`unknown`: assert no `OUTCOME:` line at all (so `--regenerate` was never
      invoked), `specs/ROADMAP.md` unchanged or still absent, and all three degrade surfaces
      fired (the named warning, the `roadmap_regenerate_blocked` row in the scratch
      `events.jsonl` plus its scoped commit, and at least one `issues.jsonl` row per scratch task
      dir). *(completed)*
- [x] Case D — idempotence: two back-to-back runs with no intervening state change; the second
      emits `OUTCOME: --regenerate left … unchanged` and creates no second commit. *(completed)*
- [x] Case E — the pending marker: written on a real run, carrying `cc_session_id` and
      `continuation_count: 0`; never written under `--dry-run`. *(completed)*
- [x] Create `scripts/tests/test-orchestrate-conclusion-backstop.sh` covering: no matching
      marker prints `{}`; a matching marker blocks on stdout with exit 0; a mismatched
      `cc_session_id` does not block; the `MAX_CONTINUATIONS` cap deletes the marker and stops
      blocking; `stop_hook_active` escapes. *(completed)*
- [x] Add a TAB-separated row for each new suite to `scripts/tests/suite-classification.data`
      with its class and reason (`lint-unit-integration-boundary.sh` fails loudly on an
      unclassified discovered suite). *(completed: both classified `unit`/`-` — neither suite
      spawns `deploy-headless.sh`/`verify-deploy.sh`/`run-all.sh`)*
- [x] Re-run `sync-manifest-scripts.sh --write` so both suites appear in `provides.scripts`.
      *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1, 3

**Verification Tier**: local

**Tier Justification**: `run-all.sh --only` on the two new basenames, plus gates 27 and 29 via
their own lint scripts, covers exactly the suites this phase adds.

**Scope Hypothesis**: two new suites and two new classification rows are asserted sufficient for
all four required cases plus the backstop. Confirm by running
`lint/lint-unit-integration-boundary.sh` against the deployed `tests/` directory after the rows
land — a third discovered-but-unclassified suite would surface there, not at review time.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` - new;
  cases A-E
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-backstop.sh` - new; the
  hook's five guard cases
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - one row per new suite
  (coupled generated surface: derived from the discovered-suite set)
- `agent-system/extensions/core/manifest.json` - `provides.scripts` declaration for both suites

**Verification**:
- `bash .claude/scripts/tests/run-all.sh --only
  test-orchestrate-conclusion-roadmap.sh,test-orchestrate-conclusion-backstop.sh` passes —
  confirmed: `2 passed, 0 failed`
- `bash .claude/scripts/lint/lint-subject-resolution-declaration.sh` and
  `bash .claude/scripts/lint/lint-test-root-resolution.sh` pass (gates 27, 29) — gate 27 passes
  outright; gate 29 still fails on the pre-existing, unrelated `typescript` extension violation
  recorded against Phase 2 (both new suites are individually reported `[INFO] OK`)
- `bash .claude/scripts/lint/lint-unit-integration-boundary.sh` reports no unclassified suite —
  confirmed for both new suites specifically (neither appears among the lint's 9 reported
  violations, all 9 pre-existing and unrelated — see this phase's own issue-log entry)

---

### Phase 5: State the resulting design in the contract prose [COMPLETED]

**Goal**: Every prose surface that describes this step describes what now happens, with the two
rulings recorded.

**Tasks**:
- [x] `context/contracts/conclusion-stage.md`: rewrite `### Step 5 — Roadmap update` as the
      authoritative description of *what* the step does plus a pointer naming
      `orchestrate-conclusion-roadmap.sh` as its sole executor and Move 4 as its sole call site,
      stating that the step has already run by the time Move 5 begins. Remove the executable
      code blocks so exactly one executable copy exists; keep the step's number and the Step
      4/6/7 narrative around it undisturbed. Add the GOAL (2) ruling — both the reorder and the
      `Stop`-hook backstop, with the reasoning for adopting both — to the "## The Executable
      Stage Body" preamble, and update that preamble's "immediately after Move 4's full
      finalization sequence (consolidated output, …)" clause, which the reorder makes wrong.
      Re-read the file immediately before editing (concurrent sibling territory) and stage this
      path alone. *(completed: committed alone, as its own commit, separate from the other three files)*
- [x] `context/patterns/roadmap-update.md`: rewrite Live Callers entry 1 to name the script as
      the actual call site and Move 4 as where it fires, keeping the "non-interactive — loud
      degrade … since this surface has no approver present" arm description, which this move
      does not change. Leave the advisory-lint disposition paragraph alone. *(completed)*
- [x] `context/standards/postflight-tool-restrictions.md`: in the Conclusion Stage allowed-`Bash`
      row, replace the individually-enumerated Step 5 primitives
      (`lib/roadmap-preflight-lib.sh classify`, `roadmap-integration.sh --regenerate`,
      `lint/lint-roadmap-batch-proposals.sh`, `issue-record.sh`'s degrade loop) with the one
      script, and add the marker deletion. Keep every Prohibited bullet — the `scaffold`,
      `--prune`, and caller-contract-editing prohibitions all still bind, now inside the script.
      Correct the section's own "strictly AFTER Move 4 has emitted the consolidated output"
      preamble, which the reorder makes wrong. *(completed)*
- [x] `context/patterns/orchestrate-batch-results-template.md`: correct the opening line's
      attribution (it currently names "Move 3") to the Move 5 Step 6 emission site, and reconcile
      the `### Conclusion` section note — its claim that the section renders "after this
      template's render completes" is now literally true of one single emission, which is worth
      saying plainly rather than leaving as an inference. *(completed)*
- [x] Re-read all four files after editing and confirm no task-number reference and no
      record-versioning language landed (both are repo-wide rules outside `specs/**`, and both
      have commit-blocking enforcement). *(completed: `check-task-references.sh` found one
      unrelated unbalanced-marker defect in Phase 4's own test suite — a missing
      `task-ref-ok:end` — fixed in place; `check-record-versioning.sh`'s 3 BLOCKING hits are all
      pre-existing, in an unrelated himalaya Lua-plugin doc tree, none in this phase's four files)*

**Timing**: 1.25 hours

**Depends on**: 1, 2, 3

**Verification Tier**: local

**Tier Justification**: `check-extension-docs.sh --quiet`, `check-task-references.sh`, and
`check-record-versioning.sh` are the three checks that read prose under `context/**`; no compiled
or runtime surface changes in this phase.

**Scope Hypothesis**: exactly four prose files are asserted to describe this step. Confirm before
closing with `grep -rln "roadmap-integration.sh --regenerate\|Step 5"` over
`agent-system/extensions/core/context` and `.../docs` and `.../skills` — a fifth hit not in this
list or Phase 2's means the enumeration was short and the phase is not done.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - Step 5 becomes
  description-plus-pointer; the stage-body preamble records both rulings
- `agent-system/extensions/core/context/patterns/roadmap-update.md` - Live Callers entry 1
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` - the
  Conclusion Stage `Bash` row and section preamble
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - the
  caller attribution and the `### Conclusion` section note

**Verification**:
- `bash .claude/scripts/check-extension-docs.sh --quiet` passes — confirmed (`PASS: all
  extensions OK`, after a routine `generate-context-line-counts.sh --write` Rule R line-count fix
  run via `deploy-headless.sh`)
- `bash .claude/scripts/check-task-references.sh` and
  `bash .claude/scripts/check-record-versioning.sh` pass — `check-task-references.sh` confirmed
  (`PASS: 0 unexempted task-reference occurrences`, after fixing a missing `task-ref-ok:end`
  marker Phase 4's own test suite had left unbalanced); `check-record-versioning.sh` reports 3
  pre-existing BLOCKING hits repo-wide, all in `lua/neotex/plugins/tools/himalaya/docs/` (unrelated
  to this task) — none in this phase's four files
- `grep -c '```bash' context/contracts/conclusion-stage.md` shows Step 5's code blocks gone (one
  executable copy, in the script) — confirmed: Step 5's own section carries zero `bash` fences

---

### Phase 6: Deploy, full gate set, and close [NOT STARTED]

**Goal**: The source-store work is deployed and the complete gate set is green.

**Tasks**:
- [ ] Re-read every file this task touched, confirm no foreign uncommitted modification is
      present (concurrent sibling on this same tree), and stage only this task's own paths.
- [ ] Run `bash agent-system/deploy-headless.sh` to regenerate the deployed `.claude/**` tree
      from the source store.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (all 29 registered
      gates) and `bash .claude/scripts/tests/run-all.sh`.
- [ ] Confirm the deployed tree carries the new script, the new hook, both suites, the
      `settings.json` `Stop` registration, and the manifest declarations.
- [ ] Exercise the real path once end to end: run
      `orchestrate-conclusion-roadmap.sh --session <probe> --state-file <scratch> --dry-run`
      from the deployed copy and confirm the outcome block renders and nothing is written.
- [ ] Commit with the scoped-staging flow (`git status --short`, `git diff --staged`, then
      `git-commit-scoped.sh`), never a directory or glob add.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, which regenerates the entire
  deployed tree
- `agent-system/extensions/core/manifest.json` - final `sync-manifest-scripts.sh --check`
  reconciliation if any earlier phase left it stale

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 with every registered gate passing — including
  2 (deployed hook registrations), 3 (doc-lint / Rule Q), 4 (task-reference lint), 5 (manifest
  parity + content-hash equality), 8 (`tests/run-all.sh`), 9 (postflight boundary), 11 (contract
  compliance), 14 (runtime-file tracking), 17 (scoped-commit boundary), 18 (task-lookup
  adoption), 20 (context budget lock), 21 (hook registration paths), 22 (shellcheck), 27
  (subject-resolution declaration), and 29 (test-root resolution)
- `bash .claude/scripts/tests/run-all.sh` exits 0
- `bash .claude/scripts/check-deploy-freshness.sh` reports the deployed tree current

---

## Testing & Validation

- [ ] Regenerate fires on `all_terminal` (Phase 4 Case A) and on a partial exit (Case B), in
      single-task and batch runs alike — the latter needs no separate axis, since the four-move
      loop has no separate single-task code path
- [ ] The `absent`/`unknown` degrade never writes `specs/ROADMAP.md` and fires all three
      durable surfaces (Case C)
- [ ] A second run with no intervening state change is a no-op (Case D)
- [ ] The pending marker is written on a real run and never under `--dry-run` (Case E)
- [ ] The backstop blocks only its own session, respects the continuation cap, and escapes on
      `stop_hook_active`
- [ ] Exactly one executable copy of the step exists: no `bash` code block for the regenerate
      survives in `conclusion-stage.md`
- [ ] The complete 29-gate set and `tests/run-all.sh` pass against the deployed tree

## Artifacts & Outputs

- `scripts/orchestrate-conclusion-roadmap.sh` — the single executable copy of the step
- `hooks/orchestrate-conclusion-backstop.sh` — the `Stop`-event backstop
- Two new test suites plus their `suite-classification.data` rows
- Six updated prose surfaces (`SKILL.md`, `orchestrate-state-machine.md`,
  `conclusion-stage.md`, `roadmap-update.md`, `postflight-tool-restrictions.md`,
  `orchestrate-batch-results-template.md`)
- `manifest.json` and `root-files/settings.json` declarations
- A redeployed `.claude/**` tree

## Rollback/Contingency

Every phase commits separately and scoped, so any single phase reverts by its own commit without
disturbing the others. The new script and hook are purely additive — if the backstop proves to
misfire in practice, removing its one `Stop` registration line from `root-files/settings.json`
and redeploying disables it while leaving GOAL (1)'s unconditional regenerate (the load-bearing
guarantee) fully intact. If the emission reorder proves to break the report's rendering, Phase
2's SKILL.md hunk reverts independently of Phase 1's script, which does not depend on it. Before
any rollback that would discard uncommitted work, take a checkpoint with
`git-snapshot.sh 634 --no-revert`.
