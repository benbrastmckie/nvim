# Implementation Plan: Lean language server readiness preflight

- **Task**: 321 - Lean language server readiness preflight
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None blocking. Cross-references open task 268 (build-cache half) — no shared file scope.
- **Research Inputs**: specs/321_lean_language_server_readiness_preflight/reports/01_lean-lsp-readiness-probe.md
- **Artifacts**: plans/01_lean-lsp-readiness-dispatch-tier.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Extend the existing WARN-only preflight probe `lean-mcp-preflight-check.sh` so it reports
language-server **reachability** (not merely MCP registration), and thread that finding into the
dispatch file every `/orchestrate` dispatch already reads — so an agent working in a Lean project
knows its evidence tier before it issues its first `lean_local_search` call. The probe's
always-exit-0, never-block contract and its sub-100ms budget are preserved exactly; the new
reachability check is additive, gated on lakefile directory detection rather than `task_type`, and
degrades to an explicit `unknown` tier (never a silent `reachable`) whenever introspection fails.
Done when a dispatch built in a Lean project with no running `lean-lsp-mcp` server carries an
explicit degraded-tier statement in its dispatch file, a dispatch in a non-Lean project is
byte-identical to one built before this change, and the full gate set is green after redeploy.

### Research Integration

The research report settled four things this plan builds on directly:

- **The call site matters more than the probe logic.** `/orchestrate` resolves agents via
  `command-route-agent.sh` and never executes the four lean `SKILL.md` bodies, so their Stage 2
  inline call to the probe is unreachable on the dominant path. The manifest `hooks.preflight`
  mechanism that *does* fire resolves its owning extension by `task_type` — and the motivating
  incident's `task_type` was `formal`, whose manifest declares no `hooks` key. Therefore the fix
  must be an unconditional call from `orchestrate-build-dispatch.sh`, gated on lakefile detection,
  never a `hooks.preflight` registration (Findings 1-3).
- **The reachability probe is cheap and precedented**: one `ps -eo pid,ppid,comm,args --no-headers`
  snapshot, an `args` substring match on `lean-lsp-mcp` (`comm` is useless — `uvx` does not
  exec-replace, so both the launcher and a concurrent `mcp-nixos` server show `comm=uv`), then
  `/proc/<pid>/environ`'s `LEAN_PROJECT_PATH` for an exact project-identity cross-check. Measured
  ~35ms, no server spawn, no network call (Finding 5).
- **`deploy_freshness_context` is the injection template** — a conditionally-computed, tagged
  context block appended only when non-empty, in the same file, already proven byte-identical
  when inactive (Finding 3).
- **`.olean` staleness is excluded.** It cannot be made sub-100ms at real-project scale and is a
  build-cache-correctness concern, not a dispatch-readiness one; the research also showed it is
  only a plausible, unconfirmed relative of task 268's current hardlink-replay theory, not the
  same mechanism (Finding 7). No `proposed_file_scope` was claimed for it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consulted.

### Territory

Concurrent siblings this cycle are tasks 316 and 320. Neither claims any file in this plan's
scope: 316 owns `skill-orchestrate/SKILL.md`, `orchestrate-state-machine.md` and
`test-verify-deploy-context-budget.sh`; 320 owns six core scripts/docs around
`validate-return-meta.sh` and `orchestrate-cycle-postflight.sh`. This plan touches
`orchestrate-build-dispatch.sh` and `test-orchestrate-build-dispatch.sh` (core, unclaimed) plus
six lean-extension files. Re-read each file immediately before editing, stage only this task's
own hunks as an explicit file list, and never run `git-snapshot.sh` in its reverting default mode.

## Goals & Non-Goals

**Goals**:
- Report language-server **reachability** (`reachable` / `not_reachable` / `unknown`), distinct
  from the registration drift the probe already checks.
- Deliver that finding into the dispatch file, before the agent starts, on the `/orchestrate`
  path, for **every** `task_type` — including `formal`, the one that triggered the incident.
- Carry the `index: unavailable` / `warming` / `consulted` interpretation rule inline in the
  injected text, so the reader learns how to read a future tool result rather than only receiving
  a tier label.
- Preserve the probe's WARN-only, always-exit-0 contract and its sub-100ms budget unchanged.
- Keep every non-Lean dispatch file byte-identical to one built before this change.
- Close the parallel, smaller gap on the direct `/research|/plan|/implement` path.

