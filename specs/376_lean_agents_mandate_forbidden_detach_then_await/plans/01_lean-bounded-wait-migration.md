# Implementation Plan: Task #376

- **Task**: 376 - Lean implementation agents mandate the detach-then-await-notification path core forbids, stranding dispatches mid-phase
- **Status**: [NOT STARTED]
- **Effort**: 7.5 hours
- **Dependencies**: None (393 is already completed; no edge on the adjacent subagent-wait task, per the task's own SCOPE DECISION)
- **Research Inputs**: specs/376_lean_agents_mandate_forbidden_detach_then_await/reports/01_detach-then-await-contradiction.md
- **Artifacts**: plans/01_lean-bounded-wait-migration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The lean extension tells a dispatched agent to background a `lake build` with the harness's own
`Bash(run_in_background: true)` and then end its turn waiting for a completion notification —
the exact shape `core/agents/general-implementation-agent.md` forbids, and the shape that
stranded a measured implement dispatch mid-phase. This plan keeps lean's livelock protection
(detachment plus the build guard) and replaces only the **wait step** with
`bounded-build-waiter.md`'s single-Bash-call idiom: a shell-level detach, a captured `pid`, a
`kill -0` liveness loop under an outer `timeout`, inside one Bash call that does not return
control until the wait resolves — and, for a build that cannot fit one call, a *sequence* of
bounded calls, each of which returns control, so no turn ever ends mid-wait.

The fix starts at `extensions/lean/context/project/lean4/operations/long-builds.md`, not at the
agent files. That anchor is self-contradictory (its "Obligation 1: detach" and "Completion
discipline" sections mandate the forbidden shape as canonical while its own "Blocking on a
detached build" section points at the correct one), and both agent files are faithfully copying
one half of it. Done is: every lean contract site prescribes the bounded idiom, the two lean
implementation agents carry core's canonical bullet pair, `lint-agent-contracts.sh` Check K's
time-boxed exclusion for those two files is discharged and the lint evaluates them on merit, the
guard invocation under the new idiom is shown working against a replayed fixture, the deploy tree
is regenerated, and a named successor task carries the cross-extension duplication question
forward.

### Research Integration

The research report is integrated as follows, and its findings are treated as established rather
than re-derived:

- **Root cause relocated** (Finding 3): `long-builds.md` is the primary fix site, not a
  "possibly" touched file. Phase 2 owns it and precedes every propagation phase.
- **`lake-build-guard.sh` needs no change** (Finding 4): its `build` subcommand already blocks
  synchronously in the invoking shell and its own header already documents the
  `kill -0 "$holder_pid"` idiom. The "ALSO SETTLE" question about a blocking foreground mode is
  answered *yes, it already has one* — the detachment is introduced one layer up, by prose
  wrapping an already-blocking call in a harness-level background call. The script is
  deliberately **excluded from `file_scope`**.
- **The stale-deployed-tree question is already answered** (Finding 6): the contradictory wording
  was present in the last source-store commit before the incident date, so a redeploy alone would
  not have prevented the incident. Phase 6 records that answer; it does not re-investigate it.
- **Acceptance is mechanical** (Finding 1 / Recommendation 4): `lint-agent-contracts.sh` Check K
  carries a written, time-boxed removal condition naming exactly this work. Discharging it — both
  lean paths dropped from `CHECK_K_EXCLUDED_RELATIVE_PATHS`, both files then evaluated and
  PASSing on their own merits with 0 FAILs overall — is the acceptance criterion's required
  demonstration "against a real artifact".
- **The two lean research agents are clean today** (Finding 5) but carry the same imprecise
  `run_in_background: true` phrasing. Phase 4 aligns their wording; this is consistency work, not
  defect repair, and the plan says so rather than overstating it.
- **The cross-extension picture is calmer than the task description assumed** (Finding 7): the 14
  other in-scope implementation agents already carry the correct canonical bullet pair and
  currently PASS both Check H and Check K. Phase 6's successor task inherits that corrected
  framing (a propagation-architecture question), not the "~18 files may each carry a divergent
  copy" framing, together with the reproduce commands.

### Prior Plan Reference

No prior plan. This is the task's first planning round.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context, so no ROADMAP.md was consulted and no
roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Remove every instruction in the lean extension that tells a dispatched agent to end its turn
  awaiting a harness completion notification for a local gate or build.
- Preserve lean's livelock protection: detachment is retained (shell-level), the build guard
  remains mandatory, and `--timeout 1800` stays an explicit lock-wait budget.
- Leave no lean agent unable to comply with core's stated preference: the two lean implementation
  agents carry core's canonical bounded-wait MUST / MUST NOT bullet pair verbatim, and
  `lean-implementation-agent.md`'s MUST NOT item forbidding a plain foreground `lake build` is
  reworded so it no longer bars the form core prefers when that form actually fits.
- State explicitly **which processes** the lean rule governs — `lake`-family invocations routed
  through `lake-build-guard.sh` — and point every other local gate, test, or probe script at
  core's own Local Long-Running Command Discipline, so the measured incident's over-generalization
  (a 25-probe shell sweep treated as if it were a `lake build`) cannot recur.
- Demonstrate the fix against real artifacts: a `lint-agent-contracts.sh` run with Check K's
  exclusion discharged, and a replayed `lake-build-guard.sh` invocation under the new idiom.
- Discharge the stale lint exclusions and the now-false exclusion rationales recorded in
  `bounded-build-waiter.md`.
- Create a named successor task for the cross-extension duplication/inheritance ruling, carrying
  this task's evidence forward.

**Non-Goals**:

- Fixing the other ~14 extensions' implementation agents. Explicitly out of scope per the task's
  SCOPE DECISION; the successor task owns it.
- Changing `lake-build-guard.sh`. It already supports the correct idiom (Finding 4).
- Re-testing whether lean's livelock rationale still holds at current timeouts. The task
  explicitly forbids resolving this by deletion without testing, and a real test needs a long
  Lean build this repository does not have. The rationale is **upheld as written**, and the fix is
  designed to preserve it; Phase 1 records this as an explicit non-test rather than implying the
  claim was verified.
- Widening `stall_suspected`'s trigger predicate, or proposing any orchestrator-side detector as
  part of this task (EXPLICIT NON-GOALS).
- Rewriting `skill-lake-repair`'s command-substitution repair loop. Its detachment carve-out stays;
  only the sentence describing the carve-out's mechanism is corrected.
- Declaring a dependency edge on the adjacent subagent-wait task.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A shell-backgrounded child does not survive past the Bash call that launched it, breaking the multi-call wait sequence this plan prescribes for builds over the per-call ceiling | H | M | Phase 1 probes this empirically **before** any prose is written, and the prescription in Phase 2 is written to whatever Phase 1 measures (`nohup`/`setsid` plus a recorded PID file, or the guard's own `holder_pid`, if a bare `&` child does not survive) |
| Removing Check K's exclusion entries breaks `test-lint-agent-contracts-await-notification.sh`, whose cases (3a)/(3b) assert the exclusion is honoured for exactly those two lean paths | M | H | Known at plan time, not a discovery: Phase 5 retargets those cases to assert the **opposite** invariant — a formerly-excluded path carrying the violating shape now FAILs — which is precisely what the removal condition exists to guarantee |
| Adding the two lean agents to Check H's in-scope array before their bullet pair lands would turn Gate 6 red | M | L | Ordering invariant, stated in Phase 3 and Phase 5: the bullet pair lands in the agent files first (Phase 3), the array entry lands after (Phase 5). Likewise Check K's exclusion is removed only after the violating shape is gone. No red window exists at any phase boundary |
| Concurrent sibling dispatch (task 395) is editing `core/scripts/orchestrate-cycle-postflight.sh`, its test, and `core/context/standards/git-staging-scope.md` on this same working tree | M | M | No overlap with this task's `file_scope`. Per the dispatch's territory note: re-read every file immediately before editing, stage only this task's own explicit file list, never a directory or glob add, never `git-snapshot.sh` in reverting mode, and stop and report any foreign commit or build rather than dismissing it |
| A full `verify-deploy.sh` run carries pre-existing failures unrelated to this task, making Phase 6's gate reading ambiguous | M | M | Phase 1 captures the Gate 6 lint baseline (expected: 0 FAILs, ~13 warnings); Phase 6 captures a full-gate baseline before its own edits land if any gate is red, and reports deltas against it rather than absolute counts |
| Wording changes to `bounded-build-waiter.md`'s fenced "Copy this exact text" block would force a re-propagation pass across 14 other agent files | H | L | The bullet pair's text is **not** edited by this task. Only the two prose records naming lean as an exclusion change (Classification Rule, Forbidden-Shape Lint Anchor). Phase 5 verifies the fenced block is byte-identical before and after |
| A task-number reference leaks into a file under `agent-system/**` | M | M | `.claude/rules/no-task-references-in-deliverables.md` applies; Gate 4 (task-reference lint) is in every phase's covering check, and the successor task's evidence is recorded by reproduce-command and file path, never by task number |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Measure the Idiom Before Prescribing It [NOT STARTED]

**Goal**: Determine empirically what the corrected lean invocation shape must be, so Phase 2
writes a prescription that is known to work rather than one transcribed from a pattern document.
Produce the "replayed gate invocation" evidence the acceptance criterion requires, and capture
the Gate 6 baseline.

**Tasks**:

- [ ] Capture the Gate 6 baseline: `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`,
      recording the passed/warning/failed counts and confirming Check K currently *skips* both
      lean implementation agents and *PASSes* both lean research agents on merit.
- [ ] **Probe A — child survival across Bash calls.** In the scratch directory, launch
      `sleep 90 >log 2>&1 & echo $! > pidfile` in one Bash call, then in a *separate* Bash call
      test `kill -0 "$(cat pidfile)"`. Record whether a bare `&` child survives the launching
      call's exit. If it does not, repeat with `nohup`/`setsid` and record which form does.
- [ ] **Probe B — the single-call bounded wait returns control.** In one Bash call, run the
      canonical idiom (`cmd >log 2>&1 & pid=$!` then
      `timeout N bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 2; done' _ "$pid"`) against a
      writer that outlives the inner `timeout`, and confirm the call returns with `exit 124`
      rather than hanging or being auto-backgrounded. Repeat with a writer that finishes first and
      confirm a clean return plus a correctly read exit status.
- [ ] **Probe C — replayed guard invocation.** Build the heredoc fake-`lake` fixture that
      `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` already uses
      (`build_fixture()`: a scratch project root with a `bin/lake` stub driven by `FAKE_LAKE_SLEEP`,
      `FAKE_LAKE_EXIT`, `FAKE_LAKE_OUT`/`ERR`). Run
      `bash agent-system/extensions/core/scripts/lake-build-guard.sh build --timeout 1800 -- build`
      against it under the Phase-1-confirmed idiom, with `FAKE_LAKE_SLEEP` long enough to exercise
      the liveness loop. Confirm: the single Bash call returns control, the guard's exit code is
      captured un-piped (`... > <log> 2>&1; GUARD_EXIT=$?`), and the verdict is readable from the
      captured streams.
- [ ] Record, in the task's own notes under `specs/376_.../`, the explicit non-test statement:
      lean's livelock rationale (a killed build caches no `.olean`, so retries restart at the same
      module) is **upheld as written and not re-tested here** — no long Lean build exists in this
      repository to test it against — and the fix is therefore designed to preserve detachment
      rather than remove it.
- [ ] Record the probe transcripts verbatim; Phase 6's summary cites them as the acceptance
      evidence.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: This phase touches no source-store file at all — its only writes are a
scratch fixture and notes under `specs/**`, the `__FULL_SWEEP__` sub-case (a) in which the honest
covering check is the `prose` row's diff read-through, and the probe transcripts are themselves
the phase's verification.

**Scope Hypothesis**: This phase assumes the `test-lake-build-guard.sh` fake-`lake` fixture can be
reproduced standalone outside that suite's own harness. Confirm by reading
`build_fixture()` in that file and reproducing it in the scratch directory before relying on it;
if it cannot be reproduced standalone, fall back to driving `lake-build-guard.sh` against a
`sleep`-based stub and record that substitution in the transcript.

**Files to modify**:

- None under `agent-system/**`. Scratch fixture under the session scratchpad; probe transcripts
  recorded under `specs/376_lean_agents_mandate_forbidden_detach_then_await/`.

**Verification**:

- Probe A yields a definite answer (which backgrounding form survives a Bash call boundary),
  recorded verbatim.
- Probe B shows a single bounded call returning control in both the timeout and the
  completes-first case.
- Probe C shows a guard invocation completing under the new idiom with its exit code captured
  un-piped.
- The Gate 6 baseline counts are recorded.

---

### Phase 2: Resolve `long-builds.md`'s Self-Contradiction [NOT STARTED]

**Goal**: Make the lean extension's root anchor prescribe exactly one shape — the bounded
single-call wait — so no reader of this file alone can re-derive the forbidden
detach-then-await-notification path, and state explicitly which processes the mandate governs.

**Tasks**:

- [ ] Re-read `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` in
      full immediately before editing (concurrency discipline).
- [ ] Rewrite **"## Obligation 1: detach"** so "detach" means shell-level backgrounding in the
      form Phase 1 confirmed survives a call boundary — never the harness's
      `Bash(run_in_background: true)` tool parameter. Remove the "re-invokes the agent with a
      completion notification" sentence, which describes the forbidden mechanism as the benefit.
- [ ] Rewrite **"## The canonical invocation"** so the shown example is the complete idiom
      (captured `pid`, `kill -0` liveness loop, outer `timeout`, guard call inside) rather than a
      bare guard command annotated "run under `Bash(run_in_background: true)`". Keep the
      `--timeout 1800` lock-wait-budget paragraph unchanged — it is correct and independent.
- [ ] Add, to the same section, the **preference order** core states: a plain foreground
      `timeout N <guard call>` with the Bash tool's own `timeout` parameter raised to `600000`
      whenever the build plausibly fits that ceiling; the detach-plus-bounded-waiter shape only
      when it does not; and, for a build expected to exceed the ceiling outright, the *sequence*
      of separate bounded calls described in `bounded-build-waiter.md`'s "Sizing a Wait Near the
      Per-Call Ceiling" — each call gated on `kill -0` against the recorded PID, each returning
      control to the agent, never one unbounded wait and never a turn that ends mid-wait.
- [ ] Rewrite **"## Completion discipline"**: keep the fire-and-forget prohibition (it is correct
      and still needed), and replace "until the harness's own completion notification for that
      background job has arrived" with the bounded-waiter resolution — the dispatch blocks in its
      own bounded calls until liveness ends and the verdict is read, and **never** ends the turn
      on an unresolved local background wait. Cross-reference
      `core/agents/general-implementation-agent.md`'s Local Long-Running Command Discipline and
      `core/context/patterns/bounded-build-waiter.md` by path.
- [ ] Reconcile **"## Blocking on a detached build"** with the rewritten sections so the file
      states one position, and fold it in rather than leaving two sections that could again be
      read as alternatives.
- [ ] Add an explicit **scope-of-governed-processes** statement (the task's own "ALSO SETTLE"
      item): this anchor governs `lake`-family invocations routed through `lake-build-guard.sh`
      and nothing else. Any other long local gate, test, probe sweep, or script follows core's
      Local Long-Running Command Discipline, which permits the plain foreground form and forbids
      the harness-level background-then-await path outright. Say this positively, so an agent
      facing a 25-probe shell sweep cannot read the lake-specific detach mandate as covering it.
- [ ] Add one sentence recording the settled ruling on the guard: `lake-build-guard.sh build`
      already blocks synchronously in the invoking shell and already documents the
      `kill -0 "$holder_pid"` liveness idiom, so no new "blocking foreground mode" is needed —
      the correct idiom already is the path of least resistance at the script layer.
- [ ] Update **"## Known gaps"**: the `mcp__lean-lsp__lean_build` bullet's reasoning
      ("`Bash(run_in_background: true)` cannot wrap an MCP tool call") must be restated against
      the new idiom; the `skill-lake-repair` bullet's carve-out reason likewise (Phase 4 updates
      the skill's own copy of that sentence).
- [ ] Update **"### The liveness caveat"**, whose closing sentences reference waiting on "its
      completion notification" as the thing the passive checks are not a substitute for.
- [ ] Sweep the whole file for any remaining `run_in_background` occurrence and confirm each
      surviving one sits inside a prohibitive sentence, never an instruction.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: A pure-guidance markdown edit in the source store with no mapped suite
(`__FULL_SWEEP__` sub-case (b)), so the covering check is the explicit-TARGET gate subset
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`,
run together with a diff read-through confirming every changed hunk is prose.

**Files to modify**:

- `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` - resolve the
  self-contradiction; prescribe the bounded idiom and the preference order; state which processes
  the mandate governs; record the guard ruling.

**Verification**:

- `grep -n 'run_in_background' agent-system/extensions/lean/context/project/lean4/operations/long-builds.md`
  returns only occurrences inside prohibitive sentences (each one read and confirmed, not counted).
- `grep -n 'completion notification' <same file>` returns nothing, or only occurrences inside a
  prohibitive sentence.
- Gate subset above exits 0.
- A read-through confirms the file states one position on blocking, with no section left offering
  the forbidden shape as an alternative.

---

### Phase 3: Propagate to the Two Lean Implementation Agents [NOT STARTED]

**Goal**: Bring `lean-implementation-agent.md` and `lean-implementation-hard-agent.md` into
agreement with the corrected anchor at every site, and give each the canonical bounded-wait
bullet pair so neither is left unable to comply with core's preference.

**Tasks**:

- [ ] Re-read both files immediately before editing (concurrency discipline).
- [ ] `lean-implementation-agent.md` — rewrite each site:
      `:29-31` (Context References description of `long-builds.md`), `:51` (blocked-tool
      alternatives table), `:70-71` (Bash tool scope), `:335-349` (the phase-end build step
      carrying the literal "wait for the harness's completion notification" instruction),
      `:741-744` (MUST item 7/8 scoped-build wording), `:771-772` (MUST NOT item 13).
- [ ] Reword `lean-implementation-agent.md`'s MUST NOT item 13 so it forbids what is actually
      unsafe — an **unbounded** foreground `lake build` with no `timeout` and no raised Bash tool
      ceiling — rather than the plain foreground form outright. Keep the livelock rationale
      sentence; it is the reason the bounded form is required, not a reason to bar foreground
      entirely. (Note for the implementer: this MUST NOT list contains two items numbered `13`;
      renumbering is **out of scope** — do not renumber surrounding bullets while editing.)
- [ ] `lean-implementation-hard-agent.md` — rewrite each site: `:46-47`, `:56`, `:69-70`,
      `:241-250` (carries the literal phrase), `:450-460` (carries the literal phrase), `:782-783`,
      `:806-807`.
- [ ] Add the canonical bounded-wait **MUST** and **MUST NOT** bullets to both files'
      `## Critical Requirements` lists, copied **verbatim and each on one physical line** from
      `agent-system/extensions/core/context/patterns/bounded-build-waiter.md`'s "Copy this exact
      text" fenced block, as the next sequential item of each list. Do not reword them, do not
      reword any surrounding bullet, and do not edit the fenced source block.
- [ ] Add to both files an explicit cross-reference for **non-`lake` local gates**: any long local
      gate, test, or probe script that is not a `lake`-family invocation through
      `lake-build-guard.sh` follows `core/agents/general-implementation-agent.md`'s Local
      Long-Running Command Discipline, not this extension's build mandate. This is the direct
      textual counter to the measured incident's over-generalization.
- [ ] Confirm no task-number reference is introduced into either file.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: Both edited files are agent contracts whose covering check is Gate 6's
own lint, so
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4,6 /home/benjamin/.config/nvim`
exercises exactly the checks these two files are subject to, with no broader surface reachable
from a markdown agent definition.

**Scope Hypothesis**: The site inventory above (6 sites in `lean-implementation-agent.md`,
7 in `lean-implementation-hard-agent.md`) is taken from the research report's line numbers and
may have shifted. Confirm at implementation time by re-running
`grep -n 'run_in_background\|completion notification\|detached' <each file>` and treating the grep
output — not these line numbers — as the work list.

**Ordering invariant**: the bullet pair lands here, in the agent files; the matching
`BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS` entries land later, in Phase 5. Reversing that order turns
Gate 6 red between the two phases.

**Files to modify**:

- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - replace every
  harness-background-then-await instruction with the bounded idiom; reword MUST NOT 13; add the
  canonical bullet pair and the non-`lake`-gate cross-reference.
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - the same, at its own
  site inventory.

**Verification**:

- `grep -n 'completion notification' <both files>` returns nothing outside a prohibitive sentence.
- Every surviving `run_in_background` occurrence in both files is read and confirmed to sit inside
  a prohibition.
- Both canonical bullets are present verbatim:
  `grep -cF 'canonical idiom VERBATIM' <file>` and
  `grep -cF 'arm a \`Monitor\` to watch a local verification' <file>` each return 1.
- The gate subset above exits 0 (Check K still skips these two files at this phase — the exclusion
  is discharged in Phase 5 — so Gate 6 must be green here without relying on that discharge).

---

### Phase 4: Align the Remaining Lean Contract Sites [NOT STARTED]

**Goal**: Bring the rest of the lean extension's contract surface into agreement with the
corrected anchor, so no site is left prescribing the old shape by analogy.

**Tasks**:

- [ ] Re-read each file immediately before editing.
- [ ] `agent-system/extensions/lean/rules/lean4.md` — update `:48-52` (the phase-end and final
      verification steps) and `:62-67` ("## Build Commands") to the corrected invocation shape and
      preference order. This file is auto-applied to `**/*.lean` and so is a high-traffic site.
- [ ] `agent-system/extensions/lean/agents/lean-research-agent.md` — update `:44`, `:63-64`, and
      `:196`. These are consistency edits: the file carries no wait-for-notification instruction
      and already PASSes Check K on merit (Finding 5). Say so in the commit message rather than
      framing it as a defect fix.
- [ ] `agent-system/extensions/lean/agents/lean-research-hard-agent.md` — update `:54`, `:67-68`,
      same framing.
- [ ] `agent-system/extensions/lean/skills/skill-lake-repair/SKILL.md` — update the `:65-72`
      decision note so the carve-out is stated against the corrected idiom. The carve-out itself
      **stands**: the repair loop's `build_output=$(...)` command substitution is incompatible with
      a detached writer regardless of which backgrounding mechanism is used, because a detached
      call's stdout does not reach a shell variable. Keep the residual-exposure sentence; correct
      only the mechanism named.
- [ ] Confirm no task-number reference is introduced into any of the four files.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: Four pure-guidance markdown edits with no mapped suite
(`__FULL_SWEEP__` sub-case (b)); the covering check is
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4,6 /home/benjamin/.config/nvim`
(gate 6 included because two of the four files are agent contracts), plus a diff read-through.

**Scope Hypothesis**: Exactly four files are asserted to carry the remaining lean-side
occurrences. Confirm at implementation time with
`grep -rn 'run_in_background' agent-system/extensions/lean/` and treat any file that appears
beyond this list as in scope for the same alignment (and record it as a deviation).

**Files to modify**:

- `agent-system/extensions/lean/rules/lean4.md` - corrected invocation shape in the workflow steps
  and the Build Commands section.
- `agent-system/extensions/lean/agents/lean-research-agent.md` - wording alignment (3 sites).
- `agent-system/extensions/lean/agents/lean-research-hard-agent.md` - wording alignment (2 sites).
- `agent-system/extensions/lean/skills/skill-lake-repair/SKILL.md` - carve-out note restated
  against the corrected idiom; carve-out itself retained.

**Verification**:

- `grep -rn 'run_in_background' agent-system/extensions/lean/` returns only occurrences read and
  confirmed to sit inside prohibitive or carve-out prose.
- The gate subset above exits 0.

---

### Phase 5: Discharge the Lint Exclusions and Their Recorded Rationales [NOT STARTED]

**Goal**: Turn the fix into a standing mechanical guarantee: Check K evaluates both lean
implementation agents on their own merits, Check H requires their bullet pair, and no file still
records a now-false rationale for excluding them.

**Tasks**:

- [ ] Re-read each file immediately before editing (this phase edits core files on a tree a
      sibling task is also writing to — confirm via `git log`/`git status` that any unexpected
      modification is not this task's own before proceeding, and stop and report if it is foreign).
- [ ] `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — remove both lean paths
      from `CHECK_K_EXCLUDED_RELATIVE_PATHS` (`:947-950`), discharging the removal condition
      recorded at `:941-946`. Rewrite the surrounding comment block so it records that the
      exclusion was time-boxed and has been discharged — stating the current state, not a change
      history — and keep the `is_excluded_from_await_notification` helper and the (now empty) array
      in place so a future, differently-reasoned exclusion has a home.
- [ ] Same file — add both lean implementation-agent paths to
      `BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS` (`:669-684`) in sorted position, and rewrite comment
      block (b) at `:655-662`: the recorded reason for excluding them ("a different legitimate
      mechanism") is no longer true once they use the canonical idiom, so the only remaining
      Check H exclusion is `core/agents/general-implementation-agent.md`, the contract's own
      authoritative home.
- [ ] `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` — update the two
      prose records that name the lean files as exclusions: the **Classification Rule**
      subsection's three-file exclusion list (now one file), and the **Forbidden-Shape Lint
      Anchor**'s "Curated exclusions, not a widened predicate" paragraph. State the current
      position directly; do not narrate the supersession. **Do not touch the fenced "Copy this
      exact text" block or the four Check K anchor lines** — both are read at runtime by the lint
      and by 14 other agent files' literal copies.
- [ ] `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-await-notification.sh`
      — retarget cases (3a)/(3b). The fixture that writes a violating
      `lean/agents/lean-implementation-agent.md` into the synthetic root stays; what changes is the
      assertion: that path must now produce a Check K **FAIL**, not a recorded-exclusion skip.
      This is the removal condition's own stated purpose — "a stale exclusion remaining after its
      own migration would mask a reintroduced violation behind a silent skip instead of a FAIL" —
      turned into a regression test. Update the file header comment (`:16`) to match.
- [ ] Run the retargeted suite and the full agent-contracts lint; compare against Phase 1's
      baseline counts.

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Verification Tier**: local

**Tier Justification**: The edited lint script's own behaviour is covered by exactly one suite,
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts-await-notification.sh`,
run with
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 6,22 /home/benjamin/.config/nvim`
for the lint's own output and its shellcheck surface.

**Scope Hypothesis**: Exactly two array entries (Check K) and two prose records (Classification
Rule, Forbidden-Shape Lint Anchor) are asserted to reference the lean files. Confirm with
`grep -rn 'lean-implementation' agent-system/extensions/core/` before editing, and treat any
additional site found as part of this phase.

**Files to modify**:

- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - drop both Check K
  exclusions and rewrite their comment block; add both paths to Check H's in-scope array and
  rewrite its exclusion rationale.
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` - update the
  Classification Rule exclusion list and the Forbidden-Shape Lint Anchor's curated-exclusion
  paragraph; fenced blocks untouched.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-await-notification.sh` -
  retarget cases (3a)/(3b) to assert a FAIL on a formerly-excluded path carrying the violating
  shape; update the header comment.

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-await-notification.sh`
  exits 0 with every case passing.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` reports
  **0 FAILs**, and its Check K section now carries an evaluated PASS line for each of
  `lean/agents/lean-implementation-agent.md` and `lean/agents/lean-implementation-hard-agent.md`
  — not a "recorded exclusion ... skipped" info line. This output is the acceptance criterion's
  "fix demonstrated against a real artifact" evidence and is quoted in the summary.
- Check H reports a PASS for both newly in-scope lean paths.
- `git diff` on `bounded-build-waiter.md` shows no change inside any fenced code block
  (verify by diffing the extracted fenced blocks before and after, not by eye).
- The gate subset above exits 0.

---

### Phase 6: Redeploy, Successor Task, and Wrap-Up [NOT STARTED]

**Goal**: Land the change in the deployed tree, answer the stale-tree question on the record,
create the named successor task with its evidence, and close the task against the full gate set.

**Tasks**:

- [ ] Run the full gate set against the source store:
      `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim`.
      Read its exit status directly; if any gate is red, determine from Phase 1's baseline and
      `git stash list`/`git log` whether it is pre-existing or this task's own, and report rather
      than assume.
- [ ] Redeploy: `bash agent-system/extensions/core/scripts/deploy-headless.sh` (default
      non-destructive resync), then
      `bash agent-system/extensions/core/scripts/check-deploy-freshness.sh` to confirm the
      deployed `core` and `lean` trees are current. `.claude/` is gitignored in this repository,
      so the redeploy produces no commit churn.
- [ ] Record the **stale-tree answer** in the summary, from research Finding 6 rather than fresh
      investigation: the contradictory wording was already present in the last source-store commit
      preceding the measured incident (`4c90b876e`, 2026-10-08) at the same line numbers, so a
      redeploy alone would not have prevented the incident — the defect was in the authoritative
      source, not only in a lagging deployed copy. The redeploy is still required, because the fix
      itself must reach the deployed tree.
- [ ] Create the **named successor task** for the cross-extension duplication/inheritance ruling,
      following `commands/task.md`'s Create Task mode (read `next_project_number`, write via
      `state-write.sh` with `--regen-todo`, then `manage-topics.sh set`; topic
      `core-agent-system`, `task_type: meta`, `dependencies: []`). Its description MUST carry
      forward, verbatim and ready to use:
      - the corrected framing — 14 in-scope implementation agents already carry the correct
        canonical bullet pair and currently PASS both Check H and Check K, so the question is
        **propagation architecture** (one canonical source versus 14 literal copies kept in sync by
        a lint), not an unfixed defect;
      - the reproduce commands, copied from `lint-agent-contracts.sh`'s own Check H comment block
        (c) and Check K comment block, so the successor never re-derives them;
      - the standing constraint that an `@`-reference inside an agent body does not resolve when a
        subagent is spawned, which is why a literal copy exists in each file today
        (`bounded-build-waiter.md`'s "Generated-Copy Source, Not an `@`-Import");
      - the two decisions this task made that bind it: the lean implementation agents now carry the
        canonical bullet pair and are in Check H's in-scope list, and Check K's curated exclusion
        list is now empty.
- [ ] Write the implementation summary to
      `specs/376_lean_agents_mandate_forbidden_detach_then_await/summaries/01_lean-bounded-wait-migration-summary.md`,
      citing the Phase 1 probe transcripts and the Phase 5 lint output as the acceptance evidence,
      and naming the successor task number.
- [ ] Verify each ACCEPTANCE bullet from the task description one by one against concrete
      evidence, and state in the summary which evidence discharges which bullet.

**Timing**: 1.25 hours

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:

- `specs/376_lean_agents_mandate_forbidden_detach_then_await/summaries/01_lean-bounded-wait-migration-summary.md` - new
- `specs/state.json` (via `state-write.sh`) and `specs/TODO.md` (via `--regen-todo`) - successor
  task row.

**Verification**:

- `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim` — the
  complete gate set, source-store target explicit — exits 0, or exits with only failures shown to
  be pre-existing against the Phase 1 baseline, with its exit status checked directly rather than
  inferred from stdout.
- `bash agent-system/extensions/core/scripts/check-deploy-freshness.sh` reports `core` and `lean`
  current.
- `grep -rn 'completion notification' agent-system/extensions/lean/` returns nothing outside a
  prohibitive sentence.
- The successor task appears in `specs/state.json` and in the regenerated `specs/TODO.md`, and its
  description contains the reproduce commands.
- `bash .claude/scripts/validate-artifact.sh <summary path> summary` passes.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-await-notification.sh`
      exits 0, with the retargeted cases asserting a FAIL (not a skip) on a formerly-excluded path
      carrying the violating shape.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` reports 0
      FAILs, with Check K evaluating — and PASSing — both lean implementation agents on merit, and
      Check H PASSing them for bullet-pair presence.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` exits 0 (the guard
      is unchanged; this confirms Phase 1's fixture work left nothing behind).
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim`
      exits 0, or only with failures demonstrated pre-existing against the Phase 1 baseline.
- [ ] Phase 1's probe transcripts show a bounded single Bash call returning control in both the
      completes-first and the inner-timeout cases, and a `lake-build-guard.sh` invocation
      completing under the new idiom with its exit code captured un-piped.
- [ ] No file under `agent-system/**` gains a task-number reference (Gate 4).

## Artifacts & Outputs

- `specs/376_lean_agents_mandate_forbidden_detach_then_await/plans/01_lean-bounded-wait-migration.md`
  (this plan).
- `specs/376_lean_agents_mandate_forbidden_detach_then_await/summaries/01_lean-bounded-wait-migration-summary.md`.
- Phase 1 probe transcripts recorded under the task directory.
- Edited source-store files: the ten paths in this task's `file_scope`.
- A regenerated `.claude/` deploy tree (gitignored; no commit).
- One new successor task row in `specs/state.json` / `specs/TODO.md`.

## Rollback/Contingency

Each phase commits separately with an explicit file list (never a directory or glob pathspec), so
reverting is `git revert` of the offending phase commit — no working-tree destruction is involved
and no snapshot is required for that path.

If a phase must be abandoned mid-edit with uncommitted changes present, take a **non-reverting**
checkpoint first — `bash .claude/scripts/git-snapshot.sh 376 --no-revert` — which is durable
without touching the working tree; the reverting default form belongs only to a genuine rollback,
per `context/contracts/recovery.md`'s rollback rung, and must not be emitted as a routine
checkpoint. A sibling task is writing to this same tree, which is an additional reason never to
revert the tree wholesale here.

The highest-risk single step is Phase 5's exclusion removal, because it can turn Gate 6 red for
the whole repository. Its contingency is ordered and local: if the lint FAILs after the exclusions
are dropped, the correct response is to finish the Phase 3 propagation that the FAIL is correctly
reporting as incomplete — not to restore the exclusion. Restoring it is permitted only as a
deliberate, recorded stop-the-line decision, and then the removal condition must be re-recorded in
the lint's own comment block with the new reason.