**Non-Goals**:
- **`.olean` staleness detection** — excluded per research Finding 7 and its Decision; not in
  `file_scope`, no `proposed_file_scope` claimed.
- **`scripts/lake-build-guard.sh` and its test** — task 268's declared territory; untouched.
- **Relaying this run's stale-cache reproduction to task 268 as evidence** — recommended by
  research (Rec 5) but belongs to the orchestrator/user coordinating across the two tasks, not to
  an out-of-territory write from this task. Flagged here, deliberately not implemented.
- **Registering the probe as a manifest `hooks.preflight`** — research Finding 2 showed this
  mechanism structurally cannot reach a non-`lean4`-typed Lean project. Not attempted.
- **Generalizing the registered-vs-reachable technique to other per-project MCP servers**
  (`mcp-nixos` etc.) as executable code — named in the context doc as a concept only.
- **Probing server responsiveness.** A live process is a necessary, not sufficient, condition for
  reachability; this is stated in the injected text rather than probed.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `args` substring match on `lean-lsp-mcp` collides with an unrelated process (shell history replay, a `grep` for the string) | M | M | Exclude the probe's own PID/PPID row, and require an exact `/proc/<pid>/environ` `LEAN_PROJECT_PATH` match against the expected project path before reporting `reachable`. A bare argv match is never sufficient evidence on its own. |
| `/proc` is Linux-only; a macOS deploy would get `unknown` unconditionally | L | L | That is the decided, honest degrade path. `unknown` is the safe default and is never promoted to `reachable`; the limitation is recorded in the script header. |
| Reporting `reachable` for a live-but-hung server gives false confidence | M | L | The injected text states explicitly that a live process is necessary but not sufficient, and that an `index: unavailable` result still means degrade to the grep-sweep fallback regardless of the reported tier. |
| A new always-on call in `orchestrate-build-dispatch.sh` adds latency to every dispatch, including the 99% non-Lean case | M | L | The probe's own lakefile pre-check exits in ~6ms before any verifier or `ps` work; the reachability check runs only after registration is confirmed present. Phase 3 measures the non-Lean delta and records it. |
| Lean-specific prose leaking into a core script, violating that script's "TRANSPORT change only" header | M | M | The lean probe emits the **complete** block body; the core script only appends it verbatim when non-empty. Core carries zero Lean-specific text. |
| Non-Lean dispatch files stop being byte-identical, breaking an existing dispatch-file test | H | L | Emit no block at all for empty probe output, following the `memory_context`/`lit_context`/`deploy_freshness_context` precedent in the same file; Phase 4 pins the byte-identity case as a test. |
| A sibling task's in-flight edit to a core script is mistaken for a regression from this work | M | L | Neither sibling claims either core file in this scope; on an unexpected failure outside `file_scope`, check `git log` and report rather than "fixing" it. |
| `--dispatch-block` output drifts from the human-readable path, so the four existing call sites change behavior | M | L | New flag, not a changed default: the no-flag path stays byte-identical, pinned by the existing fixtures A-I plus a new explicit regression assertion in Phase 2. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 6 | -- |
| 2 | 2, 3, 5 | 1 |
| 3 | 4 | 3 |
| 4 | 7 | 2, 4, 5, 6 |

Phases within the same wave can execute in parallel.

### Phase 1: Add reachability detection and a `--dispatch-block` output mode to the probe [COMPLETED]

**Goal**: `lean-mcp-preflight-check.sh` can determine whether a `lean-lsp-mcp` server is actually
running for *this* project, and can emit a complete, ready-to-inject dispatch-file block — while
its existing no-flag behavior stays byte-identical.

**Tasks**:
- [x] Re-read `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh` in
      full immediately before editing (88 lines; sibling tasks do not claim it, but the re-read is
      the territory contract). *(completed)*
- [x] Add a `probe_reachability()` function: one atomic `ps -eo pid,ppid,comm,args --no-headers`
      snapshot; select rows whose `args` contains the literal `lean-lsp-mcp`; drop the row whose
      PID equals `$$` or whose PID equals `$PPID` (the self-match guard, modeled on
      `lake-build-guard.sh`'s `is_self_row` idiom); for each surviving candidate read
      `/proc/<pid>/environ` (NUL-delimited) for `LEAN_PROJECT_PATH` and compare it, after
      normalization, against the resolved project root. *(completed)*
- [x] Define the three-value result contract: `reachable` (an exact `LEAN_PROJECT_PATH` match),
      `not_reachable` (the snapshot succeeded and no candidate matched), `unknown` (`/proc` absent,
      `ps` failed, or every candidate's `environ` was unreadable). Never promote `unknown` or an
      argv-only match to `reachable`. *(completed)*
- [x] Add flag parsing for `--dispatch-block`. Keep the five ignored positional lifecycle-hook
      args accepted exactly as today, so the flag composes with the existing signature. *(completed)*
- [x] In `--dispatch-block` mode: print nothing and exit 0 when the lakefile pre-check fails (not a
      Lean project). Otherwise print a complete
      `<lean-readiness-context>` … `</lean-readiness-context>` block on stdout stating: the
      resolved project root; the registration result (reusing the existing verifier invocation, not
      a second one); the reachability tier; the `index: unavailable` / `warming` / `consulted`
      three-state interpretation rule, naming `consulted` as the only state in which an empty
      result is proof of absence; the explicit statement that a live process is necessary but not
      sufficient for reachability; and that Lean work without lean-lsp is an accepted degraded mode
      the agent should proceed in, announcing its evidence tier, not abort over. *(completed)*
- [x] Order the work so the reachability check runs only *after* registration is confirmed present,
      keeping the non-Lean (~6ms) and not-yet-registered (~20ms) exits unchanged. *(completed)*
- [x] Leave the no-flag path's output and exit behavior untouched, byte for byte. *(completed:
      verified via the full pre-existing 17-case fixture suite, all passing unchanged)*
- [x] Update the script's header block: the new flag, the new reachability semantics, the
      Linux-only `/proc` caveat and its `unknown` degrade, the self-match guard rationale, and a
      re-measured cost line for the new path. Keep the existing detection-lockstep note intact.
      *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase assumes the whole change fits in this one 88-line script with no
new helper file and no edit to `verify-lean-mcp.sh`. Confirm at implementation time by checking
that the registration result needed for the block is obtainable from the single existing
`$VERIFIER` invocation's exit code (0 / 2 / other) already captured in the script; if it is not,
state that and extend the script rather than silently adding a second verifier call or editing the
verifier.

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh` - add `probe_reachability()`,
  `--dispatch-block` mode, header documentation; no-flag path unchanged

**Verification**:
- `bash -n` parses clean; `shellcheck` (if available) reports no new findings.
- Run with no flag in a non-Lean directory: empty output, exit 0.
- Run with `--dispatch-block` in a non-Lean directory: empty output, exit 0.
- Run with `--dispatch-block` in a real Lean project: a well-formed block naming a tier from the
  three-value set.
- Time the non-Lean early exit and record the measured value; it must stay in the ~6ms band.

---

### Phase 2: Extend the probe's test suite with reachability-tier fixtures [COMPLETED]

**Goal**: the three reachability outcomes and the no-flag byte-identity guarantee are pinned by
fixtures, with a mutation check proving the new matching logic is actually exercised.

**Tasks**:
- [x] Re-read `test-lean-mcp-preflight-check.sh`'s harness helpers (`make_lean_project`,
      `deploy_real_verifier`, `write_project_claude_json`, `run_wrapper`) and extend the file's
      header fixture inventory with the new letters rather than rewriting it. *(completed)*
- [x] Add a fake-server fixture helper: a wrapper script whose own filename contains the literal
      substring `lean-lsp-mcp`, launched in the background with `LEAN_PROJECT_PATH` exported to the
      fixture repo's path and a long `sleep`, with its PID captured for cleanup in the existing
      `trap EXIT`. No real `uvx` or `lean-lsp-mcp` package dependency. *(completed: discovered and
      fixed two related bugs along the way, recorded in the Phase 2 progress file's approaches_tried: a command-substitution capture that hung on a backgrounded 300s sleep, and a lost array append from subshell scoping)*
- [x] Fixture J — `reachable`: registered project plus a running fake server whose
      `LEAN_PROJECT_PATH` matches. Assert the block reports `reachable`, exit 0. *(completed)*
- [x] Fixture K — `not_reachable`: registered project, no fake server running. Assert the block
      reports `not_reachable`, exit 0, and that the block text contains the
      `unavailable`/`warming`/`consulted` interpretation sentence. *(completed)*
- [x] Fixture L — wrong-project server: registered project plus a running fake server whose
      `LEAN_PROJECT_PATH` points at a *different* fixture repo. Assert `not_reachable`, not
      `reachable` — the anti-vacuous guard proving the `environ` cross-check is load-bearing rather
      than the argv match alone deciding the tier. *(completed)*
- [x] Fixture M — `--dispatch-block` outside a Lean project: byte-empty output, exit 0.
      *(completed)*
- [x] Fixture N — no-flag regression: assert the no-flag invocation's output on an existing drift
      fixture is unchanged, so the new flag provably did not alter the default path. *(completed)*
- [x] Mutation 3 (following the file's existing recorded-mutation discipline): a mutated copy of
      the probe whose `environ` cross-check is deleted (argv match alone decides the tier) must make
      fixture L report `reachable` where it previously reported `not_reachable`, while fixtures J
      and K stay unaffected — the targeted control. Record this in the header alongside Mutations 1
      and 2. *(completed: required an isolated `ps` stub to keep the K control deterministic --
      recorded in the Phase 2 progress file's approaches_tried)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase assumes five new fixtures (J-N) plus one mutation suffice, and
that a background `sleep` under a renamed wrapper is enough to make the `ps`+`/proc` path fire
without the real MCP package. Confirm by observing fixture J actually reach `reachable` before
counting the phase green; if a fake process cannot be made visible to the match (e.g. `args`
rewriting does not survive the launch), say so and record the alternative used, rather than
weakening the assertion to something the real code path does not exercise.

**Files to modify**:
- `agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` - fixtures J-N,
  fake-server helper, Mutation 3, header inventory update

**Verification**:
- `bash agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` exits 0 with
  all fixtures A-N passing.
- No stray background processes survive the run (verify the `trap EXIT` cleanup).
- Mutation 3 demonstrably flips fixture L and demonstrably does not flip J or K.

---

### Phase 3: Inject `<lean-readiness-context>` into every dispatch file [COMPLETED]

**Goal**: `orchestrate-build-dispatch.sh` calls the extended probe unconditionally (gated only by
the probe's own internal lakefile detection, never by `task_type`) and appends its block, so the
dispatched agent receives its evidence tier before it begins.

**Tasks**:
- [x] Re-read `orchestrate-build-dispatch.sh`'s Stage 3.5 output region and the heredoc injection
      chain immediately before editing. *(completed)*
- [x] Add a `lean_readiness_context` computation as a new Stage 3.5 output, placed immediately
      after `deploy_freshness_context` and modeled on it: assign `""`, then
      `lean_readiness_context=$(bash "${SKILL_REPO_ROOT}/.claude/scripts/lean-mcp-preflight-check.sh" --dispatch-block 2>/dev/null) || lean_readiness_context=""`,
      matching the existing `memory-retrieve.sh` / `literature-briefing-invoke.sh` call convention
      in the same file (extension-owned script, absent-safe, failure degrades to empty).
      *(completed)*
- [x] Do **not** condition the call on `task_type`, `phase`, or any flag. The probe's own lakefile
      detection is the gate — this is what makes a `formal`-typed Lean project reachable by the fix.
      *(completed: manually verified end-to-end with a fixture repo carrying a lakefile and
      task_type=formal — the block is emitted)*
- [x] Append the block in the dispatch-file writer, immediately after the
      `deploy_freshness_context` emission and before `prior_decisions_block`, guarded by
      `if [ -n "$lean_readiness_context" ]`. *(completed)*
- [x] Document the new output in the script's header: what it is, why it is `task_type`-agnostic,
      and that it is byte-identical-when-empty like its siblings. *(completed)*
- [x] Measure the added wall-clock cost of a dispatch build in a non-Lean repo (this one) and
      record the delta in the header next to the existing cost notes. *(completed: 5-run means,
      ~65ms before and after, no measurable delta)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the change is confined to two edit points in one file (the
Stage 3.5 computation and the writer's conditional emission) plus a header note, with no new
plumbing needed because `SKILL_REPO_ROOT` is already the CWD (`cd "$SKILL_REPO_ROOT"` runs earlier
in the same script). Confirm by grepping the file for any other place a context block must be
registered (e.g. a block inventory or an ordering list); if one exists, extend it and say so.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - new
  `lean_readiness_context` Stage 3.5 output, conditional emission in the writer, header note

**Verification**:
- `bash -n` parses clean.
- A dispatch built for a task in this (non-Lean) repo contains no `<lean-readiness-context>` block
  and is otherwise unchanged from one built before the edit (diff the two).
- A dispatch built with CWD inside a Lean project contains the block, ahead of the
  `## Wait Discipline` section.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` still exits 0
  before Phase 4's additions.

---

### Phase 4: Pin the dispatch-file injection in the dispatch builder's test suite [NOT STARTED]

**Goal**: both the block-present and the byte-identical-when-absent cases are regression-tested.

**Tasks**:
- [ ] Re-read `test-orchestrate-build-dispatch.sh`'s fixture harness and follow its existing case
      style rather than introducing a new one.
- [ ] Add a case asserting that a dispatch built in a fixture repo with **no** lakefile contains no
      `<lean-readiness-context>` block — the byte-identity guarantee.
- [ ] Add a case asserting that a dispatch built in a fixture repo **with** a lakefile and a
      deployed stub `lean-mcp-preflight-check.sh` (emitting a known block on `--dispatch-block`)
      contains that block verbatim, positioned before `## Wait Discipline`. A stub keeps this test
      independent of the probe's own logic, which Phase 2 already covers.
- [ ] Add a case asserting the block is emitted for a `task_type` other than `lean4` (use `formal`)
      — the regression guard for the actual motivating incident.
- [ ] Add a case asserting that a stub probe exiting non-zero or printing nothing produces no block
      and no dispatch-build failure.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts four new cases in one existing test file are sufficient and
that the file's fixture harness can already place a stub script under a fixture `.claude/scripts/`.
Confirm by reading the harness before writing the cases; if it cannot, add the capability to the
harness and record that the scope was wider than estimated.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - four new cases
  covering absent/present/non-lean4-task_type/failing-probe

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` exits 0.
- Temporarily reverting Phase 3's emission guard makes the present-case fail and the absent-case
  pass, confirming non-vacuity.

---

### Phase 5: Thread the readiness finding into the direct-command path's delegation context [COMPLETED]

**Goal**: the four lean skills capture their existing Stage 2 probe output instead of discarding it,
and pass it to the subagent in Stage 3's delegation context — closing the same
finding-never-reaches-the-agent gap on the direct `/research|/plan|/implement` path.

**Tasks**:
- [x] For each of `skill-lean-research`, `skill-lean-research-hard`, `skill-lean-implementation`,
      `skill-lean-implementation-hard`: re-read the file, then change the Stage 2 snippet to invoke
      the probe with `--dispatch-block`, capture stdout into a shell variable, and still emit the
      human-readable no-flag output for the transcript (two invocations are acceptable here — this
      path is not latency-critical — or one capture plus an echo, whichever the file's existing
      snippet shape makes cleaner; state which was used). *(completed: used TWO invocations in all
      four files — the original no-flag call unchanged, plus a second `--dispatch-block` call
      whose stdout is captured into `lean_readiness`)*
- [x] Keep the `|| true` and the `[ -x ... ]` guard, so a deploy without the lean probe is still
      silent and non-blocking. *(completed)*
- [x] Add a `lean_readiness` field to each file's Stage 3 delegation-context JSON block, alongside
      `focus_prompt`, documented as carrying Stage 2's captured block (empty string when the probe
      is absent or the directory is not a Lean project). *(completed: in
      `skill-lean-implementation`, which has no `focus_prompt` field, placed alongside `plan_path`
      instead; in `skill-lean-implementation-hard`, whose delegation-context stage is numbered
      Stage 4 not Stage 3, placed alongside `continuation_context`)*
- [x] Add a one-line note at each Stage 4 invocation directive that `lean_readiness`, when
      non-empty, must be included in the subagent prompt — the field is useless if the prompt
      composer drops it. *(completed: in `skill-lean-implementation-hard`, whose invocation
      directive is numbered Stage 5 not Stage 4, the note was added there instead)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: atomic-batch

**Scope Hypothesis**: this phase asserts exactly four `SKILL.md` files carry the Stage 2 snippet and
that each has exactly one Stage 3 delegation-context JSON block to extend. Confirmed at planning
time by `grep -c lean-mcp-preflight-check` returning 2 for each of the four files; re-confirm per
file at implementation time, and if a fifth call site or a second JSON block appears, extend scope
and say so rather than editing only four.

**Files to modify**:
- `agent-system/extensions/lean/skills/skill-lean-research/SKILL.md` - Stage 2 capture, Stage 3
  `lean_readiness` field, Stage 4 inclusion note
- `agent-system/extensions/lean/skills/skill-lean-research-hard/SKILL.md` - same
- `agent-system/extensions/lean/skills/skill-lean-implementation/SKILL.md` - same
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` - same

**Verification**:
- All four files contain `lean_readiness` in their Stage 3 JSON block and a `--dispatch-block`
  capture in Stage 2.
- The four embedded bash snippets parse (`bash -n` on each extracted snippet).
- `grep -c lean-mcp-preflight-check` per file reflects the intended call count, with the guard and
  `|| true` still present.

---

### Phase 6: Record the two context gaps research named [COMPLETED]

**Goal**: the `lean_local_search` three-state vocabulary and the registered-vs-reachable
distinction are written down, independent of whether an agent ever reads the injected block.

**Tasks**:
- [x] In `mcp-tools-guide.md`'s `#### lean_local_search` subsection, add the three-state `index`
      vocabulary: `unavailable` = no language server running; `warming` = index still loading;
      `consulted` = the only state in which an empty result is proof of absence. State the
      interpretation rule explicitly, including that treating an `unavailable` empty result as
      proof of absence is a false conclusion. *(completed)*
- [x] In `mcp-server-ownership.md`, add a short section naming **registration vs. reachability** as
      a distinct, general concept: a correctly registered project with no running server passes
      every registration check silently, and only reachability determines the evidence tier. Note
      that the same distinction applies to any per-project MCP server this codebase registers, and
      point at the probe as the Lean-specific implementation. *(completed)*
- [x] In the same section, record the cheap diagnostic tell from the motivating incident as a
      durable manual technique, stated generally: if field `X` is *defined as* a projection of field
      `Y`, and `X` resolves while `Y` does not, the compiled artifact and the source provably came
      from different revisions — which distinguishes "cache is inconsistent" from "code is broken"
      in one check. Name it as a manual sanity check, explicitly **not** automated probe logic, and
      cross-reference that the build-cache half is tracked separately. *(completed: cross-references
      lake-build-guard.sh by name, not by task number)*
- [x] Observe `.claude/rules/no-task-references-in-deliverables.md`: cite durable anchors (file
      names, section headings, the error id `err_20261002080500`) and no task numbers in either
      file. *(completed: verified via check-task-references.sh, 0 occurrences in both files)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts both target files already exist and are already registered
in their extensions' `index-entries.json` (confirmed at planning time:
`lean/index-entries.json` line ~232 and `core/index-entries.json` line ~1105), so no index edit is
needed. Re-confirm before committing; if either entry is missing or its keywords no longer describe
the extended content, update the index entry and record the added scope.

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md` - three-state
  `index` vocabulary and interpretation rule under `lean_local_search`
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` - registration vs.
  reachability section plus the projection-asymmetry diagnostic tell

**Verification**:
- Diff read-through confirms every changed hunk is prose, with no change to any executable block.
- `bash .claude/scripts/check-task-references.sh` reports no new findings for either file.
- Both files' existing structure (heading levels, section order) is preserved.

---

### Phase 7: Redeploy and final gate [NOT STARTED]

**Goal**: `.claude/` reflects the source-store edits and the full gate set is green.

**Tasks**:
- [ ] Confirm every edit in Phases 1-6 landed under `agent-system/extensions/**` and that nothing
      was hand-authored under `.claude/**` (`git status --short` review).
- [ ] Run `bash .claude/scripts/deploy-headless.sh` so the deployed tree carries the extended probe,
      the new dispatch-builder output, the four skills and the two context files.
- [ ] Confirm `.claude/scripts/lean-mcp-preflight-check.sh --dispatch-block` is present and
      executable in the deployed tree and behaves as in Phase 1.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and confirm no gate regressed. Record any
      pre-existing failure explicitly as pre-existing (with evidence from `git stash`/HEAD
      comparison) rather than attributing it to this work.
- [ ] Run the two touched suites plus the extension test runner:
      `test-lean-mcp-preflight-check.sh`, `test-orchestrate-build-dispatch.sh`, and
      `bash agent-system/extensions/core/scripts/tests/run-all.sh` (new suites are auto-discovered;
      no registration file edit is needed).
- [ ] Verify the acceptance criterion end to end: build a dispatch with CWD inside a Lean project
      with no running `lean-lsp-mcp` server, and confirm the dispatch file states that LSP-backed
      lookup is unavailable and the evidence tier is degraded — and that the build still succeeds
      (exit 0, dispatch file written).
- [ ] Commit each green step with the `task {N}: ...` convention and an explicit file list — never
      `git add -A`, a directory pathspec, or `git commit -am`.

**Timing**: 0.5 hours

**Depends on**: 2, 4, 5, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts `deploy-headless.sh` followed by `verify-deploy.sh` is the
correct and sufficient close-out, and that no new script or context file needs a wiring entry
(because no new file is created by this plan — every phase extends an existing one). Confirm by
checking `git status --short` for any untracked file under `agent-system/`; if one exists, wire it
and record the added scope.

**Files to modify**:
- none planned (deploy and gate run only; `.claude/**` changes are generated output, never
  hand-authored)

**Verification**:
- `deploy-headless.sh` exits 0, or its outcome is recorded verbatim with any pre-existing failure
  named as pre-existing.
- `verify-deploy.sh` exits 0, or every non-green gate is shown to be non-green at HEAD too.
- All three test invocations exit 0.
- The acceptance scenario produces a dispatch file containing the degraded-tier statement, and the
  build exits 0.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` exits 0
      (fixtures A-N, Mutations 1-3).
- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` exits 0
      (including the new absent/present/non-`lean4`/failing-probe cases).
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 after `deploy-headless.sh`.
- [ ] A dispatch built in a non-Lean repo is byte-identical to one built at HEAD before this work.
- [ ] A dispatch built in a Lean project with no running server carries the degraded-tier statement
      and the `unavailable`/`warming`/`consulted` interpretation rule, and the build exits 0.
- [ ] A dispatch for a `formal`-typed task in a Lean project also carries the block.
- [ ] The probe's no-flag invocation output is unchanged on every pre-existing fixture.
- [ ] Non-Lean dispatch-build latency delta is measured and recorded; the probe's non-Lean early
      exit remains in the ~6ms band.

## Artifacts & Outputs

- `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh` — reachability detection and
  `--dispatch-block` mode (extended).
- `agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` — fixtures J-N and
  Mutation 3 (extended).
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — `lean_readiness_context`
  Stage 3.5 output and `<lean-readiness-context>` emission (extended).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — four injection
  cases (extended).
- The four lean `SKILL.md` files — Stage 2 capture and Stage 3 `lean_readiness` field (extended).
- `agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md` — three-state
  `index` vocabulary (extended).
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` — registration vs.
  reachability and the projection-asymmetry tell (extended).
- `specs/321_lean_language_server_readiness_preflight/summaries/01_*-summary.md` — execution summary
  at implementation close.
- A regenerated `.claude/` deploy tree (generated output, not a hand-authored artifact).

## Rollback/Contingency

Every phase is a scoped, committed edit to an existing file, so the ordinary rollback is
`git revert` of the phase commits in reverse order followed by `bash .claude/scripts/deploy-headless.sh`
to bring `.claude/` back in line with the restored source store. No schema, state, or data migration
is involved, and nothing outside `agent-system/**` is hand-edited.

If uncommitted work must be discarded instead, that is a genuine rollback scenario: take the
snapshot first per `context/contracts/recovery.md`'s rollback rung (which also documents the
out-of-scope override flag for the deliberate whole-tree case), then run the destructive command.
Do not emit a bare reverting `git-snapshot.sh` as a precautionary checkpoint; use `--no-revert` if a
durable mid-phase checkpoint is wanted.

Partial-landing contingency: Phase 3 alone (without Phases 5-6) already satisfies the acceptance
criterion on the `/orchestrate` path, and Phase 6 alone is independently valuable prose. If the
reachability probe in Phase 1 proves unworkable within the no-spawn and sub-100ms constraints, the
honest outcome is to report the trade-off as the deliverable — per the task's own instruction — and
land the block reporting `unknown` with the interpretation rule intact, rather than relaxing a
constraint silently or claiming a tier the probe cannot establish.
